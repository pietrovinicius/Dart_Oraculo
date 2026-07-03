import 'package:flutter/foundation.dart';

import '../../core/config/app_config.dart';
import '../../core/services/secure_storage_service.dart';

/// Controller de configurações — gerencia API key, modelo e biometria.
class SettingsController extends ChangeNotifier {
  SettingsController({required SecureStorageService storageService})
      : _storageService = storageService;

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

  /// Carrega configurações do storage seguro.
  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    _apiKey = await _storageService.getApiKey() ?? '';
    _selectedModel = await _storageService.getDefaultModel() ?? AppConfig.defaultModel;
    _biometricEnabled = await _storageService.isBiometricEnabled();

    _isLoading = false;
    notifyListeners();
  }

  /// Salva a chave de API.
  Future<void> saveApiKey(String key) async {
    await _storageService.setApiKey(key);
    _apiKey = key;
    notifyListeners();
  }

  /// Salva o modelo padrão.
  Future<void> saveModel(String model) async {
    await _storageService.setDefaultModel(model);
    _selectedModel = model;
    notifyListeners();
  }

  /// Salva preferência de biometria.
  Future<void> saveBiometric(bool enabled) async {
    await _storageService.setBiometricEnabled(enabled);
    _biometricEnabled = enabled;
    notifyListeners();
  }

  /// Remove a chave de API.
  Future<void> deleteApiKey() async {
    await _storageService.deleteApiKey();
    _apiKey = '';
    notifyListeners();
  }
}
