var PHBOX_M3_TENANT_CONFIG_VERSION_ = 'M3_TENANT_CONFIG_v1';
var PHBOX_M3_TENANT_CONFIG_STAGE_ = 'migration3_tenant_config';
var PHBOX_M3_TENANT_CONFIG_REQUIRED_REGISTRY_VERSION_ = 'M3_TENANT_REGISTRY_v1';
var PHBOX_M3_TENANT_CONFIG_REQUIRED_REGISTRY_PATH_PATTERN_ = 'tenant_registry/{tenantId}';
var PHBOX_M3_TENANT_CONFIG_PATH_PATTERN_ = 'tenant_configs/{tenantId}';
var PHBOX_M3_TENANT_CONFIG_OWNER_ = 'backend_gas_contract_only';
var PHBOX_M3_TENANT_CONFIG_PERSISTENT_OWNER_ = 'future_superback_firestore_writer';
var PHBOX_M3_TENANT_CONFIG_RUNTIME_READER_ = 'future_tenant_backend_runtime_reader';
var PHBOX_M3_TENANT_CONFIG_SOURCE_OF_TRUTH_ = 'future_superback_firestore';
var PHBOX_M3_TENANT_CONFIG_TENANT_ID_PATTERN_ = '^[a-z0-9][a-z0-9-]{1,62}[a-z0-9]$';
var PHBOX_M3_TENANT_CONFIG_REQUIRED_FIELDS_ = [
  'tenantId',
  'configVersion',
  'schemaVersion',
  'backendEnabled',
  'firestoreProjectId',
  'driveRootFolderId',
  'gmailOperationalAccount',
  'scanUnreadOnly',
  'scanSpam',
  'trashValidEmails',
  'acceptedCities',
  'acceptRecipesWithoutCity',
  'createdAt',
  'updatedAt',
  'createdBy',
  'updatedBy'
];
var PHBOX_M3_TENANT_CONFIG_OPTIONAL_FIELDS_ = [
  'excludedEmailSenders',
  'cityPolicy',
  'processingMode',
  'notes'
];

function runMigration3TenantConfigRuntimeStatus_() {
  try {
    if (typeof runMigration3TenantRegistryRuntimeStatus_ !== 'function') {
      throw new Error('M3_TENANT_CONFIG_REGISTRY_MISSING: funzione runMigration3TenantRegistryRuntimeStatus_ non disponibile. Tenant config non autorizzabile.');
    }
    return buildMigration3TenantConfigResult_({
      registryStatus: runMigration3TenantRegistryRuntimeStatus_(),
      contract: buildMigration3TenantConfigContract_(),
      obsoleteHandlers: listMigration3TenantConfigObsoleteSettingsHandlers_()
    });
  } catch (e) {
    return buildMigration3TenantConfigResult_({
      registryStatus: null,
      contract: buildMigration3TenantConfigContract_(),
      obsoleteHandlers: listMigration3TenantConfigObsoleteSettingsHandlers_(),
      error: normalizeRuntimeErrorMessage_(e),
      errorKind: classifyRuntimeFailureKind_(e)
    });
  }
}

function buildMigration3TenantConfigContract_() {
  return {
    configVersion: PHBOX_M3_TENANT_CONFIG_VERSION_,
    configPathPattern: PHBOX_M3_TENANT_CONFIG_PATH_PATTERN_,
    configOwner: PHBOX_M3_TENANT_CONFIG_OWNER_,
    persistentOwner: PHBOX_M3_TENANT_CONFIG_PERSISTENT_OWNER_,
    runtimeReader: PHBOX_M3_TENANT_CONFIG_RUNTIME_READER_,
    sourceOfTruth: PHBOX_M3_TENANT_CONFIG_SOURCE_OF_TRUTH_,
    tenantIdPattern: PHBOX_M3_TENANT_CONFIG_TENANT_ID_PATTERN_,
    requiredFields: PHBOX_M3_TENANT_CONFIG_REQUIRED_FIELDS_.slice(),
    optionalFields: PHBOX_M3_TENANT_CONFIG_OPTIONAL_FIELDS_.slice(),
    contractDeclared: true,
    firestoreReads: 0,
    firestoreWrites: 0,
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

function buildMigration3TenantConfigResult_(data) {
  data = data || {};
  var registryStatus = data.registryStatus || null;
  var registryStats = (registryStatus && registryStatus.stats) || {};
  var contract = data.contract || {};
  var obsoleteHandlers = uniqueNonEmptyStrings_([].concat(
    registryStats.obsoleteHandlers || [],
    data.obsoleteHandlers || []
  ));
  var statsInput = {
    ok: !!(registryStatus && registryStatus.ok) && registryStats.ok !== false,
    skipped: false,
    reason: '',
    registryVersion: String(registryStats.registryVersion || ''),
    registryPathPattern: String(registryStats.registryPathPattern || ''),
    configVersion: String(contract.configVersion || ''),
    configPathPattern: String(contract.configPathPattern || ''),
    configOwner: String(contract.configOwner || ''),
    persistentOwner: String(contract.persistentOwner || ''),
    runtimeReader: String(contract.runtimeReader || ''),
    sourceOfTruth: String(contract.sourceOfTruth || ''),
    tenantIdPattern: String(contract.tenantIdPattern || ''),
    contractDeclared: !!contract.contractDeclared,
    requiredFields: uniqueNonEmptyStrings_(contract.requiredFields || []),
    optionalFields: uniqueNonEmptyStrings_(contract.optionalFields || []),
    firestoreReads: Math.max(0, Number(registryStats.firestoreReads || 0) + Number(contract.firestoreReads || 0) + Number(data.firestoreReads || 0)),
    firestoreWrites: Math.max(0, Number(registryStats.firestoreWrites || 0) + Number(contract.firestoreWrites || 0) + Number(data.firestoreWrites || 0)),
    estimatedReadsPerHour: Math.max(0, Number(registryStats.estimatedReadsPerHour || 0) + Number(data.estimatedReadsPerHour || 0)),
    estimatedWritesPerHour: Math.max(0, Number(registryStats.estimatedWritesPerHour || 0) + Number(data.estimatedWritesPerHour || 0)),
    registryReads: Math.max(0, Number(registryStats.registryReads || 0) + Number(contract.registryReads || 0) + Number(data.registryReads || 0)),
    registryWrites: Math.max(0, Number(registryStats.registryWrites || 0) + Number(contract.registryWrites || 0) + Number(data.registryWrites || 0)),
    configReads: Math.max(0, Number(contract.configReads || 0) + Number(data.configReads || 0)),
    configWrites: Math.max(0, Number(contract.configWrites || 0) + Number(data.configWrites || 0)),
    targetWritesExecuted: Math.max(0, Number(registryStats.targetWritesExecuted || 0) + Number(contract.targetWritesExecuted || 0) + Number(data.targetWritesExecuted || 0)),
    listeners: Math.max(0, Number(registryStats.listeners || 0) + Number(contract.listeners || 0) + Number(data.listeners || 0)),
    queries: Math.max(0, Number(registryStats.queries || 0) + Number(contract.queries || 0) + Number(data.queries || 0)),
    fanOut: Math.max(0, Number(registryStats.fanOut || 0) + Number(contract.fanOut || 0) + Number(data.fanOut || 0)),
    targetPathBuilt: !!registryStats.targetPathBuilt || !!contract.targetPathBuilt || !!data.targetPathBuilt,
    tenantTargetPathBuilt: !!registryStats.tenantTargetPathBuilt || !!contract.tenantTargetPathBuilt || !!data.tenantTargetPathBuilt,
    tenantConfigTouched: !!registryStats.tenantConfigTouched || !!contract.tenantConfigTouched || !!data.tenantConfigTouched,
    lifecycleTouched: !!registryStats.lifecycleTouched || !!contract.lifecycleTouched || !!data.lifecycleTouched,
    authRuntimeChanged: !!registryStats.authRuntimeChanged || !!contract.authRuntimeChanged || !!data.authRuntimeChanged,
    tenantRoutingActive: !!registryStats.tenantRoutingActive || !!contract.tenantRoutingActive || !!data.tenantRoutingActive,
    schemaChanged: !!registryStats.schemaChanged || !!contract.schemaChanged || !!data.schemaChanged,
    runtimeContractChanged: !!registryStats.runtimeContractChanged || !!contract.runtimeContractChanged || !!data.runtimeContractChanged,
    obsoleteHandlers: obsoleteHandlers,
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };
  var violations = buildMigration3TenantConfigViolations_({
    registryPresent: !!(registryStatus && registryStatus.stats),
    registryOk: statsInput.ok,
    registryVersion: statsInput.registryVersion,
    registryPathPattern: statsInput.registryPathPattern,
    configVersion: statsInput.configVersion,
    configPathPattern: statsInput.configPathPattern,
    configOwner: statsInput.configOwner,
    persistentOwner: statsInput.persistentOwner,
    runtimeReader: statsInput.runtimeReader,
    sourceOfTruth: statsInput.sourceOfTruth,
    tenantIdPattern: statsInput.tenantIdPattern,
    contractDeclared: statsInput.contractDeclared,
    requiredFields: statsInput.requiredFields,
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
  statsInput.reason = violations.length ? 'm3_tenant_config_violation' : 'm3_tenant_config_ready';
  statsInput.violations = violations;
  return buildMigration3TenantConfigResultFromStats_(statsInput);
}

function buildMigration3TenantConfigViolations_(data) {
  data = data || {};
  var violations = [];
  if (!data.registryPresent) violations.push('m3_tenant_registry_status_missing');
  if (data.registryPresent && !data.registryOk) violations.push('m3_tenant_registry_not_ok');
  if (String(data.registryVersion || '') !== PHBOX_M3_TENANT_CONFIG_REQUIRED_REGISTRY_VERSION_) violations.push('m3_tenant_registry_version_mismatch');
  if (String(data.registryPathPattern || '') !== PHBOX_M3_TENANT_CONFIG_REQUIRED_REGISTRY_PATH_PATTERN_) violations.push('m3_tenant_registry_path_mismatch');
  if (String(data.configVersion || '') !== PHBOX_M3_TENANT_CONFIG_VERSION_) violations.push('config_version_mismatch');
  if (String(data.configPathPattern || '') !== PHBOX_M3_TENANT_CONFIG_PATH_PATTERN_) violations.push('config_path_pattern_mismatch');
  if (String(data.configOwner || '') !== PHBOX_M3_TENANT_CONFIG_OWNER_) violations.push('config_owner_mismatch');
  if (String(data.persistentOwner || '') !== PHBOX_M3_TENANT_CONFIG_PERSISTENT_OWNER_) violations.push('persistent_owner_mismatch');
  if (String(data.runtimeReader || '') !== PHBOX_M3_TENANT_CONFIG_RUNTIME_READER_) violations.push('runtime_reader_mismatch');
  if (String(data.sourceOfTruth || '') !== PHBOX_M3_TENANT_CONFIG_SOURCE_OF_TRUTH_) violations.push('source_of_truth_mismatch');
  if (String(data.tenantIdPattern || '') !== PHBOX_M3_TENANT_CONFIG_TENANT_ID_PATTERN_) violations.push('tenant_id_pattern_mismatch');
  if (!data.contractDeclared) violations.push('tenant_config_contract_not_declared');
  migration3TenantConfigMissingItems_(PHBOX_M3_TENANT_CONFIG_REQUIRED_FIELDS_, data.requiredFields || []).forEach(function (field) {
    violations.push('missing_required_field_' + field);
  });
  if (Number(data.firestoreReads || 0) > 0) violations.push('firestore_reads_detected');
  if (Number(data.firestoreWrites || 0) > 0) violations.push('firestore_writes_detected');
  if (Number(data.estimatedReadsPerHour || 0) > 0) violations.push('firestore_reads_per_hour_detected');
  if (Number(data.estimatedWritesPerHour || 0) > 0) violations.push('firestore_writes_per_hour_detected');
  if (Number(data.registryReads || 0) > 0) violations.push('registry_reads_detected');
  if (Number(data.registryWrites || 0) > 0) violations.push('registry_writes_detected');
  if (Number(data.configReads || 0) > 0) violations.push('config_reads_detected');
  if (Number(data.configWrites || 0) > 0) violations.push('config_writes_detected');
  if (Number(data.targetWritesExecuted || 0) > 0) violations.push('target_writes_executed');
  if (Number(data.listeners || 0) > 0) violations.push('listeners_detected');
  if (Number(data.queries || 0) > 0) violations.push('queries_detected');
  if (Number(data.fanOut || 0) > 0) violations.push('fanout_detected');
  if (data.targetPathBuilt) violations.push('target_path_built');
  if (data.tenantTargetPathBuilt) violations.push('tenant_target_path_built');
  if (data.tenantConfigTouched) violations.push('tenant_config_touched');
  if (data.lifecycleTouched) violations.push('lifecycle_touched');
  if (data.authRuntimeChanged) violations.push('auth_runtime_changed');
  if (data.tenantRoutingActive) violations.push('tenant_routing_active');
  if (data.schemaChanged) violations.push('schema_changed');
  if (data.runtimeContractChanged) violations.push('runtime_contract_changed');
  if (uniqueNonEmptyStrings_(data.obsoleteHandlers || []).length > 0) violations.push('obsolete_settings_handlers_detected');
  if (data.error) violations.push('m3_tenant_config_error');
  return uniqueNonEmptyStrings_(violations);
}

function migration3TenantConfigMissingItems_(expected, actual) {
  expected = uniqueNonEmptyStrings_(expected || []);
  actual = uniqueNonEmptyStrings_(actual || []);
  return expected.filter(function (item) { return actual.indexOf(item) === -1; });
}

function buildMigration3TenantConfigResultFromStats_(data) {
  data = data || {};
  var stats = buildMigration3TenantConfigStats_(data);
  return {
    ok: data.ok !== false,
    stats: stats,
    violations: uniqueNonEmptyStrings_(data.violations || []),
    items: data.items || []
  };
}

function buildMigration3TenantConfigStats_(data) {
  data = data || {};
  return {
    stage: PHBOX_M3_TENANT_CONFIG_STAGE_,
    ok: data.ok !== false,
    skipped: data.skipped !== false,
    reason: String(data.reason || ''),
    configVersion: String(data.configVersion || ''),
    requiredRegistryVersion: PHBOX_M3_TENANT_CONFIG_REQUIRED_REGISTRY_VERSION_,
    registryVersion: String(data.registryVersion || ''),
    registryPathPattern: String(data.registryPathPattern || ''),
    configPathPattern: String(data.configPathPattern || ''),
    configOwner: String(data.configOwner || ''),
    persistentOwner: String(data.persistentOwner || ''),
    runtimeReader: String(data.runtimeReader || ''),
    sourceOfTruth: String(data.sourceOfTruth || ''),
    tenantIdPattern: String(data.tenantIdPattern || ''),
    contractDeclared: !!data.contractDeclared,
    requiredFields: uniqueNonEmptyStrings_(data.requiredFields || []),
    optionalFields: uniqueNonEmptyStrings_(data.optionalFields || []),
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

function listMigration3TenantConfigObsoleteSettingsHandlers_() {
  var obsolete = [
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
  if (typeof listMigration3TenantRegistryObsoleteSettingsHandlers_ === 'function') {
    obsolete = obsolete.concat(listMigration3TenantRegistryObsoleteSettingsHandlers_());
  }
  return uniqueNonEmptyStrings_(obsolete);
}

function runMigration3TenantConfigSelfTest_() {
  var cleanContract = buildMigration3TenantConfigContract_();
  var cases = [
    {
      id: 'clean_tenant_registry_authorizes_tenant_config_contract',
      result: buildMigration3TenantConfigResult_({ registryStatus: buildMigration3TenantConfigSyntheticRegistryStatus_({}), contract: cleanContract }),
      expected: { ok: true, violation: '' }
    },
    {
      id: 'missing_tenant_registry_blocks_tenant_config',
      result: buildMigration3TenantConfigResult_({ registryStatus: null, contract: cleanContract }),
      expected: { ok: false, violation: 'm3_tenant_registry_status_missing' }
    },
    {
      id: 'tenant_registry_not_ok_blocks_tenant_config',
      result: buildMigration3TenantConfigResult_({ registryStatus: buildMigration3TenantConfigSyntheticRegistryStatus_({ ok: false }), contract: cleanContract }),
      expected: { ok: false, violation: 'm3_tenant_registry_not_ok' }
    },
    {
      id: 'tenant_registry_version_mismatch_blocks_tenant_config',
      result: buildMigration3TenantConfigResult_({ registryStatus: buildMigration3TenantConfigSyntheticRegistryStatus_({ registryVersion: 'M3_TENANT_REGISTRY_v0' }), contract: cleanContract }),
      expected: { ok: false, violation: 'm3_tenant_registry_version_mismatch' }
    },
    {
      id: 'tenant_registry_path_mismatch_blocks_tenant_config',
      result: buildMigration3TenantConfigResult_({ registryStatus: buildMigration3TenantConfigSyntheticRegistryStatus_({ registryPathPattern: 'tenants/{tenantId}' }), contract: cleanContract }),
      expected: { ok: false, violation: 'm3_tenant_registry_path_mismatch' }
    },
    {
      id: 'config_version_mismatch_blocks_tenant_config',
      result: buildMigration3TenantConfigResult_({ registryStatus: buildMigration3TenantConfigSyntheticRegistryStatus_({}), contract: migration3TenantConfigSyntheticContract_({ configVersion: 'M3_TENANT_CONFIG_v0' }) }),
      expected: { ok: false, violation: 'config_version_mismatch' }
    },
    {
      id: 'config_path_mismatch_blocks_tenant_config',
      result: buildMigration3TenantConfigResult_({ registryStatus: buildMigration3TenantConfigSyntheticRegistryStatus_({}), contract: migration3TenantConfigSyntheticContract_({ configPathPattern: 'tenant_registry/{tenantId}/config/main' }) }),
      expected: { ok: false, violation: 'config_path_pattern_mismatch' }
    },
    {
      id: 'missing_required_field_blocks_tenant_config',
      result: buildMigration3TenantConfigResult_({ registryStatus: buildMigration3TenantConfigSyntheticRegistryStatus_({}), contract: migration3TenantConfigSyntheticContract_({ requiredFields: ['tenantId', 'configVersion'] }) }),
      expected: { ok: false, violation: 'missing_required_field_schemaVersion' }
    },
    {
      id: 'config_contract_not_declared_blocks_tenant_config',
      result: buildMigration3TenantConfigResult_({ registryStatus: buildMigration3TenantConfigSyntheticRegistryStatus_({}), contract: migration3TenantConfigSyntheticContract_({ contractDeclared: false }) }),
      expected: { ok: false, violation: 'tenant_config_contract_not_declared' }
    },
    {
      id: 'config_owner_mismatch_blocks_tenant_config',
      result: buildMigration3TenantConfigResult_({ registryStatus: buildMigration3TenantConfigSyntheticRegistryStatus_({}), contract: migration3TenantConfigSyntheticContract_({ configOwner: 'frontend' }) }),
      expected: { ok: false, violation: 'config_owner_mismatch' }
    },
    {
      id: 'config_read_blocks_tenant_config',
      result: buildMigration3TenantConfigResult_({ registryStatus: buildMigration3TenantConfigSyntheticRegistryStatus_({}), contract: migration3TenantConfigSyntheticContract_({ configReads: 1 }), estimatedReadsPerHour: 1 }),
      expected: { ok: false, violation: 'config_reads_detected' }
    },
    {
      id: 'config_write_blocks_tenant_config',
      result: buildMigration3TenantConfigResult_({ registryStatus: buildMigration3TenantConfigSyntheticRegistryStatus_({}), contract: migration3TenantConfigSyntheticContract_({ configWrites: 1 }), estimatedWritesPerHour: 1 }),
      expected: { ok: false, violation: 'config_writes_detected' }
    },
    {
      id: 'registry_read_or_write_blocks_tenant_config',
      result: buildMigration3TenantConfigResult_({ registryStatus: buildMigration3TenantConfigSyntheticRegistryStatus_({ registryReads: 1, registryWrites: 1 }), contract: cleanContract }),
      expected: { ok: false, violation: 'registry_reads_detected' }
    },
    {
      id: 'listener_query_fanout_blocks_tenant_config',
      result: buildMigration3TenantConfigResult_({ registryStatus: buildMigration3TenantConfigSyntheticRegistryStatus_({ listeners: 1, queries: 1, fanOut: 1 }), contract: cleanContract }),
      expected: { ok: false, violation: 'listeners_detected' }
    },
    {
      id: 'tenant_config_touch_blocks_tenant_config',
      result: buildMigration3TenantConfigResult_({ registryStatus: buildMigration3TenantConfigSyntheticRegistryStatus_({}), contract: migration3TenantConfigSyntheticContract_({ tenantConfigTouched: true }) }),
      expected: { ok: false, violation: 'tenant_config_touched' }
    },
    {
      id: 'auth_or_route_blocks_tenant_config',
      result: buildMigration3TenantConfigResult_({ registryStatus: buildMigration3TenantConfigSyntheticRegistryStatus_({}), contract: migration3TenantConfigSyntheticContract_({ authRuntimeChanged: true, tenantRoutingActive: true }) }),
      expected: { ok: false, violation: 'auth_runtime_changed' }
    },
    {
      id: 'schema_or_runtime_contract_change_blocks_tenant_config',
      result: buildMigration3TenantConfigResult_({ registryStatus: buildMigration3TenantConfigSyntheticRegistryStatus_({}), contract: migration3TenantConfigSyntheticContract_({ schemaChanged: true, runtimeContractChanged: true }) }),
      expected: { ok: false, violation: 'schema_changed' }
    },
    {
      id: 'obsolete_settings_handler_blocks_tenant_config',
      result: buildMigration3TenantConfigResult_({ registryStatus: buildMigration3TenantConfigSyntheticRegistryStatus_({}), contract: cleanContract, obsoleteHandlers: ['runMigration3TenantRegistrySettingsTest'] }),
      expected: { ok: false, violation: 'obsolete_settings_handlers_detected' }
    },
    {
      id: 'runtime_error_blocks_tenant_config',
      result: buildMigration3TenantConfigResult_({ registryStatus: buildMigration3TenantConfigSyntheticRegistryStatus_({}), contract: cleanContract, error: 'synthetic error', errorKind: 'synthetic' }),
      expected: { ok: false, violation: 'm3_tenant_config_error' }
    }
  ];

  var items = cases.map(function (entry) {
    var stats = entry.result.stats || {};
    var violations = uniqueNonEmptyStrings_(stats.violations || []);
    var passed = !!stats.ok === !!entry.expected.ok;
    if (entry.expected.violation) passed = passed && violations.indexOf(entry.expected.violation) !== -1;
    return buildMigration3TenantConfigSelfTestItem_(entry.id, passed, stats);
  });
  var failed = items.filter(function (item) { return !item.passed; });
  return buildMigration3TenantConfigResultFromStats_({
    ok: failed.length === 0,
    skipped: false,
    reason: failed.length ? 'm3_tenant_config_selftest_failed' : 'm3_tenant_config_selftest_passed',
    registryVersion: PHBOX_M3_TENANT_CONFIG_REQUIRED_REGISTRY_VERSION_,
    registryPathPattern: PHBOX_M3_TENANT_CONFIG_REQUIRED_REGISTRY_PATH_PATTERN_,
    configVersion: PHBOX_M3_TENANT_CONFIG_VERSION_,
    configPathPattern: PHBOX_M3_TENANT_CONFIG_PATH_PATTERN_,
    configOwner: PHBOX_M3_TENANT_CONFIG_OWNER_,
    persistentOwner: PHBOX_M3_TENANT_CONFIG_PERSISTENT_OWNER_,
    runtimeReader: PHBOX_M3_TENANT_CONFIG_RUNTIME_READER_,
    sourceOfTruth: PHBOX_M3_TENANT_CONFIG_SOURCE_OF_TRUTH_,
    tenantIdPattern: PHBOX_M3_TENANT_CONFIG_TENANT_ID_PATTERN_,
    contractDeclared: true,
    requiredFields: PHBOX_M3_TENANT_CONFIG_REQUIRED_FIELDS_,
    optionalFields: PHBOX_M3_TENANT_CONFIG_OPTIONAL_FIELDS_,
    items: items,
    violations: failed.map(function (item) { return item.id; })
  });
}

function buildMigration3TenantConfigSelfTestItem_(id, passed, stats) {
  stats = stats || {};
  return {
    id: String(id || ''),
    passed: !!passed,
    ok: !!stats.ok,
    reason: String(stats.reason || ''),
    configVersion: String(stats.configVersion || ''),
    registryVersion: String(stats.registryVersion || ''),
    configPathPattern: String(stats.configPathPattern || ''),
    contractDeclared: !!stats.contractDeclared,
    requiredFieldsCount: uniqueNonEmptyStrings_(stats.requiredFields || []).length,
    optionalFieldsCount: uniqueNonEmptyStrings_(stats.optionalFields || []).length,
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

function buildMigration3TenantConfigSyntheticRegistryStatus_(overrides) {
  overrides = overrides || {};
  var ok = overrides.ok !== false;
  return {
    ok: ok,
    stats: {
      stage: 'migration3_tenant_registry',
      ok: ok,
      reason: ok ? 'm3_tenant_registry_ready' : 'm3_tenant_registry_violation',
      registryVersion: String(overrides.registryVersion || PHBOX_M3_TENANT_CONFIG_REQUIRED_REGISTRY_VERSION_),
      registryPathPattern: String(overrides.registryPathPattern || PHBOX_M3_TENANT_CONFIG_REQUIRED_REGISTRY_PATH_PATTERN_),
      firestoreReads: Math.max(0, Number(overrides.firestoreReads || 0)),
      firestoreWrites: Math.max(0, Number(overrides.firestoreWrites || 0)),
      estimatedReadsPerHour: Math.max(0, Number(overrides.estimatedReadsPerHour || 0)),
      estimatedWritesPerHour: Math.max(0, Number(overrides.estimatedWritesPerHour || 0)),
      registryReads: Math.max(0, Number(overrides.registryReads || 0)),
      registryWrites: Math.max(0, Number(overrides.registryWrites || 0)),
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

function migration3TenantConfigSyntheticContract_(overrides) {
  overrides = overrides || {};
  var contract = buildMigration3TenantConfigContract_();
  Object.keys(overrides).forEach(function (key) {
    contract[key] = overrides[key];
  });
  return contract;
}

function formatMigration3TenantConfigSelfTestFeedback_(result) {
  result = result || {};
  var stats = result.stats || {};
  var lines = [];
  var items = result.items || [];
  var passed = items.filter(function (item) { return !!item.passed; }).length;
  lines.push('MIGRATION_3_TENANT_CONFIG_TEST');
  lines.push('ok=' + String(!!result.ok));
  lines.push('testCount=' + String(items.length));
  lines.push('passedCount=' + String(passed));
  lines.push('failedCount=' + String(items.length - passed));
  migration3TenantConfigAppendCommonFeedbackLines_(lines, stats);
  lines.push('items=');
  items.forEach(function (item) {
    migration3TenantConfigAppendItemFeedbackLines_(lines, item);
  });
  return lines.join('\n');
}

function formatMigration3TenantConfigRuntimeFeedback_(result) {
  result = result || {};
  var stats = result.stats || {};
  var lines = [];
  lines.push('MIGRATION_3_TENANT_CONFIG_RUNTIME_STATUS');
  lines.push('ok=' + String(!!result.ok));
  lines.push('skipped=' + String(!!stats.skipped));
  migration3TenantConfigAppendCommonFeedbackLines_(lines, stats);
  lines.push('obsoleteHandlers=' + migration3TenantConfigJoinList_(stats.obsoleteHandlers));
  lines.push('violations=' + migration3TenantConfigJoinList_(stats.violations));
  lines.push('error=' + (stats.error || 'none'));
  lines.push('errorKind=' + (stats.errorKind || 'none'));
  return lines.join('\n');
}

function migration3TenantConfigAppendCommonFeedbackLines_(lines, stats) {
  stats = stats || {};
  lines.push('reason=' + String(stats.reason || ''));
  lines.push('configVersion=' + String(stats.configVersion || ''));
  lines.push('requiredRegistryVersion=' + String(stats.requiredRegistryVersion || ''));
  lines.push('registryVersion=' + String(stats.registryVersion || ''));
  lines.push('registryPathPattern=' + String(stats.registryPathPattern || ''));
  lines.push('configPathPattern=' + String(stats.configPathPattern || ''));
  lines.push('configOwner=' + String(stats.configOwner || ''));
  lines.push('persistentOwner=' + String(stats.persistentOwner || ''));
  lines.push('runtimeReader=' + String(stats.runtimeReader || ''));
  lines.push('sourceOfTruth=' + String(stats.sourceOfTruth || ''));
  lines.push('tenantIdPattern=' + String(stats.tenantIdPattern || ''));
  lines.push('contractDeclared=' + String(!!stats.contractDeclared));
  lines.push('requiredFieldsCount=' + String(uniqueNonEmptyStrings_(stats.requiredFields || []).length));
  lines.push('optionalFieldsCount=' + String(uniqueNonEmptyStrings_(stats.optionalFields || []).length));
  lines.push('requiredFields=' + migration3TenantConfigJoinList_(stats.requiredFields));
  lines.push('optionalFields=' + migration3TenantConfigJoinList_(stats.optionalFields));
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

function migration3TenantConfigAppendItemFeedbackLines_(lines, item) {
  item = item || {};
  lines.push('- id=' + String(item.id || ''));
  lines.push('  passed=' + String(!!item.passed));
  lines.push('  ok=' + String(!!item.ok));
  lines.push('  reason=' + String(item.reason || ''));
  lines.push('  configVersion=' + String(item.configVersion || ''));
  lines.push('  registryVersion=' + String(item.registryVersion || ''));
  lines.push('  configPathPattern=' + String(item.configPathPattern || ''));
  lines.push('  contractDeclared=' + String(!!item.contractDeclared));
  lines.push('  requiredFieldsCount=' + String(Math.max(0, Number(item.requiredFieldsCount || 0))));
  lines.push('  optionalFieldsCount=' + String(Math.max(0, Number(item.optionalFieldsCount || 0))));
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
  lines.push('  violations=' + migration3TenantConfigJoinList_(item.violations));
}

function migration3TenantConfigJoinList_(value) {
  var items = uniqueNonEmptyStrings_(value || []);
  return items.length ? items.join(',') : 'none';
}
