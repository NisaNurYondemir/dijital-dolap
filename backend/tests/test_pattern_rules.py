"""Palet/desen destekli uyum motoru testleri."""
from color_engine import (
    Color, ItemProfile, evaluate_outfit, item_match, palette_harmony,
    pattern_rule, score_outfit,
)

RED = Color(0, 80, 50)
GREEN = Color(120, 80, 50)
BLUE = Color(240, 80, 50)
YELLOW = Color(60, 80, 50)
NAVY = Color(220, 70, 30)
WHITE = Color(0, 0, 97)


def profile(*colors, pattern="bilinmiyor", scale="bilinmiyor",
            loudness=0.0, scope="body"):
    return ItemProfile(
        colors=tuple(colors), pattern=pattern, pattern_scale=scale,
        loudness=loudness, scope=scope,
    )


# --- Palet içi harmoni -----------------------------------------------------

def test_palette_harmony_triad():
    assert palette_harmony([RED, GREEN, BLUE]) == "triad"


def test_palette_harmony_mono_and_analog():
    assert palette_harmony([RED]) == "mono"
    assert palette_harmony([Color(0, 80, 50), Color(20, 80, 50)]) == "analog"


def test_palette_harmony_ignores_neutrals():
    # beyaz + siyah sadece nötr; kromatik tek renk kalır
    assert palette_harmony([WHITE, Color(0, 0, 5)]) == "notr"


# --- Parça eşleşmesi -------------------------------------------------------

def test_shared_color_beats_missing_triad():
    """Lacivert pantolon + kırmızı/lacivert/beyaz çizgili üst: ortak renk kazanır."""
    top = profile(RED, NAVY, WHITE, pattern="cizgili", loudness=0.6)
    pants = profile(NAVY)
    result = item_match(top, pants)

    assert result.relation == "ortak_renk"
    assert result.score >= 0.9


def test_two_multicolor_items_without_shared_color_are_penalized():
    a = profile(RED, GREEN)
    b = profile(BLUE, YELLOW)
    result = item_match(a, b)

    assert result.relation == "cok_renkli"
    assert result.score <= 0.7


def test_two_multicolor_items_with_shared_color_are_fine():
    a = profile(RED, BLUE)
    b = profile(BLUE, YELLOW)
    result = item_match(a, b)

    assert result.relation == "ortak_renk"
    assert result.score >= 0.9


def test_neutral_anchor_matches_everything():
    assert item_match(profile(RED, GREEN), profile(WHITE)).score == 1.0
    assert item_match(profile(RED), profile(Color(0, 0, 5))).score == 1.0


def test_unknown_color_keeps_legacy_score():
    unknown = profile(Color(None, None, None))
    assert item_match(unknown, profile(RED)).score == 0.5


# --- Desen kuralları -------------------------------------------------------

def test_single_patterned_body_piece_is_fine():
    top = profile(RED, pattern="cizgili", scale="orta", loudness=0.55)
    pants = profile(NAVY, pattern="duz", loudness=0.0)
    result = pattern_rule([top, pants])

    assert result.score == 1.0
    assert any("sade" in r for r in result.reasons)


def test_two_patterned_body_pieces_are_penalized():
    top = profile(RED, pattern="cizgili", scale="orta", loudness=0.55)
    skirt = profile(NAVY, pattern="cicekli", scale="orta", loudness=0.7)
    result = pattern_rule([top, skirt])

    assert result.score <= 0.4
    assert any("bastır" in r for r in result.reasons)


def test_power_clash_allowed_with_different_scale_and_shared_color():
    top = profile(RED, BLUE, pattern="cizgili", scale="iri", loudness=0.63)
    skirt = profile(BLUE, pattern="cicekli", scale="ince", loudness=0.6)
    result = pattern_rule([top, skirt])

    assert result.score == 0.60
    assert any("Bilinçli" in r for r in result.reasons)


def test_accessory_pattern_is_exempt_from_body_limit():
    """Baskılı şapka + çizgili tişört: sert kural tetiklenmemeli."""
    top = profile(RED, pattern="cizgili", scale="orta", loudness=0.55)
    pants = profile(NAVY, pattern="duz", loudness=0.0)
    hat = profile(BLUE, pattern="baskili", loudness=0.78, scope="accessory")
    result = pattern_rule([top, pants, hat])

    assert result.score == 1.0
    assert any("Aksesuar" in r for r in result.reasons)


def test_accessory_loudness_uses_low_weight():
    top = profile(RED, pattern="cizgili", scale="iri", loudness=1.0)
    hat = profile(BLUE, pattern="hayvan", loudness=1.0, scope="accessory")
    # 1.0 + 1.0*0.3 = 1.3 > 1.25 -> kucuk ceza, ama kombin hala makul
    result = pattern_rule([top, hat])

    assert 0.8 <= result.score < 1.0
    assert any("yoğunluğu" in r for r in result.reasons)


def test_no_pattern_information_keeps_legacy_behaviour():
    profiles = [profile(RED), profile(NAVY), profile(WHITE)]
    total, color, pattern, reasons = evaluate_outfit(profiles)

    assert total == color
    assert pattern == 1.0
    assert reasons == []


def test_pattern_penalty_is_multiplicative():
    top = profile(RED, pattern="cizgili", scale="orta", loudness=0.55)
    skirt = profile(RED, pattern="cicekli", scale="orta", loudness=0.7)
    total, color, pattern, _ = evaluate_outfit([top, skirt])

    assert color >= 0.9          # aynı renk ailesi: güçlü renk uyumu
    assert pattern < 1.0
    assert total < color         # desen cezası çarpımsal
