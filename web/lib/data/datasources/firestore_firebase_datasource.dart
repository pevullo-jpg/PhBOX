import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_datasource.dart';

class FirestoreFirebaseDatasource implements FirestoreDatasource {
  final FirebaseFirestore firestore;

  FirestoreFirebaseDatasource(this.firestore);

  @override
  Future<void> setDocument({
    required String collectionPath,
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    return firestore.collection(collectionPath).doc(documentId).set(data);
  }

  @override
  Future<void> patchDocument({
    required String collectionPath,
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    return firestore
        .collection(collectionPath)
        .doc(documentId)
        .set(data, SetOptions(merge: true));
  }

  @override
  Future<Map<String, dynamic>?> getDocument({
    required String collectionPath,
    required String documentId,
  }) async {
    final doc = await firestore.collection(collectionPath).doc(documentId).get();
    final Map<String, dynamic>? data = doc.data();
    if (data == null) {
      return null;
    }
    return _withDocumentId(data, doc.id);
  }

  @override
  Stream<Map<String, dynamic>?> watchDocument({
    required String collectionPath,
    required String documentId,
  }) {
    return firestore.collection(collectionPath).doc(documentId).snapshots().map((doc) {
      final Map<String, dynamic>? data = doc.data();
      if (data == null) {
        return null;
      }
      return _withDocumentId(data, doc.id);
    });
  }

  @override
  Future<void> incrementDocumentFields({
    required String collectionPath,
    required String documentId,
    required Map<String, num> fields,
    Map<String, dynamic>? extraData,
  }) {
    final Map<String, dynamic> data = <String, dynamic>{
      if (extraData != null) ...extraData,
      for (final MapEntry<String, num> entry in fields.entries)
        entry.key: FieldValue.increment(entry.value),
    };
    return firestore
        .collection(collectionPath)
        .doc(documentId)
        .set(data, SetOptions(merge: true));
  }

  @override
  Future<List<Map<String, dynamic>>> getCollection({
    required String collectionPath,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) async {
    Query<Map<String, dynamic>> query = firestore.collection(collectionPath);
    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }
    query = _applyLimit(query, limit);
    final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
    return snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => _withDocumentId(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getCollectionWhereEqual({
    required String collectionPath,
    required String field,
    required Object value,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) async {
    Query<Map<String, dynamic>> query = firestore
        .collection(collectionPath)
        .where(field, isEqualTo: value);
    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }
    query = _applyLimit(query, limit);
    final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
    return snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => _withDocumentId(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getCollectionWhereArrayContains({
    required String collectionPath,
    required String field,
    required Object value,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) async {
    Query<Map<String, dynamic>> query = firestore
        .collection(collectionPath)
        .where(field, arrayContains: value);
    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }
    query = _applyLimit(query, limit);
    final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
    return snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => _withDocumentId(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getCollectionGroup({
    required String collectionPath,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) async {
    Query<Map<String, dynamic>> query = firestore.collectionGroup(collectionPath);
    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }
    query = _applyLimit(query, limit);
    final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
    return snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => _withDocumentId(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<void> deleteDocument({
    required String collectionPath,
    required String documentId,
  }) {
    return firestore.collection(collectionPath).doc(documentId).delete();
  }

  @override
  Future<void> setSubDocument({
    required String collectionPath,
    required String documentId,
    required String subcollectionPath,
    required String subDocumentId,
    required Map<String, dynamic> data,
  }) {
    return firestore
        .collection(collectionPath)
        .doc(documentId)
        .collection(subcollectionPath)
        .doc(subDocumentId)
        .set(data);
  }

  @override
  Future<void> deleteSubDocument({
    required String collectionPath,
    required String documentId,
    required String subcollectionPath,
    required String subDocumentId,
  }) {
    return firestore
        .collection(collectionPath)
        .doc(documentId)
        .collection(subcollectionPath)
        .doc(subDocumentId)
        .delete();
  }

  @override
  Future<List<Map<String, dynamic>>> getSubCollection({
    required String collectionPath,
    required String documentId,
    required String subcollectionPath,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) async {
    Query<Map<String, dynamic>> query = firestore
        .collection(collectionPath)
        .doc(documentId)
        .collection(subcollectionPath);
    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }
    query = _applyLimit(query, limit);
    final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
    return snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => _withDocumentId(doc.data(), doc.id))
        .toList();
  }

  Query<Map<String, dynamic>> _applyLimit(Query<Map<String, dynamic>> query, int? limit) {
    if (limit != null && limit > 0) {
      return query.limit(limit);
    }
    return query;
  }

  Map<String, dynamic> _withDocumentId(Map<String, dynamic> data, String documentId) {
    if (data.containsKey('id')) {
      return data;
    }
    return <String, dynamic>{...data, 'id': documentId};
  }
}
