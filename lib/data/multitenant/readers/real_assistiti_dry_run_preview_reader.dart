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
  static const int sourceVersion = 2;

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
    final DateTime updatedAt = _resolveTimestamp(
      bundle: bundle,
      candidateKeys: const <String>['updatedAt', 'lastUpdatedAt', 'modifiedAt', 'lastSeenAt'],
      fallback: previewGeneratedAt,
    );

    final Map<String, dynamic> targetPreviewPayload = <String, dynamic>{
      'cf': bundle.cf,
      'nome': identity.nome,
      'cognome': identity.cognome,
      'fullName': identity.fullName,
      'nameSplitConfidence': identity.nameSplitConfidence,
      'searchPrefixes': identity.hasSearchableFullName
          ? _buildSearchPrefixes(identity.fullName)
          : const <String>[],
      'doctor': _buildDoctorPreview(bundle),
      'dashboard': _sanitizeIdentityFields(bundle.dashboardIndex.rawData),
      'therapeuticAdvice': _sanitizeIdentityFields(bundle.therapeuticAdvice.rawData),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'sourceVersion': sourceVersion,
      'legacySource': <String, dynamic>{
        'cf': bundle.cf,
        'patientExists': bundle.patient.exists,
        'dashboardIndexExists': bundle.dashboardIndex.exists,
        'therapeuticAdviceExists': bundle.therapeuticAdvice.exists,
        'doctorManualExists': bundle.doctorManual.exists,
        'doctorPrimaryExists': bundle.doctorPrimary.exists,
        'existingSourceCount': bundle.existingSourceCount,
        'identityContract': 'cf_or_name_anchor_required',
      },
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

    const TargetAssistitoIdentityNormalizer normalizer = TargetAssistitoIdentityNormalizer();

    for (final String rawFullName in fullNameCandidates) {
      final TargetAssistitoIdentityNormalizationResult normalized = normalizer.normalize(
        rawCf: bundle.cf,
        rawNome: rawNome,
        rawCognome: rawCognome,
        rawFullName: rawFullName,
      );
      if (normalized.hasValidName) {
        return _ResolvedIdentity.fromNormalized(
          cf: bundle.cf,
          normalized: normalized,
        );
      }
    }

    final TargetAssistitoIdentityNormalizationResult fallback = normalizer.normalize(
      rawCf: bundle.cf,
      rawNome: rawNome,
      rawCognome: rawCognome,
    );
    return _ResolvedIdentity.fromNormalized(
      cf: bundle.cf,
      normalized: fallback,
    );
  }

  static Map<String, dynamic> _buildDoctorPreview(LegacyRealAssistitoReadBundle bundle) {
    final Map<String, dynamic> manual = _sanitizeDoctorFields(bundle.doctorManual.rawData);
    final Map<String, dynamic> primary = _sanitizeDoctorFields(bundle.doctorPrimary.rawData);

    if (manual.isEmpty && primary.isEmpty) {
      return const <String, dynamic>{};
    }
    return Map<String, dynamic>.unmodifiable(<String, dynamic>{
      if (manual.isNotEmpty) 'manual': manual,
      if (primary.isNotEmpty) 'primary': primary,
    });
  }

  static Map<String, dynamic> _sanitizeDoctorFields(Map<String, dynamic> rawData) {
    if (rawData.isEmpty) {
      return const <String, dynamic>{};
    }

    const Set<String> allowedKeys = <String>{
      'doctorId',
      'doctorCode',
      'doctorName',
      'doctorFullName',
      'doctorFiscalCode',
      'doctorLicense',
      'doctorPhone',
      'doctorEmail',
      'medico',
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
    };

    final Map<String, dynamic> sanitized = <String, dynamic>{};
    for (final MapEntry<String, dynamic> entry in rawData.entries) {
      if (allowedKeys.contains(entry.key)) {
        sanitized[entry.key] = entry.value;
      }
    }
    return Map<String, dynamic>.unmodifiable(sanitized);
  }

  static Map<String, dynamic> _sanitizeIdentityFields(Map<String, dynamic> rawData) {
    if (rawData.isEmpty) {
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
      'searchPrefixes',
    };

    final Map<String, dynamic> sanitized = <String, dynamic>{};
    for (final MapEntry<String, dynamic> entry in rawData.entries) {
      if (!blockedKeys.contains(entry.key)) {
        sanitized[entry.key] = entry.value;
      }
    }
    return Map<String, dynamic>.unmodifiable(sanitized);
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

  static List<String> _buildSearchPrefixes(String fullName) {
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

  factory _ResolvedIdentity.fromNormalized({
    required String cf,
    required TargetAssistitoIdentityNormalizationResult normalized,
  }) {
    return _ResolvedIdentity(
      cf: TargetAssistitoIdentityNormalizer.normalizeCf(cf),
      nome: normalized.nome,
      cognome: normalized.cognome,
      fullName: normalized.fullName,
      nameSplitConfidence: normalized.nameSplitConfidence,
    );
  }

  bool get hasAnyAcceptedIdentityAnchor {
    return cf.trim().isNotEmpty ||
        nome.trim().isNotEmpty ||
        cognome.trim().isNotEmpty ||
        hasSearchableFullName;
  }

  bool get hasSearchableFullName {
    return fullName.trim().isNotEmpty &&
        !TargetAssistitoIdentityNormalizer.isPlaceholderName(fullName) &&
        !TargetAssistitoIdentityNormalizer.isFiscalCodeLike(fullName) &&
        !TargetAssistitoIdentityNormalizer.containsFiscalCodeLikeToken(fullName);
  }
}
