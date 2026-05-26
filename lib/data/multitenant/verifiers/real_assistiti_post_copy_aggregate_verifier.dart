import 'real_assistiti_post_copy_verifier.dart';

class RealAssistitiPostCopyAggregateItem {
  final String cf;
  final String documentId;
  final String documentPath;
  final bool verified;
  final List<String> mismatchReasons;
  final bool targetDocumentExists;
  final bool cfLockDocumentExists;
  final bool targetCfMatches;
  final bool targetAssistitoIdMatches;
  final bool targetIdentityAnchorPresent;
  final bool cfLockCfMatches;
  final bool cfLockAssistitoIdMatches;
  final bool cfLockAssistitoPathMatches;
  final bool payloadMatchesExpected;

  const RealAssistitiPostCopyAggregateItem({
    required this.cf,
    required this.documentId,
    required this.documentPath,
    required this.verified,
    required this.mismatchReasons,
    required this.targetDocumentExists,
    required this.cfLockDocumentExists,
    required this.targetCfMatches,
    required this.targetAssistitoIdMatches,
    required this.targetIdentityAnchorPresent,
    required this.cfLockCfMatches,
    required this.cfLockAssistitoIdMatches,
    required this.cfLockAssistitoPathMatches,
    required this.payloadMatchesExpected,
  });

  bool get failed => !verified;

  factory RealAssistitiPostCopyAggregateItem.fromDetailedItem(
    RealAssistitiPostCopyVerificationItem item,
  ) {
    final List<String> mismatchReasons = List<String>.unmodifiable(item.mismatchReasons);
    return RealAssistitiPostCopyAggregateItem(
      cf: item.cf,
      documentId: item.documentId,
      documentPath: item.documentPath,
      verified: item.verified,
      mismatchReasons: mismatchReasons,
      targetDocumentExists: item.targetRead.exists,
      cfLockDocumentExists: item.cfLockRead.exists,
      targetCfMatches: !mismatchReasons.contains('target_cf_mismatch'),
      targetAssistitoIdMatches: !mismatchReasons.contains('target_assistito_id_mismatch'),
      targetIdentityAnchorPresent: !mismatchReasons.contains('target_identity_absent'),
      cfLockCfMatches: !mismatchReasons.contains('cf_lock_cf_mismatch'),
      cfLockAssistitoIdMatches: !mismatchReasons.contains('cf_lock_assistito_id_mismatch'),
      cfLockAssistitoPathMatches: !mismatchReasons.contains('cf_lock_assistito_path_mismatch'),
      payloadMatchesExpected: !mismatchReasons.contains('target_payload_mismatch') &&
          !mismatchReasons.contains('written_payload_drift_from_preview'),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'cf': cf,
      'documentId': documentId,
      'documentPath': documentPath,
      'verified': verified,
      'failed': failed,
      'mismatchReasons': mismatchReasons,
      'targetDocumentExists': targetDocumentExists,
      'cfLockDocumentExists': cfLockDocumentExists,
      'targetCfMatches': targetCfMatches,
      'targetAssistitoIdMatches': targetAssistitoIdMatches,
      'targetIdentityAnchorPresent': targetIdentityAnchorPresent,
      'cfLockCfMatches': cfLockCfMatches,
      'cfLockAssistitoIdMatches': cfLockAssistitoIdMatches,
      'cfLockAssistitoPathMatches': cfLockAssistitoPathMatches,
      'payloadMatchesExpected': payloadMatchesExpected,
    };
  }
}

class RealAssistitiPostCopyAggregateSummary {
  final int requestedCount;
  final int itemCount;
  final int verifiedCount;
  final int failedCount;
  final int targetDocumentMissingCount;
  final int cfLockDocumentMissingCount;
  final int payloadMismatchCount;
  final int targetIdentityMismatchCount;
  final int cfLockMismatchCount;
  final Map<String, int> mismatchReasonCounts;

  const RealAssistitiPostCopyAggregateSummary({
    required this.requestedCount,
    required this.itemCount,
    required this.verifiedCount,
    required this.failedCount,
    required this.targetDocumentMissingCount,
    required this.cfLockDocumentMissingCount,
    required this.payloadMismatchCount,
    required this.targetIdentityMismatchCount,
    required this.cfLockMismatchCount,
    required this.mismatchReasonCounts,
  });

  bool get allVerified => itemCount > 0 && failedCount == 0 && verifiedCount == itemCount;

  bool get hasFailures => failedCount > 0 || !allVerified;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'requestedCount': requestedCount,
      'itemCount': itemCount,
      'verifiedCount': verifiedCount,
      'failedCount': failedCount,
      'allVerified': allVerified,
      'hasFailures': hasFailures,
      'targetDocumentMissingCount': targetDocumentMissingCount,
      'cfLockDocumentMissingCount': cfLockDocumentMissingCount,
      'payloadMismatchCount': payloadMismatchCount,
      'targetIdentityMismatchCount': targetIdentityMismatchCount,
      'cfLockMismatchCount': cfLockMismatchCount,
      'mismatchReasonCounts': mismatchReasonCounts,
    };
  }
}

class RealAssistitiPostCopyAggregateVerificationResult {
  final String tenantId;
  final String collectionPath;
  final String cfLocksCollectionPath;
  final List<String> requestedFiscalCodes;
  final List<RealAssistitiPostCopyAggregateItem> items;
  final RealAssistitiPostCopyAggregateSummary summary;
  final int targetDocumentReads;
  final int cfLockDocumentReads;
  final int legacyAttemptedDocumentReads;
  final int totalAttemptedReads;

  const RealAssistitiPostCopyAggregateVerificationResult({
    required this.tenantId,
    required this.collectionPath,
    required this.cfLocksCollectionPath,
    required this.requestedFiscalCodes,
    required this.items,
    required this.summary,
    required this.targetDocumentReads,
    required this.cfLockDocumentReads,
    required this.legacyAttemptedDocumentReads,
    required this.totalAttemptedReads,
  });

  bool get allVerified => summary.allVerified;

  bool get hasFailures => summary.hasFailures;

  List<String> get failedFiscalCodes {
    return List<String>.unmodifiable(
      items
          .where((RealAssistitiPostCopyAggregateItem item) => item.failed)
          .map((RealAssistitiPostCopyAggregateItem item) => item.cf),
    );
  }

  factory RealAssistitiPostCopyAggregateVerificationResult.fromDetailedVerification(
    RealAssistitiPostCopyVerificationResult detailedResult,
  ) {
    final List<RealAssistitiPostCopyAggregateItem> items = detailedResult.items
        .map(RealAssistitiPostCopyAggregateItem.fromDetailedItem)
        .toList(growable: false);
    final RealAssistitiPostCopyAggregateSummary summary = _buildSummary(
      requestedCount: detailedResult.requestedCount,
      items: items,
    );

    return RealAssistitiPostCopyAggregateVerificationResult(
      tenantId: detailedResult.tenantId,
      collectionPath: detailedResult.collectionPath,
      cfLocksCollectionPath: detailedResult.cfLocksCollectionPath,
      requestedFiscalCodes: List<String>.unmodifiable(detailedResult.requestedFiscalCodes),
      items: List<RealAssistitiPostCopyAggregateItem>.unmodifiable(items),
      summary: summary,
      targetDocumentReads: detailedResult.targetDocumentReads,
      cfLockDocumentReads: detailedResult.cfLockDocumentReads,
      legacyAttemptedDocumentReads: detailedResult.legacyAttemptedDocumentReads,
      totalAttemptedReads: detailedResult.totalAttemptedReads,
    );
  }

  static RealAssistitiPostCopyAggregateSummary _buildSummary({
    required int requestedCount,
    required List<RealAssistitiPostCopyAggregateItem> items,
  }) {
    int verifiedCount = 0;
    int failedCount = 0;
    int targetDocumentMissingCount = 0;
    int cfLockDocumentMissingCount = 0;
    int payloadMismatchCount = 0;
    int targetIdentityMismatchCount = 0;
    int cfLockMismatchCount = 0;
    final Map<String, int> mismatchReasonCounts = <String, int>{};

    for (final RealAssistitiPostCopyAggregateItem item in items) {
      if (item.verified) verifiedCount++;
      if (item.failed) failedCount++;
      if (!item.targetDocumentExists) targetDocumentMissingCount++;
      if (!item.cfLockDocumentExists) cfLockDocumentMissingCount++;
      if (!item.payloadMatchesExpected) payloadMismatchCount++;
      if (!item.targetCfMatches ||
          !item.targetAssistitoIdMatches ||
          !item.targetIdentityAnchorPresent) {
        targetIdentityMismatchCount++;
      }
      if (!item.cfLockCfMatches ||
          !item.cfLockAssistitoIdMatches ||
          !item.cfLockAssistitoPathMatches) {
        cfLockMismatchCount++;
      }
      for (final String reason in item.mismatchReasons) {
        mismatchReasonCounts[reason] = (mismatchReasonCounts[reason] ?? 0) + 1;
      }
    }

    return RealAssistitiPostCopyAggregateSummary(
      requestedCount: requestedCount,
      itemCount: items.length,
      verifiedCount: verifiedCount,
      failedCount: failedCount,
      targetDocumentMissingCount: targetDocumentMissingCount,
      cfLockDocumentMissingCount: cfLockDocumentMissingCount,
      payloadMismatchCount: payloadMismatchCount,
      targetIdentityMismatchCount: targetIdentityMismatchCount,
      cfLockMismatchCount: cfLockMismatchCount,
      mismatchReasonCounts: Map<String, int>.unmodifiable(mismatchReasonCounts),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tenantId': tenantId,
      'collectionPath': collectionPath,
      'cfLocksCollectionPath': cfLocksCollectionPath,
      'requestedFiscalCodes': requestedFiscalCodes,
      'failedFiscalCodes': failedFiscalCodes,
      'targetDocumentReads': targetDocumentReads,
      'cfLockDocumentReads': cfLockDocumentReads,
      'legacyAttemptedDocumentReads': legacyAttemptedDocumentReads,
      'totalAttemptedReads': totalAttemptedReads,
      'allVerified': allVerified,
      'hasFailures': hasFailures,
      'summary': summary.toMap(),
      'items': items
          .map((RealAssistitiPostCopyAggregateItem item) => item.toMap())
          .toList(growable: false),
    };
  }
}
