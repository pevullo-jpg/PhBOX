import 'package:farmacia_desk_web/data/multitenant/readers/real_assistiti_nocf_migration_audit_reader.dart';
import 'package:farmacia_desk_web/data/multitenant/readers/target_assistiti_identity_duplicate_guard_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TargetAssistitiIdentityDuplicateGuardResult', () {
    test('summarizes duplicate identity anchors without raw payload expansion', () {
      final RealAssistitiNoCfMigrationAuditResult audit =
          RealAssistitiNoCfMigrationAuditResult.fromRequestedCodes(
        const <String>[
          'TMP_SOFIA_CASTELLI_1778262346407000',
        ],
      );
      final RealAssistitiNoCfMigrationAuditItem auditItem = audit.items.single;
      final TargetAssistitiIdentityDuplicateGuardCheck check =
          TargetAssistitiIdentityDuplicateGuardCheck.found(
        auditItem: auditItem,
        matches: <TargetAssistitiIdentityDuplicateGuardMatch>[
          TargetAssistitiIdentityDuplicateGuardMatch(
            identityAnchor: auditItem.identityAnchor,
            source: TargetAssistitiIdentityDuplicateGuardMatch.sourceIdentityLock,
            documentId: auditItem.identityAnchor,
            documentPath: 'tenants/tenant_a/assistiti_identity_locks/${auditItem.identityAnchor}',
            rawDataRootKeys: const <String>[
              'assistitoId',
              'identityAnchor',
            ],
          ),
        ],
      );

      final TargetAssistitiIdentityDuplicateGuardResult result =
          TargetAssistitiIdentityDuplicateGuardResult(
        tenantId: 'tenant_a',
        assistitiCollectionPath: 'tenants/tenant_a/assistiti',
        identityLocksCollectionPath: 'tenants/tenant_a/assistiti_identity_locks',
        cfLocksCollectionPath: 'tenants/tenant_a/assistiti_cf_locks',
        audit: audit,
        checks: <TargetAssistitiIdentityDuplicateGuardCheck>[check],
        maxIdentityCodes: TargetAssistitiIdentityDuplicateGuardReader.maxIdentityCodes,
        attemptedLookupOperations:
            TargetAssistitiIdentityDuplicateGuardReader.lookupOperationsPerIdentityAnchor,
      );

      expect(result.hasDuplicates, isTrue);
      expect(result.hasAuditBlockingIssues, isFalse);
      expect(result.duplicateIdentityAnchors, <String>[auditItem.identityAnchor]);
      expect(result.duplicateRequestedCodes, <String>['TMP_SOFIA_CASTELLI_1778262346407000']);
      expect(
        result.duplicateSourceCounts[TargetAssistitiIdentityDuplicateGuardMatch.sourceIdentityLock],
        1,
      );

      final Map<String, dynamic> mapped = result.toMap();
      expect(mapped.toString().contains('rawData'), isFalse);
      expect(mapped.toString().contains('legacyBundle'), isFalse);
      expect(mapped.toString().contains('targetPreviewPayload'), isFalse);
      expect(mapped['attemptedLookupOperations'], 4);
    });

    test('keeps audit blocking issues separate from target duplicates', () {
      final RealAssistitiNoCfMigrationAuditResult audit =
          RealAssistitiNoCfMigrationAuditResult.fromRequestedCodes(
        const <String>[
          'manuale sofia castelli',
          ' manuale  sofia  castelli ',
        ],
      );

      final TargetAssistitiIdentityDuplicateGuardResult result =
          TargetAssistitiIdentityDuplicateGuardResult(
        tenantId: 'tenant_a',
        assistitiCollectionPath: 'tenants/tenant_a/assistiti',
        identityLocksCollectionPath: 'tenants/tenant_a/assistiti_identity_locks',
        cfLocksCollectionPath: 'tenants/tenant_a/assistiti_cf_locks',
        audit: audit,
        checks: const <TargetAssistitiIdentityDuplicateGuardCheck>[],
        maxIdentityCodes: TargetAssistitiIdentityDuplicateGuardReader.maxIdentityCodes,
        attemptedLookupOperations: 0,
      );

      expect(result.hasAuditBlockingIssues, isTrue);
      expect(result.hasDuplicates, isFalse);
      expect(result.duplicateIdentityAnchors, isEmpty);
      expect(audit.summary.duplicateIdentityAnchorCount, 2);
      expect(audit.summary.blockingReasonCounts['duplicate_identity_anchor_in_request'], 2);
    });

    test('redacts match payload to sorted root keys', () {
      const TargetAssistitiIdentityDuplicateGuardMatch match =
          TargetAssistitiIdentityDuplicateGuardMatch(
        identityAnchor: 'NOCF_0123456789ABCDEF',
        source: TargetAssistitiIdentityDuplicateGuardMatch.sourceTargetCf,
        documentId: 'assistito-1',
        documentPath: 'tenants/tenant_a/assistiti/assistito-1',
        rawDataRootKeys: <String>[
          'cf',
          'identityAnchor',
        ],
      );

      expect(match.exists, isTrue);
      expect(match.toMap()['rawDataRootKeys'], const <String>['cf', 'identityAnchor']);
      expect(match.toMap().containsKey('rawData'), isFalse);
    });
  });
}
