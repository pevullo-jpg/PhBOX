import 'dart:html' as html;

const Duration pendingPdfDeleteTtl = Duration(hours: 24);
const String _storageKey = 'phbox_pending_pdf_deletes_v1';

String loadPendingPdfDeletePayload() => html.window.localStorage[_storageKey] ?? '';

Future<void> savePendingPdfDeletePayload(String payload) async {
  final String trimmed = payload.trim();
  if (trimmed.isEmpty) {
    html.window.localStorage.remove(_storageKey);
  } else {
    html.window.localStorage[_storageKey] = trimmed;
  }
}
