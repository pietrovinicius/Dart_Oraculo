import 'package:flutter/material.dart';

import '../services/app_settings_cache.dart';
import '../services/error_feedback_service.dart';
import '../services/logger_service.dart';
import '../services/secure_storage_service.dart';

/// Gerencia tema (dark/light/system) com persistência.
class ThemeNotifier extends ChangeNotifier {
  ThemeNotifier();

  static const _tag = 'ThemeNotifier';
  static const _key = 'theme_mode';
  ThemeMode _mode = ThemeMode.dark;
  ThemeMode _lastSuccessfulMode = ThemeMode.dark;

  // For testing: allows injecting a test storage service
  static SecureStorageService? _testStorageService;

  static void setStorageForTesting(SecureStorageService service) {
    _testStorageService = service;
  }

  static void clearStorageForTesting() {
    _testStorageService = null;
  }

  ThemeMode get mode => _mode;

  /// Carrega preferência do cache (batch read já executado em main).
  void load() {
    final saved = AppSettingsCache().get(_key);
    _mode = _fromString(saved);
    _lastSuccessfulMode = _mode;
    LoggerService.instance.info(_tag, 'Tema carregado: $_mode');
    notifyListeners();
  }

  /// Define e persiste novo modo.
  /// Se [context] for fornecido e a escrita falhar, exibe erro crítico.
  Future<void> setMode(ThemeMode mode, [BuildContext? context]) async {
    final previousMode = _mode;
    _mode = mode;
    notifyListeners();

    try {
      final storage = _testStorageService ?? SecureStorageService();
      await storage.writeRaw(_key, _toString(mode));
      AppSettingsCache().invalidate(_key);
      _lastSuccessfulMode = mode;
      LoggerService.instance.info(_tag, 'Tema persistido: $_mode');
    } catch (e) {
      LoggerService.instance.error(_tag, 'Falha ao persistir tema', e);

      // Reverter estado
      _mode = previousMode;
      notifyListeners();

      // Notificar usuário — consciência de perda de dados
      if (context != null && context.mounted) {
        ErrorFeedbackService.showCriticalError(
          context,
          'Tema não foi salvo. Reinicie o app para recuperar preferência anterior.',
        );
      }
    }
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
