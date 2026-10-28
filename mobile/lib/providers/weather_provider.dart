import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:dijital_dolap/data/weather_repository.dart';
import 'package:dijital_dolap/models/weather.dart';

/// Hava durumu şehir seçimini ve günlük hava bilgisini tutar.
/// Kullanıcı şehir seçtiğinde öneriler sekmesi hava uyarınca öneri ister.
/// Cihazdan konum (GPS) de alınabilir: izin istenir, reddedilirse
/// şehir arama akışı çalışır.
class WeatherProvider extends ChangeNotifier {
  final _repo = WeatherRepository();

  CitySuggestion? _city;
  WeatherInfo? _weather;
  bool _loading = false;
  String? _error;
  bool _gpsBusy = false;

  CitySuggestion? get city => _city;
  WeatherInfo? get weather => _weather;
  bool get loading => _loading;
  String? get error => _error;
  bool get gpsBusy => _gpsBusy;

  /// Konumu cihazdan alır (izin ile) ve hava bilgisini yükler.
  /// İzin reddi/GPS kapalı/konum alınamadı -> hata set edilir.
  Future<void> useDeviceLocation() async {
    if (_gpsBusy) return;
    _gpsBusy = true;
    _error = null;
    notifyListeners();
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        _error = 'Cihazın konum servisi kapalı';
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _error = 'Konum izni reddedildi — şehri elle seçebilirsin';
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low, // şehir tespiti için yeterli
          timeLimit: Duration(seconds: 15),
        ),
      );
      CitySuggestion? resolved;
      try {
        resolved = await _repo.reverseGeocode(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      } catch (_) {
        // Şehir adı çözülemese de havayla devam et (etiketsiz).
      }
      _city = resolved;
      _weather = null;
      _loading = true;
      notifyListeners();
      try {
        _weather = await _repo.getCurrent(
          latitude: position.latitude,
          longitude: position.longitude,
          city: resolved?.name,
        );
        _error = null;
      } catch (_) {
        _weather = null;
        _error = 'Hava bilgisi alınamadı';
      } finally {
        _loading = false;
        notifyListeners();
      }
    } catch (_) {
      _error = 'Konuma ulaşılamadı — şehri elle seçebilirsin';
    } finally {
      _gpsBusy = false;
      notifyListeners();
    }
  }

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
