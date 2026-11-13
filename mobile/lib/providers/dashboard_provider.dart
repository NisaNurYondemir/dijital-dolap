import 'package:flutter/material.dart';
import 'package:dijital_dolap/data/dashboard_repository.dart';
import 'package:dijital_dolap/models/dashboard.dart';

/// Dolap özeti (dashboard): yükleme + hata ayrı, liste akışını bozmaz.
class DashboardProvider extends ChangeNotifier {
  final _repo = DashboardRepository();

  WardrobeDashboard? _data;
  bool _loading = false;
  String? _error;

  WardrobeDashboard? get data => _data;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _data = await _repo.get();
      _error = null;
    } catch (_) {
      _data = null;
      _error = 'Dolap özeti yüklenemedi';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clear() {
    _data = null;
    _error = null;
    _loading = false;
    notifyListeners();
  }
}
