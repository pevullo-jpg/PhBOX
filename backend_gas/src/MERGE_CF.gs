async function canonicalizeParsedManifestsPerCf_(options) {
  options = options || {};
  var cfg = getPhboxConfig_();
  var rootFolder = DriveApp.getFolderById(cfg.folderId);
  var runtimeIndex = options.runtimeIndex || readRuntimeIndex_(rootFolder, cfg);
  var manifests = collectRuntimeManifests_(runtimeIndex);
  var active = manifests.filter(function (item) {
    return isActiveManifestCandidateForCanonicalization_(item);
  });

  var groups = {};
  active.forEach(function (item) {
    var cf = normalizeCf_(item.patientFiscalCode);
    if (!cf) return;
    if (!groups[cf]) groups[cf] = [];
    groups[cf].push(item);
  });

  var stats = {
    groupsSeen: Object.keys(groups).length,
    groupsMerged: 0,
    groupsPromotedSingle: 0,
    filesWritten: 0,
    componentsSuperseded: 0,
    noOpGroups: 0,
    deferredGroups: 0,
    stoppedEarly: false
  };

  var configuredMergeBudget = Math.max(1, Number(cfg.maxMergeGroupsPerRun || Object.keys(groups).length || 1));
  var requestedMergeBudget = Number(options.maxGroupsPerRun || options.maxGroups || 0);
  var mutationBudget = requestedMergeBudget > 0
    ? Math.max(1, Math.min(configuredMergeBudget, requestedMergeBudget))
    : configuredMergeBudget;
  var mutationsDone = 0;
  var cfKeys = Object.keys(groups).sort(function (a, b) {
    return compareCfCanonicalizationPriority_(groups[a], groups[b]);
  });

  for (var i = 0; i < cfKeys.length; i++) {
    var cf = cfKeys[i];
    var candidates = groups[cf].slice().sort(compareManifestByDateDesc_);
    var canonical = findCurrentCanonicalManifest_(candidates);
    var raws = candidates.filter(function (item) {
      return !canonical || item.driveFileId !== canonical.driveFileId;
    });

    var plan = buildCanonicalizationPlan_(canonical, raws, cf);
    var action = determineCanonicalAction_(canonical, plan, cf);
    if (action.type === 'noop') {
      stats.noOpGroups++;
      continue;
    }

    if (mutationsDone >= mutationBudget || shouldStopForBudget_(options.budget, 45000)) {
      stats.deferredGroups++;
      stats.stoppedEarly = true;
      continue;
    }

    if (action.type === 'promote_single') {
      promoteSingleRawManifestToCanonical_(runtimeIndex, action.winner, action.plan.desiredSourceKeys, action.plan.desiredPrescriptionKeys, action.plan.desiredDuplicateFingerprintKeys, action.plan.desiredSignature, cf);
      action.plan.redundantContributors.forEach(function (item) {
        markManifestAsMergedComponent_(runtimeIndex, item, action.winner, cfg);
        stats.componentsSuperseded++;
      });
      stats.groupsPromotedSingle++;
      mutationsDone++;
      continue;
    }

    if (action.type === 'refresh_canonical_metadata') {
      if (ensureCanonicalManifestMetadata_(runtimeIndex, canonical, action.plan.desiredSourceKeys, action.plan.desiredPrescriptionKeys, action.plan.desiredDuplicateFingerprintKeys, action.plan.desiredSignature, cf)) {
        stats.groupsPromotedSingle++;
        mutationsDone++;
      } else {
        stats.noOpGroups++;
      }
      continue;
    }

    if (action.type === 'absorb_into_existing') {
      var changed = ensureCanonicalManifestMetadata_(runtimeIndex, canonical, action.plan.desiredSourceKeys, action.plan.desiredPrescriptionKeys, action.plan.desiredDuplicateFingerprintKeys, action.plan.desiredSignature, cf);
      action.plan.redundantContributors.forEach(function (item) {
        markManifestAsMergedComponent_(runtimeIndex, item, canonical, cfg);
        stats.componentsSuperseded++;
      });
      if (changed || action.plan.redundantContributors.length) {
        mutationsDone++;
      }
      stats.groupsPromotedSingle++;
      continue;
    }

    try {
      var contributors = action.plan.selectedContributors.slice();
      var targetFolderId = resolveCanonicalParentFolderId_(rootFolder, canonical, raws);
      var targetFolder = DriveApp.getFolderById(targetFolderId);
      var latestPrescriptionDate = chooseLatestPrescriptionDate_(contributors);
      var canonicalFileName = buildMergedCfFileName_(cf, latestPrescriptionDate, contributors);
      var mergeInputIds = buildMergeInputFileIdsFromContributors_(contributors);
      var mergedBlob = await mergePdfFilesWithPdfLib_(mergeInputIds);
      var canonicalFile = runWithRetryOnTransient_(function () {
        return targetFolder.createFile(mergedBlob.copyBlob().setName(canonicalFileName));
      }, {
        attempts: 3,
        baseSleepMs: 500
      });
      var canonicalManifest = buildCanonicalManifestFromContributors_(canonicalFile, contributors, action.plan.desiredSourceKeys, action.plan.desiredPrescriptionKeys, action.plan.desiredDuplicateFingerprintKeys, action.plan.desiredSignature, cf, targetFolder, cfg);
      upsertRuntimeManifestInIndex_(runtimeIndex, canonicalManifest, { markDirty: true });

      action.plan.selectedContributors.concat(action.plan.redundantContributors).forEach(function (item) {
        markManifestAsMergedComponent_(runtimeIndex, item, canonicalManifest, cfg);
        stats.componentsSuperseded++;
      });

      stats.groupsMerged++;
      stats.filesWritten++;
      mutationsDone++;
    } catch (e) {
      if (isRetryableRuntimeFailure_(e)) {
        stats.deferredGroups++;
        stats.stoppedEarly = true;
        logInfo_(cfg, 'Merge CF rinviato per errore transitorio', {
          cf: cf,
          error: normalizeRuntimeErrorMessage_(e)
        });
        continue;
      }
      throw e;
    }
  }

  return {
    runtimeIndex: runtimeIndex,
    stats: stats
  };
}

function determineCanonicalAction_(canonical, plan, cf) {
  plan = plan || buildCanonicalizationPlan_(canonical, [], cf);
  var selected = plan.selectedContributors || [];
  var redundant = plan.redundantContributors || [];

  if (!canonical && selected.length === 1) {
    return { type: 'promote_single', winner: selected[0], plan: plan };
  }

  if (canonical && selected.length === 1 && selected[0].driveFileId === canonical.driveFileId) {
    var needsMetadataRefresh = canonicalNeedsMetadataRefresh_(canonical, plan, cf);
    if (redundant.length) {
      return { type: 'absorb_into_existing', plan: plan, refreshMetadata: needsMetadataRefresh };
    }
    return { type: needsMetadataRefresh ? 'refresh_canonical_metadata' : 'noop', plan: plan };
  }

  if (!canonical && selected.length === 0) {
    return { type: 'noop', plan: plan };
  }

  return { type: 'merge', plan: plan };
}

function canonicalNeedsMetadataRefresh_(canonical, plan, cf) {
  if (!canonical) return false;
  return (
    canonical.kind !== 'canonical_cf_pdf' ||
    (canonical.canonicalGroupKey || '') !== cf ||
    (canonical.canonicalFileId || '') !== canonical.driveFileId ||
    (canonical.mergeSignature || '') !== (plan.desiredSignature || '') ||
    JSON.stringify(canonical.componentSourceKeys || []) !== JSON.stringify(plan.desiredSourceKeys || []) ||
    JSON.stringify(canonical.componentFileIds || []) !== JSON.stringify([canonical.driveFileId]) ||
    JSON.stringify(canonical.componentDuplicateFingerprintKeys || []) !== JSON.stringify(plan.desiredDuplicateFingerprintKeys || []) ||
    JSON.stringify(canonical.prescriptionIdentityKeys || []) !== JSON.stringify(plan.desiredPrescriptionKeys || []) ||
    Number(canonical.representedSourceCount || 0) !== (plan.desiredSourceKeys || []).length ||
    Number(canonical.prescriptionCount || 0) !== Math.max(1, (plan.desiredPrescriptionKeys || []).length) ||
    canonical.pdfDeleted === true ||
    canonical.status !== 'parsed'
  );
}

function buildCanonicalizationPlan_(canonical, raws, cf) {
  var selection = selectCanonicalContributors_(canonical, raws);
  var desiredPrescriptionKeys = collectContributorPrescriptionKeys_(selection.selectedContributors);
  return {
    selectedContributors: selection.selectedContributors,
    redundantContributors: selection.redundantContributors,
    desiredSourceKeys: collectContributorSourceKeys_(selection.selectedContributors),
    desiredPrescriptionKeys: desiredPrescriptionKeys,
    desiredDuplicateFingerprintKeys: collectContributorDuplicateFingerprintKeys_(selection.selectedContributors),
    desiredSignature: buildMergeSignature_(cf, desiredPrescriptionKeys)
  };
}

function selectCanonicalContributors_(canonical, raws) {
  var candidates = [];
  if (canonical) candidates.push(canonical);
  (raws || []).forEach(function (item) { candidates.push(item); });
  candidates.sort(compareManifestCanonicalContributionPriority_);

  var selected = [];
  var redundant = [];
  var seenPrescriptionKeys = {};
  var seenDuplicateFingerprintKeys = {};

  candidates.forEach(function (item) {
    var prescriptionKeys = getManifestPrescriptionKeys_(item);
    var duplicateFingerprintKeys = getManifestDuplicateFingerprintKeys_(item);
    var overlapsDuplicateFingerprint = duplicateFingerprintKeys.some(function (key) {
      return !!seenDuplicateFingerprintKeys[key];
    });
    var contributesNew = prescriptionKeys.some(function (key) {
      return !seenPrescriptionKeys[key];
    });

    if ((overlapsDuplicateFingerprint || !contributesNew) && selected.length) {
      redundant.push(item);
      return;
    }

    selected.push(item);
    prescriptionKeys.forEach(function (key) {
      seenPrescriptionKeys[key] = true;
    });
    duplicateFingerprintKeys.forEach(function (key) {
      seenDuplicateFingerprintKeys[key] = true;
    });
  });

  return {
    selectedContributors: selected,
    redundantContributors: redundant
  };
}

function compareManifestCanonicalContributionPriority_(a, b) {
  var aCanonical = (a && a.kind === 'canonical_cf_pdf') ? 1 : 0;
  var bCanonical = (b && b.kind === 'canonical_cf_pdf') ? 1 : 0;
  if (bCanonical !== aCanonical) return bCanonical - aCanonical;

  var aPrescriptionKeys = getManifestPrescriptionKeys_(a).length;
  var bPrescriptionKeys = getManifestPrescriptionKeys_(b).length;
  if (bPrescriptionKeys !== aPrescriptionKeys) return bPrescriptionKeys - aPrescriptionKeys;

  var aSourceKeys = getManifestSourceKeys_(a).length;
  var bSourceKeys = getManifestSourceKeys_(b).length;
  if (bSourceKeys !== aSourceKeys) return bSourceKeys - aSourceKeys;

  return compareManifestByDateDesc_(a, b);
}

function collectContributorSourceKeys_(contributors) {
  var out = [];
  var seen = {};
  (contributors || []).forEach(function (item) {
    (getManifestSourceKeys_(item) || []).forEach(function (key) {
      var value = String(key || '').trim();
      if (!value || seen[value]) return;
      seen[value] = true;
      out.push(value);
    });
  });
  return out;
}

function collectContributorPrescriptionKeys_(contributors) {
  var out = [];
  var seen = {};
  (contributors || []).forEach(function (item) {
    (getManifestPrescriptionKeys_(item) || []).forEach(function (key) {
      var value = String(key || '').trim();
      if (!value || seen[value]) return;
      seen[value] = true;
      out.push(value);
    });
  });
  return out;
}

function collectContributorDuplicateFingerprintKeys_(contributors) {
  var out = [];
  var seen = {};
  (contributors || []).forEach(function (item) {
    (getManifestDuplicateFingerprintKeys_(item) || []).forEach(function (key) {
      var value = String(key || '').trim();
      if (!value || seen[value]) return;
      seen[value] = true;
      out.push(value);
    });
  });
  return out;
}

function compareCfCanonicalizationPriority_(groupA, groupB) {
  var scoreA = calculateCanonicalizationPriorityScore_(groupA || []);
  var scoreB = calculateCanonicalizationPriorityScore_(groupB || []);
  if (scoreB !== scoreA) return scoreB - scoreA;
  var cfA = normalizeCf_((groupA && groupA[0] && groupA[0].patientFiscalCode) || '');
  var cfB = normalizeCf_((groupB && groupB[0] && groupB[0].patientFiscalCode) || '');
  return cfA.localeCompare(cfB);
}

function calculateCanonicalizationPriorityScore_(group) {
  var canonicalCount = 0;
  var rawCount = 0;
  var latestTouched = 0;
  (group || []).forEach(function (manifest) {
    if ((manifest.kind || '') === 'canonical_cf_pdf') canonicalCount++;
    else rawCount++;
    var touched = parseDateValue_(manifest.updatedAt) || parseDateValue_(manifest.driveUpdatedAt) || parseDateValue_(manifest.prescriptionDate) || new Date(0);
    latestTouched = Math.max(latestTouched, touched.getTime());
  });
  return (rawCount * 1000000) + (canonicalCount === 0 ? 100000 : 0) + latestTouched;
}

function isActiveManifestCandidateForCanonicalization_(manifest) {
  if (!manifest || manifest.status !== 'parsed' || manifest.pdfDeleted || !manifest.patientFiscalCode || !manifest.driveFileId) return false;
  if (manifest.kind === 'merged_component') return false;
  return true;
}

function findCurrentCanonicalManifest_(candidates) {
  for (var i = 0; i < (candidates || []).length; i++) {
    if ((candidates[i].kind || '') === 'canonical_cf_pdf') return candidates[i];
  }
  return null;
}

function getManifestSourceKeys_(manifest) {
  if (!manifest) return [];
  if (Array.isArray(manifest.componentSourceKeys) && manifest.componentSourceKeys.length) {
    return manifest.componentSourceKeys.slice();
  }
  return [buildManifestOwnSourceKey_(manifest)];
}

function getManifestPrescriptionKeys_(manifest) {
  if (!manifest) return [];
  if (Array.isArray(manifest.prescriptionIdentityKeys) && manifest.prescriptionIdentityKeys.length) {
    return uniqueNonEmptyStrings_(manifest.prescriptionIdentityKeys);
  }
  if (Array.isArray(manifest.prescriptionNres) && manifest.prescriptionNres.length) {
    return uniqueNonEmptyStrings_(manifest.prescriptionNres).map(function (nre) {
      var normalized = normalizePrescriptionNre_(nre);
      return normalized ? 'NRE:' + normalized : '';
    }).filter(function (key) {
      return key;
    });
  }

  var count = Math.max(1, Number(manifest.prescriptionCount || 1));
  var baseKey = 'FILE:' + buildManifestOwnSourceKey_(manifest);
  if (count === 1) return [baseKey];

  var out = [];
  for (var i = 0; i < count; i++) {
    out.push(baseKey + '#' + String(i + 1));
  }
  return out;
}

function getManifestDuplicateFingerprintKeys_(manifest) {
  if (!manifest) return [];
  if (Array.isArray(manifest.componentDuplicateFingerprintKeys) && manifest.componentDuplicateFingerprintKeys.length) {
    return uniqueNonEmptyStrings_(manifest.componentDuplicateFingerprintKeys);
  }
  var fingerprint = String(manifest.prescriptionTextFingerprint || '').trim();
  return fingerprint ? ['DOC:' + fingerprint] : [];
}

function buildManifestOwnSourceKey_(manifest) {
  return String(manifest.driveFileId || manifest.id || '') + '@' + String(manifest.driveUpdatedAt || manifest.updatedAt || manifest.createdAt || 'NA');
}

function buildMergeSignature_(cf, sourceKeys) {
  return normalizeCf_(cf) + '|' + (sourceKeys || []).slice().sort().join('|');
}

function extractPrescriptionNresFromIdentityKeys_(identityKeys) {
  return uniqueNonEmptyStrings_((identityKeys || []).map(function (key) {
    var match = String(key || '').match(/^NRE:(\d{12})$/i);
    return match && match[1] ? match[1] : '';
  }).filter(function (item) {
    return item;
  }));
}

function promoteSingleRawManifestToCanonical_(runtimeIndex, manifest, desiredSourceKeys, desiredPrescriptionKeys, desiredDuplicateFingerprintKeys, desiredSignature, cf) {
  manifest.kind = 'canonical_cf_pdf';
  manifest.status = 'parsed';
  manifest.analysisOutcome = 'valid_prescription';
  manifest.pdfDeleted = false;
  manifest.canonicalGroupKey = cf;
  manifest.canonicalFileId = manifest.driveFileId;
  manifest.mergeSignature = desiredSignature;
  manifest.componentFileIds = [manifest.driveFileId];
  manifest.componentSourceKeys = desiredSourceKeys.slice();
  manifest.componentDuplicateFingerprintKeys = desiredDuplicateFingerprintKeys.slice();
  manifest.representedSourceCount = desiredSourceKeys.length;
  manifest.prescriptionIdentityKeys = desiredPrescriptionKeys.slice();
  manifest.prescriptionNres = extractPrescriptionNresFromIdentityKeys_(desiredPrescriptionKeys);
  manifest.prescriptionCount = Math.max(1, desiredPrescriptionKeys.length);
  manifest.supersededByCanonical = '';
  manifest.mergedAt = null;
  manifest.syncNeeded = true;
  manifest.updatedAt = new Date().toISOString();
  upsertRuntimeManifestInIndex_(runtimeIndex, manifest, { markDirty: true });
}

function ensureCanonicalManifestMetadata_(runtimeIndex, manifest, desiredSourceKeys, desiredPrescriptionKeys, desiredDuplicateFingerprintKeys, desiredSignature, cf) {
  var changed = false;
  if (manifest.kind !== 'canonical_cf_pdf') {
    manifest.kind = 'canonical_cf_pdf';
    changed = true;
  }
  if ((manifest.canonicalGroupKey || '') !== cf) {
    manifest.canonicalGroupKey = cf;
    changed = true;
  }
  if ((manifest.canonicalFileId || '') !== manifest.driveFileId) {
    manifest.canonicalFileId = manifest.driveFileId;
    changed = true;
  }
  if ((manifest.mergeSignature || '') !== desiredSignature) {
    manifest.mergeSignature = desiredSignature;
    changed = true;
  }
  if (JSON.stringify(manifest.componentSourceKeys || []) !== JSON.stringify(desiredSourceKeys)) {
    manifest.componentSourceKeys = desiredSourceKeys.slice();
    changed = true;
  }
  if (JSON.stringify(manifest.componentFileIds || []) !== JSON.stringify([manifest.driveFileId])) {
    manifest.componentFileIds = [manifest.driveFileId];
    changed = true;
  }
  if (JSON.stringify(manifest.componentDuplicateFingerprintKeys || []) !== JSON.stringify(desiredDuplicateFingerprintKeys)) {
    manifest.componentDuplicateFingerprintKeys = desiredDuplicateFingerprintKeys.slice();
    changed = true;
  }
  if (JSON.stringify(manifest.prescriptionIdentityKeys || []) !== JSON.stringify(desiredPrescriptionKeys)) {
    manifest.prescriptionIdentityKeys = desiredPrescriptionKeys.slice();
    changed = true;
  }
  var desiredNres = extractPrescriptionNresFromIdentityKeys_(desiredPrescriptionKeys);
  if (JSON.stringify(manifest.prescriptionNres || []) !== JSON.stringify(desiredNres)) {
    manifest.prescriptionNres = desiredNres;
    changed = true;
  }
  var desiredPrescriptionCount = Math.max(1, desiredPrescriptionKeys.length);
  if ((manifest.prescriptionCount || 0) !== desiredPrescriptionCount) {
    manifest.prescriptionCount = desiredPrescriptionCount;
    changed = true;
  }
  if ((manifest.representedSourceCount || 0) !== desiredSourceKeys.length) {
    manifest.representedSourceCount = desiredSourceKeys.length;
    changed = true;
  }
  if (changed) {
    manifest.syncNeeded = true;
    manifest.updatedAt = new Date().toISOString();
    upsertRuntimeManifestInIndex_(runtimeIndex, manifest, { markDirty: true });
  }
  return changed;
}

function buildMergeInputFileIdsFromContributors_(contributors) {
  var ids = [];
  var seen = {};
  function pushId_(id) {
    id = String(id || '').trim();
    if (!id || seen[id]) return;
    seen[id] = true;
    ids.push(id);
  }
  (contributors || []).forEach(function (item) { pushId_(item && item.driveFileId); });
  return ids;
}

function resolveCanonicalParentFolderId_(rootFolder, canonical, raws) {
  if (canonical && canonical.parentFolderId) return canonical.parentFolderId;
  var sortedRaws = (raws || []).slice().sort(compareManifestByDateDesc_);
  for (var i = 0; i < sortedRaws.length; i++) {
    if (sortedRaws[i].parentFolderId) return sortedRaws[i].parentFolderId;
  }
  return rootFolder.getId();
}

function buildCanonicalManifestFromContributors_(canonicalFile, contributors, desiredSourceKeys, desiredPrescriptionKeys, desiredDuplicateFingerprintKeys, desiredSignature, cf, parentFolder, cfg) {
  contributors = (contributors || []).slice().sort(compareManifestByDateDesc_);
  var latestDateIso = chooseLatestPrescriptionDate_(contributors);
  var exemptions = uniqueNonEmptyStrings_(contributors.reduce(function (acc, item) {
    return acc.concat(item.exemptions || [], item.exemptionCode || '');
  }, []));
  var therapies = uniqueNonEmptyStrings_(contributors.reduce(function (acc, item) {
    return acc.concat(item.therapy || []);
  }, []));
  var totalRecipes = Math.max(1, (desiredPrescriptionKeys || []).length);
  var earliestCreatedAt = contributors.reduce(function (current, item) {
    if (!current) return item.createdAt || null;
    if (item.createdAt && item.createdAt < current) return item.createdAt;
    return current;
  }, null);
  var nowIso = new Date().toISOString();
  return ensureRuntimeManifestShape_({
    version: 1,
    parserVersion: Number(cfg.parserVersion || 1),
    id: canonicalFile.getId(),
    driveFileId: canonicalFile.getId(),
    fileName: canonicalFile.getName(),
    mimeType: canonicalFile.getMimeType() || MimeType.PDF,
    driveUpdatedAt: safeIsoString_(canonicalFile.getLastUpdated()),
    createdAt: earliestCreatedAt || nowIso,
    updatedAt: nowIso,
    syncedAt: null,
    syncNeeded: true,
    status: 'parsed',
    kind: 'canonical_cf_pdf',
    analysisOutcome: 'valid_prescription',
    canonicalGroupKey: cf,
    canonicalFileId: canonicalFile.getId(),
    mergeSignature: desiredSignature,
    componentFileIds: collectContributorFileIds_(contributors),
    componentSourceKeys: desiredSourceKeys.slice(),
    componentDuplicateFingerprintKeys: desiredDuplicateFingerprintKeys.slice(),
    representedSourceCount: desiredSourceKeys.length,
    supersededByCanonical: '',
    mergedAt: nowIso,
    errorMessage: '',
    patientFiscalCode: normalizeCf_(cf),
    patientFullName: choosePreferredValue_(contributors.map(function (item) { return item.patientFullName; })) || '',
    doctorFullName: choosePreferredValue_(contributors.map(function (item) { return item.doctorFullName; })) || '',
    exemptionCode: exemptions.length ? exemptions[0] : '',
    exemptions: exemptions,
    city: choosePreferredValue_(contributors.map(function (item) { return item.city; })) || '',
    therapy: therapies,
    isDpc: contributors.some(function (item) { return !!item.isDpc; }),
    prescriptionNres: extractPrescriptionNresFromIdentityKeys_(desiredPrescriptionKeys),
    prescriptionIdentityKeys: desiredPrescriptionKeys.slice(),
    prescriptionCount: totalRecipes,
    prescriptionDate: latestDateIso ? String(latestDateIso).substring(0, 10) : '',
    filenameFiscalCode: normalizeCf_(cf),
    filenamePrescriptionDate: latestDateIso ? String(latestDateIso).substring(0, 10) : '',
    filenameContentMismatch: false,
    parentFolderId: parentFolder.getId(),
    parentFolderName: parentFolder.getName(),
    webViewLink: canonicalFile.getUrl(),
    pdfDeleted: false,
    sourceType: cfg.sourceType,
    rawTextPreview: ''
  }, cfg);
}

function markManifestAsMergedComponent_(runtimeIndex, manifest, canonicalManifest, cfg) {
  if (!manifest || !manifest.driveFileId) return;
  var nowIso = new Date().toISOString();
  manifest.kind = 'merged_component';
  manifest.status = 'merged_component';
  manifest.analysisOutcome = 'valid_prescription';
  manifest.pdfDeleted = true;
  manifest.webViewLink = '';
  manifest.syncNeeded = true;
  manifest.updatedAt = nowIso;
  manifest.mergedAt = nowIso;
  manifest.supersededByCanonical = canonicalManifest.driveFileId;
  manifest.canonicalFileId = canonicalManifest.driveFileId;
  manifest.canonicalGroupKey = canonicalManifest.canonicalGroupKey || normalizeCf_(manifest.patientFiscalCode);
  upsertRuntimeManifestInIndex_(runtimeIndex, manifest, { markDirty: true });
  try {
    DriveApp.getFileById(manifest.driveFileId).setTrashed(true);
  } catch (e) {
    logInfo_(cfg, 'Impossibile cestinare componente merged', { driveFileId: manifest.driveFileId, error: String(e) });
  }
}

function collectContributorFileIds_(contributors) {
  var out = [];
  var seen = {};
  (contributors || []).forEach(function (item) {
    var ids = [];
    if (Array.isArray(item.componentFileIds) && item.componentFileIds.length) {
      ids = item.componentFileIds.slice();
    } else if (item.driveFileId) {
      ids = [item.driveFileId];
    }
    ids.forEach(function (id) {
      var value = String(id || '').trim();
      if (!value || seen[value]) return;
      seen[value] = true;
      out.push(value);
    });
  });
  return out;
}

function buildMergedCfFileName_(cf, latestDateIso, manifestsForCf) {
  var datePart = latestDateIso ? String(latestDateIso).substring(0, 10) : 'NO_DATE';
  var dpcSuffix = (manifestsForCf || []).some(function (item) { return !!item.isDpc; }) ? '_DPC' : '';
  return cf + '_' + datePart + dpcSuffix + '.pdf';
}

async function mergePdfFilesWithPdfLib_(ids) {
  if (!ids || !ids.length) throw new Error('Nessun file ID passato a mergePdfFilesWithPdfLib_.');

  var data = ids.map(function (id) {
    return new Uint8Array(DriveApp.getFileById(id).getBlob().getBytes());
  });

  var cdnjs = 'https://cdn.jsdelivr.net/npm/pdf-lib/dist/pdf-lib.min.js';
  var js = runWithRetryOnTransient_(function () {
    return UrlFetchApp.fetch(cdnjs).getContentText();
  }, {
    attempts: 3,
    baseSleepMs: 400
  }).replace(/setTimeout\(.*?,.*?(\d*?)\)/g, 'Utilities.sleep($1);return t();');
  eval(js);

  var pdfDoc = await PDFLib.PDFDocument.create();
  for (var i = 0; i < data.length; i++) {
    var sourcePdf = await PDFLib.PDFDocument.load(data[i]);
    var indexes = [];
    for (var j = 0; j < sourcePdf.getPageCount(); j++) indexes.push(j);
    var pages = await pdfDoc.copyPages(sourcePdf, indexes);
    pages.forEach(function (page) { pdfDoc.addPage(page); });
  }

  var bytes = await pdfDoc.save();
  return Utilities.newBlob([].slice.call(new Int8Array(bytes)), MimeType.PDF, 'merged.pdf');
}
