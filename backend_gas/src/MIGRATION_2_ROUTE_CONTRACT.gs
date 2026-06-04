var PHBOX_M2_ROUTE_VERSION_ = 'M2_ROUTE_v2';
var PHBOX_M2_ROUTE_STAGE_ = 'migration2_route_contract';
var PHBOX_M2_ROUTE_MODE_PROPERTY_ = 'PHBOX_M2_ROUTE_MODE';
var PHBOX_M2_ROUTE_MODE_LEGACY_ = 'legacy';
var PHBOX_M2_ROUTE_MODE_DUAL_CHECK_ = 'dual_check';
var PHBOX_M2_ROUTE_MODE_TARGET_ = 'target';
var PHBOX_M2_ROUTE_REQUIRED_FREEZE_VERSION_ = 'M1_FREEZE_v2';
var PHBOX_M2_ROUTE_REQUIRED_M1_STATUS_ = 'baseline_frozen';
var PHBOX_M2_ROUTE_NEXT_ROADMAP_ = 'Migration 2 — Cutover operativo controllato';

function runMigration2RouteContractRuntimeStatus_() {
  var preconditionStatus = null;
  var gateResult = null;
  var routeMode = PHBOX_M2_ROUTE_MODE_LEGACY_;
  var error = '';
  var errorKind = '';

  try {
    preconditionStatus = runMigration2RoutePreconditionStatus_();
  } catch (e) {
    error = normalizeRuntimeErrorMessage_(e);
    errorKind = classifyRuntimeFailureKind_(e);
  }

  try {
    if (!error) {
      if (typeof runMigration1TargetRuntimeGateStage_ === 'function') {
        var gateStage = runMigration1TargetRuntimeGateStage_({});
        if (!gateStage || gateStage.ok === false) {
          throw new Error((gateStage && gateStage.error) || 'M2_ROUTE_GATE_STATUS_ERROR: target runtime gate non verificabile.');
        }
        gateResult = gateStage.result;
      } else if (typeof runMigration1TargetRuntimeGate_ === 'function') {
        gateResult = runMigration1TargetRuntimeGate_({});
      } else {
        throw new Error('M2_ROUTE_M1_GATE_MISSING: funzione target runtime gate non disponibile.');
      }
      routeMode = readMigration2RouteModeFromProperties_();
    }
  } catch (e2) {
    error = normalizeRuntimeErrorMessage_(e2);
    errorKind = classifyRuntimeFailureKind_(e2);
  }

  return buildMigration2RouteContractResult_({
    preconditionStatus: preconditionStatus,
    gateStatus: gateResult,
    routeMode: routeMode,
    obsoleteHandlers: listMigration2RouteObsoleteSettingsHandlers_(),
    error: error,
    errorKind: errorKind
  });
}

function runMigration2RoutePreconditionStatus_() {
  var freezeStatus = null;
  var error = '';
  var errorKind = '';

  try {
    if (typeof runMigration1FreezeBaselineRuntimeStatus_ !== 'function') {
      throw new Error('M2_ROUTE_M1_FREEZE_MISSING: funzione runMigration1FreezeBaselineRuntimeStatus_ non disponibile. Baseline M1 non verificabile.');
    }
    freezeStatus = runMigration1FreezeBaselineRuntimeStatus_();
  } catch (e) {
    error = normalizeRuntimeErrorMessage_(e);
    errorKind = classifyRuntimeFailureKind_(e);
  }

  return buildMigration2RoutePreconditionResult_({
    freezeStatus: freezeStatus,
    error: error,
    errorKind: errorKind
  });
}

function buildMigration2RoutePreconditionResult_(data) {
  data = data || {};
  var freezeStats = (data.freezeStatus && data.freezeStatus.stats) || {};
  var violations = [];

  if (!data.freezeStatus || !data.freezeStatus.stats) violations.push('m1_freeze_status_missing');
  if (data.freezeStatus && data.freezeStatus.ok === false) violations.push('m1_freeze_not_ok');
  if (freezeStats.freezeVersion !== PHBOX_M2_ROUTE_REQUIRED_FREEZE_VERSION_) violations.push('m1_freeze_version_not_v2');
  if (freezeStats.migration1Status !== PHBOX_M2_ROUTE_REQUIRED_M1_STATUS_) violations.push('migration1_not_baseline_frozen');
  if (freezeStats.nextRoadmap !== PHBOX_M2_ROUTE_NEXT_ROADMAP_) violations.push('next_roadmap_not_migration2');
  if (Number(freezeStats.firestoreReads || 0) !== 0) violations.push('m1_freeze_reads_not_zero');
  if (Number(freezeStats.firestoreWrites || 0) !== 0) violations.push('m1_freeze_writes_not_zero');
  if (freezeStats.publishToTarget || freezeStats.publishFromTarget) violations.push('m1_freeze_publish_detected');
  if (freezeStats.targetPathBuilt) violations.push('m1_freeze_target_path_built');
  if (freezeStats.cutover) violations.push('m1_freeze_cutover_detected');
  if (freezeStats.lifecycleTouched) violations.push('m1_freeze_lifecycle_touched');
  if (data.error) violations.push('m2_route_precondition_error');

  violations = uniqueNonEmptyStrings_(violations);

  var stats = {
    stage: 'migration2_route_precondition',
    ok: violations.length === 0,
    skipped: false,
    reason: violations.length === 0 ? 'm2_route_precondition_ready' : (data.error ? 'm2_route_precondition_error' : 'm2_route_precondition_violation'),
    routeVersion: PHBOX_M2_ROUTE_VERSION_,
    freezeVersion: String(freezeStats.freezeVersion || ''),
    migration1Status: String(freezeStats.migration1Status || ''),
    nextRoadmap: String(freezeStats.nextRoadmap || ''),
    firestoreReads: 0,
    firestoreWrites: 0,
    publishFromTarget: false,
    publishToTarget: false,
    targetPathBuilt: false,
    cutover: false,
    lifecycleTouched: false,
    violations: violations,
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };

  return {
    ok: !!stats.ok,
    stats: stats
  };
}

function runMigration2RouteContractSelfTest_() {
  var cases = [
    {
      id: 'default_legacy_gate_off_routes_legacy',
      result: buildMigration2RouteContractResult_({
        preconditionStatus: buildMigration2RouteSyntheticPreconditionStatus_({}),
        gateStatus: buildMigration2RouteSyntheticGateStatus_({}),
        routeMode: PHBOX_M2_ROUTE_MODE_LEGACY_
      }),
      expectedOk: true,
      expectedDecision: 'legacy',
      expectedViolation: ''
    },
    {
      id: 'target_mode_gate_off_blocks_before_target',
      result: buildMigration2RouteContractResult_({
        preconditionStatus: buildMigration2RouteSyntheticPreconditionStatus_({}),
        gateStatus: buildMigration2RouteSyntheticGateStatus_({}),
        routeMode: PHBOX_M2_ROUTE_MODE_TARGET_
      }),
      expectedOk: false,
      expectedDecision: 'blocked',
      expectedViolation: 'target_route_requested_without_authorized_gate'
    },
    {
      id: 'target_mode_gate_on_canonical_authorizes_contract_only',
      result: buildMigration2RouteContractResult_({
        preconditionStatus: buildMigration2RouteSyntheticPreconditionStatus_({}),
        gateStatus: buildMigration2RouteSyntheticGateStatus_({
          enabled: true,
          skipped: false,
          reason: '',
          tenantId: 'farmacia_santa_venera',
          tenantCanonical: true,
          targetReadWriteAuthorized: true
        }),
        routeMode: PHBOX_M2_ROUTE_MODE_TARGET_
      }),
      expectedOk: true,
      expectedDecision: 'target',
      expectedViolation: ''
    },
    {
      id: 'dual_check_mode_gate_on_canonical_routes_dual_check',
      result: buildMigration2RouteContractResult_({
        preconditionStatus: buildMigration2RouteSyntheticPreconditionStatus_({}),
        gateStatus: buildMigration2RouteSyntheticGateStatus_({
          enabled: true,
          skipped: false,
          reason: '',
          tenantId: 'farmacia_santa_venera',
          tenantCanonical: true,
          targetReadWriteAuthorized: true
        }),
        routeMode: PHBOX_M2_ROUTE_MODE_DUAL_CHECK_
      }),
      expectedOk: true,
      expectedDecision: 'dual_check',
      expectedViolation: ''
    },
    {
      id: 'target_mode_noncanonical_tenant_blocks',
      result: buildMigration2RouteContractResult_({
        preconditionStatus: buildMigration2RouteSyntheticPreconditionStatus_({}),
        gateStatus: buildMigration2RouteSyntheticGateStatus_({
          enabled: true,
          skipped: false,
          reason: '',
          tenantId: 'bad/tenant',
          tenantCanonical: false,
          targetReadWriteAuthorized: true
        }),
        routeMode: PHBOX_M2_ROUTE_MODE_TARGET_
      }),
      expectedOk: false,
      expectedDecision: 'blocked',
      expectedViolation: 'target_route_tenant_not_canonical'
    },
    {
      id: 'invalid_route_mode_blocks',
      result: buildMigration2RouteContractResult_({
        preconditionStatus: buildMigration2RouteSyntheticPreconditionStatus_({}),
        gateStatus: buildMigration2RouteSyntheticGateStatus_({}),
        routeMode: 'invalid'
      }),
      expectedOk: false,
      expectedDecision: 'blocked',
      expectedViolation: 'route_mode_invalid'
    },
    {
      id: 'route_precondition_not_ok_blocks_route',
      result: buildMigration2RouteContractResult_({
        preconditionStatus: buildMigration2RouteSyntheticPreconditionStatus_({ ok: false, reason: 'm2_route_precondition_violation', violations: ['m1_freeze_not_ok'] }),
        gateStatus: buildMigration2RouteSyntheticGateStatus_({}),
        routeMode: PHBOX_M2_ROUTE_MODE_LEGACY_
      }),
      expectedOk: false,
      expectedDecision: 'blocked',
      expectedViolation: 'm2_route_precondition_not_ok'
    },
    {
      id: 'target_path_publish_cutover_lifecycle_blocks_route',
      result: buildMigration2RouteContractResult_({
        preconditionStatus: buildMigration2RouteSyntheticPreconditionStatus_({}),
        gateStatus: buildMigration2RouteSyntheticGateStatus_({ targetPathBuilt: true, publishToTarget: true, cutover: true, lifecycleTouched: true }),
        routeMode: PHBOX_M2_ROUTE_MODE_LEGACY_
      }),
      expectedOk: false,
      expectedDecision: 'blocked',
      expectedViolation: 'target_path_built_before_route'
    },
    {
      id: 'obsolete_settings_handler_blocks_route',
      result: buildMigration2RouteContractResult_({
        preconditionStatus: buildMigration2RouteSyntheticPreconditionStatus_({}),
        gateStatus: buildMigration2RouteSyntheticGateStatus_({}),
        routeMode: PHBOX_M2_ROUTE_MODE_LEGACY_,
        obsoleteHandlers: ['runMigration2LockSettingsTest']
      }),
      expectedOk: false,
      expectedDecision: 'blocked',
      expectedViolation: 'obsolete_settings_handlers_detected'
    },
    {
      id: 'm2_route_runtime_zero_read_write_contract',
      result: buildMigration2RouteContractResult_({
        preconditionStatus: buildMigration2RouteSyntheticPreconditionStatus_({}),
        gateStatus: buildMigration2RouteSyntheticGateStatus_({}),
        routeMode: PHBOX_M2_ROUTE_MODE_LEGACY_
      }),
      expectedOk: true,
      expectedDecision: 'legacy',
      expectedViolation: ''
    }
  ];

  var passed = 0;
  var failed = 0;
  var items = cases.map(function (item) {
    var stats = (item.result && item.result.stats) || {};
    var violations = stats.violations || [];
    var mismatchReasons = [];
    if (!!stats.ok !== item.expectedOk) mismatchReasons.push('expected_ok_mismatch');
    if (stats.routeDecision !== item.expectedDecision) mismatchReasons.push('expected_route_decision_mismatch');
    if (item.expectedViolation && violations.indexOf(item.expectedViolation) === -1) mismatchReasons.push('expected_violation_missing');
    if (!item.expectedViolation && violations.length > 0) mismatchReasons.push('unexpected_violation');
    var ok = mismatchReasons.length === 0;
    if (ok) passed++; else failed++;
    return {
      id: item.id,
      passed: ok,
      ok: !!stats.ok,
      expectedOk: item.expectedOk,
      routeMode: stats.routeMode,
      routeDecision: stats.routeDecision,
      expectedDecision: item.expectedDecision,
      preconditionOk: !!stats.preconditionOk,
      targetGateEnabled: !!stats.targetGateEnabled,
      tenantId: stats.tenantId || '',
      tenantCanonical: !!stats.tenantCanonical,
      targetReadWriteAuthorized: !!stats.targetReadWriteAuthorized,
      targetRouteAuthorized: !!stats.targetRouteAuthorized,
      legacyRouteActive: !!stats.legacyRouteActive,
      dualCheckPlanned: !!stats.dualCheckPlanned,
      firestoreReads: stats.firestoreReads || 0,
      firestoreWrites: stats.firestoreWrites || 0,
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
    routeVersion: PHBOX_M2_ROUTE_VERSION_,
    defaultRouteMode: PHBOX_M2_ROUTE_MODE_LEGACY_,
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

function buildMigration2RouteContractResult_(data) {
  data = data || {};
  var preconditionStats = (data.preconditionStatus && data.preconditionStatus.stats) || {};
  var gateStats = (data.gateStatus && data.gateStatus.stats) || {};
  var obsoleteHandlers = Array.isArray(data.obsoleteHandlers) ? data.obsoleteHandlers : [];
  var routeMode = normalizeMigration2RouteMode_(data.routeMode);
  var violations = [];

  if (!data.preconditionStatus || !data.preconditionStatus.stats) violations.push('m2_route_precondition_missing');
  if (data.preconditionStatus && data.preconditionStatus.ok === false) violations.push('m2_route_precondition_not_ok');
  if (Number(preconditionStats.firestoreReads || 0) !== 0) violations.push('m2_route_precondition_reads_not_zero');
  if (Number(preconditionStats.firestoreWrites || 0) !== 0) violations.push('m2_route_precondition_writes_not_zero');
  if (preconditionStats.publishToTarget || preconditionStats.publishFromTarget) violations.push('m2_route_precondition_publish_detected');
  if (preconditionStats.targetPathBuilt) violations.push('m2_route_precondition_target_path_built');
  if (preconditionStats.cutover) violations.push('m2_route_precondition_cutover_detected');
  if (preconditionStats.lifecycleTouched) violations.push('m2_route_precondition_lifecycle_touched');

  if (!data.gateStatus || !data.gateStatus.stats) violations.push('target_runtime_gate_status_missing');
  if (Number(gateStats.firestoreReads || 0) !== 0) violations.push('target_gate_reads_not_zero');
  if (Number(gateStats.firestoreWrites || 0) !== 0) violations.push('target_gate_writes_not_zero');
  if (gateStats.targetPathBuilt) violations.push('target_path_built_before_route');
  if (gateStats.publishToTarget || gateStats.publishFromTarget) violations.push('target_gate_publish_detected');
  if (gateStats.cutover) violations.push('target_gate_cutover_detected');
  if (gateStats.lifecycleTouched) violations.push('target_gate_lifecycle_touched');

  if (!isMigration2RouteModeValid_(routeMode)) violations.push('route_mode_invalid');

  var decision = resolveMigration2RoutingDecision_(routeMode, gateStats, violations);
  violations = violations.concat(decision.violations || []);

  if (obsoleteHandlers.length > 0) violations.push('obsolete_settings_handlers_detected');
  if (data.error) violations.push('m2_route_error');
  violations = uniqueNonEmptyStrings_(violations);

  if (violations.length > 0) {
    decision.routeDecision = 'blocked';
    decision.routeReason = data.error ? 'm2_route_error' : 'm2_route_violation';
    decision.targetRouteAuthorized = false;
    decision.legacyRouteActive = false;
    decision.dualCheckPlanned = false;
  }

  var stats = {
    stage: PHBOX_M2_ROUTE_STAGE_,
    ok: violations.length === 0,
    skipped: false,
    reason: violations.length === 0 ? decision.routeReason : (data.error ? 'm2_route_error' : 'm2_route_violation'),
    routeVersion: PHBOX_M2_ROUTE_VERSION_,
    routeMode: routeMode,
    routeDecision: decision.routeDecision,
    routeReason: decision.routeReason,
    routingContractActive: true,
    preconditionOk: !!(data.preconditionStatus && data.preconditionStatus.ok),
    targetGateEnabled: !!gateStats.enabled,
    targetGateReason: String(gateStats.reason || ''),
    tenantId: String(gateStats.tenantId || ''),
    tenantCanonical: !!gateStats.tenantCanonical,
    targetReadWriteAuthorized: !!gateStats.targetReadWriteAuthorized,
    targetRouteAuthorized: !!decision.targetRouteAuthorized,
    legacyRouteActive: !!decision.legacyRouteActive,
    dualCheckPlanned: !!decision.dualCheckPlanned,
    obsoleteHandlersCount: obsoleteHandlers.length,
    firestoreReads: 0,
    firestoreWrites: 0,
    publishFromTarget: false,
    publishToTarget: false,
    targetPathBuilt: false,
    cutover: false,
    lifecycleTouched: false,
    violations: violations,
    obsoleteHandlers: uniqueNonEmptyStrings_(obsoleteHandlers),
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };

  return {
    ok: !!stats.ok,
    stats: stats
  };
}

function resolveMigration2RoutingDecision_(routeMode, gateStats, baseViolations) {
  var violations = [];
  if (baseViolations && baseViolations.length > 0) {
    return {
      routeDecision: 'blocked',
      routeReason: 'precondition_violation',
      targetRouteAuthorized: false,
      legacyRouteActive: false,
      dualCheckPlanned: false,
      violations: []
    };
  }

  if (routeMode === PHBOX_M2_ROUTE_MODE_LEGACY_) {
    return {
      routeDecision: 'legacy',
      routeReason: 'legacy_route_default',
      targetRouteAuthorized: false,
      legacyRouteActive: true,
      dualCheckPlanned: false,
      violations: []
    };
  }

  if (!gateStats.enabled || !gateStats.targetReadWriteAuthorized) {
    violations.push('target_route_requested_without_authorized_gate');
  }
  if (!gateStats.tenantCanonical || !String(gateStats.tenantId || '')) {
    violations.push('target_route_tenant_not_canonical');
  }

  if (violations.length > 0) {
    return {
      routeDecision: 'blocked',
      routeReason: 'target_route_not_authorized',
      targetRouteAuthorized: false,
      legacyRouteActive: false,
      dualCheckPlanned: false,
      violations: violations
    };
  }

  if (routeMode === PHBOX_M2_ROUTE_MODE_DUAL_CHECK_) {
    return {
      routeDecision: 'dual_check',
      routeReason: 'dual_check_route_authorized_contract_only',
      targetRouteAuthorized: false,
      legacyRouteActive: true,
      dualCheckPlanned: true,
      violations: []
    };
  }

  return {
    routeDecision: 'target',
    routeReason: 'target_route_authorized_contract_only',
    targetRouteAuthorized: true,
    legacyRouteActive: false,
    dualCheckPlanned: false,
    violations: []
  };
}

function readMigration2RouteModeFromProperties_(props) {
  props = props || PropertiesService.getScriptProperties();
  var raw = String(props.getProperty(PHBOX_M2_ROUTE_MODE_PROPERTY_) || '').trim().toLowerCase();
  return raw || PHBOX_M2_ROUTE_MODE_LEGACY_;
}

function normalizeMigration2RouteMode_(value) {
  return String(value || PHBOX_M2_ROUTE_MODE_LEGACY_).trim().toLowerCase();
}

function isMigration2RouteModeValid_(value) {
  return value === PHBOX_M2_ROUTE_MODE_LEGACY_ || value === PHBOX_M2_ROUTE_MODE_DUAL_CHECK_ || value === PHBOX_M2_ROUTE_MODE_TARGET_;
}

function buildMigration2RouteSyntheticPreconditionStatus_(overrides) {
  overrides = overrides || {};
  var stats = {
    ok: Object.prototype.hasOwnProperty.call(overrides, 'ok') ? !!overrides.ok : true,
    reason: String(overrides.reason || 'm2_route_precondition_ready'),
    routeVersion: PHBOX_M2_ROUTE_VERSION_,
    freezeVersion: Object.prototype.hasOwnProperty.call(overrides, 'freezeVersion') ? overrides.freezeVersion : PHBOX_M2_ROUTE_REQUIRED_FREEZE_VERSION_,
    migration1Status: Object.prototype.hasOwnProperty.call(overrides, 'migration1Status') ? overrides.migration1Status : PHBOX_M2_ROUTE_REQUIRED_M1_STATUS_,
    nextRoadmap: Object.prototype.hasOwnProperty.call(overrides, 'nextRoadmap') ? overrides.nextRoadmap : PHBOX_M2_ROUTE_NEXT_ROADMAP_,
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

function buildMigration2RouteSyntheticGateStatus_(overrides) {
  overrides = overrides || {};
  var stats = {
    enabled: !!overrides.enabled,
    skipped: Object.prototype.hasOwnProperty.call(overrides, 'skipped') ? !!overrides.skipped : !overrides.enabled,
    reason: Object.prototype.hasOwnProperty.call(overrides, 'reason') ? String(overrides.reason || '') : (overrides.enabled ? '' : 'target_runtime_gate_off'),
    tenantId: String(overrides.tenantId || ''),
    tenantCanonical: !!overrides.tenantCanonical,
    targetReadWriteAuthorized: !!overrides.targetReadWriteAuthorized,
    firestoreReads: Number(overrides.firestoreReads || 0),
    firestoreWrites: Number(overrides.firestoreWrites || 0),
    publishFromTarget: !!overrides.publishFromTarget,
    publishToTarget: !!overrides.publishToTarget,
    targetPathBuilt: !!overrides.targetPathBuilt,
    cutover: !!overrides.cutover,
    lifecycleTouched: !!overrides.lifecycleTouched
  };
  return { stats: stats };
}

function listMigration2RouteObsoleteSettingsHandlers_() {
  var names = [
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
    return isMigration2RouteGlobalFunction_(name);
  });
}

function isMigration2RouteGlobalFunction_(name) {
  try {
    return typeof globalThis !== 'undefined' && typeof globalThis[name] === 'function';
  } catch (e) {
    return false;
  }
}

function formatMigration2RouteContractSelfTestFeedback_(result) {
  result = result || runMigration2RouteContractSelfTest_();
  var lines = [];
  lines.push('MIGRATION_2_ROUTE_TEST');
  lines.push('ok=' + String(!!result.ok));
  lines.push('testCount=' + String(result.testCount || 0));
  lines.push('passedCount=' + String(result.passedCount || 0));
  lines.push('failedCount=' + String(result.failedCount || 0));
  lines.push('routeVersion=' + String(result.routeVersion || ''));
  lines.push('defaultRouteMode=' + String(result.defaultRouteMode || ''));
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
    lines.push('  expectedOk=' + String(!!item.expectedOk));
    lines.push('  routeMode=' + String(item.routeMode || ''));
    lines.push('  routeDecision=' + String(item.routeDecision || ''));
    lines.push('  expectedDecision=' + String(item.expectedDecision || ''));
    lines.push('  preconditionOk=' + String(!!item.preconditionOk));
    lines.push('  targetGateEnabled=' + String(!!item.targetGateEnabled));
    lines.push('  tenantId=' + String(item.tenantId || ''));
    lines.push('  tenantCanonical=' + String(!!item.tenantCanonical));
    lines.push('  targetReadWriteAuthorized=' + String(!!item.targetReadWriteAuthorized));
    lines.push('  targetRouteAuthorized=' + String(!!item.targetRouteAuthorized));
    lines.push('  legacyRouteActive=' + String(!!item.legacyRouteActive));
    lines.push('  dualCheckPlanned=' + String(!!item.dualCheckPlanned));
    lines.push('  firestoreReads=' + String(item.firestoreReads || 0));
    lines.push('  firestoreWrites=' + String(item.firestoreWrites || 0));
    lines.push('  publishFromTarget=' + String(!!item.publishFromTarget));
    lines.push('  publishToTarget=' + String(!!item.publishToTarget));
    lines.push('  targetPathBuilt=' + String(!!item.targetPathBuilt));
    lines.push('  cutover=' + String(!!item.cutover));
    lines.push('  lifecycleTouched=' + String(!!item.lifecycleTouched));
    lines.push('  violations=' + ((item.violations || []).join(',') || 'none'));
    lines.push('  mismatchReasons=' + ((item.mismatchReasons || []).join(',') || 'none'));
  });
  return lines.join('\n');
}

function formatMigration2RouteContractRuntimeFeedback_(result) {
  result = result || runMigration2RouteContractRuntimeStatus_();
  var stats = (result && result.stats) || {};
  var lines = [];
  lines.push('MIGRATION_2_ROUTE_RUNTIME_STATUS');
  lines.push('ok=' + String(!!stats.ok));
  lines.push('skipped=' + String(!!stats.skipped));
  lines.push('reason=' + String(stats.reason || ''));
  lines.push('routeVersion=' + String(stats.routeVersion || ''));
  lines.push('routeMode=' + String(stats.routeMode || ''));
  lines.push('routeDecision=' + String(stats.routeDecision || ''));
  lines.push('routeReason=' + String(stats.routeReason || ''));
  lines.push('routingContractActive=' + String(!!stats.routingContractActive));
  lines.push('preconditionOk=' + String(!!stats.preconditionOk));
  lines.push('targetGateEnabled=' + String(!!stats.targetGateEnabled));
  lines.push('targetGateReason=' + String(stats.targetGateReason || ''));
  lines.push('tenantId=' + String(stats.tenantId || ''));
  lines.push('tenantCanonical=' + String(!!stats.tenantCanonical));
  lines.push('targetReadWriteAuthorized=' + String(!!stats.targetReadWriteAuthorized));
  lines.push('targetRouteAuthorized=' + String(!!stats.targetRouteAuthorized));
  lines.push('legacyRouteActive=' + String(!!stats.legacyRouteActive));
  lines.push('dualCheckPlanned=' + String(!!stats.dualCheckPlanned));
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
  lines.push('error=' + (stats.error || 'none'));
  lines.push('errorKind=' + (stats.errorKind || 'none'));
  return lines.join('\n');
}
