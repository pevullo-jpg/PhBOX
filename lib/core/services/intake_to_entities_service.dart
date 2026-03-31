import '../../data/models/patient.dart';
import '../../data/models/prescription.dart';
import '../../data/models/prescription_intake.dart';
import '../../data/models/prescription_item.dart';
import '../../data/repositories/patients_repository.dart';
import '../../data/repositories/prescription_intakes_repository.dart';
import '../../data/repositories/prescriptions_repository.dart';

class IntakeImportResult {
  final int importedCount;
  final int skippedCount;
  final int errorCount;

  const IntakeImportResult({
    required this.importedCount,
    required this.skippedCount,
    required this.errorCount,
  });
}

class IntakeToEntitiesService {
  final PrescriptionIntakesRepository prescriptionIntakesRepository;
  final PatientsRepository patientsRepository;
  final PrescriptionsRepository prescriptionsRepository;

  const IntakeToEntitiesService({
    required this.prescriptionIntakesRepository,
    required this.patientsRepository,
    required this.prescriptionsRepository,
  });

  Future<IntakeImportResult> importAllPendingIntakes() async {
    final List<PrescriptionIntake> intakes =
        await prescriptionIntakesRepository.getAllIntakes();

    int imported = 0;
    int skipped = 0;
    int errors = 0;

    for (final PrescriptionIntake intake in intakes) {
      if (intake.status == 'imported') {
        skipped++;
        continue;
      }

      try {
        if (intake.fiscalCode.trim().isEmpty) {
          await prescriptionIntakesRepository.saveIntake(
            intake.copyWith(
              status: 'error',
              updatedAt: DateTime.now(),
              importErrorMessage: 'Codice fiscale mancante.',
            ),
          );
          errors++;
          continue;
        }

        final Patient? existing =
            await patientsRepository.getPatientByFiscalCode(intake.fiscalCode);

        final List<String> exemptions = Patient.normalizeExemptionValues(<dynamic>[
          ...(existing?.normalizedExemptions ?? const <String>[]),
          intake.exemptionCode,
        ]);
        final String? currentExemption = intake.exemptionCode.trim().isEmpty
            ? existing?.currentExemption
            : intake.exemptionCode.trim().toUpperCase();

        final Patient patient = Patient(
          fiscalCode: intake.fiscalCode,
          fullName: intake.patientName.isEmpty
              ? (existing?.fullName ?? 'Assistito senza nome')
              : intake.patientName,
          city: intake.city.isEmpty ? existing?.city : intake.city,
          doctorName:
              intake.doctorName.isEmpty ? existing?.doctorName : intake.doctorName,
          exemption: currentExemption,
          exemptionCode: currentExemption,
          exemptions: exemptions,
          archivedRecipeCount: (existing?.archivedRecipeCount ?? 0) + intake.prescriptionCount,
          hasDpc: (existing?.hasDpc ?? false) || intake.dpcFlag,
          hasAdvance: existing?.hasAdvance ?? false,
          hasDebt: existing?.hasDebt ?? false,
          hasBooking: existing?.hasBooking ?? false,
          debtTotal: existing?.debtTotal ?? 0,
          lastPrescriptionDate: intake.prescriptionDate,
          updatedAt: DateTime.now(),
          createdAt: existing?.createdAt ?? DateTime.now(),
        );

        await patientsRepository.savePatient(patient);

        final List<PrescriptionItem> items = intake.medicines.isEmpty
            ? <PrescriptionItem>[]
            : intake.medicines
                .map<PrescriptionItem>(
                  (String e) => PrescriptionItem(
                    drugName: e,
                    quantity: 1,
                  ),
                )
                .toList();

        final String prescriptionId =
            '${intake.fiscalCode}_${intake.driveFileId}';

        final DateTime now = DateTime.now();
        final DateTime prescriptionDate = intake.prescriptionDate ?? now;

        final Prescription prescription = Prescription(
          id: prescriptionId,
          patientFiscalCode: intake.fiscalCode,
          patientName: patient.fullName,
          doctorName:
              intake.doctorName.isEmpty ? patient.doctorName : intake.doctorName,
          exemptionCode: intake.exemptionCode.isEmpty
              ? patient.currentExemption
              : intake.exemptionCode.trim().toUpperCase(),
          city: intake.city.isEmpty ? patient.city : intake.city,
          prescriptionDate: prescriptionDate,
          expiryDate: _computeExpiryDate(prescriptionDate),
          dpcFlag: intake.dpcFlag,
          prescriptionCount: intake.prescriptionCount,
          sourceType: 'drive_import',
          extractedText: intake.rawText,
          items: items,
          createdAt: now,
          updatedAt: now,
        );

        await prescriptionsRepository.savePrescription(prescription);

        await prescriptionIntakesRepository.saveIntake(
          intake.copyWith(
            status: 'imported',
            updatedAt: DateTime.now(),
            importErrorMessage: '',
          ),
        );

        imported++;
      } catch (e) {
        await prescriptionIntakesRepository.saveIntake(
          intake.copyWith(
            status: 'error',
            updatedAt: DateTime.now(),
            importErrorMessage: '$e',
          ),
        );
        errors++;
      }
    }

    return IntakeImportResult(
      importedCount: imported,
      skippedCount: skipped,
      errorCount: errors,
    );
  }

  DateTime _computeExpiryDate(DateTime date) {
    return DateTime(date.year, date.month, date.day + 30);
  }
}
