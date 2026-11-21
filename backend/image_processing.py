"""Görüntü işleme modülü.

Yüklenen kıyafet fotoğrafı üzerinde sırasıyla:
1. Arka plan kaldırma (rembg)
2. Renk paleti çıkarma (baskın + yan renkler; k-means + CIEDE2000)
3. RGB → HSL dönüşümü (colorsys)
işlemlerini gerçekleştirir.

Palet, çok renkli/desenli kıyafetleri tek bir renge indirgemeden temsil eder.
Örnek: kırmızı-lacivert-yeşil çizgili gömlek ->
    [{kırmızı, %50}, {lacivert, %30}, {yeşil, %20}]
"""
import colorsys
import io
from dataclasses import dataclass, field
from typing import Optional

from colorthief import ColorThief
from PIL import Image
from rembg import new_session, remove


_SESSION = new_session("u2net")

# Paleti oluştururken kullanılan ayarlar.
MAX_PALETTE_COLORS = 3     # baskın + en fazla 2 yan renk
MIN_COLOR_RATIO = 0.08     # bu oranın altındaki renkler (dikiş, gölge) atılır
MERGE_DELTA_E = 18.0       # bu algısal mesafenin altındaki renkler birleştirilir
MAX_CLUSTERS = 8           # k-means küme sayısı (sonra birleştirilir)


@dataclass
class ColorResult:
    hue: float        # 0-360
    saturation: float # 0-100
    lightness: float  # 0-100
    r: int
    g: int
    b: int


@dataclass
class PaletteColor(ColorResult):
    ratio: float = 0.0          # görselde kapladığı alan oranı (0-1)
    name: Optional[str] = None  # "lacivert", "kırmızı" ...

    def as_dict(self) -> dict:
        return {
            "name": self.name,
            "hue": self.hue,
            "saturation": self.saturation,
            "lightness": self.lightness,
            "ratio": self.ratio,
        }


@dataclass
class ProcessingResult:
    image_bytes: bytes        # arka planı kaldırılmış PNG
    color: Optional[ColorResult]
    palette: list[PaletteColor] = field(default_factory=list)


def _rgb_to_hsl(r: float, g: float, b: float) -> tuple[float, float, float]:
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    return round(h * 360, 1), round(s * 100, 1), round(l * 100, 1)


def remove_background(image_bytes: bytes) -> bytes:
    return remove(image_bytes, session=_SESSION)


def extract_dominant_color(image_bytes: bytes) -> ColorResult:
    """Görselden dominant rengi çıkarır, HSL olarak döner.

    Geriye dönük uyumluluk için korunur; yeni akışta `extract_palette`
    kullanılır ve baskın renk paletin ilk elemanıdır.
    """
    ct = ColorThief(io.BytesIO(image_bytes))
    r, g, b = ct.get_color(quality=1)
    h, s, l = _rgb_to_hsl(r, g, b)
    return ColorResult(hue=h, saturation=s, lightness=l, r=r, g=g, b=b)


def _lab(rgb):
    """(3,) RGB (0-255) dizisini CIELAB'a çevirir."""
    import numpy as np
    from skimage.color import rgb2lab

    arr = np.asarray(rgb, dtype=float).reshape(1, 1, 3) / 255.0
    return rgb2lab(arr).reshape(3)


def _lab_batch(rgb):
    import numpy as np
    from skimage.color import rgb2lab

    return rgb2lab(np.asarray(rgb, dtype=float).reshape(-1, 1, 3) / 255.0).reshape(-1, 3)


def extract_palette(
    image_bytes: bytes,
    max_colors: int = MAX_PALETTE_COLORS,
    min_ratio: float = MIN_COLOR_RATIO,
    merge_delta: float = MERGE_DELTA_E,
) -> list[PaletteColor]:
    """Arka planı kaldırılmış görselden renk paleti çıkarır.

    Dönüş sırası önemlidir: ilk eleman baskın (en geniş alanlı) renktir.
    Oranlar korunan renkler arasında yeniden normalize edilir.
    """
    import numpy as np
    from skimage.color import deltaE_ciede2000
    from sklearn.cluster import KMeans

    with Image.open(io.BytesIO(image_bytes)) as src:
        arr = np.asarray(src.convert("RGBA"))

    if arr.size == 0:
        return []
    opaque = arr[arr[:, :, 3] >= 125]
    if opaque.size == 0:
        return []
    rgb = opaque[:, :3].astype(float)

    # K-means için örneklem (çok büyük fotoğraflarda hız).
    sample = rgb
    if len(sample) > 20000:
        sample = sample[:: max(1, len(sample) // 20000)]

    unique = np.unique(sample.astype(np.uint8), axis=0)
    k = int(min(MAX_CLUSTERS, len(unique)))
    if k <= 1:
        centers = [sample.mean(axis=0)]
    else:
        km = KMeans(n_clusters=k, n_init=3, random_state=0).fit(sample)
        centers = [np.asarray(c, dtype=float) for c in km.cluster_centers_]

    # Algısal olarak birbirine çok yakın merkezleri birleştir.
    kept: list["object"] = []
    kept_lab: list["object"] = []
    for center in centers:
        lab = _lab(center)
        if all(deltaE_ciede2000(lab.reshape(1, 1, 3), other.reshape(1, 1, 3))[0, 0] > merge_delta
               for other in kept_lab):
            kept.append(center)
            kept_lab.append(lab)

    if not kept:
        return []

    # Her pikseli en yakın palet rengine ata ve gerçek oranları hesapla.
    palette_lab = np.stack(kept_lab)
    pixel_lab = _lab_batch(rgb)
    distances = ((pixel_lab[:, None, :] - palette_lab[None, :, :]) ** 2).sum(axis=-1)
    labels = distances.argmin(axis=1)
    counts = np.bincount(labels, minlength=len(kept)).astype(float)
    ratios = counts / counts.sum()

    order = np.argsort(-ratios)
    chosen = [(idx, ratios[idx]) for idx in order if ratios[idx] >= min_ratio][:max_colors]
    if not chosen:                      # çok parçalı görselde eşik altı kalırsa
        chosen = [(int(order[0]), float(ratios[order[0]]))]

    total = sum(ratio for _, ratio in chosen)
    result: list[PaletteColor] = []
    for idx, ratio in chosen:
        r, g, b = (int(round(v)) for v in kept[idx][:3])
        h, s, l = _rgb_to_hsl(r, g, b)
        result.append(
            PaletteColor(
                hue=h, saturation=s, lightness=l, r=r, g=g, b=b,
                ratio=round(ratio / total, 3),
            )
        )

    # Renk adları (döngüsel içe aktarmayı önlemek için burada).
    from analysis import color_name

    for entry in result:
        entry.name = color_name(entry.hue, entry.saturation, entry.lightness)

    # Aynı adı taşıyan tonları ayırt et: "gri, gri" yerine "açık gri, koyu gri".
    _disambiguate_names(result)
    return result


def _disambiguate_names(entries: list[PaletteColor]) -> None:
    """Aynı adlı palet renklerine açıklık niteliği ekler (yerinde düzenler)."""
    from collections import Counter

    counts = Counter(entry.name for entry in entries)
    for entry in entries:
        if counts[entry.name] <= 1 or not entry.name:
            continue
        if entry.name.startswith(("açık ", "koyu ")):
            continue
        if entry.lightness >= 65:
            entry.name = f"açık {entry.name}"
        elif entry.lightness <= 30:
            entry.name = f"koyu {entry.name}"


def process_clothing_image(image_bytes: bytes) -> ProcessingResult:
    """Tam işleme pipeline'ı: arka plan kaldır + palet/renk tespit et."""
    cleaned = remove_background(image_bytes)
    palette = extract_palette(cleaned)
    if palette:
        first = palette[0]
        color = ColorResult(
            hue=first.hue, saturation=first.saturation,
            lightness=first.lightness, r=first.r, g=first.g, b=first.b,
        )
    else:
        try:
            color = extract_dominant_color(cleaned)
        except Exception:
            color = None
    return ProcessingResult(image_bytes=cleaned, color=color, palette=palette)
