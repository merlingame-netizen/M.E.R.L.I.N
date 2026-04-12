const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const REPO = 'merlingame-netizen/M.E.R.L.I.N';
const BRANCH = 'main';
const FILE_PATH = 'tools/autodev/status/feedback_responses.json';

interface FeedbackRequest {
  question_id: string;
  answer: string;
  additional_notes?: string;
}

interface GitHubFileResponse {
  sha: string;
  content: string;
}

async function getFileFromGitHub(): Promise<{ sha: string; data: { version: number; responses: FeedbackRequest[] } }> {
  const url = `https://api.github.com/repos/${REPO}/contents/${FILE_PATH}?ref=${BRANCH}`;
  const headers: Record<string, string> = {
    'Accept': 'application/vnd.github.v3+json',
    'User-Agent': 'merlin-mission-control',
  };
  if (GITHUB_TOKEN) {
    headers['Authorization'] = `Bearer ${GITHUB_TOKEN}`;
  }

  const res = await fetch(url, { headers });

  if (res.status === 404) {
    return {
      sha: '',
      data: { version: 1, responses: [] },
    };
  }

  if (!res.ok) {
    throw new Error(`GitHub GET failed: ${res.status}`);
  }

  const file: GitHubFileResponse = await res.json();
  const decoded = Buffer.from(file.content, 'base64').toString('utf-8');
  return {
    sha: file.sha,
    data: JSON.parse(decoded),
  };
}

async function putFileToGitHub(content: string, sha: string, message: string): Promise<boolean> {
  const url = `https://api.github.com/repos/${REPO}/contents/${FILE_PATH}`;
  const headers: Record<string, string> = {
    'Accept': 'application/vnd.github.v3+json',
    'Content-Type': 'application/json',
    'User-Agent': 'merlin-mission-control',
  };
  if (GITHUB_TOKEN) {
    headers['Authorization'] = `Bearer ${GITHUB_TOKEN}`;
  }

  const body: Record<string, string> = {
    message,
    content: Buffer.from(content).toString('base64'),
    branch: BRANCH,
  };
  if (sha) {
    body.sha = sha;
  }

  const res = await fetch(url, {
    method: 'PUT',
    headers,
    body: JSON.stringify(body),
  });

  return res.ok;
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

  const { question_id, answer, additional_notes } = req.body as FeedbackRequest;

  if (!question_id || !answer) {
    return res.status(400).json({ ok: false, error: 'question_id and answer are required' });
  }

  try {
    const { sha, data } = await getFileFromGitHub();

    data.responses.push({
      question_id,
      answer,
      additional_notes: additional_notes || undefined,
    });

    const updated = JSON.stringify(data, null, 2);
    const success = await putFileToGitHub(
      updated,
      sha,
      `feedback: director response to ${question_id}`
    );

    if (!success) {
      return res.status(500).json({ ok: false, error: 'Failed to write to GitHub' });
    }

    return res.status(200).json({ ok: true, question_id });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return res.status(500).json({ ok: false, error: message });
  }
}
