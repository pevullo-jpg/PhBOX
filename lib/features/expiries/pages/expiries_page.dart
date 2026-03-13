import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/prescription_expiry_utils.dart';
import '../../../data/datasources/firestore_firebase_datasource.dart';
import '../../../data/models/patient.dart';
import '../../../data/models/prescription.dart';
import '../../../data/repositories/patients_repository.dart';
import '../../../data/repositories/prescriptions_repository.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/table_header.dart';
import '../../../theme/app_theme.dart';

class ExpiriesPage extends StatefulWidget {
  const ExpiriesPage({super.key});

  @override
  State<ExpiriesPage> createState() => _ExpiriesPageState();
}

class _ExpiriesPageState extends State<ExpiriesPage> {
  late final PatientsRepository patientsRepository;
  late final PrescriptionsRepository prescriptionsRepository;

  @override
  void initState() {
    super.initState();
    final datasource = FirestoreFirebaseDatasource(FirebaseFirestore.instance);
    patientsRepository = PatientsRepository(datasource: datasource);
    prescriptionsRepository = PrescriptionsRepository(
      datasource: datasource,
      patientsRepository: patientsRepository,
    );
  }

  Future<List<_ExpiryRow>> _loadRows() async {
    final patients = await patientsRepository.getAllPatients();
    final List<_ExpiryRow> rows = <_ExpiryRow>[];

    for (final Patient patient in patients) {
      final prescriptions =
          await prescriptionsRepository.getPatientPrescriptions(patient.fiscalCode);

      for (final Prescription prescription in prescriptions) {
        rows.add(
          _ExpiryRow(
            patientName: patient.fullName,
            fiscalCode: patient.fiscalCode,
            doctorName: prescription.doctorName ?? '-',
            prescriptionDate: prescription.prescriptionDate,
            expiryDate: prescription.expiryDate,
            dpcFlag: prescription.dpcFlag,
            itemLabel: prescription.items.isEmpty
                ? 'Ricetta'
                : prescription.items.map((e) => e.drugName).join(', '),
          ),
        );
      }
    }

    rows.sort((a, b) {
      final aDate = a.expiryDate ?? DateTime(2100);
      final bDate = b.expiryDate ?? DateTime(2100);
      return aDate.compareTo(bDate);
    });

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_ExpiryRow>>(
      future: _loadRows(),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <_ExpiryRow>[];

        final expiredCount = rows
            .where((r) =>
                PrescriptionExpiryUtils.evaluate(r.expiryDate).status ==
                PrescriptionValidityStatus.expired)
            .length;

        final expiringCount = rows
            .where((r) =>
                PrescriptionExpiryUtils.evaluate(r.expiryDate).status ==
                PrescriptionValidityStatus.expiringSoon)
            .length;

        final validCount = rows
            .where((r) =>
                PrescriptionExpiryUtils.evaluate(r.expiryDate).status ==
                PrescriptionValidityStatus.valid)
            .length;

        return Scaffold(
          body: snapshot.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
              : snapshot.hasError
                  ? Center(
                      child: Text(
                        'Errore caricamento scadenze: ${snapshot.error}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Scadenze ricette',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: <Widget>[
                              _MiniCard(
                                title: 'Scadute',
                                value: '$expiredCount',
                                color: AppColors.red,
                              ),
                              _MiniCard(
                                title: 'In scadenza',
                                value: '$expiringCount',
                                color: AppColors.amber,
                              ),
                              _MiniCard(
                                title: 'Valide',
                                value: '$validCount',
                                color: AppColors.green,
                              ),
                            ],
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
                            child: rows.isEmpty
                                ? const Text(
                                    'Nessuna ricetta presente.',
                                    style: TextStyle(color: Colors.white70),
                                  )
                                : SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      headingRowColor:
                                          const WidgetStatePropertyAll<Color>(
                                        Color(0xFF1A1A1A),
                                      ),
                                      columns: const <DataColumn>[
                                        DataColumn(label: TableHeader('Assistito')),
                                        DataColumn(label: TableHeader('CF')),
                                        DataColumn(label: TableHeader('Farmaci')),
                                        DataColumn(label: TableHeader('Medico')),
                                        DataColumn(label: TableHeader('Data ricetta')),
                                        DataColumn(label: TableHeader('Scadenza')),
                                        DataColumn(label: TableHeader('Stato')),
                                        DataColumn(label: TableHeader('DPC')),
                                      ],
                                      rows: rows.map((row) {
                                        final expiryInfo = PrescriptionExpiryUtils
                                            .evaluate(row.expiryDate);

                                        return DataRow(
                                          cells: <DataCell>[
                                            DataCell(Text(row.patientName, style: _rowStyle)),
                                            DataCell(Text(row.fiscalCode, style: _rowStyle)),
                                            DataCell(Text(row.itemLabel, style: _rowStyle)),
                                            DataCell(Text(row.doctorName, style: _rowStyle)),
                                            DataCell(Text(_formatDate(row.prescriptionDate), style: _rowStyle)),
                                            DataCell(Text(_formatDate(row.expiryDate), style: _rowStyle)),
                                            DataCell(
                                              StatusBadge(
                                                text: expiryInfo.label,
                                                color: expiryInfo.color,
                                              ),
                                            ),
                                            DataCell(
                                              row.dpcFlag
                                                  ? const StatusBadge(
                                                      text: 'DPC',
                                                      color: AppColors.coral,
                                                    )
                                                  : const StatusBadge(
                                                      text: 'NO',
                                                      color: Color(0xFF2A2A2A),
                                                    ),
                                            ),
                                          ],
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

  static String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }
}

class _ExpiryRow {
  final String patientName;
  final String fiscalCode;
  final String doctorName;
  final DateTime prescriptionDate;
  final DateTime? expiryDate;
  final bool dpcFlag;
  final String itemLabel;

  const _ExpiryRow({
    required this.patientName,
    required this.fiscalCode,
    required this.doctorName,
    required this.prescriptionDate,
    required this.expiryDate,
    required this.dpcFlag,
    required this.itemLabel,
  });
}

class _MiniCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _MiniCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 28,
            ),
          ),
        ],
      ),
    );
  }
}

const TextStyle _rowStyle = TextStyle(
  color: Colors.white,
  fontWeight: FontWeight.w600,
);
