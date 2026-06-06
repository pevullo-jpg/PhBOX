var PHBOX_M3_E2E_VERSION_ = 'M3_E2E_v1';
var PHBOX_M3_E2E_STAGE_ = 'migration3_e2e';
var PHBOX_M3_E2E_REQUIRED_RECOVERY_VERSION_ = 'M3_RECOVERY_v1';
var PHBOX_M3_E2E_OWNER_ = 'backend_gas_e2e_contract_only';
var PHBOX_M3_E2E_RUNTIME_OWNER_ = 'future_m3_freeze_and_m4_lock';
var PHBOX_M3_E2E_POLICY_ = 'no_e2e_runtime_side_effect_before_m3_freeze';
var PHBOX_M3_E2E_MODE_ = 'pre_m3_freeze_chain_validation_contract';
var PHBOX_M3_E2E_M4_READINESS_MODE_ = 'contract_ready_no_materialization';
var PHBOX_M3_E2E_REQUIRED_STAGES_ = [
  'm3_lock',
  'm3_tenant_registry',
  'm3_tenant_config',
  'm3_cost_guard',
  'm3_auth',
  'm3_front_route',
  'm3_backend_route',
  'm3_observability',
  'm3_recovery'
];
var PHBOX_M3_E2E_REQUIRED_CHECKS_ = [
  'version_chain',
  'zero_costs',
  'no_runtime_routing',
  'no_backend_dispatch',
  'no_recovery_execution',
  'no_source_scan',
  'no_target_scan',
  'no_schema_change',
  'no_obsolete_handlers',
  'm4_readiness_declared',
  'settings_single_handler',
  'freeze_allowed'
];

function runMigration3E2eRuntimeStatus_() {
  try {
    if (typeof runMigration3RecoveryRuntimeStatus_ !== 'function') {
      throw new Error('M3_E2E_RECOVERY_MISSING: funzione runMigration3RecoveryRuntimeStatus_ non disponibile. E2E non autorizzabile.');
    }
    return buildMigration3E2eResult_({
      recoveryStatus: runMigration3RecoveryRuntimeStatus_(),
      contract: buildMigration3E2eContract_(),
      obsoleteHandlers: listMigration3E2eObsoleteSettingsHandlers_()
    });
  } catch (e) {
    return buildMigration3E2eResult_({
      recoveryStatus: null,
      contract: buildMigration3E2eContract_(),
      obsoleteHandlers: listMigration3E2eObsoleteSettingsHandlers_(),
      error: normalizeMigration3E2eErrorMessage_(e),
      errorKind: classifyMigration3E2eErrorKind_(e)
    });
  }
}

function buildMigration3E2eContract_() {
  return {
    e2eVersion: PHBOX_M3_E2E_VERSION_,
    owner: PHBOX_M3_E2E_OWNER_,
    runtimeOwner: PHBOX_M3_E2E_RUNTIME_OWNER_,
    e2ePolicy: PHBOX_M3_E2E_POLICY_,
    e2eMode: PHBOX_M3_E2E_MODE_,
    m4ReadinessMode: PHBOX_M3_E2E_M4_READINESS_MODE_,
    requiredStages: PHBOX_M3_E2E_REQUIRED_STAGES_.slice(),
    requiredChecks: PHBOX_M3_E2E_REQUIRED_CHECKS_.slice(),
    e2eContractDeclared: true,
    m3ChainComplete: true,
    m4ReadinessDeclared: true,
    m3FreezeAllowed: true,
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
    recoveryStateRead: false,
    recoveryStateWritten: false,
    recoveryCheckpointWritten: false,
    recoveryCursorAdvanced: false,
    recoveryResumeExecuted: false,
    partialWriteRecoveryExecuted: false,
    idempotentRetryExecuted: false,
    e2eRuntimeExecuted: false,
    e2eSideEffectsExecuted: false,
    m4MaterializeStarted: false,
    schemaChanged: false,
    runtimeContractChanged: false
  };
}

function buildMigration3E2eResult_(data) {
  data = data || {};
  var recoveryStatus = data.recoveryStatus || null;
  var recoveryStats = (recoveryStatus && recoveryStatus.stats) || {};
  var contract = data.contract || {};
  var obsoleteHandlers = uniqueMigration3E2eStrings_([].concat(
    recoveryStats.obsoleteHandlers || [],
    data.obsoleteHandlers || []
  ));
  var statsInput = {
    ok: !!(recoveryStatus && recoveryStatus.ok) && recoveryStats.ok !== false,
    skipped: false,
    reason: '',
    e2eVersion: String(contract.e2eVersion || ''),
    requiredRecoveryVersion: PHBOX_M3_E2E_REQUIRED_RECOVERY_VERSION_,
    recoveryVersion: String(recoveryStats.recoveryVersion || ''),
    observabilityVersion: String(recoveryStats.observabilityVersion || ''),
    backendRouteVersion: String(recoveryStats.backendRouteVersion || ''),
    frontRouteVersion: String(recoveryStats.frontRouteVersion || ''),
    authVersion: String(recoveryStats.authVersion || ''),
    costGuardVersion: String(recoveryStats.costGuardVersion || ''),
    configVersion: String(recoveryStats.configVersion || ''),
    registryVersion: String(recoveryStats.registryVersion || ''),
    e2eOwner: String(contract.owner || ''),
    runtimeOwner: String(contract.runtimeOwner || ''),
    e2ePolicy: String(contract.e2ePolicy || ''),
    e2eMode: String(contract.e2eMode || ''),
    m4ReadinessMode: String(contract.m4ReadinessMode || ''),
    e2eContractDeclared: !!contract.e2eContractDeclared,
    requiredStages: uniqueMigration3E2eStrings_(contract.requiredStages || []),
    requiredChecks: uniqueMigration3E2eStrings_(contract.requiredChecks || []),
    m3ChainComplete: !!contract.m3ChainComplete,
    m4ReadinessDeclared: !!contract.m4ReadinessDeclared,
    m3FreezeAllowed: !!contract.m3FreezeAllowed,
    firestoreReads: Math.max(0, Number(recoveryStats.firestoreReads || 0) + Number(contract.firestoreReads || 0) + Number(data.firestoreReads || 0)),
    firestoreWrites: Math.max(0, Number(recoveryStats.firestoreWrites || 0) + Number(contract.firestoreWrites || 0) + Number(data.firestoreWrites || 0)),
    estimatedReadsPerHour: Math.max(0, Number(recoveryStats.estimatedReadsPerHour || 0) + Number(data.estimatedReadsPerHour || 0)),
    estimatedWritesPerHour: Math.max(0, Number(recoveryStats.estimatedWritesPerHour || 0) + Number(data.estimatedWritesPerHour || 0)),
    registryReads: Math.max(0, Number(recoveryStats.registryReads || 0) + Number(contract.registryReads || 0) + Number(data.registryReads || 0)),
    registryWrites: Math.max(0, Number(recoveryStats.registryWrites || 0) + Number(contract.registryWrites || 0) + Number(data.registryWrites || 0)),
    configReads: Math.max(0, Number(recoveryStats.configReads || 0) + Number(contract.configReads || 0) + Number(data.configReads || 0)),
    configWrites: Math.max(0, Number(recoveryStats.configWrites || 0) + Number(contract.configWrites || 0) + Number(data.configWrites || 0)),
    targetWritesExecuted: Math.max(0, Number(recoveryStats.targetWritesExecuted || 0) + Number(contract.targetWritesExecuted || 0) + Number(data.targetWritesExecuted || 0)),
    listeners: Math.max(0, Number(recoveryStats.listeners || 0) + Number(contract.listeners || 0) + Number(data.listeners || 0)),
    queries: Math.max(0, Number(recoveryStats.queries || 0) + Number(contract.queries || 0) + Number(data.queries || 0)),
    fanOut: Math.max(0, Number(recoveryStats.fanOut || 0) + Number(contract.fanOut || 0) + Number(data.fanOut || 0)),
    targetPathBuilt: !!recoveryStats.targetPathBuilt || !!contract.targetPathBuilt || !!data.targetPathBuilt,
    tenantTargetPathBuilt: !!recoveryStats.tenantTargetPathBuilt || !!contract.tenantTargetPathBuilt || !!data.tenantTargetPathBuilt,
    tenantConfigTouched: !!recoveryStats.tenantConfigTouched || !!contract.tenantConfigTouched || !!data.tenantConfigTouched,
    lifecycleTouched: !!recoveryStats.lifecycleTouched || !!contract.lifecycleTouched || !!data.lifecycleTouched,
    authRuntimeChanged: !!recoveryStats.authRuntimeChanged || !!contract.authRuntimeChanged || !!data.authRuntimeChanged,
    authProviderTouched: !!recoveryStats.authProviderTouched || !!contract.authProviderTouched || !!data.authProviderTouched,
    authTokenValidated: !!recoveryStats.authTokenValidated || !!contract.authTokenValidated || !!data.authTokenValidated,
    sessionCreated: !!recoveryStats.sessionCreated || !!contract.sessionCreated || !!data.sessionCreated,
    tenantRoutingActive: !!recoveryStats.tenantRoutingActive || !!contract.tenantRoutingActive || !!data.tenantRoutingActive,
    frontRouteRuntimeChanged: !!recoveryStats.frontRouteRuntimeChanged || !!contract.frontRouteRuntimeChanged || !!data.frontRouteRuntimeChanged,
    routeResolved: !!recoveryStats.routeResolved || !!contract.routeResolved || !!data.routeResolved,
    navigationChanged: !!recoveryStats.navigationChanged || !!contract.navigationChanged || !!data.navigationChanged,
    backendRouteRuntimeChanged: !!recoveryStats.backendRouteRuntimeChanged || !!contract.backendRouteRuntimeChanged || !!data.backendRouteRuntimeChanged,
    backendRouteResolved: !!recoveryStats.backendRouteResolved || !!contract.backendRouteResolved || !!data.backendRouteResolved,
    backendDispatchExecuted: !!recoveryStats.backendDispatchExecuted || !!contract.backendDispatchExecuted || !!data.backendDispatchExecuted,
    backendRunStarted: !!recoveryStats.backendRunStarted || !!contract.backendRunStarted || !!data.backendRunStarted,
    triggerInstalled: !!recoveryStats.triggerInstalled || !!contract.triggerInstalled || !!data.triggerInstalled,
    sourceScanExecuted: !!recoveryStats.sourceScanExecuted || !!contract.sourceScanExecuted || !!data.sourceScanExecuted,
    targetScanExecuted: !!recoveryStats.targetScanExecuted || !!contract.targetScanExecuted || !!data.targetScanExecuted,
    sourceCountsCollected: !!recoveryStats.sourceCountsCollected || !!contract.sourceCountsCollected || !!data.sourceCountsCollected,
    targetCountsCollected: !!recoveryStats.targetCountsCollected || !!contract.targetCountsCollected || !!data.targetCountsCollected,
    migrationSignatureComputed: !!recoveryStats.migrationSignatureComputed || !!contract.migrationSignatureComputed || !!data.migrationSignatureComputed,
    blockingAnomaliesDetected: !!recoveryStats.blockingAnomaliesDetected || !!contract.blockingAnomaliesDetected || !!data.blockingAnomaliesDetected,
    recoveryStateRead: !!recoveryStats.recoveryStateRead || !!contract.recoveryStateRead || !!data.recoveryStateRead,
    recoveryStateWritten: !!recoveryStats.recoveryStateWritten || !!contract.recoveryStateWritten || !!data.recoveryStateWritten,
    recoveryCheckpointWritten: !!recoveryStats.recoveryCheckpointWritten || !!contract.recoveryCheckpointWritten || !!data.recoveryCheckpointWritten,
    recoveryCursorAdvanced: !!recoveryStats.recoveryCursorAdvanced || !!contract.recoveryCursorAdvanced || !!data.recoveryCursorAdvanced,
    recoveryResumeExecuted: !!recoveryStats.recoveryResumeExecuted || !!contract.recoveryResumeExecuted || !!data.recoveryResumeExecuted,
    partialWriteRecoveryExecuted: !!recoveryStats.partialWriteRecoveryExecuted || !!contract.partialWriteRecoveryExecuted || !!data.partialWriteRecoveryExecuted,
    idempotentRetryExecuted: !!recoveryStats.idempotentRetryExecuted || !!contract.idempotentRetryExecuted || !!data.idempotentRetryExecuted,
    e2eRuntimeExecuted: !!contract.e2eRuntimeExecuted || !!data.e2eRuntimeExecuted,
    e2eSideEffectsExecuted: !!contract.e2eSideEffectsExecuted || !!data.e2eSideEffectsExecuted,
    m4MaterializeStarted: !!contract.m4MaterializeStarted || !!data.m4MaterializeStarted,
    schemaChanged: !!recoveryStats.schemaChanged || !!contract.schemaChanged || !!data.schemaChanged,
    runtimeContractChanged: !!recoveryStats.runtimeContractChanged || !!contract.runtimeContractChanged || !!data.runtimeContractChanged,
    obsoleteHandlers: obsoleteHandlers,
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };
  var violations = buildMigration3E2eViolations_({
    recoveryPresent: !!(recoveryStatus && recoveryStatus.stats),
    recoveryOk: statsInput.ok,
    recoveryVersion: statsInput.recoveryVersion,
    observabilityVersion: statsInput.observabilityVersion,
    backendRouteVersion: statsInput.backendRouteVersion,
    frontRouteVersion: statsInput.frontRouteVersion,
    authVersion: statsInput.authVersion,
    costGuardVersion: statsInput.costGuardVersion,
    configVersion: statsInput.configVersion,
    registryVersion: statsInput.registryVersion,
    e2eVersion: statsInput.e2eVersion,
    e2eOwner: statsInput.e2eOwner,
    runtimeOwner: statsInput.runtimeOwner,
    e2ePolicy: statsInput.e2ePolicy,
    e2eMode: statsInput.e2eMode,
    m4ReadinessMode: statsInput.m4ReadinessMode,
    e2eContractDeclared: statsInput.e2eContractDeclared,
    requiredStages: statsInput.requiredStages,
    requiredChecks: statsInput.requiredChecks,
    m3ChainComplete: statsInput.m3ChainComplete,
    m4ReadinessDeclared: statsInput.m4ReadinessDeclared,
    m3FreezeAllowed: statsInput.m3FreezeAllowed,
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
    recoveryStateRead: statsInput.recoveryStateRead,
    recoveryStateWritten: statsInput.recoveryStateWritten,
    recoveryCheckpointWritten: statsInput.recoveryCheckpointWritten,
    recoveryCursorAdvanced: statsInput.recoveryCursorAdvanced,
    recoveryResumeExecuted: statsInput.recoveryResumeExecuted,
    partialWriteRecoveryExecuted: statsInput.partialWriteRecoveryExecuted,
    idempotentRetryExecuted: statsInput.idempotentRetryExecuted,
    e2eRuntimeExecuted: statsInput.e2eRuntimeExecuted,
    e2eSideEffectsExecuted: statsInput.e2eSideEffectsExecuted,
    m4MaterializeStarted: statsInput.m4MaterializeStarted,
    schemaChanged: statsInput.schemaChanged,
    runtimeContractChanged: statsInput.runtimeContractChanged,
    obsoleteHandlers: obsoleteHandlers,
    error: statsInput.error
  });
  statsInput.ok = violations.length === 0;
  statsInput.reason = violations.length ? 'm3_e2e_violation' : 'm3_e2e_ready';
  statsInput.violations = violations;
  return buildMigration3E2eResultFromStats_(statsInput);
}

function buildMigration3E2eViolations_(data) {
  data = data || {};
  var violations = [];
  if (!data.recoveryPresent) violations.push('m3_recovery_status_missing');
  if (data.recoveryPresent && !data.recoveryOk) violations.push('m3_recovery_not_ok');
  if (String(data.recoveryVersion || '') !== PHBOX_M3_E2E_REQUIRED_RECOVERY_VERSION_) violations.push('m3_recovery_version_mismatch');
  if (String(data.observabilityVersion || '') !== 'M3_OBSERVABILITY_v1') violations.push('m3_observability_version_mismatch');
  if (String(data.backendRouteVersion || '') !== 'M3_BACKEND_ROUTE_v1') violations.push('m3_backend_route_version_mismatch');
  if (String(data.frontRouteVersion || '') !== 'M3_FRONT_ROUTE_v1') violations.push('m3_front_route_version_mismatch');
  if (String(data.authVersion || '') !== 'M3_AUTH_v1') violations.push('m3_auth_version_mismatch');
  if (String(data.costGuardVersion || '') !== 'M3_COST_GUARD_v1') violations.push('m3_cost_guard_version_mismatch');
  if (String(data.configVersion || '') !== 'M3_TENANT_CONFIG_v1') violations.push('m3_tenant_config_version_mismatch');
  if (String(data.registryVersion || '') !== 'M3_TENANT_REGISTRY_v1') violations.push('m3_tenant_registry_version_mismatch');
  if (String(data.e2eVersion || '') !== PHBOX_M3_E2E_VERSION_) violations.push('e2e_version_mismatch');
  if (String(data.e2eOwner || '') !== PHBOX_M3_E2E_OWNER_) violations.push('e2e_owner_mismatch');
  if (String(data.runtimeOwner || '') !== PHBOX_M3_E2E_RUNTIME_OWNER_) violations.push('e2e_runtime_owner_mismatch');
  if (String(data.e2ePolicy || '') !== PHBOX_M3_E2E_POLICY_) violations.push('e2e_policy_mismatch');
  if (String(data.e2eMode || '') !== PHBOX_M3_E2E_MODE_) violations.push('e2e_mode_mismatch');
  if (String(data.m4ReadinessMode || '') !== PHBOX_M3_E2E_M4_READINESS_MODE_) violations.push('m4_readiness_mode_mismatch');
  if (!data.e2eContractDeclared) violations.push('e2e_contract_not_declared');
  PHBOX_M3_E2E_REQUIRED_STAGES_.forEach(function (name) {
    if (data.requiredStages.indexOf(name) === -1) violations.push('missing_required_stage_' + sanitizeMigration3E2eName_(name));
  });
  PHBOX_M3_E2E_REQUIRED_CHECKS_.forEach(function (name) {
    if (data.requiredChecks.indexOf(name) === -1) violations.push('missing_required_check_' + sanitizeMigration3E2eName_(name));
  });
  if (!data.m3ChainComplete) violations.push('m3_chain_not_complete');
  if (!data.m4ReadinessDeclared) violations.push('m4_readiness_not_declared');
  if (!data.m3FreezeAllowed) violations.push('m3_freeze_not_allowed');
  if (Number(data.firestoreReads || 0) > 0) violations.push('firestore_reads_detected');
  if (Number(data.firestoreWrites || 0) > 0) violations.push('firestore_writes_detected');
  if (Number(data.estimatedReadsPerHour || 0) > 0) violations.push('estimated_reads_per_hour_detected');
  if (Number(data.estimatedWritesPerHour || 0) > 0) violations.push('estimated_writes_per_hour_detected');
  if (Number(data.registryReads || 0) > 0) violations.push('registry_reads_detected');
  if (Number(data.registryWrites || 0) > 0) violations.push('registry_writes_detected');
  if (Number(data.configReads || 0) > 0) violations.push('config_reads_detected');
  if (Number(data.configWrites || 0) > 0) violations.push('config_writes_detected');
  if (Number(data.targetWritesExecuted || 0) > 0) violations.push('target_writes_executed_detected');
  if (Number(data.listeners || 0) > 0) violations.push('listeners_detected');
  if (Number(data.queries || 0) > 0) violations.push('queries_detected');
  if (Number(data.fanOut || 0) > 0) violations.push('fanout_detected');
  if (data.targetPathBuilt) violations.push('target_path_built_before_m4_plan');
  if (data.tenantTargetPathBuilt) violations.push('tenant_target_path_built_before_m4_plan');
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
  if (data.recoveryStateRead) violations.push('recovery_state_read_before_m4_materialize');
  if (data.recoveryStateWritten) violations.push('recovery_state_written_before_m4_materialize');
  if (data.recoveryCheckpointWritten) violations.push('recovery_checkpoint_written_before_m4_materialize');
  if (data.recoveryCursorAdvanced) violations.push('recovery_cursor_advanced_before_m4_materialize');
  if (data.recoveryResumeExecuted) violations.push('recovery_resume_executed_before_m4_materialize');
  if (data.partialWriteRecoveryExecuted) violations.push('partial_write_recovery_executed_before_m4_materialize');
  if (data.idempotentRetryExecuted) violations.push('idempotent_retry_executed_before_m4_materialize');
  if (data.e2eRuntimeExecuted) violations.push('e2e_runtime_executed_before_m3_freeze');
  if (data.e2eSideEffectsExecuted) violations.push('e2e_side_effects_executed_before_m3_freeze');
  if (data.m4MaterializeStarted) violations.push('m4_materialize_started_before_m3_freeze');
  if (data.schemaChanged) violations.push('schema_changed');
  if (data.runtimeContractChanged) violations.push('runtime_contract_changed');
  if ((data.obsoleteHandlers || []).length > 0) violations.push('obsolete_settings_handlers_detected');
  if (data.error) violations.push('m3_e2e_error');
  return violations;
}

function buildMigration3E2eResultFromStats_(stats) {
  stats = stats || {};
  stats.requiredStages = uniqueMigration3E2eStrings_(stats.requiredStages || []);
  stats.requiredChecks = uniqueMigration3E2eStrings_(stats.requiredChecks || []);
  stats.requiredStagesCount = stats.requiredStages.length;
  stats.requiredChecksCount = stats.requiredChecks.length;
  stats.violations = uniqueMigration3E2eStrings_(stats.violations || []);
  stats.obsoleteHandlers = uniqueMigration3E2eStrings_(stats.obsoleteHandlers || []);
  return {
    ok: !!stats.ok,
    skipped: !!stats.skipped,
    reason: String(stats.reason || ''),
    stats: stats
  };
}

function runMigration3E2eSelfTest_() {
  var items = [];
  function add(id, overrides, expectedOk, expectedViolations) {
    var result = buildMigration3E2eResult_(buildMigration3E2eSelfTestInput_(overrides));
    var passed = result.ok === expectedOk && migration3E2eHasExpectedViolations_(result.stats.violations, expectedViolations || []);
    items.push({ id: id, passed: passed, result: result });
  }
  add('clean_recovery_authorizes_e2e_contract', {}, true, []);
  add('missing_recovery_blocks_e2e', { recoveryStatusMissing: true }, false, ['m3_recovery_status_missing', 'm3_recovery_version_mismatch']);
  add('recovery_not_ok_blocks_e2e', { recoveryOk: false }, false, ['m3_recovery_not_ok']);
  add('recovery_version_mismatch_blocks_e2e', { recoveryVersion: 'M3_RECOVERY_v0' }, false, ['m3_recovery_version_mismatch']);
  add('m3_chain_version_mismatch_blocks_e2e', { authVersion: 'M3_AUTH_v0' }, false, ['m3_auth_version_mismatch']);
  add('e2e_version_mismatch_blocks_e2e', { e2eVersion: 'M3_E2E_v0' }, false, ['e2e_version_mismatch']);
  add('e2e_owner_mismatch_blocks_e2e', { owner: 'frontend_runtime' }, false, ['e2e_owner_mismatch']);
  add('e2e_policy_mismatch_blocks_e2e', { e2ePolicy: 'execute_runtime_e2e_now' }, false, ['e2e_policy_mismatch']);
  add('e2e_contract_not_declared_blocks_e2e', { e2eContractDeclared: false }, false, ['e2e_contract_not_declared']);
  add('missing_required_stage_blocks_e2e', { requiredStages: ['m3_recovery'] }, false, ['missing_required_stage_m3_lock']);
  add('missing_required_check_blocks_e2e', { requiredChecks: ['version_chain'] }, false, ['missing_required_check_zero_costs']);
  add('m3_chain_or_m4_readiness_missing_blocks_e2e', { m3ChainComplete: false, m4ReadinessDeclared: false, m3FreezeAllowed: false }, false, ['m3_chain_not_complete', 'm4_readiness_not_declared', 'm3_freeze_not_allowed']);
  add('firestore_read_or_write_blocks_e2e', { firestoreReads: 1, firestoreWrites: 1 }, false, ['firestore_reads_detected', 'firestore_writes_detected']);
  add('registry_or_config_read_write_blocks_e2e', { registryReads: 1, registryWrites: 1, configReads: 1, configWrites: 1 }, false, ['registry_reads_detected', 'registry_writes_detected', 'config_reads_detected', 'config_writes_detected']);
  add('listener_query_fanout_blocks_e2e', { listeners: 1, queries: 1, fanOut: 1 }, false, ['listeners_detected', 'queries_detected', 'fanout_detected']);
  add('target_or_tenant_path_blocks_e2e', { targetPathBuilt: true, tenantTargetPathBuilt: true }, false, ['target_path_built_before_m4_plan', 'tenant_target_path_built_before_m4_plan']);
  add('auth_or_front_route_runtime_blocks_e2e', { authRuntimeChanged: true, authTokenValidated: true, sessionCreated: true, frontRouteRuntimeChanged: true, routeResolved: true, navigationChanged: true }, false, ['auth_runtime_changed', 'auth_token_validated', 'session_created', 'front_route_runtime_changed', 'front_route_resolved', 'navigation_changed']);
  add('backend_runtime_blocks_e2e', { backendRouteRuntimeChanged: true, backendRouteResolved: true, backendDispatchExecuted: true, backendRunStarted: true, triggerInstalled: true }, false, ['backend_route_runtime_changed', 'backend_route_resolved', 'backend_dispatch_executed', 'backend_run_started', 'trigger_installed']);
  add('source_target_scan_blocks_e2e', { sourceScanExecuted: true, targetScanExecuted: true, sourceCountsCollected: true, targetCountsCollected: true, migrationSignatureComputed: true }, false, ['source_scan_executed_before_m4_plan', 'target_scan_executed_before_m4_plan', 'migration_signature_computed_before_m4_plan']);
  add('recovery_state_touch_blocks_e2e', { recoveryStateRead: true, recoveryStateWritten: true, recoveryCheckpointWritten: true, recoveryCursorAdvanced: true }, false, ['recovery_state_read_before_m4_materialize', 'recovery_state_written_before_m4_materialize', 'recovery_cursor_advanced_before_m4_materialize']);
  add('recovery_execution_blocks_e2e', { recoveryResumeExecuted: true, partialWriteRecoveryExecuted: true, idempotentRetryExecuted: true }, false, ['recovery_resume_executed_before_m4_materialize', 'partial_write_recovery_executed_before_m4_materialize', 'idempotent_retry_executed_before_m4_materialize']);
  add('e2e_runtime_or_m4_materialize_blocks_e2e', { e2eRuntimeExecuted: true, e2eSideEffectsExecuted: true, m4MaterializeStarted: true }, false, ['e2e_runtime_executed_before_m3_freeze', 'e2e_side_effects_executed_before_m3_freeze', 'm4_materialize_started_before_m3_freeze']);
  add('lifecycle_or_tenant_routing_blocks_e2e', { lifecycleTouched: true, tenantRoutingActive: true, tenantConfigTouched: true }, false, ['lifecycle_touched', 'tenant_routing_active', 'tenant_config_touched']);
  add('schema_or_runtime_contract_blocks_e2e', { schemaChanged: true, runtimeContractChanged: true }, false, ['schema_changed', 'runtime_contract_changed']);
  add('obsolete_settings_handler_blocks_e2e', { obsoleteHandlers: ['runMigration3RecoverySettingsTest'] }, false, ['obsolete_settings_handlers_detected']);
  add('runtime_error_blocks_e2e', { error: 'boom' }, false, ['m3_e2e_error']);
  var failed = items.filter(function (item) { return !item.passed; });
  var clean = buildMigration3E2eResult_(buildMigration3E2eSelfTestInput_({}));
  var stats = copyMigration3E2eStats_(clean.stats);
  stats.reason = failed.length ? 'm3_e2e_selftest_failed' : 'm3_e2e_selftest_passed';
  stats.ok = failed.length === 0;
  stats.testCount = items.length;
  stats.passedCount = items.length - failed.length;
  stats.failedCount = failed.length;
  return {
    ok: failed.length === 0,
    testCount: items.length,
    passedCount: items.length - failed.length,
    failedCount: failed.length,
    reason: stats.reason,
    stats: stats,
    items: items.map(function (item) {
      var itemStats = copyMigration3E2eStats_(item.result.stats || {});
      itemStats.id = item.id;
      itemStats.passed = item.passed;
      return itemStats;
    })
  };
}

function buildMigration3E2eSelfTestInput_(overrides) {
  overrides = overrides || {};
  var recoveryStats = {
    ok: overrides.recoveryOk === false ? false : true,
    recoveryVersion: overrides.recoveryVersion || PHBOX_M3_E2E_REQUIRED_RECOVERY_VERSION_,
    observabilityVersion: overrides.observabilityVersion || 'M3_OBSERVABILITY_v1',
    backendRouteVersion: overrides.backendRouteVersion || 'M3_BACKEND_ROUTE_v1',
    frontRouteVersion: overrides.frontRouteVersion || 'M3_FRONT_ROUTE_v1',
    authVersion: overrides.authVersion || 'M3_AUTH_v1',
    costGuardVersion: overrides.costGuardVersion || 'M3_COST_GUARD_v1',
    configVersion: overrides.configVersion || 'M3_TENANT_CONFIG_v1',
    registryVersion: overrides.registryVersion || 'M3_TENANT_REGISTRY_v1',
    firestoreReads: overrides.firestoreReads || 0,
    firestoreWrites: overrides.firestoreWrites || 0,
    estimatedReadsPerHour: overrides.estimatedReadsPerHour || 0,
    estimatedWritesPerHour: overrides.estimatedWritesPerHour || 0,
    registryReads: overrides.registryReads || 0,
    registryWrites: overrides.registryWrites || 0,
    configReads: overrides.configReads || 0,
    configWrites: overrides.configWrites || 0,
    targetWritesExecuted: overrides.targetWritesExecuted || 0,
    listeners: overrides.listeners || 0,
    queries: overrides.queries || 0,
    fanOut: overrides.fanOut || 0,
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
    sourceScanExecuted: !!overrides.sourceScanExecuted,
    targetScanExecuted: !!overrides.targetScanExecuted,
    sourceCountsCollected: !!overrides.sourceCountsCollected,
    targetCountsCollected: !!overrides.targetCountsCollected,
    migrationSignatureComputed: !!overrides.migrationSignatureComputed,
    blockingAnomaliesDetected: !!overrides.blockingAnomaliesDetected,
    recoveryStateRead: !!overrides.recoveryStateRead,
    recoveryStateWritten: !!overrides.recoveryStateWritten,
    recoveryCheckpointWritten: !!overrides.recoveryCheckpointWritten,
    recoveryCursorAdvanced: !!overrides.recoveryCursorAdvanced,
    recoveryResumeExecuted: !!overrides.recoveryResumeExecuted,
    partialWriteRecoveryExecuted: !!overrides.partialWriteRecoveryExecuted,
    idempotentRetryExecuted: !!overrides.idempotentRetryExecuted,
    schemaChanged: !!overrides.schemaChanged,
    runtimeContractChanged: !!overrides.runtimeContractChanged,
    obsoleteHandlers: overrides.obsoleteHandlers || []
  };
  var recoveryStatus = overrides.recoveryStatusMissing ? null : { ok: recoveryStats.ok, stats: recoveryStats };
  var contract = buildMigration3E2eContract_();
  Object.keys(overrides).forEach(function (key) {
    if (contract.hasOwnProperty(key)) contract[key] = overrides[key];
  });
  return {
    recoveryStatus: recoveryStatus,
    contract: contract,
    obsoleteHandlers: overrides.obsoleteHandlers || [],
    firestoreReads: overrides.firestoreReads || 0,
    firestoreWrites: overrides.firestoreWrites || 0,
    registryReads: overrides.registryReads || 0,
    registryWrites: overrides.registryWrites || 0,
    configReads: overrides.configReads || 0,
    configWrites: overrides.configWrites || 0,
    listeners: overrides.listeners || 0,
    queries: overrides.queries || 0,
    fanOut: overrides.fanOut || 0,
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
    sourceScanExecuted: !!overrides.sourceScanExecuted,
    targetScanExecuted: !!overrides.targetScanExecuted,
    sourceCountsCollected: !!overrides.sourceCountsCollected,
    targetCountsCollected: !!overrides.targetCountsCollected,
    migrationSignatureComputed: !!overrides.migrationSignatureComputed,
    blockingAnomaliesDetected: !!overrides.blockingAnomaliesDetected,
    recoveryStateRead: !!overrides.recoveryStateRead,
    recoveryStateWritten: !!overrides.recoveryStateWritten,
    recoveryCheckpointWritten: !!overrides.recoveryCheckpointWritten,
    recoveryCursorAdvanced: !!overrides.recoveryCursorAdvanced,
    recoveryResumeExecuted: !!overrides.recoveryResumeExecuted,
    partialWriteRecoveryExecuted: !!overrides.partialWriteRecoveryExecuted,
    idempotentRetryExecuted: !!overrides.idempotentRetryExecuted,
    e2eRuntimeExecuted: !!overrides.e2eRuntimeExecuted,
    e2eSideEffectsExecuted: !!overrides.e2eSideEffectsExecuted,
    m4MaterializeStarted: !!overrides.m4MaterializeStarted,
    schemaChanged: !!overrides.schemaChanged,
    runtimeContractChanged: !!overrides.runtimeContractChanged,
    error: overrides.error || ''
  };
}

function migration3E2eHasExpectedViolations_(actual, expected) {
  actual = actual || [];
  expected = expected || [];
  for (var i = 0; i < expected.length; i++) {
    if (actual.indexOf(expected[i]) === -1) return false;
  }
  return expected.length > 0 || actual.length === 0;
}

function formatMigration3E2eRuntimeFeedback_(result) {
  return formatMigration3E2eStats_('MIGRATION_3_E2E_RUNTIME_STATUS', result && result.stats || {});
}

function formatMigration3E2eSelfTestFeedback_(result) {
  var lines = [];
  lines.push('MIGRATION_3_E2E_TEST');
  lines.push('ok=' + String(!!(result && result.ok)));
  lines.push('testCount=' + String(result && result.testCount || 0));
  lines.push('passedCount=' + String(result && result.passedCount || 0));
  lines.push('failedCount=' + String(result && result.failedCount || 0));
  lines.push(formatMigration3E2eStats_('', result && result.stats || {}));
  lines.push('items=');
  (result && result.items || []).forEach(function (item) {
    lines.push('- id=' + item.id);
    lines.push('  passed=' + String(!!item.passed));
    migration3E2eFeedbackFields_().forEach(function (key) {
      if (key === 'id' || key === 'passed') return;
      lines.push('  ' + key + '=' + formatMigration3E2eValue_(item[key]));
    });
  });
  return lines.join('\n');
}

function formatMigration3E2eStats_(header, stats) {
  stats = stats || {};
  var lines = [];
  if (header) lines.push(header);
  migration3E2eFeedbackFields_().forEach(function (key) {
    lines.push(key + '=' + formatMigration3E2eValue_(stats[key]));
  });
  return lines.join('\n');
}

function migration3E2eFeedbackFields_() {
  return [
    'ok', 'skipped', 'reason', 'e2eVersion', 'requiredRecoveryVersion', 'recoveryVersion',
    'observabilityVersion', 'backendRouteVersion', 'frontRouteVersion', 'authVersion',
    'costGuardVersion', 'configVersion', 'registryVersion', 'e2eOwner', 'runtimeOwner',
    'e2ePolicy', 'e2eMode', 'm4ReadinessMode', 'e2eContractDeclared', 'requiredStagesCount',
    'requiredChecksCount', 'requiredStages', 'requiredChecks', 'm3ChainComplete',
    'm4ReadinessDeclared', 'm3FreezeAllowed', 'firestoreReads', 'firestoreWrites',
    'estimatedReadsPerHour', 'estimatedWritesPerHour', 'registryReads', 'registryWrites',
    'configReads', 'configWrites', 'targetWritesExecuted', 'listeners', 'queries', 'fanOut',
    'targetPathBuilt', 'tenantTargetPathBuilt', 'tenantConfigTouched', 'lifecycleTouched',
    'authRuntimeChanged', 'authProviderTouched', 'authTokenValidated', 'sessionCreated',
    'tenantRoutingActive', 'frontRouteRuntimeChanged', 'routeResolved', 'navigationChanged',
    'backendRouteRuntimeChanged', 'backendRouteResolved', 'backendDispatchExecuted',
    'backendRunStarted', 'triggerInstalled', 'sourceScanExecuted', 'targetScanExecuted',
    'sourceCountsCollected', 'targetCountsCollected', 'migrationSignatureComputed',
    'blockingAnomaliesDetected', 'recoveryStateRead', 'recoveryStateWritten',
    'recoveryCheckpointWritten', 'recoveryCursorAdvanced', 'recoveryResumeExecuted',
    'partialWriteRecoveryExecuted', 'idempotentRetryExecuted', 'e2eRuntimeExecuted',
    'e2eSideEffectsExecuted', 'm4MaterializeStarted', 'schemaChanged', 'runtimeContractChanged',
    'obsoleteHandlers', 'violations', 'error', 'errorKind'
  ];
}

function listMigration3E2eObsoleteSettingsHandlers_() {
  return [];
}

function copyMigration3E2eStats_(stats) {
  var copy = {};
  Object.keys(stats || {}).forEach(function (key) {
    if (Array.isArray(stats[key])) {
      copy[key] = stats[key].slice();
    } else {
      copy[key] = stats[key];
    }
  });
  return copy;
}

function uniqueMigration3E2eStrings_(values) {
  var seen = {};
  var out = [];
  (values || []).forEach(function (value) {
    var normalized = String(value || '').trim();
    if (!normalized || seen[normalized]) return;
    seen[normalized] = true;
    out.push(normalized);
  });
  return out;
}

function sanitizeMigration3E2eName_(value) {
  return String(value || '').replace(/[^A-Za-z0-9]+/g, '_').replace(/^_+|_+$/g, '').toLowerCase();
}

function formatMigration3E2eValue_(value) {
  if (Array.isArray(value)) return value.length ? value.join(',') : 'none';
  if (typeof value === 'boolean') return String(value);
  if (typeof value === 'number') return String(value);
  if (value === null || typeof value === 'undefined' || value === '') return '';
  return String(value);
}

function normalizeMigration3E2eErrorMessage_(error) {
  if (!error) return '';
  return String(error && error.message ? error.message : error);
}

function classifyMigration3E2eErrorKind_(error) {
  var message = normalizeMigration3E2eErrorMessage_(error);
  if (!message) return '';
  if (message.indexOf('M3_E2E_RECOVERY_MISSING') !== -1) return 'missing_dependency';
  return 'runtime_error';
}
