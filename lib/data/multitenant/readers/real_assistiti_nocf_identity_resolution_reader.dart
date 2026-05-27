import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/target_multitenant_collections.dart';

class RealAssistitiNoCfIdentityResolutionPendingItem {
  final String assistitoId;
  final String documentPath;
  final String identityAnchor;
  final String fullName;
  final String nome;
  final String cognome;
  final List<Map<String, String>> candidateSplits;
  final List<String> rawDataRootKeys;

  const RealAssistitiNoCfIdentityResolutionPendingItem({
    required this.assistitoId,
    required this.documentPath,
    required this.identityAnchor,
    required this.fullName,
    required this.nome,
    required this.cognome,
    required this.candidateSplits,
    required this.rawDataRootKeys,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'assistitoId': assistitoId,
      'documentPath': documentPath,
      'identityAnchor': identityAnchor,
      'fullName': fullName,
      'nome': nome,
      'cognome': cognome,
      'candidateSplits': candidateSplits,
      'rawDataRootKeys': rawDataRootKeys,
    };
  }
}

class RealAssistitiNoCfIdentityResolutionPendingResult {
  final String tenantId;
  final String assistitiCollectionPath;
  final List<RealAssistitiNoCfIdentityResolutionPendingItem> items;
  final int maxPendingItems;
  final int attemptedReads;

  const RealAssistitiNoCfIdentityResolutionPendingResult({
    required this.tenantId,
    required this.assistitiCollectionPath,
    required this.items,
    required this.maxPendingItems,
    required this.attemptedReads,
  });

  bool get hasPendingItems => items.isNotEmpty;

  int get pendingCount => items.length;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tenantId': tenantId,
      'assistitiCollectionPath': assistitiCollectionPath,
      'pendingCount': pendingCount,
      'maxPendingItems': maxPendingItems,
      'attemptedReads': attemptedReads,
      'items': items
          .map((RealAssistitiNoCfIdentityResolutionPendingItem item) => item.toMap())
          .toList(growable: false),
    };
  }
}

class RealAssistitiNoCfIdentityResolutionReader {
  static const int defaultMaxPendingItems = 20;
  static const String pendingStatus = 'pending_manual';

  final FirebaseFirestore firestore;

  const RealAssistitiNoCfIdentityResolutionReader({
    required this.firestore,
  });

  Future<RealAssistitiNoCfIdentityResolutionPendingResult> readPendingManual({
    required String tenantId,
    int maxPendingItems = defaultMaxPendingItems,
  }) async {
    final String normalizedTenantId = _normalizeTenantId(tenantId);
    final int safeLimit = _normalizeLimit(maxPendingItems);
    final String assistitiCollectionPath = TargetMultitenantCollections.tenantCollection(
      tenantId: normalizedTenantId,
      collectionId: TargetMultitenantCollections.assistiti,
    );

    final QuerySnapshot<Map<String, dynamic>> snapshot = await firestore
        .collection(assistitiCollectionPath)
        .where('identityResolutionStatus', isEqualTo: pendingStatus)
        .limit(safeLimit)
        .get(const GetOptions(source: Source.serverAndCache));

    final List<RealAssistitiNoCfIdentityResolutionPendingItem> items =
        <RealAssistitiNoCfIdentityResolutionPendingItem>[];
    for (final QueryDocumentSnapshot<Map<String, dynamic>> document in snapshot.docs) {
      items.add(fromDocumentSnapshot(
        tenantId: normalizedTenantId,
        document: document,
      ));
    }

    return RealAssistitiNoCfIdentityResolutionPendingResult(
      tenantId: normalizedTenantId,
      assistitiCollectionPath: assistitiCollectionPath,
      items: List<RealAssistitiNoCfIdentityResolutionPendingItem>.unmodifiable(items),
      maxPendingItems: safeLimit,
      attemptedReads: snapshot.docs.length,
    );
  }

  static RealAssistitiNoCfIdentityResolutionPendingItem fromDocumentSnapshot({
    required String tenantId,
    required QueryDocumentSnapshot<Map<String, dynamic>> document,
  }) {
    final Map<String, dynamic> rawData = document.data();
    final String documentPath = TargetMultitenantCollections.assistitoDocument(
      tenantId: tenantId,
      assistitoId: document.id,
    );

    return RealAssistitiNoCfIdentityResolutionPendingItem(
      assistitoId: _readString(rawData['assistitoId']).isEmpty
          ? document.id
          : _readString(rawData['assistitoId']),
      documentPath: documentPath,
      identityAnchor: _readString(rawData['identityAnchor']),
      fullName: _readString(rawData['fullName']),
      nome: _readString(rawData['nome']),
      cognome: _readString(rawData['cognome']),
      candidateSplits: sanitizeCandidateSplits(_readIdentityResolutionMap(rawData)['candidateSplits']),
      rawDataRootKeys: _sortedRootKeys(rawData),
    );
  }

  static List<Map<String, String>> sanitizeCandidateSplits(Object? value) {
    if (value is! Iterable) {
      return const <Map<String, String>>[];
    }

    final List<Map<String, String>> result = <Map<String, String>>[];
    for (final Object? item in value) {
      if (item is! Map) {
        continue;
      }
      final String nome = _readString(item['nome']);
      final String cognome = _readString(item['cognome']);
      if (nome.isEmpty || cognome.isEmpty) {
        continue;
      }
      result.add(<String, String>{
        'nome': nome,
        'cognome': cognome,
      });
    }

    return List<Map<String, String>>.unmodifiable(result);
  }

  static Map<String, dynamic> _readIdentityResolutionMap(Map<String, dynamic> rawData) {
    final Object? value = rawData['identityResolution'];
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.unmodifiable(
        value.map((Object? key, Object? item) => MapEntry<String, dynamic>(key.toString(), item)),
      );
    }
    return const <String, dynamic>{};
  }

  static int _normalizeLimit(int value) {
    if (value <= 0) {
      return defaultMaxPendingItems;
    }
    if (value > defaultMaxPendingItems) {
      return defaultMaxPendingItems;
    }
    return value;
  }

  static String _normalizeTenantId(String value) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'tenantId', 'tenantId vuoto non valido.');
    }
    if (normalized.contains('/')) {
      throw ArgumentError.value(value, 'tenantId', 'tenantId con slash non valido.');
    }
    return normalized;
  }

  static List<String> _sortedRootKeys(Map<String, dynamic> payload) {
    return List<String>.unmodifiable(payload.keys.toList(growable: false)..sort());
  }

  static String _readString(Object? value) {
    return value?.toString().trim() ?? '';
  }
}
