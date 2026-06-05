var PHBOX_M3_FRONT_ROUTE_VERSION_ = 'M3_FRONT_ROUTE_v1';
var PHBOX_M3_FRONT_ROUTE_STAGE_ = 'migration3_front_route';
var PHBOX_M3_FRONT_ROUTE_REQUIRED_AUTH_VERSION_ = 'M3_AUTH_v1';
var PHBOX_M3_FRONT_ROUTE_OWNER_ = 'frontend_route_contract_only';
var PHBOX_M3_FRONT_ROUTE_RUNTIME_OWNER_ = 'future_frontend_tenant_router';
var PHBOX_M3_FRONT_ROUTE_POLICY_ = 'no_runtime_route_activation_before_backend_route';
var PHBOX_M3_FRONT_ROUTE_ENTRYPOINT_ = 'FarmaciaApp._TenantGate._PhboxShell';
var PHBOX_M3_FRONT_ROUTE_NAVIGATION_MODEL_ = 'appNavigationIndex_contract';
var PHBOX_M3_FRONT_ROUTE_TENANT_RESOLVER_ = 'future_tenant_registry_config_lookup';
var PHBOX_M3_FRONT_ROUTE_ALLOWED_ROUTES_ = [
  'login',
  'access_denied',
  'dashboard',
  'families',
  'settings',
  'target_assistiti_read_only'
];
var PHBOX_M3_FRONT_ROUTE_REQUIRED_INPUTS_ = [
  'authState',
  'tenantAccess',
  'tenantSession',
  'navigationIndex'
];
var PHBOX_M3_FRONT_ROUTE_NAVIGATION_INDICES_ = [
  '0:dashboard',
  '1:families',
  '2:settings',
  '3:target_assistiti_read_only'
];

function runMigration3FrontRouteRuntimeStatus_() {
  try {
    if (typeof runMigration3AuthRuntimeStatus_ !== 'function') {
      throw new Error('M3_FRONT_ROUTE_AUTH_MISSING: funzione runMigration3AuthRuntimeStatus_ non disponibile. Front route non autorizzabile.');
    }
    return buildMigration3FrontRouteResult_({
      authStatus: runMigration3AuthRuntimeStatus_(),
      contract: buildMigration3FrontRouteContract_(),
      obsoleteHandlers: listMigration3FrontRouteObsoleteSettingsHandlers_()
    });
  } catch (e) {
    return buildMigration3FrontRouteResult_({
      authStatus: null,
      contract: buildMigration3FrontRouteContract_(),
      obsoleteHandlers: listMigration3FrontRouteObsoleteSettingsHandlers_(),
      error: normalizeRuntimeErrorMessage_(e),
      errorKind: classifyRuntimeFailureKind_(e)
    });
  }
}

function buildMigration3FrontRouteContract_() {
  return {
    frontRouteVersion: PHBOX_M3_FRONT_ROUTE_VERSION_,
    owner: PHBOX_M3_FRONT_ROUTE_OWNER_,
    runtimeOwner: PHBOX_M3_FRONT_ROUTE_RUNTIME_OWNER_,
    routePolicy: PHBOX_M3_FRONT_ROUTE_POLICY_,
    entrypoint: PHBOX_M3_FRONT_ROUTE_ENTRYPOINT_,
    navigationModel: PHBOX_M3_FRONT_ROUTE_NAVIGATION_MODEL_,
    tenantResolver: PHBOX_M3_FRONT_ROUTE_TENANT_RESOLVER_,
    allowedRoutes: PHBOX_M3_FRONT_ROUTE_ALLOWED_ROUTES_.slice(),
    requiredInputs: PHBOX_M3_FRONT_ROUTE_REQUIRED_INPUTS_.slice(),
    navigationIndices: PHBOX_M3_FRONT_ROUTE_NAVIGATION_INDICES_.slice(),
    routeContractDeclared: true,
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
    frontRouteRuntimeChanged: false,
    routeResolved: false,
    navigationChanged: false,
    schemaChanged: false,
    runtimeContractChanged: false
  };
}

function buildMigration3FrontRouteResult_(data) {
  data = data || {};
  var authStatus = data.authStatus || null;
  var authStats = (authStatus && authStatus.stats) || {};
  var contract = data.contract || {};
  var obsoleteHandlers = uniqueNonEmptyStrings_([].concat(
    authStats.obsoleteHandlers || [],
    data.obsoleteHandlers || []
  ));
  var statsInput = {
    ok: !!(authStatus && authStatus.ok) && authStats.ok !== false,
    skipped: false,
    reason: '',
    authVersion: String(authStats.authVersion || ''),
    costGuardVersion: String(authStats.costGuardVersion || ''),
    configVersion: String(authStats.configVersion || ''),
    registryVersion: String(authStats.registryVersion || ''),
    frontRouteVersion: String(contract.frontRouteVersion || ''),
    frontRouteOwner: String(contract.owner || ''),
    runtimeOwner: String(contract.runtimeOwner || ''),
    routePolicy: String(contract.routePolicy || ''),
    entrypoint: String(contract.entrypoint || ''),
    navigationModel: String(contract.navigationModel || ''),
    tenantResolver: String(contract.tenantResolver || ''),
    routeContractDeclared: !!contract.routeContractDeclared,
    allowedRoutes: uniqueNonEmptyStrings_(contract.allowedRoutes || []),
    requiredInputs: uniqueNonEmptyStrings_(contract.requiredInputs || []),
    navigationIndices: uniqueNonEmptyStrings_(contract.navigationIndices || []),
    firestoreReads: Math.max(0, Number(authStats.firestoreReads || 0) + Number(contract.firestoreReads || 0) + Number(data.firestoreReads || 0)),
    firestoreWrites: Math.max(0, Number(authStats.firestoreWrites || 0) + Number(contract.firestoreWrites || 0) + Number(data.firestoreWrites || 0)),
    estimatedReadsPerHour: Math.max(0, Number(authStats.estimatedReadsPerHour || 0) + Number(data.estimatedReadsPerHour || 0)),
    estimatedWritesPerHour: Math.max(0, Number(authStats.estimatedWritesPerHour || 0) + Number(data.estimatedWritesPerHour || 0)),
    registryReads: Math.max(0, Number(authStats.registryReads || 0) + Number(contract.registryReads || 0) + Number(data.registryReads || 0)),
    registryWrites: Math.max(0, Number(authStats.registryWrites || 0) + Number(contract.registryWrites || 0) + Number(data.registryWrites || 0)),
    configReads: Math.max(0, Number(authStats.configReads || 0) + Number(contract.configReads || 0) + Number(data.configReads || 0)),
    configWrites: Math.max(0, Number(authStats.configWrites || 0) + Number(contract.configWrites || 0) + Number(data.configWrites || 0)),
    targetWritesExecuted: Math.max(0, Number(authStats.targetWritesExecuted || 0) + Number(contract.targetWritesExecuted || 0) + Number(data.targetWritesExecuted || 0)),
    listeners: Math.max(0, Number(authStats.listeners || 0) + Number(contract.listeners || 0) + Number(data.listeners || 0)),
    queries: Math.max(0, Number(authStats.queries || 0) + Number(contract.queries || 0) + Number(data.queries || 0)),
    fanOut: Math.max(0, Number(authStats.fanOut || 0) + Number(contract.fanOut || 0) + Number(data.fanOut || 0)),
    targetPathBuilt: !!authStats.targetPathBuilt || !!contract.targetPathBuilt || !!data.targetPathBuilt,
    tenantTargetPathBuilt: !!authStats.tenantTargetPathBuilt || !!contract.tenantTargetPathBuilt || !!data.tenantTargetPathBuilt,
    tenantConfigTouched: !!authStats.tenantConfigTouched || !!contract.tenantConfigTouched || !!data.tenantConfigTouched,
    lifecycleTouched: !!authStats.lifecycleTouched || !!contract.lifecycleTouched || !!data.lifecycleTouched,
    authRuntimeChanged: !!authStats.authRuntimeChanged || !!contract.authRuntimeChanged || !!data.authRuntimeChanged,
    authProviderTouched: !!authStats.authProviderTouched || !!contract.authProviderTouched || !!data.authProviderTouched,
    authTokenValidated: !!authStats.authTokenValidated || !!contract.authTokenValidated || !!data.authTokenValidated,
    sessionCreated: !!authStats.sessionCreated || !!contract.sessionCreated || !!data.sessionCreated,
    tenantRoutingActive: !!authStats.tenantRoutingActive || !!contract.tenantRoutingActive || !!data.tenantRoutingActive,
    frontRouteRuntimeChanged: !!contract.frontRouteRuntimeChanged || !!data.frontRouteRuntimeChanged,
    routeResolved: !!contract.routeResolved || !!data.routeResolved,
    navigationChanged: !!contract.navigationChanged || !!data.navigationChanged,
    schemaChanged: !!authStats.schemaChanged || !!contract.schemaChanged || !!data.schemaChanged,
    runtimeContractChanged: !!authStats.runtimeContractChanged || !!contract.runtimeContractChanged || !!data.runtimeContractChanged,
    obsoleteHandlers: obsoleteHandlers,
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };
  var violations = buildMigration3FrontRouteViolations_({
    authPresent: !!(authStatus && authStatus.stats),
    authOk: statsInput.ok,
    authVersion: statsInput.authVersion,
    frontRouteVersion: statsInput.frontRouteVersion,
    frontRouteOwner: statsInput.frontRouteOwner,
    runtimeOwner: statsInput.runtimeOwner,
    routePolicy: statsInput.routePolicy,
    entrypoint: statsInput.entrypoint,
    navigationModel: statsInput.navigationModel,
    tenantResolver: statsInput.tenantResolver,
    routeContractDeclared: statsInput.routeContractDeclared,
    allowedRoutes: statsInput.allowedRoutes,
    requiredInputs: statsInput.requiredInputs,
    navigationIndices: statsInput.navigationIndices,
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
    frontRouteRuntimeChanged: statsInput.frontRouteRuntimeChanged,
    routeResolved: statsInput.routeResolved,
    navigationChanged: statsInput.navigationChanged,
    schemaChanged: statsInput.schemaChanged,
    runtimeContractChanged: statsInput.runtimeContractChanged,
    obsoleteHandlers: obsoleteHandlers,
    error: statsInput.error
  });
  statsInput.ok = violations.length === 0;
  statsInput.reason = violations.length ? 'm3_front_route_violation' : 'm3_front_route_ready';
  statsInput.violations = violations;
  return buildMigration3FrontRouteResultFromStats_(statsInput);
}

function buildMigration3FrontRouteViolations_(data) {
  data = data || {};
  var violations = [];
  if (!data.authPresent) violations.push('m3_auth_status_missing');
  if (data.authPresent && !data.authOk) violations.push('m3_auth_not_ok');
  if (String(data.authVersion || '') !== PHBOX_M3_FRONT_ROUTE_REQUIRED_AUTH_VERSION_) violations.push('m3_auth_version_mismatch');
  if (String(data.frontRouteVersion || '') !== PHBOX_M3_FRONT_ROUTE_VERSION_) violations.push('front_route_version_mismatch');
  if (String(data.frontRouteOwner || '') !== PHBOX_M3_FRONT_ROUTE_OWNER_) violations.push('front_route_owner_mismatch');
  if (String(data.runtimeOwner || '') !== PHBOX_M3_FRONT_ROUTE_RUNTIME_OWNER_) violations.push('front_route_runtime_owner_mismatch');
  if (String(data.routePolicy || '') !== PHBOX_M3_FRONT_ROUTE_POLICY_) violations.push('front_route_policy_mismatch');
  if (String(data.entrypoint || '') !== PHBOX_M3_FRONT_ROUTE_ENTRYPOINT_) violations.push('front_route_entrypoint_mismatch');
  if (String(data.navigationModel || '') !== PHBOX_M3_FRONT_ROUTE_NAVIGATION_MODEL_) violations.push('front_route_navigation_model_mismatch');
  if (String(data.tenantResolver || '') !== PHBOX_M3_FRONT_ROUTE_TENANT_RESOLVER_) violations.push('front_route_tenant_resolver_mismatch');
  if (!data.routeContractDeclared) violations.push('front_route_contract_not_declared');
  migration3FrontRouteMissingItems_(PHBOX_M3_FRONT_ROUTE_ALLOWED_ROUTES_, data.allowedRoutes || []).forEach(function (route) {
    violations.push('missing_route_' + route);
  });
  migration3FrontRouteMissingItems_(PHBOX_M3_FRONT_ROUTE_REQUIRED_INPUTS_, data.requiredInputs || []).forEach(function (input) {
    violations.push('missing_required_input_' + input);
  });
  migration3FrontRouteMissingItems_(PHBOX_M3_FRONT_ROUTE_NAVIGATION_INDICES_, data.navigationIndices || []).forEach(function (index) {
    violations.push('missing_navigation_index_' + index.replace(/[^a-zA-Z0-9]+/g, '_'));
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
  if (data.frontRouteRuntimeChanged) violations.push('front_route_runtime_changed');
  if (data.routeResolved) violations.push('front_route_resolved');
  if (data.navigationChanged) violations.push('navigation_changed');
  if (data.schemaChanged) violations.push('schema_changed');
  if (data.runtimeContractChanged) violations.push('runtime_contract_changed');
  if (uniqueNonEmptyStrings_(data.obsoleteHandlers || []).length > 0) violations.push('obsolete_settings_handlers_detected');
  if (data.error) violations.push('m3_front_route_error');
  return uniqueNonEmptyStrings_(violations);
}

function migration3FrontRouteMissingItems_(expected, actual) {
  expected = uniqueNonEmptyStrings_(expected || []);
  actual = uniqueNonEmptyStrings_(actual || []);
  return expected.filter(function (item) { return actual.indexOf(item) === -1; });
}

function buildMigration3FrontRouteResultFromStats_(data) {
  data = data || {};
  var stats = buildMigration3FrontRouteStats_(data);
  return {
    ok: data.ok !== false,
    stats: stats,
    violations: uniqueNonEmptyStrings_(data.violations || []),
    items: data.items || []
  };
}

function buildMigration3FrontRouteStats_(data) {
  data = data || {};
  return {
    stage: PHBOX_M3_FRONT_ROUTE_STAGE_,
    ok: data.ok !== false,
    skipped: data.skipped !== false,
    reason: String(data.reason || ''),
    frontRouteVersion: String(data.frontRouteVersion || ''),
    requiredAuthVersion: PHBOX_M3_FRONT_ROUTE_REQUIRED_AUTH_VERSION_,
    authVersion: String(data.authVersion || ''),
    costGuardVersion: String(data.costGuardVersion || ''),
    configVersion: String(data.configVersion || ''),
    registryVersion: String(data.registryVersion || ''),
    frontRouteOwner: String(data.frontRouteOwner || ''),
    runtimeOwner: String(data.runtimeOwner || ''),
    routePolicy: String(data.routePolicy || ''),
    entrypoint: String(data.entrypoint || ''),
    navigationModel: String(data.navigationModel || ''),
    tenantResolver: String(data.tenantResolver || ''),
    routeContractDeclared: !!data.routeContractDeclared,
    allowedRoutes: uniqueNonEmptyStrings_(data.allowedRoutes || []),
    requiredInputs: uniqueNonEmptyStrings_(data.requiredInputs || []),
    navigationIndices: uniqueNonEmptyStrings_(data.navigationIndices || []),
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
    frontRouteRuntimeChanged: !!data.frontRouteRuntimeChanged,
    routeResolved: !!data.routeResolved,
    navigationChanged: !!data.navigationChanged,
    schemaChanged: !!data.schemaChanged,
    runtimeContractChanged: !!data.runtimeContractChanged,
    obsoleteHandlers: uniqueNonEmptyStrings_(data.obsoleteHandlers || []),
    violations: uniqueNonEmptyStrings_(data.violations || []),
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };
}

function listMigration3FrontRouteObsoleteSettingsHandlers_() {
  var obsolete = [
    'runMigration3AuthSettingsTest',
    'getMigration3AuthSettingsStatus'
  ].filter(function (name) {
    try {
      if (typeof globalThis !== 'undefined' && typeof globalThis[name] === 'function') return true;
      return typeof this !== 'undefined' && typeof this[name] === 'function';
    } catch (e) {
      return false;
    }
  });
  if (typeof listMigration3AuthObsoleteSettingsHandlers_ === 'function') {
    obsolete = obsolete.concat(listMigration3AuthObsoleteSettingsHandlers_());
  }
  return uniqueNonEmptyStrings_(obsolete);
}

function runMigration3FrontRouteSelfTest_() {
  var cleanContract = buildMigration3FrontRouteContract_();
  var cases = [
    {
      id: 'clean_auth_authorizes_front_route_contract',
      result: buildMigration3FrontRouteResult_({ authStatus: buildMigration3FrontRouteSyntheticAuthStatus_({}), contract: cleanContract }),
      expected: { ok: true, violation: '' }
    },
    {
      id: 'missing_auth_blocks_front_route',
      result: buildMigration3FrontRouteResult_({ authStatus: null, contract: cleanContract }),
      expected: { ok: false, violation: 'm3_auth_status_missing' }
    },
    {
      id: 'auth_not_ok_blocks_front_route',
      result: buildMigration3FrontRouteResult_({ authStatus: buildMigration3FrontRouteSyntheticAuthStatus_({ ok: false }), contract: cleanContract }),
      expected: { ok: false, violation: 'm3_auth_not_ok' }
    },
    {
      id: 'auth_version_mismatch_blocks_front_route',
      result: buildMigration3FrontRouteResult_({ authStatus: buildMigration3FrontRouteSyntheticAuthStatus_({ authVersion: 'M3_AUTH_v0' }), contract: cleanContract }),
      expected: { ok: false, violation: 'm3_auth_version_mismatch' }
    },
    {
      id: 'front_route_version_mismatch_blocks_front_route',
      result: buildMigration3FrontRouteResult_({ authStatus: buildMigration3FrontRouteSyntheticAuthStatus_({}), contract: migration3FrontRouteSyntheticContract_({ frontRouteVersion: 'M3_FRONT_ROUTE_v0' }) }),
      expected: { ok: false, violation: 'front_route_version_mismatch' }
    },
    {
      id: 'front_route_owner_mismatch_blocks_front_route',
      result: buildMigration3FrontRouteResult_({ authStatus: buildMigration3FrontRouteSyntheticAuthStatus_({}), contract: migration3FrontRouteSyntheticContract_({ owner: 'backend_runtime_router' }) }),
      expected: { ok: false, violation: 'front_route_owner_mismatch' }
    },
    {
      id: 'route_policy_mismatch_blocks_front_route',
      result: buildMigration3FrontRouteResult_({ authStatus: buildMigration3FrontRouteSyntheticAuthStatus_({}), contract: migration3FrontRouteSyntheticContract_({ routePolicy: 'activate_runtime_routes' }) }),
      expected: { ok: false, violation: 'front_route_policy_mismatch' }
    },
    {
      id: 'route_contract_not_declared_blocks_front_route',
      result: buildMigration3FrontRouteResult_({ authStatus: buildMigration3FrontRouteSyntheticAuthStatus_({}), contract: migration3FrontRouteSyntheticContract_({ routeContractDeclared: false }) }),
      expected: { ok: false, violation: 'front_route_contract_not_declared' }
    },
    {
      id: 'missing_route_blocks_front_route',
      result: buildMigration3FrontRouteResult_({ authStatus: buildMigration3FrontRouteSyntheticAuthStatus_({}), contract: migration3FrontRouteSyntheticContract_({ allowedRoutes: ['login', 'dashboard'] }) }),
      expected: { ok: false, violation: 'missing_route_access_denied' }
    },
    {
      id: 'missing_required_input_blocks_front_route',
      result: buildMigration3FrontRouteResult_({ authStatus: buildMigration3FrontRouteSyntheticAuthStatus_({}), contract: migration3FrontRouteSyntheticContract_({ requiredInputs: ['authState'] }) }),
      expected: { ok: false, violation: 'missing_required_input_tenantAccess' }
    },
    {
      id: 'missing_navigation_index_blocks_front_route',
      result: buildMigration3FrontRouteResult_({ authStatus: buildMigration3FrontRouteSyntheticAuthStatus_({}), contract: migration3FrontRouteSyntheticContract_({ navigationIndices: ['0:dashboard'] }) }),
      expected: { ok: false, violation: 'missing_navigation_index_1_families' }
    },
    {
      id: 'firestore_read_or_write_blocks_front_route',
      result: buildMigration3FrontRouteResult_({ authStatus: buildMigration3FrontRouteSyntheticAuthStatus_({ firestoreReads: 1, firestoreWrites: 1 }), contract: cleanContract }),
      expected: { ok: false, violation: 'firestore_reads_detected' }
    },
    {
      id: 'registry_or_config_read_write_blocks_front_route',
      result: buildMigration3FrontRouteResult_({ authStatus: buildMigration3FrontRouteSyntheticAuthStatus_({ registryReads: 1, registryWrites: 1, configReads: 1, configWrites: 1 }), contract: cleanContract }),
      expected: { ok: false, violation: 'registry_reads_detected' }
    },
    {
      id: 'listener_query_fanout_blocks_front_route',
      result: buildMigration3FrontRouteResult_({ authStatus: buildMigration3FrontRouteSyntheticAuthStatus_({ listeners: 1, queries: 1, fanOut: 1 }), contract: cleanContract }),
      expected: { ok: false, violation: 'listeners_detected' }
    },
    {
      id: 'target_or_tenant_path_blocks_front_route',
      result: buildMigration3FrontRouteResult_({ authStatus: buildMigration3FrontRouteSyntheticAuthStatus_({ targetPathBuilt: true, tenantTargetPathBuilt: true }), contract: cleanContract }),
      expected: { ok: false, violation: 'target_path_built' }
    },
    {
      id: 'auth_runtime_blocks_front_route',
      result: buildMigration3FrontRouteResult_({ authStatus: buildMigration3FrontRouteSyntheticAuthStatus_({ authRuntimeChanged: true, authTokenValidated: true, sessionCreated: true }), contract: cleanContract }),
      expected: { ok: false, violation: 'auth_runtime_changed' }
    },
    {
      id: 'front_route_runtime_blocks_front_route',
      result: buildMigration3FrontRouteResult_({ authStatus: buildMigration3FrontRouteSyntheticAuthStatus_({}), contract: migration3FrontRouteSyntheticContract_({ frontRouteRuntimeChanged: true, routeResolved: true, navigationChanged: true }) }),
      expected: { ok: false, violation: 'front_route_runtime_changed' }
    },
    {
      id: 'lifecycle_or_route_blocks_front_route',
      result: buildMigration3FrontRouteResult_({ authStatus: buildMigration3FrontRouteSyntheticAuthStatus_({ lifecycleTouched: true, tenantRoutingActive: true }), contract: cleanContract }),
      expected: { ok: false, violation: 'lifecycle_touched' }
    },
    {
      id: 'schema_or_runtime_contract_blocks_front_route',
      result: buildMigration3FrontRouteResult_({ authStatus: buildMigration3FrontRouteSyntheticAuthStatus_({ schemaChanged: true, runtimeContractChanged: true }), contract: cleanContract }),
      expected: { ok: false, violation: 'schema_changed' }
    },
    {
      id: 'obsolete_settings_handler_blocks_front_route',
      result: buildMigration3FrontRouteResult_({ authStatus: buildMigration3FrontRouteSyntheticAuthStatus_({}), contract: cleanContract, obsoleteHandlers: ['runMigration3AuthSettingsTest'] }),
      expected: { ok: false, violation: 'obsolete_settings_handlers_detected' }
    },
    {
      id: 'runtime_error_blocks_front_route',
      result: buildMigration3FrontRouteResult_({ authStatus: buildMigration3FrontRouteSyntheticAuthStatus_({}), contract: cleanContract, error: 'synthetic error', errorKind: 'synthetic' }),
      expected: { ok: false, violation: 'm3_front_route_error' }
    }
  ];

  var items = cases.map(function (entry) {
    var stats = entry.result.stats || {};
    var violations = uniqueNonEmptyStrings_(stats.violations || []);
    var passed = !!stats.ok === !!entry.expected.ok;
    if (entry.expected.violation) passed = passed && violations.indexOf(entry.expected.violation) !== -1;
    return buildMigration3FrontRouteSelfTestItem_(entry.id, passed, stats);
  });
  var failed = items.filter(function (item) { return !item.passed; });
  return buildMigration3FrontRouteResultFromStats_({
    ok: failed.length === 0,
    skipped: false,
    reason: failed.length ? 'm3_front_route_selftest_failed' : 'm3_front_route_selftest_passed',
    frontRouteVersion: PHBOX_M3_FRONT_ROUTE_VERSION_,
    authVersion: PHBOX_M3_FRONT_ROUTE_REQUIRED_AUTH_VERSION_,
    frontRouteOwner: PHBOX_M3_FRONT_ROUTE_OWNER_,
    runtimeOwner: PHBOX_M3_FRONT_ROUTE_RUNTIME_OWNER_,
    routePolicy: PHBOX_M3_FRONT_ROUTE_POLICY_,
    entrypoint: PHBOX_M3_FRONT_ROUTE_ENTRYPOINT_,
    navigationModel: PHBOX_M3_FRONT_ROUTE_NAVIGATION_MODEL_,
    tenantResolver: PHBOX_M3_FRONT_ROUTE_TENANT_RESOLVER_,
    routeContractDeclared: true,
    allowedRoutes: PHBOX_M3_FRONT_ROUTE_ALLOWED_ROUTES_,
    requiredInputs: PHBOX_M3_FRONT_ROUTE_REQUIRED_INPUTS_,
    navigationIndices: PHBOX_M3_FRONT_ROUTE_NAVIGATION_INDICES_,
    items: items,
    violations: failed.map(function (item) { return item.id; })
  });
}

function buildMigration3FrontRouteSelfTestItem_(id, passed, stats) {
  stats = stats || {};
  return {
    id: String(id || ''),
    passed: !!passed,
    ok: !!stats.ok,
    reason: String(stats.reason || ''),
    frontRouteVersion: String(stats.frontRouteVersion || ''),
    authVersion: String(stats.authVersion || ''),
    routePolicy: String(stats.routePolicy || ''),
    routeContractDeclared: !!stats.routeContractDeclared,
    allowedRoutesCount: uniqueNonEmptyStrings_(stats.allowedRoutes || []).length,
    requiredInputsCount: uniqueNonEmptyStrings_(stats.requiredInputs || []).length,
    navigationIndicesCount: uniqueNonEmptyStrings_(stats.navigationIndices || []).length,
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
    authTokenValidated: !!stats.authTokenValidated,
    sessionCreated: !!stats.sessionCreated,
    tenantRoutingActive: !!stats.tenantRoutingActive,
    frontRouteRuntimeChanged: !!stats.frontRouteRuntimeChanged,
    routeResolved: !!stats.routeResolved,
    navigationChanged: !!stats.navigationChanged,
    schemaChanged: !!stats.schemaChanged,
    runtimeContractChanged: !!stats.runtimeContractChanged,
    violations: uniqueNonEmptyStrings_(stats.violations || [])
  };
}

function buildMigration3FrontRouteSyntheticAuthStatus_(overrides) {
  overrides = overrides || {};
  var ok = overrides.ok !== false;
  return {
    ok: ok,
    stats: {
      stage: 'migration3_auth',
      ok: ok,
      reason: ok ? 'm3_auth_ready' : 'm3_auth_violation',
      authVersion: String(overrides.authVersion || PHBOX_M3_FRONT_ROUTE_REQUIRED_AUTH_VERSION_),
      costGuardVersion: String(overrides.costGuardVersion || 'M3_COST_GUARD_v1'),
      configVersion: String(overrides.configVersion || 'M3_TENANT_CONFIG_v1'),
      registryVersion: String(overrides.registryVersion || 'M3_TENANT_REGISTRY_v1'),
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
      authProviderTouched: !!overrides.authProviderTouched,
      authTokenValidated: !!overrides.authTokenValidated,
      sessionCreated: !!overrides.sessionCreated,
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

function migration3FrontRouteSyntheticContract_(overrides) {
  overrides = overrides || {};
  var contract = buildMigration3FrontRouteContract_();
  Object.keys(overrides).forEach(function (key) {
    contract[key] = overrides[key];
  });
  return contract;
}

function formatMigration3FrontRouteSelfTestFeedback_(result) {
  result = result || {};
  var stats = result.stats || {};
  var lines = [];
  var items = result.items || [];
  var passed = items.filter(function (item) { return !!item.passed; }).length;
  lines.push('MIGRATION_3_FRONT_ROUTE_TEST');
  lines.push('ok=' + String(!!result.ok));
  lines.push('testCount=' + String(items.length));
  lines.push('passedCount=' + String(passed));
  lines.push('failedCount=' + String(items.length - passed));
  migration3FrontRouteAppendCommonFeedbackLines_(lines, stats);
  lines.push('items=');
  items.forEach(function (item) {
    migration3FrontRouteAppendItemFeedbackLines_(lines, item);
  });
  return lines.join('\n');
}

function formatMigration3FrontRouteRuntimeFeedback_(result) {
  result = result || {};
  var stats = result.stats || {};
  var lines = [];
  lines.push('MIGRATION_3_FRONT_ROUTE_RUNTIME_STATUS');
  lines.push('ok=' + String(!!result.ok));
  lines.push('skipped=' + String(!!stats.skipped));
  migration3FrontRouteAppendCommonFeedbackLines_(lines, stats);
  lines.push('obsoleteHandlers=' + migration3FrontRouteJoinList_(stats.obsoleteHandlers));
  lines.push('violations=' + migration3FrontRouteJoinList_(stats.violations));
  lines.push('error=' + (stats.error || 'none'));
  lines.push('errorKind=' + (stats.errorKind || 'none'));
  return lines.join('\n');
}

function migration3FrontRouteAppendCommonFeedbackLines_(lines, stats) {
  stats = stats || {};
  lines.push('reason=' + String(stats.reason || ''));
  lines.push('frontRouteVersion=' + String(stats.frontRouteVersion || ''));
  lines.push('requiredAuthVersion=' + String(stats.requiredAuthVersion || ''));
  lines.push('authVersion=' + String(stats.authVersion || ''));
  lines.push('costGuardVersion=' + String(stats.costGuardVersion || ''));
  lines.push('configVersion=' + String(stats.configVersion || ''));
  lines.push('registryVersion=' + String(stats.registryVersion || ''));
  lines.push('frontRouteOwner=' + String(stats.frontRouteOwner || ''));
  lines.push('runtimeOwner=' + String(stats.runtimeOwner || ''));
  lines.push('routePolicy=' + String(stats.routePolicy || ''));
  lines.push('entrypoint=' + String(stats.entrypoint || ''));
  lines.push('navigationModel=' + String(stats.navigationModel || ''));
  lines.push('tenantResolver=' + String(stats.tenantResolver || ''));
  lines.push('routeContractDeclared=' + String(!!stats.routeContractDeclared));
  lines.push('allowedRoutesCount=' + String(uniqueNonEmptyStrings_(stats.allowedRoutes || []).length));
  lines.push('requiredInputsCount=' + String(uniqueNonEmptyStrings_(stats.requiredInputs || []).length));
  lines.push('navigationIndicesCount=' + String(uniqueNonEmptyStrings_(stats.navigationIndices || []).length));
  lines.push('allowedRoutes=' + migration3FrontRouteJoinList_(stats.allowedRoutes));
  lines.push('requiredInputs=' + migration3FrontRouteJoinList_(stats.requiredInputs));
  lines.push('navigationIndices=' + migration3FrontRouteJoinList_(stats.navigationIndices));
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
  lines.push('frontRouteRuntimeChanged=' + String(!!stats.frontRouteRuntimeChanged));
  lines.push('routeResolved=' + String(!!stats.routeResolved));
  lines.push('navigationChanged=' + String(!!stats.navigationChanged));
  lines.push('schemaChanged=' + String(!!stats.schemaChanged));
  lines.push('runtimeContractChanged=' + String(!!stats.runtimeContractChanged));
}

function migration3FrontRouteAppendItemFeedbackLines_(lines, item) {
  item = item || {};
  lines.push('- id=' + String(item.id || ''));
  lines.push('  passed=' + String(!!item.passed));
  lines.push('  ok=' + String(!!item.ok));
  lines.push('  reason=' + String(item.reason || ''));
  lines.push('  frontRouteVersion=' + String(item.frontRouteVersion || ''));
  lines.push('  authVersion=' + String(item.authVersion || ''));
  lines.push('  routePolicy=' + String(item.routePolicy || ''));
  lines.push('  routeContractDeclared=' + String(!!item.routeContractDeclared));
  lines.push('  allowedRoutesCount=' + String(Math.max(0, Number(item.allowedRoutesCount || 0))));
  lines.push('  requiredInputsCount=' + String(Math.max(0, Number(item.requiredInputsCount || 0))));
  lines.push('  navigationIndicesCount=' + String(Math.max(0, Number(item.navigationIndicesCount || 0))));
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
  lines.push('  authTokenValidated=' + String(!!item.authTokenValidated));
  lines.push('  sessionCreated=' + String(!!item.sessionCreated));
  lines.push('  tenantRoutingActive=' + String(!!item.tenantRoutingActive));
  lines.push('  frontRouteRuntimeChanged=' + String(!!item.frontRouteRuntimeChanged));
  lines.push('  routeResolved=' + String(!!item.routeResolved));
  lines.push('  navigationChanged=' + String(!!item.navigationChanged));
  lines.push('  schemaChanged=' + String(!!item.schemaChanged));
  lines.push('  runtimeContractChanged=' + String(!!item.runtimeContractChanged));
  lines.push('  violations=' + migration3FrontRouteJoinList_(item.violations));
}

function migration3FrontRouteJoinList_(value) {
  var items = uniqueNonEmptyStrings_(value || []);
  return items.length ? items.join(',') : 'none';
}
