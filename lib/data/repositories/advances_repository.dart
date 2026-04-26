import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/advance.dart';
import 'runtime_signal_repository.dart';

class AdvancesRepository {
  final FirestoreDatasource datasource;

  const AdvancesRepository({required this.datasource});

  RuntimeSignalRepository get _runtimeSignals => RuntimeSignalRepository(datasource: datasource);

  Future<void> saveAdvance(Advance advance) async {
    await datasource.setSubDocument(
      collectionPath: AppCollections.patients,
      documentId: advance.patientFiscalCode,
      subcollectionPath: AppCollections.advances,
      subDocumentId: advance.id,
      data: advance.toMap(),
    );
    await _runtimeSignals.emitBestEffort(
      domain: 'advances',
      operation: 'sync',
      targetPath: 'patients/${advance.patientFiscalCode}/advances/${advance.id}',
      targetFiscalCode: advance.patientFiscalCode,
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
    await datasource.deleteSubDocument(
      collectionPath: AppCollections.patients,
      documentId: fiscalCode,
      subcollectionPath: AppCollections.advances,
      subDocumentId: id,
    );
    await _runtimeSignals.emitBestEffort(
      domain: 'advances',
      operation: 'delete',
      targetPath: 'patients/$fiscalCode/advances/$id',
      targetFiscalCode: fiscalCode,
      targetDocumentId: id,
      requiresTotalsUpdate: true,
      requiresIndexUpdate: true,
    );
  }
}
