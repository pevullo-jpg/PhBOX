import 'package:cloud_firestore/cloud_firestore.dart';

import '../mappers/real_assistiti_target_preview_mapper.dart';
import 'legacy_real_assistiti_bounded_reader.dart';
import 'target_assistiti_duplicate_guard_reader.dart';

class RealAssistitiDryRunPreviewRejectedException implements Exception {
  final String code;
  final String message;

  const RealAssistitiDryRunPreviewRejectedException({
    required this.code,
    required this.message,
  });

  @override
  String toString() {
    return 'RealAssistitiDryRunPreviewRejectedException($code): $message';
  }
}

class RealAssistitiDryRunPreviewItem {
  final String cf;
  final LegacyRealAssistitoReadBundle legacyBundle;
  final TargetAssistitiDuplicateGuardCheck duplicateGuard;
  final Map<String, dynamic> targetPreviewPayloadWithoutAssistitoId;
  final List<String> blockingReasons;
  final DateTime previewGeneratedAt;

  const RealAssistitiDryRunPreviewItem({
    required this.cf,
    required this.legacyBundle,
    required this.duplicateGuard,
    required this.targetPreviewPayloadWithoutAssistitoId,
    required this.blockingReasons,
    required this.previewGeneratedAt,
  });

  bool get blocked => blockingReasons.isNotEmpty;

  bool get canProceedToManualCopyStep => !blocked;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'cf': cf,
      'blocked': blocked,
      'canProceedToManualCopyStep': canProceedToManualCopyStep,
      'blockingReasons': blockingReasons,
      'requiresAutoIdAtCopyTime': true,
      'previewGeneratedAt': previewGeneratedAt,
      'targetPreviewPayloadWithoutAssistitoId': targetPreviewPayloadWithoutAssistitoId,
      'legacyBundle': legacyBundle.toMap(),
      'duplicateGuard': duplicateGuard.toMap(),
    };
  }
}

class RealAssistitiDryRunPreviewResult {
  final String tenantId;
  final List<String> requestedFiscalCodes;
  final List<RealAssistitiDryRunPreviewItem> items;
  final int maxFiscalCodes;
  final int legacyAttemptedDocumentReads;
  final int targetAttemptedQueries;

  const RealAssistitiDryRunPreviewResult({
    required this.tenantId,
    required this.requestedFiscalCodes,
    required this.items,
    required this.maxFiscalCodes,
    required this.legacyAttemptedDocumentReads,
    required this.targetAttemptedQueries,
  });

  int get requestedCount => requestedFiscalCodes.length;

  bool get hasBlockingIssues {
    for (final RealAssistitiDryRunPreviewItem item in items) {
      if (item.blocked) {
        return true;
      }
    }
    return false;
  }

  List<String> get blockedFiscalCodes {
    final List<String> blocked = <String>[];
    for (final RealAssistitiDryRunPreviewItem item in items) {
      if (item.blocked) {
        blocked.add(item.cf);
      }
    }
    return List<String>.unmodifiable(blocked);
  }

  Map<String, dynamic> toMap() {
    final List<Map<String, dynamic>> mappedItems = <Map<String, dynamic>>[];
    for (final RealAssistitiDryRunPreviewItem item in items) {
      mappedItems.add(item.toMap());
    }
    return <String, dynamic>{
      'tenantId': tenantId,
      'requestedFiscalCodes': requestedFiscalCodes,
      'requestedCount': requestedCount,
      'maxFiscalCodes': maxFiscalCodes,
      'legacyAttemptedDocumentReads': legacyAttemptedDocumentReads,
      'targetAttemptedQueries': targetAttemptedQueries,
      'hasBlockingIssues': hasBlockingIssues,
      'blockedFiscalCodes': blockedFiscalCodes,
      'items': mappedItems,
    };
  }
}

class RealAssistitiDryRunPreviewReader {
  static const int maxFiscalCodes = LegacyRealAssistitiBoundedReader.maxFiscalCodes;

  final FirebaseFirestore firestore;

  const RealAssistitiDryRunPreviewReader({
    required this.firestore,
  });

  Future<RealAssistitiDryRunPreviewResult> previewByManualFiscalCodes({
    required String tenantId,
    required Iterable<String> fiscalCodes,
  }) async {
    final String normalizedTenantId = _normalizeTenantId(tenantId);
    final LegacyRealAssistitiBoundedReader legacyReader = LegacyRealAssistitiBoundedReader(
      firestore: firestore,
    );
    final TargetAssistitiDuplicateGuardReader duplicateGuardReader =
        TargetAssistitiDuplicateGuardReader(firestore: firestore);

    final LegacyRealAssistitiBoundedReadResult legacyResult =
        await legacyReader.readByManualFiscalCodes(fiscalCodes: fiscalCodes);
    final TargetAssistitiDuplicateGuardResult duplicateGuardResult =
        await duplicateGuardReader.checkByManualFiscalCodes(
      tenantId: normalizedTenantId,
      fiscalCodes: legacyResult.requestedFiscalCodes,
    );

    final Map<String, TargetAssistitiDuplicateGuardCheck> duplicateChecksByCf =
        <String, TargetAssistitiDuplicateGuardCheck>{};
    for (final TargetAssistitiDuplicateGuardCheck check in duplicateGuardResult.checks) {
      duplicateChecksByCf[check.cf] = check;
    }

    final DateTime previewGeneratedAt = DateTime.now().toUtc();
    final List<RealAssistitiDryRunPreviewItem> items = <RealAssistitiDryRunPreviewItem>[];

    for (final LegacyRealAssistitoReadBundle bundle in legacyResult.bundles) {
      final TargetAssistitiDuplicateGuardCheck? duplicateGuard = duplicateChecksByCf[bundle.cf];
      if (duplicateGuard == null) {
        throw RealAssistitiDryRunPreviewRejectedException(
          code: 'target_duplicate_guard_missing_result',
          message: 'Duplicate guard target assente per CF ${bundle.cf}.',
        );
      }
      items.add(_buildPreviewItem(
        bundle: bundle,
        duplicateGuard: duplicateGuard,
        previewGeneratedAt: previewGeneratedAt,
      ));
    }

    return RealAssistitiDryRunPreviewResult(
      tenantId: normalizedTenantId,
      requestedFiscalCodes: legacyResult.requestedFiscalCodes,
      items: List<RealAssistitiDryRunPreviewItem>.unmodifiable(items),
      maxFiscalCodes: maxFiscalCodes,
      legacyAttemptedDocumentReads: legacyResult.attemptedDocumentReads,
      targetAttemptedQueries: duplicateGuardResult.attemptedQueries,
    );
  }

  RealAssistitiDryRunPreviewItem _buildPreviewItem({
    required LegacyRealAssistitoReadBundle bundle,
    required TargetAssistitiDuplicateGuardCheck duplicateGuard,
    required DateTime previewGeneratedAt,
  }) {
    final List<String> blockingReasons = <String>[];

    if (!bundle.hasAnyLegacySource) {
      blockingReasons.add('legacy_source_missing');
    }
    if (duplicateGuard.duplicateFound) {
      blockingReasons.add('target_cf_duplicate');
    }

    final RealAssistitiResolvedIdentity identity =
        RealAssistitiTargetPreviewMapper.resolveIdentity(
      cf: bundle.cf,
      patientData: bundle.patient.rawData,
      dashboardIndexData: bundle.dashboardIndex.rawData,
      therapeuticAdviceData: bundle.therapeuticAdvice.rawData,
    );
    if (!identity.hasAnyAcceptedIdentityAnchor) {
      blockingReasons.add('target_identity_absent');
    }

    final List<Map<String, dynamic>> timestampSources = <Map<String, dynamic>>[
      bundle.patient.rawData,
      bundle.dashboardIndex.rawData,
      bundle.therapeuticAdvice.rawData,
    ];
    final DateTime createdAt = RealAssistitiTargetPreviewMapper.resolveTimestamp(
      sources: timestampSources,
      candidateKeys: const <String>['createdAt', 'creationTime', 'importedAt', 'firstSeenAt'],
      fallback: previewGeneratedAt,
    );
    final DateTime updatedAt = RealAssistitiTargetPreviewMapper.resolveTimestamp(
      sources: timestampSources,
      candidateKeys: const <String>['updatedAt', 'lastUpdatedAt', 'modifiedAt', 'lastSeenAt'],
      fallback: previewGeneratedAt,
    );

    final Map<String, dynamic> targetPreviewPayload = <String, dynamic>{
      'cf': bundle.cf,
      'fullName': identity.fullName,
      'cognome': identity.cognome,
      'nome': identity.nome,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'dashboard': RealAssistitiTargetPreviewMapper.buildDashboardSnapshot(
        dashboardIndexData: bundle.dashboardIndex.rawData,
        identity: identity,
      ),
      'nameSplitConfidence': identity.nameSplitConfidence,
      'searchPrefixes': RealAssistitiTargetPreviewMapper.buildSearchPrefixes(identity.fullName),
      'doctor': RealAssistitiTargetPreviewMapper.buildDoctorPreview(
        doctorManualData: bundle.doctorManual.rawData,
        doctorPrimaryData: bundle.doctorPrimary.rawData,
        identity: identity,
      ),
      'therapeuticAdvice': RealAssistitiTargetPreviewMapper.buildTherapeuticAdvicePreview(
        therapeuticAdviceData: bundle.therapeuticAdvice.rawData,
        identity: identity,
      ),
    };

    return RealAssistitiDryRunPreviewItem(
      cf: bundle.cf,
      legacyBundle: bundle,
      duplicateGuard: duplicateGuard,
      targetPreviewPayloadWithoutAssistitoId: Map<String, dynamic>.unmodifiable(targetPreviewPayload),
      blockingReasons: List<String>.unmodifiable(blockingReasons),
      previewGeneratedAt: previewGeneratedAt,
    );
  }

  static String _normalizeTenantId(String value) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw const RealAssistitiDryRunPreviewRejectedException(
        code: 'tenant_id_empty',
        message: 'tenantId obbligatorio per dry-run reale assistiti.',
      );
    }
    if (normalized.contains('/')) {
      throw const RealAssistitiDryRunPreviewRejectedException(
        code: 'tenant_id_not_canonical',
        message: 'tenantId non canonico: slash non ammesso.',
      );
    }
    return normalized;
  }
}
