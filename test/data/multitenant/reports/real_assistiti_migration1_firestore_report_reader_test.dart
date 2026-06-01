import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farmacia_desk_web/data/multitenant/mappers/real_assistiti_target_preview_mapper.dart';
import 'package:farmacia_desk_web/data/multitenant/reports/real_assistiti_migration1_data_report_reader.dart';
import 'package:farmacia_desk_web/data/multitenant/reports/real_assistiti_migration1_firestore_report_reader.dart';

void main() {
  group('RealAssistitiMigration1FirestoreReportReader', () {
    test('uses server-only reads for Migration 1 gate reports', () {
      expect(
        RealAssistitiMigration1FirestoreReportReader.migrationReportGetOptions.source,
        Source.server,
      );
    });

    test('normalizes max assistiti scan within the declared hard cap', () {
      expect(
        RealAssistitiMigration1FirestoreReportReader.normalizeMaxAssistitiScan(-1),
        RealAssistitiMigration1FirestoreReportReader.defaultMaxAssistitiScan,
      );
      expect(
        RealAssistitiMigration1FirestoreReportReader.normalizeMaxAssistitiScan(0),
        RealAssistitiMigration1FirestoreReportReader.defaultMaxAssistitiScan,
      );
      expect(
        RealAssistitiMigration1FirestoreReportReader.normalizeMaxAssistitiScan(5),
        5,
      );
      expect(
        RealAssistitiMigration1FirestoreReportReader.normalizeMaxAssistitiScan(1000),
        RealAssistitiMigration1FirestoreReportReader.defaultMaxAssistitiScan,
      );
    });

    test('builds the tenant assistiti collection path without legacy collections', () {
      expect(
        RealAssistitiMigration1FirestoreReportReader.assistitiCollectionPath(
          tenantId: 'tenant-a',
        ),
        'tenants/tenant-a/assistiti',
      );
    });

    test('rejects non canonical tenant ids before any Firestore path is used', () {
      expect(
        () => RealAssistitiMigration1FirestoreReportReader.assistitiCollectionPath(
          tenantId: 'tenant/a',
        ),
        throwsA(isA<RealAssistitiMigration1FirestoreReportRejectedException>()),
      );
    });

    test('builds a report from fetched raw documents and records Firestore reads', () {
      final RealAssistitiMigration1DataReportResult result =
          RealAssistitiMigration1FirestoreReportReader.buildReportFromFetchedRawDocuments(
        tenantId: 'tenant-a',
        firestoreReads: 1,
        documents: <RealAssistitiMigration1DataReportRawDocument>[
          RealAssistitiMigration1DataReportRawDocument(
            documentId: 'assistito-1',
            rawData: _validCfPayload(
              assistitoId: 'assistito-1',
              cf: 'RSSMRA80A01H501U',
              fullName: 'Rossi Mario',
            ),
          ),
        ],
      );

      expect(result.firestoreReads, 1);
      expect(result.firestoreWrites, 0);
      expect(result.summary.inputDocumentCount, 1);
      expect(result.summary.cfCount, 1);
      expect(result.allVerified, isTrue);
    });

    test('rejects impossible Firestore read counts above the hard cap', () {
      expect(
        () => RealAssistitiMigration1FirestoreReportReader.buildReportFromFetchedRawDocuments(
          tenantId: 'tenant-a',
          firestoreReads: RealAssistitiMigration1FirestoreReportReader.maxFirestoreReadsPerRun + 1,
          documents: const <RealAssistitiMigration1DataReportRawDocument>[],
        ),
        throwsA(isA<RealAssistitiMigration1FirestoreReportRejectedException>()),
      );
    });

    test('preserves the raw report bounded input cap after Firestore fetch', () {
      final List<RealAssistitiMigration1DataReportRawDocument> documents =
          List<RealAssistitiMigration1DataReportRawDocument>.generate(
        RealAssistitiMigration1DataReportReader.maxInputDocuments + 1,
        (int index) => RealAssistitiMigration1DataReportRawDocument(
          documentId: 'assistito-$index',
          rawData: _validCfPayload(
            assistitoId: 'assistito-$index',
            cf: 'RSSMRA80A01H501U',
            fullName: 'Rossi Mario',
          ),
        ),
      );

      expect(
        () => RealAssistitiMigration1FirestoreReportReader.buildReportFromFetchedRawDocuments(
          tenantId: 'tenant-a',
          firestoreReads: RealAssistitiMigration1FirestoreReportReader.maxFirestoreReadsPerRun,
          documents: documents,
        ),
        throwsA(isA<RealAssistitiMigration1DataReportRejectedException>()),
      );
    });
  });
}

Map<String, dynamic> _validCfPayload({
  required String assistitoId,
  required String cf,
  required String fullName,
  String nome = 'Mario',
  String cognome = 'Rossi',
}) {
  return <String, dynamic>{
    'assistitoId': assistitoId,
    'identityType': 'cf',
    'cf': cf,
    'identityAnchor': cf,
    'nome': nome,
    'cognome': cognome,
    'fullName': fullName,
    'searchPrefixes': RealAssistitiTargetPreviewMapper.buildSearchPrefixes(fullName),
  };
}
