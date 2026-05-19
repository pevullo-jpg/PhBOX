import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF242424);
  static const Color panel = Color(0xFF2B2B2B);
  static const Color panelSoft = Color(0xFF333333);
  static const Color panelElevated = Color(0xFF3A3A3A);
  static const Color outlineSoft = Color(0xFF505050);
  static const Color textPrimary = Color(0xFFFAFAFA);
  static const Color textSecondary = Color(0xFFE0E0E0);
  static const Color textMuted = Color(0xFFB8B8B8);

  static const Color recipe = Color(0xFF22D39B);
  static const Color dpc = Color(0xFF3FA2FF);
  static const Color debt = Color(0xFFE36E84);
  static const Color advance = Color(0xFFF6C83A);
  static const Color booking = Color(0xFFB86CFF);
  static const Color expiry = Color(0xFFF09A48);

  static const Color yellow = advance;
  static const Color coral = dpc;
  static const Color pink = Color(0xFFF0B9C2);
  static const Color wine = debt;
  static const Color green = recipe;
  static const Color amber = advance;
  static const Color red = Color(0xFFE57373);
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
