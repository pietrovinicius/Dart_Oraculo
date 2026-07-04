import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/storage_keys.dart';
import 'logger_service.dart';

/// Wrapper sobre flutter_secure_storage para acesso seguro a credenciais.
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _tag = 'SecureStorage';
  final FlutterSecureStorage _storage;

  // --- API Key ---

  Future<String?> getApiKey() async {
    try {
      final value = await _storage.read(key: StorageKeys.apiKey);
      LoggerService.instance.info(_tag, 'getApiKey → ${value != null ? "[SET]" : "null"}');
      return value;
    } catch (e, stack) {
      LoggerService.instance.error(_tag, 'getApiKey falhou', e, stack);
      return null;
    }
  }

  Future<void> setApiKey(String value) async {
    try {
      await _storage.write(key: StorageKeys.apiKey, value: value);
      LoggerService.instance.info(_tag, 'setApiKey → salva (${value.length} chars)');
    } catch (e, stack) {
      LoggerService.instance.error(_tag, 'setApiKey falhou', e, stack);
      rethrow;
    }
  }

  Future<void> deleteApiKey() async {
    try {
      await _storage.delete(key: StorageKeys.apiKey);
      LoggerService.instance.info(_tag, 'deleteApiKey → removida');
    } catch (e, stack) {
      LoggerService.instance.error(_tag, 'deleteApiKey falhou', e, stack);
    }
  }

  Future<bool> hasApiKey() async =>
      (await getApiKey()) != null;

  // --- Default Model ---

  Future<String?> getDefaultModel() async {
    try {
      final value = await _storage.read(key: StorageKeys.defaultModel);
      LoggerService.instance.info(_tag, 'getDefaultModel → ${value ?? "null"}');
      return value;
    } catch (e, stack) {
      LoggerService.instance.error(_tag, 'getDefaultModel falhou', e, stack);
      return null;
    }
  }

  Future<void> setDefaultModel(String value) async {
    try {
      await _storage.write(key: StorageKeys.defaultModel, value: value);
      LoggerService.instance.info(_tag, 'setDefaultModel → $value');
    } catch (e, stack) {
      LoggerService.instance.error(_tag, 'setDefaultModel falhou', e, stack);
      rethrow;
    }
  }

  // --- Biometric Toggle ---

  Future<bool> isBiometricEnabled() async {
    try {
      final value = await _storage.read(key: StorageKeys.biometricEnabled);
      final enabled = value == 'true';
      LoggerService.instance.info(_tag, 'isBiometricEnabled → $enabled');
      return enabled;
    } catch (e, stack) {
      LoggerService.instance.error(_tag, 'isBiometricEnabled falhou', e, stack);
      return false;
    }
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    try {
      await _storage.write(
        key: StorageKeys.biometricEnabled,
        value: enabled.toString(),
      );
      LoggerService.instance.info(_tag, 'setBiometricEnabled → $enabled');
    } catch (e, stack) {
      LoggerService.instance.error(_tag, 'setBiometricEnabled falhou', e, stack);
      rethrow;
    }
  }
}
