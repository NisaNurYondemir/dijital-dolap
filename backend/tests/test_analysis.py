from analysis import color_name, suggest_season


def test_neutral_colors():
    assert color_name(0, 0, 5) == "siyah"
    assert color_name(0, 0, 97) == "beyaz"
    assert color_name(200, 5, 50) == "gri"


def test_basic_hues():
    assert color_name(0, 80, 50) == "kırmızı"
    assert color_name(55, 80, 50) == "sarı"
    assert color_name(120, 70, 45) == "yeşil"
    assert color_name(180, 70, 45) == "turkuaz"
    assert color_name(220, 70, 50) == "mavi"
    assert color_name(280, 70, 50) == "mor"
    assert color_name(320, 70, 50) == "pembe"


def test_hue_wraps_at_360():
    assert color_name(360, 80, 50) == "kırmızı"
    assert color_name(350, 80, 50) == "kırmızı"


def test_special_dark_names():
    assert color_name(30, 60, 30) == "kahverengi"
    assert color_name(30, 80, 55) == "turuncu"
    assert color_name(230, 60, 25) == "lacivert"


def test_light_and_dark_prefix():
    assert color_name(0, 80, 80) == "açık kırmızı"
    assert color_name(120, 70, 20) == "koyu yeşil"


def test_missing_values():
    assert color_name(None, None, None) is None


def test_season_suggestion():
    assert suggest_season("tshirt") == "yaz"
    assert suggest_season("kazak") == "kis"
    assert suggest_season("ceket") == "sonbahar"
    assert suggest_season("pantolon") == "tum"
    assert suggest_season("bilinmeyen") == "tum"