import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';

enum BackupImportMode {
  merge,
  overwrite,
}

class BackupImportResult {
  final int writtenDocuments;
  final int deletedDocuments;

  const BackupImportResult({
    required this.writtenDocuments,
    required this.deletedDocuments,
  });
}

class BackupImportService {
  final FirebaseFirestore firestore;

  const BackupImportService({required this.firestore});

  Future<BackupImportResult> importJsonBytes({
    required Uint8List bytes,
    required BackupImportMode mode,
  }) async {
    final Map<String, dynamic> payload = _decodePayload(bytes);
    final _SnapshotData snapshot = _SnapshotData.fromPayload(payload);
    final _BatchWriter writer = _BatchWriter(firestore);

    int deletedDocuments = 0;
    if (mode == BackupImportMode.overwrite) {
      deletedDocuments = await _queueOverwriteDeletes(
        snapshot: snapshot,
        writer: writer,
      );
    }

    final int writtenDocuments = await _queueWrites(
      snapshot: snapshot,
      writer: writer,
      merge: mode == BackupImportMode.merge,
    );

    await writer.commit();
    return BackupImportResult(
      writtenDocuments: writtenDocuments,
      deletedDocuments: deletedDocuments,
    );
  }

  Map<String, dynamic> _decodePayload(Uint8List bytes) {
    String content = utf8.decode(bytes, allowMalformed: true).trim();
    if (content.startsWith('\uFEFF')) {
      content = content.substring(1).trimLeft();
    }
    final dynamic decoded = jsonDecode(content);
    if (decoded is! Map) {
      throw Exception('Il file selezionato non contiene un backup JSON valido.');
    }
    return Map<String, dynamic>.from(decoded as Map);
  }

  Future<int> _queueOverwriteDeletes({
    required _SnapshotData snapshot,
    required _BatchWriter writer,
  }) async {
    int deleted = 0;

    deleted += await _deleteMissingRootCollectionDocs(
      collectionPath: AppCollections.families,
      keepIds: snapshot.familyIds,
      writer: writer,
    );
    deleted += await _deleteMissingRootCollectionDocs(
      collectionPath: AppCollections.doctorPatientLinks,
      keepIds: snapshot.doctorLinkIds,
      writer: writer,
    );
    deleted += await _deleteMissingRootCollectionDocs(
      collectionPath: AppCollections.drivePdfImports,
      keepIds: snapshot.importIds,
      writer: writer,
    );
    deleted += await _deleteMissingRootCollectionDocs(
      collectionPath: AppCollections.patientTherapeuticAdvice,
      keepIds: snapshot.therapeuticAdviceIds,
      writer: writer,
    );
    deleted += await _deleteMissingRootCollectionDocs(
      collectionPath: AppCollections.prescriptionIntakes,
      keepIds: snapshot.prescriptionIntakeIds,
      writer: writer,
    );
    deleted += await _deleteMissingRootCollectionDocs(
      collectionPath: AppCollections.parserReferenceValues,
      keepIds: snapshot.parserReferenceIds,
      writer: writer,
    );

    final QuerySnapshot<Map<String, dynamic>> patientSnapshot =
        await firestore.collection(AppCollections.patients).get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> patientDoc
        in patientSnapshot.docs) {
      final String patientDocumentId = patientDoc.id.trim();
      final String patientLookupId = patientDocumentId.toUpperCase();

      if (!snapshot.patientIds.contains(patientLookupId)) {
        deleted += await _deleteAllKnownPatientSubcollections(
          patientDocumentId: patientDocumentId,
          writer: writer,
        );
        writer.deleteDoc(patientDoc.reference);
        deleted += 1;
        continue;
      }

      deleted += await _deleteMissingSubcollectionDocs(
        patientDocumentId: patientDocumentId,
        subcollectionPath: AppCollections.debts,
        keepIds: snapshot.debtIdsByPatient[patientLookupId] ?? const <String>{},
        writer: writer,
      );
      deleted += await _deleteMissingSubcollectionDocs(
        patientDocumentId: patientDocumentId,
        subcollectionPath: AppCollections.advances,
        keepIds:
            snapshot.advanceIdsByPatient[patientLookupId] ?? const <String>{},
        writer: writer,
      );
      deleted += await _deleteMissingSubcollectionDocs(
        patientDocumentId: patientDocumentId,
        subcollectionPath: AppCollections.bookings,
        keepIds:
            snapshot.bookingIdsByPatient[patientLookupId] ?? const <String>{},
        writer: writer,
      );
      deleted += await _deleteMissingSubcollectionDocs(
        patientDocumentId: patientDocumentId,
        subcollectionPath: AppCollections.prescriptions,
        keepIds: snapshot.prescriptionIdsByPatient[patientLookupId] ??
            const <String>{},
        writer: writer,
      );
    }

    return deleted;
  }

  Future<int> _deleteMissingRootCollectionDocs({
    required String collectionPath,
    required Set<String> keepIds,
    required _BatchWriter writer,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await firestore.collection(collectionPath).get();
    int deleted = 0;
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snapshot.docs) {
      if (keepIds.contains(doc.id.trim())) {
        continue;
      }
      writer.deleteDoc(doc.reference);
      deleted += 1;
    }
    return deleted;
  }

  Future<int> _deleteMissingSubcollectionDocs({
    required String patientDocumentId,
    required String subcollectionPath,
    required Set<String> keepIds,
    required _BatchWriter writer,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await firestore
        .collection(AppCollections.patients)
        .doc(patientDocumentId)
        .collection(subcollectionPath)
        .get();
    int deleted = 0;
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snapshot.docs) {
      if (keepIds.contains(doc.id.trim())) {
        continue;
      }
      writer.deleteDoc(doc.reference);
      deleted += 1;
    }
    return deleted;
  }


  Future<int> _deleteAllKnownPatientSubcollections({
    required String patientDocumentId,
    required _BatchWriter writer,
  }) async {
    int deleted = 0;
    for (final String subcollectionPath in const <String>[
      AppCollections.debts,
      AppCollections.advances,
      AppCollections.bookings,
      AppCollections.prescriptions,
    ]) {
      deleted += await _deleteMissingSubcollectionDocs(
        patientDocumentId: patientDocumentId,
        subcollectionPath: subcollectionPath,
        keepIds: const <String>{},
        writer: writer,
      );
    }
    return deleted;
  }

  Future<int> _queueWrites({
    required _SnapshotData snapshot,
    required _BatchWriter writer,
    required bool merge,
  }) async {
    int written = 0;

    writer.setDoc(
      firestore.collection(AppCollections.appSettings).doc('main'),
      snapshot.appSettings,
      merge: merge,
    );
    written += 1;

    for (final Map<String, dynamic> patient in snapshot.patients) {
      final String patientId = _patientId(patient);
      if (patientId.isEmpty) {
        continue;
      }
      writer.setDoc(
        firestore.collection(AppCollections.patients).doc(patientId),
        patient,
        merge: merge,
      );
      written += 1;
    }

    for (final Map<String, dynamic> family in snapshot.families) {
      final String id = _docId(family, fallbacks: const <String>['familyId']);
      if (id.isEmpty) continue;
      writer.setDoc(
        firestore.collection(AppCollections.families).doc(id),
        family,
        merge: merge,
      );
      written += 1;
    }

    for (final Map<String, dynamic> link in snapshot.doctorPatientLinks) {
      final String id = _docId(link);
      if (id.isEmpty) continue;
      writer.setDoc(
        firestore.collection(AppCollections.doctorPatientLinks).doc(id),
        link,
        merge: merge,
      );
      written += 1;
    }

    for (final Map<String, dynamic> importDoc in snapshot.drivePdfImports) {
      final String id = _docId(
        importDoc,
        fallbacks: const <String>['duplicateHash', 'fileId', 'driveFileId'],
      );
      if (id.isEmpty) continue;
      writer.setDoc(
        firestore.collection(AppCollections.drivePdfImports).doc(id),
        importDoc,
        merge: merge,
      );
      written += 1;
    }

    for (final Map<String, dynamic> advice in snapshot.therapeuticAdvice) {
      final String id = _upperString(advice['patientFiscalCode']);
      if (id.isEmpty) continue;
      writer.setDoc(
        firestore.collection(AppCollections.patientTherapeuticAdvice).doc(id),
        advice,
        merge: merge,
      );
      written += 1;
    }

    for (final Map<String, dynamic> intake in snapshot.prescriptionIntakes) {
      final String id = _docId(intake);
      if (id.isEmpty) continue;
      writer.setDoc(
        firestore.collection(AppCollections.prescriptionIntakes).doc(id),
        intake,
        merge: merge,
      );
      written += 1;
    }

    for (final Map<String, dynamic> reference in snapshot.parserReferenceValues) {
      final String id = _docId(reference);
      if (id.isEmpty) continue;
      writer.setDoc(
        firestore.collection(AppCollections.parserReferenceValues).doc(id),
        reference,
        merge: merge,
      );
      written += 1;
    }

    written += _queuePatientSubcollectionWrites(
      writer: writer,
      collectionName: AppCollections.debts,
      docs: snapshot.debts,
      patientFieldName: 'patientFiscalCode',
      merge: merge,
    );
    written += _queuePatientSubcollectionWrites(
      writer: writer,
      collectionName: AppCollections.advances,
      docs: snapshot.advances,
      patientFieldName: 'patientFiscalCode',
      merge: merge,
    );
    written += _queuePatientSubcollectionWrites(
      writer: writer,
      collectionName: AppCollections.bookings,
      docs: snapshot.bookings,
      patientFieldName: 'patientFiscalCode',
      merge: merge,
    );
    written += _queuePatientSubcollectionWrites(
      writer: writer,
      collectionName: AppCollections.prescriptions,
      docs: snapshot.prescriptions,
      patientFieldName: 'patientFiscalCode',
      merge: merge,
    );

    return written;
  }

  int _queuePatientSubcollectionWrites({
    required _BatchWriter writer,
    required String collectionName,
    required List<Map<String, dynamic>> docs,
    required String patientFieldName,
    required bool merge,
  }) {
    int written = 0;
    for (final Map<String, dynamic> doc in docs) {
      final String patientId = _upperString(doc[patientFieldName]);
      final String id = _docId(doc);
      if (patientId.isEmpty || id.isEmpty) {
        continue;
      }
      writer.setDoc(
        firestore
            .collection(AppCollections.patients)
            .doc(patientId)
            .collection(collectionName)
            .doc(id),
        doc,
        merge: merge,
      );
      written += 1;
    }
    return written;
  }

  String _patientId(Map<String, dynamic> patient) {
    return _upperString(patient['fiscalCode'] ?? patient['patientFiscalCode']);
  }

  String _docId(
    Map<String, dynamic> data, {
    List<String> fallbacks = const <String>[],
  }) {
    final List<String> keys = <String>['id', ...fallbacks];
    for (final String key in keys) {
      final String value = _trimString(data[key]);
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  String _upperString(dynamic value) => _trimString(value).toUpperCase();

  String _trimString(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }
}

class _SnapshotData {
  final Map<String, dynamic> appSettings;
  final List<Map<String, dynamic>> patients;
  final List<Map<String, dynamic>> families;
  final List<Map<String, dynamic>> doctorPatientLinks;
  final List<Map<String, dynamic>> prescriptions;
  final List<Map<String, dynamic>> drivePdfImports;
  final List<Map<String, dynamic>> debts;
  final List<Map<String, dynamic>> advances;
  final List<Map<String, dynamic>> bookings;
  final List<Map<String, dynamic>> therapeuticAdvice;
  final List<Map<String, dynamic>> prescriptionIntakes;
  final List<Map<String, dynamic>> parserReferenceValues;

  const _SnapshotData({
    required this.appSettings,
    required this.patients,
    required this.families,
    required this.doctorPatientLinks,
    required this.prescriptions,
    required this.drivePdfImports,
    required this.debts,
    required this.advances,
    required this.bookings,
    required this.therapeuticAdvice,
    required this.prescriptionIntakes,
    required this.parserReferenceValues,
  });

  factory _SnapshotData.fromPayload(Map<String, dynamic> payload) {
    final dynamic collectionsRaw = payload['collections'];
    if (collectionsRaw is! Map) {
      throw Exception('Backup JSON privo del blocco collections.');
    }
    final Map<String, dynamic> collections =
        Map<String, dynamic>.from(collectionsRaw as Map);

    final List<String> requiredKeys = <String>[
      'app_settings',
      'patients',
      'families',
      'doctor_patient_links',
      'prescriptions',
      'drive_pdf_imports',
      'debts',
      'advances',
      'bookings',
      'patient_therapeutic_advice',
      'prescription_intakes',
      'parser_reference_values',
    ];
    for (final String key in requiredKeys) {
      if (!collections.containsKey(key)) {
        throw Exception('Backup JSON incompleto: manca $key.');
      }
    }

    return _SnapshotData(
      appSettings: _asMap(collections['app_settings']),
      patients: _asListOfMaps(collections['patients']),
      families: _asListOfMaps(collections['families']),
      doctorPatientLinks:
          _asListOfMaps(collections['doctor_patient_links']),
      prescriptions: _asListOfMaps(collections['prescriptions']),
      drivePdfImports: _asListOfMaps(collections['drive_pdf_imports']),
      debts: _asListOfMaps(collections['debts']),
      advances: _asListOfMaps(collections['advances']),
      bookings: _asListOfMaps(collections['bookings']),
      therapeuticAdvice:
          _asListOfMaps(collections['patient_therapeutic_advice']),
      prescriptionIntakes:
          _asListOfMaps(collections['prescription_intakes']),
      parserReferenceValues:
          _asListOfMaps(collections['parser_reference_values']),
    );
  }

  Set<String> get patientIds => patients
      .map((Map<String, dynamic> item) =>
          _trim(item['fiscalCode'] ?? item['patientFiscalCode']).toUpperCase())
      .where((String item) => item.isNotEmpty)
      .toSet();

  Set<String> get familyIds => families
      .map((Map<String, dynamic> item) => _trim(item['id'] ?? item['familyId']))
      .where((String item) => item.isNotEmpty)
      .toSet();

  Set<String> get doctorLinkIds => doctorPatientLinks
      .map((Map<String, dynamic> item) => _trim(item['id']))
      .where((String item) => item.isNotEmpty)
      .toSet();

  Set<String> get importIds => drivePdfImports
      .map((Map<String, dynamic> item) =>
          _trim(item['id'] ?? item['duplicateHash'] ?? item['fileId']))
      .where((String item) => item.isNotEmpty)
      .toSet();

  Set<String> get therapeuticAdviceIds => therapeuticAdvice
      .map((Map<String, dynamic> item) =>
          _trim(item['patientFiscalCode']).toUpperCase())
      .where((String item) => item.isNotEmpty)
      .toSet();

  Set<String> get prescriptionIntakeIds => prescriptionIntakes
      .map((Map<String, dynamic> item) => _trim(item['id']))
      .where((String item) => item.isNotEmpty)
      .toSet();

  Set<String> get parserReferenceIds => parserReferenceValues
      .map((Map<String, dynamic> item) => _trim(item['id']))
      .where((String item) => item.isNotEmpty)
      .toSet();

  Map<String, Set<String>> get debtIdsByPatient =>
      _subIdsByPatient(debts, 'patientFiscalCode');

  Map<String, Set<String>> get advanceIdsByPatient =>
      _subIdsByPatient(advances, 'patientFiscalCode');

  Map<String, Set<String>> get bookingIdsByPatient =>
      _subIdsByPatient(bookings, 'patientFiscalCode');

  Map<String, Set<String>> get prescriptionIdsByPatient =>
      _subIdsByPatient(prescriptions, 'patientFiscalCode');

  static Map<String, Set<String>> _subIdsByPatient(
    List<Map<String, dynamic>> docs,
    String patientField,
  ) {
    final Map<String, Set<String>> grouped = <String, Set<String>>{};
    for (final Map<String, dynamic> doc in docs) {
      final String patientId = _trim(doc[patientField]).toUpperCase();
      final String docId = _trim(doc['id']);
      if (patientId.isEmpty || docId.isEmpty) {
        continue;
      }
      grouped.putIfAbsent(patientId, () => <String>{}).add(docId);
    }
    return grouped;
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value as Map);
    }
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _asListOfMaps(dynamic value) {
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }
    return value
        .whereType<Map>()
        .map((Map item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static String _trim(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }
}

class _BatchWriter {
  final FirebaseFirestore firestore;
  WriteBatch _batch;
  int _pendingOperations = 0;
  static const int _maxOperations = 400;
  Future<void> _commitQueue = Future<void>.value();

  _BatchWriter(this.firestore) : _batch = firestore.batch();

  void setDoc(
    DocumentReference<Map<String, dynamic>> reference,
    Map<String, dynamic> data, {
    required bool merge,
  }) {
    final Map<String, dynamic> cleanData = Map<String, dynamic>.from(data);
    if (merge) {
      _batch.set(reference, cleanData, SetOptions(merge: true));
    } else {
      _batch.set(reference, cleanData);
    }
    _pendingOperations += 1;
    _flushIfNeeded();
  }

  void deleteDoc(DocumentReference<Map<String, dynamic>> reference) {
    _batch.delete(reference);
    _pendingOperations += 1;
    _flushIfNeeded();
  }

  void _flushIfNeeded() {
    if (_pendingOperations < _maxOperations) {
      return;
    }
    final WriteBatch batchToCommit = _batch;
    _batch = firestore.batch();
    _pendingOperations = 0;
    _commitQueue = _commitQueue.then((_) => batchToCommit.commit());
  }

  Future<void> commit() async {
    if (_pendingOperations > 0) {
      final WriteBatch batchToCommit = _batch;
      _batch = firestore.batch();
      _pendingOperations = 0;
      _commitQueue = _commitQueue.then((_) => batchToCommit.commit());
    }
    await _commitQueue;
  }
}
