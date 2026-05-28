import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/target_multitenant_collections.dart';
import 'target_write_executor_guarded.dart';

class TargetAssistitiFirestoreCopyRejectedException implements Exception {
  final String code;
  final String message;
  final String path;

  const TargetAssistitiFirestoreCopyRejectedException({
    required this.code,
    required this.message,
    this.path = '',
  });

  @override
  String toString() {
    final String suffix = path.trim().isEmpty ? '' : ' path=$path';
    return 'TargetAssistitiFirestoreCopyRejectedException($code): $message$suffix';
  }
}

class TargetAssistitiFirestoreCopySink implements TargetWriteCommitSink {
  static const int defaultMaxWritesPerInstance = 5;

  final FirebaseFirestore firestore;
  final int maxWritesPerInstance;
  int _writesReserved = 0;
  int _writesCommitted = 0;

  TargetAssistitiFirestoreCopySink({
    required this.firestore,
    this.maxWritesPerInstance = defaultMaxWritesPerInstance,
  }) {
    if (maxWritesPerInstance <= 0) {
      throw ArgumentError.value(
        maxWritesPerInstance,
        'maxWritesPerInstance',
        'La copia assistiti target richiede un limite positivo.',
      );
    }
  }

  int get writesReserved => _writesReserved;
  int get writesCommitted => _writesCommitted;
  int get writesRemaining => maxWritesPerInstance - _writesReserved;

  @override
  Future<void> setDocument({
    required String path,
    required Map<String, dynamic> data,
  }) async {
    final _TargetAssistitoPath parsedPath = _parseAssistitoPath(path);
    _validateAssistitoPayload(
      path: parsedPath.canonicalPath,
      assistitoId: parsedPath.assistitoId,
      data: data,
    );

    _reserveWriteSlot(parsedPath.canonicalPath);

    await firestore.doc(parsedPath.canonicalPath).set(
          Map<String, dynamic>.unmodifiable(data),
        );
    _writesCommitted += 1;
  }

  @override
  Future<void> patchDocument({
    required String path,
    required Map<String, dynamic> data,
  }) {
    throw TargetAssistitiFirestoreCopyRejectedException(
      code: 'patch_not_allowed',
      message: 'La copia reale limitata assistiti consente solo set documentale completo.',
      path: path,
    );
  }

  void _reserveWriteSlot(String path) {
    if (_writesReserved >= maxWritesPerInstance) {
      throw TargetAssistitiFirestoreCopyRejectedException(
        code: 'max_writes_per_instance_reached',
        message: 'Limite hard di copie target assistiti raggiunto per questa istanza sink.',
        path: path,
      );
    }
    _writesReserved += 1;
  }

  static _TargetAssistitoPath _parseAssistitoPath(String path) {
    final String normalizedPath = path.trim();
    if (path != normalizedPath) {
      throw TargetAssistitiFirestoreCopyRejectedException(
        code: 'path_not_canonical',
        message: 'Path non canonico: spazi iniziali/finali non ammessi.',
        path: path,
      );
    }

    final List<String> segments = normalizedPath.split('/');
    if (normalizedPath.isEmpty ||
        segments.length != 4 ||
        segments.any((String segment) => segment.isEmpty || segment != segment.trim()) ||
        segments[0] != TargetMultitenantCollections.tenants ||
        segments[2] != TargetMultitenantCollections.assistiti) {
      throw TargetAssistitiFirestoreCopyRejectedException(
        code: 'path_not_target_assistito_document',
        message: 'Path non ammesso per copia target assistiti.',
        path: path,
      );
    }

    return _TargetAssistitoPath(
      canonicalPath: normalizedPath,
      assistitoId: segments[3],
    );
  }

  static void _validateAssistitoPayload({
    required String path,
    required String assistitoId,
    required Map<String, dynamic> data,
  }) {
    if (data.isEmpty) {
      throw TargetAssistitiFirestoreCopyRejectedException(
        code: 'empty_payload',
        message: 'Payload assistito target vuoto non copiabile.',
        path: path,
      );
    }

    final String payloadAssistitoId = _readString(data['assistitoId']);
    if (payloadAssistitoId.isEmpty || payloadAssistitoId != assistitoId) {
      throw TargetAssistitiFirestoreCopyRejectedException(
        code: 'assistito_id_mismatch',
        message: 'assistitoId payload assente o diverso dal documentId target.',
        path: path,
      );
    }

    if (data.containsKey('fiscalCode')) {
      throw TargetAssistitiFirestoreCopyRejectedException(
        code: 'legacy_fiscal_code_field_not_allowed',
        message: 'Il target assistiti deve usare cf, non fiscalCode.',
        path: path,
      );
    }

    _rejectMissingRootField(path: path, data: data, field: 'nome');
    _rejectMissingRootField(path: path, data: data, field: 'cognome');
    _rejectMissingRootField(path: path, data: data, field: 'fullName');
    _rejectMissingRootField(path: path, data: data, field: 'nameSplitConfidence');
    _rejectMissingRootField(path: path, data: data, field: 'searchPrefixes');

    final String cf = _readString(data['cf']);
    if (cf.isNotEmpty && cf != cf.toUpperCase()) {
      throw TargetAssistitiFirestoreCopyRejectedException(
        code: 'cf_not_uppercase',
        message: 'Il campo cf deve essere normalizzato in maiuscolo.',
        path: path,
      );
    }

    _rejectCfContamination(
      path: path,
      cf: cf,
      field: 'nome',
      value: data['nome'],
    );
    _rejectCfContamination(
      path: path,
      cf: cf,
      field: 'cognome',
      value: data['cognome'],
    );
    _rejectCfContamination(
      path: path,
      cf: cf,
      field: 'fullName',
      value: data['fullName'],
    );
    _rejectSearchPrefixContamination(
      path: path,
      cf: cf,
      hasSearchPrefixes: data.containsKey('searchPrefixes'),
      value: data['searchPrefixes'],
    );
    _rejectDoctorIdentityContamination(
      path: path,
      hasDoctor: data.containsKey('doctor'),
      value: data['doctor'],
    );
  }

  static void _rejectMissingRootField({
    required String path,
    required Map<String, dynamic> data,
    required String field,
  }) {
    if (!data.containsKey(field)) {
      throw TargetAssistitiFirestoreCopyRejectedException(
        code: '${_normalizeMapKey(field)}_missing',
        message: 'Il payload assistito target deve contenere il campo root $field.',
        path: path,
      );
    }
  }

  static void _rejectCfContamination({
    required String path,
    required String cf,
    required String field,
    required Object? value,
  }) {
    final String normalized = _readString(value);
    if (normalized.isEmpty) {
      return;
    }
    if (_isFiscalCodeLike(normalized) ||
        _containsCf(normalized, cf) ||
        _containsFiscalCodeLikeToken(normalized)) {
      throw TargetAssistitiFirestoreCopyRejectedException(
        code: 'cf_contaminates_$field',
        message: 'Il codice fiscale non può contaminare $field.',
        path: path,
      );
    }
  }

  static void _rejectSearchPrefixContamination({
    required String path,
    required String cf,
    required bool hasSearchPrefixes,
    required Object? value,
  }) {
    if (!hasSearchPrefixes) {
      return;
    }
    if (value is! Iterable) {
      throw TargetAssistitiFirestoreCopyRejectedException(
        code: 'search_prefixes_not_iterable',
        message: 'searchPrefixes deve essere un array di stringhe.',
        path: path,
      );
    }
    for (final Object? item in value) {
      if (item is! String) {
        throw TargetAssistitiFirestoreCopyRejectedException(
          code: 'search_prefixes_item_not_string',
          message: 'Ogni elemento di searchPrefixes deve essere una stringa.',
          path: path,
        );
      }
      final String prefix = _readString(item);
      if (prefix.isEmpty) {
        continue;
      }
      if (_isFiscalCodeLike(prefix) ||
          _containsCf(prefix, cf) ||
          _containsFiscalCodeLikeToken(prefix)) {
        throw TargetAssistitiFirestoreCopyRejectedException(
          code: 'cf_contaminates_search_prefixes',
          message: 'Il codice fiscale non può contaminare searchPrefixes.',
          path: path,
        );
      }
    }
  }

  static void _rejectDoctorIdentityContamination({
    required String path,
    required bool hasDoctor,
    required Object? value,
  }) {
    if (!hasDoctor || value == null) {
      return;
    }
    if (value is! Map) {
      throw TargetAssistitiFirestoreCopyRejectedException(
        code: 'doctor_not_map',
        message: 'doctor deve essere una map semantica medico-assistito, non un valore scalare.',
        path: path,
      );
    }

    _validateDoctorMap(path: path, value: value, depth: 0);
  }

  static void _validateDoctorMap({
    required String path,
    required Map<dynamic, dynamic> value,
    required int depth,
  }) {
    if (depth > 4) {
      throw TargetAssistitiFirestoreCopyRejectedException(
        code: 'doctor_nesting_too_deep',
        message: 'doctor contiene una struttura annidata non ammessa.',
        path: path,
      );
    }

    for (final MapEntry<dynamic, dynamic> entry in value.entries) {
      final String normalizedKey = _normalizeMapKey(entry.key);
      if (_doctorIdentityKeys.contains(normalizedKey)) {
        throw TargetAssistitiFirestoreCopyRejectedException(
          code: 'doctor_identity_contamination',
          message: 'doctor non può contenere campi identità assistito: $normalizedKey.',
          path: path,
        );
      }
      if (_doctorUnsupportedKeys.contains(normalizedKey)) {
        throw TargetAssistitiFirestoreCopyRejectedException(
          code: 'doctor_unsupported_field',
          message: 'doctor contiene un campo non ammesso: $normalizedKey.',
          path: path,
        );
      }

      final Object? item = entry.value;
      if (item is Map) {
        _validateDoctorMap(path: path, value: item, depth: depth + 1);
      }
      if (item is Iterable) {
        _validateDoctorIterable(path: path, value: item, depth: depth + 1);
      }
    }
  }

  static void _validateDoctorIterable({
    required String path,
    required Iterable<dynamic> value,
    required int depth,
  }) {
    if (depth > 4) {
      throw TargetAssistitiFirestoreCopyRejectedException(
        code: 'doctor_nesting_too_deep',
        message: 'doctor contiene una struttura annidata non ammessa.',
        path: path,
      );
    }

    for (final Object? item in value) {
      if (item is Map) {
        _validateDoctorMap(path: path, value: item, depth: depth + 1);
      }
      if (item is Iterable) {
        _validateDoctorIterable(path: path, value: item, depth: depth + 1);
      }
    }
  }

  static final Set<String> _doctorIdentityKeys = <String>{
    'assistitoid',
    'cf',
    'codicefiscale',
    'cognome',
    'familyname',
    'fiscalcode',
    'fullname',
    'givenname',
    'lastname',
    'name',
    'namesplitconfidence',
    'nome',
    'patientname',
    'searchprefixes',
    'surname',
  };

  static final Set<String> _doctorUnsupportedKeys = <String>{
    'ambulatorio',
  };

  static String _normalizeMapKey(Object? key) {
    return key
        .toString()
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .trim()
        .toLowerCase();
  }

  static bool _containsCf(String value, String cf) {
    if (cf.trim().isEmpty) {
      return false;
    }
    return value.toUpperCase().contains(cf.toUpperCase());
  }

  static bool _isFiscalCodeLike(String value) {
    return RegExp(r'^[A-Z]{6}[0-9]{2}[A-Z][0-9]{2}[A-Z][0-9]{3}[A-Z]$')
        .hasMatch(value.replaceAll(RegExp(r'\s+'), '').trim().toUpperCase());
  }

  static bool _containsFiscalCodeLikeToken(String value) {
    final Iterable<RegExpMatch> matches = RegExp(r'[A-Z0-9]{16}')
        .allMatches(value.toUpperCase());
    for (final RegExpMatch match in matches) {
      final String token = match.group(0) ?? '';
      if (_isFiscalCodeLike(token)) {
        return true;
      }
    }
    return false;
  }

  static String _readString(Object? value) {
    return value?.toString().trim() ?? '';
  }
}

class _TargetAssistitoPath {
  final String canonicalPath;
  final String assistitoId;

  const _TargetAssistitoPath({
    required this.canonicalPath,
    required this.assistitoId,
  });
}
