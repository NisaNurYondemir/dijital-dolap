from weather import WeatherSummary, describe_weather_code, _city_from_nominatim


def _w(temp_c, code, precip=0.0):
    return WeatherSummary(
        temperature_c=temp_c,
        precipitation_mm=precip,
        wind_kmh=5.0,
        code=code,
        description=describe_weather_code(code),
    )


def test_description_rain_snow_clear():
    assert describe_weather_code(0) == "açık"
    assert describe_weather_code(63) == "yağmurlu"
    assert describe_weather_code(73) == "karlı"
    assert describe_weather_code(95) == "fırtınalı"


def test_rainy_detection_from_code_and_precipitation():
    assert _w(20, 61).is_rainy_snowy
    assert _w(30, 0, precip=0.4).is_rainy_snowy
    assert not _w(30, 0, precip=0.0).is_rainy_snowy


def test_season_hint_from_temperature():
    assert _w(30, 0).season_hint == "yaz"
    assert _w(20, 0).season_hint == "ilkbahar"
    assert _w(12, 0).season_hint == "sonbahar"
    assert _w(3, 0).season_hint == "kis"


def test_needs_outerwear_thresholds():
    assert _w(9, 0).needs_outerwear          # soğuk
    assert _w(16, 61).needs_outerwear        # yağmur + serin
    assert not _w(22, 61).needs_outerwear    # yağmur ama sıcak
    assert not _w(20, 0).needs_outerwear     # sıcak ve yağmursuz


def test_headline_contains_temp_and_description():
    assert _w(12.4, 61).headline() == "yağmurlu, 12°C"


def test_reverse_geocode_picks_turkish_city():
    data = {
        'lat': '39.9334',
        'lon': '32.8597',
        'country_code': 'TR',
        'address': {'city': 'Ankara', 'state': 'Ankara'},
    }
    result = _city_from_nominatim(data)
    assert result is not None
    assert result['name'] == 'Ankara'
    assert result['latitude'] == 39.9334


def test_reverse_geocode_rejects_foreign_location():
    data = {'lat': '51.5', 'lon': '-0.12', 'country_code': 'GB',
            'address': {'city': 'London'}}
    assert _city_from_nominatim(data) is None
