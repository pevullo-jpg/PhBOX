import 'advance.dart';
import 'booking.dart';
import 'debt.dart';

class Patient {
  final String fiscalCode;
  final String fullName;
  final String? city;
  final String? exemption;
  final String? exemptionCode;
  final List<String> exemptions;
  final String? doctorName;
  final String? doctorSurname;
  final String? doctorFullName;
  final List<String> therapiesSummary;
  final DateTime? lastPrescriptionDate;
  final bool hasDebt;
  final double debtTotal;
  final bool hasBooking;
  final bool hasAdvance;
  final bool hasDpc;
  final int archivedRecipeCount;
  final int recipesCount;
  final int activeDebtsCount;
  final int activeBookingsCount;
  final int activeAdvancesCount;
  final double totalDebtAmount;
  final List<Advance> advances;
  final List<Booking> bookings;
  final List<Debt> debts;
  final List<Map<String, dynamic>> recipes;
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
    this.doctorSurname,
    this.doctorFullName,
    this.therapiesSummary = const <String>[],
    this.lastPrescriptionDate,
    this.hasDebt = false,
    this.debtTotal = 0,
    this.hasBooking = false,
    this.hasAdvance = false,
    this.hasDpc = false,
    this.archivedRecipeCount = 0,
    this.recipesCount = 0,
    this.activeDebtsCount = 0,
    this.activeBookingsCount = 0,
    this.activeAdvancesCount = 0,
    this.totalDebtAmount = 0,
    this.advances = const <Advance>[],
    this.bookings = const <Booking>[],
    this.debts = const <Debt>[],
    this.recipes = const <Map<String, dynamic>>[],
    required this.createdAt,
    required this.updatedAt,
  });

  Patient copyWith({
    String? fiscalCode, String? fullName, String? city, String? exemption, String? exemptionCode,
    List<String>? exemptions, String? doctorName, String? doctorSurname, String? doctorFullName,
    List<String>? therapiesSummary, DateTime? lastPrescriptionDate, bool? hasDebt, double? debtTotal,
    bool? hasBooking, bool? hasAdvance, bool? hasDpc, int? archivedRecipeCount, int? recipesCount,
    int? activeDebtsCount, int? activeBookingsCount, int? activeAdvancesCount, double? totalDebtAmount,
    List<Advance>? advances, List<Booking>? bookings, List<Debt>? debts, List<Map<String,dynamic>>? recipes,
    DateTime? createdAt, DateTime? updatedAt,
  }) => Patient(
    fiscalCode: fiscalCode ?? this.fiscalCode,
    fullName: fullName ?? this.fullName,
    city: city ?? this.city,
    exemption: exemption ?? this.exemption,
    exemptionCode: exemptionCode ?? this.exemptionCode,
    exemptions: exemptions ?? this.exemptions,
    doctorName: doctorName ?? this.doctorName,
    doctorSurname: doctorSurname ?? this.doctorSurname,
    doctorFullName: doctorFullName ?? this.doctorFullName,
    therapiesSummary: therapiesSummary ?? this.therapiesSummary,
    lastPrescriptionDate: lastPrescriptionDate ?? this.lastPrescriptionDate,
    hasDebt: hasDebt ?? this.hasDebt,
    debtTotal: debtTotal ?? this.debtTotal,
    hasBooking: hasBooking ?? this.hasBooking,
    hasAdvance: hasAdvance ?? this.hasAdvance,
    hasDpc: hasDpc ?? this.hasDpc,
    archivedRecipeCount: archivedRecipeCount ?? this.archivedRecipeCount,
    recipesCount: recipesCount ?? this.recipesCount,
    activeDebtsCount: activeDebtsCount ?? this.activeDebtsCount,
    activeBookingsCount: activeBookingsCount ?? this.activeBookingsCount,
    activeAdvancesCount: activeAdvancesCount ?? this.activeAdvancesCount,
    totalDebtAmount: totalDebtAmount ?? this.totalDebtAmount,
    advances: advances ?? this.advances,
    bookings: bookings ?? this.bookings,
    debts: debts ?? this.debts,
    recipes: recipes ?? this.recipes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  String? get currentExemption {
    final String resolved = _normalizeString(exemption).isNotEmpty
        ? _normalizeString(exemption).toUpperCase()
        : (_normalizeString(exemptionCode).isNotEmpty
            ? _normalizeString(exemptionCode).toUpperCase()
            : (normalizedExemptions.isEmpty ? '' : normalizedExemptions.first));
    return resolved.isEmpty ? null : resolved;
  }

  List<String> get normalizedExemptions => normalizeExemptionValues(<dynamic>[...exemptions, exemption, exemptionCode]);
  String get exemptionsDisplay => normalizedExemptions.isEmpty ? '-' : normalizedExemptions.join(', ');

  Map<String, dynamic> toMap() {
    final String? current = currentExemption;
    return <String, dynamic>{
      'id': fiscalCode,
      'fiscalCode': fiscalCode,
      'fullName': fullName,
      'city': city,
      'exemption': current,
      'exemptionCode': current,
      'exemptions': normalizedExemptions,
      'doctorFullName': doctorFullName ?? doctorName,
      'doctorName': doctorName,
      'doctorSurname': doctorSurname,
      'therapiesSummary': therapiesSummary,
      'lastPrescriptionDate': lastPrescriptionDate?.toIso8601String(),
      'hasDebt': hasDebt,
      'debtTotal': debtTotal,
      'hasBooking': hasBooking,
      'hasAdvance': hasAdvance,
      'hasDpc': hasDpc,
      'archivedRecipeCount': archivedRecipeCount,
      'recipesCount': recipesCount,
      'activeDebtsCount': activeDebtsCount,
      'activeBookingsCount': activeBookingsCount,
      'activeAdvancesCount': activeAdvancesCount,
      'totalDebtAmount': totalDebtAmount,
      'advances': advances.map((e) => e.toMap()).toList(),
      'bookings': bookings.map((e) => e.toMap()).toList(),
      'debts': debts.map((e) => e.toMap()).toList(),
      'recipes': recipes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Patient.fromMap(Map<String, dynamic> map) {
    final List<String> exemptions = normalizeExemptionValues(<dynamic>[..._readCollection(map['exemptions']), map['exemption'], map['exemptionCode'], map['esenzione']]);
    final String? currentExemption = _firstNonEmpty(<dynamic>[map['exemption'], map['exemptionCode'], map['esenzione'], exemptions.isEmpty ? null : exemptions.first])?.toUpperCase();
    final List<Advance> advances = _readCollection(map['advances']).whereType<Map>().map((e) => Advance.fromMap(Map<String,dynamic>.from(e as Map))).toList();
    final List<Booking> bookings = _readCollection(map['bookings']).whereType<Map>().map((e) => Booking.fromMap(Map<String,dynamic>.from(e as Map))).toList();
    final List<Debt> debts = _readCollection(map['debts']).whereType<Map>().map((e) => Debt.fromMap(Map<String,dynamic>.from(e as Map))).toList();
    final List<Map<String,dynamic>> recipes = _readCollection(map['recipes']).whereType<Map>().map((e) => Map<String,dynamic>.from(e as Map)).toList();
    final String doctorFull = _nullIfEmpty(map['doctorFullName'] ?? map['doctorName'] ?? map['doctor'] ?? map['medico']) ?? '';
    return Patient(
      fiscalCode: _normalizeString(map['fiscalCode'] ?? map['id']),
      fullName: _normalizeString(map['fullName']),
      city: _nullIfEmpty(map['city']),
      exemption: currentExemption,
      exemptionCode: currentExemption,
      exemptions: exemptions,
      doctorName: _nullIfEmpty(map['doctorName']) ?? (doctorFull.isEmpty ? null : doctorFull),
      doctorSurname: _nullIfEmpty(map['doctorSurname']),
      doctorFullName: doctorFull.isEmpty ? null : doctorFull,
      therapiesSummary: List<String>.from(map['therapiesSummary'] ?? const <String>[]),
      lastPrescriptionDate: _readDate(map['lastPrescriptionDate']),
      hasDebt: (map['hasDebt'] ?? debts.isNotEmpty) as bool,
      debtTotal: _readDouble(map['debtTotal'] ?? map['totalDebtAmount']),
      hasBooking: (map['hasBooking'] ?? bookings.isNotEmpty) as bool,
      hasAdvance: (map['hasAdvance'] ?? advances.isNotEmpty) as bool,
      hasDpc: (map['hasDpc'] ?? false) as bool,
      archivedRecipeCount: (map['archivedRecipeCount'] ?? map['recipesCount'] ?? recipes.length) as int,
      recipesCount: (map['recipesCount'] ?? map['archivedRecipeCount'] ?? recipes.length) as int,
      activeDebtsCount: (map['activeDebtsCount'] ?? debts.length) as int,
      activeBookingsCount: (map['activeBookingsCount'] ?? bookings.length) as int,
      activeAdvancesCount: (map['activeAdvancesCount'] ?? advances.length) as int,
      totalDebtAmount: _readDouble(map['totalDebtAmount'] ?? map['debtTotal']),
      advances: advances,
      bookings: bookings,
      debts: debts,
      recipes: recipes,
      createdAt: _readDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: _readDate(map['updatedAt']) ?? DateTime.now(),
    );
  }

  static List<String> normalizeExemptionValues(Iterable<dynamic> values) {
    final Set<String> normalized = <String>{};
    for (final dynamic value in values) {
      final String cleaned = _normalizeString(value).toUpperCase();
      if (cleaned.isNotEmpty) normalized.add(cleaned);
    }
    return normalized.toList()..sort();
  }

  static List<dynamic> _readCollection(dynamic value) => value is Iterable ? value.toList() : const <dynamic>[];
  static String _normalizeString(dynamic value) => value == null ? '' : value.toString().trim();
  static String? _nullIfEmpty(dynamic value) { final s = _normalizeString(value); return s.isEmpty ? null : s; }
  static String? _firstNonEmpty(Iterable<dynamic> values) { for (final v in values) { final s = _normalizeString(v); if (s.isNotEmpty) return s; } return null; }
  static DateTime? _readDate(dynamic value) { if (value == null) return null; if (value is DateTime) return value; if (value is String && value.isNotEmpty) return DateTime.tryParse(value); if (value is int) return DateTime.fromMillisecondsSinceEpoch(value); try { final d = (value as dynamic).toDate(); if (d is DateTime) return d; } catch (_) {} try { final s = (value as dynamic).seconds; if (s is int) return DateTime.fromMillisecondsSinceEpoch(s * 1000); } catch (_) {} return null; }
  static double _readDouble(dynamic value) { if (value == null) return 0; if (value is num) return value.toDouble(); return double.tryParse(value.toString()) ?? 0; }
}
