var PHBOX_M2_FINALCLEAN_VERSION_ = 'M2_FINALCLEAN_v2';
var PHBOX_M2_FINALCLEAN_STAGE_ = 'migration2_final_cleanup';
var PHBOX_M2_FINALCLEAN_REQUIRED_COST_VERSION_ = 'M2_COST_v3';
var PHBOX_M2_FINALCLEAN_REQUIRED_E2E_VERSION_ = 'M2_E2E_v1';

function runMigration2FinalCleanRuntimeStatus_() {
  try {
    if (typeof runMigration2CostAuditRuntimeStatus_ !== 'function') {
      throw new Error('M2_FINALCLEAN_COST_MISSING: funzione runMigration2CostAuditRuntimeStatus_ non disponibile. Final clean M2 non verificabile.');
    }
    return buildMigration2FinalCleanResult_({
      costStatus: runMigration2CostAuditRuntimeStatus_(),
      obsoleteHandlers: listMigration2FinalCleanObsoleteSettingsHandlers_()
    });
  } catch (e) {
    return buildMigration2FinalCleanResult_({
      costStatus: null,
      obsoleteHandlers: listMigration2FinalCleanObsoleteSettingsHandlers_(),
      error: normalizeRuntimeErrorMessage_(e),
      errorKind: classifyRuntimeFailureKind_(e)
    });
  }
}

function buildMigration2FinalCleanResult_(data) {
  data = data || {};
  var costStatus = data.costStatus || null;
  var costStats = (costStatus && costStatus.stats) || {};
  var obsoleteHandlers = uniqueNonEmptyStrings_(data.obsoleteHandlers || []);
  var violations = buildMigration2FinalCleanViolations_({
    costPresent: !!(costStatus && costStatus.stats),
    costOk: !!(costStatus && costStatus.ok) && costStats.ok !== false,
    costVersion: String(costStats.costVersion || ''),
    e2eVersion: String(costStats.e2eVersion || ''),
    firestoreWrites: Math.max(0, Number(costStats.firestoreWrites || 0)),
    estimatedWritesPerHour: Math.max(0, Number(costStats.estimatedWritesPerHour || 0)),
    targetWritesExecuted: Math.max(0, Number(costStats.targetWritesExecuted || 0)),
    publishFromTarget: !!costStats.publishFromTarget,
    publishToTarget: !!costStats.publishToTarget,
    lifecycleTouched: !!costStats.lifecycleTouched,
    listeners: Math.max(0, Number(costStats.listeners || 0)),
    queries: Math.max(0, Number(costStats.queries || 0)),
    fanOut: Math.max(0, Number(costStats.fanOut || 0)),
    obsoleteHandlers: obsoleteHandlers,
    error: data.error
  });

  return buildMigration2FinalCleanResultFromStats_({
    ok: violations.length === 0,
    skipped: false,
    reason: violations.length ? 'm2_finalclean_violation' : 'm2_finalclean_ready',
    costVersion: String(costStats.costVersion || ''),
    e2eVersion: String(costStats.e2eVersion || ''),
    costOk: !!(costStatus && costStatus.ok) && costStats.ok !== false,
    routeMode: String(costStats.routeMode || ''),
    routeDecision: String(costStats.routeDecision || ''),
    dashboardReadDecision: String(costStats.dashboardReadDecision || ''),
    firestoreReads: Math.max(0, Number(costStats.firestoreReads || 0)),
    firestoreWrites: Math.max(0, Number(costStats.firestoreWrites || 0)),
    estimatedReadsPerHour: Math.max(0, Number(costStats.estimatedReadsPerHour || 0)),
    estimatedWritesPerHour: Math.max(0, Number(costStats.estimatedWritesPerHour || 0)),
    targetWritesExecuted: Math.max(0, Number(costStats.targetWritesExecuted || 0)),
    listeners: Math.max(0, Number(costStats.listeners || 0)),
    queries: Math.max(0, Number(costStats.queries || 0)),
    fanOut: Math.max(0, Number(costStats.fanOut || 0)),
    publishFromTarget: !!costStats.publishFromTarget,
    publishToTarget: !!costStats.publishToTarget,
    targetPathBuilt: !!costStats.targetPathBuilt,
    cutover: !!costStats.cutover,
    lifecycleTouched: !!costStats.lifecycleTouched,
    obsoleteHandlers: obsoleteHandlers,
    violations: violations,
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  });
}

function buildMigration2FinalCleanViolations_(data) {
  data = data || {};
  var violations = [];
  if (!data.costPresent) violations.push('cost_status_missing');
  if (data.costPresent && !data.costOk) violations.push('cost_not_ok');
  if (String(data.costVersion || '') !== PHBOX_M2_FINALCLEAN_REQUIRED_COST_VERSION_) violations.push('cost_version_mismatch');
  if (data.costPresent && String(data.e2eVersion || '') !== PHBOX_M2_FINALCLEAN_REQUIRED_E2E_VERSION_) violations.push('e2e_version_mismatch');
  if (Number(data.firestoreWrites || 0) > 0) violations.push('firestore_writes_detected');
  if (Number(data.estimatedWritesPerHour || 0) > 0) violations.push('firestore_writes_per_hour_detected');
  if (Number(data.targetWritesExecuted || 0) > 0) violations.push('target_writes_executed');
  if (data.publishFromTarget || data.publishToTarget) violations.push('publish_detected');
  if (data.lifecycleTouched) violations.push('lifecycle_touched');
  if (Number(data.listeners || 0) > 0) violations.push('listeners_detected');
  if (Number(data.queries || 0) > 0) violations.push('queries_detected');
  if (Number(data.fanOut || 0) > 0) violations.push('fanout_detected');
  if (uniqueNonEmptyStrings_(data.obsoleteHandlers || []).length > 0) violations.push('obsolete_settings_handlers_detected');
  if (data.error) violations.push('m2_finalclean_error');
  return uniqueNonEmptyStrings_(violations);
}

function buildMigration2FinalCleanResultFromStats_(data) {
  data = data || {};
  var stats = buildMigration2FinalCleanStats_(data);
  return {
    ok: data.ok !== false,
    stats: stats,
    violations: uniqueNonEmptyStrings_(data.violations || []),
    items: data.items || []
  };
}

function buildMigration2FinalCleanStats_(data) {
  data = data || {};
  return {
    stage: PHBOX_M2_FINALCLEAN_STAGE_,
    ok: data.ok !== false,
    skipped: data.skipped !== false,
    reason: String(data.reason || ''),
    finalCleanVersion: PHBOX_M2_FINALCLEAN_VERSION_,
    costVersion: String(data.costVersion || ''),
    requiredCostVersion: PHBOX_M2_FINALCLEAN_REQUIRED_COST_VERSION_,
    e2eVersion: String(data.e2eVersion || ''),
    requiredE2eVersion: PHBOX_M2_FINALCLEAN_REQUIRED_E2E_VERSION_,
    costOk: !!data.costOk,
    routeMode: String(data.routeMode || ''),
    routeDecision: String(data.routeDecision || ''),
    dashboardReadDecision: String(data.dashboardReadDecision || ''),
    firestoreReads: Math.max(0, Number(data.firestoreReads || 0)),
    firestoreWrites: Math.max(0, Number(data.firestoreWrites || 0)),
    estimatedReadsPerHour: Math.max(0, Number(data.estimatedReadsPerHour || 0)),
    estimatedWritesPerHour: Math.max(0, Number(data.estimatedWritesPerHour || 0)),
    targetWritesExecuted: Math.max(0, Number(data.targetWritesExecuted || 0)),
    listeners: Math.max(0, Number(data.listeners || 0)),
    queries: Math.max(0, Number(data.queries || 0)),
    fanOut: Math.max(0, Number(data.fanOut || 0)),
    publishFromTarget: !!data.publishFromTarget,
    publishToTarget: !!data.publishToTarget,
    targetPathBuilt: !!data.targetPathBuilt,
    cutover: !!data.cutover,
    lifecycleTouched: !!data.lifecycleTouched,
    obsoleteHandlers: uniqueNonEmptyStrings_(data.obsoleteHandlers || []),
    violations: uniqueNonEmptyStrings_(data.violations || []),
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };
}

function listMigration2FinalCleanObsoleteSettingsHandlers_() {
  var names = [
    'runMigration2CostAuditSettingsTest',
    'getMigration2CostAuditSettingsStatus',
    'runMigration2E2eSettingsTest',
    'getMigration2E2eSettingsStatus',
    'runMigration2RollbackSettingsTest',
    'getMigration2RollbackSettingsStatus',
    'runMigration2CutonSettingsTest',
    'getMigration2CutonSettingsStatus',
    'runMigration2PostWriteVerifySettingsTest',
    'getMigration2PostWriteVerifySettingsStatus',
    'runMigration2DashboardReadSettingsTest',
    'getMigration2DashboardReadSettingsStatus',
    'runMigration2RuntimeSignalSettingsTest',
    'getMigration2RuntimeSignalSettingsStatus',
    'runMigration2TargetWriteSettingsTest',
    'getMigration2TargetWriteSettingsStatus',
    'runMigration2RouteContractSettingsTest',
    'getMigration2RouteContractSettingsStatus',
    'runMigration2LockSettingsTest',
    'getMigration2LockSettingsStatus',
    'runMigration1FreezeSettingsTest',
    'getMigration1FreezeSettingsStatus',
    'runMigration1DocSettingsTest',
    'getMigration1DocSettingsStatus',
    'runMigration1FinalCleanSettingsTest',
    'getMigration1FinalCleanSettingsStatus',
    'runMigration1CostSettingsTest',
    'getMigration1CostSettingsStatus',
    'runMigration1E2eSettingsTest',
    'getMigration1E2eSettingsStatus',
    'runMigration1CutSettingsTest',
    'getMigration1CutSettingsStatus',
    'runMigration1DualSettingsTest',
    'getMigration1DualSettingsStatus',
    'runMigration1DashboardSettingsTest',
    'getMigration1DashboardSettingsStatus',
    'runMigration1SignatureSettingsTest',
    'getMigration1SignatureSettingsStatus',
    'runMigration1PublishSettingsTest',
    'getMigration1PublishSettingsStatus',
    'runMigration1GateSettingsTest',
    'getMigration1GateSettingsStatus',
    'runMigration1IdResolutionSettingsTest',
    'getMigration1IdResolutionSettingsStatus',
    'runMigration1ShadowSettingsTest',
    'getMigration1ShadowSettingsStatus'
  ];
  var found = [];
  names.forEach(function (name) {
    if (typeof globalThis !== 'undefined' && typeof globalThis[name] === 'function') found.push(name);
    else if (typeof this !== 'undefined' && typeof this[name] === 'function') found.push(name);
  });
  return uniqueNonEmptyStrings_(found);
}

function runMigration2FinalCleanSelfTest_() {
  var cases = [
    {
      id: 'clean_cost_status_passes',
      result: buildMigration2FinalCleanResult_({ costStatus: buildMigration2FinalCleanSyntheticCostStatus_({}) }),
      expected: { ok: true, violation: '' }
    },
    {
      id: 'missing_cost_status_blocks_finalclean',
      result: buildMigration2FinalCleanResult_({ costStatus: null }),
      expected: { ok: false, violation: 'cost_status_missing' }
    },
    {
      id: 'cost_not_ok_blocks_finalclean',
      result: buildMigration2FinalCleanResult_({ costStatus: buildMigration2FinalCleanSyntheticCostStatus_({ ok: false }) }),
      expected: { ok: false, violation: 'cost_not_ok' }
    },
    {
      id: 'cost_version_mismatch_blocks_finalclean',
      result: buildMigration2FinalCleanResult_({ costStatus: buildMigration2FinalCleanSyntheticCostStatus_({ costVersion: 'M2_COST_v2' }) }),
      expected: { ok: false, violation: 'cost_version_mismatch' }
    },
    {
      id: 'e2e_version_mismatch_blocks_finalclean',
      result: buildMigration2FinalCleanResult_({ costStatus: buildMigration2FinalCleanSyntheticCostStatus_({ e2eVersion: 'M2_E2E_v0' }) }),
      expected: { ok: false, violation: 'e2e_version_mismatch' }
    },
    {
      id: 'firestore_write_blocks_finalclean',
      result: buildMigration2FinalCleanResult_({ costStatus: buildMigration2FinalCleanSyntheticCostStatus_({ firestoreWrites: 1, estimatedWritesPerHour: 12 }) }),
      expected: { ok: false, violation: 'firestore_writes_detected' }
    },
    {
      id: 'target_write_blocks_finalclean',
      result: buildMigration2FinalCleanResult_({ costStatus: buildMigration2FinalCleanSyntheticCostStatus_({ targetWritesExecuted: 1 }) }),
      expected: { ok: false, violation: 'target_writes_executed' }
    },
    {
      id: 'publish_blocks_finalclean',
      result: buildMigration2FinalCleanResult_({ costStatus: buildMigration2FinalCleanSyntheticCostStatus_({ publishToTarget: true, targetPathBuilt: true }) }),
      expected: { ok: false, violation: 'publish_detected' }
    },
    {
      id: 'lifecycle_touch_blocks_finalclean',
      result: buildMigration2FinalCleanResult_({ costStatus: buildMigration2FinalCleanSyntheticCostStatus_({ lifecycleTouched: true }) }),
      expected: { ok: false, violation: 'lifecycle_touched' }
    },
    {
      id: 'listener_query_fanout_blocks_finalclean',
      result: buildMigration2FinalCleanResult_({ costStatus: buildMigration2FinalCleanSyntheticCostStatus_({ listeners: 1, queries: 1, fanOut: 1 }) }),
      expected: { ok: false, violation: 'listeners_detected' }
    },
    {
      id: 'obsolete_settings_handler_blocks_finalclean',
      result: buildMigration2FinalCleanResult_({ costStatus: buildMigration2FinalCleanSyntheticCostStatus_({}), obsoleteHandlers: ['runMigration2CostAuditSettingsTest'] }),
      expected: { ok: false, violation: 'obsolete_settings_handlers_detected' }
    }
  ];

  var items = [];
  cases.forEach(function (testCase) {
    var stats = (testCase.result && testCase.result.stats) || {};
    var violations = uniqueNonEmptyStrings_(stats.violations || []);
    var expected = testCase.expected || {};
    var passed = (testCase.result && testCase.result.ok) === expected.ok;
    if (expected.violation) passed = passed && violations.indexOf(expected.violation) !== -1;
    if (!expected.violation) passed = passed && violations.length === 0;
    items.push({
      id: testCase.id,
      passed: !!passed,
      ok: !!(testCase.result && testCase.result.ok),
      reason: String(stats.reason || ''),
      finalCleanVersion: String(stats.finalCleanVersion || ''),
      costVersion: String(stats.costVersion || ''),
      e2eVersion: String(stats.e2eVersion || ''),
      firestoreReads: Math.max(0, Number(stats.firestoreReads || 0)),
      firestoreWrites: Math.max(0, Number(stats.firestoreWrites || 0)),
      estimatedReadsPerHour: Math.max(0, Number(stats.estimatedReadsPerHour || 0)),
      estimatedWritesPerHour: Math.max(0, Number(stats.estimatedWritesPerHour || 0)),
      targetWritesExecuted: Math.max(0, Number(stats.targetWritesExecuted || 0)),
      listeners: Math.max(0, Number(stats.listeners || 0)),
      queries: Math.max(0, Number(stats.queries || 0)),
      fanOut: Math.max(0, Number(stats.fanOut || 0)),
      publishToTarget: !!stats.publishToTarget,
      targetPathBuilt: !!stats.targetPathBuilt,
      lifecycleTouched: !!stats.lifecycleTouched,
      violations: violations
    });
  });

  var failed = items.filter(function (item) { return !item.passed; });
  return {
    ok: failed.length === 0,
    stats: {
      stage: PHBOX_M2_FINALCLEAN_STAGE_,
      ok: failed.length === 0,
      finalCleanVersion: PHBOX_M2_FINALCLEAN_VERSION_,
      costVersion: PHBOX_M2_FINALCLEAN_REQUIRED_COST_VERSION_,
      e2eVersion: PHBOX_M2_FINALCLEAN_REQUIRED_E2E_VERSION_,
      testCount: items.length,
      passedCount: items.length - failed.length,
      failedCount: failed.length,
      firestoreReads: 0,
      firestoreWrites: 0,
      estimatedReadsPerHour: 0,
      estimatedWritesPerHour: 0,
      targetWritesExecuted: 0,
      listeners: 0,
      queries: 0,
      fanOut: 0,
      publishFromTarget: false,
      publishToTarget: false,
      targetPathBuilt: false,
      cutover: false,
      lifecycleTouched: false
    },
    items: items
  };
}

function buildMigration2FinalCleanSyntheticCostStatus_(overrides) {
  overrides = overrides || {};
  var ok = overrides.ok === false ? false : true;
  return {
    ok: ok,
    stats: {
      ok: ok,
      reason: ok ? 'm2_cost_within_budget' : 'm2_cost_violation',
      costVersion: String(overrides.costVersion || PHBOX_M2_FINALCLEAN_REQUIRED_COST_VERSION_),
      e2eVersion: String(overrides.e2eVersion || PHBOX_M2_FINALCLEAN_REQUIRED_E2E_VERSION_),
      routeMode: String(overrides.routeMode || 'legacy'),
      routeDecision: String(overrides.routeDecision || 'legacy'),
      dashboardReadDecision: String(overrides.dashboardReadDecision || 'legacy'),
      firestoreReads: Math.max(0, Number(overrides.firestoreReads || 0)),
      firestoreWrites: Math.max(0, Number(overrides.firestoreWrites || 0)),
      estimatedReadsPerHour: Math.max(0, Number(overrides.estimatedReadsPerHour || 0)),
      estimatedWritesPerHour: Math.max(0, Number(overrides.estimatedWritesPerHour || 0)),
      targetWritesExecuted: Math.max(0, Number(overrides.targetWritesExecuted || 0)),
      listeners: Math.max(0, Number(overrides.listeners || 0)),
      queries: Math.max(0, Number(overrides.queries || 0)),
      fanOut: Math.max(0, Number(overrides.fanOut || 0)),
      publishFromTarget: !!overrides.publishFromTarget,
      publishToTarget: !!overrides.publishToTarget,
      targetPathBuilt: !!overrides.targetPathBuilt,
      cutover: !!overrides.cutover,
      lifecycleTouched: !!overrides.lifecycleTouched,
      violations: uniqueNonEmptyStrings_(overrides.violations || [])
    },
    items: []
  };
}

function formatMigration2FinalCleanSelfTestFeedback_(result) {
  result = result || {};
  var stats = result.stats || {};
  var lines = [];
  lines.push('MIGRATION_2_FINALCLEAN_TEST');
  appendMigration2FinalCleanStatsFeedback_(lines, stats, true);
  lines.push('items=');
  (result.items || []).forEach(function (item) {
    lines.push('- id=' + String(item.id || ''));
    lines.push('  passed=' + String(!!item.passed));
    lines.push('  ok=' + String(!!item.ok));
    lines.push('  reason=' + String(item.reason || ''));
    lines.push('  finalCleanVersion=' + String(item.finalCleanVersion || ''));
    lines.push('  costVersion=' + String(item.costVersion || ''));
    lines.push('  e2eVersion=' + String(item.e2eVersion || ''));
    lines.push('  firestoreReads=' + String(Math.max(0, Number(item.firestoreReads || 0))));
    lines.push('  firestoreWrites=' + String(Math.max(0, Number(item.firestoreWrites || 0))));
    lines.push('  estimatedReadsPerHour=' + String(Math.max(0, Number(item.estimatedReadsPerHour || 0))));
    lines.push('  estimatedWritesPerHour=' + String(Math.max(0, Number(item.estimatedWritesPerHour || 0))));
    lines.push('  targetWritesExecuted=' + String(Math.max(0, Number(item.targetWritesExecuted || 0))));
    lines.push('  listeners=' + String(Math.max(0, Number(item.listeners || 0))));
    lines.push('  queries=' + String(Math.max(0, Number(item.queries || 0))));
    lines.push('  fanOut=' + String(Math.max(0, Number(item.fanOut || 0))));
    lines.push('  publishToTarget=' + String(!!item.publishToTarget));
    lines.push('  targetPathBuilt=' + String(!!item.targetPathBuilt));
    lines.push('  lifecycleTouched=' + String(!!item.lifecycleTouched));
    lines.push('  violations=' + migration2FinalCleanJoinList_(item.violations));
  });
  return lines.join('\n');
}

function formatMigration2FinalCleanRuntimeFeedback_(result) {
  result = result || {};
  var stats = result.stats || {};
  var lines = [];
  lines.push('MIGRATION_2_FINALCLEAN_RUNTIME_STATUS');
  appendMigration2FinalCleanStatsFeedback_(lines, stats, false);
  lines.push('obsoleteHandlers=' + migration2FinalCleanJoinList_(stats.obsoleteHandlers));
  lines.push('violations=' + migration2FinalCleanJoinList_(stats.violations));
  lines.push('error=' + (String(stats.error || '') || 'none'));
  lines.push('errorKind=' + (String(stats.errorKind || '') || 'none'));
  return lines.join('\n');
}

function appendMigration2FinalCleanStatsFeedback_(lines, stats, includeTestCounts) {
  stats = stats || {};
  lines.push('ok=' + String(!!stats.ok));
  if (!includeTestCounts) lines.push('skipped=' + String(!!stats.skipped));
  if (!includeTestCounts) lines.push('reason=' + String(stats.reason || ''));
  if (includeTestCounts) lines.push('testCount=' + String(Math.max(0, Number(stats.testCount || 0))));
  if (includeTestCounts) lines.push('passedCount=' + String(Math.max(0, Number(stats.passedCount || 0))));
  if (includeTestCounts) lines.push('failedCount=' + String(Math.max(0, Number(stats.failedCount || 0))));
  lines.push('finalCleanVersion=' + String(stats.finalCleanVersion || ''));
  lines.push('costVersion=' + String(stats.costVersion || ''));
  lines.push('e2eVersion=' + String(stats.e2eVersion || ''));
  if (!includeTestCounts) lines.push('costOk=' + String(!!stats.costOk));
  if (!includeTestCounts) lines.push('routeMode=' + String(stats.routeMode || ''));
  if (!includeTestCounts) lines.push('routeDecision=' + String(stats.routeDecision || ''));
  if (!includeTestCounts) lines.push('dashboardReadDecision=' + String(stats.dashboardReadDecision || ''));
  lines.push('firestoreReads=' + String(Math.max(0, Number(stats.firestoreReads || 0))));
  lines.push('firestoreWrites=' + String(Math.max(0, Number(stats.firestoreWrites || 0))));
  lines.push('estimatedReadsPerHour=' + String(Math.max(0, Number(stats.estimatedReadsPerHour || 0))));
  lines.push('estimatedWritesPerHour=' + String(Math.max(0, Number(stats.estimatedWritesPerHour || 0))));
  lines.push('targetWritesExecuted=' + String(Math.max(0, Number(stats.targetWritesExecuted || 0))));
  lines.push('listeners=' + String(Math.max(0, Number(stats.listeners || 0))));
  lines.push('queries=' + String(Math.max(0, Number(stats.queries || 0))));
  lines.push('fanOut=' + String(Math.max(0, Number(stats.fanOut || 0))));
  lines.push('publishFromTarget=' + String(!!stats.publishFromTarget));
  lines.push('publishToTarget=' + String(!!stats.publishToTarget));
  lines.push('targetPathBuilt=' + String(!!stats.targetPathBuilt));
  lines.push('cutover=' + String(!!stats.cutover));
  lines.push('lifecycleTouched=' + String(!!stats.lifecycleTouched));
}

function migration2FinalCleanJoinList_(items) {
  var values = uniqueNonEmptyStrings_(items || []);
  return values.length ? values.join(',') : 'none';
}
