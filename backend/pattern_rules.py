"""Desen türleri, adları ve desen "gürültü" (loudness) hesabı.

Bu modül bilinçli olarak yalnızca saf Python içerir: CLIP/torch gibi ağır
bağımlılıklar `pattern.py` içinde kalır. Böylece kural motoru ve testler
model yüklemeden çalışabilir.
"""
from typing import Optional

# Veritabanında ve API'de kullanılan desen anahtarları (Türkçe).
PATTERN_TYPES = [
    "duz",
    "cizgili",
    "ekose",
    "puantiyeli",
    "cicekli",
    "geometrik",
    "hayvan",
    "baskili",
    "diger",
    "bilinmiyor",
]

PATTERN_NAMES = {
    "duz": "düz",
    "cizgili": "çizgili",
    "ekose": "ekose",
    "puantiyeli": "puantiyeli",
    "cicekli": "çiçekli",
    "geometrik": "geometrik",
    "hayvan": "hayvan desenli",
    "baskili": "baskılı",
    "diger": "dokulu/desenli",
    "bilinmiyor": "bilinmiyor",
}

# Desen ölçeği (yalnızca periyodik desenlerde anlamlı).
PATTERN_SCALES = ["ince", "orta", "iri", "bilinmiyor"]
SCALE_NAMES = {"ince": "ince", "orta": "orta", "iri": "iri", "bilinmiyor": "bilinmiyor"}
SCALE_RANK = {"ince": 1, "orta": 2, "iri": 3}

# Desen türünün temel görsel ağırlığı (0-1).
_BASE_LOUDNESS = {
    "duz": 0.0,
    "cizgili": 0.55,
    "ekose": 0.68,
    "puantiyeli": 0.60,
    "cicekli": 0.70,
    "geometrik": 0.72,
    "hayvan": 0.80,
    "baskili": 0.78,
    "diger": 0.50,
    "bilinmiyor": 0.0,
}

# Ölçek çarpanı: ince desen uzaktan neredeyse düz okunur, iri desen baskındır.
_SCALE_FACTOR = {"ince": 0.85, "orta": 1.0, "iri": 1.15, "bilinmiyor": 1.0}

# Çok renklilik deseni daha "gürültülü" yapar.
_MULTI_COLOR_BONUS = {2: 0.04, 3: 0.08}


def loudness(
    pattern: Optional[str],
    scale: Optional[str] = "bilinmiyor",
    color_count: int = 1,
) -> float:
    """Bir parçanın görsel desen ağırlığını 0-1 aralığında döndürür.

    Düz parçalar 0 döner; böylece desen kuralında hiç sayılmazlar.
    """
    base = _BASE_LOUDNESS.get(pattern or "bilinmiyor", 0.0)
    if base <= 0:
        return 0.0
    value = base * _SCALE_FACTOR.get(scale or "bilinmiyor", 1.0)
    value += _MULTI_COLOR_BONUS.get(min(color_count, 3), 0.0)
    return round(min(1.0, value), 2)
