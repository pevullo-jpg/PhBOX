var PHBOX_M1_COST_STAGE_ = 'migration1_cost_audit';
var PHBOX_M1_COST_MAX_READS_PROPERTY_ = 'PHBOX_M1_COST_MAX_READS';
var PHBOX_M1_COST_MAX_WRITES_PROPERTY_ = 'PHBOX_M1_COST_MAX_WRITES';
var PHBOX_M1_COST_DEFAULT_MAX_READS_ = 20;
var PHBOX_M1_COST_DEFAULT_MAX_WRITES_ = 0;

function runMigration1CostAuditRuntimeStatus_() {
  try {
    var gateStage = runMigration1TargetRuntimeGateStage_({});
    var gateStats = gateStage && gateStage.result && gateStage.result.stats ? gateStage.result.stats : {};
    if (!gateStage || !gateStage.ok) {
      return buildMigration1CostAuditResult_({ ok: false, skipped: true, reason: 'target_runtime_gate_error', gateOk: false, gateEnabled: false, error: String((gateStage && gateStage.error) || 'unknown'), errorKind: String((gateStage && gateStage.errorKind) || 'unknown') });
    }
    if (!gateStats.enabled) {
      return buildMigration1CostAuditResult_({ ok: true, skipped: true, reason: 'target_runtime_gate_off', gateOk: true, gateEnabled: false });
    }
    var e2eStatus = runMigration1E2eValidationRuntimeStatus_();
    return buildMigration1CostAuditRuntimeResult_(gateStage, e2eStatus, readMigration1CostAuditBudgets_());
  } catch (e) {
    return buildMigration1CostAuditResult_({ ok: false, skipped: true, reason: 'cost_audit_runtime_error', error: normalizeRuntimeErrorMessage_(e), errorKind: classifyRuntimeFailureKind_(e) });
  }
}

function readMigration1CostAuditBudgets_() {
  var props = PropertiesService.getScriptProperties();
  return {
    maxReads: readMigration1CostAuditBudgetValue_(props, PHBOX_M1_COST_MAX_READS_PROPERTY_, PHBOX_M1_COST_DEFAULT_MAX_READS_),
    maxWrites: readMigration1CostAuditBudgetValue_(props, PHBOX_M1_COST_MAX_WRITES_PROPERTY_, PHBOX_M1_COST_DEFAULT_MAX_WRITES_)
  };
}

function readMigration1CostAuditBudgetValue_(props, propertyName, defaultValue) {
  var raw = props ? props.getProperty(propertyName) : null;
  if (raw === null || raw === undefined || String(raw).trim() === '') return Math.max(0, Number(defaultValue || 0));
  var parsed = Number(String(raw).trim());
  return isNaN(parsed) ? Math.max(0, Number(defaultValue || 0)) : Math.max(0, parsed);
}

function resolveMigration1CostAuditBudget_(budgets, key, defaultValue) {
  if (budgets && Object.prototype.hasOwnProperty.call(budgets, key)) {
    var parsed = Number(budgets[key]);
    return isNaN(parsed) ? Math.max(0, Number(defaultValue || 0)) : Math.max(0, parsed);
  }
  return Math.max(0, Number(defaultValue || 0));
}

function buildMigration1CostAuditRuntimeResult_(gateStage, e2eStatus, budgets) {
  var gateStats = (gateStage && gateStage.result && gateStage.result.stats) || {};
  var e2eStats = (e2eStatus && e2eStatus.stats) || {};
  var reads = Math.max(0, Number(e2eStats.firestoreReads || 0));
  var writes = Math.max(0, Number(e2eStats.firestoreWrites || 0));
  var maxReads = resolveMigration1CostAuditBudget_(budgets, 'maxReads', PHBOX_M1_COST_DEFAULT_MAX_READS_);
  var maxWrites = resolveMigration1CostAuditBudget_(budgets, 'maxWrites', PHBOX_M1_COST_DEFAULT_MAX_WRITES_);
  var violations = buildMigration1CostAuditViolations_({ reads: reads, writes: writes, maxReads: maxReads, maxWrites: maxWrites, e2eOk: !!(e2eStatus && e2eStatus.ok), publishToTarget: !!e2eStats.publishToTarget, publishFromTarget: !!e2eStats.publishFromTarget, targetPathBuilt: !!e2eStats.targetPathBuilt, cutover: !!e2eStats.cutover, lifecycleTouched: !!e2eStats.lifecycleTouched });
  return buildMigration1CostAuditResult_({ ok: violations.length === 0, skipped: false, reason: violations.length ? 'cost_audit_violation' : '', gateOk: !!(gateStage && gateStage.ok), gateEnabled: !!gateStats.enabled, e2eOk: !!(e2eStatus && e2eStatus.ok), tenantId: gateStats.tenantId || e2eStats.tenantId || '', tenantCanonical: !!(gateStats.tenantCanonical || e2eStats.tenantCanonical), targetReadWriteAuthorized: !!(gateStats.targetReadWriteAuthorized || e2eStats.targetReadWriteAuthorized), samplePathsCompared: Math.max(0, Number(e2eStats.samplePathsCompared || 0)), mismatchedCount: Math.max(0, Number(e2eStats.mismatchedCount || 0)), missingLegacyCount: Math.max(0, Number(e2eStats.missingLegacyCount || 0)), missingTargetCount: Math.max(0, Number(e2eStats.missingTargetCount || 0)), firestoreReads: reads, firestoreWrites: writes, maxReads: maxReads, maxWrites: maxWrites, publishFromTarget: !!e2eStats.publishFromTarget, publishToTarget: !!e2eStats.publishToTarget, targetPathBuilt: !!e2eStats.targetPathBuilt, cutover: !!e2eStats.cutover, lifecycleTouched: !!e2eStats.lifecycleTouched, stoppedEarly: !!e2eStats.stoppedEarly, violations: violations });
}

function buildMigration1CostAuditViolations_(data) {
  data = data || {};
  var violations = [];
  if (!data.e2eOk) violations.push('e2e_not_ok');
  if (Number(data.reads || 0) > Number(data.maxReads || 0)) violations.push('firestore_reads_over_budget');
  if (Number(data.writes || 0) > Number(data.maxWrites || 0)) violations.push('firestore_writes_over_budget');
  if (data.publishFromTarget) violations.push('publish_from_target_detected');
  if (data.publishToTarget) violations.push('publish_to_target_detected');
  if (data.cutover) violations.push('cutover_detected');
  if (data.lifecycleTouched) violations.push('lifecycle_touched');
  return uniqueNonEmptyStrings_(violations);
}

function buildMigration1CostAuditResult_(data) {
  data = data || {};
  return { ok: data.ok !== false, stats: buildMigration1CostAuditStats_(data), violations: uniqueNonEmptyStrings_(data.violations || []) };
}

function buildMigration1CostAuditStats_(data) {
  data = data || {};
  return { stage: PHBOX_M1_COST_STAGE_, skipped: data.skipped !== false, reason: String(data.reason || ''), gateOk: !!data.gateOk, gateEnabled: !!data.gateEnabled, e2eOk: !!data.e2eOk, tenantId: String(data.tenantId || ''), tenantCanonical: !!data.tenantCanonical, targetReadWriteAuthorized: !!data.targetReadWriteAuthorized, samplePathsCompared: Math.max(0, Number(data.samplePathsCompared || 0)), mismatchedCount: Math.max(0, Number(data.mismatchedCount || 0)), missingLegacyCount: Math.max(0, Number(data.missingLegacyCount || 0)), missingTargetCount: Math.max(0, Number(data.missingTargetCount || 0)), firestoreReads: Math.max(0, Number(data.firestoreReads || 0)), firestoreWrites: Math.max(0, Number(data.firestoreWrites || 0)), maxReads: resolveMigration1CostAuditBudget_(data, 'maxReads', PHBOX_M1_COST_DEFAULT_MAX_READS_), maxWrites: resolveMigration1CostAuditBudget_(data, 'maxWrites', PHBOX_M1_COST_DEFAULT_MAX_WRITES_), publishFromTarget: !!data.publishFromTarget, publishToTarget: !!data.publishToTarget, targetPathBuilt: !!data.targetPathBuilt, cutover: !!data.cutover, lifecycleTouched: !!data.lifecycleTouched, stoppedEarly: !!data.stoppedEarly, error: String(data.error || ''), errorKind: String(data.errorKind || '') };
}

function runMigration1CostAuditSelfTest_() {
  var cases = [
    { id: 'gate_off_cost_audit_zero_read_write', input: buildMigration1CostAuditResult_({ ok: true, skipped: true, reason: 'target_runtime_gate_off', gateOk: true, gateEnabled: false }), expected: { ok: true, skipped: true, reason: 'target_runtime_gate_off', firestoreReads: 0, firestoreWrites: 0 } },
    { id: 'e2e_within_budget_passes', input: buildMigration1CostAuditRuntimeResult_(buildMigration1CostAuditTestGateStage_(true), buildMigration1CostAuditTestE2eStatus_(true, { firestoreReads: 4, firestoreWrites: 0, samplePathsCompared: 2 }), { maxReads: 20, maxWrites: 0 }), expected: { ok: true, skipped: false, firestoreReads: 4, firestoreWrites: 0, reason: '' } },
    { id: 'zero_read_budget_override_is_enforced', input: buildMigration1CostAuditRuntimeResult_(buildMigration1CostAuditTestGateStage_(true), buildMigration1CostAuditTestE2eStatus_(true, { firestoreReads: 1, firestoreWrites: 0, samplePathsCompared: 1 }), { maxReads: 0, maxWrites: 0 }), expected: { ok: false, reason: 'cost_audit_violation', maxReads: 0, violation: 'firestore_reads_over_budget' } },
    { id: 'read_budget_exceeded_fails', input: buildMigration1CostAuditRuntimeResult_(buildMigration1CostAuditTestGateStage_(true), buildMigration1CostAuditTestE2eStatus_(true, { firestoreReads: 24, firestoreWrites: 0, samplePathsCompared: 12 }), { maxReads: 20, maxWrites: 0 }), expected: { ok: false, reason: 'cost_audit_violation', violation: 'firestore_reads_over_budget' } },
    { id: 'write_budget_exceeded_fails', input: buildMigration1CostAuditRuntimeResult_(buildMigration1CostAuditTestGateStage_(true), buildMigration1CostAuditTestE2eStatus_(true, { firestoreReads: 4, firestoreWrites: 1 }), { maxReads: 20, maxWrites: 0 }), expected: { ok: false, reason: 'cost_audit_violation', violation: 'firestore_writes_over_budget' } },
    { id: 'publish_to_target_detected_fails', input: buildMigration1CostAuditRuntimeResult_(buildMigration1CostAuditTestGateStage_(true), buildMigration1CostAuditTestE2eStatus_(true, { firestoreReads: 2, publishToTarget: true, targetPathBuilt: true }), { maxReads: 20, maxWrites: 0 }), expected: { ok: false, reason: 'cost_audit_violation', violation: 'publish_to_target_detected' } },
    { id: 'cutover_detected_fails', input: buildMigration1CostAuditRuntimeResult_(buildMigration1CostAuditTestGateStage_(true), buildMigration1CostAuditTestE2eStatus_(true, { firestoreReads: 4, cutover: true }), { maxReads: 20, maxWrites: 0 }), expected: { ok: false, reason: 'cost_audit_violation', violation: 'cutover_detected' } },
    { id: 'e2e_not_ok_fails', input: buildMigration1CostAuditRuntimeResult_(buildMigration1CostAuditTestGateStage_(true), buildMigration1CostAuditTestE2eStatus_(false, { firestoreReads: 4, mismatchedCount: 1 }), { maxReads: 20, maxWrites: 0 }), expected: { ok: false, reason: 'cost_audit_violation', violation: 'e2e_not_ok' } }
  ];
  var passed = 0;
  var failed = 0;
  var items = cases.map(function (item) {
    var actual = buildMigration1CostAuditSelfTestActual_(item.input);
    var mismatchReasons = compareMigration1CostAuditExpected_(item.input, actual, item.expected || {});
    var ok = mismatchReasons.length === 0;
    if (ok) passed++; else failed++;
    return { id: item.id, passed: ok, actual: actual, expected: item.expected || {}, mismatchReasons: mismatchReasons };
  });
  return { ok: failed === 0, testCount: items.length, passedCount: passed, failedCount: failed, firestoreReads: 0, firestoreWrites: 0, publishFromTarget: false, publishToTarget: false, targetPathBuilt: false, cutover: false, lifecycleTouched: false, items: items };
}

function buildMigration1CostAuditTestGateStage_(enabled) {
  return { ok: true, result: { stats: { enabled: !!enabled, tenantId: enabled ? 'farmacia_santa_venera' : '', tenantCanonical: !!enabled, targetReadWriteAuthorized: !!enabled, reason: enabled ? '' : 'target_runtime_gate_off' } } };
}

function buildMigration1CostAuditTestE2eStatus_(ok, stats) { return { ok: ok !== false, stats: stats || {} }; }

function buildMigration1CostAuditSelfTestActual_(result) {
  var stats = (result && result.stats) || {};
  return { ok: !!(result && result.ok), skipped: !!stats.skipped, reason: String(stats.reason || ''), gateOk: !!stats.gateOk, gateEnabled: !!stats.gateEnabled, e2eOk: !!stats.e2eOk, samplePathsCompared: Number(stats.samplePathsCompared || 0), mismatchedCount: Number(stats.mismatchedCount || 0), firestoreReads: Number(stats.firestoreReads || 0), firestoreWrites: Number(stats.firestoreWrites || 0), maxReads: Number(stats.maxReads || 0), maxWrites: Number(stats.maxWrites || 0), publishToTarget: !!stats.publishToTarget, targetPathBuilt: !!stats.targetPathBuilt, cutover: !!stats.cutover, lifecycleTouched: !!stats.lifecycleTouched, violations: uniqueNonEmptyStrings_((result && result.violations) || []) };
}

function compareMigration1CostAuditExpected_(result, actual, expected) {
  var mismatches = [];
  Object.keys(expected || {}).forEach(function (key) {
    if (key === 'violation') {
      if (actual.violations.indexOf(expected[key]) === -1) mismatches.push('missing_violation_' + expected[key]);
    } else if (actual[key] !== expected[key]) {
      mismatches.push('field_' + key + '_mismatch');
    }
  });
  if (actual.lifecycleTouched) mismatches.push('lifecycle_touched');
  if (result && result.stats && result.stats.stage !== PHBOX_M1_COST_STAGE_) mismatches.push('stage_mismatch');
  return uniqueNonEmptyStrings_(mismatches);
}

function formatMigration1CostAuditSelfTestFeedback_(result) {
  result = result || runMigration1CostAuditSelfTest_();
  var lines = [];
  lines.push('MIGRATION_1_COST_TEST');
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
    lines.push('- id=' + String(item.id || ''));
    lines.push('  passed=' + String(!!item.passed));
    lines.push('  reason=' + String(actual.reason || ''));
    lines.push('  firestoreReads=' + String(actual.firestoreReads || 0));
    lines.push('  firestoreWrites=' + String(actual.firestoreWrites || 0));
    lines.push('  maxReads=' + String(actual.maxReads || 0));
    lines.push('  maxWrites=' + String(actual.maxWrites || 0));
    lines.push('  publishToTarget=' + String(!!actual.publishToTarget));
    lines.push('  targetPathBuilt=' + String(!!actual.targetPathBuilt));
    lines.push('  cutover=' + String(!!actual.cutover));
    lines.push('  lifecycleTouched=' + String(!!actual.lifecycleTouched));
    lines.push('  violations=' + (actual.violations && actual.violations.length ? actual.violations.join(',') : 'none'));
    lines.push('  mismatchReasons=' + (item.mismatchReasons && item.mismatchReasons.length ? item.mismatchReasons.join(',') : 'none'));
  });
  return lines.join('\n');
}

function formatMigration1CostAuditRuntimeFeedback_(result) {
  result = result || runMigration1CostAuditRuntimeStatus_();
  var stats = (result && result.stats) || {};
  var violations = uniqueNonEmptyStrings_((result && result.violations) || []);
  var lines = [];
  lines.push('MIGRATION_1_COST_RUNTIME_STATUS');
  lines.push('ok=' + String(!!(result && result.ok)));
  lines.push('skipped=' + String(!!stats.skipped));
  lines.push('reason=' + String(stats.reason || ''));
  lines.push('gateOk=' + String(!!stats.gateOk));
  lines.push('gateEnabled=' + String(!!stats.gateEnabled));
  lines.push('e2eOk=' + String(!!stats.e2eOk));
  lines.push('tenantId=' + String(stats.tenantId || ''));
  lines.push('tenantCanonical=' + String(!!stats.tenantCanonical));
  lines.push('targetReadWriteAuthorized=' + String(!!stats.targetReadWriteAuthorized));
  lines.push('samplePathsCompared=' + String(stats.samplePathsCompared || 0));
  lines.push('mismatchedCount=' + String(stats.mismatchedCount || 0));
  lines.push('missingLegacyCount=' + String(stats.missingLegacyCount || 0));
  lines.push('missingTargetCount=' + String(stats.missingTargetCount || 0));
  lines.push('firestoreReads=' + String(stats.firestoreReads || 0));
  lines.push('firestoreWrites=' + String(stats.firestoreWrites || 0));
  lines.push('maxReads=' + String(stats.maxReads || 0));
  lines.push('maxWrites=' + String(stats.maxWrites || 0));
  lines.push('publishFromTarget=' + String(!!stats.publishFromTarget));
  lines.push('publishToTarget=' + String(!!stats.publishToTarget));
  lines.push('targetPathBuilt=' + String(!!stats.targetPathBuilt));
  lines.push('cutover=' + String(!!stats.cutover));
  lines.push('lifecycleTouched=' + String(!!stats.lifecycleTouched));
  lines.push('stoppedEarly=' + String(!!stats.stoppedEarly));
  lines.push('violations=' + (violations.length ? violations.join(',') : 'none'));
  lines.push('error=' + (stats.error || 'none'));
  lines.push('errorKind=' + (stats.errorKind || 'none'));
  return lines.join('\n');
}
