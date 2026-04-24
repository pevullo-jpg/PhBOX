class PatientInputNormalizer {
  const PatientInputNormalizer._();

  static String normalizeFiscalCode(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();
  }

  static String normalizeNamePart(String value) {
    return value
        .trim()
        .split(RegExp(r'\s+'))
        .where((String item) => item.isNotEmpty)
        .join(' ');
  }

  static String normalizeFullName(String value) {
    return normalizeNamePart(value);
  }

  static String buildFullName({
    required String name,
    required String surname,
  }) {
    final String normalizedName = normalizeNamePart(name);
    final String normalizedSurname = normalizeNamePart(surname);
    return <String>[normalizedName, normalizedSurname]
        .where((String item) => item.isNotEmpty)
        .join(' ')
        .trim();
  }

  static List<String> splitFullName(String value) {
    final String normalized = normalizeFullName(value);
    if (normalized.isEmpty) {
      return const <String>['', ''];
    }
    final List<String> parts = normalized
        .split(RegExp(r'\s+'))
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
    if (parts.length == 1) {
      return <String>[parts.first, ''];
    }
    return <String>[parts.first, parts.sublist(1).join(' ')];
  }
}
