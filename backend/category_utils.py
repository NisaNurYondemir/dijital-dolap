"""Kategori adlarını tek biçime indirgeyen küçük yardımcı.

Öneri motoru, çamaşır kuralları ve etkinlik uygunluk kuralları aynı
normalizasyonu kullanmalı; aksi hâlde "T-Shirt" ile "tshirt" farklı
davranır.
"""

_TR = str.maketrans("İIıŞşĞğÜüÖöÇç", "iiissgguuoocc")


def normalize_category(text: str) -> str:
    text = (text or "").translate(_TR).lower()
    for ch in (" ", "-", "_"):
        text = text.replace(ch, "")
    return text.strip()
