import { defineConfig, type Plugin } from 'vite';
import react from '@vitejs/plugin-react';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';

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
          const raw = fs.readFileSync(fp, 'utf-8');
          sendJson(res, 200, { ok: true, state: JSON.parse(raw) });
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
