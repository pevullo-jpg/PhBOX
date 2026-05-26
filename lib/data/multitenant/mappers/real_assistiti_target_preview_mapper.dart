import '../normalizers/target_assistito_identity_normalizer.dart';

class RealAssistitiResolvedIdentity {
  final String cf;
  final String nome;
  final String cognome;
  final String fullName;
  final String nameSplitConfidence;

  const RealAssistitiResolvedIdentity({
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

class RealAssistitiTargetPreviewMapper {
  const RealAssistitiTargetPreviewMapper._();

  static RealAssistitiResolvedIdentity resolveIdentity({
    required String cf,
    required Map<String, dynamic> patientData,
    required Map<String, dynamic> dashboardIndexData,
    required Map<String, dynamic> therapeuticAdviceData,
  }) {
    final String rawNome = _readFirstString(
      patientData,
      const <String>['nome', 'firstName', 'givenName'],
    );
    final String rawCognome = _readFirstString(
      patientData,
      const <String>['cognome', 'lastName', 'surname', 'familyName'],
    );

    final List<String> fullNameCandidates = <String>[
      _readFirstString(
        patientData,
        const <String>['fullName', 'displayName', 'patientName', 'assistitoName', 'name'],
      ),
      _readFirstString(
        dashboardIndexData,
        const <String>['fullName', 'displayName', 'patientName', 'assistitoName', 'name'],
      ),
      _readFirstString(
        therapeuticAdviceData,
        const <String>['fullName', 'displayName', 'patientName', 'assistitoName', 'name'],
      ),
    ];

    final _IdentityCandidate? bestCandidate = _selectBestIdentityCandidate(
      cf: cf,
      rawNome: rawNome,
      rawCognome: rawCognome,
      rawFullNameCandidates: fullNameCandidates,
    );

    if (bestCandidate != null) {
      return RealAssistitiResolvedIdentity(
        cf: TargetAssistitoIdentityNormalizer.normalizeCf(cf),
        nome: bestCandidate.nome,
        cognome: bestCandidate.cognome,
        fullName: bestCandidate.fullName,
        nameSplitConfidence: bestCandidate.nameSplitConfidence,
      );
    }

    return RealAssistitiResolvedIdentity(
      cf: TargetAssistitoIdentityNormalizer.normalizeCf(cf),
      nome: '',
      cognome: '',
      fullName: '',
      nameSplitConfidence: 'cf_only',
    );
  }

  static Map<String, dynamic> buildDoctorPreview({
    required Map<String, dynamic> doctorManualData,
    required Map<String, dynamic> doctorPrimaryData,
    required RealAssistitiResolvedIdentity identity,
  }) {
    final Map<String, dynamic> manual = _sanitizeDoctorFields(
      doctorManualData,
      identity,
    );
    final Map<String, dynamic> primary = _sanitizeDoctorFields(
      doctorPrimaryData,
      identity,
    );

    if (manual.isEmpty && primary.isEmpty) {
      return const <String, dynamic>{};
    }
    return Map<String, dynamic>.unmodifiable(<String, dynamic>{
      if (manual.isNotEmpty) 'manual': manual,
      if (primary.isNotEmpty) 'primary': primary,
    });
  }

  static Map<String, dynamic> buildDashboardSnapshot({
    required Map<String, dynamic> dashboardIndexData,
    required RealAssistitiResolvedIdentity identity,
  }) {
    if (dashboardIndexData.isEmpty) {
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
      if (!dashboardIndexData.containsKey(key)) {
        continue;
      }
      final Object? value = dashboardIndexData[key];
      if (containsPatientIdentityEcho(value, identity)) {
        continue;
      }
      sanitized[key] = value;
    }
    return Map<String, dynamic>.unmodifiable(sanitized);
  }

  static Map<String, dynamic> buildTherapeuticAdvicePreview({
    required Map<String, dynamic> therapeuticAdviceData,
    required RealAssistitiResolvedIdentity identity,
  }) {
    if (therapeuticAdviceData.isEmpty) {
      return const <String, dynamic>{};
    }

    const Set<String> blockedKeys = <String>{
      'cf',
      'fiscalCode',
      'codiceFiscale',
      'nome',
      'cognome',
      'firstName',
      'givenName',
      'lastName',
      'surname',
      'familyName',
      'fullName',
      'displayName',
      'patientName',
      'assistitoName',
      'name',
      'alias',
      'familyId',
      'familyColorIndex',
      'doctorFullName',
      'source',
      'schemaVersion',
      'searchPrefixes',
    };

    final Map<String, dynamic> sanitized = <String, dynamic>{};
    for (final MapEntry<String, dynamic> entry in therapeuticAdviceData.entries) {
      if (blockedKeys.contains(entry.key)) {
        continue;
      }
      if (containsPatientIdentityEcho(entry.value, identity)) {
        continue;
      }
      sanitized[entry.key] = entry.value;
    }
    return Map<String, dynamic>.unmodifiable(sanitized);
  }

  static List<String> buildSearchPrefixes(String fullName) {
    final String normalized = fullName.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    if (normalized.isEmpty ||
        TargetAssistitoIdentityNormalizer.isPlaceholderName(normalized) ||
        TargetAssistitoIdentityNormalizer.isFiscalCodeLike(normalized) ||
        TargetAssistitoIdentityNormalizer.containsFiscalCodeLikeToken(normalized)) {
      return const <String>[];
    }

    final Set<String> prefixes = <String>{};
    final List<String> tokens = normalized.split(' ');
    for (final String token in tokens) {
      for (int length = 1; length <= token.length; length++) {
        prefixes.add(token.substring(0, length));
      }
    }
    for (int length = 1; length <= normalized.length; length++) {
      prefixes.add(normalized.substring(0, length));
    }

    final List<String> sorted = prefixes.toList(growable: false)..sort();
    return List<String>.unmodifiable(sorted.take(50).toList(growable: false));
  }

  static DateTime resolveTimestamp({
    required List<Map<String, dynamic>> sources,
    required List<String> candidateKeys,
    required DateTime fallback,
  }) {
    for (final Map<String, dynamic> source in sources) {
      for (final String key in candidateKeys) {
        final DateTime? parsed = readDate(source[key]);
        if (parsed != null) {
          return parsed.toUtc();
        }
      }
    }
    return fallback;
  }

  static DateTime? readDate(Object? value) {
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
    final String joined = <String>[cognome, nome]
        .where((String item) => item.trim().isNotEmpty)
        .join(' ')
        .trim();
    if (joined.isNotEmpty) {
      return joined;
    }
    return TargetAssistitoIdentityNormalizer.normalizeFullName(fallbackFullName);
  }

  static Map<String, dynamic> _sanitizeDoctorFields(
    Map<String, dynamic> rawData,
    RealAssistitiResolvedIdentity identity,
  ) {
    if (rawData.isEmpty) {
      return const <String, dynamic>{};
    }

    const List<String> allowedKeys = <String>[
      'doctorId',
      'doctorCode',
      'doctorName',
      'doctorFullName',
      'doctorFiscalCode',
      'doctorLicense',
      'doctorPhone',
      'doctorEmail',
      'medicoId',
      'medicoCodice',
      'medicoNome',
      'medicoCognome',
      'medicoFullName',
      'medicoCodiceFiscale',
      'medicoTelefono',
      'medicoEmail',
      'specialization',
      'specializzazione',
    ];

    final Map<String, dynamic> sanitized = <String, dynamic>{};
    for (final String key in allowedKeys) {
      if (!rawData.containsKey(key)) {
        continue;
      }
      final Object? value = rawData[key];
      if (!_isSafeScalar(value)) {
        continue;
      }
      if (containsPatientIdentityEcho(value, identity)) {
        continue;
      }
      sanitized[key] = value;
    }
    return Map<String, dynamic>.unmodifiable(sanitized);
  }

  static bool _isSafeScalar(Object? value) {
    return value == null || value is String || value is num || value is bool || value is DateTime;
  }

  static bool containsPatientIdentityEcho(Object? value, RealAssistitiResolvedIdentity identity) {
    if (value == null) {
      return false;
    }
    if (value is Map) {
      return value.values.any((Object? item) => containsPatientIdentityEcho(item, identity));
    }
    if (value is Iterable && value is! String) {
      return value.any((Object? item) => containsPatientIdentityEcho(item, identity));
    }
    return _isPatientIdentityEcho(value, identity);
  }

  static bool _isPatientIdentityEcho(Object? value, RealAssistitiResolvedIdentity identity) {
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

  static String _readFirstString(Map<String, dynamic> map, List<String> keys) {
    for (final String key in keys) {
      final String value = map[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
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

  static bool _looksAllUppercaseHumanName(String rawFullName) {
    final String normalized = rawFullName.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      return false;
    }
    final String lettersOnly = normalized.replaceAll(RegExp(r"[^A-Za-zÀ-ÖØ-öø-ÿ']"), '');
    if (lettersOnly.length < 3) {
      return false;
    }
    return lettersOnly == lettersOnly.toUpperCase() && lettersOnly != lettersOnly.toLowerCase();
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
        RealAssistitiTargetPreviewMapper._surnameCodeForNamePart(cognome) ==
            RealAssistitiTargetPreviewMapper._fiscalCodeSurnameCode(cf)) {
      value += 4;
    }
    if (nome.isNotEmpty &&
        RealAssistitiTargetPreviewMapper._nameCodeForNamePart(nome) ==
            RealAssistitiTargetPreviewMapper._fiscalCodeNameCode(cf)) {
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
