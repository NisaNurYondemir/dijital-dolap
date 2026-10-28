from itertools import combinations
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session, selectinload

from auth import get_db, get_current_user
from color_engine import Color, score_outfit
from models.clothing import Clothing
from models.occasion import OccasionGroup
from models.outfit import Outfit, WearHistory
from models.user import User
from schemas.clothing import ClothingOut, Season
from schemas.outfit import OutfitCreate, OutfitOut, OutfitSuggestion, OutfitUpdate
from suggestion import ItemHistory, PairHistory, group_of, suggest_outfits

router = APIRouter(prefix="/outfits", tags=["outfits"])
def get_owned_outfit(outfit_id: int, db: Session, user: User) -> Outfit:
    outfit = (
        db.query(Outfit)
        .options(selectinload(Outfit.groups))
        .filter(
            Outfit.id == outfit_id,
            Outfit.user_id == user.id,
        )
        .first()
    )
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


def resolve_groups(
    occasion_ids: list[int],
    db: Session,
    user: User,
) -> list[OccasionGroup]:
    """ID listesini kullanıcıya ait amaç gruplarına çevirir (sırayı korur)."""
    ids = list(dict.fromkeys(occasion_ids))
    if not ids:
        return []
    groups = (
        db.query(OccasionGroup)
        .filter(
            OccasionGroup.id.in_(ids),
            OccasionGroup.user_id == user.id,
        )
        .all()
    )
    if len(groups) != len(ids):
        raise HTTPException(404, "Bir veya daha fazla amaç grubu bulunamadı")
    by_id = {group.id: group for group in groups}
    return [by_id[group_id] for group_id in ids]


@router.post("/", response_model=OutfitOut, status_code=201)
def create_outfit(
    req: OutfitCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    clothes = resolve_clothes(req.clothing_ids, db, current_user)
    groups = resolve_groups(req.occasion_ids, db, current_user)
    outfit = Outfit(user_id=current_user.id, is_favorite=req.is_favorite)
    outfit.clothes = clothes
    outfit.groups = groups
    db.add(outfit)
    db.commit()
    db.refresh(outfit)
    return get_owned_outfit(outfit.id, db, current_user)


@router.get("/", response_model=list[OutfitOut])
def list_outfits(
    occasion_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = (
        db.query(Outfit)
        .options(selectinload(Outfit.groups))
        .filter(Outfit.user_id == current_user.id)
    )
    if occasion_id is not None:
        query = query.join(Outfit.groups).filter(
            OccasionGroup.id == occasion_id
        )
    return query.order_by(Outfit.created_at.desc(), Outfit.id.desc()).all()

def _wear_signals(
    db: Session,
    user: User,
    occasion: Optional[OccasionGroup],
) -> tuple[dict[int, ItemHistory], dict[tuple[int, int], PairHistory]]:
    """Giyim geçmişini öneri motorunun beklediği sinyallere çevirir."""
    history: dict[int, ItemHistory] = {}
    pairs: dict[tuple[int, int], PairHistory] = {}

    wears = (
        db.query(WearHistory)
        .options(selectinload(WearHistory.clothes))
        .filter(WearHistory.user_id == user.id)
        .all()
    )
    for wear in wears:
        same_occasion = (
            occasion is not None
            and wear.occasion_group_id == occasion.id
        )
        for item in wear.clothes:
            entry = history.setdefault(item.id, ItemHistory())
            entry.wear_count += 1
            if wear.rating is not None:
                entry.rating_sum += wear.rating
                entry.rating_count += 1
            if wear.worn_at is not None and (
                entry.last_worn is None or wear.worn_at > entry.last_worn
            ):
                entry.last_worn = wear.worn_at
            if same_occasion:
                entry.occasion_wear_count += 1
                if wear.rating is not None:
                    entry.occasion_rating_sum += wear.rating
                    entry.occasion_rating_count += 1

        # Birlikte giyilip puanlanan ikililer, kombin uyumunun ek sinyalidir.
        if wear.rating is not None and len(wear.clothes) >= 2:
            for first, second in combinations(wear.clothes, 2):
                key = tuple(sorted((first.id, second.id)))
                pair = pairs.setdefault(key, PairHistory())
                pair.count += 1
                pair.rating_sum += wear.rating
                pair.rating_count += 1

    if occasion is not None:
        # Henüz giyilmemiş olsa bile o amaçla kaydedilen kombinlerdeki
        # parçalar "bu amaçla kullandığın parçalar" sinyali verir.
        outfits = (
            db.query(Outfit)
            .options(selectinload(Outfit.clothes))
            .join(Outfit.groups)
            .filter(
                Outfit.user_id == user.id,
                OccasionGroup.id == occasion.id,
            )
            .all()
        )
        for outfit in outfits:
            for item in outfit.clothes:
                entry = history.setdefault(item.id, ItemHistory())
                entry.occasion_outfit_count += 1

    return history, pairs


@router.get("/suggest", response_model=list[OutfitSuggestion])
def suggest(
    season: Optional[Season] = None,
    limit: int = Query(5, ge=1, le=20),
    include_shoes: bool = True,
    include_outerwear: bool = False,
    occasion_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Renk uyumu + giyim geçmişinden öğrenilen tercihlere göre önerir."""
    occasion: Optional[OccasionGroup] = None
    if occasion_id is not None:
        occasion = (
            db.query(OccasionGroup)
            .filter(
                OccasionGroup.id == occasion_id,
                OccasionGroup.user_id == current_user.id,
            )
            .first()
        )
        if not occasion:
            raise HTTPException(404, "Amaç grubu bulunamadı")

    clothes = db.query(Clothing).filter(Clothing.user_id == current_user.id).all()
    history, pairs = _wear_signals(db, current_user, occasion)

    # Amaç seçiliyse ve o amaçla ilişkili yeterli parça varsa adayları daralt;
    # yoksa tüm dolaptan önererek yeni kullanıcıyı boş ekranla bırakma.
    if occasion is not None:
        related_ids = {
            item_id
            for item_id, signals in history.items()
            if signals.occasion_wear_count or signals.occasion_outfit_count
        }
        related = [item for item in clothes if item.id in related_ids]
        has_top = any(group_of(item.category) == "ust" for item in related)
        has_bottom = any(group_of(item.category) == "alt" for item in related)
        has_dress = any(group_of(item.category) == "elbise" for item in related)
        if (has_top and has_bottom) or has_dress:
            clothes = related

    results = suggest_outfits(
        clothes,
        season=season,
        limit=limit,
        include_shoes=include_shoes,
        include_outerwear=include_outerwear,
        history=history or None,
        pair_history=pairs or None,
        occasion_name=occasion.name if occasion else None,
    )
    return [
        OutfitSuggestion(
            score=round(r.score, 3),
            color_score=round(r.color_score, 3),
            reasons=r.reasons,
            clothes=[ClothingOut.model_validate(i) for i in r.items],
        )
        for r in results
    ]

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

    if req.occasion_ids is not None:
        outfit.groups = resolve_groups(req.occasion_ids, db, current_user)

    db.commit()
    db.refresh(outfit)
    return get_owned_outfit(outfit.id, db, current_user)


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