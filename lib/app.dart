import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data/datasources/firestore_firebase_datasource.dart';
import 'data/models/backend_auth_status.dart';
import 'data/models/tenant_access.dart';
import 'data/repositories/backend_auth_status_repository.dart';
import 'data/repositories/tenant_access_repository.dart';
import 'features/auth/pages/tenant_access_denied_page.dart';
import 'features/auth/pages/tenant_login_page.dart';
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
  late final BackendAuthStatusRepository _backendAuthStatusRepository;
  late final TenantAccessRepository _tenantAccessRepository;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  BackendAuthStatus _backendAuthStatus = BackendAuthStatus.emptyOk();
  TenantAccess? _tenantAccess;
  String _tenantGateError = '';
  bool _backendAuthLoading = false;
  bool _tenantGateLoading = true;
  bool _tenantSignInLoading = false;

  @override
  void initState() {
    super.initState();
    appNavigationIndex.value = 0;
    final datasource = FirestoreFirebaseDatasource(FirebaseFirestore.instance);
    _backendAuthStatusRepository = BackendAuthStatusRepository(datasource: datasource);
    _tenantAccessRepository = TenantAccessRepository(firestore: FirebaseFirestore.instance);
    _bootstrapTenantGate();
  }

  Future<void> _bootstrapTenantGate() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _tenantAccess = null;
        _tenantGateError = '';
        _tenantGateLoading = false;
      });
      return;
    }
    await _loadTenantAccessForUser(user);
  }

  Future<void> _loadTenantAccessForUser(User user) async {
    final String email = user.email?.trim().toLowerCase() ?? '';
    if (!mounted) return;
    setState(() {
      _tenantGateLoading = true;
      _tenantGateError = '';
    });

    try {
      if (email.isEmpty) {
        throw Exception('Account Google privo di email verificabile.');
      }

      final TenantAccess? access = await _tenantAccessRepository.getForLoginEmail(email);
      if (!mounted) return;

      if (access == null) {
        setState(() {
          _tenantAccess = null;
          _tenantGateError = 'Nessun documento tenant_access/$email trovato. Autorizzare la farmacia dal SuperBack.';
          _tenantGateLoading = false;
        });
        return;
      }

      if (!access.isAllowed) {
        setState(() {
          _tenantAccess = null;
          _tenantGateError = access.blockReason;
          _tenantGateLoading = false;
        });
        return;
      }

      setState(() {
        _tenantAccess = access;
        _tenantGateError = '';
        _tenantGateLoading = false;
      });
      await _refreshBackendAuthStatus();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _tenantAccess = null;
        _tenantGateError = 'Impossibile verificare accesso farmacia: $e';
        _tenantGateLoading = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_tenantSignInLoading) {
      return;
    }
    setState(() {
      _tenantSignInLoading = true;
      _tenantGateError = '';
    });

    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        if (!mounted) return;
        setState(() {
          _tenantSignInLoading = false;
        });
        return;
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;
      if (user == null) {
        throw Exception('Login Firebase non completato.');
      }
      await _loadTenantAccessForUser(user);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _tenantAccess = null;
        _tenantGateError = 'Accesso Google/Firebase non riuscito: $e';
      });
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _tenantSignInLoading = false;
    });
  }

  Future<void> _signOutTenant() async {
    await _googleSignIn.signOut();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    setState(() {
      _tenantAccess = null;
      _tenantGateError = '';
      _tenantGateLoading = false;
      _backendAuthStatus = BackendAuthStatus.emptyOk();
    });
  }

  Future<void> _refreshBackendAuthStatus() async {
    if (_tenantAccess == null || _backendAuthLoading) {
      return;
    }
    setState(() {
      _backendAuthLoading = true;
    });
    try {
      final BackendAuthStatus status = await _backendAuthStatusRepository.getMainStatus();
      if (!mounted) return;
      setState(() {
        _backendAuthStatus = status;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _backendAuthStatus = BackendAuthStatus(
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
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _backendAuthLoading = false;
      });
    }
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

  Widget _buildTenantGate() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (_tenantGateLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (user == null) {
      return TenantLoginPage(
        isLoading: _tenantSignInLoading,
        errorMessage: _tenantGateError,
        onSignIn: _signInWithGoogle,
      );
    }
    return TenantAccessDeniedPage(
      email: user.email?.trim().toLowerCase() ?? '',
      message: _tenantGateError,
      isLoading: _tenantGateLoading,
      onRetry: _bootstrapTenantGate,
      onSignOut: _signOutTenant,
    );
  }

  @override
  Widget build(BuildContext context) {
    final TenantAccess? tenantAccess = _tenantAccess;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PhBOX',
      theme: AppTheme.darkTheme,
      home: tenantAccess == null
          ? _buildTenantGate()
          : Scaffold(
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
                      ),
                      _buildBackendAuthBanner(),
                    ],
                  );
                },
              ),
            ),
    );
  }
}
