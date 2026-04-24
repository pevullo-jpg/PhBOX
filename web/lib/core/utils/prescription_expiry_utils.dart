import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

enum PrescriptionValidityStatus {
  expired,
  expiringSoon,
  valid,
  unknown,
}

class PrescriptionExpiryInfo {
  final PrescriptionValidityStatus status;
  final String label;
  final Color color;

  const PrescriptionExpiryInfo({
    required this.status,
    required this.label,
    required this.color,
  });
}

class PrescriptionExpiryUtils {
  static PrescriptionExpiryInfo evaluate(DateTime? expiryDate) {
    if (expiryDate == null) {
      return const PrescriptionExpiryInfo(
        status: PrescriptionValidityStatus.unknown,
        label: 'Senza scadenza',
        color: Color(0xFF2A2A2A),
      );
    }

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final int diffDays = expiry.difference(today).inDays;

    if (diffDays < 0) {
      return const PrescriptionExpiryInfo(
        status: PrescriptionValidityStatus.expired,
        label: 'Scaduta',
        color: AppColors.red,
      );
    }

    if (diffDays <= 7) {
      return const PrescriptionExpiryInfo(
        status: PrescriptionValidityStatus.expiringSoon,
        label: 'In scadenza',
        color: AppColors.amber,
      );
    }

    return const PrescriptionExpiryInfo(
      status: PrescriptionValidityStatus.valid,
      label: 'Valida',
      color: AppColors.green,
    );
  }
}
