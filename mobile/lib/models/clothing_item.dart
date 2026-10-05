import 'package:flutter/material.dart';

enum ClothingCategory {
  top('Üst', Icons.checkroom),
  bottom('Alt', Icons.dry_cleaning),
  dress('Elbise', Icons.woman),
  outerwear('Dış giyim', Icons.layers),
  shoes('Ayakkabı', Icons.directions_walk),
  accessory('Aksesuar', Icons.watch);

  const ClothingCategory(this.label, this.icon);
  final String label;
  final IconData icon;

  // Backend'den gelen string'i enum'a çevir
  static ClothingCategory? fromString(String? value) {
    if (value == null) return null;
    // Türkçe karakter + büyük/küçük harf toleransı
    final v = value.toLowerCase().trim();
    for (final c in ClothingCategory.values) {
      if (c.label.toLowerCase() == v) return c;
    }
    return null;
  }
}

class ClothingItem {
  final int id;                    // backend int
  final int userId;
  final String category;           // backend string (ör. "tshirt", "pantolon")
  final String season;             // "yaz", "kis", "ilkbahar", "sonbahar", "tum"
  final double? hue;               // 0-360
  final double? saturation;        // 0-100
  final double? lightness;         // 0-100
  final String? colorName;
  final bool isDirty;
  final bool needsIroning;
  final bool isIroned;
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
    required this.isDirty,
    required this.needsIroning,
    required this.isIroned,
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
      isDirty: json['is_dirty'] as bool,
      needsIroning: json['needs_ironing'] as bool,
      isIroned: json['is_ironed'] as bool,
      imagePath: json['image_path'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Görsel URL'i (backend /uploads altında servis ediyor)
  String? imageUrlFor(String baseUrl) {
    if (imagePath == null) return null;
    // image_path "uploads/xxx.png" formatında
    return '$baseUrl/$imagePath';
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