class TenantAccess {
  final String loginEmail;
  final String tenantId;
  final String tenantName;
  final bool frontendEnabled;
  final String tenantStatus;
  final String subscriptionStatus;
  final int schemaVersion;

  const TenantAccess({
    required this.loginEmail,
    required this.tenantId,
    required this.tenantName,
    required this.frontendEnabled,
    required this.tenantStatus,
    required this.subscriptionStatus,
    required this.schemaVersion,
  });

  factory TenantAccess.fromMap(Map<String, dynamic> map) {
    return TenantAccess(
      loginEmail: _readString(map['loginEmail']).toLowerCase(),
      tenantId: _readString(map['tenantId']),
      tenantName: _readString(map['tenantName']),
      frontendEnabled: map['frontendEnabled'] == true,
      tenantStatus: _readString(map['tenantStatus']).toLowerCase(),
      subscriptionStatus: _readString(map['subscriptionStatus']).toLowerCase(),
      schemaVersion: _readInt(map['schemaVersion']),
    );
  }

  bool get isAllowed {
    return frontendEnabled &&
        tenantStatus == 'active' &&
        (subscriptionStatus == 'active' || subscriptionStatus == 'trial');
  }

  String get deniedReason {
    if (!frontendEnabled) {
      return 'Frontend farmacia disabilitato dal SuperBack.';
    }
    if (tenantStatus != 'active') {
      return 'Tenant non attivo: $tenantStatus.';
    }
    if (subscriptionStatus != 'active' && subscriptionStatus != 'trial') {
      return 'Abbonamento non valido: $subscriptionStatus.';
    }
    return 'Accesso non consentito.';
  }

  static String _readString(Object? value) {
    if (value == null) {
      return '';
    }
    return value.toString().trim();
  }

  static int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
