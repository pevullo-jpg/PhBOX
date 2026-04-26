import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';

class RuntimeSignalRepository {
  final FirestoreDatasource datasource;

  const RuntimeSignalRepository({required this.datasource});

  Future<void> emitBestEffort({
    required String domain,
    required String operation,
    required String targetPath,
    required String targetFiscalCode,
    required String targetDocumentId,
    required bool requiresTotalsUpdate,
    required bool requiresIndexUpdate,
  }) async {
    try {
      await emit(
        domain: domain,
        operation: operation,
        targetPath: targetPath,
        targetFiscalCode: targetFiscalCode,
        targetDocumentId: targetDocumentId,
        requiresTotalsUpdate: requiresTotalsUpdate,
        requiresIndexUpdate: requiresIndexUpdate,
      );
    } catch (_) {
      // PHBOX_RUNTIME_SIGNAL_GATE è un'ottimizzazione backend.
      // La scrittura del dato utente non deve fallire se le regole Firestore
      // non permettono ancora la scrittura dei segnali runtime.
    }
  }

  Future<void> emit({
    required String domain,
    required String operation,
    required String targetPath,
    required String targetFiscalCode,
    required String targetDocumentId,
    required bool requiresTotalsUpdate,
    required bool requiresIndexUpdate,
  }) async {
    final DateTime now = DateTime.now();
    final String nowIso = now.toIso8601String();
    final String signalId = _signalId(
      domain: domain,
      operation: operation,
      targetPath: targetPath,
      targetDocumentId: targetDocumentId,
    );

    await datasource.patchDocument(
      collectionPath: AppCollections.phboxSignals,
      documentId: signalId,
      data: <String, dynamic>{
        'signalId': signalId,
        'status': 'pending',
        'domain': domain,
        'operation': operation,
        'targetPath': targetPath,
        'targetFiscalCode': targetFiscalCode.trim().toUpperCase(),
        'targetDocumentId': targetDocumentId.trim(),
        'requiresTotalsUpdate': requiresTotalsUpdate,
        'requiresIndexUpdate': requiresIndexUpdate,
        'createdAt': nowIso,
        'updatedAt': nowIso,
        'processedAt': null,
        'attempts': 0,
        'lastError': '',
      },
    );

    await datasource.patchDocument(
      collectionPath: AppCollections.phboxRuntime,
      documentId: 'main',
      data: <String, dynamic>{
        'status': 'green',
        'pendingWorkCount': 1,
        'nextSignalId': signalId,
        'lastChangedAt': nowIso,
        'updatedAt': nowIso,
      },
    );
  }

  String _signalId({
    required String domain,
    required String operation,
    required String targetPath,
    required String targetDocumentId,
  }) {
    final String rawKey = targetDocumentId.trim().isNotEmpty
        ? targetDocumentId.trim()
        : targetPath.trim();
    final String safeKey = rawKey
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final String suffix = safeKey.isEmpty ? DateTime.now().microsecondsSinceEpoch.toString() : safeKey;
    return '${domain}_${operation}_$suffix';
  }
}
