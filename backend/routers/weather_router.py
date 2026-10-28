from typing import List, Optional

from fastapi import APIRouter, HTTPException, Query

from schemas.weather import CityOut, WeatherCurrentOut
from weather import WeatherError, fetch_weather, geocode, reverse_geocode

router = APIRouter(prefix="/weather", tags=["weather"])


@router.get(
    "/current",
    response_model=WeatherCurrentOut,
    responses={502: {"description": "Hava servisine ulaşılamadı"}},
)
def current_weather(
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
    city: Optional[str] = Query(None, max_length=80),
):
    """Verilen koordinatlar için anlık hava özeti döner."""
    try:
        summary = fetch_weather(lat, lon, city=city)
    except WeatherError as exc:
        raise HTTPException(502, str(exc))
    return {
        "temperature_c": round(summary.temperature_c, 1),
        "precipitation_mm": summary.precipitation_mm,
        "wind_kmh": summary.wind_kmh,
        "code": summary.code,
        "description": summary.description,
        "city": summary.city,
        "headline": summary.headline(),
        "needs_outerwear": summary.needs_outerwear,
        "season_hint": summary.season_hint,
    }


@router.get("/search", response_model=list[CityOut])
def search_city(
    name: str = Query(..., min_length=2, max_length=60),
):
    """Şehir adı araması (Türkiye sonuçları, Open-Meteo geocoding)."""
    try:
        results = geocode(name)
    except WeatherError as exc:
        raise HTTPException(502, str(exc))
    return [
        {
            "name": r["name"],
            "admin1": r.get("admin1", ""),
            "label": f"{r['name']}"
            + (f", {r['admin1']}" if r.get("admin1") and r["admin1"] != r["name"] else ""),
            "latitude": r["latitude"],
            "longitude": r["longitude"],
        }
        for r in results
    ]


@router.get("/reverse", response_model=CityOut)
def reverse_city(
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
):
    """Cihaz konumu (GPS) -> şehir adı (Nominatim reverse geocoding)."""
    try:
        r = reverse_geocode(lat, lon)
    except WeatherError as exc:
        raise HTTPException(502, str(exc))
    return {
        "name": r["name"],
        "admin1": r.get("admin1", ""),
        "label": r["name"],
        "latitude": r["latitude"],
        "longitude": r["longitude"],
    }
