import 'package:farmacia_desk_web/data/multitenant/mappers/real_assistiti_target_preview_mapper.dart';
import 'package:farmacia_desk_web/data/multitenant/reports/real_assistiti_migration1_data_report_reader.dart';
import 'package:farmacia_desk_web/data/multitenant/verifiers/real_assistiti_nocf_post_resolution_verifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RealAssistitiMigration1DataReportReader', () {
    test('marks a canonical resolved_manual NOCF target item as verified', () {
      final RealAssistitiMigration1DataReportItem item =
          RealAssistitiMigration1DataReportReader.buildItemFromRawData(
        tenantId: 'tenant_a',
        documentId: 'assistito_doc_1',
        rawData: _validResolvedNoCfPayload(),
      );

      expect(item.verified, isTrue);
      expect(item.mismatchReasons, isEmpty);
      expect(item.resolvedManual, isTrue);
      expect(item.pendingManual, isFalse);
    });

    test('rejects non-manual root status even when nested status is resolved_manual', () {
      final Map<String, dynamic> payload = _validResolvedNoCfPayload();
      payload['identityResolutionStatus'] = 'resolved_auto';

      final RealAssistitiMigration1DataReportItem item =
          RealAssistitiMigration1DataReportReader.buildItemFromRawData(
        tenantId: 'tenant_a',
        documentId: 'assistito_doc_1',
        rawData: payload,
      );

      expect(item.verified, isFalse);
      expect(item.mismatchReasons, contains('target_nocf_resolution_state_invalid'));
    });

    test('rejects root and nested manual status drift', () {
      final Map<String, dynamic> payload = _validResolvedNoCfPayload();
      payload['identityResolution'] = <String, dynamic>{
        'status': RealAssistitiNoCfPostResolutionVerifier.pendingManualStatus,
      };

      final RealAssistitiMigration1DataReportItem item =
          RealAssistitiMigration1DataReportReader.buildItemFromRawData(
        tenantId: 'tenant_a',
        documentId: 'assistito_doc_1',
        rawData: payload,
      );

      expect(item.verified, isFalse);
      expect(item.mismatchReasons, contains('target_nocf_resolution_state_invalid'));
    });

    test('rejects CF-like contamination inside identity fields', () {
      final Map<String, dynamic> payload = _validResolvedNoCfPayload();
      payload['nome'] = 'Amedeo RSSMRA80A01H501U';
      payload['fullName'] = 'Fantauzzo Amedeo RSSMRA80A01H501U';
      payload['searchPrefixes'] = RealAssistitiTargetPreviewMapper.buildSearchPrefixes(
        payload['fullName'] as String,
      );

      final RealAssistitiMigration1DataReportItem item =
          RealAssistitiMigration1DataReportReader.buildItemFromRawData(
        tenantId: 'tenant_a',
        documentId: 'assistito_doc_1',
        rawData: payload,
      );

      expect(item.verified, isFalse);
      expect(item.mismatchReasons, contains('target_identity_contains_cf_token'));
    });

    test('rejects stale searchPrefixes built from a different fullName', () {
      final Map<String, dynamic> payload = _validResolvedNoCfPayload();
      payload['searchPrefixes'] = RealAssistitiTargetPreviewMapper.buildSearchPrefixes('Rossi Mario');

      final RealAssistitiMigration1DataReportItem item =
          RealAssistitiMigration1DataReportReader.buildItemFromRawData(
        tenantId: 'tenant_a',
        documentId: 'assistito_doc_1',
        rawData: payload,
      );

      expect(item.verified, isFalse);
      expect(item.mismatchReasons, contains('target_search_prefixes_mismatch'));
    });

    test('accepts canonical pending_manual NOCF target item', () {
      final Map<String, dynamic> payload = _validPendingNoCfPayload();

      final RealAssistitiMigration1DataReportItem item =
          RealAssistitiMigration1DataReportReader.buildItemFromRawData(
        tenantId: 'tenant_a',
        documentId: 'assistito_doc_2',
        rawData: payload,
      );

      expect(item.verified, isTrue);
      expect(item.pendingManual, isTrue);
      expect(item.resolvedManual, isFalse);
    });

    test('buildSummary counts identity states and mismatch reasons', () {
      final RealAssistitiMigration1DataReportItem verified =
          RealAssistitiMigration1DataReportReader.buildItemFromRawData(
        tenantId: 'tenant_a',
        documentId: 'assistito_doc_1',
        rawData: _validResolvedNoCfPayload(),
      );
      final Map<String, dynamic> invalidPayload = _validResolvedNoCfPayload();
      invalidPayload['legacyNoCfCode'] = '';
      final RealAssistitiMigration1DataReportItem invalid =
          RealAssistitiMigration1DataReportReader.buildItemFromRawData(
        tenantId: 'tenant_a',
        documentId: 'assistito_doc_3',
        rawData: invalidPayload,
      );

      final RealAssistitiMigration1DataReportSummary summary =
          RealAssistitiMigration1DataReportReader.buildSummary(<RealAssistitiMigration1DataReportItem>[
        verified,
        invalid,
      ]);

      expect(summary.scannedCount, 2);
      expect(summary.noCfCount, 2);
      expect(summary.verifiedCount, 1);
      expect(summary.failedCount, 1);
      expect(summary.noCfMissingLegacyCodeCount, 1);
      expect(summary.mismatchReasonCounts['target_nocf_legacy_code_missing'], 1);
    });

    test('selectNoCfAnchorsForLockVerification deduplicates and respects hard cap', () {
      final List<RealAssistitiMigration1DataReportItem> items = <RealAssistitiMigration1DataReportItem>[
        RealAssistitiMigration1DataReportReader.buildItemFromRawData(
          tenantId: 'tenant_a',
          documentId: 'assistito_doc_1',
          rawData: _validResolvedNoCfPayload(identityAnchor: 'NOCF_0000000000000001'),
        ),
        RealAssistitiMigration1DataReportReader.buildItemFromRawData(
          tenantId: 'tenant_a',
          documentId: 'assistito_doc_2',
          rawData: _validPendingNoCfPayload(identityAnchor: 'NOCF_0000000000000002'),
        ),
        RealAssistitiMigration1DataReportReader.buildItemFromRawData(
          tenantId: 'tenant_a',
          documentId: 'assistito_doc_3',
          rawData: _validPendingNoCfPayload(identityAnchor: 'NOCF_0000000000000002'),
        ),
      ];

      final List<String> anchors =
          RealAssistitiMigration1DataReportReader.selectNoCfAnchorsForLockVerification(
        items: items,
        maxNoCfLockVerification: 1,
      );

      expect(anchors, <String>['NOCF_0000000000000001']);
    });

    test('normalizes bounded report limits', () {
      expect(RealAssistitiMigration1DataReportReader.normalizeMaxAssistitiScan(-1), 50);
      expect(RealAssistitiMigration1DataReportReader.normalizeMaxAssistitiScan(101), 100);
      expect(RealAssistitiMigration1DataReportReader.normalizeMaxNoCfLockVerification(-1), 0);
      expect(RealAssistitiMigration1DataReportReader.normalizeMaxNoCfLockVerification(10), 5);
    });
  });
}

Map<String, dynamic> _validResolvedNoCfPayload({
  String identityAnchor = 'NOCF_1333C7A3C5B35C8B',
}) {
  const String nome = 'Amedeo';
  const String cognome = 'Fantauzzo';
  const String fullName = 'Fantauzzo Amedeo';
  return <String, dynamic>{
    'assistitoId': 'assistito_doc_1',
    'cf': identityAnchor,
    'identityType': 'nocf',
    'identityAnchor': identityAnchor,
    'legacyNoCfCode': 'TMP_AMEDEO_FANTAUZZO_1775837672370000',
    'generatedNoCf': false,
    'nome': nome,
    'cognome': cognome,
    'fullName': fullName,
    'searchPrefixes': RealAssistitiTargetPreviewMapper.buildSearchPrefixes(fullName),
    'identityResolutionStatus': RealAssistitiNoCfPostResolutionVerifier.resolvedManualStatus,
    'identityResolution': <String, dynamic>{
      'status': RealAssistitiNoCfPostResolutionVerifier.resolvedManualStatus,
    },
    'nameSplitConfidence': RealAssistitiNoCfPostResolutionVerifier.resolvedManualConfidence,
  };
}

Map<String, dynamic> _validPendingNoCfPayload({
  String identityAnchor = 'NOCF_1333C7A3C5B35C8B',
}) {
  const String fullName = 'Amedeo Fantauzzo';
  return <String, dynamic>{
    'assistitoId': 'assistito_doc_2',
    'cf': identityAnchor,
    'identityType': 'nocf',
    'identityAnchor': identityAnchor,
    'legacyNoCfCode': 'TMP_AMEDEO_FANTAUZZO_1775837672370000',
    'generatedNoCf': false,
    'nome': '',
    'cognome': '',
    'fullName': fullName,
    'searchPrefixes': RealAssistitiTargetPreviewMapper.buildSearchPrefixes(fullName),
    'identityResolutionStatus': RealAssistitiNoCfPostResolutionVerifier.pendingManualStatus,
    'identityResolution': <String, dynamic>{
      'status': RealAssistitiNoCfPostResolutionVerifier.pendingManualStatus,
    },
    'nameSplitConfidence': RealAssistitiNoCfPostResolutionVerifier.pendingManualConfidence,
  };
}
