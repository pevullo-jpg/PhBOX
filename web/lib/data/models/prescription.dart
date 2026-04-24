import 'prescription_item.dart';

class Prescription {
  final String id;
  final String patientFiscalCode;
  final String patientName;
  final DateTime prescriptionDate;
  final DateTime? expiryDate;
  final String? doctorName;
  final String? exemptionCode;
  final String? city;
  final bool dpcFlag;
  final int prescriptionCount;
  final String sourceType;
  final String? extractedText;
  final List<PrescriptionItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Prescription({
    required this.id,
    required this.patientFiscalCode,
    required this.patientName,
    required this.prescriptionDate,
    this.expiryDate,
    this.doctorName,
    this.exemptionCode,
    this.city,
    this.dpcFlag = false,
    this.prescriptionCount = 1,
    required this.sourceType,
    this.extractedText,
    this.items = const <PrescriptionItem>[],
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'patientFiscalCode': patientFiscalCode,
      'patientName': patientName,
      'prescriptionDate': prescriptionDate.toIso8601String(),
      'expiryDate': expiryDate?.toIso8601String(),
      'doctorName': doctorName,
      'exemptionCode': exemptionCode,
      'city': city,
      'dpcFlag': dpcFlag,
      'prescriptionCount': prescriptionCount,
      'sourceType': sourceType,
      'extractedText': extractedText,
      'items': items.map((PrescriptionItem item) => item.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Prescription.fromMap(Map<String, dynamic> map) {
    return Prescription(
      id: (map['id'] ?? '') as String,
      patientFiscalCode: (map['patientFiscalCode'] ?? '') as String,
      patientName: (map['patientName'] ?? '') as String,
      prescriptionDate: _readDate(map['prescriptionDate']) ?? DateTime.now(),
      expiryDate: _readDate(map['expiryDate']),
      doctorName: map['doctorName'] as String?,
      exemptionCode: map['exemptionCode'] as String?,
      city: map['city'] as String?,
      dpcFlag: (map['dpcFlag'] ?? false) as bool,
      prescriptionCount: (map['prescriptionCount'] ?? 1) as int,
      sourceType: (map['sourceType'] ?? 'upload') as String,
      extractedText: map['extractedText'] as String?,
      items: (map['items'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic item) => PrescriptionItem.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList(),
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
