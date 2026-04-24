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

  Stream<DashboardTotalsSnapshot?> watchMainTotals() {
    return datasource
        .watchDocument(
          collectionPath: AppCollections.dashboardTotals,
          documentId: 'main',
        )
        .map((Map<String, dynamic>? map) {
      if (map == null) {
        return null;
      }
      return DashboardTotalsSnapshot.fromMap(map);
    });
  }

  Future<void> patchFrontendComputedTotals({
    required int recipeCount,
    required int dpcCount,
    required double debtAmount,
    required int advanceCount,
    required int bookingCount,
    required int expiringCount,
  }) {
    final String now = DateTime.now().toIso8601String();
    return datasource.patchDocument(
      collectionPath: AppCollections.dashboardTotals,
      documentId: 'main',
      data: <String, dynamic>{
        'recipeCount': recipeCount,
        'dpcCount': dpcCount,
        'debtAmount': debtAmount,
        'advanceCount': advanceCount,
        'bookingCount': bookingCount,
        'expiringCount': expiringCount,
        'updatedAt': now,
        'frontendComputedTotalsUpdatedAt': now,
        'frontendComputedTotalsSource': 'frontend_full_refresh',
      },
    );
  }

  Future<void> applyFrontendManagedDelta({
    double debtAmountDelta = 0,
    int advanceCountDelta = 0,
    int bookingCountDelta = 0,
  }) {
    final Map<String, num> fields = <String, num>{};
    if (debtAmountDelta != 0) {
      fields['debtAmount'] = debtAmountDelta;
    }
    if (advanceCountDelta != 0) {
      fields['advanceCount'] = advanceCountDelta;
    }
    if (bookingCountDelta != 0) {
      fields['bookingCount'] = bookingCountDelta;
    }
    if (fields.isEmpty) {
      return Future<void>.value();
    }
    final String now = DateTime.now().toIso8601String();
    return datasource.incrementDocumentFields(
      collectionPath: AppCollections.dashboardTotals,
      documentId: 'main',
      fields: fields,
      extraData: <String, dynamic>{
        'updatedAt': now,
        'frontendManagedTotalsUpdatedAt': now,
        'frontendManagedTotalsSource': 'frontend_delta',
      },
    );
  }
}
