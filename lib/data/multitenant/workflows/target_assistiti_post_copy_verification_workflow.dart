import '../mappers/legacy_to_target_assistito_mapper.dart';
import '../models/target_assistito.dart';
import '../models/target_multitenant_collections.dart';
import '../readers/target_assistiti_read_only_reader.dart';
import '../reports/legacy_target_assistito_batch_verification_report.dart';
import '../verifiers/legacy_target_assistito_verifier.dart';

class TargetAssistitiPostCopyVerificationBlocker {
  final String code;
  final String message;

  const TargetAssistitiPostCopyVerificationBlocker({
    required this.code,
    required this.message,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'code': code,
      'message': message,
    };
  }
}

class TargetAssistitiPostCopyUnmatchedTargetSummary {
  final String documentId;
  final String assistitoId;
  final String cf;
  final String fullName;
  final bool documentIdentityValid;

  const TargetAssistitiPostCopyUnmatchedTargetSummary({
    required this.documentId,
    required this.assistitoId,
    required this.cf,
    required this.fullName,
    required this.documentIdentityValid,
  });

  factory TargetAssistitiPostCopyUnmatchedTargetSummary.fromDocument(
    TargetAssistitiReadDocument document,
  ) {
    return TargetAssistitiPostCopyUnmatchedTargetSummary(
      documentId: document.documentId,
      assistitoId: document.assistito.assistitoId,
      cf: document.assistito.cf,
      fullName: document.assistito.fullName,
      documentIdentityValid: document.documentIdentityValid,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'documentId': documentId,
      'assistitoId': assistitoId,
      'cf': cf,
      'fullName': fullName,
      'documentIdentityValid': documentIdentityValid,
    };
  }
}

class TargetAssistitiPostCopyVerificationResult {
  final String tenantId;
  final String expectedCollectionPath;
  final String targetCollectionPath;
  final int sourceCount;
  final int verifiedSourceCount;
  final int maxSourcesToVerify;
  final bool sourceLimitExceeded;
  final int duplicateSourceAssistitoIdCount;
  final int targetReadReturnedCount;
  final bool targetReadEmpty;
  final int unmatchedTargetDocumentCount;
  final int reportedUnmatchedTargetDocumentCount;
  final int maxReportedUnmatchedTargets;
  final bool unmatchedTargetsTruncated;
  final bool unmatchedTargetAccountingSuppressed;
  final List<TargetAssistitiPostCopyVerificationBlocker> blockers;
  final LegacyTargetAssistitoBatchVerificationReport report;
  final List<TargetAssistitiPostCopyUnmatchedTargetSummary> unmatchedTargets;

  const TargetAssistitiPostCopyVerificationResult({
    required this.tenantId,
    required this.expectedCollectionPath,
    required this.targetCollectionPath,
    required this.sourceCount,
    required this.verifiedSourceCount,
    required this.maxSourcesToVerify,
    required this.sourceLimitExceeded,
    required this.duplicateSourceAssistitoIdCount,
    required this.targetReadReturnedCount,
    required this.targetReadEmpty,
    required this.unmatchedTargetDocumentCount,
    required this.reportedUnmatchedTargetDocumentCount,
    required this.maxReportedUnmatchedTargets,
    required this.unmatchedTargetsTruncated,
    required this.unmatchedTargetAccountingSuppressed,
    required this.blockers,
    required this.report,
    required this.unmatchedTargets,
  });

  bool get blocked => blockers.isNotEmpty;
  bool get allVerified {
    return !blocked &&
        !sourceLimitExceeded &&
        duplicateSourceAssistitoIdCount == 0 &&
        unmatchedTargetDocumentCount == 0 &&
        !unmatchedTargetAccountingSuppressed &&
        report.allVerified;
  }

  bool get hasIssues => !allVerified;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tenantId': tenantId,
      'expectedCollectionPath': expectedCollectionPath,
      'targetCollectionPath': targetCollectionPath,
      'sourceCount': sourceCount,
      'verifiedSourceCount': verifiedSourceCount,
      'maxSourcesToVerify': maxSourcesToVerify,
      'sourceLimitExceeded': sourceLimitExceeded,
      'duplicateSourceAssistitoIdCount': duplicateSourceAssistitoIdCount,
      'targetReadReturnedCount': targetReadReturnedCount,
      'targetReadEmpty': targetReadEmpty,
      'unmatchedTargetDocumentCount': unmatchedTargetDocumentCount,
      'reportedUnmatchedTargetDocumentCount': reportedUnmatchedTargetDocumentCount,
      'maxReportedUnmatchedTargets': maxReportedUnmatchedTargets,
      'unmatchedTargetsTruncated': unmatchedTargetsTruncated,
      'unmatchedTargetAccountingSuppressed': unmatchedTargetAccountingSuppressed,
      'blocked': blocked,
      'allVerified': allVerified,
      'hasIssues': hasIssues,
      'blockers': blockers
          .map((TargetAssistitiPostCopyVerificationBlocker blocker) => blocker.toMap())
          .toList(growable: false),
      'report': report.toMap(),
      'unmatchedTargets': unmatchedTargets
          .map((TargetAssistitiPostCopyUnmatchedTargetSummary target) => target.toMap())
          .toList(growable: false),
    };
  }
}

class TargetAssistitiPostCopyVerificationWorkflow {
  static const int defaultMaxSourcesToVerify = 20;
  static const int hardMaxSourcesToVerify = 50;
  static const int defaultMaxReportedIssues = 20;
  static const int defaultMaxReportedMismatchesPerIssue = 5;
  static const int defaultMaxReportedUnmatchedTargets = 10;

  final LegacyToTargetAssistitoMapper mapper;
  final LegacyTargetAssistitoVerifier verifier;

  const TargetAssistitiPostCopyVerificationWorkflow({
    this.mapper = const LegacyToTargetAssistitoMapper(),
    this.verifier = const LegacyTargetAssistitoVerifier(),
  });

  TargetAssistitiPostCopyVerificationResult verify({
    required String tenantId,
    required Iterable<LegacyAssistitoSourceBundle> sources,
    required TargetAssistitiReadOnlyResult targetReadResult,
    int maxSourcesToVerify = defaultMaxSourcesToVerify,
    int maxReportedIssues = defaultMaxReportedIssues,
    int maxReportedMismatchesPerIssue = defaultMaxReportedMismatchesPerIssue,
    int maxReportedUnmatchedTargets = defaultMaxReportedUnmatchedTargets,
  }) {
    final String normalizedTenantId = _normalizeTenantId(tenantId);
    final int safeSourceLimit = _validateLimit(
      maxSourcesToVerify,
      label: 'maxSourcesToVerify',
      hardCap: hardMaxSourcesToVerify,
    );
    final int safeIssueLimit = _safeLimit(maxReportedIssues);
    final int safeMismatchLimit = _safeLimit(maxReportedMismatchesPerIssue);
    final int safeUnmatchedTargetLimit = _safeLimit(maxReportedUnmatchedTargets);
    final String expectedCollectionPath = TargetMultitenantCollections.tenantCollection(
      tenantId: normalizedTenantId,
      collectionId: TargetMultitenantCollections.assistiti,
    );
    final String targetCollectionPath = targetReadResult.collectionPath.trim();

    int sourceCount = 0;
    int duplicateSourceAssistitoIdCount = 0;
    bool sourceLimitExceeded = false;
    final Set<String> expectedAssistitoIds = <String>{};
    final List<LegacyTargetAssistitoVerificationInput> inputs =
        <LegacyTargetAssistitoVerificationInput>[];
    final List<TargetAssistitiPostCopyVerificationBlocker> blockers =
        <TargetAssistitiPostCopyVerificationBlocker>[];

    if (targetReadResult.tenantId.trim() != normalizedTenantId) {
      blockers.add(
        TargetAssistitiPostCopyVerificationBlocker(
          code: 'target_read_tenant_mismatch',
          message: 'Il risultato target letto appartiene a un tenant diverso da $normalizedTenantId.',
        ),
      );
    }

    if (targetCollectionPath != expectedCollectionPath) {
      blockers.add(
        TargetAssistitiPostCopyVerificationBlocker(
          code: 'target_collection_path_mismatch',
          message: 'Il risultato target non proviene da $expectedCollectionPath.',
        ),
      );
    }

    if (targetReadResult.returnedCount != targetReadResult.documents.length) {
      blockers.add(
        const TargetAssistitiPostCopyVerificationBlocker(
          code: 'target_returned_count_mismatch',
          message: 'Conteggio documenti target incoerente con la lista bounded fornita.',
        ),
      );
    }

    final Map<String, TargetAssistitiReadDocument> targetsByDocumentId =
        <String, TargetAssistitiReadDocument>{};
    for (final TargetAssistitiReadDocument document in targetReadResult.documents) {
      targetsByDocumentId[document.documentId.trim()] = document;
    }

    for (final LegacyAssistitoSourceBundle source in sources) {
      sourceCount += 1;
      if (sourceCount > safeSourceLimit) {
        sourceLimitExceeded = true;
        break;
      }

      final TargetAssistito expected = mapper.map(source);
      if (!expectedAssistitoIds.add(expected.assistitoId)) {
        duplicateSourceAssistitoIdCount += 1;
        continue;
      }

      final TargetAssistitiReadDocument? target = targetsByDocumentId[expected.assistitoId];
      inputs.add(
        LegacyTargetAssistitoVerificationInput(
          legacy: source,
          targetDocumentId: target?.documentId ?? expected.assistitoId,
          targetData: target?.assistito.toMap(),
        ),
      );
    }

    if (sourceLimitExceeded) {
      blockers.add(
        TargetAssistitiPostCopyVerificationBlocker(
          code: 'source_limit_exceeded',
          message: 'Batch verifica troppo ampio: massimo $safeSourceLimit assistiti.',
        ),
      );
    }

    if (duplicateSourceAssistitoIdCount > 0) {
      blockers.add(
        const TargetAssistitiPostCopyVerificationBlocker(
          code: 'duplicate_source_assistito_id',
          message: 'Sono presenti assistitoId duplicati tra le sorgenti legacy da verificare.',
        ),
      );
    }

    final LegacyTargetAssistitoBatchVerificationReport report =
        LegacyTargetAssistitoBatchVerificationReport.fromInputs(
      inputs: inputs,
      verifier: verifier,
      maxReportedIssues: safeIssueLimit,
      maxReportedMismatchesPerIssue: safeMismatchLimit,
    );

    final List<TargetAssistitiPostCopyUnmatchedTargetSummary> unmatchedTargets =
        <TargetAssistitiPostCopyUnmatchedTargetSummary>[];
    int unmatchedTargetDocumentCount = 0;
    bool unmatchedTargetsTruncated = false;
    final bool unmatchedTargetAccountingSuppressed = sourceLimitExceeded;

    if (!unmatchedTargetAccountingSuppressed) {
      for (final TargetAssistitiReadDocument target in targetReadResult.documents) {
        if (expectedAssistitoIds.contains(target.documentId.trim())) {
          continue;
        }
        unmatchedTargetDocumentCount += 1;
        if (unmatchedTargets.length >= safeUnmatchedTargetLimit) {
          unmatchedTargetsTruncated = true;
          continue;
        }
        unmatchedTargets.add(
          TargetAssistitiPostCopyUnmatchedTargetSummary.fromDocument(target),
        );
      }
    }

    return TargetAssistitiPostCopyVerificationResult(
      tenantId: normalizedTenantId,
      expectedCollectionPath: expectedCollectionPath,
      targetCollectionPath: targetCollectionPath,
      sourceCount: sourceCount,
      verifiedSourceCount: inputs.length,
      maxSourcesToVerify: safeSourceLimit,
      sourceLimitExceeded: sourceLimitExceeded,
      duplicateSourceAssistitoIdCount: duplicateSourceAssistitoIdCount,
      targetReadReturnedCount: targetReadResult.returnedCount,
      targetReadEmpty: targetReadResult.empty,
      unmatchedTargetDocumentCount: unmatchedTargetDocumentCount,
      reportedUnmatchedTargetDocumentCount: unmatchedTargets.length,
      maxReportedUnmatchedTargets: safeUnmatchedTargetLimit,
      unmatchedTargetsTruncated: unmatchedTargetsTruncated,
      unmatchedTargetAccountingSuppressed: unmatchedTargetAccountingSuppressed,
      blockers: List<TargetAssistitiPostCopyVerificationBlocker>.unmodifiable(blockers),
      report: report,
      unmatchedTargets:
          List<TargetAssistitiPostCopyUnmatchedTargetSummary>.unmodifiable(unmatchedTargets),
    );
  }

  static String _normalizeTenantId(String value) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'tenantId', 'tenantId obbligatorio per verifica post-copia.');
    }
    if (normalized.contains('/')) {
      throw ArgumentError.value(value, 'tenantId', 'tenantId con slash non valido.');
    }
    return normalized;
  }

  static int _validateLimit(
    int value, {
    required String label,
    required int hardCap,
  }) {
    if (value <= 0) {
      throw ArgumentError.value(value, label, 'Limite non positivo non valido.');
    }
    if (value > hardCap) {
      throw ArgumentError.value(value, label, 'Limite superiore al cap hard di $hardCap.');
    }
    return value;
  }

  static int _safeLimit(int value) {
    if (value < 0) {
      return 0;
    }
    return value;
  }
}
