import 'package:dijital_dolap/data/api_client.dart';
import 'package:dijital_dolap/models/clothing_item.dart';
import 'package:dijital_dolap/models/laundry.dart';

/// Çamaşır ayarları ve yıkama işlemleri.
class LaundryRepository {
  final ApiClient _api = ApiClient.instance;

  Future<LaundrySettings> fetchSettings() async {
    final res = await _api.get('/settings/laundry');
    return LaundrySettings.fromJson(res as Map<String, dynamic>);
  }

  /// Sadece gönderilen kategorilerin kuralları güncellenir.
  Future<LaundrySettings> saveRules(Map<String, LaundryRule> rules) async {
    final res = await _api.put(
      '/settings/laundry',
      body: {
        'rules': rules.map((k, v) => MapEntry(k, v.toJson())),
      },
    );
    return LaundrySettings.fromJson(res as Map<String, dynamic>);
  }

  /// Yıkanan parçaları döner (temiz durumuna geçmiş haliyle).
  Future<List<ClothingItem>> wash({
    List<int>? clothingIds,
    bool allDirty = false,
  }) async {
    final res = await _api.post('/clothes/wash', body: {
      'clothing_ids': clothingIds,
      'all_dirty': allDirty,
    });
    if (res is! List) return [];
    return res
        .map((e) => ClothingItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
