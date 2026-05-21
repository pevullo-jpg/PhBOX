import 'package:flutter/widgets.dart';

import '../../features/auth/models/tenant_session.dart';

enum TenantDataScopeMode {
  legacyRoot,
}

class TenantPathResolver {
  final TenantSession session;
  final TenantDataScopeMode mode;

  const TenantPathResolver._({
    required this.session,
    required this.mode,
  });

  factory TenantPathResolver.legacyRoot(TenantSession session) {
    return TenantPathResolver._(
      session: session,
      mode: TenantDataScopeMode.legacyRoot,
    );
  }

  bool get usesLegacyRootCollections => mode == TenantDataScopeMode.legacyRoot;

  String collection(String legacyRootCollection) {
    return _normalizeLegacyRootCollection(legacyRootCollection);
  }

  String documentPath({
    required String legacyRootCollection,
    required String documentId,
  }) {
    final String collectionPath = collection(legacyRootCollection);
    final String normalizedDocumentId = documentId.trim();
    if (normalizedDocumentId.isEmpty) {
      return collectionPath;
    }
    return '$collectionPath/$normalizedDocumentId';
  }

  String subcollectionPath({
    required String legacyRootCollection,
    required String documentId,
    required String legacySubcollection,
  }) {
    final String parentPath = documentPath(
      legacyRootCollection: legacyRootCollection,
      documentId: documentId,
    );
    final String normalizedSubcollection = _normalizeLegacyRootCollection(legacySubcollection);
    return '$parentPath/$normalizedSubcollection';
  }

  String _normalizeLegacyRootCollection(String value) {
    final String normalized = value.trim();
    assert(normalized.isNotEmpty, 'Firestore collection path cannot be empty.');
    assert(!normalized.startsWith('/'), 'Firestore collection path must be relative.');
    assert(!normalized.endsWith('/'), 'Firestore collection path must not end with /.');
    return normalized;
  }
}

class TenantPathScope extends InheritedWidget {
  final TenantPathResolver resolver;

  const TenantPathScope({
    super.key,
    required this.resolver,
    required super.child,
  });

  static TenantPathResolver? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TenantPathScope>()?.resolver;
  }

  static TenantPathResolver of(BuildContext context) {
    final TenantPathResolver? resolver = maybeOf(context);
    assert(resolver != null, 'TenantPathScope not found in context.');
    return resolver!;
  }

  @override
  bool updateShouldNotify(covariant TenantPathScope oldWidget) {
    return oldWidget.resolver != resolver;
  }
}
