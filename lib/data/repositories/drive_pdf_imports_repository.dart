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
    );
    final List<DrivePdfImport> items = maps.map(DrivePdfImport.fromMap).where((DrivePdfImport item) {
      return (item.patientFiscalCode.trim().isNotEmpty || item.patientFullName.trim().isNotEmpty) && item.status.trim().toLowerCase() != 'deleted';
    }).toList();
    items.sort((DrivePdfImport a, DrivePdfImport b) {
      final DateTime aKey = a.prescriptionDate ?? a.updatedAt ?? a.createdAt;
      final DateTime bKey = b.prescriptionDate ?? b.updatedAt ?? b.createdAt;
      return bKey.compareTo(aKey);
    });
    return items;
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

  Future<void> softDeleteImport(String id) async {
    final Map<String, dynamic>? current = await datasource.getDocument(
      collectionPath: AppCollections.drivePdfImports,
      documentId: id,
    );
    if (current == null) return;
    final Map<String, dynamic> next = <String, dynamic>{...current};
    next['status'] = 'deleted';
    next['deletedAt'] = DateTime.now().toIso8601String();
    next['deleteMode'] = 'pdf_only_requested';
    next['webViewLink'] = '';
    next['openUrl'] = '';
    await datasource.setDocument(
      collectionPath: AppCollections.drivePdfImports,
      documentId: id,
      data: next,
    );
  }

  Future<void> deleteImportsByPatient(String fiscalCode) async {
    final List<DrivePdfImport> imports = await getImportsByPatient(fiscalCode);
    for (final DrivePdfImport item in imports) {
      await deleteImport(item.id);
    }
  }
}
