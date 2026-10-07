import 'package:dijital_dolap/data/api_client.dart';

class AuthService {
  final _api = ApiClient.instance;

  /// Giriş yap → token kaydet
  Future<void> login({
    required String email,
    required String password,
  }) async {
    final res = await _api.postForm('/auth/login', {
      'username': email, // backend email bekliyor
      'password': password,
    });
    final token = res['access_token'] as String;
    await _api.saveToken(token);
  }

  /// Kayıt ol → kullanıcı oluştur (token dönmüyor, sonra login gerekir)
  Future<void> register({
    required String email,
    required String username,
    required String password,
  }) async {
    await _api.post('/auth/register', body: {
      'email': email,
      'username': username,
      'password': password,
    });
  }

  /// Şifre değiştir
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.post('/auth/change-password', body: {
      'current_password': currentPassword,
      'new_password': newPassword,
      });
  }

  /// Mevcut kullanıcı bilgisi
  Future<Map<String, dynamic>> me() async {
    final res = await _api.get('/auth/me');
    return Map<String, dynamic>.from(res);
  }

  /// Çıkış
  Future<void> logout() async {
    await _api.clearToken();
  }
}