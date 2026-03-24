import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/family_group.dart';

class FamiliesRepository {
  final FirestoreDatasource datasource;

  const FamiliesRepository({required this.datasource});

  Future<void> saveFamily(FamilyGroup family) {
    return datasource.setDocument(
      collectionPath: AppCollections.families,
      documentId: family.id,
      data: family.toMap(),
    );
  }

  Future<List<FamilyGroup>> getAllFamilies() async {
    final maps = await datasource.getCollection(
      collectionPath: AppCollections.families,
      orderBy: 'name',
    );
    return maps.map(FamilyGroup.fromMap).toList();
  }

  Future<void> deleteFamily(String id) {
    return datasource.deleteDocument(
      collectionPath: AppCollections.families,
      documentId: id,
    );
  }
}
