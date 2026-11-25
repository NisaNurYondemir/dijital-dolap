import random
from types import SimpleNamespace

from suggestion import suggest_outfits


def item(category, hue=0, sat=80, light=50, season="tum", wearable=True):
    return SimpleNamespace(
        category=category,
        season=season,
        hue=hue,
        saturation=sat,
        lightness=light,
        is_wearable=wearable,
    )


def rng():
    return random.Random(0)


def categories(suggestion):
    return {piece.category for piece in suggestion.items}


def test_formal_never_suggests_loungewear():
    # Sweatshirt sert engel; geriye üst kalmadığı için kombin üretilemez.
    clothes = [item("sweatshirt"), item("pantolon"), item("topuklu")]
    assert suggest_outfits(
        clothes, occasion_type="formal", rng=rng()
    ) == []


def test_formal_prefers_anchor_outfit():
    clothes = [
        item("tshirt", hue=0),
        item("bluz", hue=120),
        item("pantolon", sat=0, light=5),
        item("sneaker", sat=0, light=95),
    ]
    result = suggest_outfits(clothes, occasion_type="formal", rng=rng())
    assert result
    # Tişört + pantolon + sneaker resmi çapa taşımadığı için elenir.
    assert all("bluz" in categories(s) for s in result)


def test_sport_excludes_heels():
    clothes = [
        item("tshirt"),
        item("sort"),
        item("topuklu", sat=0, light=95),
        item("sneaker", sat=0, light=95),
    ]
    result = suggest_outfits(clothes, occasion_type="sport", rng=rng())
    assert result
    assert all("topuklu" not in categories(s) for s in result)
    assert all("sneaker" in categories(s) for s in result)


def test_work_blocks_tracksuit():
    clothes = [item("sweatshirt"), item("esofman"), item("sneaker")]
    assert suggest_outfits(clothes, occasion_type="work", rng=rng()) == []


def test_casual_allows_tracksuit():
    clothes = [item("sweatshirt"), item("esofman"), item("sneaker")]
    assert suggest_outfits(clothes, occasion_type="casual", rng=rng())


def test_no_occasion_type_keeps_old_behaviour():
    clothes = [item("sweatshirt"), item("esofman"), item("sneaker")]
    assert suggest_outfits(clothes, rng=rng())


def test_soft_penalty_lowers_occasion_score_and_adds_reason():
    clothes = [item("bluz"), item("pantolon"), item("sneaker")]
    result = suggest_outfits(clothes, occasion_type="formal", rng=rng())
    assert result
    assert result[0].occasion_score < 1.0
    joined = " | ".join(result[0].reasons)
    assert "için uygun parçalar" in joined
