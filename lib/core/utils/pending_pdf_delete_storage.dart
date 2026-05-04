import '../../data/models/drive_pdf_import.dart';
import 'patient_input_normalizer.dart';
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
}

const Duration _ttl = Duration(hours: 24);

Future<void> savePendingPdfDelete({required String importId, required String fiscalCode, DateTime? requestedAt}) async {
  final String normalizedImportId = importId.trim();
  final String normalizedFiscalCode = PatientInputNormalizer.normalizeFiscalCode(fiscalCode);
  if (normalizedImportId.isEmpty || normalizedFiscalCode.isEmpty) return;
  await impl.upsertEntry(PendingPdfDeleteEntry(
    importId: normalizedImportId,
    fiscalCode: normalizedFiscalCode,
    requestedAt: requestedAt ?? DateTime.now(),
  ));
}

Future<Map<String, PendingPdfDeleteEntry>> loadPendingPdfDeletesByImportId() async {
  final DateTime now = DateTime.now();
  final List<PendingPdfDeleteEntry> entries = await impl.loadEntries();
  final Map<String, PendingPdfDeleteEntry> active = <String, PendingPdfDeleteEntry>{};
  bool changed = false;
  for (final PendingPdfDeleteEntry entry in entries) {
    if (now.difference(entry.requestedAt) > _ttl) {
      changed = true;
      continue;
    }
    active[entry.importId] = entry;
  }
  if (changed || active.length != entries.length) {
    await impl.replaceEntries(active.values.toList());
  }
  return active;
}

Future<void> removePendingPdfDeleteByImportId(String importId) async {
  final String normalizedImportId = importId.trim();
  if (normalizedImportId.isEmpty) return;
  await impl.removeByImportIds(<String>{normalizedImportId});
}

Future<void> removePendingPdfDeletesByFiscalCode(String fiscalCode) async {
  final String normalizedFiscalCode = PatientInputNormalizer.normalizeFiscalCode(fiscalCode);
  if (normalizedFiscalCode.isEmpty) return;
  final List<PendingPdfDeleteEntry> entries = await impl.loadEntries();
  final Set<String> ids = entries.where((e) => e.fiscalCode == normalizedFiscalCode).map((e) => e.importId).toSet();
  if (ids.isEmpty) return;
  await impl.removeByImportIds(ids);
}
