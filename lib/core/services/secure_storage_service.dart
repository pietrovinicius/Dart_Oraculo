import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/storage_keys.dart';
import 'logger_service.dart';

/// Exceção para falhas de Keychain.
class SecureStorageException implements Exception {
  const SecureStorageException(this.message);
  final String message;

  @override
  String toString() => 'SecureStorageException: $message';
}

/// Wrapper sobre flutter_secure_storage.
/// Falha de Keychain surfaça como erro — nunca grava em texto plano.
class SecureStorageService {
  /// Singleton — garante sessão única de Keychain (evita prompts repetidos).
  factory SecureStorageService() => _instance;

  SecureStorageService._internal()
      : _storage = const FlutterSecureStorage(
          mOptions: MacOsOptions(
            // true = data-protection keychain (desbloqueia uma vez ao login,
            // não pede senha por item). false = login keychain (prompt por acesso).
            useDataProtectionKeyChain: true,
            accessibility: KeychainAccessibility.first_unlock,
          ),
        ),
        testStore = null;

  /// Construtor para testes — injeta storage mock.
  SecureStorageService.test({FlutterSecureStorage? storage, this.testStore})
      : _storage = storage ??
            const FlutterSecureStorage(
              mOptions: MacOsOptions(
                useDataProtectionKeyChain: true,
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  static final SecureStorageService _instance = SecureStorageService._internal();

  static const _tag = 'SecureStorage';
  final FlutterSecureStorage _storage;

  /// Para testes — se não-null, usa este mapa em vez de Keychain.
  final Map<String, String>? testStore;

  // --- API Key ---

  Future<String?> getApiKey() => _read(StorageKeys.apiKey);

  Future<void> setApiKey(String value) => _write(StorageKeys.apiKey, value);

  Future<void> deleteApiKey() => _delete(StorageKeys.apiKey);

  Future<bool> hasApiKey() async => (await getApiKey()) != null;

  // --- Kimi API Key ---

  Future<String?> getKimiApiKey() => _read(StorageKeys.kimiApiKey);

  Future<void> setKimiApiKey(String value) => _write(StorageKeys.kimiApiKey, value);

  Future<void> deleteKimiApiKey() => _delete(StorageKeys.kimiApiKey);

  Future<bool> hasKimiApiKey() async => (await getKimiApiKey()) != null;

  // --- Default Model ---

  Future<String?> getDefaultModel() => _read(StorageKeys.defaultModel);

  Future<void> setDefaultModel(String value) =>
      _write(StorageKeys.defaultModel, value);

  // --- Biometric Toggle ---

  Future<bool> isBiometricEnabled() async {
    final value = await _read(StorageKeys.biometricEnabled);
    LoggerService.instance.info(_tag, 'isBiometricEnabled → ${value == "true"}');
    return value == 'true';
  }

  Future<void> setBiometricEnabled(bool enabled) =>
      _write(StorageKeys.biometricEnabled, enabled.toString());

  // --- Acesso genérico (para ThemeNotifier e futuros) ---

  Future<String?> readRaw(String key) => _read(key);

  Future<void> writeRaw(String key, String value) => _write(key, value);

  // --- Internal: read/write/delete (Keychain only, no fallback) ---

  Future<String?> _read(String key) async {
    if (testStore != null) return testStore![key];

    try {
      final value = await _storage.read(key: key);
      LoggerService.instance.info(_tag, 'read($key) → ${value != null ? "[SET]" : "null"}');
      return value;
    } catch (e) {
      LoggerService.instance.error(_tag, 'Keychain read falhou para "$key"', e);
      throw SecureStorageException(
        'Não foi possível ler do Keychain. Verifique as permissões do app. ($e)',
      );
    }
  }

  Future<void> _write(String key, String value) async {
    if (testStore != null) {
      testStore![key] = value;
      return;
    }

    try {
      await _storage.write(key: key, value: value);
      LoggerService.instance.info(_tag, 'write($key) → OK (${value.length} chars)');
    } catch (e) {
      LoggerService.instance.error(_tag, 'Keychain write falhou para "$key"', e);
      throw SecureStorageException(
        'Não foi possível gravar no Keychain. Verifique as permissões do app. ($e)',
      );
    }
  }

  Future<void> _delete(String key) async {
    if (testStore != null) {
      testStore!.remove(key);
      return;
    }

    try {
      await _storage.delete(key: key);
      LoggerService.instance.info(_tag, 'delete($key) → OK');
    } catch (e) {
      LoggerService.instance.error(_tag, 'Keychain delete falhou para "$key"', e);
      throw SecureStorageException(
        'Não foi possível remover do Keychain. Verifique as permissões do app. ($e)',
      );
    }
  }
}
