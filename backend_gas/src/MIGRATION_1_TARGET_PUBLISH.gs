var PHBOX_M1_TARGET_PUBLISH_STAGE_ = 'migration1_target_publish';


function maybePublishMigration1TargetFirestorePlan_(cfg, plan, options) {
  options = options || {};
  cfg = cfg || getPhboxConfig_();
  plan = plan || {};

  if (!isMigration1TargetRuntimeGateEnabled_()) {
    return {
      stats: buildMigration1TargetPublishSkippedStats_('target_runtime_gate_off')
    };
  }

  if (shouldStopForBudget_(options.budget, 15000)) {
    throw new Error('M1_PUB_BUDGET_LOW: budget runtime insufficiente prima del publish target. Dirty legacy non marcato come sincronizzato.');
  }

  var targetRuntime = requireMigration1TargetRuntimeGateOpen_();
  var targetWrites = buildMigration1TargetFirestoreWrites_(cfg, plan.writes || [], targetRuntime);
  if (!targetWrites.length) {
    return {
      stats: buildMigration1TargetPublishSkippedStats_('no_legacy_writes_to_mirror', targetRuntime)
    };
  }

  executeFirestoreCommit_(cfg, targetWrites);

  return {
    stats: {
      stage: PHBOX_M1_TARGET_PUBLISH_STAGE_,
      enabled: true,
      skipped: false,
      reason: '',
      tenantId: targetRuntime.tenantId,
      tenantCanonical: true,
      targetReadWriteAuthorized: true,
      legacyWritesSeen: (plan.writes || []).length,
      targetWritesPlanned: targetWrites.length,
      firestoreReads: 0,
      firestoreWrites: targetWrites.length,
      publishFromTarget: false,
      publishToTarget: true,
      targetPathBuilt: targetWrites.length > 0,
      cutover: false,
      lifecycleTouched: false,
      stoppedEarly: false
    }
  };
}

function buildMigration1TargetPublishSkippedStats_(reason, targetRuntime) {
  targetRuntime = targetRuntime || {};
  return {
    stage: PHBOX_M1_TARGET_PUBLISH_STAGE_,
    enabled: !!targetRuntime.enabled,
    skipped: true,
    reason: String(reason || 'skipped'),
    tenantId: String(targetRuntime.tenantId || ''),
    tenantCanonical: !!targetRuntime.tenantCanonical,
    targetReadWriteAuthorized: !!targetRuntime.targetReadWriteAuthorized,
    legacyWritesSeen: 0,
    targetWritesPlanned: 0,
    firestoreReads: 0,
    firestoreWrites: 0,
    publishFromTarget: false,
    publishToTarget: false,
    targetPathBuilt: false,
    cutover: false,
    lifecycleTouched: false,
    stoppedEarly: false
  };
}

function buildMigration1TargetFirestoreWrites_(cfg, legacyWrites, targetRuntime) {
  cfg = cfg || getPhboxConfig_();
  legacyWrites = legacyWrites || [];
  if (!targetRuntime || !targetRuntime.enabled || !targetRuntime.targetReadWriteAuthorized || !targetRuntime.tenantCanonical) {
    throw new Error('M1_PUB_TARGET_RUNTIME_CLOSED: publish target non autorizzato. Nessun target path costruito.');
  }
  var tenantId = String(targetRuntime.tenantId || '');
  if (!tenantId) {
    throw new Error('M1_PUB_TENANT_MISSING: tenantId assente dopo apertura gate. Nessun target path costruito.');
  }

  return legacyWrites.map(function (write) {
    return buildMigration1TargetFirestoreWrite_(cfg, tenantId, write);
  });
}

function buildMigration1TargetFirestoreWrite_(cfg, tenantId, write) {
  write = write || {};
  if (write.update && write.update.name) {
    var updateWrite = JSON.parse(JSON.stringify(write));
    updateWrite.update.name = buildMigration1TargetFirestoreDocumentNameFromLegacyName_(cfg, tenantId, write.update.name);
    return updateWrite;
  }
  if (write.delete) {
    var deleteWrite = JSON.parse(JSON.stringify(write));
    deleteWrite.delete = buildMigration1TargetFirestoreDocumentNameFromLegacyName_(cfg, tenantId, write.delete);
    return deleteWrite;
  }
  throw new Error('M1_PUB_UNSUPPORTED_WRITE: write Firestore non supportata per target publish. Nessun target commit eseguito.');
}

function buildMigration1TargetFirestoreDocumentNameFromLegacyName_(cfg, tenantId, legacyName) {
  cfg = cfg || getPhboxConfig_();
  var canonicalTenantId = normalizeMigration1CanonicalTenantSegment_(tenantId, 'tenantId', {
    errorPrefix: 'M1_PUB',
    blockedOperationLabel: 'Nessun target path costruito.'
  });
  var prefix = 'projects/' + cfg.firestoreProjectId + '/databases/(default)/documents/';
  var name = String(legacyName || '').trim();
  if (name.indexOf(prefix) !== 0) {
    throw new Error('M1_PUB_LEGACY_NAME_INVALID: document name legacy fuori progetto/database atteso. Nessun target path costruito.');
  }
  var legacyPath = name.substring(prefix.length);
  if (!legacyPath) {
    throw new Error('M1_PUB_LEGACY_PATH_EMPTY: path documento legacy vuoto. Nessun target path costruito.');
  }
  if (legacyPath.indexOf('tenants/') === 0) {
    throw new Error('M1_PUB_DOUBLE_TARGET_PATH: write già target-prefixed. Nessun target path costruito.');
  }
  return prefix + 'tenants/' + canonicalTenantId + '/' + legacyPath;
}

function runMigration1TargetPublishRuntimeStatus_() {
  var stage = runMigration1TargetRuntimeGateStage_({});
  if (!stage || !stage.ok) {
    return {
      ok: false,
      stats: buildMigration1TargetPublishErrorStats_(stage && stage.error, stage && stage.errorKind)
    };
  }
  var gateStats = (stage.result && stage.result.stats) || {};
  if (!gateStats.enabled) {
    return {
      ok: true,
      stats: buildMigration1TargetPublishSkippedStats_('target_runtime_gate_off')
    };
  }
  return {
    ok: true,
    stats: buildMigration1TargetPublishSkippedStats_('no_runtime_publish_attempted', {
      enabled: true,
      tenantId: gateStats.tenantId || '',
      tenantCanonical: !!gateStats.tenantCanonical,
      targetReadWriteAuthorized: !!gateStats.targetReadWriteAuthorized
    })
  };
}

function buildMigration1TargetPublishErrorStats_(error, errorKind) {
  var out = buildMigration1TargetPublishSkippedStats_('target_runtime_gate_error');
  out.failed = true;
  out.error = String(error || 'unknown');
  out.errorKind = String(errorKind || 'unknown');
  return out;
}

function runMigration1TargetPublishSelfTest_() {
  var cfg = { firestoreProjectId: 'phbox-test-project' };
  var canonicalProps = {
    PHBOX_M1_TARGET_RUNTIME_ENABLED: 'true',
    PHBOX_TENANT_ID: 'farmacia_santa_venera',
    PHBOX_EXPECTED_CANONICAL_TENANT_ID: 'farmacia_santa_venera'
  };
  var cases = [
    {
      id: 'gate_off_skips_without_path',
      props: {},
      writes: [buildMigration1TargetPublishTestUpdate_(cfg, 'drive_pdf_imports', 'file_1')],
      expected: { ok: true, skipped: true, targetPathBuilt: false, targetWritesPlanned: 0, errorContains: '' }
    },
    {
      id: 'gate_on_update_path_built_after_canonical_tenant',
      props: canonicalProps,
      writes: [buildMigration1TargetPublishTestUpdate_(cfg, 'drive_pdf_imports', 'file_1')],
      expected: { ok: true, skipped: false, targetPathBuilt: true, targetWritesPlanned: 1, targetNameContains: '/documents/tenants/farmacia_santa_venera/drive_pdf_imports/file_1', errorContains: '' }
    },
    {
      id: 'gate_on_delete_path_built_after_canonical_tenant',
      props: canonicalProps,
      writes: [buildMigration1TargetPublishTestDelete_(cfg, 'patients', 'RSSMRA80A01H501U')],
      expected: { ok: true, skipped: false, targetPathBuilt: true, targetWritesPlanned: 1, targetNameContains: '/documents/tenants/farmacia_santa_venera/patients/RSSMRA80A01H501U', errorContains: '' }
    },
    {
      id: 'gate_on_missing_tenant_rejected_before_path',
      props: {
        PHBOX_M1_TARGET_RUNTIME_ENABLED: 'true',
        PHBOX_EXPECTED_CANONICAL_TENANT_ID: 'farmacia_santa_venera'
      },
      writes: [buildMigration1TargetPublishTestUpdate_(cfg, 'patients', 'RSSMRA80A01H501U')],
      expected: { ok: false, skipped: true, targetPathBuilt: false, targetWritesPlanned: 0, errorContains: 'M1_GATE_TENANT_MISSING' }
    },
    {
      id: 'gate_on_slash_tenant_rejected_before_path',
      props: {
        PHBOX_M1_TARGET_RUNTIME_ENABLED: 'true',
        PHBOX_TENANT_ID: 'farmacia/santa/venera',
        PHBOX_EXPECTED_CANONICAL_TENANT_ID: 'farmacia/santa/venera'
      },
      writes: [buildMigration1TargetPublishTestUpdate_(cfg, 'patients', 'RSSMRA80A01H501U')],
      expected: { ok: false, skipped: true, targetPathBuilt: false, targetWritesPlanned: 0, errorContains: 'M1_GATE_TENANT_NOT_CANONICAL' }
    },
    {
      id: 'already_target_prefixed_legacy_write_rejected',
      props: canonicalProps,
      writes: [{ update: { name: 'projects/phbox-test-project/databases/(default)/documents/tenants/farmacia_santa_venera/patients/RSSMRA80A01H501U', fields: {} } }],
      expected: { ok: false, skipped: true, targetPathBuilt: false, targetWritesPlanned: 0, errorContains: 'M1_PUB_DOUBLE_TARGET_PATH' }
    },
    {
      id: 'empty_legacy_writes_skip_without_path',
      props: canonicalProps,
      writes: [],
      expected: { ok: true, skipped: true, targetPathBuilt: false, targetWritesPlanned: 0, errorContains: '' }
    }
  ];

  var passed = 0;
  var failed = 0;
  var items = cases.map(function (item) {
    var actual = runMigration1TargetPublishSelfTestCase_(cfg, item.props, item.writes);
    var mismatchReasons = compareMigration1TargetPublishExpected_(actual, item.expected);
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
    cutover: false,
    lifecycleTouched: false,
    items: items
  };
}

function runMigration1TargetPublishSelfTestCase_(cfg, props, writes) {
  try {
    var stage = runMigration1TargetRuntimeGateStage_({ props: createMigration1TargetRuntimeGateTestProperties_(props || {}) });
    if (!stage || !stage.ok) {
      return {
        ok: false,
        skipped: true,
        targetPathBuilt: false,
        targetWritesPlanned: 0,
        firestoreReads: 0,
        firestoreWrites: 0,
        publishFromTarget: false,
        publishToTarget: false,
        cutover: false,
        lifecycleTouched: false,
        targetName: '',
        error: String((stage && stage.error) || 'unknown')
      };
    }
    var targetRuntime = (stage.result && stage.result.targetRuntime) || {};
    if (!targetRuntime.enabled) {
      return {
        ok: true,
        skipped: true,
        targetPathBuilt: false,
        targetWritesPlanned: 0,
        firestoreReads: 0,
        firestoreWrites: 0,
        publishFromTarget: false,
        publishToTarget: false,
        cutover: false,
        lifecycleTouched: false,
        targetName: '',
        error: ''
      };
    }
    var targetWrites = buildMigration1TargetFirestoreWrites_(cfg, writes || [], targetRuntime);
    var targetName = extractMigration1TargetPublishTestName_(targetWrites[0]);
    return {
      ok: true,
      skipped: targetWrites.length === 0,
      targetPathBuilt: targetWrites.length > 0,
      targetWritesPlanned: targetWrites.length,
      firestoreReads: 0,
      firestoreWrites: 0,
      publishFromTarget: false,
      publishToTarget: targetWrites.length > 0,
      cutover: false,
      lifecycleTouched: false,
      targetName: targetName,
      error: ''
    };
  } catch (e) {
    return {
      ok: false,
      skipped: true,
      targetPathBuilt: false,
      targetWritesPlanned: 0,
      firestoreReads: 0,
      firestoreWrites: 0,
      publishFromTarget: false,
      publishToTarget: false,
      cutover: false,
      lifecycleTouched: false,
      targetName: '',
      error: normalizeRuntimeErrorMessage_(e)
    };
  }
}

function buildMigration1TargetPublishTestUpdate_(cfg, collection, documentId) {
  return {
    update: {
      name: buildFirestoreDocumentName_(cfg, collection, documentId),
      fields: {
        id: { stringValue: documentId }
      }
    }
  };
}

function buildMigration1TargetPublishTestDelete_(cfg, collection, documentId) {
  return {
    delete: buildFirestoreDocumentName_(cfg, collection, documentId)
  };
}

function extractMigration1TargetPublishTestName_(write) {
  if (!write) return '';
  if (write.update && write.update.name) return String(write.update.name || '');
  if (write.delete) return String(write.delete || '');
  return '';
}

function compareMigration1TargetPublishExpected_(actual, expected) {
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
    if (key === 'targetNameContains') {
      var expectedNamePart = String(expected[key] || '');
      if (expectedNamePart && String(actual.targetName || '').indexOf(expectedNamePart) === -1) {
        mismatches.push('target_name_missing_expected_segment');
      }
      return;
    }
    if (actual[key] !== expected[key]) {
      mismatches.push('field_' + key + '_mismatch');
    }
  });
  if (actual.firestoreReads !== 0) mismatches.push('firestore_reads_not_zero');
  if (actual.firestoreWrites !== 0) mismatches.push('firestore_writes_not_zero_in_selftest');
  if (actual.publishFromTarget !== false) mismatches.push('publish_from_target_not_false');
  if (actual.cutover !== false) mismatches.push('cutover_not_false');
  if (actual.lifecycleTouched !== false) mismatches.push('lifecycle_touched_not_false');
  return uniqueNonEmptyStrings_(mismatches);
}

function formatMigration1TargetPublishSelfTestFeedback_(result) {
  result = result || runMigration1TargetPublishSelfTest_();
  var lines = [];
  lines.push('MIGRATION_1_PUB_TEST');
  lines.push('ok=' + String(!!result.ok));
  lines.push('testCount=' + String(result.testCount || 0));
  lines.push('passedCount=' + String(result.passedCount || 0));
  lines.push('failedCount=' + String(result.failedCount || 0));
  lines.push('firestoreReads=' + String(result.firestoreReads || 0));
  lines.push('firestoreWrites=' + String(result.firestoreWrites || 0));
  lines.push('publishFromTarget=' + String(!!result.publishFromTarget));
  lines.push('cutover=' + String(!!result.cutover));
  lines.push('lifecycleTouched=' + String(!!result.lifecycleTouched));
  lines.push('items=');
  (result.items || []).forEach(function (item) {
    lines.push('- id=' + item.id);
    lines.push('  passed=' + String(!!item.passed));
    lines.push('  skipped=' + String(!!item.actual.skipped));
    lines.push('  targetPathBuilt=' + String(!!item.actual.targetPathBuilt));
    lines.push('  targetWritesPlanned=' + String(item.actual.targetWritesPlanned || 0));
    lines.push('  firestoreReads=' + String(item.actual.firestoreReads || 0));
    lines.push('  firestoreWrites=' + String(item.actual.firestoreWrites || 0));
    lines.push('  publishFromTarget=' + String(!!item.actual.publishFromTarget));
    lines.push('  publishToTarget=' + String(!!item.actual.publishToTarget));
    lines.push('  cutover=' + String(!!item.actual.cutover));
    lines.push('  lifecycleTouched=' + String(!!item.actual.lifecycleTouched));
    lines.push('  error=' + (item.actual.error || 'none'));
    lines.push('  mismatchReasons=' + ((item.mismatchReasons || []).length ? item.mismatchReasons.join(',') : 'none'));
  });
  return lines.join('\n');
}

function formatMigration1TargetPublishRuntimeFeedback_(status) {
  status = status || runMigration1TargetPublishRuntimeStatus_();
  var stats = status.stats || buildMigration1TargetPublishErrorStats_('missing_status', 'unknown');
  var lines = [];
  lines.push('MIGRATION_1_PUB_RUNTIME_STATUS');
  lines.push('ok=' + String(!!status.ok));
  lines.push('enabled=' + String(!!stats.enabled));
  lines.push('skipped=' + String(!!stats.skipped));
  lines.push('reason=' + String(stats.reason || ''));
  lines.push('tenantId=' + String(stats.tenantId || ''));
  lines.push('tenantCanonical=' + String(!!stats.tenantCanonical));
  lines.push('targetReadWriteAuthorized=' + String(!!stats.targetReadWriteAuthorized));
  lines.push('legacyWritesSeen=' + String(stats.legacyWritesSeen || 0));
  lines.push('targetWritesPlanned=' + String(stats.targetWritesPlanned || 0));
  lines.push('firestoreReads=' + String(stats.firestoreReads || 0));
  lines.push('firestoreWrites=' + String(stats.firestoreWrites || 0));
  lines.push('publishFromTarget=' + String(!!stats.publishFromTarget));
  lines.push('publishToTarget=' + String(!!stats.publishToTarget));
  lines.push('targetPathBuilt=' + String(!!stats.targetPathBuilt));
  lines.push('cutover=' + String(!!stats.cutover));
  lines.push('lifecycleTouched=' + String(!!stats.lifecycleTouched));
  lines.push('error=' + (stats.error || 'none'));
  lines.push('errorKind=' + (stats.errorKind || 'none'));
  return lines.join('\n');
}
