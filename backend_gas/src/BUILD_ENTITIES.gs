function buildSyncPayloadFromManifests_(manifests, options) {
  var unitsResult = buildSyncUnitsFromManifests_(manifests, options);
  var imports = [];
  var patients = [];
  var doctorLinks = [];

  unitsResult.units.forEach(function (unit) {
    unit.imports.forEach(function (entry) { imports.push(entry); });
    if (unit.patient) patients.push(unit.patient);
    if (unit.doctorLink) doctorLinks.push(unit.doctorLink);
  });

  return {
    imports: imports,
    patients: patients,
    doctorLinks: doctorLinks,
    units: unitsResult.units,
    meta: unitsResult.meta
  };
}

function buildSyncUnitsFromManifests_(manifests, options) {
  options = options || {};
  var activeVisible = manifests.filter(function (item) {
    return isActiveVisibleManifestForSync_(item);
  });

  var changedManifests = manifests.filter(function (item) {
    return item && item.syncNeeded && item.patientFiscalCode;
  }).slice().sort(function (a, b) {
    var da = parseDateValue_(a.updatedAt) || new Date(0);
    var db = parseDateValue_(b.updatedAt) || new Date(0);
    return da.getTime() - db.getTime();
  });

  var activeByCf = {};
  activeVisible.forEach(function (item) {
    var cf = normalizeCf_(item.patientFiscalCode);
    if (!cf) return;
    if (!activeByCf[cf]) activeByCf[cf] = [];
    activeByCf[cf].push(item);
  });

  var historicalByCf = {};
  (manifests || []).forEach(function (item) {
    var cf = normalizeCf_(item && item.patientFiscalCode);
    if (!cf) return;
    if (!historicalByCf[cf]) historicalByCf[cf] = [];
    historicalByCf[cf].push(item);
  });

  var changedByCf = {};
  var cfOrder = [];
  changedManifests.forEach(function (item) {
    var cf = normalizeCf_(item.patientFiscalCode);
    if (!cf) return;
    if (!changedByCf[cf]) {
      changedByCf[cf] = [];
      cfOrder.push(cf);
    }
    changedByCf[cf].push(item);
  });

  var maxWrites = Number(options.maxWrites || 0);
  var units = [];
  var selectedWrites = 0;

  for (var i = 0; i < cfOrder.length; i++) {
    var cf = cfOrder[i];
    var unit = buildSyncUnitForCf_(cf, changedByCf[cf], activeByCf[cf] || [], historicalByCf[cf] || []);
    var estimatedWrites = unit.estimatedWrites;
    if (maxWrites > 0 && units.length > 0 && selectedWrites + estimatedWrites > maxWrites) {
      break;
    }
    units.push(unit);
    selectedWrites += estimatedWrites;
  }

  return {
    units: units,
    meta: {
      totalPendingUnits: cfOrder.length,
      selectedUnits: units.length,
      deferredUnits: Math.max(0, cfOrder.length - units.length),
      estimatedWrites: selectedWrites
    }
  };
}

function buildSyncUnitForCf_(cf, changedManifestsForCf, activeCanonicalsForCf, historicalManifestsForCf) {
  var imports = (changedManifestsForCf || []).map(function (item) {
    return buildDriveImportDocument_(item);
  });

  var patient = null;
  var doctorLink = null;
  var stableDoctorManifests = selectStableDoctorSourceManifestsForCf_(historicalManifestsForCf || []);

  if (!(activeCanonicalsForCf || []).length) {
    patient = buildDeletedPatientDocument_(cf, stableDoctorManifests);
  } else {
    patient = buildPatientDocument_(cf, activeCanonicalsForCf);
  }

  if (stableDoctorManifests.length) {
    doctorLink = buildDoctorLinkDocument_(cf, stableDoctorManifests, patient && patient.fullName);
  }

  return {
    cf: cf,
    manifestIds: uniqueNonEmptyStrings_((changedManifestsForCf || []).map(function (item) { return item.driveFileId; })),
    imports: imports,
    patient: patient,
    doctorLink: doctorLink,
    estimatedWrites: imports.length + (patient ? 1 : 0) + (doctorLink ? 1 : 0)
  };
}

function buildDriveImportDocument_(manifest) {
  var exemptions = extractManifestExemptionsForProjection_(manifest);
  var primaryExemption = exemptions.length ? exemptions[0] : '';
  return {
    collection: 'drive_pdf_imports',
    documentId: manifest.driveFileId,
    data: {
      id: manifest.driveFileId,
      driveFileId: manifest.driveFileId,
      fileId: manifest.driveFileId,
      fileName: manifest.fileName,
      mimeType: manifest.mimeType || MimeType.PDF,
      status: manifest.status,
      kind: manifest.kind || '',
      canonicalGroupKey: manifest.canonicalGroupKey || '',
      canonicalFileId: manifest.canonicalFileId || manifest.driveFileId,
      mergeSignature: manifest.mergeSignature || '',
      componentFileIds: manifest.componentFileIds || [],
      componentSourceKeys: manifest.componentSourceKeys || [],
      representedSourceCount: manifest.representedSourceCount || 0,
      supersededByCanonical: manifest.supersededByCanonical || '',
      mergedAt: manifest.mergedAt || null,
      errorMessage: manifest.errorMessage || '',
      patientFiscalCode: normalizeCf_(manifest.patientFiscalCode),
      patientFullName: manifest.patientFullName || '',
      doctorFullName: manifest.doctorFullName || '',
      exemptionCode: primaryExemption || '',
      exemptions: exemptions,
      exemption: primaryExemption || '',
      city: manifest.city || '',
      therapy: manifest.therapy || [],
      isDpc: !!manifest.isDpc,
      prescriptionNres: manifest.prescriptionNres || [],
      prescriptionIdentityKeys: getManifestPrescriptionKeys_(manifest),
      prescriptionCount: resolveManifestPrescriptionCount_(manifest),
      prescriptionDate: manifest.prescriptionDate || null,
      filenameFiscalCode: manifest.filenameFiscalCode || '',
      filenamePrescriptionDate: manifest.filenamePrescriptionDate || null,
      filenameContentMismatch: !!manifest.filenameContentMismatch,
      parentFolderId: manifest.parentFolderId || '',
      parentFolderName: manifest.parentFolderName || '',
      webViewLink: manifest.webViewLink || '',
      openUrl: manifest.webViewLink || '',
      pdfDeleted: !!manifest.pdfDeleted,
      sourceType: manifest.sourceType || 'script',
      sourceKeyCount: getManifestSourceKeys_(manifest).length,
      isActiveArchiveItem: !!(manifest.status === 'parsed' && !manifest.pdfDeleted && !manifest.deletePdfRequested && (manifest.kind || '') !== 'merged_component' && (manifest.kind || '') !== 'canonical_source_retained' && (manifest.kind || '') !== 'merge_pending_component'),
      createdAt: manifest.createdAt,
      updatedAt: manifest.updatedAt,
      deletePdfRequested: !!manifest.deletePdfRequested,
      deleteRequestedAt: manifest.deleteRequestedAt || null,
      deleteRequestedBy: manifest.deleteRequestedBy || '',
      deletedAt: manifest.deletedAt || null
    }
  };
}

function extractManifestExemptionsForProjection_(manifest) {
  return uniqueNonEmptyStrings_([].concat(
    (manifest && manifest.exemptions) || [],
    (manifest && manifest.exemptionCode) || '',
    (manifest && manifest.exemption) || ''
  ));
}

function buildPatientDocument_(cf, manifestsForPatient) {
  manifestsForPatient.sort(compareManifestByDateDesc_);
  var fullName = choosePreferredValue_(manifestsForPatient.map(function (item) { return item.patientFullName; })) || 'Assistito senza nome';
  var city = choosePreferredValue_(manifestsForPatient.map(function (item) { return item.city; }));
  var doctor = choosePreferredValue_(manifestsForPatient.map(function (item) { return item.doctorFullName; }));
  var exemptions = uniqueNonEmptyStrings_(manifestsForPatient.reduce(function (acc, item) {
    return acc.concat(item.exemptions || [], item.exemptionCode || '');
  }, []));
  var therapies = uniqueNonEmptyStrings_(manifestsForPatient.reduce(function (acc, item) {
    return acc.concat(item.therapy || []);
  }, []));
  var archiveAggregate = aggregateVisibleArchiveStatsForPatient_(manifestsForPatient);

  var lastDate = chooseLatestPrescriptionDate_(manifestsForPatient);
  var createdAt = manifestsForPatient.reduce(function (current, item) {
    if (!current) return item.createdAt || null;
    if (item.createdAt && item.createdAt < current) return item.createdAt;
    return current;
  }, null);

  return {
    collection: 'patients',
    documentId: cf,
    fullName: fullName,
    data: {
      fiscalCode: cf,
      fullName: fullName,
      city: city || null,
      exemptionCode: exemptions.length ? exemptions[0] : null,
      exemption: exemptions.length ? exemptions[0] : null,
      exemptions: exemptions,
      doctorName: doctor || null,
      doctorFullName: doctor || null,
      therapiesSummary: therapies,
      lastPrescriptionDate: lastDate,
      hasDpc: manifestsForPatient.some(function (item) { return !!item.isDpc; }),
      archivedRecipeCount: archiveAggregate.totalRecipes,
      archivedPdfCount: archiveAggregate.totalSourceDocuments,
      activeArchiveDocuments: archiveAggregate.visibleDocuments,
      createdAt: createdAt || new Date().toISOString(),
      updatedAt: new Date().toISOString()
    }
  };
}

function isActiveVisibleManifestForSync_(manifest) {
  return !!(manifest && manifest.status === 'parsed' && !manifest.pdfDeleted && !manifest.deletePdfRequested && manifest.patientFiscalCode && (manifest.kind || '') !== 'merged_component' && (manifest.kind || '') !== 'canonical_source_retained' && (manifest.kind || '') !== 'merge_pending_component');
}

function resolveManifestPrescriptionCount_(manifest) {
  var keys = getManifestPrescriptionKeys_(manifest);
  if (keys.length) return keys.length;
  return Math.max(1, Number((manifest && manifest.prescriptionCount) || 1));
}

function aggregateVisibleArchiveStatsForPatient_(manifestsForPatient) {
  var sorted = (manifestsForPatient || []).slice().sort(function (a, b) {
    var keyDelta = getManifestPrescriptionKeys_(b).length - getManifestPrescriptionKeys_(a).length;
    if (keyDelta !== 0) return keyDelta;
    return compareManifestByDateDesc_(a, b);
  });

  var seenSourceKeys = {};
  var seenPrescriptionKeys = {};
  var totalRecipes = 0;
  var totalSourceDocuments = 0;
  var visibleDocuments = 0;

  sorted.forEach(function (manifest) {
    var sourceKeys = getManifestSourceKeys_(manifest);
    var prescriptionKeys = getManifestPrescriptionKeys_(manifest);
    var unseenSourceKeys = sourceKeys.filter(function (key) {
      var normalizedKey = String(key || '').trim();
      if (!normalizedKey || seenSourceKeys[normalizedKey]) return false;
      return true;
    });
    var unseenPrescriptionKeys = prescriptionKeys.filter(function (key) {
      var normalizedKey = String(key || '').trim();
      if (!normalizedKey || seenPrescriptionKeys[normalizedKey]) return false;
      return true;
    });
    if (!unseenSourceKeys.length && !unseenPrescriptionKeys.length) return;

    unseenSourceKeys.forEach(function (key) {
      seenSourceKeys[String(key).trim()] = true;
    });
    unseenPrescriptionKeys.forEach(function (key) {
      seenPrescriptionKeys[String(key).trim()] = true;
    });

    visibleDocuments++;
    totalSourceDocuments += unseenSourceKeys.length || Math.max(1, getManifestSourceKeys_(manifest).length);
    totalRecipes += prescriptionKeys.length ? unseenPrescriptionKeys.length : resolveManifestPrescriptionCount_(manifest);
  });

  return {
    totalRecipes: totalRecipes,
    totalSourceDocuments: totalSourceDocuments,
    visibleDocuments: visibleDocuments
  };
}

function buildDeletedPatientDocument_(cf, stableDoctorManifests) {
  var manifestsForDoctor = (stableDoctorManifests || []).slice().sort(compareManifestByDateDesc_);
  var doctor = choosePreferredValue_(manifestsForDoctor.map(function (item) { return item.doctorFullName; }));
  var doctorParts = String(doctor || '').trim().split(/\s+/).filter(function (part) { return part; });
  var givenNames = doctorParts.length > 1 ? doctorParts.slice(1).join(' ') : (doctor || null);

  return {
    collection: 'patients',
    documentId: cf,
    fullName: '',
    data: {
      fiscalCode: cf,
      fullName: 'Assistito senza nome',
      city: null,
      exemptionCode: null,
      exemption: null,
      exemptions: [],
      doctorName: doctor ? givenNames : null,
      doctorFullName: doctor || null,
      therapiesSummary: [],
      lastPrescriptionDate: null,
      hasDpc: false,
      archivedRecipeCount: 0,
      archivedPdfCount: 0,
      activeArchiveDocuments: 0,
      updatedAt: new Date().toISOString()
    }
  };
}

function selectStableDoctorSourceManifestsForCf_(historicalManifestsForCf) {
  return (historicalManifestsForCf || []).filter(function (manifest) {
    if (!manifest) return false;
    if (!normalizeCf_(manifest.patientFiscalCode)) return false;
    if (!String(manifest.doctorFullName || '').trim()) return false;
    var kind = String(manifest.kind || '').trim();
    if (kind === 'merged_component') return false;
    var status = String(manifest.status || '').trim();
    return status === 'parsed' || status === 'deleted_pdf';
  }).slice().sort(compareManifestByDateDesc_);
}

function buildDoctorLinkDocument_(cf, manifestsForPatient, patientFullName) {
  manifestsForPatient.sort(compareManifestByDateDesc_);
  var doctor = choosePreferredValue_(manifestsForPatient.map(function (item) { return item.doctorFullName; }));
  if (!doctor) return null;
  var resolvedPatientFullName = String(patientFullName || '').trim() || choosePreferredValue_(manifestsForPatient.map(function (item) { return item.patientFullName; })) || '';
  var id = cf + '__primary';
  var parts = doctor.split(/\s+/).filter(function (part) { return part; });
  var surname = parts.length ? parts[0] : doctor;
  var givenNames = parts.length > 1 ? parts.slice(1).join(' ') : doctor;
  return {
    collection: 'doctor_patient_links',
    documentId: id,
    data: {
      id: id,
      patientFiscalCode: cf,
      patientFullName: resolvedPatientFullName,
      doctorFullName: doctor,
      doctorName: givenNames,
      doctorSurname: surname,
      city: choosePreferredValue_(manifestsForPatient.map(function (item) { return item.city; })),
      updatedAt: new Date().toISOString()
    }
  };
}

function chooseLatestPrescriptionDate_(manifestsForPatient) {
  var latest = null;
  manifestsForPatient.forEach(function (item) {
    var date = parseDateValue_(item.prescriptionDate);
    if (!date) return;
    if (!latest || date.getTime() > latest.getTime()) {
      latest = date;
    }
  });
  return latest ? latest.toISOString() : null;
}

function compareManifestByDateDesc_(a, b) {
  var da = parseDateValue_(a.prescriptionDate) || parseDateValue_(a.updatedAt) || new Date(0);
  var db = parseDateValue_(b.prescriptionDate) || parseDateValue_(b.updatedAt) || new Date(0);
  return db.getTime() - da.getTime();
}
