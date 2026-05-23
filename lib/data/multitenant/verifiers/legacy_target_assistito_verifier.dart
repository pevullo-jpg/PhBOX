import '../mappers/legacy_to_target_assistito_mapper.dart';
import '../models/legacy_target_assistito_comparison.dart';
import '../models/target_assistito.dart';
import '../reports/legacy_target_assistito_comparison_report.dart';

class LegacyTargetAssistitoVerificationInput {
  final LegacyAssistitoSourceBundle legacy;
  final String targetDocumentId;
  final Map<String, dynamic>? targetData;

  const LegacyTargetAssistitoVerificationInput({
    required this.legacy,
    required this.targetDocumentId,
    required this.targetData,
  });

  bool get targetDocumentPresent => targetData != null;
}

class LegacyTargetAssistitoVerificationResult {
  final String expectedAssistitoId;
  final String targetDocumentId;
  final bool targetDocumentPresent;
  final bool targetDocumentIdMatchesExpected;
  final LegacyTargetAssistitoComparison comparison;

  const LegacyTargetAssistitoVerificationResult({
    required this.expectedAssistitoId,
    required this.targetDocumentId,
    required this.targetDocumentPresent,
    required this.targetDocumentIdMatchesExpected,
    required this.comparison,
  });

  bool get verified {
    return targetDocumentPresent && targetDocumentIdMatchesExpected && comparison.matches;
  }

  bool get hasIssues => !verified;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'expectedAssistitoId': expectedAssistitoId,
      'targetDocumentId': targetDocumentId,
      'targetDocumentPresent': targetDocumentPresent,
      'targetDocumentIdMatchesExpected': targetDocumentIdMatchesExpected,
      'verified': verified,
      'hasIssues': hasIssues,
      'comparison': comparison.toMap(),
    };
  }
}

class LegacyTargetAssistitoVerificationReport {
  final int inputCount;
  final int verifiedCount;
  final int issueCount;
  final int targetDocumentPresentCount;
  final int targetDocumentMissingCount;
  final int targetDocumentIdMismatchCount;
  final LegacyTargetAssistitoComparisonReport comparisonReport;

  const LegacyTargetAssistitoVerificationReport({
    required this.inputCount,
    required this.verifiedCount,
    required this.issueCount,
    required this.targetDocumentPresentCount,
    required this.targetDocumentMissingCount,
    required this.targetDocumentIdMismatchCount,
    required this.comparisonReport,
  });

  bool get allVerified {
    return issueCount == 0 && comparisonReport.allMatched;
  }

  bool get hasIssues => !allVerified;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'inputCount': inputCount,
      'verifiedCount': verifiedCount,
      'issueCount': issueCount,
      'targetDocumentPresentCount': targetDocumentPresentCount,
      'targetDocumentMissingCount': targetDocumentMissingCount,
      'targetDocumentIdMismatchCount': targetDocumentIdMismatchCount,
      'allVerified': allVerified,
      'hasIssues': hasIssues,
      'comparisonReport': comparisonReport.toMap(),
    };
  }
}

class LegacyTargetAssistitoVerifier {
  final LegacyToTargetAssistitoMapper mapper;

  const LegacyTargetAssistitoVerifier({
    this.mapper = const LegacyToTargetAssistitoMapper(),
  });

  LegacyTargetAssistitoVerificationResult verifyOne({
    required LegacyAssistitoSourceBundle legacy,
    required String targetDocumentId,
    required Map<String, dynamic>? targetData,
    bool compareTimestamps = false,
  }) {
    final TargetAssistito expected = mapper.map(legacy);
    final String resolvedTargetDocumentId = targetDocumentId.trim().isEmpty
        ? expected.assistitoId
        : targetDocumentId.trim();
    final Map<String, dynamic> resolvedTargetData =
        targetData == null ? const <String, dynamic>{} : Map<String, dynamic>.unmodifiable(targetData);

    final TargetAssistito actual = targetData == null
        ? TargetAssistito.empty(
            assistitoId: resolvedTargetDocumentId,
          )
        : TargetAssistito.fromMap(
            assistitoId: resolvedTargetDocumentId,
            map: resolvedTargetData,
          );

    final TargetAssistitoDocumentIdentityComparison documentIdentity =
        TargetAssistitoDocumentIdentityComparison.fromDocument(
      documentId: resolvedTargetDocumentId,
      data: resolvedTargetData,
    );

    final LegacyTargetAssistitoComparison comparison =
        LegacyTargetAssistitoComparison.fromAssistiti(
      expected: expected,
      actual: actual,
      documentIdentity: documentIdentity,
      compareTimestamps: compareTimestamps,
    );

    return LegacyTargetAssistitoVerificationResult(
      expectedAssistitoId: expected.assistitoId,
      targetDocumentId: resolvedTargetDocumentId,
      targetDocumentPresent: targetData != null,
      targetDocumentIdMatchesExpected: expected.assistitoId == resolvedTargetDocumentId,
      comparison: comparison,
    );
  }

  LegacyTargetAssistitoVerificationReport verifyMany({
    required Iterable<LegacyTargetAssistitoVerificationInput> inputs,
    bool compareTimestamps = false,
    int maxReportedComparisons = 50,
    int maxReportedMismatchesPerComparison = 8,
    bool reportOnlyMismatches = true,
  }) {
    int inputCount = 0;
    int verifiedCount = 0;
    int targetDocumentPresentCount = 0;
    int targetDocumentMissingCount = 0;
    int targetDocumentIdMismatchCount = 0;

    final List<LegacyTargetAssistitoComparison> comparisons =
        <LegacyTargetAssistitoComparison>[];

    for (final LegacyTargetAssistitoVerificationInput input in inputs) {
      inputCount += 1;
      final LegacyTargetAssistitoVerificationResult result = verifyOne(
        legacy: input.legacy,
        targetDocumentId: input.targetDocumentId,
        targetData: input.targetData,
        compareTimestamps: compareTimestamps,
      );

      if (result.targetDocumentPresent) {
        targetDocumentPresentCount += 1;
      } else {
        targetDocumentMissingCount += 1;
      }

      if (!result.targetDocumentIdMatchesExpected) {
        targetDocumentIdMismatchCount += 1;
      }

      if (result.verified) {
        verifiedCount += 1;
      }

      comparisons.add(result.comparison);
    }

    final LegacyTargetAssistitoComparisonReport comparisonReport =
        LegacyTargetAssistitoComparisonReport.fromComparisons(
      comparisons: comparisons,
      maxReportedComparisons: maxReportedComparisons,
      maxReportedMismatchesPerComparison: maxReportedMismatchesPerComparison,
      reportOnlyMismatches: reportOnlyMismatches,
    );

    return LegacyTargetAssistitoVerificationReport(
      inputCount: inputCount,
      verifiedCount: verifiedCount,
      issueCount: inputCount - verifiedCount,
      targetDocumentPresentCount: targetDocumentPresentCount,
      targetDocumentMissingCount: targetDocumentMissingCount,
      targetDocumentIdMismatchCount: targetDocumentIdMismatchCount,
      comparisonReport: comparisonReport,
    );
  }
}
