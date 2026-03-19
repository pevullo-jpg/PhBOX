import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/doctor_patient_link.dart';

class DoctorPatientLinksRepository {
  final FirestoreDatasource datasource;

  const DoctorPatientLinksRepository({required this.datasource});

  Future<List<DoctorPatientLink>> getAllLinks() async {
    final List<Map<String, dynamic>> maps = await datasource.getCollection(
      collectionPath: AppCollections.doctorPatientLinks,
      orderBy: 'updatedAt',
      descending: true,
    );
    return maps.map(DoctorPatientLink.fromMap).where((DoctorPatientLink item) {
      return item.patientFiscalCode.isNotEmpty && item.doctorName.isNotEmpty;
    }).toList();
  }

  Future<String?> getDoctorForPatient(String fiscalCode) async {
    final String normalized = fiscalCode.trim().toUpperCase();
    final List<DoctorPatientLink> links = await getAllLinks();
    for (final DoctorPatientLink link in links) {
      if (link.patientFiscalCode == normalized) {
        return link.doctorName;
      }
    }
    return null;
  }
}
