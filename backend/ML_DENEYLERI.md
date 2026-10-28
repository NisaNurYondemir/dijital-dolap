# Kıyafet Kategori Modeli — Doğruluk Çalışması

Bu dosya, kategori tahmininin doğruluğunu artırmak için yapılanları ve
ölçüm sonuçlarını özetler. Tüm çalışma `dijital-dolap-dev` kopyasında,
`ml-model` dalında yapılmıştır; `main` dalına dokunulmamıştır.

## 1. Sorunun teşhisi

`clip_category.py` içinde CLIP (ViT-B/32) şu şekilde çalışıyordu:

```python
CATEGORIES = ["tshirt", "gomlek", ..., "takim elbise", "ic camasir", "corap", "sal"]
PROMPTS = [f"a photo of a {cat}" for cat in CATEGORIES]
```

CLIP İngilizce odaklı eğitildiği için `"a photo of a takim elbise"`,
`"a photo of a corap"` gibi promptlar anlamsız token dizileriydi. Düşük
doğruluğun ana nedeni modelin kendisi değil, **prompt/etiket seçimiydi**.

## 2. Çözüm — İngilizce etiket + prompt ensembling

`backend/clip_category.py` yeniden yazıldı:

- Her kategori anahtarı **doğal İngilizce karşılıklara** eşlenir
  (`tshirt → t-shirt`, `takim elbise → suit`, `ic camasir → underwear`,
  `sal → scarf`, …).
- Kategori başına 2 karşılık × 5 prompt şablonu ortalanır ve normalize edilir
  (**prompt ensembling**).
- Metin özellikleri **bir kez** hesaplanıp önbelleğe alınır; her istekte
  yeniden hesaplanmaz.
- Dış arayüz değişmedi: `CATEGORIES`, `predict_top_categories`, `predict_category`.
  Bu yüzden `routers/clothing_router.py` ve Flutter tarafı etkilenmedi.

## 3. Ölçüm — `backend/eval_clip.py`

Etiketli, gerçek kıyafet fotoğraflarından oluşan bir test seti kullanıldı:
`datasets/clothing-dataset-small` (CC0 lisanslı, 10 sınıf).
Test seti: **372 görsel**.

```bash
python eval_clip.py datasets/clothing-dataset-small/test --legacy
```

### Sonuçlar (372 görsel, top-1)

| Yöntem | Top-1 | Top-3 |
|---|---|---|
| Eski (tek, karışık dilli prompt) | %26,3 (98/372) | — |
| **Yeni (İngilizce + ensemble)** | **%66,4 (247/372)** | **%94,6 (352/372)** |

Top-1 doğruluk **2,5 katından fazla** arttı; eğitim gerekmedi.

### Sınıf bazında top-1 (yeni yöntem)

| Sınıf | Top-1 |
|---|---|
| gomlek | %100 |
| pantolon | %100 |
| sapka | %91,7 |
| sort | %90,0 |
| tshirt | %88,5 |
| elbise | %86,7 |
| etek | %66,7 |
| kazak | %52,8 |
| ceket | %36,8 |
| ayakkabi | %30,1 |

### Kalan hatalar nerede?

Hataların çoğu, **birbirine çok yakın kategoriler** arasında:

| Doğru | Yanlış tahmin | Adet |
|---|---|---|
| ayakkabi | sandalet | 45 |
| ceket | mont | 22 |
| kazak | tshirt | 12 |
| kazak | ceket | 10 |
| kazak | gomlek | 7 |
| ayakkabi | bot | 6 |

Bu, zero-shot CLIP'in ince ayrım (ayakkabı/sandalet/bot, ceket/mont,
kazak/tişört) sınırıdır. **Top-3 %94,6** olduğu için doğru cevap neredeyse her
zaman ilk üç aday arasındadır; uygulamada kullanıcıya ilk 3 adayın gösterilmesi
(`category_candidates`) bu sınırı pratikte telafi eder.

### 20 kategori vs 10 kategori

Aynı görsellerde CLIP'i yalnızca test setindeki 10 sınıfla sınırlayınca top-1
**%66,4 → %87,6** çıkıyor. Yani hataların çoğu, test setinde hiç bulunmayan
komşu kategorilere (bot, sandalet, mont, hoodie) kaymaktan geliyor. Uygulamada
(20 kategori) en büyük risk bu komşu kategorilerdir; top-3 aday gösterimi bu
yüzden önemlidir.

## 4. (Opsiyonel) Lineer probe

`backend/train_linear_probe.py`: CLIP dondurulur, özellikleri üzerine yalnızca
küçük bir lineer katman (512 → sınıf sayısı) eğitilir. CPU'da hızlıdır.

```bash
python train_linear_probe.py --data datasets/clothing-dataset-small \
    --out models/clip_linear_probe.pt --epochs 3000 --lr 2e-3
```

### Sonuçlar (10 sınıf, aynı test seti)

| Yöntem | Top-1 |
|---|---|
| Zero-shot CLIP (10 sınıfla sınırlı) | %87,6 |
| **Lineer probe** | **%92,7** |

Probe yaklaşık 900 adımda yakınsıyor ve zero-shot'a göre **~5 puan** kazanç
sağlıyor. Eğitim yalnızca saniyeler sürüyor (görsel özellikleri bir kez
çıkarılıp önbelleğe alınıyor).

> **Not:** Bu test setinde etiketler veri setinin kendi düzenini kullanır
> (ör. tüm ayakkabılar `shoes → ayakkabi`). Probe bu düzeni öğrendiği için
> doğruluğu, ince ayrım yapan zero-shot'a göre iyimser görünebilir. Gerçek
> kazanç için probe'un **kendi çektiğiniz, uygulama kategorileriyle
> etiketlenmiş fotoğraflarla** eğitilmesi gerekir.

## 5. Yan kazanç

`backend/suggestion.py` kategori tablosuna CLIP'in tahmin ettiği
`hoodie` (üst) ve `takim elbise` (elbise) eklendi; testi
`tests/test_suggestion.py` içine yazıldı.

## 6. Dosyalar

| Dosya | Açıklama |
|---|---|
| `backend/clip_category.py` | İngilizce etiket + prompt ensembling + önbellek |
| `backend/eval_clip.py` | Etiketli set üzerinde doğruluk ölçümü (`--legacy` ile önce/sonra) |
| `backend/train_linear_probe.py` | CLIP özellikleri üzerine lineer sınıflandırıcı |
| `backend/suggestion.py` | Yeni kategoriler (`hoodie`, `takim elbise`) |
| `.gitignore` | `datasets/`, `models/`, `*.pt` eklendi |

## 7. Veri setini yeniden indirme

```bash
git clone --depth 1 https://github.com/alexeygrigorev/clothing-dataset-small \
    datasets/clothing-dataset-small
```

## 8. Bilinen sınırlar

- Test seti **ürün fotoğrafı**; uygulama gerçek fotoğrafları `rembg` ile arka
  planı silip beyaz zemine oturtuyor. Dağılım farkı doğruluğu bir miktar düşürebilir.
- Test seti 10 sınıf; uygulamada 20 kategori var. Ölçüm, kapsanan kategoriler
  için geçerlidir.
- GPU yok (`torch 2.14.1+cpu`); eğitim CPU'da.

## 9. Öneri motoru: geçmişten öğrenme (3. faz)

`suggestion.py` artık yalnızca renk uyumuna bakmıyor; giyim geçmişinden
üç tür sinyal öğreniyor ve önerilerin "neden" seçildiğini açıklıyor.

Sinyaller (`_wear_signals`, `routers/outfit_router.py`):

| Sinyal | Kaynak |
|---|---|
| `ItemHistory.rating_avg` | Parçanın giyimlerindeki ortalama puan (1-5 → 0-1) |
| `PairHistory.rating_avg` | İki parçanın birlikte giyilip puanlandığı ikililer |
| `occasion_*` alanları | Seçilen amaç grubundaki giyimler + o amaçla kaydedilmiş kombinlerdeki parçalar |
| `last_worn` | Son giyim tarihi → 3/7/14 gün eşiğiyle "dolaşım" skoru |

Nihai skor (`_is_candidate` filtrelerinden sonra):

```
tercih   = 0.50·parça_puanı + 0.20·ikili_puanı + 0.15·dolaşım + 0.15·amaç_yakınlığı
skor     = renk_uyumu · (0.80 + 0.20·tercih)          # aralık 0.8·renk .. renk
```

- Renk uyumu hâl â belirleyici (±%20 çarpan); geçmiş verisi renk sıralamasını
  devirme gücünde ama sınırlı.
- Geçmiş hiç yokken (`history`/`pair_history` boş ve amaç seçili değilken)
  eski davranış korunur: `skor == renk_uyumu`.
- Son 3 günde giyilen parça 0 dolaşım alır (tekrarı azaltır); hiç giyilmemiş
  veya 14 günden eski parça 1.0 alır.
- Amaç (ör. "İş") seçiliyken parça tercihinde o amaçtaki puanlar %40 ağırlıkla
  karışır; adaylar önce o amaçla ilişkili parçalara daraltılır, ilişkili
  parça üst/alt veya elbise kurmaya yetmiyorsa tüm dolap kullanılır.

Açıklamalar: `reasons` alanı kullanıcıya Türkçe nedenler döner ("İş için
yüksek puanladığın parçalar", "Birlikte iyi puanladığın bir ikili", "Uzun
süredir giyilmeyen parçalar", "Renkler birbiriyle çok uyumlu"). Mobil
öneri kartında etiket olarak gösterilir. Testler:
`backend/tests/test_suggestion_history.py` (7 test).

## 10. Hava durumu önerisi (4. faz)

`weather.py` — Open-Meteo istemcisi (API anahtarı yok):

- `fetch_weather(lat, lon)` → `WeatherSummary` (sıcaklık, yağış, rüzgar,
  WMO kodu, Türkçe açıklama). Ağ hatasında `WeatherError`; router zarif
  biçimde havasuz öneriye döner.
- `geocode(name)` → Şehir arama (yalnızca Türkiye sonuçları).
- Sıcaklık → mevsim önerisi (`season_hint`): ≥26 yaz, ≥18 ilkbahar,
  ≥7 sonbahar, altında kış. `needs_outerwear`: <14°C veya ıslak+<18°C.

`/outfits/suggest` artık `lat/lon/city` kabul eder:

```
hava varsa → mevsim filtresi (kullanıcı mevsim vermemişse) +
             soğuk/ıslak havada mont/ceket eklenir +
             nedenlere "Bugün hava: ...", "Soğuk görünüyor..." eklenir
mevsim filtresi dolabı sıfırlarsa → havasuz filtreyle yeniden dener
```

Yeni uç noktalar: `GET /weather/current?lat=&lon=&city=`,
`GET /weather/search?name=`. (`routers/weather_router.py`)

Mobil: Öneriler sekmesinde hava şeridi ("Şehri seç — hava uyarınca öner");
CitySearchDialog geocoding ile Türkiye şehirlerini listeler, seçim sonrası
öneriler havayla yenilenir (`WeatherProvider`). Testler:
`backend/tests/test_weather.py` + `test_suggestion_history.py`'ye hava testi.

