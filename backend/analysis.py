"""Kıyafet analizi yardımcıları: renk adı ve mevsim önerisi."""
from typing import Optional

from color_engine import (
    BLACK_LIGHTNESS_MAX,
    NEUTRAL_SATURATION_MAX,
    WHITE_LIGHTNESS_MIN,
)

# Hue (0-360) bu sınırın altındaysa karşısındaki ad kullanılır
_HUE_NAMES = [
    (15, "kırmızı"),
    (45, "turuncu"),
    (70, "sarı"),
    (165, "yeşil"),
    (200, "turkuaz"),
    (255, "mavi"),
    (290, "mor"),
    (345, "pembe"),
    (360, "kırmızı"),
]

_SEASON_BY_CATEGORY = {
    "tshirt": "yaz", "sort": "yaz", "sandalet": "yaz",
    "kazak": "kis", "hoodie": "kis", "mont": "kis", "bot": "kis", "sal": "kis",
    "ceket": "sonbahar",
}


def color_name(
    hue: Optional[float],
    saturation: Optional[float],
    lightness: Optional[float],
) -> Optional[str]:
    """HSL değerinden Türkçe renk adı üretir."""
    if hue is None or saturation is None or lightness is None:
        return None
    if lightness <= BLACK_LIGHTNESS_MAX:
        return "siyah"
    if lightness >= WHITE_LIGHTNESS_MIN:
        return "beyaz"
    if saturation <= NEUTRAL_SATURATION_MAX:
        return "gri"

    h = hue % 360
    name = next(n for limit, n in _HUE_NAMES if h < limit)

    if name == "turuncu" and lightness < 40:
        return "kahverengi"
    if name == "mavi" and lightness < 30:
        return "lacivert"
    if lightness >= 75:
        return f"açık {name}"
    if lightness <= 25:
        return f"koyu {name}"
    return name


def suggest_season(category: str) -> str:
    """Kategoriye göre varsayılan mevsim; kullanıcı formda değiştirebilir."""
    return _SEASON_BY_CATEGORY.get(category, "tum")