const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const REPO = 'merlingame-netizen/M.E.R.L.I.N';
const BRANCH = 'main';

const STATUS_FILES = [
  'tools/autodev/status/feature_queue.json',
  'tools/autodev/status/agent_status.json',
  'tools/autodev/status/events.jsonl',
  'tools/autodev/status/escalation.json',
  'tools/autodev/status/watchdog.txt',
  'tools/autodev/status/feedback_questions.json',
  'tools/autodev/status/director_decision.json',
  'tools/autodev/status/session.json',
  'tools/autodev/status/control_state.json',
  'tools/autodev/status/test_results.json',
  'tools/autodev/status/health_report.json',
  'tools/autodev/status/feedback_responses.json',
  'tools/autodev/status/completed_archive.json',
  'tools/autodev/status/studio_learnings.json',
  'tools/autodev/status/studio_insights.json',
];

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
  res.setHeader('Cache-Control', 's-maxage=15, stale-while-revalidate=30');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  const results: Record<string, unknown> = {};

  const fetches = STATUS_FILES.map(async (path) => {
    const key = path.split('/').pop()!.replace(/\.\w+$/, '');
    results[key] = await fetchGitHubFile(path);
  });

  // Also fetch test_reports directory listing
  fetches.push((async () => {
    try {
      const url = `https://api.github.com/repos/${REPO}/contents/tools/autodev/status/test_reports?ref=${BRANCH}`;
      const headers: Record<string, string> = {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'merlin-mission-control',
      };
      if (GITHUB_TOKEN) headers['Authorization'] = `Bearer ${GITHUB_TOKEN}`;
      const dirRes = await fetch(url, { headers });
      if (dirRes.ok) {
        const files = await dirRes.json();
        // Get last 10 reports sorted by name (date-based names sort naturally)
        const reportFiles = (files as Array<{ name: string; download_url: string }>)
          .filter((f: { name: string }) => f.name.startsWith('SPECIALIST-') || f.name.endsWith('.json'))
          .sort((a: { name: string }, b: { name: string }) => b.name.localeCompare(a.name))
          .slice(0, 10);

        // Fetch content of last 3 reports
        const reports = await Promise.all(
          reportFiles.slice(0, 3).map(async (f: { name: string; download_url: string }) => {
            try {
              const content = await fetchGitHubFile(`tools/autodev/status/test_reports/${f.name}`);
              return { name: f.name, content };
            } catch { return { name: f.name, content: null }; }
          })
        );
        results['test_reports'] = {
          total: reportFiles.length,
          files: reportFiles.map((f: { name: string }) => f.name),
          recent: reports,
        };
      }
    } catch { /* non-critical */ }
  })());

  await Promise.all(fetches);

  return res.status(200).json({
    ok: true,
    timestamp: new Date().toISOString(),
    data: results,
  });
}
