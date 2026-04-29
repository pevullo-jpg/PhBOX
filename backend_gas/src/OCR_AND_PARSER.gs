function buildImportManifestsFromDrive_(options) {
  options = options || {};
  var cfg = getPhboxConfig_();
  var rootFolder = DriveApp.getFolderById(cfg.folderId);
  var runtimeIndex = options.runtimeIndex || readRuntimeIndex_(rootFolder, cfg);
  var activeFiles = listActivePdfFiles_(rootFolder, cfg.maxDriveScanFiles || 1000);
  var activeMap = {};
  activeFiles.forEach(function (file) {
    activeMap[file.getId()] = file;
  });

  var manifests = [];
  var stats = {
    filesScanned: activeFiles.length,
    reusedUnchanged: 0,
    built: 0,
    parsed: 0,
    discardedNonPrescription: 0,
    transientDeferred: 0,
    buildErrors: 0,
    deferredBuilds: 0,
    deletedMarked: 0,
    stoppedEarly: false,
    lastDeferredFile: ''
  };

  for (var i = 0; i < activeFiles.length; i++) {
    var file = activeFiles[i];
    var driveFileId = file.getId();
    var current = runtimeIndex.filesById[driveFileId] ? ensureRuntimeManifestShape_(runtimeIndex.filesById[driveFileId], cfg) : null;
    var driveUpdatedAt = safeIsoString_(file.getLastUpdated());

    var canReuseWithoutAnalysis = !!(
      current &&
      Number(current.parserVersion || 0) === Number(cfg.parserVersion || 1) &&
      (
        (current.kind === 'canonical_cf_pdf' && current.status === 'parsed') ||
        ((current.analysisOutcome === 'valid_prescription' || current.analysisOutcome === 'non_prescription') && current.driveUpdatedAt === driveUpdatedAt)
      )
    );

    if (canReuseWithoutAnalysis) {
      manifests.push(current);
      stats.reusedUnchanged++;
      continue;
    }

    if (stats.built >= Number(cfg.maxFilesPerRun || 1) || shouldStopForBudget_(options.budget, 90000)) {
      stats.deferredBuilds++;
      stats.stoppedEarly = true;
      stats.lastDeferredFile = file.getName();
      continue;
    }

    try {
      var manifest = buildManifestForRuntimeFile_(file, current, cfg, { driveUpdatedAt: driveUpdatedAt });
      upsertRuntimeManifestInIndex_(runtimeIndex, manifest, { markDirty: true });
      manifests.push(manifest);
      stats.built++;
      if (manifest.status === 'parsed') stats.parsed++;
      if (manifest.status === 'discarded_non_prescription') stats.discardedNonPrescription++;
      if (manifest.status === 'error_transient') stats.transientDeferred++;
      if (manifest.status === 'error') stats.buildErrors++;
    } catch (e) {
      if (isRetryableRuntimeFailure_(e)) {
        stats.deferredBuilds++;
        stats.transientDeferred++;
        stats.lastDeferredFile = file.getName();
        stats.stoppedEarly = true;
        logInfo_(cfg, 'Build runtime manifest rinviato per errore transitorio', {
          driveFileId: driveFileId,
          fileName: file.getName(),
          error: normalizeRuntimeErrorMessage_(e)
        });
        continue;
      }
      throw e;
    }
  }

  stats.deletedMarked = reconcileMissingRuntimeFiles_(runtimeIndex, activeMap, cfg);
  return {
    runtimeIndex: runtimeIndex,
    manifests: collectRuntimeManifests_(runtimeIndex),
    stats: stats
  };
}

function listActivePdfFiles_(folder, maxFiles) {
  var cfg = getPhboxConfig_();
  var out = [];
  collectPdfFilesRecursive_(folder, out, maxFiles, cfg, true);
  return out;
}

function collectPdfFilesRecursive_(folder, out, maxFiles, cfg, isRoot) {
  var files = folder.getFilesByType(MimeType.PDF);
  while (files.hasNext()) {
    var file = files.next();
    out.push(file);
    if (maxFiles && out.length >= maxFiles) return true;
  }

  if (!cfg.scanSubfolders) return false;

  var folders = folder.getFolders();
  while (folders.hasNext()) {
    var child = folders.next();
    var childName = child.getName() || '';
    if (childName === cfg.manifestsFolderName) continue;
    if (/^_/.test(childName)) continue;
    var stop = collectPdfFilesRecursive_(child, out, maxFiles, cfg, false);
    if (stop) return true;
  }
  return false;
}

function buildManifestForRuntimeFile_(file, current, cfg, context) {
  context = context || {};
  var driveUpdatedAt = context.driveUpdatedAt || safeIsoString_(file.getLastUpdated());
  var parentInfo = getDirectParentFolderInfo_(file, cfg.folderId);
  var nowIso = new Date().toISOString();
  var base = ensureRuntimeManifestShape_(current || {
    id: file.getId(),
    driveFileId: file.getId(),
    fileName: file.getName(),
    mimeType: file.getMimeType() || MimeType.PDF,
    createdAt: safeIsoString_(file.getDateCreated()) || nowIso,
    sourceType: cfg.sourceType,
    syncNeeded: true
  }, cfg);

  try {
    var fileBlob = file.getBlob();
    var binaryPdfPageCount = estimatePdfPageCountFromBlob_(fileBlob);
    var ocr = runOcrOnBlob_(fileBlob, 'FILE_' + file.getName());
    var resolvedPdfPageCount = Math.max(0, Number(binaryPdfPageCount || 0), Number((ocr && ocr.pageCount) || 0));
    var parsed = parsePrescriptionText_(ocr.text, file.getName(), cfg, {
      pdfPageCount: resolvedPdfPageCount,
      ocrPageCount: Number((ocr && ocr.pageCount) || 0),
      binaryPdfPageCount: Number(binaryPdfPageCount || 0)
    });
    var classification = classifyParsedPrescriptionResult_(parsed, ocr.text, cfg);

    var manifest = ensureRuntimeManifestShape_(base, cfg);
    manifest.parserVersion = Number(cfg.parserVersion || 1);
    manifest.fileName = file.getName();
    manifest.mimeType = file.getMimeType() || MimeType.PDF;
    manifest.driveUpdatedAt = driveUpdatedAt;
    manifest.updatedAt = nowIso;
    manifest.syncNeeded = true;
    manifest.parentFolderId = parentInfo.id;
    manifest.parentFolderName = parentInfo.name;
    manifest.webViewLink = file.getUrl();
    manifest.errorMessage = '';
    manifest.patientFiscalCode = parsed.patientFiscalCode;
    manifest.patientFullName = parsed.patientFullName;
    manifest.doctorFullName = parsed.doctorFullName;
    manifest.exemptionCode = parsed.exemptionCode;
    manifest.exemptions = parsed.exemptions;
    manifest.city = parsed.city;
    manifest.therapy = parsed.therapy;
    manifest.isDpc = parsed.isDpc;
    manifest.prescriptionNres = parsed.strongPrescriptionNres;
    manifest.strongPrescriptionNres = parsed.strongPrescriptionNres;
    manifest.weakPrescriptionNres = parsed.weakPrescriptionNres;
    manifest.prescriptionTextFingerprint = parsed.prescriptionTextFingerprint || '';
    manifest.prescriptionIdentityKeys = buildManifestPrescriptionIdentityKeys_(parsed.strongPrescriptionNres, parsed.prescriptionCount, file.getId(), driveUpdatedAt);
    manifest.prescriptionCount = parsed.prescriptionCount;
    manifest.nreExtractionMode = 'split_strong_weak_v1';
    manifest.pdfPageCount = parsed.pdfPageCount || 0;
    manifest.ocrPageCount = parsed.ocrPageCount || 0;
    manifest.binaryPdfPageCount = parsed.binaryPdfPageCount || 0;
    manifest.prescriptionDate = parsed.prescriptionDate;
    manifest.filenameFiscalCode = parsed.filenameFiscalCode;
    manifest.filenamePrescriptionDate = parsed.filenamePrescriptionDate;
    manifest.filenameContentMismatch = !!parsed.filenameContentMismatch;
    manifest.rawTextPreview = parsed.rawTextPreview || '';
    manifest.pdfDeleted = false;
    manifest.deletedAt = null;
    manifest.deletePdfRequested = false;
    manifest.deleteRequestedAt = null;
    manifest.deleteRequestedBy = '';

    if (classification.isValid) {
      manifest.status = 'parsed';
      manifest.analysisOutcome = 'valid_prescription';
      if (!manifest.kind || manifest.kind === 'discarded_non_prescription' || manifest.kind === 'raw_source') {
        manifest.kind = manifest.kind === 'canonical_cf_pdf' ? 'canonical_cf_pdf' : 'raw_source';
      }
      manifest.componentFileIds = (manifest.kind === 'canonical_cf_pdf') ? uniqueNonEmptyStrings_(manifest.componentFileIds || [file.getId()]) : [file.getId()];
      manifest.componentSourceKeys = (manifest.kind === 'canonical_cf_pdf') ? uniqueNonEmptyStrings_(manifest.componentSourceKeys || [buildManifestOwnSourceKey_(manifest)]) : [buildManifestOwnSourceKey_(manifest)];
      manifest.componentDuplicateFingerprintKeys = parsed.prescriptionTextFingerprint ? ['DOC:' + parsed.prescriptionTextFingerprint] : [];
      manifest.representedSourceCount = manifest.componentSourceKeys.length || 1;
      if (manifest.kind !== 'canonical_cf_pdf') {
        manifest.canonicalGroupKey = '';
        manifest.canonicalFileId = '';
        manifest.mergeSignature = '';
        manifest.supersededByCanonical = '';
        manifest.mergedAt = null;
      }
      return manifest;
    }

    manifest.status = 'discarded_non_prescription';
    manifest.kind = 'discarded_non_prescription';
    manifest.analysisOutcome = 'non_prescription';
    manifest.errorMessage = classification.reason;
    manifest.canonicalGroupKey = '';
    manifest.canonicalFileId = '';
    manifest.mergeSignature = '';
    manifest.supersededByCanonical = '';
    manifest.mergedAt = null;
    manifest.componentFileIds = [file.getId()];
    manifest.componentSourceKeys = [buildManifestOwnSourceKey_(manifest)];
    manifest.componentDuplicateFingerprintKeys = parsed.prescriptionTextFingerprint ? ['DOC:' + parsed.prescriptionTextFingerprint] : [];
    manifest.representedSourceCount = 1;
    trashFileAsNonPrescription_(file, cfg);
    manifest.pdfDeleted = true;
    manifest.webViewLink = '';
    manifest.deletedAt = nowIso;
    return manifest;
  } catch (e) {
    if (shouldAbortManifestCreationForError_(e)) throw e;
    var errorManifest = ensureRuntimeManifestShape_(base, cfg);
    errorManifest.parserVersion = Number(cfg.parserVersion || 1);
    errorManifest.fileName = file.getName();
    errorManifest.mimeType = file.getMimeType() || MimeType.PDF;
    errorManifest.driveUpdatedAt = driveUpdatedAt;
    errorManifest.updatedAt = nowIso;
    errorManifest.syncNeeded = false;
    errorManifest.status = 'error';
    errorManifest.analysisOutcome = 'error_parser';
    errorManifest.kind = 'raw_source';
    errorManifest.errorMessage = normalizeRuntimeErrorMessage_(e);
    errorManifest.parentFolderId = parentInfo.id;
    errorManifest.parentFolderName = parentInfo.name;
    errorManifest.webViewLink = file.getUrl();
    return errorManifest;
  }
}

function classifyParsedPrescriptionResult_(parsed, rawText, cfg) {
  parsed = parsed || {};
  var normalizedText = normalizeToken_(rawText || '');
  var hasCf = !!normalizeCf_(parsed.patientFiscalCode);
  var cityAccepted = isAcceptedPrescriptionCity_(rawText || normalizedText, cfg);
  var signalScore = 0;
  if (/\bPRESCRIZIONE\b|\bRICETTA\b|SERVIZIO\s+SANITARIO|\bSSN\b|PROMEMORIA/i.test(String(rawText || ''))) signalScore += 2;
  if ((parsed.strongPrescriptionNres || []).length) signalScore += 2;
  if (parsed.prescriptionDate) signalScore += 1;
  if (parsed.doctorFullName) signalScore += 1;
  if ((parsed.therapy || []).length) signalScore += 1;
  if (parsed.isDpc) signalScore += 1;
  var likelyPrescription = isLikelyPrescriptionText_(normalizedText, cfg, rawText || normalizedText);
  var isValid = hasCf && cityAccepted && (likelyPrescription || signalScore >= 2);
  return {
    isValid: isValid,
    reason: isValid ? '' : buildInvalidPrescriptionReason_(hasCf, cityAccepted, signalScore, likelyPrescription)
  };
}

function buildInvalidPrescriptionReason_(hasCf, cityAccepted, signalScore, likelyPrescription) {
  if (!hasCf) return 'Codice fiscale non trovato';
  if (!cityAccepted) return 'Città non accettata';
  if (!likelyPrescription && signalScore < 2) return 'PDF non classificato come ricetta';
  return 'PDF non valido';
}

function trashFileAsNonPrescription_(file, cfg) {
  try {
    runWithRetryOnTransient_(function () {
      file.setTrashed(true);
      return true;
    }, {
      attempts: 3,
      baseSleepMs: 250
    });
  } catch (e) {
    logInfo_(cfg, 'Impossibile cestinare PDF non ricetta', {
      driveFileId: file && file.getId ? file.getId() : '',
      fileName: file && file.getName ? file.getName() : '',
      error: normalizeRuntimeErrorMessage_(e)
    });
  }
}

function reconcileMissingRuntimeFiles_(runtimeIndex, activeMap, cfg) {
  var changed = 0;
  collectRuntimeManifests_(runtimeIndex).forEach(function (manifest) {
    if (!manifest || !manifest.driveFileId) return;
    if (activeMap[manifest.driveFileId]) return;
    if (manifest.pdfDeleted) return;
    if (manifest.status === 'merged_component' || manifest.status === 'discarded_non_prescription' || manifest.status === 'deleted_pdf') return;
    manifest.status = 'deleted_pdf';
    manifest.kind = manifest.kind || 'raw_source';
    manifest.analysisOutcome = manifest.analysisOutcome || 'valid_prescription';
    manifest.pdfDeleted = true;
    manifest.webViewLink = '';
    manifest.deletePdfRequested = false;
    manifest.deletedAt = manifest.deletedAt || new Date().toISOString();
    manifest.updatedAt = new Date().toISOString();
    manifest.syncNeeded = true;
    upsertRuntimeManifestInIndex_(runtimeIndex, manifest, { markDirty: true });
    changed++;
    logInfo_(cfg, 'Runtime manifest marcato deleted_pdf', { driveFileId: manifest.driveFileId });
  });
  return changed;
}

function getDirectParentFolderInfo_(file, fallbackFolderId) {
  try {
    var parents = file.getParents();
    if (parents.hasNext()) {
      var parent = parents.next();
      return {
        id: parent.getId(),
        name: parent.getName()
      };
    }
  } catch (_) {}
  return {
    id: fallbackFolderId || '',
    name: ''
  };
}

function markDeletedManifests_(manifestsFolder, activeMap, cfg, options) {
  options = options || {};
  var files = manifestsFolder.getFilesByType(MimeType.PLAIN_TEXT);
  var out = [];
  var changed = 0;
  var stoppedEarly = false;
  while (files.hasNext()) {
    if (shouldStopForBudget_(options.budget, 30000)) {
      stoppedEarly = true;
      break;
    }
    var file = files.next();
    if (!/\.json$/i.test(file.getName())) continue;
    var manifest = parseJsonSafe_(file.getBlob().getDataAsString());
    if (!manifest || !manifest.driveFileId) continue;
    if (activeMap[manifest.driveFileId]) continue;
    if ((manifest.kind || '') === 'merged_component' || (manifest.kind || '') === 'merge_pending_component') continue;
    if (manifest.status === 'deleted_pdf' && manifest.pdfDeleted === true && !manifest.syncNeeded) continue;

    manifest.status = 'deleted_pdf';
    manifest.pdfDeleted = true;
    manifest.webViewLink = '';
    manifest.deletePdfRequested = false;
    manifest.deletedAt = manifest.deletedAt || new Date().toISOString();
    manifest.updatedAt = new Date().toISOString();
    manifest.syncNeeded = true;
    writeJsonFileInFolder_(manifestsFolder, file.getName(), manifest);
    out.push(manifest);
    changed++;
    logInfo_(cfg, 'Manifest marcato deleted_pdf', { driveFileId: manifest.driveFileId });
  }
  return {
    manifests: out,
    changed: changed,
    stoppedEarly: stoppedEarly
  };
}

function estimatePdfPageCountFromBlob_(blob) {
  if (!blob) return 0;

  var binaryText = '';
  try {
    binaryText = blob.getDataAsString('ISO-8859-1') || '';
  } catch (_) {
    try {
      binaryText = blob.getDataAsString() || '';
    } catch (_) {
      binaryText = '';
    }
  }

  if (!binaryText) return 0;

  var directMarkers = binaryText.match(/\/Type\s*\/Page\b/g);
  var directCount = directMarkers ? directMarkers.length : 0;

  var pagesTreeCount = 0;
  var pagesTreePattern = /\/Type\s*\/Pages\b[\s\S]{0,250}?\/Count\s+(\d{1,5})\b/g;
  var match;
  while ((match = pagesTreePattern.exec(binaryText)) !== null) {
    var count = parseInt(match[1], 10);
    if (!isNaN(count) && count > pagesTreeCount) pagesTreeCount = count;
  }

  var pageCount = Math.max(directCount, pagesTreeCount);
  if (!isFinite(pageCount) || pageCount < 0) return 0;
  return pageCount;
}

function estimateGoogleDocPageCount_(doc) {
  if (!doc) return 0;

  try {
    var body = doc.getBody();
    if (!body) return 0;

    var pageBreaks = 0;
    var children = body.getNumChildren();
    for (var i = 0; i < children; i++) {
      var child = body.getChild(i);
      if (child && child.getType && child.getType() === DocumentApp.ElementType.PAGE_BREAK) {
        pageBreaks++;
      }
    }

    var text = '';
    try {
      text = body.getText() || '';
    } catch (_) {
      text = '';
    }

    var formFeedMatches = text.match(/\f/g);
    var formFeedCount = formFeedMatches ? formFeedMatches.length : 0;
    var explicitPageCount = Math.max(pageBreaks, formFeedCount);

    if (explicitPageCount > 0) return explicitPageCount + 1;
    return 0;
  } catch (_) {
    return 0;
  }
}

function runOcrOnBlob_(blob, tempName) {
  var resource = {
    name: tempName,
    mimeType: MimeType.GOOGLE_DOCS
  };
  var options = {
    ocr: true,
    ocrLanguage: 'it'
  };
  var maxAttempts = 3;
  var baseSleepMs = 800;
  var lastError = null;

  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    var tempDocFile = null;
    try {
      tempDocFile = runWithRetryOnTransient_(function () {
        return Drive.Files.create(resource, blob, options);
      }, {
        attempts: 2,
        baseSleepMs: 400
      });

      var docId = tempDocFile.id;
      var ocrDocData = runWithRetryOnTransient_(function () {
        var doc = DocumentApp.openById(docId);
        return {
          text: (doc.getBody().getText() || ''),
          pageCount: estimateGoogleDocPageCount_(doc)
        };
      }, {
        attempts: 2,
        baseSleepMs: 400
      });

      return {
        docId: docId,
        text: ocrDocData.text,
        pageCount: ocrDocData.pageCount
      };
    } catch (e) {
      lastError = e;
      if (!isRetryableRuntimeFailure_(e) || attempt >= maxAttempts - 1) {
        throw e;
      }
      Utilities.sleep(baseSleepMs * Math.pow(2, attempt));
    } finally {
      if (tempDocFile && tempDocFile.id) {
        try {
          DriveApp.getFileById(tempDocFile.id).setTrashed(true);
        } catch (_) {}
      }
    }
  }

  throw lastError || new Error('OCR non riuscito senza errore esplicito.');
}

function parsePrescriptionText_(rawText, fileName, cfg, options) {
  options = options || {};
  var text = String(rawText || '');
  var filenameSignals = extractFileNameSignals_(fileName);

  var patientFiscalCode = extractFiscalCode_(text, fileName);
  var prescriptionDate = extractPrescriptionDate_(text, fileName);
  var patientFullName = extractPatientName_(text, patientFiscalCode);
  var doctorFullName = extractDoctorFullName_(text, cfg.doctorReferenceNames || []);
  var exemptions = extractExemptions_(text);
  var exemptionCode = exemptions.length ? exemptions[0] : '';
  var city = extractCity_(text, cfg.acceptedCities || []);
  var therapy = extractMedicines_(text);
  var isDpc = /\bDPC\b/i.test(text) || /_DPC\.PDF$/i.test(String(fileName || ''));
  var allDates = extractAllDates_(text, fileName);
  var prescriptionNreEvidence = extractPrescriptionNreEvidence_(text);
  var strongPrescriptionNres = prescriptionNreEvidence.strongNres;
  var weakPrescriptionNres = prescriptionNreEvidence.weakNres;
  var pdfPageCount = Math.max(0, Number(options.pdfPageCount || 0));
  var ocrPageCount = Math.max(0, Number(options.ocrPageCount || 0));
  var binaryPdfPageCount = Math.max(0, Number(options.binaryPdfPageCount || 0));
  var prescriptionCount = detectPrescriptionCount_(
    text,
    fileName,
    allDates,
    patientFiscalCode,
    strongPrescriptionNres.concat(weakPrescriptionNres),
    pdfPageCount
  );
  var prescriptionTextFingerprint = buildPrescriptionTextFingerprint_(text);

  return {
    patientFiscalCode: patientFiscalCode,
    patientFullName: patientFullName,
    doctorFullName: doctorFullName,
    exemptionCode: exemptionCode,
    exemptions: exemptions,
    city: city,
    therapy: therapy,
    isDpc: isDpc,
    prescriptionNres: strongPrescriptionNres,
    strongPrescriptionNres: strongPrescriptionNres,
    weakPrescriptionNres: weakPrescriptionNres,
    prescriptionCount: prescriptionCount,
    pdfPageCount: pdfPageCount,
    ocrPageCount: ocrPageCount,
    binaryPdfPageCount: binaryPdfPageCount,
    prescriptionTextFingerprint: prescriptionTextFingerprint,
    prescriptionDate: prescriptionDate,
    filenameFiscalCode: filenameSignals.fiscalCode,
    filenamePrescriptionDate: filenameSignals.prescriptionDate,
    filenameContentMismatch: detectFileContentMismatch_(filenameSignals, patientFiscalCode, prescriptionDate),
    rawTextPreview: text.substring(0, 4000)
  };
}

function extractFiscalCode_(rawText, fileName) {
  var text = String(rawText || '');
  var starMatch = text.match(/\*([A-Z]{6}[0-9]{2}[A-Z][0-9]{2}[A-Z][0-9]{3}[A-Z])\*/i);
  if (starMatch && starMatch[1]) return normalizeCf_(starMatch[1]);

  var beforeDoctor = text.split(/CODICE\s+FISCALE\s+(?:DEL\s+)?MEDICO/i)[0] || text;
  var matches = beforeDoctor.match(/[A-Z]{6}[0-9]{2}[A-Z][0-9]{2}[A-Z][0-9]{3}[A-Z]/ig);
  if (matches && matches.length) return normalizeCf_(matches[0]);

  var allMatches = text.match(/[A-Z]{6}[0-9]{2}[A-Z][0-9]{2}[A-Z][0-9]{3}[A-Z]/ig);
  if (allMatches && allMatches.length) return normalizeCf_(allMatches[0]);

  var fileMatch = String(fileName || '').match(/([A-Z]{6}[0-9]{2}[A-Z][0-9]{2}[A-Z][0-9]{3}[A-Z])/i);
  return fileMatch && fileMatch[1] ? normalizeCf_(fileMatch[1]) : '';
}

function extractFileNameSignals_(fileName) {
  var file = String(fileName || '');
  var fiscalCode = '';
  var prescriptionDate = '';

  var cfMatch = file.match(/([A-Z]{6}[0-9]{2}[A-Z][0-9]{2}[A-Z][0-9]{3}[A-Z])/i);
  if (cfMatch && cfMatch[1]) fiscalCode = normalizeCf_(cfMatch[1]);

  var dateMatch = file.match(/(\d{4}-\d{2}-\d{2}|[0-3]?\d[\/\-.][0-1]?\d[\/\-.]\d{4})/i);
  if (dateMatch && dateMatch[1]) {
    var parsed = parseDateValue_(dateMatch[1]);
    if (parsed) prescriptionDate = formatDateIso_(parsed);
  }

  return {
    fiscalCode: fiscalCode,
    prescriptionDate: prescriptionDate
  };
}

function detectFileContentMismatch_(fileSignals, contentFiscalCode, contentPrescriptionDate) {
  fileSignals = fileSignals || {};
  var cfMismatch = !!(fileSignals.fiscalCode && contentFiscalCode && normalizeCf_(fileSignals.fiscalCode) !== normalizeCf_(contentFiscalCode));
  var dateMismatch = !!(fileSignals.prescriptionDate && contentPrescriptionDate && String(fileSignals.prescriptionDate) !== String(contentPrescriptionDate));
  return cfMismatch || dateMismatch;
}

function extractPrescriptionDate_(rawText, fileName) {
  var text = String(rawText || '');
  var explicit = text.match(/\bDATA\s*:?\s*([0-3]?\d[\/\-.][0-1]?\d[\/\-.]\d{4})\b/i);
  if (explicit && explicit[1]) {
    var parsed = parseDateValue_(explicit[1]);
    if (parsed) return formatDateIso_(parsed);
  }

  var allDates = extractAllDates_(text, fileName);
  if (allDates.length) return formatDateIso_(allDates[allDates.length - 1]);
  return '';
}

function extractAllDates_(rawText, fileName) {
  var text = String(rawText || '') + '\n' + String(fileName || '');
  var out = [];
  var seen = {};

  function pushDate_(dateObj) {
    if (!(dateObj instanceof Date) || isNaN(dateObj.getTime())) return;
    var iso = formatDateIso_(dateObj);
    if (!iso || seen[iso]) return;
    seen[iso] = true;
    out.push(dateObj);
  }

  var dmY = /\b([0-3]?\d)[\/\-.]([0-1]?\d)[\/\-.](\d{4})\b/g;
  var match;
  while ((match = dmY.exec(text)) !== null) {
    var parsed1 = parseDateValue_(match[0]);
    pushDate_(parsed1);
  }

  var yMd = /\b(\d{4})-(\d{2})-(\d{2})\b/g;
  while ((match = yMd.exec(text)) !== null) {
    var parsed2 = parseDateValue_(match[0]);
    pushDate_(parsed2);
  }

  out.sort(function (a, b) {
    return a.getTime() - b.getTime();
  });
  return out;
}

function extractPatientName_(rawText, fiscalCode) {
  var text = String(rawText || '');
  var patterns = [
    /COGNOME\s+E\s+NOME\s*\/\s*INIZIALI\s+DELL['’]ASSISTITO\s*:?\s*([^\n\r*]+)/i,
    /COGNOME\s+E\s*\n+\s*NOME\s*:?\s*([^\n\r*]+)/i,
    /COGNOME\s+E\s+([^\n\r*]{3,})\s*\n+\s*NOME\s*:/i
  ];

  for (var i = 0; i < patterns.length; i++) {
    var match = text.match(patterns[i]);
    if (match && match[1]) {
      var cleaned = cleanupExtractedName_(match[1]);
      if (cleaned) return cleaned;
    }
  }

  if (fiscalCode) {
    var escapedCf = String(fiscalCode).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    var anchored = text.match(new RegExp('([A-ZÀ-Ú\' ]{3,})\\s*\\n+\\s*\\*' + escapedCf + '\\*', 'i'));
    if (anchored && anchored[1]) {
      var cleanedAnchored = cleanupExtractedName_(anchored[1]);
      if (cleanedAnchored && normalizeToken_(cleanedAnchored).indexOf('COGNOME E NOME') === -1) {
        return cleanedAnchored;
      }
    }
  }

  return '';
}

function extractDoctorFullName_(rawText, referenceNames) {
  var text = String(rawText || '');
  var explicit = text.match(/COGNOME\s+E\s+NOME\s+DEL\s+MEDICO\s*:?\s*([A-ZÀ-Ú' ]{3,}?)(?=\s+RILASCIATO\b|\s+AI\s+SENSI\b|\r?\n|$)/i);
  if (explicit && explicit[1]) {
    var cleanedExplicit = cleanupExtractedName_(explicit[1]);
    if (cleanedExplicit) return cleanedExplicit;
  }

  for (var r = 0; r < (referenceNames || []).length; r++) {
    var ref = normalizePersonName_(referenceNames[r]);
    if (!ref) continue;
    if (new RegExp('\\b' + normalizeToken_(ref).replace(/\s+/g, '\\s+') + '\\b', 'i').test(normalizeToken_(text))) {
      return ref;
    }
  }

  return '';
}

function cleanupExtractedName_(value) {
  var text = String(value || '')
    .replace(/[\r\n\t]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

  if (!text) return '';

  text = text
    .replace(/\b(RILASCIATO|AI\s+SENSI|CODICE\s+FISCALE|CODICE\s+AUTENTICAZIONE|INDIRIZZO|ESENZIONE|COMUNE|CITTA|CITTÀ|PROV|CAP|SERVIZIO|SANITARIO|NAZIONALE|REGIONE|SICILIA)\b.*$/i, '')
    .replace(/[0-9*]/g, ' ')
    .replace(/\s+/g, ' ')
    .replace(/^[:\-\s]+|[:\-\s]+$/g, '')
    .trim();

  if (!text) return '';

  var normalized = normalizeToken_(text);
  if (!normalized) return '';
  if (/REGIONE SICILIA|SERVIZIO SANITARIO|CODICE FISCALE|COGNOME E NOME DEL MEDICO/.test(normalized)) return '';

  var tokens = normalized.split(' ').filter(function (token) {
    return token && token.length > 1;
  });
  if (tokens.length < 2) return '';

  return normalizePersonName_(tokens.join(' '));
}

function extractExemptions_(rawText) {
  var text = String(rawText || '');
  var out = [];

  var explicit = text.match(/ESENZIONE\s*:?\s*([^\n\r]+?)(?=\s+SIGLA\s+PROVINCIA\b|\s+CODICE\s+ASL\b|\s+DISPOSIZIONI\b|\r?\n|$)/i);
  if (explicit && explicit[1]) {
    var segment = normalizeToken_(explicit[1]);
    if (segment) {
      if (segment.indexOf('NON ESENTE') === 0) {
        out.push('NON ESENTE');
      } else {
        var match = segment.match(/\b([A-Z]\d{2,3}|0\d{2,3}|\d{3})\b/);
        if (match && match[1]) out.push(normalizeExemptionValue_(match[1]));
      }
    }
  }

  return uniqueNonEmptyStrings_(out);
}

function normalizeExemptionValue_(value) {
  var text = normalizeToken_(value);
  if (!text) return '';
  if (text === 'NON ESENTE') return 'NON ESENTE';
  return text;
}

function extractCity_(rawText, acceptedCities, options) {
  options = options || {};
  var text = String(rawText || '');
  var accepted = normalizeAcceptedCities_(acceptedCities);

  var candidate = extractCityCandidate_(text);
  if (candidate) {
    var explicitCity = cleanupCityValue_(candidate, accepted, options);
    if (explicitCity) return explicitCity;
  }

  var normalizedText = normalizeToken_(text);
  for (var i = 0; i < accepted.length; i++) {
    var city = normalizeToken_(accepted[i]);
    if (city && normalizedText.indexOf(city) !== -1) {
      return normalizePersonName_(city.toLowerCase());
    }
  }

  return '';
}

function extractCityCandidate_(rawText) {
  var text = String(rawText || '');
  var comune = text.match(/COMUNE\s*:?\s*([A-ZÀ-Ú' ]+?)(?:\s+PROV\b|\r?\n|$)/i);
  if (comune && comune[1]) return comune[1];

  var citta = text.match(/CITTA['’]?\s*:?\s*([A-ZÀ-Ú' ]+?)(?:\s+PROV\b|\r?\n|$)/i);
  if (citta && citta[1]) return citta[1];

  return '';
}

function cleanupCityValue_(value, acceptedCities, options) {
  options = options || {};
  var accepted = normalizeAcceptedCities_(acceptedCities);
  var cleaned = normalizeToken_(value).replace(/\bPROV\b.*$/, '').trim();
  if (!cleaned) return '';

  if (accepted.length) {
    for (var i = 0; i < accepted.length; i++) {
      var city = normalizeToken_(accepted[i]);
      if (cleaned === city) return normalizePersonName_(city.toLowerCase());
    }
    return '';
  }

  return normalizePersonName_(cleaned.toLowerCase());
}

function normalizeAcceptedCities_(acceptedCities) {
  return (acceptedCities || []).map(function (city) {
    return normalizeToken_(city);
  }).filter(function (city) {
    return city;
  });
}

function extractMedicines_(rawText) {
  var text = String(rawText || '');
  var section = extractPrescriptionSection_(text);
  var lines = splitPrescriptionLines_(section);
  var out = [];
  var seen = {};

  lines.forEach(function (line) {
    var normalized = normalizeToken_(line);
    if (!normalized) return;
    if (/^(PRESCRIZIONE|QTA|QTA NOTA|QTA NOTA|NOTA)$/.test(normalized)) return;
    if (/TIPOLOGIA PRESCRIZIONE/.test(normalized)) return;
    if (/^(QUESITO DIAGNOSTICO|N CONFEZIONI PRESTAZIONI|TIPO RICETTA|CODICE FISCALE|CODICE AUTENTICAZIONE)/.test(normalized)) return;
    if (/^\d+\s+---$/.test(normalized)) return;
    if (/^[A-Z0-9]{1,4}\s+POS\b/.test(normalized)) return;

    var looksLikeMedicine = /^\d{8,10}\b/.test(normalized) || /^[A-Z0-9]{2,4}\s+-\s+[A-Z]/.test(line) || /\b(MG|MCG|ML|CPR|CPS|BUST|FIAL|UNITA|SOLOS|RIV|PEN)\b/.test(normalized);
    if (!looksLikeMedicine) return;

    var cleaned = cleanupMedicineLine_(line);
    if (!cleaned) return;
    var key = normalizeToken_(cleaned);
    if (!key || seen[key]) return;
    seen[key] = true;
    out.push(cleaned);
  });

  return out.slice(0, 8);
}

function extractPrescriptionSection_(rawText) {
  var text = String(rawText || '');
  var header = text.match(/PRESCRIZIONE\s+QTA[^\n\r]*/i);
  var tail = '';
  if (header && header.index >= 0) {
    tail = text.substring(header.index + header[0].length);
  } else {
    var start = text.search(/\bPRESCRIZIONE\b/i);
    tail = start === -1 ? text : text.substring(start);
  }

  var endMatch = tail.search(/(?:QUESITO DIAGNOSTICO|N\.?CONFEZIONI\/PRESTAZIONI|TIPO RICETTA)/i);
  if (endMatch === -1) return tail;
  return tail.substring(0, endMatch);
}

function splitPrescriptionLines_(section) {
  var prepared = String(section || '')
    .replace(/(\d{8,10}\s+[^\n\r]*?)(?=\s+\d{8,10}\s+)/g, '$1\n')
    .replace(/\s+---\s+/g, ' ---\n')
    .replace(/\r/g, '\n')
    .replace(/\n+/g, '\n');

  return prepared.split(/\n/).map(function (line) {
    return line.replace(/\s+/g, ' ').trim();
  }).filter(function (line) { return line; });
}

function cleanupMedicineLine_(line) {
  var cleaned = String(line || '')
    .replace(/\s+/g, ' ')
    .trim();

  cleaned = cleaned
    .replace(/^\d{8,10}\s*[-:]?\s*/, '')
    .replace(/^[A-Z0-9]{2,4}\s*-\s*/, '')
    .replace(/\s+\d+\s+(?:---|\d+|[A-Z0-9]{1,4})\s*$/i, '')
    .replace(/\s+---\s*$/i, '')
    .replace(/^[-:;\s]+|[-:;\s]+$/g, '')
    .replace(/\*/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

  if (!cleaned || cleaned.length < 4) return '';
  return cleaned;
}

function detectPrescriptionCount_(rawText, fileName, allDates, fiscalCode, prescriptionNres, pdfPageCount) {
  var structuralPageCount = Math.max(0, Number(pdfPageCount || 0));
  var textPageCount = estimatePrescriptionPageCountFromText_(rawText, fiscalCode);
  var resolvedPageCount = Math.max(structuralPageCount, textPageCount);
  if (resolvedPageCount > 0) return resolvedPageCount;

  var nres = uniqueNonEmptyStrings_(prescriptionNres || []);
  if (nres.length > 0) return nres.length;

  var file = String(fileName || '');
  if (/\-\d+\.pdf$/i.test(file)) return 1;

  var uniqueDates = {};
  (allDates || []).forEach(function (dateObj) {
    var iso = formatDateIso_(dateObj);
    if (iso) uniqueDates[iso] = true;
  });
  var uniqueDateCount = Object.keys(uniqueDates).length;
  if (uniqueDateCount > 0) return uniqueDateCount;

  return 1;
}

function estimatePrescriptionPageCountFromText_(rawText, fiscalCode) {
  var text = String(rawText || '').toUpperCase();
  if (!text) return 0;

  var candidateCounts = [];

  function pushCount_(value) {
    var count = Math.max(0, Number(value || 0));
    if (count > 0) candidateCounts.push(count);
  }

  pushCount_(countClusteredPatternOccurrences_(text, /SERVIZIO\s+SANITARIO\s+NAZIONALE\s+RICETTA\s+ELETTRONICA/ig, 250));
  pushCount_(countClusteredPatternOccurrences_(text, /RICETTA\s+ELETTRONICA\s*\-\s*PROMEMORIA\s+PER\s+L['’]?ASSISTITO/ig, 250));
  pushCount_(countClusteredPatternOccurrences_(text, /\bCODICE\s+AUTENTICAZIONE\s*:/ig, 120));
  pushCount_(countClusteredPatternOccurrences_(text, /\bTIPO\s+RICETTA\s*:/ig, 120));
  pushCount_(countClusteredPatternOccurrences_(text, /COGNOME\s+E\s+NOME\s+DEL\s+MEDICO\s*:/ig, 120));

  var normalizedCf = normalizeCf_(fiscalCode || '');
  if (normalizedCf) {
    var escapedCf = normalizedCf.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    pushCount_(countClusteredPatternOccurrences_(text, new RegExp('\\*?' + escapedCf + '\\*?', 'ig'), 120));
  }

  return chooseConsensusPrescriptionPageCount_(candidateCounts);
}

function chooseConsensusPrescriptionPageCount_(counts) {
  var values = (counts || []).map(function (item) {
    return Math.max(0, parseInt(item, 10) || 0);
  }).filter(function (item) {
    return item > 0;
  });

  if (!values.length) return 0;
  if (values.length === 1) return values[0];

  var frequency = {};
  values.forEach(function (value) {
    frequency[value] = (frequency[value] || 0) + 1;
  });

  var bestValue = 0;
  var bestFrequency = 0;
  Object.keys(frequency).forEach(function (key) {
    var value = parseInt(key, 10);
    var freq = frequency[key];
    if (freq > bestFrequency || (freq === bestFrequency && value > bestValue)) {
      bestFrequency = freq;
      bestValue = value;
    }
  });

  if (bestFrequency >= 2) return bestValue;

  values.sort(function (a, b) { return a - b; });
  return values[values.length - 1];
}

function countClusteredPatternOccurrences_(rawText, pattern, minGap) {
  var text = String(rawText || '').toUpperCase();
  if (!text) return 0;

  var matcher = new RegExp(pattern.source, pattern.flags || 'g');
  var positions = [];
  var match;
  while ((match = matcher.exec(text)) !== null) {
    positions.push(match.index);
  }

  return countClusteredPositions_(positions, minGap);
}

function countClusteredPositions_(positions, minGap) {
  var sorted = (positions || []).slice().sort(function (a, b) {
    return a - b;
  });
  if (!sorted.length) return 0;

  var gap = Math.max(1, Number(minGap || 1));
  var clusters = 0;
  var lastAccepted = null;

  sorted.forEach(function (position) {
    if (lastAccepted == null || position - lastAccepted > gap) {
      clusters++;
      lastAccepted = position;
    }
  });

  return clusters;
}

function isPrescriptionAnchorLine_(line) {
  var normalized = String(line || '').toUpperCase().replace(/\s+/g, ' ').trim();
  if (!normalized) return false;
  return /\b(?:NUM(?:ERO)?\s+(?:RICETTA|NRE)|NRE|CODICE\s+AUTENTICAZIONE|PROMEMORIA|1900\s*[A4])\b/.test(normalized);
}

function extractPrescriptionNreEvidence_(rawText) {
  var text = String(rawText || '').toUpperCase();
  if (!text) return { strongNres: [], weakNres: [] };

  var strongOut = [];
  var weakOut = [];
  var strongSeen = {};
  var weakSeen = {};
  var strongPatterns = [
    /\*((?:\d[\s\-:]*){12})\*/g,
    /\bNRE\b[\s:\-]*(?:1900\s*[A4][\s:\-]*)?\*((?:\d[\s\-:]*){12})\*/g,
    /\bNUM(?:ERO)?\s+(?:RICETTA|NRE)\b[\s:\-]*(?:1900\s*[A4][\s:\-]*)?\*((?:\d[\s\-:]*){12})\*/g,
    /\b1900\s*[A4][\s:\-]*\*((?:\d[\s\-:]*){12})\*/g,
    /\b1900\s*[A4][\s:\-]*((?:\d[\s\-:]*){12})\b/g,
    /\bNRE\b[\s:\-]*(?:1900\s*[A4][\s:\-]*)?((?:\d[\s\-:]*){12})\b/g,
    /\bNUM(?:ERO)?\s+(?:RICETTA|NRE)\b[\s:\-]*(?:1900\s*[A4][\s:\-]*)?((?:\d[\s\-:]*){12})\b/g
  ];
  var weakPatterns = [
    /\b1900\s*[A4][\s:\-]*((?:[0-9OQDGILSBTZ][\s\-:]*){12,18})\b/g,
    /\bNRE\b[\s:\-]*(?:1900\s*[A4][\s:\-]*)?((?:[0-9OQDGILSBTZ][\s\-:]*){12,18})\b/g,
    /\bNUM(?:ERO)?\s+(?:RICETTA|NRE)\b[\s:\-]*(?:1900\s*[A4][\s:\-]*)?((?:[0-9OQDGILSBTZ][\s\-:]*){12,18})\b/g,
    /\b1900\s*[A4]\s*([0-9OQDGILSBTZ\s\-:]{12,18})\b/g
  ];

  function pushStrong_(candidate) {
    var normalized = normalizePrescriptionNre_(candidate);
    if (!normalized || strongSeen[normalized]) return;
    strongSeen[normalized] = true;
    strongOut.push(normalized);
  }

  function pushWeak_(candidate) {
    var normalized = normalizeWeakPrescriptionNre_(candidate);
    if (!normalized || strongSeen[normalized] || weakSeen[normalized]) return;
    weakSeen[normalized] = true;
    weakOut.push(normalized);
  }

  extractStrongStarWrappedPrescriptionNres_(text).forEach(function (candidate) {
    pushStrong_(candidate);
  });

  strongPatterns.forEach(function (pattern) {
    var match;
    while ((match = pattern.exec(text)) !== null) {
      pushStrong_(match[1]);
    }
  });

  extractStrongPrescriptionNresFromAnchors_(text).forEach(function (candidate) {
    pushStrong_(candidate);
  });

  weakPatterns.forEach(function (pattern) {
    var match;
    while ((match = pattern.exec(text)) !== null) {
      pushWeak_(match[1]);
    }
  });

  extractWeakPrescriptionNresFromAnchors_(text).forEach(function (candidate) {
    pushWeak_(candidate);
  });

  return {
    strongNres: strongOut,
    weakNres: weakOut
  };
}

function extractStrongStarWrappedPrescriptionNres_(text) {
  var out = [];
  var matcher = /\*((?:\d[\s\-:]*){12})\*/g;
  var match;
  while ((match = matcher.exec(String(text || '').toUpperCase())) !== null) {
    var normalized = normalizePrescriptionNre_(match[1]);
    if (normalized) out.push(normalized);
  }
  return uniqueNonEmptyStrings_(out);
}

function extractStrongPrescriptionNresFromAnchors_(text) {
  var out = [];
  var windows = [];
  var patterns = [
    /\b1900\s*[A4]\b/g,
    /\bNRE\b/g,
    /\bNUM(?:ERO)?\s+(?:RICETTA|NRE)\b/g
  ];

  patterns.forEach(function (pattern) {
    var match;
    while ((match = pattern.exec(text)) !== null) {
      windows.push(text.substring(match.index, Math.min(text.length, match.index + 96)));
    }
  });

  windows.forEach(function (windowText) {
    extractStrongStarWrappedPrescriptionNres_(windowText).forEach(function (candidate) {
      out.push(candidate);
    });

    var candidateMatch = windowText.match(/(?:1900\s*[A4][\s:\-]*)?(?:NRE[\s:\-]*)?((?:\d[\s\-:]*){12})/);
    if (!candidateMatch || !candidateMatch[1]) return;
    var normalized = normalizePrescriptionNre_(candidateMatch[1]);
    if (normalized) out.push(normalized);
  });

  return uniqueNonEmptyStrings_(out);
}

function extractWeakPrescriptionNresFromAnchors_(text) {
  var out = [];
  var windows = [];
  var patterns = [
    /\b1900\s*[A4]\b/g,
    /\bNRE\b/g,
    /\bNUM(?:ERO)?\s+(?:RICETTA|NRE)\b/g
  ];

  patterns.forEach(function (pattern) {
    var match;
    while ((match = pattern.exec(text)) !== null) {
      windows.push(text.substring(match.index, Math.min(text.length, match.index + 80)));
    }
  });

  windows.forEach(function (windowText) {
    var normalized = normalizeWeakPrescriptionNre_(windowText);
    if (normalized) out.push(normalized);
  });

  return uniqueNonEmptyStrings_(out);
}

function normalizePrescriptionNre_(value) {
  var normalized = String(value || '')
    .toUpperCase()
    .replace(/\b1900\s*[A4]\b/g, ' ')
    .replace(/[\*\s:\-]+/g, '')
    .trim();
  return /^\d{12}$/.test(normalized) ? normalized : '';
}

function normalizeWeakPrescriptionNre_(value) {
  var normalized = String(value || '')
    .toUpperCase()
    .replace(/\b1900\s*[A4]\b/g, ' ')
    .replace(/[OQDU]/g, '0')
    .replace(/[ILT]/g, '1')
    .replace(/Z/g, '2')
    .replace(/S/g, '5')
    .replace(/G/g, '6')
    .replace(/B/g, '8');
  var digits = normalized.replace(/\D+/g, '');
  if (digits.length < 12) return '';
  for (var i = 0; i <= digits.length - 12; i++) {
    var candidate = digits.substring(i, i + 12);
    if (!/^\d{12}$/.test(candidate)) continue;
    return candidate;
  }
  return '';
}

function buildPrescriptionTextFingerprint_(rawText) {
  var normalized = normalizeTextForPrescriptionFingerprint_(rawText);
  if (!normalized) return '';
  var digest = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, normalized, Utilities.Charset.UTF_8);
  return digest.map(function (byte) {
    var value = (byte < 0 ? byte + 256 : byte).toString(16);
    return value.length === 1 ? '0' + value : value;
  }).join('');
}

function normalizeTextForPrescriptionFingerprint_(rawText) {
  var text = String(rawText || '').toUpperCase();
  if (!text) return '';
  return text
    .replace(/\bID\s+ASSISTITO\b/g, ' ')
    .replace(/\bCODICE\s+AUTENTICAZIONE\b/g, ' ')
    .replace(/\bNUMERO\s+PRATICA\b/g, ' ')
    .replace(/\bPROMEMORIA\b/g, ' ')
    .replace(/[^A-Z0-9]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .substring(0, 12000);
}

function buildManifestPrescriptionIdentityKeys_(prescriptionNres, prescriptionCount, driveFileId, driveUpdatedAt) {
  var out = [];
  var seen = {};
  var normalizedNres = uniqueNonEmptyStrings_(prescriptionNres || []).map(function (item) {
    return normalizePrescriptionNre_(item);
  }).filter(function (item) {
    return item;
  });

  normalizedNres.forEach(function (nre) {
    var key = 'NRE:' + nre;
    if (seen[key]) return;
    seen[key] = true;
    out.push(key);
  });

  var desiredCount = Math.max(out.length, Number(prescriptionCount || 1));
  var baseKey = 'FILE:' + String(driveFileId || 'UNKNOWN') + '@' + String(driveUpdatedAt || 'NA');
  if (desiredCount <= out.length) return out;

  if (desiredCount === 1 && !out.length) {
    out.push(baseKey);
    return out;
  }

  for (var i = out.length; i < desiredCount; i++) {
    out.push(baseKey + '#' + String(i + 1));
  }
  return out;
}
