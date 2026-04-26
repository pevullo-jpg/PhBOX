import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/debt.dart';
import 'runtime_signal_repository.dart';

class DebtsRepository {
  final FirestoreDatasource datasource;

  const DebtsRepository({required this.datasource});

  RuntimeSignalRepository get _runtimeSignals => RuntimeSignalRepository(datasource: datasource);

  Future<void> saveDebt(Debt debt) async {
    await datasource.setSubDocument(
      collectionPath: AppCollections.patients,
      documentId: debt.patientFiscalCode,
      subcollectionPath: AppCollections.debts,
      subDocumentId: debt.id,
      data: debt.toMap(),
    );
    await _runtimeSignals.emitBestEffort(
      domain: 'debts',
      operation: 'sync',
      targetPath: 'patients/${debt.patientFiscalCode}/debts/${debt.id}',
      targetFiscalCode: debt.patientFiscalCode,
      targetDocumentId: debt.id,
      requiresTotalsUpdate: true,
      requiresIndexUpdate: true,
    );
  }

  Future<List<Debt>> getAllDebts() async {
    final List<Map<String, dynamic>> maps = await datasource.getCollectionGroup(
      collectionPath: AppCollections.debts,
    );
    return maps.map(Debt.fromMap).toList();
  }

  Future<List<Debt>> getPatientDebts(String fiscalCode) async {
    final List<Map<String, dynamic>> maps = await datasource.getSubCollection(
      collectionPath: AppCollections.patients,
      documentId: fiscalCode,
      subcollectionPath: AppCollections.debts,
    );
    return maps.map(Debt.fromMap).toList();
  }

  Future<void> deleteDebt(String fiscalCode, String id) async {
    await datasource.deleteSubDocument(
      collectionPath: AppCollections.patients,
      documentId: fiscalCode,
      subcollectionPath: AppCollections.debts,
      subDocumentId: id,
    );
    await _runtimeSignals.emitBestEffort(
      domain: 'debts',
      operation: 'delete',
      targetPath: 'patients/$fiscalCode/debts/$id',
      targetFiscalCode: fiscalCode,
      targetDocumentId: id,
      requiresTotalsUpdate: true,
      requiresIndexUpdate: true,
    );
  }
}
