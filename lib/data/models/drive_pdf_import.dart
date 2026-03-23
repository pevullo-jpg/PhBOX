class DrivePdfImport {
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
  final String sourceType;
  final String documentType;
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
    this.sourceType = 'script',
    this.documentType = 'prescription',
    required this.createdAt,
    required this.updatedAt,
  });

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
    String? sourceType,
    String? documentType,
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
      sourceType: sourceType ?? this.sourceType,
      documentType: documentType ?? this.documentType,
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
      'sourceType': sourceType,
      'documentType': documentType,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory DrivePdfImport.fromMap(Map<String, dynamic> map) {
    final Map<String, dynamic> flat = _flattenMap(map);
    final String documentType = _readString(flat['documentType'] ?? flat['type'] ?? flat['docType']);
    final int fallbackCount = documentType.isEmpty || documentType.toLowerCase() == 'prescription' ? 1 : 0;
    return DrivePdfImport(
      id: _readString(flat['id'] ?? flat['duplicateHash'] ?? flat['hash']),
      driveFileId: _readString(flat['driveFileId'] ?? flat['fileId'] ?? flat['googleDriveFileId']),
      fileName: _readString(flat['fileName'] ?? flat['name']),
      mimeType: _readString(flat['mimeType']).isEmpty ? 'application/pdf' : _readString(flat['mimeType']),
      status: _readString(flat['status']).isEmpty ? 'pending' : _readString(flat['status']),
      errorMessage: _readString(flat['errorMessage'] ?? flat['error']),
      patientFiscalCode: _readString(
        flat['patientFiscalCode'] ??
            flat['fiscalCode'] ??
            flat['patientCf'] ??
            flat['patientCF'] ??
            flat['cf'] ??
            flat['codiceFiscale'] ??
            flat['patient_fiscal_code'] ??
            flat['assistitoFiscalCode'] ??
            flat['assistitoCf'],
      ),
      patientFullName: _readString(
        flat['patientFullName'] ?? flat['patientName'] ?? flat['fullName'] ?? flat['name'] ?? flat['assistitoNomeCompleto'],
      ),
      doctorFullName: _readString(
        flat['doctorFullName'] ?? flat['doctorName'] ?? flat['doctor'] ?? flat['medico'] ?? flat['doctor_full_name'],
      ),
      exemptionCode: _readString(flat['exemptionCode'] ?? flat['exemption'] ?? flat['esenzione']),
      city: _readString(flat['city'] ?? flat['comune']),
      therapy: _readStringList(flat['therapy'] ?? flat['therapies'] ?? flat['items'] ?? flat['therapySummary']),
      isDpc: _readBool(flat['isDpc'] ?? flat['dpc'] ?? flat['dpcFlag']),
      prescriptionCount: _readInt(flat['prescriptionCount'] ?? flat['sourceCount'] ?? flat['recipeCount'] ?? flat['count']) ?? fallbackCount,
      prescriptionDate: _readDate(flat['prescriptionDate'] ?? flat['date'] ?? flat['recipeDate'] ?? flat['lastPrescriptionDate']),
      webViewLink: _readString(
        flat['webViewLink'] ??
            flat['viewLink'] ??
            flat['driveViewLink'] ??
            flat['fileUrl'] ??
            flat['downloadUrl'] ??
            flat['url'] ??
            flat['link'] ??
            flat['alternateLink'],
      ),
      sourceType: _readString(flat['sourceType'] ?? flat['source']).isEmpty ? 'script' : _readString(flat['sourceType'] ?? flat['source']),
      documentType: documentType.isEmpty ? 'prescription' : documentType,
      createdAt: _readDate(flat['createdAt'] ?? flat['importedAt']) ?? DateTime.now(),
      updatedAt: _readDate(flat['updatedAt'] ?? flat['manifestUpdatedAt']) ?? DateTime.now(),
    );
  }

  static Map<String, dynamic> _flattenMap(Map<String, dynamic> source) {
    final Map<String, dynamic> result = <String, dynamic>{};

    void absorb(Map<dynamic, dynamic> map) {
      map.forEach((dynamic rawKey, dynamic value) {
        final String key = rawKey.toString();
        if (!result.containsKey(key) || _isEmptyValue(result[key])) {
          result[key] = value;
        }
        if (value is Map) {
          absorb(value);
        }
      });
    }

    absorb(source);
    return result;
  }

  static bool _isEmptyValue(dynamic value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    if (value is List) return value.isEmpty;
    return false;
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
