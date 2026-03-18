import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthPrepResult {
  final String email;
  final String? displayName;
  final String? accessToken;
  final bool isConnected;

  const GoogleAuthPrepResult({
    required this.email,
    required this.displayName,
    required this.accessToken,
    required this.isConnected,
  });
}

class GoogleAuthPrepService {
  static const List<String> basicScopes = <String>[
    'email',
    'openid',
    'profile',
  ];

  static const String driveScope = 'https://www.googleapis.com/auth/drive';
  static const String gmailModifyScope = 'https://www.googleapis.com/auth/gmail.modify';

  static const List<String> driveScopes = <String>[
    driveScope,
  ];

  static const List<String> gmailScopes = <String>[
    gmailModifyScope,
  ];

  static const List<String> driveAndGmailScopes = <String>[
    driveScope,
    gmailModifyScope,
  ];

  List<String> get _fullScopes => <String>[
    ...basicScopes,
    ...driveAndGmailScopes,
  ];

  GoogleSignIn? _cachedSignIn;
  String _cachedClientId = '';

  GoogleSignIn getSignInInstance({required String clientId}) => _buildOrReuseSignIn(clientId);

  void prime({required String clientId}) {
    if (clientId.trim().isEmpty) return;
    _buildOrReuseSignIn(clientId);
  }

  GoogleSignIn _buildOrReuseSignIn(String clientId) {
    final String normalizedClientId = clientId.trim();
    if (_cachedSignIn != null && _cachedClientId == normalizedClientId) {
      return _cachedSignIn!;
    }

    _cachedClientId = normalizedClientId;
    _cachedSignIn = GoogleSignIn(
      clientId: normalizedClientId,
      scopes: _fullScopes,
    );
    return _cachedSignIn!;
  }

  Future<GoogleSignInAccount?> _getSignedAccount({
    required GoogleSignIn googleSignIn,
    required bool interactive,
  }) async {
    GoogleSignInAccount? account = googleSignIn.currentUser;
    account ??= await googleSignIn.signInSilently();

    if (account == null && interactive && !kIsWeb) {
      account = await googleSignIn.signIn();
    }

    return account;
  }

  String? _tokenFromAuthHeaders(Map<String, String> headers) {
    final String authorization = headers['Authorization'] ?? headers['authorization'] ?? '';
    if (!authorization.toLowerCase().startsWith('bearer ')) {
      return null;
    }
    final String token = authorization.substring(7).trim();
    return token.isEmpty ? null : token;
  }

  Future<Map<String, String>> getAuthHeaders({
    required String clientId,
    bool interactive = false,
  }) async {
    if (clientId.trim().isEmpty) {
      throw Exception('Inserisci prima il Web Client ID Google nelle impostazioni.');
    }

    final GoogleSignIn googleSignIn = _buildOrReuseSignIn(clientId);
    final GoogleSignInAccount? account = await _getSignedAccount(
      googleSignIn: googleSignIn,
      interactive: interactive,
    );

    if (account == null) {
      throw Exception(
        interactive
            ? 'Login Google annullato.'
            : 'Sessione Google assente o scaduta. Su web usa il pulsante ufficiale Google e poi premi Verifica sessione.',
      );
    }

    final Map<String, String> authHeaders = await account.authHeaders;
    final String? token = _tokenFromAuthHeaders(authHeaders);
    if (token == null) {
      throw Exception("Token Google non disponibile. Su web autentica di nuovo l'account Google e poi ripeti la scansione.");
    }

    return <String, String>{
      ...authHeaders,
      'Authorization': 'Bearer $token',
    };
  }

  Future<GoogleAuthPrepResult> signInForGoogleAccount({
    required String clientId,
  }) async {
    final GoogleSignIn googleSignIn = _buildOrReuseSignIn(clientId);
    final GoogleSignInAccount? account = googleSignIn.currentUser ?? await googleSignIn.signInSilently();

    if (account == null) {
      if (kIsWeb) {
        throw Exception('Su web usa il pulsante ufficiale Google qui sotto, poi premi Verifica sessione.');
      }
      throw Exception('Login Google annullato.');
    }

    final Map<String, String> headers = await getAuthHeaders(
      clientId: clientId,
      interactive: !kIsWeb,
    );

    return GoogleAuthPrepResult(
      email: account.email,
      displayName: account.displayName,
      accessToken: _tokenFromAuthHeaders(headers),
      isConnected: true,
    );
  }

  Future<GoogleAuthPrepResult?> tryRestoreSession({
    required String clientId,
  }) async {
    if (clientId.trim().isEmpty) return null;

    try {
      final Map<String, String> headers = await getAuthHeaders(
        clientId: clientId,
        interactive: false,
      );
      final GoogleSignIn googleSignIn = _buildOrReuseSignIn(clientId);
      final GoogleSignInAccount? account = googleSignIn.currentUser ?? await googleSignIn.signInSilently();
      if (account == null) return null;

      return GoogleAuthPrepResult(
        email: account.email,
        displayName: account.displayName,
        accessToken: _tokenFromAuthHeaders(headers),
        isConnected: true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _ensureScopes({
    required GoogleSignIn googleSignIn,
    required GoogleSignInAccount account,
    required List<String> scopes,
    required bool interactive,
  }) async {
    if (scopes.isEmpty) return;

    if (kIsWeb) {
      bool canAccess = false;
      try {
        canAccess = await googleSignIn.canAccessScopes(scopes);
      } on UnimplementedError {
        canAccess = true;
      }

      if (!canAccess) {
        if (!interactive) {
          throw Exception('Permessi Google Drive/Gmail non ancora concessi. Premi il pulsante della scansione per autorizzarli.');
        }

        final bool granted = await googleSignIn.requestScopes(scopes);
        if (!granted) {
          throw Exception('Permessi Google Drive/Gmail non concessi.');
        }
      }
      return;
    }
  }

  Future<GoogleAuthPrepResult?> ensureAuthorizedSession({
    required String clientId,
    required List<String> scopes,
    bool interactive = false,
  }) async {
    if (clientId.trim().isEmpty) return null;

    final GoogleSignIn googleSignIn = _buildOrReuseSignIn(clientId);
    final GoogleSignInAccount? account = await _getSignedAccount(
      googleSignIn: googleSignIn,
      interactive: interactive,
    );
    if (account == null) return null;

    await _ensureScopes(
      googleSignIn: googleSignIn,
      account: account,
      scopes: scopes,
      interactive: interactive,
    );

    final Map<String, String> headers = await getAuthHeaders(
      clientId: clientId,
      interactive: false,
    );

    return GoogleAuthPrepResult(
      email: account.email,
      displayName: account.displayName,
      accessToken: _tokenFromAuthHeaders(headers),
      isConnected: true,
    );
  }

  Future<GoogleAuthPrepResult?> ensureDriveSession({
    required String clientId,
    bool interactive = false,
  }) async {
    return ensureAuthorizedSession(
      clientId: clientId,
      scopes: driveScopes,
      interactive: interactive,
    );
  }

  Future<GoogleAuthPrepResult?> ensureDriveAndGmailSession({
    required String clientId,
    bool interactive = false,
  }) async {
    return ensureAuthorizedSession(
      clientId: clientId,
      scopes: driveAndGmailScopes,
      interactive: interactive,
    );
  }

  Future<void> signOut({
    required String clientId,
  }) async {
    if (clientId.trim().isEmpty) return;
    final GoogleSignIn googleSignIn = _buildOrReuseSignIn(clientId);
    try {
      await googleSignIn.disconnect();
    } catch (_) {
      await googleSignIn.signOut();
    }
  }
}
