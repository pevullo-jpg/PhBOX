function dryRunPatientIdentityCanonicalization(options) {
  options = options || {};
  var cfg = getPhboxConfig_();
  var startedAt = new Date().toISOString();
  var maxSamples = patientIdentityCanonicalizerBoundedInt_(options.maxSamples, 30, 1, 100);
  var built = patientIdentityCanonicalizerBuildPlan_(cfg, {
    maxSamples: maxSamples,
    collectApplyOperations: false
  });
  var plan = built.plan;

  var result = {
    ok: true,
    mode: 'dry_run_read_only',
    source: 'patient_identity_canonicalizer',
    startedAt: startedAt,
    checkedAt: new Date().toISOString(),
    policy: {
      canonicalId: 'patients/{normalizedFiscalCode}',
      familyMembershipWithRealCf: 'create_canonical_patient',
      tmpWithoutCf: 'do_not_auto_canonicalize',
      sameNameWithoutCf: 'frontend_user_merge_suggestion_only',
      hardDelete: 'out_of_scope_for_this_pr'
    },
    counts: {
      patientsSeen: built.counts.patientsSeen,
      patientDashboardIndexSeen: built.counts.patientDashboardIndexSeen,
      drivePdfImportsSeen: built.counts.drivePdfImportsSeen,
      debtsSeen: built.counts.debtsSeen,
      advancesSeen: built.counts.advancesSeen,
      bookingsSeen: built.counts.bookingsSeen,
      familiesSeen: built.counts.familiesSeen,
      doctorLinksSeen: built.counts.doctorLinksSeen,
      therapeuticAdviceSeen: built.counts.therapeuticAdviceSeen,
      canonicalPatients: built.counts.canonicalPatients,
      tmpPatients: built.counts.tmpPatients,
      identityStatus: plan.counts.identityStatus,
      createReasons: plan.counts.createReasons,
      mergeTypes: plan.counts.mergeTypes,
      plannedOperations: plan.counts.plannedOperations,
      operationSamplesReturned: plan.samples.operationSamples.length
    },
    samples: plan.samples,
    nextStep: 'Review dry-run. Apply executor is separate, bounded and create-only.'
  };

  logInfo_(cfg, 'dryRunPatientIdentityCanonicalization completato', result);
  return result;
}

function applyPatientIdentityCanonicalization(options) {
  options = options || {};
  var cfg = getPhboxConfig_();
  var startedAt = new Date().toISOString();
  var dryRun = options.dryRun !== false;
  var applyToken = String(options.applyToken || '').trim();
  var maxSamples = patientIdentityCanonicalizerBoundedInt_(options.maxSamples, 30, 1, 100);
  var maxWrites = patientIdentityCanonicalizerBoundedInt_(options.maxWrites, 25, 1, 100);
  var resumeAfter = normalizeCf_(options.resumeAfter || '');

  if (!dryRun && applyToken !== 'APPLY_CREATE_CANONICAL_PATIENTS') {
    var blocked = {
      ok: false,
      mode: 'apply_blocked',
      source: 'patient_identity_canonicalizer_apply',
      dryRun: false,
      startedAt: startedAt,
      checkedAt: new Date().toISOString(),
      reason: 'blocked_missing_apply_token',
      requiredApplyToken: 'APPLY_CREATE_CANONICAL_PATIENTS',
      writesSucceeded: 0,
      firestoreWritesDelta: 0
    };
    logInfo_(cfg, 'applyPatientIdentityCanonicalization bloccato', blocked);
    return blocked;
  }

  var built = patientIdentityCanonicalizerBuildPlan_(cfg, {
    maxSamples: maxSamples,
    collectApplyOperations: true,
    maxApplyOperations: maxWrites,
    resumeAfter: resumeAfter
  });
  var operations = built.applyOperations || [];
  var nowIso = new Date().toISOString();
  var result = {
    ok: true,
    mode: dryRun ? 'apply_dry_run_create_canonical_patients' : 'apply_create_canonical_patients',
    source: 'patient_identity_canonicalizer_apply',
    dryRun: dryRun,
    startedAt: startedAt,
    checkedAt: '',
    maxWrites: maxWrites,
    maxSamples: maxSamples,
    resumeAfter: resumeAfter,
    plannedOperations: built.plan.counts.plannedOperations,
    plannedApplicableOperations: built.applyCounts.plannedApplicableOperations,
    remainingApplicableOperations: built.applyCounts.remainingApplicableOperations,
    boundedApplyOperationsReturned: operations.length,
    createReasons: built.plan.counts.createReasons,
    operationsProcessed: 0,
    writesPlanned: 0,
    writesAttempted: 0,
    writesSucceeded: 0,
    skippedAlreadyExists: 0,
    skippedConcurrentExists: 0,
    skippedTmp: 0,
    skippedInvalid: 0,
    maxWritesReached: built.applyCounts.remainingApplicableOperations > operations.length,
    nextResumeAfter: '',
    firestoreWritesDelta: 0,
    samples: {
      appliedOrPlanned: [],
      skippedAlreadyExists: [],
      skippedTmp: [],
      skippedInvalid: []
    }
  };

  for (var i = 0; i < operations.length; i++) {
    var op = operations[i] || {};
    var targetId = normalizeCf_(op.targetId || op.fiscalCode || '');
    result.operationsProcessed++;
    result.nextResumeAfter = targetId || result.nextResumeAfter;

    if (!patientIdentityCanonicalizerIsSafeRealCf_(targetId)) {
      result.skippedInvalid++;
      patientIdentityCanonicalizerAddSample_(result.samples.skippedInvalid, {
        targetId: targetId,
        reason: 'invalid_or_missing_real_fiscal_code'
      }, maxSamples);
      continue;
    }

    if (auditPatientIdentityIsTmp_(targetId)) {
      result.skippedTmp++;
      patientIdentityCanonicalizerAddSample_(result.samples.skippedTmp, {
        targetId: targetId,
        reason: 'tmp_identity_not_canonicalized'
      }, maxSamples);
      continue;
    }

    if (dryRun) {
      result.writesPlanned++;
      patientIdentityCanonicalizerAddSample_(result.samples.appliedOrPlanned, {
        action: 'create_canonical_patient',
        targetId: targetId,
        dryRun: true,
        reason: op.reason || ''
      }, maxSamples);
      continue;
    }

    if (patientIdentityCanonicalizerPatientExists_(cfg, targetId)) {
      result.skippedAlreadyExists++;
      patientIdentityCanonicalizerAddSample_(result.samples.skippedAlreadyExists, {
        targetId: targetId,
        reason: 'patient_already_exists'
      }, maxSamples);
      continue;
    }

    var doc = patientIdentityCanonicalizerBuildMinimalPatientDocument_(targetId, op, nowIso);
    var write = patientIdentityCanonicalizerBuildCreateOnlyWrite_(cfg, 'patients', targetId, doc);
    result.writesAttempted++;
    try {
      executeFirestoreCommit_(cfg, [write]);
      result.writesSucceeded++;
      result.firestoreWritesDelta++;
      patientIdentityCanonicalizerAddSample_(result.samples.appliedOrPlanned, {
        action: 'create_canonical_patient',
        targetId: targetId,
        dryRun: false,
        reason: op.reason || ''
      }, maxSamples);
    } catch (e) {
      if (patientIdentityCanonicalizerIsAlreadyExistsCommitError_(e)) {
        result.skippedConcurrentExists++;
        patientIdentityCanonicalizerAddSample_(result.samples.skippedAlreadyExists, {
          targetId: targetId,
          reason: 'patient_created_concurrently'
        }, maxSamples);
        continue;
      }
      throw e;
    }
  }

  result.checkedAt = new Date().toISOString();
  logInfo_(cfg, 'applyPatientIdentityCanonicalization completato', result);
  return result;
}

function patientIdentityCanonicalizerBuildPlan_(cfg, options) {
  options = options || {};
  var maxSamples = patientIdentityCanonicalizerBoundedInt_(options.maxSamples, 30, 1, 100);
  var collectApplyOperations = options.collectApplyOperations === true;
  var maxApplyOperations = patientIdentityCanonicalizerBoundedInt_(options.maxApplyOperations, 25, 1, 100);
  var resumeAfter = normalizeCf_(options.resumeAfter || '');

  var patients = listFirestoreDocumentsByPathSafe_(cfg, ['patients'], { pageSize: 500 });
  var indexes = listFirestoreDocumentsByPathSafe_(cfg, ['patient_dashboard_index'], { pageSize: 500 });
  var doctorLinks = listFirestoreDocumentsByPathSafe_(cfg, ['doctor_patient_links'], { pageSize: 500 });
  var families = listFirestoreDocumentsByPathSafe_(cfg, ['families'], { pageSize: 500 });
  var therapeuticAdvice = listFirestoreDocumentsByPathSafe_(cfg, ['patient_therapeutic_advice'], { pageSize: 500 });
  var imports = listFirestoreDocumentsByPathSafe_(cfg, ['drive_pdf_imports'], { pageSize: 500 });
  var debts = listFirestoreCollectionGroupDocumentsSafe_(cfg, 'debts', {});
  var advances = listFirestoreCollectionGroupDocumentsSafe_(cfg, 'advances', {});
  var bookings = listFirestoreCollectionGroupDocumentsSafe_(cfg, 'bookings', {});

  var canonicalPatientsByCf = {};
  var tmpPatientsById = {};
  var patientDocsByEffectiveCf = {};
  var indexByCf = {};
  var operationalByCf = {};
  var doctorByCf = {};
  var familyByCf = {};
  var adviceByCf = {};
  var nameBuckets = {};

  patients.forEach(function (patient) {
    var docId = normalizeCf_(auditPatientIdentityReadDocumentId_(patient));
    var fieldCf = normalizeCf_(patient && (patient.fiscalCode || patient.patientFiscalCode || patient.patientCf || patient.cf));
    var effectiveCf = fieldCf || docId;
    var fullName = auditPatientIdentityReadString_(patient && (patient.fullName || patient.patientFullName));
    if (effectiveCf) {
      if (!patientDocsByEffectiveCf[effectiveCf]) patientDocsByEffectiveCf[effectiveCf] = [];
      patientDocsByEffectiveCf[effectiveCf].push({
        documentId: docId,
        fiscalCode: fieldCf,
        fullName: fullName,
        isTmp: auditPatientIdentityIsTmp_(docId) || auditPatientIdentityIsTmp_(fieldCf)
      });
    }
    var isTemporaryPatientIdentity = auditPatientIdentityIsTmp_(docId) ||
      auditPatientIdentityIsTmp_(fieldCf) ||
      auditPatientIdentityIsTmp_(effectiveCf);
    if (isTemporaryPatientIdentity) {
      var tmpId = docId || fieldCf || effectiveCf;
      if (tmpId) {
        tmpPatientsById[tmpId] = {
          id: tmpId,
          documentId: docId,
          fullName: fullName,
          fiscalCode: fieldCf || effectiveCf || tmpId
        };
      }
    } else if (effectiveCf) {
      canonicalPatientsByCf[effectiveCf] = {
        id: effectiveCf,
        fullName: fullName,
        fiscalCode: effectiveCf
      };
    }
    patientIdentityCanonicalizerAddNameBucket_(nameBuckets, 'patients', docId || effectiveCf, effectiveCf, fullName, auditPatientIdentityIsTmp_(docId) || auditPatientIdentityIsTmp_(fieldCf), !!(effectiveCf && !auditPatientIdentityIsTmp_(effectiveCf)));
  });

  indexes.forEach(function (item) {
    var cf = normalizeCf_(item && (item.fiscalCode || item.patientFiscalCode || item.documentId || item.id));
    if (!cf) return;
    var fullName = auditPatientIdentityReadString_(item && (item.fullName || item.patientFullName));
    indexByCf[cf] = {
      id: cf,
      fullName: fullName,
      hasRecipes: item && item.hasRecipes === true,
      hasDpc: item && item.hasDpc === true,
      hasDebt: item && item.hasDebt === true,
      hasAdvance: item && item.hasAdvance === true,
      hasBooking: item && item.hasBooking === true,
      hasExpiry: item && item.hasExpiry === true,
      familyId: auditPatientIdentityReadString_(item && item.familyId),
      doctorFullName: auditPatientIdentityReadString_(item && (item.doctorFullName || item.doctorName))
    };
    patientIdentityCanonicalizerAddNameBucket_(nameBuckets, 'patient_dashboard_index', cf, cf, fullName, auditPatientIdentityIsTmp_(cf), !!canonicalPatientsByCf[cf]);
  });

  patientIdentityCanonicalizerAddOperationalDocs_(operationalByCf, imports, 'drive_pdf_imports', maxSamples);
  patientIdentityCanonicalizerAddOperationalDocs_(operationalByCf, debts, 'debts', maxSamples);
  patientIdentityCanonicalizerAddOperationalDocs_(operationalByCf, advances, 'advances', maxSamples);
  patientIdentityCanonicalizerAddOperationalDocs_(operationalByCf, bookings, 'bookings', maxSamples);

  doctorLinks.forEach(function (link) {
    var linkId = auditPatientIdentityReadDocumentId_(link);
    var cf = normalizeCf_(link && (link.patientFiscalCode || link.fiscalCode || link.patientCf));
    if (!cf && linkId) cf = normalizeCf_(String(linkId).split('__')[0]);
    if (!cf) return;
    if (!doctorByCf[cf]) doctorByCf[cf] = { count: 0, idsSample: [] };
    doctorByCf[cf].count++;
    patientIdentityCanonicalizerPushBounded_(doctorByCf[cf].idsSample, linkId, maxSamples);
  });

  families.forEach(function (family) {
    var familyId = auditPatientIdentityReadDocumentId_(family);
    var members = auditPatientIdentityReadFamilyMembers_(family);
    members.forEach(function (rawMember) {
      var cf = normalizeCf_(rawMember);
      if (!cf) return;
      if (!familyByCf[cf]) familyByCf[cf] = { count: 0, familyIdsSample: [] };
      familyByCf[cf].count++;
      patientIdentityCanonicalizerPushBounded_(familyByCf[cf].familyIdsSample, familyId, maxSamples);
    });
  });

  therapeuticAdvice.forEach(function (advice) {
    var docId = normalizeCf_(auditPatientIdentityReadDocumentId_(advice));
    var cf = normalizeCf_(advice && (advice.patientFiscalCode || advice.fiscalCode || advice.patientCf)) || docId;
    if (!cf) return;
    if (!adviceByCf[cf]) adviceByCf[cf] = { count: 0, idsSample: [] };
    adviceByCf[cf].count++;
    patientIdentityCanonicalizerPushBounded_(adviceByCf[cf].idsSample, docId, maxSamples);
  });

  var plan = patientIdentityCanonicalizerEmptyPlan_();
  var ids = {};
  [indexByCf, operationalByCf, doctorByCf, familyByCf, adviceByCf, tmpPatientsById, canonicalPatientsByCf].forEach(function (source) {
    Object.keys(source || {}).forEach(function (id) { if (id) ids[id] = true; });
  });

  var applyOperations = [];
  var applyCounts = {
    plannedApplicableOperations: 0,
    remainingApplicableOperations: 0
  };

  Object.keys(ids).sort().forEach(function (id) {
    var isTmp = auditPatientIdentityIsTmp_(id);
    var canonical = canonicalPatientsByCf[id] || null;
    var tmp = tmpPatientsById[id] || null;
    var index = indexByCf[id] || null;
    var operational = operationalByCf[id] || null;
    var doctor = doctorByCf[id] || null;
    var family = familyByCf[id] || null;
    var advice = adviceByCf[id] || null;

    if (canonical) {
      patientIdentityCanonicalizerInc_(plan.counts.identityStatus, 'already_canonical');
      return;
    }

    if (tmp || isTmp) {
      patientIdentityCanonicalizerInc_(plan.counts.identityStatus, 'temporary_not_canonicalized');
      patientIdentityCanonicalizerAddSample_(plan.samples.temporaryNotCanonicalized, {
        id: id,
        fullName: tmp ? tmp.fullName : '',
        operationalCount: operational ? operational.totalCount : 0,
        doctorLinkCount: doctor ? doctor.count : 0,
        familyCount: family ? family.count : 0,
        adviceCount: advice ? advice.count : 0,
        futureAction: 'frontend_user_adds_cf_then_backend_merge'
      }, maxSamples);
      return;
    }

    var evidence = patientIdentityCanonicalizerEvidence_(index, operational, doctor, family, advice);
    if (evidence.hasCanonicalEvidence) {
      patientIdentityCanonicalizerInc_(plan.counts.identityStatus, 'to_create_canonical_patient');
      patientIdentityCanonicalizerInc_(plan.counts.createReasons, evidence.primaryReason);
      var op = {
        action: 'create_canonical_patient',
        targetId: id,
        fiscalCode: id,
        fullName: patientIdentityCanonicalizerBestName_(id, index, operational),
        source: 'backend_identity_canonicalizer_dry_run',
        reason: evidence.primaryReason,
        evidence: evidence.summary
      };
      patientIdentityCanonicalizerAddSample_(plan.samples.createCanonicalPatients, op, maxSamples);
      patientIdentityCanonicalizerAddOperationSample_(plan, op, maxSamples);
      applyCounts.plannedApplicableOperations++;
      if (!resumeAfter || String(id) > resumeAfter) {
        applyCounts.remainingApplicableOperations++;
        if (collectApplyOperations && applyOperations.length < maxApplyOperations) {
          applyOperations.push(patientIdentityCanonicalizerMinimalApplyOperation_(op));
        }
      }
      return;
    }

    if (index) {
      patientIdentityCanonicalizerInc_(plan.counts.identityStatus, 'zombie_index_candidate');
      var zombie = {
        action: 'remove_zombie_index',
        targetId: id,
        reason: 'index_without_patient_without_canonical_evidence'
      };
      patientIdentityCanonicalizerAddSample_(plan.samples.zombieIndexCandidates, zombie, maxSamples);
      patientIdentityCanonicalizerAddOperationSample_(plan, zombie, maxSamples);
      return;
    }

    patientIdentityCanonicalizerInc_(plan.counts.identityStatus, 'unsafe_or_unclassified');
    patientIdentityCanonicalizerAddSample_(plan.samples.unsafeCandidates, {
      id: id,
      hasIndex: !!index,
      hasOperational: !!operational,
      hasDoctor: !!doctor,
      hasFamily: !!family,
      hasAdvice: !!advice
    }, maxSamples);
  });

  Object.keys(patientDocsByEffectiveCf).sort().forEach(function (cf) {
    var docs = patientDocsByEffectiveCf[cf] || [];
    if (docs.length <= 1) return;
    patientIdentityCanonicalizerInc_(plan.counts.mergeTypes, 'strong_same_cf');
    patientIdentityCanonicalizerAddSample_(plan.samples.strongSameCfMerge, {
      fiscalCode: cf,
      documentCount: docs.length,
      docsSample: docs.slice(0, maxSamples),
      futureAction: 'backend_owned_merge'
    }, maxSamples);
  });

  Object.keys(nameBuckets).sort().forEach(function (nameKey) {
    var group = patientIdentityCanonicalizerDedupeNameGroup_(nameBuckets[nameKey] || []);
    if (group.length <= 1) return;
    var hasTmpOrNoCf = group.some(function (item) { return item.isTmp || !item.fiscalCode; });
    if (!hasTmpOrNoCf) return;
    var hasRealCf = group.some(function (item) { return item.fiscalCode && !auditPatientIdentityIsTmp_(item.fiscalCode); });
    var type = hasRealCf ? 'user_same_name_tmp_or_no_cf_with_cf' : 'user_same_name_without_cf';
    patientIdentityCanonicalizerInc_(plan.counts.mergeTypes, type);
    patientIdentityCanonicalizerAddSample_(plan.samples.userMergeSuggestionsByName, {
      candidateType: type,
      normalizedName: nameKey,
      candidateCount: group.length,
      candidatesSample: group.slice(0, maxSamples),
      futureAction: 'frontend_user_confirms_then_backend_merge'
    }, maxSamples);
  });

  return {
    counts: {
      patientsSeen: patients.length,
      patientDashboardIndexSeen: indexes.length,
      drivePdfImportsSeen: imports.length,
      debtsSeen: debts.length,
      advancesSeen: advances.length,
      bookingsSeen: bookings.length,
      familiesSeen: families.length,
      doctorLinksSeen: doctorLinks.length,
      therapeuticAdviceSeen: therapeuticAdvice.length,
      canonicalPatients: Object.keys(canonicalPatientsByCf).length,
      tmpPatients: Object.keys(tmpPatientsById).length
    },
    plan: plan,
    applyOperations: applyOperations,
    applyCounts: applyCounts
  };
}

function patientIdentityCanonicalizerEmptyPlan_() {
  return {
    counts: {
      identityStatus: {},
      createReasons: {},
      mergeTypes: {},
      plannedOperations: 0
    },
    samples: {
      createCanonicalPatients: [],
      zombieIndexCandidates: [],
      temporaryNotCanonicalized: [],
      strongSameCfMerge: [],
      userMergeSuggestionsByName: [],
      unsafeCandidates: [],
      operationSamples: []
    }
  };
}

function patientIdentityCanonicalizerEvidence_(index, operational, doctor, family, advice) {
  var summary = {
    indexFlags: patientIdentityCanonicalizerIndexFlags_(index),
    operationalCount: operational ? operational.totalCount : 0,
    operationalBySource: operational ? operational.countsBySource : {},
    doctorLinkCount: doctor ? doctor.count : 0,
    familyMembershipCount: family ? family.count : 0,
    familyIdsSample: family ? family.familyIdsSample : [],
    adviceCount: advice ? advice.count : 0
  };
  var indexHasFlags = !!(index && (index.hasRecipes || index.hasDpc || index.hasDebt || index.hasAdvance || index.hasBooking || index.hasExpiry));
  var primaryReason = '';
  if (operational && operational.totalCount > 0) primaryReason = 'operational_docs';
  else if (doctor && doctor.count > 0) primaryReason = 'doctor_link';
  else if (advice && advice.count > 0) primaryReason = 'therapeutic_advice';
  else if (indexHasFlags) primaryReason = 'dashboard_index_flags';
  else if (family && family.count > 0) primaryReason = 'family_membership';
  return {
    hasCanonicalEvidence: !!primaryReason,
    primaryReason: primaryReason,
    summary: summary
  };
}

function patientIdentityCanonicalizerAddOperationalDocs_(out, items, source, maxSamples) {
  (items || []).forEach(function (item) {
    var cf = normalizeCf_(item && (item.patientFiscalCode || item.fiscalCode || item.patientCf || item.cf || item.parentDocumentId));
    if (!cf) cf = auditPatientIdentityResolveCfFromPath_(item, source);
    if (!cf) return;
    if (!out[cf]) out[cf] = { totalCount: 0, countsBySource: {}, documentIdsSample: [], namesSample: [] };
    out[cf].totalCount++;
    out[cf].countsBySource[source] = (out[cf].countsBySource[source] || 0) + 1;
    patientIdentityCanonicalizerPushBounded_(out[cf].documentIdsSample, auditPatientIdentityReadDocumentId_(item), maxSamples);
    var name = auditPatientIdentityReadString_(item && (item.patientName || item.patientFullName || item.fullName));
    patientIdentityCanonicalizerPushBounded_(out[cf].namesSample, name, maxSamples);
  });
}

function patientIdentityCanonicalizerIndexFlags_(indexItem) {
  return {
    hasRecipes: !!(indexItem && indexItem.hasRecipes),
    hasDpc: !!(indexItem && indexItem.hasDpc),
    hasDebt: !!(indexItem && indexItem.hasDebt),
    hasAdvance: !!(indexItem && indexItem.hasAdvance),
    hasBooking: !!(indexItem && indexItem.hasBooking),
    hasExpiry: !!(indexItem && indexItem.hasExpiry)
  };
}

function patientIdentityCanonicalizerBestName_(id, index, operational) {
  var fromIndex = auditPatientIdentityReadString_(index && index.fullName);
  if (fromIndex && normalizeCf_(fromIndex) !== fromIndex) return fromIndex;
  var names = operational && Array.isArray(operational.namesSample) ? operational.namesSample : [];
  return names.length ? names[0] : id;
}

function patientIdentityCanonicalizerMinimalApplyOperation_(operation) {
  var familyIdsSample = operation && operation.evidence && Array.isArray(operation.evidence.familyIdsSample)
    ? operation.evidence.familyIdsSample.slice(0, 10)
    : [];
  return {
    action: 'create_canonical_patient',
    targetId: normalizeCf_(operation && operation.targetId),
    fiscalCode: normalizeCf_(operation && operation.fiscalCode),
    fullName: auditPatientIdentityReadString_(operation && operation.fullName),
    reason: String((operation && operation.reason) || '').trim(),
    familyIdsSample: familyIdsSample
  };
}

function patientIdentityCanonicalizerCreateCanonicalOperations_(operations) {
  return (operations || []).filter(function (op) {
    return op && op.action === 'create_canonical_patient';
  }).sort(function (a, b) {
    return String(a.targetId || '').localeCompare(String(b.targetId || ''));
  });
}

function patientIdentityCanonicalizerPatientExists_(cfg, fiscalCode) {
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

function patientIdentityCanonicalizerBuildMinimalPatientDocument_(fiscalCode, operation, nowIso) {
  var reason = String((operation && operation.reason) || '').trim();
  var data = {
    fiscalCode: fiscalCode,
    source: 'backend_identity_canonicalizer_apply',
    createdAt: nowIso,
    updatedAt: nowIso,
    identityCanonicalizedAt: nowIso,
    identityCanonicalizationReason: reason,
    identityCanonicalizationVersion: 1
  };
  var fullName = auditPatientIdentityReadString_(operation && operation.fullName);
  if (fullName && normalizeCf_(fullName) !== fiscalCode) data.fullName = fullName;
  var familyIdsSample = operation && Array.isArray(operation.familyIdsSample) ? operation.familyIdsSample : [];
  if (familyIdsSample.length) data.identityCanonicalizationFamilyIdsSample = familyIdsSample.slice(0, 10);
  return data;
}

function patientIdentityCanonicalizerBuildCreateOnlyWrite_(cfg, collection, documentId, data) {
  var write = buildFirestoreUpdateWrite_(cfg, collection, documentId, data);
  write.currentDocument = { exists: false };
  return write;
}

function patientIdentityCanonicalizerIsAlreadyExistsCommitError_(error) {
  var text = String(error && (error.message || error) || '');
  return text.indexOf('ALREADY_EXISTS') >= 0 ||
    text.indexOf('already exists') >= 0 ||
    text.indexOf('FAILED_PRECONDITION') >= 0 ||
    text.indexOf('currentDocument') >= 0;
}

function patientIdentityCanonicalizerIsSafeRealCf_(value) {
  var cf = normalizeCf_(value);
  return !!cf && !auditPatientIdentityIsTmp_(cf) && /^[A-Z0-9]{16}$/.test(cf);
}

function patientIdentityCanonicalizerAddNameBucket_(buckets, source, id, fiscalCode, fullName, isTmp, isCanonical) {
  var nameKey = patientIdentityCanonicalizerNameKey_(fullName);
  if (!nameKey) return;
  if (!buckets[nameKey]) buckets[nameKey] = [];
  buckets[nameKey].push({
    source: source,
    id: id,
    fiscalCode: auditPatientIdentityIsTmp_(fiscalCode) ? '' : normalizeCf_(fiscalCode),
    fullName: auditPatientIdentityReadString_(fullName),
    isTmp: !!isTmp,
    isCanonical: !!isCanonical
  });
}

function patientIdentityCanonicalizerDedupeNameGroup_(items) {
  var out = [];
  var seen = {};
  (items || []).forEach(function (item) {
    var key = [item.source, item.id, item.fiscalCode || '', item.fullName || ''].join('|');
    if (seen[key]) return;
    seen[key] = true;
    out.push(item);
  });
  return out;
}

function patientIdentityCanonicalizerNameKey_(value) {
  return auditPatientIdentityReadString_(value)
    .toUpperCase()
    .replace(/[^A-Z0-9]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function patientIdentityCanonicalizerAddOperationSample_(plan, operation, maxSamples) {
  plan.counts.plannedOperations = (plan.counts.plannedOperations || 0) + 1;
  patientIdentityCanonicalizerAddSample_(plan.samples.operationSamples, operation, maxSamples);
}

function patientIdentityCanonicalizerAddSample_(target, value, maxSamples) {
  if (!target || target.length >= maxSamples) return;
  target.push(value);
}

function patientIdentityCanonicalizerPushBounded_(target, value, maxSamples) {
  if (!target || target.length >= maxSamples) return;
  if (value === undefined || value === null || String(value).trim() === '') return;
  target.push(String(value).trim());
}

function patientIdentityCanonicalizerInc_(target, key) {
  if (!target || !key) return;
  target[key] = (target[key] || 0) + 1;
}

function patientIdentityCanonicalizerBoundedInt_(value, fallback, minValue, maxValue) {
  var parsed = Number(value);
  if (!isFinite(parsed)) parsed = Number(fallback);
  if (!isFinite(parsed)) parsed = minValue;
  parsed = Math.floor(parsed);
  if (parsed < minValue) return minValue;
  if (parsed > maxValue) return maxValue;
  return parsed;
}
