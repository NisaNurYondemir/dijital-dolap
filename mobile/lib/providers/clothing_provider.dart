import 'package:flutter/material.dart';
import 'package:dijital_dolap/data/api_client.dart';
import 'package:dijital_dolap/data/clothing_repository.dart';
import 'package:dijital_dolap/models/clothing_item.dart';
import 'package:dijital_dolap/models/analysis_result.dart';

class ClothingProvider extends ChangeNotifier {
  final _repo = ClothingRepository();

  List<ClothingItem> _items = [];
  bool _loading = false;
  String? _error;

  List<ClothingItem> get items => _items;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadAll() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _items = await _repo.getAll();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Bağlantı hatası: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => loadAll();

  /// Çıkışta çağrılır: önceki hesabın verisi bellekte kalmasın.
  void clear() {
    _items = [];
    _error = null;
    _loading = false;
    notifyListeners();
  }

  /// Yeni kıyafet ekle. Başarılıysa true döner.
  Future<bool> createItem(Map<String, dynamic> data) async {
    _error = null;
    notifyListeners();
    try {
      final created = await _repo.create(data);
      _items = [..._items, created];
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
    }
  }

  /// Fotoğrafı kayıt açmadan analiz et. Başarısızsa null döner.
  Future<AnalysisResult?> analyzeImage(List<int> bytes, String filename) async {
    _error = null;
    notifyListeners();
    try {
      return await _repo.analyze(bytes, filename);
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _error = 'Bağlantı hatası: $e';
      notifyListeners();
      return null;
    }
  }

  /// Analiz sonucunu (kullanıcının düzelttiği değerlerle) tek POST ile kaydet.
  Future<ClothingItem?> createFromAnalysis({
    required AnalysisResult analysis,
    required String category,
    required String season,
    String? colorName,
    bool isDirty = false,
    bool needsIroning = false,
    bool isIroned = false,
  }) async {
    _error = null;
    notifyListeners();
    try {
      final item = await _repo.create({
        'category': category,
        'season': season,
        'color_name': colorName,
        'hue': analysis.hue,
        'saturation': analysis.saturation,
        'lightness': analysis.lightness,
        'is_dirty': isDirty,
        'needs_ironing': needsIroning,
        'is_ironed': isIroned,
        'temp_image': analysis.tempImage,
      });
      _items = [..._items, item];
      notifyListeners();
      return item;
    } on ApiException catch (e) {
      _error = e.statusCode == 410
          ? 'Fotoğrafın süresi doldu, lütfen tekrar seç.'
          : e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _error = 'Bağlantı hatası: $e';
      notifyListeners();
      return null;
    }
  }

  /// Var olan kıyafetin bilgilerini güncelle (PATCH). Başarısızsa null döner.
  Future<ClothingItem?> updateItem(int id, Map<String, dynamic> data) async {
    _error = null;
    notifyListeners();
    try {
      final updated = await _repo.update(id, data);
      _items = [for (final i in _items) i.id == id ? updated : i];
      notifyListeners();
      return updated;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _error = 'Bağlantı hatası: $e';
      notifyListeners();
      return null;
    }
  }

  /// Kıyafeti sil. Başarılıysa true döner.
  Future<bool> deleteItem(int id) async {
    _error = null;
    notifyListeners();
    try {
      await _repo.delete(id);
      _items = _items.where((i) => i.id != id).toList();
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
    }
  }
}