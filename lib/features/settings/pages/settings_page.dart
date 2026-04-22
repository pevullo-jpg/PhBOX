import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/services/backup_export_service.dart';
import '../../../core/services/backup_import_service.dart';
import '../../../core/services/google_auth_prep_service.dart';
import '../../../core/services/google_drive_service.dart';
import '../../../core/utils/web_client_id_storage.dart';
import '../../../data/datasources/firestore_firebase_datasource.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/repositories/advances_repository.dart';
import '../../../data/repositories/bookings_repository.dart';
import '../../../data/repositories/debts_repository.dart';
import '../../../data/repositories/patients_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../shared/mixins/page_auto_refresh_mixin.dart';
import '../../../shared/navigation/app_navigation.dart';
import '../../../shared/widgets/floating_page_menu.dart';
import '../../../shared/widgets/settings_field_card.dart';
import '../../../theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with PageAutoRefreshMixin<SettingsPage> {
  late final SettingsRepository repository;
  late final BackupExportService _backupExportService;
  late final BackupImportService _backupImportService;
  final GoogleAuthPrepService _googleAuthPrepService = GoogleAuthPrepService();

  final TextEditingController expiryWarningController = TextEditingController();
  final TextEditingController doctorsCatalogController = TextEditingController();
  final TextEditingController backupIntervalController = TextEditingController();
  final TextEditingController backupDriveFolderController =
      TextEditingController();
  final TextEditingController googleClientIdController =
      TextEditingController();

  bool isSaving = false;
  bool isLoading = true;
  bool isExportingBackup = false;
  bool isImportingBackup = false;
  bool isAuthorizingDrive = false;
  String message = '';
  bool isErrorMessage = false;
  bool backupAutoEnabled = false;
  String backupAutoDestination = 'download';
  String _savedGoogleClientId = '';

  AppSettings currentSettings = AppSettings.empty();

  @override
  void initState() {
    super.initState();
    final FirestoreFirebaseDatasource datasource =
        FirestoreFirebaseDatasource(FirebaseFirestore.instance);
    repository = SettingsRepository(datasource: datasource);
    _backupExportService = BackupExportService(
      firestore: FirebaseFirestore.instance,
      settingsRepository: repository,
      patientsRepository: PatientsRepository(datasource: datasource),
      debtsRepository: DebtsRepository(datasource: datasource),
      advancesRepository: AdvancesRepository(datasource: datasource),
      bookingsRepository: BookingsRepository(datasource: datasource),
    );
    _backupImportService =
        BackupImportService(firestore: FirebaseFirestore.instance);
    _savedGoogleClientId = loadSavedGoogleWebClientId();
    googleClientIdController.text = _savedGoogleClientId;
    _load();
    startPageAutoRefresh();
  }

  @override
  void dispose() {
    expiryWarningController.dispose();
    doctorsCatalogController.dispose();
    backupIntervalController.dispose();
    backupDriveFolderController.dispose();
    googleClientIdController.dispose();
    super.dispose();
  }

  @override
  bool get shouldAutoRefresh =>
      appNavigationIndex.value == 2 && !_hasUnsavedChanges && !_isBusy;

  @override
  void onAutoRefreshTick() {
    _load();
  }

  bool get _isBusy =>
      isSaving || isExportingBackup || isImportingBackup || isAuthorizingDrive;

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
    if (typedDoctors.join('|') != currentDoctors.join('|')) {
      return true;
    }

    final int typedInterval = int.tryParse(backupIntervalController.text.trim()) ??
        currentSettings.backupAutoIntervalMinutes;
    if (typedInterval != currentSettings.backupAutoIntervalMinutes) {
      return true;
    }

    if (backupAutoEnabled != currentSettings.backupAutoEnabled) {
      return true;
    }
    if (backupAutoDestination != currentSettings.backupAutoDestination) {
      return true;
    }
    if (backupDriveFolderController.text.trim() !=
        (currentSettings.backupDriveFolderId ?? '').trim()) {
      return true;
    }
    if (googleClientIdController.text.trim() != _savedGoogleClientId.trim()) {
      return true;
    }

    return false;
  }

  Future<void> _load() async {
    setState(() {
      isLoading = true;
      if (message == 'Impostazioni salvate.') {
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
        backupIntervalController.text =
            settings.backupAutoIntervalMinutes.toString();
        backupDriveFolderController.text = settings.backupDriveFolderId ?? '';
        backupAutoEnabled = settings.backupAutoEnabled;
        backupAutoDestination =
            settings.backupAutoDestination == 'drive' ? 'drive' : 'download';
        _savedGoogleClientId = loadSavedGoogleWebClientId();
        if (googleClientIdController.text.trim().isEmpty || !_hasUnsavedChanges) {
          googleClientIdController.text = _savedGoogleClientId;
        }
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
      final int backupIntervalMinutes =
          int.tryParse(backupIntervalController.text.trim()) ?? 720;
      final AppSettings updated = currentSettings.copyWith(
        expiryWarningDays: expiryWarningDays,
        doctorsCatalog: doctorsCatalog,
        backupAutoEnabled: backupAutoEnabled,
        backupAutoIntervalMinutes:
            backupIntervalMinutes < 5 ? 5 : backupIntervalMinutes,
        backupAutoDestination: backupAutoDestination,
        backupDriveFolderId: backupDriveFolderController.text.trim().isEmpty
            ? null
            : backupDriveFolderController.text.trim(),
        clearBackupDriveFolderId:
            backupDriveFolderController.text.trim().isEmpty,
        updatedAt: DateTime.now(),
      );
      await repository.saveSettings(updated);
      await saveGoogleWebClientId(googleClientIdController.text.trim());
      if (!mounted) return;
      setState(() {
        currentSettings = updated;
        _savedGoogleClientId = googleClientIdController.text.trim();
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

  Future<void> _exportBackupDownload() async {
    setState(() {
      isExportingBackup = true;
      message = '';
      isErrorMessage = false;
    });

    try {
      final BackupExportResult result =
          await _backupExportService.exportCurrentSnapshot(
        destination: BackupExportDestination.download,
        trigger: 'manual',
      );
      if (!mounted) return;
      setState(() {
        message =
            'Backup completato: ${result.jsonFilename} + ${result.reportPdfFilename}';
      });
      await _load();
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

  Future<void> _exportBackupDrive() async {
    setState(() {
      isExportingBackup = true;
      message = '';
      isErrorMessage = false;
    });

    try {
      final String clientId = googleClientIdController.text.trim();
      final String folderId = backupDriveFolderController.text.trim();
      if (clientId.isEmpty) {
        throw Exception('Inserisci il Web Client ID Google.');
      }
      if (folderId.isEmpty) {
        throw Exception('Inserisci l\'ID della cartella Drive di backup.');
      }
      await saveGoogleWebClientId(clientId);
      final GoogleAuthPrepResult? session =
          await _googleAuthPrepService.ensureDriveSession(
        clientId: clientId,
        interactive: true,
      );
      if (session == null || !session.isConnected) {
        throw Exception('Connessione Drive non disponibile.');
      }
      final GoogleDriveService driveService = GoogleDriveService(
        authHeadersLoader: () => _googleAuthPrepService.getAuthHeaders(
          clientId: clientId,
          interactive: false,
        ),
      );
      final BackupExportResult result =
          await _backupExportService.exportCurrentSnapshot(
        destination: BackupExportDestination.drive,
        googleDriveService: driveService,
        driveFolderId: folderId,
        trigger: 'manual',
      );
      if (!mounted) return;
      setState(() {
        _savedGoogleClientId = clientId;
        message =
            'Backup completato: ${result.jsonFilename} + ${result.reportPdfFilename} su Drive';
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        message = 'Errore backup Drive: $e';
        isErrorMessage = true;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isExportingBackup = false;
      });
    }
  }

  Future<void> _importBackup(BackupImportMode mode) async {
    if (mode == BackupImportMode.overwrite) {
      final bool confirmed = await _confirmOverwriteImport();
      if (!confirmed) {
        return;
      }
    }

    setState(() {
      isImportingBackup = true;
      message = '';
      isErrorMessage = false;
    });

    try {
      final Uint8List bytes = await _pickJsonBackupBytes();
      final BackupImportResult result = await _backupImportService.importJsonBytes(
        bytes: bytes,
        mode: mode,
      );
      if (!mounted) return;
      setState(() {
        message =
            'Import completato: ${result.writtenDocuments} scritture, ${result.deletedDocuments} eliminazioni.';
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        message = 'Errore import: $e';
        isErrorMessage = true;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isImportingBackup = false;
      });
    }
  }

  Future<Uint8List> _pickJsonBackupBytes() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const <String>['json'],
    );
    if (result == null || result.files.isEmpty) {
      throw Exception('Import annullato.');
    }
    final PlatformFile file = result.files.single;
    final Uint8List? bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw Exception('File JSON vuoto o non leggibile.');
    }
    return bytes;
  }

  Future<bool> _confirmOverwriteImport() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.panel,
          title: const Text(
            'Sovrascrivere il database?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'La modalità sovrascrittura rimuove i documenti attuali non presenti nel backup importato.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.red),
              child: const Text('Sovrascrivi'),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  Future<void> _authorizeDriveSession() async {
    setState(() {
      isAuthorizingDrive = true;
      message = '';
      isErrorMessage = false;
    });

    try {
      final String clientId = googleClientIdController.text.trim();
      if (clientId.isEmpty) {
        throw Exception('Inserisci il Web Client ID Google.');
      }
      await saveGoogleWebClientId(clientId);
      final GoogleAuthPrepResult? session =
          await _googleAuthPrepService.ensureDriveSession(
        clientId: clientId,
        interactive: true,
      );
      if (session == null || !session.isConnected) {
        throw Exception('Autorizzazione Drive non completata.');
      }
      if (!mounted) return;
      setState(() {
        _savedGoogleClientId = clientId;
        message = 'Sessione Drive pronta.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        message = 'Errore autorizzazione Drive: $e';
        isErrorMessage = true;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isAuthorizingDrive = false;
      });
    }
  }

  String _formatDateTime(DateTime value) {
    final String d = value.day.toString().padLeft(2, '0');
    final String m = value.month.toString().padLeft(2, '0');
    final String y = value.year.toString().padLeft(4, '0');
    final String hh = value.hour.toString().padLeft(2, '0');
    final String mm = value.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }

  String get _backupStatusLabel {
    final DateTime? lastRunAt = currentSettings.backupLastRunAt;
    final String status = (currentSettings.backupLastRunStatus ?? '').trim();
    if (lastRunAt == null && status.isEmpty) {
      return 'Nessun backup registrato.';
    }
    final String when = lastRunAt == null ? '-' : _formatDateTime(lastRunAt);
    final String label = status.isEmpty ? '-' : status;
    return 'Ultimo esito: $when • $label';
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
                    'Nel front restano solo i parametri utili alla consultazione operativa e al salvataggio amministrativo.',
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
                            child: Text(isSaving ? 'Salvataggio...' : 'Salva'),
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
                    title: 'Backup manuale',
                    subtitle:
                        'Esporta JSON completo e PDF riepilogativo di debiti, prenotazioni e anticipi.',
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: <Widget>[
                        FilledButton.icon(
                          onPressed:
                              isExportingBackup ? null : _exportBackupDownload,
                          icon: const Icon(Icons.download_rounded),
                          label: Text(
                            isExportingBackup ? 'Esportazione...' : 'Scarica backup',
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: isExportingBackup ? null : _exportBackupDrive,
                          icon: const Icon(Icons.cloud_upload_rounded),
                          label: const Text('Invia su Drive'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SettingsFieldCard(
                    title: 'Import backup',
                    subtitle:
                        'Importa un backup JSON completo. Integrazione mantiene i dati extra già presenti. Sovrascrittura elimina i documenti non inclusi nel backup.',
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: <Widget>[
                        FilledButton.icon(
                          onPressed: isImportingBackup
                              ? null
                              : () => _importBackup(BackupImportMode.merge),
                          icon: const Icon(Icons.merge_rounded),
                          label: Text(
                            isImportingBackup ? 'Import...' : 'Importa integrazione',
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: isImportingBackup
                              ? null
                              : () => _importBackup(BackupImportMode.overwrite),
                          icon: const Icon(Icons.warning_amber_rounded),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.red,
                          ),
                          label: const Text('Importa sovrascrittura'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SettingsFieldCard(
                    title: 'Automazione backup',
                    subtitle:
                        'Pianificazione frontend. Funziona mentre l\'app resta aperta. In download usa la cartella predefinita del browser; in Drive carica i file nella cartella indicata.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SwitchListTile.adaptive(
                          value: backupAutoEnabled,
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppColors.yellow,
                          title: const Text(
                            'Backup automatico attivo',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: const Text(
                            'Il controllo parte ogni minuto e l\'export scatta solo alla scadenza prevista.',
                            style: TextStyle(color: Colors.white70),
                          ),
                          onChanged: _isBusy
                              ? null
                              : (bool value) {
                                  setState(() {
                                    backupAutoEnabled = value;
                                  });
                                },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: backupIntervalController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Intervallo minuti',
                            helperText: 'Minimo consigliato: 5 minuti',
                            labelStyle: TextStyle(color: Colors.white70),
                            helperStyle: TextStyle(color: Colors.white54),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: backupAutoDestination,
                          dropdownColor: AppColors.panelSoft,
                          decoration: const InputDecoration(
                            labelText: 'Destinazione automatica',
                            labelStyle: TextStyle(color: Colors.white70),
                          ),
                          style: const TextStyle(color: Colors.white),
                          items: const <DropdownMenuItem<String>>[
                            DropdownMenuItem<String>(
                              value: 'download',
                              child: Text('Download browser'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'drive',
                              child: Text('Google Drive'),
                            ),
                          ],
                          onChanged: _isBusy
                              ? null
                              : (String? value) {
                                  if (value == null) return;
                                  setState(() {
                                    backupAutoDestination = value;
                                  });
                                },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: backupDriveFolderController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'ID cartella Drive backup',
                            helperText:
                                'Richiesto solo se scegli Google Drive come destinazione automatica o manuale.',
                            labelStyle: TextStyle(color: Colors.white70),
                            helperStyle: TextStyle(color: Colors.white54),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: googleClientIdController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Google Web Client ID (browser corrente)',
                            helperText:
                                'Serve per l\'upload automatico/manuale su Drive da questo terminale.',
                            labelStyle: TextStyle(color: Colors.white70),
                            helperStyle: TextStyle(color: Colors.white54),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: <Widget>[
                            FilledButton.icon(
                              onPressed:
                                  isAuthorizingDrive ? null : _authorizeDriveSession,
                              icon: const Icon(Icons.verified_user_rounded),
                              label: Text(
                                isAuthorizingDrive
                                    ? 'Autorizzazione...'
                                    : 'Autorizza Drive',
                              ),
                            ),
                            FilledButton(
                              onPressed: isSaving ? null : _save,
                              child: Text(isSaving ? 'Salvataggio...' : 'Salva pianificazione'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _backupStatusLabel,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
