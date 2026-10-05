from datetime import datetime
from typing import Literal, Optional
from pydantic import BaseModel, ConfigDict, Field, computed_field

Season = Literal["yaz", "kis", "ilkbahar", "sonbahar", "tum"]


class ClothingCreate(BaseModel):
    category: str = Field(min_length=1, max_length=50)
    season: Season
    hue: Optional[float] = Field(default=None, ge=0, le=360)
    saturation: Optional[float] = Field(default=None, ge=0, le=100)
    lightness: Optional[float] = Field(default=None, ge=0, le=100)
    color_name: Optional[str] = Field(default=None, max_length=50)
    is_dirty: bool = False
    needs_ironing: bool = False
    is_ironed: bool = False


class ClothingUpdate(BaseModel):
    category: Optional[str] = Field(default=None, min_length=1, max_length=50)
    season: Optional[Season] = None
    hue: Optional[float] = Field(default=None, ge=0, le=360)
    saturation: Optional[float] = Field(default=None, ge=0, le=100)
    lightness: Optional[float] = Field(default=None, ge=0, le=100)
    color_name: Optional[str] = Field(default=None, max_length=50)
    is_dirty: Optional[bool] = None
    needs_ironing: Optional[bool] = None
    is_ironed: Optional[bool] = None


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
    is_dirty: bool
    needs_ironing: bool
    is_ironed: bool
    image_path: Optional[str]
    created_at: datetime

    @computed_field
    @property
    def is_wearable(self) -> bool:
        return (not self.is_dirty) and ((not self.needs_ironing) or self.is_ironed)