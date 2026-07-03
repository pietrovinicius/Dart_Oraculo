import 'package:flutter/material.dart';

import '../../core/config/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Tela de bloqueio com autenticação biométrica.
/// Implementação completa no Sprint 1.
class LockScreen extends StatelessWidget {
  const LockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Dart Oráculo',
              style: AppTextStyles.displayLarge,
            ),
            const SizedBox(height: 48),
            IconButton(
              icon: const Icon(
                Icons.fingerprint,
                size: 64,
                color: AppColors.accentOrange,
              ),
              onPressed: () {
                // TODO: integrar local_auth (Sprint 1)
                Navigator.pushReplacementNamed(context, AppRoutes.home);
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Toque para desbloquear',
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
