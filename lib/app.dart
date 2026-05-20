import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data/datasources/firestore_firebase_datasource.dart';
import 'data/models/backend_auth_status.dart';
import 'data/repositories/backend_auth_status_repository.dart';
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

  @override
  Widget build(BuildContext context) {
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
