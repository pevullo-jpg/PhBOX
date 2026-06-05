var PHBOX_M3_BACKEND_ROUTE_VERSION_ = 'M3_BACKEND_ROUTE_v1';
var PHBOX_M3_BACKEND_ROUTE_STAGE_ = 'migration3_backend_route';
var PHBOX_M3_BACKEND_ROUTE_REQUIRED_FRONT_ROUTE_VERSION_ = 'M3_FRONT_ROUTE_v1';
var PHBOX_M3_BACKEND_ROUTE_OWNER_ = 'backend_gas_route_contract_only';
var PHBOX_M3_BACKEND_ROUTE_RUNTIME_OWNER_ = 'future_tenant_backend_router';
var PHBOX_M3_BACKEND_ROUTE_POLICY_ = 'no_runtime_backend_route_activation_before_observability';
var PHBOX_M3_BACKEND_ROUTE_ENTRYPOINT_ = 'future_runPhboxTenantBackend';
var PHBOX_M3_BACKEND_ROUTE_DISPATCHER_ = 'future_tenant_backend_dispatcher';
var PHBOX_M3_BACKEND_ROUTE_TENANT_RESOLVER_ = 'future_tenant_registry_config_lookup';
var PHBOX_M3_BACKEND_ROUTE_ALLOWED_ROUTES_ = [
  'precheck',
  'gmail_ingest',
  'drive_pdf_import',
  'ocr_parse',
  'firestore_publish',
  'dashboard_index'
];
var PHBOX_M3_BACKEND_ROUTE_REQUIRED_INPUTS_ = [
  'tenantId',
  'tenantConfig',
  'backendEnabled',
  'routeSignal'
];

function runMigration3BackendRouteRuntimeStatus_() {
  try {
    if (typeof runMigration3FrontRouteRuntimeStatus_ !== 'function') {
      throw new Error('M3_BACKEND_ROUTE_FRONT_ROUTE_MISSING: funzione runMigration3FrontRouteRuntimeStatus_ non disponibile. Backend route non autorizzabile.');
    }
    return buildMigration3BackendRouteResult_({
      frontRouteStatus: runMigration3FrontRouteRuntimeStatus_(),
      contract: buildMigration3BackendRouteContract_(),
      obsoleteHandlers: listMigration3BackendRouteObsoleteSettingsHandlers_()
    });
  } catch (e) {
    return buildMigration3BackendRouteResult_({
      frontRouteStatus: null,
      contract: buildMigration3BackendRouteContract_(),
      obsoleteHandlers: listMigration3BackendRouteObsoleteSettingsHandlers_(),
      error: migration3BackendRouteNormalizeError_(e),
      errorKind: migration3BackendRouteErrorKind_(e)
    });
  }
}

function buildMigration3BackendRouteContract_() {
  return {
    backendRouteVersion: PHBOX_M3_BACKEND_ROUTE_VERSION_,
    owner: PHBOX_M3_BACKEND_ROUTE_OWNER_,
    runtimeOwner: PHBOX_M3_BACKEND_ROUTE_RUNTIME_OWNER_,
    routePolicy: PHBOX_M3_BACKEND_ROUTE_POLICY_,
    entrypoint: PHBOX_M3_BACKEND_ROUTE_ENTRYPOINT_,
    dispatcher: PHBOX_M3_BACKEND_ROUTE_DISPATCHER_,
    tenantResolver: PHBOX_M3_BACKEND_ROUTE_TENANT_RESOLVER_,
    allowedBackendRoutes: PHBOX_M3_BACKEND_ROUTE_ALLOWED_ROUTES_.slice(),
    requiredInputs: PHBOX_M3_BACKEND_ROUTE_REQUIRED_INPUTS_.slice(),
    backendRouteContractDeclared: true,
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
    backendRouteRuntimeChanged: false,
    backendRouteResolved: false,
    backendDispatchExecuted: false,
    backendRunStarted: false,
    triggerInstalled: false,
    schemaChanged: false,
    runtimeContractChanged: false
  };
}

function buildMigration3BackendRouteResult_(data) {
  data = data || {};
  var frontRouteStatus = data.frontRouteStatus || null;
  var frontStats = (frontRouteStatus && frontRouteStatus.stats) || {};
  var contract = data.contract || {};
  var obsoleteHandlers = uniqueNonEmptyStrings_([].concat(
    frontStats.obsoleteHandlers || [],
    data.obsoleteHandlers || []
  ));
  var statsInput = {
    ok: !!(frontRouteStatus && frontRouteStatus.ok) && frontStats.ok !== false,
    skipped: false,
    reason: '',
    frontRouteVersion: String(frontStats.frontRouteVersion || ''),
    authVersion: String(frontStats.authVersion || ''),
    costGuardVersion: String(frontStats.costGuardVersion || ''),
    configVersion: String(frontStats.configVersion || ''),
    registryVersion: String(frontStats.registryVersion || ''),
    backendRouteVersion: String(contract.backendRouteVersion || ''),
    backendRouteOwner: String(contract.owner || ''),
    runtimeOwner: String(contract.runtimeOwner || ''),
    routePolicy: String(contract.routePolicy || ''),
    entrypoint: String(contract.entrypoint || ''),
    dispatcher: String(contract.dispatcher || ''),
    tenantResolver: String(contract.tenantResolver || ''),
    backendRouteContractDeclared: !!contract.backendRouteContractDeclared,
    allowedBackendRoutes: uniqueNonEmptyStrings_(contract.allowedBackendRoutes || []),
    requiredInputs: uniqueNonEmptyStrings_(contract.requiredInputs || []),
    firestoreReads: Math.max(0, Number(frontStats.firestoreReads || 0) + Number(contract.firestoreReads || 0) + Number(data.firestoreReads || 0)),
    firestoreWrites: Math.max(0, Number(frontStats.firestoreWrites || 0) + Number(contract.firestoreWrites || 0) + Number(data.firestoreWrites || 0)),
    estimatedReadsPerHour: Math.max(0, Number(frontStats.estimatedReadsPerHour || 0) + Number(data.estimatedReadsPerHour || 0)),
    estimatedWritesPerHour: Math.max(0, Number(frontStats.estimatedWritesPerHour || 0) + Number(data.estimatedWritesPerHour || 0)),
    registryReads: Math.max(0, Number(frontStats.registryReads || 0) + Number(contract.registryReads || 0) + Number(data.registryReads || 0)),
    registryWrites: Math.max(0, Number(frontStats.registryWrites || 0) + Number(contract.registryWrites || 0) + Number(data.registryWrites || 0)),
    configReads: Math.max(0, Number(frontStats.configReads || 0) + Number(contract.configReads || 0) + Number(data.configReads || 0)),
    configWrites: Math.max(0, Number(frontStats.configWrites || 0) + Number(contract.configWrites || 0) + Number(data.configWrites || 0)),
    targetWritesExecuted: Math.max(0, Number(frontStats.targetWritesExecuted || 0) + Number(contract.targetWritesExecuted || 0) + Number(data.targetWritesExecuted || 0)),
    listeners: Math.max(0, Number(frontStats.listeners || 0) + Number(contract.listeners || 0) + Number(data.listeners || 0)),
    queries: Math.max(0, Number(frontStats.queries || 0) + Number(contract.queries || 0) + Number(data.queries || 0)),
    fanOut: Math.max(0, Number(frontStats.fanOut || 0) + Number(contract.fanOut || 0) + Number(data.fanOut || 0)),
    targetPathBuilt: !!frontStats.targetPathBuilt || !!contract.targetPathBuilt || !!data.targetPathBuilt,
    tenantTargetPathBuilt: !!frontStats.tenantTargetPathBuilt || !!contract.tenantTargetPathBuilt || !!data.tenantTargetPathBuilt,
    tenantConfigTouched: !!frontStats.tenantConfigTouched || !!contract.tenantConfigTouched || !!data.tenantConfigTouched,
    lifecycleTouched: !!frontStats.lifecycleTouched || !!contract.lifecycleTouched || !!data.lifecycleTouched,
    authRuntimeChanged: !!frontStats.authRuntimeChanged || !!contract.authRuntimeChanged || !!data.authRuntimeChanged,
    authProviderTouched: !!frontStats.authProviderTouched || !!contract.authProviderTouched || !!data.authProviderTouched,
    authTokenValidated: !!frontStats.authTokenValidated || !!contract.authTokenValidated || !!data.authTokenValidated,
    sessionCreated: !!frontStats.sessionCreated || !!contract.sessionCreated || !!data.sessionCreated,
    tenantRoutingActive: !!frontStats.tenantRoutingActive || !!contract.tenantRoutingActive || !!data.tenantRoutingActive,
    frontRouteRuntimeChanged: !!frontStats.frontRouteRuntimeChanged || !!contract.frontRouteRuntimeChanged || !!data.frontRouteRuntimeChanged,
    routeResolved: !!frontStats.routeResolved || !!contract.routeResolved || !!data.routeResolved,
    navigationChanged: !!frontStats.navigationChanged || !!contract.navigationChanged || !!data.navigationChanged,
    backendRouteRuntimeChanged: !!contract.backendRouteRuntimeChanged || !!data.backendRouteRuntimeChanged,
    backendRouteResolved: !!contract.backendRouteResolved || !!data.backendRouteResolved,
    backendDispatchExecuted: !!contract.backendDispatchExecuted || !!data.backendDispatchExecuted,
    backendRunStarted: !!contract.backendRunStarted || !!data.backendRunStarted,
    triggerInstalled: !!contract.triggerInstalled || !!data.triggerInstalled,
    schemaChanged: !!frontStats.schemaChanged || !!contract.schemaChanged || !!data.schemaChanged,
    runtimeContractChanged: !!frontStats.runtimeContractChanged || !!contract.runtimeContractChanged || !!data.runtimeContractChanged,
    obsoleteHandlers: obsoleteHandlers,
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };
  var violations = buildMigration3BackendRouteViolations_({
    frontRoutePresent: !!(frontRouteStatus && frontRouteStatus.stats),
    frontRouteOk: statsInput.ok,
    frontRouteVersion: statsInput.frontRouteVersion,
    backendRouteVersion: statsInput.backendRouteVersion,
    backendRouteOwner: statsInput.backendRouteOwner,
    runtimeOwner: statsInput.runtimeOwner,
    routePolicy: statsInput.routePolicy,
    entrypoint: statsInput.entrypoint,
    dispatcher: statsInput.dispatcher,
    tenantResolver: statsInput.tenantResolver,
    backendRouteContractDeclared: statsInput.backendRouteContractDeclared,
    allowedBackendRoutes: statsInput.allowedBackendRoutes,
    requiredInputs: statsInput.requiredInputs,
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
    backendRouteRuntimeChanged: statsInput.backendRouteRuntimeChanged,
    backendRouteResolved: statsInput.backendRouteResolved,
    backendDispatchExecuted: statsInput.backendDispatchExecuted,
    backendRunStarted: statsInput.backendRunStarted,
    triggerInstalled: statsInput.triggerInstalled,
    schemaChanged: statsInput.schemaChanged,
    runtimeContractChanged: statsInput.runtimeContractChanged,
    obsoleteHandlers: obsoleteHandlers,
    error: statsInput.error
  });
  statsInput.ok = violations.length === 0;
  statsInput.reason = violations.length ? 'm3_backend_route_violation' : 'm3_backend_route_ready';
  statsInput.violations = violations;
  return buildMigration3BackendRouteResultFromStats_(statsInput);
}

function buildMigration3BackendRouteViolations_(data) {
  data = data || {};
  var violations = [];
  if (!data.frontRoutePresent) violations.push('m3_front_route_status_missing');
  if (data.frontRoutePresent && !data.frontRouteOk) violations.push('m3_front_route_not_ok');
  if (String(data.frontRouteVersion || '') !== PHBOX_M3_BACKEND_ROUTE_REQUIRED_FRONT_ROUTE_VERSION_) violations.push('m3_front_route_version_mismatch');
  if (String(data.backendRouteVersion || '') !== PHBOX_M3_BACKEND_ROUTE_VERSION_) violations.push('backend_route_version_mismatch');
  if (String(data.backendRouteOwner || '') !== PHBOX_M3_BACKEND_ROUTE_OWNER_) violations.push('backend_route_owner_mismatch');
  if (String(data.runtimeOwner || '') !== PHBOX_M3_BACKEND_ROUTE_RUNTIME_OWNER_) violations.push('backend_route_runtime_owner_mismatch');
  if (String(data.routePolicy || '') !== PHBOX_M3_BACKEND_ROUTE_POLICY_) violations.push('backend_route_policy_mismatch');
  if (String(data.entrypoint || '') !== PHBOX_M3_BACKEND_ROUTE_ENTRYPOINT_) violations.push('backend_route_entrypoint_mismatch');
  if (String(data.dispatcher || '') !== PHBOX_M3_BACKEND_ROUTE_DISPATCHER_) violations.push('backend_route_dispatcher_mismatch');
  if (String(data.tenantResolver || '') !== PHBOX_M3_BACKEND_ROUTE_TENANT_RESOLVER_) violations.push('backend_route_tenant_resolver_mismatch');
  if (!data.backendRouteContractDeclared) violations.push('backend_route_contract_not_declared');
  migration3BackendRouteMissingItems_(PHBOX_M3_BACKEND_ROUTE_ALLOWED_ROUTES_, data.allowedBackendRoutes || []).forEach(function (route) {
    violations.push('missing_backend_route_' + route);
  });
  migration3BackendRouteMissingItems_(PHBOX_M3_BACKEND_ROUTE_REQUIRED_INPUTS_, data.requiredInputs || []).forEach(function (input) {
    violations.push('missing_required_input_' + input);
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
  if (data.backendRouteRuntimeChanged) violations.push('backend_route_runtime_changed');
  if (data.backendRouteResolved) violations.push('backend_route_resolved');
  if (data.backendDispatchExecuted) violations.push('backend_dispatch_executed');
  if (data.backendRunStarted) violations.push('backend_run_started');
  if (data.triggerInstalled) violations.push('trigger_installed');
  if (data.schemaChanged) violations.push('schema_changed');
  if (data.runtimeContractChanged) violations.push('runtime_contract_changed');
  if (uniqueNonEmptyStrings_(data.obsoleteHandlers || []).length > 0) violations.push('obsolete_settings_handlers_detected');
  if (data.error) violations.push('m3_backend_route_error');
  return uniqueNonEmptyStrings_(violations);
}

function migration3BackendRouteMissingItems_(expected, actual) {
  expected = uniqueNonEmptyStrings_(expected || []);
  actual = uniqueNonEmptyStrings_(actual || []);
  return expected.filter(function (item) { return actual.indexOf(item) === -1; });
}

function buildMigration3BackendRouteResultFromStats_(data) {
  data = data || {};
  var stats = buildMigration3BackendRouteStats_(data);
  return {
    ok: data.ok !== false,
    stats: stats,
    violations: uniqueNonEmptyStrings_(data.violations || []),
    items: data.items || []
  };
}

function buildMigration3BackendRouteStats_(data) {
  data = data || {};
  return {
    stage: PHBOX_M3_BACKEND_ROUTE_STAGE_,
    ok: data.ok !== false,
    skipped: data.skipped !== false,
    reason: String(data.reason || ''),
    backendRouteVersion: String(data.backendRouteVersion || ''),
    requiredFrontRouteVersion: PHBOX_M3_BACKEND_ROUTE_REQUIRED_FRONT_ROUTE_VERSION_,
    frontRouteVersion: String(data.frontRouteVersion || ''),
    authVersion: String(data.authVersion || ''),
    costGuardVersion: String(data.costGuardVersion || ''),
    configVersion: String(data.configVersion || ''),
    registryVersion: String(data.registryVersion || ''),
    backendRouteOwner: String(data.backendRouteOwner || ''),
    runtimeOwner: String(data.runtimeOwner || ''),
    routePolicy: String(data.routePolicy || ''),
    entrypoint: String(data.entrypoint || ''),
    dispatcher: String(data.dispatcher || ''),
    tenantResolver: String(data.tenantResolver || ''),
    backendRouteContractDeclared: !!data.backendRouteContractDeclared,
    allowedBackendRoutes: uniqueNonEmptyStrings_(data.allowedBackendRoutes || []),
    requiredInputs: uniqueNonEmptyStrings_(data.requiredInputs || []),
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
    backendRouteRuntimeChanged: !!data.backendRouteRuntimeChanged,
    backendRouteResolved: !!data.backendRouteResolved,
    backendDispatchExecuted: !!data.backendDispatchExecuted,
    backendRunStarted: !!data.backendRunStarted,
    triggerInstalled: !!data.triggerInstalled,
    schemaChanged: !!data.schemaChanged,
    runtimeContractChanged: !!data.runtimeContractChanged,
    obsoleteHandlers: uniqueNonEmptyStrings_(data.obsoleteHandlers || []),
    violations: uniqueNonEmptyStrings_(data.violations || []),
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };
}

function listMigration3BackendRouteObsoleteSettingsHandlers_() {
  var obsolete = [
    'runMigration3FrontRouteSettingsTest',
    'getMigration3FrontRouteSettingsStatus'
  ].filter(function (name) {
    try {
      if (typeof globalThis !== 'undefined' && typeof globalThis[name] === 'function') return true;
      return typeof this !== 'undefined' && typeof this[name] === 'function';
    } catch (e) {
      return false;
    }
  });
  if (typeof listMigration3FrontRouteObsoleteSettingsHandlers_ === 'function') {
    obsolete = obsolete.concat(listMigration3FrontRouteObsoleteSettingsHandlers_());
  }
  return uniqueNonEmptyStrings_(obsolete);
}

function runMigration3BackendRouteSelfTest_() {
  var cleanContract = buildMigration3BackendRouteContract_();
  var cases = [
    {
      id: 'clean_front_route_authorizes_backend_route_contract',
      result: buildMigration3BackendRouteResult_({ frontRouteStatus: buildMigration3BackendRouteSyntheticFrontRouteStatus_({}), contract: cleanContract }),
      expected: { ok: true, violation: '' }
    },
    {
      id: 'missing_front_route_blocks_backend_route',
      result: buildMigration3BackendRouteResult_({ frontRouteStatus: null, contract: cleanContract }),
      expected: { ok: false, violation: 'm3_front_route_status_missing' }
    },
    {
      id: 'front_route_not_ok_blocks_backend_route',
      result: buildMigration3BackendRouteResult_({ frontRouteStatus: buildMigration3BackendRouteSyntheticFrontRouteStatus_({ ok: false }), contract: cleanContract }),
      expected: { ok: false, violation: 'm3_front_route_not_ok' }
    },
    {
      id: 'front_route_version_mismatch_blocks_backend_route',
      result: buildMigration3BackendRouteResult_({ frontRouteStatus: buildMigration3BackendRouteSyntheticFrontRouteStatus_({ frontRouteVersion: 'M3_FRONT_ROUTE_v0' }), contract: cleanContract }),
      expected: { ok: false, violation: 'm3_front_route_version_mismatch' }
    },
    {
      id: 'backend_route_version_mismatch_blocks_backend_route',
      result: buildMigration3BackendRouteResult_({ frontRouteStatus: buildMigration3BackendRouteSyntheticFrontRouteStatus_({}), contract: migration3BackendRouteSyntheticContract_({ backendRouteVersion: 'M3_BACKEND_ROUTE_v0' }) }),
      expected: { ok: false, violation: 'backend_route_version_mismatch' }
    },
    {
      id: 'backend_route_owner_mismatch_blocks_backend_route',
      result: buildMigration3BackendRouteResult_({ frontRouteStatus: buildMigration3BackendRouteSyntheticFrontRouteStatus_({}), contract: migration3BackendRouteSyntheticContract_({ owner: 'frontend_route_contract_only' }) }),
      expected: { ok: false, violation: 'backend_route_owner_mismatch' }
    },
    {
      id: 'backend_route_policy_mismatch_blocks_backend_route',
      result: buildMigration3BackendRouteResult_({ frontRouteStatus: buildMigration3BackendRouteSyntheticFrontRouteStatus_({}), contract: migration3BackendRouteSyntheticContract_({ routePolicy: 'activate_backend_route_runtime' }) }),
      expected: { ok: false, violation: 'backend_route_policy_mismatch' }
    },
    {
      id: 'backend_route_entrypoint_mismatch_blocks_backend_route',
      result: buildMigration3BackendRouteResult_({ frontRouteStatus: buildMigration3BackendRouteSyntheticFrontRouteStatus_({}), contract: migration3BackendRouteSyntheticContract_({ entrypoint: 'legacy_backend_entrypoint' }) }),
      expected: { ok: false, violation: 'backend_route_entrypoint_mismatch' }
    },
    {
      id: 'backend_route_contract_not_declared_blocks_backend_route',
      result: buildMigration3BackendRouteResult_({ frontRouteStatus: buildMigration3BackendRouteSyntheticFrontRouteStatus_({}), contract: migration3BackendRouteSyntheticContract_({ backendRouteContractDeclared: false }) }),
      expected: { ok: false, violation: 'backend_route_contract_not_declared' }
    },
    {
      id: 'missing_backend_route_blocks_backend_route',
      result: buildMigration3BackendRouteResult_({ frontRouteStatus: buildMigration3BackendRouteSyntheticFrontRouteStatus_({}), contract: migration3BackendRouteSyntheticContract_({ allowedBackendRoutes: ['precheck', 'gmail_ingest'] }) }),
      expected: { ok: false, violation: 'missing_backend_route_drive_pdf_import' }
    },
    {
      id: 'missing_required_input_blocks_backend_route',
      result: buildMigration3BackendRouteResult_({ frontRouteStatus: buildMigration3BackendRouteSyntheticFrontRouteStatus_({}), contract: migration3BackendRouteSyntheticContract_({ requiredInputs: ['tenantId'] }) }),
      expected: { ok: false, violation: 'missing_required_input_tenantConfig' }
    },
    {
      id: 'firestore_read_or_write_blocks_backend_route',
      result: buildMigration3BackendRouteResult_({ frontRouteStatus: buildMigration3BackendRouteSyntheticFrontRouteStatus_({ firestoreReads: 1, firestoreWrites: 1 }), contract: cleanContract }),
      expected: { ok: false, violation: 'firestore_reads_detected' }
    },
    {
      id: 'registry_or_config_read_write_blocks_backend_route',
      result: buildMigration3BackendRouteResult_({ frontRouteStatus: buildMigration3BackendRouteSyntheticFrontRouteStatus_({ registryReads: 1, registryWrites: 1, configReads: 1, configWrites: 1 }), contract: cleanContract }),
      expected: { ok: false, violation: 'registry_reads_detected' }
    },
    {
      id: 'listener_query_fanout_blocks_backend_route',
      result: buildMigration3BackendRouteResult_({ frontRouteStatus: buildMigration3BackendRouteSyntheticFrontRouteStatus_({ listeners: 1, queries: 1, fanOut: 1 }), contract: cleanContract }),
      expected: { ok: false, violation: 'listeners_detected' }
    },
    {
      id: 'target_or_tenant_path_blocks_backend_route',
      result: buildMigration3BackendRouteResult_({ frontRouteStatus: buildMigration3BackendRouteSyntheticFrontRouteStatus_({ targetPathBuilt: true, tenantTargetPathBuilt: true }), contract: cleanContract }),
      expected: { ok: false, violation: 'target_path_built' }
    },
    {
      id: 'auth_or_front_route_runtime_blocks_backend_route',
      result: buildMigration3BackendRouteResult_({ frontRouteStatus: buildMigration3BackendRouteSyntheticFrontRouteStatus_({ authRuntimeChanged: true, authTokenValidated: true, sessionCreated: true, frontRouteRuntimeChanged: true, routeResolved: true, navigationChanged: true }), contract: cleanContract }),
      expected: { ok: false, violation: 'auth_runtime_changed' }
    },
    {
      id: 'backend_route_runtime_blocks_backend_route',
      result: buildMigration3BackendRouteResult_({ frontRouteStatus: buildMigration3BackendRouteSyntheticFrontRouteStatus_({}), contract: migration3BackendRouteSyntheticContract_({ backendRouteRuntimeChanged: true, backendRouteResolved: true, backendDispatchExecuted: true }) }),
      expected: { ok: false, violation: 'backend_route_runtime_changed' }
    },
    {
      id: 'backend_run_or_trigger_blocks_backend_route',
      result: buildMigration3BackendRouteResult_({ frontRouteStatus: buildMigration3BackendRouteSyntheticFrontRouteStatus_({}), contract: migration3BackendRouteSyntheticContract_({ backendRunStarted: true, triggerInstalled: true }) }),
      expected: { ok: false, violation: 'backend_run_started' }
    },
    {
      id: 'lifecycle_or_tenant_routing_blocks_backend_route',
      result: buildMigration3BackendRouteResult_({ frontRouteStatus: buildMigration3BackendRouteSyntheticFrontRouteStatus_({ lifecycleTouched: true, tenantRoutingActive: true }), contract: cleanContract }),
      expected: { ok: false, violation: 'lifecycle_touched' }
    },
    {
      id: 'schema_or_runtime_contract_blocks_backend_route',
      result: buildMigration3BackendRouteResult_({ frontRouteStatus: buildMigration3BackendRouteSyntheticFrontRouteStatus_({ schemaChanged: true, runtimeContractChanged: true }), contract: cleanContract }),
      expected: { ok: false, violation: 'schema_changed' }
    },
    {
      id: 'obsolete_settings_handler_blocks_backend_route',
      result: buildMigration3BackendRouteResult_({ frontRouteStatus: buildMigration3BackendRouteSyntheticFrontRouteStatus_({}), contract: cleanContract, obsoleteHandlers: ['runMigration3FrontRouteSettingsTest'] }),
      expected: { ok: false, violation: 'obsolete_settings_handlers_detected' }
    },
    {
      id: 'runtime_error_blocks_backend_route',
      result: buildMigration3BackendRouteResult_({ frontRouteStatus: buildMigration3BackendRouteSyntheticFrontRouteStatus_({}), contract: cleanContract, error: 'synthetic error', errorKind: 'synthetic' }),
      expected: { ok: false, violation: 'm3_backend_route_error' }
    }
  ];

  var items = cases.map(function (entry) {
    var stats = entry.result.stats || {};
    var violations = uniqueNonEmptyStrings_(stats.violations || []);
    var passed = entry.expected.ok ? !!stats.ok : (!stats.ok && violations.indexOf(entry.expected.violation) !== -1);
    return {
      id: entry.id,
      passed: passed,
      stats: stats
    };
  });
  var failed = items.filter(function (item) { return !item.passed; });
  return {
    ok: failed.length === 0,
    testCount: items.length,
    passedCount: items.length - failed.length,
    failedCount: failed.length,
    reason: failed.length ? 'm3_backend_route_selftest_failed' : 'm3_backend_route_selftest_passed',
    stats: buildMigration3BackendRouteResult_({
      frontRouteStatus: buildMigration3BackendRouteSyntheticFrontRouteStatus_({}),
      contract: cleanContract
    }).stats,
    items: items
  };
}

function buildMigration3BackendRouteSyntheticFrontRouteStatus_(overrides) {
  overrides = overrides || {};
  var stats = {
    ok: overrides.ok !== false,
    reason: overrides.ok === false ? 'synthetic_front_route_not_ok' : 'm3_front_route_ready',
    frontRouteVersion: String(overrides.frontRouteVersion || PHBOX_M3_BACKEND_ROUTE_REQUIRED_FRONT_ROUTE_VERSION_),
    authVersion: String(overrides.authVersion || 'M3_AUTH_v1'),
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
    frontRouteRuntimeChanged: !!overrides.frontRouteRuntimeChanged,
    routeResolved: !!overrides.routeResolved,
    navigationChanged: !!overrides.navigationChanged,
    schemaChanged: !!overrides.schemaChanged,
    runtimeContractChanged: !!overrides.runtimeContractChanged,
    obsoleteHandlers: uniqueNonEmptyStrings_(overrides.obsoleteHandlers || []),
    violations: uniqueNonEmptyStrings_(overrides.violations || [])
  };
  return {
    ok: !!stats.ok,
    stats: stats,
    violations: stats.violations,
    items: []
  };
}

function migration3BackendRouteSyntheticContract_(overrides) {
  overrides = overrides || {};
  var contract = buildMigration3BackendRouteContract_();
  Object.keys(overrides).forEach(function (key) {
    contract[key] = overrides[key];
  });
  return contract;
}

function formatMigration3BackendRouteRuntimeFeedback_(result) {
  var stats = (result && result.stats) || {};
  return formatMigration3BackendRouteStats_('MIGRATION_3_BACKEND_ROUTE_RUNTIME_STATUS', stats, null);
}

function formatMigration3BackendRouteSelfTestFeedback_(result) {
  result = result || {};
  var stats = result.stats || {};
  var lines = formatMigration3BackendRouteStats_('MIGRATION_3_BACKEND_ROUTE_TEST', stats, {
    testCount: result.testCount,
    passedCount: result.passedCount,
    failedCount: result.failedCount,
    reason: result.reason
  }).split('\n');
  lines.push('items=');
  (result.items || []).forEach(function (item) {
    var itemStats = item.stats || {};
    lines.push('- id=' + String(item.id || ''));
    lines.push('  passed=' + String(!!item.passed));
    lines.push('  ok=' + String(!!itemStats.ok));
    lines.push('  reason=' + String(itemStats.reason || ''));
    lines.push('  backendRouteVersion=' + String(itemStats.backendRouteVersion || ''));
    lines.push('  frontRouteVersion=' + String(itemStats.frontRouteVersion || ''));
    lines.push('  routePolicy=' + String(itemStats.routePolicy || ''));
    lines.push('  backendRouteContractDeclared=' + String(!!itemStats.backendRouteContractDeclared));
    lines.push('  allowedBackendRoutesCount=' + String((itemStats.allowedBackendRoutes || []).length));
    lines.push('  requiredInputsCount=' + String((itemStats.requiredInputs || []).length));
    lines.push('  firestoreReads=' + String(itemStats.firestoreReads || 0));
    lines.push('  firestoreWrites=' + String(itemStats.firestoreWrites || 0));
    lines.push('  registryReads=' + String(itemStats.registryReads || 0));
    lines.push('  registryWrites=' + String(itemStats.registryWrites || 0));
    lines.push('  configReads=' + String(itemStats.configReads || 0));
    lines.push('  configWrites=' + String(itemStats.configWrites || 0));
    lines.push('  listeners=' + String(itemStats.listeners || 0));
    lines.push('  queries=' + String(itemStats.queries || 0));
    lines.push('  fanOut=' + String(itemStats.fanOut || 0));
    lines.push('  backendRouteRuntimeChanged=' + String(!!itemStats.backendRouteRuntimeChanged));
    lines.push('  backendRouteResolved=' + String(!!itemStats.backendRouteResolved));
    lines.push('  backendDispatchExecuted=' + String(!!itemStats.backendDispatchExecuted));
    lines.push('  backendRunStarted=' + String(!!itemStats.backendRunStarted));
    lines.push('  triggerInstalled=' + String(!!itemStats.triggerInstalled));
    lines.push('  violations=' + migration3BackendRouteJoinList_(itemStats.violations || []));
  });
  return lines.join('\n');
}

function formatMigration3BackendRouteStats_(title, stats, testMeta) {
  stats = stats || {};
  var lines = [];
  lines.push(String(title || 'MIGRATION_3_BACKEND_ROUTE_RUNTIME_STATUS'));
  lines.push('ok=' + String(!!stats.ok));
  if (testMeta) {
    lines.push('testCount=' + String(testMeta.testCount || 0));
    lines.push('passedCount=' + String(testMeta.passedCount || 0));
    lines.push('failedCount=' + String(testMeta.failedCount || 0));
    lines.push('reason=' + String(testMeta.reason || ''));
  } else {
    lines.push('skipped=' + String(!!stats.skipped));
    lines.push('reason=' + String(stats.reason || ''));
  }
  lines.push('backendRouteVersion=' + String(stats.backendRouteVersion || ''));
  lines.push('requiredFrontRouteVersion=' + String(stats.requiredFrontRouteVersion || PHBOX_M3_BACKEND_ROUTE_REQUIRED_FRONT_ROUTE_VERSION_));
  lines.push('frontRouteVersion=' + String(stats.frontRouteVersion || ''));
  lines.push('authVersion=' + String(stats.authVersion || ''));
  lines.push('costGuardVersion=' + String(stats.costGuardVersion || ''));
  lines.push('configVersion=' + String(stats.configVersion || ''));
  lines.push('registryVersion=' + String(stats.registryVersion || ''));
  lines.push('backendRouteOwner=' + String(stats.backendRouteOwner || ''));
  lines.push('runtimeOwner=' + String(stats.runtimeOwner || ''));
  lines.push('routePolicy=' + String(stats.routePolicy || ''));
  lines.push('entrypoint=' + String(stats.entrypoint || ''));
  lines.push('dispatcher=' + String(stats.dispatcher || ''));
  lines.push('tenantResolver=' + String(stats.tenantResolver || ''));
  lines.push('backendRouteContractDeclared=' + String(!!stats.backendRouteContractDeclared));
  lines.push('allowedBackendRoutesCount=' + String((stats.allowedBackendRoutes || []).length));
  lines.push('requiredInputsCount=' + String((stats.requiredInputs || []).length));
  lines.push('allowedBackendRoutes=' + migration3BackendRouteJoinList_(stats.allowedBackendRoutes || []));
  lines.push('requiredInputs=' + migration3BackendRouteJoinList_(stats.requiredInputs || []));
  lines.push('firestoreReads=' + String(stats.firestoreReads || 0));
  lines.push('firestoreWrites=' + String(stats.firestoreWrites || 0));
  lines.push('estimatedReadsPerHour=' + String(stats.estimatedReadsPerHour || 0));
  lines.push('estimatedWritesPerHour=' + String(stats.estimatedWritesPerHour || 0));
  lines.push('registryReads=' + String(stats.registryReads || 0));
  lines.push('registryWrites=' + String(stats.registryWrites || 0));
  lines.push('configReads=' + String(stats.configReads || 0));
  lines.push('configWrites=' + String(stats.configWrites || 0));
  lines.push('targetWritesExecuted=' + String(stats.targetWritesExecuted || 0));
  lines.push('listeners=' + String(stats.listeners || 0));
  lines.push('queries=' + String(stats.queries || 0));
  lines.push('fanOut=' + String(stats.fanOut || 0));
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
  lines.push('backendRouteRuntimeChanged=' + String(!!stats.backendRouteRuntimeChanged));
  lines.push('backendRouteResolved=' + String(!!stats.backendRouteResolved));
  lines.push('backendDispatchExecuted=' + String(!!stats.backendDispatchExecuted));
  lines.push('backendRunStarted=' + String(!!stats.backendRunStarted));
  lines.push('triggerInstalled=' + String(!!stats.triggerInstalled));
  lines.push('schemaChanged=' + String(!!stats.schemaChanged));
  lines.push('runtimeContractChanged=' + String(!!stats.runtimeContractChanged));
  lines.push('obsoleteHandlers=' + migration3BackendRouteJoinList_(stats.obsoleteHandlers || []));
  lines.push('violations=' + migration3BackendRouteJoinList_(stats.violations || []));
  lines.push('error=' + String(stats.error || 'none'));
  lines.push('errorKind=' + String(stats.errorKind || 'none'));
  return lines.join('\n');
}

function migration3BackendRouteJoinList_(value) {
  var items = uniqueNonEmptyStrings_(value || []);
  return items.length ? items.join(',') : 'none';
}

function migration3BackendRouteNormalizeError_(error) {
  if (!error) return '';
  if (error && error.message) return String(error.message);
  return String(error);
}

function migration3BackendRouteErrorKind_(error) {
  var text = migration3BackendRouteNormalizeError_(error);
  if (!text) return '';
  if (/missing|non disponibile/i.test(text)) return 'missing_dependency';
  return 'runtime_error';
}
