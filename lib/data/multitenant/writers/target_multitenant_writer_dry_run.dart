import '../models/target_assistito.dart';
import '../models/target_multitenant_collections.dart';
import '../models/target_runtime_documents.dart';

class TargetDryRunWriteIntent {
  static const String setOperation = 'set';
  static const String patchOperation = 'patch';

  final String operation;
  final String path;
  final Map<String, dynamic> data;
  final String reason;

  const TargetDryRunWriteIntent({
    required this.operation,
    required this.path,
    required this.data,
    required this.reason,
  });

  factory TargetDryRunWriteIntent.set({
    required String path,
    required Map<String, dynamic> data,
    required String reason,
  }) {
    return TargetDryRunWriteIntent(
      operation: setOperation,
      path: path,
      data: Map<String, dynamic>.unmodifiable(data),
      reason: reason,
    );
  }

  factory TargetDryRunWriteIntent.patch({
    required String path,
    required Map<String, dynamic> data,
    required String reason,
  }) {
    return TargetDryRunWriteIntent(
      operation: patchOperation,
      path: path,
      data: Map<String, dynamic>.unmodifiable(data),
      reason: reason,
    );
  }

  bool get isSet => operation == setOperation;
  bool get isPatch => operation == patchOperation;
}

class TargetDryRunWritePlan {
  final String tenantId;
  final List<TargetDryRunWriteIntent> intents;

  const TargetDryRunWritePlan({
    required this.tenantId,
    required this.intents,
  });

  factory TargetDryRunWritePlan.empty({required String tenantId}) {
    return TargetDryRunWritePlan(
      tenantId: _normalizeTenantId(tenantId),
      intents: const <TargetDryRunWriteIntent>[],
    );
  }

  int get intentCount => intents.length;
  bool get isEmpty => intents.isEmpty;
  bool get isNotEmpty => intents.isNotEmpty;

  TargetDryRunWritePlan merge(TargetDryRunWritePlan other) {
    if (tenantId != other.tenantId) {
      throw ArgumentError.value(
        other.tenantId,
        'other.tenantId',
        'Non è possibile fondere piani dry-run di tenant diversi.',
      );
    }
    return TargetDryRunWritePlan(
      tenantId: tenantId,
      intents: List<TargetDryRunWriteIntent>.unmodifiable(<TargetDryRunWriteIntent>[
        ...intents,
        ...other.intents,
      ]),
    );
  }
}

class TargetMultitenantWriterDryRun {
  const TargetMultitenantWriterDryRun();

  TargetDryRunWritePlan planAssistitoSet({
    required String tenantId,
    required TargetAssistito assistito,
  }) {
    final String normalizedTenantId = _normalizeTenantId(tenantId);
    final String assistitoId = _normalizeDocumentId(assistito.assistitoId, label: 'assistito.assistitoId');
    return TargetDryRunWritePlan(
      tenantId: normalizedTenantId,
      intents: <TargetDryRunWriteIntent>[
        TargetDryRunWriteIntent.set(
          path: TargetMultitenantCollections.assistitoDocument(
            tenantId: normalizedTenantId,
            assistitoId: assistitoId,
          ),
          data: assistito.toMap(),
          reason: 'target_assistito_set_dry_run',
        ),
      ],
    );
  }

  TargetDryRunWritePlan planRuntimeSet({
    required String tenantId,
    required TargetPhboxRuntime runtime,
  }) {
    final String normalizedTenantId = _normalizeTenantId(tenantId);
    return TargetDryRunWritePlan(
      tenantId: normalizedTenantId,
      intents: <TargetDryRunWriteIntent>[
        TargetDryRunWriteIntent.set(
          path: TargetMultitenantCollections.tenantDocument(
            tenantId: normalizedTenantId,
            collectionId: TargetMultitenantCollections.phboxRuntime,
            documentId: 'main',
          ),
          data: runtime.toMap(),
          reason: 'target_phbox_runtime_set_dry_run',
        ),
      ],
    );
  }

  TargetDryRunWritePlan planSignalSet({
    required String tenantId,
    required TargetPhboxSignal signal,
  }) {
    final String normalizedTenantId = _normalizeTenantId(tenantId);
    final String signalId = _normalizeDocumentId(signal.signalId, label: 'signal.signalId');
    return TargetDryRunWritePlan(
      tenantId: normalizedTenantId,
      intents: <TargetDryRunWriteIntent>[
        TargetDryRunWriteIntent.set(
          path: TargetMultitenantCollections.tenantDocument(
            tenantId: normalizedTenantId,
            collectionId: TargetMultitenantCollections.phboxSignals,
            documentId: signalId,
          ),
          data: signal.toMap(),
          reason: 'target_phbox_signal_set_dry_run',
        ),
      ],
    );
  }

  TargetDryRunWritePlan combine({
    required String tenantId,
    required Iterable<TargetDryRunWritePlan> plans,
  }) {
    final String normalizedTenantId = _normalizeTenantId(tenantId);
    TargetDryRunWritePlan combined = TargetDryRunWritePlan.empty(tenantId: normalizedTenantId);
    for (final TargetDryRunWritePlan plan in plans) {
      combined = combined.merge(plan);
    }
    return combined;
  }
}

String _normalizeTenantId(String value) {
  return _normalizeDocumentId(value, label: 'tenantId');
}

String _normalizeDocumentId(String value, {required String label}) {
  final String normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, label, 'Identificativo vuoto non valido.');
  }
  if (normalized.contains('/')) {
    throw ArgumentError.value(value, label, 'Identificativo con slash non valido.');
  }
  return normalized;
}
