var PHBOX_M4_LOCK_VERSION_ = 'M4_LOCK_v1';
var PHBOX_M4_LOCK_STAGE_ = 'migration4_lock';
var PHBOX_M4_LOCK_REQUIRED_FREEZE_VERSION_ = 'M3_FREEZE_v1';
var PHBOX_M4_LOCK_OWNER_ = 'backend_gas_m4_lock_contract_only';
var PHBOX_M4_LOCK_SOURCE_OWNER_ = 'legacy_firestore_source_read_only_until_m5';
var PHBOX_M4_LOCK_TARGET_OWNER_ = 'tenant_scoped_firestore_future_m4_plan';
var PHBOX_M4_LOCK_POLICY_ = 'authorize_m4_plan_only_without_firestore_io';
var PHBOX_M4_LOCK_MODE_ = 'm4_entry_gate_no_data_access';
var PHBOX_M4_LOCK_NEXT_STAGE_ = 'M4-PLAN';
var PHBOX_M4_LOCK_REQUIRED_STAGES_ = [
  'm3_freeze'
];
var PHBOX_M4_LOCK_REQUIRED_CHECKS_ = [
  'm3_freeze_ok',
  'm3_freeze_version',
  'm3_closed',
  'm4_allowed_next',
  'zero_costs',
  'no_source_scan',
  'no_target_scan',
  'no_target_path',
  'no_materialize',
  'no_cutover',
  'no_legacy_write',
  'no_schema_change'
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
    sourceOwner: PHBOX_M4_LOCK_SOURCE_OWNER_,
    targetOwner: PHBOX_M4_LOCK_TARGET_OWNER_,
    lockPolicy: PHBOX_M4_LOCK_POLICY_,
    lockMode: PHBOX_M4_LOCK_MODE_,
    nextAllowedStage: PHBOX_M4_LOCK_NEXT_STAGE_,
    requiredStages: PHBOX_M4_LOCK_REQUIRED_STAGES_.slice(),
    requiredChecks: PHBOX_M4_LOCK_REQUIRED_CHECKS_.slice(),
    lockContractDeclared: true,
    m4Locked: true,
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
    sourceScanExecuted: false,
    targetScanExecuted: false,
    sourceCountsCollected: false,
    targetCountsCollected: false,
    sourcePatientsCount: null,
    sourceFamiliesCount: null,
    sourceSubcollectionsCount: null,
    sourceDoctorLinksCount: null,
    sourceDashboardIndexCount: null,
    sourceDrivePdfImportsLinkedCount: null,
    plannedTargetWrites: null,
    migrationSignatureComputed: false,
    migrationSignature: '',
    blockingAnomalies: null,
    blockingAnomaliesDetected: false,
    targetPathBuilt: false,
    tenantTargetPathBuilt: false,
    dryRunOk: false,
    materializeStarted: false,
    materializeComplete: false,
    verifyStarted: false,
    verifyOk: false,
    cutoverStarted: false,
    cutoverOk: false,
    tenantRoutingActive: false,
    tenantScopedReads: false,
    tenantScopedWrites: false,
    legacyRuntimeDisabled: false,
    legacySourceTouched: false,
    legacySourceDeleted: false,
    lifecycleTouched: false,
    authRuntimeChanged: false,
    authProviderTouched: false,
    authTokenValidated: false,
    sessionCreated: false,
    frontRouteRuntimeChanged: false,
    routeResolved: false,
    navigationChanged: false,
    backendRouteRuntimeChanged: false,
    backendRouteResolved: false,
    backendDispatchExecuted: false,
    backendRunStarted: false,
    triggerInstalled: false,
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
    requiredE2eVersion: String(freezeStats.requiredE2eVersion || ''),
    e2eVersion: String(freezeStats.e2eVersion || ''),
    recoveryVersion: String(freezeStats.recoveryVersion || ''),
    observabilityVersion: String(freezeStats.observabilityVersion || ''),
    backendRouteVersion: String(freezeStats.backendRouteVersion || ''),
    frontRouteVersion: String(freezeStats.frontRouteVersion || ''),
    authVersion: String(freezeStats.authVersion || ''),
    costGuardVersion: String(freezeStats.costGuardVersion || ''),
    configVersion: String(freezeStats.configVersion || ''),
    registryVersion: String(freezeStats.registryVersion || ''),
    lockOwner: String(contract.owner || ''),
    sourceOwner: String(contract.sourceOwner || ''),
    targetOwner: String(contract.targetOwner || ''),
    lockPolicy: String(contract.lockPolicy || ''),
    lockMode: String(contract.lockMode || ''),
    nextAllowedStage: String(contract.nextAllowedStage || ''),
    lockContractDeclared: !!contract.lockContractDeclared,
    requiredStages: uniqueMigration4LockStrings_(contract.requiredStages || []),
    requiredChecks: uniqueMigration4LockStrings_(contract.requiredChecks || []),
    m3FreezeOk: !!(freezeStatus && freezeStatus.ok),
    m3Closed: !!freezeStats.m3Closed,
    m3Frozen: !!freezeStats.frozen,
    m4AllowedNextFromM3: !!freezeStats.m4AllowedNext,
    m4Locked: !!contract.m4Locked,
    m4PlanAllowedNext: !!contract.m4PlanAllowedNext,
    m4DryRunAllowedNext: !!contract.m4DryRunAllowedNext,
    m4MaterializeAllowedNext: !!contract.m4MaterializeAllowedNext,
    m4VerifyAllowedNext: !!contract.m4VerifyAllowedNext,
    m4CutoverAllowedNext: !!contract.m4CutoverAllowedNext,
    m4FreezeAllowedNext: !!contract.m4FreezeAllowedNext,
    firestoreReads: sumMigration4LockNumbers_([freezeStats.firestoreReads, contract.firestoreReads, data.firestoreReads]),
    firestoreWrites: sumMigration4LockNumbers_([freezeStats.firestoreWrites, contract.firestoreWrites, data.firestoreWrites]),
    estimatedReadsPerHour: sumMigration4LockNumbers_([freezeStats.estimatedReadsPerHour, contract.estimatedReadsPerHour, data.estimatedReadsPerHour]),
    estimatedWritesPerHour: sumMigration4LockNumbers_([freezeStats.estimatedWritesPerHour, contract.estimatedWritesPerHour, data.estimatedWritesPerHour]),
    registryReads: sumMigration4LockNumbers_([freezeStats.registryReads, contract.registryReads, data.registryReads]),
    registryWrites: sumMigration4LockNumbers_([freezeStats.registryWrites, contract.registryWrites, data.registryWrites]),
    configReads: sumMigration4LockNumbers_([freezeStats.configReads, contract.configReads, data.configReads]),
    configWrites: sumMigration4LockNumbers_([freezeStats.configWrites, contract.configWrites, data.configWrites]),
    sourceReads: sumMigration4LockNumbers_([contract.sourceReads, data.sourceReads]),
    sourceWrites: sumMigration4LockNumbers_([contract.sourceWrites, data.sourceWrites]),
    targetReads: sumMigration4LockNumbers_([contract.targetReads, data.targetReads]),
    targetWrites: sumMigration4LockNumbers_([contract.targetWrites, data.targetWrites]),
    targetWritesExecuted: sumMigration4LockNumbers_([freezeStats.targetWritesExecuted, contract.targetWritesExecuted, data.targetWritesExecuted]),
    listeners: sumMigration4LockNumbers_([freezeStats.listeners, contract.listeners, data.listeners]),
    queries: sumMigration4LockNumbers_([freezeStats.queries, contract.queries, data.queries]),
    fanOut: sumMigration4LockNumbers_([freezeStats.fanOut, contract.fanOut, data.fanOut]),
    sourceScanExecuted: boolMigration4LockAny_([freezeStats.sourceScanExecuted, contract.sourceScanExecuted, data.sourceScanExecuted]),
    targetScanExecuted: boolMigration4LockAny_([freezeStats.targetScanExecuted, contract.targetScanExecuted, data.targetScanExecuted]),
    sourceCountsCollected: boolMigration4LockAny_([freezeStats.sourceCountsCollected, contract.sourceCountsCollected, data.sourceCountsCollected]),
    targetCountsCollected: boolMigration4LockAny_([freezeStats.targetCountsCollected, contract.targetCountsCollected, data.targetCountsCollected]),
    sourcePatientsCount: contract.sourcePatientsCount,
    sourceFamiliesCount: contract.sourceFamiliesCount,
    sourceSubcollectionsCount: contract.sourceSubcollectionsCount,
    sourceDoctorLinksCount: contract.sourceDoctorLinksCount,
    sourceDashboardIndexCount: contract.sourceDashboardIndexCount,
    sourceDrivePdfImportsLinkedCount: contract.sourceDrivePdfImportsLinkedCount,
    plannedTargetWrites: contract.plannedTargetWrites,
    migrationSignatureComputed: boolMigration4LockAny_([freezeStats.migrationSignatureComputed, contract.migrationSignatureComputed, data.migrationSignatureComputed]),
    migrationSignature: String(contract.migrationSignature || data.migrationSignature || ''),
    blockingAnomalies: contract.blockingAnomalies,
    blockingAnomaliesDetected: boolMigration4LockAny_([freezeStats.blockingAnomaliesDetected, contract.blockingAnomaliesDetected, data.blockingAnomaliesDetected]),
    targetPathBuilt: boolMigration4LockAny_([freezeStats.targetPathBuilt, contract.targetPathBuilt, data.targetPathBuilt]),
    tenantTargetPathBuilt: boolMigration4LockAny_([freezeStats.tenantTargetPathBuilt, contract.tenantTargetPathBuilt, data.tenantTargetPathBuilt]),
    dryRunOk: !!contract.dryRunOk || !!data.dryRunOk,
    materializeStarted: !!contract.materializeStarted || !!data.materializeStarted || !!freezeStats.m4MaterializeStarted,
    materializeComplete: !!contract.materializeComplete || !!data.materializeComplete,
    verifyStarted: !!contract.verifyStarted || !!data.verifyStarted,
    verifyOk: !!contract.verifyOk || !!data.verifyOk,
    cutoverStarted: !!contract.cutoverStarted || !!data.cutoverStarted,
    cutoverOk: !!contract.cutoverOk || !!data.cutoverOk,
    tenantRoutingActive: boolMigration4LockAny_([freezeStats.tenantRoutingActive, contract.tenantRoutingActive, data.tenantRoutingActive]),
    tenantScopedReads: !!contract.tenantScopedReads || !!data.tenantScopedReads,
    tenantScopedWrites: !!contract.tenantScopedWrites || !!data.tenantScopedWrites,
    legacyRuntimeDisabled: !!contract.legacyRuntimeDisabled || !!data.legacyRuntimeDisabled,
    legacySourceTouched: !!contract.legacySourceTouched || !!data.legacySourceTouched,
    legacySourceDeleted: !!contract.legacySourceDeleted || !!data.legacySourceDeleted,
    lifecycleTouched: boolMigration4LockAny_([freezeStats.lifecycleTouched, contract.lifecycleTouched, data.lifecycleTouched]),
    authRuntimeChanged: boolMigration4LockAny_([freezeStats.authRuntimeChanged, contract.authRuntimeChanged, data.authRuntimeChanged]),
    authProviderTouched: boolMigration4LockAny_([freezeStats.authProviderTouched, contract.authProviderTouched, data.authProviderTouched]),
    authTokenValidated: boolMigration4LockAny_([freezeStats.authTokenValidated, contract.authTokenValidated, data.authTokenValidated]),
    sessionCreated: boolMigration4LockAny_([freezeStats.sessionCreated, contract.sessionCreated, data.sessionCreated]),
    frontRouteRuntimeChanged: boolMigration4LockAny_([freezeStats.frontRouteRuntimeChanged, contract.frontRouteRuntimeChanged, data.frontRouteRuntimeChanged]),
    routeResolved: boolMigration4LockAny_([freezeStats.routeResolved, contract.routeResolved, data.routeResolved]),
    navigationChanged: boolMigration4LockAny_([freezeStats.navigationChanged, contract.navigationChanged, data.navigationChanged]),
    backendRouteRuntimeChanged: boolMigration4LockAny_([freezeStats.backendRouteRuntimeChanged, contract.backendRouteRuntimeChanged, data.backendRouteRuntimeChanged]),
    backendRouteResolved: boolMigration4LockAny_([freezeStats.backendRouteResolved, contract.backendRouteResolved, data.backendRouteResolved]),
    backendDispatchExecuted: boolMigration4LockAny_([freezeStats.backendDispatchExecuted, contract.backendDispatchExecuted, data.backendDispatchExecuted]),
    backendRunStarted: boolMigration4LockAny_([freezeStats.backendRunStarted, contract.backendRunStarted, data.backendRunStarted]),
    triggerInstalled: boolMigration4LockAny_([freezeStats.triggerInstalled, contract.triggerInstalled, data.triggerInstalled]),
    recoveryStateRead: boolMigration4LockAny_([freezeStats.recoveryStateRead, contract.recoveryStateRead, data.recoveryStateRead]),
    recoveryStateWritten: boolMigration4LockAny_([freezeStats.recoveryStateWritten, contract.recoveryStateWritten, data.recoveryStateWritten]),
    recoveryCheckpointWritten: boolMigration4LockAny_([freezeStats.recoveryCheckpointWritten, contract.recoveryCheckpointWritten, data.recoveryCheckpointWritten]),
    recoveryCursorAdvanced: boolMigration4LockAny_([freezeStats.recoveryCursorAdvanced, contract.recoveryCursorAdvanced, data.recoveryCursorAdvanced]),
    recoveryResumeExecuted: boolMigration4LockAny_([freezeStats.recoveryResumeExecuted, contract.recoveryResumeExecuted, data.recoveryResumeExecuted]),
    partialWriteRecoveryExecuted: boolMigration4LockAny_([freezeStats.partialWriteRecoveryExecuted, contract.partialWriteRecoveryExecuted, data.partialWriteRecoveryExecuted]),
    idempotentRetryExecuted: boolMigration4LockAny_([freezeStats.idempotentRetryExecuted, contract.idempotentRetryExecuted, data.idempotentRetryExecuted]),
    schemaChanged: boolMigration4LockAny_([freezeStats.schemaChanged, contract.schemaChanged, data.schemaChanged]),
    runtimeContractChanged: boolMigration4LockAny_([freezeStats.runtimeContractChanged, contract.runtimeContractChanged, data.runtimeContractChanged]),
    obsoleteHandlers: obsoleteHandlers,
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };
  var violations = buildMigration4LockViolations_({
    freezePresent: !!(freezeStatus && freezeStatus.stats),
    freezeOk: statsInput.m3FreezeOk,
    lockVersion: statsInput.lockVersion,
    stage: statsInput.stage,
    requiredFreezeVersion: statsInput.requiredFreezeVersion,
    freezeVersion: statsInput.freezeVersion,
    lockOwner: statsInput.lockOwner,
    sourceOwner: statsInput.sourceOwner,
    targetOwner: statsInput.targetOwner,
    lockPolicy: statsInput.lockPolicy,
    lockMode: statsInput.lockMode,
    nextAllowedStage: statsInput.nextAllowedStage,
    lockContractDeclared: statsInput.lockContractDeclared,
    requiredStages: statsInput.requiredStages,
    requiredChecks: statsInput.requiredChecks,
    m3Closed: statsInput.m3Closed,
    m3Frozen: statsInput.m3Frozen,
    m4AllowedNextFromM3: statsInput.m4AllowedNextFromM3,
    m4Locked: statsInput.m4Locked,
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
    sourceScanExecuted: statsInput.sourceScanExecuted,
    targetScanExecuted: statsInput.targetScanExecuted,
    sourceCountsCollected: statsInput.sourceCountsCollected,
    targetCountsCollected: statsInput.targetCountsCollected,
    migrationSignatureComputed: statsInput.migrationSignatureComputed,
    blockingAnomaliesDetected: statsInput.blockingAnomaliesDetected,
    targetPathBuilt: statsInput.targetPathBuilt,
    tenantTargetPathBuilt: statsInput.tenantTargetPathBuilt,
    dryRunOk: statsInput.dryRunOk,
    materializeStarted: statsInput.materializeStarted,
    materializeComplete: statsInput.materializeComplete,
    verifyStarted: statsInput.verifyStarted,
    verifyOk: statsInput.verifyOk,
    cutoverStarted: statsInput.cutoverStarted,
    cutoverOk: statsInput.cutoverOk,
    tenantRoutingActive: statsInput.tenantRoutingActive,
    tenantScopedReads: statsInput.tenantScopedReads,
    tenantScopedWrites: statsInput.tenantScopedWrites,
    legacyRuntimeDisabled: statsInput.legacyRuntimeDisabled,
    legacySourceTouched: statsInput.legacySourceTouched,
    legacySourceDeleted: statsInput.legacySourceDeleted,
    lifecycleTouched: statsInput.lifecycleTouched,
    authRuntimeChanged: statsInput.authRuntimeChanged,
    authProviderTouched: statsInput.authProviderTouched,
    authTokenValidated: statsInput.authTokenValidated,
    sessionCreated: statsInput.sessionCreated,
    frontRouteRuntimeChanged: statsInput.frontRouteRuntimeChanged,
    routeResolved: statsInput.routeResolved,
    navigationChanged: statsInput.navigationChanged,
    backendRouteRuntimeChanged: statsInput.backendRouteRuntimeChanged,
    backendRouteResolved: statsInput.backendRouteResolved,
    backendDispatchExecuted: statsInput.backendDispatchExecuted,
    backendRunStarted: statsInput.backendRunStarted,
    triggerInstalled: statsInput.triggerInstalled,
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
  statsInput.reason = violations.length ? 'm4_lock_violation' : 'm4_lock_ready';
  statsInput.m4Locked = violations.length === 0 && statsInput.m4Locked;
  statsInput.m4PlanAllowedNext = violations.length === 0 && statsInput.m4PlanAllowedNext;
  statsInput.violations = violations;
  return buildMigration4LockResultFromStats_(statsInput);
}

function buildMigration4LockViolations_(data) {
  data = data || {};
  var violations = [];
  if (!data.freezePresent) violations.push('m3_freeze_status_missing');
  if (data.freezePresent && !data.freezeOk) violations.push('m3_freeze_not_ok');
  if (String(data.lockVersion || '') !== PHBOX_M4_LOCK_VERSION_) violations.push('lock_version_mismatch');
  if (String(data.stage || '') !== PHBOX_M4_LOCK_STAGE_) violations.push('lock_stage_mismatch');
  if (String(data.requiredFreezeVersion || '') !== PHBOX_M4_LOCK_REQUIRED_FREEZE_VERSION_) violations.push('required_freeze_version_mismatch');
  if (String(data.freezeVersion || '') !== PHBOX_M4_LOCK_REQUIRED_FREEZE_VERSION_) violations.push('m3_freeze_version_mismatch');
  if (String(data.lockOwner || '') !== PHBOX_M4_LOCK_OWNER_) violations.push('lock_owner_mismatch');
  if (String(data.sourceOwner || '') !== PHBOX_M4_LOCK_SOURCE_OWNER_) violations.push('source_owner_mismatch');
  if (String(data.targetOwner || '') !== PHBOX_M4_LOCK_TARGET_OWNER_) violations.push('target_owner_mismatch');
  if (String(data.lockPolicy || '') !== PHBOX_M4_LOCK_POLICY_) violations.push('lock_policy_mismatch');
  if (String(data.lockMode || '') !== PHBOX_M4_LOCK_MODE_) violations.push('lock_mode_mismatch');
  if (String(data.nextAllowedStage || '') !== PHBOX_M4_LOCK_NEXT_STAGE_) violations.push('next_allowed_stage_mismatch');
  if (!data.lockContractDeclared) violations.push('lock_contract_not_declared');
  PHBOX_M4_LOCK_REQUIRED_STAGES_.forEach(function (name) {
    if (data.requiredStages.indexOf(name) === -1) violations.push('missing_required_stage_' + sanitizeMigration4LockName_(name));
  });
  PHBOX_M4_LOCK_REQUIRED_CHECKS_.forEach(function (name) {
    if (data.requiredChecks.indexOf(name) === -1) violations.push('missing_required_check_' + sanitizeMigration4LockName_(name));
  });
  if (!data.m3Closed) violations.push('m3_not_closed');
  if (!data.m3Frozen) violations.push('m3_not_frozen');
  if (!data.m4AllowedNextFromM3) violations.push('m4_not_allowed_by_m3_freeze');
  if (!data.m4Locked) violations.push('m4_not_locked');
  if (!data.m4PlanAllowedNext) violations.push('m4_plan_not_allowed_next');
  if (data.m4DryRunAllowedNext) violations.push('m4_dryrun_allowed_too_early');
  if (data.m4MaterializeAllowedNext) violations.push('m4_materialize_allowed_too_early');
  if (data.m4VerifyAllowedNext) violations.push('m4_verify_allowed_too_early');
  if (data.m4CutoverAllowedNext) violations.push('m4_cutover_allowed_too_early');
  if (data.m4FreezeAllowedNext) violations.push('m4_freeze_allowed_too_early');
  if (Number(data.firestoreReads || 0) > 0) violations.push('firestore_reads_detected');
  if (Number(data.firestoreWrites || 0) > 0) violations.push('firestore_writes_detected');
  if (Number(data.estimatedReadsPerHour || 0) > 0) violations.push('estimated_reads_per_hour_detected');
  if (Number(data.estimatedWritesPerHour || 0) > 0) violations.push('estimated_writes_per_hour_detected');
  if (Number(data.registryReads || 0) > 0) violations.push('registry_reads_detected');
  if (Number(data.registryWrites || 0) > 0) violations.push('registry_writes_detected');
  if (Number(data.configReads || 0) > 0) violations.push('config_reads_detected');
  if (Number(data.configWrites || 0) > 0) violations.push('config_writes_detected');
  if (Number(data.sourceReads || 0) > 0) violations.push('source_reads_detected');
  if (Number(data.sourceWrites || 0) > 0) violations.push('source_writes_detected');
  if (Number(data.targetReads || 0) > 0) violations.push('target_reads_detected');
  if (Number(data.targetWrites || 0) > 0) violations.push('target_writes_detected');
  if (Number(data.targetWritesExecuted || 0) > 0) violations.push('target_writes_executed_detected');
  if (Number(data.listeners || 0) > 0) violations.push('listeners_detected');
  if (Number(data.queries || 0) > 0) violations.push('queries_detected');
  if (Number(data.fanOut || 0) > 0) violations.push('fanout_detected');
  if (data.sourceScanExecuted) violations.push('source_scan_executed_before_m4_plan');
  if (data.targetScanExecuted) violations.push('target_scan_executed_before_m4_plan');
  if (data.sourceCountsCollected) violations.push('source_counts_collected_before_m4_plan');
  if (data.targetCountsCollected) violations.push('target_counts_collected_before_m4_plan');
  if (data.migrationSignatureComputed) violations.push('migration_signature_computed_before_m4_plan');
  if (data.blockingAnomaliesDetected) violations.push('blocking_anomalies_detected_before_m4_plan');
  if (data.targetPathBuilt) violations.push('target_path_built_before_m4_dryrun');
  if (data.tenantTargetPathBuilt) violations.push('tenant_target_path_built_before_m4_dryrun');
  if (data.dryRunOk) violations.push('m4_dryrun_ok_before_m4_dryrun');
  if (data.materializeStarted) violations.push('m4_materialize_started_before_m4_materialize');
  if (data.materializeComplete) violations.push('m4_materialize_complete_before_m4_materialize');
  if (data.verifyStarted) violations.push('m4_verify_started_before_m4_verify');
  if (data.verifyOk) violations.push('m4_verify_ok_before_m4_verify');
  if (data.cutoverStarted) violations.push('m4_cutover_started_before_m4_cutover');
  if (data.cutoverOk) violations.push('m4_cutover_ok_before_m4_cutover');
  if (data.tenantRoutingActive) violations.push('tenant_routing_active_before_m4_cutover');
  if (data.tenantScopedReads) violations.push('tenant_scoped_reads_before_m4_cutover');
  if (data.tenantScopedWrites) violations.push('tenant_scoped_writes_before_m4_cutover');
  if (data.legacyRuntimeDisabled) violations.push('legacy_runtime_disabled_before_m4_cutover');
  if (data.legacySourceTouched) violations.push('legacy_source_touched');
  if (data.legacySourceDeleted) violations.push('legacy_source_deleted');
  if (data.lifecycleTouched) violations.push('lifecycle_touched');
  if (data.authRuntimeChanged) violations.push('auth_runtime_changed');
  if (data.authProviderTouched) violations.push('auth_provider_touched');
  if (data.authTokenValidated) violations.push('auth_token_validated');
  if (data.sessionCreated) violations.push('session_created');
  if (data.frontRouteRuntimeChanged) violations.push('front_route_runtime_changed');
  if (data.routeResolved) violations.push('front_route_resolved');
  if (data.navigationChanged) violations.push('navigation_changed');
  if (data.backendRouteRuntimeChanged) violations.push('backend_route_runtime_changed');
  if (data.backendRouteResolved) violations.push('backend_route_resolved');
  if (data.backendDispatchExecuted) violations.push('backend_dispatch_executed');
  if (data.backendRunStarted) violations.push('backend_run_started');
  if (data.triggerInstalled) violations.push('trigger_installed');
  if (data.recoveryStateRead) violations.push('recovery_state_read_before_m4_materialize');
  if (data.recoveryStateWritten) violations.push('recovery_state_written_before_m4_materialize');
  if (data.recoveryCheckpointWritten) violations.push('recovery_checkpoint_written_before_m4_materialize');
  if (data.recoveryCursorAdvanced) violations.push('recovery_cursor_advanced_before_m4_materialize');
  if (data.recoveryResumeExecuted) violations.push('recovery_resume_executed_before_m4_materialize');
  if (data.partialWriteRecoveryExecuted) violations.push('partial_write_recovery_executed_before_m4_materialize');
  if (data.idempotentRetryExecuted) violations.push('idempotent_retry_executed_before_m4_materialize');
  if (data.schemaChanged) violations.push('schema_changed');
  if (data.runtimeContractChanged) violations.push('runtime_contract_changed');
  if ((data.obsoleteHandlers || []).length > 0) violations.push('obsolete_settings_handlers_detected');
  if (data.error) violations.push('m4_lock_error');
  return violations;
}

function buildMigration4LockResultFromStats_(stats) {
  stats = stats || {};
  return {
    ok: !!stats.ok,
    skipped: !!stats.skipped,
    reason: String(stats.reason || ''),
    stats: stats
  };
}

function runMigration4LockSelfTest_() {
  var cases = buildMigration4LockSelfTestCases_();
  var items = cases.map(function (item) {
    var result = buildMigration4LockResult_(item.input || {});
    var stats = result.stats || {};
    var expectedOk = !!item.expectedOk;
    var passed = result.ok === expectedOk;
    if (expectedOk && stats.m4Locked !== true) passed = false;
    if (expectedOk && stats.m4PlanAllowedNext !== true) passed = false;
    if (!expectedOk && stats.m4Locked !== false) passed = false;
    if (!expectedOk && stats.m4PlanAllowedNext !== false) passed = false;
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
  var clean = buildMigration4LockResult_({
    freezeStatus: buildMigration4LockCleanFreezeStatus_(),
    contract: buildMigration4LockContract_(),
    obsoleteHandlers: []
  });
  return {
    ok: failed.length === 0 && !!clean.ok,
    testCount: items.length,
    passedCount: items.length - failed.length,
    failedCount: failed.length,
    result: clean,
    items: items,
    reason: failed.length ? 'm4_lock_selftest_failed' : 'm4_lock_selftest_passed'
  };
}

function buildMigration4LockSelfTestCases_() {
  return [
    { id: 'clean_m3_freeze_authorizes_m4_lock', expectedOk: true, input: { freezeStatus: buildMigration4LockCleanFreezeStatus_(), contract: buildMigration4LockContract_(), obsoleteHandlers: [] } },
    { id: 'missing_m3_freeze_blocks_m4_lock', expectedOk: false, expectedViolations: ['m3_freeze_status_missing'], input: { freezeStatus: null, contract: buildMigration4LockContract_(), obsoleteHandlers: [] } },
    { id: 'm3_freeze_not_ok_blocks_m4_lock', expectedOk: false, expectedViolations: ['m3_freeze_not_ok'], input: { freezeStatus: buildMigration4LockCleanFreezeStatus_({ ok: false }), contract: buildMigration4LockContract_(), obsoleteHandlers: [] } },
    { id: 'm3_freeze_version_mismatch_blocks_m4_lock', expectedOk: false, expectedViolations: ['m3_freeze_version_mismatch'], input: { freezeStatus: buildMigration4LockCleanFreezeStatus_({ freezeVersion: 'M3_FREEZE_v0' }), contract: buildMigration4LockContract_(), obsoleteHandlers: [] } },
    { id: 'm3_closed_flags_missing_blocks_m4_lock', expectedOk: false, expectedViolations: ['m3_not_closed', 'm3_not_frozen', 'm4_not_allowed_by_m3_freeze'], input: { freezeStatus: buildMigration4LockCleanFreezeStatus_({ m3Closed: false, frozen: false, m4AllowedNext: false }), contract: buildMigration4LockContract_(), obsoleteHandlers: [] } },
    { id: 'lock_version_or_owner_mismatch_blocks_m4_lock', expectedOk: false, expectedViolations: ['lock_version_mismatch', 'lock_owner_mismatch'], input: { freezeStatus: buildMigration4LockCleanFreezeStatus_(), contract: buildMigration4LockContractOverride_({ lockVersion: 'M4_LOCK_v0', owner: 'frontend_runtime' }), obsoleteHandlers: [] } },
    { id: 'lock_policy_or_next_stage_mismatch_blocks_m4_lock', expectedOk: false, expectedViolations: ['lock_policy_mismatch', 'next_allowed_stage_mismatch'], input: { freezeStatus: buildMigration4LockCleanFreezeStatus_(), contract: buildMigration4LockContractOverride_({ lockPolicy: 'start_m4_materialize_now', nextAllowedStage: 'M4-MATERIALIZE' }), obsoleteHandlers: [] } },
    { id: 'missing_required_check_blocks_m4_lock', expectedOk: false, expectedViolations: ['missing_required_check_zero_costs'], input: { freezeStatus: buildMigration4LockCleanFreezeStatus_(), contract: buildMigration4LockContractOverride_({ requiredChecks: ['m3_freeze_ok'] }), obsoleteHandlers: [] } },
    { id: 'wrong_next_stage_flags_block_m4_lock', expectedOk: false, expectedViolations: ['m4_dryrun_allowed_too_early', 'm4_materialize_allowed_too_early', 'm4_cutover_allowed_too_early'], input: { freezeStatus: buildMigration4LockCleanFreezeStatus_(), contract: buildMigration4LockContractOverride_({ m4DryRunAllowedNext: true, m4MaterializeAllowedNext: true, m4CutoverAllowedNext: true }), obsoleteHandlers: [] } },
    { id: 'firestore_or_source_io_blocks_m4_lock', expectedOk: false, expectedViolations: ['firestore_reads_detected', 'firestore_writes_detected', 'source_reads_detected', 'source_writes_detected'], input: { freezeStatus: buildMigration4LockCleanFreezeStatus_({ firestoreReads: 1, firestoreWrites: 1 }), contract: buildMigration4LockContractOverride_({ sourceReads: 1, sourceWrites: 1 }), obsoleteHandlers: [] } },
    { id: 'target_io_blocks_m4_lock', expectedOk: false, expectedViolations: ['target_reads_detected', 'target_writes_detected', 'target_writes_executed_detected'], input: { freezeStatus: buildMigration4LockCleanFreezeStatus_(), contract: buildMigration4LockContractOverride_({ targetReads: 1, targetWrites: 1, targetWritesExecuted: 1 }), obsoleteHandlers: [] } },
    { id: 'listener_query_fanout_blocks_m4_lock', expectedOk: false, expectedViolations: ['listeners_detected', 'queries_detected', 'fanout_detected'], input: { freezeStatus: buildMigration4LockCleanFreezeStatus_({ listeners: 1, queries: 1, fanOut: 1 }), contract: buildMigration4LockContract_(), obsoleteHandlers: [] } },
    { id: 'source_target_scan_blocks_m4_lock', expectedOk: false, expectedViolations: ['source_scan_executed_before_m4_plan', 'target_scan_executed_before_m4_plan', 'source_counts_collected_before_m4_plan', 'target_counts_collected_before_m4_plan'], input: { freezeStatus: buildMigration4LockCleanFreezeStatus_({ sourceScanExecuted: true, targetScanExecuted: true, sourceCountsCollected: true, targetCountsCollected: true }), contract: buildMigration4LockContract_(), obsoleteHandlers: [] } },
    { id: 'signature_or_anomaly_blocks_m4_lock', expectedOk: false, expectedViolations: ['migration_signature_computed_before_m4_plan', 'blocking_anomalies_detected_before_m4_plan'], input: { freezeStatus: buildMigration4LockCleanFreezeStatus_({ migrationSignatureComputed: true, blockingAnomaliesDetected: true }), contract: buildMigration4LockContract_(), obsoleteHandlers: [] } },
    { id: 'target_path_or_dryrun_blocks_m4_lock', expectedOk: false, expectedViolations: ['target_path_built_before_m4_dryrun', 'tenant_target_path_built_before_m4_dryrun', 'm4_dryrun_ok_before_m4_dryrun'], input: { freezeStatus: buildMigration4LockCleanFreezeStatus_({ targetPathBuilt: true, tenantTargetPathBuilt: true }), contract: buildMigration4LockContractOverride_({ dryRunOk: true }), obsoleteHandlers: [] } },
    { id: 'materialize_verify_cutover_blocks_m4_lock', expectedOk: false, expectedViolations: ['m4_materialize_started_before_m4_materialize', 'm4_verify_started_before_m4_verify', 'm4_cutover_started_before_m4_cutover'], input: { freezeStatus: buildMigration4LockCleanFreezeStatus_({ m4MaterializeStarted: true }), contract: buildMigration4LockContractOverride_({ verifyStarted: true, cutoverStarted: true }), obsoleteHandlers: [] } },
    { id: 'tenant_runtime_or_legacy_touch_blocks_m4_lock', expectedOk: false, expectedViolations: ['tenant_routing_active_before_m4_cutover', 'tenant_scoped_reads_before_m4_cutover', 'tenant_scoped_writes_before_m4_cutover', 'legacy_source_touched', 'legacy_source_deleted'], input: { freezeStatus: buildMigration4LockCleanFreezeStatus_({ tenantRoutingActive: true }), contract: buildMigration4LockContractOverride_({ tenantScopedReads: true, tenantScopedWrites: true, legacySourceTouched: true, legacySourceDeleted: true }), obsoleteHandlers: [] } },
    { id: 'auth_front_backend_runtime_blocks_m4_lock', expectedOk: false, expectedViolations: ['auth_runtime_changed', 'front_route_runtime_changed', 'backend_route_runtime_changed', 'backend_run_started', 'trigger_installed'], input: { freezeStatus: buildMigration4LockCleanFreezeStatus_({ authRuntimeChanged: true, frontRouteRuntimeChanged: true, backendRouteRuntimeChanged: true, backendRunStarted: true, triggerInstalled: true }), contract: buildMigration4LockContract_(), obsoleteHandlers: [] } },
    { id: 'recovery_state_blocks_m4_lock', expectedOk: false, expectedViolations: ['recovery_state_read_before_m4_materialize', 'recovery_state_written_before_m4_materialize', 'recovery_checkpoint_written_before_m4_materialize', 'recovery_cursor_advanced_before_m4_materialize'], input: { freezeStatus: buildMigration4LockCleanFreezeStatus_({ recoveryStateRead: true, recoveryStateWritten: true, recoveryCheckpointWritten: true, recoveryCursorAdvanced: true }), contract: buildMigration4LockContract_(), obsoleteHandlers: [] } },
    { id: 'schema_or_contract_blocks_m4_lock', expectedOk: false, expectedViolations: ['schema_changed', 'runtime_contract_changed'], input: { freezeStatus: buildMigration4LockCleanFreezeStatus_({ schemaChanged: true, runtimeContractChanged: true }), contract: buildMigration4LockContract_(), obsoleteHandlers: [] } },
    { id: 'obsolete_settings_handler_blocks_m4_lock', expectedOk: false, expectedViolations: ['obsolete_settings_handlers_detected'], input: { freezeStatus: buildMigration4LockCleanFreezeStatus_(), contract: buildMigration4LockContract_(), obsoleteHandlers: ['runMigration3FreezeSettingsTest'] } },
    { id: 'runtime_error_blocks_m4_lock', expectedOk: false, expectedViolations: ['m4_lock_error'], input: { freezeStatus: buildMigration4LockCleanFreezeStatus_(), contract: buildMigration4LockContract_(), obsoleteHandlers: [], error: 'boom' } }
  ];
}

function buildMigration4LockCleanFreezeStatus_(overrides) {
  overrides = overrides || {};
  var stats = {
    ok: true,
    skipped: false,
    reason: 'm3_freeze_ready',
    freezeVersion: 'M3_FREEZE_v1',
    requiredE2eVersion: 'M3_E2E_v1',
    e2eVersion: 'M3_E2E_v1',
    recoveryVersion: 'M3_RECOVERY_v1',
    observabilityVersion: 'M3_OBSERVABILITY_v1',
    backendRouteVersion: 'M3_BACKEND_ROUTE_v1',
    frontRouteVersion: 'M3_FRONT_ROUTE_v1',
    authVersion: 'M3_AUTH_v1',
    costGuardVersion: 'M3_COST_GUARD_v1',
    configVersion: 'M3_TENANT_CONFIG_v1',
    registryVersion: 'M3_TENANT_REGISTRY_v1',
    frozen: true,
    m3Closed: true,
    m4AllowedNext: true,
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

function buildMigration4LockContractOverride_(overrides) {
  var contract = buildMigration4LockContract_();
  Object.keys(overrides || {}).forEach(function (key) {
    contract[key] = overrides[key];
  });
  return contract;
}

function formatMigration4LockRuntimeFeedback_(result) {
  var stats = (result && result.stats) || {};
  return formatMigration4LockStats_('MIGRATION_4_LOCK_RUNTIME_STATUS', stats);
}

function formatMigration4LockSelfTestFeedback_(result) {
  result = result || {};
  var lines = [];
  lines.push('MIGRATION_4_LOCK_TEST');
  lines.push('ok=' + String(!!result.ok));
  lines.push('testCount=' + String(result.testCount || 0));
  lines.push('passedCount=' + String(result.passedCount || 0));
  lines.push('failedCount=' + String(result.failedCount || 0));
  lines.push(formatMigration4LockRuntimeFeedback_(result.result || {}));
  lines.push('items=');
  (result.items || []).forEach(function (item) {
    lines.push('- id=' + item.id);
    lines.push('  passed=' + String(!!item.passed));
    formatMigration4LockStats_('', (item.result && item.result.stats) || {})
      .split('\n')
      .filter(function (line) { return !!line; })
      .forEach(function (line) { lines.push('  ' + line); });
  });
  return lines.join('\n');
}

function formatMigration4LockStats_(title, stats) {
  stats = stats || {};
  var lines = [];
  if (title) lines.push(title);
  lines.push('ok=' + String(!!stats.ok));
  lines.push('skipped=' + String(!!stats.skipped));
  lines.push('reason=' + String(stats.reason || ''));
  lines.push('lockVersion=' + String(stats.lockVersion || ''));
  lines.push('stage=' + String(stats.stage || ''));
  lines.push('requiredFreezeVersion=' + String(stats.requiredFreezeVersion || ''));
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
  lines.push('lockOwner=' + String(stats.lockOwner || ''));
  lines.push('sourceOwner=' + String(stats.sourceOwner || ''));
  lines.push('targetOwner=' + String(stats.targetOwner || ''));
  lines.push('lockPolicy=' + String(stats.lockPolicy || ''));
  lines.push('lockMode=' + String(stats.lockMode || ''));
  lines.push('nextAllowedStage=' + String(stats.nextAllowedStage || ''));
  lines.push('lockContractDeclared=' + String(!!stats.lockContractDeclared));
  lines.push('requiredStagesCount=' + String((stats.requiredStages || []).length));
  lines.push('requiredChecksCount=' + String((stats.requiredChecks || []).length));
  lines.push('requiredStages=' + (stats.requiredStages || []).join(','));
  lines.push('requiredChecks=' + (stats.requiredChecks || []).join(','));
  lines.push('m3FreezeOk=' + String(!!stats.m3FreezeOk));
  lines.push('m3Closed=' + String(!!stats.m3Closed));
  lines.push('m3Frozen=' + String(!!stats.m3Frozen));
  lines.push('m4AllowedNextFromM3=' + String(!!stats.m4AllowedNextFromM3));
  lines.push('m4Locked=' + String(!!stats.m4Locked));
  lines.push('m4PlanAllowedNext=' + String(!!stats.m4PlanAllowedNext));
  lines.push('m4DryRunAllowedNext=' + String(!!stats.m4DryRunAllowedNext));
  lines.push('m4MaterializeAllowedNext=' + String(!!stats.m4MaterializeAllowedNext));
  lines.push('m4VerifyAllowedNext=' + String(!!stats.m4VerifyAllowedNext));
  lines.push('m4CutoverAllowedNext=' + String(!!stats.m4CutoverAllowedNext));
  lines.push('m4FreezeAllowedNext=' + String(!!stats.m4FreezeAllowedNext));
  lines.push('firestoreReads=' + String(Number(stats.firestoreReads || 0)));
  lines.push('firestoreWrites=' + String(Number(stats.firestoreWrites || 0)));
  lines.push('estimatedReadsPerHour=' + String(Number(stats.estimatedReadsPerHour || 0)));
  lines.push('estimatedWritesPerHour=' + String(Number(stats.estimatedWritesPerHour || 0)));
  lines.push('registryReads=' + String(Number(stats.registryReads || 0)));
  lines.push('registryWrites=' + String(Number(stats.registryWrites || 0)));
  lines.push('configReads=' + String(Number(stats.configReads || 0)));
  lines.push('configWrites=' + String(Number(stats.configWrites || 0)));
  lines.push('sourceReads=' + String(Number(stats.sourceReads || 0)));
  lines.push('sourceWrites=' + String(Number(stats.sourceWrites || 0)));
  lines.push('targetReads=' + String(Number(stats.targetReads || 0)));
  lines.push('targetWrites=' + String(Number(stats.targetWrites || 0)));
  lines.push('targetWritesExecuted=' + String(Number(stats.targetWritesExecuted || 0)));
  lines.push('listeners=' + String(Number(stats.listeners || 0)));
  lines.push('queries=' + String(Number(stats.queries || 0)));
  lines.push('fanOut=' + String(Number(stats.fanOut || 0)));
  lines.push('sourceScanExecuted=' + String(!!stats.sourceScanExecuted));
  lines.push('targetScanExecuted=' + String(!!stats.targetScanExecuted));
  lines.push('sourceCountsCollected=' + String(!!stats.sourceCountsCollected));
  lines.push('targetCountsCollected=' + String(!!stats.targetCountsCollected));
  lines.push('sourcePatientsCount=' + formatMigration4LockNullable_(stats.sourcePatientsCount));
  lines.push('sourceFamiliesCount=' + formatMigration4LockNullable_(stats.sourceFamiliesCount));
  lines.push('sourceSubcollectionsCount=' + formatMigration4LockNullable_(stats.sourceSubcollectionsCount));
  lines.push('sourceDoctorLinksCount=' + formatMigration4LockNullable_(stats.sourceDoctorLinksCount));
  lines.push('sourceDashboardIndexCount=' + formatMigration4LockNullable_(stats.sourceDashboardIndexCount));
  lines.push('sourceDrivePdfImportsLinkedCount=' + formatMigration4LockNullable_(stats.sourceDrivePdfImportsLinkedCount));
  lines.push('plannedTargetWrites=' + formatMigration4LockNullable_(stats.plannedTargetWrites));
  lines.push('migrationSignatureComputed=' + String(!!stats.migrationSignatureComputed));
  lines.push('migrationSignature=' + String(stats.migrationSignature || ''));
  lines.push('blockingAnomalies=' + formatMigration4LockNullable_(stats.blockingAnomalies));
  lines.push('blockingAnomaliesDetected=' + String(!!stats.blockingAnomaliesDetected));
  lines.push('targetPathBuilt=' + String(!!stats.targetPathBuilt));
  lines.push('tenantTargetPathBuilt=' + String(!!stats.tenantTargetPathBuilt));
  lines.push('dryRunOk=' + String(!!stats.dryRunOk));
  lines.push('materializeStarted=' + String(!!stats.materializeStarted));
  lines.push('materializeComplete=' + String(!!stats.materializeComplete));
  lines.push('verifyStarted=' + String(!!stats.verifyStarted));
  lines.push('verifyOk=' + String(!!stats.verifyOk));
  lines.push('cutoverStarted=' + String(!!stats.cutoverStarted));
  lines.push('cutoverOk=' + String(!!stats.cutoverOk));
  lines.push('tenantRoutingActive=' + String(!!stats.tenantRoutingActive));
  lines.push('tenantScopedReads=' + String(!!stats.tenantScopedReads));
  lines.push('tenantScopedWrites=' + String(!!stats.tenantScopedWrites));
  lines.push('legacyRuntimeDisabled=' + String(!!stats.legacyRuntimeDisabled));
  lines.push('legacySourceTouched=' + String(!!stats.legacySourceTouched));
  lines.push('legacySourceDeleted=' + String(!!stats.legacySourceDeleted));
  lines.push('lifecycleTouched=' + String(!!stats.lifecycleTouched));
  lines.push('authRuntimeChanged=' + String(!!stats.authRuntimeChanged));
  lines.push('authProviderTouched=' + String(!!stats.authProviderTouched));
  lines.push('authTokenValidated=' + String(!!stats.authTokenValidated));
  lines.push('sessionCreated=' + String(!!stats.sessionCreated));
  lines.push('frontRouteRuntimeChanged=' + String(!!stats.frontRouteRuntimeChanged));
  lines.push('routeResolved=' + String(!!stats.routeResolved));
  lines.push('navigationChanged=' + String(!!stats.navigationChanged));
  lines.push('backendRouteRuntimeChanged=' + String(!!stats.backendRouteRuntimeChanged));
  lines.push('backendRouteResolved=' + String(!!stats.backendRouteResolved));
  lines.push('backendDispatchExecuted=' + String(!!stats.backendDispatchExecuted));
  lines.push('backendRunStarted=' + String(!!stats.backendRunStarted));
  lines.push('triggerInstalled=' + String(!!stats.triggerInstalled));
  lines.push('recoveryStateRead=' + String(!!stats.recoveryStateRead));
  lines.push('recoveryStateWritten=' + String(!!stats.recoveryStateWritten));
  lines.push('recoveryCheckpointWritten=' + String(!!stats.recoveryCheckpointWritten));
  lines.push('recoveryCursorAdvanced=' + String(!!stats.recoveryCursorAdvanced));
  lines.push('recoveryResumeExecuted=' + String(!!stats.recoveryResumeExecuted));
  lines.push('partialWriteRecoveryExecuted=' + String(!!stats.partialWriteRecoveryExecuted));
  lines.push('idempotentRetryExecuted=' + String(!!stats.idempotentRetryExecuted));
  lines.push('schemaChanged=' + String(!!stats.schemaChanged));
  lines.push('runtimeContractChanged=' + String(!!stats.runtimeContractChanged));
  lines.push('obsoleteHandlers=' + ((stats.obsoleteHandlers || []).length ? stats.obsoleteHandlers.join(',') : 'none'));
  lines.push('violations=' + ((stats.violations || []).length ? stats.violations.join(',') : 'none'));
  lines.push('error=' + String(stats.error || ''));
  lines.push('errorKind=' + String(stats.errorKind || ''));
  return lines.join('\n');
}

function listMigration4LockObsoleteSettingsHandlers_() {
  var obsolete = [
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
    'getMigration3LockSettingsStatus'
  ];
  return obsolete.filter(function (name) {
    return typeof this[name] === 'function';
  }, this);
}

function normalizeMigration4LockErrorMessage_(error) {
  if (!error) return '';
  return String(error && error.message ? error.message : error);
}

function classifyMigration4LockErrorKind_(error) {
  var message = normalizeMigration4LockErrorMessage_(error);
  if (!message) return '';
  if (message.indexOf('M4_LOCK_M3_FREEZE_MISSING') !== -1) return 'm3_freeze_missing';
  return 'm4_lock_error';
}

function uniqueMigration4LockStrings_(items) {
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

function sanitizeMigration4LockName_(value) {
  return String(value || '').trim().toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
}

function sumMigration4LockNumbers_(items) {
  return Math.max(0, (items || []).reduce(function (total, value) {
    return total + Number(value || 0);
  }, 0));
}

function boolMigration4LockAny_(items) {
  return (items || []).some(function (value) { return !!value; });
}

function formatMigration4LockNullable_(value) {
  if (value === null || typeof value === 'undefined') return 'not_collected';
  return String(value);
}
