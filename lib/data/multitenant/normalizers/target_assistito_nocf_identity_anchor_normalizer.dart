import 'target_assistito_identity_normalizer.dart';

class TargetAssistitoNoCfIdentityAnchorRejectedException implements Exception {
  final String code;
  final String message;

  const TargetAssistitoNoCfIdentityAnchorRejectedException({
    required this.code,
    required this.message,
  });

  @override
  String toString() {
    return 'TargetAssistitoNoCfIdentityAnchorRejectedException($code): $message';
  }
}

class TargetAssistitoIdentityAnchorResult {
  final String cf;
  final String identityType;
  final String identityAnchor;
  final String legacyNoCfCode;
  final bool generatedNoCf;

  const TargetAssistitoIdentityAnchorResult({
    required this.cf,
    required this.identityType,
    required this.identityAnchor,
    required this.legacyNoCfCode,
    required this.generatedNoCf,
  });

  bool get isCf => identityType == TargetAssistitoNoCfIdentityAnchorNormalizer.identityTypeCf;

  bool get isNoCf => identityType == TargetAssistitoNoCfIdentityAnchorNormalizer.identityTypeNoCf;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'cf': cf,
      'identityType': identityType,
      'identityAnchor': identityAnchor,
      if (legacyNoCfCode.isNotEmpty) 'legacyNoCfCode': legacyNoCfCode,
      'generatedNoCf': generatedNoCf,
    };
  }
}

class TargetAssistitoNoCfToRealCfPromotionResult {
  final String promotedCf;
  final String identityType;
  final String identityAnchor;
  final List<String> previousIdentityAnchors;
  final String legacyNoCfCode;
  final bool generatedNoCf;

  const TargetAssistitoNoCfToRealCfPromotionResult({
    required this.promotedCf,
    required this.identityType,
    required this.identityAnchor,
    required this.previousIdentityAnchors,
    required this.legacyNoCfCode,
    required this.generatedNoCf,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'cf': promotedCf,
      'identityType': identityType,
      'identityAnchor': identityAnchor,
      'previousIdentityAnchors': previousIdentityAnchors,
      if (legacyNoCfCode.isNotEmpty) 'legacyNoCfCode': legacyNoCfCode,
      'generatedNoCf': generatedNoCf,
    };
  }
}

class TargetAssistitoNoCfIdentityAnchorNormalizer {
  static const String identityTypeCf = 'cf';
  static const String identityTypeNoCf = 'nocf';
  static const String noCfPrefix = 'NOCF_';
  static const int maxLegacyCodeLength = 128;
  static const int minLegacyCodeLength = 3;

  const TargetAssistitoNoCfIdentityAnchorNormalizer._();

  static TargetAssistitoIdentityAnchorResult fromLegacyCode(String rawCode) {
    final String originalCode = rawCode.trim();
    final String normalized = _normalizeCode(rawCode);
    _rejectInvalidLegacyCode(
      originalCode: originalCode,
      normalizedCode: normalized,
    );

    if (TargetAssistitoIdentityNormalizer.isFiscalCodeLike(normalized)) {
      return TargetAssistitoIdentityAnchorResult(
        cf: normalized,
        identityType: identityTypeCf,
        identityAnchor: normalized,
        legacyNoCfCode: '',
        generatedNoCf: false,
      );
    }

    final String canonical = _canonicalNoCf(
      namespace: 'legacy_nocf',
      stableSource: normalized,
    );
    return TargetAssistitoIdentityAnchorResult(
      cf: canonical,
      identityType: identityTypeNoCf,
      identityAnchor: canonical,
      legacyNoCfCode: originalCode,
      generatedNoCf: false,
    );
  }

  static TargetAssistitoIdentityAnchorResult fromNewNoCf({
    required String tenantId,
    required String nome,
    required String cognome,
    required int createdAtMillis,
    required String nonce,
  }) {
    final String normalizedTenantId = tenantId.trim();
    final String normalizedNome = TargetAssistitoIdentityNormalizer.normalizeNamePart(nome);
    final String normalizedCognome = TargetAssistitoIdentityNormalizer.normalizeNamePart(cognome);
    final String normalizedNonce = _normalizeCode(nonce);

    if (normalizedTenantId.isEmpty) {
      throw const TargetAssistitoNoCfIdentityAnchorRejectedException(
        code: 'tenant_id_empty',
        message: 'tenantId obbligatorio per generare NOCF canonico.',
      );
    }
    if (_containsUnsafePathSeparator(normalizedTenantId)) {
      throw const TargetAssistitoNoCfIdentityAnchorRejectedException(
        code: 'tenant_id_not_canonical',
        message: 'tenantId non canonico: slash non ammesso.',
      );
    }
    if (createdAtMillis <= 0) {
      throw const TargetAssistitoNoCfIdentityAnchorRejectedException(
        code: 'created_at_millis_invalid',
        message: 'createdAtMillis obbligatorio e positivo per generare NOCF canonico.',
      );
    }
    if (normalizedNonce.length < minLegacyCodeLength) {
      throw const TargetAssistitoNoCfIdentityAnchorRejectedException(
        code: 'nonce_invalid',
        message: 'Nonce obbligatorio e stabile per generare NOCF canonico.',
      );
    }
    if (normalizedNome.isEmpty && normalizedCognome.isEmpty) {
      throw const TargetAssistitoNoCfIdentityAnchorRejectedException(
        code: 'nocf_identity_name_anchor_missing',
        message: 'Per un nuovo NOCF serve almeno nome o cognome valido.',
      );
    }

    final String stableSource = <String>[
      normalizedTenantId,
      createdAtMillis.toString(),
      normalizedNome,
      normalizedCognome,
      normalizedNonce,
    ].join('|');
    final String canonical = _canonicalNoCf(
      namespace: 'new_nocf',
      stableSource: stableSource,
    );

    return TargetAssistitoIdentityAnchorResult(
      cf: canonical,
      identityType: identityTypeNoCf,
      identityAnchor: canonical,
      legacyNoCfCode: '',
      generatedNoCf: true,
    );
  }

  static TargetAssistitoNoCfToRealCfPromotionResult buildNoCfToRealCfPromotion({
    required String currentCf,
    required String currentIdentityType,
    required String currentIdentityAnchor,
    required String newRawCf,
    String legacyNoCfCode = '',
    bool generatedNoCf = false,
    Iterable<String> previousIdentityAnchors = const <String>[],
  }) {
    final String normalizedCurrentCf = _normalizeCode(currentCf);
    final String normalizedCurrentIdentityType = currentIdentityType.trim().toLowerCase();
    final String normalizedCurrentIdentityAnchor = _normalizeCode(currentIdentityAnchor);
    final String promotedCf = TargetAssistitoIdentityNormalizer.normalizeCf(newRawCf);

    if (normalizedCurrentIdentityType != identityTypeNoCf) {
      throw const TargetAssistitoNoCfIdentityAnchorRejectedException(
        code: 'source_identity_type_not_nocf',
        message: 'La promozione a CF reale è consentita solo da identityType nocf.',
      );
    }
    if (!isCanonicalNoCf(normalizedCurrentCf)) {
      throw const TargetAssistitoNoCfIdentityAnchorRejectedException(
        code: 'source_nocf_not_canonical',
        message: 'Sorgente NOCF non canonica: promozione bloccata.',
      );
    }
    if (normalizedCurrentIdentityAnchor != normalizedCurrentCf) {
      throw const TargetAssistitoNoCfIdentityAnchorRejectedException(
        code: 'source_identity_anchor_mismatch',
        message: 'identityAnchor sorgente non coerente con cf NOCF.',
      );
    }
    if (!TargetAssistitoIdentityNormalizer.isFiscalCodeLike(promotedCf)) {
      throw const TargetAssistitoNoCfIdentityAnchorRejectedException(
        code: 'target_cf_not_canonical',
        message: 'CF reale target non canonico: promozione bloccata.',
      );
    }

    final List<String> safePreviousAnchors = _normalizePreviousIdentityAnchors(
      previousIdentityAnchors,
    );
    if (!safePreviousAnchors.contains(normalizedCurrentCf)) {
      safePreviousAnchors.add(normalizedCurrentCf);
    }

    return TargetAssistitoNoCfToRealCfPromotionResult(
      promotedCf: promotedCf,
      identityType: identityTypeCf,
      identityAnchor: promotedCf,
      previousIdentityAnchors: List<String>.unmodifiable(safePreviousAnchors),
      legacyNoCfCode: legacyNoCfCode.trim(),
      generatedNoCf: generatedNoCf,
    );
  }

  static bool isCanonicalNoCf(String value) {
    final String normalized = value.trim().toUpperCase();
    return RegExp(r'^NOCF_[0-9A-F]{16}$').hasMatch(normalized);
  }

  static bool _containsUnsafePathSeparator(String value) {
    return value.contains('/') || value.contains('\\');
  }

  static void _rejectInvalidLegacyCode({
    required String originalCode,
    required String normalizedCode,
  }) {
    if (normalizedCode.isEmpty) {
      throw const TargetAssistitoNoCfIdentityAnchorRejectedException(
        code: 'identity_code_empty',
        message: 'Codice identità obbligatorio per assistito CF/NOCF.',
      );
    }
    if (_containsUnsafePathSeparator(originalCode) || _containsUnsafePathSeparator(normalizedCode)) {
      throw const TargetAssistitoNoCfIdentityAnchorRejectedException(
        code: 'identity_code_not_canonical',
        message: 'Codice identità non canonico: slash non ammesso.',
      );
    }
    if (normalizedCode.length < minLegacyCodeLength) {
      throw const TargetAssistitoNoCfIdentityAnchorRejectedException(
        code: 'identity_code_too_short',
        message: 'Codice identità troppo corto per assistito CF/NOCF.',
      );
    }
    if (normalizedCode.length > maxLegacyCodeLength) {
      throw const TargetAssistitoNoCfIdentityAnchorRejectedException(
        code: 'identity_code_too_long',
        message: 'Codice identità troppo lungo per assistito CF/NOCF.',
      );
    }
  }

  static List<String> _normalizePreviousIdentityAnchors(Iterable<String> values) {
    final List<String> normalized = <String>[];
    for (final String value in values) {
      final String anchor = _normalizeCode(value);
      if (anchor.isEmpty) {
        continue;
      }
      if (_containsUnsafePathSeparator(value) || _containsUnsafePathSeparator(anchor)) {
        throw const TargetAssistitoNoCfIdentityAnchorRejectedException(
          code: 'previous_identity_anchor_not_canonical',
          message: 'previousIdentityAnchors contiene valori non canonici.',
        );
      }
      if (!isCanonicalNoCf(anchor) &&
          !TargetAssistitoIdentityNormalizer.isFiscalCodeLike(anchor)) {
        throw const TargetAssistitoNoCfIdentityAnchorRejectedException(
          code: 'previous_identity_anchor_invalid',
          message: 'previousIdentityAnchors contiene anchor non valido.',
        );
      }
      if (!normalized.contains(anchor)) {
        normalized.add(anchor);
      }
    }
    return normalized;
  }

  static String _normalizeCode(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), '_').toUpperCase();
  }

  static String _canonicalNoCf({
    required String namespace,
    required String stableSource,
  }) {
    final String normalizedSource = '$namespace|$stableSource'.trim().toUpperCase();
    return '$noCfPrefix${_fnv1a64Hex(normalizedSource)}';
  }

  static String _fnv1a64Hex(String value) {
    const int fnvOffsetHigh = 0xcbf29ce4;
    const int fnvOffsetLow = 0x84222325;
    const int fnvPrime = 0x000001b3;

    int high = fnvOffsetHigh;
    int low = fnvOffsetLow;

    for (final int byte in value.codeUnits) {
      low = (low ^ (byte & 0xff)) & 0xffffffff;
      final int newLow = (low * fnvPrime) & 0xffffffff;
      final int carry = ((low * fnvPrime) / 0x100000000).floor() & 0xffffffff;
      final int newHigh = ((high * fnvPrime) + carry) & 0xffffffff;
      high = newHigh;
      low = newLow;
    }

    return '${_hex32(high)}${_hex32(low)}';
  }

  static String _hex32(int value) {
    return value.toUnsigned(32).toRadixString(16).padLeft(8, '0').toUpperCase();
  }
}
