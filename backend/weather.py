"""Open-Meteo hava durumu istemcisi (API anahtarı gerektirmez).

api.open-meteo.com: anlık hava; geocoding-api.open-meteo.com: şehir arama.
Ağ hatasında çağıran tarafın fallback yapabilmesi için WeatherError fırlatır.
"""
import json
import urllib.parse
import urllib.request
from dataclasses import dataclass
from typing import Optional

FORECAST_URL = "https://api.open-meteo.com/v1/forecast"
GEOCODE_URL = "https://geocoding-api.open-meteo.com/v1/search"


class WeatherError(Exception):
    pass


# WMO weather interpretation kodları -> Türkçe açıklama
WMO_TR = {
    0: "açık",
    1: "az bulutlu",
    2: "parçalı bulutlu",
    3: "kapalı",
    45: "sisli",
    48: "kırağılı sisli",
    51: "çisenti",
    53: "çisentili",
    55: "yoğun çisenti",
    56: "donan çisenti",
    57: "yoğun donan çisenti",
    61: "hafif yağmurlu",
    63: "yağmurlu",
    65: "şiddetli yağmurlu",
    66: "dondurucu yağmurlu",
    67: "şiddetli dondurucu yağmurlu",
    71: "hafif karlı",
    73: "karlı",
    75: "yoğun karlı",
    77: "kar taneli",
    80: "hafif sağanaklı",
    81: "sağanak yağışlı",
    82: "şiddetli sağanaklı",
    85: "hafif kar sağanağı",
    86: "yoğun kar sağanağı",
    95: "gök gürültülü",
    96: "dolulu fırtınalı",
    99: "şiddetli dolulu fırtınalı",
}

_RAIN_CODES = {51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82}
_SNOW_CODES = {71, 73, 75, 77, 85, 86}
_STORM_CODES = {95, 96, 99}


def describe_weather_code(code: int) -> str:
    if code in _RAIN_CODES:
        return "yağmurlu"
    if code in _SNOW_CODES:
        return "karlı"
    if code in _STORM_CODES:
        return "fırtınalı"
    return WMO_TR.get(code, "sisli" if code in (45, 48) else "açık")


@dataclass
class WeatherSummary:
    """Günlük kombin önerisi için gereken hava özeti."""

    temperature_c: float
    precipitation_mm: float
    wind_kmh: float
    code: int
    description: str              # kısa Türkçe durum ("yağmurlu" vb.)
    city: Optional[str] = None    # gösterim için şehir adı
    latitude: float = 0.0
    longitude: float = 0.0

    @property
    def is_rainy_snowy(self) -> bool:
        if self.code in _RAIN_CODES or self.code in _SNOW_CODES:
            return True
        # Kod yağışlı olmasa bile yağış ölçülmüşse ıslak kabul et.
        return self.precipitation_mm >= 0.2

    @property
    def needs_outerwear(self) -> bool:
        """Soğuk veya ıslak hava → mont/ceket hatırlatması."""
        if self.is_rainy_snowy:
            return self.temperature_c < 18
        return self.temperature_c < 14

    @property
    def season_hint(self) -> str:
        """Sıcaklığa göre Clothing.season değeri önerisi."""
        t = self.temperature_c
        if t >= 26:
            return "yaz"
        if t >= 18:
            return "ilkbahar"
        if t >= 7:
            return "sonbahar"
        return "kis"

    def headline(self) -> str:
        """Öneri kartlarında kullanılacak kısa özet ("Yağmurlu, 12°C")."""
        return f"{self.description}, {self.temperature_c:.0f}°C"


def fetch_weather(lat: float, lon: float, city: Optional[str] = None,
                  timeout: float = 8.0) -> WeatherSummary:
    params = urllib.parse.urlencode({
        "latitude": lat,
        "longitude": lon,
        "current": "temperature_2m,precipitation,weather_code,wind_speed_10m",
    })
    url = f"{FORECAST_URL}?{params}"
    try:
        with urllib.request.urlopen(url, timeout=timeout) as res:
            data = json.load(res)
    except Exception as exc:  # ağ, JSON, HTTP hataları tek yerde
        raise WeatherError(f"Hava servisine ulaşılamadı: {exc}") from exc
    current = data.get("current")
    if not current or "temperature_2m" not in current:
        raise WeatherError("Hava yanıtı eksik")
    code = int(current.get("weather_code", 0))
    return WeatherSummary(
        temperature_c=float(current["temperature_2m"]),
        precipitation_mm=float(current.get("precipitation", 0) or 0),
        wind_kmh=float(current.get("wind_speed_10m", 0) or 0),
        code=code,
        description=describe_weather_code(code),
        city=city,
        latitude=lat,
        longitude=lon,
    )


def geocode(name: str, count: int = 5, timeout: float = 8.0) -> list[dict]:
    """Şehir adı -> lat/lon adayları (Open-Meteo geocoding, ücretsiz)."""
    params = urllib.parse.urlencode({
        "name": name,
        "count": count,
        "language": "tr",
        "format": "json",
    })
    url = f"{GEOCODE_URL}?{params}"
    try:
        with urllib.request.urlopen(url, timeout=timeout) as res:
            data = json.load(res)
    except Exception as exc:
        raise WeatherError(f"Şehir arama başarısız: {exc}") from exc
    results = []
    for item in data.get("results", []):
        if item.get("country_code") != "TR":   # bu capstone Türkiye odaklı
            continue
        results.append({
            "name": item.get("name", ""),
            "admin1": item.get("admin1", ""),
            "latitude": float(item["latitude"]),
            "longitude": float(item["longitude"]),
        })
    return results
