import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/target_multitenant_collections.dart';
import '../validators/manual_fiscal_code_input_validator.dart';

class TargetAssistitiDuplicateGuardRejectedException implements Exception {
  final String code;
  final String message;

  const TargetAssistitiDuplicateGuardRejectedException({
    required this.code,
    required this.message,
  });

  @override
  String toString() {
    return 'TargetAssistitiDuplicateGuardRejectedException($code): $message';
  }
}

class TargetAssistitiDuplicateGuardMatch {
  final String cf;
  final String documentId;
  final Map<String, dynamic> rawData;

  const TargetAssistitiDuplicateGuardMatch({
    required this.cf,
    required this.documentId,
    required this.rawData,
  });

  bool get exists => documentId.trim().isNotEmpty;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'cf': cf,
      'documentId': documentId,
      'exists': exists,
      'rawData': rawData,
    };
  }
}

class TargetAssistitiDuplicateGuardCheck {
  final String cf;
  final String collectionPath;
  final bool duplicateFound;
  final TargetAssistitiDuplicateGuardMatch? match;

  const TargetAssistitiDuplicateGuardCheck({
    required this.cf,
    required this.collectionPath,
    required this.duplicateFound,
    required this.match,
  });

  factory TargetAssistitiDuplicateGuardCheck.notFound({
    required String cf,
    required String collectionPath,
  }) {
    return TargetAssistitiDuplicateGuardCheck(
      cf: cf,
      collectionPath: collectionPath,
      duplicateFound: false,
      match: null,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'cf': cf,
      'collectionPath': collectionPath,
      'duplicateFound': duplicateFound,
      'match': match?.toMap(),
    };
  }
}

class TargetAssistitiDuplicateGuardResult {
  final String tenantId;
  final String collectionPath;
  final List<String> requestedFiscalCodes;
  final List<TargetAssistitiDuplicateGuardCheck> checks;
  final int maxFiscalCodes;
  final int attemptedQueries;

  const TargetAssistitiDuplicateGuardResult({
    required this.tenantId,
    required this.collectionPath,
    required this.requestedFiscalCodes,
    required this.checks,
    required this.maxFiscalCodes,
    required this.attemptedQueries,
  });

  int get requestedCount => requestedFiscalCodes.length;

  bool get hasDuplicates {
    return checks.any((TargetAssistitiDuplicateGuardCheck check) => check.duplicateFound);
  }

  List<String> get duplicateFiscalCodes {
    return checks
        .where((TargetAssistitiDuplicateGuardCheck check) => check.duplicateFound)
        .map((TargetAssistitiDuplicateGuardCheck check) => check.cf)
        .toList(growable: false);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tenantId': tenantId,
      'collectionPath': collectionPath,
      'requestedFiscalCodes': requestedFiscalCodes,
      'requestedCount': requestedCount,
      'maxFiscalCodes': maxFiscalCodes,
      'attemptedQueries': attemptedQueries,
      'hasDuplicates': hasDuplicates,
      'duplicateFiscalCodes': duplicateFiscalCodes,
      'checks': checks
          .map((TargetAssistitiDuplicateGuardCheck check) => check.toMap())
          .toList(growable: false),
    };
  }
}

class TargetAssistitiDuplicateGuardReader {
  static const int maxFiscalCodes = ManualFiscalCodeInputValidator.defaultMaxFiscalCodes;
  static const int maxQueriesPerRun = maxFiscalCodes;

  final FirebaseFirestore firestore;

  const TargetAssistitiDuplicateGuardReader({
    required this.firestore,
  });

  Future<TargetAssistitiDuplicateGuardResult> checkByManualFiscalCodes({
    required String tenantId,
    required Iterable<String> fiscalCodes,
  }) async {
    final String normalizedTenantId = _normalizeTenantId(tenantId);
    final List<String> normalizedFiscalCodes = _normalizeAndValidateManualFiscalCodes(fiscalCodes);
    final String collectionPath = TargetMultitenantCollections.tenantCollection(
      tenantId: normalizedTenantId,
      collectionId: TargetMultitenantCollections.assistiti,
    );
    final List<TargetAssistitiDuplicateGuardCheck> checks =
        <TargetAssistitiDuplicateGuardCheck>[];

    for (final String cf in normalizedFiscalCodes) {
      checks.add(await _checkOneFiscalCode(
        cf: cf,
        collectionPath: collectionPath,
      ));
    }

    return TargetAssistitiDuplicateGuardResult(
      tenantId: normalizedTenantId,
      collectionPath: collectionPath,
      requestedFiscalCodes: normalizedFiscalCodes,
      checks: List<TargetAssistitiDuplicateGuardCheck>.unmodifiable(checks),
      maxFiscalCodes: maxFiscalCodes,
      attemptedQueries: normalizedFiscalCodes.length,
    );
  }

  Future<TargetAssistitiDuplicateGuardResult> assertNoTargetDuplicates({
    required String tenantId,
    required Iterable<String> fiscalCodes,
  }) async {
    final TargetAssistitiDuplicateGuardResult result = await checkByManualFiscalCodes(
      tenantId: tenantId,
      fiscalCodes: fiscalCodes,
    );

    if (result.hasDuplicates) {
      throw TargetAssistitiDuplicateGuardRejectedException(
        code: 'target_assistito_cf_duplicate',
        message:
            'Assistito target già presente per CF: ${result.duplicateFiscalCodes.join(', ')}.',
      );
    }

    return result;
  }

  Future<TargetAssistitiDuplicateGuardCheck> _checkOneFiscalCode({
    required String cf,
    required String collectionPath,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await firestore
        .collection(collectionPath)
        .where('cf', isEqualTo: cf)
        .limit(1)
        .get(const GetOptions(source: Source.serverAndCache));

    if (snapshot.docs.isEmpty) {
      return TargetAssistitiDuplicateGuardCheck.notFound(
        cf: cf,
        collectionPath: collectionPath,
      );
    }

    final QueryDocumentSnapshot<Map<String, dynamic>> document = snapshot.docs.first;
    final Map<String, dynamic> data = Map<String, dynamic>.unmodifiable(document.data());

    return TargetAssistitiDuplicateGuardCheck(
      cf: cf,
      collectionPath: collectionPath,
      duplicateFound: true,
      match: TargetAssistitiDuplicateGuardMatch(
        cf: cf,
        documentId: document.id,
        rawData: data,
      ),
    );
  }

  static List<String> _normalizeAndValidateManualFiscalCodes(Iterable<String> fiscalCodes) {
    try {
      return ManualFiscalCodeInputValidator.normalizeAndValidate(
        fiscalCodes: fiscalCodes,
        maxFiscalCodes: maxFiscalCodes,
      );
    } on ManualFiscalCodeInputRejectedException catch (error) {
      throw TargetAssistitiDuplicateGuardRejectedException(
        code: error.code,
        message: error.message,
      );
    }
  }

  static String _normalizeTenantId(String value) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw const TargetAssistitiDuplicateGuardRejectedException(
        code: 'tenant_id_empty',
        message: 'tenantId obbligatorio per duplicate guard assistiti target.',
      );
    }
    if (normalized.contains('/')) {
      throw const TargetAssistitiDuplicateGuardRejectedException(
        code: 'tenant_id_not_canonical',
        message: 'tenantId non canonico: slash non ammesso.',
      );
    }
    return normalized;
  }
}
