import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/patient.dart';

class PatientsRepository {
  final FirestoreDatasource datasource;

  const PatientsRepository({required this.datasource});

  Future<void> createManualPatient(Patient patient) async {
    final Map<String, dynamic>? existing = await datasource.getDocument(
      collectionPath: AppCollections.patients,
      documentId: patient.fiscalCode,
    );
    if (existing != null) {
      return;
    }
    await datasource.setDocument(
      collectionPath: AppCollections.patients,
      documentId: patient.fiscalCode,
      data: patient.toManualCreateMap(),
    );
  }

  Future<Patient?> getPatientByFiscalCode(String fiscalCode) async {
    final Map<String, dynamic>? map = await datasource.getDocument(
      collectionPath: AppCollections.patients,
      documentId: fiscalCode,
    );
    if (map == null) return null;
    return Patient.fromMap(map);
  }

  Future<List<Patient>> getAllPatients() async {
    final List<Map<String, dynamic>> maps = await datasource.getCollection(
      collectionPath: AppCollections.patients,
      orderBy: 'fullName',
    );
    return maps.map(Patient.fromMap).toList();
  }

  Future<void> deletePatient(String fiscalCode) {
    return datasource.deleteDocument(
      collectionPath: AppCollections.patients,
      documentId: fiscalCode,
    );
  }
}
