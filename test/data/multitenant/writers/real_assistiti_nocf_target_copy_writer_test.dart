import 'package:farmacia_desk_web/data/multitenant/normalizers/target_assistito_nocf_identity_anchor_normalizer.dart';
import 'package:farmacia_desk_web/data/multitenant/writers/real_assistiti_nocf_target_copy_writer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RealAssistitiNoCfTargetCopyWriter token and caps', () {
    test('uses small-batch hard cap and three writes per NOCF', () {
      expect(RealAssistitiNoCfTargetCopyWriter.maxDocumentsPerRun, 5);
      expect(RealAssistitiNoCfTargetCopyWriter.writesPerDocument, 3);
      expect(RealAssistitiNoCfTargetCopyWriter.maxFirestoreWritesPerRun, 15);
      expect(RealAssistitiNoCfTargetCopyWriter.legacyReadsPerIdentityCode, 5);
    });

    test('builds confirmation token from canonical NOCF identity anchors', () {
      final TargetAssistitoIdentityAnchorResult expected =
          TargetAssistitoNoCfIdentityAnchorNormalizer.fromLegacyCode(
        'TMP_SOFIA_CASTELLI_1778262346407000',
      );

      final String token = RealAssistitiNoCfTargetCopyWriter.buildRequiredManualConfirmationToken(
        tenantId: 'tenant_a',
        identityCodes: const <String>['TMP_SOFIA_CASTELLI_1778262346407000'],
      );

      expect(
        token,
        '${RealAssistitiNoCfTargetCopyWriter.manualConfirmationTokenPrefix}:tenant_a:${expected.identityAnchor}',
      );
      expect(token.contains('TMP_SOFIA_CASTELLI'), isFalse);
    });

    test('rejects real CF in NOCF copy token generation', () {
      expect(
        () => RealAssistitiNoCfTargetCopyWriter.buildRequiredManualConfirmationToken(
          tenantId: 'tenant_a',
          identityCodes: const <String>['CRPGNN48B19D514Z'],
        ),
        throwsA(
          isA<RealAssistitiNoCfTargetCopyRejectedException>().having(
            (RealAssistitiNoCfTargetCopyRejectedException error) => error.code,
            'code',
            'nocf_copy_contains_real_cf',
          ),
        ),
      );
    });

    test('rejects more than five NOCF codes before any Firestore work', () {
      expect(
        () => RealAssistitiNoCfTargetCopyWriter.buildRequiredManualConfirmationToken(
          tenantId: 'tenant_a',
          identityCodes: const <String>[
            'TMP_A_1',
            'TMP_A_2',
            'TMP_A_3',
            'TMP_A_4',
            'TMP_A_5',
            'TMP_A_6',
          ],
        ),
        throwsA(
          isA<RealAssistitiNoCfTargetCopyRejectedException>().having(
            (RealAssistitiNoCfTargetCopyRejectedException error) => error.code,
            'code',
            'identity_codes_exceed_hard_cap',
          ),
        ),
      );
    });

    test('rejects duplicate NOCF identity anchors before token generation', () {
      expect(
        () => RealAssistitiNoCfTargetCopyWriter.buildRequiredManualConfirmationToken(
          tenantId: 'tenant_a',
          identityCodes: const <String>[
            'manuale sofia castelli',
            ' manuale  sofia  castelli ',
          ],
        ),
        throwsA(
          isA<RealAssistitiNoCfTargetCopyRejectedException>().having(
            (RealAssistitiNoCfTargetCopyRejectedException error) => error.code,
            'code',
            'identity_audit_has_blocking_issues',
          ),
        ),
      );
    });
  });

  group('RealAssistitiNoCfTargetCopyWriter NOCF identity resolution', () {
    test('derives nome and cognome from TMP code without CF scoring', () {
      final TargetAssistitoIdentityAnchorResult anchor =
          TargetAssistitoNoCfIdentityAnchorNormalizer.fromLegacyCode(
        'TMP_SOFIA_CASTELLI_1778262346407000',
      );

      final identity = RealAssistitiNoCfTargetCopyWriter.resolveNoCfIdentityForMigration(
        requestedCode: 'TMP_SOFIA_CASTELLI_1778262346407000',
        identityAnchor: anchor.identityAnchor,
        patientData: const <String, dynamic>{},
        dashboardIndexData: const <String, dynamic>{},
        therapeuticAdviceData: const <String, dynamic>{},
      );

      expect(identity.nome, 'Sofia');
      expect(identity.cognome, 'Castelli');
      expect(identity.fullName, 'Sofia Castelli');
      expect(identity.nameSplitConfidence, RealAssistitiNoCfTargetCopyWriter.nameSplitConfidenceNoCfCode);
      expect(
        RealAssistitiNoCfTargetCopyWriter.identityResolutionStatusForIdentity(identity),
        RealAssistitiNoCfTargetCopyWriter.identityResolutionStatusResolvedAuto,
      );
    });

    test('handles surname particles in TMP code', () {
      final TargetAssistitoIdentityAnchorResult anchor =
          TargetAssistitoNoCfIdentityAnchorNormalizer.fromLegacyCode(
        'TMP_MARIA_DE_LUCA_1778262346407000',
      );

      final identity = RealAssistitiNoCfTargetCopyWriter.resolveNoCfIdentityForMigration(
        requestedCode: 'TMP_MARIA_DE_LUCA_1778262346407000',
        identityAnchor: anchor.identityAnchor,
        patientData: const <String, dynamic>{},
        dashboardIndexData: const <String, dynamic>{},
        therapeuticAdviceData: const <String, dynamic>{},
      );

      expect(identity.nome, 'Maria');
      expect(identity.cognome, 'De Luca');
      expect(identity.fullName, 'Maria De Luca');
    });

    test('explicit legacy fields win over NOCF code parsing', () {
      final TargetAssistitoIdentityAnchorResult anchor =
          TargetAssistitoNoCfIdentityAnchorNormalizer.fromLegacyCode(
        'TMP_ERRATO_ERRATA_1778262346407000',
      );

      final identity = RealAssistitiNoCfTargetCopyWriter.resolveNoCfIdentityForMigration(
        requestedCode: 'TMP_ERRATO_ERRATA_1778262346407000',
        identityAnchor: anchor.identityAnchor,
        patientData: const <String, dynamic>{
          'nome': 'Sofia',
          'cognome': 'Castelli',
        },
        dashboardIndexData: const <String, dynamic>{},
        therapeuticAdviceData: const <String, dynamic>{},
      );

      expect(identity.nome, 'Sofia');
      expect(identity.cognome, 'Castelli');
      expect(identity.nameSplitConfidence, RealAssistitiNoCfTargetCopyWriter.nameSplitConfidenceExplicitNoCfFields);
    });

    test('ambiguous fullName is copied but marked pending manual', () {
      const String identityAnchor = 'NOCF_0123456789ABCDEF';

      final identity = RealAssistitiNoCfTargetCopyWriter.resolveNoCfIdentityForMigration(
        requestedCode: identityAnchor,
        identityAnchor: identityAnchor,
        patientData: const <String, dynamic>{
          'fullName': 'Andrea Franco',
        },
        dashboardIndexData: const <String, dynamic>{},
        therapeuticAdviceData: const <String, dynamic>{},
      );
      final Map<String, dynamic> resolution =
          RealAssistitiNoCfTargetCopyWriter.identityResolutionForIdentity(
        requestedCode: identityAnchor,
        identity: identity,
      );

      expect(identity.nome, '');
      expect(identity.cognome, '');
      expect(identity.fullName, 'Andrea Franco');
      expect(identity.nameSplitConfidence, RealAssistitiNoCfTargetCopyWriter.nameSplitConfidencePendingManualNoCf);
      expect(resolution['status'], RealAssistitiNoCfTargetCopyWriter.identityResolutionStatusPendingManual);
      expect(resolution['reason'], 'ambiguous_nocf_name_split');
      expect((resolution['candidateSplits'] as List<dynamic>).length, 2);
    });
  });

  group('RealAssistitiNoCfTargetCopyWrittenDocument', () {
    test('redacts payloads to root keys only', () {
      const RealAssistitiNoCfTargetCopyWrittenDocument written =
          RealAssistitiNoCfTargetCopyWrittenDocument(
        requestedCode: 'TMP_SOFIA_CASTELLI_1778262346407000',
        identityAnchor: 'NOCF_0123456789ABCDEF',
        documentId: 'assistito-1',
        documentPath: 'tenants/tenant_a/assistiti/assistito-1',
        identityLockDocumentPath:
            'tenants/tenant_a/assistiti_identity_locks/NOCF_0123456789ABCDEF',
        cfLockDocumentPath: 'tenants/tenant_a/assistiti_cf_locks/NOCF_0123456789ABCDEF',
        targetPayloadRootKeys: <String>[
          'assistitoId',
          'cf',
          'identityAnchor',
        ],
        identityLockPayloadRootKeys: <String>[
          'assistitoId',
          'identityAnchor',
        ],
        cfLockPayloadRootKeys: <String>[
          'assistitoId',
          'cf',
        ],
      );

      final Map<String, dynamic> mapped = written.toMap();
      expect(mapped['identityAnchor'], 'NOCF_0123456789ABCDEF');
      expect(mapped.toString().contains('targetPayload'), isFalse);
      expect(mapped.toString().contains('identityLockPayload'), isFalse);
      expect(mapped.toString().contains('cfLockPayload'), isFalse);
      expect(mapped.toString().contains('rawData'), isFalse);
    });
  });
}
