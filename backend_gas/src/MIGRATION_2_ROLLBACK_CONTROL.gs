var PHBOX_M2_ROLLBACK_VERSION_ = 'M2_ROLLBACK_v4';
var PHBOX_M2_ROLLBACK_STAGE_ = 'migration2_rollback_controlled_legacy_restore';
var PHBOX_M2_ROLLBACK_ENABLED_PROPERTY_ = 'PHBOX_M2_ROLLBACK_ENABLED';
var PHBOX_M2_ROLLBACK_TENANT_ID_PROPERTY_ = 'PHBOX_M2_ROLLBACK_TENANT_ID';
var PHBOX_M2_ROLLBACK_REQUIRED_CUTON_VERSION_ = 'M2_CUTON_v3';
var PHBOX_M2_ROLLBACK_REQUIRED_VERIFY_VERSION_ = 'M2_VERIFY_v3';
var PHBOX_M2_ROLLBACK_REQUIRED_DASH_VERSION_ = 'M2_DASH_v1';
var PHBOX_M2_ROLLBACK_REQUIRED_ROUTE_VERSION_ = 'M2_ROUTE_v2';
var PHBOX_M2_ROLLBACK_REQUIRED_SIGNAL_VERSION_ = 'M2_SIGNAL_v2';

function runMigration2RollbackRuntimeStatus_() {
  var settings = readMigration2RollbackSettings_();
  if (!settings.enabled) {
    return buildMigration2RollbackResult_({
      enabled: false,
      rollbackTenantId: settings.rollbackTenantId,
      obsoleteHandlers: listMigration2RollbackObsoleteSettingsHandlers_()
    });
  }

  var cutonStatus = null;
  var error = '';
  var errorKind = '';
  try {
    if (typeof runMigration2CutonRuntimeStatus_ !== 'function') {
      throw new Error('M2_ROLLBACK_CUTON_MISSING: funzione runMigration2CutonRuntimeStatus_ non disponibile. Rollback M2 non verificabile.');
    }
    cutonStatus = runMigration2CutonRuntimeStatus_();
  } catch (e) {
    error = normalizeRuntimeErrorMessage_(e);
    errorKind = classifyRuntimeFailureKind_(e);
  }

  return buildMigration2RollbackResult_({
    enabled: true,
    rollbackTenantId: settings.rollbackTenantId,
    cutonStatus: cutonStatus,
    obsoleteHandlers: listMigration2RollbackObsoleteSettingsHandlers_(),
    error: error,
    errorKind: errorKind
  });
}

function buildMigration2RollbackResult_(data) {
  data = data || {};
  var enabled = data.enabled === true;
  var cutonStats = (data.cutonStatus && data.cutonStatus.stats) || {};
  var obsoleteHandlers = Array.isArray(data.obsoleteHandlers) ? data.obsoleteHandlers : [];
  var rollbackTenantId = String(data.rollbackTenantId || '');
  var violations = [];
  var reason = '';
  var rollbackAuthorized = false;
  var tenantCanonical = false;
  var legacyRouteActive = false;
  var cutonEnabled = !!cutonStats.enabled;
  var cutonAuthorized = !!cutonStats.cutoverAuthorized;
  var cutonReads = Math.max(0, Number(cutonStats.firestoreReads || 0));

  if (!enabled) {
    return {
      ok: true,
      stats: buildMigration2RollbackStats_({
        enabled: false,
        skipped: true,
        reason: 'rollback_disabled',
        rollbackTenantId: rollbackTenantId,
        cutonStats: cutonStats,
        legacyRouteActive: false,
        rollbackAuthorized: false,
        obsoleteHandlers: obsoleteHandlers
      }),
      items: []
    };
  }

  try {
    rollbackTenantId = normalizeMigration2RollbackTenantId_(rollbackTenantId);
    tenantCanonical = true;
  } catch (tenantError) {
    violations.push(normalizeRuntimeErrorMessage_(tenantError).indexOf('M2_ROLLBACK_TENANT_MISSING') === 0 ? 'rollback_tenant_missing' : 'rollback_tenant_not_canonical');
  }

  if (!data.cutonStatus || !data.cutonStatus.stats) violations.push('m2_cuton_status_missing');
  if (data.cutonStatus && data.cutonStatus.ok !== true) violations.push('m2_cuton_not_ok');
  if (data.cutonStatus && data.cutonStatus.stats) {
    if (String(cutonStats.cutonVersion || '') !== PHBOX_M2_ROLLBACK_REQUIRED_CUTON_VERSION_) violations.push('m2_cuton_version_not_v3');
    if (cutonStats.verifyVersion && String(cutonStats.verifyVersion || '') !== PHBOX_M2_ROLLBACK_REQUIRED_VERIFY_VERSION_) violations.push('m2_verify_version_not_v3');
    if (cutonStats.dashVersion && String(cutonStats.dashVersion || '') !== PHBOX_M2_ROLLBACK_REQUIRED_DASH_VERSION_) violations.push('m2_dash_version_not_v1');
    if (cutonStats.routeVersion && String(cutonStats.routeVersion || '') !== PHBOX_M2_ROLLBACK_REQUIRED_ROUTE_VERSION_) violations.push('m2_route_version_not_v2');
    if (cutonStats.signalVersion && String(cutonStats.signalVersion || '') !== PHBOX_M2_ROLLBACK_REQUIRED_SIGNAL_VERSION_) violations.push('m2_signal_version_not_v2');
    if (Number(cutonStats.firestoreWrites || 0) !== 0) violations.push('m2_cuton_writes_not_zero');
    if (cutonStats.publishToTarget || cutonStats.publishFromTarget) violations.push('m2_cuton_publish_detected_before_rollback');
    if (cutonStats.lifecycleTouched) violations.push('m2_cuton_lifecycle_touched_before_rollback');
    if (cutonStats.targetPathBuilt) violations.push('m2_cuton_target_path_built_before_rollback');
  }

  if (rollbackTenantId && String(cutonStats.tenantId || '').trim() && rollbackTenantId !== String(cutonStats.tenantId || '').trim()) violations.push('rollback_tenant_mismatch');
  if (rollbackTenantId && String(cutonStats.cutoverTenantId || '').trim() && rollbackTenantId !== String(cutonStats.cutoverTenantId || '').trim()) violations.push('rollback_tenant_mismatch');
  if (obsoleteHandlers.length > 0) violations.push('obsolete_settings_handlers_detected');
  if (data.error) violations.push('m2_rollback_error');

  violations = uniqueNonEmptyStrings_(violations);

  if (violations.length === 0) {
    if (!cutonEnabled) {
      reason = 'cuton_already_disabled_legacy_active';
      legacyRouteActive = true;
      rollbackAuthorized = false;
    } else if (cutonAuthorized && cutonStats.cutover) {
      reason = 'rollback_authorized_legacy_restore';
      legacyRouteActive = true;
      rollbackAuthorized = true;
    } else {
      violations.push('m2_cuton_not_authorized');
    }
  }

  violations = uniqueNonEmptyStrings_(violations);
  if (violations.length > 0) {
    reason = data.error ? 'm2_rollback_error' : 'm2_rollback_violation';
    legacyRouteActive = false;
    rollbackAuthorized = false;
  }

  return {
    ok: violations.length === 0,
    stats: buildMigration2RollbackStats_({
      enabled: true,
      skipped: !rollbackAuthorized,
      reason: reason,
      rollbackTenantId: rollbackTenantId,
      tenantCanonical: tenantCanonical,
      cutonStats: cutonStats,
      rollbackAuthorized: rollbackAuthorized,
      legacyRouteActive: legacyRouteActive,
      firestoreReads: cutonReads,
      violations: violations,
      obsoleteHandlers: obsoleteHandlers,
      error: data.error,
      errorKind: data.errorKind
    }),
    items: []
  };
}

function buildMigration2RollbackStats_(data) {
  data = data || {};
  var cutonStats = data.cutonStats || {};
  return {
    stage: PHBOX_M2_ROLLBACK_STAGE_,
    ok: data.ok === false ? false : uniqueNonEmptyStrings_(data.violations || []).length === 0,
    enabled: !!data.enabled,
    skipped: data.skipped !== false,
    reason: String(data.reason || ''),
    rollbackVersion: PHBOX_M2_ROLLBACK_VERSION_,
    cutonVersion: String(cutonStats.cutonVersion || ''),
    verifyVersion: String(cutonStats.verifyVersion || ''),
    dashVersion: String(cutonStats.dashVersion || ''),
    routeVersion: String(cutonStats.routeVersion || ''),
    signalVersion: String(cutonStats.signalVersion || ''),
    routeMode: String(cutonStats.routeMode || ''),
    routeDecision: String(cutonStats.routeDecision || ''),
    dashboardReadDecision: String(cutonStats.dashboardReadDecision || ''),
    rollbackTenantId: String(data.rollbackTenantId || ''),
    cutoverTenantId: String(cutonStats.cutoverTenantId || ''),
    tenantId: String(cutonStats.tenantId || ''),
    tenantCanonical: !!data.tenantCanonical,
    targetReadWriteAuthorized: !!cutonStats.targetReadWriteAuthorized,
    targetReadAuthorized: !!cutonStats.targetReadAuthorized,
    targetVerifyAuthorized: !!cutonStats.targetVerifyAuthorized,
    cutonEnabled: !!cutonStats.enabled,
    cutonAuthorized: !!cutonStats.cutoverAuthorized,
    sourceCutover: !!cutonStats.cutover,
    verifyLegacyPathsCompared: Math.max(0, Number(cutonStats.verifyLegacyPathsCompared || 0)),
    verifyMismatchedCount: Math.max(0, Number(cutonStats.verifyMismatchedCount || 0)),
    verifyMissingLegacyCount: Math.max(0, Number(cutonStats.verifyMissingLegacyCount || 0)),
    verifyMissingTargetCount: Math.max(0, Number(cutonStats.verifyMissingTargetCount || 0)),
    rollbackAuthorized: !!data.rollbackAuthorized,
    legacyRouteActive: !!data.legacyRouteActive,
    obsoleteHandlersCount: Array.isArray(data.obsoleteHandlers) ? data.obsoleteHandlers.length : 0,
    firestoreReads: Math.max(0, Number(data.firestoreReads || 0)),
    firestoreWrites: 0,
    publishFromTarget: false,
    publishToTarget: false,
    targetPathBuilt: false,
    cutover: false,
    lifecycleTouched: false,
    violations: uniqueNonEmptyStrings_(data.violations || []),
    obsoleteHandlers: uniqueNonEmptyStrings_(data.obsoleteHandlers || []),
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };
}

function readMigration2RollbackSettings_(props) {
  props = props || PropertiesService.getScriptProperties();
  return {
    enabled: parseMigration2RollbackBoolean_(props.getProperty(PHBOX_M2_ROLLBACK_ENABLED_PROPERTY_)),
    rollbackTenantId: String(props.getProperty(PHBOX_M2_ROLLBACK_TENANT_ID_PROPERTY_) || '')
  };
}

function parseMigration2RollbackBoolean_(value) {
  var normalized = String(value || '').trim().toLowerCase();
  return normalized === 'true' || normalized === '1' || normalized === 'yes' || normalized === 'on';
}

function normalizeMigration2RollbackTenantId_(tenantId) {
  var value = String(tenantId || '');
  if (!value.trim()) throw new Error('M2_ROLLBACK_TENANT_MISSING: PHBOX_M2_ROLLBACK_TENANT_ID mancante o vuoto. Nessun rollback autorizzato.');
  if (value !== value.trim()) throw new Error('M2_ROLLBACK_TENANT_NOT_CANONICAL: PHBOX_M2_ROLLBACK_TENANT_ID contiene spazi iniziali/finali. Nessun rollback autorizzato.');
  value = value.trim();
  if (value.indexOf('/') !== -1) throw new Error('M2_ROLLBACK_TENANT_NOT_CANONICAL: PHBOX_M2_ROLLBACK_TENANT_ID contiene slash. Nessun rollback autorizzato.');
  if (typeof normalizeMigration1CanonicalTenantSegment_ === 'function') {
    return normalizeMigration1CanonicalTenantSegment_(value, 'PHBOX_M2_ROLLBACK_TENANT_ID', {
      errorPrefix: 'M2_ROLLBACK',
      blockedOperationLabel: 'Nessun rollback autorizzato.'
    });
  }
  return value;
}

function runMigration2RollbackSelfTest_() {
  var tenant = 'farmacia_santa_venera';
  var cases = [
    {
      id: 'default_rollback_disabled_skips_without_cuton_or_reads',
      result: buildMigration2RollbackResult_({ enabled: false, rollbackTenantId: '', obsoleteHandlers: [] }),
      expected: { ok: true, skipped: true, enabled: false, rollbackAuthorized: false, legacyRouteActive: false, firestoreReads: 0, reason: 'rollback_disabled', violation: '' }
    },
    {
      id: 'enabled_missing_tenant_blocks_rollback',
      result: buildMigration2RollbackResult_({ enabled: true, rollbackTenantId: '', cutonStatus: buildMigration2RollbackSyntheticCutonStatus_({ tenantId: tenant }) }),
      expected: { ok: false, rollbackAuthorized: false, violation: 'rollback_tenant_missing' }
    },
    {
      id: 'enabled_slash_tenant_blocks_rollback',
      result: buildMigration2RollbackResult_({ enabled: true, rollbackTenantId: 'bad/tenant', cutonStatus: buildMigration2RollbackSyntheticCutonStatus_({ tenantId: tenant }) }),
      expected: { ok: false, rollbackAuthorized: false, violation: 'rollback_tenant_not_canonical' }
    },
    {
      id: 'enabled_spaced_tenant_rejected_before_match',
      result: (function () {
        var fakeProps = {
          getProperty: function (name) {
            if (name === PHBOX_M2_ROLLBACK_ENABLED_PROPERTY_) return 'true';
            if (name === PHBOX_M2_ROLLBACK_TENANT_ID_PROPERTY_) return ' ' + tenant + ' ';
            return '';
          }
        };
        var settings = readMigration2RollbackSettings_(fakeProps);
        return buildMigration2RollbackResult_({ enabled: settings.enabled, rollbackTenantId: settings.rollbackTenantId, cutonStatus: buildMigration2RollbackSyntheticCutonStatus_({ tenantId: tenant }) });
      })(),
      expected: { ok: false, rollbackAuthorized: false, violation: 'rollback_tenant_not_canonical' }
    },
    {
      id: 'enabled_mismatch_tenant_blocks_rollback',
      result: buildMigration2RollbackResult_({ enabled: true, rollbackTenantId: 'altra_farmacia', cutonStatus: buildMigration2RollbackSyntheticCutonStatus_({ tenantId: tenant }) }),
      expected: { ok: false, rollbackAuthorized: false, violation: 'rollback_tenant_mismatch' }
    },
    {
      id: 'cuton_status_missing_blocks_rollback',
      result: buildMigration2RollbackResult_({ enabled: true, rollbackTenantId: tenant, cutonStatus: null }),
      expected: { ok: false, rollbackAuthorized: false, violation: 'm2_cuton_status_missing' }
    },
    {
      id: 'cuton_status_without_explicit_ok_blocks_rollback',
      result: (function () {
        var status = buildMigration2RollbackSyntheticCutonStatus_({ tenantId: tenant, firestoreReads: 4 });
        delete status.ok;
        return buildMigration2RollbackResult_({ enabled: true, rollbackTenantId: tenant, cutonStatus: status });
      })(),
      expected: { ok: false, rollbackAuthorized: false, violation: 'm2_cuton_not_ok' }
    },
    {
      id: 'cuton_disabled_already_legacy_passes',
      result: buildMigration2RollbackResult_({ enabled: true, rollbackTenantId: tenant, cutonStatus: buildMigration2RollbackSyntheticCutonStatus_({ enabled: false, tenantId: tenant, cutoverAuthorized: false, cutover: false }) }),
      expected: { ok: true, skipped: true, rollbackAuthorized: false, legacyRouteActive: true, cutover: false, reason: 'cuton_already_disabled_legacy_active' }
    },
    {
      id: 'cuton_not_ok_blocks_rollback',
      result: buildMigration2RollbackResult_({ enabled: true, rollbackTenantId: tenant, cutonStatus: buildMigration2RollbackSyntheticCutonStatus_({ ok: false, tenantId: tenant, cutoverAuthorized: false, cutover: false, violations: ['m2_verify_not_ok'] }) }),
      expected: { ok: false, rollbackAuthorized: false, violation: 'm2_cuton_not_ok' }
    },
    {
      id: 'cuton_not_authorized_blocks_rollback',
      result: buildMigration2RollbackResult_({ enabled: true, rollbackTenantId: tenant, cutonStatus: buildMigration2RollbackSyntheticCutonStatus_({ tenantId: tenant, cutoverAuthorized: false, cutover: false }) }),
      expected: { ok: false, rollbackAuthorized: false, violation: 'm2_cuton_not_authorized' }
    },
    {
      id: 'cuton_publish_lifecycle_blocks_rollback',
      result: buildMigration2RollbackResult_({ enabled: true, rollbackTenantId: tenant, cutonStatus: buildMigration2RollbackSyntheticCutonStatus_({ tenantId: tenant, publishToTarget: true, lifecycleTouched: true }) }),
      expected: { ok: false, rollbackAuthorized: false, violation: 'm2_cuton_publish_detected_before_rollback' }
    },
    {
      id: 'enabled_authorized_cuton_same_tenant_authorizes_rollback',
      result: buildMigration2RollbackResult_({ enabled: true, rollbackTenantId: tenant, cutonStatus: buildMigration2RollbackSyntheticCutonStatus_({ tenantId: tenant, firestoreReads: 4 }) }),
      expected: { ok: true, skipped: false, rollbackAuthorized: true, legacyRouteActive: true, cutover: false, sourceCutover: true, firestoreReads: 4, reason: 'rollback_authorized_legacy_restore' }
    },
    {
      id: 'rollback_runtime_zero_read_write_contract',
      result: buildMigration2RollbackResult_({ enabled: false, rollbackTenantId: '', obsoleteHandlers: [] }),
      expected: { ok: true, skipped: true, firestoreReads: 0, firestoreWrites: 0, cutover: false, violation: '' }
    }
  ];

  var passed = 0;
  var failed = 0;
  var items = cases.map(function (item) {
    var stats = (item.result && item.result.stats) || {};
    var mismatchReasons = compareMigration2RollbackExpected_(stats, item.expected || {});
    var ok = mismatchReasons.length === 0;
    if (ok) passed++; else failed++;
    return {
      id: item.id,
      passed: ok,
      ok: !!stats.ok,
      enabled: !!stats.enabled,
      skipped: !!stats.skipped,
      reason: stats.reason || '',
      rollbackTenantId: stats.rollbackTenantId || '',
      cutoverTenantId: stats.cutoverTenantId || '',
      tenantId: stats.tenantId || '',
      cutonEnabled: !!stats.cutonEnabled,
      cutonAuthorized: !!stats.cutonAuthorized,
      sourceCutover: !!stats.sourceCutover,
      rollbackAuthorized: !!stats.rollbackAuthorized,
      legacyRouteActive: !!stats.legacyRouteActive,
      firestoreReads: stats.firestoreReads || 0,
      firestoreWrites: stats.firestoreWrites || 0,
      publishFromTarget: !!stats.publishFromTarget,
      publishToTarget: !!stats.publishToTarget,
      targetPathBuilt: !!stats.targetPathBuilt,
      cutover: !!stats.cutover,
      lifecycleTouched: !!stats.lifecycleTouched,
      violations: stats.violations || [],
      mismatchReasons: mismatchReasons
    };
  });

  return {
    ok: failed === 0,
    testCount: items.length,
    passedCount: passed,
    failedCount: failed,
    rollbackVersion: PHBOX_M2_ROLLBACK_VERSION_,
    cutonVersion: PHBOX_M2_ROLLBACK_REQUIRED_CUTON_VERSION_,
    verifyVersion: PHBOX_M2_ROLLBACK_REQUIRED_VERIFY_VERSION_,
    dashVersion: PHBOX_M2_ROLLBACK_REQUIRED_DASH_VERSION_,
    routeVersion: PHBOX_M2_ROLLBACK_REQUIRED_ROUTE_VERSION_,
    signalVersion: PHBOX_M2_ROLLBACK_REQUIRED_SIGNAL_VERSION_,
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

function buildMigration2RollbackSyntheticCutonStatus_(overrides) {
  overrides = overrides || {};
  var tenant = Object.prototype.hasOwnProperty.call(overrides, 'tenantId') ? overrides.tenantId : 'farmacia_santa_venera';
  var cutoverAuthorized = Object.prototype.hasOwnProperty.call(overrides, 'cutoverAuthorized') ? !!overrides.cutoverAuthorized : true;
  var enabled = Object.prototype.hasOwnProperty.call(overrides, 'enabled') ? !!overrides.enabled : true;
  var cutover = Object.prototype.hasOwnProperty.call(overrides, 'cutover') ? !!overrides.cutover : cutoverAuthorized;
  var stats = {
    stage: 'migration2_cuton_single_tenant',
    ok: Object.prototype.hasOwnProperty.call(overrides, 'ok') ? !!overrides.ok : true,
    enabled: enabled,
    skipped: !cutoverAuthorized,
    reason: cutoverAuthorized ? 'cuton_authorized_single_tenant' : 'm2_cuton_violation',
    cutonVersion: PHBOX_M2_ROLLBACK_REQUIRED_CUTON_VERSION_,
    verifyVersion: PHBOX_M2_ROLLBACK_REQUIRED_VERIFY_VERSION_,
    dashVersion: PHBOX_M2_ROLLBACK_REQUIRED_DASH_VERSION_,
    routeVersion: PHBOX_M2_ROLLBACK_REQUIRED_ROUTE_VERSION_,
    signalVersion: PHBOX_M2_ROLLBACK_REQUIRED_SIGNAL_VERSION_,
    routeMode: 'target',
    routeDecision: 'target',
    dashboardReadDecision: 'target',
    cutoverTenantId: tenant,
    tenantId: tenant,
    tenantCanonical: true,
    targetReadWriteAuthorized: true,
    targetReadAuthorized: true,
    targetVerifyAuthorized: true,
    verifyOk: true,
    verifyLegacyPathsCompared: 2,
    verifyMismatchedCount: 0,
    verifyMissingLegacyCount: 0,
    verifyMissingTargetCount: 0,
    cutoverAuthorized: cutoverAuthorized,
    obsoleteHandlersCount: 0,
    firestoreReads: Math.max(0, Number(overrides.firestoreReads || 0)),
    firestoreWrites: Math.max(0, Number(overrides.firestoreWrites || 0)),
    publishFromTarget: !!overrides.publishFromTarget,
    publishToTarget: !!overrides.publishToTarget,
    targetPathBuilt: !!overrides.targetPathBuilt,
    cutover: cutover,
    lifecycleTouched: !!overrides.lifecycleTouched,
    violations: uniqueNonEmptyStrings_(overrides.violations || []),
    obsoleteHandlers: [],
    error: String(overrides.error || ''),
    errorKind: String(overrides.errorKind || '')
  };
  return { ok: !!stats.ok, stats: stats, items: [] };
}

function compareMigration2RollbackExpected_(stats, expected) {
  var mismatchReasons = [];
  expected = expected || {};
  if (Object.prototype.hasOwnProperty.call(expected, 'ok') && !!stats.ok !== !!expected.ok) mismatchReasons.push('expected_ok_mismatch');
  if (Object.prototype.hasOwnProperty.call(expected, 'enabled') && !!stats.enabled !== !!expected.enabled) mismatchReasons.push('expected_enabled_mismatch');
  if (Object.prototype.hasOwnProperty.call(expected, 'skipped') && !!stats.skipped !== !!expected.skipped) mismatchReasons.push('expected_skipped_mismatch');
  if (Object.prototype.hasOwnProperty.call(expected, 'reason') && String(stats.reason || '') !== String(expected.reason || '')) mismatchReasons.push('expected_reason_mismatch');
  if (Object.prototype.hasOwnProperty.call(expected, 'rollbackAuthorized') && !!stats.rollbackAuthorized !== !!expected.rollbackAuthorized) mismatchReasons.push('expected_rollback_authorized_mismatch');
  if (Object.prototype.hasOwnProperty.call(expected, 'legacyRouteActive') && !!stats.legacyRouteActive !== !!expected.legacyRouteActive) mismatchReasons.push('expected_legacy_route_active_mismatch');
  if (Object.prototype.hasOwnProperty.call(expected, 'sourceCutover') && !!stats.sourceCutover !== !!expected.sourceCutover) mismatchReasons.push('expected_source_cutover_mismatch');
  if (Object.prototype.hasOwnProperty.call(expected, 'cutover') && !!stats.cutover !== !!expected.cutover) mismatchReasons.push('expected_cutover_mismatch');
  if (Object.prototype.hasOwnProperty.call(expected, 'firestoreReads') && Number(stats.firestoreReads || 0) !== Number(expected.firestoreReads || 0)) mismatchReasons.push('expected_reads_mismatch');
  if (Object.prototype.hasOwnProperty.call(expected, 'firestoreWrites') && Number(stats.firestoreWrites || 0) !== Number(expected.firestoreWrites || 0)) mismatchReasons.push('expected_writes_mismatch');
  var violations = stats.violations || [];
  if (expected.violation && violations.indexOf(expected.violation) === -1) mismatchReasons.push('expected_violation_missing_' + expected.violation);
  if (Object.prototype.hasOwnProperty.call(expected, 'violation') && !expected.violation && violations.length > 0) mismatchReasons.push('unexpected_violations');
  return uniqueNonEmptyStrings_(mismatchReasons);
}

function listMigration2RollbackObsoleteSettingsHandlers_() {
  var names = [
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
    'runMigration1DashboardCompatibilitySettingsTest',
    'getMigration1DashboardCompatibilitySettingsStatus',
    'runMigration1RuntimeSignalSettingsTest',
    'getMigration1RuntimeSignalSettingsStatus',
    'runMigration1TargetPublishSettingsTest',
    'getMigration1TargetPublishSettingsStatus',
    'runMigration1TargetRuntimeGateSettingsTest',
    'getMigration1TargetRuntimeGateSettingsStatus',
    'runMigration1BackendIdentityResolverSettingsTest',
    'getMigration1BackendIdentityResolverSettingsStatus',
    'runMigration1ShadowSettingsTest',
    'getMigration1ShadowSettingsStatus'
  ];
  return names.filter(function (name) { return typeof this[name] === 'function'; }, this);
}

function formatMigration2RollbackSelfTestFeedback_(result) {
  result = result || {};
  var lines = [];
  lines.push('MIGRATION_2_ROLLBACK_TEST');
  lines.push('ok=' + String(!!result.ok));
  lines.push('testCount=' + String(result.testCount || 0));
  lines.push('passedCount=' + String(result.passedCount || 0));
  lines.push('failedCount=' + String(result.failedCount || 0));
  lines.push('rollbackVersion=' + String(result.rollbackVersion || ''));
  lines.push('cutonVersion=' + String(result.cutonVersion || ''));
  lines.push('verifyVersion=' + String(result.verifyVersion || ''));
  lines.push('dashVersion=' + String(result.dashVersion || ''));
  lines.push('routeVersion=' + String(result.routeVersion || ''));
  lines.push('signalVersion=' + String(result.signalVersion || ''));
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
    lines.push('  ok=' + String(!!item.ok));
    lines.push('  enabled=' + String(!!item.enabled));
    lines.push('  skipped=' + String(!!item.skipped));
    lines.push('  reason=' + String(item.reason || ''));
    lines.push('  rollbackTenantId=' + String(item.rollbackTenantId || ''));
    lines.push('  cutoverTenantId=' + String(item.cutoverTenantId || ''));
    lines.push('  tenantId=' + String(item.tenantId || ''));
    lines.push('  cutonEnabled=' + String(!!item.cutonEnabled));
    lines.push('  cutonAuthorized=' + String(!!item.cutonAuthorized));
    lines.push('  sourceCutover=' + String(!!item.sourceCutover));
    lines.push('  rollbackAuthorized=' + String(!!item.rollbackAuthorized));
    lines.push('  legacyRouteActive=' + String(!!item.legacyRouteActive));
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

function formatMigration2RollbackRuntimeFeedback_(result) {
  var stats = (result && result.stats) || {};
  var lines = [];
  lines.push('MIGRATION_2_ROLLBACK_RUNTIME_STATUS');
  lines.push('ok=' + String(!!(result && result.ok)));
  lines.push('enabled=' + String(!!stats.enabled));
  lines.push('skipped=' + String(!!stats.skipped));
  lines.push('reason=' + String(stats.reason || ''));
  lines.push('rollbackVersion=' + String(stats.rollbackVersion || ''));
  lines.push('cutonVersion=' + String(stats.cutonVersion || ''));
  lines.push('verifyVersion=' + String(stats.verifyVersion || ''));
  lines.push('dashVersion=' + String(stats.dashVersion || ''));
  lines.push('routeVersion=' + String(stats.routeVersion || ''));
  lines.push('signalVersion=' + String(stats.signalVersion || ''));
  lines.push('routeMode=' + String(stats.routeMode || ''));
  lines.push('routeDecision=' + String(stats.routeDecision || ''));
  lines.push('dashboardReadDecision=' + String(stats.dashboardReadDecision || ''));
  lines.push('rollbackTenantId=' + String(stats.rollbackTenantId || ''));
  lines.push('cutoverTenantId=' + String(stats.cutoverTenantId || ''));
  lines.push('tenantId=' + String(stats.tenantId || ''));
  lines.push('tenantCanonical=' + String(!!stats.tenantCanonical));
  lines.push('targetReadWriteAuthorized=' + String(!!stats.targetReadWriteAuthorized));
  lines.push('targetReadAuthorized=' + String(!!stats.targetReadAuthorized));
  lines.push('targetVerifyAuthorized=' + String(!!stats.targetVerifyAuthorized));
  lines.push('cutonEnabled=' + String(!!stats.cutonEnabled));
  lines.push('cutonAuthorized=' + String(!!stats.cutonAuthorized));
  lines.push('sourceCutover=' + String(!!stats.sourceCutover));
  lines.push('rollbackAuthorized=' + String(!!stats.rollbackAuthorized));
  lines.push('legacyRouteActive=' + String(!!stats.legacyRouteActive));
  lines.push('verifyLegacyPathsCompared=' + String(stats.verifyLegacyPathsCompared || 0));
  lines.push('verifyMismatchedCount=' + String(stats.verifyMismatchedCount || 0));
  lines.push('verifyMissingLegacyCount=' + String(stats.verifyMissingLegacyCount || 0));
  lines.push('verifyMissingTargetCount=' + String(stats.verifyMissingTargetCount || 0));
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
