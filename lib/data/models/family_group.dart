class FamilyGroup {
  final String id;
  final String name;
  final List<String> memberFiscalCodes;
  final int colorIndex;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FamilyGroup({
    required this.id,
    required this.name,
    required this.memberFiscalCodes,
    required this.colorIndex,
    required this.createdAt,
    required this.updatedAt,
  });

  FamilyGroup copyWith({
    String? id,
    String? name,
    List<String>? memberFiscalCodes,
    int? colorIndex,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FamilyGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      memberFiscalCodes: memberFiscalCodes ?? this.memberFiscalCodes,
      colorIndex: colorIndex ?? this.colorIndex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'memberFiscalCodes': memberFiscalCodes,
      'colorIndex': colorIndex,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory FamilyGroup.fromMap(Map<String, dynamic> map) {
    return FamilyGroup(
      id: _readString(map['id'] ?? map['familyId']),
      name: _readString(map['name'] ?? map['familyName']),
      memberFiscalCodes: _readStringList(
        map['memberFiscalCodes'] ?? map['members'] ?? map['fiscalCodes'] ?? map['cfs'],
      ),
      colorIndex: _readInt(map['colorIndex'] ?? map['color'] ?? map['groupColorIndex']),
      createdAt: _readDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: _readDate(map['updatedAt']) ?? DateTime.now(),
    );
  }

  static String _readString(dynamic value) => value == null ? '' : value.toString().trim();

  static List<String> _readStringList(dynamic value) {
    final raw = value is List ? value : const <dynamic>[];
    return raw
        .map((item) => item.toString().trim().toUpperCase())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  static int _readInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
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
