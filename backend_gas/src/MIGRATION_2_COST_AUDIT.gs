var PHBOX_M2_COST_VERSION_ = 'M2_COST_v2';
var PHBOX_M2_COST_STAGE_ = 'migration2_cost_audit';
var PHBOX_M2_COST_REQUIRED_E2E_VERSION_ = 'M2_E2E_v1';
var PHBOX_M2_COST_MAX_READS_PER_RUN_PROPERTY_ = 'PHBOX_M2_COST_MAX_READS_PER_RUN';
var PHBOX_M2_COST_MAX_WRITES_PER_RUN_PROPERTY_ = 'PHBOX_M2_COST_MAX_WRITES_PER_RUN';
var PHBOX_M2_COST_MAX_READS_PER_HOUR_PROPERTY_ = 'PHBOX_M2_COST_MAX_READS_PER_HOUR';
var PHBOX_M2_COST_MAX_WRITES_PER_HOUR_PROPERTY_ = 'PHBOX_M2_COST_MAX_WRITES_PER_HOUR';
var PHBOX_M2_COST_RUNS_PER_HOUR_PROPERTY_ = 'PHBOX_M2_COST_RUNS_PER_HOUR';
var PHBOX_M2_COST_DEFAULT_MAX_READS_PER_RUN_ = 20;
var PHBOX_M2_COST_DEFAULT_MAX_WRITES_PER_RUN_ = 0;
var PHBOX_M2_COST_DEFAULT_RUNS_PER_HOUR_ = 12;
var PHBOX_M2_COST_DEFAULT_MAX_READS_PER_HOUR_ = PHBOX_M2_COST_DEFAULT_MAX_READS_PER_RUN_ * PHBOX_M2_COST_DEFAULT_RUNS_PER_HOUR_;
var PHBOX_M2_COST_DEFAULT_MAX_WRITES_PER_HOUR_ = 0;

function runMigration2CostAuditRuntimeStatus_() {
  try {
    if (typeof runMigration2E2eRuntimeStatus_ !== 'function') {
      throw new Error('M2_COST_E2E_MISSING: funzione runMigration2E2eRuntimeStatus_ non disponibile. Costo M2 non verificabile.');
    }
    var e2eStatus = runMigration2E2eRuntimeStatus_();
    return buildMigration2CostAuditRuntimeResult_(e2eStatus, readMigration2CostAuditBudgets_(), listMigration2CostAuditObsoleteSettingsHandlers_());
  } catch (e) {
    return buildMigration2CostAuditResult_({
      ok: false,
      skipped: true,
      reason: 'm2_cost_runtime_error',
      e2eOk: false,
      error: normalizeRuntimeErrorMessage_(e),
      errorKind: classifyRuntimeFailureKind_(e)
    });
  }
}

function readMigration2CostAuditBudgets_() {
  var props = PropertiesService.getScriptProperties();
  var runsPerHour = readMigration2CostAuditBudgetValue_(props, PHBOX_M2_COST_RUNS_PER_HOUR_PROPERTY_, PHBOX_M2_COST_DEFAULT_RUNS_PER_HOUR_);
  return {
    maxReadsPerRun: readMigration2CostAuditBudgetValue_(props, PHBOX_M2_COST_MAX_READS_PER_RUN_PROPERTY_, PHBOX_M2_COST_DEFAULT_MAX_READS_PER_RUN_),
    maxWritesPerRun: readMigration2CostAuditBudgetValue_(props, PHBOX_M2_COST_MAX_WRITES_PER_RUN_PROPERTY_, PHBOX_M2_COST_DEFAULT_MAX_WRITES_PER_RUN_),
    maxReadsPerHour: readMigration2CostAuditBudgetValue_(props, PHBOX_M2_COST_MAX_READS_PER_HOUR_PROPERTY_, PHBOX_M2_COST_DEFAULT_MAX_READS_PER_HOUR_),
    maxWritesPerHour: readMigration2CostAuditBudgetValue_(props, PHBOX_M2_COST_MAX_WRITES_PER_HOUR_PROPERTY_, PHBOX_M2_COST_DEFAULT_MAX_WRITES_PER_HOUR_),
    runsPerHour: runsPerHour
  };
}

function readMigration2CostAuditBudgetValue_(props, propertyName, defaultValue) {
  var raw = props ? props.getProperty(propertyName) : null;
  if (raw === null || raw === undefined || String(raw).trim() === '') return Math.max(0, Number(defaultValue || 0));
  var parsed = Number(String(raw).trim());
  return isNaN(parsed) ? Math.max(0, Number(defaultValue || 0)) : Math.max(0, parsed);
}

function resolveMigration2CostAuditBudget_(budgets, key, defaultValue) {
  if (budgets && Object.prototype.hasOwnProperty.call(budgets, key)) {
    var parsed = Number(budgets[key]);
    return isNaN(parsed) ? Math.max(0, Number(defaultValue || 0)) : Math.max(0, parsed);
  }
  return Math.max(0, Number(defaultValue || 0));
}

function buildMigration2CostAuditRuntimeResult_(e2eStatus, budgets, obsoleteHandlers) {
  var e2eStats = (e2eStatus && e2eStatus.stats) || {};
  var firestoreReads = Math.max(0, Number(e2eStats.firestoreReads || 0));
  var firestoreWrites = Math.max(0, Number(e2eStats.firestoreWrites || 0));
  var runsPerHour = resolveMigration2CostAuditBudget_(budgets, 'runsPerHour', PHBOX_M2_COST_DEFAULT_RUNS_PER_HOUR_);
  var maxReadsPerRun = resolveMigration2CostAuditBudget_(budgets, 'maxReadsPerRun', PHBOX_M2_COST_DEFAULT_MAX_READS_PER_RUN_);
  var maxWritesPerRun = resolveMigration2CostAuditBudget_(budgets, 'maxWritesPerRun', PHBOX_M2_COST_DEFAULT_MAX_WRITES_PER_RUN_);
  var maxReadsPerHour = resolveMigration2CostAuditBudget_(budgets, 'maxReadsPerHour', PHBOX_M2_COST_DEFAULT_MAX_READS_PER_HOUR_);
  var maxWritesPerHour = resolveMigration2CostAuditBudget_(budgets, 'maxWritesPerHour', PHBOX_M2_COST_DEFAULT_MAX_WRITES_PER_HOUR_);
  var estimatedReadsPerHour = firestoreReads * runsPerHour;
  var estimatedWritesPerHour = firestoreWrites * runsPerHour;
  var handlers = uniqueNonEmptyStrings_(obsoleteHandlers || []);
  var violations = buildMigration2CostAuditViolations_({
    e2eOk: !!(e2eStatus && e2eStatus.ok) && e2eStats.ok !== false,
    e2eVersion: String(e2eStats.e2eVersion || ''),
    firestoreReads: firestoreReads,
    firestoreWrites: firestoreWrites,
    estimatedReadsPerHour: estimatedReadsPerHour,
    estimatedWritesPerHour: estimatedWritesPerHour,
    maxReadsPerRun: maxReadsPerRun,
    maxWritesPerRun: maxWritesPerRun,
    maxReadsPerHour: maxReadsPerHour,
    maxWritesPerHour: maxWritesPerHour,
    targetWritesExecuted: Math.max(0, Number(e2eStats.targetWritesExecuted || 0)),
    publishFromTarget: !!e2eStats.publishFromTarget,
    publishToTarget: !!e2eStats.publishToTarget,
    lifecycleTouched: !!e2eStats.lifecycleTouched,
    obsoleteHandlers: handlers
  });

  return buildMigration2CostAuditResult_({
    ok: violations.length === 0,
    skipped: false,
    reason: violations.length ? 'm2_cost_violation' : 'm2_cost_within_budget',
    e2eOk: !!(e2eStatus && e2eStatus.ok) && e2eStats.ok !== false,
    e2eVersion: String(e2eStats.e2eVersion || ''),
    routeMode: String(e2eStats.routeMode || ''),
    routeDecision: String(e2eStats.routeDecision || ''),
    dashboardReadDecision: String(e2eStats.dashboardReadDecision || ''),
    tenantId: String(e2eStats.tenantId || ''),
    tenantCanonical: !!e2eStats.tenantCanonical,
    targetReadWriteAuthorized: !!e2eStats.targetReadWriteAuthorized,
    targetRouteAuthorized: !!e2eStats.targetRouteAuthorized,
    targetWriteAuthorized: !!e2eStats.targetWriteAuthorized,
    targetReadAuthorized: !!e2eStats.targetReadAuthorized,
    targetVerifyAuthorized: !!e2eStats.targetVerifyAuthorized,
    cutonEnabled: !!e2eStats.cutonEnabled,
    cutoverAuthorized: !!e2eStats.cutoverAuthorized,
    rollbackEnabled: !!e2eStats.rollbackEnabled,
    rollbackAuthorized: !!e2eStats.rollbackAuthorized,
    legacyRouteActive: !!e2eStats.legacyRouteActive,
    dualCheckPlanned: !!e2eStats.dualCheckPlanned,
    legacyPathsSeen: Math.max(0, Number(e2eStats.legacyPathsSeen || 0)),
    legacyPathsCompared: Math.max(0, Number(e2eStats.legacyPathsCompared || 0)),
    mismatchedCount: Math.max(0, Number(e2eStats.mismatchedCount || 0)),
    missingLegacyCount: Math.max(0, Number(e2eStats.missingLegacyCount || 0)),
    missingTargetCount: Math.max(0, Number(e2eStats.missingTargetCount || 0)),
    targetWritesPlanned: Math.max(0, Number(e2eStats.targetWritesPlanned || 0)),
    targetWritesExecuted: Math.max(0, Number(e2eStats.targetWritesExecuted || 0)),
    firestoreReads: firestoreReads,
    firestoreWrites: firestoreWrites,
    runsPerHour: runsPerHour,
    estimatedReadsPerHour: estimatedReadsPerHour,
    estimatedWritesPerHour: estimatedWritesPerHour,
    maxReadsPerRun: maxReadsPerRun,
    maxWritesPerRun: maxWritesPerRun,
    maxReadsPerHour: maxReadsPerHour,
    maxWritesPerHour: maxWritesPerHour,
    listeners: 0,
    queries: 0,
    fanOut: 0,
    publishFromTarget: !!e2eStats.publishFromTarget,
    publishToTarget: !!e2eStats.publishToTarget,
    targetPathBuilt: !!e2eStats.targetPathBuilt,
    cutover: !!e2eStats.cutover,
    lifecycleTouched: !!e2eStats.lifecycleTouched,
    failedStages: uniqueNonEmptyStrings_(e2eStats.failedStages || []),
    obsoleteHandlers: handlers,
    violations: violations,
    error: String(e2eStats.error || ''),
    errorKind: String(e2eStats.errorKind || '')
  });
}

function buildMigration2CostAuditViolations_(data) {
  data = data || {};
  var violations = [];
  if (!data.e2eOk) violations.push('e2e_not_ok');
  if (String(data.e2eVersion || '') !== PHBOX_M2_COST_REQUIRED_E2E_VERSION_) violations.push('e2e_version_mismatch');
  if (Number(data.firestoreReads || 0) > Number(data.maxReadsPerRun || 0)) violations.push('firestore_reads_per_run_over_budget');
  if (Number(data.firestoreWrites || 0) > Number(data.maxWritesPerRun || 0)) violations.push('firestore_writes_per_run_over_budget');
  if (Number(data.estimatedReadsPerHour || 0) > Number(data.maxReadsPerHour || 0)) violations.push('firestore_reads_per_hour_over_budget');
  if (Number(data.estimatedWritesPerHour || 0) > Number(data.maxWritesPerHour || 0)) violations.push('firestore_writes_per_hour_over_budget');
  if (Number(data.targetWritesExecuted || 0) !== 0) violations.push('target_writes_executed');
  if (data.publishFromTarget) violations.push('publish_from_target_detected');
  if (data.publishToTarget) violations.push('publish_to_target_detected');
  if (data.lifecycleTouched) violations.push('lifecycle_touched');
  if (uniqueNonEmptyStrings_(data.obsoleteHandlers || []).length > 0) violations.push('obsolete_settings_handlers_detected');
  return uniqueNonEmptyStrings_(violations);
}

function buildMigration2CostAuditResult_(data) {
  data = data || {};
  var stats = buildMigration2CostAuditStats_(data);
  return {
    ok: data.ok !== false,
    stats: stats,
    violations: uniqueNonEmptyStrings_(data.violations || []),
    items: data.items || []
  };
}

function buildMigration2CostAuditStats_(data) {
  data = data || {};
  return {
    stage: PHBOX_M2_COST_STAGE_,
    ok: data.ok !== false,
    skipped: data.skipped !== false,
    reason: String(data.reason || ''),
    costVersion: PHBOX_M2_COST_VERSION_,
    e2eVersion: String(data.e2eVersion || ''),
    requiredE2eVersion: PHBOX_M2_COST_REQUIRED_E2E_VERSION_,
    e2eOk: !!data.e2eOk,
    routeMode: String(data.routeMode || ''),
    routeDecision: String(data.routeDecision || ''),
    dashboardReadDecision: String(data.dashboardReadDecision || ''),
    tenantId: String(data.tenantId || ''),
    tenantCanonical: !!data.tenantCanonical,
    targetReadWriteAuthorized: !!data.targetReadWriteAuthorized,
    targetRouteAuthorized: !!data.targetRouteAuthorized,
    targetWriteAuthorized: !!data.targetWriteAuthorized,
    targetReadAuthorized: !!data.targetReadAuthorized,
    targetVerifyAuthorized: !!data.targetVerifyAuthorized,
    cutonEnabled: !!data.cutonEnabled,
    cutoverAuthorized: !!data.cutoverAuthorized,
    rollbackEnabled: !!data.rollbackEnabled,
    rollbackAuthorized: !!data.rollbackAuthorized,
    legacyRouteActive: !!data.legacyRouteActive,
    dualCheckPlanned: !!data.dualCheckPlanned,
    legacyPathsSeen: Math.max(0, Number(data.legacyPathsSeen || 0)),
    legacyPathsCompared: Math.max(0, Number(data.legacyPathsCompared || 0)),
    mismatchedCount: Math.max(0, Number(data.mismatchedCount || 0)),
    missingLegacyCount: Math.max(0, Number(data.missingLegacyCount || 0)),
    missingTargetCount: Math.max(0, Number(data.missingTargetCount || 0)),
    targetWritesPlanned: Math.max(0, Number(data.targetWritesPlanned || 0)),
    targetWritesExecuted: Math.max(0, Number(data.targetWritesExecuted || 0)),
    firestoreReads: Math.max(0, Number(data.firestoreReads || 0)),
    firestoreWrites: Math.max(0, Number(data.firestoreWrites || 0)),
    runsPerHour: resolveMigration2CostAuditBudget_(data, 'runsPerHour', PHBOX_M2_COST_DEFAULT_RUNS_PER_HOUR_),
    estimatedReadsPerHour: Math.max(0, Number(data.estimatedReadsPerHour || 0)),
    estimatedWritesPerHour: Math.max(0, Number(data.estimatedWritesPerHour || 0)),
    maxReadsPerRun: resolveMigration2CostAuditBudget_(data, 'maxReadsPerRun', PHBOX_M2_COST_DEFAULT_MAX_READS_PER_RUN_),
    maxWritesPerRun: resolveMigration2CostAuditBudget_(data, 'maxWritesPerRun', PHBOX_M2_COST_DEFAULT_MAX_WRITES_PER_RUN_),
    maxReadsPerHour: resolveMigration2CostAuditBudget_(data, 'maxReadsPerHour', PHBOX_M2_COST_DEFAULT_MAX_READS_PER_HOUR_),
    maxWritesPerHour: resolveMigration2CostAuditBudget_(data, 'maxWritesPerHour', PHBOX_M2_COST_DEFAULT_MAX_WRITES_PER_HOUR_),
    listeners: Math.max(0, Number(data.listeners || 0)),
    queries: Math.max(0, Number(data.queries || 0)),
    fanOut: Math.max(0, Number(data.fanOut || 0)),
    publishFromTarget: !!data.publishFromTarget,
    publishToTarget: !!data.publishToTarget,
    targetPathBuilt: !!data.targetPathBuilt,
    cutover: !!data.cutover,
    lifecycleTouched: !!data.lifecycleTouched,
    failedStages: uniqueNonEmptyStrings_(data.failedStages || []),
    failedStagesCount: uniqueNonEmptyStrings_(data.failedStages || []).length,
    obsoleteHandlersCount: uniqueNonEmptyStrings_(data.obsoleteHandlers || []).length,
    obsoleteHandlers: uniqueNonEmptyStrings_(data.obsoleteHandlers || []),
    violations: uniqueNonEmptyStrings_(data.violations || []),
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };
}

function runMigration2CostAuditSelfTest_() {
  var cases = [
    {
      id: 'legacy_e2e_zero_cost_passes',
      input: buildMigration2CostAuditRuntimeResult_(buildMigration2CostAuditTestE2eStatus_(true, { e2eVersion: PHBOX_M2_COST_REQUIRED_E2E_VERSION_, routeDecision: 'legacy', dashboardReadDecision: 'legacy', legacyRouteActive: true }), { maxReadsPerRun: 20, maxWritesPerRun: 0, maxReadsPerHour: 240, maxWritesPerHour: 0, runsPerHour: 12 }, []),
      expected: { ok: true, reason: 'm2_cost_within_budget', firestoreReads: 0, firestoreWrites: 0, estimatedReadsPerHour: 0, violation: '' }
    },
    {
      id: 'bounded_verify_reads_pass',
      input: buildMigration2CostAuditRuntimeResult_(buildMigration2CostAuditTestE2eStatus_(true, { e2eVersion: PHBOX_M2_COST_REQUIRED_E2E_VERSION_, routeDecision: 'target', dashboardReadDecision: 'target', targetVerifyAuthorized: true, legacyPathsCompared: 2, firestoreReads: 4 }), { maxReadsPerRun: 20, maxWritesPerRun: 0, maxReadsPerHour: 240, maxWritesPerHour: 0, runsPerHour: 12 }, []),
      expected: { ok: true, reason: 'm2_cost_within_budget', firestoreReads: 4, estimatedReadsPerHour: 48, violation: '' }
    },
    {
      id: 'read_per_run_budget_exceeded_fails',
      input: buildMigration2CostAuditRuntimeResult_(buildMigration2CostAuditTestE2eStatus_(true, { e2eVersion: PHBOX_M2_COST_REQUIRED_E2E_VERSION_, firestoreReads: 21 }), { maxReadsPerRun: 20, maxWritesPerRun: 0, maxReadsPerHour: 240, maxWritesPerHour: 0, runsPerHour: 12 }, []),
      expected: { ok: false, reason: 'm2_cost_violation', violation: 'firestore_reads_per_run_over_budget' }
    },
    {
      id: 'read_per_hour_budget_exceeded_fails',
      input: buildMigration2CostAuditRuntimeResult_(buildMigration2CostAuditTestE2eStatus_(true, { e2eVersion: PHBOX_M2_COST_REQUIRED_E2E_VERSION_, firestoreReads: 9 }), { maxReadsPerRun: 20, maxWritesPerRun: 0, maxReadsPerHour: 100, maxWritesPerHour: 0, runsPerHour: 12 }, []),
      expected: { ok: false, reason: 'm2_cost_violation', estimatedReadsPerHour: 108, violation: 'firestore_reads_per_hour_over_budget' }
    },
    {
      id: 'write_budget_exceeded_fails',
      input: buildMigration2CostAuditRuntimeResult_(buildMigration2CostAuditTestE2eStatus_(true, { e2eVersion: PHBOX_M2_COST_REQUIRED_E2E_VERSION_, firestoreWrites: 1 }), { maxReadsPerRun: 20, maxWritesPerRun: 0, maxReadsPerHour: 240, maxWritesPerHour: 0, runsPerHour: 12 }, []),
      expected: { ok: false, reason: 'm2_cost_violation', violation: 'firestore_writes_per_run_over_budget' }
    },
    {
      id: 'target_writes_executed_fails',
      input: buildMigration2CostAuditRuntimeResult_(buildMigration2CostAuditTestE2eStatus_(true, { e2eVersion: PHBOX_M2_COST_REQUIRED_E2E_VERSION_, targetWritesExecuted: 1 }), { maxReadsPerRun: 20, maxWritesPerRun: 0, maxReadsPerHour: 240, maxWritesPerHour: 0, runsPerHour: 12 }, []),
      expected: { ok: false, reason: 'm2_cost_violation', violation: 'target_writes_executed' }
    },
    {
      id: 'publish_to_target_detected_fails',
      input: buildMigration2CostAuditRuntimeResult_(buildMigration2CostAuditTestE2eStatus_(true, { e2eVersion: PHBOX_M2_COST_REQUIRED_E2E_VERSION_, publishToTarget: true, targetPathBuilt: true }), { maxReadsPerRun: 20, maxWritesPerRun: 0, maxReadsPerHour: 240, maxWritesPerHour: 0, runsPerHour: 12 }, []),
      expected: { ok: false, reason: 'm2_cost_violation', violation: 'publish_to_target_detected' }
    },
    {
      id: 'lifecycle_touch_blocks_cost',
      input: buildMigration2CostAuditRuntimeResult_(buildMigration2CostAuditTestE2eStatus_(true, { e2eVersion: PHBOX_M2_COST_REQUIRED_E2E_VERSION_, lifecycleTouched: true }), { maxReadsPerRun: 20, maxWritesPerRun: 0, maxReadsPerHour: 240, maxWritesPerHour: 0, runsPerHour: 12 }, []),
      expected: { ok: false, reason: 'm2_cost_violation', violation: 'lifecycle_touched' }
    },
    {
      id: 'e2e_not_ok_fails',
      input: buildMigration2CostAuditRuntimeResult_(buildMigration2CostAuditTestE2eStatus_(false, { e2eVersion: PHBOX_M2_COST_REQUIRED_E2E_VERSION_, failedStages: ['verify'], firestoreReads: 4 }), { maxReadsPerRun: 20, maxWritesPerRun: 0, maxReadsPerHour: 240, maxWritesPerHour: 0, runsPerHour: 12 }, []),
      expected: { ok: false, reason: 'm2_cost_violation', violation: 'e2e_not_ok' }
    },
    {
      id: 'e2e_version_mismatch_fails',
      input: buildMigration2CostAuditRuntimeResult_(buildMigration2CostAuditTestE2eStatus_(true, { e2eVersion: 'M2_E2E_old' }), { maxReadsPerRun: 20, maxWritesPerRun: 0, maxReadsPerHour: 240, maxWritesPerHour: 0, runsPerHour: 12 }, []),
      expected: { ok: false, reason: 'm2_cost_violation', violation: 'e2e_version_mismatch' }
    },
    {
      id: 'obsolete_settings_handler_blocks_cost',
      input: buildMigration2CostAuditRuntimeResult_(buildMigration2CostAuditTestE2eStatus_(true, { e2eVersion: PHBOX_M2_COST_REQUIRED_E2E_VERSION_ }), { maxReadsPerRun: 20, maxWritesPerRun: 0, maxReadsPerHour: 240, maxWritesPerHour: 0, runsPerHour: 12 }, ['runMigration2E2eSettingsTest']),
      expected: { ok: false, reason: 'm2_cost_violation', violation: 'obsolete_settings_handlers_detected' }
    }
  ];
  var passed = 0;
  var failed = 0;
  var items = cases.map(function (item) {
    var actual = buildMigration2CostAuditSelfTestActual_(item.input);
    var mismatchReasons = compareMigration2CostAuditExpected_(item.input, actual, item.expected || {});
    var ok = mismatchReasons.length === 0;
    if (ok) passed++; else failed++;
    return { id: item.id, passed: ok, actual: actual, expected: item.expected || {}, mismatchReasons: mismatchReasons };
  });
  return {
    ok: failed === 0,
    testCount: items.length,
    passedCount: passed,
    failedCount: failed,
    costVersion: PHBOX_M2_COST_VERSION_,
    e2eVersion: PHBOX_M2_COST_REQUIRED_E2E_VERSION_,
    firestoreReads: 0,
    firestoreWrites: 0,
    estimatedReadsPerHour: 0,
    estimatedWritesPerHour: 0,
    listeners: 0,
    queries: 0,
    fanOut: 0,
    publishFromTarget: false,
    publishToTarget: false,
    targetPathBuilt: false,
    cutover: false,
    lifecycleTouched: false,
    items: items
  };
}

function buildMigration2CostAuditTestE2eStatus_(ok, stats) {
  stats = stats || {};
  if (!Object.prototype.hasOwnProperty.call(stats, 'e2eVersion')) stats.e2eVersion = PHBOX_M2_COST_REQUIRED_E2E_VERSION_;
  return {
    ok: ok !== false,
    stats: stats
  };
}

function buildMigration2CostAuditSelfTestActual_(result) {
  var stats = (result && result.stats) || {};
  return {
    ok: !!(result && result.ok),
    skipped: !!stats.skipped,
    reason: String(stats.reason || ''),
    costVersion: String(stats.costVersion || ''),
    e2eVersion: String(stats.e2eVersion || ''),
    e2eOk: !!stats.e2eOk,
    routeDecision: String(stats.routeDecision || ''),
    dashboardReadDecision: String(stats.dashboardReadDecision || ''),
    legacyPathsCompared: Number(stats.legacyPathsCompared || 0),
    targetWritesExecuted: Number(stats.targetWritesExecuted || 0),
    firestoreReads: Number(stats.firestoreReads || 0),
    firestoreWrites: Number(stats.firestoreWrites || 0),
    runsPerHour: Number(stats.runsPerHour || 0),
    estimatedReadsPerHour: Number(stats.estimatedReadsPerHour || 0),
    estimatedWritesPerHour: Number(stats.estimatedWritesPerHour || 0),
    maxReadsPerRun: Number(stats.maxReadsPerRun || 0),
    maxWritesPerRun: Number(stats.maxWritesPerRun || 0),
    maxReadsPerHour: Number(stats.maxReadsPerHour || 0),
    maxWritesPerHour: Number(stats.maxWritesPerHour || 0),
    listeners: Number(stats.listeners || 0),
    queries: Number(stats.queries || 0),
    fanOut: Number(stats.fanOut || 0),
    publishToTarget: !!stats.publishToTarget,
    targetPathBuilt: !!stats.targetPathBuilt,
    cutover: !!stats.cutover,
    lifecycleTouched: !!stats.lifecycleTouched,
    failedStages: uniqueNonEmptyStrings_(stats.failedStages || []),
    violations: uniqueNonEmptyStrings_((result && result.violations) || stats.violations || [])
  };
}

function compareMigration2CostAuditExpected_(result, actual, expected) {
  var mismatches = [];
  Object.keys(expected || {}).forEach(function (key) {
    if (key === 'violation') {
      if (expected[key] && actual.violations.indexOf(expected[key]) === -1) mismatches.push('missing_violation_' + expected[key]);
      if (!expected[key] && actual.violations.length > 0) mismatches.push('unexpected_violations');
    } else if (actual[key] !== expected[key]) {
      mismatches.push('field_' + key + '_mismatch');
    }
  });
  if (actual.lifecycleTouched && !(expected && expected.violation === 'lifecycle_touched')) mismatches.push('unexpected_lifecycle_touched');
  if (actual.firestoreWrites > 0 && !(expected && (expected.violation === 'firestore_writes_per_run_over_budget' || expected.violation === 'firestore_writes_per_hour_over_budget'))) mismatches.push('unexpected_firestore_writes');
  if (actual.listeners !== 0) mismatches.push('listeners_not_zero');
  if (actual.queries !== 0) mismatches.push('queries_not_zero');
  if (result && result.stats && result.stats.stage !== PHBOX_M2_COST_STAGE_) mismatches.push('stage_mismatch');
  return uniqueNonEmptyStrings_(mismatches);
}

function listMigration2CostAuditObsoleteSettingsHandlers_() {
  var names = [
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
      return typeof this[name] === 'function';
    } catch (e) {
      return false;
    }
  });
}

function formatMigration2CostAuditSelfTestFeedback_(result) {
  result = result || runMigration2CostAuditSelfTest_();
  var lines = [];
  lines.push('MIGRATION_2_COST_TEST');
  lines.push('ok=' + String(!!result.ok));
  lines.push('testCount=' + String(result.testCount || 0));
  lines.push('passedCount=' + String(result.passedCount || 0));
  lines.push('failedCount=' + String(result.failedCount || 0));
  lines.push('costVersion=' + String(result.costVersion || ''));
  lines.push('e2eVersion=' + String(result.e2eVersion || ''));
  lines.push('firestoreReads=' + String(result.firestoreReads || 0));
  lines.push('firestoreWrites=' + String(result.firestoreWrites || 0));
  lines.push('estimatedReadsPerHour=' + String(result.estimatedReadsPerHour || 0));
  lines.push('estimatedWritesPerHour=' + String(result.estimatedWritesPerHour || 0));
  lines.push('listeners=' + String(result.listeners || 0));
  lines.push('queries=' + String(result.queries || 0));
  lines.push('fanOut=' + String(result.fanOut || 0));
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
    lines.push('  ok=' + String(!!actual.ok));
    lines.push('  reason=' + String(actual.reason || ''));
    lines.push('  firestoreReads=' + String(actual.firestoreReads || 0));
    lines.push('  firestoreWrites=' + String(actual.firestoreWrites || 0));
    lines.push('  runsPerHour=' + String(actual.runsPerHour || 0));
    lines.push('  estimatedReadsPerHour=' + String(actual.estimatedReadsPerHour || 0));
    lines.push('  estimatedWritesPerHour=' + String(actual.estimatedWritesPerHour || 0));
    lines.push('  maxReadsPerRun=' + String(actual.maxReadsPerRun || 0));
    lines.push('  maxWritesPerRun=' + String(actual.maxWritesPerRun || 0));
    lines.push('  maxReadsPerHour=' + String(actual.maxReadsPerHour || 0));
    lines.push('  maxWritesPerHour=' + String(actual.maxWritesPerHour || 0));
    lines.push('  listeners=' + String(actual.listeners || 0));
    lines.push('  queries=' + String(actual.queries || 0));
    lines.push('  fanOut=' + String(actual.fanOut || 0));
    lines.push('  publishToTarget=' + String(!!actual.publishToTarget));
    lines.push('  targetPathBuilt=' + String(!!actual.targetPathBuilt));
    lines.push('  lifecycleTouched=' + String(!!actual.lifecycleTouched));
    lines.push('  violations=' + (actual.violations.length ? actual.violations.join(',') : 'none'));
    lines.push('  mismatchReasons=' + ((item.mismatchReasons || []).length ? item.mismatchReasons.join(',') : 'none'));
  });
  return lines.join('\n');
}

function formatMigration2CostAuditRuntimeFeedback_(result) {
  result = result || runMigration2CostAuditRuntimeStatus_();
  var stats = (result && result.stats) || {};
  var violations = uniqueNonEmptyStrings_((result && result.violations) || stats.violations || []);
  var lines = [];
  lines.push('MIGRATION_2_COST_RUNTIME_STATUS');
  lines.push('ok=' + String(!!(result && result.ok)));
  lines.push('skipped=' + String(!!stats.skipped));
  lines.push('reason=' + String(stats.reason || ''));
  lines.push('costVersion=' + String(stats.costVersion || ''));
  lines.push('e2eVersion=' + String(stats.e2eVersion || ''));
  lines.push('requiredE2eVersion=' + String(stats.requiredE2eVersion || ''));
  lines.push('e2eOk=' + String(!!stats.e2eOk));
  lines.push('routeMode=' + String(stats.routeMode || ''));
  lines.push('routeDecision=' + String(stats.routeDecision || ''));
  lines.push('dashboardReadDecision=' + String(stats.dashboardReadDecision || ''));
  lines.push('tenantId=' + String(stats.tenantId || ''));
  lines.push('tenantCanonical=' + String(!!stats.tenantCanonical));
  lines.push('targetReadWriteAuthorized=' + String(!!stats.targetReadWriteAuthorized));
  lines.push('targetRouteAuthorized=' + String(!!stats.targetRouteAuthorized));
  lines.push('targetWriteAuthorized=' + String(!!stats.targetWriteAuthorized));
  lines.push('targetReadAuthorized=' + String(!!stats.targetReadAuthorized));
  lines.push('targetVerifyAuthorized=' + String(!!stats.targetVerifyAuthorized));
  lines.push('cutonEnabled=' + String(!!stats.cutonEnabled));
  lines.push('cutoverAuthorized=' + String(!!stats.cutoverAuthorized));
  lines.push('rollbackEnabled=' + String(!!stats.rollbackEnabled));
  lines.push('rollbackAuthorized=' + String(!!stats.rollbackAuthorized));
  lines.push('legacyRouteActive=' + String(!!stats.legacyRouteActive));
  lines.push('dualCheckPlanned=' + String(!!stats.dualCheckPlanned));
  lines.push('legacyPathsSeen=' + String(stats.legacyPathsSeen || 0));
  lines.push('legacyPathsCompared=' + String(stats.legacyPathsCompared || 0));
  lines.push('mismatchedCount=' + String(stats.mismatchedCount || 0));
  lines.push('missingLegacyCount=' + String(stats.missingLegacyCount || 0));
  lines.push('missingTargetCount=' + String(stats.missingTargetCount || 0));
  lines.push('targetWritesPlanned=' + String(stats.targetWritesPlanned || 0));
  lines.push('targetWritesExecuted=' + String(stats.targetWritesExecuted || 0));
  lines.push('firestoreReads=' + String(stats.firestoreReads || 0));
  lines.push('firestoreWrites=' + String(stats.firestoreWrites || 0));
  lines.push('runsPerHour=' + String(stats.runsPerHour || 0));
  lines.push('estimatedReadsPerHour=' + String(stats.estimatedReadsPerHour || 0));
  lines.push('estimatedWritesPerHour=' + String(stats.estimatedWritesPerHour || 0));
  lines.push('maxReadsPerRun=' + String(stats.maxReadsPerRun || 0));
  lines.push('maxWritesPerRun=' + String(stats.maxWritesPerRun || 0));
  lines.push('maxReadsPerHour=' + String(stats.maxReadsPerHour || 0));
  lines.push('maxWritesPerHour=' + String(stats.maxWritesPerHour || 0));
  lines.push('listeners=' + String(stats.listeners || 0));
  lines.push('queries=' + String(stats.queries || 0));
  lines.push('fanOut=' + String(stats.fanOut || 0));
  lines.push('publishFromTarget=' + String(!!stats.publishFromTarget));
  lines.push('publishToTarget=' + String(!!stats.publishToTarget));
  lines.push('targetPathBuilt=' + String(!!stats.targetPathBuilt));
  lines.push('cutover=' + String(!!stats.cutover));
  lines.push('lifecycleTouched=' + String(!!stats.lifecycleTouched));
  lines.push('failedStages=' + ((stats.failedStages || []).length ? stats.failedStages.join(',') : 'none'));
  lines.push('obsoleteHandlers=' + ((stats.obsoleteHandlers || []).length ? stats.obsoleteHandlers.join(',') : 'none'));
  lines.push('violations=' + (violations.length ? violations.join(',') : 'none'));
  lines.push('error=' + (stats.error || 'none'));
  lines.push('errorKind=' + (stats.errorKind || 'none'));
  return lines.join('\n');
}
