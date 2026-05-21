import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class TenantAccessDeniedPage extends StatelessWidget {
  final String email;
  final String message;
  final bool isLoading;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  const TenantAccessDeniedPage({
    super.key,
    required this.email,
    required this.message,
    required this.isLoading,
    required this.onRetry,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Card(
            margin: const EdgeInsets.all(24),
            color: AppColors.panel,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    'Accesso farmacia bloccato',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    email.isEmpty ? 'Account Google non disponibile.' : 'Account: $email',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.errorBorder),
                    ),
                    child: Text(
                      message.trim().isEmpty ? 'Account non autorizzato.' : message.trim(),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.end,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: isLoading ? null : onSignOut,
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Cambia account'),
                      ),
                      FilledButton.icon(
                        onPressed: isLoading ? null : onRetry,
                        icon: isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded),
                        label: Text(isLoading ? 'Verifica...' : 'Verifica accesso'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
