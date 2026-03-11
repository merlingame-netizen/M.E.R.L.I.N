'use strict';

const cp = require('child_process');
const vscode = require('vscode');

/**
 * Tue un processus Windows via PowerShell Stop-Process.
 * @param {number} pid - PID du processus à tuer
 * @param {string} label - Nom lisible pour les messages (ex: "Google Chrome")
 * @param {string} rawName - Nom brut (ex: "chrome") pour info
 * @returns {Promise<boolean>} true si tué avec succès
 */
async function killProcess(pid, label, rawName) {
  const config = vscode.workspace.getConfiguration('taskSlayer');
  const confirmKill = config.get('confirmKill', true);

  if (confirmKill) {
    const answer = await vscode.window.showWarningMessage(
      `Tuer "${label}" (${rawName}, PID ${pid}) ?`,
      { modal: true },
      'Tuer'
    );
    if (answer !== 'Tuer') return false;
  }

  return new Promise((resolve) => {
    // parseInt pour prévenir toute injection dans la commande
    const safePid = parseInt(pid, 10);
    if (!safePid || safePid <= 0) {
      vscode.window.showErrorMessage(`PID invalide: ${pid}`);
      resolve(false);
      return;
    }

    cp.execFile(
      'powershell.exe',
      [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        `Stop-Process -Id ${safePid} -Force -ErrorAction Stop`
      ],
      { timeout: 8000 },
      (err) => {
        if (err) {
          const msg = err.message || String(err);
          if (msg.includes('Access') || msg.includes('access')) {
            vscode.window.showErrorMessage(
              `Accès refusé — "${label}" est un processus système protégé.`
            );
          } else if (msg.includes('not found') || msg.includes('Cannot find')) {
            vscode.window.showWarningMessage(
              `Processus "${label}" (PID ${safePid}) introuvable — déjà terminé ?`
            );
          } else {
            vscode.window.showErrorMessage(`Échec kill "${label}": ${msg.substring(0, 120)}`);
          }
          resolve(false);
        } else {
          vscode.window.showInformationMessage(
            `✓ Processus "${label}" (PID ${safePid}) terminé.`
          );
          resolve(true);
        }
      }
    );
  });
}

module.exports = { killProcess };
