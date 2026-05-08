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
    maxRequests: 25,
    maxSamples: 30
  });
}

function processPatientIdentityMergeRequests(options) {
  options = options || {};
  var cfg = getPhboxConfig_();
  var startedAt = new Date().toISOString();
  var dryRun = options.dryRun !== false;
  var maxRequests = identityResolutionRequestsBoundedInt_(options.maxRequests, 25, 1, 50);
  var maxSamples = identityResolutionRequestsBoundedInt_(options.maxSamples, 30, 1, 100);

  if (!dryRun) {
    var blocked = {
      ok: false,
      mode: 'identity_merge_requests_apply_blocked',
      source: 'patient_identity_merge_requests',
      dryRun: false,
      startedAt: startedAt,
      checkedAt: new Date().toISOString(),
      reason: 'apply_not_implemented_for_merge_requests',
      writesAttempted: 0,
      writesSucceeded: 0,
      firestoreWritesDelta: 0
    };
    logInfo_(cfg, 'processPatientIdentityMergeRequests bloccato', blocked);
    return blocked;
  }

  var requests = listPendingBackendMergeIdentityResolutionRequests_(cfg, maxRequests);
  var result = {
    ok: true,
    mode: 'identity_merge_requests_dry_run',
    source: 'patient_identity_merge_requests',
    dryRun: true,
    startedAt: startedAt,
    checkedAt: '',
    maxRequests: maxRequests,
    maxSamples: maxSamples,
    requestsSeen: requests.length,
    requestsProcessed: 0,
    plannedMergeRequests: 0,
    invalidRequests: 0,
    unsupportedActions: 0,
    sourceMissing: 0,
    targetMissing: 0,
    targetAlreadyExists: 0,
    conflictFree: 0,
    conflictsDetected: 0,
    userChoicesRequired: 0,
    userChoicesSatisfied: 0,
    writesPlanned: 0,
    writesAttempted: 0,
    writesSucceeded: 0,
    firestoreWritesDelta: 0,
    maxRequestsReached: requests.length >= maxRequests,
    supportedActions: [
      'choose_correct_fiscal_code',
      'merge_same_name_patient',
      'merge_similar_cf_patient'
    ],
    samples: {
      planned: [],
      conflicts: [],
      rejected: [],
      unsupported: [],
      missing: []
    }
  };

  for (var i = 0; i < requests.length; i++) {
    var request = requests[i] || {};
    var requestId = String(request.documentId || '').trim();
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

    var targetPatient = identityResolutionRequestsGetPatientOrNull_(cfg, targetId);
    var targetExists = !!targetPatient;
    if (targetExists) {
      result.targetAlreadyExists++;
    } else {
      result.targetMissing++;
    }

    var rawConflicts = targetExists
      ? identityMergeDetectPatientFieldConflicts_(sourcePatient, targetPatient)
      : [];
    var unresolvedConflicts = identityMergeUnresolvedConflictFields_(rawConflicts, request);
    var resolvedConflicts = rawConflicts.filter(function (field) {
      return unresolvedConflicts.indexOf(field) < 0;
    });
    var requiresUserChoices = unresolvedConflicts.length > 0;

    result.requestsProcessed++;
    result.plannedMergeRequests++;
    if (rawConflicts.length > 0) {
      result.conflictsDetected++;
    }
    if (resolvedConflicts.length > 0) {
      result.userChoicesSatisfied++;
    }
    if (requiresUserChoices) {
      result.userChoicesRequired++;
      identityResolutionRequestsAddSample_(result.samples.conflicts, {
        requestId: requestId,
        action: action,
        sourceId: sourceId,
        targetId: targetId,
        selectedFiscalCode: selectedCf,
        conflictFields: unresolvedConflicts,
        resolvedConflictFields: resolvedConflicts,
        futureAction: 'frontend_user_selects_field_values_then_backend_apply'
      }, maxSamples);
    } else {
      result.conflictFree++;
    }

    identityResolutionRequestsAddSample_(result.samples.planned, {
      requestId: requestId,
      action: action,
      sourceId: sourceId,
      targetId: targetId,
      selectedFiscalCode: selectedCf,
      targetExists: targetExists,
      requiresUserChoices: requiresUserChoices,
      conflictFields: unresolvedConflicts,
      resolvedConflictFields: resolvedConflicts,
      targetIdentityType: identityMergeRequestTargetIdentityType_(action, targetId, selectedCf),
      futureAction: 'backend_merge_executor_apply_not_in_this_pr'
    }, maxSamples);
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
    return data;
  }).filter(function (item) {
    return !!item;
  });
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

function identityMergeComparableString_(value) {
  return String(value == null ? '' : value).trim().replace(/\s+/g, ' ').toUpperCase();
}
