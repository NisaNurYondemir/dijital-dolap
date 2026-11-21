/// Backend (CLIP) kategori adı -> Türkçe etiket. Tek kaynak bu harita.
/// Sıra, form ve çiplerdeki görünüm sırasıdır.
const Map<String, String> kCategoryLabels = {
  'tshirt': 'Tişört',
  'gomlek': 'Gömlek',
  'kazak': 'Kazak',
  'hoodie': 'Kapüşonlu',
  'ceket': 'Ceket',
  'mont': 'Mont',
  'pantolon': 'Pantolon',
  'sort': 'Şort',
  'etek': 'Etek',
  'elbise': 'Elbise',
  'sneaker': 'Sneaker',
  'topuklu': 'Topuklu ayakkabı',
  'bluz': 'Bluz',
  'blazer': 'Blazer',
  'esofman': 'Eşofman üstü',
  'sweatshirt': 'Sweatshirt',
  'hirka': 'Hırka',
  'tulum': 'Tulum',
  'atlet': 'Atlet',
  'jean': 'Jean',
  'takim elbise': 'Takım elbise',
  'ic camasir': 'İç çamaşırı',
  'corap': 'Çorap',
  'ayakkabi': 'Ayakkabı',
  'bot': 'Bot',
  'sandalet': 'Sandalet',
  'kemer': 'Kemer',
  'sapka': 'Şapka',
  'canta': 'Çanta',
  'sal': 'Şal',
};

/// Haritada yoksa (ör. 'unknown') ham adı döndürür.
String categoryLabel(String category) {
  return kCategoryLabels[category] ?? (category == 'unknown' ? 'Bilinmeyen' : category);
}

const Map<String, String> kSeasonLabels = {
  'tum': 'Tüm mevsimler',
  'yaz': 'Yaz',
  'kis': 'Kış',
  'ilkbahar': 'İlkbahar',
  'sonbahar': 'Sonbahar',
};

/// Backend desen anahtarı -> Türkçe etiket (pattern_rules.PATTERN_TYPES).
const Map<String, String> kPatternLabels = {
  'duz': 'Düz',
  'cizgili': 'Çizgili',
  'ekose': 'Ekose',
  'puantiyeli': 'Puantiyeli',
  'cicekli': 'Çiçekli',
  'geometrik': 'Geometrik',
  'hayvan': 'Hayvan desenli',
  'baskili': 'Baskılı',
  'diger': 'Dokulu/desenli',
  'bilinmiyor': 'Bilinmiyor',
};

String patternLabel(String? pattern) {
  if (pattern == null || pattern.isEmpty) return 'Bilinmiyor';
  return kPatternLabels[pattern] ?? pattern;
}

const Map<String, String> kPatternScaleLabels = {
  'ince': 'İnce',
  'orta': 'Orta',
  'iri': 'İri',
  'bilinmiyor': 'Bilinmiyor',
};