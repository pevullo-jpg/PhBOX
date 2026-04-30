import 'dart:convert';

import '../models/drive_pdf_import.dart';
import 'pending_pdf_delete_storage_stub.dart'
    if (dart.library.html) 'pending_pdf_delete_storage_web.dart' as impl;

class PendingPdfDeleteEntry {
  final String importId;
  final String fiscalCode;
  final DateTime requestedAt;

  const PendingPdfDeleteEntry({
    required this.importId,
    required this.fiscalCode,
    required this.requestedAt,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
        'importId': importId,
        'fiscalCode': fiscalCode,
        'requestedAt': requestedAt.toIso8601String(),
      };

  static PendingPdfDeleteEntry? fromMap(Map<String, dynamic> map) {
    final String importId = (map['importId'] ?? '').toString().trim();
    final String fiscalCode = (map['fiscalCode'] ?? '').toString().trim().toUpperCase();
    final String rawRequestedAt = (map['requestedAt'] ?? '').toString().trim();
    final DateTime? requestedAt = DateTime.tryParse(rawRequestedAt);
    if (importId.isEmpty || fiscalCode.isEmpty || requestedAt == null) {
      return null;
    }
    return PendingPdfDeleteEntry(
      importId: importId,
      fiscalCode: fiscalCode,
      requestedAt: requestedAt,
    );
  }
}

class PendingPdfDeleteStore {
  const PendingPdfDeleteStore();

  Duration get ttl => impl.pendingPdfDeleteTtl;

  Future<void> add({
    required String importId,
    required String fiscalCode,
    DateTime? requestedAt,
  }) async {
    final String normalizedImportId = importId.trim();
    final String normalizedCf = fiscalCode.trim().toUpperCase();
    if (normalizedImportId.isEmpty || normalizedCf.isEmpty) {
      return;
    }
    final DateTime now = DateTime.now();
    final DateTime timestamp = requestedAt ?? now;
    final Map<String, PendingPdfDeleteEntry> byId = _activeById(now);
    byId[normalizedImportId] = PendingPdfDeleteEntry(
      importId: normalizedImportId,
      fiscalCode: normalizedCf,
      requestedAt: timestamp,
    );
    await _save(byId.values.toList());
  }

  Set<String> pendingIdsForFiscalCode(String fiscalCode, {DateTime? now}) {
    final String normalizedCf = fiscalCode.trim().toUpperCase();
    if (normalizedCf.isEmpty) {
      return <String>{};
    }
    return _activeEntries(now ?? DateTime.now())
        .where((PendingPdfDeleteEntry item) => item.fiscalCode == normalizedCf)
        .map((PendingPdfDeleteEntry item) => item.importId)
        .toSet();
  }

  Map<String, int> pendingCountsByFiscalCode({DateTime? now}) {
    final Map<String, int> out = <String, int>{};
    for (final PendingPdfDeleteEntry entry in _activeEntries(now ?? DateTime.now())) {
      out.update(entry.fiscalCode, (value) => value + 1, ifAbsent: () => 1);
    }
    return out;
  }

  bool isPendingImportId(String importId, {DateTime? now}) {
    final String normalizedImportId = importId.trim();
    if (normalizedImportId.isEmpty) {
      return false;
    }
    return _activeById(now ?? DateTime.now()).containsKey(normalizedImportId);
  }

  Set<String> pendingImportIds({DateTime? now}) {
    return _activeEntries(now ?? DateTime.now())
        .map((PendingPdfDeleteEntry item) => item.importId)
        .toSet();
  }

  Future<void> cleanupWithImports(Iterable<DrivePdfImport> imports, {DateTime? now}) async {
    final DateTime effectiveNow = now ?? DateTime.now();
    final Map<String, DrivePdfImport> importsById = <String, DrivePdfImport>{
      for (final DrivePdfImport item in imports) if (item.id.trim().isNotEmpty) item.id.trim(): item,
    };
    final Map<String, PendingPdfDeleteEntry> activeById = _activeById(effectiveNow);
    bool changed = false;
    final Map<String, PendingPdfDeleteEntry> nextById = <String, PendingPdfDeleteEntry>{};
    for (final PendingPdfDeleteEntry entry in activeById.values) {
      final DrivePdfImport? current = importsById[entry.importId];
      if (current == null) {
        changed = true;
        continue;
      }
      final String status = current.status.trim().toLowerCase();
      final bool deleteSettled =
          current.pdfDeleted == true || status == 'deleted_pdf' || status == 'rejected' || status == 'cancelled';
      if (deleteSettled) {
        changed = true;
        continue;
      }
      nextById[entry.importId] = entry;
    }
    if (changed || nextById.length != activeById.length) {
      await _save(nextById.values.toList());
    }
  }

  List<PendingPdfDeleteEntry> _activeEntries(DateTime now) {
    final entries = _loadEntries();
    return entries.where((entry) => now.difference(entry.requestedAt) <= ttl).toList();
  }

  Map<String, PendingPdfDeleteEntry> _activeById(DateTime now) {
    final Map<String, PendingPdfDeleteEntry> out = <String, PendingPdfDeleteEntry>{};
    for (final PendingPdfDeleteEntry entry in _activeEntries(now)) {
      out[entry.importId] = entry;
    }
    return out;
  }

  List<PendingPdfDeleteEntry> _loadEntries() {
    final String raw = impl.loadPendingPdfDeletePayload();
    if (raw.trim().isEmpty) {
      return const <PendingPdfDeleteEntry>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <PendingPdfDeleteEntry>[];
      }
      return decoded
          .whereType<Map<dynamic, dynamic>>()
          .map((Map<dynamic, dynamic> item) => Map<String, dynamic>.from(item))
          .map(PendingPdfDeleteEntry.fromMap)
          .whereType<PendingPdfDeleteEntry>()
          .toList();
    } catch (_) {
      return const <PendingPdfDeleteEntry>[];
    }
  }

  Future<void> _save(List<PendingPdfDeleteEntry> entries) {
    if (entries.isEmpty) {
      return impl.savePendingPdfDeletePayload('');
    }
    return impl.savePendingPdfDeletePayload(jsonEncode(entries.map((item) => item.toMap()).toList()));
  }
}
