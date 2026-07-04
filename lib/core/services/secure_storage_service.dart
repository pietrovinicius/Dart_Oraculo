import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/storage_keys.dart';
import 'logger_service.dart';

/// Wrapper sobre flutter_secure_storage com fallback para arquivo local.
/// Em macOS sem code signing (dev), Keychain falha com -34018.
/// Nesse caso, usa arquivo JSON em Application Support como fallback.
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage, this.testStore})
      : _storage = storage ??
            const FlutterSecureStorage(
              mOptions: MacOsOptions(
                useDataProtectionKeyChain: false,
              ),
            ),
        // Se storage foi injetado explicitamente (testes), não usa file fallback
        _useFileFallback = storage == null && testStore == null;

  static const _tag = 'SecureStorage';
  final FlutterSecureStorage _storage;

  /// Para testes — se não-null, usa este mapa em vez de Keychain/fallback.
  final Map<String, String>? testStore;

  // TODO(auth): voltar para `storage == null` quando app tiver code signing.
  // Em dev, Keychain pede senha do macOS a cada recompilação.
  // Quando storage==null (produção), usa file fallback para evitar prompt.
  // Quando storage é injetado (testes), usa o storage injetado diretamente.
  // ignore: prefer_final_fields
  bool _useFileFallback;
  Map<String, String>? _fileCache;

  // --- API Key ---

  Future<String?> getApiKey() => _read(StorageKeys.apiKey);

  Future<void> setApiKey(String value) => _write(StorageKeys.apiKey, value);

  Future<void> deleteApiKey() => _delete(StorageKeys.apiKey);

  Future<bool> hasApiKey() async => (await getApiKey()) != null;

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

  // --- Internal: read/write/delete with fallback ---

  Future<String?> _read(String key) async {
    if (testStore != null) return testStore![key];

    if (_useFileFallback) return _readFromFile(key);

    try {
      final value = await _storage.read(key: key);
      LoggerService.instance.info(_tag, 'read($key) → ${value != null ? "[SET]" : "null"}');
      return value;
    } catch (e) {
      LoggerService.instance.warn(_tag, 'Keychain read falhou, ativando fallback de arquivo: $e');
      _useFileFallback = true;
      return _readFromFile(key);
    }
  }

  Future<void> _write(String key, String value) async {
    if (testStore != null) {
      testStore![key] = value;
      return;
    }

    if (_useFileFallback) {
      await _writeToFile(key, value);
      return;
    }

    try {
      await _storage.write(key: key, value: value);
      LoggerService.instance.info(_tag, 'write($key) → OK (${value.length} chars)');
    } catch (e) {
      LoggerService.instance.warn(_tag, 'Keychain write falhou, ativando fallback de arquivo: $e');
      _useFileFallback = true;
      await _writeToFile(key, value);
    }
  }

  Future<void> _delete(String key) async {
    if (testStore != null) {
      testStore!.remove(key);
      return;
    }

    if (_useFileFallback) {
      await _deleteFromFile(key);
      return;
    }

    try {
      await _storage.delete(key: key);
      LoggerService.instance.info(_tag, 'delete($key) → OK');
    } catch (e) {
      LoggerService.instance.warn(_tag, 'Keychain delete falhou, ativando fallback: $e');
      _useFileFallback = true;
      await _deleteFromFile(key);
    }
  }

  // --- File-based fallback ---

  Future<File> _getFallbackFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/.secure_store.json');
  }

  Future<Map<String, String>> _loadFileStore() async {
    if (_fileCache != null) return _fileCache!;

    final file = await _getFallbackFile();
    if (file.existsSync()) {
      final content = await file.readAsString();
      _fileCache = Map<String, String>.from(jsonDecode(content) as Map);
    } else {
      _fileCache = {};
    }
    return _fileCache!;
  }

  Future<void> _saveFileStore(Map<String, String> store) async {
    final file = await _getFallbackFile();
    await file.writeAsString(jsonEncode(store));
    _fileCache = store;
  }

  Future<String?> _readFromFile(String key) async {
    final store = await _loadFileStore();
    final value = store[key];
    LoggerService.instance.info(_tag, 'file-read($key) → ${value != null ? "[SET]" : "null"}');
    return value;
  }

  Future<void> _writeToFile(String key, String value) async {
    final store = await _loadFileStore();
    store[key] = value;
    await _saveFileStore(store);
    LoggerService.instance.info(_tag, 'file-write($key) → OK (${value.length} chars)');
  }

  Future<void> _deleteFromFile(String key) async {
    final store = await _loadFileStore();
    store.remove(key);
    await _saveFileStore(store);
    LoggerService.instance.info(_tag, 'file-delete($key) → OK');
  }
}
