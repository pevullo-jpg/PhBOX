class ParserReferenceValue {
  final String id;
  final String type;
  final String value;
  final String normalizedValue;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ParserReferenceValue({
    required this.id,
    required this.type,
    required this.value,
    required this.normalizedValue,
    required this.createdAt,
    required this.updatedAt,
  });

  ParserReferenceValue copyWith({
    String? id,
    String? type,
    String? value,
    String? normalizedValue,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ParserReferenceValue(
      id: id ?? this.id,
      type: type ?? this.type,
      value: value ?? this.value,
      normalizedValue: normalizedValue ?? this.normalizedValue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'type': type,
      'value': value,
      'normalizedValue': normalizedValue,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ParserReferenceValue.fromMap(Map<String, dynamic> map) {
    return ParserReferenceValue(
      id: (map['id'] ?? '') as String,
      type: (map['type'] ?? '') as String,
      value: (map['value'] ?? '') as String,
      normalizedValue: (map['normalizedValue'] ?? '') as String,
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
    return null;
  }
}
