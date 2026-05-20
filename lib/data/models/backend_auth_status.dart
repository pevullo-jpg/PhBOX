class BackendAuthStatus {
  final bool ok;
  final bool authRequired;
  final String status;
  final String message;
  final String errorKind;
  final String authUrl;
  final String expectedEmail;
  final String executingEmail;
  final DateTime? checkedAt;

  const BackendAuthStatus({
    required this.ok,
    required this.authRequired,
    required this.status,
    required this.message,
    required this.errorKind,
    required this.authUrl,
    required this.expectedEmail,
    required this.executingEmail,
    required this.checkedAt,
  });

  bool get shouldShowBanner {
    if (ok && status == 'ok' && !authRequired) {
      return false;
    }
    return status == 'auth_required' ||
        status == 'config_required' ||
        status == 'wrong_account' ||
        status == 'trigger_required' ||
        status == 'error' ||
        authRequired;
  }

  String get title {
    switch (status) {
      case 'auth_required':
        return 'Backend PhBOX da autorizzare';
      case 'config_required':
        return 'Configurazione backend incompleta';
      case 'wrong_account':
        return 'Account Google backend non corretto';
      case 'trigger_required':
        return 'Trigger backend da verificare';
      case 'error':
        return 'Backend PhBOX da verificare';
      default:
        return 'Backend PhBOX non operativo';
    }
  }

  String get actionLabel {
    switch (status) {
      case 'auth_required':
        return 'Autorizza backend';
      case 'config_required':
        return 'Apri centro backend';
      case 'wrong_account':
        return 'Controlla account';
      case 'trigger_required':
        return 'Ripara trigger';
      default:
        return 'Apri centro backend';
    }
  }

  String get effectiveMessage {
    final String trimmed = message.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    switch (status) {
      case 'auth_required':
        return 'Gmail, Drive o Apps Script richiedono una nuova autorizzazione.';
      case 'config_required':
        return 'Completa le impostazioni backend prima di riprovare.';
      case 'wrong_account':
        return 'Apri il centro backend con l’account Google operativo corretto.';
      case 'trigger_required':
        return 'Il trigger del backend deve essere verificato o riparato.';
      default:
        return 'Apri il centro backend e verifica lo stato.';
    }
  }

  factory BackendAuthStatus.emptyOk() {
    return const BackendAuthStatus(
      ok: true,
      authRequired: false,
      status: 'ok',
      message: '',
      errorKind: '',
      authUrl: '',
      expectedEmail: '',
      executingEmail: '',
      checkedAt: null,
    );
  }

  factory BackendAuthStatus.fromRuntimeMap(Map<String, dynamic> map) {
    final Map<String, dynamic> nestedAuth = _readMap(map['auth']);
    final String status = _readString(
      map['backendAuthStatus'],
      fallback: _readString(nestedAuth['status'], fallback: ''),
    );
    final String normalizedStatus = status.trim().isEmpty ? 'ok' : status.trim();
    final bool authRequired = _readBool(
      map['backendAuthRequired'],
      fallback: _readBool(nestedAuth['authRequired'], fallback: false),
    );
    final bool ok = _readBool(
      map['backendAuthOk'],
      fallback: _readBool(nestedAuth['ok'], fallback: normalizedStatus == 'ok' && !authRequired),
    );

    return BackendAuthStatus(
      ok: ok,
      authRequired: authRequired,
      status: normalizedStatus,
      message: _readString(
        map['backendAuthErrorMessage'],
        fallback: _readString(nestedAuth['message'], fallback: ''),
      ),
      errorKind: _readString(
        map['backendAuthErrorKind'],
        fallback: _readString(nestedAuth['errorKind'], fallback: ''),
      ),
      authUrl: _readString(
        map['backendAuthUrl'],
        fallback: _readString(nestedAuth['authUrl'], fallback: ''),
      ),
      expectedEmail: _readString(
        map['backendOperationalAccountEmail'],
        fallback: _readString(nestedAuth['expectedEmail'], fallback: ''),
      ),
      executingEmail: _readString(
        map['backendExecutingAccountEmail'],
        fallback: _readString(nestedAuth['executingEmail'], fallback: ''),
      ),
      checkedAt: _readDate(
        map['backendAuthLastCheckAt'] ?? nestedAuth['checkedAt'],
      ),
    );
  }

  static Map<String, dynamic> _readMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((dynamic key, dynamic item) => MapEntry<String, dynamic>(key.toString(), item));
    }
    return const <String, dynamic>{};
  }

  static String _readString(dynamic value, {required String fallback}) {
    final String trimmed = value?.toString().trim() ?? '';
    return trimmed.isEmpty ? fallback : trimmed;
  }

  static bool _readBool(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    final String text = value?.toString().trim().toLowerCase() ?? '';
    if (text == 'true') return true;
    if (text == 'false') return false;
    return fallback;
  }

  static DateTime? _readDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    try {
      final dynamic date = (value as dynamic).toDate();
      if (date is DateTime) return date;
    } catch (_) {}
    try {
      final dynamic seconds = (value as dynamic).seconds;
      if (seconds is int) {
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    } catch (_) {}
    return null;
  }
}
