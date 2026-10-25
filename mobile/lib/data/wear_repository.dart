import 'package:dijital_dolap/data/api_client.dart';
import 'package:dijital_dolap/models/wear_entry.dart';

class WearRepository {
  final _api = ApiClient.instance;

  Future<List<WearEntry>> getAll({int limit = 100}) async {
    final res = await _api.get('/wear/?limit=$limit');
    if (res is! List) return [];
    return res
        .map((e) => WearEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WearEntry> log({
    int? outfitId,
    List<int>? clothingIds,
    int? rating,
    String? occasion,
    String? note,
  }) async {
    final ids =
        (clothingIds != null && clothingIds.isNotEmpty) ? clothingIds : null;
    final res = await _api.post('/wear/', body: {
      'outfit_id': ?outfitId,
      'clothing_ids': ?ids,
      'rating': ?rating,
      'occasion': ?occasion,
      'note': ?note,
    });
    return WearEntry.fromJson(res as Map<String, dynamic>);
  }

  Future<WearEntry> update(
    int id, {
    int? rating,
    String? occasion,
    String? note,
  }) async {
    final res = await _api.patch('/wear/$id', {
      'rating': ?rating,
      'occasion': ?occasion,
      'note': ?note,
    });
    return WearEntry.fromJson(res as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _api.delete('/wear/$id');
  }
}
