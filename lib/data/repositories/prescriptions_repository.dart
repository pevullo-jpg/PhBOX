import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/drive_pdf_import.dart';
import '../models/prescription.dart';
import '../models/prescription_item.dart';
import 'drive_pdf_imports_repository.dart';

class PrescriptionsRepository {
  final FirestoreDatasource datasource;

  const PrescriptionsRepository({required this.datasource});

  Future<void> savePrescription(Prescription prescription) {
    return datasource.setSubDocument(
      collectionPath: AppCollections.patients,
      documentId: prescription.patientFiscalCode,
      subcollectionPath: AppCollections.prescriptions,
      subDocumentId: prescription.id,
      data: prescription.toMap(),
    );
  }

  Future<List<Prescription>> getAllLegacyPrescriptions() async {
    final List<Map<String, dynamic>> maps = await datasource.getCollectionGroup(
      collectionPath: AppCollections.prescriptions,
    );
    final List<Prescription> items = maps.map(Prescription.fromMap).toList();
    items.sort((Prescription a, Prescription b) {
      return b.prescriptionDate.compareTo(a.prescriptionDate);
    });
    return items;
  }

  Future<List<Prescription>> getLegacyPatientPrescriptions(String fiscalCode) async {
    final List<Map<String, dynamic>> maps = await datasource.getSubCollection(
      collectionPath: AppCollections.patients,
      documentId: fiscalCode,
      subcollectionPath: AppCollections.prescriptions,
    );
    final List<Prescription> items = maps.map(Prescription.fromMap).toList();
    items.sort((Prescription a, Prescription b) {
      return b.prescriptionDate.compareTo(a.prescriptionDate);
    });
    return items;
  }

  Future<List<Prescription>> getPatientPrescriptions(String fiscalCode) async {
    final DrivePdfImportsRepository importsRepository =
        DrivePdfImportsRepository(datasource: datasource);
    final List<DrivePdfImport> allImports = await importsRepository.getImportsByPatient(
      fiscalCode,
      includeHidden: true,
    );
    final List<DrivePdfImport> visibleImports = allImports.where((DrivePdfImport item) {
      return !item.isHiddenFromFrontend;
    }).toList();
    if (allImports.isNotEmpty) {
      return visibleImports.map(_importToPrescription).toList();
    }
    return getLegacyPatientPrescriptions(fiscalCode);
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
}
