import 'package:farmacia_desk_web/data/multitenant/mappers/real_assistiti_migration_block_diagnostic_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RealAssistitiMigrationBlockDiagnosticMapper', () {
    test('returns no diagnostics for copyable items', () {
      final List<RealAssistitiMigrationBlockDiagnostic> diagnostics =
          RealAssistitiMigrationBlockDiagnosticMapper.buildItemDiagnostics(
        status: 'copyable',
        targetDuplicateFound: false,
        blockingReasons: const <String>[],
      );

      expect(diagnostics, isEmpty);
    });

    test('maps already_target as informational and not operator-action required', () {
      final List<RealAssistitiMigrationBlockDiagnostic> diagnostics =
          RealAssistitiMigrationBlockDiagnosticMapper.buildItemDiagnostics(
        status: 'already_target',
        targetDuplicateFound: true,
        blockingReasons: const <String>['target_cf_duplicate'],
      );

      expect(diagnostics.length, 1);
      expect(diagnostics.single.code, 'already_target');
      expect(diagnostics.single.sourceCode, 'target_cf_duplicate');
      expect(diagnostics.single.severity, 'info');
      expect(diagnostics.single.operatorActionRequired, isFalse);
    });

    test('maps legacy_source_missing with actionable text', () {
      final List<RealAssistitiMigrationBlockDiagnostic> diagnostics =
          RealAssistitiMigrationBlockDiagnosticMapper.buildItemDiagnostics(
        status: 'blocked',
        targetDuplicateFound: false,
        blockingReasons: const <String>['legacy_source_missing'],
      );

      expect(diagnostics.length, 1);
      expect(diagnostics.single.code, 'legacy_source_missing');
      expect(diagnostics.single.severity, 'error');
      expect(diagnostics.single.operatorActionRequired, isTrue);
      expect(diagnostics.single.toMap()['recommendedAction'], isA<String>());
    });

    test('maps unknown blocking reasons with safe fallback', () {
      final List<RealAssistitiMigrationBlockDiagnostic> diagnostics =
          RealAssistitiMigrationBlockDiagnosticMapper.buildItemDiagnostics(
        status: 'blocked',
        targetDuplicateFound: false,
        blockingReasons: const <String>['new_unmapped_reason'],
      );

      expect(diagnostics.length, 1);
      expect(diagnostics.single.code, 'unknown_blocking_reason');
      expect(diagnostics.single.sourceCode, 'new_unmapped_reason');
      expect(diagnostics.single.operatorActionRequired, isTrue);
    });

    test('maps blocked item without reasons as unknown blocked status', () {
      final List<RealAssistitiMigrationBlockDiagnostic> diagnostics =
          RealAssistitiMigrationBlockDiagnosticMapper.buildItemDiagnostics(
        status: 'blocked',
        targetDuplicateFound: false,
        blockingReasons: const <String>[],
      );

      expect(diagnostics.length, 1);
      expect(diagnostics.single.code, 'unknown_blocked_status');
      expect(diagnostics.single.operatorActionRequired, isTrue);
    });
  });
}
