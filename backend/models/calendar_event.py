from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, func
from sqlalchemy.orm import relationship

from database import Base


class CalendarEvent(Base):
    """Kullanıcının takvimindeki yaklaşan kıyafet gerektiren olay.

    Örnek: düğün, nişan, kına, özel gün, sınav, bayram. Uygulama,
    olay tarihine yaklaşırken hazırlık uyarısı üretir (ör. "3 hafta
    sonra düğün — galeri temiz özel gün kombinin yok").
    """

    __tablename__ = "calendar_events"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    title = Column(String, nullable=False)
    kind = Column(String, nullable=False, default="genel")
    event_date = Column(DateTime(timezone=True), nullable=False, index=True)
    # İsteğe bağlı amaç grubu bağlantısı: olayla hangi kombi tipinin uygunda
    # olduğunu işaretlemek için ("Özel gün", "İş" gibi).
    occasion_group_id = Column(
        Integer,
        ForeignKey("occasion_groups.id", ondelete="SET NULL"),
        nullable=True,
    )
    note = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    owner = relationship("User", back_populates="calendar_events")
    occasion_group = relationship("OccasionGroup")
