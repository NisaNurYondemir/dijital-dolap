from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import relationship

from database import Base
from models.outfit import outfit_occasions


class OccasionGroup(Base):
    """Kullanıcının kombinlerini grupladığı amaç/ortam etiketi.

    Varsayılanlar (Okul, İş, Arkadaş...) kayıt sırasında oluşturulur;
    kullanıcı kendi gruplarını da ekleyebilir.
    """

    __tablename__ = "occasion_groups"
    __table_args__ = (
        UniqueConstraint("user_id", "name", name="uq_occasion_groups_user_name"),
    )

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    name = Column(String, nullable=False)
    emoji = Column(String, nullable=True)
    color = Column(String, nullable=True)   # "#4C6FFF"
    is_default = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    outfits = relationship(
        "Outfit",
        secondary=outfit_occasions,
        back_populates="groups",
    )
