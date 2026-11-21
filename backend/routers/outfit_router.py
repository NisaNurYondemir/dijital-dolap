from itertools import combinations
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session, selectinload

from auth import get_db, get_current_user
from color_engine import ItemProfile, evaluate_outfit
from models.clothing import Clothing
from models.occasion import OccasionGroup
from models.outfit import Outfit, WearHistory
from models.user import User
from schemas.clothing import ClothingOut, Season
from schemas.outfit import OutfitCreate, OutfitOut, OutfitSuggestion, OutfitUpdate
from schemas.wear import WearOut
from suggestion import (
    ItemHistory, PairHistory, WeatherContext, group_of, scope_of, suggest_outfits,
)
from style_profile import (
    StyleItem,
    StyleOutfit,
    StyleWear,
    StyleWeights,
    build_style_profile,
    build_style_weights,
)
from weather import WeatherError, fetch_weather, needs_outerwear_with_bias

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
    outfit = Outfit(
        user_id=current_user.id,
        is_favorite=req.is_favorite,
        name=req.name,
        description=req.description,
    )
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


def _style_profile_signals(
    db: Session,
    user: User,
    clothes: list[Clothing],
):
    """Tarz profili icin DB'yi saf moda girdilerine cevirir."""
    items = [
        StyleItem(
            id=c.id,
            category=c.category,
            hue=c.hue,
            saturation=c.saturation,
            lightness=c.lightness,
        )
        for c in clothes
    ]
    wears = [
        StyleWear(
            clothing_ids=[c.id for c in w.clothes],
            rating=w.rating,
            worn_at=w.worn_at,
        )
        for w in db.query(WearHistory)
        .options(selectinload(WearHistory.clothes))
        .filter(WearHistory.user_id == user.id)
        .all()
    ]
    outfits = [
        StyleOutfit(
            clothing_ids=[c.id for c in o.clothes],
            is_favorite=o.is_favorite,
        )
        for o in db.query(Outfit)
        .options(selectinload(Outfit.clothes))
        .filter(Outfit.user_id == user.id)
        .all()
    ]
    return items, wears, outfits


def _style_weights(
    db: Session,
    user: User,
    clothes: list[Clothing],
) -> Optional[StyleWeights]:
    items, wears, outfits = _style_profile_signals(db, user, clothes)
    profile = build_style_profile(items, wears, outfits)
    return build_style_weights(profile)


def _thermal_bias(db: Session, user: User) -> Optional[float]:
    """Kullanıcının sıcaklık hissi ortalaması (son giyimler, -2..+2).

    comfort = -2 çok üşüdüm, 0 tam ayarında, +2 çok sıcakladım. Son
    15 geri bildirim üzerinden hesaplanır; geri bildirim yoksa None.
    """
    rows = (
        db.query(WearHistory.comfort)
        .filter(
            WearHistory.user_id == user.id,
            WearHistory.comfort.isnot(None),
        )
        .order_by(WearHistory.worn_at.desc(), WearHistory.id.desc())
        .limit(15)
        .all()
    )
    values = [row[0] for row in rows]
    if not values:
        return None
    return sum(values) / len(values)


@router.get("/suggest", response_model=list[OutfitSuggestion])
def suggest(
    season: Optional[Season] = None,
    limit: int = Query(5, ge=1, le=20),
    include_shoes: bool = True,
    include_outerwear: bool = False,
    occasion_id: Optional[int] = Query(None),
    lat: Optional[float] = Query(None, ge=-90, le=90),
    lon: Optional[float] = Query(None, ge=-180, le=180),
    city: Optional[str] = Query(None, max_length=80),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Renk uyumu + giyim geçmişi + havaya göre önerir.

    lat/lon verilirse Open-Meteo'dan günlük hava alınır: sıcaklığa göre
    mevsim filtresi uygulanır, soğuk/ıslak havada üst giysi önerilir ve
    nedenlerde hava bilgisi gösterilir. Hava servisi başarısız olursa
    öneri hava bilgisi olmadan devam eder.
    """
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

    weather_ctx: Optional[WeatherContext] = None
    weather_season: Optional[str] = None
    bias = _thermal_bias(db, current_user)
    if lat is not None and lon is not None:
        try:
            summary = fetch_weather(lat, lon, city=city)
        except WeatherError:
            summary = None
        if summary is not None:
            weather_season = summary.season_hint
            note: Optional[str] = None
            if bias is not None and bias <= -0.5:
                note = "Buz gibi günlerde üşüyorsun; kalın parçalar iyi gelir"
            elif bias is not None and bias >= 0.5:
                note = "Sıcaklarda terlediğin oluyor; hafif parçalar iyi gelir"
            weather_ctx = WeatherContext(
                headline=summary.headline(),
                needs_outerwear=needs_outerwear_with_bias(summary, bias),
                rainy=summary.is_rainy_snowy,
                comfort_note=note,
            )

    clothes = db.query(Clothing).filter(Clothing.user_id == current_user.id).all()
    history, pairs = _wear_signals(db, current_user, occasion)
    style = _style_weights(db, current_user, clothes)

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

    effective_season: Optional[str] = season.value if season else weather_season
    outerwear = include_outerwear or (
        weather_ctx is not None and weather_ctx.needs_outerwear
    )
    results = suggest_outfits(
        clothes,
        season=effective_season,
        limit=limit,
        include_shoes=include_shoes,
        include_outerwear=outerwear,
        history=history or None,
        pair_history=pairs or None,
        occasion_name=occasion.name if occasion else None,
        weather=weather_ctx,
        style=style,
    )
    if not results and weather_season and season is None:
        # Hava filtresi dolabı sıfırladıysa mevsim kısıtını bırakır; hava
        # açıklamaları yine de önerilerin nedenlerine işlenir.
        results = suggest_outfits(
            clothes,
            season=None,
            limit=limit,
            include_shoes=include_shoes,
            include_outerwear=outerwear,
            history=history or None,
            pair_history=pairs or None,
            occasion_name=occasion.name if occasion else None,
            weather=weather_ctx,
            style=style,
        )
    return [
        OutfitSuggestion(
            score=round(r.score, 3),
            color_score=round(r.color_score, 3),
            pattern_score=round(r.pattern_score, 3),
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


@router.get("/{outfit_id}/history", response_model=list[WearOut])
def get_outfit_history(
    outfit_id: int,
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Kombinin giyim geçmişi: tarih, puan, sıcaklık hissi, hava bilgisi."""
    get_owned_outfit(outfit_id, db, current_user)
    return (
        db.query(WearHistory)
        .options(selectinload(WearHistory.clothes))
        .filter(
            WearHistory.outfit_id == outfit_id,
            WearHistory.user_id == current_user.id,
        )
        .order_by(WearHistory.worn_at.desc(), WearHistory.id.desc())
        .limit(limit)
        .all()
    )


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

    changes = req.model_dump(exclude_unset=True)
    changes.pop("is_favorite", None)
    changes.pop("clothing_ids", None)
    changes.pop("occasion_ids", None)
    for field, value in changes.items():
        setattr(outfit, field, value)

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
    """Kombinin renk ve desen uyum skorlarını döner (0-1)."""
    outfit = get_owned_outfit(outfit_id, db, current_user)
    profiles = [
        ItemProfile.from_item(c, scope=scope_of(c))
        for c in outfit.clothes
    ]
    total, color, pattern, _ = evaluate_outfit(profiles)
    return {
        "outfit_id": outfit_id,
        "score": round(total, 3),
        "color_score": round(color, 3),
        "pattern_score": round(pattern, 3),
    }