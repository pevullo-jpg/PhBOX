function consumePendingArchiveDeleteRequests_(options) {
  options = options || {};
  var cfg = getPhboxConfig_();
  var rootFolder = DriveApp.getFolderById(cfg.folderId);
  var runtimeIndex = options.runtimeIndex || readRuntimeIndex_(rootFolder, cfg);
  var maxRequests = Math.max(1, Number(cfg.maxBatchWrites || 50));
  var requests = listPendingArchiveDeleteRequests_(cfg, maxRequests);
  var stats = {
    requestsSeen: requests.length,
    requestsConsumed: 0,
    missingManifestRecovered: 0,
    driveDeleted: 0,
    driveAlreadyMissing: 0,
    invalidRequests: 0,
    stoppedEarly: false
  };

  for (var i = 0; i < requests.length; i++) {
    if (shouldStopForBudget_(options.budget, 30000)) {
      stats.stoppedEarly = true;
      break;
    }

    var request = requests[i] || {};
    var driveFileId = resolveArchiveDeleteDriveFileId_(request);
    if (!driveFileId) {
      stats.invalidRequests++;
      continue;
    }

    var manifest = runtimeIndex.filesById[driveFileId] ? ensureRuntimeManifestShape_(runtimeIndex.filesById[driveFileId], cfg) : null;
    if (!manifest) {
      manifest = buildDeletedManifestFromDeleteRequest_(request, driveFileId, cfg);
      stats.missingManifestRecovered++;
    }

    var driveResult = trashArchivePdfIfPresent_(driveFileId, cfg);
    if (driveResult.deleted) stats.driveDeleted++;
    if (driveResult.alreadyMissing) stats.driveAlreadyMissing++;

    finalizeManifestAsDeletedPdf_(manifest, request, driveFileId);
    upsertRuntimeManifestInIndex_(runtimeIndex, manifest, { markDirty: true });
    stats.requestsConsumed++;
  }

  if (requests.length >= maxRequests) {
    stats.stoppedEarly = true;
  }

  return {
    runtimeIndex: runtimeIndex,
    deleteRequests: requests,
    stats: stats
  };
}

function listPendingArchiveDeleteRequests_(cfg, limit) {
  var url = 'https://firestore.googleapis.com/v1/projects/' + encodeURIComponent(cfg.firestoreProjectId) + '/databases/(default)/documents:runQuery';
  var payload = {
    structuredQuery: {
      from: [{ collectionId: 'drive_pdf_imports' }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'deletePdfRequested' },
          op: 'EQUAL',
          value: { booleanValue: true }
        }
      },
      orderBy: [{ field: { fieldPath: 'updatedAt' }, direction: 'ASCENDING' }],
      limit: Math.max(1, Number(limit || 1))
    }
  };
  var response = UrlFetchApp.fetch(url, {
    method: 'post',
    muteHttpExceptions: true,
    contentType: 'application/json',
    headers: {
      Authorization: 'Bearer ' + ScriptApp.getOAuthToken()
    },
    payload: JSON.stringify(payload)
  });

  var code = response.getResponseCode();
  var body = response.getContentText() || '';
  if (code < 200 || code >= 300) {
    throw new Error('Firestore runQuery deletePdfRequested failed [' + code + '] ' + body);
  }

  var parsed = parseJsonSafe_(body);
  if (!Array.isArray(parsed)) return [];

  return parsed.map(function (row) {
    if (!row || !row.document) return null;
    var document = row.document;
    var data = fromFirestoreFields_(document.fields || {});
    data.documentName = document.name || '';
    data.documentId = extractFirestoreDocumentId_(document.name || '');
    return data;
  }).filter(function (item) {
    return !!item;
  });
}

function resolveArchiveDeleteDriveFileId_(request) {
  return String(
    (request && (request.driveFileId || request.fileId || request.id || request.documentId)) || ''
  ).trim();
}

function buildDeletedManifestFromDeleteRequest_(request, driveFileId, cfg) {
  var nowIso = new Date().toISOString();
  var patientFiscalCode = normalizeCf_(request && request.patientFiscalCode);
  var exemptions = uniqueNonEmptyStrings_([
    request && request.exemption,
    request && request.exemptionCode
  ].concat((request && request.exemptions) || []));
  return ensureRuntimeManifestShape_({
    version: 1,
    parserVersion: Number(cfg.parserVersion || 1),
    id: driveFileId,
    driveFileId: driveFileId,
    fileName: String((request && request.fileName) || '').trim(),
    mimeType: String((request && request.mimeType) || MimeType.PDF),
    driveUpdatedAt: null,
    createdAt: request && request.createdAt ? request.createdAt : nowIso,
    updatedAt: nowIso,
    syncedAt: null,
    syncNeeded: true,
    status: 'deleted_pdf',
    kind: String((request && request.kind) || 'raw_source').trim() || 'raw_source',
    analysisOutcome: 'valid_prescription',
    canonicalGroupKey: String((request && request.canonicalGroupKey) || '').trim(),
    canonicalFileId: String((request && request.canonicalFileId) || '').trim(),
    mergeSignature: String((request && request.mergeSignature) || '').trim(),
    componentFileIds: Array.isArray(request && request.componentFileIds) ? request.componentFileIds.slice() : [],
    componentSourceKeys: Array.isArray(request && request.componentSourceKeys) ? request.componentSourceKeys.slice() : [],
    representedSourceCount: Number((request && request.representedSourceCount) || 0),
    supersededByCanonical: String((request && request.supersededByCanonical) || '').trim(),
    mergedAt: request && request.mergedAt ? request.mergedAt : null,
    errorMessage: '',
    patientFiscalCode: patientFiscalCode,
    patientFullName: String((request && request.patientFullName) || '').trim(),
    doctorFullName: String((request && request.doctorFullName) || '').trim(),
    exemptionCode: exemptions.length ? exemptions[0] : '',
    exemptions: exemptions,
    city: String((request && request.city) || '').trim(),
    therapy: Array.isArray(request && request.therapy) ? request.therapy.slice() : [],
    isDpc: !!(request && request.isDpc),
    prescriptionNres: Array.isArray(request && request.prescriptionNres) ? request.prescriptionNres.slice() : [],
    prescriptionIdentityKeys: Array.isArray(request && request.prescriptionIdentityKeys) ? request.prescriptionIdentityKeys.slice() : [],
    prescriptionCount: Math.max(1, Number((request && request.prescriptionCount) || 1)),
    prescriptionDate: request && request.prescriptionDate ? request.prescriptionDate : null,
    filenameFiscalCode: String((request && request.filenameFiscalCode) || patientFiscalCode).trim(),
    filenamePrescriptionDate: request && request.filenamePrescriptionDate ? request.filenamePrescriptionDate : null,
    filenameContentMismatch: !!(request && request.filenameContentMismatch),
    parentFolderId: String((request && request.parentFolderId) || '').trim(),
    parentFolderName: String((request && request.parentFolderName) || '').trim(),
    webViewLink: '',
    pdfDeleted: true,
    sourceType: String((request && request.sourceType) || cfg.sourceType || 'script').trim() || 'script',
    rawTextPreview: '',
    deletePdfRequested: false,
    deleteRequestedAt: request && request.deleteRequestedAt ? request.deleteRequestedAt : null,
    deleteRequestedBy: String((request && request.deleteRequestedBy) || '').trim(),
    deletedAt: request && request.deletedAt ? request.deletedAt : nowIso
  }, cfg);
}

function finalizeManifestAsDeletedPdf_(manifest, request, driveFileId) {
  var nowIso = new Date().toISOString();
  var requestExemptions = uniqueNonEmptyStrings_([
    request && request.exemption,
    request && request.exemptionCode
  ].concat((request && request.exemptions) || [], (manifest && manifest.exemptions) || [], (manifest && manifest.exemptionCode) || ''));

  manifest = manifest || {};
  manifest.id = driveFileId;
  manifest.driveFileId = driveFileId;
  manifest.status = 'deleted_pdf';
  manifest.analysisOutcome = manifest.analysisOutcome || 'valid_prescription';
  manifest.pdfDeleted = true;
  manifest.webViewLink = '';
  manifest.deletePdfRequested = false;
  manifest.deleteRequestedAt = request && request.deleteRequestedAt ? request.deleteRequestedAt : (manifest.deleteRequestedAt || nowIso);
  manifest.deleteRequestedBy = String((request && request.deleteRequestedBy) || manifest.deleteRequestedBy || '').trim();
  manifest.deletedAt = manifest.deletedAt || nowIso;
  manifest.updatedAt = nowIso;
  manifest.syncNeeded = true;
  manifest.exemptions = requestExemptions;
  manifest.exemptionCode = requestExemptions.length ? requestExemptions[0] : '';
  manifest.patientFiscalCode = normalizeCf_(request && request.patientFiscalCode || manifest.patientFiscalCode);
  manifest.patientFullName = String((request && request.patientFullName) || manifest.patientFullName || '').trim();
  manifest.doctorFullName = String((request && request.doctorFullName) || manifest.doctorFullName || '').trim();
  manifest.city = String((request && request.city) || manifest.city || '').trim();
}

function trashArchivePdfIfPresent_(driveFileId, cfg) {
  try {
    var file = DriveApp.getFileById(driveFileId);
    if (file.isTrashed()) {
      return { deleted: false, alreadyMissing: true };
    }
    file.setTrashed(true);
    return { deleted: true, alreadyMissing: false };
  } catch (e) {
    if (classifyRuntimeFailureKind_(e) === 'resource_access') {
      logInfo_(cfg, 'Drive delete già soddisfatta o file mancante', { driveFileId: driveFileId });
      return { deleted: false, alreadyMissing: true };
    }
    throw e;
  }
}

function syncRuntimeIndexToFirestore_(options) {
  options = options || {};
  var cfg = getPhboxConfig_();
  var rootFolder = DriveApp.getFolderById(cfg.folderId);
  var runtimeIndex = options.runtimeIndex || readRuntimeIndex_(rootFolder, cfg);
  var maxWrites = Math.max(1, Number(options.maxWrites || cfg.maxBatchWrites || 1));
  var plan = buildFirestorePublishPlan_(runtimeIndex, cfg, maxWrites);
  var stats = {
    unitsPending: plan.meta.pendingUnits,
    readyToSyncSeen: plan.meta.pendingUnits,
    unitsSelected: plan.meta.selectedUnits,
    deferredUnits: plan.meta.deferredUnits,
    deferredByBudget: 0,
    skippedNotReady: plan.meta.skippedNotReady,
    writesPlanned: plan.writes.length,
    imports: plan.meta.importWrites,
    patients: plan.meta.patientWrites,
    doctorLinks: plan.meta.doctorLinkWrites,
    dashboardTotals: plan.meta.dashboardTotalsWrites || 0,
    patientDashboardIndex: plan.meta.patientDashboardIndexWrites || 0,
    dashboardTotalsSkipped: !!plan.meta.dashboardTotalsSkipped,
    dashboardTotalsError: plan.meta.dashboardTotalsError || '',
    writes: 0,
    synced: 0,
    forcedResync: false,
    stoppedEarly: false
  };

  if (shouldStopForBudget_(options.budget, 18000) && plan.writes.length) {
    stats.stoppedEarly = true;
    stats.deferredByBudget = plan.meta.pendingUnits;
    return {
      runtimeIndex: runtimeIndex,
      stats: stats
    };
  }

  if (plan.writes.length) {
    executeFirestoreCommit_(cfg, plan.writes);
    stats.writes = plan.writes.length;
    stats.synced = plan.meta.selectedUnits;
    applyFirestorePublishPlanSuccess_(runtimeIndex, plan);
    if ((plan.selectedCfs || []).length && typeof syncPatientDashboardIndexForFiscalCodes_ === 'function') {
      var indexSync = syncPatientDashboardIndexForFiscalCodes_(plan.selectedCfs, { useLock: false });
      stats.patientDashboardIndexSync = indexSync;
      stats.patientDashboardIndex = Number(indexSync.written || 0);
    }
  } else {
    applyNoopPublishPlan_(runtimeIndex, plan);
  }

  if (plan.meta.deferredUnits > 0) {
    stats.stoppedEarly = true;
  }

  return {
    runtimeIndex: runtimeIndex,
    stats: stats
  };
}

function buildFirestorePublishPlan_(runtimeIndex, cfg, maxWrites) {
  var manifests = collectRuntimeManifests_(runtimeIndex);
  var dirtyImportIds = uniqueNonEmptyStrings_(runtimeIndex.dirty.imports || []).filter(function (id) {
    return !!runtimeIndex.filesById[id];
  }).sort(function (a, b) {
    var ma = runtimeIndex.filesById[a];
    var mb = runtimeIndex.filesById[b];
    return compareManifestByDateDesc_(mb, ma);
  });
  var dirtyCfs = uniqueNonEmptyStrings_((runtimeIndex.dirty.cfs || []).map(function (cf) { return normalizeCf_(cf); }));

  var activeVisible = manifests.filter(function (item) {
    return isActiveVisibleManifestForSync_(item);
  });
  var activeByCf = {};
  activeVisible.forEach(function (item) {
    var cf = normalizeCf_(item.patientFiscalCode);
    if (!cf) return;
    if (!activeByCf[cf]) activeByCf[cf] = [];
    activeByCf[cf].push(item);
  });
  var historicalByCf = {};
  manifests.forEach(function (item) {
    var cf = normalizeCf_(item.patientFiscalCode);
    if (!cf) return;
    if (!historicalByCf[cf]) historicalByCf[cf] = [];
    historicalByCf[cf].push(item);
  });

  var writes = [];
  var selectedImportIds = [];
  var selectedCfs = [];
  var noopImportIds = [];
  var noopCfs = [];
  var importHashUpdates = {};
  var patientHashUpdates = {};
  var doctorHashUpdates = {};
  var patientHashDeletes = [];
  var doctorHashDeletes = [];
  var importHashDeletes = [];
  var dashboardTotalsHashUpdate = '';
  var dashboardTotalsDataUpdate = null;
  var dashboardTotalsWrites = 0;
  var patientDashboardIndexWrites = 0;
  var dashboardTotalsSkipped = false;
  var dashboardTotalsError = '';
  var importWrites = 0;
  var patientWrites = 0;
  var doctorLinkWrites = 0;

  for (var i = 0; i < dirtyImportIds.length; i++) {
    var driveFileId = dirtyImportIds[i];
    var manifest = runtimeIndex.filesById[driveFileId];
    if (!manifest) {
      noopImportIds.push(driveFileId);
      continue;
    }
    var importDoc = buildDriveImportProjectionOrNull_(manifest);
    var currentHash = runtimeIndex.publishState.imports[driveFileId] || '';
    if (!importDoc) {
      if (currentHash) {
        if (writes.length >= maxWrites && writes.length > 0) break;
        writes.push(buildFirestoreDeleteWrite_(cfg, 'drive_pdf_imports', driveFileId));
        importWrites++;
        importHashDeletes.push(driveFileId);
        selectedImportIds.push(driveFileId);
      } else {
        noopImportIds.push(driveFileId);
      }
      continue;
    }
    var nextHash = computeStableHashForData_(importDoc.data);
    if (nextHash === currentHash) {
      noopImportIds.push(driveFileId);
      continue;
    }
    if (writes.length >= maxWrites && writes.length > 0) break;
    writes.push(buildFirestoreUpdateWrite_(cfg, importDoc.collection, importDoc.documentId, importDoc.data));
    importWrites++;
    importHashUpdates[driveFileId] = nextHash;
    selectedImportIds.push(driveFileId);
  }

  for (var c = 0; c < dirtyCfs.length; c++) {
    var cf = dirtyCfs[c];
    var unit = buildRuntimeCfProjectionUnit_(cf, activeByCf[cf] || [], historicalByCf[cf] || [], runtimeIndex);
    var unitWrites = [];
    var patientNextHash = '';
    var doctorNextHash = '';
    var patientPrevHash = runtimeIndex.publishState.patients[cf] || '';
    var doctorDocId = cf + '__primary';
    var doctorPrevHash = runtimeIndex.publishState.doctorLinks[doctorDocId] || '';

    if (unit.patient) {
      patientNextHash = computeStableHashForData_(unit.patient.data);
      if (patientNextHash !== patientPrevHash) {
        unitWrites.push({ type: 'patient_update', write: buildFirestoreUpdateWrite_(cfg, unit.patient.collection, unit.patient.documentId, unit.patient.data) });
      }
    } else if (patientPrevHash) {
      unitWrites.push({ type: 'patient_delete', write: buildFirestoreDeleteWrite_(cfg, 'patients', cf) });
    }

    if (unit.doctorLink) {
      doctorNextHash = computeStableHashForData_(unit.doctorLink.data);
      if (doctorNextHash !== doctorPrevHash) {
        unitWrites.push({ type: 'doctor_update', write: buildFirestoreUpdateWrite_(cfg, unit.doctorLink.collection, unit.doctorLink.documentId, unit.doctorLink.data) });
      }
    } else if (doctorPrevHash) {
      unitWrites.push({ type: 'doctor_delete', write: buildFirestoreDeleteWrite_(cfg, 'doctor_patient_links', doctorDocId) });
    }


    if (!unitWrites.length) {
      noopCfs.push(cf);
      continue;
    }

    if (writes.length > 0 && writes.length + unitWrites.length > maxWrites) {
      break;
    }

    unitWrites.forEach(function (entry) {
      writes.push(entry.write);
      if (entry.type.indexOf('patient_') === 0 && entry.type !== 'patient_dashboard_index_update') patientWrites++;
      if (entry.type.indexOf('doctor_') === 0) doctorLinkWrites++;
      if (entry.type === 'patient_dashboard_index_update') patientDashboardIndexWrites++;
    });
    selectedCfs.push(cf);
    if (unit.patient) patientHashUpdates[cf] = patientNextHash;
    else patientHashDeletes.push(cf);
    if (unit.doctorLink) doctorHashUpdates[doctorDocId] = doctorNextHash;
    else doctorHashDeletes.push(doctorDocId);
  }

  var dashboardTotalsCandidate = buildDashboardTotalsWriteCandidate_(runtimeIndex, cfg);
  if (dashboardTotalsCandidate && dashboardTotalsCandidate.error) {
    dashboardTotalsSkipped = true;
    dashboardTotalsError = dashboardTotalsCandidate.error;
  } else if (dashboardTotalsCandidate && dashboardTotalsCandidate.write) {
    if (writes.length < maxWrites) {
      writes.push(dashboardTotalsCandidate.write);
      dashboardTotalsWrites = 1;
      dashboardTotalsHashUpdate = dashboardTotalsCandidate.hash;
      dashboardTotalsDataUpdate = dashboardTotalsCandidate.data;
    } else {
      dashboardTotalsSkipped = true;
      dashboardTotalsError = 'max_writes_reached';
    }
  }


  return {
    writes: writes,
    selectedImportIds: selectedImportIds,
    selectedCfs: selectedCfs,
    noopImportIds: noopImportIds,
    noopCfs: noopCfs,
    importHashUpdates: importHashUpdates,
    patientHashUpdates: patientHashUpdates,
    doctorHashUpdates: doctorHashUpdates,
    importHashDeletes: importHashDeletes,
    dashboardTotalsHashUpdate: dashboardTotalsHashUpdate,
    dashboardTotalsDataUpdate: dashboardTotalsDataUpdate,
    patientHashDeletes: patientHashDeletes,
    doctorHashDeletes: doctorHashDeletes,
    meta: {
      pendingUnits: dirtyImportIds.length + dirtyCfs.length,
      selectedUnits: selectedImportIds.length + selectedCfs.length,
      deferredUnits: Math.max(0, dirtyImportIds.length + dirtyCfs.length - (selectedImportIds.length + selectedCfs.length + noopImportIds.length + noopCfs.length)),
      skippedNotReady: 0,
      importWrites: importWrites,
      patientWrites: patientWrites,
      doctorLinkWrites: doctorLinkWrites,
      dashboardTotalsWrites: dashboardTotalsWrites,
      patientDashboardIndexWrites: patientDashboardIndexWrites,
      dashboardTotalsSkipped: dashboardTotalsSkipped,
      dashboardTotalsError: dashboardTotalsError
    }
  };
}

function buildRuntimeCfProjectionUnit_(cf, activeCanonicalsForCf, historicalManifestsForCf, runtimeIndex) {
  var patient = null;
  var doctorLink = null;
  var stableDoctorManifests = selectStableDoctorSourceManifestsForCf_(historicalManifestsForCf || []);

  if ((historicalManifestsForCf || []).length) {
    if (!(activeCanonicalsForCf || []).length) {
      patient = buildDeletedPatientDocument_(cf, stableDoctorManifests);
    } else {
      patient = buildPatientDocument_(cf, activeCanonicalsForCf);
    }
  }

  if (stableDoctorManifests.length) {
    doctorLink = buildDoctorLinkDocument_(cf, stableDoctorManifests, patient && patient.fullName);
  }

  return {
    patient: patient,
    doctorLink: doctorLink
  };
}

function buildDriveImportProjectionOrNull_(manifest) {
  if (!manifest || !normalizeCf_(manifest.patientFiscalCode)) return null;
  return buildDriveImportDocument_(manifest);
}

function buildFirestorePatchWrite_(cfg, collection, documentId, data, fieldPaths) {
  var cleanFieldPaths = uniqueNonEmptyStrings_(fieldPaths || Object.keys(data || {}));
  return {
    update: {
      name: buildFirestoreDocumentName_(cfg, collection, documentId),
      fields: toFirestoreFields_(data)
    },
    updateMask: {
      fieldPaths: cleanFieldPaths
    }
  };
}

function buildFirestoreUpdateWrite_(cfg, collection, documentId, data) {
  return {
    update: {
      name: buildFirestoreDocumentName_(cfg, collection, documentId),
      fields: toFirestoreFields_(data)
    }
  };
}

function buildFirestoreDeleteWrite_(cfg, collection, documentId) {
  return {
    delete: buildFirestoreDocumentName_(cfg, collection, documentId)
  };
}

function buildFirestoreDocumentName_(cfg, collection, documentId) {
  return 'projects/' + cfg.firestoreProjectId + '/databases/(default)/documents/' + collection + '/' + documentId;
}

function executeFirestoreCommit_(cfg, writes) {
  var url = 'https://firestore.googleapis.com/v1/projects/' + encodeURIComponent(cfg.firestoreProjectId) + '/databases/(default)/documents:commit';
  var response = UrlFetchApp.fetch(url, {
    method: 'post',
    muteHttpExceptions: true,
    contentType: 'application/json',
    headers: {
      Authorization: 'Bearer ' + ScriptApp.getOAuthToken()
    },
    payload: JSON.stringify({ writes: writes || [] })
  });
  var code = response.getResponseCode();
  if (code >= 200 && code < 300) return;
  throw new Error('Firestore COMMIT failed [' + code + '] ' + response.getContentText());
}

function applyFirestorePublishPlanSuccess_(runtimeIndex, plan) {
  var nowIso = new Date().toISOString();
  Object.keys(plan.importHashUpdates || {}).forEach(function (driveFileId) {
    runtimeIndex.publishState.imports[driveFileId] = plan.importHashUpdates[driveFileId];
    var manifest = runtimeIndex.filesById[driveFileId];
    if (manifest) {
      manifest.syncedAt = nowIso;
      manifest.syncNeeded = false;
      runtimeIndex.filesById[driveFileId] = manifest;
    }
  });
  (plan.importHashDeletes || []).forEach(function (driveFileId) {
    delete runtimeIndex.publishState.imports[driveFileId];
    var manifest = runtimeIndex.filesById[driveFileId];
    if (manifest) {
      manifest.syncedAt = nowIso;
      manifest.syncNeeded = false;
      runtimeIndex.filesById[driveFileId] = manifest;
    }
  });

  Object.keys(plan.patientHashUpdates || {}).forEach(function (cf) {
    runtimeIndex.publishState.patients[cf] = plan.patientHashUpdates[cf];
  });
  (plan.patientHashDeletes || []).forEach(function (cf) {
    delete runtimeIndex.publishState.patients[cf];
  });
  Object.keys(plan.doctorHashUpdates || {}).forEach(function (docId) {
    runtimeIndex.publishState.doctorLinks[docId] = plan.doctorHashUpdates[docId];
  });
  (plan.doctorHashDeletes || []).forEach(function (docId) {
    delete runtimeIndex.publishState.doctorLinks[docId];
  });

  if (plan.dashboardTotalsHashUpdate) {
    runtimeIndex.publishState.dashboardTotals = plan.dashboardTotalsHashUpdate;
    runtimeIndex.publishState.dashboardTotalsData = plan.dashboardTotalsDataUpdate || null;
  }

  removeDirtyImportIds_(runtimeIndex, (plan.selectedImportIds || []).concat(plan.noopImportIds || []));
  removeDirtyCfs_(runtimeIndex, (plan.selectedCfs || []).concat(plan.noopCfs || []));
}

function applyNoopPublishPlan_(runtimeIndex, plan) {
  removeDirtyImportIds_(runtimeIndex, plan.noopImportIds || []);
  removeDirtyCfs_(runtimeIndex, plan.noopCfs || []);
}

function syncManifestsToFirestore_(options) {
  return syncRuntimeIndexToFirestore_(options);
}

function loadAllManifestsFromFolder_(folder) {
  var cfg = getPhboxConfig_();
  var rootFolder = DriveApp.getFolderById(cfg.folderId);
  var runtimeIndex = readRuntimeIndex_(rootFolder, cfg);
  return collectRuntimeManifests_(runtimeIndex);
}

function markManifestSynced_(folder, driveFileId) {
  var cfg = getPhboxConfig_();
  var rootFolder = DriveApp.getFolderById(cfg.folderId);
  var runtimeIndex = readRuntimeIndex_(rootFolder, cfg);
  var manifest = runtimeIndex.filesById[driveFileId];
  if (!manifest) return;
  manifest.syncNeeded = false;
  manifest.syncedAt = new Date().toISOString();
  runtimeIndex.filesById[driveFileId] = manifest;
  writeRuntimeIndex_(rootFolder, cfg, runtimeIndex);
}

function upsertFirestoreDocument_(cfg, collection, documentId, data) {
  executeFirestoreCommit_(cfg, [buildFirestoreUpdateWrite_(cfg, collection, documentId, data)]);
}

function buildFirestoreDocumentUrl_(cfg, collection, documentId, updateMaskFieldPaths) {
  return 'https://firestore.googleapis.com/v1/projects/' + encodeURIComponent(cfg.firestoreProjectId) + '/databases/(default)/documents/' + collection + '/' + encodeURIComponent(documentId);
}

function extractFirestoreDocumentId_(documentName) {
  var text = String(documentName || '').trim();
  if (!text) return '';
  var parts = text.split('/');
  return parts.length ? parts[parts.length - 1] : text;
}

function fromFirestoreFields_(fields) {
  var out = {};
  Object.keys(fields || {}).forEach(function (key) {
    out[key] = fromFirestoreValue_(fields[key]);
  });
  return out;
}

function fromFirestoreValue_(value) {
  if (!value || typeof value !== 'object') return null;
  if (Object.prototype.hasOwnProperty.call(value, 'nullValue')) return null;
  if (Object.prototype.hasOwnProperty.call(value, 'stringValue')) return value.stringValue;
  if (Object.prototype.hasOwnProperty.call(value, 'booleanValue')) return !!value.booleanValue;
  if (Object.prototype.hasOwnProperty.call(value, 'timestampValue')) return value.timestampValue;
  if (Object.prototype.hasOwnProperty.call(value, 'integerValue')) return Number(value.integerValue || 0);
  if (Object.prototype.hasOwnProperty.call(value, 'doubleValue')) return Number(value.doubleValue || 0);
  if (Object.prototype.hasOwnProperty.call(value, 'mapValue')) return fromFirestoreFields_((value.mapValue && value.mapValue.fields) || {});
  if (Object.prototype.hasOwnProperty.call(value, 'arrayValue')) {
    var values = (value.arrayValue && value.arrayValue.values) || [];
    return values.map(function (item) {
      return fromFirestoreValue_(item);
    });
  }
  return null;
}

function toFirestoreFields_(data) {
  var out = {};
  Object.keys(data || {}).forEach(function (key) {
    out[key] = toFirestoreValue_(data[key]);
  });
  return out;
}

function isStrictFirestoreTimestampString_(value) {
  var text = String(value || '').trim();
  if (!text) return false;
  return /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?(?:Z|[+\-]\d{2}:\d{2})$/.test(text);
}

function toFirestoreValue_(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (Array.isArray(value)) {
    return {
      arrayValue: {
        values: value.map(function (item) {
          return toFirestoreValue_(item);
        })
      }
    };
  }
  if (Object.prototype.toString.call(value) === '[object Date]') {
    return { timestampValue: value.toISOString() };
  }
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    if (Math.floor(value) === value) return { integerValue: String(value) };
    return { doubleValue: value };
  }
  if (typeof value === 'object') {
    return { mapValue: { fields: toFirestoreFields_(value) } };
  }
  if (typeof value === 'string') {
    if (isStrictFirestoreTimestampString_(value)) return { timestampValue: value };
    return { stringValue: value };
  }
  return { stringValue: String(value) };
}
