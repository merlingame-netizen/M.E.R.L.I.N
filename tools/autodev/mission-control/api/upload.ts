const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const REPO = 'merlingame-netizen/M.E.R.L.I.N';
const BRANCH = 'main';

// Allowed upload directories and their accepted extensions
const UPLOAD_TARGETS: Record<string, string[]> = {
  'Assets/audio/music': ['.ogg', '.wav', '.mp3'],
  'Assets/audio/sfx': ['.ogg', '.wav', '.mp3'],
  'Assets/models': ['.glb', '.gltf', '.obj', '.fbx', '.blend'],
  'Assets/textures': ['.png', '.jpg', '.jpeg', '.webp', '.svg'],
  'Assets/fonts': ['.ttf', '.otf', '.woff', '.woff2'],
};

interface UploadRequest {
  filename: string;
  directory: string;
  content_base64: string;
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

  const { filename, directory, content_base64 } = req.body as UploadRequest;

  if (!filename || !directory || !content_base64) {
    return res.status(400).json({ ok: false, error: 'filename, directory, and content_base64 are required' });
  }

  // Validate directory
  if (!UPLOAD_TARGETS[directory]) {
    return res.status(400).json({
      ok: false,
      error: `Invalid directory. Allowed: ${Object.keys(UPLOAD_TARGETS).join(', ')}`,
    });
  }

  // Validate extension
  const ext = '.' + filename.split('.').pop()?.toLowerCase();
  const allowedExts = UPLOAD_TARGETS[directory];
  if (!allowedExts.includes(ext)) {
    return res.status(400).json({
      ok: false,
      error: `Invalid file type for ${directory}. Allowed: ${allowedExts.join(', ')}`,
    });
  }

  // Sanitize filename
  const safeName = filename.replace(/[^a-zA-Z0-9._-]/g, '_');
  const filePath = `${directory}/${safeName}`;

  // Size check (~10MB max after base64)
  if (content_base64.length > 14_000_000) {
    return res.status(400).json({ ok: false, error: 'File too large (max 10MB)' });
  }

  try {
    // Check if file already exists (get sha)
    const checkUrl = `https://api.github.com/repos/${REPO}/contents/${filePath}?ref=${BRANCH}`;
    const headers: Record<string, string> = {
      'Accept': 'application/vnd.github.v3+json',
      'Content-Type': 'application/json',
      'User-Agent': 'merlin-mission-control',
      'Authorization': `Bearer ${GITHUB_TOKEN}`,
    };

    let sha = '';
    const checkRes = await fetch(checkUrl, { headers });
    if (checkRes.ok) {
      const existing = await checkRes.json();
      sha = existing.sha;
    }

    // Upload file
    const body: Record<string, string> = {
      message: `asset: upload ${safeName} to ${directory}`,
      content: content_base64,
      branch: BRANCH,
    };
    if (sha) {
      body.sha = sha;
    }

    const putRes = await fetch(checkUrl, {
      method: 'PUT',
      headers,
      body: JSON.stringify(body),
    });

    if (!putRes.ok) {
      const errBody = await putRes.text();
      return res.status(500).json({ ok: false, error: `GitHub upload failed: ${putRes.status}`, details: errBody });
    }

    return res.status(200).json({ ok: true, path: filePath, replaced: !!sha });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return res.status(500).json({ ok: false, error: message });
  }
}
