import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../data/datasources/firestore_firebase_datasource.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/models/backup_job.dart';
import '../../../data/repositories/backup_jobs_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../shared/mixins/page_auto_refresh_mixin.dart';
import '../../../shared/navigation/app_navigation.dart';
import '../../../shared/widgets/floating_page_menu.dart';
import '../../../shared/widgets/settings_field_card.dart';
import '../../../theme/app_theme.dart';

enum BackupRequestImportMode {
  merge,
  overwrite,
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with PageAutoRefreshMixin<SettingsPage> {
  late final SettingsRepository repository;
  late final BackupJobsRepository backupJobsRepository;

  final TextEditingController expiryWarningController = TextEditingController();
  final TextEditingController doctorsCatalogController = TextEditingController();
  final TextEditingController backupIntervalController = TextEditingController();
  final TextEditingController backupDriveFolderController =
      TextEditingController();
  final TextEditingController backupImportFileIdController =
      TextEditingController();

  bool isSaving = false;
  bool isLoading = true;
  bool isQueueingExport = false;
  bool isQueueingImport = false;
  String message = '';
  bool isErrorMessage = false;
  bool backupAutoEnabled = false;

  AppSettings currentSettings = AppSettings.empty();
  List<BackupJob> recentBackupJobs = <BackupJob>[];

  @override
  void initState() {
    super.initState();
    final FirestoreFirebaseDatasource datasource =
        FirestoreFirebaseDatasource(FirebaseFirestore.instance);
    repository = SettingsRepository(datasource: datasource);
    backupJobsRepository =
        BackupJobsRepository(firestore: FirebaseFirestore.instance);
    _load();
    startPageAutoRefresh();
  }

  @override
  void dispose() {
    expiryWarningController.dispose();
    doctorsCatalogController.dispose();
    backupIntervalController.dispose();
    backupDriveFolderController.dispose();
    backupImportFileIdController.dispose();
    super.dispose();
  }

  @override
  bool get shouldAutoRefresh =>
      appNavigationIndex.value == 2 && !_hasUnsavedChanges && !_isBusy;

  @override
  void onAutoRefreshTick() {
    _load();
  }

  bool get _isBusy => isSaving || isQueueingExport || isQueueingImport;

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

    final int typedInterval =
        int.tryParse(backupIntervalController.text.trim()) ??
            currentSettings.backupAutoIntervalMinutes;
    if (typedInterval != currentSettings.backupAutoIntervalMinutes) {
      return true;
    }

    if (backupAutoEnabled != currentSettings.backupAutoEnabled) {
      return true;
    }
    if (backupDriveFolderController.text.trim() !=
        (currentSettings.backupDriveFolderId ?? '').trim()) {
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
      final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
        repository.getSettings(),
        backupJobsRepository.getRecentJobs(),
      ]);
      if (!mounted) return;
      final AppSettings settings = results[0] as AppSettings;
      final List<BackupJob> jobs = results[1] as List<BackupJob>;
      setState(() {
        currentSettings = settings;
        recentBackupJobs = jobs;
        expiryWarningController.text = settings.expiryWarningDays.toString();
        doctorsCatalogController.text = settings.doctorsCatalog.join('\n');
        backupIntervalController.text =
            settings.backupAutoIntervalMinutes.toString();
        backupDriveFolderController.text = settings.backupDriveFolderId ?? '';
        backupAutoEnabled = settings.backupAutoEnabled;
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
        backupAutoDestination: 'drive',
        backupDriveFolderId: backupDriveFolderController.text.trim().isEmpty
            ? null
            : backupDriveFolderController.text.trim(),
        clearBackupDriveFolderId:
            backupDriveFolderController.text.trim().isEmpty,
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

  Future<void> _requestBackupExport() async {
    final String folderId = backupDriveFolderController.text.trim();
    if (folderId.isEmpty) {
      setState(() {
        message = 'Inserisci l\'ID della cartella Drive di backup.';
        isErrorMessage = true;
      });
      return;
    }

    setState(() {
      isQueueingExport = true;
      message = '';
      isErrorMessage = false;
    });

    try {
      final String jobId =
          await backupJobsRepository.enqueueExport(targetFolderId: folderId);
      if (!mounted) return;
      setState(() {
        message =
            'Richiesta export accodata. Job: ${_shortJobId(jobId)}. Il backend la eseguirà al prossimo trigger backup.';
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        message = 'Errore richiesta export: $e';
        isErrorMessage = true;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isQueueingExport = false;
      });
    }
  }

  Future<void> _requestBackupImport(BackupRequestImportMode mode) async {
    if (mode == BackupRequestImportMode.overwrite) {
      final bool confirmed = await _confirmOverwriteImport();
      if (!confirmed) {
        return;
      }
    }

    final String folderId = backupDriveFolderController.text.trim();
    final String sourceFileId = backupImportFileIdController.text.trim();
    if (folderId.isEmpty && sourceFileId.isEmpty) {
      setState(() {
        message =
            'Per l\'import indica almeno la cartella backup oppure il file ID JSON.';
        isErrorMessage = true;
      });
      return;
    }

    setState(() {
      isQueueingImport = true;
      message = '';
      isErrorMessage = false;
    });

    try {
      final String jobId = await backupJobsRepository.enqueueImport(
        importMode:
            mode == BackupRequestImportMode.merge ? 'merge' : 'overwrite',
        sourceBackupFileId: sourceFileId,
        targetFolderId: folderId,
      );
      if (!mounted) return;
      setState(() {
        message =
            'Richiesta import accodata. Job: ${_shortJobId(jobId)}. Il backend userà '
            '${sourceFileId.isEmpty ? 'l\'ultimo backup disponibile' : 'il file indicato'}.';
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        message = 'Errore richiesta import: $e';
        isErrorMessage = true;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isQueueingImport = false;
      });
    }
  }

  Future<bool> _confirmOverwriteImport() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.panel,
          title: const Text(
            'Accodare import in sovrascrittura?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Il backend eliminerà i documenti attuali non presenti nel backup selezionato.',
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
              child: const Text('Accoda'),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  String _formatDateTime(DateTime value) {
    final String d = value.day.toString().padLeft(2, '0');
    final String m = value.month.toString().padLeft(2, '0');
    final String y = value.year.toString().padLeft(4, '0');
    final String hh = value.hour.toString().padLeft(2, '0');
    final String mm = value.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }

  String _shortJobId(String value) {
    final String normalized = value.trim();
    if (normalized.length <= 8) {
      return normalized;
    }
    return normalized.substring(0, 8);
  }

  String get _backupStatusLabel {
    final DateTime? lastRunAt = currentSettings.backupLastRunAt;
    final String status = (currentSettings.backupLastRunStatus ?? '').trim();
    if (lastRunAt == null && status.isEmpty) {
      return 'Nessun esito backend registrato.';
    }
    final String when = lastRunAt == null ? '-' : _formatDateTime(lastRunAt);
    final String label = status.isEmpty ? '-' : status;
    return 'Ultimo esito backend: $when • $label';
  }

  Color _jobStatusColor(BackupJob job) {
    if (job.isFailed) {
      return AppColors.red;
    }
    if (job.isCompleted) {
      return AppColors.green;
    }
    if (job.isRunning) {
      return AppColors.amber;
    }
    return AppColors.yellow;
  }

  String _jobTitle(BackupJob job) {
    if (job.normalizedJobType == 'import') {
      final String mode = job.importMode.trim().toLowerCase();
      if (mode == 'overwrite') {
        return 'Import sovrascrittura';
      }
      return 'Import integrazione';
    }
    return 'Export backup';
  }

  String _jobSubtitle(BackupJob job) {
    final List<String> parts = <String>[
      'Stato: ${job.status.trim().isEmpty ? 'pending' : job.status.trim()}',
      'Richiesto: ${_formatDateTime(job.requestedAt)}',
    ];
    if (job.targetFolderId.trim().isNotEmpty) {
      parts.add('Cartella: ${job.targetFolderId.trim()}');
    }
    if (job.sourceBackupFileId.trim().isNotEmpty) {
      parts.add('JSON: ${job.sourceBackupFileId.trim()}');
    }
    if (job.resultMessage.trim().isNotEmpty) {
      parts.add(job.resultMessage.trim());
    } else if (job.errorMessage.trim().isNotEmpty) {
      parts.add(job.errorMessage.trim());
    }
    return parts.join(' • ');
  }

  Widget _buildRecentJobsSection() {
    return SettingsFieldCard(
      title: 'Coda backup backend',
      subtitle:
          'Richieste manuali ed esiti recenti letti da Firestore. Il backend consumerà i job pendenti con trigger separato.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _backupStatusLabel,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (recentBackupJobs.isEmpty)
            const Text(
              'Nessun job backup presente.',
              style: TextStyle(color: Colors.white70),
            )
          else
            Column(
              children: recentBackupJobs.map((BackupJob job) {
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.panelSoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _jobStatusColor(job), width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              _jobTitle(job),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _jobStatusColor(job),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              job.status.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _jobSubtitle(job),
                        style: const TextStyle(color: Colors.white70, height: 1.4),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
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
                    'Il front non accede più a Drive per il backup. Qui configuri solo i parametri e accodi i job che il backend eseguirà con trigger separato.',
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
                        'Accoda un export backend. Il backend genererà JSON completo e PDF riepilogativi nella cartella Drive configurata.',
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: <Widget>[
                        FilledButton.icon(
                          onPressed: isQueueingExport ? null : _requestBackupExport,
                          icon: const Icon(Icons.archive_rounded),
                          label: Text(
                            isQueueingExport
                                ? 'Accodamento...'
                                : 'Richiedi export ora',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SettingsFieldCard(
                    title: 'Import backup',
                    subtitle:
                        'Il front non carica file. Accoda un import backend in integrazione o sovrascrittura. Se il file ID è vuoto, il backend userà l\'ultimo backup disponibile nella cartella configurata.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        TextField(
                          controller: backupImportFileIdController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'File ID JSON da importare (opzionale)',
                            helperText:
                                'Lascia vuoto per usare l\'ultimo backup disponibile nella cartella backup.',
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
                              onPressed: isQueueingImport
                                  ? null
                                  : () => _requestBackupImport(
                                        BackupRequestImportMode.merge,
                                      ),
                              icon: const Icon(Icons.merge_rounded),
                              label: Text(
                                isQueueingImport
                                    ? 'Accodamento...'
                                    : 'Richiedi integrazione',
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: isQueueingImport
                                  ? null
                                  : () => _requestBackupImport(
                                        BackupRequestImportMode.overwrite,
                                      ),
                              icon: const Icon(Icons.warning_amber_rounded),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.red,
                              ),
                              label: const Text('Richiedi sovrascrittura'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SettingsFieldCard(
                    title: 'Automazione backup backend',
                    subtitle:
                        'Questi parametri verranno letti dal backend dedicato. Nessun terminale frontend deve restare aperto.',
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
                            'Il backend userà questa impostazione per il trigger separato backup.',
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
                        TextField(
                          controller: backupDriveFolderController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'ID cartella Drive backup',
                            helperText:
                                'Cartella dedicata letta dal backend per export automatici e import dell\'ultimo backup.',
                            labelStyle: TextStyle(color: Colors.white70),
                            helperStyle: TextStyle(color: Colors.white54),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: isSaving ? null : _save,
                            child: Text(
                              isSaving ? 'Salvataggio...' : 'Salva pianificazione',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildRecentJobsSection(),
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
          onSelected: (int index) {
            if (appNavigationIndex.value != index) {
              appNavigationIndex.value = index;
            }
          },
        ),
      ],
    );
  }
}
