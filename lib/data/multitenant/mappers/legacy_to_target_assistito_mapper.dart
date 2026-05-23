import '../models/target_assistito.dart';
import '../normalizers/target_assistito_identity_normalizer.dart';

class LegacyAssistitoSourceBundle {
  final String assistitoId;
  final String fiscalCode;
  final Map<String, dynamic> patient;
  final Map<String, dynamic> dashboardIndex;
  final Map<String, dynamic> therapeuticAdvice;
  final Map<String, dynamic> doctorPrimaryLink;
  final Map<String, dynamic> doctorManualLink;

  const LegacyAssistitoSourceBundle({
    required this.assistitoId,
    required this.fiscalCode,
    this.patient = const <String, dynamic>{},
    this.dashboardIndex = const <String, dynamic>{},
    this.therapeuticAdvice = const <String, dynamic>{},
    this.doctorPrimaryLink = const <String, dynamic>{},
    this.doctorManualLink = const <String, dynamic>{},
  });
}

class LegacyToTargetAssistitoMapper {
  static const String fallbackFullName = TargetAssistitoIdentityNormalizer.fallbackFullName;
  static const int maxSearchPrefixCount = 64;
  static const int maxSearchPrefixLength = 40;

  final TargetAssistitoIdentityNormalizer identityNormalizer;

  const LegacyToTargetAssistitoMapper({
    this.identityNormalizer = const TargetAssistitoIdentityNormalizer(),
  });

  TargetAssistito map(LegacyAssistitoSourceBundle source) {
    final String assistitoId = _resolveAssistitoId(source);
    final TargetAssistitoIdentityNormalizationResult identity = identityNormalizer.normalize(
      rawCf: _resolveFiscalCode(source),
      rawNome: _resolveNome(source),
      rawCognome: _resolveCognome(source),
      rawFullName: _resolveFullName(source),
    );

    return TargetAssistito(
      assistitoId: assistitoId,
      cf: identity.cf,
      nome: identity.nome,
      cognome: identity.cognome,
      fullName: identity.fullName,
      nameSplitConfidence: identity.nameSplitConfidence,
      searchPrefixes: identity.hasValidName ? _buildSearchPrefixes(identity.fullName) : const <String>[],
      doctor: _resolveDoctor(source),
      dashboard: _sanitizeDashboard(source.dashboardIndex),
      therapeuticAdvice: _sanitizeMap(source.therapeuticAdvice),
      createdAt: _resolveCreatedAt(source),
      updatedAt: _resolveUpdatedAt(source),
      sourceVersion: 2,
    );
  }

  String _resolveAssistitoId(LegacyAssistitoSourceBundle source) {
    final String explicit = _readString(source.assistitoId);
    if (explicit.isNotEmpty && !explicit.contains('/')) {
      return explicit;
    }
    throw ArgumentError.value(
      source.assistitoId,
      'assistitoId',
      'Assistito target privo di identificativo tecnico valido.',
    );
  }

  String _resolveFiscalCode(LegacyAssistitoSourceBundle source) {
    final List<Object?> candidates = <Object?>[
      source.fiscalCode,
      source.patient['cf'],
      source.patient['fiscalCode'],
      source.patient['codiceFiscale'],
      source.dashboardIndex['cf'],
      source.dashboardIndex['fiscalCode'],
      source.dashboardIndex['codiceFiscale'],
      source.assistitoId,
    ];
    for (final Object? candidate in candidates) {
      final String value = TargetAssistitoIdentityNormalizer.normalizeCf(_readString(candidate));
      if (TargetAssistitoIdentityNormalizer.isFiscalCodeLike(value)) {
        return value;
      }
    }
    return TargetAssistitoIdentityNormalizer.normalizeCf(source.fiscalCode);
  }

  String _resolveNome(LegacyAssistitoSourceBundle source) {
    return _firstReadableString(<Object?>[
      source.patient['nome'],
      source.patient['firstName'],
      source.patient['givenName'],
      source.dashboardIndex['nome'],
      source.dashboardIndex['firstName'],
      source.dashboardIndex['givenName'],
    ]);
  }

  String _resolveCognome(LegacyAssistitoSourceBundle source) {
    return _firstReadableString(<Object?>[
      source.patient['cognome'],
      source.patient['lastName'],
      source.patient['surname'],
      source.patient['familyName'],
      source.dashboardIndex['cognome'],
      source.dashboardIndex['lastName'],
      source.dashboardIndex['surname'],
      source.dashboardIndex['familyName'],
    ]);
  }

  String _resolveFullName(LegacyAssistitoSourceBundle source) {
    return _firstValidHumanName(<Object?>[
      source.patient['fullName'],
      source.patient['displayName'],
      source.patient['name'],
      source.patient['nomeCognome'],
      source.patient['patientName'],
      source.dashboardIndex['fullName'],
      source.dashboardIndex['displayName'],
      source.dashboardIndex['patientName'],
    ]);
  }

  String _firstReadableString(Iterable<Object?> candidates) {
    for (final Object? candidate in candidates) {
      final String value = _normalizeWhitespace(_readString(candidate));
      if (value.isNotEmpty &&
          !TargetAssistitoIdentityNormalizer.isFiscalCodeLike(value) &&
          !TargetAssistitoIdentityNormalizer.containsFiscalCodeLikeToken(value) &&
          !TargetAssistitoIdentityNormalizer.isOcrFragment(value)) {
        return value;
      }
    }
    return '';
  }

  String _firstValidHumanName(Iterable<Object?> candidates) {
    for (final Object? candidate in candidates) {
      final String value = TargetAssistitoIdentityNormalizer.normalizeFullName(_readString(candidate));
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  Map<String, dynamic> _resolveDoctor(LegacyAssistitoSourceBundle source) {
    final Map<String, dynamic> manual = _sanitizeDoctor(source.doctorManualLink, source: 'manual');
    if (manual.isNotEmpty) {
      return manual;
    }
    return _sanitizeDoctor(source.doctorPrimaryLink, source: 'primary');
  }

  Map<String, dynamic> _sanitizeDoctor(Map<String, dynamic> value, {required String source}) {
    final Map<String, dynamic> sanitized = _sanitizeMap(value);
    if (sanitized.isEmpty) {
      return const <String, dynamic>{};
    }
    return Map<String, dynamic>.unmodifiable(<String, dynamic>{
      ...sanitized,
      'source': source,
    });
  }

  Map<String, dynamic> _sanitizeDashboard(Map<String, dynamic> value) {
    final Map<String, dynamic> sanitized = _sanitizeMap(value);
    if (sanitized.isEmpty) {
      return const <String, dynamic>{};
    }
    final Map<String, dynamic> copy = Map<String, dynamic>.of(sanitized)
      ..remove('cf')
      ..remove('fiscalCode')
      ..remove('codiceFiscale')
      ..remove('nome')
      ..remove('cognome')
      ..remove('firstName')
      ..remove('lastName')
      ..remove('givenName')
      ..remove('familyName')
      ..remove('surname')
      ..remove('fullName')
      ..remove('displayName')
      ..remove('patientName')
      ..remove('searchPrefixes');
    return Map<String, dynamic>.unmodifiable(copy);
  }

  Map<String, dynamic> _sanitizeMap(Map<String, dynamic> value) {
    if (value.isEmpty) {
      return const <String, dynamic>{};
    }
    final Map<String, dynamic> sanitized = <String, dynamic>{};
    for (final MapEntry<String, dynamic> entry in value.entries) {
      final String key = entry.key.trim();
      if (key.isEmpty) {
        continue;
      }
      sanitized[key] = entry.value;
    }
    return Map<String, dynamic>.unmodifiable(sanitized);
  }

  DateTime? _resolveCreatedAt(LegacyAssistitoSourceBundle source) {
    return _firstDate(<Object?>[
      source.patient['createdAt'],
      source.dashboardIndex['createdAt'],
      source.therapeuticAdvice['createdAt'],
    ]);
  }

  DateTime? _resolveUpdatedAt(LegacyAssistitoSourceBundle source) {
    DateTime? latest;
    for (final Object? value in <Object?>[
      source.patient['updatedAt'],
      source.dashboardIndex['updatedAt'],
      source.therapeuticAdvice['updatedAt'],
      source.doctorManualLink['updatedAt'],
      source.doctorPrimaryLink['updatedAt'],
    ]) {
      final DateTime? current = _readDate(value);
      if (current == null) {
        continue;
      }
      if (latest == null || current.isAfter(latest)) {
        latest = current;
      }
    }
    return latest;
  }

  DateTime? _firstDate(Iterable<Object?> values) {
    for (final Object? value in values) {
      final DateTime? date = _readDate(value);
      if (date != null) {
        return date;
      }
    }
    return null;
  }

  List<String> _buildSearchPrefixes(String fullName) {
    final String normalized = _normalizeWhitespace(fullName).toLowerCase();
    if (normalized.isEmpty ||
        TargetAssistitoIdentityNormalizer.isPlaceholderName(normalized) ||
        TargetAssistitoIdentityNormalizer.isFiscalCodeLike(normalized) ||
        TargetAssistitoIdentityNormalizer.containsFiscalCodeLikeToken(normalized)) {
      return const <String>[];
    }

    final Set<String> prefixes = <String>{};
    final List<String> tokens = normalized
        .split(' ')
        .map((String token) => token.trim())
        .where(
          (String token) =>
              token.length >= 2 &&
              !TargetAssistitoIdentityNormalizer.isOcrFragment(token) &&
              !TargetAssistitoIdentityNormalizer.isFiscalCodeLike(token),
        )
        .toList(growable: false);

    for (final String token in tokens) {
      final int tokenLimit = token.length < maxSearchPrefixLength ? token.length : maxSearchPrefixLength;
      for (int i = 2; i <= tokenLimit; i += 1) {
        prefixes.add(token.substring(0, i));
        if (prefixes.length >= maxSearchPrefixCount) {
          return List<String>.unmodifiable(prefixes);
        }
      }
    }

    final String boundedFullName = normalized.length <= maxSearchPrefixLength
        ? normalized
        : normalized.substring(0, maxSearchPrefixLength);
    prefixes.add(boundedFullName);

    if (prefixes.length <= maxSearchPrefixCount) {
      return List<String>.unmodifiable(prefixes);
    }
    return List<String>.unmodifiable(prefixes.take(maxSearchPrefixCount));
  }
}

String _readString(Object? value) {
  return value?.toString().trim() ?? '';
}

String _normalizeWhitespace(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

DateTime? _readDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String && value.trim().isNotEmpty) return DateTime.tryParse(value.trim());
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  try {
    final dynamic date = (value as dynamic).toDate();
    if (date is DateTime) return date;
  } catch (_) {}
  try {
    final dynamic seconds = (value as dynamic).seconds;
    if (seconds is int) {
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    }
  } catch (_) {}
  return null;
}
