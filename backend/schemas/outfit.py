from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict
from schemas.clothing import ClothingOut


class OutfitCreate(BaseModel):
    clothing_ids: list[int]
    is_favorite: bool = False


class OutfitUpdate(BaseModel):
    is_favorite: Optional[bool] = None
    clothing_ids: Optional[list[int]] = None


class OutfitOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    is_favorite: bool
    created_at: datetime
    clothes: list[ClothingOut]

class OutfitSuggestion(BaseModel):
    score: float
    clothes: list[ClothingOut]