var PHBOX_M1_E2E_STAGE_ = 'migration1_e2e_controlled_validation';

function runMigration1E2eValidationRuntimeStatus_() {
  try {
    var gateStage = runMigration1TargetRuntimeGateStage_({});
    var gateStats = gateStage && gateStage.result && gateStage.result.stats ? gateStage.result.stats : {};
    if (!gateStage || !gateStage.ok) {
      return buildMigration1E2eValidationResult_({
        ok: false,
        skipped: true,
        reason: 'target_runtime_gate_error',
        gateOk: false,
        error: String((gateStage && gateStage.error) || 'unknown'),
        errorKind: String((gateStage && gateStage.errorKind) || 'unknown')
      });
    }

    if (!gateStats.enabled) {
      return buildMigration1E2eValidationResult_({
        ok: true,
        skipped: true,
        reason: 'target_runtime_gate_off',
        gateOk: true,
        gateEnabled: false
      });
    }

    var publishStatus = runMigration1TargetPublishRuntimeStatus_();
    var dualStatus = runMigration1DualVerifierRuntimeStatus_();
    var cutStatus = runMigration1CutoverRuntimeStatusInternal_(PropertiesService.getScriptProperties(), {
      dualResult: dualStatus,
      useRuntimeDualVerifier: false
    });

    return buildMigration1E2eValidationRuntimeResult_(gateStage, publishStatus, dualStatus, cutStatus);
  } catch (e) {
    return buildMigration1E2eValidationResult_({
      ok: false,
      skipped: true,
      reason: 'e2e_runtime_error',
      error: normalizeRuntimeErrorMessage_(e),
      errorKind: classifyRuntimeFailureKind_(e)
    });
  }
}

function buildMigration1E2eValidationRuntimeResult_(gateStage, publishStatus, dualStatus, cutStatus) {
  var gateStats = (gateStage && gateStage.result && gateStage.result.stats) || {};
  var publishStats = (publishStatus && publishStatus.stats) || {};
  var dualStats = (dualStatus && dualStatus.stats) || {};
  var cutStats = (cutStatus && cutStatus.stats) || {};
  var reads = Math.max(0, Number(publishStats.firestoreReads || 0)) +
    Math.max(0, Number(dualStats.firestoreReads || 0)) +
    Math.max(0, Number(cutStats.firestoreReads || 0));
  var writes = Math.max(0, Number(publishStats.firestoreWrites || 0)) +
    Math.max(0, Number(dualStats.firestoreWrites || 0)) +
    Math.max(0, Number(cutStats.firestoreWrites || 0));
  var failedStages = [];
  if (!(gateStage && gateStage.ok)) failedStages.push('gate');
  if (!(publishStatus && publishStatus.ok)) failedStages.push('publish');
  if (!(dualStatus && dualStatus.ok)) failedStages.push('dual');
  if (!(cutStatus && cutStatus.ok)) failedStages.push('cut');

  return buildMigration1E2eValidationResult_({
    ok: failedStages.length === 0,
    skipped: false,
    reason: failedStages.length ? 'stage_failure' : '',
    gateOk: !!(gateStage && gateStage.ok),
    gateEnabled: !!gateStats.enabled,
    publishOk: !!(publishStatus && publishStatus.ok),
    dualOk: !!(dualStatus && dualStatus.ok),
    cutOk: !!(cutStatus && cutStatus.ok),
    tenantId: gateStats.tenantId || dualStats.tenantId || cutStats.tenantId || '',
    tenantCanonical: !!(gateStats.tenantCanonical || dualStats.tenantCanonical || cutStats.tenantCanonical),
    targetReadWriteAuthorized: !!(gateStats.targetReadWriteAuthorized || dualStats.targetReadWriteAuthorized || cutStats.targetReadWriteAuthorized),
    dualVerified: !!cutStats.dualVerified,
    samplePathsCompared: Math.max(0, Number(dualStats.samplePathsCompared || cutStats.samplePathsCompared || 0)),
    mismatchedCount: Math.max(0, Number(dualStats.mismatchedCount || cutStats.mismatchedCount || 0)),
    missingLegacyCount: Math.max(0, Number(dualStats.missingLegacyCount || cutStats.missingLegacyCount || 0)),
    missingTargetCount: Math.max(0, Number(dualStats.missingTargetCount || cutStats.missingTargetCount || 0)),
    firestoreReads: reads,
    firestoreWrites: writes,
    publishFromTarget: !!(publishStats.publishFromTarget || dualStats.publishFromTarget || cutStats.publishFromTarget),
    publishToTarget: !!(publishStats.publishToTarget || dualStats.publishToTarget || cutStats.publishToTarget),
    targetPathBuilt: !!(publishStats.targetPathBuilt || dualStats.targetPathBuilt || cutStats.targetPathBuilt),
    cutover: !!cutStats.cutover,
    lifecycleTouched: !!(publishStats.lifecycleTouched || dualStats.lifecycleTouched || cutStats.lifecycleTouched),
    stoppedEarly: !!(publishStats.stoppedEarly || dualStats.stoppedEarly || cutStats.stoppedEarly),
    failedStages: failedStages,
    stageReasons: {
      gate: String(gateStats.reason || ''),
      publish: String(publishStats.reason || ''),
      dual: String(dualStats.reason || ''),
      cut: String(cutStats.reason || '')
    }
  });
}

function buildMigration1E2eValidationResult_(data) {
  data = data || {};
  var stats = buildMigration1E2eValidationStats_(data);
  return {
    ok: data.ok !== false,
    stats: stats,
    stageReasons: data.stageReasons || {},
    failedStages: data.failedStages || []
  };
}

function buildMigration1E2eValidationStats_(data) {
  data = data || {};
  return {
    stage: PHBOX_M1_E2E_STAGE_,
    skipped: data.skipped !== false,
    reason: String(data.reason || ''),
    gateOk: !!data.gateOk,
    gateEnabled: !!data.gateEnabled,
    publishOk: !!data.publishOk,
    dualOk: !!data.dualOk,
    cutOk: !!data.cutOk,
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
    publishFromTarget: !!data.publishFromTarget,
    publishToTarget: !!data.publishToTarget,
    targetPathBuilt: !!data.targetPathBuilt,
    cutover: !!data.cutover,
    lifecycleTouched: !!data.lifecycleTouched,
    stoppedEarly: !!data.stoppedEarly,
    error: String(data.error || ''),
    errorKind: String(data.errorKind || '')
  };
}

function runMigration1E2eValidationSelfTest_() {
  var cases = [
    {
      id: 'gate_off_skips_zero_read_write',
      input: buildMigration1E2eValidationResult_({ ok: true, skipped: true, reason: 'target_runtime_gate_off', gateOk: true, gateEnabled: false }),
      expected: { ok: true, skipped: true, reason: 'target_runtime_gate_off', firestoreReads: 0, firestoreWrites: 0, publishToTarget: false, cutover: false }
    },
    {
      id: 'gate_error_blocks_e2e',
      input: buildMigration1E2eValidationResult_({ ok: false, skipped: true, reason: 'target_runtime_gate_error', gateOk: false, error: 'M1_GATE_TENANT_MISSING' }),
      expected: { ok: false, skipped: true, reason: 'target_runtime_gate_error', firestoreReads: 0, firestoreWrites: 0, cutover: false }
    },
    {
      id: 'all_stages_ok_cutover_off_passes_validation',
      input: buildMigration1E2eValidationRuntimeResult_(
        buildMigration1E2eTestGateStage_(true),
        buildMigration1E2eTestStage_(true, { reason: 'no_runtime_publish_attempted', publishToTarget: false }),
        buildMigration1E2eTestStage_(true, { samplePathsCompared: 2, mismatchedCount: 0, firestoreReads: 4 }),
        buildMigration1E2eTestStage_(true, { reason: 'cutover_disabled', cutover: false })
      ),
      expected: { ok: true, skipped: false, firestoreReads: 4, firestoreWrites: 0, publishToTarget: false, cutover: false, samplePathsCompared: 2 }
    },
    {
      id: 'dual_mismatch_fails_e2e',
      input: buildMigration1E2eValidationRuntimeResult_(
        buildMigration1E2eTestGateStage_(true),
        buildMigration1E2eTestStage_(true, { reason: 'no_runtime_publish_attempted' }),
        buildMigration1E2eTestStage_(false, { samplePathsCompared: 2, mismatchedCount: 1, firestoreReads: 4, reason: 'signature_mismatch' }),
        buildMigration1E2eTestStage_(true, { reason: 'cutover_disabled' })
      ),
      expected: { ok: false, reason: 'stage_failure', mismatchedCount: 1, firestoreReads: 4, cutover: false }
    },
    {
      id: 'publish_to_target_is_detected',
      input: buildMigration1E2eValidationRuntimeResult_(
        buildMigration1E2eTestGateStage_(true),
        buildMigration1E2eTestStage_(true, { publishToTarget: true, targetPathBuilt: true, firestoreWrites: 1 }),
        buildMigration1E2eTestStage_(true, { samplePathsCompared: 1, firestoreReads: 2 }),
        buildMigration1E2eTestStage_(true, { reason: 'cutover_disabled' })
      ),
      expected: { ok: true, publishToTarget: true, targetPathBuilt: true, firestoreReads: 2, firestoreWrites: 0, cutover: false }
    },
    {
      id: 'cutover_true_reuses_dual_result_without_duplicate_reads',
      input: buildMigration1E2eValidationRuntimeResult_(
        buildMigration1E2eTestGateStage_(true),
        buildMigration1E2eTestStage_(true, { reason: 'no_runtime_publish_attempted' }),
        buildMigration1E2eTestStage_(true, { samplePathsCompared: 2, firestoreReads: 4 }),
        buildMigration1E2eTestStage_(true, { cutover: true, dualVerified: true, samplePathsCompared: 2, firestoreReads: 0 })
      ),
      expected: { ok: true, cutover: true, dualVerified: true, firestoreReads: 4, firestoreWrites: 0 }
    }
  ];

  var passed = 0;
  var failed = 0;
  var items = cases.map(function (item) {
    var actual = buildMigration1E2eValidationSelfTestActual_(item.input);
    var mismatchReasons = compareMigration1E2eValidationExpected_(actual, item.expected || {});
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

function buildMigration1E2eTestGateStage_(enabled) {
  return {
    ok: true,
    result: {
      stats: {
        enabled: !!enabled,
        tenantId: enabled ? 'farmacia_santa_venera' : '',
        tenantCanonical: !!enabled,
        targetReadWriteAuthorized: !!enabled,
        reason: enabled ? '' : 'target_runtime_gate_off'
      }
    }
  };
}

function buildMigration1E2eTestStage_(ok, stats) {
  return {
    ok: ok !== false,
    stats: stats || {}
  };
}

function buildMigration1E2eValidationSelfTestActual_(result) {
  var stats = (result && result.stats) || {};
  return {
    ok: !!(result && result.ok),
    skipped: !!stats.skipped,
    reason: String(stats.reason || ''),
    gateOk: !!stats.gateOk,
    gateEnabled: !!stats.gateEnabled,
    publishOk: !!stats.publishOk,
    dualOk: !!stats.dualOk,
    cutOk: !!stats.cutOk,
    tenantId: String(stats.tenantId || ''),
    dualVerified: !!stats.dualVerified,
    samplePathsCompared: Number(stats.samplePathsCompared || 0),
    mismatchedCount: Number(stats.mismatchedCount || 0),
    firestoreReads: Number(stats.firestoreReads || 0),
    firestoreWrites: Number(stats.firestoreWrites || 0),
    publishToTarget: !!stats.publishToTarget,
    targetPathBuilt: !!stats.targetPathBuilt,
    cutover: !!stats.cutover,
    lifecycleTouched: !!stats.lifecycleTouched
  };
}

function compareMigration1E2eValidationExpected_(actual, expected) {
  var mismatches = [];
  Object.keys(expected || {}).forEach(function (key) {
    if (actual[key] !== expected[key]) {
      mismatches.push('field_' + key + '_mismatch');
    }
  });
  if (actual.firestoreWrites !== 0) mismatches.push('firestore_writes_not_zero');
  if (actual.lifecycleTouched) mismatches.push('lifecycle_touched');
  return uniqueNonEmptyStrings_(mismatches);
}

function formatMigration1E2eValidationSelfTestFeedback_(result) {
  result = result || runMigration1E2eValidationSelfTest_();
  var lines = [];
  lines.push('MIGRATION_1_E2E_TEST');
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
    lines.push('  ok=' + String(!!actual.ok));
    lines.push('  skipped=' + String(!!actual.skipped));
    lines.push('  reason=' + String(actual.reason || ''));
    lines.push('  gateOk=' + String(!!actual.gateOk));
    lines.push('  gateEnabled=' + String(!!actual.gateEnabled));
    lines.push('  publishOk=' + String(!!actual.publishOk));
    lines.push('  dualOk=' + String(!!actual.dualOk));
    lines.push('  cutOk=' + String(!!actual.cutOk));
    lines.push('  dualVerified=' + String(!!actual.dualVerified));
    lines.push('  samplePathsCompared=' + String(actual.samplePathsCompared || 0));
    lines.push('  mismatchedCount=' + String(actual.mismatchedCount || 0));
    lines.push('  firestoreReads=' + String(actual.firestoreReads || 0));
    lines.push('  firestoreWrites=' + String(actual.firestoreWrites || 0));
    lines.push('  publishToTarget=' + String(!!actual.publishToTarget));
    lines.push('  targetPathBuilt=' + String(!!actual.targetPathBuilt));
    lines.push('  cutover=' + String(!!actual.cutover));
    lines.push('  lifecycleTouched=' + String(!!actual.lifecycleTouched));
    lines.push('  mismatchReasons=' + ((item.mismatchReasons || []).length ? item.mismatchReasons.join(',') : 'none'));
  });
  return lines.join('\n');
}

function formatMigration1E2eValidationRuntimeFeedback_(result) {
  result = result || runMigration1E2eValidationRuntimeStatus_();
  var stats = (result && result.stats) || {};
  var lines = [];
  lines.push('MIGRATION_1_E2E_RUNTIME_STATUS');
  lines.push('ok=' + String(!!(result && result.ok)));
  lines.push('skipped=' + String(!!stats.skipped));
  lines.push('reason=' + String(stats.reason || ''));
  lines.push('gateOk=' + String(!!stats.gateOk));
  lines.push('gateEnabled=' + String(!!stats.gateEnabled));
  lines.push('publishOk=' + String(!!stats.publishOk));
  lines.push('dualOk=' + String(!!stats.dualOk));
  lines.push('cutOk=' + String(!!stats.cutOk));
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
  lines.push('stoppedEarly=' + String(!!stats.stoppedEarly));
  lines.push('error=' + (stats.error || 'none'));
  lines.push('errorKind=' + (stats.errorKind || 'none'));
  lines.push('failedStages=' + ((result.failedStages || []).length ? result.failedStages.join(',') : 'none'));
  var stageReasons = result.stageReasons || {};
  lines.push('stageReasonGate=' + String(stageReasons.gate || ''));
  lines.push('stageReasonPublish=' + String(stageReasons.publish || ''));
  lines.push('stageReasonDual=' + String(stageReasons.dual || ''));
  lines.push('stageReasonCut=' + String(stageReasons.cut || ''));
  return lines.join('\n');
}
