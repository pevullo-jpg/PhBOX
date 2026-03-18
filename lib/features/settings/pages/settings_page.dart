import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../data/datasources/firestore_firebase_datasource.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/models/drive_pdf_import.dart';
import '../../../data/repositories/drive_pdf_imports_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../shared/widgets/settings_field_card.dart';
import '../../../theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final SettingsRepository repository;
  late final DrivePdfImportsRepository drivePdfImportsRepository;

  final TextEditingController expiryWarningController = TextEditingController();

  bool isSaving = false;
  bool isLoading = true;
  String message = '';
  bool isErrorMessage = false;

  AppSettings currentSettings = AppSettings.empty();
  List<DrivePdfImport> recentImports = <DrivePdfImport>[];

  @override
  void initState() {
    super.initState();
    final FirestoreFirebaseDatasource datasource =
        FirestoreFirebaseDatasource(FirebaseFirestore.instance);
    repository = SettingsRepository(datasource: datasource);
    drivePdfImportsRepository = DrivePdfImportsRepository(datasource: datasource);
    _load();
  }

  @override
  void dispose() {
    expiryWarningController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      isLoading = true;
      message = '';
    });

    try {
      final AppSettings settings = await repository.getSettings();
      final List<DrivePdfImport> imports = await drivePdfImportsRepository.getAllImports();

      if (!mounted) return;
      setState(() {
        currentSettings = settings;
        expiryWarningController.text = settings.expiryWarningDays.toString();
        recentImports = imports.take(12).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        message = 'Errore caricamento impostazioni: $e';
        isErrorMessage = true;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      isSaving = true;
      message = '';
      isErrorMessage = false;
    });

    try {
      final int expiryWarningDays = int.tryParse(expiryWarningController.text.trim()) ?? 7;
      final AppSettings updated = currentSettings.copyWith(
        expiryWarningDays: expiryWarningDays,
        updatedAt: DateTime.now(),
      );
      await repository.saveSettings(updated);
      if (!mounted) return;
      setState(() {
        currentSettings = updated;
        message = 'Impostazioni front salvate.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        message = 'Errore salvataggio: $e';
        isErrorMessage = true;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Impostazioni front',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'PhBOX non gestisce più login Google, scansione Gmail/Drive o parsing ricette. Queste fasi vivono in PhBOXscript e alimentano Firestore.',
              style: TextStyle(color: Colors.white70, height: 1.5),
            ),
            const SizedBox(height: 20),
            SettingsFieldCard(
              title: 'Front-end',
              child: Column(
                children: <Widget>[
                  TextField(
                    controller: expiryWarningController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Giorni preavviso scadenza',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: isSaving ? null : _save,
                      child: Text(isSaving ? 'Salvataggio...' : 'Salva'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SettingsFieldCard(
              title: 'Contratto backend',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const <Widget>[
                  _InfoRow(label: 'Origine import', value: 'drive_pdf_imports'),
                  _InfoRow(label: 'Anagrafica', value: 'patients'),
                  _InfoRow(label: 'Terapie', value: 'patients/{cf}/therapies'),
                  _InfoRow(label: 'Login Google', value: 'gestito solo da PhBOXscript'),
                  _InfoRow(label: 'Scansione email/drive', value: 'gestita solo da PhBOXscript'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SettingsFieldCard(
              title: 'Import recenti dal backend',
              child: recentImports.isEmpty
                  ? const Text('Nessun import presente.', style: TextStyle(color: Colors.white70))
                  : Column(
                      children: recentImports.map((DrivePdfImport item) {
                        final DateTime? date = item.prescriptionDate;
                        final String dateLabel = date == null
                            ? '-'
                            : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.panelSoft,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(Icons.picture_as_pdf, color: AppColors.coral),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(item.fileName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${item.patientFullName.isEmpty ? 'Assistito non letto' : item.patientFullName} · $dateLabel · ${item.status}',
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
            if (message.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  color: isErrorMessage ? AppColors.red : AppColors.green,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 170,
            child: Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
