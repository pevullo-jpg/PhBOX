var PHBOX_M1_SHADOW_TARGET_ENABLED_PROPERTY_ = 'PHBOX_M1_SHADOW_TARGET_ENABLED';
var PHBOX_M1_SHADOW_TENANT_ID_PROPERTY_ = 'PHBOX_TENANT_ID';
var PHBOX_M1_SHADOW_EXPECTED_TENANT_ID_PROPERTY_ = 'PHBOX_EXPECTED_CANONICAL_TENANT_ID';
var PHBOX_M1_SHADOW_MAX_ASSISTITI_SCAN_PROPERTY_ = 'PHBOX_M1_SHADOW_MAX_ASSISTITI_SCAN';
var PHBOX_M1_SHADOW_MAX_ASSISTITI_SCAN_ = 100;
var PHBOX_M1_SHADOW_DEFAULT_ASSISTITI_SCAN_ = 25;


async function runMigration1TargetShadowReadOnlyStage_(options) {
  try {
    return {
      ok: true,
      result: runMigration1TargetShadowRead_(options || {})
    };
  } catch (e) {
    return {
      ok: false,
      error: normalizeRuntimeErrorMessage_(e),
      errorKind: classifyRuntimeFailureKind_(e),
      stage: 'migration1_target_shadow',
      shadowReadOnly: true,
      firestoreReads: 0,
      firestoreWrites: 0,
      docsSeen: 0,
      publishFromTarget: false,
      lifecycleTouched: false
    };
  }
}

function runMigration1TargetShadowRead_(options) {
  options = options || {};
  var cfg = options.cfg || getPhboxConfig_();
  var props = PropertiesService.getScriptProperties();
  var enabled = isMigration1TargetShadowEnabled_(props);

  if (!enabled) {
    return buildMigration1TargetShadowDisabledResult_();
  }

  var tenant = validateMigration1ShadowCanonicalTenantId_(props);
  var limit = normalizeMigration1ShadowMaxAssistitiScan_(props.getProperty(PHBOX_M1_SHADOW_MAX_ASSISTITI_SCAN_PROPERTY_));
  var docs = listMigration1TargetAssistitiShadowDocs_(cfg, tenant.tenantId, limit);
  var summary = summarizeMigration1TargetAssistitiShadowDocs_(docs);

  return {
    stats: {
      stage: 'migration1_target_shadow',
      enabled: true,
      skipped: false,
      tenantId: tenant.tenantId,
      targetCollection: 'tenants/{tenantId}/assistiti',
      maxAssistitiScan: limit,
      firestoreReads: docs.length,
      firestoreWrites: 0,
      docsSeen: docs.length,
      cfCount: summary.cfCount,
      noCfCount: summary.noCfCount,
      resolvedManualCount: summary.resolvedManualCount,
      pendingManualCount: summary.pendingManualCount,
      missingIdentityAnchorCount: summary.missingIdentityAnchorCount,
      missingFullNameCount: summary.missingFullNameCount,
      stoppedEarly: docs.length >= limit,
      publishFromTarget: false,
      lifecycleTouched: false
    },
    tenantId: tenant.tenantId,
    documents: docs.map(function (doc) {
      return {
        documentId: doc.documentId,
        identityType: String(doc.identityType || '').trim(),
        identityAnchor: String(doc.identityAnchor || '').trim(),
        cf: String(doc.cf || '').trim(),
        fullName: String(doc.fullName || '').trim(),
        identityResolutionStatus: String(doc.identityResolutionStatus || '').trim()
      };
    })
  };
}

function buildMigration1TargetShadowDisabledResult_() {
  return {
    stats: {
      stage: 'migration1_target_shadow',
      enabled: false,
      skipped: true,
      reason: 'shadow_gate_off',
      firestoreReads: 0,
      firestoreWrites: 0,
      docsSeen: 0,
      publishFromTarget: false,
      lifecycleTouched: false,
      stoppedEarly: false
    }
  };
}

function buildMigration1ShadowReadOnlyErrorFallback_() {
  return {
    stage: 'migration1_target_shadow',
    skipped: true,
    reason: 'stage_error',
    stoppedEarly: true,
    shadowReadOnly: true,
    firestoreReads: 0,
    firestoreWrites: 0,
    docsSeen: 0,
    publishFromTarget: false,
    lifecycleTouched: false
  };
}

function isMigration1TargetShadowEnabled_(props) {
  var raw = props.getProperty(PHBOX_M1_SHADOW_TARGET_ENABLED_PROPERTY_);
  return /^true$/i.test(String(raw || '').trim());
}

function validateMigration1ShadowCanonicalTenantId_(props) {
  return validateMigration1CanonicalTenantIdFromProperties_(props, {
    tenantPropertyName: PHBOX_M1_SHADOW_TENANT_ID_PROPERTY_,
    expectedTenantPropertyName: PHBOX_M1_SHADOW_EXPECTED_TENANT_ID_PROPERTY_,
    errorPrefix: 'M1_SHADOW',
    blockedOperationLabel: 'Nessuna target read eseguita.'
  });
}

function normalizeMigration1ShadowTenantSegment_(value, label) {
  return normalizeMigration1CanonicalTenantSegment_(value, label, {
    errorPrefix: 'M1_SHADOW',
    blockedOperationLabel: 'Nessuna target read eseguita.'
  });
}

function normalizeMigration1ShadowMaxAssistitiScan_(rawValue) {
  var parsed = parseInt(String(rawValue || '').trim(), 10);
  if (isNaN(parsed) || parsed <= 0) return PHBOX_M1_SHADOW_DEFAULT_ASSISTITI_SCAN_;
  return Math.min(PHBOX_M1_SHADOW_MAX_ASSISTITI_SCAN_, parsed);
}

function listMigration1TargetAssistitiShadowDocs_(cfg, tenantId, limit) {
  var safeTenantId = normalizeMigration1ShadowTenantSegment_(tenantId, 'tenantId');
  var safeLimit = Math.max(1, Math.min(PHBOX_M1_SHADOW_MAX_ASSISTITI_SCAN_, Number(limit || 1)));
  var url = buildFirestoreDocumentsListUrl_(cfg, ['tenants', safeTenantId, 'assistiti'], {
    pageSize: safeLimit,
    orderBy: '__name__'
  });
  var payload = fetchFirestoreJsonWithRetry_(url, { method: 'get' });
  var documents = (payload && payload.documents) || [];
  return documents.slice(0, safeLimit).map(function (document) {
    return mapFirestoreDocumentToPlainObject_(document);
  });
}

function summarizeMigration1TargetAssistitiShadowDocs_(docs) {
  var summary = {
    cfCount: 0,
    noCfCount: 0,
    resolvedManualCount: 0,
    pendingManualCount: 0,
    missingIdentityAnchorCount: 0,
    missingFullNameCount: 0
  };

  (docs || []).forEach(function (doc) {
    var identityType = String(doc && doc.identityType || '').trim();
    var identityAnchor = String(doc && doc.identityAnchor || '').trim();
    var fullName = String(doc && doc.fullName || '').trim();
    var rootStatus = String(doc && doc.identityResolutionStatus || '').trim();
    var nestedStatus = '';
    if (doc && doc.identityResolution && typeof doc.identityResolution === 'object') {
      nestedStatus = String(doc.identityResolution.status || '').trim();
    }

    if (identityType === 'cf') summary.cfCount++;
    if (identityType === 'nocf') summary.noCfCount++;
    if (rootStatus === 'resolved_manual' || nestedStatus === 'resolved_manual') summary.resolvedManualCount++;
    if (rootStatus === 'pending_manual' || nestedStatus === 'pending_manual') summary.pendingManualCount++;
    if (!identityAnchor) summary.missingIdentityAnchorCount++;
    if (!fullName) summary.missingFullNameCount++;
  });

  return summary;
}
