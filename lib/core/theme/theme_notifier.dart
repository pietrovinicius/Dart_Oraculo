import 'package:flutter/material.dart';

import '../services/secure_storage_service.dart';
import '../services/logger_service.dart';

/// Gerencia tema (dark/light/system) com persistência.
class ThemeNotifier extends ChangeNotifier {
  ThemeNotifier({required SecureStorageService storage}) : _storage = storage;

  static const _tag = 'ThemeNotifier';
  static const _key = 'theme_mode';
  final SecureStorageService _storage;
  ThemeMode _mode = ThemeMode.dark;

  ThemeMode get mode => _mode;

  /// Carrega preferência salva. Default: dark.
  Future<void> load() async {
    try {
      final saved = await _storage.readRaw(_key);
      _mode = _fromString(saved);
    } catch (_) {
      _mode = ThemeMode.dark;
    }
    LoggerService.instance.info(_tag, 'Tema carregado: $_mode');
    notifyListeners();
  }

  /// Define e persiste novo modo.
  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    try {
      await _storage.writeRaw(_key, _toString(mode));
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
