/* MERLIN Studio — logique du portail, HÉBERGEMENT SEUL (2026-09-08).
   Quatre écrans : Jouer (le jeu en direct, game.js), Décider (les fourches), Chronique (la liseuse),
   Santé (la machine et ses neuf gardiens). Tout ce qui montrait des agents au travail est parti
   avec eux ; les contrats /api/* restants sont inchangés. */
import { initGame } from '/static/game.js?v=4';

const $ = s => document.querySelector(s), j = (u, o) => fetch(u, o).then(r => r.json());
const esc = s => String(s ?? "").replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const card = (n, b, st) => `<div class="card ${st||''}"><div class="row"><span class="name">${n}</span></div>${b}</div>`;
const gauge = p => { const c = p >= 90 ? 'crit' : p >= 70 ? 'warn' : ''; return `<div class="bar ${c}"><i style="width:${Math.min(p,100)}%"></i></div>`; };
const duree_courte = s => {
  s = Math.max(0, Math.round(s || 0));
  if (s < 60) return s + ' s';
  if (s < 3600) return Math.round(s / 60) + ' min';
  return Math.floor(s / 3600) + ' h ' + String(Math.round((s % 3600) / 60)).padStart(2, '0');
};

/* ── Les onglets ─────────────────────────────────────────────────────────── */
let TAB = 'play';
function showTab(tab) {
  document.querySelectorAll('.dock button').forEach(x => x.classList.toggle('on', x.dataset.tab === tab));
  document.querySelectorAll('.pane').forEach(p => p.classList.toggle('on', p.id === 'pane-' + tab));
  window.scrollTo(0, 0);
  // Quitter Jouer doit COUPER le flux vidéo : sinon le jeu continue d'encoder pour un écran caché.
  if (TAB === 'play' && tab !== 'play' && window.merlinLeavePlay) window.merlinLeavePlay();
  TAB = tab;
  try { history.replaceState(null, '', '?tab=' + tab); } catch (e) {}
  rafraichirOnglet();
}
document.querySelectorAll('.dock button, .vital').forEach(b => b.onclick = () => showTab(b.dataset.tab));

/* ── La barre collante se mesure (studio.css lit --topbar-h) ─────────────── */
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
{
  const bt = document.getElementById('ch-more'), bar = document.getElementById('sysbar');
  if (bt && bar) bt.onclick = () => {
    bar.classList.toggle('replie');
    bt.textContent = bar.classList.contains('replie') ? '⋯' : '×';
    mesurerTopbar();
  };
}

/* ── Lancer une action (le jeu) ──────────────────────────────────────────── */
async function run(kind, params) {
  try {
    return await j('/api/launch', { method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ kind, params: params || {} }) });
  } catch (e) { return { error: 'réseau' }; }
}

/* ── La barre : RAM, CPU, facture, heure ─────────────────────────────────── */
const chip = (id, cls, html) => { const e = $(id); if (e) { e.className = 'chip ' + cls; e.innerHTML = html; } };
async function refreshSum() {
  try {
    const o = await j('/api/overview'); const m = o.mem || {};
    const s = $('#sum'); if (s) s.textContent = `${o.cpus} CŒURS · ${m.available_gb}/${m.total_gb} GO`;
    const pct = m.used_pct || 0;
    chip('#ch-mem', pct >= 90 ? 'crit' : pct >= 75 ? 'warn' : 'ok', `RAM <b>${pct}%</b> · ${m.available_gb} GO LIBRES`);
  } catch (e) {}
}
async function refreshCpu() {
  try {
    const h = await j('/api/host');
    const load1 = parseFloat((h.load || '0').split(' ')[0]) || 0;
    const cpus = parseInt(h.cpus, 10) || 4;
    const r = load1 / cpus;
    chip('#ch-cpu', r >= 0.95 ? 'crit' : r >= 0.7 ? 'warn' : 'ok', `CPU <b>${h.load ? h.load.split(' ')[0] : '?'}</b> / ${cpus}`);
  } catch (e) {}
}
function refreshClock() {
  const e = $('#ch-clock'); if (!e) return;
  const d = new Date();
  e.textContent = String(d.getHours()).padStart(2, '0') + ':' + String(d.getMinutes()).padStart(2, '0');
}

/* ── Santé : quatre voyants, la machine, les gardiens ────────────────────── */
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
    const b = d.billing || {};
    if (b.total === 0) { vital('#v-euro', 'up', '0,00 €'); chip('#ch-bill', 'ok', '€ <b>0</b>'); }
    else if (typeof b.total === 'number') { vital('#v-euro', 'down', b.total.toFixed(2) + ' € !'); chip('#ch-bill', 'crit', `€ <b>${b.total.toFixed(2)}</b> !`); }
    renderGardiens(d);
  } catch { /* les voyants gardent leur dernier état */ }
  try {
    const f = await j('/api/decisions');
    const n = f.a_trancher || 0;
    vital('#v-decide', n ? 'up' : 'idle', n ? n + ' à trancher' : 'rien');
    const pill = $('#dock-pending');
    if (pill) { pill.hidden = !n; pill.textContent = n; }
    chip('#ch-prop', n ? 'warn' : 'idle', `⚖ <b>${n}</b>`);
  } catch { }
}
function renderGardiens(d) {
  const list = $('#agentlist'), meta = $('#agents-meta');
  if (!list) return;
  const ags = d.agents || [];
  if (meta) meta.textContent = d.installed ? `${ags.length} planifiés` : 'planification non installée';
  list.innerHTML = ags.map(a => {
    const st = a.running ? 'warn' : a.reporte ? 'idle' : a.ok === false ? 'down' : a.ok === true ? 'up' : 'idle';
    const quand = a.running ? `en cours depuis ${duree_courte((a.course || {}).depuis_s)}`
      : a.ago_min != null ? `il y a ${duree_courte(a.ago_min * 60)}` : 'jamais passé';
    return `<div class="card ${st}"><div class="row"><span class="name">${esc(a.label || a.id)}</span>
      <span class="badge ${st}">${a.running ? 'en cours' : a.reporte ? 'reporté' : a.ok === false ? 'en panne' : a.ok === true ? 'ok' : '—'}</span></div>
      <div class="mut">${esc(a.desc || '')}</div>
      <div class="metrics"><span>${esc(a.schedule)}</span><span>${esc(quand)}</span><span>prochain ${esc(a.next_run || '')}</span></div>
      ${a.summary ? `<div class="mut">${esc(String(a.summary).slice(0, 160))}</div>` : ''}</div>`;
  }).join('') || '<div class="mut">aucun gardien</div>';
}
async function refreshHost() {
  try {
    const h = await j('/api/host'), m = h.mem || {};
    const meta = $('#host-meta'); if (meta) meta.textContent = h.uptime || '';
    $('#hostcards').innerHTML = [
      card('Ressources', `<div class="metrics"><span>arch <b>${esc(h.arch)}</b></span><span>cœurs <b>${esc(h.cpus)}</b></span>
       <span>load <b>${esc(h.load)}</b></span></div>
       <div class="mut">RAM ${m.available_gb} / ${m.total_gb} Go libres</div>${gauge(m.used_pct||0)}
       <div class="mut">disque ${esc(h.disk?.used||'?')} / ${esc(h.disk?.size||'?')} (${esc(h.disk?.pct||'')})</div>`,
       (m.used_pct || 0) > 90 ? 'down' : 'up'),
      card('Portes', (h.ports || []).map(p => `<span class="badge ${p.open?'up':'pending'}">${esc(p.name)} ${p.open?'ouvert':'fermé'}</span>`).join(' '), ''),
    ].join('');
  } catch (e) {}
}

/* ── Chronique : les parties jouées, dans la liseuse ─────────────────────── */
async function refreshChroniques() {
  let d = { parties: [] };
  try { d = await j('/api/chroniques'); } catch { /* le cadre dira lui-même s'il est vide */ }
  const n = (d.parties || []).length;
  $('#chro-meta').textContent = n ? `${n} partie(s)` : 'aucune partie encore';
  renderNuits();
  const f = $('#chro-cadre');
  if (!f) return;
  const src = '/chroniques/liseuse';
  if (!f.getAttribute('src')) f.setAttribute('src', src);
  else if (f.dataset.parties !== String(n)) { f.setAttribute('src', src + '?n=' + n); }
  f.dataset.parties = String(n);
}
/* La courbe des nuits reste lisible pour ce qui a été mesuré ; plus aucune nuit ne s'y ajoute
   depuis le 08/09 (la VM n'héberge que le jeu), et sans deux points elle reste cachée. */
function _serie(nuits, cle, unite) {
  return nuits.map(d => ({ nuit: d.nuit, v: (d.partie && d.partie[cle] != null) ? Number(d.partie[cle]) : null, unite }));
}
function _sparkline(pts, w, h) {
  const vals = pts.filter(p => p.v != null).map(p => p.v);
  if (vals.length < 2) return '';
  const lo = Math.min(0, ...vals), hi = Math.max(...vals) || 1;
  const x = i => 4 + (w - 8) * (pts.length === 1 ? 0 : i / (pts.length - 1));
  const y = v => h - 4 - (h - 8) * ((v - lo) / ((hi - lo) || 1));
  let d = '', segs = [], seg = [];
  pts.forEach((p, i) => { if (p.v == null) { if (seg.length) segs.push(seg); seg = []; } else seg.push([x(i), y(p.v)]); });
  if (seg.length) segs.push(seg);
  for (const s of segs) d += s.map((q, i) => (i ? 'L' : 'M') + q[0].toFixed(1) + ' ' + q[1].toFixed(1)).join(' ') + ' ';
  const marks = pts.map((p, i) => p.v == null ? '' :
    `<circle cx="${x(i).toFixed(1)}" cy="${y(p.v).toFixed(1)}" r="4"><title>${esc(p.nuit)} · ${p.v}${esc(p.unite)}</title></circle>`).join('');
  return `<svg viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" aria-hidden="true"><path d="${d.trim()}" fill="none" stroke="currentColor" stroke-width="2"/>${marks}</svg>`;
}
async function renderNuits() {
  const box = $('#nuits');
  if (!box) return;
  let nuits = [];
  try { nuits = (await j('/api/nuits')).nuits || []; } catch { nuits = []; }
  const jouees = nuits.filter(d => d.partie && d.partie.beats);
  if (jouees.length < 2) { box.hidden = true; box.innerHTML = ''; return; }
  const derniere = jouees[jouees.length - 1];
  const denom = derniere.partie.beats_joues || derniere.partie.beats;
  const mesures = [
    { titre: 'au banc', cle: 'banc', unite: ' beats', fmt: v => `${v}/${denom}` },
    { titre: 'réussite', cle: 'reussite_pct', unite: ' %', fmt: v => `${v} %` },
    { titre: 'sans dé', cle: 'sans_jet_pct', unite: ' %', fmt: v => `${v} %` },
    { titre: 'intégrité au plus bas', cle: 'integrite_min', unite: '', fmt: v => `${v}/10` },
    { titre: 'attente médiane', cle: 'attente_med_s', unite: ' s', fmt: v => `${v} s` },
  ];
  box.innerHTML = mesures.map(m => {
    const pts = _serie(nuits, m.cle, m.unite);
    const v = derniere.partie[m.cle];
    return `<figure class="nuit"><figcaption>${esc(m.titre)}<b>${v == null ? '—' : esc(m.fmt(v))}</b></figcaption>${_sparkline(pts, 140, 36)}</figure>`;
  }).join('') + `<div class="nuit-legende">${nuits.length} nuits mesurées jusqu'au ${esc(derniere.nuit)} · la nuit ne joue plus depuis le 08/09</div>`;
  box.hidden = false;
}

/* ── Les fourches ────────────────────────────────────────────────────────────
   Une carte par fourche ouverte : la question, deux à trois options avec leur coût, la
   recommandation, et une lettre à choisir. Le choix est enregistré sur la VM et publié sur le
   canal du Courrier ; tant que la session suivante ne l'a pas gravé dans le dépôt, la carte le
   dit (« en route »). Les fourches tranchées et périmées restent visibles, repliées. */
const DOMAINE_FR = { regles: 'règles', lore: 'lore', ecrans: 'écrans', outillage: 'outillage' };
function md(t) {
  return esc(t || '').replace(/\*\*(.+?)\*\*/g, '<b>$1</b>').replace(/`(.+?)`/g, '<code>$1</code>')
    .replace(/\n\n/g, '<br><br>').replace(/\n- /g, '<br>• ');
}
async function refreshFourches() {
  let d;
  try { d = await j('/api/decisions'); } catch { return; }
  const meta = $('#fourches-meta'), list = $('#fourches-list');
  if (!meta || !list) return;
  if (d.erreur) { meta.textContent = 'illisible'; list.innerHTML = `<div class="mut">${esc(d.erreur)}</div>`; return; }
  const fs = d.fourches || [];
  const ouvertes = fs.filter(f => f.etat === 'ouverte');
  meta.textContent = ouvertes.length
    ? `${d.a_trancher} à trancher · ${ouvertes.length}/${d.plafond} ouvertes`
    : (fs.length ? 'rien à trancher' : 'aucune fourche');
  if (!fs.length) { list.innerHTML = '<div class="mut">aucune fourche — le développement avance sur ce qui est tranché</div>'; return; }
  const carte = (f) => {
    const loc = f.locale, rep = f.reponse;
    const jours = f.ouverte ? Math.max(0, Math.round((Date.now() - Date.parse(f.ouverte)) / 864e5)) : 0;
    const etat = rep ? `tranchée ${esc(rep.lettre)} le ${esc(rep.date)}`
      : loc ? `${esc(loc.lettre)} choisie le ${esc(loc.date)} — en route vers le dépôt${loc.via ? ' (via ' + esc(loc.via) + ')' : ''}`
      : f.etat === 'perimee' ? 'périmée' : `ouverte depuis ${jours} j`;
    const opts = (f.options || []).map(o => `
      <details class="option ${rep && rep.lettre === o.lettre ? 'prise' : ''}">
        <summary><b class="lettre">${esc(o.lettre)}</b> ${esc(o.titre)}</summary>
        <div class="mut">${md(o.texte)}</div>
      </details>`).join('');
    const reco = f.recommandation ? `<div class="reco">Recommandation : <b>${esc(f.recommandation.lettre)}</b> — ${esc(f.recommandation.pourquoi)}</div>` : '';
    const boutons = (f.etat === 'ouverte' && !loc) ? `
      <div class="row" style="gap:8px;margin-top:10px;flex-wrap:wrap">
        ${(f.options || []).map(o => `<button class="go" style="flex:1;min-height:48px" data-lettre="${esc(o.lettre)}">${esc(o.lettre)} — ${esc(o.titre)}</button>`).join('')}
      </div>
      <input class="note" placeholder="une note, si tu veux (elle part sur le canal, sans lien ni secret)" maxlength="300">` : '';
    const ouverte = f.etat === 'ouverte' ? ' open' : '';
    return `<details class="card fourche" data-id="${esc(f.id)}"${ouverte}>
      <summary class="row"><span class="name">${esc(f.id)} · ${esc(f.titre)}</span>
        <span class="badge ${f.etat === 'ouverte' ? 'up' : 'idle'}">${esc(DOMAINE_FR[f.domaine] || f.domaine)}</span>
        <span class="mut">${etat}</span></summary>
      <div class="mut" style="margin:8px 0">${md(f.fourche)}</div>
      ${f.aujourdhui ? `<details><summary class="mut">aujourd'hui, dans le code</summary><div class="mut">${md(f.aujourdhui)}</div></details>` : ''}
      <div class="options">${opts}</div>
      ${reco}${boutons}
      ${rep && rep.note ? `<div class="mut">« ${esc(rep.note)} »</div>` : ''}
    </details>`;
  };
  list.innerHTML = fs.map(carte).join('');
  list.querySelectorAll('button[data-lettre]').forEach(b => {
    b.onclick = () => trancher(b.closest('.fourche'), b.dataset.lettre, b);
  });
}
async function trancher(card, lettre, btn) {
  const id = card.dataset.id;
  const note = (card.querySelector('input.note') || {}).value || '';
  card.querySelectorAll('button').forEach(x => x.disabled = true);
  btn.textContent = '…';
  try {
    const r = await fetch(`/api/decision/${encodeURIComponent(id)}/trancher`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ lettre, note }) });
    const d = await r.json();
    if (!r.ok || d.error) throw new Error(d.error || r.status);
    dire(`${id} → ${lettre} · publiée${d.via ? ' via ' + d.via : ''}`);
  } catch (e) {
    dire('refusée : ' + e.message);
    card.querySelectorAll('button').forEach(x => x.disabled = false);
    btn.textContent = lettre;
    return;
  }
  refreshFourches();
  refreshHealth();
}
function dire(t) { const m = $('#fourches-meta'); if (m) m.textContent = t; }

/* ── Rafraîchissement : seulement ce qu'on regarde ───────────────────────── */
Object.assign(window, { run });
const BARRE = () => { refreshClock(); refreshSum(); refreshCpu(); refreshHealth(); };
const PAR_ONGLET = {
  play:      () => {},                       // game.js sonde le jeu lui-même
  ideas:     () => refreshFourches(),
  chronique: () => refreshChroniques(),
  health:    () => { refreshHealth(); refreshHost(); },
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

/* Ouverture directe sur un onglet (?tab=ideas) : une notification cliquable mène droit aux fourches. */
{
  const veut = new URLSearchParams(location.search).get('tab');
  if (veut && PAR_ONGLET[veut]) showTab(veut);
}
$('#foot').textContent = 'MERLIN STUDIO · VM ORACLE · HÉBERGEMENT SEUL · REFRESH 20 S';
initGame();
BARRE();
rafraichirOnglet();
demarrerBoucles();
