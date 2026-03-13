import 'package:flutter/material.dart';

class TableHeader extends StatelessWidget {
  final String text;

  const TableHeader(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
    );
  }
}
