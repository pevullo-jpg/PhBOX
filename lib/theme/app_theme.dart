import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF2B2B2B);
  static const Color panel = Color(0xFF303030);
  static const Color panelSoft = Color(0xFF383838);
  static const Color panelElevated = Color(0xFF3D3D3E);
  static const Color outlineSoft = Color(0xFF474747);
  static const Color textPrimary = Color(0xFFFAFAFA);
  static const Color textSecondary = Color(0xFFE0E0E0);
  static const Color textMuted = Color(0xFFB8B8B8);

  static const Color recipe = Color(0xFF1CBC8C);
  static const Color dpc = Color(0xFF3494EC);
  static const Color debt = Color(0xFFD8667A);
  static const Color advance = Color(0xFFF4BC1C);
  static const Color booking = Color(0xFFA45CE4);
  static const Color expiry = Color(0xFFE08A3E);

  static const Color yellow = advance;
  static const Color coral = Color(0xFFD8667A);
  static const Color pink = Color(0xFFF1B7BD);
  static const Color wine = debt;
  static const Color green = recipe;
  static const Color amber = advance;
  static const Color red = Color(0xFFD06B6B);
}

class AppTheme {
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.dpc,
      brightness: Brightness.dark,
    ).copyWith(
      surface: AppColors.panel,
      onSurface: AppColors.textPrimary,
      primary: AppColors.dpc,
      secondary: AppColors.recipe,
      tertiary: AppColors.booking,
      error: AppColors.red,
    ),
    fontFamily: 'Arial',
  );
}
