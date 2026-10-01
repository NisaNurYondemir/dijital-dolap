from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from auth import get_db, get_current_user
from models.user import User
from models.clothing import Clothing
from schemas.clothing import ClothingCreate, ClothingUpdate, ClothingOut

router = APIRouter(prefix="/clothes", tags=["clothes"])

# Veritabanında boş olamayan alanlar: PATCH ile null gönderilemez
REQUIRED_FIELDS = {"category", "season", "is_dirty", "needs_ironing"}


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