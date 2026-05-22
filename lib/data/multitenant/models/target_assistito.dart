class TargetAssistito {
  final String assistitoId;
  final String fiscalCode;
  final String fullName;
  final List<String> searchPrefixes;
  final Map<String, dynamic> doctor;
  final Map<String, dynamic> dashboard;
  final Map<String, dynamic> therapeuticAdvice;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int sourceVersion;

  const TargetAssistito({
    required this.assistitoId,
    required this.fiscalCode,
    required this.fullName,
    required this.searchPrefixes,
    required this.doctor,
    required this.dashboard,
    required this.therapeuticAdvice,
    required this.createdAt,
    required this.updatedAt,
    required this.sourceVersion,
  });

  factory TargetAssistito.empty({
    required String assistitoId,
    required String fiscalCode,
  }) {
    return TargetAssistito(
      assistitoId: assistitoId.trim(),
      fiscalCode: fiscalCode.trim().toUpperCase(),
      fullName: '',
      searchPrefixes: const <String>[],
      doctor: const <String, dynamic>{},
      dashboard: const <String, dynamic>{},
      therapeuticAdvice: const <String, dynamic>{},
      createdAt: null,
      updatedAt: null,
      sourceVersion: 0,
    );
  }

  factory TargetAssistito.fromMap({
    required String assistitoId,
    required Map<String, dynamic> map,
  }) {
    return TargetAssistito(
      assistitoId: assistitoId.trim(),
      fiscalCode: _readString(map['fiscalCode']).toUpperCase(),
      fullName: _readString(map['fullName']),
      searchPrefixes: _readStringList(map['searchPrefixes']),
      doctor: _readMap(map['doctor']),
      dashboard: _readMap(map['dashboard']),
      therapeuticAdvice: _readMap(map['therapeuticAdvice']),
      createdAt: _readDate(map['createdAt']),
      updatedAt: _readDate(map['updatedAt']),
      sourceVersion: _readInt(map['sourceVersion']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'fiscalCode': fiscalCode,
      'fullName': fullName,
      'searchPrefixes': searchPrefixes,
      'doctor': doctor,
      'dashboard': dashboard,
      'therapeuticAdvice': therapeuticAdvice,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'sourceVersion': sourceVersion,
    };
  }

  static String _readString(Object? value) {
    return value?.toString().trim() ?? '';
  }

  static int _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<String> _readStringList(Object? value) {
    if (value is Iterable) {
      return value
          .map((Object? item) => item?.toString().trim() ?? '')
          .where((String item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  static Map<String, dynamic> _readMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.unmodifiable(value);
    }
    if (value is Map) {
      return Map<String, dynamic>.unmodifiable(
        value.map((dynamic key, dynamic item) => MapEntry<String, dynamic>(key.toString(), item)),
      );
    }
    return const <String, dynamic>{};
  }

  static DateTime? _readDate(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) return DateTime.tryParse(value.trim());
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    try {
      final dynamic date = (value as dynamic).toDate();
      if (date is DateTime) return date;
    } catch (_) {}
    return null;
  }
}
