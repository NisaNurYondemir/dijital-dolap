import 'package:flutter/material.dart';
import 'package:dijital_dolap/data/api_client.dart';
import 'package:dijital_dolap/data/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final _service = AuthService();

  AuthStatus _status = AuthStatus.unknown;
  Map<String, dynamic>? _user;
  bool _loading = false;
  String? _error;

  AuthStatus get status => _status;
  Map<String, dynamic>? get user => _user;
  bool get loading => _loading;
  String? get error => _error;

  /// Uygulama açılışında çağrılır: token var mı?
  Future<void> bootstrap() async {
    await ApiClient.instance.loadToken();
    if (ApiClient.instance.hasToken) {
      try {
        _user = await _service.me();
        _status = AuthStatus.authenticated;
      } catch (_) {
        await ApiClient.instance.clearToken();
        _status = AuthStatus.unauthenticated;
      }
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _service.login(email: email, password: password);
      _user = await _service.me();
      _status = AuthStatus.authenticated;
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Bağlantı hatası: $e';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> register(String email, String username, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _service.register(
        email: email,
        username: username,
        password: password,
      );
      // Kayıt başarılı → otomatik login
      return await login(email, password);
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Bağlantı hatası: $e';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _service.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}