import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class TenantLoginPage extends StatefulWidget {
  const TenantLoginPage({super.key});

  @override
  State<TenantLoginPage> createState() => _TenantLoginPageState();
}

class _TenantLoginPageState extends State<TenantLoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _error = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmailPassword() async {
    if (_isLoading) {
      return;
    }

    final String email = _emailController.text.trim();
    final String password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Inserisci email e password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    String nextError = '';
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      nextError = _firebaseAuthMessage(e);
    } catch (e) {
      nextError = 'Accesso non riuscito: $e';
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = false;
      _error = nextError;
    });
  }

  String _firebaseAuthMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Email non valida.';
      case 'user-disabled':
        return 'Account disabilitato in Firebase Authentication.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Credenziali non valide.';
      case 'too-many-requests':
        return 'Troppi tentativi. Attendere e riprovare.';
      default:
        return error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Accesso non riuscito.';
    }
  }

  Widget _buildErrorPanel(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.85)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    'PhBOX',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Accesso farmacia tramite account Firebase autorizzato dal SuperBack.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const <String>[AutofillHints.email],
                    enabled: !_isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    enabled: !_isLoading,
                    autofillHints: const <String>[AutofillHints.password],
                    onSubmitted: (_) => _signInWithEmailPassword(),
                    decoration: const InputDecoration(
                      labelText: 'Password',
                    ),
                  ),
                  if (_error.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 18),
                    _buildErrorPanel(_error),
                  ],
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _signInWithEmailPassword,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login_rounded),
                    label: Text(_isLoading ? 'Accesso...' : 'Entra'),
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
