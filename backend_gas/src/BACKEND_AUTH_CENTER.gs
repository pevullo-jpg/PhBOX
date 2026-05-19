function getPhboxBackendAuthCenterData() {
  return buildPhboxBackendAuthCenterResponse_(checkPhboxBackendHealth_({ persist: true }));
}

function runPhboxBackendAuthorizationCheck() {
  return buildPhboxBackendAuthCenterResponse_(checkPhboxBackendHealth_({ persist: true }));
}

function repairPhboxBackendMainTriggerFromAuthCenter() {
  var healthBefore = checkPhboxBackendHealth_({ persist: false, requireTrigger: false });
  if (!(healthBefore.operationalAccount && healthBefore.operationalAccount.ok)) {
    writePhboxBackendHealthSnapshot_(healthBefore);
    publishPhboxBackendAuthRuntimeSnapshot_(healthBefore, { source: 'auth_center_repair_trigger_blocked' });
    throw new Error('Account non valido: ' + String(healthBefore.operationalAccount && healthBefore.operationalAccount.message || 'KO'));
  }
  if (!(healthBefore.authorizations && healthBefore.authorizations.ok)) {
    writePhboxBackendHealthSnapshot_(healthBefore);
    publishPhboxBackendAuthRuntimeSnapshot_(healthBefore, { source: 'auth_center_repair_trigger_blocked' });
    throw new Error('Permessi backend non completi: ' + summarizePhboxHealthErrors_(healthBefore));
  }

  var trigger = reinstallPhboxMainTrigger_();
  var healthAfter = checkPhboxBackendHealth_({ persist: true });
  healthAfter.triggerInstall = trigger;
  writePhboxBackendHealthSnapshot_(healthAfter);
  publishPhboxBackendAuthRuntimeSnapshot_(healthAfter, { source: 'auth_center_repair_trigger' });
  return buildPhboxBackendAuthCenterResponse_(healthAfter);
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
