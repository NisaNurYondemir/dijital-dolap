import 'package:dijital_dolap/data/api_client.dart';
import 'package:dijital_dolap/models/dashboard.dart';

class DashboardRepository {
  final _api = ApiClient.instance;

  Future<WardrobeDashboard> get() async {
    final res = await _api.get('/insights/wardrobe');
    return WardrobeDashboard.fromJson(res as Map<String, dynamic>);
  }
}
