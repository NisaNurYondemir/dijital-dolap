"""Kombin öneri mantığı (veritabanından bağımsız, test edilebilir)."""
import random
from dataclasses import dataclass
from typing import Optional

from color_engine import Color, score_outfit

MAX_PER_GROUP = 40   # her gruptan en fazla bu kadar parça değerlendirilir

# Kategori adı -> grup eşlemesi (normalize edilmiş adlar: küçük harf, Türkçe
# karakter ve - _ boşluk yok). Kendi kategorilerini buraya ekleyebilirsin.
CATEGORY_GROUPS = {
    "ust": {"tshirt", "tisort", "gomlek", "bluz", "kazak", "sweatshirt",
            "polo", "atlet", "body", "top"},
    "alt": {"pantolon", "jean", "kot", "etek", "sort", "tayt", "esofman"},
    "elbise": {"elbise", "tulum", "dress"},
    "dis": {"ceket", "mont", "kaban", "hirka", "blazer", "trenckot", "yelek"},
    "ayakkabi": {"ayakkabi", "sneaker", "bot", "cizme", "sandalet",
                 "terlik", "topuklu"},
}

_TR = str.maketrans("İIıŞşĞğÜüÖöÇç", "iiissgguuoocc")


def normalize(text: str) -> str:
    text = text.translate(_TR).lower()
    for ch in (" ", "-", "_"):
        text = text.replace(ch, "")
    return text.strip()


def group_of(category: str) -> Optional[str]:
    name = normalize(category)
    for group, names in CATEGORY_GROUPS.items():
        if name in names:
            return group
    return None


@dataclass
class Suggestion:
    items: list
    score: float


def _colors(items) -> list[Color]:
    return [Color.from_item(i) for i in items]


def _is_candidate(item, season: Optional[str]) -> bool:
    if not item.is_wearable:
        return False
    return season is None or item.season in (season, "tum")


def _best_addition(base: list, candidates: list):
    """Kombine eklenince toplam uyum skorunu en yüksek yapan parçayı seçer."""
    return max(candidates, key=lambda c: score_outfit(_colors(base + [c])))


def suggest_outfits(
    clothes,
    season: Optional[str] = None,
    limit: int = 5,
    include_shoes: bool = True,
    include_outerwear: bool = False,
    rng: Optional[random.Random] = None,
) -> list[Suggestion]:
    rng = rng or random.Random()

    groups: dict[str, list] = {g: [] for g in CATEGORY_GROUPS}
    for item in clothes:
        if not _is_candidate(item, season):
            continue
        group = group_of(item.category)
        if group:
            groups[group].append(item)

    for items in groups.values():
        rng.shuffle(items)          # eşit skorlarda her seferinde farklı sonuç
        del items[MAX_PER_GROUP:]

    # Temel kombinler: üst + alt ya da tek parça elbise
    bases = [[u, a] for u in groups["ust"] for a in groups["alt"]]
    bases += [[e] for e in groups["elbise"]]

    suggestions = []
    for base in bases:
        outfit = list(base)
        if include_outerwear and groups["dis"]:
            outfit.append(_best_addition(outfit, groups["dis"]))
        if include_shoes and groups["ayakkabi"]:
            outfit.append(_best_addition(outfit, groups["ayakkabi"]))
        suggestions.append(Suggestion(outfit, score_outfit(_colors(outfit))))

    suggestions.sort(key=lambda s: s.score, reverse=True)
    return suggestions[:limit]