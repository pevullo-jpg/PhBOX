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
  final String cfLockDocumentId;
  final String cfLockDocumentPath;
  final Map<String, dynamic> targetPayload;
  final Map<String, dynamic> cfLockPayload;

  const RealAssistitiTargetCopyWrittenDocument({
    required this.cf,
    required this.documentId,
    required this.documentPath,
    required this.cfLockDocumentId,
    required this.cfLockDocumentPath,
    required this.targetPayload,
    required this.cfLockPayload,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'cf': cf,
      'documentId': documentId,
      'documentPath': documentPath,
      'cfLockDocumentId': cfLockDocumentId,
      'cfLockDocumentPath': cfLockDocumentPath,
      'targetPayload': targetPayload,
      'cfLockPayload': cfLockPayload,
    };
  }
}

class RealAssistitiTargetCopyResult {
  final String tenantId;
  final String collectionPath;
  final String cfLocksCollectionPath;
  final List<String> requestedFiscalCodes;
  final List<RealAssistitiTargetCopyWrittenDocument> writtenDocuments;
  final int maxDocumentsPerRun;
  final int maxFirestoreWritesPerRun;
  final int attemptedAssistitiWrites;
  final int attemptedCfLockWrites;
  final int attemptedWrites;
  final RealAssistitiDryRunPreviewResult dryRunPreview;

  const RealAssistitiTargetCopyResult({
    required this.tenantId,
    required this.collectionPath,
    required this.cfLocksCollectionPath,
    required this.requestedFiscalCodes,
    required this.writtenDocuments,
    required this.maxDocumentsPerRun,
    required this.maxFirestoreWritesPerRun,
    required this.attemptedAssistitiWrites,
    required this.attemptedCfLockWrites,
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
      'cfLocksCollectionPath': cfLocksCollectionPath,
      'requestedFiscalCodes': requestedFiscalCodes,
      'requestedCount': requestedCount,
      'writtenCount': writtenCount,
      'maxDocumentsPerRun': maxDocumentsPerRun,
      'maxFirestoreWritesPerRun': maxFirestoreWritesPerRun,
      'attemptedAssistitiWrites': attemptedAssistitiWrites,
      'attemptedCfLockWrites': attemptedCfLockWrites,
      'attemptedWrites': attemptedWrites,
      'dryRunPreview': dryRunPreview.toMap(),
      'writtenDocuments': mappedDocuments,
    };
  }
}

class _PreparedTargetCopyWrite {
  final String cf;
  final DocumentReference<Map<String, dynamic>> assistitoReference;
  final DocumentReference<Map<String, dynamic>> cfLockReference;
  final Map<String, dynamic> targetPayload;
  final Map<String, dynamic> cfLockPayload;
  final RealAssistitiTargetCopyWrittenDocument writtenDocument;

  const _PreparedTargetCopyWrite({
    required this.cf,
    required this.assistitoReference,
    required this.cfLockReference,
    required this.targetPayload,
    required this.cfLockPayload,
    required this.writtenDocument,
  });
}

class RealAssistitiTargetCopyWriter {
  static const int maxDocumentsPerRun = ManualFiscalCodeInputValidator.defaultMaxFiscalCodes;
  static const int writesPerDocument = 2;
  static const int maxFirestoreWritesPerRun = maxDocumentsPerRun * writesPerDocument;
  static const String manualConfirmationTokenPrefix = 'COPIA_REALE_ASSISTITI_TARGET';
  static const String cfLocksCollectionId = 'assistiti_cf_locks';

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
    final String cfLocksCollectionPath = TargetMultitenantCollections.tenantCollection(
      tenantId: normalizedTenantId,
      collectionId: cfLocksCollectionId,
    );
    final CollectionReference<Map<String, dynamic>> assistitiCollection =
        firestore.collection(collectionPath);
    final CollectionReference<Map<String, dynamic>> cfLocksCollection =
        firestore.collection(cfLocksCollectionPath);

    final List<_PreparedTargetCopyWrite> preparedWrites = _prepareTargetCopyWrites(
      tenantId: normalizedTenantId,
      assistitiCollection: assistitiCollection,
      cfLocksCollection: cfLocksCollection,
      dryRunPreview: dryRunPreview,
    );

    final List<RealAssistitiTargetCopyWrittenDocument> writtenDocuments =
        await firestore.runTransaction<List<RealAssistitiTargetCopyWrittenDocument>>(
      (Transaction transaction) async {
        for (final _PreparedTargetCopyWrite preparedWrite in preparedWrites) {
          final DocumentSnapshot<Map<String, dynamic>> lockSnapshot =
              await transaction.get(preparedWrite.cfLockReference);
          if (lockSnapshot.exists) {
            throw RealAssistitiTargetCopyRejectedException(
              code: 'target_assistito_cf_lock_exists',
              message:
                  'Lock target già presente per CF ${preparedWrite.cf}: copia atomica bloccata.',
            );
          }
        }

        final List<RealAssistitiTargetCopyWrittenDocument> transactionWrittenDocuments =
            <RealAssistitiTargetCopyWrittenDocument>[];
        for (final _PreparedTargetCopyWrite preparedWrite in preparedWrites) {
          transaction.set(preparedWrite.cfLockReference, preparedWrite.cfLockPayload);
          transaction.set(preparedWrite.assistitoReference, preparedWrite.targetPayload);
          transactionWrittenDocuments.add(preparedWrite.writtenDocument);
        }
        return List<RealAssistitiTargetCopyWrittenDocument>.unmodifiable(
          transactionWrittenDocuments,
        );
      },
    );

    return RealAssistitiTargetCopyResult(
      tenantId: normalizedTenantId,
      collectionPath: collectionPath,
      cfLocksCollectionPath: cfLocksCollectionPath,
      requestedFiscalCodes: normalizedFiscalCodes,
      writtenDocuments: writtenDocuments,
      maxDocumentsPerRun: maxDocumentsPerRun,
      maxFirestoreWritesPerRun: maxFirestoreWritesPerRun,
      attemptedAssistitiWrites: writtenDocuments.length,
      attemptedCfLockWrites: writtenDocuments.length,
      attemptedWrites: writtenDocuments.length * writesPerDocument,
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

  static List<_PreparedTargetCopyWrite> _prepareTargetCopyWrites({
    required String tenantId,
    required CollectionReference<Map<String, dynamic>> assistitiCollection,
    required CollectionReference<Map<String, dynamic>> cfLocksCollection,
    required RealAssistitiDryRunPreviewResult dryRunPreview,
  }) {
    final List<_PreparedTargetCopyWrite> preparedWrites = <_PreparedTargetCopyWrite>[];

    for (final RealAssistitiDryRunPreviewItem item in dryRunPreview.items) {
      final DocumentReference<Map<String, dynamic>> assistitoReference = assistitiCollection.doc();
      final DocumentReference<Map<String, dynamic>> cfLockReference = cfLocksCollection.doc(item.cf);
      final Map<String, dynamic> targetPayload = _buildTargetPayloadForCopy(
        item: item,
        documentId: assistitoReference.id,
      );
      final String documentPath = TargetMultitenantCollections.assistitoDocument(
        tenantId: tenantId,
        assistitoId: assistitoReference.id,
      );
      final String cfLockDocumentPath = TargetMultitenantCollections.tenantDocument(
        tenantId: tenantId,
        collectionId: cfLocksCollectionId,
        documentId: item.cf,
      );
      final Map<String, dynamic> cfLockPayload = _buildCfLockPayload(
        item: item,
        assistitoId: assistitoReference.id,
        assistitoPath: documentPath,
      );

      preparedWrites.add(_PreparedTargetCopyWrite(
        cf: item.cf,
        assistitoReference: assistitoReference,
        cfLockReference: cfLockReference,
        targetPayload: targetPayload,
        cfLockPayload: cfLockPayload,
        writtenDocument: RealAssistitiTargetCopyWrittenDocument(
          cf: item.cf,
          documentId: assistitoReference.id,
          documentPath: documentPath,
          cfLockDocumentId: item.cf,
          cfLockDocumentPath: cfLockDocumentPath,
          targetPayload: Map<String, dynamic>.unmodifiable(targetPayload),
          cfLockPayload: Map<String, dynamic>.unmodifiable(cfLockPayload),
        ),
      ));
    }

    return List<_PreparedTargetCopyWrite>.unmodifiable(preparedWrites);
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

  static Map<String, dynamic> _buildCfLockPayload({
    required RealAssistitiDryRunPreviewItem item,
    required String assistitoId,
    required String assistitoPath,
  }) {
    if (assistitoId.trim().isEmpty || assistitoId == item.cf) {
      throw RealAssistitiTargetCopyRejectedException(
        code: 'cf_lock_assistito_id_invalid',
        message: 'Lock CF con assistitoId non valido per CF ${item.cf}.',
      );
    }
    return Map<String, dynamic>.unmodifiable(<String, dynamic>{
      'cf': item.cf,
      'assistitoId': assistitoId,
      'assistitoPath': assistitoPath,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': 'real_assistiti_target_copy_writer',
      'lockVersion': 1,
    });
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
