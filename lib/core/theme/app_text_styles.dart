import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tipografia do Dart Oráculo.
/// Três famílias: display serifada, corpo sans, técnica mono.
class AppTextStyles {
  AppTextStyles._();

  // Display — serifada, títulos e nome do app
  static const TextStyle displayLarge = TextStyle(
    fontFamily: 'DisplayFont',
    fontSize: 48,
    fontWeight: FontWeight.w700,
    color: AppColors.accentOrange,
    letterSpacing: -1.0,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: 'DisplayFont',
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  // Corpo — sans geométrica, texto geral
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: 'BodyFont',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: 'BodyFont',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: 'BodyFont',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    height: 1.3,
  );

  // Técnica — mono, metadados e citações
  static const TextStyle techMedium = TextStyle(
    fontFamily: 'TechFont',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    letterSpacing: 0.5,
  );

  static const TextStyle techSmall = TextStyle(
    fontFamily: 'TechFont',
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    letterSpacing: 0.3,
  );
}
