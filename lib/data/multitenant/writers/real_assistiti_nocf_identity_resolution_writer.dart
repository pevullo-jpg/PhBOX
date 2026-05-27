import 'package:cloud_firestore/cloud_firestore.dart';

import '../mappers/real_assistiti_target_preview_mapper.dart';
import '../models/target_multitenant_collections.dart';

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
  final List<String> updatedFields;

  const RealAssistitiNoCfIdentityResolutionWriteResult({
    required this.tenantId,
    required this.assistitoId,
    required this.documentPath,
    required this.updatedFields,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tenantId': tenantId,
      'assistitoId': assistitoId,
      'documentPath': documentPath,
      'updatedFields': updatedFields,
    };
  }
}

class RealAssistitiNoCfIdentityResolutionWriter {
  static const String resolvedStatus = 'resolved_manual';
  static const String resolvedConfidence = 'resolved_manual_nocf_identity';
  static const String resolutionSource = 'frontend_modal_identity_resolution';

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
    final String normalizedTenantId = _normalizeSegment(tenantId, label: 'tenantId');
    final String normalizedAssistitoId = _normalizeSegment(assistitoId, label: 'assistitoId');
    final Map<String, dynamic> patch = buildManualResolutionPatch(
      nome: nome,
      cognome: cognome,
    );

    final String documentPath = TargetMultitenantCollections.assistitoDocument(
      tenantId: normalizedTenantId,
      assistitoId: normalizedAssistitoId,
    );

    await firestore.doc(documentPath).update(patch);

    return RealAssistitiNoCfIdentityResolutionWriteResult(
      tenantId: normalizedTenantId,
      assistitoId: normalizedAssistitoId,
      documentPath: documentPath,
      updatedFields: List<String>.unmodifiable(patch.keys.toList(growable: false)..sort()),
    );
  }

  static Map<String, dynamic> buildManualResolutionPatch({
    required String nome,
    required String cognome,
  }) {
    final String normalizedNome = _normalizeHumanNamePart(nome, label: 'nome');
    final String normalizedCognome = _normalizeHumanNamePart(cognome, label: 'cognome');
    final String fullName = _joinCanonicalFullName(
      nome: normalizedNome,
      cognome: normalizedCognome,
    );

    if (fullName.isEmpty) {
      throw const RealAssistitiNoCfIdentityResolutionRejectedException(
        code: 'identity_resolution_empty',
        message: 'Nome/cognome vuoti: risoluzione identità NOCF bloccata.',
      );
    }

    return Map<String, dynamic>.unmodifiable(<String, dynamic>{
      'nome': normalizedNome,
      'cognome': normalizedCognome,
      'fullName': fullName,
      'searchPrefixes': RealAssistitiTargetPreviewMapper.buildSearchPrefixes(fullName),
      'nameSplitConfidence': resolvedConfidence,
      'identityResolutionStatus': resolvedStatus,
      'identityResolution.status': resolvedStatus,
      'identityResolution.resolutionSource': resolutionSource,
      'identityResolution.resolvedAt': FieldValue.serverTimestamp(),
      'identityResolution.resolvedBy': 'frontend_operator',
      'identityResolution.selectedNome': normalizedNome,
      'identityResolution.selectedCognome': normalizedCognome,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static String _joinCanonicalFullName({
    required String nome,
    required String cognome,
  }) {
    return <String>[cognome, nome]
        .where((String item) => item.trim().isNotEmpty)
        .join(' ')
        .trim();
  }

  static String _normalizeHumanNamePart(String value, {required String label}) {
    final String normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      return '';
    }
    if (normalized.contains('/')) {
      throw RealAssistitiNoCfIdentityResolutionRejectedException(
        code: '${label}_contains_slash',
        message: '$label non può contenere slash.',
      );
    }
    if (_looksTechnicalIdentityCode(normalized)) {
      throw RealAssistitiNoCfIdentityResolutionRejectedException(
        code: '${label}_technical_code',
        message: '$label non può essere un codice tecnico.',
      );
    }
    return normalized
        .split(' ')
        .map(_normalizeNameWord)
        .where((String item) => item.isNotEmpty)
        .join(' ');
  }

  static bool _looksTechnicalIdentityCode(String value) {
    final String compact = value.replaceAll(RegExp(r'\s+'), '').trim().toUpperCase();
    return compact.startsWith('NOCF_') ||
        compact.startsWith('TMP_') ||
        compact.startsWith('MANUAL_') ||
        compact.startsWith('MANUALE_');
  }

  static String _normalizeNameWord(String value) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      return '';
    }
    return normalized
        .split('-')
        .map(_normalizeApostropheNameWord)
        .where((String item) => item.isNotEmpty)
        .join('-');
  }

  static String _normalizeApostropheNameWord(String value) {
    return value
        .split("'")
        .map(_capitalizeNameAtom)
        .where((String item) => item.isNotEmpty)
        .join("'");
  }

  static String _capitalizeNameAtom(String value) {
    final String lower = value.trim().toLowerCase();
    if (lower.isEmpty) {
      return '';
    }
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }

  static String _normalizeSegment(String value, {required String label}) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, label, 'Segmento vuoto non valido.');
    }
    if (normalized.contains('/')) {
      throw ArgumentError.value(value, label, 'Segmento con slash non valido.');
    }
    return normalized;
  }
}
