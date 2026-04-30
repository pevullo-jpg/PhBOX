import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/patient_dashboard_index.dart';

class PatientDashboardIndexRepository {
  final FirestoreDatasource datasource;

  const PatientDashboardIndexRepository({required this.datasource});

  static const int defaultLimit = 120;

  Future<List<PatientDashboardIndex>> getByFlag({
    required PatientDashboardIndexFlag flag,
    int limit = defaultLimit,
  }) async {
    final List<Map<String, dynamic>> maps = await datasource.getCollectionWhereEqual(
      collectionPath: AppCollections.patientDashboardIndex,
      field: flag.fieldName,
      value: true,
      limit: limit,
    );
    final List<PatientDashboardIndex> items = maps.map(PatientDashboardIndex.fromMap).toList();
    _sort(items);
    return items;
  }

  Future<List<PatientDashboardIndex>> searchByPrefix(String query, {int limit = defaultLimit}) async {
    final String normalized = normalizeSearchPrefix(query);
    if (normalized.length < 3) {
      return const <PatientDashboardIndex>[];
    }
    final List<Map<String, dynamic>> maps = await datasource.getCollectionWhereArrayContains(
      collectionPath: AppCollections.patientDashboardIndex,
      field: 'searchPrefixes',
      value: normalized,
      limit: limit,
    );
    final List<PatientDashboardIndex> items = maps.map(PatientDashboardIndex.fromMap).toList();
    _sort(items);
    return items;
  }

  Future<List<PatientDashboardIndex>> getByFamilyIds(
    Iterable<String> familyIds, {
    int maxFamilyIds = 5,
    int limitPerFamily = 10,
  }) async {
    final List<String> normalizedFamilyIds = familyIds
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final List<String> selectedFamilyIds = normalizedFamilyIds.take(maxFamilyIds).toList();
    if (selectedFamilyIds.isEmpty) {
      return const <PatientDashboardIndex>[];
    }
    final List<PatientDashboardIndex> out = <PatientDashboardIndex>[];
    final Set<String> seenFiscalCodes = <String>{};
    for (final String familyId in selectedFamilyIds) {
      final List<Map<String, dynamic>> maps = await datasource.getCollectionWhereEqual(
        collectionPath: AppCollections.patientDashboardIndex,
        field: 'familyId',
        value: familyId,
        limit: limitPerFamily,
      );
      for (final Map<String, dynamic> map in maps) {
        final PatientDashboardIndex item = PatientDashboardIndex.fromMap(map);
        final String cf = item.fiscalCode.trim().toUpperCase();
        if (cf.isEmpty || !seenFiscalCodes.add(cf)) {
          continue;
        }
        out.add(item);
      }
    }
    _sort(out);
    return out;
  }

  Future<List<PatientDashboardIndex>> getAll({int limit = 500}) async {
    final List<Map<String, dynamic>> maps = await datasource.getCollection(
      collectionPath: AppCollections.patientDashboardIndex,
      limit: limit,
    );
    final List<PatientDashboardIndex> items = maps.map(PatientDashboardIndex.fromMap).toList();
    _sort(items);
    return items;
  }

  Future<PatientDashboardIndex?> getByFiscalCode(String fiscalCode) async {
    final String cf = fiscalCode.trim().toUpperCase();
    if (cf.isEmpty) return null;
    final Map<String, dynamic>? map = await datasource.getDocument(
      collectionPath: AppCollections.patientDashboardIndex,
      documentId: cf,
    );
    if (map == null) return null;
    return PatientDashboardIndex.fromMap(map);
  }

  Future<void> patchFrontendManagedState({
    required String fiscalCode,
    required String fullName,
    String? alias,
    String? doctorFullName,
    String? city,
    String? exemptionCode,
    int? debtCount,
    double? debtAmount,
    int? advanceCount,
    int? bookingCount,
  }) {
    final String cf = fiscalCode.trim().toUpperCase();
    if (cf.isEmpty) {
      return Future<void>.value();
    }
    final DateTime now = DateTime.now();
    final Map<String, dynamic> data = <String, dynamic>{
      'fiscalCode': cf,
      'fullName': fullName.trim().isEmpty ? cf : fullName.trim(),
      if (alias != null) 'alias': alias.trim().isEmpty ? null : alias.trim(),
      if (doctorFullName != null) 'doctorFullName': doctorFullName.trim(),
      if (city != null) 'city': city.trim(),
      if (exemptionCode != null) 'exemptionCode': exemptionCode.trim(),
      if (debtCount != null) 'debtCount': debtCount < 0 ? 0 : debtCount,
      if (debtAmount != null) 'debtAmount': debtAmount,
      if (debtCount != null || debtAmount != null)
        'hasDebt': (debtCount ?? 0) > 0 || (debtAmount ?? 0).abs() > 0.005,
      if (advanceCount != null) 'advanceCount': advanceCount < 0 ? 0 : advanceCount,
      if (advanceCount != null) 'hasAdvance': advanceCount > 0,
      if (bookingCount != null) 'bookingCount': bookingCount < 0 ? 0 : bookingCount,
      if (bookingCount != null) 'hasBooking': bookingCount > 0,
      'searchPrefixes': buildSearchPrefixes(<String>[
        cf,
        fullName,
        alias ?? '',
        doctorFullName ?? '',
        city ?? '',
        exemptionCode ?? '',
      ]),
      'updatedAt': now.toIso8601String(),
    };
    return datasource.patchDocument(
      collectionPath: AppCollections.patientDashboardIndex,
      documentId: cf,
      data: data,
    );
  }

  Future<void> deleteIndex(String fiscalCode) {
    final String cf = fiscalCode.trim().toUpperCase();
    if (cf.isEmpty) return Future<void>.value();
    return datasource.deleteDocument(
      collectionPath: AppCollections.patientDashboardIndex,
      documentId: cf,
    );
  }

  static String normalizeSearchPrefix(String value) {
    return value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static List<String> buildSearchPrefixes(Iterable<String> rawValues) {
    final Set<String> out = <String>{};
    for (final String raw in rawValues) {
      final String normalized = normalizeSearchPrefix(raw);
      if (normalized.length >= 3) {
        for (int i = 3; i <= normalized.length && i <= 24; i++) {
          out.add(normalized.substring(0, i));
        }
      }
      for (final String part in normalized.split(' ')) {
        if (part.length >= 3) {
          for (int i = 3; i <= part.length && i <= 24; i++) {
            out.add(part.substring(0, i));
          }
        }
      }
    }
    final List<String> result = out.toList()..sort();
    return result.length > 120 ? result.sublist(0, 120) : result;
  }

  static void _sort(List<PatientDashboardIndex> items) {
    items.sort((PatientDashboardIndex a, PatientDashboardIndex b) {
      if (a.hasExpiry != b.hasExpiry) return a.hasExpiry ? -1 : 1;
      return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
    });
  }
}

enum PatientDashboardIndexFlag {
  recipes('hasRecipes'),
  dpc('hasDpc'),
  debt('hasDebt'),
  advance('hasAdvance'),
  booking('hasBooking'),
  expiry('hasExpiry');

  const PatientDashboardIndexFlag(this.fieldName);
  final String fieldName;
}
