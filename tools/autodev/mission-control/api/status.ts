const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const REPO = 'merlingame-netizen/M.E.R.L.I.N';
const BRANCH = 'main';

// Essential files only — reduces GitHub API calls from 19 to 7
const STATUS_FILES = [
  'tools/autodev/status/feature_queue.json',
  'tools/autodev/status/agent_status.json',
  'tools/autodev/status/events.jsonl',
  'tools/autodev/status/feedback_questions.json',
  'tools/autodev/status/director_decision.json',
  'tools/autodev/status/session.json',
  'tools/autodev/status/completed_archive.json',
];

// In-memory cache to survive rate limits
let cache: { data: Record<string, unknown>; ts: number } | null = null;
const CACHE_TTL_MS = 60_000; // 60s cache — fits within 60 req/h unauthenticated limit

async function fetchGitHubFile(path: string): Promise<unknown | null> {
  const url = `https://api.github.com/repos/${REPO}/contents/${path}?ref=${BRANCH}`;
  const headers: Record<string, string> = {
    'Accept': 'application/vnd.github.v3.raw',
    'User-Agent': 'merlin-mission-control',
  };
  if (GITHUB_TOKEN) {
    headers['Authorization'] = `Bearer ${GITHUB_TOKEN}`;
  }

  try {
    const res = await fetch(url, { headers });
    if (res.status === 403 || res.status === 429) return null; // rate limited
    if (!res.ok) return null;
    const text = await res.text();

    if (path.endsWith('.jsonl')) {
      const lines = text.trim().split('\n').filter(Boolean);
      const last50 = lines.slice(-50);
      return last50.map(line => {
        try { return JSON.parse(line); }
        catch { return null; }
      }).filter(Boolean);
    }

    if (path.endsWith('.json')) {
      return JSON.parse(text);
    }

    return text;
  } catch {
    return null;
  }
}

export default async function handler(req: any, res: any) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET');
  res.setHeader('Cache-Control', 's-maxage=60, stale-while-revalidate=120');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  // Serve from cache if fresh
  if (cache && Date.now() - cache.ts < CACHE_TTL_MS) {
    return res.status(200).json({
      ok: true,
      timestamp: new Date().toISOString(),
      cached: true,
      data: cache.data,
    });
  }

  const results: Record<string, unknown> = {};

  const fetches = STATUS_FILES.map(async (path) => {
    const key = path.split('/').pop()!.replace(/\.\w+$/, '');
    results[key] = await fetchGitHubFile(path);
  });

  await Promise.all(fetches);

  // If all results are null, we're rate-limited — serve stale cache
  const allNull = Object.values(results).every(v => v === null);
  if (allNull && cache) {
    return res.status(200).json({
      ok: true,
      timestamp: new Date().toISOString(),
      cached: true,
      stale: true,
      data: cache.data,
    });
  }

  // Update cache
  cache = { data: results, ts: Date.now() };

  return res.status(200).json({
    ok: true,
    timestamp: new Date().toISOString(),
    data: results,
  });
}
