"""Çamaşır takibi: kategori bazlı otomatik kirli işaretleme kuralları.

Her kategori için kullanıcı şunları ayarlayabilir:
- ``enabled``   : giyilme sayısı eşiği dolunca parça otomatik kirli işaretlensin mi?
- ``wear_limit``: kaç giyilme (yıkamadan beri) sonra kirli sayılsın? 0 = sınırsız.

Otomatik işaretleme isteğe bağlıdır; kullanıcı istediği parçayı her zaman
manuel kirli/temiz işaretleyebilir. Kurallar kullanıcı başına saklanır ve
verilmeyen kategoriler varsayılana düşer.

Varsayılanlar grup bazlıdır (suggestion.CATEGORY_GROUPS ile uyumlu):
üst beden 1 giyilme, alt beden 2 giyilme, iç çamaşır/çorap 1 giyilme;
şapka, çanta, ayakkabı gibi parçalar varsayılan olarak manuel.
"""

from typing import Optional

from suggestion import group_of, normalize

# Kategori grubuna göre varsayılan eşik (None = otomatik kapalı)
_DEFAULT_LIMITS = {
    "ust": 1,        # tişört, gömlek, kazak... her giyilişte kirli
    "alt": 2,        # pantolon, eşofman, etek... 2 giyiliş
    "ayakkabi": None,  # manuel
    "elbise": 1,
    "dis": 2,        # ceket/mont/yelek birkaç giyilişte
    None: None,      # şapka, çanta, sal... manuel
}

# İç çamaşır / çorap her giyilişte kirli
_ONE_WEAR_CATEGORIES = {"iccamasir", "corap"}


class LaundryRule:
    """Bir kategorinin otomatik kirli kuralı."""

    __slots__ = ("enabled", "wear_limit")

    def __init__(self, enabled: bool, wear_limit: Optional[int]):
        self.enabled = bool(enabled)
        self.wear_limit = wear_limit if wear_limit and wear_limit > 0 else None

    def as_dict(self) -> dict:
        return {"enabled": self.enabled, "wear_limit": self.wear_limit}


def default_rule(category: str) -> LaundryRule:
    """Kategorinin fabrika ayarı kuralı."""
    name = normalize(category)
    if name in _ONE_WEAR_CATEGORIES:
        return LaundryRule(enabled=True, wear_limit=1)
    limit = _DEFAULT_LIMITS.get(group_of(name))
    if limit is None:
        return LaundryRule(enabled=False, wear_limit=None)
    return LaundryRule(enabled=True, wear_limit=limit)


def normalize_rules(raw: Optional[dict]) -> dict[str, LaundryRule]:
    """Kullanıcının kayıtlı kural sözlüğünü güvenli hale getirir."""
    rules: dict[str, LaundryRule] = {}
    if not raw or not isinstance(raw, dict):
        return rules
    for category, value in raw.items():
        if not isinstance(category, str) or not isinstance(value, dict):
            continue
        limit = value.get("wear_limit")
        if isinstance(limit, bool) or not isinstance(limit, (int, float)):
            limit = None
        rules[normalize(category)] = LaundryRule(
            enabled=value.get("enabled") is True,
            wear_limit=int(limit) if limit else None,
        )
    return rules


def rule_for(category: str, user_rules: Optional[dict]) -> LaundryRule:
    """Kategorinin etkili kuralı: kullanıcı ayarı > varsayılan."""
    name = normalize(category)
    user_rule = normalize_rules(user_rules).get(name)
    if user_rule is not None:
        return user_rule
    return default_rule(name)


def should_mark_dirty(wear_count: int, rule: LaundryRule) -> bool:
    """Bu giyilme sayısıyla parça otomatik kirli sayılır mı?"""
    if not rule.enabled or rule.wear_limit is None:
        return False
    return wear_count >= rule.wear_limit
