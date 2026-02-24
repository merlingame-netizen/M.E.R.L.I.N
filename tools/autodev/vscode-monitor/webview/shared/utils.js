// utils.js — AUTODEV Monitor v3.0 shared utilities
// Loaded before panel.js and sidebar.js

function escapeHtml(str) {
  if (!str) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function truncate(str, maxLen) {
  if (!str) return '';
  if (str.length <= maxLen) return str;
  return str.substring(0, maxLen - 3) + '...';
}

function timeAgo(isoString) {
  if (!isoString) return '-';
  const diff = Date.now() - new Date(isoString).getTime();
  if (diff < 0) return 'just now';
  const secs = Math.floor(diff / 1000);
  if (secs < 60) return secs + 's ago';
  const mins = Math.floor(secs / 60);
  if (mins < 60) return mins + 'm ago';
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return hrs + 'h ago';
  return Math.floor(hrs / 24) + 'd ago';
}

function formatDuration(isoStart) {
  if (!isoStart) return '-';
  const ms = Date.now() - new Date(isoStart).getTime();
  if (ms < 0) return '-';
  const secs = Math.floor(ms / 1000);
  const mins = Math.floor(secs / 60);
  const hrs = Math.floor(mins / 60);
  if (hrs > 0) return hrs + 'h ' + (mins % 60) + 'm';
  if (mins > 0) return mins + 'm ' + (secs % 60) + 's';
  return secs + 's';
}

function clockTime() {
  const now = new Date();
  return String(now.getHours()).padStart(2, '0') + ':' + String(now.getMinutes()).padStart(2, '0');
}

function statusGlyph(status) {
  const map = {
    'in_progress': '\u25B6', // ▶
    'starting': '\u25B6',
    'done': '\u2713',        // ✓
    'merged': '\u2295',      // ⊕
    'error': '\u2717',       // ✗
    'unknown': '\u25CB',     // ○
    'idle': '\u25CB',
  };
  return map[status] || '\u25CB';
}

function statusBadgeClass(status) {
  const map = {
    'in_progress': 'badge-run',
    'starting': 'badge-run',
    'done': 'badge-done',
    'merged': 'badge-done',
    'error': 'badge-err',
    'unknown': 'badge-idle',
    'idle': 'badge-idle',
  };
  return map[status] || 'badge-idle';
}

function statusLabel(status) {
  const map = {
    'in_progress': 'RUN',
    'starting': 'START',
    'done': 'DONE',
    'merged': 'MERGED',
    'error': 'ERR',
    'unknown': '---',
    'idle': '---',
  };
  return map[status] || '---';
}

function decisionBadgeClass(decision) {
  const d = (decision || '').toUpperCase();
  if (d === 'PROCEED') return 'badge-proceed';
  if (d === 'ESCALATE') return 'badge-escalate';
  if (d === 'ROLLBACK') return 'badge-rollback';
  if (d === 'OVERRIDE') return 'badge-review';
  return 'badge-idle';
}

function priorityClass(priority) {
  return 'priority-' + (priority || 'medium');
}

function progressPercent(completed, remaining) {
  const done = (completed || []).length;
  const todo = (remaining || []).length;
  const total = done + todo;
  if (total === 0) return 0;
  return Math.round((done / total) * 100);
}

// VSCode API bridge
const vscode = (typeof acquireVsCodeApi !== 'undefined') ? acquireVsCodeApi() : null;

function postMessage(msg) {
  if (vscode) vscode.postMessage(msg);
}
