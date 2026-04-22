import 'dart:async';

import '../../data/models/app_settings.dart';
import '../../data/repositories/settings_repository.dart';
import '../utils/web_client_id_storage.dart';
import 'backup_export_service.dart';
import 'google_auth_prep_service.dart';
import 'google_drive_service.dart';

class BackupSchedulerService {
  BackupSchedulerService._();

  static final BackupSchedulerService instance = BackupSchedulerService._();

  final GoogleAuthPrepService _googleAuthPrepService = GoogleAuthPrepService();

  Timer? _timer;
  BackupExportService? _backupExportService;
  SettingsRepository? _settingsRepository;
  bool _initialized = false;
  bool _isRunning = false;

  void initialize({
    required BackupExportService backupExportService,
    required SettingsRepository settingsRepository,
  }) {
    _backupExportService = backupExportService;
    _settingsRepository = settingsRepository;
    if (_initialized) {
      return;
    }
    _initialized = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      _runTick();
    });
    _runTick();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _initialized = false;
  }

  Future<void> _runTick() async {
    if (_isRunning) {
      return;
    }
    final BackupExportService? exportService = _backupExportService;
    final SettingsRepository? settingsRepository = _settingsRepository;
    if (exportService == null || settingsRepository == null) {
      return;
    }

    _isRunning = true;
    try {
      final AppSettings settings = await settingsRepository.getSettings();
      if (!settings.backupAutoEnabled) {
        return;
      }

      final int intervalMinutes = settings.backupAutoIntervalMinutes < 5
          ? 5
          : settings.backupAutoIntervalMinutes;
      final DateTime now = DateTime.now();
      final DateTime? lastRunAt = settings.backupLastRunAt;
      if (lastRunAt != null &&
          now.difference(lastRunAt) < Duration(minutes: intervalMinutes)) {
        return;
      }

      await settingsRepository.recordBackupRun(
        at: now,
        status: 'running:scheduled',
      );

      final BackupExportDestination destination =
          settings.backupAutoDestination == 'drive'
              ? BackupExportDestination.drive
              : BackupExportDestination.download;

      if (destination == BackupExportDestination.drive) {
        final String clientId = loadSavedGoogleWebClientId().trim();
        if (clientId.isEmpty) {
          throw Exception(
            'Web Client ID Google non configurato nel browser corrente.',
          );
        }
        final String folderId = (settings.backupDriveFolderId ?? '').trim();
        if (folderId.isEmpty) {
          throw Exception('Cartella Drive backup non configurata.');
        }
        final GoogleAuthPrepResult? session =
            await _googleAuthPrepService.ensureDriveSession(
          clientId: clientId,
          interactive: false,
        );
        if (session == null || !session.isConnected) {
          throw Exception('Sessione Drive non disponibile.');
        }
        final GoogleDriveService driveService = GoogleDriveService(
          authHeadersLoader: () => _googleAuthPrepService.getAuthHeaders(
            clientId: clientId,
            interactive: false,
          ),
        );
        await exportService.exportCurrentSnapshot(
          destination: BackupExportDestination.drive,
          googleDriveService: driveService,
          driveFolderId: folderId,
          trigger: 'scheduled',
        );
        return;
      }

      await exportService.exportCurrentSnapshot(
        destination: BackupExportDestination.download,
        trigger: 'scheduled',
      );
    } catch (e) {
      final SettingsRepository? settingsRepository = _settingsRepository;
      if (settingsRepository != null) {
        await settingsRepository.recordBackupRun(
          at: DateTime.now(),
          status: 'error:scheduled:$e',
        );
      }
    } finally {
      _isRunning = false;
    }
  }
}
