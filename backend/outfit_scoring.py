"""Kombin uyum puanı: renk, desen ve etkinlik uygunluğu.

Öneri motoru kendi skorunu ayrı hesaplar; bu modül kullanıcının elle
oluşturduğu kombinler ve kaydedilmiş kombinler için aynı açıklanabilir
puanı üretir.
"""
from dataclasses import dataclass, field
from typing import Optional, Sequence

from color_engine import ItemProfile, evaluate_outfit
from occasion_rules import occasion_label, outfit_occasion_fit
from suggestion import scope_of


@dataclass(frozen=True)
class OutfitScoreResult:
    score: float
    color_score: float
    pattern_score: float
    occasion_score: float = 1.0
    reasons: list[str] = field(default_factory=list)


def score_outfit(
    items: Sequence,
    occasion_type: Optional[str] = None,
) -> OutfitScoreResult:
    """Parçaların genel uyumunu ve (varsa) etkinlik uyumunu puanlar.

    Etkinlik seçiliyse genel skor, etkinlik uygunluğuyla yumuşak biçimde
    çarpılır. Sert uygunsuzlukta skor 0 olur ve nedeni açıklanır; kullanıcı
    yine de kombinini kaydedebilir, sadece uyarıyı görür.
    """
    item_list = list(items)
    profiles = [
        ItemProfile.from_item(item, scope=scope_of(item))
        for item in item_list
    ]
    total, color, pattern, reasons = evaluate_outfit(profiles)
    reasons = list(reasons)

    occasion_score = 1.0
    if occasion_type:
        occasion_score = outfit_occasion_fit(item_list, occasion_type)
        if occasion_score <= 0:
            total = 0.0
        else:
            total *= 0.75 + 0.25 * occasion_score
        label = occasion_label(occasion_type)
        if occasion_score <= 0:
            reasons.append(f"{label} için uygun olmayan parçalar var")
        elif occasion_score < 0.999:
            reasons.append(f"{label} için bazı parçalar tartışmalı")

    if len(item_list) < 2:
        reasons.insert(0, "Kombin için en az iki parça seç")

    return OutfitScoreResult(
        score=round(min(max(total, 0.0), 1.0), 3),
        color_score=round(color, 3),
        pattern_score=round(pattern, 3),
        occasion_score=round(occasion_score, 3),
        reasons=reasons,
    )
