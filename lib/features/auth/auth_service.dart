import 'package:local_auth/local_auth.dart';

import '../../core/services/secure_storage_service.dart';

/// Resultado da tentativa de autenticação.
enum AuthResult {
  success,
  failed,
  notAvailable,
  notConfigured,
}

/// Serviço de autenticação local via biometria ou senha do sistema.
class AuthService {
  AuthService({
    required SecureStorageService storageService,
    LocalAuthentication? localAuth,
  })  : _storageService = storageService,
        _localAuth = localAuth ?? LocalAuthentication();

  final SecureStorageService _storageService;
  final LocalAuthentication _localAuth;

  /// Verifica se biometria está disponível no dispositivo.
  Future<bool> isBiometricAvailable() async {
    final canCheck = await _localAuth.canCheckBiometrics;
    final isSupported = await _localAuth.isDeviceSupported();
    return canCheck || isSupported;
  }

  /// Verifica se o usuário habilitou exigência de biometria.
  Future<bool> isBiometricRequired() =>
      _storageService.isBiometricEnabled();

  /// Tenta autenticar o usuário.
  /// Retorna [AuthResult.notConfigured] se biometria não está habilitada nas settings.
  /// Retorna [AuthResult.notAvailable] se o dispositivo não suporta.
  Future<AuthResult> authenticate() async {
    final isRequired = await _storageService.isBiometricEnabled();
    if (!isRequired) return AuthResult.notConfigured;

    final isAvailable = await isBiometricAvailable();
    if (!isAvailable) return AuthResult.notAvailable;

    final didAuth = await _localAuth.authenticate(
      localizedReason: 'Autentique-se para acessar o Dart Oráculo',
      options: const AuthenticationOptions(
        stickyAuth: true,
        biometricOnly: false,
      ),
    );

    return didAuth ? AuthResult.success : AuthResult.failed;
  }
}
