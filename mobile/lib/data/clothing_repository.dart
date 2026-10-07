import 'package:dijital_dolap/data/api_client.dart';
import 'package:dijital_dolap/models/clothing_item.dart';
import 'package:dijital_dolap/models/analysis_result.dart';

class ClothingRepository {
  final _api = ApiClient.instance;

  /// Tüm kıyafetleri getir
  Future<List<ClothingItem>> getAll({
    String? category,
    String? season,
    bool? isDirty,
    bool? needsIroning,
  }) async {
    final query = <String, String>{};
    if (category != null) query['category'] = category;
    if (season != null) query['season'] = season;
    if (isDirty != null) query['is_dirty'] = isDirty.toString();
    if (needsIroning != null) query['needs_ironing'] = needsIroning.toString();

    final qs = query.isEmpty
        ? ''
        : '?${query.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final res = await _api.get('/clothes/$qs');
    if (res is! List) return [];
    return res
        .map((e) => ClothingItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ClothingItem> getById(int id) async {
    final res = await _api.get('/clothes/$id');
    return ClothingItem.fromJson(res as Map<String, dynamic>);
  }

  Future<ClothingItem> create(Map<String, dynamic> data) async {
    final res = await _api.post('/clothes/', body: data);
    return ClothingItem.fromJson(res as Map<String, dynamic>);
  }

  Future<ClothingItem> update(int id, Map<String, dynamic> data) async {
    final res = await _api.patch('/clothes/$id', data);
    return ClothingItem.fromJson(res as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _api.delete('/clothes/$id');
  }

    /// Fotoğraf yükle (backend rengi otomatik çıkarır)
  Future<ClothingItem> uploadImage(int id, List<int> bytes, String filename) async {
    final res = await _api.uploadFile(
      '/clothes/$id/image',
      'file',
      bytes,
      filename,
    );
    return ClothingItem.fromJson(res as Map<String, dynamic>);
  }

  /// Kategori tahmini yap (CLIP modeli)
  Future<String> predictCategory(int id) async {
    final res = await _api.post('/clothes/$id/predict-category');
    return res['category'] as String;
  }
    /// Kayıt açmadan fotoğrafı analiz et (arka plan sil, renk, kategori adayları)
  Future<AnalysisResult> analyze(List<int> bytes, String filename) async {
    final res = await _api.uploadFile(
      '/clothes/analyze',
      'file',
      bytes,
      filename,
    );
    return AnalysisResult.fromJson(res as Map<String, dynamic>);
  }

}