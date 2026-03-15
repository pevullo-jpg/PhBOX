
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

  int currentIndex = 0;

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
        backgroundColor: const Color(0xFF0A0A0A),
        body: Row(
          children: [

            Container(
              width: 220,
              color: const Color(0xFF070707),
              child: Column(
                children: [

                  const SizedBox(height: 40),

                  const Text(
                    "Farmacia Desk",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 30),

                  ListTile(
                    title: const Text(
                      "Dashboard",
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () => setState(() => currentIndex = 0),
                  ),

                  ListTile(
                    title: const Text(
                      "Scadenze",
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () => setState(() => currentIndex = 1),
                  ),

                  ListTile(
                    title: const Text(
                      "Impostazioni",
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () => setState(() => currentIndex = 2),
                  ),

                ],
              ),
            ),

            Expanded(
              child: Container(
                color: const Color(0xFF0A0A0A),
                child: pages[currentIndex],
              ),
            )

          ],
        ),
      ),
    );

  }

}
