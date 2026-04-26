import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/advance.dart';
import 'runtime_signal_repository.dart';

class AdvancesRepository {
  final FirestoreDatasource datasource;

  const AdvancesRepository({required this.datasource});

  RuntimeSignalRepository get _runtimeSignalRepository => RuntimeSignalRepository(datasource: datasource);

  Future<void> saveAdvance(Advance advance) async {
    final String fiscalCode = advance.patientFiscalCode.trim().toUpperCase();
    await datasource.setSubDocument(
      collectionPath: AppCollections.patients,
      documentId: fiscalCode,
      subcollectionPath: AppCollections.advances,
      subDocumentId: advance.id,
      data: advance.toMap(),
    );
    await _runtimeSignalRepository.emitManualDataSignal(
      domain: 'advances',
      operation: 'sync',
      targetPath: '${AppCollections.patients}/$fiscalCode/${AppCollections.advances}/${advance.id}',
      targetFiscalCode: fiscalCode,
      targetDocumentId: advance.id,
      requiresTotalsUpdate: true,
      requiresIndexUpdate: true,
    );
  }

  Future<List<Advance>> getAllAdvances() async {
    final List<Map<String, dynamic>> maps = await datasource.getCollectionGroup(
      collectionPath: AppCollections.advances,
    );
    return maps.map(Advance.fromMap).toList();
  }

  Future<List<Advance>> getPatientAdvances(String fiscalCode) async {
    final List<Map<String, dynamic>> maps = await datasource.getSubCollection(
      collectionPath: AppCollections.patients,
      documentId: fiscalCode,
      subcollectionPath: AppCollections.advances,
    );
    return maps.map(Advance.fromMap).toList();
  }

  Future<void> deleteAdvance(String fiscalCode, String id) async {
    final String normalizedFiscalCode = fiscalCode.trim().toUpperCase();
    await datasource.deleteSubDocument(
      collectionPath: AppCollections.patients,
      documentId: normalizedFiscalCode,
      subcollectionPath: AppCollections.advances,
      subDocumentId: id,
    );
    await _runtimeSignalRepository.emitManualDataSignal(
      domain: 'advances',
      operation: 'delete',
      targetPath: '${AppCollections.patients}/$normalizedFiscalCode/${AppCollections.advances}/$id',
      targetFiscalCode: normalizedFiscalCode,
      targetDocumentId: id,
      requiresTotalsUpdate: true,
      requiresIndexUpdate: true,
    );
  }
}
