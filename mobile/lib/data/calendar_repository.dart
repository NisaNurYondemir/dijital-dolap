import 'package:dijital_dolap/data/api_client.dart';
import 'package:dijital_dolap/models/calendar.dart';

class CalendarRepository {
  final _api = ApiClient.instance;

  Future<List<CalendarEvent>> getAll() async {
    final res = await _api.get('/events/');
    if (res is! List) return [];
    return res
        .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<EventInsight>> getInsights([int windowDays = 30]) async {
    final res = await _api.get('/events/insights?window_days=$windowDays');
    if (res is! List) return [];
    return res
        .map((e) => EventInsight.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CalendarEvent> create(CalendarEvent event) async {
    final res = await _api.post('/events/', body: event.toJson());
    return CalendarEvent.fromJson(res as Map<String, dynamic>);
  }

  Future<CalendarEvent> update(CalendarEvent event) async {
    final res = await _api.patch(
      '/events/${event.id}',
      event.toJson(),
    );
    return CalendarEvent.fromJson(res as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _api.delete('/events/$id');
  }
}
