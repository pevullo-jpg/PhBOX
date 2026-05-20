import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/backend_auth_status.dart';

class BackendAuthStatusRepository {
  final FirestoreDatasource datasource;

  const BackendAuthStatusRepository({required this.datasource});

  Future<BackendAuthStatus> getMainStatus() async {
    final Map<String, dynamic>? map = await datasource.getDocument(
      collectionPath: AppCollections.phboxRuntime,
      documentId: 'main',
    );
    if (map == null) {
      return BackendAuthStatus.emptyOk();
    }
    return BackendAuthStatus.fromRuntimeMap(map);
  }
}
