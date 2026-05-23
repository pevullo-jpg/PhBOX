import '../normalizers/target_assistito_identity_normalizer.dart';

class TargetAssistito {
  final String assistitoId;
  final String cf;
  final String nome;
  final String cognome;
  final String fullName;
  final String nameSplitConfidence;
  final List<String> searchPrefixes;
  final Map<String, dynamic> doctor;
  final Map<String, dynamic> dashboard;
  final Map<String, dynamic> therapeuticAdvice;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int sourceVersion;

  const TargetAssistito({
    required this.assistitoId,
    required this.cf,
    required this.nome,
    required this.cognome,
    required this.fullName,
    required this.nameSplitConfidence,
    required this.searchPrefixes,
    required this.doctor,
    required this.dashboard,
    required this.therapeuticAdvice,
    required this.createdAt,
    required this.updatedAt,
    required this.sourceVersion,
  });

  String get fiscalCode => cf;

  factory TargetAssistito.empty({
    required String assistitoId,
    String cf = '',
    String fiscalCode = '',
  }) {
    final String resolvedCf = cf.trim().isNotEmpty ? cf : fiscalCode;
    return TargetAssistito(
      assistitoId: assistitoId.trim(),
      cf: TargetAssistitoIdentityNormalizer.normalizeCf(resolvedCf),
      nome: '',
      cognome: '',
      fullName: '',
      nameSplitConfidence: TargetAssistitoIdentityNormalizer.splitConfidenceFallback,
      searchPrefixes: const <String>[],
      doctor: const <String, dynamic>{},
      dashboard: const <String, dynamic>{},
      therapeuticAdvice: const <String, dynamic>{},
      createdAt: null,
      updatedAt: null,
      sourceVersion: 0,
    );
  }

  factory TargetAssistito.fromMap({
    required String assistitoId,
    required Map<String, dynamic> map,
  }) {
    final String cf = _readFirstString(map, const <String>['cf', 'fiscalCode', 'codiceFiscale']);
    final String nome = _readFirstString(map, const <String>['nome', 'firstName', 'givenName']);
    final String cognome = _readFirstString(map, const <String>['cognome', 'lastName', 'surname', 'familyName']);
    final String fullName = _readString(map['fullName']);
    final TargetAssistitoIdentityNormalizationResult normalized = const TargetAssistitoIdentityNormalizer().normalize(
      rawCf: cf,
      rawNome: nome,
      rawCognome: cognome,
      rawFullName: fullName,
    );

    return TargetAssistito(
      assistitoId: assistitoId.trim(),
      cf: normalized.cf,
      nome: normalized.nome,
      cognome: normalized.cognome,
      fullName: normalized.fullName,
      nameSplitConfidence: _readString(map['nameSplitConfidence']).isEmpty
          ? normalized.nameSplitConfidence
          : _readString(map['nameSplitConfidence']),
      searchPrefixes: _readStringList(map['searchPrefixes']),
      doctor: _readMap(map['doctor']),
      dashboard: _readMap(map['dashboard']),
      therapeuticAdvice: _readMap(map['therapeuticAdvice']),
      createdAt: _readDate(map['createdAt']),
      updatedAt: _readDate(map['updatedAt']),
      sourceVersion: _readInt(map['sourceVersion']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'assistitoId': assistitoId,
      'cf': cf,
      'nome': nome,
      'cognome': cognome,
      'fullName': fullName,
      'nameSplitConfidence': nameSplitConfidence,
      'searchPrefixes': searchPrefixes,
      'doctor': doctor,
      'dashboard': dashboard,
      'therapeuticAdvice': therapeuticAdvice,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'sourceVersion': sourceVersion,
    };
  }

  static String _readFirstString(Map<String, dynamic> map, List<String> keys) {
    for (final String key in keys) {
      final String value = _readString(map[key]);
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  static String _readString(Object? value) {
    return value?.toString().trim() ?? '';
  }

  static int _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<String> _readStringList(Object? value) {
    if (value is Iterable) {
      return value
          .map((Object? item) => item?.toString().trim() ?? '')
          .where((String item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  static Map<String, dynamic> _readMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.unmodifiable(value);
    }
    if (value is Map) {
      return Map<String, dynamic>.unmodifiable(
        value.map((dynamic key, dynamic item) => MapEntry<String, dynamic>(key.toString(), item)),
      );
    }
    return const <String, dynamic>{};
  }

  static DateTime? _readDate(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) return DateTime.tryParse(value.trim());
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    try {
      final dynamic date = (value as dynamic).toDate();
      if (date is DateTime) return date;
    } catch (_) {}
    return null;
  }
}
