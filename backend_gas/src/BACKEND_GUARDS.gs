function assertBackendReadyForRun_(options) {
  options = options || {};
  var cfg = getPhboxConfig_();
  validateBackendConfigOrThrow_(cfg, options);

  var auth = diagnosePhboxAuthorizations_(options);
  if (auth.driveOcr && auth.driveOcr.ok === false) {
    throw new Error('Autorizzazione backend bloccata in OCR/Drive: ' + auth.driveOcr.message);
  }
  if (auth.firestore && auth.firestore.ok === false) {
    throw new Error('Autorizzazione backend bloccata in Firestore: ' + auth.firestore.message);
  }
  if (auth.gmail && auth.gmail.ok === false) {
    throw new Error('Autorizzazione backend bloccata in Gmail: ' + auth.gmail.message);
  }
  return auth;
}

function validateBackendConfigOrThrow_(cfg, options) {
  options = options || {};
  if (!cfg) throw new Error('Configurazione backend assente.');

  if (!cfg.folderId || /^REPLACE_/i.test(String(cfg.folderId))) {
    throw new Error('Configurazione non valida: PHBOX_FOLDER_ID mancante o placeholder.');
  }
  if (!options.skipFirestore && (!cfg.firestoreProjectId || /^REPLACE_/i.test(String(cfg.firestoreProjectId)))) {
    throw new Error('Configurazione non valida: PHBOX_FIRESTORE_PROJECT_ID mancante o placeholder.');
  }

  try {
    DriveApp.getFolderById(cfg.folderId).getName();
  } catch (e) {
    throw new Error('Cartella Drive principale non accessibile: ' + normalizeRuntimeErrorMessage_(e));
  }
}

function diagnosePhboxAuthorizations() {
  return diagnosePhboxAuthorizations_({
    includeDriveOcrProbe: true,
    includeFirestoreProbe: true,
    includeGmailProbe: true
  });
}



function installPhboxTenant() {
  var accountGuard = assertPhboxOperationalAccountForInstaller_();
  var cfg = getPhboxConfig_();
  var health = checkPhboxBackendHealth_({ persist: false, requireTrigger: false });
  if (!health.ok) {
    writePhboxBackendHealthSnapshot_(health);
    throw new Error('Installazione PhBOX bloccata: health-check non OK. ' + summarizePhboxHealthErrors_(health));
  }

  var trigger = reinstallPhboxMainTrigger_();
  health.trigger = getPhboxMainTriggerStatus_();
  health.ok = !!(health.operationalAccount && health.operationalAccount.ok && health.authorizations && health.authorizations.ok && health.trigger && health.trigger.ok);
  health.installed = true;
  health.installedAt = new Date().toISOString();
  health.installerAccount = accountGuard;
  health.triggerInstall = trigger;
  writePhboxBackendHealthSnapshot_(health);

  logInfo_(cfg, 'installPhboxTenant completato', {
    ok: true,
    trigger: trigger,
    healthOk: health.ok
  });

  return health;
}

function checkPhboxBackendHealth() {
  return checkPhboxBackendHealth_({ persist: true });
}

function checkPhboxBackendHealth_(options) {
  options = options || {};
  var cfg = getPhboxConfig_();
  var operationalAccount = getPhboxOperationalAccountStatus_();
  var health = {
    ok: true,
    checkedAt: new Date().toISOString(),
    operationalAccount: operationalAccount,
    config: {
      folderIdConfigured: !!cfg.folderId && !/^REPLACE_/i.test(String(cfg.folderId)),
      firestoreProjectIdConfigured: !!cfg.firestoreProjectId && !/^REPLACE_/i.test(String(cfg.firestoreProjectId)),
      gmailProcessedLabel: cfg.gmailProcessedLabel || '',
      gmailRejectedLabel: cfg.gmailRejectedLabel || ''
    },
    authorizations: diagnosePhboxAuthorizations_({
      includeDriveOcrProbe: true,
      includeFirestoreProbe: true,
      includeGmailProbe: true
    }),
    trigger: getPhboxMainTriggerStatus_()
  };

  var requireTrigger = options.requireTrigger !== false;
  health.ok = !!(health.operationalAccount && health.operationalAccount.ok && health.authorizations && health.authorizations.ok && (!requireTrigger || (health.trigger && health.trigger.ok)));
  if (options.persist !== false) {
    writePhboxBackendHealthSnapshot_(health);
  }
  return health;
}

function reinstallPhboxMainTrigger_() {
  assertPhboxOperationalAccountForInstaller_();
  var intervalMinutes = readPhboxMainTriggerIntervalMinutes_();
  var triggers = ScriptApp.getProjectTriggers();
  var deleted = 0;

  triggers.forEach(function (trigger) {
    if (trigger && trigger.getHandlerFunction && trigger.getHandlerFunction() === 'runPhboxBackendSimple') {
      ScriptApp.deleteTrigger(trigger);
      deleted++;
    }
  });

  var created = ScriptApp.newTrigger('runPhboxBackendSimple')
    .timeBased()
    .everyMinutes(intervalMinutes)
    .create();

  return {
    ok: true,
    functionName: 'runPhboxBackendSimple',
    intervalMinutes: intervalMinutes,
    deletedExistingTriggers: deleted,
    createdTriggerUid: created && created.getUniqueId ? created.getUniqueId() : ''
  };
}

function getPhboxMainTriggerStatus_() {
  var intervalMinutes = readPhboxMainTriggerIntervalMinutes_();
  var triggers = ScriptApp.getProjectTriggers();
  var matches = [];

  triggers.forEach(function (trigger) {
    if (!trigger || !trigger.getHandlerFunction || trigger.getHandlerFunction() !== 'runPhboxBackendSimple') return;
    matches.push({
      functionName: trigger.getHandlerFunction(),
      source: trigger.getTriggerSource ? String(trigger.getTriggerSource()) : '',
      eventType: trigger.getEventType ? String(trigger.getEventType()) : '',
      uniqueId: trigger.getUniqueId ? trigger.getUniqueId() : ''
    });
  });

  return {
    ok: matches.length === 1,
    functionName: 'runPhboxBackendSimple',
    expectedIntervalMinutes: intervalMinutes,
    triggerCount: matches.length,
    duplicateTriggers: Math.max(0, matches.length - 1),
    triggers: matches
  };
}

function readPhboxMainTriggerIntervalMinutes_() {
  var raw = PropertiesService.getScriptProperties().getProperty('PHBOX_MAIN_TRIGGER_INTERVAL_MINUTES');
  var value = parseInt(raw || '5', 10);
  var allowed = [1, 5, 10, 15, 30];
  if (allowed.indexOf(value) === -1) return 5;
  return value;
}

function readPhboxOperationalAccountEmail_() {
  var raw = PropertiesService.getScriptProperties().getProperty('PHBOX_OPERATIONAL_ACCOUNT_EMAIL');
  return String(raw || '').trim().toLowerCase();
}

function getPhboxExecutingAccountEmail_() {
  try {
    return String(Session.getEffectiveUser().getEmail() || '').trim().toLowerCase();
  } catch (e) {
    return '';
  }
}

function getPhboxOperationalAccountStatus_() {
  var expectedEmail = readPhboxOperationalAccountEmail_();
  var executingEmail = getPhboxExecutingAccountEmail_();
  var configured = !!expectedEmail;
  var visible = !!executingEmail;
  var matches = configured && visible && executingEmail === expectedEmail;
  return {
    ok: matches,
    configured: configured,
    executingEmailVisible: visible,
    expectedEmail: expectedEmail,
    executingEmail: executingEmail,
    message: matches
      ? 'OK'
      : (!configured
        ? 'PHBOX_OPERATIONAL_ACCOUNT_EMAIL non configurata.'
        : (!visible
          ? 'Account esecutore non determinabile da Session.getEffectiveUser().'
          : "Account esecutore diverso dall'account operativo configurato."))
  };
}

function assertPhboxOperationalAccountForInstaller_() {
  var status = getPhboxOperationalAccountStatus_();
  if (!status.ok) {
    throw new Error('Installazione PhBOX bloccata: ' + status.message);
  }
  return status;
}

function writePhboxBackendHealthSnapshot_(health) {
  PropertiesService.getScriptProperties().setProperty(
    'PHBOX_BACKEND_HEALTH_LAST_JSON',
    JSON.stringify(health || {})
  );
}

function summarizePhboxHealthErrors_(health) {
  health = health || {};
  var messages = [];
  if (health.operationalAccount && health.operationalAccount.ok === false) {
    messages.push('operationalAccount: ' + String(health.operationalAccount.message || 'KO'));
  }
  var auth = health.authorizations || {};
  Object.keys(auth).forEach(function (key) {
    if (key === 'ok' || key === 'checkedAt') return;
    if (auth[key] && auth[key].ok === false) {
      messages.push(key + ': ' + String(auth[key].message || 'KO'));
    }
  });
  if (health.trigger && health.trigger.ok === false) {
    messages.push('trigger: count=' + String(health.trigger.triggerCount || 0));
  }
  return messages.join(' | ') || 'errore non specificato';
}

function diagnosePhboxAuthorizations_(options) {
  options = options || {};
  var cfg = getPhboxConfig_();
  var out = {
    ok: true,
    checkedAt: new Date().toISOString()
  };

  out.config = probeAuthorizationStep_(function () {
    validateBackendConfigOrThrow_(cfg, options);
    return {
      folderId: cfg.folderId,
      firestoreProjectId: options.skipFirestore ? '(skip)' : cfg.firestoreProjectId
    };
  });

  if (options.includeDriveOcrProbe !== false && !options.skipDriveOcrProbe) {
    out.driveOcr = probeAuthorizationStep_(function () {
      return probeDriveOcrAuthorization_();
    });
  }

  if (!options.skipFirestore && options.includeFirestoreProbe !== false) {
    out.firestore = probeAuthorizationStep_(function () {
      return probeFirestoreAuthorization_(cfg);
    });
  }

  if (!options.skipGmail && options.includeGmailProbe) {
    out.gmail = probeAuthorizationStep_(function () {
      return probeGmailAuthorization_(cfg);
    });
  }

  out.ok = Object.keys(out).every(function (key) {
    if (key === 'ok' || key === 'checkedAt') return true;
    return !out[key] || out[key].ok !== false;
  });

  return out;
}

function probeAuthorizationStep_(fn) {
  try {
    var detail = fn();
    return {
      ok: true,
      message: 'OK',
      detail: detail || null
    };
  } catch (e) {
    return {
      ok: false,
      message: normalizeRuntimeErrorMessage_(e),
      detail: {
        kind: classifyRuntimeFailureKind_(e)
      }
    };
  }
}

function probeDriveOcrAuthorization_() {
  if (typeof Drive === 'undefined' || !Drive.Files || !Drive.Files.create) {
    throw new Error('Servizio avanzato Drive non disponibile nel progetto Apps Script.');
  }

  var tempFile = null;
  try {
    tempFile = Drive.Files.create({
      name: 'PHBOX_AUTH_PROBE_' + Date.now(),
      mimeType: MimeType.GOOGLE_DOCS
    }, Utilities.newBlob('PHBOX AUTH PROBE', MimeType.PLAIN_TEXT, 'phbox_auth_probe.txt'));

    var docId = tempFile && tempFile.id;
    if (!docId) {
      throw new Error('Drive.Files.create non ha restituito un docId valido.');
    }

    var doc = DocumentApp.openById(docId);
    var text = doc.getBody().getText() || '';
    return {
      docId: docId,
      textLength: text.length
    };
  } catch (e) {
    throw new Error('Probe OCR/Drive fallita: ' + normalizeRuntimeErrorMessage_(e));
  } finally {
    if (tempFile && tempFile.id) {
      try {
        DriveApp.getFileById(tempFile.id).setTrashed(true);
      } catch (_) {}
    }
  }
}

function probeFirestoreAuthorization_(cfg) {
  var url = 'https://firestore.googleapis.com/v1/projects/' + encodeURIComponent(cfg.firestoreProjectId) + '/databases/(default)/documents:runQuery';
  var response = UrlFetchApp.fetch(url, {
    method: 'post',
    muteHttpExceptions: true,
    contentType: 'application/json',
    headers: {
      Authorization: 'Bearer ' + ScriptApp.getOAuthToken()
    },
    payload: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: '_phbox_healthcheck' }],
        limit: 1
      }
    })
  });

  var code = response.getResponseCode();
  var body = response.getContentText() || '';
  if (code >= 200 && code < 300) {
    return {
      responseCode: code
    };
  }
  throw new Error('Probe Firestore fallita [' + code + '] ' + body);
}

function probeGmailAuthorization_(cfg) {
  var labelName = cfg && cfg.gmailProcessedLabel ? cfg.gmailProcessedLabel : 'PhBOX/processed';
  var label = GmailApp.getUserLabelByName(labelName);
  return {
    labelExists: !!label,
    unreadInbox: GmailApp.getInboxUnreadCount()
  };
}

function shouldAbortManifestCreationForError_(error) {
  var kind = classifyRuntimeFailureKind_(error);
  return kind !== 'content_or_parser';
}

function isRetryableRuntimeFailure_(error) {
  return classifyRuntimeFailureKind_(error) === 'transient';
}

function runWithRetryOnTransient_(fn, options) {
  options = options || {};
  var attempts = Math.max(1, Number(options.attempts || 1));
  var baseSleepMs = Math.max(0, Number(options.baseSleepMs || 0));
  var lastError = null;

  for (var i = 0; i < attempts; i++) {
    try {
      return fn();
    } catch (e) {
      lastError = e;
      if (!isRetryableRuntimeFailure_(e) || i >= attempts - 1) {
        throw e;
      }
      if (baseSleepMs > 0) {
        Utilities.sleep(baseSleepMs * Math.pow(2, i));
      }
    }
  }

  throw lastError || new Error('runWithRetryOnTransient_ failed without explicit error');
}

function classifyRuntimeFailureKind_(error) {
  var message = normalizeRuntimeErrorMessage_(error).toUpperCase();

  if (!message) return 'unknown';
  if (/PLACEHOLDER|PHBOX_FOLDER_ID|PHBOX_FIRESTORE_PROJECT_ID|CONFIGURAZIONE NON VALIDA/.test(message)) return 'config';
  if (/URLFETCH|TIMED OUT|SERVICE UNAVAILABLE|INTERNAL ERROR|TRY AGAIN LATER|RATE LIMIT|TOO MANY REQUESTS|BANDWIDTH QUOTA EXCEEDED|QUOTA EXCEEDED|429|503|504|BACKEND ERROR|SERVICE ERROR:\s*DRIVE|DRIVE SERVICE ERROR/.test(message)) return 'transient';
  if (/NO ITEM WITH THE GIVEN ID COULD BE FOUND|YOU DO NOT HAVE PERMISSION TO ACCESS IT|YOU HAVE NOT EDITED THIS ITEM|CARTELLA DRIVE PRINCIPALE NON ACCESSIBILE|REQUESTED ENTITY WAS NOT FOUND|FILE NOT FOUND|DOCUMENT IS MISSING|NOT FOUND/.test(message)) return 'resource_access';
  if (/AUTHORIZATION|AUTORIZZAZIONE|UNAUTHENTICATED|INSUFFICIENT|PERMISSION|PERMESS|SCOPE|ACCESS NOT CONFIGURED|API HAS NOT BEEN USED|DISABLED|FORBIDDEN|LOGIN REQUIRED/.test(message)) return 'authorization';
  if (/FIRESTORE PATCH FAILED|PROBE FIRESTORE FALLITA|FIRESTORE/.test(message)) return 'firestore';
  if (/CODICE FISCALE NON TROVATO|PARSER|PARSE/.test(message)) return 'content_or_parser';
  return 'unknown';
}

function normalizeRuntimeErrorMessage_(error) {
  if (!error) return '';
  if (typeof error === 'string') return error;
  if (error && error.message) return String(error.message);
  return String(error);
}
