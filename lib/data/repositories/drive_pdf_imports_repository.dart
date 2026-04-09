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

  Future<List<DrivePdfImport>> getAllImports({bool includeHidden = false}) async {
    final List<Map<String, dynamic>> maps = await datasource.getCollection(
      collectionPath: AppCollections.drivePdfImports,
    );
    final List<DrivePdfImport> items = maps
        .map(DrivePdfImport.fromMap)
        .where((DrivePdfImport item) {
      final bool hasPatientIdentity =
          item.patientFiscalCode.trim().isNotEmpty || item.patientFullName.trim().isNotEmpty;
      if (!hasPatientIdentity) {
        return false;
      }
      if (!includeHidden && item.isHiddenFromFrontend) {
        return false;
      }
      return true;
    }).toList();
    items.sort((DrivePdfImport a, DrivePdfImport b) {
      return b.chronologyDate.compareTo(a.chronologyDate);
    });
    return items;
  }

  Future<List<DrivePdfImport>> getImportsByPatient(
    String fiscalCode, {
    bool includeHidden = false,
  }) async {
    final String normalized = fiscalCode.trim().toUpperCase();
    final List<DrivePdfImport> all = await getAllImports(includeHidden: includeHidden);
    final List<DrivePdfImport> filtered = all.where((DrivePdfImport item) {
      return item.patientFiscalCode.trim().toUpperCase() == normalized;
    }).toList();
    filtered.sort((DrivePdfImport a, DrivePdfImport b) {
      return b.chronologyDate.compareTo(a.chronologyDate);
    });
    return filtered;
  }

  Future<void> requestPdfDelete(String id) {
    return datasource.patchDocument(
      collectionPath: AppCollections.drivePdfImports,
      documentId: id,
      data: <String, dynamic>{
        'deletePdfRequested': true,
        'deleteRequestedAt': DateTime.now().toIso8601String(),
        'deleteRequestedBy': 'frontend',
      },
    );
  }
}
