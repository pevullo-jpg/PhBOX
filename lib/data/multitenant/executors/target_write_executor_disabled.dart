import '../validators/target_dry_run_plan_validator.dart';
import '../writers/target_multitenant_writer_dry_run.dart';

class TargetWriteExecutionSkippedIntent {
  final String operation;
  final String path;
  final String reason;

  const TargetWriteExecutionSkippedIntent({
    required this.operation,
    required this.path,
    required this.reason,
  });

  factory TargetWriteExecutionSkippedIntent.fromIntent(TargetDryRunWriteIntent intent) {
    return TargetWriteExecutionSkippedIntent(
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

class TargetWriteExecutionResult {
  final String tenantId;
  final bool disabled;
  final bool writesAttempted;
  final int writesCommitted;
  final int requestedIntentCount;
  final int skippedIntentCount;
  final int reportedSkippedIntentCount;
  final int maxReportedSkippedIntents;
  final bool skippedIntentsTruncated;
  final bool validationValid;
  final int validationIssueCount;
  final List<TargetWriteExecutionSkippedIntent> skippedIntents;

  const TargetWriteExecutionResult({
    required this.tenantId,
    required this.disabled,
    required this.writesAttempted,
    required this.writesCommitted,
    required this.requestedIntentCount,
    required this.skippedIntentCount,
    required this.reportedSkippedIntentCount,
    required this.maxReportedSkippedIntents,
    required this.skippedIntentsTruncated,
    required this.validationValid,
    required this.validationIssueCount,
    required this.skippedIntents,
  });

  bool get noWritesByConstruction => disabled && !writesAttempted && writesCommitted == 0;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tenantId': tenantId,
      'disabled': disabled,
      'writesAttempted': writesAttempted,
      'writesCommitted': writesCommitted,
      'requestedIntentCount': requestedIntentCount,
      'skippedIntentCount': skippedIntentCount,
      'reportedSkippedIntentCount': reportedSkippedIntentCount,
      'maxReportedSkippedIntents': maxReportedSkippedIntents,
      'skippedIntentsTruncated': skippedIntentsTruncated,
      'validationValid': validationValid,
      'validationIssueCount': validationIssueCount,
      'noWritesByConstruction': noWritesByConstruction,
      'skippedIntents': skippedIntents
          .map((TargetWriteExecutionSkippedIntent intent) => intent.toMap())
          .toList(growable: false),
    };
  }
}

class TargetWriteExecutorDisabled {
  final TargetDryRunPlanValidator validator;
  final int maxReportedSkippedIntents;

  const TargetWriteExecutorDisabled({
    this.validator = const TargetDryRunPlanValidator(),
    this.maxReportedSkippedIntents = 50,
  });

  TargetWriteExecutionResult execute(
    TargetDryRunWritePlan plan, {
    TargetDryRunPlanValidationResult? validation,
  }) {
    final TargetDryRunPlanValidationResult resolvedValidation =
        validation ?? validator.validate(plan);
    final int maxReported = _safeLimit(maxReportedSkippedIntents);

    final List<TargetWriteExecutionSkippedIntent> reportedSkippedIntents = plan.intents
        .take(maxReported)
        .map(TargetWriteExecutionSkippedIntent.fromIntent)
        .toList(growable: false);

    return TargetWriteExecutionResult(
      tenantId: plan.tenantId,
      disabled: true,
      writesAttempted: false,
      writesCommitted: 0,
      requestedIntentCount: plan.intentCount,
      skippedIntentCount: plan.intentCount,
      reportedSkippedIntentCount: reportedSkippedIntents.length,
      maxReportedSkippedIntents: maxReported,
      skippedIntentsTruncated: plan.intentCount > reportedSkippedIntents.length,
      validationValid: resolvedValidation.isValid,
      validationIssueCount: resolvedValidation.issueCount,
      skippedIntents: List<TargetWriteExecutionSkippedIntent>.unmodifiable(
        reportedSkippedIntents,
      ),
    );
  }
}

int _safeLimit(int value) {
  if (value < 0) {
    return 0;
  }
  return value;
}
