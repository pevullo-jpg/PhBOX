import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/advance.dart';
import '../models/patient.dart';

class AdvancesRepository {
  final FirestoreDatasource datasource;
  const AdvancesRepository({required this.datasource});

  Future<void> saveAdvance(Advance advance) async {
    final raw = await datasource.getDocument(collectionPath: AppCollections.patients, documentId: advance.patientFiscalCode);
    final patient = raw == null ? Patient(fiscalCode: advance.patientFiscalCode, fullName: advance.patientName, createdAt: DateTime.now(), updatedAt: DateTime.now()) : Patient.fromMap(raw);
    final items = List<Advance>.from(patient.advances);
    final index = items.indexWhere((item) => item.id == advance.id);
    if (index >= 0) { items[index] = advance; } else { items.insert(0, advance); }
    final updated = patient.copyWith(advances: items, hasAdvance: items.isNotEmpty, activeAdvancesCount: items.length, updatedAt: DateTime.now());
    await datasource.setDocument(collectionPath: AppCollections.patients, documentId: advance.patientFiscalCode, data: updated.toMap());
  }

  Future<List<Advance>> getPatientAdvances(String fiscalCode) async {
    final raw = await datasource.getDocument(collectionPath: AppCollections.patients, documentId: fiscalCode);
    if (raw == null) return const <Advance>[];
    return Patient.fromMap(raw).advances;
  }

  Future<void> deleteAdvance(String fiscalCode, String id) async {
    final raw = await datasource.getDocument(collectionPath: AppCollections.patients, documentId: fiscalCode);
    if (raw == null) return;
    final patient = Patient.fromMap(raw);
    final items = patient.advances.where((item) => item.id != id).toList();
    final updated = patient.copyWith(advances: items, hasAdvance: items.isNotEmpty, activeAdvancesCount: items.length, updatedAt: DateTime.now());
    await datasource.setDocument(collectionPath: AppCollections.patients, documentId: fiscalCode, data: updated.toMap());
  }
}
