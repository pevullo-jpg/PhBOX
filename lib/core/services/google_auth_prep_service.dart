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

  GoogleSignIn _buildSignIn(String clientId) {
    return GoogleSignIn(
      clientId: clientId,
      scopes: _fullScopes,
    );
  }

  Future<GoogleAuthPrepResult> signInForGoogleAccount({
    required String clientId,
  }) async {
    if (clientId.trim().isEmpty) {
      throw Exception('Inserisci prima il Web Client ID Google nelle impostazioni.');
    }

    final GoogleSignIn googleSignIn = _buildSignIn(clientId.trim());
    final GoogleSignInAccount? account = await googleSignIn.signIn();

    if (account == null) {
      throw Exception('Login Google annullato.');
    }

    final GoogleSignInAuthentication auth = await account.authentication;

    return GoogleAuthPrepResult(
      email: account.email,
      displayName: account.displayName,
      accessToken: auth.accessToken,
      isConnected: true,
    );
  }

  Future<GoogleAuthPrepResult?> tryRestoreSession({
    required String clientId,
  }) async {
    if (clientId.trim().isEmpty) return null;

    final GoogleSignIn googleSignIn = _buildSignIn(clientId.trim());
    final GoogleSignInAccount? account = await googleSignIn.signInSilently();

    if (account == null) return null;

    final GoogleSignInAuthentication auth = await account.authentication;

    return GoogleAuthPrepResult(
      email: account.email,
      displayName: account.displayName,
      accessToken: auth.accessToken,
      isConnected: true,
    );
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

  Future<bool> _canAccessScopes(
    GoogleSignIn googleSignIn,
    List<String> scopes,
  ) async {
    try {
      return await googleSignIn.canAccessScopes(scopes);
    } catch (_) {
      return true;
    }
  }

  Future<GoogleAuthPrepResult?> ensureAuthorizedSession({
    required String clientId,
    required List<String> scopes,
    bool interactive = false,
  }) async {
    if (clientId.trim().isEmpty) return null;

    final GoogleSignIn googleSignIn = _buildSignIn(clientId.trim());
    GoogleSignInAccount? account = googleSignIn.currentUser;
    account ??= await googleSignIn.signInSilently();

    if (account == null && interactive) {
      account = await googleSignIn.signIn();
    }

    if (account == null) {
      return null;
    }

    final GoogleSignInAuthentication auth = await account.authentication;

    return GoogleAuthPrepResult(
      email: account.email,
      displayName: account.displayName,
      accessToken: auth.accessToken,
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
    final GoogleSignIn googleSignIn = _buildSignIn(clientId.trim());
    await googleSignIn.signOut();
  }
}
