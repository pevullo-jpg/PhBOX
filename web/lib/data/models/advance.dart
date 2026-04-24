class Advance {
  final String id;
  final String patientFiscalCode;
  final String patientName;
  final String drugName;
  final String doctorName;
  final String? note;
  final bool matchedTherapyFlag;
  final String? matchedPrescriptionId;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Advance({
    required this.id,
    required this.patientFiscalCode,
    required this.patientName,
    required this.drugName,
    required this.doctorName,
    this.note,
    this.matchedTherapyFlag = false,
    this.matchedPrescriptionId,
    this.status = 'open',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'patientFiscalCode': patientFiscalCode,
      'patientName': patientName,
      'drugName': drugName,
      'doctorName': doctorName,
      'note': note,
      'matchedTherapyFlag': matchedTherapyFlag,
      'matchedPrescriptionId': matchedPrescriptionId,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Advance.fromMap(Map<String, dynamic> map) {
    return Advance(
      id: (map['id'] ?? '') as String,
      patientFiscalCode: (map['patientFiscalCode'] ?? '') as String,
      patientName: (map['patientName'] ?? '') as String,
      drugName: (map['drugName'] ?? '') as String,
      doctorName: (map['doctorName'] ?? '') as String,
      note: map['note'] as String?,
      matchedTherapyFlag: (map['matchedTherapyFlag'] ?? false) as bool,
      matchedPrescriptionId: map['matchedPrescriptionId'] as String?,
      status: (map['status'] ?? 'open') as String,
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
