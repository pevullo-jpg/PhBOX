var PHBOX_M4_LOCK_VERSION_ = 'M4_LOCK_v1';
var PHBOX_M4_LOCK_STAGE_ = 'migration4_lock';
var PHBOX_M4_LOCK_REQUIRED_FREEZE_VERSION_ = 'M3_FREEZE_v1';
var PHBOX_M4_LOCK_OWNER_ = 'backend_gas_m4_lock_contract_only';
var PHBOX_M4_LOCK_RUNTIME_OWNER_ = 'future_m4_plan_gate';
var PHBOX_M4_LOCK_POLICY_ = 'authorize_m4_plan_without_reading_or_writing_firestore';
var PHBOX_M4_LOCK_MODE_ = 'initial_m4_zero_cost_lock';
var PHBOX_M4_LOCK_NEXT_ALLOWED_STAGE_ = 'm4_plan';
var PHBOX_M4_LOCK_FORBIDDEN_STAGES_ = [
  'm4_dryrun',
  'm4_materialize',
  'm4_verify',
  'm4_cutover',
  'm4_freeze'
];

function runMigration4LockRuntimeStatus_() {
  try {
    if (typeof runMigration3FreezeRuntimeStatus_ !== 'function') {
      throw new Error('M4_LOCK_M3_FREEZE_MISSING: funzione runMigration3FreezeRuntimeStatus_ non disponibile. M4-LOCK non autorizzabile.');
    }
    return buildMigration4LockResult_({
      freezeStatus: runMigration3FreezeRuntimeStatus_(),
      contract: buildMigration4LockContract_(),
      obsoleteHandlers: listMigration4LockObsoleteSettingsHandlers_()
    });
  } catch (e) {
    return buildMigration4LockResult_({
      freezeStatus: null,
      contract: buildMigration4LockContract_(),
      obsoleteHandlers: listMigration4LockObsoleteSettingsHandlers_(),
      error: normalizeMigration4LockErrorMessage_(e),
      errorKind: classifyMigration4LockErrorKind_(e)
    });
  }
}

function buildMigration4LockContract_() {
  return {
    lockVersion: PHBOX_M4_LOCK_VERSION_,
    stage: PHBOX_M4_LOCK_STAGE_,
    requiredFreezeVersion: PHBOX_M4_LOCK_REQUIRED_FREEZE_VERSION_,
    owner: PHBOX_M4_LOCK_OWNER_,
    runtimeOwner: PHBOX_M4_LOCK_RUNTIME_OWNER_,
    lockPolicy: PHBOX_M4_LOCK_POLICY_,
    lockMode: PHBOX_M4_LOCK_MODE_,
    nextAllowedStage: PHBOX_M4_LOCK_NEXT_ALLOWED_STAGE_,
    forbiddenStages: PHBOX_M4_LOCK_FORBIDDEN_STAGES_.slice(),
    lockContractDeclared: true,
    m4Locked: true,
    m4Started: true,
    m4PlanAllowedNext: true,
    m4DryRunAllowedNext: false,
    m4MaterializeAllowedNext: false,
    m4VerifyAllowedNext: false,
    m4CutoverAllowedNext: false,
    m4FreezeAllowedNext: false,
    firestoreReads: 0,
    firestoreWrites: 0,
    estimatedReadsPerHour: 0,
    estimatedWritesPerHour: 0,
    registryReads: 0,
    registryWrites: 0,
    configReads: 0,
    configWrites: 0,
    sourceReads: 0,
    sourceWrites: 0,
    targetReads: 0,
    targetWrites: 0,
    targetWritesExecuted: 0,
    listeners: 0,
    queries: 0,
    fanOut: 0,
    targetPathBuilt: false,
    tenantTargetPathBuilt: false,
    tenantConfigTouched: false,
    lifecycleTouched: false,
    tenantRoutingActive: false,
    tenantScopedReads: false,
    tenantScopedWrites: false,
    legacyRuntimeDisabled: false,
    legacySourceFrozen: false,
    backendRunStarted: false,
    triggerInstalled: false,
    sourceScanExecuted: false,
    targetScanExecuted: false,
    sourceCountsCollected: false,
    targetCountsCollected: false,
    sourceSignatureComputed: false,
    targetSignatureComputed: false,
    migrationSignatureComputed: false,
    blockingAnomaliesDetected: false,
    migrationStateRead: false,
    migrationStateWritten: false,
    checkpointWritten: false,
    cursorAdvanced: false,
    materializeStarted: false,
    verifyStarted: false,
    cutoverStarted: false,
    schemaChanged: false,
    runtimeContractChanged: false,
    destructiveOperationExecuted: false,
    crossTenantLeakDetected: false
  };
}

function buildMigration4LockResult_(data) {
  data = data || {};
  var freezeStatus = data.freezeStatus || null;
  var freezeStats = (freezeStatus && freezeStatus.stats) || {};
  var contract = data.contract || {};
  var obsoleteHandlers = uniqueMigration4LockStrings_([].concat(
    freezeStats.obsoleteHandlers || [],
    data.obsoleteHandlers || []
  ));
  var statsInput = {
    ok: !!(freezeStatus && freezeStatus.ok) && freezeStats.ok !== false,
    skipped: false,
    reason: '',
    lockVersion: String(contract.lockVersion || ''),
    stage: String(contract.stage || ''),
    requiredFreezeVersion: PHBOX_M4_LOCK_REQUIRED_FREEZE_VERSION_,
    freezeVersion: String(freezeStats.freezeVersion || ''),
    e2eVersion: String(freezeStats.e2eVersion || ''),
    recoveryVersion: String(freezeStats.recoveryVersion || ''),
    observabilityVersion: String(freezeStats.observabilityVersion || ''),
    backendRouteVersion: String(freezeStats.backendRouteVersion || ''),
    frontRouteVersion: String(freezeStats.frontRouteVersion || ''),
    authVersion: String(freezeStats.authVersion || ''),
    costGuardVersion: String(freezeStats.costGuardVersion || ''),
    configVersion: String(freezeStats.configVersion || ''),
    registryVersion: String(freezeStats.registryVersion || ''),
    owner: String(contract.owner || ''),
    runtimeOwner: String(contract.runtimeOwner || ''),
    lockPolicy: String(contract.lockPolicy || ''),
    lockMode: String(contract.lockMode || ''),
    nextAllowedStage: String(contract.nextAllowedStage || ''),
    forbiddenStages: uniqueMigration4LockStrings_(contract.forbiddenStages || []),
    lockContractDeclared: !!contract.lockContractDeclared,
    m3Closed: !!freezeStats.m3Closed,
    m3Frozen: !!freezeStats.frozen,
    m4AllowedNextFromFreeze: !!freezeStats.m4AllowedNext,
    m4Locked: !!contract.m4Locked,
    m4Started: !!contract.m4Started,
    m4PlanAllowedNext: !!contract.m4PlanAllowedNext,
    m4DryRunAllowedNext: !!contract.m4DryRunAllowedNext,
    m4MaterializeAllowedNext: !!contract.m4MaterializeAllowedNext,
    m4VerifyAllowedNext: !!contract.m4VerifyAllowedNext,
    m4CutoverAllowedNext: !!contract.m4CutoverAllowedNext,
    m4FreezeAllowedNext: !!contract.m4FreezeAllowedNext,
    firestoreReads: Math.max(0, Number(freezeStats.firestoreReads || 0) + Number(contract.firestoreReads || 0) + Number(data.firestoreReads || 0)),
    firestoreWrites: Math.max(0, Number(freezeStats.firestoreWrites || 0) + Number(contract.firestoreWrites || 0) + Number(data.firestoreWrites || 0)),
    estimatedReadsPerHour: Math.max(0, Number(freezeStats.estimatedReadsPerHour || 0) + Number(contract.estimatedReadsPerHour || 0) + Number(data.estimatedReadsPerHour || 0)),
    estimatedWritesPerHour: Math.max(0, Number(freezeStats.estimatedWritesPerHour || 0) + Number(contract.estimatedWritesPerHour || 0) + Number(data.estimatedWritesPerHour || 0)),
    registryReads: Math.max(0, Number(freezeStats.registryReads || 0) + Number(contract.registryReads || 0) + Number(data.registryReads || 0)),
    registryWrites: Math.max(0, Number(freezeStats.registryWrites || 0) + Number(contract.registryWrites || 0) + Number(data.registryWrites || 0)),
    configReads: Math.max(0, Number(freezeStats.configReads || 0) + Number(contract.configReads || 0) + Number(data.configReads || 0)),
    configWrites: Math.max(0, Number(freezeStats.configWrites || 0) + Number(contract.configWrites || 0) + Number(data.configWrites || 0)),
    sourceReads: Math.max(0, Number(contract.sourceReads || 0) + Number(data.sourceReads || 0)),
    sourceWrites: Math.max(0, Number(contract.sourceWrites || 0) + Number(data.sourceWrites || 0)),
    targetReads: Math.max(0, Number(contract.targetReads || 0) + Number(data.targetReads || 0)),
    targetWrites: Math.max(0, Number(contract.targetWrites || 0) + Number(data.targetWrites || 0)),
    targetWritesExecuted: Math.max(0, Number(freezeStats.targetWritesExecuted || 0) + Number(contract.targetWritesExecuted || 0) + Number(data.targetWritesExecuted || 0)),
    listeners: Math.max(0, Number(freezeStats.listeners || 0) + Number(contract.listeners || 0) + Number(data.listeners || 0)),
    queries: Math.max(0, Number(freezeStats.queries || 0) + Number(contract.queries || 0) + Number(data.queries || 0)),
    fanOut: Math.max(0, Number(freezeStats.fanOut || 0) + Number(contract.fanOut || 0) + Number(data.fanOut || 0)),
    targetPathBuilt: !!freezeStats.targetPathBuilt || !!contract.targetPathBuilt || !!data.targetPathBuilt,
    tenantTargetPathBuilt: !!freezeStats.tenantTargetPathBuilt || !!contract.tenantTargetPathBuilt || !!data.tenantTargetPathBuilt,
    tenantConfigTouched: !!freezeStats.tenantConfigTouched || !!contract.tenantConfigTouched || !!data.tenantConfigTouched,
    lifecycleTouched: !!freezeStats.lifecycleTouched || !!contract.lifecycleTouched || !!data.lifecycleTouched,
    tenantRoutingActive: !!freezeStats.tenantRoutingActive || !!contract.tenantRoutingActive || !!data.tenantRoutingActive,
    tenantScopedReads: !!contract.tenantScopedReads || !!data.tenantScopedReads,
    tenantScopedWrites: !!contract.tenantScopedWrites || !!data.tenantScopedWrites,
    legacyRuntimeDisabled: !!contract.legacyRuntimeDisabled || !!data.legacyRuntimeDisabled,
    legacySourceFrozen: !!contract.legacySourceFrozen || !!data.legacySourceFrozen,
    backendRunStarted: !!freezeStats.backendRunStarted || !!contract.backendRunStarted || !!data.backendRunStarted,
    triggerInstalled: !!freezeStats.triggerInstalled || !!contract.triggerInstalled || !!data.triggerInstalled,
    sourceScanExecuted: !!freezeStats.sourceScanExecuted || !!contract.sourceScanExecuted || !!data.sourceScanExecuted,
    targetScanExecuted: !!freezeStats.targetScanExecuted || !!contract.targetScanExecuted || !!data.targetScanExecuted,
    sourceCountsCollected: !!freezeStats.sourceCountsCollected || !!contract.sourceCountsCollected || !!data.sourceCountsCollected,
    targetCountsCollected: !!freezeStats.targetCountsCollected || !!contract.targetCountsCollected || !!data.targetCountsCollected,
    sourceSignatureComputed: !!contract.sourceSignatureComputed || !!data.sourceSignatureComputed,
    targetSignatureComputed: !!contract.targetSignatureComputed || !!data.targetSignatureComputed,
    migrationSignatureComputed: !!freezeStats.migrationSignatureComputed || !!contract.migrationSignatureComputed || !!data.migrationSignatureComputed,
    blockingAnomaliesDetected: !!freezeStats.blockingAnomaliesDetected || !!contract.blockingAnomaliesDetected || !!data.blockingAnomaliesDetected,
    migrationStateRead: !!contract.migrationStateRead || !!data.migrationStateRead,
    migrationStateWritten: !!contract.migrationStateWritten || !!data.migrationStateWritten,
    checkpointWritten: !!contract.checkpointWritten || !!data.checkpointWritten,
    cursorAdvanced: !!contract.cursorAdvanced || !!data.cursorAdvanced,
    materializeStarted: !!contract.materializeStarted || !!data.materializeStarted,
    verifyStarted: !!contract.verifyStarted || !!data.verifyStarted,
    cutoverStarted: !!contract.cutoverStarted || !!data.cutoverStarted,
    schemaChanged: !!freezeStats.schemaChanged || !!contract.schemaChanged || !!data.schemaChanged,
    runtimeContractChanged: !!freezeStats.runtimeContractChanged || !!contract.runtimeContractChanged || !!data.runtimeContractChanged,
    destructiveOperationExecuted: !!contract.destructiveOperationExecuted || !!data.destructiveOperationExecuted,
    crossTenantLeakDetected: !!contract.crossTenantLeakDetected || !!data.crossTenantLeakDetected,
    obsoleteHandlers: obsoleteHandlers,
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };
  var violations = buildMigration4LockViolations_({
    freezePresent: !!(freezeStatus && freezeStatus.stats),
    freezeOk: statsInput.ok,
    lockVersion: statsInput.lockVersion,
    stage: statsInput.stage,
    freezeVersion: statsInput.freezeVersion,
    m3Closed: statsInput.m3Closed,
    m3Frozen: statsInput.m3Frozen,
    m4AllowedNextFromFreeze: statsInput.m4AllowedNextFromFreeze,
    lockContractDeclared: statsInput.lockContractDeclared,
    m4Locked: statsInput.m4Locked,
    m4Started: statsInput.m4Started,
    m4PlanAllowedNext: statsInput.m4PlanAllowedNext,
    m4DryRunAllowedNext: statsInput.m4DryRunAllowedNext,
    m4MaterializeAllowedNext: statsInput.m4MaterializeAllowedNext,
    m4VerifyAllowedNext: statsInput.m4VerifyAllowedNext,
    m4CutoverAllowedNext: statsInput.m4CutoverAllowedNext,
    m4FreezeAllowedNext: statsInput.m4FreezeAllowedNext,
    firestoreReads: statsInput.firestoreReads,
    firestoreWrites: statsInput.firestoreWrites,
    estimatedReadsPerHour: statsInput.estimatedReadsPerHour,
    estimatedWritesPerHour: statsInput.estimatedWritesPerHour,
    registryReads: statsInput.registryReads,
    registryWrites: statsInput.registryWrites,
    configReads: statsInput.configReads,
    configWrites: statsInput.configWrites,
    sourceReads: statsInput.sourceReads,
    sourceWrites: statsInput.sourceWrites,
    targetReads: statsInput.targetReads,
    targetWrites: statsInput.targetWrites,
    targetWritesExecuted: statsInput.targetWritesExecuted,
    listeners: statsInput.listeners,
    queries: statsInput.queries,
    fanOut: statsInput.fanOut,
    targetPathBuilt: statsInput.targetPathBuilt,
    tenantTargetPathBuilt: statsInput.tenantTargetPathBuilt,
    tenantConfigTouched: statsInput.tenantConfigTouched,
    lifecycleTouched: statsInput.lifecycleTouched,
    tenantRoutingActive: statsInput.tenantRoutingActive,
    tenantScopedReads: statsInput.tenantScopedReads,
    tenantScopedWrites: statsInput.tenantScopedWrites,
    legacyRuntimeDisabled: statsInput.legacyRuntimeDisabled,
    legacySourceFrozen: statsInput.legacySourceFrozen,
    backendRunStarted: statsInput.backendRunStarted,
    triggerInstalled: statsInput.triggerInstalled,
    sourceScanExecuted: statsInput.sourceScanExecuted,
    targetScanExecuted: statsInput.targetScanExecuted,
    sourceCountsCollected: statsInput.sourceCountsCollected,
    targetCountsCollected: statsInput.targetCountsCollected,
    sourceSignatureComputed: statsInput.sourceSignatureComputed,
    targetSignatureComputed: statsInput.targetSignatureComputed,
    migrationSignatureComputed: statsInput.migrationSignatureComputed,
    blockingAnomaliesDetected: statsInput.blockingAnomaliesDetected,
    migrationStateRead: statsInput.migrationStateRead,
    migrationStateWritten: statsInput.migrationStateWritten,
    checkpointWritten: statsInput.checkpointWritten,
    cursorAdvanced: statsInput.cursorAdvanced,
    materializeStarted: statsInput.materializeStarted,
    verifyStarted: statsInput.verifyStarted,
    cutoverStarted: statsInput.cutoverStarted,
    schemaChanged: statsInput.schemaChanged,
    runtimeContractChanged: statsInput.runtimeContractChanged,
    destructiveOperationExecuted: statsInput.destructiveOperationExecuted,
    crossTenantLeakDetected: statsInput.crossTenantLeakDetected,
    obsoleteHandlers: statsInput.obsoleteHandlers,
    error: statsInput.error,
    errorKind: statsInput.errorKind
  });
  statsInput.ok = violations.length === 0;
  statsInput.reason = statsInput.ok ? 'm4_lock_ready' : 'm4_lock_blocked';
  return {
    ok: statsInput.ok,
    skipped: false,
    reason: statsInput.reason,
    stage: PHBOX_M4_LOCK_STAGE_,
    stats: statsInput,
    violations: violations
  };
}

function buildMigration4LockViolations_(input) {
  input = input || {};
  var violations = [];
  if (!input.freezePresent) violations.push('m3_freeze_status_missing');
  if (!input.freezeOk) violations.push('m3_freeze_not_ok');
  if (input.lockVersion !== PHBOX_M4_LOCK_VERSION_) violations.push('lock_version_mismatch');
  if (input.stage !== PHBOX_M4_LOCK_STAGE_) violations.push('stage_mismatch');
  if (input.freezeVersion !== PHBOX_M4_LOCK_REQUIRED_FREEZE_VERSION_) violations.push('freeze_version_mismatch');
  if (!input.m3Closed) violations.push('m3_not_closed');
  if (!input.m3Frozen) violations.push('m3_not_frozen');
  if (!input.m4AllowedNextFromFreeze) violations.push('m4_not_allowed_by_m3_freeze');
  if (!input.lockContractDeclared) violations.push('lock_contract_not_declared');
  if (!input.m4Locked) violations.push('m4_not_locked');
  if (!input.m4Started) violations.push('m4_not_started');
  if (!input.m4PlanAllowedNext) violations.push('m4_plan_not_allowed');
  if (input.m4DryRunAllowedNext) violations.push('m4_dryrun_allowed_too_early');
  if (input.m4MaterializeAllowedNext) violations.push('m4_materialize_allowed_too_early');
  if (input.m4VerifyAllowedNext) violations.push('m4_verify_allowed_too_early');
  if (input.m4CutoverAllowedNext) violations.push('m4_cutover_allowed_too_early');
  if (input.m4FreezeAllowedNext) violations.push('m4_freeze_allowed_too_early');
  if (input.firestoreReads !== 0) violations.push('firestore_reads_not_zero');
  if (input.firestoreWrites !== 0) violations.push('firestore_writes_not_zero');
  if (input.estimatedReadsPerHour !== 0) violations.push('estimated_reads_not_zero');
  if (input.estimatedWritesPerHour !== 0) violations.push('estimated_writes_not_zero');
  if (input.registryReads !== 0) violations.push('registry_reads_not_zero');
  if (input.registryWrites !== 0) violations.push('registry_writes_not_zero');
  if (input.configReads !== 0) violations.push('config_reads_not_zero');
  if (input.configWrites !== 0) violations.push('config_writes_not_zero');
  if (input.sourceReads !== 0) violations.push('source_reads_not_zero');
  if (input.sourceWrites !== 0) violations.push('source_writes_not_zero');
  if (input.targetReads !== 0) violations.push('target_reads_not_zero');
  if (input.targetWrites !== 0) violations.push('target_writes_not_zero');
  if (input.targetWritesExecuted !== 0) violations.push('target_writes_executed_not_zero');
  if (input.listeners !== 0) violations.push('listeners_not_zero');
  if (input.queries !== 0) violations.push('queries_not_zero');
  if (input.fanOut !== 0) violations.push('fanout_not_zero');
  if (input.targetPathBuilt) violations.push('target_path_built_too_early');
  if (input.tenantTargetPathBuilt) violations.push('tenant_target_path_built_too_early');
  if (input.tenantConfigTouched) violations.push('tenant_config_touched_too_early');
  if (input.lifecycleTouched) violations.push('lifecycle_touched');
  if (input.tenantRoutingActive) violations.push('tenant_routing_active_too_early');
  if (input.tenantScopedReads) violations.push('tenant_scoped_reads_active_too_early');
  if (input.tenantScopedWrites) violations.push('tenant_scoped_writes_active_too_early');
  if (input.legacyRuntimeDisabled) violations.push('legacy_runtime_disabled_too_early');
  if (input.legacySourceFrozen) violations.push('legacy_source_frozen_too_early');
  if (input.backendRunStarted) violations.push('backend_run_started');
  if (input.triggerInstalled) violations.push('trigger_installed');
  if (input.sourceScanExecuted) violations.push('source_scan_executed');
  if (input.targetScanExecuted) violations.push('target_scan_executed');
  if (input.sourceCountsCollected) violations.push('source_counts_collected_too_early');
  if (input.targetCountsCollected) violations.push('target_counts_collected_too_early');
  if (input.sourceSignatureComputed) violations.push('source_signature_computed_too_early');
  if (input.targetSignatureComputed) violations.push('target_signature_computed_too_early');
  if (input.migrationSignatureComputed) violations.push('migration_signature_computed_too_early');
  if (input.blockingAnomaliesDetected) violations.push('blocking_anomalies_detected_too_early');
  if (input.migrationStateRead) violations.push('migration_state_read_too_early');
  if (input.migrationStateWritten) violations.push('migration_state_written_too_early');
  if (input.checkpointWritten) violations.push('checkpoint_written_too_early');
  if (input.cursorAdvanced) violations.push('cursor_advanced_too_early');
  if (input.materializeStarted) violations.push('materialize_started_too_early');
  if (input.verifyStarted) violations.push('verify_started_too_early');
  if (input.cutoverStarted) violations.push('cutover_started_too_early');
  if (input.schemaChanged) violations.push('schema_changed');
  if (input.runtimeContractChanged) violations.push('runtime_contract_changed');
  if (input.destructiveOperationExecuted) violations.push('destructive_operation_executed');
  if (input.crossTenantLeakDetected) violations.push('cross_tenant_leak_detected');
  if (input.obsoleteHandlers && input.obsoleteHandlers.length) violations.push('obsolete_settings_handlers_present:' + input.obsoleteHandlers.join(','));
  if (input.error) violations.push(String(input.errorKind || 'error') + ':' + String(input.error || ''));
  return uniqueMigration4LockStrings_(violations);
}

function runMigration4LockSelfTest_() {
  var cases = [
    {
      name: 'ready_from_m3_freeze',
      input: buildMigration4LockSelfTestInput_({ freezeStatus: buildMigration4LockFreezeStub_({ ok: true }) }),
      expectOk: true,
      expectedReason: 'm4_lock_ready'
    },
    {
      name: 'blocks_missing_freeze',
      input: buildMigration4LockSelfTestInput_({ freezeStatus: null }),
      expectOk: false,
      expectedViolation: 'm3_freeze_status_missing'
    },
    {
      name: 'blocks_failed_freeze',
      input: buildMigration4LockSelfTestInput_({ freezeStatus: buildMigration4LockFreezeStub_({ ok: false }) }),
      expectOk: false,
      expectedViolation: 'm3_freeze_not_ok'
    },
    {
      name: 'blocks_wrong_freeze_version',
      input: buildMigration4LockSelfTestInput_({ freezeStatus: buildMigration4LockFreezeStub_({ freezeVersion: 'M3_FREEZE_BAD' }) }),
      expectOk: false,
      expectedViolation: 'freeze_version_mismatch'
    },
    {
      name: 'blocks_not_closed_m3',
      input: buildMigration4LockSelfTestInput_({ freezeStatus: buildMigration4LockFreezeStub_({ m3Closed: false }) }),
      expectOk: false,
      expectedViolation: 'm3_not_closed'
    },
    {
      name: 'blocks_not_frozen_m3',
      input: buildMigration4LockSelfTestInput_({ freezeStatus: buildMigration4LockFreezeStub_({ frozen: false }) }),
      expectOk: false,
      expectedViolation: 'm3_not_frozen'
    },
    {
      name: 'blocks_m4_not_allowed_by_freeze',
      input: buildMigration4LockSelfTestInput_({ freezeStatus: buildMigration4LockFreezeStub_({ m4AllowedNext: false }) }),
      expectOk: false,
      expectedViolation: 'm4_not_allowed_by_m3_freeze'
    },
    {
      name: 'blocks_firestore_read',
      input: buildMigration4LockSelfTestInput_({ data: { firestoreReads: 1 } }),
      expectOk: false,
      expectedViolation: 'firestore_reads_not_zero'
    },
    {
      name: 'blocks_firestore_write',
      input: buildMigration4LockSelfTestInput_({ data: { firestoreWrites: 1 } }),
      expectOk: false,
      expectedViolation: 'firestore_writes_not_zero'
    },
    {
      name: 'blocks_source_read',
      input: buildMigration4LockSelfTestInput_({ data: { sourceReads: 1 } }),
      expectOk: false,
      expectedViolation: 'source_reads_not_zero'
    },
    {
      name: 'blocks_target_write',
      input: buildMigration4LockSelfTestInput_({ data: { targetWrites: 1 } }),
      expectOk: false,
      expectedViolation: 'target_writes_not_zero'
    },
    {
      name: 'blocks_target_path',
      input: buildMigration4LockSelfTestInput_({ data: { targetPathBuilt: true } }),
      expectOk: false,
      expectedViolation: 'target_path_built_too_early'
    },
    {
      name: 'blocks_source_scan',
      input: buildMigration4LockSelfTestInput_({ data: { sourceScanExecuted: true } }),
      expectOk: false,
      expectedViolation: 'source_scan_executed'
    },
    {
      name: 'blocks_target_scan',
      input: buildMigration4LockSelfTestInput_({ data: { targetScanExecuted: true } }),
      expectOk: false,
      expectedViolation: 'target_scan_executed'
    },
    {
      name: 'blocks_signature',
      input: buildMigration4LockSelfTestInput_({ data: { migrationSignatureComputed: true } }),
      expectOk: false,
      expectedViolation: 'migration_signature_computed_too_early'
    },
    {
      name: 'blocks_materialize',
      input: buildMigration4LockSelfTestInput_({ data: { materializeStarted: true } }),
      expectOk: false,
      expectedViolation: 'materialize_started_too_early'
    },
    {
      name: 'blocks_verify',
      input: buildMigration4LockSelfTestInput_({ data: { verifyStarted: true } }),
      expectOk: false,
      expectedViolation: 'verify_started_too_early'
    },
    {
      name: 'blocks_cutover',
      input: buildMigration4LockSelfTestInput_({ data: { cutoverStarted: true } }),
      expectOk: false,
      expectedViolation: 'cutover_started_too_early'
    },
    {
      name: 'blocks_dryrun_allowed',
      input: buildMigration4LockSelfTestInput_({ contract: { m4DryRunAllowedNext: true } }),
      expectOk: false,
      expectedViolation: 'm4_dryrun_allowed_too_early'
    },
    {
      name: 'blocks_materialize_allowed',
      input: buildMigration4LockSelfTestInput_({ contract: { m4MaterializeAllowedNext: true } }),
      expectOk: false,
      expectedViolation: 'm4_materialize_allowed_too_early'
    },
    {
      name: 'blocks_legacy_runtime_disable',
      input: buildMigration4LockSelfTestInput_({ data: { legacyRuntimeDisabled: true } }),
      expectOk: false,
      expectedViolation: 'legacy_runtime_disabled_too_early'
    },
    {
      name: 'blocks_cross_tenant_leak',
      input: buildMigration4LockSelfTestInput_({ data: { crossTenantLeakDetected: true } }),
      expectOk: false,
      expectedViolation: 'cross_tenant_leak_detected'
    }
  ];
  var results = cases.map(runMigration4LockSelfTestCase_);
  var failed = results.filter(function (item) { return !item.ok; });
  return {
    ok: failed.length === 0,
    lockVersion: PHBOX_M4_LOCK_VERSION_,
    stage: PHBOX_M4_LOCK_STAGE_,
    passedCount: results.length - failed.length,
    failedCount: failed.length,
    results: results
  };
}

function buildMigration4LockSelfTestInput_(overrides) {
  overrides = overrides || {};
  var contract = buildMigration4LockContract_();
  if (overrides.contract) {
    Object.keys(overrides.contract).forEach(function (key) {
      contract[key] = overrides.contract[key];
    });
  }
  var input = {
    freezeStatus: Object.prototype.hasOwnProperty.call(overrides, 'freezeStatus')
      ? overrides.freezeStatus
      : buildMigration4LockFreezeStub_({ ok: true }),
    contract: contract
  };
  Object.keys(overrides.data || {}).forEach(function (key) {
    input[key] = overrides.data[key];
  });
  return input;
}

function buildMigration4LockFreezeStub_(overrides) {
  overrides = overrides || {};
  var ok = Object.prototype.hasOwnProperty.call(overrides, 'ok') ? !!overrides.ok : true;
  return {
    ok: ok,
    stats: {
      ok: ok,
      freezeVersion: Object.prototype.hasOwnProperty.call(overrides, 'freezeVersion') ? overrides.freezeVersion : PHBOX_M4_LOCK_REQUIRED_FREEZE_VERSION_,
      e2eVersion: 'M3_E2E_v1',
      recoveryVersion: 'M3_RECOVERY_v1',
      observabilityVersion: 'M3_OBSERVABILITY_v1',
      backendRouteVersion: 'M3_BACKEND_ROUTE_v1',
      frontRouteVersion: 'M3_FRONT_ROUTE_v1',
      authVersion: 'M3_AUTH_v1',
      costGuardVersion: 'M3_COST_GUARD_v1',
      configVersion: 'M3_TENANT_CONFIG_v1',
      registryVersion: 'M3_TENANT_REGISTRY_v1',
      m3Closed: Object.prototype.hasOwnProperty.call(overrides, 'm3Closed') ? !!overrides.m3Closed : true,
      frozen: Object.prototype.hasOwnProperty.call(overrides, 'frozen') ? !!overrides.frozen : true,
      m4AllowedNext: Object.prototype.hasOwnProperty.call(overrides, 'm4AllowedNext') ? !!overrides.m4AllowedNext : true,
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
      tenantRoutingActive: false,
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
    }
  };
}

function runMigration4LockSelfTestCase_(testCase) {
  var result = buildMigration4LockResult_(testCase.input || {});
  var ok = result.ok === testCase.expectOk;
  if (testCase.expectedReason) ok = ok && result.reason === testCase.expectedReason;
  if (testCase.expectedViolation) {
    ok = ok && result.violations.indexOf(testCase.expectedViolation) !== -1;
  }
  return {
    name: testCase.name,
    ok: ok,
    expectedOk: testCase.expectOk,
    actualOk: result.ok,
    expectedReason: testCase.expectedReason || '',
    actualReason: result.reason || '',
    expectedViolation: testCase.expectedViolation || '',
    violations: result.violations || []
  };
}

function formatMigration4LockSelfTestFeedback_(result) {
  result = result || {};
  var lines = [];
  lines.push('MIGRATION_4_LOCK_SELF_TEST');
  lines.push('ok=' + String(!!result.ok));
  lines.push('lockVersion=' + String(result.lockVersion || ''));
  lines.push('stage=' + String(result.stage || ''));
  lines.push('passedCount=' + String(result.passedCount || 0));
  lines.push('failedCount=' + String(result.failedCount || 0));
  (result.results || []).forEach(function (item) {
    lines.push('- ' + String(item.name || '') + ': ' + (item.ok ? 'PASS' : 'FAIL'));
    if (!item.ok) {
      lines.push('  expectedOk=' + String(item.expectedOk));
      lines.push('  actualOk=' + String(item.actualOk));
      lines.push('  expectedViolation=' + String(item.expectedViolation || ''));
      lines.push('  violations=' + String((item.violations || []).join(',') || 'none'));
    }
  });
  return lines.join('\n');
}

function formatMigration4LockRuntimeFeedback_(result) {
  result = result || {};
  var stats = result.stats || {};
  var lines = [];
  lines.push('MIGRATION_4_LOCK_RUNTIME_STATUS');
  lines.push('ok=' + String(!!result.ok));
  lines.push('reason=' + String(result.reason || ''));
  lines.push('lockVersion=' + String(stats.lockVersion || ''));
  lines.push('stage=' + String(stats.stage || ''));
  lines.push('requiredFreezeVersion=' + String(stats.requiredFreezeVersion || ''));
  lines.push('freezeVersion=' + String(stats.freezeVersion || ''));
  lines.push('e2eVersion=' + String(stats.e2eVersion || ''));
  lines.push('recoveryVersion=' + String(stats.recoveryVersion || ''));
  lines.push('observabilityVersion=' + String(stats.observabilityVersion || ''));
  lines.push('backendRouteVersion=' + String(stats.backendRouteVersion || ''));
  lines.push('frontRouteVersion=' + String(stats.frontRouteVersion || ''));
  lines.push('authVersion=' + String(stats.authVersion || ''));
  lines.push('costGuardVersion=' + String(stats.costGuardVersion || ''));
  lines.push('configVersion=' + String(stats.configVersion || ''));
  lines.push('registryVersion=' + String(stats.registryVersion || ''));
  lines.push('owner=' + String(stats.owner || ''));
  lines.push('runtimeOwner=' + String(stats.runtimeOwner || ''));
  lines.push('lockPolicy=' + String(stats.lockPolicy || ''));
  lines.push('lockMode=' + String(stats.lockMode || ''));
  lines.push('nextAllowedStage=' + String(stats.nextAllowedStage || ''));
  lines.push('forbiddenStages=' + String((stats.forbiddenStages || []).join(',') || 'none'));
  lines.push('lockContractDeclared=' + String(!!stats.lockContractDeclared));
  lines.push('m3Closed=' + String(!!stats.m3Closed));
  lines.push('m3Frozen=' + String(!!stats.m3Frozen));
  lines.push('m4AllowedNextFromFreeze=' + String(!!stats.m4AllowedNextFromFreeze));
  lines.push('m4Locked=' + String(!!stats.m4Locked));
  lines.push('m4Started=' + String(!!stats.m4Started));
  lines.push('m4PlanAllowedNext=' + String(!!stats.m4PlanAllowedNext));
  lines.push('m4DryRunAllowedNext=' + String(!!stats.m4DryRunAllowedNext));
  lines.push('m4MaterializeAllowedNext=' + String(!!stats.m4MaterializeAllowedNext));
  lines.push('m4VerifyAllowedNext=' + String(!!stats.m4VerifyAllowedNext));
  lines.push('m4CutoverAllowedNext=' + String(!!stats.m4CutoverAllowedNext));
  lines.push('m4FreezeAllowedNext=' + String(!!stats.m4FreezeAllowedNext));
  lines.push('firestoreReads=' + String(stats.firestoreReads || 0));
  lines.push('firestoreWrites=' + String(stats.firestoreWrites || 0));
  lines.push('estimatedReadsPerHour=' + String(stats.estimatedReadsPerHour || 0));
  lines.push('estimatedWritesPerHour=' + String(stats.estimatedWritesPerHour || 0));
  lines.push('registryReads=' + String(stats.registryReads || 0));
  lines.push('registryWrites=' + String(stats.registryWrites || 0));
  lines.push('configReads=' + String(stats.configReads || 0));
  lines.push('configWrites=' + String(stats.configWrites || 0));
  lines.push('sourceReads=' + String(stats.sourceReads || 0));
  lines.push('sourceWrites=' + String(stats.sourceWrites || 0));
  lines.push('targetReads=' + String(stats.targetReads || 0));
  lines.push('targetWrites=' + String(stats.targetWrites || 0));
  lines.push('targetWritesExecuted=' + String(stats.targetWritesExecuted || 0));
  lines.push('listeners=' + String(stats.listeners || 0));
  lines.push('queries=' + String(stats.queries || 0));
  lines.push('fanOut=' + String(stats.fanOut || 0));
  lines.push('targetPathBuilt=' + String(!!stats.targetPathBuilt));
  lines.push('tenantTargetPathBuilt=' + String(!!stats.tenantTargetPathBuilt));
  lines.push('tenantConfigTouched=' + String(!!stats.tenantConfigTouched));
  lines.push('lifecycleTouched=' + String(!!stats.lifecycleTouched));
  lines.push('tenantRoutingActive=' + String(!!stats.tenantRoutingActive));
  lines.push('tenantScopedReads=' + String(!!stats.tenantScopedReads));
  lines.push('tenantScopedWrites=' + String(!!stats.tenantScopedWrites));
  lines.push('legacyRuntimeDisabled=' + String(!!stats.legacyRuntimeDisabled));
  lines.push('legacySourceFrozen=' + String(!!stats.legacySourceFrozen));
  lines.push('backendRunStarted=' + String(!!stats.backendRunStarted));
  lines.push('triggerInstalled=' + String(!!stats.triggerInstalled));
  lines.push('sourceScanExecuted=' + String(!!stats.sourceScanExecuted));
  lines.push('targetScanExecuted=' + String(!!stats.targetScanExecuted));
  lines.push('sourceCountsCollected=' + String(!!stats.sourceCountsCollected));
  lines.push('targetCountsCollected=' + String(!!stats.targetCountsCollected));
  lines.push('sourceSignatureComputed=' + String(!!stats.sourceSignatureComputed));
  lines.push('targetSignatureComputed=' + String(!!stats.targetSignatureComputed));
  lines.push('migrationSignatureComputed=' + String(!!stats.migrationSignatureComputed));
  lines.push('blockingAnomaliesDetected=' + String(!!stats.blockingAnomaliesDetected));
  lines.push('migrationStateRead=' + String(!!stats.migrationStateRead));
  lines.push('migrationStateWritten=' + String(!!stats.migrationStateWritten));
  lines.push('checkpointWritten=' + String(!!stats.checkpointWritten));
  lines.push('cursorAdvanced=' + String(!!stats.cursorAdvanced));
  lines.push('materializeStarted=' + String(!!stats.materializeStarted));
  lines.push('verifyStarted=' + String(!!stats.verifyStarted));
  lines.push('cutoverStarted=' + String(!!stats.cutoverStarted));
  lines.push('schemaChanged=' + String(!!stats.schemaChanged));
  lines.push('runtimeContractChanged=' + String(!!stats.runtimeContractChanged));
  lines.push('destructiveOperationExecuted=' + String(!!stats.destructiveOperationExecuted));
  lines.push('crossTenantLeakDetected=' + String(!!stats.crossTenantLeakDetected));
  lines.push('obsoleteHandlers=' + String((stats.obsoleteHandlers || []).join(',') || 'none'));
  lines.push('violations=' + String((result.violations || []).join(',') || 'none'));
  lines.push('error=' + String(stats.error || ''));
  lines.push('errorKind=' + String(stats.errorKind || ''));
  return lines.join('\n');
}

function listMigration4LockObsoleteSettingsHandlers_() {
  var candidates = [
    'runMigration3FreezeSettingsTest',
    'getMigration3FreezeSettingsStatus',
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
    'getMigration3LockSettingsStatus',
    'runMigration2FreezeSettingsTest',
    'getMigration2FreezeSettingsStatus',
    'runMigration2DocSettingsTest',
    'getMigration2DocSettingsStatus',
    'runMigration2FinalCleanSettingsTest',
    'getMigration2FinalCleanSettingsStatus',
    'runMigration2CostSettingsTest',
    'getMigration2CostSettingsStatus',
    'runMigration2E2eSettingsTest',
    'getMigration2E2eSettingsStatus',
    'runMigration2RollbackSettingsTest',
    'getMigration2RollbackSettingsStatus',
    'runMigration2CutonSettingsTest',
    'getMigration2CutonSettingsStatus',
    'runMigration2VerifySettingsTest',
    'getMigration2VerifySettingsStatus',
    'runMigration2DashSettingsTest',
    'getMigration2DashSettingsStatus',
    'runMigration2SignalSettingsTest',
    'getMigration2SignalSettingsStatus',
    'runMigration2WriteSettingsTest',
    'getMigration2WriteSettingsStatus',
    'runMigration2RouteSettingsTest',
    'getMigration2RouteSettingsStatus',
    'runMigration2LockSettingsTest',
    'getMigration2LockSettingsStatus',
    'runMigration1FreezeSettingsTest',
    'getMigration1FreezeSettingsStatus',
    'runMigration1DocSettingsTest',
    'getMigration1DocSettingsStatus',
    'runMigration1FinalCleanSettingsTest',
    'getMigration1FinalCleanSettingsStatus',
    'runMigration1CostSettingsTest',
    'getMigration1CostSettingsStatus',
    'runMigration1E2eSettingsTest',
    'getMigration1E2eSettingsStatus',
    'runMigration1CutSettingsTest',
    'getMigration1CutSettingsStatus',
    'runMigration1DualSettingsTest',
    'getMigration1DualSettingsStatus',
    'runMigration1DashSettingsTest',
    'getMigration1DashSettingsStatus',
    'runMigration1SigSettingsTest',
    'getMigration1SigSettingsStatus',
    'runMigration1PubSettingsTest',
    'getMigration1PubSettingsStatus',
    'runMigration1IdResSettingsTest',
    'getMigration1IdResSettingsStatus',
    'runMigration1GateSettingsTest',
    'getMigration1GateSettingsStatus',
    'runMigration1ShadowSettingsTest',
    'getMigration1ShadowSettingsStatus'
  ];
  return candidates.filter(function (name) {
    try {
      return typeof this[name] === 'function';
    } catch (e) {
      return false;
    }
  });
}

function uniqueMigration4LockStrings_(items) {
  var seen = {};
  var out = [];
  (items || []).forEach(function (item) {
    var text = String(item || '').trim();
    if (!text || seen[text]) return;
    seen[text] = true;
    out.push(text);
  });
  return out;
}

function normalizeMigration4LockErrorMessage_(error) {
  if (!error) return '';
  if (error && error.message) return String(error.message);
  return String(error);
}

function classifyMigration4LockErrorKind_(error) {
  var message = normalizeMigration4LockErrorMessage_(error);
  if (message.indexOf('M4_LOCK_M3_FREEZE_MISSING') !== -1) return 'missing_m3_freeze';
  return message ? 'runtime_error' : '';
}
