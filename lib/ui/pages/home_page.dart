import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:family_boxes_2/engine/budget_engine.dart';
import 'package:family_boxes_2/models/access_mode.dart';
import 'package:family_boxes_2/models/auth_user.dart';
import 'package:family_boxes_2/models/entitlement.dart';
import 'package:family_boxes_2/models/transaction.dart';
import 'package:family_boxes_2/services/oracle_service.dart';
import 'package:family_boxes_2/ui/pages/nuovo_flusso_singolo_page.dart';
import 'package:family_boxes_2/ui/pages/nuova_transazione_page.dart';
import 'package:family_boxes_2/ui/pages/settings_page.dart';
import 'package:family_boxes_2/ui/pages/transaction_history_page.dart';
import 'package:family_boxes_2/ui/widgets/box_card.dart';
import 'package:family_boxes_2/ui/widgets/fund_card.dart';
import 'package:family_boxes_2/ui/widgets/pending_section.dart';
import 'package:family_boxes_2/ui/widgets/section_title.dart';
import 'package:family_boxes_2/ui/widgets/total_capsules.dart';
import 'package:family_boxes_2/ui/widgets/ui_formatters.dart';
import 'package:family_boxes_2/ui/widgets/read_only_dialogs.dart';

class HomePage extends StatefulWidget {
  final BudgetEngine engine;
  final Future<void> Function() onChanged;
  final AccessMode accessMode;
  final AuthUser currentUser;
  final Entitlement entitlement;
  final AccessMode? debugOverride;
  final Future<void> Function() onSignOut;
  final Future<void> Function() onEntitlementRefresh;
  final Future<void> Function(AccessMode? mode) onDebugAccessOverrideChanged;
  final Future<void> Function() onActivateDebugSubscription;
  final Future<void> Function() onResetDebugTrial;
  final Future<void> Function() onForceDebugReadOnly;

  const HomePage({
    super.key,
    required this.engine,
    required this.onChanged,
    required this.accessMode,
    required this.currentUser,
    required this.entitlement,
    required this.debugOverride,
    required this.onSignOut,
    required this.onEntitlementRefresh,
    required this.onDebugAccessOverrideChanged,
    required this.onActivateDebugSubscription,
    required this.onResetDebugTrial,
    required this.onForceDebugReadOnly,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _privacyKey = 'home_hide_amounts';

  bool _hideAmounts = false;
  bool _futureExpanded = false;
  bool _alignmentWarningShown = false;
  Timer? _dailyTimer;
  DateTime _lastCheck = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadPrivacy();

    _dailyTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _checkDayChange(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showAlignmentWarningIfNeeded();
    });
  }

  @override
  void dispose() {
    _dailyTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPrivacy() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(_privacyKey) ?? false;
    if (!mounted) return;
    setState(() {
      _hideAmounts = value;
    });
  }

  Future<void> _togglePrivacy() async {
    final prefs = await SharedPreferences.getInstance();
    final next = !_hideAmounts;
    await prefs.setBool(_privacyKey, next);
    if (!mounted) return;
    setState(() {
      _hideAmounts = next;
    });
  }

  Future<void> _checkDayChange() async {
    if (!widget.accessMode.hasFullAccess) {
      return;
    }

    final now = DateTime.now();

    final oldDay = DateTime(_lastCheck.year, _lastCheck.month, _lastCheck.day);
    final newDay = DateTime(now.year, now.month, now.day);

    if (newDay.isAfter(oldDay)) {
      _lastCheck = now;

      widget.engine.materializeCurrentMonthRecurringTransactions();
      widget.engine.materializeCurrentMonthCashflowTransactions();
      widget.engine.autoConfirmDueSingleTransactions();
      widget.engine.autoConfirmDueAutomaticRecurringTransactions();

      await widget.onChanged();

      if (!mounted) return;
      setState(() {});
    }
  }

  Future<void> _confirmPending(TransactionModel tx) async {
    if (!widget.accessMode.hasFullAccess) {
      await _showReadOnlyBlockedDialog('La conferma delle transazioni');
      return;
    }
    widget.engine.confirmTransaction(tx.id);
    await widget.onChanged();
  }

  Future<void> _deleteSinglePending(TransactionModel tx) async {
    if (!widget.accessMode.hasFullAccess) {
      await _showReadOnlyBlockedDialog("L'eliminazione delle transazioni");
      return;
    }
    widget.engine.deleteTransaction(tx.id);
    await widget.onChanged();
  }

  Future<void> _deleteWholeRecurring(TransactionModel tx) async {
    if (!widget.accessMode.hasFullAccess) {
      await _showReadOnlyBlockedDialog("L'eliminazione delle ricorrenze");
      return;
    }
    if (tx.recurringId != null && tx.recurringId!.isNotEmpty) {
      widget.engine.deleteRecurring(tx.recurringId!);
      widget.engine.deleteTransaction(tx.id);
    } else {
      widget.engine.deleteTransaction(tx.id);
    }
    await widget.onChanged();
  }

  bool _isFuture(TransactionModel tx) {
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final txDateOnly = DateTime(tx.date.year, tx.date.month, tx.date.day);
    return txDateOnly.isAfter(todayOnly);
  }

  double _futureTotal(List<TransactionModel> txs) {
    return txs.fold(0.0, (sum, t) => sum + t.amount);
  }

  Future<void> _showReadOnlyBlockedDialog(String action) {
    return showReadOnlyBlockedDialog(context, action: action);
  }


  Future<void> _showAlignmentWarningIfNeeded() async {
    if (!mounted || _alignmentWarningShown) return;

    final nowReport = widget.engine.consistencyNow();
    final endMonthReport = widget.engine.consistencyEndOfMonth();

    final hasNowDelta = !nowReport.isAligned();
    final hasEndMonthDelta = !endMonthReport.isAligned();

    if (!hasNowDelta && !hasEndMonthDelta) {
      return;
    }

    _alignmentWarningShown = true;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E0A3E),
          title: const Text(
            'Disallineamento rilevato',
            style: TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Le capsule Box e Fondi non sono allineate oltre la soglia di tolleranza di €0,01.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  if (hasNowDelta) ...[
                    _buildConsistencySection(
                      title: 'Delta attuale',
                      report: nowReport,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (hasEndMonthDelta)
                    _buildConsistencySection(
                      title: 'Delta fine mese',
                      report: endMonthReport,
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Chiudi'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConsistencySection({
    required String title,
    required BudgetConsistencyReport report,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title: ${formatAmount(report.delta)}',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Totale Box ${formatAmount(report.totalBoxes)} • Totale Fondi ${formatAmount(report.totalFunds)}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        if (report.lastAlignmentDate != null) ...[
          const SizedBox(height: 6),
          Text(
            'Ultimo riallineamento: ${formatDateShort(report.lastAlignmentDate!)}',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
            ),
          ),
        ],
        if (report.ignoredHistoricalTransactionsCount > 0) ...[
          const SizedBox(height: 4),
          Text(
            'Transazioni storiche ignorate: ${report.ignoredHistoricalTransactionsCount}',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 10),
        ..._buildConsistencyGroup(
          label: 'Transazioni solo box',
          lines: report.boxOnlyTransactions,
        ),
        const SizedBox(height: 10),
        ..._buildConsistencyGroup(
          label: 'Transazioni solo fondo',
          lines: report.fundOnlyTransactions,
        ),
      ],
    );
  }

  List<Widget> _buildConsistencyGroup({
    required String label,
    required List<BudgetConsistencyLine> lines,
  }) {
    if (lines.isEmpty) {
      return [
        Text(
          '$label: nessuna',
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 12,
          ),
        ),
      ];
    }

    return [
      Text(
        '$label (${lines.length})',
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
      const SizedBox(height: 6),
      ...lines.map(_buildConsistencyLineTile),
    ];
  }

  Widget _buildConsistencyLineTile(BudgetConsistencyLine line) {
    final note = line.note.trim();
    final status = line.confirmed ? 'Confermata' : 'Non confermata';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF120021),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            line.category.isNotEmpty ? line.category : 'Senza categoria',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              note,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            '${formatDateShort(line.date)} • ${formatAmount(line.amount)} • $status',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            line.scope,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _showOracleBlockedDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Oracolo bloccato'),
          content: const Text(
            "In modalità sola lettura l'oracolo resta sigillato. Riattiva trial o abbonamento per interrogarlo.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Chiudi'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showOracle() async {
    if (!widget.accessMode.oracleEnabled) {
      await _showOracleBlockedDialog();
      return;
    }

    OracleReading reading = OracleService.generate(widget.engine);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return Dialog.fullscreen(
              backgroundColor: const Color(0xFF120021),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '🔮 ORACOLO',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Osservazione del sistema finanziario...',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E0A3E),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0x66E91E8C),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x3300F5FF),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  reading.verdict,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  reading.observation,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    height: 1.45,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  reading.prophecy,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    height: 1.45,
                                    color: Color(0xFF00F5FF),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                Center(
                                  child: Text(
                                    reading.title,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFFFC107),
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setModal(() {
                                  reading =
                                      OracleService.generate(widget.engine);
                                });
                              },
                              icon: const Icon(Icons.auto_awesome_rounded),
                              label: const Text('Interroga ancora'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('Chiudi'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = widget.engine.pendingTransactions();

    final allTransactions = widget.engine.sortedTransactionsDesc();
    final futureTransactions = allTransactions.where(_isFuture).toList();
    final visibleLatest =
        allTransactions.where((t) => !_isFuture(t)).take(10).toList();

    final futureTotal = _futureTotal(futureTransactions);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Boxes'),
        actions: [
          IconButton(
            onPressed: _togglePrivacy,
            icon: Icon(
              _hideAmounts
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
            ),
          ),
          IconButton(
            onPressed: _showOracle,
            icon: Icon(
              widget.accessMode.oracleEnabled
                  ? Icons.auto_awesome_rounded
                  : Icons.lock_rounded,
            ),
            tooltip: widget.accessMode.oracleEnabled
                ? 'Oracolo'
                : 'Oracolo bloccato in sola lettura',
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsPage(
                    engine: widget.engine,
                    onChanged: widget.onChanged,
                    accessMode: widget.accessMode,
                    currentUser: widget.currentUser,
                    entitlement: widget.entitlement,
                    debugOverride: widget.debugOverride,
                    onSignOut: widget.onSignOut,
                    onEntitlementRefresh: widget.onEntitlementRefresh,
                    onDebugAccessOverrideChanged: widget.onDebugAccessOverrideChanged,
                    onActivateDebugSubscription: widget.onActivateDebugSubscription,
                    onResetDebugTrial: widget.onResetDebugTrial,
                    onForceDebugReadOnly: widget.onForceDebugReadOnly,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 8),
                if (!widget.accessMode.hasFullAccess) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E0A3E),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFFFC107)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_rounded, color: Color(0xFFFFC107)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Modalità sola lettura: consultazione consentita, modifiche bloccate.',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  height: 105,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.engine.boxes.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final box = widget.engine.boxes[index];
                      return BoxCard(
                        name: box.name,
                        currentAmount: widget.engine.boxCurrentBalance(box.id),
                        endMonthAmount:
                            widget.engine.boxEndMonthBalance(box.id),
                        color: box.color,
                        obscureAmounts: _hideAmounts,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TransactionHistoryPage(
                                title: 'Storico box • ${box.name}',
                                transactions:
                                    widget.engine.transactionsByBox(box.id),
                                subtitleBuilder: (tx) =>
                                    '${widget.engine.transactionScope(tx)} • ${tx.note}',
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                TotalCapsules(
                  totalBoxNow: widget.engine.totalBoxesNow(),
                  totalBoxEnd: widget.engine.totalBoxesEndMonth(),
                  totalFundNow: widget.engine.totalFundsNow(),
                  totalFundEnd: widget.engine.totalFundsEndMonth(),
                  obscureAmounts: _hideAmounts,
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle('Fondi'),
                    const SizedBox(height: 8),
                    GridView.builder(
                      itemCount: widget.engine.funds.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisExtent: 84,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemBuilder: (context, index) {
                        final fund = widget.engine.funds[index];
                        return FundCard(
                          name: fund.name,
                          currentAmount:
                              widget.engine.fundCurrentBalance(fund.id),
                          endMonthAmount:
                              widget.engine.fundEndMonthBalance(fund.id),
                          obscureAmounts: _hideAmounts,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TransactionHistoryPage(
                                  title: 'Storico fondo • ${fund.name}',
                                  transactions:
                                      widget.engine.transactionsByFund(fund.id),
                                  subtitleBuilder: (tx) =>
                                      '${widget.engine.transactionScope(tx)} • ${tx.note}',
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                PendingSection(
                  transactions: pending,
                  subtitleBuilder: (tx) => tx.note.isNotEmpty
                      ? tx.note
                      : widget.engine.transactionScope(tx),
                  onConfirm: _confirmPending,
                  onDeleteSingle: _deleteSinglePending,
                  onDeleteRecurring: _deleteWholeRecurring,
                  obscureAmounts: _hideAmounts,
                  readOnly: !widget.accessMode.hasFullAccess,
                  onReadOnlyTap: () =>
                      _showReadOnlyBlockedDialog('La gestione delle transazioni in attesa'),
                ),
                if (pending.isNotEmpty) const SizedBox(height: 16),
                if (futureTransactions.isNotEmpty) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E0A3E),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () {
                            setState(() {
                              _futureExpanded = !_futureExpanded;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFF00F5FF),
                                  child: Icon(
                                    _futureExpanded
                                        ? Icons.expand_less_rounded
                                        : Icons.expand_more_rounded,
                                    color: Colors.black,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Spese future',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Text(
                                  _hideAmounts
                                      ? '•••••'
                                      : formatAmount(futureTotal),
                                  style: const TextStyle(
                                    color: Color(0xFF00F5FF),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    fontFamily: 'Roboto Condensed',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_futureExpanded) ...[
                          const Divider(color: Colors.white10, height: 1),
                          ListView.separated(
                            itemCount: futureTransactions.length,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            separatorBuilder: (_, __) => const Divider(
                              color: Colors.white10,
                              height: 1,
                            ),
                            itemBuilder: (context, index) {
                              final tx = futureTransactions[index];
                              final positive = tx.amount >= 0;

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                leading: const CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Color(0xFF00F5FF),
                                  child: Icon(
                                    Icons.schedule_rounded,
                                    color: Colors.black,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  tx.category,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                subtitle: Text(
                                  tx.note.isEmpty
                                      ? widget.engine.transactionScope(tx)
                                      : tx.note,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 11,
                                  ),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _hideAmounts
                                          ? '•••••'
                                          : formatAmount(tx.amount),
                                      style: TextStyle(
                                        color: positive
                                            ? const Color(0xFF00E676)
                                            : const Color(0xFF00F5FF),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                        fontFamily: 'Roboto Condensed',
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      formatDateShort(tx.date),
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle('Ultime transazioni'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E0A3E),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: ListView.separated(
                        itemCount: visibleLatest.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        separatorBuilder: (_, __) => const Divider(
                          color: Colors.white10,
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final tx = visibleLatest[index];
                          final positive = tx.amount >= 0;

                          final today = DateTime.now();
                          final todayOnly =
                              DateTime(today.year, today.month, today.day);
                          final txDateOnly = DateTime(
                              tx.date.year, tx.date.month, tx.date.day);

                          final visuallyPending =
                              !tx.confirmed || txDateOnly.isAfter(todayOnly);

                          final bgColor = visuallyPending
                              ? const Color(0xFF00F5FF)
                              : (positive
                                  ? const Color(0xFF00E676)
                                  : const Color(0xFFFF6B35));

                          final icon = visuallyPending
                              ? Icons.schedule_rounded
                              : positive
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded;

                          final amountColor = visuallyPending
                              ? const Color(0xFF00F5FF)
                              : (positive
                                  ? const Color(0xFF00E676)
                                  : const Color(0xFFFF6B35));

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: bgColor,
                              child: Icon(
                                icon,
                                color: Colors.black,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              tx.category,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Text(
                              tx.note.isEmpty
                                  ? widget.engine.transactionScope(tx)
                                  : tx.note,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _hideAmounts
                                      ? '•••••'
                                      : formatAmount(tx.amount),
                                  style: TextStyle(
                                    color: amountColor,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    fontFamily: 'Roboto Condensed',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatDateShort(tx.date),
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      floatingActionButton: SizedBox(
        width: 60,
        height: 120,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            Positioned(
              right: 4,
              bottom: 64,
              child: FloatingActionButton(
                heroTag: 'single_flow_home',
                mini: true,
                onPressed: () {
                  if (!widget.accessMode.hasFullAccess) {
                    _showReadOnlyBlockedDialog('La creazione dei flussi');
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NuovoFlussoSingoloPage(
                        engine: widget.engine,
                        onSaved: widget.onChanged,
                      ),
                    ),
                  );
                },
                child: const Icon(Icons.sync_rounded),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 8,
              child: FloatingActionButton(
                heroTag: 'new_transaction_home',
                onPressed: () {
                  if (!widget.accessMode.hasFullAccess) {
                    _showReadOnlyBlockedDialog('La creazione delle transazioni');
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NuovaTransazionePage(
                        engine: widget.engine,
                        onSaved: widget.onChanged,
                      ),
                    ),
                  );
                },
                child: const Icon(Icons.add_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
