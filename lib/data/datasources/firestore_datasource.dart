abstract class FirestoreDatasource {
  Future<void> setDocument({
    required String collectionPath,
    required String documentId,
    required Map<String, dynamic> data,
  });

  Future<void> patchDocument({
    required String collectionPath,
    required String documentId,
    required Map<String, dynamic> data,
  });

  Future<Map<String, dynamic>?> getDocument({
    required String collectionPath,
    required String documentId,
  });

  Stream<Map<String, dynamic>?> watchDocument({
    required String collectionPath,
    required String documentId,
  });

  Future<void> incrementDocumentFields({
    required String collectionPath,
    required String documentId,
    required Map<String, num> fields,
    Map<String, dynamic>? extraData,
  });

  Future<List<Map<String, dynamic>>> getCollection({
    required String collectionPath,
    String? orderBy,
    bool descending = false,
    int? limit,
  });

  Future<List<Map<String, dynamic>>> getCollectionWhereEqual({
    required String collectionPath,
    required String field,
    required Object value,
    String? orderBy,
    bool descending = false,
    int? limit,
  });

  Future<List<Map<String, dynamic>>> getCollectionWhereArrayContains({
    required String collectionPath,
    required String field,
    required Object value,
    String? orderBy,
    bool descending = false,
    int? limit,
  });

  Future<List<Map<String, dynamic>>> getCollectionGroup({
    required String collectionPath,
    String? orderBy,
    bool descending = false,
    int? limit,
  });

  Future<void> deleteDocument({
    required String collectionPath,
    required String documentId,
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
    int? limit,
  });

  Future<void> deleteSubDocument({
    required String collectionPath,
    required String documentId,
    required String subcollectionPath,
    required String subDocumentId,
  });
}
