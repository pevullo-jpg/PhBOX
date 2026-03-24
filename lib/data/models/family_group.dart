class FamilyGroup {
  final String id;
  final String name;
  final List<String> members;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FamilyGroup({
    required this.id,
    required this.name,
    required this.members,
    required this.createdAt,
    required this.updatedAt,
  });

  FamilyGroup copyWith({
    String? id,
    String? name,
    List<String>? members,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FamilyGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      members: members ?? this.members,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'members': members,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory FamilyGroup.fromMap(Map<String, dynamic> map) {
    final members = (map['members'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => item.toString().trim().toUpperCase())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return FamilyGroup(
      id: _readString(map['id']).isNotEmpty
          ? _readString(map['id'])
          : (_readString(map['familyId']).isNotEmpty ? _readString(map['familyId']) : _readString(map['name'])),
      name: _readString(map['name']).isNotEmpty ? _readString(map['name']) : 'Famiglia',
      members: members,
      createdAt: _readDate(map['createdAt']) ?? DateTime.now(),
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
