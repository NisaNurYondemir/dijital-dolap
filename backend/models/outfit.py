from sqlalchemy import Column, Integer, ForeignKey, DateTime, Boolean, Table, func
from sqlalchemy.orm import relationship
from database import Base

# Outfits ↔ Clothes arası many-to-many köprü tablosu
outfit_items = Table(
    "outfit_items",
    Base.metadata,
    Column("outfit_id",   Integer, ForeignKey("outfits.id"),  primary_key=True),
    Column("clothing_id", Integer, ForeignKey("clothes.id"),  primary_key=True),
)

class Outfit(Base):
    __tablename__ = "outfits"

    id         = Column(Integer, primary_key=True, index=True)
    user_id    = Column(Integer, ForeignKey("users.id"), nullable=False)
    is_favorite = Column(Boolean, default=False, nullable=False)   # ← bunu ekle
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    owner    = relationship("User",     back_populates="outfits")
    clothes  = relationship("Clothing", secondary=outfit_items)


class WearHistory(Base):
    __tablename__ = "wear_history"

    id         = Column(Integer, primary_key=True, index=True)
    user_id    = Column(Integer, ForeignKey("users.id"),  nullable=False)
    outfit_id  = Column(Integer, ForeignKey("outfits.id"), nullable=False)
    worn_at    = Column(DateTime(timezone=True), server_default=func.now())