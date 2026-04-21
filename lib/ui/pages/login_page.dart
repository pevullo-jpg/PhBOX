import 'package:flutter/material.dart';

import 'package:family_boxes_2/models/auth_user.dart';
import 'package:family_boxes_2/services/auth_service.dart';

class LoginPage extends StatefulWidget {
  final Future<void> Function(AuthUser user) onAuthenticated;

  const LoginPage({
    super.key,
    required this.onAuthenticated,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();

  bool _registerMode = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _displayNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = _registerMode
          ? await AuthService.register(
              email: _emailCtrl.text,
              password: _passwordCtrl.text,
              displayName: _displayNameCtrl.text,
            )
          : await AuthService.signIn(
              email: _emailCtrl.text,
              password: _passwordCtrl.text,
            );
      await widget.onAuthenticated(user);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Autenticazione non riuscita.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E0A3E),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFF3D2966)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.account_circle_rounded, size: 56, color: Color(0xFFE91E8C)),
                    const SizedBox(height: 16),
                    Text(
                      _registerMode ? 'Crea account Family Box' : 'Accedi a Family Box',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _registerMode
                          ? 'Il trial di 3 mesi parte al primo accesso dell’account.'
                          : 'Login obbligatorio per usare l’app e leggere il tuo stato di accesso.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 20),
                    if (_registerMode) ...[
                      TextField(
                        controller: _displayNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nome visualizzato',
                          prefixIcon: Icon(Icons.badge_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_rounded),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFFF8A80), fontWeight: FontWeight.w700),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _loading ? null : _submit,
                      icon: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(_registerMode ? Icons.person_add_rounded : Icons.login_rounded),
                      label: Text(_registerMode ? 'Crea account' : 'Accedi'),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () {
                              setState(() {
                                _registerMode = !_registerMode;
                                _error = null;
                              });
                            },
                      child: Text(
                        _registerMode
                            ? 'Hai già un account? Accedi'
                            : 'Non hai un account? Registrati',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
