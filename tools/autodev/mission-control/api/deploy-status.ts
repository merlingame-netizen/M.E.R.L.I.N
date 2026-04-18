const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const REPO = 'merlingame-netizen/M.E.R.L.I.N';

let cache: { data: unknown; ts: number } | null = null;
const CACHE_TTL_MS = 30_000;

export default async function handler(req: any, res: any) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET');
  res.setHeader('Cache-Control', 'no-cache');

  if (req.method === 'OPTIONS') return res.status(200).end();

  if (cache && Date.now() - cache.ts < CACHE_TTL_MS) {
    return res.status(200).json({ ok: true, cached: true, ...cache.data as object });
  }

  try {
    const headers: Record<string, string> = {
      'Accept': 'application/vnd.github.v3+json',
      'User-Agent': 'merlin-mission-control',
    };
    if (GITHUB_TOKEN) headers['Authorization'] = `Bearer ${GITHUB_TOKEN}`;

    const url = `https://api.github.com/repos/${REPO}/actions/workflows/godot-export.yml/runs?per_page=3&status=completed`;
    const urlInProgress = `https://api.github.com/repos/${REPO}/actions/workflows/godot-export.yml/runs?per_page=1&status=in_progress`;

    const [completedRes, inProgressRes] = await Promise.all([
      fetch(url, { headers }),
      fetch(urlInProgress, { headers }),
    ]);

    let latest = null;
    let deploying = null;

    if (completedRes.ok) {
      const data = await completedRes.json();
      const runs = data.workflow_runs || [];
      if (runs.length > 0) {
        const r = runs[0];
        latest = {
          id: r.id,
          run_number: r.run_number,
          status: r.status,
          conclusion: r.conclusion,
          created_at: r.created_at,
          updated_at: r.updated_at,
          head_sha: r.head_sha?.slice(0, 7),
          head_message: r.head_commit?.message?.split('\n')[0] || '',
          duration_s: Math.round((new Date(r.updated_at).getTime() - new Date(r.created_at).getTime()) / 1000),
        };
      }
    }

    if (inProgressRes.ok) {
      const data = await inProgressRes.json();
      const runs = data.workflow_runs || [];
      if (runs.length > 0) {
        const r = runs[0];
        deploying = {
          id: r.id,
          run_number: r.run_number,
          status: 'deploying',
          created_at: r.created_at,
          head_sha: r.head_sha?.slice(0, 7),
          head_message: r.head_commit?.message?.split('\n')[0] || '',
          elapsed_s: Math.round((Date.now() - new Date(r.created_at).getTime()) / 1000),
        };
      }
    }

    const result = { ok: true, latest, deploying };
    cache = { data: result, ts: Date.now() };
    return res.status(200).json(result);
  } catch {
    if (cache) return res.status(200).json({ ok: true, cached: true, ...cache.data as object });
    return res.status(200).json({ ok: true, latest: null, deploying: null });
  }
}
