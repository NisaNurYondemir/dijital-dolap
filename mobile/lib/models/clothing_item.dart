import 'package:flutter/material.dart';

import 'palette_color.dart';

class ClothingItem {
  final int id;                    // backend int
  final int userId;
  final String category;           // backend string (ör. "tshirt", "pantolon")
  final String season;             // "yaz", "kis", "ilkbahar", "sonbahar", "tum"
  final double? hue;               // 0-360
  final double? saturation;        // 0-100
  final double? lightness;         // 0-100
  final String? colorName;
  final List<PaletteEntry> palette;
  final String? pattern; // duz/cizgili/ekose/...
  final String? patternScale; // ince/orta/iri/bilinmiyor
  final double? patternConfidence;
  final String? patternSource; // zero_shot/probe/manual
  final bool isDirty;
  final bool needsIroning;
  final bool isIroned;
  final int wearCountSinceWash; // son yıkamadan beri giyilme sayısı
  final String? imagePath;         // "uploads/xxx.png"
  final DateTime createdAt;

  const ClothingItem({
    required this.id,
    required this.userId,
    required this.category,
    required this.season,
    this.hue,
    this.saturation,
    this.lightness,
    this.colorName,
    this.palette = const [],
    this.pattern,
    this.patternScale,
    this.patternConfidence,
    this.patternSource,
    required this.isDirty,
    required this.needsIroning,
    required this.isIroned,
    this.wearCountSinceWash = 0,
    this.imagePath,
    required this.createdAt,
  });

  /// Backend'den gelen JSON'u modele çevir
  factory ClothingItem.fromJson(Map<String, dynamic> json) {
    return ClothingItem(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      category: json['category'] as String,
      season: json['season'] as String,
      hue: (json['hue'] as num?)?.toDouble(),
      saturation: (json['saturation'] as num?)?.toDouble(),
      lightness: (json['lightness'] as num?)?.toDouble(),
      colorName: json['color_name'] as String?,
      palette: parsePalette(json['palette']),
      pattern: json['pattern'] as String?,
      patternScale: json['pattern_scale'] as String?,
      patternConfidence: (json['pattern_confidence'] as num?)?.toDouble(),
      patternSource: json['pattern_source'] as String?,
      isDirty: json['is_dirty'] as bool,
      needsIroning: json['needs_ironing'] as bool,
      isIroned: json['is_ironed'] as bool,
      wearCountSinceWash: json['wear_count_since_wash'] as int? ?? 0,
      imagePath: json['image_path'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Görsel URL'i (backend /uploads altında servis ediyor)
  String? imageUrlFor(String baseUrl) {
    if (imagePath == null) return null;
    final p = imagePath!.replaceAll('\\', '/');
    return '$baseUrl/${p.startsWith('/') ? p.substring(1) : p}';
  }

  /// HSL'den Flutter Color'a çevir (hue 0-360, s 0-100, l 0-100)
  Color? get color {
    if (hue == null || saturation == null || lightness == null) return null;
    return HSLColor.fromAHSL(
      1.0,
      hue!.clamp(0, 360),
      (saturation! / 100).clamp(0, 1),
      (lightness! / 100).clamp(0, 1),
    ).toColor();
  }

  bool get isWearable => !isDirty && (!needsIroning || isIroned);
}