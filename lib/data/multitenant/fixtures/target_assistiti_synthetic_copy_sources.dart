import '../mappers/legacy_to_target_assistito_mapper.dart';

class TargetAssistitiSyntheticCopySources {
  static const String scenarioId = 'synthetic_family_normalization_v2';
  static const String syntheticCreatedAt = '2026-01-01T00:00:00.000Z';
  static const String syntheticUpdatedAt = '2026-01-02T00:00:00.000Z';

  static const List<LegacyAssistitoSourceBundle> familyNormalizationBatch =
      <LegacyAssistitoSourceBundle>[
    LegacyAssistitoSourceBundle(
      assistitoId: 'synthetic_family_villa_giuseppe',
      fiscalCode: 'TSTVLL84H27A089I',
      patient: <String, dynamic>{
        'nome': 'giuseppe',
        'cognome': 'villa',
        'createdAt': syntheticCreatedAt,
        'updatedAt': syntheticUpdatedAt,
      },
      dashboardIndex: <String, dynamic>{
        'syntheticScenario': scenarioId,
        'syntheticFamilyId': 'family_synthetic_villa',
        'syntheticFamilyRole': 'padre',
      },
    ),
    LegacyAssistitoSourceBundle(
      assistitoId: 'synthetic_family_villa_maria_grazia',
      fiscalCode: 'TSTDLU81B02H501X',
      patient: <String, dynamic>{
        'nome': 'maria grazia',
        'cognome': 'de luca',
        'createdAt': syntheticCreatedAt,
        'updatedAt': syntheticUpdatedAt,
      },
      dashboardIndex: <String, dynamic>{
        'syntheticScenario': scenarioId,
        'syntheticFamilyId': 'family_synthetic_villa',
        'syntheticFamilyRole': 'madre',
      },
    ),
    LegacyAssistitoSourceBundle(
      assistitoId: 'synthetic_family_villa_luca_damico',
      fiscalCode: 'TSTDMC82C03H501X',
      patient: <String, dynamic>{
        'nome': 'luca',
        'cognome': "villa d'amico",
        'createdAt': syntheticCreatedAt,
        'updatedAt': syntheticUpdatedAt,
      },
      dashboardIndex: <String, dynamic>{
        'syntheticScenario': scenarioId,
        'syntheticFamilyId': 'family_synthetic_villa',
        'syntheticFamilyRole': 'figlio',
      },
    ),
  ];

  const TargetAssistitiSyntheticCopySources._();
}
