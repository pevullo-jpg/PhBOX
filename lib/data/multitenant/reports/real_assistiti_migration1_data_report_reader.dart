import '../mappers/real_assistiti_target_preview_mapper.dart';
import '../normalizers/target_assistito_identity_normalizer.dart';
import '../normalizers/target_assistito_nocf_identity_anchor_normalizer.dart';

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

class RealAssistitiMigration1DataReportRawDocument {
  final String documentId;
  final Map<String, dynamic> rawData;

  const RealAssistitiMigration1DataReportRawDocument({
    required this.documentId,
    required this.rawData,
  });
}

class RealAssistitiMigration1DataReportItem {
  final String documentId;
  final String assistitoId;
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
    required this.documentId,
    required this.assistitoId,
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

  bool get isNoCf =>
      identityType == TargetAssistitoNoCfIdentityAnchorNormalizer.identityTypeNoCf;

  bool get isCf =>
      identityType == TargetAssistitoNoCfIdentityAnchorNormalizer.identityTypeCf;

  bool get verified => mismatchReasons.isEmpty;

  bool get failed => !verified;

  bool get contaminated => mismatchReasons.contains('target_identity_contains_cf_token');

  bool get staleSearchPrefixes => mismatchReasons.contains('target_search_prefixes_mismatch');

  bool get resolvedManual =>
      identityResolutionStatus == RealAssistitiMigration1DataReportReader.resolvedManualStatus;

  bool get pendingManual =>
      identityResolutionStatus == RealAssistitiMigration1DataReportReader.pendingManualStatus;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'documentId': documentId,
      'assistitoId': assistitoId,
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
      'verified': verified,
      'failed': failed,
      'mismatchReasons': mismatchReasons,
    };
  }
}

class RealAssistitiMigration1DataReportSummary {
  final int inputDocumentCount;
  final int verifiedCount;
  final int failedCount;
  final int cfCount;
  final int noCfCount;
  final int resolvedManualCount;
  final int pendingManualCount;
  final int contaminatedIdentityCount;
  final int staleSearchPrefixesCount;
  final Map<String, int> mismatchReasonCounts;

  const RealAssistitiMigration1DataReportSummary({
    required this.inputDocumentCount,
    required this.verifiedCount,
    required this.failedCount,
    required this.cfCount,
    required this.noCfCount,
    required this.resolvedManualCount,
    required this.pendingManualCount,
    required this.contaminatedIdentityCount,
    required this.staleSearchPrefixesCount,
    required this.mismatchReasonCounts,
  });

  bool get allVerified => inputDocumentCount > 0 && failedCount == 0 && verifiedCount == inputDocumentCount;

  bool get hasFailures => !allVerified;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'inputDocumentCount': inputDocumentCount,
      'verifiedCount': verifiedCount,
      'failedCount': failedCount,
      'cfCount': cfCount,
      'noCfCount': noCfCount,
      'resolvedManualCount': resolvedManualCount,
      'pendingManualCount': pendingManualCount,
      'contaminatedIdentityCount': contaminatedIdentityCount,
      'staleSearchPrefixesCount': staleSearchPrefixesCount,
      'allVerified': allVerified,
      'hasFailures': hasFailures,
      'mismatchReasonCounts': mismatchReasonCounts,
    };
  }
}

class RealAssistitiMigration1DataReportResult {
  final String tenantId;
  final List<RealAssistitiMigration1DataReportItem> items;
  final RealAssistitiMigration1DataReportSummary summary;
  final int maxInputDocuments;
  final int maxSearchPrefixesPerDocument;
  final int firestoreReads;
  final int firestoreWrites;

  const RealAssistitiMigration1DataReportResult({
    required this.tenantId,
    required this.items,
    required this.summary,
    required this.maxInputDocuments,
    required this.maxSearchPrefixesPerDocument,
    required this.firestoreReads,
    required this.firestoreWrites,
  });

  bool get allVerified => summary.allVerified;

  bool get hasFailures => summary.hasFailures;

  List<String> get failedDocumentIds {
    return List<String>.unmodifiable(
      items
          .where((RealAssistitiMigration1DataReportItem item) => item.failed)
          .map((RealAssistitiMigration1DataReportItem item) => item.documentId),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tenantId': tenantId,
      'maxInputDocuments': maxInputDocuments,
      'maxSearchPrefixesPerDocument': maxSearchPrefixesPerDocument,
      'firestoreReads': firestoreReads,
      'firestoreWrites': firestoreWrites,
      'failedDocumentIds': failedDocumentIds,
      'summary': summary.toMap(),
      'items': items
          .map((RealAssistitiMigration1DataReportItem item) => item.toMap())
          .toList(growable: false),
    };
  }
}

class _BoundedStringListRead {
  final List<String> values;
  final bool exceeded;

  const _BoundedStringListRead({
    required this.values,
    required this.exceeded,
  });
}

class RealAssistitiMigration1DataReportReader {
  static const int maxInputDocuments = 100;
  static const int maxSearchPrefixesPerDocument = 64;
  static const int firestoreReadsPerRawReport = 0;
  static const int firestoreWritesPerRawReport = 0;
  static const String pendingManualStatus = 'pending_manual';
  static const String resolvedManualStatus = 'resolved_manual';
  static const String pendingManualConfidence = 'pending_manual_nocf_identity_resolution';
  static const String resolvedManualConfidence = 'resolved_manual_nocf_identity';

  const RealAssistitiMigration1DataReportReader._();

  static RealAssistitiMigration1DataReportResult buildReportFromRawDocuments({
    required String tenantId,
    required Iterable<RealAssistitiMigration1DataReportRawDocument> documents,
  }) {
    final String normalizedTenantId = _normalizeSegment(tenantId, label: 'tenantId');
    final List<RealAssistitiMigration1DataReportRawDocument> rawDocuments =
        _collectRawDocumentsBounded(documents);

    final List<RealAssistitiMigration1DataReportItem> items = <RealAssistitiMigration1DataReportItem>[];
    for (final RealAssistitiMigration1DataReportRawDocument document in rawDocuments) {
      items.add(verifyRawDocument(documentId: document.documentId, rawData: document.rawData));
    }

    return RealAssistitiMigration1DataReportResult(
      tenantId: normalizedTenantId,
      items: List<RealAssistitiMigration1DataReportItem>.unmodifiable(items),
      summary: buildSummary(items),
      maxInputDocuments: maxInputDocuments,
      maxSearchPrefixesPerDocument: maxSearchPrefixesPerDocument,
      firestoreReads: firestoreReadsPerRawReport,
      firestoreWrites: firestoreWritesPerRawReport,
    );
  }

  static List<RealAssistitiMigration1DataReportRawDocument> _collectRawDocumentsBounded(
    Iterable<RealAssistitiMigration1DataReportRawDocument> documents,
  ) {
    final List<RealAssistitiMigration1DataReportRawDocument> rawDocuments =
        <RealAssistitiMigration1DataReportRawDocument>[];
    for (final RealAssistitiMigration1DataReportRawDocument document in documents) {
      if (rawDocuments.length >= maxInputDocuments) {
        throw const RealAssistitiMigration1DataReportRejectedException(
          code: 'raw_documents_exceed_hard_cap',
          message: 'Troppi assistiti target per report Migration 1 bounded.',
        );
      }
      rawDocuments.add(document);
    }
    return List<RealAssistitiMigration1DataReportRawDocument>.unmodifiable(rawDocuments);
  }

  static RealAssistitiMigration1DataReportItem verifyRawDocument({
    required String documentId,
    required Map<String, dynamic> rawData,
  }) {
    final String normalizedDocumentId = _normalizeSegment(documentId, label: 'documentId');
    final String assistitoId = _readString(rawData['assistitoId']);
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
    final _BoundedStringListRead searchPrefixesRead = _readBoundedStringList(
      rawData['searchPrefixes'],
      maxItems: maxSearchPrefixesPerDocument,
    );
    final List<String> searchPrefixes = searchPrefixesRead.values;
    final List<String> mismatchReasons = <String>[];

    if (searchPrefixesRead.exceeded) {
      mismatchReasons.add('target_search_prefixes_unbounded');
    }
    if (assistitoId != normalizedDocumentId) {
      mismatchReasons.add('target_assistito_id_mismatch');
    }

    final bool looksNoCf = identityType == TargetAssistitoNoCfIdentityAnchorNormalizer.identityTypeNoCf ||
        TargetAssistitoNoCfIdentityAnchorNormalizer.isCanonicalNoCf(identityAnchor) ||
        TargetAssistitoNoCfIdentityAnchorNormalizer.isCanonicalNoCf(cf);
    if (looksNoCf) {
      _verifyNoCfPayload(
        cf: cf,
        identityType: identityType,
        identityAnchor: identityAnchor,
        legacyNoCfCode: legacyNoCfCode,
        generatedNoCf: generatedNoCf,
        rootStatus: identityResolutionStatus,
        nestedStatus: nestedIdentityResolutionStatus,
        nameSplitConfidence: nameSplitConfidence,
        nome: nome,
        cognome: cognome,
        fullName: fullName,
        searchPrefixes: searchPrefixes,
        mismatchReasons: mismatchReasons,
      );
    } else {
      _verifyCfPayload(
        cf: cf,
        identityType: identityType,
        identityAnchor: identityAnchor,
        nome: nome,
        cognome: cognome,
        fullName: fullName,
        searchPrefixes: searchPrefixes,
        mismatchReasons: mismatchReasons,
      );
    }

    return RealAssistitiMigration1DataReportItem(
      documentId: normalizedDocumentId,
      assistitoId: assistitoId,
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
      searchPrefixes: searchPrefixes,
      mismatchReasons: List<String>.unmodifiable(mismatchReasons),
    );
  }

  static RealAssistitiMigration1DataReportSummary buildSummary(
    List<RealAssistitiMigration1DataReportItem> items,
  ) {
    int verifiedCount = 0;
    int failedCount = 0;
    int cfCount = 0;
    int noCfCount = 0;
    int resolvedManualCount = 0;
    int pendingManualCount = 0;
    int contaminatedIdentityCount = 0;
    int staleSearchPrefixesCount = 0;
    final Map<String, int> mismatchReasonCounts = <String, int>{};

    for (final RealAssistitiMigration1DataReportItem item in items) {
      if (item.verified) verifiedCount++;
      if (item.failed) failedCount++;
      if (item.isCf) cfCount++;
      if (item.isNoCf) noCfCount++;
      if (item.resolvedManual) resolvedManualCount++;
      if (item.pendingManual) pendingManualCount++;
      if (item.contaminated) contaminatedIdentityCount++;
      if (item.staleSearchPrefixes) staleSearchPrefixesCount++;
      for (final String reason in item.mismatchReasons) {
        mismatchReasonCounts[reason] = (mismatchReasonCounts[reason] ?? 0) + 1;
      }
    }

    return RealAssistitiMigration1DataReportSummary(
      inputDocumentCount: items.length,
      verifiedCount: verifiedCount,
      failedCount: failedCount,
      cfCount: cfCount,
      noCfCount: noCfCount,
      resolvedManualCount: resolvedManualCount,
      pendingManualCount: pendingManualCount,
      contaminatedIdentityCount: contaminatedIdentityCount,
      staleSearchPrefixesCount: staleSearchPrefixesCount,
      mismatchReasonCounts: Map<String, int>.unmodifiable(mismatchReasonCounts),
    );
  }

  static void _verifyCfPayload({
    required String cf,
    required String identityType,
    required String identityAnchor,
    required String nome,
    required String cognome,
    required String fullName,
    required List<String> searchPrefixes,
    required List<String> mismatchReasons,
  }) {
    if (identityType != TargetAssistitoNoCfIdentityAnchorNormalizer.identityTypeCf) {
      mismatchReasons.add('target_identity_type_not_cf');
    }
    if (!TargetAssistitoIdentityNormalizer.isFiscalCodeLike(cf)) {
      mismatchReasons.add('target_cf_not_canonical');
    }
    if (identityAnchor != cf) {
      mismatchReasons.add('target_identity_anchor_mismatch');
    }
    if (_hasIdentityContamination(<String>[nome, cognome, fullName, ...searchPrefixes])) {
      mismatchReasons.add('target_identity_contains_cf_token');
    }
    if (!_searchPrefixesMatchFullName(fullName: fullName, searchPrefixes: searchPrefixes)) {
      mismatchReasons.add('target_search_prefixes_mismatch');
    }
  }

  static void _verifyNoCfPayload({
    required String cf,
    required String identityType,
    required String identityAnchor,
    required String legacyNoCfCode,
    required bool generatedNoCf,
    required String rootStatus,
    required String nestedStatus,
    required String nameSplitConfidence,
    required String nome,
    required String cognome,
    required String fullName,
    required List<String> searchPrefixes,
    required List<String> mismatchReasons,
  }) {
    if (identityType != TargetAssistitoNoCfIdentityAnchorNormalizer.identityTypeNoCf) {
      mismatchReasons.add('target_identity_type_not_nocf');
    }
    if (!TargetAssistitoNoCfIdentityAnchorNormalizer.isCanonicalNoCf(identityAnchor)) {
      mismatchReasons.add('target_identity_anchor_not_canonical_nocf');
    }
    if (cf != identityAnchor) {
      mismatchReasons.add('target_cf_identity_anchor_mismatch');
    }
    if (legacyNoCfCode.isEmpty) {
      mismatchReasons.add('target_legacy_nocf_code_missing');
    }
    if (generatedNoCf != false) {
      mismatchReasons.add('target_generated_nocf_not_false');
    }
    if (!_hasAcceptedManualResolutionState(
      rootStatus: rootStatus,
      nestedStatus: nestedStatus,
      nameSplitConfidence: nameSplitConfidence,
    )) {
      mismatchReasons.add('target_identity_resolution_state_invalid');
    }
    if (_hasIdentityContamination(<String>[nome, cognome, fullName, ...searchPrefixes])) {
      mismatchReasons.add('target_identity_contains_cf_token');
    }
    if (!_fullNameIsCanonicalForNoCfState(
      nome: nome,
      cognome: cognome,
      fullName: fullName,
      rootStatus: rootStatus,
      nestedStatus: nestedStatus,
      nameSplitConfidence: nameSplitConfidence,
    )) {
      mismatchReasons.add('target_full_name_not_canonical');
    }
    if (!_searchPrefixesMatchFullName(fullName: fullName, searchPrefixes: searchPrefixes)) {
      mismatchReasons.add('target_search_prefixes_mismatch');
    }
  }

  static bool _hasAcceptedManualResolutionState({
    required String rootStatus,
    required String nestedStatus,
    required String nameSplitConfidence,
  }) {
    if (!_isManualStatus(rootStatus) || !_isManualStatus(nestedStatus)) {
      return false;
    }
    if (rootStatus != nestedStatus) {
      return false;
    }
    if (rootStatus == resolvedManualStatus) {
      return nameSplitConfidence == resolvedManualConfidence;
    }
    if (rootStatus == pendingManualStatus) {
      return nameSplitConfidence == pendingManualConfidence;
    }
    return false;
  }

  static bool _isManualStatus(String value) {
    return value == resolvedManualStatus || value == pendingManualStatus;
  }

  static bool _fullNameIsCanonicalForNoCfState({
    required String nome,
    required String cognome,
    required String fullName,
    required String rootStatus,
    required String nestedStatus,
    required String nameSplitConfidence,
  }) {
    if (fullName.trim().isEmpty) {
      return rootStatus == pendingManualStatus &&
          nestedStatus == pendingManualStatus &&
          nameSplitConfidence == pendingManualConfidence;
    }
    final String normalizedFullName = TargetAssistitoIdentityNormalizer.normalizeFullName(fullName);
    if (normalizedFullName != fullName.trim()) {
      return false;
    }
    final bool resolved = rootStatus == resolvedManualStatus &&
        nestedStatus == resolvedManualStatus &&
        nameSplitConfidence == resolvedManualConfidence;
    if (!resolved) {
      return true;
    }
    final String expected = <String>[
      TargetAssistitoIdentityNormalizer.normalizeNamePart(cognome),
      TargetAssistitoIdentityNormalizer.normalizeNamePart(nome),
    ].where((String item) => item.isNotEmpty).join(' ').trim();
    return expected.isNotEmpty && expected == fullName.trim();
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
      if (TargetAssistitoIdentityNormalizer.containsFiscalCodeLikeToken(value) ||
          TargetAssistitoIdentityNormalizer.isFiscalCodeLike(value)) {
        return true;
      }
    }
    return false;
  }

  static _BoundedStringListRead _readBoundedStringList(Object? value, {required int maxItems}) {
    if (value is! Iterable) {
      return const _BoundedStringListRead(values: <String>[], exceeded: false);
    }
    final List<String> result = <String>[];
    int rawItemsSeen = 0;
    for (final Object? item in value) {
      rawItemsSeen++;
      if (rawItemsSeen > maxItems) {
        return _BoundedStringListRead(
          values: List<String>.unmodifiable(result),
          exceeded: true,
        );
      }
      final String prefix = _readSearchPrefix(item);
      if (prefix.trim().isEmpty) {
        continue;
      }
      result.add(prefix);
    }
    return _BoundedStringListRead(
      values: List<String>.unmodifiable(result),
      exceeded: false,
    );
  }

  static String _normalizeSegment(String value, {required String label}) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw RealAssistitiMigration1DataReportRejectedException(
        code: '${label}_empty',
        message: '$label obbligatorio per report Migration 1.',
      );
    }
    if (normalized.contains('/')) {
      throw RealAssistitiMigration1DataReportRejectedException(
        code: '${label}_not_canonical',
        message: '$label non canonico: slash non ammesso.',
      );
    }
    return normalized;
  }

  static String _readNestedStatus(Object? value) {
    if (value is Map) {
      return _readString(value['status']);
    }
    return '';
  }

  static String _readString(Object? value) {
    return value?.toString().trim() ?? '';
  }

  static String _readSearchPrefix(Object? value) {
    return value?.toString() ?? '';
  }

  static bool _readBool(Object? value) {
    if (value is bool) return value;
    if (value is String) return value.trim().toLowerCase() == 'true';
    return false;
  }
}
