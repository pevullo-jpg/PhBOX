var PHBOX_M4_MATERIALIZE_VERSION_ = 'M4_MATERIALIZE_v1';
var PHBOX_M4_MATERIALIZE_STAGE_ = 'migration4_materialize';
var PHBOX_M4_MATERIALIZE_REQUIRED_LOCK_VERSION_ = 'M4_LOCK_v1';
var PHBOX_M4_MATERIALIZE_REQUIRED_FREEZE_VERSION_ = 'M3_FREEZE_v1';
var PHBOX_M4_MATERIALIZE_OWNER_ = 'backend_gas_m4_materialize_writer';
var PHBOX_M4_MATERIALIZE_RUNTIME_OWNER_ = 'future_m4_verify_gate';
var PHBOX_M4_MATERIALIZE_POLICY_ = 'bounded_idempotent_copy_source_to_tenant_target_without_source_delete';
var PHBOX_M4_MATERIALIZE_MODE_ = 'materialize_with_internal_preflight_and_dryrun';
var PHBOX_M4_MATERIALIZE_STATE_PATH_ = 'migrations/m4_materialize';
var PHBOX_M4_MATERIALIZE_APPROVED_TENANT_ID_ = 'farmacia-santa-venera-8xnoc';
var PHBOX_M4_MATERIALIZE_TENANT_SOURCE_ = 'approved_frontend_tenant_namespace';
var PHBOX_M4_MATERIALIZE_TARGET_CONTRACT_ = 'TENANTS_ASSISTITI_v1';
var PHBOX_M4_MATERIALIZE_TARGET_ASSISTITI_COLLECTION_ = 'assistiti';
var PHBOX_M4_MATERIALIZE_TARGET_CF_LOCKS_COLLECTION_ = 'assistiti_cf_locks';
var PHBOX_M4_MATERIALIZE_TARGET_IDENTITY_LOCKS_COLLECTION_ = 'assistiti_identity_locks';
var PHBOX_M4_MATERIALIZE_DEFAULT_MAX_WRITES_ = 20;
var PHBOX_M4_MATERIALIZE_DEFAULT_PAGE_SIZE_ = 20;
var PHBOX_M4_MATERIALIZE_MAX_PAGE_SIZE_ = 50;
var PHBOX_M4_MATERIALIZE_MAX_READS_PER_RUN_ = 180;
var PHBOX_M4_MATERIALIZE_ROOT_COLLECTIONS_ = [
  'patients'
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
    firestoreReads += Math.max(0, Number(e && e.firestoreReads || 0));
    registryReads += Math.max(0, Number(e && e.registryReads || 0));
  }

  return buildMigration4MaterializeResult_({
    lockStatus: lockStatus,
    state: state,
    executeWrites: false,
    firestoreReads: firestoreReads,
    firestoreWrites: 0,
    registryReads: registryReads,
    tenantId: tenant && tenant.tenantId,
    tenantSource: tenant && tenant.tenantSource,
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

  var tenantAudit = {
    firestoreReads: 0,
    registryReads: 0
  };

  try {
    var tenant = resolveMigration4MaterializeTenant_(api, options.props || PropertiesService.getScriptProperties());
    tenantAudit.firestoreReads = Math.max(0, Number(tenant && tenant.firestoreReads || 0));
    tenantAudit.registryReads = Math.max(0, Number(tenant && tenant.registryReads || 0));
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
      tenantSource: tenant.tenantSource,
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
      firestoreReads: stats.firestoreReads + Math.max(
        Math.max(0, Number(tenantAudit.firestoreReads || 0)),
        Math.max(0, Number(e && e.firestoreReads || 0))
      ),
      firestoreWrites: 0,
      registryReads: Math.max(
        Math.max(0, Number(tenantAudit.registryReads || 0)),
        Math.max(0, Number(e && e.registryReads || 0))
      ),
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
  work.maxWritesReached = !!work.maxWritesReached || writes.length >= maxWrites;
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
  if (collection !== 'patients') {
    work.blockingAnomalies += 1;
    work.violations.push('unsupported_root_collection_' + collection);
    return { cursor: cursor, work: work, writes: writes, stop: true };
  }

  var listed = api.listDocuments(collection, cursor.pageToken || '', options.pageSize);
  work.firestoreReads += 1;
  work.sourceReads += (listed.documents || []).length;
  work.sourceCountsCollected = true;

  var pageResult = buildMigration4MaterializeAssistitiWritesForPatients_(cfg, api, tenantId, listed.documents || [], {
    sourceCollectionPath: collection,
    maxWrites: options.maxWrites,
    currentWrites: options.currentWrites,
    executeWrites: options.executeWrites,
    nowIso: options.nowIso
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

  var rootPhaseCompletedWithWrites = writes.length > 0 && !cursor.pageToken && cursor.collectionIndex >= PHBOX_M4_MATERIALIZE_ROOT_COLLECTIONS_.length;
  return {
    cursor: cursor,
    work: work,
    writes: writes,
    stop: rootPhaseCompletedWithWrites || !!pageResult.pageCutShortForWriteBudget || !!cursor.pageToken || ((options.currentWrites + writes.length) >= options.maxWrites)
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
  var assistitoResolution = resolveMigration4MaterializeAssistitoIdForSourcePatient_(api, tenantId, patientId);
  work = mergeMigration4MaterializeWork_(work, assistitoResolution.work);
  var assistitoId = assistitoResolution.assistitoId;
  if (!assistitoId) {
    work.blockingAnomalies += 1;
    work.violations.push('assistito_id_missing_for_subcollection');
    return { cursor: cursor, work: work, writes: writes, stop: true };
  }

  var subcollection = PHBOX_M4_MATERIALIZE_PATIENT_SUBCOLLECTIONS_[subcollectionIndex];
  var sourceCollectionPath = 'patients/' + patientId + '/' + subcollection;
  var targetCollectionPath = 'tenants/' + tenantId + '/' + PHBOX_M4_MATERIALIZE_TARGET_ASSISTITI_COLLECTION_ + '/' + assistitoId + '/' + subcollection;
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

function buildMigration4MaterializeAssistitiWritesForPatients_(cfg, api, tenantId, documents, options) {
  options = options || {};
  documents = documents || [];
  var work = buildMigration4MaterializeEmptyWork_();
  var writes = [];
  var pageCutShortForWriteBudget = false;

  for (var i = 0; i < documents.length; i++) {
    var sourceDoc = documents[i] || {};
    var plan = buildMigration4MaterializeAssistitoPlan_(cfg, api, tenantId, sourceDoc, {
      nowIso: options.nowIso,
      sourceCollectionPath: options.sourceCollectionPath
    });
    work = mergeMigration4MaterializeWork_(work, plan.work);

    var plannedWrites = plan.writes || [];
    if ((options.currentWrites + writes.length + plannedWrites.length) > options.maxWrites) {
      pageCutShortForWriteBudget = true;
      work.maxWritesReached = true;
      break;
    }
    writes = writes.concat(plannedWrites);
  }

  return { work: work, writes: writes, pageCutShortForWriteBudget: pageCutShortForWriteBudget };
}

function buildMigration4MaterializeAssistitoPlan_(cfg, api, tenantId, sourceDoc, options) {
  options = options || {};
  var work = buildMigration4MaterializeEmptyWork_();
  var writes = [];
  var nowIso = String(options.nowIso || new Date().toISOString());
  var sourcePath = extractMigration4MaterializeDocumentPath_(sourceDoc.name || '');
  var sourceId = extractFirestoreDocumentId_(sourceDoc.name || '');
  if (!sourcePath || !sourceId || sourcePath.indexOf('tenants/') === 0 || sourcePath.indexOf('migrations/') === 0) {
    work.blockingAnomalies += 1;
    work.targetWritesSkippedInvalid += 1;
    return { work: work, writes: writes };
  }
  if (sourcePath.split('/')[0] !== 'patients') {
    work.blockingAnomalies += 1;
    work.violations.push('unsupported_source_collection_' + sourcePath.split('/')[0]);
    work.targetWritesSkippedInvalid += 1;
    return { work: work, writes: writes };
  }

  var sourceData = fromFirestoreFields_(sourceDoc.fields || {});
  var linked = readMigration4MaterializeAssistitoLinkedSources_(api, sourceId, sourceData);
  work = mergeMigration4MaterializeWork_(work, linked.work);

  var identity = resolveMigration4MaterializeAssistitoIdentity_(sourceId, sourceData, linked, nowIso);
  if (!identity.identityAnchor) {
    work.blockingAnomalies += 1;
    work.violations.push('assistito_identity_anchor_missing');
    work.targetWritesSkippedInvalid += 1;
    return { work: work, writes: writes };
  }

  var lockPlan = resolveMigration4MaterializeAssistitoLockPlan_(api, tenantId, identity, nowIso);
  work = mergeMigration4MaterializeWork_(work, lockPlan.work);
  if (isMigration4MaterializeNonOpaqueAssistitoId_(lockPlan.assistitoId, identity, sourceId)) {
    work.blockingAnomalies += 1;
    work.violations.push('assistito_id_not_opaque');
    work.targetWritesSkippedInvalid += 1;
    return { work: work, writes: writes };
  }

  var targetPath = buildMigration4MaterializeAssistitoPath_(tenantId, lockPlan.assistitoId);
  assertMigration4MaterializeTargetPath_(tenantId, targetPath);
  work.targetPathBuilt = true;
  work.tenantTargetPathBuilt = true;

  var targetDoc = api.getDocument(targetPath);
  work.firestoreReads += 1;
  work.targetReads += 1;
  work.targetCountsCollected = true;
  var targetData = targetDoc ? fromFirestoreFields_(targetDoc.fields || {}) : {};

  var targetPayload = buildMigration4MaterializeAssistitoPayload_(lockPlan.assistitoId, identity, sourceData, linked, targetData, nowIso);
  if (!isMigration4MaterializeFullAssistitoPayload_(targetPayload)) {
    work.blockingAnomalies += 1;
    work.violations.push('assistito_payload_contract_incomplete');
    work.targetWritesSkippedInvalid += 1;
    return { work: work, writes: writes };
  }

  var sourceSignature = computeMigration4MaterializeSignature_(targetPayload);
  work.sourceSignatureComputed = true;
  var targetSignature = targetDoc ? computeMigration4MaterializeSignature_(targetData) : '';
  if (targetDoc) work.targetSignatureComputed = true;
  work.migrationSignatureComputed = true;

  if (!lockPlan.cfLockExists && lockPlan.cfLockPath) {
    writes.push(buildMigration4MaterializeUpdateWriteFromPath_(cfg, lockPlan.cfLockPath, buildMigration4MaterializeCfLockPayload_(identity, lockPlan.assistitoId, targetPath, nowIso)));
  }
  if (!lockPlan.identityLockExists && lockPlan.identityLockPath) {
    writes.push(buildMigration4MaterializeUpdateWriteFromPath_(cfg, lockPlan.identityLockPath, buildMigration4MaterializeIdentityLockPayload_(identity, lockPlan.assistitoId, targetPath, nowIso)));
  }
  if (!targetDoc || sourceSignature !== targetSignature) {
    writes.push(buildMigration4MaterializeUpdateWriteFromPath_(cfg, targetPath, targetPayload));
  } else {
    work.targetWritesSkippedSameSignature += 1;
  }

  return { work: work, writes: writes };
}

function readMigration4MaterializeAssistitoLinkedSources_(api, sourceId, sourceData) {
  var work = buildMigration4MaterializeEmptyWork_();
  var key = resolveMigration4MaterializeLegacyKey_(sourceId, sourceData);
  var out = {
    dashboardIndexData: {},
    therapeuticAdviceData: {},
    doctorManualData: {},
    doctorPrimaryData: {},
    work: work
  };
  var docs = [
    { prop: 'dashboardIndexData', path: 'patient_dashboard_index/' + key },
    { prop: 'therapeuticAdviceData', path: 'patient_therapeutic_advice/' + key },
    { prop: 'doctorManualData', path: 'doctor_patient_links/' + key + '__manual' },
    { prop: 'doctorPrimaryData', path: 'doctor_patient_links/' + key + '__primary' }
  ];
  for (var i = 0; i < docs.length; i++) {
    var doc = api.getDocument(docs[i].path);
    work.firestoreReads += 1;
    work.sourceReads += doc ? 1 : 0;
    if (doc && doc.fields) out[docs[i].prop] = fromFirestoreFields_(doc.fields || {});
  }
  return out;
}

function resolveMigration4MaterializeAssistitoIdForSourcePatient_(api, tenantId, patientId) {
  var work = buildMigration4MaterializeEmptyWork_();
  var patientDoc = api.getDocument('patients/' + patientId);
  work.firestoreReads += 1;
  work.sourceReads += patientDoc ? 1 : 0;
  if (!patientDoc || !patientDoc.fields) return { assistitoId: '', work: work };
  var sourceData = fromFirestoreFields_(patientDoc.fields || {});
  var linked = { dashboardIndexData: {}, therapeuticAdviceData: {}, doctorManualData: {}, doctorPrimaryData: {}, work: buildMigration4MaterializeEmptyWork_() };
  var identity = resolveMigration4MaterializeAssistitoIdentity_(patientId, sourceData, linked, new Date().toISOString());
  var lock = readMigration4MaterializeAssistitoLock_(api, tenantId, identity);
  work = mergeMigration4MaterializeWork_(work, lock.work);
  return { assistitoId: lock.assistitoId, work: work };
}

function resolveMigration4MaterializeAssistitoLockPlan_(api, tenantId, identity, nowIso) {
  var work = buildMigration4MaterializeEmptyWork_();
  var lock = readMigration4MaterializeAssistitoLock_(api, tenantId, identity);
  work = mergeMigration4MaterializeWork_(work, lock.work);
  var assistitoId = lock.assistitoId;
  if (!assistitoId) assistitoId = buildMigration4MaterializeOpaqueAssistitoId_(identity.identityAnchor);
  return {
    assistitoId: assistitoId,
    cfLockPath: lock.cfLockPath,
    identityLockPath: lock.identityLockPath,
    cfLockExists: lock.cfLockExists,
    identityLockExists: lock.identityLockExists,
    work: work
  };
}

function readMigration4MaterializeAssistitoLock_(api, tenantId, identity) {
  var work = buildMigration4MaterializeEmptyWork_();
  var cfLockPath = '';
  var identityLockPath = '';
  var cfLock = null;
  var identityLock = null;

  if (identity.identityType === 'cf') {
    cfLockPath = buildMigration4MaterializeCfLockPath_(tenantId, identity.cf);
    cfLock = api.getDocument(cfLockPath);
    work.firestoreReads += 1;
    work.targetReads += 1;
  } else {
    identityLockPath = buildMigration4MaterializeIdentityLockPath_(tenantId, identity.identityAnchor);
    identityLock = api.getDocument(identityLockPath);
    work.firestoreReads += 1;
    work.targetReads += 1;
  }

  var cfLockData = cfLock && cfLock.fields ? fromFirestoreFields_(cfLock.fields || {}) : {};
  var identityLockData = identityLock && identityLock.fields ? fromFirestoreFields_(identityLock.fields || {}) : {};
  var assistitoId = String((identity.identityType === 'cf' ? cfLockData.assistitoId : identityLockData.assistitoId) || '').trim();
  return {
    assistitoId: assistitoId,
    cfLockPath: cfLockPath,
    identityLockPath: identityLockPath,
    cfLockExists: !!cfLock,
    identityLockExists: !!identityLock,
    work: work
  };
}

function resolveMigration4MaterializeAssistitoIdentity_(sourceId, sourceData, linked, nowIso) {
  sourceData = sourceData || {};
  linked = linked || {};
  var rawCode = readMigration4MaterializeFirstString_(sourceData, ['cf', 'fiscalCode', 'codiceFiscale', 'identityAnchor', 'legacyNoCfCode', 'id']);
  if (!rawCode) rawCode = sourceId;
  rawCode = normalizeMigration4MaterializeIdentityCode_(rawCode);
  var identityType = classifyMigration4MaterializeIdentityType_(rawCode);
  var identityAnchor = rawCode;
  var cf = rawCode;
  var legacyNoCfCode = '';
  var generatedNoCf = false;

  if (identityType !== 'cf') {
    legacyNoCfCode = resolveMigration4MaterializeLegacyNoCfCode_(sourceId, sourceData, rawCode);
    if (isMigration4MaterializeCanonicalNoCf_(rawCode)) {
      identityAnchor = rawCode;
      cf = rawCode;
    } else {
      identityAnchor = buildMigration4MaterializeCanonicalNoCfFromLegacyCode_(legacyNoCfCode || rawCode || sourceId);
      cf = identityAnchor;
    }
    identityType = 'nocf';
  }

  var existingResolution = readMigration4MaterializeMap_(sourceData.identityResolution);
  var explicitNome = normalizeMigration4MaterializeNamePart_(readMigration4MaterializeFirstString_(sourceData, ['nome', 'firstName', 'givenName']));
  var explicitCognome = normalizeMigration4MaterializeNamePart_(readMigration4MaterializeFirstString_(sourceData, ['cognome', 'lastName', 'surname', 'familyName']));
  var rawFullName = readMigration4MaterializeFirstString_(sourceData, ['fullName', 'displayName', 'patientName', 'assistitoName', 'name']);
  if (!rawFullName) rawFullName = readMigration4MaterializeFirstString_(linked.dashboardIndexData || {}, ['fullName', 'displayName', 'patientName', 'assistitoName', 'name']);
  if (!rawFullName) rawFullName = readMigration4MaterializeFirstString_(linked.therapeuticAdviceData || {}, ['fullName', 'displayName', 'patientName', 'assistitoName', 'name']);
  rawFullName = normalizeMigration4MaterializeFullName_(rawFullName);

  var resolved = resolveMigration4MaterializeNameSplit_(cf, explicitNome, explicitCognome, rawFullName);
  var status = resolved.status;
  var nameSplitConfidence = resolved.nameSplitConfidence;
  var identityResolution = {
    status: status,
    source: 'backend_gas_m4_materialize_assistiti_identity_contract',
    resolutionSource: 'backend_gas_m4_materialize_assistiti_identity_contract',
    nameSplitConfidence: nameSplitConfidence,
    rawFullName: rawFullName,
    requestedCode: String(legacyNoCfCode || sourceId || ''),
    resolvedNome: resolved.nome,
    resolvedCognome: resolved.cognome,
    resolvedFullName: resolved.fullName,
    resolvedAt: nowIso,
    candidateSplits: resolved.candidateSplits || []
  };
  if (existingResolution && String(existingResolution.status || '') === 'resolved_manual') {
    identityResolution = existingResolution;
    status = 'resolved_manual';
    nameSplitConfidence = String(existingResolution.nameSplitConfidence || sourceData.nameSplitConfidence || 'resolved_manual_identity');
    resolved = {
      nome: normalizeMigration4MaterializeNamePart_(existingResolution.resolvedNome || sourceData.nome || ''),
      cognome: normalizeMigration4MaterializeNamePart_(existingResolution.resolvedCognome || sourceData.cognome || ''),
      fullName: normalizeMigration4MaterializeFullName_(existingResolution.resolvedFullName || sourceData.fullName || rawFullName),
      status: status,
      nameSplitConfidence: nameSplitConfidence,
      candidateSplits: readMigration4MaterializeArray_(existingResolution.candidateSplits)
    };
  }

  return {
    cf: cf,
    nome: resolved.nome,
    cognome: resolved.cognome,
    fullName: resolved.fullName || rawFullName,
    identityAnchor: identityAnchor,
    identityType: identityType,
    legacyNoCfCode: String(legacyNoCfCode || '').trim(),
    generatedNoCf: generatedNoCf,
    identityResolution: identityResolution,
    identityResolutionStatus: status,
    nameSplitConfidence: nameSplitConfidence,
    rawFullName: rawFullName
  };
}

function buildMigration4MaterializeAssistitoPayload_(assistitoId, identity, sourceData, linked, existingData, nowIso) {
  existingData = existingData || {};
  linked = linked || {};
  var existingResolution = readMigration4MaterializeMap_(existingData.identityResolution);
  if (existingResolution && String(existingResolution.status || '') === 'resolved_manual') {
    identity.identityResolution = existingResolution;
    identity.identityResolutionStatus = 'resolved_manual';
    identity.nameSplitConfidence = String(existingResolution.nameSplitConfidence || identity.nameSplitConfidence || 'resolved_manual_identity');
    identity.nome = normalizeMigration4MaterializeNamePart_(existingResolution.resolvedNome || identity.nome || existingData.nome || '');
    identity.cognome = normalizeMigration4MaterializeNamePart_(existingResolution.resolvedCognome || identity.cognome || existingData.cognome || '');
    identity.fullName = normalizeMigration4MaterializeFullName_(existingResolution.resolvedFullName || identity.fullName || existingData.fullName || '');
  } else if (existingResolution && existingResolution.resolvedAt && identity.identityResolution) {
    identity.identityResolution.resolvedAt = existingResolution.resolvedAt;
  }
  var dashboard = buildMigration4MaterializeDashboardMap_(linked.dashboardIndexData || {}, identity);
  if (Object.keys(dashboard).length === 0) dashboard = readMigration4MaterializeMap_(existingData.dashboard);
  var doctor = buildMigration4MaterializeDoctorMap_(linked.doctorManualData || {}, linked.doctorPrimaryData || {}, identity);
  if (Object.keys(doctor).length === 0) doctor = readMigration4MaterializeMap_(existingData.doctor);
  var therapeuticAdvice = buildMigration4MaterializeTherapeuticAdviceMap_(linked.therapeuticAdviceData || {}, identity);
  if (Object.keys(therapeuticAdvice).length === 0) therapeuticAdvice = readMigration4MaterializeMap_(existingData.therapeuticAdvice);
  var createdAt = readMigration4MaterializeFirstString_(sourceData, ['createdAt', 'creationTime', 'importedAt', 'firstSeenAt']) || existingData.createdAt || nowIso;
  var updatedAt = readMigration4MaterializeFirstString_(sourceData, ['updatedAt', 'modifiedAt', 'lastSeenAt']) || existingData.updatedAt || createdAt;
  return {
    assistitoId: assistitoId,
    cf: identity.cf,
    nome: identity.nome,
    cognome: identity.cognome,
    fullName: identity.fullName,
    generatedNoCf: !!identity.generatedNoCf,
    identityAnchor: identity.identityAnchor,
    identityType: identity.identityType,
    legacyNoCfCode: identity.legacyNoCfCode,
    identityResolution: identity.identityResolution,
    identityResolutionStatus: identity.identityResolutionStatus,
    nameSplitConfidence: identity.nameSplitConfidence,
    searchPrefixes: buildMigration4MaterializeSearchPrefixes_(identity.fullName),
    doctor: doctor,
    dashboard: dashboard,
    therapeuticAdvice: therapeuticAdvice,
    createdAt: createdAt,
    updatedAt: updatedAt,
    sourceVersion: 1
  };
}

function isMigration4MaterializeFullAssistitoPayload_(payload) {
  payload = payload || {};
  var required = ['assistitoId', 'cf', 'fullName', 'identityAnchor', 'identityType', 'identityResolution', 'identityResolutionStatus', 'nameSplitConfidence', 'searchPrefixes', 'doctor', 'dashboard', 'therapeuticAdvice', 'createdAt', 'updatedAt'];
  for (var i = 0; i < required.length; i++) {
    if (!Object.prototype.hasOwnProperty.call(payload, required[i])) return false;
  }
  if (!payload.assistitoId || String(payload.assistitoId) === String(payload.cf) || String(payload.assistitoId) === String(payload.identityAnchor)) return false;
  if (!Array.isArray(payload.searchPrefixes)) return false;
  if (typeof payload.identityResolution !== 'object' || payload.identityResolution === null || Array.isArray(payload.identityResolution)) return false;
  return true;
}

function buildMigration4MaterializeCfLockPayload_(identity, assistitoId, assistitoPath, nowIso) {
  return {
    cf: identity.cf,
    identityAnchor: identity.identityAnchor,
    identityType: identity.identityType,
    assistitoId: assistitoId,
    assistitoPath: assistitoPath,
    createdAt: nowIso,
    createdBy: 'backend_gas_m4_materialize_assistiti_identity_contract',
    lockVersion: 1
  };
}

function buildMigration4MaterializeIdentityLockPayload_(identity, assistitoId, assistitoPath, nowIso) {
  return {
    requestedCode: identity.legacyNoCfCode || identity.identityAnchor,
    identityAnchor: identity.identityAnchor,
    identityType: identity.identityType,
    canonicalCf: identity.cf,
    legacyNoCfCode: identity.legacyNoCfCode,
    assistitoId: assistitoId,
    assistitoPath: assistitoPath,
    createdAt: nowIso,
    createdBy: 'backend_gas_m4_materialize_assistiti_identity_contract',
    lockVersion: 1
  };
}


function isMigration4MaterializeNonOpaqueAssistitoId_(assistitoId, identity, sourceId) {
  var value = String(assistitoId || '').trim();
  if (!value) return true;
  var normalized = normalizeMigration4MaterializeIdentityCode_(value);
  var forbidden = [
    identity && identity.identityAnchor,
    identity && identity.cf,
    identity && identity.legacyNoCfCode,
    sourceId
  ];
  for (var i = 0; i < forbidden.length; i++) {
    var item = String(forbidden[i] || '').trim();
    if (item && value === item) return true;
    if (item && normalized === normalizeMigration4MaterializeIdentityCode_(item)) return true;
  }
  if (/^[A-Z]{6}[0-9]{2}[A-Z][0-9]{2}[A-Z][0-9]{3}[A-Z]$/.test(normalized)) return true;
  if (normalized.indexOf('NOCF_') === 0) return true;
  if (normalized.indexOf('TMP_') === 0) return true;
  return false;
}

function resolveMigration4MaterializeLegacyNoCfCode_(sourceId, sourceData, rawCode) {
  sourceData = sourceData || {};
  var legacyNoCfCode = readMigration4MaterializeFirstString_(sourceData, ['legacyNoCfCode', 'requestedCode']);
  if (!legacyNoCfCode && String(sourceId || '').indexOf('TMP_') === 0) legacyNoCfCode = String(sourceId || '');
  if (!legacyNoCfCode && String(rawCode || '').indexOf('TMP_') === 0) legacyNoCfCode = String(rawCode || '');
  if (!legacyNoCfCode && String(sourceId || '').indexOf('NOCF_') === 0 && !isMigration4MaterializeCanonicalNoCf_(sourceId)) legacyNoCfCode = String(sourceId || '');
  return String(legacyNoCfCode || '').trim();
}

function isMigration4MaterializeCanonicalNoCf_(value) {
  return /^NOCF_[0-9A-F]{16}$/.test(normalizeMigration4MaterializeIdentityCode_(value));
}

function buildMigration4MaterializeCanonicalNoCfFromLegacyCode_(legacyCode) {
  var normalized = normalizeMigration4MaterializeLegacyNoCfSource_(legacyCode);
  if (!normalized) throw new Error('M4_MATERIALIZE_NOCF_LEGACY_CODE_MISSING: codice legacy NOCF/TMP mancante. Nessuna write target eseguita.');
  return 'NOCF_' + computeMigration4MaterializeFnv1a64Hex_('legacy_nocf|' + normalized);
}

function normalizeMigration4MaterializeLegacyNoCfSource_(value) {
  return String(value || '').trim().replace(/\s+/g, '_').toUpperCase();
}

function computeMigration4MaterializeFnv1a64Hex_(value) {
  var high = 0xcbf29ce4;
  var low = 0x84222325;
  var prime = 0x000001b3;
  var input = String(value || '').trim().toUpperCase();
  for (var i = 0; i < input.length; i++) {
    low = (low ^ (input.charCodeAt(i) & 0xff)) >>> 0;
    var product = low * prime;
    var newLow = product >>> 0;
    var carry = Math.floor(product / 0x100000000) >>> 0;
    var newHigh = ((high * prime) + carry) >>> 0;
    high = newHigh;
    low = newLow;
  }
  return hexMigration4MaterializeUint32_(high) + hexMigration4MaterializeUint32_(low);
}

function hexMigration4MaterializeUint32_(value) {
  return (value >>> 0).toString(16).toUpperCase().padStart(8, '0');
}


function resolveMigration4MaterializeLegacyKey_(sourceId, sourceData) {
  sourceData = sourceData || {};
  var legacy = normalizeMigration4MaterializeIdentityCode_(readMigration4MaterializeFirstString_(sourceData, ['legacyNoCfCode', 'requestedCode']));
  var sourceKey = normalizeMigration4MaterializeIdentityCode_(sourceId);
  var primary = normalizeMigration4MaterializeIdentityCode_(readMigration4MaterializeFirstString_(sourceData, ['cf', 'fiscalCode', 'codiceFiscale', 'identityAnchor', 'id']));

  if (isMigration4MaterializeNoCfOrTmpCode_(legacy)) return legacy;
  if (isMigration4MaterializeNoCfOrTmpCode_(sourceKey)) return sourceKey;
  if (isMigration4MaterializeNoCfOrTmpCode_(primary)) return primary;
  return primary || sourceKey;
}

function isMigration4MaterializeNoCfOrTmpCode_(value) {
  value = normalizeMigration4MaterializeIdentityCode_(value);
  return value.indexOf('NOCF_') === 0 || value.indexOf('TMP_') === 0;
}

function normalizeMigration4MaterializeIdentityCode_(value) {
  return String(value || '').trim().toUpperCase().replace(/\s+/g, '');
}

function classifyMigration4MaterializeIdentityType_(code) {
  var value = normalizeMigration4MaterializeIdentityCode_(code);
  if (/^[A-Z]{6}[0-9]{2}[A-Z][0-9]{2}[A-Z][0-9]{3}[A-Z]$/.test(value)) return 'cf';
  if (value.indexOf('NOCF_') === 0) return 'nocf';
  if (value.indexOf('TMP_') === 0) return 'nocf';
  return 'nocf';
}

function readMigration4MaterializeFirstString_(map, keys) {
  map = map || {};
  keys = keys || [];
  for (var i = 0; i < keys.length; i++) {
    var value = String(map[keys[i]] === null || map[keys[i]] === undefined ? '' : map[keys[i]]).trim();
    if (value) return value;
  }
  return '';
}

function readMigration4MaterializeMap_(value) {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    var out = {};
    Object.keys(value).forEach(function (key) { out[key] = value[key]; });
    return out;
  }
  return {};
}

function readMigration4MaterializeArray_(value) {
  return Array.isArray(value) ? value.slice() : [];
}

function normalizeMigration4MaterializeNamePart_(value) {
  return String(value || '').trim().replace(/\s+/g, ' ');
}

function normalizeMigration4MaterializeFullName_(value) {
  return String(value || '').trim().replace(/\s+/g, ' ');
}

function resolveMigration4MaterializeNameSplit_(cf, explicitNome, explicitCognome, rawFullName) {
  explicitNome = normalizeMigration4MaterializeNamePart_(explicitNome);
  explicitCognome = normalizeMigration4MaterializeNamePart_(explicitCognome);
  rawFullName = normalizeMigration4MaterializeFullName_(rawFullName);
  if (explicitNome || explicitCognome) {
    var explicitFullName = buildMigration4MaterializeDisplayFullName_(explicitCognome, explicitNome, rawFullName);
    return { nome: explicitNome, cognome: explicitCognome, fullName: explicitFullName, status: 'resolved_auto', nameSplitConfidence: explicitNome && explicitCognome ? 'explicit_fields' : 'explicit_fields_partial', candidateSplits: [] };
  }
  var tokens = rawFullName ? rawFullName.split(' ') : [];
  var candidates = [];
  if (tokens.length >= 2) {
    candidates.push({ cognome: tokens.slice(1).join(' '), nome: tokens[0], order: 'name_first' });
    candidates.push({ cognome: tokens[0], nome: tokens.slice(1).join(' '), order: 'surname_first' });
  }
  var best = null;
  for (var i = 0; i < candidates.length; i++) {
    var score = scoreMigration4MaterializeNameCandidate_(cf, candidates[i].nome, candidates[i].cognome);
    candidates[i].score = score;
    if (!best || score > best.score) best = candidates[i];
  }
  var candidateSplits = candidates.map(function (item) { return { nome: item.nome, cognome: item.cognome, order: item.order, score: item.score }; });
  if (best && best.score >= 8) {
    return { nome: best.nome, cognome: best.cognome, fullName: buildMigration4MaterializeDisplayFullName_(best.cognome, best.nome, rawFullName), status: 'resolved_auto', nameSplitConfidence: 'derived_from_cf_full_name', candidateSplits: candidateSplits };
  }
  return { nome: '', cognome: '', fullName: rawFullName, status: rawFullName ? 'pending_manual' : 'pending_manual', nameSplitConfidence: rawFullName ? 'pending_manual_ambiguous_full_name' : 'pending_manual_missing_name', candidateSplits: candidateSplits };
}

function buildMigration4MaterializeDisplayFullName_(cognome, nome, fallback) {
  cognome = normalizeMigration4MaterializeNamePart_(cognome);
  nome = normalizeMigration4MaterializeNamePart_(nome);
  if (cognome && nome) return cognome + ' ' + nome;
  if (cognome) return cognome;
  if (nome) return nome;
  return normalizeMigration4MaterializeFullName_(fallback);
}

function scoreMigration4MaterializeNameCandidate_(cf, nome, cognome) {
  var value = 0;
  var normalizedCf = normalizeMigration4MaterializeIdentityCode_(cf);
  if (classifyMigration4MaterializeIdentityType_(normalizedCf) !== 'cf') return value;
  if (migration4MaterializeNameCode_(cognome, true) === normalizedCf.substring(0, 3)) value += 4;
  if (migration4MaterializeNameCode_(nome, false) === normalizedCf.substring(3, 6)) value += 4;
  return value;
}

function migration4MaterializeNameCode_(value, surname) {
  var letters = String(value || '').toUpperCase().replace(/[^A-Z]/g, '');
  var consonants = letters.replace(/[AEIOU]/g, '');
  var vowels = letters.replace(/[^AEIOU]/g, '');
  var src = consonants + vowels + 'XXX';
  if (!surname && consonants.length >= 4) return consonants.charAt(0) + consonants.charAt(2) + consonants.charAt(3);
  return src.substring(0, 3);
}

function buildMigration4MaterializeSearchPrefixes_(fullName) {
  var normalized = String(fullName || '').trim().replace(/\s+/g, ' ').toLowerCase();
  if (!normalized) return [];
  var out = {};
  var tokens = normalized.split(' ');
  for (var i = 0; i < tokens.length; i++) {
    for (var n = 1; n <= tokens[i].length; n++) out[tokens[i].substring(0, n)] = true;
  }
  for (var j = 1; j <= normalized.length; j++) out[normalized.substring(0, j)] = true;
  return Object.keys(out).sort().slice(0, 50);
}

function buildMigration4MaterializeDashboardMap_(dashboardIndexData, identity) {
  dashboardIndexData = dashboardIndexData || {};
  var allowed = ['advanceCount', 'bookingCount', 'debtAmount', 'debtCount', 'exemptionCode', 'exemptions', 'hasAdvance', 'hasBooking', 'hasDebt', 'hasDpc', 'hasExpiry', 'hasRecipes', 'lastPrescriptionDate', 'nearestExpiryDate', 'recipeCount'];
  var out = {};
  for (var i = 0; i < allowed.length; i++) if (Object.prototype.hasOwnProperty.call(dashboardIndexData, allowed[i])) out[allowed[i]] = dashboardIndexData[allowed[i]];
  return out;
}

function buildMigration4MaterializeDoctorMap_(manualData, primaryData, identity) {
  var manual = sanitizeMigration4MaterializeDoctorFields_(manualData || {});
  var primary = sanitizeMigration4MaterializeDoctorFields_(primaryData || {});
  var out = {};
  if (Object.keys(manual).length > 0) out.manual = manual;
  if (Object.keys(primary).length > 0) out.primary = primary;
  return out;
}

function sanitizeMigration4MaterializeDoctorFields_(data) {
  var out = {};
  var doctorFullName = readMigration4MaterializeFirstString_(data, ['doctorFullName', 'fullName', 'displayName', 'name']);
  var doctorName = readMigration4MaterializeFirstString_(data, ['doctorName', 'name', 'fullName', 'doctorFullName']);
  if (doctorFullName) out.doctorFullName = doctorFullName;
  if (doctorName) out.doctorName = doctorName;
  Object.keys(data || {}).forEach(function (key) {
    if (key.indexOf('doctor') === 0 && !Object.prototype.hasOwnProperty.call(out, key)) out[key] = data[key];
  });
  return out;
}

function buildMigration4MaterializeTherapeuticAdviceMap_(data, identity) {
  data = data || {};
  var blocked = { cf: true, fiscalCode: true, codiceFiscale: true, nome: true, cognome: true, firstName: true, givenName: true, lastName: true, surname: true, familyName: true, fullName: true, displayName: true, patientName: true, assistitoName: true, name: true, searchPrefixes: true };
  var out = {};
  Object.keys(data).forEach(function (key) { if (!blocked[key]) out[key] = data[key]; });
  return out;
}

function buildMigration4MaterializeAssistitoPath_(tenantId, assistitoId) {
  return 'tenants/' + tenantId + '/' + PHBOX_M4_MATERIALIZE_TARGET_ASSISTITI_COLLECTION_ + '/' + assistitoId;
}

function buildMigration4MaterializeCfLockPath_(tenantId, cf) {
  return 'tenants/' + tenantId + '/' + PHBOX_M4_MATERIALIZE_TARGET_CF_LOCKS_COLLECTION_ + '/' + encodeURIComponent(String(cf || '').trim());
}

function buildMigration4MaterializeIdentityLockPath_(tenantId, identityAnchor) {
  return 'tenants/' + tenantId + '/' + PHBOX_M4_MATERIALIZE_TARGET_IDENTITY_LOCKS_COLLECTION_ + '/' + encodeURIComponent(String(identityAnchor || '').trim());
}

function buildMigration4MaterializeOpaqueAssistitoId_(identityAnchor) {
  var hash = computeStableHashForData_({ identityAnchor: String(identityAnchor || '') });
  return 'm4_' + String(hash || '').replace(/[^A-Za-z0-9]/g, '').substring(0, 22);
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
    tenantSource: String(data.tenantSource || ''),
    targetContract: PHBOX_M4_MATERIALIZE_TARGET_CONTRACT_,
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
  var rawExplicitTenantId = String(props.getProperty('PHBOX_TENANT_ID') || '');
  var rawExpectedTenantId = String(props.getProperty('PHBOX_EXPECTED_CANONICAL_TENANT_ID') || '');
  if (rawExplicitTenantId) assertMigration4MaterializeCanonicalTenantId_(rawExplicitTenantId);
  if (rawExpectedTenantId) assertMigration4MaterializeCanonicalTenantId_(rawExpectedTenantId);
  var explicitTenantId = rawExplicitTenantId.trim();
  var expectedTenantId = rawExpectedTenantId.trim();
  var tenantId = PHBOX_M4_MATERIALIZE_APPROVED_TENANT_ID_;
  assertMigration4MaterializeCanonicalTenantId_(tenantId);

  if (explicitTenantId && explicitTenantId !== tenantId) {
    throw new Error('M4_MATERIALIZE_TENANT_NAMESPACE_MISMATCH: Script Properties tenant diverso dal tenant namespace frontend approvato. Nessuna write target eseguita.');
  }
  if (expectedTenantId && expectedTenantId !== tenantId) {
    throw new Error('M4_MATERIALIZE_EXPECTED_TENANT_NAMESPACE_MISMATCH: expected tenant diverso dal tenant namespace frontend approvato. Nessuna write target eseguita.');
  }

  return {
    tenantId: tenantId,
    expectedTenantId: expectedTenantId || tenantId,
    tenantSource: PHBOX_M4_MATERIALIZE_TENANT_SOURCE_,
    firestoreReads: 0,
    registryReads: 0
  };
}

function throwMigration4MaterializeTenantRegistryError_(message) {
  var error = new Error(String(message || 'M4_MATERIALIZE_TENANT_REGISTRY_ERROR'));
  attachMigration4MaterializeTenantRegistryReadCounts_(error);
  throw error;
}

function attachMigration4MaterializeTenantRegistryReadCounts_(error) {
  error.firestoreReads = Math.max(1, Number(error.firestoreReads || 0));
  error.registryReads = Math.max(1, Number(error.registryReads || 0));
  return error;
}

function assertMigration4MaterializeCanonicalTenantId_(tenantId) {
  var value = String(tenantId || '').trim();
  if (!value) throw new Error('M4_MATERIALIZE_TENANT_EMPTY: tenantId vuoto. Nessuna write target eseguita.');
  if (value !== String(tenantId || '')) throw new Error('M4_MATERIALIZE_TENANT_NOT_CANONICAL: tenantId contiene spazi iniziali/finali. Nessuna write target eseguita.');
  if (value.indexOf('/') !== -1) throw new Error('M4_MATERIALIZE_TENANT_NOT_CANONICAL: tenantId contiene slash. Nessuna write target eseguita.');
  if (value.indexOf(' ') !== -1) throw new Error('M4_MATERIALIZE_TENANT_NOT_CANONICAL: tenantId contiene spazi. Nessuna write target eseguita.');
}


function resolveMigration4MaterializeTargetCollectionPath_(tenantId, sourceCollectionPath) {
  var sourcePath = String(sourceCollectionPath || '').trim();
  if (sourcePath === 'patients') {
    return 'tenants/' + String(tenantId || '').trim() + '/' + PHBOX_M4_MATERIALIZE_TARGET_ASSISTITI_COLLECTION_;
  }
  throw new Error('M4_MATERIALIZE_UNSUPPORTED_TARGET_MAPPING: source collection non mappata nel contratto FE assistiti. Nessuna write target eseguita.');
}

function assertMigration4MaterializeTargetPath_(tenantId, targetPath) {
  var expectedPrefix = 'tenants/' + String(tenantId || '').trim() + '/';
  var path = String(targetPath || '').trim();
  if (path.indexOf(expectedPrefix) !== 0) throw new Error('M4_MATERIALIZE_TARGET_PATH_OUT_OF_TENANT: target path fuori tenant. Nessuna write eseguita.');
  if (path.indexOf('/tenants/') !== -1) throw new Error('M4_MATERIALIZE_DOUBLE_TENANT_PATH: target path contiene tenants annidato. Nessuna write eseguita.');
  if (path.indexOf(expectedPrefix + 'patients/') === 0) throw new Error('M4_MATERIALIZE_TARGET_PATIENTS_PATH_FORBIDDEN: il target FE è assistiti, non patients. Nessuna write eseguita.');
  if (
    path.indexOf(expectedPrefix + PHBOX_M4_MATERIALIZE_TARGET_ASSISTITI_COLLECTION_ + '/') !== 0 &&
    path.indexOf(expectedPrefix + PHBOX_M4_MATERIALIZE_TARGET_CF_LOCKS_COLLECTION_ + '/') !== 0 &&
    path.indexOf(expectedPrefix + PHBOX_M4_MATERIALIZE_TARGET_IDENTITY_LOCKS_COLLECTION_ + '/') !== 0
  ) {
    throw new Error('M4_MATERIALIZE_TARGET_PATH_NOT_IN_FE_CONTRACT: target path non conforme al contratto FE assistiti/locks. Nessuna write eseguita.');
  }
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
  var props = createMigration4MaterializeTestProperties_({ PHBOX_TENANT_ID: PHBOX_M4_MATERIALIZE_APPROVED_TENANT_ID_, PHBOX_EXPECTED_CANONICAL_TENANT_ID: PHBOX_M4_MATERIALIZE_APPROVED_TENANT_ID_ });
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
      id: 'resolves_approved_frontend_tenant_namespace_without_registry_read',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: {}, firestoreApi: { listDocuments: function (collectionPath, pageToken, pageSize) { if (String(collectionPath || '') === 'tenants') throw new Error('TENANTS_REGISTRY_MUST_NOT_BE_READ'); if (String(collectionPath || '') === 'patients') return { documents: [buildMigration4MaterializeFakeDoc_(cfg.firestoreProjectId, 'patients', 'BFLGPR79A26A089F', { fiscalCode: 'BFLGPR79A26A089F', fullName: 'GASPARE BUFALINO' })], nextPageToken: '' }; return { documents: [], nextPageToken: '' }; }, getDocument: function () { return null; }, commit: function () {} }, props: createMigration4MaterializeTestProperties_({}), executeWrites: true, maxWrites: 5 }); },
      expected: { ok: true, tenantId: 'farmacia-santa-venera-8xnoc', tenantSource: 'approved_frontend_tenant_namespace', registryReads: 0, targetWritesExecuted: 2 }
    },
    {
      id: 'blocks_noncanonical_raw_script_property_tenant',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: {}, firestoreApi: createMigration4MaterializeFakeApi_({}), props: createMigration4MaterializeTestProperties_({ PHBOX_TENANT_ID: ' farmacia-santa-venera-8xnoc ' }), executeWrites: true }); },
      expected: { ok: false, violationContains: 'materialize_error', targetWritesExecuted: 0 }
    },
    {
      id: 'blocks_noncanonical_raw_expected_tenant',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: {}, firestoreApi: createMigration4MaterializeFakeApi_({}), props: createMigration4MaterializeTestProperties_({ PHBOX_EXPECTED_CANONICAL_TENANT_ID: ' farmacia-santa-venera-8xnoc ' }), executeWrites: true }); },
      expected: { ok: false, violationContains: 'materialize_error', targetWritesExecuted: 0 }
    },
    {
      id: 'blocks_script_property_tenant_mismatch',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: {}, firestoreApi: createMigration4MaterializeFakeApi_({}), props: createMigration4MaterializeTestProperties_({ PHBOX_TENANT_ID: 'wrong-tenant' }), executeWrites: true }); },
      expected: { ok: false, violationContains: 'materialize_error', targetWritesExecuted: 0 }
    },
    {
      id: 'writes_missing_cf_patient_with_full_fe_contract_and_lock',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: {}, firestoreApi: createMigration4MaterializeFakeApi_({ source: { patients: [{ id: 'BFLGPR79A26A089F', data: { fiscalCode: 'BFLGPR79A26A089F', fullName: 'GASPARE BUFALINO' } }] } }), props: props, executeWrites: true, maxWrites: 5 }); },
      expected: { ok: true, targetWritesExecuted: 2, targetPathBuilt: true, tenantTargetPathBuilt: true, sourceWrites: 0, targetContract: 'TENANTS_ASSISTITI_v1' }
    },
    {
      id: 'writes_missing_nocf_patient_with_identity_lock_only',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: {}, firestoreApi: createMigration4MaterializeFakeApi_({ source: { patients: [{ id: 'TMP_AMEDEO_FANTAUZZO_1775837672370000', data: { fiscalCode: 'NOCF_1333C7A3C5B35C8B', legacyNoCfCode: 'TMP_AMEDEO_FANTAUZZO_1775837672370000', fullName: 'Amedeo Fantauzzo' } }] } }), props: props, executeWrites: true, maxWrites: 5 }); },
      expected: { ok: true, targetWritesExecuted: 2, targetPathBuilt: true, tenantTargetPathBuilt: true, sourceWrites: 0 }
    },
    {
      id: 'blocks_nocf_resolution_through_cf_lock_collection',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: {}, firestoreApi: { listDocuments: function (collectionPath) { if (String(collectionPath || '') === 'patients') return { documents: [buildMigration4MaterializeFakeDoc_(cfg.firestoreProjectId, 'patients', 'TMP_AMEDEO_FANTAUZZO_1775837672370000', { fiscalCode: 'NOCF_1333C7A3C5B35C8B', legacyNoCfCode: 'TMP_AMEDEO_FANTAUZZO_1775837672370000', fullName: 'Amedeo Fantauzzo' })], nextPageToken: '' }; return { documents: [], nextPageToken: '' }; }, getDocument: function (documentPath) { if (String(documentPath || '').indexOf('/assistiti_cf_locks/NOCF_') !== -1 || String(documentPath || '').indexOf('/assistiti_cf_locks/TMP_') !== -1) throw new Error('NOCF_TMP_CF_LOCK_MUST_NOT_BE_READ'); return null; }, commit: function () {} }, props: props, executeWrites: true, maxWrites: 5 }); },
      expected: { ok: true, targetWritesExecuted: 2, targetPathBuilt: true, tenantTargetPathBuilt: true }
    },
    {
      id: 'normalizes_tmp_identity_type_as_nocf',
      run: function () { var identity = resolveMigration4MaterializeAssistitoIdentity_('TMP_AMEDEO_FANTAUZZO_1775837672370000', { fiscalCode: 'TMP_AMEDEO_FANTAUZZO_1775837672370000', fullName: 'Amedeo Fantauzzo' }, {}, '2026-06-06T17:00:00.000Z'); return { stats: { ok: identity.identityType === 'nocf', identityType: identity.identityType } }; },
      expected: { ok: true, identityType: 'nocf' }
    },
    {
      id: 'canonicalizes_tmp_identity_anchor_as_nocf_hash',
      run: function () { var identity = resolveMigration4MaterializeAssistitoIdentity_('TMP_AMEDEO_FANTAUZZO_1775837672370000', { fiscalCode: 'TMP_AMEDEO_FANTAUZZO_1775837672370000', fullName: 'Amedeo Fantauzzo' }, {}, '2026-06-06T17:00:00.000Z'); return { stats: { ok: isMigration4MaterializeCanonicalNoCf_(identity.identityAnchor) && identity.cf === identity.identityAnchor && identity.legacyNoCfCode === 'TMP_AMEDEO_FANTAUZZO_1775837672370000', identityAnchorCanonical: isMigration4MaterializeCanonicalNoCf_(identity.identityAnchor), legacyNoCfCode: identity.legacyNoCfCode } }; },
      expected: { ok: true, identityAnchorCanonical: true, legacyNoCfCode: 'TMP_AMEDEO_FANTAUZZO_1775837672370000' }
    },
    {
      id: 'rejects_legacy_requested_code_as_assistito_id_from_identity_lock',
      run: function () { var identity = resolveMigration4MaterializeAssistitoIdentity_('TMP_AMEDEO_FANTAUZZO_1775837672370000', { fiscalCode: 'TMP_AMEDEO_FANTAUZZO_1775837672370000', fullName: 'Amedeo Fantauzzo' }, {}, '2026-06-06T17:00:00.000Z'); var target = {}; target['tenants/farmacia-santa-venera-8xnoc/assistiti_identity_locks/' + identity.identityAnchor] = { identityAnchor: identity.identityAnchor, identityType: 'nocf', legacyNoCfCode: identity.legacyNoCfCode, assistitoId: identity.legacyNoCfCode, assistitoPath: 'tenants/farmacia-santa-venera-8xnoc/assistiti/' + identity.legacyNoCfCode }; return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: {}, firestoreApi: createMigration4MaterializeFakeApi_({ source: { patients: [{ id: 'TMP_AMEDEO_FANTAUZZO_1775837672370000', data: { fiscalCode: 'TMP_AMEDEO_FANTAUZZO_1775837672370000', fullName: 'Amedeo Fantauzzo' } }] }, target: target }), props: props, executeWrites: true, maxWrites: 5 }); },
      expected: { ok: false, violationContains: 'blocking_anomalies_detected', targetWritesExecuted: 0 }
    },
    {
      id: 'prefers_legacy_tmp_key_for_nocf_side_documents',
      run: function () { var key = resolveMigration4MaterializeLegacyKey_('TMP_AMEDEO_FANTAUZZO_1775837672370000', { fiscalCode: 'NOCF_1333C7A3C5B35C8B', legacyNoCfCode: 'TMP_AMEDEO_FANTAUZZO_1775837672370000', fullName: 'Amedeo Fantauzzo' }); return { stats: { ok: key === 'TMP_AMEDEO_FANTAUZZO_1775837672370000', legacyKey: key } }; },
      expected: { ok: true, legacyKey: 'TMP_AMEDEO_FANTAUZZO_1775837672370000' }
    },
    {
      id: 'retried_cut_page_does_not_rewrite_completed_assistiti',
      run: function () { var assistitoId = buildMigration4MaterializeOpaqueAssistitoId_('BFLGPR79A26A089F'); var target = {}; target['tenants/farmacia-santa-venera-8xnoc/assistiti_cf_locks/BFLGPR79A26A089F'] = { cf: 'BFLGPR79A26A089F', identityAnchor: 'BFLGPR79A26A089F', identityType: 'cf', assistitoId: assistitoId, assistitoPath: 'tenants/farmacia-santa-venera-8xnoc/assistiti/' + assistitoId, createdAt: '2026-05-23T10:20:13.716', createdBy: 'backend_gas_m4_materialize_assistiti_identity_contract', lockVersion: 1 }; target['tenants/farmacia-santa-venera-8xnoc/assistiti/' + assistitoId] = buildMigration4MaterializeAssistitoPayload_(assistitoId, resolveMigration4MaterializeAssistitoIdentity_('BFLGPR79A26A089F', { fiscalCode: 'BFLGPR79A26A089F', fullName: 'GASPARE BUFALINO', createdAt: '2026-05-23T10:20:13.716' }, {}, '2026-06-06T17:00:00.000Z'), { fiscalCode: 'BFLGPR79A26A089F', fullName: 'GASPARE BUFALINO', createdAt: '2026-05-23T10:20:13.716' }, { dashboardIndexData: {}, therapeuticAdviceData: {}, doctorManualData: {}, doctorPrimaryData: {} }, {}, '2026-06-06T17:00:00.000Z'); return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: {}, firestoreApi: createMigration4MaterializeFakeApi_({ source: { patients: [{ id: 'BFLGPR79A26A089F', data: { fiscalCode: 'BFLGPR79A26A089F', fullName: 'GASPARE BUFALINO', createdAt: '2026-05-23T10:20:13.716' } }] }, target: target }), props: props, executeWrites: true, maxWrites: 5 }); },
      expected: { ok: true, targetWritesExecuted: 0, targetWritesSkippedSameSignature: 1 }
    },
    {
      id: 'does_not_skip_against_obsolete_cf_document_id_path',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: {}, firestoreApi: createMigration4MaterializeFakeApi_({ source: { patients: [{ id: 'BFLGPR79A26A089F', data: { fiscalCode: 'BFLGPR79A26A089F', fullName: 'GASPARE BUFALINO' } }] }, target: { 'tenants/farmacia-santa-venera-8xnoc/assistiti/BFLGPR79A26A089F': { fiscalCode: 'BFLGPR79A26A089F', fullName: 'GASPARE BUFALINO' } } }), props: props, executeWrites: true, maxWrites: 5 }); },
      expected: { ok: true, targetWritesExecuted: 2, targetWritesSkippedSameSignature: 0 }
    },
    {
      id: 'uses_existing_cf_lock_assistito_id',
      run: function () { var assistitoId = 'ZJYufVs7xItukDhXeJJO'; var lockPath = 'tenants/farmacia-santa-venera-8xnoc/assistiti_cf_locks/BFLGPR79A26A089F'; var target = {}; target[lockPath] = { cf: 'BFLGPR79A26A089F', assistitoId: assistitoId, assistitoPath: 'tenants/farmacia-santa-venera-8xnoc/assistiti/' + assistitoId }; return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: {}, firestoreApi: createMigration4MaterializeFakeApi_({ source: { patients: [{ id: 'BFLGPR79A26A089F', data: { fiscalCode: 'BFLGPR79A26A089F', fullName: 'GASPARE BUFALINO' } }] }, target: target }), props: props, executeWrites: true, maxWrites: 5 }); },
      expected: { ok: true, targetWritesExecuted: 1, targetWritesSkippedSameSignature: 0 }
    },
    {
      id: 'dryrun_plans_without_commit',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: {}, firestoreApi: createMigration4MaterializeFakeApi_({ source: { patients: [{ id: 'BFLGPR79A26A089F', data: { fiscalCode: 'BFLGPR79A26A089F', fullName: 'GASPARE BUFALINO' } }] } }), props: props, executeWrites: false, maxWrites: 5 }); },
      expected: { ok: true, plannedTargetWrites: 2, targetWritesExecuted: 0, dryRunOk: true }
    },
    {
      id: 'preserves_root_cursor_when_write_budget_cuts_page_short',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: {}, firestoreApi: createMigration4MaterializeFakeApi_({ source: { patients: [{ id: 'BFLGPR79A26A089F', data: { fiscalCode: 'BFLGPR79A26A089F', fullName: 'GASPARE BUFALINO' } }, { id: 'RSSMRA80A01H501U', data: { fiscalCode: 'RSSMRA80A01H501U', fullName: 'Mario Rossi' } }] } }), props: props, executeWrites: true, maxWrites: 3, pageSize: 20 }); },
      expected: { ok: true, targetWritesExecuted: 2, maxWritesReached: true, lastCursorPhase: 'root', lastCursorCollectionIndex: 0, lastCursorPageToken: '' }
    },
    {
      id: 'materializes_patient_subcollection_under_locked_assistito_id',
      run: function () { var cf = 'BFLGPR79A26A089F'; var target = {}; target['tenants/farmacia-santa-venera-8xnoc/assistiti_cf_locks/' + cf] = { cf: cf, assistitoId: 'assistito_auto_1', assistitoPath: 'tenants/farmacia-santa-venera-8xnoc/assistiti/assistito_auto_1' }; return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: { lastCursor: { phase: 'patient_subcollections' } }, firestoreApi: createMigration4MaterializeFakeApi_({ source: { patients: [{ id: cf, data: { fiscalCode: cf, fullName: 'Test Uno' } }], ['patients/' + cf + '/debts']: [{ id: 'debt1', data: { id: 'debt1' } }] }, target: target }), props: props, executeWrites: true, maxWrites: 5 }); },
      expected: { ok: true, targetWritesExecuted: 1, targetPathBuilt: true }
    },
    {
      id: 'completes_when_no_more_patients',
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: { lastCursor: { phase: 'patient_subcollections' } }, firestoreApi: createMigration4MaterializeFakeApi_({ source: { patients: [] } }), props: props, executeWrites: true, maxWrites: 5 }); },
      expected: { ok: true, materializeComplete: true, m4VerifyAllowedNext: true }
    },
    {
      id: 'writes_checkpoint_state',
      run: function () { var saved = null; return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: {}, firestoreApi: createMigration4MaterializeFakeApi_({ source: { patients: [{ id: 'BFLGPR79A26A089F', data: { fiscalCode: 'BFLGPR79A26A089F', fullName: 'GASPARE BUFALINO' } }] } }), saveStateFn: function (state) { saved = state; }, props: props, executeWrites: true, maxWrites: 5 }); },
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
      run: function () { return runMigration4MaterializeBatch_({ cfg: cfg, lockStatus: cleanLock, state: {}, firestoreApi: createMigration4MaterializeFakeApi_({ source: { patients: [{ id: 'BFLGPR79A26A089F', data: { fiscalCode: 'BFLGPR79A26A089F', fullName: 'GASPARE BUFALINO' } }] } }), props: props, executeWrites: true, maxWrites: 3, pageSize: 1 }); },
      expected: { ok: true, sourceReadsMax: 6 }
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
      var decodedPath = decodeURIComponent(String(documentPath || ''));
      var data = target[decodedPath];
      if (!data) {
        var collectionPath = decodedPath.split('/').slice(0, -1).join('/');
        var documentId = decodedPath.split('/').pop();
        var docs = source[collectionPath] || [];
        for (var i = 0; i < docs.length; i++) {
          if (String(docs[i].id || '') === documentId) {
            data = docs[i].data || {};
            break;
          }
        }
      }
      if (!data) return null;
      return buildMigration4MaterializeFakeDoc_(cfgPathProject_(), decodedPath.split('/').slice(0, -1).join('/'), decodedPath.split('/').pop(), data);
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
