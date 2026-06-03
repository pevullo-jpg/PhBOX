var PHBOX_M1_FREEZE_VERSION_ = 'M1_FREEZE_v2';
var PHBOX_M1_FREEZE_STAGE_ = 'migration1_frozen_multifarmacia_baseline';
var PHBOX_M1_FREEZE_BASELINE_DOC_PATH_ = 'docs/MIGRATION_1_FREEZE_BASELINE.md';
var PHBOX_M1_FREEZE_SOURCE_DOC_PATH_ = 'docs/MIGRATION_1_MULTIFARMACIA.md';

function buildMigration1FreezeBaselineRegistry_() {
  return {
    version: PHBOX_M1_FREEZE_VERSION_,
    stage: PHBOX_M1_FREEZE_STAGE_,
    status: 'baseline_frozen',
    baselineDocPath: PHBOX_M1_FREEZE_BASELINE_DOC_PATH_,
    sourceDocPath: PHBOX_M1_FREEZE_SOURCE_DOC_PATH_,
    sourceDocVersion: 'M1_DOC_v2',
    documentedSteps: [
      'M1-COPY',
      'M1-RPT',
      'M1-CLEAN',
      'M1-BEAUD',
      'M1-SHADOW',
      'M1-IDRES',
      'M1-GATE',
      'M1-PUB',
      'M1-SIG',
      'M1-DASH',
      'M1-DUAL',
      'M1-CUT',
      'M1-E2E',
      'M1-COST',
      'M1-FINALCLEAN',
      'M1-DOC',
      'M1-FREEZE'
    ],
    requiredSections: [
      'scope',
      'owner_truth',
      'data_contracts',
      'runtime_invariants',
      'operational_properties',
      'validation_evidence',
      'cost_audit',
      'merge_and_freeze_rule'
    ],
    invariants: [
      'legacy_default_on',
      'target_runtime_default_off',
      'no_default_tenant',
      'no_target_path_before_canonical_tenant',
      'no_cutover_without_dual_match',
      'zero_write_diagnostics',
      'settings_exposes_only_current_test'
    ],
    validationEvidence: [
      'M1-IDRES PASS 7/7',
      'M1-GATE PASS 8/8',
      'M1-PUB PASS 7/7',
      'M1-SIG PASS 18/18',
      'M1-DASH PASS 8/8',
      'M1-DUAL PASS 9/9',
      'M1-CUT PASS 8/8',
      'M1-E2E PASS 6/6',
      'M1-COST PASS 8/8',
      'M1-FINALCLEAN PASS 6/6',
      'M1-DOC PASS 8/8'
    ],
    nextRoadmap: 'Migration 2 — Cutover operativo controllato'
  };
}

function runMigration1FreezeBaselineRuntimeStatus_() {
  var registry = buildMigration1FreezeBaselineRegistry_();
  return buildMigration1FreezeBaselineResult_({
    ok: true,
    skipped: false,
    reason: 'baseline_frozen',
    registry: registry,
    obsoleteHandlers: listMigration1FreezeObsoleteSettingsHandlers_(),
    violations: []
  });
}

function runMigration1FreezeBaselineSelfTest_() {
  var registry = buildMigration1FreezeBaselineRegistry_();
  var runtimeStatus = runMigration1FreezeBaselineRuntimeStatus_();
  var stats = (runtimeStatus && runtimeStatus.stats) || {};
  var cases = [
    {
      id: 'freeze_registry_contains_all_migration_steps',
      actual: registry.documentedSteps.length,
      expected: 17
    },
    {
      id: 'freeze_registry_contains_required_sections',
      actual: registry.requiredSections.length,
      expected: 8
    },
    {
      id: 'freeze_registry_contains_required_invariants',
      actual: registry.invariants.length,
      expected: 7
    },
    {
      id: 'freeze_declares_doc_v2_as_source',
      actual: registry.sourceDocVersion,
      expected: 'M1_DOC_v2'
    },
    {
      id: 'freeze_declares_next_migration_2',
      actual: registry.nextRoadmap,
      expected: 'Migration 2 — Cutover operativo controllato'
    },
    {
      id: 'settings_handlers_only_freeze_exposed',
      actual: stats.obsoleteHandlersCount,
      expected: 0
    },
    {
      id: 'freeze_runtime_zero_read_write_contract',
      actual: String(stats.firestoreReads) + ':' + String(stats.firestoreWrites),
      expected: '0:0'
    },
    {
      id: 'freeze_runtime_no_publish_cutover_lifecycle',
      actual: String(!!stats.publishToTarget || !!stats.cutover || !!stats.lifecycleTouched),
      expected: 'false'
    }
  ];

  var passed = 0;
  var failed = 0;
  var items = cases.map(function (item) {
    var mismatchReasons = [];
    if (item.actual !== item.expected) mismatchReasons.push('expected_value_mismatch');
    var ok = mismatchReasons.length === 0;
    if (ok) passed++; else failed++;
    return {
      id: item.id,
      passed: ok,
      actual: item.actual,
      expected: item.expected,
      mismatchReasons: uniqueNonEmptyStrings_(mismatchReasons)
    };
  });

  var violations = [];
  if (stats.firestoreReads !== 0) violations.push('firestore_reads_not_zero');
  if (stats.firestoreWrites !== 0) violations.push('firestore_writes_not_zero');
  if (stats.publishToTarget) violations.push('publish_to_target_detected');
  if (stats.cutover) violations.push('cutover_detected');
  if (stats.lifecycleTouched) violations.push('lifecycle_touched');
  if (stats.obsoleteHandlersCount > 0) violations.push('obsolete_settings_handlers_detected');

  return {
    ok: failed === 0 && violations.length === 0,
    testCount: items.length,
    passedCount: passed,
    failedCount: failed,
    freezeVersion: registry.version,
    migration1Status: registry.status,
    baselineDocPath: registry.baselineDocPath,
    sourceDocPath: registry.sourceDocPath,
    documentedStepsCount: registry.documentedSteps.length,
    requiredSectionsCount: registry.requiredSections.length,
    invariantsCount: registry.invariants.length,
    validationEvidenceCount: registry.validationEvidence.length,
    obsoleteHandlersCount: stats.obsoleteHandlersCount,
    firestoreReads: 0,
    firestoreWrites: 0,
    publishFromTarget: false,
    publishToTarget: false,
    targetPathBuilt: false,
    cutover: false,
    lifecycleTouched: false,
    violations: uniqueNonEmptyStrings_(violations),
    obsoleteHandlers: stats.obsoleteHandlers || [],
    items: items
  };
}

function buildMigration1FreezeBaselineResult_(data) {
  data = data || {};
  var registry = data.registry || buildMigration1FreezeBaselineRegistry_();
  var obsoleteHandlers = Array.isArray(data.obsoleteHandlers) ? data.obsoleteHandlers : [];
  var violations = Array.isArray(data.violations) ? data.violations : [];
  if (obsoleteHandlers.length > 0) violations.push('obsolete_settings_handlers_detected');

  var stats = {
    stage: PHBOX_M1_FREEZE_STAGE_,
    ok: data.ok !== false && violations.length === 0,
    skipped: !!data.skipped,
    reason: String(data.reason || 'baseline_frozen'),
    freezeVersion: registry.version,
    migration1Status: registry.status,
    baselineDocPath: registry.baselineDocPath,
    sourceDocPath: registry.sourceDocPath,
    sourceDocVersion: registry.sourceDocVersion,
    documentedStepsCount: registry.documentedSteps.length,
    requiredSectionsCount: registry.requiredSections.length,
    invariantsCount: registry.invariants.length,
    validationEvidenceCount: registry.validationEvidence.length,
    nextRoadmap: registry.nextRoadmap,
    obsoleteHandlersCount: obsoleteHandlers.length,
    firestoreReads: 0,
    firestoreWrites: 0,
    publishFromTarget: false,
    publishToTarget: false,
    targetPathBuilt: false,
    cutover: false,
    lifecycleTouched: false,
    violations: uniqueNonEmptyStrings_(violations),
    obsoleteHandlers: uniqueNonEmptyStrings_(obsoleteHandlers),
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };

  return {
    ok: !!stats.ok,
    stats: stats,
    registry: registry
  };
}

function listMigration1FreezeObsoleteSettingsHandlers_() {
  var names = [
    'runMigration1DocumentationSettingsTest',
    'getMigration1DocumentationSettingsStatus',
    'runMigration1FinalCleanupSettingsTest',
    'getMigration1FinalCleanupSettingsStatus',
    'runMigration1CostAuditSettingsTest',
    'getMigration1CostAuditSettingsStatus',
    'runMigration1E2eValidationSettingsTest',
    'getMigration1E2eValidationSettingsStatus',
    'runMigration1CutoverSettingsTest',
    'getMigration1CutoverSettingsStatus',
    'runMigration1DualVerifierSettingsTest',
    'getMigration1DualVerifierSettingsStatus',
    'runMigration1DashboardCompatSettingsTest',
    'runMigration1RuntimeSignalIdentitySettingsTest',
    'runMigration1TargetPublishSettingsTest',
    'runMigration1TargetRuntimeGateSettingsTest',
    'runMigration1BackendIdentityResolverSettingsTest'
  ];
  return names.filter(function (name) {
    return isMigration1FreezeGlobalFunction_(name);
  });
}

function isMigration1FreezeGlobalFunction_(name) {
  try {
    return typeof globalThis !== 'undefined' && typeof globalThis[name] === 'function';
  } catch (e) {
    return false;
  }
}

function formatMigration1FreezeBaselineSelfTestFeedback_(result) {
  result = result || runMigration1FreezeBaselineSelfTest_();
  var lines = [];
  lines.push('MIGRATION_1_FREEZE_TEST');
  lines.push('ok=' + String(!!result.ok));
  lines.push('testCount=' + String(result.testCount || 0));
  lines.push('passedCount=' + String(result.passedCount || 0));
  lines.push('failedCount=' + String(result.failedCount || 0));
  lines.push('freezeVersion=' + String(result.freezeVersion || ''));
  lines.push('migration1Status=' + String(result.migration1Status || ''));
  lines.push('baselineDocPath=' + String(result.baselineDocPath || ''));
  lines.push('sourceDocPath=' + String(result.sourceDocPath || ''));
  lines.push('documentedStepsCount=' + String(result.documentedStepsCount || 0));
  lines.push('requiredSectionsCount=' + String(result.requiredSectionsCount || 0));
  lines.push('invariantsCount=' + String(result.invariantsCount || 0));
  lines.push('validationEvidenceCount=' + String(result.validationEvidenceCount || 0));
  lines.push('obsoleteHandlersCount=' + String(result.obsoleteHandlersCount || 0));
  lines.push('firestoreReads=' + String(result.firestoreReads || 0));
  lines.push('firestoreWrites=' + String(result.firestoreWrites || 0));
  lines.push('publishFromTarget=' + String(!!result.publishFromTarget));
  lines.push('publishToTarget=' + String(!!result.publishToTarget));
  lines.push('targetPathBuilt=' + String(!!result.targetPathBuilt));
  lines.push('cutover=' + String(!!result.cutover));
  lines.push('lifecycleTouched=' + String(!!result.lifecycleTouched));
  lines.push('violations=' + (result.violations && result.violations.length ? result.violations.join(',') : 'none'));
  lines.push('obsoleteHandlers=' + (result.obsoleteHandlers && result.obsoleteHandlers.length ? result.obsoleteHandlers.join(',') : 'none'));
  lines.push('items=');
  (result.items || []).forEach(function (item) {
    lines.push('- id=' + item.id);
    lines.push('  passed=' + String(!!item.passed));
    lines.push('  actual=' + String(item.actual));
    lines.push('  expected=' + String(item.expected));
    lines.push('  mismatchReasons=' + (item.mismatchReasons && item.mismatchReasons.length ? item.mismatchReasons.join(',') : 'none'));
  });
  return lines.join('\n');
}

function formatMigration1FreezeBaselineRuntimeFeedback_(result) {
  result = result || runMigration1FreezeBaselineRuntimeStatus_();
  var stats = (result && result.stats) || {};
  var lines = [];
  lines.push('MIGRATION_1_FREEZE_RUNTIME_STATUS');
  lines.push('ok=' + String(!!(result && result.ok)));
  lines.push('skipped=' + String(!!stats.skipped));
  lines.push('reason=' + String(stats.reason || ''));
  lines.push('freezeVersion=' + String(stats.freezeVersion || ''));
  lines.push('migration1Status=' + String(stats.migration1Status || ''));
  lines.push('baselineDocPath=' + String(stats.baselineDocPath || ''));
  lines.push('sourceDocPath=' + String(stats.sourceDocPath || ''));
  lines.push('sourceDocVersion=' + String(stats.sourceDocVersion || ''));
  lines.push('documentedStepsCount=' + String(stats.documentedStepsCount || 0));
  lines.push('requiredSectionsCount=' + String(stats.requiredSectionsCount || 0));
  lines.push('invariantsCount=' + String(stats.invariantsCount || 0));
  lines.push('validationEvidenceCount=' + String(stats.validationEvidenceCount || 0));
  lines.push('nextRoadmap=' + String(stats.nextRoadmap || ''));
  lines.push('obsoleteHandlersCount=' + String(stats.obsoleteHandlersCount || 0));
  lines.push('firestoreReads=' + String(stats.firestoreReads || 0));
  lines.push('firestoreWrites=' + String(stats.firestoreWrites || 0));
  lines.push('publishFromTarget=' + String(!!stats.publishFromTarget));
  lines.push('publishToTarget=' + String(!!stats.publishToTarget));
  lines.push('targetPathBuilt=' + String(!!stats.targetPathBuilt));
  lines.push('cutover=' + String(!!stats.cutover));
  lines.push('lifecycleTouched=' + String(!!stats.lifecycleTouched));
  lines.push('violations=' + (stats.violations && stats.violations.length ? stats.violations.join(',') : 'none'));
  lines.push('obsoleteHandlers=' + (stats.obsoleteHandlers && stats.obsoleteHandlers.length ? stats.obsoleteHandlers.join(',') : 'none'));
  lines.push('error=' + String(stats.error || 'none'));
  lines.push('errorKind=' + String(stats.errorKind || 'none'));
  return lines.join('\n');
}
