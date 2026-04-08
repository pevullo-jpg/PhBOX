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
}
