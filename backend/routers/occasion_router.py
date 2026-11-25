from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from auth import get_current_user, get_db
from models.occasion import OccasionGroup
from models.user import User
from occasion_defaults import seed_default_occasions
from schemas.occasion import (
    OccasionGroupCreate,
    OccasionGroupOut,
    OccasionGroupUpdate,
)

router = APIRouter(prefix="/occasions", tags=["occasions"])


def get_owned_group(group_id: int, db: Session, user: User) -> OccasionGroup:
    group = (
        db.query(OccasionGroup)
        .filter(
            OccasionGroup.id == group_id,
            OccasionGroup.user_id == user.id,
        )
        .first()
    )
    if not group:
        raise HTTPException(404, "Amaç grubu bulunamadı")
    return group


def _name_exists(
    name: str,
    db: Session,
    user: User,
    exclude_id: int | None = None,
) -> bool:
    query = db.query(OccasionGroup).filter(
        OccasionGroup.user_id == user.id,
        func.lower(OccasionGroup.name) == name.lower(),
    )
    if exclude_id is not None:
        query = query.filter(OccasionGroup.id != exclude_id)
    return bool(db.query(query.exists()).scalar())


@router.get("/", response_model=list[OccasionGroupOut])
def list_groups(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Kullanıcının amaç gruplarını döner; ilk açılışta varsayılanları oluşturur."""
    groups = (
        db.query(OccasionGroup)
        .filter(OccasionGroup.user_id == current_user.id)
        .order_by(OccasionGroup.is_default.desc(), OccasionGroup.id)
        .all()
    )
    if not groups:
        seed_default_occasions(db, current_user.id)
        groups = (
            db.query(OccasionGroup)
            .filter(OccasionGroup.user_id == current_user.id)
            .order_by(OccasionGroup.is_default.desc(), OccasionGroup.id)
            .all()
        )
    return groups


@router.post("/", response_model=OccasionGroupOut, status_code=201)
def create_group(
    req: OccasionGroupCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if _name_exists(req.name, db, current_user):
        raise HTTPException(409, "Bu isimde bir amaç grubu zaten var")

    group = OccasionGroup(
        user_id=current_user.id,
        name=req.name,
        emoji=req.emoji,
        color=req.color,
        occasion_type=req.occasion_type,
        is_default=False,
    )
    db.add(group)
    db.commit()
    db.refresh(group)
    return group


@router.patch("/{group_id}", response_model=OccasionGroupOut)
def update_group(
    group_id: int,
    req: OccasionGroupUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    group = get_owned_group(group_id, db, current_user)
    changes = req.model_dump(exclude_unset=True)

    new_name = changes.get("name")
    if new_name is not None and _name_exists(
        new_name, db, current_user, exclude_id=group.id
    ):
        raise HTTPException(409, "Bu isimde bir amaç grubu zaten var")

    for field, value in changes.items():
        # Ad ve tip boşaltılamaz; emoji/renk null ile temizlenebilir.
        if field in {"name", "occasion_type"} and value is None:
            continue
        setattr(group, field, value)

    db.commit()
    db.refresh(group)
    return group


@router.delete("/{group_id}", status_code=204)
def delete_group(
    group_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Grubu siler; kombin bağlantıları ve giyim kaydı bağlantısı temizlenir.

    Giyim geçmişindeki `occasion` metni anlık görüntü olarak korunur.
    """
    group = get_owned_group(group_id, db, current_user)
    db.delete(group)
    db.commit()
