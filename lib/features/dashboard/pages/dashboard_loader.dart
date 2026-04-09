part of 'dashboard_page.dart';

class _DashboardLoader {
  final PatientsRepository patientsRepository;
  final PrescriptionsRepository prescriptionsRepository;
  final AdvancesRepository advancesRepository;
  final DebtsRepository debtsRepository;
  final BookingsRepository bookingsRepository;
  final DrivePdfImportsRepository drivePdfImportsRepository;
  final DoctorPatientLinksRepository doctorPatientLinksRepository;
  final FamilyGroupsRepository familyGroupsRepository;

  const _DashboardLoader({
    required this.patientsRepository,
    required this.prescriptionsRepository,
    required this.advancesRepository,
    required this.debtsRepository,
    required this.bookingsRepository,
    required this.drivePdfImportsRepository,
    required this.doctorPatientLinksRepository,
    required this.familyGroupsRepository,
  });

  Future<_DashboardData> load() async {
    final results = await Future.wait<dynamic>([
      patientsRepository.getAllPatients(),
      drivePdfImportsRepository.getAllImports(),
      doctorPatientLinksRepository.getAllLinks(),
      familyGroupsRepository.getAllFamilies(),
      prescriptionsRepository.getAllStoredPrescriptions(),
      debtsRepository.getAllDebts(),
      advancesRepository.getAllAdvances(),
      bookingsRepository.getAllBookings(),
    ]);

    final patients = results[0] as List<Patient>;
    final imports = results[1] as List<DrivePdfImport>;
    final doctorLinks = results[2] as List<DoctorPatientLink>;
    final families = results[3] as List<FamilyGroup>;
    final prescriptions = results[4] as List<Prescription>;
    final debts = results[5] as List<Debt>;
    final advances = results[6] as List<Advance>;
    final bookings = results[7] as List<Booking>;

    final importsByFiscalCode = <String, List<DrivePdfImport>>{};
    final importsByFullNameWithoutFiscalCode = <String, List<DrivePdfImport>>{};
    for (final item in imports) {
      final normalizedFiscalCode = item.patientFiscalCode.trim().toUpperCase();
      final normalizedFullName = item.patientFullName.trim().toUpperCase();
      final notDeleted = item.pdfDeleted != true && item.status.trim().toLowerCase() != 'deleted_pdf';
      if (!notDeleted) {
        continue;
      }
      if (normalizedFiscalCode.isNotEmpty) {
        (importsByFiscalCode[normalizedFiscalCode] ??= <DrivePdfImport>[]).add(item);
        continue;
      }
      if (normalizedFullName.isNotEmpty) {
        (importsByFullNameWithoutFiscalCode[normalizedFullName] ??= <DrivePdfImport>[]).add(item);
      }
    }

    final doctorLinksByFiscalCode = _groupByFiscalCode<DoctorPatientLink>(
      doctorLinks,
      (item) => item.patientFiscalCode,
    );
    final prescriptionsByFiscalCode = _groupByFiscalCode<Prescription>(
      prescriptions,
      (item) => item.patientFiscalCode,
    );
    final debtsByFiscalCode = _groupByFiscalCode<Debt>(
      debts,
      (item) => item.patientFiscalCode,
    );
    final advancesByFiscalCode = _groupByFiscalCode<Advance>(
      advances,
      (item) => item.patientFiscalCode,
    );
    final bookingsByFiscalCode = _groupByFiscalCode<Booking>(
      bookings,
      (item) => item.patientFiscalCode,
    );

    final familyIdByFiscalCode = <String, String>{};
    for (final family in families) {
      for (final fiscalCode in family.memberFiscalCodes) {
        final normalized = fiscalCode.trim().toUpperCase();
        if (normalized.isEmpty) {
          continue;
        }
        familyIdByFiscalCode[normalized] = family.id;
      }
    }

    final summaries = patients.map((patient) {
      final normalizedFiscalCode = patient.fiscalCode.trim().toUpperCase();
      final normalizedFullName = patient.fullName.trim().toUpperCase();
      final matchingImports = <DrivePdfImport>[
        ...(importsByFiscalCode[normalizedFiscalCode] ?? const <DrivePdfImport>[]),
        ...(normalizedFullName.isEmpty
            ? const <DrivePdfImport>[]
            : (importsByFullNameWithoutFiscalCode[normalizedFullName] ?? const <DrivePdfImport>[])),
      ];
      final uniqueImports = <String, DrivePdfImport>{
        for (final item in matchingImports) item.id: item,
      }.values.toList();
      uniqueImports.sort((a, b) {
        final aDate = a.prescriptionDate ?? a.createdAt;
        final bDate = b.prescriptionDate ?? b.createdAt;
        return bDate.compareTo(aDate);
      });
      return _PatientDashboardSummary.build(
        patient: patient,
        prescriptions: prescriptionsByFiscalCode[normalizedFiscalCode] ?? const <Prescription>[],
        imports: uniqueImports,
        debts: debtsByFiscalCode[normalizedFiscalCode] ?? const <Debt>[],
        advances: advancesByFiscalCode[normalizedFiscalCode] ?? const <Advance>[],
        bookings: bookingsByFiscalCode[normalizedFiscalCode] ?? const <Booking>[],
        doctorLinks: doctorLinksByFiscalCode[normalizedFiscalCode] ?? const <DoctorPatientLink>[],
        familyId: familyIdByFiscalCode[normalizedFiscalCode] ?? '',
      );
    }).toList();

    summaries.sort((a, b) {
      if (a.hasExpiryAlert != b.hasExpiryAlert) {
        return a.hasExpiryAlert ? -1 : 1;
      }
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });

    return _DashboardData(
      summaries: summaries,
      families: families,
    );
  }

  Map<String, List<T>> _groupByFiscalCode<T>(
    List<T> items,
    String Function(T item) fiscalCodeReader,
  ) {
    final grouped = <String, List<T>>{};
    for (final item in items) {
      final normalized = fiscalCodeReader(item).trim().toUpperCase();
      if (normalized.isEmpty) {
        continue;
      }
      (grouped[normalized] ??= <T>[]).add(item);
    }
    return grouped;
  }
}
