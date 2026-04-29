function buildDashboardTotalsWriteCandidate_(runtimeIndex, cfg) {
  try {
    runtimeIndex = ensureRuntimeIndexShape_(runtimeIndex, cfg);
    var archiveTotals = buildArchiveDashboardTotalsFromRuntimeIndex_(runtimeIndex, cfg);
    var previousData = getPreviousDashboardTotalsData_(runtimeIndex);
    var appTotalsResult = fetchAppManagedDashboardTotals_(cfg);
    var appTotals = appTotalsResult.ok ? appTotalsResult.data : buildAppManagedTotalsFromPrevious_(previousData);
    var content = buildDashboardTotalsHashPayload_(archiveTotals, appTotals, cfg);
    var nextHash = computeStableHashForData_(content);
    var currentHash = String((runtimeIndex.publishState && runtimeIndex.publishState.dashboardTotals) || '');

    if (nextHash === currentHash) {
      return {
        write: null,
        hash: nextHash,
        data: previousData,
        error: appTotalsResult.ok ? '' : appTotalsResult.error
      };
    }

    var nowIso = new Date().toISOString();
    var data = {
      schemaVersion: 1,
      source: 'phbox_backend_runtime_index',
      archiveTotalsSource: archiveTotals.source || 'runtime_index',
      recipeCount: archiveTotals.recipeCount,
      dpcCount: archiveTotals.dpcCount,
      debtAmount: appTotals.debtAmount,
      advanceCount: appTotals.advanceCount,
      bookingCount: appTotals.bookingCount,
      expiringCount: archiveTotals.expiringCount,
      archiveUpdatedAt: runtimeIndex.updatedAt || null,
      appManagedTotalsReadOk: !!appTotalsResult.ok,
      appManagedTotalsSource: appTotalsResult.source || '',
      appManagedTotalsError: appTotalsResult.error || '',
      generatedAt: nowIso,
      updatedAt: nowIso
    };

    return {
      write: buildFirestoreUpdateWrite_(cfg, 'dashboard_totals', 'main', data),
      hash: nextHash,
      data: data,
      error: ''
    };
  } catch (e) {
    return {
      write: null,
      hash: '',
      data: null,
      error: normalizeRuntimeErrorMessage_(e)
    };
  }
}

function buildArchiveDashboardTotalsFromRuntimeIndex_(runtimeIndex, cfg) {
  var manifests = Object.keys((runtimeIndex && runtimeIndex.filesById) || {}).map(function (driveFileId) {
    return runtimeIndex.filesById[driveFileId];
  }).filter(function (item) {
    return isActiveVisibleManifestForDashboardTotals_(item);
  });

  var runtimeTotals = buildArchiveDashboardTotalsFromManifests_(manifests, 'runtime_index');
  if (!isEmptyArchiveDashboardTotals_(runtimeTotals)) {
    return runtimeTotals;
  }

  var firestoreFallback = fetchArchiveDashboardTotalsFromFirestoreFallback_(cfg);
  if (firestoreFallback && !isEmptyArchiveDashboardTotals_(firestoreFallback)) {
    return firestoreFallback;
  }

  return runtimeTotals;
}

function isActiveVisibleManifestForDashboardTotals_(manifest) {
  if (!manifest) return false;
  if (manifest.pdfDeleted || manifest.deletePdfRequested) return false;
  var kind = String(manifest.kind || '');
  if (kind === 'merged_component' || kind === 'canonical_source_retained' || kind === 'merge_pending_component') return false;
  var status = String(manifest.status || '').trim().toLowerCase();
  if (status === 'deleted_pdf' || status === 'deleted' || status === 'discarded_non_prescription') return false;
  return !!(normalizeCf_(manifest.patientFiscalCode) || String(manifest.patientFullName || '').trim());
}

function buildArchiveDashboardTotalsFromManifests_(manifests, source) {
  var expiringPatientKeys = {};
  var recipeCount = 0;
  var dpcCount = 0;

  (manifests || []).forEach(function (manifest) {
    recipeCount += resolveManifestPrescriptionCount_(manifest);
    if (manifest && manifest.isDpc) dpcCount += 1;

    var key = buildDashboardTotalsPatientKey_(manifest);
    var baseDate = parseDashboardTotalsDate_(manifest && (manifest.prescriptionDate || manifest.createdAt));
    var expiryDate = baseDate ? addDaysForDashboardTotals_(baseDate, 30) : null;
    if (isDashboardExpiryAlert_(expiryDate)) {
      expiringPatientKeys[key || String((manifest && (manifest.driveFileId || manifest.id)) || '')] = true;
    }
  });

  return {
    recipeCount: recipeCount,
    dpcCount: dpcCount,
    expiringCount: Object.keys(expiringPatientKeys).length,
    source: source || 'runtime_index'
  };
}

function isEmptyArchiveDashboardTotals_(totals) {
  if (!totals) return true;
  return Number(totals.recipeCount || 0) === 0 &&
    Number(totals.dpcCount || 0) === 0 &&
    Number(totals.expiringCount || 0) === 0;
}

function fetchArchiveDashboardTotalsFromFirestoreFallback_(cfg) {
  try {
    var imports = listFirestoreDocumentsByPath_(cfg, ['drive_pdf_imports'], { pageSize: 300 }).filter(function (item) {
      return isActiveVisibleImportForDashboardTotals_(item);
    }).map(function (item) {
      return normalizeImportAsDashboardManifest_(item);
    });
    var importPatientKeys = {};
    imports.forEach(function (item) {
      var key = buildDashboardTotalsPatientKey_(item);
      if (key) importPatientKeys[key] = true;
    });

    var legacy = listFirestoreDocumentsByPath_(cfg, ['prescriptions'], { pageSize: 300 }).filter(function (item) {
      var cf = normalizeCf_(item && item.patientFiscalCode);
      if (cf && importPatientKeys[cf]) return false;
      return isActiveVisibleLegacyPrescriptionForDashboardTotals_(item);
    }).map(function (item) {
      return normalizeLegacyPrescriptionAsDashboardManifest_(item);
    });

    return buildArchiveDashboardTotalsFromManifests_(imports.concat(legacy), 'firestore_fallback');
  } catch (e) {
    return null;
  }
}

function isActiveVisibleImportForDashboardTotals_(item) {
  if (!item) return false;
  if (item.pdfDeleted || item.deletePdfRequested) return false;
  var status = String(item.status || '').trim().toLowerCase();
  if (status === 'deleted_pdf' || status === 'deleted' || status === 'discarded_non_prescription') return false;
  return !!(normalizeCf_(item.patientFiscalCode || item.fiscalCode || item.patientCf || item.patientCF || item.cf || item.codiceFiscale || item.patient_fiscal_code) ||
    String(item.patientFullName || item.patientName || item.fullName || item.name || '').trim());
}

function isActiveVisibleLegacyPrescriptionForDashboardTotals_(item) {
  if (!item) return false;
  if (item.deleted || item.archived || item.pdfDeleted || item.deletePdfRequested) return false;
  return !!(normalizeCf_(item.patientFiscalCode || item.fiscalCode || item.patientCf || item.cf) ||
    String(item.patientFullName || item.patientName || item.fullName || item.name || '').trim());
}

function normalizeImportAsDashboardManifest_(item) {
  return {
    id: item.id || item.documentId || item.driveFileId || item.fileId || '',
    driveFileId: item.driveFileId || item.fileId || item.id || item.documentId || '',
    patientFiscalCode: normalizeCf_(item.patientFiscalCode || item.fiscalCode || item.patientCf || item.patientCF || item.cf || item.codiceFiscale || item.patient_fiscal_code),
    patientFullName: String(item.patientFullName || item.patientName || item.fullName || item.name || '').trim(),
    prescriptionCount: readDashboardTotalsPositiveInt_(item.prescriptionCount || item.sourceCount || item.recipeCount || item.count, 1),
    prescriptionKeys: item.prescriptionKeys || item.recipeKeys || [],
    isDpc: readDashboardTotalsBool_(item.isDpc || item.dpc || item.dpcFlag || item.mergeHasDpc),
    prescriptionDate: item.prescriptionDate || item.date || item.recipeDate || null,
    createdAt: item.createdAt || item.importedAt || item.updatedAt || null
  };
}

function normalizeLegacyPrescriptionAsDashboardManifest_(item) {
  return {
    id: item.id || item.documentId || '',
    driveFileId: item.driveFileId || item.fileId || item.id || item.documentId || '',
    patientFiscalCode: normalizeCf_(item.patientFiscalCode || item.fiscalCode || item.patientCf || item.cf),
    patientFullName: String(item.patientFullName || item.patientName || item.fullName || item.name || '').trim(),
    prescriptionCount: readDashboardTotalsPositiveInt_(item.prescriptionCount || item.recipeCount || item.count, 1),
    prescriptionKeys: item.prescriptionKeys || item.recipeKeys || [],
    isDpc: readDashboardTotalsBool_(item.dpcFlag || item.isDpc || item.dpc),
    prescriptionDate: item.prescriptionDate || item.date || item.recipeDate || null,
    createdAt: item.createdAt || item.importedAt || item.updatedAt || null
  };
}

function readDashboardTotalsPositiveInt_(value, fallback) {
  var n = Number(value);
  if (isNaN(n) || n <= 0) return fallback;
  return Math.floor(n);
}

function readDashboardTotalsBool_(value) {
  if (value === true) return true;
  var text = String(value || '').trim().toLowerCase();
  return text === 'true' || text === '1' || text === 'si' || text === 'sì' || text === 'yes';
}

function buildDashboardTotalsPatientKey_(manifest) {
  var cf = normalizeCf_(manifest && manifest.patientFiscalCode);
  if (cf) return cf;
  return String((manifest && manifest.patientFullName) || '').trim().toUpperCase();
}


function parseDashboardTotalsDate_(value) {
  var parsed = parseDateValue_(value);
  if (parsed) return parsed;
  if (!value) return null;
  if (Object.prototype.toString.call(value) === '[object Date]' && !isNaN(value.getTime())) return value;
  var text = String(value || '').trim();
  if (!text) return null;
  var direct = new Date(text);
  return isNaN(direct.getTime()) ? null : direct;
}

function addDaysForDashboardTotals_(date, days) {
  var out = new Date(date.getTime());
  out.setDate(out.getDate() + Number(days || 0));
  return out;
}

function isDashboardExpiryAlert_(expiryDate) {
  if (!expiryDate) return false;
  var now = new Date();
  var today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  var expiry = new Date(expiryDate.getFullYear(), expiryDate.getMonth(), expiryDate.getDate());
  var diffDays = Math.floor((expiry.getTime() - today.getTime()) / 86400000);
  return diffDays <= 7;
}

function fetchAppManagedDashboardTotals_(cfg) {
  try {
    var diagnostics = [];
    var debtResult = fetchDashboardDebtAmount_(cfg);
    var advanceResult = fetchDashboardCollectionCount_(cfg, 'advances', 'advanceCount');
    var bookingResult = fetchDashboardCollectionCount_(cfg, 'bookings', 'bookingCount');

    [debtResult, advanceResult, bookingResult].forEach(function (item) {
      if (item && item.error) diagnostics.push(item.error);
    });

    return {
      ok: true,
      data: {
        debtAmount: roundDashboardTotalsAmount_(debtResult.value),
        advanceCount: Math.round(Number(advanceResult.value || 0)),
        bookingCount: Math.round(Number(bookingResult.value || 0))
      },
      source: [
        'debts:' + debtResult.source,
        'advances:' + advanceResult.source,
        'bookings:' + bookingResult.source
      ].join('|'),
      error: diagnostics.join(' | ')
    };
  } catch (e) {
    return {
      ok: false,
      data: null,
      source: 'previous_data',
      error: normalizeRuntimeErrorMessage_(e)
    };
  }
}

function fetchDashboardDebtAmount_(cfg) {
  if (!cfg || cfg.dashboardTotalsUseDebtAggregation !== true) {
    return buildDashboardDebtAmountByNoIndexScan_(cfg, 'scan_no_index');
  }

  try {
    return {
      value: runFirestoreAggregationNumber_(cfg, 'debts', {
        sum: { field: { fieldPath: 'residualAmount' } },
        alias: 'debtAmount'
      }),
      source: 'aggregation',
      error: ''
    };
  } catch (e) {
    var fallback = buildDashboardDebtAmountByNoIndexScan_(cfg, 'scan_fallback');
    fallback.error = 'debts aggregation fallback: ' + shortenDashboardTotalsError_(e);
    return fallback;
  }
}

function buildDashboardDebtAmountByNoIndexScan_(cfg, source) {
  var docs = listDashboardCollectionGroupDocumentsNoIndex_(cfg, 'debts');
  var sum = docs.reduce(function (total, item) {
    return total + readDashboardTotalsNumber_(item && item.residualAmount);
  }, 0);
  return {
    value: sum,
    source: source || 'scan_no_index',
    error: ''
  };
}


function fetchDashboardCollectionCount_(cfg, collectionId, alias) {
  try {
    return {
      value: runFirestoreAggregationNumber_(cfg, collectionId, {
        count: {},
        alias: alias || 'value'
      }),
      source: 'aggregation',
      error: ''
    };
  } catch (e) {
    var docs = listDashboardCollectionGroupDocumentsNoIndex_(cfg, collectionId);
    return {
      value: docs.length,
      source: 'scan_fallback',
      error: collectionId + ' aggregation fallback: ' + shortenDashboardTotalsError_(e)
    };
  }
}

function listDashboardCollectionGroupDocumentsNoIndex_(cfg, collectionId) {
  var url = 'https://firestore.googleapis.com/v1/projects/' + encodeURIComponent(cfg.firestoreProjectId) + '/databases/(default)/documents:runQuery';
  var payload = {
    structuredQuery: {
      from: [{
        collectionId: String(collectionId || '').trim(),
        allDescendants: true
      }]
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
    throw new Error('Firestore scan fallback ' + collectionId + ' failed [' + code + '] ' + body);
  }

  var rows = parseJsonSafe_(body);
  if (!Array.isArray(rows)) return [];

  return rows.map(function (row) {
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

function shortenDashboardTotalsError_(error) {
  var text = normalizeRuntimeErrorMessage_(error);
  if (!text) return '';
  text = text.replace(/https:\/\/console\.firebase\.google\.com\/[^\s"]+/g, '[firebase-index-link]');
  return text.length > 280 ? text.slice(0, 277) + '...' : text;
}


function buildAppManagedTotalsFromPrevious_(previousData) {
  previousData = previousData || {};
  return {
    debtAmount: readDashboardTotalsNumber_(previousData.debtAmount),
    advanceCount: Math.round(readDashboardTotalsNumber_(previousData.advanceCount)),
    bookingCount: Math.round(readDashboardTotalsNumber_(previousData.bookingCount))
  };
}

function readDashboardTotalsNumber_(value) {
  if (value === null || value === undefined || value === '') return 0;
  var n = Number(value);
  return isNaN(n) ? 0 : n;
}

function getPreviousDashboardTotalsData_(runtimeIndex) {
  var data = runtimeIndex && runtimeIndex.publishState ? runtimeIndex.publishState.dashboardTotalsData : null;
  if (!data || typeof data !== 'object' || Array.isArray(data)) return null;
  return data;
}

function buildDashboardTotalsHashPayload_(archiveTotals, appTotals, cfg) {
  return {
    schemaVersion: 1,
    parserVersion: Number((cfg && cfg.parserVersion) || 1),
    recipeCount: Math.max(0, Number((archiveTotals && archiveTotals.recipeCount) || 0)),
    dpcCount: Math.max(0, Number((archiveTotals && archiveTotals.dpcCount) || 0)),
    debtAmount: roundDashboardTotalsAmount_((appTotals && appTotals.debtAmount) || 0),
    advanceCount: Math.max(0, Number((appTotals && appTotals.advanceCount) || 0)),
    bookingCount: Math.max(0, Number((appTotals && appTotals.bookingCount) || 0)),
    expiringCount: Math.max(0, Number((archiveTotals && archiveTotals.expiringCount) || 0))
  };
}

function roundDashboardTotalsAmount_(value) {
  var n = Number(value || 0);
  if (isNaN(n)) return 0;
  return Math.round(n * 100) / 100;
}

function runFirestoreAggregationNumber_(cfg, collectionId, aggregation) {
  var url = 'https://firestore.googleapis.com/v1/projects/' + encodeURIComponent(cfg.firestoreProjectId) + '/databases/(default)/documents:runAggregationQuery';
  var alias = String((aggregation && aggregation.alias) || 'value');
  var payload = {
    structuredAggregationQuery: {
      structuredQuery: {
        from: [{
          collectionId: String(collectionId || '').trim(),
          allDescendants: true
        }]
      },
      aggregations: [aggregation]
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
    throw new Error('Firestore aggregation ' + collectionId + ' failed [' + code + '] ' + body);
  }

  var rows = parseJsonSafe_(body);
  if (!Array.isArray(rows) || !rows.length) return 0;

  for (var i = 0; i < rows.length; i++) {
    var aggregateFields = rows[i] && rows[i].result && rows[i].result.aggregateFields;
    if (!aggregateFields) continue;
    if (Object.prototype.hasOwnProperty.call(aggregateFields, alias)) {
      return readFirestoreAggregationValue_(aggregateFields[alias]);
    }
  }
  return 0;
}

function readFirestoreAggregationValue_(value) {
  if (!value || typeof value !== 'object') return 0;
  if (Object.prototype.hasOwnProperty.call(value, 'integerValue')) return Number(value.integerValue || 0);
  if (Object.prototype.hasOwnProperty.call(value, 'doubleValue')) return Number(value.doubleValue || 0);
  return 0;
}

function refreshPhboxDashboardTotals() {
  var lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    var cfg = getPhboxConfig_();
    assertBackendReadyForRun_({ includeDriveOcrProbe: false, includeFirestoreProbe: false, skipGmail: true });
    var rootFolder = DriveApp.getFolderById(cfg.folderId);
    var runtimeIndex = readRuntimeIndex_(rootFolder, cfg);
    var candidate = buildDashboardTotalsWriteCandidate_(runtimeIndex, cfg);
    if (candidate.error) {
      throw new Error('refreshPhboxDashboardTotals fallita: ' + candidate.error);
    }
    if (candidate.write) {
      executeFirestoreCommit_(cfg, [candidate.write]);
      runtimeIndex.publishState.dashboardTotals = candidate.hash;
      runtimeIndex.publishState.dashboardTotalsData = candidate.data || null;
      writeRuntimeIndex_(rootFolder, cfg, runtimeIndex);
      return { ok: true, written: true, dashboardTotals: candidate.data };
    }
    return { ok: true, written: false, dashboardTotals: candidate.data || getPreviousDashboardTotalsData_(runtimeIndex) };
  } finally {
    lock.releaseLock();
  }
}
