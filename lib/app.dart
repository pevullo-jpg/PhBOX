import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data/datasources/firestore_firebase_datasource.dart';
import 'data/models/backend_auth_status.dart';
import 'data/models/tenant_access.dart';
import 'data/repositories/backend_auth_status_repository.dart';
import 'data/repositories/tenant_access_repository.dart';
import 'data/tenancy/tenant_path_resolver.dart';
import 'features/auth/models/tenant_session.dart';
import 'features/auth/pages/tenant_access_denied_page.dart';
import 'features/auth/pages/tenant_login_page.dart';
import 'features/auth/services/email_password_session_guard.dart';
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
      home: const _TenantGate(),
    );
  }
}

class _TenantGate extends StatelessWidget {
  const _TenantGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final User? user = snapshot.data;
        if (user == null) {
          return const TenantLoginPage();
        }
        final String email = _normalizedEmail(user.email ?? '');
        final String? invalidSessionReason = _invalidEmailPasswordSessionReason(
          user: user,
          normalizedEmail: email,
        );
        if (invalidSessionReason != null) {
          return const _InvalidSessionLoginReset();
        }
        return _TenantAccessGate(user: user);
      },
    );
  }

  String _normalizedEmail(String value) {
    return TenantAccessRepository.normalizeLoginEmail(value);
  }

  String? _invalidEmailPasswordSessionReason({
    required User user,
    required String normalizedEmail,
  }) {
    if (user.isAnonymous) {
      return 'Accesso anonimo non consentito.';
    }
    if (normalizedEmail.isEmpty) {
      return 'Account Firebase privo di email verificabile.';
    }
    final bool hasMatchingPasswordProvider = user.providerData.any((UserInfo provider) {
      final String providerEmail = _normalizedEmail(provider.email ?? '');
      return provider.providerId == EmailAuthProvider.PROVIDER_ID &&
          providerEmail.isNotEmpty &&
          providerEmail == normalizedEmail;
    });
    if (!hasMatchingPasswordProvider) {
      return 'Accesso consentito solo con account email/password registrato in Firebase Authentication.';
    }
    if (!EmailPasswordSessionGuard.isConfirmed(user: user, normalizedEmail: normalizedEmail)) {
      return 'Sessione email/password non confermata in questo browser. Esegui nuovamente il login.';
    }
    return null;
  }
}

class _InvalidSessionLoginReset extends StatefulWidget {
  const _InvalidSessionLoginReset();

  @override
  State<_InvalidSessionLoginReset> createState() => _InvalidSessionLoginResetState();
}

class _InvalidSessionLoginResetState extends State<_InvalidSessionLoginReset> {
  bool _resetStarted = false;

  @override
  void initState() {
    super.initState();
    _resetInvalidSession();
  }

  Future<void> _resetInvalidSession() async {
    if (_resetStarted) {
      return;
    }
    _resetStarted = true;
    EmailPasswordSessionGuard.clear();
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return const TenantLoginPage();
  }
}

class _TenantAccessGate extends StatefulWidget {
  final User user;

  const _TenantAccessGate({required this.user});

  @override
  State<_TenantAccessGate> createState() => _TenantAccessGateState();
}

class _TenantAccessGateState extends State<_TenantAccessGate> {
  late final TenantAccessRepository _tenantAccessRepository = TenantAccessRepository(
    firestore: FirebaseFirestore.instance,
  );
  late Future<TenantAccess?> _tenantAccessFuture;
  late String _email;

  @override
  void initState() {
    super.initState();
    _email = _normalizedEmail(widget.user);
    _tenantAccessFuture = _tenantAccessRepository.getByLoginEmail(_email);
  }

  @override
  void didUpdateWidget(covariant _TenantAccessGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String nextEmail = _normalizedEmail(widget.user);
    if (nextEmail != _email || oldWidget.user.uid != widget.user.uid) {
      _email = nextEmail;
      _tenantAccessFuture = _tenantAccessRepository.getByLoginEmail(_email);
    }
  }

  void _retryTenantAccess() {
    setState(() {
      _tenantAccessFuture = _tenantAccessRepository.getByLoginEmail(_email);
    });
  }

  String _normalizedEmail(User user) {
    return TenantAccessRepository.normalizeLoginEmail(user.email ?? '');
  }

  @override
  Widget build(BuildContext context) {
    if (_email.isEmpty) {
      return const _InvalidSessionLoginReset();
    }

    return FutureBuilder<TenantAccess?>(
      future: _tenantAccessFuture,
      builder: (BuildContext context, AsyncSnapshot<TenantAccess?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return TenantAccessDeniedPage(
            email: _email,
            reason: 'Impossibile leggere tenant_access/{$_email}: ${snapshot.error}',
            onRetry: _retryTenantAccess,
          );
        }
        final TenantAccess? tenantAccess = snapshot.data;
        if (tenantAccess == null) {
          return TenantAccessDeniedPage(
            email: _email,
            reason: 'Nessun tenant_access configurato per questo account.',
            onRetry: _retryTenantAccess,
          );
        }
        if (!tenantAccess.isAllowed) {
          return TenantAccessDeniedPage(
            email: _email,
            reason: tenantAccess.deniedReason,
            onRetry: _retryTenantAccess,
          );
        }
        return _PhboxShell(
          tenantSession: TenantSession.fromTenantAccess(tenantAccess),
        );
      },
    );
  }
}

class _PhboxShell extends StatefulWidget {
  final TenantSession tenantSession;

  const _PhboxShell({required this.tenantSession});

  @override
  State<_PhboxShell> createState() => _PhboxShellState();
}

class _PhboxShellState extends State<_PhboxShell> {
  late final BackendAuthStatusRepository _backendAuthStatusRepository;
  BackendAuthStatus _backendAuthStatus = BackendAuthStatus.emptyOk();
  bool _backendAuthLoading = false;

  @override
  void initState() {
    super.initState();
    appNavigationIndex.value = 0;
    final datasource = FirestoreFirebaseDatasource(FirebaseFirestore.instance);
    _backendAuthStatusRepository = BackendAuthStatusRepository(datasource: datasource);
    _refreshBackendAuthStatus();
  }

  Future<void> _refreshBackendAuthStatus() async {
    if (_backendAuthLoading) {
      return;
    }
    setState(() {
      _backendAuthLoading = true;
    });

    BackendAuthStatus nextStatus = _backendAuthStatus;
    try {
      nextStatus = await _backendAuthStatusRepository.getMainStatus();
    } catch (e) {
      nextStatus = BackendAuthStatus(
        ok: false,
        authRequired: false,
        status: 'error',
        message: 'Impossibile leggere lo stato backend: $e',
        errorKind: 'frontend_backend_auth_status_read_failed',
        authUrl: '',
        expectedEmail: '',
        executingEmail: '',
        checkedAt: DateTime.now(),
      );
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _backendAuthStatus = nextStatus;
      _backendAuthLoading = false;
    });
  }

  Future<void> _openBackendAuthCenter() async {
    final String authUrl = _backendAuthStatus.authUrl.trim();
    if (authUrl.isEmpty) {
      await _refreshBackendAuthStatus();
      return;
    }
    final Uri? uri = Uri.tryParse(authUrl);
    if (uri == null) {
      await _refreshBackendAuthStatus();
      return;
    }
    await launchUrl(uri, webOnlyWindowName: '_blank');
  }

  Future<void> _signOut() async {
    EmailPasswordSessionGuard.clear();
    appNavigationIndex.value = 0;
    await FirebaseAuth.instance.signOut();
  }

  Widget _buildPage(int currentIndex) {
    switch (currentIndex) {
      case 1:
        return const FamiliesPage();
      case 2:
        return const SettingsPage();
      case 0:
      default:
        return const DashboardPage();
    }
  }

  Widget _buildBackendAuthBanner() {
    final BackendAuthStatus status = _backendAuthStatus;
    if (!status.shouldShowBanner) {
      return const SizedBox.shrink();
    }
    final bool canOpenAuthCenter = status.authUrl.trim().isNotEmpty;
    return Positioned(
      top: 18,
      left: 24,
      right: 24,
      child: SafeArea(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF3A2323),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE08A3E), width: 1.4),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 22,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFF4BC1C), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        status.title,
                        style: const TextStyle(
                          color: Color(0xFFFAFAFA),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        status.effectiveMessage,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFE0E0E0),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (status.expectedEmail.isNotEmpty || status.executingEmail.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          'Richiesto: ${status.expectedEmail.isEmpty ? '-' : status.expectedEmail} · Attuale: ${status.executingEmail.isEmpty ? '-' : status.executingEmail}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFBDBDBD),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (canOpenAuthCenter)
                  FilledButton(
                    onPressed: _openBackendAuthCenter,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF4BC1C),
                      foregroundColor: const Color(0xFF121212),
                    ),
                    child: Text(status.actionLabel),
                  ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _backendAuthLoading ? null : _refreshBackendAuthStatus,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFAFAFA),
                    side: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  child: Text(_backendAuthLoading ? 'Verifica...' : 'Verifica'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TenantSessionScope(
      session: widget.tenantSession,
      child: TenantPathScope(
        resolver: TenantPathResolver.legacyRoot(
          tenantId: widget.tenantSession.tenantId,
        ),
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: ValueListenableBuilder<int>(
            valueListenable: appNavigationIndex,
            builder: (context, currentIndex, _) {
              return Stack(
                children: [
                  _buildPage(currentIndex),
                  FloatingPageMenu(
                    currentIndex: currentIndex,
                    onSelected: (index) {
                      if (appNavigationIndex.value != index) {
                        appNavigationIndex.value = index;
                      }
                    },
                    onLogout: _signOut,
                  ),
                  _buildBackendAuthBanner(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
