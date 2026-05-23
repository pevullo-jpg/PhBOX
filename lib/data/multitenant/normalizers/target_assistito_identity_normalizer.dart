class TargetAssistitoIdentityNormalizationResult {
  final String cf;
  final String nome;
  final String cognome;
  final String fullName;
  final String nameSplitConfidence;

  const TargetAssistitoIdentityNormalizationResult({
    required this.cf,
    required this.nome,
    required this.cognome,
    required this.fullName,
    required this.nameSplitConfidence,
  });

  bool get hasValidName =>
      fullName.isNotEmpty &&
      !TargetAssistitoIdentityNormalizer.isPlaceholderName(fullName) &&
      !TargetAssistitoIdentityNormalizer.isFiscalCodeLike(fullName) &&
      !TargetAssistitoIdentityNormalizer.containsFiscalCodeLikeToken(fullName);

  bool get hasSplitName => nome.isNotEmpty || cognome.isNotEmpty;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'cf': cf,
      'nome': nome,
      'cognome': cognome,
      'fullName': fullName,
      'nameSplitConfidence': nameSplitConfidence,
    };
  }
}

class TargetAssistitoIdentityNormalizer {
  static const String fallbackFullName = 'Assistito senza nome';
  static const String splitConfidenceExplicit = 'explicit_fields';
  static const String splitConfidenceUnverifiedFullName = 'unverified_full_name';
  static const String splitConfidenceFallback = 'fallback';

  const TargetAssistitoIdentityNormalizer();

  TargetAssistitoIdentityNormalizationResult normalize({
    required String rawCf,
    String rawNome = '',
    String rawCognome = '',
    String rawFullName = '',
  }) {
    final String cf = normalizeCf(rawCf);
    final String nome = normalizeNamePart(rawNome);
    final String cognome = normalizeNamePart(rawCognome);
    final String fullNameCandidate = normalizeFullName(rawFullName);

    if (nome.isNotEmpty || cognome.isNotEmpty) {
      final String derivedFullName = _joinNameParts(cognome: cognome, nome: nome);
      return TargetAssistitoIdentityNormalizationResult(
        cf: cf,
        nome: nome,
        cognome: cognome,
        fullName: derivedFullName.isEmpty ? fallbackFullName : derivedFullName,
        nameSplitConfidence: splitConfidenceExplicit,
      );
    }

    if (_isValidHumanName(fullNameCandidate)) {
      return TargetAssistitoIdentityNormalizationResult(
        cf: cf,
        nome: '',
        cognome: '',
        fullName: fullNameCandidate,
        nameSplitConfidence: splitConfidenceUnverifiedFullName,
      );
    }

    return TargetAssistitoIdentityNormalizationResult(
      cf: cf,
      nome: '',
      cognome: '',
      fullName: fallbackFullName,
      nameSplitConfidence: splitConfidenceFallback,
    );
  }

  static String normalizeCf(String value) {
    return value.replaceAll(RegExp(r'\s+'), '').trim().toUpperCase();
  }

  static String normalizeFullName(String value) {
    final String normalized = _normalizeWhitespace(value);
    if (!_isValidHumanName(normalized)) {
      return '';
    }
    return normalizeNamePart(normalized);
  }

  static String normalizeNamePart(String value) {
    final String normalized = _normalizeWhitespace(value);
    if (normalized.isEmpty) {
      return '';
    }
    if (isPlaceholderName(normalized)) {
      return '';
    }
    if (containsFiscalCodeLikeToken(normalized) || isFiscalCodeLike(normalized)) {
      return '';
    }
    final List<String> words = normalized
        .split(' ')
        .map(_normalizeCompositeNameWord)
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
    return words.join(' ');
  }

  static bool isFiscalCodeLike(String value) {
    return RegExp(r'^[A-Z]{6}[0-9]{2}[A-Z][0-9]{2}[A-Z][0-9]{3}[A-Z]$')
        .hasMatch(normalizeCf(value));
  }

  static bool containsFiscalCodeLikeToken(String value) {
    return _normalizeWhitespace(value)
        .split(' ')
        .map(normalizeCf)
        .any(isFiscalCodeLike);
  }

  static bool isOcrFragment(String value) {
    final String normalized = value.trim().toUpperCase();
    if (normalized.length < 5 || normalized.length > 8) {
      return false;
    }
    if (!RegExp(r'^[A-Z]+$').hasMatch(normalized)) {
      return false;
    }
    final bool hasVowel = RegExp('[AEIOU]').hasMatch(normalized);
    return !hasVowel;
  }

  static bool isPlaceholderName(String value) {
    return _normalizeWhitespace(value).toLowerCase() == fallbackFullName.toLowerCase();
  }

  static bool _isValidHumanName(String value) {
    final String normalized = _normalizeWhitespace(value);
    if (normalized.length < 3) {
      return false;
    }
    if (isPlaceholderName(normalized)) {
      return false;
    }
    if (isFiscalCodeLike(normalized) || containsFiscalCodeLikeToken(normalized)) {
      return false;
    }
    final List<String> tokens = normalized.split(' ');
    if (tokens.any(isOcrFragment)) {
      return false;
    }
    return true;
  }

  static String _joinNameParts({required String cognome, required String nome}) {
    return <String>[cognome, nome]
        .where((String item) => item.trim().isNotEmpty)
        .join(' ')
        .trim();
  }

  static String _normalizeWhitespace(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _normalizeCompositeNameWord(String value) {
    return value
        .split('-')
        .map(_normalizeApostropheNameWord)
        .where((String item) => item.isNotEmpty)
        .join('-');
  }

  static String _normalizeApostropheNameWord(String value) {
    return value
        .split("'")
        .map(_capitalizeNameAtom)
        .where((String item) => item.isNotEmpty)
        .join("'");
  }

  static String _capitalizeNameAtom(String value) {
    final String lower = value.trim().toLowerCase();
    if (lower.isEmpty) {
      return '';
    }
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }
}
