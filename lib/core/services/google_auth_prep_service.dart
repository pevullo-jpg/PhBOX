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
  static const List<String> scopes = <String>[
    'email',
    'https://www.googleapis.com/auth/drive.readonly',
  ];

  GoogleSignIn _buildSignIn(String clientId) {
    return GoogleSignIn(
      clientId: clientId,
      scopes: scopes,
    );
  }

  Future<GoogleAuthPrepResult> signInForDriveRead({
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

    final bool scopesGranted = await googleSignIn.requestScopes(scopes);

    if (!scopesGranted) {
      throw Exception('Permessi Drive non concessi.');
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


  Future<GoogleAuthPrepResult?> ensureDriveSession({
    required String clientId,
    bool interactive = false,
  }) async {
    if (clientId.trim().isEmpty) return null;

    GoogleAuthPrepResult? result = await tryRestoreSession(
      clientId: clientId,
    );

    if (result != null && (result.accessToken?.isNotEmpty ?? false)) {
      return result;
    }

    if (!interactive) return result;

    result = await signInForDriveRead(
      clientId: clientId,
    );

    if (result.accessToken == null || result.accessToken!.isEmpty) {
      throw Exception('Sessione Google attiva ma token Drive non disponibile. Riprova il collegamento.');
    }

    return result;
  }

  Future<void> signOut({
    required String clientId,
  }) async {
    if (clientId.trim().isEmpty) return;
    final GoogleSignIn googleSignIn = _buildSignIn(clientId.trim());
    await googleSignIn.signOut();
  }
}
