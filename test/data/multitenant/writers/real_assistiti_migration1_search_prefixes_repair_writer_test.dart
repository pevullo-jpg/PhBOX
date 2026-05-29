import 'package:flutter_test/flutter_test.dart';
import 'package:farmacia_desk_web/data/multitenant/mappers/real_assistiti_target_preview_mapper.dart';
import 'package:farmacia_desk_web/data/multitenant/writers/real_assistiti_migration1_search_prefixes_repair_writer.dart';

void main() {
  group('RealAssistitiMigration1SearchPrefixesRepairWriter', () {
    test('builds repair plan for resolved manual NOCF with stale searchPrefixes', () {
      final RealAssistitiMigration1SearchPrefixesRepairPlan plan =
          RealAssistitiMigration1SearchPrefixesRepairWriter.buildRepairPlan(
        _resolvedNoCfPayload(
          fullName: 'Fantauzzo Amedeo',
          searchPrefixes: const <String>['stale'],
        ),
      );

      expect(plan.repairable, isTrue);
      expect(plan.alreadyConsistent, isFalse);
      expect(plan.expectedSearchPrefixes,
          RealAssistitiTargetPreviewMapper.buildSearchPrefixes('Fantauzzo Amedeo'));
    });

    test('skips already consistent searchPrefixes without requiring a write', () {
      final List<String> prefixes = RealAssistitiTargetPreviewMapper.buildSearchPrefixes('Fantauzzo Amedeo');
      final RealAssistitiMigration1SearchPrefixesRepairPlan plan =
          RealAssistitiMigration1SearchPrefixesRepairWriter.buildRepairPlan(
        _resolvedNoCfPayload(
          fullName: 'Fantauzzo Amedeo',
          searchPrefixes: prefixes,
        ),
      );

      expect(plan.repairable, isTrue);
      expect(plan.alreadyConsistent, isTrue);
    });

    test('rejects non NOCF documents', () {
      final RealAssistitiMigration1SearchPrefixesRepairPlan plan =
          RealAssistitiMigration1SearchPrefixesRepairWriter.buildRepairPlan(
        <String, dynamic>{
          'identityType': 'cf',
          'identityResolutionStatus': 'resolved_manual',
          'identityResolution': <String, dynamic>{'status': 'resolved_manual'},
          'nameSplitConfidence': 'resolved_manual_nocf_identity',
          'fullName': 'Rossi Mario',
          'searchPrefixes': const <String>['stale'],
        },
      );

      expect(plan.repairable, isFalse);
      expect(plan.skipReason, 'target_identity_type_not_nocf');
    });

    test('rejects non resolved_manual identity states', () {
      final RealAssistitiMigration1SearchPrefixesRepairPlan plan =
          RealAssistitiMigration1SearchPrefixesRepairWriter.buildRepairPlan(
        _resolvedNoCfPayload(
          fullName: 'Fantauzzo Amedeo',
          rootStatus: 'pending_manual',
          nestedStatus: 'pending_manual',
          nameSplitConfidence: 'pending_manual_nocf_identity_resolution',
          searchPrefixes: const <String>['stale'],
        ),
      );

      expect(plan.repairable, isFalse);
      expect(plan.skipReason, 'target_identity_resolution_state_not_resolved_manual');
    });

    test('rejects contaminated fullName', () {
      final RealAssistitiMigration1SearchPrefixesRepairPlan plan =
          RealAssistitiMigration1SearchPrefixesRepairWriter.buildRepairPlan(
        _resolvedNoCfPayload(
          fullName: 'Fantauzzo RSSMRA80A01H501U',
          searchPrefixes: const <String>['stale'],
        ),
      );

      expect(plan.repairable, isFalse);
      expect(plan.skipReason, 'target_full_name_not_repairable');
    });

    test('enforces max two assistito ids before work', () {
      expect(
        () => RealAssistitiMigration1SearchPrefixesRepairWriter.normalizeAssistitoIds(
          const <String>['a', 'b', 'c'],
        ),
        throwsA(isA<RealAssistitiMigration1SearchPrefixesRepairRejectedException>()),
      );
    });

    test('deduplicates canonical assistito ids within cap', () {
      expect(
        RealAssistitiMigration1SearchPrefixesRepairWriter.normalizeAssistitoIds(
          const <String>['ZJYufVs7xItukDhXeJJO', 'ZJYufVs7xItukDhXeJJO'],
        ),
        const <String>['ZJYufVs7xItukDhXeJJO'],
      );
    });
  });
}

Map<String, dynamic> _resolvedNoCfPayload({
  required String fullName,
  required List<String> searchPrefixes,
  String rootStatus = 'resolved_manual',
  String nestedStatus = 'resolved_manual',
  String nameSplitConfidence = 'resolved_manual_nocf_identity',
}) {
  return <String, dynamic>{
    'identityType': 'nocf',
    'identityResolutionStatus': rootStatus,
    'identityResolution': <String, dynamic>{'status': nestedStatus},
    'nameSplitConfidence': nameSplitConfidence,
    'fullName': fullName,
    'searchPrefixes': searchPrefixes,
  };
}
