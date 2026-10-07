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