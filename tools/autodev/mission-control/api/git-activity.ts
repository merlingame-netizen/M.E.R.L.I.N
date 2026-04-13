const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const REPO = 'merlingame-netizen/M.E.R.L.I.N';
const BRANCH = 'main';

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

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'GET') {
    return res.status(405).json({ ok: false, error: 'Method not allowed' });
  }

  if (!GITHUB_TOKEN) {
    return res.status(500).json({ ok: false, error: 'GITHUB_TOKEN not configured' });
  }

  try {
    const url = `https://api.github.com/repos/${REPO}/commits?sha=${BRANCH}&per_page=12`;
    const headers: Record<string, string> = {
      'Authorization': `Bearer ${GITHUB_TOKEN}`,
      'Accept': 'application/vnd.github.v3+json',
      'User-Agent': 'merlin-mission-control',
    };

    const ghRes = await fetch(url, { headers });
    if (!ghRes.ok) {
      return res.status(500).json({ ok: false, error: `GitHub API error: ${ghRes.status}` });
    }

    const rawCommits: GitHubCommit[] = await ghRes.json();

    const commits = rawCommits.map(c => {
      const firstLine = c.commit.message.split('\n')[0];
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

    return res.status(200).json({ ok: true, commits });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return res.status(500).json({ ok: false, error: message });
  }
}
