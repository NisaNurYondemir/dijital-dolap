import 'package:dijital_dolap/data/api_client.dart';
import 'package:dijital_dolap/models/weather.dart';

class WeatherRepository {
  final _api = ApiClient.instance;

  Future<WeatherInfo> getCurrent({
    required double latitude,
    required double longitude,
    String? city,
  }) async {
    final cityParam = city != null ? '&city=${Uri.encodeComponent(city)}' : '';
    final query = 'lat=$latitude&lon=$longitude$cityParam';
    final res = await _api.get('/weather/current?$query');
    return WeatherInfo.fromJson(res as Map<String, dynamic>);
  }

  Future<List<CitySuggestion>> searchCity(String name) async {
    final res = await _api.get(
      '/weather/search?name=${Uri.encodeComponent(name)}',
    );
    if (res is! List) return [];
    return res
        .map((e) => CitySuggestion.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
