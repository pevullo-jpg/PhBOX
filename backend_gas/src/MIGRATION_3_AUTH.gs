var PHBOX_M3_AUTH_VERSION_ = 'M3_AUTH_v1';
var PHBOX_M3_AUTH_STAGE_ = 'migration3_auth';
var PHBOX_M3_AUTH_REQUIRED_COST_GUARD_VERSION_ = 'M3_COST_GUARD_v1';
var PHBOX_M3_AUTH_PROVIDER_ = 'google_oauth_contract_only';
var PHBOX_M3_AUTH_IDENTITY_SOURCE_ = 'google_id_token_claims_contract';
var PHBOX_M3_AUTH_TENANT_RESOLVER_ = 'future_tenant_registry_config_lookup';
var PHBOX_M3_AUTH_OWNER_ = 'backend_gas_contract_only';
var PHBOX_M3_AUTH_RUNTIME_OWNER_ = 'future_frontend_google_signin_backend_verifier';
var PHBOX_M3_AUTH_REQUIRED_CLAIMS_ = [
  'sub',
  'email',
  'email_verified',
  'aud',
  'iss',
  'iat',
  'exp'
];
var PHBOX_M3_AUTH_ROLE_VALUES_ = [
  'superback_admin',
  'tenant_admin',
  'tenant_operator'
];
var PHBOX_M3_AUTH_OPTIONAL_CLAIMS_ = [
  'name',
  'picture',
  'hd'
];

function runMigration3AuthRuntimeStatus_() {
  try {
    if (typeof runMigration3CostGuardRuntimeStatus_ !== 'function') {
      throw new Error('M3_AUTH_COST_GUARD_MISSING: funzione runMigration3CostGuardRuntimeStatus_ non disponibile. Auth M3 non autorizzabile.');
    }
    return buildMigration3AuthResult_({
      costGuardStatus: runMigration3CostGuardRuntimeStatus_(),
      contract: buildMigration3AuthContract_(),
      obsoleteHandlers: listMigration3AuthObsoleteSettingsHandlers_()
    });
  } catch (e) {
    return buildMigration3AuthResult_({
      costGuardStatus: null,
      contract: buildMigration3AuthContract_(),
      obsoleteHandlers: listMigration3AuthObsoleteSettingsHandlers_(),
      error: normalizeRuntimeErrorMessage_(e),
      errorKind: classifyRuntimeFailureKind_(e)
    });
  }
}

function buildMigration3AuthContract_() {
  return {
    authVersion: PHBOX_M3_AUTH_VERSION_,
    authOwner: PHBOX_M3_AUTH_OWNER_,
    runtimeOwner: PHBOX_M3_AUTH_RUNTIME_OWNER_,
    authProvider: PHBOX_M3_AUTH_PROVIDER_,
    identitySource: PHBOX_M3_AUTH_IDENTITY_SOURCE_,
    tenantResolver: PHBOX_M3_AUTH_TENANT_RESOLVER_,
    requiredClaims: PHBOX_M3_AUTH_REQUIRED_CLAIMS_.slice(),
    optionalClaims: PHBOX_M3_AUTH_OPTIONAL_CLAIMS_.slice(),
    roleValues: PHBOX_M3_AUTH_ROLE_VALUES_.slice(),
    authContractDeclared: true,
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
    authProviderTouched: false,
    authTokenValidated: false,
    sessionCreated: false,
    tenantRoutingActive: false,
    schemaChanged: false,
    runtimeContractChanged: false
  };
}

function buildMigration3AuthResult_(data) {
  data = data || {};
  var costGuardStatus = data.costGuardStatus || null;
  var costStats = (costGuardStatus && costGuardStatus.stats) || {};
  var contract = data.contract || {};
  var obsoleteHandlers = uniqueNonEmptyStrings_([].concat(
    costStats.obsoleteHandlers || [],
    data.obsoleteHandlers || []
  ));
  var statsInput = {
    ok: !!(costGuardStatus && costGuardStatus.ok) && costStats.ok !== false,
    skipped: false,
    reason: '',
    costGuardVersion: String(costStats.costGuardVersion || ''),
    configVersion: String(costStats.configVersion || ''),
    registryVersion: String(costStats.registryVersion || ''),
    registryPathPattern: String(costStats.registryPathPattern || ''),
    configPathPattern: String(costStats.configPathPattern || ''),
    authVersion: String(contract.authVersion || ''),
    authOwner: String(contract.authOwner || ''),
    runtimeOwner: String(contract.runtimeOwner || ''),
    authProvider: String(contract.authProvider || ''),
    identitySource: String(contract.identitySource || ''),
    tenantResolver: String(contract.tenantResolver || ''),
    authContractDeclared: !!contract.authContractDeclared,
    requiredClaims: uniqueNonEmptyStrings_(contract.requiredClaims || []),
    optionalClaims: uniqueNonEmptyStrings_(contract.optionalClaims || []),
    roleValues: uniqueNonEmptyStrings_(contract.roleValues || []),
    firestoreReads: Math.max(0, Number(costStats.firestoreReads || 0) + Number(contract.firestoreReads || 0) + Number(data.firestoreReads || 0)),
    firestoreWrites: Math.max(0, Number(costStats.firestoreWrites || 0) + Number(contract.firestoreWrites || 0) + Number(data.firestoreWrites || 0)),
    estimatedReadsPerHour: Math.max(0, Number(costStats.estimatedReadsPerHour || 0) + Number(data.estimatedReadsPerHour || 0)),
    estimatedWritesPerHour: Math.max(0, Number(costStats.estimatedWritesPerHour || 0) + Number(data.estimatedWritesPerHour || 0)),
    registryReads: Math.max(0, Number(costStats.registryReads || 0) + Number(contract.registryReads || 0) + Number(data.registryReads || 0)),
    registryWrites: Math.max(0, Number(costStats.registryWrites || 0) + Number(contract.registryWrites || 0) + Number(data.registryWrites || 0)),
    configReads: Math.max(0, Number(costStats.configReads || 0) + Number(contract.configReads || 0) + Number(data.configReads || 0)),
    configWrites: Math.max(0, Number(costStats.configWrites || 0) + Number(contract.configWrites || 0) + Number(data.configWrites || 0)),
    targetWritesExecuted: Math.max(0, Number(costStats.targetWritesExecuted || 0) + Number(contract.targetWritesExecuted || 0) + Number(data.targetWritesExecuted || 0)),
    listeners: Math.max(0, Number(costStats.listeners || 0) + Number(contract.listeners || 0) + Number(data.listeners || 0)),
    queries: Math.max(0, Number(costStats.queries || 0) + Number(contract.queries || 0) + Number(data.queries || 0)),
    fanOut: Math.max(0, Number(costStats.fanOut || 0) + Number(contract.fanOut || 0) + Number(data.fanOut || 0)),
    targetPathBuilt: !!costStats.targetPathBuilt || !!contract.targetPathBuilt || !!data.targetPathBuilt,
    tenantTargetPathBuilt: !!costStats.tenantTargetPathBuilt || !!contract.tenantTargetPathBuilt || !!data.tenantTargetPathBuilt,
    tenantConfigTouched: !!costStats.tenantConfigTouched || !!contract.tenantConfigTouched || !!data.tenantConfigTouched,
    lifecycleTouched: !!costStats.lifecycleTouched || !!contract.lifecycleTouched || !!data.lifecycleTouched,
    authRuntimeChanged: !!costStats.authRuntimeChanged || !!contract.authRuntimeChanged || !!data.authRuntimeChanged,
    authProviderTouched: !!contract.authProviderTouched || !!data.authProviderTouched,
    authTokenValidated: !!contract.authTokenValidated || !!data.authTokenValidated,
    sessionCreated: !!contract.sessionCreated || !!data.sessionCreated,
    tenantRoutingActive: !!costStats.tenantRoutingActive || !!contract.tenantRoutingActive || !!data.tenantRoutingActive,
    schemaChanged: !!costStats.schemaChanged || !!contract.schemaChanged || !!data.schemaChanged,
    runtimeContractChanged: !!costStats.runtimeContractChanged || !!contract.runtimeContractChanged || !!data.runtimeContractChanged,
    obsoleteHandlers: obsoleteHandlers,
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };
  var violations = buildMigration3AuthViolations_({
    costGuardPresent: !!(costGuardStatus && costGuardStatus.stats),
    costGuardOk: statsInput.ok,
    costGuardVersion: statsInput.costGuardVersion,
    authVersion: statsInput.authVersion,
    authOwner: statsInput.authOwner,
    runtimeOwner: statsInput.runtimeOwner,
    authProvider: statsInput.authProvider,
    identitySource: statsInput.identitySource,
    tenantResolver: statsInput.tenantResolver,
    authContractDeclared: statsInput.authContractDeclared,
    requiredClaims: statsInput.requiredClaims,
    roleValues: statsInput.roleValues,
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
    authProviderTouched: statsInput.authProviderTouched,
    authTokenValidated: statsInput.authTokenValidated,
    sessionCreated: statsInput.sessionCreated,
    tenantRoutingActive: statsInput.tenantRoutingActive,
    schemaChanged: statsInput.schemaChanged,
    runtimeContractChanged: statsInput.runtimeContractChanged,
    obsoleteHandlers: obsoleteHandlers,
    error: statsInput.error
  });
  statsInput.ok = violations.length === 0;
  statsInput.reason = violations.length ? 'm3_auth_violation' : 'm3_auth_ready';
  statsInput.violations = violations;
  return buildMigration3AuthResultFromStats_(statsInput);
}

function buildMigration3AuthViolations_(data) {
  data = data || {};
  var violations = [];
  if (!data.costGuardPresent) violations.push('m3_cost_guard_status_missing');
  if (data.costGuardPresent && !data.costGuardOk) violations.push('m3_cost_guard_not_ok');
  if (String(data.costGuardVersion || '') !== PHBOX_M3_AUTH_REQUIRED_COST_GUARD_VERSION_) violations.push('m3_cost_guard_version_mismatch');
  if (String(data.authVersion || '') !== PHBOX_M3_AUTH_VERSION_) violations.push('auth_version_mismatch');
  if (String(data.authOwner || '') !== PHBOX_M3_AUTH_OWNER_) violations.push('auth_owner_mismatch');
  if (String(data.runtimeOwner || '') !== PHBOX_M3_AUTH_RUNTIME_OWNER_) violations.push('auth_runtime_owner_mismatch');
  if (String(data.authProvider || '') !== PHBOX_M3_AUTH_PROVIDER_) violations.push('auth_provider_mismatch');
  if (String(data.identitySource || '') !== PHBOX_M3_AUTH_IDENTITY_SOURCE_) violations.push('identity_source_mismatch');
  if (String(data.tenantResolver || '') !== PHBOX_M3_AUTH_TENANT_RESOLVER_) violations.push('tenant_resolver_mismatch');
  if (!data.authContractDeclared) violations.push('auth_contract_not_declared');
  migration3AuthMissingItems_(PHBOX_M3_AUTH_REQUIRED_CLAIMS_, data.requiredClaims || []).forEach(function (claim) {
    violations.push('missing_required_claim_' + claim);
  });
  migration3AuthMissingItems_(PHBOX_M3_AUTH_ROLE_VALUES_, data.roleValues || []).forEach(function (role) {
    violations.push('missing_role_' + role);
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
  if (data.authProviderTouched) violations.push('auth_provider_touched');
  if (data.authTokenValidated) violations.push('auth_token_validated');
  if (data.sessionCreated) violations.push('session_created');
  if (data.tenantRoutingActive) violations.push('tenant_routing_active');
  if (data.schemaChanged) violations.push('schema_changed');
  if (data.runtimeContractChanged) violations.push('runtime_contract_changed');
  if (uniqueNonEmptyStrings_(data.obsoleteHandlers || []).length > 0) violations.push('obsolete_settings_handlers_detected');
  if (data.error) violations.push('m3_auth_error');
  return uniqueNonEmptyStrings_(violations);
}

function migration3AuthMissingItems_(expected, actual) {
  expected = uniqueNonEmptyStrings_(expected || []);
  actual = uniqueNonEmptyStrings_(actual || []);
  return expected.filter(function (item) { return actual.indexOf(item) === -1; });
}

function buildMigration3AuthResultFromStats_(data) {
  data = data || {};
  var stats = buildMigration3AuthStats_(data);
  return {
    ok: data.ok !== false,
    stats: stats,
    violations: uniqueNonEmptyStrings_(data.violations || []),
    items: data.items || []
  };
}

function buildMigration3AuthStats_(data) {
  data = data || {};
  return {
    stage: PHBOX_M3_AUTH_STAGE_,
    ok: data.ok !== false,
    skipped: data.skipped !== false,
    reason: String(data.reason || ''),
    authVersion: String(data.authVersion || ''),
    requiredCostGuardVersion: PHBOX_M3_AUTH_REQUIRED_COST_GUARD_VERSION_,
    costGuardVersion: String(data.costGuardVersion || ''),
    configVersion: String(data.configVersion || ''),
    registryVersion: String(data.registryVersion || ''),
    registryPathPattern: String(data.registryPathPattern || ''),
    configPathPattern: String(data.configPathPattern || ''),
    authOwner: String(data.authOwner || ''),
    runtimeOwner: String(data.runtimeOwner || ''),
    authProvider: String(data.authProvider || ''),
    identitySource: String(data.identitySource || ''),
    tenantResolver: String(data.tenantResolver || ''),
    authContractDeclared: !!data.authContractDeclared,
    requiredClaims: uniqueNonEmptyStrings_(data.requiredClaims || []),
    optionalClaims: uniqueNonEmptyStrings_(data.optionalClaims || []),
    roleValues: uniqueNonEmptyStrings_(data.roleValues || []),
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
    authProviderTouched: !!data.authProviderTouched,
    authTokenValidated: !!data.authTokenValidated,
    sessionCreated: !!data.sessionCreated,
    tenantRoutingActive: !!data.tenantRoutingActive,
    schemaChanged: !!data.schemaChanged,
    runtimeContractChanged: !!data.runtimeContractChanged,
    obsoleteHandlers: uniqueNonEmptyStrings_(data.obsoleteHandlers || []),
    violations: uniqueNonEmptyStrings_(data.violations || []),
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };
}

function listMigration3AuthObsoleteSettingsHandlers_() {
  var obsolete = [
    'runMigration3CostGuardSettingsTest',
    'getMigration3CostGuardSettingsStatus'
  ].filter(function (name) {
    try {
      if (typeof globalThis !== 'undefined' && typeof globalThis[name] === 'function') return true;
      return typeof this !== 'undefined' && typeof this[name] === 'function';
    } catch (e) {
      return false;
    }
  });
  if (typeof listMigration3CostGuardObsoleteSettingsHandlers_ === 'function') {
    obsolete = obsolete.concat(listMigration3CostGuardObsoleteSettingsHandlers_());
  }
  return uniqueNonEmptyStrings_(obsolete);
}

function runMigration3AuthSelfTest_() {
  var cleanContract = buildMigration3AuthContract_();
  var cases = [
    { id: 'clean_cost_guard_authorizes_auth_contract', result: buildMigration3AuthResult_({ costGuardStatus: buildMigration3AuthSyntheticCostGuardStatus_({}), contract: cleanContract }), expected: { ok: true, violation: '' } },
    { id: 'missing_cost_guard_blocks_auth', result: buildMigration3AuthResult_({ costGuardStatus: null, contract: cleanContract }), expected: { ok: false, violation: 'm3_cost_guard_status_missing' } },
    { id: 'cost_guard_not_ok_blocks_auth', result: buildMigration3AuthResult_({ costGuardStatus: buildMigration3AuthSyntheticCostGuardStatus_({ ok: false }), contract: cleanContract }), expected: { ok: false, violation: 'm3_cost_guard_not_ok' } },
    { id: 'cost_guard_version_mismatch_blocks_auth', result: buildMigration3AuthResult_({ costGuardStatus: buildMigration3AuthSyntheticCostGuardStatus_({ costGuardVersion: 'M3_COST_GUARD_v0' }), contract: cleanContract }), expected: { ok: false, violation: 'm3_cost_guard_version_mismatch' } },
    { id: 'auth_version_mismatch_blocks_auth', result: buildMigration3AuthResult_({ costGuardStatus: buildMigration3AuthSyntheticCostGuardStatus_({}), contract: migration3AuthSyntheticContract_({ authVersion: 'M3_AUTH_v0' }) }), expected: { ok: false, violation: 'auth_version_mismatch' } },
    { id: 'auth_provider_mismatch_blocks_auth', result: buildMigration3AuthResult_({ costGuardStatus: buildMigration3AuthSyntheticCostGuardStatus_({}), contract: migration3AuthSyntheticContract_({ authProvider: 'password_login' }) }), expected: { ok: false, violation: 'auth_provider_mismatch' } },
    { id: 'identity_source_mismatch_blocks_auth', result: buildMigration3AuthResult_({ costGuardStatus: buildMigration3AuthSyntheticCostGuardStatus_({}), contract: migration3AuthSyntheticContract_({ identitySource: 'email_only' }) }), expected: { ok: false, violation: 'identity_source_mismatch' } },
    { id: 'tenant_resolver_mismatch_blocks_auth', result: buildMigration3AuthResult_({ costGuardStatus: buildMigration3AuthSyntheticCostGuardStatus_({}), contract: migration3AuthSyntheticContract_({ tenantResolver: 'frontend_local_storage' }) }), expected: { ok: false, violation: 'tenant_resolver_mismatch' } },
    { id: 'missing_required_claim_blocks_auth', result: buildMigration3AuthResult_({ costGuardStatus: buildMigration3AuthSyntheticCostGuardStatus_({}), contract: migration3AuthSyntheticContract_({ requiredClaims: ['sub', 'email'] }) }), expected: { ok: false, violation: 'missing_required_claim_email_verified' } },
    { id: 'missing_role_value_blocks_auth', result: buildMigration3AuthResult_({ costGuardStatus: buildMigration3AuthSyntheticCostGuardStatus_({}), contract: migration3AuthSyntheticContract_({ roleValues: ['tenant_operator'] }) }), expected: { ok: false, violation: 'missing_role_superback_admin' } },
    { id: 'auth_contract_not_declared_blocks_auth', result: buildMigration3AuthResult_({ costGuardStatus: buildMigration3AuthSyntheticCostGuardStatus_({}), contract: migration3AuthSyntheticContract_({ authContractDeclared: false }) }), expected: { ok: false, violation: 'auth_contract_not_declared' } },
    { id: 'firestore_read_or_write_blocks_auth', result: buildMigration3AuthResult_({ costGuardStatus: buildMigration3AuthSyntheticCostGuardStatus_({ firestoreReads: 1, firestoreWrites: 1 }), contract: cleanContract }), expected: { ok: false, violation: 'firestore_reads_detected' } },
    { id: 'registry_or_config_read_write_blocks_auth', result: buildMigration3AuthResult_({ costGuardStatus: buildMigration3AuthSyntheticCostGuardStatus_({ registryReads: 1, registryWrites: 1, configReads: 1, configWrites: 1 }), contract: cleanContract }), expected: { ok: false, violation: 'registry_reads_detected' } },
    { id: 'listener_query_fanout_blocks_auth', result: buildMigration3AuthResult_({ costGuardStatus: buildMigration3AuthSyntheticCostGuardStatus_({ listeners: 1, queries: 1, fanOut: 1 }), contract: cleanContract }), expected: { ok: false, violation: 'listeners_detected' } },
    { id: 'auth_runtime_blocks_auth', result: buildMigration3AuthResult_({ costGuardStatus: buildMigration3AuthSyntheticCostGuardStatus_({}), contract: migration3AuthSyntheticContract_({ authRuntimeChanged: true, authTokenValidated: true, sessionCreated: true }) }), expected: { ok: false, violation: 'auth_runtime_changed' } },
    { id: 'lifecycle_or_route_blocks_auth', result: buildMigration3AuthResult_({ costGuardStatus: buildMigration3AuthSyntheticCostGuardStatus_({ lifecycleTouched: true, tenantRoutingActive: true }), contract: cleanContract }), expected: { ok: false, violation: 'lifecycle_touched' } },
    { id: 'schema_or_runtime_contract_blocks_auth', result: buildMigration3AuthResult_({ costGuardStatus: buildMigration3AuthSyntheticCostGuardStatus_({}), contract: migration3AuthSyntheticContract_({ schemaChanged: true, runtimeContractChanged: true }) }), expected: { ok: false, violation: 'schema_changed' } },
    { id: 'obsolete_settings_handler_blocks_auth', result: buildMigration3AuthResult_({ costGuardStatus: buildMigration3AuthSyntheticCostGuardStatus_({}), contract: cleanContract, obsoleteHandlers: ['runMigration3CostGuardSettingsTest'] }), expected: { ok: false, violation: 'obsolete_settings_handlers_detected' } },
    { id: 'runtime_error_blocks_auth', result: buildMigration3AuthResult_({ costGuardStatus: buildMigration3AuthSyntheticCostGuardStatus_({}), contract: cleanContract, error: 'synthetic error', errorKind: 'synthetic' }), expected: { ok: false, violation: 'm3_auth_error' } }
  ];
  var items = cases.map(function (entry) {
    var stats = entry.result.stats || {};
    var violations = uniqueNonEmptyStrings_(stats.violations || []);
    var passed = !!stats.ok === !!entry.expected.ok;
    if (entry.expected.violation) passed = passed && violations.indexOf(entry.expected.violation) !== -1;
    return buildMigration3AuthSelfTestItem_(entry.id, passed, stats);
  });
  var failed = items.filter(function (item) { return !item.passed; });
  return buildMigration3AuthResultFromStats_({
    ok: failed.length === 0,
    skipped: false,
    reason: failed.length ? 'm3_auth_selftest_failed' : 'm3_auth_selftest_passed',
    costGuardVersion: PHBOX_M3_AUTH_REQUIRED_COST_GUARD_VERSION_,
    configVersion: 'M3_TENANT_CONFIG_v1',
    registryVersion: 'M3_TENANT_REGISTRY_v1',
    registryPathPattern: 'tenant_registry/{tenantId}',
    configPathPattern: 'tenant_configs/{tenantId}',
    authVersion: PHBOX_M3_AUTH_VERSION_,
    authOwner: PHBOX_M3_AUTH_OWNER_,
    runtimeOwner: PHBOX_M3_AUTH_RUNTIME_OWNER_,
    authProvider: PHBOX_M3_AUTH_PROVIDER_,
    identitySource: PHBOX_M3_AUTH_IDENTITY_SOURCE_,
    tenantResolver: PHBOX_M3_AUTH_TENANT_RESOLVER_,
    authContractDeclared: true,
    requiredClaims: PHBOX_M3_AUTH_REQUIRED_CLAIMS_,
    optionalClaims: PHBOX_M3_AUTH_OPTIONAL_CLAIMS_,
    roleValues: PHBOX_M3_AUTH_ROLE_VALUES_,
    items: items,
    violations: failed.map(function (item) { return item.id; })
  });
}

function buildMigration3AuthSelfTestItem_(id, passed, stats) {
  stats = stats || {};
  return {
    id: String(id || ''),
    passed: !!passed,
    ok: !!stats.ok,
    reason: String(stats.reason || ''),
    authVersion: String(stats.authVersion || ''),
    costGuardVersion: String(stats.costGuardVersion || ''),
    authProvider: String(stats.authProvider || ''),
    authContractDeclared: !!stats.authContractDeclared,
    requiredClaimsCount: uniqueNonEmptyStrings_(stats.requiredClaims || []).length,
    roleValuesCount: uniqueNonEmptyStrings_(stats.roleValues || []).length,
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
    lifecycleTouched: !!stats.lifecycleTouched,
    authRuntimeChanged: !!stats.authRuntimeChanged,
    authProviderTouched: !!stats.authProviderTouched,
    authTokenValidated: !!stats.authTokenValidated,
    sessionCreated: !!stats.sessionCreated,
    tenantRoutingActive: !!stats.tenantRoutingActive,
    schemaChanged: !!stats.schemaChanged,
    runtimeContractChanged: !!stats.runtimeContractChanged,
    violations: uniqueNonEmptyStrings_(stats.violations || [])
  };
}

function buildMigration3AuthSyntheticCostGuardStatus_(overrides) {
  overrides = overrides || {};
  var ok = overrides.ok !== false;
  return {
    ok: ok,
    stats: {
      stage: 'migration3_cost_guard',
      ok: ok,
      reason: ok ? 'm3_cost_guard_ready' : 'm3_cost_guard_violation',
      costGuardVersion: String(overrides.costGuardVersion || PHBOX_M3_AUTH_REQUIRED_COST_GUARD_VERSION_),
      configVersion: String(overrides.configVersion || 'M3_TENANT_CONFIG_v1'),
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

function migration3AuthSyntheticContract_(overrides) {
  overrides = overrides || {};
  var contract = buildMigration3AuthContract_();
  Object.keys(overrides).forEach(function (key) {
    contract[key] = overrides[key];
  });
  return contract;
}

function formatMigration3AuthSelfTestFeedback_(result) {
  result = result || {};
  var stats = result.stats || {};
  var lines = [];
  var items = result.items || [];
  var passed = items.filter(function (item) { return !!item.passed; }).length;
  lines.push('MIGRATION_3_AUTH_TEST');
  lines.push('ok=' + String(!!result.ok));
  lines.push('testCount=' + String(items.length));
  lines.push('passedCount=' + String(passed));
  lines.push('failedCount=' + String(items.length - passed));
  migration3AuthAppendCommonFeedbackLines_(lines, stats);
  lines.push('items=');
  items.forEach(function (item) {
    migration3AuthAppendItemFeedbackLines_(lines, item);
  });
  return lines.join('\n');
}

function formatMigration3AuthRuntimeFeedback_(result) {
  result = result || {};
  var stats = result.stats || {};
  var lines = [];
  lines.push('MIGRATION_3_AUTH_RUNTIME_STATUS');
  lines.push('ok=' + String(!!result.ok));
  lines.push('skipped=' + String(!!stats.skipped));
  migration3AuthAppendCommonFeedbackLines_(lines, stats);
  lines.push('obsoleteHandlers=' + migration3AuthJoinList_(stats.obsoleteHandlers));
  lines.push('violations=' + migration3AuthJoinList_(stats.violations));
  lines.push('error=' + (stats.error || 'none'));
  lines.push('errorKind=' + (stats.errorKind || 'none'));
  return lines.join('\n');
}

function migration3AuthAppendCommonFeedbackLines_(lines, stats) {
  stats = stats || {};
  lines.push('reason=' + String(stats.reason || ''));
  lines.push('authVersion=' + String(stats.authVersion || ''));
  lines.push('requiredCostGuardVersion=' + String(stats.requiredCostGuardVersion || ''));
  lines.push('costGuardVersion=' + String(stats.costGuardVersion || ''));
  lines.push('configVersion=' + String(stats.configVersion || ''));
  lines.push('registryVersion=' + String(stats.registryVersion || ''));
  lines.push('registryPathPattern=' + String(stats.registryPathPattern || ''));
  lines.push('configPathPattern=' + String(stats.configPathPattern || ''));
  lines.push('authOwner=' + String(stats.authOwner || ''));
  lines.push('runtimeOwner=' + String(stats.runtimeOwner || ''));
  lines.push('authProvider=' + String(stats.authProvider || ''));
  lines.push('identitySource=' + String(stats.identitySource || ''));
  lines.push('tenantResolver=' + String(stats.tenantResolver || ''));
  lines.push('authContractDeclared=' + String(!!stats.authContractDeclared));
  lines.push('requiredClaimsCount=' + String(uniqueNonEmptyStrings_(stats.requiredClaims || []).length));
  lines.push('optionalClaimsCount=' + String(uniqueNonEmptyStrings_(stats.optionalClaims || []).length));
  lines.push('roleValuesCount=' + String(uniqueNonEmptyStrings_(stats.roleValues || []).length));
  lines.push('requiredClaims=' + migration3AuthJoinList_(stats.requiredClaims));
  lines.push('roleValues=' + migration3AuthJoinList_(stats.roleValues));
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
  lines.push('authProviderTouched=' + String(!!stats.authProviderTouched));
  lines.push('authTokenValidated=' + String(!!stats.authTokenValidated));
  lines.push('sessionCreated=' + String(!!stats.sessionCreated));
  lines.push('tenantRoutingActive=' + String(!!stats.tenantRoutingActive));
  lines.push('schemaChanged=' + String(!!stats.schemaChanged));
  lines.push('runtimeContractChanged=' + String(!!stats.runtimeContractChanged));
}

function migration3AuthAppendItemFeedbackLines_(lines, item) {
  item = item || {};
  lines.push('- id=' + String(item.id || ''));
  lines.push('  passed=' + String(!!item.passed));
  lines.push('  ok=' + String(!!item.ok));
  lines.push('  reason=' + String(item.reason || ''));
  lines.push('  authVersion=' + String(item.authVersion || ''));
  lines.push('  costGuardVersion=' + String(item.costGuardVersion || ''));
  lines.push('  authProvider=' + String(item.authProvider || ''));
  lines.push('  authContractDeclared=' + String(!!item.authContractDeclared));
  lines.push('  requiredClaimsCount=' + String(Math.max(0, Number(item.requiredClaimsCount || 0))));
  lines.push('  roleValuesCount=' + String(Math.max(0, Number(item.roleValuesCount || 0))));
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
  lines.push('  lifecycleTouched=' + String(!!item.lifecycleTouched));
  lines.push('  authRuntimeChanged=' + String(!!item.authRuntimeChanged));
  lines.push('  authProviderTouched=' + String(!!item.authProviderTouched));
  lines.push('  authTokenValidated=' + String(!!item.authTokenValidated));
  lines.push('  sessionCreated=' + String(!!item.sessionCreated));
  lines.push('  tenantRoutingActive=' + String(!!item.tenantRoutingActive));
  lines.push('  schemaChanged=' + String(!!item.schemaChanged));
  lines.push('  runtimeContractChanged=' + String(!!item.runtimeContractChanged));
  lines.push('  violations=' + migration3AuthJoinList_(item.violations));
}

function migration3AuthJoinList_(value) {
  var items = uniqueNonEmptyStrings_(value || []);
  return items.length ? items.join(',') : 'none';
}
