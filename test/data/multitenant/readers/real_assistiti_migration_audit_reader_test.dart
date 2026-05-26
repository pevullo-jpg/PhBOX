import 'package:farmacia_desk_web/data/multitenant/readers/legacy_real_assistiti_bounded_reader.dart';
import 'package:farmacia_desk_web/data/multitenant/readers/real_assistiti_dry_run_preview_reader.dart';
import 'package:farmacia_desk_web/data/multitenant/readers/real_assistiti_migration_audit_reader.dart';
import 'package:farmacia_desk_web/data/multitenant/readers/target_assistiti_duplicate_guard_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RealAssistitiMigrationAuditResult', () {
    test('aggregates mutually exclusive copyable, blocked and already-target statuses', () {
      final DateTime now = DateTime.utc(2026, 5, 26, 9, 0, 0);
      final RealAssistitiDryRunPreviewResult preview = RealAssistitiDryRunPreviewResult(
        tenantId: 'tenant_a',
        requestedFiscalCodes: const <String>[
          'CRPGNN48B19D514Z',
          'VLLGPP84H27A089I',
          'RSSMRA80A01H501U',
        ],
        maxFiscalCodes: 20,
        legacyAttemptedDocumentReads: 15,
        targetAttemptedQueries: 3,
        items: <RealAssistitiDryRunPreviewItem>[
          _previewItem(
            cf: 'CRPGNN48B19D514Z',
            bundle: _bundle(
              cf: 'CRPGNN48B19D514Z',
              patientExists: true,
              dashboardExists: true,
              therapeuticExists: true,
              doctorManualExists: true,
            ),
            duplicateFound: false,
            blockingReasons: const <String>[],
            now: now,
          ),
          _previewItem(
            cf: 'VLLGPP84H27A089I',
            bundle: _bundle(
              cf: 'VLLGPP84H27A089I',
              patientExists: true,
            ),
            duplicateFound: true,
            blockingReasons: const <String>['target_cf_duplicate'],
            now: now,
          ),
          _previewItem(
            cf: 'RSSMRA80A01H501U',
            bundle: _bundle(
              cf: 'RSSMRA80A01H501U',
            ),
            duplicateFound: false,
            blockingReasons: const <String>['legacy_source_missing'],
            now: now,
          ),
        ],
      );

      final RealAssistitiMigrationAuditResult audit =
          RealAssistitiMigrationAuditResult.fromDryRunPreview(preview);

      expect(audit.summary.requestedCount, 3);
      expect(audit.summary.previewItemCount, 3);
      expect(audit.summary.copyableCount, 1);
      expect(audit.summary.blockedCount, 1);
      expect(audit.summary.alreadyTargetCount, 1);
      expect(audit.summary.legacyFoundCount, 2);
      expect(audit.summary.legacyMissingCount, 1);
      expect(audit.summary.canonicalPatientCount, 2);
      expect(audit.summary.dashboardIndexCount, 1);
      expect(audit.summary.therapeuticAdviceCount, 1);
      expect(audit.summary.doctorManualCount, 1);
      expect(audit.summary.doctorAnyCount, 1);
      expect(audit.summary.blockingReasonCounts.containsKey('target_cf_duplicate'), isFalse);
      expect(audit.summary.blockingReasonCounts['legacy_source_missing'], 1);
      expect(audit.summary.diagnosticCodeCounts['already_target'], 1);
      expect(audit.summary.diagnosticCodeCounts['legacy_source_missing'], 1);
      expect(audit.attemptedReadOperations, 18);
      expect(audit.copyableFiscalCodes, const <String>['CRPGNN48B19D514Z']);
      expect(audit.blockedFiscalCodes, const <String>['RSSMRA80A01H501U']);
      expect(audit.alreadyTargetFiscalCodes, const <String>['VLLGPP84H27A089I']);

      final Map<String, dynamic> mapped = audit.toMap();
      expect(mapped.containsKey('dryRunPreview'), isFalse);
      expect((mapped['items'] as List<dynamic>).length, 3);
      expect(
        ((mapped['items'] as List<dynamic>).first as Map<String, dynamic>)
            .containsKey('targetPreviewPayloadWithoutAssistitoId'),
        isFalse,
      );
    });

    test('does not expose raw dry-run preview on audit result surface', () {
      final DateTime now = DateTime.utc(2026, 5, 26, 9, 0, 0);
      final RealAssistitiMigrationAuditResult audit =
          RealAssistitiMigrationAuditResult.fromDryRunPreview(
        RealAssistitiDryRunPreviewResult(
          tenantId: 'tenant_a',
          requestedFiscalCodes: const <String>['CRPGNN48B19D514Z'],
          maxFiscalCodes: 20,
          legacyAttemptedDocumentReads: 5,
          targetAttemptedQueries: 1,
          items: <RealAssistitiDryRunPreviewItem>[
            _previewItem(
              cf: 'CRPGNN48B19D514Z',
              bundle: _bundle(
                cf: 'CRPGNN48B19D514Z',
                patientExists: true,
              ),
              duplicateFound: false,
              blockingReasons: const <String>[],
              now: now,
            ),
          ],
        ),
      );

      final Map<String, dynamic> mapped = audit.toMap();
      expect(mapped.containsKey('dryRunPreview'), isFalse);
      expect(mapped.toString().contains('targetPreviewPayloadWithoutAssistitoId'), isFalse);
      expect(mapped.toString().contains('legacyBundle'), isFalse);
    });

    test('marks target duplicate as already_target without counting it as blocked', () {
      final DateTime now = DateTime.utc(2026, 5, 26, 9, 0, 0);
      final RealAssistitiMigrationAuditItem item =
          RealAssistitiMigrationAuditItem.fromPreviewItem(
        _previewItem(
          cf: 'VLLGPP84H27A089I',
          bundle: _bundle(
            cf: 'VLLGPP84H27A089I',
            patientExists: true,
          ),
          duplicateFound: true,
          blockingReasons: const <String>['target_cf_duplicate'],
          now: now,
        ),
      );

      expect(item.status, 'already_target');
      expect(item.copyable, isFalse);
      expect(item.blocked, isFalse);
      expect(item.alreadyTarget, isTrue);
      expect(item.targetDuplicateFound, isTrue);
      expect(item.diagnostics.single.code, 'already_target');
    });

    test('includes readable diagnostics in mapped audit items without raw payload', () {
      final DateTime now = DateTime.utc(2026, 5, 26, 9, 0, 0);
      final RealAssistitiMigrationAuditResult audit =
          RealAssistitiMigrationAuditResult.fromDryRunPreview(
        RealAssistitiDryRunPreviewResult(
          tenantId: 'tenant_a',
          requestedFiscalCodes: const <String>['RSSMRA80A01H501U'],
          maxFiscalCodes: 20,
          legacyAttemptedDocumentReads: 5,
          targetAttemptedQueries: 1,
          items: <RealAssistitiDryRunPreviewItem>[
            _previewItem(
              cf: 'RSSMRA80A01H501U',
              bundle: _bundle(cf: 'RSSMRA80A01H501U'),
              duplicateFound: false,
              blockingReasons: const <String>['legacy_source_missing'],
              now: now,
            ),
          ],
        ),
      );

      final Map<String, dynamic> mappedItem =
          ((audit.toMap()['items'] as List<dynamic>).single as Map<String, dynamic>);
      final List<dynamic> diagnostics = mappedItem['diagnostics'] as List<dynamic>;

      expect(diagnostics.length, 1);
      expect((diagnostics.single as Map<String, dynamic>)['code'], 'legacy_source_missing');
      expect(mappedItem.containsKey('legacyBundle'), isFalse);
      expect(mappedItem.containsKey('targetPreviewPayloadWithoutAssistitoId'), isFalse);
    });
  });
}

RealAssistitiDryRunPreviewItem _previewItem({
  required String cf,
  required LegacyRealAssistitoReadBundle bundle,
  required bool duplicateFound,
  required List<String> blockingReasons,
  required DateTime now,
}) {
  return RealAssistitiDryRunPreviewItem(
    cf: cf,
    legacyBundle: bundle,
    duplicateGuard: TargetAssistitiDuplicateGuardCheck(
      cf: cf,
      collectionPath: 'tenants/tenant_a/assistiti',
      duplicateFound: duplicateFound,
      match: duplicateFound
          ? TargetAssistitiDuplicateGuardMatch(
              cf: cf,
              documentId: 'target-$cf',
              rawData: const <String, dynamic>{'cf': 'already-target'},
            )
          : null,
    ),
    targetPreviewPayloadWithoutAssistitoId: <String, dynamic>{
      'cf': cf,
      'fullName': 'Test Assistito',
      'searchPrefixes': const <String>['test'],
      'createdAt': now,
      'updatedAt': now,
    },
    blockingReasons: blockingReasons,
    previewGeneratedAt: now,
  );
}

LegacyRealAssistitoReadBundle _bundle({
  required String cf,
  bool patientExists = false,
  bool dashboardExists = false,
  bool therapeuticExists = false,
  bool doctorManualExists = false,
  bool doctorPrimaryExists = false,
}) {
  return LegacyRealAssistitoReadBundle(
    cf: cf,
    patient: _source(
      collectionId: 'patients',
      documentId: cf,
      exists: patientExists,
    ),
    dashboardIndex: _source(
      collectionId: 'patient_dashboard_index',
      documentId: cf,
      exists: dashboardExists,
    ),
    therapeuticAdvice: _source(
      collectionId: 'patient_therapeutic_advice',
      documentId: cf,
      exists: therapeuticExists,
    ),
    doctorManual: _source(
      collectionId: 'doctor_patient_links',
      documentId: '${cf}__manual',
      exists: doctorManualExists,
    ),
    doctorPrimary: _source(
      collectionId: 'doctor_patient_links',
      documentId: '${cf}__primary',
      exists: doctorPrimaryExists,
    ),
  );
}

LegacyRealAssistitiSourceRead _source({
  required String collectionId,
  required String documentId,
  required bool exists,
}) {
  return LegacyRealAssistitiSourceRead(
    collectionId: collectionId,
    documentId: documentId,
    exists: exists,
    rawData: exists ? <String, dynamic>{'exists': true} : const <String, dynamic>{},
  );
}
