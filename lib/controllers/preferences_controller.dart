import 'package:flutter/material.dart';

import '../models/preferences.dart';
import '../services/preferences_storage.dart';

class PreferencesController extends ChangeNotifier {
  final _storage = PreferencesStorage();
  AppPreferences value = const AppPreferences();
  bool loaded = false;
  String? error;
  Future<void> load() async {
    try {
      value = await _storage.load();
    } catch (_) {
      error = 'Não foi possível recuperar as preferências. Os padrões foram carregados.';
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _pending = Future<void>.value();
  Future<bool> update(Map<String, dynamic> patch) {
    final result = _pending.then((_) => save(patch));
    _pending = result.then<void>((_) {});
    return result;
  }

  Future<bool> save(Map<String, dynamic> patch) async {
    final next = value.changed(patch);
    try {
      if (!await _storage.save(next)) {
        throw Exception('Storage');
      }
      value = next;
      error = null;
      notifyListeners();
      return true;
    } catch (_) {
      error = 'Não foi possível salvar as preferências. Tente novamente.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> reset() => update(const AppPreferences().toJson());
}
