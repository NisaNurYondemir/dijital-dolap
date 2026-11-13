"""Hafta planı: yaklaşan olaylar + hava tahmini + kombin önerisi.

Takvimdeki olayları 7 günlük pencerede ele alır; o günün tahmini
(varsa) ve kullanıcının temiz dolabı ile her olay için kısa bir
hazırlık önerisi üretir. Veritabanından bağımsız, test edilebilir.
"""
from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional

from calendar_insights import FORMAL_KINDS
from weather import DayForecast


@dataclass
class EventPlan:
    """Tek bir yaklaşan olayın hafta planı kartı."""

    event_id: int
    title: str
    kind: str
    event_date: datetime
    days_left: int
    weather_headline: Optional[str]   # "yağmurlu, 9–12°C"
    needs_outerwear: bool = False
    item_ids: list[int] = field(default_factory=list)
    message: str = ""


def _kind_of(event) -> str:
    return getattr(event, "kind", "genel")


def _pick_set(clothes, formal: bool):
    """Formal olay için temiz üst+alt/elbise seti, değilse temiz parçalar."""
    clean = [c for c in clothes if getattr(c, "is_wearable", False)]
    if not formal:
        return clean[:3]

    tops = [c for c in clean if getattr(c, "category", "") in
            ("gomlek", "elbise", "tulum", "blazer", "ceket", "takim elbise")]
    bottoms = [c for c in clean if getattr(c, "category", "") in
               ("pantolon", "jean", "kot", "etek")]
    shoes = [c for c in clean if getattr(c, "category", "") in
             ("ayakkabi", "bot", "sneaker", "topuklu", "sandalet")]

    dress = next((c for c in tops if c.category in ("elbise", "tulum")), None)
    picked: list = []
    if dress is not None:
        picked = [dress]
    elif tops and bottoms:
        picked = [tops[0], bottoms[0]]
    if shoes:
        picked.append(shoes[0])
    return [c for c in picked if c is not None][:3]


def build_week_plan(
    events,
    clothes,
    now: datetime,
    forecast: Optional[dict[str, DayForecast]] = None,
    window_days: int = 7,
) -> list[EventPlan]:
    """Olayları tarihe göre sıralar, hava + içgörü mesajı ekler.

    forecast: {"2026-11-03": DayForecast, ...} — verilmeyen günlerde
    hava alanı None kalır (hesap bozulmaz, sadece hava bilgisi yok).
    """
    forecast = forecast or {}
    plans: list[EventPlan] = []

    for event in sorted(events, key=lambda e: e.event_date):
        delta = event.event_date - now
        days = delta.days
        if delta.total_seconds() < 0 or days > window_days:
            continue

        kind = _kind_of(event)
        formal = kind in FORMAL_KINDS
        day_key = event.event_date.date().isoformat()
        day = forecast.get(day_key)
        items = _pick_set(clothes, formal)

        weather_headline = day.headline() if day is not None else None
        if formal:
            if items:
                message = (
                    f"{event.title} {days} gün sonra: dolabından "
                    f"temiz özel gün setin hazır."
                )
            else:
                message = (
                    f"{event.title} {days} gün sonra: temiz özel gün "
                    f"kombinin eksik; şimdi hazırlan."
                )
        else:
            message = f"{event.title} {days} gün sonra."

        plans.append(EventPlan(
            event_id=getattr(event, "id", 0),
            title=event.title,
            kind=kind,
            event_date=event.event_date,
            days_left=max(days, 0),
            weather_headline=weather_headline,
            needs_outerwear=bool(day and day.needs_outerwear),
            item_ids=[c.id for c in items],
            message=message,
        ))
    return plans
