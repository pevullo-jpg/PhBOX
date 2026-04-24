import 'dart:convert';

import '../../data/models/advance.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/booking.dart';
import '../../data/models/debt.dart';
import '../../data/models/doctor_patient_link.dart';
import '../../data/models/drive_pdf_import.dart';
import '../../data/models/family_group.dart';
import '../../data/models/patient.dart';
import '../../data/models/prescription.dart';
import '../../data/models/therapeutic_advice_note.dart';
import '../../data/repositories/advances_repository.dart';
import '../../data/repositories/bookings_repository.dart';
import '../../data/repositories/debts_repository.dart';
import '../../data/repositories/doctor_patient_links_repository.dart';
import '../../data/repositories/drive_pdf_imports_repository.dart';
import '../../data/repositories/family_groups_repository.dart';
import '../../data/repositories/patients_repository.dart';
import '../../data/repositories/prescriptions_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/therapeutic_advice_repository.dart';
import '../utils/file_download.dart';

class BackupExportService {
  final SettingsRepository settingsRepository;
  final PatientsRepository patientsRepository;
  final FamilyGroupsRepository familyGroupsRepository;
  final DoctorPatientLinksRepository doctorPatientLinksRepository;
  final PrescriptionsRepository prescriptionsRepository;
  final DrivePdfImportsRepository drivePdfImportsRepository;
  final DebtsRepository debtsRepository;
  final AdvancesRepository advancesRepository;
  final BookingsRepository bookingsRepository;
  final TherapeuticAdviceRepository therapeuticAdviceRepository;

  const BackupExportService({
    required this.settingsRepository,
    required this.patientsRepository,
    required this.familyGroupsRepository,
    required this.doctorPatientLinksRepository,
    required this.prescriptionsRepository,
    required this.drivePdfImportsRepository,
    required this.debtsRepository,
    required this.advancesRepository,
    required this.bookingsRepository,
    required this.therapeuticAdviceRepository,
  });

  Future<String> exportCurrentSnapshot() async {
    final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
      settingsRepository.getSettings(),
      patientsRepository.getAllPatients(),
      familyGroupsRepository.getAllFamilies(),
      doctorPatientLinksRepository.getAllLinks(),
      prescriptionsRepository.getAllLegacyPrescriptions(),
      drivePdfImportsRepository.getAllImports(includeHidden: true),
      debtsRepository.getAllDebts(),
      advancesRepository.getAllAdvances(),
      bookingsRepository.getAllBookings(),
      therapeuticAdviceRepository.getAllNotes(),
    ]);

    final AppSettings settings = results[0] as AppSettings;
    final List<Patient> patients = results[1] as List<Patient>;
    final List<FamilyGroup> families = results[2] as List<FamilyGroup>;
    final List<DoctorPatientLink> doctorLinks = results[3] as List<DoctorPatientLink>;
    final List<Prescription> prescriptions = results[4] as List<Prescription>;
    final List<DrivePdfImport> imports = results[5] as List<DrivePdfImport>;
    final List<Debt> debts = results[6] as List<Debt>;
    final List<Advance> advances = results[7] as List<Advance>;
    final List<Booking> bookings = results[8] as List<Booking>;
    final List<TherapeuticAdviceNote> therapeuticAdviceNotes = results[9] as List<TherapeuticAdviceNote>;

    final DateTime now = DateTime.now();
    final Map<String, dynamic> payload = <String, dynamic>{
      'exportedAt': now.toIso8601String(),
      'source': 'PhBOX frontend backup',
      'schemaVersion': 1,
      'collections': <String, dynamic>{
        'app_settings': settings.toFrontendPatchMap(),
        'patients': patients.map((Patient item) => _patientToMap(item)).toList(),
        'families': families.map((FamilyGroup item) => item.toMap()).toList(),
        'doctor_patient_links': doctorLinks.map((DoctorPatientLink item) => _doctorLinkToMap(item)).toList(),
        'prescriptions': prescriptions.map((Prescription item) => item.toMap()).toList(),
        'drive_pdf_imports': imports.map((DrivePdfImport item) => item.toMap()).toList(),
        'debts': debts.map((Debt item) => item.toMap()).toList(),
        'advances': advances.map((Advance item) => item.toMap()).toList(),
        'bookings': bookings.map((Booking item) => item.toMap()).toList(),
        'patient_therapeutic_advice': therapeuticAdviceNotes.map((TherapeuticAdviceNote item) => item.toMap()).toList(),
      },
      'counts': <String, int>{
        'patients': patients.length,
        'families': families.length,
        'doctor_patient_links': doctorLinks.length,
        'prescriptions': prescriptions.length,
        'drive_pdf_imports': imports.length,
        'debts': debts.length,
        'advances': advances.length,
        'bookings': bookings.length,
        'patient_therapeutic_advice': therapeuticAdviceNotes.length,
      },
    };

    final String filename = _buildFileName(now);
    final String content = const JsonEncoder.withIndent('  ').convert(payload);
    await downloadTextFile(filename: filename, content: content);
    return filename;
  }



  Map<String, dynamic> _patientToMap(Patient item) {
    return <String, dynamic>{
      'fiscalCode': item.fiscalCode,
      'fullName': item.fullName,
      'alias': item.alias,
      'city': item.city,
      'exemptionCode': item.exemptionCode,
      'exemptions': item.exemptions,
      'doctorName': item.doctorName,
      'doctorFullName': item.doctorFullName,
      'therapiesSummary': item.therapiesSummary,
      'lastPrescriptionDate': item.lastPrescriptionDate?.toIso8601String(),
      'hasDebt': item.hasDebt,
      'debtTotal': item.debtTotal,
      'hasBooking': item.hasBooking,
      'hasAdvance': item.hasAdvance,
      'hasDpc': item.hasDpc,
      'archivedRecipeCount': item.archivedRecipeCount,
      'archivedPdfCount': item.archivedPdfCount,
      'activeArchiveDocuments': item.activeArchiveDocuments,
      'createdAt': item.createdAt.toIso8601String(),
      'updatedAt': item.updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _doctorLinkToMap(DoctorPatientLink item) {
    return <String, dynamic>{
      'id': item.id,
      'patientFiscalCode': item.patientFiscalCode,
      'doctorName': item.doctorName,
      'doctorFullName': item.doctorFullName,
      'doctorSurname': item.doctorSurname,
      'updatedAt': item.updatedAt?.toIso8601String(),
    };
  }

  String _buildFileName(DateTime now) {
    final String y = now.year.toString().padLeft(4, '0');
    final String m = now.month.toString().padLeft(2, '0');
    final String d = now.day.toString().padLeft(2, '0');
    final String hh = now.hour.toString().padLeft(2, '0');
    final String mm = now.minute.toString().padLeft(2, '0');
    final String ss = now.second.toString().padLeft(2, '0');
    return 'phbox_backup_${y}${m}${d}_${hh}${mm}${ss}.json';
  }
}
