import 'package:farmacia_desk_web/data/multitenant/models/target_assistito.dart';
import 'package:farmacia_desk_web/data/multitenant/models/target_runtime_documents.dart';
import 'package:farmacia_desk_web/data/multitenant/validators/target_dry_run_plan_validator.dart';
import 'package:farmacia_desk_web/data/multitenant/writers/target_multitenant_writer_dry_run.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TargetDryRunPlanValidator', () {
    const String tenantId = 'farmacia_santa_venera';
    const TargetMultitenantWriterDryRun writer = TargetMultitenantWriterDryRun();
    const TargetDryRunPlanValidator validator = TargetDryRunPlanValidator();

    test('accepts bounded target plans under tenants tenantId paths', () {
      final TargetDryRunWritePlan assistitoPlan = writer.planAssistitoSet(
        tenantId: tenantId,
        assistito: TargetAssistito.empty(
          assistitoId: 'RSSMRA80A01H501U',
          fiscalCode: 'RSSMRA80A01H501U',
        ),
      );
      final TargetDryRunWritePlan runtimePlan = writer.planRuntimeSet(
        tenantId: tenantId,
        runtime: TargetPhboxRuntime.empty(),
      );
      final TargetDryRunWritePlan signalPlan = writer.planSignalSet(
        tenantId: tenantId,
        signal: const TargetPhboxSignal(
          signalId: 'signal_001',
          kind: 'dry_run_fixture',
          status: 'pending',
          createdAt: null,
          handledAt: null,
          payload: <String, dynamic>{'fixture': true},
        ),
      );

      final TargetDryRunWritePlan combined = writer.combine(
        tenantId: tenantId,
        plans: <TargetDryRunWritePlan>[assistitoPlan, runtimePlan, signalPlan],
      );
      final TargetDryRunPlanValidationResult result = validator.validate(combined);

      expect(result.isValid, isTrue);
      expect(result.issueCount, 0);
      expect(combined.intentCount, 3);
      expect(
        combined.intents.every((TargetDryRunWriteIntent intent) => intent.path.startsWith('tenants/$tenantId/')),
        isTrue,
      );
    });

    test('rejects duplicate set intents for the same target document path', () {
      final TargetDryRunWritePlan plan = writer.planRuntimeSet(
        tenantId: tenantId,
        runtime: TargetPhboxRuntime.empty(),
      );
      final TargetDryRunWritePlan duplicatePlan = TargetDryRunWritePlan(
        tenantId: tenantId,
        intents: <TargetDryRunWriteIntent>[
          ...plan.intents,
          ...plan.intents,
        ],
      );

      final TargetDryRunPlanValidationResult result = validator.validate(duplicatePlan);

      expect(result.isNotValid, isTrue);
      expect(
        result.issues.any((TargetDryRunPlanValidationIssue issue) => issue.code == 'duplicate_set_path'),
        isTrue,
      );
    });

    test('rejects paths outside the tenant target tree', () {
      const TargetDryRunWritePlan plan = TargetDryRunWritePlan(
        tenantId: tenantId,
        intents: <TargetDryRunWriteIntent>[
          TargetDryRunWriteIntent(
            operation: TargetDryRunWriteIntent.setOperation,
            path: 'patients/RSSMRA80A01H501U',
            data: <String, dynamic>{'fiscalCode': 'RSSMRA80A01H501U'},
            reason: 'legacy_root_path_fixture',
          ),
        ],
      );

      final TargetDryRunPlanValidationResult result = validator.validate(plan);

      expect(result.isNotValid, isTrue);
      expect(
        result.issues.any((TargetDryRunPlanValidationIssue issue) => issue.code == 'path_outside_tenant'),
        isTrue,
      );
    });

    test('rejects unbounded dry-run plans', () {
      final List<TargetDryRunWriteIntent> intents = List<TargetDryRunWriteIntent>.generate(
        3,
        (int index) => TargetDryRunWriteIntent.set(
          path: 'tenants/$tenantId/phbox_signals/signal_$index',
          data: <String, dynamic>{'index': index},
          reason: 'bounded_fixture',
        ),
      );
      final TargetDryRunWritePlan plan = TargetDryRunWritePlan(
        tenantId: tenantId,
        intents: intents,
      );
      const TargetDryRunPlanValidator strictValidator = TargetDryRunPlanValidator(maxIntentCount: 2);

      final TargetDryRunPlanValidationResult result = strictValidator.validate(plan);

      expect(result.isNotValid, isTrue);
      expect(
        result.issues.any((TargetDryRunPlanValidationIssue issue) => issue.code == 'intent_count_unbounded'),
        isTrue,
      );
    });
  });
}
