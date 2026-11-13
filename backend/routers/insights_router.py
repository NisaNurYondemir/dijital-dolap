from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func
from sqlalchemy import func
from sqlalchemy.orm import Session

from auth import get_current_user, get_db
from insights import build_wardrobe_insights
from models.clothing import Clothing
from models.outfit import WearHistory, wear_items
from models.occasion import OccasionGroup
from models.user import User

router = APIRouter(prefix="/insights", tags=["insights"])


def color_hex(c) -> str:
    h = int(c.hue) if c.hue is not None else 210
    s = (c.saturation or 0) / 100.0
    l = (c.lightness or 70) / 100.0
    return f"hsl({h},{int(c.saturation or 0)}%,{int(c.lightness or 70)}%)"


@router.get("/wardrobe")
def wardrobe_dashboard(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Kullanıcının dolap özeti + kısa Türkçe içgörüler."""
    user_id = current_user.id
    clothes = (
        db.query(Clothing).filter(Clothing.user_id == user_id).all()
    )
    items = len(clothes)
    dirty = sum(1 for c in clothes if c.is_dirty)
    ironing = sum(1 for c in clothes if c.needs_ironing)
    wearable = sum(1 for c in clothes if c.is_wearable)

    # Mevsim dağılımı
    season_counts: dict[str, int] = {}
    for c in clothes:
        season_counts[c.season] = season_counts.get(c.season, 0) + 1

    # Kategori dağılımı (+ giyilme sayıları)
    cat_rows = (
        db.query(
            Clothing.category,
            func.count(wear_items.c.wear_id).label("wears"),
        )
        .outerjoin(wear_items, wear_items.c.clothing_id == Clothing.id)
        .filter(Clothing.user_id == user_id)
        .group_by(Clothing.category)
        .order_by(func.count(wear_items.c.wear_id).desc())
        .all()
    )
    by_category = [
        {"category": row[0], "count": 0, "wears": int(row[1] or 0)}
        for row in cat_rows
    ]
    cat_count = {}
    for c in clothes:
        cat_count[c.category] = cat_count.get(c.category, 0) + 1
    for row in by_category:
        row["count"] = cat_count.get(row["category"], 0)

    # En çok giyilenler / hiç giyilmeyenler
    wear_q = (
        db.query(
            Clothing.id.label("id"),
            Clothing.category.label("category"),
            Clothing.color_name.label("color_name"),
            Clothing.image_path.label("image_path"),
            Clothing.hue.label("hue"),
            Clothing.saturation.label("saturation"),
            Clothing.lightness.label("lightness"),
            func.count(wear_items.c.wear_id).label("wear_count"),
            func.max(WearHistory.worn_at).label("last_worn"),
            func.avg(WearHistory.rating).label("avg_rating"),
        )
        .join(wear_items, wear_items.c.clothing_id == Clothing.id)
        .join(WearHistory, WearHistory.id == wear_items.c.wear_id)
        .filter(Clothing.user_id == user_id)
        .group_by(Clothing.id)
    )
    top_worn_rows = (
        wear_q.order_by(func.count(wear_items.c.wear_id).desc()).limit(5).all()
    )
    # tüm giyilmiş parça id'leri (hiç giyilmeyenleri bulmak için)
    all_worn_ids = {
        row[0]
        for row in (
            db.query(wear_items.c.clothing_id)
            .join(WearHistory, WearHistory.id == wear_items.c.wear_id)
            .filter(WearHistory.user_id == user_id)
            .distinct()
            .all()
        )
    }

    def item_dict(row) -> dict:
        return {
            "id": row.id,
            "category": row.category,
            "color_name": row.color_name,
            "color": color_hex(
                SimpleNamespace(
                    hue=row.hue,
                    saturation=row.saturation,
                    lightness=row.lightness,
                )
            ),
            "image_path": row.image_path,
            "wear_count": int(row.wear_count or 0),
            "last_worn": row.last_worn,
            "avg_rating": round(float(row.avg_rating), 1) if row.avg_rating else None,
        }

    top_worn = [item_dict(r) for r in top_worn_rows]

    now = datetime.now(timezone.utc)
    never_worn = []
    for c in clothes:
        if c.id in all_worn_ids:
            continue
        days = None
        if c.created_at:
            days = max((now - c.created_at).days, 0)
        never_worn.append({
            "id": c.id,
            "category": c.category,
            "color_name": c.color_name,
            "color": color_hex(c),
            "image_path": c.image_path,
            "days_in_wardrobe": days,
            "dirty_or_ironing": not c.is_wearable,
        })

    # Amaç kullanımı (occasion_group bazında)
    occ_rows = (
        db.query(
            OccasionGroup.name,
            OccasionGroup.emoji,
            func.count(WearHistory.id),
            func.avg(WearHistory.rating),
        )
        .join(
            WearHistory,
            WearHistory.occasion_group_id == OccasionGroup.id,
        )
        .filter(
            WearHistory.user_id == user_id,
            WearHistory.occasion_group_id.isnot(None),
        )
        .group_by(OccasionGroup.id)
        .order_by(func.count(WearHistory.id).desc())
        .all()
    )
    occasion_usage = [
        {
            "name": name,
            "emoji": emoji,
            "wears": int(count),
            "avg_rating": round(float(avg), 1) if avg else None,
        }
        for name, emoji, count, avg in occ_rows
    ]

    wear_total = (
        db.query(func.count(WearHistory.id))
        .filter(WearHistory.user_id == user_id)
        .scalar()
        or 0
    )

    insight_lines = build_wardrobe_insights(
        items=items,
        wearable=wearable,
        dirty=dirty,
        ironing=ironing,
        wear_total=wear_total,
        never_worn=never_worn,
        top_worn=top_worn,
        occasion_usage=occasion_usage,
    )

    return {
        "totals": {
            "items": items,
            "wearable": wearable,
            "dirty": dirty,
            "ironing": ironing,
            "wear_total": wear_total,
        },
        "by_season": [
            {"season": s, "count": n}
            for s, n in sorted(season_counts.items(), key=lambda kv: -kv[1])
        ],
        "by_category": by_category,
        "top_worn": top_worn,
        "never_worn": never_worn,
        "occasion_usage": occasion_usage,
        "insight_lines": insight_lines,
    }


def _plan_dict(plan) -> dict:
    return {
        "event_id": plan.event_id,
        "title": plan.title,
        "kind": plan.kind,
        "event_date": plan.event_date,
        "days_left": plan.days_left,
        "weather_headline": plan.weather_headline,
        "needs_outerwear": plan.needs_outerwear,
        "item_ids": plan.item_ids,
        "message": plan.message,
    }


@router.get("/week")
def week_plan(
    lat: Optional[float] = Query(None, ge=-90, le=90),
    lon: Optional[float] = Query(None, ge=-180, le=180),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Önümüzdeki 7 gün: yaklaşan olaylar + hava + hazır set önerisi.

    lat/lon verilirse olay günleri için Open-Meteo günlük tahmin
    alınır; servis başarısızsa plan hava bilgisi olmadan devam eder.
    """
    from datetime import datetime, timezone

    from models.calendar_event import CalendarEvent
    from week import build_week_plan
    from weather import WeatherError, fetch_daily_forecast

    now = datetime.now(timezone.utc)
    events = (
        db.query(CalendarEvent)
        .filter(
            CalendarEvent.user_id == current_user.id,
            CalendarEvent.event_date >= now,
            CalendarEvent.event_date <= now + timedelta(days=8),
        )
        .all()
    )
    clothes = (
        db.query(Clothing).filter(Clothing.user_id == current_user.id).all()
    )

    forecast_by_date: dict[str, object] = {}
    if lat is not None and lon is not None:
        try:
            forecast_by_date = {
                f.date: f for f in fetch_daily_forecast(lat, lon, days=8)
            }
        except WeatherError:
            forecast_by_date = {}

    plans = build_week_plan(events, clothes, now, forecast_by_date)
    items_by_id = {c.id: c for c in clothes}
    return {
        "generated_at": now,
        "has_forecast": bool(forecast_by_date),
        "plans": [_plan_dict(p) for p in plans],
        "items": [
            {
                "id": items_by_id[i].id,
                "category": items_by_id[i].category,
                "color_name": items_by_id[i].color_name,
                "color": color_hex(items_by_id[i]),
                "image_path": items_by_id[i].image_path,
            }
            for i in sorted({i for p in plans for i in p.item_ids})
            if i in items_by_id
        ],
    }
