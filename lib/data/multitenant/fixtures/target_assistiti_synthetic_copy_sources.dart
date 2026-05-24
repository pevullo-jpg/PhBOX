import '../mappers/legacy_to_target_assistito_mapper.dart';

class TargetAssistitiSyntheticCopySources {
  static const String scenarioId = 'synthetic_family_normalization_v4';
  static const String syntheticFamilyId = 'family_synthetic_villa_v4';
  static const String syntheticCreatedAt = '2026-01-01T00:00:00.000Z';
  static const String syntheticUpdatedAt = '2026-01-02T00:00:00.000Z';

  static const Map<String, dynamic> syntheticDoctorManualLink = <String, dynamic>{
    'medicoNome': 'Elena',
    'medicoCognome': 'Ferri',
    'codiceMedico': 'MED-SYN-001',
  };

  static const List<LegacyAssistitoSourceBundle> familyNormalizationBatch =
      <LegacyAssistitoSourceBundle>[
    LegacyAssistitoSourceBundle(
      assistitoId: 'syn_assistito_0001',
      fiscalCode: 'TSTVLL84H27A089I',
      patient: <String, dynamic>{
        'nome': 'giuseppe',
        'cognome': 'villa',
        'createdAt': syntheticCreatedAt,
        'updatedAt': syntheticUpdatedAt,
      },
      dashboardIndex: <String, dynamic>{
        'syntheticScenario': scenarioId,
        'syntheticFamilyId': syntheticFamilyId,
      },
      doctorManualLink: syntheticDoctorManualLink,
    ),
    LegacyAssistitoSourceBundle(
      assistitoId: 'syn_assistito_0002',
      fiscalCode: 'TSTDLU81B02H501X',
      patient: <String, dynamic>{
        'nome': 'maria grazia',
        'cognome': 'de luca',
        'createdAt': syntheticCreatedAt,
        'updatedAt': syntheticUpdatedAt,
      },
      dashboardIndex: <String, dynamic>{
        'syntheticScenario': scenarioId,
        'syntheticFamilyId': syntheticFamilyId,
      },
      doctorManualLink: syntheticDoctorManualLink,
    ),
    LegacyAssistitoSourceBundle(
      assistitoId: 'syn_assistito_0003',
      fiscalCode: 'TSTDMC82C03H501X',
      patient: <String, dynamic>{
        'nome': 'luca',
        'cognome': "villa d'amico",
        'createdAt': syntheticCreatedAt,
        'updatedAt': syntheticUpdatedAt,
      },
      dashboardIndex: <String, dynamic>{
        'syntheticScenario': scenarioId,
        'syntheticFamilyId': syntheticFamilyId,
      },
      doctorManualLink: syntheticDoctorManualLink,
    ),
  ];

  const TargetAssistitiSyntheticCopySources._();
}
