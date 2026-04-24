import 'advance.dart';
import 'booking.dart';
import 'debt.dart';
import 'drive_pdf_import.dart';
import 'patient.dart';

class DashboardSummary {
  final String id;
  final Patient patient;
  final List<DrivePdfImport> imports;
  final List<Debt> debts;
  final List<Advance> advances;
  final List<Booking> bookings;
  final bool hasDpc;
  final int recipeCount;
  final bool hasExpiryAlert;
  final DateTime? nextExpiryDate;
  final double debtsTotal;
  final int debtsCount;
  final int advancesCount;
  final int bookingsCount;
  final DateTime updatedAt;

  const DashboardSummary({
    required this.id,
    required this.patient,
    required this.imports,
    required this.debts,
    required this.advances,
    required this.bookings,
    required this.hasDpc,
    required this.recipeCount,
    required this.hasExpiryAlert,
    this.nextExpiryDate,
    required this.debtsTotal,
    required this.debtsCount,
    required this.advancesCount,
    required this.bookingsCount,
    required this.updatedAt,
  });

  factory DashboardSummary.fromMap(Map<String, dynamic> map) {
    final patientMap = <String, dynamic>{
      'fiscalCode': map['fiscalCode'] ?? map['patientFiscalCode'] ?? '',
      'fullName': map['fullName'] ?? map['patientFullName'] ?? '',
      'city': map['city'],
      'exemption': map['exemption'],
      'exemptionCode': map['exemptionCode'],
      'exemptions': map['exemptions'] ?? const <dynamic>[],
      'doctorFullName': map['doctorFullName'] ?? map['doctorName'],
      'doctorName': map['doctorFullName'] ?? map['doctorName'],
      'hasDebt': (map['debtsCount'] ?? 0) is num ? (map['debtsCount'] ?? 0) > 0 : false,
      'debtTotal': _readDouble(map['debtsTotal'] ?? map['debtTotal']),
      'hasBooking': (map['bookingsCount'] ?? 0) is num ? (map['bookingsCount'] ?? 0) > 0 : false,
      'hasAdvance': (map['advancesCount'] ?? 0) is num ? (map['advancesCount'] ?? 0) > 0 : false,
      'hasDpc': _readBool(map['hasDpc']),
      'archivedRecipeCount': _readInt(map['recipeCount']) ?? 0,
      'createdAt': map['createdAt'] ?? map['updatedAt'],
      'updatedAt': map['updatedAt'],
    };
    return DashboardSummary(
      id: (map['id'] ?? map['_id'] ?? '') as String,
      patient: Patient.fromMap(patientMap),
      imports: ((map['imports'] as List<dynamic>?) ?? const <dynamic>[]).map((dynamic item) => DrivePdfImport.fromMap(Map<String, dynamic>.from(item as Map))).toList(),
      debts: ((map['debts'] as List<dynamic>?) ?? const <dynamic>[]).map((dynamic item) => Debt.fromMap(Map<String, dynamic>.from(item as Map))).toList(),
      advances: ((map['advances'] as List<dynamic>?) ?? const <dynamic>[]).map((dynamic item) => Advance.fromMap(Map<String, dynamic>.from(item as Map))).toList(),
      bookings: ((map['bookings'] as List<dynamic>?) ?? const <dynamic>[]).map((dynamic item) => Booking.fromMap(Map<String, dynamic>.from(item as Map))).toList(),
      hasDpc: _readBool(map['hasDpc']),
      recipeCount: _readInt(map['recipeCount']) ?? 0,
      hasExpiryAlert: _readBool(map['hasExpiryAlert']),
      nextExpiryDate: _readDate(map['nextExpiryDate']),
      debtsTotal: _readDouble(map['debtsTotal'] ?? map['debtTotal']),
      debtsCount: _readInt(map['debtsCount']) ?? (((map['debts'] as List<dynamic>?) ?? const <dynamic>[]).length),
      advancesCount: _readInt(map['advancesCount']) ?? (((map['advances'] as List<dynamic>?) ?? const <dynamic>[]).length),
      bookingsCount: _readInt(map['bookingsCount']) ?? (((map['bookings'] as List<dynamic>?) ?? const <dynamic>[]).length),
      updatedAt: _readDate(map['updatedAt']) ?? DateTime.now(),
    );
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    final String normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == 'true' || normalized == '1' || normalized == 'yes' || normalized == 'si' || normalized == 'sì';
  }
  static int? _readInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }
  static double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
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
