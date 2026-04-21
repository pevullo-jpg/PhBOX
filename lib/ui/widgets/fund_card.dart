import 'package:flutter/material.dart';

import 'ui_formatters.dart';

class FundCard extends StatelessWidget {
  final String name;
  final double currentAmount;
  final double endMonthAmount;
  final bool obscureAmounts;
  final VoidCallback? onTap;

  const FundCard({
    super.key,
    required this.name,
    required this.currentAmount,
    required this.endMonthAmount,
    this.obscureAmounts = false,
    this.onTap,
  });

  String get _hidden => '•••••';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF281A4A),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const Spacer(),
            Text(
              obscureAmounts ? _hidden : formatAmount(currentAmount),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                fontFamily: 'Roboto Condensed',
              ),
            ),
            Text(
              obscureAmounts ? _hidden : formatAmount(endMonthAmount),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white60,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
