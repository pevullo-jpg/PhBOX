var PHBOX_M2_E2E_VERSION_ = 'M2_E2E_v1';
var PHBOX_M2_E2E_STAGE_ = 'migration2_end_to_end_controlled_validation';
var PHBOX_M2_E2E_REQUIRED_LOCK_VERSION_ = 'M2_LOCK_v3';
var PHBOX_M2_E2E_REQUIRED_ROUTE_VERSION_ = 'M2_ROUTE_v2';
var PHBOX_M2_E2E_REQUIRED_WRITE_VERSION_ = 'M2_WRITE_v1';
var PHBOX_M2_E2E_REQUIRED_SIGNAL_VERSION_ = 'M2_SIGNAL_v2';
var PHBOX_M2_E2E_REQUIRED_DASH_VERSION_ = 'M2_DASH_v1';
var PHBOX_M2_E2E_REQUIRED_VERIFY_VERSION_ = 'M2_VERIFY_v3';
var PHBOX_M2_E2E_REQUIRED_CUTON_VERSION_ = 'M2_CUTON_v3';
var PHBOX_M2_E2E_REQUIRED_ROLLBACK_VERSION_ = 'M2_ROLLBACK_v6';

function runMigration2E2eRuntimeStatus_() {
  var lockStatus = runMigration2E2eRuntimeStage_('lock', 'runMigration2LockRuntimeStatus_', 'lockVersion', PHBOX_M2_E2E_REQUIRED_LOCK_VERSION_);
  var routeStatus = runMigration2E2eRuntimeStage_('route', 'runMigration2RouteContractRuntimeStatus_', 'routeVersion', PHBOX_M2_E2E_REQUIRED_ROUTE_VERSION_);
  var writeStatus = buildMigration2E2eTargetWriteRuntimeStatus_(routeStatus);
  var signalStatus = buildMigration2E2eRuntimeSignalRuntimeStatus_(routeStatus);
  var dashStatus = buildMigration2E2eDashboardRuntimeStatus_(routeStatus, signalStatus);
  var verifyStatus = buildMigration2E2eVerifyRuntimeStatus_(dashStatus);
  var cutonStatus = buildMigration2E2eCutonRuntimeStatus_(verifyStatus);
  var rollbackStatus = buildMigration2E2eRollbackRuntimeStatus_(cutonStatus);

  return buildMigration2E2eResult_({
    lockStatus: lockStatus,
    routeStatus: routeStatus,
    writeStatus: writeStatus,
    signalStatus: signalStatus,
    dashStatus: dashStatus,
    verifyStatus: verifyStatus,
    cutonStatus: cutonStatus,
    rollbackStatus: rollbackStatus,
    obsoleteHandlers: listMigration2E2eObsoleteSettingsHandlers_()
  });
}

function runMigration2E2eRuntimeStage_(stageKey, functionName, versionField, requiredVersion) {
  try {
    var fn = null;
    if (typeof globalThis !== 'undefined' && typeof globalThis[functionName] === 'function') fn = globalThis[functionName];
    if (!fn && typeof this[functionName] === 'function') fn = this[functionName];
    if (typeof fn !== 'function') {
      throw new Error('M2_E2E_STAGE_MISSING: funzione ' + functionName + ' non disponibile. E2E M2 non verificabile.');
    }
    return fn();
  } catch (e) {
    return buildMigration2E2eStageFailureStatus_(stageKey, versionField, requiredVersion, 'm2_e2e_stage_error', e);
  }
}

function buildMigration2E2eTargetWriteRuntimeStatus_(routeStatus) {
  try {
    if (typeof buildMigration2TargetWriteResult_ !== 'function') {
      throw new Error('M2_E2E_WRITE_MISSING: funzione buildMigration2TargetWriteResult_ non disponibile. Target write M2 non verificabile.');
    }
    return buildMigration2TargetWriteResult_({
      cfg: getPhboxConfig_(),
      routeStatus: routeStatus,
      legacyWrites: [],
      executeTargetWrites: false,
      maxWrites: typeof readMigration2TargetWriteMaxWrites_ === 'function' ? readMigration2TargetWriteMaxWrites_() : 20
    });
  } catch (e) {
    return buildMigration2E2eStageFailureStatus_('write', 'writeVersion', PHBOX_M2_E2E_REQUIRED_WRITE_VERSION_, 'm2_e2e_write_error', e);
  }
}

function buildMigration2E2eRuntimeSignalRuntimeStatus_(routeStatus) {
  try {
    if (typeof buildMigration2RuntimeSignalResult_ !== 'function') {
      throw new Error('M2_E2E_SIGNAL_MISSING: funzione buildMigration2RuntimeSignalResult_ non disponibile. Runtime signal M2 non verificabile.');
    }
    return buildMigration2RuntimeSignalResult_({
      routeStatus: routeStatus,
      signal: null,
      obsoleteHandlers: typeof listMigration2RuntimeSignalObsoleteSettingsHandlers_ === 'function' ? listMigration2RuntimeSignalObsoleteSettingsHandlers_() : []
    });
  } catch (e) {
    return buildMigration2E2eStageFailureStatus_('signal', 'signalVersion', PHBOX_M2_E2E_REQUIRED_SIGNAL_VERSION_, 'm2_e2e_signal_error', e);
  }
}

function buildMigration2E2eDashboardRuntimeStatus_(routeStatus, signalStatus) {
  try {
    if (typeof buildMigration2DashboardReadResult_ !== 'function') {
      throw new Error('M2_E2E_DASH_MISSING: funzione buildMigration2DashboardReadResult_ non disponibile. Dashboard read M2 non verificabile.');
    }
    return buildMigration2DashboardReadResult_({
      routeStatus: routeStatus,
      signalStatus: signalStatus,
      obsoleteHandlers: typeof listMigration2DashboardReadObsoleteSettingsHandlers_ === 'function' ? listMigration2DashboardReadObsoleteSettingsHandlers_() : []
    });
  } catch (e) {
    return buildMigration2E2eStageFailureStatus_('dash', 'dashVersion', PHBOX_M2_E2E_REQUIRED_DASH_VERSION_, 'm2_e2e_dash_error', e);
  }
}

function buildMigration2E2eVerifyRuntimeStatus_(dashStatus) {
  try {
    if (typeof buildMigration2PostWriteVerifyResult_ !== 'function') {
      throw new Error('M2_E2E_VERIFY_MISSING: funzione buildMigration2PostWriteVerifyResult_ non disponibile. Post-write verify M2 non verificabile.');
    }
    var legacyPaths = typeof readMigration2PostWriteVerifySampleLegacyPaths_ === 'function'
      ? readMigration2PostWriteVerifySampleLegacyPaths_()
      : [];
    var result = buildMigration2PostWriteVerifyResult_({
      dashStatus: dashStatus,
      legacyPaths: legacyPaths,
      obsoleteHandlers: typeof listMigration2PostWriteVerifyObsoleteSettingsHandlers_ === 'function' ? listMigration2PostWriteVerifyObsoleteSettingsHandlers_() : []
    });
    var stats = (result && result.stats) || {};
    if (!stats.targetVerifyAuthorized || !legacyPaths.length || !stats.ok) return result;
    if (typeof runMigration2PostWriteVerifyForLegacyPaths_ !== 'function') {
      throw new Error('M2_E2E_VERIFY_RUNNER_MISSING: funzione runMigration2PostWriteVerifyForLegacyPaths_ non disponibile. Target path non letto.');
    }
    return runMigration2PostWriteVerifyForLegacyPaths_(getPhboxConfig_(), dashStatus, legacyPaths);
  } catch (e) {
    return buildMigration2PostWriteVerifyResult_({
      dashStatus: dashStatus,
      legacyPaths: [],
      obsoleteHandlers: typeof listMigration2PostWriteVerifyObsoleteSettingsHandlers_ === 'function' ? listMigration2PostWriteVerifyObsoleteSettingsHandlers_() : [],
      error: normalizeRuntimeErrorMessage_(e),
      errorKind: classifyRuntimeFailureKind_(e)
    });
  }
}

function buildMigration2E2eCutonRuntimeStatus_(verifyStatus) {
  try {
    if (typeof buildMigration2CutonResult_ !== 'function') {
      throw new Error('M2_E2E_CUTON_MISSING: funzione buildMigration2CutonResult_ non disponibile. CUTON M2 non verificabile.');
    }
    var settings = typeof readMigration2CutonSettings_ === 'function'
      ? readMigration2CutonSettings_()
      : { enabled: false, cutoverTenantId: '' };
    if (!settings.enabled) {
      return buildMigration2CutonResult_({
        enabled: false,
        cutoverTenantId: settings.cutoverTenantId,
        obsoleteHandlers: typeof listMigration2CutonObsoleteSettingsHandlers_ === 'function' ? listMigration2CutonObsoleteSettingsHandlers_() : []
      });
    }
    return buildMigration2CutonResult_({
      enabled: true,
      cutoverTenantId: settings.cutoverTenantId,
      verifyStatus: verifyStatus,
      obsoleteHandlers: typeof listMigration2CutonObsoleteSettingsHandlers_ === 'function' ? listMigration2CutonObsoleteSettingsHandlers_() : []
    });
  } catch (e) {
    return buildMigration2E2eStageFailureStatus_('cuton', 'cutonVersion', PHBOX_M2_E2E_REQUIRED_CUTON_VERSION_, 'm2_e2e_cuton_error', e);
  }
}

function buildMigration2E2eRollbackRuntimeStatus_(cutonStatus) {
  try {
    if (typeof buildMigration2RollbackResult_ !== 'function') {
      throw new Error('M2_E2E_ROLLBACK_MISSING: funzione buildMigration2RollbackResult_ non disponibile. Rollback M2 non verificabile.');
    }
    var settings = typeof readMigration2RollbackSettings_ === 'function'
      ? readMigration2RollbackSettings_()
      : { enabled: false, rollbackTenantId: '' };
    if (!settings.enabled) {
      return buildMigration2RollbackResult_({
        enabled: false,
        rollbackTenantId: settings.rollbackTenantId,
        obsoleteHandlers: typeof listMigration2RollbackObsoleteSettingsHandlers_ === 'function' ? listMigration2RollbackObsoleteSettingsHandlers_() : []
      });
    }
    return buildMigration2RollbackResult_({
      enabled: true,
      rollbackTenantId: settings.rollbackTenantId,
      cutonStatus: cutonStatus,
      obsoleteHandlers: typeof listMigration2RollbackObsoleteSettingsHandlers_ === 'function' ? listMigration2RollbackObsoleteSettingsHandlers_() : []
    });
  } catch (e) {
    return buildMigration2E2eStageFailureStatus_('rollback', 'rollbackVersion', PHBOX_M2_E2E_REQUIRED_ROLLBACK_VERSION_, 'm2_e2e_rollback_error', e);
  }
}

function buildMigration2E2eStageFailureStatus_(stageKey, versionField, requiredVersion, reason, error) {
  var stats = {
    stage: 'migration2_' + String(stageKey || 'unknown'),
    ok: false,
    skipped: true,
    reason: String(reason || 'm2_e2e_stage_error'),
    firestoreReads: 0,
    firestoreWrites: 0,
    publishFromTarget: false,
    publishToTarget: false,
    targetPathBuilt: false,
    cutover: false,
    lifecycleTouched: false,
    violations: ['m2_e2e_stage_error'],
    error: normalizeRuntimeErrorMessage_(error),
    errorKind: classifyRuntimeFailureKind_(error)
  };
  stats[versionField] = String(requiredVersion || '');
  return {
    ok: false,
    stats: stats,
    items: []
  };
}

function buildMigration2E2eResult_(data) {
  data = data || {};
  var stages = [
    buildMigration2E2eStageSummary_('lock', data.lockStatus, 'lockVersion', PHBOX_M2_E2E_REQUIRED_LOCK_VERSION_),
    buildMigration2E2eStageSummary_('route', data.routeStatus, 'routeVersion', PHBOX_M2_E2E_REQUIRED_ROUTE_VERSION_),
    buildMigration2E2eStageSummary_('write', data.writeStatus, 'writeVersion', PHBOX_M2_E2E_REQUIRED_WRITE_VERSION_),
    buildMigration2E2eStageSummary_('signal', data.signalStatus, 'signalVersion', PHBOX_M2_E2E_REQUIRED_SIGNAL_VERSION_),
    buildMigration2E2eStageSummary_('dash', data.dashStatus, 'dashVersion', PHBOX_M2_E2E_REQUIRED_DASH_VERSION_),
    buildMigration2E2eStageSummary_('verify', data.verifyStatus, 'verifyVersion', PHBOX_M2_E2E_REQUIRED_VERIFY_VERSION_),
    buildMigration2E2eStageSummary_('cuton', data.cutonStatus, 'cutonVersion', PHBOX_M2_E2E_REQUIRED_CUTON_VERSION_),
    buildMigration2E2eStageSummary_('rollback', data.rollbackStatus, 'rollbackVersion', PHBOX_M2_E2E_REQUIRED_ROLLBACK_VERSION_)
  ];
  var obsoleteHandlers = uniqueNonEmptyStrings_(data.obsoleteHandlers || []);
  var violations = [];
  var failedStages = [];

  stages.forEach(function (stage) {
    if (!stage.present) violations.push(stage.key + '_status_missing');
    if (!stage.ok) violations.push(stage.key + '_not_ok');
    if (stage.version !== stage.requiredVersion) violations.push(stage.key + '_version_mismatch');
    if (stage.firestoreWrites !== 0) violations.push(stage.key + '_writes_not_zero');
    if (stage.key === 'write' && stage.targetWritesExecuted !== 0) violations.push('target_writes_executed');
    if (stage.publishFromTarget || stage.publishToTarget) violations.push(stage.key + '_publish_detected');
    if (stage.lifecycleTouched) violations.push(stage.key + '_lifecycle_touched');
    if (stage.violations.length > 0 && !stage.ok) violations.push(stage.key + '_violations_present');
  });

  if (obsoleteHandlers.length > 0) violations.push('obsolete_settings_handlers_detected');
  if (data.error) violations.push('m2_e2e_error');

  violations = uniqueNonEmptyStrings_(violations);
  stages.forEach(function (stage) {
    if (!stage.present || !stage.ok || stage.version !== stage.requiredVersion || stage.firestoreWrites !== 0 || stage.lifecycleTouched || stage.publishFromTarget || stage.publishToTarget) {
      failedStages.push(stage.key);
    }
  });
  failedStages = uniqueNonEmptyStrings_(failedStages);

  var routeStats = (data.routeStatus && data.routeStatus.stats) || {};
  var writeStats = (data.writeStatus && data.writeStatus.stats) || {};
  var dashStats = (data.dashStatus && data.dashStatus.stats) || {};
  var verifyStats = (data.verifyStatus && data.verifyStatus.stats) || {};
  var cutonStats = (data.cutonStatus && data.cutonStatus.stats) || {};
  var rollbackStats = (data.rollbackStatus && data.rollbackStatus.stats) || {};
  var firestoreReads = Math.max(0, Number(stages[0].firestoreReads || 0)) +
    Math.max(0, Number(stages[1].firestoreReads || 0)) +
    Math.max(0, Number(stages[2].firestoreReads || 0)) +
    Math.max(0, Number(stages[3].firestoreReads || 0)) +
    Math.max(0, Number(stages[4].firestoreReads || 0)) +
    Math.max(0, Number(stages[5].firestoreReads || 0));
  var firestoreWrites = stages.reduce(function (sum, stage) {
    return sum + Math.max(0, Number(stage.firestoreWrites || 0));
  }, 0);
  var reason = resolveMigration2E2eReason_(violations, routeStats, verifyStats, cutonStats, rollbackStats);
  var stats = {
    stage: PHBOX_M2_E2E_STAGE_,
    ok: violations.length === 0,
    skipped: false,
    reason: reason,
    e2eVersion: PHBOX_M2_E2E_VERSION_,
    lockVersion: stages[0].version,
    routeVersion: stages[1].version,
    writeVersion: stages[2].version,
    signalVersion: stages[3].version,
    dashVersion: stages[4].version,
    verifyVersion: stages[5].version,
    cutonVersion: stages[6].version,
    rollbackVersion: stages[7].version,
    routeMode: String(routeStats.routeMode || dashStats.routeMode || verifyStats.routeMode || cutonStats.routeMode || rollbackStats.routeMode || ''),
    routeDecision: String(routeStats.routeDecision || dashStats.routeDecision || verifyStats.routeDecision || cutonStats.routeDecision || rollbackStats.routeDecision || ''),
    dashboardReadDecision: String(dashStats.dashboardReadDecision || verifyStats.dashboardReadDecision || cutonStats.dashboardReadDecision || rollbackStats.dashboardReadDecision || ''),
    tenantId: String(routeStats.tenantId || dashStats.tenantId || verifyStats.tenantId || cutonStats.tenantId || rollbackStats.tenantId || ''),
    tenantCanonical: !!(routeStats.tenantCanonical || dashStats.tenantCanonical || verifyStats.tenantCanonical || cutonStats.tenantCanonical || rollbackStats.tenantCanonical),
    targetReadWriteAuthorized: !!(routeStats.targetReadWriteAuthorized || dashStats.targetReadWriteAuthorized || verifyStats.targetReadWriteAuthorized || cutonStats.targetReadWriteAuthorized || rollbackStats.targetReadWriteAuthorized),
    targetRouteAuthorized: !!routeStats.targetRouteAuthorized,
    targetWriteAuthorized: !!writeStats.targetWriteAuthorized,
    targetReadAuthorized: !!(dashStats.targetReadAuthorized || verifyStats.targetReadAuthorized || cutonStats.targetReadAuthorized || rollbackStats.targetReadAuthorized),
    targetVerifyAuthorized: !!(verifyStats.targetVerifyAuthorized || cutonStats.targetVerifyAuthorized || rollbackStats.targetVerifyAuthorized),
    cutonEnabled: !!cutonStats.enabled,
    cutoverAuthorized: !!cutonStats.cutoverAuthorized,
    rollbackEnabled: !!rollbackStats.enabled,
    rollbackAuthorized: !!rollbackStats.rollbackAuthorized,
    legacyRouteActive: !!(routeStats.legacyRouteActive || dashStats.legacyDashboardActive || rollbackStats.legacyRouteActive),
    dualCheckPlanned: !!(routeStats.dualCheckPlanned || dashStats.dualCheckReadPlanned),
    legacyPathsSeen: Math.max(0, Number(verifyStats.legacyPathsSeen || 0)),
    legacyPathsCompared: Math.max(0, Number(verifyStats.legacyPathsCompared || cutonStats.verifyLegacyPathsCompared || rollbackStats.verifyLegacyPathsCompared || 0)),
    mismatchedCount: Math.max(0, Number(verifyStats.mismatchedCount || cutonStats.verifyMismatchedCount || rollbackStats.verifyMismatchedCount || 0)),
    missingLegacyCount: Math.max(0, Number(verifyStats.missingLegacyCount || cutonStats.verifyMissingLegacyCount || rollbackStats.verifyMissingLegacyCount || 0)),
    missingTargetCount: Math.max(0, Number(verifyStats.missingTargetCount || cutonStats.verifyMissingTargetCount || rollbackStats.verifyMissingTargetCount || 0)),
    targetWritesPlanned: Math.max(0, Number(writeStats.targetWritesPlanned || 0)),
    targetWritesExecuted: Math.max(0, Number(writeStats.targetWritesExecuted || 0)),
    firestoreReads: firestoreReads,
    firestoreWrites: firestoreWrites,
    publishFromTarget: stages.some(function (stage) { return stage.publishFromTarget; }),
    publishToTarget: stages.some(function (stage) { return stage.publishToTarget; }),
    targetPathBuilt: stages.some(function (stage) { return stage.targetPathBuilt; }),
    cutover: !!(cutonStats.cutover || rollbackStats.sourceCutover),
    lifecycleTouched: stages.some(function (stage) { return stage.lifecycleTouched; }),
    failedStages: failedStages,
    failedStagesCount: failedStages.length,
    obsoleteHandlersCount: obsoleteHandlers.length,
    obsoleteHandlers: obsoleteHandlers,
    violations: violations,
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };

  return {
    ok: !!stats.ok,
    stats: stats,
    items: stages,
    failedStages: failedStages
  };
}

function buildMigration2E2eStageSummary_(key, status, versionField, requiredVersion) {
  var stats = (status && status.stats) || {};
  return {
    key: String(key || ''),
    present: !!(status && status.stats),
    ok: !!(status && status.ok) && stats.ok !== false,
    version: String(stats[versionField] || ''),
    requiredVersion: String(requiredVersion || ''),
    reason: String(stats.reason || ''),
    skipped: !!stats.skipped,
    routeDecision: String(stats.routeDecision || ''),
    dashboardReadDecision: String(stats.dashboardReadDecision || ''),
    firestoreReads: Math.max(0, Number(stats.firestoreReads || 0)),
    firestoreWrites: Math.max(0, Number(stats.firestoreWrites || 0)),
    publishFromTarget: !!stats.publishFromTarget,
    publishToTarget: !!stats.publishToTarget,
    targetPathBuilt: !!stats.targetPathBuilt,
    cutover: !!stats.cutover,
    lifecycleTouched: !!stats.lifecycleTouched,
    targetWritesPlanned: Math.max(0, Number(stats.targetWritesPlanned || 0)),
    targetWritesExecuted: Math.max(0, Number(stats.targetWritesExecuted || 0)),
    violations: uniqueNonEmptyStrings_(stats.violations || []),
    error: String(stats.error || ''),
    errorKind: String(stats.errorKind || '')
  };
}

function resolveMigration2E2eReason_(violations, routeStats, verifyStats, cutonStats, rollbackStats) {
  if ((violations || []).length > 0) return 'm2_e2e_violation';
  if (rollbackStats && rollbackStats.rollbackAuthorized) return 'controlled_rollback_authorized';
  if (cutonStats && cutonStats.cutoverAuthorized) return 'cutover_authorized';
  if (verifyStats && verifyStats.targetVerifyAuthorized && Number(verifyStats.legacyPathsCompared || 0) > 0) return 'target_verified_e2e';
  var routeDecision = String((routeStats && routeStats.routeDecision) || '').trim().toLowerCase();
  if (routeDecision === 'target') return 'target_route_e2e_validated';
  if (routeDecision === 'dual_check') return 'dual_check_e2e_validated';
  if (routeDecision === 'legacy') return 'legacy_route_e2e_validated';
  return 'm2_e2e_validated';
}

function runMigration2E2eSelfTest_() {
  var cases = [
    {
      id: 'legacy_route_default_passes_without_reads_or_writes',
      result: buildMigration2E2eSyntheticResult_({ routeDecision: 'legacy', routeMode: 'legacy', legacyRouteActive: true }),
      expected: { ok: true, reason: 'legacy_route_e2e_validated', firestoreReads: 0, firestoreWrites: 0, publishToTarget: false, lifecycleTouched: false, failedStagesCount: 0 }
    },
    {
      id: 'dual_check_route_passes_contract_only',
      result: buildMigration2E2eSyntheticResult_({ routeDecision: 'dual_check', routeMode: 'dual_check', dualCheckPlanned: true }),
      expected: { ok: true, reason: 'dual_check_e2e_validated', firestoreReads: 0, firestoreWrites: 0, failedStagesCount: 0 }
    },
    {
      id: 'target_verify_with_bounded_reads_passes',
      result: buildMigration2E2eSyntheticResult_({ routeDecision: 'target', routeMode: 'target', targetReadWriteAuthorized: true, targetRouteAuthorized: true, targetReadAuthorized: true, targetVerifyAuthorized: true, legacyPathsSeen: 2, legacyPathsCompared: 2, firestoreReads: 4, targetPathBuilt: true }),
      expected: { ok: true, reason: 'target_verified_e2e', firestoreReads: 4, firestoreWrites: 0, targetPathBuilt: true, failedStagesCount: 0 }
    },
    {
      id: 'verify_mismatch_fails_e2e',
      result: buildMigration2E2eSyntheticResult_({ routeDecision: 'target', routeMode: 'target', targetReadWriteAuthorized: true, targetRouteAuthorized: true, targetReadAuthorized: true, targetVerifyAuthorized: true, legacyPathsSeen: 2, legacyPathsCompared: 2, mismatchedCount: 1, firestoreReads: 4, verifyOk: false, verifyViolations: ['signature_mismatch'] }),
      expected: { ok: false, reason: 'm2_e2e_violation', failedStage: 'verify', firestoreWrites: 0 }
    },
    {
      id: 'target_write_execution_blocks_e2e',
      result: buildMigration2E2eSyntheticResult_({ routeDecision: 'target', routeMode: 'target', targetReadWriteAuthorized: true, targetRouteAuthorized: true, targetWriteAuthorized: true, targetWritesExecuted: 1, writeOk: true }),
      expected: { ok: false, reason: 'm2_e2e_violation', failedStage: 'write', firestoreWrites: 1 }
    },
    {
      id: 'version_mismatch_blocks_e2e',
      result: buildMigration2E2eSyntheticResult_({ routeVersion: 'M2_ROUTE_v1' }),
      expected: { ok: false, reason: 'm2_e2e_violation', failedStage: 'route', violation: 'route_version_mismatch' }
    },
    {
      id: 'obsolete_settings_handler_blocks_e2e',
      result: buildMigration2E2eSyntheticResult_({ obsoleteHandlers: ['runMigration2RollbackSettingsTest'] }),
      expected: { ok: false, reason: 'm2_e2e_violation', violation: 'obsolete_settings_handlers_detected' }
    },
    {
      id: 'cuton_authorized_passes_without_writes',
      result: buildMigration2E2eSyntheticResult_({ routeDecision: 'target', routeMode: 'target', targetReadWriteAuthorized: true, targetRouteAuthorized: true, targetReadAuthorized: true, targetVerifyAuthorized: true, cutonEnabled: true, cutoverAuthorized: true, cutover: true, legacyPathsSeen: 1, legacyPathsCompared: 1, firestoreReads: 2 }),
      expected: { ok: true, reason: 'cutover_authorized', firestoreReads: 2, firestoreWrites: 0, cutover: true }
    },
    {
      id: 'rollback_authorized_passes_as_controlled_status',
      result: buildMigration2E2eSyntheticResult_({ routeDecision: 'target', routeMode: 'target', targetReadWriteAuthorized: true, targetRouteAuthorized: true, targetReadAuthorized: true, targetVerifyAuthorized: true, cutonEnabled: true, cutoverAuthorized: true, cutover: true, rollbackEnabled: true, rollbackAuthorized: true, legacyRouteActive: true, firestoreReads: 2 }),
      expected: { ok: true, reason: 'controlled_rollback_authorized', rollbackAuthorized: true, firestoreWrites: 0 }
    },
    {
      id: 'lifecycle_touch_blocks_e2e',
      result: buildMigration2E2eSyntheticResult_({ lifecycleTouched: true }),
      expected: { ok: false, reason: 'm2_e2e_violation', lifecycleTouched: true, violation: 'route_lifecycle_touched' }
    }
  ];

  var passed = 0;
  var failed = 0;
  var items = cases.map(function (item) {
    var actual = buildMigration2E2eSelfTestActual_(item.result);
    var mismatchReasons = compareMigration2E2eExpected_(actual, item.expected || {});
    var ok = mismatchReasons.length === 0;
    if (ok) passed++; else failed++;
    return {
      id: item.id,
      passed: ok,
      actual: actual,
      expected: item.expected || {},
      mismatchReasons: mismatchReasons
    };
  });

  return {
    ok: failed === 0,
    testCount: items.length,
    passedCount: passed,
    failedCount: failed,
    e2eVersion: PHBOX_M2_E2E_VERSION_,
    lockVersion: PHBOX_M2_E2E_REQUIRED_LOCK_VERSION_,
    routeVersion: PHBOX_M2_E2E_REQUIRED_ROUTE_VERSION_,
    writeVersion: PHBOX_M2_E2E_REQUIRED_WRITE_VERSION_,
    signalVersion: PHBOX_M2_E2E_REQUIRED_SIGNAL_VERSION_,
    dashVersion: PHBOX_M2_E2E_REQUIRED_DASH_VERSION_,
    verifyVersion: PHBOX_M2_E2E_REQUIRED_VERIFY_VERSION_,
    cutonVersion: PHBOX_M2_E2E_REQUIRED_CUTON_VERSION_,
    rollbackVersion: PHBOX_M2_E2E_REQUIRED_ROLLBACK_VERSION_,
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

function buildMigration2E2eSyntheticResult_(options) {
  options = options || {};
  var routeDecision = String(options.routeDecision || 'legacy');
  var routeMode = String(options.routeMode || routeDecision || 'legacy');
  var tenantId = String(options.tenantId || (routeDecision === 'target' ? 'farmacia_santa_venera' : ''));
  var routeStatus = buildMigration2E2eSyntheticStageStatus_('route', 'routeVersion', String(options.routeVersion || PHBOX_M2_E2E_REQUIRED_ROUTE_VERSION_), options.routeOk !== false, {
    routeMode: routeMode,
    routeDecision: routeDecision,
    tenantId: tenantId,
    tenantCanonical: !!tenantId,
    targetReadWriteAuthorized: !!options.targetReadWriteAuthorized,
    targetRouteAuthorized: !!options.targetRouteAuthorized,
    legacyRouteActive: routeDecision === 'legacy' || !!options.legacyRouteActive,
    dualCheckPlanned: routeDecision === 'dual_check' || !!options.dualCheckPlanned,
    lifecycleTouched: !!options.lifecycleTouched
  });
  var writeStatus = buildMigration2E2eSyntheticStageStatus_('write', 'writeVersion', PHBOX_M2_E2E_REQUIRED_WRITE_VERSION_, options.writeOk !== false, {
    routeMode: routeMode,
    routeDecision: routeDecision,
    targetWriteAuthorized: !!options.targetWriteAuthorized,
    tenantId: tenantId,
    tenantCanonical: !!tenantId,
    targetReadWriteAuthorized: !!options.targetReadWriteAuthorized,
    targetWritesPlanned: Math.max(0, Number(options.targetWritesPlanned || 0)),
    targetWritesExecuted: Math.max(0, Number(options.targetWritesExecuted || 0)),
    firestoreWrites: Math.max(0, Number(options.targetWritesExecuted || 0)),
    publishToTarget: Math.max(0, Number(options.targetWritesPlanned || 0)) > 0 || Math.max(0, Number(options.targetWritesExecuted || 0)) > 0,
    targetPathBuilt: Math.max(0, Number(options.targetWritesPlanned || 0)) > 0 || Math.max(0, Number(options.targetWritesExecuted || 0)) > 0
  });
  var signalStatus = buildMigration2E2eSyntheticStageStatus_('signal', 'signalVersion', PHBOX_M2_E2E_REQUIRED_SIGNAL_VERSION_, options.signalOk !== false, {
    routeMode: routeMode,
    routeDecision: routeDecision,
    tenantId: tenantId,
    tenantCanonical: !!tenantId,
    targetReadWriteAuthorized: !!options.targetReadWriteAuthorized
  });
  var dashStatus = buildMigration2E2eSyntheticStageStatus_('dash', 'dashVersion', PHBOX_M2_E2E_REQUIRED_DASH_VERSION_, options.dashOk !== false, {
    routeMode: routeMode,
    routeDecision: routeDecision,
    dashboardReadDecision: String(options.dashboardReadDecision || routeDecision),
    tenantId: tenantId,
    tenantCanonical: !!tenantId,
    targetReadWriteAuthorized: !!options.targetReadWriteAuthorized,
    targetReadAuthorized: !!options.targetReadAuthorized,
    legacyDashboardActive: routeDecision === 'legacy' || !!options.legacyRouteActive,
    dualCheckReadPlanned: routeDecision === 'dual_check' || !!options.dualCheckPlanned,
    targetPathBuilt: !!options.targetPathBuilt
  });
  var verifyStatus = buildMigration2E2eSyntheticStageStatus_('verify', 'verifyVersion', PHBOX_M2_E2E_REQUIRED_VERIFY_VERSION_, options.verifyOk !== false, {
    routeMode: routeMode,
    routeDecision: routeDecision,
    dashboardReadDecision: String(options.dashboardReadDecision || routeDecision),
    tenantId: tenantId,
    tenantCanonical: !!tenantId,
    targetReadWriteAuthorized: !!options.targetReadWriteAuthorized,
    targetReadAuthorized: !!options.targetReadAuthorized,
    targetVerifyAuthorized: !!options.targetVerifyAuthorized,
    legacyPathsSeen: Math.max(0, Number(options.legacyPathsSeen || 0)),
    legacyPathsCompared: Math.max(0, Number(options.legacyPathsCompared || 0)),
    mismatchedCount: Math.max(0, Number(options.mismatchedCount || 0)),
    missingLegacyCount: Math.max(0, Number(options.missingLegacyCount || 0)),
    missingTargetCount: Math.max(0, Number(options.missingTargetCount || 0)),
    firestoreReads: Math.max(0, Number(options.firestoreReads || 0)),
    targetPathBuilt: !!options.targetPathBuilt,
    violations: uniqueNonEmptyStrings_(options.verifyViolations || [])
  });
  var cutonStatus = buildMigration2E2eSyntheticStageStatus_('cuton', 'cutonVersion', PHBOX_M2_E2E_REQUIRED_CUTON_VERSION_, options.cutonOk !== false, {
    enabled: !!options.cutonEnabled,
    routeMode: routeMode,
    routeDecision: routeDecision,
    dashboardReadDecision: String(options.dashboardReadDecision || routeDecision),
    tenantId: tenantId,
    tenantCanonical: !!tenantId,
    targetReadWriteAuthorized: !!options.targetReadWriteAuthorized,
    targetReadAuthorized: !!options.targetReadAuthorized,
    targetVerifyAuthorized: !!options.targetVerifyAuthorized,
    verifyLegacyPathsCompared: Math.max(0, Number(options.legacyPathsCompared || 0)),
    verifyMismatchedCount: Math.max(0, Number(options.mismatchedCount || 0)),
    cutoverAuthorized: !!options.cutoverAuthorized,
    cutover: !!options.cutover
  });
  var rollbackStatus = buildMigration2E2eSyntheticStageStatus_('rollback', 'rollbackVersion', PHBOX_M2_E2E_REQUIRED_ROLLBACK_VERSION_, options.rollbackOk !== false, {
    enabled: !!options.rollbackEnabled,
    routeMode: routeMode,
    routeDecision: routeDecision,
    dashboardReadDecision: String(options.dashboardReadDecision || routeDecision),
    tenantId: tenantId,
    tenantCanonical: !!tenantId,
    targetReadWriteAuthorized: !!options.targetReadWriteAuthorized,
    targetReadAuthorized: !!options.targetReadAuthorized,
    targetVerifyAuthorized: !!options.targetVerifyAuthorized,
    verifyLegacyPathsCompared: Math.max(0, Number(options.legacyPathsCompared || 0)),
    verifyMismatchedCount: Math.max(0, Number(options.mismatchedCount || 0)),
    rollbackAuthorized: !!options.rollbackAuthorized,
    legacyRouteActive: !!options.legacyRouteActive,
    sourceCutover: !!options.cutover
  });

  return buildMigration2E2eResult_({
    lockStatus: buildMigration2E2eSyntheticStageStatus_('lock', 'lockVersion', PHBOX_M2_E2E_REQUIRED_LOCK_VERSION_, options.lockOk !== false, {}),
    routeStatus: routeStatus,
    writeStatus: writeStatus,
    signalStatus: signalStatus,
    dashStatus: dashStatus,
    verifyStatus: verifyStatus,
    cutonStatus: cutonStatus,
    rollbackStatus: rollbackStatus,
    obsoleteHandlers: uniqueNonEmptyStrings_(options.obsoleteHandlers || [])
  });
}

function buildMigration2E2eSyntheticStageStatus_(stageKey, versionField, version, ok, stats) {
  stats = stats || {};
  stats.stage = 'migration2_' + String(stageKey || 'synthetic');
  stats.ok = ok !== false;
  stats.skipped = !!stats.skipped;
  stats.reason = String(stats.reason || 'synthetic_status');
  stats.firestoreReads = Math.max(0, Number(stats.firestoreReads || 0));
  stats.firestoreWrites = Math.max(0, Number(stats.firestoreWrites || 0));
  stats.publishFromTarget = !!stats.publishFromTarget;
  stats.publishToTarget = !!stats.publishToTarget;
  stats.targetPathBuilt = !!stats.targetPathBuilt;
  stats.cutover = !!stats.cutover;
  stats.lifecycleTouched = !!stats.lifecycleTouched;
  stats.violations = uniqueNonEmptyStrings_(stats.violations || []);
  stats.error = String(stats.error || '');
  stats.errorKind = String(stats.errorKind || '');
  stats[versionField] = String(version || '');
  return {
    ok: ok !== false,
    stats: stats,
    items: []
  };
}

function buildMigration2E2eSelfTestActual_(result) {
  var stats = (result && result.stats) || {};
  return {
    ok: !!(result && result.ok),
    reason: String(stats.reason || ''),
    routeDecision: String(stats.routeDecision || ''),
    dashboardReadDecision: String(stats.dashboardReadDecision || ''),
    firestoreReads: Number(stats.firestoreReads || 0),
    firestoreWrites: Number(stats.firestoreWrites || 0),
    publishToTarget: !!stats.publishToTarget,
    targetPathBuilt: !!stats.targetPathBuilt,
    cutover: !!stats.cutover,
    lifecycleTouched: !!stats.lifecycleTouched,
    rollbackAuthorized: !!stats.rollbackAuthorized,
    failedStagesCount: Number(stats.failedStagesCount || 0),
    failedStages: uniqueNonEmptyStrings_(stats.failedStages || []),
    violations: uniqueNonEmptyStrings_(stats.violations || [])
  };
}

function compareMigration2E2eExpected_(actual, expected) {
  var mismatches = [];
  Object.keys(expected || {}).forEach(function (key) {
    if (key === 'failedStage') {
      if (actual.failedStages.indexOf(expected[key]) === -1) mismatches.push('expected_failed_stage_missing');
      return;
    }
    if (key === 'violation') {
      if (actual.violations.indexOf(expected[key]) === -1) mismatches.push('expected_violation_missing');
      return;
    }
    if (actual[key] !== expected[key]) mismatches.push('field_' + key + '_mismatch');
  });
  if (actual.firestoreWrites < 0) mismatches.push('firestore_writes_invalid');
  if (actual.lifecycleTouched && expected.lifecycleTouched !== true) mismatches.push('unexpected_lifecycle_touched');
  return uniqueNonEmptyStrings_(mismatches);
}

function listMigration2E2eObsoleteSettingsHandlers_() {
  var names = [
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

function formatMigration2E2eSelfTestFeedback_(result) {
  result = result || runMigration2E2eSelfTest_();
  var lines = [];
  lines.push('MIGRATION_2_E2E_TEST');
  lines.push('ok=' + String(!!result.ok));
  lines.push('testCount=' + String(result.testCount || 0));
  lines.push('passedCount=' + String(result.passedCount || 0));
  lines.push('failedCount=' + String(result.failedCount || 0));
  lines.push('e2eVersion=' + String(result.e2eVersion || ''));
  lines.push('lockVersion=' + String(result.lockVersion || ''));
  lines.push('routeVersion=' + String(result.routeVersion || ''));
  lines.push('writeVersion=' + String(result.writeVersion || ''));
  lines.push('signalVersion=' + String(result.signalVersion || ''));
  lines.push('dashVersion=' + String(result.dashVersion || ''));
  lines.push('verifyVersion=' + String(result.verifyVersion || ''));
  lines.push('cutonVersion=' + String(result.cutonVersion || ''));
  lines.push('rollbackVersion=' + String(result.rollbackVersion || ''));
  lines.push('firestoreReads=' + String(result.firestoreReads || 0));
  lines.push('firestoreWrites=' + String(result.firestoreWrites || 0));
  lines.push('publishFromTarget=' + String(!!result.publishFromTarget));
  lines.push('publishToTarget=' + String(!!result.publishToTarget));
  lines.push('targetPathBuilt=' + String(!!result.targetPathBuilt));
  lines.push('cutover=' + String(!!result.cutover));
  lines.push('lifecycleTouched=' + String(!!result.lifecycleTouched));
  lines.push('items=');
  (result.items || []).forEach(function (item) {
    var actual = item.actual || {};
    lines.push('- id=' + item.id);
    lines.push('  passed=' + String(!!item.passed));
    lines.push('  ok=' + String(!!actual.ok));
    lines.push('  reason=' + String(actual.reason || ''));
    lines.push('  routeDecision=' + String(actual.routeDecision || ''));
    lines.push('  dashboardReadDecision=' + String(actual.dashboardReadDecision || ''));
    lines.push('  firestoreReads=' + String(actual.firestoreReads || 0));
    lines.push('  firestoreWrites=' + String(actual.firestoreWrites || 0));
    lines.push('  publishToTarget=' + String(!!actual.publishToTarget));
    lines.push('  targetPathBuilt=' + String(!!actual.targetPathBuilt));
    lines.push('  cutover=' + String(!!actual.cutover));
    lines.push('  lifecycleTouched=' + String(!!actual.lifecycleTouched));
    lines.push('  rollbackAuthorized=' + String(!!actual.rollbackAuthorized));
    lines.push('  failedStages=' + (actual.failedStages.length ? actual.failedStages.join(',') : 'none'));
    lines.push('  violations=' + (actual.violations.length ? actual.violations.join(',') : 'none'));
    lines.push('  mismatchReasons=' + ((item.mismatchReasons || []).length ? item.mismatchReasons.join(',') : 'none'));
  });
  return lines.join('\n');
}

function formatMigration2E2eRuntimeFeedback_(result) {
  result = result || runMigration2E2eRuntimeStatus_();
  var stats = (result && result.stats) || {};
  var lines = [];
  lines.push('MIGRATION_2_E2E_RUNTIME_STATUS');
  lines.push('ok=' + String(!!(result && result.ok)));
  lines.push('skipped=' + String(!!stats.skipped));
  lines.push('reason=' + String(stats.reason || ''));
  lines.push('e2eVersion=' + String(stats.e2eVersion || ''));
  lines.push('lockVersion=' + String(stats.lockVersion || ''));
  lines.push('routeVersion=' + String(stats.routeVersion || ''));
  lines.push('writeVersion=' + String(stats.writeVersion || ''));
  lines.push('signalVersion=' + String(stats.signalVersion || ''));
  lines.push('dashVersion=' + String(stats.dashVersion || ''));
  lines.push('verifyVersion=' + String(stats.verifyVersion || ''));
  lines.push('cutonVersion=' + String(stats.cutonVersion || ''));
  lines.push('rollbackVersion=' + String(stats.rollbackVersion || ''));
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
  lines.push('publishFromTarget=' + String(!!stats.publishFromTarget));
  lines.push('publishToTarget=' + String(!!stats.publishToTarget));
  lines.push('targetPathBuilt=' + String(!!stats.targetPathBuilt));
  lines.push('cutover=' + String(!!stats.cutover));
  lines.push('lifecycleTouched=' + String(!!stats.lifecycleTouched));
  lines.push('failedStages=' + ((stats.failedStages || []).length ? stats.failedStages.join(',') : 'none'));
  lines.push('obsoleteHandlers=' + ((stats.obsoleteHandlers || []).length ? stats.obsoleteHandlers.join(',') : 'none'));
  lines.push('violations=' + ((stats.violations || []).length ? stats.violations.join(',') : 'none'));
  lines.push('error=' + (stats.error || 'none'));
  lines.push('errorKind=' + (stats.errorKind || 'none'));
  lines.push('stageItems=');
  (result.items || []).forEach(function (item) {
    lines.push('- key=' + item.key);
    lines.push('  ok=' + String(!!item.ok));
    lines.push('  version=' + String(item.version || ''));
    lines.push('  reason=' + String(item.reason || ''));
    lines.push('  firestoreReads=' + String(item.firestoreReads || 0));
    lines.push('  firestoreWrites=' + String(item.firestoreWrites || 0));
    lines.push('  publishToTarget=' + String(!!item.publishToTarget));
    lines.push('  targetPathBuilt=' + String(!!item.targetPathBuilt));
    lines.push('  cutover=' + String(!!item.cutover));
    lines.push('  lifecycleTouched=' + String(!!item.lifecycleTouched));
    lines.push('  violations=' + ((item.violations || []).length ? item.violations.join(',') : 'none'));
  });
  return lines.join('\n');
}
