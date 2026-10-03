import random
from types import SimpleNamespace

from suggestion import group_of, suggest_outfits


def item(category, hue=0, sat=80, light=50, season="tum", wearable=True):
    return SimpleNamespace(
        category=category, season=season,
        hue=hue, saturation=sat, lightness=light, is_wearable=wearable,
    )


def rng():
    return random.Random(0)


def test_group_of_normalizes_names():
    assert group_of("T-Shirt") == "ust"
    assert group_of("TİŞÖRT") == "ust"
    assert group_of("Pantolon") == "alt"
    assert group_of("ELBİSE") == "elbise"
    assert group_of("Ayakkabı") == "ayakkabi"
    assert group_of("şapka") is None


def test_best_combination_first():
    red_top = item("tshirt", hue=0)
    black_pants = item("pantolon", hue=0, sat=0, light=5)   # nötr -> 1.0
    green_pants = item("pantolon", hue=120)                 # triad -> 0.8
    result = suggest_outfits([red_top, green_pants, black_pants], rng=rng())
    assert len(result) == 2
    assert result[0].score == 1.0
    assert black_pants in result[0].items


def test_dirty_items_are_excluded():
    top = item("tshirt", wearable=False)
    pants = item("pantolon")
    assert suggest_outfits([top, pants], rng=rng()) == []


def test_season_filter_keeps_all_season_items():
    kis_top = item("kazak", season="kis")
    tum_pants = item("pantolon", season="tum")
    assert suggest_outfits([kis_top, tum_pants], season="yaz", rng=rng()) == []
    assert len(suggest_outfits([kis_top, tum_pants], season="kis", rng=rng())) == 1


def test_dress_is_a_single_piece_outfit():
    result = suggest_outfits([item("elbise")], rng=rng())
    assert len(result) == 1
    assert result[0].score == 1.0


def test_shoes_are_added_when_available():
    clothes = [item("tshirt"), item("pantolon"), item("sneaker", sat=0, light=95)]
    assert len(suggest_outfits(clothes, rng=rng())[0].items) == 3
    assert len(suggest_outfits(clothes, include_shoes=False, rng=rng())[0].items) == 2


def test_unknown_category_is_ignored():
    assert suggest_outfits([item("sapka"), item("tshirt")], rng=rng()) == []


def test_limit():
    clothes = [item("tshirt", hue=h) for h in (0, 60, 120)] + [item("pantolon")]
    assert len(suggest_outfits(clothes, limit=2, rng=rng())) == 2