class MonthlySnapshot {
  final String id;
  final int year;
  final int month;

  final double totalIncome;
  final double totalExpenses;
  final double monthlyBalance;

  final double totalBoxesBalance;
  final double totalFundsBalance;

  final double savingsBoxBalance;
  final double subscriptionsBoxBalance;

  final Map<String, double> groupTotals;

  MonthlySnapshot({
    required this.id,
    required this.year,
    required this.month,
    required this.totalIncome,
    required this.totalExpenses,
    required this.monthlyBalance,
    required this.totalBoxesBalance,
    required this.totalFundsBalance,
    required this.savingsBoxBalance,
    required this.subscriptionsBoxBalance,
    required this.groupTotals,
  });

  factory MonthlySnapshot.fromJson(Map<String, dynamic> json) {
    final rawGroups = (json['groupTotals'] as Map?) ?? {};

    return MonthlySnapshot(
      id: (json['id'] ?? '').toString(),
      year: (json['year'] ?? 0) is int
          ? json['year'] as int
          : int.tryParse(json['year'].toString()) ?? 0,
      month: (json['month'] ?? 0) is int
          ? json['month'] as int
          : int.tryParse(json['month'].toString()) ?? 0,
      totalIncome: ((json['totalIncome'] ?? 0) as num).toDouble(),
      totalExpenses: ((json['totalExpenses'] ?? 0) as num).toDouble(),
      monthlyBalance: ((json['monthlyBalance'] ?? 0) as num).toDouble(),
      totalBoxesBalance: ((json['totalBoxesBalance'] ?? 0) as num).toDouble(),
      totalFundsBalance: ((json['totalFundsBalance'] ?? 0) as num).toDouble(),
      savingsBoxBalance: ((json['savingsBoxBalance'] ?? 0) as num).toDouble(),
      subscriptionsBoxBalance:
          ((json['subscriptionsBoxBalance'] ?? 0) as num).toDouble(),
      groupTotals: rawGroups.map(
        (key, value) => MapEntry(
          key.toString(),
          (value as num).toDouble(),
        ),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'year': year,
      'month': month,
      'totalIncome': totalIncome,
      'totalExpenses': totalExpenses,
      'monthlyBalance': monthlyBalance,
      'totalBoxesBalance': totalBoxesBalance,
      'totalFundsBalance': totalFundsBalance,
      'savingsBoxBalance': savingsBoxBalance,
      'subscriptionsBoxBalance': subscriptionsBoxBalance,
      'groupTotals': groupTotals,
    };
  }
}
