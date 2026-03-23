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

  List<DrivePdfImport> _matchingImports(Patient patient, List<DrivePdfImport> imports) {
    return imports.where((DrivePdfImport item) {
      final String importFiscal = item.patientFiscalCode.trim().toUpperCase();
      final String patientFiscal = patient.fiscalCode.trim().toUpperCase();
      if (importFiscal.isNotEmpty && patientFiscal.isNotEmpty && importFiscal == patientFiscal) {
        return true;
      }
      return _sameLooseName(item.patientFullName, patient.fullName);
    }).toList();
  }

  int _recipeCountForPatient(Patient patient, List<DrivePdfImport> imports) {
    final int importsCount = _matchingImports(patient, imports)
        .fold<int>(0, (int sum, DrivePdfImport item) => sum + item.prescriptionCount);
    return importsCount > 0 ? importsCount : patient.archivedRecipeCount;
  }

  Future<void> _openFlagManager(String flag, Patient patient, List<DrivePdfImport> allImports) async {
    if (flag == 'DPC') {
      await _openPatientPdfFiles(patient, allImports);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: AppColors.panel,
          child: SizedBox(
            width: 700,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: FutureBuilder<List<_FlagEntry>>(
                future: _loadFlagEntries(flag, patient),
                builder: (BuildContext context, AsyncSnapshot<List<_FlagEntry>> snapshot) {
                  final List<_FlagEntry> items = snapshot.data ?? const <_FlagEntry>[];
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              '$flag · ${patient.fullName}',
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                              openPatientDetail(patient);
                            },
                            child: const Text('Apri scheda'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Center(child: CircularProgressIndicator())
                      else if (items.isEmpty)
                        const Text('Nessuna voce disponibile.', style: TextStyle(color: Colors.white70))
                      else
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 420),
                          child: SingleChildScrollView(
                            child: Column(
                              children: items.map((_FlagEntry item) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.panelSoft,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(item.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                            const SizedBox(height: 4),
                                            Text(item.subtitle, style: const TextStyle(color: Colors.white70)),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () async {
                                          final bool? ok = await showDialog<bool>(
                                            context: dialogContext,
                                            builder: (BuildContext confirmContext) => AlertDialog(
                                              backgroundColor: AppColors.panel,
                                              title: const Text('Conferma eliminazione', style: TextStyle(color: Colors.white)),
                                              content: const Text('Eliminare questa voce?', style: TextStyle(color: Colors.white70)),
                                              actions: <Widget>[
                                                TextButton(onPressed: () => Navigator.of(confirmContext).pop(false), child: const Text('Annulla')),
                                                FilledButton(onPressed: () => Navigator.of(confirmContext).pop(true), child: const Text('Elimina')),
                                              ],
                                            ),
                                          );
                                          if (ok == true) {
                                            await item.onDelete();
                                            if (mounted) setState(() {});
                                            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                                            await _openFlagManager(flag, patient, allImports);
                                          }
                                        },
                                        icon: const Icon(Icons.delete_outline, color: AppColors.red),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<List<_FlagEntry>> _loadFlagEntries(String flag, Patient patient) async {
    if (flag == 'DEBITO') {
      final List<Debt> debts = await debtsRepository.getPatientDebts(patient.fiscalCode);
      return debts.map((Debt debt) => _FlagEntry(
        title: debt.description,
        subtitle: 'Residuo € ${debt.residualAmount.toStringAsFixed(2)}',
        onDelete: () async => debtsRepository.deleteDebt(patient.fiscalCode, debt.id),
      )).toList();
    }
    if (flag == 'ANTICIPO') {
      final List<Advance> advances = await advancesRepository.getPatientAdvances(patient.fiscalCode);
      return advances.map((Advance advance) => _FlagEntry(
        title: advance.drugName,
        subtitle: '${_formatDate(advance.createdAt)} · ${advance.doctorName}',
        onDelete: () async => advancesRepository.deleteAdvance(patient.fiscalCode, advance.id),
      )).toList();
    }
    final List<Booking> bookings = await bookingsRepository.getPatientBookings(patient.fiscalCode);
    return bookings.map((Booking booking) => _FlagEntry(
      title: '${booking.drugName} x${booking.quantity}',
      subtitle: 'Prevista ${_formatDate(booking.expectedDate)}',
      onDelete: () async => bookingsRepository.deleteBooking(patient.fiscalCode, booking.id),
    )).toList();
  }

  Future<void> _deletePatientRow(Patient patient) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Eliminare riga assistito', style: TextStyle(color: Colors.white)),
        content: Text('Verranno eliminati debiti, anticipi, prenotazioni e ricette di ${patient.fullName}.', style: const TextStyle(color: Colors.white70)),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Elimina tutto')),
        ],
      ),
    );
    if (confirmed != true) return;

    final List<Debt> debts = await debtsRepository.getPatientDebts(patient.fiscalCode);
    final List<Advance> advances = await advancesRepository.getPatientAdvances(patient.fiscalCode);
    final List<Booking> bookings = await bookingsRepository.getPatientBookings(patient.fiscalCode);
    final List<Prescription> prescriptions = await prescriptionsRepository.getPatientPrescriptions(patient.fiscalCode);
    for (final Debt debt in debts) { await debtsRepository.deleteDebt(patient.fiscalCode, debt.id); }
    for (final Advance advance in advances) { await advancesRepository.deleteAdvance(patient.fiscalCode, advance.id); }
    for (final Booking booking in bookings) { await bookingsRepository.deleteBooking(patient.fiscalCode, booking.id); }
    for (final Prescription prescription in prescriptions) {
      if (prescription.sourceType == 'script') {
        await drivePdfImportsRepository.deleteImport(prescription.id);
      } else {
        await prescriptionsRepository.deletePrescription(patient.fiscalCode, prescription.id);
      }
    }
    await drivePdfImportsRepository.deleteImportsByPatient(patient.fiscalCode);
    await patientsRepository.deletePatient(patient.fiscalCode);
    if (mounted) setState(() => seedMessage = 'Riga assistito eliminata.');
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
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
            patients.fold<int>(0, (int sum, Patient p) => sum + _recipeCountForPatient(p, allImports));
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
                                    constraints: const BoxConstraints(maxWidth: 1120),
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
                                              final List<DrivePdfImport> patientImports = _matchingImports(patient, allImports);
                                              final int recipeCount = _recipeCountForPatient(patient, allImports);
                                              final List<Widget> flags = <Widget>[];
                                              if (patient.hasDpc || patientImports.any((DrivePdfImport item) => item.isDpc)) {
                                                flags.add(_ClickableFlag(label: 'DPC', color: AppColors.coral, onTap: () => _openFlagManager('DPC', patient, allImports)));
                                              }
                                              if (patient.hasDebt || patient.debtTotal > 0) {
                                                flags.add(_ClickableFlag(label: 'DEBITO € ${patient.debtTotal.toStringAsFixed(2)}', color: AppColors.wine, onTap: () => _openFlagManager('DEBITO', patient, allImports)));
                                              }
                                              if (patient.hasAdvance) {
                                                flags.add(_ClickableFlag(label: 'ANTICIPO', color: AppColors.amber, onTap: () => _openFlagManager('ANTICIPO', patient, allImports)));
                                              }
                                              if (patient.hasBooking) {
                                                flags.add(_ClickableFlag(label: 'PRENOT.', color: AppColors.yellow, onTap: () => _openFlagManager('PRENOT.', patient, allImports)));
                                              }

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
                                                    flags.isEmpty
                                                        ? Text('-', style: _rowStyle)
                                                        : SingleChildScrollView(
                                                            scrollDirection: Axis.horizontal,
                                                            child: Row(children: flags),
                                                          ),
                                                  ),
                                                  DataCell(
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: <Widget>[
                                                        FilledButton(
                                                          onPressed: () => openPatientDetail(patient),
                                                          style: FilledButton.styleFrom(
                                                            backgroundColor: AppColors.panelSoft,
                                                            foregroundColor: Colors.white,
                                                          ),
                                                          child: const Text('Apri scheda'),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        IconButton(
                                                          tooltip: 'Elimina riga',
                                                          onPressed: () => _deletePatientRow(patient),
                                                          icon: const Icon(Icons.delete_outline, color: AppColors.red),
                                                        ),
                                                      ],
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

    final List<Patient> enrichedPatients = patients.map((Patient patient) {
      final List<DrivePdfImport> patientImports = _matchingImports(patient, imports);
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
      final String? importDoctor = patientImports
          .map((DrivePdfImport item) => item.doctorFullName.trim())
          .firstWhere((String item) => item.isNotEmpty, orElse: () => '');
      return patient.copyWith(
        archivedRecipeCount: recipeCount > 0 ? recipeCount : patient.archivedRecipeCount,
        hasDpc: hasDpc,
        lastPrescriptionDate: lastDate ?? patient.lastPrescriptionDate,
        therapiesSummary: therapies.where((String item) => item.trim().isNotEmpty).toList()..sort(),
        doctorName: importDoctor != null && importDoctor.isNotEmpty ? importDoctor : patient.doctorName,
      );
    }).toList();

    return _DashboardData(patients: enrichedPatients, imports: imports);
  }
}

class _FlagEntry {
  final String title;
  final String subtitle;
  final Future<void> Function() onDelete;

  const _FlagEntry({required this.title, required this.subtitle, required this.onDelete});
}

class _ClickableFlag extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ClickableFlag({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: StatusBadge(text: label, color: color),
      ),
    );
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
