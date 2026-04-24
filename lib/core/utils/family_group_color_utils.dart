import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class FamilyGroupColorUtils {
  const FamilyGroupColorUtils._();

  static const List<Color> palette = <Color>[
    Color(0xFF2563EB),
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFFDC2626),
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
    Color(0xFF65A30D),
    Color(0xFFEA580C),
  ];

  static Color colorForIndex(int index) {
    if (palette.isEmpty) {
      return AppColors.yellow;
    }
    return palette[index % palette.length];
  }
}
