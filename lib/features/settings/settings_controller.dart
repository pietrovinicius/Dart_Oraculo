import 'package:flutter/foundation.dart';

import '../../core/config/app_config.dart';
import '../../core/services/app_settings_cache.dart';
import '../../core/services/logger_service.dart';
import '../../core/services/secure_storage_service.dart';

/// Controller de configurações — gerencia API key, modelo e biometria.
class SettingsController extends ChangeNotifier {
  SettingsController({SecureStorageService? storageService})
      : _storageService = storageService ?? SecureStorageService();

  static const _tag = 'SettingsController';
  final SecureStorageService _storageService;

  String _apiKey = '';
  String _selectedModel = AppConfig.defaultModel;
  bool _biometricEnabled = false;
  bool _isLoading = true;

  String get apiKey => _apiKey;
  String get selectedModel => _selectedModel;
  bool get biometricEnabled => _biometricEnabled;
  bool get isLoading => _isLoading;
  bool get hasApiKey => _apiKey.isNotEmpty;

  /// Carrega do cache em memória — sem acesso Keychain.
  /// Fallback ao storage direto se cache não inicializado (testes).
  Future<void> load() async {
    LoggerService.instance.info(_tag, 'load() iniciando');
    _isLoading = true;
    notifyListeners();

    final cache = AppSettingsCache();
    if (cache.isInitialized) {
      _apiKey = cache.get('anthropic_api_key') ?? '';
      _selectedModel = cache.get('default_model') ?? AppConfig.defaultModel;
      final bioStr = cache.get('biometric_enabled');
      _biometricEnabled = bioStr == 'true';
    } else {
      // Fallback: testes ou cenário sem cache
      _apiKey = await _storageService.getApiKey() ?? '';
      _selectedModel =
          await _storageService.getDefaultModel() ?? AppConfig.defaultModel;
      _biometricEnabled = await _storageService.isBiometricEnabled();
    }

    _isLoading = false;
    LoggerService.instance.info(_tag, 'load() completo — hasApiKey=$hasApiKey, model=$_selectedModel, bio=$_biometricEnabled');
    notifyListeners();
  }

  Future<void> saveApiKey(String key) async {
    LoggerService.instance.info(_tag, 'saveApiKey() chamado (${key.length} chars)');
    await _storageService.setApiKey(key);
    AppSettingsCache().invalidate('anthropic_api_key');
    _apiKey = key;
    LoggerService.instance.info(_tag, 'saveApiKey() sucesso');
    notifyListeners();
  }

  Future<void> saveModel(String model) async {
    LoggerService.instance.info(_tag, 'saveModel() → $model');
    await _storageService.setDefaultModel(model);
    AppSettingsCache().invalidate('default_model');
    _selectedModel = model;
    notifyListeners();
  }

  Future<void> saveBiometric(bool enabled) async {
    LoggerService.instance.info(_tag, 'saveBiometric() → $enabled');
    await _storageService.setBiometricEnabled(enabled);
    AppSettingsCache().invalidate('biometric_enabled');
    _biometricEnabled = enabled;
    notifyListeners();
  }

  Future<void> deleteApiKey() async {
    LoggerService.instance.info(_tag, 'deleteApiKey()');
    await _storageService.deleteApiKey();
    AppSettingsCache().invalidate('anthropic_api_key');
    _apiKey = '';
    notifyListeners();
  }
}
