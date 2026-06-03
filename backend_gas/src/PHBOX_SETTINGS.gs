function doGet(e) {
  var page = String(e && e.parameter && e.parameter.page || '').trim().toLowerCase();
  if (page === 'auth' || page === 'authorize' || page === 'health') {
    return HtmlService.createHtmlOutputFromFile('BACKEND_AUTH_CENTER_PAGE')
      .setTitle('PhBOX Backend Authorization Center');
  }

  return HtmlService.createHtmlOutputFromFile('SETTINGS')
    .setTitle('PhBOX Settings');
}

function getPhboxSettingsPageData() {
  var cfg = readPhboxConfigFromProperties_();
  return {
    settings: serializePhboxSettingsForUi_(cfg),
    feedback: getPhboxSettingsFeedback_()
  };
}

function savePhboxSettings(payload) {
  payload = payload || {};
  var props = PropertiesService.getScriptProperties();

  var normalized = normalizePhboxSettingsPayload_(payload);
  props.setProperties({
    PHBOX_FOLDER_ID: normalized.folderId,
    PHBOX_FIRESTORE_PROJECT_ID: normalized.firestoreProjectId,
    PHBOX_OPERATIONAL_ACCOUNT_EMAIL: normalized.operationalAccountEmail,
    PHBOX_EXCLUDED_SENDERS: normalized.excludedEmailSenders.join('\n'),
    PHBOX_SCAN_UNREAD_ONLY: String(normalized.scanUnreadOnly),
    PHBOX_SCAN_SPAM: String(normalized.scanSpam),
    PHBOX_TRASH_VALID_EMAILS: String(normalized.trashValidEmails),
    PHBOX_ACCEPTED_CITIES: normalized.acceptedCities.join('\n'),
    PHBOX_ACCEPT_RECIPES_WITHOUT_CITY: String(normalized.acceptRecipesWithoutCity),
    PHBOX_STRICT_ACCEPTED_CITIES_FOR_GMAIL: String(normalized.acceptedCities.length > 0)
  }, false);

  clearMigration1ShadowSettingsTestProperties_(props);

  var cfg = getPhboxConfig_();
  writePhboxSettingsFeedback_(buildPhboxSettingsFeedback_({
    mode: 'config_saved',
    cfg: cfg
  }));

  return {
    ok: true,
    settings: serializePhboxSettingsForUi_(cfg),
    feedback: getPhboxSettingsFeedback_()
  };
}

function refreshPhboxSettingsFeedback() {
  var cfg = getPhboxConfig_();
  var diagnosis = diagnosePhboxBackendState();
  writePhboxSettingsFeedback_(buildPhboxSettingsFeedback_({
    mode: 'full_diagnosis',
    cfg: cfg,
    diagnosis: diagnosis
  }));
  return {
    ok: true,
    feedback: getPhboxSettingsFeedback_()
  };
}

function serializePhboxSettingsForUi_(cfg) {
  return {
    folderId: cfg.folderId || '',
    firestoreProjectId: cfg.firestoreProjectId || '',
    operationalAccountEmail: readPhboxOperationalAccountEmail_(),
    executingAccountEmail: getPhboxExecutingAccountEmail_(),
    excludedEmailSendersText: (cfg.excludedEmailSenders || []).join('\n'),
    scanUnreadOnly: !!cfg.scanUnreadOnly,
    scanSpam: !!cfg.scanSpam,
    trashValidEmails: !!cfg.trashValidEmails,
    acceptedCitiesText: (cfg.acceptedCities || []).join('\n'),
    acceptRecipesWithoutCity: !!cfg.acceptRecipesWithoutCity
  };
}

function normalizePhboxSettingsPayload_(payload) {
  var folderId = String(payload.folderId || '').trim();
  var firestoreProjectId = String(payload.firestoreProjectId || '').trim();
  var operationalAccountEmail = normalizePhboxOperationalAccountEmailForSettings_(payload.operationalAccountEmail);
  if (!folderId) throw new Error('ID cartella root obbligatorio.');
  if (!firestoreProjectId) throw new Error('ID progetto obbligatorio.');
  if (!operationalAccountEmail) throw new Error('Account Gmail operativo backend obbligatorio.');

  return {
    folderId: folderId,
    firestoreProjectId: firestoreProjectId,
    operationalAccountEmail: operationalAccountEmail,
    excludedEmailSenders: parseNormalizedListProperty_(payload.excludedEmailSendersText, function (item) {
      return normalizeEmailSenderToken_(item);
    }),
    scanUnreadOnly: !!payload.scanUnreadOnly,
    scanSpam: !!payload.scanSpam,
    trashValidEmails: !!payload.trashValidEmails,
    acceptedCities: parseNormalizedListProperty_(payload.acceptedCitiesText, function (item) {
      return normalizeToken_(item);
    }),
    acceptRecipesWithoutCity: !!payload.acceptRecipesWithoutCity
  };
}

function normalizePhboxOperationalAccountEmailForSettings_(value) {
  var email = String(value || '').trim().toLowerCase();
  if (!email) return '';
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    throw new Error('Account Gmail operativo backend non valido.');
  }
  return email;
}

function clearMigration1ShadowSettingsTestProperties_(props) {
  props = props || PropertiesService.getScriptProperties();
  [
    'PHBOX_M1_SHADOW_TARGET_ENABLED',
    'PHBOX_M1_SHADOW_MAX_ASSISTITI_SCAN'
  ].forEach(function (name) {
    props.deleteProperty(name);
  });
}

function getPhboxSettingsFeedback_() {
  var stored = PropertiesService.getScriptProperties().getProperty('PHBOX_SETTINGS_FEEDBACK');
  if (stored) return stored;
  return buildPhboxSettingsFeedback_({
    mode: 'config_snapshot',
    cfg: readPhboxConfigFromProperties_()
  });
}

function writePhboxSettingsFeedback_(text) {
  PropertiesService.getScriptProperties().setProperty('PHBOX_SETTINGS_FEEDBACK', String(text || ''));
}

function buildPhboxSettingsFeedback_(options) {
  options = options || {};
  var cfg = options.cfg || readPhboxConfigFromProperties_();
  var lines = [];
  lines.push('[' + new Date().toISOString() + ']');
  lines.push('MODE: ' + String(options.mode || 'config_snapshot'));
  lines.push('ROOT_FOLDER_ID: ' + (cfg.folderId || ''));
  lines.push('FIRESTORE_PROJECT_ID: ' + (cfg.firestoreProjectId || ''));
  lines.push('OPERATIONAL_ACCOUNT_EMAIL: ' + (readPhboxOperationalAccountEmail_() || ''));
  lines.push('SCAN_UNREAD_ONLY: ' + String(!!cfg.scanUnreadOnly));
  lines.push('SCAN_SPAM: ' + String(!!cfg.scanSpam));
  lines.push('TRASH_VALID_EMAILS: ' + String(!!cfg.trashValidEmails));
  lines.push('EXCLUDED_SENDERS_COUNT: ' + String((cfg.excludedEmailSenders || []).length));
  lines.push('ACCEPTED_CITIES_COUNT: ' + String((cfg.acceptedCities || []).length));
  lines.push('ACCEPT_RECIPES_WITHOUT_CITY: ' + String(!!cfg.acceptRecipesWithoutCity));
  lines.push('M1_CUT_TEST_AVAILABLE: true');
  lines.push('SETTINGS_UI_BUILD: M1_CUT_ONLY_UI_v2');
  lines.push('M1_DUAL_TEST_SETTINGS_REMOVED: true');
  lines.push('M1_DASH_TEST_SETTINGS_REMOVED: true');
  lines.push('M1_SIG_TEST_SETTINGS_REMOVED: true');
  lines.push('M1_PUB_TEST_SETTINGS_REMOVED: true');
  lines.push('M1_IDRES_TEST_SETTINGS_REMOVED: true');
  lines.push('M1_GATE_TEST_SETTINGS_REMOVED: true');
  lines.push('M1_SHADOW_TEST_SETTINGS_REMOVED: true');
  lines.push('GMAIL_QUERY_PREVIEW: ' + buildGmailQuery_(cfg, cfg.gmailProcessedLabel));

  if (options.diagnosis) {
    lines.push('');
    lines.push('DIAGNOSIS_NOTE: ' + String(options.diagnosis.note || ''));
    lines.push('AUTH_OK: ' + String(!!(options.diagnosis.authorizations && options.diagnosis.authorizations.ok)));
    lines.push('PDFS_VISIBLE: ' + String(options.diagnosis.pdfsVisibleToImporter || 0));
    lines.push('MANIFESTS_TOTAL: ' + String((options.diagnosis.manifests && options.diagnosis.manifests.total) || 0));
    lines.push('MANIFESTS_PARSED: ' + String((options.diagnosis.manifests && options.diagnosis.manifests.parsed) || 0));
    lines.push('MANIFESTS_ERRORS: ' + String((options.diagnosis.manifests && options.diagnosis.manifests.errors) || 0));
    lines.push('GMAIL_THREADS_PREVIEW: ' + String(options.diagnosis.gmailCandidateThreadsPreview || 0));
  }

  return lines.join('\n');
}

function runMigration1CutoverSettingsTest() {
  var result = runMigration1CutoverSelfTest_();
  var feedback = formatMigration1CutoverSelfTestFeedback_(result);
  writePhboxSettingsFeedback_(feedback);
  return {
    ok: !!result.ok,
    feedback: feedback
  };
}

function getMigration1CutoverSettingsStatus() {
  var result = runMigration1CutoverRuntimeStatus_();
  var feedback = formatMigration1CutoverRuntimeFeedback_(result);
  writePhboxSettingsFeedback_(feedback);
  return {
    ok: !!(result && result.ok),
    feedback: feedback
  };
}
