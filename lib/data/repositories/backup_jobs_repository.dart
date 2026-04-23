import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/tenant_firestore_path_resolver.dart';
import '../models/backup_job.dart';

class BackupQueueRequestResult {
  final bool enqueued;
  final String? jobId;
  final String reason;
  final BackupJob? blockingJob;

  const BackupQueueRequestResult({
    required this.enqueued,
    required this.jobId,
    required this.reason,
    required this.blockingJob,
  });

  factory BackupQueueRequestResult.enqueued(String jobId) {
    return BackupQueueRequestResult(
      enqueued: true,
      jobId: jobId,
      reason: 'enqueued',
      blockingJob: null,
    );
  }

  factory BackupQueueRequestResult.blocked(BackupJob? job) {
    return BackupQueueRequestResult(
      enqueued: false,
      jobId: null,
      reason: 'queue_busy',
      blockingJob: job,
    );
  }
}

class BackupJobsRepository {
  final FirebaseFirestore firestore;

  const BackupJobsRepository({required this.firestore});

  Future<BackupQueueRequestResult> enqueueExport({
    required String targetFolderId,
  }) async {
    final List<BackupJob> activeJobs = await getActiveJobs();
    if (activeJobs.isNotEmpty) {
      return BackupQueueRequestResult.blocked(activeJobs.first);
    }
    final DocumentReference<Map<String, dynamic>> doc =
        TenantFirestorePathResolver.collection(firestore, AppCollections.backupJobs).doc();
    final DateTime now = DateTime.now();
    await doc.set(<String, dynamic>{
      'id': doc.id,
      'jobType': 'export',
      'status': 'pending',
      'trigger': 'manual',
      'requestedBy': 'frontend',
      'requestedAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'targetFolderId': targetFolderId.trim(),
      'sourceBackupFileId': '',
      'importMode': '',
      'resultMessage': '',
      'errorMessage': '',
      'jsonFileId': '',
      'pdfFileId': '',
      'jsonFileName': '',
      'pdfFileName': '',
    });
    return BackupQueueRequestResult.enqueued(doc.id);
  }

  Future<BackupQueueRequestResult> enqueueImport({
    required String importMode,
    String? sourceBackupFileId,
    String? targetFolderId,
  }) async {
    final List<BackupJob> activeJobs = await getActiveJobs();
    if (activeJobs.isNotEmpty) {
      return BackupQueueRequestResult.blocked(activeJobs.first);
    }
    final DocumentReference<Map<String, dynamic>> doc =
        TenantFirestorePathResolver.collection(firestore, AppCollections.backupJobs).doc();
    final DateTime now = DateTime.now();
    await doc.set(<String, dynamic>{
      'id': doc.id,
      'jobType': 'import',
      'status': 'pending',
      'trigger': 'manual',
      'requestedBy': 'frontend',
      'requestedAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'targetFolderId': (targetFolderId ?? '').trim(),
      'sourceBackupFileId': (sourceBackupFileId ?? '').trim(),
      'importMode': importMode.trim().isEmpty ? 'merge' : importMode.trim(),
      'resultMessage': '',
      'errorMessage': '',
      'jsonFileId': '',
      'pdfFileId': '',
      'jsonFileName': '',
      'pdfFileName': '',
    });
    return BackupQueueRequestResult.enqueued(doc.id);
  }

  Future<List<BackupJob>> getRecentJobs({int limit = 8}) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await firestore
        .collection(TenantFirestorePathResolver.resolveCollectionPath(AppCollections.backupJobs))
        .orderBy('requestedAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              BackupJob.fromMap(<String, dynamic>{...doc.data(), 'id': doc.id}),
        )
        .toList();
  }

  Future<List<BackupJob>> getActiveJobs({int limitPerStatus = 10}) async {
    final List<BackupJob> pending = await _getJobsByStatus(
      status: 'pending',
      limit: limitPerStatus,
    );
    final List<BackupJob> running = await _getJobsByStatus(
      status: 'running',
      limit: limitPerStatus,
    );
    final Map<String, BackupJob> merged = <String, BackupJob>{
      for (final BackupJob job in <BackupJob>[...pending, ...running]) job.id: job,
    };
    final List<BackupJob> result = merged.values.toList()
      ..sort(
        (BackupJob a, BackupJob b) => b.requestedAt.compareTo(a.requestedAt),
      );
    return result;
  }

  Future<List<BackupJob>> _getJobsByStatus({
    required String status,
    required int limit,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await firestore
        .collection(TenantFirestorePathResolver.resolveCollectionPath(AppCollections.backupJobs))
        .where('status', isEqualTo: status)
        .limit(limit)
        .get();
    return snapshot.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              BackupJob.fromMap(<String, dynamic>{...doc.data(), 'id': doc.id}),
        )
        .toList();
  }
}
