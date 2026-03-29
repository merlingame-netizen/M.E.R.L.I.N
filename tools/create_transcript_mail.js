/**
 * create_transcript_mail.js — VTT to Orange-branded .eml (CR meeting minutes)
 *
 * Usage:
 *   node tools/create_transcript_mail.js --list
 *   node tools/create_transcript_mail.js --parse <file.vtt>
 *   node tools/create_transcript_mail.js --generate <cr.json> --output <path.eml>
 */

const fs = require('fs');
const path = require('path');

const TRANSCRIPTS_DIR = 'C:/Users/PGNK2128/OneDrive - orange.com/Partage VOC/Data/_transcripts_auto';

// ── CLI ──────────────────────────────────────────────────────────────────────
const args = process.argv.slice(2);
const mode = args[0];

if (mode === '--list') {
  listVtt();
} else if (mode === '--parse' && args[1]) {
  parseVtt(args[1]);
} else if (mode === '--generate' && args[1]) {
  const outputIdx = args.indexOf('--output');
  const output = outputIdx !== -1 ? args[outputIdx + 1] : null;
  generateEml(args[1], output);
} else {
  console.log('Usage:');
  console.log('  --list                         List pending VTT files');
  console.log('  --parse <file.vtt>             Parse VTT to JSON');
  console.log('  --generate <cr.json> [--output <path.eml>]  Generate .eml');
  process.exit(1);
}

// ── LIST ─────────────────────────────────────────────────────────────────────
function listVtt() {
  try {
    const files = fs.readdirSync(TRANSCRIPTS_DIR)
      .filter(f => f.toLowerCase().endsWith('.vtt'));
    if (files.length === 0) {
      console.log('Aucun fichier VTT a traiter dans _transcripts_auto/');
      return;
    }
    console.log(`${files.length} fichier(s) VTT en attente:`);
    files.forEach(f => {
      const stat = fs.statSync(path.join(TRANSCRIPTS_DIR, f));
      console.log(`  - ${f}  (${(stat.size / 1024).toFixed(1)} KB, ${stat.mtime.toISOString().slice(0, 10)})`);
    });
  } catch (e) {
    console.error('Erreur lecture dossier:', e.message);
  }
}

// ── PARSE ────────────────────────────────────────────────────────────────────
function parseVtt(filePath) {
  const raw = fs.readFileSync(filePath, 'utf8');
  const blocks = raw.split(/\r?\n\r?\n/).filter(b => b.trim());

  const entries = [];
  for (const block of blocks) {
    const lines = block.split(/\r?\n/);
    // Find timestamp line
    const tsLine = lines.find(l => /\d{2}:\d{2}:\d{2}\.\d{3}\s*-->\s*\d{2}:\d{2}:\d{2}\.\d{3}/.test(l));
    if (!tsLine) continue;

    const [startStr, endStr] = tsLine.split('-->').map(s => s.trim());
    const textLines = lines.slice(lines.indexOf(tsLine) + 1);
    const fullText = textLines.join(' ');

    // Extract speaker from <v NAME>...</v>
    const speakerMatch = fullText.match(/<v\s+([^>]+)>/);
    const speaker = speakerMatch ? decodeEntities(speakerMatch[1]) : 'Unknown';
    const text = fullText.replace(/<\/?v[^>]*>/g, '').trim();

    if (text) {
      entries.push({ start: startStr, end: endStr, speaker, text });
    }
  }

  // Merge consecutive turns by same speaker
  const merged = [];
  for (const e of entries) {
    const last = merged[merged.length - 1];
    if (last && last.speaker === e.speaker) {
      last.text += ' ' + e.text;
      last.end = e.end;
    } else {
      merged.push({ ...e });
    }
  }

  // Extract unique speakers
  const speakers = [...new Set(entries.map(e => e.speaker))].map(name => ({
    displayName: formatDisplayName(name),
    rawName: name,
    email: deriveEmail(name),
    type: name.includes('ext') ? 'external' : 'internal'
  }));

  // Timestamps
  const firstTs = entries[0]?.start || '00:00:00.000';
  const lastTs = entries[entries.length - 1]?.end || '00:00:00.000';
  const durationMs = parseTimestamp(lastTs) - parseTimestamp(firstTs);
  const durationMinutes = Math.round(durationMs / 60000);

  // Full text for summarization
  const fullText = merged.map(m => `[${m.speaker}] ${m.text}`).join('\n');

  const result = {
    source: path.basename(filePath),
    speakers,
    turns: merged.length,
    startTime: firstTs,
    endTime: lastTs,
    durationMinutes,
    fullText,
    mergedTurns: merged
  };

  console.log(JSON.stringify(result, null, 2));
}

// ── GENERATE EML ─────────────────────────────────────────────────────────────
function generateEml(crJsonPath, outputPath) {
  const cr = JSON.parse(fs.readFileSync(crJsonPath, 'utf8'));

  const html = buildHtml(cr);
  const toEmails = cr.participants.map(p => p.email).join(', ');
  const subject = `CR - ${cr.subject} - ${cr.date}`;
  const encodedSubject = '=?UTF-8?B?' + Buffer.from(subject).toString('base64') + '?=';
  const boundary = 'boundary_' + Date.now();

  const eml = [
    'X-Unsent: 1',
    'From: maxime.babonneau@orange.com',
    'To: ' + toEmails,
    'Subject: ' + encodedSubject,
    'MIME-Version: 1.0',
    'Content-Type: multipart/alternative; boundary="' + boundary + '"',
    '',
    '--' + boundary,
    'Content-Type: text/html; charset=utf-8',
    'Content-Transfer-Encoding: base64',
    '',
    Buffer.from(html).toString('base64').match(/.{1,76}/g).join('\n'),
    '',
    '--' + boundary + '--'
  ].join('\r\n');

  const out = outputPath || path.join(TRANSCRIPTS_DIR, `CR - ${cr.subject} - ${cr.date}.eml`);
  fs.writeFileSync(out, eml);
  console.log('EML generated: ' + out);
}

// ── HTML TEMPLATE (Orange CR format — modèle VOCE validé) ────────────────────
function buildHtml(cr) {
  const orange = '#FF7900';
  const black = '#000000';
  const grey = '#595959';
  const lightBg = '#F6F6F6';

  // Format date DD/MM/YYYY
  const dateParts = cr.date.split('-');
  const dateFormatted = dateParts.length === 3
    ? `${dateParts[2]}/${dateParts[1]}/${dateParts[0]}`
    : cr.date;

  // Participants list inline
  const participantNames = cr.participants.map(p => p.displayName).join(', ');

  // Section builder helper
  const sectionTitle = (title) =>
    `<h2 style="color:${orange};font-size:15px;font-weight:bold;text-transform:uppercase;letter-spacing:0.5px;margin:28px 0 12px;padding:0">${title}</h2>`;

  const blockquote = (content) =>
    `<div style="border-left:4px solid ${orange};background:${lightBg};padding:12px 16px;margin:0 0 20px;font-size:14px;line-height:1.6;color:${grey}">${content}</div>`;

  // Build key points as blockquote bullets
  const keyPointsHtml = cr.keyPoints.map(p => `<li style="margin-bottom:4px">${p}</li>`).join('\n');

  // Build decisions
  const decisionsHtml = cr.decisions.map(d => `<li style="margin-bottom:4px">${d}</li>`).join('\n');

  // Build actions table
  const actionsRows = cr.actions.map((a, i) => `
    <tr style="background:${i % 2 === 0 ? '#ffffff' : lightBg}">
      <td style="padding:8px 10px;border-bottom:1px solid #eee;text-align:center;font-size:13px">${i + 1}</td>
      <td style="padding:8px 10px;border-bottom:1px solid #eee;font-size:13px">${a.action}</td>
      <td style="padding:8px 10px;border-bottom:1px solid #eee;font-size:13px;white-space:nowrap">${a.responsible}</td>
      <td style="padding:8px 10px;border-bottom:1px solid #eee;font-size:13px;white-space:nowrap">${a.deadline}</td>
    </tr>`).join('');

  // Build next steps
  const nextStepsHtml = cr.nextSteps.map(s => `<li style="margin-bottom:4px">${s}</li>`).join('\n');

  return `<!DOCTYPE html>
<html lang="fr">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width"></head>
<body style="margin:0;padding:0;background:#ffffff;font-family:Helvetica Neue,Arial,sans-serif;color:${black}">

<div style="max-width:760px;margin:0 auto;padding:24px 24px 8px">

<!-- HEADER: Orange + Direction VOCE Data -->
<p style="margin:0 0 24px;font-size:16px">
  <span style="color:${orange};font-weight:bold;font-size:20px">Orange</span>
  <span style="color:${black};font-size:15px;margin-left:6px">Direction VOCE Data</span>
</p>

<!-- TITRE REUNION -->
<h1 style="color:${black};font-size:22px;font-weight:bold;margin:0 0 6px">${cr.subject}</h1>

<!-- DATE + PARTICIPANTS -->
<p style="color:${grey};font-size:14px;margin:0 0 28px">${dateFormatted} - ${participantNames}</p>

<!-- SYNTHESE -->
${sectionTitle('SYNTHESE')}
${blockquote(cr.keyPoints.length <= 3
    ? cr.keyPoints.join('<br>')
    : '<ul style="margin:0;padding-left:18px">' + keyPointsHtml + '</ul>'
)}

<!-- CONTEXTE -->
${sectionTitle('CONTEXTE')}
<p style="font-size:14px;line-height:1.7;color:${grey};margin:0 0 20px;text-align:justify">${cr.context}</p>

<!-- DECISIONS -->
${cr.decisions && cr.decisions.length > 0 && cr.decisions[0] !== 'Aucune decision formalisee' ? `
${sectionTitle('DÉCISIONS')}
<ol style="font-size:14px;padding-left:20px;margin:0 0 20px;line-height:1.6;color:${grey}">
${decisionsHtml}
</ol>` : ''}

<!-- ACTIONS -->
${cr.actions && cr.actions.length > 0 ? `
${sectionTitle('ACTIONS')}
<table style="border-collapse:collapse;width:100%;margin-bottom:20px" cellpadding="0" cellspacing="0">
  <tr style="background:${black}">
    <th style="padding:8px 10px;text-align:center;color:white;font-size:12px;font-weight:600;width:32px">#</th>
    <th style="padding:8px 10px;text-align:left;color:white;font-size:12px;font-weight:600">Action</th>
    <th style="padding:8px 10px;text-align:left;color:white;font-size:12px;font-weight:600">Responsable</th>
    <th style="padding:8px 10px;text-align:left;color:white;font-size:12px;font-weight:600">Échéance</th>
  </tr>
  ${actionsRows}
</table>` : ''}

<!-- PROCHAINES ETAPES -->
${cr.nextSteps && cr.nextSteps.length > 0 ? `
${sectionTitle('PROCHAINES ÉTAPES')}
<ul style="font-size:14px;padding-left:20px;margin:0 0 20px;line-height:1.6;color:${grey}">
${nextStepsHtml}
</ul>` : ''}

</div>
</body></html>`;
}

// ── HELPERS ──────────────────────────────────────────────────────────────────
function decodeEntities(str) {
  return str.replace(/&#(\d+);/g, (_, code) => String.fromCharCode(parseInt(code)));
}

function formatDisplayName(raw) {
  // "BABONNEAU Maxime DEF" → "Maxime Babonneau"
  const parts = raw.replace(/\s+(DEF|DM2P|ext)\s*$/i, '').trim().split(/\s+/);
  if (parts.length < 2) return raw;
  const lastName = parts[0];
  const firstName = parts.slice(1).join(' ');
  const cap = s => s.charAt(0).toUpperCase() + s.slice(1).toLowerCase();
  return firstName.split(' ').map(cap).join(' ') + ' ' + lastName.split('-').map(cap).join('-');
}

function deriveEmail(raw) {
  const isExt = /\bext\b/i.test(raw);
  const clean = raw.replace(/\s+(DEF|DM2P|ext)\s*$/i, '').trim();
  const parts = clean.split(/\s+/);
  if (parts.length < 2) return '';
  const lastName = parts[0].toLowerCase();
  const firstName = parts.slice(1).join(' ').toLowerCase();
  const strip = s => s.normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/\s+/g, '-');
  const suffix = isExt ? '-ext' : '';
  return `${strip(firstName)}.${strip(lastName)}${suffix}@orange.com`;
}

function parseTimestamp(ts) {
  const [h, m, rest] = ts.split(':');
  const [s, ms] = rest.split('.');
  return parseInt(h) * 3600000 + parseInt(m) * 60000 + parseInt(s) * 1000 + parseInt(ms || 0);
}
