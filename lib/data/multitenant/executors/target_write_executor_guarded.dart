import '../models/target_multitenant_collections.dart';
import '../validators/target_dry_run_plan_validator.dart';
import '../writers/target_multitenant_writer_dry_run.dart';
import 'target_write_executor_disabled.dart';

abstract class TargetWriteCommitSink {
  Future<void> setDocument({
    required String path,
    required Map<String, dynamic> data,
  });

  Future<void> patchDocument({
    required String path,
    required Map<String, dynamic> data,
  });
}

class TargetWriteExecutionGuard {
  final bool enabled;
  final String approvalToken;
  final String expectedApprovalToken;
  final int maxWriteCount;
  final Set<String> allowedCollectionIds;
  final bool allowSet;
  final bool allowPatch;
  final bool requireValidPlan;

  const TargetWriteExecutionGuard({
    this.enabled = false,
    this.approvalToken = '',
    this.expectedApprovalToken = '',
    this.maxWriteCount = 0,
    this.allowedCollectionIds = const <String>{},
    this.allowSet = false,
    this.allowPatch = false,
    this.requireValidPlan = true,
  });

  const TargetWriteExecutionGuard.disabled()
      : enabled = false,
        approvalToken = '',
        expectedApprovalToken = '',
        maxWriteCount = 0,
        allowedCollectionIds = const <String>{},
        allowSet = false,
        allowPatch = false,
        requireValidPlan = true;

  bool get approvalTokenValid {
    return enabled &&
        approvalToken.trim().isNotEmpty &&
        expectedApprovalToken.trim().isNotEmpty &&
        approvalToken.trim() == expectedApprovalToken.trim();
  }

  bool get hasAllowedCollections => allowedCollectionIds.isNotEmpty;

  bool allowsCollection(String collectionId) {
    return allowedCollectionIds.contains(collectionId.trim());
  }
}

class TargetGuardedWriteBlocker {
  final String code;
  final String message;
  final String path;

  const TargetGuardedWriteBlocker({
    required this.code,
    required this.message,
    this.path = '',
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'code': code,
      'message': message,
      'path': path,
    };
  }
}

class TargetGuardedWriteCommittedIntent {
  final String operation;
  final String path;
  final String reason;

  const TargetGuardedWriteCommittedIntent({
    required this.operation,
    required this.path,
    required this.reason,
  });

  factory TargetGuardedWriteCommittedIntent.fromIntent(TargetDryRunWriteIntent intent) {
    return TargetGuardedWriteCommittedIntent(
      operation: intent.operation,
      path: intent.path,
      reason: intent.reason,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'operation': operation,
      'path': path,
      'reason': reason,
    };
  }
}

class TargetGuardedWriteExecutionResult {
  final String tenantId;
  final bool guardEnabled;
  final bool approvalTokenValid;
  final bool validationValid;
  final bool writesAttempted;
  final int requestedIntentCount;
  final int writesCommitted;
  final int skippedIntentCount;
  final int reportedCommittedIntentCount;
  final int reportedSkippedIntentCount;
  final int maxReportedCommittedIntents;
  final int maxReportedSkippedIntents;
  final bool committedIntentsTruncated;
  final bool skippedIntentsTruncated;
  final String executionError;
  final List<TargetGuardedWriteBlocker> blockers;
  final List<TargetGuardedWriteCommittedIntent> committedIntents;
  final List<TargetWriteExecutionSkippedIntent> skippedIntents;

  const TargetGuardedWriteExecutionResult({
    required this.tenantId,
    required this.guardEnabled,
    required this.approvalTokenValid,
    required this.validationValid,
    required this.writesAttempted,
    required this.requestedIntentCount,
    required this.writesCommitted,
    required this.skippedIntentCount,
    required this.reportedCommittedIntentCount,
    required this.reportedSkippedIntentCount,
    required this.maxReportedCommittedIntents,
    required this.maxReportedSkippedIntents,
    required this.committedIntentsTruncated,
    required this.skippedIntentsTruncated,
    required this.executionError,
    required this.blockers,
    required this.committedIntents,
    required this.skippedIntents,
  });

  bool get blocked => blockers.isNotEmpty;
  bool get completed => executionError.isEmpty && !blocked && writesCommitted == requestedIntentCount;
  bool get partialCommit => executionError.isNotEmpty && writesCommitted > 0;
  bool get noWritesCommitted => writesCommitted == 0;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tenantId': tenantId,
      'guardEnabled': guardEnabled,
      'approvalTokenValid': approvalTokenValid,
      'validationValid': validationValid,
      'writesAttempted': writesAttempted,
      'requestedIntentCount': requestedIntentCount,
      'writesCommitted': writesCommitted,
      'skippedIntentCount': skippedIntentCount,
      'reportedCommittedIntentCount': reportedCommittedIntentCount,
      'reportedSkippedIntentCount': reportedSkippedIntentCount,
      'maxReportedCommittedIntents': maxReportedCommittedIntents,
      'maxReportedSkippedIntents': maxReportedSkippedIntents,
      'committedIntentsTruncated': committedIntentsTruncated,
      'skippedIntentsTruncated': skippedIntentsTruncated,
      'executionError': executionError,
      'blocked': blocked,
      'completed': completed,
      'partialCommit': partialCommit,
      'noWritesCommitted': noWritesCommitted,
      'blockers': blockers
          .map((TargetGuardedWriteBlocker blocker) => blocker.toMap())
          .toList(growable: false),
      'committedIntents': committedIntents
          .map((TargetGuardedWriteCommittedIntent intent) => intent.toMap())
          .toList(growable: false),
      'skippedIntents': skippedIntents
          .map((TargetWriteExecutionSkippedIntent intent) => intent.toMap())
          .toList(growable: false),
    };
  }
}

class TargetWriteExecutorGuarded {
  final TargetWriteCommitSink sink;
  final TargetDryRunPlanValidator validator;
  final int maxReportedCommittedIntents;
  final int maxReportedSkippedIntents;

  const TargetWriteExecutorGuarded({
    required this.sink,
    this.validator = const TargetDryRunPlanValidator(),
    this.maxReportedCommittedIntents = 50,
    this.maxReportedSkippedIntents = 50,
  });

  Future<TargetGuardedWriteExecutionResult> execute(
    TargetDryRunWritePlan plan, {
    TargetWriteExecutionGuard guard = const TargetWriteExecutionGuard.disabled(),
    TargetDryRunPlanValidationResult? validation,
  }) async {
    final TargetDryRunPlanValidationResult resolvedValidation =
        validation ?? validator.validate(plan);
    final int maxReportedCommitted = _safeLimit(maxReportedCommittedIntents);
    final int maxReportedSkipped = _safeLimit(maxReportedSkippedIntents);

    final List<TargetGuardedWriteBlocker> blockers = _preflightBlockers(
      plan: plan,
      guard: guard,
      validation: resolvedValidation,
    );

    if (blockers.isNotEmpty) {
      final List<TargetWriteExecutionSkippedIntent> skipped = _boundedSkipped(
        plan.intents,
        maxReported: maxReportedSkipped,
      );
      return TargetGuardedWriteExecutionResult(
        tenantId: plan.tenantId,
        guardEnabled: guard.enabled,
        approvalTokenValid: guard.approvalTokenValid,
        validationValid: resolvedValidation.isValid,
        writesAttempted: false,
        requestedIntentCount: plan.intentCount,
        writesCommitted: 0,
        skippedIntentCount: plan.intentCount,
        reportedCommittedIntentCount: 0,
        reportedSkippedIntentCount: skipped.length,
        maxReportedCommittedIntents: maxReportedCommitted,
        maxReportedSkippedIntents: maxReportedSkipped,
        committedIntentsTruncated: false,
        skippedIntentsTruncated: plan.intentCount > skipped.length,
        executionError: '',
        blockers: List<TargetGuardedWriteBlocker>.unmodifiable(blockers),
        committedIntents: const <TargetGuardedWriteCommittedIntent>[],
        skippedIntents: List<TargetWriteExecutionSkippedIntent>.unmodifiable(skipped),
      );
    }

    final List<TargetGuardedWriteCommittedIntent> reportedCommitted =
        <TargetGuardedWriteCommittedIntent>[];
    int writesCommitted = 0;
    String executionError = '';

    for (final TargetDryRunWriteIntent intent in plan.intents) {
      try {
        if (intent.isSet) {
          await sink.setDocument(path: intent.path, data: intent.data);
        } else if (intent.isPatch) {
          await sink.patchDocument(path: intent.path, data: intent.data);
        } else {
          throw StateError('Unsupported operation after preflight: ${intent.operation}');
        }
        writesCommitted += 1;
        if (reportedCommitted.length < maxReportedCommitted) {
          reportedCommitted.add(TargetGuardedWriteCommittedIntent.fromIntent(intent));
        }
      } catch (error) {
        executionError = error.toString();
        break;
      }
    }

    final int skippedIntentCount = plan.intentCount - writesCommitted;
    final List<TargetWriteExecutionSkippedIntent> skippedAfterError = executionError.isEmpty
        ? const <TargetWriteExecutionSkippedIntent>[]
        : _boundedSkipped(
            plan.intents.skip(writesCommitted),
            maxReported: maxReportedSkipped,
          );

    return TargetGuardedWriteExecutionResult(
      tenantId: plan.tenantId,
      guardEnabled: guard.enabled,
      approvalTokenValid: guard.approvalTokenValid,
      validationValid: resolvedValidation.isValid,
      writesAttempted: plan.intentCount > 0,
      requestedIntentCount: plan.intentCount,
      writesCommitted: writesCommitted,
      skippedIntentCount: skippedIntentCount,
      reportedCommittedIntentCount: reportedCommitted.length,
      reportedSkippedIntentCount: skippedAfterError.length,
      maxReportedCommittedIntents: maxReportedCommitted,
      maxReportedSkippedIntents: maxReportedSkipped,
      committedIntentsTruncated: writesCommitted > reportedCommitted.length,
      skippedIntentsTruncated: skippedIntentCount > skippedAfterError.length,
      executionError: executionError,
      blockers: const <TargetGuardedWriteBlocker>[],
      committedIntents: List<TargetGuardedWriteCommittedIntent>.unmodifiable(reportedCommitted),
      skippedIntents: List<TargetWriteExecutionSkippedIntent>.unmodifiable(skippedAfterError),
    );
  }

  List<TargetGuardedWriteBlocker> _preflightBlockers({
    required TargetDryRunWritePlan plan,
    required TargetWriteExecutionGuard guard,
    required TargetDryRunPlanValidationResult validation,
  }) {
    final List<TargetGuardedWriteBlocker> blockers = <TargetGuardedWriteBlocker>[];

    if (!guard.enabled) {
      blockers.add(
        const TargetGuardedWriteBlocker(
          code: 'guard_disabled',
          message: 'Executor guarded non abilitato.',
        ),
      );
    }

    if (!guard.approvalTokenValid) {
      blockers.add(
        const TargetGuardedWriteBlocker(
          code: 'approval_token_invalid',
          message: 'Token di approvazione assente o non valido.',
        ),
      );
    }

    if (guard.requireValidPlan && validation.isNotValid) {
      blockers.add(
        TargetGuardedWriteBlocker(
          code: 'plan_validation_failed',
          message: 'Piano target non valido: ${validation.issueCount} issue.',
        ),
      );
    }

    if (guard.maxWriteCount <= 0) {
      blockers.add(
        const TargetGuardedWriteBlocker(
          code: 'max_write_count_not_positive',
          message: 'maxWriteCount deve essere positivo per consentire scritture.',
        ),
      );
    } else if (plan.intentCount > guard.maxWriteCount) {
      blockers.add(
        TargetGuardedWriteBlocker(
          code: 'max_write_count_exceeded',
          message: 'Piano troppo ampio per la guardia corrente.',
        ),
      );
    }

    if (!guard.hasAllowedCollections) {
      blockers.add(
        const TargetGuardedWriteBlocker(
          code: 'allowed_collections_empty',
          message: 'Nessuna collection target esplicitamente autorizzata.',
        ),
      );
    }

    for (final TargetDryRunWriteIntent intent in plan.intents) {
      if (intent.isSet && !guard.allowSet) {
        blockers.add(
          TargetGuardedWriteBlocker(
            code: 'set_not_allowed',
            message: 'Operazione set non autorizzata dalla guardia.',
            path: intent.path,
          ),
        );
      }
      if (intent.isPatch && !guard.allowPatch) {
        blockers.add(
          TargetGuardedWriteBlocker(
            code: 'patch_not_allowed',
            message: 'Operazione patch non autorizzata dalla guardia.',
            path: intent.path,
          ),
        );
      }

      final String collectionId = _firstTargetCollection(intent.path);
      if (collectionId.isEmpty) {
        blockers.add(
          TargetGuardedWriteBlocker(
            code: 'target_collection_unresolved',
            message: 'Collection target non risolta dal path.',
            path: intent.path,
          ),
        );
      } else if (!guard.allowsCollection(collectionId)) {
        blockers.add(
          TargetGuardedWriteBlocker(
            code: 'target_collection_not_allowed',
            message: 'Collection target non autorizzata: $collectionId.',
            path: intent.path,
          ),
        );
      }
    }

    if (blockers.isEmpty) {
      return const <TargetGuardedWriteBlocker>[];
    }
    return List<TargetGuardedWriteBlocker>.unmodifiable(blockers);
  }
}

List<TargetWriteExecutionSkippedIntent> _boundedSkipped(
  Iterable<TargetDryRunWriteIntent> intents, {
  required int maxReported,
}) {
  return intents
      .take(maxReported)
      .map(TargetWriteExecutionSkippedIntent.fromIntent)
      .toList(growable: false);
}

String _firstTargetCollection(String path) {
  final List<String> segments = path.split('/');
  if (segments.length < 3 || segments[0] != TargetMultitenantCollections.tenants) {
    return '';
  }
  return segments[2].trim();
}

int _safeLimit(int value) {
  if (value < 0) {
    return 0;
  }
  return value;
}
