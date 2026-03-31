class Patient {
  final String fiscalCode;
  final String fullName;
  final String? city;
  final String? exemption;
  final String? exemptionCode;
  final List<String> exemptions;
  final String? doctorName;
  final List<String> therapiesSummary;
  final DateTime? lastPrescriptionDate;
  final bool hasDebt;
  final double debtTotal;
  final bool hasBooking;
  final bool hasAdvance;
  final bool hasDpc;
  final int archivedRecipeCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Patient({
    required this.fiscalCode,
    required this.fullName,
    this.city,
    this.exemption,
    this.exemptionCode,
    this.exemptions = const <String>[],
    this.doctorName,
    this.therapiesSummary = const <String>[],
    this.lastPrescriptionDate,
    this.hasDebt = false,
    this.debtTotal = 0,
    this.hasBooking = false,
    this.hasAdvance = false,
    this.hasDpc = false,
    this.archivedRecipeCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Patient copyWith({
    String? fiscalCode,
    String? fullName,
    String? city,
    String? exemption,
    String? exemptionCode,
    List<String>? exemptions,
    String? doctorName,
    List<String>? therapiesSummary,
    DateTime? lastPrescriptionDate,
    bool? hasDebt,
    double? debtTotal,
    bool? hasBooking,
    bool? hasAdvance,
    bool? hasDpc,
    int? archivedRecipeCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Patient(
      fiscalCode: fiscalCode ?? this.fiscalCode,
      fullName: fullName ?? this.fullName,
      city: city ?? this.city,
      exemption: exemption ?? this.exemption,
      exemptionCode: exemptionCode ?? this.exemptionCode,
      exemptions: exemptions ?? this.exemptions,
      doctorName: doctorName ?? this.doctorName,
      therapiesSummary: therapiesSummary ?? this.therapiesSummary,
      lastPrescriptionDate: lastPrescriptionDate ?? this.lastPrescriptionDate,
      hasDebt: hasDebt ?? this.hasDebt,
      debtTotal: debtTotal ?? this.debtTotal,
      hasBooking: hasBooking ?? this.hasBooking,
      hasAdvance: hasAdvance ?? this.hasAdvance,
      hasDpc: hasDpc ?? this.hasDpc,
      archivedRecipeCount: archivedRecipeCount ?? this.archivedRecipeCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String? get currentExemption {
    final String resolved = _normalizeString(exemption).isNotEmpty
        ? _normalizeString(exemption).toUpperCase()
        : (_normalizeString(exemptionCode).isNotEmpty
            ? _normalizeString(exemptionCode).toUpperCase()
            : (normalizedExemptions.isEmpty ? '' : normalizedExemptions.first));
    return resolved.isEmpty ? null : resolved;
  }

  List<String> get normalizedExemptions {
    return normalizeExemptionValues(<dynamic>[
      ...exemptions,
      exemption,
      exemptionCode,
    ]);
  }

  String get exemptionsDisplay {
    final List<String> values = normalizedExemptions;
    return values.isEmpty ? '-' : values.join(', ');
  }

  Map<String, dynamic> toMap() {
    final String? current = currentExemption;
    return <String, dynamic>{
      'fiscalCode': fiscalCode,
      'fullName': fullName,
      'city': city,
      'exemption': current,
      'exemptionCode': current,
      'exemptions': normalizedExemptions,
      'doctorName': doctorName,
      'doctorFullName': doctorName,
      'therapiesSummary': therapiesSummary,
      'lastPrescriptionDate': lastPrescriptionDate?.toIso8601String(),
      'hasDebt': hasDebt,
      'debtTotal': debtTotal,
      'hasBooking': hasBooking,
      'hasAdvance': hasAdvance,
      'hasDpc': hasDpc,
      'archivedRecipeCount': archivedRecipeCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Patient.fromMap(Map<String, dynamic> map) {
    final List<String> exemptions = normalizeExemptionValues(<dynamic>[
      ..._readExemptionCollection(map['exemptions']),
      map['exemption'],
      map['exemptionCode'],
      map['esenzione'],
    ]);
    final String? currentExemption = _firstNonEmpty(<dynamic>[
      map['exemption'],
      map['exemptionCode'],
      map['esenzione'],
      exemptions.isEmpty ? null : exemptions.first,
    ])?.toUpperCase();
    return Patient(
      fiscalCode: _normalizeString(map['fiscalCode'] ?? map['patientFiscalCode'] ?? map['cf'] ?? map['codiceFiscale']).toUpperCase(),
      fullName: _normalizeString(map['fullName'] ?? map['patientFullName'] ?? map['name']),
      city: _nullIfEmpty(map['city']),
      exemption: currentExemption,
      exemptionCode: currentExemption,
      exemptions: exemptions,
      doctorName: _nullIfEmpty(map['doctorFullName'] ?? map['doctorName'] ?? map['doctor'] ?? map['medico']),
      therapiesSummary: List<String>.from(map['therapiesSummary'] ?? const <String>[]),
      lastPrescriptionDate: _readDate(map['lastPrescriptionDate']),
      hasDebt: (map['hasDebt'] ?? false) as bool,
      debtTotal: _readDouble(map['debtTotal']),
      hasBooking: (map['hasBooking'] ?? false) as bool,
      hasAdvance: (map['hasAdvance'] ?? false) as bool,
      hasDpc: (map['hasDpc'] ?? false) as bool,
      archivedRecipeCount: (map['archivedRecipeCount'] ?? 0) as int,
      createdAt: _readDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: _readDate(map['updatedAt']) ?? DateTime.now(),
    );
  }

  static List<String> normalizeExemptionValues(Iterable<dynamic> values) {
    final Set<String> normalized = <String>{};
    for (final dynamic value in values) {
      if (value == null) continue;
      if (value is List) {
        normalized.addAll(normalizeExemptionValues(value));
        continue;
      }
      final String text = value.toString().trim().toUpperCase();
      if (text.isNotEmpty) {
        normalized.add(text);
      }
    }
    final List<String> result = normalized.toList()..sort();
    return result;
  }


  static List<dynamic> _readExemptionCollection(dynamic value) {
    if (value == null) return const <dynamic>[];
    if (value is List) return List<dynamic>.from(value);
    final String text = value.toString().trim();
    if (text.isEmpty) return const <dynamic>[];
    return text.split(RegExp(r'[,;|\n]')).map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
  }

  static String _normalizeString(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  static String? _nullIfEmpty(dynamic value) {
    final String text = _normalizeString(value);
    return text.isEmpty ? null : text;
  }

  static String? _firstNonEmpty(Iterable<dynamic> values) {
    for (final dynamic value in values) {
      final String text = _normalizeString(value);
      if (text.isNotEmpty) return text;
    }
    return null;
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

  static double _readDouble(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return double.tryParse(value.toString()) ?? 0;
  }
}
