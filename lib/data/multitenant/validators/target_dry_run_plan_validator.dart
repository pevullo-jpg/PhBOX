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

  const TargetDryRunPlanValidationResult({
    required this.issues,
  });

  bool get isValid => issues.isEmpty;
  bool get isNotValid => issues.isNotEmpty;

  static const TargetDryRunPlanValidationResult valid = TargetDryRunPlanValidationResult(
    issues: <TargetDryRunPlanValidationIssue>[],
  );
}

class TargetDryRunPlanValidator {
  final int maxIntents;

  const TargetDryRunPlanValidator({
    this.maxIntents = 500,
  });

  TargetDryRunPlanValidationResult validate(TargetDryRunWritePlan plan) {
    final List<TargetDryRunPlanValidationIssue> issues = <TargetDryRunPlanValidationIssue>[];
    final String tenantId = plan.tenantId.trim();

    if (!_isValidSegment(tenantId)) {
      issues.add(
        const TargetDryRunPlanValidationIssue(
          code: 'invalid_tenant_id',
          message: 'tenantId vuoto o contenente slash.',
        ),
      );
      return TargetDryRunPlanValidationResult(issues: List<TargetDryRunPlanValidationIssue>.unmodifiable(issues));
    }

    if (plan.intentCount > maxIntents) {
      issues.add(
        TargetDryRunPlanValidationIssue(
          code: 'too_many_intents',
          message: 'Il piano dry-run supera il limite massimo di intenti: $maxIntents.',
        ),
      );
    }

    final Set<String> seenSetPaths = <String>{};
    final String tenantPrefix = '${TargetMultitenantCollections.tenants}/$tenantId/';

    for (final TargetDryRunWriteIntent intent in plan.intents) {
      final String path = intent.path.trim();

      if (!_isSupportedOperation(intent.operation)) {
        issues.add(
          TargetDryRunPlanValidationIssue(
            code: 'unsupported_operation',
            message: 'Operazione dry-run non supportata: ${intent.operation}.',
            path: path,
          ),
        );
      }

      if (!_isValidDocumentPath(path)) {
        issues.add(
          TargetDryRunPlanValidationIssue(
            code: 'invalid_document_path',
            message: 'Path documento non valido.',
            path: path,
          ),
        );
      }

      if (!path.startsWith(tenantPrefix)) {
        issues.add(
          TargetDryRunPlanValidationIssue(
            code: 'path_outside_tenant',
            message: 'Path fuori dal tenant del piano.',
            path: path,
          ),
        );
      }

      if (intent.isSet && !seenSetPaths.add(path)) {
        issues.add(
          TargetDryRunPlanValidationIssue(
            code: 'duplicate_set_path',
            message: 'Più intenti set puntano allo stesso documento target.',
            path: path,
          ),
        );
      }

      if (intent.reason.trim().isEmpty) {
        issues.add(
          TargetDryRunPlanValidationIssue(
            code: 'empty_reason',
            message: 'Motivo dry-run vuoto.',
            path: path,
          ),
        );
      }

      if (intent.data.isEmpty) {
        issues.add(
          TargetDryRunPlanValidationIssue(
            code: 'empty_data',
            message: 'Payload dry-run vuoto.',
            path: path,
          ),
        );
      }
    }

    if (issues.isEmpty) {
      return TargetDryRunPlanValidationResult.valid;
    }
    return TargetDryRunPlanValidationResult(
      issues: List<TargetDryRunPlanValidationIssue>.unmodifiable(issues),
    );
  }

  bool _isSupportedOperation(String operation) {
    return operation == TargetDryRunWriteIntent.setOperation ||
        operation == TargetDryRunWriteIntent.patchOperation;
  }

  bool _isValidSegment(String value) {
    final String normalized = value.trim();
    return normalized.isNotEmpty && !normalized.contains('/');
  }

  bool _isValidDocumentPath(String path) {
    final String normalized = path.trim();
    if (normalized.isEmpty) {
      return false;
    }
    if (normalized.startsWith('/') || normalized.endsWith('/')) {
      return false;
    }
    if (normalized.contains('//')) {
      return false;
    }
    final List<String> segments = normalized.split('/');
    if (segments.length.isOdd) {
      return false;
    }
    return segments.every((String segment) => _isValidSegment(segment));
  }
}
