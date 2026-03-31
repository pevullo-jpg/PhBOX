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
import '../../../data/models/family_group.dart';
import '../../../data/models/patient.dart';
import '../../../data/models/prescription.dart';
import '../../../data/repositories/advances_repository.dart';
import '../../../data/repositories/bookings_repository.dart';
import '../../../data/repositories/debts_repository.dart';
import '../../../data/repositories/doctor_patient_links_repository.dart';
import '../../../data/repositories/drive_pdf_imports_repository.dart';
import '../../../data/repositories/family_groups_repository.dart';
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
  late final FamilyGroupsRepository _familyGroupsRepository;
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
    _familyGroupsRepository = FamilyGroupsRepository(datasource: datasource);
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
    final families = await _familyGroupsRepository.getAllFamilies();
    final settings = await _settingsRepository.getSettings();

    final summaries = await Future.wait(
      patients.map((patient) async {
        final prescriptions = await _prescriptionsRepository.getPatientPrescriptions(patient.fiscalCode);
        final debts = patient.debts;
        final advances = patient.advances;
        final bookings = patient.bookings;
        return _PatientDashboardSummary.build(
          patient: patient,
          prescriptions: prescriptions,
          imports: const [],
          debts: debts,
          advances: advances,
          bookings: bookings,
          doctorLinks: const [],
          families: families,
        );
      }),
    );

    summaries.sort((a, b) {
      if (a.hasExpiryAlert != b.hasExpiryAlert) {
        return a.hasExpiryAlert ? -1 : 1;
      }
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });

    return _DashboardData(
      summaries: summaries,
      doctorsCatalog: settings.doctorsCatalog,
      families: families,
    );
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  List<_PatientDashboardSummary> _applyFilters(List<_PatientDashboardSummary> input, List<FamilyGroup> families) {
    final query = _searchController.text.trim().toLowerCase();

    bool matchesCardFilters(_PatientDashboardSummary item) {
      final activeFilters = _activeCardFilters.toList();
      if (activeFilters.isEmpty) return true;
      for (final filter in activeFilters) {
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
        }
      }
      return true;
    }

    bool matchesSearch(_PatientDashboardSummary item) {
      if (query.isEmpty) return true;
      return item.displayName.toLowerCase().contains(query) ||
          item.patient.fiscalCode.toLowerCase().contains(query) ||
          item.doctorName.toLowerCase().contains(query) ||
          item.exemptionCode.toLowerCase().contains(query) ||
          item.city.toLowerCase().contains(query);
    }

    final filtered = input.where(matchesCardFilters).toList();
    if (query.isEmpty) return filtered;

    final Map<String, _PatientDashboardSummary> byCf = {
      for (final item in filtered) item.patient.fiscalCode.trim().toUpperCase(): item,
    };

    final Set<String> resultCfs = filtered.where(matchesSearch).map((item) => item.patient.fiscalCode.trim().toUpperCase()).toSet();

    final Set<String> matchingFamilies = <String>{};
    for (final family in families) {
      final members = family.memberFiscalCodes.map((e) => e.trim().toUpperCase()).toSet();
      final hasMemberMatch = members.any((cf) => resultCfs.contains(cf));
      if (hasMemberMatch) {
        matchingFamilies.add(family.id);
        resultCfs.addAll(members.where(byCf.containsKey));
      }
    }

    final result = filtered.where((item) => resultCfs.contains(item.patient.fiscalCode.trim().toUpperCase())).toList();
    result.sort((a, b) {
      final aInFamily = matchingFamilies.contains(a.familyId);
      final bInFamily = matchingFamilies.contains(b.familyId);
      if (aInFamily != bInFamily) return aInFamily ? -1 : 1;
      if (a.hasExpiryAlert != b.hasExpiryAlert) return a.hasExpiryAlert ? -1 : 1;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    return result;
  }


  void _toggleCardFilter(_DashboardCardFilter filter) {
    setState(() {
      if (_activeCardFilters.contains(filter)) {
        _activeCardFilters.remove(filter);
        return;
      }

      _activeCardFilters.add(filter);
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
                            '${_formatDate(item.prescriptionDate ?? item.createdAt)} · ${item.doctorFullName.trim().isEmpty ? '-' : item.doctorFullName.trim()}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                tooltip: 'Elimina ricetta',
                                onPressed: () async {
                                  final bool confirmed = await _confirmDeleteRecipe(item);
                                  if (!confirmed) return;
                                  await _prescriptionsRepository.requestDeletionForImport(item.patientFiscalCode, item.id);
                                  if (mounted) {
                                    Navigator.of(context).pop();
                                    _refresh();
                                  }
                                },
                                icon: const Icon(Icons.delete_outline, color: AppColors.red),
                              ),
                              TextButton(
                                onPressed: () => _openPdf(item),
                                child: const Text('Apri'),
                              ),
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
        );
      },
    );
  }


  Future<bool> _confirmDeleteRecipe(DrivePdfImport item) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Elimina ricetta', style: TextStyle(color: Colors.white)),
        content: Text(
          'La ricetta ${item.fileName} verrà rimossa dalla dashboard mantenendo i dati estratti nel database. Continuare?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annulla', style: TextStyle(color: Colors.white70))),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Elimina')),
        ],
      ),
    );
    return confirmed == true;
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
      final String normalizedDoctor = selectedDoctor.trim();
      await _advancesRepository.saveAdvance(
        Advance(
          id: 'adv_${now.microsecondsSinceEpoch}',
          patientFiscalCode: summary.patient.fiscalCode,
          patientName: summary.patient.fullName,
          drugName: drugController.text.trim(),
          doctorName: normalizedDoctor,
          note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await _doctorPatientLinksRepository.saveLink(
        patientFiscalCode: summary.patient.fiscalCode,
        patientFullName: summary.patient.fullName,
        doctorFullName: normalizedDoctor,
        city: summary.city == '-' ? null : summary.city,
      );
      final Patient refreshedPatient = summary.patient.copyWith(doctorName: normalizedDoctor, updatedAt: now);
      await _patientsRepository.savePatient(refreshedPatient);
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
    final data = await _future!;
    final doctorsCatalog = data.doctorsCatalog.map((e) => e.trim()).where((e) => e.isNotEmpty).toList()..sort();

    final debtDescriptionController = TextEditingController();
    final debtAmountController = TextEditingController();
    final debtNoteController = TextEditingController();

    final advanceDrugController = TextEditingController();
    final advanceNoteController = TextEditingController();

    final bookingDrugController = TextEditingController();
    final bookingQuantityController = TextEditingController(text: '1');
    final bookingNoteController = TextEditingController();

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          _PatientDashboardSummary currentSummary = summary;
          bool busy = false;
          bool showAddForm = false;
          String formError = '';
          String selectedDoctor = summary.doctorName.trim() == '-' ? '' : summary.doctorName.trim();

          Future<void> reload(StateSetter setLocalState) async {
            final refreshed = await _reloadSummary(summary.patient.fiscalCode);
            setLocalState(() {
              if (refreshed != null) {
                currentSummary = refreshed;
              }
              busy = false;
            });
          }

          Future<void> runBusyAction(StateSetter setLocalState, Future<void> Function() action) async {
            setLocalState(() => busy = true);
            try {
              await action();
            } finally {
              await reload(setLocalState);
            }
          }

          void clearInlineForm() {
            debtDescriptionController.clear();
            debtAmountController.clear();
            debtNoteController.clear();
            advanceDrugController.clear();
            advanceNoteController.clear();
            bookingDrugController.clear();
            bookingQuantityController.text = '1';
            bookingNoteController.clear();
            formError = '';
            selectedDoctor = currentSummary.doctorName.trim() == '-' ? '' : currentSummary.doctorName.trim();
          }

          Future<void> saveInlineForm(StateSetter setLocalState) async {
            final now = DateTime.now();
            final fiscalCode = currentSummary.patient.fiscalCode;
            final patientName = currentSummary.patient.fullName;

            try {
              if (key == 'debiti') {
                final description = debtDescriptionController.text.trim();
                final amount = double.tryParse(debtAmountController.text.trim().replaceAll(',', '.')) ?? 0;
                if (description.isEmpty || amount <= 0) {
                  setLocalState(() => formError = 'Inserisci causale e importo validi.');
                  return;
                }
                await _debtsRepository.saveDebt(
                  Debt(
                    id: 'debt_${now.microsecondsSinceEpoch}',
                    patientFiscalCode: fiscalCode,
                    patientName: patientName,
                    description: description,
                    amount: amount,
                    paidAmount: 0,
                    residualAmount: amount,
                    createdAt: now,
                    dueDate: now,
                    note: debtNoteController.text.trim().isEmpty ? null : debtNoteController.text.trim(),
                  ),
                );
              } else if (key == 'anticipi') {
                final drugName = advanceDrugController.text.trim();
                final doctorName = selectedDoctor.trim();
                if (drugName.isEmpty || doctorName.isEmpty) {
                  setLocalState(() => formError = 'Inserisci farmaco e medico.');
                  return;
                }
                await _advancesRepository.saveAdvance(
                  Advance(
                    id: 'adv_${now.microsecondsSinceEpoch}',
                    patientFiscalCode: fiscalCode,
                    patientName: patientName,
                    drugName: drugName,
                    doctorName: doctorName,
                    note: advanceNoteController.text.trim().isEmpty ? null : advanceNoteController.text.trim(),
                    createdAt: now,
                    updatedAt: now,
                  ),
                );
              } else {
                final drugName = bookingDrugController.text.trim();
                final quantity = int.tryParse(bookingQuantityController.text.trim()) ?? 1;
                if (drugName.isEmpty || quantity <= 0) {
                  setLocalState(() => formError = 'Inserisci farmaco e quantità valide.');
                  return;
                }
                await _bookingsRepository.saveBooking(
                  Booking(
                    id: 'book_${now.microsecondsSinceEpoch}',
                    patientFiscalCode: fiscalCode,
                    patientName: patientName,
                    drugName: drugName,
                    quantity: quantity,
                    createdAt: now,
                    expectedDate: now,
                    note: bookingNoteController.text.trim().isEmpty ? null : bookingNoteController.text.trim(),
                  ),
                );
              }

              _refresh();
              setLocalState(() {
                showAddForm = false;
                clearInlineForm();
              });
              await runBusyAction(setLocalState, () async {});
            } catch (e) {
              setLocalState(() {
                formError = 'Errore salvataggio: $e';
              });
            }
          }

          List<_FlagItem> buildItems(StateSetter setLocalState) {
            if (key == 'debiti') {
              return currentSummary.debts
                  .map((item) => _FlagItem(
                        title: '${item.description} · € ${item.residualAmount.toStringAsFixed(2)}',
                        subtitle: 'Inserito ${_formatDate(item.createdAt)}${item.note == null || item.note!.trim().isEmpty ? '' : ' · ${item.note!.trim()}'}',
                        onDelete: () async {
                          await runBusyAction(setLocalState, () async {
                            await _debtsRepository.deleteDebt(currentSummary.patient.fiscalCode, item.id);
                            _refresh();
                          });
                        },
                      ))
                  .toList();
            }
            if (key == 'anticipi') {
              return currentSummary.advances
                  .map((item) => _FlagItem(
                        title: item.drugName,
                        subtitle: '${item.doctorName.isEmpty ? '-' : item.doctorName} · ${_formatDate(item.createdAt)}${item.note == null || item.note!.trim().isEmpty ? '' : ' · ${item.note!.trim()}'}',
                        onDelete: () async {
                          await runBusyAction(setLocalState, () async {
                            await _advancesRepository.deleteAdvance(currentSummary.patient.fiscalCode, item.id);
                            _refresh();
                          });
                        },
                      ))
                  .toList();
            }
            return currentSummary.bookings
                .map((item) => _FlagItem(
                      title: '${item.drugName} x${item.quantity}',
                      subtitle: 'Registrata ${_formatDate(item.createdAt)} · Prevista ${_formatDate(item.expectedDate)}${item.note == null || item.note!.trim().isEmpty ? '' : ' · ${item.note!.trim()}'}',
                      onDelete: () async {
                        await runBusyAction(setLocalState, () async {
                          await _bookingsRepository.deleteBooking(currentSummary.patient.fiscalCode, item.id);
                          _refresh();
                        });
                      },
                    ))
                .toList();
          }

          String modalTitle() {
            if (key == 'debiti') return 'Debiti · ${currentSummary.displayName}';
            if (key == 'anticipi') return 'Anticipi · ${currentSummary.displayName}';
            return 'Prenotazioni · ${currentSummary.displayName}';
          }

          Widget buildInlineForm(StateSetter setLocalState) {
            if (!showAddForm) return const SizedBox.shrink();
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.panelSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    key == 'debiti' ? 'Nuovo debito' : key == 'anticipi' ? 'Nuovo anticipo' : 'Nuova prenotazione',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  if (key == 'debiti') ...[
                    _dialogField(debtDescriptionController, 'Causale'),
                    const SizedBox(height: 12),
                    _dialogField(
                      debtAmountController,
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
                    _dialogField(debtNoteController, 'Nota', maxLines: 3),
                  ] else if (key == 'anticipi') ...[
                    _dialogField(advanceDrugController, 'Farmaco / articolo'),
                  ] else ...[
                    _dialogField(bookingDrugController, 'Farmaco / articolo'),
                    const SizedBox(height: 12),
                    _dialogField(
                      bookingQuantityController,
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
                    _dialogField(bookingNoteController, 'Nota', maxLines: 3),
                  ],
                  if (key == 'anticipi') ...[
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
                      items: ((<String>{...doctorsCatalog, if (selectedDoctor.isNotEmpty) selectedDoctor}.toList())..sort())
                          .map((item) => DropdownMenuItem<String>(value: item, child: Text(item)))
                          .toList(),
                      onChanged: (value) => setLocalState(() => selectedDoctor = value ?? ''),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Data registrazione: ${_formatDate(DateTime.now())}', style: const TextStyle(color: Colors.white70)),
                    ),
                    const SizedBox(height: 12),
                    _dialogField(advanceNoteController, 'Nota', maxLines: 3),
                  ],
                  if (formError.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(formError, style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: busy
                            ? null
                            : () {
                                setLocalState(() {
                                  showAddForm = false;
                                  clearInlineForm();
                                });
                              },
                        child: const Text('Annulla', style: TextStyle(color: Colors.white70)),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: busy ? null : () => saveInlineForm(setLocalState),
                        child: const Text('Salva'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          return StatefulBuilder(
            builder: (context, setLocalState) {
              Widget headerAction = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: showAddForm
                        ? 'Chiudi inserimento'
                        : key == 'debiti'
                            ? 'Nuovo debito'
                            : key == 'anticipi'
                                ? 'Nuovo anticipo'
                                : 'Nuova prenotazione',
                    onPressed: busy
                        ? null
                        : () {
                            setLocalState(() {
                              showAddForm = !showAddForm;
                              if (!showAddForm) clearInlineForm();
                              formError = '';
                            });
                          },
                    icon: Icon(showAddForm ? Icons.remove_circle_outline : Icons.add_circle_outline, color: AppColors.green),
                  ),
                  IconButton(
                    tooltip: 'Elimina tutto',
                    onPressed: busy
                        ? null
                        : () => runBusyAction(setLocalState, () async {
                              if (key == 'debiti') {
                                for (final item in currentSummary.debts) {
                                  await _debtsRepository.deleteDebt(currentSummary.patient.fiscalCode, item.id);
                                }
                              } else if (key == 'anticipi') {
                                for (final item in currentSummary.advances) {
                                  await _advancesRepository.deleteAdvance(currentSummary.patient.fiscalCode, item.id);
                                }
                              } else {
                                for (final item in currentSummary.bookings) {
                                  await _bookingsRepository.deleteBooking(currentSummary.patient.fiscalCode, item.id);
                                }
                              }
                              _refresh();
                            }),
                    icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.red),
                  ),
                ],
              );
              return Stack(
                children: [
                  _buildFlagDialog(
                    title: modalTitle(),
                    items: buildItems(setLocalState),
                    headerAction: headerAction,
                    inlineTop: buildInlineForm(setLocalState),
                    dialogContext: dialogContext,
                  ),
                  if (busy)
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Color(0x66000000),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                ],
              );
            },
          );
        },
      );
    } finally {
      debtDescriptionController.dispose();
      debtAmountController.dispose();
      debtNoteController.dispose();
      advanceDrugController.dispose();
      advanceNoteController.dispose();
      bookingDrugController.dispose();
      bookingQuantityController.dispose();
      bookingNoteController.dispose();
    }
  }

  Widget _buildFlagDialog({
    required String title,
    required List<_FlagItem> items,
    Widget? headerAction,
    Widget? inlineTop,
    BuildContext? dialogContext,
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
                    onPressed: () => Navigator.of(dialogContext ?? context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (inlineTop != null) ...[
                inlineTop,
                const SizedBox(height: 4),
              ],
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
                                      onPressed: item.onDelete == null ? null : () async { await item.onDelete!.call(); },
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
    if (key == 'quick-edit') {
      final selectedKey = await showDialog<String>(
        context: context,
        builder: (context) {
          Widget option({required IconData icon, required String label, required String value}) {
            return ListTile(
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white12,
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              title: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              onTap: () => Navigator.of(context).pop(value),
            );
          }

          return AlertDialog(
            backgroundColor: AppColors.panel,
            title: Text('Apri gestione · ${summary.displayName}', style: const TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                option(icon: Icons.account_balance_wallet_outlined, label: 'Debiti', value: 'debiti'),
                option(icon: Icons.payments_outlined, label: 'Anticipi', value: 'anticipi'),
                option(icon: Icons.event_note_outlined, label: 'Prenotazioni', value: 'prenotazioni'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Chiudi', style: TextStyle(color: Colors.white70)),
              ),
            ],
          );
        },
      );
      if (selectedKey != null && mounted) {
        await _openEditableFlagModal(summary: summary, key: selectedKey);
      }
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
    final fiscalCodeFocusNode = FocusNode();
    final nameController = TextEditingController();
    final surnameController = TextEditingController();
    final advanceController = TextEditingController();
    final bookingController = TextEditingController();
    final debtController = TextEditingController();
    final debtDescriptionController = TextEditingController();
    String selectedDoctor = '';
    final doctorCandidates = data.doctorsCatalog.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList()..sort();

    List<String> _splitPatientName(String fullName) {
      final parts = fullName.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
      if (parts.isEmpty) return const ['', ''];
      if (parts.length == 1) return [parts.first, ''];
      return [parts.first, parts.skip(1).join(' ')];
    }

    _PatientDashboardSummary? _findExactPatientByCf(String rawValue) {
      final normalizedCf = rawValue.trim().toUpperCase();
      for (final summary in data.summaries) {
        if (summary.patient.fiscalCode.trim().toUpperCase() == normalizedCf) {
          return summary;
        }
      }
      return null;
    }

    List<_PatientDashboardSummary> _findPatientSuggestions(String rawValue) {
      final normalizedQuery = rawValue.trim().toUpperCase();
      if (normalizedQuery.isEmpty) return const [];
      final startsWithMatches = <_PatientDashboardSummary>[];
      final containsMatches = <_PatientDashboardSummary>[];
      for (final summary in data.summaries) {
        final patientCf = summary.patient.fiscalCode.trim().toUpperCase();
        if (patientCf.isEmpty) continue;
        if (patientCf.startsWith(normalizedQuery)) {
          startsWithMatches.add(summary);
        } else if (patientCf.contains(normalizedQuery)) {
          containsMatches.add(summary);
        }
      }
      final allMatches = [...startsWithMatches, ...containsMatches];
      if (allMatches.length <= 6) return allMatches;
      return allMatches.take(6).toList();
    }

    void _applyPatientSuggestion(_PatientDashboardSummary summary, void Function(void Function()) setLocalState) {
      final normalizedCf = summary.patient.fiscalCode.trim().toUpperCase();
      final nameParts = _splitPatientName(summary.patient.fullName);
      final doctorFromMemory = summary.doctorName.trim();
      setLocalState(() {
        fiscalCodeController.value = fiscalCodeController.value.copyWith(
          text: normalizedCf,
          selection: TextSelection.collapsed(offset: normalizedCf.length),
          composing: TextRange.empty,
        );
        if (nameParts.first.isNotEmpty) {
          nameController.text = nameParts.first;
        }
        if (nameParts.last.isNotEmpty) {
          surnameController.text = nameParts.last;
        }
        if (doctorFromMemory.isNotEmpty && doctorFromMemory != '-' && doctorCandidates.contains(doctorFromMemory)) {
          selectedDoctor = doctorFromMemory;
        }
      });
    }

    void fillFromExistingPatient(String rawValue, void Function(void Function()) setLocalState) {
      final normalizedCf = rawValue.trim().toUpperCase();
      if (fiscalCodeController.text != normalizedCf) {
        fiscalCodeController.value = fiscalCodeController.value.copyWith(
          text: normalizedCf,
          selection: TextSelection.collapsed(offset: normalizedCf.length),
          composing: TextRange.empty,
        );
      }
      final existing = _findExactPatientByCf(normalizedCf);
      if (existing != null) {
        _applyPatientSuggestion(existing, setLocalState);
      }
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
                      RawAutocomplete<_PatientDashboardSummary>(
                        textEditingController: fiscalCodeController,
                        focusNode: fiscalCodeFocusNode,
                        displayStringForOption: (option) => option.patient.fiscalCode.trim().toUpperCase(),
                        optionsBuilder: (textEditingValue) {
                          return _findPatientSuggestions(textEditingValue.text);
                        },
                        onSelected: (selection) {
                          _applyPatientSuggestion(selection, setLocalState);
                        },
                        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                          return _dialogField(
                            textEditingController,
                            'Codice fiscale',
                            focusNode: focusNode,
                            onChanged: (value) => fillFromExistingPatient(value, setLocalState),
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          final optionList = options.toList(growable: false);
                          if (optionList.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              color: Colors.transparent,
                              child: Container(
                                width: 460,
                                margin: const EdgeInsets.only(top: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.panelSoft,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: ListView.separated(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: optionList.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
                                  itemBuilder: (context, index) {
                                    final option = optionList[index];
                                    final normalizedCf = option.patient.fiscalCode.trim().toUpperCase();
                                    final displayName = option.patient.fullName.trim().toUpperCase();
                                    return InkWell(
                                      onTap: () => onSelected(option),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(normalizedCf, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                            const SizedBox(height: 2),
                                            Text(displayName, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
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
      fiscalCodeFocusNode.dispose();
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
      fiscalCodeFocusNode.dispose();
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
      await _prescriptionsRepository.requestDeletionForAllPatientPrescriptions(summary.patient.fiscalCode);
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
      await _prescriptionsRepository.refreshPatientAggregates(summary.patient.fiscalCode);
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
        final summaries = data == null ? const <_PatientDashboardSummary>[] : _applyFilters(data.summaries, data.families);
        final expiring = summaries.where((item) => item.hasExpiryAlert).toList();
        final familyState = data == null
            ? _DashboardFamilyState.empty()
            : _DashboardFamilyState.fromFamilies(data.summaries, data.families);
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
                    final double cardsBlockWidth = constraints.maxWidth >= ((cardWidth * 6) + (cardSpacing * 5))
                        ? ((cardWidth * 6) + (cardSpacing * 5))
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
                                  title: 'Anticipi',
                                  value: summaries.fold<int>(0, (sum, item) => sum + item.advances.length).toString(),
                                  icon: Icons.payments_outlined,
                                  accent: AppColors.amber,
                                  isSelected: _activeCardFilters.contains(_DashboardCardFilter.anticipi),
                                  onTap: () => _toggleCardFilter(_DashboardCardFilter.anticipi),
                                ),
                                _SummaryCard(
                                  title: 'Prenotazioni',
                                  value: summaries.fold<int>(0, (sum, item) => sum + item.bookings.length).toString(),
                                  icon: Icons.event_note_outlined,
                                  accent: AppColors.yellow,
                                  isSelected: _activeCardFilters.contains(_DashboardCardFilter.prenotazioni),
                                  onTap: () => _toggleCardFilter(_DashboardCardFilter.prenotazioni),
                                ),
                                _SummaryCard(
                                  title: 'In scadenza',
                                  value: expiring.length.toString(),
                                  icon: Icons.warning_amber_rounded,
                                  accent: AppColors.coral,
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
                                              child: Row(
                                                children: [
                                                  if (item.familyId.isNotEmpty && familyState.hasMultipleActive(item.familyId)) ...[
                                                    Container(
                                                      width: 14,
                                                      height: 14,
                                                      decoration: BoxDecoration(
                                                        color: familyState.colorFor(item.familyId),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                  ],
                                                  Expanded(
                                                    child: Text(
                                                      item.displayName,
                                                      textAlign: TextAlign.left,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(color: Colors.white, fontSize: 18.2, fontWeight: FontWeight.w800),
                                                    ),
                                                  ),
                                                ],
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
                                              item.doctorSurnameUpper,
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
    final widgets = <Widget>[
      _QuickEditFlag(onTap: () => _handleFlagTap(item, 'quick-edit')),
    ];
    if (item.recipeCount > 0 && item.imports.isNotEmpty) {
      widgets.add(
        Container(
          padding: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: AppColors.green,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FlagChip(label: 'ricette ${item.recipeCount}', color: AppColors.green, onTap: () => _handleFlagTap(item, 'ricette')),
              IconButton(
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                visualDensity: VisualDensity.compact,
                tooltip: 'Elimina ricetta',
                onPressed: () => _deleteRecipesFromRow(item),
                icon: const Icon(Icons.delete_outline, color: Colors.white, size: 18),
              ),
            ],
          ),
        ),
      );
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

  Future<void> _deleteRecipesFromRow(_PatientDashboardSummary summary) async {
    if (summary.imports.isEmpty) return;
    if (summary.imports.length == 1) {
      final item = summary.imports.first;
      final confirmed = await _confirmDeleteRecipe(item);
      if (!confirmed) return;
      await _prescriptionsRepository.requestDeletionForImport(item.patientFiscalCode, item.id);
      _refresh();
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) {
          bool busy = false;
          Future<void> handleDelete(DrivePdfImport item) async {
            final confirmed = await _confirmDeleteRecipe(item);
            if (!confirmed) return;
            setLocalState(() => busy = true);
            await _prescriptionsRepository.requestDeletionForImport(item.patientFiscalCode, item.id);
            _refresh();
            setLocalState(() => busy = false);
            if (!mounted) return;
            Navigator.of(dialogContext).pop();
          }
          return Stack(
            children: [
              _buildFlagDialog(
                title: 'Elimina ricette · ${summary.displayName}',
                items: summary.imports.map((item) => _FlagItem(
                  title: item.fileName,
                  subtitle: '${_formatDate(item.prescriptionDate ?? item.createdAt)} · ${item.doctorFullName.trim().isEmpty ? '-' : item.doctorFullName.trim()}',
                  onDelete: () => handleDelete(item),
                )).toList(),
                dialogContext: dialogContext,
              ),
              if (busy) const Positioned.fill(child: ColoredBox(color: Color(0x66000000), child: Center(child: CircularProgressIndicator()))),
            ],
          );
        },
      ),
    );
  }


  Widget _dialogField(
    TextEditingController controller,
    String label, {
    FocusNode? focusNode,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
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
  final List<FamilyGroup> families;

  const _DashboardData({
    required this.summaries,
    required this.doctorsCatalog,
    required this.families,
  });
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
  final String familyId;

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
    required this.familyId,
  });

  String get displayName => patient.fullName.trim().isEmpty ? patient.fiscalCode : patient.fullName.trim();

  double get totalDebt => debts.fold<double>(0, (sum, item) => sum + item.residualAmount);

  String get doctorNameUpper => doctorName.trim().isEmpty ? '-' : doctorName.trim().toUpperCase();
  String get doctorSurnameUpper {
    final String cleaned = doctorName.trim();
    if (cleaned.isEmpty || cleaned == '-') return '-';
    return cleaned.toUpperCase();
  }

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
    required List<FamilyGroup> families,
  }) {
    final normalizedFiscalCode = patient.fiscalCode.trim().toUpperCase();
    final normalizedFullName = patient.fullName.trim().toUpperCase();
    final matchingImports = imports.where((item) {
      final importFiscalCode = item.patientFiscalCode.trim().toUpperCase();
      final importFullName = item.patientFullName.trim().toUpperCase();
      if (item.isInactiveForActiveFlows) return false;
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
    final linkDoctorFull = matchingDoctor.map((e) => e.doctorFullName.trim()).firstWhere((e) => e.isNotEmpty, orElse: () => '');
    final patientDoctor = (patient.doctorName ?? '').trim();
    final doctorName = linkDoctorFull.isNotEmpty
        ? linkDoctorFull
        : (patientDoctor.isNotEmpty
            ? patientDoctor
            : (importDoctor.isNotEmpty ? importDoctor : prescriptionDoctor));
    final exemptionCode = patient.normalizedExemptions.isNotEmpty
        ? patient.exemptionsDisplay
        : (() {
            final List<String> observed = Patient.normalizeExemptionValues(<dynamic>[
              ...prescriptions.map((e) => e.exemptionCode),
              ...matchingImports.map((e) => e.exemptionCode),
            ]);
            return observed.isEmpty ? '-' : observed.join(', ');
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
    final recipeCount = importsRecipeCount > 0
        ? importsRecipeCount
        : (prescriptionsRecipeCount > 0 ? prescriptionsRecipeCount : (matchingImports.isNotEmpty ? matchingImports.length : 0));
    final hasDpc = prescriptions.any((item) => item.dpcFlag) || matchingImports.any((item) => item.isDpc);
    final hasExpiryAlert = prescriptions.any((item) {
      final info = PrescriptionExpiryUtils.evaluate(item.expiryDate);
      return info.status == PrescriptionValidityStatus.expiringSoon || info.status == PrescriptionValidityStatus.expired;
    });
    final familyId = (() {
      for (final family in families) {
        if (family.memberFiscalCodes.map((e) => e.trim().toUpperCase()).contains(normalizedFiscalCode)) {
          return family.id;
        }
      }
      return '';
    })();
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
      familyId: familyId,
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



class _DashboardFamilyState {
  final Map<String, int> activeCounts;
  final Map<String, Color> colors;

  const _DashboardFamilyState({required this.activeCounts, required this.colors});

  factory _DashboardFamilyState.empty() => const _DashboardFamilyState(activeCounts: <String, int>{}, colors: <String, Color>{});

  factory _DashboardFamilyState.fromFamilies(List<_PatientDashboardSummary> summaries, List<FamilyGroup> families) {
    const palette = <Color>[
      Color(0xFF2563EB),
      Color(0xFF059669),
      Color(0xFFD97706),
      Color(0xFFDC2626),
      Color(0xFF7C3AED),
      Color(0xFF0891B2),
      Color(0xFF65A30D),
      Color(0xFFEA580C),
    ];
    final counts = <String, int>{};
    final colors = <String, Color>{};
    for (final family in families) {
      final activeCount = summaries.where((item) => item.familyId == family.id && item.hasActiveContent).length;
      counts[family.id] = activeCount;
      colors[family.id] = palette[family.colorIndex % palette.length];
    }
    return _DashboardFamilyState(activeCounts: counts, colors: colors);
  }

  bool hasMultipleActive(String familyId) => (activeCounts[familyId] ?? 0) > 1;

  Color colorFor(String familyId) => colors[familyId] ?? AppColors.yellow;
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

enum _DashboardCardFilter { ricette, dpc, debiti, anticipi, prenotazioni, scadenze }

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

class _QuickEditFlag extends StatelessWidget {
  final VoidCallback onTap;

  const _QuickEditFlag({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Apri gestione',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: Color(0xFF7A7A7A),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

const TextStyle _headStyle = TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 15);
