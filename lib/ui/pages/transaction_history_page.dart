import 'package:flutter/material.dart';

import 'package:family_boxes_2/models/transaction.dart';
import 'package:family_boxes_2/ui/widgets/form_card.dart';
import 'package:family_boxes_2/ui/widgets/transaction_tile.dart';
import 'package:family_boxes_2/ui/widgets/ui_formatters.dart';

class TransactionHistoryPage extends StatelessWidget {
  final String title;
  final List<TransactionModel> transactions;
  final String Function(TransactionModel)? subtitleBuilder;

  const TransactionHistoryPage({
    super.key,
    required this.title,
    required this.transactions,
    this.subtitleBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final list = [...transactions]..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: list.isEmpty
          ? const Center(
              child: Text('Nessuna transazione'),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FormCard(
                padding: EdgeInsets.zero,
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(
                    color: Colors.white10,
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final tx = list[index];
                    final subtitle = subtitleBuilder != null
                        ? subtitleBuilder!(tx)
                        : '${formatDateFull(tx.date)}${tx.note.isNotEmpty ? ' • ${tx.note}' : ''}';

                    return TransactionTile(
                      transaction: tx,
                      subtitle: subtitle,
                    );
                  },
                ),
              ),
            ),
    );
  }
}
