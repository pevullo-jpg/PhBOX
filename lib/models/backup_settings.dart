class BackupSettings {
  final bool enabled;
  final String frequency; // daily | weekly | monthly
  final String folderPath;
  final String? lastRunIso;
  final int keepLast;

  const BackupSettings({
    required this.enabled,
    required this.frequency,
    required this.folderPath,
    required this.lastRunIso,
    required this.keepLast,
  });

  factory BackupSettings.defaults() {
    return const BackupSettings(
      enabled: false,
      frequency: 'weekly',
      folderPath: '',
      lastRunIso: null,
      keepLast: 10,
    );
  }

  DateTime? get lastRun => lastRunIso == null || lastRunIso!.isEmpty
      ? null
      : DateTime.tryParse(lastRunIso!);

  BackupSettings copyWith({
    bool? enabled,
    String? frequency,
    String? folderPath,
    String? lastRunIso,
    int? keepLast,
    bool clearLastRun = false,
  }) {
    return BackupSettings(
      enabled: enabled ?? this.enabled,
      frequency: frequency ?? this.frequency,
      folderPath: folderPath ?? this.folderPath,
      lastRunIso: clearLastRun ? null : (lastRunIso ?? this.lastRunIso),
      keepLast: keepLast ?? this.keepLast,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'frequency': frequency,
      'folderPath': folderPath,
      'lastRunIso': lastRunIso,
      'keepLast': keepLast,
    };
  }

  factory BackupSettings.fromJson(Map<String, dynamic> json) {
    return BackupSettings(
      enabled: json['enabled'] ?? false,
      frequency: (json['frequency'] ?? 'weekly').toString(),
      folderPath: (json['folderPath'] ?? '').toString(),
      lastRunIso: json['lastRunIso']?.toString(),
      keepLast: (json['keepLast'] ?? 10) is int
          ? json['keepLast'] as int
          : int.tryParse(json['keepLast'].toString()) ?? 10,
    );
  }
}
