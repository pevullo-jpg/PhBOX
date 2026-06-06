var PHBOX_M3_RECOVERY_VERSION_ = 'M3_RECOVERY_v1';
var PHBOX_M3_RECOVERY_STAGE_ = 'migration3_recovery';
var PHBOX_M3_RECOVERY_REQUIRED_OBSERVABILITY_VERSION_ = 'M3_OBSERVABILITY_v1';
var PHBOX_M3_RECOVERY_OWNER_ = 'backend_gas_recovery_contract_only';
var PHBOX_M3_RECOVERY_RUNTIME_OWNER_ = 'future_m4_recovery_controller';
var PHBOX_M3_RECOVERY_POLICY_ = 'no_recovery_write_before_m4_materialize';
var PHBOX_M3_RECOVERY_MODE_ = 'pre_materialize_recovery_contract';
var PHBOX_M3_RECOVERY_STATE_DOC_PATH_ = 'migrations/m4_materialize';
var PHBOX_M3_RECOVERY_CHECKPOINT_FIELDS_ = [
  'migrationId',
  'tenantId',
  'status',
  'phase',
  'lastCursor',
  'sourceSignature',
  'targetSignature',
  'plannedTargetWrites',
  'targetWritesExecuted',
  'maxWritesReached',
  'startedAt',
  'updatedAt',
  'completedAt',
  'errorKind',
  'errorMessage'
];
var PHBOX_M3_RECOVERY_STATUS_VALUES_ = [
  'planned',
  'running',
  'partial',
  'complete',
  'failed',
  'paused'
];
var PHBOX_M3_RECOVERY_SCENARIOS_ = [
  'resume_from_last_cursor',
  'retry_idempotent_write',
  'skip_already_verified_target_doc',
  'detect_partial_target_doc',
  'detect_signature_mismatch',
  'stop_on_blocking_anomaly',
  'stop_on_max_writes_reached',
  'recover_after_runtime_error'
];

function runMigration3RecoveryRuntimeStatus_() {
  try {
    if (typeof runMigration3ObservabilityRuntimeStatus_ !== 'function') {
      throw new Error('M3_RECOVERY_OBSERVABILITY_MISSING: funzione runMigration3ObservabilityRuntimeStatus_ non disponibile. Recovery non autorizzabile.');
    }
    return buildMigration3RecoveryResult_({
      observabilityStatus: runMigration3ObservabilityRuntimeStatus_(),
      contract: buildMigration3RecoveryContract_(),
      obsoleteHandlers: listMigration3RecoveryObsoleteSettingsHandlers_()
    });
  } catch (e) {
    return buildMigration3RecoveryResult_({
      observabilityStatus: null,
      contract: buildMigration3RecoveryContract_(),
      obsoleteHandlers: listMigration3RecoveryObsoleteSettingsHandlers_(),
      error: normalizeRuntimeErrorMessage_(e),
      errorKind: classifyRuntimeFailureKind_(e)
    });
  }
}

function buildMigration3RecoveryContract_() {
  return {
    recoveryVersion: PHBOX_M3_RECOVERY_VERSION_,
    owner: PHBOX_M3_RECOVERY_OWNER_,
    runtimeOwner: PHBOX_M3_RECOVERY_RUNTIME_OWNER_,
    recoveryPolicy: PHBOX_M3_RECOVERY_POLICY_,
    recoveryMode: PHBOX_M3_RECOVERY_MODE_,
    recoveryStateDocPath: PHBOX_M3_RECOVERY_STATE_DOC_PATH_,
    checkpointFields: PHBOX_M3_RECOVERY_CHECKPOINT_FIELDS_.slice(),
    statusValues: PHBOX_M3_RECOVERY_STATUS_VALUES_.slice(),
    recoveryScenarios: PHBOX_M3_RECOVERY_SCENARIOS_.slice(),
    recoveryContractDeclared: true,
    idempotencyRequired: true,
    cursorRequired: true,
    partialWriteRecoveryRequired: true,
    maxWritesGuardRequired: true,
    signatureCheckRequired: true,
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
    schemaChanged: false,
    runtimeContractChanged: false
  };
}

function buildMigration3RecoveryResult_(data) {
  data = data || {};
  var observabilityStatus = data.observabilityStatus || null;
  var obsStats = (observabilityStatus && observabilityStatus.stats) || {};
  var contract = data.contract || {};
  var obsoleteHandlers = uniqueNonEmptyStrings_([].concat(
    obsStats.obsoleteHandlers || [],
    data.obsoleteHandlers || []
  ));
  var statsInput = {
    ok: !!(observabilityStatus && observabilityStatus.ok) && obsStats.ok !== false,
    skipped: false,
    reason: '',
    observabilityVersion: String(obsStats.observabilityVersion || ''),
    backendRouteVersion: String(obsStats.backendRouteVersion || ''),
    frontRouteVersion: String(obsStats.frontRouteVersion || ''),
    authVersion: String(obsStats.authVersion || ''),
    costGuardVersion: String(obsStats.costGuardVersion || ''),
    configVersion: String(obsStats.configVersion || ''),
    registryVersion: String(obsStats.registryVersion || ''),
    recoveryVersion: String(contract.recoveryVersion || ''),
    recoveryOwner: String(contract.owner || ''),
    runtimeOwner: String(contract.runtimeOwner || ''),
    recoveryPolicy: String(contract.recoveryPolicy || ''),
    recoveryMode: String(contract.recoveryMode || ''),
    recoveryStateDocPath: String(contract.recoveryStateDocPath || ''),
    recoveryContractDeclared: !!contract.recoveryContractDeclared,
    checkpointFields: uniqueNonEmptyStrings_(contract.checkpointFields || []),
    statusValues: uniqueNonEmptyStrings_(contract.statusValues || []),
    recoveryScenarios: uniqueNonEmptyStrings_(contract.recoveryScenarios || []),
    idempotencyRequired: !!contract.idempotencyRequired,
    cursorRequired: !!contract.cursorRequired,
    partialWriteRecoveryRequired: !!contract.partialWriteRecoveryRequired,
    maxWritesGuardRequired: !!contract.maxWritesGuardRequired,
    signatureCheckRequired: !!contract.signatureCheckRequired,
    firestoreReads: Math.max(0, Number(obsStats.firestoreReads || 0) + Number(contract.firestoreReads || 0) + Number(data.firestoreReads || 0)),
    firestoreWrites: Math.max(0, Number(obsStats.firestoreWrites || 0) + Number(contract.firestoreWrites || 0) + Number(data.firestoreWrites || 0)),
    estimatedReadsPerHour: Math.max(0, Number(obsStats.estimatedReadsPerHour || 0) + Number(data.estimatedReadsPerHour || 0)),
    estimatedWritesPerHour: Math.max(0, Number(obsStats.estimatedWritesPerHour || 0) + Number(data.estimatedWritesPerHour || 0)),
    registryReads: Math.max(0, Number(obsStats.registryReads || 0) + Number(contract.registryReads || 0) + Number(data.registryReads || 0)),
    registryWrites: Math.max(0, Number(obsStats.registryWrites || 0) + Number(contract.registryWrites || 0) + Number(data.registryWrites || 0)),
    configReads: Math.max(0, Number(obsStats.configReads || 0) + Number(contract.configReads || 0) + Number(data.configReads || 0)),
    configWrites: Math.max(0, Number(obsStats.configWrites || 0) + Number(contract.configWrites || 0) + Number(data.configWrites || 0)),
    targetWritesExecuted: Math.max(0, Number(obsStats.targetWritesExecuted || 0) + Number(contract.targetWritesExecuted || 0) + Number(data.targetWritesExecuted || 0)),
    listeners: Math.max(0, Number(obsStats.listeners || 0) + Number(contract.listeners || 0) + Number(data.listeners || 0)),
    queries: Math.max(0, Number(obsStats.queries || 0) + Number(contract.queries || 0) + Number(data.queries || 0)),
    fanOut: Math.max(0, Number(obsStats.fanOut || 0) + Number(contract.fanOut || 0) + Number(data.fanOut || 0)),
    targetPathBuilt: !!obsStats.targetPathBuilt || !!contract.targetPathBuilt || !!data.targetPathBuilt,
    tenantTargetPathBuilt: !!obsStats.tenantTargetPathBuilt || !!contract.tenantTargetPathBuilt || !!data.tenantTargetPathBuilt,
    tenantConfigTouched: !!obsStats.tenantConfigTouched || !!contract.tenantConfigTouched || !!data.tenantConfigTouched,
    lifecycleTouched: !!obsStats.lifecycleTouched || !!contract.lifecycleTouched || !!data.lifecycleTouched,
    authRuntimeChanged: !!obsStats.authRuntimeChanged || !!contract.authRuntimeChanged || !!data.authRuntimeChanged,
    authProviderTouched: !!obsStats.authProviderTouched || !!contract.authProviderTouched || !!data.authProviderTouched,
    authTokenValidated: !!obsStats.authTokenValidated || !!contract.authTokenValidated || !!data.authTokenValidated,
    sessionCreated: !!obsStats.sessionCreated || !!contract.sessionCreated || !!data.sessionCreated,
    tenantRoutingActive: !!obsStats.tenantRoutingActive || !!contract.tenantRoutingActive || !!data.tenantRoutingActive,
    frontRouteRuntimeChanged: !!obsStats.frontRouteRuntimeChanged || !!contract.frontRouteRuntimeChanged || !!data.frontRouteRuntimeChanged,
    routeResolved: !!obsStats.routeResolved || !!contract.routeResolved || !!data.routeResolved,
    navigationChanged: !!obsStats.navigationChanged || !!contract.navigationChanged || !!data.navigationChanged,
    backendRouteRuntimeChanged: !!obsStats.backendRouteRuntimeChanged || !!contract.backendRouteRuntimeChanged || !!data.backendRouteRuntimeChanged,
    backendRouteResolved: !!obsStats.backendRouteResolved || !!contract.backendRouteResolved || !!data.backendRouteResolved,
    backendDispatchExecuted: !!obsStats.backendDispatchExecuted || !!contract.backendDispatchExecuted || !!data.backendDispatchExecuted,
    backendRunStarted: !!obsStats.backendRunStarted || !!contract.backendRunStarted || !!data.backendRunStarted,
    triggerInstalled: !!obsStats.triggerInstalled || !!contract.triggerInstalled || !!data.triggerInstalled,
    sourceScanExecuted: !!obsStats.sourceScanExecuted || !!contract.sourceScanExecuted || !!data.sourceScanExecuted,
    targetScanExecuted: !!obsStats.targetScanExecuted || !!contract.targetScanExecuted || !!data.targetScanExecuted,
    sourceCountsCollected: !!obsStats.sourceCountsCollected || !!contract.sourceCountsCollected || !!data.sourceCountsCollected,
    targetCountsCollected: !!obsStats.targetCountsCollected || !!contract.targetCountsCollected || !!data.targetCountsCollected,
    migrationSignatureComputed: !!obsStats.migrationSignatureComputed || !!contract.migrationSignatureComputed || !!data.migrationSignatureComputed,
    blockingAnomaliesDetected: !!obsStats.blockingAnomaliesDetected || !!contract.blockingAnomaliesDetected || !!data.blockingAnomaliesDetected,
    recoveryStateRead: !!contract.recoveryStateRead || !!data.recoveryStateRead,
    recoveryStateWritten: !!contract.recoveryStateWritten || !!data.recoveryStateWritten,
    recoveryCheckpointWritten: !!contract.recoveryCheckpointWritten || !!data.recoveryCheckpointWritten,
    recoveryCursorAdvanced: !!contract.recoveryCursorAdvanced || !!data.recoveryCursorAdvanced,
    recoveryResumeExecuted: !!contract.recoveryResumeExecuted || !!data.recoveryResumeExecuted,
    partialWriteRecoveryExecuted: !!contract.partialWriteRecoveryExecuted || !!data.partialWriteRecoveryExecuted,
    idempotentRetryExecuted: !!contract.idempotentRetryExecuted || !!data.idempotentRetryExecuted,
    schemaChanged: !!obsStats.schemaChanged || !!contract.schemaChanged || !!data.schemaChanged,
    runtimeContractChanged: !!obsStats.runtimeContractChanged || !!contract.runtimeContractChanged || !!data.runtimeContractChanged,
    obsoleteHandlers: obsoleteHandlers,
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };
  var violations = buildMigration3RecoveryViolations_({
    observabilityPresent: !!(observabilityStatus && observabilityStatus.stats),
    observabilityOk: statsInput.ok,
    observabilityVersion: statsInput.observabilityVersion,
    recoveryVersion: statsInput.recoveryVersion,
    recoveryOwner: statsInput.recoveryOwner,
    runtimeOwner: statsInput.runtimeOwner,
    recoveryPolicy: statsInput.recoveryPolicy,
    recoveryMode: statsInput.recoveryMode,
    recoveryStateDocPath: statsInput.recoveryStateDocPath,
    recoveryContractDeclared: statsInput.recoveryContractDeclared,
    checkpointFields: statsInput.checkpointFields,
    statusValues: statsInput.statusValues,
    recoveryScenarios: statsInput.recoveryScenarios,
    idempotencyRequired: statsInput.idempotencyRequired,
    cursorRequired: statsInput.cursorRequired,
    partialWriteRecoveryRequired: statsInput.partialWriteRecoveryRequired,
    maxWritesGuardRequired: statsInput.maxWritesGuardRequired,
    signatureCheckRequired: statsInput.signatureCheckRequired,
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
    schemaChanged: statsInput.schemaChanged,
    runtimeContractChanged: statsInput.runtimeContractChanged,
    obsoleteHandlers: obsoleteHandlers,
    error: statsInput.error
  });
  statsInput.ok = violations.length === 0;
  statsInput.reason = violations.length ? 'm3_recovery_violation' : 'm3_recovery_ready';
  statsInput.violations = violations;
  return buildMigration3RecoveryResultFromStats_(statsInput);
}

function buildMigration3RecoveryViolations_(data) {
  data = data || {};
  var violations = [];
  if (!data.observabilityPresent) violations.push('m3_observability_status_missing');
  if (data.observabilityPresent && !data.observabilityOk) violations.push('m3_observability_not_ok');
  if (String(data.observabilityVersion || '') !== PHBOX_M3_RECOVERY_REQUIRED_OBSERVABILITY_VERSION_) violations.push('m3_observability_version_mismatch');
  if (String(data.recoveryVersion || '') !== PHBOX_M3_RECOVERY_VERSION_) violations.push('recovery_version_mismatch');
  if (String(data.recoveryOwner || '') !== PHBOX_M3_RECOVERY_OWNER_) violations.push('recovery_owner_mismatch');
  if (String(data.runtimeOwner || '') !== PHBOX_M3_RECOVERY_RUNTIME_OWNER_) violations.push('recovery_runtime_owner_mismatch');
  if (String(data.recoveryPolicy || '') !== PHBOX_M3_RECOVERY_POLICY_) violations.push('recovery_policy_mismatch');
  if (String(data.recoveryMode || '') !== PHBOX_M3_RECOVERY_MODE_) violations.push('recovery_mode_mismatch');
  if (String(data.recoveryStateDocPath || '') !== PHBOX_M3_RECOVERY_STATE_DOC_PATH_) violations.push('recovery_state_doc_path_mismatch');
  if (!data.recoveryContractDeclared) violations.push('recovery_contract_not_declared');
  migration3RecoveryMissingItems_(PHBOX_M3_RECOVERY_CHECKPOINT_FIELDS_, data.checkpointFields || []).forEach(function (field) {
    violations.push('missing_checkpoint_field_' + field);
  });
  migration3RecoveryMissingItems_(PHBOX_M3_RECOVERY_STATUS_VALUES_, data.statusValues || []).forEach(function (status) {
    violations.push('missing_status_value_' + status);
  });
  migration3RecoveryMissingItems_(PHBOX_M3_RECOVERY_SCENARIOS_, data.recoveryScenarios || []).forEach(function (scenario) {
    violations.push('missing_recovery_scenario_' + scenario);
  });
  if (!data.idempotencyRequired) violations.push('idempotency_not_required');
  if (!data.cursorRequired) violations.push('cursor_not_required');
  if (!data.partialWriteRecoveryRequired) violations.push('partial_write_recovery_not_required');
  if (!data.maxWritesGuardRequired) violations.push('max_writes_guard_not_required');
  if (!data.signatureCheckRequired) violations.push('signature_check_not_required');
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
  if (data.schemaChanged) violations.push('schema_changed');
  if (data.runtimeContractChanged) violations.push('runtime_contract_changed');
  if (uniqueNonEmptyStrings_(data.obsoleteHandlers || []).length > 0) violations.push('obsolete_settings_handlers_detected');
  if (data.error) violations.push('m3_recovery_error');
  return uniqueNonEmptyStrings_(violations);
}

function migration3RecoveryMissingItems_(expected, actual) {
  expected = uniqueNonEmptyStrings_(expected || []);
  actual = uniqueNonEmptyStrings_(actual || []);
  return expected.filter(function (item) { return actual.indexOf(item) === -1; });
}

function buildMigration3RecoveryResultFromStats_(data) {
  data = data || {};
  var stats = buildMigration3RecoveryStats_(data);
  return {
    ok: data.ok !== false,
    stats: stats,
    violations: uniqueNonEmptyStrings_(data.violations || []),
    items: data.items || []
  };
}

function buildMigration3RecoveryStats_(data) {
  data = data || {};
  return {
    stage: PHBOX_M3_RECOVERY_STAGE_,
    ok: data.ok !== false,
    skipped: data.skipped !== false,
    reason: String(data.reason || ''),
    recoveryVersion: String(data.recoveryVersion || ''),
    requiredObservabilityVersion: PHBOX_M3_RECOVERY_REQUIRED_OBSERVABILITY_VERSION_,
    observabilityVersion: String(data.observabilityVersion || ''),
    backendRouteVersion: String(data.backendRouteVersion || ''),
    frontRouteVersion: String(data.frontRouteVersion || ''),
    authVersion: String(data.authVersion || ''),
    costGuardVersion: String(data.costGuardVersion || ''),
    configVersion: String(data.configVersion || ''),
    registryVersion: String(data.registryVersion || ''),
    recoveryOwner: String(data.recoveryOwner || ''),
    runtimeOwner: String(data.runtimeOwner || ''),
    recoveryPolicy: String(data.recoveryPolicy || ''),
    recoveryMode: String(data.recoveryMode || ''),
    recoveryStateDocPath: String(data.recoveryStateDocPath || ''),
    recoveryContractDeclared: !!data.recoveryContractDeclared,
    checkpointFields: uniqueNonEmptyStrings_(data.checkpointFields || []),
    statusValues: uniqueNonEmptyStrings_(data.statusValues || []),
    recoveryScenarios: uniqueNonEmptyStrings_(data.recoveryScenarios || []),
    checkpointFieldsCount: uniqueNonEmptyStrings_(data.checkpointFields || []).length,
    statusValuesCount: uniqueNonEmptyStrings_(data.statusValues || []).length,
    recoveryScenariosCount: uniqueNonEmptyStrings_(data.recoveryScenarios || []).length,
    idempotencyRequired: !!data.idempotencyRequired,
    cursorRequired: !!data.cursorRequired,
    partialWriteRecoveryRequired: !!data.partialWriteRecoveryRequired,
    maxWritesGuardRequired: !!data.maxWritesGuardRequired,
    signatureCheckRequired: !!data.signatureCheckRequired,
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
    recoveryStateRead: !!data.recoveryStateRead,
    recoveryStateWritten: !!data.recoveryStateWritten,
    recoveryCheckpointWritten: !!data.recoveryCheckpointWritten,
    recoveryCursorAdvanced: !!data.recoveryCursorAdvanced,
    recoveryResumeExecuted: !!data.recoveryResumeExecuted,
    partialWriteRecoveryExecuted: !!data.partialWriteRecoveryExecuted,
    idempotentRetryExecuted: !!data.idempotentRetryExecuted,
    schemaChanged: !!data.schemaChanged,
    runtimeContractChanged: !!data.runtimeContractChanged,
    obsoleteHandlers: uniqueNonEmptyStrings_(data.obsoleteHandlers || []),
    violations: uniqueNonEmptyStrings_(data.violations || []),
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };
}

function listMigration3RecoveryObsoleteSettingsHandlers_() {
  var obsolete = [
    'runMigration3ObservabilitySettingsTest',
    'getMigration3ObservabilitySettingsStatus'
  ].filter(function (name) {
    try {
      if (typeof globalThis !== 'undefined' && typeof globalThis[name] === 'function') return true;
      return typeof this !== 'undefined' && typeof this[name] === 'function';
    } catch (e) {
      return false;
    }
  });
  if (typeof listMigration3ObservabilityObsoleteSettingsHandlers_ === 'function') {
    obsolete = obsolete.concat(listMigration3ObservabilityObsoleteSettingsHandlers_());
  }
  return uniqueNonEmptyStrings_(obsolete);
}

function runMigration3RecoverySelfTest_() {
  var cleanContract = buildMigration3RecoveryContract_();
  var cases = [
    { id: 'clean_observability_authorizes_recovery_contract', result: buildMigration3RecoveryResult_({ observabilityStatus: buildMigration3RecoverySyntheticObservabilityStatus_({}), contract: cleanContract }), expected: { ok: true, violation: '' } },
    { id: 'missing_observability_blocks_recovery', result: buildMigration3RecoveryResult_({ observabilityStatus: null, contract: cleanContract }), expected: { ok: false, violation: 'm3_observability_status_missing' } },
    { id: 'observability_not_ok_blocks_recovery', result: buildMigration3RecoveryResult_({ observabilityStatus: buildMigration3RecoverySyntheticObservabilityStatus_({ ok: false }), contract: cleanContract }), expected: { ok: false, violation: 'm3_observability_not_ok' } },
    { id: 'observability_version_mismatch_blocks_recovery', result: buildMigration3RecoveryResult_({ observabilityStatus: buildMigration3RecoverySyntheticObservabilityStatus_({ observabilityVersion: 'M3_OBSERVABILITY_v0' }), contract: cleanContract }), expected: { ok: false, violation: 'm3_observability_version_mismatch' } },
    { id: 'recovery_version_mismatch_blocks_recovery', result: buildMigration3RecoveryResult_({ observabilityStatus: buildMigration3RecoverySyntheticObservabilityStatus_({}), contract: migration3RecoverySyntheticContract_({ recoveryVersion: 'M3_RECOVERY_v0' }) }), expected: { ok: false, violation: 'recovery_version_mismatch' } },
    { id: 'recovery_owner_mismatch_blocks_recovery', result: buildMigration3RecoveryResult_({ observabilityStatus: buildMigration3RecoverySyntheticObservabilityStatus_({}), contract: migration3RecoverySyntheticContract_({ owner: 'runtime_recovery_writer' }) }), expected: { ok: false, violation: 'recovery_owner_mismatch' } },
    { id: 'recovery_policy_mismatch_blocks_recovery', result: buildMigration3RecoveryResult_({ observabilityStatus: buildMigration3RecoverySyntheticObservabilityStatus_({}), contract: migration3RecoverySyntheticContract_({ recoveryPolicy: 'write_recovery_state_now' }) }), expected: { ok: false, violation: 'recovery_policy_mismatch' } },
    { id: 'recovery_contract_not_declared_blocks_recovery', result: buildMigration3RecoveryResult_({ observabilityStatus: buildMigration3RecoverySyntheticObservabilityStatus_({}), contract: migration3RecoverySyntheticContract_({ recoveryContractDeclared: false }) }), expected: { ok: false, violation: 'recovery_contract_not_declared' } },
    { id: 'missing_checkpoint_field_blocks_recovery', result: buildMigration3RecoveryResult_({ observabilityStatus: buildMigration3RecoverySyntheticObservabilityStatus_({}), contract: migration3RecoverySyntheticContract_({ checkpointFields: ['migrationId'] }) }), expected: { ok: false, violation: 'missing_checkpoint_field_tenantId' } },
    { id: 'missing_status_value_blocks_recovery', result: buildMigration3RecoveryResult_({ observabilityStatus: buildMigration3RecoverySyntheticObservabilityStatus_({}), contract: migration3RecoverySyntheticContract_({ statusValues: ['planned'] }) }), expected: { ok: false, violation: 'missing_status_value_running' } },
    { id: 'missing_recovery_scenario_blocks_recovery', result: buildMigration3RecoveryResult_({ observabilityStatus: buildMigration3RecoverySyntheticObservabilityStatus_({}), contract: migration3RecoverySyntheticContract_({ recoveryScenarios: ['resume_from_last_cursor'] }) }), expected: { ok: false, violation: 'missing_recovery_scenario_retry_idempotent_write' } },
    { id: 'required_guards_missing_blocks_recovery', result: buildMigration3RecoveryResult_({ observabilityStatus: buildMigration3RecoverySyntheticObservabilityStatus_({}), contract: migration3RecoverySyntheticContract_({ idempotencyRequired: false, cursorRequired: false, partialWriteRecoveryRequired: false, maxWritesGuardRequired: false, signatureCheckRequired: false }) }), expected: { ok: false, violation: 'idempotency_not_required' } },
    { id: 'firestore_read_or_write_blocks_recovery', result: buildMigration3RecoveryResult_({ observabilityStatus: buildMigration3RecoverySyntheticObservabilityStatus_({ firestoreReads: 1, firestoreWrites: 1 }), contract: cleanContract }), expected: { ok: false, violation: 'firestore_reads_detected' } },
    { id: 'registry_or_config_read_write_blocks_recovery', result: buildMigration3RecoveryResult_({ observabilityStatus: buildMigration3RecoverySyntheticObservabilityStatus_({ registryReads: 1, registryWrites: 1, configReads: 1, configWrites: 1 }), contract: cleanContract }), expected: { ok: false, violation: 'registry_reads_detected' } },
    { id: 'listener_query_fanout_blocks_recovery', result: buildMigration3RecoveryResult_({ observabilityStatus: buildMigration3RecoverySyntheticObservabilityStatus_({ listeners: 1, queries: 1, fanOut: 1 }), contract: cleanContract }), expected: { ok: false, violation: 'listeners_detected' } },
    { id: 'target_or_tenant_path_blocks_recovery', result: buildMigration3RecoveryResult_({ observabilityStatus: buildMigration3RecoverySyntheticObservabilityStatus_({ targetPathBuilt: true, tenantTargetPathBuilt: true }), contract: cleanContract }), expected: { ok: false, violation: 'target_path_built_before_m4_plan' } },
    { id: 'backend_runtime_blocks_recovery', result: buildMigration3RecoveryResult_({ observabilityStatus: buildMigration3RecoverySyntheticObservabilityStatus_({ backendRouteRuntimeChanged: true, backendRouteResolved: true, backendDispatchExecuted: true, backendRunStarted: true, triggerInstalled: true }), contract: cleanContract }), expected: { ok: false, violation: 'backend_route_runtime_changed' } },
    { id: 'source_target_scan_blocks_recovery', result: buildMigration3RecoveryResult_({ observabilityStatus: buildMigration3RecoverySyntheticObservabilityStatus_({ sourceScanExecuted: true, targetScanExecuted: true, sourceCountsCollected: true, targetCountsCollected: true, migrationSignatureComputed: true }), contract: cleanContract }), expected: { ok: false, violation: 'source_scan_executed_before_m4_plan' } },
    { id: 'recovery_state_touch_blocks_recovery', result: buildMigration3RecoveryResult_({ observabilityStatus: buildMigration3RecoverySyntheticObservabilityStatus_({}), contract: migration3RecoverySyntheticContract_({ recoveryStateRead: true, recoveryStateWritten: true, recoveryCheckpointWritten: true, recoveryCursorAdvanced: true }) }), expected: { ok: false, violation: 'recovery_state_read_before_m4_materialize' } },
    { id: 'recovery_execution_blocks_recovery', result: buildMigration3RecoveryResult_({ observabilityStatus: buildMigration3RecoverySyntheticObservabilityStatus_({}), contract: migration3RecoverySyntheticContract_({ recoveryResumeExecuted: true, partialWriteRecoveryExecuted: true, idempotentRetryExecuted: true }) }), expected: { ok: false, violation: 'recovery_resume_executed_before_m4_materialize' } },
    { id: 'lifecycle_or_route_blocks_recovery', result: buildMigration3RecoveryResult_({ observabilityStatus: buildMigration3RecoverySyntheticObservabilityStatus_({ lifecycleTouched: true, tenantRoutingActive: true }), contract: cleanContract }), expected: { ok: false, violation: 'lifecycle_touched' } },
    { id: 'schema_or_runtime_contract_blocks_recovery', result: buildMigration3RecoveryResult_({ observabilityStatus: buildMigration3RecoverySyntheticObservabilityStatus_({ schemaChanged: true, runtimeContractChanged: true }), contract: cleanContract }), expected: { ok: false, violation: 'schema_changed' } },
    { id: 'obsolete_settings_handler_blocks_recovery', result: buildMigration3RecoveryResult_({ observabilityStatus: buildMigration3RecoverySyntheticObservabilityStatus_({}), contract: cleanContract, obsoleteHandlers: ['runMigration3ObservabilitySettingsTest'] }), expected: { ok: false, violation: 'obsolete_settings_handlers_detected' } },
    { id: 'runtime_error_blocks_recovery', result: buildMigration3RecoveryResult_({ observabilityStatus: buildMigration3RecoverySyntheticObservabilityStatus_({}), contract: cleanContract, error: 'synthetic error', errorKind: 'synthetic' }), expected: { ok: false, violation: 'm3_recovery_error' } }
  ];

  var items = cases.map(function (entry) {
    var stats = entry.result.stats || {};
    var violations = uniqueNonEmptyStrings_(stats.violations || []);
    var passed = entry.expected.ok ? !!entry.result.ok : (!entry.result.ok && violations.indexOf(entry.expected.violation) !== -1);
    return {
      id: entry.id,
      passed: passed,
      ok: !!entry.result.ok,
      reason: String(stats.reason || ''),
      recoveryVersion: String(stats.recoveryVersion || ''),
      observabilityVersion: String(stats.observabilityVersion || ''),
      recoveryPolicy: String(stats.recoveryPolicy || ''),
      recoveryContractDeclared: !!stats.recoveryContractDeclared,
      checkpointFieldsCount: Number(stats.checkpointFieldsCount || 0),
      statusValuesCount: Number(stats.statusValuesCount || 0),
      recoveryScenariosCount: Number(stats.recoveryScenariosCount || 0),
      firestoreReads: Number(stats.firestoreReads || 0),
      firestoreWrites: Number(stats.firestoreWrites || 0),
      registryReads: Number(stats.registryReads || 0),
      registryWrites: Number(stats.registryWrites || 0),
      configReads: Number(stats.configReads || 0),
      configWrites: Number(stats.configWrites || 0),
      listeners: Number(stats.listeners || 0),
      queries: Number(stats.queries || 0),
      fanOut: Number(stats.fanOut || 0),
      recoveryStateRead: !!stats.recoveryStateRead,
      recoveryStateWritten: !!stats.recoveryStateWritten,
      recoveryCheckpointWritten: !!stats.recoveryCheckpointWritten,
      recoveryResumeExecuted: !!stats.recoveryResumeExecuted,
      partialWriteRecoveryExecuted: !!stats.partialWriteRecoveryExecuted,
      idempotentRetryExecuted: !!stats.idempotentRetryExecuted,
      violations: violations
    };
  });
  var failed = items.filter(function (item) { return !item.passed; });
  var aggregate = buildMigration3RecoveryResultFromStats_(Object.assign({}, buildMigration3RecoveryResult_({ observabilityStatus: buildMigration3RecoverySyntheticObservabilityStatus_({}), contract: cleanContract }).stats, {
    ok: failed.length === 0,
    reason: failed.length ? 'm3_recovery_selftest_failed' : 'm3_recovery_selftest_passed',
    violations: failed.map(function (item) { return item.id; }),
    items: items
  }));
  aggregate.testCount = items.length;
  aggregate.passedCount = items.length - failed.length;
  aggregate.failedCount = failed.length;
  aggregate.items = items;
  aggregate.ok = failed.length === 0;
  return aggregate;
}

function buildMigration3RecoverySyntheticObservabilityStatus_(overrides) {
  overrides = overrides || {};
  var stats = {
    ok: overrides.ok !== false,
    observabilityVersion: PHBOX_M3_RECOVERY_REQUIRED_OBSERVABILITY_VERSION_,
    backendRouteVersion: 'M3_BACKEND_ROUTE_v1',
    frontRouteVersion: 'M3_FRONT_ROUTE_v1',
    authVersion: 'M3_AUTH_v1',
    costGuardVersion: 'M3_COST_GUARD_v1',
    configVersion: 'M3_TENANT_CONFIG_v1',
    registryVersion: 'M3_TENANT_REGISTRY_v1',
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
    schemaChanged: false,
    runtimeContractChanged: false,
    obsoleteHandlers: []
  };
  Object.keys(overrides).forEach(function (key) { stats[key] = overrides[key]; });
  return {
    ok: stats.ok !== false,
    stats: stats,
    violations: uniqueNonEmptyStrings_(stats.violations || [])
  };
}

function migration3RecoverySyntheticContract_(overrides) {
  var contract = buildMigration3RecoveryContract_();
  overrides = overrides || {};
  Object.keys(overrides).forEach(function (key) { contract[key] = overrides[key]; });
  return contract;
}

function formatMigration3RecoveryRuntimeFeedback_(result) {
  return formatMigration3RecoveryFeedback_('MIGRATION_3_RECOVERY_RUNTIME_STATUS', result);
}

function formatMigration3RecoverySelfTestFeedback_(result) {
  return formatMigration3RecoveryFeedback_('MIGRATION_3_RECOVERY_TEST', result);
}

function formatMigration3RecoveryFeedback_(title, result) {
  result = result || {};
  var stats = result.stats || {};
  var lines = [];
  lines.push(title);
  if (title === 'MIGRATION_3_RECOVERY_TEST') {
    lines.push('ok=' + String(!!result.ok));
    lines.push('testCount=' + String(result.testCount || 0));
    lines.push('passedCount=' + String(result.passedCount || 0));
    lines.push('failedCount=' + String(result.failedCount || 0));
  }
  lines.push('ok=' + String(!!(result.ok && stats.ok !== false)));
  lines.push('skipped=' + String(!!stats.skipped));
  lines.push('reason=' + String(stats.reason || ''));
  lines.push('recoveryVersion=' + String(stats.recoveryVersion || ''));
  lines.push('requiredObservabilityVersion=' + String(stats.requiredObservabilityVersion || ''));
  lines.push('observabilityVersion=' + String(stats.observabilityVersion || ''));
  lines.push('backendRouteVersion=' + String(stats.backendRouteVersion || ''));
  lines.push('frontRouteVersion=' + String(stats.frontRouteVersion || ''));
  lines.push('authVersion=' + String(stats.authVersion || ''));
  lines.push('costGuardVersion=' + String(stats.costGuardVersion || ''));
  lines.push('configVersion=' + String(stats.configVersion || ''));
  lines.push('registryVersion=' + String(stats.registryVersion || ''));
  lines.push('recoveryOwner=' + String(stats.recoveryOwner || ''));
  lines.push('runtimeOwner=' + String(stats.runtimeOwner || ''));
  lines.push('recoveryPolicy=' + String(stats.recoveryPolicy || ''));
  lines.push('recoveryMode=' + String(stats.recoveryMode || ''));
  lines.push('recoveryStateDocPath=' + String(stats.recoveryStateDocPath || ''));
  lines.push('recoveryContractDeclared=' + String(!!stats.recoveryContractDeclared));
  lines.push('checkpointFieldsCount=' + String(stats.checkpointFieldsCount || 0));
  lines.push('statusValuesCount=' + String(stats.statusValuesCount || 0));
  lines.push('recoveryScenariosCount=' + String(stats.recoveryScenariosCount || 0));
  lines.push('checkpointFields=' + uniqueNonEmptyStrings_(stats.checkpointFields || []).join(','));
  lines.push('statusValues=' + uniqueNonEmptyStrings_(stats.statusValues || []).join(','));
  lines.push('recoveryScenarios=' + uniqueNonEmptyStrings_(stats.recoveryScenarios || []).join(','));
  lines.push('idempotencyRequired=' + String(!!stats.idempotencyRequired));
  lines.push('cursorRequired=' + String(!!stats.cursorRequired));
  lines.push('partialWriteRecoveryRequired=' + String(!!stats.partialWriteRecoveryRequired));
  lines.push('maxWritesGuardRequired=' + String(!!stats.maxWritesGuardRequired));
  lines.push('signatureCheckRequired=' + String(!!stats.signatureCheckRequired));
  ['firestoreReads','firestoreWrites','estimatedReadsPerHour','estimatedWritesPerHour','registryReads','registryWrites','configReads','configWrites','targetWritesExecuted','listeners','queries','fanOut'].forEach(function (field) {
    lines.push(field + '=' + String(Number(stats[field] || 0)));
  });
  ['targetPathBuilt','tenantTargetPathBuilt','tenantConfigTouched','lifecycleTouched','authRuntimeChanged','authProviderTouched','authTokenValidated','sessionCreated','tenantRoutingActive','frontRouteRuntimeChanged','routeResolved','navigationChanged','backendRouteRuntimeChanged','backendRouteResolved','backendDispatchExecuted','backendRunStarted','triggerInstalled','sourceScanExecuted','targetScanExecuted','sourceCountsCollected','targetCountsCollected','migrationSignatureComputed','blockingAnomaliesDetected','recoveryStateRead','recoveryStateWritten','recoveryCheckpointWritten','recoveryCursorAdvanced','recoveryResumeExecuted','partialWriteRecoveryExecuted','idempotentRetryExecuted','schemaChanged','runtimeContractChanged'].forEach(function (field) {
    lines.push(field + '=' + String(!!stats[field]));
  });
  lines.push('obsoleteHandlers=' + (uniqueNonEmptyStrings_(stats.obsoleteHandlers || []).join(',') || 'none'));
  lines.push('violations=' + (uniqueNonEmptyStrings_(stats.violations || []).join(',') || 'none'));
  lines.push('error=' + (String(stats.error || '') || 'none'));
  lines.push('errorKind=' + (String(stats.errorKind || '') || 'none'));
  if (result.items && result.items.length) {
    lines.push('items=');
    result.items.forEach(function (item) {
      lines.push('- id=' + item.id);
      lines.push('  passed=' + String(!!item.passed));
      lines.push('  ok=' + String(!!item.ok));
      lines.push('  reason=' + String(item.reason || ''));
      lines.push('  recoveryVersion=' + String(item.recoveryVersion || ''));
      lines.push('  observabilityVersion=' + String(item.observabilityVersion || ''));
      lines.push('  recoveryPolicy=' + String(item.recoveryPolicy || ''));
      lines.push('  recoveryContractDeclared=' + String(!!item.recoveryContractDeclared));
      lines.push('  checkpointFieldsCount=' + String(item.checkpointFieldsCount || 0));
      lines.push('  statusValuesCount=' + String(item.statusValuesCount || 0));
      lines.push('  recoveryScenariosCount=' + String(item.recoveryScenariosCount || 0));
      lines.push('  firestoreReads=' + String(item.firestoreReads || 0));
      lines.push('  firestoreWrites=' + String(item.firestoreWrites || 0));
      lines.push('  registryReads=' + String(item.registryReads || 0));
      lines.push('  registryWrites=' + String(item.registryWrites || 0));
      lines.push('  configReads=' + String(item.configReads || 0));
      lines.push('  configWrites=' + String(item.configWrites || 0));
      lines.push('  listeners=' + String(item.listeners || 0));
      lines.push('  queries=' + String(item.queries || 0));
      lines.push('  fanOut=' + String(item.fanOut || 0));
      lines.push('  recoveryStateRead=' + String(!!item.recoveryStateRead));
      lines.push('  recoveryStateWritten=' + String(!!item.recoveryStateWritten));
      lines.push('  recoveryCheckpointWritten=' + String(!!item.recoveryCheckpointWritten));
      lines.push('  recoveryResumeExecuted=' + String(!!item.recoveryResumeExecuted));
      lines.push('  partialWriteRecoveryExecuted=' + String(!!item.partialWriteRecoveryExecuted));
      lines.push('  idempotentRetryExecuted=' + String(!!item.idempotentRetryExecuted));
      lines.push('  violations=' + (uniqueNonEmptyStrings_(item.violations || []).join(',') || 'none'));
    });
  }
  return lines.join('\n');
}
