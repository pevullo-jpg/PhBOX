import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/advance.dart';

class AdvancesRepository {
  final FirestoreDatasource datasource;

  const AdvancesRepository({required this.datasource});

  Future<void> saveAdvance(Advance advance) {
    return datasource.setSubDocument(
      collectionPath: AppCollections.patients,
      documentId: advance.patientFiscalCode,
      subcollectionPath: AppCollections.advances,
      subDocumentId: advance.id,
      data: advance.toMap(),
    );
  }

  Future<List<Advance>> getPatientAdvances(String fiscalCode) async {
    final List<Map<String, dynamic>> maps = await datasource.getSubCollection(
      collectionPath: AppCollections.patients,
      documentId: fiscalCode,
      subcollectionPath: AppCollections.advances,
      orderBy: 'createdAt',
      descending: true,
    );
    return maps.map(Advance.fromMap).toList();
  }



  Future<List<Advance>> getAllAdvances() async {
    final List<Map<String, dynamic>> maps = await datasource.getCollectionGroup(
      collectionPath: AppCollections.advances,
    );
    final advances = maps.map(Advance.fromMap).where((item) => item.patientFiscalCode.trim().isNotEmpty).toList();
    advances.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return advances;
  }

  Future<void> deleteAdvance(String fiscalCode, String id) {
    return datasource.deleteSubDocument(
      collectionPath: AppCollections.patients,
      documentId: fiscalCode,
      subcollectionPath: AppCollections.advances,
      subDocumentId: id,
    );
  }
}
