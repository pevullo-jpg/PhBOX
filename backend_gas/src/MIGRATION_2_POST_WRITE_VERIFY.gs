var PHBOX_M2_VERIFY_VERSION_ = 'M2_VERIFY_v1';
var PHBOX_M2_VERIFY_STAGE_ = 'migration2_post_write_verify';
var PHBOX_M2_VERIFY_SAMPLE_PATHS_PROPERTY_ = 'PHBOX_M2_VERIFY_SAMPLE_LEGACY_PATHS';
var PHBOX_M2_VERIFY_MAX_SAMPLE_PATHS_ = 10;
var PHBOX_M2_VERIFY_REQUIRED_DASH_VERSION_ = 'M2_DASH_v1';
var PHBOX_M2_VERIFY_REQUIRED_ROUTE_VERSION_ = 'M2_ROUTE_v2';
var PHBOX_M2_VERIFY_REQUIRED_SIGNAL_VERSION_ = 'M2_SIGNAL_v2';

function runMigration2PostWriteVerifyRuntimeStatus_() {
  var dashStatus = null;
  var error = '';
  var errorKind = '';

  try {
    if (typeof runMigration2DashboardReadRuntimeStatus_ !== 'function') {
      throw new Error('M2_VERIFY_DASH_MISSING: funzione runMigration2DashboardReadRuntimeStatus_ non disponibile. Verifier M2 non eseguibile.');
    }
    dashStatus = runMigration2DashboardReadRuntimeStatus_();
  } catch (e) {
    error = normalizeRuntimeErrorMessage_(e);
    errorKind = classifyRuntimeFailureKind_(e);
  }

  if (error) {
    return buildMigration2PostWriteVerifyResult_({
      dashStatus: dashStatus,
      legacyPaths: [],
      obsoleteHandlers: listMigration2PostWriteVerifyObsoleteSettingsHandlers_(),
      error: error,
      errorKind: errorKind
    });
  }

  var legacyPaths = readMigration2PostWriteVerifySampleLegacyPaths_();
  var result = buildMigration2PostWriteVerifyResult_({
    dashStatus: dashStatus,
    legacyPaths: legacyPaths,
    obsoleteHandlers: listMigration2PostWriteVerifyObsoleteSettingsHandlers_()
  });

  var stats = (result && result.stats) || {};
  if (!stats.targetVerifyAuthorized || !legacyPaths.length || !stats.ok) {
    return result;
  }

  try {
    return runMigration2PostWriteVerifyForLegacyPaths_(getPhboxConfig_(), dashStatus, legacyPaths);
  } catch (e2) {
    return buildMigration2PostWriteVerifyResult_({
      dashStatus: dashStatus,
      legacyPaths: legacyPaths,
      obsoleteHandlers: listMigration2PostWriteVerifyObsoleteSettingsHandlers_(),
      error: normalizeRuntimeErrorMessage_(e2),
      errorKind: classifyRuntimeFailureKind_(e2)
    });
  }
}

function runMigration2PostWriteVerifyForLegacyPaths_(cfg, dashStatus, legacyPaths) {
  cfg = cfg || getPhboxConfig_();
  legacyPaths = legacyPaths || [];
  var dashStats = (dashStatus && dashStatus.stats) || {};
  var preflight = buildMigration2PostWriteVerifyResult_({
    dashStatus: dashStatus,
    legacyPaths: legacyPaths,
    obsoleteHandlers: []
  });
  if (!preflight || !preflight.ok || !preflight.stats || !preflight.stats.targetVerifyAuthorized) {
    throw new Error('M2_VERIFY_TARGET_NOT_AUTHORIZED: target verifier non autorizzato. Nessun target path letto.');
  }

  var tenantId = normalizeMigration1CanonicalTenantSegment_(dashStats.tenantId, 'tenantId', {
    errorPrefix: 'M2_VERIFY',
    blockedOperationLabel: 'Nessun target path letto.'
  });
  var boundedPaths = normalizeMigration2PostWriteVerifySampleLegacyPaths_(legacyPaths).slice(0, PHBOX_M2_VERIFY_MAX_SAMPLE_PATHS_);
  var items = [];
  var reads = 0;
  var mismatchedCount = 0;
  var missingLegacyCount = 0;
  var missingTargetCount = 0;
  var targetPathBuilt = false;

  boundedPaths.forEach(function (legacyPath) {
    var normalizedLegacy = normalizeMigration2PostWriteVerifyLegacyPath_(legacyPath);
    var targetPath = buildMigration2PostWriteVerifyTargetPath_(tenantId, normalizedLegacy);
    targetPathBuilt = true;

    var legacyDoc = getFirestoreDocumentByPath_(cfg, normalizedLegacy.pathParts);
    var targetDoc = getFirestoreDocumentByPath_(cfg, targetPath.pathParts);
    reads += 2;

    var comparison = compareMigration2PostWriteVerifyDocs_(legacyDoc, targetDoc);
    if (!comparison.legacyExists) missingLegacyCount++;
    if (!comparison.targetExists) missingTargetCount++;
    if (!comparison.matched) mismatchedCount++;

    items.push({
      legacyPath: normalizedLegacy.path,
      targetPath: targetPath.path,
      legacyExists: comparison.legacyExists,
      targetExists: comparison.targetExists,
      matched: comparison.matched,
      mismatchReasons: comparison.mismatchReasons
    });
  });

  var stats = buildMigration2PostWriteVerifyStats_({
    ok: mismatchedCount === 0,
    skipped: false,
    reason: mismatchedCount === 0 ? 'post_write_verify_matched' : 'post_write_verify_mismatch',
    dashStats: dashStats,
    targetVerifyAuthorized: true,
    legacyPathsSeen: legacyPaths.length,
    legacyPathsCompared: boundedPaths.length,
    mismatchedCount: mismatchedCount,
    missingLegacyCount: missingLegacyCount,
    missingTargetCount: missingTargetCount,
    firestoreReads: reads,
    targetPathBuilt: targetPathBuilt,
    stoppedEarly: legacyPaths.length > boundedPaths.length
  });

  return {
    ok: !!stats.ok,
    stats: stats,
    items: items
  };
}

function buildMigration2PostWriteVerifyResult_(data) {
  data = data || {};
  var dashStats = (data.dashStatus && data.dashStatus.stats) || {};
  var legacyPaths = normalizeMigration2PostWriteVerifySampleLegacyPaths_(data.legacyPaths || []);
  var obsoleteHandlers = Array.isArray(data.obsoleteHandlers) ? data.obsoleteHandlers : [];
  var violations = [];
  var reason = '';
  var targetVerifyAuthorized = false;
  var routeDecision = String(dashStats.routeDecision || '').trim().toLowerCase();
  var dashboardReadDecision = String(dashStats.dashboardReadDecision || '').trim().toLowerCase();

  if (!data.dashStatus || !data.dashStatus.stats) violations.push('m2_dash_status_missing');
  if (data.dashStatus && data.dashStatus.ok === false) violations.push('m2_dash_not_ok');
  if (String(dashStats.dashVersion || '') !== PHBOX_M2_VERIFY_REQUIRED_DASH_VERSION_) violations.push('m2_dash_version_not_v1');
  if (String(dashStats.routeVersion || '') !== PHBOX_M2_VERIFY_REQUIRED_ROUTE_VERSION_) violations.push('m2_route_version_not_v2');
  if (String(dashStats.signalVersion || '') !== PHBOX_M2_VERIFY_REQUIRED_SIGNAL_VERSION_) violations.push('m2_signal_version_not_v2');
  if (Number(dashStats.firestoreReads || 0) !== 0) violations.push('m2_dash_reads_not_zero');
  if (Number(dashStats.firestoreWrites || 0) !== 0) violations.push('m2_dash_writes_not_zero');
  if (dashStats.publishToTarget || dashStats.publishFromTarget) violations.push('m2_dash_publish_detected_before_verify');
  if (dashStats.cutover) violations.push('m2_dash_cutover_detected_before_verify');
  if (dashStats.lifecycleTouched) violations.push('m2_dash_lifecycle_touched_before_verify');
  if (obsoleteHandlers.length > 0) violations.push('obsolete_settings_handlers_detected');
  if (data.error) violations.push('m2_verify_error');

  if (violations.length === 0) {
    if (dashboardReadDecision === 'legacy' || routeDecision === 'legacy') {
      reason = 'legacy_route_active';
    } else if (dashboardReadDecision === 'dual_check' || routeDecision === 'dual_check') {
      reason = 'dual_check_route_no_target_verify';
    } else if (dashboardReadDecision === 'target' && !!dashStats.targetReadAuthorized && !!dashStats.tenantCanonical && !!dashStats.targetReadWriteAuthorized && String(dashStats.tenantId || '').trim()) {
      targetVerifyAuthorized = true;
      reason = legacyPaths.length ? 'target_verify_ready' : 'no_verify_paths_configured';
    } else {
      violations.push('target_verify_not_authorized');
    }
  }

  violations = uniqueNonEmptyStrings_(violations);
  if (violations.length > 0) {
    reason = data.error ? 'm2_verify_error' : 'm2_verify_violation';
    targetVerifyAuthorized = false;
  }

  var stats = buildMigration2PostWriteVerifyStats_({
    ok: violations.length === 0,
    skipped: !targetVerifyAuthorized || legacyPaths.length === 0,
    reason: reason,
    dashStats: dashStats,
    targetVerifyAuthorized: targetVerifyAuthorized,
    legacyPathsSeen: legacyPaths.length,
    legacyPathsCompared: 0,
    mismatchedCount: 0,
    missingLegacyCount: 0,
    missingTargetCount: 0,
    firestoreReads: 0,
    targetPathBuilt: false,
    stoppedEarly: false,
    violations: violations,
    obsoleteHandlers: obsoleteHandlers,
    error: data.error,
    errorKind: data.errorKind
  });

  return {
    ok: !!stats.ok,
    stats: stats,
    items: []
  };
}

function buildMigration2PostWriteVerifyStats_(data) {
  data = data || {};
  var dashStats = data.dashStats || {};
  return {
    stage: PHBOX_M2_VERIFY_STAGE_,
    ok: data.ok !== false,
    skipped: data.skipped !== false,
    reason: String(data.reason || ''),
    verifyVersion: PHBOX_M2_VERIFY_VERSION_,
    dashVersion: String(dashStats.dashVersion || PHBOX_M2_VERIFY_REQUIRED_DASH_VERSION_),
    routeVersion: String(dashStats.routeVersion || ''),
    signalVersion: String(dashStats.signalVersion || ''),
    routeMode: String(dashStats.routeMode || ''),
    routeDecision: String(dashStats.routeDecision || ''),
    dashboardReadDecision: String(dashStats.dashboardReadDecision || ''),
    targetVerifyAuthorized: !!data.targetVerifyAuthorized,
    targetReadAuthorized: !!dashStats.targetReadAuthorized,
    tenantId: String(dashStats.tenantId || ''),
    tenantCanonical: !!dashStats.tenantCanonical,
    targetReadWriteAuthorized: !!dashStats.targetReadWriteAuthorized,
    legacyPathsSeen: Math.max(0, Number(data.legacyPathsSeen || 0)),
    legacyPathsCompared: Math.max(0, Number(data.legacyPathsCompared || 0)),
    mismatchedCount: Math.max(0, Number(data.mismatchedCount || 0)),
    missingLegacyCount: Math.max(0, Number(data.missingLegacyCount || 0)),
    missingTargetCount: Math.max(0, Number(data.missingTargetCount || 0)),
    maxSamplePaths: PHBOX_M2_VERIFY_MAX_SAMPLE_PATHS_,
    obsoleteHandlersCount: Array.isArray(data.obsoleteHandlers) ? data.obsoleteHandlers.length : 0,
    firestoreReads: Math.max(0, Number(data.firestoreReads || 0)),
    firestoreWrites: 0,
    publishFromTarget: false,
    publishToTarget: false,
    targetPathBuilt: !!data.targetPathBuilt,
    cutover: false,
    lifecycleTouched: false,
    stoppedEarly: !!data.stoppedEarly,
    violations: uniqueNonEmptyStrings_(data.violations || []),
    obsoleteHandlers: uniqueNonEmptyStrings_(data.obsoleteHandlers || []),
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };
}

function readMigration2PostWriteVerifySampleLegacyPaths_() {
  var props = PropertiesService.getScriptProperties();
  var raw = String(props.getProperty(PHBOX_M2_VERIFY_SAMPLE_PATHS_PROPERTY_) || '');
  return normalizeMigration2PostWriteVerifySampleLegacyPaths_(raw.split(/\r?\n/));
}

function normalizeMigration2PostWriteVerifySampleLegacyPaths_(value) {
  var list = Array.isArray(value) ? value : String(value || '').split(/\r?\n/);
  return uniqueNonEmptyStrings_(list.map(function (item) {
    return String(item || '').trim();
  })).slice(0, PHBOX_M2_VERIFY_MAX_SAMPLE_PATHS_);
}

function normalizeMigration2PostWriteVerifyLegacyPath_(legacyPath) {
  if (typeof normalizeMigration1DualLegacyPath_ === 'function') return normalizeMigration1DualLegacyPath_(legacyPath);
  var path = String(legacyPath || '').trim().replace(/^\/+/, '').replace(/\/+$/, '');
  if (!path) throw new Error('M2_VERIFY_LEGACY_PATH_EMPTY: path legacy vuoto. Nessun target path letto.');
  if (path.indexOf('tenants/') === 0) throw new Error('M2_VERIFY_LEGACY_PATH_ALREADY_TARGET: path legacy già target-prefixed. Nessun target path letto.');
  if (path.indexOf('//') !== -1) throw new Error('M2_VERIFY_LEGACY_PATH_INVALID: path legacy contiene segmento vuoto. Nessun target path letto.');
  var parts = path.split('/').map(function (part) { return String(part || '').trim(); });
  if (!parts.length || parts.length % 2 !== 0) throw new Error('M2_VERIFY_LEGACY_PATH_INVALID: path legacy deve puntare a documento collection/document. Nessun target path letto.');
  parts.forEach(function (part) { if (!part) throw new Error('M2_VERIFY_LEGACY_PATH_INVALID: path legacy contiene segmento vuoto. Nessun target path letto.'); });
  return { path: parts.join('/'), pathParts: parts };
}

function buildMigration2PostWriteVerifyTargetPath_(tenantId, normalizedLegacyPath) {
  if (typeof buildMigration1DualTargetPath_ === 'function') return buildMigration1DualTargetPath_(tenantId, normalizedLegacyPath);
  var canonicalTenantId = normalizeMigration1CanonicalTenantSegment_(tenantId, 'tenantId', {
    errorPrefix: 'M2_VERIFY',
    blockedOperationLabel: 'Nessun target path letto.'
  });
  var normalized = normalizedLegacyPath && normalizedLegacyPath.pathParts ? normalizedLegacyPath : normalizeMigration2PostWriteVerifyLegacyPath_(normalizedLegacyPath);
  var parts = ['tenants', canonicalTenantId].concat(normalized.pathParts);
  return { path: parts.join('/'), pathParts: parts };
}

function compareMigration2PostWriteVerifyDocs_(legacyDoc, targetDoc) {
  var legacyExists = !!legacyDoc;
  var targetExists = !!targetDoc;
  var mismatchReasons = [];
  if (!legacyExists) mismatchReasons.push('legacy_missing');
  if (!targetExists) mismatchReasons.push('target_missing');
  if (legacyExists && targetExists) {
    var legacySignature = buildMigration2PostWriteVerifyComparableSignature_(legacyDoc);
    var targetSignature = buildMigration2PostWriteVerifyComparableSignature_(targetDoc);
    if (legacySignature !== targetSignature) mismatchReasons.push('signature_mismatch');
  }
  mismatchReasons = uniqueNonEmptyStrings_(mismatchReasons);
  return {
    legacyExists: legacyExists,
    targetExists: targetExists,
    matched: mismatchReasons.length === 0,
    mismatchReasons: mismatchReasons
  };
}

function buildMigration2PostWriteVerifyComparableSignature_(doc) {
  if (typeof buildMigration1DualComparableSignature_ === 'function') return buildMigration1DualComparableSignature_(doc);
  return stableStringifyMigration2PostWriteVerify_(normalizeMigration2PostWriteVerifyComparableValue_(doc || {}, true));
}

function normalizeMigration2PostWriteVerifyComparableValue_(value, isTopLevel) {
  if (value === null || value === undefined) return null;
  if (Array.isArray(value)) return value.map(function (item) { return normalizeMigration2PostWriteVerifyComparableValue_(item, false); });
  if (typeof value === 'object') {
    var out = {};
    Object.keys(value).sort().forEach(function (key) {
      if (isTopLevel && (key === 'documentName' || key === 'documentPath' || key === 'collectionId' || key === 'parentDocumentId')) return;
      out[key] = normalizeMigration2PostWriteVerifyComparableValue_(value[key], false);
    });
    return out;
  }
  return value;
}

function stableStringifyMigration2PostWriteVerify_(value) {
  if (value === null || value === undefined) return 'null';
  if (Array.isArray(value)) return '[' + value.map(function (item) { return stableStringifyMigration2PostWriteVerify_(item); }).join(',') + ']';
  if (typeof value === 'object') {
    return '{' + Object.keys(value).sort().map(function (key) { return JSON.stringify(key) + ':' + stableStringifyMigration2PostWriteVerify_(value[key]); }).join(',') + '}';
  }
  return JSON.stringify(value);
}

function runMigration2PostWriteVerifySelfTest_() {
  var cases = [
    {
      id: 'legacy_route_skips_without_reads',
      result: buildMigration2PostWriteVerifyResult_({
        dashStatus: buildMigration2PostWriteVerifySyntheticDashStatus_({ dashboardReadDecision: 'legacy', routeDecision: 'legacy', legacyDashboardActive: true }),
        legacyPaths: ['patients/RSSMRA80A01H501U']
      }),
      expected: { ok: true, skipped: true, targetPathBuilt: false, firestoreReads: 0, reason: 'legacy_route_active' }
    },
    {
      id: 'target_authorized_no_samples_skips_without_reads',
      result: buildMigration2PostWriteVerifyResult_({
        dashStatus: buildMigration2PostWriteVerifySyntheticDashStatus_({ dashboardReadDecision: 'target', routeDecision: 'target', targetReadAuthorized: true, targetRouteAuthorized: true, tenantId: 'farmacia_santa_venera', tenantCanonical: true, targetReadWriteAuthorized: true }),
        legacyPaths: []
      }),
      expected: { ok: true, skipped: true, targetPathBuilt: false, firestoreReads: 0, reason: 'no_verify_paths_configured' }
    },
    {
      id: 'canonical_tenant_builds_verify_target_path',
      purePath: 'patients/RSSMRA80A01H501U',
      expected: { targetPath: 'tenants/farmacia_santa_venera/patients/RSSMRA80A01H501U' }
    },
    {
      id: 'target_prefixed_legacy_path_rejected',
      purePath: 'tenants/farmacia_santa_venera/patients/RSSMRA80A01H501U',
      expected: { errorContains: 'LEGACY_PATH_ALREADY_TARGET' }
    },
    {
      id: 'odd_segment_legacy_path_rejected',
      purePath: 'patients',
      expected: { errorContains: 'LEGACY_PATH_INVALID' }
    },
    {
      id: 'matching_signatures_pass',
      legacyDoc: { fiscalCode: 'RSSMRA80A01H501U', fullName: 'Mario Rossi', nested: { count: 1 } },
      targetDoc: { fiscalCode: 'RSSMRA80A01H501U', fullName: 'Mario Rossi', nested: { count: 1 } },
      expected: { matched: true }
    },
    {
      id: 'signature_mismatch_detected',
      legacyDoc: { fiscalCode: 'RSSMRA80A01H501U', recipeCount: 2 },
      targetDoc: { fiscalCode: 'RSSMRA80A01H501U', recipeCount: 1 },
      expected: { matched: false, reason: 'signature_mismatch' }
    },
    {
      id: 'missing_target_detected',
      legacyDoc: { fiscalCode: 'RSSMRA80A01H501U', recipeCount: 2 },
      targetDoc: null,
      expected: { matched: false, reason: 'target_missing' }
    },
    {
      id: 'sample_paths_are_bounded',
      rawPaths: 'patients/A\npatients/B\npatients/C\npatients/D\npatients/E\npatients/F\npatients/G\npatients/H\npatients/I\npatients/J\npatients/K',
      expected: { sampleCount: PHBOX_M2_VERIFY_MAX_SAMPLE_PATHS_ }
    },
    {
      id: 'dash_publish_cutover_lifecycle_blocks_verify',
      result: buildMigration2PostWriteVerifyResult_({
        dashStatus: buildMigration2PostWriteVerifySyntheticDashStatus_({ dashboardReadDecision: 'target', routeDecision: 'target', targetReadAuthorized: true, targetRouteAuthorized: true, tenantId: 'farmacia_santa_venera', tenantCanonical: true, targetReadWriteAuthorized: true, publishToTarget: true, cutover: true, lifecycleTouched: true }),
        legacyPaths: ['patients/RSSMRA80A01H501U']
      }),
      expected: { ok: false, skipped: true, targetPathBuilt: false, firestoreReads: 0, reason: 'm2_verify_violation', violation: 'm2_dash_publish_detected_before_verify' }
    }
  ];

  var passed = 0;
  var failed = 0;
  var items = cases.map(function (item) {
    var actual = runMigration2PostWriteVerifySelfTestCase_(item);
    var mismatchReasons = compareMigration2PostWriteVerifyExpected_(actual, item.expected || {});
    var ok = mismatchReasons.length === 0;
    if (ok) passed++; else failed++;
    return {
      id: item.id,
      passed: ok,
      ok: actual.ok,
      skipped: actual.skipped,
      reason: actual.reason || '',
      targetVerifyAuthorized: !!actual.targetVerifyAuthorized,
      legacyPathsSeen: actual.legacyPathsSeen || 0,
      legacyPathsCompared: actual.legacyPathsCompared || 0,
      mismatchedCount: actual.mismatchedCount || 0,
      missingLegacyCount: actual.missingLegacyCount || 0,
      missingTargetCount: actual.missingTargetCount || 0,
      targetPath: actual.targetPath || '',
      matched: Object.prototype.hasOwnProperty.call(actual, 'matched') ? actual.matched : '',
      sampleCount: actual.sampleCount || '',
      firestoreReads: actual.firestoreReads || 0,
      firestoreWrites: actual.firestoreWrites || 0,
      publishFromTarget: !!actual.publishFromTarget,
      publishToTarget: !!actual.publishToTarget,
      targetPathBuilt: !!actual.targetPathBuilt,
      cutover: !!actual.cutover,
      lifecycleTouched: !!actual.lifecycleTouched,
      violations: actual.violations || [],
      mismatchReasons: mismatchReasons
    };
  });

  return {
    ok: failed === 0,
    testCount: items.length,
    passedCount: passed,
    failedCount: failed,
    verifyVersion: PHBOX_M2_VERIFY_VERSION_,
    dashVersion: PHBOX_M2_VERIFY_REQUIRED_DASH_VERSION_,
    routeVersion: PHBOX_M2_VERIFY_REQUIRED_ROUTE_VERSION_,
    signalVersion: PHBOX_M2_VERIFY_REQUIRED_SIGNAL_VERSION_,
    maxSamplePaths: PHBOX_M2_VERIFY_MAX_SAMPLE_PATHS_,
    firestoreReads: 0,
    firestoreWrites: 0,
    publishFromTarget: false,
    publishToTarget: false,
    targetPathBuilt: false,
    cutover: false,
    lifecycleTouched: false,
    items: items
  };
}

function runMigration2PostWriteVerifySelfTestCase_(item) {
  try {
    if (item.result) {
      var stats = item.result.stats || {};
      return cloneMigration2PostWriteVerifyStatsForTest_(stats);
    }
    if (item.purePath) {
      var normalized = normalizeMigration2PostWriteVerifyLegacyPath_(item.purePath);
      var target = buildMigration2PostWriteVerifyTargetPath_('farmacia_santa_venera', normalized);
      return { ok: true, targetPath: target.path, targetPathBuilt: true, firestoreReads: 0, firestoreWrites: 0 };
    }
    if (Object.prototype.hasOwnProperty.call(item, 'legacyDoc') || Object.prototype.hasOwnProperty.call(item, 'targetDoc')) {
      var comparison = compareMigration2PostWriteVerifyDocs_(item.legacyDoc, item.targetDoc);
      return {
        ok: comparison.matched,
        matched: comparison.matched,
        mismatchReasons: comparison.mismatchReasons,
        missingLegacyCount: comparison.legacyExists ? 0 : 1,
        missingTargetCount: comparison.targetExists ? 0 : 1,
        firestoreReads: 0,
        firestoreWrites: 0
      };
    }
    if (item.rawPaths) {
      return { ok: true, sampleCount: normalizeMigration2PostWriteVerifySampleLegacyPaths_(item.rawPaths.split(/\r?\n/)).length, firestoreReads: 0, firestoreWrites: 0 };
    }
    return { ok: false, error: 'unknown_selftest_case' };
  } catch (e) {
    return { ok: false, error: normalizeRuntimeErrorMessage_(e), firestoreReads: 0, firestoreWrites: 0 };
  }
}

function cloneMigration2PostWriteVerifyStatsForTest_(stats) {
  return {
    ok: !!stats.ok,
    skipped: !!stats.skipped,
    reason: stats.reason || '',
    targetVerifyAuthorized: !!stats.targetVerifyAuthorized,
    legacyPathsSeen: stats.legacyPathsSeen || 0,
    legacyPathsCompared: stats.legacyPathsCompared || 0,
    mismatchedCount: stats.mismatchedCount || 0,
    missingLegacyCount: stats.missingLegacyCount || 0,
    missingTargetCount: stats.missingTargetCount || 0,
    firestoreReads: stats.firestoreReads || 0,
    firestoreWrites: stats.firestoreWrites || 0,
    publishFromTarget: !!stats.publishFromTarget,
    publishToTarget: !!stats.publishToTarget,
    targetPathBuilt: !!stats.targetPathBuilt,
    cutover: !!stats.cutover,
    lifecycleTouched: !!stats.lifecycleTouched,
    violations: uniqueNonEmptyStrings_(stats.violations || [])
  };
}

function compareMigration2PostWriteVerifyExpected_(actual, expected) {
  actual = actual || {};
  expected = expected || {};
  var mismatchReasons = [];
  if (Object.prototype.hasOwnProperty.call(expected, 'ok') && !!actual.ok !== !!expected.ok) mismatchReasons.push('expected_ok_mismatch');
  if (Object.prototype.hasOwnProperty.call(expected, 'skipped') && !!actual.skipped !== !!expected.skipped) mismatchReasons.push('expected_skipped_mismatch');
  if (Object.prototype.hasOwnProperty.call(expected, 'reason') && String(actual.reason || '') !== String(expected.reason || '')) mismatchReasons.push('expected_reason_mismatch');
  if (Object.prototype.hasOwnProperty.call(expected, 'targetPath') && String(actual.targetPath || '') !== String(expected.targetPath || '')) mismatchReasons.push('expected_target_path_mismatch');
  if (Object.prototype.hasOwnProperty.call(expected, 'matched') && !!actual.matched !== !!expected.matched) mismatchReasons.push('expected_match_mismatch');
  if (Object.prototype.hasOwnProperty.call(expected, 'reason') && (actual.mismatchReasons || []).indexOf(expected.reason) === -1 && (actual.violations || []).indexOf(expected.reason) === -1 && String(actual.reason || '') !== String(expected.reason || '')) mismatchReasons.push('expected_reason_missing');
  if (Object.prototype.hasOwnProperty.call(expected, 'violation') && (actual.violations || []).indexOf(expected.violation) === -1) mismatchReasons.push('expected_violation_missing');
  if (Object.prototype.hasOwnProperty.call(expected, 'sampleCount') && Number(actual.sampleCount || 0) !== Number(expected.sampleCount || 0)) mismatchReasons.push('expected_sample_count_mismatch');
  if (Object.prototype.hasOwnProperty.call(expected, 'firestoreReads') && Number(actual.firestoreReads || 0) !== Number(expected.firestoreReads || 0)) mismatchReasons.push('expected_reads_mismatch');
  if (Object.prototype.hasOwnProperty.call(expected, 'targetPathBuilt') && !!actual.targetPathBuilt !== !!expected.targetPathBuilt) mismatchReasons.push('expected_target_path_built_mismatch');
  if (expected.errorContains && String(actual.error || '').indexOf(expected.errorContains) === -1) mismatchReasons.push('expected_error_missing');
  return uniqueNonEmptyStrings_(mismatchReasons);
}

function buildMigration2PostWriteVerifySyntheticDashStatus_(overrides) {
  overrides = overrides || {};
  var stats = {
    ok: Object.prototype.hasOwnProperty.call(overrides, 'ok') ? !!overrides.ok : true,
    dashVersion: Object.prototype.hasOwnProperty.call(overrides, 'dashVersion') ? overrides.dashVersion : PHBOX_M2_VERIFY_REQUIRED_DASH_VERSION_,
    routeVersion: Object.prototype.hasOwnProperty.call(overrides, 'routeVersion') ? overrides.routeVersion : PHBOX_M2_VERIFY_REQUIRED_ROUTE_VERSION_,
    signalVersion: Object.prototype.hasOwnProperty.call(overrides, 'signalVersion') ? overrides.signalVersion : PHBOX_M2_VERIFY_REQUIRED_SIGNAL_VERSION_,
    routeMode: String(overrides.routeMode || overrides.routeDecision || 'legacy'),
    routeDecision: String(overrides.routeDecision || 'legacy'),
    dashboardReadDecision: String(overrides.dashboardReadDecision || overrides.routeDecision || 'legacy'),
    targetReadAuthorized: !!overrides.targetReadAuthorized,
    legacyDashboardActive: !!overrides.legacyDashboardActive,
    dualCheckReadPlanned: !!overrides.dualCheckReadPlanned,
    targetGateEnabled: !!overrides.targetGateEnabled,
    tenantId: String(overrides.tenantId || ''),
    tenantCanonical: !!overrides.tenantCanonical,
    targetReadWriteAuthorized: !!overrides.targetReadWriteAuthorized,
    targetRouteAuthorized: !!overrides.targetRouteAuthorized,
    signalContractOk: true,
    firestoreReads: Number(overrides.firestoreReads || 0),
    firestoreWrites: Number(overrides.firestoreWrites || 0),
    publishFromTarget: !!overrides.publishFromTarget,
    publishToTarget: !!overrides.publishToTarget,
    targetPathBuilt: !!overrides.targetPathBuilt,
    cutover: !!overrides.cutover,
    lifecycleTouched: !!overrides.lifecycleTouched,
    violations: Array.isArray(overrides.violations) ? overrides.violations : []
  };
  return { ok: stats.ok, stats: stats };
}

function listMigration2PostWriteVerifyObsoleteSettingsHandlers_() {
  var names = [
    'runMigration2DashboardReadSettingsTest',
    'getMigration2DashboardReadSettingsStatus',
    'runMigration2RuntimeSignalSettingsTest',
    'getMigration2RuntimeSignalSettingsStatus',
    'runMigration2TargetWriteSettingsTest',
    'getMigration2TargetWriteSettingsStatus',
    'runMigration2RouteSettingsTest',
    'getMigration2RouteSettingsStatus',
    'runMigration2LockSettingsTest',
    'getMigration2LockSettingsStatus',
    'runMigration1FreezeBaselineSettingsTest',
    'getMigration1FreezeBaselineSettingsStatus',
    'runMigration1DocumentationSettingsTest',
    'getMigration1DocumentationSettingsStatus',
    'runMigration1FinalCleanupSettingsTest',
    'getMigration1FinalCleanupSettingsStatus',
    'runMigration1CostAuditSettingsTest',
    'getMigration1CostAuditSettingsStatus',
    'runMigration1E2ESettingsTest',
    'getMigration1E2ESettingsStatus',
    'runMigration1CutoverSettingsTest',
    'getMigration1CutoverSettingsStatus',
    'runMigration1DualVerifierSettingsTest',
    'getMigration1DualVerifierSettingsStatus',
    'runMigration1DashSettingsTest',
    'getMigration1DashSettingsStatus',
    'runMigration1RuntimeSignalSettingsTest',
    'getMigration1RuntimeSignalSettingsStatus',
    'runMigration1TargetPublishSettingsTest',
    'getMigration1TargetPublishSettingsStatus',
    'runMigration1TargetRuntimeGateSettingsTest',
    'getMigration1TargetRuntimeGateSettingsStatus',
    'runMigration1IdentityResolverSettingsTest',
    'getMigration1IdentityResolverSettingsStatus',
    'runMigration1ShadowSettingsTest',
    'getMigration1ShadowSettingsStatus'
  ];
  return names.filter(function (name) {
    return typeof this[name] === 'function';
  }, this);
}

function formatMigration2PostWriteVerifySelfTestFeedback_(result) {
  result = result || {};
  var lines = [];
  lines.push('MIGRATION_2_VERIFY_TEST');
  lines.push('ok=' + String(!!result.ok));
  lines.push('testCount=' + String(result.testCount || 0));
  lines.push('passedCount=' + String(result.passedCount || 0));
  lines.push('failedCount=' + String(result.failedCount || 0));
  lines.push('verifyVersion=' + String(result.verifyVersion || PHBOX_M2_VERIFY_VERSION_));
  lines.push('dashVersion=' + String(result.dashVersion || PHBOX_M2_VERIFY_REQUIRED_DASH_VERSION_));
  lines.push('routeVersion=' + String(result.routeVersion || PHBOX_M2_VERIFY_REQUIRED_ROUTE_VERSION_));
  lines.push('signalVersion=' + String(result.signalVersion || PHBOX_M2_VERIFY_REQUIRED_SIGNAL_VERSION_));
  lines.push('maxSamplePaths=' + String(result.maxSamplePaths || PHBOX_M2_VERIFY_MAX_SAMPLE_PATHS_));
  lines.push('firestoreReads=' + String(result.firestoreReads || 0));
  lines.push('firestoreWrites=' + String(result.firestoreWrites || 0));
  lines.push('publishFromTarget=' + String(!!result.publishFromTarget));
  lines.push('publishToTarget=' + String(!!result.publishToTarget));
  lines.push('targetPathBuilt=' + String(!!result.targetPathBuilt));
  lines.push('cutover=' + String(!!result.cutover));
  lines.push('lifecycleTouched=' + String(!!result.lifecycleTouched));
  lines.push('items=');
  (result.items || []).forEach(function (item) {
    lines.push('- id=' + String(item.id || ''));
    lines.push('  passed=' + String(!!item.passed));
    lines.push('  ok=' + String(item.ok));
    lines.push('  skipped=' + String(item.skipped));
    lines.push('  reason=' + String(item.reason || ''));
    lines.push('  targetVerifyAuthorized=' + String(!!item.targetVerifyAuthorized));
    lines.push('  legacyPathsSeen=' + String(item.legacyPathsSeen || 0));
    lines.push('  legacyPathsCompared=' + String(item.legacyPathsCompared || 0));
    lines.push('  mismatchedCount=' + String(item.mismatchedCount || 0));
    lines.push('  missingLegacyCount=' + String(item.missingLegacyCount || 0));
    lines.push('  missingTargetCount=' + String(item.missingTargetCount || 0));
    lines.push('  targetPath=' + String(item.targetPath || ''));
    lines.push('  matched=' + String(item.matched));
    lines.push('  sampleCount=' + String(item.sampleCount || ''));
    lines.push('  firestoreReads=' + String(item.firestoreReads || 0));
    lines.push('  firestoreWrites=' + String(item.firestoreWrites || 0));
    lines.push('  publishFromTarget=' + String(!!item.publishFromTarget));
    lines.push('  publishToTarget=' + String(!!item.publishToTarget));
    lines.push('  targetPathBuilt=' + String(!!item.targetPathBuilt));
    lines.push('  cutover=' + String(!!item.cutover));
    lines.push('  lifecycleTouched=' + String(!!item.lifecycleTouched));
    lines.push('  violations=' + formatMigration2PostWriteVerifyList_(item.violations));
    lines.push('  mismatchReasons=' + formatMigration2PostWriteVerifyList_(item.mismatchReasons));
  });
  return lines.join('\n');
}

function formatMigration2PostWriteVerifyRuntimeFeedback_(result) {
  result = result || {};
  var stats = result.stats || {};
  var lines = [];
  lines.push('MIGRATION_2_VERIFY_RUNTIME_STATUS');
  lines.push('ok=' + String(!!result.ok));
  lines.push('skipped=' + String(!!stats.skipped));
  lines.push('reason=' + String(stats.reason || ''));
  lines.push('verifyVersion=' + String(stats.verifyVersion || PHBOX_M2_VERIFY_VERSION_));
  lines.push('dashVersion=' + String(stats.dashVersion || ''));
  lines.push('routeVersion=' + String(stats.routeVersion || ''));
  lines.push('signalVersion=' + String(stats.signalVersion || ''));
  lines.push('routeMode=' + String(stats.routeMode || ''));
  lines.push('routeDecision=' + String(stats.routeDecision || ''));
  lines.push('dashboardReadDecision=' + String(stats.dashboardReadDecision || ''));
  lines.push('targetVerifyAuthorized=' + String(!!stats.targetVerifyAuthorized));
  lines.push('targetReadAuthorized=' + String(!!stats.targetReadAuthorized));
  lines.push('tenantId=' + String(stats.tenantId || ''));
  lines.push('tenantCanonical=' + String(!!stats.tenantCanonical));
  lines.push('targetReadWriteAuthorized=' + String(!!stats.targetReadWriteAuthorized));
  lines.push('legacyPathsSeen=' + String(stats.legacyPathsSeen || 0));
  lines.push('legacyPathsCompared=' + String(stats.legacyPathsCompared || 0));
  lines.push('mismatchedCount=' + String(stats.mismatchedCount || 0));
  lines.push('missingLegacyCount=' + String(stats.missingLegacyCount || 0));
  lines.push('missingTargetCount=' + String(stats.missingTargetCount || 0));
  lines.push('maxSamplePaths=' + String(stats.maxSamplePaths || PHBOX_M2_VERIFY_MAX_SAMPLE_PATHS_));
  lines.push('obsoleteHandlersCount=' + String(stats.obsoleteHandlersCount || 0));
  lines.push('firestoreReads=' + String(stats.firestoreReads || 0));
  lines.push('firestoreWrites=' + String(stats.firestoreWrites || 0));
  lines.push('publishFromTarget=' + String(!!stats.publishFromTarget));
  lines.push('publishToTarget=' + String(!!stats.publishToTarget));
  lines.push('targetPathBuilt=' + String(!!stats.targetPathBuilt));
  lines.push('cutover=' + String(!!stats.cutover));
  lines.push('lifecycleTouched=' + String(!!stats.lifecycleTouched));
  lines.push('stoppedEarly=' + String(!!stats.stoppedEarly));
  lines.push('violations=' + formatMigration2PostWriteVerifyList_(stats.violations));
  lines.push('obsoleteHandlers=' + formatMigration2PostWriteVerifyList_(stats.obsoleteHandlers));
  lines.push('error=' + (stats.error || 'none'));
  lines.push('errorKind=' + (stats.errorKind || 'none'));
  lines.push('items=');
  (result.items || []).forEach(function (item) {
    lines.push('- legacyPath=' + String(item.legacyPath || ''));
    lines.push('  targetPath=' + String(item.targetPath || ''));
    lines.push('  legacyExists=' + String(!!item.legacyExists));
    lines.push('  targetExists=' + String(!!item.targetExists));
    lines.push('  matched=' + String(!!item.matched));
    lines.push('  mismatchReasons=' + formatMigration2PostWriteVerifyList_(item.mismatchReasons));
  });
  return lines.join('\n');
}

function formatMigration2PostWriteVerifyList_(items) {
  items = uniqueNonEmptyStrings_(items || []);
  return items.length ? items.join(',') : 'none';
}
