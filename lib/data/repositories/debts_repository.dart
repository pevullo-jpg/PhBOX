import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/debt.dart';

class DebtsRepository {
  final FirestoreDatasource datasource;

  const DebtsRepository({required this.datasource});

  Future<void> saveDebt(Debt debt) {
    return datasource.setSubDocument(
      collectionPath: AppCollections.patients,
      documentId: debt.patientFiscalCode,
      subcollectionPath: AppCollections.debts,
      subDocumentId: debt.id,
      data: debt.toMap(),
    );
  }

  Future<List<Debt>> getPatientDebts(String fiscalCode) async {
    final List<Map<String, dynamic>> maps = await datasource.getSubCollection(
      collectionPath: AppCollections.patients,
      documentId: fiscalCode,
      subcollectionPath: AppCollections.debts,
      orderBy: 'createdAt',
      descending: true,
    );
    return maps.map(Debt.fromMap).toList();
  }


  Future<void> deleteDebt(String fiscalCode, String id) {
    return datasource.deleteSubDocument(
      collectionPath: AppCollections.patients,
      documentId: fiscalCode,
      subcollectionPath: AppCollections.debts,
      subDocumentId: id,
    );
  }
}
