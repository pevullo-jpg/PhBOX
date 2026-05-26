import 'package:farmacia_desk_web/data/multitenant/readers/legacy_real_assistiti_bounded_reader.dart';
import 'package:farmacia_desk_web/data/multitenant/readers/real_assistiti_dry_run_preview_reader.dart';
import 'package:farmacia_desk_web/data/multitenant/readers/target_assistiti_duplicate_guard_reader.dart';
import 'package:farmacia_desk_web/data/multitenant/verifiers/real_assistiti_post_copy_aggregate_verifier.dart';
import 'package:farmacia_desk_web/data/multitenant/verifiers/real_assistiti_post_copy_verifier.dart';
import 'package:farmacia_desk_web/data/multitenant/writers/real_assistiti_target_copy_writer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RealAssistitiPostCopyAggregateVerificationResult', () {
    test('aggregates verified and failed post-copy items without raw payload expansion', () {
      final RealAssistitiPostCopyVerificationResult detailed = _detailedResult(
        items: <RealAssistitiPostCopyVerificationItem>[
          _verificationItem(
            cf: 'CRPGNN48B19D514Z',
            documentId: 'assistito-1',
            mismatchReasons: const <String>[],
            targetExists: true,
            lockExists: true,
          ),
          _verificationItem(
            cf: 'VLLGPP84H27A089I',
            documentId: 'assistito-2',
            mismatchReasons: const <String>[
              'target_document_missing',
              'cf_lock_document_missing',
              'target_payload_mismatch',
            ],
            targetExists: false,
            lockExists: false,
          ),
        ],
      );

      final RealAssistitiPostCopyAggregateVerificationResult aggregate =
          RealAssistitiPostCopyAggregateVerificationResult.fromDetailedVerification(detailed);

      expect(aggregate.summary.requestedCount, 2);
      expect(aggregate.summary.itemCount, 2);
      expect(aggregate.summary.verifiedCount, 1);
      expect(aggregate.summary.failedCount, 1);
      expect(aggregate.summary.allVerified, isFalse);
      expect(aggregate.summary.hasFailures, isTrue);
      expect(aggregate.summary.targetDocumentMissingCount, 1);
      expect(aggregate.summary.cfLockDocumentMissingCount, 1);
      expect(aggregate.summary.payloadMismatchCount, 1);
      expect(aggregate.summary.mismatchReasonCounts['target_document_missing'], 1);
      expect(aggregate.failedFiscalCodes, const <String>['VLLGPP84H27A089I']);
      expect(aggregate.totalAttemptedReads, 14);

      final Map<String, dynamic> mapped = aggregate.toMap();
      expect(mapped.containsKey('copyResult'), isFalse);
      expect(mapped.toString().contains('legacyBundle'), isFalse);
      expect(mapped.toString().contains('dryRunPreviewItem'), isFalse);
      expect(mapped.toString().contains('targetRead'), isFalse);
      expect(mapped.toString().contains('cfLockRead'), isFalse);
      expect(mapped.toString().contains('expectedTargetPayload'), isFalse);
      expect(mapped.toString().contains('rawData'), isFalse);
    });

    test('counts target identity anchor absence as target identity mismatch', () {
      final RealAssistitiPostCopyAggregateVerificationResult aggregate =
          RealAssistitiPostCopyAggregateVerificationResult.fromDetailedVerification(
        _detailedResult(
          items: <RealAssistitiPostCopyVerificationItem>[
            _verificationItem(
              cf: 'CRPGNN48B19D514Z',
              documentId: 'assistito-1',
              mismatchReasons: const <String>['target_identity_absent'],
              targetExists: true,
              lockExists: true,
            ),
          ],
        ),
      );

      expect(aggregate.summary.failedCount, 1);
      expect(aggregate.summary.targetIdentityMismatchCount, 1);
      expect(aggregate.summary.mismatchReasonCounts['target_identity_absent'], 1);

      final Map<String, dynamic> mappedItem =
          (aggregate.toMap()['items'] as List<dynamic>).single as Map<String, dynamic>;
      expect(mappedItem['targetCfMatches'], isTrue);
      expect(mappedItem['targetAssistitoIdMatches'], isTrue);
      expect(mappedItem['targetIdentityAnchorPresent'], isFalse);
    });

    test('reports allVerified when every detailed item is verified', () {
      final RealAssistitiPostCopyAggregateVerificationResult aggregate =
          RealAssistitiPostCopyAggregateVerificationResult.fromDetailedVerification(
        _detailedResult(
          items: <RealAssistitiPostCopyVerificationItem>[
            _verificationItem(
              cf: 'CRPGNN48B19D514Z',
              documentId: 'assistito-1',
              mismatchReasons: const <String>[],
              targetExists: true,
              lockExists: true,
            ),
          ],
        ),
      );

      expect(aggregate.allVerified, isTrue);
      expect(aggregate.hasFailures, isFalse);
      expect(aggregate.failedFiscalCodes, isEmpty);
    });
  });
}

RealAssistitiPostCopyVerificationResult _detailedResult({
  required List<RealAssistitiPostCopyVerificationItem> items,
}) {
  return RealAssistitiPostCopyVerificationResult(
    tenantId: 'tenant_a',
    collectionPath: 'tenants/tenant_a/assistiti',
    cfLocksCollectionPath: 'tenants/tenant_a/assistiti_cf_locks',
    requestedFiscalCodes: items.map((RealAssistitiPostCopyVerificationItem item) => item.cf).toList(),
    items: items,
    targetDocumentReads: items.length,
    cfLockDocumentReads: items.length,
    legacyAttemptedDocumentReads: items.length * 5,
    copyResult: _copyResult(items),
  );
}

RealAssistitiPostCopyVerificationItem _verificationItem({
  required String cf,
  required String documentId,
  required List<String> mismatchReasons,
  required bool targetExists,
  required bool lockExists,
}) {
  final String documentPath = 'tenants/tenant_a/assistiti/$documentId';
  final String lockPath = 'tenants/tenant_a/assistiti_cf_locks/$cf';
  final Map<String, dynamic> targetPayload = <String, dynamic>{
    'assistitoId': documentId,
    'cf': cf,
    'fullName': 'Test Assistito',
    'createdAt': DateTime.utc(2026, 5, 26),
    'updatedAt': DateTime.utc(2026, 5, 26),
  };
  final Map<String, dynamic> lockPayload = <String, dynamic>{
    'cf': cf,
    'assistitoId': documentId,
    'assistitoPath': documentPath,
    'createdAt': DateTime.utc(2026, 5, 26),
    'lockVersion': 1,
  };
  final RealAssistitiTargetCopyWrittenDocument writtenDocument =
      RealAssistitiTargetCopyWrittenDocument(
    cf: cf,
    documentId: documentId,
    documentPath: documentPath,
    cfLockDocumentId: cf,
    cfLockDocumentPath: lockPath,
    targetPayload: targetPayload,
    cfLockPayload: lockPayload,
  );

  return RealAssistitiPostCopyVerificationItem(
    cf: cf,
    documentId: documentId,
    documentPath: documentPath,
    legacyBundle: _bundle(cf),
    dryRunPreviewItem: _previewItem(cf),
    writtenDocument: writtenDocument,
    targetRead: RealAssistitiPostCopyDocumentRead(
      cf: cf,
      documentId: documentId,
      documentPath: documentPath,
      exists: targetExists,
      rawData: targetExists ? targetPayload : const <String, dynamic>{},
    ),
    cfLockRead: RealAssistitiPostCopyLockRead(
      cf: cf,
      documentId: cf,
      documentPath: lockPath,
      exists: lockExists,
      rawData: lockExists ? lockPayload : const <String, dynamic>{},
    ),
    expectedTargetPayload: targetPayload,
    mismatchReasons: mismatchReasons,
  );
}

RealAssistitiTargetCopyResult _copyResult(List<RealAssistitiPostCopyVerificationItem> items) {
  return RealAssistitiTargetCopyResult(
    tenantId: 'tenant_a',
    collectionPath: 'tenants/tenant_a/assistiti',
    cfLocksCollectionPath: 'tenants/tenant_a/assistiti_cf_locks',
    requestedFiscalCodes: items.map((RealAssistitiPostCopyVerificationItem item) => item.cf).toList(),
    writtenDocuments: items
        .map((RealAssistitiPostCopyVerificationItem item) => item.writtenDocument)
        .toList(),
    maxDocumentsPerRun: 5,
    maxFirestoreWritesPerRun: 10,
    attemptedAssistitiWrites: items.length,
    attemptedCfLockWrites: items.length,
    attemptedWrites: items.length * 2,
    dryRunPreview: RealAssistitiDryRunPreviewResult(
      tenantId: 'tenant_a',
      requestedFiscalCodes: items.map((RealAssistitiPostCopyVerificationItem item) => item.cf).toList(),
      items: items
          .map((RealAssistitiPostCopyVerificationItem item) => _previewItem(item.cf))
          .toList(),
      maxFiscalCodes: 5,
      legacyAttemptedDocumentReads: items.length * 5,
      targetAttemptedQueries: items.length,
    ),
  );
}

RealAssistitiDryRunPreviewItem _previewItem(String cf) {
  return RealAssistitiDryRunPreviewItem(
    cf: cf,
    legacyBundle: _bundle(cf),
    duplicateGuard: TargetAssistitiDuplicateGuardCheck.notFound(
      cf: cf,
      collectionPath: 'tenants/tenant_a/assistiti',
    ),
    targetPreviewPayloadWithoutAssistitoId: <String, dynamic>{
      'cf': cf,
      'fullName': 'Test Assistito',
      'createdAt': DateTime.utc(2026, 5, 26),
      'updatedAt': DateTime.utc(2026, 5, 26),
    },
    blockingReasons: const <String>[],
    previewGeneratedAt: DateTime.utc(2026, 5, 26),
  );
}

LegacyRealAssistitoReadBundle _bundle(String cf) {
  return LegacyRealAssistitoReadBundle(
    cf: cf,
    patient: _source('patients', cf),
    dashboardIndex: _source('patient_dashboard_index', cf),
    therapeuticAdvice: _source('patient_therapeutic_advice', cf),
    doctorManual: _source('doctor_patient_links', '${cf}__manual'),
    doctorPrimary: _source('doctor_patient_links', '${cf}__primary'),
  );
}

LegacyRealAssistitiSourceRead _source(String collectionId, String documentId) {
  return LegacyRealAssistitiSourceRead(
    collectionId: collectionId,
    documentId: documentId,
    exists: true,
    rawData: const <String, dynamic>{'exists': true},
  );
}
