from types import SimpleNamespace

from outfit_scoring import score_outfit


def item(category, hue=0, sat=80, light=50):
    return SimpleNamespace(
        category=category,
        hue=hue,
        saturation=sat,
        lightness=light,
    )


def test_general_score_without_occasion():
    result = score_outfit(
        [item("tshirt", hue=0), item("pantolon", sat=0, light=5)]
    )
    assert 0 < result.score <= 1
    assert result.occasion_score == 1.0
    assert result.color_score > 0


def test_soft_occasion_mismatch_lowers_score():
    general = score_outfit(
        [item("bluz", hue=120), item("pantolon", sat=0, light=5),
         item("sneaker", sat=0, light=95)]
    )
    formal = score_outfit(
        [item("bluz", hue=120), item("pantolon", sat=0, light=5),
         item("sneaker", sat=0, light=95)],
        "formal",
    )
    assert formal.score < general.score
    assert 0 < formal.occasion_score < 1
    assert any("tartışmalı" in reason for reason in formal.reasons)


def test_hard_occasion_mismatch_scores_zero():
    result = score_outfit(
        [item("sweatshirt"), item("pantolon"), item("topuklu")],
        "formal",
    )
    assert result.score == 0
    assert result.occasion_score == 0
    assert any("uygun olmayan" in reason for reason in result.reasons)


def test_sport_blocks_heels():
    result = score_outfit(
        [item("tshirt"), item("sort"), item("topuklu")],
        "sport",
    )
    assert result.score == 0
    assert any("Spor" in reason for reason in result.reasons)


def test_single_item_is_flagged():
    result = score_outfit([item("tshirt")])
    assert result.score == 1.0
    assert any("en az iki" in reason for reason in result.reasons)
