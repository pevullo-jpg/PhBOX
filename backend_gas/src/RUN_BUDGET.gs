function createRunBudget_(cfg, label) {
  cfg = cfg || getPhboxConfig_();
  return {
    label: label || 'PHBOX',
    startedAtMs: Date.now(),
    maxRuntimeMs: Math.max(30000, Number(cfg.maxRuntimeSeconds || 240) * 1000),
    reserveMs: 15000
  };
}

function remainingRunMillis_(budget) {
  if (!budget) return Number.MAX_SAFE_INTEGER;
  return budget.maxRuntimeMs - (Date.now() - budget.startedAtMs);
}

function shouldStopForBudget_(budget, reserveMs) {
  if (!budget) return false;
  return remainingRunMillis_(budget) <= Math.max(Number(reserveMs || 0), Number(budget.reserveMs || 0));
}

function describeBudgetState_(budget) {
  if (!budget) return { enabled: false };
  return {
    enabled: true,
    label: budget.label || 'PHBOX',
    elapsedMs: Date.now() - budget.startedAtMs,
    remainingMs: remainingRunMillis_(budget),
    reserveMs: budget.reserveMs || 0
  };
}
