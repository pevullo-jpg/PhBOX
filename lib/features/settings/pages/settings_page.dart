import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {

  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {

    return const Scaffold(
      body: Center(
        child: Text(
          "Pagina Impostazioni",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );

  }

}