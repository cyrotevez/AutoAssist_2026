import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

const kampala = LatLng(0.3476, 32.5825);

/// Which bottom-navigation tab is open. Any screen can change it.
final shellIndex = ValueNotifier<int>(0);

class AppState extends ChangeNotifier {
  static const defaultServer = 'http://172.20.10.6:8000';

  late SharedPreferences _prefs;
  Api api = Api(defaultServer, null);
  ThemeMode themeMode = ThemeMode.system;
  Map<String, dynamic>? user;
  LatLng? location;

  bool get isLoggedIn => user != null && api.token != null;
  String get role => (user?['role'] ?? 'driver') as String;
  int get userId => (user?['id'] ?? 0) as int;
  String get serverUrl => api.baseUrl;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final t = _prefs.getString('theme') ?? 'system';
    themeMode = t == 'dark' ? ThemeMode.dark : (t == 'light' ? ThemeMode.light : ThemeMode.system);
    api = Api(_prefs.getString('server') ?? defaultServer, _prefs.getString('token'));
    final cached = _prefs.getString('user');
    if (cached != null && api.token != null) {
      try {
        user = Map<String, dynamic>.from(jsonDecode(cached) as Map);
      } catch (_) {
        user = null;
      }
    }
    if (user != null) unawaited(refreshUser());
  }

  Future<void> refreshUser() async {
    try {
      final data = await api.get('/me');
      user = Map<String, dynamic>.from(data as Map);
      await _prefs.setString('user', jsonEncode(user));
      notifyListeners();
    } on ApiException catch (e) {
      if (e.status == 401) await logout();
    }
  }

  Future<void> setSession(String token, Map<String, dynamic> u) async {
    api.token = token;
    user = u;
    await _prefs.setString('token', token);
    await _prefs.setString('user', jsonEncode(u));
    shellIndex.value = 0;
    notifyListeners();
  }

  Future<void> updateUser(Map<String, dynamic> u) async {
    user = u;
    await _prefs.setString('user', jsonEncode(u));
    notifyListeners();
  }

  Future<void> logout() async {
    api.token = null;
    user = null;
    await _prefs.remove('token');
    await _prefs.remove('user');
    shellIndex.value = 0;
    notifyListeners();
  }

  Future<void> setServer(String url) async {
    api.baseUrl = Api.normalize(url);
    await _prefs.setString('server', api.baseUrl);
    notifyListeners();
  }

  Future<void> setDark(bool dark) async {
    themeMode = dark ? ThemeMode.dark : ThemeMode.light;
    await _prefs.setString('theme', dark ? 'dark' : 'light');
    notifyListeners();
  }
}

final app = AppState();
