import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/patient_identity_utils.dart';
import '../../core/utils/patient_input_normalizer.dart';
import '../datasources/firestore_datasource.dart';
import '../datasources/firestore_firebase_datasource.dart';
import '../models/patient.dart';

class PatientsRepository {
  final FirestoreDatasource datasource;

  const PatientsRepository({required this.datasource});

  Future<void> createManualPatient(Patient patient) async {
    final String normalizedDocumentId =
        PatientInputNormalizer.normalizeFiscalCode(patient.fiscalCode);
    final Patient normalizedPatient = patient.copyWith(
      fiscalCode: normalizedDocumentId,
      fullName: PatientInputNormalizer.normalizeFullName(patient.fullName),
    );
    final Map<String, dynamic>? existing = await datasource.getDocument(
      collectionPath: AppCollections.patients,
      documentId: normalizedDocumentId,
    );
    if (existing != null) {
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
  }) {
    return datasource.patchDocument(
      collectionPath: AppCollections.patients,
      documentId: documentId,
      data: <String, dynamic>{
        'fullName': PatientInputNormalizer.normalizeFullName(fullName),
        'fiscalCode': PatientInputNormalizer.normalizeFiscalCode(storedFiscalCode),
        'updatedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<PatientProfileUpdateResult> updatePatientProfile({
    required String currentDocumentId,
    required String name,
    required String surname,
    required String fiscalCodeInput,
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
    final bool isTemporaryKey =
        isTemporaryPatientKey(normalizedCurrentDocumentId);

    if (isTemporaryKey && normalizedFiscalCode.isNotEmpty) {
      return migrateTemporaryPatientToFiscalCode(
        temporaryDocumentId: normalizedCurrentDocumentId,
        name: normalizedName,
        surname: normalizedSurname,
        fiscalCode: normalizedFiscalCode,
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
  }) async {
    final String normalizedTemporaryDocumentId =
        PatientInputNormalizer.normalizeFiscalCode(temporaryDocumentId);
    final String normalizedFiscalCode =
        PatientInputNormalizer.normalizeFiscalCode(fiscalCode);
    final String fullName = PatientInputNormalizer.buildFullName(
      name: name,
      surname: surname,
    );

    if (!isTemporaryPatientKey(normalizedTemporaryDocumentId)) {
      throw const PatientProfileUpdateException(
        'La migrazione verso codice fiscale reale è consentita solo per pazienti TMP.',
      );
    }
    if (normalizedFiscalCode.isEmpty) {
      throw const PatientProfileUpdateException(
        'Inserisci un codice fiscale reale per completare il paziente temporaneo.',
      );
    }
    if (fullName.isEmpty) {
      throw const PatientProfileUpdateException(
        'Nome e cognome non possono essere entrambi vuoti.',
      );
    }

    final Map<String, dynamic>? currentPatientMap = await datasource.getDocument(
      collectionPath: AppCollections.patients,
      documentId: normalizedTemporaryDocumentId,
    );
    if (currentPatientMap == null) {
      throw const PatientProfileUpdateException('Assistito temporaneo non trovato.');
    }

    final Map<String, dynamic>? existingTargetPatient = await datasource.getDocument(
      collectionPath: AppCollections.patients,
      documentId: normalizedFiscalCode,
    );
    if (existingTargetPatient != null) {
      throw PatientProfileUpdateException(
        'Esiste già un assistito con codice fiscale $normalizedFiscalCode.',
      );
    }

    final FirebaseFirestore firestore = _firebaseFirestoreOrThrow();
    final WriteBatch batch = firestore.batch();
    final DateTime now = DateTime.now();
    final String isoNow = now.toIso8601String();

    final DocumentReference<Map<String, dynamic>> oldPatientRef = firestore
        .collection(AppCollections.patients)
        .doc(normalizedTemporaryDocumentId);
    final DocumentReference<Map<String, dynamic>> newPatientRef = firestore
        .collection(AppCollections.patients)
        .doc(normalizedFiscalCode);

    final Map<String, dynamic> nextPatientMap =
        _cleanMapForWrite(currentPatientMap);
    nextPatientMap['fiscalCode'] = normalizedFiscalCode;
    nextPatientMap['fullName'] = fullName;
    nextPatientMap['updatedAt'] = isoNow;
    nextPatientMap['createdAt'] =
        nextPatientMap['createdAt'] ?? currentPatientMap['createdAt'] ?? isoNow;
    batch.set(newPatientRef, nextPatientMap);

    await _queueManualSubcollectionMigration(
      batch: batch,
      oldPatientRef: oldPatientRef,
      newPatientRef: newPatientRef,
      oldPatientDocumentId: normalizedTemporaryDocumentId,
      newPatientDocumentId: normalizedFiscalCode,
      fullName: fullName,
      isoNow: isoNow,
    );
    await _queueDoctorLinkSync(
      batch: batch,
      oldPatientDocumentId: normalizedTemporaryDocumentId,
      newPatientDocumentId: normalizedFiscalCode,
      fullName: fullName,
      isoNow: isoNow,
      migrationMode: true,
    );
    await _queueTherapeuticAdviceMigration(
      batch: batch,
      oldPatientDocumentId: normalizedTemporaryDocumentId,
      newPatientDocumentId: normalizedFiscalCode,
      isoNow: isoNow,
    );
    await _queueFamilyMembershipRewrite(
      batch: batch,
      oldPatientDocumentId: normalizedTemporaryDocumentId,
      newPatientDocumentId: normalizedFiscalCode,
      isoNow: isoNow,
    );

    batch.delete(oldPatientRef);
    await batch.commit();

    return PatientProfileUpdateResult(
      effectiveDocumentId: normalizedFiscalCode,
      fiscalCode: normalizedFiscalCode,
      fullName: fullName,
      migratedFromTemporaryKey: true,
    );
  }

  Future<void> _applyInPlacePatientProfileUpdate({
    required String documentId,
    required String storedFiscalCode,
    required String fullName,
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
        'updatedAt': isoNow,
      },
      SetOptions(merge: true),
    );

    await _queueManualSubcollectionNameRewrite(
      batch: batch,
      patientDocumentId: documentId,
      storedFiscalCode: storedFiscalCode,
      fullName: fullName,
      isoNow: isoNow,
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

  Future<void> _queueManualSubcollectionNameRewrite({
    required WriteBatch batch,
    required String patientDocumentId,
    required String storedFiscalCode,
    required String fullName,
    required String isoNow,
  }) async {
    final FirebaseFirestore firestore = _firebaseFirestoreOrThrow();
    final DocumentReference<Map<String, dynamic>> patientRef =
        firestore.collection(AppCollections.patients).doc(patientDocumentId);

    for (final String subcollection in _manualSubcollections) {
      final List<Map<String, dynamic>> items = await datasource.getSubCollection(
        collectionPath: AppCollections.patients,
        documentId: patientDocumentId,
        subcollectionPath: subcollection,
      );
      for (final Map<String, dynamic> item in items) {
        final String itemId = _readId(item);
        if (itemId.isEmpty) continue;
        final Map<String, dynamic> nextMap = _cleanMapForWrite(item);
        nextMap['patientFiscalCode'] = storedFiscalCode;
        nextMap['patientName'] = fullName;
        if (nextMap.containsKey('updatedAt') ||
            subcollection == AppCollections.advances) {
          nextMap['updatedAt'] = isoNow;
        }
        batch.set(patientRef.collection(subcollection).doc(itemId), nextMap);
      }
    }
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
    for (final String subcollection in _manualSubcollections) {
      final List<Map<String, dynamic>> items = await datasource.getSubCollection(
        collectionPath: AppCollections.patients,
        documentId: oldPatientDocumentId,
        subcollectionPath: subcollection,
      );
      for (final Map<String, dynamic> item in items) {
        final String itemId = _readId(item);
        if (itemId.isEmpty) continue;
        final Map<String, dynamic> nextMap = _cleanMapForWrite(item);
        nextMap['patientFiscalCode'] = newPatientDocumentId;
        nextMap['patientName'] = fullName;
        if (nextMap.containsKey('updatedAt') ||
            subcollection == AppCollections.advances) {
          nextMap['updatedAt'] = isoNow;
        }
        batch.set(newPatientRef.collection(subcollection).doc(itemId), nextMap);
        batch.delete(oldPatientRef.collection(subcollection).doc(itemId));
      }
    }
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
    final List<Map<String, dynamic>> links = await datasource.getCollection(
      collectionPath: AppCollections.doctorPatientLinks,
    );
    final String normalizedOld =
        PatientInputNormalizer.normalizeFiscalCode(oldPatientDocumentId);
    final String normalizedNew =
        PatientInputNormalizer.normalizeFiscalCode(newPatientDocumentId);

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
      for (final String targetId in oldLinkIds
          .map((String linkId) => _resolveDoctorLinkTargetId(
                currentLinkId: linkId,
                oldPatientDocumentId: normalizedOld,
                newPatientDocumentId: normalizedNew,
              ))
          .where((String id) => id.isNotEmpty)) {
        if (oldLinkIds.contains(targetId)) {
          continue;
        }
        final Map<String, dynamic>? conflict = await datasource.getDocument(
          collectionPath: AppCollections.doctorPatientLinks,
          documentId: targetId,
        );
        if (conflict != null) {
          throw PatientProfileUpdateException(
            'Esiste già un collegamento medico associato al codice fiscale $normalizedNew.',
          );
        }
      }
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
      if (migrationMode && targetLinkId != currentLinkId) {
        batch.delete(
          firestore.collection(AppCollections.doctorPatientLinks).doc(currentLinkId),
        );
      }
    }
  }

  Future<void> _queueTherapeuticAdviceMigration({
    required WriteBatch batch,
    required String oldPatientDocumentId,
    required String newPatientDocumentId,
    required String isoNow,
  }) async {
    final Map<String, dynamic>? therapeuticAdvice = await datasource.getDocument(
      collectionPath: AppCollections.patientTherapeuticAdvice,
      documentId: oldPatientDocumentId,
    );
    if (therapeuticAdvice == null) {
      return;
    }

    final Map<String, dynamic>? targetAdvice = await datasource.getDocument(
      collectionPath: AppCollections.patientTherapeuticAdvice,
      documentId: newPatientDocumentId,
    );
    if (targetAdvice != null) {
      throw PatientProfileUpdateException(
        'Esistono già note terapeutiche associate al codice fiscale $newPatientDocumentId.',
      );
    }

    final FirebaseFirestore firestore = _firebaseFirestoreOrThrow();
    final DocumentReference<Map<String, dynamic>> oldAdviceRef = firestore
        .collection(AppCollections.patientTherapeuticAdvice)
        .doc(oldPatientDocumentId);
    final DocumentReference<Map<String, dynamic>> newAdviceRef = firestore
        .collection(AppCollections.patientTherapeuticAdvice)
        .doc(newPatientDocumentId);
    final Map<String, dynamic> nextAdvice = _cleanMapForWrite(therapeuticAdvice);
    nextAdvice['patientFiscalCode'] = newPatientDocumentId;
    nextAdvice['updatedAt'] = isoNow;
    batch.set(newAdviceRef, nextAdvice);
    batch.delete(oldAdviceRef);
  }

  Future<void> _queueFamilyMembershipRewrite({
    required WriteBatch batch,
    required String oldPatientDocumentId,
    required String newPatientDocumentId,
    required String isoNow,
  }) async {
    final FirebaseFirestore firestore = _firebaseFirestoreOrThrow();
    final List<Map<String, dynamic>> families = await datasource.getCollection(
      collectionPath: AppCollections.families,
    );
    for (final Map<String, dynamic> family in families) {
      final List<String> members = _readStringList(family['memberFiscalCodes']);
      if (!members.contains(oldPatientDocumentId)) {
        continue;
      }
      final String familyId = _readId(family);
      if (familyId.isEmpty) {
        continue;
      }
      final List<String> nextMembers = members
          .map((String item) => item == oldPatientDocumentId ? newPatientDocumentId : item)
          .where((String item) => item.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      batch.set(
        firestore.collection(AppCollections.families).doc(familyId),
        <String, dynamic>{
          'memberFiscalCodes': nextMembers,
          'updatedAt': isoNow,
        },
        SetOptions(merge: true),
      );
    }
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

  List<String> _readStringList(dynamic value) {
    if (value is List) {
      return value
          .map((dynamic item) =>
              PatientInputNormalizer.normalizeFiscalCode(item.toString()))
          .where((String item) => item.isNotEmpty)
          .toList();
    }
    return const <String>[];
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

  static const List<String> _manualSubcollections = <String>[
    AppCollections.advances,
    AppCollections.bookings,
    AppCollections.debts,
  ];
}

class PatientProfileUpdateResult {
  final String effectiveDocumentId;
  final String fiscalCode;
  final String fullName;
  final bool migratedFromTemporaryKey;

  const PatientProfileUpdateResult({
    required this.effectiveDocumentId,
    required this.fiscalCode,
    required this.fullName,
    required this.migratedFromTemporaryKey,
  });
}

class PatientProfileUpdateException implements Exception {
  final String message;

  const PatientProfileUpdateException(this.message);

  @override
  String toString() => message;
}
