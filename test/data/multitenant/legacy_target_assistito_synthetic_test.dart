import 'package:flutter_test/flutter_test.dart';
import 'package:farmacia_desk_web/data/multitenant/mappers/legacy_to_target_assistito_mapper.dart';
import 'package:farmacia_desk_web/data/multitenant/normalizers/target_assistito_identity_normalizer.dart';
import 'package:farmacia_desk_web/data/multitenant/reports/legacy_target_assistito_batch_verification_report.dart';
import 'package:farmacia_desk_web/data/multitenant/verifiers/legacy_target_assistito_verifier.dart';

void main() {
  group('Synthetic legacy target assistito fixtures', () {
    const LegacyToTargetAssistitoMapper mapper = LegacyToTargetAssistitoMapper();

    test('normalizes standard separated name fields without fiscal-code prefixes', () {
      final target = mapper.map(
        _source(
          assistitoId: 'assistito_001',
          cf: 'tsttst80a01h501x',
          nome: 'mario',
          cognome: 'rossi',
        ),
      );

      expect(target.assistitoId, 'assistito_001');
      expect(target.cf, 'TSTTST80A01H501X');
      expect(target.nome, 'Mario');
      expect(target.cognome, 'Rossi');
      expect(target.fullName, 'Rossi Mario');
      expect(target.nameSplitConfidence, TargetAssistitoIdentityNormalizer.splitConfidenceExplicit);
      expect(target.searchPrefixes, isNotEmpty);
      _expectSearchPrefixesExcludeCf(target.searchPrefixes, target.cf);
      expect(target.fullName.contains(target.cf), isFalse);
    });

    test('keeps fullName-only source unverified without blind split', () {
      final target = mapper.map(
        _source(
          assistitoId: 'assistito_004',
          cf: 'TSTTST83D04H501X',
          fullName: 'giuseppe verdi',
        ),
      );

      expect(target.cf, 'TSTTST83D04H501X');
      expect(target.nome, '');
      expect(target.cognome, '');
      expect(target.fullName, 'Giuseppe Verdi');
      expect(target.nameSplitConfidence, TargetAssistitoIdentityNormalizer.splitConfidenceUnverifiedFullName);
      expect(target.searchPrefixes, isNotEmpty);
      _expectSearchPrefixesExcludeCf(target.searchPrefixes, target.cf);
    });

    test('turns split placeholder parts into fallback with empty prefixes', () {
      final target = mapper.map(
        _source(
          assistitoId: 'assistito_006',
          cf: 'TSTTST85F06H501X',
          nome: 'Assistito',
          cognome: 'Senza Nome',
        ),
      );

      expect(target.cf, 'TSTTST85F06H501X');
      expect(target.nome, '');
      expect(target.cognome, '');
      expect(target.fullName, TargetAssistitoIdentityNormalizer.fallbackFullName);
      expect(target.nameSplitConfidence, TargetAssistitoIdentityNormalizer.splitConfidenceFallback);
      expect(target.searchPrefixes, isEmpty);
      _expectSearchPrefixesExcludeCf(target.searchPrefixes, target.cf);
    });

    test('keeps fiscal code only in cf when raw name is fiscal-code-like', () {
      final target = mapper.map(
        _source(
          assistitoId: 'assistito_007',
          cf: 'TSTTST86G07H501X',
          nome: 'TSTTST86G07H501X',
        ),
      );

      expect(target.cf, 'TSTTST86G07H501X');
      expect(target.nome, '');
      expect(target.cognome, '');
      expect(target.fullName, TargetAssistitoIdentityNormalizer.fallbackFullName);
      expect(target.searchPrefixes, isEmpty);
      _expectSearchPrefixesExcludeCf(target.searchPrefixes, target.cf);
      expect(target.toMap().containsKey('fiscalCode'), isFalse);
    });
  });

  group('Synthetic legacy target assistito verification', () {
    const LegacyToTargetAssistitoMapper mapper = LegacyToTargetAssistitoMapper();
    const LegacyTargetAssistitoVerifier verifier = LegacyTargetAssistitoVerifier();

    test('verifies a perfect synthetic match', () {
      final legacy = _source(
        assistitoId: 'assistito_010',
        cf: 'TSTTST89L10H501X',
        nome: 'paolo',
        cognome: 'lo monaco',
      );
      final expected = mapper.map(legacy);

      _expectSearchPrefixesExcludeCf(expected.searchPrefixes, expected.cf);

      final result = verifier.verifyOne(
        legacy: legacy,
        targetDocumentId: expected.assistitoId,
        targetData: expected.toMap(),
      );

      expect(result.verified, isTrue);
      expect(result.targetDocumentIdProvided, isTrue);
      expect(result.targetDocumentIdMatchesExpected, isTrue);
      expect(result.comparison.matches, isTrue);
    });

    test('flags missing target document and empty target document id', () {
      final legacy = _source(
        assistitoId: 'assistito_011',
        cf: 'TSTTST90M11H501X',
        nome: 'anna',
        cognome: 'neri',
      );
      final expected = mapper.map(legacy);

      _expectSearchPrefixesExcludeCf(expected.searchPrefixes, expected.cf);

      final missingTarget = verifier.verifyOne(
        legacy: legacy,
        targetDocumentId: expected.assistitoId,
        targetData: null,
      );
      final emptyTargetId = verifier.verifyOne(
        legacy: legacy,
        targetDocumentId: '',
        targetData: expected.toMap(),
      );

      expect(missingTarget.verified, isFalse);
      expect(missingTarget.targetDocumentPresent, isFalse);
      expect(emptyTargetId.verified, isFalse);
      expect(emptyTargetId.targetDocumentIdProvided, isFalse);
      expect(emptyTargetId.targetDocumentIdMatchesExpected, isFalse);
    });

    test('builds bounded batch report from synthetic inputs', () {
      final matchingLegacy = _source(
        assistitoId: 'assistito_020',
        cf: 'TSTTST91N12H501X',
        nome: 'luca',
        cognome: "d'amico",
      );
      final missingLegacy = _source(
        assistitoId: 'assistito_021',
        cf: 'TSTTST92P13H501X',
        fullName: 'maria bianchi',
      );
      final emptyIdLegacy = _source(
        assistitoId: 'assistito_022',
        cf: 'TSTTST93R14H501X',
        nome: 'maria grazia',
        cognome: 'de luca',
      );

      final matchingTarget = mapper.map(matchingLegacy);
      final emptyIdTarget = mapper.map(emptyIdLegacy);

      _expectSearchPrefixesExcludeCf(matchingTarget.searchPrefixes, matchingTarget.cf);
      _expectSearchPrefixesExcludeCf(emptyIdTarget.searchPrefixes, emptyIdTarget.cf);

      final report = LegacyTargetAssistitoBatchVerificationReport.fromInputs(
        inputs: <LegacyTargetAssistitoVerificationInput>[
          LegacyTargetAssistitoVerificationInput(
            legacy: matchingLegacy,
            targetDocumentId: matchingTarget.assistitoId,
            targetData: matchingTarget.toMap(),
          ),
          LegacyTargetAssistitoVerificationInput(
            legacy: missingLegacy,
            targetDocumentId: 'assistito_021',
            targetData: null,
          ),
          LegacyTargetAssistitoVerificationInput(
            legacy: emptyIdLegacy,
            targetDocumentId: '',
            targetData: emptyIdTarget.toMap(),
          ),
        ],
        maxReportedIssues: 2,
        maxReportedMismatchesPerIssue: 3,
      );

      expect(report.inputCount, 3);
      expect(report.verifiedCount, 1);
      expect(report.issueCount, 2);
      expect(report.targetDocumentMissingCount, 1);
      expect(report.targetDocumentIdMissingCount, 1);
      expect(report.targetDocumentIdMismatchCount, 1);
      expect(report.reportedIssueCount, 2);
      expect(report.issuesTruncated, isFalse);
      expect(report.allVerified, isFalse);
    });
  });
}

LegacyAssistitoSourceBundle _source({
  required String assistitoId,
  required String cf,
  String nome = '',
  String cognome = '',
  String fullName = '',
}) {
  return LegacyAssistitoSourceBundle(
    assistitoId: assistitoId,
    fiscalCode: cf,
    patient: <String, dynamic>{
      if (nome.isNotEmpty) 'nome': nome,
      if (cognome.isNotEmpty) 'cognome': cognome,
      if (fullName.isNotEmpty) 'fullName': fullName,
    },
    dashboardIndex: const <String, dynamic>{},
    therapeuticAdvice: const <String, dynamic>{},
    doctorPrimaryLink: const <String, dynamic>{},
    doctorManualLink: const <String, dynamic>{},
  );
}

void _expectSearchPrefixesExcludeCf(Iterable<String> searchPrefixes, String cf) {
  final String normalizedCf = cf.trim().toUpperCase();
  expect(normalizedCf, isNotEmpty);
  expect(
    searchPrefixes.any((String prefix) => prefix.trim().toUpperCase().contains(normalizedCf)),
    isFalse,
  );
  expect(
    searchPrefixes.any(TargetAssistitoIdentityNormalizer.isFiscalCodeLike),
    isFalse,
  );
}
