"""Desen sınıflandırıcısı: CLIP görsel özellikleri üzerine lineer probe.

Zero-shot desen tahmini (pattern.py) etiketli veriyle daha da iyileştirilebilir.
Bu betik, `train_pattern_probe.py --data <klasor>` ile çalıştırılır ve
`weights/pattern_probe.pt` üretir; `pattern.py` bu dosyayı görürse otomatik
olarak probe'u kullanır.

Veri düzeni:
    <veri_seti>/{train,test}/<desen_adi>/*.jpg
    Desen adları: pattern_rules.PATTERN_TYPES (bilinmiyor hariç)

Örnek:
    python train_pattern_probe.py --data datasets/patterns --out models/pattern_probe.pt

Etiketleme ipucu: en az 150-300 görsel yeterlidir (sınıf başına ~30).
"""
import argparse
import hashlib
import time
from pathlib import Path

import torch
import torch.nn as nn
from PIL import Image

import clip_category as cc
from pattern_rules import PATTERN_TYPES

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
PROMPT_LABELS = [t for t in PATTERN_TYPES if t != "bilinmiyor"]


def _classes_in(folder: Path) -> list[str]:
    names = sorted({
        p.name for p in folder.iterdir()
        if p.is_dir() and p.name in PROMPT_LABELS
    })
    if not names:
        raise SystemExit(f"{folder} içinde geçerli desen klasörü yok")
    return names


def _image_paths(folder: Path) -> list[Path]:
    return sorted(
        p for p in folder.rglob("*")
        if p.is_file() and p.suffix.lower() in IMAGE_EXTENSIONS
    )


def _features(folder: Path, classes: list[str], cache_dir: Path,
              batch_size: int = 32) -> tuple[torch.Tensor, torch.Tensor]:
    key = hashlib.md5(
        f"{folder}|{','.join(classes)}|{len(_image_paths(folder))}".encode()
    ).hexdigest()[:10]
    cache = cache_dir / f"pattern_{folder.name}_{key}.pt"
    if cache.is_file():
        blob = torch.load(cache, map_location="cpu", weights_only=True)
        print(f"[önbellek] {cache} ({len(blob['y'])} örnek)")
        return blob["x"], blob["y"]

    entries: list[tuple[Path, int]] = []
    for idx, cls in enumerate(classes):
        for path in _image_paths(folder / cls):
            entries.append((path, idx))

    xs, ys = [], []
    started = time.time()
    for start in range(0, len(entries), batch_size):
        chunk = entries[start:start + batch_size]
        tensors, labels = [], []
        for path, label in chunk:
            with Image.open(path) as img:
                tensors.append(cc.preprocess(img.convert("RGB")))
            labels.append(label)
        batch = torch.stack(tensors).to(cc.device)
        with torch.no_grad():
            feats = cc.model.encode_image(batch)
            feats = feats / feats.norm(dim=-1, keepdim=True)
        xs.append(feats.cpu())
        ys.extend(labels)
        done = len(ys)
        if done % 320 < batch_size:
            rate = done / max(1e-6, time.time() - started)
            print(f"  {folder.name}: {done}/{len(entries)} ({rate:.1f}/sn)")

    x = torch.cat(xs)
    y = torch.tensor(ys)
    cache_dir.mkdir(parents=True, exist_ok=True)
    torch.save({"x": x, "y": y}, cache)
    print(f"[kaydedildi] {cache} ({x.shape[0]} örnek)")
    return x, y


def main() -> int:
    parser = argparse.ArgumentParser(description="Desen lineer probe eğitimi")
    parser.add_argument("--data", type=Path, required=True,
                        help="Veri seti kökü (train/ ve test/ içermeli)")
    parser.add_argument("--out", type=Path, default=Path("weights/pattern_probe.pt"))
    parser.add_argument("--cache", type=Path, default=None)
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--epochs", type=int, default=400)
    parser.add_argument("--lr", type=float, default=1e-3)
    parser.add_argument("--wd", type=float, default=1e-4)
    args = parser.parse_args()

    train_dir, test_dir = args.data / "train", args.data / "test"
    if not train_dir.is_dir() or not test_dir.is_dir():
        print("train/ ve test/ klasörleri bulunamadı.")
        return 2

    classes = _classes_in(train_dir)
    print(f"Sınıflar ({len(classes)}): {', '.join(classes)}")

    cache_dir = args.cache or (args.data.parent / "features")
    x_tr, y_tr = _features(train_dir, classes, cache_dir, args.batch_size)
    x_te, y_te = _features(test_dir, classes, cache_dir, args.batch_size)

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
    print(f"\nDesen probe test top-1: {test_acc:.1%}")

    args.out.parent.mkdir(parents=True, exist_ok=True)
    torch.save({
        "state_dict": head.state_dict(),
        "classes": classes,
        "in_features": x_tr.shape[1],
    }, args.out)
    print(f"Model kaydedildi: {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
