class DashboardTotalsSnapshot {
  final int recipeCount;
  final int dpcCount;
  final double debtAmount;
  final int advanceCount;
  final int bookingCount;
  final int expiringCount;
  final DateTime? updatedAt;

  const DashboardTotalsSnapshot({
    required this.recipeCount,
    required this.dpcCount,
    required this.debtAmount,
    required this.advanceCount,
    required this.bookingCount,
    required this.expiringCount,
    this.updatedAt,
  });

  factory DashboardTotalsSnapshot.fromMap(Map<String, dynamic> map) {
    return DashboardTotalsSnapshot(
      recipeCount: _readIntFirst(map, const <String>[
        'recipeCount',
        'recipesCount',
        'prescriptionCount',
        'prescriptionsCount',
        'totalRecipes',
        'totalPrescriptions',
        'ricette',
      ]),
      dpcCount: _readIntFirst(map, const <String>[
        'dpcCount',
        'dpcTotal',
        'totalDpc',
        'totalDPC',
        'dpc',
      ]),
      debtAmount: _readDoubleFirst(map, const <String>[
        'debtAmount',
        'debtsTotal',
        'debtTotal',
        'totalDebtAmount',
        'totalDebts',
        'debiti',
      ]),
      advanceCount: _readIntFirst(map, const <String>[
        'advanceCount',
        'advancesCount',
        'totalAdvances',
        'anticipi',
      ]),
      bookingCount: _readIntFirst(map, const <String>[
        'bookingCount',
        'bookingsCount',
        'totalBookings',
        'prenotazioni',
      ]),
      expiringCount: _readIntFirst(map, const <String>[
        'expiringCount',
        'expiryCount',
        'expiriesCount',
        'expiringRecipesCount',
        'scadenze',
      ]),
      updatedAt: _readDate(map['updatedAt'] ?? map['generatedAt'] ?? map['createdAt']),
    );
  }

  static int _readIntFirst(Map<String, dynamic> map, List<String> keys) {
    for (final String key in keys) {
      final int? value = _readInt(map[key]);
      if (value != null) {
        return value;
      }
    }
    return 0;
  }

  static double _readDoubleFirst(Map<String, dynamic> map, List<String> keys) {
    for (final String key in keys) {
      final double? value = _readDouble(map[key]);
      if (value != null) {
        return value;
      }
    }
    return 0;
  }

  static int? _readInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }

  static double? _readDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim().replaceAll(',', '.'));
  }

  static DateTime? _readDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    try {
      final dynamic converted = (value as dynamic).toDate();
      if (converted is DateTime) {
        return converted;
      }
    } catch (_) {}
    return null;
  }
}
