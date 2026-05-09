function dryRunPatientIdentityResolutionRequests() {
  return processPatientIdentityResolutionRequests({
    dryRun: true,
    maxWrites: 25,
    maxSamples: 30
  });
}

function runPatientIdentityResolutionRequestsBatch() {
  return processPatientIdentityResolutionRequests({
    dryRun: false,
    applyToken: 'PROCESS_USER_CONFIRMED_IDENTITY_REQUESTS',
    maxWrites: 25,
    maxSamples: 30
  });
}

function processPatientIdentityResolutionRequests(options) {
  options = options || {};
  var cfg = getPhboxConfig_();
  var startedAt = new Date().toISOString();
  var dryRun = options.dryRun !== false;
  var applyToken = String(options.applyToken || '').trim();
  var maxWrites = identityResolutionRequestsBoundedInt_(options.maxWrites, 25, 1, 100);
  var maxSamples = identityResolutionRequestsBoundedInt_(options.maxSamples, 30, 1, 100);
  var nowIso = new Date().toISOString();

  if (!dryRun && applyToken !== 'PROCESS_USER_CONFIRMED_IDENTITY_REQUESTS') {
    var blocked = {
      ok: false,
      mode: 'identity_resolution_requests_blocked',
      source: 'patient_identity_resolution_requests',
      dryRun: false,
      startedAt: startedAt,
      checkedAt: new Date().toISOString(),
      reason: 'blocked_missing_apply_token',
      writesAttempted: 0,
      writesSucceeded: 0,
      firestoreWritesDelta: 0
    };
    logInfo_(cfg, 'processPatientIdentityResolutionRequests bloccato', blocked);
    return blocked;
  }

  var maxRequestsToRead = Math.max(1, Math.min(50, maxWrites));
  var requests = listUserConfirmedIdentityResolutionRequests_(cfg, maxRequestsToRead);
  var result = {
    ok: true,
    mode: dryRun ? 'identity_resolution_requests_dry_run' : 'identity_resolution_requests_apply',
    source: 'patient_identity_resolution_requests',
    dryRun: dryRun,
    startedAt: startedAt,
    checkedAt: '',
    maxWrites: maxWrites,
    maxSamples: maxSamples,
    requestsSeen: requests.length,
    requestsProcessed: 0,
    plannedCreates: 0,
    writesPlanned: 0,
    writesAttempted: 0,
    writesSucceeded: 0,
    skippedInvalid: 0,
    skippedUnsupportedAction: 0,
    skippedAlreadyExists: 0,
    rejectedRequests: 0,
    maxWritesReached: false,
    firestoreWritesDelta: 0,
    samples: {
      plannedOrApplied: [],
      skippedAlreadyExists: [],
      rejected: [],
      unsupported: []
    }
  };

  for (var i = 0; i < requests.length; i++) {
    var request = requests[i] || {};
    var documentId = String(request.documentId || '').trim();
    var action = String(request.action || '').trim();
    var cf = normalizeCf_(request.targetFiscalCode || request.fiscalCode || request.targetId || request.patientFiscalCode || '');
    var reason = String(request.reason || request.identityResolutionReason || 'user_confirmed_identity_resolution').trim();

    if (!documentId) {
      result.skippedInvalid++;
      identityResolutionRequestsAddSample_(result.samples.rejected, {
        requestId: '',
        targetFiscalCode: cf,
        reason: 'missing_request_document_id'
      }, maxSamples);
      continue;
    }

    if (action !== 'create_canonical_patient') {
      if (!identityResolutionRequestsCanConsumeWrites_(result, dryRun, maxWrites, 1)) {
        break;
      }
      result.requestsProcessed++;
      result.skippedUnsupportedAction++;
      result.rejectedRequests++;
      identityResolutionRequestsAddSample_(result.samples.unsupported, {
        requestId: documentId,
        action: action || '',
        reason: 'unsupported_action'
      }, maxSamples);
      if (dryRun) {
        result.writesPlanned++;
        continue;
      }
      executeFirestoreCommit_(cfg, [identityResolutionRequestsBuildRequestPatchWrite_(cfg, documentId, {
        status: 'rejected',
        rejectReason: 'unsupported_action',
        processedAt: nowIso,
        updatedAt: nowIso,
        processor: 'patient_identity_resolution_requests'
      })]);
      result.writesAttempted++;
      result.writesSucceeded++;
      result.firestoreWritesDelta++;
      continue;
    }

    if (!identityResolutionRequestsIsSafeRealCf_(cf)) {
      if (!identityResolutionRequestsCanConsumeWrites_(result, dryRun, maxWrites, 1)) {
        break;
      }
      result.requestsProcessed++;
      result.skippedInvalid++;
      result.rejectedRequests++;
      identityResolutionRequestsAddSample_(result.samples.rejected, {
        requestId: documentId,
        targetFiscalCode: cf,
        reason: 'invalid_or_tmp_fiscal_code'
      }, maxSamples);
      if (dryRun) {
        result.writesPlanned++;
        continue;
      }
      executeFirestoreCommit_(cfg, [identityResolutionRequestsBuildRequestPatchWrite_(cfg, documentId, {
        status: 'rejected',
        rejectReason: 'invalid_or_tmp_fiscal_code',
        processedAt: nowIso,
        updatedAt: nowIso,
        processor: 'patient_identity_resolution_requests'
      })]);
      result.writesAttempted++;
      result.writesSucceeded++;
      result.firestoreWritesDelta++;
      continue;
    }

    if (identityResolutionRequestsPatientExists_(cfg, cf)) {
      if (!identityResolutionRequestsCanConsumeWrites_(result, dryRun, maxWrites, 1)) {
        break;
      }
      result.requestsProcessed++;
      result.skippedAlreadyExists++;
      identityResolutionRequestsAddSample_(result.samples.skippedAlreadyExists, {
        requestId: documentId,
        targetFiscalCode: cf,
        reason: 'patient_already_exists'
      }, maxSamples);
      if (dryRun) {
        result.writesPlanned++;
        continue;
      }
      executeFirestoreCommit_(cfg, [identityResolutionRequestsBuildRequestPatchWrite_(cfg, documentId, {
        status: 'done_already_exists',
        targetFiscalCode: cf,
        processedAt: nowIso,
        updatedAt: nowIso,
        processor: 'patient_identity_resolution_requests'
      })]);
      result.writesAttempted++;
      result.writesSucceeded++;
      result.firestoreWritesDelta++;
      continue;
    }

    var writesNeeded = 2;
    if (!identityResolutionRequestsCanConsumeWrites_(result, dryRun, maxWrites, writesNeeded)) {
      break;
    }

    result.requestsProcessed++;
    result.plannedCreates++;
    if (dryRun) {
      result.writesPlanned += writesNeeded;
      identityResolutionRequestsAddSample_(result.samples.plannedOrApplied, {
        action: 'create_canonical_patient',
        requestId: documentId,
        targetFiscalCode: cf,
        dryRun: true,
        reason: reason
      }, maxSamples);
      continue;
    }

    var patientDoc = identityResolutionRequestsBuildMinimalPatientDocument_(cf, reason, nowIso);
    var writes = [
      identityResolutionRequestsBuildCreateOnlyWrite_(cfg, 'patients', cf, patientDoc),
      identityResolutionRequestsBuildRequestPatchWrite_(cfg, documentId, {
        status: 'done',
        targetFiscalCode: cf,
        processedAt: nowIso,
        updatedAt: nowIso,
        processor: 'patient_identity_resolution_requests'
      })
    ];

    try {
      executeFirestoreCommit_(cfg, writes);
      result.writesAttempted += writes.length;
      result.writesSucceeded += writes.length;
      result.firestoreWritesDelta += writes.length;
      identityResolutionRequestsAddSample_(result.samples.plannedOrApplied, {
        action: 'create_canonical_patient',
        requestId: documentId,
        targetFiscalCode: cf,
        dryRun: false,
        reason: reason
      }, maxSamples);
    } catch (e) {
      if (identityResolutionRequestsIsAlreadyExistsCommitError_(e)) {
        if (!identityResolutionRequestsCanConsumeWrites_(result, false, maxWrites, 1)) {
          break;
        }
        executeFirestoreCommit_(cfg, [identityResolutionRequestsBuildRequestPatchWrite_(cfg, documentId, {
          status: 'done_already_exists',
          targetFiscalCode: cf,
          processedAt: nowIso,
          updatedAt: nowIso,
          processor: 'patient_identity_resolution_requests'
        })]);
        result.writesAttempted++;
        result.writesSucceeded++;
        result.firestoreWritesDelta++;
        result.skippedAlreadyExists++;
        identityResolutionRequestsAddSample_(result.samples.skippedAlreadyExists, {
          requestId: documentId,
          targetFiscalCode: cf,
          reason: 'patient_created_concurrently'
        }, maxSamples);
        continue;
      }
      throw e;
    }
  }

  if (!result.maxWritesReached && requests.length >= maxRequestsToRead) {
    result.maxWritesReached = true;
  }
  result.checkedAt = new Date().toISOString();
  logInfo_(cfg, 'processPatientIdentityResolutionRequests completato', result);
  return result;
}

function listUserConfirmedIdentityResolutionRequests_(cfg, limit) {
  var url = 'https://firestore.googleapis.com/v1/projects/' + encodeURIComponent(cfg.firestoreProjectId) + '/databases/(default)/documents:runQuery';
  var payload = {
    structuredQuery: {
      from: [{ collectionId: 'identity_resolution_requests' }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'status' },
          op: 'EQUAL',
          value: { stringValue: 'user_confirmed' }
        }
      },
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
    throw new Error('Firestore runQuery identity_resolution_requests failed [' + code + '] ' + body);
  }
  var parsed = parseJsonSafe_(body);
  if (!Array.isArray(parsed)) return [];
  return parsed.map(function (row) {
    if (!row || !row.document) return null;
    var document = row.document;
    var data = fromFirestoreFields_(document.fields || {});
    data.documentName = document.name || '';
    data.documentId = extractFirestoreDocumentId_(document.name || '');
    data.updateTime = document.updateTime || '';
    return data;
  }).filter(function (item) {
    return !!item;
  });
}

function identityResolutionRequestsBuildMinimalPatientDocument_(fiscalCode, reason, nowIso) {
  return {
    fiscalCode: fiscalCode,
    source: 'backend_identity_resolution_request',
    createdAt: nowIso,
    updatedAt: nowIso,
    identityCanonicalizedAt: nowIso,
    identityCanonicalizationReason: reason,
    identityCanonicalizationVersion: 1
  };
}

function identityResolutionRequestsBuildCreateOnlyWrite_(cfg, collection, documentId, data) {
  var write = buildFirestoreUpdateWrite_(cfg, collection, documentId, data);
  write.currentDocument = { exists: false };
  return write;
}

function identityResolutionRequestsBuildRequestPatchWrite_(cfg, documentId, data) {
  return buildFirestorePatchWrite_(cfg, 'identity_resolution_requests', documentId, data, Object.keys(data || {}));
}

function identityResolutionRequestsBuildRequestPatchWriteWithUpdateTime_(cfg, documentId, data, updateTime) {
  var write = identityResolutionRequestsBuildRequestPatchWrite_(cfg, documentId, data);
  write.currentDocument = { updateTime: String(updateTime || '').trim() };
  return write;
}

function identityResolutionRequestsPatientExists_(cfg, fiscalCode) {
  var url = buildFirestoreDocumentUrl_(cfg, 'patients', fiscalCode);
  var response = UrlFetchApp.fetch(url, {
    method: 'get',
    muteHttpExceptions: true,
    headers: {
      Authorization: 'Bearer ' + ScriptApp.getOAuthToken()
    }
  });
  var code = response.getResponseCode();
  if (code === 200) return true;
  if (code === 404) return false;
  throw new Error('Firestore GET patient failed [' + code + '] ' + response.getContentText());
}

function identityResolutionRequestsIsSafeRealCf_(value) {
  var cf = normalizeCf_(value);
  return !!cf && !auditPatientIdentityIsTmp_(cf) && /^[A-Z0-9]{16}$/.test(cf);
}

function identityResolutionRequestsIsAlreadyExistsCommitError_(error) {
  var text = String(error && (error.message || error) || '');
  return text.indexOf('ALREADY_EXISTS') >= 0 ||
    text.indexOf('already exists') >= 0 ||
    text.indexOf('FAILED_PRECONDITION') >= 0 ||
    text.indexOf('currentDocument') >= 0;
}

function identityResolutionRequestsCanConsumeWrites_(result, dryRun, maxWrites, writesNeeded) {
  var needed = Math.max(0, Number(writesNeeded || 0));
  var consumed = dryRun ? Number(result.writesPlanned || 0) : Number(result.writesAttempted || 0);
  if (consumed + needed > maxWrites) {
    result.maxWritesReached = true;
    return false;
  }
  return true;
}

function identityResolutionRequestsAddSample_(target, value, maxSamples) {
  if (!target || target.length >= maxSamples) return;
  target.push(value);
}

function identityResolutionRequestsBoundedInt_(value, fallback, minValue, maxValue) {
  var parsed = Number(value);
  if (!isFinite(parsed)) parsed = Number(fallback);
  if (!isFinite(parsed)) parsed = minValue;
  parsed = Math.floor(parsed);
  if (parsed < minValue) return minValue;
  if (parsed > maxValue) return maxValue;
  return parsed;
}

function dryRunPatientIdentityMergeRequests() {
  return processPatientIdentityMergeRequests({
    dryRun: true,
    maxWrites: 25,
    maxRequests: 25,
    maxSamples: 30
  });
}

function runPatientIdentityMergeRequestsBatch() {
  return processPatientIdentityMergeRequests({
    dryRun: false,
    applyToken: 'APPLY_USER_CONFIRMED_IDENTITY_MERGE_REQUESTS',
    maxWrites: 25,
    maxRequests: 25,
    maxSamples: 30
  });
}

function processPatientIdentityMergeRequests(options) {
  options = options || {};
  var cfg = getPhboxConfig_();
  var startedAt = new Date().toISOString();
  var dryRun = options.dryRun !== false;
  var applyToken = String(options.applyToken || '').trim();
  var maxWrites = identityResolutionRequestsBoundedInt_(options.maxWrites, 25, 1, 100);
  var maxRequests = identityResolutionRequestsBoundedInt_(options.maxRequests, 25, 1, 50);
  var maxSamples = identityResolutionRequestsBoundedInt_(options.maxSamples, 30, 1, 100);
  var nowIso = new Date().toISOString();

  if (!dryRun && applyToken !== 'APPLY_USER_CONFIRMED_IDENTITY_MERGE_REQUESTS') {
    var blocked = {
      ok: false,
      mode: 'identity_merge_requests_apply_blocked',
      source: 'patient_identity_merge_requests',
      dryRun: false,
      startedAt: startedAt,
      checkedAt: new Date().toISOString(),
      reason: 'blocked_missing_apply_token',
      writesAttempted: 0,
      writesSucceeded: 0,
      firestoreWritesDelta: 0
    };
    logInfo_(cfg, 'processPatientIdentityMergeRequests bloccato', blocked);
    return blocked;
  }

  var pendingCanonicalIndexLimit = 500;
  var pendingCanonicalIndexRequests = listPendingBackendMergeIdentityResolutionRequests_(cfg, pendingCanonicalIndexLimit);
  var pendingCanonicalIndexPossiblyTruncated = pendingCanonicalIndexRequests.length >= pendingCanonicalIndexLimit;
  var pendingCanonicalTargetBySource = identityMergeBuildPendingCanonicalTargetBySource_(pendingCanonicalIndexRequests);
  var requests = listPendingBackendMergeIdentityResolutionRequests_(cfg, maxRequests);
  var seenMergeKeys = {};
  var result = {
    ok: true,
    mode: dryRun ? 'identity_merge_requests_dry_run' : 'identity_merge_requests_apply',
    source: 'patient_identity_merge_requests',
    dryRun: dryRun,
    startedAt: startedAt,
    checkedAt: '',
    maxWrites: maxWrites,
    maxRequests: maxRequests,
    maxSamples: maxSamples,
    requestsSeen: requests.length,
    pendingCanonicalIndexSeen: pendingCanonicalIndexRequests.length,
    pendingCanonicalIndexPossiblyTruncated: pendingCanonicalIndexPossiblyTruncated,
    requestsProcessed: 0,
    plannedMergeRequests: 0,
    appliedMergeRequests: 0,
    invalidRequests: 0,
    unsupportedActions: 0,
    sourceMissing: 0,
    targetMissing: 0,
    targetAlreadyExists: 0,
    conflictFree: 0,
    conflictsDetected: 0,
    userChoicesRequired: 0,
    userChoicesSatisfied: 0,
    skippedUnresolvedConflicts: 0,
    skippedDuplicateRequests: 0,
    skippedConcurrentRequests: 0,
    deferredTargetPendingCanonical: 0,
    deferredTargetPendingCanonicalIndexTruncated: 0,
    redirectedMergedTargets: 0,
    writesPlanned: 0,
    writesAttempted: 0,
    writesSucceeded: 0,
    firestoreWritesDelta: 0,
    maxWritesReached: false,
    maxRequestsReached: requests.length >= maxRequests,
    supportedActions: [
      'choose_correct_fiscal_code',
      'merge_same_name_patient',
      'merge_similar_cf_patient'
    ],
    samples: {
      planned: [],
      applied: [],
      conflicts: [],
      rejected: [],
      unsupported: [],
      missing: [],
      duplicates: [],
      concurrent: [],
      deferred: [],
      redirected: []
    }
  };

  for (var i = 0; i < requests.length; i++) {
    var request = requests[i] || {};
    var requestId = String(request.documentId || '').trim();
    var requestUpdateTime = String(request.updateTime || '').trim();
    var action = String(request.action || '').trim();
    var sourceId = identityMergeRequestSourceId_(request);
    var selectedCf = identityMergeRequestSelectedFiscalCode_(request);
    var targetId = identityMergeRequestTargetId_(request, selectedCf);

    if (!requestId) {
      result.invalidRequests++;
      identityResolutionRequestsAddSample_(result.samples.rejected, {
        requestId: '',
        reason: 'missing_request_document_id'
      }, maxSamples);
      continue;
    }

    if (!identityMergeRequestIsSupportedAction_(action)) {
      result.requestsProcessed++;
      result.unsupportedActions++;
      identityResolutionRequestsAddSample_(result.samples.unsupported, {
        requestId: requestId,
        action: action || '',
        reason: 'unsupported_merge_action'
      }, maxSamples);
      continue;
    }

    if (!sourceId || !targetId) {
      result.requestsProcessed++;
      result.invalidRequests++;
      identityResolutionRequestsAddSample_(result.samples.rejected, {
        requestId: requestId,
        action: action,
        sourceId: sourceId,
        targetId: targetId,
        selectedFiscalCode: selectedCf,
        reason: 'missing_source_or_target'
      }, maxSamples);
      continue;
    }

    if (action !== 'merge_same_name_patient' &&
        (!selectedCf || !identityResolutionRequestsIsSafeRealCf_(selectedCf))) {
      result.requestsProcessed++;
      result.invalidRequests++;
      identityResolutionRequestsAddSample_(result.samples.rejected, {
        requestId: requestId,
        action: action,
        sourceId: sourceId,
        targetId: targetId,
        selectedFiscalCode: selectedCf,
        reason: 'invalid_selected_cf_for_cf_based_merge'
      }, maxSamples);
      continue;
    }

    var sourcePatient = identityResolutionRequestsGetPatientOrNull_(cfg, sourceId);
    if (!sourcePatient) {
      result.requestsProcessed++;
      result.sourceMissing++;
      identityResolutionRequestsAddSample_(result.samples.missing, {
        requestId: requestId,
        action: action,
        sourceId: sourceId,
        selectedFiscalCode: selectedCf,
        reason: 'source_patient_missing'
      }, maxSamples);
      continue;
    }

    var pendingCanonicalTargetId = pendingCanonicalTargetBySource[targetId] || '';
    var targetIsCanonicalCf = identityResolutionRequestsIsSafeRealCf_(targetId);
    if (!targetIsCanonicalCf && (pendingCanonicalTargetId || pendingCanonicalIndexPossiblyTruncated)) {
      result.requestsProcessed++;
      result.deferredTargetPendingCanonical++;
      if (!pendingCanonicalTargetId && pendingCanonicalIndexPossiblyTruncated) {
        result.deferredTargetPendingCanonicalIndexTruncated++;
      }
      identityResolutionRequestsAddSample_(result.samples.deferred, {
        requestId: requestId,
        action: action,
        sourceId: sourceId,
        targetId: targetId,
        pendingCanonicalTargetId: pendingCanonicalTargetId,
        pendingCanonicalIndexPossiblyTruncated: pendingCanonicalIndexPossiblyTruncated,
        reason: pendingCanonicalTargetId
            ? 'target_tmp_has_pending_canonical_merge'
            : 'pending_canonical_index_truncated_fail_closed',
        futureAction: 'run_after_target_tmp_canonical_merge_applies'
      }, maxSamples);
      continue;
    }

    var targetPatient = identityResolutionRequestsGetPatientOrNull_(cfg, targetId);
    var targetExists = !!targetPatient;
    if (targetExists) {
      result.targetAlreadyExists++;
    } else {
      result.targetMissing++;
    }

    if (!targetExists) {
      result.requestsProcessed++;
      identityResolutionRequestsAddSample_(result.samples.missing, {
        requestId: requestId,
        action: action,
        sourceId: sourceId,
        targetId: targetId,
        selectedFiscalCode: selectedCf,
        reason: 'target_patient_missing'
      }, maxSamples);
      continue;
    }

    var originalTargetId = targetId;
    var targetRedirected = false;
    var redirectedTargetId = identityMergeReadMergedIntoTargetId_(targetPatient);
    if (!identityResolutionRequestsIsSafeRealCf_(targetId) && redirectedTargetId) {
      var redirectedTargetPatient = identityResolutionRequestsGetPatientOrNull_(cfg, redirectedTargetId);
      if (!redirectedTargetPatient) {
        result.requestsProcessed++;
        result.targetMissing++;
        identityResolutionRequestsAddSample_(result.samples.missing, {
          requestId: requestId,
          action: action,
          sourceId: sourceId,
          targetId: targetId,
          redirectedTargetId: redirectedTargetId,
          selectedFiscalCode: selectedCf,
          reason: 'redirected_target_patient_missing'
        }, maxSamples);
        continue;
      }
      targetId = redirectedTargetId;
      targetRedirected = true;
      targetPatient = redirectedTargetPatient;
      targetExists = true;
      result.redirectedMergedTargets++;
      identityResolutionRequestsAddSample_(result.samples.redirected, {
        requestId: requestId,
        action: action,
        sourceId: sourceId,
        originalTargetId: originalTargetId,
        effectiveTargetId: targetId,
        reason: 'target_tmp_already_merged_into_canonical'
      }, maxSamples);
    }

    var rawConflicts = identityMergeDetectPatientFieldConflicts_(sourcePatient, targetPatient);
    var selectedFieldValues = targetRedirected ? {} : (identityMergeReadSelectedFieldValues_(request) || {});
    var unresolvedConflicts = targetRedirected
        ? rawConflicts.slice()
        : identityMergeUnresolvedConflictFields_(rawConflicts, request);
    var resolvedConflicts = rawConflicts.filter(function (field) {
      return unresolvedConflicts.indexOf(field) < 0;
    });
    var requiresUserChoices = unresolvedConflicts.length > 0;

    if (requiresUserChoices) {
      result.requestsProcessed++;
      result.plannedMergeRequests++;
      if (rawConflicts.length > 0) {
        result.conflictsDetected++;
      }
      if (resolvedConflicts.length > 0) {
        result.userChoicesSatisfied++;
      }
      result.userChoicesRequired++;
      result.skippedUnresolvedConflicts++;
      identityResolutionRequestsAddSample_(result.samples.conflicts, {
        requestId: requestId,
        action: action,
        sourceId: sourceId,
        targetId: targetId,
        originalTargetId: originalTargetId,
        selectedFiscalCode: selectedCf,
        conflictFields: unresolvedConflicts,
        resolvedConflictFields: resolvedConflicts,
        redirectedTargetRequiresFreshUserChoices: targetRedirected,
        futureAction: 'frontend_user_selects_field_values_then_backend_apply'
      }, maxSamples);
      identityResolutionRequestsAddSample_(result.samples.planned, {
        requestId: requestId,
        action: action,
        sourceId: sourceId,
        targetId: targetId,
        originalTargetId: originalTargetId,
        selectedFiscalCode: selectedCf,
        targetExists: targetExists,
        requiresUserChoices: true,
        conflictFields: unresolvedConflicts,
        resolvedConflictFields: resolvedConflicts,
        redirectedTargetRequiresFreshUserChoices: targetRedirected,
        targetIdentityType: identityMergeRequestTargetIdentityType_(action, targetId, selectedCf),
        futureAction: 'frontend_user_selects_field_values_then_backend_apply'
      }, maxSamples);
      continue;
    }

    var mergeKey = [action, sourceId, targetId].join('|');
    if (!dryRun && !requestUpdateTime) {
      result.requestsProcessed++;
      result.invalidRequests++;
      identityResolutionRequestsAddSample_(result.samples.rejected, {
        requestId: requestId,
        action: action,
        sourceId: sourceId,
        targetId: targetId,
        reason: 'missing_request_update_time_for_apply_precondition'
      }, maxSamples);
      continue;
    }

    if (seenMergeKeys[mergeKey]) {
      if (!identityResolutionRequestsCanConsumeWrites_(result, dryRun, maxWrites, 1)) {
        break;
      }
      result.requestsProcessed++;
      result.skippedDuplicateRequests++;
      identityResolutionRequestsAddSample_(result.samples.duplicates, {
        requestId: requestId,
        originalRequestId: seenMergeKeys[mergeKey],
        action: action,
        sourceId: sourceId,
        targetId: targetId,
        reason: 'duplicate_identity_merge_request'
      }, maxSamples);
      if (dryRun) {
        result.writesPlanned++;
        continue;
      }
      try {
        executeFirestoreCommit_(cfg, [identityResolutionRequestsBuildRequestPatchWriteWithUpdateTime_(cfg, requestId, {
          status: 'done_duplicate_merge_request',
          duplicateOfRequestId: seenMergeKeys[mergeKey],
          processedAt: nowIso,
          updatedAt: nowIso,
          processor: 'patient_identity_merge_requests'
        }, requestUpdateTime)]);
        result.writesAttempted++;
        result.writesSucceeded++;
        result.firestoreWritesDelta++;
      } catch (e) {
        if (!identityMergeIsRequestPreconditionError_(e)) throw e;
        result.writesAttempted++;
        result.skippedConcurrentRequests++;
        identityResolutionRequestsAddSample_(result.samples.concurrent, {
          requestId: requestId,
          action: action,
          sourceId: sourceId,
          targetId: targetId,
          reason: 'request_state_changed_before_duplicate_patch',
          attemptedWritesCounted: 1
        }, maxSamples);
      }
      continue;
    }

    result.requestsProcessed++;
    result.plannedMergeRequests++;
    if (rawConflicts.length > 0) {
      result.conflictsDetected++;
    }
    if (resolvedConflicts.length > 0) {
      result.userChoicesSatisfied++;
    }
    result.conflictFree++;
    var targetPatch = identityMergeBuildTargetPatientPatch_(selectedFieldValues, requestId, sourceId, nowIso);
    var writes = [
      identityMergeBuildSourcePatientMarkerWrite_(cfg, sourceId, targetId, requestId, nowIso),
      identityResolutionRequestsBuildRequestPatchWriteWithUpdateTime_(cfg, requestId, {
        status: 'done_merge_applied',
        sourcePatientId: sourceId,
        targetPatientId: targetId,
        selectedFiscalCode: selectedCf,
        appliedAt: nowIso,
        processedAt: nowIso,
        updatedAt: nowIso,
        processor: 'patient_identity_merge_requests'
      }, requestUpdateTime)
    ];
    if (Object.keys(targetPatch).length > 0) {
      writes.unshift(identityMergeBuildTargetPatientPatchWrite_(cfg, targetId, targetPatch));
    }

    if (!identityResolutionRequestsCanConsumeWrites_(result, dryRun, maxWrites, writes.length)) {
      break;
    }

    if (dryRun) {
      seenMergeKeys[mergeKey] = requestId;
      result.writesPlanned += writes.length;
      identityResolutionRequestsAddSample_(result.samples.planned, {
        requestId: requestId,
        action: action,
        sourceId: sourceId,
        targetId: targetId,
        originalTargetId: originalTargetId,
        selectedFiscalCode: selectedCf,
        targetExists: targetExists,
        requiresUserChoices: false,
        conflictFields: [],
        resolvedConflictFields: resolvedConflicts,
        redirectedTargetRevalidated: targetRedirected,
        targetIdentityType: identityMergeRequestTargetIdentityType_(action, targetId, selectedCf),
        writesPlanned: writes.length,
        futureAction: 'backend_merge_executor_apply_ready'
      }, maxSamples);
      continue;
    }

    try {
      executeFirestoreCommit_(cfg, writes);
      result.appliedMergeRequests++;
      result.writesAttempted += writes.length;
      result.writesSucceeded += writes.length;
      result.firestoreWritesDelta += writes.length;
      seenMergeKeys[mergeKey] = requestId;
      identityResolutionRequestsAddSample_(result.samples.applied, {
        requestId: requestId,
        action: action,
        sourceId: sourceId,
        targetId: targetId,
        originalTargetId: originalTargetId,
        selectedFiscalCode: selectedCf,
        redirectedTargetRevalidated: targetRedirected,
        writesSucceeded: writes.length,
        sourceDeleted: false,
        subcollectionsMoved: false
      }, maxSamples);
    } catch (e) {
      if (!identityMergeIsRequestPreconditionError_(e)) throw e;
      seenMergeKeys[mergeKey] = requestId;
      result.writesAttempted += writes.length;
      result.skippedConcurrentRequests++;
      identityResolutionRequestsAddSample_(result.samples.concurrent, {
        requestId: requestId,
        action: action,
        sourceId: sourceId,
        targetId: targetId,
        reason: 'request_state_changed_before_apply_commit',
        mergeKeyReserved: true,
        attemptedWritesCounted: writes.length
      }, maxSamples);
    }
  }

  result.checkedAt = new Date().toISOString();
  logInfo_(cfg, 'processPatientIdentityMergeRequests completato', result);
  return result;
}

function listPendingBackendMergeIdentityResolutionRequests_(cfg, limit) {
  var url = 'https://firestore.googleapis.com/v1/projects/' + encodeURIComponent(cfg.firestoreProjectId) + '/databases/(default)/documents:runQuery';
  var payload = {
    structuredQuery: {
      from: [{ collectionId: 'identity_resolution_requests' }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'status' },
          op: 'EQUAL',
          value: { stringValue: 'user_confirmed_pending_backend_merge_executor' }
        }
      },
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
    throw new Error('Firestore runQuery pending identity merge requests failed [' + code + '] ' + body);
  }
  var parsed = parseJsonSafe_(body);
  if (!Array.isArray(parsed)) return [];
  return parsed.map(function (row) {
    if (!row || !row.document) return null;
    var document = row.document;
    var data = fromFirestoreFields_(document.fields || {});
    data.documentName = document.name || '';
    data.documentId = extractFirestoreDocumentId_(document.name || '');
    data.updateTime = document.updateTime || '';
    return data;
  }).filter(function (item) {
    return !!item;
  });
}

function identityMergeBuildPendingCanonicalTargetBySource_(requests) {
  var pendingBySource = {};
  if (!Array.isArray(requests)) return pendingBySource;
  for (var i = 0; i < requests.length; i++) {
    var request = requests[i] || {};
    var action = String(request.action || '').trim();
    if (!identityMergeRequestIsSupportedAction_(action)) continue;
    var sourceId = identityMergeRequestSourceId_(request);
    var selectedCf = identityMergeRequestSelectedFiscalCode_(request);
    var targetId = identityMergeRequestTargetId_(request, selectedCf);
    var targetType = identityMergeRequestTargetIdentityType_(action, targetId, selectedCf);
    if (!sourceId || targetType !== 'canonical_cf') continue;
    pendingBySource[sourceId] = identityResolutionRequestsIsSafeRealCf_(targetId) ? targetId : selectedCf;
  }
  return pendingBySource;
}

function identityMergeRequestIsSupportedAction_(action) {
  return action === 'choose_correct_fiscal_code' ||
    action === 'merge_same_name_patient' ||
    action === 'merge_similar_cf_patient';
}

function identityMergeRequestSourceId_(request) {
  return normalizeCf_(request.sourcePatientId ||
    request.sourceFiscalCode ||
    request.temporaryDocumentId ||
    request.currentDocumentId ||
    request.patientFiscalCode ||
    '');
}

function identityMergeRequestSelectedFiscalCode_(request) {
  return normalizeCf_(request.selectedFiscalCode ||
    request.targetFiscalCode ||
    request.correctFiscalCode ||
    request.targetId ||
    '');
}

function identityMergeRequestTargetId_(request, selectedCf) {
  return normalizeCf_(request.targetPatientId ||
    request.targetFiscalCode ||
    selectedCf ||
    '');
}

function identityMergeRequestTargetIdentityType_(action, targetId, selectedCf) {
  if (action === 'merge_same_name_patient') {
    return identityResolutionRequestsIsSafeRealCf_(targetId) ? 'canonical_cf' : 'temporary_or_no_cf';
  }
  return identityResolutionRequestsIsSafeRealCf_(selectedCf || targetId) ? 'canonical_cf' : 'invalid';
}

function identityResolutionRequestsGetPatientOrNull_(cfg, documentId) {
  var normalizedId = normalizeCf_(documentId);
  if (!normalizedId) return null;
  var url = buildFirestoreDocumentUrl_(cfg, 'patients', normalizedId);
  var response = UrlFetchApp.fetch(url, {
    method: 'get',
    muteHttpExceptions: true,
    headers: {
      Authorization: 'Bearer ' + ScriptApp.getOAuthToken()
    }
  });
  var code = response.getResponseCode();
  if (code === 404) return null;
  if (code < 200 || code >= 300) {
    throw new Error('Firestore GET patient for merge dry-run failed [' + code + '] ' + response.getContentText());
  }
  var parsed = parseJsonSafe_(response.getContentText() || '{}');
  var data = fromFirestoreFields_((parsed && parsed.fields) || {});
  data.documentName = parsed.name || '';
  data.documentId = extractFirestoreDocumentId_(parsed.name || '');
  return data;
}

function identityMergeReadMergedIntoTargetId_(patient) {
  var status = String(patient && patient.identityMergeStatus || '').trim();
  var mergedInto = normalizeCf_(patient && patient.identityMergedInto || '');
  if (status !== 'merged_into') return '';
  return identityResolutionRequestsIsSafeRealCf_(mergedInto) ? mergedInto : '';
}

function identityMergeDetectPatientFieldConflicts_(sourcePatient, targetPatient) {
  var fields = [
    'fullName',
    'alias',
    'city',
    'exemptionCode',
    'doctorName',
    'doctorFullName'
  ];
  var conflicts = [];
  for (var i = 0; i < fields.length; i++) {
    var field = fields[i];
    var sourceValue = identityMergeComparableString_(sourcePatient && sourcePatient[field]);
    var targetValue = identityMergeComparableString_(targetPatient && targetPatient[field]);
    if (sourceValue && targetValue && sourceValue !== targetValue) {
      conflicts.push(field);
    }
  }
  return conflicts;
}

function identityMergeUnresolvedConflictFields_(conflictFields, request) {
  var selectedFieldValues = identityMergeReadSelectedFieldValues_(request);
  if (!selectedFieldValues) {
    return conflictFields.slice();
  }
  return conflictFields.filter(function (field) {
    if (!identityMergeIsSafeMergeChoiceField_(field)) return true;
    return !identityMergeHasOwnNonEmptyValue_(selectedFieldValues, field);
  });
}

function identityMergeReadSelectedFieldValues_(request) {
  var selectedFieldValues = identityMergeReadPlainObject_(request && request.selectedFieldValues);
  var confirmed = identityMergeIsTrue_(request && request.userFieldChoicesConfirmed);
  if (confirmed && selectedFieldValues) return selectedFieldValues;

  var action = String(request && request.action || '').trim();
  var normalizedName = String(request && request.normalizedName || '').trim();
  if (action === 'choose_correct_fiscal_code' && normalizedName) {
    return { fullName: normalizedName };
  }
  return null;
}

function identityMergeReadPlainObject_(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  return value;
}

function identityMergeIsTrue_(value) {
  return value === true || String(value).toLowerCase() === 'true';
}

function identityMergeHasOwnNonEmptyValue_(object, field) {
  if (!object || !Object.prototype.hasOwnProperty.call(object, field)) return false;
  return identityMergeComparableString_(object[field]) !== '';
}

function identityMergeIsSafeMergeChoiceField_(field) {
  return field === 'fullName' ||
    field === 'alias' ||
    field === 'city' ||
    field === 'exemptionCode' ||
    field === 'doctorName' ||
    field === 'doctorFullName';
}

function identityMergeBuildTargetPatientPatch_(selectedFieldValues, requestId, sourceId, nowIso) {
  var patch = {};
  var fields = ['fullName', 'alias', 'city', 'exemptionCode', 'doctorName', 'doctorFullName'];
  for (var i = 0; i < fields.length; i++) {
    var field = fields[i];
    if (!identityMergeHasOwnNonEmptyValue_(selectedFieldValues, field)) continue;
    patch[field] = String(selectedFieldValues[field]).trim();
  }
  if (Object.keys(patch).length > 0) {
    patch.updatedAt = nowIso;
    patch.identityMergeLastAppliedAt = nowIso;
    patch.identityMergeLastRequestId = requestId;
    patch.identityMergeLastSourceId = sourceId;
  }
  return patch;
}

function identityMergeBuildTargetPatientPatchWrite_(cfg, targetId, patch) {
  return buildFirestorePatchWrite_(cfg, 'patients', targetId, patch, Object.keys(patch || {}));
}

function identityMergeBuildSourcePatientMarkerWrite_(cfg, sourceId, targetId, requestId, nowIso) {
  return buildFirestorePatchWrite_(cfg, 'patients', sourceId, {
    identityMergeStatus: 'merged_into',
    identityMergedInto: targetId,
    identityMergedAt: nowIso,
    identityMergeRequestId: requestId,
    identityMaterializationStatus: 'pending',
    identityMaterializationQueuedAt: nowIso,
    updatedAt: nowIso
  }, [
    'identityMergeStatus',
    'identityMergedInto',
    'identityMergedAt',
    'identityMergeRequestId',
    'identityMaterializationStatus',
    'identityMaterializationQueuedAt',
    'updatedAt'
  ]);
}

function identityMergeIsRequestPreconditionError_(error) {
  var text = String(error && (error.message || error) || '');
  return text.indexOf('FAILED_PRECONDITION') >= 0 ||
    text.indexOf('currentDocument') >= 0 ||
    text.indexOf('updateTime') >= 0 ||
    text.indexOf('precondition') >= 0;
}

function identityMergeComparableString_(value) {
  return String(value == null ? '' : value).trim().replace(/\s+/g, ' ').toUpperCase();
}

function dryRunMaterializePatientIdentityMerges() {
  return processMaterializePatientIdentityMerges({
    dryRun: true,
    maxWrites: 100,
    maxSources: 10,
    maxSourceScan: 250,
    maxDocsPerSource: 50,
    maxSamples: 30
  });
}

function runMaterializePatientIdentityMergesBatch() {
  return processMaterializePatientIdentityMerges({
    dryRun: false,
    applyToken: 'MATERIALIZE_PATIENT_IDENTITY_MERGES',
    maxWrites: 100,
    maxSources: 10,
    maxSourceScan: 250,
    maxDocsPerSource: 50,
    maxSamples: 30
  });
}

function processMaterializePatientIdentityMerges(options) {
  options = options || {};
  var cfg = getPhboxConfig_();
  var startedAt = new Date().toISOString();
  var dryRun = options.dryRun !== false;
  var applyToken = String(options.applyToken || '').trim();
  var maxWrites = identityResolutionRequestsBoundedInt_(options.maxWrites, 100, 1, 100);
  var maxSources = identityResolutionRequestsBoundedInt_(options.maxSources, 10, 1, 25);
  var maxSourceScan = identityResolutionRequestsBoundedInt_(options.maxSourceScan, 250, maxSources, 500);
  var maxDocsPerSource = identityResolutionRequestsBoundedInt_(options.maxDocsPerSource, 50, 1, 100);
  var maxSamples = identityResolutionRequestsBoundedInt_(options.maxSamples, 30, 1, 100);
  var nowIso = new Date().toISOString();

  if (!dryRun && applyToken !== 'MATERIALIZE_PATIENT_IDENTITY_MERGES') {
    var blocked = {
      ok: false,
      mode: 'materialize_identity_merges_apply_blocked',
      source: 'patient_identity_materializer',
      dryRun: false,
      startedAt: startedAt,
      checkedAt: new Date().toISOString(),
      reason: 'blocked_missing_apply_token',
      writesAttempted: 0,
      writesSucceeded: 0,
      firestoreWritesDelta: 0
    };
    logInfo_(cfg, 'processMaterializePatientIdentityMerges bloccato', blocked);
    return blocked;
  }

  var sourceScan = materializeListMergedSourcePatients_(cfg, maxSourceScan, maxSources);
  var sources = sourceScan.items.slice(0, maxSources);
  var result = {
    ok: true,
    mode: dryRun ? 'materialize_identity_merges_dry_run' : 'materialize_identity_merges_apply',
    source: 'patient_identity_materializer',
    dryRun: dryRun,
    startedAt: startedAt,
    checkedAt: '',
    maxWrites: maxWrites,
    maxSources: maxSources,
    maxSourceScan: maxSourceScan,
    maxDocsPerSource: maxDocsPerSource,
    maxSamples: maxSamples,
    sourcePatientsScanned: sourceScan.scanned,
    sourcePatientsRawScanned: sourceScan.rawScanned,
    sourcePatientsEligible: sources.length,
    sourcePatientsProcessed: 0,
    sourcePatientsMaterialized: 0,
    sourcePatientsDeleted: 0,
    sourcePatientsSkippedAlreadyMaterialized: sourceScan.skippedAlreadyMaterialized,
    sourcePatientsSkippedBlocked: sourceScan.skippedBlocked,
    sourceScanLimitReached: sourceScan.scanLimitReached,
    lastScannedSourceId: sourceScan.lastScannedSourceId,
    sourceCursorPreviousDocumentName: sourceScan.cursorPreviousDocumentName,
    sourceCursorNextDocumentName: sourceScan.cursorNextDocumentName,
    sourceCursorShouldPersist: sourceScan.cursorShouldPersist,
    sourceCursorReset: sourceScan.cursorReset,
    sourceCursorWrapped: sourceScan.cursorWrapped,
    sourceCursorWritePlanned: false,
    sourceCursorWriteApplied: false,
    sourceCursorWriteSkippedDryRun: false,
    invalidSources: 0,
    targetMissing: 0,
    targetInvalid: 0,
    blockedSourceNotTmp: 0,
    blockedConflicts: 0,
    blockedTargetCollisions: 0,
    blockedScanTruncated: 0,
    blockedPlanTooLarge: 0,
    blockedStatusWritesPlanned: 0,
    blockedStatusWritesApplied: 0,
    documentsMoved: 0,
    topLevelDocumentsPatched: 0,
    familyGroupsPatched: 0,
    dashboardIndexesPatched: 0,
    dashboardIndexesDeleted: 0,
    therapeuticAdviceMoved: 0,
    doctorLinksMoved: 0,
    doctorLinkDuplicatesRemoved: 0,
    writesPlanned: 0,
    writesAttempted: 0,
    writesSucceeded: 0,
    firestoreWritesDelta: 0,
    maxWritesReached: false,
    maxSourcesReached: false,
    samples: {
      planned: [],
      applied: [],
      skipped: [],
      conflicts: [],
      collisions: [],
      blocked: []
    }
  };

  for (var i = 0; i < sources.length; i++) {
    if (result.sourcePatientsProcessed >= maxSources) {
      result.maxSourcesReached = true;
      break;
    }

    var sourcePatient = sources[i] || {};
    var sourceId = normalizeCf_(sourcePatient.documentId || sourcePatient.fiscalCode || sourcePatient.patientFiscalCode || '');
    var targetId = normalizeCf_(sourcePatient.identityMergedInto || sourcePatient.identityMaterializedInto || '');

    if (!sourceId || !targetId) {
      result.invalidSources++;
      result.sourcePatientsProcessed++;
      identityResolutionRequestsAddSample_(result.samples.skipped, {
        sourceId: sourceId,
        targetId: targetId,
        reason: 'missing_source_or_target'
      }, maxSamples);
      continue;
    }

    if (String(sourcePatient.identityMaterializationStatus || '').trim() === 'materialized') {
      result.sourcePatientsSkippedAlreadyMaterialized++;
      continue;
    }

    if (!auditPatientIdentityIsTmp_(sourceId)) {
      result.blockedSourceNotTmp++;
      result.sourcePatientsProcessed++;
      if (!materializeRecordSourceBlock_(cfg, result, dryRun, maxWrites, sourceId, 'blocked_source_not_tmp', nowIso, maxSamples, {
        sourceId: sourceId,
        targetId: targetId,
        reason: 'source_not_tmp_delete_blocked'
      })) break;
      continue;
    }

    if (!identityResolutionRequestsIsSafeRealCf_(targetId)) {
      result.targetInvalid++;
      result.sourcePatientsProcessed++;
      if (!materializeRecordSourceBlock_(cfg, result, dryRun, maxWrites, sourceId, 'blocked_target_not_safe_cf', nowIso, maxSamples, {
        sourceId: sourceId,
        targetId: targetId,
        reason: 'target_not_safe_canonical_cf'
      })) break;
      continue;
    }

    var targetPatient = identityResolutionRequestsGetPatientOrNull_(cfg, targetId);
    if (!targetPatient) {
      result.targetMissing++;
      result.sourcePatientsProcessed++;
      identityResolutionRequestsAddSample_(result.samples.skipped, {
        sourceId: sourceId,
        targetId: targetId,
        reason: 'target_patient_missing_deferred'
      }, maxSamples);
      continue;
    }

    var plan = materializeBuildSourcePlan_(cfg, sourcePatient, targetPatient, sourceId, targetId, nowIso, maxDocsPerSource, maxSamples);
    result.sourcePatientsProcessed++;

    if (plan.blocked) {
      if (plan.blockReason === 'target_document_collision') {
        result.blockedTargetCollisions++;
        identityResolutionRequestsAddSample_(result.samples.collisions, plan.sample, maxSamples);
      } else if (plan.blockReason === 'scan_truncated') {
        result.blockedScanTruncated++;
        identityResolutionRequestsAddSample_(result.samples.skipped, plan.sample, maxSamples);
      } else {
        result.blockedConflicts++;
        identityResolutionRequestsAddSample_(result.samples.conflicts, plan.sample, maxSamples);
      }
      if (!materializeRecordSourceBlock_(cfg, result, dryRun, maxWrites, sourceId, 'blocked_' + String(plan.blockReason || 'conflict'), nowIso, maxSamples, plan.sample)) break;
      continue;
    }

    if (plan.writes.length > maxWrites) {
      result.blockedPlanTooLarge++;
      if (!materializeRecordSourceBlock_(cfg, result, dryRun, maxWrites, sourceId, 'blocked_plan_exceeds_max_writes', nowIso, maxSamples, {
        sourceId: sourceId,
        targetId: targetId,
        writesPlanned: plan.writes.length,
        maxWrites: maxWrites,
        reason: 'single_source_plan_exceeds_max_writes'
      })) break;
      continue;
    }

    if (!identityResolutionRequestsCanConsumeWrites_(result, dryRun, maxWrites, plan.writes.length)) {
      break;
    }

    result.documentsMoved += plan.counts.documentsMoved;
    result.topLevelDocumentsPatched += plan.counts.topLevelDocumentsPatched;
    result.familyGroupsPatched += plan.counts.familyGroupsPatched;
    result.dashboardIndexesPatched += plan.counts.dashboardIndexesPatched;
    result.dashboardIndexesDeleted += plan.counts.dashboardIndexesDeleted;
    result.therapeuticAdviceMoved += plan.counts.therapeuticAdviceMoved;
    result.doctorLinksMoved += plan.counts.doctorLinksMoved;
    result.doctorLinkDuplicatesRemoved += plan.counts.doctorLinkDuplicatesRemoved;

    if (dryRun) {
      result.writesPlanned += plan.writes.length;
      identityResolutionRequestsAddSample_(result.samples.planned, plan.sample, maxSamples);
      continue;
    }

    executeFirestoreCommit_(cfg, plan.writes);
    result.writesAttempted += plan.writes.length;
    result.writesSucceeded += plan.writes.length;
    result.firestoreWritesDelta += plan.writes.length;
    result.sourcePatientsMaterialized++;
    if (plan.sourceDeleted) result.sourcePatientsDeleted++;
    identityResolutionRequestsAddSample_(result.samples.applied, plan.sample, maxSamples);
  }

  materializePersistMergedSourceCursor_(cfg, result, dryRun, maxWrites, sourceScan, nowIso);

  result.checkedAt = new Date().toISOString();
  logInfo_(cfg, 'processMaterializePatientIdentityMerges completato', result);
  return result;
}

function materializePersistMergedSourceCursor_(cfg, result, dryRun, maxWrites, sourceScan, nowIso) {
  if (!sourceScan || !sourceScan.cursorShouldPersist) return;
  if (result.maxWritesReached) return;
  result.sourceCursorWritePlanned = true;
  if (dryRun) {
    result.sourceCursorWriteSkippedDryRun = true;
    return;
  }
  if (!identityResolutionRequestsCanConsumeWrites_(result, false, maxWrites, 1)) return;
  var nextDocumentName = sourceScan.cursorReset ? '' : String(sourceScan.cursorNextDocumentName || '');
  executeFirestoreCommit_(cfg, [buildFirestorePatchWrite_(cfg, 'phbox_runtime', 'patient_identity_materializer_cursor', {
    materializer: 'patient_identity_materializer',
    cursorVersion: 1,
    mergedSourceCursorDocumentName: nextDocumentName,
    mergedSourceCursorSourceId: sourceScan.cursorReset ? '' : String(sourceScan.lastScannedSourceId || ''),
    mergedSourceCursorReset: !!sourceScan.cursorReset,
    mergedSourceCursorWrapped: !!sourceScan.cursorWrapped,
    mergedSourceCursorUpdatedAt: nowIso,
    updatedAt: nowIso
  }, [
    'materializer',
    'cursorVersion',
    'mergedSourceCursorDocumentName',
    'mergedSourceCursorSourceId',
    'mergedSourceCursorReset',
    'mergedSourceCursorWrapped',
    'mergedSourceCursorUpdatedAt',
    'updatedAt'
  ])]);
  result.writesAttempted++;
  result.writesSucceeded++;
  result.firestoreWritesDelta++;
  result.sourceCursorWriteApplied = true;
}

function materializeRecordSourceBlock_(cfg, result, dryRun, maxWrites, sourceId, status, nowIso, maxSamples, sample) {
  if (!identityResolutionRequestsCanConsumeWrites_(result, dryRun, maxWrites, 1)) return false;
  result.blockedStatusWritesPlanned++;
  identityResolutionRequestsAddSample_(result.samples.blocked, sample || { sourceId: sourceId, reason: status }, maxSamples);
  if (dryRun) {
    result.writesPlanned++;
    return true;
  }
  executeFirestoreCommit_(cfg, [buildFirestorePatchWrite_(cfg, 'patients', sourceId, {
    identityMaterializationStatus: status,
    identityMaterializationBlockedAt: nowIso,
    identityMaterializationBlockReason: String(sample && sample.reason || status),
    updatedAt: nowIso
  }, [
    'identityMaterializationStatus',
    'identityMaterializationBlockedAt',
    'identityMaterializationBlockReason',
    'updatedAt'
  ])]);
  result.writesAttempted++;
  result.writesSucceeded++;
  result.firestoreWritesDelta++;
  result.blockedStatusWritesApplied++;
  return true;
}

function materializeBuildSourcePlan_(cfg, sourcePatient, targetPatient, sourceId, targetId, nowIso, maxDocsPerSource, maxSamples) {
  var targetFullName = String(targetPatient.fullName || targetPatient.patientFullName || targetId).trim() || targetId;
  var writes = [];
  var counts = {
    documentsMoved: 0,
    topLevelDocumentsPatched: 0,
    familyGroupsPatched: 0,
    dashboardIndexesPatched: 0,
    dashboardIndexesDeleted: 0,
    therapeuticAdviceMoved: 0,
    doctorLinksMoved: 0,
    doctorLinkDuplicatesRemoved: 0
  };
  var affected = {
    drivePdfImports: 0,
    prescriptionIntakes: 0,
    debts: 0,
    advances: 0,
    bookings: 0,
    prescriptions: 0,
    doctorLinks: 0,
    families: 0,
    therapeuticAdvice: 0,
    dashboardIndexes: 0
  };

  var targetPatientPatch = materializeBuildTargetPatientAggregatePatch_(targetPatient, sourcePatient, sourceId, nowIso);
  writes.push(buildFirestorePatchWrite_(cfg, 'patients', targetId, targetPatientPatch, Object.keys(targetPatientPatch)));

  var driveImports = materializeListTopLevelWhereEqual_(cfg, 'drive_pdf_imports', 'patientFiscalCode', sourceId, maxDocsPerSource);
  if (materializeListHitLimit_(driveImports, maxDocsPerSource)) {
    return materializeBuildScanTruncatedBlock_(sourceId, targetId, 'drive_pdf_imports', maxDocsPerSource, counts);
  }
  materializeAppendTopLevelPatchWrites_(writes, driveImports, [
    'patientFiscalCode',
    'patientFullName',
    'updatedAt',
    'identityMaterializedFrom',
    'identityMaterializedAt'
  ], function () {
    return {
      patientFiscalCode: targetId,
      patientFullName: targetFullName,
      updatedAt: nowIso,
      identityMaterializedFrom: sourceId,
      identityMaterializedAt: nowIso
    };
  });
  affected.drivePdfImports = driveImports.length;
  counts.topLevelDocumentsPatched += driveImports.length;

  var intakes = materializeListTopLevelWhereEqual_(cfg, 'prescription_intakes', 'fiscalCode', sourceId, maxDocsPerSource);
  if (materializeListHitLimit_(intakes, maxDocsPerSource)) {
    return materializeBuildScanTruncatedBlock_(sourceId, targetId, 'prescription_intakes', maxDocsPerSource, counts);
  }
  materializeAppendTopLevelPatchWrites_(writes, intakes, [
    'fiscalCode',
    'patientName',
    'updatedAt',
    'identityMaterializedFrom',
    'identityMaterializedAt'
  ], function () {
    return {
      fiscalCode: targetId,
      patientName: targetFullName,
      updatedAt: nowIso,
      identityMaterializedFrom: sourceId,
      identityMaterializedAt: nowIso
    };
  });
  affected.prescriptionIntakes = intakes.length;
  counts.topLevelDocumentsPatched += intakes.length;

  var subcollections = ['debts', 'advances', 'bookings', 'prescriptions'];
  for (var i = 0; i < subcollections.length; i++) {
    var subcollection = subcollections[i];
    var docs = materializeListPatientSubcollection_(cfg, subcollection, sourceId, maxDocsPerSource);
    if (materializeListHitLimit_(docs, maxDocsPerSource)) {
      return materializeBuildScanTruncatedBlock_(sourceId, targetId, subcollection, maxDocsPerSource, counts);
    }
    affected[subcollection] = docs.length;
    var moveResult = materializeAppendSubcollectionMoveWrites_(writes, docs, subcollection, sourceId, targetId, targetFullName, nowIso);
    if (moveResult.collision) {
      return materializeBuildCollisionBlock_(sourceId, targetId, subcollection, moveResult.targetDocumentName, counts, 'target_subdocument_already_exists');
    }
    counts.documentsMoved += docs.length;
  }

  var doctorLinks = materializeListTopLevelWhereEqual_(cfg, 'doctor_patient_links', 'patientFiscalCode', sourceId, maxDocsPerSource);
  if (materializeListHitLimit_(doctorLinks, maxDocsPerSource)) {
    return materializeBuildScanTruncatedBlock_(sourceId, targetId, 'doctor_patient_links', maxDocsPerSource, counts);
  }
  affected.doctorLinks = doctorLinks.length;
  var linkResult = materializeAppendDoctorLinkMoveWrites_(cfg, writes, doctorLinks, sourceId, targetId, targetFullName, nowIso);
  if (linkResult.collision) {
    return materializeBuildCollisionBlock_(sourceId, targetId, 'doctor_patient_links', linkResult.targetDocumentName, counts, linkResult.reason || 'target_doctor_link_already_exists');
  }
  counts.doctorLinksMoved += linkResult.movedCount || 0;
  counts.doctorLinkDuplicatesRemoved += linkResult.duplicateRemovedCount || 0;

  var therapeuticResult = materializeAppendTherapeuticAdviceMoveWrites_(cfg, writes, sourceId, targetId, nowIso);
  if (therapeuticResult.conflict) {
    return {
      blocked: true,
      blockReason: 'therapeutic_advice_conflict',
      writes: [],
      sourceDeleted: false,
      counts: counts,
      sample: {
        sourceId: sourceId,
        targetId: targetId,
        reason: 'source_and_target_therapeutic_advice_exist'
      }
    };
  }
  if (therapeuticResult.moved) {
    affected.therapeuticAdvice = 1;
    counts.therapeuticAdviceMoved++;
  }

  var families = materializeListFamiliesContaining_(cfg, sourceId, maxDocsPerSource);
  if (materializeListHitLimit_(families, maxDocsPerSource)) {
    return materializeBuildScanTruncatedBlock_(sourceId, targetId, 'families', maxDocsPerSource, counts);
  }
  affected.families = families.length;
  materializeAppendFamilyRewriteWrites_(writes, families, sourceId, targetId, nowIso);
  counts.familyGroupsPatched += families.length;

  var sourceIndex = materializeGetTopLevelDocumentOrNull_(cfg, 'patient_dashboard_index', sourceId);
  var targetIndex = materializeGetTopLevelDocumentOrNull_(cfg, 'patient_dashboard_index', targetId) || {};
  var targetIndexPatch = materializeBuildTargetIndexPatch_(targetIndex, sourceIndex, targetPatient, sourceId, targetId, nowIso);
  writes.push(buildFirestorePatchWrite_(cfg, 'patient_dashboard_index', targetId, targetIndexPatch, Object.keys(targetIndexPatch)));
  counts.dashboardIndexesPatched++;
  if (sourceIndex) {
    writes.push(buildFirestoreDeleteWrite_(cfg, 'patient_dashboard_index', sourceId));
    counts.dashboardIndexesDeleted++;
    affected.dashboardIndexes = 1;
  }

  writes.push(buildFirestoreDeleteWrite_(cfg, 'patients', sourceId));
  var sourceDeleted = true;

  return {
    blocked: false,
    writes: writes,
    sourceDeleted: sourceDeleted,
    counts: counts,
    sample: {
      sourceId: sourceId,
      targetId: targetId,
      targetFullName: targetFullName,
      writesPlanned: writes.length,
      sourceDeleted: sourceDeleted,
      affected: affected
    }
  };
}

function materializeBuildCollisionBlock_(sourceId, targetId, collection, targetDocumentName, counts, reason) {
  return {
    blocked: true,
    blockReason: 'target_document_collision',
    writes: [],
    sourceDeleted: false,
    counts: counts,
    sample: {
      sourceId: sourceId,
      targetId: targetId,
      collection: collection,
      targetDocumentName: targetDocumentName,
      reason: reason
    }
  };
}

function materializeListHitLimit_(items, limit) {
  return Array.isArray(items) && items.length >= Math.max(1, Number(limit || 1));
}

function materializeBuildScanTruncatedBlock_(sourceId, targetId, collection, limit, counts) {
  return {
    blocked: true,
    blockReason: 'scan_truncated',
    writes: [],
    sourceDeleted: false,
    counts: counts,
    sample: {
      sourceId: sourceId,
      targetId: targetId,
      collection: collection,
      limit: limit,
      reason: 'source_related_documents_scan_reached_limit_fail_closed'
    }
  };
}

function materializeListMergedSourcePatients_(cfg, maxSourceScan, maxSources) {
  var pageSize = 50;
  var scanned = 0;
  var rawScanned = 0;
  var maxRawScan = Math.max(pageSize, Math.max(1, Number(maxSourceScan || 1)) * 20);
  var targetSources = Math.max(1, Number(maxSources || maxSourceScan || 1));
  var cursor = materializeReadMergedSourceCursor_(cfg);
  var cursorPreviousDocumentName = String(cursor.mergedSourceCursorDocumentName || '');
  var startAfterDocumentName = cursorPreviousDocumentName;
  var lastDocumentName = '';
  var lastScannedSourceId = '';
  var items = [];
  var skippedAlreadyMaterialized = 0;
  var skippedBlocked = 0;
  var scanLimitReached = false;
  var cursorShouldPersist = false;
  var cursorReset = false;
  var cursorWrapped = false;

  while (scanned < maxSourceScan && items.length < targetSources && rawScanned < maxRawScan) {
    var remainingRaw = maxRawScan - rawScanned;
    var limit = Math.min(pageSize, remainingRaw);
    var page = materializeRunMergedSourcesPage_(cfg, limit, startAfterDocumentName);
    if (!page.length) {
      if (startAfterDocumentName && !cursorWrapped) {
        startAfterDocumentName = '';
        cursorWrapped = true;
        cursorReset = true;
        cursorShouldPersist = true;
        continue;
      }
      cursorReset = true;
      cursorShouldPersist = true;
      break;
    }

    for (var i = 0; i < page.length; i++) {
      var item = page[i] || {};
      rawScanned++;
      lastDocumentName = String(item.documentName || lastDocumentName || '');
      lastScannedSourceId = normalizeCf_(item.documentId || item.fiscalCode || item.patientFiscalCode || lastScannedSourceId);
      var status = String(item.identityMaterializationStatus || '').trim();
      if (status === 'materialized') {
        skippedAlreadyMaterialized++;
      } else if (status.indexOf('blocked_') === 0) {
        skippedBlocked++;
      } else {
        scanned++;
        items.push(item);
      }
      if (scanned >= maxSourceScan || items.length >= targetSources || rawScanned >= maxRawScan) break;
    }

    if (page.length < limit) {
      cursorReset = true;
      cursorShouldPersist = true;
      break;
    }
    if (lastDocumentName) startAfterDocumentName = lastDocumentName;
  }

  if (scanned >= maxSourceScan || rawScanned >= maxRawScan) scanLimitReached = true;
  if (rawScanned >= maxRawScan && lastDocumentName) {
    cursorShouldPersist = true;
    cursorReset = false;
  }
  if (items.length >= targetSources && lastDocumentName) {
    cursorShouldPersist = true;
    cursorReset = false;
  }

  return {
    items: items,
    scanned: scanned,
    rawScanned: rawScanned,
    skippedAlreadyMaterialized: skippedAlreadyMaterialized,
    skippedBlocked: skippedBlocked,
    scanLimitReached: scanLimitReached,
    lastScannedSourceId: lastScannedSourceId,
    cursorPreviousDocumentName: cursorPreviousDocumentName,
    cursorNextDocumentName: cursorReset ? '' : String(lastDocumentName || ''),
    cursorShouldPersist: cursorShouldPersist,
    cursorReset: cursorReset,
    cursorWrapped: cursorWrapped
  };
}

function materializeReadMergedSourceCursor_(cfg) {
  var cursor = materializeGetDocumentByNameOrNull_(buildFirestoreDocumentName_(cfg, 'phbox_runtime', 'patient_identity_materializer_cursor'));
  if (!cursor) return {};
  return cursor;
}

function materializeRunMergedSourcesPage_(cfg, limit, startAfterDocumentName) {
  var query = {
    from: [{ collectionId: 'patients' }],
    where: {
      fieldFilter: {
        field: { fieldPath: 'identityMergeStatus' },
        op: 'EQUAL',
        value: { stringValue: 'merged_into' }
      }
    },
    orderBy: [{
      field: { fieldPath: '__name__' },
      direction: 'ASCENDING'
    }],
    limit: Math.max(1, Number(limit || 1))
  };
  if (startAfterDocumentName) {
    query.startAt = {
      values: [{ referenceValue: startAfterDocumentName }],
      before: false
    };
  }
  return materializeRunQuery_(cfg, { structuredQuery: query });
}

function materializeListTopLevelWhereEqual_(cfg, collectionId, fieldPath, value, limit) {
  return materializeRunQuery_(cfg, {
    structuredQuery: {
      from: [{ collectionId: collectionId }],
      where: {
        fieldFilter: {
          field: { fieldPath: fieldPath },
          op: 'EQUAL',
          value: { stringValue: String(value || '') }
        }
      },
      limit: Math.max(1, Number(limit || 1))
    }
  });
}

function materializeListPatientSubcollection_(cfg, collectionId, sourceId, limit) {
  var safeSourceId = normalizeCf_(sourceId);
  if (!safeSourceId) return [];
  var pageSize = Math.max(1, Number(limit || 1));
  var url = 'https://firestore.googleapis.com/v1/projects/' + encodeURIComponent(cfg.firestoreProjectId) +
    '/databases/(default)/documents/patients/' + encodeURIComponent(safeSourceId) + '/' +
    encodeURIComponent(collectionId) + '?pageSize=' + encodeURIComponent(pageSize);
  var response = UrlFetchApp.fetch(url, {
    method: 'get',
    muteHttpExceptions: true,
    headers: {
      Authorization: 'Bearer ' + ScriptApp.getOAuthToken()
    }
  });
  var code = response.getResponseCode();
  if (code === 404) return [];
  var body = response.getContentText() || '';
  if (code < 200 || code >= 300) {
    throw new Error('Firestore list patient subcollection materialize identity failed [' + code + '] ' + body);
  }
  var parsed = parseJsonSafe_(body || '{}');
  var docs = Array.isArray(parsed && parsed.documents) ? parsed.documents : [];
  return docs.map(function (document) {
    var data = fromFirestoreFields_((document && document.fields) || {});
    data.documentName = (document && document.name) || '';
    data.documentId = extractFirestoreDocumentId_(data.documentName || '');
    data.updateTime = (document && document.updateTime) || '';
    return data;
  }).filter(function (item) {
    return !!(item && item.documentName);
  });
}

function materializeListFamiliesContaining_(cfg, sourceId, limit) {
  return materializeRunQuery_(cfg, {
    structuredQuery: {
      from: [{ collectionId: 'families' }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'memberFiscalCodes' },
          op: 'ARRAY_CONTAINS',
          value: { stringValue: sourceId }
        }
      },
      limit: Math.max(1, Number(limit || 1))
    }
  });
}

function materializeRunQuery_(cfg, payload) {
  var url = 'https://firestore.googleapis.com/v1/projects/' + encodeURIComponent(cfg.firestoreProjectId) + '/databases/(default)/documents:runQuery';
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
    throw new Error('Firestore runQuery materialize identity failed [' + code + '] ' + body);
  }
  var parsed = parseJsonSafe_(body);
  if (!Array.isArray(parsed)) return [];
  return parsed.map(function (row) {
    if (!row || !row.document) return null;
    var document = row.document;
    var data = fromFirestoreFields_(document.fields || {});
    data.documentName = document.name || '';
    data.documentId = extractFirestoreDocumentId_(document.name || '');
    data.updateTime = document.updateTime || '';
    return data;
  }).filter(function (item) {
    return !!item;
  });
}

function materializeGetTopLevelDocumentOrNull_(cfg, collectionId, documentId) {
  var normalizedId = normalizeCf_(documentId);
  if (!normalizedId) return null;
  return materializeGetDocumentByNameOrNull_(buildFirestoreDocumentName_(cfg, collectionId, normalizedId));
}

function materializeGetDocumentByNameOrNull_(documentName) {
  var url = 'https://firestore.googleapis.com/v1/' + String(documentName || '');
  var response = UrlFetchApp.fetch(url, {
    method: 'get',
    muteHttpExceptions: true,
    headers: {
      Authorization: 'Bearer ' + ScriptApp.getOAuthToken()
    }
  });
  var code = response.getResponseCode();
  if (code === 404) return null;
  if (code < 200 || code >= 300) {
    throw new Error('Firestore GET materialize identity failed [' + code + '] ' + response.getContentText());
  }
  var parsed = parseJsonSafe_(response.getContentText() || '{}');
  var data = fromFirestoreFields_((parsed && parsed.fields) || {});
  data.documentName = parsed.name || documentName;
  data.documentId = extractFirestoreDocumentId_(data.documentName || '');
  data.updateTime = parsed.updateTime || '';
  return data;
}

function materializeAppendTopLevelPatchWrites_(writes, docs, fieldPaths, patchFactory) {
  for (var i = 0; i < docs.length; i++) {
    var doc = docs[i] || {};
    if (!doc.documentName) continue;
    writes.push(materializeBuildPatchWriteByName_(doc.documentName, patchFactory(doc), fieldPaths));
  }
}

function materializeAppendSubcollectionMoveWrites_(writes, docs, subcollection, sourceId, targetId, targetFullName, nowIso) {
  for (var i = 0; i < docs.length; i++) {
    var doc = docs[i] || {};
    var sourceName = String(doc.documentName || '').trim();
    if (!sourceName) continue;
    var targetName = materializeRetargetPatientSubdocumentName_(sourceName, sourceId, targetId);
    if (!targetName || materializeGetDocumentByNameOrNull_(targetName)) {
      return { collision: true, targetDocumentName: targetName };
    }
    var nextData = materializeCleanDocumentForCopy_(doc);
    nextData.patientFiscalCode = targetId;
    nextData.patientName = targetFullName;
    nextData.updatedAt = nowIso;
    nextData.identityMaterializedFrom = sourceId;
    nextData.identityMaterializedAt = nowIso;
    writes.push(materializeBuildCreateOnlyWriteByName_(targetName, nextData));
    writes.push(materializeBuildDeleteWriteByName_(sourceName));
  }
  return { collision: false };
}

function materializeAppendDoctorLinkMoveWrites_(cfg, writes, docs, sourceId, targetId, targetFullName, nowIso) {
  var movedCount = 0;
  var duplicateRemovedCount = 0;
  for (var i = 0; i < docs.length; i++) {
    var doc = docs[i] || {};
    var sourceName = String(doc.documentName || '').trim();
    if (!sourceName) continue;
    var sourceDocId = extractFirestoreDocumentId_(sourceName);
    var targetDocId = materializeRetargetDoctorLinkId_(sourceDocId, sourceId, targetId);
    var targetName = buildFirestoreDocumentName_(cfg, 'doctor_patient_links', targetDocId);
    var targetLink = materializeGetDocumentByNameOrNull_(targetName);
    if (targetLink) {
      if (materializeDoctorLinksEquivalent_(doc, targetLink)) {
        writes.push(materializeBuildDeleteWriteByName_(sourceName));
        duplicateRemovedCount++;
        continue;
      }
      return {
        collision: true,
        targetDocumentName: targetName,
        reason: 'doctor_link_conflict_requires_user_choice'
      };
    }
    var nextData = materializeCleanDocumentForCopy_(doc);
    nextData.id = targetDocId;
    nextData.patientFiscalCode = targetId;
    nextData.patientFullName = targetFullName;
    nextData.updatedAt = nowIso;
    nextData.identityMaterializedFrom = sourceId;
    nextData.identityMaterializedAt = nowIso;
    writes.push(materializeBuildCreateOnlyWriteByName_(targetName, nextData));
    writes.push(materializeBuildDeleteWriteByName_(sourceName));
    movedCount++;
  }
  return {
    collision: false,
    movedCount: movedCount,
    duplicateRemovedCount: duplicateRemovedCount
  };
}

function materializeDoctorLinksEquivalent_(sourceLink, targetLink) {
  var sourceDoctorId = identityMergeComparableString_(sourceLink && (sourceLink.doctorId || sourceLink.doctorFiscalCode || sourceLink.medicalDoctorId));
  var targetDoctorId = identityMergeComparableString_(targetLink && (targetLink.doctorId || targetLink.doctorFiscalCode || targetLink.medicalDoctorId));
  if (sourceDoctorId && targetDoctorId) {
    return sourceDoctorId === targetDoctorId;
  }

  var sourceDoctor = materializeDoctorLinkComparableDoctor_(sourceLink);
  var targetDoctor = materializeDoctorLinkComparableDoctor_(targetLink);
  return !!sourceDoctor && !!targetDoctor && sourceDoctor === targetDoctor;
}

function materializeDoctorLinkComparableDoctor_(link) {
  var fullName = identityMergeComparableString_(link && (link.doctorFullName || link.doctorDisplayName || link.doctor || link.medico));
  if (fullName) return fullName;

  var surname = identityMergeComparableString_(link && link.doctorSurname);
  var name = identityMergeComparableString_(link && link.doctorName);
  return identityMergeComparableString_((surname + ' ' + name).trim());
}

function materializeAppendTherapeuticAdviceMoveWrites_(cfg, writes, sourceId, targetId, nowIso) {
  var sourceName = buildFirestoreDocumentName_(cfg, 'patient_therapeutic_advice', sourceId);
  var sourceAdvice = materializeGetDocumentByNameOrNull_(sourceName);
  if (!sourceAdvice) return { moved: false, conflict: false };
  var targetName = buildFirestoreDocumentName_(cfg, 'patient_therapeutic_advice', targetId);
  var targetAdvice = materializeGetDocumentByNameOrNull_(targetName);
  if (targetAdvice) return { moved: false, conflict: true };
  var nextData = materializeCleanDocumentForCopy_(sourceAdvice);
  nextData.patientFiscalCode = targetId;
  nextData.updatedAt = nowIso;
  nextData.identityMaterializedFrom = sourceId;
  nextData.identityMaterializedAt = nowIso;
  writes.push(materializeBuildCreateOnlyWriteByName_(targetName, nextData));
  writes.push(materializeBuildDeleteWriteByName_(sourceName));
  return { moved: true, conflict: false };
}

function materializeAppendFamilyRewriteWrites_(writes, families, sourceId, targetId, nowIso) {
  for (var i = 0; i < families.length; i++) {
    var family = families[i] || {};
    if (!family.documentName) continue;
    var members = Array.isArray(family.memberFiscalCodes) ? family.memberFiscalCodes : [];
    var nextMembersMap = {};
    for (var j = 0; j < members.length; j++) {
      var member = normalizeCf_(members[j]);
      if (!member) continue;
      nextMembersMap[member === sourceId ? targetId : member] = true;
    }
    var nextMembers = Object.keys(nextMembersMap).sort();
    writes.push(materializeBuildPatchWriteByName_(family.documentName, {
      memberFiscalCodes: nextMembers,
      updatedAt: nowIso,
      identityMaterializedFrom: sourceId,
      identityMaterializedAt: nowIso
    }, ['memberFiscalCodes', 'updatedAt', 'identityMaterializedFrom', 'identityMaterializedAt']));
  }
}

function materializeBuildTargetPatientAggregatePatch_(targetPatient, sourcePatient, sourceId, nowIso) {
  var existingSources = Array.isArray(targetPatient.identityMaterializedSourceIds)
      ? targetPatient.identityMaterializedSourceIds.map(function (item) { return normalizeCf_(item); })
      : [];
  var sourceMap = {};
  for (var i = 0; i < existingSources.length; i++) {
    if (existingSources[i]) sourceMap[existingSources[i]] = true;
  }
  sourceMap[sourceId] = true;
  return {
    fiscalCode: normalizeCf_(targetPatient.fiscalCode || targetPatient.documentId || ''),
    hasDebt: materializeBoolOr_(targetPatient.hasDebt, sourcePatient.hasDebt),
    hasAdvance: materializeBoolOr_(targetPatient.hasAdvance, sourcePatient.hasAdvance),
    hasBooking: materializeBoolOr_(targetPatient.hasBooking, sourcePatient.hasBooking),
    hasDpc: materializeBoolOr_(targetPatient.hasDpc, sourcePatient.hasDpc),
    debtTotal: materializeNumber_(targetPatient.debtTotal) + materializeNumber_(sourcePatient.debtTotal),
    archivedRecipeCount: materializeInt_(targetPatient.archivedRecipeCount) + materializeInt_(sourcePatient.archivedRecipeCount),
    archivedPdfCount: materializeInt_(targetPatient.archivedPdfCount) + materializeInt_(sourcePatient.archivedPdfCount),
    activeArchiveDocuments: materializeInt_(targetPatient.activeArchiveDocuments) + materializeInt_(sourcePatient.activeArchiveDocuments),
    identityMaterializedAt: nowIso,
    identityMaterializedSourceIds: Object.keys(sourceMap).sort(),
    updatedAt: nowIso
  };
}

function materializeBuildTargetIndexPatch_(targetIndex, sourceIndex, targetPatient, sourceId, targetId, nowIso) {
  sourceIndex = sourceIndex || {};
  targetIndex = targetIndex || {};
  var fullName = materializeBestPatientDisplayName_(targetIndex, targetPatient, sourceIndex, targetId);
  var alias = String(targetIndex.alias || targetPatient.alias || '').trim();
  var doctorFullName = String(targetIndex.doctorFullName || targetPatient.doctorFullName || targetPatient.doctorName || '').trim();
  var city = String(targetIndex.city || targetPatient.city || '').trim();
  var exemptionCode = String(targetIndex.exemptionCode || targetPatient.exemptionCode || '').trim();
  var exemptions = materializeMergeStringArrays_(targetIndex.exemptions, targetPatient.exemptions || []);
  if (exemptionCode) exemptions = materializeMergeStringArrays_([exemptionCode], exemptions);
  var recipeCount = materializeInt_(targetIndex.recipeCount) + materializeInt_(sourceIndex.recipeCount);
  var dpcCount = materializeInt_(targetIndex.dpcCount) + materializeInt_(sourceIndex.dpcCount);
  var debtCount = materializeInt_(targetIndex.debtCount) + materializeInt_(sourceIndex.debtCount);
  var debtAmount = materializeNumber_(targetIndex.debtAmount) + materializeNumber_(sourceIndex.debtAmount);
  var advanceCount = materializeInt_(targetIndex.advanceCount) + materializeInt_(sourceIndex.advanceCount);
  var bookingCount = materializeInt_(targetIndex.bookingCount) + materializeInt_(sourceIndex.bookingCount);
  return {
    schemaVersion: 1,
    fiscalCode: targetId,
    fullName: fullName,
    alias: alias || null,
    doctorFullName: doctorFullName,
    city: city,
    exemptionCode: exemptionCode,
    exemptions: exemptions,
    recipeCount: recipeCount,
    dpcCount: dpcCount,
    debtCount: debtCount,
    debtAmount: debtAmount,
    advanceCount: advanceCount,
    bookingCount: bookingCount,
    hasRecipes: materializeBoolOr_(targetIndex.hasRecipes, sourceIndex.hasRecipes) || recipeCount > 0,
    hasDpc: materializeBoolOr_(targetIndex.hasDpc, sourceIndex.hasDpc) || dpcCount > 0,
    hasDebt: materializeBoolOr_(targetIndex.hasDebt, sourceIndex.hasDebt) || debtCount > 0 || Math.abs(debtAmount) > 0.005,
    hasAdvance: materializeBoolOr_(targetIndex.hasAdvance, sourceIndex.hasAdvance) || advanceCount > 0,
    hasBooking: materializeBoolOr_(targetIndex.hasBooking, sourceIndex.hasBooking) || bookingCount > 0,
    hasExpiry: materializeBoolOr_(targetIndex.hasExpiry, sourceIndex.hasExpiry),
    nearestExpiryDate: materializeEarlierDateString_(targetIndex.nearestExpiryDate, sourceIndex.nearestExpiryDate),
    lastPrescriptionDate: materializeLaterDateString_(targetIndex.lastPrescriptionDate, sourceIndex.lastPrescriptionDate),
    identityMaterializedAt: nowIso,
    identityMaterializedSourceIds: materializeMergeStringArrays_(targetIndex.identityMaterializedSourceIds, [sourceId]),
    searchPrefixes: buildPatientDashboardSearchPrefixes_([targetId, fullName, alias, doctorFullName, city, exemptionCode].concat(exemptions)),
    updatedAt: nowIso
  };
}


function materializeBestPatientDisplayName_(targetIndex, targetPatient, sourceIndex, targetId) {
  var targetCf = normalizeCf_(targetId);
  var canonicalName = materializeCanonicalPatientDisplayName_(targetPatient, targetCf);
  if (!materializeIsPlaceholderPatientName_(canonicalName, targetCf)) {
    return canonicalName;
  }
  var candidates = [
    targetIndex && targetIndex.fullName,
    targetIndex && targetIndex.patientFullName,
    sourceIndex && sourceIndex.fullName,
    sourceIndex && sourceIndex.patientFullName
  ];
  for (var i = 0; i < candidates.length; i++) {
    var name = materializeNormalizeDisplayNameCandidate_(candidates[i]);
    if (name && !materializeIsPlaceholderPatientName_(name, targetCf)) {
      return name;
    }
  }
  return targetCf || String(targetId || '').trim();
}

function materializeCanonicalPatientDisplayName_(patient, fiscalCode) {
  var targetCf = normalizeCf_(fiscalCode);
  var directCandidates = [
    patient && patient.fullName,
    patient && patient.patientFullName,
    patient && patient.displayName,
    patient && patient.patientName
  ];
  for (var i = 0; i < directCandidates.length; i++) {
    var directName = materializeNormalizeDisplayNameCandidate_(directCandidates[i]);
    if (directName && !materializeIsPlaceholderPatientName_(directName, targetCf)) {
      return directName;
    }
  }

  var firstNameCandidates = [
    patient && patient.name,
    patient && patient.firstName,
    patient && patient.givenName,
    patient && patient.nome,
    patient && patient.patientFirstName,
    patient && patient.patientGivenName
  ];
  var lastNameCandidates = [
    patient && patient.surname,
    patient && patient.lastName,
    patient && patient.familyName,
    patient && patient.cognome,
    patient && patient.patientLastName,
    patient && patient.patientSurname,
    patient && patient.patientFamilyName
  ];
  for (var j = 0; j < firstNameCandidates.length; j++) {
    var firstName = materializeNormalizeDisplayNameCandidate_(firstNameCandidates[j]);
    if (!firstName || materializeIsPlaceholderPatientName_(firstName, targetCf)) continue;
    for (var k = 0; k < lastNameCandidates.length; k++) {
      var lastName = materializeNormalizeDisplayNameCandidate_(lastNameCandidates[k]);
      if (!lastName || materializeIsPlaceholderPatientName_(lastName, targetCf)) continue;
      var combinedName = materializeNormalizeDisplayNameCandidate_(firstName + ' ' + lastName);
      if (combinedName && !materializeIsPlaceholderPatientName_(combinedName, targetCf)) {
        return combinedName;
      }
    }
  }

  return targetCf || String(fiscalCode || '').trim();
}

function materializeNormalizeDisplayNameCandidate_(value) {
  return String(value == null ? '' : value).trim().replace(/\s+/g, ' ');
}

function materializeIsPlaceholderPatientName_(value, fiscalCode) {
  var name = materializeNormalizeDisplayNameCandidate_(value);
  if (!name) return true;
  var comparableName = identityMergeComparableString_(name);
  var cf = normalizeCf_(fiscalCode);
  if (cf && comparableName === cf) return true;
  if (auditPatientIdentityIsTmp_(comparableName)) return true;
  if (comparableName === 'ASSISTITO SENZA NOME') return true;
  if (comparableName === 'SENZA NOME') return true;
  return false;
}

function dryRunRepairMaterializedPatientDashboardIndexNames() {
  return processRepairMaterializedPatientDashboardIndexNames({
    dryRun: true,
    maxRows: 500,
    maxWrites: 25,
    maxSamples: 30
  });
}

function runRepairMaterializedPatientDashboardIndexNamesBatch() {
  return processRepairMaterializedPatientDashboardIndexNames({
    dryRun: false,
    applyToken: 'REPAIR_MATERIALIZED_PATIENT_DASHBOARD_NAMES',
    maxRows: 500,
    maxWrites: 25,
    maxSamples: 30
  });
}

function processRepairMaterializedPatientDashboardIndexNames(options) {
  options = options || {};
  var cfg = getPhboxConfig_();
  var startedAt = new Date().toISOString();
  var dryRun = options.dryRun !== false;
  var applyToken = String(options.applyToken || '').trim();
  var maxRows = identityResolutionRequestsBoundedInt_(options.maxRows, 500, 1, 1000);
  var maxWrites = identityResolutionRequestsBoundedInt_(options.maxWrites, 25, 1, 100);
  var maxSamples = identityResolutionRequestsBoundedInt_(options.maxSamples, 30, 1, 100);
  var nowIso = new Date().toISOString();

  if (!dryRun && applyToken !== 'REPAIR_MATERIALIZED_PATIENT_DASHBOARD_NAMES') {
    var blocked = {
      ok: false,
      mode: 'repair_materialized_patient_dashboard_names_blocked',
      source: 'patient_identity_materializer',
      dryRun: false,
      startedAt: startedAt,
      checkedAt: new Date().toISOString(),
      reason: 'blocked_missing_apply_token',
      writesAttempted: 0,
      writesSucceeded: 0,
      firestoreWritesDelta: 0
    };
    logInfo_(cfg, 'processRepairMaterializedPatientDashboardIndexNames bloccato', blocked);
    return blocked;
  }

  var repairScan = materializeListDashboardIndexRowsForNameRepair_(cfg, maxRows);
  var rows = repairScan.items || [];
  var result = {
    ok: true,
    mode: dryRun ? 'repair_materialized_patient_dashboard_names_dry_run' : 'repair_materialized_patient_dashboard_names_apply',
    source: 'patient_identity_materializer',
    dryRun: dryRun,
    startedAt: startedAt,
    checkedAt: '',
    maxRows: maxRows,
    maxWrites: maxWrites,
    maxSamples: maxSamples,
    rowsScanned: rows.length,
    rowsRawScanned: repairScan.rawScanned || rows.length,
    rowsScanLimitReached: !!repairScan.scanLimitReached,
    repairCursorPreviousDocumentName: String(repairScan.cursorPreviousDocumentName || ''),
    repairCursorNextDocumentName: String(repairScan.cursorNextDocumentName || ''),
    repairCursorShouldPersist: !!repairScan.cursorShouldPersist,
    repairCursorReset: !!repairScan.cursorReset,
    repairCursorWrapped: !!repairScan.cursorWrapped,
    repairCursorWritePlanned: false,
    repairCursorWriteApplied: false,
    repairCursorWriteSkippedDryRun: false,
    rowsNeedingRepair: 0,
    patientDocsRead: 0,
    backendNameSourceDocsRead: 0,
    repairedFromPatients: 0,
    repairedFromDrivePdfImports: 0,
    repairedFromPrescriptionIntakes: 0,
    skippedNameSourceConflict: 0,
    repairsPlanned: 0,
    repairsApplied: 0,
    skippedMissingPatient: 0,
    skippedMissingPatientName: 0,
    writesPlanned: 0,
    writesAttempted: 0,
    writesSucceeded: 0,
    firestoreWritesDelta: 0,
    maxWritesReached: false,
    samples: {
      planned: [],
      applied: [],
      skipped: []
    }
  };

  for (var i = 0; i < rows.length; i++) {
    var row = rows[i] || {};
    var fiscalCode = normalizeCf_(row.fiscalCode || row.patientFiscalCode || row.documentId || '');
    if (!fiscalCode) continue;
    if (!materializeDashboardIndexNameNeedsRepair_(row, fiscalCode)) continue;
    result.rowsNeedingRepair++;

    var patient = materializeGetTopLevelDocumentOrNull_(cfg, 'patients', fiscalCode);
    result.patientDocsRead++;
    if (!patient) {
      result.skippedMissingPatient++;
      identityResolutionRequestsAddSample_(result.samples.skipped, {
        fiscalCode: fiscalCode,
        currentFullName: String(row.fullName || row.patientFullName || '').trim(),
        reason: 'patient_missing'
      }, maxSamples);
      continue;
    }

    var nameResolution = materializeResolveDashboardRepairName_(cfg, patient, fiscalCode, 10);
    result.backendNameSourceDocsRead += Number(nameResolution.docsRead || 0);
    var repairedFullName = String(nameResolution.fullName || '').trim();
    if (nameResolution.conflict) {
      result.skippedNameSourceConflict++;
      identityResolutionRequestsAddSample_(result.samples.skipped, {
        fiscalCode: fiscalCode,
        currentFullName: String(row.fullName || row.patientFullName || '').trim(),
        reason: 'backend_name_source_conflict',
        conflictingNames: nameResolution.conflictingNames || []
      }, maxSamples);
      continue;
    }
    if (materializeIsPlaceholderPatientName_(repairedFullName, fiscalCode)) {
      result.skippedMissingPatientName++;
      identityResolutionRequestsAddSample_(result.samples.skipped, {
        fiscalCode: fiscalCode,
        currentFullName: String(row.fullName || row.patientFullName || '').trim(),
        reason: 'backend_name_source_missing_or_placeholder'
      }, maxSamples);
      continue;
    }

    if (nameResolution.source === 'patients') result.repairedFromPatients++;
    if (nameResolution.source === 'drive_pdf_imports') result.repairedFromDrivePdfImports++;
    if (nameResolution.source === 'prescription_intakes') result.repairedFromPrescriptionIntakes++;

    if (!identityResolutionRequestsCanConsumeWrites_(result, dryRun, maxWrites, 1)) {
      break;
    }

    var alias = String(row.alias || patient.alias || '').trim();
    var doctorFullName = String(row.doctorFullName || patient.doctorFullName || patient.doctorName || '').trim();
    var city = String(row.city || patient.city || '').trim();
    var exemptionCode = String(row.exemptionCode || patient.exemptionCode || '').trim();
    var exemptions = materializeMergeStringArrays_(row.exemptions, patient.exemptions || []);
    if (exemptionCode) exemptions = materializeMergeStringArrays_([exemptionCode], exemptions);
    var patch = {
      fiscalCode: fiscalCode,
      fullName: repairedFullName,
      searchPrefixes: buildPatientDashboardSearchPrefixes_([fiscalCode, repairedFullName, alias, doctorFullName, city, exemptionCode].concat(exemptions)),
      identityDashboardNameRepairedAt: nowIso,
      updatedAt: nowIso
    };

    result.repairsPlanned++;
    if (dryRun) {
      result.writesPlanned++;
      identityResolutionRequestsAddSample_(result.samples.planned, {
        fiscalCode: fiscalCode,
        previousFullName: String(row.fullName || row.patientFullName || '').trim(),
        repairedFullName: repairedFullName,
        nameSource: nameResolution.source || '',
        writesPlanned: 1
      }, maxSamples);
      continue;
    }

    executeFirestoreCommit_(cfg, [buildFirestorePatchWrite_(cfg, 'patient_dashboard_index', fiscalCode, patch, Object.keys(patch))]);
    result.repairsApplied++;
    result.writesAttempted++;
    result.writesSucceeded++;
    result.firestoreWritesDelta++;
    identityResolutionRequestsAddSample_(result.samples.applied, {
      fiscalCode: fiscalCode,
      previousFullName: String(row.fullName || row.patientFullName || '').trim(),
      repairedFullName: repairedFullName,
      nameSource: nameResolution.source || '',
      writesSucceeded: 1
    }, maxSamples);
  }

  materializePersistDashboardNameRepairCursor_(cfg, result, dryRun, maxWrites, repairScan, nowIso);

  result.checkedAt = new Date().toISOString();
  logInfo_(cfg, 'processRepairMaterializedPatientDashboardIndexNames completato', result);
  return result;
}

function materializeResolveDashboardRepairName_(cfg, patient, fiscalCode, maxDocsPerSource) {
  var targetCf = normalizeCf_(fiscalCode);
  var canonicalName = materializeCanonicalPatientDisplayName_(patient, targetCf);
  if (!materializeIsPlaceholderPatientName_(canonicalName, targetCf)) {
    return {
      fullName: canonicalName,
      source: 'patients',
      docsRead: 0,
      conflict: false,
      conflictingNames: []
    };
  }
  return materializeFindBackendOwnedPatientName_(cfg, targetCf, maxDocsPerSource);
}

function materializeFindBackendOwnedPatientName_(cfg, fiscalCode, maxDocsPerSource) {
  var targetCf = normalizeCf_(fiscalCode);
  var limit = identityResolutionRequestsBoundedInt_(maxDocsPerSource, 10, 1, 25);
  var docsRead = 0;
  var namesByComparable = {};
  var ordered = [];

  var driveImports = materializeListTopLevelWhereEqual_(cfg, 'drive_pdf_imports', 'patientFiscalCode', targetCf, limit);
  docsRead += driveImports.length;
  materializeCollectBackendOwnedPatientNames_(namesByComparable, ordered, driveImports, 'drive_pdf_imports', targetCf);

  var intakes = materializeListTopLevelWhereEqual_(cfg, 'prescription_intakes', 'fiscalCode', targetCf, limit);
  docsRead += intakes.length;
  materializeCollectBackendOwnedPatientNames_(namesByComparable, ordered, intakes, 'prescription_intakes', targetCf);

  if (ordered.length === 1) {
    return {
      fullName: ordered[0].fullName,
      source: ordered[0].source,
      docsRead: docsRead,
      conflict: false,
      conflictingNames: []
    };
  }
  if (ordered.length > 1) {
    return {
      fullName: '',
      source: '',
      docsRead: docsRead,
      conflict: true,
      conflictingNames: ordered.map(function (item) { return item.fullName; }).slice(0, 10)
    };
  }
  return {
    fullName: '',
    source: '',
    docsRead: docsRead,
    conflict: false,
    conflictingNames: []
  };
}

function materializeCollectBackendOwnedPatientNames_(namesByComparable, ordered, docs, source, fiscalCode) {
  for (var i = 0; i < docs.length; i++) {
    var doc = docs[i] || {};
    var fullName = materializeBestBackendOwnedNameFromDocument_(doc, fiscalCode);
    if (materializeIsPlaceholderPatientName_(fullName, fiscalCode)) continue;
    if (materializeIsSuspiciousBackendOwnedPatientName_(fullName, fiscalCode)) continue;
    var key = identityMergeComparableString_(fullName);
    if (!key || namesByComparable[key]) continue;
    namesByComparable[key] = true;
    ordered.push({ fullName: fullName, source: source });
  }
}


function materializeIsSuspiciousBackendOwnedPatientName_(value, fiscalCode) {
  var name = materializeNormalizeDisplayNameCandidate_(value);
  var cf = normalizeCf_(fiscalCode);
  if (!name || !cf) return false;
  var compactName = identityMergeComparableString_(name).replace(/[^A-Z0-9]/g, '');
  if (compactName.indexOf(cf) >= 0) return true;
  var cfFragments = [];
  for (var size = 5; size <= 8; size++) {
    for (var i = 0; i <= cf.length - size; i++) {
      cfFragments.push(cf.substring(i, i + size));
    }
  }
  var rawTokens = identityMergeComparableString_(name).split(/[^A-Z0-9]+/).filter(function (token) {
    return token && token.length >= 5;
  });
  for (var t = 0; t < rawTokens.length; t++) {
    var token = rawTokens[t];
    var tokenVariants = [token];
    if (token.charAt(0) === 'I' && token.length > 5) tokenVariants.push(token.substring(1));
    for (var v = 0; v < tokenVariants.length; v++) {
      var candidate = tokenVariants[v];
      if (candidate.length < 5) continue;
      if (cf.indexOf(candidate) >= 0) return true;
      for (var f = 0; f < cfFragments.length; f++) {
        if (candidate.indexOf(cfFragments[f]) >= 0) return true;
      }
    }
  }
  return false;
}

function materializeBestBackendOwnedNameFromDocument_(doc, fiscalCode) {
  var targetCf = normalizeCf_(fiscalCode);
  var directCandidates = [
    doc && doc.patientFullName,
    doc && doc.patientName,
    doc && doc.fullName,
    doc && doc.displayName,
    doc && doc.name
  ];
  for (var i = 0; i < directCandidates.length; i++) {
    var directName = materializeNormalizeDisplayNameCandidate_(directCandidates[i]);
    if (directName && !materializeIsPlaceholderPatientName_(directName, targetCf)) {
      return directName;
    }
  }

  var firstNameCandidates = [
    doc && doc.patientFirstName,
    doc && doc.firstName,
    doc && doc.givenName,
    doc && doc.nome
  ];
  var lastNameCandidates = [
    doc && doc.patientLastName,
    doc && doc.patientSurname,
    doc && doc.lastName,
    doc && doc.surname,
    doc && doc.familyName,
    doc && doc.cognome
  ];
  for (var j = 0; j < firstNameCandidates.length; j++) {
    var firstName = materializeNormalizeDisplayNameCandidate_(firstNameCandidates[j]);
    if (!firstName || materializeIsPlaceholderPatientName_(firstName, targetCf)) continue;
    for (var k = 0; k < lastNameCandidates.length; k++) {
      var lastName = materializeNormalizeDisplayNameCandidate_(lastNameCandidates[k]);
      if (!lastName || materializeIsPlaceholderPatientName_(lastName, targetCf)) continue;
      var combinedName = materializeNormalizeDisplayNameCandidate_(firstName + ' ' + lastName);
      if (combinedName && !materializeIsPlaceholderPatientName_(combinedName, targetCf)) {
        return combinedName;
      }
    }
  }
  return '';
}

function materializePersistDashboardNameRepairCursor_(cfg, result, dryRun, maxWrites, repairScan, nowIso) {
  if (!repairScan || !repairScan.cursorShouldPersist) return;
  if (result.maxWritesReached) return;
  result.repairCursorWritePlanned = true;
  if (dryRun) {
    result.repairCursorWriteSkippedDryRun = true;
    return;
  }
  if (!identityResolutionRequestsCanConsumeWrites_(result, false, maxWrites, 1)) return;
  var nextDocumentName = repairScan.cursorReset ? '' : String(repairScan.cursorNextDocumentName || '');
  executeFirestoreCommit_(cfg, [buildFirestorePatchWrite_(cfg, 'phbox_runtime', 'patient_dashboard_name_repair_cursor', {
    materializer: 'patient_dashboard_name_repair',
    cursorVersion: 1,
    dashboardNameRepairCursorDocumentName: nextDocumentName,
    dashboardNameRepairCursorReset: !!repairScan.cursorReset,
    dashboardNameRepairCursorWrapped: !!repairScan.cursorWrapped,
    dashboardNameRepairCursorUpdatedAt: nowIso,
    updatedAt: nowIso
  }, [
    'materializer',
    'cursorVersion',
    'dashboardNameRepairCursorDocumentName',
    'dashboardNameRepairCursorReset',
    'dashboardNameRepairCursorWrapped',
    'dashboardNameRepairCursorUpdatedAt',
    'updatedAt'
  ])]);
  result.writesAttempted++;
  result.writesSucceeded++;
  result.firestoreWritesDelta++;
  result.repairCursorWriteApplied = true;
}

function materializeDashboardIndexNameNeedsRepair_(row, fiscalCode) {
  var currentName = String(row && (row.fullName || row.patientFullName) || '').trim();
  if (materializeIsPlaceholderPatientName_(currentName, fiscalCode)) return true;
  return false;
}

function materializeListDashboardIndexRowsForNameRepair_(cfg, limit) {
  var pageSize = 50;
  var rawScanned = 0;
  var maxRawScan = Math.max(1, Number(limit || 1));
  var cursor = materializeReadDashboardNameRepairCursor_(cfg);
  var cursorPreviousDocumentName = String(cursor.dashboardNameRepairCursorDocumentName || '');
  var startAfterDocumentName = cursorPreviousDocumentName;
  var lastDocumentName = '';
  var items = [];
  var scanLimitReached = false;
  var cursorShouldPersist = false;
  var cursorReset = false;
  var cursorWrapped = false;

  while (items.length < maxRawScan && rawScanned < maxRawScan) {
    var remainingRaw = maxRawScan - rawScanned;
    var queryLimit = Math.min(pageSize, remainingRaw);
    var page = materializeRunDashboardIndexNameRepairPage_(cfg, queryLimit, startAfterDocumentName);
    if (!page.length) {
      if (startAfterDocumentName && !cursorWrapped) {
        startAfterDocumentName = '';
        cursorWrapped = true;
        cursorReset = true;
        cursorShouldPersist = true;
        continue;
      }
      cursorReset = true;
      cursorShouldPersist = !!cursorPreviousDocumentName;
      break;
    }

    for (var i = 0; i < page.length; i++) {
      var item = page[i] || {};
      rawScanned++;
      lastDocumentName = String(item.documentName || lastDocumentName || '');
      items.push(item);
      if (items.length >= maxRawScan || rawScanned >= maxRawScan) break;
    }

    if (page.length < queryLimit) {
      cursorReset = true;
      cursorShouldPersist = !!cursorPreviousDocumentName || cursorWrapped;
      break;
    }
    if (lastDocumentName) startAfterDocumentName = lastDocumentName;
  }

  if (rawScanned >= maxRawScan) scanLimitReached = true;
  if (rawScanned >= maxRawScan && lastDocumentName) {
    cursorShouldPersist = true;
    cursorReset = false;
  }

  return {
    items: items,
    rawScanned: rawScanned,
    scanLimitReached: scanLimitReached,
    cursorPreviousDocumentName: cursorPreviousDocumentName,
    cursorNextDocumentName: cursorReset ? '' : String(lastDocumentName || ''),
    cursorShouldPersist: cursorShouldPersist,
    cursorReset: cursorReset,
    cursorWrapped: cursorWrapped
  };
}

function materializeReadDashboardNameRepairCursor_(cfg) {
  var cursor = materializeGetDocumentByNameOrNull_(buildFirestoreDocumentName_(cfg, 'phbox_runtime', 'patient_dashboard_name_repair_cursor'));
  if (!cursor) return {};
  return cursor;
}

function materializeRunDashboardIndexNameRepairPage_(cfg, limit, startAfterDocumentName) {
  var query = {
    from: [{ collectionId: 'patient_dashboard_index' }],
    orderBy: [{
      field: { fieldPath: '__name__' },
      direction: 'ASCENDING'
    }],
    limit: Math.max(1, Number(limit || 1))
  };
  if (startAfterDocumentName) {
    query.startAt = {
      values: [{ referenceValue: startAfterDocumentName }],
      before: false
    };
  }
  return materializeRunQuery_(cfg, { structuredQuery: query });
}

function materializeCleanDocumentForCopy_(doc) {
  var out = {};
  Object.keys(doc || {}).forEach(function (key) {
    if (key === 'documentName' || key === 'documentId' || key === 'updateTime') return;
    out[key] = doc[key];
  });
  return out;
}

function materializeBuildPatchWriteByName_(documentName, data, fieldPaths) {
  return {
    update: {
      name: documentName,
      fields: toFirestoreFields_(data)
    },
    updateMask: {
      fieldPaths: uniqueNonEmptyStrings_(fieldPaths || Object.keys(data || {}))
    }
  };
}

function materializeBuildCreateOnlyWriteByName_(documentName, data) {
  return {
    update: {
      name: documentName,
      fields: toFirestoreFields_(data)
    },
    currentDocument: { exists: false }
  };
}

function materializeBuildDeleteWriteByName_(documentName) {
  return { delete: documentName };
}

function materializeRetargetPatientSubdocumentName_(sourceName, sourceId, targetId) {
  var sourceToken = '/patients/' + sourceId + '/';
  var targetToken = '/patients/' + targetId + '/';
  if (String(sourceName || '').indexOf(sourceToken) < 0) return '';
  return String(sourceName).replace(sourceToken, targetToken);
}

function materializeRetargetDoctorLinkId_(sourceDocId, sourceId, targetId) {
  var text = String(sourceDocId || '').trim();
  if (!text) return targetId + '__primary';
  if (text.indexOf(sourceId) >= 0) return text.split(sourceId).join(targetId);
  return targetId + '__' + text;
}

function materializeBoolOr_(a, b) {
  return materializeBool_(a) || materializeBool_(b);
}

function materializeBool_(value) {
  if (value === true) return true;
  var text = String(value || '').trim().toLowerCase();
  return text === 'true' || text === '1' || text === 'yes' || text === 'si' || text === 'sì';
}

function materializeInt_(value) {
  var parsed = Number(value || 0);
  if (!isFinite(parsed)) return 0;
  return Math.max(0, Math.floor(parsed));
}

function materializeNumber_(value) {
  var parsed = Number(value || 0);
  return isFinite(parsed) ? parsed : 0;
}

function materializeMergeStringArrays_(a, b) {
  var map = {};
  var values = [];
  if (Array.isArray(a)) values = values.concat(a);
  if (Array.isArray(b)) values = values.concat(b);
  for (var i = 0; i < values.length; i++) {
    var text = String(values[i] || '').trim();
    if (text) map[text] = true;
  }
  return Object.keys(map).sort();
}

function materializeEarlierDateString_(a, b) {
  var da = materializeParseDate_(a);
  var db = materializeParseDate_(b);
  if (da && db) return da.getTime() <= db.getTime() ? da.toISOString() : db.toISOString();
  if (da) return da.toISOString();
  if (db) return db.toISOString();
  return null;
}

function materializeLaterDateString_(a, b) {
  var da = materializeParseDate_(a);
  var db = materializeParseDate_(b);
  if (da && db) return da.getTime() >= db.getTime() ? da.toISOString() : db.toISOString();
  if (da) return da.toISOString();
  if (db) return db.toISOString();
  return null;
}

function materializeParseDate_(value) {
  var text = String(value || '').trim();
  if (!text) return null;
  var date = new Date(text);
  return isNaN(date.getTime()) ? null : date;
}
