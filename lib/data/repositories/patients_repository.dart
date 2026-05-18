import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/patient_identity_utils.dart';
import '../../core/utils/patient_input_normalizer.dart';
import '../datasources/firestore_datasource.dart';
import '../datasources/firestore_firebase_datasource.dart';
import '../models/patient.dart';
import 'patient_dashboard_index_repository.dart';

class PatientsRepository {
  final FirestoreDatasource datasource;

  const PatientsRepository({required this.datasource});

  static const int _maxFrontendMergeSubcollectionDocs = 25;
  static const int _maxFrontendMergeRootDocs = 25;
  static const int _maxFrontendMergeFamilies = 25;
  static const int _maxFrontendMergeDoctorLinks = 25;

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
    bool preferSubmittedPatientFields = true,
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
      return mergeTemporaryPatientIntoFiscalCode(
        temporaryDocumentId: normalizedCurrentDocumentId,
        targetFiscalCode: normalizedFiscalCode,
        submittedFullName: fullName,
        submittedAlias: normalizedAlias,
        preferSubmittedPatientFields: preferSubmittedPatientFields,
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
    final String normalizedName = PatientInputNormalizer.normalizeNamePart(name);
    final String normalizedSurname = PatientInputNormalizer.normalizeNamePart(surname);
    final String fullName = PatientInputNormalizer.buildFullName(
      name: normalizedName,
      surname: normalizedSurname,
    );
    if (fullName.isEmpty) {
      throw const PatientProfileUpdateException(
        'Nome e cognome non possono essere entrambi vuoti.',
      );
    }
    return mergeTemporaryPatientIntoFiscalCode(
      temporaryDocumentId: temporaryDocumentId,
      targetFiscalCode: fiscalCode,
      submittedFullName: fullName,
      submittedAlias: _normalizeAlias(alias),
      preferSubmittedPatientFields: true,
    );
  }

  Future<PatientProfileUpdateResult> mergeTemporaryPatientIntoFiscalCode({
    required String temporaryDocumentId,
    required String targetFiscalCode,
    required String submittedFullName,
    String? submittedAlias,
    bool preferSubmittedPatientFields = true,
  }) async {
    final String oldId = PatientInputNormalizer.normalizeFiscalCode(temporaryDocumentId);
    final String newId = PatientInputNormalizer.normalizeFiscalCode(targetFiscalCode);
    final String fullName = PatientInputNormalizer.normalizeFullName(submittedFullName);
    final String? normalizedAlias = _normalizeAlias(submittedAlias);
    if (oldId.isEmpty || newId.isEmpty || oldId == newId) {
      throw const PatientProfileUpdateException('Fusione TMP→CF non valida.');
    }
    if (!isTemporaryPatientKey(oldId) || isTemporaryPatientKey(newId)) {
      throw const PatientProfileUpdateException('Fusione TMP→CF consentita solo da TMP a CF reale.');
    }
    if (fullName.isEmpty) {
      throw const PatientProfileUpdateException('Nome e cognome non possono essere entrambi vuoti.');
    }

    final FirebaseFirestore firestore = _firebaseFirestoreOrThrow();
    final DocumentReference<Map<String, dynamic>> oldPatientRef =
        firestore.collection(AppCollections.patients).doc(oldId);
    final DocumentReference<Map<String, dynamic>> newPatientRef =
        firestore.collection(AppCollections.patients).doc(newId);
    final DocumentReference<Map<String, dynamic>> oldIndexRef =
        firestore.collection(AppCollections.patientDashboardIndex).doc(oldId);
    final DocumentReference<Map<String, dynamic>> newIndexRef =
        firestore.collection(AppCollections.patientDashboardIndex).doc(newId);

    final DocumentSnapshot<Map<String, dynamic>> oldPatientSnap = await oldPatientRef.get();
    if (!oldPatientSnap.exists || oldPatientSnap.data() == null ||
        _isHiddenPatientMap(oldPatientSnap.data()!)) {
      throw const PatientProfileUpdateException('Assistito temporaneo non trovato.');
    }

    final DocumentSnapshot<Map<String, dynamic>> targetPatientSnap = await newPatientRef.get();
    if (targetPatientSnap.exists && targetPatientSnap.data() != null &&
        _isHiddenPatientMap(targetPatientSnap.data()!)) {
      throw const PatientProfileUpdateException(
        'Il CF inserito punta a un assistito nascosto/migrato. Fusione bloccata.',
      );
    }
    final DocumentSnapshot<Map<String, dynamic>> oldIndexSnap = await oldIndexRef.get();
    final DocumentSnapshot<Map<String, dynamic>> targetIndexSnap = await newIndexRef.get();

    _assertTemporaryPatientHasNoBackendOwnedSignals(
      patientMap: oldPatientSnap.data()!,
      indexMap: oldIndexSnap.data(),
    );

    final _FrontendMergeLinkedData linked = await _readFrontendMergeLinkedData(
      firestore: firestore,
      temporaryFiscalCode: oldId,
      targetFiscalCode: newId,
    );

    final String isoNow = DateTime.now().toIso8601String();
    final WriteBatch batch = firestore.batch();

    final Map<String, dynamic> mergedPatient = _buildMergedPatientMap(
      oldPatientMap: oldPatientSnap.data()!,
      targetPatientMap: targetPatientSnap.data(),
      targetFiscalCode: newId,
      submittedFullName: fullName,
      submittedAlias: normalizedAlias,
      preferSubmittedPatientFields: preferSubmittedPatientFields,
      isoNow: isoNow,
    );
    batch.set(newPatientRef, mergedPatient, SetOptions(merge: true));

    batch.delete(oldPatientRef);

    _queueSubcollectionMerge(
      batch: batch,
      docs: linked.debts,
      oldPatientRef: oldPatientRef,
      newPatientRef: newPatientRef,
      subcollectionPath: AppCollections.debts,
      oldId: oldId,
      newId: newId,
      fullName: fullName,
      isoNow: isoNow,
    );
    _queueSubcollectionMerge(
      batch: batch,
      docs: linked.advances,
      oldPatientRef: oldPatientRef,
      newPatientRef: newPatientRef,
      subcollectionPath: AppCollections.advances,
      oldId: oldId,
      newId: newId,
      fullName: fullName,
      isoNow: isoNow,
    );
    _queueSubcollectionMerge(
      batch: batch,
      docs: linked.bookings,
      oldPatientRef: oldPatientRef,
      newPatientRef: newPatientRef,
      subcollectionPath: AppCollections.bookings,
      oldId: oldId,
      newId: newId,
      fullName: fullName,
      isoNow: isoNow,
    );

    _queueRootDocsPatientFiscalCodeRewrite(batch, linked.rootDebts, newId, fullName, isoNow);
    _queueRootDocsPatientFiscalCodeRewrite(batch, linked.rootAdvances, newId, fullName, isoNow);
    _queueRootDocsPatientFiscalCodeRewrite(batch, linked.rootBookings, newId, fullName, isoNow);

    _queueManualDoctorLinkMerge(
      batch: batch,
      oldLinks: linked.doctorLinks,
      targetLinks: linked.targetDoctorLinks,
      oldId: oldId,
      newId: newId,
      fullName: fullName,
      isoNow: isoNow,
      preferSubmittedPatientFields: preferSubmittedPatientFields,
    );

    _queueTherapeuticAdviceMerge(
      batch: batch,
      oldAdvice: linked.therapeuticAdvice,
      targetAdvice: linked.targetTherapeuticAdvice,
      oldId: oldId,
      newId: newId,
      isoNow: isoNow,
      preferSubmittedPatientFields: preferSubmittedPatientFields,
    );

    _queueFamilyMembershipMerge(
      batch: batch,
      sourceFamilies: linked.sourceFamilies,
      targetFamilies: linked.targetFamilies,
      oldId: oldId,
      newId: newId,
      isoNow: isoNow,
    );

    final Map<String, dynamic> mergedIndex = _buildMergedDashboardIndexMap(
      oldIndexMap: oldIndexSnap.data(),
      targetIndexMap: targetIndexSnap.data(),
      targetFiscalCode: newId,
      fullName: (mergedPatient['fullName'] ?? fullName).toString(),
      alias: _normalizeAlias(mergedPatient['alias']?.toString()),
      debtCountDelta: linked.debts.length + linked.rootDebts.length,
      debtAmountDelta: _sumDebtAmount(linked.debts) + _sumDebtAmount(linked.rootDebts),
      advanceCountDelta: linked.advances.length + linked.rootAdvances.length,
      bookingCountDelta: linked.bookings.length + linked.rootBookings.length,
      family: linked.effectiveFamilyAfterMerge(newId),
      isoNow: isoNow,
    );
    batch.set(newIndexRef, mergedIndex, SetOptions(merge: true));
    if (oldIndexSnap.exists) {
      batch.delete(oldIndexRef);
    }

    await batch.commit();

    return PatientProfileUpdateResult(
      effectiveDocumentId: newId,
      fiscalCode: newId,
      fullName: (mergedPatient['fullName'] ?? fullName).toString(),
      migratedFromTemporaryKey: true,
      mergedIntoExistingPatient: targetPatientSnap.exists,
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
    if (currentPatientMap == null || _isHiddenPatientMap(currentPatientMap)) {
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

  Future<_FrontendMergeLinkedData> _readFrontendMergeLinkedData({
    required FirebaseFirestore firestore,
    required String temporaryFiscalCode,
    required String targetFiscalCode,
  }) async {
    final DocumentReference<Map<String, dynamic>> oldPatientRef =
        firestore.collection(AppCollections.patients).doc(temporaryFiscalCode);
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> debts =
        await _readBoundedSubcollection(oldPatientRef, AppCollections.debts, _maxFrontendMergeSubcollectionDocs);
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> advances =
        await _readBoundedSubcollection(oldPatientRef, AppCollections.advances, _maxFrontendMergeSubcollectionDocs);
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> bookings =
        await _readBoundedSubcollection(oldPatientRef, AppCollections.bookings, _maxFrontendMergeSubcollectionDocs);

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> rootDebts =
        await _readBoundedRootDocsByPatientFiscalCode(firestore, AppCollections.debts, temporaryFiscalCode, _maxFrontendMergeRootDocs);
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> rootAdvances =
        await _readBoundedRootDocsByPatientFiscalCode(firestore, AppCollections.advances, temporaryFiscalCode, _maxFrontendMergeRootDocs);
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> rootBookings =
        await _readBoundedRootDocsByPatientFiscalCode(firestore, AppCollections.bookings, temporaryFiscalCode, _maxFrontendMergeRootDocs);

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> doctorLinks =
        await _readBoundedRootDocsByPatientFiscalCode(firestore, AppCollections.doctorPatientLinks, temporaryFiscalCode, _maxFrontendMergeDoctorLinks);
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> targetDoctorLinks =
        await _readBoundedRootDocsByPatientFiscalCode(firestore, AppCollections.doctorPatientLinks, targetFiscalCode, _maxFrontendMergeDoctorLinks);
    _assertOnlyManualDoctorLinks(doctorLinks, temporaryFiscalCode);

    final DocumentSnapshot<Map<String, dynamic>> advice = await firestore
        .collection(AppCollections.patientTherapeuticAdvice)
        .doc(temporaryFiscalCode)
        .get();
    final DocumentSnapshot<Map<String, dynamic>> targetAdvice = await firestore
        .collection(AppCollections.patientTherapeuticAdvice)
        .doc(targetFiscalCode)
        .get();

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> sourceFamilies =
        await _readBoundedArrayContains(firestore, AppCollections.families, 'memberFiscalCodes', temporaryFiscalCode, _maxFrontendMergeFamilies);
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> targetFamilies =
        await _readBoundedArrayContains(firestore, AppCollections.families, 'memberFiscalCodes', targetFiscalCode, _maxFrontendMergeFamilies);
    _assertFamilyMergeIsNotAmbiguous(sourceFamilies, targetFamilies);

    return _FrontendMergeLinkedData(
      debts: debts,
      advances: advances,
      bookings: bookings,
      rootDebts: rootDebts,
      rootAdvances: rootAdvances,
      rootBookings: rootBookings,
      doctorLinks: doctorLinks,
      targetDoctorLinks: targetDoctorLinks,
      therapeuticAdvice: advice.exists ? advice : null,
      targetTherapeuticAdvice: targetAdvice.exists ? targetAdvice : null,
      sourceFamilies: sourceFamilies,
      targetFamilies: targetFamilies,
    );
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _readBoundedSubcollection(
    DocumentReference<Map<String, dynamic>> parentRef,
    String subcollectionPath,
    int maxDocs,
  ) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await parentRef
        .collection(subcollectionPath)
        .limit(maxDocs + 1)
        .get();
    if (snapshot.docs.length > maxDocs) {
      throw PatientProfileUpdateException(
        'Troppi documenti collegati in $subcollectionPath. Fusione bloccata.',
      );
    }
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _readBoundedRootDocsByPatientFiscalCode(
    FirebaseFirestore firestore,
    String collectionPath,
    String fiscalCode,
    int maxDocs,
  ) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await firestore
        .collection(collectionPath)
        .where('patientFiscalCode', isEqualTo: fiscalCode)
        .limit(maxDocs + 1)
        .get();
    if (snapshot.docs.length > maxDocs) {
      throw PatientProfileUpdateException(
        'Troppi documenti collegati in $collectionPath. Fusione bloccata.',
      );
    }
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _readBoundedArrayContains(
    FirebaseFirestore firestore,
    String collectionPath,
    String field,
    String value,
    int maxDocs,
  ) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await firestore
        .collection(collectionPath)
        .where(field, arrayContains: value)
        .limit(maxDocs + 1)
        .get();
    if (snapshot.docs.length > maxDocs) {
      throw PatientProfileUpdateException(
        'Troppi documenti collegati in $collectionPath. Fusione bloccata.',
      );
    }
    return snapshot.docs;
  }

  void _queueSubcollectionMerge({
    required WriteBatch batch,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required DocumentReference<Map<String, dynamic>> oldPatientRef,
    required DocumentReference<Map<String, dynamic>> newPatientRef,
    required String subcollectionPath,
    required String oldId,
    required String newId,
    required String fullName,
    required String isoNow,
  }) {
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
      final Map<String, dynamic> data = _cleanMapForWrite(doc.data());
      data['patientFiscalCode'] = newId;
      data['patientFullName'] = fullName;
      data['updatedAt'] = isoNow;
      final String targetDocId = _mergeTargetDocumentId(
        sourceDocId: doc.id,
        sourcePatientId: oldId,
      );
      batch.set(newPatientRef.collection(subcollectionPath).doc(targetDocId), data);
      batch.delete(oldPatientRef.collection(subcollectionPath).doc(doc.id));
    }
  }

  void _queueRootDocsPatientFiscalCodeRewrite(
    WriteBatch batch,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String newId,
    String fullName,
    String isoNow,
  ) {
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
      batch.set(
        doc.reference,
        <String, dynamic>{
          'patientFiscalCode': newId,
          'patientFullName': fullName,
          'updatedAt': isoNow,
        },
        SetOptions(merge: true),
      );
    }
  }

  void _queueManualDoctorLinkMerge({
    required WriteBatch batch,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> oldLinks,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> targetLinks,
    required String oldId,
    required String newId,
    required String fullName,
    required String isoNow,
    required bool preferSubmittedPatientFields,
  }) {
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> oldManuals = _manualDoctorLinks(oldLinks);
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> targetManuals = _manualDoctorLinks(targetLinks);
    if (oldManuals.length > 1 || targetManuals.length > 1) {
      throw const PatientProfileUpdateException(
        'Link medico manuale multiplo. Fusione frontend bloccata.',
      );
    }
    final QueryDocumentSnapshot<Map<String, dynamic>>? oldManual = oldManuals.isEmpty ? null : oldManuals.first;
    final QueryDocumentSnapshot<Map<String, dynamic>>? targetManual = targetManuals.isEmpty ? null : targetManuals.first;
    if (oldManual == null) return;
    if (targetManual != null && !preferSubmittedPatientFields) {
      batch.delete(oldManual.reference);
      return;
    }
    final Map<String, dynamic> data = _cleanMapForWrite(oldManual.data());
    data['patientFiscalCode'] = newId;
    data['patientFullName'] = fullName;
    data['updatedAt'] = isoNow;
    batch.set(
      oldManual.reference.firestore
          .collection(AppCollections.doctorPatientLinks)
          .doc('${newId}__manual'),
      data,
      SetOptions(merge: true),
    );
    batch.delete(oldManual.reference);
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _manualDoctorLinks(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final String id = doc.id.trim();
      final String type = _readStringField(doc.data(), 'linkType').toLowerCase();
      final bool isManualId = id.endsWith('__manual');
      final bool hasManualType = type.isEmpty || type == 'manual';
      return isManualId && hasManualType;
    }).toList(growable: false);
  }

  void _assertOnlyManualDoctorLinks(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String temporaryFiscalCode,
  ) {
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
      final String id = doc.id.trim();
      final String type = _readStringField(doc.data(), 'linkType').toLowerCase();
      final bool isManualId = id.endsWith('__manual');
      final bool hasManualType = type.isEmpty || type == 'manual';
      final bool manual = isManualId && hasManualType;
      if (!manual) {
        throw PatientProfileUpdateException(
          'Il TMP $temporaryFiscalCode ha link medico non manuale o non standard. Fusione frontend bloccata.',
        );
      }
    }
  }

  void _queueTherapeuticAdviceMerge({
    required WriteBatch batch,
    required DocumentSnapshot<Map<String, dynamic>>? oldAdvice,
    required DocumentSnapshot<Map<String, dynamic>>? targetAdvice,
    required String oldId,
    required String newId,
    required String isoNow,
    required bool preferSubmittedPatientFields,
  }) {
    if (oldAdvice == null || !oldAdvice.exists || oldAdvice.data() == null) return;
    final Map<String, dynamic> oldData = oldAdvice.data()!;
    final String oldText = _readStringField(oldData, 'text');
    if (oldText.isEmpty) {
      batch.delete(oldAdvice.reference);
      return;
    }
    final String targetText = targetAdvice == null || !targetAdvice.exists || targetAdvice.data() == null
        ? ''
        : _readStringField(targetAdvice.data()!, 'text');
    final String mergedText = targetText.isEmpty
        ? oldText
        : preferSubmittedPatientFields
            ? '$oldText\n\n--- Nota precedente assistito canonico ---\n$targetText'
            : '$targetText\n\n--- Nota proveniente da TMP $oldId ---\n$oldText';
    final Map<String, dynamic> data = _cleanMapForWrite(oldData);
    data['patientFiscalCode'] = newId;
    data['text'] = mergedText;
    data['updatedAt'] = isoNow;
    batch.set(
      oldAdvice.reference.firestore.collection(AppCollections.patientTherapeuticAdvice).doc(newId),
      data,
      SetOptions(merge: true),
    );
    batch.delete(oldAdvice.reference);
  }

  void _queueFamilyMembershipMerge({
    required WriteBatch batch,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> sourceFamilies,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> targetFamilies,
    required String oldId,
    required String newId,
    required String isoNow,
  }) {
    final String targetFamilyId = targetFamilies.isEmpty ? '' : targetFamilies.first.id;
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in sourceFamilies) {
      final List<String> members = _readStringList(doc.data()['memberFiscalCodes'])
          .map(PatientInputNormalizer.normalizeFiscalCode)
          .where((String value) => value.isNotEmpty && value != oldId)
          .toSet()
          .toList();
      if (targetFamilyId.isNotEmpty && doc.id != targetFamilyId) {
        if (members.isEmpty) {
          batch.delete(doc.reference);
        } else {
          batch.set(doc.reference, <String, dynamic>{
            'memberFiscalCodes': members..sort(),
            'updatedAt': isoNow,
          }, SetOptions(merge: true));
        }
        continue;
      }
      if (!members.contains(newId)) members.add(newId);
      members.sort();
      batch.set(doc.reference, <String, dynamic>{
        'memberFiscalCodes': members,
        'updatedAt': isoNow,
      }, SetOptions(merge: true));
    }
  }

  void _assertFamilyMergeIsNotAmbiguous(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> sourceFamilies,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> targetFamilies,
  ) {
    final Set<String> sourceIds = sourceFamilies.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.id).toSet();
    final Set<String> targetIds = targetFamilies.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.id).toSet();
    if (sourceIds.length > 1 || targetIds.length > 1) {
      throw const PatientProfileUpdateException('Appartenenza famiglia ambigua. Fusione frontend bloccata.');
    }
    if (sourceIds.isNotEmpty && targetIds.isNotEmpty && sourceIds.first != targetIds.first) {
      throw const PatientProfileUpdateException(
        'TMP e CF appartengono a nuclei diversi. Risolvi la famiglia prima della fusione.',
      );
    }
  }

  Map<String, dynamic> _buildMergedPatientMap({
    required Map<String, dynamic> oldPatientMap,
    required Map<String, dynamic>? targetPatientMap,
    required String targetFiscalCode,
    required String submittedFullName,
    required String? submittedAlias,
    required bool preferSubmittedPatientFields,
    required String isoNow,
  }) {
    final Map<String, dynamic> base = _cleanMapForWrite(targetPatientMap ?? oldPatientMap);
    final String targetFullName = _readStringField(targetPatientMap ?? const <String, dynamic>{}, 'fullName');
    final String targetAlias = _readStringField(targetPatientMap ?? const <String, dynamic>{}, 'alias');
    base['fiscalCode'] = targetFiscalCode;
    base['fullName'] = preferSubmittedPatientFields || targetFullName.isEmpty ? submittedFullName : targetFullName;
    base['alias'] = preferSubmittedPatientFields || targetAlias.isEmpty ? submittedAlias : targetAlias;
    base['updatedAt'] = isoNow;
    base['hiddenFromFrontend'] = false;
    base.remove('patientProfileMigrated');
    base.remove('migratedToFiscalCode');
    return base;
  }

  Map<String, dynamic> _buildMergedDashboardIndexMap({
    required Map<String, dynamic>? oldIndexMap,
    required Map<String, dynamic>? targetIndexMap,
    required String targetFiscalCode,
    required String fullName,
    required String? alias,
    required int debtCountDelta,
    required double debtAmountDelta,
    required int advanceCountDelta,
    required int bookingCountDelta,
    required QueryDocumentSnapshot<Map<String, dynamic>>? family,
    required String isoNow,
  }) {
    final Map<String, dynamic> base = _cleanMapForWrite(targetIndexMap ?? oldIndexMap ?? const <String, dynamic>{});
    final Map<String, dynamic> counterBase = targetIndexMap ?? const <String, dynamic>{};
    final int currentDebtCount = _readIntField(counterBase, 'debtCount');
    final double currentDebtAmount = _readDoubleField(counterBase, 'debtAmount');
    final int currentAdvanceCount = _readIntField(counterBase, 'advanceCount');
    final int currentBookingCount = _readIntField(counterBase, 'bookingCount');
    base['fiscalCode'] = targetFiscalCode;
    base['fullName'] = fullName;
    base['alias'] = alias;
    base['debtCount'] = currentDebtCount + debtCountDelta;
    base['debtAmount'] = currentDebtAmount + debtAmountDelta;
    base['advanceCount'] = currentAdvanceCount + advanceCountDelta;
    base['bookingCount'] = currentBookingCount + bookingCountDelta;
    base['hasDebt'] = (base['debtCount'] as int) > 0 || (base['debtAmount'] as double).abs() > 0.005;
    base['hasAdvance'] = (base['advanceCount'] as int) > 0;
    base['hasBooking'] = (base['bookingCount'] as int) > 0;
    if (family != null) {
      final Map<String, dynamic> familyData = family.data();
      base['familyId'] = family.id;
      base['familyName'] = _readStringField(familyData, 'name');
      base['familyColorIndex'] = _readIntField(familyData, 'colorIndex');
    }
    base['searchPrefixes'] = PatientDashboardIndexRepository.buildSearchPrefixes(<String>[
      targetFiscalCode,
      fullName,
      alias ?? '',
      _readStringField(base, 'doctorFullName'),
      _readStringField(base, 'city'),
      _readStringField(base, 'exemptionCode'),
    ]);
    base['updatedAt'] = isoNow;
    return base;
  }

  void _assertTemporaryPatientHasNoBackendOwnedSignals({
    required Map<String, dynamic> patientMap,
    required Map<String, dynamic>? indexMap,
  }) {
    final List<String> blockers = <String>[];
    void addIf(bool condition, String label) {
      if (condition) blockers.add(label);
    }
    addIf(_readBoolField(patientMap, 'hasDpc'), 'DPC paziente');
    addIf(_readIntField(patientMap, 'archivedRecipeCount') > 0, 'ricette paziente');
    addIf(_readIntField(patientMap, 'archivedPdfCount') > 0, 'PDF paziente');
    addIf(_readIntField(patientMap, 'activeArchiveDocuments') > 0, 'archivio paziente');
    if (indexMap != null) {
      addIf(_readBoolField(indexMap, 'hasRecipes'), 'ricette index');
      addIf(_readIntField(indexMap, 'recipeCount') > 0, 'ricette index');
      addIf(_readBoolField(indexMap, 'hasDpc'), 'DPC index');
      addIf(_readIntField(indexMap, 'dpcCount') > 0, 'DPC index');
      addIf(_readBoolField(indexMap, 'hasExpiry'), 'scadenze index');
    }
    if (blockers.isNotEmpty) {
      throw PatientProfileUpdateException(
        'Il TMP contiene dati backend-owned (${blockers.join(', ')}). Fusione frontend bloccata.',
      );
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
    final String normalizedOld =
        PatientInputNormalizer.normalizeFiscalCode(oldPatientDocumentId);
    final String normalizedNew =
        PatientInputNormalizer.normalizeFiscalCode(newPatientDocumentId);
    final List<Map<String, dynamic>> links = await datasource.getCollectionWhereEqual(
      collectionPath: AppCollections.doctorPatientLinks,
      field: 'patientFiscalCode',
      value: normalizedOld,
      limit: _maxFrontendMergeDoctorLinks + 1,
    );
    if (links.length > _maxFrontendMergeDoctorLinks) {
      throw const PatientProfileUpdateException('Troppi link medico collegati. Operazione bloccata.');
    }

    if (migrationMode) {
      throw UnsupportedError('Usa mergeTemporaryPatientIntoFiscalCode per fondere TMP→CF.');
    }

    for (final Map<String, dynamic> link in links) {
      final String linkPatientCode = PatientInputNormalizer.normalizeFiscalCode(
        link['patientFiscalCode']?.toString() ?? '',
      );
      if (linkPatientCode != normalizedOld) continue;
      final String currentLinkId = _readId(link);
      if (currentLinkId.isEmpty) continue;
      final Map<String, dynamic> nextMap = _cleanMapForWrite(link);
      nextMap['patientFiscalCode'] = normalizedNew;
      nextMap['patientFullName'] = fullName;
      nextMap['updatedAt'] = isoNow;
      final DocumentReference<Map<String, dynamic>> targetRef = firestore
          .collection(AppCollections.doctorPatientLinks)
          .doc(currentLinkId);
      batch.set(targetRef, nextMap, SetOptions(merge: true));
    }
  }

  Future<Patient?> getPatientByFiscalCode(String fiscalCode) async {
    final Map<String, dynamic>? map = await datasource.getDocument(
      collectionPath: AppCollections.patients,
      documentId: fiscalCode,
    );
    if (map == null || _isHiddenPatientMap(map)) return null;
    return Patient.fromMap(map);
  }

  Future<List<Patient>> getAllPatients() async {
    final List<Map<String, dynamic>> maps = await datasource.getCollection(
      collectionPath: AppCollections.patients,
      orderBy: 'fullName',
    );
    return maps
        .where((Map<String, dynamic> map) => !_isHiddenPatientMap(map))
        .map(Patient.fromMap)
        .toList();
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

  bool _isHiddenPatientMap(Map<String, dynamic> map) {
    return _readBoolField(map, 'hiddenFromFrontend') ||
        _readBoolField(map, 'patientProfileMigrated') ||
        _readStringField(map, 'migratedToFiscalCode').isNotEmpty;
  }

  String? _normalizeAlias(String? value) {
    final String normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }


  List<String> detectTemporaryMergeProfileConflicts({
    required Patient sourcePatient,
    required Patient? targetPatient,
    required String submittedFullName,
    String? submittedAlias,
  }) {
    if (targetPatient == null) return const <String>[];
    return _detectSubmittedFieldConflicts(
      sourceValues: <String, String>{
        'fullName': submittedFullName,
        if (_normalizeAlias(submittedAlias) != null) 'alias': _normalizeAlias(submittedAlias)!,
      },
      targetValues: <String, String>{
        'fullName': targetPatient.fullName,
        if ((targetPatient.alias ?? '').trim().isNotEmpty) 'alias': targetPatient.alias!.trim(),
      },
    );
  }

  List<String> _detectSubmittedFieldConflicts({
    required Map<String, String> sourceValues,
    required Map<String, String> targetValues,
  }) {
    final List<String> conflicts = <String>[];
    for (final String field in <String>['fullName', 'alias']) {
      final String sourceValue = _comparableString(sourceValues[field]);
      final String targetValue = _comparableString(targetValues[field]);
      if (sourceValue.isNotEmpty && targetValue.isNotEmpty && sourceValue != targetValue) {
        conflicts.add(field);
      }
    }
    return conflicts;
  }

  String _mergeTargetDocumentId({
    required String sourceDocId,
    required String sourcePatientId,
  }) {
    final String safeSource = sourcePatientId.replaceAll(RegExp(r'[^A-Z0-9]+'), '_');
    final String safeDoc = sourceDocId.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    return '${safeDoc}_from_$safeSource';
  }

  Map<String, dynamic> _cleanMapForWrite(Map<String, dynamic>? source) {
    final Map<String, dynamic> clean = Map<String, dynamic>.from(source ?? const <String, dynamic>{});
    clean.remove('id');
    return clean;
  }

  String _readId(Map<String, dynamic> map) {
    final dynamic id = map['id'];
    if (id == null) return '';
    return id.toString().trim();
  }

  String _readStringField(Map<String, dynamic> map, String field) {
    final dynamic value = map[field];
    return value == null ? '' : value.toString().trim();
  }

  List<String> _readStringList(dynamic value) {
    if (value is List) {
      return value
          .map((dynamic item) => item.toString().trim())
          .where((String item) => item.isNotEmpty)
          .toList();
    }
    return const <String>[];
  }

  bool _readBoolField(Map<String, dynamic> map, String field) {
    final dynamic value = map[field];
    if (value is bool) return value;
    final String normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == 'true' || normalized == '1' || normalized == 'yes' || normalized == 'si' || normalized == 'sì';
  }

  int _readIntField(Map<String, dynamic> map, String field) {
    final dynamic value = map[field];
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _readDoubleField(Map<String, dynamic> map, String field) {
    final dynamic value = map[field];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
  }

  double _sumDebtAmount(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return docs.fold<double>(0, (double sum, QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final Map<String, dynamic> data = doc.data();
      for (final String key in <String>['residualAmount', 'amount', 'debtAmount']) {
        final dynamic value = data[key];
        if (value is num) return sum + value.toDouble();
        final double? parsed = double.tryParse(value?.toString().replaceAll(',', '.') ?? '');
        if (parsed != null) return sum + parsed;
      }
      return sum;
    });
  }

  String _comparableString(String? value) {
    return (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
  }
}

class _FrontendMergeLinkedData {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> debts;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> advances;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> bookings;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> rootDebts;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> rootAdvances;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> rootBookings;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> doctorLinks;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> targetDoctorLinks;
  final DocumentSnapshot<Map<String, dynamic>>? therapeuticAdvice;
  final DocumentSnapshot<Map<String, dynamic>>? targetTherapeuticAdvice;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> sourceFamilies;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> targetFamilies;

  const _FrontendMergeLinkedData({
    required this.debts,
    required this.advances,
    required this.bookings,
    required this.rootDebts,
    required this.rootAdvances,
    required this.rootBookings,
    required this.doctorLinks,
    required this.targetDoctorLinks,
    required this.therapeuticAdvice,
    required this.targetTherapeuticAdvice,
    required this.sourceFamilies,
    required this.targetFamilies,
  });

  QueryDocumentSnapshot<Map<String, dynamic>>? effectiveFamilyAfterMerge(String targetFiscalCode) {
    if (sourceFamilies.isNotEmpty) return sourceFamilies.first;
    if (targetFamilies.isNotEmpty) return targetFamilies.first;
    return null;
  }
}

class PatientProfileUpdateResult {
  final String effectiveDocumentId;
  final String fiscalCode;
  final String fullName;
  final bool migratedFromTemporaryKey;
  final bool mergedIntoExistingPatient;
  final String? identityResolutionRequestId;

  const PatientProfileUpdateResult({
    required this.effectiveDocumentId,
    required this.fiscalCode,
    required this.fullName,
    required this.migratedFromTemporaryKey,
    this.mergedIntoExistingPatient = false,
    this.identityResolutionRequestId,
  });
}

class PatientProfileUpdateException implements Exception {
  final String message;

  const PatientProfileUpdateException(this.message);

  @override
  String toString() => message;
}
