class Patient {
  final String fiscalCode;
  final String fullName;
  final String? alias;
  final String? city;
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
  final int archivedPdfCount;
  final int activeArchiveDocuments;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool hasArchivedRecipeCountAggregate;
  final bool hasHasDpcAggregate;
  final bool hasLastPrescriptionDateAggregate;
  final bool hasTherapiesSummaryAggregate;

  const Patient({
    required this.fiscalCode,
    required this.fullName,
    this.alias,
    this.city,
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
    this.archivedPdfCount = 0,
    this.activeArchiveDocuments = 0,
    required this.createdAt,
    required this.updatedAt,
    this.hasArchivedRecipeCountAggregate = false,
    this.hasHasDpcAggregate = false,
    this.hasLastPrescriptionDateAggregate = false,
    this.hasTherapiesSummaryAggregate = false,
  });

  Patient copyWith({
    String? fiscalCode,
    String? fullName,
    String? alias,
    String? city,
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
    int? archivedPdfCount,
    int? activeArchiveDocuments,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? hasArchivedRecipeCountAggregate,
    bool? hasHasDpcAggregate,
    bool? hasLastPrescriptionDateAggregate,
    bool? hasTherapiesSummaryAggregate,
  }) {
    return Patient(
      fiscalCode: fiscalCode ?? this.fiscalCode,
      fullName: fullName ?? this.fullName,
      alias: alias ?? this.alias,
      city: city ?? this.city,
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
      archivedPdfCount: archivedPdfCount ?? this.archivedPdfCount,
      activeArchiveDocuments: activeArchiveDocuments ?? this.activeArchiveDocuments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hasArchivedRecipeCountAggregate: hasArchivedRecipeCountAggregate ?? this.hasArchivedRecipeCountAggregate,
      hasHasDpcAggregate: hasHasDpcAggregate ?? this.hasHasDpcAggregate,
      hasLastPrescriptionDateAggregate: hasLastPrescriptionDateAggregate ?? this.hasLastPrescriptionDateAggregate,
      hasTherapiesSummaryAggregate: hasTherapiesSummaryAggregate ?? this.hasTherapiesSummaryAggregate,
    );
  }

  String? get doctorFullName {
    final String normalized = (doctorName ?? '').trim();
    return normalized.isEmpty ? null : normalized;
  }

  String get primaryExemption {
    final String canonical = exemptions.firstWhere(
      (String item) => item.trim().isNotEmpty,
      orElse: () => '',
    );
    if (canonical.isNotEmpty) {
      return canonical.trim();
    }
    return (exemptionCode ?? '').trim();
  }

  Map<String, dynamic> toManualCreateMap() {
    return <String, dynamic>{
      'fiscalCode': fiscalCode,
      'fullName': fullName,
      'alias': alias,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Patient.fromMap(Map<String, dynamic> map) {
    final List<String> canonicalExemptions = _readStringList(
      map['exemptions'],
    );
    final String primaryLegacyExemption = _readString(
      map['exemptionCode'] ?? map['exemption'] ?? map['esenzione'],
    );
    return Patient(
      fiscalCode: _readString(map['fiscalCode'] ?? map['patientFiscalCode']),
      fullName: _readString(map['fullName'] ?? map['patientFullName']),
      alias: _readNullableString(map['alias'] ?? map['nickname'] ?? map['nomignolo']),
      city: _readNullableString(map['city']),
      exemptionCode: canonicalExemptions.isNotEmpty
          ? canonicalExemptions.first
          : _readNullableString(primaryLegacyExemption),
      exemptions: canonicalExemptions,
      doctorName: _readNullableString(
        map['doctorFullName'] ?? map['doctorName'] ?? map['doctor'] ?? map['medico'],
      ),
      therapiesSummary: _readStringList(map['therapiesSummary']),
      lastPrescriptionDate: _readDate(map['lastPrescriptionDate']),
      hasDebt: _readBool(map['hasDebt']),
      debtTotal: _readDouble(map['debtTotal']),
      hasBooking: _readBool(map['hasBooking']),
      hasAdvance: _readBool(map['hasAdvance']),
      hasDpc: _readBool(map['hasDpc']),
      archivedRecipeCount: _readInt(map['archivedRecipeCount']),
      archivedPdfCount: _readInt(map['archivedPdfCount']),
      activeArchiveDocuments: _readInt(map['activeArchiveDocuments']),
      createdAt: _readDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: _readDate(map['updatedAt']) ?? DateTime.now(),
      hasArchivedRecipeCountAggregate: map.containsKey('archivedRecipeCount'),
      hasHasDpcAggregate: map.containsKey('hasDpc'),
      hasLastPrescriptionDateAggregate: map.containsKey('lastPrescriptionDate'),
      hasTherapiesSummaryAggregate: map.containsKey('therapiesSummary'),
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

  static List<String> _readStringList(dynamic value) {
    if (value == null) return const <String>[];
    if (value is List) {
      return value
          .map((dynamic item) => item.toString().trim())
          .where((String item) => item.isNotEmpty)
          .toList();
    }
    final String normalized = value.toString().trim();
    if (normalized.isEmpty) return const <String>[];
    return normalized
        .split(RegExp(r'[,;|\n]'))
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList();
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
      if (seconds is int) {
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    } catch (_) {}
    return null;
  }

  static double _readDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    final String normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'si' ||
        normalized == 'sì';
  }
}
