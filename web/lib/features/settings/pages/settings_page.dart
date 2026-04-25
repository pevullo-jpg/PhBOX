import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/services/backup_export_service.dart';
import '../../../data/datasources/firestore_firebase_datasource.dart';
import '../../../data/models/app_settings.dart';
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
import '../../../shared/widgets/settings_field_card.dart';
import '../../../theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final SettingsRepository repository;
  late final BackupExportService _backupExportService;

  final TextEditingController expiryWarningController = TextEditingController();
  final TextEditingController doctorsCatalogController = TextEditingController();

  bool isSaving = false;
  bool isLoading = true;
  bool isExportingBackup = false;
  String message = '';
  bool isErrorMessage = false;

  AppSettings currentSettings = AppSettings.empty();

  @override
  void initState() {
    super.initState();
    final FirestoreFirebaseDatasource datasource =
        FirestoreFirebaseDatasource(FirebaseFirestore.instance);
    repository = SettingsRepository(datasource: datasource);
    _backupExportService = BackupExportService(
      settingsRepository: repository,
      patientsRepository: PatientsRepository(datasource: datasource),
      familyGroupsRepository: FamilyGroupsRepository(datasource: datasource),
      doctorPatientLinksRepository:
          DoctorPatientLinksRepository(datasource: datasource),
      prescriptionsRepository: PrescriptionsRepository(datasource: datasource),
      drivePdfImportsRepository:
          DrivePdfImportsRepository(datasource: datasource),
      debtsRepository: DebtsRepository(datasource: datasource),
      advancesRepository: AdvancesRepository(datasource: datasource),
      bookingsRepository: BookingsRepository(datasource: datasource),
      therapeuticAdviceRepository:
          TherapeuticAdviceRepository(datasource: datasource),
    );
    _load();
  }

  @override
  void dispose() {
    expiryWarningController.dispose();
    doctorsCatalogController.dispose();
    super.dispose();
  }

  bool get _hasUnsavedChanges {
    final String currentExpiry = currentSettings.expiryWarningDays.toString();
    final String typedExpiry = expiryWarningController.text.trim();
    if (typedExpiry != currentExpiry) {
      return true;
    }

    final List<String> typedDoctors = doctorsCatalogController.text
        .split(RegExp(r'[\n,;]+'))
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final List<String> currentDoctors = <String>[
      ...currentSettings.doctorsCatalog,
    ]..sort();
    return typedDoctors.join('|') != currentDoctors.join('|');
  }

  Future<void> _load() async {
    setState(() {
      isLoading = true;
      if (message == 'Impostazioni salvate.' || message.startsWith('Backup creato: ')) {
        message = '';
        isErrorMessage = false;
      }
    });

    try {
      final AppSettings settings = await repository.getSettings();
      if (!mounted) return;
      setState(() {
        currentSettings = settings;
        expiryWarningController.text = settings.expiryWarningDays.toString();
        doctorsCatalogController.text = settings.doctorsCatalog.join('\n');
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
      final int expiryWarningDays =
          int.tryParse(expiryWarningController.text.trim()) ?? 7;
      final List<String> doctorsCatalog = doctorsCatalogController.text
          .split(RegExp(r'[\n,;]+'))
          .map((String item) => item.trim())
          .where((String item) => item.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      final AppSettings updated = currentSettings.copyWith(
        expiryWarningDays: expiryWarningDays,
        doctorsCatalog: doctorsCatalog,
        updatedAt: DateTime.now(),
      );
      await repository.saveSettings(updated);
      if (!mounted) return;
      setState(() {
        currentSettings = updated;
        message = 'Impostazioni salvate.';
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

  Future<void> _exportBackup() async {
    setState(() {
      isExportingBackup = true;
      message = '';
      isErrorMessage = false;
    });

    try {
      final String filename = await _backupExportService.exportCurrentSnapshot();
      if (!mounted) return;
      setState(() {
        message = 'Backup creato: $filename';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        message = 'Errore backup: $e';
        isErrorMessage = true;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isExportingBackup = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (isLoading)
          const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          )
        else
          Scaffold(
            backgroundColor: AppColors.background,
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Impostazioni',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Nel front restano solo i parametri utili alla consultazione operativa.',
                    style: TextStyle(color: Colors.white70, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  SettingsFieldCard(
                    title: 'Scadenze',
                    subtitle:
                        'Numero di giorni di preavviso per evidenziare le ricette in prossimità di scadenza.',
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
                            child:
                                Text(isSaving ? 'Salvataggio...' : 'Salva'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SettingsFieldCard(
                    title: 'Medici disponibili',
                    subtitle:
                        'Elenco usato nel menu a tendina degli anticipi. Un medico per riga oppure separati da virgola.',
                    child: Column(
                      children: <Widget>[
                        TextField(
                          controller: doctorsCatalogController,
                          minLines: 4,
                          maxLines: 8,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Lista medici',
                            alignLabelWithHint: true,
                            labelStyle: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SettingsFieldCard(
                    title: 'Backup',
                    subtitle:
                        'Esporta uno snapshot JSON completo dei dati visibili al frontend.',
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: isExportingBackup ? null : _exportBackup,
                        icon: const Icon(Icons.download_rounded),
                        label: Text(
                          isExportingBackup
                              ? 'Esportazione...'
                              : 'Scarica backup',
                        ),
                      ),
                    ),
                  ),
                  if (message.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    Text(
                      message,
                      style: TextStyle(
                        color:
                            isErrorMessage ? AppColors.red : AppColors.green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        FloatingPageMenu(
          currentIndex: appNavigationIndex.value,
          onSelected: (index) {
            if (appNavigationIndex.value != index) {
              appNavigationIndex.value = index;
            }
          },
        ),
      ],
    );
  }
}
