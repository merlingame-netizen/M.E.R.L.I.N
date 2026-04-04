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

const BOOT_LINES: readonly string[] = [
  'BIOS POST check...',
  'Memory: 4096 MB',
  'Loading druid_core.ko',
  'Loading ogham_driver.ko',
  'Ley line scan... FOUND',
  'LLM: M.E.R.L.I.N.-3B',
  'Warmup inference...',
  'Systems ready',
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

async function runPhase1(container: HTMLDivElement): Promise<void> {
  const lineArea = document.createElement('div');
  lineArea.style.cssText = [
    'position:absolute;left:50%;top:30%;transform:translateX(-50%);',
    'font-family:"Courier New",monospace;font-size:13px;line-height:22px;',
    `color:${CRT.DIM};text-align:left;min-width:280px;`,
  ].join('');
  container.appendChild(lineArea);

  for (let i = 0; i < BOOT_LINES.length; i++) {
    const line = document.createElement('div');
    line.textContent = BOOT_LINES[i] ?? '';
    line.style.opacity = '0';
    line.style.transition = 'opacity 0.08s';
    lineArea.appendChild(line);

    await wait(i === 0 ? 80 : 60);
    line.style.opacity = '0.8';
  }

  // Flash all lines to bright, then to amber
  await wait(150);
  Array.from(lineArea.children).forEach(el => {
    (el as HTMLElement).style.color = CRT.PHOSPHOR;
    (el as HTMLElement).style.opacity = '1';
  });
  await wait(100);
  Array.from(lineArea.children).forEach(el => {
    (el as HTMLElement).style.color = CRT.AMBER;
    (el as HTMLElement).style.transition = 'color 0.1s, opacity 0.4s';
  });
  await wait(300);

  // Fade out boot lines
  lineArea.style.transition = 'opacity 0.4s';
  lineArea.style.opacity = '0';
  await wait(420);
  lineArea.remove();
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
    `height:100%;width:0%;background:${CRT.PHOSPHOR};`,
    'transition:width 0.4s ease;',
  ].join('');
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
  await wait(400);

  fillEl.style.width = '60%';
  statusEl.textContent = STEPS[1]!.label;
  // Wait for real fetch to complete before advancing past 60%
  await fetchDone;

  fillEl.style.width = '85%';
  statusEl.textContent = STEPS[2]!.label;
  await wait(400);

  // Complete
  fillEl.style.width = '100%';
  fillEl.style.background = CRT.AMBER;
  statusEl.style.color = CRT.AMBER;
  statusEl.textContent = STEPS[3]!.label;
  await wait(700);

  // Fade out everything
  container.style.transition = 'opacity 0.5s';
  container.style.opacity = '0';
  await wait(520);
}

// =============================================================================
// Main entry point
// =============================================================================

export async function runCeltOSIntro(): Promise<void> {
  // Create full-screen CRT overlay (z-index above everything)
  const overlay = document.createElement('div');
  // Hide legacy #boot-screen HTML element (was z-index:9999 — would cover us)
  const legacyBoot = document.getElementById('boot-screen');
  if (legacyBoot) legacyBoot.style.display = 'none';

  overlay.id = 'celtos-intro';
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
