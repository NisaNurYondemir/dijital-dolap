import 'package:dijital_dolap/models/clothing_item.dart';
import 'package:dijital_dolap/models/occasion_group.dart';

class Outfit {
  final int? id;
  final int? userId;
  final bool isFavorite;
  final List<ClothingItem> clothes;
  final List<OccasionGroup> groups;
  final DateTime? createdAt;
  final double? score;
  final double? colorScore;
  final List<String> reasons;

  Outfit({
    this.id,
    this.userId,
    this.isFavorite = false,
    required this.clothes,
    this.groups = const [],
    this.createdAt,
    this.score,
    this.colorScore,
    this.reasons = const [],
  });

  /// Kaydedilmiş kombin (GET /outfits/)
  factory Outfit.fromJson(Map<String, dynamic> json) {
    return Outfit(
      id: json['id'] as int?,
      userId: json['user_id'] as int?,
      isFavorite: json['is_favorite'] as bool? ?? false,
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
      reasons: (json['reasons'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  String get displayName => id != null ? 'Kombin #$id' : 'Öneri';

  String get scoreLabel {
    final value = colorScore ?? score;
    if (value == null) return '';
    if (value >= 0.85) return '★ Mükemmel uyum';
    if (value >= 0.75) return '★ İyi uyum';
    return '★ Kabul edilebilir';
  }
}