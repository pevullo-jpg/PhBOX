import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/target_multitenant_collections.dart';
import 'real_assistiti_nocf_migration_audit_reader.dart';

class TargetAssistitiIdentityDuplicateGuardRejectedException implements Exception {
  final String code;
  final String message;

  const TargetAssistitiIdentityDuplicateGuardRejectedException({
    required this.code,
    required this.message,
  });

  @override
  String toString() {
    return 'TargetAssistitiIdentityDuplicateGuardRejectedException($code): $message';
  }
}

class TargetAssistitiIdentityDuplicateGuardMatch {
  static const String sourceIdentityLock = 'identity_lock';
  static const String sourceCfLock = 'cf_lock';
  static const String sourceTargetIdentityAnchor = 'target_identity_anchor';
  static const String sourceTargetCf = 'target_cf';

  final String identityAnchor;
  final String source;
  final String documentId;
  final String documentPath;
  final List<String> rawDataRootKeys;

  const TargetAssistitiIdentityDuplicateGuardMatch({
    required this.identityAnchor,
    required this.source,
    required this.documentId,
    required this.documentPath,
    required this.rawDataRootKeys,
  });

  bool get exists => documentPath.trim().isNotEmpty;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'identityAnchor': identityAnchor,
      'source': source,
      'documentId': documentId,
      'documentPath': documentPath,
      'exists': exists,
      'rawDataRootKeys': rawDataRootKeys,
    };
  }
}

class TargetAssistitiIdentityDuplicateGuardCheck {
  final String requestedCode;
  final String identityType;
  final String identityAnchor;
  final String canonicalCf;
  final String legacyNoCfCode;
  final bool duplicateFound;
  final List<TargetAssistitiIdentityDuplicateGuardMatch> matches;

  const TargetAssistitiIdentityDuplicateGuardCheck({
    required this.requestedCode,
    required this.identityType,
    required this.identityAnchor,
    required this.canonicalCf,
    required this.legacyNoCfCode,
    required this.duplicateFound,
    required this.matches,
  });

  factory TargetAssistitiIdentityDuplicateGuardCheck.notFound({
    required RealAssistitiNoCfMigrationAuditItem auditItem,
  }) {
    return TargetAssistitiIdentityDuplicateGuardCheck(
      requestedCode: auditItem.requestedCode,
      identityType: auditItem.identityType,
      identityAnchor: auditItem.identityAnchor,
      canonicalCf: auditItem.canonicalCf,
      legacyNoCfCode: auditItem.legacyNoCfCode,
      duplicateFound: false,
      matches: const <TargetAssistitiIdentityDuplicateGuardMatch>[],
    );
  }

  factory TargetAssistitiIdentityDuplicateGuardCheck.found({
    required RealAssistitiNoCfMigrationAuditItem auditItem,
    required List<TargetAssistitiIdentityDuplicateGuardMatch> matches,
  }) {
    return TargetAssistitiIdentityDuplicateGuardCheck(
      requestedCode: auditItem.requestedCode,
      identityType: auditItem.identityType,
      identityAnchor: auditItem.identityAnchor,
      canonicalCf: auditItem.canonicalCf,
      legacyNoCfCode: auditItem.legacyNoCfCode,
      duplicateFound: matches.isNotEmpty,
      matches: List<TargetAssistitiIdentityDuplicateGuardMatch>.unmodifiable(matches),
    );
  }

  List<String> get duplicateSources {
    final List<String> sources = <String>[];
    for (final TargetAssistitiIdentityDuplicateGuardMatch match in matches) {
      if (!sources.contains(match.source)) {
        sources.add(match.source);
      }
    }
    return List<String>.unmodifiable(sources);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'requestedCode': requestedCode,
      'identityType': identityType,
      'identityAnchor': identityAnchor,
      'canonicalCf': canonicalCf,
      if (legacyNoCfCode.isNotEmpty) 'legacyNoCfCode': legacyNoCfCode,
      'duplicateFound': duplicateFound,
      'duplicateSources': duplicateSources,
      'matches': matches
          .map((TargetAssistitiIdentityDuplicateGuardMatch match) => match.toMap())
          .toList(growable: false),
    };
  }
}

class TargetAssistitiIdentityDuplicateGuardResult {
  final String tenantId;
  final String assistitiCollectionPath;
  final String identityLocksCollectionPath;
  final String cfLocksCollectionPath;
  final RealAssistitiNoCfMigrationAuditResult audit;
  final List<TargetAssistitiIdentityDuplicateGuardCheck> checks;
  final int maxIdentityCodes;
  final int attemptedLookupOperations;

  const TargetAssistitiIdentityDuplicateGuardResult({
    required this.tenantId,
    required this.assistitiCollectionPath,
    required this.identityLocksCollectionPath,
    required this.cfLocksCollectionPath,
    required this.audit,
    required this.checks,
    required this.maxIdentityCodes,
    required this.attemptedLookupOperations,
  });

  int get requestedCount => audit.summary.requestedCount;

  bool get hasAuditBlockingIssues => audit.summary.hasBlockedItems || audit.summary.hasRejectedItems;

  bool get hasDuplicates {
    for (final TargetAssistitiIdentityDuplicateGuardCheck check in checks) {
      if (check.duplicateFound) {
        return true;
      }
    }
    return false;
  }

  List<String> get duplicateIdentityAnchors {
    final List<String> anchors = <String>[];
    for (final TargetAssistitiIdentityDuplicateGuardCheck check in checks) {
      if (check.duplicateFound && !anchors.contains(check.identityAnchor)) {
        anchors.add(check.identityAnchor);
      }
    }
    return List<String>.unmodifiable(anchors);
  }

  List<String> get duplicateRequestedCodes {
    final List<String> codes = <String>[];
    for (final TargetAssistitiIdentityDuplicateGuardCheck check in checks) {
      if (check.duplicateFound && !codes.contains(check.requestedCode)) {
        codes.add(check.requestedCode);
      }
    }
    return List<String>.unmodifiable(codes);
  }

  Map<String, int> get duplicateSourceCounts {
    final Map<String, int> counts = <String, int>{};
    for (final TargetAssistitiIdentityDuplicateGuardCheck check in checks) {
      if (!check.duplicateFound) {
        continue;
      }
      for (final String source in check.duplicateSources) {
        counts[source] = (counts[source] ?? 0) + 1;
      }
    }
    return Map<String, int>.unmodifiable(counts);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tenantId': tenantId,
      'assistitiCollectionPath': assistitiCollectionPath,
      'identityLocksCollectionPath': identityLocksCollectionPath,
      'cfLocksCollectionPath': cfLocksCollectionPath,
      'requestedCount': requestedCount,
      'maxIdentityCodes': maxIdentityCodes,
      'attemptedLookupOperations': attemptedLookupOperations,
      'hasAuditBlockingIssues': hasAuditBlockingIssues,
      'hasDuplicates': hasDuplicates,
      'duplicateIdentityAnchors': duplicateIdentityAnchors,
      'duplicateRequestedCodes': duplicateRequestedCodes,
      'duplicateSourceCounts': duplicateSourceCounts,
      'audit': audit.toMap(),
      'checks': checks
          .map((TargetAssistitiIdentityDuplicateGuardCheck check) => check.toMap())
          .toList(growable: false),
    };
  }
}

class TargetAssistitiIdentityDuplicateGuardReader {
  static const int maxIdentityCodes = 5;
  static const int lookupOperationsPerIdentityAnchor = 4;
  static const String identityLocksCollectionId = 'assistiti_identity_locks';
  static const String cfLocksCollectionId = 'assistiti_cf_locks';

  final FirebaseFirestore firestore;

  const TargetAssistitiIdentityDuplicateGuardReader({
    required this.firestore,
  });

  Future<TargetAssistitiIdentityDuplicateGuardResult> checkByManualIdentityCodes({
    required String tenantId,
    required Iterable<String> identityCodes,
  }) async {
    final String normalizedTenantId = _normalizeTenantId(tenantId);
    final List<String> requestedCodes = identityCodes.toList(growable: false);
    _assertRequestSize(requestedCodes);

    final RealAssistitiNoCfMigrationAuditResult audit =
        RealAssistitiNoCfMigrationAuditResult.fromRequestedCodes(requestedCodes);
    final String assistitiCollectionPath = TargetMultitenantCollections.tenantCollection(
      tenantId: normalizedTenantId,
      collectionId: TargetMultitenantCollections.assistiti,
    );
    final String identityLocksCollectionPath = TargetMultitenantCollections.tenantCollection(
      tenantId: normalizedTenantId,
      collectionId: identityLocksCollectionId,
    );
    final String cfLocksCollectionPath = TargetMultitenantCollections.tenantCollection(
      tenantId: normalizedTenantId,
      collectionId: cfLocksCollectionId,
    );

    if (audit.summary.hasBlockedItems || audit.summary.hasRejectedItems) {
      return TargetAssistitiIdentityDuplicateGuardResult(
        tenantId: normalizedTenantId,
        assistitiCollectionPath: assistitiCollectionPath,
        identityLocksCollectionPath: identityLocksCollectionPath,
        cfLocksCollectionPath: cfLocksCollectionPath,
        audit: audit,
        checks: const <TargetAssistitiIdentityDuplicateGuardCheck>[],
        maxIdentityCodes: maxIdentityCodes,
        attemptedLookupOperations: 0,
      );
    }

    final List<TargetAssistitiIdentityDuplicateGuardCheck> checks =
        <TargetAssistitiIdentityDuplicateGuardCheck>[];
    for (final RealAssistitiNoCfMigrationAuditItem item in audit.items) {
      if (!item.copyCandidate) {
        continue;
      }
      checks.add(await _checkOneIdentityAnchor(
        auditItem: item,
        assistitiCollectionPath: assistitiCollectionPath,
        identityLocksCollectionPath: identityLocksCollectionPath,
        cfLocksCollectionPath: cfLocksCollectionPath,
      ));
    }

    return TargetAssistitiIdentityDuplicateGuardResult(
      tenantId: normalizedTenantId,
      assistitiCollectionPath: assistitiCollectionPath,
      identityLocksCollectionPath: identityLocksCollectionPath,
      cfLocksCollectionPath: cfLocksCollectionPath,
      audit: audit,
      checks: List<TargetAssistitiIdentityDuplicateGuardCheck>.unmodifiable(checks),
      maxIdentityCodes: maxIdentityCodes,
      attemptedLookupOperations: checks.length * lookupOperationsPerIdentityAnchor,
    );
  }

  Future<TargetAssistitiIdentityDuplicateGuardResult> assertNoTargetIdentityDuplicates({
    required String tenantId,
    required Iterable<String> identityCodes,
  }) async {
    final TargetAssistitiIdentityDuplicateGuardResult result = await checkByManualIdentityCodes(
      tenantId: tenantId,
      identityCodes: identityCodes,
    );

    if (result.hasAuditBlockingIssues) {
      throw TargetAssistitiIdentityDuplicateGuardRejectedException(
        code: 'identity_audit_has_blocking_issues',
        message:
            'Audit identità CF/NOCF contiene blocchi o scarti: ${result.audit.blockedRequestedCodes.join(', ')} ${result.audit.rejectedRequestedCodes.join(', ')}.'
                .trim(),
      );
    }

    if (result.hasDuplicates) {
      throw TargetAssistitiIdentityDuplicateGuardRejectedException(
        code: 'target_assistito_identity_duplicate',
        message:
            'Assistito target già presente per identityAnchor: ${result.duplicateIdentityAnchors.join(', ')}.',
      );
    }

    return result;
  }

  Future<TargetAssistitiIdentityDuplicateGuardCheck> _checkOneIdentityAnchor({
    required RealAssistitiNoCfMigrationAuditItem auditItem,
    required String assistitiCollectionPath,
    required String identityLocksCollectionPath,
    required String cfLocksCollectionPath,
  }) async {
    final List<TargetAssistitiIdentityDuplicateGuardMatch> matches =
        <TargetAssistitiIdentityDuplicateGuardMatch>[];
    final Set<String> seenDocumentPaths = <String>{};

    final DocumentSnapshot<Map<String, dynamic>> identityLockSnapshot = await firestore
        .collection(identityLocksCollectionPath)
        .doc(auditItem.identityAnchor)
        .get(const GetOptions(source: Source.serverAndCache));
    _addDocumentSnapshotMatch(
      matches: matches,
      seenDocumentPaths: seenDocumentPaths,
      identityAnchor: auditItem.identityAnchor,
      source: TargetAssistitiIdentityDuplicateGuardMatch.sourceIdentityLock,
      snapshot: identityLockSnapshot,
    );

    final DocumentSnapshot<Map<String, dynamic>> cfLockSnapshot = await firestore
        .collection(cfLocksCollectionPath)
        .doc(auditItem.identityAnchor)
        .get(const GetOptions(source: Source.serverAndCache));
    _addDocumentSnapshotMatch(
      matches: matches,
      seenDocumentPaths: seenDocumentPaths,
      identityAnchor: auditItem.identityAnchor,
      source: TargetAssistitiIdentityDuplicateGuardMatch.sourceCfLock,
      snapshot: cfLockSnapshot,
    );

    final QuerySnapshot<Map<String, dynamic>> identityAnchorSnapshot = await firestore
        .collection(assistitiCollectionPath)
        .where('identityAnchor', isEqualTo: auditItem.identityAnchor)
        .limit(1)
        .get(const GetOptions(source: Source.serverAndCache));
    _addQuerySnapshotMatches(
      matches: matches,
      seenDocumentPaths: seenDocumentPaths,
      identityAnchor: auditItem.identityAnchor,
      source: TargetAssistitiIdentityDuplicateGuardMatch.sourceTargetIdentityAnchor,
      snapshot: identityAnchorSnapshot,
    );

    final QuerySnapshot<Map<String, dynamic>> cfSnapshot = await firestore
        .collection(assistitiCollectionPath)
        .where('cf', isEqualTo: auditItem.identityAnchor)
        .limit(1)
        .get(const GetOptions(source: Source.serverAndCache));
    _addQuerySnapshotMatches(
      matches: matches,
      seenDocumentPaths: seenDocumentPaths,
      identityAnchor: auditItem.identityAnchor,
      source: TargetAssistitiIdentityDuplicateGuardMatch.sourceTargetCf,
      snapshot: cfSnapshot,
    );

    if (matches.isEmpty) {
      return TargetAssistitiIdentityDuplicateGuardCheck.notFound(auditItem: auditItem);
    }

    return TargetAssistitiIdentityDuplicateGuardCheck.found(
      auditItem: auditItem,
      matches: matches,
    );
  }

  void _addDocumentSnapshotMatch({
    required List<TargetAssistitiIdentityDuplicateGuardMatch> matches,
    required Set<String> seenDocumentPaths,
    required String identityAnchor,
    required String source,
    required DocumentSnapshot<Map<String, dynamic>> snapshot,
  }) {
    if (!snapshot.exists) {
      return;
    }
    final String path = snapshot.reference.path;
    if (!seenDocumentPaths.add(path)) {
      return;
    }
    final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};
    final List<String> rootKeys = data.keys.toList(growable: false)..sort();
    matches.add(TargetAssistitiIdentityDuplicateGuardMatch(
      identityAnchor: identityAnchor,
      source: source,
      documentId: snapshot.id,
      documentPath: path,
      rawDataRootKeys: List<String>.unmodifiable(rootKeys),
    ));
  }

  void _addQuerySnapshotMatches({
    required List<TargetAssistitiIdentityDuplicateGuardMatch> matches,
    required Set<String> seenDocumentPaths,
    required String identityAnchor,
    required String source,
    required QuerySnapshot<Map<String, dynamic>> snapshot,
  }) {
    for (final QueryDocumentSnapshot<Map<String, dynamic>> document in snapshot.docs) {
      final String path = document.reference.path;
      if (!seenDocumentPaths.add(path)) {
        continue;
      }
      final List<String> rootKeys = document.data().keys.toList(growable: false)..sort();
      matches.add(TargetAssistitiIdentityDuplicateGuardMatch(
        identityAnchor: identityAnchor,
        source: source,
        documentId: document.id,
        documentPath: path,
        rawDataRootKeys: List<String>.unmodifiable(rootKeys),
      ));
    }
  }

  static void _assertRequestSize(List<String> requestedCodes) {
    if (requestedCodes.isEmpty) {
      throw const TargetAssistitiIdentityDuplicateGuardRejectedException(
        code: 'identity_codes_empty',
        message: 'Lista codici identità CF/NOCF vuota.',
      );
    }
    if (requestedCodes.length > maxIdentityCodes) {
      throw const TargetAssistitiIdentityDuplicateGuardRejectedException(
        code: 'identity_codes_exceed_hard_cap',
        message: 'Lista codici identità CF/NOCF oltre limite hard di 5.',
      );
    }
  }

  static String _normalizeTenantId(String value) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw const TargetAssistitiIdentityDuplicateGuardRejectedException(
        code: 'tenant_id_empty',
        message: 'tenantId obbligatorio per duplicate guard identità assistiti target.',
      );
    }
    if (normalized.contains('/')) {
      throw const TargetAssistitiIdentityDuplicateGuardRejectedException(
        code: 'tenant_id_not_canonical',
        message: 'tenantId non canonico: slash non ammesso.',
      );
    }
    return normalized;
  }
}
