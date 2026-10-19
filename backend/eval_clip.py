"""CLIP kategori tahmininin doğruluğunu etiketli bir veri seti üzerinde ölçer.

Kullanım (backend klasöründe, dolap ortamı etkin):
    python eval_clip.py <veri_klasoru> [--limit 100] [--topk 3] [--legacy] [--csv cikti.csv]

Veri klasörü ImageFolder düzeninde olmalı:
    <veri_klasoru>/<sinif_adi>/*.jpg

Örnek:
    python eval_clip.py datasets/clothing-dataset-small/test --legacy

--legacy verilirse, iyileştirme öncesi (tek, karışık dilli prompt) yöntem de
aynı görseller üzerinde çalıştırılır. Görsel özelliği bir kez hesaplanır;
iki yöntem yalnızca metin (prompt) tarafında ayrışır.
"""
import argparse
import io
import sys
from collections import Counter
from pathlib import Path

import clip
import torch
from PIL import Image

import clip_category as cc

# Veri seti sınıf adı (küçük harf) -> uygulama kategori anahtarı.
# clothing-dataset-small sınıfları buraya eşlenir.
MAPPING = {
    "t-shirt": "tshirt",
    "tshirt": "tshirt",
    "shirt": "gomlek",
    "longsleeve": "kazak",
    "outwear": "ceket",
    "pants": "pantolon",
    "shorts": "sort",
    "skirt": "etek",
    "dress": "elbise",
    "shoes": "ayakkabi",
    "hat": "sapka",
}

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}


def iter_images(root: Path):
    """(dogru_anahtar, sinif_adi, dosya_yolu) üretir; eşlenmeyen sınıfları atlar."""
    for class_dir in sorted(p for p in root.iterdir() if p.is_dir()):
        key = MAPPING.get(class_dir.name.lower())
        if key is None:
            print(f"[atlandi] eslenmeyen sinif: {class_dir.name}", file=sys.stderr)
            continue
        for img in sorted(class_dir.iterdir()):
            if img.suffix.lower() in IMAGE_EXTS:
                yield key, class_dir.name, img


_legacy_text = None


def _legacy_text_features() -> torch.Tensor:
    """İyileştirme öncesi: tek prompt, karışık Türkçe/İngilizce etiket."""
    global _legacy_text
    if _legacy_text is None:
        prompts = [f"a photo of a {c}" for c in cc.CATEGORIES]
        with torch.no_grad():
            t = cc.model.encode_text(clip.tokenize(prompts).to(cc.device))
            t = t / t.norm(dim=-1, keepdim=True)
        _legacy_text = t
    return _legacy_text


def _image_features(image_bytes: bytes) -> torch.Tensor:
    img = cc.preprocess(
        Image.open(io.BytesIO(image_bytes)).convert("RGB")
    ).unsqueeze(0).to(cc.device)
    with torch.no_grad():
        f = cc.model.encode_image(img)
        f = f / f.norm(dim=-1, keepdim=True)
    return f


def _probs(feat: torch.Tensor, text: torch.Tensor):
    with torch.no_grad():
        logits = cc.CLIP_LOGIT_SCALE * feat @ text.T
        return logits.softmax(dim=-1)[0].cpu().numpy()


def main() -> int:
    parser = argparse.ArgumentParser(description="CLIP kategori doğruluk ölçümü")
    parser.add_argument("data", type=Path, help="ImageFolder düzeninde veri klasörü")
    parser.add_argument("--limit", type=int, default=0,
                        help="Sınıf başına en fazla bu kadar görsel (0 = sınırsız)")
    parser.add_argument("--topk", type=int, default=3, help="Top-k başarı eşiği")
    parser.add_argument("--legacy", action="store_true",
                        help="İyileştirme öncesi yöntemi de çalıştır ve karşılaştır")
    parser.add_argument("--csv", type=Path, default=None,
                        help="Top-1 yanlışlarını bu CSV dosyasına yaz")
    args = parser.parse_args()

    if not args.data.is_dir():
        print(f"Klasör bulunamadı: {args.data}", file=sys.stderr)
        return 2

    new_text = cc._get_text_features()
    legacy_text = _legacy_text_features() if args.legacy else None

    per_class_total: Counter = Counter()
    per_class_top1: Counter = Counter()
    per_class_topk: Counter = Counter()
    errors: list[tuple[str, str, str]] = []  # (sinif, dogru, top1_tahmin)
    legacy_top1 = 0
    total = 0

    for truth, class_name, img_path in iter_images(args.data):
        if args.limit and per_class_total[truth] >= args.limit:
            continue

        feat = _image_features(img_path.read_bytes())
        probs = _probs(feat, new_text)
        order = probs.argsort()[::-1]
        predicted = [cc.CATEGORIES[i] for i in order[:args.topk]]

        per_class_total[truth] += 1
        total += 1
        if predicted[0] == truth:
            per_class_top1[truth] += 1
        else:
            errors.append((class_name, truth, predicted[0]))
        if truth in predicted:
            per_class_topk[truth] += 1

        if legacy_text is not None:
            lprobs = _probs(feat, legacy_text)
            if cc.CATEGORIES[int(lprobs.argmax())] == truth:
                legacy_top1 += 1

        if total % 25 == 0:
            print(f"  ... {total} görsel işlendi", file=sys.stderr)

    if total == 0:
        print("Hiç görsel bulunamadı.", file=sys.stderr)
        return 1

    top1_total = sum(per_class_top1.values())
    topk_total = sum(per_class_topk.values())
    print("\n=== Sonuç (iyileştirilmiş CLIP) ===")
    print(f"Toplam görsel : {total}")
    print(f"Top-1 başarı  : {top1_total}/{total} = {top1_total / total:.1%}")
    print(f"Top-{args.topk} başarı  : {topk_total}/{total} = {topk_total / total:.1%}")

    print("\n-- Sınıf bazında Top-1 --")
    for key in sorted(per_class_total):
        n = per_class_total[key]
        c = per_class_top1[key]
        print(f"  {key:12s} {c:3d}/{n:3d} = {c / n:5.1%}")

    if errors:
        print("\n-- En sık karışan sınıflar (doğru -> yanlış top-1) --")
        conf = Counter((t, p) for _, t, p in errors)
        for (t, p), n in conf.most_common(10):
            print(f"  {t:12s} -> {p:12s} : {n}")

    if args.legacy:
        print("\n=== Karşılaştırma (aynı görseller, Top-1) ===")
        print(f"  Eski (tek prompt) : {legacy_top1}/{total} = {legacy_top1 / total:.1%}")
        print(f"  Yeni (ensemble)   : {top1_total}/{total} = {top1_total / total:.1%}")

    if args.csv and errors:
        import csv
        with args.csv.open("w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(["sinif", "dogru", "top1_tahmin"])
            w.writerows(errors)
        print(f"\nYanlış tahminler yazıldı: {args.csv}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
