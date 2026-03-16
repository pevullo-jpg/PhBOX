import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';
import '../models/parser_reference_value.dart';

class ParserReferenceValuesRepository {
  final FirestoreDatasource datasource;

  const ParserReferenceValuesRepository({required this.datasource});

  Future<void> saveReference(ParserReferenceValue value) {
    return datasource.setDocument(
      collectionPath: AppCollections.parserReferenceValues,
      documentId: value.id,
      data: value.toMap(),
    );
  }

  Future<List<ParserReferenceValue>> getAllReferences() async {
    final List<Map<String, dynamic>> maps = await datasource.getCollection(
      collectionPath: AppCollections.parserReferenceValues,
      orderBy: 'updatedAt',
      descending: true,
    );
    return maps.map(ParserReferenceValue.fromMap).toList();
  }
}
