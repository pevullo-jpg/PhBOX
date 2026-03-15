import 'package:google_sign_in/google_sign_in.dart';

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
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      'email',
      'https://www.googleapis.com/auth/drive.readonly',
    ],
  );

  Future<GoogleAuthPrepResult> signInForDriveRead() async {
    final GoogleSignInAccount? account = await _googleSignIn.signIn();

    if (account == null) {
      throw Exception('Login Google annullato.');
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
