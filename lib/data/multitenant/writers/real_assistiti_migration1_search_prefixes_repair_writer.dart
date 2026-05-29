import 'package:cloud_firestore/cloud_firestore.dart';

import '../mappers/real_assistiti_target_preview_mapper.dart';
import '../models/target_multitenant_collections.dart';
import '../normalizers/target_assistito_identity_normalizer.dart';
import '../normalizers/target_assistito_nocf_identity_anchor_normalizer.dart';
import '../reports/real_assistiti_migration1_data_report_reader.dart';

class RealAssistitiMigration1SearchPrefixesRepairRejectedException implements Exception {
  final String code;
  final String message;

  const RealAssistitiMigration1SearchPrefixesRepairRejectedException({
    required this.code,
    required this.message,
  });

  @override
  String toString() {
    return 'RealAssistitiMigration1SearchPrefixesRepairRejectedException($code): $message';
  }
}

class RealAssistitiMigration1SearchPrefixesRepairPlan {
  final bool repairable;
  final String skipReason;
  final String fullName;
  final List<String> expectedSearchPrefixes;
  final bool alreadyConsistent;

  const RealAssistitiMigration1SearchPrefixesRepairPlan({
    required this.repairable,
    required this.skipReason,
    required this.fullName,
    required this.expectedSearchPrefixes,
    required this.alreadyConsistent,
  });
}

class RealAssistitiMigration1SearchPrefixesRepairItem {
  final String assistitoId;
  final String documentPath;
  final String fullName;
  final bool repaired;
  final bool skipped;
  final String skipReason;
  final int expectedSearchPrefixesCount;
  final int attemptedReads;
  final int attemptedWrites;

  const RealAssistitiMigration1SearchPrefixesRepairItem({
    required this.assistitoId,
    required this.documentPath,
    required this.fullName,
    required this.repaired,
    required this.skipped,
    required this.skipReason,
    required this.expectedSearchPrefixesCount,
    required this.attemptedReads,
    required this.attemptedWrites,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'assistitoId': assistitoId,
      'documentPath': documentPath,
      'fullName': fullName,
      'repaired': repaired,
      'skipped': skipped,
      'skipReason': skipReason,
      'expectedSearchPrefixesCount': expectedSearchPrefixesCount,
      'attemptedReads': attemptedReads,
      'attemptedWrites': attemptedWrites,
    };
  }
}

class RealAssistitiMigration1SearchPrefixesRepairResult {
  final String tenantId;
  final List<String> requestedAssistitoIds;
  final List<RealAssistitiMigration1SearchPrefixesRepairItem> items;
  final int attemptedReads;
  final int attemptedWrites;

  const RealAssistitiMigration1SearchPrefixesRepairResult({
    required this.tenantId,
    required this.requestedAssistitoIds,
    required this.items,
    required this.attemptedReads,
    required this.attemptedWrites,
  });

  int get repairedCount {
    return items.where((RealAssistitiMigration1SearchPrefixesRepairItem item) => item.repaired).length;
  }

  int get skippedCount {
    return items.where((RealAssistitiMigration1SearchPrefixesRepairItem item) => item.skipped).length;
  }

  bool get hasWrites => attemptedWrites > 0;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tenantId': tenantId,
      'requestedAssistitoIds': requestedAssistitoIds,
      'repairedCount': repairedCount,
      'skippedCount': skippedCount,
      'attemptedReads': attemptedReads,
      'attemptedWrites': attemptedWrites,
      'items': items
          .map((RealAssistitiMigration1SearchPrefixesRepairItem item) => item.toMap())
          .toList(growable: false),
    };
  }
}

class RealAssistitiMigration1SearchPrefixesRepairWriter {
  static const int maxAssistitiPerRun = 2;
  static const String resolvedManualStatus = RealAssistitiMigration1DataReportReader.resolvedManualStatus;
  static const String resolvedManualConfidence = RealAssistitiMigration1DataReportReader.resolvedManualConfidence;

  final FirebaseFirestore firestore;

  const RealAssistitiMigration1SearchPrefixesRepairWriter({
    required this.firestore,
  });

  Future<RealAssistitiMigration1SearchPrefixesRepairResult> repairByAssistitoIds({
    required String tenantId,
    required Iterable<String> assistitoIds,
  }) async {
    final String normalizedTenantId = normalizeTenantId(tenantId);
    final List<String> normalizedAssistitoIds = normalizeAssistitoIds(assistitoIds);
    final List<RealAssistitiMigration1SearchPrefixesRepairItem> items =
        <RealAssistitiMigration1SearchPrefixesRepairItem>[];

    for (final String assistitoId in normalizedAssistitoIds) {
      items.add(await _repairSingle(
        tenantId: normalizedTenantId,
        assistitoId: assistitoId,
      ));
    }

    int attemptedReads = 0;
    int attemptedWrites = 0;
    for (final RealAssistitiMigration1SearchPrefixesRepairItem item in items) {
      attemptedReads += item.attemptedReads;
      attemptedWrites += item.attemptedWrites;
    }

    return RealAssistitiMigration1SearchPrefixesRepairResult(
      tenantId: normalizedTenantId,
      requestedAssistitoIds: normalizedAssistitoIds,
      items: List<RealAssistitiMigration1SearchPrefixesRepairItem>.unmodifiable(items),
      attemptedReads: attemptedReads,
      attemptedWrites: attemptedWrites,
    );
  }

  Future<RealAssistitiMigration1SearchPrefixesRepairItem> _repairSingle({
    required String tenantId,
    required String assistitoId,
  }) async {
    final String documentPath = TargetMultitenantCollections.assistitoDocument(
      tenantId: tenantId,
      assistitoId: assistitoId,
    );
    final DocumentReference<Map<String, dynamic>> documentRef = firestore.doc(documentPath);

    return firestore.runTransaction<RealAssistitiMigration1SearchPrefixesRepairItem>(
      (Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction.get(documentRef);
        final Map<String, dynamic> rawData = snapshot.data() ?? <String, dynamic>{};
        if (!snapshot.exists) {
          return RealAssistitiMigration1SearchPrefixesRepairItem(
            assistitoId: assistitoId,
            documentPath: documentPath,
            fullName: '',
            repaired: false,
            skipped: true,
            skipReason: 'target_document_missing',
            expectedSearchPrefixesCount: 0,
            attemptedReads: 1,
            attemptedWrites: 0,
          );
        }

        final RealAssistitiMigration1SearchPrefixesRepairPlan plan = buildRepairPlan(rawData);
        if (!plan.repairable) {
          return RealAssistitiMigration1SearchPrefixesRepairItem(
            assistitoId: assistitoId,
            documentPath: documentPath,
            fullName: plan.fullName,
            repaired: false,
            skipped: true,
            skipReason: plan.skipReason,
            expectedSearchPrefixesCount: plan.expectedSearchPrefixes.length,
            attemptedReads: 1,
            attemptedWrites: 0,
          );
        }

        if (plan.alreadyConsistent) {
          return RealAssistitiMigration1SearchPrefixesRepairItem(
            assistitoId: assistitoId,
            documentPath: documentPath,
            fullName: plan.fullName,
            repaired: false,
            skipped: true,
            skipReason: 'already_consistent',
            expectedSearchPrefixesCount: plan.expectedSearchPrefixes.length,
            attemptedReads: 1,
            attemptedWrites: 0,
          );
        }

        transaction.update(documentRef, <String, dynamic>{
          'searchPrefixes': plan.expectedSearchPrefixes,
        });

        return RealAssistitiMigration1SearchPrefixesRepairItem(
          assistitoId: assistitoId,
          documentPath: documentPath,
          fullName: plan.fullName,
          repaired: true,
          skipped: false,
          skipReason: '',
          expectedSearchPrefixesCount: plan.expectedSearchPrefixes.length,
          attemptedReads: 1,
          attemptedWrites: 1,
        );
      },
    );
  }

  static RealAssistitiMigration1SearchPrefixesRepairPlan buildRepairPlan(
    Map<String, dynamic> rawData,
  ) {
    final String identityType = _readString(rawData['identityType']);
    final String identityResolutionStatus = _readString(rawData['identityResolutionStatus']);
    final String nestedIdentityResolutionStatus = _readNestedStatus(rawData['identityResolution']);
    final String nameSplitConfidence = _readString(rawData['nameSplitConfidence']);
    final String fullName = _readString(rawData['fullName']);
    final List<String> currentSearchPrefixes = _readStringList(rawData['searchPrefixes']);

    if (identityType != TargetAssistitoNoCfIdentityAnchorNormalizer.identityTypeNoCf) {
      return _skipPlan(skipReason: 'target_identity_type_not_nocf', fullName: fullName);
    }
    if (identityResolutionStatus != resolvedManualStatus ||
        nestedIdentityResolutionStatus != resolvedManualStatus ||
        nameSplitConfidence != resolvedManualConfidence) {
      return _skipPlan(skipReason: 'target_identity_resolution_state_not_resolved_manual', fullName: fullName);
    }
    if (fullName.isEmpty ||
        TargetAssistitoIdentityNormalizer.isPlaceholderName(fullName) ||
        TargetAssistitoIdentityNormalizer.isFiscalCodeLike(fullName) ||
        TargetAssistitoIdentityNormalizer.containsFiscalCodeLikeToken(fullName)) {
      return _skipPlan(skipReason: 'target_full_name_not_repairable', fullName: fullName);
    }

    final String normalizedFullName = TargetAssistitoIdentityNormalizer.normalizeFullName(fullName);
    if (normalizedFullName != fullName.trim()) {
      return _skipPlan(skipReason: 'target_full_name_not_canonical', fullName: fullName);
    }

    final List<String> expectedSearchPrefixes = RealAssistitiTargetPreviewMapper.buildSearchPrefixes(fullName);
    if (expectedSearchPrefixes.isEmpty) {
      return _skipPlan(skipReason: 'target_expected_search_prefixes_empty', fullName: fullName);
    }

    return RealAssistitiMigration1SearchPrefixesRepairPlan(
      repairable: true,
      skipReason: '',
      fullName: fullName,
      expectedSearchPrefixes: expectedSearchPrefixes,
      alreadyConsistent: _listEquals(currentSearchPrefixes, expectedSearchPrefixes),
    );
  }

  static List<String> normalizeAssistitoIds(Iterable<String> values) {
    final List<String> normalized = <String>[];
    int rawItemsSeen = 0;
    for (final String value in values) {
      rawItemsSeen++;
      if (rawItemsSeen > maxAssistitiPerRun) {
        throw const RealAssistitiMigration1SearchPrefixesRepairRejectedException(
          code: 'assistito_ids_exceed_hard_cap',
          message: 'Cleanup searchPrefixes Migration 1 limitato a massimo 2 assistiti per run.',
        );
      }
      final String assistitoId = _normalizeSegment(value, label: 'assistitoId');
      if (!normalized.contains(assistitoId)) {
        normalized.add(assistitoId);
      }
    }
    if (normalized.isEmpty) {
      throw const RealAssistitiMigration1SearchPrefixesRepairRejectedException(
        code: 'assistito_ids_empty',
        message: 'Almeno un assistitoId obbligatorio per cleanup searchPrefixes Migration 1.',
      );
    }
    return List<String>.unmodifiable(normalized);
  }

  static String normalizeTenantId(String value) {
    return _normalizeSegment(value, label: 'tenantId');
  }

  static RealAssistitiMigration1SearchPrefixesRepairPlan _skipPlan({
    required String skipReason,
    required String fullName,
  }) {
    return RealAssistitiMigration1SearchPrefixesRepairPlan(
      repairable: false,
      skipReason: skipReason,
      fullName: fullName,
      expectedSearchPrefixes: const <String>[],
      alreadyConsistent: false,
    );
  }

  static String _normalizeSegment(String value, {required String label}) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw RealAssistitiMigration1SearchPrefixesRepairRejectedException(
        code: '${label}_empty',
        message: '$label obbligatorio per cleanup searchPrefixes Migration 1.',
      );
    }
    if (normalized.contains('/')) {
      throw RealAssistitiMigration1SearchPrefixesRepairRejectedException(
        code: '${label}_not_canonical',
        message: '$label non canonico: slash non ammesso.',
      );
    }
    return normalized;
  }

  static String _readNestedStatus(Object? value) {
    if (value is Map) {
      return _readString(value['status']);
    }
    return '';
  }

  static List<String> _readStringList(Object? value) {
    if (value is! Iterable) {
      return const <String>[];
    }
    final List<String> result = <String>[];
    for (final Object? item in value.take(RealAssistitiMigration1DataReportReader.maxSearchPrefixesPerDocument + 1)) {
      final String normalized = _readString(item);
      if (normalized.isNotEmpty) {
        result.add(normalized);
      }
    }
    return List<String>.unmodifiable(result);
  }

  static String _readString(Object? value) {
    return value?.toString().trim() ?? '';
  }

  static bool _listEquals(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (int index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}
