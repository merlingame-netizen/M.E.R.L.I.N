'use strict';

const vscode = require('vscode');
const { ProcessTreeProvider } = require('./src/process-provider');
const { killProcess } = require('./src/process-killer');

/** @type {NodeJS.Timeout | null} */
let _refreshTimer = null;
/** @type {ProcessTreeProvider | null} */
let _provider = null;
/** @type {boolean} */
let _autoRefreshEnabled = true;

/**
 * Démarre le timer d'auto-refresh selon la configuration.
 */
function startTimer() {
  stopTimer();
  const config = vscode.workspace.getConfiguration('taskSlayer');
  _autoRefreshEnabled = config.get('autoRefresh', true);
  if (!_autoRefreshEnabled || !_provider) return;

  const intervalSec = Math.max(1, config.get('refreshInterval', 5));
  _refreshTimer = setInterval(() => {
    if (_provider) _provider.refresh();
  }, intervalSec * 1000);
}

function stopTimer() {
  if (_refreshTimer !== null) {
    clearInterval(_refreshTimer);
    _refreshTimer = null;
  }
}

/**
 * @param {vscode.ExtensionContext} context
 */
function activate(context) {
  _provider = new ProcessTreeProvider();

  const treeView = vscode.window.createTreeView('taskSlayer.processList', {
    treeDataProvider: _provider,
    showCollapseAll: false,
  });

  // ── Commande : rafraîchir manuellement ──
  const cmdRefresh = vscode.commands.registerCommand('taskSlayer.refresh', () => {
    if (_provider) _provider.refresh();
  });

  // ── Commande : tuer un processus ──
  const cmdKill = vscode.commands.registerCommand('taskSlayer.kill', async (item) => {
    if (!item || !item.pid) {
      vscode.window.showWarningMessage('Sélectionnez un processus dans la liste.');
      return;
    }
    const killed = await killProcess(item.pid, item.processLabel, item.processName);
    if (killed) {
      // Rafraîchir immédiatement après un kill réussi
      setTimeout(() => _provider && _provider.refresh(), 800);
    }
  });

  // ── Commande : toggle auto-refresh ──
  const cmdToggle = vscode.commands.registerCommand('taskSlayer.toggleAutoRefresh', () => {
    const config = vscode.workspace.getConfiguration('taskSlayer');
    const current = config.get('autoRefresh', true);
    config.update('autoRefresh', !current, vscode.ConfigurationTarget.Global).then(() => {
      const state = !current ? 'activé' : 'désactivé';
      vscode.window.showInformationMessage(`Task Slayer : auto-refresh ${state}.`);
    });
  });

  // ── Réagir aux changements de config ──
  const configWatcher = vscode.workspace.onDidChangeConfiguration((e) => {
    if (
      e.affectsConfiguration('taskSlayer.autoRefresh') ||
      e.affectsConfiguration('taskSlayer.refreshInterval')
    ) {
      startTimer();
    }
  });

  // ── Démarrer le timer initial ──
  startTimer();

  context.subscriptions.push(
    treeView,
    cmdRefresh,
    cmdKill,
    cmdToggle,
    configWatcher,
    _provider,
    { dispose: stopTimer }
  );
}

function deactivate() {
  stopTimer();
  _provider = null;
}

module.exports = { activate, deactivate };
