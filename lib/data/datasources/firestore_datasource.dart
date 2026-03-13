abstract class FirestoreDatasource {
  Future<void> setDocument({
    required String collectionPath,
    required String documentId,
    required Map<String, dynamic> data,
  });

  Future<Map<String, dynamic>?> getDocument({
    required String collectionPath,
    required String documentId,
  });

  Future<List<Map<String, dynamic>>> getCollection({
    required String collectionPath,
    String? orderBy,
    bool descending = false,
  });

  Future<void> setSubDocument({
    required String collectionPath,
    required String documentId,
    required String subcollectionPath,
    required String subDocumentId,
    required Map<String, dynamic> data,
  });

  Future<List<Map<String, dynamic>>> getSubCollection({
    required String collectionPath,
    required String documentId,
    required String subcollectionPath,
    String? orderBy,
    bool descending = false,
  });
}
