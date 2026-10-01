"""Renk uyum motoru.

HSL değerlerinden renk çemberi kurallarına göre (analog, tamamlayıcı, triad)
iki renk ya da bir kombin için uyum skoru (0-1) üretir.
"""
from dataclasses import dataclass
from itertools import combinations
from typing import NamedTuple, Optional, Sequence

# --- Ayarlanabilir eşikler (raporda gerekçelendirilebilir) ---
NEUTRAL_SATURATION_MAX = 12   # doygunluk bunun altındaysa gri tonu
BLACK_LIGHTNESS_MAX = 12      # parlaklık bunun altındaysa siyaha yakın
WHITE_LIGHTNESS_MIN = 90      # parlaklık bunun üstündeyse beyaza yakın

ANALOG_MAX_DIFF = 30          # hue farkı <= 30°  -> analog
COMPLEMENT_DIFF = 180         # hue farkı ~180°   -> tamamlayıcı
TRIAD_DIFF = 120              # hue farkı ~120°   -> triad
TOLERANCE = 15                # tamamlayıcı ve triad için ± pay (derece)

# İlişki türüne göre uyum skoru
SCORES = {
    "notr": 1.0,          # siyah, beyaz, gri: her renkle uyumlu
    "tamamlayici": 0.9,
    "analog": 0.85,
    "triad": 0.8,
    "bilinmiyor": 0.5,    # renk bilgisi girilmemiş kıyafet
    "uyumsuz": 0.2,
}


@dataclass(frozen=True)
class Color:
    hue: Optional[float]          # 0-360
    saturation: Optional[float]   # 0-100
    lightness: Optional[float]    # 0-100

    @classmethod
    def from_item(cls, item) -> "Color":
        """hue, saturation, lightness alanlarına sahip herhangi bir nesneden
        (örneğin Clothing modeli) Color üretir."""
        return cls(item.hue, item.saturation, item.lightness)

    @property
    def is_neutral(self) -> bool:
        if self.saturation is not None and self.saturation <= NEUTRAL_SATURATION_MAX:
            return True
        if self.lightness is not None and (
            self.lightness <= BLACK_LIGHTNESS_MAX
            or self.lightness >= WHITE_LIGHTNESS_MIN
        ):
            return True
        return False


class PairResult(NamedTuple):
    relation: str
    score: float


def hue_difference(h1: float, h2: float) -> float:
    """Renk çemberinde iki hue arasındaki en kısa mesafe (0-180)."""
    d = abs(h1 - h2) % 360
    return min(d, 360 - d)


def relation(a: Color, b: Color) -> str:
    if a.is_neutral or b.is_neutral:
        return "notr"
    if a.hue is None or b.hue is None:
        return "bilinmiyor"

    diff = hue_difference(a.hue, b.hue)
    if diff <= ANALOG_MAX_DIFF:
        return "analog"
    if abs(diff - COMPLEMENT_DIFF) <= TOLERANCE:
        return "tamamlayici"
    if abs(diff - TRIAD_DIFF) <= TOLERANCE:
        return "triad"
    return "uyumsuz"


def pair_score(a: Color, b: Color) -> PairResult:
    rel = relation(a, b)
    return PairResult(rel, SCORES[rel])


def score_outfit(colors: Sequence[Color]) -> float:
    """Kombindeki tüm çiftlerin uyum skorlarının ortalaması.
    Tek parçalık kombinde çakışacak bir şey olmadığı için 1.0 döner."""
    if len(colors) < 2:
        return 1.0
    scores = [pair_score(a, b).score for a, b in combinations(colors, 2)]
    return sum(scores) / len(scores)