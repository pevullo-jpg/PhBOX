import 'package:flutter/material.dart';
import 'features/dashboard/pages/dashboard_page.dart';
import 'features/expiries/pages/expiries_page.dart';
import 'features/settings/pages/settings_page.dart';
import 'theme/app_theme.dart';

class FarmaciaApp extends StatefulWidget {
  const FarmaciaApp({super.key});

  @override
  State<FarmaciaApp> createState() => _FarmaciaAppState();
}

class _FarmaciaAppState extends State<FarmaciaApp> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      const DashboardPage(),
      const ExpiriesPage(),
      const SettingsPage(),
    ];

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PhBOX',
      theme: AppTheme.darkTheme,
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: <Widget>[
            Container(
              width: 220,
              color: const Color(0xFF070707),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: <Widget>[
                  const SizedBox(height: 20),
                  const Text(
                    'PhBOX',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 30),
                  ListTile(
                    selected: currentIndex == 0,
                    selectedTileColor: const Color(0xFF1C1C1C),
                    title: Text(
                      'Dashboard',
                      style: TextStyle(
                        color: currentIndex == 0 ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () => setState(() => currentIndex = 0),
                  ),
                  ListTile(
                    selected: currentIndex == 1,
                    selectedTileColor: const Color(0xFF1C1C1C),
                    title: Text(
                      'Scadenze',
                      style: TextStyle(
                        color: currentIndex == 1 ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () => setState(() => currentIndex = 1),
                  ),
                  ListTile(
                    selected: currentIndex == 2,
                    selectedTileColor: const Color(0xFF1C1C1C),
                    title: Text(
                      'Impostazioni',
                      style: TextStyle(
                        color: currentIndex == 2 ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () => setState(() => currentIndex = 2),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: AppColors.background,
                child: pages[currentIndex],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
