from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from auth import get_db, get_current_user
from models.user import User
from models.outfit import WearHistory, Outfit

router = APIRouter(prefix="/wear", tags=["wear"])

class WearCreate(BaseModel):
    outfit_id: int

@router.post("/", status_code=201)
def log_wear(
    req: WearCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Kombin kullanıcıya ait mi kontrol et
    outfit = db.query(Outfit).filter(
        Outfit.id == req.outfit_id,
        Outfit.user_id == current_user.id
    ).first()
    if not outfit:
        raise HTTPException(404, "Kombin bulunamadı")

    entry = WearHistory(user_id=current_user.id, outfit_id=req.outfit_id)
    db.add(entry)
    db.commit()
    db.refresh(entry)
    return {"id": entry.id, "outfit_id": entry.outfit_id, "worn_at": entry.worn_at}

@router.get("/")
def list_wear_history(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    entries = (
        db.query(WearHistory)
        .filter(WearHistory.user_id == current_user.id)
        .order_by(WearHistory.worn_at.desc())
        .all()
    )
    return [
        {"id": e.id, "outfit_id": e.outfit_id, "worn_at": e.worn_at}
        for e in entries
    ]

@router.delete("/{entry_id}", status_code=204)
def delete_wear_entry(
    entry_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    entry = db.query(WearHistory).filter(
        WearHistory.id == entry_id,
        WearHistory.user_id == current_user.id
    ).first()
    if not entry:
        raise HTTPException(404, "Kayıt bulunamadı")

    db.delete(entry)
    db.commit()