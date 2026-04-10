import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/patient_identity_utils.dart';
import '../../../core/utils/phbox_contract_utils.dart';
import '../../../core/utils/prescription_expiry_utils.dart';
import '../../../data/datasources/firestore_firebase_datasource.dart';
import '../../../data/models/advance.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/debt.dart';
import '../../../data/models/doctor_patient_link.dart';
import '../../../data/models/drive_pdf_import.dart';
import '../../../data/models/family_group.dart';
import '../../../data/models/patient.dart';
import '../../../data/models/prescription.dart';
import '../../../data/models/prescription_item.dart';
import '../../../data/models/therapeutic_advice_note.dart';
import '../../../data/repositories/advances_repository.dart';
import '../../../data/repositories/bookings_repository.dart';
import '../../../data/repositories/debts_repository.dart';
import '../../../data/repositories/doctor_patient_links_repository.dart';
import '../../../data/repositories/drive_pdf_imports_repository.dart';
import '../../../data/repositories/family_groups_repository.dart';
import '../../../data/repositories/patients_repository.dart';
import '../../../data/repositories/prescriptions_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/repositories/therapeutic_advice_repository.dart';
import '../../../shared/navigation/app_navigation.dart';
import '../../../shared/widgets/floating_page_menu.dart';
import '../../../theme/app_theme.dart';

class PatientDetailPage extends StatefulWidget {
  final String fiscalCode;

  const PatientDetailPage({super.key, required this.fiscalCode});

  @override
  State<PatientDetailPage> createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends State<PatientDetailPage> {
  static const List<Color> _familyPalette = <Color>[
    Color(0xFF2563EB),
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFFDC2626),
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
    Color(0xFF65A30D),
    Color(0xFFEA580C),
  ];

  late final PatientsRepository _patientsRepository;
  late final AdvancesRepository _advancesRepository;
  late final DebtsRepository _debtsRepository;
  late final BookingsRepository _bookingsRepository;
  late final PrescriptionsRepository _prescriptionsRepository;
  late final DrivePdfImportsRepository _drivePdfImportsRepository;
  late final SettingsRepository _settingsRepository;
  late final DoctorPatientLinksRepository _doctorPatientLinksRepository;
  late final TherapeuticAdviceRepository _therapeuticAdviceRepository;
  late final FamilyGroupsRepository _familyGroupsRepository;

  Future<_PatientDetailData>? _future;
  String _message = '';

  @override
  void initState() {
    super.initState();
    final datasource = FirestoreFirebaseDatasource(FirebaseFirestore.instance);
    _patientsRepository = PatientsRepository(datasource: datasource);
    _advancesRepository = AdvancesRepository(datasource: datasource);
    _debtsRepository = DebtsRepository(datasource: datasource);
    _bookingsRepository = BookingsRepository(datasource: datasource);
    _prescriptionsRepository = PrescriptionsRepository(datasource: datasource);
    _drivePdfImportsRepository = DrivePdfImportsRepository(datasource: datasource);
    _settingsRepository = SettingsRepository(datasource: datasource);
    _doctorPatientLinksRepository = DoctorPatientLinksRepository(datasource: datasource);
    _therapeuticAdviceRepository = TherapeuticAdviceRepository(datasource: datasource);
    _familyGroupsRepository = FamilyGroupsRepository(datasource: datasource);
    _future = _load();
  }

  Future<_PatientDetailData> _load() async {
    final Patient? patient = await _patientsRepository.getPatientByFiscalCode(widget.fiscalCode);
    final List<Advance> advances = await _advancesRepository.getPatientAdvances(widget.fiscalCode);
    final List<Debt> debts = await _debtsRepository.getPatientDebts(widget.fiscalCode);
    final List<Booking> bookings = await _bookingsRepository.getPatientBookings(widget.fiscalCode);
    final List<Prescription> prescriptions = await _prescriptionsRepository.getPatientPrescriptions(widget.fiscalCode);
    final List<DrivePdfImport> allImports = await _drivePdfImportsRepository.getImportsByPatient(
      widget.fiscalCode,
      includeHidden: true,
    );
    final List<DrivePdfImport> imports = allImports.where((DrivePdfImport item) {
      return !item.isHiddenFromFrontend;
    }).toList();
    final List<DoctorPatientLink> doctorLinks = await _doctorPatientLinksRepository.getAllLinks();
    final AppSettings settings = await _settingsRepository.getSettings();
    final TherapeuticAdviceNote? therapeuticAdvice = await _therapeuticAdviceRepository.getByFiscalCode(widget.fiscalCode);
    final List<FamilyGroup> allFamilies = await _familyGroupsRepository.getAllFamilies();
    final List<Patient> allPatients = patient == null ? const <Patient>[] : await _patientsRepository.getAllPatients();

    final String doctorName = _resolveDoctor(
      patient: patient,
      doctorLinks: doctorLinks,
      prescriptions: prescriptions,
      imports: imports,
    );
    final _ResolvedFamily family = _resolveFamily(
      patient: patient,
      allFamilies: allFamilies,
      allPatients: allPatients,
    );

    advances.sort((Advance a, Advance b) => b.updatedAt.compareTo(a.updatedAt));
    debts.sort((Debt a, Debt b) {
      final DateTime aDate = a.dueDate ?? a.createdAt;
      final DateTime bDate = b.dueDate ?? b.createdAt;
      return bDate.compareTo(aDate);
    });
    bookings.sort((Booking a, Booking b) {
      final DateTime aDate = a.expectedDate ?? a.createdAt;
      final DateTime bDate = b.expectedDate ?? b.createdAt;
      return aDate.compareTo(bDate);
    });

    return _PatientDetailData(
      patient: patient,
      advances: advances,
      debts: debts,
      bookings: bookings,
      prescriptions: prescriptions,
      imports: imports,
      allImports: allImports,
      settings: settings,
      resolvedDoctorName: doctorName,
      therapeuticAdvice: therapeuticAdvice,
      family: family.group,
      familyMembers: family.members,
      familyColor: family.color,
    );
  }

  _ResolvedFamily _resolveFamily({
    required Patient? patient,
    required List<FamilyGroup> allFamilies,
    required List<Patient> allPatients,
  }) {
    if (patient == null) {
      return const _ResolvedFamily.empty();
    }
    final String normalizedFiscalCode = patient.fiscalCode.trim().toUpperCase();
    FamilyGroup? family;
    for (final FamilyGroup current in allFamilies) {
      if (current.memberFiscalCodes.map((String value) => value.trim().toUpperCase()).contains(normalizedFiscalCode)) {
        family = current;
        break;
      }
    }
    if (family == null) {
      return const _ResolvedFamily.empty();
    }

    final Map<String, Patient> patientByCf = <String, Patient>{
      for (final Patient item in allPatients) item.fiscalCode.trim().toUpperCase(): item,
    };
    final List<_FamilyMemberData> members = family.memberFiscalCodes.map((String fiscalCode) {
      final String normalized = fiscalCode.trim().toUpperCase();
      final Patient? related = patientByCf[normalized];
      return _FamilyMemberData(
        fiscalCode: normalized,
        fullName: related?.fullName ?? '',
        isCurrent: normalized == normalizedFiscalCode,
      );
    }).toList();
    members.sort((_FamilyMemberData a, _FamilyMemberData b) {
      if (a.isCurrent && !b.isCurrent) return -1;
      if (!a.isCurrent && b.isCurrent) return 1;
      return a.displayName.compareTo(b.displayName);
    });

    return _ResolvedFamily(
      group: family,
      members: members,
      color: _familyPalette[family.colorIndex % _familyPalette.length],
    );
  }

  void _refresh([String? message]) {
    setState(() {
      if (message != null) {
        _message = message;
      }
      _future = _load();
    });
  }

  String _resolveDoctor({
    required Patient? patient,
    required List<DoctorPatientLink> doctorLinks,
    required List<Prescription> prescriptions,
    required List<DrivePdfImport> imports,
  }) {
    return PhboxContractUtils.resolveDoctor(
      fiscalCode: widget.fiscalCode,
      doctorLinks: doctorLinks,
      patientDoctorFullName: patient?.doctorFullName,
      visibleImports: imports,
      legacyPrescriptions: prescriptions,
    );
  }

  Future<void> _openPdf(DrivePdfImport item) async {
    final String directLink = item.effectiveViewLink.trim();
    final String fallbackLink = item.driveFileId.trim().isNotEmpty
        ? 'https://drive.google.com/file/d/${item.driveFileId.trim()}/view'
        : '';
    final String url = directLink.isNotEmpty ? directLink : fallbackLink;
    if (url.isEmpty) return;
    await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_blank',
    );
  }

  Future<void> _editTherapeuticAdvice(_PatientDetailData data) async {
    final Patient? patient = data.patient;
    if (patient == null) return;
    final TextEditingController controller = TextEditingController(text: data.therapeuticAdvice?.text ?? '');
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Consigli terapeutici', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 560,
          child: _dialogField(
            controller,
            'Note libere di presa in carico',
            maxLines: 12,
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
      ),
    );
    if (confirmed != true) {
      controller.dispose();
      return;
    }
    try {
      final String textValue = controller.text.trim();
      if (textValue.isEmpty) {
        await _therapeuticAdviceRepository.clear(patient.fiscalCode);
        _refresh('Consigli terapeutici rimossi.');
      } else {
        await _therapeuticAdviceRepository.save(
          fiscalCode: patient.fiscalCode,
          text: textValue,
        );
        _refresh('Consigli terapeutici salvati.');
      }
    } catch (e) {
      setState(() => _message = 'Errore salvataggio consigli terapeutici: $e');
    } finally {
      controller.dispose();
    }
  }

  Future<void> _clearTherapeuticAdvice(_PatientDetailData data) async {
    final Patient? patient = data.patient;
    if (patient == null || data.therapeuticAdvice == null) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Rimuovi consigli terapeutici', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Il testo libero associato a questo assistito verrà eliminato. Continuare?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla', style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _therapeuticAdviceRepository.clear(patient.fiscalCode);
      _refresh('Consigli terapeutici rimossi.');
    } catch (e) {
      setState(() => _message = 'Errore eliminazione consigli terapeutici: $e');
    }
  }

  Future<void> _openManageDialog({
    required String title,
    required List<Widget> children,
    Widget? action,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => Dialog(
        backgroundColor: AppColors.panel,
        child: SizedBox(
          width: 820,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                    ),
                    if (action != null) action,
                  ],
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 560),
                  child: children.isEmpty
                      ? const Text('Nessuna voce.', style: TextStyle(color: Colors.white70))
                      : SingleChildScrollView(child: Column(children: children)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _managePrescriptions(_PatientDetailData data) async {
    await _openManageDialog(
      title: 'Ricette archivistiche',
      children: data.prescriptions.map((Prescription prescription) {
        final DrivePdfImport? matchingImport = _findImportForPrescription(data.imports, prescription.id);
        return _buildPrescriptionCard(
          prescription: prescription,
          importItem: matchingImport,
          compact: true,
        );
      }).toList(),
    );
  }

  Future<void> _manageDebts(_PatientDetailData data) async {
    final Patient? patient = data.patient;
    if (patient == null) return;
    await _openManageDialog(
      title: 'Debiti',
      action: FilledButton.icon(
        onPressed: () {
          Navigator.of(context).pop();
          _addOrEditDebt(patient);
        },
        icon: const Icon(Icons.add),
        label: const Text('Aggiungi'),
      ),
      children: data.debts.map((Debt debt) {
        return _managerCard(
          title: '${debt.description} · € ${debt.residualAmount.toStringAsFixed(2)}',
          subtitle: 'Creazione ${_formatDate(debt.createdAt)} · Scadenza ${_formatDate(debt.dueDate)}',
          actions: [
            IconButton(
              tooltip: 'Modifica',
              onPressed: () {
                Navigator.of(context).pop();
                _addOrEditDebt(patient, initial: debt);
              },
              icon: const Icon(Icons.edit_outlined, color: Colors.white70),
            ),
            IconButton(
              tooltip: 'Elimina',
              onPressed: () => _deleteDebt(patient, debt),
              icon: const Icon(Icons.delete_outline, color: AppColors.red),
            ),
          ],
          extra: [
            _detailLine('Importo totale', '€ ${debt.amount.toStringAsFixed(2)}'),
            _detailLine('Pagato', '€ ${debt.paidAmount.toStringAsFixed(2)}'),
            _detailLine('Stato', _humanDebtStatus(debt.status, debt.residualAmount)),
            if ((debt.note ?? '').trim().isNotEmpty) _detailLine('Nota', debt.note!.trim()),
          ],
        );
      }).toList(),
    );
  }

  Future<void> _manageAdvances(_PatientDetailData data) async {
    final Patient? patient = data.patient;
    if (patient == null) return;
    await _openManageDialog(
      title: 'Anticipi',
      action: FilledButton.icon(
        onPressed: () {
          Navigator.of(context).pop();
          _addOrEditAdvance(data);
        },
        icon: const Icon(Icons.add),
        label: const Text('Aggiungi'),
      ),
      children: data.advances.map((Advance advance) {
        return _managerCard(
          title: advance.drugName,
          subtitle: '${advance.doctorName.isEmpty ? '-' : advance.doctorName} · ${_formatDate(advance.createdAt)}',
          actions: [
            IconButton(
              tooltip: 'Modifica',
              onPressed: () {
                Navigator.of(context).pop();
                _addOrEditAdvance(data, initial: advance);
              },
              icon: const Icon(Icons.edit_outlined, color: Colors.white70),
            ),
            IconButton(
              tooltip: 'Elimina',
              onPressed: () => _deleteAdvance(patient, advance),
              icon: const Icon(Icons.delete_outline, color: AppColors.red),
            ),
          ],
          extra: [
            _detailLine('Stato', _humanAdvanceStatus(advance.status)),
            if (advance.matchedTherapyFlag) _detailLine('Terapia', 'Collegato a terapia nota'),
            if ((advance.note ?? '').trim().isNotEmpty) _detailLine('Nota', advance.note!.trim()),
          ],
        );
      }).toList(),
    );
  }

  Future<void> _manageBookings(_PatientDetailData data) async {
    final Patient? patient = data.patient;
    if (patient == null) return;
    await _openManageDialog(
      title: 'Prenotazioni',
      action: FilledButton.icon(
        onPressed: () {
          Navigator.of(context).pop();
          _addOrEditBooking(patient);
        },
        icon: const Icon(Icons.add),
        label: const Text('Aggiungi'),
      ),
      children: data.bookings.map((Booking booking) {
        return _managerCard(
          title: '${booking.drugName} x${booking.quantity}',
          subtitle: 'Registrata ${_formatDate(booking.createdAt)} · Prevista ${_formatDate(booking.expectedDate)}',
          actions: [
            IconButton(
              tooltip: 'Modifica',
              onPressed: () {
                Navigator.of(context).pop();
                _addOrEditBooking(patient, initial: booking);
              },
              icon: const Icon(Icons.edit_outlined, color: Colors.white70),
            ),
            IconButton(
              tooltip: 'Elimina',
              onPressed: () => _deleteBooking(patient, booking),
              icon: const Icon(Icons.delete_outline, color: AppColors.red),
            ),
          ],
          extra: [
            _detailLine('Stato', _humanBookingStatus(booking.status)),
            if ((booking.note ?? '').trim().isNotEmpty) _detailLine('Nota', booking.note!.trim()),
          ],
        );
      }).toList(),
    );
  }

  Future<void> _addOrEditDebt(Patient patient, {Debt? initial}) async {
    final TextEditingController descriptionController = TextEditingController(text: initial?.description ?? '');
    final TextEditingController amountController = TextEditingController(
      text: initial == null ? '' : initial.amount.toStringAsFixed(2).replaceAll('.', ','),
    );
    final TextEditingController paidController = TextEditingController(
      text: initial == null ? '0' : initial.paidAmount.toStringAsFixed(2).replaceAll('.', ','),
    );
    final TextEditingController dueDateController = TextEditingController(
      text: _formatDate(initial?.dueDate),
    );
    final TextEditingController noteController = TextEditingController(text: initial?.note ?? '');

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text(initial == null ? 'Nuovo debito' : 'Modifica debito', style: const TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(descriptionController, 'Causale'),
                const SizedBox(height: 12),
                _dialogField(
                  amountController,
                  'Importo totale (€)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,\.]'))],
                ),
                const SizedBox(height: 12),
                _dialogField(
                  paidController,
                  'Pagato (€)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,\.]'))],
                ),
                const SizedBox(height: 12),
                _dialogField(
                  dueDateController,
                  'Scadenza (gg/mm/aaaa)',
                  keyboardType: TextInputType.datetime,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9/]'))],
                ),
                const SizedBox(height: 12),
                _dialogField(noteController, 'Nota', maxLines: 3),
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
      ),
    );

    if (confirmed != true) {
      descriptionController.dispose();
      amountController.dispose();
      paidController.dispose();
      dueDateController.dispose();
      noteController.dispose();
      return;
    }

    try {
      final double amount = _parseEuro(amountController.text);
      final double paid = _parseEuro(paidController.text);
      final DateTime? dueDate = _parseItalianDate(dueDateController.text);
      if (descriptionController.text.trim().isEmpty || amount <= 0) {
        throw Exception('Causale e importo totale sono obbligatori.');
      }
      if (paid < 0 || paid > amount) {
        throw Exception('Il pagato deve essere compreso tra 0 e importo totale.');
      }
      final double residual = math.max(0, amount - paid);
      final DateTime now = DateTime.now();
      final Debt debt = Debt(
        id: initial?.id ?? _localId('debt'),
        patientFiscalCode: patient.fiscalCode,
        patientName: patient.fullName,
        description: descriptionController.text.trim(),
        amount: amount,
        paidAmount: paid,
        residualAmount: residual,
        createdAt: initial?.createdAt ?? now,
        dueDate: dueDate,
        status: residual <= 0 ? 'closed' : 'open',
        note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
      );
      await _debtsRepository.saveDebt(debt);
      _refresh(initial == null ? 'Debito aggiunto.' : 'Debito aggiornato.');
    } catch (e) {
      setState(() => _message = 'Errore salvataggio debito: $e');
    } finally {
      descriptionController.dispose();
      amountController.dispose();
      paidController.dispose();
      dueDateController.dispose();
      noteController.dispose();
    }
  }

  Future<void> _addOrEditAdvance(_PatientDetailData data, {Advance? initial}) async {
    final Patient? patient = data.patient;
    if (patient == null) return;
    final TextEditingController drugController = TextEditingController(text: initial?.drugName ?? '');
    final TextEditingController doctorController = TextEditingController(
      text: initial?.doctorName ?? _fallbackDoctorFromHistory(data),
    );
    final TextEditingController noteController = TextEditingController(text: initial?.note ?? '');

    final List<String> doctorCandidates = <String>{
      ...data.settings.doctorsCatalog.map((String item) => item.trim()).where((String item) => item.isNotEmpty),
      if (_fallbackDoctorFromHistory(data).trim().isNotEmpty && _fallbackDoctorFromHistory(data).trim() != '-')
        _fallbackDoctorFromHistory(data).trim(),
      if ((initial?.doctorName ?? '').trim().isNotEmpty) initial!.doctorName.trim(),
    }.toList()
      ..sort();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setLocalState) {
            return AlertDialog(
              backgroundColor: AppColors.panel,
              title: Text(initial == null ? 'Nuovo anticipo' : 'Modifica anticipo', style: const TextStyle(color: Colors.white)),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _dialogField(drugController, 'Farmaco / articolo'),
                      const SizedBox(height: 12),
                      _dialogField(doctorController, 'Medico'),
                      if (doctorCandidates.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: doctorCandidates.map((String value) {
                            final bool selected = doctorController.text.trim() == value;
                            return ChoiceChip(
                              selected: selected,
                              label: Text(value),
                              selectedColor: AppColors.yellow.withOpacity(0.22),
                              backgroundColor: AppColors.panelSoft,
                              labelStyle: TextStyle(color: selected ? AppColors.yellow : Colors.white70),
                              onSelected: (_) {
                                setLocalState(() {
                                  doctorController.text = value;
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _dialogField(noteController, 'Nota', maxLines: 3),
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
      drugController.dispose();
      doctorController.dispose();
      noteController.dispose();
      return;
    }

    try {
      final String drugName = drugController.text.trim();
      final String doctor = doctorController.text.trim();
      if (drugName.isEmpty || doctor.isEmpty || doctor == '-') {
        throw Exception('Farmaco e medico sono obbligatori.');
      }
      final DateTime now = DateTime.now();
      final Advance advance = Advance(
        id: initial?.id ?? _localId('advance'),
        patientFiscalCode: patient.fiscalCode,
        patientName: patient.fullName,
        drugName: drugName,
        doctorName: doctor,
        note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
        matchedTherapyFlag: initial?.matchedTherapyFlag ?? false,
        matchedPrescriptionId: initial?.matchedPrescriptionId,
        status: ((initial?.status ?? 'open').trim().isEmpty ? 'open' : (initial?.status ?? 'open')), 
        createdAt: initial?.createdAt ?? now,
        updatedAt: now,
      );
      await _advancesRepository.saveAdvance(advance);
      await _doctorPatientLinksRepository.saveManualOverride(
        patientFiscalCode: patient.fiscalCode,
        patientFullName: patient.fullName,
        doctorFullName: doctor,
        city: patient.city,
      );
      _refresh(initial == null ? 'Anticipo aggiunto.' : 'Anticipo aggiornato.');
    } catch (e) {
      setState(() => _message = 'Errore salvataggio anticipo: $e');
    } finally {
      drugController.dispose();
      doctorController.dispose();
      noteController.dispose();
    }
  }

  String _fallbackDoctorFromHistory(_PatientDetailData data) {
    if (data.resolvedDoctorName != '-' && data.resolvedDoctorName.trim().isNotEmpty) {
      return data.resolvedDoctorName.trim();
    }
    for (final Advance advance in data.advances) {
      if (advance.doctorName.trim().isNotEmpty) return advance.doctorName.trim();
    }
    for (final Prescription prescription in data.prescriptions) {
      if ((prescription.doctorName ?? '').trim().isNotEmpty) {
        return prescription.doctorName!.trim();
      }
    }
    return '-';
  }

  Future<void> _addOrEditBooking(Patient patient, {Booking? initial}) async {
    final TextEditingController drugController = TextEditingController(text: initial?.drugName ?? '');
    final TextEditingController quantityController = TextEditingController(text: '${initial?.quantity ?? 1}');
    final TextEditingController expectedDateController = TextEditingController(text: _formatDate(initial?.expectedDate));
    final TextEditingController noteController = TextEditingController(text: initial?.note ?? '');
    final List<String> statuses = const <String>['open', 'ordered', 'ready', 'closed'];
    String selectedStatus = statuses.contains(initial?.status) ? initial!.status : 'open';

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setLocalState) {
            return AlertDialog(
              backgroundColor: AppColors.panel,
              title: Text(initial == null ? 'Nuova prenotazione' : 'Modifica prenotazione', style: const TextStyle(color: Colors.white)),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
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
                      _dialogField(
                        expectedDateController,
                        'Data prevista (gg/mm/aaaa)',
                        keyboardType: TextInputType.datetime,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9/]'))],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedStatus,
                        dropdownColor: AppColors.panelSoft,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Stato',
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
                        items: statuses
                            .map((String item) => DropdownMenuItem<String>(
                                  value: item,
                                  child: Text(_humanBookingStatus(item)),
                                ))
                            .toList(),
                        onChanged: (String? value) {
                          setLocalState(() {
                            selectedStatus = value ?? 'open';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _dialogField(noteController, 'Nota', maxLines: 3),
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
      drugController.dispose();
      quantityController.dispose();
      expectedDateController.dispose();
      noteController.dispose();
      return;
    }

    try {
      final int quantity = int.tryParse(quantityController.text.trim()) ?? 0;
      if (drugController.text.trim().isEmpty || quantity <= 0) {
        throw Exception('Farmaco e quantità sono obbligatori.');
      }
      await _bookingsRepository.saveBooking(
        Booking(
          id: initial?.id ?? _localId('booking'),
          patientFiscalCode: patient.fiscalCode,
          patientName: patient.fullName,
          drugName: drugController.text.trim(),
          quantity: quantity,
          note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
          createdAt: initial?.createdAt ?? DateTime.now(),
          expectedDate: _parseItalianDate(expectedDateController.text),
          status: selectedStatus,
        ),
      );
      _refresh(initial == null ? 'Prenotazione aggiunta.' : 'Prenotazione aggiornata.');
    } catch (e) {
      setState(() => _message = 'Errore salvataggio prenotazione: $e');
    } finally {
      drugController.dispose();
      quantityController.dispose();
      expectedDateController.dispose();
      noteController.dispose();
    }
  }

  Future<void> _deleteDebt(Patient patient, Debt debt) async {
    if (!await _confirmDelete('Eliminare questo debito?')) return;
    await _debtsRepository.deleteDebt(patient.fiscalCode, debt.id);
    _refresh('Debito eliminato.');
  }

  Future<void> _deleteAdvance(Patient patient, Advance advance) async {
    if (!await _confirmDelete('Eliminare questo anticipo?')) return;
    await _advancesRepository.deleteAdvance(patient.fiscalCode, advance.id);
    _refresh('Anticipo eliminato.');
  }

  Future<void> _deleteBooking(Patient patient, Booking booking) async {
    if (!await _confirmDelete('Eliminare questa prenotazione?')) return;
    await _bookingsRepository.deleteBooking(patient.fiscalCode, booking.id);
    _refresh('Prenotazione eliminata.');
  }

  Future<void> _requestPrescriptionDelete(DrivePdfImport item) async {
    if (!await _confirmDelete('Eliminare questa ricetta?')) return;
    await _drivePdfImportsRepository.requestPdfDelete(item.id);
    _refresh('Richiesta delete PDF registrata.');
  }

  Future<bool> _confirmDelete(String text) async {
    final bool? value = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Conferma', style: TextStyle(color: Colors.white)),
        content: Text(text, style: const TextStyle(color: Colors.white70)),
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
      ),
    );
    return value == true;
  }

  void _openFamilyMember(_FamilyMemberData member) {
    if (member.isCurrent) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PatientDetailPage(fiscalCode: member.fiscalCode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FutureBuilder<_PatientDetailData>(
          future: _future,
          builder: (BuildContext context, AsyncSnapshot<_PatientDetailData> snapshot) {
            final _PatientDetailData? data = snapshot.data;
            return Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(
                backgroundColor: AppColors.background,
                foregroundColor: Colors.white,
                title: const Text('Scheda assistito'),
              ),
              body: snapshot.connectionState == ConnectionState.waiting
                  ? const Center(child: CircularProgressIndicator())
                  : snapshot.hasError
                      ? Center(
                          child: Text(
                            'Errore caricamento: ${snapshot.error}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        )
                      : data == null || data.patient == null
                          ? const Center(
                              child: Text('Assistito non trovato.', style: TextStyle(color: Colors.white)),
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildHeader(data),
                                  if (_message.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      _message,
                                      style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                  const SizedBox(height: 18),
                                  Wrap(
                                    spacing: 14,
                                    runSpacing: 14,
                                    children: [
                                      _summaryCard(
                                        label: 'Ricette',
                                        value: '${data.totalRecipeCount}',
                                        subtitle: data.recipeDocumentSubtitle,
                                        color: AppColors.green,
                                        onTap: () => _managePrescriptions(data),
                                      ),
                                      _summaryCard(
                                        label: 'DPC',
                                        value: data.hasDpc ? 'SI' : 'NO',
                                        subtitle: 'flag archivio attivo',
                                        color: AppColors.coral,
                                        onTap: () => _managePrescriptions(data),
                                      ),
                                      _summaryCard(
                                        label: 'Debiti',
                                        value: '€ ${data.totalDebt.toStringAsFixed(2)}',
                                        subtitle: '${data.debts.length} voci',
                                        color: AppColors.wine,
                                        onTap: () => _manageDebts(data),
                                      ),
                                      _summaryCard(
                                        label: 'Anticipi',
                                        value: '${data.advances.length}',
                                        subtitle: 'gestione rapida',
                                        color: AppColors.amber,
                                        onTap: () => _manageAdvances(data),
                                      ),
                                      _summaryCard(
                                        label: 'Prenotazioni',
                                        value: '${data.bookings.length}',
                                        subtitle: 'gestione rapida',
                                        color: AppColors.yellow,
                                        onTap: () => _manageBookings(data),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  _buildRecipesSection(data),
                                  const SizedBox(height: 18),
                                  _buildDebtsSection(data),
                                  const SizedBox(height: 18),
                                  _buildAdvancesSection(data),
                                  const SizedBox(height: 18),
                                  _buildBookingsSection(data),
                                  const SizedBox(height: 18),
                                  _buildFamilySection(data),
                                  const SizedBox(height: 18),
                                  _buildTherapeuticAdviceSection(data),
                                  const SizedBox(height: 18),
                                  _buildTherapiesSection(data),
                                ],
                              ),
                            ),
            );
          },
        ),
        FloatingPageMenu(
          currentIndex: appNavigationIndex.value,
          includeBack: true,
          onBack: () => Navigator.of(context).maybePop(),
          pageIcon: Icons.badge_outlined,
          pageTooltip: 'Scheda assistito',
          onSelected: (int index) {
            appNavigationIndex.value = index;
            Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
          },
        ),
      ],
    );
  }

  Widget _buildHeader(_PatientDetailData data) {
    final Patient patient = data.patient!;
    final List<String> extraExemptions = data.allExemptions.length > 1
        ? data.allExemptions.skip(1).toList()
        : const <String>[];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            visiblePatientTitle(
              fullName: patient.fullName,
              patientKey: patient.fiscalCode,
            ),
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metaBadge('CF', visiblePatientFiscalCode(patient.fiscalCode)),
              _metaBadge('Medico', data.resolvedDoctorName),
              _metaBadge('Esenzione primaria', data.primaryExemption),
              _metaBadge('Città', data.displayCity),
              _metaBadge('Ultima ricetta', _formatDate(data.lastPrescriptionDate)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(data.hasDpc ? 'DPC' : 'NO DPC', data.hasDpc ? AppColors.coral : AppColors.green),
              if (data.hasFamily)
                _pill('Famiglia: ${data.family!.name}', data.familyColor)
              else
                _pill('Senza famiglia', Colors.white54),
              ...extraExemptions.map((String value) => _pill('Esenzione $value', AppColors.yellow)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecipesSection(_PatientDetailData data) {
    final String emptyText = data.allImports.isNotEmpty
        ? 'Nessuna ricetta archivistica attiva: tutti i documenti del dominio archivistico risultano già nascosti, richiesti in delete o eliminati.'
        : 'Nessuna ricetta archivistica attiva.';
    return _section(
      title: 'Ricette archivistiche',
      action: Text(
        '${data.totalRecipeCount} ricette · ${data.visibleRecipeDocumentsCount} documenti attivi',
        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
      ),
      child: data.prescriptions.isEmpty
          ? Text(emptyText, style: const TextStyle(color: Colors.white70))
          : Column(
              children: data.prescriptions.map((Prescription prescription) {
                final DrivePdfImport? matchingImport = _findImportForPrescription(data.imports, prescription.id);
                return _buildPrescriptionCard(
                  prescription: prescription,
                  importItem: matchingImport,
                  compact: false,
                );
              }).toList(),
            ),
    );
  }

  Widget _buildPrescriptionCard({
    required Prescription prescription,
    required DrivePdfImport? importItem,
    required bool compact,
  }) {
    final PrescriptionExpiryInfo expiryInfo = PrescriptionExpiryUtils.evaluate(prescription.expiryDate);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panelSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _prescriptionLabel(prescription),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 16 : 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (importItem != null)
                TextButton.icon(
                  onPressed: () => _openPdf(importItem),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('PDF'),
                ),
              if (importItem != null)
                IconButton(
                  tooltip: 'Elimina ricetta',
                  onPressed: () => _requestPrescriptionDelete(importItem),
                  icon: const Icon(Icons.delete_outline, color: AppColors.red),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(expiryInfo.label, expiryInfo.color),
              _pill(prescription.dpcFlag ? 'DPC' : 'NO DPC', prescription.dpcFlag ? AppColors.coral : AppColors.green),
              _pill('${prescription.prescriptionCount} ricetta/e', AppColors.yellow),
              _pill(importItem != null ? 'Archivio attivo' : 'Legacy', importItem != null ? Colors.white70 : Colors.white38),
            ],
          ),
          const SizedBox(height: 10),
          _detailLine('Data', _formatDate(prescription.prescriptionDate)),
          _detailLine('Scadenza', _formatDate(prescription.expiryDate)),
          _detailLine('Medico', (prescription.doctorName ?? '-').trim().isEmpty ? '-' : prescription.doctorName!.trim()),
          _detailLine('Esenzione', (prescription.exemptionCode ?? '-').trim().isEmpty ? '-' : prescription.exemptionCode!.trim()),
        ],
      ),
    );
  }

  Widget _buildDebtsSection(_PatientDetailData data) {
    final Patient patient = data.patient!;
    return _section(
      title: 'Debiti',
      action: Wrap(
        spacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Totale € ${data.totalDebt.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
          ),
          FilledButton.icon(
            onPressed: () => _addOrEditDebt(patient),
            icon: const Icon(Icons.add),
            label: const Text('Aggiungi'),
          ),
        ],
      ),
      child: data.debts.isEmpty
          ? const Text('Nessun debito registrato.', style: TextStyle(color: Colors.white70))
          : Column(
              children: data.debts.map((Debt debt) {
                return _operationCard(
                  title: debt.description,
                  badgeLabel: _humanDebtStatus(debt.status, debt.residualAmount),
                  badgeColor: debt.residualAmount > 0 ? AppColors.wine : AppColors.green,
                  lines: [
                    _detailLine('Importo totale', '€ ${debt.amount.toStringAsFixed(2)}'),
                    _detailLine('Pagato', '€ ${debt.paidAmount.toStringAsFixed(2)}'),
                    _detailLine('Residuo', '€ ${debt.residualAmount.toStringAsFixed(2)}'),
                    _detailLine('Scadenza', _formatDate(debt.dueDate)),
                    if ((debt.note ?? '').trim().isNotEmpty) _detailLine('Nota', debt.note!.trim()),
                  ],
                  actions: [
                    IconButton(
                      tooltip: 'Modifica',
                      onPressed: () => _addOrEditDebt(patient, initial: debt),
                      icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                    ),
                    IconButton(
                      tooltip: 'Elimina',
                      onPressed: () => _deleteDebt(patient, debt),
                      icon: const Icon(Icons.delete_outline, color: AppColors.red),
                    ),
                  ],
                );
              }).toList(),
            ),
    );
  }

  Widget _buildAdvancesSection(_PatientDetailData data) {
    return _section(
      title: 'Anticipi',
      action: Wrap(
        spacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '${data.advances.length} voci',
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
          ),
          FilledButton.icon(
            onPressed: () => _addOrEditAdvance(data),
            icon: const Icon(Icons.add),
            label: const Text('Aggiungi'),
          ),
        ],
      ),
      child: data.advances.isEmpty
          ? const Text('Nessun anticipo registrato.', style: TextStyle(color: Colors.white70))
          : Column(
              children: data.advances.map((Advance advance) {
                return _operationCard(
                  title: advance.drugName,
                  badgeLabel: _humanAdvanceStatus(advance.status),
                  badgeColor: advance.status == 'closed' ? AppColors.green : AppColors.amber,
                  lines: [
                    _detailLine('Medico', advance.doctorName.isEmpty ? '-' : advance.doctorName),
                    _detailLine('Data', _formatDate(advance.createdAt)),
                    if (advance.matchedTherapyFlag) _detailLine('Terapia', 'Collegato a terapia nota'),
                    if ((advance.note ?? '').trim().isNotEmpty) _detailLine('Nota', advance.note!.trim()),
                  ],
                  actions: [
                    IconButton(
                      tooltip: 'Modifica',
                      onPressed: () => _addOrEditAdvance(data, initial: advance),
                      icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                    ),
                    IconButton(
                      tooltip: 'Elimina',
                      onPressed: () => _deleteAdvance(data.patient!, advance),
                      icon: const Icon(Icons.delete_outline, color: AppColors.red),
                    ),
                  ],
                );
              }).toList(),
            ),
    );
  }

  Widget _buildBookingsSection(_PatientDetailData data) {
    final Patient patient = data.patient!;
    return _section(
      title: 'Prenotazioni',
      action: Wrap(
        spacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '${data.bookings.length} voci',
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
          ),
          FilledButton.icon(
            onPressed: () => _addOrEditBooking(patient),
            icon: const Icon(Icons.add),
            label: const Text('Aggiungi'),
          ),
        ],
      ),
      child: data.bookings.isEmpty
          ? const Text('Nessuna prenotazione registrata.', style: TextStyle(color: Colors.white70))
          : Column(
              children: data.bookings.map((Booking booking) {
                return _operationCard(
                  title: '${booking.drugName} x${booking.quantity}',
                  badgeLabel: _humanBookingStatus(booking.status),
                  badgeColor: booking.status == 'closed' ? AppColors.green : AppColors.yellow,
                  lines: [
                    _detailLine('Data registrazione', _formatDate(booking.createdAt)),
                    _detailLine('Data prevista', _formatDate(booking.expectedDate)),
                    if ((booking.note ?? '').trim().isNotEmpty) _detailLine('Nota', booking.note!.trim()),
                  ],
                  actions: [
                    IconButton(
                      tooltip: 'Modifica',
                      onPressed: () => _addOrEditBooking(patient, initial: booking),
                      icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                    ),
                    IconButton(
                      tooltip: 'Elimina',
                      onPressed: () => _deleteBooking(patient, booking),
                      icon: const Icon(Icons.delete_outline, color: AppColors.red),
                    ),
                  ],
                );
              }).toList(),
            ),
    );
  }

  Widget _buildFamilySection(_PatientDetailData data) {
    return _section(
      title: 'Famiglia',
      action: data.hasFamily
          ? Text(
              '${data.familyMembers.length} membri',
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
            )
          : null,
      child: !data.hasFamily
          ? const Text(
              'Questo assistito non appartiene a nessun gruppo famiglia.',
              style: TextStyle(color: Colors.white70),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: data.familyColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        data.family!.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: data.familyMembers.map(( _FamilyMemberData member) {
                    return InkWell(
                      onTap: member.isCurrent ? null : () => _openFamilyMember(member),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 260,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.panelSoft,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: member.isCurrent ? data.familyColor : Colors.white10,
                            width: member.isCurrent ? 1.4 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.displayName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            Text(member.fiscalCode, style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 8),
                            Text(
                              member.isCurrent ? 'Assistito corrente' : 'Apri scheda collegata',
                              style: TextStyle(
                                color: member.isCurrent ? data.familyColor : Colors.white60,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
    );
  }

  Widget _buildTherapeuticAdviceSection(_PatientDetailData data) {
    return _section(
      title: 'Consigli terapeutici',
      action: Wrap(
        spacing: 10,
        children: [
          FilledButton.icon(
            onPressed: () => _editTherapeuticAdvice(data),
            icon: Icon(data.therapeuticAdvice == null ? Icons.add_comment_outlined : Icons.edit_outlined),
            label: Text(data.therapeuticAdvice == null ? 'Aggiungi' : 'Modifica'),
          ),
          if (data.therapeuticAdvice != null)
            TextButton.icon(
              onPressed: () => _clearTherapeuticAdvice(data),
              icon: const Icon(Icons.delete_outline, color: AppColors.red),
              label: const Text('Svuota', style: TextStyle(color: AppColors.red)),
            ),
        ],
      ),
      child: (data.therapeuticAdvice?.text.trim() ?? '').isEmpty
          ? const Text(
              'Nessun consiglio terapeutico registrato.',
              style: TextStyle(color: Colors.white70),
            )
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.panelSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Text(
                data.therapeuticAdvice!.text,
                style: const TextStyle(color: Colors.white, height: 1.45),
              ),
            ),
    );
  }

  Widget _buildTherapiesSection(_PatientDetailData data) {
    return _section(
      title: 'Terapie riepilogative',
      child: data.therapiesSummary.isEmpty
          ? const Text('Nessuna terapia disponibile.', style: TextStyle(color: Colors.white70))
          : Wrap(
              spacing: 10,
              runSpacing: 10,
              children: data.therapiesSummary.map((String item) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.panelSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    item,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _summaryCard({
    required String label,
    required String value,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required Widget child,
    Widget? action,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
              if (action != null) Flexible(child: action),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _operationCard({
    required String title,
    required String badgeLabel,
    required Color badgeColor,
    required List<Widget> lines,
    required List<Widget> actions,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panelSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              _pill(badgeLabel, badgeColor),
              const SizedBox(width: 8),
              ...actions,
            ],
          ),
          const SizedBox(height: 10),
          ...lines,
        ],
      ),
    );
  }

  Widget _managerCard({
    required String title,
    required String subtitle,
    required List<Widget> actions,
    List<Widget> extra = const <Widget>[],
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panelSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              ...actions,
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Colors.white70)),
          if (extra.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...extra,
          ],
        ],
      ),
    );
  }

  Widget _metaBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.panelSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800),
            ),
            TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
    );
  }

  Widget _dialogField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
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

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white70, height: 1.35),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w800)),
            TextSpan(text: value, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  DrivePdfImport? _findImportForPrescription(List<DrivePdfImport> imports, String prescriptionId) {
    for (final DrivePdfImport item in imports) {
      if (item.id == prescriptionId) return item;
    }
    return null;
  }

  String _prescriptionLabel(Prescription prescription) {
    final String label = prescription.items
        .map((PrescriptionItem item) => item.drugName.trim())
        .where((String item) => item.isNotEmpty)
        .join(', ');
    return label.isEmpty ? 'Ricetta' : label;
  }

  String _humanDebtStatus(String status, double residualAmount) {
    if (residualAmount <= 0) return 'Chiuso';
    final String normalized = status.trim().toLowerCase();
    if (normalized == 'closed') return 'Chiuso';
    return 'Aperto';
  }

  String _humanAdvanceStatus(String status) {
    final String normalized = status.trim().toLowerCase();
    switch (normalized) {
      case 'closed':
        return 'Chiuso';
      case 'matched':
        return 'Coperto';
      default:
        return 'Aperto';
    }
  }

  String _humanBookingStatus(String status) {
    switch (status.trim().toLowerCase()) {
      case 'ordered':
        return 'Ordinata';
      case 'ready':
        return 'Pronta';
      case 'closed':
        return 'Chiusa';
      default:
        return 'Aperta';
    }
  }

  String _localId(String prefix) => '${prefix}_${widget.fiscalCode}_${DateTime.now().microsecondsSinceEpoch}';

  double _parseEuro(String raw) {
    final String normalized = raw.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  DateTime? _parseItalianDate(String raw) {
    final String value = raw.trim();
    if (value.isEmpty) return null;
    final RegExpMatch? match = RegExp(r'^(\d{1,2})\/(\d{1,2})\/(\d{4})$').firstMatch(value);
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(3)!),
      int.parse(match.group(2)!),
      int.parse(match.group(1)!),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String year = date.year.toString();
    return '$day/$month/$year';
  }
}

class _PatientDetailData {
  final Patient? patient;
  final List<Advance> advances;
  final List<Debt> debts;
  final List<Booking> bookings;
  final List<Prescription> prescriptions;
  final List<DrivePdfImport> imports;
  final List<DrivePdfImport> allImports;
  final AppSettings settings;
  final String resolvedDoctorName;
  final TherapeuticAdviceNote? therapeuticAdvice;
  final FamilyGroup? family;
  final List<_FamilyMemberData> familyMembers;
  final Color familyColor;

  const _PatientDetailData({
    required this.patient,
    required this.advances,
    required this.debts,
    required this.bookings,
    required this.prescriptions,
    required this.imports,
    required this.allImports,
    required this.settings,
    required this.resolvedDoctorName,
    required this.therapeuticAdvice,
    required this.family,
    required this.familyMembers,
    required this.familyColor,
  });

  double get totalDebt => debts.fold<double>(0, (double sum, Debt item) => sum + item.residualAmount);

  int get totalRecipeCount {
    final Patient? currentPatient = patient;
    if (currentPatient == null) {
      return prescriptions.fold<int>(0, (int sum, Prescription item) => sum + item.prescriptionCount);
    }
    return PhboxContractUtils.resolveRecipeCount(
      patient: currentPatient,
      allImports: allImports,
      visibleImports: imports,
      legacyPrescriptions: prescriptions,
    );
  }

  bool get hasDpc {
    final Patient? currentPatient = patient;
    if (currentPatient == null) {
      return imports.any((DrivePdfImport item) => item.isDpc) ||
          prescriptions.any((Prescription item) => item.dpcFlag);
    }
    return PhboxContractUtils.resolveHasDpc(
      patient: currentPatient,
      allImports: allImports,
      visibleImports: imports,
      legacyPrescriptions: prescriptions,
    );
  }

  DateTime? get lastPrescriptionDate {
    final Patient? currentPatient = patient;
    if (currentPatient == null) return null;
    return PhboxContractUtils.resolveLastPrescriptionDate(
      patient: currentPatient,
      allImports: allImports,
      visibleImports: imports,
      legacyPrescriptions: prescriptions,
    );
  }

  List<String> get therapiesSummary {
    final Patient? currentPatient = patient;
    if (currentPatient == null) return const <String>[];
    return PhboxContractUtils.resolveTherapiesSummary(
      patient: currentPatient,
      allImports: allImports,
      visibleImports: imports,
      prescriptions: prescriptions,
    );
  }

  String get primaryExemption {
    final Patient? currentPatient = patient;
    if (currentPatient == null) return '-';
    return PhboxContractUtils.resolveExemption(
      patient: currentPatient,
      visibleImports: imports,
      legacyPrescriptions: allImports.isNotEmpty ? const <Prescription>[] : prescriptions,
    );
  }

  List<String> get allExemptions {
    final Patient? currentPatient = patient;
    if (currentPatient == null) return const <String>[];
    final List<String> values = <String>[];
    for (final String item in currentPatient.exemptions) {
      final String normalized = item.trim();
      if (normalized.isNotEmpty && !values.contains(normalized)) {
        values.add(normalized);
      }
    }
    if (values.isEmpty) {
      final String fallback = primaryExemption.trim();
      if (fallback.isNotEmpty && fallback != '-') {
        values.add(fallback);
      }
    }
    return values;
  }

  String get displayCity {
    final Patient? currentPatient = patient;
    if (currentPatient == null) return '-';
    return PhboxContractUtils.resolveCity(
      patient: currentPatient,
      visibleImports: imports,
      legacyPrescriptions: allImports.isNotEmpty ? const <Prescription>[] : prescriptions,
    );
  }

  bool get hasFamily => family != null;

  int get visibleRecipeDocumentsCount => prescriptions.length;

  String get recipeDocumentSubtitle {
    if (allImports.isNotEmpty) {
      return '$visibleRecipeDocumentsCount documenti attivi';
    }
    if (visibleRecipeDocumentsCount > 0) {
      return '$visibleRecipeDocumentsCount documenti legacy';
    }
    return '0 documenti';
  }
}

class _ResolvedFamily {
  final FamilyGroup? group;
  final List<_FamilyMemberData> members;
  final Color color;

  const _ResolvedFamily({
    required this.group,
    required this.members,
    required this.color,
  });

  const _ResolvedFamily.empty()
      : group = null,
        members = const <_FamilyMemberData>[],
        color = AppColors.yellow;
}

class _FamilyMemberData {
  final String fiscalCode;
  final String fullName;
  final bool isCurrent;

  const _FamilyMemberData({
    required this.fiscalCode,
    required this.fullName,
    required this.isCurrent,
  });

  String get displayName {
    final String normalized = fullName.trim();
    if (normalized.isEmpty) return fiscalCode;
    return normalized.toUpperCase();
  }
}
