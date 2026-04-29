function exportPhboxMetadataOnlyV1(options) {
  options = options || {};
  var cfg = getPhboxConfig_();
  var context = buildPhboxExportContext_(cfg, options);

  assertBackendReadyForRun_({
    includeFirestoreProbe: true,
    skipDriveOcrProbe: true,
    skipGmail: true
  });

  var tracking = buildDataExportTrackingSkeleton_(context);
  writeDataExportTrackingRecord_(cfg, tracking);

  try {
    var datasets = collectPhboxMetadataOnlyExportDatasets_(cfg, context, options);
    var entityCounts = buildPhboxExportEntityCounts_(datasets);
    var dataFiles = buildPhboxMetadataOnlyDataFiles_(datasets);
    var checksumSummary = buildPhboxExportChecksumSummary_(dataFiles);
    var manifest = buildPhboxMetadataOnlyManifest_(context, entityCounts, checksumSummary);
    var allFiles = [{
      fileName: 'manifest.json',
      content: canonicalJsonStringify_(manifest)
    }].concat(dataFiles);
    var savedZip = savePhboxExportZip_(context.exportFolder, context, allFiles);

    tracking.endedAt = new Date().toISOString();
    tracking.result = 'success';
    tracking.entityCounts = entityCounts;
    tracking.checksumSummary = checksumSummary;
    tracking.fileId = savedZip.fileId;
    tracking.fileName = savedZip.fileName;
    tracking.exportFolderId = context.exportFolder.getId();
    tracking.exportedAt = context.exportedAt;
    tracking.errorSummary = '';
    writeDataExportTrackingRecord_(cfg, tracking);

    logInfo_(cfg, 'Export metadata-only completato', {
      operationId: context.operationId,
      packageId: context.packageId,
      fileId: savedZip.fileId,
      entityCounts: entityCounts
    });

    return {
      operationId: context.operationId,
      packageId: context.packageId,
      exportMode: 'metadata_only',
      formatVersion: context.formatVersion,
      fileId: savedZip.fileId,
      fileName: savedZip.fileName,
      exportFolderId: context.exportFolder.getId(),
      entityCounts: entityCounts,
      checksumSummary: checksumSummary,
      exportedAt: context.exportedAt
    };
  } catch (e) {
    tracking.endedAt = new Date().toISOString();
    tracking.result = 'error';
    tracking.errorSummary = normalizeRuntimeErrorMessage_(e);
    try {
      writeDataExportTrackingRecord_(cfg, tracking);
    } catch (_) {}
    throw e;
  }
}

function buildPhboxExportContext_(cfg, options) {
  var props = PropertiesService.getScriptProperties();
  var rootFolder = DriveApp.getFolderById(cfg.folderId);
  var exportFolderName = String(props.getProperty('PHBOX_EXPORTS_FOLDER') || '_phbox_exports').trim() || '_phbox_exports';
  var exportFolder = getOrCreateChildFolder_(rootFolder, exportFolderName);
  var exportedAt = new Date().toISOString();
  var appVersion = String(options.appVersion || props.getProperty('PHBOX_APP_VERSION') || 'v1.1.2').trim() || 'v1.1.2';
  var pharmacyId = String(options.pharmacyId || props.getProperty('PHBOX_PHARMACY_ID') || cfg.folderId).trim() || String(cfg.folderId || '').trim();
  var actorId = resolvePhboxActorId_(options);
  var actorType = actorId && actorId !== 'script' ? 'user' : 'script';
  var packageId = buildPhboxExportPackageId_(pharmacyId, exportedAt, options.packageId);
  var operationId = String(options.operationId || Utilities.getUuid()).trim() || Utilities.getUuid();
  return {
    appVersion: appVersion,
    pharmacyId: pharmacyId,
    exportedAt: exportedAt,
    exportedBy: actorId,
    actorType: actorType,
    actorId: actorId,
    packageId: packageId,
    operationId: operationId,
    exportFolder: exportFolder,
    formatVersion: 'phbox_export_v1',
    exportMode: 'metadata_only'
  };
}

function resolvePhboxActorId_(options) {
  var explicit = String((options && options.exportedBy) || '').trim();
  if (explicit) return explicit;
  try {
    var active = Session.getActiveUser().getEmail();
    if (active) return String(active).trim();
  } catch (_) {}
  try {
    var effective = Session.getEffectiveUser().getEmail();
    if (effective) return String(effective).trim();
  } catch (_) {}
  return 'script';
}

function buildPhboxExportPackageId_(pharmacyId, exportedAt, explicitPackageId) {
  var provided = String(explicitPackageId || '').trim();
  if (provided) return provided;
  var compactTs = String(exportedAt || '')
    .replace(/[-:]/g, '')
    .replace(/\.\d+Z$/, 'Z')
    .replace(/[^0-9TZ]/g, '');
  var safePharmacy = sanitizePhboxExportToken_(pharmacyId || 'pharmacy');
  return 'pkg_' + safePharmacy + '_' + compactTs + '_' + Utilities.getUuid().replace(/-/g, '').slice(0, 12);
}

function sanitizePhboxExportToken_(value) {
  return String(value || '')
    .trim()
    .replace(/[^A-Za-z0-9._-]+/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 80) || 'value';
}

function buildDataExportTrackingSkeleton_(context) {
  return {
    operationId: context.operationId,
    packageId: context.packageId,
    pharmacyId: context.pharmacyId,
    mode: context.exportMode,
    formatVersion: context.formatVersion,
    actorType: context.actorType,
    actorId: context.actorId,
    startedAt: context.exportedAt,
    endedAt: null,
    result: 'running',
    entityCounts: {},
    checksumSummary: {},
    errorSummary: '',
    fileId: '',
    fileName: ''
  };
}

function writeDataExportTrackingRecord_(cfg, tracking) {
  upsertFirestoreDocument_(cfg, 'data_exports', String(tracking.operationId || '').trim(), tracking);
}

function collectPhboxMetadataOnlyExportDatasets_(cfg, context, options) {
  var patients = listFirestoreDocumentsByPath_(cfg, ['patients'], options).map(function (doc) {
    return enrichPatientExportRecord_(doc, context.pharmacyId);
  });

  var drivePdfImports = listFirestoreDocumentsByPath_(cfg, ['drive_pdf_imports'], options).map(function (doc) {
    return enrichDrivePdfImportExportRecord_(doc, context.pharmacyId);
  });

  var doctorLinks = listFirestoreDocumentsByPath_(cfg, ['doctor_patient_links'], options).map(function (doc) {
    return enrichDoctorPatientLinkExportRecord_(doc, context.pharmacyId);
  });

  var families = listFirestoreDocumentsByPath_(cfg, ['families'], options).map(function (doc) {
    return enrichFamilyExportRecord_(doc, context.pharmacyId);
  });

  var therapeuticAdvice = listFirestoreDocumentsByPath_(cfg, ['patient_therapeutic_advice'], options).map(function (doc) {
    return enrichTherapeuticAdviceExportRecord_(doc, context.pharmacyId);
  });

  var debts = listFirestoreCollectionGroupDocuments_(cfg, 'debts', options).map(function (doc) {
    return enrichDebtExportRecord_(doc, context.pharmacyId);
  });

  var advances = listFirestoreCollectionGroupDocuments_(cfg, 'advances', options).map(function (doc) {
    return enrichAdvanceExportRecord_(doc, context.pharmacyId);
  });

  var bookings = listFirestoreCollectionGroupDocuments_(cfg, 'bookings', options).map(function (doc) {
    return enrichBookingExportRecord_(doc, context.pharmacyId);
  });

  var settingsDoc = getFirestoreDocumentByPath_(cfg, ['app_settings', 'main']);
  var settingsFrontend = settingsDoc ? enrichSettingsFrontendExportRecord_(settingsDoc, context.pharmacyId) : null;

  return {
    patients: sortExportRecords_(patients, ['fiscalCode', 'fullName']),
    drive_pdf_imports: sortExportRecords_(drivePdfImports, ['importId', 'patientFiscalCode', 'fileId']),
    doctor_patient_links: sortExportRecords_(doctorLinks, ['linkId', 'patientFiscalCode']),
    families: sortExportRecords_(families, ['familyId', 'name']),
    debts: sortExportRecords_(debts, ['patientFiscalCode', 'debtId']),
    advances: sortExportRecords_(advances, ['patientFiscalCode', 'advanceId']),
    bookings: sortExportRecords_(bookings, ['patientFiscalCode', 'bookingId']),
    therapeutic_advice: sortExportRecords_(therapeuticAdvice, ['patientFiscalCode', 'adviceId']),
    settings_frontend: settingsFrontend
  };
}

function listFirestoreDocumentsByPath_(cfg, pathSegments, options) {
  options = options || {};
  var pageSize = Math.max(1, Math.min(500, Number(options.pageSize || 200)));
  var out = [];
  var pageToken = '';

  do {
    var url = buildFirestoreDocumentsListUrl_(cfg, pathSegments, {
      pageSize: pageSize,
      pageToken: pageToken,
      orderBy: '__name__'
    });
    var payload = fetchFirestoreJsonWithRetry_(url, { method: 'get' });
    var documents = (payload && payload.documents) || [];
    documents.forEach(function (document) {
      out.push(mapFirestoreDocumentToPlainObject_(document));
    });
    pageToken = String((payload && payload.nextPageToken) || '').trim();
  } while (pageToken);

  return out;
}

function listFirestoreCollectionGroupDocuments_(cfg, collectionId, options) {
  options = options || {};
  var url = 'https://firestore.googleapis.com/v1/projects/' + encodeURIComponent(cfg.firestoreProjectId) + '/databases/(default)/documents:runQuery';
  var payload = {
    structuredQuery: {
      from: [{
        collectionId: String(collectionId || '').trim(),
        allDescendants: true
      }],
      orderBy: [{
        field: { fieldPath: '__name__' },
        direction: 'ASCENDING'
      }]
    }
  };
  var rows = fetchFirestoreJsonWithRetry_(url, {
    method: 'post',
    payload: JSON.stringify(payload),
    contentType: 'application/json'
  });
  if (!Array.isArray(rows)) return [];
  return rows.map(function (row) {
    return row && row.document ? mapFirestoreDocumentToPlainObject_(row.document) : null;
  }).filter(function (item) {
    return !!item;
  });
}

function getFirestoreDocumentByPath_(cfg, pathSegments) {
  var url = buildFirestoreDocumentPathUrl_(cfg, pathSegments);
  var payload = fetchFirestoreJsonWithRetry_(url, {
    method: 'get',
    allow404: true
  });
  if (!payload) return null;
  return mapFirestoreDocumentToPlainObject_(payload);
}

function buildFirestoreDocumentsListUrl_(cfg, pathSegments, options) {
  options = options || {};
  var base = buildFirestoreDocumentPathUrl_(cfg, pathSegments);
  var params = [];
  if (options.pageSize) params.push('pageSize=' + encodeURIComponent(String(options.pageSize)));
  if (options.pageToken) params.push('pageToken=' + encodeURIComponent(String(options.pageToken)));
  if (options.orderBy) params.push('orderBy=' + encodeURIComponent(String(options.orderBy)));
  return params.length ? (base + '?' + params.join('&')) : base;
}

function buildFirestoreDocumentPathUrl_(cfg, pathSegments) {
  var path = (pathSegments || []).map(function (segment) {
    return encodeURIComponent(String(segment || '').trim());
  }).join('/');
  return 'https://firestore.googleapis.com/v1/projects/' + encodeURIComponent(cfg.firestoreProjectId) + '/databases/(default)/documents/' + path;
}

function fetchFirestoreJsonWithRetry_(url, options) {
  options = options || {};
  return runWithRetryOnTransient_(function () {
    var request = {
      method: options.method || 'get',
      muteHttpExceptions: true,
      headers: {
        Authorization: 'Bearer ' + ScriptApp.getOAuthToken()
      }
    };
    if (options.contentType) request.contentType = options.contentType;
    if (options.payload !== undefined) request.payload = options.payload;
    var response = UrlFetchApp.fetch(url, request);
    var code = response.getResponseCode();
    var body = response.getContentText() || '';
    if (code === 404 && options.allow404) return null;
    if (code < 200 || code >= 300) {
      throw new Error('Firestore export request failed [' + code + '] ' + body);
    }
    if (!body) return null;
    var parsed = parseJsonSafe_(body);
    if (parsed === null && String(body).trim()) {
      throw new Error('Firestore export payload non JSON valido da ' + url);
    }
    return parsed;
  }, {
    attempts: 3,
    baseSleepMs: 500
  });
}

function mapFirestoreDocumentToPlainObject_(document) {
  var data = fromFirestoreFields_((document && document.fields) || {});
  var name = String((document && document.name) || '').trim();
  var parts = name ? name.split('/') : [];
  var documentId = parts.length ? parts[parts.length - 1] : '';
  var collectionId = parts.length >= 2 ? parts[parts.length - 2] : '';
  var parentDocumentId = parts.length >= 4 ? parts[parts.length - 3] : '';
  data.documentId = documentId;
  data.documentPath = name;
  data.collectionId = collectionId;
  data.parentDocumentId = parentDocumentId;
  return data;
}

function enrichPatientExportRecord_(doc, pharmacyId) {
  var out = cloneExportRecord_(doc);
  out.fiscalCode = normalizeCf_(out.fiscalCode || out.documentId);
  out.pharmacyId = choosePreferredValue_([out.pharmacyId, pharmacyId]) || pharmacyId;
  delete out.documentId;
  delete out.documentPath;
  delete out.collectionId;
  delete out.parentDocumentId;
  return out;
}

function enrichDrivePdfImportExportRecord_(doc, pharmacyId) {
  var out = cloneExportRecord_(doc);
  var importId = String(out.importId || out.documentId || out.fileId || out.driveFileId || '').trim();
  out.importId = importId;
  out.fileId = choosePreferredValue_([out.fileId, out.driveFileId, importId]);
  out.driveFileId = choosePreferredValue_([out.driveFileId, out.fileId, importId]);
  out.patientFiscalCode = normalizeCf_(out.patientFiscalCode);
  out.pharmacyId = choosePreferredValue_([out.pharmacyId, pharmacyId]) || pharmacyId;
  out.kind = String(out.kind || '').trim();
  out.status = String(out.status || '').trim();
  out.pdfDeleted = !!out.pdfDeleted;
  out.prescriptionNres = uniqueNonEmptyStrings_(out.prescriptionNres || []);
  out.prescriptionCount = Number(out.prescriptionCount || 0);
  out.componentFileIds = uniqueNonEmptyStrings_(out.componentFileIds || []);
  out.canonicalFileId = String(out.canonicalFileId || '').trim();
  out.webViewLink = String(out.webViewLink || '').trim();
  out.openUrl = String(out.openUrl || '').trim();
  out.hasDpc = !!out.hasDpc;
  out.isDpc = !!out.isDpc;
  delete out.documentId;
  delete out.documentPath;
  delete out.collectionId;
  delete out.parentDocumentId;
  return out;
}

function enrichDoctorPatientLinkExportRecord_(doc, pharmacyId) {
  var out = cloneExportRecord_(doc);
  out.linkId = String(out.linkId || out.id || out.documentId || '').trim();
  out.patientFiscalCode = normalizeCf_(out.patientFiscalCode || out.fiscalCode || out.parentDocumentId);
  out.pharmacyId = choosePreferredValue_([out.pharmacyId, pharmacyId]) || pharmacyId;
  delete out.documentId;
  delete out.documentPath;
  delete out.collectionId;
  delete out.parentDocumentId;
  return out;
}

function enrichFamilyExportRecord_(doc, pharmacyId) {
  var out = cloneExportRecord_(doc);
  out.familyId = String(out.familyId || out.id || out.documentId || '').trim();
  out.pharmacyId = choosePreferredValue_([out.pharmacyId, pharmacyId]) || pharmacyId;
  delete out.documentId;
  delete out.documentPath;
  delete out.collectionId;
  delete out.parentDocumentId;
  return out;
}

function enrichDebtExportRecord_(doc, pharmacyId) {
  var out = cloneExportRecord_(doc);
  out.debtId = String(out.debtId || out.id || out.documentId || '').trim();
  out.patientFiscalCode = normalizeCf_(out.patientFiscalCode || out.parentDocumentId);
  out.pharmacyId = choosePreferredValue_([out.pharmacyId, pharmacyId]) || pharmacyId;
  delete out.documentId;
  delete out.documentPath;
  delete out.collectionId;
  delete out.parentDocumentId;
  return out;
}

function enrichAdvanceExportRecord_(doc, pharmacyId) {
  var out = cloneExportRecord_(doc);
  out.advanceId = String(out.advanceId || out.id || out.documentId || '').trim();
  out.patientFiscalCode = normalizeCf_(out.patientFiscalCode || out.parentDocumentId);
  out.pharmacyId = choosePreferredValue_([out.pharmacyId, pharmacyId]) || pharmacyId;
  delete out.documentId;
  delete out.documentPath;
  delete out.collectionId;
  delete out.parentDocumentId;
  return out;
}

function enrichBookingExportRecord_(doc, pharmacyId) {
  var out = cloneExportRecord_(doc);
  out.bookingId = String(out.bookingId || out.id || out.documentId || '').trim();
  out.patientFiscalCode = normalizeCf_(out.patientFiscalCode || out.parentDocumentId);
  out.pharmacyId = choosePreferredValue_([out.pharmacyId, pharmacyId]) || pharmacyId;
  delete out.documentId;
  delete out.documentPath;
  delete out.collectionId;
  delete out.parentDocumentId;
  return out;
}

function enrichTherapeuticAdviceExportRecord_(doc, pharmacyId) {
  var out = cloneExportRecord_(doc);
  out.adviceId = String(out.adviceId || out.documentId || out.patientFiscalCode || '').trim();
  out.patientFiscalCode = normalizeCf_(out.patientFiscalCode || out.documentId);
  out.pharmacyId = choosePreferredValue_([out.pharmacyId, pharmacyId]) || pharmacyId;
  delete out.documentId;
  delete out.documentPath;
  delete out.collectionId;
  delete out.parentDocumentId;
  return out;
}

function enrichSettingsFrontendExportRecord_(doc, pharmacyId) {
  var out = cloneExportRecord_(doc);
  out.documentId = String(out.documentId || 'main').trim() || 'main';
  out.pharmacyId = choosePreferredValue_([out.pharmacyId, pharmacyId]) || pharmacyId;
  delete out.documentPath;
  delete out.collectionId;
  delete out.parentDocumentId;
  return out;
}

function cloneExportRecord_(record) {
  return JSON.parse(JSON.stringify(record || {}));
}

function sortExportRecords_(records, keys) {
  return (records || []).slice().sort(function (a, b) {
    for (var i = 0; i < (keys || []).length; i++) {
      var key = keys[i];
      var av = normalizeSortValue_(a && a[key]);
      var bv = normalizeSortValue_(b && b[key]);
      if (av < bv) return -1;
      if (av > bv) return 1;
    }
    return canonicalJsonStringify_(a).localeCompare(canonicalJsonStringify_(b));
  });
}

function normalizeSortValue_(value) {
  if (value === null || value === undefined) return '';
  if (typeof value === 'number') return String(value).padStart(20, '0');
  if (typeof value === 'boolean') return value ? '1' : '0';
  return String(value).trim().toUpperCase();
}

function buildPhboxExportEntityCounts_(datasets) {
  return {
    patients: (datasets.patients || []).length,
    drive_pdf_imports: (datasets.drive_pdf_imports || []).length,
    doctor_patient_links: (datasets.doctor_patient_links || []).length,
    families: (datasets.families || []).length,
    debts: (datasets.debts || []).length,
    advances: (datasets.advances || []).length,
    bookings: (datasets.bookings || []).length,
    therapeutic_advice: (datasets.therapeutic_advice || []).length,
    settings_frontend: datasets.settings_frontend ? 1 : 0
  };
}

function buildPhboxMetadataOnlyDataFiles_(datasets) {
  return [
    { fileName: 'patients.json', content: canonicalJsonStringify_(datasets.patients || []) },
    { fileName: 'drive_pdf_imports.json', content: canonicalJsonStringify_(datasets.drive_pdf_imports || []) },
    { fileName: 'doctor_patient_links.json', content: canonicalJsonStringify_(datasets.doctor_patient_links || []) },
    { fileName: 'families.json', content: canonicalJsonStringify_(datasets.families || []) },
    { fileName: 'debts.json', content: canonicalJsonStringify_(datasets.debts || []) },
    { fileName: 'advances.json', content: canonicalJsonStringify_(datasets.advances || []) },
    { fileName: 'bookings.json', content: canonicalJsonStringify_(datasets.bookings || []) },
    { fileName: 'therapeutic_advice.json', content: canonicalJsonStringify_(datasets.therapeutic_advice || []) },
    { fileName: 'settings_frontend.json', content: canonicalJsonStringify_(datasets.settings_frontend) }
  ];
}

function buildPhboxExportChecksumSummary_(files) {
  var fileChecksums = {};
  (files || []).forEach(function (file) {
    fileChecksums[file.fileName] = computeSha256Hex_(file.content || '');
  });
  var aggregateInput = Object.keys(fileChecksums).sort().map(function (fileName) {
    return fileName + ':' + fileChecksums[fileName];
  }).join('\n');
  return {
    algorithm: 'SHA-256',
    files: fileChecksums,
    payloadChecksum: computeSha256Hex_(aggregateInput)
  };
}

function buildPhboxMetadataOnlyManifest_(context, entityCounts, checksumSummary) {
  return {
    formatVersion: context.formatVersion,
    exportedAt: context.exportedAt,
    appVersion: context.appVersion,
    pharmacyId: context.pharmacyId,
    exportMode: context.exportMode,
    includesFiles: false,
    includesLogs: false,
    entityCounts: entityCounts,
    exportedBy: context.exportedBy,
    packageId: context.packageId,
    checksumSummary: checksumSummary
  };
}

function savePhboxExportZip_(folder, context, files) {
  var safePharmacy = sanitizePhboxExportToken_(context.pharmacyId || 'pharmacy');
  var compactTs = String(context.exportedAt || '')
    .replace(/[-:]/g, '')
    .replace(/\.\d+Z$/, 'Z')
    .replace(/[^0-9TZ]/g, '');
  var zipName = 'phbox_export_metadata_only_' + safePharmacy + '_' + compactTs + '.zip';
  var blobs = (files || []).map(function (file) {
    return Utilities.newBlob(String(file.content || ''), MimeType.PLAIN_TEXT, String(file.fileName || 'payload.json'));
  });
  var zipBlob = Utilities.zip(blobs, zipName);
  var created = runWithRetryOnTransient_(function () {
    return folder.createFile(zipBlob);
  }, {
    attempts: 3,
    baseSleepMs: 400
  });
  return {
    fileId: created.getId(),
    fileName: created.getName()
  };
}

function canonicalJsonStringify_(value) {
  return JSON.stringify(canonicalizeExportValue_(value), null, 2);
}

function canonicalizeExportValue_(value) {
  if (Array.isArray(value)) {
    return value.map(function (item) {
      return canonicalizeExportValue_(item);
    });
  }
  if (value && typeof value === 'object' && Object.prototype.toString.call(value) !== '[object Date]') {
    var out = {};
    Object.keys(value).sort().forEach(function (key) {
      out[key] = canonicalizeExportValue_(value[key]);
    });
    return out;
  }
  if (Object.prototype.toString.call(value) === '[object Date]') return value.toISOString();
  return value === undefined ? null : value;
}

function computeSha256Hex_(text) {
  var digest = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, String(text || ''), Utilities.Charset.UTF_8);
  return digest.map(function (byte) {
    var value = byte;
    if (value < 0) value += 256;
    return ('0' + value.toString(16)).slice(-2);
  }).join('');
}
