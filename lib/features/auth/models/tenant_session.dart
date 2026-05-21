import 'package:flutter/widgets.dart';

import '../../../data/models/tenant_access.dart';

class TenantSession {
  final String tenantId;
  final String tenantName;
  final String loginEmail;
  final String tenantStatus;
  final String subscriptionStatus;
  final int schemaVersion;

  const TenantSession({
    required this.tenantId,
    required this.tenantName,
    required this.loginEmail,
    required this.tenantStatus,
    required this.subscriptionStatus,
    required this.schemaVersion,
  });

  factory TenantSession.fromTenantAccess(TenantAccess access) {
    return TenantSession(
      tenantId: access.tenantId,
      tenantName: access.tenantName,
      loginEmail: access.loginEmail,
      tenantStatus: access.tenantStatus,
      subscriptionStatus: access.subscriptionStatus,
      schemaVersion: access.schemaVersion,
    );
  }

  bool get hasTenantId => tenantId.trim().isNotEmpty;

  @override
  bool operator ==(Object other) {
    return other is TenantSession &&
        other.tenantId == tenantId &&
        other.tenantName == tenantName &&
        other.loginEmail == loginEmail &&
        other.tenantStatus == tenantStatus &&
        other.subscriptionStatus == subscriptionStatus &&
        other.schemaVersion == schemaVersion;
  }

  @override
  int get hashCode {
    return Object.hash(
      tenantId,
      tenantName,
      loginEmail,
      tenantStatus,
      subscriptionStatus,
      schemaVersion,
    );
  }
}

class TenantSessionScope extends InheritedWidget {
  final TenantSession session;

  const TenantSessionScope({
    super.key,
    required this.session,
    required super.child,
  });

  static TenantSession? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TenantSessionScope>()?.session;
  }

  static TenantSession of(BuildContext context) {
    final TenantSession? session = maybeOf(context);
    if (session == null) {
      throw StateError('TenantSessionScope non disponibile nel contesto corrente.');
    }
    return session;
  }

  @override
  bool updateShouldNotify(TenantSessionScope oldWidget) {
    return oldWidget.session != session;
  }
}
