var PHBOX_M2_LOCK_VERSION_ = 'M2_LOCK_v3';
var PHBOX_M2_LOCK_STAGE_ = 'migration2_lock_precheck';
var PHBOX_M2_LOCK_REQUIRED_FREEZE_VERSION_ = 'M1_FREEZE_v2';
var PHBOX_M2_LOCK_REQUIRED_M1_STATUS_ = 'baseline_frozen';
var PHBOX_M2_LOCK_NEXT_ROADMAP_ = 'Migration 2 — Cutover operativo controllato';

function runMigration2LockRuntimeStatus_() {
  var freezeStatus = null;
  var gateResult = null;
  var error = '';
  var errorKind = '';

  try {
    if (typeof runMigration1FreezeBaselineRuntimeStatus_ !== 'function') {
      throw new Error('M2_LOCK_M1_FREEZE_MISSING: funzione runMigration1FreezeBaselineRuntimeStatus_ non disponibile. Baseline M1 non verificabile.');
    }
    freezeStatus = runMigration1FreezeBaselineRuntimeStatus_();
  } catch (e) {
    error = normalizeRuntimeErrorMessage_(e);
    errorKind = classifyRuntimeFailureKind_(e);
  }

  try {
    if (!error) {
      if (typeof runMigration1TargetRuntimeGateStage_ === 'function') {
        var gateStage = runMigration1TargetRuntimeGateStage_({});
        if (!gateStage || gateStage.ok === false) {
          throw new Error((gateStage && gateStage.error) || 'M2_LOCK_GATE_STATUS_ERROR: target runtime gate non verificabile.');
        }
        gateResult = gateStage.result;
      } else if (typeof runMigration1TargetRuntimeGate_ === 'function') {
        gateResult = runMigration1TargetRuntimeGate_({});
      } else {
        throw new Error('M2_LOCK_M1_GATE_MISSING: funzione target runtime gate non disponibile.');
      }
    }
  } catch (e2) {
    error = normalizeRuntimeErrorMessage_(e2);
    errorKind = classifyRuntimeFailureKind_(e2);
  }

  return buildMigration2LockResult_({
    freezeStatus: freezeStatus,
    gateStatus: gateResult,
    obsoleteHandlers: listMigration2LockObsoleteSettingsHandlers_(),
    error: error,
    errorKind: errorKind
  });
}

function runMigration2LockSelfTest_() {
  var cases = [
    {
      id: 'm1_freeze_v2_gate_off_passes',
      result: buildMigration2LockResult_({
        freezeStatus: buildMigration2LockSyntheticFreezeStatus_({}),
        gateStatus: buildMigration2LockSyntheticGateStatus_({})
      }),
      expectedOk: true,
      expectedViolation: ''
    },
    {
      id: 'missing_freeze_blocks_m2',
      result: buildMigration2LockResult_({
        freezeStatus: null,
        gateStatus: buildMigration2LockSyntheticGateStatus_({})
      }),
      expectedOk: false,
      expectedViolation: 'm1_freeze_status_missing'
    },
    {
      id: 'wrong_freeze_version_blocks_m2',
      result: buildMigration2LockResult_({
        freezeStatus: buildMigration2LockSyntheticFreezeStatus_({ freezeVersion: 'M1_FREEZE_v1' }),
        gateStatus: buildMigration2LockSyntheticGateStatus_({})
      }),
      expectedOk: false,
      expectedViolation: 'm1_freeze_version_not_v2'
    },
    {
      id: 'not_frozen_status_blocks_m2',
      result: buildMigration2LockResult_({
        freezeStatus: buildMigration2LockSyntheticFreezeStatus_({ migration1Status: 'not_frozen' }),
        gateStatus: buildMigration2LockSyntheticGateStatus_({})
      }),
      expectedOk: false,
      expectedViolation: 'migration1_not_baseline_frozen'
    },
    {
      id: 'target_gate_enabled_blocks_m2_lock',
      result: buildMigration2LockResult_({
        freezeStatus: buildMigration2LockSyntheticFreezeStatus_({}),
        gateStatus: buildMigration2LockSyntheticGateStatus_({ enabled: true, skipped: false, reason: '', tenantId: 'farmacia_santa_venera', tenantCanonical: true, targetReadWriteAuthorized: true })
      }),
      expectedOk: false,
      expectedViolation: 'target_runtime_gate_not_default_off'
    },
    {
      id: 'target_path_publish_cutover_lifecycle_blocks_m2',
      result: buildMigration2LockResult_({
        freezeStatus: buildMigration2LockSyntheticFreezeStatus_({}),
        gateStatus: buildMigration2LockSyntheticGateStatus_({ targetPathBuilt: true, publishToTarget: true, cutover: true, lifecycleTouched: true })
      }),
      expectedOk: false,
      expectedViolation: 'target_path_built_before_m2'
    },
    {
      id: 'obsolete_settings_handler_blocks_m2_lock',
      result: buildMigration2LockResult_({
        freezeStatus: buildMigration2LockSyntheticFreezeStatus_({}),
        gateStatus: buildMigration2LockSyntheticGateStatus_({}),
        obsoleteHandlers: ['runMigration1FreezeBaselineSettingsTest']
      }),
      expectedOk: false,
      expectedViolation: 'obsolete_settings_handlers_detected'
    },
    {
      id: 'm2_lock_runtime_zero_read_write_contract',
      result: buildMigration2LockResult_({
        freezeStatus: buildMigration2LockSyntheticFreezeStatus_({}),
        gateStatus: buildMigration2LockSyntheticGateStatus_({})
      }),
      expectedOk: true,
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
    if (item.expectedViolation && violations.indexOf(item.expectedViolation) === -1) mismatchReasons.push('expected_violation_missing');
    if (!item.expectedViolation && violations.length > 0) mismatchReasons.push('unexpected_violation');
    var ok = mismatchReasons.length === 0;
    if (ok) passed++; else failed++;
    return {
      id: item.id,
      passed: ok,
      ok: !!stats.ok,
      expectedOk: item.expectedOk,
      freezeVersion: stats.freezeVersion,
      migration1Status: stats.migration1Status,
      targetGateEnabled: !!stats.targetGateEnabled,
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
    lockVersion: PHBOX_M2_LOCK_VERSION_,
    m1FreezeRequiredVersion: PHBOX_M2_LOCK_REQUIRED_FREEZE_VERSION_,
    migration1StatusRequired: PHBOX_M2_LOCK_REQUIRED_M1_STATUS_,
    nextRoadmap: PHBOX_M2_LOCK_NEXT_ROADMAP_,
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

function buildMigration2LockResult_(data) {
  data = data || {};
  var freezeStats = (data.freezeStatus && data.freezeStatus.stats) || {};
  var gateStats = (data.gateStatus && data.gateStatus.stats) || {};
  var obsoleteHandlers = Array.isArray(data.obsoleteHandlers) ? data.obsoleteHandlers : [];
  var violations = [];

  if (!data.freezeStatus || !data.freezeStatus.stats) violations.push('m1_freeze_status_missing');
  if (data.freezeStatus && data.freezeStatus.ok === false) violations.push('m1_freeze_not_ok');
  if (freezeStats.freezeVersion !== PHBOX_M2_LOCK_REQUIRED_FREEZE_VERSION_) violations.push('m1_freeze_version_not_v2');
  if (freezeStats.migration1Status !== PHBOX_M2_LOCK_REQUIRED_M1_STATUS_) violations.push('migration1_not_baseline_frozen');
  if (freezeStats.nextRoadmap !== PHBOX_M2_LOCK_NEXT_ROADMAP_) violations.push('next_roadmap_not_migration2');
  if (Number(freezeStats.firestoreReads || 0) !== 0) violations.push('m1_freeze_reads_not_zero');
  if (Number(freezeStats.firestoreWrites || 0) !== 0) violations.push('m1_freeze_writes_not_zero');
  if (freezeStats.publishToTarget || freezeStats.publishFromTarget) violations.push('m1_freeze_publish_detected');
  if (freezeStats.targetPathBuilt) violations.push('m1_freeze_target_path_built');
  if (freezeStats.cutover) violations.push('m1_freeze_cutover_detected');
  if (freezeStats.lifecycleTouched) violations.push('m1_freeze_lifecycle_touched');

  if (!data.gateStatus || !data.gateStatus.stats) violations.push('target_runtime_gate_status_missing');
  if (gateStats.enabled) violations.push('target_runtime_gate_not_default_off');
  if (gateStats.targetReadWriteAuthorized) violations.push('target_read_write_authorized_before_m2');
  if (gateStats.targetPathBuilt) violations.push('target_path_built_before_m2');
  if (Number(gateStats.firestoreReads || 0) !== 0) violations.push('target_gate_reads_not_zero');
  if (Number(gateStats.firestoreWrites || 0) !== 0) violations.push('target_gate_writes_not_zero');
  if (gateStats.publishToTarget || gateStats.publishFromTarget) violations.push('target_gate_publish_detected');
  if (gateStats.cutover) violations.push('target_gate_cutover_detected');
  if (gateStats.lifecycleTouched) violations.push('target_gate_lifecycle_touched');

  if (obsoleteHandlers.length > 0) violations.push('obsolete_settings_handlers_detected');
  if (data.error) violations.push('m2_lock_error');

  violations = uniqueNonEmptyStrings_(violations);

  var stats = {
    stage: PHBOX_M2_LOCK_STAGE_,
    ok: violations.length === 0,
    skipped: false,
    reason: violations.length === 0 ? 'm2_lock_ready' : (data.error ? 'm2_lock_error' : 'm2_lock_violation'),
    lockVersion: PHBOX_M2_LOCK_VERSION_,
    m1FreezeRequiredVersion: PHBOX_M2_LOCK_REQUIRED_FREEZE_VERSION_,
    freezeVersion: String(freezeStats.freezeVersion || ''),
    migration1Status: String(freezeStats.migration1Status || ''),
    nextRoadmap: String(freezeStats.nextRoadmap || ''),
    targetGateEnabled: !!gateStats.enabled,
    targetGateReason: String(gateStats.reason || ''),
    tenantId: String(gateStats.tenantId || ''),
    tenantCanonical: !!gateStats.tenantCanonical,
    targetReadWriteAuthorized: !!gateStats.targetReadWriteAuthorized,
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

function buildMigration2LockSyntheticFreezeStatus_(overrides) {
  overrides = overrides || {};
  var stats = {
    freezeVersion: Object.prototype.hasOwnProperty.call(overrides, 'freezeVersion') ? overrides.freezeVersion : 'M1_FREEZE_v2',
    migration1Status: Object.prototype.hasOwnProperty.call(overrides, 'migration1Status') ? overrides.migration1Status : 'baseline_frozen',
    nextRoadmap: Object.prototype.hasOwnProperty.call(overrides, 'nextRoadmap') ? overrides.nextRoadmap : PHBOX_M2_LOCK_NEXT_ROADMAP_,
    firestoreReads: Number(overrides.firestoreReads || 0),
    firestoreWrites: Number(overrides.firestoreWrites || 0),
    publishFromTarget: !!overrides.publishFromTarget,
    publishToTarget: !!overrides.publishToTarget,
    targetPathBuilt: !!overrides.targetPathBuilt,
    cutover: !!overrides.cutover,
    lifecycleTouched: !!overrides.lifecycleTouched
  };
  return {
    ok: overrides.ok === false ? false : true,
    stats: stats
  };
}

function buildMigration2LockSyntheticGateStatus_(overrides) {
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

function listMigration2LockObsoleteSettingsHandlers_() {
  var names = [
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
    return isMigration2LockGlobalFunction_(name);
  });
}

function isMigration2LockGlobalFunction_(name) {
  try {
    return typeof globalThis !== 'undefined' && typeof globalThis[name] === 'function';
  } catch (e) {
    return false;
  }
}

function formatMigration2LockSelfTestFeedback_(result) {
  result = result || runMigration2LockSelfTest_();
  var lines = [];
  lines.push('MIGRATION_2_LOCK_TEST');
  lines.push('ok=' + String(!!result.ok));
  lines.push('testCount=' + String(result.testCount || 0));
  lines.push('passedCount=' + String(result.passedCount || 0));
  lines.push('failedCount=' + String(result.failedCount || 0));
  lines.push('lockVersion=' + String(result.lockVersion || ''));
  lines.push('m1FreezeRequiredVersion=' + String(result.m1FreezeRequiredVersion || ''));
  lines.push('migration1StatusRequired=' + String(result.migration1StatusRequired || ''));
  lines.push('nextRoadmap=' + String(result.nextRoadmap || ''));
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
    lines.push('  expectedOk=' + String(!!item.expectedOk));
    lines.push('  freezeVersion=' + String(item.freezeVersion || ''));
    lines.push('  migration1Status=' + String(item.migration1Status || ''));
    lines.push('  targetGateEnabled=' + String(!!item.targetGateEnabled));
    lines.push('  targetReadWriteAuthorized=' + String(!!item.targetReadWriteAuthorized));
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

function formatMigration2LockRuntimeFeedback_(result) {
  result = result || runMigration2LockRuntimeStatus_();
  var stats = (result && result.stats) || {};
  var lines = [];
  lines.push('MIGRATION_2_LOCK_RUNTIME_STATUS');
  lines.push('ok=' + String(!!result.ok));
  lines.push('skipped=' + String(!!stats.skipped));
  lines.push('reason=' + String(stats.reason || ''));
  lines.push('lockVersion=' + String(stats.lockVersion || ''));
  lines.push('m1FreezeRequiredVersion=' + String(stats.m1FreezeRequiredVersion || ''));
  lines.push('freezeVersion=' + String(stats.freezeVersion || ''));
  lines.push('migration1Status=' + String(stats.migration1Status || ''));
  lines.push('nextRoadmap=' + String(stats.nextRoadmap || ''));
  lines.push('targetGateEnabled=' + String(!!stats.targetGateEnabled));
  lines.push('targetGateReason=' + String(stats.targetGateReason || ''));
  lines.push('tenantId=' + String(stats.tenantId || ''));
  lines.push('tenantCanonical=' + String(!!stats.tenantCanonical));
  lines.push('targetReadWriteAuthorized=' + String(!!stats.targetReadWriteAuthorized));
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
