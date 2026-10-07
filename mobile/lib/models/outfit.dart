import 'package:dijital_dolap/models/clothing_item.dart';

class Outfit {
  final int? id;
  final int? userId;
  final bool isFavorite;
  final List<ClothingItem> clothes;
  final DateTime? createdAt;
  final double? score;

  Outfit({
    this.id,
    this.userId,
    this.isFavorite = false,
    required this.clothes,
    this.createdAt,
    this.score,
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
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      score: (json['score'] as num?)?.toDouble(),
    );
  }

  /// Öneri yanıtı (GET /outfits/suggest)
  factory Outfit.fromSuggestion(Map<String, dynamic> json) {
    return Outfit(
      clothes: (json['clothes'] as List<dynamic>)
          .map((e) => ClothingItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      score: (json['score'] as num?)?.toDouble(),
    );
  }

  String get displayName => id != null ? 'Kombin #$id' : 'Öneri';

  String get scoreLabel {
    if (score == null) return '';
    if (score! >= 0.85) return '★ Mükemmel uyum';
    if (score! >= 0.75) return '★ İyi uyum';
    return '★ Kabul edilebilir';
  }
}