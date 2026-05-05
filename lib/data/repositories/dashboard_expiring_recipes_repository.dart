import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/dashboard_expiring_recipes_snapshot.dart';

class DashboardExpiringRecipesRepository {
  final FirestoreDatasource datasource;

  const DashboardExpiringRecipesRepository({required this.datasource});

  Future<DashboardExpiringRecipesSnapshot?> getMainSnapshot() async {
    final Map<String, dynamic>? map = await datasource.getDocument(
      collectionPath: AppCollections.dashboardExpiringRecipes,
      documentId: 'main',
    );
    if (map == null) {
      return null;
    }
    return DashboardExpiringRecipesSnapshot.fromMap(map);
  }
}
