import random
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

from suggestion import ItemHistory, PairHistory, WeatherContext, suggest_outfits


def item(item_id, category, hue=0, sat=80, light=50, season="tum", wearable=True):
    return SimpleNamespace(
        id=item_id,
        category=category,
        season=season,
        hue=hue,
        saturation=sat,
        lightness=light,
        is_wearable=wearable,
    )


def rng():
    return random.Random(0)


NOW = datetime(2026, 10, 25, 12, 0, tzinfo=timezone.utc)


def history(*, rating=None, last_days=None, occasion_rating=None, affinity=0):
    h = ItemHistory()
    if rating is not None:
        h.rating_count = 1
        h.rating_sum = rating
    if last_days is not None:
        h.last_worn = NOW - timedelta(days=last_days)
    if occasion_rating is not None:
        h.occasion_rating_count = 1
        h.occasion_rating_sum = occasion_rating
    h.occasion_outfit_count = affinity
    return h


def test_higher_rated_item_is_preferred_when_color_is_equal():
    top = item(1, "tshirt", hue=0)
    loved = item(2, "pantolon", hue=0, sat=0, light=5)
    disliked = item(3, "pantolon", hue=0, sat=0, light=95)

    result = suggest_outfits(
        [top, loved, disliked],
        rng=rng(),
        history={
            2: history(rating=5, last_days=30),
            3: history(rating=1, last_days=30),
        },
        now=NOW,
    )

    assert loved in result[0].items
    assert result[0].score > result[1].score
    assert "Daha önce yüksek puan verdiğin parçalar" in result[0].reasons


def test_occasion_history_prefers_items_worn_for_that_occasion():
    top = item(1, "tshirt", hue=0)
    work = item(2, "pantolon", hue=0, sat=0, light=5)
    casual = item(3, "pantolon", hue=0, sat=0, light=95)

    result = suggest_outfits(
        [top, work, casual],
        rng=rng(),
        history={
            2: history(occasion_rating=5),
            3: history(occasion_rating=1),
        },
        occasion_name="İş",
        now=NOW,
    )

    assert work in result[0].items
    assert result[0].score > result[1].score
    assert "İş için yüksek puanladığın parçalar" in result[0].reasons


def test_saved_outfit_affinity_is_used_for_occasion():
    top = item(1, "tshirt", hue=0)
    in_work_outfit = item(2, "pantolon", hue=0, sat=0, light=5)
    other = item(3, "pantolon", hue=0, sat=0, light=95)

    result = suggest_outfits(
        [top, in_work_outfit, other],
        rng=rng(),
        history={2: history(affinity=2), 3: history(affinity=0)},
        occasion_name="İş",
        now=NOW,
    )

    assert in_work_outfit in result[0].items
    assert "İş kombinlerinde kullandığın parçalar" in result[0].reasons


def test_recently_worn_item_is_rotated_out_when_color_is_equal():
    top = item(1, "tshirt", hue=0)
    recent = item(2, "pantolon", hue=120)
    waiting = item(3, "pantolon", hue=120)

    result = suggest_outfits(
        [top, recent, waiting],
        rng=rng(),
        history={
            2: history(rating=5, last_days=1),
            3: history(rating=5, last_days=30),
        },
        now=NOW,
    )

    assert waiting in result[0].items
    assert "Uzun süredir giyilmeyen parçalar" in result[0].reasons


def test_pair_history_rewards_items_worn_together():
    top = item(1, "tshirt", hue=0)
    good_pair = item(2, "pantolon", hue=120)
    bad_pair = item(3, "pantolon", hue=240)

    result = suggest_outfits(
        [top, good_pair, bad_pair],
        rng=rng(),
        pair_history={
            (1, 2): PairHistory(count=1, rating_sum=5, rating_count=1),
            (1, 3): PairHistory(count=1, rating_sum=1, rating_count=1),
        },
        now=NOW,
    )

    assert good_pair in result[0].items
    assert "Birlikte iyi puanladığın bir ikili" in result[0].reasons


def test_no_history_keeps_legacy_color_score():
    top = item(1, "tshirt", hue=0)
    pants = item(2, "pantolon", hue=0, sat=0, light=5)

    result = suggest_outfits([top, pants], rng=rng())

    assert result[0].color_score == 1.0
    assert result[0].score == 1.0
    assert "Renkler birbiriyle çok uyumlu" in result[0].reasons


def test_occasion_without_history_gets_fallback_reason():
    top = item(1, "tshirt", hue=0)
    pants = item(2, "pantolon", hue=0, sat=0, light=5)

    result = suggest_outfits(
        [top, pants],
        rng=rng(),
        history=None,
        occasion_name="Spor",
    )

    assert "Spor için yeni bir kombin" in result[0].reasons

def test_weather_context_adds_reason_and_outerwear():
    top = item(1, "tshirt", hue=0)
    bottom = item(2, "pantolon", hue=0, sat=0, light=5)
    outer = item(3, "mont", hue=0, sat=0, light=10)
    weather = WeatherContext(headline="yağmurlu, 8°C", needs_outerwear=True)

    result = suggest_outfits(
        [top, bottom, outer],
        include_outerwear=True,
        rng=rng(),
        now=NOW,
        weather=weather,
    )

    joined = " | ".join(result[0].reasons)
    assert "Bugün hava: yağmurlu, 8°C" in joined
    assert any("mont" in i.category or "ceket" in i.category or "kaban" in i.category
               for i in result[0].items)

