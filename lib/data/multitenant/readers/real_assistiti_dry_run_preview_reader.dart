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
    final String explicitNome = TargetAssistitoIdentityNormalizer.normalizeNamePart(
      _readFirstString(bundle.patient.rawData, const <String>['nome', 'firstName', 'givenName']),
    );
    final String explicitCognome = TargetAssistitoIdentityNormalizer.normalizeNamePart(
      _readFirstString(bundle.patient.rawData, const <String>['cognome', 'lastName', 'surname', 'familyName']),
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

    for (final String rawFullName in fullNameCandidates) {
      final String fullName = TargetAssistitoIdentityNormalizer.normalizeFullName(rawFullName);
      if (fullName.isEmpty) {
        continue;
      }
      final _BestEffortNameSplit split = _splitFullNameUsingCf(
        cf: bundle.cf,
        fullName: fullName,
      );
      return _ResolvedIdentity(
        cf: TargetAssistitoIdentityNormalizer.normalizeCf(bundle.cf),
        fullName: fullName,
        cognome: _preferCoherentExplicitPart(
          explicitPart: explicitCognome,
          derivedPart: split.cognome,
          fullName: fullName,
          cf: bundle.cf,
          isSurname: true,
        ),
        nome: _preferCoherentExplicitPart(
          explicitPart: explicitNome,
          derivedPart: split.nome,
          fullName: fullName,
          cf: bundle.cf,
          isSurname: false,
        ),
        nameSplitConfidence: split.nameSplitConfidence,
      );
    }

    final bool explicitCognomeCoherent = _partMatchesCfCode(
      value: explicitCognome,
      cf: bundle.cf,
      isSurname: true,
    );
    final bool explicitNomeCoherent = _partMatchesCfCode(
      value: explicitNome,
      cf: bundle.cf,
      isSurname: false,
    );
    final String safeCognome = explicitCognomeCoherent ? explicitCognome : '';
    final String safeNome = explicitNomeCoherent ? explicitNome : '';
    final String fallbackFullName = <String>[safeNome, safeCognome]
        .where((String item) => item.trim().isNotEmpty)
        .join(' ')
        .trim();

    return _ResolvedIdentity(
      cf: TargetAssistitoIdentityNormalizer.normalizeCf(bundle.cf),
      fullName: fallbackFullName,
      cognome: safeCognome,
      nome: safeNome,
      nameSplitConfidence: fallbackFullName.isEmpty ? 'cf_only' : 'explicit_patient_fields_cf_checked',
    );
  }

  static String _preferCoherentExplicitPart({
    required String explicitPart,
    required String derivedPart,
    required String fullName,
    required String cf,
    required bool isSurname,
  }) {
    if (explicitPart.isEmpty) {
      return derivedPart;
    }
    final String comparableExplicit = _normalizeComparableName(explicitPart);
    final String comparableFullName = _normalizeComparableName(fullName);
    if (comparableFullName.split(' ').contains(comparableExplicit) &&
        _partMatchesCfCode(value: explicitPart, cf: cf, isSurname: isSurname)) {
      return explicitPart;
    }
    return derivedPart;
  }

  static _BestEffortNameSplit _splitFullNameUsingCf({
    required String cf,
    required String fullName,
  }) {
    final List<String> parts = fullName
        .trim()
        .split(' ')
        .where((String part) => part.trim().isNotEmpty)
        .toList(growable: false);
    if (parts.length < 2) {
      return _BestEffortNameSplit(
        nome: '',
        cognome: '',
        nameSplitConfidence: 'full_name_only',
      );
    }

    _SplitCandidate? best;
    for (int index = 1; index < parts.length; index++) {
      final _SplitCandidate surnameFirst = _SplitCandidate(
        nome: parts.sublist(index).join(' '),
        cognome: parts.sublist(0, index).join(' '),
      ).scoreAgainstCf(cf);
      final _SplitCandidate nameFirst = _SplitCandidate(
        nome: parts.sublist(0, index).join(' '),
        cognome: parts.sublist(index).join(' '),
      ).scoreAgainstCf(cf);
      for (final _SplitCandidate candidate in <_SplitCandidate>[surnameFirst, nameFirst]) {
        if (best == null || candidate.score > best.score) {
          best = candidate;
        }
      }
    }

    final _SplitCandidate selected = best ??
        _SplitCandidate(
          nome: parts.first,
          cognome: parts.skip(1).join(' '),
        );
    return _BestEffortNameSplit(
      nome: selected.nome,
      cognome: selected.cognome,
      nameSplitConfidence: selected.score >= 2
          ? 'derived_from_full_name_cf'
          : 'derived_from_full_name',
    );
  }

  static bool _partMatchesCfCode({
    required String value,
    required String cf,
    required bool isSurname,
  }) {
    final String normalizedCf = TargetAssistitoIdentityNormalizer.normalizeCf(cf);
    if (normalizedCf.length < 6 || value.trim().isEmpty) {
      return false;
    }
    final String expected = isSurname ? normalizedCf.substring(0, 3) : normalizedCf.substring(3, 6);
    final String actual = isSurname ? _surnameCode(value) : _nameCode(value);
    return actual == expected;
  }

  static Map<String, dynamic> _buildDoctorPreview(
    LegacyRealAssistitoReadBundle bundle,
    _ResolvedIdentity identity,
  ) {
    final Map<String, dynamic> manual = _sanitizeDoctorFields(
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

  static Map<String, dynamic> _sanitizeDoctorFields(
    Map<String, dynamic> rawData,
    _ResolvedIdentity identity,
  ) {
    if (rawData.isEmpty) {
      return const <String, dynamic>{};
    }

    final String doctorFullName = _readFirstString(
      rawData,
      const <String>['doctorFullName', 'medicoFullName'],
    );
    final String doctorName = _readFirstString(
      rawData,
      const <String>['doctorName', 'medico', 'medicoNome'],
    );
    final Map<String, dynamic> sanitized = <String, dynamic>{};
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

    final Map<String, dynamic> sanitized = <String, dynamic>{};
    for (final String key in const <String>[
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
    ]) {
      if (rawData.containsKey(key) && !_containsPatientIdentityEcho(rawData[key], identity)) {
        sanitized[key] = rawData[key];
      }
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
      _normalizeComparableName('${identity.cognome} ${identity.nome}'),
      _normalizeComparableName('${identity.nome} ${identity.cognome}'),
    }..remove('');

    return forbiddenComparableValues.contains(normalizedComparable);
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
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  static String _surnameCode(String value) {
    return _fiscalNameCode(value, surname: true);
  }

  static String _nameCode(String value) {
    return _fiscalNameCode(value, surname: false);
  }

  static String _fiscalNameCode(String value, {required bool surname}) {
    final String letters = _normalizeFiscalLetters(value);
    final String consonants = letters.replaceAll(RegExp('[AEIOU]'), '');
    final String vowels = letters.replaceAll(RegExp('[^AEIOU]'), '');
    final String base;
    if (!surname && consonants.length >= 4) {
      base = '${consonants[0]}${consonants[2]}${consonants[3]}';
    } else {
      base = '$consonants$vowels';
    }
    return base.padRight(3, 'X').substring(0, 3);
  }

  static String _normalizeFiscalLetters(String value) {
    final String upper = value.toUpperCase();
    const Map<String, String> replacements = <String, String>{
      'À': 'A', 'Á': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'A', 'Å': 'A',
      'È': 'E', 'É': 'E', 'Ê': 'E', 'Ë': 'E',
      'Ì': 'I', 'Í': 'I', 'Î': 'I', 'Ï': 'I',
      'Ò': 'O', 'Ó': 'O', 'Ô': 'O', 'Õ': 'O', 'Ö': 'O',
      'Ù': 'U', 'Ú': 'U', 'Û': 'U', 'Ü': 'U',
      'Ç': 'C',
    };
    final StringBuffer buffer = StringBuffer();
    for (int index = 0; index < upper.length; index++) {
      final String char = replacements[upper[index]] ?? upper[index];
      if (RegExp('[A-Z]').hasMatch(char)) {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }
}

class _BestEffortNameSplit {
  final String nome;
  final String cognome;
  final String nameSplitConfidence;

  const _BestEffortNameSplit({
    required this.nome,
    required this.cognome,
    required this.nameSplitConfidence,
  });
}

class _SplitCandidate {
  final String nome;
  final String cognome;
  final int score;

  const _SplitCandidate({
    required this.nome,
    required this.cognome,
    this.score = 0,
  });

  _SplitCandidate scoreAgainstCf(String cf) {
    int value = 0;
    if (RealAssistitiDryRunPreviewReader._partMatchesCfCode(
      value: cognome,
      cf: cf,
      isSurname: true,
    )) {
      value++;
    }
    if (RealAssistitiDryRunPreviewReader._partMatchesCfCode(
      value: nome,
      cf: cf,
      isSurname: false,
    )) {
      value++;
    }
    return _SplitCandidate(nome: nome, cognome: cognome, score: value);
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
