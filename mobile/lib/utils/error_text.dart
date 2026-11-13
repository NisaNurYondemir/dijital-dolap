import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart';
import 'package:dijital_dolap/data/api_client.dart';

/// API ve ağ hatalarını kullanıcı dostu Türkçe metne çevirir.
String friendlyError(Object? e) {
  final raw = e?.toString() ?? '';
  if (e is SocketException ||
      (!kIsWeb && e is ApiException && e.statusCode == 0) ||
      raw.contains('SocketException') ||
      raw.contains('ClientException') ||
      raw.contains('Connection refused')) {
    return 'İnternet bağlantısı yok gibi görünüyor. Tekrar deneyebilirsin.';
  }
  if (e is ApiException) {
    if (e.statusCode >= 500) {
      return 'Sunucuda bir sorun oldu. Birazdan tekrar deneyebilirsin.';
    }
    return e.message;
  }
  return raw.isEmpty ? 'Bir şeyler ters gitti' : raw;
}
