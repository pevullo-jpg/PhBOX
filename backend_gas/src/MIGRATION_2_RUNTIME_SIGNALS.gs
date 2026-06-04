var PHBOX_M2_SIGNAL_VERSION_ = 'M2_SIGNAL_v2';
var PHBOX_M2_SIGNAL_STAGE_ = 'migration2_runtime_signals_target_aware';

function runMigration2RuntimeSignalRuntimeStatus_() {
  var routeStatus = null;
  var error = '';
  var errorKind = '';

  try {
    if (typeof runMigration2RouteContractRuntimeStatus_ !== 'function') {
      throw new Error('M2_SIGNAL_ROUTE_MISSING: funzione runMigration2RouteContractRuntimeStatus_ non disponibile. Runtime signals M2 non verificabili.');
    }
    routeStatus = runMigration2RouteContractRuntimeStatus_();
  } catch (e) {
    error = normalizeRuntimeErrorMessage_(e);
    errorKind = classifyRuntimeFailureKind_(e);
  }

  return buildMigration2RuntimeSignalResult_({
    routeStatus: routeStatus,
    signal: null,
    obsoleteHandlers: listMigration2RuntimeSignalObsoleteSettingsHandlers_(),
    error: error,
    errorKind: errorKind
  });
}

function buildMigration2RuntimeSignalResult_(data) {
  data = data || {};
  var routeStats = (data.routeStatus && data.routeStatus.stats) || {};
  var signal = data.signal || {};
  var hasSignal = !!data.hasSignal || hasMigration2RuntimeSignalPayload_(signal);
  var obsoleteHandlers = Array.isArray(data.obsoleteHandlers) ? data.obsoleteHandlers : [];
  var violations = [];

  if (!data.routeStatus || !data.routeStatus.stats) violations.push('m2_route_status_missing');
  if (data.routeStatus && data.routeStatus.ok === false) violations.push('m2_route_not_ok');
  if (Number(routeStats.firestoreReads || 0) !== 0) violations.push('m2_route_reads_not_zero');
  if (Number(routeStats.firestoreWrites || 0) !== 0) violations.push('m2_route_writes_not_zero');
  if (routeStats.targetPathBuilt) violations.push('m2_route_target_path_built_before_signal');
  if (routeStats.publishToTarget || routeStats.publishFromTarget) violations.push('m2_route_publish_detected_before_signal');
  if (routeStats.cutover) violations.push('m2_route_cutover_detected_before_signal');
  if (routeStats.lifecycleTouched) violations.push('m2_route_lifecycle_touched_before_signal');
  if (obsoleteHandlers.length > 0) violations.push('obsolete_settings_handlers_detected');
  if (data.error) violations.push('m2_signal_error');

  var routeDecision = String(routeStats.routeDecision || '').trim();
  var targetRouteAuthorized = routeDecision === 'target' && !!routeStats.targetRouteAuthorized && !!routeStats.tenantCanonical && !!routeStats.targetReadWriteAuthorized && !!String(routeStats.tenantId || '');
  var legacyRouteActive = routeDecision === 'legacy' && !!routeStats.legacyRouteActive;
  var dualCheckPlanned = routeDecision === 'dual_check' && !!routeStats.dualCheckPlanned;
  var identity = hasSignal ? resolveMigration2RuntimeSignalIdentity_(signal) : buildMigration2RuntimeSignalEmptyIdentity_();

  if (hasSignal && (!identity.identityType || identity.identityType === 'unknown' || !identity.identityAnchorCanonical)) {
    violations.push('signal_identity_not_canonical');
  }

  var targetSignalAuthorized = false;
  var targetSignalPlanned = false;
  var legacySignalActive = false;
  var dualCheckSignalPlanned = false;
  var signalTargetAware = hasSignal && violations.length === 0;
  var reason = '';

  if (!hasSignal && violations.length === 0) {
    if (legacyRouteActive) {
      reason = 'legacy_route_active';
      legacySignalActive = true;
    } else if (dualCheckPlanned) {
      reason = 'dual_check_route_no_signal';
      legacySignalActive = true;
      dualCheckSignalPlanned = true;
    } else if (targetRouteAuthorized) {
      reason = 'target_route_authorized_no_signal';
      targetSignalAuthorized = true;
    } else {
      reason = 'no_signal_to_process';
    }
  }

  if (hasSignal && violations.length === 0) {
    if (targetRouteAuthorized) {
      targetSignalAuthorized = true;
      targetSignalPlanned = true;
      reason = 'target_signal_authorized_contract_only';
    } else if (dualCheckPlanned) {
      legacySignalActive = true;
      dualCheckSignalPlanned = true;
      reason = 'dual_check_signal_contract_only';
    } else if (legacyRouteActive) {
      legacySignalActive = true;
      reason = 'legacy_signal_active';
    } else {
      violations.push('m2_signal_route_not_authorized');
      reason = 'm2_signal_violation';
    }
  }

  violations = uniqueNonEmptyStrings_(violations);
  if (violations.length > 0) {
    targetSignalAuthorized = false;
    targetSignalPlanned = false;
    legacySignalActive = false;
    dualCheckSignalPlanned = false;
    signalTargetAware = false;
    reason = data.error ? 'm2_signal_error' : 'm2_signal_violation';
  }

  var stats = {
    stage: PHBOX_M2_SIGNAL_STAGE_,
    ok: violations.length === 0,
    skipped: violations.length === 0 && (!hasSignal || !targetSignalPlanned),
    reason: reason || 'm2_signal_status',
    signalVersion: PHBOX_M2_SIGNAL_VERSION_,
    routeVersion: String(routeStats.routeVersion || ''),
    routeMode: String(routeStats.routeMode || ''),
    routeDecision: routeDecision,
    routingContractActive: !!routeStats.routingContractActive,
    signalTargetAware: !!signalTargetAware,
    hasSignal: !!hasSignal,
    signalDomain: String(signal.domain || ''),
    signalOperation: String(signal.operation || ''),
    identityType: String(identity.identityType || ''),
    identityAnchor: String(identity.identityAnchor || ''),
    identityAnchorCanonical: !!identity.identityAnchorCanonical,
    targetFiscalCode: String(identity.identityType || '') === 'cf' ? normalizeCf_(identity.targetFiscalCode || '') : '',
    legacyNoCfCode: String(identity.legacyNoCfCode || ''),
    identityResolutionReasons: uniqueNonEmptyStrings_(identity.identityResolutionReasons || []),
    targetGateEnabled: !!routeStats.targetGateEnabled,
    tenantId: String(routeStats.tenantId || ''),
    tenantCanonical: !!routeStats.tenantCanonical,
    targetReadWriteAuthorized: !!routeStats.targetReadWriteAuthorized,
    targetRouteAuthorized: !!routeStats.targetRouteAuthorized,
    targetSignalAuthorized: !!targetSignalAuthorized,
    targetSignalPlanned: !!targetSignalPlanned,
    legacySignalActive: !!legacySignalActive,
    dualCheckPlanned: !!dualCheckSignalPlanned,
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

function hasMigration2RuntimeSignalPayload_(signal) {
  signal = signal || {};
  return !!(
    signal.domain ||
    signal.operation ||
    signal.targetPath ||
    signal.targetDocumentId ||
    signal.targetFiscalCode ||
    signal.identityType ||
    signal.identityAnchor ||
    signal.targetIdentityAnchor ||
    signal.legacyNoCfCode
  );
}

function resolveMigration2RuntimeSignalIdentity_(signal) {
  signal = signal || {};
  var identityType = String(signal.identityType || '').trim().toLowerCase();
  var targetFiscalCode = identityType === 'nocf'
    ? ''
    : normalizeCf_(signal.targetFiscalCode || signal.cf || '');
  var overrides = {
    targetFiscalCode: targetFiscalCode,
    identityType: signal.identityType || '',
    identityAnchor: signal.identityAnchor || signal.targetIdentityAnchor || '',
    legacyNoCfCode: signal.legacyNoCfCode || '',
    identityResolutionReasons: Array.isArray(signal.identityResolutionReasons) ? signal.identityResolutionReasons : []
  };

  if (typeof resolveMigration1RuntimeSignalIdentity_ === 'function') {
    return resolveMigration1RuntimeSignalIdentity_(signal, overrides);
  }

  return buildMigration2RuntimeSignalFallbackIdentity_(overrides);
}

function buildMigration2RuntimeSignalFallbackIdentity_(overrides) {
  overrides = overrides || {};
  var identityType = String(overrides.identityType || '').trim().toLowerCase();
  var targetFiscalCode = normalizeCf_(overrides.targetFiscalCode || '');
  var identityAnchor = String(overrides.identityAnchor || '').trim();
  if (identityType === 'cf' && targetFiscalCode) {
    return {
      identityType: 'cf',
      identityAnchor: targetFiscalCode,
      identityAnchorCanonical: true,
      targetFiscalCode: targetFiscalCode,
      legacyNoCfCode: '',
      identityResolutionReasons: uniqueNonEmptyStrings_(overrides.identityResolutionReasons || ['cf_identity'])
    };
  }
  if (identityType === 'nocf' && identityAnchor) {
    return {
      identityType: 'nocf',
      identityAnchor: identityAnchor,
      identityAnchorCanonical: true,
      targetFiscalCode: '',
      legacyNoCfCode: String(overrides.legacyNoCfCode || identityAnchor).trim(),
      identityResolutionReasons: uniqueNonEmptyStrings_(overrides.identityResolutionReasons || ['nocf_identity'])
    };
  }
  return buildMigration2RuntimeSignalEmptyIdentity_();
}

function buildMigration2RuntimeSignalEmptyIdentity_() {
  return {
    identityType: '',
    identityAnchor: '',
    identityAnchorCanonical: false,
    targetFiscalCode: '',
    legacyNoCfCode: '',
    identityResolutionReasons: []
  };
}

function runMigration2RuntimeSignalSelfTest_() {
  var cfSignal = buildMigration2RuntimeSignalTestSignal_({
    identityType: 'cf',
    targetFiscalCode: 'RSSMRA80A01H501U',
    identityAnchor: 'RSSMRA80A01H501U'
  });
  var nocfSignal = buildMigration2RuntimeSignalTestSignal_({
    identityType: 'nocf',
    identityAnchor: 'NOCF_MANUAL_001',
    legacyNoCfCode: 'NOCF_MANUAL_001'
  });
  var nocfStaleCfSignal = buildMigration2RuntimeSignalTestSignal_({
    identityType: 'nocf',
    identityAnchor: 'NOCF_MANUAL_002',
    legacyNoCfCode: 'NOCF_MANUAL_002',
    targetFiscalCode: 'RSSMRA80A01H501U'
  });

  var cases = [
    { id: 'default_runtime_no_signal_legacy_skips', result: buildMigration2RuntimeSignalResult_({ routeStatus: buildMigration2RuntimeSignalSyntheticRouteStatus_({ routeDecision: 'legacy', routeMode: 'legacy', legacyRouteActive: true }) }), expectedOk: true, expectedReason: 'legacy_route_active', expectedTargetPlanned: false, expectedIdentityType: '', expectedViolation: '' },
    { id: 'dual_check_no_signal_preserves_legacy_active', result: buildMigration2RuntimeSignalResult_({ routeStatus: buildMigration2RuntimeSignalSyntheticRouteStatus_({ routeDecision: 'dual_check', routeMode: 'dual_check', dualCheckPlanned: true, legacyRouteActive: true, tenantId: 'farmacia_santa_venera', tenantCanonical: true, targetReadWriteAuthorized: true }) }), expectedOk: true, expectedReason: 'dual_check_route_no_signal', expectedTargetPlanned: false, expectedIdentityType: '', expectedLegacySignalActive: true, expectedViolation: '' },
    { id: 'target_route_cf_signal_authorized_contract_only', result: buildMigration2RuntimeSignalResult_({ routeStatus: buildMigration2RuntimeSignalSyntheticRouteStatus_({ routeDecision: 'target', routeMode: 'target', targetRouteAuthorized: true, tenantId: 'farmacia_santa_venera', tenantCanonical: true, targetReadWriteAuthorized: true }), signal: cfSignal }), expectedOk: true, expectedReason: 'target_signal_authorized_contract_only', expectedTargetPlanned: true, expectedIdentityType: 'cf', expectedViolation: '' },
    { id: 'target_route_nocf_signal_preserves_anchor_without_cf', result: buildMigration2RuntimeSignalResult_({ routeStatus: buildMigration2RuntimeSignalSyntheticRouteStatus_({ routeDecision: 'target', routeMode: 'target', targetRouteAuthorized: true, tenantId: 'farmacia_santa_venera', tenantCanonical: true, targetReadWriteAuthorized: true }), signal: nocfSignal }), expectedOk: true, expectedReason: 'target_signal_authorized_contract_only', expectedTargetPlanned: true, expectedIdentityType: 'nocf', expectedTargetFiscalCode: '', expectedViolation: '' },
    { id: 'dual_check_route_signal_contract_only', result: buildMigration2RuntimeSignalResult_({ routeStatus: buildMigration2RuntimeSignalSyntheticRouteStatus_({ routeDecision: 'dual_check', routeMode: 'dual_check', dualCheckPlanned: true, legacyRouteActive: true, tenantId: 'farmacia_santa_venera', tenantCanonical: true, targetReadWriteAuthorized: true }), signal: cfSignal }), expectedOk: true, expectedReason: 'dual_check_signal_contract_only', expectedTargetPlanned: false, expectedIdentityType: 'cf', expectedViolation: '' },
    { id: 'legacy_route_signal_stays_legacy', result: buildMigration2RuntimeSignalResult_({ routeStatus: buildMigration2RuntimeSignalSyntheticRouteStatus_({ routeDecision: 'legacy', routeMode: 'legacy', legacyRouteActive: true }), signal: cfSignal }), expectedOk: true, expectedReason: 'legacy_signal_active', expectedTargetPlanned: false, expectedIdentityType: 'cf', expectedViolation: '' },
    { id: 'blocked_route_blocks_signal', result: buildMigration2RuntimeSignalResult_({ routeStatus: buildMigration2RuntimeSignalSyntheticRouteStatus_({ ok: false, routeDecision: 'blocked', routeMode: 'target', violations: ['target_route_requested_without_authorized_gate'] }), signal: cfSignal }), expectedOk: false, expectedReason: 'm2_signal_violation', expectedTargetPlanned: false, expectedIdentityType: 'cf', expectedViolation: 'm2_route_not_ok' },
    { id: 'missing_identity_blocks_target_signal', result: buildMigration2RuntimeSignalResult_({ routeStatus: buildMigration2RuntimeSignalSyntheticRouteStatus_({ routeDecision: 'target', routeMode: 'target', targetRouteAuthorized: true, tenantId: 'farmacia_santa_venera', tenantCanonical: true, targetReadWriteAuthorized: true }), signal: buildMigration2RuntimeSignalTestSignal_({ identityType: '', targetFiscalCode: '', identityAnchor: '' }) }), expectedOk: false, expectedReason: 'm2_signal_violation', expectedTargetPlanned: false, expectedIdentityType: 'unknown', expectedViolation: 'signal_identity_not_canonical' },
    { id: 'nocf_with_stale_cf_does_not_keep_cf', result: buildMigration2RuntimeSignalResult_({ routeStatus: buildMigration2RuntimeSignalSyntheticRouteStatus_({ routeDecision: 'target', routeMode: 'target', targetRouteAuthorized: true, tenantId: 'farmacia_santa_venera', tenantCanonical: true, targetReadWriteAuthorized: true }), signal: nocfStaleCfSignal }), expectedOk: true, expectedReason: 'target_signal_authorized_contract_only', expectedTargetPlanned: true, expectedIdentityType: 'nocf', expectedTargetFiscalCode: '', expectedViolation: '' },
    { id: 'route_publish_cutover_lifecycle_blocks_signal', result: buildMigration2RuntimeSignalResult_({ routeStatus: buildMigration2RuntimeSignalSyntheticRouteStatus_({ routeDecision: 'target', routeMode: 'target', targetRouteAuthorized: true, tenantId: 'farmacia_santa_venera', tenantCanonical: true, targetReadWriteAuthorized: true, targetPathBuilt: true, publishToTarget: true, cutover: true, lifecycleTouched: true }), signal: cfSignal }), expectedOk: false, expectedReason: 'm2_signal_violation', expectedTargetPlanned: false, expectedIdentityType: 'cf', expectedViolation: 'm2_route_target_path_built_before_signal' },
    { id: 'm2_signal_runtime_zero_read_write_contract', result: buildMigration2RuntimeSignalResult_({ routeStatus: buildMigration2RuntimeSignalSyntheticRouteStatus_({ routeDecision: 'legacy', routeMode: 'legacy', legacyRouteActive: true }) }), expectedOk: true, expectedReason: 'legacy_route_active', expectedTargetPlanned: false, expectedIdentityType: '', expectedViolation: '' }
  ];

  var passed = 0;
  var failed = 0;
  var items = cases.map(function (item) {
    var stats = (item.result && item.result.stats) || {};
    var violations = stats.violations || [];
    var mismatchReasons = [];
    if (!!stats.ok !== item.expectedOk) mismatchReasons.push('expected_ok_mismatch');
    if (stats.reason !== item.expectedReason) mismatchReasons.push('expected_reason_mismatch');
    if (!!stats.targetSignalPlanned !== !!item.expectedTargetPlanned) mismatchReasons.push('expected_target_signal_planned_mismatch');
    if (String(stats.identityType || '') !== String(item.expectedIdentityType || '')) mismatchReasons.push('expected_identity_type_mismatch');
    if (Object.prototype.hasOwnProperty.call(item, 'expectedTargetFiscalCode') && String(stats.targetFiscalCode || '') !== String(item.expectedTargetFiscalCode || '')) mismatchReasons.push('expected_target_fiscal_code_mismatch');
    if (Object.prototype.hasOwnProperty.call(item, 'expectedLegacySignalActive') && !!stats.legacySignalActive !== !!item.expectedLegacySignalActive) mismatchReasons.push('expected_legacy_signal_active_mismatch');
    if (item.expectedViolation && violations.indexOf(item.expectedViolation) === -1) mismatchReasons.push('expected_violation_missing');
    if (!item.expectedViolation && violations.length > 0) mismatchReasons.push('unexpected_violation');
    var ok = mismatchReasons.length === 0;
    if (ok) passed++; else failed++;
    return {
      id: item.id,
      passed: ok,
      ok: !!stats.ok,
      reason: stats.reason,
      expectedReason: item.expectedReason,
      routeDecision: stats.routeDecision,
      signalTargetAware: !!stats.signalTargetAware,
      targetSignalAuthorized: !!stats.targetSignalAuthorized,
      targetSignalPlanned: !!stats.targetSignalPlanned,
      legacySignalActive: !!stats.legacySignalActive,
      dualCheckPlanned: !!stats.dualCheckPlanned,
      identityType: stats.identityType || '',
      identityAnchor: stats.identityAnchor || '',
      targetFiscalCode: stats.targetFiscalCode || '',
      legacyNoCfCode: stats.legacyNoCfCode || '',
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
    signalVersion: PHBOX_M2_SIGNAL_VERSION_,
    routeVersion: PHBOX_M2_ROUTE_VERSION_,
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

function buildMigration2RuntimeSignalTestSignal_(overrides) {
  overrides = overrides || {};
  return {
    domain: String(overrides.domain || 'debts'),
    operation: String(overrides.operation || 'update'),
    targetPath: overrides.targetPath || ['debts', 'debt_1'],
    targetFiscalCode: Object.prototype.hasOwnProperty.call(overrides, 'targetFiscalCode') ? overrides.targetFiscalCode : 'RSSMRA80A01H501U',
    identityType: Object.prototype.hasOwnProperty.call(overrides, 'identityType') ? overrides.identityType : 'cf',
    identityAnchor: Object.prototype.hasOwnProperty.call(overrides, 'identityAnchor') ? overrides.identityAnchor : 'RSSMRA80A01H501U',
    legacyNoCfCode: String(overrides.legacyNoCfCode || ''),
    identityResolutionReasons: Array.isArray(overrides.identityResolutionReasons) ? overrides.identityResolutionReasons : []
  };
}

function buildMigration2RuntimeSignalSyntheticRouteStatus_(overrides) {
  overrides = overrides || {};
  var stats = {
    ok: Object.prototype.hasOwnProperty.call(overrides, 'ok') ? !!overrides.ok : true,
    routeVersion: PHBOX_M2_ROUTE_VERSION_,
    routeMode: String(overrides.routeMode || 'legacy'),
    routeDecision: String(overrides.routeDecision || 'legacy'),
    routingContractActive: true,
    targetGateEnabled: !!overrides.targetGateEnabled,
    tenantId: String(overrides.tenantId || ''),
    tenantCanonical: !!overrides.tenantCanonical,
    targetReadWriteAuthorized: !!overrides.targetReadWriteAuthorized,
    targetRouteAuthorized: !!overrides.targetRouteAuthorized,
    legacyRouteActive: !!overrides.legacyRouteActive,
    dualCheckPlanned: !!overrides.dualCheckPlanned,
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

function listMigration2RuntimeSignalObsoleteSettingsHandlers_() {
  var names = [
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
    return isMigration2RuntimeSignalGlobalFunction_(name);
  });
}

function isMigration2RuntimeSignalGlobalFunction_(name) {
  try {
    return typeof globalThis !== 'undefined' && typeof globalThis[name] === 'function';
  } catch (e) {
    return false;
  }
}

function formatMigration2RuntimeSignalSelfTestFeedback_(result) {
  result = result || runMigration2RuntimeSignalSelfTest_();
  var lines = [];
  lines.push('MIGRATION_2_SIGNAL_TEST');
  lines.push('ok=' + String(!!result.ok));
  lines.push('testCount=' + String(result.testCount || 0));
  lines.push('passedCount=' + String(result.passedCount || 0));
  lines.push('failedCount=' + String(result.failedCount || 0));
  lines.push('signalVersion=' + String(result.signalVersion || ''));
  lines.push('routeVersion=' + String(result.routeVersion || ''));
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
    lines.push('  signalTargetAware=' + String(!!item.signalTargetAware));
    lines.push('  targetSignalAuthorized=' + String(!!item.targetSignalAuthorized));
    lines.push('  targetSignalPlanned=' + String(!!item.targetSignalPlanned));
    lines.push('  legacySignalActive=' + String(!!item.legacySignalActive));
    lines.push('  dualCheckPlanned=' + String(!!item.dualCheckPlanned));
    lines.push('  identityType=' + String(item.identityType || ''));
    lines.push('  identityAnchor=' + String(item.identityAnchor || ''));
    lines.push('  targetFiscalCode=' + String(item.targetFiscalCode || ''));
    lines.push('  legacyNoCfCode=' + String(item.legacyNoCfCode || ''));
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

function formatMigration2RuntimeSignalRuntimeFeedback_(result) {
  result = result || runMigration2RuntimeSignalRuntimeStatus_();
  var stats = (result && result.stats) || {};
  var lines = [];
  lines.push('MIGRATION_2_SIGNAL_RUNTIME_STATUS');
  lines.push('ok=' + String(!!(result && result.ok)));
  lines.push('skipped=' + String(!!stats.skipped));
  lines.push('reason=' + String(stats.reason || ''));
  lines.push('signalVersion=' + String(stats.signalVersion || ''));
  lines.push('routeVersion=' + String(stats.routeVersion || ''));
  lines.push('routeMode=' + String(stats.routeMode || ''));
  lines.push('routeDecision=' + String(stats.routeDecision || ''));
  lines.push('routingContractActive=' + String(!!stats.routingContractActive));
  lines.push('signalTargetAware=' + String(!!stats.signalTargetAware));
  lines.push('hasSignal=' + String(!!stats.hasSignal));
  lines.push('signalDomain=' + String(stats.signalDomain || ''));
  lines.push('signalOperation=' + String(stats.signalOperation || ''));
  lines.push('identityType=' + String(stats.identityType || ''));
  lines.push('identityAnchor=' + String(stats.identityAnchor || ''));
  lines.push('identityAnchorCanonical=' + String(!!stats.identityAnchorCanonical));
  lines.push('targetFiscalCode=' + String(stats.targetFiscalCode || ''));
  lines.push('legacyNoCfCode=' + String(stats.legacyNoCfCode || ''));
  lines.push('targetGateEnabled=' + String(!!stats.targetGateEnabled));
  lines.push('tenantId=' + String(stats.tenantId || ''));
  lines.push('tenantCanonical=' + String(!!stats.tenantCanonical));
  lines.push('targetReadWriteAuthorized=' + String(!!stats.targetReadWriteAuthorized));
  lines.push('targetRouteAuthorized=' + String(!!stats.targetRouteAuthorized));
  lines.push('targetSignalAuthorized=' + String(!!stats.targetSignalAuthorized));
  lines.push('targetSignalPlanned=' + String(!!stats.targetSignalPlanned));
  lines.push('legacySignalActive=' + String(!!stats.legacySignalActive));
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
