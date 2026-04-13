const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const REPO = 'merlingame-netizen/M.E.R.L.I.N';
const BRANCH = 'main';

interface SceneFile {
  name: string;
  path: string;
  size: number;
}

export default async function handler(req: any, res: any) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET');
  res.setHeader('Cache-Control', 's-maxage=60, stale-while-revalidate=120');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  const url = `https://api.github.com/repos/${REPO}/contents/scenes?ref=${BRANCH}`;
  const headers: Record<string, string> = {
    'Accept': 'application/vnd.github.v3+json',
    'User-Agent': 'merlin-mission-control',
  };
  if (GITHUB_TOKEN) {
    headers['Authorization'] = `Bearer ${GITHUB_TOKEN}`;
  }

  try {
    const response = await fetch(url, { headers });
    if (!response.ok) {
      return res.status(response.status).json({
        ok: false,
        error: `GitHub API returned ${response.status}`,
      });
    }

    const contents: Array<{ name: string; path: string; size: number; type: string }> =
      await response.json();

    const scenes: SceneFile[] = contents
      .filter(item => item.type === 'file' && item.name.endsWith('.tscn'))
      .map(item => ({
        name: item.name,
        path: item.path,
        size: item.size,
      }));

    return res.status(200).json({
      ok: true,
      scenes,
    });
  } catch {
    return res.status(500).json({
      ok: false,
      error: 'Failed to fetch scene listing from GitHub',
    });
  }
}
