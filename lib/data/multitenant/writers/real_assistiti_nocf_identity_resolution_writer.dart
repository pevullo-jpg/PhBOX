import 'package:cloud_firestore/cloud_firestore.dart';

import '../mappers/real_assistiti_target_preview_mapper.dart';
import '../models/target_multitenant_collections.dart';
import '../normalizers/target_assistito_identity_normalizer.dart';
import '../normalizers/target_assistito_nocf_identity_anchor_normalizer.dart';
import '../readers/real_assistiti_nocf_identity_resolution_reader.dart';

class RealAssistitiNoCfIdentityResolutionRejectedException implements Exception {
  final String code;
  final String message;

  const RealAssistitiNoCfIdentityResolutionRejectedException({
    required this.code,
    required this.message,
  });

  @override
  String toString() {
    return 'RealAssistitiNoCfIdentityResolutionRejectedException($code): $message';
  }
}

class RealAssistitiNoCfIdentityResolutionWriteResult {
  final String tenantId;
  final String assistitoId;
  final String documentPath;
  final String nome;
  final String cognome;
  final String fullName;
  final List<String> searchPrefixes;
  final int attemptedReads;
  final int attemptedWrites;
  final List<String> updatedRootKeys;

  const RealAssistitiNoCfIdentityResolutionWriteResult({
    required this.tenantId,
    required this.assistitoId,
    required this.documentPath,
    required this.nome,
    required this.cognome,
    required this.fullName,
    required this.searchPrefixes,
    required this.attemptedReads,
    required this.attemptedWrites,
    required this.updatedRootKeys,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tenantId': tenantId,
      'assistitoId': assistitoId,
      'documentPath': documentPath,
      'nome': nome,
      'cognome': cognome,
      'fullName': fullName,
      'searchPrefixes': searchPrefixes,
      'attemptedReads': attemptedReads,
      'attemptedWrites': attemptedWrites,
      'updatedRootKeys': updatedRootKeys,
    };
  }
}

class RealAssistitiNoCfIdentityResolutionWriter {
  static const int transactionReadsPerResolution = 1;
  static const int writesPerResolution = 1;
  static const String resolvedManualStatus = 'resolved_manual';
  static const String resolutionSource = 'frontend_modal_identity_resolution';
  static const String resolvedManualNameSplitConfidence = 'resolved_manual_nocf_identity';

  final FirebaseFirestore firestore;

  const RealAssistitiNoCfIdentityResolutionWriter({
    required this.firestore,
  });

  Future<RealAssistitiNoCfIdentityResolutionWriteResult> resolvePendingManual({
    required String tenantId,
    required String assistitoId,
    required String nome,
    required String cognome,
  }) async {
    final String normalizedTenantId = normalizeTenantId(tenantId);
    final String normalizedAssistitoId = normalizeAssistitoId(assistitoId);
    final String normalizedNome = normalizeManualNamePart(fieldName: 'nome', value: nome);
    final String normalizedCognome = normalizeManualNamePart(fieldName: 'cognome', value: cognome);
    final String fullName = buildCanonicalFullName(
      nome: normalizedNome,
      cognome: normalizedCognome,
    );
    final List<String> searchPrefixes = buildResolvedSearchPrefixes(fullName);
    final String documentPath = TargetMultitenantCollections.assistitoDocument(
      tenantId: normalizedTenantId,
      assistitoId: normalizedAssistitoId,
    );
    final DocumentReference<Map<String, dynamic>> reference = firestore.doc(documentPath);

    return firestore.runTransaction<RealAssistitiNoCfIdentityResolutionWriteResult>(
      (Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction.get(reference);
        if (!snapshot.exists) {
          throw RealAssistitiNoCfIdentityResolutionRejectedException(
            code: 'target_assistito_missing',
            message: 'Assistito target NOCF assente: $documentPath.',
          );
        }

        final Map<String, dynamic> rawData = snapshot.data() ?? const <String, dynamic>{};
        assertPendingNoCfAssistito(
          assistitoId: normalizedAssistitoId,
          documentPath: documentPath,
          rawData: rawData,
        );

        final Map<String, dynamic> updatePayload = buildResolvedManualUpdatePayload(
          nome: normalizedNome,
          cognome: normalizedCognome,
          fullName: fullName,
          searchPrefixes: searchPrefixes,
        );
        transaction.update(reference, updatePayload);

        return RealAssistitiNoCfIdentityResolutionWriteResult(
          tenantId: normalizedTenantId,
          assistitoId: normalizedAssistitoId,
          documentPath: documentPath,
          nome: normalizedNome,
          cognome: normalizedCognome,
          fullName: fullName,
          searchPrefixes: searchPrefixes,
          attemptedReads: transactionReadsPerResolution,
          attemptedWrites: writesPerResolution,
          updatedRootKeys: sortedRootKeys(updatePayload),
        );
      },
    );
  }

  static Map<String, dynamic> buildResolvedManualUpdatePayload({
    required String nome,
    required String cognome,
    required String fullName,
    required List<String> searchPrefixes,
  }) {
    final String normalizedNome = normalizeManualNamePart(fieldName: 'nome', value: nome);
    final String normalizedCognome = normalizeManualNamePart(fieldName: 'cognome', value: cognome);
    final String canonicalFullName = buildCanonicalFullName(
      nome: normalizedNome,
      cognome: normalizedCognome,
    );
    if (canonicalFullName != fullName.trim()) {
      throw const RealAssistitiNoCfIdentityResolutionRejectedException(
        code: 'manual_identity_full_name_not_canonical',
        message: 'fullName manuale NOCF non canonico rispetto a nome/cognome.',
      );
    }
    final List<String> canonicalSearchPrefixes = buildResolvedSearchPrefixes(canonicalFullName);
    if (!_sameStringList(canonicalSearchPrefixes, searchPrefixes)) {
      throw const RealAssistitiNoCfIdentityResolutionRejectedException(
        code: 'manual_identity_search_prefixes_not_canonical',
        message: 'searchPrefixes manuali NOCF non canonici rispetto a fullName.',
      );
    }

    return <String, dynamic>{
      'nome': normalizedNome,
      'cognome': normalizedCognome,
      'fullName': canonicalFullName,
      'searchPrefixes': canonicalSearchPrefixes,
      'nameSplitConfidence': resolvedManualNameSplitConfidence,
      'identityResolutionStatus': resolvedManualStatus,
      'identityResolution.status': resolvedManualStatus,
      'identityResolution.resolutionSource': resolutionSource,
      'identityResolution.nameSplitConfidence': resolvedManualNameSplitConfidence,
      'identityResolution.resolvedNome': normalizedNome,
      'identityResolution.resolvedCognome': normalizedCognome,
      'identityResolution.resolvedFullName': canonicalFullName,
      'identityResolution.resolvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static void assertPendingNoCfAssistito({
    required String assistitoId,
    required String documentPath,
    required Map<String, dynamic> rawData,
  }) {
    final String identityType = _readString(rawData['identityType']);
    if (identityType != TargetAssistitoNoCfIdentityAnchorNormalizer.identityTypeNoCf) {
      throw RealAssistitiNoCfIdentityResolutionRejectedException(
        code: 'target_assistito_not_nocf',
        message: 'Assistito non NOCF: $documentPath.',
      );
    }

    final String identityAnchor = _readString(rawData['identityAnchor']);
    final String cf = _readString(rawData['cf']);
    final String anchor = identityAnchor.isNotEmpty ? identityAnchor : cf;
    if (!TargetAssistitoNoCfIdentityAnchorNormalizer.isCanonicalNoCf(anchor)) {
      throw RealAssistitiNoCfIdentityResolutionRejectedException(
        code: 'target_assistito_nocf_anchor_invalid',
        message: 'identityAnchor NOCF non canonico: $documentPath.',
      );
    }
    if (cf.isNotEmpty && cf != anchor) {
      throw RealAssistitiNoCfIdentityResolutionRejectedException(
        code: 'target_assistito_cf_anchor_mismatch',
        message: 'cf e identityAnchor NOCF non allineati: $documentPath.',
      );
    }

    if (!isPendingManualResolutionPayload(rawData)) {
      throw RealAssistitiNoCfIdentityResolutionRejectedException(
        code: 'target_assistito_not_pending_manual',
        message: 'Assistito NOCF non più pending_manual: $assistitoId.',
      );
    }
  }

  static bool isPendingManualResolutionPayload(Map<String, dynamic> rawData) {
    if (_readString(rawData['identityResolutionStatus']) ==
        RealAssistitiNoCfIdentityResolutionReader.pendingStatus) {
      return true;
    }
    if (_readString(rawData['nameSplitConfidence']) ==
        RealAssistitiNoCfIdentityResolutionReader.pendingConfidence) {
      return true;
    }
    final Object? identityResolution = rawData['identityResolution'];
    if (identityResolution is Map) {
      return _readString(identityResolution['status']) ==
          RealAssistitiNoCfIdentityResolutionReader.pendingStatus;
    }
    return false;
  }

  static String normalizeManualNamePart({
    required String fieldName,
    required String value,
  }) {
    final String trimmed = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) {
      throw RealAssistitiNoCfIdentityResolutionRejectedException(
        code: 'manual_identity_${fieldName}_empty',
        message: '$fieldName manuale obbligatorio per risoluzione NOCF.',
      );
    }
    if (TargetAssistitoIdentityNormalizer.containsFiscalCodeLikeToken(trimmed)) {
      throw RealAssistitiNoCfIdentityResolutionRejectedException(
        code: 'manual_identity_contains_cf_token',
        message: '$fieldName manuale contiene token CF-like: risoluzione NOCF bloccata.',
      );
    }
    final String normalized = TargetAssistitoIdentityNormalizer.normalizeNamePart(trimmed);
    if (normalized.isEmpty) {
      throw RealAssistitiNoCfIdentityResolutionRejectedException(
        code: 'manual_identity_${fieldName}_invalid',
        message: '$fieldName manuale non valido per risoluzione NOCF.',
      );
    }
    if (TargetAssistitoIdentityNormalizer.containsFiscalCodeLikeToken(normalized)) {
      throw RealAssistitiNoCfIdentityResolutionRejectedException(
        code: 'manual_identity_contains_cf_token',
        message: '$fieldName manuale normalizzato contiene token CF-like: risoluzione NOCF bloccata.',
      );
    }
    return normalized;
  }

  static String buildCanonicalFullName({
    required String nome,
    required String cognome,
  }) {
    final String normalizedNome = normalizeManualNamePart(fieldName: 'nome', value: nome);
    final String normalizedCognome = normalizeManualNamePart(fieldName: 'cognome', value: cognome);
    final String fullName = <String>[normalizedCognome, normalizedNome].join(' ').trim();
    if (TargetAssistitoIdentityNormalizer.containsFiscalCodeLikeToken(fullName)) {
      throw const RealAssistitiNoCfIdentityResolutionRejectedException(
        code: 'manual_identity_contains_cf_token',
        message: 'fullName manuale contiene token CF-like: risoluzione NOCF bloccata.',
      );
    }
    return TargetAssistitoIdentityNormalizer.normalizeFullName(fullName);
  }

  static List<String> buildResolvedSearchPrefixes(String fullName) {
    final String normalizedFullName = TargetAssistitoIdentityNormalizer.normalizeFullName(fullName);
    if (normalizedFullName.isEmpty) {
      throw const RealAssistitiNoCfIdentityResolutionRejectedException(
        code: 'manual_identity_full_name_invalid',
        message: 'fullName manuale non valido per risoluzione NOCF.',
      );
    }
    final List<String> prefixes = RealAssistitiTargetPreviewMapper.buildSearchPrefixes(normalizedFullName);
    if (prefixes.isEmpty) {
      throw const RealAssistitiNoCfIdentityResolutionRejectedException(
        code: 'manual_identity_search_prefixes_empty',
        message: 'searchPrefixes vuoti dopo risoluzione manuale NOCF.',
      );
    }
    return prefixes;
  }

  static String normalizeTenantId(String value) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw const RealAssistitiNoCfIdentityResolutionRejectedException(
        code: 'tenant_id_empty',
        message: 'tenantId obbligatorio per risoluzione NOCF.',
      );
    }
    if (normalized.contains('/')) {
      throw const RealAssistitiNoCfIdentityResolutionRejectedException(
        code: 'tenant_id_not_canonical',
        message: 'tenantId non canonico: slash non ammesso.',
      );
    }
    return normalized;
  }

  static String normalizeAssistitoId(String value) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw const RealAssistitiNoCfIdentityResolutionRejectedException(
        code: 'assistito_id_empty',
        message: 'assistitoId obbligatorio per risoluzione NOCF.',
      );
    }
    if (normalized.contains('/')) {
      throw const RealAssistitiNoCfIdentityResolutionRejectedException(
        code: 'assistito_id_not_canonical',
        message: 'assistitoId non canonico: slash non ammesso.',
      );
    }
    return normalized;
  }

  static List<String> sortedRootKeys(Map<String, dynamic> payload) {
    final Set<String> rootKeys = <String>{};
    for (final String key in payload.keys) {
      rootKeys.add(key.split('.').first);
    }
    return List<String>.unmodifiable(rootKeys.toList(growable: false)..sort());
  }

  static bool _sameStringList(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (int index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  static String _readString(Object? value) {
    return value?.toString().trim() ?? '';
  }
}
