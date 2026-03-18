import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/datasources/firestore_firebase_datasource.dart';
import '../../../data/demo/demo_advances.dart';
import '../../../data/demo/demo_bookings.dart';
import '../../../data/demo/demo_debts.dart';
import '../../../data/demo/demo_patients.dart';
import '../../../data/demo/demo_prescriptions.dart';
import '../../../data/models/advance.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/debt.dart';
import '../../../data/models/drive_pdf_import.dart';
import '../../../data/models/patient.dart';
import '../../../data/models/prescription.dart';
import '../../../data/repositories/advances_repository.dart';
import '../../../data/repositories/bookings_repository.dart';
import '../../../data/repositories/debts_repository.dart';
import '../../../data/repositories/drive_pdf_imports_repository.dart';
import '../../../data/repositories/patients_repository.dart';
import '../../../data/repositories/prescriptions_repository.dart';
import '../../../shared/widgets/filter_chip_widget.dart';
import '../../../shared/widgets/header_bar.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/table_header.dart';
import '../../../theme/app_theme.dart';
import '../../patients/pages/patient_detail_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final TextEditingController searchController = TextEditingController();

  bool filterDpc = false;
  bool filterRicette = false;
  bool filterAnticipi = false;
  bool filterDebiti = false;
  bool filterPrenotazioni = false;
  bool isSeeding = false;
  String seedMessage = '';

  late final PatientsRepository patientsRepository;
  late final AdvancesRepository advancesRepository;
  late final DebtsRepository debtsRepository;
  late final BookingsRepository bookingsRepository;
  late final PrescriptionsRepository prescriptionsRepository;
  late final DrivePdfImportsRepository drivePdfImportsRepository;

  @override
  void initState() {
    super.initState();
    final FirestoreFirebaseDatasource datasource =
        FirestoreFirebaseDatasource(FirebaseFirestore.instance);

    patientsRepository = PatientsRepository(datasource: datasource);
    advancesRepository = AdvancesRepository(datasource: datasource);
    debtsRepository = DebtsRepository(datasource: datasource);
    bookingsRepository = BookingsRepository(datasource: datasource);
    prescriptionsRepository = PrescriptionsRepository(
      datasource: datasource,
      patientsRepository: patientsRepository,
    );
    drivePdfImportsRepository = DrivePdfImportsRepository(datasource: datasource);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<Patient> applyFilters(List<Patient> patients) {
    final String query = searchController.text.trim().toLowerCase();

    return patients.where((Patient p) {
      if (filterDpc && !p.hasDpc) return false;
      if (filterRicette && p.archivedRecipeCount == 0) return false;
      if (filterAnticipi && !p.hasAdvance) return false;
      if (filterDebiti && !p.hasDebt) return false;
      if (filterPrenotazioni && !p.hasBooking) return false;
      if (query.isEmpty) return true;

      return p.fullName.toLowerCase().contains(query) ||
          p.fiscalCode.toLowerCase().contains(query) ||
          (p.city ?? '').toLowerCase().contains(query) ||
          (p.doctorName ?? '').toLowerCase().contains(query);
    }).toList();
  }

  Future<void> seedAll() async {
    setState(() {
      isSeeding = true;
      seedMessage = '';
    });

    try {
      for (final Patient patient in demoPatients) {
        await patientsRepository.savePatient(patient);
      }
      for (final Advance advance in demoAdvances) {
        await advancesRepository.saveAdvance(advance);
      }
      for (final Debt debt in demoDebts) {
        await debtsRepository.saveDebt(debt);
      }
      for (final Booking booking in demoBookings) {
        await bookingsRepository.saveBooking(booking);
      }
      for (final Prescription prescription in demoPrescriptions) {
        await prescriptionsRepository.savePrescription(prescription);
      }

      setState(() {
        seedMessage =
            'Seed completo: patients + subcollections + prescriptions caricati.';
      });
    } catch (e) {
      setState(() {
        seedMessage = 'Errore seed: $e';
      });
    } finally {
      setState(() {
        isSeeding = false;
      });
    }
  }

  void openPatientDetail(Patient patient) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PatientDetailPage(fiscalCode: patient.fiscalCode),
      ),
    );
  }

  Future<void> _openDrivePdf(DrivePdfImport item) async {
    final String url = item.webViewLink.isNotEmpty
        ? item.webViewLink
        : 'https://drive.google.com/file/d/${item.driveFileId}/view';
    final Uri uri = Uri.parse(url);
    await launchUrl(uri, webOnlyWindowName: '_blank');
  }

  Future<void> _openPatientPdfFiles(
    Patient patient,
    List<DrivePdfImport> imports,
  ) async {
    final List<DrivePdfImport> matching = imports.where((DrivePdfImport item) {
      final String importFiscal = item.patientFiscalCode.trim().toUpperCase();
      final String patientFiscal = patient.fiscalCode.trim().toUpperCase();
      if (importFiscal.isNotEmpty && patientFiscal.isNotEmpty && importFiscal == patientFiscal) {
        return true;
      }
      return _sameLooseName(item.patientFullName, patient.fullName);
    }).toList();

    if (matching.isEmpty) return;
    if (matching.length == 1) {
      await _openDrivePdf(matching.first);
      return;
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.panel,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'PDF di ${patient.fullName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                ...matching.map((DrivePdfImport item) {
                  final DateTime? date = item.prescriptionDate;
                  final String dateLabel = date == null
                      ? 'data non disponibile'
                      : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.picture_as_pdf, color: AppColors.coral),
                    title: Text(item.fileName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    subtitle: Text(dateLabel, style: const TextStyle(color: Colors.white70)),
                    trailing: TextButton(
                      onPressed: () => _openDrivePdf(item),
                      child: const Text('Apri'),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _sameLooseName(String a, String b) {
    final String left = a.toUpperCase().replaceAll(RegExp(r'[^A-ZÀ-ÖØ-Ý]'), '');
    final String right = b.toUpperCase().replaceAll(RegExp(r'[^A-ZÀ-ÖØ-Ý]'), '');
    return left.isNotEmpty && left == right;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DashboardData>(
      future: _loadDashboardData(),
      builder: (BuildContext context, AsyncSnapshot<_DashboardData> snapshot) {
        final List<Patient> patients = snapshot.data?.patients ?? const <Patient>[];
        final List<DrivePdfImport> allImports = snapshot.data?.imports ?? const <DrivePdfImport>[];
        final List<Patient> filteredPatients = applyFilters(patients);
        final double totalDebts =
            patients.fold<double>(0, (double sum, Patient p) => sum + p.debtTotal);
        final int totalRecipes =
            patients.fold<int>(0, (int sum, Patient p) => sum + p.archivedRecipeCount);
        final int totalDpc = patients.where((Patient p) => p.hasDpc).length;
        final int totalAdvances =
            patients.where((Patient p) => p.hasAdvance).length;
        final int totalBookings =
            patients.where((Patient p) => p.hasBooking).length;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: <Widget>[
              HeaderBar(
                title: 'Dashboard operativa farmacia',
                searchController: searchController,
                onChanged: (_) => setState(() {}),
              ),
              Expanded(
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : snapshot.hasError
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'Errore Firestore: ${snapshot.error}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 16,
                                  children: <Widget>[
                                    StatCard(title: 'Assistiti', value: '${patients.length}', color: AppColors.green),
                                    StatCard(title: 'Ricette archiviate', value: '$totalRecipes', color: AppColors.coral),
                                    StatCard(title: 'Debito totale', value: '€ ${totalDebts.toStringAsFixed(2)}', color: AppColors.wine),
                                    StatCard(title: 'DPC', value: '$totalDpc', color: AppColors.amber),
                                    StatCard(title: 'Anticipi', value: '$totalAdvances', color: AppColors.yellow),
                                    StatCard(title: 'Prenotazioni', value: '$totalBookings', color: AppColors.coral),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: <Widget>[
                                    FilterChipWidget(
                                      label: 'Solo DPC',
                                      selected: filterDpc,
                                      onTap: () => setState(() => filterDpc = !filterDpc),
                                    ),
                                    FilterChipWidget(
                                      label: 'Con ricette',
                                      selected: filterRicette,
                                      onTap: () => setState(() => filterRicette = !filterRicette),
                                    ),
                                    FilterChipWidget(
                                      label: 'Con debiti',
                                      selected: filterDebiti,
                                      onTap: () => setState(() => filterDebiti = !filterDebiti),
                                    ),
                                    FilterChipWidget(
                                      label: 'Con anticipi',
                                      selected: filterAnticipi,
                                      onTap: () => setState(() => filterAnticipi = !filterAnticipi),
                                    ),
                                    FilterChipWidget(
                                      label: 'Con prenotazioni',
                                      selected: filterPrenotazioni,
                                      onTap: () => setState(() => filterPrenotazioni = !filterPrenotazioni),
                                    ),
                                  ],
                                ),
                                if (seedMessage.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 18),
                                  Text(seedMessage, style: const TextStyle(color: Colors.white70)),
                                ],
                                const SizedBox(height: 24),
                                Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 1280),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: AppColors.panel,
                                        borderRadius: BorderRadius.circular(28),
                                        border: Border.all(color: Colors.white10),
                                      ),
                                      child: filteredPatients.isEmpty
                                      ? const Text(
                                          'Nessun assistito presente.',
                                          style: TextStyle(color: Colors.white70),
                                        )
                                      : SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: DataTable(
                                            headingRowColor: const WidgetStatePropertyAll<Color>(
                                              Color(0xFF1A1A1A),
                                            ),
                                            columns: const <DataColumn>[
                                              DataColumn(label: TableHeader('Assistito')),
                                              DataColumn(label: TableHeader('CF')),
                                              DataColumn(label: TableHeader('Città')),
                                              DataColumn(label: TableHeader('Esenzione')),
                                              DataColumn(label: TableHeader('Medico')),
                                              DataColumn(label: TableHeader('Debito')),
                                              DataColumn(label: TableHeader('Ricette')),
                                              DataColumn(label: TableHeader('Flag')),
                                              DataColumn(label: TableHeader('Azioni')),
                                            ],
                                            rows: filteredPatients.map((Patient patient) {
                                              final List<Widget> flags = <Widget>[];
                                              if (patient.hasDpc) {
                                                flags.add(const StatusBadge(text: 'DPC', color: AppColors.coral));
                                              }
                                              if (patient.hasDebt) {
                                                flags.add(const StatusBadge(text: 'DEBITO', color: AppColors.wine));
                                              }
                                              if (patient.hasAdvance) {
                                                flags.add(const StatusBadge(text: 'ANTICIPO', color: AppColors.amber));
                                              }
                                              if (patient.hasBooking) {
                                                flags.add(const StatusBadge(text: 'PRENOT.', color: AppColors.yellow));
                                              }

                                              final List<DrivePdfImport> patientImports = allImports.where((DrivePdfImport item) {
                                                return item.patientFiscalCode.trim().toUpperCase() == patient.fiscalCode.trim().toUpperCase();
                                              }).toList();
                                              final int recipeCount = patient.archivedRecipeCount > 0
                                                  ? patient.archivedRecipeCount
                                                  : patientImports.fold<int>(0, (int sum, DrivePdfImport item) => sum + item.prescriptionCount);

                                              return DataRow(
                                                cells: <DataCell>[
                                                  DataCell(Text(patient.fullName, style: _rowStyle)),
                                                  DataCell(Text(patient.fiscalCode, style: _rowStyle)),
                                                  DataCell(Text(patient.city ?? '-', style: _rowStyle)),
                                                  DataCell(Text(patient.exemptionCode ?? '-', style: _rowStyle)),
                                                  DataCell(Text(patient.doctorName ?? '-', style: _rowStyle)),
                                                  DataCell(Text('€ ${patient.debtTotal.toStringAsFixed(2)}', style: _rowStyle)),
                                                  DataCell(
                                                    recipeCount == 0
                                                        ? Text('0', style: _rowStyle)
                                                        : InkWell(
                                                            onTap: () => _openPatientPdfFiles(patient, allImports),
                                                            child: Text(
                                                              '$recipeCount',
                                                              style: _rowStyle.copyWith(
                                                                color: AppColors.coral,
                                                                decoration: TextDecoration.underline,
                                                              ),
                                                            ),
                                                          ),
                                                  ),
                                                  DataCell(
                                                    Wrap(spacing: 6, runSpacing: 6, children: flags),
                                                  ),
                                                  DataCell(
                                                    FilledButton(
                                                      onPressed: () => openPatientDetail(patient),
                                                      style: FilledButton.styleFrom(
                                                        backgroundColor: AppColors.panelSoft,
                                                        foregroundColor: Colors.white,
                                                      ),
                                                      child: const Text('Apri scheda'),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<_DashboardData> _loadDashboardData() async {
    final List<Patient> patients = await patientsRepository.getAllPatients();
    final List<DrivePdfImport> imports = await drivePdfImportsRepository.getAllImports();

    final Map<String, List<DrivePdfImport>> importsByPatient = <String, List<DrivePdfImport>>{};
    for (final DrivePdfImport item in imports) {
      final String fiscalCode = item.patientFiscalCode.trim().toUpperCase();
      if (fiscalCode.isEmpty) continue;
      importsByPatient.putIfAbsent(fiscalCode, () => <DrivePdfImport>[]).add(item);
    }

    final List<Patient> enrichedPatients = patients.map((Patient patient) {
      final List<DrivePdfImport> patientImports = importsByPatient[patient.fiscalCode.trim().toUpperCase()] ?? const <DrivePdfImport>[];
      final int recipeCount = patientImports.fold<int>(0, (int sum, DrivePdfImport item) => sum + item.prescriptionCount);
      final DateTime? lastDate = patientImports
          .map((DrivePdfImport item) => item.prescriptionDate)
          .whereType<DateTime>()
          .fold<DateTime?>(null, (DateTime? current, DateTime value) {
        if (current == null || value.isAfter(current)) {
          return value;
        }
        return current;
      });
      final Set<String> therapies = <String>{
        ...patient.therapiesSummary,
        ...patientImports.expand((DrivePdfImport item) => item.therapy),
      };
      final bool hasDpc = patient.hasDpc || patientImports.any((DrivePdfImport item) => item.isDpc);
      final String doctorName = patient.doctorName ??
          patientImports.firstWhere(
            (DrivePdfImport item) => item.doctorFullName.trim().isNotEmpty,
            orElse: () => DrivePdfImport(
              id: '',
              driveFileId: '',
              fileName: '',
              mimeType: 'application/pdf',
              status: '',
              createdAt: DateTime.fromMillisecondsSinceEpoch(0),
              updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
            ),
          ).doctorFullName;
      return patient.copyWith(
        archivedRecipeCount: recipeCount > 0 ? recipeCount : patient.archivedRecipeCount,
        hasDpc: hasDpc,
        lastPrescriptionDate: lastDate ?? patient.lastPrescriptionDate,
        therapiesSummary: therapies.where((String item) => item.trim().isNotEmpty).toList()..sort(),
        doctorName: doctorName.isEmpty ? patient.doctorName : doctorName,
      );
    }).toList();

    return _DashboardData(patients: enrichedPatients, imports: imports);
  }
}

class _DashboardData {
  final List<Patient> patients;
  final List<DrivePdfImport> imports;

  const _DashboardData({required this.patients, required this.imports});
}

const TextStyle _rowStyle = TextStyle(
  color: Colors.white,
  fontSize: 14,
);
