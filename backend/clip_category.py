import clip
import torch
from PIL import Image
import io

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

def predict_category(image_bytes: bytes) -> str:
    image = preprocess(Image.open(io.BytesIO(image_bytes)).convert("RGB")).unsqueeze(0).to(device)
    text = clip.tokenize(PROMPTS).to(device)

    with torch.no_grad():
        image_features = model.encode_image(image)
        text_features = model.encode_text(text)
        logits, _ = model(image, text)
        probs = logits.softmax(dim=-1).cpu().numpy()[0]

    best_idx = probs.argmax()
    return CATEGORIES[best_idx]