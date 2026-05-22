import '../datasources/firestore_datasource.dart';
import 'tenant_path_resolver.dart';

class TenantScopedFirestoreDatasource implements FirestoreDatasource {
  final FirestoreDatasource delegate;
  final TenantPathResolver resolver;

  const TenantScopedFirestoreDatasource({
    required this.delegate,
    required this.resolver,
  });

  String _collectionPath(String collectionPath) {
    return resolver.collection(collectionPath);
  }

  @override
  Future<void> setDocument({
    required String collectionPath,
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    return delegate.setDocument(
      collectionPath: _collectionPath(collectionPath),
      documentId: documentId,
      data: data,
    );
  }

  @override
  Future<void> patchDocument({
    required String collectionPath,
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    return delegate.patchDocument(
      collectionPath: _collectionPath(collectionPath),
      documentId: documentId,
      data: data,
    );
  }

  @override
  Future<Map<String, dynamic>?> getDocument({
    required String collectionPath,
    required String documentId,
  }) {
    return delegate.getDocument(
      collectionPath: _collectionPath(collectionPath),
      documentId: documentId,
    );
  }

  @override
  Stream<Map<String, dynamic>?> watchDocument({
    required String collectionPath,
    required String documentId,
  }) {
    return delegate.watchDocument(
      collectionPath: _collectionPath(collectionPath),
      documentId: documentId,
    );
  }

  @override
  Future<void> incrementDocumentFields({
    required String collectionPath,
    required String documentId,
    required Map<String, num> fields,
    Map<String, dynamic>? extraData,
  }) {
    return delegate.incrementDocumentFields(
      collectionPath: _collectionPath(collectionPath),
      documentId: documentId,
      fields: fields,
      extraData: extraData,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getCollection({
    required String collectionPath,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) {
    return delegate.getCollection(
      collectionPath: _collectionPath(collectionPath),
      orderBy: orderBy,
      descending: descending,
      limit: limit,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getCollectionWhereEqual({
    required String collectionPath,
    required String field,
    required Object value,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) {
    return delegate.getCollectionWhereEqual(
      collectionPath: _collectionPath(collectionPath),
      field: field,
      value: value,
      orderBy: orderBy,
      descending: descending,
      limit: limit,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getCollectionWhereArrayContains({
    required String collectionPath,
    required String field,
    required Object value,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) {
    return delegate.getCollectionWhereArrayContains(
      collectionPath: _collectionPath(collectionPath),
      field: field,
      value: value,
      orderBy: orderBy,
      descending: descending,
      limit: limit,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getCollectionGroup({
    required String collectionPath,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) {
    return delegate.getCollectionGroup(
      collectionPath: collectionPath,
      orderBy: orderBy,
      descending: descending,
      limit: limit,
    );
  }

  @override
  Future<void> deleteDocument({
    required String collectionPath,
    required String documentId,
  }) {
    return delegate.deleteDocument(
      collectionPath: _collectionPath(collectionPath),
      documentId: documentId,
    );
  }

  @override
  Future<void> setSubDocument({
    required String collectionPath,
    required String documentId,
    required String subcollectionPath,
    required String subDocumentId,
    required Map<String, dynamic> data,
  }) {
    return delegate.setSubDocument(
      collectionPath: _collectionPath(collectionPath),
      documentId: documentId,
      subcollectionPath: subcollectionPath,
      subDocumentId: subDocumentId,
      data: data,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getSubCollection({
    required String collectionPath,
    required String documentId,
    required String subcollectionPath,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) {
    return delegate.getSubCollection(
      collectionPath: _collectionPath(collectionPath),
      documentId: documentId,
      subcollectionPath: subcollectionPath,
      orderBy: orderBy,
      descending: descending,
      limit: limit,
    );
  }

  @override
  Future<void> deleteSubDocument({
    required String collectionPath,
    required String documentId,
    required String subcollectionPath,
    required String subDocumentId,
  }) {
    return delegate.deleteSubDocument(
      collectionPath: _collectionPath(collectionPath),
      documentId: documentId,
      subcollectionPath: subcollectionPath,
      subDocumentId: subDocumentId,
    );
  }
}
