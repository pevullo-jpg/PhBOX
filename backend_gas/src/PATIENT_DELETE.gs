function processRuntimePatientDeleteSignal_(signal) {
  var cfg = getPhboxConfig_();
  signal = normalizeRuntimeSignal_(signal);
  var cf = normalizeCf_(signal.targetFiscalCode || signal.targetDocumentId || extractRuntimePatientDeleteCfFromPath_(signal.targetPath));
  if (!cf) throw new Error('PATIENT_DELETE_CF_MISSING');

  var operation = String(signal.operation || '').trim().toLowerCase();
  if (operation !== 'delete' && operation !== 'deletearchive' && operation !== 'deleted' && operation !== 'remove' && operation !== 'removed') {
    throw new Error('PATIENT_DELETE_UNSUPPORTED_OPERATION: ' + operation);
  }

  var nowIso = new Date().toISOString();
  var linked = collectRuntimePatientArchiveDeleteLinkedData_(cfg, cf);
  var runtimeIndexResult = markRuntimePatientDeleteManifests_(cfg, cf, linked.driveImports, nowIso);
  var driveResult = trashRuntimePatientDeleteDriveFiles_(cfg, linked.driveImports);
  var totalsPatch = signal.requiresTotalsUpdate === false
    ? null
    : buildRuntimePatientArchiveDeleteTotalsPatch_(cfg, linked, nowIso);
  var expiringPatch = buildRuntimePatientArchiveDeleteExpiringRecipesPatch_(cfg, cf, linked, nowIso);

  var writes = [];
  appendRuntimePatientDeleteImportWrites_(cfg, writes, linked.driveImports, nowIso);
  appendRuntimePatientArchiveDeleteLegacyPrescriptionWrites_(cfg, writes, linked.legacyPrescriptions);
  appendRuntimePatientArchiveDeleteDoctorLinkWrites_(cfg, writes, linked.doctorLinks);
  if (totalsPatch) {
    writes.push(buildFirestorePatchWrite_(cfg, 'dashboard_totals', 'main', totalsPatch, Object.keys(totalsPatch)));
  }
  if (expiringPatch) {
    writes.push(buildFirestorePatchWrite_(cfg, 'dashboard_expiring_recipes', 'main', expiringPatch, Object.keys(expiringPatch)));
  }

  executeRuntimePatientDeleteCommitChunks_(cfg, writes);

  return {
    ok: true,
    domain: 'patientDelete',
    cf: cf,
    archiveOnly: true,
    writes: writes.length,
    drive: driveResult,
    runtimeIndex: runtimeIndexResult,
    linked: summarizeRuntimePatientArchiveDeleteLinkedData_(linked),
    readsEstimated: linked.readsEstimated
  };
}

function extractRuntimePatientDeleteCfFromPath_(targetPath) {
  var parts = normalizeRuntimeSignalTargetPath_(targetPath);
  for (var i = 0; i < parts.length - 1; i++) {
    if (String(parts[i] || '').trim() === 'patients') {
      return normalizeCf_(parts[i + 1]);
    }
  }
  return '';
}

function collectRuntimePatientArchiveDeleteLinkedData_(cfg, cf) {
  var collector = createRuntimePatientArchiveDeleteCollector_(cfg, cf);

  addRuntimePatientDeleteDocs_(collector, 'driveImports', fetchRuntimePatientDeleteDriveImportsForCf_(cfg, cf, collector));

  addRuntimePatientDeleteDocs_(collector, 'legacyPrescriptions', listRuntimePatientDeleteDocumentsByPathLimited_(cfg, ['patients', cf, 'prescriptions'], collector));
  addRuntimePatientDeleteDocs_(collector, 'legacyPrescriptions', runRuntimePatientDeleteFieldEqualsQueryLimited_(cfg, 'prescriptions', 'patientFiscalCode', cf, false, collector));
  addRuntimePatientDeleteDocs_(collector, 'legacyPrescriptions', runRuntimePatientDeleteFieldEqualsQueryLimited_(cfg, 'prescriptions', 'fiscalCode', cf, false, collector));

  addRuntimePatientDeleteDoc_(collector, 'doctorLinks', getFirestoreDocumentByPathSafe_(cfg, ['doctor_patient_links', cf + '__primary']));

  return buildRuntimePatientArchiveDeleteLinkedDataFromCollector_(collector);
}

function createRuntimePatientArchiveDeleteCollector_(cfg, cf) {
  return {
    cfg: cfg,
    cf: cf,
    maxDocs: readRuntimePatientDeleteMaxLinkedDocs_(cfg),
    seen: {},
    count: 0,
    driveImports: [],
    legacyPrescriptions: [],
    doctorLinks: [],
    readsEstimated: 0
  };
}

function readRuntimePatientDeleteMaxLinkedDocs_(cfg) {
  return Math.max(50, Number((cfg && cfg.maxPatientDeleteLinkedDocs) || 300));
}

function remainingRuntimePatientDeleteDocBudget_(collector) {
  return Math.max(0, Number(collector.maxDocs || 0) - Number(collector.count || 0));
}

function runtimePatientDeleteQueryLimit_(collector) {
  return remainingRuntimePatientDeleteDocBudget_(collector) + 1;
}

function addRuntimePatientDeleteDoc_(collector, key, doc) {
  if (!doc) return;
  var dedupeKey = runtimePatientDeleteDedupeKey_(doc);
  if (!dedupeKey || collector.seen[dedupeKey]) return;
  collector.seen[dedupeKey] = true;
  collector.count++;
  if (collector.count > collector.maxDocs) {
    throw new Error('PATIENT_DELETE_TOO_MANY_LINKED_DOCS: ' + collector.count + ' > ' + collector.maxDocs);
  }
  if (!collector[key]) collector[key] = [];
  collector[key].push(doc);
}

function addRuntimePatientDeleteDocs_(collector, key, docs) {
  (docs || []).forEach(function (doc) {
    addRuntimePatientDeleteDoc_(collector, key, doc);
  });
}

function runtimePatientDeleteDedupeKey_(doc) {
  if (!doc) return '';
  return String(doc.documentPath || (doc.collectionId && doc.documentId ? doc.collectionId + '/' + doc.documentId : '') || doc.id || JSON.stringify(doc));
}

function buildRuntimePatientArchiveDeleteLinkedDataFromCollector_(collector) {
  return {
    cf: collector.cf,
    driveImports: collector.driveImports,
    legacyPrescriptions: collector.legacyPrescriptions,
    doctorLinks: collector.doctorLinks,
    readsEstimated: collector.readsEstimated
  };
}

function fetchRuntimePatientDeleteDriveImportsForCf_(cfg, cf, collector) {
  return runRuntimePatientDeleteFieldEqualsQueryLimited_(cfg, 'drive_pdf_imports', 'patientFiscalCode', cf, false, collector);
}

function listRuntimePatientDeleteDocumentsByPathLimited_(cfg, pathSegments, collector) {
  var out = [];
  var pageToken = '';
  var maxLimit = runtimePatientDeleteQueryLimit_(collector);
  if (maxLimit <= 0) throw new Error('PATIENT_DELETE_TOO_MANY_LINKED_DOCS: ' + (collector.count + 1) + ' > ' + collector.maxDocs);
  do {
    var remaining = Math.max(0, maxLimit - out.length);
    if (remaining <= 0) break;
    var url = buildFirestoreDocumentsListUrl_(cfg, pathSegments, {
      pageSize: Math.max(1, Math.min(500, remaining)),
      pageToken: pageToken,
      orderBy: '__name__'
    });
    var payload = fetchFirestoreJsonWithRetry_(url, { method: 'get' });
    collector.readsEstimated++;
    var documents = (payload && payload.documents) || [];
    documents.forEach(function (document) {
      out.push(mapFirestoreDocumentToPlainObject_(document));
    });
    pageToken = String((payload && payload.nextPageToken) || '').trim();
  } while (pageToken && out.length < maxLimit);
  if (out.length >= maxLimit && pageToken) {
    throw new Error('PATIENT_DELETE_TOO_MANY_LINKED_DOCS: more than ' + collector.maxDocs);
  }
  return out;
}

function runRuntimePatientDeleteFieldEqualsQueryLimited_(cfg, collectionId, fieldPath, value, allDescendants, collector) {
  return runRuntimePatientDeleteStructuredQueryLimited_(cfg, {
    from: [{ collectionId: String(collectionId || '').trim(), allDescendants: !!allDescendants }],
    where: {
      fieldFilter: {
        field: { fieldPath: String(fieldPath || '').trim() },
        op: 'EQUAL',
        value: toFirestoreValue_(value)
      }
    },
    limit: runtimePatientDeleteQueryLimit_(collector)
  }, collector);
}

function runRuntimePatientDeleteStructuredQueryLimited_(cfg, structuredQuery, collector) {
  var limit = Math.max(1, Number(structuredQuery && structuredQuery.limit || runtimePatientDeleteQueryLimit_(collector)));
  if (limit <= 0) throw new Error('PATIENT_DELETE_TOO_MANY_LINKED_DOCS: ' + (collector.count + 1) + ' > ' + collector.maxDocs);
  structuredQuery.limit = limit;
  try {
    var url = 'https://firestore.googleapis.com/v1/projects/' + encodeURIComponent(cfg.firestoreProjectId) + '/databases/(default)/documents:runQuery';
    var rows = fetchFirestoreJsonWithRetry_(url, {
      method: 'post',
      contentType: 'application/json',
      payload: JSON.stringify({ structuredQuery: structuredQuery })
    });
    collector.readsEstimated++;
    if (!Array.isArray(rows)) return [];
    var out = rows.map(function (row) {
      return row && row.document ? mapFirestoreDocumentToPlainObject_(row.document) : null;
    }).filter(function (item) { return !!item; });
    if (out.length >= limit && limit > remainingRuntimePatientDeleteDocBudget_(collector)) {
      throw new Error('PATIENT_DELETE_TOO_MANY_LINKED_DOCS: more than ' + collector.maxDocs);
    }
    return out;
  } catch (e) {
    var message = String(e && e.message || e);
    if (message.indexOf('PATIENT_DELETE_TOO_MANY_LINKED_DOCS') >= 0) throw e;
    throw new Error('PATIENT_DELETE_LINKED_QUERY_FAILED: ' + message);
  }
}

function summarizeRuntimePatientArchiveDeleteLinkedData_(linked) {
  linked = linked || {};
  return {
    totalLinkedDocs: ((linked.driveImports || []).length) + ((linked.legacyPrescriptions || []).length) + ((linked.doctorLinks || []).length),
    driveImports: (linked.driveImports || []).length,
    prescriptions: (linked.legacyPrescriptions || []).length,
    doctorLinks: (linked.doctorLinks || []).length
  };
}

function markRuntimePatientDeleteManifests_(cfg, cf, driveImports, nowIso) {
  var rootFolder = DriveApp.getFolderById(cfg.folderId);
  var runtimeIndex = readRuntimeIndex_(rootFolder, cfg);
  var updated = 0;
  var dirtyImportsToClear = [];

  (driveImports || []).forEach(function (item) {
    var driveFileId = resolveArchiveDeleteDriveFileId_(item);
    if (!driveFileId) return;
    var manifest = runtimeIndex.filesById[driveFileId] || buildDeletedManifestFromDeleteRequest_(item, driveFileId, cfg);
    finalizeManifestAsDeletedPdf_(manifest, item, driveFileId);
    manifest.patientDeleted = true;
    manifest.patientDeleteFiscalCode = cf;
    manifest.patientDeletedAt = nowIso;
    manifest.syncNeeded = false;
    manifest.syncedAt = nowIso;
    upsertRuntimeManifestInIndex_(runtimeIndex, manifest, { markDirty: false });
    dirtyImportsToClear.push(driveFileId);
    updated++;
  });

  if (runtimeIndex.publishState) {
    if (runtimeIndex.publishState.patients) delete runtimeIndex.publishState.patients[cf];
    if (runtimeIndex.publishState.doctorLinks) {
      delete runtimeIndex.publishState.doctorLinks[cf + '__primary'];
    }
  }
  removeDirtyImportIds_(runtimeIndex, dirtyImportsToClear);
  removeDirtyCfs_(runtimeIndex, [cf]);
  writeRuntimeIndex_(rootFolder, cfg, runtimeIndex);
  return { ok: true, manifestsMarkedDeleted: updated };
}

function trashRuntimePatientDeleteDriveFiles_(cfg, driveImports) {
  var result = { attempted: 0, trashed: 0, alreadyMissing: 0 };
  (driveImports || []).forEach(function (item) {
    if (!shouldRuntimePatientDeleteTrashImport_(item)) return;
    var driveFileId = resolveArchiveDeleteDriveFileId_(item);
    if (!driveFileId) return;
    result.attempted++;
    var drive = trashArchivePdfIfPresent_(driveFileId, cfg);
    if (drive.deleted) result.trashed++;
    if (drive.alreadyMissing) result.alreadyMissing++;
  });
  return result;
}

function shouldRuntimePatientDeleteTrashImport_(item) {
  if (!item) return false;
  if (item.pdfDeleted === true) return false;
  var status = String(item.status || '').trim().toLowerCase();
  if (status === 'deleted_pdf' || status === 'deleted' || status === 'trash' || status === 'trashed') return false;
  return true;
}

function appendRuntimePatientDeleteImportWrites_(cfg, writes, driveImports, nowIso) {
  (driveImports || []).forEach(function (item) {
    var docId = String(item.documentId || item.driveFileId || item.fileId || item.id || '').trim();
    if (!docId) return;
    var data = {
      status: 'deleted_pdf',
      pdfDeleted: true,
      deletePdfRequested: false,
      patientDeleted: true,
      patientDeletedAt: nowIso,
      deletedAt: item.deletedAt || nowIso,
      updatedAt: nowIso,
      webViewLink: '',
      openUrl: ''
    };
    writes.push(buildFirestorePatchWrite_(cfg, 'drive_pdf_imports', docId, data, Object.keys(data)));
  });
}

function appendRuntimePatientArchiveDeleteLegacyPrescriptionWrites_(cfg, writes, legacyPrescriptions) {
  appendRuntimePatientDeleteDocs_(cfg, writes, legacyPrescriptions);
}

function appendRuntimePatientArchiveDeleteDoctorLinkWrites_(cfg, writes, doctorLinks) {
  appendRuntimePatientDeleteDocs_(cfg, writes, doctorLinks);
}

function appendRuntimePatientDeleteDocs_(cfg, writes, docs) {
  (docs || []).forEach(function (doc) {
    var write = buildRuntimePatientDeleteDeleteWriteFromDoc_(cfg, doc);
    if (write) writes.push(write);
  });
}

function buildRuntimePatientArchiveDeleteTotalsPatch_(cfg, linked, nowIso) {
  var current = getFirestoreDocumentByPath_(cfg, ['dashboard_totals', 'main']) || {};
  var archiveDelta = calculateRuntimePatientArchiveDeleteDeltas_(linked);
  return {
    recipeCount: Math.max(0, Number(current.recipeCount || 0) - archiveDelta.recipeCount),
    dpcCount: Math.max(0, Number(current.dpcCount || 0) - archiveDelta.dpcCount),
    expiringCount: Math.max(0, Number(current.expiringCount || 0) - archiveDelta.expiringPatientCount),
    updatedAt: nowIso,
    generatedAt: nowIso,
    archiveTotalsSource: 'runtime_signal_patient_delete_archive'
  };
}

function calculateRuntimePatientArchiveDeleteDeltas_(linked) {
  var activeImports = (linked.driveImports || []).filter(isRuntimePatientDeleteCountableArchiveDoc_);
  var useImports = activeImports.length > 0;
  var recipeCount = 0;
  var dpcCount = 0;
  var hasExpiry = false;
  if (useImports) {
    activeImports.forEach(function (item) {
      recipeCount += Math.max(1, Number(item.prescriptionCount || item.recipeCount || 1));
      if (item.isDpc || item.hasDpc) dpcCount++;
      var baseDate = parseDashboardTotalsDate_(item.prescriptionDate || item.createdAt);
      if (baseDate && isDashboardExpiryAlert_(addDaysForDashboardTotals_(baseDate, 30))) hasExpiry = true;
    });
  } else {
    (linked.legacyPrescriptions || []).forEach(function (item) {
      recipeCount += Math.max(1, Number(item.prescriptionCount || item.recipeCount || 1));
      if (item.dpcFlag || item.isDpc || item.hasDpc) dpcCount++;
      var expiryDate = parseDashboardTotalsDate_(item.expiryDate || item.prescriptionDate || item.createdAt);
      if (expiryDate && isDashboardExpiryAlert_(expiryDate)) hasExpiry = true;
    });
  }
  return {
    recipeCount: recipeCount,
    dpcCount: dpcCount,
    expiringPatientCount: hasExpiry ? 1 : 0
  };
}

function isRuntimePatientDeleteCountableArchiveDoc_(item) {
  if (!item) return false;
  if (item.pdfDeleted === true) return false;
  var kind = String(item.kind || '');
  if (kind === 'merged_component' || kind === 'canonical_source_retained' || kind === 'merge_pending_component') return false;
  var status = String(item.status || '').trim().toLowerCase();
  if (status === 'deleted_pdf' || status === 'deleted' || status === 'trash' || status === 'trashed' || status === 'discarded_non_prescription') return false;
  return true;
}

function buildRuntimePatientArchiveDeleteExpiringRecipesPatch_(cfg, cf, linked, nowIso) {
  var current = getFirestoreDocumentByPathSafe_(cfg, ['dashboard_expiring_recipes', 'main']);
  if (!current || !Array.isArray(current.items)) return null;
  var nextItems = current.items.filter(function (item) {
    return normalizeCf_(item && (item.patientFiscalCode || item.fiscalCode)) !== cf;
  });
  if (nextItems.length === current.items.length) return null;
  var archiveDelta = calculateRuntimePatientArchiveDeleteDeltas_(linked);
  return {
    items: nextItems,
    itemCount: nextItems.length,
    totalExpiringCount: Math.max(0, Number(current.totalExpiringCount || current.itemCount || current.items.length || 0) - archiveDelta.expiringPatientCount),
    updatedAt: nowIso,
    generatedAt: nowIso,
    source: 'runtime_signal_patient_delete_archive'
  };
}

function buildRuntimePatientDeleteDeleteWriteFromDoc_(cfg, doc) {
  var documentPath = String(doc && doc.documentPath || '').trim();
  if (documentPath) return { delete: documentPath };
  var collectionId = String(doc && doc.collectionId || '').trim();
  var documentId = String(doc && doc.documentId || doc.id || '').trim();
  if (!collectionId || !documentId) return null;
  return buildRuntimePatientDeleteDeleteWriteFromPath_(cfg, [collectionId, documentId]);
}

function buildRuntimePatientDeleteDeleteWriteFromPath_(cfg, pathSegments) {
  return {
    delete: buildRuntimePatientDeleteDocumentName_(cfg, pathSegments)
  };
}

function buildRuntimePatientDeleteDocumentName_(cfg, pathSegments) {
  var path = (pathSegments || []).map(function (segment) {
    return encodeURIComponent(String(segment || '').trim());
  }).join('/');
  return 'projects/' + cfg.firestoreProjectId + '/databases/(default)/documents/' + path;
}

function executeRuntimePatientDeleteCommitChunks_(cfg, writes) {
  writes = dedupeRuntimePatientDeleteWrites_(writes || []);
  var chunkSize = 400;
  for (var i = 0; i < writes.length; i += chunkSize) {
    executeFirestoreCommit_(cfg, writes.slice(i, i + chunkSize));
  }
}

function dedupeRuntimePatientDeleteWrites_(writes) {
  var seen = {};
  var out = [];
  (writes || []).forEach(function (write) {
    if (!write) return;
    var key = String((write.delete || (write.update && write.update.name)) || JSON.stringify(write));
    var isDelete = !!write.delete;
    if (seen[key] && isDelete) return;
    seen[key] = true;
    out.push(write);
  });
  return out;
}
