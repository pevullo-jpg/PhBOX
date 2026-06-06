var PHBOX_M3_FREEZE_VERSION_ = 'M3_FREEZE_v1';
var PHBOX_M3_FREEZE_STAGE_ = 'migration3_freeze';
var PHBOX_M3_FREEZE_REQUIRED_E2E_VERSION_ = 'M3_E2E_v1';
var PHBOX_M3_FREEZE_OWNER_ = 'backend_gas_freeze_contract_only';
var PHBOX_M3_FREEZE_RUNTIME_OWNER_ = 'future_m4_lock_gate';
var PHBOX_M3_FREEZE_POLICY_ = 'freeze_m3_without_starting_m4';
var PHBOX_M3_FREEZE_MODE_ = 'final_m3_contract_freeze';
var PHBOX_M3_FREEZE_M4_STATUS_ = 'm4_not_started';
var PHBOX_M3_FREEZE_FROZEN_ = true;
var PHBOX_M3_FREEZE_REQUIRED_STAGES_ = [
  'm3_lock',
  'm3_tenant_registry',
  'm3_tenant_config',
  'm3_cost_guard',
  'm3_auth',
  'm3_front_route',
  'm3_backend_route',
  'm3_observability',
  'm3_recovery',
  'm3_e2e'
];
var PHBOX_M3_FREEZE_REQUIRED_CHECKS_ = [
  'm3_e2e_ok',
  'm3_e2e_freeze_allowed',
  'zero_costs',
  'no_runtime_routing',
  'no_backend_dispatch',
  'no_recovery_execution',
  'no_source_scan',
  'no_target_scan',
  'no_m4_materialize',
  'no_schema_change',
  'no_obsolete_handlers',
  'm3_frozen'
];

function runMigration3FreezeRuntimeStatus_() {
  try {
    if (typeof runMigration3E2eRuntimeStatus_ !== 'function') {
      throw new Error('M3_FREEZE_E2E_MISSING: funzione runMigration3E2eRuntimeStatus_ non disponibile. Freeze non autorizzabile.');
    }
    return buildMigration3FreezeResult_({
      e2eStatus: runMigration3E2eRuntimeStatus_(),
      contract: buildMigration3FreezeContract_(),
      obsoleteHandlers: listMigration3FreezeObsoleteSettingsHandlers_()
    });
  } catch (e) {
    return buildMigration3FreezeResult_({
      e2eStatus: null,
      contract: buildMigration3FreezeContract_(),
      obsoleteHandlers: listMigration3FreezeObsoleteSettingsHandlers_(),
      error: normalizeMigration3FreezeErrorMessage_(e),
      errorKind: classifyMigration3FreezeErrorKind_(e)
    });
  }
}

function buildMigration3FreezeContract_() {
  return {
    freezeVersion: PHBOX_M3_FREEZE_VERSION_,
    owner: PHBOX_M3_FREEZE_OWNER_,
    runtimeOwner: PHBOX_M3_FREEZE_RUNTIME_OWNER_,
    freezePolicy: PHBOX_M3_FREEZE_POLICY_,
    freezeMode: PHBOX_M3_FREEZE_MODE_,
    m4Status: PHBOX_M3_FREEZE_M4_STATUS_,
    requiredStages: PHBOX_M3_FREEZE_REQUIRED_STAGES_.slice(),
    requiredChecks: PHBOX_M3_FREEZE_REQUIRED_CHECKS_.slice(),
    freezeContractDeclared: true,
    frozen: PHBOX_M3_FREEZE_FROZEN_,
    m3Closed: true,
    m4AllowedNext: true,
    m4MaterializeStarted: false,
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
    freezeRuntimeExecuted: false,
    freezeSideEffectsExecuted: false,
    schemaChanged: false,
    runtimeContractChanged: false
  };
}

function buildMigration3FreezeResult_(data) {
  data = data || {};
  var e2eStatus = data.e2eStatus || null;
  var e2eStats = (e2eStatus && e2eStatus.stats) || {};
  var contract = data.contract || {};
  var obsoleteHandlers = uniqueMigration3FreezeStrings_([].concat(
    e2eStats.obsoleteHandlers || [],
    data.obsoleteHandlers || []
  ));
  var statsInput = {
    ok: !!(e2eStatus && e2eStatus.ok) && e2eStats.ok !== false,
    skipped: false,
    reason: '',
    freezeVersion: String(contract.freezeVersion || ''),
    requiredE2eVersion: PHBOX_M3_FREEZE_REQUIRED_E2E_VERSION_,
    e2eVersion: String(e2eStats.e2eVersion || ''),
    recoveryVersion: String(e2eStats.recoveryVersion || ''),
    observabilityVersion: String(e2eStats.observabilityVersion || ''),
    backendRouteVersion: String(e2eStats.backendRouteVersion || ''),
    frontRouteVersion: String(e2eStats.frontRouteVersion || ''),
    authVersion: String(e2eStats.authVersion || ''),
    costGuardVersion: String(e2eStats.costGuardVersion || ''),
    configVersion: String(e2eStats.configVersion || ''),
    registryVersion: String(e2eStats.registryVersion || ''),
    freezeOwner: String(contract.owner || ''),
    runtimeOwner: String(contract.runtimeOwner || ''),
    freezePolicy: String(contract.freezePolicy || ''),
    freezeMode: String(contract.freezeMode || ''),
    m4Status: String(contract.m4Status || ''),
    freezeContractDeclared: !!contract.freezeContractDeclared,
    requiredStages: uniqueMigration3FreezeStrings_(contract.requiredStages || []),
    requiredChecks: uniqueMigration3FreezeStrings_(contract.requiredChecks || []),
    m3ChainComplete: !!e2eStats.m3ChainComplete,
    m4ReadinessDeclared: !!e2eStats.m4ReadinessDeclared,
    m3FreezeAllowed: !!e2eStats.m3FreezeAllowed,
    frozen: !!contract.frozen,
    m3Closed: !!contract.m3Closed,
    m4AllowedNext: !!contract.m4AllowedNext,
    firestoreReads: Math.max(0, Number(e2eStats.firestoreReads || 0) + Number(contract.firestoreReads || 0) + Number(data.firestoreReads || 0)),
    firestoreWrites: Math.max(0, Number(e2eStats.firestoreWrites || 0) + Number(contract.firestoreWrites || 0) + Number(data.firestoreWrites || 0)),
    estimatedReadsPerHour: Math.max(0, Number(e2eStats.estimatedReadsPerHour || 0) + Number(contract.estimatedReadsPerHour || 0) + Number(data.estimatedReadsPerHour || 0)),
    estimatedWritesPerHour: Math.max(0, Number(e2eStats.estimatedWritesPerHour || 0) + Number(contract.estimatedWritesPerHour || 0) + Number(data.estimatedWritesPerHour || 0)),
    registryReads: Math.max(0, Number(e2eStats.registryReads || 0) + Number(contract.registryReads || 0) + Number(data.registryReads || 0)),
    registryWrites: Math.max(0, Number(e2eStats.registryWrites || 0) + Number(contract.registryWrites || 0) + Number(data.registryWrites || 0)),
    configReads: Math.max(0, Number(e2eStats.configReads || 0) + Number(contract.configReads || 0) + Number(data.configReads || 0)),
    configWrites: Math.max(0, Number(e2eStats.configWrites || 0) + Number(contract.configWrites || 0) + Number(data.configWrites || 0)),
    targetWritesExecuted: Math.max(0, Number(e2eStats.targetWritesExecuted || 0) + Number(contract.targetWritesExecuted || 0) + Number(data.targetWritesExecuted || 0)),
    listeners: Math.max(0, Number(e2eStats.listeners || 0) + Number(contract.listeners || 0) + Number(data.listeners || 0)),
    queries: Math.max(0, Number(e2eStats.queries || 0) + Number(contract.queries || 0) + Number(data.queries || 0)),
    fanOut: Math.max(0, Number(e2eStats.fanOut || 0) + Number(contract.fanOut || 0) + Number(data.fanOut || 0)),
    targetPathBuilt: !!e2eStats.targetPathBuilt || !!contract.targetPathBuilt || !!data.targetPathBuilt,
    tenantTargetPathBuilt: !!e2eStats.tenantTargetPathBuilt || !!contract.tenantTargetPathBuilt || !!data.tenantTargetPathBuilt,
    tenantConfigTouched: !!e2eStats.tenantConfigTouched || !!contract.tenantConfigTouched || !!data.tenantConfigTouched,
    lifecycleTouched: !!e2eStats.lifecycleTouched || !!contract.lifecycleTouched || !!data.lifecycleTouched,
    authRuntimeChanged: !!e2eStats.authRuntimeChanged || !!contract.authRuntimeChanged || !!data.authRuntimeChanged,
    authProviderTouched: !!e2eStats.authProviderTouched || !!contract.authProviderTouched || !!data.authProviderTouched,
    authTokenValidated: !!e2eStats.authTokenValidated || !!contract.authTokenValidated || !!data.authTokenValidated,
    sessionCreated: !!e2eStats.sessionCreated || !!contract.sessionCreated || !!data.sessionCreated,
    tenantRoutingActive: !!e2eStats.tenantRoutingActive || !!contract.tenantRoutingActive || !!data.tenantRoutingActive,
    frontRouteRuntimeChanged: !!e2eStats.frontRouteRuntimeChanged || !!contract.frontRouteRuntimeChanged || !!data.frontRouteRuntimeChanged,
    routeResolved: !!e2eStats.routeResolved || !!contract.routeResolved || !!data.routeResolved,
    navigationChanged: !!e2eStats.navigationChanged || !!contract.navigationChanged || !!data.navigationChanged,
    backendRouteRuntimeChanged: !!e2eStats.backendRouteRuntimeChanged || !!contract.backendRouteRuntimeChanged || !!data.backendRouteRuntimeChanged,
    backendRouteResolved: !!e2eStats.backendRouteResolved || !!contract.backendRouteResolved || !!data.backendRouteResolved,
    backendDispatchExecuted: !!e2eStats.backendDispatchExecuted || !!contract.backendDispatchExecuted || !!data.backendDispatchExecuted,
    backendRunStarted: !!e2eStats.backendRunStarted || !!contract.backendRunStarted || !!data.backendRunStarted,
    triggerInstalled: !!e2eStats.triggerInstalled || !!contract.triggerInstalled || !!data.triggerInstalled,
    sourceScanExecuted: !!e2eStats.sourceScanExecuted || !!contract.sourceScanExecuted || !!data.sourceScanExecuted,
    targetScanExecuted: !!e2eStats.targetScanExecuted || !!contract.targetScanExecuted || !!data.targetScanExecuted,
    sourceCountsCollected: !!e2eStats.sourceCountsCollected || !!contract.sourceCountsCollected || !!data.sourceCountsCollected,
    targetCountsCollected: !!e2eStats.targetCountsCollected || !!contract.targetCountsCollected || !!data.targetCountsCollected,
    migrationSignatureComputed: !!e2eStats.migrationSignatureComputed || !!contract.migrationSignatureComputed || !!data.migrationSignatureComputed,
    blockingAnomaliesDetected: !!e2eStats.blockingAnomaliesDetected || !!contract.blockingAnomaliesDetected || !!data.blockingAnomaliesDetected,
    recoveryStateRead: !!e2eStats.recoveryStateRead || !!contract.recoveryStateRead || !!data.recoveryStateRead,
    recoveryStateWritten: !!e2eStats.recoveryStateWritten || !!contract.recoveryStateWritten || !!data.recoveryStateWritten,
    recoveryCheckpointWritten: !!e2eStats.recoveryCheckpointWritten || !!contract.recoveryCheckpointWritten || !!data.recoveryCheckpointWritten,
    recoveryCursorAdvanced: !!e2eStats.recoveryCursorAdvanced || !!contract.recoveryCursorAdvanced || !!data.recoveryCursorAdvanced,
    recoveryResumeExecuted: !!e2eStats.recoveryResumeExecuted || !!contract.recoveryResumeExecuted || !!data.recoveryResumeExecuted,
    partialWriteRecoveryExecuted: !!e2eStats.partialWriteRecoveryExecuted || !!contract.partialWriteRecoveryExecuted || !!data.partialWriteRecoveryExecuted,
    idempotentRetryExecuted: !!e2eStats.idempotentRetryExecuted || !!contract.idempotentRetryExecuted || !!data.idempotentRetryExecuted,
    e2eRuntimeExecuted: !!e2eStats.e2eRuntimeExecuted || !!contract.e2eRuntimeExecuted || !!data.e2eRuntimeExecuted,
    e2eSideEffectsExecuted: !!e2eStats.e2eSideEffectsExecuted || !!contract.e2eSideEffectsExecuted || !!data.e2eSideEffectsExecuted,
    freezeRuntimeExecuted: !!contract.freezeRuntimeExecuted || !!data.freezeRuntimeExecuted,
    freezeSideEffectsExecuted: !!contract.freezeSideEffectsExecuted || !!data.freezeSideEffectsExecuted,
    m4MaterializeStarted: !!e2eStats.m4MaterializeStarted || !!contract.m4MaterializeStarted || !!data.m4MaterializeStarted,
    schemaChanged: !!e2eStats.schemaChanged || !!contract.schemaChanged || !!data.schemaChanged,
    runtimeContractChanged: !!e2eStats.runtimeContractChanged || !!contract.runtimeContractChanged || !!data.runtimeContractChanged,
    obsoleteHandlers: obsoleteHandlers,
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };
  var violations = buildMigration3FreezeViolations_({
    e2ePresent: !!(e2eStatus && e2eStatus.stats),
    e2eOk: statsInput.ok,
    freezeVersion: statsInput.freezeVersion,
    e2eVersion: statsInput.e2eVersion,
    recoveryVersion: statsInput.recoveryVersion,
    observabilityVersion: statsInput.observabilityVersion,
    backendRouteVersion: statsInput.backendRouteVersion,
    frontRouteVersion: statsInput.frontRouteVersion,
    authVersion: statsInput.authVersion,
    costGuardVersion: statsInput.costGuardVersion,
    configVersion: statsInput.configVersion,
    registryVersion: statsInput.registryVersion,
    freezeOwner: statsInput.freezeOwner,
    runtimeOwner: statsInput.runtimeOwner,
    freezePolicy: statsInput.freezePolicy,
    freezeMode: statsInput.freezeMode,
    m4Status: statsInput.m4Status,
    freezeContractDeclared: statsInput.freezeContractDeclared,
    requiredStages: statsInput.requiredStages,
    requiredChecks: statsInput.requiredChecks,
    m3ChainComplete: statsInput.m3ChainComplete,
    m4ReadinessDeclared: statsInput.m4ReadinessDeclared,
    m3FreezeAllowed: statsInput.m3FreezeAllowed,
    frozen: statsInput.frozen,
    m3Closed: statsInput.m3Closed,
    m4AllowedNext: statsInput.m4AllowedNext,
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
    freezeRuntimeExecuted: statsInput.freezeRuntimeExecuted,
    freezeSideEffectsExecuted: statsInput.freezeSideEffectsExecuted,
    m4MaterializeStarted: statsInput.m4MaterializeStarted,
    schemaChanged: statsInput.schemaChanged,
    runtimeContractChanged: statsInput.runtimeContractChanged,
    obsoleteHandlers: obsoleteHandlers,
    error: statsInput.error
  });
  statsInput.ok = violations.length === 0;
  statsInput.reason = violations.length ? 'm3_freeze_violation' : 'm3_freeze_ready';
  statsInput.frozen = violations.length === 0 && statsInput.frozen;
  statsInput.m3Closed = violations.length === 0 && statsInput.m3Closed;
  statsInput.m4AllowedNext = violations.length === 0 && statsInput.m4AllowedNext;
  statsInput.violations = violations;
  return buildMigration3FreezeResultFromStats_(statsInput);
}

function buildMigration3FreezeViolations_(data) {
  data = data || {};
  var violations = [];
  if (!data.e2ePresent) violations.push('m3_e2e_status_missing');
  if (data.e2ePresent && !data.e2eOk) violations.push('m3_e2e_not_ok');
  if (String(data.freezeVersion || '') !== PHBOX_M3_FREEZE_VERSION_) violations.push('freeze_version_mismatch');
  if (String(data.e2eVersion || '') !== PHBOX_M3_FREEZE_REQUIRED_E2E_VERSION_) violations.push('m3_e2e_version_mismatch');
  if (String(data.recoveryVersion || '') !== 'M3_RECOVERY_v1') violations.push('m3_recovery_version_mismatch');
  if (String(data.observabilityVersion || '') !== 'M3_OBSERVABILITY_v1') violations.push('m3_observability_version_mismatch');
  if (String(data.backendRouteVersion || '') !== 'M3_BACKEND_ROUTE_v1') violations.push('m3_backend_route_version_mismatch');
  if (String(data.frontRouteVersion || '') !== 'M3_FRONT_ROUTE_v1') violations.push('m3_front_route_version_mismatch');
  if (String(data.authVersion || '') !== 'M3_AUTH_v1') violations.push('m3_auth_version_mismatch');
  if (String(data.costGuardVersion || '') !== 'M3_COST_GUARD_v1') violations.push('m3_cost_guard_version_mismatch');
  if (String(data.configVersion || '') !== 'M3_TENANT_CONFIG_v1') violations.push('m3_tenant_config_version_mismatch');
  if (String(data.registryVersion || '') !== 'M3_TENANT_REGISTRY_v1') violations.push('m3_tenant_registry_version_mismatch');
  if (String(data.freezeOwner || '') !== PHBOX_M3_FREEZE_OWNER_) violations.push('freeze_owner_mismatch');
  if (String(data.runtimeOwner || '') !== PHBOX_M3_FREEZE_RUNTIME_OWNER_) violations.push('freeze_runtime_owner_mismatch');
  if (String(data.freezePolicy || '') !== PHBOX_M3_FREEZE_POLICY_) violations.push('freeze_policy_mismatch');
  if (String(data.freezeMode || '') !== PHBOX_M3_FREEZE_MODE_) violations.push('freeze_mode_mismatch');
  if (String(data.m4Status || '') !== PHBOX_M3_FREEZE_M4_STATUS_) violations.push('m4_status_mismatch');
  if (!data.freezeContractDeclared) violations.push('freeze_contract_not_declared');
  PHBOX_M3_FREEZE_REQUIRED_STAGES_.forEach(function (name) {
    if (data.requiredStages.indexOf(name) === -1) violations.push('missing_required_stage_' + sanitizeMigration3FreezeName_(name));
  });
  PHBOX_M3_FREEZE_REQUIRED_CHECKS_.forEach(function (name) {
    if (data.requiredChecks.indexOf(name) === -1) violations.push('missing_required_check_' + sanitizeMigration3FreezeName_(name));
  });
  if (!data.m3ChainComplete) violations.push('m3_chain_not_complete');
  if (!data.m4ReadinessDeclared) violations.push('m4_readiness_not_declared');
  if (!data.m3FreezeAllowed) violations.push('m3_e2e_freeze_not_allowed');
  if (!data.frozen) violations.push('m3_not_frozen');
  if (!data.m3Closed) violations.push('m3_not_closed');
  if (!data.m4AllowedNext) violations.push('m4_not_allowed_next');
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
  if (data.freezeRuntimeExecuted) violations.push('freeze_runtime_executed');
  if (data.freezeSideEffectsExecuted) violations.push('freeze_side_effects_executed');
  if (data.m4MaterializeStarted) violations.push('m4_materialize_started_before_m3_freeze');
  if (data.schemaChanged) violations.push('schema_changed');
  if (data.runtimeContractChanged) violations.push('runtime_contract_changed');
  if ((data.obsoleteHandlers || []).length > 0) violations.push('obsolete_settings_handlers_detected');
  if (data.error) violations.push('m3_freeze_error');
  return violations;
}

function buildMigration3FreezeResultFromStats_(stats) {
  stats = stats || {};
  return {
    ok: !!stats.ok,
    skipped: !!stats.skipped,
    reason: String(stats.reason || ''),
    stats: stats
  };
}

function runMigration3FreezeSelfTest_() {
  var cases = buildMigration3FreezeSelfTestCases_();
  var items = cases.map(function (item) {
    var result = buildMigration3FreezeResult_(item.input || {});
    var stats = result.stats || {};
    var expectedOk = !!item.expectedOk;
    var passed = result.ok === expectedOk;
    if (expectedOk && stats.frozen !== true) passed = false;
    if (!expectedOk && stats.frozen !== false) passed = false;
    if (!expectedOk && stats.m3Closed !== false) passed = false;
    if (!expectedOk && stats.m4AllowedNext !== false) passed = false;
    (item.expectedViolations || []).forEach(function (violation) {
      if ((stats.violations || []).indexOf(violation) === -1) passed = false;
    });
    return {
      id: item.id,
      passed: passed,
      result: result
    };
  });
  var failed = items.filter(function (item) { return !item.passed; });
  var clean = buildMigration3FreezeResult_({
    e2eStatus: buildMigration3FreezeCleanE2eStatus_(),
    contract: buildMigration3FreezeContract_(),
    obsoleteHandlers: []
  });
  return {
    ok: failed.length === 0 && !!clean.ok,
    testCount: items.length,
    passedCount: items.length - failed.length,
    failedCount: failed.length,
    result: clean,
    items: items,
    reason: failed.length ? 'm3_freeze_selftest_failed' : 'm3_freeze_selftest_passed'
  };
}

function buildMigration3FreezeSelfTestCases_() {
  return [
    { id: 'clean_e2e_authorizes_m3_freeze', expectedOk: true, input: { e2eStatus: buildMigration3FreezeCleanE2eStatus_(), contract: buildMigration3FreezeContract_(), obsoleteHandlers: [] } },
    { id: 'missing_e2e_blocks_freeze', expectedOk: false, expectedViolations: ['m3_e2e_status_missing'], input: { e2eStatus: null, contract: buildMigration3FreezeContract_(), obsoleteHandlers: [] } },
    { id: 'e2e_not_ok_blocks_freeze', expectedOk: false, expectedViolations: ['m3_e2e_not_ok'], input: { e2eStatus: buildMigration3FreezeCleanE2eStatus_({ ok: false }), contract: buildMigration3FreezeContract_(), obsoleteHandlers: [] } },
    { id: 'e2e_version_mismatch_blocks_freeze', expectedOk: false, expectedViolations: ['m3_e2e_version_mismatch'], input: { e2eStatus: buildMigration3FreezeCleanE2eStatus_({ e2eVersion: 'M3_E2E_v0' }), contract: buildMigration3FreezeContract_(), obsoleteHandlers: [] } },
    { id: 'm3_chain_version_mismatch_blocks_freeze', expectedOk: false, expectedViolations: ['m3_auth_version_mismatch'], input: { e2eStatus: buildMigration3FreezeCleanE2eStatus_({ authVersion: 'M3_AUTH_v0' }), contract: buildMigration3FreezeContract_(), obsoleteHandlers: [] } },
    { id: 'freeze_version_mismatch_blocks_freeze', expectedOk: false, expectedViolations: ['freeze_version_mismatch'], input: { e2eStatus: buildMigration3FreezeCleanE2eStatus_(), contract: buildMigration3FreezeContractOverride_({ freezeVersion: 'M3_FREEZE_v0' }), obsoleteHandlers: [] } },
    { id: 'freeze_owner_mismatch_blocks_freeze', expectedOk: false, expectedViolations: ['freeze_owner_mismatch'], input: { e2eStatus: buildMigration3FreezeCleanE2eStatus_(), contract: buildMigration3FreezeContractOverride_({ owner: 'frontend_runtime' }), obsoleteHandlers: [] } },
    { id: 'freeze_policy_mismatch_blocks_freeze', expectedOk: false, expectedViolations: ['freeze_policy_mismatch'], input: { e2eStatus: buildMigration3FreezeCleanE2eStatus_(), contract: buildMigration3FreezeContractOverride_({ freezePolicy: 'start_m4_now' }), obsoleteHandlers: [] } },
    { id: 'freeze_contract_not_declared_blocks_freeze', expectedOk: false, expectedViolations: ['freeze_contract_not_declared'], input: { e2eStatus: buildMigration3FreezeCleanE2eStatus_(), contract: buildMigration3FreezeContractOverride_({ freezeContractDeclared: false }), obsoleteHandlers: [] } },
    { id: 'missing_required_stage_blocks_freeze', expectedOk: false, expectedViolations: ['missing_required_stage_m3_lock'], input: { e2eStatus: buildMigration3FreezeCleanE2eStatus_(), contract: buildMigration3FreezeContractOverride_({ requiredStages: ['m3_e2e'] }), obsoleteHandlers: [] } },
    { id: 'missing_required_check_blocks_freeze', expectedOk: false, expectedViolations: ['missing_required_check_zero_costs'], input: { e2eStatus: buildMigration3FreezeCleanE2eStatus_(), contract: buildMigration3FreezeContractOverride_({ requiredChecks: ['m3_e2e_ok'] }), obsoleteHandlers: [] } },
    { id: 'e2e_flags_missing_blocks_freeze', expectedOk: false, expectedViolations: ['m3_chain_not_complete', 'm4_readiness_not_declared', 'm3_e2e_freeze_not_allowed'], input: { e2eStatus: buildMigration3FreezeCleanE2eStatus_({ m3ChainComplete: false, m4ReadinessDeclared: false, m3FreezeAllowed: false }), contract: buildMigration3FreezeContract_(), obsoleteHandlers: [] } },
    { id: 'freeze_flags_missing_blocks_freeze', expectedOk: false, expectedViolations: ['m3_not_frozen', 'm3_not_closed', 'm4_not_allowed_next'], input: { e2eStatus: buildMigration3FreezeCleanE2eStatus_(), contract: buildMigration3FreezeContractOverride_({ frozen: false, m3Closed: false, m4AllowedNext: false }), obsoleteHandlers: [] } },
    { id: 'firestore_read_or_write_blocks_freeze', expectedOk: false, expectedViolations: ['firestore_reads_detected', 'firestore_writes_detected'], input: { e2eStatus: buildMigration3FreezeCleanE2eStatus_({ firestoreReads: 2, firestoreWrites: 2 }), contract: buildMigration3FreezeContract_(), obsoleteHandlers: [] } },
    { id: 'registry_or_config_read_write_blocks_freeze', expectedOk: false, expectedViolations: ['registry_reads_detected', 'registry_writes_detected', 'config_reads_detected', 'config_writes_detected'], input: { e2eStatus: buildMigration3FreezeCleanE2eStatus_({ registryReads: 2, registryWrites: 2, configReads: 2, configWrites: 2 }), contract: buildMigration3FreezeContract_(), obsoleteHandlers: [] } },
    { id: 'listener_query_fanout_blocks_freeze', expectedOk: false, expectedViolations: ['listeners_detected', 'queries_detected', 'fanout_detected'], input: { e2eStatus: buildMigration3FreezeCleanE2eStatus_({ listeners: 2, queries: 2, fanOut: 2 }), contract: buildMigration3FreezeContract_(), obsoleteHandlers: [] } },
    { id: 'target_or_tenant_path_blocks_freeze', expectedOk: false, expectedViolations: ['target_path_built_before_m4_plan', 'tenant_target_path_built_before_m4_plan'], input: { e2eStatus: buildMigration3FreezeCleanE2eStatus_({ targetPathBuilt: true, tenantTargetPathBuilt: true }), contract: buildMigration3FreezeContract_(), obsoleteHandlers: [] } },
    { id: 'auth_or_front_route_runtime_blocks_freeze', expectedOk: false, expectedViolations: ['auth_runtime_changed', 'auth_token_validated', 'session_created', 'front_route_runtime_changed', 'front_route_resolved', 'navigation_changed'], input: { e2eStatus: buildMigration3FreezeCleanE2eStatus_({ authRuntimeChanged: true, authTokenValidated: true, sessionCreated: true, frontRouteRuntimeChanged: true, routeResolved: true, navigationChanged: true }), contract: buildMigration3FreezeContract_(), obsoleteHandlers: [] } },
    { id: 'backend_runtime_blocks_freeze', expectedOk: false, expectedViolations: ['backend_route_runtime_changed', 'backend_route_resolved', 'backend_dispatch_executed', 'backend_run_started', 'trigger_installed'], input: { e2eStatus: buildMigration3FreezeCleanE2eStatus_({ backendRouteRuntimeChanged: true, backendRouteResolved: true, backendDispatchExecuted: true, backendRunStarted: true, triggerInstalled: true }), contract: buildMigration3FreezeContract_(), obsoleteHandlers: [] } },
    { id: 'source_target_scan_blocks_freeze', expectedOk: false, expectedViolations: ['source_scan_executed_before_m4_plan', 'target_scan_executed_before_m4_plan', 'source_counts_collected_before_m4_plan', 'target_counts_collected_before_m4_plan', 'migration_signature_computed_before_m4_plan'], input: { e2eStatus: buildMigration3FreezeCleanE2eStatus_({ sourceScanExecuted: true, targetScanExecuted: true, sourceCountsCollected: true, targetCountsCollected: true, migrationSignatureComputed: true }), contract: buildMigration3FreezeContract_(), obsoleteHandlers: [] } },
    { id: 'recovery_state_touch_blocks_freeze', expectedOk: false, expectedViolations: ['recovery_state_read_before_m4_materialize', 'recovery_state_written_before_m4_materialize', 'recovery_checkpoint_written_before_m4_materialize', 'recovery_cursor_advanced_before_m4_materialize'], input: { e2eStatus: buildMigration3FreezeCleanE2eStatus_({ recoveryStateRead: true, recoveryStateWritten: true, recoveryCheckpointWritten: true, recoveryCursorAdvanced: true }), contract: buildMigration3FreezeContract_(), obsoleteHandlers: [] } },
    { id: 'recovery_execution_blocks_freeze', expectedOk: false, expectedViolations: ['recovery_resume_executed_before_m4_materialize', 'partial_write_recovery_executed_before_m4_materialize', 'idempotent_retry_executed_before_m4_materialize'], input: { e2eStatus: buildMigration3FreezeCleanE2eStatus_({ recoveryResumeExecuted: true, partialWriteRecoveryExecuted: true, idempotentRetryExecuted: true }), contract: buildMigration3FreezeContract_(), obsoleteHandlers: [] } },
    { id: 'e2e_or_freeze_runtime_blocks_freeze', expectedOk: false, expectedViolations: ['e2e_runtime_executed_before_m3_freeze', 'e2e_side_effects_executed_before_m3_freeze', 'freeze_runtime_executed', 'freeze_side_effects_executed'], input: { e2eStatus: buildMigration3FreezeCleanE2eStatus_({ e2eRuntimeExecuted: true, e2eSideEffectsExecuted: true }), contract: buildMigration3FreezeContractOverride_({ freezeRuntimeExecuted: true, freezeSideEffectsExecuted: true }), obsoleteHandlers: [] } },
    { id: 'm4_materialize_blocks_freeze', expectedOk: false, expectedViolations: ['m4_materialize_started_before_m3_freeze'], input: { e2eStatus: buildMigration3FreezeCleanE2eStatus_({ m4MaterializeStarted: true }), contract: buildMigration3FreezeContract_(), obsoleteHandlers: [] } },
    { id: 'schema_or_runtime_contract_blocks_freeze', expectedOk: false, expectedViolations: ['schema_changed', 'runtime_contract_changed'], input: { e2eStatus: buildMigration3FreezeCleanE2eStatus_({ schemaChanged: true, runtimeContractChanged: true }), contract: buildMigration3FreezeContract_(), obsoleteHandlers: [] } },
    { id: 'obsolete_settings_handler_blocks_freeze', expectedOk: false, expectedViolations: ['obsolete_settings_handlers_detected'], input: { e2eStatus: buildMigration3FreezeCleanE2eStatus_(), contract: buildMigration3FreezeContract_(), obsoleteHandlers: ['runMigration3E2eSettingsTest'] } },
    { id: 'runtime_error_blocks_freeze', expectedOk: false, expectedViolations: ['m3_freeze_error'], input: { e2eStatus: buildMigration3FreezeCleanE2eStatus_(), contract: buildMigration3FreezeContract_(), obsoleteHandlers: [], error: 'boom' } }
  ];
}

function buildMigration3FreezeCleanE2eStatus_(overrides) {
  overrides = overrides || {};
  var stats = {
    ok: true,
    skipped: false,
    reason: 'm3_e2e_ready',
    e2eVersion: 'M3_E2E_v1',
    recoveryVersion: 'M3_RECOVERY_v1',
    observabilityVersion: 'M3_OBSERVABILITY_v1',
    backendRouteVersion: 'M3_BACKEND_ROUTE_v1',
    frontRouteVersion: 'M3_FRONT_ROUTE_v1',
    authVersion: 'M3_AUTH_v1',
    costGuardVersion: 'M3_COST_GUARD_v1',
    configVersion: 'M3_TENANT_CONFIG_v1',
    registryVersion: 'M3_TENANT_REGISTRY_v1',
    m3ChainComplete: true,
    m4ReadinessDeclared: true,
    m3FreezeAllowed: true,
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
    runtimeContractChanged: false,
    obsoleteHandlers: [],
    violations: [],
    error: '',
    errorKind: ''
  };
  Object.keys(overrides || {}).forEach(function (key) {
    stats[key] = overrides[key];
  });
  return {
    ok: stats.ok !== false,
    skipped: false,
    reason: stats.reason,
    stats: stats
  };
}

function buildMigration3FreezeContractOverride_(overrides) {
  var contract = buildMigration3FreezeContract_();
  Object.keys(overrides || {}).forEach(function (key) {
    contract[key] = overrides[key];
  });
  return contract;
}

function formatMigration3FreezeRuntimeFeedback_(result) {
  var stats = (result && result.stats) || {};
  return formatMigration3FreezeStats_('MIGRATION_3_FREEZE_RUNTIME_STATUS', stats);
}

function formatMigration3FreezeSelfTestFeedback_(result) {
  result = result || {};
  var lines = [];
  lines.push('MIGRATION_3_FREEZE_TEST');
  lines.push('ok=' + String(!!result.ok));
  lines.push('testCount=' + String(result.testCount || 0));
  lines.push('passedCount=' + String(result.passedCount || 0));
  lines.push('failedCount=' + String(result.failedCount || 0));
  lines.push(formatMigration3FreezeRuntimeFeedback_(result.result || {}));
  lines.push('items=');
  (result.items || []).forEach(function (item) {
    lines.push('- id=' + item.id);
    lines.push('  passed=' + String(!!item.passed));
    formatMigration3FreezeStats_('', (item.result && item.result.stats) || {})
      .split('\n')
      .filter(function (line) { return !!line; })
      .forEach(function (line) { lines.push('  ' + line); });
  });
  return lines.join('\n');
}

function formatMigration3FreezeStats_(title, stats) {
  stats = stats || {};
  var lines = [];
  if (title) lines.push(title);
  lines.push('ok=' + String(!!stats.ok));
  lines.push('skipped=' + String(!!stats.skipped));
  lines.push('reason=' + String(stats.reason || ''));
  lines.push('freezeVersion=' + String(stats.freezeVersion || ''));
  lines.push('requiredE2eVersion=' + String(stats.requiredE2eVersion || ''));
  lines.push('e2eVersion=' + String(stats.e2eVersion || ''));
  lines.push('recoveryVersion=' + String(stats.recoveryVersion || ''));
  lines.push('observabilityVersion=' + String(stats.observabilityVersion || ''));
  lines.push('backendRouteVersion=' + String(stats.backendRouteVersion || ''));
  lines.push('frontRouteVersion=' + String(stats.frontRouteVersion || ''));
  lines.push('authVersion=' + String(stats.authVersion || ''));
  lines.push('costGuardVersion=' + String(stats.costGuardVersion || ''));
  lines.push('configVersion=' + String(stats.configVersion || ''));
  lines.push('registryVersion=' + String(stats.registryVersion || ''));
  lines.push('freezeOwner=' + String(stats.freezeOwner || ''));
  lines.push('runtimeOwner=' + String(stats.runtimeOwner || ''));
  lines.push('freezePolicy=' + String(stats.freezePolicy || ''));
  lines.push('freezeMode=' + String(stats.freezeMode || ''));
  lines.push('m4Status=' + String(stats.m4Status || ''));
  lines.push('freezeContractDeclared=' + String(!!stats.freezeContractDeclared));
  lines.push('requiredStagesCount=' + String((stats.requiredStages || []).length));
  lines.push('requiredChecksCount=' + String((stats.requiredChecks || []).length));
  lines.push('requiredStages=' + (stats.requiredStages || []).join(','));
  lines.push('requiredChecks=' + (stats.requiredChecks || []).join(','));
  lines.push('m3ChainComplete=' + String(!!stats.m3ChainComplete));
  lines.push('m4ReadinessDeclared=' + String(!!stats.m4ReadinessDeclared));
  lines.push('m3FreezeAllowed=' + String(!!stats.m3FreezeAllowed));
  lines.push('frozen=' + String(!!stats.frozen));
  lines.push('m3Closed=' + String(!!stats.m3Closed));
  lines.push('m4AllowedNext=' + String(!!stats.m4AllowedNext));
  lines.push('firestoreReads=' + String(Number(stats.firestoreReads || 0)));
  lines.push('firestoreWrites=' + String(Number(stats.firestoreWrites || 0)));
  lines.push('estimatedReadsPerHour=' + String(Number(stats.estimatedReadsPerHour || 0)));
  lines.push('estimatedWritesPerHour=' + String(Number(stats.estimatedWritesPerHour || 0)));
  lines.push('registryReads=' + String(Number(stats.registryReads || 0)));
  lines.push('registryWrites=' + String(Number(stats.registryWrites || 0)));
  lines.push('configReads=' + String(Number(stats.configReads || 0)));
  lines.push('configWrites=' + String(Number(stats.configWrites || 0)));
  lines.push('targetWritesExecuted=' + String(Number(stats.targetWritesExecuted || 0)));
  lines.push('listeners=' + String(Number(stats.listeners || 0)));
  lines.push('queries=' + String(Number(stats.queries || 0)));
  lines.push('fanOut=' + String(Number(stats.fanOut || 0)));
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
  lines.push('recoveryStateRead=' + String(!!stats.recoveryStateRead));
  lines.push('recoveryStateWritten=' + String(!!stats.recoveryStateWritten));
  lines.push('recoveryCheckpointWritten=' + String(!!stats.recoveryCheckpointWritten));
  lines.push('recoveryCursorAdvanced=' + String(!!stats.recoveryCursorAdvanced));
  lines.push('recoveryResumeExecuted=' + String(!!stats.recoveryResumeExecuted));
  lines.push('partialWriteRecoveryExecuted=' + String(!!stats.partialWriteRecoveryExecuted));
  lines.push('idempotentRetryExecuted=' + String(!!stats.idempotentRetryExecuted));
  lines.push('e2eRuntimeExecuted=' + String(!!stats.e2eRuntimeExecuted));
  lines.push('e2eSideEffectsExecuted=' + String(!!stats.e2eSideEffectsExecuted));
  lines.push('freezeRuntimeExecuted=' + String(!!stats.freezeRuntimeExecuted));
  lines.push('freezeSideEffectsExecuted=' + String(!!stats.freezeSideEffectsExecuted));
  lines.push('m4MaterializeStarted=' + String(!!stats.m4MaterializeStarted));
  lines.push('schemaChanged=' + String(!!stats.schemaChanged));
  lines.push('runtimeContractChanged=' + String(!!stats.runtimeContractChanged));
  lines.push('obsoleteHandlers=' + ((stats.obsoleteHandlers || []).length ? stats.obsoleteHandlers.join(',') : 'none'));
  lines.push('violations=' + ((stats.violations || []).length ? stats.violations.join(',') : 'none'));
  lines.push('error=' + String(stats.error || ''));
  lines.push('errorKind=' + String(stats.errorKind || ''));
  return lines.join('\n');
}

function listMigration3FreezeObsoleteSettingsHandlers_() {
  var obsolete = [
    'runMigration3E2eSettingsTest',
    'getMigration3E2eSettingsStatus',
    'runMigration3RecoverySettingsTest',
    'getMigration3RecoverySettingsStatus',
    'runMigration3ObservabilitySettingsTest',
    'getMigration3ObservabilitySettingsStatus',
    'runMigration3BackendRouteSettingsTest',
    'getMigration3BackendRouteSettingsStatus',
    'runMigration3FrontRouteSettingsTest',
    'getMigration3FrontRouteSettingsStatus',
    'runMigration3AuthSettingsTest',
    'getMigration3AuthSettingsStatus',
    'runMigration3CostGuardSettingsTest',
    'getMigration3CostGuardSettingsStatus',
    'runMigration3TenantConfigSettingsTest',
    'getMigration3TenantConfigSettingsStatus',
    'runMigration3TenantRegistrySettingsTest',
    'getMigration3TenantRegistrySettingsStatus',
    'runMigration3LockSettingsTest',
    'getMigration3LockSettingsStatus'
  ];
  return obsolete.filter(function (name) {
    return typeof this[name] === 'function';
  }, this);
}

function normalizeMigration3FreezeErrorMessage_(error) {
  if (!error) return '';
  return String(error && error.message ? error.message : error);
}

function classifyMigration3FreezeErrorKind_(error) {
  var message = normalizeMigration3FreezeErrorMessage_(error);
  if (!message) return '';
  if (message.indexOf('M3_FREEZE_E2E_MISSING') !== -1) return 'm3_e2e_missing';
  return 'm3_freeze_error';
}

function uniqueMigration3FreezeStrings_(items) {
  var seen = {};
  var out = [];
  (items || []).forEach(function (item) {
    var value = String(item || '').trim();
    if (!value || seen[value]) return;
    seen[value] = true;
    out.push(value);
  });
  return out;
}

function sanitizeMigration3FreezeName_(value) {
  return String(value || '').trim().toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
}
