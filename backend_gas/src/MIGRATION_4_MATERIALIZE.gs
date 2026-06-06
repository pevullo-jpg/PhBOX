var PHBOX_M4_MATERIALIZE_VERSION_ = 'M4_MATERIALIZE_v1';
var PHBOX_M4_MATERIALIZE_STAGE_ = 'migration4_materialize';
var PHBOX_M4_MATERIALIZE_REQUIRED_LOCK_VERSION_ = 'M4_LOCK_v1';
var PHBOX_M4_MATERIALIZE_REQUIRED_FREEZE_VERSION_ = 'M3_FREEZE_v1';
var PHBOX_M4_MATERIALIZE_OWNER_ = 'backend_gas_m4_materialize_writer';
var PHBOX_M4_MATERIALIZE_RUNTIME_OWNER_ = 'future_m4_verify_gate';
var PHBOX_M4_MATERIALIZE_POLICY_ = 'bounded_idempotent_copy_source_to_tenant_target_without_source_delete';
var PHBOX_M4_MATERIALIZE_MODE_ = 'materialize_with_internal_preflight_and_dryrun';
var PHBOX_M4_MATERIALIZE_STATE_PATH_ = 'migrations/m4_materialize';
var PHBOX_M4_MATERIALIZE_TENANTS_COLLECTION_ = 'tenants';
var PHBOX_M4_MATERIALIZE_DEFAULT_MAX_WRITES_ = 20;
var PHBOX_M4_MATERIALIZE_DEFAULT_PAGE_SIZE_ = 20;
var PHBOX_M4_MATERIALIZE_MAX_PAGE_SIZE_ = 50;
var PHBOX_M4_MATERIALIZE_MAX_READS_PER_RUN_ = 180;
var PHBOX_M4_MATERIALIZE_ROOT_COLLECTIONS_ = [
  'patients',
  'doctor_patient_links',
  'families',
  'patient_dashboard_index',
  'dashboard_totals',
  'drive_pdf_imports'
];
var PHBOX_M4_MATERIALIZE_PATIENT_SUBCOLLECTIONS_ = [
  'debts',
  'advances',
  'bookings',
  'therapeutic_advice'
];

function runMigration4MaterializeRuntimeStatus_() {
  var cfg = null;
  var api = null;
  var lockStatus = null;
  var state = null;
  var tenant = null;
  var error = '';
  var errorKind = '';
  var firestoreReads = 0;
  var registryReads = 0;

  try {
    if (typeof runMigration4LockRuntimeStatus_ !== 'function') {
      throw new Error('M4_MATERIALIZE_LOCK_MISSING: funzione runMigration4LockRuntimeStatus_ non disponibile. Materialize non autorizzabile.');
    }
    lockStatus = runMigration4LockRuntimeStatus_();
    cfg = getPhboxConfig_();
    api = buildMigration4MaterializeFirestoreApi_(cfg);
    state = readMigration4MaterializeState_(api);
    firestoreReads++;
    tenant = resolveMigration4MaterializeTenant_(api, PropertiesService.getScriptProperties());
    firestoreReads += Math.max(0, Number(tenant.firestoreReads || 0));
    registryReads += Math.max(0, Number(tenant.registryReads || 0));
  } catch (e) {
    error = normalizeRuntimeErrorMessage_(e);
    errorKind = classifyRuntimeFailureKind_(e);
  }

  return buildMigration4MaterializeResult_({
    lockStatus: lockStatus,
    state: state,
    executeWrites: false,
    firestoreReads: firestoreReads,
    firestoreWrites: 0,
    registryReads: registryReads,
    tenantId: tenant && tenant.tenantId,
    sourceReads: 0,
    targetReads: 0,
    targetWritesExecuted: 0,
    maxWrites: readMigration4MaterializeMaxWrites_(),
    pageSize: readMigration4MaterializePageSize_(),
    error: error,
    errorKind: errorKind
  });
}

function runMigration4MaterializeBatch_(options) {
  options = options || {};
  var cfg = options.cfg || getPhboxConfig_();
  var api = options.firestoreApi || buildMigration4MaterializeFirestoreApi_(cfg);
  var lockStatus = Object.prototype.hasOwnProperty.call(options, 'lockStatus') ? options.lockStatus : runMigration4LockRuntimeStatus_();
  var nowIso = String(options.nowIso || new Date().toISOString());
  var maxWrites = normalizeMigration4MaterializeMaxWrites_(Object.prototype.hasOwnProperty.call(options, 'maxWrites') ? options.maxWrites : readMigration4MaterializeMaxWrites_(options.props));
  var pageSize = normalizeMigration4MaterializePageSize_(Object.prototype.hasOwnProperty.call(options, 'pageSize') ? options.pageSize : readMigration4MaterializePageSize_(options.props));
  var executeWrites = options.executeWrites === true;
  var state = Object.prototype.hasOwnProperty.call(options, 'state') ? normalizeMigration4MaterializeState_(options.state) : readMigration4MaterializeState_(api);
  var stats = buildMigration4MaterializeResult_({
    lockStatus: lockStatus,
    state: state,
    executeWrites: executeWrites,
    maxWrites: maxWrites,
    pageSize: pageSize,
    firestoreReads: Object.prototype.hasOwnProperty.call(options, 'state') ? 0 : 1,
    migrationStateRead: !Object.prototype.hasOwnProperty.call(options, 'state'),
    nowIso: nowIso
  }).stats;

  if (!stats.preflightOk || stats.blockingAnomalies > 0) {
    stats.reason = stats.reason || 'materialize_preflight_blocked';
    return { ok: false, stats: stats };
  }

  try {
    var tenant = resolveMigration4MaterializeTenant_(api, options.props || PropertiesService.getScriptProperties());
    var work = executeMigration4MaterializeWork_(cfg, api, state, {
      tenantId: tenant.tenantId,
      expectedTenantId: tenant.expectedTenantId,
      maxWrites: maxWrites,
      pageSize: pageSize,
      executeWrites: executeWrites,
      nowIso: nowIso,
      budget: options.budget
    });

    var nextState = buildMigration4MaterializeNextState_(state, work, {
      tenantId: tenant.tenantId,
      nowIso: nowIso,
      maxWrites: maxWrites,
      pageSize: pageSize,
      executeWrites: executeWrites
    });

    if (executeWrites && typeof options.saveStateFn === 'function') {
      options.saveStateFn(nextState);
      work.migrationStateWritten = true;
      work.firestoreWrites += 1;
    } else if (executeWrites) {
      writeMigration4MaterializeState_(api, nextState, cfg);
      work.migrationStateWritten = true;
      work.firestoreWrites += 1;
    }

    return buildMigration4MaterializeResult_({
      lockStatus: lockStatus,
      state: nextState,
      work: work,
      executeWrites: executeWrites,
      maxWrites: maxWrites,
      pageSize: pageSize,
      firestoreReads: stats.firestoreReads + Math.max(0, Number(tenant.firestoreReads || 0)) + work.firestoreReads,
      firestoreWrites: work.firestoreWrites,
      registryReads: Math.max(0, Number(tenant.registryReads || 0)),
      tenantId: tenant.tenantId,
      sourceReads: work.sourceReads,
      targetReads: work.targetReads,
      targetWrites: work.targetWrites,
      targetWritesExecuted: work.targetWritesExecuted,
      plannedTargetWrites: work.plannedTargetWrites,
      targetWritesSkippedSameSignature: work.targetWritesSkippedSameSignature,
      targetWritesSkippedInvalid: work.targetWritesSkippedInvalid,
      maxWritesReached: work.maxWritesReached,
      sourceScanExecuted: work.sourceReads > 0,
      targetScanExecuted: work.targetReads > 0,
      sourceCountsCollected: work.sourceReads > 0,
      targetCountsCollected: work.targetReads > 0,
      sourceSignatureComputed: work.sourceSignatureComputed,
      targetSignatureComputed: work.targetSignatureComputed,
      migrationSignatureComputed: work.migrationSignatureComputed,
      targetPathBuilt: work.targetPathBuilt,
      tenantTargetPathBuilt: work.tenantTargetPathBuilt,
      migrationStateRead: stats.migrationStateRead,
      migrationStateWritten: work.migrationStateWritten,
      checkpointWritten: work.migrationStateWritten,
      cursorAdvanced: work.cursorAdvanced,
      materializeStarted: true,
      materializeComplete: work.materializeComplete,
      preflightOk: true,
      dryRunOk: work.dryRunOk,
      blockingAnomalies: work.blockingAnomalies,
      nowIso: nowIso
    });
  } catch (e) {
    return buildMigration4MaterializeResult_({
      lockStatus: lockStatus,
      state: state,
      executeWrites: executeWrites,
      maxWrites: maxWrites,
      pageSize: pageSize,
      firestoreReads: stats.firestoreReads,
      firestoreWrites: 0,
      error: normalizeRuntimeErrorMessage_(e),
      errorKind: classifyRuntimeFailureKind_(e),
      preflightOk: false,
      blockingAnomalies: 1,
      nowIso: nowIso
    });
  }
}

function executeMigration4MaterializeWork_(cfg, api, state, options) {
  options = options || {};
  var work = buildMigration4MaterializeEmptyWork_();
  var cursor = normalizeMigration4MaterializeCursor_(state && state.lastCursor);
  var maxWrites = normalizeMigration4MaterializeMaxWrites_(options.maxWrites);
  var pageSize = normalizeMigration4MaterializePageSize_(options.pageSize);
  var executeWrites = options.executeWrites === true;
  var tenantId = String(options.tenantId || '').trim();
  var writes = [];
  var iterations = 0;

  work.cursorBefore = JSON.parse(JSON.stringify(cursor));

  while (work.targetWritesExecuted + writes.length < maxWrites && work.firestoreReads < PHBOX_M4_MATERIALIZE_MAX_READS_PER_RUN_) {
    iterations++;
    if (iterations > 200) throw new Error('M4_MATERIALIZE_LOOP_GUARD: troppe iterazioni nel batch. Checkpoint non avanzato.');
    if (shouldStopForBudget_(options.budget, 15000)) {
      work.stoppedForBudget = true;
      break;
    }

    if (cursor.phase === 'root') {
      var rootProgress = processMigration4MaterializeRootPage_(cfg, api, cursor, tenantId, {
        pageSize: pageSize,
        maxWrites: maxWrites,
        currentWrites: writes.length,
        executeWrites: executeWrites
      });
      work = mergeMigration4MaterializeWork_(work, rootProgress.work);
      writes = writes.concat(rootProgress.writes || []);
      cursor = rootProgress.cursor;
      if (rootProgress.stop) break;
      continue;
    }

    if (cursor.phase === 'patient_subcollections') {
      var subProgress = processMigration4MaterializePatientSubcollectionPage_(cfg, api, cursor, tenantId, {
        pageSize: pageSize,
        maxWrites: maxWrites,
        currentWrites: writes.length,
        executeWrites: executeWrites
      });
      work = mergeMigration4MaterializeWork_(work, subProgress.work);
      writes = writes.concat(subProgress.writes || []);
      cursor = subProgress.cursor;
      if (subProgress.stop) break;
      continue;
    }

    if (cursor.phase === 'complete') {
      work.materializeComplete = true;
      break;
    }

    throw new Error('M4_MATERIALIZE_CURSOR_PHASE_INVALID: fase cursor non riconosciuta.');
  }

  work.cursorAfter = JSON.parse(JSON.stringify(cursor));
  work.cursorAdvanced = JSON.stringify(work.cursorBefore) !== JSON.stringify(work.cursorAfter);
  work.maxWritesReached = writes.length >= maxWrites;
  work.plannedTargetWrites = writes.length;
  work.targetWrites = writes.length;

  if (executeWrites && writes.length > 0) {
    api.commit(writes);
    work.targetWritesExecuted = writes.length;
    work.firestoreWrites += writes.length;
  }

  work.dryRunOk = work.blockingAnomalies === 0;
  if (cursor.phase === 'complete') work.materializeComplete = true;
  return work;
}

function processMigration4MaterializeRootPage_(cfg, api, cursor, tenantId, options) {
  var work = buildMigration4MaterializeEmptyWork_();
  var writes = [];
  var collectionIndex = Math.max(0, Number(cursor.collectionIndex || 0));
  if (collectionIndex >= PHBOX_M4_MATERIALIZE_ROOT_COLLECTIONS_.length) {
    cursor.phase = 'patient_subcollections';
    cursor.collectionIndex = 0;
    cursor.pageToken = '';
    cursor.patientPageToken = '';
    cursor.currentPatientId = '';
    cursor.nextPatientPageToken = '';
    cursor.subcollectionIndex = 0;
    cursor.subcollectionPageToken = '';
    return { cursor: cursor, work: work, writes: writes, stop: false };
  }

  var collection = PHBOX_M4_MATERIALIZE_ROOT_COLLECTIONS_[collectionIndex];
  var listed = api.listDocuments(collection, cursor.pageToken || '', options.pageSize);
  work.firestoreReads += 1;
  work.sourceReads += (listed.documents || []).length;
  work.sourceCountsCollected = true;

  var pageResult = buildMigration4MaterializeWritesForDocs_(cfg, api, tenantId, listed.documents || [], {
    sourceCollectionPath: collection,
    targetCollectionPath: 'tenants/' + tenantId + '/' + collection,
    maxWrites: options.maxWrites,
    currentWrites: options.currentWrites,
    executeWrites: options.executeWrites
  });

  work = mergeMigration4MaterializeWork_(work, pageResult.work);
  writes = writes.concat(pageResult.writes || []);
  if (pageResult.pageCutShortForWriteBudget) {
    cursor.pageToken = String(cursor.pageToken || '');
  } else {
    cursor.pageToken = String(listed.nextPageToken || '');
    if (!cursor.pageToken) {
      cursor.collectionIndex = collectionIndex + 1;
      cursor.pageToken = '';
    }
  }

  return {
    cursor: cursor,
    work: work,
    writes: writes,
    stop: !!pageResult.pageCutShortForWriteBudget || !!cursor.pageToken || ((options.currentWrites + writes.length) >= options.maxWrites)
  };
}

function processMigration4MaterializePatientSubcollectionPage_(cfg, api, cursor, tenantId, options) {
  var work = buildMigration4MaterializeEmptyWork_();
  var writes = [];

  if (!cursor.currentPatientId) {
    var patientList = api.listDocuments('patients', cursor.patientPageToken || '', 1);
    work.firestoreReads += 1;
    work.sourceReads += (patientList.documents || []).length;
    work.sourceCountsCollected = true;
    if (!patientList.documents || patientList.documents.length === 0) {
      cursor.phase = 'complete';
      cursor.patientPageToken = '';
      cursor.currentPatientId = '';
      cursor.nextPatientPageToken = '';
      cursor.subcollectionIndex = 0;
      cursor.subcollectionPageToken = '';
      return { cursor: cursor, work: work, writes: writes, stop: false };
    }
    cursor.currentPatientId = extractFirestoreDocumentId_(patientList.documents[0].name || '');
    cursor.nextPatientPageToken = String(patientList.nextPageToken || '');
    cursor.subcollectionIndex = 0;
    cursor.subcollectionPageToken = '';
  }

  var subcollectionIndex = Math.max(0, Number(cursor.subcollectionIndex || 0));
  if (subcollectionIndex >= PHBOX_M4_MATERIALIZE_PATIENT_SUBCOLLECTIONS_.length) {
    cursor.currentPatientId = '';
    cursor.patientPageToken = String(cursor.nextPatientPageToken || '');
    cursor.nextPatientPageToken = '';
    cursor.subcollectionIndex = 0;
    cursor.subcollectionPageToken = '';
    if (!cursor.patientPageToken) {
      cursor.phase = 'complete';
    }
    return { cursor: cursor, work: work, writes: writes, stop: false };
  }

  var patientId = String(cursor.currentPatientId || '').trim();
  var subcollection = PHBOX_M4_MATERIALIZE_PATIENT_SUBCOLLECTIONS_[subcollectionIndex];
  var sourceCollectionPath = 'patients/' + patientId + '/' + subcollection;
  var targetCollectionPath = 'tenants/' + tenantId + '/patients/' + patientId + '/' + subcollection;
  var listed = api.listDocuments(sourceCollectionPath, cursor.subcollectionPageToken || '', options.pageSize);
  work.firestoreReads += 1;
  work.sourceReads += (listed.documents || []).length;
  work.sourceCountsCollected = true;

  var pageResult = buildMigration4MaterializeWritesForDocs_(cfg, api, tenantId, listed.documents || [], {
    sourceCollectionPath: sourceCollectionPath,
    targetCollectionPath: targetCollectionPath,
    maxWrites: options.maxWrites,
    currentWrites: options.currentWrites,
    executeWrites: options.executeWrites
  });

  work = mergeMigration4MaterializeWork_(work, pageResult.work);
  writes = writes.concat(pageResult.writes || []);
  if (pageResult.pageCutShortForWriteBudget) {
    cursor.subcollectionPageToken = String(cursor.subcollectionPageToken || '');
  } else {
    cursor.subcollectionPageToken = String(listed.nextPageToken || '');
    if (!cursor.subcollectionPageToken) {
      cursor.subcollectionIndex = subcollectionIndex + 1;
      cursor.subcollectionPageToken = '';
    }
  }

  return {
    cursor: cursor,
    work: work,
    writes: writes,
    stop: !!pageResult.pageCutShortForWriteBudget || !!cursor.subcollectionPageToken || ((options.currentWrites + writes.length) >= options.maxWrites)
  };
}

function buildMigration4MaterializeWritesForDocs_(cfg, api, tenantId, documents, options) {
  options = options || {};
  documents = documents || [];
  var work = buildMigration4MaterializeEmptyWork_();
  var writes = [];
  var pageCutShortForWriteBudget = false;

  for (var i = 0; i < documents.length; i++) {
    if ((options.currentWrites + writes.length) >= options.maxWrites) {
      pageCutShortForWriteBudget = true;
      break;
    }
    var sourceDoc = documents[i] || {};
    var sourcePath = extractMigration4MaterializeDocumentPath_(sourceDoc.name || '');
    var sourceId = extractFirestoreDocumentId_(sourceDoc.name || '');
    if (!sourcePath || !sourceId || sourcePath.indexOf('tenants/') === 0 || sourcePath.indexOf('migrations/') === 0) {
      work.blockingAnomalies += 1;
      work.targetWritesSkippedInvalid += 1;
      continue;
    }

    if (sourceId.indexOf('/') !== -1) { work.blockingAnomalies += 1; work.targetWritesSkippedInvalid += 1; continue; }
    var targetPath = String(options.targetCollectionPath || '').replace(/\/+$/, '') + '/' + sourceId;
    assertMigration4MaterializeTargetPath_(tenantId, targetPath);
    work.targetPathBuilt = true;
    work.tenantTargetPathBuilt = true;

    var sourceData = fromFirestoreFields_(sourceDoc.fields || {});
    var targetDoc = api.getDocument(targetPath);
    work.firestoreReads += 1;
    work.targetReads += 1;
    work.targetCountsCollected = true;

    var sourceSignature = computeMigration4MaterializeSignature_(sourceData);
    work.sourceSignatureComputed = true;
    var targetSignature = targetDoc ? computeMigration4MaterializeSignature_(fromFirestoreFields_(targetDoc.fields || {})) : '';
    if (targetDoc) work.targetSignatureComputed = true;
    work.migrationSignatureComputed = true;

    if (targetDoc && sourceSignature === targetSignature) {
      work.targetWritesSkippedSameSignature += 1;
      continue;
    }

    writes.push(buildMigration4MaterializeUpdateWriteFromPath_(cfg, targetPath, sourceData));
  }

  return { work: work, writes: writes, pageCutShortForWriteBudget: pageCutShortForWriteBudget };
}

function buildMigration4MaterializeResult_(data) {
  data = data || {};
  var lockStatus = data.lockStatus || null;
  var lockStats = (lockStatus && lockStatus.stats) || {};
  var state = normalizeMigration4MaterializeState_(data.state || null);
  var work = data.work || {};
  var violations = [];
  var preflightOk = Object.prototype.hasOwnProperty.call(data, 'preflightOk') ? !!data.preflightOk : true;
  var blockingAnomalies = Math.max(0, Number(data.blockingAnomalies || 0));

  if (!lockStatus || !lockStatus.stats) violations.push('m4_lock_status_missing');
  if (lockStatus && lockStatus.ok === false) violations.push('m4_lock_not_ok');
  if (String(lockStats.lockVersion || '') !== PHBOX_M4_MATERIALIZE_REQUIRED_LOCK_VERSION_) violations.push('lock_version_mismatch');
  if (String(lockStats.freezeVersion || '') !== PHBOX_M4_MATERIALIZE_REQUIRED_FREEZE_VERSION_) violations.push('freeze_version_mismatch');
  if (!lockStats.m4PlanAllowedNext) violations.push('m4_lock_does_not_authorize_materialize_preflight');
  if (lockStats.m4DryRunAllowedNext || lockStats.m4MaterializeAllowedNext || lockStats.m4VerifyAllowedNext || lockStats.m4CutoverAllowedNext || lockStats.m4FreezeAllowedNext) violations.push('m4_lock_authorizes_later_stage');
  if (Number(lockStats.firestoreReads || 0) !== 0 || Number(lockStats.firestoreWrites || 0) !== 0) violations.push('m4_lock_costs_not_zero');
  if (lockStats.targetPathBuilt || lockStats.sourceScanExecuted || lockStats.targetScanExecuted) violations.push('m4_lock_already_touched_source_or_target');
  if (data.error) violations.push('materialize_error');
  if (blockingAnomalies > 0) violations.push('blocking_anomalies_detected');
  if (data.destructiveOperationExecuted) violations.push('destructive_operation_detected');
  if (data.crossTenantLeakDetected) violations.push('cross_tenant_leak_detected');

  violations = uniqueNonEmptyStrings_(violations.concat(work.violations || []));
  if (violations.length > 0) preflightOk = false;

  var executeWrites = data.executeWrites === true;
  var targetWritesExecuted = Math.max(0, Number(data.targetWritesExecuted || 0));
  var plannedTargetWrites = Math.max(0, Number(data.plannedTargetWrites || 0));
  var materializeComplete = !!data.materializeComplete || String(state.status || '') === 'complete' || (state.lastCursor && state.lastCursor.phase === 'complete');
  var maxWritesReached = !!data.maxWritesReached;
  var reason = String(data.reason || '');

  if (!reason) {
    if (violations.length > 0) reason = 'm4_materialize_blocked';
    else if (materializeComplete) reason = 'm4_materialize_complete';
    else if (executeWrites && targetWritesExecuted > 0 && maxWritesReached) reason = 'm4_materialize_partial_max_writes_reached';
    else if (executeWrites && targetWritesExecuted > 0) reason = 'm4_materialize_batch_written';
    else if (executeWrites && plannedTargetWrites === 0) reason = 'm4_materialize_noop_batch';
    else reason = 'm4_materialize_ready';
  }

  var stats = {
    ok: violations.length === 0,
    skipped: !executeWrites || plannedTargetWrites === 0,
    reason: reason,
    materializeVersion: PHBOX_M4_MATERIALIZE_VERSION_,
    stage: PHBOX_M4_MATERIALIZE_STAGE_,
    requiredLockVersion: PHBOX_M4_MATERIALIZE_REQUIRED_LOCK_VERSION_,
    lockVersion: String(lockStats.lockVersion || ''),
    requiredFreezeVersion: PHBOX_M4_MATERIALIZE_REQUIRED_FREEZE_VERSION_,
    freezeVersion: String(lockStats.freezeVersion || ''),
    owner: PHBOX_M4_MATERIALIZE_OWNER_,
    runtimeOwner: PHBOX_M4_MATERIALIZE_RUNTIME_OWNER_,
    materializePolicy: PHBOX_M4_MATERIALIZE_POLICY_,
    materializeMode: PHBOX_M4_MATERIALIZE_MODE_,
    statePath: PHBOX_M4_MATERIALIZE_STATE_PATH_,
    status: String(state.status || (materializeComplete ? 'complete' : 'planned')),
    phase: String((state.lastCursor && state.lastCursor.phase) || 'root'),
    migrationId: String(state.migrationId || ''),
    tenantId: String(data.tenantId || state.tenantId || ''),
    executeWrites: executeWrites,
    preflightOk: preflightOk,
    dryRunOk: Object.prototype.hasOwnProperty.call(data, 'dryRunOk') ? !!data.dryRunOk : preflightOk,
    materializeStarted: !!data.materializeStarted || String(state.status || '') === 'running' || String(state.status || '') === 'partial' || materializeComplete,
    materializeComplete: materializeComplete,
    m4VerifyAllowedNext: materializeComplete && violations.length === 0,
    m4CutoverAllowedNext: false,
    m4FreezeAllowedNext: false,
    sourceCollections: PHBOX_M4_MATERIALIZE_ROOT_COLLECTIONS_.slice(),
    patientSubcollections: PHBOX_M4_MATERIALIZE_PATIENT_SUBCOLLECTIONS_.slice(),
    maxWrites: Math.max(0, Number(data.maxWrites || PHBOX_M4_MATERIALIZE_DEFAULT_MAX_WRITES_)),
    pageSize: Math.max(0, Number(data.pageSize || PHBOX_M4_MATERIALIZE_DEFAULT_PAGE_SIZE_)),
    plannedTargetWrites: plannedTargetWrites,
    targetWritesExecuted: targetWritesExecuted,
    cumulativeTargetWritesExecuted: Math.max(0, Number(state.targetWritesExecuted || 0)),
    targetWritesSkippedSameSignature: Math.max(0, Number(data.targetWritesSkippedSameSignature || 0)),
    targetWritesSkippedInvalid: Math.max(0, Number(data.targetWritesSkippedInvalid || 0)),
    maxWritesReached: maxWritesReached,
    firestoreReads: Math.max(0, Number(data.firestoreReads || 0)),
    firestoreWrites: Math.max(0, Number(data.firestoreWrites || 0)),
    estimatedReadsPerHour: 0,
    estimatedWritesPerHour: 0,
    registryReads: Math.max(0, Number(data.registryReads || 0)),
    registryWrites: 0,
    configReads: 0,
    configWrites: 0,
    sourceReads: Math.max(0, Number(data.sourceReads || 0)),
    sourceWrites: 0,
    targetReads: Math.max(0, Number(data.targetReads || 0)),
    targetWrites: Math.max(0, Number(data.targetWrites || 0)),
    listeners: 0,
    queries: 0,
    fanOut: 0,
    targetPathBuilt: !!data.targetPathBuilt,
    tenantTargetPathBuilt: !!data.tenantTargetPathBuilt,
    tenantConfigTouched: false,
    lifecycleTouched: false,
    tenantRoutingActive: false,
    tenantScopedReads: false,
    tenantScopedWrites: false,
    legacyRuntimeDisabled: false,
    legacySourceFrozen: false,
    backendRunStarted: false,
    triggerInstalled: false,
    sourceScanExecuted: !!data.sourceScanExecuted,
    targetScanExecuted: !!data.targetScanExecuted,
    sourceCountsCollected: !!data.sourceCountsCollected,
    targetCountsCollected: !!data.targetCountsCollected,
    sourceSignatureComputed: !!data.sourceSignatureComputed,
    targetSignatureComputed: !!data.targetSignatureComputed,
    migrationSignatureComputed: !!data.migrationSignatureComputed,
    blockingAnomalies: blockingAnomalies,
    blockingAnomaliesDetected: blockingAnomalies > 0,
    migrationStateRead: !!data.migrationStateRead,
    migrationStateWritten: !!data.migrationStateWritten,
    checkpointWritten: !!data.checkpointWritten,
    cursorAdvanced: !!data.cursorAdvanced,
    verifyStarted: false,
    cutoverStarted: false,
    schemaChanged: false,
    runtimeContractChanged: false,
    destructiveOperationExecuted: false,
    crossTenantLeakDetected: false,
    lastCursor: state.lastCursor || normalizeMigration4MaterializeCursor_(null),
    sourceSignature: String(state.sourceSignature || ''),
    targetSignature: String(state.targetSignature || ''),
    startedAt: String(state.startedAt || ''),
    updatedAt: String(state.updatedAt || ''),
    completedAt: String(state.completedAt || ''),
    violations: violations,
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };

  return { ok: !!stats.ok, stats: stats };
}

function buildMigration4MaterializeNextState_(state, work, options) {
  state = normalizeMigration4MaterializeState_(state);
  options = options || {};
  var nowIso = String(options.nowIso || new Date().toISOString());
  var totalWrites = Math.max(0, Number(state.targetWritesExecuted || 0)) + Math.max(0, Number(work.targetWritesExecuted || 0));
  var complete = !!work.materializeComplete || (work.cursorAfter && work.cursorAfter.phase === 'complete');
  var status = complete ? 'complete' : (work.targetWritesExecuted > 0 || work.cursorAdvanced ? 'partial' : 'running');
  var migrationId = state.migrationId || ('m4_materialize_' + nowIso.replace(/[^0-9]/g, '').substring(0, 14));
  return {
    status: status,
    migrationId: migrationId,
    tenantId: String(options.tenantId || state.tenantId || ''),
    phase: String((work.cursorAfter && work.cursorAfter.phase) || state.phase || 'root'),
    lastCursor: work.cursorAfter || state.lastCursor || normalizeMigration4MaterializeCursor_(null),
    sourceSignature: String(state.sourceSignature || ''),
    targetSignature: String(state.targetSignature || ''),
    plannedTargetWrites: Math.max(0, Number(state.plannedTargetWrites || 0)) + Math.max(0, Number(work.plannedTargetWrites || 0)),
    targetWritesExecuted: totalWrites,
    maxWritesReached: !!work.maxWritesReached,
    startedAt: state.startedAt || nowIso,
    updatedAt: nowIso,
    completedAt: complete ? nowIso : '',
    errorKind: '',
    errorMessage: ''
  };
}

function buildMigration4MaterializeEmptyWork_() {
  return {
    firestoreReads: 0,
    firestoreWrites: 0,
    sourceReads: 0,
    targetReads: 0,
    targetWrites: 0,
    plannedTargetWrites: 0,
    targetWritesExecuted: 0,
    targetWritesSkippedSameSignature: 0,
    targetWritesSkippedInvalid: 0,
    maxWritesReached: false,
    stoppedForBudget: false,
    targetPathBuilt: false,
    tenantTargetPathBuilt: false,
    sourceCountsCollected: false,
    targetCountsCollected: false,
    sourceSignatureComputed: false,
    targetSignatureComputed: false,
    migrationSignatureComputed: false,
    blockingAnomalies: 0,
    migrationStateWritten: false,
    cursorAdvanced: false,
    materializeComplete: false,
    dryRunOk: true,
    violations: []
  };
}

function mergeMigration4MaterializeWork_(a, b) {
  a = a || buildMigration4MaterializeEmptyWork_();
  b = b || {};
  a.firestoreReads += Math.max(0, Number(b.firestoreReads || 0));
  a.firestoreWrites += Math.max(0, Number(b.firestoreWrites || 0));
  a.sourceReads += Math.max(0, Number(b.sourceReads || 0));
  a.targetReads += Math.max(0, Number(b.targetReads || 0));
  a.targetWrites += Math.max(0, Number(b.targetWrites || 0));
  a.plannedTargetWrites += Math.max(0, Number(b.plannedTargetWrites || 0));
  a.targetWritesExecuted += Math.max(0, Number(b.targetWritesExecuted || 0));
  a.targetWritesSkippedSameSignature += Math.max(0, Number(b.targetWritesSkippedSameSignature || 0));
  a.targetWritesSkippedInvalid += Math.max(0, Number(b.targetWritesSkippedInvalid || 0));
  a.blockingAnomalies += Math.max(0, Number(b.blockingAnomalies || 0));
  a.maxWritesReached = !!a.maxWritesReached || !!b.maxWritesReached;
  a.stoppedForBudget = !!a.stoppedForBudget || !!b.stoppedForBudget;
  a.targetPathBuilt = !!a.targetPathBuilt || !!b.targetPathBuilt;
  a.tenantTargetPathBuilt = !!a.tenantTargetPathBuilt || !!b.tenantTargetPathBuilt;
  a.sourceCountsCollected = !!a.sourceCountsCollected || !!b.sourceCountsCollected;
  a.targetCountsCollected = !!a.targetCountsCollected || !!b.targetCountsCollected;
  a.sourceSignatureComputed = !!a.sourceSignatureComputed || !!b.sourceSignatureComputed;
  a.targetSignatureComputed = !!a.targetSignatureComputed || !!b.targetSignatureComputed;
  a.migrationSignatureComputed = !!a.migrationSignatureComputed || !!b.migrationSignatureComputed;
  a.migrationStateWritten = !!a.migrationStateWritten || !!b.migrationStateWritten;
  a.cursorAdvanced = !!a.cursorAdvanced || !!b.cursorAdvanced;
  a.materializeComplete = !!a.materializeComplete || !!b.materializeComplete;
  a.dryRunOk = a.dryRunOk !== false && b.dryRunOk !== false;
  a.violations = uniqueNonEmptyStrings_((a.violations || []).concat(b.violations || []));
  return a;
}

function buildMigration4MaterializeFirestoreApi_(cfg) {
  cfg = cfg || getPhboxConfig_();
  return {
    listDocuments: function (collectionPath, pageToken, pageSize) {
      return listMigration4MaterializeFirestoreDocuments_(cfg, collectionPath, pageToken, pageSize);
    },
    getDocument: function (documentPath) {
      return getMigration4MaterializeFirestoreDocument_(cfg, documentPath);
    },
    commit: function (writes) {
      executeFirestoreCommit_(cfg, writes || []);
    }
  };
}

function listMigration4MaterializeFirestoreDocuments_(cfg, collectionPath, pageToken, pageSize) {
  var url = buildMigration4MaterializeFirestoreDocumentsUrl_(cfg, collectionPath) + '?pageSize=' + encodeURIComponent(String(normalizeMigration4MaterializePageSize_(pageSize)));
  if (pageToken) url += '&pageToken=' + encodeURIComponent(String(pageToken || ''));
  var response = UrlFetchApp.fetch(url, {
    method: 'get',
    muteHttpExceptions: true,
    headers: { Authorization: 'Bearer ' + ScriptApp.getOAuthToken() }
  });
  var code = response.getResponseCode();
  var body = response.getContentText() || '';
  if (code === 404) return { documents: [], nextPageToken: '' };
  if (code < 200 || code >= 300) throw new Error('M4_MATERIALIZE_LIST_FAILED [' + code + '] ' + body);
  var parsed = parseJsonSafe_(body) || {};
  return {
    documents: Array.isArray(parsed.documents) ? parsed.documents : [],
    nextPageToken: String(parsed.nextPageToken || '')
  };
}

function getMigration4MaterializeFirestoreDocument_(cfg, documentPath) {
  var url = buildMigration4MaterializeFirestoreDocumentsUrl_(cfg, documentPath);
  var response = UrlFetchApp.fetch(url, {
    method: 'get',
    muteHttpExceptions: true,
    headers: { Authorization: 'Bearer ' + ScriptApp.getOAuthToken() }
  });
  var code = response.getResponseCode();
  var body = response.getContentText() || '';
  if (code === 404) return null;
  if (code < 200 || code >= 300) throw new Error('M4_MATERIALIZE_GET_FAILED [' + code + '] ' + body);
  return parseJsonSafe_(body) || null;
}

function buildMigration4MaterializeFirestoreDocumentsUrl_(cfg, path) {
  return 'https://firestore.googleapis.com/v1/projects/' + encodeURIComponent(cfg.firestoreProjectId) + '/databases/(default)/documents/' + encodeFirestorePathSegments_(path);
}

function encodeFirestorePathSegments_(path) {
  return String(path || '').split('/').map(function (segment) {
    return encodeURIComponent(decodeURIComponent(String(segment || '')));
  }).join('/');
}

function buildMigration4MaterializeUpdateWriteFromPath_(cfg, documentPath, data) {
  return {
    update: {
      name: 'projects/' + cfg.firestoreProjectId + '/databases/(default)/documents/' + documentPath,
      fields: toFirestoreFields_(data || {})
    }
  };
}

function readMigration4MaterializeState_(api) {
  var doc = api.getDocument(PHBOX_M4_MATERIALIZE_STATE_PATH_);
  if (!doc || !doc.fields) return normalizeMigration4MaterializeState_(null);
  return normalizeMigration4MaterializeState_(fromFirestoreFields_(doc.fields || {}));
}

function writeMigration4MaterializeState_(api, state, cfg) {
  cfg = cfg || getPhboxConfig_();
  api.commit([buildMigration4MaterializeUpdateWriteFromPath_(cfg, PHBOX_M4_MATERIALIZE_STATE_PATH_, normalizeMigration4MaterializeState_(state))]);
}

function normalizeMigration4MaterializeState_(state) {
  state = state || {};
  return {
    status: String(state.status || 'planned'),
    migrationId: String(state.migrationId || ''),
    tenantId: String(state.tenantId || ''),
    phase: String(state.phase || (state.lastCursor && state.lastCursor.phase) || 'root'),
    lastCursor: normalizeMigration4MaterializeCursor_(state.lastCursor),
    sourceSignature: String(state.sourceSignature || ''),
    targetSignature: String(state.targetSignature || ''),
    plannedTargetWrites: Math.max(0, Number(state.plannedTargetWrites || 0)),
    targetWritesExecuted: Math.max(0, Number(state.targetWritesExecuted || 0)),
    maxWritesReached: !!state.maxWritesReached,
    startedAt: String(state.startedAt || ''),
    updatedAt: String(state.updatedAt || ''),
    completedAt: String(state.completedAt || ''),
    errorKind: String(state.errorKind || ''),
    errorMessage: String(state.errorMessage || '')
  };
}

function normalizeMigration4MaterializeCursor_(cursor) {
  cursor = cursor || {};
  var phase = String(cursor.phase || 'root');
  if (phase !== 'root' && phase !== 'patient_subcollections' && phase !== 'complete') phase = 'root';
  return {
    phase: phase,
    collectionIndex: Math.max(0, Number(cursor.collectionIndex || 0)),
    pageToken: String(cursor.pageToken || ''),
    patientPageToken: String(cursor.patientPageToken || ''),
    currentPatientId: String(cursor.currentPatientId || ''),
    nextPatientPageToken: String(cursor.nextPatientPageToken || ''),
    subcollectionIndex: Math.max(0, Number(cursor.subcollectionIndex || 0)),
    subcollectionPageToken: String(cursor.subcollectionPageToken || '')
  };
}

function resolveMigration4MaterializeTenant_(api, props) {
  props = props || PropertiesService.getScriptProperties();
  var explicitTenantId = String(props.getProperty('PHBOX_TENANT_ID') || '').trim();
  var expectedTenantId = String(props.getProperty('PHBOX_EXPECTED_CANONICAL_TENANT_ID') || '').trim();
  if (explicitTenantId && expectedTenantId && explicitTenantId !== expectedTenantId) {
    throw new Error('M4_MATERIALIZE_TENANT_MISMATCH: tenantId non allineato al canonical expected tenant. Nessuna write target eseguita.');
  }

  if (api && typeof api.listDocuments === 'function') {
    var registry = api.listDocuments(PHBOX_M4_MATERIALIZE_TENANTS_COLLECTION_, '', 2);
    var docs = (registry && registry.documents) || [];
    if (docs.length === 1) {
      var tenantId = extractFirestoreDocumentId_(docs[0].name || '');
      assertMigration4MaterializeCanonicalTenantId_(tenantId);
      if (explicitTenantId && explicitTenantId !== tenantId) {
        throw new Error('M4_MATERIALIZE_TENANT_REGISTRY_MISMATCH: Script Properties tenant diverso dal tenant registry Firestore. Nessuna write target eseguita.');
      }
      if (expectedTenantId && expectedTenantId !== tenantId) {
        throw new Error('M4_MATERIALIZE_EXPECTED_TENANT_REGISTRY_MISMATCH: expected tenant diverso dal tenant registry Firestore. Nessuna write target eseguita.');
      }
      return {
        tenantId: tenantId,
        expectedTenantId: expectedTenantId || tenantId,
        tenantSource: 'firestore_tenants_registry',
        firestoreReads: 1,
        registryReads: 1
      };
    }
    if (docs.length > 1) {
      throw new Error('M4_MATERIALIZE_TENANT_REGISTRY_AMBIGUOUS: trovati più tenant nel registry Firestore. Nessuna write target eseguita.');
    }
  }

  if (!explicitTenantId) throw new Error('M4_MATERIALIZE_TENANT_MISSING: nessun tenant nel registry Firestore e PHBOX_TENANT_ID mancante. Nessuna write target eseguita.');
  assertMigration4MaterializeCanonicalTenantId_(explicitTenantId);
  if (expectedTenantId) assertMigration4MaterializeCanonicalTenantId_(expectedTenantId);
  return {
    tenantId: explicitTenantId,
    expectedTenantId: expectedTenantId || explicitTenantId,
    tenantSource: 'script_properties_fallback',
    firestoreReads: 0,
    registryReads: 0
  };
}

function assertMigration4MaterializeCanonicalTenantId_(tenantId) {
  var value = String(tenantId || '').trim();
  if (!value) throw new Error('M4_MATERIALIZE_TENANT_EMPTY: tenantId vuoto. Nessuna write target eseguita.');
  if (value !== String(tenantId || '')) throw new Error('M4_MATERIALIZE_TENANT_NOT_CANONICAL: tenantId contiene spazi iniziali/finali. Nessuna write target eseguita.');
  if (value.indexOf('/') !== -1) throw new Error('M4_MATERIALIZE_TENANT_NOT_CANONICAL: tenantId contiene slash. Nessuna write target eseguita.');
  if (value.indexOf(' ') !== -1) throw new Error('M4_MATERIALIZE_TENANT_NOT_CANONICAL: tenantId contiene spazi. Nessuna write target eseguita.');
}

function assertMigration4MaterializeTargetPath_(tenantId, targetPath) {
  var expectedPrefix = 'tenants/' + String(tenantId || '').trim() + '/';
  var path = String(targetPath || '').trim();
  if (path.indexOf(expectedPrefix) !== 0) throw new Error('M4_MATERIALIZE_TARGET_PATH_OUT_OF_TENANT: target path fuori tenant. Nessuna write eseguita.');
  if (path.indexOf('/tenants/') !== -1) throw new Error('M4_MATERIALIZE_DOUBLE_TENANT_PATH: target path contiene tenants annidato. Nessuna write eseguita.');
}

function extractMigration4MaterializeDocumentPath_(documentName) {
  var name = String(documentName || '').trim();
  var marker = '/documents/';
  var index = name.indexOf(marker);
  if (index === -1) return '';
  return name.substring(index + marker.length);
}

function computeMigration4MaterializeSignature_(data) {
  return computeStableHashForData_(normalizeMigration4MaterializeForSignature_(data));
}

function normalizeMigration4MaterializeForSignature_(value) {
  if (value === null || value === undefined) return null;
  if (Array.isArray(value)) {
    return value.map(function (item) { return normalizeMigration4MaterializeForSignature_(item); });
  }
  if (typeof value === 'object') {
    var out = {};
    Object.keys(value).sort().forEach(function (key) {
      out[key] = normalizeMigration4MaterializeForSignature_(value[key]);
    });
    return out;
  }
  return value;
}

function normalizeMigration4MaterializeMaxWrites_(value) {
  var n = parseInt(String(value || ''), 10);
  if (isNaN(n) || n <= 0) n = PHBOX_M4_MATERIALIZE_DEFAULT_MAX_WRITES_;
  return Math.max(1, Math.min(100, n));
}

function normalizeMigration4MaterializePageSize_(value) {
  var n = parseInt(String(value || ''), 10);
  if (isNaN(n) || n <= 0) n = PHBOX_M4_MATERIALIZE_DEFAULT_PAGE_SIZE_;
  return Math.max(1, Math.min(PHBOX_M4_MATERIALIZE_MAX_PAGE_SIZE_, n));
}

function readMigration4MaterializeMaxWrites_(props) {
  props = props || PropertiesService.getScriptProperties();
  return normalizeMigration4MaterializeMaxWrites_(props.getProperty('PHBOX_M4_MATERIALIZE_MAX_WRITES'));
}

function readMigration4MaterializePageSize_(props) {
  props = props || PropertiesService.getScriptProperties();
  return normalizeMigration4MaterializePageSize_(props.getProperty('PHBOX_M4_MATERIALIZE_PAGE_SIZE'));
}

function runMigration4MaterializeSelfTest_() {
  var cfg = { firestoreProjectId: 'phbox-test-project' };
  var cases = buildMigration4MaterializeSelfTestCases_(cfg);
  var passed = 0;
  var failed = 0;
  var items = cases.map(function (testCase) {
    var result = testCase.run();
    var mismatches = compareMigration4MaterializeExpected_(result.stats || {}, testCase.expected || {});
    var ok = mismatches.length === 0;
    if (ok) passed++; else failed++;
    return { id: testCase.id, passed: ok, mismatchReasons: mismatches, expected: testCase.expected, actual: result.stats || {} };
  });
  return {
    ok: failed === 0,
    materializeVersion: PHBOX_M4_MATERIALIZE_VERSION_,
    stage: PHBOX_M4_MATERIALIZE_STAGE_,
    passedCount: passed,
    failedCount: failed,
    items: items
  };
}

function buildMigration4MaterializeSelfTestCases_(cfg) {
  var props = createMigration4MaterializeTestProperties_({ PHBOX_TENANT_ID: 'farmacia_santa_venera', PHBOX_EXPECTED_CANONICAL_TENANT_ID: 'farmacia_santa_venera' });
  var cleanLock = buildMigration4MaterializeSyntheticLockStatus_({});
  return [
    {
      id: 'blocks_missing_lock',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: null, state: {}, firestoreApi: createMigration4MaterializeFakeApi_({}), props: props, executeWrites: true }); },
      expected: { ok: false, violationContains: 'm4_lock_status_missing', targetWritesExecuted: 0 }
    },
    {
      id: 'blocks_failed_lock',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: buildMigration4MaterializeSyntheticLockStatus_({ ok: false }), state: {}, firestoreApi: createMigration4MaterializeFakeApi_({}), props: props, executeWrites: true }); },
      expected: { ok: false, violationContains: 'm4_lock_not_ok', targetWritesExecuted: 0 }
    },
    {
      id: 'blocks_wrong_lock_version',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: buildMigration4MaterializeSyntheticLockStatus_({ lockVersion: 'M4_LOCK_OLD' }), state: {}, firestoreApi: createMigration4MaterializeFakeApi_({}), props: props, executeWrites: true }); },
      expected: { ok: false, violationContains: 'lock_version_mismatch', targetWritesExecuted: 0 }
    },
    {
      id: 'blocks_missing_tenant',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: {}, firestoreApi: createMigration4MaterializeFakeApi_({}), props: createMigration4MaterializeTestProperties_({}), executeWrites: true }); },
      expected: { ok: false, violationContains: 'materialize_error', targetWritesExecuted: 0 }
    },

    {
      id: 'resolves_db_owned_tenant_from_tenants_collection',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: {}, firestoreApi: createMigration4MaterializeFakeApi_({ source: { tenants: [{ id: 'farmacia-santa-venera-8xnoc', data: { name: 'Farmacia Santa Venera' } }], patients: [{ id: 'A', data: { id: 'A' } }] } }), props: createMigration4MaterializeTestProperties_({}), executeWrites: true, maxWrites: 5 }); },
      expected: { ok: true, tenantId: 'farmacia-santa-venera-8xnoc', registryReads: 1, targetWritesExecuted: 1 }
    },
    {
      id: 'blocks_ambiguous_db_owned_tenant_registry',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: {}, firestoreApi: createMigration4MaterializeFakeApi_({ source: { tenants: [{ id: 'tenant-a', data: {} }, { id: 'tenant-b', data: {} }] } }), props: createMigration4MaterializeTestProperties_({}), executeWrites: true }); },
      expected: { ok: false, violationContains: 'materialize_error', targetWritesExecuted: 0 }
    },
    {
      id: 'writes_missing_target_patient',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: {}, firestoreApi: createMigration4MaterializeFakeApi_({ source: { patients: [{ id: 'RSSMRA80A01H501U', data: { id: 'RSSMRA80A01H501U', name: 'Mario Rossi' } }] } }), props: props, executeWrites: true, maxWrites: 5 }); },
      expected: { ok: true, targetWritesExecuted: 1, targetPathBuilt: true, tenantTargetPathBuilt: true, sourceWrites: 0 }
    },
    {
      id: 'skips_same_signature_target',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: {}, firestoreApi: createMigration4MaterializeFakeApi_({ source: { patients: [{ id: 'A', data: { id: 'A', name: 'A' } }] }, target: { 'tenants/farmacia_santa_venera/patients/A': { id: 'A', name: 'A' } } }), props: props, executeWrites: true, maxWrites: 5 }); },
      expected: { ok: true, targetWritesExecuted: 0, targetWritesSkippedSameSignature: 1 }
    },
    {
      id: 'updates_different_signature_target',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: {}, firestoreApi: createMigration4MaterializeFakeApi_({ source: { patients: [{ id: 'A', data: { id: 'A', name: 'New' } }] }, target: { 'tenants/farmacia_santa_venera/patients/A': { id: 'A', name: 'Old' } } }), props: props, executeWrites: true, maxWrites: 5 }); },
      expected: { ok: true, targetWritesExecuted: 1, targetWritesSkippedSameSignature: 0 }
    },
    {
      id: 'dryrun_plans_without_commit',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: {}, firestoreApi: createMigration4MaterializeFakeApi_({ source: { patients: [{ id: 'A', data: { id: 'A' } }] } }), props: props, executeWrites: false, maxWrites: 5 }); },
      expected: { ok: true, plannedTargetWrites: 1, targetWritesExecuted: 0, dryRunOk: true }
    },
    {
      id: 'max_writes_reached_partial',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: {}, firestoreApi: createMigration4MaterializeFakeApi_({ source: { patients: [{ id: 'A', data: { id: 'A' } }, { id: 'B', data: { id: 'B' } }] } }), props: props, executeWrites: true, maxWrites: 1 }); },
      expected: { ok: true, targetWritesExecuted: 1, maxWritesReached: true }
    },
    {
      id: 'preserves_root_cursor_when_write_budget_cuts_page_short',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: {}, firestoreApi: createMigration4MaterializeFakeApi_({ source: { patients: [{ id: 'A', data: { id: 'A' } }, { id: 'B', data: { id: 'B' } }] } }), props: props, executeWrites: true, maxWrites: 1, pageSize: 20 }); },
      expected: { ok: true, targetWritesExecuted: 1, maxWritesReached: true, lastCursorPhase: 'root', lastCursorCollectionIndex: 0, lastCursorPageToken: '' }
    },
    {
      id: 'root_cursor_converges_after_refetching_cut_page',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: { lastCursor: { phase: 'root', collectionIndex: 0, pageToken: '' } }, firestoreApi: createMigration4MaterializeFakeApi_({ source: { patients: [{ id: 'A', data: { id: 'A' } }, { id: 'B', data: { id: 'B' } }] }, target: { 'tenants/farmacia_santa_venera/patients/A': { id: 'A' } } }), props: props, executeWrites: true, maxWrites: 1, pageSize: 20 }); },
      expected: { ok: true, targetWritesExecuted: 1, targetWritesSkippedSameSignature: 1, lastCursorPhase: 'root', lastCursorCollectionIndex: 1, lastCursorPageToken: '' }
    },
    {
      id: 'preserves_subcollection_cursor_when_write_budget_cuts_page_short',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: { lastCursor: { phase: 'patient_subcollections', currentPatientId: 'CF1', nextPatientPageToken: '', subcollectionIndex: 0, subcollectionPageToken: '' } }, firestoreApi: createMigration4MaterializeFakeApi_({ source: { 'patients/CF1/debts': [{ id: 'D1', data: { id: 'D1' } }, { id: 'D2', data: { id: 'D2' } }] } }), props: props, executeWrites: true, maxWrites: 1, pageSize: 20 }); },
      expected: { ok: true, targetWritesExecuted: 1, maxWritesReached: true, lastCursorPhase: 'patient_subcollections', lastCursorCurrentPatientId: 'CF1', lastCursorSubcollectionIndex: 0, lastCursorSubcollectionPageToken: '' }
    },
    {
      id: 'materializes_doctor_links_path',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: { lastCursor: { phase: 'root', collectionIndex: 1 } }, firestoreApi: createMigration4MaterializeFakeApi_({ source: { doctor_patient_links: [{ id: 'CF__primary', data: { id: 'CF__primary' } }] } }), props: props, executeWrites: true, maxWrites: 5 }); },
      expected: { ok: true, targetWritesExecuted: 1, targetPathBuilt: true }
    },
    {
      id: 'materializes_families_path',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: { lastCursor: { phase: 'root', collectionIndex: 2 } }, firestoreApi: createMigration4MaterializeFakeApi_({ source: { families: [{ id: 'fam1', data: { id: 'fam1' } }] } }), props: props, executeWrites: true, maxWrites: 5 }); },
      expected: { ok: true, targetWritesExecuted: 1 }
    },
    {
      id: 'materializes_dashboard_index_path',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: { lastCursor: { phase: 'root', collectionIndex: 3 } }, firestoreApi: createMigration4MaterializeFakeApi_({ source: { patient_dashboard_index: [{ id: 'CF', data: { id: 'CF' } }] } }), props: props, executeWrites: true, maxWrites: 5 }); },
      expected: { ok: true, targetWritesExecuted: 1 }
    },
    {
      id: 'materializes_dashboard_totals_path',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: { lastCursor: { phase: 'root', collectionIndex: 4 } }, firestoreApi: createMigration4MaterializeFakeApi_({ source: { dashboard_totals: [{ id: 'main', data: { id: 'main' } }] } }), props: props, executeWrites: true, maxWrites: 5 }); },
      expected: { ok: true, targetWritesExecuted: 1 }
    },
    {
      id: 'materializes_drive_imports_path',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: { lastCursor: { phase: 'root', collectionIndex: 5 } }, firestoreApi: createMigration4MaterializeFakeApi_({ source: { drive_pdf_imports: [{ id: 'file1', data: { id: 'file1' } }] } }), props: props, executeWrites: true, maxWrites: 5 }); },
      expected: { ok: true, targetWritesExecuted: 1 }
    },
    {
      id: 'materializes_patient_subcollection_path',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: { lastCursor: { phase: 'patient_subcollections' } }, firestoreApi: createMigration4MaterializeFakeApi_({ source: { patients: [{ id: 'CF1', data: { id: 'CF1' } }], 'patients/CF1/debts': [{ id: 'debt1', data: { id: 'debt1' } }] } }), props: props, executeWrites: true, maxWrites: 5 }); },
      expected: { ok: true, targetWritesExecuted: 1, targetPathBuilt: true }
    },
    {
      id: 'completes_when_no_more_patients',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: { lastCursor: { phase: 'patient_subcollections' } }, firestoreApi: createMigration4MaterializeFakeApi_({ source: { patients: [] } }), props: props, executeWrites: true, maxWrites: 5 }); },
      expected: { ok: true, materializeComplete: true, m4VerifyAllowedNext: true }
    },
    {
      id: 'writes_checkpoint_state',
      run: function () { var saved = null; return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: {}, firestoreApi: createMigration4MaterializeFakeApi_({ source: { patients: [{ id: 'A', data: { id: 'A' } }] } }), saveStateFn: function (state) { saved = state; }, props: props, executeWrites: true, maxWrites: 5 }); },
      expected: { ok: true, migrationStateWritten: true, checkpointWritten: true }
    },
    {
      id: 'never_disables_legacy_runtime',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: {}, firestoreApi: createMigration4MaterializeFakeApi_({}), props: props, executeWrites: true }); },
      expected: { ok: true, legacyRuntimeDisabled: false, destructiveOperationExecuted: false }
    },
    {
      id: 'never_starts_cutover_or_verify',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: {}, firestoreApi: createMigration4MaterializeFakeApi_({}), props: props, executeWrites: true }); },
      expected: { ok: true, verifyStarted: false, cutoverStarted: false }
    },
    {
      id: 'keeps_schema_contract_unchanged',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: {}, firestoreApi: createMigration4MaterializeFakeApi_({}), props: props, executeWrites: true }); },
      expected: { ok: true, schemaChanged: false, runtimeContractChanged: false }
    },
    {
      id: 'source_reads_are_bounded',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: {}, firestoreApi: createMigration4MaterializeFakeApi_({ source: { patients: [{ id: 'A', data: { id: 'A' } }] } }), props: props, executeWrites: true, maxWrites: 1, pageSize: 1 }); },
      expected: { ok: true, sourceReadsMax: 1 }
    }
  ];
}

function createMigration4MaterializeFakeApi_(data) {
  data = data || {};
  var source = data.source || {};
  var target = data.target || {};
  var commits = [];
  return {
    listDocuments: function (collectionPath, pageToken, pageSize) {
      var key = decodeURIComponent(String(collectionPath || ''));
      var docs = (source[key] || []).slice();
      var start = Math.max(0, Number(pageToken || 0));
      var end = Math.min(docs.length, start + normalizeMigration4MaterializePageSize_(pageSize));
      var page = docs.slice(start, end).map(function (doc) {
        return buildMigration4MaterializeFakeDoc_(cfgPathProject_(), key, doc.id, doc.data || {});
      });
      return { documents: page, nextPageToken: end < docs.length ? String(end) : '' };
    },
    getDocument: function (documentPath) {
      var data = target[decodeURIComponent(String(documentPath || ''))];
      if (!data) return null;
      return buildMigration4MaterializeFakeDoc_(cfgPathProject_(), decodeURIComponent(String(documentPath || '')).split('/').slice(0, -1).join('/'), decodeURIComponent(String(documentPath || '')).split('/').pop(), data);
    },
    commit: function (writes) { commits.push.apply(commits, writes || []); },
    commits: commits
  };
}

function cfgPathProject_() {
  return 'phbox-test-project';
}

function buildMigration4MaterializeFakeDoc_(projectId, collectionPath, documentId, data) {
  return {
    name: 'projects/' + projectId + '/databases/(default)/documents/' + collectionPath + '/' + documentId,
    fields: toFirestoreFields_(data || {})
  };
}

function createMigration4MaterializeTestProperties_(values) {
  values = values || {};
  return {
    getProperty: function (name) { return Object.prototype.hasOwnProperty.call(values, name) ? values[name] : ''; }
  };
}

function buildMigration4MaterializeSyntheticLockStatus_(overrides) {
  overrides = overrides || {};
  var stats = {
    ok: true,
    lockVersion: PHBOX_M4_MATERIALIZE_REQUIRED_LOCK_VERSION_,
    freezeVersion: PHBOX_M4_MATERIALIZE_REQUIRED_FREEZE_VERSION_,
    m4PlanAllowedNext: true,
    m4DryRunAllowedNext: false,
    m4MaterializeAllowedNext: false,
    m4VerifyAllowedNext: false,
    m4CutoverAllowedNext: false,
    m4FreezeAllowedNext: false,
    firestoreReads: 0,
    firestoreWrites: 0,
    targetPathBuilt: false,
    sourceScanExecuted: false,
    targetScanExecuted: false
  };
  Object.keys(overrides).forEach(function (key) { stats[key] = overrides[key]; });
  return { ok: stats.ok !== false, stats: stats };
}

function compareMigration4MaterializeExpected_(actual, expected) {
  var mismatches = [];
  Object.keys(expected || {}).forEach(function (key) {
    if (key === 'violationContains') {
      var expectedViolation = String(expected[key] || '');
      if (expectedViolation && (actual.violations || []).indexOf(expectedViolation) === -1) mismatches.push('missing_violation_' + expectedViolation);
      return;
    }
    if (key === 'sourceReadsMax') {
      if (Number(actual.sourceReads || 0) > Number(expected[key] || 0)) mismatches.push('source_reads_over_expected_max');
      return;
    }
    if (key === 'lastCursorPhase') {
      if (String((actual.lastCursor && actual.lastCursor.phase) || '') !== String(expected[key] || '')) mismatches.push('last_cursor_phase_expected_' + expected[key] + '_actual_' + String((actual.lastCursor && actual.lastCursor.phase) || ''));
      return;
    }
    if (key === 'lastCursorCollectionIndex') {
      if (Number((actual.lastCursor && actual.lastCursor.collectionIndex) || 0) !== Number(expected[key] || 0)) mismatches.push('last_cursor_collection_index_expected_' + expected[key] + '_actual_' + Number((actual.lastCursor && actual.lastCursor.collectionIndex) || 0));
      return;
    }
    if (key === 'lastCursorPageToken') {
      if (String((actual.lastCursor && actual.lastCursor.pageToken) || '') !== String(expected[key] || '')) mismatches.push('last_cursor_page_token_expected_' + expected[key] + '_actual_' + String((actual.lastCursor && actual.lastCursor.pageToken) || ''));
      return;
    }
    if (key === 'lastCursorCurrentPatientId') {
      if (String((actual.lastCursor && actual.lastCursor.currentPatientId) || '') !== String(expected[key] || '')) mismatches.push('last_cursor_current_patient_id_expected_' + expected[key] + '_actual_' + String((actual.lastCursor && actual.lastCursor.currentPatientId) || ''));
      return;
    }
    if (key === 'lastCursorSubcollectionIndex') {
      if (Number((actual.lastCursor && actual.lastCursor.subcollectionIndex) || 0) !== Number(expected[key] || 0)) mismatches.push('last_cursor_subcollection_index_expected_' + expected[key] + '_actual_' + Number((actual.lastCursor && actual.lastCursor.subcollectionIndex) || 0));
      return;
    }
    if (key === 'lastCursorSubcollectionPageToken') {
      if (String((actual.lastCursor && actual.lastCursor.subcollectionPageToken) || '') !== String(expected[key] || '')) mismatches.push('last_cursor_subcollection_page_token_expected_' + expected[key] + '_actual_' + String((actual.lastCursor && actual.lastCursor.subcollectionPageToken) || ''));
      return;
    }
    if (actual[key] !== expected[key]) mismatches.push(key + '_expected_' + expected[key] + '_actual_' + actual[key]);
  });
  return mismatches;
}

function formatMigration4MaterializeSelfTestFeedback_(result) {
  result = result || {};
  var lines = [];
  lines.push('MIGRATION_4_MATERIALIZE_SELF_TEST');
  lines.push('ok=' + String(!!result.ok));
  lines.push('materializeVersion=' + String(result.materializeVersion || PHBOX_M4_MATERIALIZE_VERSION_));
  lines.push('stage=' + String(result.stage || PHBOX_M4_MATERIALIZE_STAGE_));
  lines.push('passedCount=' + String(result.passedCount || 0));
  lines.push('failedCount=' + String(result.failedCount || 0));
  (result.items || []).forEach(function (item) {
    lines.push('- ' + item.id + ': ' + (item.passed ? 'PASS' : 'FAIL'));
    if (!item.passed) lines.push('  mismatches=' + (item.mismatchReasons || []).join(','));
  });
  return lines.join('\n');
}

function formatMigration4MaterializeRuntimeFeedback_(result) {
  var stats = (result && result.stats) || {};
  var lines = [];
  lines.push('MIGRATION_4_MATERIALIZE_RUNTIME_STATUS');
  ['ok','reason','materializeVersion','stage','requiredLockVersion','lockVersion','requiredFreezeVersion','freezeVersion','owner','runtimeOwner','materializePolicy','materializeMode','statePath','status','phase','migrationId','tenantId','executeWrites','preflightOk','dryRunOk','materializeStarted','materializeComplete','m4VerifyAllowedNext','m4CutoverAllowedNext','m4FreezeAllowedNext','maxWrites','pageSize','plannedTargetWrites','targetWritesExecuted','cumulativeTargetWritesExecuted','targetWritesSkippedSameSignature','targetWritesSkippedInvalid','maxWritesReached','firestoreReads','firestoreWrites','sourceReads','sourceWrites','targetReads','targetWrites','listeners','queries','fanOut','targetPathBuilt','tenantTargetPathBuilt','tenantConfigTouched','lifecycleTouched','tenantRoutingActive','tenantScopedReads','tenantScopedWrites','legacyRuntimeDisabled','legacySourceFrozen','backendRunStarted','triggerInstalled','sourceScanExecuted','targetScanExecuted','sourceCountsCollected','targetCountsCollected','sourceSignatureComputed','targetSignatureComputed','migrationSignatureComputed','blockingAnomalies','blockingAnomaliesDetected','migrationStateRead','migrationStateWritten','checkpointWritten','cursorAdvanced','verifyStarted','cutoverStarted','schemaChanged','runtimeContractChanged','destructiveOperationExecuted','crossTenantLeakDetected','startedAt','updatedAt','completedAt','error','errorKind'].forEach(function (key) {
    lines.push(key + '=' + String(Object.prototype.hasOwnProperty.call(stats, key) ? stats[key] : ''));
  });
  lines.push('lastCursor=' + JSON.stringify(stats.lastCursor || {}));
  lines.push('violations=' + ((stats.violations || []).length ? (stats.violations || []).join(',') : 'none'));
  return lines.join('\n');
}
