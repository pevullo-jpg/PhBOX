import '../models/target_multitenant_collections.dart';
import '../writers/target_multitenant_writer_dry_run.dart';

class TargetDryRunPlanValidationIssue {
  final String code;
  final String message;
  final String path;

  const TargetDryRunPlanValidationIssue({
    required this.code,
    required this.message,
    this.path = '',
  });
}

class TargetDryRunPlanValidationResult {
  final List<TargetDryRunPlanValidationIssue> issues;

  const TargetDryRunPlanValidationResult({required this.issues});

  factory TargetDryRunPlanValidationResult.valid() {
    return const TargetDryRunPlanValidationResult(
      issues: <TargetDryRunPlanValidationIssue>[],
    );
  }

  bool get isValid => issues.isEmpty;
  bool get isNotValid => issues.isNotEmpty;
  int get issueCount => issues.length;
}

class TargetDryRunPlanValidator {
  final int maxIntentCount;

  const TargetDryRunPlanValidator({this.maxIntentCount = 250});

  TargetDryRunPlanValidationResult validate(TargetDryRunWritePlan plan) {
    final List<TargetDryRunPlanValidationIssue> issues = <TargetDryRunPlanValidationIssue>[];
    final String tenantId = plan.tenantId.trim();

    if (tenantId.isEmpty) {
      issues.add(
        const TargetDryRunPlanValidationIssue(
          code: 'tenant_id_empty',
          message: 'tenantId vuoto non valido.',
        ),
      );
    } else if (tenantId.contains('/')) {
      issues.add(
        TargetDryRunPlanValidationIssue(
          code: 'tenant_id_invalid',
          message: 'tenantId con slash non valido: $tenantId.',
        ),
      );
    }

    if (plan.intentCount > maxIntentCount) {
      issues.add(
        TargetDryRunPlanValidationIssue(
          code: 'intent_count_unbounded',
          message: 'Piano dry-run troppo ampio: ${plan.intentCount} intenti, massimo $maxIntentCount.',
        ),
      );
    }

    final Set<String> setPaths = <String>{};
    final Set<String> duplicateSetPaths = <String>{};

    for (final TargetDryRunWriteIntent intent in plan.intents) {
      final String path = intent.path.trim();
      _validateIntent(
        intent: intent,
        tenantId: tenantId,
        path: path,
        issues: issues,
      );

      if (intent.isSet) {
        if (!setPaths.add(path)) {
          duplicateSetPaths.add(path);
        }
      }
    }

    for (final String path in duplicateSetPaths) {
      issues.add(
        TargetDryRunPlanValidationIssue(
          code: 'duplicate_set_path',
          message: 'Più set intent puntano allo stesso documento target.',
          path: path,
        ),
      );
    }

    if (issues.isEmpty) {
      return TargetDryRunPlanValidationResult.valid();
    }
    return TargetDryRunPlanValidationResult(
      issues: List<TargetDryRunPlanValidationIssue>.unmodifiable(issues),
    );
  }

  void _validateIntent({
    required TargetDryRunWriteIntent intent,
    required String tenantId,
    required String path,
    required List<TargetDryRunPlanValidationIssue> issues,
  }) {
    if (intent.operation != TargetDryRunWriteIntent.setOperation &&
        intent.operation != TargetDryRunWriteIntent.patchOperation) {
      issues.add(
        TargetDryRunPlanValidationIssue(
          code: 'unsupported_operation',
          message: 'Operazione dry-run non supportata: ${intent.operation}.',
          path: path,
        ),
      );
    }

    if (intent.data.isEmpty) {
      issues.add(
        TargetDryRunPlanValidationIssue(
          code: 'empty_payload',
          message: 'Payload dry-run vuoto non valido.',
          path: path,
        ),
      );
    }

    if (intent.reason.trim().isEmpty) {
      issues.add(
        TargetDryRunPlanValidationIssue(
          code: 'empty_reason',
          message: 'Reason dry-run vuota non valida.',
          path: path,
        ),
      );
    }

    _validateDocumentPath(
      path: path,
      tenantId: tenantId,
      issues: issues,
    );
  }

  void _validateDocumentPath({
    required String path,
    required String tenantId,
    required List<TargetDryRunPlanValidationIssue> issues,
  }) {
    if (path.isEmpty) {
      issues.add(
        const TargetDryRunPlanValidationIssue(
          code: 'path_empty',
          message: 'Path target vuoto non valido.',
        ),
      );
      return;
    }

    if (path.startsWith('/') || path.endsWith('/') || path.contains('//')) {
      issues.add(
        TargetDryRunPlanValidationIssue(
          code: 'path_invalid_segments',
          message: 'Path target con slash iniziale/finale o segmenti vuoti.',
          path: path,
        ),
      );
      return;
    }

    final List<String> segments = path.split('/');
    if (segments.length.isOdd) {
      issues.add(
        TargetDryRunPlanValidationIssue(
          code: 'path_not_document',
          message: 'Path target non punta a un documento Firestore.',
          path: path,
        ),
      );
    }

    if (segments.length < 4 ||
        segments[0] != TargetMultitenantCollections.tenants ||
        segments[1] != tenantId) {
      issues.add(
        TargetDryRunPlanValidationIssue(
          code: 'path_outside_tenant',
          message: 'Path target fuori da tenants/$tenantId/...',
          path: path,
        ),
      );
    }
  }
}
