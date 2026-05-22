import '../models/legacy_target_assistito_comparison.dart';

class LegacyTargetAssistitoComparisonReportEntry {
  final String expectedAssistitoId;
  final String actualAssistitoId;
  final bool matches;
  final int fieldCount;
  final int mismatchCount;
  final int reportedMismatchCount;
  final bool mismatchesTruncated;
  final bool documentIdentityValid;
  final bool hasDocumentIdentityIssue;
  final List<LegacyTargetAssistitoFieldComparison> mismatches;

  const LegacyTargetAssistitoComparisonReportEntry({
    required this.expectedAssistitoId,
    required this.actualAssistitoId,
    required this.matches,
    required this.fieldCount,
    required this.mismatchCount,
    required this.reportedMismatchCount,
    required this.mismatchesTruncated,
    required this.documentIdentityValid,
    required this.hasDocumentIdentityIssue,
    required this.mismatches,
  });

  factory LegacyTargetAssistitoComparisonReportEntry.fromComparison({
    required LegacyTargetAssistitoComparison comparison,
    required int maxReportedMismatches,
  }) {
    final int safeMismatchLimit = _safeLimit(maxReportedMismatches);
    final List<LegacyTargetAssistitoFieldComparison> allMismatches = comparison.mismatches;
    final List<LegacyTargetAssistitoFieldComparison> reportedMismatches = allMismatches
        .take(safeMismatchLimit)
        .toList(growable: false);
    final bool documentIdentityValid = comparison.documentIdentity?.isValid ?? true;

    return LegacyTargetAssistitoComparisonReportEntry(
      expectedAssistitoId: comparison.expectedAssistitoId,
      actualAssistitoId: comparison.actualAssistitoId,
      matches: comparison.matches,
      fieldCount: comparison.fieldCount,
      mismatchCount: comparison.mismatchCount,
      reportedMismatchCount: reportedMismatches.length,
      mismatchesTruncated: allMismatches.length > reportedMismatches.length,
      documentIdentityValid: documentIdentityValid,
      hasDocumentIdentityIssue: !documentIdentityValid,
      mismatches: List<LegacyTargetAssistitoFieldComparison>.unmodifiable(reportedMismatches),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'expectedAssistitoId': expectedAssistitoId,
      'actualAssistitoId': actualAssistitoId,
      'matches': matches,
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

class LegacyTargetAssistitoComparisonReport {
  final int comparisonCount;
  final int matchedCount;
  final int mismatchedCount;
  final int documentIdentityIssueCount;
  final int totalFieldMismatchCount;
  final int reportedComparisonCount;
  final int reportedMismatchCount;
  final int maxReportedComparisons;
  final int maxReportedMismatchesPerComparison;
  final bool comparisonsTruncated;
  final bool mismatchesTruncated;
  final List<LegacyTargetAssistitoComparisonReportEntry> comparisons;

  const LegacyTargetAssistitoComparisonReport({
    required this.comparisonCount,
    required this.matchedCount,
    required this.mismatchedCount,
    required this.documentIdentityIssueCount,
    required this.totalFieldMismatchCount,
    required this.reportedComparisonCount,
    required this.reportedMismatchCount,
    required this.maxReportedComparisons,
    required this.maxReportedMismatchesPerComparison,
    required this.comparisonsTruncated,
    required this.mismatchesTruncated,
    required this.comparisons,
  });

  factory LegacyTargetAssistitoComparisonReport.fromComparisons({
    required Iterable<LegacyTargetAssistitoComparison> comparisons,
    int maxReportedComparisons = 50,
    int maxReportedMismatchesPerComparison = 8,
    bool reportOnlyMismatches = true,
  }) {
    final int safeComparisonLimit = _safeLimit(maxReportedComparisons);
    final int safeMismatchLimit = _safeLimit(maxReportedMismatchesPerComparison);

    int comparisonCount = 0;
    int matchedCount = 0;
    int mismatchedCount = 0;
    int documentIdentityIssueCount = 0;
    int totalFieldMismatchCount = 0;
    int reportedMismatchCount = 0;
    bool comparisonsTruncated = false;
    bool mismatchesTruncated = false;

    final List<LegacyTargetAssistitoComparisonReportEntry> reported =
        <LegacyTargetAssistitoComparisonReportEntry>[];

    for (final LegacyTargetAssistitoComparison comparison in comparisons) {
      comparisonCount += 1;

      final bool isMatch = comparison.matches;
      final bool hasDocumentIdentityIssue = comparison.documentIdentity != null && !comparison.documentIdentity!.isValid;

      if (isMatch) {
        matchedCount += 1;
      } else {
        mismatchedCount += 1;
      }

      if (hasDocumentIdentityIssue) {
        documentIdentityIssueCount += 1;
      }

      totalFieldMismatchCount += comparison.mismatchCount;

      final bool shouldReport = !reportOnlyMismatches || !isMatch || hasDocumentIdentityIssue;
      if (!shouldReport) {
        continue;
      }

      if (reported.length >= safeComparisonLimit) {
        comparisonsTruncated = true;
        continue;
      }

      final LegacyTargetAssistitoComparisonReportEntry entry =
          LegacyTargetAssistitoComparisonReportEntry.fromComparison(
        comparison: comparison,
        maxReportedMismatches: safeMismatchLimit,
      );

      reportedMismatchCount += entry.reportedMismatchCount;
      if (entry.mismatchesTruncated) {
        mismatchesTruncated = true;
      }
      reported.add(entry);
    }

    return LegacyTargetAssistitoComparisonReport(
      comparisonCount: comparisonCount,
      matchedCount: matchedCount,
      mismatchedCount: mismatchedCount,
      documentIdentityIssueCount: documentIdentityIssueCount,
      totalFieldMismatchCount: totalFieldMismatchCount,
      reportedComparisonCount: reported.length,
      reportedMismatchCount: reportedMismatchCount,
      maxReportedComparisons: safeComparisonLimit,
      maxReportedMismatchesPerComparison: safeMismatchLimit,
      comparisonsTruncated: comparisonsTruncated,
      mismatchesTruncated: mismatchesTruncated,
      comparisons: List<LegacyTargetAssistitoComparisonReportEntry>.unmodifiable(reported),
    );
  }

  bool get allMatched {
    return mismatchedCount == 0 && documentIdentityIssueCount == 0;
  }

  bool get hasIssues {
    return !allMatched;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'comparisonCount': comparisonCount,
      'matchedCount': matchedCount,
      'mismatchedCount': mismatchedCount,
      'documentIdentityIssueCount': documentIdentityIssueCount,
      'totalFieldMismatchCount': totalFieldMismatchCount,
      'reportedComparisonCount': reportedComparisonCount,
      'reportedMismatchCount': reportedMismatchCount,
      'maxReportedComparisons': maxReportedComparisons,
      'maxReportedMismatchesPerComparison': maxReportedMismatchesPerComparison,
      'comparisonsTruncated': comparisonsTruncated,
      'mismatchesTruncated': mismatchesTruncated,
      'allMatched': allMatched,
      'hasIssues': hasIssues,
      'comparisons': comparisons
          .map((LegacyTargetAssistitoComparisonReportEntry comparison) => comparison.toMap())
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
