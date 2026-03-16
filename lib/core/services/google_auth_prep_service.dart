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

    if (account == null && interactive) {
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
            : 'Sessione Google assente o scaduta. Premi Collega account Google.',
      );
    }

    final Map<String, String> authHeaders = await account.authHeaders;
    final String? token = _tokenFromAuthHeaders(authHeaders);
    if (token == null) {
      throw Exception('Token Google non disponibile. Ricollega l'account Google.');
    }

    return <String, String>{
      ...authHeaders,
      'Authorization': 'Bearer $token',
    };
  }

  Future<GoogleAuthPrepResult> signInForGoogleAccount({
    required String clientId,
  }) async {
    final Map<String, String> headers = await getAuthHeaders(
      clientId: clientId,
      interactive: true,
    );

    final GoogleSignIn googleSignIn = _buildOrReuseSignIn(clientId);
    final GoogleSignInAccount? account = googleSignIn.currentUser ?? await googleSignIn.signInSilently();

    if (account == null) {
      throw Exception('Login Google annullato.');
    }

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

  Future<GoogleAuthPrepResult?> ensureAuthorizedSession({
    required String clientId,
    required List<String> scopes,
    bool interactive = false,
  }) async {
    if (clientId.trim().isEmpty) return null;

    final Map<String, String> headers = await getAuthHeaders(
      clientId: clientId,
      interactive: interactive,
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
    await googleSignIn.signOut();
  }
}
