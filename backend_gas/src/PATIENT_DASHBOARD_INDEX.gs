function rebuildPatientDashboardIndex() {
  return rebuildPatientDashboardIndexInternal_({ useLock: true });
}

function rebuildPhboxPatientDashboardIndex() {
  return rebuildPatientDashboardIndex();
}

function rebuildPatientDashboardIndexInternal_(options) {
  options = options || {};
  var lock = null;
  if (options.useLock !== false) {
    lock = LockService.getScriptLock();
    lock.waitLock(20000);
  }
  try {
    var cfg = getPhboxConfig_();
    assertBackendReadyForRun_({ includeDriveOcrProbe: false, includeFirestoreProbe: false, skipGmail: true });
    var nowIso = new Date().toISOString();

    var patientMap = buildPatientDashboardPatientMap_(cfg);
    var doctorMap = buildPatientDashboardDoctorLinkMap_(cfg);
    var archiveMap = buildPatientDashboardArchiveMapFromFirestore_(cfg);
    var prescriptionMap = buildPatientDashboardPrescriptionMapFromFirestore_(cfg);
    var appMaps = buildPatientDashboardAppManagedMaps_(cfg);
    var familyMap = buildPatientDashboardFamilyMap_(cfg);
    var existingIndexMap = buildPatientDashboardExistingIndexMap_(cfg);

    var cfSet = {};
    [patientMap, doctorMap, archiveMap, prescriptionMap, appMaps.debts, appMaps.advances, appMaps.bookings, familyMap].forEach(function (source) {
      Object.keys(source || {}).forEach(function (rawCf) {
        var cf = normalizeCf_(rawCf);
        if (cf) cfSet[cf] = true;
      });
    });

    var writes = [];
    var written = 0;
    var skippedUnchanged = 0;
    var cfs = Object.keys(cfSet).sort();
    var maxBatch = Math.max(1, Math.min(500, Number(cfg.maxBatchWrites || 60)));

    cfs.forEach(function (cf) {
      var data = buildPatientDashboardIndexDataForCf_(cf, {
        patient: patientMap[cf] || null,
        doctorLink: doctorMap[cf] || null,
        archive: archiveMap[cf] || null,
        prescriptions: prescriptionMap[cf] || null,
        debts: appMaps.debts[cf] || null,
        advances: appMaps.advances[cf] || null,
        bookings: appMaps.bookings[cf] || null,
        family: familyMap[cf] || null,
        existing: existingIndexMap[cf] || null,
        nowIso: nowIso,
        source: 'phbox_backend_rebuild'
      });
      if (isPatientDashboardIndexEquivalent_(existingIndexMap[cf] || null, data)) {
        skippedUnchanged++;
        return;
      }
      writes.push(buildFirestoreUpdateWrite_(cfg, 'patient_dashboard_index', cf, data));
      if (writes.length >= maxBatch) {
        executeFirestoreCommit_(cfg, writes);
        written += writes.length;
        writes = [];
      }
    });

    if (writes.length) {
      executeFirestoreCommit_(cfg, writes);
      written += writes.length;
    }

    var result = {
      ok: true,
      source: 'patient_dashboard_index_rebuild',
      patientsSeen: Object.keys(patientMap).length,
      doctorLinksSeen: Object.keys(doctorMap).length,
      archivePatientsSeen: Object.keys(archiveMap).length,
      prescriptionPatientsSeen: Object.keys(prescriptionMap).length,
      debtsPatientsSeen: Object.keys(appMaps.debts || {}).length,
      advancesPatientsSeen: Object.keys(appMaps.advances || {}).length,
      bookingsPatientsSeen: Object.keys(appMaps.bookings || {}).length,
      familyPatientsSeen: Object.keys(familyMap).length,
      existingIndexSeen: Object.keys(existingIndexMap).length,
      cfs: cfs.length,
      written: written,
      skippedUnchanged: skippedUnchanged,
      updatedAt: nowIso
    };
    logInfo_(cfg, 'rebuildPatientDashboardIndex completato', result);
    return result;
  } finally {
    if (lock) lock.releaseLock();
  }
}

function syncPatientDashboardIndexForFiscalCode(cf) {
  return syncPatientDashboardIndexForFiscalCodeInternal_(cf, { useLock: true });
}

function syncPatientDashboardIndexForFiscalCodeInternal_(cf, options) {
  options = options || {};
  cf = normalizeCf_(cf);
  if (!cf) return { ok: false, reason: 'empty_cf', written: 0 };

  var lock = null;
  if (options.useLock !== false) {
    lock = LockService.getScriptLock();
    lock.waitLock(20000);
  }
  try {
    var cfg = getPhboxConfig_();
    var nowIso = new Date().toISOString();
    var existing = getFirestoreDocumentByPathSafe_(cfg, ['patient_dashboard_index', cf]);
    var patient = getFirestoreDocumentByPathSafe_(cfg, ['patients', cf]);
    var doctorLink = getFirestoreDocumentByPathSafe_(cfg, ['doctor_patient_links', cf + '__primary']) || fetchFirstPatientDashboardDoctorLinkForCf_(cfg, cf);
    var archive = buildPatientDashboardArchiveAggregateFromItems_(fetchPatientDashboardDriveImportsForCf_(cfg, cf));
    var prescriptions = buildPatientDashboardPrescriptionAggregateFromItems_(fetchPatientDashboardPrescriptionsForCf_(cfg, cf));
    var debts = buildPatientDashboardDebtAggregateFromItems_(fetchPatientDashboardAppDocsForCf_(cfg, cf, 'debts'));
    var advances = buildPatientDashboardAdvanceAggregateFromItems_(fetchPatientDashboardAppDocsForCf_(cfg, cf, 'advances'));
    var bookings = buildPatientDashboardBookingAggregateFromItems_(fetchPatientDashboardAppDocsForCf_(cfg, cf, 'bookings'));
    var family = fetchPatientDashboardFamilyForCf_(cfg, cf);

    if (!patient && !doctorLink && !archive && !prescriptions && !debts && !advances && !bookings && !family && !existing) {
      return { ok: true, reason: 'no_source_data', cf: cf, written: 0 };
    }

    var data = buildPatientDashboardIndexDataForCf_(cf, {
      patient: patient,
      doctorLink: doctorLink,
      archive: archive,
      prescriptions: prescriptions,
      debts: debts,
      advances: advances,
      bookings: bookings,
      family: family,
      existing: existing,
      nowIso: nowIso,
      source: 'phbox_backend_single_sync'
    });

    if (isPatientDashboardIndexEquivalent_(existing, data)) {
      return { ok: true, cf: cf, written: 0, skippedUnchanged: true };
    }

    executeFirestoreCommit_(cfg, [buildFirestoreUpdateWrite_(cfg, 'patient_dashboard_index', cf, data)]);
    return { ok: true, cf: cf, written: 1, updatedAt: nowIso };
  } finally {
    if (lock) lock.releaseLock();
  }
}

function syncPatientDashboardIndexForFiscalCodes_(cfs, options) {
  options = options || {};
  var out = {
    ok: true,
    cfsSeen: 0,
    written: 0,
    skippedUnchanged: 0,
    errors: []
  };
  uniqueNonEmptyStrings_((cfs || []).map(function (cf) { return normalizeCf_(cf); })).forEach(function (cf) {
    out.cfsSeen++;
    try {
      var result = syncPatientDashboardIndexForFiscalCodeInternal_(cf, { useLock: false });
      out.written += Number(result.written || 0);
      if (result.skippedUnchanged) out.skippedUnchanged++;
    } catch (e) {
      out.ok = false;
      out.errors.push({ cf: cf, error: normalizeRuntimeErrorMessage_(e) });
    }
  });
  return out;
}

function validatePatientDashboardIndex() {
  var cfg = getPhboxConfig_();
  var patientMap = buildPatientDashboardPatientMap_(cfg);
  var indexMap = buildPatientDashboardExistingIndexMap_(cfg);
  var patientsWithoutIndex = 0;
  var indexesWithoutPatient = 0;
  var recordsWithoutSearchPrefixes = 0;
  var recordsWithIncoherentFlags = 0;

  Object.keys(patientMap).forEach(function (cf) {
    if (!indexMap[cf]) patientsWithoutIndex++;
  });
  Object.keys(indexMap).forEach(function (cf) {
    var item = indexMap[cf] || {};
    if (!patientMap[cf]) indexesWithoutPatient++;
    if (!Array.isArray(item.searchPrefixes) || item.searchPrefixes.length === 0) recordsWithoutSearchPrefixes++;
    if (!isPatientDashboardIndexFlagsCoherent_(item)) recordsWithIncoherentFlags++;
  });

  var result = {
    ok: true,
    patients: Object.keys(patientMap).length,
    indexes: Object.keys(indexMap).length,
    patientsWithoutIndex: patientsWithoutIndex,
    indexesWithoutPatient: indexesWithoutPatient,
    recordsWithoutSearchPrefixes: recordsWithoutSearchPrefixes,
    recordsWithIncoherentFlags: recordsWithIncoherentFlags,
    valid: patientsWithoutIndex === 0 && recordsWithoutSearchPrefixes === 0 && recordsWithIncoherentFlags === 0,
    checkedAt: new Date().toISOString()
  };
  logInfo_(cfg, 'validatePatientDashboardIndex completato', result);
  return result;
}

function buildPatientDashboardArchiveIndexPatch_(cf, activeManifests, historicalManifests, cfg) {
  cf = normalizeCf_(cf);
  if (!cf) return null;
  var archive = buildPatientDashboardArchiveFields_(cf, activeManifests || [], historicalManifests || [], cfg);
  archive.updatedAt = new Date().toISOString();
  archive.source = 'phbox_backend_archive_patch';
  return buildFirestorePatchWrite_(cfg, 'patient_dashboard_index', cf, archive, Object.keys(archive));
}

function buildPatientDashboardArchiveFields_(cf, activeManifests, historicalManifests, cfg) {
  var stable = selectStableDoctorSourceManifestsForCf_(historicalManifests || []);
  var source = (activeManifests && activeManifests.length ? activeManifests : stable).filter(function (item) { return !!item; });
  var first = source.length ? source[0] : null;
  var recipeCount = 0;
  var dpcCount = 0;
  var lastPrescriptionDate = null;
  var nearestExpiry = null;

  (activeManifests || []).forEach(function (manifest) {
    recipeCount += resolveManifestPrescriptionCount_(manifest);
    if (manifest && manifest.isDpc) dpcCount++;
    var baseDate = parseDashboardTotalsDate_(manifest && (manifest.prescriptionDate || manifest.createdAt));
    if (baseDate && (!lastPrescriptionDate || baseDate.getTime() > lastPrescriptionDate.getTime())) lastPrescriptionDate = baseDate;
    var expiry = baseDate ? addDaysForDashboardTotals_(baseDate, 30) : null;
    if (expiry && (!nearestExpiry || expiry.getTime() < nearestExpiry.getTime())) nearestExpiry = expiry;
  });

  var fullName = String((first && first.patientFullName) || cf).trim();
  var doctorFullName = String((first && first.doctorFullName) || '').trim();
  var city = String((first && first.city) || '').trim();
  var exemptions = uniqueNonEmptyStrings_([first && first.exemptionCode, first && first.exemption].concat((first && first.exemptions) || []));
  var exemptionCode = exemptions.length ? exemptions[0] : '';
  var hasExpiry = isDashboardExpiryAlert_(nearestExpiry);

  return {
    schemaVersion: 1,
    fiscalCode: cf,
    fullName: fullName,
    doctorFullName: doctorFullName,
    city: city,
    exemptionCode: exemptionCode,
    exemptions: exemptions,
    recipeCount: Math.max(0, recipeCount),
    dpcCount: Math.max(0, dpcCount),
    hasRecipes: recipeCount > 0,
    hasDpc: dpcCount > 0,
    hasExpiry: !!hasExpiry,
    lastPrescriptionDate: lastPrescriptionDate ? lastPrescriptionDate.toISOString() : null,
    nearestExpiryDate: nearestExpiry ? nearestExpiry.toISOString() : null,
    archiveUpdatedAt: new Date().toISOString(),
    searchPrefixes: buildPatientDashboardSearchPrefixes_([cf, fullName, doctorFullName, city, exemptionCode].concat(exemptions))
  };
}

function buildPatientDashboardIndexDataForCf_(cf, sources) {
  sources = sources || {};
  var patient = sources.patient || {};
  var doctorLink = sources.doctorLink || {};
  var archive = sources.archive || {};
  var prescriptions = sources.prescriptions || {};
  var debts = sources.debts || { count: 0, amount: 0, names: [] };
  var advances = sources.advances || { count: 0, doctors: [], names: [] };
  var bookings = sources.bookings || { count: 0, names: [] };
  var family = sources.family || { id: '', name: '', colorIndex: 0 };
  var existing = sources.existing || {};

  var archiveRecipeCount = Number(archive.recipeCount || 0);
  var prescriptionRecipeCount = Number(prescriptions.recipeCount || 0);
  var recipeCount = archiveRecipeCount > 0 ? archiveRecipeCount : prescriptionRecipeCount;
  var dpcCount = archiveRecipeCount > 0 ? Number(archive.dpcCount || 0) : Number(prescriptions.dpcCount || 0);
  var nearestExpiryDate = archiveRecipeCount > 0 ? (archive.nearestExpiryDate || null) : (prescriptions.nearestExpiryDate || null);
  var lastPrescriptionDate = archiveRecipeCount > 0 ? (archive.lastPrescriptionDate || null) : (prescriptions.lastPrescriptionDate || null);

  var fullName = keepExistingIfEmpty_(choosePreferredValue_([
    patient.fullName,
    patient.patientFullName,
    archive.fullName,
    prescriptions.fullName,
    firstPatientDashboardListValue_(debts.names),
    firstPatientDashboardListValue_(advances.names),
    firstPatientDashboardListValue_(bookings.names)
  ]), existing.fullName, cf);
  var alias = keepExistingIfEmpty_(patient.alias, existing.alias, '');
  var doctorFullName = keepExistingIfEmpty_(choosePreferredValue_([
    patient.doctorFullName,
    patient.doctorName,
    doctorLink.doctorFullName,
    doctorLink.doctorName,
    archive.doctorFullName,
    prescriptions.doctorFullName,
    firstPatientDashboardListValue_(advances.doctors)
  ]), existing.doctorFullName, '');
  var city = keepExistingIfEmpty_(choosePreferredValue_([patient.city, doctorLink.city, archive.city, prescriptions.city]), existing.city, '');
  var exemptions = uniqueNonEmptyStrings_([].concat(
    patient.exemptions || [],
    patient.exemptionCode || '',
    patient.exemption || '',
    archive.exemptions || [],
    archive.exemptionCode || '',
    prescriptions.exemptions || [],
    prescriptions.exemptionCode || '',
    existing.exemptions || [],
    existing.exemptionCode || ''
  ));
  var exemptionCode = keepExistingIfEmpty_(exemptions.length ? exemptions[0] : '', existing.exemptionCode, '');
  if (exemptionCode) exemptions = uniqueNonEmptyStrings_([exemptionCode].concat(exemptions));

  var debtCount = Math.max(0, Number(debts.count || 0));
  var debtAmount = roundDashboardTotalsAmount_(Number(debts.amount || 0));
  var advanceCount = Math.max(0, Number(advances.count || 0));
  var bookingCount = Math.max(0, Number(bookings.count || 0));
  var hasExpiry = !!(nearestExpiryDate && isDashboardExpiryAlert_(parseDashboardTotalsDate_(nearestExpiryDate)));

  return {
    schemaVersion: 1,
    fiscalCode: cf,
    fullName: String(fullName || cf).trim() || cf,
    alias: String(alias || '').trim() || null,
    doctorFullName: String(doctorFullName || '').trim(),
    city: String(city || '').trim(),
    exemptionCode: String(exemptionCode || '').trim(),
    exemptions: exemptions,
    recipeCount: Math.max(0, Number(recipeCount || 0)),
    hasRecipes: Number(recipeCount || 0) > 0,
    hasDpc: Number(dpcCount || 0) > 0,
    hasExpiry: hasExpiry,
    lastPrescriptionDate: lastPrescriptionDate || null,
    nearestExpiryDate: nearestExpiryDate || null,
    debtCount: debtCount,
    debtAmount: debtAmount,
    hasDebt: debtCount > 0 || Math.abs(debtAmount) > 0.005,
    advanceCount: advanceCount,
    hasAdvance: advanceCount > 0,
    bookingCount: bookingCount,
    hasBooking: bookingCount > 0,
    familyId: family.id || existing.familyId || '',
    familyName: family.name || existing.familyName || '',
    familyColorIndex: Number(family.colorIndex || existing.familyColorIndex || 0),
    searchPrefixes: buildPatientDashboardSearchPrefixes_([cf, fullName, alias, doctorFullName, city, exemptionCode, family.name || existing.familyName || ''].concat(exemptions)),
    source: sources.source || 'phbox_backend_index_sync',
    updatedAt: sources.nowIso || new Date().toISOString()
  };
}

function buildPatientDashboardPatientMap_(cfg) {
  var out = {};
  listFirestoreDocumentsByPathSafe_(cfg, ['patients'], { pageSize: 500 }).forEach(function (item) {
    var cf = normalizeCf_(item && (item.fiscalCode || item.patientFiscalCode || item.documentId || item.id));
    if (!cf) return;
    out[cf] = normalizePatientDashboardPatientDoc_(item);
  });
  return out;
}

function buildPatientDashboardDoctorLinkMap_(cfg) {
  var out = {};
  listFirestoreDocumentsByPathSafe_(cfg, ['doctor_patient_links'], { pageSize: 500 }).forEach(function (item) {
    var cf = normalizeCf_(item && (item.patientFiscalCode || item.fiscalCode || item.patientCf || item.documentId));
    if (!cf && item && item.documentId) cf = normalizeCf_(String(item.documentId).split('__')[0]);
    if (!cf) return;
    if (!out[cf]) out[cf] = item;
  });
  return out;
}

function buildPatientDashboardExistingIndexMap_(cfg) {
  var out = {};
  listFirestoreDocumentsByPathSafe_(cfg, ['patient_dashboard_index'], { pageSize: 500 }).forEach(function (item) {
    var cf = normalizeCf_(item && (item.fiscalCode || item.documentId || item.id));
    if (cf) out[cf] = item;
  });
  return out;
}

function buildPatientDashboardArchiveMapFromFirestore_(cfg) {
  var out = {};
  listFirestoreDocumentsByPathSafe_(cfg, ['drive_pdf_imports'], { pageSize: 500 }).forEach(function (item) {
    addPatientDashboardArchiveItemToMap_(out, item);
  });
  Object.keys(out).forEach(function (cf) {
    out[cf] = finalizePatientDashboardArchiveAggregate_(out[cf]);
  });
  return out;
}

function buildPatientDashboardPrescriptionMapFromFirestore_(cfg) {
  var out = {};
  listFirestoreCollectionGroupDocumentsSafe_(cfg, 'prescriptions', {}).forEach(function (item) {
    addPatientDashboardPrescriptionItemToMap_(out, item);
  });
  Object.keys(out).forEach(function (cf) {
    out[cf] = finalizePatientDashboardPrescriptionAggregate_(out[cf]);
  });
  return out;
}

function buildPatientDashboardFamilyMap_(cfg) {
  var out = {};
  listFirestoreDocumentsByPathSafe_(cfg, ['families'], { pageSize: 500 }).forEach(function (family) {
    var members = Array.isArray(family.memberFiscalCodes) ? family.memberFiscalCodes : [];
    if (!members.length && Array.isArray(family.members)) members = family.members;
    members.forEach(function (rawCf) {
      var cf = normalizeCf_(rawCf && rawCf.fiscalCode ? rawCf.fiscalCode : rawCf);
      if (!cf) return;
      out[cf] = normalizePatientDashboardFamilyDoc_(family);
    });
  });
  return out;
}

function buildPatientDashboardAppManagedMaps_(cfg) {
  return {
    debts: buildPatientDashboardDebtMap_(listFirestoreCollectionGroupDocumentsSafe_(cfg, 'debts', {})),
    advances: buildPatientDashboardAdvanceMap_(listFirestoreCollectionGroupDocumentsSafe_(cfg, 'advances', {})),
    bookings: buildPatientDashboardBookingMap_(listFirestoreCollectionGroupDocumentsSafe_(cfg, 'bookings', {}))
  };
}

function buildPatientDashboardDebtMap_(items) {
  var out = {};
  (items || []).forEach(function (item) {
    var cf = resolvePatientDashboardCollectionGroupCf_(item, 'debts');
    if (!cf) return;
    if (isPatientDashboardDeletedAppDoc_(item)) return;
    var residual = readDashboardTotalsNumber_(item.residualAmount !== undefined ? item.residualAmount : (item.amount || item.value));
    if (!out[cf]) out[cf] = { count: 0, amount: 0, names: [] };
    out[cf].count++;
    out[cf].amount += residual;
    if (item.patientName || item.fullName) out[cf].names.push(String(item.patientName || item.fullName).trim());
  });
  Object.keys(out).forEach(function (cf) {
    out[cf].names = uniqueNonEmptyStrings_(out[cf].names);
    out[cf].amount = roundDashboardTotalsAmount_(out[cf].amount);
  });
  return out;
}

function buildPatientDashboardAdvanceMap_(items) {
  var out = {};
  (items || []).forEach(function (item) {
    var cf = resolvePatientDashboardCollectionGroupCf_(item, 'advances');
    if (!cf) return;
    if (isPatientDashboardDeletedAppDoc_(item)) return;
    if (!out[cf]) out[cf] = { count: 0, doctors: [], names: [] };
    out[cf].count++;
    if (item.doctorName || item.doctorFullName) out[cf].doctors.push(String(item.doctorName || item.doctorFullName).trim());
    if (item.patientName || item.fullName) out[cf].names.push(String(item.patientName || item.fullName).trim());
  });
  Object.keys(out).forEach(function (cf) {
    out[cf].doctors = uniqueNonEmptyStrings_(out[cf].doctors);
    out[cf].names = uniqueNonEmptyStrings_(out[cf].names);
  });
  return out;
}

function buildPatientDashboardBookingMap_(items) {
  var out = {};
  (items || []).forEach(function (item) {
    var cf = resolvePatientDashboardCollectionGroupCf_(item, 'bookings');
    if (!cf) return;
    if (isPatientDashboardDeletedAppDoc_(item)) return;
    if (!out[cf]) out[cf] = { count: 0, names: [] };
    out[cf].count++;
    if (item.patientName || item.fullName) out[cf].names.push(String(item.patientName || item.fullName).trim());
  });
  Object.keys(out).forEach(function (cf) { out[cf].names = uniqueNonEmptyStrings_(out[cf].names); });
  return out;
}

function buildPatientDashboardArchiveAggregateFromItems_(items) {
  var aggregate = null;
  (items || []).forEach(function (item) {
    if (!aggregate) aggregate = createEmptyPatientDashboardArchiveAggregate_(normalizeCf_(item && item.patientFiscalCode));
    addPatientDashboardArchiveItemToAggregate_(aggregate, item);
  });
  return aggregate ? finalizePatientDashboardArchiveAggregate_(aggregate) : null;
}

function buildPatientDashboardPrescriptionAggregateFromItems_(items) {
  var aggregate = null;
  (items || []).forEach(function (item) {
    if (!aggregate) aggregate = createEmptyPatientDashboardArchiveAggregate_(normalizeCf_(item && (item.patientFiscalCode || item.fiscalCode)));
    addPatientDashboardPrescriptionItemToAggregate_(aggregate, item);
  });
  return aggregate ? finalizePatientDashboardPrescriptionAggregate_(aggregate) : null;
}

function buildPatientDashboardDebtAggregateFromItems_(items) {
  var map = buildPatientDashboardDebtMap_(items || []);
  var keys = Object.keys(map);
  return keys.length ? map[keys[0]] : null;
}

function buildPatientDashboardAdvanceAggregateFromItems_(items) {
  var map = buildPatientDashboardAdvanceMap_(items || []);
  var keys = Object.keys(map);
  return keys.length ? map[keys[0]] : null;
}

function buildPatientDashboardBookingAggregateFromItems_(items) {
  var map = buildPatientDashboardBookingMap_(items || []);
  var keys = Object.keys(map);
  return keys.length ? map[keys[0]] : null;
}

function addPatientDashboardArchiveItemToMap_(out, item) {
  var cf = normalizeCf_(item && item.patientFiscalCode);
  if (!cf) return;
  if (!out[cf]) out[cf] = createEmptyPatientDashboardArchiveAggregate_(cf);
  addPatientDashboardArchiveItemToAggregate_(out[cf], item);
}

function addPatientDashboardArchiveItemToAggregate_(aggregate, item) {
  if (!aggregate || !item || !isActivePatientDashboardArchiveDoc_(item)) return;
  var count = Math.max(1, Number(item.prescriptionCount || 1));
  aggregate.recipeCount += count;
  if (item.isDpc || item.hasDpc) aggregate.dpcCount++;
  aggregate.names.push(item.patientFullName || item.fullName || '');
  aggregate.doctors.push(item.doctorFullName || item.doctorName || '');
  aggregate.cities.push(item.city || '');
  aggregate.exemptions = aggregate.exemptions.concat(item.exemptions || [], item.exemptionCode || '', item.exemption || '');
  updatePatientDashboardAggregateDates_(aggregate, item.prescriptionDate || item.createdAt || item.updatedAt);
}

function addPatientDashboardPrescriptionItemToMap_(out, item) {
  var cf = normalizeCf_(item && (item.patientFiscalCode || item.fiscalCode));
  if (!cf) cf = normalizeCf_(item && item.parentDocumentId);
  if (!cf) return;
  if (!out[cf]) out[cf] = createEmptyPatientDashboardArchiveAggregate_(cf);
  addPatientDashboardPrescriptionItemToAggregate_(out[cf], item);
}

function addPatientDashboardPrescriptionItemToAggregate_(aggregate, item) {
  if (!aggregate || !item || !isActivePatientDashboardArchiveDoc_(item)) return;
  aggregate.recipeCount++;
  if (item.isDpc || item.hasDpc || item.dpcFlag) aggregate.dpcCount++;
  aggregate.names.push(item.patientFullName || item.patientName || item.fullName || '');
  aggregate.doctors.push(item.doctorFullName || item.doctorName || '');
  aggregate.cities.push(item.city || '');
  aggregate.exemptions = aggregate.exemptions.concat(item.exemptions || [], item.exemptionCode || '', item.exemption || '');
  updatePatientDashboardAggregateDates_(aggregate, item.prescriptionDate || item.date || item.createdAt || item.updatedAt);
}

function createEmptyPatientDashboardArchiveAggregate_(cf) {
  return {
    cf: normalizeCf_(cf),
    recipeCount: 0,
    dpcCount: 0,
    names: [],
    doctors: [],
    cities: [],
    exemptions: [],
    lastPrescriptionDateObj: null,
    nearestExpiryDateObj: null
  };
}

function updatePatientDashboardAggregateDates_(aggregate, rawDate) {
  var baseDate = parseDashboardTotalsDate_(rawDate);
  if (!baseDate) return;
  if (!aggregate.lastPrescriptionDateObj || baseDate.getTime() > aggregate.lastPrescriptionDateObj.getTime()) {
    aggregate.lastPrescriptionDateObj = baseDate;
  }
  var expiry = addDaysForDashboardTotals_(baseDate, 30);
  if (expiry && (!aggregate.nearestExpiryDateObj || expiry.getTime() < aggregate.nearestExpiryDateObj.getTime())) {
    aggregate.nearestExpiryDateObj = expiry;
  }
}

function finalizePatientDashboardArchiveAggregate_(aggregate) {
  if (!aggregate) return null;
  var exemptions = uniqueNonEmptyStrings_(aggregate.exemptions || []);
  return {
    recipeCount: Math.max(0, Number(aggregate.recipeCount || 0)),
    dpcCount: Math.max(0, Number(aggregate.dpcCount || 0)),
    fullName: choosePreferredValue_(uniqueNonEmptyStrings_(aggregate.names || [])) || '',
    doctorFullName: choosePreferredValue_(uniqueNonEmptyStrings_(aggregate.doctors || [])) || '',
    city: choosePreferredValue_(uniqueNonEmptyStrings_(aggregate.cities || [])) || '',
    exemptionCode: exemptions.length ? exemptions[0] : '',
    exemptions: exemptions,
    lastPrescriptionDate: aggregate.lastPrescriptionDateObj ? aggregate.lastPrescriptionDateObj.toISOString() : null,
    nearestExpiryDate: aggregate.nearestExpiryDateObj ? aggregate.nearestExpiryDateObj.toISOString() : null
  };
}

function finalizePatientDashboardPrescriptionAggregate_(aggregate) {
  return finalizePatientDashboardArchiveAggregate_(aggregate);
}

function isActivePatientDashboardArchiveDoc_(item) {
  if (!item) return false;
  if (item.pdfDeleted === true) return false;
  if (item.deletePdfRequested === true) return false;
  var status = String(item.status || '').trim().toLowerCase();
  if (status === 'deleted_pdf' || status === 'deleted' || status === 'trash' || status === 'trashed') return false;
  return true;
}

function isPatientDashboardDeletedAppDoc_(item) {
  if (!item) return true;
  var status = String(item.status || '').trim().toLowerCase();
  return item.deleted === true || item.isDeleted === true || status === 'deleted' || status === 'cancelled' || status === 'canceled';
}

function normalizePatientDashboardPatientDoc_(item) {
  item = item || {};
  return {
    fiscalCode: normalizeCf_(item.fiscalCode || item.patientFiscalCode || item.documentId),
    fullName: String(item.fullName || item.patientFullName || '').trim(),
    alias: String(item.alias || '').trim(),
    doctorFullName: String(item.doctorFullName || item.doctorName || item.doctor || '').trim(),
    doctorName: String(item.doctorName || '').trim(),
    city: String(item.city || '').trim(),
    exemptionCode: String(item.exemptionCode || item.exemption || item.esenzione || '').trim(),
    exemption: String(item.exemption || item.exemptionCode || item.esenzione || '').trim(),
    exemptions: uniqueNonEmptyStrings_((item.exemptions || []).concat(item.exemptionCode || '', item.exemption || '', item.esenzione || ''))
  };
}

function normalizePatientDashboardFamilyDoc_(family) {
  family = family || {};
  return {
    id: String(family.familyId || family.id || family.documentId || '').trim(),
    name: String(family.name || family.familyName || '').trim(),
    colorIndex: Number(family.colorIndex || 0)
  };
}

function resolvePatientDashboardCollectionGroupCf_(item, collectionId) {
  var direct = normalizeCf_(item && (item.patientFiscalCode || item.fiscalCode || item.patientCf));
  if (direct) return direct;
  var parent = normalizeCf_(item && item.parentDocumentId);
  if (parent) return parent;
  var name = String((item && (item.documentName || item.documentPath || item.name)) || '').trim();
  var match = name.match(new RegExp('/patients/([^/]+)/' + collectionId + '/'));
  return match ? normalizeCf_(decodeURIComponent(match[1])) : '';
}

function fetchPatientDashboardDriveImportsForCf_(cfg, cf) {
  return runPatientDashboardFieldEqualsQuery_(cfg, 'drive_pdf_imports', 'patientFiscalCode', cf, false);
}

function fetchPatientDashboardPrescriptionsForCf_(cfg, cf) {
  var out = [];
  out = out.concat(runPatientDashboardFieldEqualsQuery_(cfg, 'prescriptions', 'patientFiscalCode', cf, true));
  out = out.concat(runPatientDashboardFieldEqualsQuery_(cfg, 'prescriptions', 'fiscalCode', cf, true));
  return dedupePatientDashboardDocs_(out);
}

function fetchPatientDashboardAppDocsForCf_(cfg, cf, collectionId) {
  var direct = listFirestoreDocumentsByPathSafe_(cfg, ['patients', cf, collectionId], { pageSize: 200 });
  if (direct.length) return direct;
  return runPatientDashboardFieldEqualsQuery_(cfg, collectionId, 'patientFiscalCode', cf, true);
}

function fetchFirstPatientDashboardDoctorLinkForCf_(cfg, cf) {
  var items = runPatientDashboardFieldEqualsQuery_(cfg, 'doctor_patient_links', 'patientFiscalCode', cf, false);
  return items.length ? items[0] : null;
}

function fetchPatientDashboardFamilyForCf_(cfg, cf) {
  var items = runPatientDashboardArrayContainsQuery_(cfg, 'families', 'memberFiscalCodes', cf, false);
  return items.length ? normalizePatientDashboardFamilyDoc_(items[0]) : null;
}

function runPatientDashboardFieldEqualsQuery_(cfg, collectionId, fieldPath, value, allDescendants) {
  return runPatientDashboardStructuredQuery_(cfg, {
    from: [{ collectionId: String(collectionId || '').trim(), allDescendants: !!allDescendants }],
    where: {
      fieldFilter: {
        field: { fieldPath: String(fieldPath || '').trim() },
        op: 'EQUAL',
        value: toFirestoreValue_(value)
      }
    }
  });
}

function runPatientDashboardArrayContainsQuery_(cfg, collectionId, fieldPath, value, allDescendants) {
  return runPatientDashboardStructuredQuery_(cfg, {
    from: [{ collectionId: String(collectionId || '').trim(), allDescendants: !!allDescendants }],
    where: {
      fieldFilter: {
        field: { fieldPath: String(fieldPath || '').trim() },
        op: 'ARRAY_CONTAINS',
        value: toFirestoreValue_(value)
      }
    }
  });
}

function runPatientDashboardStructuredQuery_(cfg, structuredQuery) {
  try {
    var url = 'https://firestore.googleapis.com/v1/projects/' + encodeURIComponent(cfg.firestoreProjectId) + '/databases/(default)/documents:runQuery';
    var rows = fetchFirestoreJsonWithRetry_(url, {
      method: 'post',
      contentType: 'application/json',
      payload: JSON.stringify({ structuredQuery: structuredQuery })
    });
    if (!Array.isArray(rows)) return [];
    return rows.map(function (row) {
      return row && row.document ? mapFirestoreDocumentToPlainObject_(row.document) : null;
    }).filter(function (item) { return !!item; });
  } catch (e) {
    return [];
  }
}

function listFirestoreDocumentsByPathSafe_(cfg, pathSegments, options) {
  try {
    return listFirestoreDocumentsByPath_(cfg, pathSegments, options || {});
  } catch (e) {
    return [];
  }
}

function listFirestoreCollectionGroupDocumentsSafe_(cfg, collectionId, options) {
  try {
    return listFirestoreCollectionGroupDocuments_(cfg, collectionId, options || {});
  } catch (e) {
    return [];
  }
}

function getFirestoreDocumentByPathSafe_(cfg, pathSegments) {
  try {
    return getFirestoreDocumentByPath_(cfg, pathSegments);
  } catch (e) {
    return null;
  }
}

function dedupePatientDashboardDocs_(items) {
  var seen = {};
  var out = [];
  (items || []).forEach(function (item) {
    var key = String((item && (item.documentPath || item.documentId || item.id)) || JSON.stringify(item || {}));
    if (!key || seen[key]) return;
    seen[key] = true;
    out.push(item);
  });
  return out;
}

function keepExistingIfEmpty_(candidate, existing, fallback) {
  var text = String(candidate || '').trim();
  if (text) return text;
  text = String(existing || '').trim();
  if (text) return text;
  return fallback;
}

function firstPatientDashboardListValue_(values) {
  values = uniqueNonEmptyStrings_(values || []);
  return values.length ? values[0] : '';
}

function isPatientDashboardIndexEquivalent_(existing, next) {
  if (!existing || !next) return false;
  var a = clonePatientDashboardComparable_(existing);
  var b = clonePatientDashboardComparable_(next);
  return computeStableHashForData_(a) === computeStableHashForData_(b);
}

function clonePatientDashboardComparable_(item) {
  var out = {};
  Object.keys(item || {}).sort().forEach(function (key) {
    if (key === 'updatedAt' || key === 'source' || key === 'documentId' || key === 'documentPath' || key === 'collectionId' || key === 'parentDocumentId') return;
    out[key] = item[key];
  });
  return out;
}

function isPatientDashboardIndexFlagsCoherent_(item) {
  if (!item) return false;
  var recipeCount = Number(item.recipeCount || 0);
  var debtCount = Number(item.debtCount || 0);
  var debtAmount = Number(item.debtAmount || 0);
  var advanceCount = Number(item.advanceCount || 0);
  var bookingCount = Number(item.bookingCount || 0);
  if (!!item.hasRecipes !== (recipeCount > 0)) return false;
  if (!!item.hasDebt !== (debtCount > 0 || Math.abs(debtAmount) > 0.005)) return false;
  if (!!item.hasAdvance !== (advanceCount > 0)) return false;
  if (!!item.hasBooking !== (bookingCount > 0)) return false;
  return true;
}

function buildPatientDashboardSearchPrefixes_(values) {
  var out = {};
  (values || []).forEach(function (raw) {
    var text = normalizePatientDashboardSearchText_(raw);
    if (!text) return;
    addPatientDashboardPrefixes_(out, text);
    text.split(' ').forEach(function (part) { addPatientDashboardPrefixes_(out, part); });
  });
  return Object.keys(out).sort().slice(0, 120);
}

function addPatientDashboardPrefixes_(out, text) {
  text = normalizePatientDashboardSearchText_(text);
  if (text.length < 3) return;
  var max = Math.min(24, text.length);
  for (var i = 3; i <= max; i++) out[text.slice(0, i)] = true;
}

function normalizePatientDashboardSearchText_(value) {
  return String(value || '').trim().toUpperCase().replace(/\s+/g, ' ');
}
