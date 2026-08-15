/* MERLIN Studio — logique du portail (extraite d'index.html, re-skin premium).
   Les contrats /api/* sont inchangés ; seules les classes CSS générées changent. */
import { initGame } from '/static/game.js?v=4';

const $ = s => document.querySelector(s), j = (u, o) => fetch(u, o).then(r => r.json());
const esc = s => String(s ?? "").replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const card = (n, b, st) => `<div class="card ${st||''}"><div class="row"><span class="name">${n}</span></div>${b}</div>`;
const gauge = p => { const c = p >= 90 ? 'crit' : p >= 70 ? 'warn' : ''; return `<div class="bar ${c}"><i style="width:${Math.min(p,100)}%"></i></div>`; };
let CAT = [];

// Un seul switcher pour le dock, la sous-nav des Coulisses et les voyants de
// Santé (taper un voyant mène à l'endroit concerné). Les onglets techniques
// n'ont plus de bouton au dock : l'engrenage reste allumé quand on y est.
const TECH_TABS = ['agents', 'godot', 'content', 'jobs', 'system'];
let TAB = 'play';
function showTab(tab) {
  const dockTab = TECH_TABS.includes(tab) ? 'cogs' : tab;
  document.querySelectorAll('.dock button').forEach(x =>
    x.classList.toggle('on', x.dataset.tab === dockTab));
  document.querySelectorAll('.subnav button').forEach(x =>
    x.classList.toggle('on', x.dataset.tab === tab));
  document.querySelectorAll('.pane').forEach(p =>
    p.classList.toggle('on', p.id === 'pane-' + tab));
  window.scrollTo(0, 0);
  // Quitter Jouer doit COUPER le flux vidéo : il se connectait tout seul et ne
  // se coupait jamais, donc le jeu continuait d'encoder pour un écran caché.
  if (TAB === 'play' && tab !== 'play' && window.merlinLeavePlay) window.merlinLeavePlay();
  TAB = tab;
  try { history.replaceState(null, '', '?tab=' + tab); } catch (e) {}
  rafraichirOnglet();
}
document.querySelectorAll('.dock button, .subnav button, .vital').forEach(b =>
  b.onclick = () => showTab(b.dataset.tab));

/* ── Mesure réelle de la barre collante ────────────────────────────────────
   `--topbar-h` était UTILISÉE par studio.css sans être définie nulle part : on
   retombait sur le repli de 132 px face à une barre bien plus haute, et la zone
   de saisie de Parler passait sous la ligne de flottaison. On la mesure. */
function mesurerTopbar() {
  const t = document.querySelector('.topbar');
  if (!t) return;
  document.documentElement.style.setProperty('--topbar-h', Math.ceil(t.getBoundingClientRect().height) + 'px');
}
if (window.ResizeObserver) {
  const ro = new ResizeObserver(mesurerTopbar);
  const t = document.querySelector('.topbar');
  if (t) ro.observe(t);
}
window.addEventListener('orientationchange', () => setTimeout(mesurerTopbar, 200));
window.addEventListener('resize', mesurerTopbar);
mesurerTopbar();

/* Repli des détails techniques : deux pastilles visibles, sept derrière « ⋯ ». */
{
  const bt = document.getElementById('ch-more'), bar = document.getElementById('sysbar');
  if (bt && bar) bt.onclick = () => {
    bar.classList.toggle('replie');
    bt.textContent = bar.classList.contains('replie') ? '⋯' : '×';
    mesurerTopbar();
  };
}

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
  const s = $('#sum'); if (s) s.textContent = `${o.cpus} CŒURS · ${m.available_gb}/${m.total_gb} GO`;
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

/* ── Agents : planification, dernier passage, santé, smoke ─────────────── */
// ── Parler : conversations avec les 101 conseillers + mémoire absolue ────────
let TALK_CONV = null, TALK_POLL = null;
const AV = { merlin: '◈' };
function whoAva(who) { return AV[who] || (WHO_FR[who] ? '◆' : '◈'); }

/* Rouvrir le dernier échange de CET interlocuteur.
   Parler s'ouvrait toujours sur une page blanche : une réponse qui arrivait
   après un rechargement (Merlin écrit en 20-60 s) n'était plus jamais réclamée
   par personne. Mesuré : trois « coucou ! » dans trois fils séparés, trois
   réponses écrites sur le disque, aucune vue. Le bouton « nouveau fil » reste
   le SEUL chemin vers une page blanche. */
async function rouvrirDernierFil(to) {
  TALK_CONV = null;
  renderThread([]);
  try {
    const d = await j('/api/chats');
    const fil = (d.chats || []).find(c => (c.to || 'merlin') === to);
    if (!fil) return;
    TALK_CONV = fil.conv;
    await talkPoll();
    // Le dernier mot est de Maxime : une réponse est encore en vol. On remet
    // l'attente en scène plutôt que de laisser un silence qui ressemble à un bug.
    if (fil.role === 'user') {
      showTyping();
      if (TALK_POLL) clearInterval(TALK_POLL);
      TALK_POLL = setInterval(talkPoll, 5000);
    }
  } catch { }
}

async function initTalk() {
  try {
    const r = await j('/api/roster');
    const sel = $('#talk-to');
    (r.advisers || []).forEach(a => {
      const o = document.createElement('option');
      o.value = a.file; o.textContent = a.title;
      sel.appendChild(o);
    });
    sel.onchange = () => { rouvrirDernierFil(sel.value); };
  } catch { }
  const ta = $('#talk-input');
  ta.addEventListener('input', () => { ta.style.height = 'auto'; ta.style.height = Math.min(ta.scrollHeight, 160) + 'px'; });
  ta.addEventListener('keydown', e => {
    if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); talkSend(); }
  });
  $('#talk-form').addEventListener('submit', e => { e.preventDefault(); talkSend(); });
  $('#talk-new').onclick = () => { TALK_CONV = null; renderThread([]); $('#talk-suggest').classList.remove('gone'); ta.focus(); };
  $('#talk-history').onclick = () => { const d = $('#talk-convs'); d.hidden = !d.hidden; if (!d.hidden) refreshConvs(); };
  // Graver, à tout moment : la mémoire n'est plus un bouton posé sous UN
  // message, c'est un geste disponible pendant toute la conversation.
  const bg = $('#talk-grave');
  if (bg) bg.onclick = () => {
    const z = $('#talk-graver');
    if (z.hidden) ouvrirGravure(); else z.hidden = true;
  };
  window.merlinGraver = graverMaintenant;   // appelé par le bouton du gabarit

  /* ── Le MERLIN du jeu ────────────────────────────────────────────────────
     Un second interlocuteur : le PERSONNAGE, pas l'assistant du studio. Sa
     voix se règle ici même, et le réglage prend effet à la phrase suivante. */
  const sel = $('#talk-to'), bv = $('#talk-voix');
  const majVoixBouton = () => { if (bv) bv.hidden = sel.value !== 'jeu'; };
  // Le duo pilote la conversation. Changer d'interlocuteur OUVRE un fil neuf :
  // l'orchestrateur et le personnage n'ont rien à faire dans le même fil, et
  // mélanger leurs voix rendrait les deux incompréhensibles.
  document.querySelectorAll('.duo-btn').forEach(b => b.onclick = () => {
    if (sel.value === b.dataset.to) return;
    sel.value = b.dataset.to;
    document.querySelectorAll('.duo-btn').forEach(x => x.classList.toggle('on', x === b));
    rouvrirDernierFil(b.dataset.to);
    $('#talk-suggest').classList.toggle('gone', b.dataset.to === 'jeu');
    $('#talk-voix-panel').hidden = true;
    majVoixBouton();
    const ta = $('#talk-input');
    if (ta) {
      ta.placeholder = b.dataset.to === 'jeu'
        ? 'Parler à Merlin — il ne sait rien du studio, il est dans la forêt…'
        : 'Parler au studio — poser une question, régler un agent, prévoir une tâche…';
      ta.focus();
    }
  });
  if (sel) { sel.addEventListener('change', majVoixBouton); majVoixBouton(); }
  if (bv) bv.onclick = async () => {
    const p = $('#talk-voix-panel');
    if (!p.hidden) { p.hidden = true; return; }
    try {
      const d = await j('/api/merlin/voix');
      // La voix du jeu en lecture : on voit CE QU'ON RÈGLE avant de le régler.
      $('#voix-canon').textContent = d.canon_lu ? d.canon
        : '⚠ voix du jeu introuvable — le dépôt du jeu est absent de cette machine.';
      const r = d.reglages || {};
      $('#voix-reglages').textContent = d.canon_lu
        ? `réglages lus dans le jeu : temp ${r.temp} · top_p ${r.top_p} · top_k ${r.top_k} · répétition ${r.repeat_penalty} · contexte ${r.ctx}`
        : '';
      $('#voix-regles').value = ((d.voix || {}).regles || []).join('\n');
      $('#voix-taille').textContent = `l'ensemble pèse ~${d.taille_prompt} tokens`;
      p.hidden = false;
    } catch { annonce('✗ voix illisible', true); }
  };
  window.merlinVoixSave = async () => {
    try {
      const r = await j('/api/merlin/voix', { method: 'POST',
        headers: { 'content-type': 'application/json' },
        // Seul le CALQUE part : identité et ton appartiennent au jeu.
        body: JSON.stringify({
          regles: $('#voix-regles').value.split('\n').map(x => x.trim()).filter(Boolean),
        }) });
      if (r.error) { annonce('✗ ' + r.error, true); return; }
      $('#talk-voix-panel').hidden = true;
      annonce('🜁 ton réglage est posé — parle-lui, tu verras la différence');
    } catch { annonce('✗ réseau', true); }
  };
  document.querySelectorAll('.chat-suggest button').forEach(b =>
    b.onclick = () => { ta.value = b.dataset.q; talkSend(); });
  // Le dernier échange plutôt qu'une page blanche — voir rouvrirDernierFil().
  rouvrirDernierFil(($('#talk-to') || {}).value || 'merlin');
  refreshBoite();
}

/* ── Le courrier des agents, dans Décider ───────────────────────────────────
   Il vivait dans Parler, mêlé à la conversation avec l'orchestrateur, et n'y
   montrait que les 80 premiers caractères — un message coupé en plein milieu
   d'une phrase n'est pas un message. Il est maintenant là où l'on tranche, en
   ENTIER, avec de quoi répondre sans changer de page. */
async function refreshBoite() {
  let d;
  try { d = await j('/api/boite'); } catch { return; }
  const n = d.non_lus || 0;
  const pastille = $('#dock-unread');
  if (pastille) { pastille.textContent = n; pastille.hidden = !n; }
  const win = $('#courrier-win'), liste = $('#courrier-list'), meta = $('#courrier-meta');
  if (!win || !liste) return;
  // On garde les fils NON LUS d'abord, puis ceux qui attendent encore l'agent :
  // un fil auquel on a répondu ne doit pas disparaître tant que rien n'est venu.
  const fils = (d.fils || []).filter(f => f.non_lu || f.attend_agent).slice(0, 5);
  win.hidden = !fils.length;
  if (meta) meta.textContent = n ? `${n} non lu(s)` : (fils.length ? 'en attente de réponse' : '');
  if (!fils.length) return;
  liste.innerHTML = fils.map(f => {
    const qui = esc(WHO_FR[f.qui] || _conseiller(f.qui));
    // `texte` porte le message complet ; `dernier` n'en était qu'un aperçu.
    const corps = esc(f.texte || f.dernier || '').replace(/\n/g, '<br>');
    const etat = f.non_lu ? '<span class="pill">nouveau</span>'
      : '<span class="mut">tu as répondu — il n\'a pas encore repris</span>';
    return `<div class="jentry courrier" data-conv="${esc(f.conv)}">
      <div class="jhead"><span class="jico">✉</span>
        <span class="jtitle"><b>${qui}</b> — ${esc(f.sujet || '')}</span>
        <span class="jago">${etat}</span></div>
      <div class="jdetail courrier-texte">${corps}</div>
      <div class="row" style="gap:6px;margin-top:8px;align-items:flex-start">
        <textarea class="courrier-rep" rows="2" style="flex:1"
          placeholder="Lui répondre…"></textarea>
        <button class="go sm courrier-envoi">Répondre</button>
      </div>
      <button class="go sm ghost courrier-ouvrir" style="margin-top:6px">Voir tout le fil</button>
    </div>`;
  }).join('');
  liste.querySelectorAll('.courrier').forEach(carte => {
    const conv = carte.dataset.conv;
    const zone = carte.querySelector('.courrier-rep');
    const envoi = carte.querySelector('.courrier-envoi');
    carte.querySelector('.courrier-ouvrir').onclick = () => ouvrirFil(conv);
    envoi.onclick = async () => {
      const texte = zone.value.trim();
      if (!texte) { zone.focus(); return; }
      envoi.disabled = true; envoi.textContent = '…';
      try {
        const r = await j('/api/chat', {
          method: 'POST', headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ conv, text: texte }) });
        if (r.error) throw new Error(r.error);
        // On ne vide la saisie qu'une fois le message ACCEPTÉ : la vider avant
        // l'envoi a déjà fait perdre des réponses de Maxime.
        zone.value = '';
        await j('/api/boite/lu', { method: 'POST', headers: { 'content-type': 'application/json' },
                                   body: JSON.stringify({ conv }) });
        annonce('✉ envoyé — il répond dans un instant');
        refreshBoite();
      } catch (e) {
        annonce('✗ ' + (e.message || 'réseau') + ' — ton texte est resté', true);
        envoi.disabled = false; envoi.textContent = 'Répondre';
      }
    };
  });
}

function _conseiller(f) {
  // « .claude/agents/gd_difficulty.md » → « gd difficulty »
  return String(f || '').replace(/^.*\//, '').replace(/\.md$/, '').replace(/_/g, ' ') || 'un agent';
}

async function ouvrirFil(conv) {
  TALK_CONV = conv;
  const box = $('#talk-convs'); if (box) box.hidden = true;
  const sug = $('#talk-suggest'); if (sug) sug.classList.add('gone');
  showTab('talk');
  await talkPoll();
  // Marquer lu APRÈS affichage : si le rendu échoue, le fil reste signalé.
  try {
    await j('/api/boite/lu', { method: 'POST', headers: { 'content-type': 'application/json' },
                               body: JSON.stringify({ conv }) });
  } catch {}
  refreshBoite();
}

async function refreshConvs() {
  try {
    const d = await j('/api/chats');
    const box = $('#talk-convs');
    box.innerHTML = (d.chats || []).map(c => {
      const label = c.conv.startsWith('conseil-')
        ? '🏛 Conseil du ' + c.conv.slice(14) + '/' + c.conv.slice(12, 14)
        : '💬 ' + (c.last ? c.last.slice(0, 28) : c.conv);
      return `<button data-conv="${esc(c.conv)}" class="${c.conv === TALK_CONV ? 'on' : ''}">${label}</button>`;
    }).join('') || '<div class="mut" style="padding:10px">aucune conversation</div>';
    box.querySelectorAll('button').forEach(b => b.onclick = async () => {
      TALK_CONV = b.dataset.conv; box.hidden = true;
      $('#talk-suggest').classList.add('gone');
      await talkPoll();
    });
  } catch { }
}

function renderThread(msgs) {
  const th = $('#talk-thread');
  if (!msgs.length) {
    th.innerHTML = `<div class="welcome"><b>◈ Parler au studio</b>
      Pose une question sur le jeu, règle un agent, entretiens la mémoire,
      crée un nouvel agent ou prévois une tâche de développement.<br><br>
      Le studio réfléchit puis te répond, et propose des actions à valider d'un tap.</div>`;
    return;
  }
  th.innerHTML = msgs.map(m => {
    const me = m.role === 'user';
    const list = m.actions || [];
    // « En parler » n'est pas une étape de plan : elle n'exécute rien côté
    // serveur, la compter ferait promettre à « Tout lancer » ce qu'il ne fait pas.
    const pending = list.filter(a => !a.done && a.verb !== 'chat.parler').length;
    // `data-label` : le bouton doit pouvoir REDIRE ce qu'il fait après un échec.
    // `data-parler` : cette action-là n'exécute rien, elle amorce la saisie.
    const acts = list.map(a => a.done
      ? `<span class="act done">✓ ${esc(a.label)}</span>`
      : `<button class="act" data-aid="${esc(a.id)}" data-label="${esc(a.label)}"${
          a.verb === 'chat.parler' ? ` data-parler="${esc(a.value || '')}"` : ''
        }>${esc(a.label)}</button>`).join('');
    // Plusieurs actions en attente = un PLAN : un bouton « Tout lancer » en tête.
    const plan = pending > 1
      ? `<button class="act plan" data-plan="${esc(m.t || '')}">⚡ Tout lancer (${pending} étapes)</button>`
      : '';
    return `<div class="turn ${me ? 'me' : 'them'}">
      <div class="ava">${me ? '🙂' : whoAva(m.who)}</div>
      <div><div class="bubble">${esc(m.text)}</div>
        ${acts ? `<div class="actbtns">${plan}${acts}</div>` : ''}</div></div>`;
  }).join('');
  th.querySelectorAll('button.act[data-aid]').forEach(b =>
    b.onclick = () => doChatAction(b.dataset.aid, b));
  th.querySelectorAll('button.act[data-plan]').forEach(b =>
    b.onclick = () => doChatPlan(b.dataset.plan, b));
  th.scrollTop = th.scrollHeight;
}

/* Merlin s'anime quand il parle : la rune s'accélère pendant qu'il écrit, et
   revient à son souffle lent quand il a fini. C'est le même signal que dans le
   jeu — on ne fait pas semblant d'attendre, on montre qu'il pense. */
function merlinParle(oui) {
  const av = $('#merlin-av');
  if (av) av.classList.toggle('parle', !!oui);
}

function showTyping() {
  const th = $('#talk-thread');
  const jeu = $('#talk-to') && $('#talk-to').value === 'jeu';
  merlinParle(jeu);
  th.insertAdjacentHTML('beforeend',
    `<div class="turn them typing" id="typing"><div class="ava">${jeu ? '🜁' : '◈'}</div>
      <div class="bubble">${jeu ? 'Merlin cherche ses mots' : 'le studio réfléchit'}<span class="dots"></span></div></div>`);
  th.scrollTop = th.scrollHeight;
}

async function doChatAction(aid, btn) {
  // « En parler » n'exécute rien : il ouvre la conversation. On amorce la
  // saisie avec le sujet et on rend la main à Maxime — ce sont SES mots qui
  // partiront, pas une phrase écrite à sa place.
  if (btn.dataset.parler !== undefined) {
    const inp = $('#talk-input');
    if (inp) {
      inp.value = btn.dataset.parler;
      inp.focus();
      try { inp.setSelectionRange(inp.value.length, inp.value.length); } catch (e) {}
      inp.dispatchEvent(new Event('input'));
    }
    btn.classList.add('done'); btn.textContent = '✓ à toi d\'écrire';
    return;
  }
  btn.disabled = true; btn.textContent = '…';
  try {
    const r = await j('/api/chat/action', { method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ conv: TALK_CONV, action_id: aid }) });
    if (r.error) {
      // Le bouton doit REDEVENIR utilisable et redire ce qu'il fait : laisser
      // « … » sur un échec transformait une erreur en bouton mort.
      btn.disabled = false;
      btn.textContent = btn.dataset.label || 'réessayer';
      annonce('✗ ' + r.error, true);
      return;
    }
    await talkPoll(); refreshAgents(); refreshMemory(); refreshCrew();
  } catch {
    btn.disabled = false;
    btn.textContent = btn.dataset.label || 'réessayer';
    annonce('✗ réseau — réessaie', true);
  }
}

/* Un mot d'état dans le fil, à la place d'`alert()` : sur mobile une alerte
   bloque tout et ne dit rien de plus. */
function annonce(texte, erreur) {
  const th = $('#talk-thread');
  if (!th) { alert(texte); return; }
  const d = document.createElement('div');
  d.className = 'turn them';
  d.innerHTML = `<div class="ava">◈</div><div class="bubble${erreur ? ' err' : ''}">${esc(texte)}</div>`;
  th.appendChild(d);
  th.scrollTop = th.scrollHeight;
}

/* ── Graver, à tout moment ───────────────────────────────────────────────────
   La mémoire ne se remplit plus par un bouton posé sous UN message : elle est
   toujours à portée, dans l'en-tête du fil. On propose un texte tiré de
   l'échange, Maxime le corrige, et ce sont ses mots qui sont gravés. */
function ouvrirGravure(suggestion) {
  const zone = $('#talk-graver');
  if (!zone) return;
  zone.hidden = false;
  const inp = zone.querySelector('input');
  inp.value = suggestion || _dernierEchange();
  inp.focus();
  try { inp.setSelectionRange(inp.value.length, inp.value.length); } catch (e) {}
}
function _dernierEchange() {
  // Ce que Maxime vient de dire prime : c'est sa décision qu'on garde, pas le
  // commentaire de l'agent.
  const miens = document.querySelectorAll('#talk-thread .turn.me .bubble');
  if (miens.length) return miens[miens.length - 1].textContent.trim().slice(0, 180);
  const eux = document.querySelectorAll('#talk-thread .turn.them .bubble');
  return eux.length ? eux[eux.length - 1].textContent.trim().slice(0, 180) : '';
}
async function graverMaintenant() {
  const zone = $('#talk-graver'), inp = zone.querySelector('input');
  const titre = (inp.value || '').trim();
  if (titre.length < 3) { inp.focus(); return; }
  const btn = zone.querySelector('button.go');
  btn.disabled = true; btn.textContent = '…';
  try {
    const r = await j('/api/memory', { method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ title: titre, kind: 'règle',
                             detail: `gravé depuis le fil ${TALK_CONV}` }) });
    if (r.error) { annonce('✗ ' + r.error, true); return; }
    zone.hidden = true; inp.value = '';
    annonce('📌 gravé dans la mémoire : « ' + titre + ' »');
    refreshMemory();
  } catch { annonce('✗ réseau', true); }
  finally { btn.disabled = false; btn.textContent = '📌 Graver'; }
}
async function doChatPlan(msgTs, btn) {
  btn.disabled = true; btn.textContent = 'exécution du plan…';
  try {
    const r = await j('/api/chat/plan', { method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ conv: TALK_CONV, msg_ts: msgTs }) });
    if (r.error) { btn.disabled = false; alert('✗ ' + r.error); return; }
    await talkPoll(); refreshAgents(); refreshMemory(); refreshCrew();
  } catch { btn.disabled = false; }
}

async function talkPoll() {
  if (!TALK_CONV) return;
  try {
    const d = await j('/api/chat/' + TALK_CONV);
    const msgs = d.messages || [];
    renderThread(msgs);
    const last = msgs[msgs.length - 1];
    if (last && last.role !== 'user' && TALK_POLL) {
      clearInterval(TALK_POLL); TALK_POLL = null;
      merlinParle(false);          // il a répondu : la rune reprend son souffle
    }
  } catch { }
}

async function talkSend() {
  const ta = $('#talk-input'), text = ta.value.trim();
  if (!text) return;
  ta.value = ''; ta.style.height = 'auto';
  $('#talk-suggest').classList.add('gone');
  try {
    const r = await j('/api/chat', { method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ conv: TALK_CONV || undefined, text, to: $('#talk-to').value }) });
    // Un refus ne doit JAMAIS coûter ses mots à Maxime : la zone est vidée
    // avant l'envoi (pour le confort), le serveur peut répondre 400, et le
    // texte n'est enregistré nulle part. On le rend.
    if (r.error) { ta.value = text; ta.style.height = 'auto'; annonce('✗ ' + r.error, true); return; }
    TALK_CONV = r.conv;
    await talkPoll();
    showTyping();
    if (TALK_POLL) clearInterval(TALK_POLL);
    TALK_POLL = setInterval(talkPoll, 5000);
  } catch {
    ta.value = text; ta.style.height = 'auto';
    annonce('✗ réseau — ton message est resté dans la zone de saisie', true);
  }
}
if ($('#talk-form')) initTalk();
const memBtn = $('#mem-add');   // la Mémoire vit dans Décider, pas dans Parler
if (memBtn) memBtn.onclick = async () => {
  const inp = $('#mem-input'), t = inp.value.trim();
  if (t.length < 3) return;
  const r = await j('/api/memory', { method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ title: t, kind: 'règle' }) });
  if (!r.error) { inp.value = ''; refreshMemory(); }
};

// ── Santé : cinq voyants, trois couleurs, zéro jargon ────────────────────────
function vital(id, state, text) {          // state: up (vert) | down (rouge) | idle
  const e = $(id);
  if (e) { e.className = 'vital ' + state; e.querySelector('.val').textContent = text; }
}
async function refreshHealth() {
  try {
    const g = await j('/api/game');
    vital('#v-game', g.vnc_open ? 'up' : 'idle', g.vnc_open ? 'en cours' : 'prêt');
  } catch { vital('#v-game', 'down', 'injoignable'); }
  try {
    const d = await j('/api/agents');
    const ko = (d.agents || []).filter(a => a.enabled && a.ok === false).length;
    vital('#v-agents', ko ? 'down' : 'up', ko ? ko + ' en panne' : 'tous OK');
    const c = (d.ci || [])[d.ci.length - 1];
    if (c) vital('#v-ci', (c.scenes_failing === 0 && c.boot_ok) ? 'up' : 'down',
                 (c.scenes_failing === 0 && c.boot_ok) ? 'vert' : 'rouge');
    const b = d.billing || {};
    if (b.total === 0) vital('#v-euro', 'up', '0,00 €');
    else if (typeof b.total === 'number') vital('#v-euro', 'down', b.total.toFixed(2) + ' € !');
  } catch { /* les voyants gardent leur dernier état */ }
  try {
    const p = await j('/api/proposals');
    const n = (p.counts || {}).pending || 0;
    vital('#v-decide', n ? 'up' : 'idle', n ? n + ' à trancher' : 'rien');
    const pill = $('#dock-pending');
    if (pill) { pill.hidden = !n; pill.textContent = n; }
  } catch { }
  await refreshMoteur();
}

// ── La plume de Merlin : à quelle vitesse le moteur du jeu écrit-il ? ────────
// Le voyant répond à UNE question — les titres de quête viennent-ils du modèle,
// ou des trois écrits en dur ? Les nombres en dessous disent pourquoi.
// `modele_gagne === null` = juge vide : on n'a pas mesuré, on ne prétend rien.
async function refreshMoteur() {
  let m;
  try { m = await j('/api/moteur'); } catch { vital('#v-moteur', 'down', 'injoignable'); return; }
  const box = $('#moteur-win');
  if (!m.mesure) {
    vital('#v-moteur', 'idle', m.raison === 'jamais mesuré' ? 'pas mesurée' : 'mesure ratée');
    if (box) box.hidden = true;
    return;
  }
  const gagne = m.modele_gagne;
  vital('#v-moteur', gagne === true ? 'up' : gagne === false ? 'down' : 'idle',
        gagne === true ? m.tok_par_s + ' mots/s' : gagne === false ? 'secours' : 'à vérifier');
  if (!box) return;
  box.hidden = false;
  $('#moteur-meta').textContent = `${esc(m.depuis || m.quand || '')}${m.commit ? ' · ' + esc(m.commit) : ''}`;
  const verdict = gagne === true
    ? '<div class="res ok">Les titres de quête viennent du modèle.</div>'
    : gagne === false
      ? '<div class="res err">⚠ Les titres écrits en dur se sont affichés à la place du modèle.</div>'
      : '<div class="res">Verdict indisponible : aucun titre de secours connu à comparer.</div>';
  $('#moteur-body').innerHTML = [
    card('Réveil de Merlin', `<div class="metrics"><span><b>${m.charge_s}</b> s</span></div>
      <div class="res">Temps de chargement du modèle au démarrage du jeu.</div>`,
      m.charge_s > 120 ? 'warn' : 'up'),
    card('Vitesse d\'écriture', `<div class="metrics"><span><b>${m.tok_par_s}</b> mots/s</span></div>
      <div class="res">Remplace le « 1 mot/s » hérité d'Ollama, qui n'a jamais concerné ce moteur.</div>`,
      m.tok_par_s >= 5 ? 'up' : m.tok_par_s >= 2 ? 'warn' : 'down'),
    card('Trois quêtes', `<div class="metrics"><span><b>${m.quetes_s}</b> s</span></div>
      ${verdict}`, gagne === true ? 'up' : gagne === false ? 'down' : ''),
  ].join('');
}

// ── Journal de bord : les derniers développements, en français, avec preuves ─
// Trois choses très différentes partageaient l'ampoule 💡 : une décision qui
// t'attend, une décision que tu as prise, un geste de la chaîne. Impossible de
// les distinguer d'un coup d'œil dans un mur de vingt lignes.
const J_ICON = { commit: '✎', ci: '🛠', proposal: '💡', playtest: '🎮',
                 corpus: '🏭', auto: '⚙' };
function agoTxt(m) {
  return m < 1 ? "à l'instant" : m < 60 ? `il y a ${m} min`
       : m < 1440 ? `il y a ${Math.round(m / 60)} h` : `il y a ${Math.round(m / 1440)} j`;
}
async function refreshJournal() {
  let d;
  try { d = await j('/api/journal'); } catch { return; }
  const ev = d.events || [];
  $('#journal-meta').textContent = ev.length ? `${ev.length} événement(s) · 48 h` : 'rien encore';
  if (!ev.length) return;
  $('#journal-list').innerHTML = ev.map(e => `
    <div class="jentry">
      <div class="jhead"><span class="jico">${
        e.kind === 'proposal' && /^Tu as/.test(e.title || '') ? '🗳'
        : J_ICON[e.kind] || '·'}</span>
        <span class="jtitle">${esc(e.title)}</span>
        <span class="jago">${agoTxt(e.ago_min)}</span></div>
      ${e.detail ? `<div class="jdetail">${esc(e.detail)}</div>` : ''}
      ${e.shot ? `<img class="jshot" loading="lazy" src="${esc(e.shot)}" alt="capture">` : ''}
    </div>`).join('');
}

/* ── Le récit gravé : chapitres + fils en cours ─────────────────────────────
   Le journal ne se recalculait qu'à la volée sur 48 h : dès qu'une source était
   purgée, l'événement disparaissait pour toujours. Ici on lit le registre. */
function _md(s) {
  // Micro-rendu : **gras** et *italique*, rien d'autre. La chaîne est déjà
  // échappée en amont — on n'introduit aucune balise venant des données.
  return esc(s)
    .replace(/\*\*(.+?)\*\*/g, '<b>$1</b>')
    .replace(/(^|[\s(])\*([^*\n]+)\*/g, '$1<i>$2</i>')
    .replace(/\n/g, '<br>');
}
async function refreshChapitres() {
  const liste = $('#chap-list'), filsBox = $('#fils-list');
  if (!liste) return;
  let d;
  try { d = await j('/api/chapitres'); } catch { return; }
  const ch = d.chapitres || [], fils = d.fils_ouverts || [];

  const fm = $('#fils-meta');
  if (fm) fm.textContent = fils.length ? `${fils.length} en suspens` : 'rien en suspens';
  if (filsBox) filsBox.innerHTML = fils.length ? fils.map(f => {
    // `libelle` est l'état COURANT du fil (dernier fait connu), pas le sujet
    // gelé à son ouverture : c'est ce que Maxime veut lire.
    const n = (f.jours || []).length;
    const duree = n <= 1 ? 'ouvert aujourd\'hui'
      : `${n} jours · depuis le ${esc(f.ouvert || '?')}`;
    const quoi = f.libelle || f.dernier || f.sujet || f.cle;
    const rouvert = f.rouvert ? ' · revenu' : '';
    return `<div class="jentry"><div class="jhead">
        <span class="jico">🧵</span><span class="jtitle err">${esc(quoi)}</span>
        <span class="jago">${duree}${rouvert}</span></div>
      ${f.sujet && f.sujet !== quoi ? `<div class="jdetail">au départ : ${esc(f.sujet)}</div>` : ''}</div>`;
  }).join('') : '<div class="mut">rien en suspens — tout ce qui s\'est ouvert s\'est refermé</div>';

  const cm = $('#chap-meta');
  if (cm) cm.textContent = ch.length
    ? `${ch.length} chapitre(s) · le récit garde tout` : 'aucun chapitre encore';
  if (!ch.length) return;
  liste.innerHTML = ch.map((c, i) => `
    <article class="chapitre${i ? ' vieux' : ''}">
      <div class="chap-texte">${_md(c.texte || '')}</div>
      ${(c.images || []).map(u =>
        `<img class="jshot" loading="lazy" src="${esc(u)}" alt="le jeu, cette nuit-là">`).join('')}
      <div class="mut chap-pied">${esc(c.redige_par === 'gabarits'
        ? 'rédigé sans modèle' : 'rédigé par ' + (c.redige_par || '?'))}${
        c.cout && c.cout.appels ? ` · ${c.cout.appels} appel(s), ${c.cout.secs || '?'} s` : ''}</div>
    </article>`).join('');
}

// ── Les agents au travail : ce que fait la VM, en direct, dans Décider ───────
// Rôles en français : le nom technique ne dit rien de ce que l'agent FAIT.
const CREW_ROLE = {
  'game-watchdog': 'Relance le jeu s\'il tombe',
  'game-autosync': 'Récupère les nouveaux commits du jeu',
  'health': 'Surveille processeur, mémoire et disque',
  'disk-guard': 'Fait le ménage quand le disque se remplit',
  'tunnel-watch': 'Vérifie que le portail reste joignable',
  'smoke-scenes': 'Teste chaque écran du jeu',
  'ci-commit': 'Teste le jeu à chaque commit, capture à l\'appui',
  'design-council': 'Ouvre le conseil de design du matin',
  'daily-report': 'Résume les dernières 24 heures',
  'journal': 'Écrit le chapitre du jour, sans modèle',
  'relance': 'Rattrape tes messages restés sans réponse',
  'parole': 'Laisse les agents te parler quand ça le mérite',
  'mesures': 'Relève chaque nuit tous les chiffres du jeu',
  'parcours': 'Relit le jeu et tient la carte de ses écrans',
  'gd-run': 'Mesure l\'équilibrage du jeu que tu joues vraiment',
  'coder': 'Écrit du code (Claude, sur demande)',
  'gd-content-gap': 'Écrit des exemples pour entraîner le modèle',
  'gd-balance': 'Mesure l\'équilibrage et propose des ajustements',
  'gd-pacing': 'Simule une run : durée, courbe de vie, marge de survie',
  'gd-economy': 'Vérifie que les récompenses donnent envie de rejouer',
  'gd-audit': 'Traque ce que la bible a supprimé mais qui vit encore',
  'coder-local': 'Applique les corrections que tu as validées',
  'corpus-night': 'Fabrique le jeu d\'entraînement du modèle',
  'playtest-bot': 'Joue au jeu et repère les blocages',
  'billing': 'Vérifie que la facture Oracle reste à zéro',
  'ollama-serve': 'Garde le modèle IA prêt à répondre',
  'llm-bench': 'Mesure la vitesse des modèles',
  'ollama-idle': 'Libère la mémoire des modèles inactifs',
};
async function refreshCrew() {
  const list = $('#crew-list');
  if (!list) return;
  let d;
  try { d = await j('/api/agents'); } catch { return; }
  const ags = (d.agents || []).slice().sort((a, b) => {
    if (a.running !== b.running) return a.running ? -1 : 1;          // au travail d'abord
    if (a.enabled !== b.enabled) return a.enabled ? -1 : 1;
    return (a.ago_min ?? 1e9) - (b.ago_min ?? 1e9);                  // puis les plus récents
  });
  const busy = ags.filter(a => a.running).length;
  const ko = ags.filter(a => a.enabled && a.ok === false).length;
  $('#crew-meta').textContent = busy
    ? `${busy} au travail en ce moment`
    : (ko ? `${ko} en difficulté` : `${ags.filter(a => a.enabled).length} en veille`);
  list.innerHTML = ags.map(a => {
    const cls = a.running ? 'run' : !a.enabled ? 'off' : a.ok === false ? 'ko' : a.ok ? 'ok' : '';
    const quand = a.running ? 'maintenant'
      : a.ago_min == null ? 'jamais lancé'
      : a.ago_min < 60 ? `il y a ${a.ago_min} min`
      : a.ago_min < 1440 ? `il y a ${Math.round(a.ago_min / 60)} h`
      : `il y a ${Math.round(a.ago_min / 1440)} j`;
    // Un agent muet doit DIRE pourquoi. Son dernier résumé porte déjà la raison
    // en français (« jeu en cours — la chaîne cède les 4 cœurs », « aucun palier
    // utilisable »…) : on l'affiche au lieu de retomber sur la description du rôle.
    const quoi = a.running ? 'travaille en ce moment…'
      : (a.summary || CREW_ROLE[a.id] || a.desc || '').slice(0, 140);
    const muet = !a.running && a.enabled && (a.ok === false ||
      /suspendu|rien d'applicable|indisponible|absent|sauté|vide|aucun/i.test(a.summary || ''));
    return `<div class="crew-row" data-row="${esc(a.id)}">
      <span class="crew-dot ${cls}"></span>
      <div class="crew-main">
        <div class="crew-name">${esc(a.label)}${a.running ? '<span class="now">en cours</span>' : ''}</div>
        <div class="crew-what${muet ? ' err' : ''}" title="${esc(CREW_ROLE[a.id] || a.desc || '')}">${esc(quoi)}</div>
        <div class="crew-log mut" data-logbox="${esc(a.id)}" style="display:none"></div>
      </div>
      <div class="crew-when">${esc(quand)}<b>${esc(a.next_run || '')}</b></div>
      <button class="crew-go" data-log="${esc(a.id)}" title="Voir son journal">📄</button>
      <button class="crew-go" data-agent="${esc(a.id)}" ${a.running ? 'disabled' : ''}
        title="Lancer maintenant">▶</button></div>`;
  }).join('');
  list.querySelectorAll('button[data-agent]').forEach(b => b.onclick = async () => {
    b.disabled = true; b.textContent = '…';
    await run('agent-run', { id: b.dataset.agent });
    setTimeout(refreshCrew, 1500);
  });
  // Journal complet d'un agent : la seule façon de comprendre un échec sans SSH.
  list.querySelectorAll('button[data-log]').forEach(b => b.onclick = async () => {
    const box = list.querySelector(`[data-logbox="${CSS.escape(b.dataset.log)}"]`);
    if (!box) return;
    if (box.style.display !== 'none') { box.style.display = 'none'; return; }
    box.style.display = ''; box.textContent = 'lecture du journal…';
    try {
      const d = await j(`/api/agent/${encodeURIComponent(b.dataset.log)}/log`);
      box.innerHTML = d.text
        ? `<pre class="log" style="max-height:220px;margin:6px 0">${esc(d.text)}</pre>`
        : `<div class="mut">${esc(d.note || d.error || 'journal vide')}</div>`;
    } catch { box.textContent = 'journal illisible'; }
  });
}

// ── Mémoire du jeu : élément de décision, affiché dans Décider ───────────────
async function refreshMemory() {
  try {
    const d = await j('/api/memory');
    const meta = $('#mem-meta');
    if (meta) meta.textContent = `${d.count} souvenir(s) — rien ne s'efface jamais`;
    const MK = { 'décision': '✓', 'rejet': '✗', 'règle': '■', 'contenu': '+', 'intégration': '⇧', 'note': '·' };
    const list = $('#mem-list');
    if (list && (d.entries || []).length) {
      list.innerHTML = d.entries.map(e => `
        <div class="jentry"><div class="jhead"><span class="jico">${MK[e.kind] || '·'}</span>
          <span class="jtitle">${esc(e.title)}</span>
          <span class="jago">${esc((e.t || '').slice(5, 16).replace('T', ' '))}</span></div>
          ${e.detail ? `<div class="jdetail">${esc(e.detail)}</div>` : ''}</div>`).join('');
    }
  } catch { }
}

// ── Propositions : les agents proposent, l'humain tranche en un tap ──────────
// Des noms français à l'écran, jamais des identifiants techniques.
const WHO_FR = { 'gd-content-gap': 'Écrivain de cartes', 'gd-balance': 'Équilibreur',
  'gd-pacing': 'Rythmeur', 'gd-economy': 'Trésorier', 'gd-audit': 'Auditeur bible', 'gd-run': 'Arbitre de la run',
  'coder-local': 'Codeur', 'playtest-bot': 'Robot testeur', 'billing': 'Comptable',
  'corpus-night': 'Atelier d’écriture', 'selftest': 'Test' };
const KIND_FR = { balance: 'équilibrage', content: 'nouvelle carte', design: 'game design',
  ux: 'ergonomie', bug: 'anomalie', infra: 'plateforme', merge: 'intégration' };
// ── « Ce matin » : ce qu'on lit avant tout le reste ─────────────────────────
const BRIEF_ROWS = [
  ['nuit', '🌙', 'Cette nuit'],
  ['attente', '👉', 'En attente de toi'],
  ['bloque', '⛔', 'Bloqué'],
  ['jeu', '🎮', 'Le jeu'],
];
async function refreshBriefing() {
  const list = $('#brief-list');
  if (!list) return;
  let d;
  try { d = await j('/api/briefing'); } catch { return; }
  const attente = (d.attente || []).length;
  const meta = $('#brief-meta');
  if (meta) meta.textContent = new Date().toLocaleDateString('fr-FR',
    { weekday: 'long', day: 'numeric', month: 'long' });
  list.innerHTML = BRIEF_ROWS.map(([k, ico, titre]) => {
    const lignes = d[k] || [];
    if (!lignes.length) return '';
    const alerte = k === 'bloque' && !/rien de bloqué/.test(lignes[0]);
    return `<div class="jentry"><div class="jhead">
        <span class="jico">${ico}</span>
        <span class="jtitle${alerte ? ' err' : ''}">${titre}</span></div>
      <div class="jdetail">${lignes.map(esc).join(' · ')}</div></div>`;
  }).join('') || '<div class="mut">rien à signaler</div>';
}

// ── Courbe d'avancement : le jeu progresse-t-il vraiment ? ──────────────────
const PROG_SERIES = [
  ['cartes', 'Cartes du recueil'],
  ['propositions_acceptees', 'Décisions prises'],
  ['missions_faites', 'Corrections appliquées'],
  ['propositions_attente', 'En attente de toi'],
];
function sparkline(vals) {
  // Sparkline en caractères : lisible sur mobile, zéro dépendance, zéro image.
  const B = '▁▂▃▄▅▆▇█';
  const ok = vals.filter(v => typeof v === 'number');
  if (!ok.length) return '—';
  const lo = Math.min(...ok), hi = Math.max(...ok);
  return vals.map(v => typeof v !== 'number' ? ' '
    : B[hi === lo ? 3 : Math.round((v - lo) / (hi - lo) * (B.length - 1))]).join('');
}
async function refreshProgress() {
  const list = $('#prog-list');
  if (!list) return;
  let d;
  try { d = await j('/api/progress'); } catch { return; }
  const pts = d.points || [];
  const meta = $('#prog-meta');
  if (meta) meta.textContent = pts.length ? `${pts.length} jour(s) relevé(s)` : 'pas encore de relevé';
  if (!pts.length) return;
  list.innerHTML = PROG_SERIES.map(([k, titre]) => {
    const vals = pts.map(p => p[k]);
    const der = vals[vals.length - 1], prem = vals.find(v => typeof v === 'number');
    const delta = (typeof der === 'number' && typeof prem === 'number') ? der - prem : null;
    const fleche = delta === null ? '' : delta > 0 ? `+${delta}` : delta < 0 ? `${delta}` : 'stable';
    return `<div class="crew-row">
      <div class="crew-main"><div class="crew-name">${titre}</div>
        <div class="crew-what" style="font-family:monospace;font-size:15px;letter-spacing:1px"
          >${sparkline(vals)}</div></div>
      <div class="crew-when">${der ?? '—'}<b>${fleche}</b></div></div>`;
  }).join('');
}

// ── Le parcours d'une décision : acceptée → patchée → smoke → poussée ───────
const STEP_ICO = { 'acceptée': '✓', 'patchée': '✎', 'smoke vert': '✅', 'smoke sauté': '⏭',
  'smoke rouge': '⛔', 'poussée': '⇧', 'poussée KO': '⚠', 'fusionnée': '🎮',
  'écartée': '✗', 'sans suite automatique': '💬' };
function renderSuivi(suivi) {
  const list = $('#suivi-list');
  if (!list) return;
  const meta = $('#suivi-meta');
  const abouties = (suivi || []).filter(s => s.step === 'fusionnée').length;
  if (meta) meta.textContent = (suivi || []).length
    ? `${suivi.length} décision(s) · ${abouties} arrivée(s) dans le jeu` : 'aucune décision';
  if (!(suivi || []).length) { list.innerHTML = '<div class="mut">rien de décidé pour l\'instant</div>'; return; }
  list.innerHTML = suivi.map(s => {
    const fil = (s.trail || []).map(e =>
      `<span title="${esc(e.detail || '')}">${STEP_ICO[e.step] || '·'} ${esc(e.step)}</span>`)
      .join(' <span class="mut">→</span> ') || '<span class="mut">aucune étape</span>';
    const dernier = (s.trail || [])[s.trail.length - 1];
    const souci = /rouge|KO|écartée|sans suite/.test(s.step || '');
    return `<div class="jentry"><div class="jhead">
        <span class="jico">${STEP_ICO[s.step] || '·'}</span>
        <span class="jtitle${souci ? ' err' : ''}">${esc(s.title || '')}</span>
        <span class="jago">${esc((s.decided_at || '').slice(5, 16).replace('T', ' '))}</span></div>
      <div class="jdetail">${fil}</div>
      ${dernier && dernier.detail ? `<div class="mut">${esc(dernier.detail)}</div>` : ''}</div>`;
  }).join('');
}

async function refreshProposals() {
  refreshMemory();   // la Mémoire est un élément de décision : elle vit ici
  refreshCrew();     // et l'activité des agents, en direct
  refreshBriefing(); // et « Ce matin » ouvre l'écran
  refreshProgress();
  let d;
  try { d = await j('/api/proposals'); } catch { return; }
  const n = (d.counts || {}).pending || 0;
  const chip = $('#ch-prop');
  chip.className = 'chip ' + (n ? 'up' : 'idle');
  chip.textContent = '💡 ' + n;
  renderSuivi(d.suivi);
  $('#ideas-meta').textContent = n
    ? `${n} en attente · ${(d.counts||{}).accepted||0} acceptées · ${(d.counts||{}).rejected||0} rejetées`
    : 'rien en attente';
  const list = $('#ideas-list');
  if (!n) { list.innerHTML = '<div class="mut">aucune proposition — les agents tournent la nuit</div>'; return; }
  list.innerHTML = (d.pending || []).map(p => {
    const ev = (p.evidence || []).map(e =>
      `<div class="mut">• ${esc(e.metric || e.source || '')} ${e.quote ? '— « ' + esc(String(e.quote).slice(0,120)) + ' »' : ''}</div>`).join('');
    return `<div class="card" data-pid="${esc(p.id)}" style="margin-bottom:12px">
      <div class="row"><span class="name">${esc(p.title)}</span>
        <span class="badge ${p.kind === 'bug' ? 'down' : 'up'}">${esc(KIND_FR[p.kind] || p.kind)}</span></div>
      <div class="mut" style="margin:4px 0 8px">${esc(p.claim)}</div>
      <div class="metrics"><span>proposé par : ${esc(WHO_FR[p.agent] || p.agent)}</span>
        <span>fiabilité ${Math.round((p.confidence || 0) * 100)}%</span></div>
      <pre class="log" style="max-height:150px;margin-top:8px">${esc((p.change || {}).summary || '')}${
        (p.change || {}).target ? '\n\ncible : ' + esc(p.change.target) : ''}</pre>
      ${ev ? `<details style="margin-top:6px"><summary class="mut">preuves</summary>${ev}</details>` : ''}
      <div class="row" style="gap:8px;margin-top:10px">
        <button class="go" style="flex:1;min-height:48px" data-act="accept">Accepter</button>
        <button class="go sm" style="flex:1;min-height:48px" data-act="reject">Rejeter</button>
      </div></div>`;
  }).join('');
  list.querySelectorAll('button[data-act]').forEach(b => {
    b.onclick = () => decideProposal(b.closest('.card').dataset.pid, b.dataset.act, b);
  });
}

/* ── Ton pourquoi ───────────────────────────────────────────────────────────
   Le serveur savait déjà tout recevoir : app.py lit `reason`, proposals.decide
   le range dans `decision_reason`, memory.add le grave dans la mémoire absolue.
   Le front n'envoyait que `{ decision }` — d'où un journal qui ne pouvait
   raconter QUE l'argument de la machine, jamais celui de son auteur.
   Quatre pastilles, un champ libre, et « passer » qui n'empêche rien. */
const RAISONS = {
  accept: ['ça corrige un vrai souci', 'ça me plaît', "j'essaie, on verra"],
  reject: ['pas maintenant', "je n'y crois pas", 'hors sujet'],
};
function decideProposal(pid, decision, btn) {
  const card = btn.closest('.card');
  const zone = btn.parentElement;
  zone.querySelectorAll('button').forEach(x => x.disabled = true);
  const verbe = decision === 'accept' ? 'Accepter' : 'Rejeter';
  const boite = document.createElement('div');
  boite.className = 'pourquoi';
  boite.innerHTML = `<div class="mut">${verbe} — pourquoi ? <i>(facultatif, mais c'est ce que
      le journal citera demain)</i></div>
    <div class="pastilles">${RAISONS[decision].map(r =>
      `<button class="go sm" data-r="${esc(r)}">${esc(r)}</button>`).join('')}</div>
    <div class="row" style="gap:8px;margin-top:8px">
      <input class="libre" placeholder="…ou dis-le avec tes mots" style="flex:1">
      <button class="go sm" data-r="">Passer</button>
    </div>`;
  card.appendChild(boite);
  boite.querySelector('.libre').focus();
  const envoyer = async raison => {
    boite.remove();
    card.style.opacity = '0.4';                     // retrait optimiste
    try {
      const r = await j(`/api/proposal/${encodeURIComponent(pid)}/decide`,
        { method: 'POST', headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ decision, reason: raison }) });
      if (r.error) { card.style.opacity = '1'; alert('✗ ' + r.error); return; }
      card.remove();
      refreshProposals();
    } catch { card.style.opacity = '1'; }
  };
  boite.querySelectorAll('button[data-r]').forEach(b => b.onclick = () =>
    envoyer(b.dataset.r || boite.querySelector('.libre').value.trim()));
  boite.querySelector('.libre').onkeydown = e => {
    if (e.key === 'Enter') envoyer(e.target.value.trim());
  };
}

async function refreshAgents() {
  let d; try { d = await j('/api/agents'); } catch (e) { return; }
  const list = d.agents || [];
  const ko = list.filter(a => a.enabled && a.ok === false).length;
  const never = list.filter(a => a.enabled && !a.last_run).length;
  const on = list.filter(a => a.enabled).length;

  const chip = $('#ch-agents');
  if (chip) {
    chip.className = 'chip ' + (!d.installed ? 'warn' : ko ? 'crit' : 'ok');
    chip.innerHTML = `AGENTS <b>${d.installed ? on : '—'}</b>${ko ? ' · ' + ko + ' KO' : ''}`;
  }
  const meta = $('#agents-meta');
  if (meta) meta.textContent = d.installed
    ? `${on} planifié(s)${ko ? ' · ' + ko + ' en échec' : ''}${never ? ' · ' + never + ' jamais exécuté' : ''}`
    : 'planification non installée';
  const hint = $('#agents-hint');
  if (hint) hint.textContent = d.installed ? '' : 'Aucune tâche planifiée sur la VM — cliquer pour installer.';

  $('#agentlist').innerHTML = list.map(a => {
    const cls = !a.enabled ? 'off' : a.ok === true ? 'ok' : a.ok === false ? 'ko' : 'never';
    const st = !a.enabled ? 'DÉSACTIVÉ' : a.ok === true ? 'OK' : a.ok === false ? 'ÉCHEC' : 'JAMAIS';
    const bcl = !a.enabled ? 'idle' : a.ok === true ? 'up' : a.ok === false ? 'down' : 'pending';
    return `<div class="agent ${cls}">
      <div class="row"><span class="name">${esc(a.label)}</span><span class="badge ${bcl}">${st}</span></div>
      <div class="mut" style="margin-top:3px">${esc(a.desc)}</div>
      <div class="metrics"><span class="sched">${esc(a.schedule || '—')}</span>
        ${a.last_run ? `<span>${esc(a.last_run.replace('T', ' ').replace('Z', ''))}</span>` : ''}
        ${a.duration_s != null ? `<span>${a.duration_s}s</span>` : ''}</div>
      ${a.summary ? `<div class="mut" style="margin-top:4px">→ ${esc(a.summary)}</div>` : ''}
      <div style="margin-top:7px"><button class="go sm" onclick="run('agent-run',{id:'${esc(a.id)}'})">Exécuter</button></div>
    </div>`;
  }).join('') || '<div class="mut">aucun agent déclaré</div>';

  // Santé : deux sparklines (charge et RAM) sur les derniers relevés.
  const h = d.health || [];
  if (h.length) {
    const spark = (vals, max) => `<div class="spark">` + vals.map(v => {
      const p = Math.min(100, Math.round(v / max * 100));
      const c = p >= 90 ? 'max' : p >= 70 ? 'hi' : '';
      return `<i class="${c}" style="height:${Math.max(2, p)}%"></i>`;
    }).join('') + `</div>`;
    const last = h[h.length - 1];
    $('#healthbody').innerHTML =
      `<div class="mut">CHARGE (sur ${last.cpus} cœurs)</div>${spark(h.map(x => x.load1), last.cpus)}
       <div class="mut" style="margin-top:8px">RAM %</div>${spark(h.map(x => x.mem_pct), 100)}`;
    $('#health-meta').textContent =
      `charge ${last.load1} · RAM ${last.mem_pct}% · disque ${last.disk_pct}%`;
  }

  // CI des commits : verdict + vignette du rendu réel par commit.
  const ci = d.ci || [];
  if (ci.length) {
    const greens = ci.filter(c => c.scenes_failing === 0 && c.boot_ok).length;
    $('#ci-meta').textContent = `${ci.length} commit(s) testés · ${ci.length - greens} rouge(s)`;
    $('#cilist').innerHTML = [...ci].reverse().map(c => {
      const ok = c.scenes_failing === 0 && c.boot_ok;
      return `<div class="card ${ok ? 'done' : 'failed'}">
        <div class="row"><span class="name">${esc(c.sha)}</span>
          <span class="badge ${ok ? 'up' : 'down'}">${ok ? 'VERT' : 'ROUGE'}</span></div>
        <div class="mut">${esc(c.subject || '')}</div>
        <div class="metrics"><span>${c.scenes_failing}/${c.scenes_total} scènes KO</span>
          <span>boot ${c.boot_ok ? 'OK' : 'KO'}</span><span>${esc((c.t || '').slice(5, 16).replace('T', ' '))}</span></div>
        ${c.diag ? `<div class="mut" style="margin-top:6px;color:var(--amber)">🜁 ${esc(c.diag)}</div>` : ''}
        ${c.shot ? `<img src="/api/ci/shot/${esc(c.sha)}" alt="rendu ${esc(c.sha)}"
             style="width:100%;margin-top:6px;border:1px solid var(--border)">` : ''}
      </div>`;
    }).join('');
  }
  // Facturation : doit rester à 0. Le chip vire au rouge au premier centime.
  const b = d.billing || {};
  const billChip = $('#ch-bill');
  if (b.total === 0) {
    billChip.className = 'chip up'; billChip.textContent = '€ 0,00';
  } else if (typeof b.total === 'number') {
    billChip.className = 'chip down';
    billChip.textContent = '€ ' + b.total.toFixed(2).replace('.', ',');
  } else {
    billChip.className = 'chip idle'; billChip.textContent = '€ ?';
  }
  if (b.t) {
    const age = Math.max(0, Math.round((Date.now() - Date.parse(b.t)) / 60000));
    const src = b.source === 'live' ? 'live' : (b.source === 'snapshot' ? 'instantané' : '—');
    $('#bill-meta').textContent = `${src} · il y a ${age} min`;
    billChip.title = `Facturation Oracle ${b.month || ''} — source ${src}, relevé il y a ${age} min`;
  }
  if (typeof b.total === 'number') {
    const zero = b.total === 0;
    $('#bill-body').innerHTML =
      `<div style="font:700 30px ui-monospace,monospace;color:${zero ? 'var(--green)' : 'var(--red)'}">
         ${b.total.toFixed(2).replace('.', ',')} ${esc(b.currency || 'EUR')}</div>
       <div class="mut" style="margin-top:4px">cumul du mois ${esc(b.month || '')} — ${
         zero ? 'offre Always Free respectée' : '⚠ montant non nul, à vérifier dans la console Oracle'}</div>
       ${(b.services || []).length ? `<div class="metrics" style="margin-top:8px">${
         b.services.map(s => `<span>${esc(s.name)} : ${s.amount} ${esc(b.currency || '')}</span>`).join('')
       }</div>` : ''}
       ${b.live_error ? `<div class="mut" style="margin-top:8px">relevé direct indisponible : ${esc(String(b.live_error).slice(0, 120))}</div>` : ''}`;
  } else if (b.error) {
    $('#bill-body').innerHTML = `<div class="mut">indisponible — ${esc(String(b.error).slice(0, 160))}</div>`;
  }

  const mq = d.missions_queued || 0;
  $('#mission-meta').textContent = mq ? `${mq} mission(s) en file` : 'file vide';
  if (d.report) {
    $('#reportbody').textContent = d.report;
    const m = d.report.match(/# Rapport du ([^\n]*)/);
    $('#report-meta').textContent = m ? m[1] : '';
  }

  const sm = d.smoke || {};
  if (sm.total) {
    $('#smoke-meta').textContent = `${sm.total} scènes · ${sm.failing} en erreur · ${esc(sm.commit || '')}`;
    $('#smokebody').innerHTML = `<div class="grid">` + (sm.scenes || []).map(s =>
      `<div class="card ${s.script_errors ? 'failed' : 'done'}"><div class="row">
        <span class="name">${esc(s.scene.replace('.tscn', ''))}</span>
        <span class="badge ${s.script_errors ? 'down' : 'up'}">${s.script_errors || 0} err</span>
      </div></div>`).join('') + `</div>`;
  }
}

function refreshClock() {
  const e = $('#ch-clock'); if (!e) return;
  const d = new Date();
  e.textContent = String(d.getHours()).padStart(2, '0') + ':' + String(d.getMinutes()).padStart(2, '0');
}

/* handlers appelés depuis les attributs onclick du HTML */
Object.assign(window, { run, runAll, parseProj, genCards, askOllama, renderParams, launchGeneric, stopJob });

function tick() {
  refreshSum(); refreshCpu(); refreshRun(); refreshPlay(); refreshContent();
  refreshLlm(); refreshRepo(); refreshHost(); refreshJobs(); refreshAgents(); refreshProposals(); refreshHealth(); refreshJournal(); refreshClock();
}
const mBtn = $('#btn-mission');
if (mBtn) mBtn.onclick = async () => {
  const inp = $('#mission-text'), res = $('#mission-res');
  try {
    const r = await j('/api/mission', { method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ text: inp.value }) });
    res.className = 'res ' + (r.error ? 'err' : 'ok');
    res.textContent = r.error ? '✗ ' + r.error : `✓ en file (${r.queued})`;
    if (!r.error) { inp.value = ''; refreshAgents(); }
  } catch (e) { res.className = 'res err'; res.textContent = '✗ réseau'; }
};

/* ── Rafraîchissement : seulement ce qu'on REGARDE, et rien en arrière-plan ──
   Avant : 6 minuteries tournaient en permanence et le tour de 30 s déclenchait
   NEUF requêtes, même page fermée — sur 4G et sur batterie. Maintenant chaque
   onglet déclare ce qu'il a besoin de savoir, et tout s'arrête quand l'écran
   n'est plus visible. Les pastilles de la barre restent à jour partout : c'est
   leur seule raison d'être. */
const BARRE = () => { refreshClock(); refreshSum(); refreshProposals(); refreshBoite(); };
const PAR_ONGLET = {
  play:    () => { refreshPlay(); refreshRun(); },
  journal: () => { refreshChapitres(); refreshJournal(); },
  ideas:   () => refreshProposals(),
  talk:   () => {},                       // talkPoll a sa propre minuterie
  health: () => { refreshHealth(); refreshCpu(); refreshHost(); },
  agents: () => { refreshAgents(); refreshCrew(); refreshJobs(); },
  jobs:   () => refreshJobs(),
  godot:  () => refreshRun(),
  content: () => { refreshContent(); refreshLlm(); },
  system: () => { refreshHost(); refreshRepo(); },
};
function rafraichirOnglet() {
  if (document.hidden) return;
  try { (PAR_ONGLET[TAB] || (() => {}))(); } catch (e) {}
}

let BOUCLE = null;
function demarrerBoucles() {
  if (BOUCLE) return;
  BOUCLE = setInterval(() => { if (document.hidden) return; BARRE(); rafraichirOnglet(); }, 20000);
}
function arreterBoucles() { clearInterval(BOUCLE); BOUCLE = null; }
document.addEventListener('visibilitychange', () => {
  if (document.hidden) { arreterBoucles(); }
  else { demarrerBoucles(); BARRE(); rafraichirOnglet(); }
});

if ('serviceWorker' in navigator) navigator.serviceWorker.register('/sw.js').catch(() => {});

// Ouverture directe sur un onglet : c'est ce qui rend une notification cliquable
// utile (« un agent te parle » → ?tab=talk mène droit au fil).
{
  const veut = new URLSearchParams(location.search).get('tab');
  if (veut && document.getElementById('pane-' + veut)) showTab(veut);
}
loadCat(); tick(); initGame();
BARRE(); rafraichirOnglet(); demarrerBoucles();
