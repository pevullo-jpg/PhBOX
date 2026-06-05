var PHBOX_M3_TENANT_REGISTRY_VERSION_ = 'M3_TENANT_REGISTRY_v1';
var PHBOX_M3_TENANT_REGISTRY_STAGE_ = 'migration3_tenant_registry';
var PHBOX_M3_TENANT_REGISTRY_REQUIRED_LOCK_VERSION_ = 'M3_LOCK_v1';
var PHBOX_M3_TENANT_REGISTRY_PATH_PATTERN_ = 'tenant_registry/{tenantId}';
var PHBOX_M3_TENANT_REGISTRY_OWNER_ = 'backend_gas_contract_only';
var PHBOX_M3_TENANT_REGISTRY_PERSISTENT_OWNER_ = 'future_superback_firestore_writer';
var PHBOX_M3_TENANT_REGISTRY_TENANT_ID_PATTERN_ = '^[a-z0-9][a-z0-9-]{1,62}[a-z0-9]$';
var PHBOX_M3_TENANT_REGISTRY_REQUIRED_FIELDS_ = [
  'tenantId',
  'displayName',
  'status',
  'backendEnabled',
  'schemaVersion',
  'createdAt',
  'updatedAt',
  'createdBy',
  'updatedBy'
];
var PHBOX_M3_TENANT_REGISTRY_OPTIONAL_FIELDS_ = [
  'notes',
  'disabledReason',
  'suspendedReason'
];
var PHBOX_M3_TENANT_REGISTRY_STATUS_VALUES_ = [
  'provisioning',
  'active',
  'suspended',
  'disabled'
];

function runMigration3TenantRegistryRuntimeStatus_() {
  try {
    if (typeof runMigration3LockRuntimeStatus_ !== 'function') {
      throw new Error('M3_TENANT_REGISTRY_LOCK_MISSING: funzione runMigration3LockRuntimeStatus_ non disponibile. Tenant registry non autorizzabile.');
    }
    return buildMigration3TenantRegistryResult_({
      lockStatus: runMigration3LockRuntimeStatus_(),
      contract: buildMigration3TenantRegistryContract_(),
      obsoleteHandlers: listMigration3TenantRegistryObsoleteSettingsHandlers_()
    });
  } catch (e) {
    return buildMigration3TenantRegistryResult_({
      lockStatus: null,
      contract: buildMigration3TenantRegistryContract_(),
      obsoleteHandlers: listMigration3TenantRegistryObsoleteSettingsHandlers_(),
      error: normalizeRuntimeErrorMessage_(e),
      errorKind: classifyRuntimeFailureKind_(e)
    });
  }
}

function buildMigration3TenantRegistryContract_() {
  return {
    registryVersion: PHBOX_M3_TENANT_REGISTRY_VERSION_,
    pathPattern: PHBOX_M3_TENANT_REGISTRY_PATH_PATTERN_,
    owner: PHBOX_M3_TENANT_REGISTRY_OWNER_,
    persistentOwner: PHBOX_M3_TENANT_REGISTRY_PERSISTENT_OWNER_,
    tenantIdPattern: PHBOX_M3_TENANT_REGISTRY_TENANT_ID_PATTERN_,
    requiredFields: PHBOX_M3_TENANT_REGISTRY_REQUIRED_FIELDS_.slice(),
    optionalFields: PHBOX_M3_TENANT_REGISTRY_OPTIONAL_FIELDS_.slice(),
    statusValues: PHBOX_M3_TENANT_REGISTRY_STATUS_VALUES_.slice(),
    contractDeclared: true,
    firestoreReads: 0,
    firestoreWrites: 0,
    registryReads: 0,
    registryWrites: 0,
    targetWritesExecuted: 0,
    listeners: 0,
    queries: 0,
    fanOut: 0,
    targetPathBuilt: false,
    tenantTargetPathBuilt: false,
    lifecycleTouched: false,
    authRuntimeChanged: false,
    tenantRoutingActive: false,
    schemaChanged: false,
    runtimeContractChanged: false
  };
}

function buildMigration3TenantRegistryResult_(data) {
  data = data || {};
  var lockStatus = data.lockStatus || null;
  var lockStats = (lockStatus && lockStatus.stats) || {};
  var contract = data.contract || {};
  var obsoleteHandlers = uniqueNonEmptyStrings_([].concat(
    lockStats.obsoleteHandlers || [],
    data.obsoleteHandlers || []
  ));
  var statsInput = {
    ok: !!(lockStatus && lockStatus.ok) && lockStats.ok !== false,
    skipped: false,
    reason: '',
    lockVersion: String(lockStats.lockVersion || ''),
    registryVersion: String(contract.registryVersion || ''),
    registryPathPattern: String(contract.pathPattern || ''),
    registryOwner: String(contract.owner || ''),
    persistentOwner: String(contract.persistentOwner || ''),
    tenantIdPattern: String(contract.tenantIdPattern || ''),
    contractDeclared: !!contract.contractDeclared,
    requiredFields: uniqueNonEmptyStrings_(contract.requiredFields || []),
    optionalFields: uniqueNonEmptyStrings_(contract.optionalFields || []),
    statusValues: uniqueNonEmptyStrings_(contract.statusValues || []),
    firestoreReads: Math.max(0, Number(lockStats.firestoreReads || 0) + Number(contract.firestoreReads || 0) + Number(data.firestoreReads || 0)),
    firestoreWrites: Math.max(0, Number(lockStats.firestoreWrites || 0) + Number(contract.firestoreWrites || 0) + Number(data.firestoreWrites || 0)),
    estimatedReadsPerHour: Math.max(0, Number(lockStats.estimatedReadsPerHour || 0) + Number(data.estimatedReadsPerHour || 0)),
    estimatedWritesPerHour: Math.max(0, Number(lockStats.estimatedWritesPerHour || 0) + Number(data.estimatedWritesPerHour || 0)),
    registryReads: Math.max(0, Number(contract.registryReads || 0) + Number(data.registryReads || 0)),
    registryWrites: Math.max(0, Number(contract.registryWrites || 0) + Number(data.registryWrites || 0)),
    targetWritesExecuted: Math.max(0, Number(lockStats.targetWritesExecuted || 0) + Number(contract.targetWritesExecuted || 0) + Number(data.targetWritesExecuted || 0)),
    listeners: Math.max(0, Number(lockStats.listeners || 0) + Number(contract.listeners || 0) + Number(data.listeners || 0)),
    queries: Math.max(0, Number(lockStats.queries || 0) + Number(contract.queries || 0) + Number(data.queries || 0)),
    fanOut: Math.max(0, Number(lockStats.fanOut || 0) + Number(contract.fanOut || 0) + Number(data.fanOut || 0)),
    targetPathBuilt: !!lockStats.targetPathBuilt || !!contract.targetPathBuilt || !!data.targetPathBuilt,
    tenantTargetPathBuilt: !!lockStats.tenantTargetPathBuilt || !!contract.tenantTargetPathBuilt || !!data.tenantTargetPathBuilt,
    lifecycleTouched: !!lockStats.lifecycleTouched || !!contract.lifecycleTouched || !!data.lifecycleTouched,
    authRuntimeChanged: !!lockStats.authRuntimeChanged || !!contract.authRuntimeChanged || !!data.authRuntimeChanged,
    tenantRoutingActive: !!lockStats.tenantRoutingActive || !!contract.tenantRoutingActive || !!data.tenantRoutingActive,
    schemaChanged: !!lockStats.schemaChanged || !!contract.schemaChanged || !!data.schemaChanged,
    runtimeContractChanged: !!contract.runtimeContractChanged || !!data.runtimeContractChanged,
    obsoleteHandlers: obsoleteHandlers,
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };
  var violations = buildMigration3TenantRegistryViolations_({
    lockPresent: !!(lockStatus && lockStatus.stats),
    lockOk: statsInput.ok,
    lockVersion: statsInput.lockVersion,
    registryVersion: statsInput.registryVersion,
    registryPathPattern: statsInput.registryPathPattern,
    registryOwner: statsInput.registryOwner,
    persistentOwner: statsInput.persistentOwner,
    tenantIdPattern: statsInput.tenantIdPattern,
    contractDeclared: statsInput.contractDeclared,
    requiredFields: statsInput.requiredFields,
    statusValues: statsInput.statusValues,
    firestoreReads: statsInput.firestoreReads,
    firestoreWrites: statsInput.firestoreWrites,
    estimatedReadsPerHour: statsInput.estimatedReadsPerHour,
    estimatedWritesPerHour: statsInput.estimatedWritesPerHour,
    registryReads: statsInput.registryReads,
    registryWrites: statsInput.registryWrites,
    targetWritesExecuted: statsInput.targetWritesExecuted,
    listeners: statsInput.listeners,
    queries: statsInput.queries,
    fanOut: statsInput.fanOut,
    targetPathBuilt: statsInput.targetPathBuilt,
    tenantTargetPathBuilt: statsInput.tenantTargetPathBuilt,
    lifecycleTouched: statsInput.lifecycleTouched,
    authRuntimeChanged: statsInput.authRuntimeChanged,
    tenantRoutingActive: statsInput.tenantRoutingActive,
    schemaChanged: statsInput.schemaChanged,
    runtimeContractChanged: statsInput.runtimeContractChanged,
    obsoleteHandlers: obsoleteHandlers,
    error: statsInput.error
  });
  statsInput.ok = violations.length === 0;
  statsInput.reason = violations.length ? 'm3_tenant_registry_violation' : 'm3_tenant_registry_ready';
  statsInput.violations = violations;
  return buildMigration3TenantRegistryResultFromStats_(statsInput);
}

function buildMigration3TenantRegistryViolations_(data) {
  data = data || {};
  var violations = [];
  if (!data.lockPresent) violations.push('m3_lock_status_missing');
  if (data.lockPresent && !data.lockOk) violations.push('m3_lock_not_ok');
  if (String(data.lockVersion || '') !== PHBOX_M3_TENANT_REGISTRY_REQUIRED_LOCK_VERSION_) violations.push('m3_lock_version_mismatch');
  if (String(data.registryVersion || '') !== PHBOX_M3_TENANT_REGISTRY_VERSION_) violations.push('registry_version_mismatch');
  if (String(data.registryPathPattern || '') !== PHBOX_M3_TENANT_REGISTRY_PATH_PATTERN_) violations.push('registry_path_pattern_mismatch');
  if (String(data.registryOwner || '') !== PHBOX_M3_TENANT_REGISTRY_OWNER_) violations.push('registry_owner_mismatch');
  if (String(data.persistentOwner || '') !== PHBOX_M3_TENANT_REGISTRY_PERSISTENT_OWNER_) violations.push('persistent_owner_mismatch');
  if (String(data.tenantIdPattern || '') !== PHBOX_M3_TENANT_REGISTRY_TENANT_ID_PATTERN_) violations.push('tenant_id_pattern_mismatch');
  if (!data.contractDeclared) violations.push('registry_contract_not_declared');
  migration3TenantRegistryMissingItems_(PHBOX_M3_TENANT_REGISTRY_REQUIRED_FIELDS_, data.requiredFields || []).forEach(function (field) {
    violations.push('missing_required_field_' + field);
  });
  migration3TenantRegistryMissingItems_(PHBOX_M3_TENANT_REGISTRY_STATUS_VALUES_, data.statusValues || []).forEach(function (status) {
    violations.push('missing_status_' + status);
  });
  if (Number(data.firestoreReads || 0) > 0) violations.push('firestore_reads_detected');
  if (Number(data.firestoreWrites || 0) > 0) violations.push('firestore_writes_detected');
  if (Number(data.estimatedReadsPerHour || 0) > 0) violations.push('firestore_reads_per_hour_detected');
  if (Number(data.estimatedWritesPerHour || 0) > 0) violations.push('firestore_writes_per_hour_detected');
  if (Number(data.registryReads || 0) > 0) violations.push('registry_reads_detected');
  if (Number(data.registryWrites || 0) > 0) violations.push('registry_writes_detected');
  if (Number(data.targetWritesExecuted || 0) > 0) violations.push('target_writes_executed');
  if (Number(data.listeners || 0) > 0) violations.push('listeners_detected');
  if (Number(data.queries || 0) > 0) violations.push('queries_detected');
  if (Number(data.fanOut || 0) > 0) violations.push('fanout_detected');
  if (data.targetPathBuilt) violations.push('target_path_built');
  if (data.tenantTargetPathBuilt) violations.push('tenant_target_path_built');
  if (data.lifecycleTouched) violations.push('lifecycle_touched');
  if (data.authRuntimeChanged) violations.push('auth_runtime_changed');
  if (data.tenantRoutingActive) violations.push('tenant_routing_active');
  if (data.schemaChanged) violations.push('schema_changed');
  if (data.runtimeContractChanged) violations.push('runtime_contract_changed');
  if (uniqueNonEmptyStrings_(data.obsoleteHandlers || []).length > 0) violations.push('obsolete_settings_handlers_detected');
  if (data.error) violations.push('m3_tenant_registry_error');
  return uniqueNonEmptyStrings_(violations);
}

function migration3TenantRegistryMissingItems_(expected, actual) {
  expected = uniqueNonEmptyStrings_(expected || []);
  actual = uniqueNonEmptyStrings_(actual || []);
  return expected.filter(function (item) { return actual.indexOf(item) === -1; });
}

function buildMigration3TenantRegistryResultFromStats_(data) {
  data = data || {};
  var stats = buildMigration3TenantRegistryStats_(data);
  return {
    ok: data.ok !== false,
    stats: stats,
    violations: uniqueNonEmptyStrings_(data.violations || []),
    items: data.items || []
  };
}

function buildMigration3TenantRegistryStats_(data) {
  data = data || {};
  return {
    stage: PHBOX_M3_TENANT_REGISTRY_STAGE_,
    ok: data.ok !== false,
    skipped: data.skipped !== false,
    reason: String(data.reason || ''),
    registryVersion: String(data.registryVersion || ''),
    requiredLockVersion: PHBOX_M3_TENANT_REGISTRY_REQUIRED_LOCK_VERSION_,
    lockVersion: String(data.lockVersion || ''),
    registryPathPattern: String(data.registryPathPattern || ''),
    registryOwner: String(data.registryOwner || ''),
    persistentOwner: String(data.persistentOwner || ''),
    tenantIdPattern: String(data.tenantIdPattern || ''),
    contractDeclared: !!data.contractDeclared,
    requiredFields: uniqueNonEmptyStrings_(data.requiredFields || []),
    optionalFields: uniqueNonEmptyStrings_(data.optionalFields || []),
    statusValues: uniqueNonEmptyStrings_(data.statusValues || []),
    firestoreReads: Math.max(0, Number(data.firestoreReads || 0)),
    firestoreWrites: Math.max(0, Number(data.firestoreWrites || 0)),
    estimatedReadsPerHour: Math.max(0, Number(data.estimatedReadsPerHour || 0)),
    estimatedWritesPerHour: Math.max(0, Number(data.estimatedWritesPerHour || 0)),
    registryReads: Math.max(0, Number(data.registryReads || 0)),
    registryWrites: Math.max(0, Number(data.registryWrites || 0)),
    targetWritesExecuted: Math.max(0, Number(data.targetWritesExecuted || 0)),
    listeners: Math.max(0, Number(data.listeners || 0)),
    queries: Math.max(0, Number(data.queries || 0)),
    fanOut: Math.max(0, Number(data.fanOut || 0)),
    targetPathBuilt: !!data.targetPathBuilt,
    tenantTargetPathBuilt: !!data.tenantTargetPathBuilt,
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

function listMigration3TenantRegistryObsoleteSettingsHandlers_() {
  var obsolete = [
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
  if (typeof listMigration3LockObsoleteSettingsHandlers_ === 'function') {
    obsolete = obsolete.concat(listMigration3LockObsoleteSettingsHandlers_());
  }
  return uniqueNonEmptyStrings_(obsolete);
}

function runMigration3TenantRegistrySelfTest_() {
  var cleanContract = buildMigration3TenantRegistryContract_();
  var cases = [
    {
      id: 'clean_m3_lock_authorizes_tenant_registry_contract',
      result: buildMigration3TenantRegistryResult_({ lockStatus: buildMigration3TenantRegistrySyntheticLockStatus_({}), contract: cleanContract }),
      expected: { ok: true, violation: '' }
    },
    {
      id: 'missing_m3_lock_blocks_tenant_registry',
      result: buildMigration3TenantRegistryResult_({ lockStatus: null, contract: cleanContract }),
      expected: { ok: false, violation: 'm3_lock_status_missing' }
    },
    {
      id: 'm3_lock_not_ok_blocks_tenant_registry',
      result: buildMigration3TenantRegistryResult_({ lockStatus: buildMigration3TenantRegistrySyntheticLockStatus_({ ok: false }), contract: cleanContract }),
      expected: { ok: false, violation: 'm3_lock_not_ok' }
    },
    {
      id: 'm3_lock_version_mismatch_blocks_tenant_registry',
      result: buildMigration3TenantRegistryResult_({ lockStatus: buildMigration3TenantRegistrySyntheticLockStatus_({ lockVersion: 'M3_LOCK_v0' }), contract: cleanContract }),
      expected: { ok: false, violation: 'm3_lock_version_mismatch' }
    },
    {
      id: 'registry_version_mismatch_blocks_tenant_registry',
      result: buildMigration3TenantRegistryResult_({ lockStatus: buildMigration3TenantRegistrySyntheticLockStatus_({}), contract: migration3TenantRegistrySyntheticContract_({ registryVersion: 'M3_TENANT_REGISTRY_v0' }) }),
      expected: { ok: false, violation: 'registry_version_mismatch' }
    },
    {
      id: 'registry_path_mismatch_blocks_tenant_registry',
      result: buildMigration3TenantRegistryResult_({ lockStatus: buildMigration3TenantRegistrySyntheticLockStatus_({}), contract: migration3TenantRegistrySyntheticContract_({ pathPattern: 'tenants/{tenantId}' }) }),
      expected: { ok: false, violation: 'registry_path_pattern_mismatch' }
    },
    {
      id: 'missing_required_field_blocks_tenant_registry',
      result: buildMigration3TenantRegistryResult_({ lockStatus: buildMigration3TenantRegistrySyntheticLockStatus_({}), contract: migration3TenantRegistrySyntheticContract_({ requiredFields: ['tenantId', 'displayName'] }) }),
      expected: { ok: false, violation: 'missing_required_field_status' }
    },
    {
      id: 'missing_status_value_blocks_tenant_registry',
      result: buildMigration3TenantRegistryResult_({ lockStatus: buildMigration3TenantRegistrySyntheticLockStatus_({}), contract: migration3TenantRegistrySyntheticContract_({ statusValues: ['active', 'disabled'] }) }),
      expected: { ok: false, violation: 'missing_status_provisioning' }
    },
    {
      id: 'registry_read_blocks_tenant_registry',
      result: buildMigration3TenantRegistryResult_({ lockStatus: buildMigration3TenantRegistrySyntheticLockStatus_({}), contract: migration3TenantRegistrySyntheticContract_({ registryReads: 1 }), estimatedReadsPerHour: 1 }),
      expected: { ok: false, violation: 'registry_reads_detected' }
    },
    {
      id: 'registry_write_blocks_tenant_registry',
      result: buildMigration3TenantRegistryResult_({ lockStatus: buildMigration3TenantRegistrySyntheticLockStatus_({}), contract: migration3TenantRegistrySyntheticContract_({ registryWrites: 1 }), estimatedWritesPerHour: 1 }),
      expected: { ok: false, violation: 'registry_writes_detected' }
    },
    {
      id: 'listener_query_fanout_blocks_tenant_registry',
      result: buildMigration3TenantRegistryResult_({ lockStatus: buildMigration3TenantRegistrySyntheticLockStatus_({ listeners: 1, queries: 1, fanOut: 1 }), contract: cleanContract }),
      expected: { ok: false, violation: 'listeners_detected' }
    },
    {
      id: 'tenant_target_path_blocks_tenant_registry',
      result: buildMigration3TenantRegistryResult_({ lockStatus: buildMigration3TenantRegistrySyntheticLockStatus_({}), contract: migration3TenantRegistrySyntheticContract_({ tenantTargetPathBuilt: true }) }),
      expected: { ok: false, violation: 'tenant_target_path_built' }
    },
    {
      id: 'auth_or_route_blocks_tenant_registry',
      result: buildMigration3TenantRegistryResult_({ lockStatus: buildMigration3TenantRegistrySyntheticLockStatus_({}), contract: migration3TenantRegistrySyntheticContract_({ authRuntimeChanged: true, tenantRoutingActive: true }) }),
      expected: { ok: false, violation: 'auth_runtime_changed' }
    },
    {
      id: 'schema_or_runtime_contract_change_blocks_tenant_registry',
      result: buildMigration3TenantRegistryResult_({ lockStatus: buildMigration3TenantRegistrySyntheticLockStatus_({}), contract: migration3TenantRegistrySyntheticContract_({ schemaChanged: true, runtimeContractChanged: true }) }),
      expected: { ok: false, violation: 'schema_changed' }
    },
    {
      id: 'obsolete_settings_handler_blocks_tenant_registry',
      result: buildMigration3TenantRegistryResult_({ lockStatus: buildMigration3TenantRegistrySyntheticLockStatus_({}), contract: cleanContract, obsoleteHandlers: ['runMigration3LockSettingsTest'] }),
      expected: { ok: false, violation: 'obsolete_settings_handlers_detected' }
    },
    {
      id: 'runtime_error_blocks_tenant_registry',
      result: buildMigration3TenantRegistryResult_({ lockStatus: buildMigration3TenantRegistrySyntheticLockStatus_({}), contract: cleanContract, error: 'synthetic error', errorKind: 'synthetic' }),
      expected: { ok: false, violation: 'm3_tenant_registry_error' }
    }
  ];

  var items = cases.map(function (entry) {
    var stats = entry.result.stats || {};
    var violations = uniqueNonEmptyStrings_(stats.violations || []);
    var passed = !!stats.ok === !!entry.expected.ok;
    if (entry.expected.violation) passed = passed && violations.indexOf(entry.expected.violation) !== -1;
    return buildMigration3TenantRegistrySelfTestItem_(entry.id, passed, stats);
  });
  var failed = items.filter(function (item) { return !item.passed; });
  return buildMigration3TenantRegistryResultFromStats_({
    ok: failed.length === 0,
    skipped: false,
    reason: failed.length ? 'm3_tenant_registry_selftest_failed' : 'm3_tenant_registry_selftest_passed',
    lockVersion: PHBOX_M3_TENANT_REGISTRY_REQUIRED_LOCK_VERSION_,
    registryVersion: PHBOX_M3_TENANT_REGISTRY_VERSION_,
    registryPathPattern: PHBOX_M3_TENANT_REGISTRY_PATH_PATTERN_,
    registryOwner: PHBOX_M3_TENANT_REGISTRY_OWNER_,
    persistentOwner: PHBOX_M3_TENANT_REGISTRY_PERSISTENT_OWNER_,
    tenantIdPattern: PHBOX_M3_TENANT_REGISTRY_TENANT_ID_PATTERN_,
    contractDeclared: true,
    requiredFields: PHBOX_M3_TENANT_REGISTRY_REQUIRED_FIELDS_,
    optionalFields: PHBOX_M3_TENANT_REGISTRY_OPTIONAL_FIELDS_,
    statusValues: PHBOX_M3_TENANT_REGISTRY_STATUS_VALUES_,
    items: items,
    violations: failed.map(function (item) { return item.id; })
  });
}

function buildMigration3TenantRegistrySelfTestItem_(id, passed, stats) {
  stats = stats || {};
  return {
    id: String(id || ''),
    passed: !!passed,
    ok: !!stats.ok,
    reason: String(stats.reason || ''),
    registryVersion: String(stats.registryVersion || ''),
    lockVersion: String(stats.lockVersion || ''),
    registryPathPattern: String(stats.registryPathPattern || ''),
    contractDeclared: !!stats.contractDeclared,
    requiredFieldsCount: uniqueNonEmptyStrings_(stats.requiredFields || []).length,
    statusValuesCount: uniqueNonEmptyStrings_(stats.statusValues || []).length,
    firestoreReads: Math.max(0, Number(stats.firestoreReads || 0)),
    firestoreWrites: Math.max(0, Number(stats.firestoreWrites || 0)),
    estimatedReadsPerHour: Math.max(0, Number(stats.estimatedReadsPerHour || 0)),
    estimatedWritesPerHour: Math.max(0, Number(stats.estimatedWritesPerHour || 0)),
    registryReads: Math.max(0, Number(stats.registryReads || 0)),
    registryWrites: Math.max(0, Number(stats.registryWrites || 0)),
    listeners: Math.max(0, Number(stats.listeners || 0)),
    queries: Math.max(0, Number(stats.queries || 0)),
    fanOut: Math.max(0, Number(stats.fanOut || 0)),
    targetPathBuilt: !!stats.targetPathBuilt,
    tenantTargetPathBuilt: !!stats.tenantTargetPathBuilt,
    lifecycleTouched: !!stats.lifecycleTouched,
    authRuntimeChanged: !!stats.authRuntimeChanged,
    tenantRoutingActive: !!stats.tenantRoutingActive,
    schemaChanged: !!stats.schemaChanged,
    runtimeContractChanged: !!stats.runtimeContractChanged,
    violations: uniqueNonEmptyStrings_(stats.violations || [])
  };
}

function buildMigration3TenantRegistrySyntheticLockStatus_(overrides) {
  overrides = overrides || {};
  var ok = overrides.ok !== false;
  return {
    ok: ok,
    stats: {
      stage: 'migration3_lock',
      ok: ok,
      reason: ok ? 'm3_lock_ready' : 'm3_lock_violation',
      lockVersion: String(overrides.lockVersion || PHBOX_M3_TENANT_REGISTRY_REQUIRED_LOCK_VERSION_),
      firestoreReads: Math.max(0, Number(overrides.firestoreReads || 0)),
      firestoreWrites: Math.max(0, Number(overrides.firestoreWrites || 0)),
      estimatedReadsPerHour: Math.max(0, Number(overrides.estimatedReadsPerHour || 0)),
      estimatedWritesPerHour: Math.max(0, Number(overrides.estimatedWritesPerHour || 0)),
      targetWritesExecuted: Math.max(0, Number(overrides.targetWritesExecuted || 0)),
      listeners: Math.max(0, Number(overrides.listeners || 0)),
      queries: Math.max(0, Number(overrides.queries || 0)),
      fanOut: Math.max(0, Number(overrides.fanOut || 0)),
      targetPathBuilt: !!overrides.targetPathBuilt,
      tenantTargetPathBuilt: !!overrides.tenantTargetPathBuilt,
      lifecycleTouched: !!overrides.lifecycleTouched,
      authRuntimeChanged: !!overrides.authRuntimeChanged,
      tenantRoutingActive: !!overrides.tenantRoutingActive,
      schemaChanged: !!overrides.schemaChanged,
      obsoleteHandlers: uniqueNonEmptyStrings_(overrides.obsoleteHandlers || []),
      violations: uniqueNonEmptyStrings_(overrides.violations || []),
      error: String(overrides.error || ''),
      errorKind: String(overrides.errorKind || '')
    },
    items: []
  };
}

function migration3TenantRegistrySyntheticContract_(overrides) {
  overrides = overrides || {};
  var contract = buildMigration3TenantRegistryContract_();
  Object.keys(overrides).forEach(function (key) {
    contract[key] = overrides[key];
  });
  return contract;
}

function formatMigration3TenantRegistrySelfTestFeedback_(result) {
  result = result || {};
  var stats = result.stats || {};
  var lines = [];
  var items = result.items || [];
  var passed = items.filter(function (item) { return !!item.passed; }).length;
  lines.push('MIGRATION_3_TENANT_REGISTRY_TEST');
  lines.push('ok=' + String(!!result.ok));
  lines.push('testCount=' + String(items.length));
  lines.push('passedCount=' + String(passed));
  lines.push('failedCount=' + String(items.length - passed));
  migration3TenantRegistryAppendCommonFeedbackLines_(lines, stats);
  lines.push('items=');
  items.forEach(function (item) {
    migration3TenantRegistryAppendItemFeedbackLines_(lines, item);
  });
  return lines.join('\n');
}

function formatMigration3TenantRegistryRuntimeFeedback_(result) {
  result = result || {};
  var stats = result.stats || {};
  var lines = [];
  lines.push('MIGRATION_3_TENANT_REGISTRY_RUNTIME_STATUS');
  lines.push('ok=' + String(!!result.ok));
  lines.push('skipped=' + String(!!stats.skipped));
  migration3TenantRegistryAppendCommonFeedbackLines_(lines, stats);
  lines.push('obsoleteHandlers=' + migration3TenantRegistryJoinList_(stats.obsoleteHandlers));
  lines.push('violations=' + migration3TenantRegistryJoinList_(stats.violations));
  lines.push('error=' + (stats.error || 'none'));
  lines.push('errorKind=' + (stats.errorKind || 'none'));
  return lines.join('\n');
}

function migration3TenantRegistryAppendCommonFeedbackLines_(lines, stats) {
  stats = stats || {};
  lines.push('reason=' + String(stats.reason || ''));
  lines.push('registryVersion=' + String(stats.registryVersion || ''));
  lines.push('requiredLockVersion=' + String(stats.requiredLockVersion || ''));
  lines.push('lockVersion=' + String(stats.lockVersion || ''));
  lines.push('registryPathPattern=' + String(stats.registryPathPattern || ''));
  lines.push('registryOwner=' + String(stats.registryOwner || ''));
  lines.push('persistentOwner=' + String(stats.persistentOwner || ''));
  lines.push('tenantIdPattern=' + String(stats.tenantIdPattern || ''));
  lines.push('contractDeclared=' + String(!!stats.contractDeclared));
  lines.push('requiredFieldsCount=' + String(uniqueNonEmptyStrings_(stats.requiredFields || []).length));
  lines.push('optionalFieldsCount=' + String(uniqueNonEmptyStrings_(stats.optionalFields || []).length));
  lines.push('statusValuesCount=' + String(uniqueNonEmptyStrings_(stats.statusValues || []).length));
  lines.push('requiredFields=' + migration3TenantRegistryJoinList_(stats.requiredFields));
  lines.push('statusValues=' + migration3TenantRegistryJoinList_(stats.statusValues));
  lines.push('firestoreReads=' + String(Math.max(0, Number(stats.firestoreReads || 0))));
  lines.push('firestoreWrites=' + String(Math.max(0, Number(stats.firestoreWrites || 0))));
  lines.push('estimatedReadsPerHour=' + String(Math.max(0, Number(stats.estimatedReadsPerHour || 0))));
  lines.push('estimatedWritesPerHour=' + String(Math.max(0, Number(stats.estimatedWritesPerHour || 0))));
  lines.push('registryReads=' + String(Math.max(0, Number(stats.registryReads || 0))));
  lines.push('registryWrites=' + String(Math.max(0, Number(stats.registryWrites || 0))));
  lines.push('targetWritesExecuted=' + String(Math.max(0, Number(stats.targetWritesExecuted || 0))));
  lines.push('listeners=' + String(Math.max(0, Number(stats.listeners || 0))));
  lines.push('queries=' + String(Math.max(0, Number(stats.queries || 0))));
  lines.push('fanOut=' + String(Math.max(0, Number(stats.fanOut || 0))));
  lines.push('targetPathBuilt=' + String(!!stats.targetPathBuilt));
  lines.push('tenantTargetPathBuilt=' + String(!!stats.tenantTargetPathBuilt));
  lines.push('lifecycleTouched=' + String(!!stats.lifecycleTouched));
  lines.push('authRuntimeChanged=' + String(!!stats.authRuntimeChanged));
  lines.push('tenantRoutingActive=' + String(!!stats.tenantRoutingActive));
  lines.push('schemaChanged=' + String(!!stats.schemaChanged));
  lines.push('runtimeContractChanged=' + String(!!stats.runtimeContractChanged));
}

function migration3TenantRegistryAppendItemFeedbackLines_(lines, item) {
  item = item || {};
  lines.push('- id=' + String(item.id || ''));
  lines.push('  passed=' + String(!!item.passed));
  lines.push('  ok=' + String(!!item.ok));
  lines.push('  reason=' + String(item.reason || ''));
  lines.push('  registryVersion=' + String(item.registryVersion || ''));
  lines.push('  lockVersion=' + String(item.lockVersion || ''));
  lines.push('  registryPathPattern=' + String(item.registryPathPattern || ''));
  lines.push('  contractDeclared=' + String(!!item.contractDeclared));
  lines.push('  requiredFieldsCount=' + String(Math.max(0, Number(item.requiredFieldsCount || 0))));
  lines.push('  statusValuesCount=' + String(Math.max(0, Number(item.statusValuesCount || 0))));
  lines.push('  firestoreReads=' + String(Math.max(0, Number(item.firestoreReads || 0))));
  lines.push('  firestoreWrites=' + String(Math.max(0, Number(item.firestoreWrites || 0))));
  lines.push('  estimatedReadsPerHour=' + String(Math.max(0, Number(item.estimatedReadsPerHour || 0))));
  lines.push('  estimatedWritesPerHour=' + String(Math.max(0, Number(item.estimatedWritesPerHour || 0))));
  lines.push('  registryReads=' + String(Math.max(0, Number(item.registryReads || 0))));
  lines.push('  registryWrites=' + String(Math.max(0, Number(item.registryWrites || 0))));
  lines.push('  listeners=' + String(Math.max(0, Number(item.listeners || 0))));
  lines.push('  queries=' + String(Math.max(0, Number(item.queries || 0))));
  lines.push('  fanOut=' + String(Math.max(0, Number(item.fanOut || 0))));
  lines.push('  targetPathBuilt=' + String(!!item.targetPathBuilt));
  lines.push('  tenantTargetPathBuilt=' + String(!!item.tenantTargetPathBuilt));
  lines.push('  lifecycleTouched=' + String(!!item.lifecycleTouched));
  lines.push('  authRuntimeChanged=' + String(!!item.authRuntimeChanged));
  lines.push('  tenantRoutingActive=' + String(!!item.tenantRoutingActive));
  lines.push('  schemaChanged=' + String(!!item.schemaChanged));
  lines.push('  runtimeContractChanged=' + String(!!item.runtimeContractChanged));
  lines.push('  violations=' + migration3TenantRegistryJoinList_(item.violations));
}

function migration3TenantRegistryJoinList_(value) {
  var items = uniqueNonEmptyStrings_(value || []);
  return items.length ? items.join(',') : 'none';
}
