var PHBOX_CONFIG = {
  folderId: 'REPLACE_MAIN_FOLDER_ID',
  firestoreProjectId: 'REPLACE_FIRESTORE_PROJECT_ID',
  gmailProcessedLabel: 'PhBOX/processed',
  gmailRejectedLabel: 'PhBOX/rejected',
  manifestsFolderName: '_phbox_manifests',
  runtimeIndexFileName: 'runtime_index.json',
  acceptedCities: ['FAVARA', 'AGRIGENTO', 'GROTTE', 'RACALMUTO', 'COMITINI'],
  excludedEmailSenders: [],
  doctorReferenceNames: [],
  strictAcceptedCitiesForGmail: false,
  acceptRecipesWithoutCity: true,
  scanUnreadOnly: true,
  scanSpam: false,
  trashValidEmails: true,
  sourceType: 'script',
  maxFilesPerRun: 8,
  maxDriveScanFiles: 1000,
  maxMessagesPerRun: 15,
  maxBatchWrites: 60,
  maxMergeGroupsPerRun: 999,
  maxRuntimeSeconds: 240,
  scanSubfolders: true,
  verboseLogs: true,
  dashboardTotalsUseDebtAggregation: false,
  parserVersion: 18,
  mergedCfFolderName: '_phbox_merged_cf'
};

function getPhboxConfig_() {
  var cfg = readPhboxConfigFromProperties_();

  if (!cfg.folderId || cfg.folderId.indexOf('REPLACE_') === 0) {
    throw new Error('PHBOX_FOLDER_ID non configurato.');
  }
  if (!cfg.firestoreProjectId || cfg.firestoreProjectId.indexOf('REPLACE_') === 0) {
    throw new Error('PHBOX_FIRESTORE_PROJECT_ID non configurato.');
  }

  return cfg;
}

function readPhboxConfigFromProperties_() {
  var cfg = JSON.parse(JSON.stringify(PHBOX_CONFIG));
  var props = PropertiesService.getScriptProperties();

  cfg.folderId = props.getProperty('PHBOX_FOLDER_ID') || cfg.folderId;
  cfg.firestoreProjectId = props.getProperty('PHBOX_FIRESTORE_PROJECT_ID') || cfg.firestoreProjectId;
  cfg.gmailProcessedLabel = props.getProperty('PHBOX_GMAIL_LABEL') || cfg.gmailProcessedLabel;
  cfg.gmailRejectedLabel = props.getProperty('PHBOX_GMAIL_REJECTED_LABEL') || cfg.gmailRejectedLabel;
  cfg.manifestsFolderName = props.getProperty('PHBOX_MANIFESTS_FOLDER') || cfg.manifestsFolderName;
  cfg.runtimeIndexFileName = props.getProperty('PHBOX_RUNTIME_INDEX_FILE') || cfg.runtimeIndexFileName;
  cfg.sourceType = props.getProperty('PHBOX_SOURCE_TYPE') || cfg.sourceType;

  var cities = props.getProperty('PHBOX_ACCEPTED_CITIES');
  if (cities != null) {
    cfg.acceptedCities = parseNormalizedListProperty_(cities, function (item) {
      return normalizeToken_(item);
    });
  }

  var excludedSenders = props.getProperty('PHBOX_EXCLUDED_SENDERS');
  if (excludedSenders != null) {
    cfg.excludedEmailSenders = parseNormalizedListProperty_(excludedSenders, function (item) {
      return normalizeEmailSenderToken_(item);
    });
  }

  var doctorNames = props.getProperty('PHBOX_DOCTOR_REFERENCE_NAMES');
  if (doctorNames) {
    cfg.doctorReferenceNames = parseNormalizedListProperty_(doctorNames, function (item) {
      return normalizePersonName_(item);
    });
  }

  var strictCities = props.getProperty('PHBOX_STRICT_ACCEPTED_CITIES_FOR_GMAIL');
  if (strictCities != null) {
    cfg.strictAcceptedCitiesForGmail = /^true$/i.test(String(strictCities));
  }

  var acceptRecipesWithoutCity = props.getProperty('PHBOX_ACCEPT_RECIPES_WITHOUT_CITY');
  if (acceptRecipesWithoutCity != null) {
    cfg.acceptRecipesWithoutCity = /^true$/i.test(String(acceptRecipesWithoutCity));
  }

  var scanUnreadOnly = props.getProperty('PHBOX_SCAN_UNREAD_ONLY');
  if (scanUnreadOnly != null) {
    cfg.scanUnreadOnly = /^true$/i.test(String(scanUnreadOnly));
  }

  var scanSpam = props.getProperty('PHBOX_SCAN_SPAM');
  if (scanSpam != null) {
    cfg.scanSpam = /^true$/i.test(String(scanSpam));
  }

  var trashValidEmails = props.getProperty('PHBOX_TRASH_VALID_EMAILS');
  if (trashValidEmails != null) {
    cfg.trashValidEmails = /^true$/i.test(String(trashValidEmails));
  }

  var maxFilesPerRun = parseInt(props.getProperty('PHBOX_MAX_FILES_PER_RUN') || '', 10);
  if (!isNaN(maxFilesPerRun) && maxFilesPerRun > 0) cfg.maxFilesPerRun = maxFilesPerRun;

  var maxDriveScanFiles = parseInt(props.getProperty('PHBOX_MAX_DRIVE_SCAN_FILES') || '', 10);
  if (!isNaN(maxDriveScanFiles) && maxDriveScanFiles > 0) cfg.maxDriveScanFiles = maxDriveScanFiles;

  var maxMessagesPerRun = parseInt(props.getProperty('PHBOX_MAX_MESSAGES_PER_RUN') || '', 10);
  if (!isNaN(maxMessagesPerRun) && maxMessagesPerRun > 0) cfg.maxMessagesPerRun = maxMessagesPerRun;

  var maxBatchWrites = parseInt(props.getProperty('PHBOX_MAX_BATCH_WRITES') || '', 10);
  if (!isNaN(maxBatchWrites) && maxBatchWrites > 0) cfg.maxBatchWrites = maxBatchWrites;

  var maxMergeGroupsPerRun = parseInt(props.getProperty('PHBOX_MAX_MERGE_GROUPS_PER_RUN') || '', 10);
  if (!isNaN(maxMergeGroupsPerRun) && maxMergeGroupsPerRun > 0) cfg.maxMergeGroupsPerRun = maxMergeGroupsPerRun;

  var maxRuntimeSeconds = parseInt(props.getProperty('PHBOX_MAX_RUNTIME_SECONDS') || '', 10);
  if (!isNaN(maxRuntimeSeconds) && maxRuntimeSeconds > 0) cfg.maxRuntimeSeconds = maxRuntimeSeconds;

  var scanSubfolders = props.getProperty('PHBOX_SCAN_SUBFOLDERS');
  if (scanSubfolders != null) {
    cfg.scanSubfolders = /^true$/i.test(String(scanSubfolders));
  }

  var verboseLogs = props.getProperty('PHBOX_VERBOSE_LOGS');
  if (verboseLogs != null) {
    cfg.verboseLogs = /^true$/i.test(String(verboseLogs));
  }

  var dashboardTotalsUseDebtAggregation = props.getProperty('PHBOX_DASHBOARD_TOTALS_USE_DEBT_AGGREGATION');
  if (dashboardTotalsUseDebtAggregation != null) {
    cfg.dashboardTotalsUseDebtAggregation = /^true$/i.test(String(dashboardTotalsUseDebtAggregation));
  }

  var parserVersion = parseInt(props.getProperty('PHBOX_PARSER_VERSION') || '', 10);
  if (!isNaN(parserVersion) && parserVersion > 0) cfg.parserVersion = parserVersion;

  return cfg;
}

function parseNormalizedListProperty_(rawValue, normalizer) {
  return uniqueNonEmptyStrings_(String(rawValue || '')
    .split(/[\n\r,;]+/)
    .map(function (item) {
      var value = String(item || '').trim();
      if (!value) return '';
      return normalizer ? normalizer(value) : value;
    })
    .filter(function (item) { return item; }));
}

function normalizeEmailSenderToken_(value) {
  return String(value || '').trim().toLowerCase();
}
