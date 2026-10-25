import 'package:dijital_dolap/data/api_client.dart';
import 'package:dijital_dolap/models/occasion_group.dart';

class OccasionRepository {
  final _api = ApiClient.instance;

  Future<List<OccasionGroup>> getAll() async {
    final res = await _api.get('/occasions/');
    if (res is! List) return [];
    return res
        .map((e) => OccasionGroup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<OccasionGroup> create(
    String name, {
    String? emoji,
    String? color,
  }) async {
    final res = await _api.post('/occasions/', body: {
      'name': name,
      'emoji': ?emoji,
      'color': ?color,
    });
    return OccasionGroup.fromJson(res as Map<String, dynamic>);
  }

  Future<OccasionGroup> update(
    int id, {
    String? name,
    String? emoji,
    String? color,
  }) async {
    final res = await _api.patch('/occasions/$id', {
      'name': ?name,
      'emoji': ?emoji,
      'color': ?color,
    });
    return OccasionGroup.fromJson(res as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _api.delete('/occasions/$id');
  }
}
