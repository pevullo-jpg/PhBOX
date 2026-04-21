import 'package:flutter/material.dart';

import 'package:family_boxes_2/engine/budget_engine.dart';
import 'package:family_boxes_2/models/access_mode.dart';
import 'package:family_boxes_2/models/transaction.dart';
import 'package:family_boxes_2/ui/pages/nuova_transazione_page.dart';
import 'package:family_boxes_2/ui/widgets/form_card.dart';
import 'package:family_boxes_2/ui/widgets/transaction_tile.dart';
import 'package:family_boxes_2/ui/widgets/ui_formatters.dart';
import 'package:family_boxes_2/ui/widgets/read_only_dialogs.dart';

class MovimentiPage extends StatelessWidget {
  final BudgetEngine engine;
  final Future<void> Function() onChanged;
  final AccessMode accessMode;

  const MovimentiPage({
    super.key,
    required this.engine,
    required this.onChanged,
    required this.accessMode,
  });

  Future<void> _openActions(BuildContext context, TransactionModel tx) async {
    if (!accessMode.hasFullAccess) {
      await showReadOnlyBlockedDialog(
        context,
        action: 'La modifica delle transazioni',
      );
      return;
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1E0A3E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Transazione',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, 'edit'),
                    child: const Text('Modifica'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, 'delete'),
                    child: const Text('Elimina'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (action == 'edit') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NuovaTransazionePage(
            engine: engine,
            onSaved: onChanged,
            existing: tx,
          ),
        ),
      );
      return;
    }

    if (action == 'delete') {
      engine.deleteTransaction(tx.id);
      await onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactions = engine.sortedTransactionsDesc();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Movimenti'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: FormCard(
            padding: EdgeInsets.zero,
            child: ListView.separated(
              itemCount: transactions.length,
              separatorBuilder: (_, __) => const Divider(
                color: Colors.white10,
                height: 1,
              ),
              itemBuilder: (context, index) {
                final tx = transactions[index];
                final scope = engine.transactionScope(tx);
                final note = tx.note.trim();

                final subtitle = '$scope\n'
                    '${note.isEmpty ? '-' : note}\n'
                    '${formatDateFull(tx.date)}${tx.confirmed ? '' : ' • non contabilizzata'}';

                return InkWell(
                  onTap: () => _openActions(context, tx),
                  child: TransactionTile(
                    transaction: tx,
                    subtitle: subtitle,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
