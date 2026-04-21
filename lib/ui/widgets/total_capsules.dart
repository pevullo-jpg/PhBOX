import 'package:flutter/material.dart';

import 'ui_formatters.dart';

class TotalCapsules extends StatelessWidget {
  final double totalBoxNow;
  final double totalBoxEnd;
  final double totalFundNow;
  final double totalFundEnd;
  final bool obscureAmounts;

  const TotalCapsules({
    super.key,
    required this.totalBoxNow,
    required this.totalBoxEnd,
    required this.totalFundNow,
    required this.totalFundEnd,
    this.obscureAmounts = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _Capsule(
              label: 'Box attuali',
              value: totalBoxNow,
              obscureAmounts: obscureAmounts,
            ),
            const SizedBox(width: 8),
            _Capsule(
              label: 'Box fine mese',
              value: totalBoxEnd,
              obscureAmounts: obscureAmounts,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _Capsule(
              label: 'Fondi attuali',
              value: totalFundNow,
              obscureAmounts: obscureAmounts,
            ),
            const SizedBox(width: 8),
            _Capsule(
              label: 'Fondi fine mese',
              value: totalFundEnd,
              obscureAmounts: obscureAmounts,
            ),
          ],
        ),
      ],
    );
  }
}

class _Capsule extends StatelessWidget {
  final String label;
  final double value;
  final bool obscureAmounts;

  const _Capsule({
    required this.label,
    required this.value,
    required this.obscureAmounts,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF1E0A3E),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white24),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
            ),
            Text(
              obscureAmounts ? '•••••' : formatAmount(value),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                fontFamily: 'Roboto Condensed',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
