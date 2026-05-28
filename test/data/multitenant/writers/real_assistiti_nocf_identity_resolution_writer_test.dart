import 'package:farmacia_desk_web/data/multitenant/readers/real_assistiti_nocf_identity_resolution_reader.dart';
import 'package:farmacia_desk_web/data/multitenant/writers/real_assistiti_nocf_identity_resolution_writer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RealAssistitiNoCfIdentityResolutionWriter validation', () {
    test('uses one transactional read and one bounded target write', () {
      expect(RealAssistitiNoCfIdentityResolutionWriter.transactionReadsPerResolution, 1);
      expect(RealAssistitiNoCfIdentityResolutionWriter.writesPerResolution, 1);
      expect(
        RealAssistitiNoCfIdentityResolutionWriter.resolvedManualStatus,
        'resolved_manual',
      );
      expect(
        RealAssistitiNoCfIdentityResolutionWriter.resolutionSource,
        'frontend_modal_identity_resolution',
      );
    });

    test('builds canonical target fullName as cognome nome', () {
      final String fullName = RealAssistitiNoCfIdentityResolutionWriter.buildCanonicalFullName(
        nome: 'Amedeo',
        cognome: 'Fantauzzo',
      );

      expect(fullName, 'Fantauzzo Amedeo');
    });

    test('rejects embedded CF token in nome', () {
      expect(
        () => RealAssistitiNoCfIdentityResolutionWriter.normalizeManualNamePart(
          fieldName: 'nome',
          value: 'Mario RSSMRA80A01H501U',
        ),
        throwsA(
          isA<RealAssistitiNoCfIdentityResolutionRejectedException>().having(
            (RealAssistitiNoCfIdentityResolutionRejectedException error) => error.code,
            'code',
            'manual_identity_contains_cf_token',
          ),
        ),
      );
    });

    test('rejects embedded CF token in cognome', () {
      expect(
        () => RealAssistitiNoCfIdentityResolutionWriter.normalizeManualNamePart(
          fieldName: 'cognome',
          value: 'Rossi RSSMRA80A01H501U',
        ),
        throwsA(
          isA<RealAssistitiNoCfIdentityResolutionRejectedException>().having(
            (RealAssistitiNoCfIdentityResolutionRejectedException error) => error.code,
            'code',
            'manual_identity_contains_cf_token',
          ),
        ),
      );
    });

    test('rejects CF token even when glued to surrounding text', () {
      expect(
        () => RealAssistitiNoCfIdentityResolutionWriter.normalizeManualNamePart(
          fieldName: 'nome',
          value: 'MarioRSSMRA80A01H501U',
        ),
        throwsA(
          isA<RealAssistitiNoCfIdentityResolutionRejectedException>().having(
            (RealAssistitiNoCfIdentityResolutionRejectedException error) => error.code,
            'code',
            'manual_identity_contains_cf_token',
          ),
        ),
      );
    });

    test('builds resolved update payload without legacy or lock writes', () {
      final String fullName = RealAssistitiNoCfIdentityResolutionWriter.buildCanonicalFullName(
        nome: 'Amedeo',
        cognome: 'Fantauzzo',
      );
      final List<String> prefixes =
          RealAssistitiNoCfIdentityResolutionWriter.buildResolvedSearchPrefixes(fullName);

      final Map<String, dynamic> payload =
          RealAssistitiNoCfIdentityResolutionWriter.buildResolvedManualUpdatePayload(
        nome: 'Amedeo',
        cognome: 'Fantauzzo',
        fullName: fullName,
        searchPrefixes: prefixes,
      );
      final List<String> rootKeys = RealAssistitiNoCfIdentityResolutionWriter.sortedRootKeys(payload);

      expect(payload['nome'], 'Amedeo');
      expect(payload['cognome'], 'Fantauzzo');
      expect(payload['fullName'], 'Fantauzzo Amedeo');
      expect(payload['nameSplitConfidence'], 'resolved_manual_nocf_identity');
      expect(payload['identityResolutionStatus'], 'resolved_manual');
      expect(payload['identityResolution.status'], 'resolved_manual');
      expect(payload['identityResolution.resolutionSource'], 'frontend_modal_identity_resolution');
      expect(rootKeys, <String>[
        'cognome',
        'fullName',
        'identityResolution',
        'identityResolutionStatus',
        'nameSplitConfidence',
        'nome',
        'searchPrefixes',
        'updatedAt',
      ]);
      expect(rootKeys.contains('assistiti_identity_locks'), isFalse);
      expect(rootKeys.contains('assistiti_cf_locks'), isFalse);
    });

    test('recognizes pending manual status from all compatible signals', () {
      expect(
        RealAssistitiNoCfIdentityResolutionWriter.isPendingManualResolutionPayload(
          const <String, dynamic>{'identityResolutionStatus': 'pending_manual'},
        ),
        isTrue,
      );
      expect(
        RealAssistitiNoCfIdentityResolutionWriter.isPendingManualResolutionPayload(
          const <String, dynamic>{
            'identityResolution': <String, dynamic>{'status': 'pending_manual'},
          },
        ),
        isTrue,
      );
      expect(
        RealAssistitiNoCfIdentityResolutionWriter.isPendingManualResolutionPayload(
          const <String, dynamic>{
            'nameSplitConfidence': 'pending_manual_nocf_identity_resolution',
          },
        ),
        isTrue,
      );
      expect(
        RealAssistitiNoCfIdentityResolutionWriter.isPendingManualResolutionPayload(
          const <String, dynamic>{'identityResolutionStatus': 'resolved_manual'},
        ),
        isFalse,
      );
    });

    test('keeps reader and writer pending constants aligned', () {
      expect(
        RealAssistitiNoCfIdentityResolutionReader.pendingStatus,
        'pending_manual',
      );
      expect(
        RealAssistitiNoCfIdentityResolutionReader.pendingConfidence,
        'pending_manual_nocf_identity_resolution',
      );
    });
  });
}
