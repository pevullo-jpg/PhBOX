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
  Future<Map<String, dynamic>?> getDocument({
    required String collectionPath,
    required String documentId,
  }) async {
    final doc = await firestore.collection(collectionPath).doc(documentId).get();
    return doc.data() == null ? null : <String, dynamic>{...doc.data()!, 'id': doc.id, '_id': doc.id};
  }

  @override
  Future<List<Map<String, dynamic>>> getCollection({
    required String collectionPath,
    String? orderBy,
    bool descending = false,
  }) async {
    Query<Map<String, dynamic>> query = firestore.collection(collectionPath);
    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }
    final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
    return snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => <String, dynamic>{...doc.data(), 'id': doc.id, '_id': doc.id}).toList();
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
    return firestore.collection(collectionPath).doc(documentId).collection(subcollectionPath).doc(subDocumentId).set(data);
  }

  @override

  @override
  Future<void> deleteSubDocument({
    required String collectionPath,
    required String documentId,
    required String subcollectionPath,
    required String subDocumentId,
  }) {
    return firestore.collection(collectionPath).doc(documentId).collection(subcollectionPath).doc(subDocumentId).delete();
  }

  @override
  Future<List<Map<String, dynamic>>> getSubCollection({
    required String collectionPath,
    required String documentId,
    required String subcollectionPath,
    String? orderBy,
    bool descending = false,
  }) async {
    Query<Map<String, dynamic>> query = firestore.collection(collectionPath).doc(documentId).collection(subcollectionPath);
    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }
    final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
    return snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => <String, dynamic>{...doc.data(), 'id': doc.id, '_id': doc.id}).toList();
  }
}
