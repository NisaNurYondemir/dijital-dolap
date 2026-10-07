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
    /// Kıyafeti fotoğrafla birlikte oluştur.
  /// 1) POST /clothes (category: "unknown")
  /// 2) POST /clothes/{id}/image (fotoğraf)
  /// 3) POST /clothes/{id}/predict-category (kategori tahmini)
  /// Başarılıysa güncel ClothingItem döner.
  Future<ClothingItem?> createWithImage({
    required String season,
    String? colorName,
    required List<int> imageBytes,
    required String filename,
    bool isDirty = false,
    bool needsIroning = false,
    bool isIroned = false,
  }) async {
    _error = null;
    notifyListeners();
    try {
      // 1) Item oluştur
      var item = await _repo.create({
        'category': 'unknown',
        'season': season,
        'color_name': colorName,
        'is_dirty': isDirty,
        'needs_ironing': needsIroning,
        'is_ironed': isIroned,
      });

      // 2) Fotoğraf yükle (backend rengi çıkarır)
      item = await _repo.uploadImage(item.id, imageBytes, filename);

      // 3) Kategori tahmini yap
      try {
        final predicted = await _repo.predictCategory(item.id);
        // Tahmin edilen kategoriyi item'a yansıtmak için tekrar getir
        item = await _repo.getById(item.id);
        // predicted değişkeni log için gerekli olabilir ama item zaten güncel
        debugPrint('Kategori tahmini: $predicted');
      } catch (e) {
        // Tahmin başarısız olsa bile item eklensin
        debugPrint('Kategori tahmini başarısız: $e');
      }

      _items = [..._items, item];
      notifyListeners();
      return item;
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



}