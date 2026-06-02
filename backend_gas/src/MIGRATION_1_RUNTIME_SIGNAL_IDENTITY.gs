var PHBOX_M1_SIG_STAGE_ = 'migration1_runtime_signal_identity';


function resolveMigration1RuntimeSignalIdentity_(signal, overrides) {
  signal = signal || {};
  overrides = overrides || {};
  var hasTargetFiscalCodeOverride = Object.prototype.hasOwnProperty.call(overrides, 'targetFiscalCode');
  var legacyTargetCf = normalizeCf_(hasTargetFiscalCodeOverride ? overrides.targetFiscalCode : (signal.targetFiscalCode || ''));
  var identity = resolveMigration1BackendIdentity_({
    identityType: overrides.identityType !== undefined ? overrides.identityType : signal.identityType,
    identityAnchor: overrides.identityAnchor || signal.identityAnchor || signal.targetIdentityAnchor || '',
    legacyNoCfCode: overrides.legacyNoCfCode || signal.legacyNoCfCode || signal.noCfCode || '',
    patientFiscalCode: legacyTargetCf,
    fullName: overrides.targetFullName || signal.targetFullName || signal.fullName || signal.patientFullName || ''
  });
  var identityType = String(identity.identityType || PHBOX_M1_IDRES_IDENTITY_TYPE_UNKNOWN_).trim().toLowerCase();
  var targetFiscalCode = identityType === PHBOX_M1_IDRES_IDENTITY_TYPE_CF_ ? normalizeCf_(identity.cf) : legacyTargetCf;
  if (identityType === PHBOX_M1_IDRES_IDENTITY_TYPE_NOCF_) {
    targetFiscalCode = '';
  }
  var overrideReasons = Array.isArray(overrides.identityResolutionReasons) ? overrides.identityResolutionReasons : null;
  var signalReasons = Array.isArray(signal.identityResolutionReasons) ? signal.identityResolutionReasons : [];
  var identityReasons = Array.isArray(identity.reasons) ? identity.reasons : [];
  var resolvedReasons = overrideReasons !== null ? overrideReasons : (signalReasons.length ? signalReasons : identityReasons);
  return {
    identityType: identityType,
    identityAnchor: String(identity.identityAnchor || '').trim(),
    identityAnchorCanonical: overrides.identityAnchorCanonical === undefined ? !!identity.ok : !!overrides.identityAnchorCanonical,
    targetFiscalCode: targetFiscalCode,
    legacyNoCfCode: String(overrides.legacyNoCfCode || signal.legacyNoCfCode || identity.noCfCode || '').trim(),
    identityResolutionReasons: uniqueNonEmptyStrings_(resolvedReasons),
    firestoreReads: 0,
    firestoreWrites: 0,
    publishFromTarget: false
  };
}

function buildMigration1RuntimeSignalIdentityStats_(result) {
  result = result || runMigration1RuntimeSignalIdentitySelfTest_();
  return {
    stage: PHBOX_M1_SIG_STAGE_,
    ok: !!result.ok,
    testCount: Number(result.testCount || 0),
    passedCount: Number(result.passedCount || 0),
    failedCount: Number(result.failedCount || 0),
    firestoreReads: 0,
    firestoreWrites: 0,
    publishFromTarget: false,
    publishToTarget: false,
    targetPathBuilt: false,
    cutover: false,
    lifecycleTouched: false
  };
}

function runMigration1RuntimeSignalIdentitySelfTest_() {
  var cases = [
    {
      id: 'cf_signal_gets_identity_anchor',
      input: { domain: 'debts', targetFiscalCode: 'RSSMRA80A01H501U', targetFullName: 'Mario Rossi' },
      expected: { identityType: 'cf', identityAnchor: 'RSSMRA80A01H501U', targetFiscalCode: 'RSSMRA80A01H501U', identityAnchorCanonical: true }
    },
    {
      id: 'nocf_signal_preserves_anchor_without_cf',
      input: { domain: 'bookings', identityType: 'nocf', identityAnchor: 'NOCF_MANUAL_001', targetFullName: 'Amedeo Fantauzzo' },
      expected: { identityType: 'nocf', identityAnchor: 'NOCF_MANUAL_001', targetFiscalCode: '', identityAnchorCanonical: true }
    },
    {
      id: 'unsupported_identity_type_keeps_legacy_cf_but_not_canonical',
      input: { domain: 'advances', identityType: 'legacy', targetFiscalCode: 'RSSMRA80A01H501U', targetFullName: 'Mario Rossi' },
      expected: { identityType: 'unknown', identityAnchor: '', targetFiscalCode: 'RSSMRA80A01H501U', identityAnchorCanonical: false, reason: 'identity_type_unsupported' }
    },
    {
      id: 'slash_identity_anchor_rejected_without_path_build',
      input: { domain: 'debts', identityType: 'nocf', identityAnchor: 'bad/anchor', targetFullName: 'Mario Rossi' },
      expected: { identityType: 'unknown', identityAnchor: '', targetFiscalCode: '', identityAnchorCanonical: false, reason: 'nocf_anchor_missing' }
    },
    {
      id: 'write_data_persists_identity_fields',
      input: { domain: 'deletePdf', signalId: 'sig_1', targetFiscalCode: 'RSSMRA80A01H501U' },
      expectedWriteData: { identityType: 'cf', identityAnchor: 'RSSMRA80A01H501U', targetFiscalCode: 'RSSMRA80A01H501U', identityAnchorCanonical: true }
    },
    {
      id: 'sanitized_result_preserves_identity_fields',
      resultInput: { ok: true, domain: 'debts', cf: 'RSSMRA80A01H501U', identityType: 'cf', identityAnchor: 'RSSMRA80A01H501U', identityAnchorCanonical: true },
      expectedSanitized: { identityType: 'cf', identityAnchor: 'RSSMRA80A01H501U', cf: 'RSSMRA80A01H501U', identityAnchorCanonical: true }
    },
    {
      id: 'sanitized_result_preserves_full_nocf_metadata',
      resultInput: {
        ok: true,
        domain: 'deletePdf',
        identityType: 'nocf',
        identityAnchor: 'NOCF_MANUAL_001',
        identityAnchorCanonical: true,
        legacyNoCfCode: 'MANUAL_001',
        identityResolutionReasons: ['nocf_manual_anchor']
      },
      expectedSanitized: {
        identityType: 'nocf',
        identityAnchor: 'NOCF_MANUAL_001',
        identityAnchorCanonical: true,
        legacyNoCfCode: 'MANUAL_001',
        reason: 'nocf_manual_anchor'
      }
    },
    {
      id: 'delete_pdf_target_identity_reasons_preserved',
      input: { domain: 'deletePdf', signalId: 'sig_nocf_target_1', targetPath: 'drive_pdf_imports/file_1' },
      identityOverrides: {
        identityType: 'nocf',
        identityAnchor: 'NOCF_MANUAL_001',
        legacyNoCfCode: 'MANUAL_001',
        identityResolutionReasons: ['target_identity_verified']
      },
      expectedResolvedIdentity: {
        identityType: 'nocf',
        identityAnchor: 'NOCF_MANUAL_001',
        identityAnchorCanonical: true,
        legacyNoCfCode: 'MANUAL_001',
        reason: 'target_identity_verified'
      }
    },
    {
      id: 'done_write_preserves_result_nocf_metadata_top_level',
      input: { domain: 'deletePdf', signalId: 'sig_nocf_1', targetPath: 'drive_pdf_imports/file_1' },
      doneResult: {
        ok: true,
        domain: 'deletePdf',
        identityType: 'nocf',
        identityAnchor: 'NOCF_MANUAL_001',
        identityAnchorCanonical: true,
        legacyNoCfCode: 'MANUAL_001',
        identityResolutionReasons: ['nocf_manual_anchor']
      },
      expectedDoneWriteData: {
        identityType: 'nocf',
        identityAnchor: 'NOCF_MANUAL_001',
        identityAnchorCanonical: true,
        legacyNoCfCode: 'MANUAL_001',
        reason: 'nocf_manual_anchor'
      }
    },
    {
      id: 'done_write_without_canonical_override_recomputes_cf_canonical',
      input: { domain: 'patientDelete', signalId: 'sig_cf_done_1', targetFiscalCode: 'RSSMRA80A01H501U' },
      doneResult: {
        ok: true,
        domain: 'patientDelete',
        cf: 'RSSMRA80A01H501U'
      },
      expectedDoneWriteData: {
        identityType: 'cf',
        identityAnchor: 'RSSMRA80A01H501U',
        identityAnchorCanonical: true,
        targetFiscalCode: 'RSSMRA80A01H501U'
      }
    },
    {
      id: 'done_write_explicit_nocf_ignores_stale_signal_cf',
      input: {
        domain: 'deletePdf',
        signalId: 'sig_stale_cf_nocf_done_1',
        targetFiscalCode: 'RSSMRA80A01H501U',
        targetPath: 'drive_pdf_imports/file_1'
      },
      doneResult: {
        ok: true,
        domain: 'deletePdf',
        identityType: 'nocf',
        identityAnchor: 'NOCF_MANUAL_001',
        identityAnchorCanonical: true,
        legacyNoCfCode: 'MANUAL_001',
        identityResolutionReasons: ['nocf_manual_anchor']
      },
      expectedDoneWriteData: {
        identityType: 'nocf',
        identityAnchor: 'NOCF_MANUAL_001',
        identityAnchorCanonical: true,
        targetFiscalCode: '',
        legacyNoCfCode: 'MANUAL_001',
        reason: 'nocf_manual_anchor'
      }
    },
    {
      id: 'done_write_preserves_existing_signal_identity_reasons',
      input: {
        domain: 'backup',
        signalId: 'sig_existing_nocf_reason_1',
        identityType: 'nocf',
        identityAnchor: 'NOCF_MANUAL_002',
        legacyNoCfCode: 'MANUAL_002',
        targetFullName: 'Amedeo Fantauzzo',
        identityResolutionReasons: ['existing_signal_identity_reason']
      },
      doneResult: {
        ok: true,
        domain: 'backup'
      },
      expectedDoneWriteData: {
        identityType: 'nocf',
        identityAnchor: 'NOCF_MANUAL_002',
        identityAnchorCanonical: true,
        targetFiscalCode: '',
        legacyNoCfCode: 'MANUAL_002',
        reason: 'existing_signal_identity_reason'
      }
    }
  ];

  var passed = 0;
  var failed = 0;
  var items = cases.map(function (item) {
    var actual = item.doneResult
      ? buildRuntimeSignalWriteData_(item.input, buildRuntimeSignalDoneWriteOverrides_(item.input, item.doneResult, '2026-01-01T00:00:00.000Z'))
      : (item.identityOverrides
        ? resolveMigration1RuntimeSignalIdentity_(item.input, item.identityOverrides)
        : (item.resultInput
          ? sanitizeRuntimeSignalResult_(item.resultInput)
          : (item.expectedWriteData ? buildRuntimeSignalWriteData_(item.input, {}) : resolveMigration1RuntimeSignalIdentity_(item.input, {}))));
    var expected = item.expected || item.expectedWriteData || item.expectedSanitized || item.expectedDoneWriteData || item.expectedResolvedIdentity || {};
    var mismatchReasons = compareMigration1RuntimeSignalIdentityExpected_(actual, expected);
    var ok = mismatchReasons.length === 0;
    if (ok) passed++; else failed++;
    return {
      id: item.id,
      passed: ok,
      mismatchReasons: mismatchReasons,
      expected: expected,
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
    publishToTarget: false,
    targetPathBuilt: false,
    cutover: false,
    lifecycleTouched: false,
    items: items
  };
}


function compareMigration1RuntimeSignalIdentityExpected_(actual, expected) {
  var mismatches = [];
  Object.keys(expected || {}).forEach(function (key) {
    if (key === 'reason') {
      if ((actual.identityResolutionReasons || []).indexOf(expected[key]) === -1) {
        mismatches.push('missing_reason_' + expected[key]);
      }
      return;
    }
    if (actual[key] !== expected[key]) {
      mismatches.push('field_' + key + '_mismatch');
    }
  });
  return uniqueNonEmptyStrings_(mismatches);
}

function formatMigration1RuntimeSignalIdentitySelfTestFeedback_(result) {
  result = result || runMigration1RuntimeSignalIdentitySelfTest_();
  var lines = [];
  lines.push('MIGRATION_1_SIG_TEST');
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
    lines.push('- id=' + item.id);
    lines.push('  passed=' + String(!!item.passed));
    lines.push('  identityType=' + String(item.actual.identityType || ''));
    lines.push('  identityAnchor=' + String(item.actual.identityAnchor || ''));
    lines.push('  identityAnchorCanonical=' + String(!!item.actual.identityAnchorCanonical));
    lines.push('  targetFiscalCode=' + String(item.actual.targetFiscalCode || item.actual.cf || ''));
    lines.push('  firestoreReads=0');
    lines.push('  firestoreWrites=0');
    lines.push('  publishFromTarget=false');
    lines.push('  targetPathBuilt=false');
    lines.push('  cutover=false');
    lines.push('  lifecycleTouched=false');
    lines.push('  identityResolutionReasons=' + ((item.actual.identityResolutionReasons || []).length ? item.actual.identityResolutionReasons.join(',') : 'none'));
    lines.push('  mismatchReasons=' + ((item.mismatchReasons || []).length ? item.mismatchReasons.join(',') : 'none'));
  });
  return lines.join('\n');
}
