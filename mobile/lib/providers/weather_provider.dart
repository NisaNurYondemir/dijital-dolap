import 'package:flutter/material.dart';
import 'package:dijital_dolap/data/weather_repository.dart';
import 'package:dijital_dolap/models/weather.dart';

/// Hariça şehir seçimini ve günlük hava bilgisini tutar.
/// Kullanıcı şehir seçtiğinden Öneriler sekmesi hava uyarınca öneri ister.
class WeatherProvider extends ChangeNotifier {
  final _repo = WeatherRepository();

  CitySuggestion? _city;
  WeatherInfo? _weather;
  bool _loading = false;
  String? _error;

  CitySuggestion? get city => _city;
  WeatherInfo? get weather => _weather;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> select(CitySuggestion city) async {
    _city = city;
    _weather = null;
    _error = null;
    _loading = true;
    notifyListeners();
    try {
      _weather = await _repo.getCurrent(
        latitude: city.latitude,
        longitude: city.longitude,
        city: city.name,
      );
      _error = null;
    } catch (_) {
      _weather = null;
      _error = 'Hava bilgisi alınamadı';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Öneriler hava olmadan yenilenir.
  void clearCity() {
    _city = null;
    _weather = null;
    _error = null;
    notifyListeners();
  }
}
