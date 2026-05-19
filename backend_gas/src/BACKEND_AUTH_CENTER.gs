function getPhboxBackendAuthCenterData() {
  return runPhboxAuthCenterHealthCheckSafely_({ persist: true });
}

function runPhboxBackendAuthorizationCheck() {
  return runPhboxAuthCenterHealthCheckSafely_({ persist: true });
}

function runPhboxAuthCenterHealthCheckSafely_(options) {
  try {
    return buildPhboxBackendAuthCenterResponse_(checkPhboxBackendHealth_(options || {}));
  } catch (e) {
    var health = buildPhboxAuthCenterHealthFromFailure_(e, {
      source: 'auth_center_health_check_failure'
    });
    persistPhboxAuthCenterHealthBestEffort_(health, { source: 'auth_center_health_check_failure' });
    return buildPhboxBackendAuthCenterResponse_(health);
  }
}

function repairPhboxBackendMainTriggerFromAuthCenter() {
  var healthBefore = null;
  try {
    healthBefore = checkPhboxBackendHealth_({ persist: false, requireTrigger: false });
  } catch (e) {
    healthBefore = buildPhboxAuthCenterHealthFromFailure_(e, {
      source: 'auth_center_repair_trigger_health_before_failure'
    });
    persistPhboxAuthCenterHealthBestEffort_(healthBefore, { source: 'auth_center_repair_trigger_blocked' });
    return buildPhboxBackendAuthCenterResponse_(healthBefore);
  }
  if (!(healthBefore.operationalAccount && healthBefore.operationalAccount.ok)) {
    persistPhboxAuthCenterHealthBestEffort_(healthBefore, { source: 'auth_center_repair_trigger_blocked' });
    return buildPhboxBackendAuthCenterResponse_(healthBefore);
  }
  if (!(healthBefore.authorizations && healthBefore.authorizations.ok)) {
    persistPhboxAuthCenterHealthBestEffort_(healthBefore, { source: 'auth_center_repair_trigger_blocked' });
    return buildPhboxBackendAuthCenterResponse_(healthBefore);
  }

  var trigger = null;
  try {
    trigger = reinstallPhboxMainTrigger_();
  } catch (e) {
    var healthInstallFailure = buildPhboxAuthCenterHealthFromFailure_(e, {
      source: 'auth_center_repair_trigger_install_failure'
    });
    healthInstallFailure.triggerInstall = {
      ok: false,
      message: normalizeRuntimeErrorMessage_(e),
      kind: classifyRuntimeFailureKind_(e)
    };
    persistPhboxAuthCenterHealthBestEffort_(healthInstallFailure, { source: 'auth_center_repair_trigger_install_failure' });
    return buildPhboxBackendAuthCenterResponse_(healthInstallFailure);
  }

  var healthAfter = null;
  try {
    healthAfter = checkPhboxBackendHealth_({ persist: true });
  } catch (e) {
    healthAfter = buildPhboxAuthCenterHealthFromFailure_(e, {
      source: 'auth_center_repair_trigger_health_after_failure'
    });
  }
  healthAfter.triggerInstall = trigger;
  persistPhboxAuthCenterHealthBestEffort_(healthAfter, { source: 'auth_center_repair_trigger' });
  return buildPhboxBackendAuthCenterResponse_(healthAfter);
}

function buildPhboxAuthCenterHealthFromFailure_(error, options) {
  options = options || {};
  var message = normalizeRuntimeErrorMessage_(error);
  var kind = classifyRuntimeFailureKind_(error);
  var health = {
    ok: false,
    checkedAt: new Date().toISOString(),
    operationalAccount: {},
    authorizations: {
      ok: false,
      checkedAt: new Date().toISOString(),
      runtimeFailure: {
        ok: false,
        message: message,
        detail: {
          kind: kind,
          source: String(options.source || '').trim()
        }
      }
    },
    trigger: {}
  };

  try {
    health.operationalAccount = getPhboxOperationalAccountStatus_();
  } catch (accountError) {
    health.operationalAccount = {
      ok: false,
      configured: false,
      message: normalizeRuntimeErrorMessage_(accountError)
    };
  }

  try {
    health.trigger = getPhboxMainTriggerStatus_();
  } catch (triggerError) {
    health.trigger = {
      ok: false,
      triggerCount: 0,
      message: normalizeRuntimeErrorMessage_(triggerError)
    };
  }

  return health;
}

function buildPhboxBackendAuthCenterResponse_(health) {
  health = health || {};
  return {
    ok: !!health.ok,
    auth: buildPhboxBackendAuthState_(health),
    health: sanitizePhboxBackendHealthForUi_(health),
    checkedAt: health.checkedAt || new Date().toISOString()
  };
}

function persistPhboxAuthCenterHealthBestEffort_(health, options) {
  options = options || {};
  try {
    writePhboxBackendHealthSnapshot_(health);
  } catch (snapshotError) {
    Logger.log('auth_center_health_snapshot_failed ' + normalizeRuntimeErrorMessage_(snapshotError));
  }
  try {
    publishPhboxBackendAuthRuntimeSnapshot_(health, {
      source: String(options.source || '').trim() || 'auth_center_best_effort'
    });
  } catch (publishError) {
    Logger.log('auth_center_runtime_publish_failed ' + normalizeRuntimeErrorMessage_(publishError));
  }
}

function sanitizePhboxBackendHealthForUi_(health) {
  health = health || {};
  return {
    ok: !!health.ok,
    checkedAt: health.checkedAt || '',
    operationalAccount: health.operationalAccount || {},
    authorizations: health.authorizations || {},
    trigger: health.trigger || {},
    summary: summarizePhboxHealthErrors_(health)
  };
}
