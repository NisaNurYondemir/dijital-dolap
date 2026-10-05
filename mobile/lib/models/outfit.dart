import 'package:dijital_dolap/models/clothing_item.dart';

class Outfit {
  final int id;
  final int userId;
  final bool isFavorite;
  final List<ClothingItem> clothes;
  final DateTime createdAt;

  Outfit({
    required this.id,
    required this.userId,
    required this.isFavorite,
    required this.clothes,
    required this.createdAt,
  });

  factory Outfit.fromJson(Map<String, dynamic> json) {
    return Outfit(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      isFavorite: json['is_favorite'] as bool,
      clothes: (json['clothes'] as List<dynamic>)
          .map((e) => ClothingItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get displayName => 'Kombin #$id';
}