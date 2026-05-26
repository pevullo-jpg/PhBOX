import 'package:farmacia_desk_web/data/multitenant/mappers/real_assistiti_target_preview_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RealAssistitiTargetPreviewMapper identity', () {
    test('keeps accepted baseline for title-case Giovanni Crapanzano', () {
      final RealAssistitiResolvedIdentity identity =
          RealAssistitiTargetPreviewMapper.resolveIdentity(
        cf: 'CRPGNN48B19D514Z',
        patientData: const <String, dynamic>{
          'fullName': 'Giovanni Crapanzano',
        },
        dashboardIndexData: const <String, dynamic>{},
        therapeuticAdviceData: const <String, dynamic>{},
      );

      expect(identity.nome, 'Giovanni');
      expect(identity.cognome, 'Crapanzano');
      expect(identity.fullName, 'Giovanni Crapanzano');
      expect(identity.nameSplitConfidence, 'derived_from_full_name_name_first');
    });

    test('uses CF-guided split for uppercase surname-first Vullo Giuseppe', () {
      final RealAssistitiResolvedIdentity identity =
          RealAssistitiTargetPreviewMapper.resolveIdentity(
        cf: 'VLLGPP84H27A089I',
        patientData: const <String, dynamic>{
          'fullName': 'VULLO GIUSEPPE',
        },
        dashboardIndexData: const <String, dynamic>{},
        therapeuticAdviceData: const <String, dynamic>{},
      );

      expect(identity.nome, 'Giuseppe');
      expect(identity.cognome, 'Vullo');
      expect(identity.fullName, 'Vullo Giuseppe');
      expect(identity.nameSplitConfidence, 'derived_from_full_name_surname_first');
    });

    test('explicit split fields compose canonical surname-first fullName', () {
      final RealAssistitiResolvedIdentity identity =
          RealAssistitiTargetPreviewMapper.resolveIdentity(
        cf: 'VLLGPP84H27A089I',
        patientData: const <String, dynamic>{
          'nome': 'Giuseppe',
          'cognome': 'Vullo',
        },
        dashboardIndexData: const <String, dynamic>{},
        therapeuticAdviceData: const <String, dynamic>{},
      );

      expect(identity.nome, 'Giuseppe');
      expect(identity.cognome, 'Vullo');
      expect(identity.fullName, 'Vullo Giuseppe');
      expect(identity.nameSplitConfidence, 'explicit_fields_without_full_name');
    });

    test('does not use family alias as cognome', () {
      final RealAssistitiResolvedIdentity identity =
          RealAssistitiTargetPreviewMapper.resolveIdentity(
        cf: 'CRPLSS82P63A089D',
        patientData: const <String, dynamic>{
          'fullName': 'Alessia Crapanzano',
        },
        dashboardIndexData: const <String, dynamic>{
          'alias': 'Lo Vullo',
        },
        therapeuticAdviceData: const <String, dynamic>{},
      );

      expect(identity.nome, 'Alessia');
      expect(identity.cognome, 'Crapanzano');
      expect(identity.cognome, isNot('Lo Vullo'));
    });

    test('allows CF-only identity anchor', () {
      final RealAssistitiResolvedIdentity identity =
          RealAssistitiTargetPreviewMapper.resolveIdentity(
        cf: 'VLLGPP84H27A089I',
        patientData: const <String, dynamic>{},
        dashboardIndexData: const <String, dynamic>{},
        therapeuticAdviceData: const <String, dynamic>{},
      );

      expect(identity.cf, 'VLLGPP84H27A089I');
      expect(identity.nome, '');
      expect(identity.cognome, '');
      expect(identity.fullName, '');
      expect(identity.hasAnyAcceptedIdentityAnchor, isTrue);
    });
  });

  group('RealAssistitiTargetPreviewMapper payload fragments', () {
    const RealAssistitiResolvedIdentity identity = RealAssistitiResolvedIdentity(
      cf: 'CRPGNN48B19D514Z',
      nome: 'Giovanni',
      cognome: 'Crapanzano',
      fullName: 'Giovanni Crapanzano',
      nameSplitConfidence: 'derived_from_full_name_name_first',
    );

    test('builds search prefixes from valid fullName', () {
      final List<String> prefixes = RealAssistitiTargetPreviewMapper.buildSearchPrefixes(
        identity.fullName,
      );

      expect(prefixes, contains('giovanni'));
      expect(prefixes, contains('crapanzano'));
      expect(prefixes, contains('giovanni crapanzano'));
    });

    test('preserves doctor manual and primary metadata while filtering patient echoes', () {
      final Map<String, dynamic> doctor = RealAssistitiTargetPreviewMapper.buildDoctorPreview(
        doctorManualData: const <String, dynamic>{
          'doctorId': 'D1',
          'doctorFullName': 'VARIE',
          'doctorName': 'Giovanni Crapanzano',
          'nested': <String, dynamic>{'unsafe': true},
        },
        doctorPrimaryData: const <String, dynamic>{
          'medicoCodiceFiscale': 'RSSMRA80A01H501U',
          'medicoFullName': 'Mario Rossi',
        },
        identity: identity,
      );

      expect(doctor['manual'], isA<Map<String, dynamic>>());
      expect((doctor['manual'] as Map<String, dynamic>)['doctorId'], 'D1');
      expect((doctor['manual'] as Map<String, dynamic>)['doctorFullName'], 'VARIE');
      expect((doctor['manual'] as Map<String, dynamic>).containsKey('doctorName'), isFalse);
      expect((doctor['manual'] as Map<String, dynamic>).containsKey('nested'), isFalse);
      expect((doctor['primary'] as Map<String, dynamic>)['medicoFullName'], 'Mario Rossi');
    });

    test('keeps only dashboard operational fields', () {
      final Map<String, dynamic> dashboard = RealAssistitiTargetPreviewMapper.buildDashboardSnapshot(
        dashboardIndexData: const <String, dynamic>{
          'hasDebt': true,
          'debtCount': 1,
          'alias': 'Lo Vullo',
          'doctorFullName': 'VARIE',
          'source': 'runtime_signal_debts',
        },
        identity: identity,
      );

      expect(dashboard['hasDebt'], isTrue);
      expect(dashboard['debtCount'], 1);
      expect(dashboard.containsKey('alias'), isFalse);
      expect(dashboard.containsKey('doctorFullName'), isFalse);
      expect(dashboard.containsKey('source'), isFalse);
    });

    test('preserves therapeutic non-identity fields', () {
      final Map<String, dynamic> therapeuticAdvice =
          RealAssistitiTargetPreviewMapper.buildTherapeuticAdvicePreview(
        therapeuticAdviceData: const <String, dynamic>{
          'updatedAt': '2026-05-11T09:30:39Z',
          'note': 'Controllare aderenza',
          'fullName': 'Giovanni Crapanzano',
          'source': 'legacy',
        },
        identity: identity,
      );

      expect(therapeuticAdvice['updatedAt'], '2026-05-11T09:30:39Z');
      expect(therapeuticAdvice['note'], 'Controllare aderenza');
      expect(therapeuticAdvice.containsKey('fullName'), isFalse);
      expect(therapeuticAdvice.containsKey('source'), isFalse);
    });
  });
}
