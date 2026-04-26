import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/drive_pdf_import.dart';
import 'runtime_signal_repository.dart';

class DrivePdfImportsRepository {
  final FirestoreDatasource datasource;

  const DrivePdfImportsRepository({required this.datasource});

  RuntimeSignalRepository get _runtimeSignals => RuntimeSignalRepository(datasource: datasource);

  Future<void> saveImport(DrivePdfImport importItem) {
    throw UnsupportedError(
      'Frontend baseline v1.1.2: drive_pdf_imports è backend-owned. '
      'Il frontend non può più scrivere documenti archivistici.',
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
    if (normalized.isEmpty) {
      return const <DrivePdfImport>[];
    }

    final List<Map<String, dynamic>> maps = await datasource.getCollectionWhereEqual(
      collectionPath: AppCollections.drivePdfImports,
      field: 'patientFiscalCode',
      value: normalized,
    );
    List<DrivePdfImport> filtered = maps
        .map(DrivePdfImport.fromMap)
        .where((DrivePdfImport item) {
      if (!includeHidden && item.isHiddenFromFrontend) {
        return false;
      }
      return item.patientFiscalCode.trim().toUpperCase() == normalized;
    }).toList();

    filtered.sort((DrivePdfImport a, DrivePdfImport b) {
      return b.chronologyDate.compareTo(a.chronologyDate);
    });
    return filtered;
  }

  Future<void> requestPdfDelete(String id, {String? fiscalCode}) async {
    await datasource.patchDocument(
      collectionPath: AppCollections.drivePdfImports,
      documentId: id,
      data: <String, dynamic>{
        'deletePdfRequested': true,
        'deleteRequestedAt': DateTime.now().toIso8601String(),
        'deleteRequestedBy': 'frontend',
      },
    );

    await _runtimeSignals.emitBestEffort(
      domain: 'deletePdf',
      operation: 'delete',
      targetPath: 'drive_pdf_imports/$id',
      targetFiscalCode: fiscalCode ?? '',
      targetDocumentId: id,
      requiresTotalsUpdate: true,
      requiresIndexUpdate: true,
    );
  }
}
