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


# ---------------------------------------------------------------------------
# Palet ve desen destekli uyum (v2)
#
# Eski `Color`/`relation`/`score_outfit` arayüzü aynen korunur; bu bölüm
# çok renkli parçaları (palet) ve desen bilgisini hesaba katar.
# ---------------------------------------------------------------------------

# Aksesuar deseni ana parçalarla yarışmasın diye düşük ağırlıkla sayılır.
ACCESSORY_LOUDNESS_WEIGHT = 0.3
# Gövde parçalarında (üst/alt/elbise/dış) en fazla bu kadar desenli parça.
BODY_PATTERN_LIMIT = 1
# İki desenli gövde parçası: bilinçli karışım / çakışma skorları.
POWER_CLASH_SCORE = 0.60
PATTERN_CONFLICT_SCORE = 0.35
# Çok renkli iki parça ortak renk paylaşmıyorsa ceza.
MULTI_COLOR_PENALTY = 0.70
# Ortak renk yakalayan çiftler için taban skor.
SHARED_COLOR_SCORE = 0.92
# Palet içi triad toleransı (hue çemberi ±20°).
PALETTE_TRIAD_TOLERANCE = 20

BODY_SCOPES = {"ust", "alt", "elbise", "dis"}


@dataclass(frozen=True)
class ItemProfile:
    """Bir kıyafetin uyum hesabı için sadeleştirilmiş profili."""

    colors: tuple[Color, ...]
    pattern: str = "bilinmiyor"
    pattern_scale: str = "bilinmiyor"
    loudness: float = 0.0
    scope: str = "body"           # "body" | "accessory"

    @classmethod
    def from_item(cls, item, scope: str = "body") -> "ItemProfile":
        colors = tuple(_item_colors(item))
        pattern = getattr(item, "pattern", None) or "bilinmiyor"
        scale = getattr(item, "pattern_scale", None) or "bilinmiyor"
        loud = getattr(item, "pattern_loudness", None)
        if loud is None:
            from pattern_rules import loudness as _loudness

            loud = _loudness(pattern, scale, len(colors))
        return cls(
            colors=colors,
            pattern=pattern,
            pattern_scale=scale,
            loudness=float(loud),
            scope=scope,
        )


def _item_colors(item) -> list[Color]:
    """Kıyafetin paletini (varsa) Color listesine çevirir.

    Palet yoksa eski davranış: tek baskın renk.
    """
    import json

    raw = getattr(item, "palette", None)
    if isinstance(raw, str):
        try:
            raw = json.loads(raw)
        except ValueError:
            raw = None
    colors: list[Color] = []
    if isinstance(raw, list):
        for entry in raw:
            if not isinstance(entry, dict):
                continue
            hue = entry.get("hue")
            sat = entry.get("saturation")
            light = entry.get("lightness")
            if hue is None or sat is None or light is None:
                continue
            colors.append(Color(float(hue), float(sat), float(light)))
    if not colors:
        colors.append(Color.from_item(item))
    return colors


def _valid(color: Color) -> bool:
    return (
        color.hue is not None
        and color.saturation is not None
        and color.lightness is not None
    )


def _chromatic(colors: Sequence[Color]) -> list[Color]:
    return [c for c in colors if _valid(c) and not c.is_neutral]


def _has_neutral(colors: Sequence[Color]) -> bool:
    return any(_valid(c) and c.is_neutral for c in colors)


def palette_harmony(colors: Sequence[Color]) -> str:
    """Bir paletin kendi içindeki renk harmoni profili.

    Dönen değerler: "notr", "mono", "analog", "tamamlayici", "triad", "serbest".
    Triad burada *destekçi* bir profildir; kombin eşleşmesinde zorunlu değildir.
    """
    chromatic = _chromatic(colors)
    if not chromatic:
        return "notr"
    if len(chromatic) == 1:
        return "mono"
    if len(chromatic) == 2:
        diff = hue_difference(chromatic[0].hue, chromatic[1].hue)
        if diff <= ANALOG_MAX_DIFF:
            return "analog"
        if abs(diff - COMPLEMENT_DIFF) <= TOLERANCE:
            return "tamamlayici"
        if abs(diff - TRIAD_DIFF) <= TOLERANCE:
            return "triad"
        return "serbest"

    hues = sorted(c.hue % 360 for c in chromatic)
    gaps = [hues[i + 1] - hues[i] for i in range(len(hues) - 1)]
    gaps.append(360 - hues[-1] + hues[0])
    if len(chromatic) == 3 and all(
        abs(gap - TRIAD_DIFF) <= PALETTE_TRIAD_TOLERANCE for gap in gaps
    ):
        return "triad"
    if all(gap <= ANALOG_MAX_DIFF * 1.5 for gap in gaps):
        return "analog"
    return "serbest"


def _shared_color(a: Sequence[Color], b: Sequence[Color]) -> bool:
    """İki palette ortak bir renk ailesi var mı?"""
    for ca in _chromatic(a):
        for cb in _chromatic(b):
            if hue_difference(ca.hue, cb.hue) <= 20:
                return True
    return _has_neutral(a) and _has_neutral(b)


@dataclass(frozen=True)
class MatchResult:
    score: float
    relation: str


def item_match(a: ItemProfile, b: ItemProfile) -> MatchResult:
    """İki kıyafet profilinin renk uyumu (palet + nötr + triad desteği)."""
    a_valid = [c for c in a.colors if _valid(c)]
    b_valid = [c for c in b.colors if _valid(c)]
    if not a_valid or not b_valid:
        return MatchResult(pair_score(a.colors[0], b.colors[0]).score, "bilinmiyor")

    a_chromatic = _chromatic(a.colors)
    b_chromatic = _chromatic(b.colors)
    if not a_chromatic or not b_chromatic:
        return MatchResult(1.0, "notr")      # biri tamamen nötr: çapa görevi görür

    best = max(
        (pair_score(ca, cb) for ca in a_chromatic for cb in b_chromatic),
        key=lambda r: r.score,
    )
    score, relation = best.score, best.relation

    shared = _shared_color(a.colors, b.colors)
    if shared:
        score = max(score, SHARED_COLOR_SCORE)
        relation = "ortak_renk"
    elif _has_neutral(a.colors) or _has_neutral(b.colors):
        score = min(1.0, score + 0.05)

    # İki parça da çok renkliyse ve ortak renk yoksa çakışma riski yüksek.
    if len(a_chromatic) >= 2 and len(b_chromatic) >= 2 and not shared:
        score *= MULTI_COLOR_PENALTY
        relation = "cok_renkli"

    # Triad destekçi: paletlerden biri triad ise küçük bir bonus.
    if shared and (
        palette_harmony(a.colors) == "triad" or palette_harmony(b.colors) == "triad"
    ):
        score = min(1.0, score + 0.03)

    return MatchResult(round(score, 3), relation)


def outfit_color_score(profiles: Sequence[ItemProfile]) -> float:
    """Kombindeki tüm parça çiftlerinin ortalama renk uyumu."""
    if len(profiles) < 2:
        return 1.0
    scores = [item_match(a, b).score for a, b in combinations(profiles, 2)]
    return sum(scores) / len(scores)


def _power_clash_ok(body: Sequence[ItemProfile]) -> bool:
    """İki desenli gövde parçası bilinçli bir karışım mı?

    Şartlar: farklı desen türü + farklı ölçek + ortak renk.
    """
    from pattern_rules import SCALE_RANK

    for a, b in combinations(body, 2):
        if a.pattern == b.pattern:
            return False
        rank_a = SCALE_RANK.get(a.pattern_scale, 0)
        rank_b = SCALE_RANK.get(b.pattern_scale, 0)
        if not rank_a or not rank_b or rank_a == rank_b:
            return False
        if not _shared_color(a.colors, b.colors):
            return False
    return True


@dataclass(frozen=True)
class PatternRuleResult:
    score: float
    reasons: list[str]


def pattern_rule(profiles: Sequence[ItemProfile]) -> PatternRuleResult:
    """Desen kuralları: gövdede tek desen, aksesuar muaf, loudness dengesi."""
    reasons: list[str] = []
    patterned = [
        p for p in profiles
        if p.loudness > 0 and p.pattern not in ("duz", "bilinmiyor", "")
    ]
    if not patterned:
        return PatternRuleResult(1.0, reasons)

    body = [p for p in patterned if p.scope in BODY_SCOPES or p.scope == "body"]
    accessories = [p for p in patterned if p not in body]

    score = 1.0
    if len(body) > BODY_PATTERN_LIMIT:
        if _power_clash_ok(body):
            score = POWER_CLASH_SCORE
            reasons.append("Bilinçli desen karışımı: farklı ölçek ve ortak renk")
        else:
            score = PATTERN_CONFLICT_SCORE
            reasons.append("İki desenli ana parça birbirini bastırıyor")
    elif body:
        reasons.append("Desenli parça sade parçalarla dengelendi")

    total_loud = sum(
        p.loudness * (1.0 if p.scope in BODY_SCOPES or p.scope == "body"
                      else ACCESSORY_LOUDNESS_WEIGHT)
        for p in profiles
    )
    if total_loud > 1.25:
        score = max(0.2, score - 0.12)
        reasons.append("Desen yoğunluğu fazla")
    if total_loud > 1.6:
        score = max(0.2, score - 0.08)

    # Aksesuar deseni tek başına ceza değil; sadece bilgi olarak eklenir.
    if accessories and total_loud <= 1.25:
        reasons.append("Aksesuar deseni ana parçalarla yarışmıyor")

    return PatternRuleResult(round(score, 3), reasons)


def evaluate_outfit(profiles: Sequence[ItemProfile]) -> tuple[float, float, float, list[str]]:
    """Kombin skorunu (renk + desen) hesaplar.

    Dönen: (toplam, renk_skoru, desen_skoru, desen_gerekceleri).
    Desen bilgisi hiç yoksa toplam skor renk skoruna eşittir (geriye dönük uyum).
    Desen cezası çarpımsaldır; böylece desenli ama uyumlu kombinler şişmez.
    """
    color = outfit_color_score(profiles)
    rule = pattern_rule(profiles)
    has_pattern_info = any(p.pattern not in ("bilinmiyor", "") for p in profiles)
    if not has_pattern_info:
        return color, color, 1.0, []
    total = color * (0.75 + 0.25 * rule.score)
    return total, color, rule.score, rule.reasons