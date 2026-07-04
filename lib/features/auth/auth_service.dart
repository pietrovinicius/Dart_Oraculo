import 'package:local_auth/local_auth.dart';

import '../../core/services/logger_service.dart';
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

  static const _tag = 'AuthService';
  final SecureStorageService _storageService;
  final LocalAuthentication _localAuth;

  Future<bool> isBiometricAvailable() async {
    final canCheck = await _localAuth.canCheckBiometrics;
    final isSupported = await _localAuth.isDeviceSupported();
    LoggerService.instance.info(_tag, 'canCheckBiometrics=$canCheck, isDeviceSupported=$isSupported');
    return canCheck || isSupported;
  }

  Future<bool> isBiometricRequired() =>
      _storageService.isBiometricEnabled();

  Future<AuthResult> authenticate() async {
    LoggerService.instance.info(_tag, 'authenticate() chamado');

    final isRequired = await _storageService.isBiometricEnabled();
    if (!isRequired) {
      LoggerService.instance.info(_tag, 'Biometria não habilitada → notConfigured');
      return AuthResult.notConfigured;
    }

    final isAvailable = await isBiometricAvailable();
    if (!isAvailable) {
      LoggerService.instance.warn(_tag, 'Biometria não disponível no dispositivo');
      return AuthResult.notAvailable;
    }

    try {
      final didAuth = await _localAuth.authenticate(
        localizedReason: 'Autentique-se para acessar o Dart Oráculo',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
      final result = didAuth ? AuthResult.success : AuthResult.failed;
      LoggerService.instance.info(_tag, 'authenticate result=$result');
      return result;
    } catch (e, stack) {
      LoggerService.instance.error(_tag, 'Erro na autenticação', e, stack);
      return AuthResult.failed;
    }
  }
}
