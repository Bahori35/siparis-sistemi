import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

class AuthService extends ChangeNotifier {
  String? _token;
  Map<String, dynamic>? _user;
  bool _isLoading = false;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;
  String? get role => _user?['role'];
  String? get shopName => _user?['shop_name'];
  int? get shopId => _user?['shop_id'];

  Future<bool> initAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    final userJson = prefs.getString('auth_user');
    if (userJson != null) {
      _user = jsonDecode(userJson);
      if (_user?['role'] == 'SHOP_OWNER') {
        final service = FlutterBackgroundService();
        final isRunning = await service.isRunning();
        if (!isRunning) {
          await service.startService();
        }
      }
    }
    notifyListeners();
    return isAuthenticated;
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _token = data['data']['token'];
        _user = data['data']['user'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
        await prefs.setString('auth_user', jsonEncode(_user));

        if (_user?['role'] == 'SHOP_OWNER') {
          final service = FlutterBackgroundService();
          final isRunning = await service.isRunning();
          if (!isRunning) {
            await service.startService();
          }
        }

        _isLoading = false;
        notifyListeners();
        return {'success': true, 'role': _user?['role']};
      } else {
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'message': data['message'] ?? 'Giriş yapılamadı.'};
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Bağlantı hatası: $e'};
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_user');
    
    final service = FlutterBackgroundService();
    service.invoke('stopService');

    notifyListeners();
  }
}
