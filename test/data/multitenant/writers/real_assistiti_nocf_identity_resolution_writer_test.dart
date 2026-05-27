import 'package:farmacia_desk_web/data/multitenant/writers/real_assistiti_nocf_identity_resolution_writer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RealAssistitiNoCfIdentityResolutionWriter', () {
    test('builds bounded manual resolution patch for target assistito only', () {
      final Map<String, dynamic> patch =
          RealAssistitiNoCfIdentityResolutionWriter.buildManualResolutionPatch(
        nome: 'sofia',
        cognome: 'castelli',
      );

      expect(patch['nome'], 'Sofia');
      expect(patch['cognome'], 'Castelli');
      expect(patch['fullName'], 'Castelli Sofia');
      expect(
        patch['searchPrefixes'],
        containsAll(<String>['c', 'castelli', 's', 'sofia']),
      );
      expect(patch['nameSplitConfidence'], 'resolved_manual_nocf_identity');
      expect(patch['identityResolutionStatus'], 'resolved_manual');
      expect(patch['identityResolution.status'], 'resolved_manual');
      expect(
        patch['identityResolution.resolutionSource'],
        'frontend_modal_identity_resolution',
      );
      expect(patch.keys.any((String key) => key.startsWith('legacy.')), isFalse);
      expect(patch.keys.any((String key) => key.contains('lock')), isFalse);
    });

    test('uses canonical surname-first fullName when only one side is present', () {
      final Map<String, dynamic> nomeOnlyPatch =
          RealAssistitiNoCfIdentityResolutionWriter.buildManualResolutionPatch(
        nome: 'sofia',
        cognome: ' ',
      );
      final Map<String, dynamic> cognomeOnlyPatch =
          RealAssistitiNoCfIdentityResolutionWriter.buildManualResolutionPatch(
        nome: ' ',
        cognome: 'castelli',
      );

      expect(nomeOnlyPatch['fullName'], 'Sofia');
      expect(
        nomeOnlyPatch['searchPrefixes'],
        containsAll(<String>['s', 'sofia']),
      );
      expect(cognomeOnlyPatch['fullName'], 'Castelli');
      expect(
        cognomeOnlyPatch['searchPrefixes'],
        containsAll(<String>['c', 'castelli']),
      );
    });

    test('rejects empty manual identity resolution', () {
      expect(
        () => RealAssistitiNoCfIdentityResolutionWriter.buildManualResolutionPatch(
          nome: ' ',
          cognome: ' ',
        ),
        throwsA(
          isA<RealAssistitiNoCfIdentityResolutionRejectedException>().having(
            (RealAssistitiNoCfIdentityResolutionRejectedException error) => error.code,
            'code',
            'identity_resolution_empty',
          ),
        ),
      );
    });

    test('rejects technical codes as manual names', () {
      expect(
        () => RealAssistitiNoCfIdentityResolutionWriter.buildManualResolutionPatch(
          nome: 'NOCF_0123456789ABCDEF',
          cognome: 'Castelli',
        ),
        throwsA(
          isA<RealAssistitiNoCfIdentityResolutionRejectedException>().having(
            (RealAssistitiNoCfIdentityResolutionRejectedException error) => error.code,
            'code',
            'nome_technical_code',
          ),
        ),
      );

      expect(
        () => RealAssistitiNoCfIdentityResolutionWriter.buildManualResolutionPatch(
          nome: 'Sofia',
          cognome: 'TMP_CASTELLI_1778262346407000',
        ),
        throwsA(
          isA<RealAssistitiNoCfIdentityResolutionRejectedException>().having(
            (RealAssistitiNoCfIdentityResolutionRejectedException error) => error.code,
            'code',
            'cognome_technical_code',
          ),
        ),
      );
    });


    test('detects pending manual payload before transactional write', () {
      expect(
        RealAssistitiNoCfIdentityResolutionWriter.isPendingManualPayload(
          const <String, dynamic>{'identityResolutionStatus': 'pending_manual'},
        ),
        isTrue,
      );
      expect(
        RealAssistitiNoCfIdentityResolutionWriter.isPendingManualPayload(
          const <String, dynamic>{
            'identityResolution': <String, dynamic>{'status': 'pending_manual'},
          },
        ),
        isTrue,
      );
      expect(
        RealAssistitiNoCfIdentityResolutionWriter.isPendingManualPayload(
          const <String, dynamic>{
            'nameSplitConfidence': 'pending_manual_nocf_identity_resolution',
          },
        ),
        isTrue,
      );
      expect(
        RealAssistitiNoCfIdentityResolutionWriter.isPendingManualPayload(
          const <String, dynamic>{'identityResolutionStatus': 'resolved_manual'},
        ),
        isFalse,
      );
    });

    test('rejects CF-like values as manual names', () {
      expect(
        () => RealAssistitiNoCfIdentityResolutionWriter.buildManualResolutionPatch(
          nome: 'RSSMRA80A01H501U',
          cognome: 'Rossi',
        ),
        throwsA(
          isA<RealAssistitiNoCfIdentityResolutionRejectedException>().having(
            (RealAssistitiNoCfIdentityResolutionRejectedException error) => error.code,
            'code',
            'nome_fiscal_code_like',
          ),
        ),
      );

      expect(
        () => RealAssistitiNoCfIdentityResolutionWriter.buildManualResolutionPatch(
          nome: 'Mario',
          cognome: 'RSSMRA80A01H501U',
        ),
        throwsA(
          isA<RealAssistitiNoCfIdentityResolutionRejectedException>().having(
            (RealAssistitiNoCfIdentityResolutionRejectedException error) => error.code,
            'code',
            'cognome_fiscal_code_like',
          ),
        ),
      );
    });

    test('rejects slash in manual name parts', () {
      expect(
        () => RealAssistitiNoCfIdentityResolutionWriter.buildManualResolutionPatch(
          nome: 'Sofia/Test',
          cognome: 'Castelli',
        ),
        throwsA(
          isA<RealAssistitiNoCfIdentityResolutionRejectedException>().having(
            (RealAssistitiNoCfIdentityResolutionRejectedException error) => error.code,
            'code',
            'nome_contains_slash',
          ),
        ),
      );
    });
  });
}
