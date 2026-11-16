from typing import Dict, Optional

from pydantic import BaseModel, Field


class LaundryRule(BaseModel):
    """Bir kategorinin otomatik kirli kuralı."""

    enabled: bool = False
    wear_limit: Optional[int] = Field(
        None, ge=1, le=99,
        description="Kaç giyilme sonra kirli; null = sınırsız",
    )


class LaundrySettingsOut(BaseModel):
    """Tüm kategorilerin etkili kuralları (varsayılanlar dahil)."""

    rules: Dict[str, LaundryRule]


class LaundrySettingsUpdate(BaseModel):
    """Kategori bazlı kural güncellemesi. Sadece gönderilenler değişir."""

    rules: Dict[str, LaundryRule]
