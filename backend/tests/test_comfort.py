"""Sıcaklık hissi (comfort) ve kombin isim/açıklama testleri."""
import pytest
from pydantic import ValidationError

from schemas.outfit import OutfitCreate, OutfitUpdate
from schemas.wear import WearCreate, WearUpdate
from weather import WeatherSummary, needs_outerwear_with_bias


# ── Comfort şema doğrulaması ─────────────────────────────────────────────────

def test_comfort_araligi_negatif_iki_iki():
    for value in (-2, -1, 0, 1, 2):
        assert WearCreate(outfit_id=1, comfort=value).comfort == value
        assert WearUpdate(comfort=value).comfort == value


def test_comfort_aralik_disi_reddedilir():
    with pytest.raises(ValidationError):
        WearCreate(outfit_id=1, comfort=-3)
    with pytest.raises(ValidationError):
        WearCreate(outfit_id=1, comfort=3)
    with pytest.raises(ValidationError):
        WearUpdate(comfort="çook üşüdüm")


def test_comfort_istemeye_bagli():
    assert WearCreate(outfit_id=1).comfort is None
    assert WearUpdate(rating=4).comfort is None


# ── Kombin isim / açıklama ───────────────────────────────────────────────────

def test_outfit_isim_ve_aciklama_kabul_edilir():
    req = OutfitCreate(clothing_ids=[1], name="  Hafta içi  ", description=" Gömlek + pantolon ")
    assert req.name == "Hafta içi"
    assert req.description == "Gömlek + pantolon"


def test_outfit_bos_isim_none_olur():
    req = OutfitCreate(clothing_ids=[1], name="   ")
    assert req.name is None
    patch = OutfitUpdate(name="")
    assert patch.name is None


def test_outfit_isim_siniri():
    with pytest.raises(ValidationError):
        OutfitCreate(clothing_ids=[1], name="x" * 61)
    with pytest.raises(ValidationError):
        OutfitCreate(clothing_ids=[1], description="y" * 301)


# ── Üşüme/sıcaklama eğiliminin mont eşiğine etkisi ───────────────────────────

def _summary(temp: float, rainy: bool = False) -> WeatherSummary:
    return WeatherSummary(
        temperature_c=temp,
        precipitation_mm=2.0 if rainy else 0.0,
        wind_kmh=5.0,
        code=61 if rainy else 0,
        description="yağmurlu" if rainy else "açık",
    )


def test_bias_yoksa_varsayilan_esik():
    assert needs_outerwear_with_bias(_summary(13.9), None)
    assert not needs_outerwear_with_bias(_summary(14.0), None)


def test_uyan_kullanici_daha_erken_mont_ister():
    # Ortalama -1 (üşüyor): kuru eşik 14 → 16°C'de de mont istenir.
    assert not needs_outerwear_with_bias(_summary(14.0), None)
    assert needs_outerwear_with_bias(_summary(15.0), -1.0)
    assert needs_outerwear_with_bias(_summary(17.9), -2.0)
    assert not needs_outerwear_with_bias(_summary(18.0), -2.0)


def test_sicaklanan_kullanici_monti_gec_ister():
    # Ortalama +1 (sıcaklıyor): kuru eşik 14 → 12°C'de de mont istenmez.
    assert not needs_outerwear_with_bias(_summary(12.0), 1.0)
    assert needs_outerwear_with_bias(_summary(11.9), 1.0)


def test_yagisli_gunde_etki_ayni_yonde():
    assert needs_outerwear_with_bias(_summary(17.0, rainy=True), -1.0)
    assert not needs_outerwear_with_bias(_summary(16.0, rainy=True), 2.0)
