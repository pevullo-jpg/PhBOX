import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/debt.dart';
import '../models/patient.dart';

class DebtsRepository {
  final FirestoreDatasource datasource;
  const DebtsRepository({required this.datasource});

  Future<void> saveDebt(Debt debt) async {
    final raw = await datasource.getDocument(collectionPath: AppCollections.patients, documentId: debt.patientFiscalCode);
    final patient = raw == null ? Patient(fiscalCode: debt.patientFiscalCode, fullName: debt.patientName, createdAt: DateTime.now(), updatedAt: DateTime.now()) : Patient.fromMap(raw);
    final items = List<Debt>.from(patient.debts);
    final index = items.indexWhere((item) => item.id == debt.id);
    if (index >= 0) { items[index] = debt; } else { items.insert(0, debt); }
    final total = items.fold<double>(0, (sum, item) => sum + item.residualAmount);
    final updated = patient.copyWith(debts: items, hasDebt: items.isNotEmpty, activeDebtsCount: items.length, debtTotal: total, totalDebtAmount: total, updatedAt: DateTime.now());
    await datasource.setDocument(collectionPath: AppCollections.patients, documentId: debt.patientFiscalCode, data: updated.toMap());
  }

  Future<List<Debt>> getPatientDebts(String fiscalCode) async {
    final raw = await datasource.getDocument(collectionPath: AppCollections.patients, documentId: fiscalCode);
    if (raw == null) return const <Debt>[];
    return Patient.fromMap(raw).debts;
  }

  Future<void> deleteDebt(String fiscalCode, String id) async {
    final raw = await datasource.getDocument(collectionPath: AppCollections.patients, documentId: fiscalCode);
    if (raw == null) return;
    final patient = Patient.fromMap(raw);
    final items = patient.debts.where((item) => item.id != id).toList();
    final total = items.fold<double>(0, (sum, item) => sum + item.residualAmount);
    final updated = patient.copyWith(debts: items, hasDebt: items.isNotEmpty, activeDebtsCount: items.length, debtTotal: total, totalDebtAmount: total, updatedAt: DateTime.now());
    await datasource.setDocument(collectionPath: AppCollections.patients, documentId: fiscalCode, data: updated.toMap());
  }
}
