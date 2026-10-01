from sqlalchemy import Column, Integer, String, DateTime, func
from database import Base
from sqlalchemy.orm import relationship

class User(Base):
    __tablename__ = "users"

    id         = Column(Integer, primary_key=True, index=True)
    email      = Column(String, unique=True, nullable=False, index=True)
    username   = Column(String, unique=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

  
    # class içine:
    clothes  = relationship("Clothing", back_populates="owner")
    outfits  = relationship("Outfit",   back_populates="owner")