var PHBOX_M2_CUTON_VERSION_ = 'M2_CUTON_v3';
var PHBOX_M2_CUTON_STAGE_ = 'migration2_cuton_single_tenant';
var PHBOX_M2_CUTON_ENABLED_PROPERTY_ = 'PHBOX_M2_CUTON_ENABLED';
var PHBOX_M2_CUTON_TENANT_ID_PROPERTY_ = 'PHBOX_M2_CUTON_TENANT_ID';
var PHBOX_M2_CUTON_REQUIRED_VERIFY_VERSION_ = 'M2_VERIFY_v3';
var PHBOX_M2_CUTON_REQUIRED_DASH_VERSION_ = 'M2_DASH_v1';
var PHBOX_M2_CUTON_REQUIRED_ROUTE_VERSION_ = 'M2_ROUTE_v2';
var PHBOX_M2_CUTON_REQUIRED_SIGNAL_VERSION_ = 'M2_SIGNAL_v2';

function runMigration2CutonRuntimeStatus_() {
  var settings = readMigration2CutonSettings_();
  if (!settings.enabled) {
    return buildMigration2CutonResult_({
      enabled: false,
      cutoverTenantId: settings.cutoverTenantId,
      obsoleteHandlers: listMigration2CutonObsoleteSettingsHandlers_()
    });
  }

  var verifyStatus = null;
  var error = '';
  var errorKind = '';
  try {
    if (typeof runMigration2PostWriteVerifyRuntimeStatus_ !== 'function') {
      throw new Error('M2_CUTON_VERIFY_MISSING: funzione runMigration2PostWriteVerifyRuntimeStatus_ non disponibile. Cutover M2 non autorizzabile.');
    }
    verifyStatus = runMigration2PostWriteVerifyRuntimeStatus_();
  } catch (e) {
    error = normalizeRuntimeErrorMessage_(e);
    errorKind = classifyRuntimeFailureKind_(e);
  }

  return buildMigration2CutonResult_({
    enabled: true,
    cutoverTenantId: settings.cutoverTenantId,
    verifyStatus: verifyStatus,
    obsoleteHandlers: listMigration2CutonObsoleteSettingsHandlers_(),
    error: error,
    errorKind: errorKind
  });
}

function buildMigration2CutonResult_(data) {
  data = data || {};
  var enabled = data.enabled === true;
  var verifyStats = (data.verifyStatus && data.verifyStatus.stats) || {};
  var obsoleteHandlers = Array.isArray(data.obsoleteHandlers) ? data.obsoleteHandlers : [];
  var cutoverTenantId = String(data.cutoverTenantId || '');
  var violations = [];
  var reason = '';
  var cutoverAuthorized = false;
  var tenantCanonical = false;
  var verifyOk = !!(data.verifyStatus && data.verifyStatus.ok);
  var verifyTargetAuthorized = !!verifyStats.targetVerifyAuthorized;
  var verifyReads = Math.max(0, Number(verifyStats.firestoreReads || 0));

  if (!enabled) {
    return {
      ok: true,
      stats: buildMigration2CutonStats_({
        enabled: false,
        skipped: true,
        reason: 'cuton_disabled',
        cutoverTenantId: cutoverTenantId,
        verifyStats: verifyStats,
        verifyOk: false,
        verifyTargetAuthorized: false,
        obsoleteHandlers: obsoleteHandlers
      }),
      items: []
    };
  }

  try {
    cutoverTenantId = normalizeMigration2CutonTenantId_(cutoverTenantId);
    tenantCanonical = true;
  } catch (tenantError) {
    violations.push(normalizeRuntimeErrorMessage_(tenantError).indexOf('M2_CUTON_TENANT_MISSING') === 0 ? 'cuton_tenant_missing' : 'cuton_tenant_not_canonical');
  }

  if (!data.verifyStatus || !data.verifyStatus.stats) violations.push('m2_verify_status_missing');
  if (data.verifyStatus && data.verifyStatus.ok === false) violations.push('m2_verify_not_ok');
  if (String(verifyStats.verifyVersion || '') !== PHBOX_M2_CUTON_REQUIRED_VERIFY_VERSION_) violations.push('m2_verify_version_not_v3');
  if (String(verifyStats.dashVersion || '') !== PHBOX_M2_CUTON_REQUIRED_DASH_VERSION_) violations.push('m2_dash_version_not_v1');
  if (String(verifyStats.routeVersion || '') !== PHBOX_M2_CUTON_REQUIRED_ROUTE_VERSION_) violations.push('m2_route_version_not_v2');
  if (String(verifyStats.signalVersion || '') !== PHBOX_M2_CUTON_REQUIRED_SIGNAL_VERSION_) violations.push('m2_signal_version_not_v2');
  if (!verifyTargetAuthorized) violations.push('m2_verify_target_not_authorized');
  if (String(verifyStats.routeDecision || '').trim().toLowerCase() !== 'target') violations.push('m2_route_not_target');
  if (String(verifyStats.dashboardReadDecision || '').trim().toLowerCase() !== 'target') violations.push('m2_dashboard_read_not_target');
  if (!verifyStats.targetReadAuthorized) violations.push('m2_target_read_not_authorized');
  if (!verifyStats.tenantCanonical || !verifyStats.targetReadWriteAuthorized || !String(verifyStats.tenantId || '').trim()) violations.push('m2_verify_tenant_not_authorized');
  if (cutoverTenantId && String(verifyStats.tenantId || '').trim() && cutoverTenantId !== String(verifyStats.tenantId || '').trim()) violations.push('cuton_tenant_mismatch');
  if (Math.max(0, Number(verifyStats.legacyPathsCompared || 0)) <= 0) violations.push('m2_verify_no_compared_paths');
  if (Math.max(0, Number(verifyStats.mismatchedCount || 0)) > 0) violations.push('m2_verify_mismatches_present');
  if (Math.max(0, Number(verifyStats.missingLegacyCount || 0)) > 0) violations.push('m2_verify_missing_legacy_present');
  if (Math.max(0, Number(verifyStats.missingTargetCount || 0)) > 0) violations.push('m2_verify_missing_target_present');
  if (Number(verifyStats.firestoreWrites || 0) !== 0) violations.push('m2_verify_writes_not_zero');
  if (verifyStats.publishToTarget || verifyStats.publishFromTarget) violations.push('m2_verify_publish_detected_before_cuton');
  if (verifyStats.cutover) violations.push('m2_verify_cutover_detected_before_cuton');
  if (verifyStats.lifecycleTouched) violations.push('m2_verify_lifecycle_touched_before_cuton');
  if (obsoleteHandlers.length > 0) violations.push('obsolete_settings_handlers_detected');
  if (data.error) violations.push('m2_cuton_error');

  violations = uniqueNonEmptyStrings_(violations);
  if (violations.length === 0) {
    cutoverAuthorized = true;
    reason = 'cuton_authorized_single_tenant';
  } else {
    reason = data.error ? 'm2_cuton_error' : 'm2_cuton_violation';
  }

  return {
    ok: violations.length === 0,
    stats: buildMigration2CutonStats_({
      enabled: true,
      skipped: !cutoverAuthorized,
      reason: reason,
      cutoverTenantId: cutoverTenantId,
      tenantCanonical: tenantCanonical,
      verifyStats: verifyStats,
      verifyOk: verifyOk,
      verifyTargetAuthorized: verifyTargetAuthorized,
      cutoverAuthorized: cutoverAuthorized,
      firestoreReads: verifyReads,
      violations: violations,
      obsoleteHandlers: obsoleteHandlers,
      error: data.error,
      errorKind: data.errorKind
    }),
    items: []
  };
}

function buildMigration2CutonStats_(data) {
  data = data || {};
  var verifyStats = data.verifyStats || {};
  return {
    stage: PHBOX_M2_CUTON_STAGE_,
    ok: data.ok === false ? false : uniqueNonEmptyStrings_(data.violations || []).length === 0,
    enabled: !!data.enabled,
    skipped: data.skipped !== false,
    reason: String(data.reason || ''),
    cutonVersion: PHBOX_M2_CUTON_VERSION_,
    verifyVersion: String(verifyStats.verifyVersion || ''),
    dashVersion: String(verifyStats.dashVersion || ''),
    routeVersion: String(verifyStats.routeVersion || ''),
    signalVersion: String(verifyStats.signalVersion || ''),
    routeMode: String(verifyStats.routeMode || ''),
    routeDecision: String(verifyStats.routeDecision || ''),
    dashboardReadDecision: String(verifyStats.dashboardReadDecision || ''),
    cutoverTenantId: String(data.cutoverTenantId || ''),
    tenantId: String(verifyStats.tenantId || ''),
    tenantCanonical: !!(data.tenantCanonical && verifyStats.tenantCanonical),
    targetReadWriteAuthorized: !!verifyStats.targetReadWriteAuthorized,
    targetReadAuthorized: !!verifyStats.targetReadAuthorized,
    targetVerifyAuthorized: !!data.verifyTargetAuthorized,
    verifyOk: !!data.verifyOk,
    verifyLegacyPathsCompared: Math.max(0, Number(verifyStats.legacyPathsCompared || 0)),
    verifyMismatchedCount: Math.max(0, Number(verifyStats.mismatchedCount || 0)),
    verifyMissingLegacyCount: Math.max(0, Number(verifyStats.missingLegacyCount || 0)),
    verifyMissingTargetCount: Math.max(0, Number(verifyStats.missingTargetCount || 0)),
    cutoverAuthorized: !!data.cutoverAuthorized,
    obsoleteHandlersCount: Array.isArray(data.obsoleteHandlers) ? data.obsoleteHandlers.length : 0,
    firestoreReads: Math.max(0, Number(data.firestoreReads || 0)),
    firestoreWrites: 0,
    publishFromTarget: false,
    publishToTarget: false,
    targetPathBuilt: false,
    cutover: !!data.cutoverAuthorized,
    lifecycleTouched: false,
    violations: uniqueNonEmptyStrings_(data.violations || []),
    obsoleteHandlers: uniqueNonEmptyStrings_(data.obsoleteHandlers || []),
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };
}

function readMigration2CutonSettings_(props) {
  props = props || PropertiesService.getScriptProperties();
  return {
    enabled: parseMigration2CutonBoolean_(props.getProperty(PHBOX_M2_CUTON_ENABLED_PROPERTY_)),
    cutoverTenantId: String(props.getProperty(PHBOX_M2_CUTON_TENANT_ID_PROPERTY_) || '')
  };
}

function parseMigration2CutonBoolean_(value) {
  var normalized = String(value || '').trim().toLowerCase();
  return normalized === 'true' || normalized === '1' || normalized === 'yes' || normalized === 'on';
}

function normalizeMigration2CutonTenantId_(tenantId) {
  var value = String(tenantId || '');
  if (!value.trim()) throw new Error('M2_CUTON_TENANT_MISSING: PHBOX_M2_CUTON_TENANT_ID mancante o vuoto. Nessun cutover autorizzato.');
  if (value !== value.trim()) throw new Error('M2_CUTON_TENANT_NOT_CANONICAL: PHBOX_M2_CUTON_TENANT_ID contiene spazi iniziali/finali. Nessun cutover autorizzato.');
  value = value.trim();
  if (value.indexOf('/') !== -1) throw new Error('M2_CUTON_TENANT_NOT_CANONICAL: PHBOX_M2_CUTON_TENANT_ID contiene slash. Nessun cutover autorizzato.');
  if (typeof normalizeMigration1CanonicalTenantSegment_ === 'function') {
    return normalizeMigration1CanonicalTenantSegment_(value, 'PHBOX_M2_CUTON_TENANT_ID', {
      errorPrefix: 'M2_CUTON',
      blockedOperationLabel: 'Nessun cutover autorizzato.'
    });
  }
  return value;
}

function runMigration2CutonSelfTest_() {
  var tenant = 'farmacia_santa_venera';
  var cases = [
    {
      id: 'default_cuton_disabled_skips_without_verify_or_reads',
      result: buildMigration2CutonResult_({ enabled: false, cutoverTenantId: '', obsoleteHandlers: [] }),
      expected: { ok: true, skipped: true, enabled: false, cutover: false, firestoreReads: 0, reason: 'cuton_disabled', violation: '' }
    },
    {
      id: 'enabled_missing_tenant_blocks_cuton',
      result: buildMigration2CutonResult_({ enabled: true, cutoverTenantId: '', verifyStatus: buildMigration2CutonSyntheticVerifyStatus_({ tenantId: tenant }) }),
      expected: { ok: false, cutover: false, violation: 'cuton_tenant_missing' }
    },
    {
      id: 'enabled_mismatch_tenant_blocks_cuton',
      result: buildMigration2CutonResult_({ enabled: true, cutoverTenantId: 'altra_farmacia', verifyStatus: buildMigration2CutonSyntheticVerifyStatus_({ tenantId: tenant }) }),
      expected: { ok: false, cutover: false, violation: 'cuton_tenant_mismatch' }
    },
    {
      id: 'enabled_slash_tenant_blocks_cuton',
      result: buildMigration2CutonResult_({ enabled: true, cutoverTenantId: 'bad/tenant', verifyStatus: buildMigration2CutonSyntheticVerifyStatus_({ tenantId: tenant }) }),
      expected: { ok: false, cutover: false, violation: 'cuton_tenant_not_canonical' }
    },
    {
      id: 'enabled_spaced_tenant_property_rejected_before_match',
      result: (function () {
        var fakeProps = {
          getProperty: function (name) {
            if (name === PHBOX_M2_CUTON_ENABLED_PROPERTY_) return 'true';
            if (name === PHBOX_M2_CUTON_TENANT_ID_PROPERTY_) return ' ' + tenant + ' ';
            return '';
          }
        };
        var settings = readMigration2CutonSettings_(fakeProps);
        return buildMigration2CutonResult_({ enabled: settings.enabled, cutoverTenantId: settings.cutoverTenantId, verifyStatus: buildMigration2CutonSyntheticVerifyStatus_({ tenantId: tenant }) });
      })(),
      expected: { ok: false, cutover: false, violation: 'cuton_tenant_not_canonical' }
    },
    {
      id: 'verify_status_missing_blocks_cuton',
      result: buildMigration2CutonResult_({ enabled: true, cutoverTenantId: tenant, verifyStatus: null }),
      expected: { ok: false, cutover: false, violation: 'm2_verify_status_missing' }
    },
    {
      id: 'verify_not_ok_blocks_cuton',
      result: buildMigration2CutonResult_({ enabled: true, cutoverTenantId: tenant, verifyStatus: buildMigration2CutonSyntheticVerifyStatus_({ ok: false, tenantId: tenant, mismatchedCount: 1 }) }),
      expected: { ok: false, cutover: false, violation: 'm2_verify_not_ok' }
    },
    {
      id: 'verify_not_target_authorized_blocks_cuton',
      result: buildMigration2CutonResult_({ enabled: true, cutoverTenantId: tenant, verifyStatus: buildMigration2CutonSyntheticVerifyStatus_({ tenantId: tenant, targetVerifyAuthorized: false, routeDecision: 'legacy', dashboardReadDecision: 'legacy' }) }),
      expected: { ok: false, cutover: false, violation: 'm2_verify_target_not_authorized' }
    },
    {
      id: 'verify_no_compared_paths_blocks_cuton',
      result: buildMigration2CutonResult_({ enabled: true, cutoverTenantId: tenant, verifyStatus: buildMigration2CutonSyntheticVerifyStatus_({ tenantId: tenant, legacyPathsCompared: 0 }) }),
      expected: { ok: false, cutover: false, violation: 'm2_verify_no_compared_paths' }
    },
    {
      id: 'verify_mismatch_blocks_cuton',
      result: buildMigration2CutonResult_({ enabled: true, cutoverTenantId: tenant, verifyStatus: buildMigration2CutonSyntheticVerifyStatus_({ tenantId: tenant, mismatchedCount: 1 }) }),
      expected: { ok: false, cutover: false, violation: 'm2_verify_mismatches_present' }
    },
    {
      id: 'verify_publish_cutover_lifecycle_blocks_cuton',
      result: buildMigration2CutonResult_({ enabled: true, cutoverTenantId: tenant, verifyStatus: buildMigration2CutonSyntheticVerifyStatus_({ tenantId: tenant, publishToTarget: true, cutover: true, lifecycleTouched: true }) }),
      expected: { ok: false, cutover: false, violation: 'm2_verify_publish_detected_before_cuton' }
    },
    {
      id: 'enabled_verified_single_tenant_authorizes_cuton',
      result: buildMigration2CutonResult_({ enabled: true, cutoverTenantId: tenant, verifyStatus: buildMigration2CutonSyntheticVerifyStatus_({ tenantId: tenant, legacyPathsCompared: 2, firestoreReads: 4 }) }),
      expected: { ok: true, skipped: false, enabled: true, cutover: true, firestoreReads: 4, reason: 'cuton_authorized_single_tenant', violation: '' }
    }
  ];

  var passed = 0;
  var failed = 0;
  var items = cases.map(function (item) {
    var stats = (item.result && item.result.stats) || {};
    var mismatchReasons = compareMigration2CutonExpected_(stats, item.expected || {});
    var ok = mismatchReasons.length === 0;
    if (ok) passed++; else failed++;
    return {
      id: item.id,
      passed: ok,
      ok: !!stats.ok,
      enabled: !!stats.enabled,
      skipped: !!stats.skipped,
      reason: stats.reason || '',
      cutoverTenantId: stats.cutoverTenantId || '',
      tenantId: stats.tenantId || '',
      targetVerifyAuthorized: !!stats.targetVerifyAuthorized,
      verifyLegacyPathsCompared: stats.verifyLegacyPathsCompared || 0,
      verifyMismatchedCount: stats.verifyMismatchedCount || 0,
      cutoverAuthorized: !!stats.cutoverAuthorized,
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
    cutonVersion: PHBOX_M2_CUTON_VERSION_,
    verifyVersion: PHBOX_M2_CUTON_REQUIRED_VERIFY_VERSION_,
    dashVersion: PHBOX_M2_CUTON_REQUIRED_DASH_VERSION_,
    routeVersion: PHBOX_M2_CUTON_REQUIRED_ROUTE_VERSION_,
    signalVersion: PHBOX_M2_CUTON_REQUIRED_SIGNAL_VERSION_,
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

function buildMigration2CutonSyntheticVerifyStatus_(overrides) {
  overrides = overrides || {};
  var stats = {
    ok: overrides.ok === false ? false : true,
    skipped: false,
    reason: overrides.reason || 'post_write_verify_matched',
    verifyVersion: overrides.verifyVersion || PHBOX_M2_CUTON_REQUIRED_VERIFY_VERSION_,
    dashVersion: overrides.dashVersion || PHBOX_M2_CUTON_REQUIRED_DASH_VERSION_,
    routeVersion: overrides.routeVersion || PHBOX_M2_CUTON_REQUIRED_ROUTE_VERSION_,
    signalVersion: overrides.signalVersion || PHBOX_M2_CUTON_REQUIRED_SIGNAL_VERSION_,
    routeMode: overrides.routeMode || 'target',
    routeDecision: overrides.routeDecision || 'target',
    dashboardReadDecision: overrides.dashboardReadDecision || 'target',
    targetVerifyAuthorized: Object.prototype.hasOwnProperty.call(overrides, 'targetVerifyAuthorized') ? !!overrides.targetVerifyAuthorized : true,
    targetReadAuthorized: Object.prototype.hasOwnProperty.call(overrides, 'targetReadAuthorized') ? !!overrides.targetReadAuthorized : true,
    tenantId: String(overrides.tenantId || 'farmacia_santa_venera'),
    tenantCanonical: Object.prototype.hasOwnProperty.call(overrides, 'tenantCanonical') ? !!overrides.tenantCanonical : true,
    targetReadWriteAuthorized: Object.prototype.hasOwnProperty.call(overrides, 'targetReadWriteAuthorized') ? !!overrides.targetReadWriteAuthorized : true,
    legacyPathsCompared: Math.max(0, Number(Object.prototype.hasOwnProperty.call(overrides, 'legacyPathsCompared') ? overrides.legacyPathsCompared : 2)),
    mismatchedCount: Math.max(0, Number(overrides.mismatchedCount || 0)),
    missingLegacyCount: Math.max(0, Number(overrides.missingLegacyCount || 0)),
    missingTargetCount: Math.max(0, Number(overrides.missingTargetCount || 0)),
    firestoreReads: Math.max(0, Number(overrides.firestoreReads || 0)),
    firestoreWrites: Math.max(0, Number(overrides.firestoreWrites || 0)),
    publishFromTarget: !!overrides.publishFromTarget,
    publishToTarget: !!overrides.publishToTarget,
    targetPathBuilt: !!overrides.targetPathBuilt,
    cutover: !!overrides.cutover,
    lifecycleTouched: !!overrides.lifecycleTouched,
    violations: overrides.violations || []
  };
  return { ok: !!stats.ok, stats: stats, items: [] };
}

function compareMigration2CutonExpected_(stats, expected) {
  var mismatchReasons = [];
  if (Object.prototype.hasOwnProperty.call(expected, 'ok') && !!stats.ok !== !!expected.ok) mismatchReasons.push('expected_ok_mismatch');
  if (Object.prototype.hasOwnProperty.call(expected, 'enabled') && !!stats.enabled !== !!expected.enabled) mismatchReasons.push('expected_enabled_mismatch');
  if (Object.prototype.hasOwnProperty.call(expected, 'skipped') && !!stats.skipped !== !!expected.skipped) mismatchReasons.push('expected_skipped_mismatch');
  if (Object.prototype.hasOwnProperty.call(expected, 'cutover') && !!stats.cutover !== !!expected.cutover) mismatchReasons.push('expected_cutover_mismatch');
  if (Object.prototype.hasOwnProperty.call(expected, 'firestoreReads') && Number(stats.firestoreReads || 0) !== Number(expected.firestoreReads || 0)) mismatchReasons.push('expected_reads_mismatch');
  if (Object.prototype.hasOwnProperty.call(expected, 'reason') && String(stats.reason || '') !== String(expected.reason || '')) mismatchReasons.push('expected_reason_mismatch');
  if (expected.violation && (stats.violations || []).indexOf(expected.violation) === -1) mismatchReasons.push('expected_violation_missing_' + expected.violation);
  if (!expected.violation && (stats.violations || []).length) mismatchReasons.push('unexpected_violations');
  if (Number(stats.firestoreWrites || 0) !== 0) mismatchReasons.push('firestore_writes_not_zero');
  if (stats.publishToTarget || stats.publishFromTarget) mismatchReasons.push('publish_detected');
  if (stats.targetPathBuilt) mismatchReasons.push('target_path_built');
  if (stats.lifecycleTouched) mismatchReasons.push('lifecycle_touched');
  return mismatchReasons;
}

function listMigration2CutonObsoleteSettingsHandlers_() {
  var names = [
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
    'runMigration1FinalCleanSettingsTest',
    'getMigration1FinalCleanSettingsStatus',
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
    'getMigration1TargetRuntimeGateSettingsStatus',
    'runMigration1ShadowSettingsTest',
    'getMigration1ShadowSettingsStatus'
  ];
  return names.filter(function (name) {
    try {
      return typeof this[name] === 'function';
    } catch (e) {
      return false;
    }
  });
}

function formatMigration2CutonSelfTestFeedback_(result) {
  result = result || {};
  var lines = [];
  lines.push('MIGRATION_2_CUTON_TEST');
  lines.push('ok=' + String(!!result.ok));
  lines.push('testCount=' + String(result.testCount || 0));
  lines.push('passedCount=' + String(result.passedCount || 0));
  lines.push('failedCount=' + String(result.failedCount || 0));
  lines.push('cutonVersion=' + String(result.cutonVersion || PHBOX_M2_CUTON_VERSION_));
  lines.push('verifyVersion=' + String(result.verifyVersion || PHBOX_M2_CUTON_REQUIRED_VERIFY_VERSION_));
  lines.push('dashVersion=' + String(result.dashVersion || PHBOX_M2_CUTON_REQUIRED_DASH_VERSION_));
  lines.push('routeVersion=' + String(result.routeVersion || PHBOX_M2_CUTON_REQUIRED_ROUTE_VERSION_));
  lines.push('signalVersion=' + String(result.signalVersion || PHBOX_M2_CUTON_REQUIRED_SIGNAL_VERSION_));
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
    lines.push('  enabled=' + String(!!item.enabled));
    lines.push('  skipped=' + String(!!item.skipped));
    lines.push('  reason=' + String(item.reason || ''));
    lines.push('  cutoverTenantId=' + String(item.cutoverTenantId || ''));
    lines.push('  tenantId=' + String(item.tenantId || ''));
    lines.push('  targetVerifyAuthorized=' + String(!!item.targetVerifyAuthorized));
    lines.push('  verifyLegacyPathsCompared=' + String(item.verifyLegacyPathsCompared || 0));
    lines.push('  verifyMismatchedCount=' + String(item.verifyMismatchedCount || 0));
    lines.push('  cutoverAuthorized=' + String(!!item.cutoverAuthorized));
    lines.push('  firestoreReads=' + String(item.firestoreReads || 0));
    lines.push('  firestoreWrites=' + String(item.firestoreWrites || 0));
    lines.push('  publishFromTarget=' + String(!!item.publishFromTarget));
    lines.push('  publishToTarget=' + String(!!item.publishToTarget));
    lines.push('  targetPathBuilt=' + String(!!item.targetPathBuilt));
    lines.push('  cutover=' + String(!!item.cutover));
    lines.push('  lifecycleTouched=' + String(!!item.lifecycleTouched));
    lines.push('  violations=' + ((item.violations || []).length ? item.violations.join(',') : 'none'));
    lines.push('  mismatchReasons=' + ((item.mismatchReasons || []).length ? item.mismatchReasons.join(',') : 'none'));
  });
  return lines.join('\n');
}

function formatMigration2CutonRuntimeFeedback_(result) {
  var stats = (result && result.stats) || {};
  var lines = [];
  lines.push('MIGRATION_2_CUTON_RUNTIME_STATUS');
  lines.push('ok=' + String(!!(result && result.ok)));
  lines.push('enabled=' + String(!!stats.enabled));
  lines.push('skipped=' + String(!!stats.skipped));
  lines.push('reason=' + String(stats.reason || ''));
  lines.push('cutonVersion=' + String(stats.cutonVersion || PHBOX_M2_CUTON_VERSION_));
  lines.push('verifyVersion=' + String(stats.verifyVersion || ''));
  lines.push('dashVersion=' + String(stats.dashVersion || ''));
  lines.push('routeVersion=' + String(stats.routeVersion || ''));
  lines.push('signalVersion=' + String(stats.signalVersion || ''));
  lines.push('routeMode=' + String(stats.routeMode || ''));
  lines.push('routeDecision=' + String(stats.routeDecision || ''));
  lines.push('dashboardReadDecision=' + String(stats.dashboardReadDecision || ''));
  lines.push('cutoverTenantId=' + String(stats.cutoverTenantId || ''));
  lines.push('tenantId=' + String(stats.tenantId || ''));
  lines.push('tenantCanonical=' + String(!!stats.tenantCanonical));
  lines.push('targetReadWriteAuthorized=' + String(!!stats.targetReadWriteAuthorized));
  lines.push('targetReadAuthorized=' + String(!!stats.targetReadAuthorized));
  lines.push('targetVerifyAuthorized=' + String(!!stats.targetVerifyAuthorized));
  lines.push('verifyOk=' + String(!!stats.verifyOk));
  lines.push('verifyLegacyPathsCompared=' + String(stats.verifyLegacyPathsCompared || 0));
  lines.push('verifyMismatchedCount=' + String(stats.verifyMismatchedCount || 0));
  lines.push('verifyMissingLegacyCount=' + String(stats.verifyMissingLegacyCount || 0));
  lines.push('verifyMissingTargetCount=' + String(stats.verifyMissingTargetCount || 0));
  lines.push('cutoverAuthorized=' + String(!!stats.cutoverAuthorized));
  lines.push('obsoleteHandlersCount=' + String(stats.obsoleteHandlersCount || 0));
  lines.push('firestoreReads=' + String(stats.firestoreReads || 0));
  lines.push('firestoreWrites=' + String(stats.firestoreWrites || 0));
  lines.push('publishFromTarget=' + String(!!stats.publishFromTarget));
  lines.push('publishToTarget=' + String(!!stats.publishToTarget));
  lines.push('targetPathBuilt=' + String(!!stats.targetPathBuilt));
  lines.push('cutover=' + String(!!stats.cutover));
  lines.push('lifecycleTouched=' + String(!!stats.lifecycleTouched));
  lines.push('violations=' + ((stats.violations || []).length ? stats.violations.join(',') : 'none'));
  lines.push('obsoleteHandlers=' + ((stats.obsoleteHandlers || []).length ? stats.obsoleteHandlers.join(',') : 'none'));
  lines.push('error=' + (stats.error || 'none'));
  lines.push('errorKind=' + (stats.errorKind || 'none'));
  return lines.join('\n');
}
