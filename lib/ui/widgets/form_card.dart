import 'package:flutter/material.dart';

class FormCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const FormCard({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E0A3E),
        borderRadius: BorderRadius.circular(22),
      ),
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
  }
}
