import 'package:flutter/material.dart';

import 'ui_formatters.dart';

class BoxCard extends StatelessWidget {
  final String name;
  final double currentAmount;
  final double endMonthAmount;
  final int color;
  final bool obscureAmounts;
  final VoidCallback? onTap;

  const BoxCard({
    super.key,
    required this.name,
    required this.currentAmount,
    required this.endMonthAmount,
    required this.color,
    this.obscureAmounts = false,
    this.onTap,
  });

  String get _hidden => '•••••';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: 154,
        decoration: BoxDecoration(
          color: Color(color).withAlpha(242),
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.black.withAlpha(230),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              obscureAmounts ? _hidden : formatAmount(currentAmount),
              style: const TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                fontFamily: 'Roboto Condensed',
              ),
            ),
            const Spacer(),
            _MiniLabel(
              text: obscureAmounts ? _hidden : formatAmount(endMonthAmount),
              color: Colors.black12,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _MiniLabel({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
