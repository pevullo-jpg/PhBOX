import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/target_multitenant_collections.dart';
import '../readers/legacy_real_assistiti_bounded_reader.dart';
import '../readers/real_assistiti_dry_run_preview_reader.dart';
import '../validators/manual_fiscal_code_input_validator.dart';
import '../writers/real_assistiti_target_copy_writer.dart';

class RealAssistitiPostCopyVerificationRejectedException implements Exception {
  final String code;
  final String message;

  const RealAssistitiPostCopyVerificationRejectedException({
    required this.code,
    required this.message,
  });

  @override
  String toString() {
    return 'RealAssistitiPostCopyVerificationRejectedException($code): $message';
  }
}

class RealAssistitiPostCopyDocumentRead {
  final String cf;
  final String documentId;
  final String documentPath;
  final bool exists;
  final Map<String, dynamic> rawData;

  const RealAssistitiPostCopyDocumentRead({
    required this.cf,
    required this.documentId,
    required this.documentPath,
    required this.exists,
    required this.rawData,
  });

  bool get missing => !exists;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'cf': cf,
      'documentId': documentId,
      'documentPath': documentPath,
      'exists': exists,
      'missing': missing,
      'rawData': rawData,
    };
  }
}

class RealAssistitiPostCopyLockRead {
  final String cf;
  final String documentId;
  final String documentPath;
  final bool exists;
  final Map<String, dynamic> rawData;

  const RealAssistitiPostCopyLockRead({
    required this.cf,
    required this.documentId,
    required this.documentPath,
    required this.exists,
    required this.rawData,
  });

  bool get missing => !exists;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'cf': cf,
      'documentId': documentId,
      'documentPath': documentPath,
      'exists': exists,
      'missing': missing,
      'rawData': rawData,
    };
  }
}

class RealAssistitiPostCopyVerificationItem {
  final String cf;
  final String documentId;
  final String documentPath;
  final LegacyRealAssistitoReadBundle legacyBundle;
  final RealAssistitiDryRunPreviewItem dryRunPreviewItem;
  final RealAssistitiTargetCopyWrittenDocument writtenDocument;
  final RealAssistitiPostCopyDocumentRead targetRead;
  final RealAssistitiPostCopyLockRead cfLockRead;
  final Map<String, dynamic> expectedTargetPayload;
  final List<String> mismatchReasons;

  const RealAssistitiPostCopyVerificationItem({
    required this.cf,
    required this.documentId,
    required this.documentPath,
    required this.legacyBundle,
    required this.dryRunPreviewItem,
    required this.writtenDocument,
    required this.targetRead,
    required this.cfLockRead,
    required this.expectedTargetPayload,
    required this.mismatchReasons,
  });

  bool get verified => mismatchReasons.isEmpty;

  bool get failed => !verified;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'cf': cf,
      'documentId': documentId,
      'documentPath': documentPath,
      'verified': verified,
      'failed': failed,
      'mismatchReasons': mismatchReasons,
      'expectedTargetPayload': expectedTargetPayload,
      'targetRead': targetRead.toMap(),
      'cfLockRead': cfLockRead.toMap(),
      'writtenDocument': writtenDocument.toMap(),
      'dryRunPreviewItem': dryRunPreviewItem.toMap(),
      'legacyBundle': legacyBundle.toMap(),
    };
  }
}

class RealAssistitiPostCopyVerificationResult {
  final String tenantId;
  final String collectionPath;
  final String cfLocksCollectionPath;
  final List<String> requestedFiscalCodes;
  final List<RealAssistitiPostCopyVerificationItem> items;
  final int targetDocumentReads;
  final int cfLockDocumentReads;
  final int legacyAttemptedDocumentReads;
  final RealAssistitiTargetCopyResult copyResult;

  const RealAssistitiPostCopyVerificationResult({
    required this.tenantId,
    required this.collectionPath,
    required this.cfLocksCollectionPath,
    required this.requestedFiscalCodes,
    required this.items,
    required this.targetDocumentReads,
    required this.cfLockDocumentReads,
    required this.legacyAttemptedDocumentReads,
    required this.copyResult,
  });

  int get requestedCount => requestedFiscalCodes.length;

  int get verifiedCount {
    int count = 0;
    for (final RealAssistitiPostCopyVerificationItem item in items) {
      if (item.verified) {
        count++;
      }
    }
    return count;
  }

  bool get allVerified => verifiedCount == items.length && items.isNotEmpty;

  bool get hasFailures => !allVerified;

  List<String> get failedFiscalCodes {
    final List<String> failed = <String>[];
    for (final RealAssistitiPostCopyVerificationItem item in items) {
      if (item.failed) {
        failed.add(item.cf);
      }
    }
    return List<String>.unmodifiable(failed);
  }

  int get totalAttemptedReads {
    return targetDocumentReads + cfLockDocumentReads + legacyAttemptedDocumentReads;
  }

  Map<String, dynamic> toMap() {
    final List<Map<String, dynamic>> mappedItems = <Map<String, dynamic>>[];
    for (final RealAssistitiPostCopyVerificationItem item in items) {
      mappedItems.add(item.toMap());
    }
    return <String, dynamic>{
      'tenantId': tenantId,
      'collectionPath': collectionPath,
      'cfLocksCollectionPath': cfLocksCollectionPath,
      'requestedFiscalCodes': requestedFiscalCodes,
      'requestedCount': requestedCount,
      'verifiedCount': verifiedCount,
      'allVerified': allVerified,
      'hasFailures': hasFailures,
      'failedFiscalCodes': failedFiscalCodes,
      'targetDocumentReads': targetDocumentReads,
      'cfLockDocumentReads': cfLockDocumentReads,
      'legacyAttemptedDocumentReads': legacyAttemptedDocumentReads,
      'totalAttemptedReads': totalAttemptedReads,
      'copyResult': copyResult.toMap(),
      'items': mappedItems,
    };
  }
}

class RealAssistitiPostCopyVerifier {
  static const int maxDocumentsPerRun = RealAssistitiTargetCopyWriter.maxDocumentsPerRun;

  final FirebaseFirestore firestore;

  const RealAssistitiPostCopyVerifier({
    required this.firestore,
  });

  Future<RealAssistitiPostCopyVerificationResult> verifyCopyResult({
    required RealAssistitiTargetCopyResult copyResult,
  }) async {
    final String normalizedTenantId = _normalizeTenantId(copyResult.tenantId);
    final List<String> normalizedFiscalCodes = _normalizeAndValidateWrittenFiscalCodes(copyResult);
    final String collectionPath = TargetMultitenantCollections.tenantCollection(
      tenantId: normalizedTenantId,
      collectionId: TargetMultitenantCollections.assistiti,
    );
    final String cfLocksCollectionPath = TargetMultitenantCollections.tenantCollection(
      tenantId: normalizedTenantId,
      collectionId: RealAssistitiTargetCopyWriter.cfLocksCollectionId,
    );

    _assertCopyResultPaths(
      copyResult: copyResult,
      expectedCollectionPath: collectionPath,
      expectedCfLocksCollectionPath: cfLocksCollectionPath,
    );

    final LegacyRealAssistitiBoundedReader legacyReader = LegacyRealAssistitiBoundedReader(
      firestore: firestore,
    );
    final LegacyRealAssistitiBoundedReadResult legacyResult =
        await legacyReader.readByManualFiscalCodes(fiscalCodes: normalizedFiscalCodes);

    final Map<String, LegacyRealAssistitoReadBundle> legacyByCf =
        <String, LegacyRealAssistitoReadBundle>{};
    for (final LegacyRealAssistitoReadBundle bundle in legacyResult.bundles) {
      legacyByCf[bundle.cf] = bundle;
    }

    final Map<String, RealAssistitiDryRunPreviewItem> previewItemsByCf =
        <String, RealAssistitiDryRunPreviewItem>{};
    for (final RealAssistitiDryRunPreviewItem item in copyResult.dryRunPreview.items) {
      previewItemsByCf[item.cf] = item;
    }

    final CollectionReference<Map<String, dynamic>> assistitiCollection =
        firestore.collection(collectionPath);
    final CollectionReference<Map<String, dynamic>> cfLocksCollection =
        firestore.collection(cfLocksCollectionPath);

    final List<RealAssistitiPostCopyVerificationItem> items =
        <RealAssistitiPostCopyVerificationItem>[];

    for (final RealAssistitiTargetCopyWrittenDocument writtenDocument
        in copyResult.writtenDocuments) {
      final LegacyRealAssistitoReadBundle? legacyBundle = legacyByCf[writtenDocument.cf];
      final RealAssistitiDryRunPreviewItem? previewItem = previewItemsByCf[writtenDocument.cf];
      if (legacyBundle == null) {
        throw RealAssistitiPostCopyVerificationRejectedException(
          code: 'legacy_bundle_missing_for_written_cf',
          message: 'Bundle legacy assente per CF copiato ${writtenDocument.cf}.',
        );
      }
      if (previewItem == null) {
        throw RealAssistitiPostCopyVerificationRejectedException(
          code: 'dry_run_preview_item_missing_for_written_cf',
          message: 'Preview dry-run assente per CF copiato ${writtenDocument.cf}.',
        );
      }

      final String expectedTargetDocumentPath = TargetMultitenantCollections.assistitoDocument(
        tenantId: normalizedTenantId,
        assistitoId: writtenDocument.documentId,
      );
      final String expectedCfLockDocumentPath = TargetMultitenantCollections.tenantDocument(
        tenantId: normalizedTenantId,
        collectionId: RealAssistitiTargetCopyWriter.cfLocksCollectionId,
        documentId: writtenDocument.cf,
      );

      final RealAssistitiPostCopyDocumentRead targetRead = await _readTargetDocument(
        cf: writtenDocument.cf,
        documentId: writtenDocument.documentId,
        documentPath: expectedTargetDocumentPath,
        collection: assistitiCollection,
      );
      final RealAssistitiPostCopyLockRead cfLockRead = await _readCfLockDocument(
        cf: writtenDocument.cf,
        expectedDocumentPath: expectedCfLockDocumentPath,
        collection: cfLocksCollection,
      );
      items.add(_buildVerificationItem(
        legacyBundle: legacyBundle,
        previewItem: previewItem,
        writtenDocument: writtenDocument,
        targetRead: targetRead,
        cfLockRead: cfLockRead,
        expectedTargetDocumentPath: expectedTargetDocumentPath,
        expectedCfLockDocumentPath: expectedCfLockDocumentPath,
      ));
    }

    return RealAssistitiPostCopyVerificationResult(
      tenantId: normalizedTenantId,
      collectionPath: collectionPath,
      cfLocksCollectionPath: cfLocksCollectionPath,
      requestedFiscalCodes: normalizedFiscalCodes,
      items: List<RealAssistitiPostCopyVerificationItem>.unmodifiable(items),
      targetDocumentReads: copyResult.writtenDocuments.length,
      cfLockDocumentReads: copyResult.writtenDocuments.length,
      legacyAttemptedDocumentReads: legacyResult.attemptedDocumentReads,
      copyResult: copyResult,
    );
  }

  Future<RealAssistitiPostCopyDocumentRead> _readTargetDocument({
    required String cf,
    required String documentId,
    required String documentPath,
    required CollectionReference<Map<String, dynamic>> collection,
  }) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await collection
        .doc(documentId)
        .get(const GetOptions(source: Source.serverAndCache));
    return RealAssistitiPostCopyDocumentRead(
      cf: cf,
      documentId: documentId,
      documentPath: documentPath,
      exists: snapshot.exists,
      rawData: Map<String, dynamic>.unmodifiable(snapshot.data() ?? <String, dynamic>{}),
    );
  }

  Future<RealAssistitiPostCopyLockRead> _readCfLockDocument({
    required String cf,
    required String expectedDocumentPath,
    required CollectionReference<Map<String, dynamic>> collection,
  }) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await collection
        .doc(cf)
        .get(const GetOptions(source: Source.serverAndCache));
    return RealAssistitiPostCopyLockRead(
      cf: cf,
      documentId: cf,
      documentPath: expectedDocumentPath,
      exists: snapshot.exists,
      rawData: Map<String, dynamic>.unmodifiable(snapshot.data() ?? <String, dynamic>{}),
    );
  }

  RealAssistitiPostCopyVerificationItem _buildVerificationItem({
    required LegacyRealAssistitoReadBundle legacyBundle,
    required RealAssistitiDryRunPreviewItem previewItem,
    required RealAssistitiTargetCopyWrittenDocument writtenDocument,
    required RealAssistitiPostCopyDocumentRead targetRead,
    required RealAssistitiPostCopyLockRead cfLockRead,
    required String expectedTargetDocumentPath,
    required String expectedCfLockDocumentPath,
  }) {
    final List<String> mismatchReasons = <String>[];
    final Map<String, dynamic> expectedTargetPayload =
        Map<String, dynamic>.unmodifiable(writtenDocument.targetPayload);

    if (writtenDocument.documentPath != expectedTargetDocumentPath) {
      mismatchReasons.add('written_document_path_mismatch');
    }
    if (writtenDocument.cfLockDocumentPath != expectedCfLockDocumentPath) {
      mismatchReasons.add('written_cf_lock_path_mismatch');
    }

    if (!legacyBundle.hasAnyLegacySource) {
      mismatchReasons.add('legacy_source_missing_after_copy');
    }
    if (previewItem.blocked) {
      mismatchReasons.add('dry_run_preview_was_blocked');
    }
    if (previewItem.targetPreviewPayloadWithoutAssistitoId.containsKey('assistitoId')) {
      mismatchReasons.add('dry_run_preview_contains_assistito_id');
    }
    if (!_writtenPayloadMatchesPreview(
      previewItem: previewItem,
      writtenDocument: writtenDocument,
    )) {
      mismatchReasons.add('written_payload_drift_from_preview');
    }
    if (!targetRead.exists) {
      mismatchReasons.add('target_document_missing');
    }
    if (!cfLockRead.exists) {
      mismatchReasons.add('cf_lock_document_missing');
    }
    if (_readString(targetRead.rawData['assistitoId']) != writtenDocument.documentId) {
      mismatchReasons.add('target_assistito_id_mismatch');
    }
    if (_readString(targetRead.rawData['cf']) != writtenDocument.cf) {
      mismatchReasons.add('target_cf_mismatch');
    }
    if (!_hasAcceptedIdentityAnchor(targetRead.rawData)) {
      mismatchReasons.add('target_identity_absent');
    }
    if (!_hasNonNullTimestamp(targetRead.rawData['createdAt'])) {
      mismatchReasons.add('target_created_at_missing');
    }
    if (!_deepEquivalent(expectedTargetPayload, targetRead.rawData)) {
      mismatchReasons.add('target_payload_mismatch');
    }
    if (_readString(cfLockRead.rawData['cf']) != writtenDocument.cf) {
      mismatchReasons.add('cf_lock_cf_mismatch');
    }
    if (_readString(cfLockRead.rawData['assistitoId']) != writtenDocument.documentId) {
      mismatchReasons.add('cf_lock_assistito_id_mismatch');
    }
    if (_readString(cfLockRead.rawData['assistitoPath']) != expectedTargetDocumentPath) {
      mismatchReasons.add('cf_lock_assistito_path_mismatch');
    }
    if (_readInt(cfLockRead.rawData['lockVersion']) != 1) {
      mismatchReasons.add('cf_lock_version_mismatch');
    }
    if (!_hasNonNullTimestamp(cfLockRead.rawData['createdAt'])) {
      mismatchReasons.add('cf_lock_created_at_missing');
    }

    return RealAssistitiPostCopyVerificationItem(
      cf: writtenDocument.cf,
      documentId: writtenDocument.documentId,
      documentPath: expectedTargetDocumentPath,
      legacyBundle: legacyBundle,
      dryRunPreviewItem: previewItem,
      writtenDocument: writtenDocument,
      targetRead: targetRead,
      cfLockRead: cfLockRead,
      expectedTargetPayload: expectedTargetPayload,
      mismatchReasons: List<String>.unmodifiable(mismatchReasons),
    );
  }

  static bool _writtenPayloadMatchesPreview({
    required RealAssistitiDryRunPreviewItem previewItem,
    required RealAssistitiTargetCopyWrittenDocument writtenDocument,
  }) {
    final Map<String, dynamic> expected = <String, dynamic>{
      'assistitoId': writtenDocument.documentId,
      ...previewItem.targetPreviewPayloadWithoutAssistitoId,
    };
    return _deepEquivalent(expected, writtenDocument.targetPayload);
  }

  static void _assertCopyResultPaths({
    required RealAssistitiTargetCopyResult copyResult,
    required String expectedCollectionPath,
    required String expectedCfLocksCollectionPath,
  }) {
    if (copyResult.collectionPath != expectedCollectionPath) {
      throw RealAssistitiPostCopyVerificationRejectedException(
        code: 'copy_result_collection_path_mismatch',
        message: 'Path assistiti del copyResult non coerente con tenantId ${copyResult.tenantId}.',
      );
    }
    if (copyResult.cfLocksCollectionPath != expectedCfLocksCollectionPath) {
      throw RealAssistitiPostCopyVerificationRejectedException(
        code: 'copy_result_cf_locks_path_mismatch',
        message: 'Path lock CF del copyResult non coerente con tenantId ${copyResult.tenantId}.',
      );
    }
  }

  static List<String> _normalizeAndValidateWrittenFiscalCodes(
    RealAssistitiTargetCopyResult copyResult,
  ) {
    final List<String> fiscalCodes = <String>[];
    if (copyResult.writtenDocuments.isEmpty) {
      throw const RealAssistitiPostCopyVerificationRejectedException(
        code: 'copy_result_empty',
        message: 'copyResult vuoto: verifica post-copia non eseguibile.',
      );
    }
    if (copyResult.writtenDocuments.length > maxDocumentsPerRun) {
      throw const RealAssistitiPostCopyVerificationRejectedException(
        code: 'copy_result_exceeds_hard_cap',
        message: 'copyResult oltre limite hard: verifica post-copia bloccata.',
      );
    }
    for (final RealAssistitiTargetCopyWrittenDocument document
        in copyResult.writtenDocuments) {
      fiscalCodes.add(document.cf);
      if (document.documentId.trim().isEmpty) {
        throw RealAssistitiPostCopyVerificationRejectedException(
          code: 'copy_result_document_id_empty',
          message: 'documentId target vuoto per CF ${document.cf}.',
        );
      }
      if (document.documentId == document.cf) {
        throw RealAssistitiPostCopyVerificationRejectedException(
          code: 'copy_result_document_id_not_opaque',
          message: 'documentId target non opaco per CF ${document.cf}.',
        );
      }
      if (document.cfLockDocumentId != document.cf) {
        throw RealAssistitiPostCopyVerificationRejectedException(
          code: 'copy_result_cf_lock_id_mismatch',
          message: 'Lock CF non coerente per CF ${document.cf}.',
        );
      }
    }

    try {
      return ManualFiscalCodeInputValidator.normalizeAndValidate(
        fiscalCodes: fiscalCodes,
        maxFiscalCodes: maxDocumentsPerRun,
      );
    } on ManualFiscalCodeInputRejectedException catch (error) {
      throw RealAssistitiPostCopyVerificationRejectedException(
        code: error.code,
        message: error.message,
      );
    }
  }

  static String _normalizeTenantId(String value) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw const RealAssistitiPostCopyVerificationRejectedException(
        code: 'tenant_id_empty',
        message: 'tenantId obbligatorio per verifica post-copia assistiti target.',
      );
    }
    if (normalized.contains('/')) {
      throw const RealAssistitiPostCopyVerificationRejectedException(
        code: 'tenant_id_not_canonical',
        message: 'tenantId non canonico: slash non ammesso.',
      );
    }
    return normalized;
  }

  static bool _deepEquivalent(Object? left, Object? right) {
    final DateTime? leftDate = _readDate(left);
    final DateTime? rightDate = _readDate(right);
    if (leftDate != null || rightDate != null) {
      if (leftDate == null || rightDate == null) {
        return false;
      }
      return leftDate.toUtc().millisecondsSinceEpoch == rightDate.toUtc().millisecondsSinceEpoch;
    }

    if (left is Map && right is Map) {
      if (left.length != right.length) {
        return false;
      }
      for (final Object? key in left.keys) {
        if (!right.containsKey(key)) {
          return false;
        }
        if (!_deepEquivalent(left[key], right[key])) {
          return false;
        }
      }
      return true;
    }

    if (left is Iterable && right is Iterable && left is! String && right is! String) {
      final List<Object?> leftItems = left.toList(growable: false);
      final List<Object?> rightItems = right.toList(growable: false);
      if (leftItems.length != rightItems.length) {
        return false;
      }
      for (int index = 0; index < leftItems.length; index++) {
        if (!_deepEquivalent(leftItems[index], rightItems[index])) {
          return false;
        }
      }
      return true;
    }

    return left == right;
  }

  static bool _hasAcceptedIdentityAnchor(Map<String, dynamic> payload) {
    return _readString(payload['cf']).isNotEmpty ||
        _readString(payload['nome']).isNotEmpty ||
        _readString(payload['cognome']).isNotEmpty ||
        _readString(payload['fullName']).isNotEmpty;
  }

  static bool _hasNonNullTimestamp(Object? value) {
    return _readDate(value) != null;
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

  static String _readString(Object? value) {
    return value?.toString().trim() ?? '';
  }

  static int _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
