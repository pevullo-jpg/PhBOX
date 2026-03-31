import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/dashboard_summary.dart';

class DashboardRepository {
  final FirestoreDatasource datasource;

  const DashboardRepository({required this.datasource});

  Future<List<DashboardSummary>> getDashboardSummaries() async {
    final List<Map<String, dynamic>> maps = await datasource.getCollection(
      collectionPath: AppCollections.dashboardSummaries,
      orderBy: 'fullName',
    );
    return maps.map(DashboardSummary.fromMap).toList();
  }
}
