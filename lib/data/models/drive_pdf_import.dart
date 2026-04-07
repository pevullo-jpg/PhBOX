class DrivePdfImport {
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
  final String driveFileId;
  final String fileName;
  final String mimeType;
  final String status;
  final String errorMessage;
  final String patientFiscalCode;
  final String patientFullName;
  final String doctorFullName;
  final String exemptionCode;
  final String city;
  final List<String> therapy;
  final bool isDpc;
  final int prescriptionCount;
  final DateTime? prescriptionDate;
  final String webViewLink;
  final bool pdfDeleted;
  final bool deletePdfRequested;
  final bool active;
  final String mergedIntoImportId;
  final String supersededBy;
  final String sourceType;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DrivePdfImport({
    required this.id,
    required this.driveFileId,
    required this.fileName,
    required this.mimeType,
    required this.status,
    this.errorMessage = '',
    this.patientFiscalCode = '',
    this.patientFullName = '',
    this.doctorFullName = '',
    this.exemptionCode = '',
    this.city = '',
    this.therapy = const <String>[],
    this.isDpc = false,
    this.prescriptionCount = 1,
    this.prescriptionDate,
    this.webViewLink = '',
    this.pdfDeleted = false,
    this.deletePdfRequested = false,
    this.active = true,
    this.mergedIntoImportId = '',
    this.supersededBy = '',
    this.sourceType = 'script',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get containsMultiplePrescriptions => prescriptionCount > 1;

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

  DrivePdfImport copyWith({
    String? id,
    String? driveFileId,
    String? fileName,
    String? mimeType,
    String? status,
    String? errorMessage,
    String? patientFiscalCode,
    String? patientFullName,
    String? doctorFullName,
    String? exemptionCode,
    String? city,
    List<String>? therapy,
    bool? isDpc,
    int? prescriptionCount,
    DateTime? prescriptionDate,
    String? webViewLink,
    bool? pdfDeleted,
    bool? deletePdfRequested,
    bool? active,
    String? mergedIntoImportId,
    String? supersededBy,
    String? sourceType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DrivePdfImport(
      id: id ?? this.id,
      driveFileId: driveFileId ?? this.driveFileId,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      patientFiscalCode: patientFiscalCode ?? this.patientFiscalCode,
      patientFullName: patientFullName ?? this.patientFullName,
      doctorFullName: doctorFullName ?? this.doctorFullName,
      exemptionCode: exemptionCode ?? this.exemptionCode,
      city: city ?? this.city,
      therapy: therapy ?? this.therapy,
      isDpc: isDpc ?? this.isDpc,
      prescriptionCount: prescriptionCount ?? this.prescriptionCount,
      prescriptionDate: prescriptionDate ?? this.prescriptionDate,
      webViewLink: webViewLink ?? this.webViewLink,
      pdfDeleted: pdfDeleted ?? this.pdfDeleted,
      deletePdfRequested: deletePdfRequested ?? this.deletePdfRequested,
      active: active ?? this.active,
      mergedIntoImportId: mergedIntoImportId ?? this.mergedIntoImportId,
      supersededBy: supersededBy ?? this.supersededBy,
      sourceType: sourceType ?? this.sourceType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'driveFileId': driveFileId,
      'fileName': fileName,
      'mimeType': mimeType,
      'status': status,
      'errorMessage': errorMessage,
      'patientFiscalCode': patientFiscalCode,
      'patientFullName': patientFullName,
      'doctorFullName': doctorFullName,
      'exemptionCode': exemptionCode,
      'city': city,
      'therapy': therapy,
      'isDpc': isDpc,
      'prescriptionCount': prescriptionCount,
      'prescriptionDate': prescriptionDate?.toIso8601String(),
      'webViewLink': webViewLink,
      'pdfDeleted': pdfDeleted,
      'deletePdfRequested': deletePdfRequested,
      'active': active,
      'mergedIntoImportId': mergedIntoImportId,
      'supersededBy': supersededBy,
      'sourceType': sourceType,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory DrivePdfImport.fromMap(Map<String, dynamic> map) {
    return DrivePdfImport(
      id: (map['id'] ?? map['duplicateHash'] ?? '') as String,
      driveFileId: (map['driveFileId'] ?? map['fileId'] ?? '') as String,
      fileName: (map['fileName'] ?? '') as String,
      mimeType: (map['mimeType'] ?? 'application/pdf') as String,
      status: (map['status'] ?? 'pending') as String,
      errorMessage: (map['errorMessage'] ?? '') as String,
      patientFiscalCode: _readString(
        map['patientFiscalCode'] ??
            map['fiscalCode'] ??
            map['patientCf'] ??
            map['patientCF'] ??
            map['cf'] ??
            map['codiceFiscale'] ??
            map['patient_fiscal_code'],
      ),
      patientFullName: _readString(map['patientFullName'] ?? map['patientName'] ?? map['fullName'] ?? map['name']),
      doctorFullName: _readString(
        map['doctorFullName'] ?? map['doctorName'] ?? map['doctor'] ?? map['medico'] ?? map['doctor_full_name'],
      ),
      exemptionCode: _readString(map['exemptionCode'] ?? map['exemption'] ?? map['esenzione']),
      city: _readString(map['city'] ?? map['comune']),
      therapy: _readStringList(map['therapy'] ?? map['therapies'] ?? map['items']),
      isDpc: _readBool(map['isDpc'] ?? map['dpc'] ?? map['dpcFlag'] ?? map['mergeHasDpc']),
      prescriptionCount: _readInt(
            map['prescriptionCount'] ??
            map['sourceCount'] ??
            map['recipeCount'] ??
            map['count'],
          ) ??
          1,
      prescriptionDate: _readDate(map['prescriptionDate'] ?? map['date'] ?? map['recipeDate']),
      webViewLink: _readString(
        map['webViewLink'] ??
            map['openUrl'] ??
            map['viewLink'] ??
            map['driveViewLink'] ??
            map['fileUrl'] ??
            map['url'] ??
            map['link'] ??
            map['alternateLink'] ??
            map['mergedWebViewLink'] ??
            map['downloadUrl'],
      ),
      pdfDeleted: _readBool(map['pdfDeleted']) || _readString(map['status']).toLowerCase() == 'deleted_pdf',
      deletePdfRequested: _readBool(map['deletePdfRequested']),
      active: _readOptionalBool(map['active']) ?? !_readBool(map['inactive']),
      mergedIntoImportId: _readString(map['mergedIntoImportId'] ?? map['mergedInto'] ?? map['absorbedIntoImportId']),
      supersededBy: _readString(map['supersededBy'] ?? map['supersededByImportId']),
      sourceType: _readString(map['sourceType'] ?? map['source']).isEmpty ? 'script' : _readString(map['sourceType'] ?? map['source']),
      createdAt: _readDate(map['createdAt'] ?? map['importedAt']) ?? DateTime.now(),
      updatedAt: _readDate(map['updatedAt'] ?? map['manifestUpdatedAt']) ?? DateTime.now(),
    );
  }

  static String _readString(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  static List<String> _readStringList(dynamic value) {
    if (value == null) return const <String>[];
    if (value is List) {
      return value.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toList();
    }
    final text = value.toString().trim();
    if (text.isEmpty) return const <String>[];
    return text
        .split(RegExp(r'[,;|\n]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
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

  static int? _readInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}
