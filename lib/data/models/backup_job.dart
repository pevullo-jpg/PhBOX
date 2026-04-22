class BackupJob {
  final String id;
  final String jobType;
  final String status;
  final String trigger;
  final String requestedBy;
  final String importMode;
  final String sourceBackupFileId;
  final String targetFolderId;
  final String resultMessage;
  final String errorMessage;
  final String jsonFileId;
  final String pdfFileId;
  final String jsonFileName;
  final String pdfFileName;
  final DateTime requestedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime updatedAt;

  const BackupJob({
    required this.id,
    required this.jobType,
    required this.status,
    required this.trigger,
    required this.requestedBy,
    required this.importMode,
    required this.sourceBackupFileId,
    required this.targetFolderId,
    required this.resultMessage,
    required this.errorMessage,
    required this.jsonFileId,
    required this.pdfFileId,
    required this.jsonFileName,
    required this.pdfFileName,
    required this.requestedAt,
    required this.startedAt,
    required this.completedAt,
    required this.updatedAt,
  });

  bool get isPending => status.trim().toLowerCase() == 'pending';
  bool get isRunning => status.trim().toLowerCase() == 'running';
  bool get isCompleted => status.trim().toLowerCase() == 'completed';
  bool get isFailed => status.trim().toLowerCase() == 'failed';

  String get normalizedJobType {
    final String value = jobType.trim().toLowerCase();
    if (value == 'import') {
      return 'import';
    }
    return 'export';
  }

  factory BackupJob.fromMap(Map<String, dynamic> map) {
    return BackupJob(
      id: _readString(map['id']),
      jobType: _readString(map['jobType']).isEmpty
          ? 'export'
          : _readString(map['jobType']),
      status: _readString(map['status']).isEmpty
          ? 'pending'
          : _readString(map['status']),
      trigger: _readString(map['trigger']).isEmpty
          ? 'manual'
          : _readString(map['trigger']),
      requestedBy: _readString(map['requestedBy']).isEmpty
          ? 'frontend'
          : _readString(map['requestedBy']),
      importMode: _readString(map['importMode']),
      sourceBackupFileId: _readString(map['sourceBackupFileId']),
      targetFolderId: _readString(map['targetFolderId']),
      resultMessage: _readString(map['resultMessage']),
      errorMessage: _readString(map['errorMessage']),
      jsonFileId: _readString(map['jsonFileId']),
      pdfFileId: _readString(map['pdfFileId']),
      jsonFileName: _readString(map['jsonFileName']),
      pdfFileName: _readString(map['pdfFileName']),
      requestedAt: _readDate(map['requestedAt']) ?? DateTime.now(),
      startedAt: _readDate(map['startedAt']),
      completedAt: _readDate(map['completedAt']),
      updatedAt: _readDate(map['updatedAt']) ?? DateTime.now(),
    );
  }

  static String _readString(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  static DateTime? _readDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    try {
      final dynamic date = (value as dynamic).toDate();
      if (date is DateTime) {
        return date;
      }
    } catch (_) {}
    try {
      final dynamic seconds = (value as dynamic).seconds;
      if (seconds is int) {
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    } catch (_) {}
    return null;
  }
}
