import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Bolha de erro com botão de retry exibida quando a API falha.
class RetryBubble extends StatelessWidget {
  const RetryBubble({super.key, required this.onRetry, this.errorMessage});

  final VoidCallback onRetry;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomLeft: const Radius.circular(4),
          ),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Falha ao gerar resposta',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
            if (errorMessage != null && errorMessage!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                errorMessage!.length > 120
                    ? '${errorMessage!.substring(0, 120)}…'
                    : errorMessage!,
                style: AppTextStyles.bodySmall,
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              height: 32,
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text(
                  'Tentar novamente',
                  style: AppTextStyles.techSmall,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accentOrange,
                  side: const BorderSide(color: AppColors.accentOrange),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}