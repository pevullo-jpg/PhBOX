import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/app_settings.dart';

class SettingsRepository {
  final FirestoreDatasource datasource;

  const SettingsRepository({required this.datasource});

  Future<AppSettings> getSettings() async {
    final Map<String, dynamic>? map = await datasource.getDocument(
      collectionPath: AppCollections.appSettings,
      documentId: 'main',
    );

    if (map == null) {
      return AppSettings.empty();
    }

    return AppSettings.fromMap(map);
  }

  Future<void> saveSettings(AppSettings settings) {
    return datasource.patchDocument(
      collectionPath: AppCollections.appSettings,
      documentId: 'main',
      data: settings.toFrontendPatchMap(),
    );
  }

  Future<void> patchFields(Map<String, dynamic> fields) {
    return datasource.patchDocument(
      collectionPath: AppCollections.appSettings,
      documentId: 'main',
      data: fields,
    );
  }

  Future<void> recordBackupRun({
    required DateTime at,
    required String status,
  }) {
    return patchFields(<String, dynamic>{
      'backupLastRunAt': at.toIso8601String(),
      'backupLastRunStatus': status,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }
}
