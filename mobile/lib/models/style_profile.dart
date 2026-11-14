/// Kullanicinin giyim gecmisinden ogrenilen tarz profili
/// (GET /insights/style).
class StyleCategory {
  final String name;
  final int count;
  final double share;

  const StyleCategory({
    required this.name,
    required this.count,
    required this.share,
  });

  factory StyleCategory.fromJson(Map<String, dynamic> json) {
    return StyleCategory(
      name: json['name']?.toString() ?? '',
      count: json['count'] as int? ?? 0,
      share: (json['share'] as num?)?.toDouble() ?? 0,
    );
  }
}

class StyleBucket {
  final String bucket;
  final String label;
  final int count;
  final double share;

  const StyleBucket({
    required this.bucket,
    required this.label,
    required this.count,
    required this.share,
  });

  factory StyleBucket.fromJson(Map<String, dynamic> json) {
    return StyleBucket(
      bucket: json['bucket']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      count: json['count'] as int? ?? 0,
      share: (json['share'] as num?)?.toDouble() ?? 0,
    );
  }
}

class SignaturePair {
  final String top;
  final String alt;
  final int count;

  const SignaturePair({
    required this.top,
    required this.alt,
    required this.count,
  });

  factory SignaturePair.fromJson(Map<String, dynamic> json) {
    return SignaturePair(
      top: json['top']?.toString() ?? '',
      alt: json['alt']?.toString() ?? '',
      count: json['count'] as int? ?? 0,
    );
  }
}

class StyleProfile {
  final int wearTotal;
  final int confidence; // 0-3: profil ne kadar taniniyor
  final List<StyleCategory> topCategories;
  final List<StyleBucket> hueBuckets;
  final double neutralShare;
  final double? contrast;
  final SignaturePair? signaturePair;
  final List<String> summary;

  const StyleProfile({
    required this.wearTotal,
    required this.confidence,
    required this.topCategories,
    required this.hueBuckets,
    required this.neutralShare,
    required this.contrast,
    required this.signaturePair,
    required this.summary,
  });

  factory StyleProfile.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> maps(dynamic v) =>
        (v as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
    final sig = json['signature_pair'];
    return StyleProfile(
      wearTotal: json['wear_total'] as int? ?? 0,
      confidence: json['confidence'] as int? ?? 0,
      topCategories: maps(json['top_categories']).map(StyleCategory.fromJson).toList(),
      hueBuckets: maps(json['hue_buckets']).map(StyleBucket.fromJson).toList(),
      neutralShare: (json['neutral_share'] as num?)?.toDouble() ?? 0,
      contrast: (json['contrast'] as num?)?.toDouble(),
      signaturePair: sig == null ? null : SignaturePair.fromJson(sig),
      summary: (json['summary'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  /// Tarzin ogrenilme asamasi (0: yetersiz veri, 3: net).
  String get confidenceLabel {
    switch (confidence) {
      case 3:
        return 'Tarzın netleşti';
      case 2:
        return 'Tarzın şekilleniyor';
      case 1:
        return 'Tarzın öğreniliyor';
      default:
        return 'Tarzın öğrenilmeye başlandı';
    }
  }
}
