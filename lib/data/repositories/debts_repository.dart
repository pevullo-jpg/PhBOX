import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/debt.dart';
import 'runtime_signal_repository.dart';

class DebtsRepository {
  final FirestoreDatasource datasource;

  const DebtsRepository({required this.datasource});

  RuntimeSignalRepository get _runtimeSignalRepository => RuntimeSignalRepository(datasource: datasource);

  Future<void> saveDebt(Debt debt) async {
    final String fiscalCode = debt.patientFiscalCode.trim().toUpperCase();
    await datasource.setSubDocument(
      collectionPath: AppCollections.patients,
      documentId: fiscalCode,
      subcollectionPath: AppCollections.debts,
      subDocumentId: debt.id,
      data: debt.toMap(),
    );
    await _runtimeSignalRepository.emitManualDataSignal(
      domain: 'debts',
      operation: 'sync',
      targetPath: '${AppCollections.patients}/$fiscalCode/${AppCollections.debts}/${debt.id}',
      targetFiscalCode: fiscalCode,
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
    final String normalizedFiscalCode = fiscalCode.trim().toUpperCase();
    await datasource.deleteSubDocument(
      collectionPath: AppCollections.patients,
      documentId: normalizedFiscalCode,
      subcollectionPath: AppCollections.debts,
      subDocumentId: id,
    );
    await _runtimeSignalRepository.emitManualDataSignal(
      domain: 'debts',
      operation: 'delete',
      targetPath: '${AppCollections.patients}/$normalizedFiscalCode/${AppCollections.debts}/$id',
      targetFiscalCode: normalizedFiscalCode,
      targetDocumentId: id,
      requiresTotalsUpdate: true,
      requiresIndexUpdate: true,
    );
  }
}
