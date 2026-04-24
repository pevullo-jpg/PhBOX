class AppSettings {
  final int expiryWarningDays;
  final List<String> doctorsCatalog;
  final DateTime updatedAt;

  const AppSettings({
    this.expiryWarningDays = 7,
    this.doctorsCatalog = const <String>[],
    required this.updatedAt,
  });

  AppSettings copyWith({
    int? expiryWarningDays,
    List<String>? doctorsCatalog,
    DateTime? updatedAt,
  }) {
    return AppSettings(
      expiryWarningDays: expiryWarningDays ?? this.expiryWarningDays,
      doctorsCatalog: doctorsCatalog ?? this.doctorsCatalog,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toFrontendPatchMap() {
    return <String, dynamic>{
      'expiryWarningDays': expiryWarningDays,
      'doctorsCatalog': doctorsCatalog,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      expiryWarningDays: _readInt(map['expiryWarningDays']) ?? 7,
      doctorsCatalog: _readStringList(map['doctorsCatalog']),
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
      if (seconds is int) {
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    } catch (_) {}
    return null;
  }
}
