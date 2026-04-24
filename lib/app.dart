import 'package:flutter/material.dart';

import 'features/dashboard/pages/dashboard_page.dart';
import 'features/families/pages/families_page.dart';
import 'features/settings/pages/settings_page.dart';
import 'shared/navigation/app_navigation.dart';
import 'shared/widgets/floating_page_menu.dart';
import 'theme/app_theme.dart';

class FarmaciaApp extends StatefulWidget {
  const FarmaciaApp({super.key});

  @override
  State<FarmaciaApp> createState() => _FarmaciaAppState();
}

class _FarmaciaAppState extends State<FarmaciaApp> {
  @override
  void initState() {
    super.initState();
    appNavigationIndex.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      const DashboardPage(),
      const FamiliesPage(),
      const SettingsPage(),
    ];

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PhBOX',
      theme: AppTheme.darkTheme,
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: ValueListenableBuilder<int>(
          valueListenable: appNavigationIndex,
          builder: (BuildContext context, int currentIndex, _) {
            return Stack(
              children: <Widget>[
                IndexedStack(
                  index: currentIndex,
                  children: pages,
                ),
                FloatingPageMenu(
                  currentIndex: currentIndex,
                  onSelected: (int index) {
                    if (appNavigationIndex.value != index) {
                      appNavigationIndex.value = index;
                    }
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
