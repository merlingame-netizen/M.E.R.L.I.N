/* MERLIN Studio — logique du portail (extraite d'index.html, re-skin premium).
   Les contrats /api/* sont inchangés ; seules les classes CSS générées changent. */
import { initGame } from '/static/game.js';

const $ = s => document.querySelector(s), j = (u, o) => fetch(u, o).then(r => r.json());
const esc = s => String(s ?? "").replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const card = (n, b, st) => `<div class="card ${st||''}"><div class="row"><span class="name">${n}</span></div>${b}</div>`;
const gauge = p => { const c = p >= 90 ? 'crit' : p >= 70 ? 'warn' : ''; return `<div class="bar ${c}"><i style="width:${Math.min(p,100)}%"></i></div>`; };
let CAT = [];

document.querySelectorAll('nav button').forEach(b => b.onclick = () => {
  document.querySelectorAll('nav button').forEach(x => x.classList.toggle('on', x === b));
  document.querySelectorAll('.pane').forEach(p => p.classList.toggle('on', p.id === 'pane-' + b.dataset.tab));
});

async function run(kind, params) {
  try {
    const x = await j('/api/launch', { method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ kind, params: params || {} }) });
    const t = x.error ? ('✗ ' + x.error) : ('✓ ' + (x.label || kind) + ' lancé #' + x.id);
    ['#runres', '#genres', '#lres'].forEach(id => { const e = $(id); if (e) { e.textContent = t; e.className = 'res ' + (x.error ? 'err' : 'ok'); } });
  } catch (e) {}
  refreshJobs();
}
const runAll = () => run('godot-smoke-all', { duration: 6 });
const parseProj = () => { if (confirm("L'import/parse complet peut prendre 5-10 min à froid. Lancer ?")) run('godot-parse'); };
const genCards = () => run('content-gen', { count: parseInt($('#genN').value), backend: $('#genB').value });

async function refreshRun() {
  const d = await j('/api/godot'), g = d.godot || {}, runs = d.runs || {};
  $('#godotcard').innerHTML = [
    card('Binaire', `<div class="metrics"><span>version <b>${esc(g.version||'—')}</b></span><span>headless <b>${g.headless_only?'oui':'non'}</b></span></div>
     ${g.warning ? `<div class="res err">⚠ ${esc(g.warning)}</div>` : ''}`, g.available ? (g.warning ? 'warn' : 'up') : 'down'),
    card('Projet', `<div class="metrics"><span>nom <b>${esc(g.project?.name||'—')}</b></span></div>
     <div class="mut">scène principale : ${esc(g.project?.main_scene||'—')}</div>
     <div class="mut">export presets : ${g.export_presets?'✓':'absent'}</div>`, 'up'),
  ].join('');
  $('#scenes').innerHTML = (g.scenes || []).map(s => {
    const k = 'smoke:' + s, r = runs[k];
    const st = r ? (r.status === 'done' && !r.script_errors ? 'done' : 'failed') : 'pending';
    return `<div class="card ${st}"><div class="row"><span class="name">${esc(s.replace('.tscn',''))}</span>
     <span class="badge ${st}">${r ? r.status : 'jamais'}</span></div>
     ${r ? `<div class="mut">exit ${r.exit_code} · ${r.script_errors} SCRIPT ERROR · ${esc(r.at||'')}</div>` : '<div class="mut">pas encore testée</div>'}
     <div style="margin-top:9px"><button class="go sm" onclick="run('godot-smoke',{scene:'${esc(s)}',duration:8})">Smoke ▶</button></div></div>`;
  }).join('');
}

async function refreshPlay() {
  let ok = false;
  try { const r = await fetch('/play/', { method: 'HEAD' }); ok = r.ok; } catch (e) {}
  const el = $('#weblink');
  if (el) {
    el.classList.toggle('mut', !ok);
    el.textContent = ok ? 'Jouer en version web ↗ (secours)' : 'Version web : aucun build (lancer Build web)';
    if (ok) el.setAttribute('href', '/play/'); else el.removeAttribute('href');
  }
}

async function refreshContent() {
  const d = await j('/api/content'), c = d.canon || {}, co = d.corpus || {}, lp = d.loops || {};
  const cnt = c.counts || {};
  const mos = co.mos || { cards: 0, target: 25 };
  $('#contentcards').innerHTML = [
    card('Lore canon', c.available ? `<div class="metrics">
     <span>v <b>${esc(c.version)}</b></span><span>factions <b>${cnt.factions}</b></span><span>PNJ <b>${cnt.npcs}</b></span>
     <span>biomes <b>${cnt.biomes}</b></span><span>runes <b>${cnt.rune_circuits}</b></span><span>fins <b>${cnt.endings}</b></span>
     <span>events <b>${cnt.events}</b></span></div>
     <div class="mut">divergences ${c.divergences} · gaps ${c.gaps}</div>` : '<div class="mut">lore_canon.json absent</div>',
     c.available ? 'up' : 'pending'),
    card('Corpus auto', co.available ? `<div class="metrics"><span>cartes <b>${co.lines}</b></span>
     <span>${Object.entries(co.backends||{}).map(([k,v])=>k+' '+v).join(' · ')}</span></div>
     <div class="mut">MOS ${mos.cards}/${mos.target}</div>${gauge(Math.round(100*mos.cards/mos.target))}
     <div class="mut">maj ${esc(co.mtime||'')}</div>` : '<div class="mut">aucun corpus généré</div>', co.available ? 'up' : 'pending'),
    card('Boucles', Object.keys(lp).length ? Object.entries(lp).map(([k,v]) =>
     `<div class="metrics"><span>${esc(k)} <b>×${v.runs||0}</b></span><span class="mut">${esc(v.last||'')}</span></div>`).join('')
     : '<div class="mut">aucune boucle exécutée</div>', 'done'),
  ].join('');
  $('#divs').innerHTML = (c.divergence_list || []).map(t => `<li><span class="when">⚠</span><span>${esc(t)}</span></li>`).join('')
    || '<li class="mut">aucune divergence listée</li>';
}

async function refreshLlm() {
  const d = await j('/api/llm'), o = d.ollama || {}, v = d.voice || {};
  $('#llmcards').innerHTML = [
    card('Ollama', o.available ? `<div class="metrics"><span>v <b>${esc(o.version)}</b></span>
     <span>modèles <b>${(o.models||[]).length}</b></span><span>chargés <b>${(o.loaded||[]).length}</b></span></div>
     ${(o.models||[]).map(m=>`<div class="mut">${esc(m.name)} — ${m.gb} Go ${esc(m.param)} ${esc(m.quant)}</div>`).join('')}
     ${o.biggest_gb && !o.fits ? '<div class="res err">⚠ RAM insuffisante pour le plus gros modèle</div>' : ''}`
     : `<div class="mut">indisponible sur ${esc(o.url||'')}</div>`, o.available ? 'up' : 'down'),
  ].join('');
  const b = (x, n) => card(n, x && x.ok !== false ? `<div class="metrics"><span>backend <b>${esc(x.backend||'?')}</b></span>
     <span>prêt <b>${x.ready?'oui':'non'}</b></span>${x.profile?`<span>profil <b>${esc(x.profile)}</b></span>`:''}</div>`
     : '<div class="mut">service arrêté</div>', x && x.ok !== false ? 'up' : 'pending');
  $('#voicecards').innerHTML = [b(v.tts, 'TTS (conteur)'), b(v.asr, 'ASR (voix joueur)'),
    card('Démarrer', `<div class="row" style="gap:9px;flex-wrap:wrap">
     <button class="go sm" onclick="run('tts-start')">TTS ▶</button>
     <button class="go sm" onclick="run('asr-start')">ASR ▶</button></div>`, '')].join('');
}
const askOllama = () => run('ollama-generate', { model: $('#omodel').value, prompt: $('#oprompt').value });

async function refreshRepo() {
  const r = await j('/api/repo');
  $('#repocards').innerHTML = [
    card('Branche', `<div class="metrics"><span><b>${esc(r.branch)}</b></span>
     <span>↑${r.ahead} ↓${r.behind}</span><span>modifiés <b>${r.dirty_count}</b></span></div>
     ${r.diffstat ? `<div class="mut">${esc(r.diffstat)}</div>` : ''}`, r.behind ? 'pending' : 'up'),
    card('Fichiers modifiés', (r.dirty || []).length ? `<pre class="log">${esc((r.dirty||[]).join('\n'))}</pre>`
     : '<div class="mut">arbre propre</div>', (r.dirty || []).length ? 'warn' : 'up'),
  ].join('');
  $('#commits').innerHTML = (r.commits || []).map(c => `<li><span class="when">${esc(c.when)}</span>
    <span><code>${esc(c.hash)}</code> ${esc(c.subject)}</span></li>`).join('');
}

async function refreshHost() {
  const h = await j('/api/host'), m = h.mem || {};
  const svc = Object.entries(h.services || {}).map(([k, v]) => {
    const cls = v === 'active' ? 'up' : (v === 'inactive' && k === 'merlin-runner') ? 'idle' : (v === 'n/a' ? 'idle' : 'down');
    return `<span class="badge ${cls}">${esc(k)} ${esc(v)}</span>`; }).join(' ');
  $('#hostcards').innerHTML = [
    card('Ressources', `<div class="metrics"><span>arch <b>${esc(h.arch)}</b></span><span>cœurs <b>${esc(h.cpus)}</b></span>
     <span>load <b>${esc(h.load)}</b></span></div>
     <div class="mut">RAM ${m.available_gb} / ${m.total_gb} Go libres</div>${gauge(m.used_pct||0)}
     <div class="mut">disque ${esc(h.disk?.used||'?')} / ${esc(h.disk?.size||'?')} (${esc(h.disk?.pct||'')}) · ${esc(h.uptime||'')}</div>`,
     (m.used_pct || 0) > 90 ? 'down' : 'up'),
    card('Services', `<div style="display:flex;gap:6px;flex-wrap:wrap;margin-top:4px">${svc}</div>
     <div class="mut" style="margin-top:6px">merlin-runner inactif = normal (idle sans clé API)</div>`, ''),
    card('Provisioning', `<div class="mut">PROVISION_DONE : ${h.provision?.provision_done?'✓':'—'}</div>
     <div class="mut">${esc(h.provision?.models_done||'MODELS_DONE : —')}</div>
     ${h.containers ? `<div class="mut">${h.containers.map(c=>esc(c.name)+': '+esc(c.status)).join('<br>')}</div>` : '<div class="mut">docker n/a</div>'}`, ''),
  ].join('');
  $('#ports').innerHTML = (h.ports || []).map(p => `<div class="card ${p.open?'up':'pending'}">
    <div class="row"><span class="name">${p.port}</span><span class="badge ${p.open?'up':'pending'}">${p.open?'ouvert':'fermé'}</span></div>
    <div class="mut">${esc(p.name)}</div></div>`).join('');
}

async function loadCat() {
  CAT = (await j('/api/launchers')).launchers || [];
  $('#lk').innerHTML = CAT.map(l => `<option value="${l.kind}"${l.available?'':' disabled'}>${esc(l.label)}${l.available?'':' — '+esc(l.reason||'indispo')}</option>`).join('');
  renderParams();
}
function renderParams() {
  const l = CAT.find(x => x.kind === $('#lk').value) || { params: [] };
  $('#lparams').innerHTML = (l.params || []).map(p => p.options
    ? `<label>${p.name}</label><select data-p="${p.name}">${p.options.map(o=>`<option>${esc(o)}</option>`).join('')}</select>`
    : `<label>${p.name}</label><input data-p="${p.name}" value="${esc(p.default??'')}">`).join('')
    || '<div class="mut" style="margin-top:8px">aucun paramètre</div>';
}
function launchGeneric() {
  const params = {};
  document.querySelectorAll('#lparams [data-p]').forEach(e => { if (e.value) params[e.dataset.p] = e.value; });
  run($('#lk').value, params);
}

async function refreshJobs() {
  const d = await j('/api/jobs');
  const busy = Object.entries(d.running || {}).filter(([, v]) => v > 0).map(([k, v]) => k + ' ×' + v).join(' · ');
  $('#jobs').innerHTML = (d.jobs || []).map(job => `<div class="card ${job.status}">
    <div class="row"><span class="name">${esc(job.label||job.kind)} <span class="mut">#${job.id}</span></span>
     <span class="badge ${job.status}">${job.status}</span></div>
    <div class="mut">${esc(job.started_at)}${job.exit_code!=null?' · exit '+job.exit_code:''} · groupe ${esc(job.group)}</div>
    ${job.log_tail ? `<pre class="log">${esc(job.log_tail)}</pre>` : ''}
    <div style="margin-top:8px;display:flex;gap:8px;flex-wrap:wrap">
     <a class="mut" href="/api/job/${job.id}" target="_blank">log complet ↗</a>
     ${job.status === 'running' ? `<button class="go sm stop" onclick="stopJob('${job.id}')">Stop ■</button>` : ''}</div></div>`).join('')
    || '<div class="mut" style="padding:0 16px">aucun job</div>';
  $('#foot').textContent = 'MERLIN STUDIO · VM ORACLE · ' + (busy ? ('OCCUPÉ : ' + busy) : 'LIBRE') + ' · REFRESH 10 S';
  statusJobs(d);
}
const stopJob = async id => { await j('/api/job/' + id + '/stop', { method: 'POST' }); refreshJobs(); };

async function refreshSum() {
  const o = await j('/api/overview'); const m = o.mem || {};
  $('#sum').textContent = `${o.cpus} CŒURS · ${m.available_gb}/${m.total_gb} GO · ${o.models} MODÈLES · ${o.branch}`;
  // Bandeau d'état : ce qui tourne, lisible sans changer d'onglet.
  const chip = (id, cls, html) => { const e = $(id); if (e) { e.className = 'chip ' + cls; e.innerHTML = html; } };
  const pct = m.used_pct || 0;
  chip('#ch-mem', pct >= 90 ? 'crit' : pct >= 75 ? 'warn' : 'ok',
       `RAM <b>${pct}%</b> · ${m.available_gb} GO LIBRES`);
  chip('#ch-llm', o.ollama ? 'ok' : 'idle', `LLM <b>${o.ollama ? o.models : '—'}</b>`);
}

/* Bandeau : jobs (l'état du jeu est mis à jour par game.js, qui le sonde déjà). */
function statusJobs(d) {
  const n = Object.values(d.running || {}).reduce((a, b) => a + b, 0);
  const e = $('#ch-jobs'); if (!e) return;
  e.className = 'chip ' + (n ? 'warn' : 'idle');
  e.innerHTML = `JOBS <b>${n || 0}</b>`;
}
async function refreshCpu() {
  try {
    const h = await j('/api/host');
    const load1 = parseFloat((h.load || '0').split(' ')[0]) || 0;
    const cpus = parseInt(h.cpus, 10) || 4;
    const r = load1 / cpus;
    const e = $('#ch-cpu'); if (!e) return;
    e.className = 'chip ' + (r >= 0.95 ? 'crit' : r >= 0.7 ? 'warn' : 'ok');
    e.innerHTML = `CPU <b>${h.load ? h.load.split(' ')[0] : '?'}</b> / ${cpus}`;
  } catch (e) {}
}

/* handlers appelés depuis les attributs onclick du HTML */
Object.assign(window, { run, runAll, parseProj, genCards, askOllama, renderParams, launchGeneric, stopJob });

function tick() { refreshSum(); refreshCpu(); refreshRun(); refreshPlay(); refreshContent(); refreshLlm(); refreshRepo(); refreshHost(); refreshJobs(); }
loadCat(); tick(); initGame();
setInterval(refreshJobs, 10000);
setInterval(() => { refreshSum(); refreshCpu(); refreshRun(); refreshPlay(); refreshHost(); }, 30000);
setInterval(() => { refreshContent(); refreshLlm(); refreshRepo(); }, 60000);
