function processRuntimePatientDeleteSignal_(signal) {
  var cfg = getPhboxConfig_();
  signal = normalizeRuntimeSignal_(signal);
  var cf = normalizeCf_(signal.targetFiscalCode || signal.targetDocumentId || extractRuntimePatientDeleteCfFromPath_(signal.targetPath));
  if (!cf) throw new Error('PATIENT_DELETE_CF_MISSING');

  var operation = String(signal.operation || '').trim().toLowerCase();
  if (operation !== 'delete' && operation !== 'deleted' && operation !== 'remove' && operation !== 'removed') {
    throw new Error('PATIENT_DELETE_UNSUPPORTED_OPERATION: ' + operation);
  }

  var nowIso = new Date().toISOString();
  var linked = collectRuntimePatientDeleteLinkedData_(cfg, cf);
  assertRuntimePatientDeleteBounded_(cfg, linked);

  var runtimeIndexResult = markRuntimePatientDeleteManifests_(cfg, cf, linked.driveImports, nowIso);
  var driveResult = trashRuntimePatientDeleteDriveFiles_(cfg, linked.driveImports);
  var totalsPatch = signal.requiresTotalsUpdate === false
    ? null
    : buildRuntimePatientDeleteTotalsPatch_(cfg, linked, nowIso);
  var expiringPatch = buildRuntimePatientDeleteExpiringRecipesPatch_(cfg, cf, linked, nowIso);

  var writes = [];
  appendRuntimePatientDeleteImportWrites_(cfg, writes, linked.driveImports, nowIso);
  appendRuntimePatientDeleteDocumentDeletes_(cfg, writes, linked);
  appendRuntimePatientDeleteFamilyWrites_(cfg, writes, linked.families, cf, nowIso);
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
    deletedPatient: true,
    writes: writes.length,
    drive: driveResult,
    runtimeIndex: runtimeIndexResult,
    linked: summarizeRuntimePatientDeleteLinkedData_(linked),
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

function collectRuntimePatientDeleteLinkedData_(cfg, cf) {
  var driveImports = fetchPatientDashboardDriveImportsForCf_(cfg, cf);
  var legacyPrescriptions = fetchPatientDashboardPrescriptionsForCf_(cfg, cf);
  var debts = fetchRuntimePatientDeleteAppDocsForCf_(cfg, cf, 'debts');
  var advances = fetchRuntimePatientDeleteAppDocsForCf_(cfg, cf, 'advances');
  var bookings = fetchRuntimePatientDeleteAppDocsForCf_(cfg, cf, 'bookings');
  var prescriptionIntakes = runPatientDashboardFieldEqualsQuery_(cfg, 'prescription_intakes', 'fiscalCode', cf, false);
  var doctorLinks = fetchRuntimePatientDeleteDoctorLinks_(cfg, cf);
  var families = runPatientDashboardArrayContainsQuery_(cfg, 'families', 'memberFiscalCodes', cf, false);
  var identityRequests = fetchRuntimePatientDeleteIdentityRequests_(cfg, cf);

  return {
    cf: cf,
    patient: getFirestoreDocumentByPathSafe_(cfg, ['patients', cf]),
    index: getFirestoreDocumentByPathSafe_(cfg, ['patient_dashboard_index', cf]),
    therapeuticAdvice: getFirestoreDocumentByPathSafe_(cfg, ['patient_therapeutic_advice', cf]),
    driveImports: dedupeRuntimePatientDeleteDocs_(driveImports),
    legacyPrescriptions: dedupeRuntimePatientDeleteDocs_(legacyPrescriptions),
    debts: dedupeRuntimePatientDeleteDocs_(debts),
    advances: dedupeRuntimePatientDeleteDocs_(advances),
    bookings: dedupeRuntimePatientDeleteDocs_(bookings),
    prescriptionIntakes: dedupeRuntimePatientDeleteDocs_(prescriptionIntakes),
    doctorLinks: dedupeRuntimePatientDeleteDocs_(doctorLinks),
    families: dedupeRuntimePatientDeleteDocs_(families),
    identityRequests: dedupeRuntimePatientDeleteDocs_(identityRequests),
    readsEstimated: 18
  };
}

function fetchRuntimePatientDeleteAppDocsForCf_(cfg, cf, collectionId) {
  var direct = listFirestoreDocumentsByPathSafe_(cfg, ['patients', cf, collectionId], { pageSize: 300 });
  var grouped = runPatientDashboardFieldEqualsQuery_(cfg, collectionId, 'patientFiscalCode', cf, true);
  return dedupeRuntimePatientDeleteDocs_(direct.concat(grouped));
}

function fetchRuntimePatientDeleteDoctorLinks_(cfg, cf) {
  var out = runPatientDashboardFieldEqualsQuery_(cfg, 'doctor_patient_links', 'patientFiscalCode', cf, false);
  var manual = getFirestoreDocumentByPathSafe_(cfg, ['doctor_patient_links', cf + '__manual']);
  var primary = getFirestoreDocumentByPathSafe_(cfg, ['doctor_patient_links', cf + '__primary']);
  if (manual) out.push(manual);
  if (primary) out.push(primary);
  return dedupeRuntimePatientDeleteDocs_(out);
}

function fetchRuntimePatientDeleteIdentityRequests_(cfg, cf) {
  var out = [];
  out = out.concat(runPatientDashboardFieldEqualsQuery_(cfg, 'identity_resolution_requests', 'sourceFiscalCode', cf, false));
  out = out.concat(runPatientDashboardFieldEqualsQuery_(cfg, 'identity_resolution_requests', 'targetFiscalCode', cf, false));
  out = out.concat(runPatientDashboardFieldEqualsQuery_(cfg, 'identity_resolution_requests', 'selectedFiscalCode', cf, false));
  out = out.concat(runPatientDashboardArrayContainsQuery_(cfg, 'identity_resolution_requests', 'candidateFiscalCodes', cf, false));
  return dedupeRuntimePatientDeleteDocs_(out);
}

function dedupeRuntimePatientDeleteDocs_(items) {
  var seen = {};
  var out = [];
  (items || []).forEach(function (item) {
    if (!item) return;
    var key = String(item.documentPath || item.documentId || item.id || JSON.stringify(item));
    if (!key || seen[key]) return;
    seen[key] = true;
    out.push(item);
  });
  return out;
}

function assertRuntimePatientDeleteBounded_(cfg, linked) {
  var maxDocs = Math.max(50, Number((cfg && cfg.maxPatientDeleteLinkedDocs) || 300));
  var count = summarizeRuntimePatientDeleteLinkedData_(linked).totalLinkedDocs;
  if (count > maxDocs) {
    throw new Error('PATIENT_DELETE_TOO_MANY_LINKED_DOCS: ' + count + ' > ' + maxDocs);
  }
}

function summarizeRuntimePatientDeleteLinkedData_(linked) {
  linked = linked || {};
  var count = 0;
  ['driveImports', 'legacyPrescriptions', 'debts', 'advances', 'bookings', 'prescriptionIntakes', 'doctorLinks', 'families', 'identityRequests'].forEach(function (key) {
    count += ((linked[key] || []).length);
  });
  if (linked.patient) count++;
  if (linked.index) count++;
  if (linked.therapeuticAdvice) count++;
  return {
    totalLinkedDocs: count,
    driveImports: (linked.driveImports || []).length,
    prescriptions: (linked.legacyPrescriptions || []).length,
    debts: (linked.debts || []).length,
    advances: (linked.advances || []).length,
    bookings: (linked.bookings || []).length,
    prescriptionIntakes: (linked.prescriptionIntakes || []).length,
    doctorLinks: (linked.doctorLinks || []).length,
    families: (linked.families || []).length,
    identityRequests: (linked.identityRequests || []).length,
    patientExists: !!linked.patient,
    indexExists: !!linked.index,
    therapeuticAdviceExists: !!linked.therapeuticAdvice
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
      delete runtimeIndex.publishState.doctorLinks[cf + '__manual'];
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

function appendRuntimePatientDeleteDocumentDeletes_(cfg, writes, linked) {
  var cf = linked.cf;
  appendRuntimePatientDeleteDocs_(cfg, writes, linked.debts);
  appendRuntimePatientDeleteDocs_(cfg, writes, linked.advances);
  appendRuntimePatientDeleteDocs_(cfg, writes, linked.bookings);
  appendRuntimePatientDeleteDocs_(cfg, writes, linked.legacyPrescriptions);
  appendRuntimePatientDeleteDocs_(cfg, writes, linked.prescriptionIntakes);
  appendRuntimePatientDeleteDocs_(cfg, writes, linked.doctorLinks);
  appendRuntimePatientDeleteDocs_(cfg, writes, linked.identityRequests);
  writes.push(buildRuntimePatientDeleteDeleteWriteFromPath_(cfg, ['patient_therapeutic_advice', cf]));
  writes.push(buildRuntimePatientDeleteDeleteWriteFromPath_(cfg, ['patient_dashboard_index', cf]));
  writes.push(buildRuntimePatientDeleteDeleteWriteFromPath_(cfg, ['patients', cf]));
  writes.push(buildRuntimePatientDeleteDeleteWriteFromPath_(cfg, ['doctor_patient_links', cf + '__manual']));
  writes.push(buildRuntimePatientDeleteDeleteWriteFromPath_(cfg, ['doctor_patient_links', cf + '__primary']));
}

function appendRuntimePatientDeleteDocs_(cfg, writes, docs) {
  (docs || []).forEach(function (doc) {
    var write = buildRuntimePatientDeleteDeleteWriteFromDoc_(cfg, doc);
    if (write) writes.push(write);
  });
}

function appendRuntimePatientDeleteFamilyWrites_(cfg, writes, families, cf, nowIso) {
  (families || []).forEach(function (family) {
    var currentMembers = uniqueNonEmptyStrings_(family.memberFiscalCodes || []);
    var nextMembers = currentMembers.filter(function (item) { return normalizeCf_(item) !== cf; });
    if (!nextMembers.length) {
      var deleteWrite = buildRuntimePatientDeleteDeleteWriteFromDoc_(cfg, family);
      if (deleteWrite) writes.push(deleteWrite);
      return;
    }
    var docId = String(family.documentId || family.familyId || family.id || '').trim();
    if (!docId) return;
    var data = cloneRuntimePlainObject_(family);
    delete data.documentId;
    delete data.documentPath;
    delete data.collectionId;
    delete data.parentDocumentId;
    data.memberFiscalCodes = nextMembers;
    data.updatedAt = nowIso;
    writes.push(buildFirestoreUpdateWrite_(cfg, 'families', docId, data));
  });
}

function buildRuntimePatientDeleteTotalsPatch_(cfg, linked, nowIso) {
  var current = getFirestoreDocumentByPath_(cfg, ['dashboard_totals', 'main']) || {};
  var archiveDelta = calculateRuntimePatientDeleteArchiveDeltas_(linked);
  var debtDelta = (linked.debts || []).reduce(function (sum, item) {
    return sum + Number(item.residualAmount || item.amount || item.debtAmount || 0);
  }, 0);
  return {
    recipeCount: Math.max(0, Number(current.recipeCount || 0) - archiveDelta.recipeCount),
    dpcCount: Math.max(0, Number(current.dpcCount || 0) - archiveDelta.dpcCount),
    expiringCount: Math.max(0, Number(current.expiringCount || 0) - archiveDelta.expiringPatientCount),
    debtAmount: roundDashboardTotalsAmount_(Number(current.debtAmount || 0) - debtDelta),
    advanceCount: Math.max(0, Number(current.advanceCount || 0) - (linked.advances || []).length),
    bookingCount: Math.max(0, Number(current.bookingCount || 0) - (linked.bookings || []).length),
    updatedAt: nowIso,
    generatedAt: nowIso,
    archiveTotalsSource: 'runtime_signal_patient_delete',
    appManagedTotalsSource: 'runtime_signal_patient_delete'
  };
}

function calculateRuntimePatientDeleteArchiveDeltas_(linked) {
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

function buildRuntimePatientDeleteExpiringRecipesPatch_(cfg, cf, linked, nowIso) {
  var current = getFirestoreDocumentByPathSafe_(cfg, ['dashboard_expiring_recipes', 'main']);
  if (!current || !Array.isArray(current.items)) return null;
  var nextItems = current.items.filter(function (item) {
    return normalizeCf_(item && (item.patientFiscalCode || item.fiscalCode)) !== cf;
  });
  if (nextItems.length === current.items.length) return null;
  var archiveDelta = calculateRuntimePatientDeleteArchiveDeltas_(linked);
  return {
    items: nextItems,
    itemCount: nextItems.length,
    totalExpiringCount: Math.max(0, Number(current.totalExpiringCount || current.itemCount || current.items.length || 0) - archiveDelta.expiringPatientCount),
    updatedAt: nowIso,
    generatedAt: nowIso,
    source: 'runtime_signal_patient_delete'
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
