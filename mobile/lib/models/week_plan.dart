class PlanItem {
  final int id;
  final String category;
  final String? colorName;
  final String? imagePath;

  const PlanItem({
    required this.id,
    required this.category,
    this.colorName,
    this.imagePath,
  });

  factory PlanItem.fromJson(Map<String, dynamic> json) {
    return PlanItem(
      id: json['id'] as int? ?? 0,
      category: json['category']?.toString() ?? '',
      colorName: json['color_name']?.toString(),
      imagePath: json['image_path']?.toString(),
    );
  }
}

class WeekPlan {
  final int eventId;
  final String title;
  final String kind;
  final int daysLeft;
  final String? weatherHeadline;
  final bool needsOuterwear;
  final List<int> itemIds;
  final String message;

  const WeekPlan({
    required this.eventId,
    required this.title,
    required this.kind,
    required this.daysLeft,
    this.weatherHeadline,
    required this.needsOuterwear,
    required this.itemIds,
    required this.message,
  });

  factory WeekPlan.fromJson(Map<String, dynamic> json) {
    return WeekPlan(
      eventId: json['event_id'] as int? ?? 0,
      title: json['title']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'genel',
      daysLeft: json['days_left'] as int? ?? 0,
      weatherHeadline: json['weather_headline']?.toString(),
      needsOuterwear: json['needs_outerwear'] as bool? ?? false,
      itemIds: (json['item_ids'] as List?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      message: json['message']?.toString() ?? '',
    );
  }
}

class WeekPlanResult {
  final List<WeekPlan> plans;
  final List<PlanItem> items;

  const WeekPlanResult({required this.plans, required this.items});

  factory WeekPlanResult.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> maps(dynamic v) =>
        (v as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
    return WeekPlanResult(
      plans: maps(json['plans']).map(WeekPlan.fromJson).toList(),
      items: maps(json['items']).map(PlanItem.fromJson).toList(),
    );
  }

  PlanItem? item(int id) {
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }
}
