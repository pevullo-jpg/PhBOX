import '../validators/target_dry_run_plan_validator.dart';
import '../writers/target_multitenant_writer_dry_run.dart';

class TargetDryRunPlanReport {
  static const int defaultMaxReportedPaths = 50;

  final String tenantId;
  final int intentCount;
  final int setIntentCount;
  final int patchIntentCount;
  final int validationIssueCount;
  final bool isValid;
  final Map<String, int> collectionIntentCounts;
  final List<String> reportedPaths;
  final List<TargetDryRunPlanReportIssue> issues;

  const TargetDryRunPlanReport({
    required this.tenantId,
    required this.intentCount,
    required this.setIntentCount,
    required this.patchIntentCount,
    required this.validationIssueCount,
    required this.isValid,
    required this.collectionIntentCounts,
    required this.reportedPaths,
    required this.issues,
  });

  factory TargetDryRunPlanReport.fromPlan({
    required TargetDryRunWritePlan plan,
    required TargetDryRunPlanValidationResult validation,
    int maxReportedPaths = defaultMaxReportedPaths,
  }) {
    final Map<String, int> collectionCounts = <String, int>{};
    final List<String> paths = <String>[];

    for (final TargetDryRunWriteIntent intent in plan.intents) {
      final String collectionId = _targetCollectionId(intent.path);
      if (collectionId.isNotEmpty) {
        collectionCounts[collectionId] = (collectionCounts[collectionId] ?? 0) + 1;
      }
      if (paths.length < maxReportedPaths) {
        paths.add(intent.path);
      }
    }

    return TargetDryRunPlanReport(
      tenantId: plan.tenantId,
      intentCount: plan.intentCount,
      setIntentCount: plan.intents.where((TargetDryRunWriteIntent intent) => intent.isSet).length,
      patchIntentCount: plan.intents.where((TargetDryRunWriteIntent intent) => intent.isPatch).length,
      validationIssueCount: validation.issueCount,
      isValid: validation.isValid,
      collectionIntentCounts: Map<String, int>.unmodifiable(collectionCounts),
      reportedPaths: List<String>.unmodifiable(paths),
      issues: List<TargetDryRunPlanReportIssue>.unmodifiable(
        validation.issues.map(TargetDryRunPlanReportIssue.fromValidationIssue),
      ),
    );
  }

  bool get hasTruncatedPaths => intentCount > reportedPaths.length;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tenantId': tenantId,
      'intentCount': intentCount,
      'setIntentCount': setIntentCount,
      'patchIntentCount': patchIntentCount,
      'validationIssueCount': validationIssueCount,
      'isValid': isValid,
      'collectionIntentCounts': collectionIntentCounts,
      'reportedPaths': reportedPaths,
      'hasTruncatedPaths': hasTruncatedPaths,
      'issues': issues.map((TargetDryRunPlanReportIssue issue) => issue.toMap()).toList(growable: false),
    };
  }

  static String _targetCollectionId(String path) {
    final List<String> segments = path.split('/');
    if (segments.length < 3 || segments.first != 'tenants') {
      return '';
    }
    return segments[2].trim();
  }
}

class TargetDryRunPlanReportIssue {
  final String code;
  final String message;
  final String path;

  const TargetDryRunPlanReportIssue({
    required this.code,
    required this.message,
    required this.path,
  });

  factory TargetDryRunPlanReportIssue.fromValidationIssue(TargetDryRunPlanValidationIssue issue) {
    return TargetDryRunPlanReportIssue(
      code: issue.code,
      message: issue.message,
      path: issue.path,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'code': code,
      'message': message,
      'path': path,
    };
  }
}
