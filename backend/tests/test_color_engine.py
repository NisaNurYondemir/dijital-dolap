from color_engine import (
    Color, hue_difference, relation, pair_score, score_outfit,
)

RED = Color(0, 80, 50)
GREEN = Color(120, 80, 50)
BLUE = Color(240, 80, 50)
ORANGE = Color(30, 80, 50)
BLACK = Color(0, 0, 5)
WHITE = Color(0, 0, 97)
GRAY = Color(0, 3, 50)
UNKNOWN = Color(None, None, None)


def test_hue_difference_wraps_around_circle():
    assert hue_difference(350, 10) == 20
    assert hue_difference(0, 180) == 180
    assert hue_difference(360, 0) == 0
    assert hue_difference(90, 270) == 180


def test_analog():
    assert relation(RED, Color(20, 80, 50)) == "analog"
    assert relation(RED, Color(345, 80, 50)) == "analog"   # çemberi aşar


def test_complementary():
    assert relation(BLUE, Color(60, 80, 50)) == "tamamlayici"
    assert relation(Color(210, 60, 40), Color(30, 70, 50)) == "tamamlayici"


def test_triad():
    assert relation(RED, GREEN) == "triad"
    assert relation(GREEN, BLUE) == "triad"
    assert relation(RED, BLUE) == "triad"


def test_incompatible():
    assert relation(RED, Color(60, 80, 50)) == "uyumsuz"


def test_boundaries():
    assert relation(RED, Color(30, 80, 50)) == "analog"
    assert relation(RED, Color(31, 80, 50)) == "uyumsuz"
    assert relation(RED, Color(165, 80, 50)) == "tamamlayici"
    assert relation(RED, Color(195, 80, 50)) == "tamamlayici"
    assert relation(RED, Color(105, 80, 50)) == "triad"
    assert relation(RED, Color(135, 80, 50)) == "triad"


def test_neutrals_match_everything():
    for neutral in (BLACK, WHITE, GRAY):
        for color in (RED, GREEN, BLUE, ORANGE):
            assert relation(neutral, color) == "notr"
            assert pair_score(neutral, color).score == 1.0


def test_unknown_color():
    assert relation(UNKNOWN, RED) == "bilinmiyor"
    assert relation(UNKNOWN, BLACK) == "notr"


def test_score_outfit():
    assert score_outfit([RED]) == 1.0
    assert score_outfit([]) == 1.0
    # kırmızı + siyah: tek çift, nötr -> 1.0
    assert score_outfit([RED, BLACK]) == 1.0
    # kırmızı + yeşil + siyah: (0.8 + 1.0 + 1.0) / 3
    assert abs(score_outfit([RED, GREEN, BLACK]) - (0.8 + 1.0 + 1.0) / 3) < 1e-9