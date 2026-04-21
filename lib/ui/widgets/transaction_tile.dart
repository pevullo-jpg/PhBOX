import 'package:flutter/material.dart';

import 'package:family_boxes_2/models/transaction.dart';

import 'ui_formatters.dart';

class TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final String subtitle;

  const TransactionTile({
    super.key,
    required this.transaction,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final positive = transaction.amount >= 0;

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final txDateOnly = DateTime(
      transaction.date.year,
      transaction.date.month,
      transaction.date.day,
    );

    final visuallyPending =
        !transaction.confirmed || txDateOnly.isAfter(todayOnly);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: visuallyPending
            ? const Color(0xFF00F5FF)
            : (positive ? const Color(0xFF00E676) : const Color(0xFFFF6B35)),
        child: Icon(
          visuallyPending
              ? Icons.schedule_rounded
              : positive
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
          color: Colors.black,
          size: 20,
        ),
      ),
      title: Text(
        transaction.category,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
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
            formatAmount(transaction.amount),
            style: TextStyle(
              color: visuallyPending
                  ? const Color(0xFF00F5FF)
                  : (positive
                      ? const Color(0xFF00E676)
                      : const Color(0xFFFF6B35)),
              fontWeight: FontWeight.w900,
              fontSize: 16,
              fontFamily: 'Roboto Condensed',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatDateShort(transaction.date),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
