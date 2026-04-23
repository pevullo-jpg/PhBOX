import 'package:cloud_firestore/cloud_firestore.dart';

import '../session/phbox_tenant_session.dart';

class TenantFirestorePathResolver {
  const TenantFirestorePathResolver._();

  static CollectionReference<Map<String, dynamic>> collection(
    FirebaseFirestore firestore,
    String collectionPath,
  ) {
    return firestore.collection(resolveCollectionPath(collectionPath));
  }

  static DocumentReference<Map<String, dynamic>> document({
    required FirebaseFirestore firestore,
    required String collectionPath,
    required String documentId,
  }) {
    return collection(firestore, collectionPath).doc(documentId);
  }

  static String resolveCollectionPath(String collectionPath) {
    final String normalized = _normalizePath(collectionPath);
    if (normalized.isEmpty) {
      return normalized;
    }
    final String root = _normalizePath(PhboxTenantSession.instance.dataRootPath);
    if (root.isEmpty || normalized.startsWith('$root/')) {
      return normalized;
    }
    return '$root/$normalized';
  }

  static String resolveCollectionGroupId(String collectionPath) {
    final String normalized = _normalizePath(collectionPath);
    if (normalized.isEmpty) {
      return normalized;
    }
    final List<String> segments = normalized.split('/');
    return segments.isEmpty ? normalized : segments.last;
  }

  static String _normalizePath(String value) {
    String normalized = value.trim();
    while (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}
