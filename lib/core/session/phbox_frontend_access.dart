class PhboxFrontendAccess {
  final String tenantId;
  final String tenantName;
  final String pharmacyEmail;
  final bool frontendEnabled;
  final String tenantStatus;
  final String subscriptionStatus;
  final String dataRootPath;

  const PhboxFrontendAccess({
    required this.tenantId,
    required this.tenantName,
    required this.pharmacyEmail,
    required this.frontendEnabled,
    required this.tenantStatus,
    required this.subscriptionStatus,
    required this.dataRootPath,
  });

  bool get canOpenFrontend => frontendEnabled && tenantStatus != 'blocked';

  String get denyReason {
    if (!frontendEnabled) {
      return 'Frontend disattivato da SUPERBACK.';
    }
    if (tenantStatus == 'blocked') {
      return 'Account farmacia bloccato da SUPERBACK.';
    }
    return 'Accesso non consentito.';
  }

  String get displayTenantLabel {
    if (tenantName.isNotEmpty) {
      return tenantName;
    }
    if (tenantId.isNotEmpty) {
      return tenantId;
    }
    return 'Tenant non configurato';
  }
}
