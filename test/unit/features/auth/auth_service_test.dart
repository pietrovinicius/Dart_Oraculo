import 'package:dart_oraculo/core/services/secure_storage_service.dart';
import 'package:dart_oraculo/features/auth/auth_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

/// Fake LocalAuthentication para testes — usa noSuchMethod para evitar
/// dependência de tipos internos (AuthMessages) que não são exportados.
class FakeLocalAuth extends Fake implements LocalAuthentication {
  bool canCheckBiometricsValue = true;
  bool isDeviceSupportedValue = true;
  bool authenticateResult = true;

  @override
  Future<bool> get canCheckBiometrics async => canCheckBiometricsValue;

  @override
  Future<bool> isDeviceSupported() async => isDeviceSupportedValue;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    // ignore: always_specify_types
    dynamic authMessages = const [],
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async => authenticateResult;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async =>
      [BiometricType.fingerprint];

  @override
  Future<bool> stopAuthentication() async => true;
}

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
  late AuthService authService;
  late FakeLocalAuth fakeLocalAuth;
  late SecureStorageService storageService;

  setUp(() {
    fakeLocalAuth = FakeLocalAuth();
    storageService = SecureStorageService.test(storage: FakeSecureStorage());
    authService = AuthService(
      storageService: storageService,
      localAuth: fakeLocalAuth,
    );
  });

  group('AuthService', () {
    test('isBiometricAvailable retorna true quando dispositivo suporta',
        () async {
      fakeLocalAuth.canCheckBiometricsValue = true;
      fakeLocalAuth.isDeviceSupportedValue = true;
      expect(await authService.isBiometricAvailable(), isTrue);
    });

    test('isBiometricAvailable retorna false quando não suporta', () async {
      fakeLocalAuth.canCheckBiometricsValue = false;
      fakeLocalAuth.isDeviceSupportedValue = false;
      expect(await authService.isBiometricAvailable(), isFalse);
    });

    test('authenticate retorna notConfigured quando biometria desabilitada',
        () async {
      // biometric_enabled não foi setado → default false
      final result = await authService.authenticate();
      expect(result, equals(AuthResult.notConfigured));
    });

    test('authenticate retorna notAvailable quando dispositivo não suporta',
        () async {
      await storageService.setBiometricEnabled(true);
      fakeLocalAuth.canCheckBiometricsValue = false;
      fakeLocalAuth.isDeviceSupportedValue = false;

      final result = await authService.authenticate();
      expect(result, equals(AuthResult.notAvailable));
    });

    test('authenticate retorna success quando biometria passa', () async {
      await storageService.setBiometricEnabled(true);
      fakeLocalAuth.authenticateResult = true;

      final result = await authService.authenticate();
      expect(result, equals(AuthResult.success));
    });

    test('authenticate retorna failed quando biometria falha', () async {
      await storageService.setBiometricEnabled(true);
      fakeLocalAuth.authenticateResult = false;

      final result = await authService.authenticate();
      expect(result, equals(AuthResult.failed));
    });

    test('isBiometricRequired lê do storage', () async {
      expect(await authService.isBiometricRequired(), isFalse);
      await storageService.setBiometricEnabled(true);
      expect(await authService.isBiometricRequired(), isTrue);
    });
  });
}
