class AppSettings {
  final int expiryWarningDays;
  final List<String> doctorsCatalog;
  final bool backupAutoEnabled;
  final int backupAutoIntervalMinutes;
  final String backupAutoDestination;
  final String? backupDriveFolderId;
  final DateTime? backupLastRunAt;
  final String? backupLastRunStatus;
  final DateTime updatedAt;

  const AppSettings({
    this.expiryWarningDays = 7,
    this.doctorsCatalog = const <String>[],
    this.backupAutoEnabled = false,
    this.backupAutoIntervalMinutes = 720,
    this.backupAutoDestination = 'drive',
    this.backupDriveFolderId,
    this.backupLastRunAt,
    this.backupLastRunStatus,
    required this.updatedAt,
  });

  AppSettings copyWith({
    int? expiryWarningDays,
    List<String>? doctorsCatalog,
    bool? backupAutoEnabled,
    int? backupAutoIntervalMinutes,
    String? backupAutoDestination,
    String? backupDriveFolderId,
    bool clearBackupDriveFolderId = false,
    DateTime? backupLastRunAt,
    bool clearBackupLastRunAt = false,
    String? backupLastRunStatus,
    bool clearBackupLastRunStatus = false,
    DateTime? updatedAt,
  }) {
    return AppSettings(
      expiryWarningDays: expiryWarningDays ?? this.expiryWarningDays,
      doctorsCatalog: doctorsCatalog ?? this.doctorsCatalog,
      backupAutoEnabled: backupAutoEnabled ?? this.backupAutoEnabled,
      backupAutoIntervalMinutes:
          backupAutoIntervalMinutes ?? this.backupAutoIntervalMinutes,
      backupAutoDestination:
          backupAutoDestination ?? this.backupAutoDestination,
      backupDriveFolderId: clearBackupDriveFolderId
          ? null
          : (backupDriveFolderId ?? this.backupDriveFolderId),
      backupLastRunAt: clearBackupLastRunAt
          ? null
          : (backupLastRunAt ?? this.backupLastRunAt),
      backupLastRunStatus: clearBackupLastRunStatus
          ? null
          : (backupLastRunStatus ?? this.backupLastRunStatus),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toFrontendPatchMap() {
    return <String, dynamic>{
      'expiryWarningDays': expiryWarningDays,
      'doctorsCatalog': doctorsCatalog,
      'backupAutoEnabled': backupAutoEnabled,
      'backupAutoIntervalMinutes': backupAutoIntervalMinutes,
      'backupAutoDestination': backupAutoDestination,
      'backupDriveFolderId': backupDriveFolderId,
      'backupLastRunAt': backupLastRunAt?.toIso8601String(),
      'backupLastRunStatus': backupLastRunStatus,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      expiryWarningDays: _readInt(map['expiryWarningDays']) ?? 7,
      doctorsCatalog: _readStringList(map['doctorsCatalog']),
      backupAutoEnabled: _readBool(map['backupAutoEnabled']),
      backupAutoIntervalMinutes:
          _readInt(map['backupAutoIntervalMinutes']) ?? 720,
      backupAutoDestination: _readString(map['backupAutoDestination'])
              .trim()
              .isEmpty
          ? 'drive'
          : _readString(map['backupAutoDestination']).trim(),
      backupDriveFolderId: _readNullableString(map['backupDriveFolderId']),
      backupLastRunAt: _readDate(map['backupLastRunAt']),
      backupLastRunStatus: _readNullableString(map['backupLastRunStatus']),
      updatedAt: _readDate(map['updatedAt']) ?? DateTime.now(),
    );
  }

  factory AppSettings.empty() {
    return AppSettings(updatedAt: DateTime.now());
  }

  static List<String> _readStringList(dynamic value) {
    if (value == null) return const <String>[];
    if (value is List) {
      return value
          .map((dynamic item) => item.toString().trim())
          .where((String item) => item.isNotEmpty)
          .toList();
    }
    final String normalized = value.toString().trim();
    if (normalized.isEmpty) return const <String>[];
    return normalized
        .split(RegExp(r'[,;|\n]'))
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList();
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    final String normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'si' ||
        normalized == 'sì';
  }

  static String _readString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  static String? _readNullableString(dynamic value) {
    final String normalized = _readString(value).trim();
    return normalized.isEmpty ? null : normalized;
  }

  static DateTime? _readDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    try {
      final dynamic date = (value as dynamic).toDate();
      if (date is DateTime) return date;
    } catch (_) {}
    try {
      final dynamic seconds = (value as dynamic).seconds;
      if (seconds is int) return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    } catch (_) {}
    return null;
  }
}
