class PrescriptionIntake {
  final String id;
  final String driveFileId;
  final String fileName;
  final String patientName;
  final String fiscalCode;
  final String doctorName;
  final String exemptionCode;
  final String city;
  final DateTime? prescriptionDate;
  final bool dpcFlag;
  final List<String> medicines;
  final String rawText;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PrescriptionIntake({
    required this.id,
    required this.driveFileId,
    required this.fileName,
    required this.patientName,
    required this.fiscalCode,
    required this.doctorName,
    required this.exemptionCode,
    required this.city,
    required this.prescriptionDate,
    required this.dpcFlag,
    required this.medicines,
    required this.rawText,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'driveFileId': driveFileId,
      'fileName': fileName,
      'patientName': patientName,
      'fiscalCode': fiscalCode,
      'doctorName': doctorName,
      'exemptionCode': exemptionCode,
      'city': city,
      'prescriptionDate': prescriptionDate?.toIso8601String(),
      'dpcFlag': dpcFlag,
      'medicines': medicines,
      'rawText': rawText,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory PrescriptionIntake.fromMap(Map<String, dynamic> map) {
    return PrescriptionIntake(
      id: (map['id'] ?? '') as String,
      driveFileId: (map['driveFileId'] ?? '') as String,
      fileName: (map['fileName'] ?? '') as String,
      patientName: (map['patientName'] ?? '') as String,
      fiscalCode: (map['fiscalCode'] ?? '') as String,
      doctorName: (map['doctorName'] ?? '') as String,
      exemptionCode: (map['exemptionCode'] ?? '') as String,
      city: (map['city'] ?? '') as String,
      prescriptionDate: _readDate(map['prescriptionDate']),
      dpcFlag: (map['dpcFlag'] ?? false) as bool,
      medicines: List<String>.from(map['medicines'] ?? const <String>[]),
      rawText: (map['rawText'] ?? '') as String,
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
