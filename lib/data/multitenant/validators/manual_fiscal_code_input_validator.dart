import '../normalizers/target_assistito_identity_normalizer.dart';

class ManualFiscalCodeInputRejectedException implements Exception {
  final String code;
  final String message;

  const ManualFiscalCodeInputRejectedException({
    required this.code,
    required this.message,
  });

  @override
  String toString() {
    return 'ManualFiscalCodeInputRejectedException($code): $message';
  }
}

class ManualFiscalCodeInputValidator {
  static const int defaultMaxFiscalCodes = 3;

  const ManualFiscalCodeInputValidator._();

  static List<String> normalizeAndValidate({
    required Iterable<String> fiscalCodes,
    int maxFiscalCodes = defaultMaxFiscalCodes,
  }) {
    final List<String> normalizedFiscalCodes = fiscalCodes
        .map(TargetAssistitoIdentityNormalizer.normalizeCf)
        .toList(growable: false);

    if (normalizedFiscalCodes.isEmpty) {
      throw const ManualFiscalCodeInputRejectedException(
        code: 'manual_cf_empty',
        message: 'Inserire almeno un CF manuale.',
      );
    }
    if (normalizedFiscalCodes.length > maxFiscalCodes) {
      throw ManualFiscalCodeInputRejectedException(
        code: 'manual_cf_exceeds_hard_cap',
        message: 'Operazione limitata a massimo $maxFiscalCodes CF manuali per run.',
      );
    }

    final Set<String> seen = <String>{};
    for (int index = 0; index < normalizedFiscalCodes.length; index++) {
      final String cf = normalizedFiscalCodes[index];
      if (cf.isEmpty) {
        throw ManualFiscalCodeInputRejectedException(
          code: 'manual_cf_blank',
          message: 'CF manuale vuoto non ammesso alla posizione ${index + 1}.',
        );
      }
      if (!isValidFiscalCode(cf)) {
        throw ManualFiscalCodeInputRejectedException(
          code: 'manual_cf_invalid',
          message: 'CF manuale non valido o non canonico: $cf.',
        );
      }
      if (!seen.add(cf)) {
        throw ManualFiscalCodeInputRejectedException(
          code: 'manual_cf_duplicate',
          message: 'CF manuale duplicato nello stesso run: $cf.',
        );
      }
    }

    return List<String>.unmodifiable(normalizedFiscalCodes);
  }

  static bool isValidFiscalCode(String cf) {
    return RegExp(r'^[A-Z]{6}[0-9]{2}[A-Z][0-9]{2}[A-Z][0-9]{3}[A-Z]$').hasMatch(cf);
  }
}
