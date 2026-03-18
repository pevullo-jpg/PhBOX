import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PatientDetailData>(
      future: _loadAll(),
      builder: (BuildContext context, AsyncSnapshot<_PatientDetailData> snapshot) {
        final _PatientDetailData? data = snapshot.data;

        return Scaffold(
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
                          child: Text('Assistito non trovato.', style: TextStyle(color: Colors.white)),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              _buildHeader(data.patient!),
                              const SizedBox(height: 20),
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: _FlagCard(
                                      label: 'Debiti',
                                      value: '${data.debts.length}',
                                      color: data.debts.isNotEmpty ? AppColors.wine : AppColors.green,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _FlagCard(
                                      label: 'Anticipi',
                                      value: '${data.advances.length}',
                                      color: data.advances.isNotEmpty ? AppColors.amber : AppColors.green,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _FlagCard(
                                      label: 'Prenotazioni',
                                      value: '${data.bookings.length}',
                                      color: data.bookings.isNotEmpty ? AppColors.coral : AppColors.green,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: <Widget>[
                                  ElevatedButton.icon(
                                    onPressed: isSavingQuickAction ? null : () => _openAddDebtDialog(data.patient!),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.wine,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    ),
                                    icon: const Icon(Icons.payments_outlined),
                                    label: Text(
                                      isSavingQuickAction ? 'Salvataggio...' : 'Aggiungi debito',
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: isSavingQuickAction ? null : () => _openAddBookingDialog(data.patient!),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.coral,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    ),
                                    icon: const Icon(Icons.event_note_outlined),
                                    label: Text(
                                      isSavingQuickAction ? 'Salvataggio...' : 'Aggiungi prenotazione',
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              _buildTherapies(data.patient!),
                              const SizedBox(height: 20),
                              _buildPrescriptions(data.prescriptions),
                              const SizedBox(height: 20),
                              _buildDebts(data.debts),
                              const SizedBox(height: 20),
                              _buildAdvances(data.advances),
                              const SizedBox(height: 20),
                              _buildBookings(data.bookings),
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
    final List<Debt> debts =
        await debtsRepository.getPatientDebts(widget.fiscalCode);
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
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.wine, foregroundColor: Colors.white),
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
      await patientsRepository.savePatient(
        patient.copyWith(
          hasDebt: true,
          debtTotal: patient.debtTotal + amount,
          updatedAt: DateTime.now(),
        ),
      );

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
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral, foregroundColor: Colors.white),
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
      await patientsRepository.savePatient(
        patient.copyWith(
          hasBooking: true,
          updatedAt: DateTime.now(),
        ),
      );

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

  Widget _buildPrescriptions(List<Prescription> prescriptions) {
    return _SectionCard(
      title: 'Ricette',
      emptyLabel: 'Nessuna ricetta registrata.',
      child: prescriptions.isEmpty
          ? null
          : Column(
              children: prescriptions.map((Prescription prescription) {
                final String itemLabel =
                    prescription.items.map((item) => item.drugName).join(', ');
                final expiryInfo = PrescriptionExpiryUtils.evaluate(prescription.expiryDate);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.panelSoft,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              itemLabel.isEmpty ? 'Ricetta' : itemLabel,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_formatDate(prescription.prescriptionDate)} · ${prescription.doctorName ?? '-'} · scadenza ${_formatDate(prescription.expiryDate)}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      StatusBadge(text: expiryInfo.label, color: expiryInfo.color),
                      const SizedBox(width: 8),
                      StatusBadge(
                        text: prescription.sourceType.toUpperCase(),
                        color: prescription.dpcFlag ? AppColors.coral : AppColors.green,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildDebts(List<Debt> debts) {
    return _SectionCard(
      title: 'Debiti',
      emptyLabel: 'Nessun debito registrato.',
      child: debts.isEmpty
          ? null
          : Column(
              children: debts.map((Debt debt) {
                return _LineItem(
                  title: debt.description,
                  subtitle:
                      'Residuo € ${debt.residualAmount.toStringAsFixed(2)} · Scadenza ${_formatDate(debt.dueDate)}',
                  badgeText: debt.status.toUpperCase(),
                  badgeColor: AppColors.wine,
                );
              }).toList(),
            ),
    );
  }

  Widget _buildAdvances(List<Advance> advances) {
    return _SectionCard(
      title: 'Anticipi',
      emptyLabel: 'Nessun anticipo registrato.',
      child: advances.isEmpty
          ? null
          : Column(
              children: advances.map((Advance advance) {
                return _LineItem(
                  title: advance.drugName,
                  subtitle: '${advance.doctorName} · ${advance.note ?? 'Nessuna nota'}',
                  badgeText: advance.matchedTherapyFlag ? 'MATCH' : 'CHECK',
                  badgeColor: advance.matchedTherapyFlag ? AppColors.green : AppColors.amber,
                );
              }).toList(),
            ),
    );
  }

  Widget _buildBookings(List<Booking> bookings) {
    return _SectionCard(
      title: 'Prenotazioni',
      emptyLabel: 'Nessuna prenotazione registrata.',
      child: bookings.isEmpty
          ? null
          : Column(
              children: bookings.map((Booking booking) {
                return _LineItem(
                  title: '${booking.drugName} x${booking.quantity}',
                  subtitle:
                      'Prevista ${_formatDate(booking.expectedDate)} · ${booking.note ?? 'Nessuna nota'}',
                  badgeText: booking.status.toUpperCase(),
                  badgeColor: AppColors.coral,
                );
              }).toList(),
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
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;

  const _InfoCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.panelSoft, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _FlagCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _FlagCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String emptyLabel;
  final Widget? child;

  const _SectionCard({
    required this.title,
    required this.emptyLabel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
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
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 18),
          child ?? Text(emptyLabel, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _LineItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badgeText;
  final Color badgeColor;

  const _LineItem({
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.panelSoft, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(subtitle, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          StatusBadge(text: badgeText, color: badgeColor),
        ],
      ),
    );
  }
}
