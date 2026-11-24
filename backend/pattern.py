"""CLIP ile desen türü ve ölçeği tahmini.

İki mod desteklenir:
1. Zero-shot (varsayılan): desen adları İngilizce prompt kümesine çevrilir,
   metin prototipleri bir kez hesaplanıp önbelleğe alınır.
2. Linear probe: `weights/pattern_probe.pt` varsa (train_pattern_probe.py ile
   üretilir) CLIP görsel özellikleri üzerinde eğitilmiş küçük sınıflandırıcı
   kullanılır. Dosya yoksa sessizce zero-shot'a döner.

Görsel gömme vektörü `clip_category.image_features` ile bir kez çıkarılır;
kategori ve desen tahmini aynı vektörü paylaşır. Desen için ayrıca merkezden
kırpılmış bir yakın plan kodlanır ve iki vektörün ortalaması kullanılır.
"""
import io
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

import clip
import torch
from PIL import Image

import clip_category as cc
from pattern_rules import PATTERN_TYPES

# Desen anahtarı -> CLIP'in anladığı İngilizce ifadeler.
#
# `diger` bilinçli olarak burada yoktur: "dokulu/desenli" tanımı çok geniş
# olduğu için kapitone, dantel ve triko gibi düz kumaşları yutuyordu. Bu sınıf
# veritabanında ve manuel seçimde kalır, otomatik tahminde kullanılmaz.
PATTERN_PROMPTS = {
    "duz": [
        "a plain solid color garment",
        "a garment with no pattern at all",
        "a solid colored shirt without any print",
        "a plain fabric with a single uniform color",
        "a solid black t-shirt",
        "a plain white button down shirt",
        "a solid navy jacket with no print",
        "a smooth solid cotton fabric close up",
        "a garment made of one uniform color fabric",
        "a solid colored sweater with nothing printed on it",
    ],
    "cizgili": [
        "a striped garment",
        "a shirt with horizontal stripes",
        "a shirt with vertical stripes",
        "a fabric with striped pattern",
        "a breton striped shirt",
        "a striped knit sweater",
    ],
    "ekose": [
        "a plaid garment",
        "a checked shirt",
        "a checkered fabric",
        "a tartan pattern garment",
        "a flannel plaid shirt",
        "a checked button down shirt",
    ],
    "puantiyeli": [
        "a polka dot garment",
        "a fabric with small round dots",
        "a dress with polka dots",
        "a fabric with evenly spaced dots",
        "a dotted blouse",
    ],
    "cicekli": [
        "a floral print garment",
        "a dress with flower print",
        "a fabric with floral pattern",
        "a small repeating flower print fabric",
        "a liberty floral print fabric",
    ],
    "geometrik": [
        "a garment with geometric pattern",
        "a fabric with geometric shapes",
        "a zigzag pattern garment",
        "a fabric with triangles and diamonds",
        "an aztec geometric print fabric",
    ],
    "hayvan": [
        "an animal print garment",
        "a leopard print garment",
        "a zebra print fabric",
        "a snake print fabric",
    ],
    "baskili": [
        "a garment with a large graphic print",
        "a t-shirt with a picture print",
        "a sweatshirt with a large front print",
        "a t-shirt with a printed graphic on the chest",
        "a garment with one big picture print",
    ],
}

# Deseni daha iyi görmek için tam görünümün yanına merkezden kırpılmış bir
# yakın plan eklenir; iki gömme vektörünün ortalaması kullanılır.
CROP_RATIO = 0.35

# Ölçek yalnızca periyodik desenlerde sorulur.
SCALE_PROMPTS = {
    "cizgili": {
        "ince": ["a garment with thin fine stripes", "a fabric with narrow stripes"],
        "orta": ["a garment with medium stripes", "a fabric with regular stripes"],
        "iri": ["a garment with wide bold stripes", "a fabric with thick stripes"],
    },
    "ekose": {
        "ince": ["a garment with a small check pattern", "a fine checkered fabric"],
        "orta": ["a garment with a medium check pattern", "a regular plaid fabric"],
        "iri": ["a garment with a large check pattern", "a big tartan pattern"],
    },
    "puantiyeli": {
        "ince": ["a garment with tiny dots", "a fabric with small polka dots"],
        "orta": ["a garment with medium polka dots", "a fabric with regular dots"],
        "iri": ["a garment with large polka dots", "a fabric with big dots"],
    },
}

# "bilinmiyor" bir çıktı sınıfıdır, prompt'u yoktur; düşük güvende atanır.
PROMPT_LABELS = [t for t in PATTERN_TYPES if t in PATTERN_PROMPTS]

# Bu güvenin altında desen "bilinmiyor" kabul edilir (yanlış ceza yazmamak için).
MIN_CONFIDENCE = 0.30

_PROBE_PATH = Path(__file__).with_name("weights") / "pattern_probe.pt"

_text_cache: dict[tuple[str, ...], torch.Tensor] = {}
_probe = None


@dataclass(frozen=True)
class PatternResult:
    pattern: str
    confidence: float
    scale: str
    scale_confidence: float
    source: str                       # "zero_shot" | "probe"
    candidates: tuple[tuple[str, float], ...] = ()


def _label_prompts(labels: list[str], prompts: dict[str, list[str]]) -> list[str]:
    return [p for label in labels for p in prompts[label]]


def _prototypes(labels: list[str], prompts: dict[str, list[str]]) -> torch.Tensor:
    flat: list[str] = []
    owner: list[int] = []
    for idx, label in enumerate(labels):
        for prompt in prompts[label]:
            flat.append(prompt)
            owner.append(idx)
    key = tuple(flat)
    if key not in _text_cache:
        tokens = clip.tokenize(flat).to(cc.device)
        with torch.no_grad():
            feats = cc.model.encode_text(tokens)
            feats = feats / feats.norm(dim=-1, keepdim=True)
        dim = feats.shape[-1]
        protos = torch.zeros(len(labels), dim, device=cc.device)
        for idx in range(len(labels)):
            rows = feats[[j for j, o in enumerate(owner) if o == idx]]
            mean = rows.mean(dim=0)
            protos[idx] = mean / mean.norm()
        _text_cache[key] = protos
    return _text_cache[key]


def _probabilities(features: torch.Tensor, labels: list[str],
                   prompts: dict[str, list[str]]) -> torch.Tensor:
    protos = _prototypes(labels, prompts)
    with torch.no_grad():
        logits = cc.CLIP_LOGIT_SCALE * features @ protos.T
        return logits.softmax(dim=-1)[0]


def _load_probe():
    """Eğitilmiş lineer prob varsa yükler (yoksa None)."""
    global _probe
    if _probe is None and _PROBE_PATH.is_file():
        try:
            blob = torch.load(_PROBE_PATH, map_location=cc.device, weights_only=True)
        except TypeError:                       # eski torch sürümleri
            blob = torch.load(_PROBE_PATH, map_location=cc.device)
        head = torch.nn.Linear(blob["in_features"], len(blob["classes"]))
        head.load_state_dict(blob["state_dict"])
        head.eval()
        head.to(cc.device)
        _probe = (head, list(blob["classes"]))
    return _probe


def _center_crop_bytes(image_bytes: bytes, ratio: float = CROP_RATIO) -> bytes:
    """Görselin merkezinden kare kırpma üretir (desen detayı için)."""
    with Image.open(io.BytesIO(image_bytes)) as img:
        img = img.convert("RGB")
        width, height = img.size
        side = max(1, int(min(width, height) * ratio))
        left = (width - side) // 2
        top = (height - side) // 2
        crop = img.crop((left, top, left + side, top + side))
        buffer = io.BytesIO()
        crop.save(buffer, format="JPEG", quality=92)
        return buffer.getvalue()


def pattern_features(image_bytes: bytes,
                     base_features: Optional[torch.Tensor] = None,
                     ) -> torch.Tensor:
    """Tam görünüm ve merkez kırpma özelliklerinin ortalamasını döndürür.

    Tam görünüm tek başına küçük desenleri kaçırabiliyor; yakın plan ise
    desen türünü daha iyi ayırıyor. `base_features` verilirse tam görünüm
    yeniden kodlanmaz (kategori sınıflandırıcısıyla aynı vektör paylaşılır).
    """
    base = cc.image_features(image_bytes) if base_features is None else base_features
    crop = cc.image_features(_center_crop_bytes(image_bytes))
    merged = base + crop
    return merged / merged.norm(dim=-1, keepdim=True)


def predict_pattern(image_bytes: bytes) -> PatternResult:
    """Görsel için desen türü ve (mümkünse) ölçeğini tahmin eder."""
    return predict_pattern_from_features(cc.image_features(image_bytes), image_bytes)


def predict_pattern_from_features(
    features: torch.Tensor,
    image_bytes: Optional[bytes] = None,
) -> PatternResult:
    """Önceden çıkarılmış CLIP görsel özelliğinden desen tahmini.

    Kategori tahminiyle aynı vektör paylaşılırsa görselin tam görünümü
    yeniden kodlanmaz; yalnızca merkez kırpma eklenir.
    """
    if image_bytes is not None:
        features = pattern_features(image_bytes, base_features=features)

    probe = _load_probe()
    if probe is not None:
        head, classes = probe
        with torch.no_grad():
            probs = head(features).softmax(dim=-1)[0]
        source = "probe"
        labels = classes
        top = int(probs.argmax())
        pattern = labels[top]
        confidence = float(probs[top])
        candidates = tuple(
            (labels[int(i)], float(probs[int(i)]))
            for i in torch.argsort(probs, descending=True)[:3]
        )
    else:
        source = "zero_shot"
        probs = _probabilities(features, PROMPT_LABELS, PATTERN_PROMPTS)
        top = int(probs.argmax())
        pattern = PROMPT_LABELS[top]
        confidence = float(probs[top])
        candidates = tuple(
            (PROMPT_LABELS[int(i)], float(probs[int(i)]))
            for i in torch.argsort(probs, descending=True)[:3]
        )

    if confidence < MIN_CONFIDENCE:
        pattern = "bilinmiyor"

    scale, scale_conf = "bilinmiyor", 0.0
    if pattern in SCALE_PROMPTS:
        scale_labels = list(SCALE_PROMPTS[pattern].keys())
        scale_probs = _probabilities(features, scale_labels, SCALE_PROMPTS[pattern])
        best = int(scale_probs.argmax())
        scale = scale_labels[best]
        scale_conf = float(scale_probs[best])

    return PatternResult(
        pattern=pattern,
        confidence=round(confidence, 3),
        scale=scale,
        scale_confidence=round(scale_conf, 3),
        source=source,
        candidates=candidates,
    )
