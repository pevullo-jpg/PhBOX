function normalizeFinalActivePdfNames_(options) {
  options = options || {};
  var cfg = getPhboxConfig_();
  var rootFolder = DriveApp.getFolderById(cfg.folderId);
  var runtimeIndex = options.runtimeIndex || readRuntimeIndex_(rootFolder, cfg);
  var manifests = collectRuntimeManifests_(runtimeIndex);
  var contexts = buildFinalPdfRenameContexts_(manifests, cfg);
  var stats = {
    candidatesSeen: contexts.length,
    renamed: 0,
    manifestUpdatedOnly: 0,
    alreadyCanonical: 0,
    collisionFallbacks: 0,
    skippedMissing: 0,
    skippedTrashed: 0,
    skippedInvalid: 0,
    deferredCandidates: 0,
    stoppedEarly: false
  };

  var maxCandidatesPerRun = Math.max(0, Number(options.maxCandidatesPerRun || options.maxCandidates || 0));

  for (var i = 0; i < contexts.length; i++) {
    if (maxCandidatesPerRun > 0 && i >= maxCandidatesPerRun) {
      stats.deferredCandidates += (contexts.length - i);
      stats.stoppedEarly = true;
      break;
    }
    if (shouldStopForBudget_(options.budget, 25000)) {
      stats.deferredCandidates += (contexts.length - i);
      stats.stoppedEarly = true;
      break;
    }

    var outcome = applyFinalPdfRenameContext_(runtimeIndex, contexts[i], cfg);
    if (!outcome) {
      stats.skippedInvalid++;
      continue;
    }
    if (outcome.result === 'renamed') stats.renamed++;
    else if (outcome.result === 'manifest_updated_only') stats.manifestUpdatedOnly++;
    else if (outcome.result === 'already_canonical') stats.alreadyCanonical++;
    else if (outcome.result === 'missing_or_inaccessible') stats.skippedMissing++;
    else if (outcome.result === 'trashed') stats.skippedTrashed++;
    else stats.skippedInvalid++;

    if (outcome.usedCollisionFallback) {
      stats.collisionFallbacks++;
    }
  }

  return {
    runtimeIndex: runtimeIndex,
    stats: stats
  };
}

function buildFinalPdfRenameContexts_(manifests, cfg) {
  var candidates = (manifests || []).filter(function (manifest) {
    return isFinalActiveManifestForPdfRename_(manifest);
  }).map(function (manifest) {
    var baseName = buildFinalActivePdfFileName_(manifest);
    return {
      manifest: manifest,
      driveFileId: String((manifest && manifest.driveFileId) || '').trim(),
      folderId: String((manifest && manifest.parentFolderId) || cfg.folderId || '').trim(),
      baseName: baseName,
      assignedName: baseName,
      usedGroupFallback: false
    };
  }).filter(function (context) {
    return !!(context.driveFileId && context.folderId && context.baseName);
  });

  var grouped = {};
  candidates.forEach(function (context) {
    var key = context.folderId + '|' + context.baseName;
    if (!grouped[key]) grouped[key] = [];
    grouped[key].push(context);
  });

  Object.keys(grouped).forEach(function (key) {
    var group = grouped[key].slice().sort(function (a, b) {
      return String(a.driveFileId || '').localeCompare(String(b.driveFileId || ''));
    });
    for (var i = 0; i < group.length; i++) {
      if (i === 0) continue;
      group[i].assignedName = appendDeterministicSuffixToPdfName_(group[i].baseName, shortDeterministicFileId_(group[i].driveFileId));
      group[i].usedGroupFallback = true;
    }
  });

  return candidates.sort(function (a, b) {
    var aNeedsSync = !!(a.manifest && a.manifest.syncNeeded);
    var bNeedsSync = !!(b.manifest && b.manifest.syncNeeded);
    if (aNeedsSync !== bNeedsSync) return aNeedsSync ? -1 : 1;

    var aUpdated = parseDateValue_(a.manifest && a.manifest.updatedAt);
    var bUpdated = parseDateValue_(b.manifest && b.manifest.updatedAt);
    var aUpdatedMs = aUpdated ? aUpdated.getTime() : 0;
    var bUpdatedMs = bUpdated ? bUpdated.getTime() : 0;
    if (aUpdatedMs !== bUpdatedMs) return aUpdatedMs - bUpdatedMs;

    var folderDelta = String(a.folderId || '').localeCompare(String(b.folderId || ''));
    if (folderDelta !== 0) return folderDelta;
    if (!!a.usedGroupFallback !== !!b.usedGroupFallback) {
      return a.usedGroupFallback ? -1 : 1;
    }
    var nameDelta = String(a.assignedName || '').localeCompare(String(b.assignedName || ''));
    if (nameDelta !== 0) return nameDelta;
    return String(a.driveFileId || '').localeCompare(String(b.driveFileId || ''));
  });
}

function isFinalActiveManifestForPdfRename_(manifest) {
  return !!(
    manifest &&
    manifest.driveFileId &&
    normalizeCf_(manifest.patientFiscalCode) &&
    manifest.status === 'parsed' &&
    !manifest.pdfDeleted &&
    !manifest.deletePdfRequested &&
    (manifest.kind || '') !== 'merged_component' &&
    (manifest.kind || '') !== 'deleted_pdf' &&
    (manifest.kind || '') !== 'discarded_non_prescription'
  );
}

function buildFinalActivePdfFileName_(manifest) {
  var cf = normalizeCf_(manifest && manifest.patientFiscalCode);
  if (!cf) return '';
  var reliableDate = extractReliableInternalPrescriptionDateForNaming_(manifest);
  var datePart = reliableDate || 'NO_DATE';
  var dpcSuffix = manifest && manifest.isDpc ? '_DPC' : '';
  return cf + '_' + datePart + dpcSuffix + '.pdf';
}

function extractReliableInternalPrescriptionDateForNaming_(manifest) {
  var parsedDate = parseDateValue_(manifest && manifest.prescriptionDate);
  if (!parsedDate) return '';
  return formatDateIso_(parsedDate);
}

function applyFinalPdfRenameContext_(runtimeIndex, context, cfg) {
  if (!context || !context.manifest || !context.driveFileId || !context.assignedName) {
    return { result: 'invalid', usedCollisionFallback: false };
  }

  var manifest = context.manifest;
  var file = null;
  try {
    file = runWithRetryOnTransient_(function () {
      return DriveApp.getFileById(context.driveFileId);
    }, {
      attempts: 3,
      baseSleepMs: 250
    });
  } catch (e) {
    var missingKind = classifyRuntimeFailureKind_(e);
    if (missingKind === 'resource_access') {
      logInfo_(cfg, 'Rinomina finale saltata: file assente o non accessibile', {
        driveFileId: context.driveFileId,
        fileName: manifest.fileName || '',
        error: normalizeRuntimeErrorMessage_(e)
      });
      return { result: 'missing_or_inaccessible', usedCollisionFallback: context.usedGroupFallback };
    }
    throw e;
  }

  var isTrashed = runWithRetryOnTransient_(function () {
    return file.isTrashed();
  }, {
    attempts: 3,
    baseSleepMs: 150
  });
  if (isTrashed) {
    return { result: 'trashed', usedCollisionFallback: context.usedGroupFallback };
  }

  var parentFolder = resolveRenameTargetFolder_(file, manifest, cfg);
  var desiredName = resolveAvailableFinalPdfFileName_(parentFolder, context.assignedName, context.driveFileId);
  var usedCollisionFallback = context.usedGroupFallback || desiredName !== context.baseName;
  var currentDriveName = runWithRetryOnTransient_(function () {
    return file.getName();
  }, {
    attempts: 3,
    baseSleepMs: 150
  });

  var renamed = false;
  if (currentDriveName !== desiredName) {
    runWithRetryOnTransient_(function () {
      file.setName(desiredName);
      return true;
    }, {
      attempts: 3,
      baseSleepMs: 250
    });
    renamed = true;
  }

  var refreshedFile = renamed ? runWithRetryOnTransient_(function () {
    return DriveApp.getFileById(context.driveFileId);
  }, {
    attempts: 3,
    baseSleepMs: 150
  }) : file;

  var actualName = runWithRetryOnTransient_(function () {
    return refreshedFile.getName();
  }, {
    attempts: 3,
    baseSleepMs: 150
  });
  var driveUpdatedAt = safeIsoString_(runWithRetryOnTransient_(function () {
    return refreshedFile.getLastUpdated();
  }, {
    attempts: 3,
    baseSleepMs: 150
  }));

  var manifestChanged = false;
  if ((manifest.fileName || '') !== actualName) {
    manifest.fileName = actualName;
    manifestChanged = true;
  }
  if ((manifest.parentFolderId || '') !== parentFolder.getId()) {
    manifest.parentFolderId = parentFolder.getId();
    manifestChanged = true;
  }
  if ((manifest.parentFolderName || '') !== parentFolder.getName()) {
    manifest.parentFolderName = parentFolder.getName();
    manifestChanged = true;
  }
  if (driveUpdatedAt && (manifest.driveUpdatedAt || '') !== driveUpdatedAt) {
    manifest.driveUpdatedAt = driveUpdatedAt;
    manifestChanged = true;
  }

  if (manifestChanged || renamed) {
    manifest.updatedAt = new Date().toISOString();
    manifest.syncNeeded = true;
    upsertRuntimeManifestInIndex_(runtimeIndex, manifest, { markDirty: true });
  }

  if (renamed) {
    return { result: 'renamed', usedCollisionFallback: usedCollisionFallback };
  }
  if (manifestChanged) {
    return { result: 'manifest_updated_only', usedCollisionFallback: usedCollisionFallback };
  }
  return { result: 'already_canonical', usedCollisionFallback: usedCollisionFallback };
}

function resolveRenameTargetFolder_(file, manifest, cfg) {
  var targetFolderId = String((manifest && manifest.parentFolderId) || cfg.folderId || '').trim();
  if (targetFolderId) {
    try {
      return runWithRetryOnTransient_(function () {
        return DriveApp.getFolderById(targetFolderId);
      }, {
        attempts: 3,
        baseSleepMs: 150
      });
    } catch (_) {}
  }
  var parents = file.getParents();
  if (parents.hasNext()) return parents.next();
  return DriveApp.getFolderById(cfg.folderId);
}

function resolveAvailableFinalPdfFileName_(folder, desiredName, selfDriveFileId) {
  var assignedName = String(desiredName || '').trim();
  if (!assignedName) return '';
  var existing = folder.getFilesByName(assignedName);
  while (existing.hasNext()) {
    var other = existing.next();
    if (String(other.getId() || '') === String(selfDriveFileId || '')) return assignedName;
    assignedName = appendDeterministicSuffixToPdfName_(desiredName, shortDeterministicFileId_(selfDriveFileId));
    break;
  }
  return assignedName;
}

function appendDeterministicSuffixToPdfName_(baseName, suffixToken) {
  var cleanBase = String(baseName || '').replace(/\.pdf$/i, '');
  var cleanSuffix = String(suffixToken || '').trim();
  if (!cleanSuffix) return cleanBase + '.pdf';
  return cleanBase + '__' + cleanSuffix + '.pdf';
}

function shortDeterministicFileId_(driveFileId) {
  return String(driveFileId || '').replace(/[^A-Za-z0-9]/g, '').substring(0, 8) || 'dup';
}
