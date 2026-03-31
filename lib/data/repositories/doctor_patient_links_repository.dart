import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/doctor_patient_link.dart';

class DoctorPatientLinksRepository {
  final FirestoreDatasource datasource;

  const DoctorPatientLinksRepository({required this.datasource});

  Future<List<DoctorPatientLink>> getAllLinks() async {
    final List<Map<String, dynamic>> maps = await datasource.getCollection(
      collectionPath: AppCollections.doctorPatientLinks,
    );
    return maps.map(DoctorPatientLink.fromMap).where((DoctorPatientLink item) {
      return item.patientFiscalCode.isNotEmpty && item.doctorFullName.isNotEmpty;
    }).toList();
  }



  Future<void> saveLink({
    required String patientFiscalCode,
    required String patientFullName,
    required String doctorFullName,
    String? city,
  }) {
    final String normalizedCf = patientFiscalCode.trim().toUpperCase();
    final String normalizedDoctor = doctorFullName.trim();
    final List<String> parts = normalizedDoctor.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final String doctorSurname = parts.isEmpty ? normalizedDoctor : parts.last;
    final String doctorGivenName = parts.length > 1 ? parts.sublist(0, parts.length - 1).join(' ') : normalizedDoctor;
    final DateTime now = DateTime.now();
    final String safeDoctor = normalizedDoctor.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '_').replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
    final String documentId = '${normalizedCf}_${safeDoctor.isEmpty ? 'NO_DOCTOR' : safeDoctor}';
    return datasource.setDocument(
      collectionPath: AppCollections.doctorPatientLinks,
      documentId: documentId,
      data: <String, dynamic>{
        'id': documentId,
        'patientFiscalCode': normalizedCf,
        'patientFullName': patientFullName.trim(),
        'doctorFullName': normalizedDoctor,
        'doctorSurname': doctorSurname,
        'doctorName': doctorGivenName,
        'city': city?.trim(),
        'updatedAt': now.toIso8601String(),
      },
    );
  }

  Future<String?> getDoctorForPatient(String fiscalCode) async {
    final String normalized = fiscalCode.trim().toUpperCase();
    final List<DoctorPatientLink> links = await getAllLinks();
    for (final DoctorPatientLink link in links) {
      if (link.patientFiscalCode == normalized) {
        return link.doctorFullName;
      }
    }
    return null;
  }
}
