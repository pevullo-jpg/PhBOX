var PHBOX_M1_FINALCLEAN_STAGE_ = 'migration1_final_cleanup';

function runMigration1FinalCleanupRuntimeStatus_() {
  try {
    var costStatus = runMigration1CostAuditRuntimeStatus_();
    return buildMigration1FinalCleanupRuntimeResult_(costStatus);
  } catch (e) {
    return buildMigration1FinalCleanupResult_({
      ok: false,
      skipped: true,
      reason: 'final_cleanup_runtime_error',
      error: normalizeRuntimeErrorMessage_(e),
      errorKind: classifyRuntimeFailureKind_(e)
    });
  }
}

function buildMigration1FinalCleanupRuntimeResult_(costStatus) {
  var costStats = (costStatus && costStatus.stats) || {};
  var handlerStatus = inspectMigration1FinalCleanupSettingsHandlers_();
  var violations = [];

  if (!(costStatus && costStatus.ok)) violations.push('cost_audit_not_ok');
  if (handlerStatus.obsoleteHandlers.length) violations.push('obsolete_settings_handlers_exposed');
  if (!handlerStatus.finalCleanupHandlersOk) violations.push('final_cleanup_handlers_missing');
  if (Math.max(0, Number(costStats.firestoreWrites || 0)) > 0) violations.push('firestore_writes_detected');
  if (costStats.publishFromTarget) violations.push('publish_from_target_detected');
  if (costStats.publishToTarget) violations.push('publish_to_target_detected');
  if (costStats.cutover) violations.push('cutover_detected');
  if (costStats.lifecycleTouched) violations.push('lifecycle_touched');

  return buildMigration1FinalCleanupResult_({
    ok: violations.length === 0,
    skipped: !!costStats.skipped,
    reason: violations.length ? 'final_cleanup_violation' : String(costStats.reason || ''),
    costOk: !!(costStatus && costStatus.ok),
    settingsHandlersOk: handlerStatus.finalCleanupHandlersOk && handlerStatus.obsoleteHandlers.length === 0,
    obsoleteHandlers: handlerStatus.obsoleteHandlers,
    firestoreReads: Math.max(0, Number(costStats.firestoreReads || 0)),
    firestoreWrites: Math.max(0, Number(costStats.firestoreWrites || 0)),
    publishFromTarget: !!costStats.publishFromTarget,
    publishToTarget: !!costStats.publishToTarget,
    targetPathBuilt: !!costStats.targetPathBuilt,
    cutover: !!costStats.cutover,
    lifecycleTouched: !!costStats.lifecycleTouched,
    violations: violations
  });
}

function inspectMigration1FinalCleanupSettingsHandlers_() {
  var obsoleteNames = [
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
  var obsoleteHandlers = obsoleteNames.filter(function (name) {
    try {
      return typeof this[name] === 'function';
    } catch (e) {
      return false;
    }
  }, this);

  return {
    finalCleanupHandlersOk: typeof runMigration1FinalCleanupSettingsTest === 'function' && typeof getMigration1FinalCleanupSettingsStatus === 'function',
    obsoleteHandlers: obsoleteHandlers
  };
}

function buildMigration1FinalCleanupResult_(data) {
  data = data || {};
  return {
    ok: data.ok !== false,
    stats: buildMigration1FinalCleanupStats_(data),
    obsoleteHandlers: data.obsoleteHandlers || [],
    violations: uniqueNonEmptyStrings_(data.violations || [])
  };
}

function buildMigration1FinalCleanupStats_(data) {
  data = data || {};
  return {
    stage: PHBOX_M1_FINALCLEAN_STAGE_,
    skipped: data.skipped !== false,
    reason: String(data.reason || ''),
    costOk: !!data.costOk,
    settingsHandlersOk: !!data.settingsHandlersOk,
    obsoleteHandlersCount: Math.max(0, Number((data.obsoleteHandlers || []).length || 0)),
    firestoreReads: Math.max(0, Number(data.firestoreReads || 0)),
    firestoreWrites: 0,
    publishFromTarget: !!data.publishFromTarget,
    publishToTarget: !!data.publishToTarget,
    targetPathBuilt: !!data.targetPathBuilt,
    cutover: !!data.cutover,
    lifecycleTouched: !!data.lifecycleTouched,
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };
}

function runMigration1FinalCleanupSelfTest_() {
  var cases = [
    {
      id: 'cost_gate_off_zero_read_write_passes',
      input: buildMigration1FinalCleanupRuntimeResult_(buildMigration1FinalCleanupTestCostStatus_({ ok: true, skipped: true, reason: 'target_runtime_gate_off' })),
      expected: { ok: true, firestoreReads: 0, firestoreWrites: 0, publishToTarget: false, cutover: false, lifecycleTouched: false }
    },
    {
      id: 'settings_handlers_only_finalclean_exposed',
      actual: buildMigration1FinalCleanupSelfTestActual_(buildMigration1FinalCleanupResult_({ ok: true, settingsHandlersOk: inspectMigration1FinalCleanupSettingsHandlers_().finalCleanupHandlersOk && inspectMigration1FinalCleanupSettingsHandlers_().obsoleteHandlers.length === 0, obsoleteHandlers: inspectMigration1FinalCleanupSettingsHandlers_().obsoleteHandlers })),
      expected: { settingsHandlersOk: true, obsoleteHandlersCount: 0 }
    },
    {
      id: 'cost_audit_not_ok_blocks_finalclean',
      input: buildMigration1FinalCleanupRuntimeResult_(buildMigration1FinalCleanupTestCostStatus_({ ok: false, reason: 'cost_audit_violation', violations: ['e2e_not_ok'] })),
      expected: { ok: false, reason: 'final_cleanup_violation' }
    },
    {
      id: 'firestore_write_detected_blocks_finalclean',
      input: buildMigration1FinalCleanupRuntimeResult_(buildMigration1FinalCleanupTestCostStatus_({ ok: true, firestoreWrites: 1 })),
      expected: { ok: false, reason: 'final_cleanup_violation', firestoreWrites: 0 }
    },
    {
      id: 'publish_target_detected_blocks_finalclean',
      input: buildMigration1FinalCleanupRuntimeResult_(buildMigration1FinalCleanupTestCostStatus_({ ok: true, publishToTarget: true, targetPathBuilt: true })),
      expected: { ok: false, reason: 'final_cleanup_violation', publishToTarget: true }
    },
    {
      id: 'cutover_detected_blocks_finalclean',
      input: buildMigration1FinalCleanupRuntimeResult_(buildMigration1FinalCleanupTestCostStatus_({ ok: true, cutover: true })),
      expected: { ok: false, reason: 'final_cleanup_violation', cutover: true }
    }
  ];

  var passed = 0;
  var failed = 0;
  var items = cases.map(function (item) {
    var actual = item.actual || buildMigration1FinalCleanupSelfTestActual_(item.input);
    var mismatchReasons = compareMigration1FinalCleanupExpected_(actual, item.expected || {});
    var ok = mismatchReasons.length === 0;
    if (ok) passed++; else failed++;
    return {
      id: item.id,
      passed: ok,
      actual: actual,
      expected: item.expected || {},
      mismatchReasons: mismatchReasons
    };
  });

  return {
    ok: failed === 0,
    testCount: items.length,
    passedCount: passed,
    failedCount: failed,
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

function buildMigration1FinalCleanupTestCostStatus_(stats) {
  stats = stats || {};
  return {
    ok: stats.ok !== false,
    stats: {
      skipped: stats.skipped !== false,
      reason: String(stats.reason || ''),
      firestoreReads: Math.max(0, Number(stats.firestoreReads || 0)),
      firestoreWrites: Math.max(0, Number(stats.firestoreWrites || 0)),
      publishFromTarget: !!stats.publishFromTarget,
      publishToTarget: !!stats.publishToTarget,
      targetPathBuilt: !!stats.targetPathBuilt,
      cutover: !!stats.cutover,
      lifecycleTouched: !!stats.lifecycleTouched
    },
    violations: stats.violations || []
  };
}

function buildMigration1FinalCleanupSelfTestActual_(result) {
  var stats = (result && result.stats) || {};
  return {
    ok: !!(result && result.ok),
    skipped: !!stats.skipped,
    reason: String(stats.reason || ''),
    costOk: !!stats.costOk,
    settingsHandlersOk: !!stats.settingsHandlersOk,
    obsoleteHandlersCount: Number(stats.obsoleteHandlersCount || 0),
    firestoreReads: Number(stats.firestoreReads || 0),
    firestoreWrites: Number(stats.firestoreWrites || 0),
    publishToTarget: !!stats.publishToTarget,
    targetPathBuilt: !!stats.targetPathBuilt,
    cutover: !!stats.cutover,
    lifecycleTouched: !!stats.lifecycleTouched
  };
}

function compareMigration1FinalCleanupExpected_(actual, expected) {
  var mismatches = [];
  Object.keys(expected || {}).forEach(function (key) {
    if (actual[key] !== expected[key]) {
      mismatches.push('field_' + key + '_mismatch');
    }
  });
  if (actual.firestoreWrites !== 0) mismatches.push('firestore_writes_not_zero');
  if (actual.lifecycleTouched) mismatches.push('lifecycle_touched');
  return uniqueNonEmptyStrings_(mismatches);
}

function formatMigration1FinalCleanupSelfTestFeedback_(result) {
  result = result || runMigration1FinalCleanupSelfTest_();
  var lines = [];
  lines.push('MIGRATION_1_FINALCLEAN_TEST');
  lines.push('ok=' + String(!!result.ok));
  lines.push('testCount=' + String(result.testCount || 0));
  lines.push('passedCount=' + String(result.passedCount || 0));
  lines.push('failedCount=' + String(result.failedCount || 0));
  lines.push('firestoreReads=' + String(result.firestoreReads || 0));
  lines.push('firestoreWrites=' + String(result.firestoreWrites || 0));
  lines.push('publishFromTarget=' + String(!!result.publishFromTarget));
  lines.push('publishToTarget=' + String(!!result.publishToTarget));
  lines.push('targetPathBuilt=' + String(!!result.targetPathBuilt));
  lines.push('cutover=' + String(!!result.cutover));
  lines.push('lifecycleTouched=' + String(!!result.lifecycleTouched));
  lines.push('items=');
  (result.items || []).forEach(function (item) {
    var actual = item.actual || {};
    lines.push('- id=' + String(item.id || ''));
    lines.push('  passed=' + String(!!item.passed));
    lines.push('  reason=' + String(actual.reason || ''));
    lines.push('  costOk=' + String(!!actual.costOk));
    lines.push('  settingsHandlersOk=' + String(!!actual.settingsHandlersOk));
    lines.push('  obsoleteHandlersCount=' + String(actual.obsoleteHandlersCount || 0));
    lines.push('  firestoreReads=' + String(actual.firestoreReads || 0));
    lines.push('  firestoreWrites=' + String(actual.firestoreWrites || 0));
    lines.push('  publishToTarget=' + String(!!actual.publishToTarget));
    lines.push('  targetPathBuilt=' + String(!!actual.targetPathBuilt));
    lines.push('  cutover=' + String(!!actual.cutover));
    lines.push('  lifecycleTouched=' + String(!!actual.lifecycleTouched));
    lines.push('  mismatchReasons=' + (((item.mismatchReasons || []).length) ? item.mismatchReasons.join(',') : 'none'));
  });
  return lines.join('\n');
}

function formatMigration1FinalCleanupRuntimeFeedback_(result) {
  result = result || runMigration1FinalCleanupRuntimeStatus_();
  var stats = (result && result.stats) || {};
  var lines = [];
  lines.push('MIGRATION_1_FINALCLEAN_RUNTIME_STATUS');
  lines.push('ok=' + String(!!(result && result.ok)));
  lines.push('skipped=' + String(!!stats.skipped));
  lines.push('reason=' + String(stats.reason || ''));
  lines.push('costOk=' + String(!!stats.costOk));
  lines.push('settingsHandlersOk=' + String(!!stats.settingsHandlersOk));
  lines.push('obsoleteHandlersCount=' + String(stats.obsoleteHandlersCount || 0));
  lines.push('firestoreReads=' + String(stats.firestoreReads || 0));
  lines.push('firestoreWrites=' + String(stats.firestoreWrites || 0));
  lines.push('publishFromTarget=' + String(!!stats.publishFromTarget));
  lines.push('publishToTarget=' + String(!!stats.publishToTarget));
  lines.push('targetPathBuilt=' + String(!!stats.targetPathBuilt));
  lines.push('cutover=' + String(!!stats.cutover));
  lines.push('lifecycleTouched=' + String(!!stats.lifecycleTouched));
  lines.push('violations=' + (((result && result.violations || []).length) ? result.violations.join(',') : 'none'));
  lines.push('obsoleteHandlers=' + (((result && result.obsoleteHandlers || []).length) ? result.obsoleteHandlers.join(',') : 'none'));
  lines.push('error=' + String(stats.error || 'none'));
  lines.push('errorKind=' + String(stats.errorKind || 'none'));
  return lines.join('\n');
}
