import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/drive_pdf_import.dart';

class DrivePdfImportsRepository {
  final FirestoreDatasource datasource;

  const DrivePdfImportsRepository({required this.datasource});

  Future<void> saveImport(DrivePdfImport import) {
    return datasource.setDocument(
      collectionPath: AppCollections.drivePdfImports,
      documentId: import.id,
      data: import.toMap(),
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
}
