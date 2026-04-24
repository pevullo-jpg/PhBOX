import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/prescription_intake.dart';

class PrescriptionIntakesRepository {
  final FirestoreDatasource datasource;

  const PrescriptionIntakesRepository({required this.datasource});

  Future<void> saveIntake(PrescriptionIntake intake) {
    return datasource.setDocument(
      collectionPath: AppCollections.prescriptionIntakes,
      documentId: intake.id,
      data: intake.toMap(),
    );
  }

  Future<List<PrescriptionIntake>> getAllIntakes() async {
    final List<Map<String, dynamic>> maps = await datasource.getCollection(
      collectionPath: AppCollections.prescriptionIntakes,
      orderBy: 'updatedAt',
      descending: true,
    );
    return maps.map(PrescriptionIntake.fromMap).toList();
  }
}
