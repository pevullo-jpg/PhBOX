import 'package:farmacia_desk_web/data/multitenant/normalizers/target_assistito_nocf_identity_anchor_normalizer.dart';
import 'package:farmacia_desk_web/data/multitenant/readers/real_assistiti_nocf_migration_audit_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RealAssistitiNoCfMigrationAuditResult', () {
    test('classifies mixed real CF and legacy NOCF codes without writes', () {
      final RealAssistitiNoCfMigrationAuditResult audit =
          RealAssistitiNoCfMigrationAuditResult.fromRequestedCodes(
        const <String>[
          'CRPGNN48B19D514Z',
          'TMP_SOFIA_CASTELLI_1778262346407000',
          'manuale sofia castelli',
        ],
      );

      expect(audit.summary.requestedCount, 3);
      expect(audit.summary.itemCount, 3);
      expect(audit.summary.copyCandidateCount, 3);
      expect(audit.summary.blockedCount, 0);
      expect(audit.summary.rejectedCount, 0);
      expect(audit.summary.cfCount, 1);
      expect(audit.summary.nocfCount, 2);
      expect(audit.copyCandidateIdentityAnchors.length, 3);
      expect(audit.copyCandidateIdentityAnchors.first, 'CRPGNN48B19D514Z');

      final RealAssistitiNoCfMigrationAuditItem tmpItem = audit.items[1];
      expect(tmpItem.identityType, TargetAssistitoNoCfIdentityAnchorNormalizer.identityTypeNoCf);
      expect(TargetAssistitoNoCfIdentityAnchorNormalizer.isCanonicalNoCf(tmpItem.identityAnchor), isTrue);
      expect(tmpItem.legacyNoCfCode, 'TMP_SOFIA_CASTELLI_1778262346407000');
      expect(tmpItem.copyCandidate, isTrue);
    });

    test('blocks duplicate identity anchors inside the same request', () {
      final RealAssistitiNoCfMigrationAuditResult audit =
          RealAssistitiNoCfMigrationAuditResult.fromRequestedCodes(
        const <String>[
          'TMP_SOFIA_CASTELLI_1778262346407000',
          ' tmp_sofia_castelli_1778262346407000 ',
        ],
      );

      expect(audit.summary.copyCandidateCount, 0);
      expect(audit.summary.blockedCount, 2);
      expect(audit.summary.duplicateIdentityAnchorCount, 2);
      expect(
        audit.summary.blockingReasonCounts['duplicate_identity_anchor_in_request'],
        2,
      );
      expect(audit.blockedRequestedCodes.length, 2);
      expect(audit.items.every((RealAssistitiNoCfMigrationAuditItem item) => item.blocked), isTrue);
    });

    test('rejects invalid NOCF identity codes without throwing from audit', () {
      final RealAssistitiNoCfMigrationAuditResult audit =
          RealAssistitiNoCfMigrationAuditResult.fromRequestedCodes(
        const <String>[
          '',
          'TMP/SOFIA',
        ],
      );

      expect(audit.summary.copyCandidateCount, 0);
      expect(audit.summary.rejectedCount, 2);
      expect(audit.rejectedRequestedCodes, const <String>['', 'TMP/SOFIA']);
      expect(audit.summary.blockingReasonCounts['identity_code_empty'], 1);
      expect(audit.summary.blockingReasonCounts['identity_code_not_canonical'], 1);
    });

    test('does not expose Firestore payloads or raw legacy bundles in map output', () {
      final RealAssistitiNoCfMigrationAuditResult audit =
          RealAssistitiNoCfMigrationAuditResult.fromRequestedCodes(
        const <String>[
          'CRPGNN48B19D514Z',
          'TMP_SOFIA_CASTELLI_1778262346407000',
        ],
      );

      final Map<String, dynamic> mapped = audit.toMap();

      expect(mapped.toString().contains('legacyBundle'), isFalse);
      expect(mapped.toString().contains('dryRunPreview'), isFalse);
      expect(mapped.toString().contains('targetPreviewPayload'), isFalse);
      expect(mapped.toString().contains('rawData'), isFalse);
      expect(mapped.containsKey('summary'), isTrue);
      expect(mapped.containsKey('items'), isTrue);
    });
  });
}
