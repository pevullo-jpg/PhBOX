import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../models/backup_job.dart';

class BackupJobsRepository {
  final FirebaseFirestore firestore;

  const BackupJobsRepository({required this.firestore});

  Future<String> enqueueExport({
    required String targetFolderId,
  }) async {
    final DocumentReference<Map<String, dynamic>> doc =
        firestore.collection(AppCollections.backupJobs).doc();
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
    return doc.id;
  }

  Future<String> enqueueImport({
    required String importMode,
    String? sourceBackupFileId,
    String? targetFolderId,
  }) async {
    final DocumentReference<Map<String, dynamic>> doc =
        firestore.collection(AppCollections.backupJobs).doc();
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
    return doc.id;
  }

  Future<List<BackupJob>> getRecentJobs({int limit = 8}) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await firestore
        .collection(AppCollections.backupJobs)
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
}
