import 'package:flutter/services.dart';

/// Resultado da autenticação com mensagem de diagnóstico.
class AuthResult {
  const AuthResult({
    required this.success,
    this.message,
  });

  final bool success;
  final String? message;

  /// Autenticação bem-sucedida.
  factory AuthResult.ok() => const AuthResult(success: true);

  /// Autenticação falhou com mensagem explicativa.
  factory AuthResult.failed(String message) => AuthResult(
        success: false,
        message: message,
      );

  /// Converte PlatformException em AuthResult com mensagem localizada.
  factory AuthResult.fromException(Exception e) {
    final code = _platformCode(e);
    final msg = _messageForPlatformCode(code);
    return AuthResult.failed(msg);
  }

  static String _platformCode(Exception e) {
    if (e is PlatformException) {
      return e.code;
    }
    return 'unknown';
  }

  static String _messageForPlatformCode(String code) {
    switch (code) {
      case 'NotAvailable':
        return 'Biometria não disponível neste dispositivo.';
      case 'NotEnrolled':
        return 'Nenhuma biometria cadastrada. Adicione no sistema.';
      case 'LockedOut':
        return 'Muitas tentativas. Tente novamente em alguns minutos.';
      case 'PermanentlyLockedOut':
        return 'Muitas tentativas. Desbloqueie manualmente no sistema.';
      case 'UserCanceled':
        return 'Autenticação cancelada.';
      default:
        return 'Falha na autenticação: $code';
    }
  }

  @override
  String toString() => 'AuthResult(success=$success, message=$message)';
}
