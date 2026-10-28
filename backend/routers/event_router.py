from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session, selectinload

from auth import get_current_user, get_db
from calendar_insights import event_insights
from models.calendar_event import CalendarEvent
from models.clothing import Clothing
from models.occasion import OccasionGroup
from models.outfit import Outfit
from models.user import User
from schemas.calendar import EventCreate, EventInsightOut, EventOut, EventUpdate

router = APIRouter(prefix="/events", tags=["events"])


def _get_event(
    event_id: int,
    db: Session,
    user: User,
) -> CalendarEvent:
    event = (
        db.query(CalendarEvent)
        .filter(CalendarEvent.id == event_id, CalendarEvent.user_id == user.id)
        .first()
    )
    if not event:
        raise HTTPException(404, "Olay bulunamadı")
    return event


def _resolve_occasion(occasion_id: Optional[int], db: Session, user: User):
    if occasion_id is None:
        return None
    group = (
        db.query(OccasionGroup)
        .filter(
            OccasionGroup.id == occasion_id,
            OccasionGroup.user_id == user.id,
        )
        .first()
    )
    if not group:
        raise HTTPException(404, "Amaç grubu bulunamadı")
    return group.id


@router.get("/", response_model=list[EventOut])
def list_events(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Kullanıcının olayları, tarihe göre artan sıralı."""
    return (
        db.query(CalendarEvent)
        .filter(CalendarEvent.user_id == current_user.id)
        .order_by(CalendarEvent.event_date.asc(), CalendarEvent.id.asc())
        .all()
    )


@router.post("/", response_model=EventOut, status_code=201)
def create_event(
    req: EventCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if len(req.title.strip()) < 2:
        raise HTTPException(400, "Olay başlığı çok kısa")
    event = CalendarEvent(
        user_id=current_user.id,
        title=req.title.strip(),
        kind=req.kind,
        event_date=req.event_date,
        occasion_group_id=_resolve_occasion(req.occasion_group_id, db, current_user),
        note=req.note,
    )
    db.add(event)
    db.commit()
    db.refresh(event)
    return event


@router.patch("/{event_id}", response_model=EventOut)
def update_event(
    event_id: int,
    req: EventUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    event = _get_event(event_id, db, current_user)
    if req.title is not None:
        if len(req.title.strip()) < 2:
            raise HTTPException(400, "Olay başlığı çok kısa")
        event.title = req.title.strip()
    if req.kind is not None:
        event.kind = req.kind
    if req.event_date is not None:
        event.event_date = req.event_date
    if req.note is not None:
        event.note = req.note
    if req.occasion_group_id is not None:
        event.occasion_group_id = _resolve_occasion(
            req.occasion_group_id, db, current_user
        )
    db.commit()
    db.refresh(event)
    return event


@router.delete("/{event_id}", status_code=204)
def delete_event(
    event_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    event = _get_event(event_id, db, current_user)
    db.delete(event)
    db.commit()


@router.get("/insights", response_model=list[EventInsightOut])
def insights(
    window_days: int = Query(30, ge=1, le=90),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Yaklaşan olaylar için proaktif hazırlık uyarıları.

    - Olay tarihine ≤ `window_days` gün kalan olaylar listelenir.
    - Olaya bağlı amaç grubu için kayıtlı kombin varsa "hazır";
      formal türlerde temiz dolap setine göre uyarı üretilir.
    """
    events = (
        db.query(CalendarEvent)
        .filter(CalendarEvent.user_id == current_user.id)
        .all()
    )
    clothes = db.query(Clothing).filter(Clothing.user_id == current_user.id).all()
    found = event_insights(
        events,
        clothes,
        datetime.now(timezone.utc),
        saved_occasion_ids=_saved_occasion_ids(db, current_user),
        window_days=window_days,
    )
    return [
        EventInsightOut(
            event_id=i.event_id,
            title=i.title,
            kind=i.kind,
            event_date=i.event_date,
            days_left=i.days_left,
            ready=i.ready,
            message=i.message,
        )
        for i in found
    ]


def _saved_occasion_ids(db: Session, user: User) -> set[int]:
    rows = (
        db.query(Outfit)
        .options(selectinload(Outfit.groups))
        .filter(Outfit.user_id == user.id)
        .all()
    )
    ids: set[int] = set()
    for outfit in rows:
        for group in outfit.groups:
            ids.add(group.id)
    return ids
