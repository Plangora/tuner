import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/metronome_settings.dart';

abstract interface class MetronomeSettingsRepository {
  Future<MetronomeSettings> load();
  Future<void> save(MetronomeSettings settings);
}

class PreferencesMetronomeSettingsRepository
    implements MetronomeSettingsRepository {
  static const key = 'metronome.settings.v1';
  @override
  Future<MetronomeSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(key);
      return value == null
          ? MetronomeSettings()
          : MetronomeSettings.fromJson(jsonDecode(value));
    } on FormatException {
      return MetronomeSettings();
    } on TypeError {
      return MetronomeSettings();
    }
  }

  @override
  Future<void> save(MetronomeSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(key, jsonEncode(settings.toJson()))) {
      throw StateError('Settings storage rejected the write.');
    }
  }
}
