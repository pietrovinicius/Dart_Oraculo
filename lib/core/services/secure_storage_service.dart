import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/storage_keys.dart';

/// Wrapper sobre flutter_secure_storage para acesso seguro a credenciais.
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  // --- API Key ---

  Future<String?> getApiKey() =>
      _storage.read(key: StorageKeys.apiKey);

  Future<void> setApiKey(String value) =>
      _storage.write(key: StorageKeys.apiKey, value: value);

  Future<void> deleteApiKey() =>
      _storage.delete(key: StorageKeys.apiKey);

  Future<bool> hasApiKey() async =>
      (await getApiKey()) != null;

  // --- Default Model ---

  Future<String?> getDefaultModel() =>
      _storage.read(key: StorageKeys.defaultModel);

  Future<void> setDefaultModel(String value) =>
      _storage.write(key: StorageKeys.defaultModel, value: value);

  // --- Biometric Toggle ---

  Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: StorageKeys.biometricEnabled);
    return value == 'true';
  }

  Future<void> setBiometricEnabled(bool enabled) =>
      _storage.write(
        key: StorageKeys.biometricEnabled,
        value: enabled.toString(),
      );
}
