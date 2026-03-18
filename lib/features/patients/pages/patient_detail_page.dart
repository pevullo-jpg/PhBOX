import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/prescription_expiry_utils.dart';
import '../../../data/datasources/firestore_firebase_datasource.dart';
import '../../../data/models/advance.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/debt.dart';
import '../../../data/models/patient.dart';
import '../../../data/models/prescription.dart';
import '../../../data/repositories/advances_repository.dart';
import '../../../data/repositories/bookings_repository.dart';
import '../../../data/repositories/debts_repository.dart';
import '../../../data/repositories/drive_pdf_imports_repository.dart';
import '../../../data/repositories/patients_repository.dart';
import '../../../data/repositories/prescriptions_repository.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../theme/app_theme.dart';

class PatientDetailPage extends StatefulWidget {
  final String fiscalCode;

  const PatientDetailPage({
    super.key,
    required this.fiscalCode,
  });

  @override
  State<PatientDetailPage> createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends State<PatientDetailPage> {
  late final PatientsRepository patientsRepository;
  late final AdvancesRepository advancesRepository;
  late final DebtsRepository debtsRepository;
  late final BookingsRepository bookingsRepository;
  late final PrescriptionsRepository prescriptionsRepository;
  late final DrivePdfImportsRepository drivePdfImportsRepository;

  bool isSavingQuickAction = false;
  String uploadMessage = '';

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
  Widget build(BuildContext context) {
    return FutureBuilder<_PatientDetailData>(
      future: _loadAll(),
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
                        'Errore caricamento assistito: ${snapshot.error}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    )
                  : data == null || data.patient == null
                      ? const Center(
                          child: Text(
                            'Assistito non trovato.',
                            style: TextStyle(color: Colors.white),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              _buildHeader(data.patient!),
                              const SizedBox(height: 20),
                              Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                children: <Widget>[
                                  _ActionSummaryCard(
                                    label: 'Debiti',
                                    value:
                                        '€ ${data.totalDebt.toStringAsFixed(2)}',
                                    subtitle: '${data.debts.length} voci',
                                    color: AppColors.wine,
                                    onTap: () => _openDebtsManager(data.patient!, data.debts),
                                    onClear: data.debts.isEmpty
                                        ? null
                                        : () => _deleteAllDebts(data.patient!, data.debts),
                                  ),
                                  _ActionSummaryCard(
                                    label: 'Anticipi',
                                    value: '${data.advances.length}',
                                    subtitle: 'gestisci elenco',
                                    color: AppColors.amber,
                                    onTap: () => _openAdvancesManager(data.patient!, data.advances),
                                    onClear: data.advances.isEmpty
                                        ? null
                                        : () => _deleteAllAdvances(data.patient!, data.advances),
                                  ),
                                  _ActionSummaryCard(
                                    label: 'Prenotazioni',
                                    value: '${data.bookings.length}',
                                    subtitle: 'gestisci elenco',
                                    color: AppColors.coral,
                                    onTap: () => _openBookingsManager(data.patient!, data.bookings),
                                    onClear: data.bookings.isEmpty
                                        ? null
                                        : () => _deleteAllBookings(data.patient!, data.bookings),
                                  ),
                                  _ActionSummaryCard(
                                    label: 'Ricette',
                                    value: '${data.totalRecipeCount}',
                                    subtitle: '${data.prescriptions.length} documenti',
                                    color: AppColors.green,
                                    onTap: () => _openPrescriptionsManager(data.patient!, data.prescriptions),
                                    onClear: data.prescriptions.isEmpty
                                        ? null
                                        : () => _deleteAllPrescriptions(data.patient!, data.prescriptions),
                                  ),
                                ],
                              ),
                              if (uploadMessage.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 16),
                                Text(
                                  uploadMessage,
                                  style: TextStyle(
                                    color: uploadMessage.toLowerCase().contains('errore')
                                        ? AppColors.red
                                        : AppColors.green,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              _buildTherapies(data.patient!),
                              const SizedBox(height: 20),
                              _buildPrescriptionDetails(data.patient!, data.prescriptions),
                            ],
                          ),
                        ),
        );
      },
    );
  }

  Future<_PatientDetailData> _loadAll() async {
    final Patient? patient =
        await patientsRepository.getPatientByFiscalCode(widget.fiscalCode);
    final List<Advance> advances =
        await advancesRepository.getPatientAdvances(widget.fiscalCode);
    final List<Debt> debts = await debtsRepository.getPatientDebts(widget.fiscalCode);
    final List<Booking> bookings =
        await bookingsRepository.getPatientBookings(widget.fiscalCode);
    final List<Prescription> prescriptions =
        await prescriptionsRepository.getPatientPrescriptions(widget.fiscalCode);

    return _PatientDetailData(
      patient: patient,
      advances: advances,
      debts: debts,
      bookings: bookings,
      prescriptions: prescriptions,
    );
  }

  Future<void> _refreshPatientFlags(Patient patient) async {
    await prescriptionsRepository.refreshPatientAggregates(patient.fiscalCode);
    final Patient? current =
        await patientsRepository.getPatientByFiscalCode(patient.fiscalCode);
    if (current == null) return;

    final List<Debt> debts = await debtsRepository.getPatientDebts(patient.fiscalCode);
    final List<Advance> advances =
        await advancesRepository.getPatientAdvances(patient.fiscalCode);
    final List<Booking> bookings =
        await bookingsRepository.getPatientBookings(patient.fiscalCode);

    final double totalDebt = debts.fold<double>(
      0,
      (double sum, Debt item) => sum + item.residualAmount,
    );

    await patientsRepository.savePatient(
      current.copyWith(
        hasDebt: debts.isNotEmpty,
        debtTotal: totalDebt,
        hasAdvance: advances.isNotEmpty,
        hasBooking: bookings.isNotEmpty,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _openDebtsManager(Patient patient, List<Debt> debts) async {
    await _openCollectionManager<Debt>(
      title: 'Debiti',
      items: debts,
      emptyLabel: 'Nessun debito registrato.',
      buildRow: (Debt debt) => _ManagerRow(
        title: debt.description,
        subtitle:
            'Residuo € ${debt.residualAmount.toStringAsFixed(2)} · Scadenza ${_formatDate(debt.dueDate)}${debt.note == null || debt.note!.trim().isEmpty ? '' : ' · ${debt.note!.trim()}'}',
        badge: StatusBadge(text: debt.status.toUpperCase(), color: AppColors.wine),
        onDelete: () => _deleteSingleDebt(patient, debt),
      ),
      onAdd: () => _openAddDebtDialog(patient),
    );
  }

  Future<void> _openAdvancesManager(Patient patient, List<Advance> advances) async {
    await _openCollectionManager<Advance>(
      title: 'Anticipi',
      items: advances,
      emptyLabel: 'Nessun anticipo registrato.',
      buildRow: (Advance advance) => _ManagerRow(
        title: advance.drugName,
        subtitle:
            '${advance.doctorName.isEmpty ? '-' : advance.doctorName}${advance.note == null || advance.note!.trim().isEmpty ? '' : ' · ${advance.note!.trim()}'}',
        badge: StatusBadge(
          text: advance.matchedTherapyFlag ? 'MATCH' : advance.status.toUpperCase(),
          color: advance.matchedTherapyFlag ? AppColors.green : AppColors.amber,
        ),
        onDelete: () => _deleteSingleAdvance(patient, advance),
      ),
      onAdd: () => _openAddAdvanceDialog(patient),
    );
  }

  Future<void> _openBookingsManager(Patient patient, List<Booking> bookings) async {
    await _openCollectionManager<Booking>(
      title: 'Prenotazioni',
      items: bookings,
      emptyLabel: 'Nessuna prenotazione registrata.',
      buildRow: (Booking booking) => _ManagerRow(
        title: '${booking.drugName} x${booking.quantity}',
        subtitle:
            'Prevista ${_formatDate(booking.expectedDate)}${booking.note == null || booking.note!.trim().isEmpty ? '' : ' · ${booking.note!.trim()}'}',
        badge: StatusBadge(text: booking.status.toUpperCase(), color: AppColors.coral),
        onDelete: () => _deleteSingleBooking(patient, booking),
      ),
      onAdd: () => _openAddBookingDialog(patient),
    );
  }

  Future<void> _openPrescriptionsManager(Patient patient, List<Prescription> prescriptions) async {
    await _openCollectionManager<Prescription>(
      title: 'Ricette',
      items: prescriptions,
      emptyLabel: 'Nessuna ricetta registrata.',
      buildRow: (Prescription prescription) => _ManagerRow(
        title: _prescriptionTitle(prescription),
        subtitle:
            '${_formatDate(prescription.prescriptionDate)} · ${prescription.doctorName ?? '-'} · ${prescription.prescriptionCount} ricetta/e',
        badge: StatusBadge(
          text: prescription.dpcFlag ? 'DPC' : prescription.sourceType.toUpperCase(),
          color: prescription.dpcFlag ? AppColors.coral : AppColors.green,
        ),
        onDelete: () => _deleteSinglePrescription(patient, prescription),
      ),
    );
  }

  Future<void> _openCollectionManager<T>({
    required String title,
    required List<T> items,
    required String emptyLabel,
    required Widget Function(T item) buildRow,
    Future<void> Function()? onAdd,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: AppColors.panel,
          child: SizedBox(
            width: 760,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (onAdd != null)
                        FilledButton.icon(
                          onPressed: () async {
                            Navigator.of(dialogContext).pop();
                            await onAdd();
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Aggiungi'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 520),
                    child: items.isEmpty
                        ? Text(emptyLabel, style: const TextStyle(color: Colors.white70))
                        : SingleChildScrollView(
                            child: Column(
                              children: items.map(buildRow).toList(),
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

  Future<void> _openAddDebtDialog(Patient patient) async {
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    final TextEditingController dueDateController = TextEditingController();
    final TextEditingController noteController = TextEditingController();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.panel,
          title: const Text('Nuovo debito', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _dialogField(controller: descriptionController, label: 'Descrizione'),
                  const SizedBox(height: 12),
                  _dialogField(
                    controller: amountController,
                    label: 'Importo (€)',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9,\.]')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _dialogField(controller: dueDateController, label: 'Scadenza (gg/mm/aaaa)'),
                  const SizedBox(height: 12),
                  _dialogField(controller: noteController, label: 'Nota', maxLines: 3),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annulla', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.wine,
                foregroundColor: Colors.white,
              ),
              child: const Text('Salva'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      descriptionController.dispose();
      amountController.dispose();
      dueDateController.dispose();
      noteController.dispose();
      return;
    }

    try {
      setState(() {
        isSavingQuickAction = true;
        uploadMessage = '';
      });

      final String description = descriptionController.text.trim();
      final double amount = _parseEuro(amountController.text);
      final DateTime? dueDate = _parseItalianDate(dueDateController.text);
      final String note = noteController.text.trim();

      if (description.isEmpty) {
        throw Exception('Inserisci la descrizione del debito.');
      }
      if (amount <= 0) {
        throw Exception('Inserisci un importo valido.');
      }

      final Debt debt = Debt(
        id: _buildLocalId('debt', patient.fiscalCode),
        patientFiscalCode: patient.fiscalCode,
        patientName: patient.fullName,
        description: description,
        amount: amount,
        paidAmount: 0,
        residualAmount: amount,
        createdAt: DateTime.now(),
        dueDate: dueDate,
        status: 'open',
        note: note.isEmpty ? null : note,
      );

      await debtsRepository.saveDebt(debt);
      await _refreshPatientFlags(patient);

      if (!mounted) return;
      setState(() {
        uploadMessage = 'Debito aggiunto correttamente.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        uploadMessage = 'Errore salvataggio debito: $e';
      });
    } finally {
      descriptionController.dispose();
      amountController.dispose();
      dueDateController.dispose();
      noteController.dispose();
      if (mounted) {
        setState(() {
          isSavingQuickAction = false;
        });
      }
    }
  }

  Future<void> _openAddAdvanceDialog(Patient patient) async {
    final TextEditingController drugController = TextEditingController();
    final TextEditingController doctorController =
        TextEditingController(text: (patient.doctorName ?? '').trim());
    final TextEditingController noteController = TextEditingController(
      text: (patient.exemptionCode ?? '').trim().isEmpty
          ? ''
          : 'Esenzione: ${patient.exemptionCode!.trim()}',
    );
    bool matchedTherapyFlag = false;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setModalState) {
            return AlertDialog(
              backgroundColor: AppColors.panel,
              title: const Text('Nuovo anticipo', style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if ((patient.doctorName ?? '').trim().isNotEmpty ||
                          (patient.exemptionCode ?? '').trim().isNotEmpty) ...<Widget>[
                        const Text(
                          'Suggerimenti memoria assistito',
                          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            if ((patient.doctorName ?? '').trim().isNotEmpty)
                              ActionChip(
                                label: Text('Medico: ${patient.doctorName!.trim()}'),
                                onPressed: () => doctorController.text = patient.doctorName!.trim(),
                              ),
                            if ((patient.exemptionCode ?? '').trim().isNotEmpty)
                              ActionChip(
                                label: Text('Esenzione: ${patient.exemptionCode!.trim()}'),
                                onPressed: () {
                                  final String prefix = 'Esenzione: ${patient.exemptionCode!.trim()}';
                                  if (!noteController.text.contains(prefix)) {
                                    noteController.text = noteController.text.trim().isEmpty
                                        ? prefix
                                        : '$prefix · ${noteController.text.trim()}';
                                  }
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                      _dialogField(controller: drugController, label: 'Farmaco / articolo'),
                      const SizedBox(height: 12),
                      _dialogField(controller: doctorController, label: 'Medico'),
                      const SizedBox(height: 12),
                      _dialogField(controller: noteController, label: 'Nota', maxLines: 3),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        value: matchedTherapyFlag,
                        activeColor: AppColors.green,
                        title: const Text('Già allineato a terapia', style: TextStyle(color: Colors.white)),
                        subtitle: const Text('Attivalo se l’anticipo corrisponde a una terapia nota.', style: TextStyle(color: Colors.white70)),
                        onChanged: (bool value) => setModalState(() => matchedTherapyFlag = value),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Annulla', style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: Colors.black,
                  ),
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
      setState(() {
        isSavingQuickAction = true;
        uploadMessage = '';
      });

      final String drugName = drugController.text.trim();
      final String doctorName = doctorController.text.trim();
      final String note = noteController.text.trim();

      if (drugName.isEmpty) {
        throw Exception('Inserisci il nome dell’anticipo.');
      }
      if (doctorName.isEmpty) {
        throw Exception('Seleziona o inserisci il medico.');
      }

      final Advance advance = Advance(
        id: _buildLocalId('advance', patient.fiscalCode),
        patientFiscalCode: patient.fiscalCode,
        patientName: patient.fullName,
        drugName: drugName,
        doctorName: doctorName,
        note: note.isEmpty ? null : note,
        matchedTherapyFlag: matchedTherapyFlag,
        status: 'open',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await advancesRepository.saveAdvance(advance);
      await _refreshPatientFlags(patient);

      if (!mounted) return;
      setState(() {
        uploadMessage = 'Anticipo aggiunto correttamente.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        uploadMessage = 'Errore salvataggio anticipo: $e';
      });
    } finally {
      drugController.dispose();
      doctorController.dispose();
      noteController.dispose();
      if (mounted) {
        setState(() {
          isSavingQuickAction = false;
        });
      }
    }
  }

  Future<void> _openAddBookingDialog(Patient patient) async {
    final TextEditingController drugController = TextEditingController();
    final TextEditingController quantityController = TextEditingController(text: '1');
    final TextEditingController expectedDateController = TextEditingController();
    final TextEditingController noteController = TextEditingController();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.panel,
          title: const Text('Nuova prenotazione', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _dialogField(controller: drugController, label: 'Farmaco / articolo'),
                  const SizedBox(height: 12),
                  _dialogField(
                    controller: quantityController,
                    label: 'Quantità',
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 12),
                  _dialogField(controller: expectedDateController, label: 'Data prevista (gg/mm/aaaa)'),
                  const SizedBox(height: 12),
                  _dialogField(controller: noteController, label: 'Nota', maxLines: 3),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annulla', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.coral,
                foregroundColor: Colors.white,
              ),
              child: const Text('Salva'),
            ),
          ],
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
      setState(() {
        isSavingQuickAction = true;
        uploadMessage = '';
      });

      final String drugName = drugController.text.trim();
      final int quantity = int.tryParse(quantityController.text.trim()) ?? 1;
      final DateTime? expectedDate = _parseItalianDate(expectedDateController.text);
      final String note = noteController.text.trim();

      if (drugName.isEmpty) {
        throw Exception('Inserisci il nome della prenotazione.');
      }
      if (quantity <= 0) {
        throw Exception('Inserisci una quantità valida.');
      }

      final Booking booking = Booking(
        id: _buildLocalId('booking', patient.fiscalCode),
        patientFiscalCode: patient.fiscalCode,
        patientName: patient.fullName,
        drugName: drugName,
        quantity: quantity,
        createdAt: DateTime.now(),
        expectedDate: expectedDate,
        status: 'open',
        note: note.isEmpty ? null : note,
      );

      await bookingsRepository.saveBooking(booking);
      await _refreshPatientFlags(patient);

      if (!mounted) return;
      setState(() {
        uploadMessage = 'Prenotazione aggiunta correttamente.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        uploadMessage = 'Errore salvataggio prenotazione: $e';
      });
    } finally {
      drugController.dispose();
      quantityController.dispose();
      expectedDateController.dispose();
      noteController.dispose();
      if (mounted) {
        setState(() {
          isSavingQuickAction = false;
        });
      }
    }
  }

  Future<void> _deleteSingleDebt(Patient patient, Debt debt) async {
    if (!await _confirmDelete('Eliminare questa voce debito?')) return;
    try {
      await debtsRepository.deleteDebt(patient.fiscalCode, debt.id);
      await _refreshPatientFlags(patient);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => uploadMessage = 'Voce debito eliminata.');
    } catch (e) {
      if (!mounted) return;
      setState(() => uploadMessage = 'Errore eliminazione debito: $e');
    }
  }

  Future<void> _deleteSingleAdvance(Patient patient, Advance advance) async {
    if (!await _confirmDelete('Eliminare questo anticipo?')) return;
    try {
      await advancesRepository.deleteAdvance(patient.fiscalCode, advance.id);
      await _refreshPatientFlags(patient);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => uploadMessage = 'Anticipo eliminato.');
    } catch (e) {
      if (!mounted) return;
      setState(() => uploadMessage = 'Errore eliminazione anticipo: $e');
    }
  }

  Future<void> _deleteSingleBooking(Patient patient, Booking booking) async {
    if (!await _confirmDelete('Eliminare questa prenotazione?')) return;
    try {
      await bookingsRepository.deleteBooking(patient.fiscalCode, booking.id);
      await _refreshPatientFlags(patient);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => uploadMessage = 'Prenotazione eliminata.');
    } catch (e) {
      if (!mounted) return;
      setState(() => uploadMessage = 'Errore eliminazione prenotazione: $e');
    }
  }

  Future<void> _deleteSinglePrescription(Patient patient, Prescription prescription) async {
    if (!await _confirmDelete('Eliminare questa ricetta?')) return;
    try {
      if (prescription.sourceType == 'script') {
        await drivePdfImportsRepository.deleteImport(prescription.id);
      } else {
        await prescriptionsRepository.deletePrescription(patient.fiscalCode, prescription.id);
      }
      await _refreshPatientFlags(patient);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => uploadMessage = 'Ricetta eliminata.');
    } catch (e) {
      if (!mounted) return;
      setState(() => uploadMessage = 'Errore eliminazione ricetta: $e');
    }
  }

  Future<void> _deleteAllDebts(Patient patient, List<Debt> debts) async {
    if (!await _confirmDelete('Eliminare tutti i debiti dell’assistito?')) return;
    try {
      for (final Debt debt in debts) {
        await debtsRepository.deleteDebt(patient.fiscalCode, debt.id);
      }
      await _refreshPatientFlags(patient);
      if (!mounted) return;
      setState(() => uploadMessage = 'Tutti i debiti eliminati.');
    } catch (e) {
      if (!mounted) return;
      setState(() => uploadMessage = 'Errore eliminazione debiti: $e');
    }
  }

  Future<void> _deleteAllAdvances(Patient patient, List<Advance> advances) async {
    if (!await _confirmDelete('Eliminare tutti gli anticipi dell’assistito?')) return;
    try {
      for (final Advance advance in advances) {
        await advancesRepository.deleteAdvance(patient.fiscalCode, advance.id);
      }
      await _refreshPatientFlags(patient);
      if (!mounted) return;
      setState(() => uploadMessage = 'Tutti gli anticipi eliminati.');
    } catch (e) {
      if (!mounted) return;
      setState(() => uploadMessage = 'Errore eliminazione anticipi: $e');
    }
  }

  Future<void> _deleteAllBookings(Patient patient, List<Booking> bookings) async {
    if (!await _confirmDelete('Eliminare tutte le prenotazioni dell’assistito?')) return;
    try {
      for (final Booking booking in bookings) {
        await bookingsRepository.deleteBooking(patient.fiscalCode, booking.id);
      }
      await _refreshPatientFlags(patient);
      if (!mounted) return;
      setState(() => uploadMessage = 'Tutte le prenotazioni eliminate.');
    } catch (e) {
      if (!mounted) return;
      setState(() => uploadMessage = 'Errore eliminazione prenotazioni: $e');
    }
  }

  Future<void> _deleteAllPrescriptions(Patient patient, List<Prescription> prescriptions) async {
    if (!await _confirmDelete('Eliminare tutte le ricette dell’assistito?')) return;
    try {
      await prescriptionsRepository.deleteAllPatientPrescriptions(patient.fiscalCode);
      await drivePdfImportsRepository.deleteImportsByPatient(patient.fiscalCode);
      await _refreshPatientFlags(patient);
      if (!mounted) return;
      setState(() => uploadMessage = 'Tutte le ricette eliminate.');
    } catch (e) {
      if (!mounted) return;
      setState(() => uploadMessage = 'Errore eliminazione ricette: $e');
    }
  }

  Future<bool> _confirmDelete(String message) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.panel,
          title: const Text('Conferma eliminazione', style: TextStyle(color: Colors.white)),
          content: Text(message, style: const TextStyle(color: Colors.white70)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annulla', style: TextStyle(color: Colors.white70)),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.red),
              child: const Text('Elimina'),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
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

  String _buildLocalId(String prefix, String fiscalCode) {
    final String ts = DateTime.now().microsecondsSinceEpoch.toString();
    return '${prefix}_${fiscalCode}_$ts';
  }

  double _parseEuro(String raw) {
    final String normalized = raw.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  DateTime? _parseItalianDate(String raw) {
    final String value = raw.trim();
    if (value.isEmpty) return null;
    final Match? match = RegExp(r'^(\d{1,2})\/(\d{1,2})\/(\d{4})$').firstMatch(value);
    if (match == null) return null;
    final int day = int.parse(match.group(1)!);
    final int month = int.parse(match.group(2)!);
    final int year = int.parse(match.group(3)!);
    return DateTime(year, month, day);
  }

  Widget _buildHeader(Patient patient) {
    final DateTime? lastDate = patient.lastPrescriptionDate;
    final String lastDateLabel = lastDate == null
        ? '-'
        : '${lastDate.day.toString().padLeft(2, '0')}/${lastDate.month.toString().padLeft(2, '0')}/${lastDate.year}';

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
        children: <Widget>[
          Text(
            patient.fullName.isEmpty ? 'Assistito' : patient.fullName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _MetaBadge(label: 'CF', value: patient.fiscalCode),
              _MetaBadge(label: 'Città', value: (patient.city ?? '').trim().isEmpty ? '-' : patient.city!.trim()),
              _MetaBadge(label: 'Esenzione', value: (patient.exemptionCode ?? '').trim().isEmpty ? '-' : patient.exemptionCode!.trim()),
              _MetaBadge(label: 'Medico', value: (patient.doctorName ?? '').trim().isEmpty ? '-' : patient.doctorName!.trim()),
              _MetaBadge(label: 'Ultima ricetta', value: lastDateLabel),
              _MetaBadge(label: 'Ricette', value: '${patient.archivedRecipeCount}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTherapies(Patient patient) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Terapie riepilogative', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 18),
          if (patient.therapiesSummary.isEmpty)
            const Text('Nessuna terapia disponibile.', style: TextStyle(color: Colors.white70))
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: patient.therapiesSummary.map((String therapy) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.panelSoft, borderRadius: BorderRadius.circular(16)),
                  child: Text(therapy, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionDetails(Patient patient, List<Prescription> prescriptions) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Dettaglio ricette', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 18),
          if (prescriptions.isEmpty)
            const Text('Nessuna ricetta registrata.', style: TextStyle(color: Colors.white70))
          else
            Column(
              children: prescriptions.map((Prescription prescription) {
                final PrescriptionExpiryInfo expiryInfo =
                    PrescriptionExpiryUtils.evaluate(prescription.expiryDate);
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.panelSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  _prescriptionTitle(prescription),
                                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: <Widget>[
                                    StatusBadge(text: expiryInfo.label, color: expiryInfo.color),
                                    StatusBadge(
                                      text: prescription.dpcFlag ? 'DPC' : prescription.sourceType.toUpperCase(),
                                      color: prescription.dpcFlag ? AppColors.coral : AppColors.green,
                                    ),
                                    StatusBadge(text: '${prescription.prescriptionCount} ricetta/e', color: AppColors.amber),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Elimina ricetta',
                            onPressed: () => _deleteSinglePrescription(patient, prescription),
                            icon: const Icon(Icons.delete_outline, color: AppColors.red),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _detailRow('Data', _formatDate(prescription.prescriptionDate)),
                      _detailRow('Scadenza', _formatDate(prescription.expiryDate)),
                      _detailRow('Medico', (prescription.doctorName ?? '-').trim().isEmpty ? '-' : prescription.doctorName!.trim()),
                      _detailRow('Esenzione', (prescription.exemptionCode ?? '-').trim().isEmpty ? '-' : prescription.exemptionCode!.trim()),
                      _detailRow('Città', (prescription.city ?? '-').trim().isEmpty ? '-' : prescription.city!.trim()),
                      _detailRow('Terapie', _prescriptionItemsLabel(prescription)),
                      if (prescription.sourceType == 'script') ...<Widget>[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: () => _openPdfByPrescription(patient, prescription),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Apri PDF'),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Future<void> _openPdfByPrescription(Patient patient, Prescription prescription) async {
    final imports = await drivePdfImportsRepository.getImportsByPatient(patient.fiscalCode);
    final match = imports.where((item) => item.id == prescription.id).toList();
    if (match.isEmpty || match.first.webViewLink.trim().isEmpty) {
      if (!mounted) return;
      setState(() => uploadMessage = 'PDF non disponibile per questa ricetta.');
      return;
    }
    await launchUrl(Uri.parse(match.first.webViewLink), webOnlyWindowName: '_blank');
  }

  String _prescriptionTitle(Prescription prescription) {
    final String label = _prescriptionItemsLabel(prescription);
    return label.isEmpty ? 'Ricetta' : label;
  }

  String _prescriptionItemsLabel(Prescription prescription) {
    return prescription.items
        .map((item) => item.drugName.trim())
        .where((String item) => item.isNotEmpty)
        .join(', ');
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white70, height: 1.4),
          children: <InlineSpan>[
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
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

class _MetaBadge extends StatelessWidget {
  final String label;
  final String value;

  const _MetaBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.panelSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white),
          children: <InlineSpan>[
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white70),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientDetailData {
  final Patient? patient;
  final List<Advance> advances;
  final List<Debt> debts;
  final List<Booking> bookings;
  final List<Prescription> prescriptions;

  _PatientDetailData({
    required this.patient,
    required this.advances,
    required this.debts,
    required this.bookings,
    required this.prescriptions,
  });

  double get totalDebt => debts.fold<double>(
        0,
        (double sum, Debt item) => sum + item.residualAmount,
      );

  int get totalRecipeCount => prescriptions.fold<int>(
        0,
        (int sum, Prescription item) => sum + item.prescriptionCount,
      );
}

class _ActionSummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _ActionSummaryCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 270,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClear,
                  splashRadius: 18,
                  icon: Icon(
                    Icons.delete_outline,
                    color: onClear == null ? Colors.white38 : Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.84))),
          ],
        ),
      ),
    );
  }
}

class _ManagerRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget badge;
  final VoidCallback onDelete;

  const _ManagerRow({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.panelSoft, borderRadius: BorderRadius.circular(18)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(subtitle, style: const TextStyle(color: Colors.white70, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          badge,
          const SizedBox(width: 8),
          IconButton(
            onPressed: onDelete,
            tooltip: 'Elimina',
            icon: const Icon(Icons.delete_outline, color: AppColors.red),
          ),
        ],
      ),
    );
  }
}
