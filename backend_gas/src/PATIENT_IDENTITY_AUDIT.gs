function auditPatientIdentityConsistency(options) {
  options = options || {};
  var cfg = getPhboxConfig_();
  var startedAt = new Date().toISOString();
  var maxSamples = auditPatientIdentityNormalizeMaxSamples_(options.maxSamples);

  var patients = listFirestoreDocumentsByPathSafe_(cfg, ['patients'], { pageSize: 500 });
  var indexes = listFirestoreDocumentsByPathSafe_(cfg, ['patient_dashboard_index'], { pageSize: 500 });
  var imports = listFirestoreDocumentsByPathSafe_(cfg, ['drive_pdf_imports'], { pageSize: 500 });
  var doctorLinks = listFirestoreDocumentsByPathSafe_(cfg, ['doctor_patient_links'], { pageSize: 500 });
  var families = listFirestoreDocumentsByPathSafe_(cfg, ['families'], { pageSize: 500 });
  var therapeuticAdvice = listFirestoreDocumentsByPathSafe_(cfg, ['patient_therapeutic_advice'], { pageSize: 500 });
  var debts = listFirestoreCollectionGroupDocumentsSafe_(cfg, 'debts', {});
  var advances = listFirestoreCollectionGroupDocumentsSafe_(cfg, 'advances', {});
  var bookings = listFirestoreCollectionGroupDocumentsSafe_(cfg, 'bookings', {});

  var samples = {
    duplicateFiscalCodeGroups: [],
    tmpPatients: [],
    tmpWithRealFiscalCode: [],
    documentIdFiscalCodeMismatches: [],
    indexesWithoutCanonicalPatient: [],
    patientsWithoutIndex: [],
    operationalDocsWithoutCanonicalPatient: [],
    familiesWithTmpMembers: [],
    familiesWithDuplicateMembers: [],
    doctorLinksWithTmpOrMissingPatient: [],
    therapeuticAdviceWithoutCanonicalPatient: [],
    mergeCandidates: []
  };

  var patientsByDocId = {};
  var canonicalPatientByCf = {};
  var patientDocsByCf = {};
  var tmpPatients = [];
  var tmpWithRealFiscalCodeCandidates = [];

  patients.forEach(function (patient) {
    var docId = auditPatientIdentityReadDocumentId_(patient);
    var docIdCf = normalizeCf_(docId);
    var fieldCf = normalizeCf_(patient && (patient.fiscalCode || patient.patientFiscalCode || patient.patientCf || patient.cf));
    var effectiveCf = fieldCf || docIdCf;
    var isDocTmp = auditPatientIdentityIsTmp_(docIdCf);
    var isFieldTmp = auditPatientIdentityIsTmp_(fieldCf);

    if (docIdCf) {
      patientsByDocId[docIdCf] = patient;
    }
    if (effectiveCf) {
      if (!patientDocsByCf[effectiveCf]) patientDocsByCf[effectiveCf] = [];
      patientDocsByCf[effectiveCf].push({
        documentId: docIdCf,
        fiscalCode: fieldCf,
        fullName: auditPatientIdentityReadString_(patient && (patient.fullName || patient.patientFullName)),
        isDocumentTmp: isDocTmp,
        isFiscalCodeTmp: isFieldTmp
      });
    }
    if (effectiveCf && !auditPatientIdentityIsTmp_(effectiveCf)) {
      if (!canonicalPatientByCf[effectiveCf]) canonicalPatientByCf[effectiveCf] = patient;
    }
    if (isDocTmp || isFieldTmp) {
      tmpPatients.push({
        documentId: docIdCf,
        fiscalCode: fieldCf,
        fullName: auditPatientIdentityReadString_(patient && (patient.fullName || patient.patientFullName))
      });
      auditPatientIdentityPushSample_(samples.tmpPatients, tmpPatients[tmpPatients.length - 1], maxSamples);
    }
    if (isDocTmp && fieldCf && !isFieldTmp) {
      tmpWithRealFiscalCodeCandidates.push({
        temporaryDocumentId: docIdCf,
        targetFiscalCode: fieldCf,
        fullName: auditPatientIdentityReadString_(patient && (patient.fullName || patient.patientFullName))
      });
    }
    if (docIdCf && fieldCf && docIdCf !== fieldCf) {
      auditPatientIdentityPushSample_(samples.documentIdFiscalCodeMismatches, {
        documentId: docIdCf,
        fiscalCode: fieldCf,
        documentIsTmp: isDocTmp,
        fiscalCodeIsTmp: isFieldTmp,
        fullName: auditPatientIdentityReadString_(patient && (patient.fullName || patient.patientFullName))
      }, maxSamples);
    }
  });

  tmpWithRealFiscalCodeCandidates.forEach(function (candidate) {
    auditPatientIdentityPushSample_(samples.tmpWithRealFiscalCode, {
      temporaryDocumentId: candidate.temporaryDocumentId,
      targetFiscalCode: candidate.targetFiscalCode,
      targetExists: !!canonicalPatientByCf[candidate.targetFiscalCode],
      fullName: candidate.fullName
    }, maxSamples);
    auditPatientIdentityPushSample_(samples.mergeCandidates, {
      reason: 'tmp_with_real_fiscal_code',
      sourceId: candidate.temporaryDocumentId,
      targetId: candidate.targetFiscalCode
    }, maxSamples);
  });

  Object.keys(patientDocsByCf).sort().forEach(function (cf) {
    var docs = patientDocsByCf[cf] || [];
    if (docs.length > 1) {
      auditPatientIdentityPushSample_(samples.duplicateFiscalCodeGroups, {
        fiscalCode: cf,
        count: docs.length,
        docsSample: docs.slice(0, maxSamples)
      }, maxSamples);
      if (!auditPatientIdentityIsTmp_(cf)) {
        docs.forEach(function (doc) {
          if (doc.documentId && doc.documentId !== cf) {
            auditPatientIdentityPushSample_(samples.mergeCandidates, {
              reason: 'duplicate_patient_fiscal_code',
              sourceId: doc.documentId,
              targetId: cf
            }, maxSamples);
          }
        });
      }
    }
  });

  var indexByCf = {};
  indexes.forEach(function (item) {
    var cf = normalizeCf_(item && (item.fiscalCode || item.patientFiscalCode || item.documentId || item.id));
    if (!cf) return;
    indexByCf[cf] = item;
    if (!canonicalPatientByCf[cf]) {
      auditPatientIdentityPushSample_(samples.indexesWithoutCanonicalPatient, {
        fiscalCode: cf,
        fullName: auditPatientIdentityReadString_(item && (item.fullName || item.patientFullName)),
        hasRecipes: item && item.hasRecipes === true,
        hasDebt: item && item.hasDebt === true,
        hasAdvance: item && item.hasAdvance === true,
        hasBooking: item && item.hasBooking === true
      }, maxSamples);
      if (!auditPatientIdentityIsTmp_(cf)) {
        auditPatientIdentityPushSample_(samples.mergeCandidates, {
          reason: 'index_without_canonical_patient',
          sourceId: 'patient_dashboard_index/' + cf,
          targetId: cf
        }, maxSamples);
      }
    }
  });

  Object.keys(canonicalPatientByCf).sort().forEach(function (cf) {
    if (!indexByCf[cf]) {
      auditPatientIdentityPushSample_(samples.patientsWithoutIndex, {
        fiscalCode: cf,
        fullName: auditPatientIdentityReadString_(canonicalPatientByCf[cf] && (canonicalPatientByCf[cf].fullName || canonicalPatientByCf[cf].patientFullName))
      }, maxSamples);
    }
  });

  var operationalCountsBySource = {};
  auditPatientIdentityAuditOperationalDocs_(imports, 'drive_pdf_imports', canonicalPatientByCf, samples, maxSamples, operationalCountsBySource);
  auditPatientIdentityAuditOperationalDocs_(debts, 'debts', canonicalPatientByCf, samples, maxSamples, operationalCountsBySource);
  auditPatientIdentityAuditOperationalDocs_(advances, 'advances', canonicalPatientByCf, samples, maxSamples, operationalCountsBySource);
  auditPatientIdentityAuditOperationalDocs_(bookings, 'bookings', canonicalPatientByCf, samples, maxSamples, operationalCountsBySource);

  families.forEach(function (family) {
    var familyId = auditPatientIdentityReadDocumentId_(family);
    var members = auditPatientIdentityReadFamilyMembers_(family);
    var normalizedMembers = [];
    var seen = {};
    var duplicates = [];
    var tmpMembers = [];
    members.forEach(function (raw) {
      var cf = normalizeCf_(raw);
      if (!cf) return;
      normalizedMembers.push(cf);
      if (seen[cf]) duplicates.push(cf);
      seen[cf] = true;
      if (auditPatientIdentityIsTmp_(cf)) tmpMembers.push(cf);
    });
    if (tmpMembers.length) {
      var uniqueTmpMembers = auditPatientIdentityUnique_(tmpMembers);
      auditPatientIdentityPushSample_(samples.familiesWithTmpMembers, {
        familyId: familyId,
        tmpMemberCount: tmpMembers.length,
        tmpMembersSample: uniqueTmpMembers.slice(0, maxSamples)
      }, maxSamples);
    }
    if (duplicates.length) {
      var uniqueDuplicateMembers = auditPatientIdentityUnique_(duplicates);
      auditPatientIdentityPushSample_(samples.familiesWithDuplicateMembers, {
        familyId: familyId,
        duplicateMemberCount: duplicates.length,
        duplicateMembersSample: uniqueDuplicateMembers.slice(0, maxSamples)
      }, maxSamples);
    }
  });

  doctorLinks.forEach(function (link) {
    var linkId = auditPatientIdentityReadDocumentId_(link);
    var cf = normalizeCf_(link && (link.patientFiscalCode || link.fiscalCode || link.patientCf));
    if (!cf && linkId) cf = normalizeCf_(String(linkId).split('__')[0]);
    if (!cf) return;
    if (auditPatientIdentityIsTmp_(cf) || !canonicalPatientByCf[cf]) {
      auditPatientIdentityPushSample_(samples.doctorLinksWithTmpOrMissingPatient, {
        linkId: linkId,
        fiscalCode: cf,
        isTmp: auditPatientIdentityIsTmp_(cf),
        canonicalPatientExists: !!canonicalPatientByCf[cf]
      }, maxSamples);
    }
  });

  therapeuticAdvice.forEach(function (advice) {
    var docId = normalizeCf_(auditPatientIdentityReadDocumentId_(advice));
    var cf = normalizeCf_(advice && (advice.patientFiscalCode || advice.fiscalCode || advice.patientCf)) || docId;
    if (!cf) return;
    if (!canonicalPatientByCf[cf]) {
      auditPatientIdentityPushSample_(samples.therapeuticAdviceWithoutCanonicalPatient, {
        documentId: docId,
        fiscalCode: cf,
        isTmp: auditPatientIdentityIsTmp_(cf)
      }, maxSamples);
      if (!auditPatientIdentityIsTmp_(cf)) {
        auditPatientIdentityPushSample_(samples.mergeCandidates, {
          reason: 'therapeutic_advice_without_canonical_patient',
          sourceId: 'patient_therapeutic_advice/' + docId,
          targetId: cf
        }, maxSamples);
      }
    }
  });

  var result = {
    ok: true,
    mode: 'read_only',
    source: 'patient_identity_audit',
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
      canonicalPatients: Object.keys(canonicalPatientByCf).length,
      tmpPatients: tmpPatients.length,
      duplicateFiscalCodeGroups: auditPatientIdentityAnomalyCount_(samples.duplicateFiscalCodeGroups),
      tmpWithRealFiscalCode: auditPatientIdentityAnomalyCount_(samples.tmpWithRealFiscalCode),
      documentIdFiscalCodeMismatches: auditPatientIdentityAnomalyCount_(samples.documentIdFiscalCodeMismatches),
      indexesWithoutCanonicalPatient: auditPatientIdentityAnomalyCount_(samples.indexesWithoutCanonicalPatient),
      patientsWithoutIndex: auditPatientIdentityAnomalyCount_(samples.patientsWithoutIndex),
      operationalDocsWithoutCanonicalPatient: auditPatientIdentityAnomalyCount_(samples.operationalDocsWithoutCanonicalPatient),
      familiesWithTmpMembers: auditPatientIdentityAnomalyCount_(samples.familiesWithTmpMembers),
      familiesWithDuplicateMembers: auditPatientIdentityAnomalyCount_(samples.familiesWithDuplicateMembers),
      doctorLinksWithTmpOrMissingPatient: auditPatientIdentityAnomalyCount_(samples.doctorLinksWithTmpOrMissingPatient),
      therapeuticAdviceWithoutCanonicalPatient: auditPatientIdentityAnomalyCount_(samples.therapeuticAdviceWithoutCanonicalPatient),
      mergeCandidates: auditPatientIdentityAnomalyCount_(samples.mergeCandidates)
    },
    operationalDocsWithoutCanonicalPatientBySource: operationalCountsBySource,
    samples: auditPatientIdentityCleanSamples_(samples),
    nextStep: 'Review samples, then design dry-run canonicalizer. This audit performs no writes.'
  };

  logInfo_(cfg, 'auditPatientIdentityConsistency completato', result);
  return result;
}

function auditPatientIdentityAuditOperationalDocs_(items, source, canonicalPatientByCf, samples, maxSamples, countsBySource) {
  countsBySource[source] = countsBySource[source] || 0;
  (items || []).forEach(function (item) {
    var cf = normalizeCf_(item && (item.patientFiscalCode || item.fiscalCode || item.patientCf || item.cf || item.parentDocumentId));
    if (!cf) cf = auditPatientIdentityResolveCfFromPath_(item, source);
    if (!cf) return;
    if (canonicalPatientByCf[cf]) return;
    countsBySource[source]++;
    auditPatientIdentityPushSample_(samples.operationalDocsWithoutCanonicalPatient, {
      source: source,
      documentId: auditPatientIdentityReadDocumentId_(item),
      fiscalCode: cf,
      isTmp: auditPatientIdentityIsTmp_(cf),
      patientName: auditPatientIdentityReadString_(item && (item.patientName || item.patientFullName || item.fullName))
    }, maxSamples);
    if (!auditPatientIdentityIsTmp_(cf)) {
      auditPatientIdentityPushSample_(samples.mergeCandidates, {
        reason: source + '_without_canonical_patient',
        sourceId: source + '/' + auditPatientIdentityReadDocumentId_(item),
        targetId: cf
      }, maxSamples);
    }
  });
}

function auditPatientIdentityReadDocumentId_(item) {
  if (!item) return '';
  var direct = item.documentId || item.id;
  if (direct !== undefined && direct !== null && String(direct).trim()) return String(direct).trim();
  var raw = String(item.documentName || item.documentPath || item.name || '').trim();
  if (!raw) return '';
  var parts = raw.split('/');
  return parts.length ? decodeURIComponent(parts[parts.length - 1]) : '';
}

function auditPatientIdentityResolveCfFromPath_(item, collectionId) {
  var raw = String((item && (item.documentName || item.documentPath || item.name)) || '').trim();
  if (!raw) return '';
  var match = raw.match(new RegExp('/patients/([^/]+)/' + collectionId + '/'));
  return match ? normalizeCf_(decodeURIComponent(match[1])) : '';
}

function auditPatientIdentityReadFamilyMembers_(family) {
  if (!family) return [];
  if (Array.isArray(family.memberFiscalCodes)) return family.memberFiscalCodes;
  if (Array.isArray(family.members)) {
    return family.members.map(function (item) {
      return item && item.fiscalCode ? item.fiscalCode : item;
    });
  }
  return [];
}

function auditPatientIdentityIsTmp_(value) {
  return String(value || '').trim().toUpperCase().indexOf('TMP_') === 0;
}

function auditPatientIdentityReadString_(value) {
  return value === undefined || value === null ? '' : String(value).trim();
}

function auditPatientIdentityPushSample_(target, value, maxSamples) {
  if (!target) return;
  target._auditTotal = Number(target._auditTotal || 0) + 1;
  if (target.length >= maxSamples) return;
  target.push(value);
}

function auditPatientIdentityAnomalyCount_(target) {
  return Number((target && target._auditTotal) || 0);
}

function auditPatientIdentityCleanSamples_(samples) {
  var out = {};
  Object.keys(samples || {}).forEach(function (key) {
    out[key] = (samples[key] || []).slice(0);
  });
  return out;
}

function auditPatientIdentityNormalizeMaxSamples_(value) {
  var parsed = Number(value);
  if (!isFinite(parsed) || parsed <= 0) {
    parsed = 30;
  }
  return Math.max(1, Math.min(100, Math.floor(parsed)));
}

function auditPatientIdentityUnique_(items) {
  var out = [];
  var seen = {};
  (items || []).forEach(function (item) {
    var value = String(item || '').trim();
    if (!value || seen[value]) return;
    seen[value] = true;
    out.push(value);
  });
  return out;
}
