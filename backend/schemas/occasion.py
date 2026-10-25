import re
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator

_HEX_COLOR = re.compile(r"^#[0-9a-fA-F]{6}$")


def _clean_name(value: str) -> str:
    value = value.strip()
    if not value:
        raise ValueError("Grup adı boş olamaz")
    return value


def _clean_optional(value: Optional[str]) -> Optional[str]:
    if value is None:
        return None
    value = value.strip()
    return value or None


def _clean_color(value: Optional[str]) -> Optional[str]:
    value = _clean_optional(value)
    if value is None:
        return None
    if not _HEX_COLOR.match(value):
        raise ValueError("Renk #RRGGBB biçiminde olmalı")
    return value.upper()


class OccasionGroupCreate(BaseModel):
    name: str = Field(min_length=1, max_length=40)
    emoji: Optional[str] = Field(default=None, max_length=8)
    color: Optional[str] = Field(default=None, max_length=7)

    @field_validator("name")
    @classmethod
    def name_is_valid(cls, value: str) -> str:
        return _clean_name(value)

    @field_validator("emoji")
    @classmethod
    def emoji_is_valid(cls, value: Optional[str]) -> Optional[str]:
        return _clean_optional(value)

    @field_validator("color")
    @classmethod
    def color_is_valid(cls, value: Optional[str]) -> Optional[str]:
        return _clean_color(value)


class OccasionGroupUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=40)
    emoji: Optional[str] = Field(default=None, max_length=8)
    color: Optional[str] = Field(default=None, max_length=7)

    @field_validator("name")
    @classmethod
    def name_is_valid(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        return _clean_name(value)

    @field_validator("emoji")
    @classmethod
    def emoji_is_valid(cls, value: Optional[str]) -> Optional[str]:
        return _clean_optional(value)

    @field_validator("color")
    @classmethod
    def color_is_valid(cls, value: Optional[str]) -> Optional[str]:
        return _clean_color(value)


class OccasionGroupOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    name: str
    emoji: Optional[str]
    color: Optional[str]
    is_default: bool
    created_at: Optional[datetime]
