/// Bir kategorinin otomatik kirli kuralı.
class LaundryRule {
  final String category;
  final bool enabled;
  final int? wearLimit;

  const LaundryRule({
    required this.category,
    required this.enabled,
    required this.wearLimit,
  });

  factory LaundryRule.fromJson(String category, Map<String, dynamic> json) {
    return LaundryRule(
      category: category,
      enabled: json['enabled'] == true,
      wearLimit: json['wear_limit'] is int ? json['wear_limit'] as int : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'wear_limit': wearLimit,
      };

  LaundryRule copyWith({bool? enabled, int? wearLimit}) => LaundryRule(
        category: category,
        enabled: enabled ?? this.enabled,
        wearLimit: wearLimit ?? this.wearLimit,
      );
}

/// Kategori bazlı çamaşır ayarları (backend varsayılanları dahil).
class LaundrySettings {
  final List<LaundryRule> rules;

  const LaundrySettings({required this.rules});

  static LaundrySettings fromJson(Map<String, dynamic> json) {
    final raw = (json['rules'] as Map<String, dynamic>? ?? {});
    final rules = raw.entries
        .map((e) => LaundryRule.fromJson(e.key, e.value as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.category.compareTo(b.category));
    return LaundrySettings(rules: rules);
  }
}
