"""Kullanıcı ayarları: çamaşır / otomatik kirli işaretleme kuralları."""
from typing import Dict

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from auth import get_current_user, get_db
from laundry import LaundryRule, default_rule, normalize, normalize_rules, rule_for
from models.user import User
from schemas.settings import LaundrySettingsOut, LaundrySettingsUpdate

router = APIRouter(prefix="/settings", tags=["settings"])

# Ayar ekranında gösterilecek bilinen kategoriler (clip_category.CATEGORIES);
# kullanıcının dolabında başka kategori de olsa kuralları saklanabilir.
KNOWN_CATEGORIES = [
    "tshirt", "gomlek", "kazak", "hoodie", "ceket", "mont",
    "pantolon", "sort", "etek", "elbise", "takim elbise",
    "ic camasir", "corap", "ayakkabi", "bot", "sandalet",
    "kemer", "sapka", "canta", "sal",
]


def _effective_rules(db: Session, user: User) -> Dict[str, dict]:
    """Kullanıcı ayarları + varsayılanlar birleşik, göstergelik kurallar."""
    stored = normalize_rules(user.laundry_rules)
    categories = set(KNOWN_CATEGORIES) | set(stored.keys())
    return {cat: rule_for(cat, user.laundry_rules).as_dict()
            for cat in sorted(categories)}


@router.get("/laundry", response_model=LaundrySettingsOut)
def get_laundry_settings(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Kategori bazlı otomatik kirli kuralları (kullanıcı ayarı > varsayılan)."""
    return LaundrySettingsOut(rules=_effective_rules(db, current_user))


@router.put("/laundry", response_model=LaundrySettingsOut)
def update_laundry_settings(
    req: LaundrySettingsUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Kural kaydet. Kategori için enabled=false → otomatik işaretleme kapalı."""
    stored = normalize_rules(current_user.laundry_rules)
    for category, rule in req.rules.items():
        name = normalize(category)
        key = LaundryRule(enabled=rule.enabled, wear_limit=rule.wear_limit)
        if default_rule(name).as_dict() == key.as_dict():
            # Varsayılanla aynıysa saklamaya gerek yok (temiz JSON)
            stored.pop(name, None)
        else:
            stored[name] = key
    current_user.laundry_rules = (
        {cat: r.as_dict() for cat, r in stored.items()} or None
    )
    db.commit()
    db.refresh(current_user)
    return LaundrySettingsOut(rules=_effective_rules(db, current_user))
