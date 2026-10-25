from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func
from sqlalchemy.orm import Session, selectinload

from auth import get_db, get_current_user
from models.clothing import Clothing
from models.occasion import OccasionGroup
from models.outfit import Outfit, WearHistory, wear_items
from models.user import User
from schemas.wear import WearCreate, WearOut, WearUpdate

router = APIRouter(prefix="/wear", tags=["wear"])


def get_owned_wear(entry_id: int, db: Session, user: User) -> WearHistory:
    entry = (
        db.query(WearHistory)
        .options(selectinload(WearHistory.clothes))
        .filter(WearHistory.id == entry_id, WearHistory.user_id == user.id)
        .first()
    )
    if not entry:
        raise HTTPException(404, "Giyim kaydı bulunamadı")
    return entry


def _resolve_clothes(
    outfit_id: Optional[int],
    clothing_ids: Optional[list[int]],
    db: Session,
    user: User,
) -> tuple[Optional[Outfit], list[Clothing]]:
    """Kombin ve/veya tek tek parçalardan giyilen kıyafetleri çözer."""
    outfit: Optional[Outfit] = None
    clothes: list[Clothing] = []

    if outfit_id is not None:
        outfit = (
            db.query(Outfit)
            .options(selectinload(Outfit.clothes))
            .filter(Outfit.id == outfit_id, Outfit.user_id == user.id)
            .first()
        )
        if not outfit:
            raise HTTPException(404, "Kombin bulunamadı")
        clothes = list(outfit.clothes)

    # Tekrarları at, sırayı koru
    ids = list(dict.fromkeys(clothing_ids or []))
    if ids:
        found = (
            db.query(Clothing)
            .filter(Clothing.id.in_(ids), Clothing.user_id == user.id)
            .all()
        )
        if len(found) != len(ids):
            raise HTTPException(404, "Bir veya daha fazla kıyafet bulunamadı")
        by_id = {item.id: item for item in found}
        existing = {item.id for item in clothes}
        for clothing_id in ids:
            if clothing_id not in existing:
                clothes.append(by_id[clothing_id])
                existing.add(clothing_id)

    if not clothes:
        raise HTTPException(422, "En az bir kombin veya kıyafet seçin")

    return outfit, clothes


@router.post("/", response_model=WearOut, status_code=201)
def log_wear(
    req: WearCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Giyimi kaydeder. Kombin veya tek tek parça gönderilebilir."""
    outfit, clothes = _resolve_clothes(
        req.outfit_id, req.clothing_ids, db, current_user
    )

    group: Optional[OccasionGroup] = None
    if req.occasion_group_id is not None:
        group = (
            db.query(OccasionGroup)
            .filter(
                OccasionGroup.id == req.occasion_group_id,
                OccasionGroup.user_id == current_user.id,
            )
            .first()
        )
        if not group:
            raise HTTPException(404, "Amaç grubu bulunamadı")

    entry = WearHistory(
        user_id=current_user.id,
        outfit_id=outfit.id if outfit else None,
        rating=req.rating,
        occasion=group.name if group else req.occasion,
        occasion_group_id=group.id if group else None,
        note=req.note,
        weather_temp=req.weather_temp,
        weather_condition=req.weather_condition,
        location=req.location,
    )
    # worn_at verilmezse veritabanı varsayılanı (şimdi) kullanılır
    if req.worn_at is not None:
        entry.worn_at = req.worn_at
    entry.clothes = clothes

    db.add(entry)
    db.commit()
    db.refresh(entry)
    return get_owned_wear(entry.id, db, current_user)


@router.get("/", response_model=list[WearOut])
def list_wear_history(
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
    occasion: Optional[str] = Query(None),
    occasion_group_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Kullanıcının giyim geçmişini en yeniden eskiye döner."""
    query = (
        db.query(WearHistory)
        .options(selectinload(WearHistory.clothes))
        .filter(WearHistory.user_id == current_user.id)
    )
    if occasion is not None:
        query = query.filter(WearHistory.occasion == occasion)
    if occasion_group_id is not None:
        query = query.filter(
            WearHistory.occasion_group_id == occasion_group_id
        )
    return (
        query.order_by(WearHistory.worn_at.desc(), WearHistory.id.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )


@router.get("/stats")
def wear_stats(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Geçmişten özet: toplam, ortalama puan, amaç dağılımı, parça kullanımı."""
    total, average = (
        db.query(func.count(WearHistory.id), func.avg(WearHistory.rating))
        .filter(WearHistory.user_id == current_user.id)
        .one()
    )

    occasion_rows = (
        db.query(WearHistory.occasion, func.count(WearHistory.id))
        .filter(
            WearHistory.user_id == current_user.id,
            WearHistory.occasion.isnot(None),
        )
        .group_by(WearHistory.occasion)
        .order_by(func.count(WearHistory.id).desc())
        .all()
    )

    per_item = (
        db.query(
            Clothing.id,
            Clothing.category,
            Clothing.color_name,
            Clothing.image_path,
            func.count(wear_items.c.wear_id).label("wear_count"),
            func.max(WearHistory.worn_at).label("last_worn"),
        )
        .join(wear_items, wear_items.c.clothing_id == Clothing.id)
        .join(WearHistory, WearHistory.id == wear_items.c.wear_id)
        .filter(WearHistory.user_id == current_user.id)
        .group_by(Clothing.id)
        .order_by(func.count(wear_items.c.wear_id).desc())
        .all()
    )

    return {
        "total": total,
        "average_rating": round(float(average), 2) if average is not None else None,
        "by_occasion": [
            {"occasion": occasion, "count": count}
            for occasion, count in occasion_rows
        ],
        "per_clothing": [
            {
                "clothing_id": row.id,
                "category": row.category,
                "color_name": row.color_name,
                "image_path": row.image_path,
                "wear_count": row.wear_count,
                "last_worn": row.last_worn,
            }
            for row in per_item
        ],
    }


@router.get("/{entry_id}", response_model=WearOut)
def get_wear_entry(
    entry_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_owned_wear(entry_id, db, current_user)


@router.patch("/{entry_id}", response_model=WearOut)
def update_wear_entry(
    entry_id: int,
    req: WearUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Giyim kaydını puanla/amaçla/notla günceller (giydikten sonra puanlama)."""
    entry = get_owned_wear(entry_id, db, current_user)

    changes = req.model_dump(exclude_unset=True)
    if "occasion_group_id" in changes:
        group_id = changes.pop("occasion_group_id")
        if group_id is None:
            entry.occasion_group_id = None
        else:
            group = (
                db.query(OccasionGroup)
                .filter(
                    OccasionGroup.id == group_id,
                    OccasionGroup.user_id == current_user.id,
                )
                .first()
            )
            if not group:
                raise HTTPException(404, "Amaç grubu bulunamadı")
            entry.occasion_group_id = group.id
            entry.occasion = group.name

    for field, value in changes.items():
        setattr(entry, field, value)

    db.commit()
    db.refresh(entry)
    return get_owned_wear(entry.id, db, current_user)


@router.delete("/{entry_id}", status_code=204)
def delete_wear_entry(
    entry_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    entry = get_owned_wear(entry_id, db, current_user)
    db.delete(entry)
    db.commit()
