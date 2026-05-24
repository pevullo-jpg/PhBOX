import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/legacy_target_assistito_comparison.dart';
import '../models/target_assistito.dart';
import '../models/target_multitenant_collections.dart';

class TargetAssistitiReadOnlyRejectedException implements Exception {
  final String code;
  final String message;

  const TargetAssistitiReadOnlyRejectedException({
    required this.code,
    required this.message,
  });

  @override
  String toString() {
    return 'TargetAssistitiReadOnlyRejectedException($code): $message';
  }
}

class TargetAssistitiReadDocument {
  final String documentId;
  final Map<String, dynamic> rawData;
  final TargetAssistito assistito;
  final TargetAssistitoDocumentIdentityComparison documentIdentity;

  const TargetAssistitiReadDocument({
    required this.documentId,
    required this.rawData,
    required this.assistito,
    required this.documentIdentity,
  });

  bool get documentIdentityValid => documentIdentity.isValid;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'documentId': documentId,
      'documentIdentityValid': documentIdentityValid,
      'documentIdentity': documentIdentity.toMap(),
      'assistito': assistito.toMap(),
    };
  }
}

class TargetAssistitiReadOnlyResult {
  final String tenantId;
  final String collectionPath;
  final int requestedLimit;
  final int returnedCount;
  final bool empty;
  final List<TargetAssistitiReadDocument> documents;

  const TargetAssistitiReadOnlyResult({
    required this.tenantId,
    required this.collectionPath,
    required this.requestedLimit,
    required this.returnedCount,
    required this.empty,
    required this.documents,
  });

  factory TargetAssistitiReadOnlyResult.empty({
    required String tenantId,
    required String collectionPath,
    required int requestedLimit,
  }) {
    return TargetAssistitiReadOnlyResult(
      tenantId: tenantId,
      collectionPath: collectionPath,
      requestedLimit: requestedLimit,
      returnedCount: 0,
      empty: true,
      documents: const <TargetAssistitiReadDocument>[],
    );
  }

  bool get hasDocuments => documents.isNotEmpty;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tenantId': tenantId,
      'collectionPath': collectionPath,
      'requestedLimit': requestedLimit,
      'returnedCount': returnedCount,
      'empty': empty,
      'hasDocuments': hasDocuments,
      'documents': documents
          .map((TargetAssistitiReadDocument document) => document.toMap())
          .toList(growable: false),
    };
  }
}

class TargetAssistitiReadOnlyReader {
  static const int defaultMaxDocuments = 20;
  static const int hardMaxDocuments = 50;

  final FirebaseFirestore firestore;

  const TargetAssistitiReadOnlyReader({
    required this.firestore,
  });

  Future<TargetAssistitiReadOnlyResult> readAssistiti({
    required String tenantId,
    int maxDocuments = defaultMaxDocuments,
  }) async {
    final String normalizedTenantId = _normalizeTenantId(tenantId);
    final int safeLimit = _validateLimit(maxDocuments);
    final String collectionPath = TargetMultitenantCollections.tenantCollection(
      tenantId: normalizedTenantId,
      collectionId: TargetMultitenantCollections.assistiti,
    );

    final QuerySnapshot<Map<String, dynamic>> snapshot = await firestore
        .collection(collectionPath)
        .limit(safeLimit)
        .get(const GetOptions(source: Source.serverAndCache));

    if (snapshot.docs.isEmpty) {
      return TargetAssistitiReadOnlyResult.empty(
        tenantId: normalizedTenantId,
        collectionPath: collectionPath,
        requestedLimit: safeLimit,
      );
    }

    final List<TargetAssistitiReadDocument> documents = snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> document) {
      final Map<String, dynamic> data =
          Map<String, dynamic>.unmodifiable(document.data());
      return TargetAssistitiReadDocument(
        documentId: document.id,
        rawData: data,
        assistito: TargetAssistito.fromMap(
          assistitoId: document.id,
          map: data,
        ),
        documentIdentity: TargetAssistitoDocumentIdentityComparison.fromDocument(
          documentId: document.id,
          data: data,
        ),
      );
    }).toList(growable: false);

    return TargetAssistitiReadOnlyResult(
      tenantId: normalizedTenantId,
      collectionPath: collectionPath,
      requestedLimit: safeLimit,
      returnedCount: documents.length,
      empty: documents.isEmpty,
      documents: List<TargetAssistitiReadDocument>.unmodifiable(documents),
    );
  }

  static String _normalizeTenantId(String value) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw const TargetAssistitiReadOnlyRejectedException(
        code: 'tenant_id_empty',
        message: 'tenantId obbligatorio per la lettura isolata assistiti target.',
      );
    }
    if (normalized.contains('/')) {
      throw const TargetAssistitiReadOnlyRejectedException(
        code: 'tenant_id_not_canonical',
        message: 'tenantId non canonico: slash non ammesso.',
      );
    }
    return normalized;
  }

  static int _validateLimit(int value) {
    if (value <= 0) {
      throw TargetAssistitiReadOnlyRejectedException(
        code: 'max_documents_not_positive',
        message: 'maxDocuments deve essere positivo.',
      );
    }
    if (value > hardMaxDocuments) {
      throw TargetAssistitiReadOnlyRejectedException(
        code: 'max_documents_exceeds_hard_cap',
        message: 'maxDocuments supera il limite hard di $hardMaxDocuments documenti.',
      );
    }
    return value;
  }
}
