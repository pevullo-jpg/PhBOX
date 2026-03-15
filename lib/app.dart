import 'package:flutter/material.dart';
import 'features/dashboard/pages/dashboard_page.dart';
import 'features/expiries/pages/expiries_page.dart';
import 'features/settings/pages/settings_page.dart';

class FarmaciaApp extends StatefulWidget {
  const FarmaciaApp({super.key});

  @override
  State<FarmaciaApp> createState() => _FarmaciaAppState();
}

class _FarmaciaAppState extends State<FarmaciaApp> {

  int index = 0;

  @override
  Widget build(BuildContext context) {

    final pages = [
      const DashboardPage(),
      const ExpiriesPage(),
      const SettingsPage(),
    ];

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Row(
          children: [

            Container(
              width: 220,
              color: const Color(0xFF070707),
              child: Column(
                children: [

                  const SizedBox(height: 40),

                  ListTile(
                    title: const Text("Dashboard"),
                    onTap: () => setState(() => index = 0),
                  ),

                  ListTile(
                    title: const Text("Scadenze"),
                    onTap: () => setState(() => index = 1),
                  ),

                  ListTile(
                    title: const Text("Impostazioni"),
                    onTap: () => setState(() => index = 2),
                  ),

                ],
              ),
            ),

            Expanded(child: pages[index])

          ],
        ),
      ),
    );

  }

}