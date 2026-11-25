from types import SimpleNamespace

from occasion_rules import (
    ALLOWED,
    BLOCKED,
    SOFT,
    item_occasion_fit,
    outfit_occasion_fit,
)


def item(category):
    return SimpleNamespace(category=category)


def test_formal_blocks_loungewear():
    assert item_occasion_fit("esofman", "formal") == BLOCKED
    assert item_occasion_fit("sweatshirt", "formal") == BLOCKED
    assert item_occasion_fit("sort", "formal") == BLOCKED
    assert item_occasion_fit("gomlek", "formal") == ALLOWED


def test_sport_blocks_heels_and_formalwear():
    assert item_occasion_fit("topuklu", "sport") == BLOCKED
    assert item_occasion_fit("blazer", "sport") == BLOCKED
    assert item_occasion_fit("gomlek", "sport") == BLOCKED
    assert item_occasion_fit("sneaker", "sport") == ALLOWED
    assert item_occasion_fit("esofman", "sport") == ALLOWED


def test_debatable_items_are_soft_penalties():
    assert item_occasion_fit("sneaker", "formal") == SOFT
    assert item_occasion_fit("tshirt", "formal") == SOFT
    assert item_occasion_fit("jean", "work") == SOFT


def test_formal_outfit_needs_an_anchor():
    # Tişört + pantolon + sneaker: hiçbir resmi çapa yok.
    assert outfit_occasion_fit(
        [item("tshirt"), item("pantolon"), item("sneaker")], "formal"
    ) == BLOCKED
    # Bluz çapa görevi görür; sneaker yumuşak ceza alır ama kombin geçer.
    fit = outfit_occasion_fit(
        [item("bluz"), item("pantolon"), item("sneaker")], "formal"
    )
    assert 0 < fit < 1


def test_sport_outfit_with_heels_is_invalid():
    assert outfit_occasion_fit(
        [item("tshirt"), item("sort"), item("topuklu")], "sport"
    ) == BLOCKED
    assert outfit_occasion_fit(
        [item("tshirt"), item("sort"), item("sneaker")], "sport"
    ) > 0


def test_unknown_occasion_type_is_permissive():
    assert item_occasion_fit("esofman", None) == ALLOWED
    assert outfit_occasion_fit([item("esofman")], None) == 1.0
