import 'package:dijital_dolap/models/clothing_item.dart';
import 'package:dijital_dolap/models/occasion_group.dart';

class Outfit {
  final int? id;
  final int? userId;
  final bool isFavorite;
  final String? name;
  final String? description;
  final List<ClothingItem> clothes;
  final List<OccasionGroup> groups;
  final DateTime? createdAt;
  final double? score;
  final double? colorScore;
  final double? patternScore;
  final double? occasionScore;
  final List<String> reasons;

  Outfit({
    this.id,
    this.userId,
    this.isFavorite = false,
    this.name,
    this.description,
    required this.clothes,
    this.groups = const [],
    this.createdAt,
    this.score,
    this.colorScore,
    this.patternScore,
    this.occasionScore,
    this.reasons = const [],
  });

  /// Kaydedilmiş kombin (GET /outfits/)
  factory Outfit.fromJson(Map<String, dynamic> json) {
    return Outfit(
      id: json['id'] as int?,
      userId: json['user_id'] as int?,
      isFavorite: json['is_favorite'] as bool? ?? false,
      name: json['name'] as String?,
      description: json['description'] as String?,
      clothes: (json['clothes'] as List<dynamic>)
          .map((e) => ClothingItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      groups: (json['groups'] as List<dynamic>? ?? [])
          .map((e) => OccasionGroup.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      score: (json['score'] as num?)?.toDouble(),
      colorScore: (json['color_score'] as num?)?.toDouble(),
      patternScore: (json['pattern_score'] as num?)?.toDouble(),
      occasionScore: (json['occasion_score'] as num?)?.toDouble(),
      reasons: (json['reasons'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  /// Öneri yanıtı (GET /outfits/suggest)
  factory Outfit.fromSuggestion(Map<String, dynamic> json) {
    return Outfit(
      clothes: (json['clothes'] as List<dynamic>)
          .map((e) => ClothingItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      score: (json['score'] as num?)?.toDouble(),
      colorScore: (json['color_score'] as num?)?.toDouble(),
      patternScore: (json['pattern_score'] as num?)?.toDouble(),
      occasionScore: (json['occasion_score'] as num?)?.toDouble(),
      reasons: (json['reasons'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  /// Kaydedilmiş kombinin güncel hâliyle yeni bir kopya.
  Outfit copyWith({
    String? name,
    String? description,
    bool? isFavorite,
  }) {
    return Outfit(
      id: id,
      userId: userId,
      isFavorite: isFavorite ?? this.isFavorite,
      name: name ?? this.name,
      description: description ?? this.description,
      clothes: clothes,
      groups: groups,
      createdAt: createdAt,
      score: score,
      colorScore: colorScore,
      patternScore: patternScore,
      occasionScore: occasionScore,
      reasons: reasons,
    );
  }

  String get displayName => name?.isNotEmpty == true
      ? name!
      : (id != null ? 'Kombin #$id' : 'Öneri');

  double? get compatibilityScore => score ?? colorScore;

  int? get scorePercent {
    final value = compatibilityScore;
    return value == null ? null : (value * 100).round();
  }

  String get scoreBadgeLabel =>
      scorePercent == null ? '' : 'Uyum %$scorePercent';

  String get scoreLabel {
    final value = compatibilityScore;
    if (value == null) return '';
    if (value >= 0.85) return '★ Mükemmel uyum';
    if (value >= 0.70) return '★ İyi uyum';
    if (value >= 0.50) return '★ Kabul edilebilir';
    return '★ Uyumsuz';
  }

  String get scoreBreakdown {
    final parts = <String>[];
    if (colorScore != null) {
      parts.add('Renk %${(colorScore! * 100).round()}');
    }
    if (patternScore != null) {
      parts.add('Desen %${(patternScore! * 100).round()}');
    }
    if (occasionScore != null && occasionScore! < 0.999) {
      parts.add('Etkinlik %${(occasionScore! * 100).round()}');
    }
    return parts.join(' · ');
  }
}