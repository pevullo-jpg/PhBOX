import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'core/services/frontend_access_service.dart';
import 'core/session/phbox_frontend_access.dart';
import 'core/session/phbox_tenant_session.dart';
import 'features/auth/pages/frontend_access_status_page.dart';
import 'features/auth/pages/login_page.dart';
import 'features/dashboard/pages/dashboard_page.dart';
import 'features/families/pages/families_page.dart';
import 'features/settings/pages/settings_page.dart';
import 'shared/navigation/app_navigation.dart';
import 'shared/widgets/floating_page_menu.dart';
import 'theme/app_theme.dart';

class FarmaciaApp extends StatelessWidget {
  const FarmaciaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PhBOX',
      theme: AppTheme.darkTheme,
      home: const _FrontendAuthGate(),
    );
  }
}

class _FrontendAuthGate extends StatelessWidget {
  const _FrontendAuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _PhboxLoadingPage();
        }

        final User? user = snapshot.data;
        if (user == null) {
          PhboxTenantSession.instance.clear();
          return const LoginPage();
        }

        return _TenantAccessGate(user: user);
      },
    );
  }
}

class _TenantAccessGate extends StatefulWidget {
  final User user;

  const _TenantAccessGate({required this.user});

  @override
  State<_TenantAccessGate> createState() => _TenantAccessGateState();
}

class _TenantAccessGateState extends State<_TenantAccessGate> {
  late final FrontendAccessService _accessService;
  late Future<PhboxFrontendAccess> _future;

  @override
  void initState() {
    super.initState();
    _accessService = FrontendAccessService(firestore: FirebaseFirestore.instance);
    _future = _resolve();
  }

  @override
  void didUpdateWidget(covariant _TenantAccessGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid) {
      _future = _resolve();
    }
  }

  Future<PhboxFrontendAccess> _resolve() {
    return _accessService.resolveForUser(widget.user);
  }

  Future<void> _retry() async {
    setState(() {
      _future = _resolve();
    });
  }

  Future<void> _signOut() async {
    appNavigationIndex.value = 0;
    PhboxTenantSession.instance.clear();
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PhboxFrontendAccess>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<PhboxFrontendAccess> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _PhboxLoadingPage();
        }

        if (snapshot.hasError) {
          PhboxTenantSession.instance.clear();
          final Object? error = snapshot.error;
          final String message = error is FrontendAccessResolutionException
              ? error.message
              : 'Errore nel caricamento accesso frontend.';
          return FrontendAccessStatusPage(
            title: 'Accesso non configurato',
            message: message,
            onSignOut: _signOut,
            onRetry: _retry,
          );
        }

        final PhboxFrontendAccess access = snapshot.data!;
        if (!access.canOpenFrontend) {
          PhboxTenantSession.instance.activate(access);
          return FrontendAccessStatusPage(
            title: 'Frontend non disponibile',
            message: access.denyReason,
            tenantName: access.displayTenantLabel,
            onSignOut: _signOut,
            onRetry: _retry,
          );
        }

        PhboxTenantSession.instance.activate(access);
        return _FarmaciaShell(
          onLogout: _signOut,
        );
      },
    );
  }
}

class _FarmaciaShell extends StatefulWidget {
  final Future<void> Function() onLogout;

  const _FarmaciaShell({
    required this.onLogout,
  });

  @override
  State<_FarmaciaShell> createState() => _FarmaciaShellState();
}

class _FarmaciaShellState extends State<_FarmaciaShell> {
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

    return Scaffold(
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
                onLogout: () {
                  widget.onLogout();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PhboxLoadingPage extends StatelessWidget {
  const _PhboxLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}
