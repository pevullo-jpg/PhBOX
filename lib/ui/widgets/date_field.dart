import 'package:flutter/material.dart';

class DataField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  const DataField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15),
            ),
          ),
          if (onTap != null) const Icon(Icons.edit_calendar_rounded),
        ],
      ),
    );

    if (onTap == null) return child;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: child,
    );
  }
}
