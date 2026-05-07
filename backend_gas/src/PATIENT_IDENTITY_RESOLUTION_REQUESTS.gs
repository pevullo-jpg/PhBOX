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
