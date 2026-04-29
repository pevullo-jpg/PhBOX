function ingestPrescriptionEmails_(options) {
  options = options || {};
  var cfg = getPhboxConfig_();
  var rootFolder = DriveApp.getFolderById(cfg.folderId);
  var runtimeIndex = options.runtimeIndex || readRuntimeIndex_(rootFolder, cfg);
  var query = buildGmailQuery_(cfg, cfg.gmailProcessedLabel);
  var threads = GmailApp.search(query, 0, cfg.maxMessagesPerRun);
  var stats = {
    query: query,
    scannedThreads: 0,
    scannedMessages: 0,
    excludedSenderMessages: 0,
    pdfCandidateMessages: 0,
    savedPdfs: 0,
    duplicateCandidates: 0,
    messagesWithAttachmentsNoRecognizedPdf: 0,
    stoppedEarly: false
  };

  for (var t = 0; t < threads.length; t++) {
    if (shouldStopForBudget_(options.budget, 120000)) {
      stats.stoppedEarly = true;
      break;
    }
    var thread = threads[t];
    stats.scannedThreads++;
    var messages = thread.getMessages();

    for (var m = 0; m < messages.length; m++) {
      if (shouldStopForBudget_(options.budget, 120000)) {
        stats.stoppedEarly = true;
        break;
      }
      var message = messages[m];
      stats.scannedMessages++;

      if (isExcludedSenderMessage_(message, cfg)) {
        stats.excludedSenderMessages++;
        continue;
      }

      var existingThreadState = ensureRuntimeThreadShape_(runtimeIndex.threadsById[thread.getId()]);
      if (existingThreadState.finalizationStatus === 'no_pdf' && existingThreadState.noPdfMessageIds.indexOf(message.getId()) !== -1) {
        continue;
      }

      var attachments = message.getAttachments({
        includeInlineImages: false,
        includeAttachments: true
      }) || [];
      if (!attachments.length) continue;

      var messageDiagnostic = createStageAMessageDiagnostic_(message, attachments);
      var pdfAttachments = [];
      var attachmentDiagnostics = [];
      for (var attIndex = 0; attIndex < attachments.length; attIndex++) {
        var attachmentInfo = classifyPdfAttachment_(attachments[attIndex]);
        attachmentDiagnostics.push(attachmentInfo.diagnostic);
        if (attachmentInfo.isPdf) pdfAttachments.push(attachments[attIndex]);
      }
      messageDiagnostic.attachments = attachmentDiagnostics;
      messageDiagnostic.pdfRecognized = !!pdfAttachments.length;

      if (!pdfAttachments.length) {
        stats.messagesWithAttachmentsNoRecognizedPdf++;
        messageDiagnostic.finalDisposition = 'discarded_no_recognized_pdf';
        var noPdfThreadId = thread.getId();
        var noPdfThreadState = ensureRuntimeThreadShape_(runtimeIndex.threadsById[noPdfThreadId]);
        noPdfThreadState.threadId = noPdfThreadId;
        noPdfThreadState.messageIds = uniqueNonEmptyStrings_(noPdfThreadState.messageIds.concat([message.getId()]));
        noPdfThreadState.noPdfMessageIds = uniqueNonEmptyStrings_(noPdfThreadState.noPdfMessageIds.concat([message.getId()]));
        noPdfThreadState.subject = message.getSubject() || thread.getFirstMessageSubject() || '';
        noPdfThreadState.from = message.getFrom() || '';
        noPdfThreadState.replyTo = getMessageReplyToSafe_(message);
        noPdfThreadState.updatedAt = new Date().toISOString();
        runtimeIndex.threadsById[noPdfThreadId] = noPdfThreadState;
        addDirtyThreadId_(runtimeIndex, noPdfThreadId);
        logUnrecognizedPdfAttachments_(cfg, message, attachmentDiagnostics);
        finalizeStageAMessageDiagnostic_(cfg, messageDiagnostic, false);
        continue;
      }

      stats.pdfCandidateMessages++;
      var threadId = thread.getId();
      var threadMeta = {
        subject: message.getSubject() || thread.getFirstMessageSubject() || '',
        from: message.getFrom() || '',
        replyTo: getMessageReplyToSafe_(message),
        messageId: message.getId()
      };
      var threadState = ensureRuntimeThreadShape_(runtimeIndex.threadsById[threadId]);
      threadState.threadId = threadId;
      threadState.messageIds = uniqueNonEmptyStrings_(threadState.messageIds.concat([message.getId()]));
      threadState.subject = threadMeta.subject;
      threadState.from = threadMeta.from;
      threadState.replyTo = threadMeta.replyTo;
      threadState.updatedAt = new Date().toISOString();
      runtimeIndex.threadsById[threadId] = threadState;
      addDirtyThreadId_(runtimeIndex, threadId);

      var savedAny = false;
      for (var a = 0; a < pdfAttachments.length; a++) {
        if (shouldStopForBudget_(options.budget, 120000)) {
          stats.stoppedEarly = true;
          break;
        }
        var saveResult = saveRecognizedPdfAttachmentRuntime_(rootFolder, runtimeIndex, pdfAttachments[a], message, threadMeta, cfg);
        if (saveResult.duplicate) {
          stats.duplicateCandidates++;
        }
        if (saveResult.saved) {
          stats.savedPdfs++;
          savedAny = true;
        }
      }

      messageDiagnostic.savedToDrive = savedAny;
      messageDiagnostic.ocrAttempted = false;
      messageDiagnostic.finalDisposition = savedAny ? 'saved_pending_analysis' : 'already_indexed';
      finalizeStageAMessageDiagnostic_(cfg, messageDiagnostic, false);
    }

    if (stats.stoppedEarly) break;
  }

  return {
    runtimeIndex: runtimeIndex,
    stats: stats
  };
}

function saveRecognizedPdfAttachmentRuntime_(rootFolder, runtimeIndex, attachment, message, threadMeta, cfg) {
  cfg = cfg || getPhboxConfig_();
  var attachmentKey = buildGmailAttachmentRuntimeKey_(message, attachment);
  var existing = findRuntimeManifestByAttachmentKey_(runtimeIndex, attachmentKey);
  if (existing) {
    linkManifestToRuntimeThread_(runtimeIndex, existing.gmailThreadId || (message.getThread() ? message.getThread().getId() : ''), existing, threadMeta);
    return { saved: false, duplicate: true, driveFileId: existing.driveFileId || '' };
  }

  var rawName = attachment && attachment.getName ? (attachment.getName() || '') : '';
  var safeName = buildSafePdfAttachmentName_(rawName, message);
  var nowIso = new Date().toISOString();
  var file = null;
  try {
    var sourceBlob = attachment.copyBlob();
    var bytes = sourceBlob.getBytes();
    var pdfBlob = Utilities.newBlob(bytes, MimeType.PDF, safeName);
    file = runWithRetryOnTransient_(function () {
      return rootFolder.createFile(pdfBlob);
    }, {
      attempts: 3,
      baseSleepMs: 400
    });
  } catch (e) {
    return {
      saved: false,
      duplicate: false,
      error: normalizeRuntimeErrorMessage_(e)
    };
  }

  var parentInfo = getDirectParentFolderInfo_(file, cfg.folderId);
  var manifest = ensureRuntimeManifestShape_({
    version: 1,
    parserVersion: Number(cfg.parserVersion || 1),
    id: file.getId(),
    driveFileId: file.getId(),
    fileName: file.getName(),
    mimeType: file.getMimeType() || MimeType.PDF,
    driveUpdatedAt: safeIsoString_(file.getLastUpdated()),
    createdAt: safeIsoString_(file.getDateCreated()) || nowIso,
    updatedAt: nowIso,
    syncedAt: null,
    syncNeeded: true,
    status: 'pending_analysis',
    kind: 'raw_source',
    analysisOutcome: '',
    canonicalGroupKey: '',
    canonicalFileId: '',
    mergeSignature: '',
    componentFileIds: [file.getId()],
    componentSourceKeys: [file.getId() + '@' + (safeIsoString_(file.getLastUpdated()) || nowIso)],
    componentDuplicateFingerprintKeys: [],
    representedSourceCount: 1,
    supersededByCanonical: '',
    mergedAt: null,
    errorMessage: '',
    patientFiscalCode: '',
    patientFullName: '',
    doctorFullName: '',
    exemptionCode: '',
    exemptions: [],
    city: '',
    therapy: [],
    isDpc: false,
    prescriptionNres: [],
    strongPrescriptionNres: [],
    weakPrescriptionNres: [],
    prescriptionTextFingerprint: '',
    prescriptionIdentityKeys: [],
    prescriptionCount: 1,
    nreExtractionMode: 'split_strong_weak_v1',
    pdfPageCount: 0,
    ocrPageCount: 0,
    binaryPdfPageCount: 0,
    prescriptionDate: null,
    filenameFiscalCode: extractFiscalCode_('', file.getName()),
    filenamePrescriptionDate: extractPrescriptionDate_('', file.getName()),
    filenameContentMismatch: false,
    parentFolderId: parentInfo.id,
    parentFolderName: parentInfo.name,
    webViewLink: file.getUrl(),
    pdfDeleted: false,
    sourceType: cfg.sourceType,
    rawTextPreview: '',
    deletePdfRequested: false,
    deleteRequestedAt: null,
    deleteRequestedBy: '',
    deletedAt: null,
    gmailMessageId: message.getId(),
    gmailThreadId: message.getThread().getId(),
    gmailAttachmentKey: attachmentKey,
    gmailSubject: threadMeta.subject,
    gmailFrom: threadMeta.from,
    gmailReplyTo: threadMeta.replyTo
  }, cfg);
  upsertRuntimeManifestInIndex_(runtimeIndex, manifest, { markDirty: true });
  return {
    saved: true,
    duplicate: false,
    driveFileId: manifest.driveFileId
  };
}

function finalizeRuntimeEmails_(options) {
  options = options || {};
  var cfg = getPhboxConfig_();
  var runtimeIndex = options.runtimeIndex;
  if (!runtimeIndex) throw new Error('Runtime index richiesto per finalizeRuntimeEmails_.');

  var processedLabel = ensureGmailLabel_(cfg.gmailProcessedLabel);
  var rejectedLabel = ensureGmailLabel_(cfg.gmailRejectedLabel || 'PhBOX/rejected');
  var threadIds = uniqueNonEmptyStrings_([].concat(runtimeIndex.dirty.threads || [], Object.keys(runtimeIndex.threadsById || {}).filter(function (threadId) {
    var thread = runtimeIndex.threadsById[threadId];
    return thread && !thread.finalizationStatus;
  })));

  var stats = {
    threadsSeen: threadIds.length,
    pendingThreads: 0,
    processedThreads: 0,
    rejectedThreads: 0,
    noPdfThreads: 0,
    orphanedThreads: 0,
    processedMessages: 0,
    rejectedMessages: 0,
    noPdfMessages: 0,
    pendingMessages: 0,
    markedRead: 0,
    trashed: 0,
    stoppedEarly: false
  };

  var finalizedThreadIds = [];
  for (var i = 0; i < threadIds.length; i++) {
    if (shouldStopForBudget_(options.budget, 20000)) {
      stats.stoppedEarly = true;
      break;
    }
    var threadId = threadIds[i];
    var threadState = ensureRuntimeThreadShape_(runtimeIndex.threadsById[threadId]);
    var manifests = threadState.manifestIds.map(function (id) { return runtimeIndex.filesById[id]; }).filter(function (item) { return !!item; });
    var evaluation = evaluateRuntimeThreadFinalization_(threadState, manifests);
    threadState.status = evaluation.status;
    threadState.terminal = evaluation.terminal;
    threadState.lastEvaluatedAt = new Date().toISOString();
    runtimeIndex.threadsById[threadId] = threadState;

    if (evaluation.status === 'pending') {
      stats.pendingThreads++;
      stats.pendingMessages += threadState.messageIds.length;
      continue;
    }

    var gmailThread = null;
    if (evaluation.requiresThreadAccess) {
      try {
        gmailThread = GmailApp.getThreadById(threadId);
      } catch (e) {
        logInfo_(cfg, 'Finalize Gmail thread non accessibile', {
          threadId: threadId,
          error: normalizeRuntimeErrorMessage_(e)
        });
        if (evaluation.status === 'orphaned') {
          gmailThread = null;
        } else {
          continue;
        }
      }
      if (!gmailThread && evaluation.status !== 'orphaned') continue;
    }

    var messages = gmailThread ? gmailThread.getMessages() : [];
    if (evaluation.status === 'processed') {
      processedLabel.addToThread(gmailThread);
      threadState.labeledProcessed = true;
      stats.processedThreads++;
      stats.processedMessages += messages.length;
    } else if (evaluation.status === 'rejected') {
      rejectedLabel.addToThread(gmailThread);
      threadState.labeledRejected = true;
      stats.rejectedThreads++;
      stats.rejectedMessages += messages.length;
    } else if (evaluation.status === 'no_pdf') {
      stats.noPdfThreads++;
      stats.noPdfMessages += messages.length || threadState.noPdfMessageIds.length || threadState.messageIds.length;
    } else if (evaluation.status === 'orphaned') {
      stats.orphanedThreads++;
    }

    if (evaluation.status === 'processed' || evaluation.status === 'rejected') {
      for (var m = 0; m < messages.length; m++) {
        try {
          messages[m].markRead();
          stats.markedRead++;
        } catch (_) {}
        if (evaluation.status === 'processed' && cfg.trashValidEmails) {
          try {
            messages[m].moveToTrash();
            stats.trashed++;
          } catch (_) {}
        }
      }
      threadState.markedRead = true;
      threadState.trashed = evaluation.status === 'processed' && !!cfg.trashValidEmails;
    }

    threadState.finalizationStatus = evaluation.status;
    threadState.updatedAt = new Date().toISOString();
    runtimeIndex.threadsById[threadId] = threadState;
    finalizedThreadIds.push(threadId);
  }

  removeDirtyThreadIds_(runtimeIndex, finalizedThreadIds);
  return {
    runtimeIndex: runtimeIndex,
    stats: stats
  };
}

function evaluateRuntimeThreadFinalization_(threadState, manifests) {
  manifests = manifests || [];
  threadState = ensureRuntimeThreadShape_(threadState);
  if (!manifests.length) {
    var noPdfOnly = !!threadState.noPdfMessageIds.length && threadState.noPdfMessageIds.length === threadState.messageIds.length;
    if (noPdfOnly) {
      return { status: 'no_pdf', terminal: true, requiresThreadAccess: true };
    }
    if (threadState.messageIds.length || threadState.manifestIds.length) {
      return { status: 'orphaned', terminal: true, requiresThreadAccess: false };
    }
    return { status: 'pending', terminal: false, requiresThreadAccess: false };
  }
  var allTerminal = manifests.every(function (manifest) { return isRuntimeManifestTerminal_(manifest); });
  if (!allTerminal) {
    return { status: 'pending', terminal: false, requiresThreadAccess: false };
  }
  var anyValid = manifests.some(function (manifest) { return isRuntimeManifestValidOutcome_(manifest); });
  var allRejected = manifests.every(function (manifest) { return isRuntimeManifestRejectedOutcome_(manifest); });
  if (anyValid) return { status: 'processed', terminal: true, requiresThreadAccess: true };
  if (allRejected) return { status: 'rejected', terminal: true, requiresThreadAccess: true };
  return { status: 'orphaned', terminal: true, requiresThreadAccess: false };
}

function createStageAMessageDiagnostic_(message, attachments) {
  return {
    subject: message.getSubject() || '',
    rawFrom: message.getFrom() || '',
    replyTo: getMessageReplyToSafe_(message),
    attachmentCount: (attachments || []).length,
    attachments: [],
    pdfRecognized: false,
    savedToDrive: false,
    ocrAttempted: false,
    ocrError: '',
    labeledThread: false,
    finalDisposition: ''
  };
}

function finalizeStageAMessageDiagnostic_(cfg, diagnostic, labeledThread) {
  diagnostic = diagnostic || {};
  diagnostic.labeledThread = !!labeledThread && !!diagnostic.pdfRecognized && !!diagnostic.savedToDrive;
  logInfo_(cfg, 'Stage A - esito messaggio candidato', diagnostic);
}

function ensureGmailLabel_(labelName) {
  var label = GmailApp.getUserLabelByName(labelName);
  if (!label) {
    label = GmailApp.createLabel(labelName);
  }
  return label;
}

function buildGmailQuery_(cfg, labelName) {
  var parts = [];
  if (cfg.scanUnreadOnly) parts.push('is:unread');
  parts.push('has:attachment');
  parts.push('-label:' + labelName);
  parts.push('-label:' + (cfg.gmailRejectedLabel || 'PhBOX/rejected'));
  if (cfg.scanSpam) {
    parts.push('in:anywhere');
    parts.push('-in:trash');
  } else {
    parts.push('in:inbox');
  }

  (cfg.excludedEmailSenders || []).forEach(function (sender) {
    var token = normalizeEmailSenderToken_(sender);
    if (!token) return;
    parts.push('-from:"' + token.replace(/"/g, '') + '"');
  });

  return parts.join(' ');
}

function classifyPdfAttachment_(attachment) {
  var name = attachment.getName() || '';
  var contentType = attachment.getContentType() || '';
  var nameLooksPdf = /\.pdf$/i.test(name);
  var contentTypeLooksPdf = /pdf/i.test(contentType);
  var signatureLooksPdf = false;
  var signatureChecked = false;

  if (!nameLooksPdf && !contentTypeLooksPdf) {
    signatureChecked = true;
    signatureLooksPdf = blobHasPdfSignature_(attachment);
  }

  var reasons = [];
  if (nameLooksPdf) reasons.push('filename=.pdf');
  if (contentTypeLooksPdf) reasons.push('contentType=pdf');
  if (signatureLooksPdf) reasons.push('signature=%PDF');

  if (!reasons.length) {
    if (signatureChecked) {
      reasons.push('nessun match filename/content-type/signature');
    } else {
      reasons.push('nessun match filename/content-type');
    }
  }

  return {
    isPdf: nameLooksPdf || contentTypeLooksPdf || signatureLooksPdf,
    diagnostic: {
      name: name,
      contentType: contentType,
      detection: reasons.join('|')
    }
  };
}

function blobHasPdfSignature_(blob) {
  try {
    var bytes = blob.getBytes() || [];
    if (bytes.length < 4) return false;
    return (bytes[0] & 255) === 37 &&
      (bytes[1] & 255) === 80 &&
      (bytes[2] & 255) === 68 &&
      (bytes[3] & 255) === 70;
  } catch (e) {
    return false;
  }
}

function buildSafePdfAttachmentName_(name, message) {
  var safe = String(name || '')
    .replace(/[\u0000-\u001f\u007f]/g, ' ')
    .replace(/[\\/:*?"<>|]+/g, '_')
    .replace(/\s+/g, ' ')
    .trim();

  if (!safe) {
    safe = 'mail_attachment_' + new Date().getTime() + '.pdf';
  }
  if (!/\.pdf$/i.test(safe)) {
    safe += '.pdf';
  }
  if (safe.length > 180) {
    safe = safe.substring(0, 176) + '.pdf';
  }
  return safe;
}

function logUnrecognizedPdfAttachments_(cfg, message, attachmentDiagnostics) {
  var payload = {
    from: message.getFrom() || '',
    replyTo: getMessageReplyToSafe_(message),
    subject: message.getSubject() || '',
    attachments: attachmentDiagnostics || [],
    discardReason: 'Messaggio con allegati reali ma nessun PDF riconosciuto tramite filename, content-type o signature %PDF.'
  };
  logInfo_(cfg, 'Stage A - allegati presenti ma nessun PDF riconosciuto', payload);
}

function getMessageReplyToSafe_(message) {
  try {
    if (message && typeof message.getReplyTo === 'function') {
      return message.getReplyTo() || '';
    }
  } catch (e) {}
  return '';
}

function isLikelyPrescriptionText_(normalizedText, cfg, rawText) {
  if (!normalizedText) return false;
  var hasCf = /[A-Z]{6}[0-9]{2}[A-Z][0-9]{2}[A-Z][0-9]{3}[A-Z]/.test(normalizedText);
  var hasPrescriptionWord = normalizedText.indexOf('PRESCRIZIONE') !== -1 || normalizedText.indexOf('RICETTA') !== -1;
  if (!hasCf || !hasPrescriptionWord) return false;
  return isAcceptedPrescriptionCity_(rawText || normalizedText, cfg);
}

function isAcceptedPrescriptionCity_(rawText, cfg) {
  var accepted = normalizeAcceptedCities_(cfg.acceptedCities || []);
  if (!accepted.length) return true;

  var candidate = extractCityCandidate_(rawText);
  if (!candidate) {
    return !!cfg.acceptRecipesWithoutCity;
  }

  var cleaned = normalizeToken_(candidate).replace(/\bPROV\b.*$/, '').trim();
  if (!cleaned) {
    return !!cfg.acceptRecipesWithoutCity;
  }

  return accepted.indexOf(cleaned) !== -1;
}

function isExcludedSenderMessage_(message, cfg) {
  var excluded = cfg.excludedEmailSenders || [];
  if (!excluded.length) return false;

  var fromValue = normalizeEmailSenderToken_(message.getFrom() || '');
  if (!fromValue) return false;

  for (var i = 0; i < excluded.length; i++) {
    var rule = normalizeEmailSenderToken_(excluded[i]);
    if (!rule) continue;
    if (fromValue.indexOf(rule) !== -1) return true;
  }
  return false;
}
