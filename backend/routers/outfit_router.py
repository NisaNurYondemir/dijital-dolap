from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from auth import get_db, get_current_user
from models.user import User
from models.clothing import Clothing
from models.outfit import Outfit
from schemas.outfit import OutfitCreate, OutfitUpdate, OutfitOut
from color_engine import Color, score_outfit

router = APIRouter(prefix="/outfits", tags=["outfits"])


def get_owned_outfit(outfit_id: int, db: Session, user: User) -> Outfit:
    outfit = db.query(Outfit).filter(
        Outfit.id == outfit_id,
        Outfit.user_id == user.id,
    ).first()
    if not outfit:
        raise HTTPException(404, "Kombin bulunamadı")
    return outfit


def resolve_clothes(clothing_ids: list[int], db: Session, user: User) -> list[Clothing]:
    """ID listesini kullanıcıya ait Clothing nesnelerine çevirir."""
    items = db.query(Clothing).filter(
        Clothing.id.in_(clothing_ids),
        Clothing.user_id == user.id,
    ).all()
    if len(items) != len(clothing_ids):
        raise HTTPException(404, "Bir veya daha fazla kıyafet bulunamadı")
    return items


@router.post("/", response_model=OutfitOut, status_code=201)
def create_outfit(
    req: OutfitCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    clothes = resolve_clothes(req.clothing_ids, db, current_user)
    outfit = Outfit(user_id=current_user.id, is_favorite=req.is_favorite)
    outfit.clothes = clothes
    db.add(outfit)
    db.commit()
    db.refresh(outfit)
    return outfit


@router.get("/", response_model=list[OutfitOut])
def list_outfits(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return db.query(Outfit).filter(Outfit.user_id == current_user.id).all()


@router.get("/{outfit_id}", response_model=OutfitOut)
def get_outfit(
    outfit_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_owned_outfit(outfit_id, db, current_user)


@router.patch("/{outfit_id}", response_model=OutfitOut)
def update_outfit(
    outfit_id: int,
    req: OutfitUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    outfit = get_owned_outfit(outfit_id, db, current_user)

    if req.is_favorite is not None:
        outfit.is_favorite = req.is_favorite

    if req.clothing_ids is not None:
        outfit.clothes = resolve_clothes(req.clothing_ids, db, current_user)

    db.commit()
    db.refresh(outfit)
    return outfit


@router.delete("/{outfit_id}", status_code=204)
def delete_outfit(
    outfit_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    outfit = get_owned_outfit(outfit_id, db, current_user)
    db.delete(outfit)
    db.commit()


@router.get("/{outfit_id}/score")
def get_outfit_score(
    outfit_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Kombinin renk uyum skorunu döner (0-1)."""
    outfit = get_owned_outfit(outfit_id, db, current_user)
    colors = [Color.from_item(c) for c in outfit.clothes]
    score = score_outfit(colors)
    return {"outfit_id": outfit_id, "score": round(score, 3)}