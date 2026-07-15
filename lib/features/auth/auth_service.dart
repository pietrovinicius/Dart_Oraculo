import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/models/auth_result.dart';
import '../../core/services/logger_service.dart';
import '../../core/services/secure_storage_service.dart';

export '../../core/models/auth_result.dart';

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
    LoggerService.instance.info(
      _tag,
      'canCheckBiometrics=$canCheck, isDeviceSupported=$isSupported',
    );
    return canCheck || isSupported;
  }

  Future<bool> isBiometricRequired() =>
      _storageService.isBiometricEnabled();

  Future<AuthResult> authenticate() async {
    LoggerService.instance.info(_tag, 'authenticate() chamado');

    final isRequired = await _storageService.isBiometricEnabled();
    if (!isRequired) {
      LoggerService.instance.info(_tag, 'Biometria não habilitada');
      return AuthResult.failed(
        'Biometria não habilitada. Configure em Configurações.',
      );
    }

    final isAvailable = await isBiometricAvailable();
    if (!isAvailable) {
      LoggerService.instance.warn(
        _tag,
        'Biometria não disponível no dispositivo',
      );
      return AuthResult.failed(
        'Biometria não disponível neste dispositivo.',
      );
    }

    try {
      final didAuth = await _localAuth.authenticate(
        localizedReason: 'Autentique-se para acessar o Dart Oráculo',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
      if (didAuth) {
        LoggerService.instance.info(_tag, 'Autenticação bem-sucedida');
        return AuthResult.ok();
      } else {
        LoggerService.instance.info(_tag, 'Usuário cancelou autenticação');
        return AuthResult.failed('Autenticação cancelada.');
      }
    } on PlatformException catch (e) {
      LoggerService.instance.error(
        _tag,
        'PlatformException na autenticação: ${e.code}',
        e,
      );
      return AuthResult.fromException(e);
    } catch (e) {
      LoggerService.instance.error(
        _tag,
        'Erro desconhecido na autenticação',
        e,
      );
      return AuthResult.failed('Erro desconhecido na autenticação: $e');
    }
  }
}
