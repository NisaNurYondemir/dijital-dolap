from datetime import datetime
from typing import Literal, Optional
from pydantic import BaseModel, ConfigDict, Field, computed_field

Season = Literal["yaz", "kis", "ilkbahar", "sonbahar", "tum"]
PatternType = Literal[
    "duz", "cizgili", "ekose", "puantiyeli", "cicekli",
    "geometrik", "hayvan", "baskili", "diger", "bilinmiyor",
]
PatternScale = Literal["ince", "orta", "iri", "bilinmiyor"]


class PaletteColor(BaseModel):
    """Paletteki tek bir renk ve görseldeki oranı."""

    name: Optional[str] = Field(default=None, max_length=50)
    hue: float = Field(ge=0, le=360)
    saturation: float = Field(ge=0, le=100)
    lightness: float = Field(ge=0, le=100)
    ratio: float = Field(ge=0, le=1)


class ClothingCreate(BaseModel):
    category: str = Field(min_length=1, max_length=50)
    season: Season
    hue: Optional[float] = Field(default=None, ge=0, le=360)
    saturation: Optional[float] = Field(default=None, ge=0, le=100)
    lightness: Optional[float] = Field(default=None, ge=0, le=100)
    color_name: Optional[str] = Field(default=None, max_length=50)
    palette: Optional[list[PaletteColor]] = Field(default=None, max_length=5)
    pattern: Optional[PatternType] = None
    pattern_scale: Optional[PatternScale] = None
    pattern_source: Optional[str] = Field(default=None, max_length=20)
    pattern_confidence: Optional[float] = Field(default=None, ge=0, le=1)
    is_dirty: bool = False
    needs_ironing: bool = False
    is_ironed: bool = False
    temp_image: Optional[str] = Field(default=None, max_length=100)


class ClothingUpdate(BaseModel):
    category: Optional[str] = Field(default=None, min_length=1, max_length=50)
    season: Optional[Season] = None
    hue: Optional[float] = Field(default=None, ge=0, le=360)
    saturation: Optional[float] = Field(default=None, ge=0, le=100)
    lightness: Optional[float] = Field(default=None, ge=0, le=100)
    color_name: Optional[str] = Field(default=None, max_length=50)
    palette: Optional[list[PaletteColor]] = Field(default=None, max_length=5)
    pattern: Optional[PatternType] = None
    pattern_scale: Optional[PatternScale] = None
    pattern_source: Optional[str] = Field(default=None, max_length=20)
    pattern_confidence: Optional[float] = Field(default=None, ge=0, le=1)
    is_dirty: Optional[bool] = None
    needs_ironing: Optional[bool] = None
    is_ironed: Optional[bool] = None


class WashRequest(BaseModel):
    """Çamaşır günü isteği: ya seçili parçalar ya da tüm kirli sepeti."""

    clothing_ids: Optional[list[int]] = None
    all_dirty: bool = False


class ClothingOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    category: str
    season: str
    hue: Optional[float]
    saturation: Optional[float]
    lightness: Optional[float]
    color_name: Optional[str]
    palette: Optional[list[PaletteColor]] = None
    pattern: Optional[str] = None
    pattern_scale: Optional[str] = None
    pattern_source: Optional[str] = None
    pattern_confidence: Optional[float] = None
    is_dirty: bool
    needs_ironing: bool
    is_ironed: bool
    wear_count_since_wash: int = 0
    image_path: Optional[str]
    created_at: datetime

    @computed_field
    @property
    def is_wearable(self) -> bool:
        return (not self.is_dirty) and ((not self.needs_ironing) or self.is_ironed)