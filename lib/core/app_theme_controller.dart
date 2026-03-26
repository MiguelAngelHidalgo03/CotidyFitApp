import 'package:flutter/material.dart';

import '../models/user_settings.dart';
import '../services/settings_service.dart';

class AppThemeController extends ChangeNotifier {
  AppThemeController._();

  static final AppThemeController instance = AppThemeController._();

  final SettingsService _settingsService = SettingsService();

  AppThemeMode _mode = AppThemeMode.system;
  bool _loaded = false;

  AppThemeMode get mode => _mode;
  bool get loaded => _loaded;

  ThemeMode get themeMode {
    switch (_mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  Future<void> load() async {
    if (_loaded) return;
    final settings = await _settingsService.getSettings();
    _mode = settings.appThemeMode;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setMode(AppThemeMode mode) async {
    if (_mode == mode && _loaded) return;

    final settings = await _settingsService.getSettings();
    await _settingsService.saveSettings(settings.copyWith(appThemeMode: mode));

    _mode = mode;
    _loaded = true;
    notifyListeners();
  }
}
