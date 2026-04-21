import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'engine/budget_engine.dart';
import 'models/access_mode.dart';
import 'models/app_data.dart';
import 'models/auth_user.dart';
import 'models/box.dart';
import 'models/entitlement.dart';
import 'services/access_service.dart';
import 'services/auth_service.dart';
import 'services/backup_service.dart';
import 'services/billing_service.dart';
import 'services/entitlement_service.dart';
import 'services/storage_service.dart';
import 'ui/pages/first_install_setup_dialog.dart';
import 'ui/pages/backend_setup_page.dart';
import 'ui/pages/home_page.dart';
import 'ui/pages/login_page.dart';
import 'ui/pages/movimenti_page.dart';
import 'ui/pages/ricorrenze_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FamilyBoxesApp());
}

class FamilyBoxesApp extends StatelessWidget {
  const FamilyBoxesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Family Boxes',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF120021),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE91E8C),
          secondary: Color(0xFF00F5FF),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E0A3E),
          elevation: 0,
        ),
      ),
      home: const _Bootstrap(),
    );
  }
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  BudgetEngine? engine;
  AuthUser? _currentUser;
  Entitlement? _entitlement;
  AccessMode _accessMode = AccessMode.readOnly;
  AccessMode? _debugOverride;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _requestPermissions() async {
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();
  }

  Future<void> _init() async {
    await _requestPermissions();

    if (!AuthService.isBackendConfigured) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        engine = null;
        _currentUser = null;
        _entitlement = null;
      });
      return;
    }

    final signedUser = await AuthService.currentUser();
    if (signedUser == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        engine = null;
        _currentUser = null;
        _entitlement = null;
      });
      return;
    }
    await _loadAuthenticatedSession(signedUser);
  }

  Future<void> _loadAuthenticatedSession(AuthUser user) async {
    StorageService.setScope(user.safeStorageScope);
    _debugOverride = kDebugMode ? await AccessService.loadDebugOverride() : null;

    final data = await StorageService.loadData();
    final isFirstInstall = data == null;
    final entitlement = await EntitlementService.refreshForUser(user);
    final accessMode = entitlement.accessModeAt(
      DateTime.now(),
      debugOverride: _debugOverride,
    );

    final nextEngine = BudgetEngine(data: data ?? AppData.initialTemplate());
    nextEngine.setWritesLocked(!accessMode.hasFullAccess);

    setState(() {
      engine = nextEngine;
      _currentUser = user;
      _entitlement = entitlement;
      _accessMode = accessMode;
      _loading = false;
    });

    unawaited(
      BillingService.instance.bindUser(
        user,
        onEntitlementChanged: _refreshEntitlement,
      ),
    );

    if (isFirstInstall && mounted) {
      final familyMembers = await showFirstInstallSetupDialog(context);
      _applyInitialFamilyBoxes(familyMembers);
    }

    if (_accessMode.hasFullAccess) {
      await _runWritableBootTasks();
    }
  }

  Future<void> _runWritableBootTasks() async {
    if (engine == null || !_accessMode.hasFullAccess) return;

    engine!.createMonthlySnapshotIfNeeded();
    engine!.materializeCurrentMonthRecurringTransactions();
    engine!.materializeCurrentMonthCashflowTransactions();
    engine!.autoConfirmDueSingleTransactions();
    engine!.autoConfirmDueAutomaticRecurringTransactions();

    await StorageService.saveData(engine!.exportData());
    await BackupService.runAutoBackupIfDue(engine!.exportData());

    if (!mounted) return;
    setState(() {});
  }

  void _applyInitialFamilyBoxes(List<String> familyMembers) {
    if (engine == null || familyMembers.isEmpty || !_accessMode.hasFullAccess) {
      return;
    }

    const personalColors = [
      4294929205,
      4286263230,
      4293467788,
      4293212469,
    ];

    final existingNames = engine!.boxes
        .map((b) => b.name.trim().toUpperCase())
        .toSet();

    int colorIndex = 0;
    for (final member in familyMembers) {
      final normalized = member.trim().toUpperCase();
      if (normalized.isEmpty || existingNames.contains(normalized)) {
        continue;
      }

      engine!.addBox(
        BoxModel(
          id: 'box_personal_${engine!.newId()}',
          name: normalized,
          initialAmount: 0.0,
          color: personalColors[colorIndex % personalColors.length],
        ),
      );
      existingNames.add(normalized);
      colorIndex++;
    }

    StorageService.saveData(engine!.exportData());
    setState(() {});
  }

  Future<void> _refresh() async {
    if (engine == null) return;

    if (_accessMode.hasFullAccess) {
      engine!.createMonthlySnapshotIfNeeded();
      engine!.materializeCurrentMonthRecurringTransactions();
      engine!.materializeCurrentMonthCashflowTransactions();
      engine!.autoConfirmDueSingleTransactions();
      engine!.autoConfirmDueAutomaticRecurringTransactions();

      await StorageService.saveData(engine!.exportData());
      await BackupService.runAutoBackupIfDue(engine!.exportData());
    }

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _handleAuthenticated(AuthUser user) async {
    setState(() {
      _loading = true;
    });
    await _loadAuthenticatedSession(user);
  }

  Future<void> _refreshEntitlement() async {
    if (_currentUser == null || engine == null) return;

    _debugOverride = kDebugMode ? await AccessService.loadDebugOverride() : null;
    final entitlement = await EntitlementService.refreshForUser(_currentUser!);
    final accessMode = entitlement.accessModeAt(
      DateTime.now(),
      debugOverride: _debugOverride,
    );

    engine!.setWritesLocked(!accessMode.hasFullAccess);

    setState(() {
      _entitlement = entitlement;
      _accessMode = accessMode;
    });

    if (accessMode.hasFullAccess) {
      await _refresh();
    }
  }

  Future<void> _signOut() async {
    await BillingService.instance.unbindUser();
    await AuthService.signOut();
    StorageService.setScope(null);
    if (!mounted) return;
    setState(() {
      engine = null;
      _currentUser = null;
      _entitlement = null;
      _accessMode = AccessMode.readOnly;
      _debugOverride = null;
      _loading = false;
    });
  }

  Future<void> _setDebugAccessOverride(AccessMode? mode) async {
    if (!kDebugMode) return;
    await AccessService.saveDebugOverride(mode);
    await _refreshEntitlement();
  }

  @override
  void dispose() {
    unawaited(BillingService.instance.dispose());
    super.dispose();
  }

  Future<void> _activateDebugSubscription() async {
    if (!kDebugMode || _currentUser == null) return;
    await EntitlementService.activateDebugSubscription(_currentUser!);
    await _refreshEntitlement();
  }

  Future<void> _resetDebugTrial() async {
    if (!kDebugMode || _currentUser == null) return;
    await EntitlementService.resetTrialFromNow(_currentUser!);
    await _refreshEntitlement();
  }

  Future<void> _forceDebugReadOnly() async {
    if (!kDebugMode || _currentUser == null) return;
    await EntitlementService.forceReadOnlyNow(_currentUser!);
    await _refreshEntitlement();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!AuthService.isBackendConfigured) {
      return const BackendSetupPage();
    }

    if (_currentUser == null) {
      return LoginPage(onAuthenticated: _handleAuthenticated);
    }

    if (engine == null || _entitlement == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return _MainShell(
      engine: engine!,
      currentUser: _currentUser!,
      entitlement: _entitlement!,
      accessMode: _accessMode,
      debugOverride: _debugOverride,
      onChanged: _refresh,
      onSignOut: _signOut,
      onEntitlementRefresh: _refreshEntitlement,
      onDebugAccessOverrideChanged: _setDebugAccessOverride,
      onActivateDebugSubscription: _activateDebugSubscription,
      onResetDebugTrial: _resetDebugTrial,
      onForceDebugReadOnly: _forceDebugReadOnly,
    );
  }
}

class _MainShell extends StatefulWidget {
  final BudgetEngine engine;
  final AuthUser currentUser;
  final Entitlement entitlement;
  final AccessMode accessMode;
  final AccessMode? debugOverride;
  final Future<void> Function() onChanged;
  final Future<void> Function() onSignOut;
  final Future<void> Function() onEntitlementRefresh;
  final Future<void> Function(AccessMode? mode) onDebugAccessOverrideChanged;
  final Future<void> Function() onActivateDebugSubscription;
  final Future<void> Function() onResetDebugTrial;
  final Future<void> Function() onForceDebugReadOnly;

  const _MainShell({
    required this.engine,
    required this.currentUser,
    required this.entitlement,
    required this.accessMode,
    required this.debugOverride,
    required this.onChanged,
    required this.onSignOut,
    required this.onEntitlementRefresh,
    required this.onDebugAccessOverrideChanged,
    required this.onActivateDebugSubscription,
    required this.onResetDebugTrial,
    required this.onForceDebugReadOnly,
  });

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        engine: widget.engine,
        onChanged: widget.onChanged,
        accessMode: widget.accessMode,
        currentUser: widget.currentUser,
        entitlement: widget.entitlement,
        debugOverride: widget.debugOverride,
        onSignOut: widget.onSignOut,
        onEntitlementRefresh: widget.onEntitlementRefresh,
        onDebugAccessOverrideChanged: widget.onDebugAccessOverrideChanged,
        onActivateDebugSubscription: widget.onActivateDebugSubscription,
        onResetDebugTrial: widget.onResetDebugTrial,
        onForceDebugReadOnly: widget.onForceDebugReadOnly,
      ),
      MovimentiPage(
        engine: widget.engine,
        onChanged: widget.onChanged,
        accessMode: widget.accessMode,
      ),
      RicorrenzePage(
        engine: widget.engine,
        onChanged: widget.onChanged,
        accessMode: widget.accessMode,
      ),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        backgroundColor: const Color(0xFF1E0A3E),
        selectedItemColor: const Color(0xFFE91E8C),
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        onTap: (i) {
          setState(() {
            _index = i;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.swap_vert_rounded),
            label: 'Movimenti',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.repeat_rounded),
            label: 'Ricorrenze',
          ),
        ],
      ),
    );
  }
}
