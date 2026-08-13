/* MERLIN Studio — onglet Jouer : jeu natif VM via noVNC.
   Machine à états : offline → starting → connecting → live (→ offline).
   PLAY = 1 clic : lance game-start puis se connecte dès que le VNC répond. */
import RFB from '/static/novnc/core/rfb.js';

const $ = s => document.querySelector(s);
const j = (u, o) => fetch(u, o).then(r => r.json());

let state = 'offline';
let rfb = null;
let pollTimer = null;

function readout(msg, isErr) {
  const el = $('#game-status');
  if (el) el.innerHTML = `<span class="${isErr ? 'err' : ''}">${msg}</span>`;
}

/* Résolution de rendu choisie selon l'appareil : sans carte graphique sur la VM,
   diviser le nombre de pixels par ~1,8 est le levier de fluidité le plus efficace. */
function autoRes() {
  const coarse = window.matchMedia && window.matchMedia('(pointer: coarse)').matches;
  const big = Math.max(window.innerWidth, window.innerHeight);
  return (coarse || big < 1100) ? '960x540' : '1280x720';
}

/* Bandeau d'état : le jeu tourne-t-il, et sur quelle branche. */
function statusGame(g) {
  const e = $('#ch-game'); if (!e) return;
  const live = g && g.vnc_open;
  e.className = 'chip ' + (live ? 'ok' : (g && g.available ? 'idle' : 'warn'));
  e.innerHTML = `<i class="dot"></i>JEU <b>${live ? 'EN COURS' : 'ARRÊTÉ'}</b>`
    + (g && g.repo_branch ? ` · ${g.repo_branch}` : '');
}

/* Ligne de transparence : QUOI tourne exactement (branche@commit, godot, import). */
function versionReadout(g) {
  const el = $('#game-version');
  if (!el) return;
  const parts = [
    `JEU : ${g.repo_branch || '?'} @ ${g.repo_commit || '?'}`,
    `GODOT ${g.godot_version || '?'}`,
    `IMPORT ${g.imported ? 'OK' : '<span class="err">JAMAIS FAIT — SYNC REQUIS</span>'}`,
  ];
  if (g.version_warning) parts.push(`<span class="err">⚠ ${g.version_warning}</span>`);
  el.innerHTML = parts.join(' · ');
}

async function refreshVersion() {
  try { const g = await j('/api/game'); versionReadout(g); statusGame(g); } catch (e) {}
}

function setState(s) {
  state = s;
  const play = $('#btn-play'), stop = $('#btn-stop'), fs = $('#btn-fs');
  const frame = $('#crt-frame'), off = $('#crt-off');
  const running = s === 'live';
  const busy = s === 'starting' || s === 'connecting';
  play.style.display = running || busy ? 'none' : '';
  stop.style.display = running || busy ? '' : 'none';
  fs.disabled = !running;
  frame.classList.toggle('live', running);
  off.style.display = running ? 'none' : '';
}

function offMessage(big, small) {
  $('#crt-off').innerHTML = `<div class="big">${big}</div><div>${small || ''}</div>`;
}

/* Reconnexion : le signal tombe pour des raisons qui n'ont rien à voir avec le
   jeu (réseau mobile qui change de cellule, veille de l'écran, tunnel qui se
   renouvelle). Avant, il fallait retaper PLAY à chaque fois. On réessaie seul,
   en espaçant les tentatives, et on ABANDONNE franchement au bout de 5 — une
   boucle infinie silencieuse tournerait toute la nuit sur une VM à 0 €. */
let retryN = 0;
let retryTimer = null;

function annuleReconnexion() {
  retryN = 0;
  clearTimeout(retryTimer);
  retryTimer = null;
}

function reconnecte() {
  if (retryN >= 5) {
    offMessage('SIGNAL PERDU', 'APPUYER SUR PLAY');
    readout('5 TENTATIVES SANS SUCCÈS — RELANCE MANUELLE', true);
    return;
  }
  const delai = Math.min(2000 * Math.pow(2, retryN), 30000);
  retryN++;
  offMessage('RECONNEXION…', `TENTATIVE ${retryN}/5 DANS ${Math.round(delai / 1000)} S`);
  readout(`SIGNAL PERDU — RECONNEXION AUTOMATIQUE (${retryN}/5)`);
  clearTimeout(retryTimer);
  retryTimer = setTimeout(async () => {
    // Le jeu tourne-t-il encore ? Se reconnecter à un conteneur mort ne ferait
    // que répéter l'échec en annonçant la mauvaise cause.
    let g = {};
    try { g = await j('/api/game'); } catch (e) {}
    if (!g.vnc_open) {
      setState('offline');
      offMessage('LE JEU S\'EST ARRÊTÉ', 'APPUYER SUR PLAY');
      readout('CONTENEUR ARRÊTÉ — CE N\'EST PAS LE RÉSEAU', true);
      annuleReconnexion();
      return;
    }
    connectVNC(true);
  }, delai);
}

async function connectVNC(reprise) {
  setState('connecting');
  readout(reprise ? 'RECONNEXION VNC…' : 'CONNEXION VNC…');
  let ticket;
  try {
    ticket = (await j('/api/vnc/ticket', { method: 'POST' })).ticket;
  } catch (e) {
    setState('offline');
    if (reprise) { reconnecte(); return; }
    readout('TICKET REFUSÉ — RECHARGER LA PAGE', true);
    return;
  }
  const proto = location.protocol === 'https:' ? 'wss' : 'ws';
  const url = `${proto}://${location.host}/websockify?ticket=${encodeURIComponent(ticket)}`;
  rfb = new RFB($('#vnc-screen'), url);
  rfb.scaleViewport = true;
  rfb.showDotCursor = false;
  // Le goulot dépend du chemin : sur le Wi-Fi de la maison c'est le CPU de la VM
  // (4 cœurs ARM, encodage logiciel), en 4G à travers le tunnel c'est le réseau.
  // « fluide » compresse plus (moins d'octets, un peu plus de CPU), « net »
  // compresse moins et soigne l'image. Le défaut suit l'appareil.
  const dbt = debit();
  rfb.qualityLevel = dbt === 'net' ? 7 : 6;
  rfb.compressionLevel = dbt === 'net' ? 1 : 2;
  rfb.addEventListener('connect', () => {
    setState('live');
    annuleReconnexion();
    readout(`SIGNAL OK · ${rfb._fbWidth || ''}×${rfb._fbHeight || ''} · ${dbt}`);
    refreshVersion();
  });
  rfb.addEventListener('disconnect', ev => {
    rfb = null;
    setState('offline');
    // Une fermeture PROPRE, c'est Maxime qui a arrêté : on ne relance rien.
    // Tout le reste (tunnel, réseau, veille) mérite une reconnexion.
    if (ev.detail && ev.detail.clean) {
      offMessage('SIGNAL PERDU', 'APPUYER SUR PLAY');
      readout('DÉCONNECTÉ');
      annuleReconnexion();
    } else {
      reconnecte();
    }
  });
}

/* Le débit choisi : « fluide » (moins d'octets) ou « net » (plus d'image). Sur
   un écran tactile — donc souvent en mobile — la fluidité prime par défaut. */
function debit() {
  const sel = $('#game-debit');
  if (sel && sel.value) return sel.value;
  const coarse = window.matchMedia && window.matchMedia('(pointer: coarse)').matches;
  return coarse ? 'fluide' : 'net';
}

async function play() {
  setState('starting');
  offMessage('BOOT CONTENEUR…', 'XVFB + X11VNC + GODOT');
  readout('LANCEMENT game-start…');
  const res = $('#game-res') ? $('#game-res').value : '1280x720';
  try {
    const r = await j('/api/launch', {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ kind: 'game-start', params: { res } }),
    });
    if (r.error && !/occupé/.test(r.error)) {
      setState('offline');
      offMessage('ÉCHEC LANCEMENT', r.error);
      readout(r.error, true);
      return;
    }
  } catch (e) {
    setState('offline');
    readout('ERREUR RÉSEAU', true);
    return;
  }
  // Poll jusqu'à ce que le VNC réponde (le start attend déjà côté VM, marge 90 s).
  let tries = 0;
  clearInterval(pollTimer);
  pollTimer = setInterval(async () => {
    tries++;
    let g = {};
    try { g = await j('/api/game'); } catch (e) { /* transitoire */ }
    if (g.vnc_open && g.ws_bridge) {
      clearInterval(pollTimer);
      connectVNC();
    } else if (g.container === 'exited' || tries > 45) {
      clearInterval(pollTimer);
      setState('offline');
      offMessage('ÉCHEC BOOT', 'VOIR ONGLET JOBS POUR LES LOGS');
      readout(g.container === 'exited' ? 'CONTENEUR MORT AU BOOT' : 'TIMEOUT 90 S', true);
    } else {
      readout(`BOOT CONTENEUR… (${tries * 2} s) · conteneur: ${g.container || '?'}`);
    }
  }, 2000);
}

async function stop() {
  clearInterval(pollTimer);
  if (rfb) { try { rfb.disconnect(); } catch (e) {} rfb = null; }
  readout('ARRÊT…');
  try {
    await j('/api/launch', {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ kind: 'game-stop', params: {} }),
    });
  } catch (e) {}
  setState('offline');
  offMessage('SIGNAL PERDU', 'APPUYER SUR PLAY');
  readout('JEU ARRÊTÉ');
}

function fullscreen() {
  const f = $('#crt-frame');
  if (document.fullscreenElement) document.exitFullscreen();
  else f.requestFullscreen && f.requestFullscreen();
}

async function sync() {
  const btn = $('#btn-sync');
  btn.disabled = true;
  readout('SYNC GITHUB → VM…');
  let job;
  try {
    job = await j('/api/launch', {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ kind: 'game-sync', params: {} }),
    });
  } catch (e) { job = { error: 'réseau' }; }
  if (job.error) {
    btn.disabled = false;
    readout('SYNC REFUSÉE : ' + job.error, true);
    return;
  }
  // Suivi du job (l'import à froid peut prendre 5-15 min).
  const t0 = Date.now();
  const timer = setInterval(async () => {
    let done = null;
    try {
      const d = await j('/api/jobs');
      done = (d.jobs || []).find(x => x.id === job.id && x.status !== 'running');
    } catch (e) {}
    const min = Math.floor((Date.now() - t0) / 60000);
    if (done) {
      clearInterval(timer);
      btn.disabled = false;
      readout(done.status === 'done' ? 'SYNC + IMPORT OK' : `SYNC ÉCHOUÉE (voir Jobs #${job.id})`,
              done.status !== 'done');
      refreshVersion();
    } else {
      readout(`SYNC + IMPORT EN COURS… (${min} min — long au premier passage)`);
    }
  }, 4000);
}

export async function initGame() {
  $('#btn-play').onclick = play;
  $('#btn-stop').onclick = stop;
  $('#btn-sync').onclick = sync;
  $('#btn-fs').onclick = fullscreen;
  // Son du jeu : flux MP3 depuis la VM, activé au tap (les navigateurs bloquent
  // le son automatique). Se recharge à chaud si le lien casse.
  const sndBtn = $('#btn-sound'), audio = $('#game-audio');
  if (sndBtn && audio) sndBtn.onclick = () => {
    if (audio.paused) {
      audio.src = '/audio/stream?t=' + Date.now();
      audio.play().then(() => { sndBtn.textContent = '🔊 Son'; sndBtn.classList.add('primary'); })
        .catch(() => { sndBtn.textContent = '🔇 indispo'; });
    } else {
      audio.pause(); audio.src = ''; sndBtn.textContent = '🔇 Son'; sndBtn.classList.remove('primary');
    }
  };
  // Quitter l'onglet Jouer coupe le flux vidéo ET le son. Sans ça, la VM
  // continuait d'encoder du VNC pour un écran que personne ne regarde — sur
  // 4 cœurs ARM sans GPU, c'est autant de moins pour les agents. Le jeu, lui,
  // continue de tourner : revenir sur l'onglet se reconnecte.
  window.merlinLeavePlay = () => {
    clearInterval(pollTimer);
    if (rfb) { try { rfb.disconnect(); } catch (e) {} rfb = null; }
    if (audio && !audio.paused) { audio.pause(); audio.src = ''; }
    if (sndBtn) { sndBtn.textContent = '🔇 Son'; sndBtn.classList.remove('primary'); }
    setState('offline');
    offMessage('EN PAUSE', 'REVENIR SUR JOUER POUR RECONNECTER');
  };
  const sel = $('#game-res');
  if (sel) sel.value = autoRes();   // pré-sélection selon l'appareil (modifiable)
  offMessage('SIGNAL PERDU', 'APPUYER SUR PLAY');
  setInterval(refreshVersion, 30000);
  // État initial : si le jeu tourne déjà (autre session), proposer la reconnexion.
  try {
    const g = await j('/api/game');
    versionReadout(g); statusGame(g);
    if (!g.available) {
      readout(g.reason || 'PODMAN ABSENT SUR CET HÔTE', true);
      $('#btn-play').disabled = true;
    } else if (!g.ws_bridge) {
      readout('PONT WS ABSENT — pip install flask-sock', true);
      $('#btn-play').disabled = true;
    } else if (g.vnc_open) {
      readout('JEU DÉJÀ EN COURS — CONNEXION…');
      connectVNC();
    } else {
      readout('PRÊT');
    }
  } catch (e) {
    readout('API INJOIGNABLE', true);
  }
}
