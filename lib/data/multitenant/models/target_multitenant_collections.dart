class TargetMultitenantCollections {
  static const String tenants = 'tenants';
  static const String appSettings = 'app_settings';
  static const String dashboardExpiringRecipes = 'dashboard_expiring_recipes';
  static const String dashboardTotals = 'dashboard_totals';
  static const String drivePdfImports = 'drive_pdf_imports';
  static const String phboxRuntime = 'phbox_runtime';
  static const String phboxRuntimeManifests = 'phbox_runtime_manifests';
  static const String phboxSignals = 'phbox_signals';
  static const String assistiti = 'assistiti';

  const TargetMultitenantCollections._();

  static String tenantRoot(String tenantId) {
    final String normalizedTenantId = _normalizeSegment(tenantId, label: 'tenantId');
    return '$tenants/$normalizedTenantId';
  }

  static String tenantCollection({
    required String tenantId,
    required String collectionId,
  }) {
    final String normalizedCollectionId = _normalizeSegment(collectionId, label: 'collectionId');
    return '${tenantRoot(tenantId)}/$normalizedCollectionId';
  }

  static String tenantDocument({
    required String tenantId,
    required String collectionId,
    required String documentId,
  }) {
    final String normalizedDocumentId = _normalizeSegment(documentId, label: 'documentId');
    return '${tenantCollection(tenantId: tenantId, collectionId: collectionId)}/$normalizedDocumentId';
  }

  static String assistitoDocument({
    required String tenantId,
    required String assistitoId,
  }) {
    return tenantDocument(
      tenantId: tenantId,
      collectionId: assistiti,
      documentId: assistitoId,
    );
  }

  static String _normalizeSegment(String value, {required String label}) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, label, 'Segmento vuoto non valido.');
    }
    if (normalized.contains('/')) {
      throw ArgumentError.value(value, label, 'Segmento con slash non valido.');
    }
    return normalized;
  }
}
