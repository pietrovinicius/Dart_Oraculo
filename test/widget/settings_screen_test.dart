import 'package:dart_oraculo/core/config/app_config.dart';
import 'package:dart_oraculo/core/services/secure_storage_service.dart';
import 'package:dart_oraculo/features/settings/settings_controller.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake SecureStorage in-memory.
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late SettingsController controller;
  late SecureStorageService storageService;

  setUp(() {
    storageService = SecureStorageService(storage: FakeSecureStorage());
    controller = SettingsController(storageService: storageService);
  });

  tearDown(() {
    controller.dispose();
  });

  group('SettingsController', () {
    test('load carrega valores padrão quando storage vazio', () async {
      await controller.load();

      expect(controller.apiKey, isEmpty);
      expect(controller.selectedModel, equals(AppConfig.defaultModel));
      expect(controller.biometricEnabled, isFalse);
      expect(controller.isLoading, isFalse);
      expect(controller.hasApiKey, isFalse);
    });

    test('saveApiKey persiste e atualiza estado', () async {
      await controller.load();
      await controller.saveApiKey('sk-ant-test-123');

      expect(controller.apiKey, equals('sk-ant-test-123'));
      expect(controller.hasApiKey, isTrue);

      // Verifica que persiste no storage
      expect(await storageService.getApiKey(), equals('sk-ant-test-123'));
    });

    test('saveModel persiste e atualiza estado', () async {
      await controller.load();
      await controller.saveModel(AppConfig.modelOpus);

      expect(controller.selectedModel, equals(AppConfig.modelOpus));
      expect(await storageService.getDefaultModel(), equals(AppConfig.modelOpus));
    });

    test('saveBiometric persiste e atualiza estado', () async {
      await controller.load();
      await controller.saveBiometric(true);

      expect(controller.biometricEnabled, isTrue);
      expect(await storageService.isBiometricEnabled(), isTrue);
    });

    test('deleteApiKey remove chave e atualiza estado', () async {
      await controller.load();
      await controller.saveApiKey('sk-to-delete');
      await controller.deleteApiKey();

      expect(controller.apiKey, isEmpty);
      expect(controller.hasApiKey, isFalse);
      expect(await storageService.getApiKey(), isNull);
    });

    test('load carrega valores previamente salvos', () async {
      await storageService.setApiKey('sk-existing');
      await storageService.setDefaultModel(AppConfig.modelOpus);
      await storageService.setBiometricEnabled(true);

      await controller.load();

      expect(controller.apiKey, equals('sk-existing'));
      expect(controller.selectedModel, equals(AppConfig.modelOpus));
      expect(controller.biometricEnabled, isTrue);
    });

    test('notifica listeners em cada mudança', () async {
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      await controller.load(); // 2 notificações (loading=true, loading=false)
      await controller.saveApiKey('key');
      await controller.saveModel(AppConfig.modelOpus);
      await controller.saveBiometric(true);

      expect(notifyCount, equals(5)); // 2 load + 3 saves
    });
  });
}
