import 'package:cloud_firestore/cloud_firestore.dart';

import '../mappers/real_assistiti_migration_block_diagnostic_mapper.dart';
import 'real_assistiti_dry_run_preview_reader.dart';

class RealAssistitiMigrationAuditItem {
  final String cf;
  final String status;
  final bool copyable;
  final bool legacyFound;
  final bool targetDuplicateFound;
  final bool hasCanonicalPatient;
  final bool hasDashboardIndex;
  final bool hasTherapeuticAdvice;
  final bool hasDoctorManual;
  final bool hasDoctorPrimary;
  final int existingLegacySourceCount;
  final List<String> blockingReasons;
  final List<String> targetPreviewPayloadRootKeys;
  final List<RealAssistitiMigrationBlockDiagnostic> diagnostics;

  const RealAssistitiMigrationAuditItem({
    required this.cf,
    required this.status,
    required this.copyable,
    required this.legacyFound,
    required this.targetDuplicateFound,
    required this.hasCanonicalPatient,
    required this.hasDashboardIndex,
    required this.hasTherapeuticAdvice,
    required this.hasDoctorManual,
    required this.hasDoctorPrimary,
    required this.existingLegacySourceCount,
    required this.blockingReasons,
    required this.targetPreviewPayloadRootKeys,
    required this.diagnostics,
  });

  bool get blocked => status == 'blocked';

  bool get alreadyTarget => status == 'already_target';

  bool get hasDoctorData => hasDoctorManual || hasDoctorPrimary;

  bool get hasDiagnostics => diagnostics.isNotEmpty;

  factory RealAssistitiMigrationAuditItem.fromPreviewItem(
    RealAssistitiDryRunPreviewItem item,
  ) {
    final bool targetDuplicateFound = item.duplicateGuard.duplicateFound;
    final bool copyable = item.canProceedToManualCopyStep;
    final String status = copyable
        ? 'copyable'
        : targetDuplicateFound
            ? 'already_target'
            : 'blocked';

    final List<String> payloadRootKeys =
        item.targetPreviewPayloadWithoutAssistitoId.keys.toList(growable: false)..sort();
    final List<RealAssistitiMigrationBlockDiagnostic> diagnostics =
        RealAssistitiMigrationBlockDiagnosticMapper.buildItemDiagnostics(
      status: status,
      targetDuplicateFound: targetDuplicateFound,
      blockingReasons: item.blockingReasons,
    );

    return RealAssistitiMigrationAuditItem(
      cf: item.cf,
      status: status,
      copyable: copyable,
      legacyFound: item.legacyBundle.hasAnyLegacySource,
      targetDuplicateFound: targetDuplicateFound,
      hasCanonicalPatient: item.legacyBundle.patient.exists,
      hasDashboardIndex: item.legacyBundle.dashboardIndex.exists,
      hasTherapeuticAdvice: item.legacyBundle.therapeuticAdvice.exists,
      hasDoctorManual: item.legacyBundle.doctorManual.exists,
      hasDoctorPrimary: item.legacyBundle.doctorPrimary.exists,
      existingLegacySourceCount: item.legacyBundle.existingSourceCount,
      blockingReasons: List<String>.unmodifiable(item.blockingReasons),
      targetPreviewPayloadRootKeys: List<String>.unmodifiable(payloadRootKeys),
      diagnostics: List<RealAssistitiMigrationBlockDiagnostic>.unmodifiable(diagnostics),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'cf': cf,
      'status': status,
      'copyable': copyable,
      'blocked': blocked,
      'alreadyTarget': alreadyTarget,
      'legacyFound': legacyFound,
      'targetDuplicateFound': targetDuplicateFound,
      'hasCanonicalPatient': hasCanonicalPatient,
      'hasDashboardIndex': hasDashboardIndex,
      'hasTherapeuticAdvice': hasTherapeuticAdvice,
      'hasDoctorManual': hasDoctorManual,
      'hasDoctorPrimary': hasDoctorPrimary,
      'hasDoctorData': hasDoctorData,
      'existingLegacySourceCount': existingLegacySourceCount,
      'blockingReasons': blockingReasons,
      'targetPreviewPayloadRootKeys': targetPreviewPayloadRootKeys,
      'diagnostics': diagnostics
          .map((RealAssistitiMigrationBlockDiagnostic diagnostic) => diagnostic.toMap())
          .toList(growable: false),
    };
  }
}

class RealAssistitiMigrationAuditSummary {
  final int requestedCount;
  final int previewItemCount;
  final int copyableCount;
  final int blockedCount;
  final int alreadyTargetCount;
  final int legacyFoundCount;
  final int legacyMissingCount;
  final int canonicalPatientCount;
  final int dashboardIndexCount;
  final int therapeuticAdviceCount;
  final int doctorManualCount;
  final int doctorPrimaryCount;
  final int doctorAnyCount;
  final Map<String, int> blockingReasonCounts;
  final Map<String, int> diagnosticCodeCounts;

  const RealAssistitiMigrationAuditSummary({
    required this.requestedCount,
    required this.previewItemCount,
    required this.copyableCount,
    required this.blockedCount,
    required this.alreadyTargetCount,
    required this.legacyFoundCount,
    required this.legacyMissingCount,
    required this.canonicalPatientCount,
    required this.dashboardIndexCount,
    required this.therapeuticAdviceCount,
    required this.doctorManualCount,
    required this.doctorPrimaryCount,
    required this.doctorAnyCount,
    required this.blockingReasonCounts,
    required this.diagnosticCodeCounts,
  });

  bool get hasBlockedItems => blockedCount > 0;

  bool get hasCopyableItems => copyableCount > 0;

  bool get hasDiagnostics => diagnosticCodeCounts.isNotEmpty;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'requestedCount': requestedCount,
      'previewItemCount': previewItemCount,
      'copyableCount': copyableCount,
      'blockedCount': blockedCount,
      'alreadyTargetCount': alreadyTargetCount,
      'legacyFoundCount': legacyFoundCount,
      'legacyMissingCount': legacyMissingCount,
      'canonicalPatientCount': canonicalPatientCount,
      'dashboardIndexCount': dashboardIndexCount,
      'therapeuticAdviceCount': therapeuticAdviceCount,
      'doctorManualCount': doctorManualCount,
      'doctorPrimaryCount': doctorPrimaryCount,
      'doctorAnyCount': doctorAnyCount,
      'hasBlockedItems': hasBlockedItems,
      'hasCopyableItems': hasCopyableItems,
      'hasDiagnostics': hasDiagnostics,
      'blockingReasonCounts': blockingReasonCounts,
      'diagnosticCodeCounts': diagnosticCodeCounts,
    };
  }
}

class RealAssistitiMigrationAuditResult {
  final String tenantId;
  final List<String> requestedFiscalCodes;
  final List<RealAssistitiMigrationAuditItem> items;
  final RealAssistitiMigrationAuditSummary summary;
  final int maxFiscalCodes;
  final int legacyAttemptedDocumentReads;
  final int targetAttemptedQueries;

  const RealAssistitiMigrationAuditResult({
    required this.tenantId,
    required this.requestedFiscalCodes,
    required this.items,
    required this.summary,
    required this.maxFiscalCodes,
    required this.legacyAttemptedDocumentReads,
    required this.targetAttemptedQueries,
  });

  int get attemptedReadOperations => legacyAttemptedDocumentReads + targetAttemptedQueries;

  List<String> get copyableFiscalCodes {
    return List<String>.unmodifiable(
      items
          .where((RealAssistitiMigrationAuditItem item) => item.copyable)
          .map((RealAssistitiMigrationAuditItem item) => item.cf),
    );
  }

  List<String> get blockedFiscalCodes {
    return List<String>.unmodifiable(
      items
          .where((RealAssistitiMigrationAuditItem item) => item.blocked)
          .map((RealAssistitiMigrationAuditItem item) => item.cf),
    );
  }

  List<String> get alreadyTargetFiscalCodes {
    return List<String>.unmodifiable(
      items
          .where((RealAssistitiMigrationAuditItem item) => item.alreadyTarget)
          .map((RealAssistitiMigrationAuditItem item) => item.cf),
    );
  }

  factory RealAssistitiMigrationAuditResult.fromDryRunPreview(
    RealAssistitiDryRunPreviewResult dryRunPreview,
  ) {
    final List<RealAssistitiMigrationAuditItem> items = dryRunPreview.items
        .map(RealAssistitiMigrationAuditItem.fromPreviewItem)
        .toList(growable: false);
    final RealAssistitiMigrationAuditSummary summary = _buildSummary(
      requestedCount: dryRunPreview.requestedCount,
      items: items,
    );

    return RealAssistitiMigrationAuditResult(
      tenantId: dryRunPreview.tenantId,
      requestedFiscalCodes: List<String>.unmodifiable(dryRunPreview.requestedFiscalCodes),
      items: List<RealAssistitiMigrationAuditItem>.unmodifiable(items),
      summary: summary,
      maxFiscalCodes: dryRunPreview.maxFiscalCodes,
      legacyAttemptedDocumentReads: dryRunPreview.legacyAttemptedDocumentReads,
      targetAttemptedQueries: dryRunPreview.targetAttemptedQueries,
    );
  }

  static RealAssistitiMigrationAuditSummary _buildSummary({
    required int requestedCount,
    required List<RealAssistitiMigrationAuditItem> items,
  }) {
    int copyableCount = 0;
    int blockedCount = 0;
    int alreadyTargetCount = 0;
    int legacyFoundCount = 0;
    int canonicalPatientCount = 0;
    int dashboardIndexCount = 0;
    int therapeuticAdviceCount = 0;
    int doctorManualCount = 0;
    int doctorPrimaryCount = 0;
    int doctorAnyCount = 0;
    final Map<String, int> blockingReasonCounts = <String, int>{};
    final Map<String, int> diagnosticCodeCounts = <String, int>{};

    for (final RealAssistitiMigrationAuditItem item in items) {
      if (item.copyable) copyableCount++;
      if (item.blocked) {
        blockedCount++;
        for (final String reason in item.blockingReasons) {
          blockingReasonCounts[reason] = (blockingReasonCounts[reason] ?? 0) + 1;
        }
      }
      if (item.alreadyTarget) alreadyTargetCount++;
      if (item.legacyFound) legacyFoundCount++;
      if (item.hasCanonicalPatient) canonicalPatientCount++;
      if (item.hasDashboardIndex) dashboardIndexCount++;
      if (item.hasTherapeuticAdvice) therapeuticAdviceCount++;
      if (item.hasDoctorManual) doctorManualCount++;
      if (item.hasDoctorPrimary) doctorPrimaryCount++;
      if (item.hasDoctorData) doctorAnyCount++;
      for (final RealAssistitiMigrationBlockDiagnostic diagnostic in item.diagnostics) {
        diagnosticCodeCounts[diagnostic.code] = (diagnosticCodeCounts[diagnostic.code] ?? 0) + 1;
      }
    }

    return RealAssistitiMigrationAuditSummary(
      requestedCount: requestedCount,
      previewItemCount: items.length,
      copyableCount: copyableCount,
      blockedCount: blockedCount,
      alreadyTargetCount: alreadyTargetCount,
      legacyFoundCount: legacyFoundCount,
      legacyMissingCount: items.length - legacyFoundCount,
      canonicalPatientCount: canonicalPatientCount,
      dashboardIndexCount: dashboardIndexCount,
      therapeuticAdviceCount: therapeuticAdviceCount,
      doctorManualCount: doctorManualCount,
      doctorPrimaryCount: doctorPrimaryCount,
      doctorAnyCount: doctorAnyCount,
      blockingReasonCounts: Map<String, int>.unmodifiable(blockingReasonCounts),
      diagnosticCodeCounts: Map<String, int>.unmodifiable(diagnosticCodeCounts),
    );
  }

  Map<String, dynamic> toMap() {
    final List<Map<String, dynamic>> mappedItems = <Map<String, dynamic>>[];
    for (final RealAssistitiMigrationAuditItem item in items) {
      mappedItems.add(item.toMap());
    }
    return <String, dynamic>{
      'tenantId': tenantId,
      'requestedFiscalCodes': requestedFiscalCodes,
      'maxFiscalCodes': maxFiscalCodes,
      'legacyAttemptedDocumentReads': legacyAttemptedDocumentReads,
      'targetAttemptedQueries': targetAttemptedQueries,
      'attemptedReadOperations': attemptedReadOperations,
      'copyableFiscalCodes': copyableFiscalCodes,
      'blockedFiscalCodes': blockedFiscalCodes,
      'alreadyTargetFiscalCodes': alreadyTargetFiscalCodes,
      'summary': summary.toMap(),
      'items': mappedItems,
    };
  }
}

class RealAssistitiMigrationAuditReader {
  final FirebaseFirestore firestore;

  const RealAssistitiMigrationAuditReader({
    required this.firestore,
  });

  Future<RealAssistitiMigrationAuditResult> auditByManualFiscalCodes({
    required String tenantId,
    required Iterable<String> fiscalCodes,
  }) async {
    final RealAssistitiDryRunPreviewReader previewReader = RealAssistitiDryRunPreviewReader(
      firestore: firestore,
    );
    final RealAssistitiDryRunPreviewResult dryRunPreview =
        await previewReader.previewByManualFiscalCodes(
      tenantId: tenantId,
      fiscalCodes: fiscalCodes,
    );
    return RealAssistitiMigrationAuditResult.fromDryRunPreview(dryRunPreview);
  }
}
