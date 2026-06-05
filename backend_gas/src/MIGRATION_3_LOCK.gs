var PHBOX_M3_LOCK_VERSION_ = 'M3_LOCK_v1';
var PHBOX_M3_LOCK_STAGE_ = 'migration3_lock';
var PHBOX_M3_LOCK_REQUIRED_FREEZE_VERSION_ = 'M2_FREEZE_v1';
var PHBOX_M3_LOCK_REQUIRED_DOC_VERSION_ = 'M2_DOC_v2';
var PHBOX_M3_LOCK_REQUIRED_FINALCLEAN_VERSION_ = 'M2_FINALCLEAN_v3';
var PHBOX_M3_LOCK_REQUIRED_COST_VERSION_ = 'M2_COST_v3';
var PHBOX_M3_LOCK_REQUIRED_E2E_VERSION_ = 'M2_E2E_v1';

function runMigration3LockRuntimeStatus_() {
  try {
    if (typeof runMigration2FreezeRuntimeStatus_ !== 'function') {
      throw new Error('M3_LOCK_M2_FREEZE_MISSING: funzione runMigration2FreezeRuntimeStatus_ non disponibile. Avvio M3 non autorizzabile.');
    }
    return buildMigration3LockResult_({
      freezeStatus: runMigration2FreezeRuntimeStatus_(),
      obsoleteHandlers: listMigration3LockObsoleteSettingsHandlers_()
    });
  } catch (e) {
    return buildMigration3LockResult_({
      freezeStatus: null,
      obsoleteHandlers: listMigration3LockObsoleteSettingsHandlers_(),
      error: normalizeRuntimeErrorMessage_(e),
      errorKind: classifyRuntimeFailureKind_(e)
    });
  }
}

function buildMigration3LockResult_(data) {
  data = data || {};
  var freezeStatus = data.freezeStatus || null;
  var freezeStats = (freezeStatus && freezeStatus.stats) || {};
  var obsoleteHandlers = uniqueNonEmptyStrings_([].concat(
    freezeStats.obsoleteHandlers || [],
    data.obsoleteHandlers || []
  ));
  var statsInput = {
    ok: !!(freezeStatus && freezeStatus.ok) && freezeStats.ok !== false,
    skipped: false,
    reason: '',
    freezeVersion: String(freezeStats.freezeVersion || ''),
    docVersion: String(freezeStats.docVersion || ''),
    finalCleanVersion: String(freezeStats.finalCleanVersion || ''),
    costVersion: String(freezeStats.costVersion || ''),
    e2eVersion: String(freezeStats.e2eVersion || ''),
    docOk: !!freezeStats.docOk,
    frozen: !!freezeStats.frozen,
    firestoreReads: Math.max(0, Number(freezeStats.firestoreReads || 0)),
    firestoreWrites: Math.max(0, Number(freezeStats.firestoreWrites || 0)),
    estimatedReadsPerHour: Math.max(0, Number(freezeStats.estimatedReadsPerHour || 0)),
    estimatedWritesPerHour: Math.max(0, Number(freezeStats.estimatedWritesPerHour || 0)),
    targetWritesExecuted: Math.max(0, Number(freezeStats.targetWritesExecuted || 0)),
    listeners: Math.max(0, Number(freezeStats.listeners || 0)),
    queries: Math.max(0, Number(freezeStats.queries || 0)),
    fanOut: Math.max(0, Number(freezeStats.fanOut || 0)),
    publishFromTarget: !!freezeStats.publishFromTarget,
    publishToTarget: !!freezeStats.publishToTarget,
    targetPathBuilt: !!freezeStats.targetPathBuilt,
    cutover: !!freezeStats.cutover,
    lifecycleTouched: !!freezeStats.lifecycleTouched,
    tenantRegistryTouched: !!data.tenantRegistryTouched,
    tenantConfigTouched: !!data.tenantConfigTouched,
    authRuntimeChanged: !!data.authRuntimeChanged,
    tenantRoutingActive: !!data.tenantRoutingActive,
    tenantTargetPathBuilt: !!data.tenantTargetPathBuilt,
    schemaChanged: !!data.schemaChanged,
    contractChanged: !!data.contractChanged,
    obsoleteHandlers: obsoleteHandlers,
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };
  var violations = buildMigration3LockViolations_({
    freezePresent: !!(freezeStatus && freezeStatus.stats),
    freezeOk: statsInput.ok,
    freezeVersion: statsInput.freezeVersion,
    docVersion: statsInput.docVersion,
    finalCleanVersion: statsInput.finalCleanVersion,
    costVersion: statsInput.costVersion,
    e2eVersion: statsInput.e2eVersion,
    docOk: statsInput.docOk,
    frozen: statsInput.frozen,
    firestoreReads: statsInput.firestoreReads,
    firestoreWrites: statsInput.firestoreWrites,
    estimatedReadsPerHour: statsInput.estimatedReadsPerHour,
    estimatedWritesPerHour: statsInput.estimatedWritesPerHour,
    targetWritesExecuted: statsInput.targetWritesExecuted,
    listeners: statsInput.listeners,
    queries: statsInput.queries,
    fanOut: statsInput.fanOut,
    publishFromTarget: statsInput.publishFromTarget,
    publishToTarget: statsInput.publishToTarget,
    targetPathBuilt: statsInput.targetPathBuilt,
    cutover: statsInput.cutover,
    lifecycleTouched: statsInput.lifecycleTouched,
    tenantRegistryTouched: statsInput.tenantRegistryTouched,
    tenantConfigTouched: statsInput.tenantConfigTouched,
    authRuntimeChanged: statsInput.authRuntimeChanged,
    tenantRoutingActive: statsInput.tenantRoutingActive,
    tenantTargetPathBuilt: statsInput.tenantTargetPathBuilt,
    schemaChanged: statsInput.schemaChanged,
    contractChanged: statsInput.contractChanged,
    obsoleteHandlers: obsoleteHandlers,
    error: statsInput.error
  });
  statsInput.ok = violations.length === 0;
  statsInput.reason = violations.length ? 'm3_lock_violation' : 'm3_lock_ready';
  statsInput.violations = violations;
  return buildMigration3LockResultFromStats_(statsInput);
}

function buildMigration3LockViolations_(data) {
  data = data || {};
  var violations = [];
  if (!data.freezePresent) violations.push('m2_freeze_status_missing');
  if (data.freezePresent && !data.freezeOk) violations.push('m2_freeze_not_ok');
  if (String(data.freezeVersion || '') !== PHBOX_M3_LOCK_REQUIRED_FREEZE_VERSION_) violations.push('m2_freeze_version_mismatch');
  if (!data.frozen) violations.push('m2_baseline_not_frozen');
  if (String(data.docVersion || '') !== PHBOX_M3_LOCK_REQUIRED_DOC_VERSION_) violations.push('doc_version_mismatch');
  if (String(data.finalCleanVersion || '') !== PHBOX_M3_LOCK_REQUIRED_FINALCLEAN_VERSION_) violations.push('finalclean_version_mismatch');
  if (String(data.costVersion || '') !== PHBOX_M3_LOCK_REQUIRED_COST_VERSION_) violations.push('cost_version_mismatch');
  if (String(data.e2eVersion || '') !== PHBOX_M3_LOCK_REQUIRED_E2E_VERSION_) violations.push('e2e_version_mismatch');
  if (!data.docOk) violations.push('doc_not_ok');
  if (Number(data.firestoreReads || 0) > 0) violations.push('firestore_reads_detected');
  if (Number(data.firestoreWrites || 0) > 0) violations.push('firestore_writes_detected');
  if (Number(data.estimatedReadsPerHour || 0) > 0) violations.push('firestore_reads_per_hour_detected');
  if (Number(data.estimatedWritesPerHour || 0) > 0) violations.push('firestore_writes_per_hour_detected');
  if (Number(data.targetWritesExecuted || 0) > 0) violations.push('target_writes_executed');
  if (Number(data.listeners || 0) > 0) violations.push('listeners_detected');
  if (Number(data.queries || 0) > 0) violations.push('queries_detected');
  if (Number(data.fanOut || 0) > 0) violations.push('fanout_detected');
  if (data.publishFromTarget || data.publishToTarget) violations.push('publish_detected');
  if (data.targetPathBuilt) violations.push('target_path_built');
  if (data.cutover) violations.push('cutover_detected');
  if (data.lifecycleTouched) violations.push('lifecycle_touched');
  if (data.tenantRegistryTouched) violations.push('tenant_registry_touched');
  if (data.tenantConfigTouched) violations.push('tenant_config_touched');
  if (data.authRuntimeChanged) violations.push('auth_runtime_changed');
  if (data.tenantRoutingActive) violations.push('tenant_routing_active');
  if (data.tenantTargetPathBuilt) violations.push('tenant_target_path_built');
  if (data.schemaChanged) violations.push('schema_changed');
  if (data.contractChanged) violations.push('contract_changed');
  if (uniqueNonEmptyStrings_(data.obsoleteHandlers || []).length > 0) violations.push('obsolete_settings_handlers_detected');
  if (data.error) violations.push('m3_lock_error');
  return uniqueNonEmptyStrings_(violations);
}

function buildMigration3LockResultFromStats_(data) {
  data = data || {};
  var stats = buildMigration3LockStats_(data);
  return {
    ok: data.ok !== false,
    stats: stats,
    violations: uniqueNonEmptyStrings_(data.violations || []),
    items: data.items || []
  };
}

function buildMigration3LockStats_(data) {
  data = data || {};
  return {
    stage: PHBOX_M3_LOCK_STAGE_,
    ok: data.ok !== false,
    skipped: data.skipped !== false,
    reason: String(data.reason || ''),
    lockVersion: PHBOX_M3_LOCK_VERSION_,
    requiredFreezeVersion: PHBOX_M3_LOCK_REQUIRED_FREEZE_VERSION_,
    freezeVersion: String(data.freezeVersion || ''),
    requiredDocVersion: PHBOX_M3_LOCK_REQUIRED_DOC_VERSION_,
    docVersion: String(data.docVersion || ''),
    requiredFinalCleanVersion: PHBOX_M3_LOCK_REQUIRED_FINALCLEAN_VERSION_,
    finalCleanVersion: String(data.finalCleanVersion || ''),
    requiredCostVersion: PHBOX_M3_LOCK_REQUIRED_COST_VERSION_,
    costVersion: String(data.costVersion || ''),
    requiredE2eVersion: PHBOX_M3_LOCK_REQUIRED_E2E_VERSION_,
    e2eVersion: String(data.e2eVersion || ''),
    docOk: !!data.docOk,
    frozen: !!data.frozen,
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
    tenantRegistryTouched: !!data.tenantRegistryTouched,
    tenantConfigTouched: !!data.tenantConfigTouched,
    authRuntimeChanged: !!data.authRuntimeChanged,
    tenantRoutingActive: !!data.tenantRoutingActive,
    tenantTargetPathBuilt: !!data.tenantTargetPathBuilt,
    schemaChanged: !!data.schemaChanged,
    contractChanged: !!data.contractChanged,
    obsoleteHandlers: uniqueNonEmptyStrings_(data.obsoleteHandlers || []),
    violations: uniqueNonEmptyStrings_(data.violations || []),
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };
}

function listMigration3LockObsoleteSettingsHandlers_() {
  var names = [
    'runMigration2FreezeSettingsTest',
    'getMigration2FreezeSettingsStatus',
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

function runMigration3LockSelfTest_() {
  var cases = [
    {
      id: 'clean_m2_freeze_authorizes_m3_lock',
      result: buildMigration3LockResult_({ freezeStatus: buildMigration3LockSyntheticFreezeStatus_({}) }),
      expected: { ok: true, violation: '' }
    },
    {
      id: 'missing_m2_freeze_blocks_m3_lock',
      result: buildMigration3LockResult_({ freezeStatus: null }),
      expected: { ok: false, violation: 'm2_freeze_status_missing' }
    },
    {
      id: 'm2_freeze_not_ok_blocks_m3_lock',
      result: buildMigration3LockResult_({ freezeStatus: buildMigration3LockSyntheticFreezeStatus_({ ok: false }) }),
      expected: { ok: false, violation: 'm2_freeze_not_ok' }
    },
    {
      id: 'm2_freeze_version_mismatch_blocks_m3_lock',
      result: buildMigration3LockResult_({ freezeStatus: buildMigration3LockSyntheticFreezeStatus_({ freezeVersion: 'M2_FREEZE_v0' }) }),
      expected: { ok: false, violation: 'm2_freeze_version_mismatch' }
    },
    {
      id: 'm2_not_frozen_blocks_m3_lock',
      result: buildMigration3LockResult_({ freezeStatus: buildMigration3LockSyntheticFreezeStatus_({ frozen: false }) }),
      expected: { ok: false, violation: 'm2_baseline_not_frozen' }
    },
    {
      id: 'doc_version_mismatch_blocks_m3_lock',
      result: buildMigration3LockResult_({ freezeStatus: buildMigration3LockSyntheticFreezeStatus_({ docVersion: 'M2_DOC_v1' }) }),
      expected: { ok: false, violation: 'doc_version_mismatch' }
    },
    {
      id: 'finalclean_version_mismatch_blocks_m3_lock',
      result: buildMigration3LockResult_({ freezeStatus: buildMigration3LockSyntheticFreezeStatus_({ finalCleanVersion: 'M2_FINALCLEAN_v2' }) }),
      expected: { ok: false, violation: 'finalclean_version_mismatch' }
    },
    {
      id: 'cost_version_mismatch_blocks_m3_lock',
      result: buildMigration3LockResult_({ freezeStatus: buildMigration3LockSyntheticFreezeStatus_({ costVersion: 'M2_COST_v2' }) }),
      expected: { ok: false, violation: 'cost_version_mismatch' }
    },
    {
      id: 'e2e_version_mismatch_blocks_m3_lock',
      result: buildMigration3LockResult_({ freezeStatus: buildMigration3LockSyntheticFreezeStatus_({ e2eVersion: 'M2_E2E_v0' }) }),
      expected: { ok: false, violation: 'e2e_version_mismatch' }
    },
    {
      id: 'doc_not_ok_blocks_m3_lock',
      result: buildMigration3LockResult_({ freezeStatus: buildMigration3LockSyntheticFreezeStatus_({ docOk: false }) }),
      expected: { ok: false, violation: 'doc_not_ok' }
    },
    {
      id: 'firestore_read_blocks_m3_lock',
      result: buildMigration3LockResult_({ freezeStatus: buildMigration3LockSyntheticFreezeStatus_({ firestoreReads: 1, estimatedReadsPerHour: 1 }) }),
      expected: { ok: false, violation: 'firestore_reads_detected' }
    },
    {
      id: 'firestore_write_blocks_m3_lock',
      result: buildMigration3LockResult_({ freezeStatus: buildMigration3LockSyntheticFreezeStatus_({ firestoreWrites: 1, estimatedWritesPerHour: 1 }) }),
      expected: { ok: false, violation: 'firestore_writes_detected' }
    },
    {
      id: 'target_write_blocks_m3_lock',
      result: buildMigration3LockResult_({ freezeStatus: buildMigration3LockSyntheticFreezeStatus_({ targetWritesExecuted: 1 }) }),
      expected: { ok: false, violation: 'target_writes_executed' }
    },
    {
      id: 'publish_lifecycle_blocks_m3_lock',
      result: buildMigration3LockResult_({ freezeStatus: buildMigration3LockSyntheticFreezeStatus_({ publishToTarget: true, lifecycleTouched: true }) }),
      expected: { ok: false, violation: 'publish_detected' }
    },
    {
      id: 'listener_query_fanout_blocks_m3_lock',
      result: buildMigration3LockResult_({ freezeStatus: buildMigration3LockSyntheticFreezeStatus_({ listeners: 1, queries: 1, fanOut: 1 }) }),
      expected: { ok: false, violation: 'listeners_detected' }
    },
    {
      id: 'target_path_and_cutover_block_m3_lock',
      result: buildMigration3LockResult_({ freezeStatus: buildMigration3LockSyntheticFreezeStatus_({ targetPathBuilt: true, cutover: true }) }),
      expected: { ok: false, violation: 'target_path_built' }
    },
    {
      id: 'obsolete_settings_handler_blocks_m3_lock',
      result: buildMigration3LockResult_({ freezeStatus: buildMigration3LockSyntheticFreezeStatus_({}), obsoleteHandlers: ['runMigration2FreezeSettingsTest'] }),
      expected: { ok: false, violation: 'obsolete_settings_handlers_detected' }
    },
    {
      id: 'tenant_registry_or_config_touch_blocks_m3_lock',
      result: buildMigration3LockResult_({ freezeStatus: buildMigration3LockSyntheticFreezeStatus_({}), tenantRegistryTouched: true, tenantConfigTouched: true }),
      expected: { ok: false, violation: 'tenant_registry_touched' }
    },
    {
      id: 'auth_or_tenant_route_blocks_m3_lock',
      result: buildMigration3LockResult_({ freezeStatus: buildMigration3LockSyntheticFreezeStatus_({}), authRuntimeChanged: true, tenantRoutingActive: true, tenantTargetPathBuilt: true }),
      expected: { ok: false, violation: 'auth_runtime_changed' }
    },
    {
      id: 'schema_or_contract_change_blocks_m3_lock',
      result: buildMigration3LockResult_({ freezeStatus: buildMigration3LockSyntheticFreezeStatus_({}), schemaChanged: true, contractChanged: true }),
      expected: { ok: false, violation: 'schema_changed' }
    },
    {
      id: 'runtime_error_blocks_m3_lock',
      result: buildMigration3LockResult_({ freezeStatus: buildMigration3LockSyntheticFreezeStatus_({}), error: 'synthetic error', errorKind: 'synthetic' }),
      expected: { ok: false, violation: 'm3_lock_error' }
    }
  ];

  var items = cases.map(function (entry) {
    var stats = entry.result.stats || {};
    var violations = uniqueNonEmptyStrings_(stats.violations || []);
    var passed = !!stats.ok === !!entry.expected.ok;
    if (entry.expected.violation) passed = passed && violations.indexOf(entry.expected.violation) !== -1;
    return buildMigration3LockSelfTestItem_(entry.id, passed, stats);
  });
  var failed = items.filter(function (item) { return !item.passed; });
  return buildMigration3LockResultFromStats_({
    ok: failed.length === 0,
    skipped: false,
    reason: failed.length ? 'm3_lock_selftest_failed' : 'm3_lock_selftest_passed',
    freezeVersion: PHBOX_M3_LOCK_REQUIRED_FREEZE_VERSION_,
    docVersion: PHBOX_M3_LOCK_REQUIRED_DOC_VERSION_,
    finalCleanVersion: PHBOX_M3_LOCK_REQUIRED_FINALCLEAN_VERSION_,
    costVersion: PHBOX_M3_LOCK_REQUIRED_COST_VERSION_,
    e2eVersion: PHBOX_M3_LOCK_REQUIRED_E2E_VERSION_,
    docOk: true,
    frozen: true,
    items: items,
    violations: failed.map(function (item) { return item.id; })
  });
}

function buildMigration3LockSelfTestItem_(id, passed, stats) {
  stats = stats || {};
  return {
    id: String(id || ''),
    passed: !!passed,
    ok: !!stats.ok,
    reason: String(stats.reason || ''),
    lockVersion: String(stats.lockVersion || ''),
    freezeVersion: String(stats.freezeVersion || ''),
    docVersion: String(stats.docVersion || ''),
    finalCleanVersion: String(stats.finalCleanVersion || ''),
    costVersion: String(stats.costVersion || ''),
    e2eVersion: String(stats.e2eVersion || ''),
    docOk: !!stats.docOk,
    frozen: !!stats.frozen,
    firestoreReads: Math.max(0, Number(stats.firestoreReads || 0)),
    firestoreWrites: Math.max(0, Number(stats.firestoreWrites || 0)),
    estimatedReadsPerHour: Math.max(0, Number(stats.estimatedReadsPerHour || 0)),
    estimatedWritesPerHour: Math.max(0, Number(stats.estimatedWritesPerHour || 0)),
    targetWritesExecuted: Math.max(0, Number(stats.targetWritesExecuted || 0)),
    listeners: Math.max(0, Number(stats.listeners || 0)),
    queries: Math.max(0, Number(stats.queries || 0)),
    fanOut: Math.max(0, Number(stats.fanOut || 0)),
    publishFromTarget: !!stats.publishFromTarget,
    publishToTarget: !!stats.publishToTarget,
    targetPathBuilt: !!stats.targetPathBuilt,
    cutover: !!stats.cutover,
    lifecycleTouched: !!stats.lifecycleTouched,
    tenantRegistryTouched: !!stats.tenantRegistryTouched,
    tenantConfigTouched: !!stats.tenantConfigTouched,
    authRuntimeChanged: !!stats.authRuntimeChanged,
    tenantRoutingActive: !!stats.tenantRoutingActive,
    tenantTargetPathBuilt: !!stats.tenantTargetPathBuilt,
    schemaChanged: !!stats.schemaChanged,
    contractChanged: !!stats.contractChanged,
    violations: uniqueNonEmptyStrings_(stats.violations || [])
  };
}

function buildMigration3LockSyntheticFreezeStatus_(overrides) {
  overrides = overrides || {};
  var ok = overrides.ok !== false;
  return {
    ok: ok,
    stats: {
      stage: 'migration2_freeze',
      ok: ok,
      reason: ok ? 'm2_freeze_ready' : 'm2_freeze_violation',
      freezeVersion: String(overrides.freezeVersion || PHBOX_M3_LOCK_REQUIRED_FREEZE_VERSION_),
      docVersion: String(overrides.docVersion || PHBOX_M3_LOCK_REQUIRED_DOC_VERSION_),
      finalCleanVersion: String(overrides.finalCleanVersion || PHBOX_M3_LOCK_REQUIRED_FINALCLEAN_VERSION_),
      costVersion: String(overrides.costVersion || PHBOX_M3_LOCK_REQUIRED_COST_VERSION_),
      e2eVersion: String(overrides.e2eVersion || PHBOX_M3_LOCK_REQUIRED_E2E_VERSION_),
      docOk: overrides.docOk !== false,
      frozen: Object.prototype.hasOwnProperty.call(overrides, 'frozen') ? !!overrides.frozen : true,
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
      obsoleteHandlers: uniqueNonEmptyStrings_(overrides.obsoleteHandlers || []),
      violations: uniqueNonEmptyStrings_(overrides.violations || []),
      error: String(overrides.error || ''),
      errorKind: String(overrides.errorKind || '')
    },
    items: []
  };
}

function formatMigration3LockSelfTestFeedback_(result) {
  result = result || {};
  var stats = result.stats || {};
  var lines = [];
  var items = result.items || [];
  var passed = items.filter(function (item) { return !!item.passed; }).length;
  lines.push('MIGRATION_3_LOCK_TEST');
  lines.push('ok=' + String(!!result.ok));
  lines.push('testCount=' + String(items.length));
  lines.push('passedCount=' + String(passed));
  lines.push('failedCount=' + String(items.length - passed));
  migration3LockAppendCommonFeedbackLines_(lines, stats);
  lines.push('items=');
  items.forEach(function (item) {
    migration3LockAppendItemFeedbackLines_(lines, item);
  });
  return lines.join('\n');
}

function formatMigration3LockRuntimeFeedback_(result) {
  result = result || {};
  var stats = result.stats || {};
  var lines = [];
  lines.push('MIGRATION_3_LOCK_RUNTIME_STATUS');
  lines.push('ok=' + String(!!result.ok));
  lines.push('skipped=' + String(!!stats.skipped));
  migration3LockAppendCommonFeedbackLines_(lines, stats);
  lines.push('obsoleteHandlers=' + migration3LockJoinList_(stats.obsoleteHandlers));
  lines.push('violations=' + migration3LockJoinList_(stats.violations));
  lines.push('error=' + (stats.error || 'none'));
  lines.push('errorKind=' + (stats.errorKind || 'none'));
  return lines.join('\n');
}

function migration3LockAppendCommonFeedbackLines_(lines, stats) {
  stats = stats || {};
  lines.push('reason=' + String(stats.reason || ''));
  lines.push('lockVersion=' + String(stats.lockVersion || ''));
  lines.push('requiredFreezeVersion=' + String(stats.requiredFreezeVersion || ''));
  lines.push('freezeVersion=' + String(stats.freezeVersion || ''));
  lines.push('frozen=' + String(!!stats.frozen));
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
  lines.push('tenantRegistryTouched=' + String(!!stats.tenantRegistryTouched));
  lines.push('tenantConfigTouched=' + String(!!stats.tenantConfigTouched));
  lines.push('authRuntimeChanged=' + String(!!stats.authRuntimeChanged));
  lines.push('tenantRoutingActive=' + String(!!stats.tenantRoutingActive));
  lines.push('tenantTargetPathBuilt=' + String(!!stats.tenantTargetPathBuilt));
  lines.push('schemaChanged=' + String(!!stats.schemaChanged));
  lines.push('contractChanged=' + String(!!stats.contractChanged));
}

function migration3LockAppendItemFeedbackLines_(lines, item) {
  item = item || {};
  lines.push('- id=' + String(item.id || ''));
  lines.push('  passed=' + String(!!item.passed));
  lines.push('  ok=' + String(!!item.ok));
  lines.push('  reason=' + String(item.reason || ''));
  lines.push('  lockVersion=' + String(item.lockVersion || ''));
  lines.push('  freezeVersion=' + String(item.freezeVersion || ''));
  lines.push('  frozen=' + String(!!item.frozen));
  lines.push('  docVersion=' + String(item.docVersion || ''));
  lines.push('  finalCleanVersion=' + String(item.finalCleanVersion || ''));
  lines.push('  costVersion=' + String(item.costVersion || ''));
  lines.push('  e2eVersion=' + String(item.e2eVersion || ''));
  lines.push('  docOk=' + String(!!item.docOk));
  lines.push('  firestoreReads=' + String(Math.max(0, Number(item.firestoreReads || 0))));
  lines.push('  firestoreWrites=' + String(Math.max(0, Number(item.firestoreWrites || 0))));
  lines.push('  estimatedReadsPerHour=' + String(Math.max(0, Number(item.estimatedReadsPerHour || 0))));
  lines.push('  estimatedWritesPerHour=' + String(Math.max(0, Number(item.estimatedWritesPerHour || 0))));
  lines.push('  targetWritesExecuted=' + String(Math.max(0, Number(item.targetWritesExecuted || 0))));
  lines.push('  listeners=' + String(Math.max(0, Number(item.listeners || 0))));
  lines.push('  queries=' + String(Math.max(0, Number(item.queries || 0))));
  lines.push('  fanOut=' + String(Math.max(0, Number(item.fanOut || 0))));
  lines.push('  publishFromTarget=' + String(!!item.publishFromTarget));
  lines.push('  publishToTarget=' + String(!!item.publishToTarget));
  lines.push('  targetPathBuilt=' + String(!!item.targetPathBuilt));
  lines.push('  cutover=' + String(!!item.cutover));
  lines.push('  lifecycleTouched=' + String(!!item.lifecycleTouched));
  lines.push('  tenantRegistryTouched=' + String(!!item.tenantRegistryTouched));
  lines.push('  tenantConfigTouched=' + String(!!item.tenantConfigTouched));
  lines.push('  authRuntimeChanged=' + String(!!item.authRuntimeChanged));
  lines.push('  tenantRoutingActive=' + String(!!item.tenantRoutingActive));
  lines.push('  tenantTargetPathBuilt=' + String(!!item.tenantTargetPathBuilt));
  lines.push('  schemaChanged=' + String(!!item.schemaChanged));
  lines.push('  contractChanged=' + String(!!item.contractChanged));
  lines.push('  violations=' + migration3LockJoinList_(item.violations));
}

function migration3LockJoinList_(value) {
  var items = uniqueNonEmptyStrings_(value || []);
  return items.length ? items.join(',') : 'none';
}
