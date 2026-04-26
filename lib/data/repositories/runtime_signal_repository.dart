import '../../core/constants/app_constants.dart';
import '../datasources/firestore_datasource.dart';

class RuntimeSignalRepository {
  final FirestoreDatasource datasource;

  const RuntimeSignalRepository({required this.datasource});

  Future<void> emitManualDataSignal({
    required String domain,
    required String operation,
    required String targetPath,
    required String targetFiscalCode,
    required String targetDocumentId,
    required bool requiresTotalsUpdate,
    required bool requiresIndexUpdate,
  }) async {
    final String signalId = _buildSignalId(domain: domain, targetDocumentId: targetDocumentId);
    final String now = DateTime.now().toIso8601String();

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
        'createdAt': now,
        'updatedAt': now,
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
        'lastChangedAt': now,
        'updatedAt': now,
      },
    );
  }

  static String _buildSignalId({
    required String domain,
    required String targetDocumentId,
  }) {
    final String safeDomain = _safeSegment(domain);
    final String safeTarget = _safeSegment(targetDocumentId);
    return '${safeDomain}_$safeTarget';
  }

  static String _safeSegment(String value) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      return 'unknown';
    }
    return normalized.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
  }
}
