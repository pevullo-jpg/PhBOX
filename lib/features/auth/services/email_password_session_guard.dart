import 'package:firebase_auth/firebase_auth.dart';

import '../../../data/repositories/tenant_access_repository.dart';

class EmailPasswordSessionGuard {
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
    _confirmedUid = uid;
    _confirmedEmail = email;
    _confirmedAt = DateTime.now().toUtc();
  }

  static bool isConfirmed({
    required User user,
    required String normalizedEmail,
  }) {
    return _confirmedUid == user.uid &&
        _confirmedEmail == normalizedEmail &&
        _confirmedAt != null;
  }

  static void clear() {
    _confirmedUid = null;
    _confirmedEmail = null;
    _confirmedAt = null;
  }
}
