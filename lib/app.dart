import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'core/services/backup_export_service.dart';
import 'core/services/backup_scheduler_service.dart';
import 'data/datasources/firestore_firebase_datasource.dart';
import 'data/repositories/advances_repository.dart';
import 'data/repositories/bookings_repository.dart';
import 'data/repositories/debts_repository.dart';
import 'data/repositories/patients_repository.dart';
import 'data/repositories/settings_repository.dart';
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

    final FirestoreFirebaseDatasource datasource =
        FirestoreFirebaseDatasource(FirebaseFirestore.instance);
    final SettingsRepository settingsRepository =
        SettingsRepository(datasource: datasource);
    final BackupExportService backupExportService = BackupExportService(
      firestore: FirebaseFirestore.instance,
      settingsRepository: settingsRepository,
      patientsRepository: PatientsRepository(datasource: datasource),
      debtsRepository: DebtsRepository(datasource: datasource),
      advancesRepository: AdvancesRepository(datasource: datasource),
      bookingsRepository: BookingsRepository(datasource: datasource),
    );
    BackupSchedulerService.instance.initialize(
      backupExportService: backupExportService,
      settingsRepository: settingsRepository,
    );
  }

  @override
  void dispose() {
    BackupSchedulerService.instance.dispose();
    super.dispose();
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
          builder: (context, currentIndex, _) {
            return Stack(
              children: [
                IndexedStack(
                  index: currentIndex,
                  children: pages,
                ),
                FloatingPageMenu(
                  currentIndex: currentIndex,
                  onSelected: (index) {
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
