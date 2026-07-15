import 'package:dart_oraculo/core/services/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake in-memory implementation of FlutterSecureStorage for testing.
class FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _store[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _store[key] = value;
    } else {
      _store.remove(key);
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _store.remove(key);

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => Map.unmodifiable(_store);

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _store.clear();

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _store.containsKey(key);

  @override
  // ignore: override_on_non_overriding_member
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late SecureStorageService service;
  late FakeSecureStorage fakeStorage;

  setUp(() {
    fakeStorage = FakeSecureStorage();
    service = SecureStorageService.test(storage: fakeStorage);
  });

  group('SecureStorageService', () {
    group('API Key', () {
      test('retorna null quando não há chave armazenada', () async {
        final result = await service.getApiKey();
        expect(result, isNull);
      });

      test('hasApiKey retorna false quando vazio', () async {
        expect(await service.hasApiKey(), isFalse);
      });

      test('armazena e recupera chave', () async {
        await service.setApiKey('sk-ant-test-123');
        expect(await service.getApiKey(), equals('sk-ant-test-123'));
        expect(await service.hasApiKey(), isTrue);
      });

      test('deleta chave', () async {
        await service.setApiKey('sk-ant-test-123');
        await service.deleteApiKey();
        expect(await service.getApiKey(), isNull);
        expect(await service.hasApiKey(), isFalse);
      });
    });

    group('Default Model', () {
      test('retorna null quando não configurado', () async {
        expect(await service.getDefaultModel(), isNull);
      });

      test('armazena e recupera modelo', () async {
        await service.setDefaultModel('claude-sonnet-5-20250514');
        expect(
          await service.getDefaultModel(),
          equals('claude-sonnet-5-20250514'),
        );
      });
    });

    group('Biometric Toggle', () {
      test('retorna false por padrão', () async {
        expect(await service.isBiometricEnabled(), isFalse);
      });

      test('armazena true', () async {
        await service.setBiometricEnabled(true);
        expect(await service.isBiometricEnabled(), isTrue);
      });

      test('armazena false após true', () async {
        await service.setBiometricEnabled(true);
        await service.setBiometricEnabled(false);
        expect(await service.isBiometricEnabled(), isFalse);
      });
    });
  });
}
