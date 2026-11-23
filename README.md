# Dijital Dolap

Kişisel gardırobunuzu dijitalleştiren, fotoğraflardan kıyafet tanıyan ve kombin önerileri sunan mobil uygulama.

## Özellikler

- Kullanıcı kaydı ve JWT tabanlı giriş
- Kıyafet ekleme, düzenleme ve silme
- Fotoğraftan otomatik arka plan kaldırma (`rembg`)
- CLIP modeli ile otomatik kategori tahmini ve renk analizi
- Dolap görünümünde kategoriye göre filtreleme
- Kombin önerileri, favorilere ekleme ve kombin kaydetme
- Giyim kaydı (wear log) ve profil/istatistik ekranı

## Mimari

| Katman | Teknoloji |
|---|---|
| Mobil | Flutter (Dart), Provider, `http`, `image_picker` |
| Backend | FastAPI (Python), SQLAlchemy, Alembic, JWT |
| Veritabanı | PostgreSQL 15 (Docker) |
| Görsel işleme | `rembg`, `Pillow`, `colorthief`, CLIP |

## Proje Yapısı

```
dijital-dolap/
├── backend/
│   ├── main.py              # FastAPI uygulaması
│   ├── auth.py              # JWT / parola işlemleri
│   ├── database.py          # SQLAlchemy bağlantısı
│   ├── image_processing.py  # Arka plan kaldırma, görsel işleme
│   ├── clip_category.py     # CLIP ile kategori tahmini
│   ├── color_engine.py      # Renk analizi
│   ├── suggestion.py        # Kombin öneri motoru
│   ├── models/              # user, clothing, outfit
│   ├── routers/             # auth, clothing, outfit, wear
│   ├── schemas/             # Pydantic şemaları
│   └── alembic/             # Veritabanı migrasyonları
└── mobile/
    ├── lib/screens/         # login, home, wardrobe, outfits, profile, add/edit
    ├── lib/providers/       # auth, clothing, outfit
    └── lib/models/, widgets/, theme/
```

## Kurulum

### 1. Veritabanı

```bash
docker compose up -d
```

PostgreSQL `localhost:5432` üzerinde `dolap` veritabanıyla ayağa kalkar.

### 2. Backend

```bash
cd backend
python -m venv venv
venv\Scripts\activate        # Windows
pip install -r requirements.txt
```

`backend/.env` dosyasını oluşturun:

```env
DATABASE_URL=postgresql+psycopg2://dolap:dolap123@localhost:5432/dolap
SECRET_KEY=<gizli-anahtar>
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=60
```

Migrasyonları uygulayıp sunucuyu başlatın:

```bash
alembic upgrade head
uvicorn main:app --reload
```

API dokümantasyonu: `http://localhost:8000/docs`

### 3. Mobil Uygulama

```bash
cd mobile
flutter pub get
flutter run
```

> Not: Uygulama backend'e bağlanırken `localhost` yerine emülatör/cihaz için uygun IP adresini kullanmanız gerekir.

## API

| Router | Açıklama |
|---|---|
| `auth_router` | Kayıt, giriş, token |
| `clothing_router` | Kıyafet CRUD ve görsel yükleme |
| `outfit_router` | Kombin oluşturma, favoriler |
| `wear_router` | Giyim kayıtları |

## Testler

```bash
cd backend
pytest
```
