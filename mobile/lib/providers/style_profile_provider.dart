import 'package:flutter/foundation.dart';
import 'package:dijital_dolap/data/api_client.dart';
import 'package:dijital_dolap/models/style_profile.dart';
import 'package:dijital_dolap/utils/error_text.dart';

/// GET /insights/style: giyim gecmisinden ogrenilen tarz profili.
class StyleProfileProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient.instance;

  StyleProfile? profile;
  bool loading = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await _api.get('/insights/style');
      profile = StyleProfile.fromJson(res as Map<String, dynamic>);
    } catch (e) {
      error = friendlyError(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void clear() {
    profile = null;
    error = null;
    loading = false;
    notifyListeners();
  }
}
