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


## 11. Renk paleti ve desen farkındalığı (Faz 1)

Amaç: kıyafeti tek bir renge indirgemeden "baskın renk + 2 yan renk" ve
desen bilgisiyle temsil etmek; kombin motorunda desen çakışmasını ve çok
renkli parçaların uyumunu hesaba katmak.

### 11.1 Palet çıkarımı (`image_processing.py`)

`process_clothing_image` artık `palette` da döner:

```
rembg (arka plan) -> k-means (RGB, k=8) -> CIEDE2000 ile birleştirme (dE<18)
-> en yakın merkeze göre alan oranı -> oranı %8 altındakiler atılır
-> en fazla 3 renk (baskın + 2 yan) -> HSL + Türkçe renk adı
```

- `clothes.palette` JSON: `[{name, hue, saturation, lightness, ratio}, ...]`
- İlk eleman baskın renktir; `hue/saturation/lightness/color_name` alanları
  da bu renkle eşitlenir (tek renk davranışıyla tutarlı).
- Aynı adlı tonlar ayrıştırılır: `gri` -> `açık gri` / `koyu gri`.
- Palet yoksa eski davranış korunur (tek renk).

### 11.2 Desen sınıflandırıcı (`pattern.py`)

- CLIP ViT-B/32 zero-shot; 9 desen sınıfı: `duz, cizgili, ekose, puantiyeli,
  cicekli, geometrik, hayvan, baskili, diger`.
- Ölçek (`ince/orta/iri`) yalnızca periyodik desenlerde sorulur.
- Görsel gömme vektörü kategori ile paylaşılır (tek `encode_image`).
- Güven < 0,30 ise desen `bilinmiyor` olur (yanlış ceza yazmamak için).
- `train_pattern_probe.py` ile 150-300 etiketli görselden lineer probe
  eğitilebilir; `weights/pattern_probe.pt` varsa zero-shot yerine kullanılır.
- `pattern_rules.loudness()` desen türü + ölçek + renk sayısından 0-1
  görsel ağırlık üretir.

### 11.3 Karar motoru (`color_engine.py`)

`ItemProfile` = renk paleti + desen + loudness + rol (body/accessory).

- **Ortak renk birincil**: iki parçada hue farkı <= 20° olan bir çift varsa
  skor en az 0,92 (`ortak_renk`).
- **Triad destekçi**: palet üçlüsü hue çemberinde 120°±20° oturuyorsa
  (`palette_harmony == "triad"`) ortak renkli çiftlere +0,03 bonus.
  Triad zorunlu değildir; tek başına 3 renk uyumu aranmaz.
- **Çok renkli çakışma**: iki parça da >=2 kromatik renk taşıyor ve ortak
  renk yoksa skor x0,70 (`cok_renkli`).
- **Nötr çapa**: bir parça tamamen nötrse (siyah/beyaz/gri) 1,0.
- **Desen kuralı**: gövde parçalarında (üst/alt/elbise/dış) en fazla 1
  desenli parça. İki desenli gövde parçası -> 0,35; farklı tür + farklı
  ölçek + ortak renk varsa "bilinçli karışım" -> 0,60.
- **Aksesuar muaf**: şapka/atkı/çanta/ayakkabı deseni gövde sınırına sayılmaz;
  loudness toplamına 0,3 ağırlıkla girer.
- Toplam skor: `renk * (0,75 + 0,25 * desen)`. Desen bilgisi yoksa toplam
  skor renk skoruna eşittir (eski davranış birebir korunur).

### 11.4 API ve veritabanı

- `clothes` yeni alanlar: `palette (JSON), pattern, pattern_scale,
  pattern_source, pattern_confidence` (migration `b3c4d5e6f7a8`).
- `POST /clothes/analyze` yanıtı: `palette`, `pattern`, `pattern_scale`,
  `pattern_confidence`, `pattern_source`, `pattern_candidates`.
- Analiz sonucu geçici görselin yanına `.json` olarak yazılır; eski Flutter
  sürümü palet/desen göndermese bile kayıt sırasında tamamlanır.
- `GET /outfits/suggest` yanıtına `pattern_score` eklendi; nedenler desen
  açıklamalarını içerir.
- `GET /outfits/{id}/score` artık `score`, `color_score`, `pattern_score`
  döner.

### 11.5 Testler

- `tests/test_palette.py`: sentetik şeritler, şeffaf arka plan, beyaz kıyafet,
  eşik altı vurgu rengi.
- `tests/test_pattern_rules.py`: palet harmonisi, ortak renk, çok renkli
  ceza, nötr çapa, tek/çift desenli gövde, güç çakışması, aksesuar muafiyeti.
- `tests/test_suggestion_pattern.py`: desenli etek cezası, açıklama metni,
  baskılı ayakkabının sınırı tetiklememesi, desen verisi yokken eski skor.

## 12. Desen sınıflandırıcı doğruluk ölçümü ve iyileştirme

### 12.1 Ölçüm düzeneği

- 50 gerçek fotoğraf (10 kategori x 5, `clothing-dataset-small`).
- Her görsel tek tek görsel olarak incelenip desen türü etiketlendi
  (tek etiketleyici, 9 sınıf: düz, çizgili, ekose, puantiyeli, çiçekli,
  geometrik, hayvan, baskılı, dokulu).
- Etiketler `D:\tmp\pattern_eval\labels.json` altında; ölçüm betiği aynı
  ön işlemeyi (rembg + beyaz zemin) uygular, yani üretim yolu ölçülür.
- Ölçüm bir geliştirme kümesidir: prompt ve karar ayarları bu 50 görsel
  üzerinde yapıldı. Bağımsız başarım için ayrı etiketli küme gerekir.

### 12.2 Başlangıç durumu (v1)

| Metrik | Sonuç |
|---|---|
| Tür bazında birebir doğruluk | 34/50 = %68,0 |
| Düz/desenli ikili doğruluk | 39/50 = %78,0 |
| İkili kesinlik / duyarlılık | %67,7 / %95,5 |
| Gövde parçalarında birebir | 30/40 = %75,0 |

Hata dağılımı: gerçek düz kumaşların çoğu `dokulu/desenli` sınıfına kaçıyor
(kapitone mont, dantel, triko); ayrıca bazı düz parçalar `çiçekli` veya `ekose`
okunuyor. Sınıflandırıcı desenli parçayı neredeyse hiç kaçırmıyor, ancak düz
parçayı fazla desenli sayıyor.

### 12.3 Yapılan iyileştirmeler

1. **Prompt genişletme ve netleştirme**: düz sınıfı için "baskısız, tek renk,
   üniform kumaş" vurgulandı; her desen sınıfına ayırt edici örnekler
   (breton çizgi, flanel ekose, liberty çiçek, aztek geometrik vb.) eklendi.
2. **`diger` sınıfı zero-shot'tan çıkarıldı**: "dokulu/desenli" tanımı çok
   geniş olduğu için düz kumaşları yutuyordu. Anahtar veritabanında ve manuel
   seçimde kalır; otomatik tahminde kullanılmaz.
3. **Çoklu görünüm**: tam görünüm ve merkezden %35 kırpılmış yakın plan ayrı
   ayrı CLIP ile kodlanıp vektörlerin ortalaması alınır. Yakın plan küçük
   desenleri (çiçek, puantiye, ince çizgi) daha iyi ayırır. Kategori
   sınıflandırıcısı tam görünüm vektörünü paylaşmaya devam eder; ek maliyet
   görsel başına bir CLIP kodlamasıdır.

### 12.4 Sonuç (v2)

| Metrik | v1 | v2 |
|---|---|---|
| Tür bazında birebir doğruluk | %68,0 | **%84,0** (42/50) |
| Düz/desenli ikili doğruluk | %78,0 | **%90,0** (45/50) |
| İkili kesinlik / duyarlılık | %67,7 / %95,5 | %81,5 / %100 |
| Gövde parçalarında birebir | %75,0 | **%90,0** (36/40) |

Kalan hatalar: dantel elbisenin çiçekli okunması, küçük çiçekli kumaşın
hayvan desenine benzemesi, grafik baskılı şapkanın puantiyeli sanılması.
Bunların bir kısmı etiket sınırı da olabilir (dantel/çiçek, küçük çiçek/
leopar). Ayakkabı hataları aksesuar muafiyeti nedeniyle skoru doğrudan
etkilemez.

### 12.5 Geriye dönük uyumluluk

- `predict_pattern_from_features(features)` eski imzayla çalışmaya devam eder;
  `image_bytes` verilmezse yalnızca tam görünüm kullanılır.
- Mevcut kayıtlardaki `diger` etiketi geçerlidir; manuel düzenlemede seçilebilir.
- Kategori (CLIP) yolu değişmedi; 134 test geçer.
