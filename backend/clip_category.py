"""CLIP (ViT-B/32) ile kıyafet kategorisi tahmini.

CLIP İngilizce odaklı eğitildiği için uygulamanın iç kategori anahtarları
("tshirt", "takim elbise", ...) doğrudan prompt olarak kullanılmaz. Bunun
yerine her anahtar İngilizce karşılıklarına ve birden çok prompt şablonuna
(prompt ensembling) eşlenir. Metin özellikleri bir kez hesaplanıp önbelleğe
alınır; böylece her istekte yeniden hesaplanmaz.

Dışa açık arayüz değişmedi: CATEGORIES, predict_top_categories, predict_category.
"""
import io

import clip
import torch
from PIL import Image

# Model bir kez yüklenir
device = "cuda" if torch.cuda.is_available() else "cpu"
model, preprocess = clip.load("ViT-B/32", device=device)
model.eval()

# Uygulama/veritabanı kategori anahtarları (değişmemeli; DB ve Flutter bu
# anahtarları kullanır).
CATEGORIES = [
    "tshirt", "gomlek", "kazak", "hoodie", "ceket", "mont",
    "pantolon", "sort", "etek", "elbise", "takim elbise",
    "ic camasir", "corap", "ayakkabi", "bot", "sandalet",
    "kemer", "sapka", "canta", "sal",
]

# Kategori anahtarı -> CLIP'in anladığı doğal İngilizce karşılıklar.
# (Eski sürümde "a photo of a takim elbise" gibi anlamsız promptlar vardı.)
ENGLISH_LABELS = {
    "tshirt": ["t-shirt", "tee shirt"],
    "gomlek": ["dress shirt", "button-up shirt"],
    "kazak": ["sweater", "knitted jumper"],
    "hoodie": ["hoodie", "hooded sweatshirt"],
    "ceket": ["jacket", "blazer"],
    "mont": ["winter coat", "down jacket"],
    "pantolon": ["trousers", "pants"],
    "sort": ["shorts"],
    "etek": ["skirt"],
    "elbise": ["dress"],
    "takim elbise": ["suit"],
    "ic camasir": ["underwear", "lingerie"],
    "corap": ["socks"],
    "ayakkabi": ["shoes", "sneakers"],
    "bot": ["boots"],
    "sandalet": ["sandals"],
    "kemer": ["belt"],
    "sapka": ["hat", "cap"],
    "canta": ["bag", "handbag"],
    "sal": ["scarf", "shawl"],
}

# Prompt şablonları: {} yerine İngilizce karşılık gelir.
PROMPT_TEMPLATES = [
    "a photo of a {}",
    "a photo of a {}, a piece of clothing",
    "a close-up photo of a {}",
    "a product photo of a {} on a white background",
    "a person wearing a {}",
]

# CLIP'in öğrenilmiş sıcaklığı (exp(logit_scale) ~ 100).
CLIP_LOGIT_SCALE = 100.0

# Geriye dönük uyumluluk: eski kod PROMPTS'u içe aktarıyor olabilir.
PROMPTS = [t.format(ENGLISH_LABELS[c][0]) for c in CATEGORIES for t in PROMPT_TEMPLATES]


def _build_text_features() -> torch.Tensor:
    """Her kategori için şablon ortalamalarını alıp normalize eder (N x D)."""
    prompts: list[str] = []
    owner: list[int] = []
    for idx, cat in enumerate(CATEGORIES):
        for name in ENGLISH_LABELS[cat]:
            for tpl in PROMPT_TEMPLATES:
                prompts.append(tpl.format(name))
                owner.append(idx)

    tokens = clip.tokenize(prompts).to(device)
    with torch.no_grad():
        feats = model.encode_text(tokens)
        feats = feats / feats.norm(dim=-1, keepdim=True)

    dim = feats.shape[-1]
    protos = torch.zeros(len(CATEGORIES), dim, device=device)
    for idx in range(len(CATEGORIES)):
        rows = feats[[j for j, o in enumerate(owner) if o == idx]]
        mean = rows.mean(dim=0)
        protos[idx] = mean / mean.norm()
    return protos


_text_features: "torch.Tensor | None" = None


def _get_text_features() -> torch.Tensor:
    global _text_features
    if _text_features is None:
        _text_features = _build_text_features()
    return _text_features


def probabilities(image_bytes: bytes):
    """Görsel için 20 kategoriye ait olasılık vektörü döner (numpy array)."""
    image = preprocess(
        Image.open(io.BytesIO(image_bytes)).convert("RGB")
    ).unsqueeze(0).to(device)
    with torch.no_grad():
        feat = model.encode_image(image)
        feat = feat / feat.norm(dim=-1, keepdim=True)
        logits = CLIP_LOGIT_SCALE * feat @ _get_text_features().T
        probs = logits.softmax(dim=-1)
    return probs.cpu().numpy()[0]


def predict_top_categories(image_bytes: bytes, k: int = 3) -> list[tuple[str, float]]:
    """En olası k kategoriyi (ad, olasılık) olarak, en olasıdan başlayarak döner."""
    probs = probabilities(image_bytes)
    top = probs.argsort()[::-1][:k]
    return [(CATEGORIES[i], float(probs[i])) for i in top]


def predict_category(image_bytes: bytes) -> str:
    return predict_top_categories(image_bytes, k=1)[0][0]
