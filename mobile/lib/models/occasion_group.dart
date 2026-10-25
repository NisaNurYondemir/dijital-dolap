import 'package:flutter/material.dart';

/// Kullanıcının kombinlerini grupladığı amaç/ortam etiketi.
class OccasionGroup {
  final int id;
  final String name;
  final String? emoji;
  final String? colorHex;
  final bool isDefault;

  const OccasionGroup({
    required this.id,
    required this.name,
    this.emoji,
    this.colorHex,
    this.isDefault = false,
  });

  factory OccasionGroup.fromJson(Map<String, dynamic> json) {
    return OccasionGroup(
      id: json['id'] as int,
      name: json['name'] as String,
      emoji: json['emoji'] as String?,
      colorHex: json['color'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
    );
  }

  String get label {
    final value = emoji?.trim() ?? '';
    return value.isEmpty ? name : '$value $name';
  }

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
