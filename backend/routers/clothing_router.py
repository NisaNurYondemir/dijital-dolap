from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from auth import get_db, get_current_user
from models.user import User
from models.clothing import Clothing
from schemas.clothing import ClothingCreate, ClothingUpdate, ClothingOut
import logging
import uuid
from pathlib import Path
from fastapi import UploadFile, File
from image_processing import process_clothing_image

logger = logging.getLogger(__name__)

# Çalıştırma klasöründen bağımsız: backend/uploads
UPLOAD_DIR = Path(__file__).resolve().parent.parent / "uploads"
UPLOAD_DIR.mkdir(exist_ok=True)
MAX_UPLOAD_BYTES = 10 * 1024 * 1024  # 10 MB

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


@router.post("/", response_model=ClothingOut, status_code=201)
def create_clothing(
    req: ClothingCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    item = Clothing(user_id=current_user.id, **req.model_dump())
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


@router.get("/", response_model=list[ClothingOut])
def list_clothes(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return db.query(Clothing).filter(Clothing.user_id == current_user.id).all()


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
    db.delete(item)
    db.commit()
@router.post("/upload-image", status_code=200)
def upload_clothing_image(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
):
    if file.content_type not in ("image/jpeg", "image/png", "image/webp"):
        raise HTTPException(415, "Desteklenmeyen dosya formatı. JPEG, PNG veya WEBP gönderin.")

    image_bytes = file.file.read(MAX_UPLOAD_BYTES + 1)
    if len(image_bytes) > MAX_UPLOAD_BYTES:
        raise HTTPException(413, "Dosya çok büyük (en fazla 10 MB)")

    try:
        result = process_clothing_image(image_bytes)
    except Exception:
        logger.exception("Görüntü işleme hatası")
        raise HTTPException(422, "Görsel işlenemedi, geçerli bir görsel gönderin")

    filename = f"{current_user.id}_{uuid.uuid4().hex}.png"
    (UPLOAD_DIR / filename).write_bytes(result.image_bytes)

    return {
        "image_path": f"uploads/{filename}",
        "color": {
            "hue": result.color.hue,
            "saturation": result.color.saturation,
            "lightness": result.color.lightness,
            "r": result.color.r,
            "g": result.color.g,
            "b": result.color.b,
        } if result.color else None,
    }