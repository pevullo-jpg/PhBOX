class DoctorDisplayUtils {
  const DoctorDisplayUtils._();

  static String bestDisplay({
    String? preferred,
    List<String?> fallbacks = const <String?>[],
  }) {
    final String normalizedPreferred = _clean(preferred);
    String best = normalizedPreferred;

    for (final fallback in fallbacks) {
      final String candidate = _clean(fallback);
      if (candidate.isEmpty) continue;
      if (best.isEmpty) {
        best = candidate;
        continue;
      }
      if (_isMoreCompleteVersion(candidate, best)) {
        best = candidate;
      }
    }

    return best.isEmpty ? '-' : best;
  }

  static String _clean(String? value) {
    final String cleaned = value?.trim() ?? '';
    if (cleaned.isEmpty || cleaned == '-') return '';
    return cleaned;
  }

  static bool _isMoreCompleteVersion(String candidate, String current) {
    final List<String> candidateTokens = _tokens(candidate);
    final List<String> currentTokens = _tokens(current);
    final bool candidateContainsCurrent = currentTokens.isNotEmpty && currentTokens.every(candidateTokens.contains);
    if (candidateContainsCurrent) {
      if (candidateTokens.length != currentTokens.length) {
        return candidateTokens.length > currentTokens.length;
      }
      return candidate.length > current.length;
    }
    return false;
  }

  static List<String> _tokens(String value) {
    return value
        .toUpperCase()
        .split(RegExp(r'\s+'))
        .map((token) => token.trim())
        .where((token) => token.isNotEmpty)
        .toList();
  }
}
