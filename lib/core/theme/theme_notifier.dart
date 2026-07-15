import 'package:flutter/material.dart';

import '../services/app_settings_cache.dart';
import '../services/logger_service.dart';
import '../services/secure_storage_service.dart';

/// Gerencia tema (dark/light/system) com persistência.
class ThemeNotifier extends ChangeNotifier {
  ThemeNotifier();

  static const _tag = 'ThemeNotifier';
  static const _key = 'theme_mode';
  ThemeMode _mode = ThemeMode.dark;

  ThemeMode get mode => _mode;

  /// Carrega preferência do cache (batch read já executado em main).
  void load() {
    final saved = AppSettingsCache().get(_key);
    _mode = _fromString(saved);
    LoggerService.instance.info(_tag, 'Tema carregado: $_mode');
    notifyListeners();
  }

  /// Define e persiste novo modo.
  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    try {
      await SecureStorageService().writeRaw(_key, _toString(mode));
      AppSettingsCache().invalidate(_key);
    } catch (_) {}
    LoggerService.instance.info(_tag, 'Tema alterado: $_mode');
    notifyListeners();
  }

  static ThemeMode _fromString(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    'system' => ThemeMode.system,
    _ => ThemeMode.dark,
  };

  static String _toString(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };
}
