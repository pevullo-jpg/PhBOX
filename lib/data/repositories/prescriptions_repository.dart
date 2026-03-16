import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/patient.dart';
import '../models/prescription.dart';
import 'patients_repository.dart';

class PrescriptionsRepository {
  final FirestoreDatasource datasource;
  final PatientsRepository patientsRepository;

  const PrescriptionsRepository({
    required this.datasource,
    required this.patientsRepository,
  });

  Future<void> savePrescription(Prescription prescription) async {
    await datasource.setSubDocument(
      collectionPath: AppCollections.patients,
      documentId: prescription.patientFiscalCode,
      subcollectionPath: AppCollections.prescriptions,
      subDocumentId: prescription.id,
      data: prescription.toMap(),
    );

    await refreshPatientAggregates(prescription.patientFiscalCode);
  }

  Future<List<Prescription>> getPatientPrescriptions(String fiscalCode) async {
    final List<Map<String, dynamic>> maps = await datasource.getSubCollection(
      collectionPath: AppCollections.patients,
      documentId: fiscalCode,
      subcollectionPath: AppCollections.prescriptions,
      orderBy: 'prescriptionDate',
      descending: true,
    );
    return maps.map(Prescription.fromMap).toList();
  }

  Future<void> refreshPatientAggregates(String fiscalCode) async {
    final Patient? patient = await patientsRepository.getPatientByFiscalCode(fiscalCode);
    if (patient == null) return;

    final List<Prescription> prescriptions = await getPatientPrescriptions(fiscalCode);

    final int archivedRecipeCount = prescriptions.fold<int>(0, (int sum, Prescription prescription) => sum + prescription.prescriptionCount);

    DateTime? lastPrescriptionDate;
    bool hasDpc = false;
    final Set<String> therapies = <String>{};

    for (final Prescription prescription in prescriptions) {
      if (lastPrescriptionDate == null ||
          prescription.prescriptionDate.isAfter(lastPrescriptionDate)) {
        lastPrescriptionDate = prescription.prescriptionDate;
      }

      if (prescription.dpcFlag) {
        hasDpc = true;
      }

      for (final item in prescription.items) {
        final String drug = item.drugName.trim();
        if (drug.isNotEmpty) {
          therapies.add(drug);
        }
      }
    }

    final Patient updated = patient.copyWith(
      archivedRecipeCount: archivedRecipeCount,
      lastPrescriptionDate: lastPrescriptionDate,
      hasDpc: hasDpc,
      therapiesSummary: therapies.toList()..sort(),
      updatedAt: DateTime.now(),
    );

    await patientsRepository.savePatient(updated);
  }
}
