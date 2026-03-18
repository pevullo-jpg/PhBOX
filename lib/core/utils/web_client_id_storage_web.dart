
import 'dart:html' as html;

const String _storageKey = 'phbox_google_client_id';

String loadSavedGoogleWebClientId() => html.window.localStorage[_storageKey] ?? '';

Future<void> saveGoogleWebClientId(String clientId) async {
  final String trimmed = clientId.trim();
  if (trimmed.isEmpty) {
    html.window.localStorage.remove(_storageKey);
  } else {
    html.window.localStorage[_storageKey] = trimmed;
  }
}
