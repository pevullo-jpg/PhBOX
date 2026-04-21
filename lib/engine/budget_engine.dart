import 'package:family_boxes_2/models/app_category.dart';
import 'package:family_boxes_2/models/app_data.dart';
import 'package:family_boxes_2/models/box.dart';
import 'package:family_boxes_2/models/cashflow.dart';
import 'package:family_boxes_2/models/fund.dart';
import 'package:family_boxes_2/models/monthly_snapshot.dart';
import 'package:family_boxes_2/models/recurring.dart';
import 'package:family_boxes_2/models/recurring_group.dart';
import 'package:family_boxes_2/models/transaction.dart';


class BudgetConsistencyLine {
  final String transactionId;
  final String category;
  final String note;
  final DateTime date;
  final double amount;
  final bool confirmed;
  final String scope;

  const BudgetConsistencyLine({
    required this.transactionId,
    required this.category,
    required this.note,
    required this.date,
    required this.amount,
    required this.confirmed,
    required this.scope,
  });
}

class BudgetConsistencyReport {
  final double totalBoxes;
  final double totalFunds;
  final double delta;
  final List<BudgetConsistencyLine> boxOnlyTransactions;
  final List<BudgetConsistencyLine> fundOnlyTransactions;
  final DateTime? lastAlignmentDate;
  final int ignoredHistoricalTransactionsCount;

  const BudgetConsistencyReport({
    required this.totalBoxes,
    required this.totalFunds,
    required this.delta,
    required this.boxOnlyTransactions,
    required this.fundOnlyTransactions,
    required this.lastAlignmentDate,
    required this.ignoredHistoricalTransactionsCount,
  });

  bool isAligned([double tolerance = 0.01]) {
    return delta.abs() <= tolerance;
  }
}

class _BudgetConsistencyEntry {
  final TransactionModel transaction;
  final BudgetConsistencyLine line;
  final double contribution;

  const _BudgetConsistencyEntry({
    required this.transaction,
    required this.line,
    required this.contribution,
  });
}

class ReadOnlyWriteBlockedException implements Exception {
  final String operation;

  const ReadOnlyWriteBlockedException(this.operation);

  @override
  String toString() => 'ReadOnlyWriteBlockedException($operation)';
}

class BudgetEngine {
  AppData data;
  bool _writesLocked = false;

  BudgetEngine({
    required this.data,
  });

  factory BudgetEngine.empty() {
    return BudgetEngine(data: AppData.empty());
  }

  AppData exportData() => data;

  bool get writesLocked => _writesLocked;
  bool get canWrite => !_writesLocked;

  void setWritesLocked(bool value) {
    _writesLocked = value;
  }

  void _assertWritable(String operation) {
    if (_writesLocked) {
      throw ReadOnlyWriteBlockedException(operation);
    }
  }

  void replaceData(AppData newData) {
    _assertWritable('replace_data');
    data = newData;
  }

  List<BoxModel> get boxes => data.boxes;
  List<Fund> get funds => data.funds;
  List<TransactionModel> get transactions => data.transactions;
  List<Recurring> get recurring => data.recurring;
  List<Cashflow> get cashflows => data.cashflows;
  List<RecurringGroup> get recurringGroups => data.recurringGroups;
  List<AppCategory> get categories => data.categories;
  List<MonthlySnapshot> get monthlySnapshots => data.monthlySnapshots;

  String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  DateTime get now => DateTime.now();

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime get _todayOnly => _dateOnly(now);

  bool _isDue(DateTime date) => !_dateOnly(date).isAfter(_todayOnly);

  bool _sameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  bool _sameOrAfter(DateTime a, DateTime b) {
    return !_dateOnly(a).isBefore(_dateOnly(b));
  }

  bool _isRecurringActiveOnDate(Recurring r, DateTime dueDate) {
    if (!_sameOrAfter(dueDate, r.startDate)) {
      return false;
    }

    final duration = r.durationMonths;
    if (duration == null || duration <= 0) {
      return true;
    }

    final startMonth = DateTime(r.startDate.year, r.startDate.month, 1);
    final dueMonth = DateTime(dueDate.year, dueDate.month, 1);

    final diffMonths = (dueMonth.year - startMonth.year) * 12 +
        (dueMonth.month - startMonth.month);

    return diffMonths >= 0 && diffMonths < duration;
  }

  String boxName(String? id) {
    try {
      return boxes.firstWhere((e) => e.id == id).name;
    } catch (_) {
      return '';
    }
  }

  String fundName(String? id) {
    try {
      return funds.firstWhere((e) => e.id == id).name;
    } catch (_) {
      return '';
    }
  }

  String groupName(String? id) {
    try {
      return recurringGroups.firstWhere((e) => e.id == id).name;
    } catch (_) {
      return '';
    }
  }

  String categoryName(String? id) {
    try {
      return categories.firstWhere((e) => e.id == id).name;
    } catch (_) {
      return '';
    }
  }

  String transactionScope(TransactionModel t) {
    final parts = <String>[];
    final fund = fundName(t.fundId);
    final box = boxName(t.boxId);

    if (fund.isNotEmpty) {
      parts.add(fund);
    }
    if (box.isNotEmpty) {
      parts.add(box);
    }

    return parts.isEmpty ? 'Nessun fondo/box' : parts.join(' • ');
  }

  void addBox(BoxModel box) {
    _assertWritable('add_box');
    boxes.add(box);
  }

  void updateBox(BoxModel box) {
    _assertWritable('update_box');
    final i = boxes.indexWhere((e) => e.id == box.id);
    if (i >= 0) {
      boxes[i] = box;
    }
  }

  void deleteBox(String id) {
    _assertWritable('delete_box');
    boxes.removeWhere((e) => e.id == id);

    for (final t in transactions) {
      if (t.boxId == id) {
        t.boxId = null;
      }
    }

    for (final r in recurring) {
      if (r.boxId == id) {
        r.boxId = null;
      }
    }

    for (final c in cashflows) {
      if (c.isBoxFlow) {
        if (c.sourceId == id) {
          c.sourceId = '';
        }
        if (c.destinationId == id) {
          c.destinationId = '';
        }
      }
    }
  }

  void addFund(Fund fund) {
    _assertWritable('add_fund');
    funds.add(fund);
  }

  void updateFund(Fund fund) {
    _assertWritable('update_fund');
    final i = funds.indexWhere((e) => e.id == fund.id);
    if (i >= 0) {
      funds[i] = fund;
    }
  }

  void deleteFund(String id) {
    _assertWritable('delete_fund');
    funds.removeWhere((e) => e.id == id);

    for (final t in transactions) {
      if (t.fundId == id) {
        t.fundId = null;
      }
    }

    for (final r in recurring) {
      if (r.fundId == id) {
        r.fundId = null;
      }
    }

    for (final c in cashflows) {
      if (!c.isBoxFlow) {
        if (c.sourceId == id) {
          c.sourceId = '';
        }
        if (c.destinationId == id) {
          c.destinationId = '';
        }
      }
    }
  }

  void addCategory(AppCategory category) {
    _assertWritable('add_category');
    categories.add(category);
  }

  void updateCategory(AppCategory category) {
    _assertWritable('update_category');
    final i = categories.indexWhere((e) => e.id == category.id);
    if (i >= 0) {
      categories[i] = category;
    }
  }

  void deleteCategory(String id) {
    _assertWritable('delete_category');
    categories.removeWhere((e) => e.id == id);
  }

  void addRecurringGroup(RecurringGroup group) {
    _assertWritable('add_recurring_group');
    recurringGroups.add(group);
  }

  void updateRecurringGroup(RecurringGroup group) {
    _assertWritable('update_recurring_group');
    final i = recurringGroups.indexWhere((e) => e.id == group.id);
    if (i >= 0) {
      recurringGroups[i] = group;
    }
  }

  void deleteRecurringGroup(String id) {
    _assertWritable('delete_recurring_group');
    recurringGroups.removeWhere((e) => e.id == id);

    for (final r in recurring) {
      if (r.groupId == id) {
        r.groupId = null;
      }
    }
  }

  void addTransaction(TransactionModel transaction) {
    _assertWritable('add_transaction');
    transactions.add(transaction);
  }

  void updateTransaction(TransactionModel transaction) {
    _assertWritable('update_transaction');
    final i = transactions.indexWhere((e) => e.id == transaction.id);
    if (i >= 0) {
      transactions[i] = transaction;
    }
  }

  void deleteTransaction(String id) {
    _assertWritable('delete_transaction');
    transactions.removeWhere((e) => e.id == id);
  }

  void confirmTransaction(String id) {
    _assertWritable('confirm_transaction');
    final i = transactions.indexWhere((e) => e.id == id);
    if (i >= 0) {
      transactions[i].confirmed = true;
    }
  }

  void addRecurring(Recurring item) {
    _assertWritable('add_recurring');
    recurring.add(item);
  }

  void updateRecurring(Recurring item) {
    _assertWritable('update_recurring');
    final i = recurring.indexWhere((e) => e.id == item.id);
    if (i >= 0) {
      recurring[i] = item;
    }
  }

  void deleteRecurring(String id) {
    _assertWritable('delete_recurring');
    recurring.removeWhere((e) => e.id == id);
    transactions.removeWhere((t) => t.recurringId == id && !t.confirmed);
  }

  void addCashflow(Cashflow item) {
    _assertWritable('add_cashflow');
    cashflows.add(item);
  }

  void updateCashflow(Cashflow item) {
    _assertWritable('update_cashflow');
    final i = cashflows.indexWhere((e) => e.id == item.id);
    if (i >= 0) {
      cashflows[i] = item;
    }
  }

  void deleteCashflow(String id) {
    _assertWritable('delete_cashflow');
    cashflows.removeWhere((e) => e.id == id);
  }

  List<TransactionModel> sortedTransactionsDesc() {
    final list = [...transactions];
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  List<TransactionModel> latestTransactions([int limit = 10]) {
    final list = [...transactions]..sort((a, b) => b.date.compareTo(a.date));
    return list.take(limit).toList();
  }

  List<TransactionModel> latestConfirmedTransactions([int limit = 10]) {
    final list = transactions.where((e) => e.confirmed).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list.take(limit).toList();
  }

  List<TransactionModel> pendingTransactions() {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    final list = transactions.where((e) {
      final txDateOnly = DateTime(e.date.year, e.date.month, e.date.day);
      return !e.confirmed && !txDateOnly.isAfter(todayOnly);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return list;
  }

  List<TransactionModel> transactionsByBox(String boxId) {
    final list = transactions.where((e) => e.boxId == boxId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  List<TransactionModel> transactionsByFund(String fundId) {
    final list = transactions.where((e) => e.fundId == fundId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  bool _isWithinTargetMonth(DateTime date, DateTime targetMonth) {
    return date.year == targetMonth.year && date.month == targetMonth.month;
  }

  double _entityCurrentBalance({
    required double initialAmount,
    required String entityId,
    required bool Function(TransactionModel transaction, String entityId)
        matchesEntity,
  }) {
    double total = initialAmount;

    for (final t in transactions) {
      if (!matchesEntity(t, entityId)) continue;
      if (!t.confirmed) continue;
      if (!_isDue(t.date)) continue;
      total += t.amount;
    }

    return total;
  }

  double _entityProjectedEndOfCurrentMonthBalance({
    required double initialAmount,
    required String entityId,
    required bool Function(TransactionModel transaction, String entityId)
        matchesEntity,
  }) {
    double total = _entityCurrentBalance(
      initialAmount: initialAmount,
      entityId: entityId,
      matchesEntity: matchesEntity,
    );

    final currentMonth = DateTime(now.year, now.month, 1);

    for (final t in transactions) {
      if (!matchesEntity(t, entityId)) continue;
      if (!_isWithinTargetMonth(t.date, currentMonth)) continue;
      if (t.confirmed && _isDue(t.date)) continue;
      if (_isDue(t.date) && !t.confirmed) continue;
      total += t.amount;
    }

    return total;
  }

  double _entityBalanceAtMonthEnd({
    required double initialAmount,
    required String entityId,
    required DateTime targetMonth,
    required bool Function(TransactionModel transaction, String entityId)
        matchesEntity,
  }) {
    double total = initialAmount;
    final monthEnd = DateTime(targetMonth.year, targetMonth.month + 1, 0);

    for (final t in transactions) {
      if (!matchesEntity(t, entityId)) continue;
      if (_dateOnly(t.date).isAfter(monthEnd)) continue;
      total += t.amount;
    }

    return total;
  }

  double boxCurrentBalance(String boxId) {
    final box = boxes.firstWhere((e) => e.id == boxId);
    return _entityCurrentBalance(
      initialAmount: box.initialAmount,
      entityId: boxId,
      matchesEntity: (t, id) => t.boxId == id,
    );
  }

  double fundCurrentBalance(String fundId) {
    final fund = funds.firstWhere((e) => e.id == fundId);
    return _entityCurrentBalance(
      initialAmount: fund.initialAmount,
      entityId: fundId,
      matchesEntity: (t, id) => t.fundId == id,
    );
  }

  double boxEndMonthBalance(String boxId) {
    final box = boxes.firstWhere((e) => e.id == boxId);
    return _entityProjectedEndOfCurrentMonthBalance(
      initialAmount: box.initialAmount,
      entityId: boxId,
      matchesEntity: (t, id) => t.boxId == id,
    );
  }

  double fundEndMonthBalance(String fundId) {
    final fund = funds.firstWhere((e) => e.id == fundId);
    return _entityProjectedEndOfCurrentMonthBalance(
      initialAmount: fund.initialAmount,
      entityId: fundId,
      matchesEntity: (t, id) => t.fundId == id,
    );
  }

  double totalBoxesNow() =>
      boxes.fold(0.0, (sum, e) => sum + boxCurrentBalance(e.id));

  double totalFundsNow() =>
      funds.fold(0.0, (sum, e) => sum + fundCurrentBalance(e.id));

  double totalBoxesEndMonth() =>
      boxes.fold(0.0, (sum, e) => sum + boxEndMonthBalance(e.id));

  double totalFundsEndMonth() =>
      funds.fold(0.0, (sum, e) => sum + fundEndMonthBalance(e.id));

  BudgetConsistencyLine _consistencyLine(TransactionModel transaction) {
    return BudgetConsistencyLine(
      transactionId: transaction.id,
      category: transaction.category,
      note: transaction.note,
      date: transaction.date,
      amount: transaction.amount,
      confirmed: transaction.confirmed,
      scope: transactionScope(transaction),
    );
  }

  double _initialSystemDelta() {
    final initialBoxes = boxes.fold<double>(
      0.0,
      (sum, box) => sum + box.initialAmount,
    );
    final initialFunds = funds.fold<double>(
      0.0,
      (sum, fund) => sum + fund.initialAmount,
    );
    return initialBoxes - initialFunds;
  }

  bool _hasBoxSide(TransactionModel transaction) {
    return transaction.boxId != null && transaction.boxId!.isNotEmpty;
  }

  bool _hasFundSide(TransactionModel transaction) {
    return transaction.fundId != null && transaction.fundId!.isNotEmpty;
  }

  bool _isBoxOnlyTransaction(TransactionModel transaction) {
    return _hasBoxSide(transaction) && !_hasFundSide(transaction);
  }

  bool _isFundOnlyTransaction(TransactionModel transaction) {
    return !_hasBoxSide(transaction) && _hasFundSide(transaction);
  }

  double _consistencyContribution(TransactionModel transaction) {
    if (_isBoxOnlyTransaction(transaction)) {
      return transaction.amount;
    }
    if (_isFundOnlyTransaction(transaction)) {
      return -transaction.amount;
    }
    return 0.0;
  }

  bool _isIncludedInCurrentBalance(TransactionModel transaction) {
    return transaction.confirmed && _isDue(transaction.date);
  }

  bool _isIncludedInEndOfCurrentMonthTotals(TransactionModel transaction) {
    if (_isIncludedInCurrentBalance(transaction)) {
      return true;
    }

    final currentMonth = DateTime(now.year, now.month, 1);
    if (!_isWithinTargetMonth(transaction.date, currentMonth)) {
      return false;
    }

    return !_isDue(transaction.date);
  }

  bool _isRelevantForNowConsistency(TransactionModel transaction) {
    return _isIncludedInCurrentBalance(transaction);
  }

  bool _isRelevantForEndMonthConsistency(TransactionModel transaction) {
    return _isIncludedInEndOfCurrentMonthTotals(transaction);
  }

  List<_BudgetConsistencyEntry> _relevantConsistencyEntries({
    required bool Function(TransactionModel transaction) includeTransaction,
  }) {
    final entries = <_BudgetConsistencyEntry>[];

    for (final transaction in transactions) {
      if (!includeTransaction(transaction)) continue;

      final contribution = _consistencyContribution(transaction);
      if (contribution.abs() <= 0.0000001) {
        continue;
      }

      entries.add(
        _BudgetConsistencyEntry(
          transaction: transaction,
          line: _consistencyLine(transaction),
          contribution: contribution,
        ),
      );
    }

    entries.sort((a, b) {
      final byDate = a.transaction.date.compareTo(b.transaction.date);
      if (byDate != 0) return byDate;
      return a.transaction.id.compareTo(b.transaction.id);
    });

    return entries;
  }

  BudgetConsistencyReport _buildConsistencyReport({
    required double totalBoxes,
    required double totalFunds,
    required bool Function(TransactionModel transaction) includeTransaction,
    double tolerance = 0.01,
  }) {
    final entries = _relevantConsistencyEntries(
      includeTransaction: includeTransaction,
    );

    var runningDelta = _initialSystemDelta();
    var lastAlignmentIndexExclusive = 0;
    DateTime? lastAlignmentDate;

    for (var i = 0; i < entries.length; i++) {
      runningDelta += entries[i].contribution;

      if (runningDelta.abs() <= tolerance) {
        lastAlignmentIndexExclusive = i + 1;
        lastAlignmentDate = entries[i].transaction.date;
      }
    }

    final residualEntries = entries.sublist(lastAlignmentIndexExclusive);
    final boxOnly = <BudgetConsistencyLine>[];
    final fundOnly = <BudgetConsistencyLine>[];

    for (final entry in residualEntries) {
      if (entry.contribution > 0) {
        boxOnly.add(entry.line);
      } else if (entry.contribution < 0) {
        fundOnly.add(entry.line);
      }
    }

    return BudgetConsistencyReport(
      totalBoxes: totalBoxes,
      totalFunds: totalFunds,
      delta: totalBoxes - totalFunds,
      boxOnlyTransactions: boxOnly,
      fundOnlyTransactions: fundOnly,
      lastAlignmentDate: lastAlignmentDate,
      ignoredHistoricalTransactionsCount: lastAlignmentIndexExclusive,
    );
  }

  BudgetConsistencyReport consistencyNow() {
    return _buildConsistencyReport(
      totalBoxes: totalBoxesNow(),
      totalFunds: totalFundsNow(),
      includeTransaction: _isRelevantForNowConsistency,
    );
  }

  BudgetConsistencyReport consistencyEndOfMonth() {
    return _buildConsistencyReport(
      totalBoxes: totalBoxesEndMonth(),
      totalFunds: totalFundsEndMonth(),
      includeTransaction: _isRelevantForEndMonthConsistency,
    );
  }

  double currentMonthIncome() {
    final n = now;
    return transactions
        .where((t) =>
            t.confirmed &&
            t.amount > 0 &&
            t.date.year == n.year &&
            t.date.month == n.month)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double recurringMonthlyEquivalent(Recurring r) {
    final base = r.isMonthly ? r.amount.abs() : (r.amount.abs() / 12.0);
    return r.isIncome ? base : -base;
  }

  double totalRecurringMonthlyExpense() {
    double total = 0.0;
    for (final r in recurring) {
      if (!r.isIncome) {
        total += r.isMonthly ? r.amount.abs() : (r.amount.abs() / 12.0);
      }
    }
    return total;
  }

  double recurringGroupMonthlyTotal(String? groupId) {
    double total = 0.0;

    for (final r in recurring) {
      final match = groupId == null || groupId.isEmpty
          ? (r.groupId == null || r.groupId!.isEmpty)
          : r.groupId == groupId;

      if (!match) continue;
      total += recurringMonthlyEquivalent(r);
    }

    return total;
  }

  double recurringGroupExpensePercent(String? groupId) {
    final total = totalRecurringMonthlyExpense();
    if (total <= 0) return 0;

    double groupExpenses = 0.0;
    for (final r in recurring) {
      final match = groupId == null || groupId.isEmpty
          ? (r.groupId == null || r.groupId!.isEmpty)
          : r.groupId == groupId;

      if (!match) continue;
      if (r.isIncome) continue;

      groupExpenses += r.isMonthly ? r.amount.abs() : (r.amount.abs() / 12.0);
    }

    return (groupExpenses / total) * 100;
  }

  double recurringGroupOnIncomePercent(String? groupId) {
    final income = currentMonthIncome();
    if (income <= 0) return 0;
    return (recurringGroupMonthlyTotal(groupId).abs() / income) * 100;
  }

  Map<String, List<Recurring>> groupedRecurring() {
    final map = <String, List<Recurring>>{};
    for (final r in recurring) {
      final key = (r.groupId == null || r.groupId!.isEmpty)
          ? '__ungrouped__'
          : r.groupId!;
      map.putIfAbsent(key, () => []);
      map[key]!.add(r);
    }
    if (map.isEmpty) {
      map['__ungrouped__'] = [];
    }
    return map;
  }

  String recurringOccurrenceId(String recurringId, DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return 'rec_${recurringId}_$y$m$d';
  }

  String cashflowOccurrenceBaseId(String cashflowId, DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return 'flow_${cashflowId}_$y$m$d';
  }

  bool materializeCurrentMonthRecurringTransactions() {
    if (_writesLocked) return false;
    bool changed = false;
    final n = now;
    final currentMonthStart = DateTime(n.year, n.month, 1);

    for (final r in recurring) {
      DateTime dueDate;

      if (r.isMonthly) {
        dueDate = DateTime(n.year, n.month, r.dayOfMonth.clamp(1, 28));
        final startMonth = DateTime(r.startDate.year, r.startDate.month, 1);
        if (currentMonthStart.isBefore(startMonth)) {
          continue;
        }
        if (_sameMonth(r.startDate, dueDate) &&
            !_sameOrAfter(dueDate, r.startDate)) {
          continue;
        }
      } else {
        final annual = r.annualDate ?? r.startDate;
        dueDate = DateTime(n.year, annual.month, annual.day.clamp(1, 28));
        if (!_sameMonth(dueDate, n)) {
          continue;
        }
      }

      if (!_isRecurringActiveOnDate(r, dueDate)) {
        continue;
      }

      final txId = recurringOccurrenceId(r.id, dueDate);
      final exists = transactions.any((t) => t.id == txId);
      if (exists) continue;

      final signedAmount = r.isIncome ? r.amount.abs() : -r.amount.abs();
      final confirmed = r.manual ? false : _isDue(dueDate);

      transactions.add(
        TransactionModel(
          id: txId,
          boxId: r.boxId,
          fundId: r.fundId,
          amount: signedAmount,
          category: r.category,
          note: r.title,
          date: dueDate,
          confirmed: confirmed,
          recurringId: r.id,
        ),
      );
      changed = true;
    }

    return changed;
  }

  bool materializeCurrentMonthCashflowTransactions() {
    if (_writesLocked) return false;
    bool changed = false;
    final n = now;

    for (final c in cashflows) {
      DateTime dueDate;

      if (c.isMonthly) {
        dueDate = DateTime(n.year, n.month, c.dayOfMonth.clamp(1, 28));
        final startMonth = DateTime(c.startDate.year, c.startDate.month, 1);
        final currentMonthStart = DateTime(n.year, n.month, 1);

        if (currentMonthStart.isBefore(startMonth)) {
          continue;
        }
        if (_sameMonth(c.startDate, dueDate) &&
            !_sameOrAfter(dueDate, c.startDate)) {
          continue;
        }
      } else {
        final annual = c.annualDate ?? c.startDate;
        dueDate = DateTime(n.year, annual.month, annual.day.clamp(1, 28));
        if (!_sameMonth(dueDate, n)) {
          continue;
        }
        if (!_sameOrAfter(dueDate, c.startDate)) {
          continue;
        }
      }

      final base = cashflowOccurrenceBaseId(c.id, dueDate);
      final outExists = transactions.any((t) => t.id == '${base}_out');
      final inExists = transactions.any((t) => t.id == '${base}_in');

      if (!outExists && !inExists) {
        _createCashflowTransactions(
          c,
          dueDate,
          base,
          confirmed: _isDue(dueDate),
        );
        changed = true;
      }
    }

    return changed;
  }

  bool autoConfirmDueSingleTransactions() {
    if (_writesLocked) return false;
    bool changed = false;

    for (final t in transactions) {
      final isSingle = t.recurringId == null || t.recurringId!.isEmpty;

      if (isSingle && !t.confirmed && _isDue(t.date)) {
        t.confirmed = true;
        changed = true;
      }
    }

    return changed;
  }

  bool autoConfirmDueAutomaticRecurringTransactions() {
    if (_writesLocked) return false;
    bool changed = false;

    for (final t in transactions) {
      if (t.confirmed) continue;
      if (t.recurringId == null || t.recurringId!.isEmpty) continue;
      if (!_isDue(t.date)) continue;

      final match = recurring.where((r) => r.id == t.recurringId);
      if (match.isEmpty) continue;

      final rec = match.first;
      if (!rec.manual) {
        t.confirmed = true;
        changed = true;
      }
    }

    return changed;
  }

  void _createCashflowTransactions(
    Cashflow c,
    DateTime date,
    String base, {
    required bool confirmed,
  }) {
    final note = c.isBoxFlow
        ? 'Flusso ricorrente ${boxName(c.sourceId)} → ${boxName(c.destinationId)}'
        : 'Flusso ricorrente ${fundName(c.sourceId)} → ${fundName(c.destinationId)}';

    if (c.isBoxFlow) {
      transactions.add(
        TransactionModel(
          id: '${base}_out',
          boxId: c.sourceId,
          fundId: null,
          amount: -c.amount.abs(),
          category: 'Flusso ricorrente',
          note: note,
          date: date,
          confirmed: confirmed,
        ),
      );
      transactions.add(
        TransactionModel(
          id: '${base}_in',
          boxId: c.destinationId,
          fundId: null,
          amount: c.amount.abs(),
          category: 'Flusso ricorrente',
          note: note,
          date: date,
          confirmed: confirmed,
        ),
      );
    } else {
      transactions.add(
        TransactionModel(
          id: '${base}_out',
          boxId: null,
          fundId: c.sourceId,
          amount: -c.amount.abs(),
          category: 'Flusso ricorrente',
          note: note,
          date: date,
          confirmed: confirmed,
        ),
      );
      transactions.add(
        TransactionModel(
          id: '${base}_in',
          boxId: null,
          fundId: c.destinationId,
          amount: c.amount.abs(),
          category: 'Flusso ricorrente',
          note: note,
          date: date,
          confirmed: confirmed,
        ),
      );
    }
  }

  void applySingleCashflow({
    required bool isBoxFlow,
    required String sourceId,
    required String destinationId,
    required double amount,
    String category = 'Flusso singolo',
    String note = '',
    DateTime? date,
  }) {
    _assertWritable('apply_single_cashflow');
    final when = date ?? now;
    final confirmed = _isDue(when);
    final baseId = newId();

    if (isBoxFlow) {
      transactions.add(
        TransactionModel(
          id: '${baseId}_out',
          boxId: sourceId,
          fundId: null,
          amount: -amount.abs(),
          category: category,
          note: note,
          date: when,
          confirmed: confirmed,
        ),
      );
      transactions.add(
        TransactionModel(
          id: '${baseId}_in',
          boxId: destinationId,
          fundId: null,
          amount: amount.abs(),
          category: category,
          note: note,
          date: when,
          confirmed: confirmed,
        ),
      );
    } else {
      transactions.add(
        TransactionModel(
          id: '${baseId}_out',
          boxId: null,
          fundId: sourceId,
          amount: -amount.abs(),
          category: category,
          note: note,
          date: when,
          confirmed: confirmed,
        ),
      );
      transactions.add(
        TransactionModel(
          id: '${baseId}_in',
          boxId: null,
          fundId: destinationId,
          amount: amount.abs(),
          category: category,
          note: note,
          date: when,
          confirmed: confirmed,
        ),
      );
    }
  }

  MonthlySnapshot? snapshotForMonth(int year, int month) {
    try {
      return monthlySnapshots.firstWhere(
        (s) => s.year == year && s.month == month,
      );
    } catch (_) {
      return null;
    }
  }

  List<MonthlySnapshot> latestSnapshots([int limit = 12]) {
    final list = [...monthlySnapshots]..sort((a, b) {
        final ay = a.year * 100 + a.month;
        final by = b.year * 100 + b.month;
        return by.compareTo(ay);
      });
    return list.take(limit).toList();
  }

  bool createMonthlySnapshotIfNeeded() {
    if (_writesLocked) return false;
    final current = now;
    final targetMonth = DateTime(current.year, current.month - 1, 1);

    final alreadyExists =
        snapshotForMonth(targetMonth.year, targetMonth.month) != null;
    if (alreadyExists) {
      return false;
    }

    final monthTx = transactions.where(
      (t) =>
          t.date.year == targetMonth.year && t.date.month == targetMonth.month,
    );

    final totalIncome = monthTx
        .where((t) => t.amount > 0)
        .fold<double>(0.0, (sum, t) => sum + t.amount);

    final totalExpenses = monthTx
        .where((t) => t.amount < 0)
        .fold<double>(0.0, (sum, t) => sum + t.amount.abs());

    final groupTotals = <String, double>{};

    for (final r in recurring) {
      final group = groupName(r.groupId).trim();
      final key = group.isEmpty ? 'Senza gruppo' : group;
      final value = r.isMonthly ? r.amount.abs() : (r.amount.abs() / 12.0);
      groupTotals.update(key, (old) => old + value, ifAbsent: () => value);
    }

    final savingsBox = boxes.where(
      (b) => b.name.trim().toUpperCase() == 'RISPARMI',
    );
    final subscriptionsBox = boxes.where(
      (b) => b.name.trim().toUpperCase() == 'ABBONAMENTI',
    );

    final snapshot = MonthlySnapshot(
      id: newId(),
      year: targetMonth.year,
      month: targetMonth.month,
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      monthlyBalance: totalIncome - totalExpenses,
      totalBoxesBalance: boxes.fold(
        0.0,
        (sum, box) =>
            sum +
            _entityBalanceAtMonthEnd(
              initialAmount: box.initialAmount,
              entityId: box.id,
              targetMonth: targetMonth,
              matchesEntity: (t, id) => t.boxId == id,
            ),
      ),
      totalFundsBalance: funds.fold(
        0.0,
        (sum, fund) =>
            sum +
            _entityBalanceAtMonthEnd(
              initialAmount: fund.initialAmount,
              entityId: fund.id,
              targetMonth: targetMonth,
              matchesEntity: (t, id) => t.fundId == id,
            ),
      ),
      savingsBoxBalance: savingsBox.isNotEmpty
          ? _entityBalanceAtMonthEnd(
              initialAmount: savingsBox.first.initialAmount,
              entityId: savingsBox.first.id,
              targetMonth: targetMonth,
              matchesEntity: (t, id) => t.boxId == id,
            )
          : 0.0,
      subscriptionsBoxBalance: subscriptionsBox.isNotEmpty
          ? _entityBalanceAtMonthEnd(
              initialAmount: subscriptionsBox.first.initialAmount,
              entityId: subscriptionsBox.first.id,
              targetMonth: targetMonth,
              matchesEntity: (t, id) => t.boxId == id,
            )
          : 0.0,
      groupTotals: groupTotals,
    );

    monthlySnapshots.add(snapshot);

    monthlySnapshots.sort((a, b) {
      final ay = a.year * 100 + a.month;
      final by = b.year * 100 + b.month;
      return ay.compareTo(by);
    });

    if (monthlySnapshots.length > 24) {
      final overflow = monthlySnapshots.length - 24;
      monthlySnapshots.removeRange(0, overflow);
    }

    return true;
  }
}
