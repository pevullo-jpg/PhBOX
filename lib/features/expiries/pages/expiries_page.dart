
import 'package:flutter/material.dart';

class ExpiriesPage extends StatelessWidget {

  const ExpiriesPage({super.key});

  @override
  Widget build(BuildContext context) {

    return const Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      body: Center(
        child: Text(
          "Scadenze",
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

  }

}
