import '../normalizers/target_assistito_nocf_identity_anchor_normalizer.dart';

class RealAssistitiNoCfMigrationAuditItem {
  static const String statusCopyCandidate = 'copy_candidate';
  static const String statusBlocked = 'blocked';
  static const String statusRejected = 'rejected';

  final String requestedCode;
  final String status;
  final String identityType;
  final String identityAnchor;
  final String canonicalCf;
  final String legacyNoCfCode;
  final bool generatedNoCf;
  final bool copyCandidate;
  final List<String> blockingReasons;

  const RealAssistitiNoCfMigrationAuditItem({
    required this.requestedCode,
    required this.status,
    required this.identityType,
    required this.identityAnchor,
    required this.canonicalCf,
    required this.legacyNoCfCode,
    required this.generatedNoCf,
    required this.copyCandidate,
    required this.blockingReasons,
  });

  bool get isCf => identityType == TargetAssistitoNoCfIdentityAnchorNormalizer.identityTypeCf;

  bool get isNoCf => identityType == TargetAssistitoNoCfIdentityAnchorNormalizer.identityTypeNoCf;

  bool get rejected => status == statusRejected;

  bool get blocked => status == statusBlocked;

  factory RealAssistitiNoCfMigrationAuditItem.fromRequestedCode(String rawCode) {
    final String requestedCode = rawCode.trim();
    try {
      final TargetAssistitoIdentityAnchorResult normalized =
          TargetAssistitoNoCfIdentityAnchorNormalizer.fromLegacyCode(rawCode);

      return RealAssistitiNoCfMigrationAuditItem(
        requestedCode: requestedCode,
        status: statusCopyCandidate,
        identityType: normalized.identityType,
        identityAnchor: normalized.identityAnchor,
        canonicalCf: normalized.cf,
        legacyNoCfCode: normalized.legacyNoCfCode,
        generatedNoCf: normalized.generatedNoCf,
        copyCandidate: true,
        blockingReasons: const <String>[],
      );
    } on TargetAssistitoNoCfIdentityAnchorRejectedException catch (error) {
      return RealAssistitiNoCfMigrationAuditItem(
        requestedCode: requestedCode,
        status: statusRejected,
        identityType: '',
        identityAnchor: '',
        canonicalCf: '',
        legacyNoCfCode: '',
        generatedNoCf: false,
        copyCandidate: false,
        blockingReasons: <String>[error.code],
      );
    }
  }

  RealAssistitiNoCfMigrationAuditItem withBlockingReason(String reason) {
    final List<String> reasons = List<String>.from(blockingReasons);
    if (!reasons.contains(reason)) {
      reasons.add(reason);
    }

    return RealAssistitiNoCfMigrationAuditItem(
      requestedCode: requestedCode,
      status: statusBlocked,
      identityType: identityType,
      identityAnchor: identityAnchor,
      canonicalCf: canonicalCf,
      legacyNoCfCode: legacyNoCfCode,
      generatedNoCf: generatedNoCf,
      copyCandidate: false,
      blockingReasons: List<String>.unmodifiable(reasons),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'requestedCode': requestedCode,
      'status': status,
      'identityType': identityType,
      'identityAnchor': identityAnchor,
      'canonicalCf': canonicalCf,
      if (legacyNoCfCode.isNotEmpty) 'legacyNoCfCode': legacyNoCfCode,
      'generatedNoCf': generatedNoCf,
      'copyCandidate': copyCandidate,
      'isCf': isCf,
      'isNoCf': isNoCf,
      'blocked': blocked,
      'rejected': rejected,
      'blockingReasons': blockingReasons,
    };
  }
}

class RealAssistitiNoCfMigrationAuditSummary {
  final int requestedCount;
  final int itemCount;
  final int copyCandidateCount;
  final int blockedCount;
  final int rejectedCount;
  final int cfCount;
  final int nocfCount;
  final int duplicateIdentityAnchorCount;
  final Map<String, int> blockingReasonCounts;

  const RealAssistitiNoCfMigrationAuditSummary({
    required this.requestedCount,
    required this.itemCount,
    required this.copyCandidateCount,
    required this.blockedCount,
    required this.rejectedCount,
    required this.cfCount,
    required this.nocfCount,
    required this.duplicateIdentityAnchorCount,
    required this.blockingReasonCounts,
  });

  bool get hasCopyCandidates => copyCandidateCount > 0;

  bool get hasBlockedItems => blockedCount > 0;

  bool get hasRejectedItems => rejectedCount > 0;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'requestedCount': requestedCount,
      'itemCount': itemCount,
      'copyCandidateCount': copyCandidateCount,
      'blockedCount': blockedCount,
      'rejectedCount': rejectedCount,
      'cfCount': cfCount,
      'nocfCount': nocfCount,
      'duplicateIdentityAnchorCount': duplicateIdentityAnchorCount,
      'hasCopyCandidates': hasCopyCandidates,
      'hasBlockedItems': hasBlockedItems,
      'hasRejectedItems': hasRejectedItems,
      'blockingReasonCounts': blockingReasonCounts,
    };
  }
}

class RealAssistitiNoCfMigrationAuditResult {
  final List<RealAssistitiNoCfMigrationAuditItem> items;
  final RealAssistitiNoCfMigrationAuditSummary summary;

  const RealAssistitiNoCfMigrationAuditResult({
    required this.items,
    required this.summary,
  });

  List<String> get copyCandidateIdentityAnchors {
    return List<String>.unmodifiable(
      items
          .where((RealAssistitiNoCfMigrationAuditItem item) => item.copyCandidate)
          .map((RealAssistitiNoCfMigrationAuditItem item) => item.identityAnchor),
    );
  }

  List<String> get copyCandidateRequestedCodes {
    return List<String>.unmodifiable(
      items
          .where((RealAssistitiNoCfMigrationAuditItem item) => item.copyCandidate)
          .map((RealAssistitiNoCfMigrationAuditItem item) => item.requestedCode),
    );
  }

  List<String> get blockedRequestedCodes {
    return List<String>.unmodifiable(
      items
          .where((RealAssistitiNoCfMigrationAuditItem item) => item.blocked)
          .map((RealAssistitiNoCfMigrationAuditItem item) => item.requestedCode),
    );
  }

  List<String> get rejectedRequestedCodes {
    return List<String>.unmodifiable(
      items
          .where((RealAssistitiNoCfMigrationAuditItem item) => item.rejected)
          .map((RealAssistitiNoCfMigrationAuditItem item) => item.requestedCode),
    );
  }

  static RealAssistitiNoCfMigrationAuditResult fromRequestedCodes(
    Iterable<String> rawCodes,
  ) {
    final List<String> requestedCodes = rawCodes.toList(growable: false);
    final List<RealAssistitiNoCfMigrationAuditItem> normalizedItems = requestedCodes
        .map(RealAssistitiNoCfMigrationAuditItem.fromRequestedCode)
        .toList(growable: false);

    final Map<String, int> anchorCounts = <String, int>{};
    for (final RealAssistitiNoCfMigrationAuditItem item in normalizedItems) {
      if (item.identityAnchor.isEmpty) {
        continue;
      }
      anchorCounts[item.identityAnchor] = (anchorCounts[item.identityAnchor] ?? 0) + 1;
    }

    final List<RealAssistitiNoCfMigrationAuditItem> items =
        <RealAssistitiNoCfMigrationAuditItem>[];
    for (final RealAssistitiNoCfMigrationAuditItem item in normalizedItems) {
      if (item.identityAnchor.isNotEmpty && (anchorCounts[item.identityAnchor] ?? 0) > 1) {
        items.add(item.withBlockingReason('duplicate_identity_anchor_in_request'));
      } else {
        items.add(item);
      }
    }

    return RealAssistitiNoCfMigrationAuditResult(
      items: List<RealAssistitiNoCfMigrationAuditItem>.unmodifiable(items),
      summary: _buildSummary(
        requestedCount: requestedCodes.length,
        items: items,
      ),
    );
  }

  static RealAssistitiNoCfMigrationAuditSummary _buildSummary({
    required int requestedCount,
    required List<RealAssistitiNoCfMigrationAuditItem> items,
  }) {
    int copyCandidateCount = 0;
    int blockedCount = 0;
    int rejectedCount = 0;
    int cfCount = 0;
    int nocfCount = 0;
    int duplicateIdentityAnchorCount = 0;
    final Map<String, int> blockingReasonCounts = <String, int>{};

    for (final RealAssistitiNoCfMigrationAuditItem item in items) {
      if (item.copyCandidate) copyCandidateCount++;
      if (item.blocked) blockedCount++;
      if (item.rejected) rejectedCount++;
      if (item.isCf) cfCount++;
      if (item.isNoCf) nocfCount++;

      for (final String reason in item.blockingReasons) {
        blockingReasonCounts[reason] = (blockingReasonCounts[reason] ?? 0) + 1;
      }
      if (item.blockingReasons.contains('duplicate_identity_anchor_in_request')) {
        duplicateIdentityAnchorCount++;
      }
    }

    return RealAssistitiNoCfMigrationAuditSummary(
      requestedCount: requestedCount,
      itemCount: items.length,
      copyCandidateCount: copyCandidateCount,
      blockedCount: blockedCount,
      rejectedCount: rejectedCount,
      cfCount: cfCount,
      nocfCount: nocfCount,
      duplicateIdentityAnchorCount: duplicateIdentityAnchorCount,
      blockingReasonCounts: Map<String, int>.unmodifiable(blockingReasonCounts),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'copyCandidateIdentityAnchors': copyCandidateIdentityAnchors,
      'copyCandidateRequestedCodes': copyCandidateRequestedCodes,
      'blockedRequestedCodes': blockedRequestedCodes,
      'rejectedRequestedCodes': rejectedRequestedCodes,
      'summary': summary.toMap(),
      'items': items
          .map((RealAssistitiNoCfMigrationAuditItem item) => item.toMap())
          .toList(growable: false),
    };
  }
}
