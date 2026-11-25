from sqlalchemy.orm import Session

from models.occasion import OccasionGroup

# (ad, emoji, renk, etkinlik tipi)
DEFAULT_OCCASIONS: list[tuple[str, str, str, str]] = [
    ("Okul", "🎓", "#4C6FFF", "casual"),
    ("İş", "💼", "#22305A", "work"),
    ("Arkadaş", "☕", "#F2B84B", "casual"),
    ("Romantik", "❤️", "#E85D75", "romantic"),
    ("Özel gün", "✨", "#9B51E0", "formal"),
    ("Spor", "🏃", "#27AE60", "sport"),
    ("Günlük", "🌤️", "#5B6478", "casual"),
]


def seed_default_occasions(db: Session, user_id: int) -> list[OccasionGroup]:
    """Kullanıcının hiç grubu yoksa varsayılanları oluşturur.

    Kullanıcı tüm gruplarını silerse bir sonraki listede varsayılanlar
    yeniden gelir; bu, boş ekran yerine kullanılabilir bir başlangıç sağlar.
    """
    has_any = (
        db.query(OccasionGroup)
        .filter(OccasionGroup.user_id == user_id)
        .count()
        > 0
    )
    if has_any:
        return []

    groups = [
        OccasionGroup(
            user_id=user_id,
            name=name,
            emoji=emoji,
            color=color,
            occasion_type=occasion_type,
            is_default=True,
        )
        for name, emoji, color, occasion_type in DEFAULT_OCCASIONS
    ]
    db.add_all(groups)
    db.commit()
    for group in groups:
        db.refresh(group)
    return groups
