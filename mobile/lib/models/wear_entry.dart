import 'package:dijital_dolap/models/clothing_item.dart';

/// Bir giyim kaydı: kombin veya tek tek parçalar + puan/amaç/not.
class WearEntry {
  final int id;
  final int? outfitId;
  final DateTime? wornAt;
  final int? rating;
  final String? occasion;
  final int? occasionGroupId;
  final String? note;
  final List<ClothingItem> clothes;

  const WearEntry({
    required this.id,
    this.outfitId,
    this.wornAt,
    this.rating,
    this.occasion,
    this.occasionGroupId,
    this.note,
    required this.clothes,
  });

  factory WearEntry.fromJson(Map<String, dynamic> json) {
    return WearEntry(
      id: json['id'] as int,
      outfitId: json['outfit_id'] as int?,
      wornAt: json['worn_at'] != null
          ? DateTime.parse(json['worn_at'] as String)
          : null,
      rating: json['rating'] as int?,
      occasion: json['occasion'] as String?,
      occasionGroupId: json['occasion_group_id'] as int?,
      note: json['note'] as String?,
      clothes: (json['clothes'] as List<dynamic>? ?? [])
          .map((e) => ClothingItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get hasRating => rating != null && rating! > 0;
}
