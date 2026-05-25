import 'package:cloud_firestore/cloud_firestore.dart';

import '../normalizers/target_assistito_identity_normalizer.dart';
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

    final _ResolvedIdentity identity = _resolveIdentity(bundle);
    if (!identity.hasAnyAcceptedIdentityAnchor) {
      blockingReasons.add('target_identity_absent');
    }

    final DateTime createdAt = _resolveTimestamp(
      bundle: bundle,
      candidateKeys: const <String>['createdAt', 'creationTime', 'importedAt', 'firstSeenAt'],
      fallback: previewGeneratedAt,
    );

    final Map<String, dynamic> targetPreviewPayload = <String, dynamic>{
      'cf': bundle.cf,
      'fullName': identity.fullName,
      'cognome': identity.cognome,
      'nome': identity.nome,
      'createdAt': createdAt,
      'dashboard': _buildDashboardSnapshot(bundle.dashboardIndex.rawData, identity),
      'nameSplitConfidence': identity.nameSplitConfidence,
      'doctor': _buildDoctorPreview(bundle, identity),
      'therapeuticAdvice': _buildTherapeuticAdvicePreview(bundle.therapeuticAdvice.rawData),
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

  _ResolvedIdentity _resolveIdentity(LegacyRealAssistitoReadBundle bundle) {
    final String rawNome = _readFirstString(
      bundle.patient.rawData,
      const <String>['nome', 'firstName', 'givenName'],
    );
    final String rawCognome = _readFirstString(
      bundle.patient.rawData,
      const <String>['cognome', 'lastName', 'surname', 'familyName'],
    );

    final List<String> fullNameCandidates = <String>[
      _readFirstString(
        bundle.patient.rawData,
        const <String>['fullName', 'displayName', 'patientName', 'assistitoName', 'name'],
      ),
      _readFirstString(
        bundle.dashboardIndex.rawData,
        const <String>['fullName', 'displayName', 'patientName', 'assistitoName', 'name'],
      ),
      _readFirstString(
        bundle.therapeuticAdvice.rawData,
        const <String>['fullName', 'displayName', 'patientName', 'assistitoName', 'name'],
      ),
    ];

    final _IdentityCandidate? bestCandidate = _selectBestIdentityCandidate(
      cf: bundle.cf,
      rawNome: rawNome,
      rawCognome: rawCognome,
      rawFullNameCandidates: fullNameCandidates,
    );

    if (bestCandidate != null) {
      return _ResolvedIdentity(
        cf: TargetAssistitoIdentityNormalizer.normalizeCf(bundle.cf),
        nome: bestCandidate.nome,
        cognome: bestCandidate.cognome,
        fullName: bestCandidate.fullName,
        nameSplitConfidence: bestCandidate.nameSplitConfidence,
      );
    }

    return _ResolvedIdentity(
      cf: TargetAssistitoIdentityNormalizer.normalizeCf(bundle.cf),
      nome: '',
      cognome: '',
      fullName: '',
      nameSplitConfidence: 'cf_only',
    );
  }

  static _IdentityCandidate? _selectBestIdentityCandidate({
    required String cf,
    required String rawNome,
    required String rawCognome,
    required List<String> rawFullNameCandidates,
  }) {
    final String normalizedCf = TargetAssistitoIdentityNormalizer.normalizeCf(cf);
    final List<_IdentityCandidate> candidates = <_IdentityCandidate>[];
    final String explicitNome = TargetAssistitoIdentityNormalizer.normalizeNamePart(rawNome);
    final String explicitCognome = TargetAssistitoIdentityNormalizer.normalizeNamePart(rawCognome);

    for (final String rawFullName in rawFullNameCandidates) {
      final String fullName = TargetAssistitoIdentityNormalizer.normalizeFullName(rawFullName);
      if (fullName.isEmpty) {
        continue;
      }
      candidates.addAll(_splitFullNameCandidates(
        cf: normalizedCf,
        fullName: fullName,
        rawFullName: rawFullName,
      ));
      if (explicitNome.isNotEmpty || explicitCognome.isNotEmpty) {
        final String mergedFullName = _joinFullName(
          nome: explicitNome,
          cognome: explicitCognome,
          fallbackFullName: fullName,
        );
        candidates.add(_IdentityCandidate(
          cf: normalizedCf,
          nome: explicitNome,
          cognome: explicitCognome,
          fullName: mergedFullName,
          nameSplitConfidence: 'explicit_fields',
        ));
      }
    }

    if (candidates.isEmpty && (explicitNome.isNotEmpty || explicitCognome.isNotEmpty)) {
      candidates.add(_IdentityCandidate(
        cf: normalizedCf,
        nome: explicitNome,
        cognome: explicitCognome,
        fullName: _joinFullName(
          nome: explicitNome,
          cognome: explicitCognome,
          fallbackFullName: '',
        ),
        nameSplitConfidence: 'explicit_fields_without_full_name',
      ));
    }

    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((_IdentityCandidate left, _IdentityCandidate right) {
      final int scoreCompare = right.score.compareTo(left.score);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      final int tieBreakCompare = left.tieBreakPriority.compareTo(right.tieBreakPriority);
      if (tieBreakCompare != 0) {
        return tieBreakCompare;
      }
      return left.nameSplitConfidence.compareTo(right.nameSplitConfidence);
    });
    return candidates.first;
  }

  static List<_IdentityCandidate> _splitFullNameCandidates({
    required String cf,
    required String fullName,
    required String rawFullName,
  }) {
    final List<String> parts = fullName
        .trim()
        .split(' ')
        .where((String item) => item.trim().isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return const <_IdentityCandidate>[];
    }
    if (parts.length == 1) {
      return <_IdentityCandidate>[
        _IdentityCandidate(
          cf: cf,
          nome: '',
          cognome: '',
          fullName: fullName,
          nameSplitConfidence: 'full_name_only',
        ),
      ];
    }

    final bool preferSurnameFirstOnTie = _looksAllUppercaseHumanName(rawFullName);
    final Set<String> seen = <String>{};
    final List<_IdentityCandidate> candidates = <_IdentityCandidate>[];
    void addCandidate(String nome, String cognome, String confidence) {
      final String normalizedNome = TargetAssistitoIdentityNormalizer.normalizeNamePart(nome);
      final String normalizedCognome = TargetAssistitoIdentityNormalizer.normalizeNamePart(cognome);
      final String key = '$normalizedNome|$normalizedCognome|$fullName';
      if (seen.add(key)) {
        candidates.add(_IdentityCandidate(
          cf: cf,
          nome: normalizedNome,
          cognome: normalizedCognome,
          fullName: fullName,
          nameSplitConfidence: confidence,
          preferSurnameFirstOnTie: preferSurnameFirstOnTie,
        ));
      }
    }

    addCandidate(parts.first, parts.skip(1).join(' '), 'derived_from_full_name_name_first');
    addCandidate(parts.skip(1).join(' '), parts.first, 'derived_from_full_name_surname_first');
    addCandidate(parts.take(parts.length - 1).join(' '), parts.last, 'derived_from_full_name_last_surname');
    addCandidate(parts.last, parts.take(parts.length - 1).join(' '), 'derived_from_full_name_last_name');

    return List<_IdentityCandidate>.unmodifiable(candidates);
  }

  static String _joinFullName({
    required String nome,
    required String cognome,
    required String fallbackFullName,
  }) {
    final String joined = <String>[nome, cognome]
        .where((String item) => item.trim().isNotEmpty)
        .join(' ')
        .trim();
    if (joined.isNotEmpty) {
      return joined;
    }
    return TargetAssistitoIdentityNormalizer.normalizeFullName(fallbackFullName);
  }

  static Map<String, dynamic> _buildDoctorPreview(
    LegacyRealAssistitoReadBundle bundle,
    _ResolvedIdentity identity,
  ) {
    final Map<String, dynamic> manual = _sanitizeDoctorManualFields(
      bundle.doctorManual.rawData,
      identity,
    );
    if (manual.isEmpty) {
      return const <String, dynamic>{};
    }
    return Map<String, dynamic>.unmodifiable(<String, dynamic>{
      'manual': manual,
    });
  }

  static Map<String, dynamic> _sanitizeDoctorManualFields(
    Map<String, dynamic> rawData,
    _ResolvedIdentity identity,
  ) {
    if (rawData.isEmpty) {
      return const <String, dynamic>{};
    }

    final Map<String, dynamic> sanitized = <String, dynamic>{};
    final String doctorFullName = _readFirstString(rawData, const <String>['doctorFullName']);
    final String doctorName = _readFirstString(rawData, const <String>['doctorName']);

    if (doctorFullName.isNotEmpty && !_containsPatientIdentityEcho(doctorFullName, identity)) {
      sanitized['doctorFullName'] = doctorFullName;
    }
    if (doctorName.isNotEmpty && !_containsPatientIdentityEcho(doctorName, identity)) {
      sanitized['doctorName'] = doctorName;
    }
    return Map<String, dynamic>.unmodifiable(sanitized);
  }

  static Map<String, dynamic> _buildDashboardSnapshot(
    Map<String, dynamic> rawData,
    _ResolvedIdentity identity,
  ) {
    if (rawData.isEmpty) {
      return const <String, dynamic>{};
    }

    const List<String> allowedKeys = <String>[
      'advanceCount',
      'bookingCount',
      'debtAmount',
      'debtCount',
      'exemptionCode',
      'exemptions',
      'hasAdvance',
      'hasBooking',
      'hasDebt',
      'hasDpc',
      'hasExpiry',
      'hasRecipes',
      'lastPrescriptionDate',
      'nearestExpiryDate',
      'recipeCount',
    ];

    final Map<String, dynamic> sanitized = <String, dynamic>{};
    for (final String key in allowedKeys) {
      if (!rawData.containsKey(key)) {
        continue;
      }
      final Object? value = rawData[key];
      if (_containsPatientIdentityEcho(value, identity)) {
        continue;
      }
      sanitized[key] = value;
    }
    return Map<String, dynamic>.unmodifiable(sanitized);
  }

  static Map<String, dynamic> _buildTherapeuticAdvicePreview(Map<String, dynamic> rawData) {
    if (rawData.isEmpty || !rawData.containsKey('updatedAt')) {
      return const <String, dynamic>{};
    }
    return Map<String, dynamic>.unmodifiable(<String, dynamic>{
      'updatedAt': rawData['updatedAt'],
    });
  }

  static bool _containsPatientIdentityEcho(Object? value, _ResolvedIdentity identity) {
    if (value == null) {
      return false;
    }
    if (value is Map) {
      return value.values.any((Object? item) => _containsPatientIdentityEcho(item, identity));
    }
    if (value is Iterable && value is! String) {
      return value.any((Object? item) => _containsPatientIdentityEcho(item, identity));
    }
    return _isPatientIdentityEcho(value, identity);
  }

  static bool _isPatientIdentityEcho(Object? value, _ResolvedIdentity identity) {
    final String normalized = value?.toString().trim() ?? '';
    if (normalized.isEmpty) {
      return false;
    }
    final String normalizedCf = TargetAssistitoIdentityNormalizer.normalizeCf(normalized);
    if (identity.cf.trim().isNotEmpty && normalizedCf == identity.cf) {
      return true;
    }

    final String normalizedComparable = _normalizeComparableName(normalized);
    final Set<String> forbiddenComparableValues = <String>{
      _normalizeComparableName(identity.nome),
      _normalizeComparableName(identity.cognome),
      _normalizeComparableName(identity.fullName),
      _normalizeComparableName(_reverseNameOrder(identity.fullName)),
    }..remove('');

    if (forbiddenComparableValues.contains(normalizedComparable)) {
      return true;
    }

    final List<String> identityTokens = _normalizeComparableName(identity.fullName)
        .split(' ')
        .where((String token) => token.isNotEmpty)
        .toList(growable: false);
    final List<String> valueTokens = normalizedComparable
        .split(' ')
        .where((String token) => token.isNotEmpty)
        .toList(growable: false);

    return identityTokens.length >= 2 &&
        valueTokens.length >= 2 &&
        identityTokens.every(valueTokens.contains);
  }

  static DateTime _resolveTimestamp({
    required LegacyRealAssistitoReadBundle bundle,
    required List<String> candidateKeys,
    required DateTime fallback,
  }) {
    final List<Map<String, dynamic>> sources = <Map<String, dynamic>>[
      bundle.patient.rawData,
      bundle.dashboardIndex.rawData,
      bundle.therapeuticAdvice.rawData,
    ];

    for (final Map<String, dynamic> source in sources) {
      for (final String key in candidateKeys) {
        final DateTime? parsed = _readDate(source[key]);
        if (parsed != null) {
          return parsed.toUtc();
        }
      }
    }
    return fallback;
  }

  static DateTime? _readDate(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    try {
      final dynamic converted = (value as dynamic).toDate();
      if (converted is DateTime) {
        return converted;
      }
    } catch (_) {}
    return null;
  }

  static String _readFirstString(Map<String, dynamic> map, List<String> keys) {
    for (final String key in keys) {
      final String value = map[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
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

  static String _normalizeComparableName(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
  }

  static String _reverseNameOrder(String value) {
    final List<String> parts = value
        .trim()
        .split(' ')
        .where((String item) => item.trim().isNotEmpty)
        .toList(growable: false);
    if (parts.length < 2) {
      return value;
    }
    return <String>[
      parts.sublist(1).join(' '),
      parts.first,
    ].join(' ');
  }

  static String _fiscalCodeSurnameCode(String cf) {
    final String normalized = TargetAssistitoIdentityNormalizer.normalizeCf(cf);
    if (normalized.length < 6) {
      return '';
    }
    return normalized.substring(0, 3);
  }

  static String _fiscalCodeNameCode(String cf) {
    final String normalized = TargetAssistitoIdentityNormalizer.normalizeCf(cf);
    if (normalized.length < 6) {
      return '';
    }
    return normalized.substring(3, 6);
  }

  static String _surnameCodeForNamePart(String value) {
    return _takeFiscalCodeLetters(value, surname: true);
  }

  static String _nameCodeForNamePart(String value) {
    return _takeFiscalCodeLetters(value, surname: false);
  }

  static String _takeFiscalCodeLetters(String value, {required bool surname}) {
    final String normalized = value
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z]'), '');
    if (normalized.isEmpty) {
      return '';
    }
    final String consonants = normalized.replaceAll(RegExp(r'[AEIOU]'), '');
    final String vowels = normalized.replaceAll(RegExp(r'[^AEIOU]'), '');
    if (!surname && consonants.length >= 4) {
      return '${consonants[0]}${consonants[2]}${consonants[3]}';
    }
    return (consonants + vowels + 'XXX').substring(0, 3);
  }
}

class _IdentityCandidate {
  final String cf;
  final String nome;
  final String cognome;
  final String fullName;
  final String nameSplitConfidence;
  final bool preferSurnameFirstOnTie;

  const _IdentityCandidate({
    required this.cf,
    required this.nome,
    required this.cognome,
    required this.fullName,
    required this.nameSplitConfidence,
    this.preferSurnameFirstOnTie = false,
  });

  int get score {
    int value = 0;
    if (cognome.isNotEmpty &&
        RealAssistitiDryRunPreviewReader._surnameCodeForNamePart(cognome) ==
            RealAssistitiDryRunPreviewReader._fiscalCodeSurnameCode(cf)) {
      value += 4;
    }
    if (nome.isNotEmpty &&
        RealAssistitiDryRunPreviewReader._nameCodeForNamePart(nome) ==
            RealAssistitiDryRunPreviewReader._fiscalCodeNameCode(cf)) {
      value += 4;
    }
    if (fullName.isNotEmpty) {
      value += 1;
    }
    if (nome.isNotEmpty && cognome.isNotEmpty) {
      value += 1;
    }
    return value;
  }

  int get tieBreakPriority {
    if (nameSplitConfidence == 'explicit_fields') {
      return 0;
    }
    if (nameSplitConfidence == 'explicit_fields_without_full_name') {
      return 1;
    }
    if (preferSurnameFirstOnTie) {
      if (nameSplitConfidence == 'derived_from_full_name_surname_first' ||
          nameSplitConfidence == 'derived_from_full_name_last_name') {
        return 2;
      }
      if (nameSplitConfidence == 'derived_from_full_name_name_first' ||
          nameSplitConfidence == 'derived_from_full_name_last_surname') {
        return 3;
      }
    } else {
      if (nameSplitConfidence == 'derived_from_full_name_name_first' ||
          nameSplitConfidence == 'derived_from_full_name_last_surname') {
        return 2;
      }
      if (nameSplitConfidence == 'derived_from_full_name_surname_first' ||
          nameSplitConfidence == 'derived_from_full_name_last_name') {
        return 3;
      }
    }
    if (nameSplitConfidence == 'full_name_only') {
      return 4;
    }
    return 5;
  }
}

class _ResolvedIdentity {
  final String cf;
  final String nome;
  final String cognome;
  final String fullName;
  final String nameSplitConfidence;

  const _ResolvedIdentity({
    required this.cf,
    required this.nome,
    required this.cognome,
    required this.fullName,
    required this.nameSplitConfidence,
  });

  bool get hasAnyAcceptedIdentityAnchor {
    return cf.trim().isNotEmpty ||
        nome.trim().isNotEmpty ||
        cognome.trim().isNotEmpty ||
        fullName.trim().isNotEmpty;
  }
}
