from pydantic import BaseModel


class WeatherCurrentOut(BaseModel):
    temperature_c: float
    precipitation_mm: float
    wind_kmh: float
    code: int
    description: str
    city: str | None = None
    headline: str
    needs_outerwear: bool
    season_hint: str


class CityOut(BaseModel):
    name: str
    admin1: str = ""
    label: str
    latitude: float
    longitude: float
