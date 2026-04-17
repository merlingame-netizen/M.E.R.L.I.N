const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const REPO = 'merlingame-netizen/M.E.R.L.I.N';
const BRANCH = 'main';

// In-memory cache to survive rate limits (same pattern as status.ts)
let cache: { commits: unknown[]; ts: number } | null = null;
const CACHE_TTL_MS = 120_000; // 2min cache — git activity changes less often

interface GitHubCommit {
  sha: string;
  commit: {
    message: string;
    author: {
      name: string;
      date: string;
    };
  };
}

export default async function handler(req: any, res: any) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Cache-Control', 's-maxage=120, stale-while-revalidate=300');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'GET') {
    return res.status(405).json({ ok: false, error: 'Method not allowed' });
  }

  // Serve from cache if fresh
  if (cache && Date.now() - cache.ts < CACHE_TTL_MS) {
    return res.status(200).json({ ok: true, commits: cache.commits, cached: true });
  }

  try {
    const url = `https://api.github.com/repos/${REPO}/commits?sha=${BRANCH}&per_page=12`;
    const headers: Record<string, string> = {
      'Accept': 'application/vnd.github.v3+json',
      'User-Agent': 'merlin-mission-control',
    };
    // Use token if available, otherwise unauthenticated (60 req/h)
    if (GITHUB_TOKEN) {
      headers['Authorization'] = `Bearer ${GITHUB_TOKEN}`;
    }

    const ghRes = await fetch(url, { headers });

    // Rate limited — serve stale cache if available
    if (ghRes.status === 403 || ghRes.status === 429) {
      if (cache) {
        return res.status(200).json({ ok: true, commits: cache.commits, cached: true, stale: true });
      }
      return res.status(200).json({ ok: true, commits: [], error: 'Rate limited, no cache available' });
    }

    if (!ghRes.ok) {
      // Serve stale cache on any GitHub error
      if (cache) {
        return res.status(200).json({ ok: true, commits: cache.commits, cached: true, stale: true });
      }
      return res.status(500).json({ ok: false, error: `GitHub API error: ${ghRes.status}` });
    }

    const rawCommits: GitHubCommit[] = await ghRes.json();

    const commits = rawCommits.map(c => {
      const firstLine = c.commit.message.split('\n')[0] ?? '';
      const typeMatch = firstLine.match(/^(\w+)(?:\(([^)]+)\))?:/);
      return {
        sha: c.sha.slice(0, 7),
        message: firstLine,
        author: c.commit.author.name,
        date: c.commit.author.date,
        type: typeMatch?.[1] || 'chore',
        scope: typeMatch?.[2] || null,
      };
    });

    // Update cache
    cache = { commits, ts: Date.now() };

    return res.status(200).json({ ok: true, commits });
  } catch (err: unknown) {
    // On network error, serve stale cache if available
    if (cache) {
      return res.status(200).json({ ok: true, commits: cache.commits, cached: true, stale: true });
    }
    const message = err instanceof Error ? err.message : 'Unknown error';
    return res.status(500).json({ ok: false, error: message });
  }
}
