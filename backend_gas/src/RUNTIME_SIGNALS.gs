function readRuntimeGate_() {
  var cfg = getPhboxConfig_();
  try {
    var gate = getFirestoreDocumentByPath_(cfg, ['phbox_runtime', 'main']);
    if (!gate) {
      return {
        ok: false,
        exists: false,
        fallbackPipeline: true,
        reason: 'GATE_MISSING',
        gate: buildDefaultRuntimeGate_('red')
      };
    }
    gate.status = String(gate.status || '').trim().toLowerCase();
    if (!isRuntimeGateCoherent_(gate)) {
      repairRuntimeGate_('GATE_INCOHERENT');
      return {
        ok: false,
        exists: true,
        fallbackPipeline: true,
        reason: 'GATE_INCOHERENT',
        gate: gate
      };
    }
    return {
      ok: true,
      exists: true,
      fallbackPipeline: false,
      reason: '',
      gate: normalizeRuntimeGate_(gate)
    };
  } catch (e) {
    return {
      ok: false,
      exists: false,
      fallbackPipeline: true,
      reason: 'GATE_READ_ERROR: ' + normalizeRuntimeErrorMessage_(e),
      gate: null
    };
  }
}

function shouldFastExit_(gateRead) {
  return !!(gateRead && gateRead.ok && gateRead.gate && String(gateRead.gate.status || '').toLowerCase() === 'red');
}

function runRuntimeSignalGate_(options) {
  options = options || {};
  var cfg = getPhboxConfig_();
  var nowIso = new Date().toISOString();
  var gateRead = readRuntimeGate_();

  if (!gateRead.ok && gateRead.reason === 'GATE_MISSING') {
    ensureRuntimeGateCreated_('red');
    return {
      ok: true,
      mode: 'fallback_pipeline',
      fallbackPipeline: true,
      reason: 'GATE_MISSING_CREATED',
      readsEstimated: 1
    };
  }

  if (!gateRead.ok || gateRead.fallbackPipeline) {
    return {
      ok: true,
      mode: 'fallback_pipeline',
      fallbackPipeline: true,
      reason: gateRead.reason || 'GATE_UNAVAILABLE',
      readsEstimated: 1
    };
  }

  if (shouldFastExit_(gateRead)) {
    updateRuntimeGate_(buildRuntimeGatePatch_({
      status: 'red',
      pendingWorkCount: 0,
      nextSignalId: '',
      lastRunAt: nowIso,
      lastIdleExitAt: nowIso,
      updatedAt: nowIso
    }));
    return {
      ok: true,
      mode: 'fast_exit',
      fastExit: true,
      fallbackPipeline: false,
      reason: 'GATE_RED',
      gate: gateRead.gate,
      readsEstimated: 1
    };
  }

  var signal = getNextPendingSignal_();
  if (!signal) {
    updateRuntimeGate_(buildRuntimeGatePatch_({
      status: 'red',
      pendingWorkCount: 0,
      nextSignalId: '',
      lastRunAt: nowIso,
      lastIdleExitAt: nowIso,
      updatedAt: nowIso
    }));
    return {
      ok: true,
      mode: 'green_without_signal',
      handled: true,
      fallbackPipeline: false,
      reason: 'NO_PENDING_SIGNAL',
      readsEstimated: 2
    };
  }

  markSignalProcessing_(signal);

  try {
    var processed = processRuntimeSignal_(signal);
    if (processed && processed.requiresFullPipeline) {
      return {
        ok: true,
        mode: 'requires_full_pipeline',
        requiresFullPipeline: true,
        fallbackPipeline: true,
        signal: signal,
        signalResult: processed,
        readsEstimated: processed.readsEstimated || 2
      };
    }
    markSignalDone_(signal, processed || {});
    var gateAfter = refreshRuntimeGateAfterSignal_();
    return {
      ok: true,
      mode: 'signal_processed',
      handled: true,
      fallbackPipeline: false,
      signalId: signal.signalId,
      domain: signal.domain,
      operation: signal.operation,
      signalResult: processed || {},
      gateAfter: gateAfter,
      readsEstimated: processed && processed.readsEstimated ? processed.readsEstimated : 4
    };
  } catch (e) {
    markSignalError_(signal, e);
    var gateError = refreshRuntimeGateAfterSignal_();
    return {
      ok: false,
      mode: 'signal_error',
      handled: true,
      fallbackPipeline: false,
      signalId: signal.signalId,
      domain: signal.domain,
      operation: signal.operation,
      error: normalizeRuntimeErrorMessage_(e),
      gateAfter: gateError
    };
  }
}

function finalizeRuntimeSignalFullPipeline_(gateResult, pipelineResult) {
  if (!gateResult || !gateResult.signal || !gateResult.requiresFullPipeline) return null;
  var signal = gateResult.signal;
  if (pipelineResult && pipelineResult.ok) {
    markSignalDone_(signal, {
      fullPipeline: true,
      pipelineNeedsAnotherRun: !!pipelineResult.needsAnotherRun
    });
  } else {
    markSignalError_(signal, new Error('FULL_PIPELINE_FAILED'));
  }
  return refreshRuntimeGateAfterSignal_();
}

function getNextPendingSignal_() {
  var cfg = getPhboxConfig_();
  var url = 'https://firestore.googleapis.com/v1/projects/' + encodeURIComponent(cfg.firestoreProjectId) + '/databases/(default)/documents:runQuery';
  var payload = {
    structuredQuery: {
      from: [{ collectionId: 'phbox_signals' }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'status' },
          op: 'EQUAL',
          value: { stringValue: 'pending' }
        }
      },
      limit: 1
    }
  };
  var rows = fetchFirestoreJsonWithRetry_(url, {
    method: 'post',
    contentType: 'application/json',
    payload: JSON.stringify(payload)
  });
  if (!Array.isArray(rows)) return null;
  for (var i = 0; i < rows.length; i++) {
    if (rows[i] && rows[i].document) {
      return normalizeRuntimeSignal_(mapFirestoreDocumentToPlainObject_(rows[i].document));
    }
  }
  return null;
}

function markSignalProcessing_(signal) {
  var cfg = getPhboxConfig_();
  var nowIso = new Date().toISOString();
  var data = buildRuntimeSignalWriteData_(signal, {
    status: 'processing',
    updatedAt: nowIso,
    attempts: Math.max(0, Number(signal && signal.attempts || 0)) + 1,
    lastError: ''
  });
  executeFirestoreCommit_(cfg, [buildFirestoreUpdateWrite_(cfg, 'phbox_signals', data.signalId, data)]);
  return data;
}

function markSignalDone_(signal, result) {
  var cfg = getPhboxConfig_();
  var nowIso = new Date().toISOString();
  var data = buildRuntimeSignalWriteData_(signal, {
    status: 'done',
    updatedAt: nowIso,
    processedAt: nowIso,
    lastError: '',
    result: sanitizeRuntimeSignalResult_(result || {})
  });
  executeFirestoreCommit_(cfg, [buildFirestoreUpdateWrite_(cfg, 'phbox_signals', data.signalId, data)]);
  return data;
}

function markSignalError_(signal, error) {
  var cfg = getPhboxConfig_();
  var nowIso = new Date().toISOString();
  var data = buildRuntimeSignalWriteData_(signal, {
    status: 'error',
    updatedAt: nowIso,
    processedAt: nowIso,
    lastError: normalizeRuntimeSignalError_(error)
  });
  executeFirestoreCommit_(cfg, [buildFirestoreUpdateWrite_(cfg, 'phbox_signals', data.signalId, data)]);
  return data;
}

function refreshRuntimeGateAfterSignal_() {
  var next = getNextPendingSignal_();
  var nowIso = new Date().toISOString();
  var data = buildRuntimeGatePatch_({
    status: next ? 'green' : 'red',
    pendingWorkCount: next ? 1 : 0,
    nextSignalId: next ? next.signalId : '',
    lastChangedAt: nowIso,
    lastRunAt: nowIso,
    lastIdleExitAt: next ? null : nowIso,
    updatedAt: nowIso
  });
  updateRuntimeGate_(data);
  return data;
}

function createRuntimeSignal_(payload) {
  payload = payload || {};
  var cfg = getPhboxConfig_();
  var nowIso = new Date().toISOString();
  var signalId = String(payload.signalId || '').trim() || Utilities.getUuid();
  var signal = buildRuntimeSignalWriteData_(payload, {
    signalId: signalId,
    status: 'pending',
    createdAt: payload.createdAt || nowIso,
    updatedAt: nowIso,
    processedAt: null,
    attempts: 0,
    lastError: ''
  });
  var gate = buildRuntimeGatePatch_({
    status: 'green',
    pendingWorkCount: 1,
    nextSignalId: signalId,
    lastChangedAt: nowIso,
    updatedAt: nowIso
  });
  executeFirestoreCommit_(cfg, [
    buildFirestoreUpdateWrite_(cfg, 'phbox_signals', signalId, signal),
    buildFirestoreUpdateWrite_(cfg, 'phbox_runtime', 'main', gate)
  ]);
  return { ok: true, signalId: signalId, gateStatus: 'green' };
}

function initializeRuntimeSignalGateRed() {
  ensureRuntimeGateCreated_('red');
  return { ok: true, status: 'red', document: 'phbox_runtime/main' };
}

function processRuntimeSignal_(signal) {
  signal = normalizeRuntimeSignal_(signal);
  var domain = String(signal.domain || '').trim();
  if (domain === 'debts') return processRuntimeAppManagedSignal_(signal, 'debts');
  if (domain === 'advances') return processRuntimeAppManagedSignal_(signal, 'advances');
  if (domain === 'bookings') return processRuntimeAppManagedSignal_(signal, 'bookings');
  if (domain === 'deletePdf') return processRuntimeDeletePdfSignal_(signal);

  if (signal.requiresDriveAction || signal.requiresGmailAction || domain === 'gmail' || domain === 'drive' || domain === 'backup' || domain === 'prescriptions') {
    return {
      ok: true,
      requiresFullPipeline: true,
      reason: 'SIGNAL_REQUIRES_FULL_PIPELINE',
      domain: domain
    };
  }

  throw new Error('UNSUPPORTED_SIGNAL_DOMAIN: ' + domain);
}

function processRuntimeAppManagedSignal_(signal, collectionId) {
  var cfg = getPhboxConfig_();
  var targetPath = normalizeRuntimeSignalTargetPath_(signal.targetPath);
  if (!targetPath.length) throw new Error('TARGET_PATH_MISSING');

  var target = getFirestoreDocumentByPath_(cfg, targetPath);
  var operation = String(signal.operation || '').trim().toLowerCase();
  var isDeleteOperation = operation === 'delete' || operation === 'deleted' || operation === 'remove' || operation === 'removed';
  var targetAlreadyDeleted = false;

  if (!target) {
    if (!isDeleteOperation) throw new Error('TARGET_NOT_FOUND');
    targetAlreadyDeleted = true;
  }

  var cf = normalizeCf_(signal.targetFiscalCode || (target ? resolvePatientDashboardCollectionGroupCf_(target, collectionId) : ''));
  if (!cf) throw new Error(targetAlreadyDeleted ? 'TARGET_CF_MISSING_AFTER_DELETE' : 'TARGET_CF_MISSING');

  var indexResult = signal.requiresIndexUpdate === false
    ? { ok: true, skipped: true }
    : patchPatientDashboardIndexForAppDomain_(cfg, cf, collectionId);

  var totalsResult = signal.requiresTotalsUpdate
    ? refreshDashboardTotalsForAppDomain_(cfg, collectionId)
    : { ok: true, skipped: true };

  return {
    ok: true,
    domain: collectionId,
    operation: operation,
    cf: cf,
    targetPath: targetPath.join('/'),
    targetAlreadyDeleted: targetAlreadyDeleted,
    reason: targetAlreadyDeleted ? 'DELETE_TARGET_ALREADY_ABSENT' : '',
    index: indexResult,
    totals: totalsResult,
    readsEstimated: signal.requiresTotalsUpdate ? 5 : 4
  };
}

function processRuntimeDeletePdfSignal_(signal) {
  var cfg = getPhboxConfig_();
  var targetPath = normalizeRuntimeSignalTargetPath_(signal.targetPath);
  if (!targetPath.length && signal.targetDocumentId) targetPath = ['drive_pdf_imports', String(signal.targetDocumentId).trim()];
  if (!targetPath.length) throw new Error('TARGET_PATH_MISSING');
  var target = getFirestoreDocumentByPath_(cfg, targetPath);
  if (!target) throw new Error('TARGET_NOT_FOUND');
  if (target.deletePdfRequested !== true) throw new Error('DELETE_PDF_NOT_REQUESTED');

  var driveFileId = resolveArchiveDeleteDriveFileId_(target);
  if (!driveFileId) throw new Error('DRIVE_FILE_ID_MISSING');
  var driveResult = trashArchivePdfIfPresent_(driveFileId, cfg);
  var nowIso = new Date().toISOString();
  var cf = normalizeCf_(signal.targetFiscalCode || target.patientFiscalCode || target.fiscalCode || target.patientCf);
  var update = cloneRuntimePlainObject_(target);
  delete update.documentId;
  delete update.documentPath;
  delete update.collectionId;
  delete update.parentDocumentId;
  update.status = 'deleted_pdf';
  update.pdfDeleted = true;
  update.deletePdfRequested = false;
  update.deletedAt = update.deletedAt || nowIso;
  update.updatedAt = nowIso;
  update.webViewLink = '';
  update.openUrl = '';

  executeFirestoreCommit_(cfg, [buildFirestoreUpdateWrite_(cfg, 'drive_pdf_imports', String(target.documentId || signal.targetDocumentId || driveFileId), update)]);

  var indexResult = { ok: true, skipped: true };
  if (signal.requiresIndexUpdate !== false && cf) {
    indexResult = patchPatientDashboardArchiveIndexAfterDelete_(cfg, cf);
  }

  var totalsResult = signal.requiresTotalsUpdate
    ? refreshDashboardTotalsAfterDeletePdf_(cfg, target)
    : { ok: true, skipped: true };

  return {
    ok: true,
    domain: 'deletePdf',
    cf: cf,
    driveFileId: driveFileId,
    drive: driveResult,
    firestoreImportUpdated: true,
    index: indexResult,
    totals: totalsResult,
    readsEstimated: signal.requiresTotalsUpdate ? 5 : 4
  };
}

function patchPatientDashboardIndexForAppDomain_(cfg, cf, collectionId) {
  cf = normalizeCf_(cf);
  var existing = getFirestoreDocumentByPath_(cfg, ['patient_dashboard_index', cf]);
  if (!existing) {
    return syncPatientDashboardIndexForFiscalCodeInternal_(cf, { useLock: false });
  }

  var nowIso = new Date().toISOString();
  var data = { updatedAt: nowIso, source: 'runtime_signal_' + collectionId };
  if (collectionId === 'debts') {
    var debt = aggregateRuntimeAppDocsForCf_(cfg, 'debts', cf);
    data.debtCount = Math.max(0, Number(debt.count || 0));
    data.debtAmount = roundDashboardTotalsAmount_(debt.amount || 0);
    data.hasDebt = data.debtCount > 0 || Math.abs(data.debtAmount) > 0.005;
  } else if (collectionId === 'advances') {
    var advances = aggregateRuntimeAppDocsForCf_(cfg, 'advances', cf);
    data.advanceCount = Math.max(0, Number(advances.count || 0));
    data.hasAdvance = data.advanceCount > 0;
  } else if (collectionId === 'bookings') {
    var bookings = aggregateRuntimeAppDocsForCf_(cfg, 'bookings', cf);
    data.bookingCount = Math.max(0, Number(bookings.count || 0));
    data.hasBooking = data.bookingCount > 0;
  } else {
    throw new Error('UNSUPPORTED_APP_DOMAIN: ' + collectionId);
  }

  executeFirestoreCommit_(cfg, [buildFirestorePatchWrite_(cfg, 'patient_dashboard_index', cf, data, Object.keys(data))]);
  return { ok: true, cf: cf, patched: true, data: data };
}

function patchPatientDashboardArchiveIndexAfterDelete_(cfg, cf) {
  var items = fetchPatientDashboardDriveImportsForCf_(cfg, cf);
  var archive = buildPatientDashboardArchiveAggregateFromItems_(items);
  var existing = getFirestoreDocumentByPath_(cfg, ['patient_dashboard_index', cf]);
  if (!existing) {
    return syncPatientDashboardIndexForFiscalCodeInternal_(cf, { useLock: false });
  }
  var nowIso = new Date().toISOString();
  var data = {
    recipeCount: archive ? Math.max(0, Number(archive.recipeCount || 0)) : 0,
    hasRecipes: archive ? Number(archive.recipeCount || 0) > 0 : false,
    hasDpc: archive ? Number(archive.dpcCount || 0) > 0 : false,
    hasExpiry: !!(archive && archive.nearestExpiryDate && isDashboardExpiryAlert_(parseDashboardTotalsDate_(archive.nearestExpiryDate))),
    lastPrescriptionDate: archive ? archive.lastPrescriptionDate || null : null,
    nearestExpiryDate: archive ? archive.nearestExpiryDate || null : null,
    updatedAt: nowIso,
    source: 'runtime_signal_delete_pdf'
  };
  executeFirestoreCommit_(cfg, [buildFirestorePatchWrite_(cfg, 'patient_dashboard_index', cf, data, Object.keys(data))]);
  return { ok: true, cf: cf, patched: true, data: data };
}

function refreshDashboardTotalsForAppDomain_(cfg, collectionId) {
  var current = getFirestoreDocumentByPath_(cfg, ['dashboard_totals', 'main']) || {};
  var nowIso = new Date().toISOString();
  var data = {
    updatedAt: nowIso,
    generatedAt: nowIso,
    appManagedTotalsReadOk: true,
    appManagedTotalsSource: 'runtime_signal_' + collectionId
  };

  if (collectionId === 'debts') {
    data.debtAmount = roundDashboardTotalsAmount_(aggregateRuntimeCollectionGroup_(cfg, 'debts', { sumField: 'residualAmount' }).sum);
  } else if (collectionId === 'advances') {
    data.advanceCount = Math.max(0, Number(aggregateRuntimeCollectionGroup_(cfg, 'advances', {}).count || 0));
  } else if (collectionId === 'bookings') {
    data.bookingCount = Math.max(0, Number(aggregateRuntimeCollectionGroup_(cfg, 'bookings', {}).count || 0));
  } else {
    throw new Error('UNSUPPORTED_TOTALS_DOMAIN: ' + collectionId);
  }

  executeFirestoreCommit_(cfg, [buildFirestorePatchWrite_(cfg, 'dashboard_totals', 'main', data, Object.keys(data))]);
  return { ok: true, patched: true, data: data, previousUpdatedAt: current.updatedAt || null };
}

function refreshDashboardTotalsAfterDeletePdf_(cfg, importDoc) {
  var current = getFirestoreDocumentByPath_(cfg, ['dashboard_totals', 'main']) || {};
  var nowIso = new Date().toISOString();
  var recipeDelta = isActivePatientDashboardArchiveDoc_(importDoc) ? Math.max(1, Number(importDoc.prescriptionCount || importDoc.recipeCount || 1)) : 0;
  var dpcDelta = isActivePatientDashboardArchiveDoc_(importDoc) && (importDoc.isDpc || importDoc.hasDpc) ? 1 : 0;
  var expiryDate = parseDashboardTotalsDate_(importDoc && (importDoc.prescriptionDate || importDoc.createdAt));
  var expiryDelta = expiryDate && isDashboardExpiryAlert_(addDaysForDashboardTotals_(expiryDate, 30)) ? 1 : 0;
  var data = {
    recipeCount: Math.max(0, Number(current.recipeCount || 0) - recipeDelta),
    dpcCount: Math.max(0, Number(current.dpcCount || 0) - dpcDelta),
    expiringCount: Math.max(0, Number(current.expiringCount || 0) - expiryDelta),
    updatedAt: nowIso,
    generatedAt: nowIso,
    archiveTotalsSource: 'runtime_signal_delete_pdf'
  };
  executeFirestoreCommit_(cfg, [buildFirestorePatchWrite_(cfg, 'dashboard_totals', 'main', data, Object.keys(data))]);
  return { ok: true, patched: true, data: data };
}

function aggregateRuntimeAppDocsForCf_(cfg, collectionId, cf) {
  var docs = fetchPatientDashboardAppDocsForCf_(cfg, cf, collectionId);
  if (collectionId === 'debts') return buildPatientDashboardDebtAggregateFromItems_(docs) || { count: 0, amount: 0 };
  if (collectionId === 'advances') return buildPatientDashboardAdvanceAggregateFromItems_(docs) || { count: 0 };
  if (collectionId === 'bookings') return buildPatientDashboardBookingAggregateFromItems_(docs) || { count: 0 };
  return { count: 0 };
}

function aggregateRuntimeCollectionGroup_(cfg, collectionId, options) {
  options = options || {};
  var aggregations = [{ count: {}, alias: 'count' }];
  if (options.sumField) {
    aggregations.push({ sum: { field: { fieldPath: String(options.sumField) } }, alias: 'sum' });
  }
  var url = 'https://firestore.googleapis.com/v1/projects/' + encodeURIComponent(cfg.firestoreProjectId) + '/databases/(default)/documents:runAggregationQuery';
  var payload = {
    structuredAggregationQuery: {
      structuredQuery: {
        from: [{ collectionId: String(collectionId || '').trim(), allDescendants: true }]
      },
      aggregations: aggregations
    }
  };
  var rows = fetchFirestoreJsonWithRetry_(url, {
    method: 'post',
    contentType: 'application/json',
    payload: JSON.stringify(payload)
  });
  return readRuntimeAggregationResult_(rows);
}

function readRuntimeAggregationResult_(rows) {
  var out = { count: 0, sum: 0 };
  if (!Array.isArray(rows)) return out;
  rows.forEach(function (row) {
    var fields = row && row.result && row.result.aggregateFields;
    if (!fields) return;
    if (fields.count) out.count = readFirestoreAggregationValue_(fields.count);
    if (fields.sum) out.sum = readFirestoreAggregationValue_(fields.sum);
  });
  return out;
}

function updateRuntimeGate_(data) {
  var cfg = getPhboxConfig_();
  executeFirestoreCommit_(cfg, [buildFirestoreUpdateWrite_(cfg, 'phbox_runtime', 'main', data)]);
  return data;
}

function ensureRuntimeGateCreated_(status) {
  return updateRuntimeGate_(buildDefaultRuntimeGate_(status || 'red'));
}

function repairRuntimeGate_(reason) {
  var gate = buildDefaultRuntimeGate_('red');
  gate.lastError = String(reason || '').trim();
  return updateRuntimeGate_(gate);
}

function buildDefaultRuntimeGate_(status) {
  var nowIso = new Date().toISOString();
  return buildRuntimeGatePatch_({
    status: status || 'red',
    pendingWorkCount: 0,
    nextSignalId: '',
    lastChangedAt: nowIso,
    lastRunAt: null,
    lastIdleExitAt: null,
    updatedAt: nowIso
  });
}

function buildRuntimeGatePatch_(data) {
  data = data || {};
  return {
    status: String(data.status || 'red').trim().toLowerCase() === 'green' ? 'green' : 'red',
    pendingWorkCount: Math.max(0, Number(data.pendingWorkCount || 0)),
    nextSignalId: String(data.nextSignalId || '').trim(),
    lastChangedAt: data.lastChangedAt || null,
    lastRunAt: data.lastRunAt || null,
    lastIdleExitAt: data.lastIdleExitAt || null,
    updatedAt: data.updatedAt || new Date().toISOString()
  };
}

function normalizeRuntimeGate_(gate) {
  return buildRuntimeGatePatch_({
    status: gate.status,
    pendingWorkCount: gate.pendingWorkCount,
    nextSignalId: gate.nextSignalId,
    lastChangedAt: gate.lastChangedAt,
    lastRunAt: gate.lastRunAt,
    lastIdleExitAt: gate.lastIdleExitAt,
    updatedAt: gate.updatedAt
  });
}

function isRuntimeGateCoherent_(gate) {
  if (!gate) return false;
  var status = String(gate.status || '').trim().toLowerCase();
  if (status !== 'red' && status !== 'green') return false;
  if (isNaN(Number(gate.pendingWorkCount || 0))) return false;
  return true;
}

function normalizeRuntimeSignal_(signal) {
  signal = signal || {};
  var signalId = String(signal.signalId || signal.documentId || '').trim();
  return buildRuntimeSignalWriteData_(signal, {
    signalId: signalId,
    status: String(signal.status || 'pending').trim().toLowerCase(),
    attempts: Math.max(0, Number(signal.attempts || 0))
  });
}

function buildRuntimeSignalWriteData_(signal, overrides) {
  signal = signal || {};
  overrides = overrides || {};
  var nowIso = new Date().toISOString();
  var signalId = String(overrides.signalId || signal.signalId || signal.documentId || '').trim();
  return {
    signalId: signalId,
    status: String(overrides.status || signal.status || 'pending').trim().toLowerCase(),
    domain: String(overrides.domain || signal.domain || '').trim(),
    operation: String(overrides.operation || signal.operation || '').trim(),
    targetPath: String(overrides.targetPath || signal.targetPath || '').trim(),
    targetFiscalCode: normalizeCf_(overrides.targetFiscalCode || signal.targetFiscalCode || ''),
    targetDocumentId: String(overrides.targetDocumentId || signal.targetDocumentId || '').trim(),
    requiresTotalsUpdate: readRuntimeBool_(overrides.requiresTotalsUpdate !== undefined ? overrides.requiresTotalsUpdate : signal.requiresTotalsUpdate),
    requiresIndexUpdate: overrides.requiresIndexUpdate === undefined ? readRuntimeBool_(signal.requiresIndexUpdate !== false) : readRuntimeBool_(overrides.requiresIndexUpdate),
    requiresDriveAction: readRuntimeBool_(overrides.requiresDriveAction !== undefined ? overrides.requiresDriveAction : signal.requiresDriveAction),
    requiresGmailAction: readRuntimeBool_(overrides.requiresGmailAction !== undefined ? overrides.requiresGmailAction : signal.requiresGmailAction),
    createdAt: overrides.createdAt !== undefined ? overrides.createdAt : (signal.createdAt || nowIso),
    updatedAt: overrides.updatedAt !== undefined ? overrides.updatedAt : (signal.updatedAt || nowIso),
    processedAt: overrides.processedAt !== undefined ? overrides.processedAt : (signal.processedAt || null),
    attempts: Math.max(0, Number(overrides.attempts !== undefined ? overrides.attempts : (signal.attempts || 0))),
    lastError: String(overrides.lastError !== undefined ? overrides.lastError : (signal.lastError || '')).trim(),
    result: overrides.result !== undefined ? overrides.result : (signal.result || null)
  };
}

function sanitizeRuntimeSignalResult_(result) {
  result = result || {};
  return {
    ok: result.ok !== false,
    domain: String(result.domain || '').trim(),
    cf: normalizeCf_(result.cf || ''),
    reason: String(result.reason || '').trim(),
    readsEstimated: Number(result.readsEstimated || 0),
    updatedAt: new Date().toISOString()
  };
}

function normalizeRuntimeSignalTargetPath_(targetPath) {
  var text = String(targetPath || '').trim();
  if (!text) return [];
  var marker = '/documents/';
  var idx = text.indexOf(marker);
  if (idx >= 0) text = text.slice(idx + marker.length);
  text = text.replace(/^\/+/, '').replace(/\/+$/, '');
  if (!text) return [];
  return text.split('/').map(function (part) {
    return decodeURIComponent(String(part || '').trim());
  }).filter(function (part) {
    return !!part;
  });
}

function normalizeRuntimeSignalError_(error) {
  var text = normalizeRuntimeErrorMessage_(error);
  if (text.indexOf('TARGET_NOT_FOUND') >= 0) return 'TARGET_NOT_FOUND';
  if (text.indexOf('TARGET_PATH_MISSING') >= 0) return 'TARGET_PATH_MISSING';
  if (text.indexOf('TARGET_CF_MISSING') >= 0) return 'TARGET_CF_MISSING';
  if (text.indexOf('DELETE_PDF_NOT_REQUESTED') >= 0) return 'DELETE_PDF_NOT_REQUESTED';
  if (text.indexOf('DRIVE_FILE_ID_MISSING') >= 0) return 'DRIVE_FILE_ID_MISSING';
  return text;
}

function readRuntimeBool_(value) {
  if (value === true) return true;
  if (value === false) return false;
  var text = String(value || '').trim().toLowerCase();
  return text === 'true' || text === '1' || text === 'yes' || text === 'si' || text === 'sì';
}

function cloneRuntimePlainObject_(value) {
  return JSON.parse(JSON.stringify(value || {}));
}
