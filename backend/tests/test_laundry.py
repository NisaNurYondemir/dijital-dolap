"""Çamaşır kuralı motoru testleri: varsayılanlar, kullanıcı ayarı, otomatik kirli."""
from laundry import (
    LaundryRule,
    default_rule,
    normalize_rules,
    rule_for,
    should_mark_dirty,
)


# ── Varsayılanlar ─────────────────────────────────────────────────────────────

def test_ust_beden_varsayilani_1_giyilme():
    for cat in ("tshirt", "gomlek", "kazak", "Tişört"):
        rule = default_rule(cat)
        assert rule.enabled and rule.wear_limit == 1, cat


def test_alt_beden_varsayilani_2_giyilme():
    for cat in ("pantolon", "esofman", "etek", "sort"):
        rule = default_rule(cat)
        assert rule.enabled and rule.wear_limit == 2, cat


def test_ic_camasir_ve_corap_1_giyilme():
    assert default_rule("ic camasir").wear_limit == 1
    assert default_rule("corap").wear_limit == 1
    assert default_rule("iç çamaşır").wear_limit == 1  # Türkçe yazım


def test_aksesuarlar_ozel_otomatik_kapali():
    for cat in ("sapka", "canta", "sal", "ayakkabi", "bot"):
        rule = default_rule(cat)
        assert not rule.enabled, cat


# ── Kullanıcı ayarı varsayılanı ezer ─────────────────────────────────────────

def test_kullanici_ayari_eklenir():
    rules = {"pantolon": {"enabled": True, "wear_limit": 3}}
    rule = rule_for("pantolon", rules)
    assert rule.enabled and rule.wear_limit == 3


def test_kullanici_ayari_yoksa_varsayilan_doner():
    rule = rule_for("tshirt", {})
    assert rule.as_dict() == default_rule("tshirt").as_dict()


def test_bilinmeyen_kategori_manuel_kalir():
    rule = rule_for("nurhak esarmasi", None)
    assert not rule.enabled


# ── Otomatik işaretleme kararı ───────────────────────────────────────────────

def test_esik_dolunca_kirli_isaretlenir():
    rule = LaundryRule(enabled=True, wear_limit=2)
    assert not should_mark_dirty(1, rule)
    assert should_mark_dirty(2, rule)
    assert should_mark_dirty(5, rule)


def test_kapali_kural_hic_kirli_isaretlemez():
    rule = LaundryRule(enabled=False, wear_limit=1)
    assert not should_mark_dirty(10, rule)


def test_sinirsiz_kural_hicbir_zaman_isaretlemez():
    rule = LaundryRule(enabled=True, wear_limit=None)
    assert not should_mark_dirty(50, rule)


# ── Normalizasyon ────────────────────────────────────────────────────────────

def test_hatali_json_verisi_zararsiz_normalizasyon():
    rules = normalize_rules({
        "Pantolon": {"enabled": "x", "wear_limit": "3"},  # bozuk değerler
        42: {"enabled": True},                            # bozuk anahtar
        "sapka": {"enabled": True, "wear_limit": None},
    })
    assert "pantolon" in rules
    assert rules["pantolon"].enabled is False  # "x" bool değil → güvenli kapalı
    assert rules["pantolon"].wear_limit is None
    assert 42 not in rules
    assert rules["sapka"].enabled and rules["sapka"].wear_limit is None


def test_wear_limit_sifir_ve_negatif_sinirsizlesir():
    rule = LaundryRule(enabled=True, wear_limit=0)
    assert rule.wear_limit is None
    assert not should_mark_dirty(3, rule)
