import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/drive_pdf_import.dart';

class DrivePdfImportsRepository {
  final FirestoreDatasource datasource;

  const DrivePdfImportsRepository({required this.datasource});

  Future<void> saveImport(DrivePdfImport importItem) {
    return datasource.setDocument(
      collectionPath: AppCollections.drivePdfImports,
      documentId: importItem.id,
      data: importItem.toMap(),
    );
  }

  Future<List<DrivePdfImport>> getAllImports() async {
    final List<Map<String, dynamic>> maps = await datasource.getCollection(
      collectionPath: AppCollections.drivePdfImports,
      orderBy: 'updatedAt',
      descending: true,
    );
    return maps.map(DrivePdfImport.fromMap).toList();
  }

  Future<List<DrivePdfImport>> getImportsByPatient(String fiscalCode) async {
    final String normalized = fiscalCode.trim().toUpperCase();
    final List<DrivePdfImport> all = await getAllImports();
    final List<DrivePdfImport> filtered = all.where((DrivePdfImport item) {
      return item.patientFiscalCode.trim().toUpperCase() == normalized;
    }).toList();
    filtered.sort((DrivePdfImport a, DrivePdfImport b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }


  Future<void> deleteImport(String id) {
    return datasource.deleteDocument(
      collectionPath: AppCollections.drivePdfImports,
      documentId: id,
    );
  }

  Future<void> deleteImportsByPatient(String fiscalCode) async {
    final List<DrivePdfImport> imports = await getImportsByPatient(fiscalCode);
    for (final DrivePdfImport item in imports) {
      await deleteImport(item.id);
    }
  }
}
