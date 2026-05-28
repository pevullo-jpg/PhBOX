import 'package:flutter_test/flutter_test.dart';
import 'package:farmacia_desk_web/data/multitenant/mappers/real_assistiti_target_preview_mapper.dart';
import 'package:farmacia_desk_web/data/multitenant/reports/real_assistiti_migration1_data_report_reader.dart';

void main() {
  group('RealAssistitiMigration1DataReportReader', () {
    test('does not introduce Firestore reads or writes for raw payload reports', () {
      final RealAssistitiMigration1DataReportResult result =
          RealAssistitiMigration1DataReportReader.buildReportFromRawDocuments(
        tenantId: 'tenant-a',
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

      expect(result.firestoreReads, 0);
      expect(result.firestoreWrites, 0);
      expect(result.summary.cfCount, 1);
      expect(result.summary.noCfCount, 0);
      expect(result.allVerified, isTrue);
    });

    test('reports CF-like contamination inside CF nome', () {
      final RealAssistitiMigration1DataReportItem item =
          RealAssistitiMigration1DataReportReader.verifyRawDocument(
        documentId: 'assistito-1',
        rawData: _validCfPayload(
          assistitoId: 'assistito-1',
          cf: 'RSSMRA80A01H501U',
          nome: 'Mario BNCLSN80A01H501U',
          cognome: 'Rossi',
          fullName: 'Rossi Mario',
        ),
      );

      expect(item.verified, isFalse);
      expect(item.mismatchReasons, contains('target_identity_contains_cf_token'));
    });

    test('reports CF-like contamination inside CF cognome', () {
      final RealAssistitiMigration1DataReportResult result =
          RealAssistitiMigration1DataReportReader.buildReportFromRawDocuments(
        tenantId: 'tenant-a',
        documents: <RealAssistitiMigration1DataReportRawDocument>[
          RealAssistitiMigration1DataReportRawDocument(
            documentId: 'assistito-1',
            rawData: _validCfPayload(
              assistitoId: 'assistito-1',
              cf: 'RSSMRA80A01H501U',
              nome: 'Mario',
              cognome: 'Rossi BNCLSN80A01H501U',
              fullName: 'Rossi Mario',
            ),
          ),
        ],
      );

      expect(result.summary.contaminatedIdentityCount, 1);
      expect(result.summary.mismatchReasonCounts['target_identity_contains_cf_token'], 1);
    });

    test('accepts valid resolved manual NOCF payload', () {
      final RealAssistitiMigration1DataReportItem item =
          RealAssistitiMigration1DataReportReader.verifyRawDocument(
        documentId: 'assistito-1',
        rawData: _validNoCfPayload(
          assistitoId: 'assistito-1',
          fullName: 'Fantauzzo Amedeo',
          nome: 'Amedeo',
          cognome: 'Fantauzzo',
          rootStatus: 'resolved_manual',
          nestedStatus: 'resolved_manual',
          nameSplitConfidence: 'resolved_manual_nocf_identity',
        ),
      );

      expect(item.verified, isTrue);
      expect(item.resolvedManual, isTrue);
    });

    test('rejects non-manual root status even when nested status is manual', () {
      final RealAssistitiMigration1DataReportItem item =
          RealAssistitiMigration1DataReportReader.verifyRawDocument(
        documentId: 'assistito-1',
        rawData: _validNoCfPayload(
          assistitoId: 'assistito-1',
          fullName: 'Fantauzzo Amedeo',
          nome: 'Amedeo',
          cognome: 'Fantauzzo',
          rootStatus: 'resolved_auto',
          nestedStatus: 'resolved_manual',
          nameSplitConfidence: 'resolved_manual_nocf_identity',
        ),
      );

      expect(item.verified, isFalse);
      expect(item.mismatchReasons, contains('target_identity_resolution_state_invalid'));
    });

    test('rejects stale searchPrefixes', () {
      final Map<String, dynamic> payload = _validCfPayload(
        assistitoId: 'assistito-1',
        cf: 'RSSMRA80A01H501U',
        fullName: 'Rossi Mario',
      );
      payload['searchPrefixes'] = <String>['stale'];

      final RealAssistitiMigration1DataReportItem item =
          RealAssistitiMigration1DataReportReader.verifyRawDocument(
        documentId: 'assistito-1',
        rawData: payload,
      );

      expect(item.verified, isFalse);
      expect(item.mismatchReasons, contains('target_search_prefixes_mismatch'));
    });

    test('enforces raw document hard cap before materializing lazy iterable', () {
      int generated = 0;
      Iterable<RealAssistitiMigration1DataReportRawDocument> lazyDocuments() sync* {
        for (int index = 0; index < 1000; index++) {
          generated++;
          yield RealAssistitiMigration1DataReportRawDocument(
            documentId: 'assistito-$index',
            rawData: _validCfPayload(
              assistitoId: 'assistito-$index',
              cf: 'RSSMRA80A01H501U',
              fullName: 'Rossi Mario',
            ),
          );
        }
      }

      expect(
        () => RealAssistitiMigration1DataReportReader.buildReportFromRawDocuments(
          tenantId: 'tenant-a',
          documents: lazyDocuments(),
        ),
        throwsA(isA<RealAssistitiMigration1DataReportRejectedException>()),
      );
      expect(generated, RealAssistitiMigration1DataReportReader.maxInputDocuments + 1);
    });

    test('bounds lazy searchPrefixes before materializing them', () {
      int generated = 0;
      Iterable<String> lazySearchPrefixes() sync* {
        for (int index = 0; index < 1000; index++) {
          generated++;
          yield 'prefix_$index';
        }
      }

      final Map<String, dynamic> payload = _validCfPayload(
        assistitoId: 'assistito-1',
        cf: 'RSSMRA80A01H501U',
        fullName: 'Rossi Mario',
      );
      payload['searchPrefixes'] = lazySearchPrefixes();

      final RealAssistitiMigration1DataReportItem item =
          RealAssistitiMigration1DataReportReader.verifyRawDocument(
        documentId: 'assistito-1',
        rawData: payload,
      );

      expect(item.verified, isFalse);
      expect(item.searchPrefixes.length, RealAssistitiMigration1DataReportReader.maxSearchPrefixesPerDocument);
      expect(generated, RealAssistitiMigration1DataReportReader.maxSearchPrefixesPerDocument + 1);
      expect(item.mismatchReasons, contains('target_search_prefixes_unbounded'));
      expect(item.mismatchReasons, contains('target_search_prefixes_mismatch'));
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

Map<String, dynamic> _validNoCfPayload({
  required String assistitoId,
  required String fullName,
  required String nome,
  required String cognome,
  required String rootStatus,
  required String nestedStatus,
  required String nameSplitConfidence,
}) {
  const String identityAnchor = 'NOCF_1333C7A3C5B35C8B';
  return <String, dynamic>{
    'assistitoId': assistitoId,
    'identityType': 'nocf',
    'cf': identityAnchor,
    'identityAnchor': identityAnchor,
    'legacyNoCfCode': 'TMP_AMEDEO_FANTAUZZO_1775837672370000',
    'generatedNoCf': false,
    'nome': nome,
    'cognome': cognome,
    'fullName': fullName,
    'identityResolutionStatus': rootStatus,
    'identityResolution': <String, dynamic>{'status': nestedStatus},
    'nameSplitConfidence': nameSplitConfidence,
    'searchPrefixes': fullName.isEmpty
        ? const <String>[]
        : RealAssistitiTargetPreviewMapper.buildSearchPrefixes(fullName),
  };
}
