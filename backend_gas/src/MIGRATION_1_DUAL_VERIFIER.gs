var PHBOX_M1_DUAL_STAGE_ = 'migration1_dual_readonly_verifier';
var PHBOX_M1_DUAL_SAMPLE_PATHS_PROPERTY_ = 'PHBOX_M1_DUAL_SAMPLE_LEGACY_PATHS';
var PHBOX_M1_DUAL_MAX_SAMPLE_PATHS_ = 10;

function runMigration1DualVerifierRuntimeStatus_() {
  var cfg = getPhboxConfig_();
  var gateStage = runMigration1TargetRuntimeGateStage_({});
  if (!gateStage || !gateStage.ok) {
    return {
      ok: false,
      stats: buildMigration1DualVerifierStats_({
        enabled: false,
        skipped: true,
        reason: 'target_runtime_gate_error',
        error: String((gateStage && gateStage.error) || 'unknown'),
        errorKind: String((gateStage && gateStage.errorKind) || 'unknown')
      }),
      items: []
    };
  }

  var gateStats = (gateStage.result && gateStage.result.stats) || {};
  var targetRuntime = (gateStage.result && gateStage.result.targetRuntime) || {};
  if (!gateStats.enabled || !targetRuntime.enabled) {
    return {
      ok: true,
      stats: buildMigration1DualVerifierStats_({
        enabled: false,
        skipped: true,
        reason: 'target_runtime_gate_off'
      }),
      items: []
    };
  }

  var samplePaths = readMigration1DualVerifierSampleLegacyPaths_();
  if (!samplePaths.length) {
    return {
      ok: true,
      stats: buildMigration1DualVerifierStats_({
        enabled: true,
        skipped: true,
        reason: 'no_sample_paths_configured',
        tenantId: targetRuntime.tenantId,
        tenantCanonical: !!targetRuntime.tenantCanonical,
        targetReadWriteAuthorized: !!targetRuntime.targetReadWriteAuthorized,
        samplePathsSeen: 0,
        samplePathsCompared: 0
      }),
      items: []
    };
  }

  return runMigration1DualVerifierForLegacyPaths_(cfg, targetRuntime, samplePaths);
}

function runMigration1DualVerifierForLegacyPaths_(cfg, targetRuntime, legacyPaths) {
  cfg = cfg || getPhboxConfig_();
  legacyPaths = legacyPaths || [];
  if (!targetRuntime || !targetRuntime.enabled || !targetRuntime.targetReadWriteAuthorized || !targetRuntime.tenantCanonical) {
    throw new Error('M1_DUAL_TARGET_RUNTIME_CLOSED: verifier target non autorizzato. Nessun target path letto.');
  }

  var tenantId = normalizeMigration1CanonicalTenantSegment_(targetRuntime.tenantId, 'tenantId', {
    errorPrefix: 'M1_DUAL',
    blockedOperationLabel: 'Nessun target path letto.'
  });

  var boundedPaths = legacyPaths.slice(0, PHBOX_M1_DUAL_MAX_SAMPLE_PATHS_);
  var items = [];
  var mismatchedCount = 0;
  var missingTargetCount = 0;
  var missingLegacyCount = 0;
  var reads = 0;
  var targetPathBuilt = false;

  boundedPaths.forEach(function (legacyPath) {
    var normalizedLegacy = normalizeMigration1DualLegacyPath_(legacyPath);
    var targetPath = buildMigration1DualTargetPath_(tenantId, normalizedLegacy);
    targetPathBuilt = true;

    var legacyDoc = getFirestoreDocumentByPath_(cfg, normalizedLegacy.pathParts);
    var targetDoc = getFirestoreDocumentByPath_(cfg, targetPath.pathParts);
    reads += 2;

    var legacyExists = !!legacyDoc;
    var targetExists = !!targetDoc;
    var legacySignature = legacyExists ? buildMigration1DualComparableSignature_(legacyDoc) : '';
    var targetSignature = targetExists ? buildMigration1DualComparableSignature_(targetDoc) : '';
    var mismatchReasons = [];

    if (!legacyExists) {
      missingLegacyCount++;
      mismatchReasons.push('legacy_missing');
    }
    if (!targetExists) {
      missingTargetCount++;
      mismatchReasons.push('target_missing');
    }
    if (legacyExists && targetExists && legacySignature !== targetSignature) {
      mismatchReasons.push('signature_mismatch');
    }
    if (mismatchReasons.length) mismatchedCount++;

    items.push({
      legacyPath: normalizedLegacy.path,
      targetPath: targetPath.path,
      legacyExists: legacyExists,
      targetExists: targetExists,
      matched: mismatchReasons.length === 0,
      mismatchReasons: uniqueNonEmptyStrings_(mismatchReasons)
    });
  });

  return {
    ok: mismatchedCount === 0,
    stats: buildMigration1DualVerifierStats_({
      enabled: true,
      skipped: false,
      reason: '',
      tenantId: tenantId,
      tenantCanonical: true,
      targetReadWriteAuthorized: true,
      samplePathsSeen: legacyPaths.length,
      samplePathsCompared: boundedPaths.length,
      mismatchedCount: mismatchedCount,
      missingLegacyCount: missingLegacyCount,
      missingTargetCount: missingTargetCount,
      firestoreReads: reads,
      targetPathBuilt: targetPathBuilt,
      stoppedEarly: legacyPaths.length > boundedPaths.length
    }),
    items: items
  };
}

function buildMigration1DualVerifierStats_(data) {
  data = data || {};
  return {
    stage: PHBOX_M1_DUAL_STAGE_,
    enabled: !!data.enabled,
    skipped: data.skipped !== false,
    reason: String(data.reason || ''),
    tenantId: String(data.tenantId || ''),
    tenantCanonical: !!data.tenantCanonical,
    targetReadWriteAuthorized: !!data.targetReadWriteAuthorized,
    samplePathsSeen: Math.max(0, Number(data.samplePathsSeen || 0)),
    samplePathsCompared: Math.max(0, Number(data.samplePathsCompared || 0)),
    mismatchedCount: Math.max(0, Number(data.mismatchedCount || 0)),
    missingLegacyCount: Math.max(0, Number(data.missingLegacyCount || 0)),
    missingTargetCount: Math.max(0, Number(data.missingTargetCount || 0)),
    firestoreReads: Math.max(0, Number(data.firestoreReads || 0)),
    firestoreWrites: 0,
    publishFromTarget: false,
    publishToTarget: false,
    targetPathBuilt: !!data.targetPathBuilt,
    cutover: false,
    lifecycleTouched: false,
    stoppedEarly: !!data.stoppedEarly,
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };
}

function readMigration1DualVerifierSampleLegacyPaths_() {
  var props = PropertiesService.getScriptProperties();
  var raw = String(props.getProperty(PHBOX_M1_DUAL_SAMPLE_PATHS_PROPERTY_) || '');
  return parseMigration1DualVerifierSampleLegacyPaths_(raw);
}

function parseMigration1DualVerifierSampleLegacyPaths_(raw) {
  return uniqueNonEmptyStrings_(String(raw || '').split(/\r?\n/).map(function (line) {
    return String(line || '').trim();
  })).slice(0, PHBOX_M1_DUAL_MAX_SAMPLE_PATHS_);
}

function normalizeMigration1DualLegacyPath_(legacyPath) {
  var path = String(legacyPath || '').trim();
  path = path.replace(/^\/+/, '').replace(/\/+$/, '');
  if (!path) throw new Error('M1_DUAL_LEGACY_PATH_EMPTY: path legacy vuoto. Nessun target path letto.');
  if (path.indexOf('tenants/') === 0) {
    throw new Error('M1_DUAL_LEGACY_PATH_ALREADY_TARGET: path legacy già target-prefixed. Nessun target path letto.');
  }
  if (path.indexOf('//') !== -1) {
    throw new Error('M1_DUAL_LEGACY_PATH_INVALID: path legacy contiene segmento vuoto. Nessun target path letto.');
  }
  var parts = path.split('/').map(function (part) {
    return String(part || '').trim();
  });
  if (!parts.length || parts.length % 2 !== 0) {
    throw new Error('M1_DUAL_LEGACY_PATH_INVALID: path legacy deve puntare a documento collection/document. Nessun target path letto.');
  }
  parts.forEach(function (part) {
    if (!part) throw new Error('M1_DUAL_LEGACY_PATH_INVALID: path legacy contiene segmento vuoto. Nessun target path letto.');
  });
  return {
    path: parts.join('/'),
    pathParts: parts
  };
}

function buildMigration1DualTargetPath_(tenantId, normalizedLegacyPath) {
  var canonicalTenantId = normalizeMigration1CanonicalTenantSegment_(tenantId, 'tenantId', {
    errorPrefix: 'M1_DUAL',
    blockedOperationLabel: 'Nessun target path letto.'
  });
  var normalized = normalizedLegacyPath && normalizedLegacyPath.pathParts ? normalizedLegacyPath : normalizeMigration1DualLegacyPath_(normalizedLegacyPath);
  var parts = ['tenants', canonicalTenantId].concat(normalized.pathParts);
  return {
    path: parts.join('/'),
    pathParts: parts
  };
}

function buildMigration1DualComparableSignature_(doc) {
  return stableStringifyMigration1Dual_(normalizeMigration1DualComparableValue_(doc || {}));
}

function normalizeMigration1DualComparableValue_(value) {
  if (value === null || value === undefined) return null;
  if (Array.isArray(value)) {
    return value.map(function (item) {
      return normalizeMigration1DualComparableValue_(item);
    });
  }
  if (typeof value === 'object') {
    var out = {};
    Object.keys(value).sort().forEach(function (key) {
      if (key === 'documentName' || key === 'documentPath' || key === 'collectionId' || key === 'parentDocumentId') return;
      out[key] = normalizeMigration1DualComparableValue_(value[key]);
    });
    return out;
  }
  return value;
}

function stableStringifyMigration1Dual_(value) {
  if (value === null || value === undefined) return 'null';
  if (Array.isArray(value)) {
    return '[' + value.map(function (item) { return stableStringifyMigration1Dual_(item); }).join(',') + ']';
  }
  if (typeof value === 'object') {
    return '{' + Object.keys(value).sort().map(function (key) {
      return JSON.stringify(key) + ':' + stableStringifyMigration1Dual_(value[key]);
    }).join(',') + '}';
  }
  return JSON.stringify(value);
}

function runMigration1DualVerifierSelfTest_() {
  var canonicalTenant = 'farmacia_santa_venera';
  var canonicalProps = {
    PHBOX_M1_TARGET_RUNTIME_ENABLED: 'true',
    PHBOX_TENANT_ID: canonicalTenant,
    PHBOX_EXPECTED_CANONICAL_TENANT_ID: canonicalTenant
  };
  var cases = [
    {
      id: 'gate_off_skips_without_path',
      props: {},
      paths: ['patients/RSSMRA80A01H501U'],
      expected: { ok: true, skipped: true, targetPathBuilt: false, firestoreReads: 0, reason: 'target_runtime_gate_off' }
    },
    {
      id: 'gate_on_no_samples_skips_without_reads',
      props: canonicalProps,
      paths: [],
      expected: { ok: true, skipped: true, targetPathBuilt: false, firestoreReads: 0, reason: 'no_sample_paths_configured' }
    },
    {
      id: 'canonical_tenant_builds_target_path',
      props: canonicalProps,
      pureLegacyPath: 'patients/RSSMRA80A01H501U',
      expected: { targetPath: 'tenants/farmacia_santa_venera/patients/RSSMRA80A01H501U' }
    },
    {
      id: 'target_prefixed_legacy_path_rejected',
      props: canonicalProps,
      pureLegacyPath: 'tenants/farmacia_santa_venera/patients/RSSMRA80A01H501U',
      expected: { errorContains: 'M1_DUAL_LEGACY_PATH_ALREADY_TARGET' }
    },
    {
      id: 'odd_segment_legacy_path_rejected',
      props: canonicalProps,
      pureLegacyPath: 'patients',
      expected: { errorContains: 'M1_DUAL_LEGACY_PATH_INVALID' }
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
      id: 'sample_paths_are_bounded',
      rawPaths: 'patients/A\npatients/B\npatients/C\npatients/D\npatients/E\npatients/F\npatients/G\npatients/H\npatients/I\npatients/J\npatients/K',
      expected: { sampleCount: PHBOX_M1_DUAL_MAX_SAMPLE_PATHS_ }
    }
  ];

  var passed = 0;
  var failed = 0;
  var items = cases.map(function (item) {
    var actual = runMigration1DualVerifierSelfTestCase_(item);
    var mismatchReasons = compareMigration1DualVerifierExpected_(actual, item.expected || {});
    var ok = mismatchReasons.length === 0;
    if (ok) passed++; else failed++;
    return {
      id: item.id,
      passed: ok,
      actual: actual,
      expected: item.expected || {},
      mismatchReasons: mismatchReasons
    };
  });

  return {
    ok: failed === 0,
    testCount: items.length,
    passedCount: passed,
    failedCount: failed,
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

function runMigration1DualVerifierSelfTestCase_(item) {
  try {
    if (item.rawPaths !== undefined) {
      return { sampleCount: parseMigration1DualVerifierSampleLegacyPaths_(item.rawPaths).length };
    }
    if (item.legacyDoc || item.targetDoc) {
      var legacySignature = buildMigration1DualComparableSignature_(item.legacyDoc || {});
      var targetSignature = buildMigration1DualComparableSignature_(item.targetDoc || {});
      var matched = legacySignature === targetSignature;
      return {
        matched: matched,
        mismatchReasons: matched ? [] : ['signature_mismatch']
      };
    }
    if (item.pureLegacyPath) {
      var gate = runMigration1TargetRuntimeGateStage_({ props: createMigration1TargetRuntimeGateTestProperties_(item.props || {}) });
      if (!gate || !gate.ok) {
        return { error: String((gate && gate.error) || 'unknown') };
      }
      var targetRuntime = gate.result && gate.result.targetRuntime;
      var normalized = normalizeMigration1DualLegacyPath_(item.pureLegacyPath);
      var targetPath = buildMigration1DualTargetPath_(targetRuntime.tenantId, normalized);
      return {
        targetPath: targetPath.path,
        targetPathBuilt: true,
        firestoreReads: 0,
        firestoreWrites: 0
      };
    }
    var stage = runMigration1TargetRuntimeGateStage_({ props: createMigration1TargetRuntimeGateTestProperties_(item.props || {}) });
    if (!stage || !stage.ok) {
      return {
        ok: false,
        skipped: true,
        reason: 'target_runtime_gate_error',
        targetPathBuilt: false,
        firestoreReads: 0,
        firestoreWrites: 0,
        error: String((stage && stage.error) || 'unknown')
      };
    }
    var targetRuntime = (stage.result && stage.result.targetRuntime) || {};
    if (!targetRuntime.enabled) {
      return {
        ok: true,
        skipped: true,
        reason: 'target_runtime_gate_off',
        targetPathBuilt: false,
        firestoreReads: 0,
        firestoreWrites: 0
      };
    }
    if (!(item.paths || []).length) {
      return {
        ok: true,
        skipped: true,
        reason: 'no_sample_paths_configured',
        targetPathBuilt: false,
        firestoreReads: 0,
        firestoreWrites: 0
      };
    }
    return {
      ok: true,
      skipped: false,
      reason: '',
      targetPathBuilt: false,
      firestoreReads: 0,
      firestoreWrites: 0
    };
  } catch (e) {
    return {
      error: normalizeRuntimeErrorMessage_(e),
      targetPathBuilt: false,
      firestoreReads: 0,
      firestoreWrites: 0
    };
  }
}

function compareMigration1DualVerifierExpected_(actual, expected) {
  var mismatches = [];
  Object.keys(expected || {}).forEach(function (key) {
    if (key === 'errorContains') {
      var expectedError = String(expected[key] || '');
      if (expectedError && String(actual.error || '').indexOf(expectedError) === -1) {
        mismatches.push('missing_error_' + expectedError);
      }
      return;
    }
    if (key === 'reason') {
      var expectedReason = String(expected[key] || '');
      if (expectedReason && (actual.reason !== expectedReason) && ((actual.mismatchReasons || []).indexOf(expectedReason) === -1)) {
        mismatches.push('reason_mismatch');
      }
      return;
    }
    if (key === 'matched') {
      if (!!actual.matched !== !!expected[key]) mismatches.push('matched_mismatch');
      return;
    }
    if (key === 'reason' || key === 'errorContains') return;
    if (actual[key] !== expected[key]) {
      mismatches.push('field_' + key + '_mismatch');
    }
  });
  if (Number(actual.firestoreWrites || 0) !== 0) mismatches.push('firestore_writes_not_zero');
  return uniqueNonEmptyStrings_(mismatches);
}

function formatMigration1DualVerifierSelfTestFeedback_(result) {
  result = result || runMigration1DualVerifierSelfTest_();
  var lines = [];
  lines.push('MIGRATION_1_DUAL_TEST');
  lines.push('ok=' + String(!!result.ok));
  lines.push('testCount=' + String(result.testCount || 0));
  lines.push('passedCount=' + String(result.passedCount || 0));
  lines.push('failedCount=' + String(result.failedCount || 0));
  lines.push('firestoreReads=' + String(result.firestoreReads || 0));
  lines.push('firestoreWrites=' + String(result.firestoreWrites || 0));
  lines.push('publishFromTarget=' + String(!!result.publishFromTarget));
  lines.push('publishToTarget=' + String(!!result.publishToTarget));
  lines.push('targetPathBuilt=' + String(!!result.targetPathBuilt));
  lines.push('cutover=' + String(!!result.cutover));
  lines.push('lifecycleTouched=' + String(!!result.lifecycleTouched));
  lines.push('items=');
  (result.items || []).forEach(function (item) {
    var actual = item.actual || {};
    lines.push('- id=' + item.id);
    lines.push('  passed=' + String(!!item.passed));
    lines.push('  targetPath=' + String(actual.targetPath || ''));
    lines.push('  matched=' + String(actual.matched === undefined ? '' : !!actual.matched));
    lines.push('  reason=' + String(actual.reason || ''));
    lines.push('  sampleCount=' + String(actual.sampleCount === undefined ? '' : actual.sampleCount));
    lines.push('  firestoreReads=' + String(actual.firestoreReads || 0));
    lines.push('  firestoreWrites=' + String(actual.firestoreWrites || 0));
    lines.push('  publishFromTarget=false');
    lines.push('  publishToTarget=false');
    lines.push('  targetPathBuilt=' + String(!!actual.targetPathBuilt));
    lines.push('  cutover=false');
    lines.push('  lifecycleTouched=false');
    lines.push('  error=' + String(actual.error || 'none'));
    lines.push('  mismatchReasons=' + ((item.mismatchReasons || []).length ? item.mismatchReasons.join(',') : 'none'));
  });
  return lines.join('\n');
}

function formatMigration1DualVerifierRuntimeFeedback_(result) {
  result = result || runMigration1DualVerifierRuntimeStatus_();
  var stats = (result && result.stats) || buildMigration1DualVerifierStats_({ reason: 'missing_stats' });
  var lines = [];
  lines.push('MIGRATION_1_DUAL_RUNTIME_STATUS');
  lines.push('ok=' + String(!!(result && result.ok)));
  lines.push('enabled=' + String(!!stats.enabled));
  lines.push('skipped=' + String(!!stats.skipped));
  lines.push('reason=' + String(stats.reason || ''));
  lines.push('tenantId=' + String(stats.tenantId || ''));
  lines.push('tenantCanonical=' + String(!!stats.tenantCanonical));
  lines.push('targetReadWriteAuthorized=' + String(!!stats.targetReadWriteAuthorized));
  lines.push('samplePathsSeen=' + String(stats.samplePathsSeen || 0));
  lines.push('samplePathsCompared=' + String(stats.samplePathsCompared || 0));
  lines.push('mismatchedCount=' + String(stats.mismatchedCount || 0));
  lines.push('missingLegacyCount=' + String(stats.missingLegacyCount || 0));
  lines.push('missingTargetCount=' + String(stats.missingTargetCount || 0));
  lines.push('firestoreReads=' + String(stats.firestoreReads || 0));
  lines.push('firestoreWrites=' + String(stats.firestoreWrites || 0));
  lines.push('publishFromTarget=' + String(!!stats.publishFromTarget));
  lines.push('publishToTarget=' + String(!!stats.publishToTarget));
  lines.push('targetPathBuilt=' + String(!!stats.targetPathBuilt));
  lines.push('cutover=' + String(!!stats.cutover));
  lines.push('lifecycleTouched=' + String(!!stats.lifecycleTouched));
  lines.push('stoppedEarly=' + String(!!stats.stoppedEarly));
  lines.push('error=' + String(stats.error || 'none'));
  lines.push('errorKind=' + String(stats.errorKind || 'none'));
  lines.push('items=');
  (result.items || []).forEach(function (item) {
    lines.push('- legacyPath=' + item.legacyPath);
    lines.push('  targetPath=' + item.targetPath);
    lines.push('  legacyExists=' + String(!!item.legacyExists));
    lines.push('  targetExists=' + String(!!item.targetExists));
    lines.push('  matched=' + String(!!item.matched));
    lines.push('  mismatchReasons=' + ((item.mismatchReasons || []).length ? item.mismatchReasons.join(',') : 'none'));
  });
  return lines.join('\n');
}
