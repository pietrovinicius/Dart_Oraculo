import 'package:flutter/material.dart';

/// Paleta de cores do Dart Oráculo.
/// Base escura com acento laranja, conforme design/design.md seção 3.
class AppColors {
  AppColors._();

  // Fundos
  static const Color background = Color(0xFF1A1A2E);
  static const Color surface = Color(0xFF16213E);
  static const Color surfaceLight = Color(0xFF0F3460);

  // Acento
  static const Color accent = Color(0xFFE94560);
  static const Color accentOrange = Color(0xFFFF6B35);

  // Texto
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textMuted = Color(0xFF6B6B6B);

  // Utilitários
  static const Color divider = Color(0xFF2A2A4A);
  static const Color error = Color(0xFFCF6679);
  static const Color success = Color(0xFF4CAF50);
}
