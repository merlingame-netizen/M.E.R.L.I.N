'use strict';

const vscode = require('vscode');
const { getProcesses } = require('./process-service');
const { resolveProcess } = require('./process-dictionary');

/**
 * Formate une taille mémoire en MB ou GB lisible.
 * @param {number} mb - mégaoctets
 * @returns {string}
 */
function formatMem(mb) {
  if (mb >= 1024) return `${(mb / 1024).toFixed(1)} GB`;
  return `${mb.toFixed(0)} MB`;
}

/**
 * Retourne un ThemeIcon coloré selon le % CPU.
 * @param {number} cpu
 * @returns {vscode.ThemeIcon}
 */
function cpuIcon(cpu) {
  if (cpu >= 20) return new vscode.ThemeIcon('flame', new vscode.ThemeColor('charts.red'));
  if (cpu >= 5)  return new vscode.ThemeIcon('circle-filled', new vscode.ThemeColor('charts.orange'));
  if (cpu >= 1)  return new vscode.ThemeIcon('circle-filled', new vscode.ThemeColor('charts.yellow'));
  return new vscode.ThemeIcon('circle-outline', new vscode.ThemeColor('charts.green'));
}

/**
 * Item représentant un processus dans le TreeView.
 */
class ProcessItem extends vscode.TreeItem {
  /**
   * @param {{ name: string, pid: number, cpu: number, mem: number }} proc
   */
  constructor(proc) {
    const info = resolveProcess(proc.name);
    super(info.label, vscode.TreeItemCollapsibleState.None);

    this.description = `CPU: ${proc.cpu.toFixed(1)}%  RAM: ${formatMem(proc.mem)}`;
    this.tooltip = new vscode.MarkdownString(
      `**${info.label}**\n\n` +
      `- Processus : \`${proc.name}.exe\`\n` +
      `- PID : ${proc.pid}\n` +
      `- CPU : ${proc.cpu.toFixed(1)}%\n` +
      `- RAM : ${formatMem(proc.mem)}\n` +
      (info.desc ? `- Rôle : ${info.desc}\n` : '')
    );
    this.iconPath = cpuIcon(proc.cpu);
    this.contextValue = 'process';

    // Données attachées pour les commandes kill
    this.pid = proc.pid;
    this.processName = proc.name;
    this.processLabel = info.label;
  }
}

/**
 * Nœud d'état vide affiché quand la liste est vide ou en erreur.
 */
class StatusItem extends vscode.TreeItem {
  constructor(message, icon = 'info') {
    super(message, vscode.TreeItemCollapsibleState.None);
    this.iconPath = new vscode.ThemeIcon(icon);
    this.contextValue = 'status';
  }
}

/**
 * TreeDataProvider qui alimente la sidebar avec la liste des processus.
 */
class ProcessTreeProvider {
  constructor() {
    this._onDidChangeTreeData = new vscode.EventEmitter();
    /** @type {vscode.Event<undefined>} */
    this.onDidChangeTreeData = this._onDidChangeTreeData.event;
  }

  dispose() {
    this._onDidChangeTreeData.dispose();
  }

  /**
   * Déclenche un rechargement de la liste des processus.
   */
  refresh() {
    this._onDidChangeTreeData.fire(undefined);
  }

  /** @param {ProcessItem} element */
  getTreeItem(element) {
    return element;
  }

  /** @returns {Promise<vscode.TreeItem[]>} */
  async getChildren() {
    const config = vscode.workspace.getConfiguration('taskSlayer');
    const maxProcesses = config.get('maxProcesses', 50);

    let processes;
    try {
      processes = await getProcesses(maxProcesses);
    } catch (err) {
      console.error('[TaskSlayer] getChildren error:', err);
      return [new StatusItem('Erreur de récupération — voir console', 'error')];
    }

    if (!processes || processes.length === 0) {
      return [new StatusItem('Aucun processus récupéré — vérifier PowerShell', 'warning')];
    }

    return processes.map(p => new ProcessItem(p));
  }
}

module.exports = { ProcessTreeProvider };
