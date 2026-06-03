var PHBOX_M1_DOC_STAGE_ = 'migration1_final_documentation';
var PHBOX_M1_DOC_VERSION_ = 'M1_DOC_v1';
var PHBOX_M1_DOC_FILE_PATH_ = 'docs/MIGRATION_1_MULTIFARMACIA.md';

var PHBOX_M1_DOC_REQUIRED_STEPS_ = [
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
];

var PHBOX_M1_DOC_REQUIRED_SECTIONS_ = [
  'Owner della verità',
  'Contratti dati',
  'Invarianti runtime',
  'Properties operative',
  'Evidenze di validazione',
  'Costi',
  'Regola di merge',
  'Prossimo step'
];

var PHBOX_M1_DOC_REQUIRED_INVARIANTS_ = [
  'default_off',
  'no_fallback_tenant',
  'canonical_tenant_before_target_path',
  'no_bulk_scan',
  'no_cutover_until_authorized',
  'zero_write_diagnostic_tests',
  'legacy_runtime_preserved'
];

var PHBOX_M1_DOC_OBSOLETE_SETTINGS_HANDLERS_ = [
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
  'runMigration1IdentityResolverSettingsTest'
];

function runMigration1DocumentationSelfTest_() {
  var cases = [
    {
      id: 'doc_registry_contains_all_migration_steps',
      actual: PHBOX_M1_DOC_REQUIRED_STEPS_.length,
      expected: 17
    },
    {
      id: 'doc_registry_contains_required_sections',
      actual: PHBOX_M1_DOC_REQUIRED_SECTIONS_.length,
      expected: 8
    },
    {
      id: 'doc_registry_contains_required_invariants',
      actual: PHBOX_M1_DOC_REQUIRED_INVARIANTS_.length,
      expected: 7
    },
    {
      id: 'validation_evidence_declared',
      actual: migration1DocumentationHasStep_('M1-COST') && migration1DocumentationHasStep_('M1-FINALCLEAN'),
      expected: true
    },
    {
      id: 'next_step_freeze_declared',
      actual: migration1DocumentationHasStep_('M1-FREEZE'),
      expected: true
    },
    {
      id: 'settings_handlers_only_doc_exposed',
      actual: listMigration1DocumentationObsoleteSettingsHandlers_().length,
      expected: 0
    },
    {
      id: 'doc_runtime_zero_read_write_contract',
      actual: buildMigration1DocumentationStats_({}).firestoreReads + ':' + buildMigration1DocumentationStats_({}).firestoreWrites,
      expected: '0:0'
    },
    {
      id: 'doc_runtime_no_publish_cutover_lifecycle',
      actual: buildMigration1DocumentationStats_({}).publishToTarget || buildMigration1DocumentationStats_({}).cutover || buildMigration1DocumentationStats_({}).lifecycleTouched,
      expected: false
    }
  ];

  var passed = 0;
  var failed = 0;
  var items = cases.map(function (item) {
    var ok = item.actual === item.expected;
    if (ok) passed++; else failed++;
    return {
      id: item.id,
      passed: ok,
      actual: String(item.actual),
      expected: String(item.expected),
      mismatchReasons: ok ? [] : ['expected_' + String(item.expected) + '_got_' + String(item.actual)]
    };
  });

  return {
    ok: failed === 0,
    testCount: items.length,
    passedCount: passed,
    failedCount: failed,
    docVersion: PHBOX_M1_DOC_VERSION_,
    docPath: PHBOX_M1_DOC_FILE_PATH_,
    documentedStepsCount: PHBOX_M1_DOC_REQUIRED_STEPS_.length,
    requiredSectionsCount: PHBOX_M1_DOC_REQUIRED_SECTIONS_.length,
    invariantsCount: PHBOX_M1_DOC_REQUIRED_INVARIANTS_.length,
    obsoleteHandlersCount: listMigration1DocumentationObsoleteSettingsHandlers_().length,
    firestoreReads: 0,
    firestoreWrites: 0,
    publishFromTarget: false,
    publishToTarget: false,
    targetPathBuilt: false,
    cutover: false,
    lifecycleTouched: false,
    items: items
  };
}

function runMigration1DocumentationRuntimeStatus_() {
  var obsoleteHandlers = listMigration1DocumentationObsoleteSettingsHandlers_();
  var ok = obsoleteHandlers.length === 0;
  return {
    ok: ok,
    stats: buildMigration1DocumentationStats_({
      ok: ok,
      reason: ok ? 'documentation_available' : 'obsolete_settings_handlers_exposed',
      obsoleteHandlers: obsoleteHandlers
    })
  };
}

function buildMigration1DocumentationStats_(data) {
  data = data || {};
  var obsoleteHandlers = data.obsoleteHandlers || [];
  return {
    stage: PHBOX_M1_DOC_STAGE_,
    docVersion: PHBOX_M1_DOC_VERSION_,
    docPath: PHBOX_M1_DOC_FILE_PATH_,
    ok: data.ok !== false,
    skipped: false,
    reason: String(data.reason || 'documentation_available'),
    documentedStepsCount: PHBOX_M1_DOC_REQUIRED_STEPS_.length,
    requiredSectionsCount: PHBOX_M1_DOC_REQUIRED_SECTIONS_.length,
    invariantsCount: PHBOX_M1_DOC_REQUIRED_INVARIANTS_.length,
    obsoleteHandlersCount: obsoleteHandlers.length,
    firestoreReads: 0,
    firestoreWrites: 0,
    publishFromTarget: false,
    publishToTarget: false,
    targetPathBuilt: false,
    cutover: false,
    lifecycleTouched: false,
    violations: [],
    obsoleteHandlers: obsoleteHandlers,
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };
}

function migration1DocumentationHasStep_(step) {
  return PHBOX_M1_DOC_REQUIRED_STEPS_.indexOf(String(step || '')) >= 0;
}

function listMigration1DocumentationObsoleteSettingsHandlers_() {
  return PHBOX_M1_DOC_OBSOLETE_SETTINGS_HANDLERS_.filter(function (name) {
    return isMigration1DocumentationGlobalFunction_(name);
  });
}

function isMigration1DocumentationGlobalFunction_(name) {
  try {
    if (typeof globalThis !== 'undefined' && typeof globalThis[name] === 'function') return true;
  } catch (e) {
    return false;
  }
  return false;
}

function formatMigration1DocumentationSelfTestFeedback_(result) {
  result = result || runMigration1DocumentationSelfTest_();
  var lines = [];
  lines.push('MIGRATION_1_DOC_TEST');
  lines.push('ok=' + String(!!result.ok));
  lines.push('testCount=' + String(result.testCount || 0));
  lines.push('passedCount=' + String(result.passedCount || 0));
  lines.push('failedCount=' + String(result.failedCount || 0));
  lines.push('docVersion=' + String(result.docVersion || ''));
  lines.push('docPath=' + String(result.docPath || ''));
  lines.push('documentedStepsCount=' + String(result.documentedStepsCount || 0));
  lines.push('requiredSectionsCount=' + String(result.requiredSectionsCount || 0));
  lines.push('invariantsCount=' + String(result.invariantsCount || 0));
  lines.push('obsoleteHandlersCount=' + String(result.obsoleteHandlersCount || 0));
  lines.push('firestoreReads=' + String(result.firestoreReads || 0));
  lines.push('firestoreWrites=' + String(result.firestoreWrites || 0));
  lines.push('publishFromTarget=' + String(!!result.publishFromTarget));
  lines.push('publishToTarget=' + String(!!result.publishToTarget));
  lines.push('targetPathBuilt=' + String(!!result.targetPathBuilt));
  lines.push('cutover=' + String(!!result.cutover));
  lines.push('lifecycleTouched=' + String(!!result.lifecycleTouched));
  lines.push('items=');
  (result.items || []).forEach(function (item) {
    lines.push('- id=' + String(item.id || ''));
    lines.push('  passed=' + String(!!item.passed));
    lines.push('  actual=' + String(item.actual || ''));
    lines.push('  expected=' + String(item.expected || ''));
    lines.push('  mismatchReasons=' + ((item.mismatchReasons || []).join(',') || 'none'));
  });
  return lines.join('\n');
}

function formatMigration1DocumentationRuntimeFeedback_(result) {
  result = result || runMigration1DocumentationRuntimeStatus_();
  var stats = (result && result.stats) || {};
  var lines = [];
  lines.push('MIGRATION_1_DOC_RUNTIME_STATUS');
  lines.push('ok=' + String(!!(result && result.ok)));
  lines.push('skipped=' + String(!!stats.skipped));
  lines.push('reason=' + String(stats.reason || ''));
  lines.push('docVersion=' + String(stats.docVersion || ''));
  lines.push('docPath=' + String(stats.docPath || ''));
  lines.push('documentedStepsCount=' + String(stats.documentedStepsCount || 0));
  lines.push('requiredSectionsCount=' + String(stats.requiredSectionsCount || 0));
  lines.push('invariantsCount=' + String(stats.invariantsCount || 0));
  lines.push('obsoleteHandlersCount=' + String(stats.obsoleteHandlersCount || 0));
  lines.push('firestoreReads=' + String(stats.firestoreReads || 0));
  lines.push('firestoreWrites=' + String(stats.firestoreWrites || 0));
  lines.push('publishFromTarget=' + String(!!stats.publishFromTarget));
  lines.push('publishToTarget=' + String(!!stats.publishToTarget));
  lines.push('targetPathBuilt=' + String(!!stats.targetPathBuilt));
  lines.push('cutover=' + String(!!stats.cutover));
  lines.push('lifecycleTouched=' + String(!!stats.lifecycleTouched));
  lines.push('violations=' + ((stats.violations || []).join(',') || 'none'));
  lines.push('obsoleteHandlers=' + ((stats.obsoleteHandlers || []).join(',') || 'none'));
  lines.push('error=' + String(stats.error || 'none'));
  lines.push('errorKind=' + String(stats.errorKind || 'none'));
  return lines.join('\n');
}
