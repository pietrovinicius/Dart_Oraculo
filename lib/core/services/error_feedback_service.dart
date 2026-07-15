import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Serviço centralizado para exibir feedback de erro ao usuário.
/// Garante consistência de UX e facilita testes.
class ErrorFeedbackService {
  ErrorFeedbackService._(); // Prevent instantiation

  static const _duration = Duration(seconds: 4);

  /// Exibe erro genérico via SnackBar.
  static void showError(
    BuildContext context,
    String title,
    String message,
  ) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title: $message'),
        backgroundColor: AppColors.error,
        duration: _duration,
      ),
    );
  }

  /// Exibe aviso via SnackBar (amarelo).
  static void showWarning(
    BuildContext context,
    String message,
  ) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFFFA500), // Orange
        duration: _duration,
      ),
    );
  }

  /// Exibe erro crítico via AlertDialog modal.
  static void showCriticalError(
    BuildContext context,
    String message,
  ) {
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Erro Crítico'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}