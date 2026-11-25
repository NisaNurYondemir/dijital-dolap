"""Amaç gruplarının etkinlik tipi.

Kullanıcı "Düğün", "Spor", "İş" gibi kendi gruplarını oluşturabilir.
Öneri motorunun bu grupları anlayabilmesi için her grubun bir etkinlik
tipi olur. Böylece "Düğün" adlı özel grup da resmi kabul edilir.
"""
from typing import Optional

from category_utils import normalize_category

OCCASION_TYPES: tuple[str, ...] = (
    "formal",
    "work",
    "sport",
    "casual",
    "romantic",
)

DEFAULT_OCCASION_TYPE = "casual"

OCCASION_TYPE_LABELS: dict[str, str] = {
    "formal": "Resmi / Özel gün",
    "work": "İş / Ofis",
    "sport": "Spor",
    "casual": "Günlük",
    "romantic": "Romantik",
}

# Sıra önemli: daha özel ifadeler önce gelir.
_NAME_HINTS: tuple[tuple[str, tuple[str, ...]], ...] = (
    (
        "formal",
        (
            "dugun", "nisan", "kina", "nikah", "mezuniyet", "ozelgun",
            "abiye", "gala", "davet", "balo", "sunnet", "kokteyl",
        ),
    ),
    (
        "sport",
        (
            "spor", "antrenman", "kosu", "yoga", "fitness", "tenis",
            "yuzme", "gym", "workout", "pilates", "bisiklet",
        ),
    ),
    (
        "romantic",
        ("romantik", "randevu", "date", "sevgili"),
    ),
)

# "iş" gibi kısa kelimeler başka adların içinde geçebilir; bunları
# yalnızca tam eşleşmede kabul et.
_EXACT_NAME_HINTS: dict[str, str] = {
    "is": "work",
    "ofis": "work",
    "isyeri": "work",
    "staj": "work",
    "mulakat": "work",
    "kariyer": "work",
}


def infer_occasion_type(name: str) -> str:
    """Grup adından etkinlik tipi çıkarır; emin değilse günlük döner."""
    normalized = normalize_category(name)
    if not normalized:
        return DEFAULT_OCCASION_TYPE
    exact = _EXACT_NAME_HINTS.get(normalized)
    if exact:
        return exact
    for occasion_type, hints in _NAME_HINTS:
        if any(hint in normalized for hint in hints):
            return occasion_type
    return DEFAULT_OCCASION_TYPE


def normalize_occasion_type(value: Optional[str]) -> Optional[str]:
    """API'den gelen tipi doğrular; boşsa None, geçersizse hata verir."""
    if value is None:
        return None
    normalized = value.strip().lower()
    if not normalized:
        return None
    if normalized not in OCCASION_TYPES:
        allowed = ", ".join(OCCASION_TYPES)
        raise ValueError(f"Etkinlik tipi şunlardan biri olmalı: {allowed}")
    return normalized
