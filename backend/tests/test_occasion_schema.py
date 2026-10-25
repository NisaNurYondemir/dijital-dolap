import pytest
from pydantic import ValidationError

from schemas.occasion import OccasionGroupCreate, OccasionGroupUpdate
from schemas.outfit import OutfitCreate, OutfitUpdate
from schemas.wear import WearCreate


def test_group_name_is_trimmed():
    group = OccasionGroupCreate(name="  Okul  ")
    assert group.name == "Okul"


def test_blank_group_name_is_rejected():
    with pytest.raises(ValidationError):
        OccasionGroupCreate(name="   ")
    with pytest.raises(ValidationError):
        OccasionGroupUpdate(name="   ")


def test_color_is_normalized_and_validated():
    assert OccasionGroupCreate(name="Okul", color="#4c6fff").color == "#4C6FFF"
    assert OccasionGroupCreate(name="Okul", color="").color is None
    with pytest.raises(ValidationError):
        OccasionGroupCreate(name="Okul", color="mavi")
    with pytest.raises(ValidationError):
        OccasionGroupUpdate(color="#12345")


def test_outfit_occasion_ids_are_optional():
    created = OutfitCreate(clothing_ids=[1, 2])
    assert created.occasion_ids == []
    assert OutfitUpdate().occasion_ids is None
    assert OutfitUpdate(occasion_ids=[3, 4]).occasion_ids == [3, 4]


def test_wear_can_reference_occasion_group():
    entry = WearCreate(outfit_id=1, occasion_group_id=7)
    assert entry.occasion_group_id == 7
