import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/target_multitenant_collections.dart';
import 'real_assistiti_migration1_data_report_reader.dart';

class RealAssistitiMigration1FirestoreReportRejectedException implements Exception {
  final String code;
  final String message;

  const RealAssistitiMigration1FirestoreReportRejectedException({
    required this.code,
    required this.message,
  });

  @override
  String toString() {
    return 'RealAssistitiMigration1FirestoreReportRejectedException($code): $message';
  }
}

class RealAssistitiMigration1FirestoreReportReader {
  static const int defaultMaxAssistitiScan =
      RealAssistitiMigration1DataReportReader.maxInputDocuments;
  static const int maxFirestoreReadsPerRun = defaultMaxAssistitiScan;
  static const int firestoreWritesPerRun = 0;
  static const GetOptions migrationReportGetOptions = GetOptions(source: Source.server);

  final FirebaseFirestore firestore;

  const RealAssistitiMigration1FirestoreReportReader({
    required this.firestore,
  });

  Future<RealAssistitiMigration1DataReportResult> readReport({
    required String tenantId,
    int maxAssistitiScan = defaultMaxAssistitiScan,
  }) async {
    final String normalizedTenantId = normalizeTenantId(tenantId);
    final int safeMaxAssistitiScan = normalizeMaxAssistitiScan(maxAssistitiScan);
    final String collectionPath = assistitiCollectionPath(tenantId: normalizedTenantId);

    final QuerySnapshot<Map<String, dynamic>> snapshot = await firestore
        .collection(collectionPath)
        .limit(safeMaxAssistitiScan)
        .get(migrationReportGetOptions);

    final List<RealAssistitiMigration1DataReportRawDocument> rawDocuments =
        <RealAssistitiMigration1DataReportRawDocument>[];
    for (final QueryDocumentSnapshot<Map<String, dynamic>> document in snapshot.docs) {
      rawDocuments.add(RealAssistitiMigration1DataReportRawDocument(
        documentId: document.id,
        rawData: document.data(),
      ));
    }

    return buildReportFromFetchedRawDocuments(
      tenantId: normalizedTenantId,
      documents: rawDocuments,
      firestoreReads: snapshot.docs.length,
    );
  }

  static RealAssistitiMigration1DataReportResult buildReportFromFetchedRawDocuments({
    required String tenantId,
    required Iterable<RealAssistitiMigration1DataReportRawDocument> documents,
    required int firestoreReads,
  }) {
    final String normalizedTenantId = normalizeTenantId(tenantId);
    assertFirestoreReadBudget(firestoreReads);

    final RealAssistitiMigration1DataReportResult rawReport =
        RealAssistitiMigration1DataReportReader.buildReportFromRawDocuments(
      tenantId: normalizedTenantId,
      documents: documents,
    );

    return RealAssistitiMigration1DataReportResult(
      tenantId: rawReport.tenantId,
      items: rawReport.items,
      summary: rawReport.summary,
      maxInputDocuments: rawReport.maxInputDocuments,
      maxSearchPrefixesPerDocument: rawReport.maxSearchPrefixesPerDocument,
      firestoreReads: firestoreReads,
      firestoreWrites: firestoreWritesPerRun,
    );
  }

  static String assistitiCollectionPath({required String tenantId}) {
    final String normalizedTenantId = normalizeTenantId(tenantId);
    return TargetMultitenantCollections.tenantCollection(
      tenantId: normalizedTenantId,
      collectionId: TargetMultitenantCollections.assistiti,
    );
  }

  static int normalizeMaxAssistitiScan(int value) {
    if (value <= 0) {
      return defaultMaxAssistitiScan;
    }
    if (value > defaultMaxAssistitiScan) {
      return defaultMaxAssistitiScan;
    }
    return value;
  }

  static void assertFirestoreReadBudget(int firestoreReads) {
    if (firestoreReads < 0) {
      throw const RealAssistitiMigration1FirestoreReportRejectedException(
        code: 'firestore_reads_negative',
        message: 'Conteggio letture Firestore negativo non valido per report Migration 1.',
      );
    }
    if (firestoreReads > maxFirestoreReadsPerRun) {
      throw const RealAssistitiMigration1FirestoreReportRejectedException(
        code: 'firestore_reads_exceed_hard_cap',
        message: 'Report Migration 1 oltre hard cap letture Firestore.',
      );
    }
  }

  static String normalizeTenantId(String value) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw const RealAssistitiMigration1FirestoreReportRejectedException(
        code: 'tenant_id_empty',
        message: 'tenantId obbligatorio per report Firestore Migration 1.',
      );
    }
    if (normalized.contains('/')) {
      throw const RealAssistitiMigration1FirestoreReportRejectedException(
        code: 'tenant_id_not_canonical',
        message: 'tenantId non canonico: slash non ammesso.',
      );
    }
    return normalized;
  }
}
