import '../../core/constants/app_constants.dart';
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
  final String status;
  final bool deleteRequested;
  final DateTime? deletionRequestedAt;
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
    this.status = AppPrescriptionStatuses.active,
    this.deleteRequested = false,
    this.deletionRequestedAt,
    this.extractedText,
    this.items = const <PrescriptionItem>[],
    required this.createdAt,
    required this.updatedAt,
  });

  Prescription copyWith({
    String? id,
    String? patientFiscalCode,
    String? patientName,
    DateTime? prescriptionDate,
    DateTime? expiryDate,
    String? doctorName,
    String? exemptionCode,
    String? city,
    bool? dpcFlag,
    int? prescriptionCount,
    String? sourceType,
    String? status,
    bool? deleteRequested,
    DateTime? deletionRequestedAt,
    String? extractedText,
    List<PrescriptionItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Prescription(
      id: id ?? this.id,
      patientFiscalCode: patientFiscalCode ?? this.patientFiscalCode,
      patientName: patientName ?? this.patientName,
      prescriptionDate: prescriptionDate ?? this.prescriptionDate,
      expiryDate: expiryDate ?? this.expiryDate,
      doctorName: doctorName ?? this.doctorName,
      exemptionCode: exemptionCode ?? this.exemptionCode,
      city: city ?? this.city,
      dpcFlag: dpcFlag ?? this.dpcFlag,
      prescriptionCount: prescriptionCount ?? this.prescriptionCount,
      sourceType: sourceType ?? this.sourceType,
      status: status ?? this.status,
      deleteRequested: deleteRequested ?? this.deleteRequested,
      deletionRequestedAt: deletionRequestedAt ?? this.deletionRequestedAt,
      extractedText: extractedText ?? this.extractedText,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isDeleteRequested {
    final String normalized = status.trim().toLowerCase();
    return deleteRequested || normalized == AppPrescriptionStatuses.deleteRequested;
  }

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
      'status': status,
      'deleteRequested': deleteRequested,
      'deletionRequestedAt': deletionRequestedAt?.toIso8601String(),
      'extractedText': extractedText,
      'items': items.map((PrescriptionItem item) => item.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Prescription.fromMap(Map<String, dynamic> map) {
    final String status = _readString(map['status']).isEmpty ? AppPrescriptionStatuses.active : _readString(map['status']);
    final bool deleteRequested = _readBool(map['deleteRequested']) || status.trim().toLowerCase() == AppPrescriptionStatuses.deleteRequested;
    return Prescription(
      id: _readString(map['id']),
      patientFiscalCode: _readString(map['patientFiscalCode']),
      patientName: _readString(map['patientName']),
      prescriptionDate: _readDate(map['prescriptionDate']) ?? DateTime.now(),
      expiryDate: _readDate(map['expiryDate']),
      doctorName: _readNullableString(map['doctorName'] ?? map['doctorFullName'] ?? map['doctor']),
      exemptionCode: _readNullableString(map['exemptionCode'] ?? map['exemption'] ?? map['esenzione']),
      city: _readNullableString(map['city'] ?? map['comune']),
      dpcFlag: (map['dpcFlag'] ?? false) as bool,
      prescriptionCount: (map['prescriptionCount'] ?? 1) as int,
      sourceType: _readString(map['sourceType']).isEmpty ? 'upload' : _readString(map['sourceType']),
      status: status,
      deleteRequested: deleteRequested,
      deletionRequestedAt: _readDate(map['deletionRequestedAt']),
      extractedText: _readNullableString(map['extractedText']),
      items: (map['items'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic item) => PrescriptionItem.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList(),
      createdAt: _readDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: _readDate(map['updatedAt']) ?? DateTime.now(),
    );
  }

  static String _readString(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  static String? _readNullableString(dynamic value) {
    final String text = _readString(value);
    return text.isEmpty ? null : text;
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    final String normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == 'true' || normalized == '1' || normalized == 'yes' || normalized == 'si' || normalized == 'sì';
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
