'use strict';

const cp = require('child_process');

// PowerShell : récupère CPU% + RAM via WMI (données pré-calculées, pas de delta)
const PS_SCRIPT = `
$procs = Get-CimInstance Win32_PerfFormattedData_PerfProc_Process -ErrorAction Stop |
  Where-Object { $_.Name -ne '_Total' -and $_.Name -ne 'Idle' } |
  Select-Object @{N='name';E={$_.Name}},
                @{N='pid';E={$_.IDProcess}},
                @{N='cpu';E={$_.PercentProcessorTime}},
                @{N='mem';E={[math]::Round($_.WorkingSetPrivate / 1MB, 1)}}
$procs | ConvertTo-Json -Compress -Depth 2
`.trim();

// Timeout PowerShell en ms
const PS_TIMEOUT_MS = 15000;

// Nombre de cœurs CPU pour normalisation (évite >100% sur multi-core)
let CPU_CORES = 1;
try { CPU_CORES = require('os').cpus().length || 1; } catch (_) {}

/**
 * Agrège les entrées WMI du même processus de base (svchost#1, svchost#2 → svchost).
 * Somme le CPU, somme la RAM, garde le PID du plus gros consommateur.
 * @param {Array} rawList
 * @returns {Array}
 */
function aggregate(rawList) {
  /** @type {Map<string, {name:string, pid:number, cpu:number, mem:number}>} */
  const map = new Map();

  for (const p of rawList) {
    // Nom de base : supprimer suffixe #N (ex: svchost#3 → svchost)
    const baseName = String(p.name || '').replace(/#\d+$/, '').trim();
    if (!baseName) continue;

    const cpu = typeof p.cpu === 'number' ? p.cpu : parseFloat(p.cpu) || 0;
    const mem = typeof p.mem === 'number' ? p.mem : parseFloat(p.mem) || 0;
    const pid = typeof p.pid === 'number' ? p.pid : parseInt(p.pid, 10) || 0;

    if (map.has(baseName)) {
      const existing = map.get(baseName);
      existing.cpu += cpu;
      existing.mem += mem;
      // Garder le PID du plus gros consommateur CPU
      if (cpu > existing._maxCpu) {
        existing.pid = pid;
        existing._maxCpu = cpu;
      }
    } else {
      map.set(baseName, { name: baseName, pid, cpu, mem, _maxCpu: cpu });
    }
  }

  return Array.from(map.values()).map(({ _maxCpu, ...p }) => ({
    ...p,
    // Normaliser CPU sur nombre de cœurs (WMI peut donner >100% sur multi-core)
    cpu: Math.min(100, Math.round((p.cpu / CPU_CORES) * 10) / 10),
    mem: Math.round(p.mem * 10) / 10,
  }));
}

/**
 * Récupère la liste des processus Windows avec CPU% et RAM via PowerShell.
 * @param {number} maxProcesses - Nombre max à retourner (triés par CPU% desc)
 * @returns {Promise<Array<{name:string, pid:number, cpu:number, mem:number}>>}
 */
function getProcesses(maxProcesses = 50) {
  return new Promise((resolve) => {
    const child = cp.execFile(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-Command', PS_SCRIPT],
      { timeout: PS_TIMEOUT_MS, maxBuffer: 2 * 1024 * 1024 },
      (err, stdout, stderr) => {
        if (err) {
          console.error('[TaskSlayer] PowerShell error:', err.message);
          resolve([]);
          return;
        }

        const raw = (stdout || '').trim();
        if (!raw) {
          resolve([]);
          return;
        }

        let parsed;
        try {
          parsed = JSON.parse(raw);
        } catch (parseErr) {
          console.error('[TaskSlayer] JSON parse error:', parseErr.message);
          resolve([]);
          return;
        }

        // PowerShell retourne un objet unique (pas tableau) si 1 seul processus
        if (!parsed || typeof parsed !== 'object') {
          console.error('[TaskSlayer] Unexpected PowerShell output type:', typeof parsed);
          resolve([]);
          return;
        }
        const list = Array.isArray(parsed) ? parsed : [parsed];
        const aggregated = aggregate(list);

        // Trier par CPU% décroissant, limiter
        aggregated.sort((a, b) => b.cpu - a.cpu || b.mem - a.mem);
        resolve(aggregated.slice(0, maxProcesses));
      }
    );
  });
}

module.exports = { getProcesses };
