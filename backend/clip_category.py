import io

import clip
import torch
from PIL import Image

# Model bir kez yüklenir
device = "cuda" if torch.cuda.is_available() else "cpu"
model, preprocess = clip.load("ViT-B/32", device=device)

CATEGORIES = [
    "tshirt", "gomlek", "kazak", "hoodie", "ceket", "mont",
    "pantolon", "sort", "etek", "elbise", "takim elbise",
    "ic camasir", "corap", "ayakkabi", "bot", "sandalet",
    "kemer", "sapka", "canta", "sal"
]

PROMPTS = [f"a photo of a {cat}" for cat in CATEGORIES]


def predict_top_categories(image_bytes: bytes, k: int = 3) -> list[tuple[str, float]]:
    """En olası k kategoriyi (ad, olasılık) olarak, en olasıdan başlayarak döner."""
    image = preprocess(Image.open(io.BytesIO(image_bytes)).convert("RGB")).unsqueeze(0).to(device)
    text = clip.tokenize(PROMPTS).to(device)

    with torch.no_grad():
        logits, _ = model(image, text)
        probs = logits.softmax(dim=-1).cpu().numpy()[0]

    top = probs.argsort()[::-1][:k]
    return [(CATEGORIES[i], float(probs[i])) for i in top]


def predict_category(image_bytes: bytes) -> str:
    return predict_top_categories(image_bytes, k=1)[0][0]