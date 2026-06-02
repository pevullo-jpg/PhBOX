var PHBOX_M1_DASH_STAGE_ = 'migration1_dashboard_frontend_compat';

function runMigration1DashboardCompatSelfTest_() {
  var cases = [
    {
      id: 'cf_index_row_uses_cf_identity_key',
      input: { fiscalCode: 'RSSMRA80A01H501U', fullName: 'Mario Rossi', identityType: 'cf', identityAnchor: 'RSSMRA80A01H501U' },
      expected: { identityType: 'cf', identityKey: 'RSSMRA80A01H501U', copyableFiscalCode: 'RSSMRA80A01H501U', displayName: 'Mario Rossi', valid: true }
    },
    {
      id: 'nocf_index_row_uses_anchor_not_cf',
      input: { fiscalCode: 'NOCF_MANUAL_001', fullName: 'Amedeo Fantauzzo', identityType: 'nocf', identityAnchor: 'NOCF_MANUAL_001' },
      expected: { identityType: 'nocf', identityKey: 'NOCF_MANUAL_001', copyableFiscalCode: '', displayName: 'Amedeo Fantauzzo', valid: true }
    },
    {
      id: 'nocf_row_with_stale_cf_uses_anchor_and_hides_cf',
      input: { fiscalCode: 'RSSMRA80A01H501U', fullName: 'Amedeo Fantauzzo', identityType: 'nocf', identityAnchor: 'NOCF_MANUAL_002', identityResolutionReasons: ['target_identity_verified'] },
      expected: { identityType: 'nocf', identityKey: 'NOCF_MANUAL_002', copyableFiscalCode: '', displayName: 'Amedeo Fantauzzo', valid: true, reason: 'target_identity_verified' }
    },
    {
      id: 'nocf_without_name_does_not_display_anchor_as_name',
      input: { fiscalCode: 'NOCF_MANUAL_003', fullName: '', identityType: 'nocf', identityAnchor: 'NOCF_MANUAL_003' },
      expected: { identityType: 'nocf', identityKey: 'NOCF_MANUAL_003', copyableFiscalCode: '', displayName: 'Assistito senza nome', valid: true }
    },
    {
      id: 'cf_missing_fiscal_code_uses_identity_anchor',
      input: { fiscalCode: '', fullName: 'Mario Rossi', identityType: 'cf', identityAnchor: 'RSSMRA80A01H501U' },
      expected: { identityType: 'cf', identityKey: 'RSSMRA80A01H501U', copyableFiscalCode: 'RSSMRA80A01H501U', displayName: 'Mario Rossi', valid: true }
    },
    {
      id: 'slash_identity_anchor_rejected_before_path_use',
      input: { fiscalCode: '', fullName: 'Mario Rossi', identityType: 'nocf', identityAnchor: 'bad/anchor' },
      expected: { identityType: 'nocf', identityKey: '', copyableFiscalCode: '', displayName: 'Mario Rossi', valid: false, reason: 'identity_anchor_contains_slash' }
    },
    {
      id: 'unknown_identity_keeps_legacy_cf_compatibility',
      input: { fiscalCode: 'RSSMRA80A01H501U', fullName: 'Mario Rossi', identityType: 'legacy', identityAnchor: '' },
      expected: { identityType: '', identityKey: 'RSSMRA80A01H501U', copyableFiscalCode: 'RSSMRA80A01H501U', displayName: 'Mario Rossi', valid: true }
    },
    {
      id: 'dpc_flag_match_uses_dashboard_identity_key_not_stale_cf',
      input: { fiscalCode: 'RSSMRA80A01H501U', fullName: 'Amedeo Fantauzzo', identityType: 'nocf', identityAnchor: 'NOCF_DPC_001', hasDpc: true },
      expected: { identityType: 'nocf', identityKey: 'NOCF_DPC_001', copyableFiscalCode: '', displayName: 'Amedeo Fantauzzo', valid: true }
    }
  ];

  var passed = 0;
  var failed = 0;
  var items = cases.map(function (item) {
    var actual = normalizeMigration1DashboardCompatIndexRow_(item.input);
    var mismatchReasons = compareMigration1DashboardCompatExpected_(actual, item.expected);
    var ok = mismatchReasons.length === 0;
    if (ok) passed++; else failed++;
    return {
      id: item.id,
      passed: ok,
      actual: actual,
      expected: item.expected,
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

function normalizeMigration1DashboardCompatIndexRow_(row) {
  row = row || {};
  var identityType = normalizeMigration1DashboardCompatIdentityType_(row.identityType);
  var rawFiscalCode = normalizeCf_(row.cf || row.fiscalCode || row.patientFiscalCode || '');
  var rawIdentityAnchor = String(row.identityAnchor || '').trim().toUpperCase();
  var reasons = uniqueNonEmptyStrings_(row.identityResolutionReasons || []);
  var valid = true;
  var identityKey = '';

  if (rawIdentityAnchor.indexOf('/') >= 0) {
    valid = false;
    reasons.push('identity_anchor_contains_slash');
  } else if (identityType === 'nocf') {
    identityKey = rawIdentityAnchor || rawFiscalCode;
  } else if (identityType === 'cf') {
    identityKey = rawIdentityAnchor || rawFiscalCode;
  } else {
    identityKey = rawFiscalCode;
  }

  var copyableFiscalCode = '';
  if (identityType !== 'nocf') {
    copyableFiscalCode = rawFiscalCode || (identityType === 'cf' ? rawIdentityAnchor : '');
  }

  var displayName = String(row.fullName || row.patientFullName || '').trim();
  if (!displayName) {
    displayName = identityType === 'nocf' ? 'Assistito senza nome' : (copyableFiscalCode || identityKey);
  }

  return {
    identityType: identityType,
    identityKey: valid ? identityKey : '',
    copyableFiscalCode: copyableFiscalCode,
    displayName: displayName,
    valid: valid,
    identityResolutionReasons: uniqueNonEmptyStrings_(reasons),
    firestoreReads: 0,
    firestoreWrites: 0,
    publishFromTarget: false,
    publishToTarget: false,
    targetPathBuilt: false,
    cutover: false,
    lifecycleTouched: false
  };
}

function normalizeMigration1DashboardCompatIdentityType_(value) {
  var normalized = String(value || '').trim().toLowerCase();
  if (normalized === 'cf' || normalized === 'nocf') return normalized;
  return '';
}

function compareMigration1DashboardCompatExpected_(actual, expected) {
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

function formatMigration1DashboardCompatSelfTestFeedback_(result) {
  result = result || runMigration1DashboardCompatSelfTest_();
  var lines = [];
  lines.push('MIGRATION_1_DASH_TEST');
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
    lines.push('  identityType=' + String(actual.identityType || ''));
    lines.push('  identityKey=' + String(actual.identityKey || ''));
    lines.push('  copyableFiscalCode=' + String(actual.copyableFiscalCode || ''));
    lines.push('  displayName=' + String(actual.displayName || ''));
    lines.push('  valid=' + String(actual.valid !== false));
    lines.push('  firestoreReads=0');
    lines.push('  firestoreWrites=0');
    lines.push('  publishFromTarget=false');
    lines.push('  targetPathBuilt=false');
    lines.push('  cutover=false');
    lines.push('  lifecycleTouched=false');
    lines.push('  identityResolutionReasons=' + ((actual.identityResolutionReasons || []).length ? actual.identityResolutionReasons.join(',') : 'none'));
    lines.push('  mismatchReasons=' + ((item.mismatchReasons || []).length ? item.mismatchReasons.join(',') : 'none'));
  });
  return lines.join('\n');
}
