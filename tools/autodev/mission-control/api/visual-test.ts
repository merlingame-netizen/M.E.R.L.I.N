const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const REPO = 'merlingame-netizen/M.E.R.L.I.N';
const BRANCH = 'main';
const REQUEST_PATH = 'tools/autodev/status/visual_test_request.json';

interface VisualTestRequest {
  scene: string;
  duration?: number;
}

interface GitHubFileResponse {
  sha: string;
  content: string;
}

export default async function handler(req: any, res: any) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ ok: false, error: 'Method not allowed' });
  }

  if (!GITHUB_TOKEN) {
    return res.status(500).json({ ok: false, error: 'GITHUB_TOKEN not configured' });
  }

  const { scene, duration } = req.body as VisualTestRequest;

  if (!scene || typeof scene !== 'string') {
    return res.status(400).json({ ok: false, error: 'scene path required' });
  }

  if (!scene.endsWith('.tscn') || scene.includes('..')) {
    return res.status(400).json({ ok: false, error: 'Invalid scene path' });
  }

  const headers: Record<string, string> = {
    'Authorization': `Bearer ${GITHUB_TOKEN}`,
    'Accept': 'application/vnd.github.v3+json',
    'User-Agent': 'merlin-mission-control',
  };

  try {
    // Check if file already exists (to get sha for update)
    let existingSha: string | undefined;
    const getRes = await fetch(
      `https://api.github.com/repos/${REPO}/contents/${REQUEST_PATH}?ref=${BRANCH}`,
      { headers }
    );
    if (getRes.ok) {
      const existing = (await getRes.json()) as GitHubFileResponse;
      existingSha = existing.sha;
    }

    // Write the request file
    const requestData = {
      scene,
      duration: duration || 30,
      requested_at: new Date().toISOString(),
      requested_by: 'director',
      status: 'pending',
    };

    const content = Buffer.from(JSON.stringify(requestData, null, 2)).toString('base64');

    const putBody: Record<string, unknown> = {
      message: `visual-test: request for ${scene.split('/').pop()}`,
      content,
      branch: BRANCH,
    };
    if (existingSha) {
      putBody.sha = existingSha;
    }

    const putRes = await fetch(
      `https://api.github.com/repos/${REPO}/contents/${REQUEST_PATH}`,
      {
        method: 'PUT',
        headers: { ...headers, 'Content-Type': 'application/json' },
        body: JSON.stringify(putBody),
      }
    );

    if (!putRes.ok) {
      const err = await putRes.text();
      return res.status(500).json({ ok: false, error: `GitHub API error: ${putRes.status}`, details: err });
    }

    return res.status(200).json({
      ok: true,
      message: `Visual test requested for ${scene}`,
      request: requestData,
    });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return res.status(500).json({ ok: false, error: message });
  }
}
