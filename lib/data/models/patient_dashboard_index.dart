import 'patient.dart';

class PatientDashboardIndex {
  final String id;
  final String fiscalCode;
  final String fullName;
  final String? alias;
  final String doctorFullName;
  final String city;
  final String exemptionCode;
  final List<String> exemptions;
  final String familyId;
  final String familyName;
  final int familyColorIndex;
  final int recipeCount;
  final int dpcCount;
  final double debtAmount;
  final int debtCount;
  final int advanceCount;
  final int bookingCount;
  final DateTime? nearestExpiryDate;
  final bool hasRecipes;
  final bool hasDpc;
  final bool hasDebt;
  final bool hasAdvance;
  final bool hasBooking;
  final bool hasExpiry;
  final List<String> searchPrefixes;
  final DateTime updatedAt;

  const PatientDashboardIndex({
    required this.id,
    required this.fiscalCode,
    required this.fullName,
    this.alias,
    required this.doctorFullName,
    required this.city,
    required this.exemptionCode,
    required this.exemptions,
    required this.familyId,
    required this.familyName,
    required this.familyColorIndex,
    required this.recipeCount,
    required this.dpcCount,
    required this.debtAmount,
    required this.debtCount,
    required this.advanceCount,
    required this.bookingCount,
    this.nearestExpiryDate,
    required this.hasRecipes,
    required this.hasDpc,
    required this.hasDebt,
    required this.hasAdvance,
    required this.hasBooking,
    required this.hasExpiry,
    required this.searchPrefixes,
    required this.updatedAt,
  });

  Patient toPatient() {
    final DateTime now = DateTime.now();
    return Patient(
      fiscalCode: fiscalCode,
      fullName: fullName.trim().isEmpty ? fiscalCode : fullName.trim(),
      alias: alias,
      city: city.trim().isEmpty ? null : city.trim(),
      exemptionCode: exemptionCode.trim().isEmpty ? null : exemptionCode.trim(),
      exemptions: exemptions,
      doctorName: doctorFullName.trim().isEmpty ? null : doctorFullName.trim(),
      lastPrescriptionDate: nearestExpiryDate == null
          ? null
          : nearestExpiryDate!.subtract(const Duration(days: 30)),
      hasDebt: hasDebt,
      debtTotal: debtAmount,
      hasBooking: hasBooking,
      hasAdvance: hasAdvance,
      hasDpc: hasDpc,
      archivedRecipeCount: recipeCount,
      createdAt: updatedAt,
      updatedAt: now,
      hasArchivedRecipeCountAggregate: true,
      hasHasDpcAggregate: true,
      hasLastPrescriptionDateAggregate: nearestExpiryDate != null,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'fiscalCode': fiscalCode,
      'fullName': fullName,
      'alias': alias,
      'doctorFullName': doctorFullName,
      'city': city,
      'exemptionCode': exemptionCode,
      'exemptions': exemptions,
      'familyId': familyId,
      'familyName': familyName,
      'familyColorIndex': familyColorIndex,
      'recipeCount': recipeCount,
      'dpcCount': dpcCount,
      'debtAmount': debtAmount,
      'debtCount': debtCount,
      'advanceCount': advanceCount,
      'bookingCount': bookingCount,
      'nearestExpiryDate': nearestExpiryDate?.toIso8601String(),
      'hasRecipes': hasRecipes,
      'hasDpc': hasDpc,
      'hasDebt': hasDebt,
      'hasAdvance': hasAdvance,
      'hasBooking': hasBooking,
      'hasExpiry': hasExpiry,
      'searchPrefixes': searchPrefixes,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory PatientDashboardIndex.fromMap(Map<String, dynamic> map) {
    final String cf = _readString(map['fiscalCode'] ?? map['patientFiscalCode'] ?? map['id']).toUpperCase();
    final int recipeCount = _readInt(map['recipeCount']);
    final int dpcCount = _readInt(map['dpcCount']);
    final double debtAmount = _readDouble(map['debtAmount'] ?? map['debtTotal'] ?? map['debtsTotal']);
    final int debtCount = _readInt(map['debtCount'] ?? map['debtsCount']);
    final int advanceCount = _readInt(map['advanceCount'] ?? map['advancesCount']);
    final int bookingCount = _readInt(map['bookingCount'] ?? map['bookingsCount']);
    return PatientDashboardIndex(
      id: _readString(map['id']).isEmpty ? cf : _readString(map['id']),
      fiscalCode: cf,
      fullName: _readString(map['fullName'] ?? map['patientFullName']),
      alias: _readNullableString(map['alias']),
      doctorFullName: _readString(map['doctorFullName'] ?? map['doctorName']),
      city: _readString(map['city']),
      exemptionCode: _readString(map['exemptionCode'] ?? map['exemption']),
      exemptions: _readStringList(map['exemptions']),
      familyId: _readString(map['familyId']),
      familyName: _readString(map['familyName']),
      familyColorIndex: _readInt(map['familyColorIndex']),
      recipeCount: recipeCount,
      dpcCount: dpcCount,
      debtAmount: debtAmount,
      debtCount: debtCount,
      advanceCount: advanceCount,
      bookingCount: bookingCount,
      nearestExpiryDate: _readDate(map['nearestExpiryDate'] ?? map['expiryDate']),
      hasRecipes: _readBool(map['hasRecipes']) || recipeCount > 0,
      hasDpc: _readBool(map['hasDpc']) || dpcCount > 0,
      hasDebt: _readBool(map['hasDebt']) || debtAmount.abs() > 0.005 || debtCount > 0,
      hasAdvance: _readBool(map['hasAdvance']) || advanceCount > 0,
      hasBooking: _readBool(map['hasBooking']) || bookingCount > 0,
      hasExpiry: _readBool(map['hasExpiry']),
      searchPrefixes: _readStringList(map['searchPrefixes']),
      updatedAt: _readDate(map['updatedAt']) ?? DateTime.now(),
    );
  }

  static String _readString(dynamic value) => value == null ? '' : value.toString().trim();

  static String? _readNullableString(dynamic value) {
    final String text = _readString(value);
    return text.isEmpty ? null : text;
  }

  static List<String> _readStringList(dynamic value) {
    if (value is List) {
      return value.map((dynamic item) => _readString(item)).where((String item) => item.isNotEmpty).toList();
    }
    return const <String>[];
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    final String text = _readString(value).toLowerCase();
    return text == 'true' || text == '1' || text == 'yes' || text == 'si' || text == 'sì';
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(_readString(value)) ?? 0;
  }

  static double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(_readString(value).replaceAll(',', '.')) ?? 0;
  }

  static DateTime? _readDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    final String text = _readString(value);
    if (text.isNotEmpty) {
      final DateTime? parsed = DateTime.tryParse(text);
      if (parsed != null) return parsed;
    }
    try {
      final dynamic date = (value as dynamic).toDate();
      if (date is DateTime) return date;
    } catch (_) {}
    return null;
  }
}
