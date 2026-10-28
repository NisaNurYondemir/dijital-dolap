from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

from calendar_insights import EventInsight, event_insights

NOW = datetime.now(timezone.utc)


def event(event_id, title, kind, event_date, occasion_group_id=None):
    return SimpleNamespace(
        id=event_id,
        title=title,
        kind=kind,
        event_date=event_date,
        occasion_group_id=occasion_group_id,
    )


def item(category, wearable=True):
    return SimpleNamespace(category=category, is_wearable=wearable)


def test_upcoming_formal_event_without_formal_items_warns():
    event_ = event(1, "Ablamın Düğünü", "dugun", NOW + timedelta(days=21))
    result = event_insights(
        [event_],
        [item("tshirt"), item("sandalet")],       # formal set yok
        NOW,
    )
    assert len(result) == 1
    insight = result[0]
    assert insight.days_left == 21
    assert insight.ready is False
    assert "temiz özel gün kombinleri eksik" in insight.message


def test_formal_event_ready_when_dress_and_clean():
    event_ = event(1, "Ablamın Düğünü", "dugun", NOW + timedelta(days=7))
    result = event_insights(
        [event_],
        [item("elbise", wearable=True), item("topuklu")],
        NOW,
    )
    assert result[0].ready is True


def test_dirty_formal_items_do_not_count():
    event_ = event(1, "Kına", "kina", NOW + timedelta(days=10))
    result = event_insights(
        [event_],
        [item("gomlek", wearable=False), item("pantolon", wearable=False)],
        NOW,
    )
    assert result[0].ready is False


def test_window_and_past_events_are_skipped():
    past = event(1, "geçmiş", "dugun", NOW - timedelta(days=1))
    far = event(2, "çok uzak", "dugun", NOW + timedelta(days=60))
    near = event(3, "yakın", "genel", NOW + timedelta(days=5))
    result = event_insights([past, far, near], [], NOW)
    assert [i.event_id for i in result] == [3]


def test_linked_saved_occasion_marks_ready():
    event_ = event(1, "Nikah Töreni", "genel", NOW + timedelta(days=14), occasion_group_id=5)
    result = event_insights(
        [event_],
        [item("tshirt")],
        NOW,
        saved_occasion_ids={5},
    )
    assert result[0].ready is True
    assert "kaydedilmiş bir kombin" in result[0].message
