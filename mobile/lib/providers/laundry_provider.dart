import 'package:flutter/foundation.dart';
import 'package:dijital_dolap/data/api_client.dart';
import 'package:dijital_dolap/data/laundry_repository.dart';
import 'package:dijital_dolap/models/laundry.dart';

class LaundryProvider extends ChangeNotifier {
  final _repo = LaundryRepository();

  List<LaundryRule> _rules = [];
  bool _loading = false;
  bool _saving = false;
  String? _error;

  List<LaundryRule> get rules => _rules;
  bool get loading => _loading;
  bool get saving => _saving;
  String? get error => _error;

  LaundryRule? ruleFor(String category) {
    for (final r in _rules) {
      if (r.category == category) return r;
    }
    return null;
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _rules = (await _repo.fetchSettings()).rules;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Bağlantı hatası: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Tek kategori kuralını günceller ve kaydeder. Başarılıysa true döner.
  Future<bool> saveRule(LaundryRule rule) async {
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      _rules = (await _repo.saveRules({rule.category: rule})).rules;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Bağlantı hatası: $e';
      notifyListeners();
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// Çıkışta çağrılır: önceki hesabın ayarları bellekte kalmasın.
  void clear() {
    _rules = [];
    _error = null;
    _loading = false;
    _saving = false;
    notifyListeners();
  }
}
