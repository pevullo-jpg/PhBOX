function planPatientIdentityResolution(options) {
  options = options || {};
  var cfg = getPhboxConfig_();
  var startedAt = new Date().toISOString();
  var maxSamples = planPatientIdentityResolutionBoundedInt_(options.maxSamples, 30, 1, 100);

  var patients = listFirestoreDocumentsByPathSafe_(cfg, ['patients'], { pageSize: 500 });
  var indexes = listFirestoreDocumentsByPathSafe_(cfg, ['patient_dashboard_index'], { pageSize: 500 });
  var doctorLinks = listFirestoreDocumentsByPathSafe_(cfg, ['doctor_patient_links'], { pageSize: 500 });
  var families = listFirestoreDocumentsByPathSafe_(cfg, ['families'], { pageSize: 500 });
  var therapeuticAdvice = listFirestoreDocumentsByPathSafe_(cfg, ['patient_therapeutic_advice'], { pageSize: 500 });
  var imports = listFirestoreDocumentsByPathSafe_(cfg, ['drive_pdf_imports'], { pageSize: 500 });
  var debts = listFirestoreCollectionGroupDocumentsSafe_(cfg, 'debts', {});
  var advances = listFirestoreCollectionGroupDocumentsSafe_(cfg, 'advances', {});
  var bookings = listFirestoreCollectionGroupDocumentsSafe_(cfg, 'bookings', {});

  var patientsById = {};
  var canonicalPatientsByCf = {};
  var tmpPatientsById = {};
  var nameBuckets = {};
  var indexByCf = {};
  var operationalByCf = {};
  var doctorLinkByCf = {};
  var familyByCf = {};
  var adviceByCf = {};
  var patientDocsByEffectiveCf = {};

  patients.forEach(function (patient) {
    var docId = normalizeCf_(auditPatientIdentityReadDocumentId_(patient));
    var fieldCf = normalizeCf_(patient && (patient.fiscalCode || patient.patientFiscalCode || patient.patientCf || patient.cf));
    var effectiveCf = fieldCf || docId;
    var fullName = auditPatientIdentityReadString_(patient && (patient.fullName || patient.patientFullName));
    var nameKey = planPatientIdentityResolutionNameKey_(fullName);
    if (docId) patientsById[docId] = patient;
    if (effectiveCf) {
      if (!patientDocsByEffectiveCf[effectiveCf]) patientDocsByEffectiveCf[effectiveCf] = [];
      patientDocsByEffectiveCf[effectiveCf].push({
        documentId: docId,
        fiscalCode: fieldCf,
        fullName: fullName,
        isTmp: auditPatientIdentityIsTmp_(docId) || auditPatientIdentityIsTmp_(fieldCf)
      });
    }
    if (auditPatientIdentityIsTmp_(docId) || auditPatientIdentityIsTmp_(fieldCf)) {
      if (docId) tmpPatientsById[docId] = { id: docId, fiscalCode: fieldCf || docId, fullName: fullName, nameKey: nameKey };
    } else if (effectiveCf) {
      canonicalPatientsByCf[effectiveCf] = { id: effectiveCf, fiscalCode: effectiveCf, fullName: fullName, nameKey: nameKey };
    }
    planPatientIdentityResolutionAddNameBucket_(nameBuckets, nameKey, {
      source: 'patients',
      id: docId || effectiveCf,
      fiscalCode: auditPatientIdentityIsTmp_(effectiveCf) ? '' : effectiveCf,
      fullName: fullName,
      isTmp: auditPatientIdentityIsTmp_(docId) || auditPatientIdentityIsTmp_(fieldCf),
      isCanonical: !!(effectiveCf && !auditPatientIdentityIsTmp_(effectiveCf))
    });
  });

  indexes.forEach(function (item) {
    var cf = normalizeCf_(item && (item.fiscalCode || item.patientFiscalCode || item.documentId || item.id));
    if (!cf) return;
    var fullName = auditPatientIdentityReadString_(item && (item.fullName || item.patientFullName));
    indexByCf[cf] = {
      id: cf,
      fiscalCode: cf,
      fullName: fullName,
      hasRecipes: item && item.hasRecipes === true,
      hasDpc: item && item.hasDpc === true,
      hasDebt: item && item.hasDebt === true,
      hasAdvance: item && item.hasAdvance === true,
      hasBooking: item && item.hasBooking === true,
      hasExpiry: item && item.hasExpiry === true
    };
    planPatientIdentityResolutionAddNameBucket_(nameBuckets, planPatientIdentityResolutionNameKey_(fullName), {
      source: 'patient_dashboard_index',
      id: cf,
      fiscalCode: auditPatientIdentityIsTmp_(cf) ? '' : cf,
      fullName: fullName,
      isTmp: auditPatientIdentityIsTmp_(cf),
      isCanonical: !!canonicalPatientsByCf[cf]
    });
  });

  planPatientIdentityResolutionAddOperationalDocs_(operationalByCf, imports, 'drive_pdf_imports');
  planPatientIdentityResolutionAddOperationalDocs_(operationalByCf, debts, 'debts');
  planPatientIdentityResolutionAddOperationalDocs_(operationalByCf, advances, 'advances');
  planPatientIdentityResolutionAddOperationalDocs_(operationalByCf, bookings, 'bookings');
  planPatientIdentityResolutionAddDoctorLinks_(doctorLinkByCf, doctorLinks, maxSamples);
  planPatientIdentityResolutionAddFamilies_(familyByCf, families, maxSamples);
  planPatientIdentityResolutionAddAdvice_(adviceByCf, therapeuticAdvice, maxSamples);

  var plan = planPatientIdentityResolutionCreateEmptyPlan_();
  var allIds = {};
  [canonicalPatientsByCf, tmpPatientsById, indexByCf, operationalByCf, doctorLinkByCf, familyByCf, adviceByCf].forEach(function (source) {
    Object.keys(source || {}).forEach(function (id) { if (id) allIds[id] = true; });
  });

  Object.keys(allIds).sort().forEach(function (id) {
    var canonicalPatient = canonicalPatientsByCf[id] || null;
    var tmpPatient = tmpPatientsById[id] || null;
    var indexItem = indexByCf[id] || null;
    var operational = operationalByCf[id] || null;
    var doctor = doctorLinkByCf[id] || null;
    var family = familyByCf[id] || null;
    var advice = adviceByCf[id] || null;
    var hasOperational = !!(operational && operational.totalCount > 0);
    var hasIndexFlags = !!(indexItem && (indexItem.hasRecipes || indexItem.hasDpc || indexItem.hasDebt || indexItem.hasAdvance || indexItem.hasBooking || indexItem.hasExpiry));

    if (canonicalPatient) {
      planPatientIdentityResolutionIncrement_(plan.counts.identityStatus, 'canonical');
      if (indexItem) planPatientIdentityResolutionIncrement_(plan.counts.indexRows, 'canonical_with_index');
      return;
    }
    if (tmpPatient || auditPatientIdentityIsTmp_(id)) {
      planPatientIdentityResolutionIncrement_(plan.counts.identityStatus, 'temporary');
      planPatientIdentityResolutionAddSample_(plan.samples.temporaryRows, {
        id: id,
        fullName: tmpPatient ? tmpPatient.fullName : '',
        hasIndex: !!indexItem,
        operationalCount: operational ? operational.totalCount : 0,
        doctorLinkCount: doctor ? doctor.count : 0,
        familyCount: family ? family.count : 0,
        adviceCount: advice ? advice.count : 0
      }, maxSamples);
      return;
    }
    if (hasOperational || doctor || family || advice) {
      planPatientIdentityResolutionIncrement_(plan.counts.identityStatus, 'operational_orphan');
      planPatientIdentityResolutionAddSample_(plan.samples.createCanonicalPatients, {
        reason: 'operational_orphan',
        targetId: id,
        fullName: planPatientIdentityResolutionBestName_(indexItem, operational),
        hasIndex: !!indexItem,
        indexHasFlags: hasIndexFlags,
        operationalCount: operational ? operational.totalCount : 0,
        operationalBySource: operational ? operational.countsBySource : {},
        doctorLinkCount: doctor ? doctor.count : 0,
        familyCount: family ? family.count : 0,
        adviceCount: advice ? advice.count : 0
      }, maxSamples);
      planPatientIdentityResolutionAddMergeCandidate_(plan, 'create_canonical_from_operational_orphan', id, id, maxSamples);
      return;
    }
    if (indexItem && hasIndexFlags) {
      planPatientIdentityResolutionIncrement_(plan.counts.identityStatus, 'index_orphan_with_flags');
      planPatientIdentityResolutionAddSample_(plan.samples.indexOrphansWithFlags, {
        targetId: id,
        fullName: indexItem.fullName,
        flags: planPatientIdentityResolutionIndexFlags_(indexItem)
      }, maxSamples);
      planPatientIdentityResolutionAddMergeCandidate_(plan, 'create_canonical_from_index_flags', 'patient_dashboard_index/' + id, id, maxSamples);
      return;
    }
    if (indexItem && !hasIndexFlags) {
      planPatientIdentityResolutionIncrement_(plan.counts.identityStatus, 'zombie_index');
      planPatientIdentityResolutionAddSample_(plan.samples.zombieIndexes, { targetId: id, fullName: indexItem.fullName }, maxSamples);
    }
  });

  Object.keys(patientDocsByEffectiveCf).sort().forEach(function (cf) {
    var docs = patientDocsByEffectiveCf[cf] || [];
    if (docs.length <= 1) return;
    planPatientIdentityResolutionIncrement_(plan.counts.mergeTypes, 'strong_same_cf');
    planPatientIdentityResolutionAddSample_(plan.samples.strongMergeByCf, {
      fiscalCode: cf,
      count: docs.length,
      docsSample: docs.slice(0, maxSamples)
    }, maxSamples);
  });

  Object.keys(nameBuckets).sort().forEach(function (nameKey) {
    var group = planPatientIdentityResolutionDedupeNameGroup_(nameBuckets[nameKey] || []);
    if (group.length <= 1) return;
    var hasTmpOrNoCf = group.some(function (item) { return item.isTmp || !item.fiscalCode; });
    if (!hasTmpOrNoCf) return;
    var hasCanonical = group.some(function (item) { return item.isCanonical || !!item.fiscalCode; });
    var type = hasCanonical ? 'user_same_name_tmp_or_no_cf_with_cf' : 'user_same_name_without_cf';
    planPatientIdentityResolutionIncrement_(plan.counts.mergeTypes, type);
    planPatientIdentityResolutionAddSample_(plan.samples.userMergeSuggestionsByName, {
      candidateType: type,
      normalizedName: nameKey,
      count: group.length,
      candidatesSample: group.slice(0, maxSamples)
    }, maxSamples);
  });

  var result = {
    ok: true,
    mode: 'read_only',
    source: 'patient_identity_resolution_plan',
    startedAt: startedAt,
    checkedAt: new Date().toISOString(),
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
      tmpPatients: Object.keys(tmpPatientsById).length,
      identityStatus: plan.counts.identityStatus,
      mergeTypes: plan.counts.mergeTypes,
      indexRows: plan.counts.indexRows,
      mergeCandidates: plan.counts.mergeCandidates
    },
    samples: plan.samples,
    nextStep: 'Review plan. This planner performs no writes. Later PRs may add backend-owned dry-run/apply endpoints and frontend user merge proposals.'
  };

  logInfo_(cfg, 'planPatientIdentityResolution completato', result);
  return result;
}

function planPatientIdentityResolutionCreateEmptyPlan_() {
  return {
    counts: { identityStatus: {}, mergeTypes: {}, indexRows: {}, mergeCandidates: 0 },
    samples: {
      temporaryRows: [],
      createCanonicalPatients: [],
      indexOrphansWithFlags: [],
      zombieIndexes: [],
      strongMergeByCf: [],
      userMergeSuggestionsByName: [],
      mergeCandidates: []
    }
  };
}

function planPatientIdentityResolutionAddOperationalDocs_(out, items, source) {
  (items || []).forEach(function (item) {
    var cf = normalizeCf_(item && (item.patientFiscalCode || item.fiscalCode || item.patientCf || item.cf || item.parentDocumentId));
    if (!cf) cf = auditPatientIdentityResolveCfFromPath_(item, source);
    if (!cf) return;
    if (!out[cf]) out[cf] = { totalCount: 0, countsBySource: {}, names: [] };
    out[cf].totalCount++;
    out[cf].countsBySource[source] = (out[cf].countsBySource[source] || 0) + 1;
    var name = auditPatientIdentityReadString_(item && (item.patientName || item.patientFullName || item.fullName));
    if (name) planPatientIdentityResolutionPushBounded_(out[cf].names, name, 10);
  });
}

function planPatientIdentityResolutionAddDoctorLinks_(out, doctorLinks, sampleLimit) {
  (doctorLinks || []).forEach(function (link) {
    var linkId = auditPatientIdentityReadDocumentId_(link);
    var cf = normalizeCf_(link && (link.patientFiscalCode || link.fiscalCode || link.patientCf));
    if (!cf && linkId) cf = normalizeCf_(String(linkId).split('__')[0]);
    if (!cf) return;
    if (!out[cf]) out[cf] = { count: 0, ids: [] };
    out[cf].count++;
    planPatientIdentityResolutionPushBounded_(out[cf].ids, linkId, sampleLimit);
  });
}

function planPatientIdentityResolutionAddFamilies_(out, families, sampleLimit) {
  (families || []).forEach(function (family) {
    var familyId = auditPatientIdentityReadDocumentId_(family);
    auditPatientIdentityReadFamilyMembers_(family).forEach(function (rawMember) {
      var cf = normalizeCf_(rawMember);
      if (!cf) return;
      if (!out[cf]) out[cf] = { count: 0, ids: [] };
      out[cf].count++;
      planPatientIdentityResolutionPushBounded_(out[cf].ids, familyId, sampleLimit);
    });
  });
}

function planPatientIdentityResolutionAddAdvice_(out, items, sampleLimit) {
  (items || []).forEach(function (advice) {
    var docId = normalizeCf_(auditPatientIdentityReadDocumentId_(advice));
    var cf = normalizeCf_(advice && (advice.patientFiscalCode || advice.fiscalCode || advice.patientCf)) || docId;
    if (!cf) return;
    if (!out[cf]) out[cf] = { count: 0, ids: [] };
    out[cf].count++;
    planPatientIdentityResolutionPushBounded_(out[cf].ids, docId, sampleLimit);
  });
}

function planPatientIdentityResolutionAddMergeCandidate_(plan, reason, sourceId, targetId, sampleLimit) {
  plan.counts.mergeCandidates++;
  planPatientIdentityResolutionAddSample_(plan.samples.mergeCandidates, { reason: reason, sourceId: sourceId, targetId: targetId }, sampleLimit);
}

function planPatientIdentityResolutionIndexFlags_(indexItem) {
  return {
    hasRecipes: !!(indexItem && indexItem.hasRecipes),
    hasDpc: !!(indexItem && indexItem.hasDpc),
    hasDebt: !!(indexItem && indexItem.hasDebt),
    hasAdvance: !!(indexItem && indexItem.hasAdvance),
    hasBooking: !!(indexItem && indexItem.hasBooking),
    hasExpiry: !!(indexItem && indexItem.hasExpiry)
  };
}

function planPatientIdentityResolutionBestName_(indexItem, operational) {
  var fromIndex = auditPatientIdentityReadString_(indexItem && indexItem.fullName);
  if (fromIndex && normalizeCf_(fromIndex) !== fromIndex) return fromIndex;
  var names = operational && Array.isArray(operational.names) ? operational.names : [];
  return names.length ? names[0] : fromIndex;
}

function planPatientIdentityResolutionAddNameBucket_(buckets, nameKey, item) {
  if (!nameKey) return;
  if (!buckets[nameKey]) buckets[nameKey] = [];
  buckets[nameKey].push(item);
}

function planPatientIdentityResolutionDedupeNameGroup_(items) {
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

function planPatientIdentityResolutionNameKey_(value) {
  return auditPatientIdentityReadString_(value).toUpperCase().replace(/[^A-Z0-9]+/g, ' ').replace(/\s+/g, ' ').trim();
}

function planPatientIdentityResolutionIncrement_(target, key) {
  if (!key) return;
  target[key] = (target[key] || 0) + 1;
}

function planPatientIdentityResolutionAddSample_(target, value, sampleLimit) {
  if (!target || target.length >= sampleLimit) return;
  target.push(value);
}

function planPatientIdentityResolutionPushBounded_(target, value, limit) {
  if (!target || target.length >= limit) return;
  if (value === undefined || value === null || String(value).trim() === '') return;
  target.push(String(value).trim());
}

function planPatientIdentityResolutionBoundedInt_(value, fallback, minValue, maxValue) {
  var parsed = Number(value);
  if (!isFinite(parsed)) parsed = Number(fallback);
  if (!isFinite(parsed)) parsed = minValue;
  parsed = Math.floor(parsed);
  if (parsed < minValue) return minValue;
  if (parsed > maxValue) return maxValue;
  return parsed;
}
