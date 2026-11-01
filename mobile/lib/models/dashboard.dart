class DashboardTotals {
  final int items;
  final int wearable;
  final int dirty;
  final int ironing;
  final int wearTotal;

  const DashboardTotals({
    required this.items,
    required this.wearable,
    required this.dirty,
    required this.ironing,
    required this.wearTotal,
  });

  factory DashboardTotals.fromJson(Map<String, dynamic> json) {
    return DashboardTotals(
      items: json['items'] as int? ?? 0,
      wearable: json['wearable'] as int? ?? 0,
      dirty: json['dirty'] as int? ?? 0,
      ironing: json['ironing'] as int? ?? 0,
      wearTotal: json['wear_total'] as int? ?? 0,
    );
  }
}

class SeasonCount {
  final String season;
  final int count;
  const SeasonCount({required this.season, required this.count});

  factory SeasonCount.fromJson(Map<String, dynamic> json) {
    return SeasonCount(
      season: json['season']?.toString() ?? '',
      count: json['count'] as int? ?? 0,
    );
  }
}

class CategoryCount {
  final String category;
  final int count;
  final int wears;
  const CategoryCount({required this.category, required this.count, required this.wears});

  factory CategoryCount.fromJson(Map<String, dynamic> json) {
    return CategoryCount(
      category: json['category']?.toString() ?? '',
      count: json['count'] as int? ?? 0,
      wears: json['wears'] as int? ?? 0,
    );
  }
}

class WornItem {
  final int id;
  final String category;
  final String? colorName;
  final int wearCount;
  final double? avgRating;
  final String? imagePath;

  const WornItem({
    required this.id,
    required this.category,
    this.colorName,
    required this.wearCount,
    this.avgRating,
    this.imagePath,
  });

  factory WornItem.fromJson(Map<String, dynamic> json) {
    return WornItem(
      id: json['id'] as int? ?? 0,
      category: json['category']?.toString() ?? '',
      colorName: json['color_name']?.toString(),
      wearCount: json['wear_count'] as int? ?? 0,
      avgRating: (json['avg_rating'] as num?)?.toDouble(),
      imagePath: json['image_path']?.toString(),
    );
  }
}

class NeverWornItem {
  final int id;
  final String category;
  final String? colorName;
  final int? daysInWardrobe;
  final bool dirtyOrIroning;
  final String? imagePath;

  const NeverWornItem({
    required this.id,
    required this.category,
    this.colorName,
    this.daysInWardrobe,
    required this.dirtyOrIroning,
    this.imagePath,
  });

  factory NeverWornItem.fromJson(Map<String, dynamic> json) {
    return NeverWornItem(
      id: json['id'] as int? ?? 0,
      category: json['category']?.toString() ?? '',
      colorName: json['color_name']?.toString(),
      daysInWardrobe: json['days_in_wardrobe'] as int?,
      dirtyOrIroning: json['dirty_or_ironing'] as bool? ?? false,
      imagePath: json['image_path']?.toString(),
    );
  }
}

class OccasionUsage {
  final String name;
  final String? emoji;
  final int wears;
  final double? avgRating;
  const OccasionUsage({required this.name, this.emoji, required this.wears, this.avgRating});

  factory OccasionUsage.fromJson(Map<String, dynamic> json) {
    return OccasionUsage(
      name: json['name']?.toString() ?? '',
      emoji: json['emoji']?.toString(),
      wears: json['wears'] as int? ?? 0,
      avgRating: (json['avg_rating'] as num?)?.toDouble(),
    );
  }
}

class WardrobeDashboard {
  final DashboardTotals totals;
  final List<SeasonCount> bySeason;
  final List<CategoryCount> byCategory;
  final List<WornItem> topWorn;
  final List<NeverWornItem> neverWorn;
  final List<OccasionUsage> occasionUsage;
  final List<String> insightLines;

  const WardrobeDashboard({
    required this.totals,
    required this.bySeason,
    required this.byCategory,
    required this.topWorn,
    required this.neverWorn,
    required this.occasionUsage,
    required this.insightLines,
  });

  factory WardrobeDashboard.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> maps(dynamic v) =>
        (v as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
    return WardrobeDashboard(
      totals: DashboardTotals.fromJson(
          json['totals'] as Map<String, dynamic>? ?? {}),
      bySeason: maps(json['by_season']).map(SeasonCount.fromJson).toList(),
      byCategory: maps(json['by_category']).map(CategoryCount.fromJson).toList(),
      topWorn: maps(json['top_worn']).map(WornItem.fromJson).toList(),
      neverWorn: maps(json['never_worn']).map(NeverWornItem.fromJson).toList(),
      occasionUsage: maps(json['occasion_usage']).map(OccasionUsage.fromJson).toList(),
      insightLines:
          (json['insight_lines'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
