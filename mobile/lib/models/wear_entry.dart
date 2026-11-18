import 'package:dijital_dolap/models/clothing_item.dart';

/// Bir giyim kaydı: kombin veya tek tek parçalar + puan/amaç/not.
class WearEntry {
  final int id;
  final int? outfitId;
  final DateTime? wornAt;
  final int? rating;
  /// Sıcaklık hissi: -2 çok üşüdüm ... 0 tam ayarında ... +2 çok sıcakladım.
  final int? comfort;
  final String? occasion;
  final int? occasionGroupId;
  final String? note;
  final double? weatherTemp;
  final String? weatherCondition;
  final List<ClothingItem> clothes;

  const WearEntry({
    required this.id,
    this.outfitId,
    this.wornAt,
    this.rating,
    this.comfort,
    this.occasion,
    this.occasionGroupId,
    this.note,
    this.weatherTemp,
    this.weatherCondition,
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
      comfort: json['comfort'] as int?,
      occasion: json['occasion'] as String?,
      occasionGroupId: json['occasion_group_id'] as int?,
      note: json['note'] as String?,
      weatherTemp: (json['weather_temp'] as num?)?.toDouble(),
      weatherCondition: json['weather_condition'] as String?,
      clothes: (json['clothes'] as List<dynamic>? ?? [])
          .map((e) => ClothingItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get hasRating => rating != null && rating! > 0;

  String get comfortLabel {
    switch (comfort) {
      case -2:
        return 'Çok üşüdüm';
      case -1:
        return 'Biraz üşüdüm';
      case 0:
        return 'Tam ayarında';
      case 1:
        return 'Biraz sıcakladım';
      case 2:
        return 'Çok sıcakladım';
      default:
        return '';
    }
  }

  /// Comfort ikonu için emoji: soğuk soldan, sıcak sağdan.
  String get comfortEmoji {
    switch (comfort) {
      case -2:
        return '🥶';
      case -1:
        return '❄️';
      case 0:
        return '👌';
      case 1:
        return '☀️';
      case 2:
        return '🥵';
      default:
        return '';
    }
  }
}
