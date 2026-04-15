const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const REPO = 'merlingame-netizen/M.E.R.L.I.N';
const BRANCH = 'main';
const QUEUE_PATH = 'tools/autodev/status/feature_queue.json';

interface AdminRequest {
  action: 'update_priority' | 'delete' | 'update_status';
  task_id: string;
  value?: number | string;
}

interface GitHubFileResponse {
  sha: string;
  content: string;
}

export default async function handler(req: any, res: any) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ ok: false, error: 'Method not allowed' });
  if (!GITHUB_TOKEN) return res.status(500).json({ ok: false, error: 'GITHUB_TOKEN not configured' });

  const body = req.body as AdminRequest;
  if (!body.action || !body.task_id) {
    return res.status(400).json({ ok: false, error: 'action and task_id required' });
  }

  try {
    const url = `https://api.github.com/repos/${REPO}/contents/${QUEUE_PATH}?ref=${BRANCH}`;
    const headers: Record<string, string> = {
      'Accept': 'application/vnd.github.v3+json',
      'Content-Type': 'application/json',
      'User-Agent': 'merlin-mission-control',
      'Authorization': `Bearer ${GITHUB_TOKEN}`,
    };

    const getRes = await fetch(url, { headers });
    if (!getRes.ok) return res.status(500).json({ ok: false, error: `Read failed: ${getRes.status}` });

    const file: GitHubFileResponse = await getRes.json();
    const decoded = Buffer.from(file.content, 'base64').toString('utf-8');
    const queue = JSON.parse(decoded);
    const tasks: Array<Record<string, unknown>> = queue.tasks || [];

    const taskIdx = tasks.findIndex(t => t.id === body.task_id);
    if (taskIdx === -1) return res.status(404).json({ ok: false, error: `Task ${body.task_id} not found` });

    let commitMsg = '';

    switch (body.action) {
      case 'update_priority': {
        const newPriority = typeof body.value === 'number' ? body.value : parseInt(String(body.value), 10);
        if (isNaN(newPriority)) return res.status(400).json({ ok: false, error: 'value must be a number' });
        tasks[taskIdx]!.priority = newPriority;
        commitMsg = `admin: set ${body.task_id} priority to P${newPriority}`;
        break;
      }
      case 'delete': {
        tasks.splice(taskIdx, 1);
        commitMsg = `admin: removed task ${body.task_id}`;
        break;
      }
      case 'update_status': {
        const validStatuses = ['pending', 'in_progress', 'dispatched', 'completed', 'blocked'];
        if (!validStatuses.includes(String(body.value))) {
          return res.status(400).json({ ok: false, error: `value must be one of: ${validStatuses.join(', ')}` });
        }
        tasks[taskIdx]!.status = body.value;
        commitMsg = `admin: set ${body.task_id} status to ${body.value}`;
        break;
      }
      default:
        return res.status(400).json({ ok: false, error: `Unknown action: ${body.action}` });
    }

    queue.tasks = tasks;
    queue.updated = new Date().toISOString();

    const putRes = await fetch(url, {
      method: 'PUT',
      headers,
      body: JSON.stringify({
        message: commitMsg,
        content: Buffer.from(JSON.stringify(queue, null, 2)).toString('base64'),
        sha: file.sha,
        branch: BRANCH,
      }),
    });

    if (!putRes.ok) return res.status(500).json({ ok: false, error: `Write failed: ${putRes.status}` });
    return res.status(200).json({ ok: true, action: body.action, task_id: body.task_id });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return res.status(500).json({ ok: false, error: message });
  }
}
