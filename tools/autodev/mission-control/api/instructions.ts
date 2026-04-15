const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const REPO = 'merlingame-netizen/M.E.R.L.I.N';
const BRANCH = 'main';
const QUEUE_PATH = 'tools/autodev/status/feature_queue.json';

interface InstructionRequest {
  title: string;
  description?: string;
  sprint?: string;
  type?: string;
  priority?: number;
  agent?: string;
  files?: string[];
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

  const body = req.body as InstructionRequest;

  if (!body.title || body.title.trim().length < 5) {
    return res.status(400).json({ ok: false, error: 'Title is required (min 5 chars)' });
  }

  try {
    // Read current feature_queue.json
    const url = `https://api.github.com/repos/${REPO}/contents/${QUEUE_PATH}?ref=${BRANCH}`;
    const headers: Record<string, string> = {
      'Accept': 'application/vnd.github.v3+json',
      'Content-Type': 'application/json',
      'User-Agent': 'merlin-mission-control',
      'Authorization': `Bearer ${GITHUB_TOKEN}`,
    };

    const getRes = await fetch(url, { headers });
    if (!getRes.ok) {
      return res.status(500).json({ ok: false, error: `Failed to read queue: ${getRes.status}` });
    }

    const file: GitHubFileResponse = await getRes.json();
    const decoded = Buffer.from(file.content, 'base64').toString('utf-8');
    const queue = JSON.parse(decoded);

    // Auto-detect current sprint from existing tasks
    const existingTasks = queue.tasks || [];
    const sprintCounts: Record<string, number> = {};
    for (const t of existingTasks) {
      const s = t.sprint || t.id?.match(/^(?:DIR-|S)(\w+)/)?.[1] || '';
      if (s) sprintCounts[s] = (sprintCounts[s] || 0) + 1;
    }
    const sprint = body.sprint || Object.entries(sprintCounts).sort((a, b) => b[1] - a[1])[0]?.[0] || 'S2';
    const timestamp = Date.now().toString(36).toUpperCase();
    const taskId = `DIR-${sprint}-${timestamp}`;

    // Compute priority (default: after existing tasks)
    const existingPriorities = (queue.tasks || []).map((t: any) => t.priority || 99);
    const maxPriority = existingPriorities.length > 0 ? Math.max(...existingPriorities) : 10;
    const priority = body.priority ?? maxPriority + 1;

    // Add new task
    const newTask = {
      id: taskId,
      sprint: sprint.toUpperCase(),
      priority,
      status: 'pending',
      type: body.type || 'dev',
      title: body.title.trim(),
      agent: body.agent || 'auto',
      description: body.description?.trim() || '',
      files: body.files || [],
    };

    queue.tasks.push(newTask);
    queue.updated = new Date().toISOString();

    // Write back
    const putBody = {
      message: `instruction: director added task ${taskId}`,
      content: Buffer.from(JSON.stringify(queue, null, 2)).toString('base64'),
      sha: file.sha,
      branch: BRANCH,
    };

    const putRes = await fetch(url, {
      method: 'PUT',
      headers,
      body: JSON.stringify(putBody),
    });

    if (!putRes.ok) {
      return res.status(500).json({ ok: false, error: `Failed to write queue: ${putRes.status}` });
    }

    return res.status(200).json({ ok: true, task: newTask });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return res.status(500).json({ ok: false, error: message });
  }
}
