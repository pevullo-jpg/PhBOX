import 'target_assistito.dart';

class LegacyTargetAssistitoFieldComparison {
  static const int defaultPreviewLength = 120;
  static const int defaultPreviewItems = 8;

  final String field;
  final bool matches;
  final bool expectedMissing;
  final bool actualMissing;
  final String expectedPreview;
  final String actualPreview;

  const LegacyTargetAssistitoFieldComparison({
    required this.field,
    required this.matches,
    required this.expectedMissing,
    required this.actualMissing,
    required this.expectedPreview,
    required this.actualPreview,
  });

  factory LegacyTargetAssistitoFieldComparison.compare({
    required String field,
    required Object? expectedValue,
    required Object? actualValue,
    int maxPreviewLength = defaultPreviewLength,
    int maxPreviewItems = defaultPreviewItems,
  }) {
    return LegacyTargetAssistitoFieldComparison(
      field: field.trim(),
      matches: _deepEquals(expectedValue, actualValue),
      expectedMissing: _isMissing(expectedValue),
      actualMissing: _isMissing(actualValue),
      expectedPreview: _previewValue(
        expectedValue,
        maxLength: maxPreviewLength,
        maxItems: maxPreviewItems,
      ),
      actualPreview: _previewValue(
        actualValue,
        maxLength: maxPreviewLength,
        maxItems: maxPreviewItems,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'field': field,
      'matches': matches,
      'expectedMissing': expectedMissing,
      'actualMissing': actualMissing,
      'expectedPreview': expectedPreview,
      'actualPreview': actualPreview,
    };
  }
}

class TargetAssistitoDocumentIdentityComparison {
  final String documentId;
  final String fieldAssistitoId;
  final bool fieldPresent;
  final bool fieldMatchesDocumentId;

  const TargetAssistitoDocumentIdentityComparison({
    required this.documentId,
    required this.fieldAssistitoId,
    required this.fieldPresent,
    required this.fieldMatchesDocumentId,
  });

  factory TargetAssistitoDocumentIdentityComparison.fromDocument({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    final String normalizedDocumentId = documentId.trim();
    final String fieldValue = _readString(data['assistitoId']);
    return TargetAssistitoDocumentIdentityComparison(
      documentId: normalizedDocumentId,
      fieldAssistitoId: fieldValue,
      fieldPresent: fieldValue.isNotEmpty,
      fieldMatchesDocumentId: normalizedDocumentId.isNotEmpty && fieldValue == normalizedDocumentId,
    );
  }

  bool get isValid => fieldPresent && fieldMatchesDocumentId;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'documentId': documentId,
      'fieldAssistitoId': fieldAssistitoId,
      'fieldPresent': fieldPresent,
      'fieldMatchesDocumentId': fieldMatchesDocumentId,
      'valid': isValid,
    };
  }
}

class LegacyTargetAssistitoComparison {
  final String expectedAssistitoId;
  final String actualAssistitoId;
  final List<LegacyTargetAssistitoFieldComparison> fields;
  final TargetAssistitoDocumentIdentityComparison? documentIdentity;

  const LegacyTargetAssistitoComparison({
    required this.expectedAssistitoId,
    required this.actualAssistitoId,
    required this.fields,
    this.documentIdentity,
  });

  factory LegacyTargetAssistitoComparison.fromAssistiti({
    required TargetAssistito expected,
    required TargetAssistito actual,
    TargetAssistitoDocumentIdentityComparison? documentIdentity,
    bool compareTimestamps = false,
  }) {
    final List<LegacyTargetAssistitoFieldComparison> comparisons = <LegacyTargetAssistitoFieldComparison>[
      LegacyTargetAssistitoFieldComparison.compare(
        field: 'assistitoId',
        expectedValue: expected.assistitoId,
        actualValue: actual.assistitoId,
      ),
      LegacyTargetAssistitoFieldComparison.compare(
        field: 'cf',
        expectedValue: expected.cf.toUpperCase(),
        actualValue: actual.cf.toUpperCase(),
      ),
      LegacyTargetAssistitoFieldComparison.compare(
        field: 'nome',
        expectedValue: expected.nome.trim(),
        actualValue: actual.nome.trim(),
      ),
      LegacyTargetAssistitoFieldComparison.compare(
        field: 'cognome',
        expectedValue: expected.cognome.trim(),
        actualValue: actual.cognome.trim(),
      ),
      LegacyTargetAssistitoFieldComparison.compare(
        field: 'fullName',
        expectedValue: expected.fullName.trim(),
        actualValue: actual.fullName.trim(),
      ),
      LegacyTargetAssistitoFieldComparison.compare(
        field: 'nameSplitConfidence',
        expectedValue: expected.nameSplitConfidence.trim(),
        actualValue: actual.nameSplitConfidence.trim(),
      ),
      LegacyTargetAssistitoFieldComparison.compare(
        field: 'searchPrefixes',
        expectedValue: _normalizedStringList(expected.searchPrefixes),
        actualValue: _normalizedStringList(actual.searchPrefixes),
      ),
      LegacyTargetAssistitoFieldComparison.compare(
        field: 'doctor',
        expectedValue: expected.doctor,
        actualValue: actual.doctor,
      ),
      LegacyTargetAssistitoFieldComparison.compare(
        field: 'dashboard',
        expectedValue: expected.dashboard,
        actualValue: actual.dashboard,
      ),
      LegacyTargetAssistitoFieldComparison.compare(
        field: 'therapeuticAdvice',
        expectedValue: expected.therapeuticAdvice,
        actualValue: actual.therapeuticAdvice,
      ),
      LegacyTargetAssistitoFieldComparison.compare(
        field: 'sourceVersion',
        expectedValue: expected.sourceVersion,
        actualValue: actual.sourceVersion,
      ),
    ];

    if (compareTimestamps) {
      comparisons.addAll(<LegacyTargetAssistitoFieldComparison>[
        LegacyTargetAssistitoFieldComparison.compare(
          field: 'createdAt',
          expectedValue: expected.createdAt,
          actualValue: actual.createdAt,
        ),
        LegacyTargetAssistitoFieldComparison.compare(
          field: 'updatedAt',
          expectedValue: expected.updatedAt,
          actualValue: actual.updatedAt,
        ),
      ]);
    }

    return LegacyTargetAssistitoComparison(
      expectedAssistitoId: expected.assistitoId.trim(),
      actualAssistitoId: actual.assistitoId.trim(),
      fields: List<LegacyTargetAssistitoFieldComparison>.unmodifiable(comparisons),
      documentIdentity: documentIdentity,
    );
  }

  bool get matches {
    if (documentIdentity != null && !documentIdentity!.isValid) {
      return false;
    }
    return fields.every((LegacyTargetAssistitoFieldComparison field) => field.matches);
  }

  int get fieldCount => fields.length;

  int get mismatchCount => mismatches.length;

  List<LegacyTargetAssistitoFieldComparison> get mismatches {
    return List<LegacyTargetAssistitoFieldComparison>.unmodifiable(
      fields.where((LegacyTargetAssistitoFieldComparison field) => !field.matches),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'expectedAssistitoId': expectedAssistitoId,
      'actualAssistitoId': actualAssistitoId,
      'matches': matches,
      'fieldCount': fieldCount,
      'mismatchCount': mismatchCount,
      'documentIdentity': documentIdentity?.toMap(),
      'fields': fields
          .map((LegacyTargetAssistitoFieldComparison field) => field.toMap())
          .toList(growable: false),
    };
  }
}

List<String> _normalizedStringList(Iterable<String> values) {
  return values
      .map((String value) => value.trim())
      .where((String value) => value.isNotEmpty)
      .toList(growable: false);
}

String _readString(Object? value) {
  return value?.toString().trim() ?? '';
}

bool _isMissing(Object? value) {
  if (value == null) return true;
  if (value is String) return value.trim().isEmpty;
  if (value is Iterable) return value.isEmpty;
  if (value is Map) return value.isEmpty;
  return false;
}

bool _deepEquals(Object? left, Object? right) {
  if (identical(left, right)) return true;
  if (left == null || right == null) return false;

  if (left is DateTime && right is DateTime) {
    return left.toUtc().millisecondsSinceEpoch == right.toUtc().millisecondsSinceEpoch;
  }

  if (left is Iterable && right is Iterable) {
    final List<Object?> leftList = left.cast<Object?>().toList(growable: false);
    final List<Object?> rightList = right.cast<Object?>().toList(growable: false);
    if (leftList.length != rightList.length) return false;
    for (int index = 0; index < leftList.length; index += 1) {
      if (!_deepEquals(leftList[index], rightList[index])) return false;
    }
    return true;
  }

  if (left is Map && right is Map) {
    if (left.length != right.length) return false;
    for (final Object? key in left.keys) {
      if (!right.containsKey(key)) return false;
      if (!_deepEquals(left[key], right[key])) return false;
    }
    return true;
  }

  return left == right;
}

String _previewValue(
  Object? value, {
  required int maxLength,
  required int maxItems,
}) {
  final String preview = _rawPreviewValue(value, maxItems: maxItems);
  if (maxLength <= 0) return '';
  if (preview.length <= maxLength) return preview;
  if (maxLength <= 3) return preview.substring(0, maxLength);
  return '${preview.substring(0, maxLength - 3)}...';
}

String _rawPreviewValue(Object? value, {required int maxItems}) {
  if (value == null) return '';
  if (value is DateTime) return value.toUtc().toIso8601String();
  if (value is String) return value.trim();
  if (value is Iterable) {
    final List<String> items = value
        .take(maxItems < 0 ? 0 : maxItems)
        .map((Object? item) => _rawPreviewValue(item, maxItems: 0))
        .toList(growable: false);
    final bool truncated = value.length > items.length;
    return '[${items.join(', ')}${truncated ? ', ...' : ''}]';
  }
  if (value is Map) {
    final List<MapEntry<String, Object?>> entries = value.entries
        .map((MapEntry<dynamic, dynamic> entry) => MapEntry<String, Object?>(entry.key.toString(), entry.value))
        .toList(growable: false)
      ..sort((MapEntry<String, Object?> left, MapEntry<String, Object?> right) => left.key.compareTo(right.key));
    final List<String> items = entries
        .take(maxItems < 0 ? 0 : maxItems)
        .map(
          (MapEntry<String, Object?> entry) => '${entry.key}: ${_rawPreviewValue(entry.value, maxItems: 0)}',
        )
        .toList(growable: false);
    final bool truncated = entries.length > items.length;
    return '{${items.join(', ')}${truncated ? ', ...' : ''}}';
  }
  return value.toString();
}
