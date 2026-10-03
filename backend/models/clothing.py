from sqlalchemy import Column, Integer, String, Float, Boolean, ForeignKey, DateTime, func, false
from sqlalchemy.orm import relationship
from database import Base

class Clothing(Base):
    __tablename__ = "clothes"
    
    id          = Column(Integer, primary_key=True, index=True)
    user_id     = Column(Integer, ForeignKey("users.id"), nullable=False)

    # Kategori
    category    = Column(String, nullable=False)   # "tshirt", "pantolon", "elbise" vb.
    season      = Column(String, nullable=False)   # "yaz", "kis", "ilkbahar", "sonbahar", "tum"

    # Renk (HSL)
    hue         = Column(Float, nullable=True)     # 0-360
    saturation  = Column(Float, nullable=True)     # 0-100
    lightness   = Column(Float, nullable=True)     # 0-100
    color_name  = Column(String, nullable=True)    # "lacivert", "kırmızı" vb.

    # Durum
    is_dirty    = Column(Boolean, default=False)
    needs_ironing = Column(Boolean, default=False)
    is_ironed = Column(Boolean, nullable=False, default=False, server_default=false())

    # Görsel
    image_path  = Column(String, nullable=True)   # sunucu diskindeki yol

    created_at  = Column(DateTime(timezone=True), server_default=func.now())

    owner       = relationship("User", back_populates="clothes")

    @property
    def is_wearable(self) -> bool:
        """Temiz VE (ütü gerektirmiyorsa VEYA ütülenmişse) giyilebilir."""
        return (not self.is_dirty) and ((not self.needs_ironing) or bool(self.is_ironed))