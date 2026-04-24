import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF0A0A0A);
  static const Color panel = Color(0xFF111111);
  static const Color panelSoft = Color(0xFF1A1A1A);
  static const Color yellow = Color(0xFFF6BE0F);
  static const Color coral = Color(0xFFE43D57);
  static const Color pink = Color(0xFFF1B7BD);
  static const Color wine = Color(0xFFB11434);
  static const Color green = Color(0xFF1E6B3A);
  static const Color amber = Color(0xFFA66B00);
  static const Color red = Color(0xFF8F1D1D);
}
class AppTheme {
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.yellow,
      brightness: Brightness.dark,
    ),
    fontFamily: 'Arial',
  );
}
