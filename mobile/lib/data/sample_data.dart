import 'package:dijital_dolap/models/clothing_item.dart';

// ⚠️ GEÇİCİ VERİ — backend bağlanınca silinecek.
final sampleItems = <ClothingItem>[
  ClothingItem(
    id: 1, userId: 1, category: 'Üst', season: 'tum',
    hue: 220, saturation: 15, lightness: 92, colorName: 'beyaz',
    isDirty: false, needsIroning: false, isIroned: true,
    createdAt: DateTime.now(),
  ),
  ClothingItem(
    id: 2, userId: 1, category: 'Üst', season: 'kis',
    hue: 220, saturation: 45, lightness: 32, colorName: 'lacivert',
    isDirty: false, needsIroning: false, isIroned: true,
    createdAt: DateTime.now(),
  ),
  ClothingItem(
    id: 3, userId: 1, category: 'Alt', season: 'tum',
    hue: 220, saturation: 40, lightness: 58, colorName: 'mavi',
    isDirty: false, needsIroning: false, isIroned: true,
    createdAt: DateTime.now(),
  ),
  ClothingItem(
    id: 4, userId: 1, category: 'Alt', season: 'tum',
    hue: 60, saturation: 25, lightness: 45, colorName: 'haki',
    isDirty: false, needsIroning: false, isIroned: true,
    createdAt: DateTime.now(),
  ),
  ClothingItem(
    id: 5, userId: 1, category: 'Elbise', season: 'tum',
    hue: 240, saturation: 10, lightness: 18, colorName: 'siyah',
    isDirty: false, needsIroning: false, isIroned: true,
    createdAt: DateTime.now(),
  ),
  ClothingItem(
    id: 6, userId: 1, category: 'Dış giyim', season: 'ilkbahar',
    hue: 35, saturation: 35, lightness: 70, colorName: 'bej',
    isDirty: false, needsIroning: false, isIroned: true,
    createdAt: DateTime.now(),
  ),
  ClothingItem(
    id: 7, userId: 1, category: 'Ayakkabı', season: 'tum',
    hue: 0, saturation: 0, lightness: 95, colorName: 'beyaz',
    isDirty: false, needsIroning: false, isIroned: true,
    createdAt: DateTime.now(),
  ),
  ClothingItem(
    id: 8, userId: 1, category: 'Aksesuar', season: 'tum',
    hue: 25, saturation: 50, lightness: 32, colorName: 'kahverengi',
    isDirty: false, needsIroning: false, isIroned: true,
    createdAt: DateTime.now(),
  ),
];