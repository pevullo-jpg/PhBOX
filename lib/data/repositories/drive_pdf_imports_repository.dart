import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/drive_pdf_import.dart';

class DrivePdfImportsRepository {
  final FirestoreDatasource datasource;

  const DrivePdfImportsRepository({required this.datasource});

  Future<void> saveImport(DrivePdfImport item) {
    return datasource.setDocument(
      collectionPath: AppCollections.drivePdfImports,
      documentId: item.id,
      data: item.toMap(),
    );
  }

  Future<List<DrivePdfImport>> getAllImports({bool includeInactive = false}) async {
    final List<Map<String, dynamic>> maps = await datasource.getCollection(
      collectionPath: AppCollections.drivePdfImports,
      orderBy: 'updatedAt',
      descending: true,
    );
    final List<DrivePdfImport> items = maps.map(DrivePdfImport.fromMap).toList();
    final List<DrivePdfImport> filtered = includeInactive ? items : items.where((DrivePdfImport item) => !item.isInactiveForActiveFlows).toList();
    filtered.sort((DrivePdfImport a, DrivePdfImport b) {
      final DateTime aKey = a.prescriptionDate ?? a.updatedAt;
      final DateTime bKey = b.prescriptionDate ?? b.updatedAt;
      return bKey.compareTo(aKey);
    });
    return filtered;
  }

  Future<List<DrivePdfImport>> getImportsByPatient(String fiscalCode, {bool includeInactive = false}) async {
    final String normalized = fiscalCode.trim().toUpperCase();
    final List<DrivePdfImport> all = await getAllImports(includeInactive: includeInactive);
    final List<DrivePdfImport> filtered = all.where((DrivePdfImport item) {
      return item.patientFiscalCode.trim().toUpperCase() == normalized;
    }).toList();
    filtered.sort((DrivePdfImport a, DrivePdfImport b) {
      final DateTime aKey = a.prescriptionDate ?? a.updatedAt;
      final DateTime bKey = b.prescriptionDate ?? b.updatedAt;
      return bKey.compareTo(aKey);
    });
    return filtered;
  }

  Future<DrivePdfImport?> getImportById(String id) async {
    final Map<String, dynamic>? map = await datasource.getDocument(
      collectionPath: AppCollections.drivePdfImports,
      documentId: id,
    );
    if (map == null) return null;
    return DrivePdfImport.fromMap(<String, dynamic>{...map, 'id': map['id'] ?? id});
  }

  Future<void> deleteImport(String id) {
    return datasource.deleteDocument(
      collectionPath: AppCollections.drivePdfImports,
      documentId: id,
    );
  }

  Future<void> queueImportDeletion(String id) async {
    final Map<String, dynamic>? current = await datasource.getDocument(
      collectionPath: AppCollections.drivePdfImports,
      documentId: id,
    );
    if (current == null) return;
    final DateTime now = DateTime.now();
    final Map<String, dynamic> next = <String, dynamic>{...current};
    next['status'] = AppImportStatuses.deleteRequested;
    next['deletePdfRequested'] = true;
    next['excludeFromMerge'] = true;
    next['excludeFromReanalysis'] = true;
    next['deletionRequestedAt'] = now.toIso8601String();
    next['updatedAt'] = now.toIso8601String();
    await datasource.setDocument(
      collectionPath: AppCollections.drivePdfImports,
      documentId: id,
      data: next,
    );
  }
}
