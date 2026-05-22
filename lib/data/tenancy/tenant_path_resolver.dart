import 'package:flutter/widgets.dart';

enum TenantDataScope {
  legacyRoot,
}

class TenantPathResolver {
  final TenantDataScope scope;
  final String tenantId;

  const TenantPathResolver.legacyRoot({String tenantId = ''})
      : scope = TenantDataScope.legacyRoot,
        tenantId = tenantId;

  String collection(String legacyCollectionPath) {
    return _normalizePath(legacyCollectionPath, label: 'legacyCollectionPath');
  }

  String documentPath({
    required String collectionPath,
    required String documentId,
  }) {
    return '${collection(collectionPath)}/${_normalizePath(documentId, label: 'documentId')}';
  }

  String subcollectionPath({
    required String collectionPath,
    required String documentId,
    required String subcollectionPath,
  }) {
    return '${documentPath(collectionPath: collectionPath, documentId: documentId)}/${collection(subcollectionPath)}';
  }

  static String _normalizePath(String value, {required String label}) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, label, 'Path vuoto non valido.');
    }
    if (normalized.startsWith('/') || normalized.endsWith('/')) {
      throw ArgumentError.value(value, label, 'Path con slash iniziale/finale non valido.');
    }
    if (normalized.contains('//')) {
      throw ArgumentError.value(value, label, 'Path con segmenti vuoti non valido.');
    }
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
