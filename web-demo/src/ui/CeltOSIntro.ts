// =============================================================================
// CeltOSIntro — Terminal boot sequence (ported from Godot IntroCeltOS.gd)
// Phase 1: CRT terminal boot lines
// Phase 2: CELTOS pixel logo (blocks falling Tetris-style)
// Phase 3: Loading bar + real asset preload (cards.json)
// =============================================================================

import { loadTemplates } from '../game/CardSystem';

// --- CRT palette (matches Godot MerlinVisual.CRT_PALETTE) ---
const CRT = {
  BG:      '#030507',
  PHOSPHOR: '#33ff66',
  DIM:     '#1a8833',
  BRIGHT:  '#88ffaa',
  AMBER:   '#ffaa00',
  BORDER:  '#1a3320',
} as const;

const CELTOS_ASCII = [
  '  \u2588\u2588\u2588\u2588\u2588\u2588\u2557\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2557\u2588\u2588\u2557  \u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2557 \u2588\u2588\u2588\u2588\u2588\u2588\u2557 \u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2557',
  ' \u2588\u2588\u2554\u2550\u2550\u2550\u2550\u255d\u2588\u2588\u2554\u2550\u2550\u2550\u2550\u255d\u2588\u2588\u2551  \u2554\u2550\u2550\u2588\u2588\u2554\u2550\u2550\u255d\u2588\u2588\u2554\u2550\u2550\u2550\u2588\u2588\u2557\u2588\u2588\u2554\u2550\u2550\u2550\u2550\u255d',
  ' \u2588\u2588\u2551     \u2588\u2588\u2588\u2588\u2588\u2557  \u2588\u2588\u2551     \u2588\u2588\u2551   \u2588\u2588\u2551   \u2588\u2588\u2551\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2557',
  ' \u2588\u2588\u2551     \u2588\u2588\u2554\u2550\u2550\u255d  \u2588\u2588\u2551     \u2588\u2588\u2551   \u2588\u2588\u2551   \u2588\u2588\u2551\u2554\u2550\u2550\u2550\u2550\u2588\u2588\u2551',
  ' \u255a\u2588\u2588\u2588\u2588\u2588\u2588\u2557\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2557\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2557\u2588\u2588\u2551   \u255a\u2588\u2588\u2588\u2588\u2588\u2588\u2554\u255d\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2551',
  '  \u255a\u2550\u2550\u2550\u2550\u2550\u255d\u255a\u2550\u2550\u2550\u2550\u2550\u2550\u255d\u255a\u2550\u2550\u2550\u2550\u2550\u2550\u255d\u255a\u2550\u255d    \u255a\u2550\u2550\u2550\u2550\u2550\u255d \u255a\u2550\u2550\u2550\u2550\u2550\u2550\u255d',
  '                        v4.2 KERNEL',
].join('\n');

const BOOT_LINES: readonly string[] = [
  'CELTOS v4.2 KERNEL \u2014 INITIATING MEMORY NODES',
  'LOADING /dev/ogham/18 ... [OK]',
  'MOUNTING SACRED_GROVES_PARTITION ... [OK]',
  'INITIALIZING FACTION_MATRIX (5 branches) ... [OK]',
  'LINKING /lib/merlin/arcana.so ... [OK]',
  'CHECKING LEYLINE INTEGRITY ... [OK]',
  'LOADING FASTROUTE_CARD_POOL (500+ entries) ... [OK]',
  'SPAWNING DAEMON: merlin-omniscient.service ... [OK]',
  'CALIBRATING ANAM_ACCUMULATOR ... [OK]',
  'BINDING BIOME_SHADERS to /dev/gpu ... [OK]',
  'VERIFYING DRUID_CONSENSUS_PROTOCOL ... [OK]',
  'SYNCING CAULDRON_STATE ... [OK]',
  'SYSTEM READY \u2014 AWAITING PLAYER INVOCATION',
];

// CELTOS in 5×3 pixel font (23 cols × 5 rows)
const LOGO_GRID: readonly (readonly number[])[] = [
  [1,1,1,0,1,1,1,0,1,0,0,0,1,1,1,0,1,1,1,0,1,1,1],
  [1,0,0,0,1,0,0,0,1,0,0,0,0,1,0,0,1,0,1,0,1,0,0],
  [1,0,0,0,1,1,0,0,1,0,0,0,0,1,0,0,1,0,1,0,1,1,1],
  [1,0,0,0,1,0,0,0,1,0,0,0,0,1,0,0,1,0,1,0,0,0,1],
  [1,1,1,0,1,1,1,0,1,1,1,0,0,1,0,0,1,1,1,0,1,1,1],
];

const BLOCK_SIZE = 10;
const BLOCK_GAP  = 2;
const BLOCK_STEP = BLOCK_SIZE + BLOCK_GAP;

/** Resolve after `ms` milliseconds. */
function wait(ms: number): Promise<void> {
  return new Promise(res => setTimeout(res, ms));
}

// =============================================================================
// Phase 1 — CRT terminal boot lines
// =============================================================================

// Inject blink keyframes once into document head
function _ensureBlinkStyle(): void {
  if (document.getElementById('crt-blink-style')) return;
  const style = document.createElement('style');
  style.id = 'crt-blink-style';
  style.textContent =
    '@keyframes crt-cursor-blink{0%,49%{opacity:1}50%,100%{opacity:0}}';
  document.head.appendChild(style);
}

// Inject CeltOS scanline + glitch styles (idempotent)
function ensureCeltOSStyles(): void {
  if (document.getElementById('celtos-intro-styles')) return;
  const s = document.createElement('style');
  s.id = 'celtos-intro-styles';
  s.textContent = `
    .celtos-scanlines::after {
      content: '';
      position: absolute;
      inset: 0;
      background: repeating-linear-gradient(
        to bottom,
        transparent 0px,
        transparent 1px,
        rgba(0,0,0,0.22) 1px,
        rgba(0,0,0,0.22) 2px
      );
      pointer-events: none;
      z-index: 10;
    }
    #celtos-scanlines {
      position: absolute;
      inset: 0;
      pointer-events: none;
      z-index: 0;
      background: repeating-linear-gradient(
        0deg,
        rgba(0,0,0,0.15) 0px,
        rgba(0,0,0,0.15) 1px,
        transparent 1px,
        transparent 3px
      );
      animation: scanline-scroll 8s linear infinite;
    }
    @keyframes scanline-scroll {
      from { background-position: 0 0; }
      to   { background-position: 0 24px; }
    }
    @keyframes celtos-glitch {
      0%, 94%, 100% { transform: none; opacity: 1; }
      95%  { transform: translate(-2px, 0) skewX(-3deg); opacity: 0.85; }
      97%  { transform: translate(2px, 0); opacity: 0.9; }
      98%  { transform: none; opacity: 0.7; }
      99%  { transform: translate(-1px, 1px); opacity: 0.95; }
    }
    .celtos-glitch-active { animation: celtos-glitch 3.5s ease-in-out infinite; }
  `;
  document.head.appendChild(s);
}

/** Inject a short green glitch flash div into `container`, auto-removed after `durationMs`. */
function _glitchFlash(container: HTMLElement, durationMs: number): void {
  const h = 10 + Math.random() * 30; // 10–40% of container height
  const t = Math.random() * (100 - h);
  const div = document.createElement('div');
  div.style.cssText = [
    'position:absolute;left:0;width:100%;pointer-events:none;',
    `top:${t.toFixed(1)}%;height:${h.toFixed(1)}%;`,
    'background:rgba(51,255,102,0.04);',
    'z-index:2;',
  ].join('');
  container.appendChild(div);
  setTimeout(() => { div.remove(); }, durationMs);
}

/** Apply a translateX glitch to `el`, reset after `durationMs`. */
function _glitchShift(el: HTMLElement, px: number, durationMs: number): void {
  el.style.transform = `translateX(${px}px)`;
  setTimeout(() => { el.style.transform = ''; }, durationMs);
}

async function runPhase1(container: HTMLDivElement): Promise<void> {
  _ensureBlinkStyle();

  // Scrolling scanline overlay behind boot text
  const scanlineDiv = document.createElement('div');
  scanlineDiv.id = 'celtos-scanlines';
  container.appendChild(scanlineDiv);

  const lineArea = document.createElement('div');
  lineArea.style.cssText = [
    'position:absolute;left:50%;top:28%;transform:translateX(-50%);',
    'font-family:Courier New,monospace;font-size:13px;line-height:22px;',
    `color:${CRT.DIM};text-align:left;min-width:320px;`,
  ].join('');
  container.appendChild(lineArea);

  // ASCII art logo — prepended above boot lines
  const asciiPre = document.createElement('pre');
  asciiPre.textContent = CELTOS_ASCII;
  asciiPre.style.cssText = [
    'color:rgba(51,255,102,0.6);',
    "font-family:'Courier New',monospace;",
    'font-size:7px;line-height:1.1;',
    'margin:0 0 8px 0;overflow:hidden;white-space:pre;',
    'opacity:0;transition:opacity 0.5s ease;',
  ].join('');
  lineArea.appendChild(asciiPre);
  // Trigger fade-in on next frame
  requestAnimationFrame(() => {
    requestAnimationFrame(() => { asciiPre.style.opacity = '0.6'; });
  });
  await wait(500);

  // Blinking cursor element (reused, appended after each line)
  const cursor = document.createElement('span');
  cursor.textContent = '\u258b'; // U+258B LOWER FIVE EIGHTHS BLOCK
  cursor.style.cssText =
    'animation:crt-cursor-blink 0.8s step-end infinite;margin-left:2px;';

  // Random glitch interval — active during lines 3-10 (indices 2-9)
  let glitchIntervalId: ReturnType<typeof setInterval> | null = null;

  const startGlitchInterval = (): void => {
    glitchIntervalId = setInterval(() => {
      if (Math.random() < 0.15) {
        _glitchShift(container, 2, 80);
        _glitchFlash(container, 80);
      }
    }, 800);
  };

  const stopGlitchInterval = (): void => {
    if (glitchIntervalId !== null) {
      clearInterval(glitchIntervalId);
      glitchIntervalId = null;
    }
  };

  for (let i = 0; i < BOOT_LINES.length; i++) {
    // Start glitch interval when entering the 3-10 range (0-based index 2)
    if (i === 2) startGlitchInterval();
    // Stop when leaving that range
    if (i === 10) stopGlitchInterval();

    const line = document.createElement('div');
    const text = BOOT_LINES[i] ?? '';
    line.style.opacity = '0';
    line.style.transition = 'opacity 0.08s';
    lineArea.appendChild(line);

    // Show line with cursor
    await wait(i === 0 ? 80 : 70);
    line.style.opacity = '0.85';

    const isSeparator = text.startsWith('\u2500');
    const isHeader = i === 0;

    if (isHeader) {
      line.style.color = CRT.PHOSPHOR;
      line.style.opacity = '1';
      line.textContent = text;
    } else if (isSeparator) {
      line.style.color = CRT.BORDER;
      line.textContent = text;
    } else {
      line.textContent = text;
      line.appendChild(cursor);
      await wait(120);
      // Remove cursor from this line before moving to next
      if (cursor.parentNode === line) line.removeChild(cursor);
    }
  }

  // Ensure glitch interval is cleared (safety — in case BOOT_LINES.length <= 10)
  stopGlitchInterval();

  // After last line, leave cursor visible briefly
  const lastLine = lineArea.lastElementChild as HTMLElement | null;
  if (lastLine) lastLine.appendChild(cursor);
  await wait(300);
  if (cursor.parentNode) cursor.parentNode.removeChild(cursor);

  // Final reveal glitch sequence — 3 rapid flashes over 300ms
  window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'transition' } }));

  // Flash 1: shift right
  _glitchShift(container, 3, 80);
  _glitchFlash(container, 80);
  await wait(100);

  // Flash 2: shift left
  _glitchShift(container, -3, 80);
  _glitchFlash(container, 80);
  await wait(100);

  // Flash 3: shift right again
  _glitchShift(container, 3, 80);
  _glitchFlash(container, 80);
  await wait(100);

  // Green flash overlay for 150ms
  const greenFlash = document.createElement('div');
  greenFlash.style.cssText = [
    'position:absolute;inset:0;pointer-events:none;',
    'background:rgba(51,255,102,0.08);',
    'z-index:3;',
  ].join('');
  container.appendChild(greenFlash);
  await wait(150);
  greenFlash.remove();

  // Ensure container is back to normal transform after glitch shifts
  container.style.transform = '';

  // Flash all lines to bright phosphor, then amber
  await wait(100);
  Array.from(lineArea.children).forEach(el => {
    (el as HTMLElement).style.color = CRT.PHOSPHOR;
    (el as HTMLElement).style.opacity = '1';
  });
  await wait(120);
  Array.from(lineArea.children).forEach(el => {
    (el as HTMLElement).style.color = CRT.AMBER;
    (el as HTMLElement).style.transition = 'color 0.15s, opacity 0.4s';
  });
  await wait(350);

  // Fade out boot lines
  lineArea.style.transition = 'opacity 0.4s';
  lineArea.style.opacity = '0';
  await wait(420);
  lineArea.remove();

  // Remove scanline overlay when phase ends
  scanlineDiv.remove();
}

// =============================================================================
// Phase 2 — CELTOS pixel logo (blocks fall from top)
// =============================================================================

async function runPhase2(container: HTMLDivElement): Promise<HTMLDivElement> {
  const cols = LOGO_GRID[0]?.length ?? 23;
  const rows = LOGO_GRID.length;
  const logoW = cols * BLOCK_STEP - BLOCK_GAP;
  const logoH = rows * BLOCK_STEP - BLOCK_GAP;

  const logoWrap = document.createElement('div');
  logoWrap.style.cssText = [
    'position:absolute;left:50%;top:50%;',
    `transform:translate(-50%,-50%);`,
    `width:${logoW}px;height:${logoH}px;`,
    'opacity:0;transition:opacity 0.2s;',
  ].join('');
  container.appendChild(logoWrap);

  // Build block elements
  const blocks: HTMLDivElement[] = [];
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      if (!LOGO_GRID[r]?.[c]) continue;
      const block = document.createElement('div');
      const finalTop = r * BLOCK_STEP;
      block.style.cssText = [
        'position:absolute;',
        `left:${c * BLOCK_STEP}px;`,
        `top:${finalTop}px;`,
        `width:${BLOCK_SIZE}px;height:${BLOCK_SIZE}px;`,
        `background:${(r + c) % 2 === 0 ? CRT.PHOSPHOR : CRT.BRIGHT};`,
        // Start above viewport — will fall into place
        `transform:translateY(${-350 - Math.random() * 200}px);`,
        'transition:transform 0.35s cubic-bezier(0.33,1,0.68,1);',
      ].join('');
      block.dataset['col'] = String(c);
      logoWrap.appendChild(block);
      blocks.push(block);
    }
  }

  // Sort by column for staggered fall
  blocks.sort((a, b) => Number(a.dataset['col']) - Number(b.dataset['col']));

  // Show wrapper
  await wait(50);
  logoWrap.style.opacity = '1';

  // Trigger falls with staggered delays
  blocks.forEach((block, i) => {
    setTimeout(() => {
      block.style.transform = 'translateY(0)';
    }, i * 15 + Math.random() * 20);
  });

  // Wait for all falls to complete (~blocks * 15ms + 350ms anim)
  await wait(blocks.length * 15 + 400);

  // Flash amber, then back to phosphor
  blocks.forEach(b => { b.style.background = CRT.AMBER; b.style.transition = 'background 0.15s'; });
  await wait(150);
  blocks.forEach(b => { b.style.background = CRT.PHOSPHOR; });
  await wait(500);

  return logoWrap;
}

// =============================================================================
// Phase 3 — Loading bar + real asset fetch
// =============================================================================

async function runPhase3(container: HTMLDivElement, logoWrap: HTMLDivElement): Promise<void> {
  // Slide logo up slightly
  logoWrap.style.transition = 'transform 0.4s ease, opacity 0.4s';
  logoWrap.style.transform = 'translate(-50%, calc(-50% - 44px))';

  // Loading bar container
  const barW = 320;
  const barH = 10;

  const barGroup = document.createElement('div');
  barGroup.style.cssText = [
    'position:absolute;left:50%;top:60%;transform:translateX(-50%);',
    `width:${barW}px;opacity:0;transition:opacity 0.3s;`,
  ].join('');

  const statusEl = document.createElement('div');
  statusEl.style.cssText = [
    `font-family:"Courier New",monospace;font-size:12px;`,
    `color:${CRT.DIM};margin-bottom:8px;text-align:center;`,
    'transition:color 0.2s;',
  ].join('');
  statusEl.textContent = 'Initialisation du système druidique...';
  barGroup.appendChild(statusEl);

  const trackEl = document.createElement('div');
  trackEl.style.cssText = [
    `width:${barW}px;height:${barH}px;`,
    `border:1px solid ${CRT.BORDER};background:#010305;`,
    'position:relative;overflow:hidden;',
  ].join('');

  const fillEl = document.createElement('div');
  fillEl.style.cssText = [
    'height:100%;width:0%;',
    'background:linear-gradient(90deg,#1a8833,#33ff66);',
    'transition:width 0.4s ease;',
  ].join('');
  // Pulsing glow on the progress bar
  fillEl.style.boxShadow = '0 0 8px rgba(51,255,102,0.6), 0 0 2px rgba(51,255,102,1.0)';
  trackEl.appendChild(fillEl);
  barGroup.appendChild(trackEl);
  container.appendChild(barGroup);

  await wait(50);
  barGroup.style.opacity = '1';
  await wait(350);

  // Load templates (real network request) + animate bar
  const STEPS: Array<{ pct: number; label: string; waitMs: number }> = [
    { pct: 30,  label: 'Chargement des runes oghamiques...',  waitMs: 300 },
    { pct: 60,  label: 'Connexion aux lignes de ley...',      waitMs: 0   }, // 0 = wait for fetch
    { pct: 85,  label: 'Éveil de M.E.R.L.I.N...',            waitMs: 400 },
    { pct: 100, label: 'Système prêt.',                       waitMs: 600 },
  ];

  // Kick off real asset load in parallel
  const fetchDone = loadTemplates().catch(() => { /* silent — CardSystem has fallback */ });

  fillEl.style.width = '30%';
  statusEl.textContent = STEPS[0]!.label;
  // Milestone flicker at ~33%
  fillEl.style.opacity = '0.4';
  await wait(60);
  fillEl.style.opacity = '1';
  await wait(400);

  fillEl.style.width = '60%';
  statusEl.textContent = STEPS[1]!.label;
  // Wait for real fetch to complete before advancing past 60%
  await fetchDone;
  // Milestone flicker at ~66%
  fillEl.style.opacity = '0.4';
  await wait(60);
  fillEl.style.opacity = '1';

  fillEl.style.width = '85%';
  statusEl.textContent = STEPS[2]!.label;
  await wait(400);

  // Complete
  fillEl.style.width = '100%';
  fillEl.style.background = CRT.AMBER;
  statusEl.style.color = CRT.AMBER;
  statusEl.textContent = STEPS[3]!.label;
  await wait(700);

  // Boot complete — SFX + screen flash
  window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'magic_reveal' } }));
  setTimeout(() => {
    window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'win' } }));
  }, 400);

  // Inject boot-flash keyframes (idempotent)
  if (!document.getElementById('celtos-boot-flash-style')) {
    const flashStyle = document.createElement('style');
    flashStyle.id = 'celtos-boot-flash-style';
    flashStyle.textContent =
      '@keyframes celtos-boot-flash{0%{opacity:0}20%{opacity:1}100%{opacity:0}}';
    document.head.appendChild(flashStyle);
  }
  // Full-screen phosphor green flash overlay
  const flashDiv = document.createElement('div');
  flashDiv.style.cssText = [
    'position:fixed;inset:0;',
    'background:rgba(51,255,102,0.12);',
    'animation:celtos-boot-flash 800ms ease-out forwards;',
    'pointer-events:none;z-index:10001;',
  ].join('');
  document.body.appendChild(flashDiv);
  setTimeout(() => { flashDiv.remove(); }, 900);

  // CRT power-on glitch after boot complete
  await wait(200);
  container.classList.add('celtos-glitch-active');
  // Brief green flash (CRT tube warming)
  container.style.transition = 'background 0.05s';
  container.style.background = 'rgba(4,16,6,0.98)';
  await wait(50);
  container.style.background = 'rgba(1,8,2,0.97)';
  container.style.transition = '';
  await wait(500);

  // Fade out everything
  container.style.transition = 'opacity 0.5s';
  container.style.opacity = '0';
  await wait(520);
}

// =============================================================================
// Main entry point
// =============================================================================

export async function runCeltOSIntro(): Promise<void> {
  ensureCeltOSStyles();

  // Create full-screen CRT overlay (z-index above everything)
  const overlay = document.createElement('div');
  // Hide legacy #boot-screen HTML element (was z-index:9999 — would cover us)
  const legacyBoot = document.getElementById('boot-screen');
  if (legacyBoot) legacyBoot.style.display = 'none';

  overlay.id = 'celtos-intro';
  overlay.className = 'celtos-scanlines';
  overlay.style.cssText = [
    'position:fixed;inset:0;z-index:10000;',
    `background:${CRT.BG};`,
    'display:flex;align-items:center;justify-content:center;',
    'overflow:hidden;',
  ].join('');
  document.body.appendChild(overlay);

  // CRT scanline overlay (subtle, CSS only)
  const scanlines = document.createElement('div');
  scanlines.style.cssText = [
    'position:absolute;inset:0;pointer-events:none;',
    'background:repeating-linear-gradient(0deg,transparent,transparent 2px,rgba(0,0,0,0.08) 2px,rgba(0,0,0,0.08) 4px);',
    'z-index:1;',
  ].join('');
  overlay.appendChild(scanlines);

  const container = document.createElement('div');
  container.style.cssText = 'position:relative;width:100%;height:100%;';
  overlay.appendChild(container);

  // C167: skip hint — appears bottom-right after 400ms so it doesn't flash on fast loads
  const skipHint = document.createElement('div');
  skipHint.textContent = '[ CLIC ou TOUCHE pour passer ]';
  skipHint.style.cssText = [
    'position:absolute;bottom:18px;right:18px;',
    'color:rgba(51,255,102,0.35);font-family:"Courier New",Courier,monospace;font-size:11px;',
    'letter-spacing:0.08em;pointer-events:none;opacity:0;transition:opacity 0.4s ease;',
    'z-index:5;',
  ].join('');
  overlay.appendChild(skipHint);
  setTimeout(() => { skipHint.style.opacity = '1'; }, 400);

  // C166: click or any key skips the intro immediately.
  // Promise.race() races the 3-phase sequence against the skip signal.
  // Phase 3 contains the real asset fetch (loadTemplates) — it continues in the background
  // after skip so templates are still available when the first card is drawn.
  const skipSignal = new Promise<void>((res) => {
    const onSkip = (): void => {
      overlay.removeEventListener('click', onSkip);
      document.removeEventListener('keydown', onSkip);
      res();
    };
    overlay.addEventListener('click', onSkip, { once: true });
    document.addEventListener('keydown', onSkip, { once: true });
  });

  try {
    await Promise.race([
      (async () => {
        await runPhase1(container);
        const logoWrap = await runPhase2(container);
        await runPhase3(container, logoWrap);
      })(),
      skipSignal,
    ]);
  } finally {
    overlay.remove();
  }
}
