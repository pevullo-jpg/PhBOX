var PHBOX_M3_COST_GUARD_VERSION_ = 'M3_COST_GUARD_v1';
var PHBOX_M3_COST_GUARD_STAGE_ = 'migration3_cost_guard';
var PHBOX_M3_COST_GUARD_REQUIRED_CONFIG_VERSION_ = 'M3_TENANT_CONFIG_v1';
var PHBOX_M3_COST_GUARD_OWNER_ = 'backend_gas_diagnostic_only';
var PHBOX_M3_COST_GUARD_POLICY_ = 'zero_runtime_cost_before_m3_auth_route';
var PHBOX_M3_COST_GUARD_MODE_ = 'pre_auth_pre_route_cost_gate';
var PHBOX_M3_COST_GUARD_LIMITS_ = {
  maxFirestoreReads: 0,
  maxFirestoreWrites: 0,
  maxEstimatedReadsPerHour: 0,
  maxEstimatedWritesPerHour: 0,
  maxRegistryReads: 0,
  maxRegistryWrites: 0,
  maxConfigReads: 0,
  maxConfigWrites: 0,
  maxTargetWritesExecuted: 0,
  maxListeners: 0,
  maxQueries: 0,
  maxFanOut: 0
};

function runMigration3CostGuardRuntimeStatus_() {
  try {
    if (typeof runMigration3TenantConfigRuntimeStatus_ !== 'function') {
      throw new Error('M3_COST_GUARD_TENANT_CONFIG_MISSING: funzione runMigration3TenantConfigRuntimeStatus_ non disponibile. Cost guard non autorizzabile.');
    }
    return buildMigration3CostGuardResult_({
      configStatus: runMigration3TenantConfigRuntimeStatus_(),
      contract: buildMigration3CostGuardContract_(),
      obsoleteHandlers: listMigration3CostGuardObsoleteSettingsHandlers_()
    });
  } catch (e) {
    return buildMigration3CostGuardResult_({
      configStatus: null,
      contract: buildMigration3CostGuardContract_(),
      obsoleteHandlers: listMigration3CostGuardObsoleteSettingsHandlers_(),
      error: normalizeRuntimeErrorMessage_(e),
      errorKind: classifyRuntimeFailureKind_(e)
    });
  }
}

function buildMigration3CostGuardContract_() {
  return {
    costGuardVersion: PHBOX_M3_COST_GUARD_VERSION_,
    requiredConfigVersion: PHBOX_M3_COST_GUARD_REQUIRED_CONFIG_VERSION_,
    costGuardOwner: PHBOX_M3_COST_GUARD_OWNER_,
    costPolicy: PHBOX_M3_COST_GUARD_POLICY_,
    guardMode: PHBOX_M3_COST_GUARD_MODE_,
    limitsDeclared: true,
    limits: Object.assign({}, PHBOX_M3_COST_GUARD_LIMITS_),
    firestoreReads: 0,
    firestoreWrites: 0,
    estimatedReadsPerHour: 0,
    estimatedWritesPerHour: 0,
    registryReads: 0,
    registryWrites: 0,
    configReads: 0,
    configWrites: 0,
    targetWritesExecuted: 0,
    listeners: 0,
    queries: 0,
    fanOut: 0,
    targetPathBuilt: false,
    tenantTargetPathBuilt: false,
    tenantConfigTouched: false,
    lifecycleTouched: false,
    authRuntimeChanged: false,
    tenantRoutingActive: false,
    schemaChanged: false,
    runtimeContractChanged: false
  };
}

function buildMigration3CostGuardResult_(data) {
  data = data || {};
  var configStatus = data.configStatus || null;
  var configStats = (configStatus && configStatus.stats) || {};
  var contract = data.contract || {};
  var limits = Object.assign({}, PHBOX_M3_COST_GUARD_LIMITS_, contract.limits || {}, data.limits || {});
  var obsoleteHandlers = uniqueNonEmptyStrings_([].concat(
    configStats.obsoleteHandlers || [],
    data.obsoleteHandlers || []
  ));
  var statsInput = {
    ok: !!(configStatus && configStatus.ok) && configStats.ok !== false,
    skipped: false,
    reason: '',
    configVersion: String(configStats.configVersion || ''),
    registryVersion: String(configStats.registryVersion || ''),
    registryPathPattern: String(configStats.registryPathPattern || ''),
    configPathPattern: String(configStats.configPathPattern || ''),
    costGuardVersion: String(contract.costGuardVersion || ''),
    requiredConfigVersion: String(contract.requiredConfigVersion || ''),
    costGuardOwner: String(contract.costGuardOwner || ''),
    costPolicy: String(contract.costPolicy || ''),
    guardMode: String(contract.guardMode || ''),
    limitsDeclared: !!contract.limitsDeclared,
    limits: buildMigration3CostGuardLimits_(limits),
    firestoreReads: Math.max(0, Number(configStats.firestoreReads || 0) + Number(contract.firestoreReads || 0) + Number(data.firestoreReads || 0)),
    firestoreWrites: Math.max(0, Number(configStats.firestoreWrites || 0) + Number(contract.firestoreWrites || 0) + Number(data.firestoreWrites || 0)),
    estimatedReadsPerHour: Math.max(0, Number(configStats.estimatedReadsPerHour || 0) + Number(contract.estimatedReadsPerHour || 0) + Number(data.estimatedReadsPerHour || 0)),
    estimatedWritesPerHour: Math.max(0, Number(configStats.estimatedWritesPerHour || 0) + Number(contract.estimatedWritesPerHour || 0) + Number(data.estimatedWritesPerHour || 0)),
    registryReads: Math.max(0, Number(configStats.registryReads || 0) + Number(contract.registryReads || 0) + Number(data.registryReads || 0)),
    registryWrites: Math.max(0, Number(configStats.registryWrites || 0) + Number(contract.registryWrites || 0) + Number(data.registryWrites || 0)),
    configReads: Math.max(0, Number(configStats.configReads || 0) + Number(contract.configReads || 0) + Number(data.configReads || 0)),
    configWrites: Math.max(0, Number(configStats.configWrites || 0) + Number(contract.configWrites || 0) + Number(data.configWrites || 0)),
    targetWritesExecuted: Math.max(0, Number(configStats.targetWritesExecuted || 0) + Number(contract.targetWritesExecuted || 0) + Number(data.targetWritesExecuted || 0)),
    listeners: Math.max(0, Number(configStats.listeners || 0) + Number(contract.listeners || 0) + Number(data.listeners || 0)),
    queries: Math.max(0, Number(configStats.queries || 0) + Number(contract.queries || 0) + Number(data.queries || 0)),
    fanOut: Math.max(0, Number(configStats.fanOut || 0) + Number(contract.fanOut || 0) + Number(data.fanOut || 0)),
    targetPathBuilt: !!configStats.targetPathBuilt || !!contract.targetPathBuilt || !!data.targetPathBuilt,
    tenantTargetPathBuilt: !!configStats.tenantTargetPathBuilt || !!contract.tenantTargetPathBuilt || !!data.tenantTargetPathBuilt,
    tenantConfigTouched: !!configStats.tenantConfigTouched || !!contract.tenantConfigTouched || !!data.tenantConfigTouched,
    lifecycleTouched: !!configStats.lifecycleTouched || !!contract.lifecycleTouched || !!data.lifecycleTouched,
    authRuntimeChanged: !!configStats.authRuntimeChanged || !!contract.authRuntimeChanged || !!data.authRuntimeChanged,
    tenantRoutingActive: !!configStats.tenantRoutingActive || !!contract.tenantRoutingActive || !!data.tenantRoutingActive,
    schemaChanged: !!configStats.schemaChanged || !!contract.schemaChanged || !!data.schemaChanged,
    runtimeContractChanged: !!configStats.runtimeContractChanged || !!contract.runtimeContractChanged || !!data.runtimeContractChanged,
    obsoleteHandlers: obsoleteHandlers,
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };
  var violations = buildMigration3CostGuardViolations_({
    configPresent: !!(configStatus && configStatus.stats),
    configOk: statsInput.ok,
    configVersion: statsInput.configVersion,
    costGuardVersion: statsInput.costGuardVersion,
    requiredConfigVersion: statsInput.requiredConfigVersion,
    costGuardOwner: statsInput.costGuardOwner,
    costPolicy: statsInput.costPolicy,
    guardMode: statsInput.guardMode,
    limitsDeclared: statsInput.limitsDeclared,
    limits: statsInput.limits,
    firestoreReads: statsInput.firestoreReads,
    firestoreWrites: statsInput.firestoreWrites,
    estimatedReadsPerHour: statsInput.estimatedReadsPerHour,
    estimatedWritesPerHour: statsInput.estimatedWritesPerHour,
    registryReads: statsInput.registryReads,
    registryWrites: statsInput.registryWrites,
    configReads: statsInput.configReads,
    configWrites: statsInput.configWrites,
    targetWritesExecuted: statsInput.targetWritesExecuted,
    listeners: statsInput.listeners,
    queries: statsInput.queries,
    fanOut: statsInput.fanOut,
    targetPathBuilt: statsInput.targetPathBuilt,
    tenantTargetPathBuilt: statsInput.tenantTargetPathBuilt,
    tenantConfigTouched: statsInput.tenantConfigTouched,
    lifecycleTouched: statsInput.lifecycleTouched,
    authRuntimeChanged: statsInput.authRuntimeChanged,
    tenantRoutingActive: statsInput.tenantRoutingActive,
    schemaChanged: statsInput.schemaChanged,
    runtimeContractChanged: statsInput.runtimeContractChanged,
    obsoleteHandlers: obsoleteHandlers,
    error: statsInput.error
  });
  statsInput.ok = violations.length === 0;
  statsInput.reason = violations.length ? 'm3_cost_guard_violation' : 'm3_cost_guard_ready';
  statsInput.violations = violations;
  return buildMigration3CostGuardResultFromStats_(statsInput);
}

function buildMigration3CostGuardLimits_(limits) {
  limits = limits || {};
  return {
    maxFirestoreReads: Math.max(0, Number(limits.maxFirestoreReads || 0)),
    maxFirestoreWrites: Math.max(0, Number(limits.maxFirestoreWrites || 0)),
    maxEstimatedReadsPerHour: Math.max(0, Number(limits.maxEstimatedReadsPerHour || 0)),
    maxEstimatedWritesPerHour: Math.max(0, Number(limits.maxEstimatedWritesPerHour || 0)),
    maxRegistryReads: Math.max(0, Number(limits.maxRegistryReads || 0)),
    maxRegistryWrites: Math.max(0, Number(limits.maxRegistryWrites || 0)),
    maxConfigReads: Math.max(0, Number(limits.maxConfigReads || 0)),
    maxConfigWrites: Math.max(0, Number(limits.maxConfigWrites || 0)),
    maxTargetWritesExecuted: Math.max(0, Number(limits.maxTargetWritesExecuted || 0)),
    maxListeners: Math.max(0, Number(limits.maxListeners || 0)),
    maxQueries: Math.max(0, Number(limits.maxQueries || 0)),
    maxFanOut: Math.max(0, Number(limits.maxFanOut || 0))
  };
}

function buildMigration3CostGuardViolations_(data) {
  data = data || {};
  var limits = buildMigration3CostGuardLimits_(data.limits || {});
  var violations = [];
  if (!data.configPresent) violations.push('m3_tenant_config_status_missing');
  if (data.configPresent && !data.configOk) violations.push('m3_tenant_config_not_ok');
  if (String(data.configVersion || '') !== PHBOX_M3_COST_GUARD_REQUIRED_CONFIG_VERSION_) violations.push('m3_tenant_config_version_mismatch');
  if (String(data.costGuardVersion || '') !== PHBOX_M3_COST_GUARD_VERSION_) violations.push('cost_guard_version_mismatch');
  if (String(data.requiredConfigVersion || '') !== PHBOX_M3_COST_GUARD_REQUIRED_CONFIG_VERSION_) violations.push('required_config_version_mismatch');
  if (String(data.costGuardOwner || '') !== PHBOX_M3_COST_GUARD_OWNER_) violations.push('cost_guard_owner_mismatch');
  if (String(data.costPolicy || '') !== PHBOX_M3_COST_GUARD_POLICY_) violations.push('cost_policy_mismatch');
  if (String(data.guardMode || '') !== PHBOX_M3_COST_GUARD_MODE_) violations.push('guard_mode_mismatch');
  if (!data.limitsDeclared) violations.push('cost_limits_not_declared');
  migration3CostGuardLimitNames_().forEach(function (name) {
    if (Number(limits[name] || 0) !== Number(PHBOX_M3_COST_GUARD_LIMITS_[name] || 0)) violations.push(name + '_mismatch');
  });
  if (Number(data.firestoreReads || 0) > limits.maxFirestoreReads) violations.push('firestore_reads_detected');
  if (Number(data.firestoreWrites || 0) > limits.maxFirestoreWrites) violations.push('firestore_writes_detected');
  if (Number(data.estimatedReadsPerHour || 0) > limits.maxEstimatedReadsPerHour) violations.push('firestore_reads_per_hour_detected');
  if (Number(data.estimatedWritesPerHour || 0) > limits.maxEstimatedWritesPerHour) violations.push('firestore_writes_per_hour_detected');
  if (Number(data.registryReads || 0) > limits.maxRegistryReads) violations.push('registry_reads_detected');
  if (Number(data.registryWrites || 0) > limits.maxRegistryWrites) violations.push('registry_writes_detected');
  if (Number(data.configReads || 0) > limits.maxConfigReads) violations.push('config_reads_detected');
  if (Number(data.configWrites || 0) > limits.maxConfigWrites) violations.push('config_writes_detected');
  if (Number(data.targetWritesExecuted || 0) > limits.maxTargetWritesExecuted) violations.push('target_writes_executed');
  if (Number(data.listeners || 0) > limits.maxListeners) violations.push('listeners_detected');
  if (Number(data.queries || 0) > limits.maxQueries) violations.push('queries_detected');
  if (Number(data.fanOut || 0) > limits.maxFanOut) violations.push('fanout_detected');
  if (data.targetPathBuilt) violations.push('target_path_built');
  if (data.tenantTargetPathBuilt) violations.push('tenant_target_path_built');
  if (data.tenantConfigTouched) violations.push('tenant_config_touched');
  if (data.lifecycleTouched) violations.push('lifecycle_touched');
  if (data.authRuntimeChanged) violations.push('auth_runtime_changed');
  if (data.tenantRoutingActive) violations.push('tenant_routing_active');
  if (data.schemaChanged) violations.push('schema_changed');
  if (data.runtimeContractChanged) violations.push('runtime_contract_changed');
  if (uniqueNonEmptyStrings_(data.obsoleteHandlers || []).length > 0) violations.push('obsolete_settings_handlers_detected');
  if (data.error) violations.push('m3_cost_guard_error');
  return uniqueNonEmptyStrings_(violations);
}

function migration3CostGuardLimitNames_() {
  return [
    'maxFirestoreReads',
    'maxFirestoreWrites',
    'maxEstimatedReadsPerHour',
    'maxEstimatedWritesPerHour',
    'maxRegistryReads',
    'maxRegistryWrites',
    'maxConfigReads',
    'maxConfigWrites',
    'maxTargetWritesExecuted',
    'maxListeners',
    'maxQueries',
    'maxFanOut'
  ];
}

function buildMigration3CostGuardResultFromStats_(data) {
  data = data || {};
  var stats = buildMigration3CostGuardStats_(data);
  return {
    ok: data.ok !== false,
    stats: stats,
    violations: uniqueNonEmptyStrings_(data.violations || []),
    items: data.items || []
  };
}

function buildMigration3CostGuardStats_(data) {
  data = data || {};
  var limits = buildMigration3CostGuardLimits_(data.limits || {});
  return {
    stage: PHBOX_M3_COST_GUARD_STAGE_,
    ok: data.ok !== false,
    skipped: data.skipped !== false,
    reason: String(data.reason || ''),
    costGuardVersion: String(data.costGuardVersion || ''),
    requiredConfigVersion: PHBOX_M3_COST_GUARD_REQUIRED_CONFIG_VERSION_,
    configVersion: String(data.configVersion || ''),
    registryVersion: String(data.registryVersion || ''),
    registryPathPattern: String(data.registryPathPattern || ''),
    configPathPattern: String(data.configPathPattern || ''),
    costGuardOwner: String(data.costGuardOwner || ''),
    costPolicy: String(data.costPolicy || ''),
    guardMode: String(data.guardMode || ''),
    limitsDeclared: !!data.limitsDeclared,
    limits: limits,
    firestoreReads: Math.max(0, Number(data.firestoreReads || 0)),
    firestoreWrites: Math.max(0, Number(data.firestoreWrites || 0)),
    estimatedReadsPerHour: Math.max(0, Number(data.estimatedReadsPerHour || 0)),
    estimatedWritesPerHour: Math.max(0, Number(data.estimatedWritesPerHour || 0)),
    registryReads: Math.max(0, Number(data.registryReads || 0)),
    registryWrites: Math.max(0, Number(data.registryWrites || 0)),
    configReads: Math.max(0, Number(data.configReads || 0)),
    configWrites: Math.max(0, Number(data.configWrites || 0)),
    targetWritesExecuted: Math.max(0, Number(data.targetWritesExecuted || 0)),
    listeners: Math.max(0, Number(data.listeners || 0)),
    queries: Math.max(0, Number(data.queries || 0)),
    fanOut: Math.max(0, Number(data.fanOut || 0)),
    targetPathBuilt: !!data.targetPathBuilt,
    tenantTargetPathBuilt: !!data.tenantTargetPathBuilt,
    tenantConfigTouched: !!data.tenantConfigTouched,
    lifecycleTouched: !!data.lifecycleTouched,
    authRuntimeChanged: !!data.authRuntimeChanged,
    tenantRoutingActive: !!data.tenantRoutingActive,
    schemaChanged: !!data.schemaChanged,
    runtimeContractChanged: !!data.runtimeContractChanged,
    obsoleteHandlers: uniqueNonEmptyStrings_(data.obsoleteHandlers || []),
    violations: uniqueNonEmptyStrings_(data.violations || []),
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };
}

function listMigration3CostGuardObsoleteSettingsHandlers_() {
  var obsolete = [
    'runMigration3TenantConfigSettingsTest',
    'getMigration3TenantConfigSettingsStatus',
    'runMigration3TenantRegistrySettingsTest',
    'getMigration3TenantRegistrySettingsStatus',
    'runMigration3LockSettingsTest',
    'getMigration3LockSettingsStatus'
  ].filter(function (name) {
    try {
      if (typeof globalThis !== 'undefined' && typeof globalThis[name] === 'function') return true;
      return typeof this !== 'undefined' && typeof this[name] === 'function';
    } catch (e) {
      return false;
    }
  });
  if (typeof listMigration3TenantConfigObsoleteSettingsHandlers_ === 'function') {
    obsolete = obsolete.concat(listMigration3TenantConfigObsoleteSettingsHandlers_());
  }
  return uniqueNonEmptyStrings_(obsolete);
}

function runMigration3CostGuardSelfTest_() {
  var cleanContract = buildMigration3CostGuardContract_();
  var cases = [
    {
      id: 'clean_tenant_config_authorizes_cost_guard',
      result: buildMigration3CostGuardResult_({ configStatus: buildMigration3CostGuardSyntheticConfigStatus_({}), contract: cleanContract }),
      expected: { ok: true, violation: '' }
    },
    {
      id: 'missing_tenant_config_blocks_cost_guard',
      result: buildMigration3CostGuardResult_({ configStatus: null, contract: cleanContract }),
      expected: { ok: false, violation: 'm3_tenant_config_status_missing' }
    },
    {
      id: 'tenant_config_not_ok_blocks_cost_guard',
      result: buildMigration3CostGuardResult_({ configStatus: buildMigration3CostGuardSyntheticConfigStatus_({ ok: false }), contract: cleanContract }),
      expected: { ok: false, violation: 'm3_tenant_config_not_ok' }
    },
    {
      id: 'tenant_config_version_mismatch_blocks_cost_guard',
      result: buildMigration3CostGuardResult_({ configStatus: buildMigration3CostGuardSyntheticConfigStatus_({ configVersion: 'M3_TENANT_CONFIG_v0' }), contract: cleanContract }),
      expected: { ok: false, violation: 'm3_tenant_config_version_mismatch' }
    },
    {
      id: 'cost_guard_version_mismatch_blocks_cost_guard',
      result: buildMigration3CostGuardResult_({ configStatus: buildMigration3CostGuardSyntheticConfigStatus_({}), contract: migration3CostGuardSyntheticContract_({ costGuardVersion: 'M3_COST_GUARD_v0' }) }),
      expected: { ok: false, violation: 'cost_guard_version_mismatch' }
    },
    {
      id: 'cost_limits_mismatch_blocks_cost_guard',
      result: buildMigration3CostGuardResult_({ configStatus: buildMigration3CostGuardSyntheticConfigStatus_({}), contract: migration3CostGuardSyntheticContract_({ limits: { maxFirestoreReads: 1 } }) }),
      expected: { ok: false, violation: 'maxFirestoreReads_mismatch' }
    },
    {
      id: 'firestore_read_or_write_blocks_cost_guard',
      result: buildMigration3CostGuardResult_({ configStatus: buildMigration3CostGuardSyntheticConfigStatus_({ firestoreReads: 1, firestoreWrites: 1 }), contract: cleanContract }),
      expected: { ok: false, violation: 'firestore_reads_detected' }
    },
    {
      id: 'estimated_read_or_write_blocks_cost_guard',
      result: buildMigration3CostGuardResult_({ configStatus: buildMigration3CostGuardSyntheticConfigStatus_({ estimatedReadsPerHour: 1, estimatedWritesPerHour: 1 }), contract: cleanContract }),
      expected: { ok: false, violation: 'firestore_reads_per_hour_detected' }
    },
    {
      id: 'registry_or_config_read_write_blocks_cost_guard',
      result: buildMigration3CostGuardResult_({ configStatus: buildMigration3CostGuardSyntheticConfigStatus_({ registryReads: 1, registryWrites: 1, configReads: 1, configWrites: 1 }), contract: cleanContract }),
      expected: { ok: false, violation: 'registry_reads_detected' }
    },
    {
      id: 'listener_query_fanout_blocks_cost_guard',
      result: buildMigration3CostGuardResult_({ configStatus: buildMigration3CostGuardSyntheticConfigStatus_({ listeners: 1, queries: 1, fanOut: 1 }), contract: cleanContract }),
      expected: { ok: false, violation: 'listeners_detected' }
    },
    {
      id: 'target_path_blocks_cost_guard',
      result: buildMigration3CostGuardResult_({ configStatus: buildMigration3CostGuardSyntheticConfigStatus_({ targetPathBuilt: true, tenantTargetPathBuilt: true }), contract: cleanContract }),
      expected: { ok: false, violation: 'target_path_built' }
    },
    {
      id: 'tenant_config_touch_blocks_cost_guard',
      result: buildMigration3CostGuardResult_({ configStatus: buildMigration3CostGuardSyntheticConfigStatus_({ tenantConfigTouched: true }), contract: cleanContract }),
      expected: { ok: false, violation: 'tenant_config_touched' }
    },
    {
      id: 'lifecycle_blocks_cost_guard',
      result: buildMigration3CostGuardResult_({ configStatus: buildMigration3CostGuardSyntheticConfigStatus_({ lifecycleTouched: true }), contract: cleanContract }),
      expected: { ok: false, violation: 'lifecycle_touched' }
    },
    {
      id: 'auth_or_route_blocks_cost_guard',
      result: buildMigration3CostGuardResult_({ configStatus: buildMigration3CostGuardSyntheticConfigStatus_({ authRuntimeChanged: true, tenantRoutingActive: true }), contract: cleanContract }),
      expected: { ok: false, violation: 'auth_runtime_changed' }
    },
    {
      id: 'schema_or_runtime_contract_blocks_cost_guard',
      result: buildMigration3CostGuardResult_({ configStatus: buildMigration3CostGuardSyntheticConfigStatus_({ schemaChanged: true, runtimeContractChanged: true }), contract: cleanContract }),
      expected: { ok: false, violation: 'schema_changed' }
    },
    {
      id: 'obsolete_settings_handler_blocks_cost_guard',
      result: buildMigration3CostGuardResult_({ configStatus: buildMigration3CostGuardSyntheticConfigStatus_({}), contract: cleanContract, obsoleteHandlers: ['runMigration3TenantConfigSettingsTest'] }),
      expected: { ok: false, violation: 'obsolete_settings_handlers_detected' }
    },
    {
      id: 'runtime_error_blocks_cost_guard',
      result: buildMigration3CostGuardResult_({ configStatus: buildMigration3CostGuardSyntheticConfigStatus_({}), contract: cleanContract, error: 'synthetic error', errorKind: 'synthetic' }),
      expected: { ok: false, violation: 'm3_cost_guard_error' }
    }
  ];

  var items = cases.map(function (entry) {
    var stats = entry.result.stats || {};
    var violations = uniqueNonEmptyStrings_(stats.violations || []);
    var passed = !!stats.ok === !!entry.expected.ok;
    if (entry.expected.violation) passed = passed && violations.indexOf(entry.expected.violation) !== -1;
    return buildMigration3CostGuardSelfTestItem_(entry.id, passed, stats);
  });
  var failed = items.filter(function (item) { return !item.passed; });
  return buildMigration3CostGuardResultFromStats_({
    ok: failed.length === 0,
    skipped: false,
    reason: failed.length ? 'm3_cost_guard_selftest_failed' : 'm3_cost_guard_selftest_passed',
    costGuardVersion: PHBOX_M3_COST_GUARD_VERSION_,
    requiredConfigVersion: PHBOX_M3_COST_GUARD_REQUIRED_CONFIG_VERSION_,
    configVersion: PHBOX_M3_COST_GUARD_REQUIRED_CONFIG_VERSION_,
    registryVersion: 'M3_TENANT_REGISTRY_v1',
    registryPathPattern: 'tenant_registry/{tenantId}',
    configPathPattern: 'tenant_configs/{tenantId}',
    costGuardOwner: PHBOX_M3_COST_GUARD_OWNER_,
    costPolicy: PHBOX_M3_COST_GUARD_POLICY_,
    guardMode: PHBOX_M3_COST_GUARD_MODE_,
    limitsDeclared: true,
    limits: PHBOX_M3_COST_GUARD_LIMITS_,
    items: items,
    violations: failed.map(function (item) { return item.id; })
  });
}

function buildMigration3CostGuardSelfTestItem_(id, passed, stats) {
  stats = stats || {};
  return {
    id: String(id || ''),
    passed: !!passed,
    ok: !!stats.ok,
    reason: String(stats.reason || ''),
    costGuardVersion: String(stats.costGuardVersion || ''),
    configVersion: String(stats.configVersion || ''),
    limitsDeclared: !!stats.limitsDeclared,
    firestoreReads: Math.max(0, Number(stats.firestoreReads || 0)),
    firestoreWrites: Math.max(0, Number(stats.firestoreWrites || 0)),
    estimatedReadsPerHour: Math.max(0, Number(stats.estimatedReadsPerHour || 0)),
    estimatedWritesPerHour: Math.max(0, Number(stats.estimatedWritesPerHour || 0)),
    registryReads: Math.max(0, Number(stats.registryReads || 0)),
    registryWrites: Math.max(0, Number(stats.registryWrites || 0)),
    configReads: Math.max(0, Number(stats.configReads || 0)),
    configWrites: Math.max(0, Number(stats.configWrites || 0)),
    listeners: Math.max(0, Number(stats.listeners || 0)),
    queries: Math.max(0, Number(stats.queries || 0)),
    fanOut: Math.max(0, Number(stats.fanOut || 0)),
    targetPathBuilt: !!stats.targetPathBuilt,
    tenantTargetPathBuilt: !!stats.tenantTargetPathBuilt,
    tenantConfigTouched: !!stats.tenantConfigTouched,
    lifecycleTouched: !!stats.lifecycleTouched,
    authRuntimeChanged: !!stats.authRuntimeChanged,
    tenantRoutingActive: !!stats.tenantRoutingActive,
    schemaChanged: !!stats.schemaChanged,
    runtimeContractChanged: !!stats.runtimeContractChanged,
    violations: uniqueNonEmptyStrings_(stats.violations || [])
  };
}

function buildMigration3CostGuardSyntheticConfigStatus_(overrides) {
  overrides = overrides || {};
  var ok = overrides.ok !== false;
  return {
    ok: ok,
    stats: {
      stage: 'migration3_tenant_config',
      ok: ok,
      reason: ok ? 'm3_tenant_config_ready' : 'm3_tenant_config_violation',
      configVersion: String(overrides.configVersion || PHBOX_M3_COST_GUARD_REQUIRED_CONFIG_VERSION_),
      registryVersion: String(overrides.registryVersion || 'M3_TENANT_REGISTRY_v1'),
      registryPathPattern: String(overrides.registryPathPattern || 'tenant_registry/{tenantId}'),
      configPathPattern: String(overrides.configPathPattern || 'tenant_configs/{tenantId}'),
      firestoreReads: Math.max(0, Number(overrides.firestoreReads || 0)),
      firestoreWrites: Math.max(0, Number(overrides.firestoreWrites || 0)),
      estimatedReadsPerHour: Math.max(0, Number(overrides.estimatedReadsPerHour || 0)),
      estimatedWritesPerHour: Math.max(0, Number(overrides.estimatedWritesPerHour || 0)),
      registryReads: Math.max(0, Number(overrides.registryReads || 0)),
      registryWrites: Math.max(0, Number(overrides.registryWrites || 0)),
      configReads: Math.max(0, Number(overrides.configReads || 0)),
      configWrites: Math.max(0, Number(overrides.configWrites || 0)),
      targetWritesExecuted: Math.max(0, Number(overrides.targetWritesExecuted || 0)),
      listeners: Math.max(0, Number(overrides.listeners || 0)),
      queries: Math.max(0, Number(overrides.queries || 0)),
      fanOut: Math.max(0, Number(overrides.fanOut || 0)),
      targetPathBuilt: !!overrides.targetPathBuilt,
      tenantTargetPathBuilt: !!overrides.tenantTargetPathBuilt,
      tenantConfigTouched: !!overrides.tenantConfigTouched,
      lifecycleTouched: !!overrides.lifecycleTouched,
      authRuntimeChanged: !!overrides.authRuntimeChanged,
      tenantRoutingActive: !!overrides.tenantRoutingActive,
      schemaChanged: !!overrides.schemaChanged,
      runtimeContractChanged: !!overrides.runtimeContractChanged,
      obsoleteHandlers: uniqueNonEmptyStrings_(overrides.obsoleteHandlers || []),
      violations: uniqueNonEmptyStrings_(overrides.violations || []),
      error: String(overrides.error || ''),
      errorKind: String(overrides.errorKind || '')
    },
    items: []
  };
}

function migration3CostGuardSyntheticContract_(overrides) {
  overrides = overrides || {};
  var contract = buildMigration3CostGuardContract_();
  Object.keys(overrides).forEach(function (key) {
    contract[key] = overrides[key];
  });
  return contract;
}

function formatMigration3CostGuardSelfTestFeedback_(result) {
  result = result || {};
  var stats = result.stats || {};
  var lines = [];
  var items = result.items || [];
  var passed = items.filter(function (item) { return !!item.passed; }).length;
  lines.push('MIGRATION_3_COST_GUARD_TEST');
  lines.push('ok=' + String(!!result.ok));
  lines.push('testCount=' + String(items.length));
  lines.push('passedCount=' + String(passed));
  lines.push('failedCount=' + String(items.length - passed));
  migration3CostGuardAppendCommonFeedbackLines_(lines, stats);
  lines.push('items=');
  items.forEach(function (item) {
    migration3CostGuardAppendItemFeedbackLines_(lines, item);
  });
  return lines.join('\n');
}

function formatMigration3CostGuardRuntimeFeedback_(result) {
  result = result || {};
  var stats = result.stats || {};
  var lines = [];
  lines.push('MIGRATION_3_COST_GUARD_RUNTIME_STATUS');
  lines.push('ok=' + String(!!result.ok));
  lines.push('skipped=' + String(!!stats.skipped));
  migration3CostGuardAppendCommonFeedbackLines_(lines, stats);
  lines.push('obsoleteHandlers=' + migration3CostGuardJoinList_(stats.obsoleteHandlers));
  lines.push('violations=' + migration3CostGuardJoinList_(stats.violations));
  lines.push('error=' + (stats.error || 'none'));
  lines.push('errorKind=' + (stats.errorKind || 'none'));
  return lines.join('\n');
}

function migration3CostGuardAppendCommonFeedbackLines_(lines, stats) {
  stats = stats || {};
  var limits = buildMigration3CostGuardLimits_(stats.limits || {});
  lines.push('reason=' + String(stats.reason || ''));
  lines.push('costGuardVersion=' + String(stats.costGuardVersion || ''));
  lines.push('requiredConfigVersion=' + String(stats.requiredConfigVersion || ''));
  lines.push('configVersion=' + String(stats.configVersion || ''));
  lines.push('registryVersion=' + String(stats.registryVersion || ''));
  lines.push('registryPathPattern=' + String(stats.registryPathPattern || ''));
  lines.push('configPathPattern=' + String(stats.configPathPattern || ''));
  lines.push('costGuardOwner=' + String(stats.costGuardOwner || ''));
  lines.push('costPolicy=' + String(stats.costPolicy || ''));
  lines.push('guardMode=' + String(stats.guardMode || ''));
  lines.push('limitsDeclared=' + String(!!stats.limitsDeclared));
  lines.push('thresholdFieldsCount=' + String(migration3CostGuardLimitNames_().length));
  lines.push('maxFirestoreReads=' + String(limits.maxFirestoreReads));
  lines.push('maxFirestoreWrites=' + String(limits.maxFirestoreWrites));
  lines.push('maxEstimatedReadsPerHour=' + String(limits.maxEstimatedReadsPerHour));
  lines.push('maxEstimatedWritesPerHour=' + String(limits.maxEstimatedWritesPerHour));
  lines.push('maxRegistryReads=' + String(limits.maxRegistryReads));
  lines.push('maxRegistryWrites=' + String(limits.maxRegistryWrites));
  lines.push('maxConfigReads=' + String(limits.maxConfigReads));
  lines.push('maxConfigWrites=' + String(limits.maxConfigWrites));
  lines.push('maxTargetWritesExecuted=' + String(limits.maxTargetWritesExecuted));
  lines.push('maxListeners=' + String(limits.maxListeners));
  lines.push('maxQueries=' + String(limits.maxQueries));
  lines.push('maxFanOut=' + String(limits.maxFanOut));
  lines.push('firestoreReads=' + String(Math.max(0, Number(stats.firestoreReads || 0))));
  lines.push('firestoreWrites=' + String(Math.max(0, Number(stats.firestoreWrites || 0))));
  lines.push('estimatedReadsPerHour=' + String(Math.max(0, Number(stats.estimatedReadsPerHour || 0))));
  lines.push('estimatedWritesPerHour=' + String(Math.max(0, Number(stats.estimatedWritesPerHour || 0))));
  lines.push('registryReads=' + String(Math.max(0, Number(stats.registryReads || 0))));
  lines.push('registryWrites=' + String(Math.max(0, Number(stats.registryWrites || 0))));
  lines.push('configReads=' + String(Math.max(0, Number(stats.configReads || 0))));
  lines.push('configWrites=' + String(Math.max(0, Number(stats.configWrites || 0))));
  lines.push('targetWritesExecuted=' + String(Math.max(0, Number(stats.targetWritesExecuted || 0))));
  lines.push('listeners=' + String(Math.max(0, Number(stats.listeners || 0))));
  lines.push('queries=' + String(Math.max(0, Number(stats.queries || 0))));
  lines.push('fanOut=' + String(Math.max(0, Number(stats.fanOut || 0))));
  lines.push('targetPathBuilt=' + String(!!stats.targetPathBuilt));
  lines.push('tenantTargetPathBuilt=' + String(!!stats.tenantTargetPathBuilt));
  lines.push('tenantConfigTouched=' + String(!!stats.tenantConfigTouched));
  lines.push('lifecycleTouched=' + String(!!stats.lifecycleTouched));
  lines.push('authRuntimeChanged=' + String(!!stats.authRuntimeChanged));
  lines.push('tenantRoutingActive=' + String(!!stats.tenantRoutingActive));
  lines.push('schemaChanged=' + String(!!stats.schemaChanged));
  lines.push('runtimeContractChanged=' + String(!!stats.runtimeContractChanged));
}

function migration3CostGuardAppendItemFeedbackLines_(lines, item) {
  item = item || {};
  lines.push('- id=' + String(item.id || ''));
  lines.push('  passed=' + String(!!item.passed));
  lines.push('  ok=' + String(!!item.ok));
  lines.push('  reason=' + String(item.reason || ''));
  lines.push('  costGuardVersion=' + String(item.costGuardVersion || ''));
  lines.push('  configVersion=' + String(item.configVersion || ''));
  lines.push('  limitsDeclared=' + String(!!item.limitsDeclared));
  lines.push('  firestoreReads=' + String(Math.max(0, Number(item.firestoreReads || 0))));
  lines.push('  firestoreWrites=' + String(Math.max(0, Number(item.firestoreWrites || 0))));
  lines.push('  estimatedReadsPerHour=' + String(Math.max(0, Number(item.estimatedReadsPerHour || 0))));
  lines.push('  estimatedWritesPerHour=' + String(Math.max(0, Number(item.estimatedWritesPerHour || 0))));
  lines.push('  registryReads=' + String(Math.max(0, Number(item.registryReads || 0))));
  lines.push('  registryWrites=' + String(Math.max(0, Number(item.registryWrites || 0))));
  lines.push('  configReads=' + String(Math.max(0, Number(item.configReads || 0))));
  lines.push('  configWrites=' + String(Math.max(0, Number(item.configWrites || 0))));
  lines.push('  listeners=' + String(Math.max(0, Number(item.listeners || 0))));
  lines.push('  queries=' + String(Math.max(0, Number(item.queries || 0))));
  lines.push('  fanOut=' + String(Math.max(0, Number(item.fanOut || 0))));
  lines.push('  targetPathBuilt=' + String(!!item.targetPathBuilt));
  lines.push('  tenantTargetPathBuilt=' + String(!!item.tenantTargetPathBuilt));
  lines.push('  tenantConfigTouched=' + String(!!item.tenantConfigTouched));
  lines.push('  lifecycleTouched=' + String(!!item.lifecycleTouched));
  lines.push('  authRuntimeChanged=' + String(!!item.authRuntimeChanged));
  lines.push('  tenantRoutingActive=' + String(!!item.tenantRoutingActive));
  lines.push('  schemaChanged=' + String(!!item.schemaChanged));
  lines.push('  runtimeContractChanged=' + String(!!item.runtimeContractChanged));
  lines.push('  violations=' + migration3CostGuardJoinList_(item.violations));
}

function migration3CostGuardJoinList_(value) {
  var items = uniqueNonEmptyStrings_(value || []);
  return items.length ? items.join(',') : 'none';
}
