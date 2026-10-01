import sys
import os
import colorsys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from rembg import remove
from colorthief import ColorThief
from image_processing import process_clothing_image, extract_dominant_color

IMG = os.path.join(os.path.dirname(__file__), "../test_clothing.jpg")
OUT = os.path.join(os.path.dirname(__file__), "../test_output.png")


def test_background_removal():
    with open(IMG, "rb") as f:
        output = remove(f.read())
    with open(OUT, "wb") as f:
        f.write(output)
    assert os.path.exists(OUT)
    print("Arka plan kaldırıldı.")


def test_dominant_color():
    ct = ColorThief(IMG)
    r, g, b = ct.get_color(quality=1)
    assert 0 <= r <= 255
    assert 0 <= g <= 255
    assert 0 <= b <= 255
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    print(f"RGB: ({r}, {g}, {b})")
    print(f"HSL: hue={round(h*360,1)}, sat={round(s*100,1)}, light={round(l*100,1)}")


def test_process_clothing_image():
    with open(IMG, "rb") as f:
        result = process_clothing_image(f.read())
    assert result.image_bytes is not None
    assert len(result.image_bytes) > 0
    assert result.color is not None
    assert 0 <= result.color.hue <= 360
    assert 0 <= result.color.saturation <= 100
    assert 0 <= result.color.lightness <= 100
    print(f"Hue: {result.color.hue}, Sat: {result.color.saturation}, Light: {result.color.lightness}")


def test_extract_dominant_color_direct():
    with open(IMG, "rb") as f:
        color = extract_dominant_color(f.read())
    assert color.r is not None
    print(f"RGB: ({color.r}, {color.g}, {color.b})")