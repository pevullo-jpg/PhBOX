var PHBOX_M1_TARGET_RUNTIME_ENABLED_PROPERTY_ = 'PHBOX_M1_TARGET_RUNTIME_ENABLED';
var PHBOX_M1_TARGET_RUNTIME_TENANT_ID_PROPERTY_ = 'PHBOX_TENANT_ID';
var PHBOX_M1_TARGET_RUNTIME_EXPECTED_TENANT_ID_PROPERTY_ = 'PHBOX_EXPECTED_CANONICAL_TENANT_ID';
var PHBOX_M1_TARGET_RUNTIME_STAGE_ = 'migration1_target_runtime_gate';


function runMigration1TargetRuntimeGateStage_(options) {
  try {
    return {
      ok: true,
      result: runMigration1TargetRuntimeGate_(options || {})
    };
  } catch (e) {
    return {
      ok: false,
      error: normalizeRuntimeErrorMessage_(e),
      errorKind: classifyRuntimeFailureKind_(e),
      stage: PHBOX_M1_TARGET_RUNTIME_STAGE_,
      targetRuntimeGate: true,
      firestoreReads: 0,
      firestoreWrites: 0,
      publishFromTarget: false,
      targetPathBuilt: false,
      cutover: false
    };
  }
}

function runMigration1TargetRuntimeGate_(options) {
  options = options || {};
  var props = options.props || PropertiesService.getScriptProperties();

  if (!isMigration1TargetRuntimeGateEnabled_(props)) {
    return buildMigration1TargetRuntimeGateDisabledResult_();
  }

  var tenant = validateMigration1TargetRuntimeCanonicalTenantId_(props);
  return buildMigration1TargetRuntimeGateEnabledResult_(tenant);
}

function buildMigration1TargetRuntimeGateDisabledResult_() {
  return {
    stats: {
      stage: PHBOX_M1_TARGET_RUNTIME_STAGE_,
      enabled: false,
      skipped: true,
      reason: 'target_runtime_gate_off',
      tenantId: '',
      tenantCanonical: false,
      targetReadWriteAuthorized: false,
      targetPathBuilt: false,
      targetPathTemplate: 'tenants/{tenantId}/...',
      firestoreReads: 0,
      firestoreWrites: 0,
      publishFromTarget: false,
      cutover: false,
      lifecycleTouched: false,
      stoppedEarly: false
    },
    targetRuntime: {
      enabled: false,
      tenantId: '',
      tenantCanonical: false,
      targetReadWriteAuthorized: false,
      targetPathBuilt: false
    }
  };
}

function buildMigration1TargetRuntimeGateEnabledResult_(tenant) {
  var tenantId = String(tenant && tenant.tenantId || '').trim();
  return {
    stats: {
      stage: PHBOX_M1_TARGET_RUNTIME_STAGE_,
      enabled: true,
      skipped: false,
      reason: '',
      tenantId: tenantId,
      tenantCanonical: true,
      targetReadWriteAuthorized: true,
      targetPathBuilt: false,
      targetPathTemplate: 'tenants/{tenantId}/...',
      firestoreReads: 0,
      firestoreWrites: 0,
      publishFromTarget: false,
      cutover: false,
      lifecycleTouched: false,
      stoppedEarly: false
    },
    targetRuntime: {
      enabled: true,
      tenantId: tenantId,
      tenantCanonical: true,
      targetReadWriteAuthorized: true,
      targetPathBuilt: false
    }
  };
}

function buildMigration1TargetRuntimeGateErrorFallback_() {
  return {
    stage: PHBOX_M1_TARGET_RUNTIME_STAGE_,
    enabled: false,
    skipped: true,
    reason: 'target_runtime_gate_error',
    tenantId: '',
    tenantCanonical: false,
    targetReadWriteAuthorized: false,
    targetPathBuilt: false,
    targetPathTemplate: 'tenants/{tenantId}/...',
    firestoreReads: 0,
    firestoreWrites: 0,
    publishFromTarget: false,
    cutover: false,
    lifecycleTouched: false,
    stoppedEarly: true
  };
}

function isMigration1TargetRuntimeGateEnabled_(props) {
  props = props || PropertiesService.getScriptProperties();
  var raw = props.getProperty(PHBOX_M1_TARGET_RUNTIME_ENABLED_PROPERTY_);
  return /^true$/i.test(String(raw || '').trim());
}

function validateMigration1TargetRuntimeCanonicalTenantId_(props) {
  return validateMigration1CanonicalTenantIdFromProperties_(props, {
    tenantPropertyName: PHBOX_M1_TARGET_RUNTIME_TENANT_ID_PROPERTY_,
    expectedTenantPropertyName: PHBOX_M1_TARGET_RUNTIME_EXPECTED_TENANT_ID_PROPERTY_,
    errorPrefix: 'M1_GATE',
    blockedOperationLabel: 'Nessun target runtime path autorizzato.'
  });
}

function requireMigration1TargetRuntimeGateOpen_() {
  var result = runMigration1TargetRuntimeGate_({});
  var targetRuntime = result && result.targetRuntime;
  if (!targetRuntime || !targetRuntime.enabled || !targetRuntime.targetReadWriteAuthorized || !targetRuntime.tenantCanonical) {
    throw new Error('M1_GATE_TARGET_RUNTIME_CLOSED: target runtime non autorizzato. Nessun target path costruibile.');
  }
  return {
    enabled: true,
    tenantId: targetRuntime.tenantId,
    tenantCanonical: true,
    targetReadWriteAuthorized: true
  };
}

function normalizeMigration1CanonicalTenantSegment_(value, label, options) {
  options = options || {};
  var errorPrefix = String(options.errorPrefix || 'M1').trim() || 'M1';
  var blockedOperationLabel = String(options.blockedOperationLabel || 'Nessuna target operation eseguita.').trim();
  var raw = String(value || '');
  var normalized = raw.trim();
  if (!normalized) {
    throw new Error(errorPrefix + '_TENANT_MISSING: ' + label + ' mancante o vuoto. ' + blockedOperationLabel);
  }
  if (normalized !== raw) {
    throw new Error(errorPrefix + '_TENANT_NOT_CANONICAL: ' + label + ' contiene spazi iniziali/finali. ' + blockedOperationLabel);
  }
  if (normalized.indexOf('/') !== -1) {
    throw new Error(errorPrefix + '_TENANT_NOT_CANONICAL: ' + label + ' contiene slash. ' + blockedOperationLabel);
  }
  return normalized;
}

function validateMigration1CanonicalTenantIdFromProperties_(props, options) {
  options = options || {};
  props = props || PropertiesService.getScriptProperties();
  var tenantPropertyName = options.tenantPropertyName || 'PHBOX_TENANT_ID';
  var expectedTenantPropertyName = options.expectedTenantPropertyName || 'PHBOX_EXPECTED_CANONICAL_TENANT_ID';
  var errorPrefix = String(options.errorPrefix || 'M1').trim() || 'M1';
  var blockedOperationLabel = String(options.blockedOperationLabel || 'Nessuna target operation eseguita.').trim();
  var rawTenantId = String(props.getProperty(tenantPropertyName) || '');
  var rawExpectedTenantId = String(props.getProperty(expectedTenantPropertyName) || '');
  var tenantId = normalizeMigration1CanonicalTenantSegment_(rawTenantId, tenantPropertyName, {
    errorPrefix: errorPrefix,
    blockedOperationLabel: blockedOperationLabel
  });
  var expectedTenantId = normalizeMigration1CanonicalTenantSegment_(rawExpectedTenantId, expectedTenantPropertyName, {
    errorPrefix: errorPrefix,
    blockedOperationLabel: blockedOperationLabel
  });

  if (tenantId !== expectedTenantId) {
    throw new Error(errorPrefix + '_TENANT_NOT_CANONICAL: ' + tenantPropertyName + ' diverso da ' + expectedTenantPropertyName + '. ' + blockedOperationLabel);
  }

  return {
    tenantId: tenantId,
    expectedTenantId: expectedTenantId
  };
}

function runMigration1TargetRuntimeGateSelfTest_() {
  var cases = [
    {
      id: 'default_off_no_tenant_pass',
      props: {},
      expected: { ok: true, enabled: false, skipped: true, tenantId: '', targetReadWriteAuthorized: false, errorContains: '' }
    },
    {
      id: 'explicit_false_no_tenant_pass',
      props: { PHBOX_M1_TARGET_RUNTIME_ENABLED: 'false' },
      expected: { ok: true, enabled: false, skipped: true, tenantId: '', targetReadWriteAuthorized: false, errorContains: '' }
    },
    {
      id: 'on_canonical_tenant_pass',
      props: {
        PHBOX_M1_TARGET_RUNTIME_ENABLED: 'true',
        PHBOX_TENANT_ID: 'farmacia_santa_venera',
        PHBOX_EXPECTED_CANONICAL_TENANT_ID: 'farmacia_santa_venera'
      },
      expected: { ok: true, enabled: true, skipped: false, tenantId: 'farmacia_santa_venera', targetReadWriteAuthorized: true, errorContains: '' }
    },
    {
      id: 'on_missing_tenant_rejected',
      props: {
        PHBOX_M1_TARGET_RUNTIME_ENABLED: 'true',
        PHBOX_EXPECTED_CANONICAL_TENANT_ID: 'farmacia_santa_venera'
      },
      expected: { ok: false, enabled: false, skipped: true, tenantId: '', targetReadWriteAuthorized: false, errorContains: 'M1_GATE_TENANT_MISSING' }
    },
    {
      id: 'on_missing_expected_tenant_rejected',
      props: {
        PHBOX_M1_TARGET_RUNTIME_ENABLED: 'true',
        PHBOX_TENANT_ID: 'farmacia_santa_venera'
      },
      expected: { ok: false, enabled: false, skipped: true, tenantId: '', targetReadWriteAuthorized: false, errorContains: 'M1_GATE_TENANT_MISSING' }
    },
    {
      id: 'on_mismatch_tenant_rejected',
      props: {
        PHBOX_M1_TARGET_RUNTIME_ENABLED: 'true',
        PHBOX_TENANT_ID: 'farmacia_santa_venera',
        PHBOX_EXPECTED_CANONICAL_TENANT_ID: 'farmacia_diversa'
      },
      expected: { ok: false, enabled: false, skipped: true, tenantId: '', targetReadWriteAuthorized: false, errorContains: 'M1_GATE_TENANT_NOT_CANONICAL' }
    },
    {
      id: 'on_trimmed_tenant_rejected',
      props: {
        PHBOX_M1_TARGET_RUNTIME_ENABLED: 'true',
        PHBOX_TENANT_ID: ' farmacia_santa_venera',
        PHBOX_EXPECTED_CANONICAL_TENANT_ID: 'farmacia_santa_venera'
      },
      expected: { ok: false, enabled: false, skipped: true, tenantId: '', targetReadWriteAuthorized: false, errorContains: 'M1_GATE_TENANT_NOT_CANONICAL' }
    },
    {
      id: 'on_slash_tenant_rejected',
      props: {
        PHBOX_M1_TARGET_RUNTIME_ENABLED: 'true',
        PHBOX_TENANT_ID: 'farmacia/santa/venera',
        PHBOX_EXPECTED_CANONICAL_TENANT_ID: 'farmacia/santa/venera'
      },
      expected: { ok: false, enabled: false, skipped: true, tenantId: '', targetReadWriteAuthorized: false, errorContains: 'M1_GATE_TENANT_NOT_CANONICAL' }
    }
  ];

  var passed = 0;
  var failed = 0;
  var items = cases.map(function (item) {
    var stage = runMigration1TargetRuntimeGateStage_({ props: createMigration1TargetRuntimeGateTestProperties_(item.props) });
    var actualStats = stage && stage.ok ? ((stage.result && stage.result.stats) || {}) : buildMigration1TargetRuntimeGateErrorFallback_();
    var actual = {
      ok: !!(stage && stage.ok),
      enabled: !!actualStats.enabled,
      skipped: !!actualStats.skipped,
      tenantId: String(actualStats.tenantId || ''),
      targetReadWriteAuthorized: !!actualStats.targetReadWriteAuthorized,
      firestoreReads: Number(actualStats.firestoreReads || 0),
      firestoreWrites: Number(actualStats.firestoreWrites || 0),
      publishFromTarget: !!actualStats.publishFromTarget,
      targetPathBuilt: !!actualStats.targetPathBuilt,
      cutover: !!actualStats.cutover,
      error: stage && stage.ok ? '' : String((stage && stage.error) || '')
    };
    var mismatchReasons = compareMigration1TargetRuntimeGateExpected_(actual, item.expected);
    var ok = mismatchReasons.length === 0;
    if (ok) passed++; else failed++;
    return {
      id: item.id,
      passed: ok,
      mismatchReasons: mismatchReasons,
      expected: item.expected,
      actual: actual
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
    targetPathBuilt: false,
    cutover: false,
    items: items
  };
}

function createMigration1TargetRuntimeGateTestProperties_(values) {
  values = values || {};
  return {
    getProperty: function (name) {
      return Object.prototype.hasOwnProperty.call(values, name) ? values[name] : null;
    }
  };
}

function compareMigration1TargetRuntimeGateExpected_(actual, expected) {
  var mismatches = [];
  Object.keys(expected || {}).forEach(function (key) {
    if (key === 'errorContains') {
      var expectedError = String(expected[key] || '');
      if (expectedError && String(actual.error || '').indexOf(expectedError) === -1) {
        mismatches.push('missing_error_' + expectedError);
      }
      if (!expectedError && String(actual.error || '')) {
        mismatches.push('unexpected_error');
      }
      return;
    }
    if (actual[key] !== expected[key]) {
      mismatches.push('field_' + key + '_mismatch');
    }
  });
  if (actual.firestoreReads !== 0) mismatches.push('firestore_reads_not_zero');
  if (actual.firestoreWrites !== 0) mismatches.push('firestore_writes_not_zero');
  if (actual.publishFromTarget !== false) mismatches.push('publish_from_target_not_false');
  if (actual.targetPathBuilt !== false) mismatches.push('target_path_built_not_false');
  if (actual.cutover !== false) mismatches.push('cutover_not_false');
  return uniqueNonEmptyStrings_(mismatches);
}

function formatMigration1TargetRuntimeGateSelfTestFeedback_(result) {
  result = result || runMigration1TargetRuntimeGateSelfTest_();
  var lines = [];
  lines.push('MIGRATION_1_GATE_TEST');
  lines.push('ok=' + String(!!result.ok));
  lines.push('testCount=' + String(result.testCount || 0));
  lines.push('passedCount=' + String(result.passedCount || 0));
  lines.push('failedCount=' + String(result.failedCount || 0));
  lines.push('firestoreReads=' + String(result.firestoreReads || 0));
  lines.push('firestoreWrites=' + String(result.firestoreWrites || 0));
  lines.push('publishFromTarget=' + String(!!result.publishFromTarget));
  lines.push('targetPathBuilt=' + String(!!result.targetPathBuilt));
  lines.push('cutover=' + String(!!result.cutover));
  lines.push('items=');
  (result.items || []).forEach(function (item) {
    lines.push('- id=' + item.id);
    lines.push('  passed=' + String(!!item.passed));
    lines.push('  enabled=' + String(!!item.actual.enabled));
    lines.push('  skipped=' + String(!!item.actual.skipped));
    lines.push('  tenantId=' + String(item.actual.tenantId || ''));
    lines.push('  targetReadWriteAuthorized=' + String(!!item.actual.targetReadWriteAuthorized));
    lines.push('  firestoreReads=' + String(item.actual.firestoreReads || 0));
    lines.push('  firestoreWrites=' + String(item.actual.firestoreWrites || 0));
    lines.push('  publishFromTarget=' + String(!!item.actual.publishFromTarget));
    lines.push('  targetPathBuilt=' + String(!!item.actual.targetPathBuilt));
    lines.push('  cutover=' + String(!!item.actual.cutover));
    lines.push('  error=' + (item.actual.error || 'none'));
    lines.push('  mismatchReasons=' + ((item.mismatchReasons || []).length ? item.mismatchReasons.join(',') : 'none'));
  });
  return lines.join('\n');
}


function formatMigration1TargetRuntimeGateRuntimeFeedback_(stage) {
  stage = stage || runMigration1TargetRuntimeGateStage_({});
  var stats = stage && stage.ok ? ((stage.result && stage.result.stats) || {}) : buildMigration1TargetRuntimeGateErrorFallback_();
  var lines = [];
  lines.push('MIGRATION_1_GATE_RUNTIME_STATUS');
  lines.push('ok=' + String(!!(stage && stage.ok)));
  lines.push('enabled=' + String(!!stats.enabled));
  lines.push('skipped=' + String(!!stats.skipped));
  lines.push('reason=' + String(stats.reason || ''));
  lines.push('tenantId=' + String(stats.tenantId || ''));
  lines.push('tenantCanonical=' + String(!!stats.tenantCanonical));
  lines.push('targetReadWriteAuthorized=' + String(!!stats.targetReadWriteAuthorized));
  lines.push('firestoreReads=' + String(stats.firestoreReads || 0));
  lines.push('firestoreWrites=' + String(stats.firestoreWrites || 0));
  lines.push('publishFromTarget=' + String(!!stats.publishFromTarget));
  lines.push('targetPathBuilt=' + String(!!stats.targetPathBuilt));
  lines.push('cutover=' + String(!!stats.cutover));
  lines.push('lifecycleTouched=' + String(!!stats.lifecycleTouched));
  lines.push('error=' + (stage && stage.ok ? 'none' : String((stage && stage.error) || 'unknown')));
  lines.push('errorKind=' + (stage && stage.ok ? 'none' : String((stage && stage.errorKind) || 'unknown')));
  return lines.join('\n');
}
