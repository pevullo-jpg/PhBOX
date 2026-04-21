class FirebaseBackendConfig {
  // Configurazione progetto Firebase.
  static const String apiKey = 'AIzaSyBTDseGmrPsxkxC25-j9Ejgn0YT8Zni9TU';
  static const String projectId = 'family-box-2a11c';

  static bool get isConfigured =>
      apiKey != 'PASTE_FIREBASE_WEB_API_KEY' &&
      projectId != 'PASTE_FIREBASE_PROJECT_ID' &&
      apiKey.trim().isNotEmpty &&
      projectId.trim().isNotEmpty;
}
