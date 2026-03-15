import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/app_settings.dart';

class SettingsRepository {

  final FirestoreDatasource datasource;

  const SettingsRepository({required this.datasource});

  Future<void> saveSettings(AppSettings settings) {
    return datasource.setDocument(
      collectionPath: AppCollections.appSettings,
      documentId: 'main',
      data: settings.toMap(),
    );
  }
}