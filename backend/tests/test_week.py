from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

from week import build_week_plan

NOW = datetime(2026, 11, 1, 10, 0, tzinfo=timezone.utc)


def _wearable():
    return SimpleNamespace(is_wearable=True)


def _event(title, kind, days, eid=1):
    return SimpleNamespace(
        id=eid, title=title, kind=kind, event_date=NOW + timedelta(days=days)
    )


def _formal_wardrobe():
    return [
        SimpleNamespace(id=10, category="gomlek", is_wearable=True),
        SimpleNamespace(id=11, category="pantolon", is_wearable=True),
        SimpleNamespace(id=12, category="bot", is_wearable=True),
        SimpleNamespace(id=13, category="tshirt", is_wearable=True),
        SimpleNamespace(id=14, category="mont", is_wearable=False),
    ]


def test_formal_event_picks_clean_set():
    plans = build_week_plan(
        [_event("Kardeş düğünü", "dugun", 3)], _formal_wardrobe(), NOW
    )
    assert len(plans) == 1
    p = plans[0]
    assert p.days_left == 3
    assert not p.weather_headline
    # gömlek üst ayakkabı: 12 (mont değil)
    assert set(p.item_ids) <= {10, 11, 12}


def test_weather_attached_when_day_forecast_present():
    from weather import DayForecast

    forecast = {
        (NOW + timedelta(days=2)).date().isoformat(): DayForecast(
            date=(NOW + timedelta(days=2)).date().isoformat(),
            max_c=12.0,
            min_c=4.0,
            code=61,
            description="yağmurlu",
        ),
    }
    plans = build_week_plan(
        [_event("Nişan", "nisan", 2)], _formal_wardrobe(), NOW, forecast
    )
    p = plans[0]
    assert "yağmurlu" in p.weather_headline
    assert "12" in p.weather_headline
    assert p.needs_outerwear is True
    assert "Nişan" in p.message


def test_past_and_far_events_skipped():
    plans = build_week_plan(
        [_event("geçmiş", "dugun", -1, eid=2),
         _event("uzak", "dugun", 10, eid=3)],
        _formal_wardrobe(), NOW,
    )
    assert plans == []


def test_non_formal_event_message():
    plans = build_week_plan(
        [_event("Sınav", "sinav", 1)], _formal_wardrobe(), NOW
    )
    assert plans[0].message == "Sınav 1 gün sonra."
