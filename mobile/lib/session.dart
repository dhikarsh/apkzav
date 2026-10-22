import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api.dart';

/// Status login dan data member yang sedang aktif.
class Session extends ChangeNotifier {
  Session({Api? api, FlutterSecureStorage? storage})
      : api = api ?? Api(),
        _storage = storage ?? const FlutterSecureStorage() {
    this.api.onUnauthorized = _clear;
  }

  final Api api;
  final FlutterSecureStorage _storage;

  Map<String, dynamic>? user;
  bool loading = true;

  bool get loggedIn => api.token != null;
  int get balance => (user?['balance'] as num?)?.toInt() ?? 0;

  Future<void> restore() async {
    api.token = await _storage.read(key: 'token');
    if (api.token != null) {
      try {
        await refresh();
      } catch (_) {
        // Tetap masuk dengan data terakhir bila offline; 401 sudah ditangani onUnauthorized.
      }
    }
    loading = false;
    notifyListeners();
  }

  Future<void> login(String phone, String pin) async {
    final res = await api.post('/auth/login',
        {'phone': phone, 'pin': pin, 'device_name': 'android'});
    await _save(res);
  }

  Future<void> register(String name, String phone, String pin, String? upline) async {
    final res = await api.post('/auth/register', {
      'name': name,
      'phone': phone,
      'pin': pin,
      if (upline != null && upline.isNotEmpty) 'upline_phone': upline,
      'device_name': 'android',
    });
    await _save(res);
  }

  Future<void> refresh() async {
    final res = await api.get('/me');
    user = Map<String, dynamic>.from(res['data']);
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await api.post('/auth/logout');
    } catch (_) {}
    await _clear();
  }

  Future<void> _save(dynamic res) async {
    api.token = res['token'];
    user = Map<String, dynamic>.from(res['user']);
    await _storage.write(key: 'token', value: api.token);
    notifyListeners();
  }

  Future<void> _clear() async {
    api.token = null;
    user = null;
    await _storage.delete(key: 'token');
    notifyListeners();
  }
}
