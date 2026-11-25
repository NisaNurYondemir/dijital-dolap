"""Etkinlik tipine göre parça ve kombin uygunluğu.

İki seviye vardır:

1. **Sert engel**: Topuklu ayakkabı + spor, eşofman + resmi etkinlik gibi
   bariz uyuşmazlıklar. Bu parçalar aday listesine hiç girmez.
2. **Yumuşak ceza**: Sneaker + resmi etkinlik gibi tartışmalı durumlar.
   Parça önerilebilir ama skoru düşer.

Kurallar kullanıcıya açıklanabilir ve test edilebilir olsun diye tablo
hâlinde tutulur; öğrenilmiş model sonraki katmanda devreye girer.
"""
from typing import Iterable, Optional

from category_utils import normalize_category
from occasion_types import OCCASION_TYPE_LABELS, OCCASION_TYPES

ALLOWED = 1.0
SOFT = 0.45
BLOCKED = 0.0

# Gerçek aksesuarlar: kombin skoruna 0,3 ağırlıkla girer. Ayakkabılar
# burada değil; onlar kombin için işlevsel parçadır ve tam ağırlık alır.
ACCESSORY_CATEGORIES = {
    "sapka", "sal", "atki", "bere", "kemer", "canta", "taki", "gozluk",
}
ACCESSORY_WEIGHT = 0.3

# Etkinlik tipine göre hiç önerilmeyecek kategoriler.
OCCASION_BLOCKED: dict[str, set[str]] = {
    "formal": {
        "esofman", "sweatshirt", "hoodie", "kapusonlu",
        "sort", "tayt", "atlet", "iccamasir", "iccamasiri",
        "terlik", "pijama", "gecelik", "mayo",
    },
    "sport": {
        "topuklu", "sandalet", "terlik", "cizme", "blazer", "takimelbise",
        "sal", "taki", "gomlek", "bluz", "jean", "kot", "pantolon",
        "elbise", "tulum", "kemer", "iccamasir", "iccamasiri",
        "pijama", "gecelik", "mayo",
    },
    "work": {
        "esofman", "sort", "tayt", "atlet", "iccamasir", "iccamasiri",
        "terlik", "pijama", "gecelik", "mayo",
    },
    "casual": {
        "iccamasir", "iccamasiri", "pijama", "gecelik", "mayo",
    },
    "romantic": {
        "esofman", "atlet", "iccamasir", "iccamasiri",
        "terlik", "pijama", "gecelik", "mayo",
    },
}

# Tartışmalı ama tamamen yasak olmayan kategoriler: önerilebilir, skoru düşer.
OCCASION_SOFT: dict[str, set[str]] = {
    "formal": {
        "tshirt", "tisort", "polo", "top", "jean", "kot",
        "sneaker", "sandalet", "sapka", "bere",
    },
    "sport": {
        "bot", "ceket", "kazak", "etek", "canta",
    },
    "work": {
        "hoodie", "sweatshirt", "kapusonlu", "tshirt", "tisort",
        "top", "jean", "kot", "sneaker", "sandalet", "sal", "sapka",
        "bere",
    },
    "casual": set(),
    "romantic": {
        "sweatshirt", "hoodie", "kapusonlu", "top", "sort",
        "tshirt", "tisort", "jean", "kot", "sneaker", "sapka", "bere",
    },
}

# Resmi kombinde en az bir "akıllı" parça bulunmalı. Böylece tişört +
# jean + sneaker gibi bir kombin düğüne önerilmez.
FORMAL_ANCHORS = {
    "gomlek", "bluz", "kazak", "ceket", "blazer", "elbise", "tulum",
    "takimelbise", "etek", "yelek", "topuklu", "bot", "body",
}


def _normalized_tokens(items: Iterable) -> list[str]:
    return [normalize_category(getattr(item, "category", "")) for item in items]


def item_occasion_fit(category: str, occasion_type: Optional[str]) -> float:
    """Bir parçanın etkinliğe uygunluk puanı: 1.0 / 0.45 / 0.0."""
    if not occasion_type:
        return ALLOWED
    name = normalize_category(category)
    if name in OCCASION_BLOCKED.get(occasion_type, set()):
        return BLOCKED
    if name in OCCASION_SOFT.get(occasion_type, set()):
        return SOFT
    return ALLOWED


def is_blocked(category: str, occasion_type: Optional[str]) -> bool:
    return item_occasion_fit(category, occasion_type) == BLOCKED


def outfit_occasion_fit(items: Iterable, occasion_type: Optional[str]) -> float:
    """Kombin bütününün etkinliğe uygunluğu (0..1).

    0 dönerse kombin hiç önerilmemeli. Resmi etkinliklerde en az bir
    formal çapa aranır. Aksesuarlar 0,3 ağırlıkla, gövde ve ayakkabılar
    tam ağırlıkla değerlendirilir.
    """
    if not occasion_type:
        return 1.0
    item_list = list(items)
    if not item_list:
        return BLOCKED

    names = _normalized_tokens(item_list)
    scores = [item_occasion_fit(n, occasion_type) for n in names]
    if any(score == BLOCKED for score in scores):
        return BLOCKED
    if occasion_type == "formal" and not any(
        name in FORMAL_ANCHORS for name in names
    ):
        return BLOCKED

    weighted_sum = 0.0
    weight_sum = 0.0
    body_scores: list[float] = []
    for name, score in zip(names, scores):
        weight = ACCESSORY_WEIGHT if name in ACCESSORY_CATEGORIES else 1.0
        weighted_sum += score * weight
        weight_sum += weight
        if name not in ACCESSORY_CATEGORIES:
            body_scores.append(score)

    average = weighted_sum / weight_sum if weight_sum else BLOCKED
    lowest_body = min(body_scores) if body_scores else average
    # Tek bir uygunsuz parça kombini belirgin şekilde aşağı çeksin.
    fit = 0.65 * average + 0.35 * lowest_body
    return max(0.0, min(1.0, fit))


def occasion_label(occasion_type: Optional[str]) -> str:
    if not occasion_type:
        return ""
    return OCCASION_TYPE_LABELS.get(occasion_type, occasion_type)


def is_valid_occasion_type(value: Optional[str]) -> bool:
    return value is None or value in OCCASION_TYPES
