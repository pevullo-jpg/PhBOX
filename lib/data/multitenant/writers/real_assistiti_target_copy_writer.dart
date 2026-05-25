import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/target_multitenant_collections.dart';
import '../readers/real_assistiti_dry_run_preview_reader.dart';
import '../validators/manual_fiscal_code_input_validator.dart';

class RealAssistitiTargetCopyRejectedException implements Exception {
  final String code;
  final String message;

  const RealAssistitiTargetCopyRejectedException({
    required this.code,
    required this.message,
  });

  @override
  String toString() {
    return 'RealAssistitiTargetCopyRejectedException($code): $message';
  }
}

class RealAssistitiTargetCopyWrittenDocument {
  final String cf;
  final String documentId;
  final String documentPath;
  final Map<String, dynamic> targetPayload;

  const RealAssistitiTargetCopyWrittenDocument({
    required this.cf,
    required this.documentId,
    required this.documentPath,
    required this.targetPayload,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'cf': cf,
      'documentId': documentId,
      'documentPath': documentPath,
      'targetPayload': targetPayload,
    };
  }
}

class RealAssistitiTargetCopyResult {
  final String tenantId;
  final String collectionPath;
  final List<String> requestedFiscalCodes;
  final List<RealAssistitiTargetCopyWrittenDocument> writtenDocuments;
  final int maxDocumentsPerRun;
  final int attemptedWrites;
  final RealAssistitiDryRunPreviewResult dryRunPreview;

  const RealAssistitiTargetCopyResult({
    required this.tenantId,
    required this.collectionPath,
    required this.requestedFiscalCodes,
    required this.writtenDocuments,
    required this.maxDocumentsPerRun,
    required this.attemptedWrites,
    required this.dryRunPreview,
  });

  int get requestedCount => requestedFiscalCodes.length;

  int get writtenCount => writtenDocuments.length;

  Map<String, dynamic> toMap() {
    final List<Map<String, dynamic>> mappedDocuments = <Map<String, dynamic>>[];
    for (final RealAssistitiTargetCopyWrittenDocument document in writtenDocuments) {
      mappedDocuments.add(document.toMap());
    }
    return <String, dynamic>{
      'tenantId': tenantId,
      'collectionPath': collectionPath,
      'requestedFiscalCodes': requestedFiscalCodes,
      'requestedCount': requestedCount,
      'writtenCount': writtenCount,
      'maxDocumentsPerRun': maxDocumentsPerRun,
      'attemptedWrites': attemptedWrites,
      'dryRunPreview': dryRunPreview.toMap(),
      'writtenDocuments': mappedDocuments,
    };
  }
}

class RealAssistitiTargetCopyWriter {
  static const int maxDocumentsPerRun = ManualFiscalCodeInputValidator.defaultMaxFiscalCodes;
  static const String manualConfirmationTokenPrefix = 'COPIA_REALE_ASSISTITI_TARGET';

  final FirebaseFirestore firestore;

  const RealAssistitiTargetCopyWriter({
    required this.firestore,
  });

  Future<RealAssistitiTargetCopyResult> copyByManualFiscalCodes({
    required String tenantId,
    required Iterable<String> fiscalCodes,
    required String manualConfirmationToken,
  }) async {
    final String normalizedTenantId = _normalizeTenantId(tenantId);
    final List<String> normalizedFiscalCodes = _normalizeAndValidateManualFiscalCodes(fiscalCodes);
    final String expectedManualConfirmationToken = buildRequiredManualConfirmationToken(
      tenantId: normalizedTenantId,
      normalizedFiscalCodes: normalizedFiscalCodes,
    );

    if (manualConfirmationToken.trim() != expectedManualConfirmationToken) {
      throw const RealAssistitiTargetCopyRejectedException(
        code: 'manual_confirmation_token_invalid',
        message: 'Token manuale non valido per la copia reale assistiti target.',
      );
    }

    final RealAssistitiDryRunPreviewReader previewReader = RealAssistitiDryRunPreviewReader(
      firestore: firestore,
    );
    final RealAssistitiDryRunPreviewResult dryRunPreview =
        await previewReader.previewByManualFiscalCodes(
      tenantId: normalizedTenantId,
      fiscalCodes: normalizedFiscalCodes,
    );

    _assertDryRunCanBeCopied(dryRunPreview);

    final String collectionPath = TargetMultitenantCollections.tenantCollection(
      tenantId: normalizedTenantId,
      collectionId: TargetMultitenantCollections.assistiti,
    );
    final CollectionReference<Map<String, dynamic>> collection = firestore.collection(collectionPath);
    final WriteBatch batch = firestore.batch();
    final List<RealAssistitiTargetCopyWrittenDocument> writtenDocuments =
        <RealAssistitiTargetCopyWrittenDocument>[];

    for (final RealAssistitiDryRunPreviewItem item in dryRunPreview.items) {
      final DocumentReference<Map<String, dynamic>> document = collection.doc();
      final Map<String, dynamic> targetPayload = _buildTargetPayloadForCopy(
        item: item,
        documentId: document.id,
      );
      final String documentPath = TargetMultitenantCollections.assistitoDocument(
        tenantId: normalizedTenantId,
        assistitoId: document.id,
      );

      batch.set(document, targetPayload);
      writtenDocuments.add(RealAssistitiTargetCopyWrittenDocument(
        cf: item.cf,
        documentId: document.id,
        documentPath: documentPath,
        targetPayload: Map<String, dynamic>.unmodifiable(targetPayload),
      ));
    }

    await batch.commit();

    return RealAssistitiTargetCopyResult(
      tenantId: normalizedTenantId,
      collectionPath: collectionPath,
      requestedFiscalCodes: normalizedFiscalCodes,
      writtenDocuments: List<RealAssistitiTargetCopyWrittenDocument>.unmodifiable(writtenDocuments),
      maxDocumentsPerRun: maxDocumentsPerRun,
      attemptedWrites: writtenDocuments.length,
      dryRunPreview: dryRunPreview,
    );
  }

  static String buildRequiredManualConfirmationToken({
    required String tenantId,
    required Iterable<String> normalizedFiscalCodes,
  }) {
    final String normalizedTenantId = _normalizeTenantId(tenantId);
    final List<String> safeFiscalCodes = _normalizeAndValidateManualFiscalCodes(normalizedFiscalCodes);
    return '$manualConfirmationTokenPrefix:$normalizedTenantId:${safeFiscalCodes.join(',')}';
  }

  static void _assertDryRunCanBeCopied(RealAssistitiDryRunPreviewResult dryRunPreview) {
    if (dryRunPreview.items.isEmpty) {
      throw const RealAssistitiTargetCopyRejectedException(
        code: 'dry_run_preview_empty',
        message: 'Dry-run reale assistiti vuoto: copia target bloccata.',
      );
    }
    if (dryRunPreview.items.length > maxDocumentsPerRun) {
      throw const RealAssistitiTargetCopyRejectedException(
        code: 'dry_run_preview_exceeds_hard_cap',
        message: 'Dry-run reale assistiti oltre limite hard: copia target bloccata.',
      );
    }
    if (dryRunPreview.hasBlockingIssues) {
      throw RealAssistitiTargetCopyRejectedException(
        code: 'dry_run_preview_blocked',
        message:
            'Dry-run reale assistiti contiene blocchi per CF: ${dryRunPreview.blockedFiscalCodes.join(', ')}.',
      );
    }
    for (final RealAssistitiDryRunPreviewItem item in dryRunPreview.items) {
      if (!item.canProceedToManualCopyStep) {
        throw RealAssistitiTargetCopyRejectedException(
          code: 'dry_run_preview_item_not_copyable',
          message: 'Preview non copiabile per CF ${item.cf}.',
        );
      }
      if (item.targetPreviewPayloadWithoutAssistitoId.containsKey('assistitoId')) {
        throw RealAssistitiTargetCopyRejectedException(
          code: 'dry_run_preview_contains_assistito_id',
          message: 'La preview contiene già assistitoId per CF ${item.cf}.',
        );
      }
    }
  }

  static Map<String, dynamic> _buildTargetPayloadForCopy({
    required RealAssistitiDryRunPreviewItem item,
    required String documentId,
  }) {
    final String assistitoId = documentId.trim();
    if (assistitoId.isEmpty) {
      throw RealAssistitiTargetCopyRejectedException(
        code: 'generated_assistito_id_empty',
        message: 'Auto-id Firestore vuoto per CF ${item.cf}.',
      );
    }
    if (assistitoId == item.cf) {
      throw RealAssistitiTargetCopyRejectedException(
        code: 'generated_assistito_id_not_opaque',
        message: 'Auto-id Firestore non opaco per CF ${item.cf}.',
      );
    }

    final Map<String, dynamic> targetPayload =
        Map<String, dynamic>.from(item.targetPreviewPayloadWithoutAssistitoId);
    if (targetPayload.containsKey('assistitoId')) {
      throw RealAssistitiTargetCopyRejectedException(
        code: 'target_payload_assistito_id_preexisting',
        message: 'Payload target contiene assistitoId prima della copia per CF ${item.cf}.',
      );
    }

    targetPayload['assistitoId'] = assistitoId;

    if (targetPayload['cf'] != item.cf) {
      throw RealAssistitiTargetCopyRejectedException(
        code: 'target_payload_cf_mismatch',
        message: 'Payload target con CF non coerente per CF ${item.cf}.',
      );
    }
    if (_readString(targetPayload['nome']).isEmpty ||
        _readString(targetPayload['cognome']).isEmpty ||
        _readString(targetPayload['fullName']).isEmpty) {
      throw RealAssistitiTargetCopyRejectedException(
        code: 'target_payload_identity_incomplete',
        message: 'Payload target con identità incompleta per CF ${item.cf}.',
      );
    }
    if (!_hasNonNullTimestamp(targetPayload['createdAt']) ||
        !_hasNonNullTimestamp(targetPayload['updatedAt'])) {
      throw RealAssistitiTargetCopyRejectedException(
        code: 'target_payload_timestamp_missing',
        message: 'Payload target senza createdAt/updatedAt validi per CF ${item.cf}.',
      );
    }

    return Map<String, dynamic>.unmodifiable(targetPayload);
  }

  static List<String> _normalizeAndValidateManualFiscalCodes(Iterable<String> fiscalCodes) {
    try {
      return ManualFiscalCodeInputValidator.normalizeAndValidate(
        fiscalCodes: fiscalCodes,
        maxFiscalCodes: maxDocumentsPerRun,
      );
    } on ManualFiscalCodeInputRejectedException catch (error) {
      throw RealAssistitiTargetCopyRejectedException(
        code: error.code,
        message: error.message,
      );
    }
  }

  static String _normalizeTenantId(String value) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw const RealAssistitiTargetCopyRejectedException(
        code: 'tenant_id_empty',
        message: 'tenantId obbligatorio per copia reale assistiti target.',
      );
    }
    if (normalized.contains('/')) {
      throw const RealAssistitiTargetCopyRejectedException(
        code: 'tenant_id_not_canonical',
        message: 'tenantId non canonico: slash non ammesso.',
      );
    }
    return normalized;
  }

  static bool _hasNonNullTimestamp(Object? value) {
    if (value == null) {
      return false;
    }
    if (value is DateTime) {
      return true;
    }
    if (value is String) {
      return DateTime.tryParse(value.trim()) != null;
    }
    try {
      final dynamic converted = (value as dynamic).toDate();
      return converted is DateTime;
    } catch (_) {}
    return false;
  }

  static String _readString(Object? value) {
    return value?.toString().trim() ?? '';
  }
}
