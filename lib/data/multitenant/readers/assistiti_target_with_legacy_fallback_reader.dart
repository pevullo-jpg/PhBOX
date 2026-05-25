import 'package:cloud_firestore/cloud_firestore.dart';

import '../validators/manual_fiscal_code_input_validator.dart';
import 'legacy_real_assistiti_bounded_reader.dart';
import 'target_assistiti_duplicate_guard_reader.dart';

class AssistitiTargetWithLegacyFallbackRejectedException implements Exception {
  final String code;
  final String message;

  const AssistitiTargetWithLegacyFallbackRejectedException({
    required this.code,
    required this.message,
  });

  @override
  String toString() {
    return 'AssistitiTargetWithLegacyFallbackRejectedException($code): $message';
  }
}

class AssistitiTargetWithLegacyFallbackItem {
  static const String sourceTarget = 'target';
  static const String sourceLegacyFallback = 'legacy_fallback';
  static const String sourceMissing = 'missing';

  final String cf;
  final String source;
  final bool foundInTarget;
  final bool usedLegacyFallback;
  final bool missing;
  final String targetDocumentId;
  final Map<String, dynamic> targetRawData;
  final LegacyRealAssistitoReadBundle? legacyBundle;
  final List<String> reasons;

  const AssistitiTargetWithLegacyFallbackItem({
    required this.cf,
    required this.source,
    required this.foundInTarget,
    required this.usedLegacyFallback,
    required this.missing,
    required this.targetDocumentId,
    required this.targetRawData,
    required this.legacyBundle,
    required this.reasons,
  });

  bool get hasReadableData => foundInTarget || usedLegacyFallback;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'cf': cf,
      'source': source,
      'foundInTarget': foundInTarget,
      'usedLegacyFallback': usedLegacyFallback,
      'missing': missing,
      'hasReadableData': hasReadableData,
      'targetDocumentId': targetDocumentId,
      'targetRawData': targetRawData,
      'legacyBundle': legacyBundle?.toMap(),
      'reasons': reasons,
    };
  }
}

class AssistitiTargetWithLegacyFallbackResult {
  final String tenantId;
  final List<String> requestedFiscalCodes;
  final List<AssistitiTargetWithLegacyFallbackItem> items;
  final int maxFiscalCodes;
  final int targetAttemptedQueries;
  final int legacyAttemptedDocumentReads;
  final bool legacyFallbackEnabled;

  const AssistitiTargetWithLegacyFallbackResult({
    required this.tenantId,
    required this.requestedFiscalCodes,
    required this.items,
    required this.maxFiscalCodes,
    required this.targetAttemptedQueries,
    required this.legacyAttemptedDocumentReads,
    required this.legacyFallbackEnabled,
  });

  int get requestedCount => requestedFiscalCodes.length;

  bool get usedAnyLegacyFallback {
    return items.any((AssistitiTargetWithLegacyFallbackItem item) => item.usedLegacyFallback);
  }

  bool get hasMissingItems {
    return items.any((AssistitiTargetWithLegacyFallbackItem item) => item.missing);
  }

  List<String> get missingFiscalCodes {
    final List<String> missing = <String>[];
    for (final AssistitiTargetWithLegacyFallbackItem item in items) {
      if (item.missing) {
        missing.add(item.cf);
      }
    }
    return List<String>.unmodifiable(missing);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tenantId': tenantId,
      'requestedFiscalCodes': requestedFiscalCodes,
      'requestedCount': requestedCount,
      'maxFiscalCodes': maxFiscalCodes,
      'targetAttemptedQueries': targetAttemptedQueries,
      'legacyAttemptedDocumentReads': legacyAttemptedDocumentReads,
      'legacyFallbackEnabled': legacyFallbackEnabled,
      'usedAnyLegacyFallback': usedAnyLegacyFallback,
      'hasMissingItems': hasMissingItems,
      'missingFiscalCodes': missingFiscalCodes,
      'items': items
          .map((AssistitiTargetWithLegacyFallbackItem item) => item.toMap())
          .toList(growable: false),
    };
  }
}

class AssistitiTargetWithLegacyFallbackReader {
  static const int maxFiscalCodes = ManualFiscalCodeInputValidator.defaultMaxFiscalCodes;

  final FirebaseFirestore firestore;

  const AssistitiTargetWithLegacyFallbackReader({
    required this.firestore,
  });

  Future<AssistitiTargetWithLegacyFallbackResult> readByManualFiscalCodes({
    required String tenantId,
    required Iterable<String> fiscalCodes,
    bool enableLegacyFallback = true,
  }) async {
    final String normalizedTenantId = _normalizeTenantId(tenantId);
    final List<String> normalizedFiscalCodes = _normalizeAndValidateManualFiscalCodes(fiscalCodes);

    final TargetAssistitiDuplicateGuardReader targetReader = TargetAssistitiDuplicateGuardReader(
      firestore: firestore,
    );
    final TargetAssistitiDuplicateGuardResult targetResult =
        await targetReader.checkByManualFiscalCodes(
      tenantId: normalizedTenantId,
      fiscalCodes: normalizedFiscalCodes,
    );

    final Map<String, TargetAssistitiDuplicateGuardCheck> targetChecksByCf =
        <String, TargetAssistitiDuplicateGuardCheck>{
      for (final TargetAssistitiDuplicateGuardCheck check in targetResult.checks) check.cf: check,
    };

    final List<String> fiscalCodesMissingTarget = <String>[];
    final Map<String, AssistitiTargetWithLegacyFallbackItem> targetItemsByCf =
        <String, AssistitiTargetWithLegacyFallbackItem>{};

    for (final String cf in normalizedFiscalCodes) {
      final TargetAssistitiDuplicateGuardCheck? targetCheck = targetChecksByCf[cf];
      if (targetCheck == null) {
        throw AssistitiTargetWithLegacyFallbackRejectedException(
          code: 'target_check_missing_result',
          message: 'Risultato lettura target assente per CF $cf.',
        );
      }
      if (targetCheck.duplicateFound && targetCheck.match != null) {
        targetItemsByCf[cf] = AssistitiTargetWithLegacyFallbackItem(
          cf: cf,
          source: AssistitiTargetWithLegacyFallbackItem.sourceTarget,
          foundInTarget: true,
          usedLegacyFallback: false,
          missing: false,
          targetDocumentId: targetCheck.match!.documentId,
          targetRawData: targetCheck.match!.rawData,
          legacyBundle: null,
          reasons: const <String>[],
        );
      } else {
        fiscalCodesMissingTarget.add(cf);
      }
    }

    final Map<String, LegacyRealAssistitoReadBundle> legacyBundlesByCf =
        <String, LegacyRealAssistitoReadBundle>{};
    int legacyAttemptedDocumentReads = 0;

    if (enableLegacyFallback && fiscalCodesMissingTarget.isNotEmpty) {
      final LegacyRealAssistitiBoundedReader legacyReader = LegacyRealAssistitiBoundedReader(
        firestore: firestore,
      );
      final LegacyRealAssistitiBoundedReadResult legacyResult =
          await legacyReader.readByManualFiscalCodes(fiscalCodes: fiscalCodesMissingTarget);
      legacyAttemptedDocumentReads = legacyResult.attemptedDocumentReads;
      for (final LegacyRealAssistitoReadBundle bundle in legacyResult.bundles) {
        legacyBundlesByCf[bundle.cf] = bundle;
      }
    }

    final List<AssistitiTargetWithLegacyFallbackItem> items =
        <AssistitiTargetWithLegacyFallbackItem>[];
    for (final String cf in normalizedFiscalCodes) {
      final AssistitiTargetWithLegacyFallbackItem? targetItem = targetItemsByCf[cf];
      if (targetItem != null) {
        items.add(targetItem);
        continue;
      }

      final LegacyRealAssistitoReadBundle? legacyBundle = legacyBundlesByCf[cf];
      if (legacyBundle != null && legacyBundle.hasAnyLegacySource) {
        items.add(AssistitiTargetWithLegacyFallbackItem(
          cf: cf,
          source: AssistitiTargetWithLegacyFallbackItem.sourceLegacyFallback,
          foundInTarget: false,
          usedLegacyFallback: true,
          missing: false,
          targetDocumentId: '',
          targetRawData: const <String, dynamic>{},
          legacyBundle: legacyBundle,
          reasons: const <String>['target_missing_legacy_fallback_used'],
        ));
      } else {
        items.add(AssistitiTargetWithLegacyFallbackItem(
          cf: cf,
          source: AssistitiTargetWithLegacyFallbackItem.sourceMissing,
          foundInTarget: false,
          usedLegacyFallback: false,
          missing: true,
          targetDocumentId: '',
          targetRawData: const <String, dynamic>{},
          legacyBundle: legacyBundle,
          reasons: List<String>.unmodifiable(<String>[
            'target_missing',
            if (!enableLegacyFallback) 'legacy_fallback_disabled',
            if (enableLegacyFallback) 'legacy_source_missing',
          ]),
        ));
      }
    }

    return AssistitiTargetWithLegacyFallbackResult(
      tenantId: normalizedTenantId,
      requestedFiscalCodes: normalizedFiscalCodes,
      items: List<AssistitiTargetWithLegacyFallbackItem>.unmodifiable(items),
      maxFiscalCodes: maxFiscalCodes,
      targetAttemptedQueries: targetResult.attemptedQueries,
      legacyAttemptedDocumentReads: legacyAttemptedDocumentReads,
      legacyFallbackEnabled: enableLegacyFallback,
    );
  }

  static List<String> _normalizeAndValidateManualFiscalCodes(Iterable<String> fiscalCodes) {
    try {
      return ManualFiscalCodeInputValidator.normalizeAndValidate(
        fiscalCodes: fiscalCodes,
        maxFiscalCodes: maxFiscalCodes,
      );
    } on ManualFiscalCodeInputRejectedException catch (error) {
      throw AssistitiTargetWithLegacyFallbackRejectedException(
        code: error.code,
        message: error.message,
      );
    }
  }

  static String _normalizeTenantId(String value) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw const AssistitiTargetWithLegacyFallbackRejectedException(
        code: 'tenant_id_empty',
        message: 'tenantId obbligatorio per lettura assistiti con fallback legacy.',
      );
    }
    if (normalized.contains('/')) {
      throw const AssistitiTargetWithLegacyFallbackRejectedException(
        code: 'tenant_id_not_canonical',
        message: 'tenantId non canonico: slash non ammesso.',
      );
    }
    return normalized;
  }
}
