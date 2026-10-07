import 'package:dijital_dolap/data/api_client.dart';
import 'package:dijital_dolap/models/outfit.dart';

class OutfitRepository {
  final _api = ApiClient.instance;

  Future<List<Outfit>> getAll() async {
    final res = await _api.get('/outfits/');
    if (res is! List) return [];
    return res.map((e) => Outfit.fromJson(e as Map<String, dynamic>)).toList();
  }
  
  Future<List<Outfit>> getSuggestions() async {
  final res = await _api.get('/outfits/suggest');
  if (res is! List) return [];
  return res
      .map((e) => Outfit.fromSuggestion(e as Map<String, dynamic>))
      .toList();
  }

  Future<Outfit> create(List<int> clothingIds) async {
    final res = await _api.post('/outfits/', body: {'clothing_ids': clothingIds});
    return Outfit.fromJson(res as Map<String, dynamic>);
  }

  Future<Outfit> toggleFavorite(int id, bool isFavorite) async {
    final res = await _api.patch('/outfits/$id', {'is_favorite': isFavorite});
    return Outfit.fromJson(res as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _api.delete('/outfits/$id');
  }

  Future<void> logWear(int outfitId) async {
    await _api.post('/wear/', body: {'outfit_id': outfitId});
  }
}