import logging
import re
import shutil
import time
import uuid
from io import BytesIO
from pathlib import Path
from typing import Optional

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile
from PIL import Image, UnidentifiedImageError
from sqlalchemy.orm import Session

from analysis import color_name, suggest_season
from auth import get_current_user, get_db
from clip_category import predict_category, predict_top_categories
from image_processing import process_clothing_image
from models.clothing import Clothing
from models.user import User
from schemas.clothing import ClothingCreate, ClothingOut, ClothingUpdate
logger = logging.getLogger(__name__)

# Çalıştırma klasöründen bağımsız: backend/uploads
UPLOAD_DIR = Path(__file__).resolve().parent.parent / "uploads"
UPLOAD_DIR.mkdir(exist_ok=True)
MAX_UPLOAD_BYTES = 10 * 1024 * 1024  # 10 MB
ALLOWED_FORMATS = {"JPEG", "PNG", "WEBP"}
TMP_DIR = UPLOAD_DIR / "tmp"
TMP_DIR.mkdir(exist_ok=True)
TMP_MAX_AGE_SECONDS = 60 * 60  # geçici görseller 1 saat saklanır
_TMP_NAME = re.compile(r"^(\d+)_[0-9a-f]{32}\.png$")

def _detect_format(data: bytes):
    """Dosyanın gerçek biçimini içeriğine bakarak bulur (başlığa güvenmez)."""
    try:
        with Image.open(BytesIO(data)) as img:
            return img.format
    except (UnidentifiedImageError, OSError):
        return None

def _flatten_on_white(png_bytes: bytes) -> bytes:
    """Şeffaf arka planlı PNG'yi beyaz zemine oturtur (CLIP siyah zeminde yanılır)."""
    with Image.open(BytesIO(png_bytes)) as img:
        base = Image.new("RGBA", img.size, (255, 255, 255, 255))
        base.alpha_composite(img.convert("RGBA"))
        out = BytesIO()
        base.convert("RGB").save(out, format="JPEG", quality=90)
        return out.getvalue()


def _cleanup_tmp() -> None:
    """Bir saatten eski geçici görselleri siler."""
    limit = time.time() - TMP_MAX_AGE_SECONDS
    for f in TMP_DIR.glob("*.png"):
        try:
            if f.stat().st_mtime < limit:
                f.unlink(missing_ok=True)
        except OSError:
            pass


def _claim_tmp_image(temp_image: str, user: User) -> str:
    """Kullanıcının geçici görselini kalıcı klasöre taşır, göreli yolunu döner."""
    match = _TMP_NAME.match(temp_image)
    if not match or int(match.group(1)) != user.id:
        raise HTTPException(400, "Geçersiz geçici görsel")
    src = TMP_DIR / temp_image
    if not src.is_file():
        raise HTTPException(410, "Geçici görselin süresi dolmuş, fotoğrafı yeniden yükleyin")
    filename = f"{user.id}_{uuid.uuid4().hex}.png"
    shutil.move(str(src), str(UPLOAD_DIR / filename))
    return f"uploads/{filename}"

router = APIRouter(prefix="/clothes", tags=["clothes"])

# Veritabanında boş olamayan alanlar: PATCH ile null gönderilemez
REQUIRED_FIELDS = {"category", "season", "is_dirty", "needs_ironing", "is_ironed"}


def get_owned_clothing(item_id: int, db: Session, user: User) -> Clothing:
    item = db.query(Clothing).filter(
        Clothing.id == item_id,
        Clothing.user_id == user.id,
    ).first()
    if not item:
        raise HTTPException(404, "Kıyafet bulunamadı")
    return item


@router.post("/analyze")
def analyze_clothing_image(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
):
    """Fotoğrafı kayıt açmadan analiz eder. Kullanıcı sonucu onaylayınca
    POST /clothes/ ile (temp_image alanıyla) kaydedilir."""
    _cleanup_tmp()

    image_bytes = file.file.read(MAX_UPLOAD_BYTES + 1)
    if len(image_bytes) > MAX_UPLOAD_BYTES:
        raise HTTPException(413, "Dosya çok büyük (en fazla 10 MB)")
    if _detect_format(image_bytes) not in ALLOWED_FORMATS:
        raise HTTPException(415, "Desteklenmeyen dosya formatı. JPEG, PNG veya WEBP gönderin.")

    try:
        result = process_clothing_image(image_bytes)
        top = predict_top_categories(_flatten_on_white(result.image_bytes), k=3)
    except Exception:
        logger.exception("Analiz hatası")
        raise HTTPException(422, "Görsel işlenemedi, geçerli bir görsel gönderin")

    filename = f"{current_user.id}_{uuid.uuid4().hex}.png"
    (TMP_DIR / filename).write_bytes(result.image_bytes)

    color = result.color
    hue = color.hue if color else None
    saturation = color.saturation if color else None
    lightness = color.lightness if color else None
    category = top[0][0]

    return {
        "temp_image": filename,
        "preview_path": f"uploads/tmp/{filename}",
        "category": category,
        "category_candidates": [
            {"category": c, "probability": round(p, 3)} for c, p in top
        ],
        "season": suggest_season(category),
        "hue": hue,
        "saturation": saturation,
        "lightness": lightness,
        "color_name": color_name(hue, saturation, lightness),
    }


@router.post("/", response_model=ClothingOut, status_code=201)
def create_clothing(
    req: ClothingCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    data = req.model_dump(exclude={"temp_image"})
    image_path = _claim_tmp_image(req.temp_image, current_user) if req.temp_image else None

    item = Clothing(user_id=current_user.id, image_path=image_path, **data)
    try:
        db.add(item)
        db.commit()
    except Exception:
        db.rollback()
        _delete_image_file(image_path)  # kayıt başarısızsa taşınan dosyayı geri temizle
        raise
    db.refresh(item)
    return item


@router.post("/{item_id}/predict-category")
def predict_clothing_category(
    item_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    item = db.query(Clothing).filter(
        Clothing.id == item_id,
        Clothing.user_id == current_user.id
    ).first()
    if not item:
        raise HTTPException(404, "Kıyafet bulunamadı")
    if not item.image_path:
        raise HTTPException(400, "Önce görsel yükleyin")

    with open(item.image_path, "rb") as f:
        image_bytes = f.read()

    category = predict_category(image_bytes)

    item.category = category
    db.commit()
    db.refresh(item)
    return {"id": item.id, "category": item.category}


@router.get("/")
def list_clothes(
    category: Optional[str] = Query(None),
    season: Optional[str] = Query(None),
    is_dirty: Optional[bool] = Query(None),
    needs_ironing: Optional[bool] = Query(None),
    is_ironed: Optional[bool] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    q = db.query(Clothing).filter(Clothing.user_id == current_user.id)

    if category is not None:
        q = q.filter(Clothing.category == category)
    if season is not None:
        q = q.filter(Clothing.season == season)
    if is_dirty is not None:
        q = q.filter(Clothing.is_dirty == is_dirty)
    if needs_ironing is not None:
        q = q.filter(Clothing.needs_ironing == needs_ironing)
    if is_ironed is not None:
        q = q.filter(Clothing.is_ironed == is_ironed)

    return q.all()

@router.get("/{item_id}", response_model=ClothingOut)
def get_clothing(
    item_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_owned_clothing(item_id, db, current_user)


@router.patch("/{item_id}", response_model=ClothingOut)
def update_clothing(
    item_id: int,
    req: ClothingUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    item = get_owned_clothing(item_id, db, current_user)

    changes = req.model_dump(exclude_unset=True)
    for field, value in changes.items():
        if value is None and field in REQUIRED_FIELDS:
            raise HTTPException(422, f"'{field}' alanı boş bırakılamaz")
        setattr(item, field, value)

    db.commit()
    db.refresh(item)
    return item


@router.delete("/{item_id}", status_code=204)
def delete_clothing(
    item_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    item = get_owned_clothing(item_id, db, current_user)
    image_path = item.image_path
    db.delete(item)
    db.commit()
    _delete_image_file(image_path)


def _delete_image_file(image_path: Optional[str]) -> None:
    """Diskteki görseli siler (yoksa sessizce geçer)."""
    if image_path:
        (UPLOAD_DIR / Path(image_path).name).unlink(missing_ok=True)


@router.post("/{item_id}/image", response_model=ClothingOut)
def upload_clothing_image(
    item_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    item = get_owned_clothing(item_id, db, current_user)

    image_bytes = file.file.read(MAX_UPLOAD_BYTES + 1)
    if len(image_bytes) > MAX_UPLOAD_BYTES:
        raise HTTPException(413, "Dosya çok büyük (en fazla 10 MB)")
    
    if _detect_format(image_bytes) not in ALLOWED_FORMATS:
        raise HTTPException(415, "Desteklenmeyen dosya formatı. JPEG, PNG veya WEBP gönderin.")

    try:
        result = process_clothing_image(image_bytes)
    except Exception:
        logger.exception("Görüntü işleme hatası")
        raise HTTPException(422, "Görsel işlenemedi, geçerli bir görsel gönderin")

    filename = f"{current_user.id}_{uuid.uuid4().hex}.png"
    (UPLOAD_DIR / filename).write_bytes(result.image_bytes)

    # Önceki görseli diskten temizle, yenisini bağla
    _delete_image_file(item.image_path)
    item.image_path = f"uploads/{filename}"
    if result.color:
        item.hue = result.color.hue
        item.saturation = result.color.saturation
        item.lightness = result.color.lightness

    db.commit()
    db.refresh(item)
    return item
