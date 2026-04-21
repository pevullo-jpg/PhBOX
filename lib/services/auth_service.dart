import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:family_boxes_2/config/firebase_backend_config.dart';
import 'package:family_boxes_2/models/auth_user.dart';

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

class BackendConfigException extends AuthException {
  const BackendConfigException()
      : super('Backend Firebase non configurato. Inserisci apiKey e projectId in lib/config/firebase_backend_config.dart');
}

class AuthService {
  static const String _sessionKey = 'firebase_rest_auth_session_v1';
  static const Duration _refreshTolerance = Duration(minutes: 5);

  static bool get isBackendConfigured => FirebaseBackendConfig.isConfigured;

  static Future<AuthUser?> currentUser() async {
    if (!isBackendConfigured) return null;
    final session = await _loadSession();
    if (session == null) return null;

    try {
      final fresh = await _ensureFreshSession(session);
      await _saveSession(fresh);
      return fresh.user;
    } catch (_) {
      await signOut();
      return null;
    }
  }

  static Future<AuthUser> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _assertConfigured();
    final normalizedEmail = _normalizeEmail(email);
    final cleanPassword = password.trim();
    final cleanDisplayName = displayName.trim();

    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw const AuthException('Email non valida.');
    }
    if (cleanPassword.length < 6) {
      throw const AuthException('Password troppo corta. Minimo 6 caratteri.');
    }
    if (cleanDisplayName.isEmpty) {
      throw const AuthException('Inserisci un nome visualizzato.');
    }

    final signupUri = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${FirebaseBackendConfig.apiKey}',
    );

    final signupRes = await http
        .post(
          signupUri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': normalizedEmail,
            'password': cleanPassword,
            'returnSecureToken': true,
          }),
        )
        .timeout(const Duration(seconds: 20));

    final signupJson = _decodeJson(signupRes.body);
    _throwIfFirebaseError(signupJson);

    final initialUser = AuthUser(
      uid: (signupJson['localId'] ?? '').toString(),
      email: (signupJson['email'] ?? normalizedEmail).toString(),
      displayName: cleanDisplayName,
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );

    final namedSession = await _applyDisplayName(
      _RemoteSession(
        user: initialUser,
        idToken: (signupJson['idToken'] ?? '').toString(),
        refreshToken: (signupJson['refreshToken'] ?? '').toString(),
        expiresAt: DateTime.now().add(
          Duration(seconds: int.tryParse((signupJson['expiresIn'] ?? '3600').toString()) ?? 3600),
        ),
      ),
      cleanDisplayName,
    );

    final updatedSession = await _lookupUser(namedSession);
    await _saveSession(updatedSession);
    return updatedSession.user;
  }

  static Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    _assertConfigured();
    final normalizedEmail = _normalizeEmail(email);

    final signInUri = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FirebaseBackendConfig.apiKey}',
    );

    final signInRes = await http
        .post(
          signInUri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': normalizedEmail,
            'password': password,
            'returnSecureToken': true,
          }),
        )
        .timeout(const Duration(seconds: 20));

    final signInJson = _decodeJson(signInRes.body);
    _throwIfFirebaseError(signInJson);

    final baseSession = _RemoteSession(
      user: AuthUser(
        uid: (signInJson['localId'] ?? '').toString(),
        email: (signInJson['email'] ?? normalizedEmail).toString(),
        displayName: '',
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      ),
      idToken: (signInJson['idToken'] ?? '').toString(),
      refreshToken: (signInJson['refreshToken'] ?? '').toString(),
      expiresAt: DateTime.now().add(
        Duration(seconds: int.tryParse((signInJson['expiresIn'] ?? '3600').toString()) ?? 3600),
      ),
    );

    final hydrated = await _lookupUser(baseSession);
    await _saveSession(hydrated);
    return hydrated.user;
  }

  static Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  static Future<String?> currentIdToken() async {
    if (!isBackendConfigured) return null;
    final session = await _loadSession();
    if (session == null) return null;
    final fresh = await _ensureFreshSession(session);
    await _saveSession(fresh);
    return fresh.idToken;
  }

  static Future<AuthUser?> currentUserFresh() async {
    return currentUser();
  }

  static void _assertConfigured() {
    if (!isBackendConfigured) {
      throw const BackendConfigException();
    }
  }

  static Future<_RemoteSession?> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return _RemoteSession.fromJson(decoded);
      }
      if (decoded is Map) {
        return _RemoteSession.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return null;
  }

  static Future<void> _saveSession(_RemoteSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  static Future<_RemoteSession> _ensureFreshSession(_RemoteSession session) async {
    final now = DateTime.now();
    if (session.idToken.isNotEmpty && session.expiresAt.isAfter(now.add(_refreshTolerance))) {
      return session;
    }

    final refreshUri = Uri.parse(
      'https://securetoken.googleapis.com/v1/token?key=${FirebaseBackendConfig.apiKey}',
    );

    final refreshRes = await http
        .post(
          refreshUri,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'grant_type': 'refresh_token',
            'refresh_token': session.refreshToken,
          },
        )
        .timeout(const Duration(seconds: 20));

    final refreshJson = _decodeJson(refreshRes.body);
    _throwIfFirebaseError(refreshJson);

    final refreshed = session.copyWith(
      idToken: (refreshJson['id_token'] ?? '').toString(),
      refreshToken: (refreshJson['refresh_token'] ?? session.refreshToken).toString(),
      expiresAt: DateTime.now().add(
        Duration(seconds: int.tryParse((refreshJson['expires_in'] ?? '3600').toString()) ?? 3600),
      ),
      user: session.user.copyWith(lastLoginAt: DateTime.now()),
    );

    return _lookupUser(refreshed);
  }

  static Future<_RemoteSession> _applyDisplayName(_RemoteSession session, String displayName) async {
    final uri = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:update?key=${FirebaseBackendConfig.apiKey}',
    );

    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'idToken': session.idToken,
            'displayName': displayName,
            'returnSecureToken': false,
          }),
        )
        .timeout(const Duration(seconds: 20));

    final json = _decodeJson(res.body);
    _throwIfFirebaseError(json);

    return session.copyWith(
      user: session.user.copyWith(displayName: (json['displayName'] ?? displayName).toString()),
    );
  }

  static Future<_RemoteSession> _lookupUser(_RemoteSession session) async {
    final uri = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${FirebaseBackendConfig.apiKey}',
    );

    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'idToken': session.idToken}),
        )
        .timeout(const Duration(seconds: 20));

    final json = _decodeJson(res.body);
    _throwIfFirebaseError(json);

    final users = json['users'];
    if (users is List && users.isNotEmpty && users.first is Map) {
      final raw = Map<String, dynamic>.from(users.first as Map);
      final createdAtMs = int.tryParse((raw['createdAt'] ?? '').toString());
      final lastLoginMs = int.tryParse((raw['lastLoginAt'] ?? '').toString());
      return session.copyWith(
        user: session.user.copyWith(
          uid: (raw['localId'] ?? session.user.uid).toString(),
          email: (raw['email'] ?? session.user.email).toString(),
          displayName: (raw['displayName'] ?? session.user.displayName).toString(),
          createdAt: createdAtMs == null
              ? session.user.createdAt
              : DateTime.fromMillisecondsSinceEpoch(createdAtMs),
          lastLoginAt: lastLoginMs == null
              ? DateTime.now()
              : DateTime.fromMillisecondsSinceEpoch(lastLoginMs),
        ),
      );
    }

    return session.copyWith(
      user: session.user.copyWith(lastLoginAt: DateTime.now()),
    );
  }

  static Map<String, dynamic> _decodeJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return <String, dynamic>{};
  }

  static void _throwIfFirebaseError(Map<String, dynamic> json) {
    final error = json['error'];
    if (error is! Map) return;
    final message = (error['message'] ?? '').toString();
    throw AuthException(_mapFirebaseError(message));
  }

  static String _normalizeEmail(String email) => email.trim().toLowerCase();

  static String _mapFirebaseError(String code) {
    switch (code) {
      case 'EMAIL_EXISTS':
        return 'Esiste già un account con questa email.';
      case 'INVALID_PASSWORD':
      case 'INVALID_LOGIN_CREDENTIALS':
      case 'EMAIL_NOT_FOUND':
        return 'Credenziali non valide.';
      case 'USER_DISABLED':
        return 'Account disabilitato.';
      case 'TOO_MANY_ATTEMPTS_TRY_LATER':
        return 'Troppi tentativi. Riprova più tardi.';
      case 'OPERATION_NOT_ALLOWED':
        return 'Email/password non abilitato in Firebase Authentication.';
      case 'PROJECT_NOT_FOUND':
        return 'Project ID Firebase non valido.';
      case 'API_KEY_INVALID':
      case 'INVALID_API_KEY':
        return 'API key Firebase non valida.';
      default:
        if (code.isEmpty) {
          return 'Autenticazione non riuscita.';
        }
        return 'Autenticazione non riuscita: $code';
    }
  }
}

class _RemoteSession {
  final AuthUser user;
  final String idToken;
  final String refreshToken;
  final DateTime expiresAt;

  const _RemoteSession({
    required this.user,
    required this.idToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  _RemoteSession copyWith({
    AuthUser? user,
    String? idToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) {
    return _RemoteSession(
      user: user ?? this.user,
      idToken: idToken ?? this.idToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'idToken': idToken,
      'refreshToken': refreshToken,
      'expiresAt': expiresAt.toIso8601String(),
    };
  }

  factory _RemoteSession.fromJson(Map<String, dynamic> json) {
    return _RemoteSession(
      user: AuthUser.fromJson(Map<String, dynamic>.from((json['user'] ?? <String, dynamic>{}) as Map)),
      idToken: (json['idToken'] ?? '').toString(),
      refreshToken: (json['refreshToken'] ?? '').toString(),
      expiresAt: DateTime.tryParse((json['expiresAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}
