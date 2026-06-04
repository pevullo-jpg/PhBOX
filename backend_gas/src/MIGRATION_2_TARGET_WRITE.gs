var PHBOX_M2_WRITE_VERSION_ = 'M2_WRITE_v1';
var PHBOX_M2_WRITE_STAGE_ = 'migration2_target_write_bounded';
var PHBOX_M2_WRITE_MAX_WRITES_PROPERTY_ = 'PHBOX_M2_WRITE_MAX_WRITES';
var PHBOX_M2_WRITE_DEFAULT_MAX_WRITES_ = 20;

function runMigration2TargetWriteRuntimeStatus_() {
  var routeStatus = null;
  var error = '';
  var errorKind = '';

  try {
    if (typeof runMigration2RouteContractRuntimeStatus_ !== 'function') {
      throw new Error('M2_WRITE_ROUTE_MISSING: funzione runMigration2RouteContractRuntimeStatus_ non disponibile. Target write M2 non verificabile.');
    }
    routeStatus = runMigration2RouteContractRuntimeStatus_();
  } catch (e) {
    error = normalizeRuntimeErrorMessage_(e);
    errorKind = classifyRuntimeFailureKind_(e);
  }

  return buildMigration2TargetWriteResult_({
    routeStatus: routeStatus,
    legacyWrites: [],
    executeTargetWrites: false,
    maxWrites: readMigration2TargetWriteMaxWrites_(),
    error: error,
    errorKind: errorKind
  });
}

function maybeExecuteMigration2TargetWritePlan_(cfg, plan, options) {
  options = options || {};
  cfg = cfg || getPhboxConfig_();
  plan = plan || {};

  var routeStatus = options.routeStatus || runMigration2RouteContractRuntimeStatus_();
  var maxWrites = Object.prototype.hasOwnProperty.call(options, 'maxWrites')
    ? normalizeMigration2TargetWriteMaxWrites_(options.maxWrites)
    : readMigration2TargetWriteMaxWrites_(options.props);
  var legacyWrites = Array.isArray(plan.writes) ? plan.writes : [];
  var result = buildMigration2TargetWriteResult_({
    cfg: cfg,
    routeStatus: routeStatus,
    legacyWrites: legacyWrites,
    maxWrites: maxWrites,
    executeTargetWrites: options.executeTargetWrites === true,
    commitFn: options.commitFn,
    budget: options.budget
  });

  return {
    stats: result.stats,
    targetWrites: result.targetWrites || []
  };
}

function buildMigration2TargetWriteResult_(data) {
  data = data || {};
  var cfg = data.cfg || { firestoreProjectId: 'phbox-test-project' };
  var routeStats = (data.routeStatus && data.routeStatus.stats) || {};
  var legacyWrites = Array.isArray(data.legacyWrites) ? data.legacyWrites : [];
  var maxWrites = Object.prototype.hasOwnProperty.call(data, 'maxWrites')
    ? normalizeMigration2TargetWriteMaxWrites_(data.maxWrites)
    : PHBOX_M2_WRITE_DEFAULT_MAX_WRITES_;
  var executeTargetWrites = data.executeTargetWrites === true;
  var violations = [];
  var targetWrites = [];
  var targetWritesExecuted = 0;
  var reason = '';

  if (!data.routeStatus || !data.routeStatus.stats) violations.push('m2_route_status_missing');
  if (data.routeStatus && data.routeStatus.ok === false) violations.push('m2_route_not_ok');
  if (routeStats.targetPathBuilt) violations.push('route_target_path_built_before_write');
  if (routeStats.publishToTarget || routeStats.publishFromTarget) violations.push('route_publish_detected_before_write');
  if (routeStats.cutover) violations.push('route_cutover_detected_before_write');
  if (routeStats.lifecycleTouched) violations.push('route_lifecycle_touched_before_write');
  if (Number(routeStats.firestoreReads || 0) !== 0) violations.push('route_reads_not_zero');
  if (Number(routeStats.firestoreWrites || 0) !== 0) violations.push('route_writes_not_zero');
  if (data.error) violations.push('m2_write_error');

  var routeDecision = String(routeStats.routeDecision || '');
  var targetWriteAuthorized = !!routeStats.targetRouteAuthorized &&
    routeDecision === 'target' &&
    !!routeStats.tenantCanonical &&
    !!routeStats.targetReadWriteAuthorized &&
    !!String(routeStats.tenantId || '');

  if (!targetWriteAuthorized && violations.length === 0) {
    reason = routeDecision === 'legacy'
      ? 'legacy_route_active'
      : (routeDecision === 'dual_check' ? 'dual_check_route_no_target_write' : 'target_write_not_authorized');
  }

  if (targetWriteAuthorized && legacyWrites.length > maxWrites) {
    violations.push('target_writes_over_bound');
  }

  if (targetWriteAuthorized && legacyWrites.length === 0 && violations.length === 0) {
    reason = 'no_legacy_writes_to_mirror';
  }

  try {
    if (targetWriteAuthorized && legacyWrites.length > 0 && violations.length === 0) {
      var targetRuntime = {
        enabled: true,
        tenantId: String(routeStats.tenantId || ''),
        tenantCanonical: true,
        targetReadWriteAuthorized: true
      };
      targetWrites = buildMigration1TargetFirestoreWrites_(cfg, legacyWrites, targetRuntime);
      if (targetWrites.length > maxWrites) {
        violations.push('target_writes_over_bound_after_build');
        targetWrites = [];
      }
    }

    if (executeTargetWrites && targetWrites.length > 0 && violations.length === 0) {
      if (shouldStopForBudget_(data.budget, 15000)) {
        throw new Error('M2_WRITE_BUDGET_LOW: budget runtime insufficiente prima del target write. Nessuna write target eseguita.');
      }
      if (typeof data.commitFn === 'function') {
        data.commitFn(cfg, targetWrites);
      } else {
        executeFirestoreCommit_(cfg, targetWrites);
      }
      targetWritesExecuted = targetWrites.length;
    }
  } catch (e) {
    targetWrites = [];
    violations.push('target_write_plan_error');
    data.error = normalizeRuntimeErrorMessage_(e);
    data.errorKind = classifyRuntimeFailureKind_(e);
  }

  violations = uniqueNonEmptyStrings_(violations);

  var planned = targetWrites.length;
  var ok = violations.length === 0;
  var skipped = ok && (planned === 0 || !executeTargetWrites);
  if (!reason) {
    if (violations.length > 0) {
      reason = 'target_write_violation';
    } else if (planned > 0 && executeTargetWrites) {
      reason = 'target_write_executed';
    } else if (planned > 0) {
      reason = 'target_write_planned_contract_only';
    } else {
      reason = 'target_write_skipped';
    }
  }

  var stats = {
    stage: PHBOX_M2_WRITE_STAGE_,
    ok: ok,
    skipped: skipped,
    reason: reason,
    writeVersion: PHBOX_M2_WRITE_VERSION_,
    routeVersion: String(routeStats.routeVersion || ''),
    routeMode: String(routeStats.routeMode || ''),
    routeDecision: routeDecision,
    targetWriteAuthorized: targetWriteAuthorized,
    executeTargetWrites: executeTargetWrites,
    tenantId: String(routeStats.tenantId || ''),
    tenantCanonical: !!routeStats.tenantCanonical,
    targetReadWriteAuthorized: !!routeStats.targetReadWriteAuthorized,
    legacyWritesSeen: legacyWrites.length,
    targetWritesPlanned: planned,
    targetWritesExecuted: targetWritesExecuted,
    maxWrites: maxWrites,
    firestoreReads: 0,
    firestoreWrites: targetWritesExecuted,
    publishFromTarget: false,
    publishToTarget: planned > 0 || targetWritesExecuted > 0,
    targetPathBuilt: planned > 0 || targetWritesExecuted > 0,
    cutover: false,
    lifecycleTouched: false,
    violations: violations,
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };

  return {
    ok: !!stats.ok,
    stats: stats,
    targetWrites: targetWrites
  };
}

function runMigration2TargetWriteSelfTest_() {
  var cfg = { firestoreProjectId: 'phbox-test-project' };
  var legacyUpdate = buildMigration1TargetPublishTestUpdate_(cfg, 'drive_pdf_imports', 'file_1');
  var legacyDelete = buildMigration1TargetPublishTestDelete_(cfg, 'patients', 'RSSMRA80A01H501U');
  var cases = [
    {
      id: 'legacy_route_skips_without_target_path',
      result: buildMigration2TargetWriteResult_({
        cfg: cfg,
        routeStatus: buildMigration2TargetWriteSyntheticRouteStatus_({ routeDecision: 'legacy', routeMode: 'legacy', legacyRouteActive: true }),
        legacyWrites: [legacyUpdate],
        maxWrites: 20,
        executeTargetWrites: false
      }),
      expectedOk: true,
      expectedSkipped: true,
      expectedPlanned: 0,
      expectedExecuted: 0,
      expectedReason: 'legacy_route_active',
      expectedViolation: ''
    },
    {
      id: 'target_route_authorized_plans_single_write_contract_only',
      result: buildMigration2TargetWriteResult_({
        cfg: cfg,
        routeStatus: buildMigration2TargetWriteSyntheticRouteStatus_({ routeDecision: 'target', routeMode: 'target', targetRouteAuthorized: true, tenantId: 'farmacia_santa_venera', tenantCanonical: true, targetReadWriteAuthorized: true }),
        legacyWrites: [legacyUpdate],
        maxWrites: 20,
        executeTargetWrites: false
      }),
      expectedOk: true,
      expectedSkipped: true,
      expectedPlanned: 1,
      expectedExecuted: 0,
      expectedReason: 'target_write_planned_contract_only',
      expectedViolation: ''
    },
    {
      id: 'target_route_execute_uses_injected_commit_only',
      result: runMigration2TargetWriteInjectedCommitSelfTestCase_(cfg, [legacyUpdate]),
      expectedOk: true,
      expectedSkipped: false,
      expectedPlanned: 1,
      expectedExecuted: 1,
      expectedReason: 'target_write_executed',
      expectedViolation: ''
    },
    {
      id: 'dual_check_route_skips_target_write',
      result: buildMigration2TargetWriteResult_({
        cfg: cfg,
        routeStatus: buildMigration2TargetWriteSyntheticRouteStatus_({ routeDecision: 'dual_check', routeMode: 'dual_check', dualCheckPlanned: true, legacyRouteActive: true, tenantId: 'farmacia_santa_venera', tenantCanonical: true, targetReadWriteAuthorized: true }),
        legacyWrites: [legacyUpdate],
        maxWrites: 20,
        executeTargetWrites: false
      }),
      expectedOk: true,
      expectedSkipped: true,
      expectedPlanned: 0,
      expectedExecuted: 0,
      expectedReason: 'dual_check_route_no_target_write',
      expectedViolation: ''
    },
    {
      id: 'target_route_gate_off_blocks_before_path',
      result: buildMigration2TargetWriteResult_({
        cfg: cfg,
        routeStatus: buildMigration2TargetWriteSyntheticRouteStatus_({ ok: false, routeDecision: 'blocked', routeMode: 'target', violations: ['target_route_requested_without_authorized_gate'] }),
        legacyWrites: [legacyUpdate],
        maxWrites: 20,
        executeTargetWrites: false
      }),
      expectedOk: false,
      expectedSkipped: false,
      expectedPlanned: 0,
      expectedExecuted: 0,
      expectedReason: 'target_write_violation',
      expectedViolation: 'm2_route_not_ok'
    },
    {
      id: 'write_bound_exceeded_blocks_before_path',
      result: buildMigration2TargetWriteResult_({
        cfg: cfg,
        routeStatus: buildMigration2TargetWriteSyntheticRouteStatus_({ routeDecision: 'target', routeMode: 'target', targetRouteAuthorized: true, tenantId: 'farmacia_santa_venera', tenantCanonical: true, targetReadWriteAuthorized: true }),
        legacyWrites: [legacyUpdate, legacyDelete],
        maxWrites: 1,
        executeTargetWrites: false
      }),
      expectedOk: false,
      expectedSkipped: false,
      expectedPlanned: 0,
      expectedExecuted: 0,
      expectedReason: 'target_write_violation',
      expectedViolation: 'target_writes_over_bound'
    },
    {
      id: 'already_target_prefixed_write_rejected_before_commit',
      result: buildMigration2TargetWriteResult_({
        cfg: cfg,
        routeStatus: buildMigration2TargetWriteSyntheticRouteStatus_({ routeDecision: 'target', routeMode: 'target', targetRouteAuthorized: true, tenantId: 'farmacia_santa_venera', tenantCanonical: true, targetReadWriteAuthorized: true }),
        legacyWrites: [{ update: { name: 'projects/phbox-test-project/databases/(default)/documents/tenants/farmacia_santa_venera/patients/RSSMRA80A01H501U', fields: {} } }],
        maxWrites: 20,
        executeTargetWrites: false
      }),
      expectedOk: false,
      expectedSkipped: false,
      expectedPlanned: 0,
      expectedExecuted: 0,
      expectedReason: 'target_write_violation',
      expectedViolation: 'target_write_plan_error'
    },
    {
      id: 'empty_legacy_writes_skip_without_path',
      result: buildMigration2TargetWriteResult_({
        cfg: cfg,
        routeStatus: buildMigration2TargetWriteSyntheticRouteStatus_({ routeDecision: 'target', routeMode: 'target', targetRouteAuthorized: true, tenantId: 'farmacia_santa_venera', tenantCanonical: true, targetReadWriteAuthorized: true }),
        legacyWrites: [],
        maxWrites: 20,
        executeTargetWrites: false
      }),
      expectedOk: true,
      expectedSkipped: true,
      expectedPlanned: 0,
      expectedExecuted: 0,
      expectedReason: 'no_legacy_writes_to_mirror',
      expectedViolation: ''
    },
    {
      id: 'route_publish_cutover_lifecycle_blocks_write',
      result: buildMigration2TargetWriteResult_({
        cfg: cfg,
        routeStatus: buildMigration2TargetWriteSyntheticRouteStatus_({ routeDecision: 'target', routeMode: 'target', targetRouteAuthorized: true, tenantId: 'farmacia_santa_venera', tenantCanonical: true, targetReadWriteAuthorized: true, publishToTarget: true, targetPathBuilt: true, cutover: true, lifecycleTouched: true }),
        legacyWrites: [legacyUpdate],
        maxWrites: 20,
        executeTargetWrites: false
      }),
      expectedOk: false,
      expectedSkipped: false,
      expectedPlanned: 0,
      expectedExecuted: 0,
      expectedReason: 'target_write_violation',
      expectedViolation: 'route_target_path_built_before_write'
    }
  ];

  var passed = 0;
  var failed = 0;
  var items = cases.map(function (item) {
    var stats = (item.result && item.result.stats) || {};
    var violations = stats.violations || [];
    var mismatchReasons = [];
    if (!!stats.ok !== item.expectedOk) mismatchReasons.push('expected_ok_mismatch');
    if (!!stats.skipped !== item.expectedSkipped) mismatchReasons.push('expected_skipped_mismatch');
    if (Number(stats.targetWritesPlanned || 0) !== item.expectedPlanned) mismatchReasons.push('expected_target_writes_planned_mismatch');
    if (Number(stats.targetWritesExecuted || 0) !== item.expectedExecuted) mismatchReasons.push('expected_target_writes_executed_mismatch');
    if (String(stats.reason || '') !== item.expectedReason) mismatchReasons.push('expected_reason_mismatch');
    if (item.expectedViolation && violations.indexOf(item.expectedViolation) === -1) mismatchReasons.push('expected_violation_missing');
    if (!item.expectedViolation && violations.length > 0) mismatchReasons.push('unexpected_violation');
    var ok = mismatchReasons.length === 0;
    if (ok) passed++; else failed++;
    return {
      id: item.id,
      passed: ok,
      ok: !!stats.ok,
      skipped: !!stats.skipped,
      reason: stats.reason || '',
      routeDecision: stats.routeDecision || '',
      targetWriteAuthorized: !!stats.targetWriteAuthorized,
      executeTargetWrites: !!stats.executeTargetWrites,
      tenantId: stats.tenantId || '',
      tenantCanonical: !!stats.tenantCanonical,
      targetReadWriteAuthorized: !!stats.targetReadWriteAuthorized,
      legacyWritesSeen: Number(stats.legacyWritesSeen || 0),
      targetWritesPlanned: Number(stats.targetWritesPlanned || 0),
      targetWritesExecuted: Number(stats.targetWritesExecuted || 0),
      maxWrites: Number(stats.maxWrites || 0),
      firestoreReads: Number(stats.firestoreReads || 0),
      firestoreWrites: Number(stats.firestoreWrites || 0),
      publishFromTarget: !!stats.publishFromTarget,
      publishToTarget: !!stats.publishToTarget,
      targetPathBuilt: !!stats.targetPathBuilt,
      cutover: !!stats.cutover,
      lifecycleTouched: !!stats.lifecycleTouched,
      violations: uniqueNonEmptyStrings_(violations),
      mismatchReasons: uniqueNonEmptyStrings_(mismatchReasons)
    };
  });

  return {
    ok: failed === 0,
    testCount: items.length,
    passedCount: passed,
    failedCount: failed,
    writeVersion: PHBOX_M2_WRITE_VERSION_,
    defaultMaxWrites: PHBOX_M2_WRITE_DEFAULT_MAX_WRITES_,
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

function runMigration2TargetWriteInjectedCommitSelfTestCase_(cfg, legacyWrites) {
  var executedCount = 0;
  var result = buildMigration2TargetWriteResult_({
    cfg: cfg,
    routeStatus: buildMigration2TargetWriteSyntheticRouteStatus_({ routeDecision: 'target', routeMode: 'target', targetRouteAuthorized: true, tenantId: 'farmacia_santa_venera', tenantCanonical: true, targetReadWriteAuthorized: true }),
    legacyWrites: legacyWrites,
    maxWrites: 20,
    executeTargetWrites: true,
    commitFn: function (_cfg, targetWrites) {
      executedCount = targetWrites.length;
    }
  });
  if (result && result.stats) result.stats.targetWritesExecuted = executedCount;
  return result;
}

function buildMigration2TargetWriteSyntheticRouteStatus_(overrides) {
  overrides = overrides || {};
  var stats = {
    ok: Object.prototype.hasOwnProperty.call(overrides, 'ok') ? !!overrides.ok : true,
    routeVersion: Object.prototype.hasOwnProperty.call(overrides, 'routeVersion') ? overrides.routeVersion : 'M2_ROUTE_v2',
    routeMode: String(overrides.routeMode || 'legacy'),
    routeDecision: String(overrides.routeDecision || 'legacy'),
    targetRouteAuthorized: !!overrides.targetRouteAuthorized,
    legacyRouteActive: !!overrides.legacyRouteActive,
    dualCheckPlanned: !!overrides.dualCheckPlanned,
    tenantId: String(overrides.tenantId || ''),
    tenantCanonical: !!overrides.tenantCanonical,
    targetReadWriteAuthorized: !!overrides.targetReadWriteAuthorized,
    firestoreReads: Number(overrides.firestoreReads || 0),
    firestoreWrites: Number(overrides.firestoreWrites || 0),
    publishFromTarget: !!overrides.publishFromTarget,
    publishToTarget: !!overrides.publishToTarget,
    targetPathBuilt: !!overrides.targetPathBuilt,
    cutover: !!overrides.cutover,
    lifecycleTouched: !!overrides.lifecycleTouched,
    violations: Array.isArray(overrides.violations) ? overrides.violations : []
  };
  return {
    ok: stats.ok,
    stats: stats
  };
}

function readMigration2TargetWriteMaxWrites_(props) {
  props = props || PropertiesService.getScriptProperties();
  var raw = props.getProperty(PHBOX_M2_WRITE_MAX_WRITES_PROPERTY_);
  if (raw === null || raw === undefined || String(raw).trim() === '') return PHBOX_M2_WRITE_DEFAULT_MAX_WRITES_;
  return normalizeMigration2TargetWriteMaxWrites_(raw);
}

function normalizeMigration2TargetWriteMaxWrites_(value) {
  var numeric = Number(value);
  if (!isFinite(numeric) || numeric < 0) return PHBOX_M2_WRITE_DEFAULT_MAX_WRITES_;
  return Math.floor(numeric);
}

function listMigration2TargetWriteObsoleteSettingsHandlers_() {
  var names = [
    'runMigration2RouteSettingsTest',
    'getMigration2RouteSettingsStatus',
    'runMigration2LockSettingsTest',
    'getMigration2LockSettingsStatus',
    'runMigration1FreezeBaselineSettingsTest',
    'getMigration1FreezeBaselineSettingsStatus',
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
    return isMigration2TargetWriteGlobalFunction_(name);
  });
}

function isMigration2TargetWriteGlobalFunction_(name) {
  try {
    return typeof globalThis !== 'undefined' && typeof globalThis[name] === 'function';
  } catch (e) {
    return false;
  }
}

function formatMigration2TargetWriteSelfTestFeedback_(result) {
  result = result || runMigration2TargetWriteSelfTest_();
  var lines = [];
  lines.push('MIGRATION_2_WRITE_TEST');
  lines.push('ok=' + String(!!result.ok));
  lines.push('testCount=' + String(result.testCount || 0));
  lines.push('passedCount=' + String(result.passedCount || 0));
  lines.push('failedCount=' + String(result.failedCount || 0));
  lines.push('writeVersion=' + String(result.writeVersion || ''));
  lines.push('defaultMaxWrites=' + String(result.defaultMaxWrites || 0));
  lines.push('firestoreReads=' + String(result.firestoreReads || 0));
  lines.push('firestoreWrites=' + String(result.firestoreWrites || 0));
  lines.push('publishFromTarget=' + String(!!result.publishFromTarget));
  lines.push('publishToTarget=' + String(!!result.publishToTarget));
  lines.push('targetPathBuilt=' + String(!!result.targetPathBuilt));
  lines.push('cutover=' + String(!!result.cutover));
  lines.push('lifecycleTouched=' + String(!!result.lifecycleTouched));
  lines.push('items=');
  (result.items || []).forEach(function (item) {
    lines.push('- id=' + item.id);
    lines.push('  passed=' + String(!!item.passed));
    lines.push('  ok=' + String(!!item.ok));
    lines.push('  skipped=' + String(!!item.skipped));
    lines.push('  reason=' + String(item.reason || ''));
    lines.push('  routeDecision=' + String(item.routeDecision || ''));
    lines.push('  targetWriteAuthorized=' + String(!!item.targetWriteAuthorized));
    lines.push('  executeTargetWrites=' + String(!!item.executeTargetWrites));
    lines.push('  tenantId=' + String(item.tenantId || ''));
    lines.push('  tenantCanonical=' + String(!!item.tenantCanonical));
    lines.push('  targetReadWriteAuthorized=' + String(!!item.targetReadWriteAuthorized));
    lines.push('  legacyWritesSeen=' + String(item.legacyWritesSeen || 0));
    lines.push('  targetWritesPlanned=' + String(item.targetWritesPlanned || 0));
    lines.push('  targetWritesExecuted=' + String(item.targetWritesExecuted || 0));
    lines.push('  maxWrites=' + String(item.maxWrites || 0));
    lines.push('  firestoreReads=' + String(item.firestoreReads || 0));
    lines.push('  firestoreWrites=' + String(item.firestoreWrites || 0));
    lines.push('  publishFromTarget=' + String(!!item.publishFromTarget));
    lines.push('  publishToTarget=' + String(!!item.publishToTarget));
    lines.push('  targetPathBuilt=' + String(!!item.targetPathBuilt));
    lines.push('  cutover=' + String(!!item.cutover));
    lines.push('  lifecycleTouched=' + String(!!item.lifecycleTouched));
    lines.push('  violations=' + formatMigration2TargetWriteList_(item.violations));
    lines.push('  mismatchReasons=' + formatMigration2TargetWriteList_(item.mismatchReasons));
  });
  return lines.join('\n');
}

function formatMigration2TargetWriteRuntimeFeedback_(result) {
  result = result || runMigration2TargetWriteRuntimeStatus_();
  var stats = (result && result.stats) || {};
  var lines = [];
  lines.push('MIGRATION_2_WRITE_RUNTIME_STATUS');
  lines.push('ok=' + String(!!(result && result.ok)));
  lines.push('skipped=' + String(!!stats.skipped));
  lines.push('reason=' + String(stats.reason || ''));
  lines.push('writeVersion=' + String(stats.writeVersion || ''));
  lines.push('routeVersion=' + String(stats.routeVersion || ''));
  lines.push('routeMode=' + String(stats.routeMode || ''));
  lines.push('routeDecision=' + String(stats.routeDecision || ''));
  lines.push('targetWriteAuthorized=' + String(!!stats.targetWriteAuthorized));
  lines.push('executeTargetWrites=' + String(!!stats.executeTargetWrites));
  lines.push('tenantId=' + String(stats.tenantId || ''));
  lines.push('tenantCanonical=' + String(!!stats.tenantCanonical));
  lines.push('targetReadWriteAuthorized=' + String(!!stats.targetReadWriteAuthorized));
  lines.push('legacyWritesSeen=' + String(stats.legacyWritesSeen || 0));
  lines.push('targetWritesPlanned=' + String(stats.targetWritesPlanned || 0));
  lines.push('targetWritesExecuted=' + String(stats.targetWritesExecuted || 0));
  lines.push('maxWrites=' + String(stats.maxWrites || 0));
  lines.push('firestoreReads=' + String(stats.firestoreReads || 0));
  lines.push('firestoreWrites=' + String(stats.firestoreWrites || 0));
  lines.push('publishFromTarget=' + String(!!stats.publishFromTarget));
  lines.push('publishToTarget=' + String(!!stats.publishToTarget));
  lines.push('targetPathBuilt=' + String(!!stats.targetPathBuilt));
  lines.push('cutover=' + String(!!stats.cutover));
  lines.push('lifecycleTouched=' + String(!!stats.lifecycleTouched));
  lines.push('violations=' + formatMigration2TargetWriteList_(stats.violations));
  lines.push('error=' + (stats.error || 'none'));
  lines.push('errorKind=' + (stats.errorKind || 'none'));
  return lines.join('\n');
}

function formatMigration2TargetWriteList_(values) {
  values = uniqueNonEmptyStrings_(values || []);
  return values.length ? values.join(',') : 'none';
}
