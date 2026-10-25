from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator

from schemas.clothing import ClothingOut


class WearCreate(BaseModel):
    """Giyim kaydı. En az bir kombin veya kıyafet seçilmelidir."""

    outfit_id: Optional[int] = None
    clothing_ids: Optional[list[int]] = None

    worn_at: Optional[datetime] = None
    rating: Optional[int] = Field(None, ge=1, le=5)
    occasion: Optional[str] = None
    occasion_group_id: Optional[int] = None
    note: Optional[str] = None

    weather_temp: Optional[float] = None
    weather_condition: Optional[str] = None
    location: Optional[str] = None

    @field_validator("occasion", "note")
    @classmethod
    def blank_to_none(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        value = value.strip()
        return value or None


class WearUpdate(BaseModel):
    rating: Optional[int] = Field(None, ge=1, le=5)
    occasion: Optional[str] = None
    occasion_group_id: Optional[int] = None
    note: Optional[str] = None
    worn_at: Optional[datetime] = None

    @field_validator("occasion", "note")
    @classmethod
    def blank_to_none(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        value = value.strip()
        return value or None


class WearOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    outfit_id: Optional[int]
    worn_at: Optional[datetime]
    rating: Optional[int]
    occasion: Optional[str]
    occasion_group_id: Optional[int]
    note: Optional[str]
    weather_temp: Optional[float]
    weather_condition: Optional[str]
    location: Optional[str]
    created_at: Optional[datetime]
    clothes: list[ClothingOut]
