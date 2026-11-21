"""Renk paleti çıkarımı testleri (sentetik görsellerle, model yüklemeden)."""
import io

import numpy as np
from PIL import Image

from image_processing import extract_palette

RED = (200, 20, 20)
BLUE = (20, 20, 180)
GREEN = (20, 150, 60)
WHITE = (255, 255, 255)


def _png(img: Image.Image) -> bytes:
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def _stripes(parts, width=300, height=200) -> Image.Image:
    """parts: [(rgb, oran), ...] dikey şeritler."""
    arr = np.zeros((height, width, 4), dtype=np.uint8)
    x = 0
    for rgb, ratio in parts:
        w = int(round(width * ratio))
        arr[:, x:x + w] = (*rgb, 255)
        x += w
    return Image.fromarray(arr, "RGBA")


def test_three_color_stripes_are_kept():
    img = _stripes([(RED, 1 / 3), (BLUE, 1 / 3), (GREEN, 1 / 3)])
    palette = extract_palette(_png(img))

    assert len(palette) == 3
    assert abs(sum(p.ratio for p in palette) - 1.0) < 0.01
    assert {p.name for p in palette} == {"kırmızı", "mavi", "yeşil"}
    # Oranlar birbirine yakın
    assert all(0.25 <= p.ratio <= 0.42 for p in palette)


def test_dominant_color_is_first():
    img = _stripes([(RED, 0.7), (BLUE, 0.3)])
    palette = extract_palette(_png(img))

    assert palette[0].name == "kırmızı"
    assert palette[0].ratio > palette[1].ratio
    assert abs(palette[0].ratio - 0.7) < 0.05


def test_transparent_background_is_ignored():
    img = Image.new("RGBA", (200, 200), (0, 0, 0, 0))
    arr = np.asarray(img).copy()
    arr[:, :100] = (*RED, 255)          # sol yarı kırmızı, sağ yarı şeffaf
    palette = extract_palette(_png(Image.fromarray(arr, "RGBA")))

    assert len(palette) == 1
    assert palette[0].name == "kırmızı"
    assert palette[0].ratio == 1.0


def test_single_color_image_returns_one_entry():
    img = _stripes([(BLUE, 1.0)])
    palette = extract_palette(_png(img))

    assert len(palette) == 1
    assert palette[0].name == "mavi"


def test_white_garment_is_not_dropped():
    """Beyaz bir kıyafet (şeffaf arka plan üzerinde) paletten düşmemeli."""
    img = Image.new("RGBA", (200, 200), (*WHITE, 255))
    palette = extract_palette(_png(img))

    assert len(palette) == 1
    assert palette[0].name == "beyaz"


def test_tiny_accent_below_threshold_is_dropped():
    # %97 kırmızı + %3 mavi: mavi eşik altında kalmalı
    img = _stripes([(RED, 0.97), (BLUE, 0.03)])
    palette = extract_palette(_png(img))

    assert len(palette) == 1
    assert palette[0].name == "kırmızı"
