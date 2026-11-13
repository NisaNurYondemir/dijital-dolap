import 'package:flutter/foundation.dart';
import 'package:dijital_dolap/data/api_client.dart';
import 'package:dijital_dolap/models/week_plan.dart';

class WeekPlanProvider extends ChangeNotifier {
  final _api = ApiClient.instance;

  WeekPlanResult? _data;
  bool _loading = false;
  String? _error;

  WeekPlanResult? get data => _data;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load({double? latitude, double? longitude}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final params = <String, String>{
        if (latitude != null) 'lat': latitude.toStringAsFixed(4),
        if (longitude != null) 'lon': longitude.toStringAsFixed(4),
      };
      final qs = params.entries
          .map((e) => '${e.key}=${e.value}')
          .join('&');
      final path = qs.isEmpty ? '/insights/week' : '/insights/week?$qs';
      final res = await _api.get(path);
      _data = WeekPlanResult.fromJson(res as Map<String, dynamic>);
      _error = null;
    } catch (_) {
      _error = 'Hafta planı yüklenemedi';
      _data = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clear() {
    _data = null;
    _error = null;
    _loading = false;
    notifyListeners();
  }

  List<WeekPlan> get plansSafe => _data?.plans ?? const [];
}
