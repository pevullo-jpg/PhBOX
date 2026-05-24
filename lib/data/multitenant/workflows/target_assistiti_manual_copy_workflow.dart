import '../executors/target_write_executor_guarded.dart';
import '../mappers/legacy_to_target_assistito_mapper.dart';
import '../models/target_assistito.dart';
import '../models/target_multitenant_collections.dart';
import '../validators/target_dry_run_plan_validator.dart';
import '../writers/target_multitenant_writer_dry_run.dart';

class TargetAssistitiManualCopyBlocker {
  final String code;
  final String message;

  const TargetAssistitiManualCopyBlocker({
    required this.code,
    required this.message,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'code': code,
      'message': message,
    };
  }
}

class TargetAssistitiManualCopyAssistitoSummary {
  final String assistitoId;
  final String cf;
  final String fullName;

  const TargetAssistitiManualCopyAssistitoSummary({
    required this.assistitoId,
    required this.cf,
    required this.fullName,
  });

  factory TargetAssistitiManualCopyAssistitoSummary.fromAssistito(TargetAssistito assistito) {
    return TargetAssistitiManualCopyAssistitoSummary(
      assistitoId: assistito.assistitoId,
      cf: assistito.cf,
      fullName: assistito.fullName,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'assistitoId': assistitoId,
      'cf': cf,
      'fullName': fullName,
    };
  }
}

class TargetAssistitiManualCopyPreparationResult {
  final String tenantId;
  final int requestedSourceCount;
  final int plannedAssistitiCount;
  final int maxAssistitiPerRun;
  final bool sourceLimitExceeded;
  final bool sourceScanStoppedAtLimit;
  final int duplicateAssistitoIdCount;
  final TargetDryRunWritePlan plan;
  final TargetDryRunPlanValidationResult validation;
  final List<TargetAssistitiManualCopyBlocker> blockers;
  final List<TargetAssistitiManualCopyAssistitoSummary> plannedAssistiti;

  const TargetAssistitiManualCopyPreparationResult({
    required this.tenantId,
    required this.requestedSourceCount,
    required this.plannedAssistitiCount,
    required this.maxAssistitiPerRun,
    required this.sourceLimitExceeded,
    required this.sourceScanStoppedAtLimit,
    required this.duplicateAssistitoIdCount,
    required this.plan,
    required this.validation,
    required this.blockers,
    required this.plannedAssistiti,
  });

  bool get canExecute => blockers.isEmpty && validation.isValid && plan.isNotEmpty;
  bool get blocked => !canExecute;
  bool get validationFailed => validation.isNotValid;
  bool get hasInputBlockers => blockers.isNotEmpty;

  String get statusCode {
    if (sourceLimitExceeded) {
      return 'source_limit_exceeded';
    }
    if (duplicateAssistitoIdCount > 0) {
      return 'duplicate_assistito_id';
    }
    if (requestedSourceCount == 0) {
      return 'sources_empty';
    }
    if (validationFailed) {
      return 'validation_failed';
    }
    if (plan.isEmpty) {
      return 'plan_empty';
    }
    return 'ready';
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tenantId': tenantId,
      'requestedSourceCount': requestedSourceCount,
      'requestedSourceCountMayBeTruncated': sourceScanStoppedAtLimit,
      'plannedAssistitiCount': plannedAssistitiCount,
      'maxAssistitiPerRun': maxAssistitiPerRun,
      'sourceLimitExceeded': sourceLimitExceeded,
      'sourceScanStoppedAtLimit': sourceScanStoppedAtLimit,
      'duplicateAssistitoIdCount': duplicateAssistitoIdCount,
      'statusCode': statusCode,
      'canExecute': canExecute,
      'blocked': blocked,
      'hasInputBlockers': hasInputBlockers,
      'planIntentCount': plan.intentCount,
      'validationValid': validation.isValid,
      'validationFailed': validationFailed,
      'validationIssueCount': validation.issueCount,
      'validationIssues': validation.issues
          .map(
            (TargetDryRunPlanValidationIssue issue) => <String, dynamic>{
              'code': issue.code,
              'message': issue.message,
              'path': issue.path,
            },
          )
          .toList(growable: false),
      'blockers': blockers
          .map((TargetAssistitiManualCopyBlocker blocker) => blocker.toMap())
          .toList(growable: false),
      'plannedAssistiti': plannedAssistiti
          .map((TargetAssistitiManualCopyAssistitoSummary assistito) => assistito.toMap())
          .toList(growable: false),
    };
  }
}

class TargetAssistitiManualCopyWorkflowResult {
  final TargetAssistitiManualCopyPreparationResult preparation;
  final TargetGuardedWriteExecutionResult? execution;

  const TargetAssistitiManualCopyWorkflowResult({
    required this.preparation,
    required this.execution,
  });

  bool get executed => execution != null;
  bool get completed => execution?.completed ?? false;
  bool get blocked => !executed || preparation.blocked || (execution?.blocked ?? false);
  bool get partialCommit => execution?.partialCommit ?? false;
  bool get executionFailed => (execution?.executionError ?? '').isNotEmpty;
  bool get noWritesCommitted => writesCommitted == 0;
  bool get automaticRetryAllowed => false;
  bool get sameBatchManualRetryAllowed {
    return executed && !completed && !partialCommit && noWritesCommitted;
  }

  bool get manualRebuildRequired {
    return preparation.blocked || preparation.validationFailed;
  }

  bool get postCopyVerificationRequiredBeforeRetry {
    return !completed && writesCommitted > 0;
  }

  int get writesCommitted => execution?.writesCommitted ?? 0;

  String get outcomeCode {
    if (preparation.blocked) {
      return 'preparation_blocked';
    }
    if (!executed) {
      return 'not_executed';
    }
    final TargetGuardedWriteExecutionResult resolvedExecution = execution!;
    if (resolvedExecution.completed) {
      return 'completed';
    }
    if (resolvedExecution.partialCommit) {
      return 'partial_commit';
    }
    if (resolvedExecution.blocked) {
      return 'execution_blocked';
    }
    if (resolvedExecution.executionError.isNotEmpty && resolvedExecution.writesCommitted == 0) {
      return 'execution_failed_no_commit';
    }
    if (resolvedExecution.executionError.isNotEmpty) {
      return 'execution_failed';
    }
    return 'incomplete';
  }

  String get retryPolicyCode {
    if (completed) {
      return 'none_completed';
    }
    if (manualRebuildRequired) {
      return 'manual_rebuild_required';
    }
    if (postCopyVerificationRequiredBeforeRetry) {
      return 'verify_target_before_retry';
    }
    if (sameBatchManualRetryAllowed) {
      return 'manual_retry_allowed_no_writes_committed';
    }
    return 'manual_review_required';
  }

  String get operatorAction {
    switch (retryPolicyCode) {
      case 'none_completed':
        return 'Copia completata: non ripetere il run senza nuova verifica.';
      case 'manual_rebuild_required':
        return 'Correggere input/limiti/duplicati e ricostruire manualmente il batch.';
      case 'verify_target_before_retry':
        return 'Eseguire verifica post-copia prima di qualsiasi retry manuale.';
      case 'manual_retry_allowed_no_writes_committed':
        return 'Retry manuale ammesso solo dopo controllo operatore: nessuna write risulta committata.';
      default:
        return 'Richiesta revisione manuale prima di ripetere la copia.';
    }
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'executed': executed,
      'completed': completed,
      'blocked': blocked,
      'partialCommit': partialCommit,
      'executionFailed': executionFailed,
      'writesCommitted': writesCommitted,
      'noWritesCommitted': noWritesCommitted,
      'outcomeCode': outcomeCode,
      'automaticRetryAllowed': automaticRetryAllowed,
      'sameBatchManualRetryAllowed': sameBatchManualRetryAllowed,
      'manualRebuildRequired': manualRebuildRequired,
      'postCopyVerificationRequiredBeforeRetry': postCopyVerificationRequiredBeforeRetry,
      'retryPolicyCode': retryPolicyCode,
      'operatorAction': operatorAction,
      'preparation': preparation.toMap(),
      'execution': execution?.toMap(),
    };
  }
}

class TargetAssistitiManualCopyWorkflow {
  static const int defaultMaxAssistitiPerRun = 3;
  static const int hardMaxAssistitiPerRun = 5;

  final LegacyToTargetAssistitoMapper mapper;
  final TargetMultitenantWriterDryRun writer;
  final TargetDryRunPlanValidator validator;
  final TargetWriteExecutorGuarded executor;

  const TargetAssistitiManualCopyWorkflow({
    required this.executor,
    this.mapper = const LegacyToTargetAssistitoMapper(),
    this.writer = const TargetMultitenantWriterDryRun(),
    this.validator = const TargetDryRunPlanValidator(maxIntentCount: hardMaxAssistitiPerRun),
  });

  TargetAssistitiManualCopyPreparationResult prepare({
    required String tenantId,
    required Iterable<LegacyAssistitoSourceBundle> sources,
    int maxAssistitiPerRun = defaultMaxAssistitiPerRun,
  }) {
    final String normalizedTenantId = _normalizeTenantId(tenantId);
    final int safeLimit = _validateRunLimit(maxAssistitiPerRun);

    int requestedSourceCount = 0;
    int duplicateAssistitoIdCount = 0;
    bool sourceLimitExceeded = false;
    bool sourceScanStoppedAtLimit = false;
    final Set<String> seenAssistitoIds = <String>{};
    final List<TargetAssistito> assistiti = <TargetAssistito>[];
    final List<TargetAssistitiManualCopyBlocker> blockers = <TargetAssistitiManualCopyBlocker>[];

    for (final LegacyAssistitoSourceBundle source in sources) {
      if (requestedSourceCount >= safeLimit) {
        requestedSourceCount += 1;
        sourceLimitExceeded = true;
        sourceScanStoppedAtLimit = true;
        break;
      }

      requestedSourceCount += 1;
      final TargetAssistito assistito = mapper.map(source);
      if (!seenAssistitoIds.add(assistito.assistitoId)) {
        duplicateAssistitoIdCount += 1;
      }
      assistiti.add(assistito);
    }

    if (requestedSourceCount == 0) {
      blockers.add(
        const TargetAssistitiManualCopyBlocker(
          code: 'sources_empty',
          message: 'Nessun assistito legacy fornito per la copia manuale controllata.',
        ),
      );
    }

    if (sourceLimitExceeded) {
      blockers.add(
        TargetAssistitiManualCopyBlocker(
          code: 'source_limit_exceeded',
          message: 'Input troppo ampio: massimo $safeLimit assistiti per run manuale.',
        ),
      );
    }

    if (duplicateAssistitoIdCount > 0) {
      blockers.add(
        const TargetAssistitiManualCopyBlocker(
          code: 'duplicate_assistito_id',
          message: 'Sono presenti assistitoId duplicati nel batch manuale.',
        ),
      );
    }

    final TargetDryRunWritePlan plan = assistiti.isEmpty
        ? TargetDryRunWritePlan.empty(tenantId: normalizedTenantId)
        : writer.combine(
            tenantId: normalizedTenantId,
            plans: assistiti.map(
              (TargetAssistito assistito) => writer.planAssistitoSet(
                tenantId: normalizedTenantId,
                assistito: assistito,
              ),
            ),
          );
    final TargetDryRunPlanValidationResult validation = validator.validate(plan);

    return TargetAssistitiManualCopyPreparationResult(
      tenantId: normalizedTenantId,
      requestedSourceCount: requestedSourceCount,
      plannedAssistitiCount: assistiti.length,
      maxAssistitiPerRun: safeLimit,
      sourceLimitExceeded: sourceLimitExceeded,
      sourceScanStoppedAtLimit: sourceScanStoppedAtLimit,
      duplicateAssistitoIdCount: duplicateAssistitoIdCount,
      plan: plan,
      validation: validation,
      blockers: List<TargetAssistitiManualCopyBlocker>.unmodifiable(blockers),
      plannedAssistiti: List<TargetAssistitiManualCopyAssistitoSummary>.unmodifiable(
        assistiti.map(TargetAssistitiManualCopyAssistitoSummary.fromAssistito),
      ),
    );
  }

  Future<TargetAssistitiManualCopyWorkflowResult> copy({
    required String tenantId,
    required Iterable<LegacyAssistitoSourceBundle> sources,
    required String approvalToken,
    required String expectedApprovalToken,
    int maxAssistitiPerRun = defaultMaxAssistitiPerRun,
  }) async {
    final TargetAssistitiManualCopyPreparationResult preparation = prepare(
      tenantId: tenantId,
      sources: sources,
      maxAssistitiPerRun: maxAssistitiPerRun,
    );

    if (!preparation.canExecute) {
      return TargetAssistitiManualCopyWorkflowResult(
        preparation: preparation,
        execution: null,
      );
    }

    final TargetGuardedWriteExecutionResult execution = await executor.execute(
      preparation.plan,
      guard: TargetWriteExecutionGuard(
        enabled: true,
        approvalToken: approvalToken,
        expectedApprovalToken: expectedApprovalToken,
        maxWriteCount: preparation.maxAssistitiPerRun,
        allowedCollectionIds: const <String>{TargetMultitenantCollections.assistiti},
        allowSet: true,
        allowPatch: false,
        requireValidPlan: true,
      ),
      validation: preparation.validation,
    );

    return TargetAssistitiManualCopyWorkflowResult(
      preparation: preparation,
      execution: execution,
    );
  }

  static String _normalizeTenantId(String value) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'tenantId', 'tenantId obbligatorio per copia assistiti target.');
    }
    if (normalized.contains('/')) {
      throw ArgumentError.value(value, 'tenantId', 'tenantId con slash non valido.');
    }
    return normalized;
  }

  static int _validateRunLimit(int value) {
    if (value <= 0) {
      throw ArgumentError.value(value, 'maxAssistitiPerRun', 'Il limite per run deve essere positivo.');
    }
    if (value > hardMaxAssistitiPerRun) {
      throw ArgumentError.value(
        value,
        'maxAssistitiPerRun',
        'Il limite per run supera il cap hard di $hardMaxAssistitiPerRun assistiti.',
      );
    }
    return value;
  }
}
