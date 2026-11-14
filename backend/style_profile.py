"""Kullanici tarzi profili: giyim gecmisi + kayitli kombinlerden ogrenme.

Veritabanindan bagimsiz, test edilebilir saf mantik. Hedef:
- kullanicinin en cok giydigi kategoriler,
- tercih ettigi renk tonlari (hue kovalari),
- monokrom mu kontrastli mu oldugu,
- imza kombinleri (ust + alt),
bunlarindan bir tarz profili cikarmak ve oneri motorunu
kisisellestiren agirliklar uretmek.
"""
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Optional


# ---- Renk kovalari ---------------------------------------------------------

BUCKET_LABELS = {
    "sicak": "sıcak tonlar (kırmızı-turuncu)",
    "sari": "sarı/hardal tonları",
    "yesil": "yeşil tonlar",
    "mavi": "mavi tonlar",
    "mor": "mor/pembe tonlar",
    "notr": "nötr renkler",
}

NEUTRAL_SATURATION = 15.0   # bu doygunluğun altı nötr sayılır


def hue_bucket(hue: Optional[float], saturation: Optional[float]) -> str:
    """Renk tonunu kova etiketine çevirir (nötr önceliklidir)."""
    if hue is None or saturation is None or saturation < NEUTRAL_SATURATION:
        return "notr"
    h = hue % 360.0
    if h >= 345.0 or h < 30.0:
        return "sicak"
    if h < 75.0:
        return "sari"
    if h < 165.0:
        return "yesil"
    if h < 255.0:
        return "mavi"
    return "mor"


def _circular_hue_distance(a: float, b: float) -> float:
    d = abs(a - b) % 360.0
    return min(d, 360.0 - d)


# ---- Girdi modelleri -------------------------------------------------------

@dataclass
class StyleItem:
    id: int
    category: str
    hue: Optional[float] = None
    saturation: Optional[float] = None
    lightness: Optional[float] = None


@dataclass
class StyleWear:
    clothing_ids: list[int] = field(default_factory=list)
    rating: Optional[float] = None
    worn_at: Optional[datetime] = None


@dataclass
class StyleOutfit:
    clothing_ids: list[int] = field(default_factory=list)
    is_favorite: bool = False


# ---- Profil ----------------------------------------------------------------

@dataclass
class CategoryShare:
    name: str
    count: int
    share: float


@dataclass
class BucketShare:
    bucket: str
    label: str
    count: int
    share: float


@dataclass
class StyleProfile:
    wear_total: int
    confidence: int                       # 0-3: profili ne kadar tanıyoruz
    top_categories: list[CategoryShare] = field(default_factory=list)
    hue_buckets: list[BucketShare] = field(default_factory=list)
    neutral_share: float = 0.0
    contrast: Optional[float] = None      # 0 monokrom .. 1 yüksek kontrast
    signature_pair: Optional[dict] = None # {"top", "alt", "count"}
    summary: list[str] = field(default_factory=list)


MIN_WEAR_FOR_WEIGHTS = 3     # bundan az giyimde kisisellestirme kapali
MIN_PAIRS_FOR_CONTRAST = 3   # kontrast tahmini icin en az birlikte-giyim ikilisi


def build_style_profile(
    items: list[StyleItem],
    wears: list[StyleWear],
    outfits: list[StyleOutfit],
    now: Optional[datetime] = None,
) -> StyleProfile:
    now = now or datetime.now(timezone.utc)
    by_id = {i.id: i for i in items}

    # Kayitli giyimler: gecerli (dolapta hala olan) parcalara filtrele
    wear_counts: dict[str, int] = {}
    bucket_counts: dict[str, int] = {}
    wear_total = 0
    pair_distances: list[float] = []
    category_pairs: dict[tuple[str, str], int] = {}

    for wear in wears:
        worn = [by_id[cid] for cid in wear.clothing_ids if cid in by_id]
        if not worn:
            continue
        wear_total += 1
        rating = wear.rating if wear.rating is not None else 3.0
        weight = max(0.5, min(2.0, rating / 3.0))   # 1 puan 0.5x, 5 puan ~1.7x

        for item in worn:
            wear_counts[item.category] = (
                wear_counts.get(item.category, 0) + weight
            )
            bucket = hue_bucket(item.hue, item.saturation)
            bucket_counts[bucket] = bucket_counts.get(bucket, 0) + weight

        # birlikte giyilen ikililerin ton mesafesi + ust/alt imza ciftleri
        for i, first in enumerate(worn):
            for second in worn[i + 1:]:
                if (first.hue is not None and first.saturation is not None
                        and first.saturation >= NEUTRAL_SATURATION
                        and second.hue is not None
                        and second.saturation is not None
                        and second.saturation >= NEUTRAL_SATURATION):
                    pair_distances.append(
                        _circular_hue_distance(first.hue, second.hue)
                    )
                for (a, b) in ((first, second), (second, first)):
                    ga, gb = a.category, b.category
                    if gb in _ALT_CATEGORIES and ga in _TOP_CATEGORIES:
                        key = (ga, gb)
                        category_pairs[key] = category_pairs.get(key, 0) + 1

    # Favori kombinler hafif pozitif sinyal (giyim yoksa da tarzi yansitir)
    if wear_total == 0:
        for outfit in outfits:
            worn = [by_id[cid] for cid in outfit.clothing_ids if cid in by_id]
            if not worn:
                continue
            weight = 1.2 if outfit.is_favorite else 0.6
            for item in worn:
                wear_counts[item.category] = (
                    wear_counts.get(item.category, 0) + weight
                )
                bucket = hue_bucket(item.hue, item.saturation)
                bucket_counts[bucket] = bucket_counts.get(bucket, 0) + weight

    total_cat_weight = sum(wear_counts.values())
    total_bucket_weight = sum(bucket_counts.values())

    top_categories = sorted(
        (
            CategoryShare(name=name, count=int(round(w)), share=w / total_cat_weight)
            for name, w in wear_counts.items()
            if total_cat_weight
        ),
        key=lambda c: c.share,
        reverse=True,
    )

    hue_buckets = sorted(
        (
            BucketShare(
                bucket=b,
                label=BUCKET_LABELS[b],
                count=int(round(w)),
                share=w / total_bucket_weight,
            )
            for b, w in bucket_counts.items()
            if total_bucket_weight
        ),
        key=lambda c: c.share,
        reverse=True,
    )
    neutral_share = next(
        (b.share for b in hue_buckets if b.bucket == "notr"), 0.0
    )

    contrast: Optional[float] = None
    if len(pair_distances) >= MIN_PAIRS_FOR_CONTRAST:
        mean_dist = sum(pair_distances) / len(pair_distances)
        contrast = min(mean_dist / 120.0, 1.0)

    signature_pair: Optional[dict] = None
    if category_pairs:
        (top_cat, alt_cat), count = max(
            category_pairs.items(), key=lambda kv: kv[1]
        )
        if count >= 2:
            signature_pair = {"top": top_cat, "alt": alt_cat, "count": count}

    confidence = _confidence(wear_total)
    summary = _summary(
        wear_total, top_categories, hue_buckets, contrast, signature_pair
    )

    return StyleProfile(
        wear_total=wear_total,
        confidence=confidence,
        top_categories=top_categories,
        hue_buckets=hue_buckets,
        neutral_share=neutral_share,
        contrast=contrast,
        signature_pair=signature_pair,
        summary=summary,
    )


_TOP_CATEGORIES = {
    "tshirt", "tisort", "gomlek", "bluz", "kazak", "sweatshirt",
    "polo", "atlet", "body", "hoodie", "kapusonlu", "blazer",
}
_ALT_CATEGORIES = {
    "pantolon", "jean", "kot", "etek", "sort", "tayt", "esofman",
}


def _confidence(wear_total: int) -> int:
    if wear_total < MIN_WEAR_FOR_WEIGHTS:
        return 0
    if wear_total < 8:
        return 1
    if wear_total < 20:
        return 2
    return 3


def _summary(
    wear_total: int,
    top_categories: list[CategoryShare],
    hue_buckets: list[BucketShare],
    contrast: Optional[float],
    signature_pair: Optional[dict],
) -> list[str]:
    lines: list[str] = []

    if wear_total < MIN_WEAR_FOR_WEIGHTS:
        lines.append(
            "Birkaç giyim daha kaydet; tarzın netleşince öneriler ona göre şekillenecek."
        )
        return lines

    if len(top_categories) >= 2:
        first, second = top_categories[0], top_categories[1]
        lines.append(
            f"Tarzında {first.name} ve {second.name} öne çıkıyor "
            f"(sırasıyla %{int(round(first.share * 100))} ve "
            f"%{int(round(second.share * 100))})."
        )
    elif top_categories:
        lines.append(f"Tarzında en çok {top_categories[0].name} görünüyor.")

    strong_buckets = [b for b in hue_buckets if b.share >= 0.15][:2]
    if strong_buckets:
        labels = " ve ".join(b.label for b in strong_buckets)
        lines.append(f"Renk tercihinde {labels} öne çıkıyor.")

    if contrast is not None:
        if contrast >= 0.6:
            lines.append("Kontrastlı, dikkat çekici kombinleri seviyorsun.")
        elif contrast <= 0.35:
            lines.append("Aynı tonda, sakin kombinleri seviyorsun.")

    if signature_pair:
        lines.append(
            f"İmza kombin: {signature_pair['top']} + {signature_pair['alt']} "
            f"({signature_pair['count']} kez birlikte)."
        )

    return lines


# ---- Oneri motoru icin agirliklar ------------------------------------------

@dataclass
class StyleWeights:
    """suggest_outfits'a verilen kisisellestirme agirliklari."""

    category_weights: dict[str, float] = field(default_factory=dict)
    hue_buckets: set[str] = field(default_factory=set)


def build_style_weights(profile: StyleProfile) -> Optional[StyleWeights]:
    """Profil yeterli degilse None doner (oneriler tarzsiz calisir)."""
    if profile.wear_total < MIN_WEAR_FOR_WEIGHTS:
        return None

    category_weights = {
        c.name: min(c.share / 0.30, 1.0)          # %30+ pay tam puan
        for c in profile.top_categories
        if c.share >= 0.10
    }

    buckets = {
        b.bucket for b in profile.hue_buckets if b.share >= 0.15
    }
    # yeterince yogun kova yoksa (orn. cok daaginik) en populer 2'si alinir
    if not buckets and profile.hue_buckets:
        buckets = {b.bucket for b in profile.hue_buckets[:2]}

    return StyleWeights(category_weights=category_weights, hue_buckets=buckets)


def style_affinity(
    category: str,
    hue: Optional[float],
    saturation: Optional[float],
    weights: StyleWeights,
) -> float:
    """Tek bir parcanin tarza uygunluk puan (0-1)."""
    cat_score = weights.category_weights.get(
        _norm_category(category), 0.0
    )
    bucket = hue_bucket(hue, saturation)
    hue_score = 1.0 if bucket in weights.hue_buckets else 0.0
    return 0.5 * cat_score + 0.5 * hue_score


_TR = str.maketrans("ıIİşŞğĞüÜöÖçÇ", "iIisSgGuUoOcC")


def _norm_category(name: str) -> str:
    return name.translate(_TR).lower().strip()
