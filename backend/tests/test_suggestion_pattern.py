"""Öneri motorunun desen kurallarıyla entegrasyonu."""
import random
from types import SimpleNamespace

from suggestion import suggest_outfits


def item(category, hue=0, sat=80, light=50, season="tum", wearable=True,
         palette=None, pattern=None, scale=None):
    if palette is None:
        palette = [{
            "name": "kırmızı", "hue": hue, "saturation": sat,
            "lightness": light, "ratio": 1.0,
        }]
    return SimpleNamespace(
        category=category, season=season,
        hue=hue, saturation=sat, lightness=light,
        is_wearable=wearable,
        palette=palette, pattern=pattern, pattern_scale=scale,
    )


def rng():
    return random.Random(0)


def test_patterned_skirt_scores_lower_than_solid_skirt():
    top = item("tshirt", pattern="cizgili", scale="orta")
    solid = item("etek", pattern="duz")
    floral = item("etek", pattern="cicekli", scale="orta")

    result = suggest_outfits([top, solid, floral], rng=rng())

    assert len(result) == 2
    assert solid in result[0].items
    assert floral not in result[0].items
    floral_outfit = next(s for s in result if floral in s.items)
    assert floral_outfit.pattern_score < result[0].pattern_score


def test_conflict_reason_is_explained():
    top = item("tshirt", pattern="cizgili", scale="orta")
    floral = item("etek", pattern="cicekli", scale="orta")

    suggestion = suggest_outfits([top, floral], rng=rng())[0]

    assert any("desen" in r.lower() for r in suggestion.reasons)


def test_printed_shoes_do_not_trigger_pattern_limit():
    top = item("tshirt", pattern="cizgili", scale="orta")
    pants = item("pantolon", hue=220, sat=70, light=30, pattern="duz")
    shoes = item("sneaker", hue=240, sat=80, light=50, pattern="baskili")

    suggestion = suggest_outfits(
        [top, pants, shoes], include_shoes=True, rng=rng()
    )[0]

    assert shoes in suggestion.items
    assert suggestion.pattern_score == 1.0
    assert any("Aksesuar" in r or "sade" in r for r in suggestion.reasons)


def test_items_without_pattern_data_keep_old_scores():
    top = item("tshirt", hue=0, sat=80, light=50)
    pants = item("pantolon", hue=0, sat=0, light=5)   # siyah -> nötr

    suggestion = suggest_outfits([top, pants], rng=rng())[0]

    assert suggestion.pattern_score == 1.0
    assert suggestion.score == suggestion.color_score
