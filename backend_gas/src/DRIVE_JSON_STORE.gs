function getOrCreateChildFolder_(parentFolder, folderName) {
  var folders = parentFolder.getFoldersByName(folderName);
  if (folders.hasNext()) return folders.next();
  return runWithRetryOnTransient_(function () {
    return parentFolder.createFolder(folderName);
  }, {
    attempts: 3,
    baseSleepMs: 400
  });
}

function readJsonFileInFolderByName_(folder, fileName) {
  return runWithRetryOnTransient_(function () {
    var file = getFirstFileByNameOrNull_(folder, fileName);
    if (!file) return null;
    return parseJsonSafe_(file.getBlob().getDataAsString());
  }, {
    attempts: 3,
    baseSleepMs: 400
  });
}

function writeJsonFileInFolder_(folder, fileName, data) {
  var content = JSON.stringify(data, null, 2);
  runWithRetryOnTransient_(function () {
    var file = getFirstFileByNameOrNull_(folder, fileName);
    if (file) {
      file.setContent(content);
      return file.getId();
    }
    return createOrRecoverJsonFile_(folder, fileName, content).getId();
  }, {
    attempts: 3,
    baseSleepMs: 400
  });
}

function getFirstFileByNameOrNull_(folder, fileName) {
  var files = folder.getFilesByName(fileName);
  if (!files.hasNext()) return null;
  return files.next();
}

function createOrRecoverJsonFile_(folder, fileName, content) {
  try {
    return folder.createFile(fileName, content, MimeType.PLAIN_TEXT);
  } catch (e) {
    if (!isRetryableRuntimeFailure_(e)) {
      throw e;
    }
    var existing = getFirstFileByNameOrNull_(folder, fileName);
    if (existing) {
      existing.setContent(content);
      return existing;
    }
    throw e;
  }
}

function parseJsonSafe_(content) {
  try {
    return JSON.parse(content);
  } catch (_) {
    return null;
  }
}

function getRuntimeStateFolder_(rootFolder, cfg) {
  return getOrCreateChildFolder_(rootFolder, cfg.manifestsFolderName);
}

function readRuntimeIndex_(rootFolder, cfg) {
  cfg = cfg || getPhboxConfig_();
  var stateFolder = getRuntimeStateFolder_(rootFolder, cfg);
  var index = readJsonFileInFolderByName_(stateFolder, cfg.runtimeIndexFileName);
  if (!index) {
    index = migrateLegacyManifestsIntoRuntimeIndex_(stateFolder, cfg) || buildEmptyRuntimeIndex_(cfg);
    writeRuntimeIndex_(rootFolder, cfg, index);
  }
  return ensureRuntimeIndexShape_(index, cfg);
}

function writeRuntimeIndex_(rootFolder, cfg, index) {
  cfg = cfg || getPhboxConfig_();
  var stateFolder = getRuntimeStateFolder_(rootFolder, cfg);
  index = ensureRuntimeIndexShape_(index, cfg);
  index.updatedAt = new Date().toISOString();
  writeJsonFileInFolder_(stateFolder, cfg.runtimeIndexFileName, index);
}

function buildEmptyRuntimeIndex_(cfg) {
  var nowIso = new Date().toISOString();
  return {
    version: 2,
    parserVersion: Number((cfg && cfg.parserVersion) || 1),
    createdAt: nowIso,
    updatedAt: nowIso,
    filesById: {},
    threadsById: {},
    dirty: {
      imports: [],
      cfs: [],
      threads: []
    },
    publishState: {
      imports: {},
      patients: {},
      doctorLinks: {},
      dashboardTotals: '',
      dashboardTotalsData: null
    },
    meta: {
      legacyMigratedAt: null
    }
  };
}

function ensureRuntimeIndexShape_(index, cfg) {
  var out = index || buildEmptyRuntimeIndex_(cfg);
  if (!out.version) out.version = 2;
  if (!out.createdAt) out.createdAt = new Date().toISOString();
  if (!out.updatedAt) out.updatedAt = out.createdAt;
  if (!out.filesById || typeof out.filesById !== 'object' || Array.isArray(out.filesById)) out.filesById = {};
  if (!out.threadsById || typeof out.threadsById !== 'object' || Array.isArray(out.threadsById)) out.threadsById = {};
  if (!out.dirty || typeof out.dirty !== 'object') out.dirty = {};
  if (!Array.isArray(out.dirty.imports)) out.dirty.imports = [];
  if (!Array.isArray(out.dirty.cfs)) out.dirty.cfs = [];
  if (!Array.isArray(out.dirty.threads)) out.dirty.threads = [];
  if (!out.publishState || typeof out.publishState !== 'object') out.publishState = {};
  if (!out.publishState.imports || typeof out.publishState.imports !== 'object') out.publishState.imports = {};
  if (!out.publishState.patients || typeof out.publishState.patients !== 'object') out.publishState.patients = {};
  if (!out.publishState.doctorLinks || typeof out.publishState.doctorLinks !== 'object') out.publishState.doctorLinks = {};
  if (typeof out.publishState.dashboardTotals !== 'string') out.publishState.dashboardTotals = '';
  if (out.publishState.dashboardTotalsData !== null &&
      (!out.publishState.dashboardTotalsData || typeof out.publishState.dashboardTotalsData !== 'object' || Array.isArray(out.publishState.dashboardTotalsData))) {
    out.publishState.dashboardTotalsData = null;
  }
  if (!out.meta || typeof out.meta !== 'object') out.meta = {};
  if (!Object.prototype.hasOwnProperty.call(out.meta, 'legacyMigratedAt')) out.meta.legacyMigratedAt = null;
  Object.keys(out.filesById).forEach(function (key) {
    out.filesById[key] = ensureRuntimeManifestShape_(out.filesById[key], cfg);
  });
  Object.keys(out.threadsById).forEach(function (key) {
    out.threadsById[key] = ensureRuntimeThreadShape_(out.threadsById[key]);
  });
  out.dirty.imports = uniqueNonEmptyStrings_(out.dirty.imports);
  out.dirty.cfs = uniqueNonEmptyStrings_(out.dirty.cfs.map(function (item) { return normalizeCf_(item); }));
  out.dirty.threads = uniqueNonEmptyStrings_(out.dirty.threads);
  return out;
}

function ensureRuntimeManifestShape_(manifest, cfg) {
  manifest = manifest || {};
  var nowIso = new Date().toISOString();
  var driveFileId = String((manifest.driveFileId || manifest.id || '')).trim();
  var out = {
    version: Number(manifest.version || 1),
    parserVersion: Number(manifest.parserVersion || ((cfg && cfg.parserVersion) || 1)),
    id: driveFileId,
    driveFileId: driveFileId,
    fileName: String(manifest.fileName || '').trim(),
    mimeType: String(manifest.mimeType || MimeType.PDF),
    driveUpdatedAt: manifest.driveUpdatedAt || null,
    createdAt: manifest.createdAt || nowIso,
    updatedAt: manifest.updatedAt || nowIso,
    syncedAt: manifest.syncedAt || null,
    syncNeeded: !!manifest.syncNeeded,
    status: String(manifest.status || 'pending_analysis').trim(),
    kind: String(manifest.kind || 'raw_source').trim(),
    analysisOutcome: String(manifest.analysisOutcome || '').trim(),
    errorMessage: String(manifest.errorMessage || '').trim(),
    canonicalGroupKey: String(manifest.canonicalGroupKey || '').trim(),
    canonicalFileId: String(manifest.canonicalFileId || '').trim(),
    mergeSignature: String(manifest.mergeSignature || '').trim(),
    componentFileIds: Array.isArray(manifest.componentFileIds) ? uniqueNonEmptyStrings_(manifest.componentFileIds) : [],
    componentSourceKeys: Array.isArray(manifest.componentSourceKeys) ? uniqueNonEmptyStrings_(manifest.componentSourceKeys) : [],
    componentDuplicateFingerprintKeys: Array.isArray(manifest.componentDuplicateFingerprintKeys) ? uniqueNonEmptyStrings_(manifest.componentDuplicateFingerprintKeys) : [],
    representedSourceCount: Number(manifest.representedSourceCount || 0),
    supersededByCanonical: String(manifest.supersededByCanonical || '').trim(),
    mergedAt: manifest.mergedAt || null,
    patientFiscalCode: normalizeCf_(manifest.patientFiscalCode),
    patientFullName: String(manifest.patientFullName || '').trim(),
    doctorFullName: String(manifest.doctorFullName || '').trim(),
    exemptionCode: String(manifest.exemptionCode || manifest.exemption || '').trim(),
    exemptions: uniqueNonEmptyStrings_([].concat((manifest.exemptions || []), manifest.exemptionCode || '', manifest.exemption || '')),
    city: String(manifest.city || '').trim(),
    therapy: Array.isArray(manifest.therapy) ? uniqueNonEmptyStrings_(manifest.therapy) : [],
    isDpc: !!manifest.isDpc,
    prescriptionNres: Array.isArray(manifest.prescriptionNres) ? uniqueNonEmptyStrings_(manifest.prescriptionNres) : [],
    strongPrescriptionNres: Array.isArray(manifest.strongPrescriptionNres) ? uniqueNonEmptyStrings_(manifest.strongPrescriptionNres) : [],
    weakPrescriptionNres: Array.isArray(manifest.weakPrescriptionNres) ? uniqueNonEmptyStrings_(manifest.weakPrescriptionNres) : [],
    prescriptionTextFingerprint: String(manifest.prescriptionTextFingerprint || '').trim(),
    prescriptionIdentityKeys: Array.isArray(manifest.prescriptionIdentityKeys) ? uniqueNonEmptyStrings_(manifest.prescriptionIdentityKeys) : [],
    prescriptionCount: Math.max(1, Number(manifest.prescriptionCount || 1)),
    nreExtractionMode: String(manifest.nreExtractionMode || 'split_strong_weak_v1').trim(),
    pdfPageCount: Math.max(0, Number(manifest.pdfPageCount || 0)),
    ocrPageCount: Math.max(0, Number(manifest.ocrPageCount || 0)),
    binaryPdfPageCount: Math.max(0, Number(manifest.binaryPdfPageCount || 0)),
    prescriptionDate: manifest.prescriptionDate || null,
    filenameFiscalCode: String(manifest.filenameFiscalCode || '').trim(),
    filenamePrescriptionDate: manifest.filenamePrescriptionDate || null,
    filenameContentMismatch: !!manifest.filenameContentMismatch,
    parentFolderId: String(manifest.parentFolderId || '').trim(),
    parentFolderName: String(manifest.parentFolderName || '').trim(),
    webViewLink: String(manifest.webViewLink || '').trim(),
    pdfDeleted: !!manifest.pdfDeleted,
    sourceType: String(manifest.sourceType || ((cfg && cfg.sourceType) || 'script')).trim(),
    rawTextPreview: String(manifest.rawTextPreview || '').trim(),
    deletePdfRequested: !!manifest.deletePdfRequested,
    deleteRequestedAt: manifest.deleteRequestedAt || null,
    deleteRequestedBy: String(manifest.deleteRequestedBy || '').trim(),
    deletedAt: manifest.deletedAt || null,
    gmailMessageId: String(manifest.gmailMessageId || '').trim(),
    gmailThreadId: String(manifest.gmailThreadId || '').trim(),
    gmailAttachmentKey: String(manifest.gmailAttachmentKey || '').trim(),
    gmailSubject: String(manifest.gmailSubject || '').trim(),
    gmailFrom: String(manifest.gmailFrom || '').trim(),
    gmailReplyTo: String(manifest.gmailReplyTo || '').trim()
  };
  if (!out.componentFileIds.length && out.driveFileId) out.componentFileIds = [out.driveFileId];
  if (!out.componentSourceKeys.length && out.driveFileId) out.componentSourceKeys = [buildManifestOwnSourceKey_(out)];
  if (out.representedSourceCount <= 0) out.representedSourceCount = out.componentSourceKeys.length || (out.driveFileId ? 1 : 0);
  return out;
}

function ensureRuntimeThreadShape_(thread) {
  thread = thread || {};
  return {
    threadId: String(thread.threadId || '').trim(),
    messageIds: uniqueNonEmptyStrings_(thread.messageIds || []),
    manifestIds: uniqueNonEmptyStrings_(thread.manifestIds || []),
    noPdfMessageIds: uniqueNonEmptyStrings_(thread.noPdfMessageIds || []),
    subject: String(thread.subject || '').trim(),
    from: String(thread.from || '').trim(),
    replyTo: String(thread.replyTo || '').trim(),
    status: String(thread.status || 'pending').trim(),
    terminal: !!thread.terminal,
    finalizationStatus: String(thread.finalizationStatus || '').trim(),
    labeledProcessed: !!thread.labeledProcessed,
    labeledRejected: !!thread.labeledRejected,
    labeledNoPdf: !!thread.labeledNoPdf,
    markedRead: !!thread.markedRead,
    trashed: !!thread.trashed,
    updatedAt: thread.updatedAt || new Date().toISOString(),
    lastEvaluatedAt: thread.lastEvaluatedAt || null
  };
}

function migrateLegacyManifestsIntoRuntimeIndex_(stateFolder, cfg) {
  var files = stateFolder.getFilesByType(MimeType.PLAIN_TEXT);
  var index = buildEmptyRuntimeIndex_(cfg);
  var found = 0;
  while (files.hasNext()) {
    var file = files.next();
    var name = file.getName() || '';
    if (name === cfg.runtimeIndexFileName) continue;
    if (!/\.json$/i.test(name)) continue;
    var parsed = parseJsonSafe_(file.getBlob().getDataAsString());
    if (!parsed || !parsed.driveFileId) continue;
    var manifest = ensureRuntimeManifestShape_(parsed, cfg);
    index.filesById[manifest.driveFileId] = manifest;
    found++;
    if (manifest.gmailThreadId) {
      linkManifestToRuntimeThread_(index, manifest.gmailThreadId, manifest, {
        subject: manifest.gmailSubject,
        from: manifest.gmailFrom,
        replyTo: manifest.gmailReplyTo,
        messageId: manifest.gmailMessageId
      });
    }
    addDirtyImportId_(index, manifest.driveFileId);
    if (manifest.patientFiscalCode) addDirtyCf_(index, manifest.patientFiscalCode);
  }
  if (!found) return null;
  index.meta.legacyMigratedAt = new Date().toISOString();
  return index;
}

function collectRuntimeManifests_(index) {
  index = ensureRuntimeIndexShape_(index, getPhboxConfig_());
  return Object.keys(index.filesById || {}).map(function (driveFileId) {
    return index.filesById[driveFileId];
  });
}

function upsertRuntimeManifestInIndex_(index, manifest, options) {
  options = options || {};
  var cfg = getPhboxConfig_();
  manifest = ensureRuntimeManifestShape_(manifest, cfg);
  if (!manifest.driveFileId) {
    throw new Error('Runtime manifest privo di driveFileId.');
  }
  index.filesById[manifest.driveFileId] = manifest;
  if (options.markDirty !== false) {
    addDirtyImportId_(index, manifest.driveFileId);
    if (manifest.patientFiscalCode) addDirtyCf_(index, manifest.patientFiscalCode);
  }
  if (manifest.gmailThreadId) {
    linkManifestToRuntimeThread_(index, manifest.gmailThreadId, manifest, {
      subject: manifest.gmailSubject,
      from: manifest.gmailFrom,
      replyTo: manifest.gmailReplyTo,
      messageId: manifest.gmailMessageId
    });
  }
  return manifest;
}

function linkManifestToRuntimeThread_(index, threadId, manifest, meta) {
  threadId = String(threadId || '').trim();
  if (!threadId) return null;
  var thread = ensureRuntimeThreadShape_(index.threadsById[threadId]);
  thread.threadId = threadId;
  if (meta && meta.messageId) thread.messageIds = uniqueNonEmptyStrings_(thread.messageIds.concat([meta.messageId]));
  if (manifest && manifest.driveFileId) thread.manifestIds = uniqueNonEmptyStrings_(thread.manifestIds.concat([manifest.driveFileId]));
  if (meta && meta.subject) thread.subject = meta.subject;
  if (meta && meta.from) thread.from = meta.from;
  if (meta && meta.replyTo) thread.replyTo = meta.replyTo;
  thread.updatedAt = new Date().toISOString();
  index.threadsById[threadId] = thread;
  addDirtyThreadId_(index, threadId);
  return thread;
}

function addDirtyImportId_(index, driveFileId) {
  driveFileId = String(driveFileId || '').trim();
  if (!driveFileId) return;
  index.dirty.imports = uniqueNonEmptyStrings_((index.dirty.imports || []).concat([driveFileId]));
}

function addDirtyCf_(index, cf) {
  cf = normalizeCf_(cf);
  if (!cf) return;
  index.dirty.cfs = uniqueNonEmptyStrings_((index.dirty.cfs || []).concat([cf]));
}

function addDirtyThreadId_(index, threadId) {
  threadId = String(threadId || '').trim();
  if (!threadId) return;
  index.dirty.threads = uniqueNonEmptyStrings_((index.dirty.threads || []).concat([threadId]));
}

function findRuntimeManifestByAttachmentKey_(index, attachmentKey) {
  attachmentKey = String(attachmentKey || '').trim();
  if (!attachmentKey) return null;
  var manifests = collectRuntimeManifests_(index);
  for (var i = 0; i < manifests.length; i++) {
    if (String(manifests[i].gmailAttachmentKey || '').trim() === attachmentKey) {
      return manifests[i];
    }
  }
  return null;
}

function buildGmailAttachmentRuntimeKey_(message, attachment) {
  var messageId = String(message && message.getId ? (message.getId() || '') : '').trim();
  var safeName = buildSafePdfAttachmentName_(attachment && attachment.getName ? attachment.getName() : '', message);
  var size = 0;
  try {
    size = (attachment && attachment.getBytes ? (attachment.getBytes() || []).length : 0);
  } catch (_) {
    size = 0;
  }
  return [messageId, safeName.toLowerCase(), String(size)].join('::');
}

function isRuntimeManifestTerminal_(manifest) {
  if (!manifest) return false;
  var status = String(manifest.status || '').trim();
  return status === 'parsed' || status === 'discarded_non_prescription' || status === 'deleted_pdf' || status === 'merged_component';
}

function isRuntimeManifestValidOutcome_(manifest) {
  if (!manifest) return false;
  if (String(manifest.analysisOutcome || '') === 'valid_prescription') return true;
  var status = String(manifest.status || '').trim();
  return status === 'parsed' || status === 'merged_component';
}

function isRuntimeManifestRejectedOutcome_(manifest) {
  if (!manifest) return false;
  return String(manifest.analysisOutcome || '') === 'non_prescription' || String(manifest.status || '') === 'discarded_non_prescription';
}

function computeStableHashForData_(data) {
  var json = JSON.stringify(data === undefined ? null : data);
  var digest = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, json, Utilities.Charset.UTF_8);
  return digest.map(function (b) {
    var value = (b < 0 ? b + 256 : b).toString(16);
    return value.length === 1 ? '0' + value : value;
  }).join('');
}

function removeDirtyImportIds_(index, driveFileIds) {
  var remove = {};
  uniqueNonEmptyStrings_(driveFileIds || []).forEach(function (id) { remove[id] = true; });
  index.dirty.imports = (index.dirty.imports || []).filter(function (id) { return !remove[id]; });
}

function removeDirtyCfs_(index, cfs) {
  var remove = {};
  uniqueNonEmptyStrings_((cfs || []).map(function (item) { return normalizeCf_(item); })).forEach(function (cf) { remove[cf] = true; });
  index.dirty.cfs = (index.dirty.cfs || []).filter(function (cf) { return !remove[normalizeCf_(cf)]; });
}

function removeDirtyThreadIds_(index, threadIds) {
  var remove = {};
  uniqueNonEmptyStrings_(threadIds || []).forEach(function (id) { remove[id] = true; });
  index.dirty.threads = (index.dirty.threads || []).filter(function (id) { return !remove[id]; });
}
