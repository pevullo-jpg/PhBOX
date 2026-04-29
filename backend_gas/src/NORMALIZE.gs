function normalizeCf_(value) {
  return String(value || '').replace(/\s+/g, '').trim().toUpperCase();
}

function normalizeToken_(value) {
  return String(value || '')
    .toUpperCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^A-Z0-9 ]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function normalizePersonName_(value) {
  var normalized = String(value || '')
    .replace(/[\t\r\n]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  if (!normalized) return '';
  return normalized
    .split(' ')
    .map(function (part) {
      if (!part) return '';
      return part.charAt(0).toUpperCase() + part.slice(1).toLowerCase();
    })
    .join(' ')
    .trim();
}

function safeIsoString_(date) {
  return date instanceof Date ? date.toISOString() : null;
}

function parseDateValue_(value) {
  if (!value) return null;
  if (Object.prototype.toString.call(value) === '[object Date]' && !isNaN(value.getTime())) {
    return value;
  }
  var text = String(value).trim();
  if (!text) return null;
  var iso = /^\d{4}-\d{2}-\d{2}$/;
  if (iso.test(text)) {
    var d1 = new Date(text + 'T00:00:00');
    return isNaN(d1.getTime()) ? null : d1;
  }
  var m = text.match(/\b([0-3]?\d)[\/\-.]([0-1]?\d)[\/\-.](\d{4})\b/);
  if (!m) return null;
  var day = parseInt(m[1], 10);
  var month = parseInt(m[2], 10);
  var year = parseInt(m[3], 10);
  var d2 = new Date(year, month - 1, day);
  if (isNaN(d2.getTime())) return null;
  if (d2.getFullYear() !== year || d2.getMonth() !== (month - 1) || d2.getDate() !== day) return null;
  return d2;
}

function formatDateIso_(date) {
  if (!(date instanceof Date) || isNaN(date.getTime())) return '';
  var y = date.getFullYear();
  var m = String(date.getMonth() + 1).padStart(2, '0');
  var d = String(date.getDate()).padStart(2, '0');
  return y + '-' + m + '-' + d;
}

function uniqueNonEmptyStrings_(items) {
  var out = [];
  var seen = {};
  (items || []).forEach(function (item) {
    var value = String(item || '').trim();
    if (!value) return;
    var key = value.toUpperCase();
    if (seen[key]) return;
    seen[key] = true;
    out.push(value);
  });
  return out;
}

function choosePreferredValue_(items) {
  for (var i = 0; i < (items || []).length; i++) {
    var value = String(items[i] || '').trim();
    if (value) return value;
  }
  return '';
}

function logInfo_(cfg, message, data) {
  if (!cfg || !cfg.verboseLogs) return;
  if (data === undefined) {
    Logger.log(message);
    return;
  }
  Logger.log(message + ' ' + JSON.stringify(data));
}
