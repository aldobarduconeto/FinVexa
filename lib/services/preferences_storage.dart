import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/preferences.dart';

class PreferencesStorage {
  static const _preferences = 'preferences_v1';
  static const _welcome = 'welcome_completed_v1';

  Future<AppPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_preferences);
    return raw == null
        ? const AppPreferences()
        : AppPreferences.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
  }

  Future<bool> save(AppPreferences value) async =>
      (await SharedPreferences.getInstance()).setString(
        _preferences,
        jsonEncode(value.toJson()),
      );

  Future<bool> welcomeCompleted() async =>
      (await SharedPreferences.getInstance()).getBool(_welcome) ?? false;

  Future<bool> completeWelcome() async =>
      (await SharedPreferences.getInstance()).setBool(_welcome, true);
}
