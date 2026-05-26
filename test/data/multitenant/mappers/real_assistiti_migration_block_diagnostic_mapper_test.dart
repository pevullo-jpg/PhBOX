import 'package:farmacia_desk_web/data/multitenant/mappers/real_assistiti_migration_block_diagnostic_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RealAssistitiMigrationBlockDiagnosticMapper', () {
    test('returns no diagnostics for copyable items', () {
      final List<RealAssistitiMigrationBlockDiagnostic> diagnostics =
          RealAssistitiMigrationBlockDiagnosticMapper.buildDiagnostics(
        status: RealAssistitiMigrationBlockDiagnosticMapper.statusCopyable,
        blockingReasons: const <String>[],
      );

      expect(diagnostics, isEmpty);
    });

    test('maps already_target to informational diagnostic', () {
      final List<RealAssistitiMigrationBlockDiagnostic> diagnostics =
          RealAssistitiMigrationBlockDiagnosticMapper.buildDiagnostics(
        status: RealAssistitiMigrationBlockDiagnosticMapper.statusAlreadyTarget,
        blockingReasons: const <String>['target_cf_duplicate'],
      );

      expect(diagnostics.length, 1);
      expect(diagnostics.single.code, 'already_target');
      expect(diagnostics.single.sourceCode, 'target_cf_duplicate');
      expect(diagnostics.single.severity, RealAssistitiMigrationBlockDiagnosticMapper.severityInfo);
      expect(diagnostics.single.operatorActionRequired, isFalse);
    });

    test('maps legacy_source_missing to blocking diagnostic', () {
      final List<RealAssistitiMigrationBlockDiagnostic> diagnostics =
          RealAssistitiMigrationBlockDiagnosticMapper.buildDiagnostics(
        status: RealAssistitiMigrationBlockDiagnosticMapper.statusBlocked,
        blockingReasons: const <String>['legacy_source_missing'],
      );

      expect(diagnostics.length, 1);
      expect(diagnostics.single.code, 'legacy_source_missing');
      expect(diagnostics.single.sourceCode, 'legacy_source_missing');
      expect(diagnostics.single.severity,
          RealAssistitiMigrationBlockDiagnosticMapper.severityBlocking);
      expect(diagnostics.single.operatorActionRequired, isTrue);
      expect(diagnostics.single.recommendedAction, contains('Verificare il CF'));
    });

    test('maps target_identity_absent to blocking diagnostic', () {
      final List<RealAssistitiMigrationBlockDiagnostic> diagnostics =
          RealAssistitiMigrationBlockDiagnosticMapper.buildDiagnostics(
        status: RealAssistitiMigrationBlockDiagnosticMapper.statusBlocked,
        blockingReasons: const <String>['target_identity_absent'],
      );

      expect(diagnostics.single.code, 'target_identity_absent');
      expect(diagnostics.single.operatorActionRequired, isTrue);
    });

    test('maps unknown blocking reason to safe fallback', () {
      final List<RealAssistitiMigrationBlockDiagnostic> diagnostics =
          RealAssistitiMigrationBlockDiagnosticMapper.buildDiagnostics(
        status: RealAssistitiMigrationBlockDiagnosticMapper.statusBlocked,
        blockingReasons: const <String>['new_unmapped_reason'],
      );

      expect(diagnostics.length, 1);
      expect(diagnostics.single.code, 'unknown_blocking_reason');
      expect(diagnostics.single.sourceCode, 'new_unmapped_reason');
      expect(diagnostics.single.operatorActionRequired, isTrue);
    });

    test('maps blocked status without reasons to safe diagnostic', () {
      final List<RealAssistitiMigrationBlockDiagnostic> diagnostics =
          RealAssistitiMigrationBlockDiagnosticMapper.buildDiagnostics(
        status: RealAssistitiMigrationBlockDiagnosticMapper.statusBlocked,
        blockingReasons: const <String>[],
      );

      expect(diagnostics.length, 1);
      expect(diagnostics.single.code, 'blocked_without_reason');
      expect(diagnostics.single.operatorActionRequired, isTrue);
    });

    test('maps unknown status to safe diagnostic', () {
      final List<RealAssistitiMigrationBlockDiagnostic> diagnostics =
          RealAssistitiMigrationBlockDiagnosticMapper.buildDiagnostics(
        status: 'unexpected_status',
        blockingReasons: const <String>[],
      );

      expect(diagnostics.length, 1);
      expect(diagnostics.single.code, 'unknown_audit_status');
      expect(diagnostics.single.sourceCode, 'unexpected_status');
    });
  });
}
