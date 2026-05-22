import '../models/target_assistito.dart';

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
  static const String fallbackFullName = 'Assistito senza nome';
  static const int maxSearchPrefixCount = 64;
  static const int maxSearchPrefixLength = 40;

  const LegacyToTargetAssistitoMapper();

  TargetAssistito map(LegacyAssistitoSourceBundle source) {
    final String fiscalCode = _resolveFiscalCode(source);
    final String assistitoId = _resolveAssistitoId(source, fiscalCode: fiscalCode);
    final String? validFullName = _resolveValidFullName(source);
    final String fullName = validFullName ?? fallbackFullName;

    return TargetAssistito(
      assistitoId: assistitoId,
      fiscalCode: fiscalCode,
      fullName: fullName,
      searchPrefixes: validFullName == null ? const <String>[] : _buildSearchPrefixes(validFullName),
      doctor: _resolveDoctor(source),
      dashboard: _sanitizeDashboard(source.dashboardIndex),
      therapeuticAdvice: _sanitizeMap(source.therapeuticAdvice),
      createdAt: _resolveCreatedAt(source),
      updatedAt: _resolveUpdatedAt(source),
      sourceVersion: 1,
    );
  }

  String _resolveFiscalCode(LegacyAssistitoSourceBundle source) {
    final List<Object?> candidates = <Object?>[
      source.fiscalCode,
      source.patient['fiscalCode'],
      source.patient['codiceFiscale'],
      source.patient['cf'],
      source.dashboardIndex['fiscalCode'],
      source.dashboardIndex['codiceFiscale'],
      source.dashboardIndex['cf'],
      source.assistitoId,
    ];
    for (final Object? candidate in candidates) {
      final String value = _readString(candidate).toUpperCase();
      if (_isFiscalCodeLike(value)) {
        return value;
      }
    }
    return _readString(source.fiscalCode).toUpperCase();
  }

  String _resolveAssistitoId(LegacyAssistitoSourceBundle source, {required String fiscalCode}) {
    final String explicit = _readString(source.assistitoId).toUpperCase();
    if (explicit.isNotEmpty && !explicit.contains('/')) {
      return explicit;
    }
    if (fiscalCode.isNotEmpty && !fiscalCode.contains('/')) {
      return fiscalCode;
    }
    throw ArgumentError.value(source.assistitoId, 'assistitoId', 'Assistito target privo di identificativo valido.');
  }

  String? _resolveValidFullName(LegacyAssistitoSourceBundle source) {
    final List<Object?> candidates = <Object?>[
      source.patient['fullName'],
      source.patient['displayName'],
      source.patient['name'],
      source.patient['nomeCognome'],
      source.patient['patientName'],
      source.dashboardIndex['fullName'],
      source.dashboardIndex['displayName'],
      source.dashboardIndex['patientName'],
    ];
    for (final Object? candidate in candidates) {
      final String value = _normalizeWhitespace(_readString(candidate));
      if (_isValidHumanName(value)) {
        return value;
      }
    }
    return null;
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
    if (!_isValidHumanName(normalized)) {
      return const <String>[];
    }

    final Set<String> prefixes = <String>{};
    final List<String> tokens = normalized
        .split(' ')
        .map((String token) => token.trim())
        .where((String token) => token.length >= 2 && !_isOcrFragment(token) && !_isFiscalCodeLike(token.toUpperCase()))
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

bool _isValidHumanName(String value) {
  final String normalized = _normalizeWhitespace(value);
  if (normalized.isEmpty) {
    return false;
  }
  if (normalized.toLowerCase() == LegacyToTargetAssistitoMapper.fallbackFullName.toLowerCase()) {
    return false;
  }
  if (_isFiscalCodeLike(normalized.toUpperCase())) {
    return false;
  }
  final List<String> tokens = normalized.split(' ');
  if (tokens.any((String token) => _isFiscalCodeLike(token.toUpperCase()))) {
    return false;
  }
  if (tokens.any(_isOcrFragment)) {
    return false;
  }
  return normalized.length >= 3;
}

bool _isFiscalCodeLike(String value) {
  return RegExp(r'^[A-Z]{6}[0-9]{2}[A-Z][0-9]{2}[A-Z][0-9]{3}[A-Z]$').hasMatch(value);
}

bool _isOcrFragment(String value) {
  final String normalized = value.trim().toUpperCase();
  if (normalized.length < 5 || normalized.length > 8) {
    return false;
  }
  if (!RegExp(r'^[A-Z]+$').hasMatch(normalized)) {
    return false;
  }
  final bool hasVowel = RegExp('[AEIOU]').hasMatch(normalized);
  return !hasVowel;
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
