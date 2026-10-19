"""CLIP görsel özellikleri üzerine lineer sınıflandırıcı (linear probe) eğitir.

CLIP modeli dondurulur; yalnızca küçük bir lineer katman (512 -> sınıf sayısı)
eğitilir. Bu, tam ince ayardan çok daha hızlıdır ve CPU'da birkaç dakikada biter.

Kullanım:
    python train_linear_probe.py --data <veri_seti_klasoru> [--out models/clip_linear_probe.pt]

Veri seti düzeni (clothing-dataset-small):
    <veri_seti>/{train,test}/<sinif_adi>/*.jpg

Akış:
  1. train/ ve test/ için CLIP görsel özellikleri toplu (batch) çıkarılır ve
     diskte önbelleğe alınır.
  2. Lineer katman eğitilir.
  3. test/ üzerinde top-1 doğruluk, aynı sınıf kümesinde zero-shot CLIP ile karşılaştırılır.

UYARI: Bu test setinde etiketler veri setinin kendi düzeni (ör. tüm ayakkabılar
"shoes" -> ayakkabi). Probe bu düzeni öğrendiği için doğruluğu, ince ayrım
(sandalet/bot) yapan zero-shot'a göre iyimser görünebilir.
"""
import argparse
import hashlib
import time
from pathlib import Path

import torch
import torch.nn as nn
from PIL import Image

import clip_category as cc
from eval_clip import IMAGE_EXTS, MAPPING


def _classes_in(split_dir: Path) -> list[str]:
    keys = {
        MAPPING[d.name.lower()]
        for d in split_dir.iterdir()
        if d.is_dir() and d.name.lower() in MAPPING
    }
    return sorted(keys)


def _iter_split(split_dir: Path, classes: list[str]):
    index = {c: i for i, c in enumerate(classes)}
    for class_dir in sorted(p for p in split_dir.iterdir() if p.is_dir()):
        key = MAPPING.get(class_dir.name.lower())
        if key is None:
            continue
        for img in sorted(class_dir.iterdir()):
            if img.suffix.lower() in IMAGE_EXTS:
                yield index[key], img


def _features(split_dir: Path, classes: list[str], cache_dir: Path, batch_size: int = 32):
    """CLIP görsel özelliklerini toplu çıkarır; yoksa hesaplayıp önbelleğe yazar."""
    tag = hashlib.md5((",".join(classes) + "|" + split_dir.name).encode()).hexdigest()[:10]
    cache = cache_dir / f"features_{split_dir.name}_{tag}.pt"
    if cache.is_file():
        print(f"[onbellek] {cache}")
        blob = torch.load(cache)
        return blob["x"], blob["y"], blob["paths"]

    entries = list(_iter_split(split_dir, classes))
    xs, ys, paths = [], [], []
    started = time.time()
    done = 0
    for start in range(0, len(entries), batch_size):
        chunk = entries[start:start + batch_size]
        tensors, labels, kept_paths = [], [], []
        for label, img in chunk:
            try:
                tensors.append(cc.preprocess(Image.open(img).convert("RGB")))
                labels.append(label)
                kept_paths.append(str(img))
            except OSError:
                print(f"  [atlandi] {img}")
        if not tensors:
            continue
        batch = torch.stack(tensors).to(cc.device)
        with torch.no_grad():
            f = cc.model.encode_image(batch)
            f = f / f.norm(dim=-1, keepdim=True)
        xs.append(f.cpu())
        ys.extend(labels)
        paths.extend(kept_paths)
        done += len(tensors)
        if done % 320 < batch_size:
            rate = done / (time.time() - started)
            print(f"  {split_dir.name}: {done}/{len(entries)} ({rate:.1f}/sn)")

    x = torch.cat(xs)
    y = torch.tensor(ys)
    cache_dir.mkdir(parents=True, exist_ok=True)
    torch.save({"x": x, "y": y, "paths": paths}, cache)
    print(f"[kaydedildi] {cache}  ({x.shape[0]} örnek, {x.shape[1]} boyut)")
    return x, y, paths


def _zero_shot_top1(x, y, classes: list[str]) -> float:
    """Aynı sınıf kümesiyle sınırlı zero-shot CLIP doğruluğu (adil karşılaştırma)."""
    idx = [cc.CATEGORIES.index(c) for c in classes]
    text = cc._get_text_features()[idx]
    text = text / text.norm(dim=-1, keepdim=True)
    with torch.no_grad():
        pred = (cc.CLIP_LOGIT_SCALE * x @ text.T).argmax(dim=-1)
    return (pred == y).float().mean().item()


def main() -> int:
    parser = argparse.ArgumentParser(description="CLIP üzerine lineer probe eğitimi")
    parser.add_argument("--data", type=Path, required=True,
                        help="Veri seti kök klasörü (train/ ve test/ içermeli)")
    parser.add_argument("--out", type=Path, default=Path("models/clip_linear_probe.pt"))
    parser.add_argument("--cache", type=Path, default=None,
                        help="Özellik önbellek klasörü (varsayılan: veri setinin yanındaki 'features')")
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--epochs", type=int, default=400)
    parser.add_argument("--lr", type=float, default=1e-3)
    parser.add_argument("--wd", type=float, default=1e-4)
    args = parser.parse_args()

    train_dir = args.data / "train"
    test_dir = args.data / "test"
    if not train_dir.is_dir() or not test_dir.is_dir():
        print("train/ ve test/ klasörleri bulunamadı.")
        return 2

    classes = _classes_in(train_dir)
    print(f"Sınıflar ({len(classes)}): {', '.join(classes)}")

    cache_dir = args.cache or (args.data.parent / "features")
    x_tr, y_tr, _ = _features(train_dir, classes, cache_dir, args.batch_size)
    x_te, y_te, _ = _features(test_dir, classes, cache_dir, args.batch_size)

    print("\nZero-shot CLIP (aynı sınıf kümesi) test top-1: "
          f"{_zero_shot_top1(x_te, y_te, classes):.1%}")

    torch.manual_seed(0)
    head = nn.Linear(x_tr.shape[1], len(classes))
    opt = torch.optim.Adam(head.parameters(), lr=args.lr, weight_decay=args.wd)
    loss_fn = nn.CrossEntropyLoss()

    head.train()
    for epoch in range(1, args.epochs + 1):
        opt.zero_grad()
        loss = loss_fn(head(x_tr), y_tr)
        loss.backward()
        opt.step()
        if epoch % 50 == 0 or epoch == 1:
            head.eval()
            with torch.no_grad():
                acc = (head(x_te).argmax(dim=-1) == y_te).float().mean().item()
            head.train()
            print(f"  epoch {epoch:4d}  loss={loss.item():.4f}  test_top1={acc:.1%}")

    head.eval()
    with torch.no_grad():
        test_acc = (head(x_te).argmax(dim=-1) == y_te).float().mean().item()
    print(f"\nLineer probe test top-1: {test_acc:.1%}")

    args.out.parent.mkdir(parents=True, exist_ok=True)
    torch.save({
        "state_dict": head.state_dict(),
        "classes": classes,            # probe'un eğitildiği sınıflar (uygulama anahtarları)
        "categories": cc.CATEGORIES,   # tam 20 kategori
        "in_features": x_tr.shape[1],
    }, args.out)
    print(f"Model kaydedildi: {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
