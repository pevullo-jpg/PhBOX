function doGet() {
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
    PHBOX_EXCLUDED_SENDERS: normalized.excludedEmailSenders.join('\n'),
    PHBOX_SCAN_UNREAD_ONLY: String(normalized.scanUnreadOnly),
    PHBOX_SCAN_SPAM: String(normalized.scanSpam),
    PHBOX_TRASH_VALID_EMAILS: String(normalized.trashValidEmails),
    PHBOX_ACCEPTED_CITIES: normalized.acceptedCities.join('\n'),
    PHBOX_ACCEPT_RECIPES_WITHOUT_CITY: String(normalized.acceptRecipesWithoutCity),
    PHBOX_STRICT_ACCEPTED_CITIES_FOR_GMAIL: String(normalized.acceptedCities.length > 0)
  }, false);

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
  if (!folderId) throw new Error('ID cartella root obbligatorio.');
  if (!firestoreProjectId) throw new Error('ID progetto obbligatorio.');

  return {
    folderId: folderId,
    firestoreProjectId: firestoreProjectId,
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
  lines.push('SCAN_UNREAD_ONLY: ' + String(!!cfg.scanUnreadOnly));
  lines.push('SCAN_SPAM: ' + String(!!cfg.scanSpam));
  lines.push('TRASH_VALID_EMAILS: ' + String(!!cfg.trashValidEmails));
  lines.push('EXCLUDED_SENDERS_COUNT: ' + String((cfg.excludedEmailSenders || []).length));
  lines.push('ACCEPTED_CITIES_COUNT: ' + String((cfg.acceptedCities || []).length));
  lines.push('ACCEPT_RECIPES_WITHOUT_CITY: ' + String(!!cfg.acceptRecipesWithoutCity));
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
