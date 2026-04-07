import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/prescription_expiry_utils.dart';
import '../../../core/utils/patient_identity_utils.dart';
import '../../../data/datasources/firestore_firebase_datasource.dart';
import '../../../data/models/advance.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/debt.dart';
import '../../../data/models/doctor_patient_link.dart';
import '../../../data/models/drive_pdf_import.dart';
import '../../../data/models/patient.dart';
import '../../../data/models/prescription.dart';
import '../../../data/models/therapeutic_advice_note.dart';
import '../../../data/repositories/advances_repository.dart';
import '../../../data/repositories/bookings_repository.dart';
import '../../../data/repositories/debts_repository.dart';
import '../../../data/repositories/doctor_patient_links_repository.dart';
import '../../../data/repositories/drive_pdf_imports_repository.dart';
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
  late final PatientsRepository _patientsRepository;
  late final AdvancesRepository _advancesRepository;
  late final DebtsRepository _debtsRepository;
  late final BookingsRepository _bookingsRepository;
  late final PrescriptionsRepository _prescriptionsRepository;
  late final DrivePdfImportsRepository _drivePdfImportsRepository;
  late final SettingsRepository _settingsRepository;
  late final DoctorPatientLinksRepository _doctorPatientLinksRepository;
  late final TherapeuticAdviceRepository _therapeuticAdviceRepository;

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
    _prescriptionsRepository = PrescriptionsRepository(
      datasource: datasource,
      patientsRepository: _patientsRepository,
    );
    _drivePdfImportsRepository = DrivePdfImportsRepository(datasource: datasource);
    _settingsRepository = SettingsRepository(datasource: datasource);
    _doctorPatientLinksRepository = DoctorPatientLinksRepository(datasource: datasource);
    _therapeuticAdviceRepository = TherapeuticAdviceRepository(datasource: datasource);
    _future = _load();
  }

  Future<_PatientDetailData> _load() async {
    final patient = await _patientsRepository.getPatientByFiscalCode(widget.fiscalCode);
    final advances = await _advancesRepository.getPatientAdvances(widget.fiscalCode);
    final debts = await _debtsRepository.getPatientDebts(widget.fiscalCode);
    final bookings = await _bookingsRepository.getPatientBookings(widget.fiscalCode);
    final prescriptions = await _prescriptionsRepository.getPatientPrescriptions(widget.fiscalCode);
    final imports = await _drivePdfImportsRepository.getImportsByPatient(widget.fiscalCode);
    final doctorLinks = await _doctorPatientLinksRepository.getAllLinks();
    final settings = await _settingsRepository.getSettings();
    final therapeuticAdvice = await _therapeuticAdviceRepository.getByFiscalCode(widget.fiscalCode);
    final doctorName = _resolveDoctor(
      patient: patient,
      doctorLinks: doctorLinks,
      prescriptions: prescriptions,
      advances: advances,
    );
    return _PatientDetailData(
      patient: patient,
      advances: advances,
      debts: debts,
      bookings: bookings,
      prescriptions: prescriptions,
      imports: imports,
      settings: settings,
      resolvedDoctorName: doctorName,
      therapeuticAdvice: therapeuticAdvice,
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
    required List<Advance> advances,
  }) {
    for (final link in doctorLinks) {
      if (link.patientFiscalCode == widget.fiscalCode.trim().toUpperCase() && link.doctorName.trim().isNotEmpty) {
        return link.doctorName.trim();
      }
    }
    if (patient != null && (patient.doctorName ?? '').trim().isNotEmpty) {
      return patient.doctorName!.trim();
    }
    for (final advance in advances) {
      if (advance.doctorName.trim().isNotEmpty) return advance.doctorName.trim();
    }
    for (final prescription in prescriptions) {
      if ((prescription.doctorName ?? '').trim().isNotEmpty) return prescription.doctorName!.trim();
    }
    return '-';
  }

  Future<void> _syncPatientAggregates(_PatientDetailData data) async {
    final patient = data.patient;
    if (patient == null) return;
    final double totalDebt = data.debts.fold<double>(0, (sum, item) => sum + item.residualAmount);
    final therapySummary = data.prescriptions
        .expand((item) => item.items)
        .map((item) => item.drugName.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final lastPrescriptionDate = data.prescriptions.isEmpty
        ? null
        : data.prescriptions.map((item) => item.prescriptionDate).reduce((a, b) => a.isAfter(b) ? a : b);
    final archivedRecipeCount = data.prescriptions.fold<int>(0, (sum, item) => sum + item.prescriptionCount);
    await _patientsRepository.savePatient(
      patient.copyWith(
        doctorName: data.resolvedDoctorName == '-' ? patient.doctorName : data.resolvedDoctorName,
        hasDebt: data.debts.isNotEmpty,
        debtTotal: totalDebt,
        hasAdvance: data.advances.isNotEmpty,
        hasBooking: data.bookings.isNotEmpty,
        hasDpc: data.prescriptions.any((item) => item.dpcFlag) || data.imports.any((item) => item.isDpc),
        archivedRecipeCount: archivedRecipeCount,
        lastPrescriptionDate: lastPrescriptionDate,
        therapiesSummary: therapySummary,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _openPdf(DrivePdfImport item) async {
    final String directLink = item.webViewLink.trim();
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
    final patient = data.patient;
    if (patient == null) return;
    final controller = TextEditingController(text: data.therapeuticAdvice?.text ?? '');
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
    final patient = data.patient;
    if (patient == null || data.therapeuticAdvice == null) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
      builder: (context) => Dialog(
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
                      child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
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
    final patient = data.patient;
    if (patient == null) return;
    await _openManageDialog(
      title: 'Ricette',
      children: data.prescriptions.map((prescription) {
        final matchingImport = _findImportForPrescription(data.imports, prescription.id);
        final expiryInfo = PrescriptionExpiryUtils.evaluate(prescription.expiryDate);
        return _managerCard(
          title: _prescriptionLabel(prescription),
          subtitle: '${_formatDate(prescription.prescriptionDate)} · ${prescription.doctorName ?? '-'} · ${expiryInfo.label}',
          actions: [
            if (matchingImport != null)
              TextButton.icon(
                onPressed: () => _openPdf(matchingImport),
                icon: const Icon(Icons.open_in_new),
                label: const Text('PDF'),
              ),
            IconButton(
              onPressed: () => _deleteSinglePrescription(patient, prescription),
              icon: const Icon(Icons.delete_outline, color: AppColors.red),
            ),
          ],
          extra: [
            _detailLine('Esenzione', (prescription.exemptionCode ?? '-').trim().isEmpty ? '-' : prescription.exemptionCode!.trim()),
            _detailLine('DPC', prescription.dpcFlag ? 'SI' : 'NO'),
            _detailLine('Terapie', _prescriptionLabel(prescription)),
          ],
        );
      }).toList(),
    );
  }

  Future<void> _manageDebts(_PatientDetailData data) async {
    final patient = data.patient;
    if (patient == null) return;
    await _openManageDialog(
      title: 'Debiti',
      action: FilledButton.icon(
        onPressed: () {
          Navigator.of(context).pop();
          _addDebt(patient);
        },
        icon: const Icon(Icons.add),
        label: const Text('Aggiungi'),
      ),
      children: data.debts.map((debt) {
        return _managerCard(
          title: '${debt.description} · € ${debt.residualAmount.toStringAsFixed(2)}',
          subtitle: 'Creazione ${_formatDate(debt.createdAt)} · Scadenza ${_formatDate(debt.dueDate)}',
          actions: [
            IconButton(
              onPressed: () => _deleteDebt(patient, debt),
              icon: const Icon(Icons.delete_outline, color: AppColors.red),
            ),
          ],
          extra: [if ((debt.note ?? '').trim().isNotEmpty) _detailLine('Nota', debt.note!.trim())],
        );
      }).toList(),
    );
  }

  Future<void> _manageAdvances(_PatientDetailData data) async {
    final patient = data.patient;
    if (patient == null) return;
    await _openManageDialog(
      title: 'Anticipi',
      action: FilledButton.icon(
        onPressed: () {
          Navigator.of(context).pop();
          _addAdvance(data);
        },
        icon: const Icon(Icons.add),
        label: const Text('Aggiungi'),
      ),
      children: data.advances.map((advance) {
        return _managerCard(
          title: advance.drugName,
          subtitle: '${advance.doctorName.isEmpty ? '-' : advance.doctorName} · ${_formatDate(advance.createdAt)}',
          actions: [
            IconButton(
              onPressed: () => _deleteAdvance(patient, advance),
              icon: const Icon(Icons.delete_outline, color: AppColors.red),
            ),
          ],
          extra: [if ((advance.note ?? '').trim().isNotEmpty) _detailLine('Nota', advance.note!.trim())],
        );
      }).toList(),
    );
  }

  Future<void> _manageBookings(_PatientDetailData data) async {
    final patient = data.patient;
    if (patient == null) return;
    await _openManageDialog(
      title: 'Prenotazioni',
      action: FilledButton.icon(
        onPressed: () {
          Navigator.of(context).pop();
          _addBooking(patient);
        },
        icon: const Icon(Icons.add),
        label: const Text('Aggiungi'),
      ),
      children: data.bookings.map((booking) {
        return _managerCard(
          title: '${booking.drugName} x${booking.quantity}',
          subtitle: 'Registrata ${_formatDate(booking.createdAt)} · Prevista ${_formatDate(booking.expectedDate)}',
          actions: [
            IconButton(
              onPressed: () => _deleteBooking(patient, booking),
              icon: const Icon(Icons.delete_outline, color: AppColors.red),
            ),
          ],
          extra: [if ((booking.note ?? '').trim().isNotEmpty) _detailLine('Nota', booking.note!.trim())],
        );
      }).toList(),
    );
  }

  Future<void> _addDebt(Patient patient) async {
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
    if (confirmed != true) return;
    try {
      final amount = _parseEuro(amountController.text);
      if (descriptionController.text.trim().isEmpty || amount <= 0) {
        throw Exception('Causale e importo sono obbligatori.');
      }
      final now = DateTime.now();
      await _debtsRepository.saveDebt(
        Debt(
          id: _localId('debt'),
          patientFiscalCode: patient.fiscalCode,
          patientName: patient.fullName,
          description: descriptionController.text.trim(),
          amount: amount,
          paidAmount: 0,
          residualAmount: amount,
          createdAt: now,
          dueDate: now,
          note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
        ),
      );
      _refresh('Debito aggiunto.');
    } catch (e) {
      setState(() => _message = 'Errore salvataggio debito: $e');
    } finally {
      descriptionController.dispose();
      amountController.dispose();
      noteController.dispose();
    }
  }

  Future<void> _addAdvance(_PatientDetailData data) async {
    final patient = data.patient;
    if (patient == null) return;
    final drugController = TextEditingController();
    final noteController = TextEditingController();
    String selectedDoctor = data.resolvedDoctorName != '-' ? data.resolvedDoctorName : _fallbackDoctorFromHistory(data);
    final doctorCandidates = <String>{
      ...data.settings.doctorsCatalog.map((item) => item.trim()).where((item) => item.isNotEmpty),
      if (selectedDoctor.trim().isNotEmpty && selectedDoctor.trim() != '-') selectedDoctor.trim(),
    }.toList()
      ..sort();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
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
                      value: selectedDoctor == '-' || selectedDoctor.isEmpty ? null : selectedDoctor,
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
                      items: doctorCandidates
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
                    _dialogField(noteController, 'Nota', maxLines: 3),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annulla', style: TextStyle(color: Colors.white70))),
                FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Salva')),
              ],
            );
          },
        );
      },
    );
    if (confirmed != true) return;
    try {
      final doctor = selectedDoctor.trim();
      if (drugController.text.trim().isEmpty || doctor.isEmpty || doctor == '-') {
        throw Exception('Farmaco e medico sono obbligatori.');
      }
      final now = DateTime.now();
      await _advancesRepository.saveAdvance(
        Advance(
          id: _localId('advance'),
          patientFiscalCode: patient.fiscalCode,
          patientName: patient.fullName,
          drugName: drugController.text.trim(),
          doctorName: doctor,
          note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await _doctorPatientLinksRepository.saveLink(
        patientFiscalCode: patient.fiscalCode,
        patientFullName: patient.fullName,
        doctorFullName: doctor,
        city: patient.city,
      );
      await _patientsRepository.savePatient(patient.copyWith(doctorName: doctor, updatedAt: now));
      _refresh('Anticipo aggiunto.');
    } catch (e) {
      setState(() => _message = 'Errore salvataggio anticipo: $e');
    } finally {
      drugController.dispose();
      noteController.dispose();
    }
  }

  String _fallbackDoctorFromHistory(_PatientDetailData data) {
    if (data.resolvedDoctorName != '-' && data.resolvedDoctorName.trim().isNotEmpty) {
      return data.resolvedDoctorName.trim();
    }
    for (final advance in data.advances) {
      if (advance.doctorName.trim().isNotEmpty) return advance.doctorName.trim();
    }
    for (final prescription in data.prescriptions) {
      if ((prescription.doctorName ?? '').trim().isNotEmpty) return prescription.doctorName!.trim();
    }
    return '-';
  }

  Future<void> _addBooking(Patient patient) async {
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
    if (confirmed != true) return;
    try {
      await _bookingsRepository.saveBooking(
        Booking(
          id: _localId('booking'),
          patientFiscalCode: patient.fiscalCode,
          patientName: patient.fullName,
          drugName: drugController.text.trim(),
          quantity: int.tryParse(quantityController.text.trim()) ?? 1,
          createdAt: DateTime.now(),
          expectedDate: DateTime.now(),
          note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
        ),
      );
      _refresh('Prenotazione aggiunta.');
    } catch (e) {
      setState(() => _message = 'Errore salvataggio prenotazione: $e');
    } finally {
      drugController.dispose();
      quantityController.dispose();
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

  Future<void> _deleteSinglePrescription(Patient patient, Prescription prescription) async {
    if (!await _confirmDelete('Eliminare questa ricetta?')) return;
    await _prescriptionsRepository.deletePrescription(patient.fiscalCode, prescription.id);
    try {
      await _drivePdfImportsRepository.deleteImport(prescription.id);
    } catch (_) {}
    _refresh('Ricetta eliminata.');
  }

  Future<bool> _confirmDelete(String text) async {
    final value = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Conferma', style: TextStyle(color: Colors.white)),
        content: Text(text, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annulla', style: TextStyle(color: Colors.white70))),
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FutureBuilder<_PatientDetailData>(
          future: _future,
          builder: (context, snapshot) {
            final data = snapshot.data;
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
                      ? Center(child: Text('Errore caricamento: ${snapshot.error}', style: const TextStyle(color: Colors.white)))
                      : data == null || data.patient == null
                          ? const Center(child: Text('Assistito non trovato.', style: TextStyle(color: Colors.white)))
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildHeader(data),
                                  if (_message.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text(_message, style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w700)),
                                  ],
                                  const SizedBox(height: 18),
                                  Wrap(
                                    spacing: 14,
                                    runSpacing: 14,
                                    children: [
                                      _summaryCard(
                                        label: 'Ricette',
                                        value: '${data.totalRecipeCount}',
                                        subtitle: '${data.prescriptions.length} documenti',
                                        color: AppColors.green,
                                        onTap: () => _managePrescriptions(data),
                                      ),
                                      _summaryCard(
                                        label: 'DPC',
                                        value: data.prescriptions.any((item) => item.dpcFlag) || data.imports.any((item) => item.isDpc) ? 'SI' : 'NO',
                                        subtitle: 'flag ricette',
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
                                  _section(
                                    title: 'Consigli terapeutici',
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if ((data.therapeuticAdvice?.text.trim() ?? '').isEmpty)
                                          const Text(
                                            'Nessun consiglio terapeutico registrato.',
                                            style: TextStyle(color: Colors.white70),
                                          )
                                        else
                                          Container(
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
                                        const SizedBox(height: 14),
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
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
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  _section(
                                    title: 'Terapie riepilogative',
                                    child: data.patient!.therapiesSummary.isEmpty
                                        ? const Text('Nessuna terapia disponibile.', style: TextStyle(color: Colors.white70))
                                        : Wrap(
                                            spacing: 10,
                                            runSpacing: 10,
                                            children: data.patient!.therapiesSummary
                                                .map((item) => Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.panelSoft,
                                                        borderRadius: BorderRadius.circular(14),
                                                      ),
                                                      child: Text(item, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                                    ))
                                                .toList(),
                                          ),
                                  ),
                                  const SizedBox(height: 18),
                                  _section(
                                    title: 'Dettaglio ricette',
                                    child: data.prescriptions.isEmpty
                                        ? const Text('Nessuna ricetta registrata.', style: TextStyle(color: Colors.white70))
                                        : Column(
                                            children: data.prescriptions.map((prescription) {
                                              final matchingImport = _findImportForPrescription(data.imports, prescription.id);
                                              final expiryInfo = PrescriptionExpiryUtils.evaluate(prescription.expiryDate);
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
                                                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                                                          ),
                                                        ),
                                                        if (matchingImport != null)
                                                          TextButton.icon(
                                                            onPressed: () => _openPdf(matchingImport),
                                                            icon: const Icon(Icons.open_in_new),
                                                            label: const Text('PDF'),
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
                                            }).toList(),
                                          ),
                                  ),
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
          onSelected: (index) {
            appNavigationIndex.value = index;
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      ],
    );
  }

  Widget _buildHeader(_PatientDetailData data) {
    final patient = data.patient!;
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
              _metaBadge('Esenzione', (patient.exemptionCode ?? '').trim().isEmpty ? '-' : patient.exemptionCode!.trim()),
              _metaBadge('Città', (patient.city ?? '').trim().isEmpty ? '-' : patient.city!.trim()),
              _metaBadge('Ultima ricetta', _formatDate(patient.lastPrescriptionDate)),
            ],
          ),
        ],
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

  Widget _section({required String title, required Widget child}) {
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
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _managerCard({required String title, required String subtitle, required List<Widget> actions, List<Widget> extra = const []}) {
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
              Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))),
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
            TextSpan(text: '$label: ', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
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
    for (final item in imports) {
      if (item.id == prescriptionId) return item;
    }
    return null;
  }

  String _prescriptionLabel(Prescription prescription) {
    final label = prescription.items.map((item) => item.drugName.trim()).where((item) => item.isNotEmpty).join(', ');
    return label.isEmpty ? 'Ricetta' : label;
  }

  String _localId(String prefix) => '${prefix}_${widget.fiscalCode}_${DateTime.now().microsecondsSinceEpoch}';

  double _parseEuro(String raw) {
    final normalized = raw.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  DateTime? _parseItalianDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final match = RegExp(r'^(\d{1,2})\/(\d{1,2})\/(\d{4})$').firstMatch(value);
    if (match == null) return null;
    return DateTime(int.parse(match.group(3)!), int.parse(match.group(2)!), int.parse(match.group(1)!));
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
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
  final AppSettings settings;
  final String resolvedDoctorName;
  final TherapeuticAdviceNote? therapeuticAdvice;

  const _PatientDetailData({
    required this.patient,
    required this.advances,
    required this.debts,
    required this.bookings,
    required this.prescriptions,
    required this.imports,
    required this.settings,
    required this.resolvedDoctorName,
    required this.therapeuticAdvice,
  });

  double get totalDebt => debts.fold<double>(0, (sum, item) => sum + item.residualAmount);

  int get totalRecipeCount => prescriptions.fold<int>(0, (sum, item) => sum + item.prescriptionCount);
}
