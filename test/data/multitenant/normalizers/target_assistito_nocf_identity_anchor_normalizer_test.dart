import 'package:farmacia_desk_web/data/multitenant/normalizers/target_assistito_nocf_identity_anchor_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TargetAssistitoNoCfIdentityAnchorNormalizer legacy codes', () {
    test('keeps real fiscal code as cf identity anchor', () {
      final TargetAssistitoIdentityAnchorResult result =
          TargetAssistitoNoCfIdentityAnchorNormalizer.fromLegacyCode(' crpgnn48b19d514z ');

      expect(result.cf, 'CRPGNN48B19D514Z');
      expect(result.identityAnchor, 'CRPGNN48B19D514Z');
      expect(result.identityType, 'cf');
      expect(result.legacyNoCfCode, '');
      expect(result.generatedNoCf, isFalse);
      expect(result.isCf, isTrue);
      expect(result.isNoCf, isFalse);
    });

    test('canonicalizes TMP legacy NOCF code into stable NOCF anchor', () {
      final TargetAssistitoIdentityAnchorResult first =
          TargetAssistitoNoCfIdentityAnchorNormalizer.fromLegacyCode(
        'TMP_SOFIA_CASTELLI_1778262346407000',
      );
      final TargetAssistitoIdentityAnchorResult second =
          TargetAssistitoNoCfIdentityAnchorNormalizer.fromLegacyCode(
        ' tmp_sofia_castelli_1778262346407000 ',
      );

      expect(first.identityType, 'nocf');
      expect(first.generatedNoCf, isFalse);
      expect(first.legacyNoCfCode, 'TMP_SOFIA_CASTELLI_1778262346407000');
      expect(first.cf, startsWith('NOCF_'));
      expect(TargetAssistitoNoCfIdentityAnchorNormalizer.isCanonicalNoCf(first.cf), isTrue);
      expect(first.identityAnchor, first.cf);
      expect(second.cf, first.cf);
    });

    test('canonicalizes manual NOCF code without using manual code as final anchor', () {
      final TargetAssistitoIdentityAnchorResult result =
          TargetAssistitoNoCfIdentityAnchorNormalizer.fromLegacyCode('manuale sofia castelli');

      expect(result.identityType, 'nocf');
      expect(result.cf, startsWith('NOCF_'));
      expect(result.cf, isNot('MANUALE_SOFIA_CASTELLI'));
      expect(result.identityAnchor, result.cf);
      expect(result.legacyNoCfCode, 'manuale sofia castelli');
    });

    test('rejects empty legacy identity code', () {
      expect(
        () => TargetAssistitoNoCfIdentityAnchorNormalizer.fromLegacyCode('   '),
        throwsA(
          isA<TargetAssistitoNoCfIdentityAnchorRejectedException>()
              .having((TargetAssistitoNoCfIdentityAnchorRejectedException error) => error.code,
                  'code', 'identity_code_empty'),
        ),
      );
    });

    test('rejects slash in legacy identity code', () {
      expect(
        () => TargetAssistitoNoCfIdentityAnchorNormalizer.fromLegacyCode('TMP/SOFIA'),
        throwsA(
          isA<TargetAssistitoNoCfIdentityAnchorRejectedException>()
              .having((TargetAssistitoNoCfIdentityAnchorRejectedException error) => error.code,
                  'code', 'identity_code_not_canonical'),
        ),
      );
    });
  });

  group('TargetAssistitoNoCfIdentityAnchorNormalizer future NOCF', () {
    test('generates canonical NOCF for new assistito without CF', () {
      final TargetAssistitoIdentityAnchorResult first =
          TargetAssistitoNoCfIdentityAnchorNormalizer.fromNewNoCf(
        tenantId: 'tenant_a',
        nome: 'Sofia',
        cognome: 'Castelli',
        createdAtMillis: 1778262346407,
        nonce: 'auto-id-1',
      );
      final TargetAssistitoIdentityAnchorResult second =
          TargetAssistitoNoCfIdentityAnchorNormalizer.fromNewNoCf(
        tenantId: 'tenant_a',
        nome: 'Sofia',
        cognome: 'Castelli',
        createdAtMillis: 1778262346407,
        nonce: 'auto-id-1',
      );

      expect(first.identityType, 'nocf');
      expect(first.generatedNoCf, isTrue);
      expect(first.legacyNoCfCode, '');
      expect(first.cf, startsWith('NOCF_'));
      expect(TargetAssistitoNoCfIdentityAnchorNormalizer.isCanonicalNoCf(first.cf), isTrue);
      expect(first.identityAnchor, first.cf);
      expect(second.cf, first.cf);
    });

    test('different nonce produces different future NOCF anchor for same name', () {
      final TargetAssistitoIdentityAnchorResult first =
          TargetAssistitoNoCfIdentityAnchorNormalizer.fromNewNoCf(
        tenantId: 'tenant_a',
        nome: 'Mario',
        cognome: 'Rossi',
        createdAtMillis: 1778262346407,
        nonce: 'auto-id-1',
      );
      final TargetAssistitoIdentityAnchorResult second =
          TargetAssistitoNoCfIdentityAnchorNormalizer.fromNewNoCf(
        tenantId: 'tenant_a',
        nome: 'Mario',
        cognome: 'Rossi',
        createdAtMillis: 1778262346407,
        nonce: 'auto-id-2',
      );

      expect(second.cf, isNot(first.cf));
    });

    test('rejects future NOCF without tenantId', () {
      expect(
        () => TargetAssistitoNoCfIdentityAnchorNormalizer.fromNewNoCf(
          tenantId: '',
          nome: 'Sofia',
          cognome: 'Castelli',
          createdAtMillis: 1778262346407,
          nonce: 'auto-id-1',
        ),
        throwsA(
          isA<TargetAssistitoNoCfIdentityAnchorRejectedException>()
              .having((TargetAssistitoNoCfIdentityAnchorRejectedException error) => error.code,
                  'code', 'tenant_id_empty'),
        ),
      );
    });

    test('rejects future NOCF without name anchor', () {
      expect(
        () => TargetAssistitoNoCfIdentityAnchorNormalizer.fromNewNoCf(
          tenantId: 'tenant_a',
          nome: '',
          cognome: '',
          createdAtMillis: 1778262346407,
          nonce: 'auto-id-1',
        ),
        throwsA(
          isA<TargetAssistitoNoCfIdentityAnchorRejectedException>()
              .having((TargetAssistitoNoCfIdentityAnchorRejectedException error) => error.code,
                  'code', 'nocf_identity_name_anchor_missing'),
        ),
      );
    });
  });
}
