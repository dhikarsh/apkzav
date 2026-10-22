import 'dart:convert';

import 'package:http/http.dart' as http;

/// Alamat backend. Set saat build: flutter build apk --dart-define=API_URL=https://api.domainanda.com
const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8000');

class ApiException implements Exception {
  ApiException(this.message, [this.status]);
  final String message;
  final int? status;

  @override
  String toString() => message;
}

class Api {
  Api({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? token;

  /// Dipanggil saat token ditolak server (login di HP lain / logout dari admin).
  void Function()? onUnauthorized;

  Future<dynamic> get(String path, [Map<String, String>? query]) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) =>
      _send('POST', path, body: body);

  Future<dynamic> _send(String method, String path,
      {Map<String, String>? query, Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$apiUrl/api/v1$path').replace(queryParameters: query);
    final request = http.Request(method, uri)
      ..headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });
    if (body != null) request.body = jsonEncode(body);

    final http.Response res;
    try {
      res = await http.Response.fromStream(
          await _client.send(request).timeout(const Duration(seconds: 40)));
    } catch (_) {
      throw ApiException('Gagal terhubung ke server. Periksa koneksi internet.');
    }

    final data = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode == 401) {
      onUnauthorized?.call();
      throw ApiException('Sesi berakhir, silakan login ulang', 401);
    }
    if (res.statusCode >= 400) {
      throw ApiException(_errorMessage(data, res.statusCode), res.statusCode);
    }
    return data;
  }

  static String _errorMessage(dynamic data, int status) {
    if (data is Map) {
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
      }
      if (data['message'] != null) return data['message'].toString();
    }
    if (status == 429) return 'Terlalu banyak percobaan, tunggu sebentar';
    return 'Terjadi kesalahan ($status)';
  }
}
