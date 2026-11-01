"""Dolap özetidir (dashboard): veritabanından bağımsız hüner mantığı.

Girdi olarak dolap sayımları ve giyim istatistiklerini alır; kullanıcıya
Türkçe kısa içgörü cümleleri üretir.
"""
from typing import Optional


def build_wardrobe_insights(
    items: int,
    wearable: int,
    dirty: int,
    ironing: int,
    wear_total: int,
    never_worn: list[dict],
    top_worn: list[dict],
    occasion_usage: list[dict],
) -> list[str]:
    """Dolap durumu + giyim geçmişinden en fazla 4 ipucu cümlesi üretir."""
    lines: list[str] = []

    if items == 0:
        return ["Dolabın boş; ilk parçanı ekleyerek başla."]

    if wear_total == 0:
        lines.append(
            "Henüz giyim geçmişin yok; giydikçe öneriler sana göre kişiselleşir."
        )
    else:
        top = top_worn[0] if top_worn else None
        if top and top.get("wear_count", 0) > 0:
            label = top.get("category", "")
            lines.append(
                f"En sevdiğin parça: {label} ({top['wear_count']} kez giyildi)."
            )

    # Hiç giyilmeyenler: kullanıcıya "terk edilmiş" hissi verir
    unused = [i for i in never_worn if not i.get("dirty_or_ironing")]
    if len(unused) >= 2:
        lines.append(
            f"{len(unused)} parça hiç giyilmemiş — bu hafta birini denemeye ne dersin?"
        )

    # Yıkanan/ütü bekleyenlerin kapasiteyi düşürmesi
    if wearable < items * 0.6:
        lines.append(
            f"Parçalarının {items - wearable} tanesi yıkamada/ütüde; "
            f"giyilebilir dolabın {wearable} parçaya düşüyor."
        )

    # Amaç alışkanlığı
    if occasion_usage:
        first = occasion_usage[0]
        name = first.get("name") or first.get("occasion")
        count = first.get("wears") or first.get("count") or 0
        if name and count:
            lines.append(f"En sık giydiğin ortam: {name} ({count} giyim).")

    return lines[:4]
