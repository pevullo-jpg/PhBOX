import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class FrontendAccessStatusPage extends StatelessWidget {
  final String title;
  final String message;
  final String? tenantName;
  final VoidCallback onSignOut;
  final VoidCallback? onRetry;
  final bool loading;

  const FrontendAccessStatusPage({
    super.key,
    required this.title,
    required this.message,
    required this.onSignOut,
    this.tenantName,
    this.onRetry,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            color: AppColors.panel,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: Colors.white10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.lock_outline_rounded, size: 44, color: AppColors.yellow),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  if ((tenantName ?? '').trim().isNotEmpty) ...<Widget>[
                    Text(
                      tenantName!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.yellow,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    message,
                    style: const TextStyle(color: Colors.white70, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: <Widget>[
                      if (onRetry != null)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: loading ? null : onRetry,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Riprova'),
                          ),
                        ),
                      if (onRetry != null) const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: loading ? null : onSignOut,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.yellow,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Esci'),
                        ),
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
