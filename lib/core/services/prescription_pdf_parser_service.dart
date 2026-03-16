class ParsedPrescriptionData {
  final String patientName;
  final String fiscalCode;
  final String doctorName;
  final String exemptionCode;
  final String city;
  final DateTime? prescriptionDate;
  final bool dpcFlag;
  final int prescriptionCount;
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
    required this.prescriptionCount,
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
      'prescriptionCount': prescriptionCount,
      'medicines': medicines,
      'rawText': rawText,
    };
  }
}

class PrescriptionParserReferenceSet {
  final List<String> patientNames;
  final List<String> doctorNames;
  final List<String> cities;

  const PrescriptionParserReferenceSet({
    this.patientNames = const <String>[],
    this.doctorNames = const <String>[],
    this.cities = const <String>[],
  });
}

class PrescriptionPdfParserService {
  const PrescriptionPdfParserService();

  ParsedPrescriptionData parse(
    String rawText, {
    String fileName = '',
    PrescriptionParserReferenceSet references = const PrescriptionParserReferenceSet(),
  }) {
    final String normalized = _normalizeRawText(rawText);
    final String compact = _compactText(normalized);
    final List<String> lines = normalized
        .split('\n')
        .map(_cleanLine)
        .where((String e) => e.isNotEmpty)
        .toList();

    final String fiscalCode = _extractFiscalCode(normalized, compact);
    final DateTime? prescriptionDate = _extractDate(compact, lines);
    final bool dpcFlag = _extractDpcFlag(compact, fileName);
    final int prescriptionCount = _extractPrescriptionCount(normalized, compact);
    final String patientName = _applyReference(
      extracted: _extractPatientName(compact, lines, fiscalCode),
      references: references.patientNames,
      usePlaceSanitizer: false,
      rawText: compact,
    );
    final String doctorName = _applyReference(
      extracted: _extractDoctorName(compact, lines, patientName),
      references: references.doctorNames,
      usePlaceSanitizer: false,
      rawText: compact,
    );
    final String exemptionCode = _extractExemptionCode(compact, lines);
    final String city = _applyReference(
      extracted: _extractCity(compact, lines),
      references: references.cities,
      usePlaceSanitizer: true,
      rawText: compact,
    );
    final List<String> medicines = _extractMedicines(normalized, lines);

    return ParsedPrescriptionData(
      patientName: patientName,
      fiscalCode: fiscalCode,
      doctorName: doctorName,
      exemptionCode: exemptionCode,
      city: city,
      prescriptionDate: prescriptionDate,
      dpcFlag: dpcFlag,
      prescriptionCount: prescriptionCount,
      medicines: medicines,
      rawText: rawText,
    );
  }

  String _normalizeRawText(String rawText) {
    return rawText
        .replaceAll('\r', '\n')
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll('`', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), ' ');
  }

  String _compactText(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _extractFiscalCode(String normalized, String compact) {
    final Match? patientScoped = RegExp(
      r"COGNOME\s+E\s+NOME(?:\s*/\s*INIZIALI\s+DELL'?ASSISTITO)?[\s:]*.*?\b([A-Z]{6}[0-9]{2}[A-Z][0-9]{2}[A-Z][0-9]{3}[A-Z])\b",
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(normalized.toUpperCase());
    if (patientScoped != null) {
      return patientScoped.group(1) ?? '';
    }

    final Iterable<Match> matches = RegExp(
      r'\b[A-Z]{6}[0-9]{2}[A-Z][0-9]{2}[A-Z][0-9]{3}[A-Z]\b',
    ).allMatches(compact.toUpperCase());

    for (final Match match in matches) {
      final String value = match.group(0) ?? '';
      final int start = match.start;
      final int contextStart = start - 60 < 0 ? 0 : start - 60;
      final String context = compact.substring(contextStart, start).toUpperCase();
      if (context.contains('MEDICO')) continue;
      return value;
    }

    return '';
  }

  DateTime? _extractDate(String compact, List<String> lines) {
    final List<DateTime> labeledDates = <DateTime>[];

    for (final Match match in RegExp(
      r'\bDATA\s*:?\s*(\d{2})[/-](\d{2})[/-](\d{4})\b',
      caseSensitive: false,
    ).allMatches(compact)) {
      final DateTime? parsed = _parseDateParts(
        match.group(1),
        match.group(2),
        match.group(3),
      );
      if (parsed != null) labeledDates.add(parsed);
    }

    if (labeledDates.isNotEmpty) {
      labeledDates.sort();
      return labeledDates.last;
    }

    for (final String line in lines) {
      final String upper = line.toUpperCase();
      if (!upper.contains('DATA')) continue;
      for (final Match match in RegExp(r'\b(\d{2})[/-](\d{2})[/-](\d{4})\b').allMatches(line)) {
        final DateTime? parsed = _parseDateParts(
          match.group(1),
          match.group(2),
          match.group(3),
        );
        if (parsed != null) {
          labeledDates.add(parsed);
        }
      }
    }

    if (labeledDates.isNotEmpty) {
      labeledDates.sort();
      return labeledDates.last;
    }
    return null;
  }

  DateTime? _parseDateParts(String? dayRaw, String? monthRaw, String? yearRaw) {
    final int? day = int.tryParse(dayRaw ?? '');
    final int? month = int.tryParse(monthRaw ?? '');
    final int? year = int.tryParse(yearRaw ?? '');
    if (day == null || month == null || year == null) return null;

    final DateTime parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  bool _extractDpcFlag(String compact, String fileName) {
    final String text = '${compact.toUpperCase()} ${fileName.toUpperCase()}';
    return text.contains(' DPC') ||
        text.contains('DPC ') ||
        text.contains('_DPC') ||
        text.contains('-DPC') ||
        text.contains('DISTRIBUZIONE PER CONTO') ||
        text.contains('DIST PER CONTO');
  }

  int _extractPrescriptionCount(String normalized, String compact) {
    final String upperNormalized = normalized.toUpperCase();
    final String upperCompact = compact.toUpperCase();

    final int serviceCount = RegExp(r'SERVIZIO\s+SANITARIO\s+NAZIONALE').allMatches(upperNormalized).length;
    final int memoCount = RegExp(r'RICETTA\s+ELETTRONICA').allMatches(upperCompact).length;
    final int doctorCount = RegExp(r'COGNOME\s+E\s+NOME\s+DEL\s+MEDICO').allMatches(upperCompact).length;
    final int dateCount = RegExp(r'\bDATA\s*:?\s*\d{2}[/-]\d{2}[/-]\d{4}\b').allMatches(upperCompact).length;

    final int count = <int>[serviceCount, memoCount, doctorCount, dateCount]
        .reduce((int a, int b) => a > b ? a : b);

    if (count > 0) return count;
    return upperCompact.trim().isEmpty ? 0 : 1;
  }

  String _extractPatientName(String compact, List<String> lines, String fiscalCode) {
    final String byLabel = _extractValueNearLabels(
      lines,
      const <String>[
        'COGNOME E NOME/ INIZIALI DELL\'ASSISTITO',
        'COGNOME E NOME/INIZIALI DELL\'ASSISTITO',
        'COGNOME E NOME DELL\'ASSISTITO',
        'COGNOME E NOME',
        'ASSISTITO',
        'PAZIENTE',
        'NOME:',
      ],
      maxWords: 5,
      blockedWords: const <String>[
        'MEDICO',
        'DOTT',
        'DOTTORE',
        'ESENZIONE',
        'CODICE',
        'ASL',
        'REGIONE',
        'SICILIA',
      ],
    );
    if (byLabel.isNotEmpty && _looksLikePatientName(byLabel)) {
      return byLabel;
    }

    final String fromBlock = _extractNameByRegex(
      compact,
      RegExp(
        r"COGNOME\s+E\s+NOME(?:\s*/\s*INIZIALI\s+DELL'?ASSISTITO)?\s*:?\s*([A-ZÀ-ÖØ-Ý' ]{3,}?)(?=\s+(?:INDIRIZZO|CAP|COMUNE|CITTA|CITTÀ|PROV|ESENZIONE|SIGLA|TIPOLOGIA|CODICE)\b)",
        caseSensitive: false,
      ),
    );
    if (fromBlock.isNotEmpty) return fromBlock;

    if (fiscalCode.isNotEmpty) {
      for (int i = 0; i < lines.length; i++) {
        if (!lines[i].toUpperCase().contains(fiscalCode)) continue;
        for (final int index in <int>[i - 1, i - 2, i + 1, i + 2]) {
          if (index < 0 || index >= lines.length) continue;
          final String candidate = _sanitizePersonName(lines[index], maxWords: 5);
          if (_looksLikePatientName(candidate)) {
            return candidate;
          }
        }
      }
    }

    return '';
  }

  String _extractDoctorName(String compact, List<String> lines, String patientName) {
    final String byLabel = _extractValueNearLabels(
      lines,
      const <String>[
        'COGNOME E NOME DEL MEDICO',
        'COGNOME E NOME MEDICO',
        'MEDICO PRESCRITTORE',
        'DEL MEDICO',
        'DOTT.',
        'DOTT ',
        'DR.',
        'DR ',
      ],
      maxWords: 5,
      blockedWords: const <String>[
        'ASSISTITO',
        'PAZIENTE',
        'ESENZIONE',
        'RILASCIATO',
        'REGIONE',
        'SICILIA',
      ],
    );
    if (byLabel.isNotEmpty && !_sameLooseName(byLabel, patientName)) {
      return byLabel;
    }

    final String fromBlock = _extractNameByRegex(
      compact,
      RegExp(
        r"COGNOME\s+E\s+NOME\s+DEL\s+MEDICO\s*:?\s*([A-ZÀ-ÖØ-Ý' ]{3,}?)(?=(?:\s+)?(?:RILASCIATO|CODICE|DATA|$))",
        caseSensitive: false,
      ),
    );
    if (fromBlock.isNotEmpty && !_sameLooseName(fromBlock, patientName)) {
      return fromBlock;
    }

    return '';
  }

  String _extractExemptionCode(String compact, List<String> lines) {
    final Match? blockMatch = RegExp(
      r'ESENZIONE\s*:?\s*(NON\s+ESENTE|[A-Z0-9]{2,5})(?=\s+(?:SIGLA|TIPOLOGIA|ALTRO|CODICE|PROV|PRESCRIZIONE|DISPOSIZIONI)\b|$)',
      caseSensitive: false,
    ).firstMatch(compact);
    if (blockMatch != null) {
      return _normalizeExemption(blockMatch.group(1) ?? '');
    }

    for (int i = 0; i < lines.length; i++) {
      final String upper = lines[i].toUpperCase();
      if (!upper.contains('ESENZ')) continue;

      final String inline = _extractExemptionFromLine(lines[i]);
      if (inline.isNotEmpty) return inline;

      if (i + 1 < lines.length) {
        final String next = _extractExemptionFromLine(lines[i + 1]);
        if (next.isNotEmpty) return next;
      }
    }

    return '';
  }

  String _extractCity(String compact, List<String> lines) {
    for (final RegExp regex in <RegExp>[
      RegExp(
        r"\bCOMUNE\s*:?\s*([A-ZÀ-ÖØ-Ý' ]{2,}?)(?=(?:\s+)?(?:PROV|ESENZIONE|SIGLA|TIPOLOGIA|CODICE|DISPOSIZIONI|$))",
        caseSensitive: false,
      ),
      RegExp(
        r"\bCITTA'?\s*:?\s*([A-ZÀ-ÖØ-Ý' ]{2,}?)(?=(?:\s+)?(?:PROV|ESENZIONE|SIGLA|TIPOLOGIA|CODICE|DISPOSIZIONI|$))",
        caseSensitive: false,
      ),
      RegExp(
        r"\bCAP\s*:?\s*\d{5}\s+CITTA'?\s*:?\s*([A-ZÀ-ÖØ-Ý' ]{2,}?)(?=(?:\s+)?(?:PROV|ESENZIONE|SIGLA|TIPOLOGIA|CODICE|DISPOSIZIONI|$))",
        caseSensitive: false,
      ),
    ]) {
      final Match? match = regex.firstMatch(compact);
      if (match != null) {
        final String city = _sanitizePlace(match.group(1) ?? '');
        if (city.isNotEmpty) return city;
      }
    }

    return _extractValueNearLabels(
      lines,
      const <String>['COMUNE', 'CITTA', 'CITTÀ', 'LUOGO'],
      maxWords: 3,
      blockedWords: const <String>[
        'MEDICO',
        'ASSISTITO',
        'ESENZIONE',
        'REGIONE',
        'SICILIA',
      ],
      usePlaceSanitizer: true,
    );
  }

  String _extractNameByRegex(String text, RegExp regex) {
    final Match? match = regex.firstMatch(text);
    if (match == null) return '';
    return _sanitizePersonName(match.group(1) ?? '');
  }

  String _extractValueNearLabels(
    List<String> lines,
    List<String> labels, {
    int maxWords = 8,
    List<String> blockedWords = const <String>[],
    bool usePlaceSanitizer = false,
  }) {
    for (int i = 0; i < lines.length; i++) {
      final String original = lines[i];
      final String upper = original.toUpperCase();

      for (final String label in labels) {
        final int index = upper.indexOf(label);
        if (index < 0) continue;

        String inline = original.substring(index + label.length).trim();
        inline = inline.replaceFirst(RegExp(r'''^['":\-\s]+'''), '').trim();
        final String cleanedInline = usePlaceSanitizer
            ? _sanitizePlace(inline, maxWords: maxWords)
            : _sanitizePersonName(inline, maxWords: maxWords);
        if (_isAcceptedCandidate(
          cleanedInline,
          maxWords: maxWords,
          blockedWords: blockedWords,
          usePlaceSanitizer: usePlaceSanitizer,
        )) {
          return cleanedInline;
        }

        if (i + 1 < lines.length) {
          final String next = usePlaceSanitizer
              ? _sanitizePlace(lines[i + 1], maxWords: maxWords)
              : _sanitizePersonName(lines[i + 1], maxWords: maxWords);
          if (_isAcceptedCandidate(
            next,
            maxWords: maxWords,
            blockedWords: blockedWords,
            usePlaceSanitizer: usePlaceSanitizer,
          )) {
            return next;
          }
        }
      }
    }

    return '';
  }

  bool _isAcceptedCandidate(
    String candidate, {
    required int maxWords,
    required List<String> blockedWords,
    required bool usePlaceSanitizer,
  }) {
    if (candidate.isEmpty) return false;
    final List<String> words = candidate.split(RegExp(r'\s+'));
    if (words.length < 1 || words.length > maxWords) return false;

    final String upper = candidate.toUpperCase();
    for (final String blocked in blockedWords) {
      if (upper.contains(blocked)) return false;
    }

    if (!usePlaceSanitizer && RegExp(r'\d').hasMatch(candidate)) {
      return false;
    }

    return true;
  }

  String _extractExemptionFromLine(String line) {
    final Match? labeled = RegExp(
      r'ESENZ(?:IONE)?[^A-Z0-9]{0,10}(NON\s+ESENTE|[A-Z0-9]{2,5})\b',
      caseSensitive: false,
    ).firstMatch(line.toUpperCase());
    if (labeled != null) {
      return _normalizeExemption(labeled.group(1) ?? '');
    }
    return '';
  }

  String _normalizeExemption(String value) {
    final String upper = _compactText(value).toUpperCase();
    if (upper == 'NO' || upper == 'NON') return '';
    if (upper == 'NON ESENTE') return 'NON ESENTE';
    if (_looksLikeExemptionCode(upper)) return upper;
    return '';
  }

  bool _looksLikeExemptionCode(String value) {
    final String upper = value.toUpperCase().trim();
    if (upper.isEmpty) return false;
    if (upper == 'NO' || upper == 'NON') return false;
    if (upper == 'NON ESENTE') return true;
    if (upper == 'DPC') return false;
    if (RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(upper)) return false;
    return RegExp(r'^(E\d{1,4}|[A-Z]\d{1,4}|\d{2,4}|G\d{1,4}|L\d{1,4}|C\d{1,4})$')
        .hasMatch(upper);
  }

  String _sanitizePersonName(String value, {int maxWords = 5}) {
    String result = _prepareFieldValue(value)
        .replaceAll(RegExp(r'\bREGIONE\s+SICILIA\b.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bSERVIZIO\s+SANITARIO\s+NAZIONALE\b.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r"[^A-Za-zÀ-ÖØ-öø-ÿ'\s]"), ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    result = result.replaceAll(RegExp(r"^[\'\-:;,.\s]+"), '').trim();
    result = result.replaceAll(RegExp(r"[\'\-:;,.\s]+$"), '').trim();
    result = _keepFirstWords(result, maxWords);
    return _toNameCase(result);
  }

  String _sanitizePlace(String value, {int maxWords = 3}) {
    String result = _prepareFieldValue(value)
        .replaceAll(RegExp(r'\bREGIONE\s+SICILIA\b.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bSERVIZIO\s+SANITARIO\s+NAZIONALE\b.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(PROV|SIGLA|TIPOLOGIA|ESENZIONE|CODICE|DISPOSIZIONI|ASL)\b.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r"\b[A-Z]{6}[0-9]{2}[A-Z][0-9]{2}[A-Z][0-9]{3}[A-Z]\b"), ' ')
        .replaceAll(RegExp(r"[^A-Za-zÀ-ÖØ-öø-ÿ'\s]"), ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    result = result.replaceAll(RegExp(r"^[\'\-:;,.\s]+"), '').trim();
    result = result.replaceAll(RegExp(r"[\'\-:;,.\s]+$"), '').trim();
    result = _keepFirstWords(result, maxWords);
    return _toNameCase(result);
  }

  String _prepareFieldValue(String value) {
    String result = _cutAtMarkers(_cleanLine(value), _tailMarkers);
    result = result.replaceAll(
      RegExp(r'(?i)([A-ZÀ-ÖØ-Ý])((?:CODICE|RILASCIATO|PROV|CAP|ESENZIONE|SIGLA|TIPOLOGIA|DISPOSIZIONI|ASL|COMUNE|CITTA|CITTÀ))'),
      r'$1 $2',
    );
    result = result.replaceAll(
      RegExp(r'(?i)([A-ZÀ-ÖØ-Ý])((?:REGIONE|SICILIA|SERVIZIO))'),
      r'$1 $2',
    );
    result = result.replaceAll(RegExp(r"\b[A-Z]{6}[0-9]{2}[A-Z][0-9]{2}[A-Z][0-9]{3}[A-Z]\b"), ' ');
    result = _cutAtMarkers(result, _tailMarkers);
    return result;
  }

  List<String> get _tailMarkers => const <String>[
        'RILASCIATO',
        'CODICE AUTENTICAZIONE',
        'CODICE FISCALE',
        'CODICE',
        'ESENZIONE',
        'COMUNE',
        'CITTA',
        'CITTÀ',
        'PROV',
        'CAP',
        'SIGLA',
        'TIPOLOGIA',
        'DISPOSIZIONI',
        'REGIONE',
        'SICILIA',
        'ASL',
        'QUESITO',
        'PRESCRIZIONE',
      ];

  String _keepFirstWords(String value, int maxWords) {
    if (value.isEmpty) return '';
    final List<String> words = value.split(RegExp(r'\s+')).where((String word) => word.isNotEmpty).toList();
    if (words.length <= maxWords) return words.join(' ');
    return words.take(maxWords).join(' ');
  }

  bool _looksLikePatientName(String value) {
    if (value.isEmpty) return false;
    final String upper = value.toUpperCase();
    if (upper.contains('DOTT') || upper.contains('DOTTORE') || upper.contains('DR.')) {
      return false;
    }
    if (upper.contains('ESENZ') || upper.contains('CODICE FISCALE')) return false;
    if (upper.contains('REGIONE') || upper.contains('SICILIA')) return false;
    if (RegExp(r'\d').hasMatch(value)) return false;
    final List<String> words = value.split(RegExp(r'\s+'));
    if (words.length < 2 || words.length > 5) return false;
    return words.every((String word) => word.length >= 2);
  }

  bool _sameLooseName(String a, String b) {
    final String left = a.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    final String right = b.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    return left.isNotEmpty && left == right;
  }

  String _cleanLine(String value) {
    return value.replaceAll('\t', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _toNameCase(String value) {
    if (value.isEmpty) return '';
    return value
        .split(RegExp(r'\s+'))
        .map((String word) {
          if (word.isEmpty) return word;
          if (word.contains("'")) {
            return word
                .split("'")
                .map((String part) => part.isEmpty
                    ? part
                    : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
                .join("'");
          }
          return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
        })
        .join(' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  List<String> _extractMedicines(String normalized, List<String> lines) {
    final List<String> candidates = <String>[];
    final List<String> sectionLines = _extractPrescriptionSectionLines(normalized, lines);

    for (final String line in <String>[...sectionLines, ...lines]) {
      if (_looksLikeMedicineLine(line)) {
        candidates.add(_sanitizeMedicineLine(line));
      }
    }

    final List<String> unique = <String>[];
    for (final String item in candidates) {
      if (item.isEmpty) continue;
      final String normalizedItem = item.toUpperCase();
      if (unique.any((String existing) => existing.toUpperCase() == normalizedItem)) {
        continue;
      }
      unique.add(item);
    }
    return unique;
  }

  List<String> _extractPrescriptionSectionLines(String normalized, List<String> lines) {
    final List<String> results = <String>[];
    bool inside = false;
    int trailingWindow = 0;

    for (final String line in lines) {
      final String upper = line.toUpperCase();

      if (upper.contains('PRESCRIZIONE')) {
        inside = true;
        trailingWindow = 8;
        continue;
      }

      if (upper.contains('SERVIZIO SANITARIO NAZIONALE') && results.isNotEmpty) {
        inside = false;
        trailingWindow = 0;
      }

      if (!inside && trailingWindow <= 0) {
        continue;
      }

      if (_looksLikeMedicineLine(line)) {
        results.add(line);
      }

      if (inside && (upper.contains('QUESITO DIAGNOSTICO') || upper.contains('COGNOME E NOME DEL MEDICO'))) {
        inside = false;
      }

      if (trailingWindow > 0) {
        trailingWindow--;
      }
    }

    return results;
  }

  bool _looksLikeMedicineLine(String line) {
    final String cleaned = _cleanLine(line);
    final String upper = cleaned.toUpperCase().trim();
    if (upper.isEmpty) return false;
    if (upper == 'PRESCRIZIONE' ||
        upper == 'QTA' ||
        upper == "QTA'" ||
        upper == 'NOTA' ||
        upper == '---') {
      return false;
    }
    if (upper.contains('CODICE FISCALE') ||
        upper.contains('COGNOME E NOME') ||
        upper.contains('QUESITO') ||
        upper.contains('REGIONE SICILIA') ||
        upper.contains('SERVIZIO SANITARIO') ||
        upper.contains('ESENZIONE') ||
        upper.contains('CODICE AUTENTICAZIONE') ||
        upper.contains('RILASCIATO AI SENSI')) {
      return false;
    }

    final bool dosageLike = RegExp(
      r'(MG|MCG|G\b|ML|CPR|CPS|COMPRESSE|CAPSULE|SCIROPPO|GOCCE|FIALA|FIALE|BUSTINE|BUSTA|CEROTTO|FLACONE|SOLUZIONE|USO ORALE|RIV|CREMA|POMATA|SPRAY|PENNA|IM\b|OS\b)',
      caseSensitive: false,
    ).hasMatch(cleaned);
    final bool qtyLike = RegExp(r'\b(QTA|QT\.?A?\b|X\s*\d+|N\.?\s*\d+)\b', caseSensitive: false).hasMatch(cleaned);
    final bool productCodeLike = RegExp(r'^\(?\d{6,9}\)?\s*[- ]\s*[A-ZÀ-ÖØ-Ý0-9]', caseSensitive: false).hasMatch(cleaned) ||
        RegExp(r'^\d{6,9}\s+[A-ZÀ-ÖØ-Ý0-9]', caseSensitive: false).hasMatch(cleaned);
    final bool recipeCodeLike = RegExp(r'^\(?[A-Z0-9]{3,4}\)?\s*[- ]\s*[A-ZÀ-ÖØ-Ý]', caseSensitive: false).hasMatch(cleaned);
    final bool commercialLike = cleaned.contains('*') || cleaned.contains(':');

    return (dosageLike && (productCodeLike || recipeCodeLike || commercialLike || qtyLike)) ||
        productCodeLike ||
        (recipeCodeLike && dosageLike);
  }

  String _sanitizeMedicineLine(String line) {
    String cleaned = _cleanLine(line)
        .replaceAll(RegExp(r'^\d+\s*[-–]\s*'), '')
        .replaceAll(RegExp(r'^QTA\s*:?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    cleaned = _cutAtMarkers(cleaned, const <String>[
      'QUESITO',
      'NOTE',
      'DISPOSIZIONI',
      'CODICE AUTENTICAZIONE',
      'RILASCIATO',
      'COGNOME E NOME DEL MEDICO',
      'SERVIZIO SANITARIO',
    ]);
    cleaned = cleaned.replaceAll(RegExp(r'\s+\d+\s*---$'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+\d+\s+\d+$'), '');
    cleaned = cleaned.replaceAll(RegExp(r'^[\-:;,.\s]+'), '').trim();
    cleaned = cleaned.replaceAll(RegExp(r'[\-:;,.\s]+$'), '').trim();
    return cleaned;
  }

  String _cutAtMarkers(String value, List<String> markers) {
    String result = value;
    final String upper = result.toUpperCase();
    int? minIndex;
    for (final String marker in markers) {
      final int index = upper.indexOf(marker.toUpperCase());
      if (index <= 0) continue;
      if (minIndex == null || index < minIndex) {
        minIndex = index;
      }
    }
    if (minIndex != null) {
      result = result.substring(0, minIndex).trim();
    }
    return result;
  }

  String _applyReference({
    required String extracted,
    required List<String> references,
    required bool usePlaceSanitizer,
    required String rawText,
  }) {
    if (references.isEmpty) {
      return extracted;
    }

    final String sanitizedExtracted = usePlaceSanitizer
        ? _sanitizePlace(extracted)
        : _sanitizePersonName(extracted);
    final String normalizedExtracted = _normalizeReferenceKey(sanitizedExtracted);

    if (normalizedExtracted.isNotEmpty) {
      for (final String value in references) {
        final String normalizedReference = _normalizeReferenceKey(value);
        if (normalizedReference.isEmpty) continue;
        if (normalizedExtracted == normalizedReference ||
            normalizedExtracted.startsWith(normalizedReference) ||
            normalizedReference.startsWith(normalizedExtracted)) {
          return usePlaceSanitizer ? _sanitizePlace(value) : _sanitizePersonName(value);
        }
      }
    }

    final String normalizedRaw = _normalizeReferenceKey(rawText);
    for (final String value in references) {
      final String normalizedReference = _normalizeReferenceKey(value);
      if (normalizedReference.isNotEmpty && normalizedRaw.contains(normalizedReference)) {
        return usePlaceSanitizer ? _sanitizePlace(value) : _sanitizePersonName(value);
      }
    }

    return sanitizedExtracted;
  }

  String _normalizeReferenceKey(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-ZÀ-ÖØ-Ý]'), '');
  }
}
