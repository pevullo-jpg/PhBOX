import '../validators/target_dry_run_plan_validator.dart';
import '../writers/target_multitenant_writer_dry_run.dart';

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

class TargetDryRunPlanReport {
  final String tenantId;
  final int intentCount;
  final int setIntentCount;
  final int patchIntentCount;
  final int issueCount;
  final int reportedPathCount;
  final int reportedCollectionCount;
  final int reportedIssueCount;
  final int maxReportedItems;
  final bool valid;
  final bool pathsTruncated;
  final bool collectionIntentCountsTruncated;
  final bool issuesTruncated;
  final Map<String, int> collectionIntentCounts;
  final List<String> reportedPaths;
  final List<TargetDryRunPlanReportIssue> issues;

  const TargetDryRunPlanReport({
    required this.tenantId,
    required this.intentCount,
    required this.setIntentCount,
    required this.patchIntentCount,
    required this.issueCount,
    required this.reportedPathCount,
    required this.reportedCollectionCount,
    required this.reportedIssueCount,
    required this.maxReportedItems,
    required this.valid,
    required this.pathsTruncated,
    required this.collectionIntentCountsTruncated,
    required this.issuesTruncated,
    required this.collectionIntentCounts,
    required this.reportedPaths,
    required this.issues,
  });

  factory TargetDryRunPlanReport.fromPlan({
    required TargetDryRunWritePlan plan,
    required TargetDryRunPlanValidationResult validation,
    int maxReportedPaths = 50,
  }) {
    final int maxReportedItems = _safeLimit(maxReportedPaths);
    final Map<String, int> allCollectionCounts = <String, int>{};
    final List<String> allPaths = <String>[];

    int setCount = 0;
    int patchCount = 0;

    for (final TargetDryRunWriteIntent intent in plan.intents) {
      final String path = intent.path.trim();
      allPaths.add(path);

      if (intent.isSet) {
        setCount += 1;
      } else if (intent.isPatch) {
        patchCount += 1;
      }

      final String collectionId = _firstTargetCollection(path);
      if (collectionId.isNotEmpty) {
        allCollectionCounts[collectionId] = (allCollectionCounts[collectionId] ?? 0) + 1;
      }
    }

    final List<String> boundedPaths = allPaths.take(maxReportedItems).toList(growable: false);
    final Map<String, int> boundedCollectionCounts = Map<String, int>.fromEntries(
      allCollectionCounts.entries.take(maxReportedItems),
    );
    final List<TargetDryRunPlanReportIssue> boundedIssues = validation.issues
        .take(maxReportedItems)
        .map(TargetDryRunPlanReportIssue.fromValidationIssue)
        .toList(growable: false);

    return TargetDryRunPlanReport(
      tenantId: plan.tenantId,
      intentCount: plan.intentCount,
      setIntentCount: setCount,
      patchIntentCount: patchCount,
      issueCount: validation.issueCount,
      reportedPathCount: boundedPaths.length,
      reportedCollectionCount: boundedCollectionCounts.length,
      reportedIssueCount: boundedIssues.length,
      maxReportedItems: maxReportedItems,
      valid: validation.isValid,
      pathsTruncated: allPaths.length > boundedPaths.length,
      collectionIntentCountsTruncated: allCollectionCounts.length > boundedCollectionCounts.length,
      issuesTruncated: validation.issueCount > boundedIssues.length,
      collectionIntentCounts: Map<String, int>.unmodifiable(boundedCollectionCounts),
      reportedPaths: List<String>.unmodifiable(boundedPaths),
      issues: List<TargetDryRunPlanReportIssue>.unmodifiable(boundedIssues),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tenantId': tenantId,
      'intentCount': intentCount,
      'setIntentCount': setIntentCount,
      'patchIntentCount': patchIntentCount,
      'issueCount': issueCount,
      'reportedPathCount': reportedPathCount,
      'reportedCollectionCount': reportedCollectionCount,
      'reportedIssueCount': reportedIssueCount,
      'maxReportedItems': maxReportedItems,
      'valid': valid,
      'pathsTruncated': pathsTruncated,
      'collectionIntentCountsTruncated': collectionIntentCountsTruncated,
      'issuesTruncated': issuesTruncated,
      'collectionIntentCounts': collectionIntentCounts,
      'reportedPaths': reportedPaths,
      'issues': issues.map((TargetDryRunPlanReportIssue issue) => issue.toMap()).toList(growable: false),
    };
  }

  static int _safeLimit(int value) {
    if (value < 0) {
      return 0;
    }
    return value;
  }

  static String _firstTargetCollection(String path) {
    final List<String> segments = path.split('/');
    if (segments.length < 3 || segments[0] != 'tenants') {
      return '';
    }
    return segments[2].trim();
  }
}
