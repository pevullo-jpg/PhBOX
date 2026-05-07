import '../../core/constants/app_constants.dart';
import '../../core/utils/patient_input_normalizer.dart';
import '../datasources/firestore_datasource.dart';

class IdentityResolutionRequestsRepository {
  final FirestoreDatasource datasource;

  const IdentityResolutionRequestsRepository({required this.datasource});

  Future<String> createUserConfirmedRequest({
    required IdentityResolutionRequestAction action,
    required String targetFiscalCode,
    String? sourceFiscalCode,
    String? sourcePatientId,
    String? targetPatientId,
    String? selectedFiscalCode,
    String? normalizedName,
    String? reason,
    List<String> candidateFiscalCodes = const <String>[],
  }) async {
    final String normalizedTarget =
        PatientInputNormalizer.normalizeFiscalCode(targetFiscalCode);
    final String normalizedSource =
        PatientInputNormalizer.normalizeFiscalCode(sourceFiscalCode ?? '');
    final String normalizedSelected =
        PatientInputNormalizer.normalizeFiscalCode(selectedFiscalCode ?? '');
    final List<String> normalizedCandidates = candidateFiscalCodes
        .map(PatientInputNormalizer.normalizeFiscalCode)
        .where((String item) => item.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    if (normalizedTarget.isEmpty && normalizedSelected.isEmpty) {
      throw const IdentityResolutionRequestException(
        'Seleziona o inserisci un codice fiscale di destinazione.',
      );
    }

    final DateTime now = DateTime.now();
    final String requestId = _buildRequestId(action, normalizedTarget, now);
    final String effectiveTarget = normalizedTarget.isNotEmpty
        ? normalizedTarget
        : normalizedSelected;
    final Map<String, dynamic> data = <String, dynamic>{
      'status': action.backendProcessable
          ? 'user_confirmed'
          : 'user_confirmed_pending_backend_merge_executor',
      'action': action.value,
      'targetFiscalCode': effectiveTarget,
      if (normalizedSource.isNotEmpty) 'sourceFiscalCode': normalizedSource,
      if ((sourcePatientId ?? '').trim().isNotEmpty)
        'sourcePatientId': sourcePatientId!.trim(),
      if ((targetPatientId ?? '').trim().isNotEmpty)
        'targetPatientId': targetPatientId!.trim(),
      if (normalizedSelected.isNotEmpty) 'selectedFiscalCode': normalizedSelected,
      if ((normalizedName ?? '').trim().isNotEmpty)
        'normalizedName': normalizedName!.trim().toUpperCase(),
      if (normalizedCandidates.isNotEmpty) 'candidateFiscalCodes': normalizedCandidates,
      'reason': (reason ?? action.defaultReason).trim(),
      'createdBy': 'frontend_user_confirmed',
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'userConfirmedAt': now.toIso8601String(),
      'frontendContractVersion': 1,
    };

    await datasource.setDocument(
      collectionPath: AppCollections.identityResolutionRequests,
      documentId: requestId,
      data: data,
    );
    return requestId;
  }

  String _buildRequestId(
    IdentityResolutionRequestAction action,
    String targetFiscalCode,
    DateTime now,
  ) {
    final String target = targetFiscalCode.isEmpty ? 'NO_TARGET' : targetFiscalCode;
    return <String>[
      'identity',
      action.value,
      target,
      now.microsecondsSinceEpoch.toString(),
    ].join('_');
  }
}

enum IdentityResolutionRequestAction {
  createCanonicalPatient('create_canonical_patient'),
  mergeSameNamePatient('merge_same_name_patient'),
  mergeSimilarFiscalCodePatient('merge_similar_cf_patient'),
  chooseCorrectFiscalCode('choose_correct_fiscal_code');

  const IdentityResolutionRequestAction(this.value);

  final String value;

  bool get backendProcessable => this == createCanonicalPatient;

  String get defaultReason {
    switch (this) {
      case createCanonicalPatient:
        return 'frontend_user_confirmed_create_canonical_patient';
      case mergeSameNamePatient:
        return 'frontend_user_confirmed_same_name_merge_request';
      case mergeSimilarFiscalCodePatient:
        return 'frontend_user_confirmed_similar_cf_merge_request';
      case chooseCorrectFiscalCode:
        return 'frontend_user_confirmed_correct_cf_choice';
    }
  }
}

class IdentityResolutionRequestException implements Exception {
  final String message;

  const IdentityResolutionRequestException(this.message);

  @override
  String toString() => message;
}
