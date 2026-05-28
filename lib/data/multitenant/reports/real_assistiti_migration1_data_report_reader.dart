import 'package:cloud_firestore/cloud_firestore.dart';

import '../mappers/real_assistiti_target_preview_mapper.dart';
import '../models/target_multitenant_collections.dart';
import '../normalizers/target_assistito_identity_normalizer.dart';
import '../normalizers/target_assistito_nocf_identity_anchor_normalizer.dart';
import '../verifiers/real_assistiti_nocf_post_resolution_verifier.dart';
import '../writers/real_assistiti_nocf_identity_resolution_writer.dart';

class RealAssistitiMigration1DataReportRejectedException implements Exception {
  final String code;
  final String message;

  const RealAssistitiMigration1DataReportRejectedException({
    required this.code,
    required this.message,
  });

  @override
  String toString() {
    return 'RealAssistitiMigration1DataReportRejectedException($code): $message';
  }
}

class RealAssistitiMigration1DataReportItem {
  final String assistitoId;
  final String documentPath;
  final String identityType;
  final String cf;
  final String identityAnchor;
  final String legacyNoCfCode;
  final bool generatedNoCf;
  final String identityResolutionStatus;
  final String nestedIdentityResolutionStatus;
  final String nameSplitConfidence;
  final String nome;
  final String cognome;
  final String fullName;
  final List<String> searchPrefixes;
  final List<String> mismatchReasons;

  const RealAssistitiMigration1DataReportItem({
    required this.assistitoId,
    required this.documentPath,
    required this.identityType,
    required this.cf,
    required this.identityAnchor,
    required this.legacyNoCfCode,
    required this.generatedNoCf,
    required this.identityResolutionStatus,
    required this.nestedIdentityResolutionStatus,
    required this.nameSplitConfidence,
    required this.nome,
    required this.cognome,
    required this.fullName,
    required this.searchPrefixes,
    required this.mismatchReasons,
  });

  bool get isCf => identityType == TargetAssistitoNoCfIdentityAnchorNormalizer.identityTypeCf;

  bool get isNoCf => identityType == TargetAssistitoNoCfIdentityAnchorNormalizer.identityTypeNoCf;

  bool get verified => mismatchReasons.isEmpty;

  bool get failed => !verified;

  bool get resolvedManual =>
      identityResolutionStatus == RealAssistitiNoCfPostResolutionVerifier.resolvedManualStatus &&
      nestedIdentityResolutionStatus == RealAssistitiNoCfPostResolutionVerifier.resolvedManualStatus;

  bool get pendingManual =>
      identityResolutionStatus == RealAssistitiNoCfPostResolutionVerifier.pendingManualStatus &&
      nestedIdentityResolutionStatus == RealAssistitiNoCfPostResolutionVerifier.pendingManualStatus;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'assistitoId': assistitoId,
      'documentPath': documentPath,
      'verified': verified,
      'failed': failed,
      'mismatchReasons': mismatchReasons,
      'identityType': identityType,
      'cf': cf,
      'identityAnchor': identityAnchor,
      'legacyNoCfCode': legacyNoCfCode,
      'generatedNoCf': generatedNoCf,
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

class RealAssistitiMigration1DataReportSummary {
  final int scannedCount;
  final int cfCount;
  final int noCfCount;
  final int unknownIdentityTypeCount;
  final int verifiedCount;
  final int failedCount;
  final int resolvedManualCount;
  final int pendingManualCount;
  final int resolvedAutoCount;
  final int noCfWithLegacyCodeCount;
  final int noCfMissingLegacyCodeCount;
  final int contaminatedIdentityCount;
  final int staleSearchPrefixesCount;
  final Map<String, int> mismatchReasonCounts;

  const RealAssistitiMigration1DataReportSummary({
    required this.scannedCount,
    required this.cfCount,
    required this.noCfCount,
    required this.unknownIdentityTypeCount,
    required this.verifiedCount,
    required this.failedCount,
    required this.resolvedManualCount,
    required this.pendingManualCount,
    required this.resolvedAutoCount,
    required this.noCfWithLegacyCodeCount,
    required this.noCfMissingLegacyCodeCount,
    required this.contaminatedIdentityCount,
    required this.staleSearchPrefixesCount,
    required this.mismatchReasonCounts,
  });

  bool get allScannedVerified => scannedCount > 0 && failedCount == 0 && verifiedCount == scannedCount;

  bool get hasFailures => !allScannedVerified;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'scannedCount': scannedCount,
      'cfCount': cfCount,
      'noCfCount': noCfCount,
      'unknownIdentityTypeCount': unknownIdentityTypeCount,
      'verifiedCount': verifiedCount,
      'failedCount': failedCount,
      'allScannedVerified': allScannedVerified,
      'hasFailures': hasFailures,
      'resolvedManualCount': resolvedManualCount,
      'pendingManualCount': pendingManualCount,
      'resolvedAutoCount': resolvedAutoCount,
      'noCfWithLegacyCodeCount': noCfWithLegacyCodeCount,
      'noCfMissingLegacyCodeCount': noCfMissingLegacyCodeCount,
      'contaminatedIdentityCount': contaminatedIdentityCount,
      'staleSearchPrefixesCount': staleSearchPrefixesCount,
      'mismatchReasonCounts': mismatchReasonCounts,
    };
  }
}

class RealAssistitiMigration1DataReportResult {
  final String tenantId;
  final String assistitiCollectionPath;
  final int maxAssistitiScan;
  final int maxNoCfLockVerification;
  final int attemptedAssistitiReads;
  final RealAssistitiNoCfPostResolutionVerificationResult? noCfLockVerification;
  final List<RealAssistitiMigration1DataReportItem> items;
  final RealAssistitiMigration1DataReportSummary summary;

  const RealAssistitiMigration1DataReportResult({
    required this.tenantId,
    required this.assistitiCollectionPath,
    required this.maxAssistitiScan,
    required this.maxNoCfLockVerification,
    required this.attemptedAssistitiReads,
    required this.noCfLockVerification,
    required this.items,
    required this.summary,
  });

  int get noCfLockVerificationReads => noCfLockVerification?.totalAttemptedReads ?? 0;

  int get totalAttemptedReads => attemptedAssistitiReads + noCfLockVerificationReads;

  bool get allScannedVerified => summary.allScannedVerified &&
      (noCfLockVerification == null || noCfLockVerification!.allVerified);

  bool get hasFailures => !allScannedVerified;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tenantId': tenantId,
      'assistitiCollectionPath': assistitiCollectionPath,
      'maxAssistitiScan': maxAssistitiScan,
      'maxNoCfLockVerification': maxNoCfLockVerification,
      'attemptedAssistitiReads': attemptedAssistitiReads,
      'noCfLockVerificationReads': noCfLockVerificationReads,
      'totalAttemptedReads': totalAttemptedReads,
      'allScannedVerified': allScannedVerified,
      'hasFailures': hasFailures,
      'summary': summary.toMap(),
      if (noCfLockVerification != null) 'noCfLockVerification': noCfLockVerification!.toMap(),
      'items': items
          .map((RealAssistitiMigration1DataReportItem item) => item.toMap())
          .toList(growable: false),
    };
  }
}

class RealAssistitiMigration1DataReportReader {
  static const int defaultMaxAssistitiScan = 50;
  static const int hardMaxAssistitiScan = 100;
  static const int defaultMaxNoCfLockVerification = 5;

  final FirebaseFirestore firestore;

  const RealAssistitiMigration1DataReportReader({
    required this.firestore,
  });

  Future<RealAssistitiMigration1DataReportResult> readReport({
    required String tenantId,
    int maxAssistitiScan = defaultMaxAssistitiScan,
    int maxNoCfLockVerification = defaultMaxNoCfLockVerification,
  }) async {
    final String normalizedTenantId = normalizeTenantId(tenantId);
    final int safeMaxAssistitiScan = normalizeMaxAssistitiScan(maxAssistitiScan);
    final int safeMaxNoCfLockVerification = normalizeMaxNoCfLockVerification(maxNoCfLockVerification);
    final String assistitiCollectionPath = TargetMultitenantCollections.tenantCollection(
      tenantId: normalizedTenantId,
      collectionId: TargetMultitenantCollections.assistiti,
    );

    final QuerySnapshot<Map<String, dynamic>> snapshot = await firestore
        .collection(assistitiCollectionPath)
        .limit(safeMaxAssistitiScan)
        .get(const GetOptions(source: Source.serverAndCache));

    final List<RealAssistitiMigration1DataReportItem> items =
        <RealAssistitiMigration1DataReportItem>[];
    for (final QueryDocumentSnapshot<Map<String, dynamic>> document in snapshot.docs) {
      items.add(buildItemFromRawData(
        tenantId: normalizedTenantId,
        documentId: document.id,
        rawData: document.data(),
      ));
    }

    final List<String> noCfAnchorsToVerify = selectNoCfAnchorsForLockVerification(
      items: items,
      maxNoCfLockVerification: safeMaxNoCfLockVerification,
    );
    RealAssistitiNoCfPostResolutionVerificationResult? noCfLockVerification;
    if (noCfAnchorsToVerify.isNotEmpty) {
      noCfLockVerification = await RealAssistitiNoCfPostResolutionVerifier(
        firestore: firestore,
      ).verifyIdentityAnchors(
        tenantId: normalizedTenantId,
        identityAnchors: noCfAnchorsToVerify,
      );
    }

    return RealAssistitiMigration1DataReportResult(
      tenantId: normalizedTenantId,
      assistitiCollectionPath: assistitiCollectionPath,
      maxAssistitiScan: safeMaxAssistitiScan,
      maxNoCfLockVerification: safeMaxNoCfLockVerification,
      attemptedAssistitiReads: snapshot.docs.length,
      noCfLockVerification: noCfLockVerification,
      items: List<RealAssistitiMigration1DataReportItem>.unmodifiable(items),
      summary: buildSummary(items),
    );
  }

  static RealAssistitiMigration1DataReportItem buildItemFromRawData({
    required String tenantId,
    required String documentId,
    required Map<String, dynamic> rawData,
  }) {
    final String normalizedTenantId = normalizeTenantId(tenantId);
    final String assistitoId = _readString(rawData['assistitoId']).isNotEmpty
        ? _readString(rawData['assistitoId'])
        : _normalizeSegment(documentId, label: 'documentId');
    final String documentPath = TargetMultitenantCollections.assistitoDocument(
      tenantId: normalizedTenantId,
      assistitoId: assistitoId,
    );
    final String identityType = _readString(rawData['identityType']);
    final String cf = _readString(rawData['cf']);
    final String identityAnchor = _readString(rawData['identityAnchor']);
    final String legacyNoCfCode = _readString(rawData['legacyNoCfCode']);
    final bool generatedNoCf = _readBool(rawData['generatedNoCf']);
    final String identityResolutionStatus = _readString(rawData['identityResolutionStatus']);
    final String nestedIdentityResolutionStatus = _readNestedStatus(rawData['identityResolution']);
    final String nameSplitConfidence = _readString(rawData['nameSplitConfidence']);
    final String nome = _readString(rawData['nome']);
    final String cognome = _readString(rawData['cognome']);
    final String fullName = _readString(rawData['fullName']);
    final List<String> searchPrefixes = _readStringList(rawData['searchPrefixes']);

    final List<String> mismatchReasons = <String>[];
    if (_readString(rawData['assistitoId']).isNotEmpty && _readString(rawData['assistitoId']) != documentId) {
      mismatchReasons.add('payload_assistito_id_differs_from_document_id');
    }
    if (identityType == TargetAssistitoNoCfIdentityAnchorNormalizer.identityTypeNoCf) {
      _verifyNoCfPayload(
        cf: cf,
        identityAnchor: identityAnchor,
        legacyNoCfCode: legacyNoCfCode,
        generatedNoCf: generatedNoCf,
        identityResolutionStatus: identityResolutionStatus,
        nestedIdentityResolutionStatus: nestedIdentityResolutionStatus,
        nameSplitConfidence: nameSplitConfidence,
        nome: nome,
        cognome: cognome,
        fullName: fullName,
        searchPrefixes: searchPrefixes,
        mismatchReasons: mismatchReasons,
      );
    } else if (identityType == TargetAssistitoNoCfIdentityAnchorNormalizer.identityTypeCf) {
      _verifyCfPayload(
        cf: cf,
        identityAnchor: identityAnchor,
        nome: nome,
        cognome: cognome,
        fullName: fullName,
        searchPrefixes: searchPrefixes,
        mismatchReasons: mismatchReasons,
      );
    } else {
      mismatchReasons.add('target_identity_type_unknown');
    }

    return RealAssistitiMigration1DataReportItem(
      assistitoId: assistitoId,
      documentPath: documentPath,
      identityType: identityType,
      cf: cf,
      identityAnchor: identityAnchor,
      legacyNoCfCode: legacyNoCfCode,
      generatedNoCf: generatedNoCf,
      identityResolutionStatus: identityResolutionStatus,
      nestedIdentityResolutionStatus: nestedIdentityResolutionStatus,
      nameSplitConfidence: nameSplitConfidence,
      nome: nome,
      cognome: cognome,
      fullName: fullName,
      searchPrefixes: List<String>.unmodifiable(searchPrefixes),
      mismatchReasons: List<String>.unmodifiable(mismatchReasons),
    );
  }

  static RealAssistitiMigration1DataReportSummary buildSummary(
    List<RealAssistitiMigration1DataReportItem> items,
  ) {
    int cfCount = 0;
    int noCfCount = 0;
    int unknownIdentityTypeCount = 0;
    int verifiedCount = 0;
    int failedCount = 0;
    int resolvedManualCount = 0;
    int pendingManualCount = 0;
    int resolvedAutoCount = 0;
    int noCfWithLegacyCodeCount = 0;
    int noCfMissingLegacyCodeCount = 0;
    int contaminatedIdentityCount = 0;
    int staleSearchPrefixesCount = 0;
    final Map<String, int> mismatchReasonCounts = <String, int>{};

    for (final RealAssistitiMigration1DataReportItem item in items) {
      if (item.isCf) cfCount++;
      if (item.isNoCf) noCfCount++;
      if (!item.isCf && !item.isNoCf) unknownIdentityTypeCount++;
      if (item.verified) verifiedCount++;
      if (item.failed) failedCount++;
      if (item.resolvedManual) resolvedManualCount++;
      if (item.pendingManual) pendingManualCount++;
      if (item.identityResolutionStatus == 'resolved_auto') resolvedAutoCount++;
      if (item.isNoCf && item.legacyNoCfCode.isNotEmpty) noCfWithLegacyCodeCount++;
      if (item.isNoCf && item.legacyNoCfCode.isEmpty) noCfMissingLegacyCodeCount++;
      if (item.mismatchReasons.contains('target_identity_contains_cf_token')) {
        contaminatedIdentityCount++;
      }
      if (item.mismatchReasons.contains('target_search_prefixes_mismatch')) {
        staleSearchPrefixesCount++;
      }
      for (final String reason in item.mismatchReasons) {
        mismatchReasonCounts[reason] = (mismatchReasonCounts[reason] ?? 0) + 1;
      }
    }

    return RealAssistitiMigration1DataReportSummary(
      scannedCount: items.length,
      cfCount: cfCount,
      noCfCount: noCfCount,
      unknownIdentityTypeCount: unknownIdentityTypeCount,
      verifiedCount: verifiedCount,
      failedCount: failedCount,
      resolvedManualCount: resolvedManualCount,
      pendingManualCount: pendingManualCount,
      resolvedAutoCount: resolvedAutoCount,
      noCfWithLegacyCodeCount: noCfWithLegacyCodeCount,
      noCfMissingLegacyCodeCount: noCfMissingLegacyCodeCount,
      contaminatedIdentityCount: contaminatedIdentityCount,
      staleSearchPrefixesCount: staleSearchPrefixesCount,
      mismatchReasonCounts: Map<String, int>.unmodifiable(mismatchReasonCounts),
    );
  }

  static List<String> selectNoCfAnchorsForLockVerification({
    required List<RealAssistitiMigration1DataReportItem> items,
    required int maxNoCfLockVerification,
  }) {
    final int safeLimit = normalizeMaxNoCfLockVerification(maxNoCfLockVerification);
    if (safeLimit == 0) {
      return const <String>[];
    }
    final List<String> anchors = <String>[];
    for (final RealAssistitiMigration1DataReportItem item in items) {
      if (!item.isNoCf) {
        continue;
      }
      if (!TargetAssistitoNoCfIdentityAnchorNormalizer.isCanonicalNoCf(item.identityAnchor)) {
        continue;
      }
      if (!anchors.contains(item.identityAnchor)) {
        anchors.add(item.identityAnchor);
      }
      if (anchors.length >= safeLimit) {
        break;
      }
    }
    return List<String>.unmodifiable(anchors);
  }

  static int normalizeMaxAssistitiScan(int value) {
    if (value <= 0) {
      return defaultMaxAssistitiScan;
    }
    if (value > hardMaxAssistitiScan) {
      return hardMaxAssistitiScan;
    }
    return value;
  }

  static int normalizeMaxNoCfLockVerification(int value) {
    if (value < 0) {
      return 0;
    }
    if (value > RealAssistitiNoCfPostResolutionVerifier.maxIdentityAnchorsPerRun) {
      return RealAssistitiNoCfPostResolutionVerifier.maxIdentityAnchorsPerRun;
    }
    return value;
  }

  static String normalizeTenantId(String value) {
    return _normalizeSegment(value, label: 'tenantId');
  }

  static void _verifyNoCfPayload({
    required String cf,
    required String identityAnchor,
    required String legacyNoCfCode,
    required bool generatedNoCf,
    required String identityResolutionStatus,
    required String nestedIdentityResolutionStatus,
    required String nameSplitConfidence,
    required String nome,
    required String cognome,
    required String fullName,
    required List<String> searchPrefixes,
    required List<String> mismatchReasons,
  }) {
    if (!TargetAssistitoNoCfIdentityAnchorNormalizer.isCanonicalNoCf(identityAnchor)) {
      mismatchReasons.add('target_nocf_identity_anchor_invalid');
    }
    if (cf != identityAnchor) {
      mismatchReasons.add('target_nocf_cf_identity_anchor_mismatch');
    }
    if (legacyNoCfCode.isEmpty) {
      mismatchReasons.add('target_nocf_legacy_code_missing');
    }
    if (generatedNoCf != false) {
      mismatchReasons.add('target_nocf_generated_flag_not_false');
    }
    if (!_hasAcceptedResolutionState(
      rootStatus: identityResolutionStatus,
      nestedStatus: nestedIdentityResolutionStatus,
      nameSplitConfidence: nameSplitConfidence,
    )) {
      mismatchReasons.add('target_nocf_resolution_state_invalid');
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

  static void _verifyCfPayload({
    required String cf,
    required String identityAnchor,
    required String nome,
    required String cognome,
    required String fullName,
    required List<String> searchPrefixes,
    required List<String> mismatchReasons,
  }) {
    if (!TargetAssistitoIdentityNormalizer.isFiscalCodeLike(cf)) {
      mismatchReasons.add('target_cf_not_canonical');
    }
    if (identityAnchor != cf) {
      mismatchReasons.add('target_cf_identity_anchor_mismatch');
    }
    if (_hasIdentityContamination(<String>[nome, cognome, fullName, ...searchPrefixes])) {
      mismatchReasons.add('target_identity_contains_cf_token');
    }
    if (!_searchPrefixesMatchFullName(fullName: fullName, searchPrefixes: searchPrefixes)) {
      mismatchReasons.add('target_search_prefixes_mismatch');
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
    if (rootStatus == RealAssistitiNoCfPostResolutionVerifier.resolvedManualStatus) {
      return nameSplitConfidence == RealAssistitiNoCfPostResolutionVerifier.resolvedManualConfidence;
    }
    if (rootStatus == RealAssistitiNoCfPostResolutionVerifier.pendingManualStatus) {
      return nameSplitConfidence == RealAssistitiNoCfPostResolutionVerifier.pendingManualConfidence;
    }
    return false;
  }

  static bool _isManualResolutionStatus(String value) {
    return value == RealAssistitiNoCfPostResolutionVerifier.resolvedManualStatus ||
        value == RealAssistitiNoCfPostResolutionVerifier.pendingManualStatus;
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
      return nameSplitConfidence == RealAssistitiNoCfPostResolutionVerifier.pendingManualConfidence;
    }
    final String normalizedFullName = TargetAssistitoIdentityNormalizer.normalizeFullName(fullName);
    if (normalizedFullName != fullName.trim()) {
      return false;
    }
    final bool resolved = identityResolutionStatus == RealAssistitiNoCfPostResolutionVerifier.resolvedManualStatus &&
        nestedIdentityResolutionStatus == RealAssistitiNoCfPostResolutionVerifier.resolvedManualStatus &&
        nameSplitConfidence == RealAssistitiNoCfPostResolutionVerifier.resolvedManualConfidence;
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
    if (expected.length != searchPrefixes.length) {
      return false;
    }
    for (int index = 0; index < expected.length; index++) {
      if (expected[index] != searchPrefixes[index]) {
        return false;
      }
    }
    return true;
  }

  static bool _hasIdentityContamination(List<String> values) {
    for (final String value in values) {
      if (TargetAssistitoIdentityNormalizer.containsFiscalCodeLikeToken(value) ||
          TargetAssistitoIdentityNormalizer.isFiscalCodeLike(value)) {
        return true;
      }
    }
    return false;
  }

  static String _normalizeSegment(String value, {required String label}) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw RealAssistitiMigration1DataReportRejectedException(
        code: '${label}_empty',
        message: '$label obbligatorio per report Migration 1 assistiti.',
      );
    }
    if (normalized.contains('/') || normalized.contains('\\')) {
      throw RealAssistitiMigration1DataReportRejectedException(
        code: '${label}_not_canonical',
        message: '$label non canonico: slash non ammesso.',
      );
    }
    return normalized;
  }

  static String _readNestedStatus(Object? value) {
    if (value is Map<String, dynamic>) {
      return _readString(value['status']);
    }
    if (value is Map) {
      return _readString(value['status']);
    }
    return '';
  }

  static List<String> _readStringList(Object? value) {
    if (value is! Iterable) {
      return const <String>[];
    }
    return List<String>.unmodifiable(
      value
          .map((Object? item) => _readString(item))
          .where((String item) => item.isNotEmpty)
          .toList(growable: false),
    );
  }

  static String _readString(Object? value) {
    return value?.toString().trim() ?? '';
  }

  static bool _readBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      return value.trim().toLowerCase() == 'true';
    }
    return false;
  }
}
