from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Table,
    func,
)
from sqlalchemy.orm import relationship
from database import Base

# Outfits ↔ Clothes arası many-to-many köprü tablosu
outfit_items = Table(
    "outfit_items",
    Base.metadata,
    Column("outfit_id",   Integer, ForeignKey("outfits.id"),  primary_key=True),
    Column("clothing_id", Integer, ForeignKey("clothes.id"),  primary_key=True),
)

# Outfits ↔ OccasionGroups arası many-to-many köprü tablosu.
# Bir kombin birden fazla amaca hizmet edebilir (okul + günlük gibi).
outfit_occasions = Table(
    "outfit_occasions",
    Base.metadata,
    Column(
        "outfit_id",
        Integer,
        ForeignKey("outfits.id", ondelete="CASCADE"),
        primary_key=True,
    ),
    Column(
        "occasion_group_id",
        Integer,
        ForeignKey("occasion_groups.id", ondelete="CASCADE"),
        primary_key=True,
    ),
)

# WearHistory ↔ Clothes arası many-to-many köprü tablosu.
# Kombin kaydedilmemiş olsa bile tek tek parça giyimi kaydedilebilsin diye.
wear_items = Table(
    "wear_items",
    Base.metadata,
    Column(
        "wear_id",
        Integer,
        ForeignKey("wear_history.id", ondelete="CASCADE"),
        primary_key=True,
    ),
    Column(
        "clothing_id",
        Integer,
        ForeignKey("clothes.id", ondelete="CASCADE"),
        primary_key=True,
    ),
)


class Outfit(Base):
    __tablename__ = "outfits"

    id         = Column(Integer, primary_key=True, index=True)
    user_id    = Column(Integer, ForeignKey("users.id"), nullable=False)
    is_favorite = Column(Boolean, default=False, nullable=False)   # ← bunu ekle
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    owner    = relationship("User",     back_populates="outfits")
    clothes  = relationship("Clothing", secondary=outfit_items)
    groups   = relationship(
        "OccasionGroup",
        secondary=outfit_occasions,
        back_populates="outfits",
    )


class WearHistory(Base):
    __tablename__ = "wear_history"

    id         = Column(Integer, primary_key=True, index=True)
    user_id    = Column(Integer, ForeignKey("users.id"),  nullable=False)
    # Kombin silinse bile giyim geçmişi korunsun
    outfit_id  = Column(
        Integer,
        ForeignKey("outfits.id", ondelete="SET NULL"),
        nullable=True,
    )
    worn_at    = Column(DateTime(timezone=True), server_default=func.now())

    # Kullanıcı geri bildirimi
    rating     = Column(Integer, nullable=True)    # 1-5
    occasion   = Column(String, nullable=True)     # okul, iş, arkadaş, romantik...
    occasion_group_id = Column(
        Integer,
        ForeignKey("occasion_groups.id", ondelete="SET NULL"),
        nullable=True,
    )
    note       = Column(String, nullable=True)

    # İleride hava durumu entegrasyonu için anlık görüntü
    weather_temp      = Column(Float, nullable=True)
    weather_condition = Column(String, nullable=True)
    location          = Column(String, nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())

    outfit  = relationship("Outfit")
    clothes = relationship("Clothing", secondary=wear_items)
    occasion_group = relationship("OccasionGroup")
