import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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
import '../../../core/services/mock_prescription_parser_service.dart';
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
  final MockPrescriptionParserService parser = MockPrescriptionParserService();

  bool isUploading = false;
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
                              _buildUploadArea(),
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

  Future<void> uploadMockPrescription() async {
    setState(() {
      isUploading = true;
      uploadMessage = '';
    });

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>['jpg', 'jpeg', 'png', 'pdf', 'txt'],
        withData: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          uploadMessage = 'Upload annullato.';
        });
        return;
      }

      final PlatformFile file = result.files.first;
      final MockPrescriptionParserResult parsed = parser.parse(
        fileName: file.name,
        rawText: file.name,
      );

      if (parsed.fiscalCode != widget.fiscalCode) {
        setState(() {
          uploadMessage =
              'Il parser mock ha associato la ricetta a ${parsed.patientName}, non a questo assistito.';
        });
        return;
      }

      final Prescription prescription = parsed.toPrescription();
      await prescriptionsRepository.savePrescription(prescription);

      setState(() {
        uploadMessage =
            'Ricetta mock caricata, scadenza valutata e anagrafica aggiornata.';
      });
    } catch (e) {
      setState(() {
        uploadMessage = 'Errore upload mock: $e';
      });
    } finally {
      setState(() {
        isUploading = false;
      });
    }
  }

  Widget _buildHeader(Patient patient) {
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(patient.fullName, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text(patient.fiscalCode, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  ],
                ),
              ),
              patient.hasDpc
                  ? const StatusBadge(text: 'DPC', color: AppColors.coral)
                  : const StatusBadge(text: 'NO DPC', color: Color(0xFF2A2A2A)),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: <Widget>[
              _InfoCard(title: 'Città', value: patient.city ?? '-'),
              _InfoCard(title: 'Esenzione', value: patient.exemptionCode ?? '-'),
              _InfoCard(title: 'Medico', value: patient.doctorName ?? '-'),
              _InfoCard(title: 'Ricette archiviate', value: '${patient.archivedRecipeCount}'),
              _InfoCard(title: 'Debito totale', value: '€ ${patient.debtTotal.toStringAsFixed(2)}'),
              _InfoCard(title: 'Ultima ricetta', value: _formatDate(patient.lastPrescriptionDate)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUploadArea() {
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
          const Text(
            'Upload ricetta mock',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          const Text(
            'Carica un file con nome che contenga Mario, Luigi, Giuseppe o Maria. Il parser mock estrarrà i dati, salverà una ricetta e aggiornerà automaticamente l\'anagrafica assistito.',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: isUploading ? null : uploadMockPrescription,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.yellow,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            icon: const Icon(Icons.upload_file),
            label: Text(
              isUploading ? 'Caricamento...' : 'Carica ricetta mock',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          if (uploadMessage.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(uploadMessage, style: const TextStyle(color: Colors.white70)),
          ],
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
