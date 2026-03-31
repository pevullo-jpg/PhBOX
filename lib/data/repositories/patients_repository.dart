import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/patient.dart';

class PatientsRepository {
  final FirestoreDatasource datasource;
  const PatientsRepository({required this.datasource});

  Future<void> savePatient(Patient patient) async {
    final existing = await getPatientByFiscalCode(patient.fiscalCode);
    final merged = existing == null ? patient : existing.copyWith(
      fullName: patient.fullName,
      city: patient.city ?? existing.city,
      exemption: patient.exemption ?? existing.exemption,
      exemptionCode: patient.exemptionCode ?? existing.exemptionCode,
      exemptions: patient.exemptions.isEmpty ? existing.exemptions : patient.exemptions,
      doctorName: patient.doctorName ?? existing.doctorName,
      doctorSurname: patient.doctorSurname ?? existing.doctorSurname,
      doctorFullName: patient.doctorFullName ?? existing.doctorFullName,
      therapiesSummary: patient.therapiesSummary.isEmpty ? existing.therapiesSummary : patient.therapiesSummary,
      lastPrescriptionDate: patient.lastPrescriptionDate ?? existing.lastPrescriptionDate,
      hasDebt: patient.hasDebt || existing.hasDebt,
      debtTotal: patient.debtTotal == 0 ? existing.debtTotal : patient.debtTotal,
      hasBooking: patient.hasBooking || existing.hasBooking,
      hasAdvance: patient.hasAdvance || existing.hasAdvance,
      hasDpc: patient.hasDpc || existing.hasDpc,
      archivedRecipeCount: patient.archivedRecipeCount == 0 ? existing.archivedRecipeCount : patient.archivedRecipeCount,
      recipesCount: patient.recipesCount == 0 ? existing.recipesCount : patient.recipesCount,
      activeDebtsCount: patient.activeDebtsCount == 0 ? existing.activeDebtsCount : patient.activeDebtsCount,
      activeBookingsCount: patient.activeBookingsCount == 0 ? existing.activeBookingsCount : patient.activeBookingsCount,
      activeAdvancesCount: patient.activeAdvancesCount == 0 ? existing.activeAdvancesCount : patient.activeAdvancesCount,
      totalDebtAmount: patient.totalDebtAmount == 0 ? existing.totalDebtAmount : patient.totalDebtAmount,
      advances: patient.advances.isEmpty ? existing.advances : patient.advances,
      bookings: patient.bookings.isEmpty ? existing.bookings : patient.bookings,
      debts: patient.debts.isEmpty ? existing.debts : patient.debts,
      recipes: patient.recipes.isEmpty ? existing.recipes : patient.recipes,
      createdAt: existing.createdAt,
      updatedAt: patient.updatedAt,
    );
    await datasource.setDocument(collectionPath: AppCollections.patients, documentId: patient.fiscalCode, data: merged.toMap());
  }

  Future<Patient?> getPatientByFiscalCode(String fiscalCode) async {
    final map = await datasource.getDocument(collectionPath: AppCollections.patients, documentId: fiscalCode);
    if (map == null) return null;
    return Patient.fromMap(map);
  }

  Future<List<Patient>> getAllPatients() async {
    final maps = await datasource.getCollection(collectionPath: AppCollections.patients, orderBy: 'fullName');
    return maps.map(Patient.fromMap).toList();
  }

  Future<void> deletePatient(String fiscalCode) => datasource.deleteDocument(collectionPath: AppCollections.patients, documentId: fiscalCode);
}
