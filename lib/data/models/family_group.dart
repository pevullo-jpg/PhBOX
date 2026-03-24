class FamilyGroup {
  final String id;
  final String name;
  final List<String> fiscalCodes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FamilyGroup({
    required this.id,
    required this.name,
    required this.fiscalCodes,
    required this.createdAt,
    required this.updatedAt,
  });

  FamilyGroup copyWith({
    String? id,
    String? name,
    List<String>? fiscalCodes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FamilyGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      fiscalCodes: fiscalCodes ?? this.fiscalCodes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'fiscalCodes': fiscalCodes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory FamilyGroup.fromMap(Map<String, dynamic> map) {
    return FamilyGroup(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      fiscalCodes: List<String>.from(map['fiscalCodes'] ?? const <String>[]).map((e) => e.trim().toUpperCase()).where((e) => e.isNotEmpty).toSet().toList(),
      createdAt: _readDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: _readDate(map['updatedAt']) ?? DateTime.now(),
    );
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
