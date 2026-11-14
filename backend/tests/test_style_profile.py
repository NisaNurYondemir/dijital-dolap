from datetime import datetime, timedelta, timezone

from suggestion import suggest_outfits
from style_profile import (
    MIN_WEAR_FOR_WEIGHTS,
    StyleItem,
    StyleOutfit,
    StyleProfile,
    StyleWear,
    StyleWeights,
    build_style_profile,
    build_style_weights,
    hue_bucket,
    style_affinity,
)

NOW = datetime(2026, 11, 14, tzinfo=timezone.utc)


class _Cloth:
    """suggest_outfits'in bekledigi minimal parca."""

    def __init__(self, id, category, hue, sat, season="tum", is_wearable=True):
        self.id = id
        self.category = category
        self.hue = hue
        self.saturation = sat
        self.lightness = 50.0
        self.season = season
        self.is_wearable = is_wearable


# ---- hue_bucket ------------------------------------------------------------

def test_hue_bucket_neutral_first():
    assert hue_bucket(None, None) == "notr"
    assert hue_bucket(220.0, 5.0) == "notr"      # soluk mavi = nötr


def test_hue_bucket_ranges():
    assert hue_bucket(0.0, 60.0) == "sicak"
    assert hue_bucket(350.0, 60.0) == "sicak"
    assert hue_bucket(50.0, 60.0) == "sari"
    assert hue_bucket(120.0, 60.0) == "yesil"
    assert hue_bucket(220.0, 60.0) == "mavi"
    assert hue_bucket(300.0, 60.0) == "mor"


# ---- build_style_profile ---------------------------------------------------

def _sample_items():
    return [
        StyleItem(1, "kazak", hue=10.0, saturation=50.0),    # sicak
        StyleItem(2, "kazak", hue=15.0, saturation=45.0),    # sicak
        StyleItem(3, "jean", hue=220.0, saturation=40.0),    # mavi
        StyleItem(4, "sneaker", hue=40.0, saturation=10.0),  # notr
        StyleItem(5, "gomlek", hue=200.0, saturation=30.0),  # mavi
    ]


def test_profile_counts_categories_and_buckets():
    wears = [
        StyleWear([1, 3, 4], rating=5.0),
        StyleWear([2, 3, 4], rating=4.0),
        StyleWear([1], rating=5.0),
    ]
    p = build_style_profile(_sample_items(), wears, [])
    assert p.wear_total == 3
    assert p.confidence == 1
    assert p.top_categories[0].name == "kazak"    # en agir giyilen kategori
    assert p.top_categories[0].share > p.top_categories[1].share
    buckets = {b.bucket: b.share for b in p.hue_buckets}
    assert buckets["sicak"] > 0


def test_profile_signature_pair():
    wears = [StyleWear([1, 3]), StyleWear([2, 3]), StyleWear([1, 3])]
    p = build_style_profile(_sample_items(), wears, [])
    assert p.signature_pair == {"top": "kazak", "alt": "jean", "count": 3}


def test_profile_contrast_monochrome_vs_contrast():
    mono = [StyleItem(1, "kazak", 210.0, 40.0), StyleItem(2, "jean", 215.0, 40.0)]
    worn_mono = [StyleWear([1, 2])] * 4
    p_mono = build_style_profile(mono, worn_mono, [])
    assert p_mono.contrast is not None and p_mono.contrast < 0.2

    loud = [StyleItem(1, "kazak", 10.0, 60.0), StyleItem(2, "jean", 220.0, 60.0)]
    p_loud = build_style_profile(loud, [StyleWear([1, 2])] * 4, [])
    assert p_loud.contrast > p_mono.contrast


def test_profile_confidence_levels():
    wears = [StyleWear([1])] * MIN_WEAR_FOR_WEIGHTS
    p = build_style_profile(_sample_items(), wears, [])
    assert p.confidence == 1
    p0 = build_style_profile(_sample_items(), [StyleWear([1])], [])
    assert p0.confidence == 0


def test_summary_grows_with_data():
    empty = build_style_profile(_sample_items(), [], [])
    assert "Birkaç giyim daha" in empty.summary[0]

    wears = [
        StyleWear([1, 3, 4], rating=5.0),
        StyleWear([2, 3, 4], rating=5.0),
        StyleWear([1, 3], rating=5.0),
        StyleWear([2, 3, 4], rating=4.0),
    ]
    rich = build_style_profile(_sample_items(), wears, [])
    assert any("Tarzında" in s for s in rich.summary)
    assert any("İmza kombin" in s for s in rich.summary)


# ---- build_style_weights ---------------------------------------------------

def test_weights_none_when_insufficient():
    p = build_style_profile(_sample_items(), [StyleWear([1])], [])
    assert build_style_weights(p) is None


def test_weights_prefers_top_categories_and_buckets():
    wears = [
        StyleWear([1, 3, 4], rating=5.0),
        StyleWear([2, 3, 4], rating=5.0),
        StyleWear([1, 3], rating=5.0),
    ]
    p = build_style_profile(_sample_items(), wears, [])
    w = build_style_weights(p)
    assert isinstance(w, StyleWeights)
    assert w.category_weights.get("kazak", 0) >= w.category_weights.get("gomlek", 0)
    assert "sicak" in w.hue_buckets or "notr" in w.hue_buckets


def test_style_affinity_scoring():
    w = StyleWeights(category_weights={"kazak": 1.0}, hue_buckets={"sicak"})
    assert style_affinity("kazak", 10.0, 50.0, w) == 1.0
    assert style_affinity("gomlek", 220.0, 60.0, w) == 0.0
    assert style_affinity("kazak", 220.0, 60.0, w) == 0.5


# ---- suggest_outfits entegrasyonu ------------------------------------------

def _closet():
    # Renk uyumu acisindan esdeger ustler (ayni hue): tarz fark yaratir
    return [
        _Cloth(1, "kazak", 220.0, 40.0),   # tarza uyumlu ust
        _Cloth(3, "gomlek", 220.0, 40.0),  # tarza uymayan ust
        _Cloth(4, "jean", 220.0, 40.0),
        _Cloth(5, "sneaker", 220.0, 40.0),
    ]


def _wears():
    # kazak agirlikli (3 kez 5 puan), gomlek neredeyse hic giyilmemis
    return [
        StyleWear([1, 3, 4], rating=5.0),
        StyleWear([1, 3, 4], rating=5.0),
        StyleWear([1, 3, 4], rating=5.0),
        StyleWear([1, 5], rating=3.0),
    ]


def test_suggestion_prefers_style_matching_items():
    profile = build_style_profile(_sample_items(), _wears(), [])
    style = build_style_weights(profile)
    personalized = suggest_outfits(
        _closet(), season=None, limit=6, rng=__import__("random").Random(1), style=style
    )
    # Renk uyumlar esitken tarza uygun ust (kazak) on sirada olmali
    assert any(i.category == "kazak" for i in personalized[0].items)
    # 'Tarzına uygun' nedeni (ASCII parcalarla kontrol)
    assert any(
        r.startswith("Tarz") and "uygun" in r
        for s in personalized
        for r in s.reasons
        if any(i.category == "kazak" for i in s.items)
    )


def test_suggestion_without_style_unchanged():
    out1 = suggest_outfits(_closet(), season=None, limit=5, rng=__import__("random").Random(2))
    out2 = suggest_outfits(
        _closet(), season=None, limit=5, rng=__import__("random").Random(2), style=None
    )
    assert [(s.score, [i.id for i in s.items]) for s in out1] == [
        (s.score, [i.id for i in s.items]) for s in out2
    ]
