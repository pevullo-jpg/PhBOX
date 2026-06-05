var PHBOX_M2_DOC_VERSION_ = 'M2_DOC_v1';
var PHBOX_M2_DOC_STAGE_ = 'migration2_documentation';
var PHBOX_M2_DOC_REQUIRED_FINALCLEAN_VERSION_ = 'M2_FINALCLEAN_v3';
var PHBOX_M2_DOC_REQUIRED_COST_VERSION_ = 'M2_COST_v3';
var PHBOX_M2_DOC_REQUIRED_E2E_VERSION_ = 'M2_E2E_v1';

function runMigration2DocRuntimeStatus_() {
  try {
    if (typeof runMigration2FinalCleanRuntimeStatus_ !== 'function') {
      throw new Error('M2_DOC_FINALCLEAN_MISSING: funzione runMigration2FinalCleanRuntimeStatus_ non disponibile. Documentazione M2 non verificabile.');
    }
    return buildMigration2DocResult_({
      finalCleanStatus: runMigration2FinalCleanRuntimeStatus_(),
      obsoleteHandlers: listMigration2DocObsoleteSettingsHandlers_()
    });
  } catch (e) {
    return buildMigration2DocResult_({
      finalCleanStatus: null,
      obsoleteHandlers: listMigration2DocObsoleteSettingsHandlers_(),
      error: normalizeRuntimeErrorMessage_(e),
      errorKind: classifyRuntimeFailureKind_(e)
    });
  }
}

function buildMigration2DocResult_(data) {
  data = data || {};
  var finalCleanStatus = data.finalCleanStatus || null;
  var finalCleanStats = (finalCleanStatus && finalCleanStatus.stats) || {};
  var documentationItems = buildMigration2DocItems_();
  var obsoleteHandlers = uniqueNonEmptyStrings_(data.obsoleteHandlers || []);
  var violations = buildMigration2DocViolations_({
    finalCleanPresent: !!(finalCleanStatus && finalCleanStatus.stats),
    finalCleanOk: !!(finalCleanStatus && finalCleanStatus.ok) && finalCleanStats.ok !== false,
    finalCleanVersion: String(finalCleanStats.finalCleanVersion || ''),
    costVersion: String(finalCleanStats.costVersion || ''),
    e2eVersion: String(finalCleanStats.e2eVersion || ''),
    firestoreWrites: Math.max(0, Number(finalCleanStats.firestoreWrites || 0)),
    estimatedWritesPerHour: Math.max(0, Number(finalCleanStats.estimatedWritesPerHour || 0)),
    targetWritesExecuted: Math.max(0, Number(finalCleanStats.targetWritesExecuted || 0)),
    publishFromTarget: !!finalCleanStats.publishFromTarget,
    publishToTarget: !!finalCleanStats.publishToTarget,
    lifecycleTouched: !!finalCleanStats.lifecycleTouched,
    listeners: Math.max(0, Number(finalCleanStats.listeners || 0)),
    queries: Math.max(0, Number(finalCleanStats.queries || 0)),
    fanOut: Math.max(0, Number(finalCleanStats.fanOut || 0)),
    documentationItems: documentationItems,
    obsoleteHandlers: obsoleteHandlers,
    error: data.error
  });

  return buildMigration2DocResultFromStats_({
    ok: violations.length === 0,
    skipped: false,
    reason: violations.length ? 'm2_doc_violation' : 'm2_doc_ready',
    finalCleanVersion: String(finalCleanStats.finalCleanVersion || ''),
    costVersion: String(finalCleanStats.costVersion || ''),
    e2eVersion: String(finalCleanStats.e2eVersion || ''),
    finalCleanOk: !!(finalCleanStatus && finalCleanStatus.ok) && finalCleanStats.ok !== false,
    routeMode: String(finalCleanStats.routeMode || ''),
    routeDecision: String(finalCleanStats.routeDecision || ''),
    dashboardReadDecision: String(finalCleanStats.dashboardReadDecision || ''),
    firestoreReads: Math.max(0, Number(finalCleanStats.firestoreReads || 0)),
    firestoreWrites: Math.max(0, Number(finalCleanStats.firestoreWrites || 0)),
    estimatedReadsPerHour: Math.max(0, Number(finalCleanStats.estimatedReadsPerHour || 0)),
    estimatedWritesPerHour: Math.max(0, Number(finalCleanStats.estimatedWritesPerHour || 0)),
    targetWritesExecuted: Math.max(0, Number(finalCleanStats.targetWritesExecuted || 0)),
    listeners: Math.max(0, Number(finalCleanStats.listeners || 0)),
    queries: Math.max(0, Number(finalCleanStats.queries || 0)),
    fanOut: Math.max(0, Number(finalCleanStats.fanOut || 0)),
    publishFromTarget: !!finalCleanStats.publishFromTarget,
    publishToTarget: !!finalCleanStats.publishToTarget,
    targetPathBuilt: !!finalCleanStats.targetPathBuilt,
    cutover: !!finalCleanStats.cutover,
    lifecycleTouched: !!finalCleanStats.lifecycleTouched,
    documentationItems: documentationItems,
    obsoleteHandlers: obsoleteHandlers,
    violations: violations,
    error: String(data.error || finalCleanStats.error || ''),
    errorKind: String(data.errorKind || finalCleanStats.errorKind || '')
  });
}

function buildMigration2DocViolations_(data) {
  data = data || {};
  var violations = [];
  if (!data.finalCleanPresent) violations.push('finalclean_status_missing');
  if (data.finalCleanPresent && !data.finalCleanOk) violations.push('finalclean_not_ok');
  if (String(data.finalCleanVersion || '') !== PHBOX_M2_DOC_REQUIRED_FINALCLEAN_VERSION_) violations.push('finalclean_version_mismatch');
  if (data.finalCleanPresent && String(data.costVersion || '') !== PHBOX_M2_DOC_REQUIRED_COST_VERSION_) violations.push('cost_version_mismatch');
  if (data.finalCleanPresent && String(data.e2eVersion || '') !== PHBOX_M2_DOC_REQUIRED_E2E_VERSION_) violations.push('e2e_version_mismatch');
  if (Number(data.firestoreWrites || 0) > 0) violations.push('firestore_writes_detected');
  if (Number(data.estimatedWritesPerHour || 0) > 0) violations.push('firestore_writes_per_hour_detected');
  if (Number(data.targetWritesExecuted || 0) > 0) violations.push('target_writes_executed');
  if (data.publishFromTarget || data.publishToTarget) violations.push('publish_detected');
  if (data.lifecycleTouched) violations.push('lifecycle_touched');
  if (Number(data.listeners || 0) > 0) violations.push('listeners_detected');
  if (Number(data.queries || 0) > 0) violations.push('queries_detected');
  if (Number(data.fanOut || 0) > 0) violations.push('fanout_detected');
  if (!Array.isArray(data.documentationItems) || data.documentationItems.length !== 11) violations.push('documentation_items_incomplete');
  if (uniqueNonEmptyStrings_(data.obsoleteHandlers || []).length > 0) violations.push('obsolete_settings_handlers_detected');
  if (data.error) violations.push('m2_doc_error');
  return uniqueNonEmptyStrings_(violations);
}

function buildMigration2DocResultFromStats_(data) {
  data = data || {};
  var stats = buildMigration2DocStats_(data);
  return {
    ok: data.ok !== false,
    stats: stats,
    violations: uniqueNonEmptyStrings_(data.violations || []),
    items: data.documentationItems || []
  };
}

function buildMigration2DocStats_(data) {
  data = data || {};
  return {
    stage: PHBOX_M2_DOC_STAGE_,
    ok: data.ok !== false,
    skipped: data.skipped !== false,
    reason: String(data.reason || ''),
    docVersion: PHBOX_M2_DOC_VERSION_,
    finalCleanVersion: String(data.finalCleanVersion || ''),
    requiredFinalCleanVersion: PHBOX_M2_DOC_REQUIRED_FINALCLEAN_VERSION_,
    costVersion: String(data.costVersion || ''),
    requiredCostVersion: PHBOX_M2_DOC_REQUIRED_COST_VERSION_,
    e2eVersion: String(data.e2eVersion || ''),
    requiredE2eVersion: PHBOX_M2_DOC_REQUIRED_E2E_VERSION_,
    finalCleanOk: !!data.finalCleanOk,
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
    documentationItemsCount: Array.isArray(data.documentationItems) ? data.documentationItems.length : 0,
    documentedStages: (data.documentationItems || []).map(function (item) { return String(item.id || ''); }),
    obsoleteHandlers: uniqueNonEmptyStrings_(data.obsoleteHandlers || []),
    violations: uniqueNonEmptyStrings_(data.violations || []),
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };
}

function buildMigration2DocItems_() {
  return [
    buildMigration2DocItem_('M2-LOCK', 'M2_LOCK_v3', 'Backend GAS', 'lock readiness, no writes'),
    buildMigration2DocItem_('M2-ROUTE', 'M2_ROUTE_v2', 'Backend GAS', 'legacy/dual/target route contract'),
    buildMigration2DocItem_('M2-WRITE', 'M2_WRITE_v1', 'Backend GAS', 'target writes dry-run bounded by executeTargetWrites=false in audits'),
    buildMigration2DocItem_('M2-SIGNAL', 'M2_SIGNAL_v2', 'Backend GAS', 'runtime signal contract without new listeners'),
    buildMigration2DocItem_('M2-DASH', 'M2_DASH_v1', 'Backend GAS', 'dashboard read route decision only'),
    buildMigration2DocItem_('M2-VERIFY', 'M2_VERIFY_v3', 'Backend GAS', 'bounded post-write verify sample'),
    buildMigration2DocItem_('M2-CUTON', 'M2_CUTON_v3', 'Backend GAS', 'cutover authorization diagnostic only'),
    buildMigration2DocItem_('M2-ROLLBACK', 'M2_ROLLBACK_v6', 'Backend GAS', 'controlled legacy restore diagnostic only'),
    buildMigration2DocItem_('M2-E2E', PHBOX_M2_DOC_REQUIRED_E2E_VERSION_, 'Backend GAS', 'end-to-end validation, no lifecycle'),
    buildMigration2DocItem_('M2-COST', PHBOX_M2_DOC_REQUIRED_COST_VERSION_, 'Backend GAS', 'cost audit, hard-block all writes'),
    buildMigration2DocItem_('M2-FINALCLEAN', PHBOX_M2_DOC_REQUIRED_FINALCLEAN_VERSION_, 'Backend GAS', 'final cleanup diagnostic, only current Settings handlers exposed')
  ];
}

function buildMigration2DocItem_(id, version, owner, invariant) {
  return {
    id: String(id || ''),
    version: String(version || ''),
    owner: String(owner || ''),
    invariant: String(invariant || ''),
    contract: 'diagnostic_only',
    firestoreWrites: 0,
    lifecycleTouched: false
  };
}

function listMigration2DocObsoleteSettingsHandlers_() {
  var names = [
    'runMigration2FinalCleanSettingsTest',
    'getMigration2FinalCleanSettingsStatus',
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
    'runMigration2RouteSettingsTest',
    'getMigration2RouteSettingsStatus',
    'runMigration2RouteContractSettingsTest',
    'getMigration2RouteContractSettingsStatus',
    'runMigration2LockSettingsTest',
    'getMigration2LockSettingsStatus',
    'runMigration1FreezeBaselineSettingsTest',
    'getMigration1FreezeBaselineSettingsStatus',
    'runMigration1DocSettingsTest',
    'getMigration1DocSettingsStatus',
    'runMigration1DocumentationSettingsTest',
    'getMigration1DocumentationSettingsStatus',
    'runMigration1FinalCleanupSettingsTest',
    'getMigration1FinalCleanupSettingsStatus',
    'runMigration1CostAuditSettingsTest',
    'getMigration1CostAuditSettingsStatus',
    'runMigration1E2eValidationSettingsTest',
    'getMigration1E2eValidationSettingsStatus',
    'runMigration1E2ESettingsTest',
    'getMigration1E2ESettingsStatus',
    'runMigration1CutoverSettingsTest',
    'getMigration1CutoverSettingsStatus',
    'runMigration1DualVerifierSettingsTest',
    'getMigration1DualVerifierSettingsStatus',
    'runMigration1DashboardCompatibilitySettingsTest',
    'getMigration1DashboardCompatibilitySettingsStatus',
    'runMigration1DashboardCompatSettingsTest',
    'runMigration1DashboardSettingsTest',
    'getMigration1DashboardSettingsStatus',
    'runMigration1RuntimeSignalSettingsTest',
    'getMigration1RuntimeSignalSettingsStatus',
    'runMigration1TargetPublishSettingsTest',
    'getMigration1TargetPublishSettingsStatus',
    'runMigration1TargetRuntimeGateSettingsTest',
    'getMigration1TargetRuntimeGateSettingsStatus',
    'runMigration1BackendIdentityResolverSettingsTest',
    'getMigration1BackendIdentityResolverSettingsStatus',
    'runMigration1IdentityResolverSettingsTest',
    'getMigration1IdentityResolverSettingsStatus',
    'runMigration1ShadowSettingsTest',
    'getMigration1ShadowSettingsStatus'
  ];
  return names.filter(function (name) {
    try {
      if (typeof globalThis !== 'undefined' && typeof globalThis[name] === 'function') return true;
      return typeof this !== 'undefined' && typeof this[name] === 'function';
    } catch (e) {
      return false;
    }
  });
}

function runMigration2DocSelfTest_() {
  var cases = [
    {
      id: 'clean_finalclean_status_documents_m2_chain',
      result: buildMigration2DocResult_({ finalCleanStatus: buildMigration2DocSyntheticFinalCleanStatus_({}) }),
      expected: { ok: true, violation: '', documentationItemsCount: 11 }
    },
    {
      id: 'missing_finalclean_status_blocks_doc',
      result: buildMigration2DocResult_({ finalCleanStatus: null }),
      expected: { ok: false, violation: 'finalclean_status_missing' }
    },
    {
      id: 'finalclean_not_ok_blocks_doc',
      result: buildMigration2DocResult_({ finalCleanStatus: buildMigration2DocSyntheticFinalCleanStatus_({ ok: false }) }),
      expected: { ok: false, violation: 'finalclean_not_ok' }
    },
    {
      id: 'finalclean_version_mismatch_blocks_doc',
      result: buildMigration2DocResult_({ finalCleanStatus: buildMigration2DocSyntheticFinalCleanStatus_({ finalCleanVersion: 'M2_FINALCLEAN_v2' }) }),
      expected: { ok: false, violation: 'finalclean_version_mismatch' }
    },
    {
      id: 'cost_version_mismatch_blocks_doc',
      result: buildMigration2DocResult_({ finalCleanStatus: buildMigration2DocSyntheticFinalCleanStatus_({ costVersion: 'M2_COST_v2' }) }),
      expected: { ok: false, violation: 'cost_version_mismatch' }
    },
    {
      id: 'e2e_version_mismatch_blocks_doc',
      result: buildMigration2DocResult_({ finalCleanStatus: buildMigration2DocSyntheticFinalCleanStatus_({ e2eVersion: 'M2_E2E_v0' }) }),
      expected: { ok: false, violation: 'e2e_version_mismatch' }
    },
    {
      id: 'firestore_write_blocks_doc',
      result: buildMigration2DocResult_({ finalCleanStatus: buildMigration2DocSyntheticFinalCleanStatus_({ firestoreWrites: 1, estimatedWritesPerHour: 12 }) }),
      expected: { ok: false, violation: 'firestore_writes_detected' }
    },
    {
      id: 'target_write_blocks_doc',
      result: buildMigration2DocResult_({ finalCleanStatus: buildMigration2DocSyntheticFinalCleanStatus_({ targetWritesExecuted: 1 }) }),
      expected: { ok: false, violation: 'target_writes_executed' }
    },
    {
      id: 'listener_query_fanout_blocks_doc',
      result: buildMigration2DocResult_({ finalCleanStatus: buildMigration2DocSyntheticFinalCleanStatus_({ listeners: 1, queries: 1, fanOut: 1 }) }),
      expected: { ok: false, violation: 'listeners_detected' }
    },
    {
      id: 'obsolete_settings_handler_blocks_doc',
      result: buildMigration2DocResult_({ finalCleanStatus: buildMigration2DocSyntheticFinalCleanStatus_({}), obsoleteHandlers: ['runMigration2FinalCleanSettingsTest'] }),
      expected: { ok: false, violation: 'obsolete_settings_handlers_detected' }
    },
    {
      id: 'documentation_items_incomplete_blocks_doc',
      result: buildMigration2DocResultFromStats_({ ok: false, reason: 'm2_doc_violation', finalCleanVersion: PHBOX_M2_DOC_REQUIRED_FINALCLEAN_VERSION_, costVersion: PHBOX_M2_DOC_REQUIRED_COST_VERSION_, e2eVersion: PHBOX_M2_DOC_REQUIRED_E2E_VERSION_, documentationItems: [], violations: ['documentation_items_incomplete'] }),
      expected: { ok: false, violation: 'documentation_items_incomplete' }
    }
  ];

  var items = cases.map(function (testCase) {
    var stats = (testCase.result && testCase.result.stats) || {};
    var violations = uniqueNonEmptyStrings_(stats.violations || []);
    var passed = (!!stats.ok) === !!testCase.expected.ok;
    if (testCase.expected.violation) passed = passed && violations.indexOf(testCase.expected.violation) !== -1;
    if (testCase.expected.documentationItemsCount !== undefined) passed = passed && Number(stats.documentationItemsCount || 0) === Number(testCase.expected.documentationItemsCount || 0);
    return {
      id: testCase.id,
      passed: passed,
      ok: !!stats.ok,
      reason: String(stats.reason || ''),
      docVersion: String(stats.docVersion || ''),
      finalCleanVersion: String(stats.finalCleanVersion || ''),
      costVersion: String(stats.costVersion || ''),
      e2eVersion: String(stats.e2eVersion || ''),
      documentationItemsCount: Math.max(0, Number(stats.documentationItemsCount || 0)),
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
    };
  });

  var failed = items.filter(function (item) { return !item.passed; });
  return {
    ok: failed.length === 0,
    stats: {
      stage: PHBOX_M2_DOC_STAGE_ + '_self_test',
      docVersion: PHBOX_M2_DOC_VERSION_,
      finalCleanVersion: PHBOX_M2_DOC_REQUIRED_FINALCLEAN_VERSION_,
      costVersion: PHBOX_M2_DOC_REQUIRED_COST_VERSION_,
      e2eVersion: PHBOX_M2_DOC_REQUIRED_E2E_VERSION_,
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

function buildMigration2DocSyntheticFinalCleanStatus_(overrides) {
  overrides = overrides || {};
  var stats = {
    stage: 'migration2_final_cleanup',
    ok: overrides.ok === false ? false : true,
    skipped: false,
    reason: overrides.ok === false ? 'm2_finalclean_violation' : 'm2_finalclean_ready',
    finalCleanVersion: overrides.finalCleanVersion || PHBOX_M2_DOC_REQUIRED_FINALCLEAN_VERSION_,
    costVersion: overrides.costVersion || PHBOX_M2_DOC_REQUIRED_COST_VERSION_,
    e2eVersion: overrides.e2eVersion || PHBOX_M2_DOC_REQUIRED_E2E_VERSION_,
    routeMode: overrides.routeMode || 'legacy',
    routeDecision: overrides.routeDecision || 'legacy',
    dashboardReadDecision: overrides.dashboardReadDecision || 'legacy',
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
    obsoleteHandlers: uniqueNonEmptyStrings_(overrides.obsoleteHandlers || []),
    violations: uniqueNonEmptyStrings_(overrides.violations || []),
    error: String(overrides.error || ''),
    errorKind: String(overrides.errorKind || '')
  };
  return {
    ok: stats.ok,
    stats: stats,
    items: []
  };
}

function formatMigration2DocSelfTestFeedback_(result) {
  var stats = (result && result.stats) || {};
  var lines = [];
  lines.push('MIGRATION_2_DOC_TEST');
  lines.push('ok=' + String(!!(result && result.ok)));
  lines.push('testCount=' + String(Math.max(0, Number(stats.testCount || 0))));
  lines.push('passedCount=' + String(Math.max(0, Number(stats.passedCount || 0))));
  lines.push('failedCount=' + String(Math.max(0, Number(stats.failedCount || 0))));
  lines.push('docVersion=' + String(stats.docVersion || ''));
  lines.push('finalCleanVersion=' + String(stats.finalCleanVersion || ''));
  lines.push('costVersion=' + String(stats.costVersion || ''));
  lines.push('e2eVersion=' + String(stats.e2eVersion || ''));
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
  lines.push('items=');
  (result.items || []).forEach(function (item) {
    lines.push('- id=' + String(item.id || ''));
    lines.push('  passed=' + String(!!item.passed));
    lines.push('  ok=' + String(!!item.ok));
    lines.push('  reason=' + String(item.reason || ''));
    lines.push('  docVersion=' + String(item.docVersion || ''));
    lines.push('  finalCleanVersion=' + String(item.finalCleanVersion || ''));
    lines.push('  costVersion=' + String(item.costVersion || ''));
    lines.push('  e2eVersion=' + String(item.e2eVersion || ''));
    lines.push('  documentationItemsCount=' + String(Math.max(0, Number(item.documentationItemsCount || 0))));
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
    lines.push('  violations=' + (uniqueNonEmptyStrings_(item.violations || []).join(',') || 'none'));
  });
  return lines.join('\n');
}

function formatMigration2DocRuntimeFeedback_(result) {
  var stats = (result && result.stats) || {};
  var lines = [];
  lines.push('MIGRATION_2_DOC_RUNTIME_STATUS');
  lines.push('ok=' + String(!!(result && result.ok)));
  lines.push('skipped=' + String(!!stats.skipped));
  lines.push('reason=' + String(stats.reason || ''));
  lines.push('docVersion=' + String(stats.docVersion || ''));
  lines.push('finalCleanVersion=' + String(stats.finalCleanVersion || ''));
  lines.push('costVersion=' + String(stats.costVersion || ''));
  lines.push('e2eVersion=' + String(stats.e2eVersion || ''));
  lines.push('finalCleanOk=' + String(!!stats.finalCleanOk));
  lines.push('routeMode=' + String(stats.routeMode || ''));
  lines.push('routeDecision=' + String(stats.routeDecision || ''));
  lines.push('dashboardReadDecision=' + String(stats.dashboardReadDecision || ''));
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
  lines.push('documentationItemsCount=' + String(Math.max(0, Number(stats.documentationItemsCount || 0))));
  lines.push('documentedStages=' + (uniqueNonEmptyStrings_(stats.documentedStages || []).join(',') || 'none'));
  lines.push('obsoleteHandlers=' + (uniqueNonEmptyStrings_(stats.obsoleteHandlers || []).join(',') || 'none'));
  lines.push('violations=' + (uniqueNonEmptyStrings_(stats.violations || []).join(',') || 'none'));
  lines.push('error=' + (String(stats.error || '') || 'none'));
  lines.push('errorKind=' + (String(stats.errorKind || '') || 'none'));
  lines.push('items=');
  (result.items || []).forEach(function (item) {
    lines.push('- id=' + String(item.id || ''));
    lines.push('  version=' + String(item.version || ''));
    lines.push('  owner=' + String(item.owner || ''));
    lines.push('  contract=' + String(item.contract || ''));
    lines.push('  invariant=' + String(item.invariant || ''));
    lines.push('  firestoreWrites=' + String(Math.max(0, Number(item.firestoreWrites || 0))));
    lines.push('  lifecycleTouched=' + String(!!item.lifecycleTouched));
  });
  return lines.join('\n');
}
