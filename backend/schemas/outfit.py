from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator

from schemas.clothing import ClothingOut
from schemas.occasion import OccasionGroupOut


class OutfitCreate(BaseModel):
    clothing_ids: list[int]
    is_favorite: bool = False
    occasion_ids: list[int] = []
    name: Optional[str] = Field(None, max_length=60)
    description: Optional[str] = Field(None, max_length=300)

    @field_validator("name", "description")
    @classmethod
    def blank_to_none(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        value = value.strip()
        return value or None


class OutfitUpdate(BaseModel):
    is_favorite: Optional[bool] = None
    clothing_ids: Optional[list[int]] = None
    occasion_ids: Optional[list[int]] = None
    name: Optional[str] = Field(None, max_length=60)
    description: Optional[str] = Field(None, max_length=300)

    @field_validator("name", "description")
    @classmethod
    def blank_to_none(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        value = value.strip()
        return value or None


class OutfitEvaluateRequest(BaseModel):
    """Kaydetmeden önce seçilen parçaların uyumunu hesaplamak için."""

    clothing_ids: list[int] = Field(min_length=1)
    occasion_id: Optional[int] = None


class OutfitScoreOut(BaseModel):
    score: float
    color_score: float
    pattern_score: float
    occasion_score: float = 1.0
    reasons: list[str] = []


class OutfitOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    is_favorite: bool
    created_at: datetime
    name: Optional[str] = None
    description: Optional[str] = None
    clothes: list[ClothingOut]
    groups: list[OccasionGroupOut] = []
    score: Optional[float] = None
    color_score: Optional[float] = None
    pattern_score: Optional[float] = None
    occasion_score: Optional[float] = None
    reasons: list[str] = []


class OutfitSuggestion(BaseModel):
    score: float
    color_score: float = 0.0
    pattern_score: float = 1.0
    occasion_score: float = 1.0
    reasons: list[str] = []
    clothes: list[ClothingOut]
