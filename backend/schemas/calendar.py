from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class EventCreate(BaseModel):
    title: str
    kind: str = "genel"
    event_date: datetime
    occasion_group_id: Optional[int] = None
    note: Optional[str] = None


class EventUpdate(BaseModel):
    title: Optional[str] = None
    kind: Optional[str] = None
    event_date: Optional[datetime] = None
    occasion_group_id: Optional[int] = None
    note: Optional[str] = None


class EventOut(BaseModel):
    id: int
    title: str
    kind: str
    event_date: datetime
    occasion_group_id: Optional[int] = None
    note: Optional[str] = None


class EventInsightOut(BaseModel):
    event_id: int
    title: str
    kind: str
    event_date: datetime
    days_left: int
    ready: bool
    message: str
