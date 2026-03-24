class Patient {
  final String fiscalCode;
  final String fullName;
  final String? city;
  final String? exemptionCode;
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
    this.exemptionCode,
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
    String? exemptionCode,
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
      exemptionCode: exemptionCode ?? this.exemptionCode,
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

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'fiscalCode': fiscalCode,
      'fullName': fullName,
      'city': city,
      'exemptionCode': exemptionCode,
      'doctorName': doctorName,
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
    return Patient(
      fiscalCode: (map['fiscalCode'] ?? '') as String,
      fullName: (map['fullName'] ?? '') as String,
      city: map['city'] as String?,
      exemptionCode: (map['exemptionCode'] ?? map['exemption'] ?? map['esenzione']) as String?,
      doctorName: (map['doctorFullName'] ?? map['doctorName'] ?? map['doctor'] ?? map['medico']) as String?,
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
