const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const REPO = 'merlingame-netizen/M.E.R.L.I.N';
const BRANCH = 'main';

const STATUS_FILES = [
  'tools/autodev/status/feature_queue.json',
  'tools/autodev/status/agent_status.json',
  'tools/autodev/status/session.json',
  'tools/autodev/status/events.jsonl',
  'tools/autodev/status/feedback_questions.json',
];

let cache: { data: Record<string, unknown>; ts: number } | null = null;
const CACHE_TTL_MS = 360_000;

async function fetchFile(path: string): Promise<unknown | null> {
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
    if (!res.ok) return null;
    const text = await res.text();

    if (path.endsWith('.jsonl')) {
      const lines = text.trim().split('\n').filter(Boolean);
      return lines.slice(-50).map(line => {
        try { return JSON.parse(line); } catch { return null; }
      }).filter(Boolean);
    }
    if (path.endsWith('.json')) return JSON.parse(text);
    return text;
  } catch {
    return null;
  }
}

export default async function handler(req: any, res: any) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET');
  res.setHeader('Cache-Control', 'no-cache');

  if (req.method === 'OPTIONS') return res.status(200).end();

  if (cache && Date.now() - cache.ts < CACHE_TTL_MS) {
    return res.status(200).json({ ok: true, timestamp: new Date().toISOString(), cached: true, data: cache.data });
  }

  const results: Record<string, unknown> = {};
  for (const path of STATUS_FILES) {
    const key = path.split('/').pop()!.replace(/\.\w+$/, '');
    results[key] = await fetchFile(path);
  }

  const allNull = Object.values(results).every(v => v === null);
  if (allNull && cache) {
    return res.status(200).json({ ok: true, timestamp: new Date().toISOString(), cached: true, stale: true, data: cache.data });
  }

  if (!allNull) cache = { data: results, ts: Date.now() };

  return res.status(200).json({ ok: true, timestamp: new Date().toISOString(), data: results });
}
