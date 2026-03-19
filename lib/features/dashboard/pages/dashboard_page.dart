import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/prescription_expiry_utils.dart';
import '../../../data/datasources/firestore_firebase_datasource.dart';
import '../../../data/models/advance.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/debt.dart';
import '../../../data/models/doctor_patient_link.dart';
import '../../../data/models/drive_pdf_import.dart';
import '../../../data/models/patient.dart';
import '../../../data/models/prescription.dart';
import '../../../data/repositories/advances_repository.dart';
import '../../../data/repositories/bookings_repository.dart';
import '../../../data/repositories/debts_repository.dart';
import '../../../data/repositories/doctor_patient_links_repository.dart';
import '../../../data/repositories/drive_pdf_imports_repository.dart';
import '../../../data/repositories/patients_repository.dart';
import '../../../data/repositories/prescriptions_repository.dart';
import '../../../features/patients/pages/patient_detail_page.dart';
import '../../../theme/app_theme.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final TextEditingController _searchController = TextEditingController();

  late final PatientsRepository _patientsRepository;
  late final PrescriptionsRepository _prescriptionsRepository;
  late final AdvancesRepository _advancesRepository;
  late final DebtsRepository _debtsRepository;
  late final BookingsRepository _bookingsRepository;
  late final DrivePdfImportsRepository _drivePdfImportsRepository;
  late final DoctorPatientLinksRepository _doctorPatientLinksRepository;

  Future<_DashboardData>? _future;
  bool _onlyRicette = false;
  bool _onlyDpc = false;
  bool _onlyDebiti = false;
  bool _onlyAnticipi = false;
  bool _onlyPrenotazioni = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    final datasource = FirestoreFirebaseDatasource(FirebaseFirestore.instance);
    _patientsRepository = PatientsRepository(datasource: datasource);
    _prescriptionsRepository = PrescriptionsRepository(
      datasource: datasource,
      patientsRepository: _patientsRepository,
    );
    _advancesRepository = AdvancesRepository(datasource: datasource);
    _debtsRepository = DebtsRepository(datasource: datasource);
    _bookingsRepository = BookingsRepository(datasource: datasource);
    _drivePdfImportsRepository = DrivePdfImportsRepository(datasource: datasource);
    _doctorPatientLinksRepository = DoctorPatientLinksRepository(datasource: datasource);
    _future = _load();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_DashboardData> _load() async {
    final patients = await _patientsRepository.getAllPatients();
    final imports = await _drivePdfImportsRepository.getAllImports();
    final doctorLinks = await _doctorPatientLinksRepository.getAllLinks();

    final summaries = await Future.wait(
      patients.map((patient) async {
        final prescriptions = await _prescriptionsRepository.getPatientPrescriptions(patient.fiscalCode);
        final debts = await _debtsRepository.getPatientDebts(patient.fiscalCode);
        final advances = await _advancesRepository.getPatientAdvances(patient.fiscalCode);
        final bookings = await _bookingsRepository.getPatientBookings(patient.fiscalCode);
        return _PatientDashboardSummary.build(
          patient: patient,
          prescriptions: prescriptions,
          imports: imports,
          debts: debts,
          advances: advances,
          bookings: bookings,
          doctorLinks: doctorLinks,
        );
      }),
    );

    summaries.sort((a, b) {
      if (a.hasExpiryAlert != b.hasExpiryAlert) {
        return a.hasExpiryAlert ? -1 : 1;
      }
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });

    return _DashboardData(summaries: summaries);
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  List<_PatientDashboardSummary> _applyFilters(List<_PatientDashboardSummary> input) {
    final query = _searchController.text.trim().toLowerCase();
    return input.where((item) {
      if (_onlyRicette && item.recipeCount == 0) return false;
      if (_onlyDpc && !item.hasDpc) return false;
      if (_onlyDebiti && item.debts.isEmpty) return false;
      if (_onlyAnticipi && item.advances.isEmpty) return false;
      if (_onlyPrenotazioni && item.bookings.isEmpty) return false;
      if (query.isEmpty) return true;
      return item.displayName.toLowerCase().contains(query) ||
          item.patient.fiscalCode.toLowerCase().contains(query) ||
          item.doctorName.toLowerCase().contains(query) ||
          item.exemptionCode.toLowerCase().contains(query) ||
          item.city.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openPdf(DrivePdfImport item) async {
    final String directLink = item.webViewLink.trim();
    final String fallbackLink = item.driveFileId.trim().isNotEmpty
        ? 'https://drive.google.com/file/d/${item.driveFileId.trim()}/view'
        : '';
    final String url = directLink.isNotEmpty ? directLink : fallbackLink;
    if (url.isEmpty) {
      setState(() {
        _message = 'Link PDF assente nel record Firestore.';
      });
      return;
    }
    await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_blank',
    );
  }

  Future<void> _openPdfList(_PatientDashboardSummary summary) async {
    if (summary.imports.isEmpty) return;
    if (summary.imports.length == 1) {
      await _openPdf(summary.imports.first);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.panel,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PDF ${summary.displayName}',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: SingleChildScrollView(
                    child: Column(
                      children: summary.imports.map((item) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.picture_as_pdf, color: AppColors.coral),
                          title: Text(item.fileName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          subtitle: Text(
                            _formatDate(item.prescriptionDate ?? item.createdAt),
                            style: const TextStyle(color: Colors.white70),
                          ),
                          trailing: TextButton(
                            onPressed: () => _openPdf(item),
                            child: const Text('Apri'),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Future<void> _openFlagModal({
    required String title,
    required List<_FlagItem> items,
    Widget? headerAction,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: AppColors.panel,
          child: SizedBox(
            width: 760,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                      ),
                      if (headerAction != null) headerAction,
                    ],
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 500),
                    child: items.isEmpty
                        ? const Text('Nessuna voce.', style: TextStyle(color: Colors.white70))
                        : SingleChildScrollView(
                            child: Column(
                              children: items.map((item) {
                                return Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.panelSoft,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(item.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                                            if (item.subtitle.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Text(item.subtitle, style: const TextStyle(color: Colors.white70, height: 1.35)),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (item.onDelete != null) ...[
                                        const SizedBox(width: 12),
                                        IconButton(
                                          tooltip: 'Elimina voce',
                                          onPressed: item.onDelete == null ? null : () { item.onDelete!.call(); },
                                          icon: const Icon(Icons.delete_outline, color: AppColors.red),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteAllDebts(_PatientDashboardSummary summary) async {
    for (final item in summary.debts) {
      await _debtsRepository.deleteDebt(summary.patient.fiscalCode, item.id);
    }
    Navigator.of(context, rootNavigator: true).pop();
    _refresh();
  }

  Future<void> _deleteAllAdvances(_PatientDashboardSummary summary) async {
    for (final item in summary.advances) {
      await _advancesRepository.deleteAdvance(summary.patient.fiscalCode, item.id);
    }
    Navigator.of(context, rootNavigator: true).pop();
    _refresh();
  }

  Future<void> _deleteAllBookings(_PatientDashboardSummary summary) async {
    for (final item in summary.bookings) {
      await _bookingsRepository.deleteBooking(summary.patient.fiscalCode, item.id);
    }
    Navigator.of(context, rootNavigator: true).pop();
    _refresh();
  }

  Future<void> _handleFlagTap(_PatientDashboardSummary summary, String key) async {
    if (key == 'ricette') {
      await _openPdfList(summary);
      return;
    }
    if (key == 'dpc') {
      await _openFlagModal(
        title: 'DPC · ${summary.displayName}',
        items: summary.dpcItems.map((item) {
          return _FlagItem(
            title: item.title,
            subtitle: item.subtitle,
          );
        }).toList(),
      );
      return;
    }
    if (key == 'debiti') {
      await _openFlagModal(
        title: 'Debiti · ${summary.displayName}',
        headerAction: IconButton(
          tooltip: 'Elimina tutto',
          onPressed: () { _deleteAllDebts(summary); },
          icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.red),
        ),
        items: summary.debts.map((item) {
          return _FlagItem(
            title: '${item.description} · € ${item.residualAmount.toStringAsFixed(2)}',
            subtitle: 'Creazione ${_formatDate(item.createdAt)}${item.note == null || item.note!.trim().isEmpty ? '' : ' · ${item.note!.trim()}'}',
            onDelete: () async {
              await _debtsRepository.deleteDebt(summary.patient.fiscalCode, item.id);
              Navigator.of(context, rootNavigator: true).pop();
              _refresh();
            },
          );
        }).toList(),
      );
      return;
    }
    if (key == 'anticipi') {
      await _openFlagModal(
        title: 'Anticipi · ${summary.displayName}',
        headerAction: IconButton(
          tooltip: 'Elimina tutto',
          onPressed: () { _deleteAllAdvances(summary); },
          icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.red),
        ),
        items: summary.advances.map((item) {
          return _FlagItem(
            title: item.drugName,
            subtitle: '${item.doctorName.isEmpty ? '-' : item.doctorName} · ${_formatDate(item.createdAt)}${item.note == null || item.note!.trim().isEmpty ? '' : ' · ${item.note!.trim()}'}',
            onDelete: () async {
              await _advancesRepository.deleteAdvance(summary.patient.fiscalCode, item.id);
              Navigator.of(context, rootNavigator: true).pop();
              _refresh();
            },
          );
        }).toList(),
      );
      return;
    }
    await _openFlagModal(
      title: 'Prenotazioni · ${summary.displayName}',
      headerAction: IconButton(
        tooltip: 'Elimina tutto',
        onPressed: () { _deleteAllBookings(summary); },
        icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.red),
      ),
      items: summary.bookings.map((item) {
        return _FlagItem(
          title: '${item.drugName} x${item.quantity}',
          subtitle: 'Registrata ${_formatDate(item.createdAt)} · Prevista ${_formatDate(item.expectedDate)}${item.note == null || item.note!.trim().isEmpty ? '' : ' · ${item.note!.trim()}'}',
          onDelete: () async {
            await _bookingsRepository.deleteBooking(summary.patient.fiscalCode, item.id);
            Navigator.of(context, rootNavigator: true).pop();
            _refresh();
          },
        );
      }).toList(),
    );
  }

  Future<void> _openAddPatientDialog() async {

    final fiscalCodeController = TextEditingController();
    final nameController = TextEditingController();
    final cityController = TextEditingController();
    final exemptionController = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.panel,
          title: const Text('Nuovo assistito', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(fiscalCodeController, 'Codice fiscale'),
                const SizedBox(height: 12),
                _dialogField(nameController, 'Nome e cognome'),
                const SizedBox(height: 12),
                _dialogField(cityController, 'Città'),
                const SizedBox(height: 12),
                _dialogField(exemptionController, 'Esenzione'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annulla', style: TextStyle(color: Colors.white70)),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Salva'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    try {
      final fiscalCode = fiscalCodeController.text.trim().toUpperCase();
      final name = nameController.text.trim();
      if (fiscalCode.isEmpty || name.isEmpty) {
        throw Exception('Codice fiscale e nome sono obbligatori.');
      }
      await _patientsRepository.savePatient(
        Patient(
          fiscalCode: fiscalCode,
          fullName: name,
          city: cityController.text.trim().isEmpty ? null : cityController.text.trim(),
          exemptionCode: exemptionController.text.trim().isEmpty ? null : exemptionController.text.trim(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      setState(() {
        _message = 'Assistito inserito correttamente.';
      });
      _refresh();
    } catch (e) {
      setState(() {
        _message = 'Errore inserimento assistito: $e';
      });
    } finally {
      fiscalCodeController.dispose();
      nameController.dispose();
      cityController.dispose();
      exemptionController.dispose();
    }
  }

  Future<void> _deletePatientEverything(_PatientDashboardSummary summary) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.panel,
          title: const Text('Eliminazione totale', style: TextStyle(color: Colors.white)),
          content: Text(
            'Eliminare debiti, anticipi, prenotazioni e ricette di ${summary.displayName}?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annulla', style: TextStyle(color: Colors.white70)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Elimina'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    try {
      for (final debt in summary.debts) {
        await _debtsRepository.deleteDebt(summary.patient.fiscalCode, debt.id);
      }
      for (final advance in summary.advances) {
        await _advancesRepository.deleteAdvance(summary.patient.fiscalCode, advance.id);
      }
      for (final booking in summary.bookings) {
        await _bookingsRepository.deleteBooking(summary.patient.fiscalCode, booking.id);
      }
      await _prescriptionsRepository.deleteAllPatientPrescriptions(summary.patient.fiscalCode);
      await _drivePdfImportsRepository.deleteImportsByPatient(summary.patient.fiscalCode);
      final updated = summary.patient.copyWith(
        hasDebt: false,
        debtTotal: 0,
        hasAdvance: false,
        hasBooking: false,
        hasDpc: false,
        archivedRecipeCount: 0,
        lastPrescriptionDate: null,
        therapiesSummary: const <String>[],
        updatedAt: DateTime.now(),
      );
      await _patientsRepository.savePatient(updated);
      setState(() {
        _message = 'Dati assistito eliminati.';
      });
      _refresh();
    } catch (e) {
      setState(() {
        _message = 'Errore eliminazione totale: $e';
      });
    }
  }

  void _openPatient(_PatientDashboardSummary summary) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => PatientDetailPage(fiscalCode: summary.patient.fiscalCode),
          ),
        )
        .then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DashboardData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final summaries = data == null ? const <_PatientDashboardSummary>[] : _applyFilters(data.summaries);
        final expiring = summaries.where((item) => item.hasExpiryAlert).toList();
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dashboard assistiti', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                          SizedBox(height: 6),
                          Text('Solo Firestore. PDF aperti con webViewLink.', style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _openAddPatientDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Nuovo assistito'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  decoration: InputDecoration(
                    hintText: 'Cerca per nome, CF, medico, esenzione, città',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: AppColors.panel,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _FilterToggle(label: 'Ricette', value: _onlyRicette, onChanged: (v) => setState(() => _onlyRicette = v)),
                    _FilterToggle(label: 'DPC', value: _onlyDpc, onChanged: (v) => setState(() => _onlyDpc = v)),
                    _FilterToggle(label: 'Debiti', value: _onlyDebiti, onChanged: (v) => setState(() => _onlyDebiti = v)),
                    _FilterToggle(label: 'Anticipi', value: _onlyAnticipi, onChanged: (v) => setState(() => _onlyAnticipi = v)),
                    _FilterToggle(label: 'Prenotazioni', value: _onlyPrenotazioni, onChanged: (v) => setState(() => _onlyPrenotazioni = v)),
                  ],
                ),
                if (_message.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(_message, style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w700)),
                ],
                const SizedBox(height: 18),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Expanded(child: Center(child: CircularProgressIndicator()))
                else if (snapshot.hasError)
                  Expanded(
                    child: Center(
                      child: Text('Errore dashboard: ${snapshot.error}', style: const TextStyle(color: Colors.white)),
                    ),
                  )
                else
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (expiring.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.panel,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppColors.amber),
                            ),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                const Text('Ricette in scadenza:', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                                ...expiring.map((item) => ActionChip(
                                      backgroundColor: AppColors.panelSoft,
                                      label: Text(item.displayName, style: const TextStyle(color: Colors.white)),
                                      onPressed: () => _openPatient(item),
                                    )),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.panel,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: const Row(
                            children: [
                              SizedBox(width: 180, child: Text('Assistito', style: _headStyle)),
                              SizedBox(width: 220, child: Text('CF', style: _headStyle)),
                              SizedBox(width: 240, child: Text('Medico', style: _headStyle)),
                              SizedBox(width: 120, child: Text('Esenzione', style: _headStyle)),
                              Expanded(child: Text('Flags', style: _headStyle)),
                              SizedBox(width: 52),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: summaries.isEmpty
                              ? const Center(child: Text('Nessun assistito.', style: TextStyle(color: Colors.white70, fontSize: 18)))
                              : ListView.separated(
                                  itemCount: summaries.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final item = summaries[index];
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                                      decoration: BoxDecoration(
                                        color: item.hasExpiryAlert ? const Color(0x332A1B00) : AppColors.panel,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: item.hasExpiryAlert ? AppColors.amber : Colors.white10,
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 180,
                                            child: TextButton(
                                              style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                                              onPressed: () => _openPatient(item),
                                              child: Text(
                                                item.displayName,
                                                textAlign: TextAlign.left,
                                                style: const TextStyle(color: Colors.white, fontSize: 18.2, fontWeight: FontWeight.w800),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 220,
                                            child: TextButton(
                                              style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                                              onPressed: () => _openPatient(item),
                                              child: Text(
                                                item.patient.fiscalCode,
                                                textAlign: TextAlign.left,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(color: AppColors.yellow, fontSize: 18.2, fontWeight: FontWeight.w800),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 240,
                                            child: Text(
                                              item.doctorNameUpper,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(color: Colors.white, fontSize: 18.2, fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 120,
                                            child: Text(item.exemptionCode, style: const TextStyle(color: Colors.white70, fontSize: 18.2)),
                                          ),
                                          Expanded(
                                            child: Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: _buildFlagChips(item),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 52,
                                            child: IconButton(
                                              tooltip: 'Elimina tutto',
                                              onPressed: () => _deletePatientEverything(item),
                                              icon: const Icon(Icons.delete_outline, color: AppColors.red),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }


  List<Widget> _buildFlagChips(_PatientDashboardSummary item) {
    final widgets = <Widget>[];
    if (item.recipeCount > 0 && item.imports.isNotEmpty) {
      widgets.add(_FlagChip(label: 'ricette ${item.recipeCount}', color: AppColors.green, onTap: () => _handleFlagTap(item, 'ricette')));
    }
    if (item.dpcItems.isNotEmpty) {
      widgets.add(_FlagChip(label: 'DPC ${item.dpcItems.length}', color: AppColors.coral, onTap: () => _handleFlagTap(item, 'dpc')));
    }
    if (item.totalDebt > 0) {
      widgets.add(_FlagChip(label: 'debiti € ${item.totalDebt.toStringAsFixed(2)}', color: AppColors.wine, onTap: () => _handleFlagTap(item, 'debiti')));
    }
    if (item.advances.isNotEmpty) {
      widgets.add(_FlagChip(label: 'anticipi ${item.advances.length}', color: AppColors.amber, onTap: () => _handleFlagTap(item, 'anticipi')));
    }
    if (item.bookings.isNotEmpty) {
      widgets.add(_FlagChip(label: 'prenotazioni ${item.bookings.length}', color: AppColors.yellow, onTap: () => _handleFlagTap(item, 'prenotazioni')));
    }
    return widgets;
  }

  Widget _dialogField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white70),
        ),
      ),
    );
  }

  String _prescriptionTitle(Prescription prescription) {
    final label = prescription.items.map((e) => e.drugName.trim()).where((e) => e.isNotEmpty).join(', ');
    return label.isEmpty ? 'Ricetta' : label;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }
}

class _DashboardData {
  final List<_PatientDashboardSummary> summaries;

  const _DashboardData({required this.summaries});
}

class _PatientDashboardSummary {
  final Patient patient;
  final String doctorName;
  final String exemptionCode;
  final String city;
  final List<Prescription> prescriptions;
  final List<DrivePdfImport> imports;
  final List<Debt> debts;
  final List<Advance> advances;
  final List<Booking> bookings;
  final bool hasDpc;
  final int recipeCount;
  final bool hasExpiryAlert;

  const _PatientDashboardSummary({
    required this.patient,
    required this.doctorName,
    required this.exemptionCode,
    required this.city,
    required this.prescriptions,
    required this.imports,
    required this.debts,
    required this.advances,
    required this.bookings,
    required this.hasDpc,
    required this.recipeCount,
    required this.hasExpiryAlert,
  });

  String get displayName => patient.fullName.trim().isEmpty ? patient.fiscalCode : patient.fullName.trim();

  double get totalDebt => debts.fold<double>(0, (sum, item) => sum + item.residualAmount);

  String get doctorNameUpper => doctorName.trim().isEmpty ? '-' : doctorName.trim().toUpperCase();

  List<_FlagItem> get dpcItems {
    final fromPrescriptions = prescriptions.where((item) => item.dpcFlag).map((item) {
      return _FlagItem(
        title: _dashboardPrescriptionTitle(item),
        subtitle: '${_dashboardFormatDate(item.prescriptionDate)} · ${(item.doctorName ?? '-').trim().isEmpty ? '-' : item.doctorName!.trim()}',
      );
    });
    final fromImports = imports.where((item) => item.isDpc).map((item) {
      return _FlagItem(
        title: item.therapy.isEmpty ? (item.fileName.trim().isEmpty ? 'DPC' : item.fileName.trim()) : item.therapy.join(', '),
        subtitle: '${_dashboardFormatDate(item.prescriptionDate ?? item.createdAt)} · ${item.doctorFullName.trim().isEmpty ? '-' : item.doctorFullName.trim()}',
      );
    });
    return [...fromPrescriptions, ...fromImports];
  }

  static _PatientDashboardSummary build({
    required Patient patient,
    required List<Prescription> prescriptions,
    required List<DrivePdfImport> imports,
    required List<Debt> debts,
    required List<Advance> advances,
    required List<Booking> bookings,
    required List<DoctorPatientLink> doctorLinks,
  }) {
    final normalizedFiscalCode = patient.fiscalCode.trim().toUpperCase();
    final normalizedFullName = patient.fullName.trim().toUpperCase();
    final matchingImports = imports.where((item) {
      final importFiscalCode = item.patientFiscalCode.trim().toUpperCase();
      final importFullName = item.patientFullName.trim().toUpperCase();
      if (importFiscalCode.isNotEmpty) {
        return importFiscalCode == normalizedFiscalCode;
      }
      return normalizedFullName.isNotEmpty && importFullName == normalizedFullName;
    }).toList();
    final matchingDoctor = doctorLinks.where((item) {
      return item.patientFiscalCode == patient.fiscalCode.trim().toUpperCase();
    }).toList();
    final doctorName = matchingDoctor.isNotEmpty
        ? matchingDoctor.first.doctorName.trim()
        : ((patient.doctorName ?? '').trim().isNotEmpty
            ? patient.doctorName!.trim()
            : (prescriptions.map((e) => e.doctorName?.trim() ?? '').firstWhere((e) => e.isNotEmpty, orElse: () => '')).isNotEmpty
                ? prescriptions.map((e) => e.doctorName?.trim() ?? '').firstWhere((e) => e.isNotEmpty, orElse: () => '')
                : matchingImports.map((e) => e.doctorFullName.trim()).firstWhere((e) => e.isNotEmpty, orElse: () => '-')));
    final exemptionCode = (patient.exemptionCode ?? '').trim().isNotEmpty
        ? patient.exemptionCode!.trim()
        : (() {
            final fromPrescription = prescriptions.map((e) => e.exemptionCode?.trim() ?? '').firstWhere((e) => e.isNotEmpty, orElse: () => '');
            if (fromPrescription.isNotEmpty) return fromPrescription;
            return matchingImports.map((e) => e.exemptionCode.trim()).firstWhere((e) => e.isNotEmpty, orElse: () => '-');
          })();
    final city = (patient.city ?? '').trim().isNotEmpty
        ? patient.city!.trim()
        : (() {
            final fromPrescription = prescriptions.map((e) => e.city?.trim() ?? '').firstWhere((e) => e.isNotEmpty, orElse: () => '');
            if (fromPrescription.isNotEmpty) return fromPrescription;
            return matchingImports.map((e) => e.city.trim()).firstWhere((e) => e.isNotEmpty, orElse: () => '-');
          })();
    final int importsRecipeCount = matchingImports.fold<int>(0, (sum, item) => sum + (item.prescriptionCount > 0 ? item.prescriptionCount : 1));
    final int prescriptionsRecipeCount = prescriptions.fold<int>(0, (sum, item) => sum + (item.prescriptionCount > 0 ? item.prescriptionCount : 1));
    final int patientRecipeCount = patient.archivedRecipeCount > 0 ? patient.archivedRecipeCount : 0;
    final recipeCount = importsRecipeCount > 0
        ? importsRecipeCount
        : (prescriptionsRecipeCount > 0 ? prescriptionsRecipeCount : (matchingImports.isNotEmpty ? matchingImports.length : patientRecipeCount));
    final hasDpc = prescriptions.any((item) => item.dpcFlag) || matchingImports.any((item) => item.isDpc);
    final hasExpiryAlert = prescriptions.any((item) {
      final info = PrescriptionExpiryUtils.evaluate(item.expiryDate);
      return info.status == PrescriptionValidityStatus.expiringSoon || info.status == PrescriptionValidityStatus.expired;
    });
    return _PatientDashboardSummary(
      patient: patient,
      doctorName: doctorName.isEmpty ? '-' : doctorName,
      exemptionCode: exemptionCode.isEmpty ? '-' : exemptionCode,
      city: city.isEmpty ? '-' : city,
      prescriptions: prescriptions,
      imports: matchingImports,
      debts: debts,
      advances: advances,
      bookings: bookings,
      hasDpc: hasDpc,
      recipeCount: recipeCount,
      hasExpiryAlert: hasExpiryAlert,
    );
  }
}

class _FlagItem {
  final String title;
  final String subtitle;
  final Future<void> Function()? onDelete;

  const _FlagItem({required this.title, required this.subtitle, this.onDelete});
}

String _dashboardPrescriptionTitle(Prescription prescription) {
  final label = prescription.items.map((e) => e.drugName.trim()).where((e) => e.isNotEmpty).join(', ');
  return label.isEmpty ? 'Ricetta' : label;
}

String _dashboardFormatDate(DateTime? date) {
  if (date == null) return '-';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  return '$day/$month/$year';
}

class _FilterToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FilterToggle({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: value,
      onSelected: onChanged,
      label: Text(label),
      labelStyle: TextStyle(color: value ? Colors.black : Colors.white),
      selectedColor: AppColors.yellow,
      backgroundColor: AppColors.panel,
      side: const BorderSide(color: Colors.white10),
    );
  }
}

class _FlagChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _FlagChip({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.18),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: color),
        ),
        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15.5)),
      ),
    );
  }
}

const TextStyle _headStyle = TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 15);
