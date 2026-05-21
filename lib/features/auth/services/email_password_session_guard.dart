import 'dart:convert';
import 'dart:html' as html;

import 'package:firebase_auth/firebase_auth.dart';

import '../../../data/repositories/tenant_access_repository.dart';

class EmailPasswordSessionGuard {
  static const String _storageKey = 'phbox_email_password_session_v1';

  static String? _confirmedUid;
  static String? _confirmedEmail;
  static DateTime? _confirmedAt;

  const EmailPasswordSessionGuard._();

  static void markConfirmed(User? user) {
    final String uid = user?.uid.trim() ?? '';
    final String email = TenantAccessRepository.normalizeLoginEmail(user?.email ?? '');
    if (uid.isEmpty || email.isEmpty) {
      clear();
      return;
    }

    final DateTime confirmedAt = DateTime.now().toUtc();
    _confirmedUid = uid;
    _confirmedEmail = email;
    _confirmedAt = confirmedAt;

    final Map<String, String> payload = <String, String>{
      'uid': uid,
      'email': email,
      'confirmedAt': confirmedAt.toIso8601String(),
      'source': 'email_password',
    };

    try {
      html.window.localStorage[_storageKey] = jsonEncode(payload);
    } catch (_) {
      // In-memory confirmation remains valid for the current runtime.
    }
  }

  static bool isConfirmed({
    required User user,
    required String normalizedEmail,
  }) {
    if (_matchesCurrentUser(user: user, normalizedEmail: normalizedEmail)) {
      return true;
    }

    final Map<String, String>? payload = _readStoredPayload();
    if (payload == null) {
      return false;
    }

    final String storedUid = payload['uid'] ?? '';
    final String storedEmail = payload['email'] ?? '';
    final String storedSource = payload['source'] ?? '';
    final String storedConfirmedAt = payload['confirmedAt'] ?? '';

    if (storedSource != 'email_password' ||
        storedUid != user.uid ||
        storedEmail != normalizedEmail ||
        storedConfirmedAt.isEmpty) {
      clear();
      return false;
    }

    final DateTime? parsedConfirmedAt = DateTime.tryParse(storedConfirmedAt)?.toUtc();
    if (parsedConfirmedAt == null) {
      clear();
      return false;
    }

    _confirmedUid = storedUid;
    _confirmedEmail = storedEmail;
    _confirmedAt = parsedConfirmedAt;
    return true;
  }

  static void clear() {
    _confirmedUid = null;
    _confirmedEmail = null;
    _confirmedAt = null;
    try {
      html.window.localStorage.remove(_storageKey);
    } catch (_) {}
  }

  static bool _matchesCurrentUser({
    required User user,
    required String normalizedEmail,
  }) {
    return _confirmedUid == user.uid &&
        _confirmedEmail == normalizedEmail &&
        _confirmedAt != null;
  }

  static Map<String, String>? _readStoredPayload() {
    String? raw;
    try {
      raw = html.window.localStorage[_storageKey];
    } catch (_) {
      return null;
    }
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        clear();
        return null;
      }
      return <String, String>{
        for (final MapEntry<String, dynamic> entry in decoded.entries)
          entry.key: (entry.value ?? '').toString(),
      };
    } catch (_) {
      clear();
      return null;
    }
  }
}
