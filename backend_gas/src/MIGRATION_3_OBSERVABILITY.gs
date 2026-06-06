var PHBOX_M3_OBSERVABILITY_VERSION_ = 'M3_OBSERVABILITY_v1';
var PHBOX_M3_OBSERVABILITY_STAGE_ = 'migration3_observability';
var PHBOX_M3_OBSERVABILITY_REQUIRED_BACKEND_ROUTE_VERSION_ = 'M3_BACKEND_ROUTE_v1';
var PHBOX_M3_OBSERVABILITY_OWNER_ = 'backend_gas_observability_contract_only';
var PHBOX_M3_OBSERVABILITY_RUNTIME_OWNER_ = 'future_m4_plan_observer';
var PHBOX_M3_OBSERVABILITY_POLICY_ = 'no_source_target_scan_before_m4_plan';
var PHBOX_M3_OBSERVABILITY_MODE_ = 'pre_materialize_observability_contract';
var PHBOX_M3_OBSERVABILITY_SOURCE_ROOT_ = 'legacy_root_collections';
var PHBOX_M3_OBSERVABILITY_TARGET_ROOT_ = 'tenants/{tenantId}';
var PHBOX_M3_OBSERVABILITY_COLLECTIONS_ = [
  'patients',
  'doctor_patient_links',
  'families',
  'patient_dashboard_index',
  'dashboard_totals',
  'patients/{patientId}/debts',
  'patients/{patientId}/advances',
  'patients/{patientId}/bookings',
  'patients/{patientId}/therapeutic_advice',
  'drive_pdf_imports_linked'
];
var PHBOX_M3_OBSERVABILITY_METRICS_ = [
  'sourcePatientsCount',
  'sourceFamiliesCount',
  'sourceSubcollectionsCount',
  'sourceDoctorLinksCount',
  'sourceDashboardIndexCount',
  'sourceDrivePdfImportsLinkedCount',
  'plannedTargetWrites',
  'estimatedReads',
  'estimatedWrites',
  'migrationSignature',
  'blockingAnomalies'
];

function runMigration3ObservabilityRuntimeStatus_() {
  try {
    if (typeof runMigration3BackendRouteRuntimeStatus_ !== 'function') {
      throw new Error('M3_OBSERVABILITY_BACKEND_ROUTE_MISSING: funzione runMigration3BackendRouteRuntimeStatus_ non disponibile. Observability non autorizzabile.');
    }
    return buildMigration3ObservabilityResult_({
      backendRouteStatus: runMigration3BackendRouteRuntimeStatus_(),
      contract: buildMigration3ObservabilityContract_(),
      obsoleteHandlers: listMigration3ObservabilityObsoleteSettingsHandlers_()
    });
  } catch (e) {
    return buildMigration3ObservabilityResult_({
      backendRouteStatus: null,
      contract: buildMigration3ObservabilityContract_(),
      obsoleteHandlers: listMigration3ObservabilityObsoleteSettingsHandlers_(),
      error: normalizeRuntimeErrorMessage_(e),
      errorKind: classifyRuntimeFailureKind_(e)
    });
  }
}

function buildMigration3ObservabilityContract_() {
  return {
    observabilityVersion: PHBOX_M3_OBSERVABILITY_VERSION_,
    owner: PHBOX_M3_OBSERVABILITY_OWNER_,
    runtimeOwner: PHBOX_M3_OBSERVABILITY_RUNTIME_OWNER_,
    observabilityPolicy: PHBOX_M3_OBSERVABILITY_POLICY_,
    observabilityMode: PHBOX_M3_OBSERVABILITY_MODE_,
    sourceRoot: PHBOX_M3_OBSERVABILITY_SOURCE_ROOT_,
    targetRoot: PHBOX_M3_OBSERVABILITY_TARGET_ROOT_,
    observedCollections: PHBOX_M3_OBSERVABILITY_COLLECTIONS_.slice(),
    requiredMetrics: PHBOX_M3_OBSERVABILITY_METRICS_.slice(),
    observabilityContractDeclared: true,
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
    sourceScanExecuted: false,
    targetScanExecuted: false,
    sourceCountsCollected: false,
    targetCountsCollected: false,
    migrationSignatureComputed: false,
    blockingAnomaliesDetected: false,
    schemaChanged: false,
    runtimeContractChanged: false
  };
}

function buildMigration3ObservabilityResult_(data) {
  data = data || {};
  var backendRouteStatus = data.backendRouteStatus || null;
  var backendStats = (backendRouteStatus && backendRouteStatus.stats) || {};
  var contract = data.contract || {};
  var obsoleteHandlers = uniqueNonEmptyStrings_([].concat(
    backendStats.obsoleteHandlers || [],
    data.obsoleteHandlers || []
  ));
  var statsInput = {
    ok: !!(backendRouteStatus && backendRouteStatus.ok) && backendStats.ok !== false,
    skipped: false,
    reason: '',
    backendRouteVersion: String(backendStats.backendRouteVersion || ''),
    frontRouteVersion: String(backendStats.frontRouteVersion || ''),
    authVersion: String(backendStats.authVersion || ''),
    costGuardVersion: String(backendStats.costGuardVersion || ''),
    configVersion: String(backendStats.configVersion || ''),
    registryVersion: String(backendStats.registryVersion || ''),
    observabilityVersion: String(contract.observabilityVersion || ''),
    observabilityOwner: String(contract.owner || ''),
    runtimeOwner: String(contract.runtimeOwner || ''),
    observabilityPolicy: String(contract.observabilityPolicy || ''),
    observabilityMode: String(contract.observabilityMode || ''),
    sourceRoot: String(contract.sourceRoot || ''),
    targetRoot: String(contract.targetRoot || ''),
    observabilityContractDeclared: !!contract.observabilityContractDeclared,
    observedCollections: uniqueNonEmptyStrings_(contract.observedCollections || []),
    requiredMetrics: uniqueNonEmptyStrings_(contract.requiredMetrics || []),
    firestoreReads: Math.max(0, Number(backendStats.firestoreReads || 0) + Number(contract.firestoreReads || 0) + Number(data.firestoreReads || 0)),
    firestoreWrites: Math.max(0, Number(backendStats.firestoreWrites || 0) + Number(contract.firestoreWrites || 0) + Number(data.firestoreWrites || 0)),
    estimatedReadsPerHour: Math.max(0, Number(backendStats.estimatedReadsPerHour || 0) + Number(data.estimatedReadsPerHour || 0)),
    estimatedWritesPerHour: Math.max(0, Number(backendStats.estimatedWritesPerHour || 0) + Number(data.estimatedWritesPerHour || 0)),
    registryReads: Math.max(0, Number(backendStats.registryReads || 0) + Number(contract.registryReads || 0) + Number(data.registryReads || 0)),
    registryWrites: Math.max(0, Number(backendStats.registryWrites || 0) + Number(contract.registryWrites || 0) + Number(data.registryWrites || 0)),
    configReads: Math.max(0, Number(backendStats.configReads || 0) + Number(contract.configReads || 0) + Number(data.configReads || 0)),
    configWrites: Math.max(0, Number(backendStats.configWrites || 0) + Number(contract.configWrites || 0) + Number(data.configWrites || 0)),
    targetWritesExecuted: Math.max(0, Number(backendStats.targetWritesExecuted || 0) + Number(contract.targetWritesExecuted || 0) + Number(data.targetWritesExecuted || 0)),
    listeners: Math.max(0, Number(backendStats.listeners || 0) + Number(contract.listeners || 0) + Number(data.listeners || 0)),
    queries: Math.max(0, Number(backendStats.queries || 0) + Number(contract.queries || 0) + Number(data.queries || 0)),
    fanOut: Math.max(0, Number(backendStats.fanOut || 0) + Number(contract.fanOut || 0) + Number(data.fanOut || 0)),
    targetPathBuilt: !!backendStats.targetPathBuilt || !!contract.targetPathBuilt || !!data.targetPathBuilt,
    tenantTargetPathBuilt: !!backendStats.tenantTargetPathBuilt || !!contract.tenantTargetPathBuilt || !!data.tenantTargetPathBuilt,
    tenantConfigTouched: !!backendStats.tenantConfigTouched || !!contract.tenantConfigTouched || !!data.tenantConfigTouched,
    lifecycleTouched: !!backendStats.lifecycleTouched || !!contract.lifecycleTouched || !!data.lifecycleTouched,
    authRuntimeChanged: !!backendStats.authRuntimeChanged || !!contract.authRuntimeChanged || !!data.authRuntimeChanged,
    authProviderTouched: !!backendStats.authProviderTouched || !!contract.authProviderTouched || !!data.authProviderTouched,
    authTokenValidated: !!backendStats.authTokenValidated || !!contract.authTokenValidated || !!data.authTokenValidated,
    sessionCreated: !!backendStats.sessionCreated || !!contract.sessionCreated || !!data.sessionCreated,
    tenantRoutingActive: !!backendStats.tenantRoutingActive || !!contract.tenantRoutingActive || !!data.tenantRoutingActive,
    frontRouteRuntimeChanged: !!backendStats.frontRouteRuntimeChanged || !!contract.frontRouteRuntimeChanged || !!data.frontRouteRuntimeChanged,
    routeResolved: !!backendStats.routeResolved || !!contract.routeResolved || !!data.routeResolved,
    navigationChanged: !!backendStats.navigationChanged || !!contract.navigationChanged || !!data.navigationChanged,
    backendRouteRuntimeChanged: !!backendStats.backendRouteRuntimeChanged || !!contract.backendRouteRuntimeChanged || !!data.backendRouteRuntimeChanged,
    backendRouteResolved: !!backendStats.backendRouteResolved || !!contract.backendRouteResolved || !!data.backendRouteResolved,
    backendDispatchExecuted: !!backendStats.backendDispatchExecuted || !!contract.backendDispatchExecuted || !!data.backendDispatchExecuted,
    backendRunStarted: !!backendStats.backendRunStarted || !!contract.backendRunStarted || !!data.backendRunStarted,
    triggerInstalled: !!backendStats.triggerInstalled || !!contract.triggerInstalled || !!data.triggerInstalled,
    sourceScanExecuted: !!contract.sourceScanExecuted || !!data.sourceScanExecuted,
    targetScanExecuted: !!contract.targetScanExecuted || !!data.targetScanExecuted,
    sourceCountsCollected: !!contract.sourceCountsCollected || !!data.sourceCountsCollected,
    targetCountsCollected: !!contract.targetCountsCollected || !!data.targetCountsCollected,
    migrationSignatureComputed: !!contract.migrationSignatureComputed || !!data.migrationSignatureComputed,
    blockingAnomaliesDetected: !!contract.blockingAnomaliesDetected || !!data.blockingAnomaliesDetected,
    schemaChanged: !!backendStats.schemaChanged || !!contract.schemaChanged || !!data.schemaChanged,
    runtimeContractChanged: !!backendStats.runtimeContractChanged || !!contract.runtimeContractChanged || !!data.runtimeContractChanged,
    obsoleteHandlers: obsoleteHandlers,
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };
  var violations = buildMigration3ObservabilityViolations_({
    backendRoutePresent: !!(backendRouteStatus && backendRouteStatus.stats),
    backendRouteOk: statsInput.ok,
    backendRouteVersion: statsInput.backendRouteVersion,
    observabilityVersion: statsInput.observabilityVersion,
    observabilityOwner: statsInput.observabilityOwner,
    runtimeOwner: statsInput.runtimeOwner,
    observabilityPolicy: statsInput.observabilityPolicy,
    observabilityMode: statsInput.observabilityMode,
    sourceRoot: statsInput.sourceRoot,
    targetRoot: statsInput.targetRoot,
    observabilityContractDeclared: statsInput.observabilityContractDeclared,
    observedCollections: statsInput.observedCollections,
    requiredMetrics: statsInput.requiredMetrics,
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
    sourceScanExecuted: statsInput.sourceScanExecuted,
    targetScanExecuted: statsInput.targetScanExecuted,
    sourceCountsCollected: statsInput.sourceCountsCollected,
    targetCountsCollected: statsInput.targetCountsCollected,
    migrationSignatureComputed: statsInput.migrationSignatureComputed,
    blockingAnomaliesDetected: statsInput.blockingAnomaliesDetected,
    schemaChanged: statsInput.schemaChanged,
    runtimeContractChanged: statsInput.runtimeContractChanged,
    obsoleteHandlers: obsoleteHandlers,
    error: statsInput.error
  });
  statsInput.ok = violations.length === 0;
  statsInput.reason = violations.length ? 'm3_observability_violation' : 'm3_observability_ready';
  statsInput.violations = violations;
  return buildMigration3ObservabilityResultFromStats_(statsInput);
}

function buildMigration3ObservabilityViolations_(data) {
  data = data || {};
  var violations = [];
  if (!data.backendRoutePresent) violations.push('m3_backend_route_status_missing');
  if (data.backendRoutePresent && !data.backendRouteOk) violations.push('m3_backend_route_not_ok');
  if (String(data.backendRouteVersion || '') !== PHBOX_M3_OBSERVABILITY_REQUIRED_BACKEND_ROUTE_VERSION_) violations.push('m3_backend_route_version_mismatch');
  if (String(data.observabilityVersion || '') !== PHBOX_M3_OBSERVABILITY_VERSION_) violations.push('observability_version_mismatch');
  if (String(data.observabilityOwner || '') !== PHBOX_M3_OBSERVABILITY_OWNER_) violations.push('observability_owner_mismatch');
  if (String(data.runtimeOwner || '') !== PHBOX_M3_OBSERVABILITY_RUNTIME_OWNER_) violations.push('observability_runtime_owner_mismatch');
  if (String(data.observabilityPolicy || '') !== PHBOX_M3_OBSERVABILITY_POLICY_) violations.push('observability_policy_mismatch');
  if (String(data.observabilityMode || '') !== PHBOX_M3_OBSERVABILITY_MODE_) violations.push('observability_mode_mismatch');
  if (String(data.sourceRoot || '') !== PHBOX_M3_OBSERVABILITY_SOURCE_ROOT_) violations.push('observability_source_root_mismatch');
  if (String(data.targetRoot || '') !== PHBOX_M3_OBSERVABILITY_TARGET_ROOT_) violations.push('observability_target_root_mismatch');
  if (!data.observabilityContractDeclared) violations.push('observability_contract_not_declared');
  migration3ObservabilityMissingItems_(PHBOX_M3_OBSERVABILITY_COLLECTIONS_, data.observedCollections || []).forEach(function (collection) {
    violations.push('missing_observed_collection_' + collection.replace(/[^a-zA-Z0-9]+/g, '_'));
  });
  migration3ObservabilityMissingItems_(PHBOX_M3_OBSERVABILITY_METRICS_, data.requiredMetrics || []).forEach(function (metric) {
    violations.push('missing_required_metric_' + metric);
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
  if (data.sourceScanExecuted) violations.push('source_scan_executed_before_m4_plan');
  if (data.targetScanExecuted) violations.push('target_scan_executed_before_m4_plan');
  if (data.sourceCountsCollected) violations.push('source_counts_collected_before_m4_plan');
  if (data.targetCountsCollected) violations.push('target_counts_collected_before_m4_plan');
  if (data.migrationSignatureComputed) violations.push('migration_signature_computed_before_m4_plan');
  if (data.blockingAnomaliesDetected) violations.push('blocking_anomalies_detected');
  if (data.schemaChanged) violations.push('schema_changed');
  if (data.runtimeContractChanged) violations.push('runtime_contract_changed');
  if (uniqueNonEmptyStrings_(data.obsoleteHandlers || []).length > 0) violations.push('obsolete_settings_handlers_detected');
  if (data.error) violations.push('m3_observability_error');
  return uniqueNonEmptyStrings_(violations);
}

function migration3ObservabilityMissingItems_(expected, actual) {
  expected = uniqueNonEmptyStrings_(expected || []);
  actual = uniqueNonEmptyStrings_(actual || []);
  return expected.filter(function (item) { return actual.indexOf(item) === -1; });
}

function buildMigration3ObservabilityResultFromStats_(data) {
  data = data || {};
  var stats = buildMigration3ObservabilityStats_(data);
  return {
    ok: data.ok !== false,
    stats: stats,
    violations: uniqueNonEmptyStrings_(data.violations || []),
    items: data.items || []
  };
}

function buildMigration3ObservabilityStats_(data) {
  data = data || {};
  return {
    stage: PHBOX_M3_OBSERVABILITY_STAGE_,
    ok: data.ok !== false,
    skipped: data.skipped !== false,
    reason: String(data.reason || ''),
    observabilityVersion: String(data.observabilityVersion || ''),
    requiredBackendRouteVersion: PHBOX_M3_OBSERVABILITY_REQUIRED_BACKEND_ROUTE_VERSION_,
    backendRouteVersion: String(data.backendRouteVersion || ''),
    frontRouteVersion: String(data.frontRouteVersion || ''),
    authVersion: String(data.authVersion || ''),
    costGuardVersion: String(data.costGuardVersion || ''),
    configVersion: String(data.configVersion || ''),
    registryVersion: String(data.registryVersion || ''),
    observabilityOwner: String(data.observabilityOwner || ''),
    runtimeOwner: String(data.runtimeOwner || ''),
    observabilityPolicy: String(data.observabilityPolicy || ''),
    observabilityMode: String(data.observabilityMode || ''),
    sourceRoot: String(data.sourceRoot || ''),
    targetRoot: String(data.targetRoot || ''),
    observabilityContractDeclared: !!data.observabilityContractDeclared,
    observedCollections: uniqueNonEmptyStrings_(data.observedCollections || []),
    requiredMetrics: uniqueNonEmptyStrings_(data.requiredMetrics || []),
    observedCollectionsCount: uniqueNonEmptyStrings_(data.observedCollections || []).length,
    requiredMetricsCount: uniqueNonEmptyStrings_(data.requiredMetrics || []).length,
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
    sourceScanExecuted: !!data.sourceScanExecuted,
    targetScanExecuted: !!data.targetScanExecuted,
    sourceCountsCollected: !!data.sourceCountsCollected,
    targetCountsCollected: !!data.targetCountsCollected,
    migrationSignatureComputed: !!data.migrationSignatureComputed,
    blockingAnomaliesDetected: !!data.blockingAnomaliesDetected,
    schemaChanged: !!data.schemaChanged,
    runtimeContractChanged: !!data.runtimeContractChanged,
    obsoleteHandlers: uniqueNonEmptyStrings_(data.obsoleteHandlers || []),
    violations: uniqueNonEmptyStrings_(data.violations || []),
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };
}

function listMigration3ObservabilityObsoleteSettingsHandlers_() {
  var obsolete = [
    'runMigration3BackendRouteSettingsTest',
    'getMigration3BackendRouteSettingsStatus'
  ].filter(function (name) {
    try {
      if (typeof globalThis !== 'undefined' && typeof globalThis[name] === 'function') return true;
      return typeof this !== 'undefined' && typeof this[name] === 'function';
    } catch (e) {
      return false;
    }
  });
  if (typeof listMigration3BackendRouteObsoleteSettingsHandlers_ === 'function') {
    obsolete = obsolete.concat(listMigration3BackendRouteObsoleteSettingsHandlers_());
  }
  return uniqueNonEmptyStrings_(obsolete);
}

function runMigration3ObservabilitySelfTest_() {
  var cleanContract = buildMigration3ObservabilityContract_();
  var cases = [
    {
      id: 'clean_backend_route_authorizes_observability_contract',
      result: buildMigration3ObservabilityResult_({ backendRouteStatus: buildMigration3ObservabilitySyntheticBackendRouteStatus_({}), contract: cleanContract }),
      expected: { ok: true, violation: '' }
    },
    {
      id: 'missing_backend_route_blocks_observability',
      result: buildMigration3ObservabilityResult_({ backendRouteStatus: null, contract: cleanContract }),
      expected: { ok: false, violation: 'm3_backend_route_status_missing' }
    },
    {
      id: 'backend_route_not_ok_blocks_observability',
      result: buildMigration3ObservabilityResult_({ backendRouteStatus: buildMigration3ObservabilitySyntheticBackendRouteStatus_({ ok: false }), contract: cleanContract }),
      expected: { ok: false, violation: 'm3_backend_route_not_ok' }
    },
    {
      id: 'backend_route_version_mismatch_blocks_observability',
      result: buildMigration3ObservabilityResult_({ backendRouteStatus: buildMigration3ObservabilitySyntheticBackendRouteStatus_({ backendRouteVersion: 'M3_BACKEND_ROUTE_v0' }), contract: cleanContract }),
      expected: { ok: false, violation: 'm3_backend_route_version_mismatch' }
    },
    {
      id: 'observability_version_mismatch_blocks_observability',
      result: buildMigration3ObservabilityResult_({ backendRouteStatus: buildMigration3ObservabilitySyntheticBackendRouteStatus_({}), contract: migration3ObservabilitySyntheticContract_({ observabilityVersion: 'M3_OBSERVABILITY_v0' }) }),
      expected: { ok: false, violation: 'observability_version_mismatch' }
    },
    {
      id: 'observability_owner_mismatch_blocks_observability',
      result: buildMigration3ObservabilityResult_({ backendRouteStatus: buildMigration3ObservabilitySyntheticBackendRouteStatus_({}), contract: migration3ObservabilitySyntheticContract_({ owner: 'runtime_observer' }) }),
      expected: { ok: false, violation: 'observability_owner_mismatch' }
    },
    {
      id: 'observability_policy_mismatch_blocks_observability',
      result: buildMigration3ObservabilityResult_({ backendRouteStatus: buildMigration3ObservabilitySyntheticBackendRouteStatus_({}), contract: migration3ObservabilitySyntheticContract_({ observabilityPolicy: 'scan_source_now' }) }),
      expected: { ok: false, violation: 'observability_policy_mismatch' }
    },
    {
      id: 'observability_contract_not_declared_blocks_observability',
      result: buildMigration3ObservabilityResult_({ backendRouteStatus: buildMigration3ObservabilitySyntheticBackendRouteStatus_({}), contract: migration3ObservabilitySyntheticContract_({ observabilityContractDeclared: false }) }),
      expected: { ok: false, violation: 'observability_contract_not_declared' }
    },
    {
      id: 'missing_collection_blocks_observability',
      result: buildMigration3ObservabilityResult_({ backendRouteStatus: buildMigration3ObservabilitySyntheticBackendRouteStatus_({}), contract: migration3ObservabilitySyntheticContract_({ observedCollections: ['patients'] }) }),
      expected: { ok: false, violation: 'missing_observed_collection_doctor_patient_links' }
    },
    {
      id: 'missing_metric_blocks_observability',
      result: buildMigration3ObservabilityResult_({ backendRouteStatus: buildMigration3ObservabilitySyntheticBackendRouteStatus_({}), contract: migration3ObservabilitySyntheticContract_({ requiredMetrics: ['sourcePatientsCount'] }) }),
      expected: { ok: false, violation: 'missing_required_metric_sourceFamiliesCount' }
    },
    {
      id: 'firestore_read_or_write_blocks_observability',
      result: buildMigration3ObservabilityResult_({ backendRouteStatus: buildMigration3ObservabilitySyntheticBackendRouteStatus_({ firestoreReads: 1, firestoreWrites: 1 }), contract: cleanContract }),
      expected: { ok: false, violation: 'firestore_reads_detected' }
    },
    {
      id: 'registry_or_config_read_write_blocks_observability',
      result: buildMigration3ObservabilityResult_({ backendRouteStatus: buildMigration3ObservabilitySyntheticBackendRouteStatus_({ registryReads: 1, registryWrites: 1, configReads: 1, configWrites: 1 }), contract: cleanContract }),
      expected: { ok: false, violation: 'registry_reads_detected' }
    },
    {
      id: 'listener_query_fanout_blocks_observability',
      result: buildMigration3ObservabilityResult_({ backendRouteStatus: buildMigration3ObservabilitySyntheticBackendRouteStatus_({ listeners: 1, queries: 1, fanOut: 1 }), contract: cleanContract }),
      expected: { ok: false, violation: 'listeners_detected' }
    },
    {
      id: 'target_or_tenant_path_blocks_observability',
      result: buildMigration3ObservabilityResult_({ backendRouteStatus: buildMigration3ObservabilitySyntheticBackendRouteStatus_({ targetPathBuilt: true, tenantTargetPathBuilt: true }), contract: cleanContract }),
      expected: { ok: false, violation: 'target_path_built' }
    },
    {
      id: 'backend_runtime_blocks_observability',
      result: buildMigration3ObservabilityResult_({ backendRouteStatus: buildMigration3ObservabilitySyntheticBackendRouteStatus_({ backendRouteRuntimeChanged: true, backendRouteResolved: true, backendDispatchExecuted: true, backendRunStarted: true, triggerInstalled: true }), contract: cleanContract }),
      expected: { ok: false, violation: 'backend_route_runtime_changed' }
    },
    {
      id: 'source_or_target_scan_blocks_observability',
      result: buildMigration3ObservabilityResult_({ backendRouteStatus: buildMigration3ObservabilitySyntheticBackendRouteStatus_({}), contract: migration3ObservabilitySyntheticContract_({ sourceScanExecuted: true, targetScanExecuted: true }) }),
      expected: { ok: false, violation: 'source_scan_executed_before_m4_plan' }
    },
    {
      id: 'counts_or_signature_blocks_observability',
      result: buildMigration3ObservabilityResult_({ backendRouteStatus: buildMigration3ObservabilitySyntheticBackendRouteStatus_({}), contract: migration3ObservabilitySyntheticContract_({ sourceCountsCollected: true, targetCountsCollected: true, migrationSignatureComputed: true }) }),
      expected: { ok: false, violation: 'source_counts_collected_before_m4_plan' }
    },
    {
      id: 'blocking_anomalies_blocks_observability',
      result: buildMigration3ObservabilityResult_({ backendRouteStatus: buildMigration3ObservabilitySyntheticBackendRouteStatus_({}), contract: migration3ObservabilitySyntheticContract_({ blockingAnomaliesDetected: true }) }),
      expected: { ok: false, violation: 'blocking_anomalies_detected' }
    },
    {
      id: 'lifecycle_or_route_blocks_observability',
      result: buildMigration3ObservabilityResult_({ backendRouteStatus: buildMigration3ObservabilitySyntheticBackendRouteStatus_({ lifecycleTouched: true, tenantRoutingActive: true }), contract: cleanContract }),
      expected: { ok: false, violation: 'lifecycle_touched' }
    },
    {
      id: 'schema_or_runtime_contract_blocks_observability',
      result: buildMigration3ObservabilityResult_({ backendRouteStatus: buildMigration3ObservabilitySyntheticBackendRouteStatus_({ schemaChanged: true, runtimeContractChanged: true }), contract: cleanContract }),
      expected: { ok: false, violation: 'schema_changed' }
    },
    {
      id: 'obsolete_settings_handler_blocks_observability',
      result: buildMigration3ObservabilityResult_({ backendRouteStatus: buildMigration3ObservabilitySyntheticBackendRouteStatus_({}), contract: cleanContract, obsoleteHandlers: ['runMigration3BackendRouteSettingsTest'] }),
      expected: { ok: false, violation: 'obsolete_settings_handlers_detected' }
    },
    {
      id: 'runtime_error_blocks_observability',
      result: buildMigration3ObservabilityResult_({ backendRouteStatus: buildMigration3ObservabilitySyntheticBackendRouteStatus_({}), contract: cleanContract, error: 'synthetic error', errorKind: 'synthetic' }),
      expected: { ok: false, violation: 'm3_observability_error' }
    }
  ];

  var items = cases.map(function (entry) {
    var stats = entry.result.stats || {};
    var violations = uniqueNonEmptyStrings_(stats.violations || []);
    var okMatches = !!stats.ok === !!entry.expected.ok;
    var violationMatches = !entry.expected.violation || violations.indexOf(entry.expected.violation) !== -1;
    return {
      id: entry.id,
      passed: okMatches && violationMatches,
      stats: stats
    };
  });
  var failed = items.filter(function (item) { return !item.passed; });
  var cleanStats = (cases[0].result && cases[0].result.stats) || buildMigration3ObservabilityStats_({});
  return buildMigration3ObservabilityResultFromStats_(Object.assign({}, cleanStats, {
    ok: failed.length === 0,
    reason: failed.length ? 'm3_observability_selftest_failed' : 'm3_observability_selftest_passed',
    violations: failed.map(function (item) { return item.id; }),
    items: items
  }));
}

function buildMigration3ObservabilitySyntheticBackendRouteStatus_(overrides) {
  overrides = overrides || {};
  var stats = {
    ok: overrides.ok !== false,
    backendRouteVersion: overrides.backendRouteVersion || PHBOX_M3_OBSERVABILITY_REQUIRED_BACKEND_ROUTE_VERSION_,
    frontRouteVersion: overrides.frontRouteVersion || 'M3_FRONT_ROUTE_v1',
    authVersion: overrides.authVersion || 'M3_AUTH_v1',
    costGuardVersion: overrides.costGuardVersion || 'M3_COST_GUARD_v1',
    configVersion: overrides.configVersion || 'M3_TENANT_CONFIG_v1',
    registryVersion: overrides.registryVersion || 'M3_TENANT_REGISTRY_v1',
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
    backendRouteRuntimeChanged: !!overrides.backendRouteRuntimeChanged,
    backendRouteResolved: !!overrides.backendRouteResolved,
    backendDispatchExecuted: !!overrides.backendDispatchExecuted,
    backendRunStarted: !!overrides.backendRunStarted,
    triggerInstalled: !!overrides.triggerInstalled,
    schemaChanged: !!overrides.schemaChanged,
    runtimeContractChanged: !!overrides.runtimeContractChanged,
    obsoleteHandlers: uniqueNonEmptyStrings_(overrides.obsoleteHandlers || [])
  };
  return { ok: stats.ok, stats: stats };
}

function migration3ObservabilitySyntheticContract_(overrides) {
  overrides = overrides || {};
  var contract = buildMigration3ObservabilityContract_();
  Object.keys(overrides).forEach(function (key) { contract[key] = overrides[key]; });
  return contract;
}

function formatMigration3ObservabilityRuntimeFeedback_(result) {
  var stats = (result && result.stats) || {};
  var lines = [];
  lines.push('MIGRATION_3_OBSERVABILITY_RUNTIME_STATUS');
  appendMigration3ObservabilityStatsLines_(lines, stats);
  return lines.join('\n');
}

function formatMigration3ObservabilitySelfTestFeedback_(result) {
  var stats = (result && result.stats) || {};
  var items = (result && result.items) || [];
  var lines = [];
  lines.push('MIGRATION_3_OBSERVABILITY_TEST');
  lines.push('ok=' + String(!!(result && result.ok)));
  lines.push('testCount=' + String(items.length));
  lines.push('passedCount=' + String(items.filter(function (item) { return !!item.passed; }).length));
  lines.push('failedCount=' + String(items.filter(function (item) { return !item.passed; }).length));
  lines.push('reason=' + String(stats.reason || ''));
  appendMigration3ObservabilityStatsLines_(lines, stats);
  lines.push('items=');
  items.forEach(function (item) {
    var itemStats = item.stats || {};
    lines.push('- id=' + item.id);
    lines.push('  passed=' + String(!!item.passed));
    lines.push('  ok=' + String(!!itemStats.ok));
    lines.push('  reason=' + String(itemStats.reason || ''));
    lines.push('  observabilityVersion=' + String(itemStats.observabilityVersion || ''));
    lines.push('  backendRouteVersion=' + String(itemStats.backendRouteVersion || ''));
    lines.push('  observabilityPolicy=' + String(itemStats.observabilityPolicy || ''));
    lines.push('  observabilityContractDeclared=' + String(!!itemStats.observabilityContractDeclared));
    lines.push('  observedCollectionsCount=' + String(itemStats.observedCollectionsCount || 0));
    lines.push('  requiredMetricsCount=' + String(itemStats.requiredMetricsCount || 0));
    lines.push('  firestoreReads=' + String(itemStats.firestoreReads || 0));
    lines.push('  firestoreWrites=' + String(itemStats.firestoreWrites || 0));
    lines.push('  registryReads=' + String(itemStats.registryReads || 0));
    lines.push('  registryWrites=' + String(itemStats.registryWrites || 0));
    lines.push('  configReads=' + String(itemStats.configReads || 0));
    lines.push('  configWrites=' + String(itemStats.configWrites || 0));
    lines.push('  listeners=' + String(itemStats.listeners || 0));
    lines.push('  queries=' + String(itemStats.queries || 0));
    lines.push('  fanOut=' + String(itemStats.fanOut || 0));
    lines.push('  sourceScanExecuted=' + String(!!itemStats.sourceScanExecuted));
    lines.push('  targetScanExecuted=' + String(!!itemStats.targetScanExecuted));
    lines.push('  sourceCountsCollected=' + String(!!itemStats.sourceCountsCollected));
    lines.push('  targetCountsCollected=' + String(!!itemStats.targetCountsCollected));
    lines.push('  migrationSignatureComputed=' + String(!!itemStats.migrationSignatureComputed));
    lines.push('  violations=' + formatMigration3ObservabilityList_(itemStats.violations));
  });
  return lines.join('\n');
}

function appendMigration3ObservabilityStatsLines_(lines, stats) {
  stats = stats || {};
  lines.push('ok=' + String(!!stats.ok));
  lines.push('skipped=' + String(!!stats.skipped));
  lines.push('reason=' + String(stats.reason || ''));
  lines.push('observabilityVersion=' + String(stats.observabilityVersion || ''));
  lines.push('requiredBackendRouteVersion=' + String(stats.requiredBackendRouteVersion || ''));
  lines.push('backendRouteVersion=' + String(stats.backendRouteVersion || ''));
  lines.push('frontRouteVersion=' + String(stats.frontRouteVersion || ''));
  lines.push('authVersion=' + String(stats.authVersion || ''));
  lines.push('costGuardVersion=' + String(stats.costGuardVersion || ''));
  lines.push('configVersion=' + String(stats.configVersion || ''));
  lines.push('registryVersion=' + String(stats.registryVersion || ''));
  lines.push('observabilityOwner=' + String(stats.observabilityOwner || ''));
  lines.push('runtimeOwner=' + String(stats.runtimeOwner || ''));
  lines.push('observabilityPolicy=' + String(stats.observabilityPolicy || ''));
  lines.push('observabilityMode=' + String(stats.observabilityMode || ''));
  lines.push('sourceRoot=' + String(stats.sourceRoot || ''));
  lines.push('targetRoot=' + String(stats.targetRoot || ''));
  lines.push('observabilityContractDeclared=' + String(!!stats.observabilityContractDeclared));
  lines.push('observedCollectionsCount=' + String(stats.observedCollectionsCount || 0));
  lines.push('requiredMetricsCount=' + String(stats.requiredMetricsCount || 0));
  lines.push('observedCollections=' + formatMigration3ObservabilityList_(stats.observedCollections));
  lines.push('requiredMetrics=' + formatMigration3ObservabilityList_(stats.requiredMetrics));
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
  lines.push('sourceScanExecuted=' + String(!!stats.sourceScanExecuted));
  lines.push('targetScanExecuted=' + String(!!stats.targetScanExecuted));
  lines.push('sourceCountsCollected=' + String(!!stats.sourceCountsCollected));
  lines.push('targetCountsCollected=' + String(!!stats.targetCountsCollected));
  lines.push('migrationSignatureComputed=' + String(!!stats.migrationSignatureComputed));
  lines.push('blockingAnomaliesDetected=' + String(!!stats.blockingAnomaliesDetected));
  lines.push('schemaChanged=' + String(!!stats.schemaChanged));
  lines.push('runtimeContractChanged=' + String(!!stats.runtimeContractChanged));
  lines.push('obsoleteHandlers=' + formatMigration3ObservabilityList_(stats.obsoleteHandlers));
  lines.push('violations=' + formatMigration3ObservabilityList_(stats.violations));
  lines.push('error=' + String(stats.error || 'none'));
  lines.push('errorKind=' + String(stats.errorKind || 'none'));
}

function formatMigration3ObservabilityList_(items) {
  items = uniqueNonEmptyStrings_(items || []);
  return items.length ? items.join(',') : 'none';
}
