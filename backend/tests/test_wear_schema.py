import pytest
from pydantic import ValidationError

from schemas.wear import WearCreate, WearUpdate


def test_rating_must_be_between_1_and_5():
    assert WearCreate(outfit_id=1, rating=1).rating == 1
    assert WearCreate(outfit_id=1, rating=5).rating == 5
    with pytest.raises(ValidationError):
        WearCreate(outfit_id=1, rating=0)
    with pytest.raises(ValidationError):
        WearCreate(outfit_id=1, rating=6)


def test_blank_occasion_and_note_become_none():
    entry = WearCreate(outfit_id=1, occasion="   ", note="")
    assert entry.occasion is None
    assert entry.note is None


def test_occasion_is_trimmed():
    assert WearCreate(outfit_id=1, occasion="  okul ").occasion == "okul"
    assert WearUpdate(rating=4, occasion=" iş ").occasion == "iş"


def test_outfit_or_clothing_ids_are_optional_at_schema_level():
    # "En az biri" kontrolü router'da; şema ikisini de kabul eder.
    assert WearCreate().outfit_id is None
    assert WearCreate(clothing_ids=[1, 2]).clothing_ids == [1, 2]
