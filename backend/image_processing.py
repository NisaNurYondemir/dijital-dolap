"""Görüntü işleme modülü.

Yüklenen kıyafet fotoğrafı üzerinde sırasıyla:
1. Arka plan kaldırma (rembg)
2. Dominant renk tespiti (colorthief)
3. RGB → HSL dönüşümü (colorsys)
işlemlerini gerçekleştirir.
"""
import colorsys
import io
from dataclasses import dataclass
from typing import Optional

from colorthief import ColorThief
from PIL import Image
from rembg import new_session, remove


_SESSION = new_session("u2net")


@dataclass
class ColorResult:
    hue: float        # 0-360
    saturation: float # 0-100
    lightness: float  # 0-100
    r: int
    g: int
    b: int


@dataclass
class ProcessingResult:
    image_bytes: bytes        # arka planı kaldırılmış PNG
    color: Optional[ColorResult]



def remove_background(image_bytes: bytes) -> bytes:
    return remove(image_bytes, session=_SESSION)

def extract_dominant_color(image_bytes: bytes) -> ColorResult:
    """Görselden dominant rengi çıkarır, HSL olarak döner."""
    ct = ColorThief(io.BytesIO(image_bytes))
    r, g, b = ct.get_color(quality=1)
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    return ColorResult(
        hue=round(h * 360, 1),
        saturation=round(s * 100, 1),
        lightness=round(l * 100, 1),
        r=r, g=g, b=b,
    )


def process_clothing_image(image_bytes: bytes) -> ProcessingResult:
    """Tam işleme pipeline'ı: arka plan kaldır + renk tespit et."""
    cleaned = remove_background(image_bytes)
    color = extract_dominant_color(cleaned)
    return ProcessingResult(image_bytes=cleaned, color=color)