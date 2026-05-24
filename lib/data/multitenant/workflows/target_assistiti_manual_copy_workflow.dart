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
    required this.duplicateAssistitoIdCount,
    required this.plan,
    required this.validation,
    required this.blockers,
    required this.plannedAssistiti,
  });

  bool get canExecute => blockers.isEmpty && validation.isValid && plan.isNotEmpty;
  bool get blocked => !canExecute;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tenantId': tenantId,
      'requestedSourceCount': requestedSourceCount,
      'plannedAssistitiCount': plannedAssistitiCount,
      'maxAssistitiPerRun': maxAssistitiPerRun,
      'sourceLimitExceeded': sourceLimitExceeded,
      'duplicateAssistitoIdCount': duplicateAssistitoIdCount,
      'canExecute': canExecute,
      'blocked': blocked,
      'planIntentCount': plan.intentCount,
      'validationValid': validation.isValid,
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
  int get writesCommitted => execution?.writesCommitted ?? 0;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'executed': executed,
      'completed': completed,
      'blocked': blocked,
      'partialCommit': partialCommit,
      'writesCommitted': writesCommitted,
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
    final Set<String> seenAssistitoIds = <String>{};
    final List<TargetAssistito> assistiti = <TargetAssistito>[];
    final List<TargetAssistitiManualCopyBlocker> blockers = <TargetAssistitiManualCopyBlocker>[];

    for (final LegacyAssistitoSourceBundle source in sources) {
      requestedSourceCount += 1;
      if (requestedSourceCount > safeLimit) {
        sourceLimitExceeded = true;
        continue;
      }
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
        TargetAssistitiManualCopyBlocker(
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
