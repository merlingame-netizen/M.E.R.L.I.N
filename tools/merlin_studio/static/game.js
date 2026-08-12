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

async function connectVNC() {
  setState('connecting');
  readout('CONNEXION VNC…');
  let ticket;
  try {
    ticket = (await j('/api/vnc/ticket', { method: 'POST' })).ticket;
  } catch (e) {
    setState('offline');
    readout('TICKET REFUSÉ — RECHARGER LA PAGE', true);
    return;
  }
  const proto = location.protocol === 'https:' ? 'wss' : 'ws';
  const url = `${proto}://${location.host}/websockify?ticket=${encodeURIComponent(ticket)}`;
  rfb = new RFB($('#vnc-screen'), url);
  rfb.scaleViewport = true;
  rfb.showDotCursor = false;
  // Le goulot est le CPU de la VM (4 cœurs ARM, encodage logiciel), pas la bande
  // passante : on baisse la compression (moins de zlib à faire) et on remonte la
  // qualité d'image. Résultat : moins de latence ET une image plus nette.
  rfb.qualityLevel = 7;
  rfb.compressionLevel = 1;
  rfb.addEventListener('connect', () => {
    setState('live');
    readout(`SIGNAL OK · ${rfb._fbWidth || ''}×${rfb._fbHeight || ''}`);
    refreshVersion();
  });
  rfb.addEventListener('disconnect', ev => {
    rfb = null;
    setState('offline');
    offMessage('SIGNAL PERDU', 'APPUYER SUR PLAY');
    readout(ev.detail && ev.detail.clean ? 'DÉCONNECTÉ' : 'CONNEXION PERDUE', !ev.detail?.clean);
  });
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
