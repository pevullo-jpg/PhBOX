import 'package:cloud_firestore/cloud_firestore.dart';

import '../validators/manual_fiscal_code_input_validator.dart';

class LegacyRealAssistitiBoundedReadRejectedException implements Exception {
  final String code;
  final String message;

  const LegacyRealAssistitiBoundedReadRejectedException({
    required this.code,
    required this.message,
  });

  @override
  String toString() {
    return 'LegacyRealAssistitiBoundedReadRejectedException($code): $message';
  }
}

class LegacyRealAssistitiSourceRead {
  final String collectionId;
  final String documentId;
  final bool exists;
  final Map<String, dynamic> rawData;

  const LegacyRealAssistitiSourceRead({
    required this.collectionId,
    required this.documentId,
    required this.exists,
    required this.rawData,
  });

  bool get missing => !exists;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'collectionId': collectionId,
      'documentId': documentId,
      'exists': exists,
      'missing': missing,
      'rawData': rawData,
    };
  }
}

class LegacyRealAssistitoReadBundle {
  final String cf;
  final LegacyRealAssistitiSourceRead patient;
  final LegacyRealAssistitiSourceRead dashboardIndex;
  final LegacyRealAssistitiSourceRead therapeuticAdvice;
  final LegacyRealAssistitiSourceRead doctorManual;
  final LegacyRealAssistitiSourceRead doctorPrimary;

  const LegacyRealAssistitoReadBundle({
    required this.cf,
    required this.patient,
    required this.dashboardIndex,
    required this.therapeuticAdvice,
    required this.doctorManual,
    required this.doctorPrimary,
  });

  bool get hasCanonicalPatient => patient.exists;

  bool get hasAnyLegacySource =>
      patient.exists ||
      dashboardIndex.exists ||
      therapeuticAdvice.exists ||
      doctorManual.exists ||
      doctorPrimary.exists;

  int get existingSourceCount {
    int count = 0;
    final List<LegacyRealAssistitiSourceRead> sources = <LegacyRealAssistitiSourceRead>[
      patient,
      dashboardIndex,
      therapeuticAdvice,
      doctorManual,
      doctorPrimary,
    ];
    for (final LegacyRealAssistitiSourceRead source in sources) {
      if (source.exists) {
        count++;
      }
    }
    return count;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'cf': cf,
      'hasCanonicalPatient': hasCanonicalPatient,
      'hasAnyLegacySource': hasAnyLegacySource,
      'existingSourceCount': existingSourceCount,
      'patient': patient.toMap(),
      'dashboardIndex': dashboardIndex.toMap(),
      'therapeuticAdvice': therapeuticAdvice.toMap(),
      'doctorManual': doctorManual.toMap(),
      'doctorPrimary': doctorPrimary.toMap(),
    };
  }
}

class LegacyRealAssistitiBoundedReadResult {
  final List<String> requestedFiscalCodes;
  final List<LegacyRealAssistitoReadBundle> bundles;
  final int maxFiscalCodes;
  final int attemptedDocumentReads;

  const LegacyRealAssistitiBoundedReadResult({
    required this.requestedFiscalCodes,
    required this.bundles,
    required this.maxFiscalCodes,
    required this.attemptedDocumentReads,
  });

  bool get empty => bundles.isEmpty;

  int get requestedCount => requestedFiscalCodes.length;

  int get returnedCount => bundles.length;

  bool get hasMissingLegacySources =>
      bundles.any((LegacyRealAssistitoReadBundle bundle) => !bundle.hasAnyLegacySource);

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'requestedFiscalCodes': requestedFiscalCodes,
      'requestedCount': requestedCount,
      'returnedCount': returnedCount,
      'maxFiscalCodes': maxFiscalCodes,
      'attemptedDocumentReads': attemptedDocumentReads,
      'hasMissingLegacySources': hasMissingLegacySources,
      'bundles': bundles
          .map((LegacyRealAssistitoReadBundle bundle) => bundle.toMap())
          .toList(growable: false),
    };
  }
}

class LegacyRealAssistitiBoundedReader {
  static const int maxFiscalCodes = ManualFiscalCodeInputValidator.defaultMaxFiscalCodes;
  static const int readsPerFiscalCode = 5;

  static const String patientsCollection = 'patients';
  static const String dashboardIndexCollection = 'patient_dashboard_index';
  static const String therapeuticAdviceCollection = 'patient_therapeutic_advice';
  static const String doctorPatientLinksCollection = 'doctor_patient_links';
  static const String manualDoctorLinkSuffix = '__manual';
  static const String primaryDoctorLinkSuffix = '__primary';

  final FirebaseFirestore firestore;

  const LegacyRealAssistitiBoundedReader({
    required this.firestore,
  });

  Future<LegacyRealAssistitiBoundedReadResult> readByManualFiscalCodes({
    required Iterable<String> fiscalCodes,
  }) async {
    final List<String> normalizedFiscalCodes = normalizeAndValidateManualFiscalCodes(fiscalCodes);
    final List<LegacyRealAssistitoReadBundle> bundles = <LegacyRealAssistitoReadBundle>[];

    for (final String cf in normalizedFiscalCodes) {
      bundles.add(await _readOneFiscalCode(cf));
    }

    return LegacyRealAssistitiBoundedReadResult(
      requestedFiscalCodes: normalizedFiscalCodes,
      bundles: List<LegacyRealAssistitoReadBundle>.unmodifiable(bundles),
      maxFiscalCodes: maxFiscalCodes,
      attemptedDocumentReads: normalizedFiscalCodes.length * readsPerFiscalCode,
    );
  }

  Future<LegacyRealAssistitoReadBundle> _readOneFiscalCode(String cf) async {
    final LegacyRealAssistitiSourceRead patient = await _readDocument(
      collectionId: patientsCollection,
      documentId: cf,
    );
    final LegacyRealAssistitiSourceRead dashboardIndex = await _readDocument(
      collectionId: dashboardIndexCollection,
      documentId: cf,
    );
    final LegacyRealAssistitiSourceRead therapeuticAdvice = await _readDocument(
      collectionId: therapeuticAdviceCollection,
      documentId: cf,
    );
    final LegacyRealAssistitiSourceRead doctorManual = await _readDocument(
      collectionId: doctorPatientLinksCollection,
      documentId: '$cf$manualDoctorLinkSuffix',
    );
    final LegacyRealAssistitiSourceRead doctorPrimary = await _readDocument(
      collectionId: doctorPatientLinksCollection,
      documentId: '$cf$primaryDoctorLinkSuffix',
    );

    return LegacyRealAssistitoReadBundle(
      cf: cf,
      patient: patient,
      dashboardIndex: dashboardIndex,
      therapeuticAdvice: therapeuticAdvice,
      doctorManual: doctorManual,
      doctorPrimary: doctorPrimary,
    );
  }

  Future<LegacyRealAssistitiSourceRead> _readDocument({
    required String collectionId,
    required String documentId,
  }) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await firestore
        .collection(collectionId)
        .doc(documentId)
        .get(const GetOptions(source: Source.serverAndCache));

    return LegacyRealAssistitiSourceRead(
      collectionId: collectionId,
      documentId: documentId,
      exists: snapshot.exists,
      rawData: Map<String, dynamic>.unmodifiable(snapshot.data() ?? <String, dynamic>{}),
    );
  }

  static List<String> normalizeAndValidateManualFiscalCodes(Iterable<String> fiscalCodes) {
    try {
      return ManualFiscalCodeInputValidator.normalizeAndValidate(
        fiscalCodes: fiscalCodes,
        maxFiscalCodes: maxFiscalCodes,
      );
    } on ManualFiscalCodeInputRejectedException catch (error) {
      throw LegacyRealAssistitiBoundedReadRejectedException(
        code: error.code,
        message: error.message,
      );
    }
  }
}
