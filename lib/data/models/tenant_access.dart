class TenantAccess {
  final String loginEmail;
  final String tenantId;
  final String tenantName;
  final bool frontendEnabled;
  final String tenantStatus;
  final String subscriptionStatus;
  final DateTime? updatedAt;
  final String updatedBy;
  final int schemaVersion;

  const TenantAccess({
    required this.loginEmail,
    required this.tenantId,
    required this.tenantName,
    required this.frontendEnabled,
    required this.tenantStatus,
    required this.subscriptionStatus,
    required this.updatedAt,
    required this.updatedBy,
    required this.schemaVersion,
  });

  factory TenantAccess.fromMap(String documentId, Map<String, dynamic> data) {
    final String loginEmail = _readString(
      data['loginEmail'],
      fallback: _readString(data['pharmacyEmail'], fallback: documentId),
    ).toLowerCase();
    final String tenantId = _readString(data['tenantId']);
    return TenantAccess(
      loginEmail: loginEmail,
      tenantId: tenantId,
      tenantName: _readString(data['tenantName'], fallback: tenantId),
      frontendEnabled: _readBool(data['frontendEnabled'], fallback: false),
      tenantStatus: _readString(data['tenantStatus'], fallback: 'blocked'),
      subscriptionStatus: _readString(data['subscriptionStatus'], fallback: 'expired'),
      updatedAt: _readDateTime(data['updatedAt']),
      updatedBy: _readString(data['updatedBy']),
      schemaVersion: _readInt(data['schemaVersion'], fallback: 1),
    );
  }

  bool get isAllowed {
    return frontendEnabled &&
        tenantStatus == 'active' &&
        (subscriptionStatus == 'active' || subscriptionStatus == 'trial');
  }

  String get blockReason {
    if (tenantId.trim().isEmpty) {
      return 'Accesso tenant incompleto. Contatta il gestore PhBOX.';
    }
    if (!frontendEnabled) {
      return 'Frontend farmacia disabilitato dal SuperBack.';
    }
    if (tenantStatus != 'active') {
      return 'Tenant farmacia non attivo.';
    }
    if (subscriptionStatus != 'active' && subscriptionStatus != 'trial') {
      return 'Abbonamento non attivo.';
    }
    return 'Accesso non autorizzato.';
  }

  static String _readString(Object? value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return fallback;
  }

  static bool _readBool(Object? value, {required bool fallback}) {
    if (value is bool) {
      return value;
    }
    return fallback;
  }

  static int _readInt(Object? value, {required int fallback}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return fallback;
  }

  static DateTime? _readDateTime(Object? value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }
}
