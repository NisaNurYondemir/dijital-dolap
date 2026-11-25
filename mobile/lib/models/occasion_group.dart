import 'package:flutter/material.dart';

/// Öneri motorunun anladığı etkinlik tipleri.
const occasionTypeLabels = <String, String>{
  'formal': 'Resmi / Özel gün',
  'work': 'İş / Ofis',
  'sport': 'Spor',
  'casual': 'Günlük',
  'romantic': 'Romantik',
};

String _fold(String value) {
  return value
      .replaceAll('İ', 'i')
      .replaceAll('I', 'i')
      .replaceAll('ı', 'i')
      .replaceAll('Ş', 's')
      .replaceAll('ş', 's')
      .replaceAll('Ğ', 'g')
      .replaceAll('ğ', 'g')
      .replaceAll('Ü', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('Ö', 'o')
      .replaceAll('ö', 'o')
      .replaceAll('Ç', 'c')
      .replaceAll('ç', 'c')
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\-_]'), '');
}

/// Grup adından etkinlik tipi çıkarır; emin değilse günlük döner.
/// Backend'deki `occasion_types.infer_occasion_type` ile aynı mantık.
String inferOccasionType(String name) {
  final normalized = _fold(name);
  if (normalized.isEmpty) return 'casual';
  const exact = <String, String>{
    'is': 'work',
    'ofis': 'work',
    'isyeri': 'work',
    'staj': 'work',
    'mulakat': 'work',
    'kariyer': 'work',
  };
  final exactType = exact[normalized];
  if (exactType != null) return exactType;
  const formal = [
    'dugun', 'nisan', 'kina', 'nikah', 'mezuniyet', 'ozelgun',
    'abiye', 'gala', 'davet', 'balo', 'sunnet', 'kokteyl',
  ];
  if (formal.any(normalized.contains)) return 'formal';
  const sport = [
    'spor', 'antrenman', 'kosu', 'yoga', 'fitness', 'tenis',
    'yuzme', 'gym', 'workout', 'pilates', 'bisiklet',
  ];
  if (sport.any(normalized.contains)) return 'sport';
  const romantic = ['romantik', 'randevu', 'date', 'sevgili'];
  if (romantic.any(normalized.contains)) return 'romantic';
  return 'casual';
}

/// Kullanıcının kombinlerini grupladığı amaç/ortam etiketi.
class OccasionGroup {
  final int id;
  final String name;
  final String? emoji;
  final String? colorHex;
  final String occasionType;
  final bool isDefault;

  const OccasionGroup({
    required this.id,
    required this.name,
    this.emoji,
    this.colorHex,
    this.occasionType = 'casual',
    this.isDefault = false,
  });

  factory OccasionGroup.fromJson(Map<String, dynamic> json) {
    return OccasionGroup(
      id: json['id'] as int,
      name: json['name'] as String,
      emoji: json['emoji'] as String?,
      colorHex: json['color'] as String?,
      occasionType: json['occasion_type']?.toString() ?? 'casual',
      isDefault: json['is_default'] as bool? ?? false,
    );
  }

  String get label {
    final value = emoji?.trim() ?? '';
    return value.isEmpty ? name : '$value $name';
  }

  String get typeLabel => occasionTypeLabels[occasionType] ?? occasionType;

  Color get color {
    final hex = colorHex?.replaceFirst('#', '');
    if (hex == null || hex.length != 6) {
      return const Color(0xFFF2B84B);
    }
    final value = int.tryParse(hex, radix: 16);
    if (value == null) {
      return const Color(0xFFF2B84B);
    }
    return Color(0xFF000000 | value);
  }
}
