var PHBOX_M2_FREEZE_VERSION_ = 'M2_FREEZE_v1';
var PHBOX_M2_FREEZE_STAGE_ = 'migration2_freeze';
var PHBOX_M2_FREEZE_REQUIRED_DOC_VERSION_ = 'M2_DOC_v2';
var PHBOX_M2_FREEZE_REQUIRED_FINALCLEAN_VERSION_ = 'M2_FINALCLEAN_v3';
var PHBOX_M2_FREEZE_REQUIRED_COST_VERSION_ = 'M2_COST_v3';
var PHBOX_M2_FREEZE_REQUIRED_E2E_VERSION_ = 'M2_E2E_v1';
var PHBOX_M2_FREEZE_REQUIRED_DOCUMENTATION_ITEMS_COUNT_ = 11;

function runMigration2FreezeRuntimeStatus_() {
  try {
    if (typeof runMigration2DocRuntimeStatus_ !== 'function') {
      throw new Error('M2_FREEZE_DOC_MISSING: funzione runMigration2DocRuntimeStatus_ non disponibile. Freeze M2 non verificabile.');
    }
    return buildMigration2FreezeResult_({
      docStatus: runMigration2DocRuntimeStatus_(),
      obsoleteHandlers: listMigration2FreezeObsoleteSettingsHandlers_()
    });
  } catch (e) {
    return buildMigration2FreezeResult_({
      docStatus: null,
      obsoleteHandlers: listMigration2FreezeObsoleteSettingsHandlers_(),
      error: normalizeRuntimeErrorMessage_(e),
      errorKind: classifyRuntimeFailureKind_(e)
    });
  }
}

function buildMigration2FreezeResult_(data) {
  data = data || {};
  var docStatus = data.docStatus || null;
  var docStats = (docStatus && docStatus.stats) || {};
  var docItems = (docStatus && docStatus.items) || [];
  var documentedStages = uniqueNonEmptyStrings_(docStats.documentedStages || []);
  var obsoleteHandlers = uniqueNonEmptyStrings_(data.obsoleteHandlers || []);
  var violations = buildMigration2FreezeViolations_({
    docPresent: !!(docStatus && docStatus.stats),
    docOk: !!(docStatus && docStatus.ok) && docStats.ok !== false,
    docVersion: String(docStats.docVersion || ''),
    finalCleanVersion: String(docStats.finalCleanVersion || ''),
    costVersion: String(docStats.costVersion || ''),
    e2eVersion: String(docStats.e2eVersion || ''),
    documentationItemsCount: Math.max(0, Number(docStats.documentationItemsCount || 0)),
    documentedStages: documentedStages,
    firestoreReads: Math.max(0, Number(docStats.firestoreReads || 0)),
    firestoreWrites: Math.max(0, Number(docStats.firestoreWrites || 0)),
    estimatedWritesPerHour: Math.max(0, Number(docStats.estimatedWritesPerHour || 0)),
    targetWritesExecuted: Math.max(0, Number(docStats.targetWritesExecuted || 0)),
    publishFromTarget: !!docStats.publishFromTarget,
    publishToTarget: !!docStats.publishToTarget,
    targetPathBuilt: !!docStats.targetPathBuilt,
    cutover: !!docStats.cutover,
    lifecycleTouched: !!docStats.lifecycleTouched,
    listeners: Math.max(0, Number(docStats.listeners || 0)),
    queries: Math.max(0, Number(docStats.queries || 0)),
    fanOut: Math.max(0, Number(docStats.fanOut || 0)),
    obsoleteHandlers: obsoleteHandlers,
    docItems: docItems,
    error: data.error
  });

  return buildMigration2FreezeResultFromStats_({
    ok: violations.length === 0,
    skipped: false,
    reason: violations.length ? 'm2_freeze_violation' : 'm2_freeze_ready',
    docVersion: String(docStats.docVersion || ''),
    finalCleanVersion: String(docStats.finalCleanVersion || ''),
    costVersion: String(docStats.costVersion || ''),
    e2eVersion: String(docStats.e2eVersion || ''),
    docOk: !!(docStatus && docStatus.ok) && docStats.ok !== false,
    routeMode: String(docStats.routeMode || ''),
    routeDecision: String(docStats.routeDecision || ''),
    dashboardReadDecision: String(docStats.dashboardReadDecision || ''),
    firestoreReads: Math.max(0, Number(docStats.firestoreReads || 0)),
    firestoreWrites: Math.max(0, Number(docStats.firestoreWrites || 0)),
    estimatedReadsPerHour: Math.max(0, Number(docStats.estimatedReadsPerHour || 0)),
    estimatedWritesPerHour: Math.max(0, Number(docStats.estimatedWritesPerHour || 0)),
    targetWritesExecuted: Math.max(0, Number(docStats.targetWritesExecuted || 0)),
    listeners: Math.max(0, Number(docStats.listeners || 0)),
    queries: Math.max(0, Number(docStats.queries || 0)),
    fanOut: Math.max(0, Number(docStats.fanOut || 0)),
    publishFromTarget: !!docStats.publishFromTarget,
    publishToTarget: !!docStats.publishToTarget,
    targetPathBuilt: !!docStats.targetPathBuilt,
    cutover: !!docStats.cutover,
    lifecycleTouched: !!docStats.lifecycleTouched,
    documentationItemsCount: Math.max(0, Number(docStats.documentationItemsCount || 0)),
    documentedStages: documentedStages,
    obsoleteHandlers: obsoleteHandlers,
    violations: violations,
    error: String(data.error || ''),
    errorKind: String(data.errorKind || ''),
    items: buildMigration2FreezeItemSnapshot_(docItems)
  });
}

function buildMigration2FreezeViolations_(data) {
  data = data || {};
  var violations = [];
  if (!data.docPresent) violations.push('doc_status_missing');
  if (data.docPresent && !data.docOk) violations.push('doc_not_ok');
  if (String(data.docVersion || '') !== PHBOX_M2_FREEZE_REQUIRED_DOC_VERSION_) violations.push('doc_version_mismatch');
  if (data.docPresent && String(data.finalCleanVersion || '') !== PHBOX_M2_FREEZE_REQUIRED_FINALCLEAN_VERSION_) violations.push('finalclean_version_mismatch');
  if (data.docPresent && String(data.costVersion || '') !== PHBOX_M2_FREEZE_REQUIRED_COST_VERSION_) violations.push('cost_version_mismatch');
  if (data.docPresent && String(data.e2eVersion || '') !== PHBOX_M2_FREEZE_REQUIRED_E2E_VERSION_) violations.push('e2e_version_mismatch');
  if (Number(data.documentationItemsCount || 0) !== PHBOX_M2_FREEZE_REQUIRED_DOCUMENTATION_ITEMS_COUNT_) violations.push('documentation_items_count_mismatch');
  if (!migration2FreezeHasRequiredDocumentedStages_(data.documentedStages || [])) violations.push('documented_stages_incomplete');
  if (Number(data.firestoreReads || 0) > 0) violations.push('firestore_reads_detected');
  if (Number(data.firestoreWrites || 0) > 0) violations.push('firestore_writes_detected');
  if (Number(data.estimatedWritesPerHour || 0) > 0) violations.push('firestore_writes_per_hour_detected');
  if (Number(data.targetWritesExecuted || 0) > 0) violations.push('target_writes_executed');
  if (data.publishFromTarget || data.publishToTarget) violations.push('publish_detected');
  if (data.targetPathBuilt) violations.push('target_path_built');
  if (data.cutover) violations.push('cutover_detected');
  if (data.lifecycleTouched) violations.push('lifecycle_touched');
  if (Number(data.listeners || 0) > 0) violations.push('listeners_detected');
  if (Number(data.queries || 0) > 0) violations.push('queries_detected');
  if (Number(data.fanOut || 0) > 0) violations.push('fanout_detected');
  if (uniqueNonEmptyStrings_(data.obsoleteHandlers || []).length > 0) violations.push('obsolete_settings_handlers_detected');
  if (migration2FreezeDocItemsContainSideEffects_(data.docItems || [])) violations.push('documented_item_side_effects_detected');
  if (data.error) violations.push('m2_freeze_error');
  return uniqueNonEmptyStrings_(violations);
}

function buildMigration2FreezeResultFromStats_(data) {
  data = data || {};
  var stats = buildMigration2FreezeStats_(data);
  return {
    ok: data.ok !== false,
    stats: stats,
    violations: uniqueNonEmptyStrings_(data.violations || []),
    items: data.items || []
  };
}

function buildMigration2FreezeStats_(data) {
  data = data || {};
  return {
    stage: PHBOX_M2_FREEZE_STAGE_,
    ok: data.ok !== false,
    skipped: data.skipped !== false,
    reason: String(data.reason || ''),
    freezeVersion: PHBOX_M2_FREEZE_VERSION_,
    docVersion: String(data.docVersion || ''),
    requiredDocVersion: PHBOX_M2_FREEZE_REQUIRED_DOC_VERSION_,
    finalCleanVersion: String(data.finalCleanVersion || ''),
    requiredFinalCleanVersion: PHBOX_M2_FREEZE_REQUIRED_FINALCLEAN_VERSION_,
    costVersion: String(data.costVersion || ''),
    requiredCostVersion: PHBOX_M2_FREEZE_REQUIRED_COST_VERSION_,
    e2eVersion: String(data.e2eVersion || ''),
    requiredE2eVersion: PHBOX_M2_FREEZE_REQUIRED_E2E_VERSION_,
    docOk: !!data.docOk,
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
    documentationItemsCount: Math.max(0, Number(data.documentationItemsCount || 0)),
    requiredDocumentationItemsCount: PHBOX_M2_FREEZE_REQUIRED_DOCUMENTATION_ITEMS_COUNT_,
    documentedStages: uniqueNonEmptyStrings_(data.documentedStages || []),
    obsoleteHandlers: uniqueNonEmptyStrings_(data.obsoleteHandlers || []),
    frozen: data.ok !== false,
    violations: uniqueNonEmptyStrings_(data.violations || []),
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };
}

function migration2FreezeRequiredDocumentedStages_() {
  return [
    'M2-LOCK',
    'M2-ROUTE',
    'M2-WRITE',
    'M2-SIGNAL',
    'M2-DASH',
    'M2-VERIFY',
    'M2-CUTON',
    'M2-ROLLBACK',
    'M2-E2E',
    'M2-COST',
    'M2-FINALCLEAN'
  ];
}

function migration2FreezeHasRequiredDocumentedStages_(stages) {
  var present = uniqueNonEmptyStrings_(stages || []);
  var required = migration2FreezeRequiredDocumentedStages_();
  if (present.length !== required.length) return false;
  var index = {};
  present.forEach(function (stage) { index[stage] = true; });
  return required.every(function (stage) { return !!index[stage]; });
}

function migration2FreezeDocItemsContainSideEffects_(items) {
  items = items || [];
  return items.some(function (item) {
    return Number(item && item.firestoreWrites || 0) > 0 || !!(item && item.lifecycleTouched);
  });
}

function buildMigration2FreezeItemSnapshot_(items) {
  items = items || [];
  return items.map(function (item) {
    return {
      id: String(item && item.id || ''),
      version: String(item && item.version || ''),
      owner: String(item && item.owner || ''),
      contract: String(item && item.contract || ''),
      invariant: String(item && item.invariant || ''),
      firestoreWrites: Math.max(0, Number(item && item.firestoreWrites || 0)),
      lifecycleTouched: !!(item && item.lifecycleTouched)
    };
  }).filter(function (item) { return !!item.id; });
}

function listMigration2FreezeObsoleteSettingsHandlers_() {
  var names = [
    'runMigration2DocSettingsTest',
    'getMigration2DocSettingsStatus',
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

function runMigration2FreezeSelfTest_() {
  var cases = [
    {
      id: 'clean_doc_status_freezes_m2_baseline',
      result: buildMigration2FreezeResult_({ docStatus: buildMigration2FreezeSyntheticDocStatus_({}) }),
      expected: { ok: true, violation: '' }
    },
    {
      id: 'missing_doc_status_blocks_freeze',
      result: buildMigration2FreezeResult_({ docStatus: null }),
      expected: { ok: false, violation: 'doc_status_missing' }
    },
    {
      id: 'doc_not_ok_blocks_freeze',
      result: buildMigration2FreezeResult_({ docStatus: buildMigration2FreezeSyntheticDocStatus_({ ok: false }) }),
      expected: { ok: false, violation: 'doc_not_ok' }
    },
    {
      id: 'doc_version_mismatch_blocks_freeze',
      result: buildMigration2FreezeResult_({ docStatus: buildMigration2FreezeSyntheticDocStatus_({ docVersion: 'M2_DOC_v1' }) }),
      expected: { ok: false, violation: 'doc_version_mismatch' }
    },
    {
      id: 'finalclean_version_mismatch_blocks_freeze',
      result: buildMigration2FreezeResult_({ docStatus: buildMigration2FreezeSyntheticDocStatus_({ finalCleanVersion: 'M2_FINALCLEAN_v2' }) }),
      expected: { ok: false, violation: 'finalclean_version_mismatch' }
    },
    {
      id: 'cost_version_mismatch_blocks_freeze',
      result: buildMigration2FreezeResult_({ docStatus: buildMigration2FreezeSyntheticDocStatus_({ costVersion: 'M2_COST_v2' }) }),
      expected: { ok: false, violation: 'cost_version_mismatch' }
    },
    {
      id: 'e2e_version_mismatch_blocks_freeze',
      result: buildMigration2FreezeResult_({ docStatus: buildMigration2FreezeSyntheticDocStatus_({ e2eVersion: 'M2_E2E_v0' }) }),
      expected: { ok: false, violation: 'e2e_version_mismatch' }
    },
    {
      id: 'firestore_read_blocks_freeze',
      result: buildMigration2FreezeResult_({ docStatus: buildMigration2FreezeSyntheticDocStatus_({ firestoreReads: 1 }) }),
      expected: { ok: false, violation: 'firestore_reads_detected' }
    },
    {
      id: 'firestore_write_blocks_freeze',
      result: buildMigration2FreezeResult_({ docStatus: buildMigration2FreezeSyntheticDocStatus_({ firestoreWrites: 1, estimatedWritesPerHour: 12 }) }),
      expected: { ok: false, violation: 'firestore_writes_detected' }
    },
    {
      id: 'target_write_blocks_freeze',
      result: buildMigration2FreezeResult_({ docStatus: buildMigration2FreezeSyntheticDocStatus_({ targetWritesExecuted: 1 }) }),
      expected: { ok: false, violation: 'target_writes_executed' }
    },
    {
      id: 'publish_lifecycle_blocks_freeze',
      result: buildMigration2FreezeResult_({ docStatus: buildMigration2FreezeSyntheticDocStatus_({ publishToTarget: true, lifecycleTouched: true }) }),
      expected: { ok: false, violation: 'publish_detected' }
    },
    {
      id: 'listener_query_fanout_blocks_freeze',
      result: buildMigration2FreezeResult_({ docStatus: buildMigration2FreezeSyntheticDocStatus_({ listeners: 1, queries: 1, fanOut: 1 }) }),
      expected: { ok: false, violation: 'listeners_detected' }
    },
    {
      id: 'obsolete_settings_handler_blocks_freeze',
      result: buildMigration2FreezeResult_({ docStatus: buildMigration2FreezeSyntheticDocStatus_({}), obsoleteHandlers: ['runMigration2DocSettingsTest'] }),
      expected: { ok: false, violation: 'obsolete_settings_handlers_detected' }
    },
    {
      id: 'documentation_items_count_mismatch_blocks_freeze',
      result: buildMigration2FreezeResult_({ docStatus: buildMigration2FreezeSyntheticDocStatus_({ documentationItemsCount: 10 }) }),
      expected: { ok: false, violation: 'documentation_items_count_mismatch' }
    },
    {
      id: 'documented_stages_incomplete_blocks_freeze',
      result: buildMigration2FreezeResult_({ docStatus: buildMigration2FreezeSyntheticDocStatus_({ documentedStages: ['M2-LOCK'] }) }),
      expected: { ok: false, violation: 'documented_stages_incomplete' }
    },
    {
      id: 'documented_item_side_effects_block_freeze',
      result: buildMigration2FreezeResult_({ docStatus: buildMigration2FreezeSyntheticDocStatus_({ itemFirestoreWrites: 1 }) }),
      expected: { ok: false, violation: 'documented_item_side_effects_detected' }
    }
  ];

  var items = cases.map(function (entry) {
    var stats = entry.result.stats || {};
    var violations = uniqueNonEmptyStrings_(stats.violations || []);
    var passed = !!stats.ok === !!entry.expected.ok;
    if (entry.expected.violation) passed = passed && violations.indexOf(entry.expected.violation) !== -1;
    return {
      id: entry.id,
      passed: passed,
      ok: !!stats.ok,
      reason: String(stats.reason || ''),
      freezeVersion: String(stats.freezeVersion || ''),
      docVersion: String(stats.docVersion || ''),
      finalCleanVersion: String(stats.finalCleanVersion || ''),
      costVersion: String(stats.costVersion || ''),
      e2eVersion: String(stats.e2eVersion || ''),
      documentationItemsCount: Math.max(0, Number(stats.documentationItemsCount || 0)),
      firestoreReads: Math.max(0, Number(stats.firestoreReads || 0)),
      firestoreWrites: Math.max(0, Number(stats.firestoreWrites || 0)),
      estimatedWritesPerHour: Math.max(0, Number(stats.estimatedWritesPerHour || 0)),
      targetWritesExecuted: Math.max(0, Number(stats.targetWritesExecuted || 0)),
      listeners: Math.max(0, Number(stats.listeners || 0)),
      queries: Math.max(0, Number(stats.queries || 0)),
      fanOut: Math.max(0, Number(stats.fanOut || 0)),
      publishToTarget: !!stats.publishToTarget,
      targetPathBuilt: !!stats.targetPathBuilt,
      cutover: !!stats.cutover,
      lifecycleTouched: !!stats.lifecycleTouched,
      frozen: !!stats.frozen,
      violations: violations
    };
  });

  var failed = items.filter(function (item) { return !item.passed; });
  return buildMigration2FreezeResultFromStats_({
    ok: failed.length === 0,
    skipped: false,
    reason: failed.length ? 'm2_freeze_selftest_failed' : 'm2_freeze_selftest_passed',
    docVersion: PHBOX_M2_FREEZE_REQUIRED_DOC_VERSION_,
    finalCleanVersion: PHBOX_M2_FREEZE_REQUIRED_FINALCLEAN_VERSION_,
    costVersion: PHBOX_M2_FREEZE_REQUIRED_COST_VERSION_,
    e2eVersion: PHBOX_M2_FREEZE_REQUIRED_E2E_VERSION_,
    docOk: true,
    documentationItemsCount: PHBOX_M2_FREEZE_REQUIRED_DOCUMENTATION_ITEMS_COUNT_,
    documentedStages: migration2FreezeRequiredDocumentedStages_(),
    items: items,
    violations: failed.map(function (item) { return item.id; })
  });
}

function buildMigration2FreezeSyntheticDocStatus_(overrides) {
  overrides = overrides || {};
  var documentedStages = overrides.documentedStages || migration2FreezeRequiredDocumentedStages_();
  var documentationItemsCount = Object.prototype.hasOwnProperty.call(overrides, 'documentationItemsCount')
    ? Math.max(0, Number(overrides.documentationItemsCount || 0))
    : documentedStages.length;
  var items = documentedStages.map(function (stage) {
    return {
      id: stage,
      version: 'synthetic',
      owner: 'Backend GAS',
      contract: 'diagnostic_only',
      invariant: 'synthetic invariant',
      firestoreWrites: Math.max(0, Number(overrides.itemFirestoreWrites || 0)),
      lifecycleTouched: !!overrides.itemLifecycleTouched
    };
  });
  return {
    ok: overrides.ok !== false,
    stats: {
      ok: overrides.ok !== false,
      reason: overrides.ok === false ? 'synthetic_doc_not_ok' : 'm2_doc_ready',
      docVersion: String(overrides.docVersion || PHBOX_M2_FREEZE_REQUIRED_DOC_VERSION_),
      finalCleanVersion: String(overrides.finalCleanVersion || PHBOX_M2_FREEZE_REQUIRED_FINALCLEAN_VERSION_),
      costVersion: String(overrides.costVersion || PHBOX_M2_FREEZE_REQUIRED_COST_VERSION_),
      e2eVersion: String(overrides.e2eVersion || PHBOX_M2_FREEZE_REQUIRED_E2E_VERSION_),
      finalCleanOk: overrides.finalCleanOk !== false,
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
      documentationItemsCount: documentationItemsCount,
      documentedStages: documentedStages,
      obsoleteHandlers: uniqueNonEmptyStrings_(overrides.obsoleteHandlers || []),
      violations: uniqueNonEmptyStrings_(overrides.violations || []),
      error: String(overrides.error || ''),
      errorKind: String(overrides.errorKind || '')
    },
    items: items
  };
}

function formatMigration2FreezeSelfTestFeedback_(result) {
  result = result || {};
  var stats = result.stats || {};
  var lines = [];
  var items = result.items || [];
  var passed = items.filter(function (item) { return !!item.passed; }).length;
  lines.push('MIGRATION_2_FREEZE_TEST');
  lines.push('ok=' + String(!!result.ok));
  lines.push('testCount=' + String(items.length));
  lines.push('passedCount=' + String(passed));
  lines.push('failedCount=' + String(items.length - passed));
  migration2FreezeAppendCommonFeedbackLines_(lines, stats);
  lines.push('items=');
  items.forEach(function (item) {
    lines.push('- id=' + String(item.id || ''));
    lines.push('  passed=' + String(!!item.passed));
    lines.push('  ok=' + String(!!item.ok));
    lines.push('  reason=' + String(item.reason || ''));
    lines.push('  freezeVersion=' + String(item.freezeVersion || ''));
    lines.push('  docVersion=' + String(item.docVersion || ''));
    lines.push('  finalCleanVersion=' + String(item.finalCleanVersion || ''));
    lines.push('  costVersion=' + String(item.costVersion || ''));
    lines.push('  e2eVersion=' + String(item.e2eVersion || ''));
    lines.push('  documentationItemsCount=' + String(Math.max(0, Number(item.documentationItemsCount || 0))));
    lines.push('  firestoreReads=' + String(Math.max(0, Number(item.firestoreReads || 0))));
    lines.push('  firestoreWrites=' + String(Math.max(0, Number(item.firestoreWrites || 0))));
    lines.push('  estimatedWritesPerHour=' + String(Math.max(0, Number(item.estimatedWritesPerHour || 0))));
    lines.push('  targetWritesExecuted=' + String(Math.max(0, Number(item.targetWritesExecuted || 0))));
    lines.push('  listeners=' + String(Math.max(0, Number(item.listeners || 0))));
    lines.push('  queries=' + String(Math.max(0, Number(item.queries || 0))));
    lines.push('  fanOut=' + String(Math.max(0, Number(item.fanOut || 0))));
    lines.push('  publishToTarget=' + String(!!item.publishToTarget));
    lines.push('  targetPathBuilt=' + String(!!item.targetPathBuilt));
    lines.push('  cutover=' + String(!!item.cutover));
    lines.push('  lifecycleTouched=' + String(!!item.lifecycleTouched));
    lines.push('  frozen=' + String(!!item.frozen));
    lines.push('  violations=' + migration2FreezeJoinList_(item.violations));
  });
  return lines.join('\n');
}

function formatMigration2FreezeRuntimeFeedback_(result) {
  result = result || {};
  var stats = result.stats || {};
  var lines = [];
  lines.push('MIGRATION_2_FREEZE_RUNTIME_STATUS');
  lines.push('ok=' + String(!!result.ok));
  lines.push('skipped=' + String(!!stats.skipped));
  migration2FreezeAppendCommonFeedbackLines_(lines, stats);
  lines.push('routeMode=' + String(stats.routeMode || ''));
  lines.push('routeDecision=' + String(stats.routeDecision || ''));
  lines.push('dashboardReadDecision=' + String(stats.dashboardReadDecision || ''));
  lines.push('obsoleteHandlers=' + migration2FreezeJoinList_(stats.obsoleteHandlers));
  lines.push('violations=' + migration2FreezeJoinList_(stats.violations));
  lines.push('error=' + (stats.error || 'none'));
  lines.push('errorKind=' + (stats.errorKind || 'none'));
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

function migration2FreezeAppendCommonFeedbackLines_(lines, stats) {
  stats = stats || {};
  lines.push('reason=' + String(stats.reason || ''));
  lines.push('freezeVersion=' + String(stats.freezeVersion || ''));
  lines.push('docVersion=' + String(stats.docVersion || ''));
  lines.push('finalCleanVersion=' + String(stats.finalCleanVersion || ''));
  lines.push('costVersion=' + String(stats.costVersion || ''));
  lines.push('e2eVersion=' + String(stats.e2eVersion || ''));
  lines.push('docOk=' + String(!!stats.docOk));
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
  lines.push('documentedStages=' + migration2FreezeJoinList_(stats.documentedStages));
  lines.push('frozen=' + String(!!stats.frozen));
}

function migration2FreezeJoinList_(value) {
  var items = uniqueNonEmptyStrings_(value || []);
  return items.length ? items.join(',') : 'none';
}
