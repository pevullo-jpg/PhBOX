import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/patient_identity_utils.dart';
import '../../core/utils/patient_input_normalizer.dart';
import '../datasources/firestore_datasource.dart';
import '../datasources/firestore_firebase_datasource.dart';
import '../models/patient.dart';
import 'identity_resolution_requests_repository.dart';

class PatientsRepository {
  final FirestoreDatasource datasource;

  const PatientsRepository({required this.datasource});

  Future<void> createManualPatient(Patient patient) async {
    final String normalizedDocumentId =
        PatientInputNormalizer.normalizeFiscalCode(patient.fiscalCode);
    final Patient normalizedPatient = patient.copyWith(
      fiscalCode: normalizedDocumentId,
      fullName: PatientInputNormalizer.normalizeFullName(patient.fullName),
      alias: _normalizeAlias(patient.alias),
    );
    final Map<String, dynamic>? existing = await datasource.getDocument(
      collectionPath: AppCollections.patients,
      documentId: normalizedDocumentId,
    );
    if (existing != null) {
      final String? normalizedAlias = _normalizeAlias(normalizedPatient.alias);
      if (normalizedAlias != null) {
        await datasource.patchDocument(
          collectionPath: AppCollections.patients,
          documentId: normalizedDocumentId,
          data: <String, dynamic>{
            'alias': normalizedAlias,
            'updatedAt': DateTime.now().toIso8601String(),
          },
        );
      }
      return;
    }
    await datasource.setDocument(
      collectionPath: AppCollections.patients,
      documentId: normalizedDocumentId,
      data: normalizedPatient.toManualCreateMap(),
    );
  }

  Future<void> patchPatientIdentity({
    required String documentId,
    required String fullName,
    required String storedFiscalCode,
    String? alias,
  }) {
    return datasource.patchDocument(
      collectionPath: AppCollections.patients,
      documentId: documentId,
      data: <String, dynamic>{
        'fullName': PatientInputNormalizer.normalizeFullName(fullName),
        'fiscalCode': PatientInputNormalizer.normalizeFiscalCode(storedFiscalCode),
        'alias': _normalizeAlias(alias),
        'updatedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<PatientProfileUpdateResult> updatePatientProfile({
    required String currentDocumentId,
    required String name,
    required String surname,
    required String fiscalCodeInput,
    String? alias,
  }) async {
    final String normalizedCurrentDocumentId =
        PatientInputNormalizer.normalizeFiscalCode(currentDocumentId);
    final String normalizedName = PatientInputNormalizer.normalizeNamePart(name);
    final String normalizedSurname =
        PatientInputNormalizer.normalizeNamePart(surname);
    final String fullName = PatientInputNormalizer.buildFullName(
      name: normalizedName,
      surname: normalizedSurname,
    );
    if (fullName.isEmpty) {
      throw const PatientProfileUpdateException(
        'Nome e cognome non possono essere entrambi vuoti.',
      );
    }

    final String normalizedFiscalCode =
        PatientInputNormalizer.normalizeFiscalCode(fiscalCodeInput);
    final String? normalizedAlias = _normalizeAlias(alias);
    final bool isTemporaryKey =
        isTemporaryPatientKey(normalizedCurrentDocumentId);

    if (isTemporaryKey && normalizedFiscalCode.isNotEmpty) {
      if (isTemporaryPatientKey(normalizedFiscalCode)) {
        throw const PatientProfileUpdateException(
          'Il codice fiscale corretto deve essere reale, non TMP.',
        );
      }
      final String requestId = await IdentityResolutionRequestsRepository(
        datasource: datasource,
      ).createUserConfirmedRequest(
        action: IdentityResolutionRequestAction.chooseCorrectFiscalCode,
        sourceFiscalCode: normalizedCurrentDocumentId,
        targetFiscalCode: normalizedFiscalCode,
        sourcePatientId: normalizedCurrentDocumentId,
        selectedFiscalCode: normalizedFiscalCode,
        normalizedName: fullName,
        candidateFiscalCodes: <String>[normalizedFiscalCode],
        reason: 'frontend_contextual_tmp_cf_user_confirmed',
      );
      await _applyInPlacePatientProfileUpdate(
        documentId: normalizedCurrentDocumentId,
        storedFiscalCode: normalizedCurrentDocumentId,
        fullName: fullName,
        alias: normalizedAlias,
      );
      return PatientProfileUpdateResult(
        effectiveDocumentId: normalizedCurrentDocumentId,
        fiscalCode: normalizedCurrentDocumentId,
        fullName: fullName,
        migratedFromTemporaryKey: false,
        identityResolutionRequestId: requestId,
      );
    }

    if (!isTemporaryKey) {
      if (normalizedFiscalCode.isEmpty) {
        throw const PatientProfileUpdateException(
          'Il codice fiscale non può essere svuotato da questa schermata.',
        );
      }
      if (normalizedFiscalCode != normalizedCurrentDocumentId) {
        throw const PatientProfileUpdateException(
          'Il codice fiscale coincide con la chiave del paziente e non può essere modificato da qui.',
        );
      }
    }

    await _applyInPlacePatientProfileUpdate(
      documentId: normalizedCurrentDocumentId,
      storedFiscalCode: normalizedCurrentDocumentId,
      fullName: fullName,
      alias: normalizedAlias,
    );

    return PatientProfileUpdateResult(
      effectiveDocumentId: normalizedCurrentDocumentId,
      fiscalCode: normalizedCurrentDocumentId,
      fullName: fullName,
      migratedFromTemporaryKey: false,
    );
  }

  Future<PatientProfileUpdateResult> migrateTemporaryPatientToFiscalCode({
    required String temporaryDocumentId,
    required String name,
    required String surname,
    required String fiscalCode,
    String? alias,
  }) async {
    throw const PatientProfileUpdateException(
      'Migrazione frontend TMP→CF disabilitata: le correzioni identità devono essere '
      'utente-confermate e backend-owned.',
    );
  }

  Future<void> _applyInPlacePatientProfileUpdate({
    required String documentId,
    required String storedFiscalCode,
    required String fullName,
    required String? alias,
  }) async {
    final Map<String, dynamic>? currentPatientMap = await datasource.getDocument(
      collectionPath: AppCollections.patients,
      documentId: documentId,
    );
    if (currentPatientMap == null) {
      throw const PatientProfileUpdateException('Assistito non trovato.');
    }

    final FirebaseFirestore firestore = _firebaseFirestoreOrThrow();
    final WriteBatch batch = firestore.batch();
    final String isoNow = DateTime.now().toIso8601String();
    final DocumentReference<Map<String, dynamic>> patientRef =
        firestore.collection(AppCollections.patients).doc(documentId);

    batch.set(
      patientRef,
      <String, dynamic>{
        'fullName': fullName,
        'fiscalCode': storedFiscalCode,
        'alias': alias,
        'updatedAt': isoNow,
      },
      SetOptions(merge: true),
    );

    await _queueDoctorLinkSync(
      batch: batch,
      oldPatientDocumentId: documentId,
      newPatientDocumentId: documentId,
      fullName: fullName,
      isoNow: isoNow,
      migrationMode: false,
    );

    await batch.commit();
  }

  Future<void> _queueManualSubcollectionMigration({
    required WriteBatch batch,
    required DocumentReference<Map<String, dynamic>> oldPatientRef,
    required DocumentReference<Map<String, dynamic>> newPatientRef,
    required String oldPatientDocumentId,
    required String newPatientDocumentId,
    required String fullName,
    required String isoNow,
  }) async {
    throw UnsupportedError(
      'Migrazione subcollection frontend disabilitata per contratto identity backend-owned.',
    );
  }

  Future<void> _queueDoctorLinkSync({
    required WriteBatch batch,
    required String oldPatientDocumentId,
    required String newPatientDocumentId,
    required String fullName,
    required String isoNow,
    required bool migrationMode,
  }) async {
    final FirebaseFirestore firestore = _firebaseFirestoreOrThrow();
    final String normalizedOld =
        PatientInputNormalizer.normalizeFiscalCode(oldPatientDocumentId);
    final String normalizedNew =
        PatientInputNormalizer.normalizeFiscalCode(newPatientDocumentId);
    final List<Map<String, dynamic>> links = await datasource.getCollectionWhereEqual(
      collectionPath: AppCollections.doctorPatientLinks,
      field: 'patientFiscalCode',
      value: normalizedOld,
    );

    final Set<String> oldLinkIds = links
        .where((Map<String, dynamic> item) {
          return PatientInputNormalizer.normalizeFiscalCode(
                item['patientFiscalCode']?.toString() ?? '',
              ) ==
              normalizedOld;
        })
        .map(_readId)
        .where((String id) => id.isNotEmpty)
        .toSet();

    if (migrationMode) {
      throw UnsupportedError(
        'Migrazione doctor links frontend disabilitata per contratto identity backend-owned.',
      );
    }

    for (final Map<String, dynamic> link in links) {
      final String linkPatientCode = PatientInputNormalizer.normalizeFiscalCode(
        link['patientFiscalCode']?.toString() ?? '',
      );
      if (linkPatientCode != normalizedOld) {
        continue;
      }
      final String currentLinkId = _readId(link);
      if (currentLinkId.isEmpty) {
        continue;
      }
      final String targetLinkId = _resolveDoctorLinkTargetId(
        currentLinkId: currentLinkId,
        oldPatientDocumentId: normalizedOld,
        newPatientDocumentId: normalizedNew,
      );
      final Map<String, dynamic> nextMap = _cleanMapForWrite(link);
      nextMap['patientFiscalCode'] = normalizedNew;
      nextMap['patientFullName'] = fullName;
      nextMap['updatedAt'] = isoNow;
      final DocumentReference<Map<String, dynamic>> targetRef = firestore
          .collection(AppCollections.doctorPatientLinks)
          .doc(targetLinkId);
      batch.set(targetRef, nextMap);
    }
  }

  Future<void> _queueTherapeuticAdviceMigration({
    required WriteBatch batch,
    required String oldPatientDocumentId,
    required String newPatientDocumentId,
    required String isoNow,
  }) async {
    throw UnsupportedError(
      'Migrazione therapeutic advice frontend disabilitata per contratto identity backend-owned.',
    );
  }

  Future<void> _queueFamilyMembershipRewrite({
    required WriteBatch batch,
    required String oldPatientDocumentId,
    required String newPatientDocumentId,
    required String isoNow,
  }) async {
    throw UnsupportedError(
      'Migrazione famiglie frontend disabilitata per contratto identity backend-owned.',
    );
  }

  Future<Patient?> getPatientByFiscalCode(String fiscalCode) async {
    final Map<String, dynamic>? map = await datasource.getDocument(
      collectionPath: AppCollections.patients,
      documentId: fiscalCode,
    );
    if (map == null) return null;
    return Patient.fromMap(map);
  }

  Future<List<Patient>> getAllPatients() async {
    final List<Map<String, dynamic>> maps = await datasource.getCollection(
      collectionPath: AppCollections.patients,
      orderBy: 'fullName',
    );
    return maps.map(Patient.fromMap).toList();
  }

  Future<void> deletePatient(String fiscalCode) {
    throw UnsupportedError(
      'Frontend baseline v1.1.2: deletePatient è disabilitato per evitare '
      'cancellazioni distruttive fuori contratto.',
    );
  }

  FirebaseFirestore _firebaseFirestoreOrThrow() {
    final FirestoreDatasource currentDatasource = datasource;
    if (currentDatasource is FirestoreFirebaseDatasource) {
      return currentDatasource.firestore;
    }
    throw UnsupportedError(
      'Operazione disponibile solo con datasource Firebase reale.',
    );
  }

  String? _normalizeAlias(String? value) {
    final String normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  Map<String, dynamic> _cleanMapForWrite(Map<String, dynamic> source) {
    final Map<String, dynamic> clean = Map<String, dynamic>.from(source);
    clean.remove('id');
    return clean;
  }

  String _readId(Map<String, dynamic> map) {
    final dynamic id = map['id'];
    if (id == null) return '';
    return id.toString().trim();
  }

  String _resolveDoctorLinkTargetId({
    required String currentLinkId,
    required String oldPatientDocumentId,
    required String newPatientDocumentId,
  }) {
    final String normalizedCurrentLinkId = currentLinkId.trim();
    final String manualSuffix = '__manual';
    final String primarySuffix = '__primary';
    if (normalizedCurrentLinkId == '$oldPatientDocumentId$manualSuffix') {
      return '$newPatientDocumentId$manualSuffix';
    }
    if (normalizedCurrentLinkId == '$oldPatientDocumentId$primarySuffix') {
      return '$newPatientDocumentId$primarySuffix';
    }
    return normalizedCurrentLinkId;
  }
}

class PatientProfileUpdateResult {
  final String effectiveDocumentId;
  final String fiscalCode;
  final String fullName;
  final bool migratedFromTemporaryKey;
  final String? identityResolutionRequestId;

  const PatientProfileUpdateResult({
    required this.effectiveDocumentId,
    required this.fiscalCode,
    required this.fullName,
    required this.migratedFromTemporaryKey,
    this.identityResolutionRequestId,
  });
}

class PatientProfileUpdateException implements Exception {
  final String message;

  const PatientProfileUpdateException(this.message);

  @override
  String toString() => message;
}
