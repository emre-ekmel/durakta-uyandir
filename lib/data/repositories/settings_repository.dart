import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SettingsRepository {
  static const String _boxName = 'settings_box';
  static const String _keyTheme = 'theme_mode';
  static const String _keySound = 'sound_enabled';
  static const String _keyVibration = 'vibration_enabled';
  static const String _keyNotification = 'notification_enabled';
  static const String _keyHeadphoneOnly = 'headphone_only_enabled';
  static const String _keyAnalytics = 'analytics_enabled';

  late Box _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  ThemeMode getThemeMode() {
    final String? stored = _box.get(_keyTheme);
    if (stored == 'light') return ThemeMode.light;
    if (stored == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    String value = 'system';
    if (mode == ThemeMode.light) value = 'light';
    if (mode == ThemeMode.dark) value = 'dark';
    await _box.put(_keyTheme, value);
  }

  bool isSoundEnabled() => _box.get(_keySound, defaultValue: true);
  Future<void> setSoundEnabled(bool value) => _box.put(_keySound, value);

  bool isVibrationEnabled() => _box.get(_keyVibration, defaultValue: true);
  Future<void> setVibrationEnabled(bool value) => _box.put(_keyVibration, value);

  bool isNotificationEnabled() => _box.get(_keyNotification, defaultValue: true);
  Future<void> setNotificationEnabled(bool value) => _box.put(_keyNotification, value);

  bool isHeadphoneOnlyModeEnabled() => _box.get(_keyHeadphoneOnly, defaultValue: false);
  Future<void> setHeadphoneOnlyModeEnabled(bool value) => _box.put(_keyHeadphoneOnly, value);

  bool? isAnalyticsEnabled() => _box.get(_keyAnalytics);
  Future<void> setAnalyticsEnabled(bool value) => _box.put(_keyAnalytics, value);

  Map<String, dynamic> getAllSettings() {
    return {
      'sound': isSoundEnabled(),
      'vibration': isVibrationEnabled(),
      'notification': isNotificationEnabled(),
      'headphoneOnly': isHeadphoneOnlyModeEnabled(),
    };
  }
}
