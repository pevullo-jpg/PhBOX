import 'package:flutter/material.dart';

import 'package:family_boxes_2/engine/budget_engine.dart';
import 'package:family_boxes_2/models/access_mode.dart';
import 'package:family_boxes_2/models/recurring.dart';
import 'package:family_boxes_2/models/cashflow.dart';
import 'package:family_boxes_2/ui/pages/nuova_ricorrenza_page.dart';
import 'package:family_boxes_2/ui/pages/nuovo_flusso_ricorrente_page.dart';
import 'package:family_boxes_2/ui/widgets/form_card.dart';
import 'package:family_boxes_2/ui/widgets/ui_formatters.dart';
import 'package:family_boxes_2/ui/widgets/read_only_dialogs.dart';

class RicorrenzePage extends StatefulWidget {
  final BudgetEngine engine;
  final Future<void> Function() onChanged;
  final AccessMode accessMode;

  const RicorrenzePage({
    super.key,
    required this.engine,
    required this.onChanged,
    required this.accessMode,
  });

  @override
  State<RicorrenzePage> createState() => _RicorrenzePageState();
}

class _RicorrenzePageState extends State<RicorrenzePage> {
  Future<void> _openRecurring(Recurring? existing) async {
    if (!widget.accessMode.hasFullAccess) {
      await showReadOnlyBlockedDialog(
        context,
        action: existing == null
            ? 'La creazione delle ricorrenze'
            : 'La modifica delle ricorrenze',
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NuovaRicorrenzaPage(
          engine: widget.engine,
          onSaved: widget.onChanged,
          existing: existing,
        ),
      ),
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openCashflow([Cashflow? existing]) async {
    if (!widget.accessMode.hasFullAccess) {
      await showReadOnlyBlockedDialog(
        context,
        action: existing == null
            ? 'La creazione dei flussi ricorrenti'
            : 'La modifica dei flussi ricorrenti',
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NuovoFlussoRicorrentePage(
          engine: widget.engine,
          onSaved: widget.onChanged,
          existing: existing,
        ),
      ),
    );

    if (!mounted) return;
    setState(() {});
  }

  String _scheduleLabel(Recurring r) {
    if (r.isMonthly) {
      return '${r.dayOfMonth} di ogni mese';
    }

    final annual = r.annualDate ?? r.startDate;
    return formatDateShort(annual);
  }

  int _annualSortValue(Recurring r) {
    final annual = r.annualDate ?? r.startDate;
    return annual.month * 100 + annual.day;
  }

  List<Recurring> _sortedRecurring(List<Recurring> items) {
    final list = [...items];

    list.sort((a, b) {
      if (a.isMonthly != b.isMonthly) {
        return a.isMonthly ? -1 : 1;
      }

      if (a.isMonthly) {
        return a.dayOfMonth.compareTo(b.dayOfMonth);
      }

      return _annualSortValue(a).compareTo(_annualSortValue(b));
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = widget.engine.groupedRecurring();
    final groupKeys = grouped.keys.toList()
      ..sort((a, b) {
        final an =
            a == '__ungrouped__' ? 'Senza gruppo' : widget.engine.groupName(a);
        final bn =
            b == '__ungrouped__' ? 'Senza gruppo' : widget.engine.groupName(b);
        return an.compareTo(bn);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ricorrenze'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        children: [
          ...groupKeys.map((groupId) {
            final list = _sortedRecurring(grouped[groupId] ?? []);
            final groupTitle = groupId == '__ungrouped__'
                ? 'Senza gruppo'
                : widget.engine.groupName(groupId);

            final monthlyTotal = widget.engine.recurringGroupMonthlyTotal(
              groupId == '__ungrouped__' ? null : groupId,
            );
            final expensePercent = widget.engine.recurringGroupExpensePercent(
              groupId == '__ungrouped__' ? null : groupId,
            );
            final incomePercent = widget.engine.recurringGroupOnIncomePercent(
              groupId == '__ungrouped__' ? null : groupId,
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: FormCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      groupTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Totale mensile: ${formatAmount(monthlyTotal)}',
                      style:
                          const TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '% su spese fisse: ${formatPercent(expensePercent)}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '% su introiti mese: ${formatPercent(incomePercent)}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                    const SizedBox(height: 12),
                    if (list.isEmpty)
                      const Text(
                        'Nessuna spesa fissa',
                        style: TextStyle(color: Colors.white54),
                      )
                    else
                      ...list.map((r) {
                        final amountColor = r.isIncome
                            ? const Color(0xFF00E676)
                            : const Color(0xFFFF6B35);

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () => _openRecurring(r),
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: r.isIncome
                                ? const Color(0xFF00E676)
                                : const Color(0xFFFF6B35),
                            child: Icon(
                              r.isIncome
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded,
                              color: Colors.black,
                            ),
                          ),
                          title: Text(
                            r.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Text(
                            '${r.category}\n${_scheduleLabel(r)}',
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
                                formatAmount(r.isIncome
                                    ? r.amount.abs()
                                    : -r.amount.abs()),
                                style: TextStyle(
                                  color: amountColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  fontFamily: 'Roboto Condensed',
                                ),
                              ),
                              if (r.durationMonths != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${r.durationMonths} mesi',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            );
          }),
          FormCard(
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openRecurring(null),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Nuova spesa fissa'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openCashflow(),
                    icon: const Icon(Icons.repeat_rounded),
                    label: const Text('Nuovo flusso ricorrente'),
                  ),
                ),
              ],
            ),
          ),
          if (widget.engine.cashflows.isNotEmpty) ...[
            const SizedBox(height: 16),
            FormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Flussi ricorrenti',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...widget.engine.cashflows.map((c) {
                    final source = c.isBoxFlow
                        ? widget.engine.boxName(c.sourceId)
                        : widget.engine.fundName(c.sourceId);
                    final dest = c.isBoxFlow
                        ? widget.engine.boxName(c.destinationId)
                        : widget.engine.fundName(c.destinationId);

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () => _openCashflow(c),
                      title: Text(
                        '$source → $dest',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        c.isMonthly
                            ? '${c.dayOfMonth} di ogni mese'
                            : formatDateShort(c.annualDate ?? c.startDate),
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                      trailing: Text(
                        formatAmount(c.amount),
                        style: const TextStyle(
                          color: Color(0xFF00F5FF),
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          fontFamily: 'Roboto Condensed',
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
