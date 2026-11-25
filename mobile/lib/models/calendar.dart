class CalendarEvent {
  final int? id;
  final String title;
  final String kind;
  final DateTime eventDate;
  final int? occasionGroupId;
  final String? note;

  CalendarEvent({
    this.id,
    required this.title,
    required this.kind,
    required this.eventDate,
    this.occasionGroupId,
    this.note,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as int?,
      title: json['title']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'genel',
      eventDate: DateTime.parse(json['event_date'] as String),
      occasionGroupId: json['occasion_group_id'] as int?,
      note: json['note']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'kind': kind,
      'event_date': eventDate.toUtc().toIso8601String(),
      'occasion_group_id': occasionGroupId,
      if (note != null) 'note': note,
    };
  }
}

class EventInsight {
  final int eventId;
  final String title;
  final String kind;
  final int daysLeft;
  final bool ready;
  final String message;

  const EventInsight({
    required this.eventId,
    required this.title,
    required this.kind,
    required this.daysLeft,
    required this.ready,
    required this.message,
  });

  factory EventInsight.fromJson(Map<String, dynamic> json) {
    return EventInsight(
      eventId: json['event_id'] as int? ?? 0,
      title: json['title']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'genel',
      daysLeft: json['days_left'] as int? ?? 0,
      ready: json['ready'] as bool? ?? false,
      message: json['message']?.toString() ?? '',
    );
  }
}
