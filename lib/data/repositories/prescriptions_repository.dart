import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/drive_pdf_import.dart';
import '../models/patient.dart';
import '../models/prescription.dart';
import '../models/prescription_item.dart';
import 'patients_repository.dart';
import 'drive_pdf_imports_repository.dart';

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

    if (maps.isNotEmpty) {
      return maps.map(Prescription.fromMap).toList();
    }

    final DrivePdfImportsRepository importsRepository =
        DrivePdfImportsRepository(datasource: datasource);
    final List<DrivePdfImport> imports =
        await importsRepository.getImportsByPatient(fiscalCode);
    return imports.map(_importToPrescription).toList();
  }


  Future<List<Prescription>> getAllStoredPrescriptions() async {
    final List<Map<String, dynamic>> maps = await datasource.getCollectionGroup(
      collectionPath: AppCollections.prescriptions,
    );
    final prescriptions = maps.map(Prescription.fromMap).where((item) => item.patientFiscalCode.trim().isNotEmpty).toList();
    prescriptions.sort((a, b) => b.prescriptionDate.compareTo(a.prescriptionDate));
    return prescriptions;
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

  Prescription _importToPrescription(DrivePdfImport item) {
    final DateTime prescriptionDate = item.prescriptionDate ?? item.createdAt;
    return Prescription(
      id: item.id,
      patientFiscalCode: item.patientFiscalCode,
      patientName: item.patientFullName,
      prescriptionDate: prescriptionDate,
      expiryDate: prescriptionDate.add(const Duration(days: 30)),
      doctorName: item.doctorFullName.isEmpty ? null : item.doctorFullName,
      exemptionCode: item.exemptionCode.isEmpty ? null : item.exemptionCode,
      city: item.city.isEmpty ? null : item.city,
      dpcFlag: item.isDpc,
      prescriptionCount: item.prescriptionCount,
      sourceType: item.sourceType,
      extractedText: null,
      items: item.therapy
          .where((String value) => value.trim().isNotEmpty)
          .map((String value) => PrescriptionItem(drugName: value.trim()))
          .toList(),
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    );
  }


  Future<void> deletePrescription(String fiscalCode, String prescriptionId) async {
    await datasource.deleteSubDocument(
      collectionPath: AppCollections.patients,
      documentId: fiscalCode,
      subcollectionPath: AppCollections.prescriptions,
      subDocumentId: prescriptionId,
    );
    await refreshPatientAggregates(fiscalCode);
  }

  Future<void> deleteAllPatientPrescriptions(String fiscalCode) async {
    final List<Prescription> prescriptions = await getPatientPrescriptions(fiscalCode);
    for (final Prescription prescription in prescriptions) {
      try {
        await datasource.deleteSubDocument(
          collectionPath: AppCollections.patients,
          documentId: fiscalCode,
          subcollectionPath: AppCollections.prescriptions,
          subDocumentId: prescription.id,
        );
      } catch (_) {}
    }
    await refreshPatientAggregates(fiscalCode);
  }
}
