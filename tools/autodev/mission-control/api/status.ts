const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const REPO = 'merlingame-netizen/M.E.R.L.I.N';
const BRANCH = 'main';
const STATUS_DIR = 'tools/autodev/status';

const WANTED_FILES: Record<string, string> = {
  'feature_queue.json': 'feature_queue',
  'agent_status.json': 'agent_status',
  'events.jsonl': 'events',
  'feedback_questions.json': 'feedback_questions',
  'feedback_responses.json': 'feedback_responses',
  'director_decision.json': 'director_decision',
  'session.json': 'session',
  'completed_archive.json': 'completed_archive',
  'watchdog.txt': 'watchdog',
};

let cache: { data: Record<string, unknown>; ts: number; etag: string } | null = null;
const CACHE_TTL_MS = 90_000;

async function fetchAllStatusFiles(): Promise<Record<string, unknown>> {
  const results: Record<string, unknown> = {};
  const headers: Record<string, string> = {
    'Accept': 'application/vnd.github.v3+json',
    'User-Agent': 'merlin-mission-control',
  };
  if (GITHUB_TOKEN) {
    headers['Authorization'] = `Bearer ${GITHUB_TOKEN}`;
  }
  if (cache?.etag) {
    headers['If-None-Match'] = cache.etag;
  }

  try {
    const url = `https://api.github.com/repos/${REPO}/contents/${STATUS_DIR}?ref=${BRANCH}`;
    const dirRes = await fetch(url, { headers });

    if (dirRes.status === 304) {
      return cache?.data || {};
    }
    if (dirRes.status === 403 || dirRes.status === 429) {
      return cache?.data || {};
    }
    if (!dirRes.ok) {
      return cache?.data || {};
    }

    const newEtag = dirRes.headers.get('etag') || '';
    const listing: Array<{ name: string; download_url: string }> = await dirRes.json();

    const filesToFetch = listing.filter(f => WANTED_FILES[f.name]);

    const fetches = filesToFetch.map(async (file) => {
      const key = WANTED_FILES[file.name];
      try {
        const fileRes = await fetch(file.download_url, {
          headers: { 'User-Agent': 'merlin-mission-control' },
        });
        if (!fileRes.ok) { results[key] = null; return; }
        const text = await fileRes.text();

        if (file.name.endsWith('.jsonl')) {
          const lines = text.trim().split('\n').filter(Boolean);
          results[key] = lines.slice(-50).map(line => {
            try { return JSON.parse(line); }
            catch { return null; }
          }).filter(Boolean);
        } else if (file.name.endsWith('.json')) {
          results[key] = JSON.parse(text);
        } else {
          results[key] = text;
        }
      } catch {
        results[key] = null;
      }
    });

    await Promise.all(fetches);

    cache = { data: results, ts: Date.now(), etag: newEtag };
    return results;

  } catch {
    return cache?.data || {};
  }
}

export default async function handler(req: any, res: any) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET');
  res.setHeader('Cache-Control', 's-maxage=60, stale-while-revalidate=120');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (cache && Date.now() - cache.ts < CACHE_TTL_MS) {
    return res.status(200).json({
      ok: true,
      timestamp: new Date().toISOString(),
      cached: true,
      data: cache.data,
    });
  }

  const data = await fetchAllStatusFiles();

  return res.status(200).json({
    ok: true,
    timestamp: new Date().toISOString(),
    data,
  });
}
