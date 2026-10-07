import 'package:flutter/material.dart';

/// CLIP'in önerdiği tek bir kategori adayı.
class CategoryCandidate {
  final String category;
  final double probability; // backend 0-1 ya da 0-100 gönderebilir

  const CategoryCandidate({required this.category, required this.probability});

  factory CategoryCandidate.fromJson(dynamic json) {
    if (json is Map) {
      final cat = json['category'] ?? json['label'] ?? json['name'] ?? '';
      final prob = json['probability'] ?? json['prob'] ?? json['score'] ?? 0;
      return CategoryCandidate(
        category: cat.toString(),
        probability: (prob as num).toDouble(),
      );
    }
    if (json is List && json.length >= 2) {
      return CategoryCandidate(
        category: json[0].toString(),
        probability: (json[1] as num).toDouble(),
      );
    }
    return const CategoryCandidate(category: '', probability: 0);
  }

  /// "%91,8" gibi gösterim için yüzde değeri
  double get percent => probability <= 1 ? probability * 100 : probability;
}

/// POST /clothes/analyze yanıtı (kayıt açmadan yapılan analiz).
class AnalysisResult {
  final String tempImage;
  final String previewPath;
  final String category;
  final List<CategoryCandidate> candidates;
  final String season;
  final double? hue;
  final double? saturation;
  final double? lightness;
  final String? colorName;

  const AnalysisResult({
    required this.tempImage,
    required this.previewPath,
    required this.category,
    required this.candidates,
    required this.season,
    this.hue,
    this.saturation,
    this.lightness,
    this.colorName,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    final rawCandidates = json['category_candidates'];
    return AnalysisResult(
      tempImage: json['temp_image'] as String,
      previewPath: json['preview_path'] as String,
      category: json['category'] as String,
      candidates: rawCandidates is List
          ? rawCandidates.map(CategoryCandidate.fromJson).toList()
          : const [],
      season: json['season'] as String,
      hue: (json['hue'] as num?)?.toDouble(),
      saturation: (json['saturation'] as num?)?.toDouble(),
      lightness: (json['lightness'] as num?)?.toDouble(),
      colorName: json['color_name'] as String?,
    );
  }

  /// Önizleme görselinin tam adresi
  String previewUrlFor(String baseUrl) {
    final p = previewPath.startsWith('/') ? previewPath.substring(1) : previewPath;
    return '$baseUrl/$p';
  }

  Color? get color {
    if (hue == null || saturation == null || lightness == null) return null;
    return HSLColor.fromAHSL(
      1.0,
      hue!.clamp(0, 360).toDouble(),
      (saturation! / 100).clamp(0, 1).toDouble(),
      (lightness! / 100).clamp(0, 1).toDouble(),
    ).toColor();
  }
}