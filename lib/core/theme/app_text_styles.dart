import 'package:flutter/material.dart';

/// Tipografia do Dart Oráculo.
/// Três famílias: display serifada, corpo sans, técnica mono.
/// Cores NÃO definidas aqui — vêm do Theme (textTheme) para suportar light/dark.
class AppTextStyles {
  AppTextStyles._();

  // Display — serifada, títulos e nome do app
  static const TextStyle displayLarge = TextStyle(
    fontFamily: 'DisplayFont',
    fontSize: 48,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.0,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: 'DisplayFont',
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  // Corpo — sans geométrica, texto geral
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: 'BodyFont',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: 'BodyFont',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: 'BodyFont',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );

  // Técnica — mono, metadados e citações
  static const TextStyle techMedium = TextStyle(
    fontFamily: 'TechFont',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
  );

  static const TextStyle techSmall = TextStyle(
    fontFamily: 'TechFont',
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.3,
  );
}
