import 'package:flutter/foundation.dart';

import 'phbox_frontend_access.dart';

class PhboxTenantSession extends ChangeNotifier {
  PhboxTenantSession._();

  static final PhboxTenantSession instance = PhboxTenantSession._();

  PhboxFrontendAccess? _access;

  PhboxFrontendAccess? get access => _access;

  String get tenantId => _access?.tenantId ?? '';

  String get tenantName => _access?.tenantName ?? '';

  String get pharmacyEmail => _access?.pharmacyEmail ?? '';

  String get dataRootPath => _access?.dataRootPath ?? '';

  bool get hasActiveSession => _access != null;

  void activate(PhboxFrontendAccess access) {
    final PhboxFrontendAccess? current = _access;
    if (current != null &&
        current.tenantId == access.tenantId &&
        current.pharmacyEmail == access.pharmacyEmail &&
        current.frontendEnabled == access.frontendEnabled &&
        current.tenantStatus == access.tenantStatus &&
        current.subscriptionStatus == access.subscriptionStatus &&
        current.dataRootPath == access.dataRootPath) {
      return;
    }
    _access = access;
    notifyListeners();
  }

  void clear() {
    if (_access == null) {
      return;
    }
    _access = null;
    notifyListeners();
  }
}
