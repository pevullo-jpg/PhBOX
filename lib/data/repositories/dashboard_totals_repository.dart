import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/dashboard_totals_snapshot.dart';

class DashboardTotalsRepository {
  final FirestoreDatasource datasource;

  const DashboardTotalsRepository({required this.datasource});

  Future<DashboardTotalsSnapshot?> getMainTotals() async {
    final Map<String, dynamic>? map = await datasource.getDocument(
      collectionPath: AppCollections.dashboardTotals,
      documentId: 'main',
    );
    if (map == null) {
      return null;
    }
    return DashboardTotalsSnapshot.fromMap(map);
  }
}
