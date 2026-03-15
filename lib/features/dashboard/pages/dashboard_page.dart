import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../data/datasources/firestore_firebase_datasource.dart';
import '../../../data/demo/demo_advances.dart';
import '../../../data/demo/demo_bookings.dart';
import '../../../data/demo/demo_debts.dart';
import '../../../data/demo/demo_patients.dart';
import '../../../data/demo/demo_prescriptions.dart';
import '../../../data/models/advance.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/debt.dart';
import '../../../data/models/patient.dart';
import '../../../data/models/prescription.dart';
import '../../../data/repositories/advances_repository.dart';
import '../../../data/repositories/bookings_repository.dart';
import '../../../data/repositories/debts_repository.dart';
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Patient>>(
      future: patientsRepository.getAllPatients(),
      builder: (BuildContext context, AsyncSnapshot<List<Patient>> snapshot) {
        final List<Patient> patients = snapshot.data ?? const <Patient>[];
        final List<Patient> filteredPatients = applyFilters(patients);
        final double totalDebts =
            patients.fold<double>(0, (double sum, Patient p) => sum + p.debtTotal);
        final int totalRecipes =
            patients.where((Patient p) => p.archivedRecipeCount > 0).length;
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
                                Row(
                                  children: <Widget>[
                                    ElevatedButton.icon(
                                      onPressed: isSeeding
                                          ? null
                                          : () async {
                                              await seedAll();
                                              if (mounted) {
                                                setState(() {});
                                              }
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.yellow,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                      ),
                                      icon: const Icon(Icons.cloud_upload),
                                      label: Text(
                                        isSeeding
                                            ? 'Caricamento...'
                                            : 'Seed completo test',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    if (seedMessage.isNotEmpty)
                                      Expanded(
                                        child: Text(
                                          seedMessage,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 16,
                                  children: <Widget>[
                                    StatCard(
                                      title: 'Assistiti con ricette',
                                      value: '$totalRecipes',
                                      color: AppColors.yellow,
                                      darkText: true,
                                    ),
                                    StatCard(
                                      title: 'Assistiti con DPC',
                                      value: '$totalDpc',
                                      color: AppColors.coral,
                                    ),
                                    StatCard(
                                      title: 'Assistiti con anticipi',
                                      value: '$totalAdvances',
                                      color: AppColors.pink,
                                      darkText: true,
                                    ),
                                    StatCard(
                                      title: 'Assistiti con prenotazioni',
                                      value: '$totalBookings',
                                      color: AppColors.panelSoft,
                                    ),
                                    StatCard(
                                      title: 'Debito totale',
                                      value: '€ ${totalDebts.toStringAsFixed(2)}',
                                      color: AppColors.wine,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: AppColors.panel,
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      const Text(
                                        'Filtri dashboard',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 12,
                                        children: <Widget>[
                                          FilterChipWidget(
                                            label: 'DPC',
                                            selected: filterDpc,
                                            onTap: () => setState(
                                              () => filterDpc = !filterDpc,
                                            ),
                                          ),
                                          FilterChipWidget(
                                            label: 'Ricette',
                                            selected: filterRicette,
                                            onTap: () => setState(
                                              () => filterRicette = !filterRicette,
                                            ),
                                          ),
                                          FilterChipWidget(
                                            label: 'Anticipi',
                                            selected: filterAnticipi,
                                            onTap: () => setState(
                                              () => filterAnticipi = !filterAnticipi,
                                            ),
                                          ),
                                          FilterChipWidget(
                                            label: 'Debiti',
                                            selected: filterDebiti,
                                            onTap: () => setState(
                                              () => filterDebiti = !filterDebiti,
                                            ),
                                          ),
                                          FilterChipWidget(
                                            label: 'Prenotazioni',
                                            selected: filterPrenotazioni,
                                            onTap: () => setState(
                                              () => filterPrenotazioni =
                                                  !filterPrenotazioni,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: AppColors.panel,
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      const Text(
                                        'Archivio assistiti',
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: DataTable(
                                          headingRowColor:
                                              const WidgetStatePropertyAll<Color>(
                                            Color(0xFF1A1A1A),
                                          ),
                                          dataRowMinHeight: 62,
                                          dataRowMaxHeight: 74,
                                          columns: const <DataColumn>[
                                            DataColumn(
                                              label: TableHeader('Assistito'),
                                            ),
                                            DataColumn(
                                              label: TableHeader('Codice fiscale'),
                                            ),
                                            DataColumn(
                                              label: TableHeader('Città'),
                                            ),
                                            DataColumn(
                                              label: TableHeader('Medico'),
                                            ),
                                            DataColumn(
                                              label: TableHeader('Ricette'),
                                            ),
                                            DataColumn(
                                              label: TableHeader('DPC'),
                                            ),
                                            DataColumn(
                                              label: TableHeader('Anticipi'),
                                            ),
                                            DataColumn(
                                              label: TableHeader('Prenotazioni'),
                                            ),
                                            DataColumn(
                                              label: TableHeader('Debito'),
                                            ),
                                          ],
                                          rows: filteredPatients.map((Patient p) {
                                            return DataRow(
                                              onSelectChanged: (_) =>
                                                  openPatientDetail(p),
                                              cells: <DataCell>[
                                                DataCell(
                                                  Text(
                                                    p.fullName,
                                                    style: _rowLinkStyle,
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(p.fiscalCode, style: _rowStyle),
                                                ),
                                                DataCell(
                                                  Text(p.city ?? '-', style: _rowStyle),
                                                ),
                                                DataCell(
                                                  Text(p.doctorName ?? '-', style: _rowStyle),
                                                ),
                                                DataCell(
                                                  Text('${p.archivedRecipeCount}',
                                                      style: _rowStyle),
                                                ),
                                                DataCell(
                                                  p.hasDpc
                                                      ? const StatusBadge(
                                                          text: 'DPC',
                                                          color: AppColors.coral,
                                                        )
                                                      : const StatusBadge(
                                                          text: 'NO',
                                                          color: Color(0xFF2A2A2A),
                                                        ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    p.hasAdvance ? 'SI' : 'NO',
                                                    style: _rowStyle,
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    p.hasBooking ? 'SI' : 'NO',
                                                    style: _rowStyle,
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    '€ ${p.debtTotal.toStringAsFixed(2)}',
                                                    style: _rowStyle,
                                                  ),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ],
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
}

const TextStyle _rowStyle =
    TextStyle(color: Colors.white, fontWeight: FontWeight.w600);

const TextStyle _rowLinkStyle =
    TextStyle(color: AppColors.yellow, fontWeight: FontWeight.w700);
