import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

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
import '../../../data/repositories/settings_repository.dart';
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
  late final SettingsRepository _settingsRepository;

  Future<_DashboardData>? _future;
  final Set<_DashboardCardFilter> _activeCardFilters = <_DashboardCardFilter>{};
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
    _settingsRepository = SettingsRepository(datasource: datasource);
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
    final settings = await _settingsRepository.getSettings();

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

    return _DashboardData(summaries: summaries, doctorsCatalog: settings.doctorsCatalog);
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  List<_PatientDashboardSummary> _applyFilters(List<_PatientDashboardSummary> input) {
    final query = _searchController.text.trim().toLowerCase();
    return input.where((item) {
      if (!item.hasActiveContent) return false;
      for (final filter in _activeCardFilters) {
        switch (filter) {
          case _DashboardCardFilter.ricette:
            if (item.recipeCount == 0) return false;
            break;
          case _DashboardCardFilter.dpc:
            if (!item.hasDpc) return false;
            break;
          case _DashboardCardFilter.debiti:
            if (item.debts.isEmpty) return false;
            break;
          case _DashboardCardFilter.anticipi:
            if (item.advances.isEmpty) return false;
            break;
          case _DashboardCardFilter.prenotazioni:
            if (item.bookings.isEmpty) return false;
            break;
          case _DashboardCardFilter.scadenze:
            if (!item.hasExpiryAlert) return false;
            break;
          case _DashboardCardFilter.assistiti:
            break;
        }
      }
      if (query.isEmpty) return true;
      return item.displayName.toLowerCase().contains(query) ||
          item.patient.fiscalCode.toLowerCase().contains(query) ||
          item.doctorName.toLowerCase().contains(query) ||
          item.exemptionCode.toLowerCase().contains(query) ||
          item.city.toLowerCase().contains(query);
    }).toList();
  }


  void _toggleCardFilter(_DashboardCardFilter filter) {
    setState(() {
      if (_activeCardFilters.contains(filter)) {
        _activeCardFilters.remove(filter);
      } else {
        _activeCardFilters.add(filter);
      }
    });
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
        return _buildFlagDialog(
          title: title,
          items: items,
          headerAction: headerAction,
        );
      },
    );
  }

  Future<bool> _addDebtFromDashboard(_PatientDashboardSummary summary) async {
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Nuovo debito', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(descriptionController, 'Causale'),
              const SizedBox(height: 12),
              _dialogField(
                amountController,
                'Importo (€)',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,\.]'))],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Data inserimento: ${_formatDate(DateTime.now())}', style: const TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 12),
              _dialogField(noteController, 'Nota', maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annulla', style: TextStyle(color: Colors.white70))),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Salva')),
        ],
      ),
    );
    if (confirmed != true) return false;
    try {
      final amount = double.tryParse(amountController.text.trim().replaceAll(',', '.')) ?? 0;
      if (descriptionController.text.trim().isEmpty || amount <= 0) {
        throw Exception('Causale e importo sono obbligatori.');
      }
      final now = DateTime.now();
      await _debtsRepository.saveDebt(
        Debt(
          id: 'debt_${now.microsecondsSinceEpoch}',
          patientFiscalCode: summary.patient.fiscalCode,
          patientName: summary.patient.fullName,
          description: descriptionController.text.trim(),
          amount: amount,
          paidAmount: 0,
          residualAmount: amount,
          createdAt: now,
          dueDate: now,
          note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
        ),
      );
      _refresh();
      return true;
    } catch (e) {
      setState(() => _message = 'Errore salvataggio debito: $e');
      return false;
    } finally {
      descriptionController.dispose();
      amountController.dispose();
      noteController.dispose();
    }
  }

  Future<bool> _addAdvanceFromDashboard(_PatientDashboardSummary summary) async {
    final drugController = TextEditingController();
    final noteController = TextEditingController();
    String selectedDoctor = summary.doctorName.trim() == '-' ? '' : summary.doctorName.trim();
    final data = await _future!;
    final candidateList = <String>{
      ...data.doctorsCatalog.map((e) => e.trim()).where((e) => e.isNotEmpty),
      if (selectedDoctor.isNotEmpty) selectedDoctor,
    }.toList()
      ..sort();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) => AlertDialog(
            backgroundColor: AppColors.panel,
            title: const Text('Nuovo anticipo', style: TextStyle(color: Colors.white)),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dialogField(drugController, 'Farmaco / articolo'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedDoctor.isEmpty ? null : selectedDoctor,
                    dropdownColor: AppColors.panelSoft,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Medico',
                      hintText: 'Seleziona medico',
                      hintStyle: const TextStyle(color: Colors.white54),
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
                    items: candidateList.map((item) => DropdownMenuItem<String>(value: item, child: Text(item))).toList(),
                    onChanged: (value) => setLocalState(() => selectedDoctor = value ?? ''),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Data registrazione: ${_formatDate(DateTime.now())}', style: const TextStyle(color: Colors.white70)),
                  ),
                  const SizedBox(height: 12),
                  _dialogField(noteController, 'Nota', maxLines: 3),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annulla', style: TextStyle(color: Colors.white70))),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Salva')),
            ],
          ),
        );
      },
    );
    if (confirmed != true) return false;
    try {
      if (drugController.text.trim().isEmpty || selectedDoctor.trim().isEmpty) {
        throw Exception('Farmaco e medico sono obbligatori.');
      }
      final now = DateTime.now();
      await _advancesRepository.saveAdvance(
        Advance(
          id: 'adv_${now.microsecondsSinceEpoch}',
          patientFiscalCode: summary.patient.fiscalCode,
          patientName: summary.patient.fullName,
          drugName: drugController.text.trim(),
          doctorName: selectedDoctor.trim(),
          note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
          createdAt: now,
          updatedAt: now,
        ),
      );
      _refresh();
      return true;
    } catch (e) {
      setState(() => _message = 'Errore salvataggio anticipo: $e');
      return false;
    } finally {
      drugController.dispose();
      noteController.dispose();
    }
  }

  Future<bool> _addBookingFromDashboard(_PatientDashboardSummary summary) async {
    final drugController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Nuova prenotazione', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(drugController, 'Farmaco / articolo'),
              const SizedBox(height: 12),
              _dialogField(
                quantityController,
                'Quantità',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Data prevista: ${_formatDate(DateTime.now())}', style: const TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 12),
              _dialogField(noteController, 'Nota', maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annulla', style: TextStyle(color: Colors.white70))),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Salva')),
        ],
      ),
    );
    if (confirmed != true) return false;
    try {
      if (drugController.text.trim().isEmpty) {
        throw Exception('Farmaco obbligatorio.');
      }
      final now = DateTime.now();
      await _bookingsRepository.saveBooking(
        Booking(
          id: 'book_${now.microsecondsSinceEpoch}',
          patientFiscalCode: summary.patient.fiscalCode,
          patientName: summary.patient.fullName,
          drugName: drugController.text.trim(),
          quantity: int.tryParse(quantityController.text.trim()) ?? 1,
          createdAt: now,
          expectedDate: now,
          note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
        ),
      );
      _refresh();
      return true;
    } catch (e) {
      setState(() => _message = 'Errore salvataggio prenotazione: $e');
      return false;
    } finally {
      drugController.dispose();
      quantityController.dispose();
      noteController.dispose();
    }
  }

  Future<bool> _deleteAllDebts(_PatientDashboardSummary summary) async {
    for (final item in summary.debts) {
      await _debtsRepository.deleteDebt(summary.patient.fiscalCode, item.id);
    }
    _refresh();
    return true;
  }

  Future<bool> _deleteAllAdvances(_PatientDashboardSummary summary) async {
    for (final item in summary.advances) {
      await _advancesRepository.deleteAdvance(summary.patient.fiscalCode, item.id);
    }
    _refresh();
    return true;
  }

  Future<bool> _deleteAllBookings(_PatientDashboardSummary summary) async {
    for (final item in summary.bookings) {
      await _bookingsRepository.deleteBooking(summary.patient.fiscalCode, item.id);
    }
    _refresh();
    return true;
  }


  Future<_PatientDashboardSummary?> _reloadSummary(String fiscalCode) async {
    final data = await _load();
    final normalized = fiscalCode.trim().toUpperCase();
    for (final item in data.summaries) {
      if (item.patient.fiscalCode.trim().toUpperCase() == normalized) {
        return item;
      }
    }
    return null;
  }

  Future<void> _openEditableFlagModal({
    required _PatientDashboardSummary summary,
    required String key,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        _PatientDashboardSummary currentSummary = summary;
        bool busy = false;

        Future<void> reload(StateSetter setLocalState) async {
          setLocalState(() => busy = true);
          final refreshed = await _reloadSummary(summary.patient.fiscalCode);
          if (refreshed != null) {
            setLocalState(() {
              currentSummary = refreshed;
              busy = false;
            });
          } else {
            setLocalState(() => busy = false);
          }
        }

        Future<void> runAndReload(StateSetter setLocalState, Future<bool> Function() action) async {
          final changed = await action();
          if (changed) {
            await reload(setLocalState);
          }
        }

        List<_FlagItem> buildItems(StateSetter setLocalState) {
          if (key == 'debiti') {
            return currentSummary.debts.map((item) => _FlagItem(
              title: '${item.description} · € ${item.residualAmount.toStringAsFixed(2)}',
              subtitle: 'Inserito ${_formatDate(item.createdAt)}${item.note == null || item.note!.trim().isEmpty ? '' : ' · ${item.note!.trim()}'}',
              onDelete: () async {
                await _debtsRepository.deleteDebt(currentSummary.patient.fiscalCode, item.id);
                _refresh();
                await reload(setLocalState);
              },
            )).toList();
          }
          if (key == 'anticipi') {
            return currentSummary.advances.map((item) => _FlagItem(
              title: item.drugName,
              subtitle: '${item.doctorName.isEmpty ? '-' : item.doctorName} · ${_formatDate(item.createdAt)}${item.note == null || item.note!.trim().isEmpty ? '' : ' · ${item.note!.trim()}'}',
              onDelete: () async {
                await _advancesRepository.deleteAdvance(currentSummary.patient.fiscalCode, item.id);
                _refresh();
                await reload(setLocalState);
              },
            )).toList();
          }
          return currentSummary.bookings.map((item) => _FlagItem(
            title: '${item.drugName} x${item.quantity}',
            subtitle: 'Registrata ${_formatDate(item.createdAt)} · Prevista ${_formatDate(item.expectedDate)}${item.note == null || item.note!.trim().isEmpty ? '' : ' · ${item.note!.trim()}'}',
            onDelete: () async {
              await _bookingsRepository.deleteBooking(currentSummary.patient.fiscalCode, item.id);
              _refresh();
              await reload(setLocalState);
            },
          )).toList();
        }

        String modalTitle() {
          if (key == 'debiti') return 'Debiti · ${currentSummary.displayName}';
          if (key == 'anticipi') return 'Anticipi · ${currentSummary.displayName}';
          return 'Prenotazioni · ${currentSummary.displayName}';
        }

        return StatefulBuilder(
          builder: (context, setLocalState) {
            Widget headerAction;
            if (key == 'debiti') {
              headerAction = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Nuovo debito',
                    onPressed: busy ? null : () => runAndReload(setLocalState, () => _addDebtFromDashboard(currentSummary)),
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.green),
                  ),
                  IconButton(
                    tooltip: 'Elimina tutto',
                    onPressed: busy ? null : () => runAndReload(setLocalState, () => _deleteAllDebts(currentSummary)),
                    icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.red),
                  ),
                ],
              );
            } else if (key == 'anticipi') {
              headerAction = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Nuovo anticipo',
                    onPressed: busy ? null : () => runAndReload(setLocalState, () => _addAdvanceFromDashboard(currentSummary)),
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.green),
                  ),
                  IconButton(
                    tooltip: 'Elimina tutto',
                    onPressed: busy ? null : () => runAndReload(setLocalState, () => _deleteAllAdvances(currentSummary)),
                    icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.red),
                  ),
                ],
              );
            } else {
              headerAction = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Nuova prenotazione',
                    onPressed: busy ? null : () => runAndReload(setLocalState, () => _addBookingFromDashboard(currentSummary)),
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.green),
                  ),
                  IconButton(
                    tooltip: 'Elimina tutto',
                    onPressed: busy ? null : () => runAndReload(setLocalState, () => _deleteAllBookings(currentSummary)),
                    icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.red),
                  ),
                ],
              );
            }
            return Stack(
              children: [
                _buildFlagDialog(
                  title: modalTitle(),
                  items: buildItems(setLocalState),
                  headerAction: headerAction,
                ),
                if (busy) const Positioned.fill(child: ColoredBox(color: Color(0x66000000), child: Center(child: CircularProgressIndicator()))),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFlagDialog({
    required String title,
    required List<_FlagItem> items,
    Widget? headerAction,
  }) {
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
                  if (headerAction != null) ...[
                    headerAction,
                    const SizedBox(width: 8),
                  ],
                  IconButton(
                    tooltip: 'Chiudi',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
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
    if (key == 'debiti' || key == 'anticipi' || key == 'prenotazioni') {
      await _openEditableFlagModal(summary: summary, key: key);
      return;
    }
  }

  Future<void> _openAddPatientDialog() async {
    final data = await _future!;
    final fiscalCodeController = TextEditingController();
    final nameController = TextEditingController();
    final surnameController = TextEditingController();
    final advanceController = TextEditingController();
    final bookingController = TextEditingController();
    final debtController = TextEditingController();
    final debtDescriptionController = TextEditingController();
    String selectedDoctor = '';
    final doctorCandidates = data.doctorsCatalog.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList()..sort();

    void fillFromExistingPatient(String rawValue, void Function(void Function()) setLocalState) {
      final normalizedCf = rawValue.trim().toUpperCase();
      if (fiscalCodeController.text != normalizedCf) {
        fiscalCodeController.value = fiscalCodeController.value.copyWith(
          text: normalizedCf,
          selection: TextSelection.collapsed(offset: normalizedCf.length),
          composing: TextRange.empty,
        );
      }
      final existing = data.summaries.where((e) => e.patient.fiscalCode.trim().toUpperCase() == normalizedCf).cast<_PatientDashboardSummary?>().firstWhere(
        (e) => e != null,
        orElse: () => null,
      );
      if (existing == null) return;

      final fullName = existing.patient.fullName.trim();
      final parts = fullName.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
      String inferredName = '';
      String inferredSurname = '';
      if (parts.length >= 2) {
        inferredName = parts.first;
        inferredSurname = parts.skip(1).join(' ');
      } else if (parts.isNotEmpty) {
        inferredSurname = parts.first;
      }
      final doctorFromMemory = existing.doctorName.trim();
      setLocalState(() {
        if (inferredName.isNotEmpty) {
          nameController.text = inferredName;
        }
        if (inferredSurname.isNotEmpty) {
          surnameController.text = inferredSurname;
        }
        if (doctorFromMemory.isNotEmpty && doctorFromMemory != '-' && doctorCandidates.contains(doctorFromMemory)) {
          selectedDoctor = doctorFromMemory;
        }
      });
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              backgroundColor: AppColors.panel,
              title: const Text('Nuovo assistito', style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _dialogField(
                        fiscalCodeController,
                        'Codice fiscale',
                        onChanged: (value) => fillFromExistingPatient(value, setLocalState),
                      ),
                      const SizedBox(height: 12),
                      _dialogField(nameController, 'Nome'),
                      const SizedBox(height: 12),
                      _dialogField(surnameController, 'Cognome'),
                      const SizedBox(height: 12),
                      _dialogField(advanceController, 'Eventuale anticipo', onChanged: (_) => setLocalState(() {})),
                      if (advanceController.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedDoctor.isEmpty ? null : selectedDoctor,
                          dropdownColor: AppColors.panelSoft,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Medico',
                            hintText: 'Seleziona medico',
                            hintStyle: const TextStyle(color: Colors.white54),
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
                          items: doctorCandidates.map((item) => DropdownMenuItem<String>(value: item, child: Text(item))).toList(),
                          onChanged: (value) => setLocalState(() => selectedDoctor = value ?? ''),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Data anticipo: ${_formatDate(DateTime.now())}', style: const TextStyle(color: Colors.white70)),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _dialogField(bookingController, 'Eventuale prenotazione', onChanged: (_) => setLocalState(() {})),
                      if (bookingController.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Data prenotazione: ${_formatDate(DateTime.now())}', style: const TextStyle(color: Colors.white70)),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _dialogField(
                        debtController,
                        'Eventuale debito (€)',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,\.]'))],
                        onChanged: (_) => setLocalState(() {}),
                      ),
                      if ((double.tryParse(debtController.text.trim().replaceAll(',', '.')) ?? 0) > 0) ...[
                        const SizedBox(height: 12),
                        _dialogField(debtDescriptionController, 'Causale debito'),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Data debito: ${_formatDate(DateTime.now())}', style: const TextStyle(color: Colors.white70)),
                        ),
                      ],
                    ],
                  ),
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
      },
    );
    if (confirmed != true) {
      fiscalCodeController.dispose();
      nameController.dispose();
      surnameController.dispose();
      advanceController.dispose();
      bookingController.dispose();
      debtController.dispose();
      debtDescriptionController.dispose();
      return;
    }

    try {
      final fiscalCode = fiscalCodeController.text.trim().toUpperCase();
      final name = nameController.text.trim();
      final surname = surnameController.text.trim();
      if (fiscalCode.isEmpty || name.isEmpty || surname.isEmpty) {
        throw Exception('Codice fiscale, nome e cognome sono obbligatori.');
      }

      final now = DateTime.now();
      final fullName = '$name $surname'.trim();
      final advanceText = advanceController.text.trim();
      final bookingText = bookingController.text.trim();
      final debtValue = double.tryParse(debtController.text.trim().replaceAll(',', '.')) ?? 0;
      final debtDescription = debtDescriptionController.text.trim();

      if (advanceText.isNotEmpty && selectedDoctor.trim().isEmpty) {
        throw Exception("Per l'anticipo devi selezionare il medico.");
      }
      if (debtValue > 0 && debtDescription.isEmpty) {
        throw Exception('Per il debito devi indicare la causale.');
      }

      await _patientsRepository.savePatient(
        Patient(
          fiscalCode: fiscalCode,
          fullName: fullName,
          hasDebt: debtValue > 0,
          debtTotal: debtValue > 0 ? debtValue : 0,
          hasAdvance: advanceText.isNotEmpty,
          hasBooking: bookingText.isNotEmpty,
          createdAt: now,
          updatedAt: now,
        ),
      );

      if (advanceText.isNotEmpty) {
        await _advancesRepository.saveAdvance(
          Advance(
            id: 'adv_${now.microsecondsSinceEpoch}',
            patientFiscalCode: fiscalCode,
            patientName: fullName,
            drugName: advanceText,
            doctorName: selectedDoctor.trim(),
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      if (bookingText.isNotEmpty) {
        await _bookingsRepository.saveBooking(
          Booking(
            id: 'book_${now.microsecondsSinceEpoch}',
            patientFiscalCode: fiscalCode,
            patientName: fullName,
            drugName: bookingText,
            createdAt: now,
            expectedDate: now,
          ),
        );
      }

      if (debtValue > 0) {
        await _debtsRepository.saveDebt(
          Debt(
            id: 'debt_${now.microsecondsSinceEpoch}',
            patientFiscalCode: fiscalCode,
            patientName: fullName,
            description: debtDescription,
            amount: debtValue,
            paidAmount: 0,
            residualAmount: debtValue,
            createdAt: now,
            dueDate: now,
          ),
        );
      }

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
      surnameController.dispose();
      advanceController.dispose();
      bookingController.dispose();
      debtController.dispose();
      debtDescriptionController.dispose();
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
                if (_message.isNotEmpty) ...[
                  Text(_message, style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                ],
                LayoutBuilder(
                  builder: (context, constraints) {
                    const double cardWidth = 220;
                    const double cardSpacing = 12;
                    final double cardsBlockWidth = constraints.maxWidth >= ((cardWidth * 5) + (cardSpacing * 4))
                        ? ((cardWidth * 5) + (cardSpacing * 4))
                        : constraints.maxWidth;
                    return Column(
                      children: [
                        const SizedBox(height: 10),
                        Center(
                          child: SizedBox(
                            width: cardsBlockWidth,
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: cardSpacing,
                              runSpacing: cardSpacing,
                              children: [
                                _SummaryCard(
                                  title: 'Assistiti attivi',
                                  value: summaries.length.toString(),
                                  icon: Icons.people_alt_outlined,
                                  accent: AppColors.yellow,
                                  isSelected: _activeCardFilters.contains(_DashboardCardFilter.assistiti),
                                  onTap: () => _toggleCardFilter(_DashboardCardFilter.assistiti),
                                ),
                                _SummaryCard(
                                  title: 'Ricette',
                                  value: summaries.fold<int>(0, (sum, item) => sum + item.recipeCount).toString(),
                                  icon: Icons.receipt_long_outlined,
                                  accent: AppColors.green,
                                  isSelected: _activeCardFilters.contains(_DashboardCardFilter.ricette),
                                  onTap: () => _toggleCardFilter(_DashboardCardFilter.ricette),
                                ),
                                _SummaryCard(
                                  title: 'Totale DPC',
                                  value: summaries.fold<int>(0, (sum, item) => sum + item.dpcItems.length).toString(),
                                  icon: Icons.local_shipping_outlined,
                                  accent: AppColors.coral,
                                  isSelected: _activeCardFilters.contains(_DashboardCardFilter.dpc),
                                  onTap: () => _toggleCardFilter(_DashboardCardFilter.dpc),
                                ),
                                _SummaryCard(
                                  title: 'Debiti',
                                  value: '€ ${summaries.fold<double>(0, (sum, item) => sum + item.totalDebt).toStringAsFixed(2)}',
                                  icon: Icons.euro_outlined,
                                  accent: AppColors.wine,
                                  isSelected: _activeCardFilters.contains(_DashboardCardFilter.debiti),
                                  onTap: () => _toggleCardFilter(_DashboardCardFilter.debiti),
                                ),
                                _SummaryCard(
                                  title: 'In scadenza',
                                  value: expiring.length.toString(),
                                  icon: Icons.warning_amber_rounded,
                                  accent: AppColors.amber,
                                  isSelected: _activeCardFilters.contains(_DashboardCardFilter.scadenze),
                                  onTap: () => _toggleCardFilter(_DashboardCardFilter.scadenze),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: SizedBox(
                            width: cardsBlockWidth,
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                hintText: 'Cerca assistito',
                                hintStyle: const TextStyle(color: Colors.white54),
                                prefixIcon: const Icon(Icons.search, size: 20),
                                filled: true,
                                fillColor: AppColors.panel,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: _openAddPatientDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Nuovo assistito'),
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                    );
                  },
                ),
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
                    child: LayoutBuilder(
                      builder: (context, tableConstraints) {
                        final double sideInset = math.min(220, math.max(24, tableConstraints.maxWidth * 0.12));
                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: sideInset),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

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
                          child: Builder(
                            builder: (context) {
                              final orderedSummaries = [...summaries]..sort((a, b) {
                                if (a.hasExpiryAlert == b.hasExpiryAlert) return 0;
                                return a.hasExpiryAlert ? -1 : 1;
                              });
                              if (orderedSummaries.isEmpty) {
                                return const Center(child: Text('Nessun assistito.', style: TextStyle(color: Colors.white70, fontSize: 18)));
                              }
                              return ListView.separated(
                                itemCount: orderedSummaries.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                    final item = orderedSummaries[index];
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
                                );
                            },
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

  Widget _dialogField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      onChanged: onChanged,
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
  final List<String> doctorsCatalog;

  const _DashboardData({required this.summaries, required this.doctorsCatalog});
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

  bool get hasActiveContent => recipeCount > 0 || hasDpc || debts.isNotEmpty || advances.isNotEmpty || bookings.isNotEmpty;

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
    final prescriptionDoctor = prescriptions.map((e) => e.doctorName?.trim() ?? '').firstWhere((e) => e.isNotEmpty, orElse: () => '');
    final importDoctor = matchingImports.map((e) => e.doctorFullName.trim()).firstWhere((e) => e.isNotEmpty, orElse: () => '');
    final doctorName = matchingDoctor.isNotEmpty
        ? matchingDoctor.first.doctorName.trim()
        : ((patient.doctorName ?? '').trim().isNotEmpty
            ? patient.doctorName!.trim()
            : (prescriptionDoctor.isNotEmpty ? prescriptionDoctor : importDoctor));
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


class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accent;
  final bool isSelected;
  final VoidCallback onTap;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _DashboardCardFilter { assistiti, ricette, dpc, debiti, anticipi, prenotazioni, scadenze }

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
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15.5),
        ),
      ),
    );
  }
}

const TextStyle _headStyle = TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 15);
