var PHBOX_M1_IDRES_PLACEHOLDER_FULL_NAME_ = 'Assistito senza nome';
var PHBOX_M1_IDRES_IDENTITY_TYPE_CF_ = 'cf';
var PHBOX_M1_IDRES_IDENTITY_TYPE_NOCF_ = 'nocf';
var PHBOX_M1_IDRES_IDENTITY_TYPE_UNKNOWN_ = 'unknown';
var PHBOX_M1_IDRES_KNOWN_OCR_CF_FRAGMENTS_ = {
  ICLTRSO: true,
  ICSLVCN: true
};


function resolveMigration1BackendIdentity_(source) {
  source = source || {};

  var explicitType = String(source.identityType || '').trim().toLowerCase();
  var cf = normalizeMigration1IdentityResolverCf_(source.cf || source.fiscalCode || source.patientFiscalCode || source.codiceFiscale || '');
  var identityAnchor = normalizeMigration1IdentityResolverSegment_(source.identityAnchor || source.assistitoId || '');
  var legacyNoCfCode = normalizeMigration1IdentityResolverSegment_(source.legacyNoCfCode || source.noCfCode || source.identityCode || '');
  var nameResolution = resolveMigration1IdentityResolverFullName_(source);
  var reasons = [];

  if (nameResolution.reason) {
    reasons.push(nameResolution.reason);
  }

  if (explicitType &&
      explicitType !== PHBOX_M1_IDRES_IDENTITY_TYPE_CF_ &&
      explicitType !== PHBOX_M1_IDRES_IDENTITY_TYPE_NOCF_) {
    reasons.push('identity_type_unsupported');
    return buildMigration1IdentityResolverResult_(false, PHBOX_M1_IDRES_IDENTITY_TYPE_UNKNOWN_, '', cf, legacyNoCfCode, nameResolution, reasons);
  }

  if (isMigration1IdentityResolverValidCf_(cf)) {
    if (explicitType === PHBOX_M1_IDRES_IDENTITY_TYPE_NOCF_) {
      reasons.push('identity_type_nocf_with_valid_cf');
      return buildMigration1IdentityResolverResult_(false, PHBOX_M1_IDRES_IDENTITY_TYPE_UNKNOWN_, '', cf, legacyNoCfCode, nameResolution, reasons);
    }
    return buildMigration1IdentityResolverResult_(true, PHBOX_M1_IDRES_IDENTITY_TYPE_CF_, cf, cf, '', nameResolution, reasons);
  }

  if (cf) {
    reasons.push('invalid_cf_rejected');
  }

  if (explicitType === PHBOX_M1_IDRES_IDENTITY_TYPE_CF_) {
    reasons.push('identity_type_cf_without_valid_cf');
    return buildMigration1IdentityResolverResult_(false, PHBOX_M1_IDRES_IDENTITY_TYPE_UNKNOWN_, '', cf, legacyNoCfCode, nameResolution, reasons);
  }

  var noCfAnchor = identityAnchor || legacyNoCfCode;
  if (explicitType === PHBOX_M1_IDRES_IDENTITY_TYPE_NOCF_ || noCfAnchor) {
    if (!noCfAnchor) {
      reasons.push('nocf_anchor_missing');
      return buildMigration1IdentityResolverResult_(false, PHBOX_M1_IDRES_IDENTITY_TYPE_UNKNOWN_, '', cf, legacyNoCfCode, nameResolution, reasons);
    }
    return buildMigration1IdentityResolverResult_(true, PHBOX_M1_IDRES_IDENTITY_TYPE_NOCF_, noCfAnchor, '', legacyNoCfCode || noCfAnchor, nameResolution, reasons);
  }

  reasons.push('identity_anchor_missing');
  return buildMigration1IdentityResolverResult_(false, PHBOX_M1_IDRES_IDENTITY_TYPE_UNKNOWN_, '', cf, legacyNoCfCode, nameResolution, reasons);
}

function buildMigration1IdentityResolverResult_(ok, identityType, identityAnchor, cf, noCfCode, nameResolution, reasons) {
  return {
    ok: !!ok,
    identityType: identityType || PHBOX_M1_IDRES_IDENTITY_TYPE_UNKNOWN_,
    identityAnchor: identityAnchor || '',
    cf: cf || '',
    noCfCode: noCfCode || '',
    fullNameSafe: nameResolution.fullNameSafe,
    nameAccepted: !!nameResolution.nameAccepted,
    reasons: uniqueNonEmptyStrings_(reasons || []),
    publishFromTarget: false,
    firestoreReads: 0,
    firestoreWrites: 0
  };
}

function normalizeMigration1IdentityResolverCf_(value) {
  return normalizeCf_(value);
}

function isMigration1IdentityResolverValidCf_(value) {
  var cf = normalizeMigration1IdentityResolverCf_(value);
  return /^[A-Z]{6}[0-9]{2}[A-Z][0-9]{2}[A-Z][0-9A-Z]{3}[A-Z]$/.test(cf);
}

function isMigration1IdentityResolverCfLikeToken_(value) {
  var token = normalizeMigration1IdentityResolverCf_(value);
  return /^[A-Z]{6}[0-9A-Z]{2}[A-Z][0-9A-Z]{2}[A-Z][0-9A-Z]{3}[A-Z]$/.test(token);
}

function normalizeMigration1IdentityResolverSegment_(value) {
  var text = String(value || '').trim();
  if (!text) return '';
  if (text.indexOf('/') !== -1) return '';
  return text;
}

function resolveMigration1IdentityResolverFullName_(source) {
  source = source || {};
  var rawCandidates = [
    source.fullName,
    source.patientFullName,
    joinMigration1IdentityResolverNameParts_(source.nome, source.cognome),
    joinMigration1IdentityResolverNameParts_(source.name, source.surname)
  ];

  for (var i = 0; i < rawCandidates.length; i++) {
    var raw = String(rawCandidates[i] || '');
    var normalized = normalizePersonName_(raw);
    if (!normalized) continue;
    var rejection = getMigration1IdentityResolverNameRejectionReason_(raw, normalized);
    if (rejection) {
      return {
        fullNameSafe: PHBOX_M1_IDRES_PLACEHOLDER_FULL_NAME_,
        nameAccepted: false,
        reason: rejection
      };
    }
    return {
      fullNameSafe: normalized,
      nameAccepted: true,
      reason: ''
    };
  }

  return {
    fullNameSafe: PHBOX_M1_IDRES_PLACEHOLDER_FULL_NAME_,
    nameAccepted: false,
    reason: 'full_name_missing'
  };
}

function joinMigration1IdentityResolverNameParts_(first, second) {
  return [String(first || '').trim(), String(second || '').trim()].filter(function (item) { return !!item; }).join(' ');
}

function getMigration1IdentityResolverNameRejectionReason_(raw, normalized) {
  var key = normalizeToken_(normalized);
  if (!key) return 'full_name_missing';
  if (key === 'ASSISTITO SENZA NOME' || key === 'SENZA NOME' || key === 'SCONOSCIUTO' || key === 'UNKNOWN') {
    return 'full_name_placeholder';
  }

  var tokens = String(raw || normalized)
    .split(/\s+/)
    .map(function (item) { return normalizeMigration1IdentityResolverCf_(item); })
    .filter(function (item) { return !!item; });

  for (var i = 0; i < tokens.length; i++) {
    if (isMigration1IdentityResolverCfLikeToken_(tokens[i])) {
      return 'full_name_contains_cf_token';
    }
    if (PHBOX_M1_IDRES_KNOWN_OCR_CF_FRAGMENTS_[tokens[i]]) {
      return 'full_name_contains_ocr_cf_fragment';
    }
  }

  return '';
}

function runMigration1IdentityResolverSelfTest_() {
  var cases = [
    {
      id: 'cf_valid',
      input: { patientFiscalCode: 'RSSMRA80A01H501U', fullName: 'Mario Rossi' },
      expected: { ok: true, identityType: PHBOX_M1_IDRES_IDENTITY_TYPE_CF_, identityAnchor: 'RSSMRA80A01H501U', fullNameSafe: 'Mario Rossi' }
    },
    {
      id: 'nocf_manual',
      input: { identityType: 'nocf', identityAnchor: 'nocf_manual_001', fullName: 'Fantauzzo Amedeo' },
      expected: { ok: true, identityType: PHBOX_M1_IDRES_IDENTITY_TYPE_NOCF_, identityAnchor: 'nocf_manual_001', fullNameSafe: 'Fantauzzo Amedeo' }
    },
    {
      id: 'placeholder_name_rejected',
      input: { patientFiscalCode: 'RSSMRA80A01H501U', fullName: 'Assistito senza nome' },
      expected: { ok: true, identityType: PHBOX_M1_IDRES_IDENTITY_TYPE_CF_, fullNameSafe: PHBOX_M1_IDRES_PLACEHOLDER_FULL_NAME_, reason: 'full_name_placeholder' }
    },
    {
      id: 'cf_like_name_rejected',
      input: { patientFiscalCode: 'RSSMRA80A01H501U', fullName: 'RSSMRA80A01H501U' },
      expected: { ok: true, identityType: PHBOX_M1_IDRES_IDENTITY_TYPE_CF_, fullNameSafe: PHBOX_M1_IDRES_PLACEHOLDER_FULL_NAME_, reason: 'full_name_contains_cf_token' }
    },
    {
      id: 'ocr_fragment_rejected',
      input: { identityType: 'nocf', identityAnchor: 'nocf_manual_002', fullName: 'ICLTRSO' },
      expected: { ok: true, identityType: PHBOX_M1_IDRES_IDENTITY_TYPE_NOCF_, fullNameSafe: PHBOX_M1_IDRES_PLACEHOLDER_FULL_NAME_, reason: 'full_name_contains_ocr_cf_fragment' }
    },
    {
      id: 'unsupported_identity_type_rejected_before_cf',
      input: { identityType: 'legacy', patientFiscalCode: 'RSSMRA80A01H501U', fullName: 'Mario Rossi' },
      expected: { ok: false, identityType: PHBOX_M1_IDRES_IDENTITY_TYPE_UNKNOWN_, cf: 'RSSMRA80A01H501U', fullNameSafe: 'Mario Rossi', reason: 'identity_type_unsupported' }
    },
    {
      id: 'missing_identity_rejected',
      input: { fullName: 'Mario Rossi' },
      expected: { ok: false, identityType: PHBOX_M1_IDRES_IDENTITY_TYPE_UNKNOWN_, fullNameSafe: 'Mario Rossi', reason: 'identity_anchor_missing' }
    }
  ];

  var passed = 0;
  var failed = 0;
  var items = cases.map(function (item) {
    var actual = resolveMigration1BackendIdentity_(item.input);
    var mismatchReasons = compareMigration1IdentityResolverExpected_(actual, item.expected);
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
    items: items
  };
}

function compareMigration1IdentityResolverExpected_(actual, expected) {
  var mismatches = [];
  Object.keys(expected || {}).forEach(function (key) {
    if (key === 'reason') {
      if ((actual.reasons || []).indexOf(expected[key]) === -1) {
        mismatches.push('missing_reason_' + expected[key]);
      }
      return;
    }
    if (actual[key] !== expected[key]) {
      mismatches.push('field_' + key + '_mismatch');
    }
  });
  return mismatches;
}

function formatMigration1IdentityResolverSelfTestFeedback_(result) {
  result = result || runMigration1IdentityResolverSelfTest_();
  var lines = [];
  lines.push('MIGRATION_1_IDRES_TEST');
  lines.push('ok=' + String(!!result.ok));
  lines.push('testCount=' + String(result.testCount || 0));
  lines.push('passedCount=' + String(result.passedCount || 0));
  lines.push('failedCount=' + String(result.failedCount || 0));
  lines.push('firestoreReads=' + String(result.firestoreReads || 0));
  lines.push('firestoreWrites=' + String(result.firestoreWrites || 0));
  lines.push('publishFromTarget=' + String(!!result.publishFromTarget));
  lines.push('items=');
  (result.items || []).forEach(function (item) {
    lines.push('- id=' + item.id);
    lines.push('  passed=' + String(!!item.passed));
    lines.push('  identityType=' + String(item.actual.identityType || ''));
    lines.push('  identityAnchor=' + String(item.actual.identityAnchor || ''));
    lines.push('  cf=' + String(item.actual.cf || ''));
    lines.push('  noCfCode=' + String(item.actual.noCfCode || ''));
    lines.push('  fullNameSafe=' + String(item.actual.fullNameSafe || ''));
    lines.push('  nameAccepted=' + String(!!item.actual.nameAccepted));
    lines.push('  reasons=' + ((item.actual.reasons || []).length ? item.actual.reasons.join(',') : 'none'));
    lines.push('  mismatchReasons=' + ((item.mismatchReasons || []).length ? item.mismatchReasons.join(',') : 'none'));
  });
  return lines.join('\n');
}
