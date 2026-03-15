class ParsedPrescriptionData {
  final String patientName;
  final String fiscalCode;
  final String doctorName;
  final String exemptionCode;
  final String city;
  final DateTime? prescriptionDate;
  final bool dpcFlag;
  final List<String> medicines;
  final String rawText;

  const ParsedPrescriptionData({
    required this.patientName,
    required this.fiscalCode,
    required this.doctorName,
    required this.exemptionCode,
    required this.city,
    required this.prescriptionDate,
    required this.dpcFlag,
    required this.medicines,
    required this.rawText,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'patientName': patientName,
      'fiscalCode': fiscalCode,
      'doctorName': doctorName,
      'exemptionCode': exemptionCode,
      'city': city,
      'prescriptionDate': prescriptionDate?.toIso8601String(),
      'dpcFlag': dpcFlag,
      'medicines': medicines,
      'rawText': rawText,
    };
  }
}

class PrescriptionPdfParserService {
  const PrescriptionPdfParserService();

  ParsedPrescriptionData parse(String rawText) {
    final String normalized = rawText.replaceAll('', '');
    final List<String> lines = normalized
        .split('
')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final String fiscalCode = _extractFiscalCode(normalized);
    final DateTime? prescriptionDate = _extractDate(normalized);
    final bool dpcFlag = normalized.toUpperCase().contains('DPC');
    final String patientName = _extractLabeledValue(
      lines,
      <String>['ASSISTITO', 'PAZIENTE', 'NOME ASSISTITO', 'COGNOME E NOME'],
    );
    final String doctorName = _extractLabeledValue(
      lines,
      <String>['MEDICO', 'DOTT', 'DOTT.', 'DOTTORE'],
    );
    final String exemptionCode = _extractLabeledValue(
      lines,
      <String>['ESENZIONE'],
    );
    final String city = _extractLabeledValue(
      lines,
      <String>['COMUNE', 'CITTA', 'CITTÀ'],
    );
    final List<String> medicines = _extractMedicines(lines);

    return ParsedPrescriptionData(
      patientName: patientName,
      fiscalCode: fiscalCode,
      doctorName: doctorName,
      exemptionCode: exemptionCode,
      city: city,
      prescriptionDate: prescriptionDate,
      dpcFlag: dpcFlag,
      medicines: medicines,
      rawText: rawText,
    );
  }

  String _extractFiscalCode(String text) {
    final RegExp regex = RegExp(r'\b[A-Z]{6}[0-9]{2}[A-Z][0-9]{2}[A-Z][0-9]{3}[A-Z]\b');
    final Match? match = regex.firstMatch(text.toUpperCase());
    return match?.group(0) ?? '';
  }

  DateTime? _extractDate(String text) {
    final RegExp regex = RegExp(r'\b(\d{2})/(\d{2})/(\d{4})\b');
    final Match? match = regex.firstMatch(text);
    if (match == null) return null;

    final int? day = int.tryParse(match.group(1) ?? '');
    final int? month = int.tryParse(match.group(2) ?? '');
    final int? year = int.tryParse(match.group(3) ?? '');
    if (day == null || month == null || year == null) return null;

    return DateTime(year, month, day);
  }

  String _extractLabeledValue(List<String> lines, List<String> labels) {
    for (final String line in lines) {
      final String upper = line.toUpperCase();
      for (final String label in labels) {
        if (upper.startsWith(label)) {
          final String cleaned = line.substring(label.length).trim();
          final String result = cleaned
              .replaceFirst(':', '')
              .replaceFirst('-', '')
              .trim();
          if (result.isNotEmpty) {
            return result;
          }
        }
      }
    }
    return '';
  }

  List<String> _extractMedicines(List<String> lines) {
    final List<String> results = <String>[];
    final RegExp medicineHint = RegExp(
      r'(MG|MCG|ML|CPR|COMPRESSE|CAPSULE|SCIROPPO|GOCCE|FIALA|BUSTINE|CEROTTO)',
      caseSensitive: false,
    );

    for (final String line in lines) {
      if (line.length < 6) continue;
      if (medicineHint.hasMatch(line)) {
        results.add(line);
      }
    }

    return results.take(10).toList();
  }
}
