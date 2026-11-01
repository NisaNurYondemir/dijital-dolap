from insights import build_wardrobe_insights

EMPTY_TOP = []
EMPTY_NEVER = []


def test_empty_wardrobe():
    lines = build_wardrobe_insights(
        items=0, wearable=0, dirty=0, ironing=0, wear_total=0,
        never_worn=[], top_worn=[], occasion_usage=[],
    )
    assert lines == ["Dolabın boş; ilk parçanı ekleyerek başla."]


def test_no_history_message():
    lines = build_wardrobe_insights(
        items=10, wearable=10, dirty=0, ironing=0, wear_total=0,
        never_worn=[], top_worn=[], occasion_usage=[],
    )
    assert any("kişiselleşir" in l for l in lines)


def test_top_worn_and_occasion():
    lines = build_wardrobe_insights(
        items=10, wearable=10, dirty=0, ironing=0, wear_total=12,
        never_worn=[],
        top_worn=[{"category": "gomlek", "wear_count": 5}],
        occasion_usage=[{"name": "İş", "wears": 6}],
    )
    assert any("gomlek" in l for l in lines)
    assert any("İş" in l for l in lines)


def test_unused_and_capacity_messages():
    lines = build_wardrobe_insights(
        items=10, wearable=4, dirty=2, ironing=4, wear_total=8,
        never_worn=[
            {"category": "mont", "dirty_or_ironing": False},
            {"category": "etek", "dirty_or_ironing": False},
        ],
        top_worn=[{"category": "tshirt", "wear_count": 3}],
        occasion_usage=[],
    )
    assert any("hiç giyilmemiş" in l for l in lines)
    assert any("6 tanesi yıkamada/ütüde" in l for l in lines)
