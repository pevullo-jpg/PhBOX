import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../session/phbox_frontend_access.dart';

class FrontendAccessResolutionException implements Exception {
  final String message;

  const FrontendAccessResolutionException(this.message);

  @override
  String toString() => message;
}

class FrontendAccessService {
  final FirebaseFirestore firestore;

  const FrontendAccessService({required this.firestore});

  Future<PhboxFrontendAccess> resolveForUser(User user) async {
    final String normalizedEmail = _normalizeEmail(user.email);
    if (normalizedEmail.isEmpty) {
      throw const FrontendAccessResolutionException(
        'Utente autenticato senza email valida.',
      );
    }

    final DocumentSnapshot<Map<String, dynamic>> accessSnapshot =
        await firestore.collection('tenant_access').doc(normalizedEmail).get();
    final Map<String, dynamic>? accessData = accessSnapshot.data();
    if (accessData == null) {
      throw const FrontendAccessResolutionException(
        'Accesso frontend non configurato in tenant_access.',
      );
    }

    final String tenantId = _readString(accessData['tenantId']);
    if (tenantId.isEmpty) {
      throw const FrontendAccessResolutionException(
        'tenant_access privo di tenantId.',
      );
    }

    final DocumentSnapshot<Map<String, dynamic>> tenantSnapshot =
        await firestore.collection('tenants_public').doc(tenantId).get();
    final Map<String, dynamic>? tenantData = tenantSnapshot.data();

    final Map<String, dynamic> merged = <String, dynamic>{
      ...accessData,
      if (tenantData != null) ...tenantData,
    };

    return PhboxFrontendAccess(
      tenantId: tenantId,
      tenantName: _readString(merged['tenantName']),
      pharmacyEmail: _readString(merged['pharmacyEmail']).isEmpty
          ? normalizedEmail
          : _readString(merged['pharmacyEmail']),
      frontendEnabled: _readBool(merged['frontendEnabled'], defaultValue: false),
      tenantStatus: _readString(merged['tenantStatus']).isEmpty
          ? 'active'
          : _readString(merged['tenantStatus']),
      subscriptionStatus: _readString(merged['subscriptionStatus']).isEmpty
          ? 'trial'
          : _readString(merged['subscriptionStatus']),
      dataRootPath: _readString(merged['dataRootPath']),
    );
  }

  String _normalizeEmail(String? value) {
    return (value ?? '').trim().toLowerCase();
  }

  String _readString(dynamic value) {
    if (value == null) {
      return '';
    }
    return value.toString().trim();
  }

  bool _readBool(dynamic value, {required bool defaultValue}) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      final String normalized = value.trim().toLowerCase();
      if (normalized == 'true') {
        return true;
      }
      if (normalized == 'false') {
        return false;
      }
    }
    return defaultValue;
  }
}
