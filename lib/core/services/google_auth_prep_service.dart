import 'package:google_sign_in/google_sign_in.dart';
import '../constants/google_oauth_config.dart';

class GoogleAuthPrepResult {
  final String email;
  final String? displayName;
  final String? accessToken;

  const GoogleAuthPrepResult({
    required this.email,
    required this.displayName,
    required this.accessToken,
  });
}

class GoogleAuthPrepService {
  static const List<String> _scopes = <String>[
    'email',
    'https://www.googleapis.com/auth/drive.readonly',
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kGoogleWebClientId,
    scopes: _scopes,
  );

  Future<GoogleAuthPrepResult> signInForDriveRead() async {
    if (kGoogleWebClientId.contains('INSERISCI_QUI_IL_CLIENT_ID_WEB')) {
      throw Exception(
        'Client ID Google Web mancante. Compila lib/core/constants/google_oauth_config.dart',
      );
    }

    final GoogleSignInAccount? account = await _googleSignIn.signIn();

    if (account == null) {
      throw Exception('Login Google annullato.');
    }

    final bool scopesGranted = await _googleSignIn.requestScopes(_scopes);

    if (!scopesGranted) {
      throw Exception('Permessi Drive non concessi.');
    }

    final GoogleSignInAuthentication auth = await account.authentication;

    return GoogleAuthPrepResult(
      email: account.email,
      displayName: account.displayName,
      accessToken: auth.accessToken,
    );
  }

  Future<void> signOut() {
    return _googleSignIn.signOut();
  }
}
