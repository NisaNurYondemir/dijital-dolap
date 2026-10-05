import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const _tokenKey = 'auth_token';
  String? _token;

  /// Platforma göre base URL
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    if (Platform.isIOS) return 'http://localhost:8000';
    return 'http://localhost:8000';
  }

  // ---------- Token yönetimi ----------

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }

  Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  bool get hasToken => _token != null && _token!.isNotEmpty;

  // ---------- Header yardımcıları ----------

  Map<String, String> _headers({bool json = true}) {
    return {
      if (json) 'Content-Type': 'application/json',
      if (hasToken) 'Authorization': 'Bearer $_token',
    };
  }

  // ---------- HTTP metotları ----------

  Future<dynamic> get(String path) async {
    final res = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers(json: false),
    );
    return _handle(res);
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    return _handle(res);
  }

  /// Form-data (login endpoint'i OAuth2PasswordRequestForm istiyor)
  Future<dynamic> postForm(String path, Map<String, String> fields) async {
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        if (hasToken) 'Authorization': 'Bearer $_token',
      },
      body: fields,
    );
    return _handle(res);
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final res = await http.patch(
      Uri.parse('$baseUrl$path'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _handle(res);
  }

  Future<dynamic> delete(String path) async {
    final res = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: _headers(json: false),
    );
    return _handle(res);
  }

    /// Multipart dosya yükleme (fotoğraf için)
  Future<dynamic> uploadFile(
    String path,
    String fieldName,
    List<int> fileBytes,
    String filename,
  ) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = http.MultipartRequest('POST', uri);

    if (hasToken) {
      request.headers['Authorization'] = 'Bearer $_token';
    }

    request.files.add(http.MultipartFile.fromBytes(
      fieldName,
      fileBytes,
      filename: filename,
    ));

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _handle(res);
  }

  // ---------- Response handler ----------

  dynamic _handle(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(utf8.decode(res.bodyBytes));
    }

    String detail = 'Bilinmeyen hata';
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map && body['detail'] != null) {
        detail = body['detail'].toString();
      }
    } catch (_) {
      detail = res.body;
    }
    throw ApiException(res.statusCode, detail);
  }
}