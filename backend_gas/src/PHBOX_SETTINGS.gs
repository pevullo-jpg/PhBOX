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
    PHBOX_STRICT_ACCEPTED_CITIES_FOR_GMAIL: String(normalized.acceptedCities.length > 0),
    PHBOX_M1_SHADOW_TARGET_ENABLED: String(normalized.migration1ShadowTargetEnabled)
  }, false);

  setOrDeletePhboxSettingsProperty_(props, 'PHBOX_TENANT_ID', normalized.migration1ShadowTenantId);
  setOrDeletePhboxSettingsProperty_(props, 'PHBOX_EXPECTED_CANONICAL_TENANT_ID', normalized.migration1ShadowExpectedCanonicalTenantId);
  setOrDeletePhboxSettingsProperty_(props, 'PHBOX_M1_SHADOW_MAX_ASSISTITI_SCAN', normalized.migration1ShadowMaxAssistitiScan);

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
    acceptRecipesWithoutCity: !!cfg.acceptRecipesWithoutCity,
    migration1ShadowTargetEnabled: readPhboxSettingsBoolProperty_('PHBOX_M1_SHADOW_TARGET_ENABLED'),
    migration1ShadowTenantId: readPhboxSettingsProperty_('PHBOX_TENANT_ID'),
    migration1ShadowExpectedCanonicalTenantId: readPhboxSettingsProperty_('PHBOX_EXPECTED_CANONICAL_TENANT_ID'),
    migration1ShadowMaxAssistitiScan: readPhboxSettingsProperty_('PHBOX_M1_SHADOW_MAX_ASSISTITI_SCAN')
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
    acceptRecipesWithoutCity: !!payload.acceptRecipesWithoutCity,
    migration1ShadowTargetEnabled: !!payload.migration1ShadowTargetEnabled,
    migration1ShadowTenantId: normalizePhboxSingleLineSettingsValue_(payload.migration1ShadowTenantId, 'PHBOX_TENANT_ID', 160),
    migration1ShadowExpectedCanonicalTenantId: normalizePhboxSingleLineSettingsValue_(payload.migration1ShadowExpectedCanonicalTenantId, 'PHBOX_EXPECTED_CANONICAL_TENANT_ID', 160),
    migration1ShadowMaxAssistitiScan: normalizePhboxM1ShadowMaxScanForSettings_(payload.migration1ShadowMaxAssistitiScan)
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

function readPhboxSettingsProperty_(name) {
  return String(PropertiesService.getScriptProperties().getProperty(name) || '');
}

function readPhboxSettingsBoolProperty_(name) {
  return /^true$/i.test(readPhboxSettingsProperty_(name).trim());
}

function setOrDeletePhboxSettingsProperty_(props, name, value) {
  var text = String(value || '');
  if (!text) {
    props.deleteProperty(name);
    return;
  }
  props.setProperty(name, text);
}

function normalizePhboxSingleLineSettingsValue_(value, fieldName, maxLength) {
  var text = String(value || '');
  if (/\r|\n/.test(text)) {
    throw new Error(fieldName + ' deve stare su una sola riga.');
  }
  if (text.length > Number(maxLength || 160)) {
    throw new Error(fieldName + ' troppo lungo.');
  }
  return text;
}

function normalizePhboxM1ShadowMaxScanForSettings_(value) {
  var text = String(value || '').trim();
  if (!text) return '';
  var parsed = parseInt(text, 10);
  if (isNaN(parsed) || parsed <= 0) {
    throw new Error('PHBOX_M1_SHADOW_MAX_ASSISTITI_SCAN deve essere un numero positivo.');
  }
  return String(Math.min(100, parsed));
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
  lines.push('M1_SHADOW_TARGET_ENABLED: ' + String(readPhboxSettingsBoolProperty_('PHBOX_M1_SHADOW_TARGET_ENABLED')));
  lines.push('M1_SHADOW_TENANT_ID: ' + readPhboxSettingsProperty_('PHBOX_TENANT_ID'));
  lines.push('M1_SHADOW_EXPECTED_CANONICAL_TENANT_ID: ' + readPhboxSettingsProperty_('PHBOX_EXPECTED_CANONICAL_TENANT_ID'));
  lines.push('M1_SHADOW_MAX_ASSISTITI_SCAN: ' + readPhboxSettingsProperty_('PHBOX_M1_SHADOW_MAX_ASSISTITI_SCAN'));
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
