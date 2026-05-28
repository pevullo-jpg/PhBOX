import 'package:cloud_firestore/cloud_firestore.dart';

import '../mappers/real_assistiti_target_preview_mapper.dart';
import '../models/target_multitenant_collections.dart';
import '../normalizers/target_assistito_identity_normalizer.dart';
import '../normalizers/target_assistito_nocf_identity_anchor_normalizer.dart';
import '../writers/real_assistiti_nocf_identity_resolution_writer.dart';
import '../writers/real_assistiti_nocf_target_copy_writer.dart';

class RealAssistitiNoCfPostResolutionVerifierRejectedException implements Exception {
  final String code;
  final String message;

  const RealAssistitiNoCfPostResolutionVerifierRejectedException({
    required this.code,
    required this.message,
  });

  @override
  String toString() {
    return 'RealAssistitiNoCfPostResolutionVerifierRejectedException($code): $message';
  }
}

class RealAssistitiNoCfPostResolutionVerificationItem {
  final String identityAnchor;
  final String assistitoId;
  final String assistitoPath;
  final String identityLockPath;
  final String cfLockPath;
  final bool targetExists;
  final bool identityLockExists;
  final bool cfLockExists;
  final String identityType;
  final String cf;
  final String legacyNoCfCode;
  final String identityResolutionStatus;
  final String nestedIdentityResolutionStatus;
  final String nameSplitConfidence;
  final String nome;
  final String cognome;
  final String fullName;
  final List<String> searchPrefixes;
  final List<String> mismatchReasons;

  const RealAssistitiNoCfPostResolutionVerificationItem({
    required this.identityAnchor,
    required this.assistitoId,
    required this.assistitoPath,
    required this.identityLockPath,
    required this.cfLockPath,
    required this.targetExists,
    required this.identityLockExists,
    required this.cfLockExists,
    required this.identityType,
    required this.cf,
    required this.legacyNoCfCode,
    required this.identityResolutionStatus,
    required this.nestedIdentityResolutionStatus,
    required this.nameSplitConfidence,
    required this.nome,
    required this.cognome,
    required this.fullName,
    required this.searchPrefixes,
    required this.mismatchReasons,
  });

  bool get verified => mismatchReasons.isEmpty;

  bool get failed => !verified;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'identityAnchor': identityAnchor,
      'assistitoId': assistitoId,
      'assistitoPath': assistitoPath,
      'identityLockPath': identityLockPath,
      'cfLockPath': cfLockPath,
      'verified': verified,
      'failed': failed,
      'mismatchReasons': mismatchReasons,
      'targetExists': targetExists,
      'identityLockExists': identityLockExists,
      'cfLockExists': cfLockExists,
      'identityType': identityType,
      'cf': cf,
      'legacyNoCfCode': legacyNoCfCode,
      'identityResolutionStatus': identityResolutionStatus,
      'nestedIdentityResolutionStatus': nestedIdentityResolutionStatus,
      'nameSplitConfidence': nameSplitConfidence,
      'nome': nome,
      'cognome': cognome,
      'fullName': fullName,
      'searchPrefixes': searchPrefixes,
    };
  }
}

class RealAssistitiNoCfPostResolutionVerificationSummary {
  final int requestedCount;
  final int verifiedCount;
  final int failedCount;
  final Map<String, int> mismatchReasonCounts;

  const RealAssistitiNoCfPostResolutionVerificationSummary({
    required this.requestedCount,
    required this.verifiedCount,
    required this.failedCount,
    required this.mismatchReasonCounts,
  });

  bool get allVerified => requestedCount > 0 && failedCount == 0 && verifiedCount == requestedCount;

  bool get hasFailures => !allVerified;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'requestedCount': requestedCount,
      'verifiedCount': verifiedCount,
      'failedCount': failedCount,
      'allVerified': allVerified,
      'hasFailures': hasFailures,
      'mismatchReasonCounts': mismatchReasonCounts,
    };
  }
}

class RealAssistitiNoCfPostResolutionVerificationResult {
  final String tenantId;
  final String assistitiCollectionPath;
  final String identityLocksCollectionPath;
  final String cfLocksCollectionPath;
  final List<String> requestedIdentityAnchors;
  final List<RealAssistitiNoCfPostResolutionVerificationItem> items;
  final int targetDocumentReads;
  final int identityLockDocumentReads;
  final int cfLockDocumentReads;
  final RealAssistitiNoCfPostResolutionVerificationSummary summary;

  const RealAssistitiNoCfPostResolutionVerificationResult({
    required this.tenantId,
    required this.assistitiCollectionPath,
    required this.identityLocksCollectionPath,
    required this.cfLocksCollectionPath,
    required this.requestedIdentityAnchors,
    required this.items,
    required this.targetDocumentReads,
    required this.identityLockDocumentReads,
    required this.cfLockDocumentReads,
    required this.summary,
  });

  int get totalAttemptedReads => targetDocumentReads + identityLockDocumentReads + cfLockDocumentReads;

  bool get allVerified => summary.allVerified;

  bool get hasFailures => summary.hasFailures;

  List<String> get failedIdentityAnchors {
    return List<String>.unmodifiable(
      items
          .where((RealAssistitiNoCfPostResolutionVerificationItem item) => item.failed)
          .map((RealAssistitiNoCfPostResolutionVerificationItem item) => item.identityAnchor),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tenantId': tenantId,
      'assistitiCollectionPath': assistitiCollectionPath,
      'identityLocksCollectionPath': identityLocksCollectionPath,
      'cfLocksCollectionPath': cfLocksCollectionPath,
      'requestedIdentityAnchors': requestedIdentityAnchors,
      'failedIdentityAnchors': failedIdentityAnchors,
      'targetDocumentReads': targetDocumentReads,
      'identityLockDocumentReads': identityLockDocumentReads,
      'cfLockDocumentReads': cfLockDocumentReads,
      'totalAttemptedReads': totalAttemptedReads,
      'allVerified': allVerified,
      'hasFailures': hasFailures,
      'summary': summary.toMap(),
      'items': items
          .map((RealAssistitiNoCfPostResolutionVerificationItem item) => item.toMap())
          .toList(growable: false),
    };
  }
}

class RealAssistitiNoCfPostResolutionVerifier {
  static const int maxIdentityAnchorsPerRun = 5;
  static const int readsPerIdentityAnchor = 3;
  static const String pendingManualStatus = 'pending_manual';
  static const String resolvedManualStatus = 'resolved_manual';
  static const String resolvedManualConfidence = 'resolved_manual_nocf_identity';
  static const String pendingManualConfidence = 'pending_manual_nocf_identity_resolution';

  final FirebaseFirestore firestore;

  const RealAssistitiNoCfPostResolutionVerifier({
    required this.firestore,
  });

  Future<RealAssistitiNoCfPostResolutionVerificationResult> verifyIdentityAnchors({
    required String tenantId,
    required Iterable<String> identityAnchors,
  }) async {
    final String normalizedTenantId = _normalizeSegment(tenantId, label: 'tenantId');
    final List<String> normalizedIdentityAnchors = normalizeIdentityAnchors(identityAnchors);
    final String assistitiCollectionPath = TargetMultitenantCollections.tenantCollection(
      tenantId: normalizedTenantId,
      collectionId: TargetMultitenantCollections.assistiti,
    );
    final String identityLocksCollectionPath = TargetMultitenantCollections.tenantCollection(
      tenantId: normalizedTenantId,
      collectionId: RealAssistitiNoCfTargetCopyWriter.identityLocksCollectionId,
    );
    final String cfLocksCollectionPath = TargetMultitenantCollections.tenantCollection(
      tenantId: normalizedTenantId,
      collectionId: RealAssistitiNoCfTargetCopyWriter.cfLocksCollectionId,
    );

    final List<RealAssistitiNoCfPostResolutionVerificationItem> items =
        <RealAssistitiNoCfPostResolutionVerificationItem>[];
    int targetDocumentReads = 0;

    for (final String identityAnchor in normalizedIdentityAnchors) {
      final DocumentReference<Map<String, dynamic>> identityLockRef = firestore.doc(
        TargetMultitenantCollections.tenantDocument(
          tenantId: normalizedTenantId,
          collectionId: RealAssistitiNoCfTargetCopyWriter.identityLocksCollectionId,
          documentId: identityAnchor,
        ),
      );
      final DocumentReference<Map<String, dynamic>> cfLockRef = firestore.doc(
        TargetMultitenantCollections.tenantDocument(
          tenantId: normalizedTenantId,
          collectionId: RealAssistitiNoCfTargetCopyWriter.cfLocksCollectionId,
          documentId: identityAnchor,
        ),
      );

      final DocumentSnapshot<Map<String, dynamic>> identityLockSnapshot =
          await identityLockRef.get(const GetOptions(source: Source.serverAndCache));
      final DocumentSnapshot<Map<String, dynamic>> cfLockSnapshot =
          await cfLockRef.get(const GetOptions(source: Source.serverAndCache));
      final Map<String, dynamic> identityLockData =
          Map<String, dynamic>.unmodifiable(identityLockSnapshot.data() ?? <String, dynamic>{});
      final Map<String, dynamic> cfLockData =
          Map<String, dynamic>.unmodifiable(cfLockSnapshot.data() ?? <String, dynamic>{});
      final String assistitoId = _firstNonEmptyString(<Object?>[
        identityLockData['assistitoId'],
        cfLockData['assistitoId'],
      ]);

      bool targetExists = false;
      Map<String, dynamic> targetData = const <String, dynamic>{};
      if (assistitoId.isNotEmpty) {
        final DocumentSnapshot<Map<String, dynamic>> targetSnapshot = await firestore
            .doc(TargetMultitenantCollections.assistitoDocument(
              tenantId: normalizedTenantId,
              assistitoId: assistitoId,
            ))
            .get(const GetOptions(source: Source.serverAndCache));
        targetDocumentReads++;
        targetExists = targetSnapshot.exists;
        targetData = Map<String, dynamic>.unmodifiable(targetSnapshot.data() ?? <String, dynamic>{});
      }

      items.add(verifyRawPayloads(
        tenantId: normalizedTenantId,
        identityAnchor: identityAnchor,
        targetExists: targetExists,
        targetData: targetData,
        identityLockExists: identityLockSnapshot.exists,
        identityLockData: identityLockData,
        cfLockExists: cfLockSnapshot.exists,
        cfLockData: cfLockData,
        assistitoIdOverride: assistitoId,
      ));
    }

    return RealAssistitiNoCfPostResolutionVerificationResult(
      tenantId: normalizedTenantId,
      assistitiCollectionPath: assistitiCollectionPath,
      identityLocksCollectionPath: identityLocksCollectionPath,
      cfLocksCollectionPath: cfLocksCollectionPath,
      requestedIdentityAnchors: normalizedIdentityAnchors,
      items: List<RealAssistitiNoCfPostResolutionVerificationItem>.unmodifiable(items),
      targetDocumentReads: targetDocumentReads,
      identityLockDocumentReads: normalizedIdentityAnchors.length,
      cfLockDocumentReads: normalizedIdentityAnchors.length,
      summary: buildSummary(
        requestedCount: normalizedIdentityAnchors.length,
        items: items,
      ),
    );
  }

  static RealAssistitiNoCfPostResolutionVerificationItem verifyRawPayloads({
    required String tenantId,
    required String identityAnchor,
    required bool targetExists,
    required Map<String, dynamic> targetData,
    required bool identityLockExists,
    required Map<String, dynamic> identityLockData,
    required bool cfLockExists,
    required Map<String, dynamic> cfLockData,
    String assistitoIdOverride = '',
  }) {
    final String normalizedTenantId = _normalizeSegment(tenantId, label: 'tenantId');
    final String normalizedIdentityAnchor = _normalizeIdentityAnchor(identityAnchor);
    final String assistitoId = _firstNonEmptyString(<Object?>[
      assistitoIdOverride,
      identityLockData['assistitoId'],
      cfLockData['assistitoId'],
      targetData['assistitoId'],
    ]);
    final String assistitoPath = assistitoId.isEmpty
        ? ''
        : TargetMultitenantCollections.assistitoDocument(
            tenantId: normalizedTenantId,
            assistitoId: assistitoId,
          );
    final String identityLockPath = TargetMultitenantCollections.tenantDocument(
      tenantId: normalizedTenantId,
      collectionId: RealAssistitiNoCfTargetCopyWriter.identityLocksCollectionId,
      documentId: normalizedIdentityAnchor,
    );
    final String cfLockPath = TargetMultitenantCollections.tenantDocument(
      tenantId: normalizedTenantId,
      collectionId: RealAssistitiNoCfTargetCopyWriter.cfLocksCollectionId,
      documentId: normalizedIdentityAnchor,
    );
    final String identityType = _readString(targetData['identityType']);
    final String cf = _readString(targetData['cf']);
    final String legacyNoCfCode = _readString(targetData['legacyNoCfCode']);
    final String identityResolutionStatus = _readString(targetData['identityResolutionStatus']);
    final String nestedIdentityResolutionStatus = _readNestedStatus(targetData['identityResolution']);
    final String nameSplitConfidence = _readString(targetData['nameSplitConfidence']);
    final String nome = _readString(targetData['nome']);
    final String cognome = _readString(targetData['cognome']);
    final String fullName = _readString(targetData['fullName']);
    final List<String> searchPrefixes = _readStringList(targetData['searchPrefixes']);

    final List<String> mismatchReasons = <String>[];
    if (!identityLockExists) mismatchReasons.add('identity_lock_missing');
    if (!cfLockExists) mismatchReasons.add('cf_lock_missing');
    if (assistitoId.isEmpty) mismatchReasons.add('assistito_id_missing_from_locks');
    if (!targetExists) mismatchReasons.add('target_document_missing');

    _verifyLockPayload(
      lockLabel: 'identity_lock',
      expectedIdentityAnchor: normalizedIdentityAnchor,
      expectedAssistitoId: assistitoId,
      expectedAssistitoPath: assistitoPath,
      payload: identityLockData,
      mismatchReasons: mismatchReasons,
    );
    _verifyLockPayload(
      lockLabel: 'cf_lock',
      expectedIdentityAnchor: normalizedIdentityAnchor,
      expectedAssistitoId: assistitoId,
      expectedAssistitoPath: assistitoPath,
      payload: cfLockData,
      mismatchReasons: mismatchReasons,
    );

    if (targetExists) {
      if (identityType != TargetAssistitoNoCfIdentityAnchorNormalizer.identityTypeNoCf) {
        mismatchReasons.add('target_identity_type_not_nocf');
      }
      if (cf != normalizedIdentityAnchor) {
        mismatchReasons.add('target_cf_identity_anchor_mismatch');
      }
      if (_readString(targetData['identityAnchor']) != normalizedIdentityAnchor) {
        mismatchReasons.add('target_identity_anchor_mismatch');
      }
      if (_readString(targetData['assistitoId']) != assistitoId) {
        mismatchReasons.add('target_assistito_id_mismatch');
      }
      if (_readBool(targetData['generatedNoCf']) != false) {
        mismatchReasons.add('target_generated_nocf_not_false');
      }
      if (legacyNoCfCode.isEmpty) {
        mismatchReasons.add('target_legacy_nocf_code_missing');
      }
      if (!_hasAcceptedResolutionState(
        rootStatus: identityResolutionStatus,
        nestedStatus: nestedIdentityResolutionStatus,
        nameSplitConfidence: nameSplitConfidence,
      )) {
        mismatchReasons.add('target_identity_resolution_state_invalid');
      }
      if (_hasIdentityContamination(<String>[nome, cognome, fullName, ...searchPrefixes])) {
        mismatchReasons.add('target_identity_contains_cf_token');
      }
      if (!_fullNameIsCanonicalForResolutionState(
        nome: nome,
        cognome: cognome,
        fullName: fullName,
        identityResolutionStatus: identityResolutionStatus,
        nestedIdentityResolutionStatus: nestedIdentityResolutionStatus,
        nameSplitConfidence: nameSplitConfidence,
      )) {
        mismatchReasons.add('target_full_name_not_canonical');
      }
      if (!_searchPrefixesMatchFullName(fullName: fullName, searchPrefixes: searchPrefixes)) {
        mismatchReasons.add('target_search_prefixes_mismatch');
      }
    }

    if (legacyNoCfCode.isNotEmpty) {
      if (_readString(identityLockData['legacyNoCfCode']) != legacyNoCfCode) {
        mismatchReasons.add('identity_lock_legacy_nocf_code_mismatch');
      }
      if (_readString(cfLockData['legacyNoCfCode']) != legacyNoCfCode) {
        mismatchReasons.add('cf_lock_legacy_nocf_code_mismatch');
      }
    }

    return RealAssistitiNoCfPostResolutionVerificationItem(
      identityAnchor: normalizedIdentityAnchor,
      assistitoId: assistitoId,
      assistitoPath: assistitoPath,
      identityLockPath: identityLockPath,
      cfLockPath: cfLockPath,
      targetExists: targetExists,
      identityLockExists: identityLockExists,
      cfLockExists: cfLockExists,
      identityType: identityType,
      cf: cf,
      legacyNoCfCode: legacyNoCfCode,
      identityResolutionStatus: identityResolutionStatus,
      nestedIdentityResolutionStatus: nestedIdentityResolutionStatus,
      nameSplitConfidence: nameSplitConfidence,
      nome: nome,
      cognome: cognome,
      fullName: fullName,
      searchPrefixes: searchPrefixes,
      mismatchReasons: List<String>.unmodifiable(mismatchReasons),
    );
  }

  static RealAssistitiNoCfPostResolutionVerificationSummary buildSummary({
    required int requestedCount,
    required List<RealAssistitiNoCfPostResolutionVerificationItem> items,
  }) {
    int verifiedCount = 0;
    int failedCount = 0;
    final Map<String, int> mismatchReasonCounts = <String, int>{};
    for (final RealAssistitiNoCfPostResolutionVerificationItem item in items) {
      if (item.verified) verifiedCount++;
      if (item.failed) failedCount++;
      for (final String reason in item.mismatchReasons) {
        mismatchReasonCounts[reason] = (mismatchReasonCounts[reason] ?? 0) + 1;
      }
    }
    return RealAssistitiNoCfPostResolutionVerificationSummary(
      requestedCount: requestedCount,
      verifiedCount: verifiedCount,
      failedCount: failedCount,
      mismatchReasonCounts: Map<String, int>.unmodifiable(mismatchReasonCounts),
    );
  }

  static List<String> normalizeIdentityAnchors(Iterable<String> values) {
    final List<String> normalized = <String>[];
    for (final String value in values) {
      final String anchor = _normalizeIdentityAnchor(value);
      if (!normalized.contains(anchor)) {
        normalized.add(anchor);
      }
    }
    if (normalized.isEmpty) {
      throw const RealAssistitiNoCfPostResolutionVerifierRejectedException(
        code: 'identity_anchors_empty',
        message: 'Almeno un identityAnchor NOCF è obbligatorio per la verifica.',
      );
    }
    if (normalized.length > maxIdentityAnchorsPerRun) {
      throw const RealAssistitiNoCfPostResolutionVerifierRejectedException(
        code: 'identity_anchors_exceed_hard_cap',
        message: 'Troppi identityAnchor NOCF per una singola verifica bounded.',
      );
    }
    return List<String>.unmodifiable(normalized);
  }

  static void _verifyLockPayload({
    required String lockLabel,
    required String expectedIdentityAnchor,
    required String expectedAssistitoId,
    required String expectedAssistitoPath,
    required Map<String, dynamic> payload,
    required List<String> mismatchReasons,
  }) {
    if (payload.isEmpty) return;
    if (_readString(payload['identityAnchor']) != expectedIdentityAnchor) {
      mismatchReasons.add('${lockLabel}_identity_anchor_mismatch');
    }
    if (_readString(payload['cf']) != expectedIdentityAnchor) {
      mismatchReasons.add('${lockLabel}_cf_mismatch');
    }
    if (_readString(payload['identityType']) != TargetAssistitoNoCfIdentityAnchorNormalizer.identityTypeNoCf) {
      mismatchReasons.add('${lockLabel}_identity_type_not_nocf');
    }
    if (expectedAssistitoId.isNotEmpty && _readString(payload['assistitoId']) != expectedAssistitoId) {
      mismatchReasons.add('${lockLabel}_assistito_id_mismatch');
    }
    if (expectedAssistitoPath.isNotEmpty && _readString(payload['assistitoPath']) != expectedAssistitoPath) {
      mismatchReasons.add('${lockLabel}_assistito_path_mismatch');
    }
    if (_readInt(payload['lockVersion']) != 1) {
      mismatchReasons.add('${lockLabel}_version_mismatch');
    }
  }

  static bool _hasAcceptedResolutionState({
    required String rootStatus,
    required String nestedStatus,
    required String nameSplitConfidence,
  }) {
    if (!_isManualResolutionStatus(rootStatus) || !_isManualResolutionStatus(nestedStatus)) {
      return false;
    }
    if (rootStatus != nestedStatus) {
      return false;
    }
    return _confidenceMatchesResolutionStatus(
      status: rootStatus,
      nameSplitConfidence: nameSplitConfidence,
    );
  }

  static bool _isManualResolutionStatus(String value) {
    return value == resolvedManualStatus || value == pendingManualStatus;
  }

  static bool _confidenceMatchesResolutionStatus({
    required String status,
    required String nameSplitConfidence,
  }) {
    if (status == resolvedManualStatus) {
      return nameSplitConfidence == resolvedManualConfidence;
    }
    if (status == pendingManualStatus) {
      return nameSplitConfidence == pendingManualConfidence;
    }
    return false;
  }

  static bool _fullNameIsCanonicalForResolutionState({
    required String nome,
    required String cognome,
    required String fullName,
    required String identityResolutionStatus,
    required String nestedIdentityResolutionStatus,
    required String nameSplitConfidence,
  }) {
    if (fullName.trim().isEmpty) {
      return nameSplitConfidence == pendingManualConfidence;
    }
    final String normalizedFullName = TargetAssistitoIdentityNormalizer.normalizeFullName(fullName);
    if (normalizedFullName != fullName.trim()) {
      return false;
    }
    final bool resolved = identityResolutionStatus == resolvedManualStatus &&
        nestedIdentityResolutionStatus == resolvedManualStatus &&
        nameSplitConfidence == resolvedManualConfidence;
    if (!resolved) {
      return true;
    }
    try {
      final String expected = RealAssistitiNoCfIdentityResolutionWriter.buildCanonicalFullName(
        nome: nome,
        cognome: cognome,
      );
      return expected == fullName.trim();
    } on RealAssistitiNoCfIdentityResolutionRejectedException {
      return false;
    }
  }

  static bool _searchPrefixesMatchFullName({
    required String fullName,
    required List<String> searchPrefixes,
  }) {
    if (fullName.trim().isEmpty) {
      return searchPrefixes.isEmpty;
    }
    final List<String> expected = RealAssistitiTargetPreviewMapper.buildSearchPrefixes(fullName);
    if (expected.length != searchPrefixes.length) return false;
    for (int index = 0; index < expected.length; index++) {
      if (expected[index] != searchPrefixes[index]) return false;
    }
    return true;
  }

  static bool _hasIdentityContamination(Iterable<String> values) {
    for (final String value in values) {
      if (TargetAssistitoIdentityNormalizer.isFiscalCodeLike(value) ||
          TargetAssistitoIdentityNormalizer.containsFiscalCodeLikeToken(value)) {
        return true;
      }
    }
    return false;
  }

  static String _normalizeIdentityAnchor(String value) {
    final String normalized = value.trim().replaceAll(RegExp(r'\s+'), '_').toUpperCase();
    if (!TargetAssistitoNoCfIdentityAnchorNormalizer.isCanonicalNoCf(normalized)) {
      throw RealAssistitiNoCfPostResolutionVerifierRejectedException(
        code: 'identity_anchor_not_canonical_nocf',
        message: 'identityAnchor NOCF non canonico: $value.',
      );
    }
    return normalized;
  }

  static String _normalizeSegment(String value, {required String label}) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw RealAssistitiNoCfPostResolutionVerifierRejectedException(
        code: '${label}_empty',
        message: '$label obbligatorio per verifica NOCF post-risoluzione.',
      );
    }
    if (normalized.contains('/')) {
      throw RealAssistitiNoCfPostResolutionVerifierRejectedException(
        code: '${label}_not_canonical',
        message: '$label non canonico: slash non ammesso.',
      );
    }
    return normalized;
  }

  static String _readNestedStatus(Object? value) {
    if (value is Map<String, dynamic>) return _readString(value['status']);
    if (value is Map) return _readString(value['status']);
    return '';
  }

  static List<String> _readStringList(Object? value) {
    if (value is! Iterable) return const <String>[];
    return List<String>.unmodifiable(
      value
          .map((Object? item) => _readString(item))
          .where((String item) => item.isNotEmpty),
    );
  }

  static String _firstNonEmptyString(Iterable<Object?> values) {
    for (final Object? value in values) {
      final String stringValue = _readString(value);
      if (stringValue.isNotEmpty) return stringValue;
    }
    return '';
  }

  static String _readString(Object? value) {
    return value?.toString().trim() ?? '';
  }

  static bool? _readBool(Object? value) {
    if (value is bool) return value;
    if (value is String) {
      final String normalized = value.trim().toLowerCase();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
    return null;
  }

  static int _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
