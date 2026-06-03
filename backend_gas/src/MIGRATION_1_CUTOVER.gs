var PHBOX_M1_CUTOVER_STAGE_ = 'migration1_controlled_cutover';
var PHBOX_M1_CUTOVER_ENABLED_PROPERTY_ = 'PHBOX_M1_CUTOVER_ENABLED';
var PHBOX_M1_CUTOVER_TENANT_ID_PROPERTY_ = 'PHBOX_M1_CUTOVER_TENANT_ID';


function runMigration1CutoverRuntimeStatus_() {
  try {
    return runMigration1CutoverRuntimeStatusInternal_(PropertiesService.getScriptProperties(), { useRuntimeDualVerifier: true });
  } catch (e) {
    return {
      ok: false,
      stats: buildMigration1CutoverStats_({
        enabled: false,
        skipped: true,
        reason: 'cutover_runtime_error',
        error: normalizeRuntimeErrorMessage_(e),
        errorKind: classifyRuntimeFailureKind_(e)
      }),
      dualStats: null
    };
  }
}

function runMigration1CutoverRuntimeStatusInternal_(props, options) {
  props = props || PropertiesService.getScriptProperties();
  options = options || {};

  if (!isMigration1CutoverEnabled_(props)) {
    return buildMigration1CutoverResult_({
      ok: true,
      enabled: false,
      skipped: true,
      reason: 'cutover_disabled'
    });
  }

  var gateStage = runMigration1TargetRuntimeGateStage_({ props: props });
  if (!gateStage || !gateStage.ok) {
    return buildMigration1CutoverResult_({
      ok: false,
      enabled: true,
      skipped: true,
      reason: 'target_runtime_gate_error',
      error: String((gateStage && gateStage.error) || 'unknown'),
      errorKind: String((gateStage && gateStage.errorKind) || 'unknown')
    });
  }

  var targetRuntime = (gateStage.result && gateStage.result.targetRuntime) || {};
  if (!targetRuntime.enabled || !targetRuntime.tenantCanonical || !targetRuntime.targetReadWriteAuthorized) {
    return buildMigration1CutoverResult_({
      ok: false,
      enabled: true,
      skipped: true,
      reason: 'target_runtime_gate_off',
      tenantId: targetRuntime.tenantId || '',
      tenantCanonical: !!targetRuntime.tenantCanonical,
      targetReadWriteAuthorized: !!targetRuntime.targetReadWriteAuthorized
    });
  }

  var cutoverTenant = validateMigration1CutoverTenant_(props, targetRuntime.tenantId);
  var dualResult = options.dualResult || null;
  if (!dualResult && options.useRuntimeDualVerifier) {
    dualResult = runMigration1DualVerifierRuntimeStatus_();
  }
  if (!dualResult) {
    dualResult = buildMigration1CutoverTestDualResult_({
      ok: false,
      skipped: true,
      reason: 'dual_verifier_not_provided'
    });
  }

  var dualStats = (dualResult && dualResult.stats) || {};
  var dualOk = !!(dualResult && dualResult.ok);
  var dualCompared = Math.max(0, Number(dualStats.samplePathsCompared || 0));
  var dualMismatches = Math.max(0, Number(dualStats.mismatchedCount || 0));
  var dualMissingLegacy = Math.max(0, Number(dualStats.missingLegacyCount || 0));
  var dualMissingTarget = Math.max(0, Number(dualStats.missingTargetCount || 0));
  var dualReads = Math.max(0, Number(dualStats.firestoreReads || 0));

  if (!dualOk) {
    return buildMigration1CutoverResult_({
      ok: false,
      enabled: true,
      skipped: true,
      reason: 'dual_verifier_failed',
      tenantId: cutoverTenant,
      tenantCanonical: true,
      targetReadWriteAuthorized: true,
      dualVerified: false,
      samplePathsCompared: dualCompared,
      mismatchedCount: dualMismatches,
      missingLegacyCount: dualMissingLegacy,
      missingTargetCount: dualMissingTarget,
      firestoreReads: dualReads,
      dualStats: dualStats
    });
  }

  if (dualStats.skipped || dualCompared <= 0) {
    return buildMigration1CutoverResult_({
      ok: false,
      enabled: true,
      skipped: true,
      reason: 'dual_verifier_not_executed',
      tenantId: cutoverTenant,
      tenantCanonical: true,
      targetReadWriteAuthorized: true,
      dualVerified: false,
      samplePathsCompared: dualCompared,
      mismatchedCount: dualMismatches,
      missingLegacyCount: dualMissingLegacy,
      missingTargetCount: dualMissingTarget,
      firestoreReads: dualReads,
      dualStats: dualStats
    });
  }

  if (dualMismatches > 0 || dualMissingLegacy > 0 || dualMissingTarget > 0) {
    return buildMigration1CutoverResult_({
      ok: false,
      enabled: true,
      skipped: true,
      reason: 'dual_verifier_mismatches',
      tenantId: cutoverTenant,
      tenantCanonical: true,
      targetReadWriteAuthorized: true,
      dualVerified: false,
      samplePathsCompared: dualCompared,
      mismatchedCount: dualMismatches,
      missingLegacyCount: dualMissingLegacy,
      missingTargetCount: dualMissingTarget,
      firestoreReads: dualReads,
      dualStats: dualStats
    });
  }

  return buildMigration1CutoverResult_({
    ok: true,
    enabled: true,
    skipped: false,
    reason: '',
    tenantId: cutoverTenant,
    tenantCanonical: true,
    targetReadWriteAuthorized: true,
    dualVerified: true,
    samplePathsCompared: dualCompared,
    mismatchedCount: 0,
    missingLegacyCount: 0,
    missingTargetCount: 0,
    firestoreReads: dualReads,
    cutover: true,
    dualStats: dualStats
  });
}

function isMigration1CutoverEnabled_(props) {
  props = props || PropertiesService.getScriptProperties();
  var raw = props.getProperty(PHBOX_M1_CUTOVER_ENABLED_PROPERTY_);
  return /^true$/i.test(String(raw || '').trim());
}

function validateMigration1CutoverTenant_(props, runtimeTenantId) {
  props = props || PropertiesService.getScriptProperties();
  var cutoverTenant = normalizeMigration1CanonicalTenantSegment_(props.getProperty(PHBOX_M1_CUTOVER_TENANT_ID_PROPERTY_), PHBOX_M1_CUTOVER_TENANT_ID_PROPERTY_, {
    errorPrefix: 'M1_CUT',
    blockedOperationLabel: 'Nessun cutover autorizzato.'
  });
  var runtimeTenant = normalizeMigration1CanonicalTenantSegment_(runtimeTenantId, 'targetRuntime.tenantId', {
    errorPrefix: 'M1_CUT',
    blockedOperationLabel: 'Nessun cutover autorizzato.'
  });
  if (cutoverTenant !== runtimeTenant) {
    throw new Error('M1_CUT_TENANT_MISMATCH: ' + PHBOX_M1_CUTOVER_TENANT_ID_PROPERTY_ + ' diverso dal tenant runtime. Nessun cutover autorizzato.');
  }
  return cutoverTenant;
}

function buildMigration1CutoverResult_(data) {
  data = data || {};
  return {
    ok: data.ok !== false,
    stats: buildMigration1CutoverStats_(data),
    dualStats: data.dualStats || null
  };
}

function buildMigration1CutoverStats_(data) {
  data = data || {};
  return {
    stage: PHBOX_M1_CUTOVER_STAGE_,
    enabled: !!data.enabled,
    skipped: data.skipped !== false,
    reason: String(data.reason || ''),
    tenantId: String(data.tenantId || ''),
    tenantCanonical: !!data.tenantCanonical,
    targetReadWriteAuthorized: !!data.targetReadWriteAuthorized,
    dualVerified: !!data.dualVerified,
    samplePathsCompared: Math.max(0, Number(data.samplePathsCompared || 0)),
    mismatchedCount: Math.max(0, Number(data.mismatchedCount || 0)),
    missingLegacyCount: Math.max(0, Number(data.missingLegacyCount || 0)),
    missingTargetCount: Math.max(0, Number(data.missingTargetCount || 0)),
    firestoreReads: Math.max(0, Number(data.firestoreReads || 0)),
    firestoreWrites: 0,
    publishFromTarget: false,
    publishToTarget: false,
    targetPathBuilt: false,
    cutover: !!data.cutover,
    lifecycleTouched: false,
    stoppedEarly: false,
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };
}

function buildMigration1CutoverTestProperties_(values) {
  values = values || {};
  return {
    getProperty: function (name) {
      return Object.prototype.hasOwnProperty.call(values, name) ? values[name] : null;
    }
  };
}

function buildMigration1CutoverTestDualResult_(data) {
  data = data || {};
  return {
    ok: data.ok !== false,
    stats: {
      enabled: true,
      skipped: data.skipped !== false,
      reason: String(data.reason || ''),
      samplePathsCompared: Math.max(0, Number(data.samplePathsCompared || 0)),
      mismatchedCount: Math.max(0, Number(data.mismatchedCount || 0)),
      missingLegacyCount: Math.max(0, Number(data.missingLegacyCount || 0)),
      missingTargetCount: Math.max(0, Number(data.missingTargetCount || 0)),
      firestoreReads: Math.max(0, Number(data.firestoreReads || 0)),
      firestoreWrites: 0,
      publishFromTarget: false,
      publishToTarget: false,
      targetPathBuilt: false,
      cutover: false,
      lifecycleTouched: false
    }
  };
}

function runMigration1CutoverSelfTest_() {
  var tenantId = 'farmacia_santa_venera';
  var canonicalGate = {
    PHBOX_M1_TARGET_RUNTIME_ENABLED: 'true',
    PHBOX_TENANT_ID: tenantId,
    PHBOX_EXPECTED_CANONICAL_TENANT_ID: tenantId,
    PHBOX_M1_CUTOVER_ENABLED: 'true',
    PHBOX_M1_CUTOVER_TENANT_ID: tenantId
  };
  var cases = [
    {
      id: 'default_cutover_disabled_skips_without_gate_or_reads',
      props: {},
      dual: null,
      expected: { ok: true, enabled: false, skipped: true, reason: 'cutover_disabled', cutover: false, firestoreReads: 0 }
    },
    {
      id: 'enabled_gate_off_rejected_without_cutover',
      props: { PHBOX_M1_CUTOVER_ENABLED: 'true', PHBOX_M1_CUTOVER_TENANT_ID: tenantId },
      dual: null,
      expected: { ok: false, enabled: true, skipped: true, reason: 'target_runtime_gate_off', cutover: false, firestoreReads: 0 }
    },
    {
      id: 'enabled_missing_cutover_tenant_rejected',
      props: {
        PHBOX_M1_TARGET_RUNTIME_ENABLED: 'true',
        PHBOX_TENANT_ID: tenantId,
        PHBOX_EXPECTED_CANONICAL_TENANT_ID: tenantId,
        PHBOX_M1_CUTOVER_ENABLED: 'true'
      },
      expected: { ok: false, errorContains: 'M1_CUT_TENANT_MISSING', cutover: false }
    },
    {
      id: 'enabled_mismatch_cutover_tenant_rejected',
      props: {
        PHBOX_M1_TARGET_RUNTIME_ENABLED: 'true',
        PHBOX_TENANT_ID: tenantId,
        PHBOX_EXPECTED_CANONICAL_TENANT_ID: tenantId,
        PHBOX_M1_CUTOVER_ENABLED: 'true',
        PHBOX_M1_CUTOVER_TENANT_ID: 'farmacia_diversa'
      },
      expected: { ok: false, errorContains: 'M1_CUT_TENANT_MISMATCH', cutover: false }
    },
    {
      id: 'enabled_slash_cutover_tenant_rejected',
      props: {
        PHBOX_M1_TARGET_RUNTIME_ENABLED: 'true',
        PHBOX_TENANT_ID: tenantId,
        PHBOX_EXPECTED_CANONICAL_TENANT_ID: tenantId,
        PHBOX_M1_CUTOVER_ENABLED: 'true',
        PHBOX_M1_CUTOVER_TENANT_ID: 'farmacia/santa/venera'
      },
      expected: { ok: false, errorContains: 'M1_CUT_TENANT_NOT_CANONICAL', cutover: false }
    },
    {
      id: 'enabled_dual_not_executed_blocks_cutover',
      props: canonicalGate,
      dual: buildMigration1CutoverTestDualResult_({ ok: true, skipped: true, reason: 'no_sample_paths_configured', samplePathsCompared: 0 }),
      expected: { ok: false, enabled: true, skipped: true, reason: 'dual_verifier_not_executed', dualVerified: false, cutover: false, firestoreReads: 0 }
    },
    {
      id: 'enabled_dual_mismatch_blocks_cutover',
      props: canonicalGate,
      dual: buildMigration1CutoverTestDualResult_({ ok: false, skipped: false, samplePathsCompared: 2, mismatchedCount: 1, firestoreReads: 4 }),
      expected: { ok: false, enabled: true, skipped: true, reason: 'dual_verifier_failed', dualVerified: false, cutover: false, firestoreReads: 4 }
    },
    {
      id: 'enabled_dual_match_authorizes_single_tenant_cutover',
      props: canonicalGate,
      dual: buildMigration1CutoverTestDualResult_({ ok: true, skipped: false, samplePathsCompared: 2, mismatchedCount: 0, firestoreReads: 4 }),
      expected: { ok: true, enabled: true, skipped: false, reason: '', dualVerified: true, cutover: true, firestoreReads: 4, tenantId: tenantId }
    }
  ];

  var passed = 0;
  var failed = 0;
  var items = cases.map(function (item) {
    var actual = runMigration1CutoverSelfTestCase_(item);
    var mismatchReasons = compareMigration1CutoverExpected_(actual, item.expected || {});
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

function runMigration1CutoverSelfTestCase_(item) {
  try {
    var result = runMigration1CutoverRuntimeStatusInternal_(buildMigration1CutoverTestProperties_(item.props || {}), {
      useRuntimeDualVerifier: false,
      dualResult: item.dual || null
    });
    var stats = (result && result.stats) || {};
    return {
      ok: !!(result && result.ok),
      enabled: !!stats.enabled,
      skipped: !!stats.skipped,
      reason: String(stats.reason || ''),
      tenantId: String(stats.tenantId || ''),
      tenantCanonical: !!stats.tenantCanonical,
      targetReadWriteAuthorized: !!stats.targetReadWriteAuthorized,
      dualVerified: !!stats.dualVerified,
      samplePathsCompared: Math.max(0, Number(stats.samplePathsCompared || 0)),
      mismatchedCount: Math.max(0, Number(stats.mismatchedCount || 0)),
      firestoreReads: Math.max(0, Number(stats.firestoreReads || 0)),
      firestoreWrites: Math.max(0, Number(stats.firestoreWrites || 0)),
      publishFromTarget: !!stats.publishFromTarget,
      publishToTarget: !!stats.publishToTarget,
      targetPathBuilt: !!stats.targetPathBuilt,
      cutover: !!stats.cutover,
      lifecycleTouched: !!stats.lifecycleTouched,
      error: String(stats.error || '')
    };
  } catch (e) {
    return {
      ok: false,
      enabled: true,
      skipped: true,
      reason: 'cutover_error',
      tenantId: '',
      tenantCanonical: false,
      targetReadWriteAuthorized: false,
      dualVerified: false,
      samplePathsCompared: 0,
      mismatchedCount: 0,
      firestoreReads: 0,
      firestoreWrites: 0,
      publishFromTarget: false,
      publishToTarget: false,
      targetPathBuilt: false,
      cutover: false,
      lifecycleTouched: false,
      error: normalizeRuntimeErrorMessage_(e)
    };
  }
}

function compareMigration1CutoverExpected_(actual, expected) {
  var mismatches = [];
  Object.keys(expected || {}).forEach(function (key) {
    if (key === 'errorContains') {
      var expectedError = String(expected[key] || '');
      if (expectedError && String(actual.error || '').indexOf(expectedError) === -1) mismatches.push('missing_error_' + expectedError);
      return;
    }
    if (actual[key] !== expected[key]) mismatches.push('field_' + key + '_mismatch');
  });
  if (actual.firestoreWrites !== 0) mismatches.push('firestore_writes_not_zero');
  if (actual.publishFromTarget) mismatches.push('publish_from_target_true');
  if (actual.publishToTarget) mismatches.push('publish_to_target_true');
  if (actual.targetPathBuilt) mismatches.push('target_path_built_true');
  if (actual.lifecycleTouched) mismatches.push('lifecycle_touched_true');
  return uniqueNonEmptyStrings_(mismatches);
}

function formatMigration1CutoverSelfTestFeedback_(result) {
  result = result || runMigration1CutoverSelfTest_();
  var lines = [];
  lines.push('MIGRATION_1_CUT_TEST');
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
    lines.push('  enabled=' + String(!!actual.enabled));
    lines.push('  skipped=' + String(!!actual.skipped));
    lines.push('  reason=' + String(actual.reason || ''));
    lines.push('  tenantId=' + String(actual.tenantId || ''));
    lines.push('  dualVerified=' + String(!!actual.dualVerified));
    lines.push('  samplePathsCompared=' + String(actual.samplePathsCompared || 0));
    lines.push('  mismatchedCount=' + String(actual.mismatchedCount || 0));
    lines.push('  firestoreReads=' + String(actual.firestoreReads || 0));
    lines.push('  firestoreWrites=' + String(actual.firestoreWrites || 0));
    lines.push('  publishFromTarget=' + String(!!actual.publishFromTarget));
    lines.push('  publishToTarget=' + String(!!actual.publishToTarget));
    lines.push('  targetPathBuilt=' + String(!!actual.targetPathBuilt));
    lines.push('  cutover=' + String(!!actual.cutover));
    lines.push('  lifecycleTouched=' + String(!!actual.lifecycleTouched));
    lines.push('  error=' + (actual.error ? actual.error : 'none'));
    lines.push('  mismatchReasons=' + ((item.mismatchReasons || []).length ? item.mismatchReasons.join(',') : 'none'));
  });
  return lines.join('\n');
}

function formatMigration1CutoverRuntimeFeedback_(result) {
  result = result || runMigration1CutoverRuntimeStatus_();
  var stats = (result && result.stats) || {};
  var lines = [];
  lines.push('MIGRATION_1_CUT_RUNTIME_STATUS');
  lines.push('ok=' + String(!!(result && result.ok)));
  lines.push('enabled=' + String(!!stats.enabled));
  lines.push('skipped=' + String(!!stats.skipped));
  lines.push('reason=' + String(stats.reason || ''));
  lines.push('tenantId=' + String(stats.tenantId || ''));
  lines.push('tenantCanonical=' + String(!!stats.tenantCanonical));
  lines.push('targetReadWriteAuthorized=' + String(!!stats.targetReadWriteAuthorized));
  lines.push('dualVerified=' + String(!!stats.dualVerified));
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
  lines.push('error=' + (stats.error ? stats.error : 'none'));
  lines.push('errorKind=' + (stats.errorKind ? stats.errorKind : 'none'));
  return lines.join('\n');
}
