from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from auth import get_db, get_current_user
from models.user import User
from models.clothing import Clothing

router = APIRouter(prefix="/clothes", tags=["clothes"])

# --- Şemalar ---
class ClothingCreate(BaseModel):
    category: str
    season: str
    hue: Optional[float] = None
    saturation: Optional[float] = None
    lightness: Optional[float] = None
    color_name: Optional[str] = None
    is_dirty: bool = False
    needs_ironing: bool = False

class ClothingUpdate(BaseModel):
    category: Optional[str] = None
    season: Optional[str] = None
    hue: Optional[float] = None
    saturation: Optional[float] = None
    lightness: Optional[float] = None
    color_name: Optional[str] = None
    is_dirty: Optional[bool] = None
    needs_ironing: Optional[bool] = None

# --- Endpoint'ler ---
@router.post("/", status_code=201)
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

@router.get("/")
def list_clothes(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return db.query(Clothing).filter(Clothing.user_id == current_user.id).all()

@router.get("/{item_id}")
def get_clothing(
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
    return item

@router.patch("/{item_id}")
def update_clothing(
    item_id: int,
    req: ClothingUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    item = db.query(Clothing).filter(
        Clothing.id == item_id,
        Clothing.user_id == current_user.id
    ).first()
    if not item:
        raise HTTPException(404, "Kıyafet bulunamadı")

    for field, value in req.model_dump(exclude_unset=True).items():
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
    item = db.query(Clothing).filter(
        Clothing.id == item_id,
        Clothing.user_id == current_user.id
    ).first()
    if not item:
        raise HTTPException(404, "Kıyafet bulunamadı")

    db.delete(item)
    db.commit()