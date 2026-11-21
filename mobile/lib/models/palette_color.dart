import 'package:flutter/material.dart';

/// Bir kıyafetin paletindeki tek renk: HSL + görseldeki alan oranı.
///
/// Backend `palette` alanı: `[{name, hue, saturation, lightness, ratio}, ...]`
/// İlk eleman baskın renktir.
class PaletteEntry {
  final String? name;
  final double hue; // 0-360
  final double saturation; // 0-100
  final double lightness; // 0-100
  final double ratio; // 0-1

  const PaletteEntry({
    this.name,
    required this.hue,
    required this.saturation,
    required this.lightness,
    required this.ratio,
  });

  factory PaletteEntry.fromJson(Map<String, dynamic> json) {
    return PaletteEntry(
      name: json['name'] as String?,
      hue: (json['hue'] as num?)?.toDouble() ?? 0,
      saturation: (json['saturation'] as num?)?.toDouble() ?? 0,
      lightness: (json['lightness'] as num?)?.toDouble() ?? 0,
      ratio: (json['ratio'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Oranı yüzdeye çevirir (ör. 0.52 -> %52).
  int get percent => (ratio * 100).round();

  Color get color => HSLColor.fromAHSL(
        1.0,
        hue.clamp(0, 360).toDouble(),
        (saturation / 100).clamp(0, 1).toDouble(),
        (lightness / 100).clamp(0, 1).toDouble(),
      ).toColor();
}

/// JSON listesini güvenli biçimde palet girdilerine çevirir.
List<PaletteEntry> parsePalette(dynamic raw) {
  if (raw is! List) return const [];
  final entries = <PaletteEntry>[];
  for (final item in raw) {
    if (item is Map) {
      entries.add(PaletteEntry.fromJson(Map<String, dynamic>.from(item)));
    }
  }
  return entries;
}
