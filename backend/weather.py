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
REVERSE_URL = "https://nominatim.openstreetmap.org/reverse"


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


@dataclass
class DayForecast:
    """Belirli bir gün için Open-Meteo günlük tahmini."""

    date: str                     # "2026-11-03"
    max_c: float
    min_c: float
    code: int
    description: str

    @property
    def is_rainy_snowy(self) -> bool:
        return (
            self.code in _RAIN_CODES
            or self.code in _SNOW_CODES
            or self.code in _STORM_CODES
        )

    @property
    def needs_outerwear(self) -> bool:
        """Günün en-soğuk anına göre mont/ceket hatırlatması."""
        return self.min_c < 14 or (self.is_rainy_snowy and self.max_c < 18)

    def headline(self) -> str:
        return f"{self.description}, {self.min_c:.0f}–{self.max_c:.0f}°C"


def fetch_daily_forecast(lat: float, lon: float, days: int = 7,
                         timeout: float = 8.0) -> list[DayForecast]:
    """lat/lon için gün gün tahmin listesi döner (index 0 = bugün)."""
    params = urllib.parse.urlencode({
        "latitude": lat,
        "longitude": lon,
        "daily": "temperature_2m_max,temperature_2m_min,weather_code",
        "forecast_days": max(1, min(int(days), 16)),
    })
    url = f"{FORECAST_URL}?{params}"
    try:
        with urllib.request.urlopen(url, timeout=timeout) as res:
            data = json.load(res)
    except Exception as exc:
        raise WeatherError(f"Tahmin servisine ulaşılamadı: {exc}") from exc
    daily = data.get("daily") or {}
    dates = daily.get("time") or []
    tmax = daily.get("temperature_2m_max") or []
    tmin = daily.get("temperature_2m_min") or []
    codes = daily.get("weather_code") or []
    forecast: list[DayForecast] = []
    for i, date in enumerate(dates):
        try:
            forecast.append(DayForecast(
                date=str(date),
                max_c=float(tmax[i]),
                min_c=float(tmin[i]),
                code=int(codes[i]) if i < len(codes) else 0,
                description=describe_weather_code(
                    int(codes[i]) if i < len(codes) else 0
                ),
            ))
        except (TypeError, ValueError, IndexError):
            continue
    if not forecast:
        raise WeatherError("Tahmin yanıtı eksik")
    return forecast


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


def _city_from_nominatim(data: dict) -> dict | None:
    """Nominatim yanıtından en iyi şehir adayı (Türkiye odaklı)."""
    adr = (data or {}).get("address") or {}
    if adr.get("country_code", "").upper() != "TR":
        return None
    # Türkiye yanıtlarında il 'province', ilçe 'town' alanında gelir.
    name = (adr.get("province") or adr.get("city") or adr.get("town")
            or adr.get("district") or adr.get("county") or "")
    if not name:
        return None
    return {
        "name": name,
        "admin1": adr.get("province", ""),
        "latitude": float(data["lat"]),
        "longitude": float(data["lon"]),
    }


def reverse_geocode(lat: float, lon: float, timeout: float = 8.0) -> dict:
    """lat/lon -> şehir adı (Nominatim reverse geocoding, anahtar yok)."""
    params = urllib.parse.urlencode({
        "lat": lat,
        "lon": lon,
        "format": "jsonv2",
        "accept-language": "tr",
        "zoom": 10,
    })
    url = f"{REVERSE_URL}?{params}"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "dijital-dolap-demo/1.0"})
        with urllib.request.urlopen(req, timeout=timeout) as res:
            data = json.load(res)
    except Exception as exc:
        raise WeatherError(f"Konum çözümlemesi başarısız: {exc}") from exc
    result = _city_from_nominatim(data)
    if result is None:
        raise WeatherError("Konum Türkiye'de değil ya da şehir adı çözülemedi")
    return result
