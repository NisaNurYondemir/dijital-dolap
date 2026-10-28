import 'package:flutter/material.dart';
import 'package:dijital_dolap/data/calendar_repository.dart';
import 'package:dijital_dolap/models/calendar.dart';

/// Takvim olayları: liste + yaklaşan olay hazırlık uyarıları.
class CalendarProvider extends ChangeNotifier {
  final _repo = CalendarRepository();

  List<CalendarEvent> _events = [];
  List<EventInsight> _insights = [];
  bool _loading = false;
  bool _insightsLoading = false;
  String? _error;
  String? _mutationError;

  List<CalendarEvent> get events => _events;
  List<EventInsight> get insights => _insights;
  bool get loading => _loading;
  bool get insightsLoading => _insightsLoading;
  String? get error => _error;
  String? get mutationError => _mutationError;

  /// Hazırlanmamış yaklaşan olaylar (ana ekran uyarısı için).
  List<EventInsight> get pendingInsights =>
      _insights.where((i) => !i.ready).toList();

  Future<void> loadAll() async {
    final eventsFuture = _loadEvents();
    await Future.wait([eventsFuture, loadInsights()]);
  }

  Future<void> _loadEvents() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _events = await _repo.getAll();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadInsights() async {
    _insightsLoading = true;
    notifyListeners();
    try {
      _insights = await _repo.getInsights();
    } catch (_) {
      // Uyarılar opsiyonel: hata ana akışı bozmasın. Eskisini koruyoruz.
    } finally {
      _insightsLoading = false;
      notifyListeners();
    }
  }

  Future<bool> create(CalendarEvent event) async {
    try {
      final created = await _repo.create(event);
      _events = [..._events, created]..sort(
          (a, b) => a.eventDate.compareTo(b.eventDate),
        );
      _mutationError = null;
      notifyListeners();
      loadInsights();
      return true;
    } catch (e) {
      _mutationError = _friendly(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> update(CalendarEvent event) async {
    try {
      final updated = await _repo.update(event);
      final i = _events.indexWhere((e) => e.id == updated.id);
      if (i != -1) {
        _events[i] = updated;
        _events.sort((a, b) => a.eventDate.compareTo(b.eventDate));
      }
      _mutationError = null;
      notifyListeners();
      loadInsights();
      return true;
    } catch (e) {
      _mutationError = _friendly(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> delete(int id) async {
    try {
      await _repo.delete(id);
      _events.removeWhere((e) => e.id == id);
      _mutationError = null;
      notifyListeners();
      loadInsights();
    } catch (e) {
      _mutationError = _friendly(e);
      notifyListeners();
    }
  }

  String _friendly(Object e) {
    final text = e.toString();
    if (text.contains('ApiException(400')) return 'Kayıt geçersiz';
    if (text.contains('possibly')) return 'Kayıt geçersiz';
    return 'Olay kaydedilemedi';
  }

  void clear() {
    _events = [];
    _insights = [];
    _loading = false;
    _insightsLoading = false;
    _error = null;
    _mutationError = null;
    notifyListeners();
  }
}
