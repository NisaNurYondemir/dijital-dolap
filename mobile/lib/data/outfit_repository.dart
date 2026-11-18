import 'package:dijital_dolap/data/api_client.dart';
import 'package:dijital_dolap/models/outfit.dart';
import 'package:dijital_dolap/models/wear_entry.dart';

class OutfitRepository {
  final _api = ApiClient.instance;

  Future<List<Outfit>> getAll({int? occasionId}) async {
    final path = occasionId != null
        ? '/outfits/?occasion_id=$occasionId'
        : '/outfits/';
    final res = await _api.get(path);
    if (res is! List) return [];
    return res.map((e) => Outfit.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Outfit>> getSuggestions({
    int? occasionId,
    double? latitude,
    double? longitude,
    String? city,
  }) async {
    final params = <String>[
      if (occasionId != null) 'occasion_id=$occasionId',
      if (latitude != null) 'lat=$latitude',
      if (longitude != null) 'lon=$longitude',
      if (city != null) 'city=${Uri.encodeComponent(city)}',
    ];
    final path = params.isEmpty
        ? '/outfits/suggest'
        : '/outfits/suggest?${params.join('&')}';
    final res = await _api.get(path);
    if (res is! List) return [];
    return res
        .map((e) => Outfit.fromSuggestion(e as Map<String, dynamic>))
        .toList();
  }

  Future<Outfit> create(
    List<int> clothingIds, {
    List<int> occasionIds = const [],
    bool isFavorite = false,
    String? name,
    String? description,
  }) async {
    final res = await _api.post('/outfits/', body: {
      'clothing_ids': clothingIds,
      if (occasionIds.isNotEmpty) 'occasion_ids': occasionIds,
      'is_favorite': isFavorite,
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
    });
    return Outfit.fromJson(res as Map<String, dynamic>);
  }

  Future<Outfit> updateDetails(
    int id, {
    String? name,
    String? description,
  }) async {
    final res = await _api.patch('/outfits/$id', {
      'name': ?name,
      'description': ?description,
    });
    return Outfit.fromJson(res as Map<String, dynamic>);
  }

  /// Kombinin giyim geçmişi (tarih, puan, sıcaklık hissi, hava).
  Future<List<WearEntry>> getHistory(int id, {int limit = 50}) async {
    final res = await _api.get('/outfits/$id/history?limit=$limit');
    if (res is! List) return [];
    return res
        .map((e) => WearEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Outfit> setOccasions(int id, List<int> occasionIds) async {
    final res = await _api.patch(
      '/outfits/$id',
      {'occasion_ids': occasionIds},
    );
    return Outfit.fromJson(res as Map<String, dynamic>);
  }

  Future<Outfit> toggleFavorite(int id, bool isFavorite) async {
    final res = await _api.patch('/outfits/$id', {'is_favorite': isFavorite});
    return Outfit.fromJson(res as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _api.delete('/outfits/$id');
  }
}
