import 'package:cloud_firestore/cloud_firestore.dart';

import '../mappers/real_assistiti_target_preview_mapper.dart';
import '../models/target_multitenant_collections.dart';
import '../normalizers/target_assistito_identity_normalizer.dart';
import '../normalizers/target_assistito_nocf_identity_anchor_normalizer.dart';
import '../readers/real_assistiti_nocf_migration_audit_reader.dart';
import '../readers/target_assistiti_identity_duplicate_guard_reader.dart';

class RealAssistitiNoCfTargetCopyRejectedException implements Exception {
  final String code;
  final String message;

  const RealAssistitiNoCfTargetCopyRejectedException({
    required this.code,
    required this.message,
  });

  @override
  String toString() {
    return 'RealAssistitiNoCfTargetCopyRejectedException($code): $message';
  }
}

class RealAssistitiNoCfTargetCopyWrittenDocument {
  final String requestedCode;
  final String identityAnchor;
  final String documentId;
  final String documentPath;
  final String identityLockDocumentPath;
  final String cfLockDocumentPath;
  final List<String> targetPayloadRootKeys;
  final List<String> identityLockPayloadRootKeys;
  final List<String> cfLockPayloadRootKeys;

  const RealAssistitiNoCfTargetCopyWrittenDocument({
    required this.requestedCode,
    required this.identityAnchor,
    required this.documentId,
    required this.documentPath,
    required this.identityLockDocumentPath,
    required this.cfLockDocumentPath,
    required this.targetPayloadRootKeys,
    required this.identityLockPayloadRootKeys,
    required this.cfLockPayloadRootKeys,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'requestedCode': requestedCode,
      'identityAnchor': identityAnchor,
      'documentId': documentId,
      'documentPath': documentPath,
      'identityLockDocumentPath': identityLockDocumentPath,
      'cfLockDocumentPath': cfLockDocumentPath,
      'targetPayloadRootKeys': targetPayloadRootKeys,
      'identityLockPayloadRootKeys': identityLockPayloadRootKeys,
      'cfLockPayloadRootKeys': cfLockPayloadRootKeys,
    };
  }
}

class RealAssistitiNoCfTargetCopyResult {
  final String tenantId;
  final String assistitiCollectionPath;
  final String identityLocksCollectionPath;
  final String cfLocksCollectionPath;
  final List<String> requestedIdentityCodes;
  final List<RealAssistitiNoCfTargetCopyWrittenDocument> writtenDocuments;
  final int maxDocumentsPerRun;
  final int maxFirestoreWritesPerRun;
  final int attemptedAssistitiWrites;
  final int attemptedIdentityLockWrites;
  final int attemptedCfLockWrites;
  final int attemptedWrites;
  final int attemptedLegacyDocumentReads;
  final int attemptedDuplicateGuardLookups;

  const RealAssistitiNoCfTargetCopyResult({
    required this.tenantId,
    required this.assistitiCollectionPath,
    required this.identityLocksCollectionPath,
    required this.cfLocksCollectionPath,
    required this.requestedIdentityCodes,
    required this.writtenDocuments,
    required this.maxDocumentsPerRun,
    required this.maxFirestoreWritesPerRun,
    required this.attemptedAssistitiWrites,
    required this.attemptedIdentityLockWrites,
    required this.attemptedCfLockWrites,
    required this.attemptedWrites,
    required this.attemptedLegacyDocumentReads,
    required this.attemptedDuplicateGuardLookups,
  });

  int get requestedCount => requestedIdentityCodes.length;

  int get writtenCount => writtenDocuments.length;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tenantId': tenantId,
      'assistitiCollectionPath': assistitiCollectionPath,
      'identityLocksCollectionPath': identityLocksCollectionPath,
      'cfLocksCollectionPath': cfLocksCollectionPath,
      'requestedIdentityCodes': requestedIdentityCodes,
      'requestedCount': requestedCount,
      'writtenCount': writtenCount,
      'maxDocumentsPerRun': maxDocumentsPerRun,
      'maxFirestoreWritesPerRun': maxFirestoreWritesPerRun,
      'attemptedAssistitiWrites': attemptedAssistitiWrites,
      'attemptedIdentityLockWrites': attemptedIdentityLockWrites,
      'attemptedCfLockWrites': attemptedCfLockWrites,
      'attemptedWrites': attemptedWrites,
      'attemptedLegacyDocumentReads': attemptedLegacyDocumentReads,
      'attemptedDuplicateGuardLookups': attemptedDuplicateGuardLookups,
      'writtenDocuments': writtenDocuments
          .map((RealAssistitiNoCfTargetCopyWrittenDocument document) => document.toMap())
          .toList(growable: false),
    };
  }
}

class _NoCfLegacyBundle {
  final String requestedCode;
  final LegacySourceSnapshot patient;
  final LegacySourceSnapshot dashboardIndex;
  final LegacySourceSnapshot therapeuticAdvice;
  final LegacySourceSnapshot doctorManual;
  final LegacySourceSnapshot doctorPrimary;

  const _NoCfLegacyBundle({
    required this.requestedCode,
    required this.patient,
    required this.dashboardIndex,
    required this.therapeuticAdvice,
    required this.doctorManual,
    required this.doctorPrimary,
  });

  bool get hasAnyLegacySource =>
      patient.exists ||
      dashboardIndex.exists ||
      therapeuticAdvice.exists ||
      doctorManual.exists ||
      doctorPrimary.exists;

  List<Map<String, dynamic>> get sourceMaps {
    return <Map<String, dynamic>>[
      patient.rawData,
      dashboardIndex.rawData,
      therapeuticAdvice.rawData,
      doctorManual.rawData,
      doctorPrimary.rawData,
    ];
  }
}

class LegacySourceSnapshot {
  final String collectionId;
  final String documentId;
  final bool exists;
  final Map<String, dynamic> rawData;

  const LegacySourceSnapshot({
    required this.collectionId,
    required this.documentId,
    required this.exists,
    required this.rawData,
  });
}

class _PreparedNoCfTargetCopyWrite {
  final String requestedCode;
  final String identityAnchor;
  final DocumentReference<Map<String, dynamic>> assistitoReference;
  final DocumentReference<Map<String, dynamic>> identityLockReference;
  final DocumentReference<Map<String, dynamic>> cfLockReference;
  final Map<String, dynamic> targetPayload;
  final Map<String, dynamic> identityLockPayload;
  final Map<String, dynamic> cfLockPayload;
  final RealAssistitiNoCfTargetCopyWrittenDocument writtenDocument;

  const _PreparedNoCfTargetCopyWrite({
    required this.requestedCode,
    required this.identityAnchor,
    required this.assistitoReference,
    required this.identityLockReference,
    required this.cfLockReference,
    required this.targetPayload,
    required this.identityLockPayload,
    required this.cfLockPayload,
    required this.writtenDocument,
  });
}

class RealAssistitiNoCfTargetCopyWriter {
  static const int maxDocumentsPerRun = 5;
  static const int writesPerDocument = 3;
  static const int legacyReadsPerIdentityCode = 5;
  static const int maxFirestoreWritesPerRun = maxDocumentsPerRun * writesPerDocument;
  static const String manualConfirmationTokenPrefix = 'COPIA_NOCF_ASSISTITI_TARGET';
  static const String identityLocksCollectionId = 'assistiti_identity_locks';
  static const String cfLocksCollectionId = 'assistiti_cf_locks';

  static const String identityResolutionStatusResolvedAuto = 'resolved_auto';
  static const String identityResolutionStatusPendingManual = 'pending_manual';
  static const String identityResolutionSourceNoCfCopyWriter = 'real_assistiti_nocf_target_copy_writer';
  static const String nameSplitConfidenceExplicitNoCfFields = 'explicit_fields_nocf';
  static const String nameSplitConfidenceNoCfCode = 'derived_from_nocf_code';
  static const String nameSplitConfidencePendingManualNoCf = 'pending_manual_nocf_identity_resolution';

  static const String patientsCollection = 'patients';
  static const String dashboardIndexCollection = 'patient_dashboard_index';
  static const String therapeuticAdviceCollection = 'patient_therapeutic_advice';
  static const String doctorPatientLinksCollection = 'doctor_patient_links';
  static const String manualDoctorLinkSuffix = '__manual';
  static const String primaryDoctorLinkSuffix = '__primary';

  static const Set<String> _surnameParticles = <String>{
    'DA',
    'DE',
    'DEL',
    'DELLA',
    'DI',
    'LA',
    'LE',
    'LO',
    'VAN',
    'VON',
  };

  final FirebaseFirestore firestore;

  const RealAssistitiNoCfTargetCopyWriter({
    required this.firestore,
  });

  Future<RealAssistitiNoCfTargetCopyResult> copyByManualIdentityCodes({
    required String tenantId,
    required Iterable<String> identityCodes,
    required String manualConfirmationToken,
  }) async {
    final String normalizedTenantId = _normalizeTenantId(tenantId);
    final List<String> requestedCodes = identityCodes.toList(growable: false);
    _assertRequestSize(requestedCodes);

    final String expectedManualConfirmationToken = buildRequiredManualConfirmationToken(
      tenantId: normalizedTenantId,
      identityCodes: requestedCodes,
    );
    if (manualConfirmationToken.trim() != expectedManualConfirmationToken) {
      throw const RealAssistitiNoCfTargetCopyRejectedException(
        code: 'manual_confirmation_token_invalid',
        message: 'Token manuale non valido per copia NOCF assistiti target.',
      );
    }

    final TargetAssistitiIdentityDuplicateGuardReader duplicateGuard =
        TargetAssistitiIdentityDuplicateGuardReader(firestore: firestore);
    final TargetAssistitiIdentityDuplicateGuardResult duplicateGuardResult =
        await duplicateGuard.assertNoTargetIdentityDuplicates(
      tenantId: normalizedTenantId,
      identityCodes: requestedCodes,
    );

    _assertDuplicateGuardAllowsNoCfCopy(duplicateGuardResult);

    final String assistitiCollectionPath = TargetMultitenantCollections.tenantCollection(
      tenantId: normalizedTenantId,
      collectionId: TargetMultitenantCollections.assistiti,
    );
    final String identityLocksCollectionPath = TargetMultitenantCollections.tenantCollection(
      tenantId: normalizedTenantId,
      collectionId: identityLocksCollectionId,
    );
    final String cfLocksCollectionPath = TargetMultitenantCollections.tenantCollection(
      tenantId: normalizedTenantId,
      collectionId: cfLocksCollectionId,
    );
    final CollectionReference<Map<String, dynamic>> assistitiCollection =
        firestore.collection(assistitiCollectionPath);
    final CollectionReference<Map<String, dynamic>> identityLocksCollection =
        firestore.collection(identityLocksCollectionPath);
    final CollectionReference<Map<String, dynamic>> cfLocksCollection =
        firestore.collection(cfLocksCollectionPath);

    final List<_NoCfLegacyBundle> legacyBundles = <_NoCfLegacyBundle>[];
    for (final TargetAssistitiIdentityDuplicateGuardCheck check in duplicateGuardResult.checks) {
      legacyBundles.add(await _readOneLegacyNoCfCode(check.requestedCode));
    }

    final List<_PreparedNoCfTargetCopyWrite> preparedWrites = _prepareTargetCopyWrites(
      tenantId: normalizedTenantId,
      assistitiCollection: assistitiCollection,
      identityLocksCollection: identityLocksCollection,
      cfLocksCollection: cfLocksCollection,
      duplicateGuardResult: duplicateGuardResult,
      legacyBundles: legacyBundles,
    );

    final List<RealAssistitiNoCfTargetCopyWrittenDocument> writtenDocuments =
        await firestore.runTransaction<List<RealAssistitiNoCfTargetCopyWrittenDocument>>(
      (Transaction transaction) async {
        for (final _PreparedNoCfTargetCopyWrite preparedWrite in preparedWrites) {
          final DocumentSnapshot<Map<String, dynamic>> identityLockSnapshot =
              await transaction.get(preparedWrite.identityLockReference);
          if (identityLockSnapshot.exists) {
            throw RealAssistitiNoCfTargetCopyRejectedException(
              code: 'target_assistito_identity_lock_exists',
              message:
                  'Lock identity target già presente per ${preparedWrite.identityAnchor}: copia NOCF bloccata.',
            );
          }
          final DocumentSnapshot<Map<String, dynamic>> cfLockSnapshot =
              await transaction.get(preparedWrite.cfLockReference);
          if (cfLockSnapshot.exists) {
            throw RealAssistitiNoCfTargetCopyRejectedException(
              code: 'target_assistito_cf_lock_exists',
              message:
                  'Lock CF compatibile già presente per ${preparedWrite.identityAnchor}: copia NOCF bloccata.',
            );
          }
        }

        final List<RealAssistitiNoCfTargetCopyWrittenDocument> transactionWrittenDocuments =
            <RealAssistitiNoCfTargetCopyWrittenDocument>[];
        for (final _PreparedNoCfTargetCopyWrite preparedWrite in preparedWrites) {
          transaction.set(preparedWrite.identityLockReference, preparedWrite.identityLockPayload);
          transaction.set(preparedWrite.cfLockReference, preparedWrite.cfLockPayload);
          transaction.set(preparedWrite.assistitoReference, preparedWrite.targetPayload);
          transactionWrittenDocuments.add(preparedWrite.writtenDocument);
        }
        return List<RealAssistitiNoCfTargetCopyWrittenDocument>.unmodifiable(
          transactionWrittenDocuments,
        );
      },
    );

    return RealAssistitiNoCfTargetCopyResult(
      tenantId: normalizedTenantId,
      assistitiCollectionPath: assistitiCollectionPath,
      identityLocksCollectionPath: identityLocksCollectionPath,
      cfLocksCollectionPath: cfLocksCollectionPath,
      requestedIdentityCodes: List<String>.unmodifiable(requestedCodes),
      writtenDocuments: writtenDocuments,
      maxDocumentsPerRun: maxDocumentsPerRun,
      maxFirestoreWritesPerRun: maxFirestoreWritesPerRun,
      attemptedAssistitiWrites: writtenDocuments.length,
      attemptedIdentityLockWrites: writtenDocuments.length,
      attemptedCfLockWrites: writtenDocuments.length,
      attemptedWrites: writtenDocuments.length * writesPerDocument,
      attemptedLegacyDocumentReads: requestedCodes.length * legacyReadsPerIdentityCode,
      attemptedDuplicateGuardLookups: duplicateGuardResult.attemptedLookupOperations,
    );
  }

  static String buildRequiredManualConfirmationToken({
    required String tenantId,
    required Iterable<String> identityCodes,
  }) {
    final String normalizedTenantId = _normalizeTenantId(tenantId);
    final List<String> requestedCodes = identityCodes.toList(growable: false);
    _assertRequestSize(requestedCodes);
    final List<String> anchors = _normalizeAndValidateNoCfIdentityAnchors(requestedCodes);
    return '$manualConfirmationTokenPrefix:$normalizedTenantId:${anchors.join(',')}';
  }

  static RealAssistitiResolvedIdentity resolveNoCfIdentityForMigration({
    required String requestedCode,
    required String identityAnchor,
    required Map<String, dynamic> patientData,
    required Map<String, dynamic> dashboardIndexData,
    required Map<String, dynamic> therapeuticAdviceData,
  }) {
    final String safeIdentityAnchor = identityAnchor.trim();
    final String explicitNome = TargetAssistitoIdentityNormalizer.normalizeNamePart(
      _readFirstString(patientData, const <String>['nome', 'firstName', 'givenName']),
    );
    final String explicitCognome = TargetAssistitoIdentityNormalizer.normalizeNamePart(
      _readFirstString(patientData, const <String>['cognome', 'lastName', 'surname', 'familyName']),
    );
    final String rawFullName = _firstAvailableFullName(
      patientData: patientData,
      dashboardIndexData: dashboardIndexData,
      therapeuticAdviceData: therapeuticAdviceData,
    );

    if (explicitNome.isNotEmpty && explicitCognome.isNotEmpty) {
      return RealAssistitiResolvedIdentity(
        cf: safeIdentityAnchor,
        nome: explicitNome,
        cognome: explicitCognome,
        fullName: _joinNameFirstFullName(
          nome: explicitNome,
          cognome: explicitCognome,
          fallbackFullName: rawFullName,
        ),
        nameSplitConfidence: nameSplitConfidenceExplicitNoCfFields,
      );
    }

    if (explicitNome.isNotEmpty || explicitCognome.isNotEmpty) {
      final String normalizedFullName = TargetAssistitoIdentityNormalizer.normalizeFullName(rawFullName);
      return RealAssistitiResolvedIdentity(
        cf: safeIdentityAnchor,
        nome: explicitNome,
        cognome: explicitCognome,
        fullName: normalizedFullName.isNotEmpty
            ? normalizedFullName
            : _joinNameFirstFullName(
                nome: explicitNome,
                cognome: explicitCognome,
                fallbackFullName: rawFullName,
              ),
        nameSplitConfidence: nameSplitConfidencePendingManualNoCf,
      );
    }

    final String normalizedFullName = TargetAssistitoIdentityNormalizer.normalizeFullName(rawFullName);
    if (normalizedFullName.isNotEmpty) {
      return RealAssistitiResolvedIdentity(
        cf: safeIdentityAnchor,
        nome: '',
        cognome: '',
        fullName: normalizedFullName,
        nameSplitConfidence: nameSplitConfidencePendingManualNoCf,
      );
    }

    final RealAssistitiResolvedIdentity? codeIdentity = _resolveIdentityFromNoCfCode(
      requestedCode: requestedCode,
      identityAnchor: safeIdentityAnchor,
    );
    if (codeIdentity != null) {
      return codeIdentity;
    }

    return RealAssistitiResolvedIdentity(
      cf: safeIdentityAnchor,
      nome: '',
      cognome: '',
      fullName: '',
      nameSplitConfidence: nameSplitConfidencePendingManualNoCf,
    );
  }

  static String identityResolutionStatusForIdentity(RealAssistitiResolvedIdentity identity) {
    if (identity.nameSplitConfidence == nameSplitConfidencePendingManualNoCf) {
      return identityResolutionStatusPendingManual;
    }
    return identityResolutionStatusResolvedAuto;
  }

  static Map<String, dynamic> identityResolutionForIdentity({
    required String requestedCode,
    required RealAssistitiResolvedIdentity identity,
  }) {
    final String status = identityResolutionStatusForIdentity(identity);
    final Map<String, dynamic> resolution = <String, dynamic>{
      'status': status,
      'source': identityResolutionSourceNoCfCopyWriter,
      'nameSplitConfidence': identity.nameSplitConfidence,
    };
    if (status == identityResolutionStatusPendingManual) {
      final List<String> tokens = identity.fullName
          .split(' ')
          .map((String item) => item.trim())
          .where((String item) => item.isNotEmpty)
          .toList(growable: false);
      resolution.addAll(<String, dynamic>{
        'reason': 'ambiguous_nocf_name_split',
        'requestedCode': requestedCode.trim(),
        'rawFullName': identity.fullName,
        'tokens': List<String>.unmodifiable(tokens),
        'candidateSplits': _buildCandidateSplits(tokens),
      });
    }
    return Map<String, dynamic>.unmodifiable(resolution);
  }

  Future<_NoCfLegacyBundle> _readOneLegacyNoCfCode(String requestedCode) async {
    final String legacyDocumentId = requestedCode.trim();
    if (legacyDocumentId.isEmpty) {
      throw const RealAssistitiNoCfTargetCopyRejectedException(
        code: 'legacy_nocf_document_id_empty',
        message: 'Codice legacy NOCF vuoto: lettura legacy bloccata.',
      );
    }
    return _NoCfLegacyBundle(
      requestedCode: legacyDocumentId,
      patient: await _readLegacyDocument(
        collectionId: patientsCollection,
        documentId: legacyDocumentId,
      ),
      dashboardIndex: await _readLegacyDocument(
        collectionId: dashboardIndexCollection,
        documentId: legacyDocumentId,
      ),
      therapeuticAdvice: await _readLegacyDocument(
        collectionId: therapeuticAdviceCollection,
        documentId: legacyDocumentId,
      ),
      doctorManual: await _readLegacyDocument(
        collectionId: doctorPatientLinksCollection,
        documentId: '$legacyDocumentId$manualDoctorLinkSuffix',
      ),
      doctorPrimary: await _readLegacyDocument(
        collectionId: doctorPatientLinksCollection,
        documentId: '$legacyDocumentId$primaryDoctorLinkSuffix',
      ),
    );
  }

  Future<LegacySourceSnapshot> _readLegacyDocument({
    required String collectionId,
    required String documentId,
  }) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await firestore
        .collection(collectionId)
        .doc(documentId)
        .get(const GetOptions(source: Source.serverAndCache));

    return LegacySourceSnapshot(
      collectionId: collectionId,
      documentId: documentId,
      exists: snapshot.exists,
      rawData: Map<String, dynamic>.unmodifiable(snapshot.data() ?? <String, dynamic>{}),
    );
  }

  static List<_PreparedNoCfTargetCopyWrite> _prepareTargetCopyWrites({
    required String tenantId,
    required CollectionReference<Map<String, dynamic>> assistitiCollection,
    required CollectionReference<Map<String, dynamic>> identityLocksCollection,
    required CollectionReference<Map<String, dynamic>> cfLocksCollection,
    required TargetAssistitiIdentityDuplicateGuardResult duplicateGuardResult,
    required List<_NoCfLegacyBundle> legacyBundles,
  }) {
    final Map<String, _NoCfLegacyBundle> legacyByRequestedCode = <String, _NoCfLegacyBundle>{
      for (final _NoCfLegacyBundle bundle in legacyBundles) bundle.requestedCode: bundle,
    };
    final List<_PreparedNoCfTargetCopyWrite> preparedWrites = <_PreparedNoCfTargetCopyWrite>[];

    for (final TargetAssistitiIdentityDuplicateGuardCheck check in duplicateGuardResult.checks) {
      final _NoCfLegacyBundle? legacyBundle = legacyByRequestedCode[check.requestedCode];
      if (legacyBundle == null) {
        throw RealAssistitiNoCfTargetCopyRejectedException(
          code: 'legacy_nocf_bundle_missing',
          message: 'Bundle legacy NOCF assente per ${check.requestedCode}.',
        );
      }
      if (!legacyBundle.hasAnyLegacySource) {
        throw RealAssistitiNoCfTargetCopyRejectedException(
          code: 'legacy_nocf_source_missing',
          message: 'Nessuna sorgente legacy trovata per NOCF ${check.requestedCode}.',
        );
      }

      final DocumentReference<Map<String, dynamic>> assistitoReference = assistitiCollection.doc();
      final DocumentReference<Map<String, dynamic>> identityLockReference =
          identityLocksCollection.doc(check.identityAnchor);
      final DocumentReference<Map<String, dynamic>> cfLockReference =
          cfLocksCollection.doc(check.identityAnchor);
      final String documentPath = TargetMultitenantCollections.assistitoDocument(
        tenantId: tenantId,
        assistitoId: assistitoReference.id,
      );
      final String identityLockDocumentPath = TargetMultitenantCollections.tenantDocument(
        tenantId: tenantId,
        collectionId: identityLocksCollectionId,
        documentId: check.identityAnchor,
      );
      final String cfLockDocumentPath = TargetMultitenantCollections.tenantDocument(
        tenantId: tenantId,
        collectionId: cfLocksCollectionId,
        documentId: check.identityAnchor,
      );

      final Map<String, dynamic> targetPayload = _buildTargetPayloadForCopy(
        check: check,
        legacyBundle: legacyBundle,
        assistitoId: assistitoReference.id,
      );
      final Map<String, dynamic> identityLockPayload = _buildIdentityLockPayload(
        check: check,
        assistitoId: assistitoReference.id,
        assistitoPath: documentPath,
      );
      final Map<String, dynamic> cfLockPayload = _buildCfLockPayload(
        check: check,
        assistitoId: assistitoReference.id,
        assistitoPath: documentPath,
      );

      preparedWrites.add(_PreparedNoCfTargetCopyWrite(
        requestedCode: check.requestedCode,
        identityAnchor: check.identityAnchor,
        assistitoReference: assistitoReference,
        identityLockReference: identityLockReference,
        cfLockReference: cfLockReference,
        targetPayload: targetPayload,
        identityLockPayload: identityLockPayload,
        cfLockPayload: cfLockPayload,
        writtenDocument: RealAssistitiNoCfTargetCopyWrittenDocument(
          requestedCode: check.requestedCode,
          identityAnchor: check.identityAnchor,
          documentId: assistitoReference.id,
          documentPath: documentPath,
          identityLockDocumentPath: identityLockDocumentPath,
          cfLockDocumentPath: cfLockDocumentPath,
          targetPayloadRootKeys: _sortedRootKeys(targetPayload),
          identityLockPayloadRootKeys: _sortedRootKeys(identityLockPayload),
          cfLockPayloadRootKeys: _sortedRootKeys(cfLockPayload),
        ),
      ));
    }

    return List<_PreparedNoCfTargetCopyWrite>.unmodifiable(preparedWrites);
  }

  static Map<String, dynamic> _buildTargetPayloadForCopy({
    required TargetAssistitiIdentityDuplicateGuardCheck check,
    required _NoCfLegacyBundle legacyBundle,
    required String assistitoId,
  }) {
    final String safeAssistitoId = assistitoId.trim();
    if (safeAssistitoId.isEmpty || safeAssistitoId == check.identityAnchor) {
      throw RealAssistitiNoCfTargetCopyRejectedException(
        code: 'generated_assistito_id_invalid',
        message: 'Auto-id Firestore non valido per NOCF ${check.identityAnchor}.',
      );
    }

    final DateTime fallbackTimestamp = DateTime.now().toUtc();
    final RealAssistitiResolvedIdentity identity = resolveNoCfIdentityForMigration(
      requestedCode: check.requestedCode,
      identityAnchor: check.identityAnchor,
      patientData: legacyBundle.patient.rawData,
      dashboardIndexData: legacyBundle.dashboardIndex.rawData,
      therapeuticAdviceData: legacyBundle.therapeuticAdvice.rawData,
    );
    final Map<String, dynamic> identityResolution = identityResolutionForIdentity(
      requestedCode: check.requestedCode,
      identity: identity,
    );

    final Map<String, dynamic> payload = <String, dynamic>{
      'assistitoId': safeAssistitoId,
      'cf': check.identityAnchor,
      'identityType': TargetAssistitoNoCfIdentityAnchorNormalizer.identityTypeNoCf,
      'identityAnchor': check.identityAnchor,
      if (check.legacyNoCfCode.isNotEmpty) 'legacyNoCfCode': check.legacyNoCfCode,
      'generatedNoCf': false,
      'nome': identity.nome,
      'cognome': identity.cognome,
      'fullName': identity.fullName,
      'nameSplitConfidence': identity.nameSplitConfidence,
      'identityResolutionStatus': identityResolution['status'],
      'identityResolution': identityResolution,
      'searchPrefixes': identity.fullName.trim().isEmpty
          ? const <String>[]
          : RealAssistitiTargetPreviewMapper.buildSearchPrefixes(identity.fullName),
      'dashboard': RealAssistitiTargetPreviewMapper.buildDashboardSnapshot(
        dashboardIndexData: legacyBundle.dashboardIndex.rawData,
        identity: identity,
      ),
      'doctor': RealAssistitiTargetPreviewMapper.buildDoctorPreview(
        doctorManualData: legacyBundle.doctorManual.rawData,
        doctorPrimaryData: legacyBundle.doctorPrimary.rawData,
        identity: identity,
      ),
      'therapeuticAdvice': RealAssistitiTargetPreviewMapper.buildTherapeuticAdvicePreview(
        therapeuticAdviceData: legacyBundle.therapeuticAdvice.rawData,
        identity: identity,
      ),
      'createdAt': RealAssistitiTargetPreviewMapper.resolveTimestamp(
        sources: legacyBundle.sourceMaps,
        candidateKeys: const <String>['createdAt', 'creationTime', 'insertedAt'],
        fallback: fallbackTimestamp,
      ),
      'updatedAt': RealAssistitiTargetPreviewMapper.resolveTimestamp(
        sources: legacyBundle.sourceMaps,
        candidateKeys: const <String>['updatedAt', 'lastUpdatedAt', 'modifiedAt'],
        fallback: fallbackTimestamp,
      ),
    };

    _assertTargetPayload(check: check, payload: payload);
    return Map<String, dynamic>.unmodifiable(payload);
  }

  static Map<String, dynamic> _buildIdentityLockPayload({
    required TargetAssistitiIdentityDuplicateGuardCheck check,
    required String assistitoId,
    required String assistitoPath,
  }) {
    return Map<String, dynamic>.unmodifiable(<String, dynamic>{
      'identityAnchor': check.identityAnchor,
      'cf': check.identityAnchor,
      'identityType': TargetAssistitoNoCfIdentityAnchorNormalizer.identityTypeNoCf,
      'assistitoId': assistitoId,
      'assistitoPath': assistitoPath,
      if (check.legacyNoCfCode.isNotEmpty) 'legacyNoCfCode': check.legacyNoCfCode,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': 'real_assistiti_nocf_target_copy_writer',
      'lockVersion': 1,
    });
  }

  static Map<String, dynamic> _buildCfLockPayload({
    required TargetAssistitiIdentityDuplicateGuardCheck check,
    required String assistitoId,
    required String assistitoPath,
  }) {
    return Map<String, dynamic>.unmodifiable(<String, dynamic>{
      'cf': check.identityAnchor,
      'identityAnchor': check.identityAnchor,
      'identityType': TargetAssistitoNoCfIdentityAnchorNormalizer.identityTypeNoCf,
      'assistitoId': assistitoId,
      'assistitoPath': assistitoPath,
      if (check.legacyNoCfCode.isNotEmpty) 'legacyNoCfCode': check.legacyNoCfCode,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': 'real_assistiti_nocf_target_copy_writer',
      'lockVersion': 1,
    });
  }

  static void _assertTargetPayload({
    required TargetAssistitiIdentityDuplicateGuardCheck check,
    required Map<String, dynamic> payload,
  }) {
    if (_readString(payload['cf']) != check.identityAnchor) {
      throw RealAssistitiNoCfTargetCopyRejectedException(
        code: 'target_payload_cf_mismatch',
        message: 'Payload target NOCF con cf non coerente per ${check.identityAnchor}.',
      );
    }
    if (_readString(payload['identityAnchor']) != check.identityAnchor) {
      throw RealAssistitiNoCfTargetCopyRejectedException(
        code: 'target_payload_identity_anchor_mismatch',
        message: 'Payload target NOCF con identityAnchor non coerente per ${check.identityAnchor}.',
      );
    }
    if (_readString(payload['identityType']) !=
        TargetAssistitoNoCfIdentityAnchorNormalizer.identityTypeNoCf) {
      throw RealAssistitiNoCfTargetCopyRejectedException(
        code: 'target_payload_identity_type_mismatch',
        message: 'Payload target NOCF con identityType non coerente per ${check.identityAnchor}.',
      );
    }
    if (!TargetAssistitoNoCfIdentityAnchorNormalizer.isCanonicalNoCf(check.identityAnchor)) {
      throw RealAssistitiNoCfTargetCopyRejectedException(
        code: 'target_payload_nocf_not_canonical',
        message: 'identityAnchor NOCF non canonico per ${check.requestedCode}.',
      );
    }
    if (_readString(payload['identityResolutionStatus']).isEmpty) {
      throw RealAssistitiNoCfTargetCopyRejectedException(
        code: 'target_payload_identity_resolution_status_missing',
        message: 'Payload target NOCF senza stato risoluzione identità per ${check.identityAnchor}.',
      );
    }
    if (!_hasNonNullTimestamp(payload['createdAt']) || !_hasNonNullTimestamp(payload['updatedAt'])) {
      throw RealAssistitiNoCfTargetCopyRejectedException(
        code: 'target_payload_timestamp_missing',
        message: 'Payload target NOCF senza createdAt/updatedAt validi per ${check.identityAnchor}.',
      );
    }
  }

  static RealAssistitiResolvedIdentity? _resolveIdentityFromNoCfCode({
    required String requestedCode,
    required String identityAnchor,
  }) {
    if (_isTechnicalNoCfHashCode(requestedCode)) {
      return null;
    }

    final List<String> parts = _humanTokensFromNoCfCode(requestedCode);
    if (parts.length < 2) {
      return null;
    }
    final int surnameStart = _surnameStartIndex(parts);
    if (surnameStart <= 0 || surnameStart >= parts.length) {
      return null;
    }
    final String nome = parts.take(surnameStart).map(_titleCaseToken).join(' ').trim();
    final String cognome = parts.skip(surnameStart).map(_titleCaseToken).join(' ').trim();
    if (nome.isEmpty || cognome.isEmpty) {
      return null;
    }
    return RealAssistitiResolvedIdentity(
      cf: identityAnchor,
      nome: TargetAssistitoIdentityNormalizer.normalizeNamePart(nome),
      cognome: TargetAssistitoIdentityNormalizer.normalizeNamePart(cognome),
      fullName: _joinNameFirstFullName(nome: nome, cognome: cognome, fallbackFullName: ''),
      nameSplitConfidence: nameSplitConfidenceNoCfCode,
    );
  }

  static bool _isTechnicalNoCfHashCode(String requestedCode) {
    final String normalized = requestedCode.trim().toUpperCase();
    return TargetAssistitoNoCfIdentityAnchorNormalizer.isCanonicalNoCf(normalized) ||
        RegExp(r'^NOCF_[0-9A-F]{8,}$').hasMatch(normalized);
  }

  static List<String> _humanTokensFromNoCfCode(String requestedCode) {
    final String normalized = requestedCode.trim().replaceAll(RegExp(r'[^A-Za-zÀ-ÖØ-öø-ÿ]+'), ' ');
    final List<String> tokens = normalized
        .split(' ')
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) {
      return const <String>[];
    }
    final List<String> filtered = <String>[];
    for (final String token in tokens) {
      final String upper = token.toUpperCase();
      if (upper == 'TMP' || upper == 'NOCF' || upper == 'MANUALE' || upper == 'MANUAL') {
        continue;
      }
      filtered.add(upper);
    }
    return List<String>.unmodifiable(filtered);
  }

  static int _surnameStartIndex(List<String> parts) {
    if (parts.length < 2) {
      return -1;
    }
    final int lastIndex = parts.length - 1;
    final String previous = parts[lastIndex - 1].toUpperCase();
    if (parts.length >= 3 && _surnameParticles.contains(previous)) {
      return lastIndex - 1;
    }
    return lastIndex;
  }

  static List<Map<String, String>> _buildCandidateSplits(List<String> tokens) {
    if (tokens.length < 2) {
      return const <Map<String, String>>[];
    }
    final String firstAsName = tokens.first;
    final String restAsSurname = tokens.skip(1).join(' ');
    final String lastAsSurname = tokens.last;
    final String restAsName = tokens.take(tokens.length - 1).join(' ');
    return List<Map<String, String>>.unmodifiable(<Map<String, String>>[
      <String, String>{'nome': firstAsName, 'cognome': restAsSurname},
      <String, String>{'nome': restAsName, 'cognome': lastAsSurname},
    ]);
  }

  static String _firstAvailableFullName({
    required Map<String, dynamic> patientData,
    required Map<String, dynamic> dashboardIndexData,
    required Map<String, dynamic> therapeuticAdviceData,
  }) {
    const List<String> fullNameKeys = <String>[
      'fullName',
      'displayName',
      'patientName',
      'assistitoName',
      'name',
    ];
    for (final Map<String, dynamic> source in <Map<String, dynamic>>[
      patientData,
      dashboardIndexData,
      therapeuticAdviceData,
    ]) {
      final String normalized = _normalizeSafeFullNameCandidate(
        _readFirstString(source, fullNameKeys),
      );
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return '';
  }

  static String _normalizeSafeFullNameCandidate(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final String compact = TargetAssistitoIdentityNormalizer.normalizeCf(trimmed);
    if (_isTechnicalNoCfFullNameCandidate(compact)) {
      return '';
    }
    return TargetAssistitoIdentityNormalizer.normalizeFullName(trimmed);
  }

  static bool _isTechnicalNoCfFullNameCandidate(String compactValue) {
    return compactValue.startsWith('NOCF_') ||
        compactValue.startsWith('TMP_') ||
        compactValue.startsWith('MANUAL_') ||
        compactValue.startsWith('MANUALE_');
  }

  static String _joinNameFirstFullName({
    required String nome,
    required String cognome,
    required String fallbackFullName,
  }) {
    final String joined = <String>[nome, cognome]
        .where((String item) => item.trim().isNotEmpty)
        .join(' ')
        .trim();
    if (joined.isNotEmpty) {
      return TargetAssistitoIdentityNormalizer.normalizeFullName(joined);
    }
    return TargetAssistitoIdentityNormalizer.normalizeFullName(fallbackFullName);
  }

  static String _titleCaseToken(String value) {
    final String normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return '';
    }
    return '${normalized.substring(0, 1).toUpperCase()}${normalized.substring(1)}';
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

  static void _assertDuplicateGuardAllowsNoCfCopy(
    TargetAssistitiIdentityDuplicateGuardResult result,
  ) {
    if (result.hasAuditBlockingIssues) {
      throw RealAssistitiNoCfTargetCopyRejectedException(
        code: 'identity_audit_has_blocking_issues',
        message:
            'Audit NOCF contiene blocchi o scarti: ${result.audit.blockedRequestedCodes.join(', ')} ${result.audit.rejectedRequestedCodes.join(', ')}.'
                .trim(),
      );
    }
    if (result.hasDuplicates) {
      throw RealAssistitiNoCfTargetCopyRejectedException(
        code: 'target_assistito_identity_duplicate',
        message:
            'Assistito target già presente per identityAnchor: ${result.duplicateIdentityAnchors.join(', ')}.',
      );
    }
    if (result.checks.isEmpty) {
      throw const RealAssistitiNoCfTargetCopyRejectedException(
        code: 'identity_duplicate_guard_empty',
        message: 'Duplicate guard NOCF senza controlli eseguibili.',
      );
    }
    for (final TargetAssistitiIdentityDuplicateGuardCheck check in result.checks) {
      if (check.identityType != TargetAssistitoNoCfIdentityAnchorNormalizer.identityTypeNoCf) {
        throw RealAssistitiNoCfTargetCopyRejectedException(
          code: 'nocf_copy_contains_real_cf',
          message: 'La copia NOCF non accetta CF reali: ${check.requestedCode}.',
        );
      }
      if (!TargetAssistitoNoCfIdentityAnchorNormalizer.isCanonicalNoCf(check.identityAnchor)) {
        throw RealAssistitiNoCfTargetCopyRejectedException(
          code: 'nocf_identity_anchor_not_canonical',
          message: 'identityAnchor NOCF non canonico: ${check.identityAnchor}.',
        );
      }
    }
  }

  static List<String> _normalizeAndValidateNoCfIdentityAnchors(List<String> requestedCodes) {
    final TargetAssistitiIdentityDuplicateGuardResult syntheticResult =
        TargetAssistitiIdentityDuplicateGuardResult(
      tenantId: 'token',
      assistitiCollectionPath: '',
      identityLocksCollectionPath: '',
      cfLocksCollectionPath: '',
      audit: RealAssistitiNoCfMigrationAuditResult.fromRequestedCodes(requestedCodes),
      checks: const <TargetAssistitiIdentityDuplicateGuardCheck>[],
      maxIdentityCodes: maxDocumentsPerRun,
      attemptedLookupOperations: 0,
    );

    if (syntheticResult.hasAuditBlockingIssues) {
      throw RealAssistitiNoCfTargetCopyRejectedException(
        code: 'identity_audit_has_blocking_issues',
        message:
            'Audit NOCF contiene blocchi o scarti: ${syntheticResult.audit.blockedRequestedCodes.join(', ')} ${syntheticResult.audit.rejectedRequestedCodes.join(', ')}.'
                .trim(),
      );
    }

    final List<String> anchors = <String>[];
    for (final RealAssistitiNoCfMigrationAuditItem item in syntheticResult.audit.items) {
      if (!item.isNoCf) {
        throw RealAssistitiNoCfTargetCopyRejectedException(
          code: 'nocf_copy_contains_real_cf',
          message: 'La copia NOCF non accetta CF reali: ${item.requestedCode}.',
        );
      }
      if (!TargetAssistitoNoCfIdentityAnchorNormalizer.isCanonicalNoCf(item.identityAnchor)) {
        throw RealAssistitiNoCfTargetCopyRejectedException(
          code: 'nocf_identity_anchor_not_canonical',
          message: 'identityAnchor NOCF non canonico: ${item.identityAnchor}.',
        );
      }
      anchors.add(item.identityAnchor);
    }

    return List<String>.unmodifiable(anchors);
  }

  static void _assertRequestSize(List<String> requestedCodes) {
    if (requestedCodes.isEmpty) {
      throw const RealAssistitiNoCfTargetCopyRejectedException(
        code: 'identity_codes_empty',
        message: 'Lista codici identità NOCF vuota.',
      );
    }
    if (requestedCodes.length > maxDocumentsPerRun) {
      throw const RealAssistitiNoCfTargetCopyRejectedException(
        code: 'identity_codes_exceed_hard_cap',
        message: 'Lista codici identità NOCF oltre limite hard di 5.',
      );
    }
  }

  static String _normalizeTenantId(String value) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw const RealAssistitiNoCfTargetCopyRejectedException(
        code: 'tenant_id_empty',
        message: 'tenantId obbligatorio per copia NOCF assistiti target.',
      );
    }
    if (normalized.contains('/')) {
      throw const RealAssistitiNoCfTargetCopyRejectedException(
        code: 'tenant_id_not_canonical',
        message: 'tenantId non canonico: slash non ammesso.',
      );
    }
    return normalized;
  }

  static List<String> _sortedRootKeys(Map<String, dynamic> payload) {
    return List<String>.unmodifiable(payload.keys.toList(growable: false)..sort());
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
