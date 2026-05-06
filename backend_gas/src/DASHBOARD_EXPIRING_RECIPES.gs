function buildDashboardExpiringRecipesWriteCandidate_(runtimeIndex, cfg) {
  try {
    runtimeIndex = ensureRuntimeIndexShape_(runtimeIndex, cfg);
    var data = buildDashboardExpiringRecipesDataFromRuntimeIndex_(runtimeIndex, cfg);
    var content = {
      schemaVersion: data.schemaVersion,
      itemCount: data.itemCount,
      totalExpiringCount: data.totalExpiringCount,
      expiringRecipesSignature: data.expiringRecipesSignature || '',
      items: data.items || []
    };
    var nextHash = computeStableHashForData_(content);
    var currentHash = String((runtimeIndex.publishState && runtimeIndex.publishState.dashboardExpiringRecipes) || '');

    if (nextHash === currentHash) {
      return {
        write: null,
        hash: nextHash,
        data: runtimeIndex.publishState.dashboardExpiringRecipesData || data,
        error: ''
      };
    }

    var nowIso = new Date().toISOString();
    data.generatedAt = nowIso;
    data.updatedAt = nowIso;

    return {
      write: buildFirestoreUpdateWrite_(cfg, 'dashboard_expiring_recipes', 'main', data),
      hash: nextHash,
      data: data,
      error: ''
    };
  } catch (e) {
    return {
      write: null,
      hash: '',
      data: null,
      error: normalizeRuntimeErrorMessage_(e)
    };
  }
}

function buildDashboardExpiringRecipesDataFromRuntimeIndex_(runtimeIndex, cfg) {
  var limit = Number((cfg && cfg.dashboardExpiringRecipesLimit) || 80);
  if (isNaN(limit) || limit <= 0) limit = 80;

  var manifests = collectRuntimeManifests_(runtimeIndex).filter(function (manifest) {
    return isActiveVisibleManifestForDashboardTotals_(manifest);
  });

  var totalsForSignature = (typeof buildArchiveDashboardTotalsFromManifests_ === 'function')
    ? buildArchiveDashboardTotalsFromManifests_(manifests, 'runtime_index')
    : null;
  var expiringRecipesSignature = String((totalsForSignature && totalsForSignature.expiringRecipesSignature) || '');

  var items = [];
  manifests.forEach(function (manifest) {
    var baseDate = parseDashboardTotalsDate_(manifest && (manifest.prescriptionDate || manifest.createdAt));
    var expiryDate = baseDate ? addDaysForDashboardTotals_(baseDate, 30) : null;
    if (!isDashboardExpiryAlert_(expiryDate)) return;

    var item = buildDashboardExpiringRecipeItemFromManifest_(manifest, baseDate, expiryDate);
    if (item) items.push(item);
  });

  items.sort(compareDashboardExpiringRecipeItems_);
  var totalExpiringCount = items.length;
  var limitedItems = items.slice(0, limit);

  return {
    schemaVersion: 1,
    source: 'phbox_backend_runtime_index',
    itemCount: limitedItems.length,
    totalExpiringCount: totalExpiringCount,
    expiringRecipesSignature: expiringRecipesSignature,
    limit: limit,
    truncated: totalExpiringCount > limitedItems.length,
    items: limitedItems,
    runtimeIndexUpdatedAt: runtimeIndex.updatedAt || null,
    generatedAt: '',
    updatedAt: ''
  };
}

function buildDashboardExpiringRecipeItemFromManifest_(manifest, baseDate, expiryDate) {
  if (!manifest) return null;
  var driveFileId = String(manifest.driveFileId || manifest.id || '').trim();
  if (!driveFileId) return null;

  var patientFiscalCode = normalizeCf_(manifest.patientFiscalCode);
  var patientFullName = String(manifest.patientFullName || '').trim();
  if (!patientFiscalCode && !patientFullName) return null;

  var expiryDay = normalizeDashboardExpiringRecipeDay_(expiryDate);
  var today = normalizeDashboardExpiringRecipeDay_(new Date());
  var daysToExpiry = Math.floor((expiryDay.getTime() - today.getTime()) / 86400000);
  var prescriptionCount = resolveManifestPrescriptionCount_(manifest);
  var exemptions = extractManifestExemptionsForProjection_(manifest);
  var primaryExemption = exemptions.length ? exemptions[0] : '';

  return {
    id: driveFileId,
    importId: driveFileId,
    driveFileId: driveFileId,
    fileName: String(manifest.fileName || '').trim(),
    patientFiscalCode: patientFiscalCode,
    patientFullName: patientFullName,
    doctorFullName: String(manifest.doctorFullName || '').trim(),
    exemptionCode: primaryExemption,
    city: String(manifest.city || '').trim(),
    therapy: uniqueNonEmptyStrings_(manifest.therapy || []),
    isDpc: !!manifest.isDpc,
    prescriptionCount: prescriptionCount,
    prescriptionDate: baseDate ? baseDate.toISOString() : null,
    expiryDate: expiryDate ? expiryDate.toISOString() : null,
    daysToExpiry: daysToExpiry,
    webViewLink: String(manifest.webViewLink || '').trim(),
    openUrl: String(manifest.webViewLink || '').trim(),
    sourceType: manifest.sourceType || 'script',
    status: String(manifest.status || '').trim(),
    updatedAt: manifest.updatedAt || manifest.createdAt || new Date().toISOString()
  };
}

function compareDashboardExpiringRecipeItems_(a, b) {
  var aExpiry = parseDashboardTotalsDate_(a && a.expiryDate);
  var bExpiry = parseDashboardTotalsDate_(b && b.expiryDate);
  var aTime = aExpiry ? aExpiry.getTime() : 0;
  var bTime = bExpiry ? bExpiry.getTime() : 0;
  if (aTime !== bTime) return aTime - bTime;

  var aPatient = String((a && (a.patientFullName || a.patientFiscalCode)) || '').toLowerCase();
  var bPatient = String((b && (b.patientFullName || b.patientFiscalCode)) || '').toLowerCase();
  if (aPatient < bPatient) return -1;
  if (aPatient > bPatient) return 1;

  var aFile = String((a && a.fileName) || '').toLowerCase();
  var bFile = String((b && b.fileName) || '').toLowerCase();
  if (aFile < bFile) return -1;
  if (aFile > bFile) return 1;
  return 0;
}

function normalizeDashboardExpiringRecipeDay_(date) {
  if (!date) return new Date(0);
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}
