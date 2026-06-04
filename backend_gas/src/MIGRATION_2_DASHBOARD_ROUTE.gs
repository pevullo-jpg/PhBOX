var PHBOX_M2_DASH_VERSION_ = 'M2_DASH_v1';
var PHBOX_M2_DASH_STAGE_ = 'migration2_dashboard_read_route';
var PHBOX_M2_DASH_REQUIRED_ROUTE_VERSION_ = 'M2_ROUTE_v2';
var PHBOX_M2_DASH_REQUIRED_SIGNAL_VERSION_ = 'M2_SIGNAL_v2';
var PHBOX_M2_DASH_TARGET_COLLECTIONS_ = [
  'dashboard_totals',
  'patient_dashboard_index',
  'dashboard_expiring_recipes'
];

function runMigration2DashboardReadRuntimeStatus_() {
  var routeStatus = null;
  var signalStatus = null;
  var error = '';
  var errorKind = '';

  try {
    if (typeof runMigration2RouteContractRuntimeStatus_ !== 'function') {
      throw new Error('M2_DASH_ROUTE_MISSING: funzione runMigration2RouteContractRuntimeStatus_ non disponibile. Dashboard read routing non verificabile.');
    }
    routeStatus = runMigration2RouteContractRuntimeStatus_();
  } catch (e) {
    error = normalizeRuntimeErrorMessage_(e);
    errorKind = classifyRuntimeFailureKind_(e);
  }

  try {
    if (!error) {
      if (typeof runMigration2RuntimeSignalRuntimeStatus_ !== 'function') {
        throw new Error('M2_DASH_SIGNAL_MISSING: funzione runMigration2RuntimeSignalRuntimeStatus_ non disponibile. Signal contract non verificabile.');
      }
      signalStatus = runMigration2RuntimeSignalRuntimeStatus_();
    }
  } catch (e2) {
    error = normalizeRuntimeErrorMessage_(e2);
    errorKind = classifyRuntimeFailureKind_(e2);
  }

  return buildMigration2DashboardReadResult_({
    routeStatus: routeStatus,
    signalStatus: signalStatus,
    obsoleteHandlers: listMigration2DashboardReadObsoleteSettingsHandlers_(),
    error: error,
    errorKind: errorKind
  });
}

function buildMigration2DashboardReadResult_(data) {
  data = data || {};
  var routeStats = (data.routeStatus && data.routeStatus.stats) || {};
  var signalStats = (data.signalStatus && data.signalStatus.stats) || {};
  var obsoleteHandlers = Array.isArray(data.obsoleteHandlers) ? data.obsoleteHandlers : [];
  var violations = [];

  if (!data.routeStatus || !data.routeStatus.stats) violations.push('m2_route_status_missing');
  if (data.routeStatus && data.routeStatus.ok === false) violations.push('m2_route_not_ok');
  if (String(routeStats.routeVersion || '') !== PHBOX_M2_DASH_REQUIRED_ROUTE_VERSION_) violations.push('m2_route_version_not_v2');
  if (!routeStats.routingContractActive) violations.push('m2_route_contract_not_active');
  if (Number(routeStats.firestoreReads || 0) !== 0) violations.push('m2_route_reads_not_zero');
  if (Number(routeStats.firestoreWrites || 0) !== 0) violations.push('m2_route_writes_not_zero');
  if (routeStats.publishToTarget || routeStats.publishFromTarget) violations.push('m2_route_publish_detected_before_dash');
  if (routeStats.cutover) violations.push('m2_route_cutover_detected_before_dash');
  if (routeStats.lifecycleTouched) violations.push('m2_route_lifecycle_touched_before_dash');

  if (!data.signalStatus || !data.signalStatus.stats) violations.push('m2_signal_status_missing');
  if (data.signalStatus && data.signalStatus.ok === false) violations.push('m2_signal_not_ok');
  if (String(signalStats.signalVersion || '') !== PHBOX_M2_DASH_REQUIRED_SIGNAL_VERSION_) violations.push('m2_signal_version_not_v2');
  if (Number(signalStats.firestoreReads || 0) !== 0) violations.push('m2_signal_reads_not_zero');
  if (Number(signalStats.firestoreWrites || 0) !== 0) violations.push('m2_signal_writes_not_zero');
  if (signalStats.publishToTarget || signalStats.publishFromTarget) violations.push('m2_signal_publish_detected_before_dash');
  if (signalStats.cutover) violations.push('m2_signal_cutover_detected_before_dash');
  if (signalStats.lifecycleTouched) violations.push('m2_signal_lifecycle_touched_before_dash');
  if (signalStats.targetPathBuilt) violations.push('m2_signal_target_path_built_before_dash');

  var routeDecision = String(routeStats.routeDecision || '').trim().toLowerCase();
  var tenantId = String(routeStats.tenantId || '').trim();
  var tenantCanonical = !!routeStats.tenantCanonical;
  var targetReadWriteAuthorized = !!routeStats.targetReadWriteAuthorized;
  var targetRouteAuthorized = !!routeStats.targetRouteAuthorized;
  var targetReadAuthorized = false;
  var legacyDashboardActive = false;
  var dualCheckReadPlanned = false;
  var targetDashboardCollectionsPlanned = [];
  var dashboardReadDecision = 'blocked';
  var reason = '';

  if (obsoleteHandlers.length > 0) violations.push('obsolete_settings_handlers_detected');
  if (data.error) violations.push('m2_dash_error');

  if (violations.length === 0) {
    if (routeDecision === 'legacy') {
      dashboardReadDecision = 'legacy';
      reason = 'legacy_dashboard_read_active';
      legacyDashboardActive = true;
    } else if (routeDecision === 'dual_check') {
      dashboardReadDecision = 'dual_check';
      reason = 'dual_check_dashboard_read_contract_only';
      legacyDashboardActive = true;
      dualCheckReadPlanned = true;
    } else if (routeDecision === 'target') {
      if (!targetRouteAuthorized || !tenantCanonical || !targetReadWriteAuthorized || !tenantId) {
        violations.push('target_dashboard_read_not_authorized');
      } else if (tenantId.indexOf('/') !== -1 || tenantId !== tenantId.trim()) {
        violations.push('target_dashboard_tenant_not_canonical');
      } else {
        dashboardReadDecision = 'target';
        reason = 'target_dashboard_read_authorized_contract_only';
        targetReadAuthorized = true;
        targetDashboardCollectionsPlanned = PHBOX_M2_DASH_TARGET_COLLECTIONS_.slice();
      }
    } else {
      violations.push('dashboard_route_decision_invalid');
    }
  }

  violations = uniqueNonEmptyStrings_(violations);
  if (violations.length > 0) {
    dashboardReadDecision = 'blocked';
    reason = data.error ? 'm2_dash_error' : 'm2_dash_violation';
    targetReadAuthorized = false;
    legacyDashboardActive = false;
    dualCheckReadPlanned = false;
    targetDashboardCollectionsPlanned = [];
  }

  var targetPathBuilt = targetDashboardCollectionsPlanned.length > 0;
  var stats = {
    stage: PHBOX_M2_DASH_STAGE_,
    ok: violations.length === 0,
    skipped: dashboardReadDecision !== 'target',
    reason: reason,
    dashVersion: PHBOX_M2_DASH_VERSION_,
    routeVersion: String(routeStats.routeVersion || ''),
    signalVersion: String(signalStats.signalVersion || ''),
    routeMode: String(routeStats.routeMode || ''),
    routeDecision: routeDecision,
    dashboardReadDecision: dashboardReadDecision,
    dashboardReadContractActive: true,
    targetReadAuthorized: targetReadAuthorized,
    legacyDashboardActive: legacyDashboardActive,
    dualCheckReadPlanned: dualCheckReadPlanned,
    targetDashboardCollectionsPlanned: targetDashboardCollectionsPlanned,
    targetDashboardCollectionsPlannedCount: targetDashboardCollectionsPlanned.length,
    targetGateEnabled: !!routeStats.targetGateEnabled,
    tenantId: tenantId,
    tenantCanonical: tenantCanonical,
    targetReadWriteAuthorized: targetReadWriteAuthorized,
    targetRouteAuthorized: targetRouteAuthorized,
    signalContractOk: !!(data.signalStatus && data.signalStatus.ok),
    obsoleteHandlersCount: obsoleteHandlers.length,
    firestoreReads: 0,
    firestoreWrites: 0,
    publishFromTarget: false,
    publishToTarget: false,
    targetPathBuilt: targetPathBuilt,
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

function runMigration2DashboardReadSelfTest_() {
  var cases = [
    {
      id: 'default_legacy_dashboard_read_active',
      result: buildMigration2DashboardReadResult_({
        routeStatus: buildMigration2DashboardReadSyntheticRouteStatus_({ routeDecision: 'legacy', routeMode: 'legacy', legacyRouteActive: true }),
        signalStatus: buildMigration2DashboardReadSyntheticSignalStatus_({})
      }),
      expectedOk: true,
      expectedDecision: 'legacy',
      expectedTargetPathBuilt: false,
      expectedViolation: ''
    },
    {
      id: 'target_route_authorizes_dashboard_read_contract_only',
      result: buildMigration2DashboardReadResult_({
        routeStatus: buildMigration2DashboardReadSyntheticRouteStatus_({ routeDecision: 'target', routeMode: 'target', targetRouteAuthorized: true, tenantId: 'farmacia_santa_venera', tenantCanonical: true, targetReadWriteAuthorized: true, targetGateEnabled: true }),
        signalStatus: buildMigration2DashboardReadSyntheticSignalStatus_({})
      }),
      expectedOk: true,
      expectedDecision: 'target',
      expectedTargetPathBuilt: true,
      expectedViolation: ''
    },
    {
      id: 'dual_check_preserves_legacy_dashboard_read',
      result: buildMigration2DashboardReadResult_({
        routeStatus: buildMigration2DashboardReadSyntheticRouteStatus_({ routeDecision: 'dual_check', routeMode: 'dual_check', dualCheckPlanned: true, legacyRouteActive: true, tenantId: 'farmacia_santa_venera', tenantCanonical: true, targetReadWriteAuthorized: true, targetGateEnabled: true }),
        signalStatus: buildMigration2DashboardReadSyntheticSignalStatus_({ routeDecision: 'dual_check', dualCheckPlanned: true, legacySignalActive: true })
      }),
      expectedOk: true,
      expectedDecision: 'dual_check',
      expectedTargetPathBuilt: false,
      expectedViolation: ''
    },
    {
      id: 'blocked_route_blocks_dashboard_read',
      result: buildMigration2DashboardReadResult_({
        routeStatus: buildMigration2DashboardReadSyntheticRouteStatus_({ ok: false, routeDecision: 'blocked', routeMode: 'target', violations: ['target_route_requested_without_authorized_gate'] }),
        signalStatus: buildMigration2DashboardReadSyntheticSignalStatus_({})
      }),
      expectedOk: false,
      expectedDecision: 'blocked',
      expectedTargetPathBuilt: false,
      expectedViolation: 'm2_route_not_ok'
    },
    {
      id: 'signal_contract_not_ok_blocks_dashboard_read',
      result: buildMigration2DashboardReadResult_({
        routeStatus: buildMigration2DashboardReadSyntheticRouteStatus_({ routeDecision: 'legacy', routeMode: 'legacy', legacyRouteActive: true }),
        signalStatus: buildMigration2DashboardReadSyntheticSignalStatus_({ ok: false, violations: ['signal_identity_not_canonical'] })
      }),
      expectedOk: false,
      expectedDecision: 'blocked',
      expectedTargetPathBuilt: false,
      expectedViolation: 'm2_signal_not_ok'
    },
    {
      id: 'target_route_noncanonical_tenant_blocks_dashboard_read',
      result: buildMigration2DashboardReadResult_({
        routeStatus: buildMigration2DashboardReadSyntheticRouteStatus_({ routeDecision: 'target', routeMode: 'target', targetRouteAuthorized: true, tenantId: 'bad/tenant', tenantCanonical: false, targetReadWriteAuthorized: true, targetGateEnabled: true }),
        signalStatus: buildMigration2DashboardReadSyntheticSignalStatus_({})
      }),
      expectedOk: false,
      expectedDecision: 'blocked',
      expectedTargetPathBuilt: false,
      expectedViolation: 'target_dashboard_read_not_authorized'
    },
    {
      id: 'target_route_missing_tenant_blocks_before_path',
      result: buildMigration2DashboardReadResult_({
        routeStatus: buildMigration2DashboardReadSyntheticRouteStatus_({ routeDecision: 'target', routeMode: 'target', targetRouteAuthorized: true, tenantId: '', tenantCanonical: true, targetReadWriteAuthorized: true, targetGateEnabled: true }),
        signalStatus: buildMigration2DashboardReadSyntheticSignalStatus_({})
      }),
      expectedOk: false,
      expectedDecision: 'blocked',
      expectedTargetPathBuilt: false,
      expectedViolation: 'target_dashboard_read_not_authorized'
    },
    {
      id: 'route_publish_cutover_lifecycle_blocks_dashboard_read',
      result: buildMigration2DashboardReadResult_({
        routeStatus: buildMigration2DashboardReadSyntheticRouteStatus_({ routeDecision: 'target', routeMode: 'target', targetRouteAuthorized: true, tenantId: 'farmacia_santa_venera', tenantCanonical: true, targetReadWriteAuthorized: true, targetPathBuilt: true, publishToTarget: true, cutover: true, lifecycleTouched: true }),
        signalStatus: buildMigration2DashboardReadSyntheticSignalStatus_({})
      }),
      expectedOk: false,
      expectedDecision: 'blocked',
      expectedTargetPathBuilt: false,
      expectedViolation: 'm2_route_publish_detected_before_dash'
    },
    {
      id: 'obsolete_settings_handler_blocks_dashboard_read',
      result: buildMigration2DashboardReadResult_({
        routeStatus: buildMigration2DashboardReadSyntheticRouteStatus_({ routeDecision: 'legacy', routeMode: 'legacy', legacyRouteActive: true }),
        signalStatus: buildMigration2DashboardReadSyntheticSignalStatus_({}),
        obsoleteHandlers: ['runMigration2RuntimeSignalSettingsTest']
      }),
      expectedOk: false,
      expectedDecision: 'blocked',
      expectedTargetPathBuilt: false,
      expectedViolation: 'obsolete_settings_handlers_detected'
    },
    {
      id: 'm2_dash_runtime_zero_read_write_contract',
      result: buildMigration2DashboardReadResult_({
        routeStatus: buildMigration2DashboardReadSyntheticRouteStatus_({ routeDecision: 'legacy', routeMode: 'legacy', legacyRouteActive: true }),
        signalStatus: buildMigration2DashboardReadSyntheticSignalStatus_({})
      }),
      expectedOk: true,
      expectedDecision: 'legacy',
      expectedTargetPathBuilt: false,
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
    if (stats.dashboardReadDecision !== item.expectedDecision) mismatchReasons.push('expected_dashboard_decision_mismatch');
    if (!!stats.targetPathBuilt !== !!item.expectedTargetPathBuilt) mismatchReasons.push('expected_target_path_built_mismatch');
    if (item.expectedViolation && violations.indexOf(item.expectedViolation) === -1) mismatchReasons.push('expected_violation_missing');
    if (!item.expectedViolation && violations.length > 0) mismatchReasons.push('unexpected_violation');
    var ok = mismatchReasons.length === 0;
    if (ok) passed++; else failed++;
    return {
      id: item.id,
      passed: ok,
      ok: !!stats.ok,
      reason: stats.reason || '',
      routeDecision: stats.routeDecision || '',
      dashboardReadDecision: stats.dashboardReadDecision || '',
      targetReadAuthorized: !!stats.targetReadAuthorized,
      legacyDashboardActive: !!stats.legacyDashboardActive,
      dualCheckReadPlanned: !!stats.dualCheckReadPlanned,
      targetDashboardCollectionsPlannedCount: stats.targetDashboardCollectionsPlannedCount || 0,
      tenantId: stats.tenantId || '',
      tenantCanonical: !!stats.tenantCanonical,
      targetReadWriteAuthorized: !!stats.targetReadWriteAuthorized,
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
    dashVersion: PHBOX_M2_DASH_VERSION_,
    routeVersion: PHBOX_M2_DASH_REQUIRED_ROUTE_VERSION_,
    signalVersion: PHBOX_M2_DASH_REQUIRED_SIGNAL_VERSION_,
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

function buildMigration2DashboardReadSyntheticRouteStatus_(overrides) {
  overrides = overrides || {};
  var stats = {
    ok: Object.prototype.hasOwnProperty.call(overrides, 'ok') ? !!overrides.ok : true,
    routeVersion: String(overrides.routeVersion || PHBOX_M2_DASH_REQUIRED_ROUTE_VERSION_),
    routeMode: String(overrides.routeMode || 'legacy'),
    routeDecision: String(overrides.routeDecision || 'legacy'),
    routingContractActive: Object.prototype.hasOwnProperty.call(overrides, 'routingContractActive') ? !!overrides.routingContractActive : true,
    targetRouteAuthorized: !!overrides.targetRouteAuthorized,
    legacyRouteActive: !!overrides.legacyRouteActive,
    dualCheckPlanned: !!overrides.dualCheckPlanned,
    targetGateEnabled: !!overrides.targetGateEnabled,
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

function buildMigration2DashboardReadSyntheticSignalStatus_(overrides) {
  overrides = overrides || {};
  var stats = {
    ok: Object.prototype.hasOwnProperty.call(overrides, 'ok') ? !!overrides.ok : true,
    signalVersion: String(overrides.signalVersion || PHBOX_M2_DASH_REQUIRED_SIGNAL_VERSION_),
    routeVersion: String(overrides.routeVersion || PHBOX_M2_DASH_REQUIRED_ROUTE_VERSION_),
    routeDecision: String(overrides.routeDecision || 'legacy'),
    signalTargetAware: !!overrides.signalTargetAware,
    hasSignal: !!overrides.hasSignal,
    legacySignalActive: Object.prototype.hasOwnProperty.call(overrides, 'legacySignalActive') ? !!overrides.legacySignalActive : true,
    dualCheckPlanned: !!overrides.dualCheckPlanned,
    targetSignalAuthorized: !!overrides.targetSignalAuthorized,
    targetSignalPlanned: !!overrides.targetSignalPlanned,
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

function listMigration2DashboardReadObsoleteSettingsHandlers_() {
  var names = [
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
    'runMigration1DocumentationSettingsTest',
    'getMigration1DocumentationSettingsStatus',
    'runMigration1FinalCleanupSettingsTest',
    'getMigration1FinalCleanupSettingsStatus',
    'runMigration1CostAuditSettingsTest',
    'getMigration1CostAuditSettingsStatus',
    'runMigration1E2ESettingsTest',
    'getMigration1E2ESettingsStatus',
    'runMigration1CutoverSettingsTest',
    'getMigration1CutoverSettingsStatus',
    'runMigration1DualVerifierSettingsTest',
    'getMigration1DualVerifierSettingsStatus',
    'runMigration1DashboardSettingsTest',
    'getMigration1DashboardSettingsStatus',
    'runMigration1RuntimeSignalSettingsTest',
    'getMigration1RuntimeSignalSettingsStatus',
    'runMigration1TargetPublishSettingsTest',
    'getMigration1TargetPublishSettingsStatus',
    'runMigration1IdentityResolverSettingsTest',
    'getMigration1IdentityResolverSettingsStatus',
    'runMigration1TargetRuntimeGateSettingsTest',
    'getMigration1TargetRuntimeGateSettingsStatus'
  ];
  return names.filter(function (name) {
    try {
      return typeof this[name] === 'function';
    } catch (e) {
      return false;
    }
  }, this);
}

function formatMigration2DashboardReadSelfTestFeedback_(result) {
  result = result || {};
  var lines = [];
  lines.push('MIGRATION_2_DASH_TEST');
  lines.push('ok=' + String(!!result.ok));
  lines.push('testCount=' + String(result.testCount || 0));
  lines.push('passedCount=' + String(result.passedCount || 0));
  lines.push('failedCount=' + String(result.failedCount || 0));
  lines.push('dashVersion=' + String(result.dashVersion || PHBOX_M2_DASH_VERSION_));
  lines.push('routeVersion=' + String(result.routeVersion || PHBOX_M2_DASH_REQUIRED_ROUTE_VERSION_));
  lines.push('signalVersion=' + String(result.signalVersion || PHBOX_M2_DASH_REQUIRED_SIGNAL_VERSION_));
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
    lines.push('  reason=' + String(item.reason || ''));
    lines.push('  routeDecision=' + String(item.routeDecision || ''));
    lines.push('  dashboardReadDecision=' + String(item.dashboardReadDecision || ''));
    lines.push('  targetReadAuthorized=' + String(!!item.targetReadAuthorized));
    lines.push('  legacyDashboardActive=' + String(!!item.legacyDashboardActive));
    lines.push('  dualCheckReadPlanned=' + String(!!item.dualCheckReadPlanned));
    lines.push('  targetDashboardCollectionsPlannedCount=' + String(item.targetDashboardCollectionsPlannedCount || 0));
    lines.push('  tenantId=' + String(item.tenantId || ''));
    lines.push('  tenantCanonical=' + String(!!item.tenantCanonical));
    lines.push('  targetReadWriteAuthorized=' + String(!!item.targetReadWriteAuthorized));
    lines.push('  firestoreReads=' + String(item.firestoreReads || 0));
    lines.push('  firestoreWrites=' + String(item.firestoreWrites || 0));
    lines.push('  publishFromTarget=' + String(!!item.publishFromTarget));
    lines.push('  publishToTarget=' + String(!!item.publishToTarget));
    lines.push('  targetPathBuilt=' + String(!!item.targetPathBuilt));
    lines.push('  cutover=' + String(!!item.cutover));
    lines.push('  lifecycleTouched=' + String(!!item.lifecycleTouched));
    lines.push('  violations=' + (item.violations && item.violations.length ? item.violations.join(',') : 'none'));
    lines.push('  mismatchReasons=' + (item.mismatchReasons && item.mismatchReasons.length ? item.mismatchReasons.join(',') : 'none'));
  });
  return lines.join('\n');
}

function formatMigration2DashboardReadRuntimeFeedback_(result) {
  var stats = (result && result.stats) || {};
  var lines = [];
  lines.push('MIGRATION_2_DASH_RUNTIME_STATUS');
  lines.push('ok=' + String(!!(result && result.ok)));
  lines.push('skipped=' + String(!!stats.skipped));
  lines.push('reason=' + String(stats.reason || ''));
  lines.push('dashVersion=' + String(stats.dashVersion || PHBOX_M2_DASH_VERSION_));
  lines.push('routeVersion=' + String(stats.routeVersion || ''));
  lines.push('signalVersion=' + String(stats.signalVersion || ''));
  lines.push('routeMode=' + String(stats.routeMode || ''));
  lines.push('routeDecision=' + String(stats.routeDecision || ''));
  lines.push('dashboardReadDecision=' + String(stats.dashboardReadDecision || ''));
  lines.push('dashboardReadContractActive=' + String(!!stats.dashboardReadContractActive));
  lines.push('targetReadAuthorized=' + String(!!stats.targetReadAuthorized));
  lines.push('legacyDashboardActive=' + String(!!stats.legacyDashboardActive));
  lines.push('dualCheckReadPlanned=' + String(!!stats.dualCheckReadPlanned));
  lines.push('targetDashboardCollectionsPlannedCount=' + String(stats.targetDashboardCollectionsPlannedCount || 0));
  lines.push('targetGateEnabled=' + String(!!stats.targetGateEnabled));
  lines.push('tenantId=' + String(stats.tenantId || ''));
  lines.push('tenantCanonical=' + String(!!stats.tenantCanonical));
  lines.push('targetReadWriteAuthorized=' + String(!!stats.targetReadWriteAuthorized));
  lines.push('targetRouteAuthorized=' + String(!!stats.targetRouteAuthorized));
  lines.push('signalContractOk=' + String(!!stats.signalContractOk));
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
  lines.push('error=' + (stats.error || 'none'));
  lines.push('errorKind=' + (stats.errorKind || 'none'));
  return lines.join('\n');
}
