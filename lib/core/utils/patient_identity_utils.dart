String buildManualPatientDocumentId({
  required String fiscalCode,
  required String name,
  required String surname,
  required DateTime now,
}) {
  final String normalizedFiscalCode = fiscalCode.trim().toUpperCase();
  if (normalizedFiscalCode.isNotEmpty) {
    return normalizedFiscalCode;
  }

  final String normalizedName = _normalizePatientToken(name);
  final String normalizedSurname = _normalizePatientToken(surname);
  final String readableSeed = <String>[normalizedName, normalizedSurname]
      .where((item) => item.isNotEmpty)
      .join('_');

  final String fallbackSeed = readableSeed.isEmpty ? 'MANUAL' : readableSeed;
  return 'TMP_${fallbackSeed}_${now.microsecondsSinceEpoch}'.toUpperCase();
}

String buildManualPatientFullName({
  required String name,
  required String surname,
}) {
  return <String>[name.trim(), surname.trim()]
      .where((item) => item.isNotEmpty)
      .join(' ')
      .trim();
}

bool isTemporaryPatientKey(String value) {
  return value.trim().toUpperCase().startsWith('TMP_');
}

String visiblePatientFiscalCode(String value) {
  final String normalized = value.trim().toUpperCase();
  if (normalized.isEmpty || isTemporaryPatientKey(normalized)) {
    return '-';
  }
  return normalized;
}

String visiblePatientTitle({
  required String fullName,
  required String patientKey,
}) {
  final String normalizedName = fullName.trim();
  if (normalizedName.isNotEmpty) {
    return normalizedName;
  }

  final String visibleCode = visiblePatientFiscalCode(patientKey);
  if (visibleCode != '-') {
    return visibleCode;
  }

  return 'Assistito senza anagrafica';
}

String _normalizePatientToken(String value) {
  return value
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}
