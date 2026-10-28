"""Takvim olaylarından hazırlık uyarıları (veritabanından bağımsız).

Olay bağlamcı değil davranış ağırlıklıdır: olay yakınlaştıkça (30 gün
penceresi) kullanıcının dolabındaki "temiz, uygunda" parçalar soyut bir
hazırlık sinyali üretir ve Türkçe ipucu döner.
"""
from dataclasses import dataclass
from datetime import datetime
from typing import Optional

FORMAL_KINDS = {
    "dugun",
    "nisan",
    "kina",
    "nikah",
    "mezuniyet",
    "ozel_gun",
    "ozel gun",
    "kiyafet gerektirir",
}

# Formal sıralı olaylarda kabul edilebilir "üst/dış" ve "alt" kategoriler.
FORMAL_TOP_CATEGORIES = {"gomlek", "elbise", "tulum", "blazer", "ceket",
                         "mont", "takim elbise", "sal", "tshirt"}
FORMAL_BOTTOM_CATEGORIES = {"pantolon", "jean", "kot", "etek", "sort", "tayt",
                            "esofman"}

WARNING_DAYS = 30


@dataclass
class EventInsight:
    event_id: int
    title: str
    kind: str
    event_date: datetime
    days_left: int
    ready: bool
    message: str


def _clean(items) -> list:
    """Yalnız giyilebilir (temiz, ütüsü hazır) parçalar."""
    return [i for i in items if getattr(i, "is_wearable", False)]


def _has_formal_set(clothes) -> bool:
    """Formal üst/elbise + uygun alt yok mu?"""
    tops = [c for c in clothes if c.category in FORMAL_TOP_CATEGORIES]
    has_dress = any(c.category in ("elbise", "tulum") for c in tops)
    has_bottom = [c for c in clothes if c.category in FORMAL_BOTTOM_CATEGORIES]
    if has_dress:
        return True
    return bool(tops) and bool(has_bottom)


def event_insights(
    events,
    clothes,
    now: datetime,
    saved_occasion_ids: Optional[set[int]] = None,
    window_days: int = WARNING_DAYS,
) -> list[EventInsight]:
    """Yaklaşan olaylar için hazırlık ipuçları üretir.

    - Geçmiş ve `window_days` ötesindeki olaylar atlanır.
    - Formal türler (düğün/nişan/kına/...) temiz dolap setleri ister;
      diğer türlerde zamanı hatırlatmak yeterli sayılır.
    """
    saved_occasion_ids = saved_occasion_ids or set()
    clean = _clean(clothes)

    insights: list[EventInsight] = []
    for event in sorted(events, key=lambda e: e.event_date):
        delta = event.event_date - now
        days = delta.days
        if delta.total_seconds() < 0 or days > window_days:
            continue

        kind = getattr(event, "kind", "genel")
        is_formal = kind in FORMAL_KINDS
        has_linked_outfit = (
            event.occasion_group_id is not None
            and event.occasion_group_id in saved_occasion_ids
        )

        if has_linked_outfit:
            ready = True
            message = f"{event.title} {days} gün sonra: bu amaç için kaydedilmiş bir kombin var."
        elif is_formal:
            ready = _has_formal_set(clean)
            message = (
                f"{event.title} {days} gün sonra: dolabında temiz özel gün parçaları var."
                if ready
                else f"{event.title} {days} gün sonra: temiz özel gün kombinleri eksik; önerileri şimdi kontrol et."
            )
        else:
            ready = True
            message = f"{event.title} {days} gün sonra: kıyafet hazırlığı için ipuçlarını gösterebilirsin."

        insights.append(
            EventInsight(
                event_id=getattr(event, "id", 0),
                title=event.title,
                kind=kind,
                event_date=event.event_date,
                days_left=max(days, 0),
                ready=ready,
                message=message,
            )
        )
    return insights
