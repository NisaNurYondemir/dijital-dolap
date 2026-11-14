"""Kombin öneri mantığı (veritabanından bağımsız, test edilebilir).

Renk uyumu temel sinyaldir. Giyim geçmişi varsa:
- yüksek puan verilen parçalar,
- birlikte iyi puanlanan ikililer,
- seçilen amaç için kullanılan parçalar,
- uzun süredir giyilmeyen parçalar
skoru ve açıklama nedenlerini besler.
"""
import random
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Optional

from color_engine import Color, score_outfit
from style_profile import StyleWeights, hue_bucket, style_affinity

MAX_PER_GROUP = 40   # her gruptan en fazla bu kadar parça değerlendirilir

# Kategori adı -> grup eşlemesi (normalize edilmiş adlar: küçük harf, Türkçe
# karakter ve - _ boşluk yok). Kendi kategorilerini buraya ekleyebilirsin.
CATEGORY_GROUPS = {
    "ust": {"tshirt", "tisort", "gomlek", "bluz", "kazak", "sweatshirt",
            "polo", "atlet", "body", "top", "hoodie", "kapusonlu"},
    "alt": {"pantolon", "jean", "kot", "etek", "sort", "tayt", "esofman"},
    "elbise": {"elbise", "tulum", "dress", "takimelbise"},
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
class ItemHistory:
    """Bir kıyafetin geçmiş sinyalleri.

    Global alanlar tüm giyimlerden, occasion_* alanları yalnızca seçilen
    amaç grubundaki giyimlerden beslenir.
    """

    wear_count: int = 0
    rating_sum: float = 0.0
    rating_count: int = 0
    last_worn: Optional[datetime] = None

    occasion_wear_count: int = 0
    occasion_rating_sum: float = 0.0
    occasion_rating_count: int = 0
    occasion_outfit_count: int = 0   # o amaçla kaydedilmiş kombinlerde geçme

    @property
    def rating_avg(self) -> Optional[float]:
        if not self.rating_count:
            return None
        return self.rating_sum / self.rating_count

    @property
    def occasion_rating_avg(self) -> Optional[float]:
        if not self.occasion_rating_count:
            return None
        return self.occasion_rating_sum / self.occasion_rating_count


@dataclass
class PairHistory:
    """İki kıyafetin birlikte giyilme/puanlanma geçmişi."""

    count: int = 0
    rating_sum: float = 0.0
    rating_count: int = 0

    @property
    def rating_avg(self) -> Optional[float]:
        if not self.rating_count:
            return None
        return self.rating_sum / self.rating_count


@dataclass
class WeatherContext:
    """Günün hava durumu özeti (sadece açıklama metni için kullanılır)."""

    headline: str                  # "yağmurlu, 12°C"
    needs_outerwear: bool = False
    rainy: bool = False


@dataclass
class Suggestion:
    items: list
    score: float
    color_score: float = 0.0
    reasons: list[str] = field(default_factory=list)


def _colors(items) -> list[Color]:
    return [Color.from_item(i) for i in items]


def _is_candidate(item, season: Optional[str]) -> bool:
    if not item.is_wearable:
        return False
    return season is None or item.season in (season, "tum")


def _best_addition(base: list, candidates: list):
    """Kombine eklenince toplam uyum skorunu en yüksek yapan parçayı seçer."""
    return max(candidates, key=lambda c: score_outfit(_colors(base + [c])))


def _rating_pref(avg: float) -> float:
    """1-5 puanı 0-1 tercih ağırlığına çevirir (3 puan nötre yakın)."""
    return max(0.0, min(1.0, (avg - 1.0) / 4.0))


def _item_preference(
    history: Optional[ItemHistory],
    use_occasion: bool,
) -> float:
    if history is None:
        return 0.5
    if history.rating_count:
        base = _rating_pref(history.rating_avg)
    elif history.wear_count:
        # Puan verilmemiş ama sık giyilen parça hafif pozitif sinyaldir.
        base = min(0.5 + 0.05 * history.wear_count, 0.75)
    else:
        base = 0.5

    if use_occasion:
        if history.occasion_rating_count:
            occ = _rating_pref(history.occasion_rating_avg)
            return 0.6 * base + 0.4 * occ
        if history.occasion_wear_count:
            occ = min(0.5 + 0.05 * history.occasion_wear_count, 0.8)
            return 0.6 * base + 0.4 * occ
    return base


def _pair_preference(
    items: list,
    pair_history: Optional[dict[tuple[int, int], PairHistory]],
) -> float:
    if not pair_history:
        return 0.5
    values: list[float] = []
    for i, first in enumerate(items):
        for second in items[i + 1:]:
            key = tuple(sorted((first.id, second.id)))
            pair = pair_history.get(key)
            if pair and pair.rating_count:
                values.append(_rating_pref(pair.rating_avg))
    if not values:
        return 0.5
    return sum(values) / len(values)


def _days_since(worn_at: Optional[datetime], now: datetime) -> Optional[float]:
    if worn_at is None:
        return None
    if worn_at.tzinfo is None:
        worn_at = worn_at.replace(tzinfo=timezone.utc)
    if now.tzinfo is None:
        now = now.replace(tzinfo=timezone.utc)
    return max((now - worn_at).total_seconds() / 86400.0, 0.0)


def _rotation_score(
    history: Optional[ItemHistory],
    now: datetime,
) -> float:
    """Yeni/uzun süredir giyilmeyen parçalara küçük bir dolaşım bonusu."""
    if history is None or history.last_worn is None:
        return 1.0
    days = _days_since(history.last_worn, now)
    if days is None:
        return 1.0
    if days < 3:
        return 0.0
    if days < 7:
        return 0.3
    if days < 14:
        return 0.6
    return 1.0


def _pair_average_rating(
    items: list,
    pair_history: Optional[dict[tuple[int, int], PairHistory]],
) -> Optional[float]:
    if not pair_history:
        return None
    values: list[float] = []
    for i, first in enumerate(items):
        for second in items[i + 1:]:
            pair = pair_history.get(tuple(sorted((first.id, second.id))))
            if pair and pair.rating_count:
                values.append(pair.rating_avg)
    if not values:
        return None
    return sum(values) / len(values)


def _reasons(
    items: list,
    color_score: float,
    history: Optional[dict[int, ItemHistory]],
    pair_history: Optional[dict[tuple[int, int], PairHistory]],
    occasion_name: Optional[str],
    now: datetime,
    weather: Optional[WeatherContext] = None,
    style_aff: Optional[float] = None,
) -> list[str]:
    reasons: list[str] = []
    if weather is not None:
        reasons.append(f"Bugün hava: {weather.headline}")
        if weather.needs_outerwear:
            reasons.append("Soğuk görünüyor; mont veya ceket iyi gelir")
    if color_score >= 0.85:
        reasons.append("Renkler birbiriyle çok uyumlu")
    elif color_score >= 0.7:
        reasons.append("Renk uyumu iyi")

    if style_aff is not None and style_aff >= 0.7:
        reasons.append("Tarzına uygun parçalar")

    histories = []
    if history:
        histories = [history.get(item.id) for item in items]
        histories = [h for h in histories if h is not None]

    if occasion_name:
        if any(
            h.occasion_rating_count and h.occasion_rating_avg >= 4
            for h in histories
        ):
            reasons.append(f"{occasion_name} için yüksek puanladığın parçalar")
        elif any(h.occasion_wear_count for h in histories):
            reasons.append(f"{occasion_name} için daha önce giydiğin parçalar")
        elif any(h.occasion_outfit_count for h in histories):
            reasons.append(f"{occasion_name} kombinlerinde kullandığın parçalar")
        else:
            reasons.append(f"{occasion_name} için yeni bir kombin")

    pair_avg = _pair_average_rating(items, pair_history)
    if pair_avg is not None and pair_avg >= 4:
        reasons.append("Birlikte iyi puanladığın bir ikili")

    rated = [h.rating_avg for h in histories if h.rating_count]
    if rated and sum(rated) / len(rated) >= 4:
        reasons.append("Daha önce yüksek puan verdiğin parçalar")

    if history:
        item_histories = [history.get(item.id) for item in items]
        if all(h is None or h.last_worn is None for h in item_histories):
            reasons.append("Dolabında hiç giyilmemiş parçalar")
        else:
            days = [
                _days_since(h.last_worn, now)
                for h in item_histories
                if h is not None and h.last_worn is not None
            ]
            if days and min(days) >= 21:
                reasons.append("Uzun süredir giyilmeyen parçalar")

    if not reasons:
        reasons.append("Yeni bir kombin denemesi")

    # Tekrarları koru, en fazla üç neden göster.
    unique: list[str] = []
    for reason in reasons:
        if reason not in unique:
            unique.append(reason)
    return unique[:3]


def suggest_outfits(
    clothes,
    season: Optional[str] = None,
    limit: int = 5,
    include_shoes: bool = True,
    include_outerwear: bool = False,
    rng: Optional[random.Random] = None,
    history: Optional[dict[int, ItemHistory]] = None,
    pair_history: Optional[dict[tuple[int, int], PairHistory]] = None,
    occasion_name: Optional[str] = None,
    now: Optional[datetime] = None,
    weather: Optional[WeatherContext] = None,
    style: Optional[StyleWeights] = None,
) -> list[Suggestion]:
    rng = rng or random.Random()
    now = now or datetime.now(timezone.utc)
    use_occasion = bool(occasion_name)
    history = history or None

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

    max_affinity = 0
    if history and use_occasion:
        max_affinity = max(
            (h.occasion_outfit_count for h in history.values()),
            default=0,
        )

    suggestions = []
    for base in bases:
        outfit = list(base)
        if include_outerwear and groups["dis"]:
            outfit.append(_best_addition(outfit, groups["dis"]))
        if include_shoes and groups["ayakkabi"]:
            outfit.append(_best_addition(outfit, groups["ayakkabi"]))

        color = score_outfit(_colors(outfit))
        item_histories = [
            history.get(item.id) if history else None for item in outfit
        ]
        item_pref = sum(
            _item_preference(h, use_occasion) for h in item_histories
        ) / len(outfit)
        pair_pref = _pair_preference(outfit, pair_history)

        affinity = 0.0
        if use_occasion and max_affinity:
            affinity = sum(
                (h.occasion_outfit_count if h else 0) / max_affinity
                for h in item_histories
            ) / len(outfit)

        # Tarz kisisellestirmesi: parcanin kullanici tarzina uygunlugu
        style_aff = None
        if style is not None:
            style_aff = sum(
                style_affinity(
                    item.category, item.hue, item.saturation, style
                )
                for item in outfit
            ) / len(outfit)

        if not history and not pair_history and not use_occasion:
            if style is not None:
                # Gecmis sinyali yoksa tarz tek etken olarak kullanilir.
                score = color * (0.85 + 0.15 * style_aff)
            else:
                # Geçmiş yokken eski davranış korunur: yalnızca renk uyumu.
                score = color
        else:
            rotation = (
                sum(_rotation_score(h, now) for h in item_histories)
                / len(outfit)
                if history
                else 0.5
            )
            if style is not None:
                preference = (
                    0.45 * item_pref
                    + 0.18 * pair_pref
                    + 0.12 * rotation
                    + 0.10 * affinity
                    + 0.15 * style_aff
                )
            else:
                preference = (
                    0.50 * item_pref
                    + 0.20 * pair_pref
                    + 0.15 * rotation
                    + 0.15 * affinity
                )
            score = color * (0.80 + 0.20 * preference)
        score = min(score, 1.0)

        suggestions.append(
            Suggestion(
                items=outfit,
                score=score,
                color_score=color,
                reasons=_reasons(
                    outfit,
                    color,
                    history,
                    pair_history,
                    occasion_name,
                    now,
                    weather=weather,
                    style_aff=style_aff,
                ),
            )
        )

    suggestions.sort(key=lambda s: s.score, reverse=True)
    return suggestions[:limit]
