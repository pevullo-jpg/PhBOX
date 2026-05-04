import 'dart:convert';
import 'dart:html' as html;

import 'pending_pdf_delete_storage.dart';

const String _storageKey = 'phbox_pending_pdf_delete_v1';

Future<void> upsertEntry(PendingPdfDeleteEntry entry) async {
  final List<PendingPdfDeleteEntry> entries = await loadEntries();
  final Map<String, PendingPdfDeleteEntry> byId = <String, PendingPdfDeleteEntry>{
    for (final PendingPdfDeleteEntry current in entries) current.importId: current,
  };
  byId[entry.importId] = entry;
  await replaceEntries(byId.values.toList());
}

Future<List<PendingPdfDeleteEntry>> loadEntries() async {
  final String raw = html.window.localStorage[_storageKey] ?? '';
  if (raw.isEmpty) return const <PendingPdfDeleteEntry>[];
  try {
    final dynamic parsed = jsonDecode(raw);
    if (parsed is! List) return const <PendingPdfDeleteEntry>[];
    return parsed
        .whereType<Map>()
        .map((Map item) {
          final String importId = (item['importId'] ?? '').toString().trim();
          final String fiscalCode = (item['fiscalCode'] ?? '').toString().trim().toUpperCase();
          final DateTime? requestedAt = DateTime.tryParse((item['requestedAt'] ?? '').toString());
          if (importId.isEmpty || fiscalCode.isEmpty || requestedAt == null) {
            return null;
          }
          return PendingPdfDeleteEntry(importId: importId, fiscalCode: fiscalCode, requestedAt: requestedAt);
        })
        .whereType<PendingPdfDeleteEntry>()
        .toList();
  } catch (_) {
    return const <PendingPdfDeleteEntry>[];
  }
}

Future<void> replaceEntries(List<PendingPdfDeleteEntry> entries) async {
  if (entries.isEmpty) {
    html.window.localStorage.remove(_storageKey);
    return;
  }
  html.window.localStorage[_storageKey] = jsonEncode(entries.map((e) => {
    'importId': e.importId,
    'fiscalCode': e.fiscalCode,
    'requestedAt': e.requestedAt.toUtc().toIso8601String(),
  }).toList());
}

Future<void> removeByImportIds(Set<String> importIds) async {
  if (importIds.isEmpty) return;
  final List<PendingPdfDeleteEntry> entries = await loadEntries();
  await replaceEntries(entries.where((e) => !importIds.contains(e.importId)).toList());
}
