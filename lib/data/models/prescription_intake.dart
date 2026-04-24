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
  final int prescriptionCount;
  final List<String> medicines;
  final String rawText;
  final String status;
  final String importErrorMessage;
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
    this.prescriptionCount = 1,
    required this.medicines,
    required this.rawText,
    this.status = 'parsed',
    this.importErrorMessage = '',
    required this.createdAt,
    required this.updatedAt,
  });

  PrescriptionIntake copyWith({
    String? id,
    String? driveFileId,
    String? fileName,
    String? patientName,
    String? fiscalCode,
    String? doctorName,
    String? exemptionCode,
    String? city,
    DateTime? prescriptionDate,
    bool? dpcFlag,
    int? prescriptionCount,
    List<String>? medicines,
    String? rawText,
    String? status,
    String? importErrorMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PrescriptionIntake(
      id: id ?? this.id,
      driveFileId: driveFileId ?? this.driveFileId,
      fileName: fileName ?? this.fileName,
      patientName: patientName ?? this.patientName,
      fiscalCode: fiscalCode ?? this.fiscalCode,
      doctorName: doctorName ?? this.doctorName,
      exemptionCode: exemptionCode ?? this.exemptionCode,
      city: city ?? this.city,
      prescriptionDate: prescriptionDate ?? this.prescriptionDate,
      dpcFlag: dpcFlag ?? this.dpcFlag,
      prescriptionCount: prescriptionCount ?? this.prescriptionCount,
      medicines: medicines ?? this.medicines,
      rawText: rawText ?? this.rawText,
      status: status ?? this.status,
      importErrorMessage: importErrorMessage ?? this.importErrorMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

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
      'prescriptionCount': prescriptionCount,
      'medicines': medicines,
      'rawText': rawText,
      'status': status,
      'importErrorMessage': importErrorMessage,
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
      prescriptionCount: (map['prescriptionCount'] ?? 1) as int,
      medicines: List<String>.from(map['medicines'] ?? const <String>[]),
      rawText: (map['rawText'] ?? '') as String,
      status: (map['status'] ?? 'parsed') as String,
      importErrorMessage: (map['importErrorMessage'] ?? '') as String,
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
