class TherapeuticAdviceNote {
  final String patientFiscalCode;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TherapeuticAdviceNote({
    required this.patientFiscalCode,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
  });

  TherapeuticAdviceNote copyWith({
    String? patientFiscalCode,
    String? text,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TherapeuticAdviceNote(
      patientFiscalCode: patientFiscalCode ?? this.patientFiscalCode,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'patientFiscalCode': patientFiscalCode,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory TherapeuticAdviceNote.fromMap(Map<String, dynamic> map) {
    return TherapeuticAdviceNote(
      patientFiscalCode: (map['patientFiscalCode'] ?? '') as String,
      text: (map['text'] ?? '') as String,
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
