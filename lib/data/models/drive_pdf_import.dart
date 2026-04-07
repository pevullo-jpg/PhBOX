class DrivePdfPrescriptionEntry {
  final int? pageNumber;
  final String identityKey;
  final String prescriptionNre;
  final DateTime? prescriptionDate;
  final String doctorFullName;
  final String exemptionCode;
  final String city;
  final List<String> therapy;
  final bool isDpc;

  const DrivePdfPrescriptionEntry({
    this.pageNumber,
    this.identityKey = '',
    this.prescriptionNre = '',
    this.prescriptionDate,
    this.doctorFullName = '',
    this.exemptionCode = '',
    this.city = '',
    this.therapy = const <String>[],
    this.isDpc = false,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'pageNumber': pageNumber,
      'identityKey': identityKey,
      'prescriptionNre': prescriptionNre,
      'prescriptionDate': prescriptionDate?.toIso8601String(),
      'doctorFullName': doctorFullName,
      'exemptionCode': exemptionCode,
      'city': city,
      'therapy': therapy,
      'isDpc': isDpc,
    };
  }

  factory DrivePdfPrescriptionEntry.fromMap(Map<String, dynamic> map) {
    return DrivePdfPrescriptionEntry(
      pageNumber: DrivePdfImport._readInt(map['pageNumber'] ?? map['page'] ?? map['page_index']),
      identityKey: DrivePdfImport._readString(map['identityKey'] ?? map['entryKey'] ?? map['key']),
      prescriptionNre: DrivePdfImport._readString(
        map['prescriptionNre'] ?? map['nre'] ?? map['recipeNre'] ?? map['prescription_nre'],
      ),
      prescriptionDate: DrivePdfImport._readDate(map['prescriptionDate'] ?? map['date'] ?? map['recipeDate']),
      doctorFullName: DrivePdfImport._readString(
        map['doctorFullName'] ?? map['doctorName'] ?? map['doctor'] ?? map['medico'],
      ),
      exemptionCode: DrivePdfImport._readString(map['exemptionCode'] ?? map['exemption'] ?? map['esenzione']),
      city: DrivePdfImport._readString(map['city'] ?? map['comune']),
      therapy: DrivePdfImport._readStringList(map['therapy'] ?? map['therapies'] ?? map['items']),
      isDpc: DrivePdfImport._readBool(map['isDpc'] ?? map['dpc'] ?? map['dpcFlag']),
    );
  }
}

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
  final bool pdfDeleted;
  final String sourceType;
  final List<DrivePdfPrescriptionEntry> prescriptionEntries;
  final List<DrivePdfPrescriptionEntry> dpcPrescriptionEntries;
  final DrivePdfPrescriptionEntry? primaryPrescriptionEntry;
  final DrivePdfPrescriptionEntry? primaryDpcPrescriptionEntry;
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
    this.sourceType = 'script',
    this.prescriptionEntries = const <DrivePdfPrescriptionEntry>[],
    this.dpcPrescriptionEntries = const <DrivePdfPrescriptionEntry>[],
    this.primaryPrescriptionEntry,
    this.primaryDpcPrescriptionEntry,
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
    bool? pdfDeleted,
    String? sourceType,
    List<DrivePdfPrescriptionEntry>? prescriptionEntries,
    List<DrivePdfPrescriptionEntry>? dpcPrescriptionEntries,
    DrivePdfPrescriptionEntry? primaryPrescriptionEntry,
    DrivePdfPrescriptionEntry? primaryDpcPrescriptionEntry,
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
      sourceType: sourceType ?? this.sourceType,
      prescriptionEntries: prescriptionEntries ?? this.prescriptionEntries,
      dpcPrescriptionEntries: dpcPrescriptionEntries ?? this.dpcPrescriptionEntries,
      primaryPrescriptionEntry: primaryPrescriptionEntry ?? this.primaryPrescriptionEntry,
      primaryDpcPrescriptionEntry: primaryDpcPrescriptionEntry ?? this.primaryDpcPrescriptionEntry,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  List<DrivePdfPrescriptionEntry> get resolvedDpcEntries {
    if (dpcPrescriptionEntries.isNotEmpty) {
      return dpcPrescriptionEntries;
    }

    final fromEntries = prescriptionEntries.where((entry) => entry.isDpc).toList();
    if (fromEntries.isNotEmpty) {
      return fromEntries;
    }

    if (primaryDpcPrescriptionEntry != null) {
      return <DrivePdfPrescriptionEntry>[primaryDpcPrescriptionEntry!];
    }

    if (primaryPrescriptionEntry != null && primaryPrescriptionEntry!.isDpc) {
      return <DrivePdfPrescriptionEntry>[primaryPrescriptionEntry!];
    }

    if (isDpc) {
      return <DrivePdfPrescriptionEntry>[
        DrivePdfPrescriptionEntry(
          prescriptionDate: prescriptionDate,
          doctorFullName: doctorFullName,
          exemptionCode: exemptionCode,
          city: city,
          therapy: therapy,
          isDpc: true,
        ),
      ];
    }

    return const <DrivePdfPrescriptionEntry>[];
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
      'sourceType': sourceType,
      'prescriptionEntries': prescriptionEntries.map((entry) => entry.toMap()).toList(),
      'dpcPrescriptionEntries': dpcPrescriptionEntries.map((entry) => entry.toMap()).toList(),
      'primaryPrescriptionEntry': primaryPrescriptionEntry?.toMap(),
      'primaryDpcPrescriptionEntry': primaryDpcPrescriptionEntry?.toMap(),
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
      sourceType: _readString(map['sourceType'] ?? map['source']).isEmpty ? 'script' : _readString(map['sourceType'] ?? map['source']),
      prescriptionEntries: _readEntryList(map['prescriptionEntries']),
      dpcPrescriptionEntries: _readEntryList(map['dpcPrescriptionEntries']),
      primaryPrescriptionEntry: _readEntry(map['primaryPrescriptionEntry']),
      primaryDpcPrescriptionEntry: _readEntry(map['primaryDpcPrescriptionEntry']),
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

  static DrivePdfPrescriptionEntry? _readEntry(dynamic value) {
    if (value is Map<String, dynamic>) {
      return DrivePdfPrescriptionEntry.fromMap(value);
    }
    if (value is Map) {
      return DrivePdfPrescriptionEntry.fromMap(Map<String, dynamic>.from(value));
    }
    return null;
  }

  static List<DrivePdfPrescriptionEntry> _readEntryList(dynamic value) {
    if (value is! List) return const <DrivePdfPrescriptionEntry>[];
    return value
        .map((item) {
          if (item is Map<String, dynamic>) {
            return DrivePdfPrescriptionEntry.fromMap(item);
          }
          if (item is Map) {
            return DrivePdfPrescriptionEntry.fromMap(Map<String, dynamic>.from(item));
          }
          return null;
        })
        .whereType<DrivePdfPrescriptionEntry>()
        .toList();
  }
}
