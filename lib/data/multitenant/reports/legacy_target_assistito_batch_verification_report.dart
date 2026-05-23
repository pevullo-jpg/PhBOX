import '../models/legacy_target_assistito_comparison.dart';
import '../verifiers/legacy_target_assistito_verifier.dart';

class LegacyTargetAssistitoBatchVerificationIssueEntry {
  final String expectedAssistitoId;
  final String targetDocumentId;
  final bool targetDocumentPresent;
  final bool targetDocumentIdProvided;
  final bool targetDocumentIdMatchesExpected;
  final bool verified;
  final int fieldCount;
  final int mismatchCount;
  final int reportedMismatchCount;
  final bool mismatchesTruncated;
  final bool documentIdentityValid;
  final bool hasDocumentIdentityIssue;
  final List<LegacyTargetAssistitoFieldComparison> mismatches;

  const LegacyTargetAssistitoBatchVerificationIssueEntry({
    required this.expectedAssistitoId,
    required this.targetDocumentId,
    required this.targetDocumentPresent,
    required this.targetDocumentIdProvided,
    required this.targetDocumentIdMatchesExpected,
    required this.verified,
    required this.fieldCount,
    required this.mismatchCount,
    required this.reportedMismatchCount,
    required this.mismatchesTruncated,
    required this.documentIdentityValid,
    required this.hasDocumentIdentityIssue,
    required this.mismatches,
  });

  factory LegacyTargetAssistitoBatchVerificationIssueEntry.fromResult({
    required LegacyTargetAssistitoVerificationResult result,
    required int maxReportedMismatches,
  }) {
    final int safeMismatchLimit = _safeLimit(maxReportedMismatches);
    final List<LegacyTargetAssistitoFieldComparison> allMismatches = result.comparison.mismatches;
    final List<LegacyTargetAssistitoFieldComparison> reportedMismatches =
        allMismatches.take(safeMismatchLimit).toList(growable: false);
    final bool documentIdentityValid = result.comparison.documentIdentity?.isValid ?? true;

    return LegacyTargetAssistitoBatchVerificationIssueEntry(
      expectedAssistitoId: result.expectedAssistitoId,
      targetDocumentId: result.targetDocumentId,
      targetDocumentPresent: result.targetDocumentPresent,
      targetDocumentIdProvided: result.targetDocumentIdProvided,
      targetDocumentIdMatchesExpected: result.targetDocumentIdMatchesExpected,
      verified: result.verified,
      fieldCount: result.comparison.fieldCount,
      mismatchCount: result.comparison.mismatchCount,
      reportedMismatchCount: reportedMismatches.length,
      mismatchesTruncated: allMismatches.length > reportedMismatches.length,
      documentIdentityValid: documentIdentityValid,
      hasDocumentIdentityIssue: !documentIdentityValid,
      mismatches: List<LegacyTargetAssistitoFieldComparison>.unmodifiable(reportedMismatches),
    );
  }

  bool get hasIssues => !verified;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'expectedAssistitoId': expectedAssistitoId,
      'targetDocumentId': targetDocumentId,
      'targetDocumentPresent': targetDocumentPresent,
      'targetDocumentIdProvided': targetDocumentIdProvided,
      'targetDocumentIdMatchesExpected': targetDocumentIdMatchesExpected,
      'verified': verified,
      'hasIssues': hasIssues,
      'fieldCount': fieldCount,
      'mismatchCount': mismatchCount,
      'reportedMismatchCount': reportedMismatchCount,
      'mismatchesTruncated': mismatchesTruncated,
      'documentIdentityValid': documentIdentityValid,
      'hasDocumentIdentityIssue': hasDocumentIdentityIssue,
      'mismatches': mismatches
          .map((LegacyTargetAssistitoFieldComparison mismatch) => mismatch.toMap())
          .toList(growable: false),
    };
  }
}

class LegacyTargetAssistitoBatchVerificationReport {
  final int inputCount;
  final int verifiedCount;
  final int issueCount;
  final int targetDocumentPresentCount;
  final int targetDocumentMissingCount;
  final int targetDocumentIdMissingCount;
  final int targetDocumentIdMismatchCount;
  final int comparisonFieldMismatchCount;
  final int documentIdentityIssueCount;
  final int reportedIssueCount;
  final int reportedMismatchCount;
  final int maxReportedIssues;
  final int maxReportedMismatchesPerIssue;
  final bool issuesTruncated;
  final bool mismatchesTruncated;
  final List<LegacyTargetAssistitoBatchVerificationIssueEntry> issues;

  const LegacyTargetAssistitoBatchVerificationReport({
    required this.inputCount,
    required this.verifiedCount,
    required this.issueCount,
    required this.targetDocumentPresentCount,
    required this.targetDocumentMissingCount,
    required this.targetDocumentIdMissingCount,
    required this.targetDocumentIdMismatchCount,
    required this.comparisonFieldMismatchCount,
    required this.documentIdentityIssueCount,
    required this.reportedIssueCount,
    required this.reportedMismatchCount,
    required this.maxReportedIssues,
    required this.maxReportedMismatchesPerIssue,
    required this.issuesTruncated,
    required this.mismatchesTruncated,
    required this.issues,
  });

  factory LegacyTargetAssistitoBatchVerificationReport.fromResults({
    required Iterable<LegacyTargetAssistitoVerificationResult> results,
    int maxReportedIssues = 50,
    int maxReportedMismatchesPerIssue = 8,
  }) {
    final int safeIssueLimit = _safeLimit(maxReportedIssues);
    final int safeMismatchLimit = _safeLimit(maxReportedMismatchesPerIssue);

    int inputCount = 0;
    int verifiedCount = 0;
    int targetDocumentPresentCount = 0;
    int targetDocumentMissingCount = 0;
    int targetDocumentIdMissingCount = 0;
    int targetDocumentIdMismatchCount = 0;
    int comparisonFieldMismatchCount = 0;
    int documentIdentityIssueCount = 0;
    int reportedMismatchCount = 0;
    bool issuesTruncated = false;
    bool mismatchesTruncated = false;

    final List<LegacyTargetAssistitoBatchVerificationIssueEntry> reportedIssues =
        <LegacyTargetAssistitoBatchVerificationIssueEntry>[];

    for (final LegacyTargetAssistitoVerificationResult result in results) {
      inputCount += 1;

      if (result.verified) {
        verifiedCount += 1;
      }

      if (result.targetDocumentPresent) {
        targetDocumentPresentCount += 1;
      } else {
        targetDocumentMissingCount += 1;
      }

      if (!result.targetDocumentIdProvided) {
        targetDocumentIdMissingCount += 1;
      }

      if (!result.targetDocumentIdMatchesExpected) {
        targetDocumentIdMismatchCount += 1;
      }

      comparisonFieldMismatchCount += result.comparison.mismatchCount;

      final bool hasDocumentIdentityIssue =
          result.comparison.documentIdentity != null && !result.comparison.documentIdentity!.isValid;
      if (hasDocumentIdentityIssue) {
        documentIdentityIssueCount += 1;
      }

      if (!result.hasIssues) {
        continue;
      }

      if (reportedIssues.length >= safeIssueLimit) {
        issuesTruncated = true;
        continue;
      }

      final LegacyTargetAssistitoBatchVerificationIssueEntry entry =
          LegacyTargetAssistitoBatchVerificationIssueEntry.fromResult(
        result: result,
        maxReportedMismatches: safeMismatchLimit,
      );

      reportedMismatchCount += entry.reportedMismatchCount;
      if (entry.mismatchesTruncated) {
        mismatchesTruncated = true;
      }
      reportedIssues.add(entry);
    }

    final int issueCount = inputCount - verifiedCount;

    return LegacyTargetAssistitoBatchVerificationReport(
      inputCount: inputCount,
      verifiedCount: verifiedCount,
      issueCount: issueCount,
      targetDocumentPresentCount: targetDocumentPresentCount,
      targetDocumentMissingCount: targetDocumentMissingCount,
      targetDocumentIdMissingCount: targetDocumentIdMissingCount,
      targetDocumentIdMismatchCount: targetDocumentIdMismatchCount,
      comparisonFieldMismatchCount: comparisonFieldMismatchCount,
      documentIdentityIssueCount: documentIdentityIssueCount,
      reportedIssueCount: reportedIssues.length,
      reportedMismatchCount: reportedMismatchCount,
      maxReportedIssues: safeIssueLimit,
      maxReportedMismatchesPerIssue: safeMismatchLimit,
      issuesTruncated: issuesTruncated,
      mismatchesTruncated: mismatchesTruncated,
      issues: List<LegacyTargetAssistitoBatchVerificationIssueEntry>.unmodifiable(reportedIssues),
    );
  }

  factory LegacyTargetAssistitoBatchVerificationReport.fromInputs({
    required Iterable<LegacyTargetAssistitoVerificationInput> inputs,
    LegacyTargetAssistitoVerifier verifier = const LegacyTargetAssistitoVerifier(),
    bool compareTimestamps = false,
    int maxReportedIssues = 50,
    int maxReportedMismatchesPerIssue = 8,
  }) {
    return LegacyTargetAssistitoBatchVerificationReport.fromResults(
      results: inputs.map(
        (LegacyTargetAssistitoVerificationInput input) => verifier.verifyOne(
          legacy: input.legacy,
          targetDocumentId: input.targetDocumentId,
          targetData: input.targetData,
          compareTimestamps: compareTimestamps,
        ),
      ),
      maxReportedIssues: maxReportedIssues,
      maxReportedMismatchesPerIssue: maxReportedMismatchesPerIssue,
    );
  }

  bool get allVerified => issueCount == 0;
  bool get hasIssues => !allVerified;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'inputCount': inputCount,
      'verifiedCount': verifiedCount,
      'issueCount': issueCount,
      'targetDocumentPresentCount': targetDocumentPresentCount,
      'targetDocumentMissingCount': targetDocumentMissingCount,
      'targetDocumentIdMissingCount': targetDocumentIdMissingCount,
      'targetDocumentIdMismatchCount': targetDocumentIdMismatchCount,
      'comparisonFieldMismatchCount': comparisonFieldMismatchCount,
      'documentIdentityIssueCount': documentIdentityIssueCount,
      'reportedIssueCount': reportedIssueCount,
      'reportedMismatchCount': reportedMismatchCount,
      'maxReportedIssues': maxReportedIssues,
      'maxReportedMismatchesPerIssue': maxReportedMismatchesPerIssue,
      'issuesTruncated': issuesTruncated,
      'mismatchesTruncated': mismatchesTruncated,
      'allVerified': allVerified,
      'hasIssues': hasIssues,
      'issues': issues
          .map((LegacyTargetAssistitoBatchVerificationIssueEntry issue) => issue.toMap())
          .toList(growable: false),
    };
  }
}

int _safeLimit(int value) {
  if (value < 0) {
    return 0;
  }
  return value;
}
