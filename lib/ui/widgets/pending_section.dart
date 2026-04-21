import 'package:flutter/material.dart';

import 'package:family_boxes_2/models/transaction.dart';

import 'section_title.dart';
import 'ui_formatters.dart';

class PendingSection extends StatelessWidget {
  final List<TransactionModel> transactions;
  final String Function(TransactionModel) subtitleBuilder;
  final Future<void> Function(TransactionModel) onConfirm;
  final Future<void> Function(TransactionModel) onDeleteSingle;
  final Future<void> Function(TransactionModel) onDeleteRecurring;
  final bool obscureAmounts;
  final bool readOnly;
  final Future<void> Function()? onReadOnlyTap;

  const PendingSection({
    super.key,
    required this.transactions,
    required this.subtitleBuilder,
    required this.onConfirm,
    required this.onDeleteSingle,
    required this.onDeleteRecurring,
    this.obscureAmounts = false,
    this.readOnly = false,
    this.onReadOnlyTap,
  });

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Da confermare'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E0A3E),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFF00F5FF),
              width: 1.4,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x6600F5FF),
                blurRadius: 18,
              ),
            ],
          ),
          child: ListView.separated(
            itemCount: transactions.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            separatorBuilder: (_, __) => const Divider(
              color: Colors.white10,
              height: 1,
            ),
            itemBuilder: (context, index) {
              final tx = transactions[index];

              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: const CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFFFF6B35),
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: Colors.black,
                    size: 20,
                  ),
                ),
                title: Text(
                  tx.category.isEmpty ? 'Ricorrenza' : tx.category,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  subtitleBuilder(tx),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white60,
                    fontSize: 11,
                  ),
                ),
                trailing: Text(
                  obscureAmounts ? '•••••' : formatAmount(tx.amount),
                  style: const TextStyle(
                    color: Color(0xFFFF6B35),
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    fontFamily: 'Roboto Condensed',
                  ),
                ),
                onTap: () async {
                  if (readOnly) {
                    await onReadOnlyTap?.call();
                    return;
                  }

                  final action = await showModalBottomSheet<String>(
                    context: context,
                    backgroundColor: const Color(0xFF1E0A3E),
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (sheetContext) {
                      return SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Transazione in attesa',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () =>
                                      Navigator.of(sheetContext).pop('confirm'),
                                  child: const Text('Conferma'),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () =>
                                      Navigator.of(sheetContext).pop('delete'),
                                  child: const Text('Elimina'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );

                  if (action == 'confirm') {
                    await onConfirm(tx);
                    return;
                  }

                  if (action == 'delete') {
                    final deleteChoice = await showModalBottomSheet<String>(
                      context: context,
                      backgroundColor: const Color(0xFF1E0A3E),
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      builder: (sheetContext) {
                        return SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Eliminazione',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () => Navigator.of(sheetContext)
                                        .pop('single'),
                                    child: const Text(
                                      'Elimina solo questa transazione',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.of(sheetContext)
                                        .pop('recurring'),
                                    child: const Text(
                                      'Elimina l\'intera ricorrenza',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );

                    if (deleteChoice == 'single') {
                      await onDeleteSingle(tx);
                      return;
                    }

                    if (deleteChoice == 'recurring') {
                      await onDeleteRecurring(tx);
                      return;
                    }
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
