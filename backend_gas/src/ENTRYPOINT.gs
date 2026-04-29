async function runPhboxBackendSimple() {
  var lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    var cfg = getPhboxConfig_();
    var budget = createRunBudget_(cfg, 'runPhboxBackendSimple');
    assertBackendReadyForRun_({ includeDriveOcrProbe: false, includeFirestoreProbe: false, includeGmailProbe: false });

    var rootFolder = DriveApp.getFolderById(cfg.folderId);
    var runtimeIndex = readRuntimeIndex_(rootFolder, cfg);

    var gmailStage = await runProtectedStage_('gmail_ingest', function () {
      return ingestPrescriptionEmails_({ budget: budget, runtimeIndex: runtimeIndex });
    }, cfg);
    runtimeIndex = persistRuntimeStageResult_(rootFolder, cfg, runtimeIndex, gmailStage);

    var manifestStage = await runProtectedStage_('build_manifests', function () {
      return buildImportManifestsFromDrive_({ budget: budget, runtimeIndex: runtimeIndex });
    }, cfg);
    runtimeIndex = persistRuntimeStageResult_(rootFolder, cfg, runtimeIndex, manifestStage);

    var mergeStage = await runProtectedStage_('merge', function () {
      return canonicalizeParsedManifestsPerCf_({ budget: budget, runtimeIndex: runtimeIndex, maxGroupsPerRun: cfg.maxMergeGroupsPerRun });
    }, cfg);
    runtimeIndex = persistRuntimeStageResult_(rootFolder, cfg, runtimeIndex, mergeStage);

    var renameStage = await runProtectedStage_('rename', function () {
      return normalizeFinalActivePdfNames_({ budget: budget, runtimeIndex: runtimeIndex });
    }, cfg);
    runtimeIndex = persistRuntimeStageResult_(rootFolder, cfg, runtimeIndex, renameStage);

    var runtimeGateStage = await runProtectedStage_('runtime_signal_gate', function () {
      return runRuntimeSignalGate_({ entrypoint: 'runPhboxBackendSimple' });
    }, cfg);
    var runtimeGate = runtimeGateStage && runtimeGateStage.ok ? runtimeGateStage.result : {
      ok: false,
      mode: 'runtime_gate_error',
      handled: false,
      fallbackPipeline: false,
      requiresFullPipeline: false,
      error: runtimeGateStage ? runtimeGateStage.error : 'runtime_signal_gate_missing'
    };

    var shouldRunFirestoreStages = shouldRunFirestoreStagesAfterDrivePipeline_(runtimeGate, runtimeIndex);
    var deleteStage = buildSkippedRuntimeStage_('archive_delete', 'firestore_gate_closed_no_firestore_work');
    var firestoreStage = buildSkippedRuntimeStage_('firestore_publish', 'firestore_gate_closed_no_firestore_work');

    if (shouldRunFirestoreStages) {
      deleteStage = await runProtectedStage_('archive_delete', function () {
        return consumePendingArchiveDeleteRequests_({ budget: budget, runtimeIndex: runtimeIndex });
      }, cfg);
      runtimeIndex = persistRuntimeStageResult_(rootFolder, cfg, runtimeIndex, deleteStage);

      firestoreStage = await runProtectedStage_('firestore_publish', function () {
        return syncRuntimeIndexToFirestore_({ budget: budget, runtimeIndex: runtimeIndex });
      }, cfg);
      runtimeIndex = persistRuntimeStageResult_(rootFolder, cfg, runtimeIndex, firestoreStage);
    }

    var gmailFinalizeStage = await runProtectedStage_('gmail_finalize', function () {
      return finalizeRuntimeEmails_({ budget: budget, runtimeIndex: runtimeIndex });
    }, cfg);
    runtimeIndex = persistRuntimeStageResult_(rootFolder, cfg, runtimeIndex, gmailFinalizeStage);

    var result = {
      ok: true,
      runtimeGate: runtimeGate,
      gmail: normalizeStageSummary_(gmailStage, { skipped: true, reason: 'stage_error', stoppedEarly: true }),
      manifestsSeen: collectRuntimeManifests_(runtimeIndex).length,
      manifests: normalizeStageSummary_(manifestStage, { skipped: true, reason: 'stage_error', stoppedEarly: true }),
      merge: normalizeStageSummary_(mergeStage, { skipped: true, reason: 'stage_error', stoppedEarly: true }),
      rename: normalizeStageSummary_(renameStage, { skipped: true, reason: 'stage_error', stoppedEarly: true }),
      archiveDelete: normalizeStageSummary_(deleteStage, { skipped: true, reason: 'stage_error', stoppedEarly: true }),
      firestore: normalizeStageSummary_(firestoreStage, { skipped: true, reason: 'stage_error', stoppedEarly: true }),
      gmailFinalize: normalizeStageSummary_(gmailFinalizeStage, { skipped: true, reason: 'stage_error', stoppedEarly: true }),
      budget: describeBudgetState_(budget),
      needsAnotherRun: computeNeedsAnotherRunFromRuntimeIndex_(runtimeIndex, [gmailStage, manifestStage, mergeStage, renameStage, runtimeGateStage, deleteStage, firestoreStage, gmailFinalizeStage])
    };
    if (runtimeGate && runtimeGate.requiresFullPipeline) {
      var runtimeSignalFinalizeStage = await runProtectedStage_('runtime_signal_finalize_full_pipeline', function () {
        return finalizeRuntimeSignalFullPipeline_(runtimeGate, result);
      }, cfg);
      result.runtimeSignalGateAfterFullPipeline = runtimeSignalFinalizeStage && runtimeSignalFinalizeStage.ok ? runtimeSignalFinalizeStage.result : {
        ok: false,
        error: runtimeSignalFinalizeStage ? runtimeSignalFinalizeStage.error : 'runtime_signal_finalize_missing'
      };
    }
    logInfo_(cfg, 'runPhboxBackendSimple completato', result);
    return result;
  } finally {
    lock.releaseLock();
  }
}


async function runPhboxDriveOnly() {
  var lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    var cfg = getPhboxConfig_();
    var budget = createRunBudget_(cfg, 'runPhboxDriveOnly');
    assertBackendReadyForRun_({ includeDriveOcrProbe: false, includeFirestoreProbe: false, skipGmail: true });
    var rootFolder = DriveApp.getFolderById(cfg.folderId);
    var runtimeIndex = readRuntimeIndex_(rootFolder, cfg);

    var manifestStage = await runProtectedStage_('build_manifests', function () {
      return buildImportManifestsFromDrive_({ budget: budget, runtimeIndex: runtimeIndex });
    }, cfg);
    runtimeIndex = persistRuntimeStageResult_(rootFolder, cfg, runtimeIndex, manifestStage);

    var mergeStage = await runProtectedStage_('merge', function () {
      return canonicalizeParsedManifestsPerCf_({ budget: budget, runtimeIndex: runtimeIndex, maxGroupsPerRun: cfg.maxMergeGroupsPerRun });
    }, cfg);
    runtimeIndex = persistRuntimeStageResult_(rootFolder, cfg, runtimeIndex, mergeStage);

    var renameStage = await runProtectedStage_('rename', function () {
      return normalizeFinalActivePdfNames_({ budget: budget, runtimeIndex: runtimeIndex });
    }, cfg);
    runtimeIndex = persistRuntimeStageResult_(rootFolder, cfg, runtimeIndex, renameStage);

    var deleteStage = await runProtectedStage_('archive_delete', function () {
      return consumePendingArchiveDeleteRequests_({ budget: budget, runtimeIndex: runtimeIndex });
    }, cfg);
    runtimeIndex = persistRuntimeStageResult_(rootFolder, cfg, runtimeIndex, deleteStage);

    var firestoreStage = await runProtectedStage_('firestore_publish', function () {
      return syncRuntimeIndexToFirestore_({ budget: budget, runtimeIndex: runtimeIndex });
    }, cfg);
    runtimeIndex = persistRuntimeStageResult_(rootFolder, cfg, runtimeIndex, firestoreStage);

    var result = {
      ok: true,
      manifestsSeen: collectRuntimeManifests_(runtimeIndex).length,
      manifests: normalizeStageSummary_(manifestStage, { skipped: true, reason: 'stage_error', stoppedEarly: true }),
      merge: normalizeStageSummary_(mergeStage, { skipped: true, reason: 'stage_error', stoppedEarly: true }),
      rename: normalizeStageSummary_(renameStage, { skipped: true, reason: 'stage_error', stoppedEarly: true }),
      archiveDelete: normalizeStageSummary_(deleteStage, { skipped: true, reason: 'stage_error', stoppedEarly: true }),
      firestore: normalizeStageSummary_(firestoreStage, { skipped: true, reason: 'stage_error', stoppedEarly: true }),
      budget: describeBudgetState_(budget),
      needsAnotherRun: computeNeedsAnotherRunFromRuntimeIndex_(runtimeIndex, [manifestStage, mergeStage, renameStage, deleteStage, firestoreStage])
    };
    logInfo_(cfg, 'runPhboxDriveOnly completato', result);
    return result;
  } finally {
    lock.releaseLock();
  }
}

async function rebuildPhboxFromManifestsOnly() {
  return runPhboxDriveOnly();
}

async function forceFullResyncToFirestore() {
  var lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    var cfg = getPhboxConfig_();
    var budget = createRunBudget_(cfg, 'forceFullResyncToFirestore');
    assertBackendReadyForRun_({ includeFirestoreProbe: false, skipDriveOcrProbe: true, skipGmail: true });
    var rootFolder = DriveApp.getFolderById(cfg.folderId);
    var runtimeIndex = readRuntimeIndex_(rootFolder, cfg);
    runtimeIndex.dirty.imports = uniqueNonEmptyStrings_(collectRuntimeManifests_(runtimeIndex).map(function (item) { return item.driveFileId; }));
    runtimeIndex.dirty.cfs = uniqueNonEmptyStrings_(collectRuntimeManifests_(runtimeIndex).map(function (item) { return normalizeCf_(item.patientFiscalCode); }));
    writeRuntimeIndex_(rootFolder, cfg, runtimeIndex);
    var firestoreStage = await syncRuntimeIndexToFirestore_({ budget: budget, runtimeIndex: runtimeIndex, maxWrites: cfg.maxBatchWrites });
    writeRuntimeIndex_(rootFolder, cfg, firestoreStage.runtimeIndex || runtimeIndex);
    var result = {
      ok: true,
      firestore: firestoreStage.stats,
      budget: describeBudgetState_(budget),
      needsAnotherRun: computeNeedsAnotherRunFromRuntimeIndex_(firestoreStage.runtimeIndex || runtimeIndex, [firestoreStage])
    };
    logInfo_(cfg, 'forceFullResyncToFirestore completato', result);
    return result;
  } finally {
    lock.releaseLock();
  }
}

async function runProtectedStage_(stageName, fn, cfg) {
  try {
    return {
      ok: true,
      result: await fn()
    };
  } catch (e) {
    var kind = classifyRuntimeFailureKind_(e);
    logInfo_(cfg, 'run_stage_failed', {
      stage: stageName,
      error: normalizeRuntimeErrorMessage_(e),
      kind: kind
    });
    return {
      ok: false,
      error: normalizeRuntimeErrorMessage_(e),
      errorKind: kind,
      stage: stageName
    };
  }
}

function persistRuntimeStageResult_(rootFolder, cfg, currentIndex, stage) {
  if (!stage || !stage.ok || !stage.result || !stage.result.runtimeIndex) {
    return currentIndex;
  }
  var runtimeIndex = stage.result.runtimeIndex;
  writeRuntimeIndex_(rootFolder, cfg, runtimeIndex);
  return runtimeIndex;
}

function normalizeStageSummary_(stage, fallback) {
  fallback = fallback || {};
  if (!stage) return fallback;
  if (stage.ok && stage.result && stage.result.stats) return stage.result.stats;
  if (!stage.ok) {
    var out = JSON.parse(JSON.stringify(fallback));
    out.failed = true;
    out.error = stage.error || '';
    out.errorKind = stage.errorKind || 'unknown';
    return out;
  }
  return fallback;
}

function buildSkippedRuntimeStage_(stageName, reason) {
  return {
    ok: true,
    result: {
      stats: {
        skipped: true,
        stage: stageName || '',
        reason: reason || 'skipped',
        stoppedEarly: false
      }
    }
  };
}

function shouldRunFirestoreStagesAfterDrivePipeline_(runtimeGate, runtimeIndex) {
  if (hasRuntimeIndexFirestoreDirtyWork_(runtimeIndex)) return true;
  if (!runtimeGate) return false;
  if (runtimeGate.requiresFullPipeline) return true;
  if (runtimeGate.fallbackPipeline) return true;
  return false;
}

function hasRuntimeIndexFirestoreDirtyWork_(runtimeIndex) {
  runtimeIndex = runtimeIndex || {};
  var dirty = runtimeIndex.dirty || {};
  return !!((dirty.imports && dirty.imports.length) || (dirty.cfs && dirty.cfs.length));
}


function computeNeedsAnotherRunFromRuntimeIndex_(runtimeIndex, stages) {
  runtimeIndex = runtimeIndex || buildEmptyRuntimeIndex_(getPhboxConfig_());
  var dirtyPending = (runtimeIndex.dirty.imports || []).length + (runtimeIndex.dirty.cfs || []).length + (runtimeIndex.dirty.threads || []).length;
  if (dirtyPending > 0) return true;
  return (stages || []).some(function (stage) {
    if (!stage) return false;
    if (!stage.ok && stage.errorKind === 'transient') return true;
    var stats = stage.result && stage.result.stats ? stage.result.stats : null;
    if (!stats) return false;
    return !!(stats.stoppedEarly || stats.deferredUnits > 0 || stats.deferredBuilds > 0 || stats.deferredCandidates > 0 || stats.deferredGroups > 0);
  });
}
