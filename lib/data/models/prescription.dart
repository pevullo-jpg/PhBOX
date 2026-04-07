import 'prescription_item.dart';

class Prescription {
  static const Set<String> _inactiveStatuses = <String>{
    'deleted',
    'deleted_pdf',
    'superseded',
    'merged_source',
    'merged_component',
    'absorbed',
    'inactive',
  };

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
  final String status;
  final bool pdfDeleted;
  final bool deletePdfRequested;
  final bool active;
  final String parentImportId;
  final String driveFileId;
  final String nre;
  final int? pageIndex;
  final String pageRange;
  final String mergedIntoImportId;
  final String supersededBy;
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
    this.status = 'active',
    this.pdfDeleted = false,
    this.deletePdfRequested = false,
    this.active = true,
    this.parentImportId = '',
    this.driveFileId = '',
    this.nre = '',
    this.pageIndex,
    this.pageRange = '',
    this.mergedIntoImportId = '',
    this.supersededBy = '',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isSuperseded {
    if (mergedIntoImportId.trim().isNotEmpty) return true;
    if (supersededBy.trim().isNotEmpty) return true;
    return _inactiveStatuses.contains(status.trim().toLowerCase()) && status.trim().toLowerCase() != 'deleted' && status.trim().toLowerCase() != 'deleted_pdf';
  }

  bool get isActiveForDashboard {
    if (!active) return false;
    if (pdfDeleted || deletePdfRequested) return false;
    final String normalizedStatus = status.trim().toLowerCase();
    if (_inactiveStatuses.contains(normalizedStatus)) return false;
    return !isSuperseded;
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
      'extractedText': extractedText,
      'items': items.map((PrescriptionItem item) => item.toMap()).toList(),
      'status': status,
      'pdfDeleted': pdfDeleted,
      'deletePdfRequested': deletePdfRequested,
      'active': active,
      'parentImportId': parentImportId,
      'driveFileId': driveFileId,
      'nre': nre,
      'pageIndex': pageIndex,
      'pageRange': pageRange,
      'mergedIntoImportId': mergedIntoImportId,
      'supersededBy': supersededBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Prescription.fromMap(Map<String, dynamic> map) {
    return Prescription(
      id: _readString(
        map['id'] ??
            map['prescriptionId'] ??
            map['unitId'] ??
            map['docId'] ??
            map['uuid'] ??
            map['nre'],
      ),
      patientFiscalCode: _readString(
        map['patientFiscalCode'] ??
            map['fiscalCode'] ??
            map['patientCf'] ??
            map['patientCF'] ??
            map['cf'] ??
            map['codiceFiscale'] ??
            map['patient_fiscal_code'],
      ),
      patientName: _readString(
        map['patientName'] ??
            map['patientFullName'] ??
            map['fullName'] ??
            map['name'],
      ),
      prescriptionDate: _readDate(
            map['prescriptionDate'] ??
                map['date'] ??
                map['recipeDate'] ??
                map['prescribedAt'],
          ) ??
          DateTime.now(),
      expiryDate: _readDate(map['expiryDate'] ?? map['validUntil']),
      doctorName: _readNullableString(
        map['doctorName'] ?? map['doctorFullName'] ?? map['doctor'] ?? map['medico'],
      ),
      exemptionCode: _readNullableString(map['exemptionCode'] ?? map['exemption'] ?? map['esenzione']),
      city: _readNullableString(map['city'] ?? map['comune']),
      dpcFlag: _readBool(map['dpcFlag'] ?? map['isDpc'] ?? map['dpc']),
      prescriptionCount: _readInt(
            map['prescriptionCount'] ??
                map['sourceCount'] ??
                map['recipeCount'] ??
                map['count'],
          ) ??
          1,
      sourceType: _readString(map['sourceType'] ?? map['source'] ?? map['sourceKind']).isEmpty
          ? 'upload'
          : _readString(map['sourceType'] ?? map['source'] ?? map['sourceKind']),
      extractedText: _readNullableString(
        map['extractedText'] ?? map['rawText'] ?? map['ocrText'] ?? map['text'],
      ),
      items: _readItems(
        map['items'] ??
            map['therapy'] ??
            map['therapies'] ??
            map['drugs'] ??
            map['medicines'] ??
            map['farmaci'],
      ),
      status: _readString(map['status']).isEmpty ? 'active' : _readString(map['status']),
      pdfDeleted: _readBool(map['pdfDeleted']) || _readString(map['status']).trim().toLowerCase() == 'deleted_pdf',
      deletePdfRequested: _readBool(map['deletePdfRequested']),
      active: _readOptionalBool(map['active']) ?? !_readBool(map['inactive']),
      parentImportId: _readString(
        map['parentImportId'] ?? map['importId'] ?? map['sourceImportId'] ?? map['driveImportId'],
      ),
      driveFileId: _readString(map['driveFileId'] ?? map['fileId']),
      nre: _readString(map['nre'] ?? map['recipeNre'] ?? map['prescriptionNre']),
      pageIndex: _readInt(map['pageIndex'] ?? map['pageNumber']),
      pageRange: _readString(map['pageRange'] ?? map['pageSpan']),
      mergedIntoImportId: _readString(map['mergedIntoImportId'] ?? map['mergedInto'] ?? map['absorbedIntoImportId']),
      supersededBy: _readString(map['supersededBy'] ?? map['supersededByImportId']),
      createdAt: _readDate(map['createdAt'] ?? map['importedAt']) ?? DateTime.now(),
      updatedAt: _readDate(map['updatedAt'] ?? map['manifestUpdatedAt']) ?? DateTime.now(),
    );
  }

  static String _readString(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  static String? _readNullableString(dynamic value) {
    final String normalized = _readString(value);
    return normalized.isEmpty ? null : normalized;
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == 'true' || normalized == '1' || normalized == 'si' || normalized == 'sì' || normalized == 'yes';
  }

  static bool? _readOptionalBool(dynamic value) {
    if (value == null) return null;
    return _readBool(value);
  }

  static int? _readInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
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

  static List<PrescriptionItem> _readItems(dynamic value) {
    if (value == null) return const <PrescriptionItem>[];
    if (value is List) {
      final List<PrescriptionItem> items = <PrescriptionItem>[];
      for (final entry in value) {
        if (entry is PrescriptionItem) {
          items.add(entry);
          continue;
        }
        if (entry is Map) {
          items.add(PrescriptionItem.fromMap(Map<String, dynamic>.from(entry)));
          continue;
        }
        final String text = entry.toString().trim();
        if (text.isNotEmpty) {
          items.add(PrescriptionItem(drugName: text));
        }
      }
      return items;
    }
    final String text = value.toString().trim();
    if (text.isEmpty) return const <PrescriptionItem>[];
    return text
        .split(RegExp(r'[,;|\n]'))
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .map((String item) => PrescriptionItem(drugName: item))
        .toList();
  }
}
