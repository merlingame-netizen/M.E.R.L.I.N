import { defineConfig, type Plugin } from 'vite';
import react from '@vitejs/plugin-react';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { spawn, type ChildProcess } from 'node:child_process';

/**
 * Find the Godot binary across known locations. Mirrors the candidate list from
 * tools/adapters/godot_adapter.py:_GODOT_CANDIDATES. Override via GODOT_BIN env var.
 * Uses os.homedir() pour ne pas leaker le username dans le source (review LOW).
 * Returns the first existing absolute path, or 'godot' as last-resort PATH fallback.
 */
function findGodotBin(): string | null {
  const envOverride = process.env.GODOT_BIN;
  if (envOverride && fs.existsSync(envOverride)) return envOverride;
  const home = os.homedir();
  const candidates: string[] = [
    path.join(home, 'Godot', 'Godot_v4.5.1-stable_win64_console.exe'),
    path.join(home, 'AppData', 'Local', 'Programs', 'Godot', 'Godot.exe'),
    path.join(home, 'AppData', 'Local', 'Programs', 'Godot', 'godot.exe'),
  ];
  for (const c of candidates) {
    if (fs.existsSync(c)) return c;
  }
  // Last resort: rely on PATH (spawn will error if not found)
  return process.platform === 'win32' ? 'godot.exe' : 'godot';
}

/**
 * Module-scope singleton tracker for the Godot subprocess spawned via /api/godot/launch.
 * One Vite dev server = one tracked Godot at a time. detached + unref → survives Vite restart
 * but we lose the handle (then UI shows "not running" until next launch).
 * `godotLaunching` est un flag synchrone qui ferme la race entre alive-check et spawn (review MEDIUM #1).
 */
let godotChild: ChildProcess | null = null;
let godotPid: number | null = null;
let godotLaunching: boolean = false;

/**
 * Resolve the Godot 4 user-data directory for the MERLIN project across platforms.
 * Used by godotBridgePlugin to read/write the dashboard live state + tweaks files.
 */
function godotUserDir(): string {
  const projectName = 'MERLIN';
  if (process.platform === 'win32') {
    const appData = process.env.APPDATA ?? path.join(os.homedir(), 'AppData', 'Roaming');
    return path.join(appData, 'Godot', 'app_userdata', projectName);
  }
  if (process.platform === 'darwin') {
    return path.join(os.homedir(), 'Library', 'Application Support', 'Godot', 'app_userdata', projectName);
  }
  return path.join(os.homedir(), '.local', 'share', 'godot', 'app_userdata', projectName);
}

interface ScenarioCorpusItem {
  id?: string;
  title?: string;
  archetype_id?: string;
  archetype_name?: string;
  pole_dominant?: string;
  length?: number;
}

interface ScenarioSlim {
  id: string;
  title: string;
  archetype_id: string;
  archetype_name: string;
  pole_dominant: string;
  length: number;
}

/**
 * v10 Dashboard Gameplay Live — local-dev bridge between mission-control React UI and the running
 * Godot editor (user 2026-05-31 /goal). Exposes 3 routes under /api/godot/* served ONLY by the Vite
 * dev server (port 4200) — Vercel deploys ignore this. Pure file I/O on the Godot user-data dir:
 *   - GET  /api/godot/state     → returns dashboard_state.json (written by TweaksOverlay every 1 s)
 *   - GET  /api/godot/tweaks    → returns merlin_tweaks.json (or empty {} if absent)
 *   - POST /api/godot/tweaks    → writes merlin_tweaks.json (full replace, hot-reloaded by Godot ≤500 ms)
 *   - GET  /api/godot/scenarios → slim listing of the 130 Brocéliande corpus scenarios (id/title/pole)
 */
function godotBridgePlugin(): Plugin {
  return {
    name: 'godot-bridge-local',
    configureServer(server) {
      const dir = godotUserDir();
      const corpusPath = path.join(os.homedir(), 'Downloads', 'broceliande_scenarios_v7.7.22.json');

      const sendJson = (res: any, code: number, body: unknown): void => {
        res.statusCode = code;
        res.setHeader('Content-Type', 'application/json');
        res.setHeader('Cache-Control', 'no-store');
        res.end(JSON.stringify(body));
      };

      server.middlewares.use('/api/godot/state', (_req, res) => {
        try {
          const fp = path.join(dir, 'dashboard_state.json');
          if (!fs.existsSync(fp)) {
            sendJson(res, 200, { ok: false, error: 'Godot pas en cours d\'exécution (ou TweaksOverlay pas encore actif)', state: null, dir });
            return;
          }
          // Auto-healing : si mtime > 5s, Godot est probablement arrêté/crashé mais a laissé un
          // fichier zombie (taskkill /T met du temps à libérer + Godot peut écrire en agonie).
          // On nettoie et on retourne comme absent. (playtester MEDIUM 2026-06-05 — defense in depth
          // par-dessus le cleanup de /stop)
          const stat = fs.statSync(fp);
          const ageMs = Date.now() - stat.mtimeMs;
          if (ageMs > 5000) {
            try { fs.unlinkSync(fp); } catch { /* best-effort */ }
            sendJson(res, 200, { ok: false, error: `État stale (${Math.round(ageMs / 1000)}s) — Godot probablement arrêté`, state: null, dir, stale_age_ms: ageMs });
            return;
          }
          const raw = fs.readFileSync(fp, 'utf-8');
          sendJson(res, 200, { ok: true, state: JSON.parse(raw), age_ms: ageMs });
        } catch (err: unknown) {
          const msg = err instanceof Error ? err.message : 'Unknown error';
          sendJson(res, 500, { ok: false, error: msg });
        }
      });

      server.middlewares.use('/api/godot/tweaks', (req, res) => {
        const fp = path.join(dir, 'merlin_tweaks.json');
        if (req.method === 'GET') {
          try {
            const raw = fs.existsSync(fp) ? fs.readFileSync(fp, 'utf-8') : '{}';
            sendJson(res, 200, { ok: true, tweaks: JSON.parse(raw) });
          } catch (err: unknown) {
            const msg = err instanceof Error ? err.message : 'Unknown error';
            sendJson(res, 500, { ok: false, error: msg });
          }
          return;
        }
        if (req.method === 'POST') {
          let body = '';
          let aborted = false;
          const MAX_BODY = 512_000;  // 512 KB cap — protège contre l'épuisement mémoire local
          req.on('data', (chunk: Buffer) => {
            if (aborted) return;
            if (body.length + chunk.length > MAX_BODY) {
              aborted = true;
              sendJson(res, 413, { ok: false, error: `Body exceeds ${MAX_BODY} bytes` });
              req.destroy();
              return;
            }
            body += chunk.toString('utf-8');
          });
          req.on('end', () => {
            if (aborted) return;
            try {
              const parsed: unknown = JSON.parse(body || '{}');
              if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
              fs.writeFileSync(fp, JSON.stringify(parsed, null, 2), 'utf-8');
              sendJson(res, 200, { ok: true, written: fp });
            } catch (err: unknown) {
              const msg = err instanceof Error ? err.message : 'Unknown error';
              sendJson(res, 400, { ok: false, error: msg });
            }
          });
          return;
        }
        sendJson(res, 405, { ok: false, error: 'Method not allowed' });
      });

      // POST /api/godot/launch — spawn Godot detached on the requested scene (default MerlinGame).
      // Pour piloter le jeu depuis la dashboard sans quitter Chrome (user 2026-06-05).
      const projectRoot = path.resolve(process.cwd(), '..', '..', '..');  // tools/autodev/mission-control → repo root
      // Guard startup (review MEDIUM #2) : surface immédiate si Vite tourne depuis le mauvais cwd.
      const godotProjectFile = path.join(projectRoot, 'project.godot');
      if (!fs.existsSync(godotProjectFile)) {
        console.warn(`[godot-bridge] WARNING: project.godot introuvable à ${projectRoot} — /api/godot/launch échouera. Lancer Vite depuis tools/autodev/mission-control/ ou définir GODOT_BIN.`);
      }
      server.middlewares.use('/api/godot/launch', (req, res) => {
        if (req.method !== 'POST') {
          sendJson(res, 405, { ok: false, error: 'POST only' });
          return;
        }
        // Race protection (review MEDIUM #1) : flag synchrone fermé avant body collection,
        // évite un double-spawn si l'utilisateur double-clique pendant que findGodotBin tourne.
        if (godotLaunching) {
          sendJson(res, 200, { ok: true, already_running: true, pid: godotPid, launching: true });
          return;
        }
        if (godotChild && godotChild.exitCode === null && !godotChild.killed) {
          sendJson(res, 200, { ok: true, already_running: true, pid: godotPid });
          return;
        }
        godotLaunching = true;
        let body = '';
        let aborted = false;
        req.on('data', (chunk: Buffer) => {
          if (aborted) return;
          if (body.length + chunk.length > 8192) {
            aborted = true;
            sendJson(res, 413, { ok: false, error: 'Body exceeds 8192 bytes' });
            req.destroy();
            godotLaunching = false;
            return;
          }
          body += chunk.toString('utf-8');
        });
        req.on('end', () => {
          if (aborted) return;
          try {
            const parsed = (JSON.parse(body || '{}') as { scene?: string });
            const rawScene = parsed.scene ?? 'res://scenes/MerlinGame.tscn';
            // Strict allowlist : seuls les chemins res://scenes/*.tscn sans `..` sont acceptés.
            if (!/^res:\/\/scenes\/[\w\-./]+\.tscn$/.test(rawScene) || rawScene.includes('..')) {
              sendJson(res, 400, { ok: false, error: `Invalid scene path: ${rawScene}` });
              godotLaunching = false;
              return;
            }
            const bin = findGodotBin();
            if (!bin) {
              sendJson(res, 500, { ok: false, error: 'Godot binary not found — set GODOT_BIN env var.' });
              godotLaunching = false;
              return;
            }
            const child = spawn(bin, ['--path', projectRoot, rawScene], {
              detached: true,
              stdio: 'ignore',
              windowsHide: false,
            });
            child.on('error', (err) => {
              console.error('[godot-bridge] spawn error:', err);
              godotChild = null;
              godotPid = null;
            });
            child.on('exit', (code) => {
              console.log(`[godot-bridge] Godot exited code=${code}`);
              godotChild = null;
              godotPid = null;
            });
            child.unref();  // ne bloque pas l'arrêt de Vite
            godotChild = child;
            godotPid = child.pid ?? null;
            sendJson(res, 200, { ok: true, pid: godotPid, scene: rawScene, bin });
          } catch (err: unknown) {
            const msg = err instanceof Error ? err.message : 'Unknown error';
            sendJson(res, 500, { ok: false, error: msg });
          } finally {
            godotLaunching = false;
          }
        });
      });

      // POST /api/godot/stop — kill the tracked Godot subprocess (taskkill /T sur Windows).
      // Supprime dashboard_state.json après kill pour éviter l'ambiguïté "stale vs live" côté
      // dashboard (playtester E2E MEDIUM 2026-06-05 : le state restait visible avec timestamp
      // figé). Après /stop, GET /state retourne la branche "pas en cours" propre.
      server.middlewares.use('/api/godot/stop', (req, res) => {
        if (req.method !== 'POST') {
          sendJson(res, 405, { ok: false, error: 'POST only' });
          return;
        }
        const cleanupStateFile = (): void => {
          const statePath = path.join(dir, 'dashboard_state.json');
          try { if (fs.existsSync(statePath)) fs.unlinkSync(statePath); } catch { /* best-effort */ }
        };
        if (!godotChild || godotChild.killed || godotChild.exitCode !== null) {
          godotChild = null;
          godotPid = null;
          cleanupStateFile();  // best-effort cleanup même si pas de process tracké
          sendJson(res, 200, { ok: true, not_running: true });
          return;
        }
        try {
          const pid = godotPid;
          if (process.platform === 'win32' && pid != null) {
            // taskkill /T pour kill tree (Godot peut spawn des sous-process)
            spawn('taskkill', ['/PID', String(pid), '/T', '/F'], { stdio: 'ignore' }).unref();
          } else if (godotChild) {
            godotChild.kill('SIGTERM');
          }
          godotChild = null;
          godotPid = null;
          // Petit délai puis cleanup pour laisser à Godot le temps de release son lock sur le fichier
          setTimeout(cleanupStateFile, 200);
          sendJson(res, 200, { ok: true, killed_pid: pid });
        } catch (err: unknown) {
          const msg = err instanceof Error ? err.message : 'Unknown error';
          sendJson(res, 500, { ok: false, error: msg });
        }
      });

      server.middlewares.use('/api/godot/scenarios', (_req, res) => {
        try {
          if (!fs.existsSync(corpusPath)) {
            sendJson(res, 200, { ok: false, error: 'Corpus non généré — exécuter tools/generate_broceliande_scenarios.py', scenarios: [] });
            return;
          }
          const raw = fs.readFileSync(corpusPath, 'utf-8');
          const parsed: unknown = JSON.parse(raw);
          const arr: ScenarioCorpusItem[] = Array.isArray(parsed) ? (parsed as ScenarioCorpusItem[]) : [];
          const slim: ScenarioSlim[] = arr.map(s => ({
            id: String(s.id ?? ''),
            title: String(s.title ?? ''),
            archetype_id: String(s.archetype_id ?? ''),
            archetype_name: String(s.archetype_name ?? ''),
            pole_dominant: String(s.pole_dominant ?? ''),
            length: Number(s.length ?? 0),
          }));
          sendJson(res, 200, { ok: true, scenarios: slim, total: slim.length });
        } catch (err: unknown) {
          const msg = err instanceof Error ? err.message : 'Unknown error';
          sendJson(res, 500, { ok: false, error: msg });
        }
      });
    },
  };
}

export default defineConfig({
  plugins: [react(), godotBridgePlugin()],
  server: {
    port: 4200,
  },
});
