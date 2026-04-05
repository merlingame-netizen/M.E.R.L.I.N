// =============================================================================
// MapGenOverlay — Procedural map + LLM scenario generation screen
//
// Flow:
//  1. Parchment overlay fades in
//  2. LLM generates scenario (titre + 3 paragraphes + 5 events) in parallel
//  3. Left panel: scenario typewriters in while map draws on right
//  4. Right panel (canvas): terrain → path → event nodes drawn progressively
//  5. "Entrer" button / auto-continue → zoom-into-map transition → 3D run
//
// Fallback: if LLM unavailable or slow, use procedural scenario (no block).
// =============================================================================

import type { RunScenario, RunScenarioEvent } from '../llm/GroqAdapter';
import { getLLMAdapter } from '../llm/GroqAdapter';
import { store } from '../game/Store';

// ── CRT scanline texture (generated once per overlay) ────────────────────────

function createScanlineTexture(w: number, h: number): HTMLCanvasElement {
  const offscreen = document.createElement('canvas');
  offscreen.width = w;
  offscreen.height = h;
  const ctx = offscreen.getContext('2d')!;
  // Horizontal scanlines every 2px
  for (let y = 0; y < h; y += 2) {
    ctx.fillStyle = 'rgba(0,0,0,0.18)';
    ctx.fillRect(0, y, w, 1);
  }
  // Occasional phosphor shimmer lines
  for (let i = 0; i < 4; i++) {
    const y = Math.floor(Math.random() * h);
    ctx.fillStyle = 'rgba(51,255,102,0.025)';
    ctx.fillRect(0, y, w, 1);
  }
  return offscreen;
}

// ── SFX dispatch helper ───────────────────────────────────────────────────────

function sfx(sound: string): void {
  window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound } }));
}

// ── Compass rose — CRT terminal style ─────────────────────────────────────────

function drawCompassRose(ctx: CanvasRenderingContext2D, cx: number, cy: number, size: number): void {
  ctx.save();
  ctx.translate(cx, cy);

  const s = size;

  // Draw 4 main spokes (N/S/E/W)
  for (const [x1, y1, x2, y2] of [
    [0, -s, 0, s * 0.35],
    [0,  s, 0, -s * 0.35],
    [-s, 0, s * 0.35, 0],
    [ s, 0, -s * 0.35, 0],
  ] as [number, number, number, number][]) {
    ctx.beginPath();
    ctx.moveTo(x1, y1);
    ctx.lineTo(x2, y2);
    ctx.strokeStyle = PAL.inkFaint;
    ctx.lineWidth = 0.8;
    ctx.stroke();
  }

  // Diamond arrow for each cardinal (N bigger) — CRT green fill
  const drawDiamond = (ax: number, ay: number, len: number, angle: number): void => {
    ctx.save();
    ctx.rotate(angle);
    ctx.beginPath();
    ctx.moveTo(ax, ay);
    ctx.lineTo(ax - len * 0.28, ay + len * 0.5);
    ctx.lineTo(ax, ay + len);
    ctx.lineTo(ax + len * 0.28, ay + len * 0.5);
    ctx.closePath();
    ctx.fillStyle = PAL.accent;
    ctx.fill();
    ctx.strokeStyle = PAL.border;
    ctx.lineWidth = 0.6;
    ctx.stroke();
    ctx.restore();
  };

  drawDiamond(0, -s, s * 0.42, 0);
  drawDiamond(0, s * 0.58, s * 0.28, Math.PI);
  drawDiamond(s * 0.58, 0, s * 0.28, Math.PI / 2);
  drawDiamond(-s * 0.58, 0, s * 0.28, -Math.PI / 2);

  // Center dot
  ctx.beginPath();
  ctx.arc(0, 0, s * 0.12, 0, Math.PI * 2);
  ctx.fillStyle = PAL.accent;
  ctx.fill();

  // N label — CRT monospace
  ctx.fillStyle = PAL.ink;
  ctx.font = `bold ${Math.max(7, Math.floor(s * 0.38))}px 'Courier New',monospace`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText('N', 0, -s * 1.42);

  ctx.restore();
}

// ── Palette ───────────────────────────────────────────────────────────────────

// CRT / phosphor-green terminal palette
const PAL = {
  bg:         '#060d06',
  ink:        '#33ff66',
  inkFaint:   'rgba(51,255,102,0.22)',
  inkPath:    '#1aff44',
  accent:     '#33ff66',
  accentGlow: 'rgba(51,255,102,0.14)',
  border:     '#1a8833',
  titleGold:  '#33ff66',
  eventRing:  '#0a3318',
  shadow:     'rgba(0,0,0,0.80)',
} as const;

const EVENT_COLORS: Readonly<Record<string, string>> = {
  rencontre: '#33ff66',
  obstacle:  '#ff4444',
  tresor:    '#ffcc00',
  danger:    '#ff2222',
  mystere:   '#aa88ff',
  fin:       '#33ffcc',
} as const;

// ── Biome fallback scenarios ──────────────────────────────────────────────────

interface FallbackScenario {
  titre: string;
  scenario: string[];
  events: RunScenarioEvent[];
}

function buildFallback(biome: string): RunScenario {
  const fallbacks: Readonly<Record<string, FallbackScenario>> = {
    foret_broceliande: {
      titre: "L'Appel des Chênes Anciens",
      scenario: [
        "La forêt de Brocéliande murmure des noms oubliés depuis l'aube des temps celtiques.",
        "Des lucioles bleues guidaient jadis les initiés vers les pierres oghamiques perdues.",
        "Ton Anam vibre au contact de cette terre sacrée. Les arbres te reconnaissent.",
      ],
      events: [
        { position: 0.12, type: 'rencontre', nom: 'Druide Errant',    icone: '◈' },
        { position: 0.30, type: 'mystere',   nom: 'Source Noire',     icone: '◇' },
        { position: 0.50, type: 'obstacle',  nom: 'Meute des Loups',  icone: '⬟' },
        { position: 0.70, type: 'tresor',    nom: 'Pierre Oghamique', icone: '◆' },
        { position: 0.90, type: 'fin',       nom: 'Clairière Sacrée', icone: '⊕' },
      ],
    },
    cotes_sauvages: {
      titre: "Les Falaises de l'Awen",
      scenario: [
        "Le vent marin porte les voix des ancêtres qui se sont noyés en gardant les secrets.",
        "Les rochers noirs émergent de la brume comme des sentinelles oubliées.",
        "Chaque vague efface un peu plus les ogham gravés sur la falaise. Il faut se hâter.",
      ],
      events: [
        { position: 0.12, type: 'rencontre', nom: 'Pêcheur Maudit',   icone: '◈' },
        { position: 0.32, type: 'danger',    nom: 'Marée Montante',   icone: '⬡' },
        { position: 0.52, type: 'mystere',   nom: 'Grotte Immergée',  icone: '◇' },
        { position: 0.72, type: 'tresor',    nom: 'Épave Druidique',  icone: '◆' },
        { position: 0.90, type: 'fin',       nom: 'Phare des Âmes',   icone: '⊕' },
      ],
    },
  };

  const chosen = fallbacks[biome] ?? fallbacks['foret_broceliande']!;
  return chosen as RunScenario;
}

// ── Map data structure ────────────────────────────────────────────────────────

interface MapPoint { x: number; y: number }

interface MapData {
  pathPoints: MapPoint[];
  terrainPatches: Array<{ points: MapPoint[]; color: string }>;
  events: RunScenarioEvent[];
}

function buildMapData(
  w: number,
  h: number,
  events: readonly RunScenarioEvent[],
  biome: string,
): MapData {
  const R = () => Math.random();
  const pad = 40;

  // Path: winding from bottom-center to top-center
  const pathPoints: MapPoint[] = [];
  const steps = 12;
  for (let i = 0; i <= steps; i++) {
    const t = i / steps;
    const y = h - pad - t * (h - pad * 2);
    const wobble = Math.sin(t * Math.PI * 2.5 + 0.8) * (w * 0.18) + (R() - 0.5) * 30;
    pathPoints.push({ x: w / 2 + wobble, y });
  }

  // Terrain patches — CRT phosphor-green tinted blobs (dark bg, subtle hue identity)
  const biomeColor: Readonly<Record<string, string[]>> = {
    foret_broceliande: ['rgba(10,40,18,0.55)', 'rgba(8,32,14,0.42)', 'rgba(14,48,22,0.48)'],
    cotes_sauvages:    ['rgba(8,28,40,0.50)',  'rgba(6,22,36,0.40)', 'rgba(10,34,50,0.45)'],
    marais_korrigans:  ['rgba(10,38,8,0.52)',  'rgba(8,28,6,0.42)',  'rgba(6,44,4,0.48)'],
    landes_bruyere:    ['rgba(30,8,28,0.50)',  'rgba(24,6,22,0.40)', 'rgba(36,10,34,0.45)'],
    cercles_pierres:   ['rgba(16,10,36,0.52)', 'rgba(12,8,28,0.42)', 'rgba(20,12,44,0.48)'],
    villages_celtes:   ['rgba(36,22,6,0.50)',  'rgba(28,16,4,0.40)', 'rgba(44,28,8,0.45)'],
    collines_dolmens:  ['rgba(14,24,8,0.52)',  'rgba(10,18,6,0.42)', 'rgba(18,30,10,0.48)'],
    iles_mystiques:    ['rgba(6,28,36,0.50)',  'rgba(4,22,28,0.40)', 'rgba(8,34,44,0.45)'],
  };
  const colors = biomeColor[biome] ?? biomeColor['foret_broceliande']!;

  const terrainPatches = Array.from({ length: 9 }, (_, i) => {
    const cx = pad + R() * (w - pad * 2);
    const cy = pad + R() * (h - pad * 2);
    const r1 = 30 + R() * 60;
    const r2 = 20 + R() * 50;
    const sides = 6 + Math.floor(R() * 4);
    const pts: MapPoint[] = Array.from({ length: sides }, (__, j) => {
      const a = (j / sides) * Math.PI * 2;
      return {
        x: cx + Math.cos(a) * (r1 + R() * 20),
        y: cy + Math.sin(a) * (r2 + R() * 15),
      };
    });
    return { points: pts, color: colors[i % colors.length]! };
  });

  return { pathPoints, terrainPatches, events: [...events] };
}

// ── Canvas drawing helpers ────────────────────────────────────────────────────

function drawPatchAt(
  ctx: CanvasRenderingContext2D,
  patch: { points: MapPoint[]; color: string },
  progress: number,
): void {
  if (progress <= 0 || patch.points.length < 2) return;
  const n = Math.ceil(patch.points.length * Math.min(progress, 1));
  ctx.beginPath();
  ctx.moveTo(patch.points[0]!.x, patch.points[0]!.y);
  for (let i = 1; i < n; i++) {
    ctx.lineTo(patch.points[i]!.x, patch.points[i]!.y);
  }
  if (progress >= 1) ctx.closePath();
  // CRT tint: biome color converted to phosphor-green toned overlay
  ctx.fillStyle = patch.color;
  ctx.fill();
  ctx.strokeStyle = PAL.inkFaint;
  ctx.lineWidth = 0.6;
  ctx.stroke();
}

function drawPathAt(
  ctx: CanvasRenderingContext2D,
  pts: MapPoint[],
  progress: number,
): void {
  if (pts.length < 2 || progress <= 0) return;
  const totalSegments = pts.length - 1;
  const drawn = progress * totalSegments;
  const fullSegs = Math.floor(drawn);
  const frac = drawn - fullSegs;

  ctx.beginPath();
  ctx.moveTo(pts[0]!.x, pts[0]!.y);

  for (let i = 0; i < fullSegs && i < totalSegments; i++) {
    ctx.lineTo(pts[i + 1]!.x, pts[i + 1]!.y);
  }
  // Partial last segment
  if (fullSegs < totalSegments && frac > 0) {
    const from = pts[fullSegs]!;
    const to = pts[fullSegs + 1]!;
    ctx.lineTo(from.x + (to.x - from.x) * frac, from.y + (to.y - from.y) * frac);
  }

  // CRT primary path stroke — phosphor green
  ctx.strokeStyle = PAL.inkPath;
  ctx.lineWidth = 3;
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  ctx.stroke();

  // Dashed glow overlay — terminal feel
  ctx.setLineDash([6, 8]);
  ctx.strokeStyle = PAL.accentGlow;
  ctx.lineWidth = 6;
  ctx.stroke();
  ctx.setLineDash([]);
}

function drawEventNode(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  event: RunScenarioEvent,
  alpha: number,
): void {
  ctx.save();
  ctx.globalAlpha = alpha;

  const color = EVENT_COLORS[event.type] ?? PAL.accent;

  // Outer glow ring — phosphor bloom
  ctx.beginPath();
  ctx.arc(x, y, 20, 0, Math.PI * 2);
  ctx.fillStyle = `rgba(51,255,102,0.08)`;
  ctx.fill();

  // Main circle — CRT dark bg
  ctx.beginPath();
  ctx.arc(x, y, 13, 0, Math.PI * 2);
  ctx.fillStyle = PAL.bg;
  ctx.fill();
  ctx.strokeStyle = color;
  ctx.lineWidth = 1.5;
  ctx.stroke();

  // Icon — monospace
  ctx.fillStyle = color;
  ctx.font = `bold 13px 'Courier New',monospace`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(event.icone, x, y);

  // Event-type glyph overlay — CRT terminal identifier
  const GLYPH_MAP: Record<string, string> = {
    combat: '⚔', decouverte: '?', repos: '+', danger: '!', mystere: '*',
  };
  const nodeR = 13;
  const glyph = GLYPH_MAP[event.type] ?? '•';
  ctx.save();
  ctx.font = `bold ${Math.round(nodeR * 1.1)}px "Courier New", monospace`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = 'rgba(1,8,2,0.92)';
  ctx.fillText(glyph, x, y);
  ctx.restore();

  // Label below — CRT green
  ctx.fillStyle = PAL.ink;
  ctx.font = `8px 'Courier New',monospace`;
  ctx.fillText(event.nom.toUpperCase(), x, y + 26);

  ctx.restore();
}

function getPathPoint(pts: MapPoint[], t: number): MapPoint {
  const total = pts.length - 1;
  const seg = t * total;
  const i = Math.min(Math.floor(seg), total - 1);
  const frac = seg - i;
  const from = pts[i]!;
  const to = pts[i + 1]!;
  return {
    x: from.x + (to.x - from.x) * frac,
    y: from.y + (to.y - from.y) * frac,
  };
}

// ── Biome glyph decorations — scattered symbols drawn beneath path ────────────

function drawBiomeDecorations(
  ctx: CanvasRenderingContext2D,
  w: number,
  h: number,
  biome: string,
): void {
  ctx.save();
  ctx.globalAlpha = 0.18;
  ctx.font = '11px "Courier New", monospace';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';

  const BIOME_GLYPHS: Readonly<Record<string, readonly string[]>> = {
    foret_broceliande: ['♣', '∗', '♠', '∗'],
    cotes_sauvages:    ['≈', '〰', '∿', '≋'],
    marais_korrigans:  ['·', '∴', '·', '∵'],
    landes_bruyere:    ['✦', '∴', '✦', '·'],
    cercles_pierres:   ['◈', '⊕', '◉', '△'],
    monts_brumeux:     ['∧', '⌂', '∧', '⌒'],
    plaine_druides:    ['✤', '❋', '✦', '✤'],
    vallee_anciens:    ['⌂', '□', '⌂', '◻'],
  };

  const glyphs = BIOME_GLYPHS[biome] ?? ['·', '∴', '·', '·'];
  ctx.fillStyle = '#33ff66';

  const seed = biome.length * 137;
  for (let i = 0; i < 25; i++) {
    const px = ((seed * (i + 1) * 1237 + i * 4567) % (w - 30)) + 15;
    const py = ((seed * (i + 3) * 2341 + i * 3891) % (h - 30)) + 15;
    const glyph = glyphs[i % glyphs.length]!;
    ctx.fillText(glyph, px, py);
  }
  ctx.restore();
}

// ── Hero position marker at path start ───────────────────────────────────────

function drawHeroMarker(ctx: CanvasRenderingContext2D, x: number, y: number): void {
  ctx.save();
  // Outer pulse ring
  ctx.strokeStyle = 'rgba(51,255,102,0.6)';
  ctx.lineWidth = 1.5;
  ctx.beginPath();
  ctx.arc(x, y, 10, 0, Math.PI * 2);
  ctx.stroke();
  // Inner filled circle
  ctx.fillStyle = '#33ff66';
  ctx.beginPath();
  ctx.arc(x, y, 4, 0, Math.PI * 2);
  ctx.fill();
  // ">" cursor symbol above
  ctx.fillStyle = '#33ff66';
  ctx.font = 'bold 10px "Courier New", monospace';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'bottom';
  ctx.fillText('>', x, y - 11);
  ctx.restore();
}

// ── Border decorator — CRT terminal frame ─────────────────────────────────────

function drawCelticBorder(ctx: CanvasRenderingContext2D, w: number, h: number): void {
  const m = 10;

  // Outer dim frame
  ctx.strokeStyle = PAL.inkFaint;
  ctx.lineWidth = 1;
  ctx.strokeRect(m, m, w - m * 2, h - m * 2);

  // Inner bright frame
  ctx.strokeStyle = PAL.border;
  ctx.lineWidth = 1.5;
  ctx.strokeRect(m + 5, m + 5, w - (m + 5) * 2, h - (m + 5) * 2);

  // Corner bracket accents [ ]
  const b = 18;
  const corners: [number, number, number, number][] = [
    [m + 5, m + 5,  1,  1],
    [w - m - 5, m + 5, -1,  1],
    [m + 5, h - m - 5,  1, -1],
    [w - m - 5, h - m - 5, -1, -1],
  ];
  ctx.strokeStyle = PAL.accent;
  ctx.lineWidth = 2;
  for (const [cx, cy, dx, dy] of corners) {
    ctx.beginPath();
    ctx.moveTo(cx + dx * b, cy);
    ctx.lineTo(cx, cy);
    ctx.lineTo(cx, cy + dy * b);
    ctx.stroke();
  }
}

// ── Easing helpers ────────────────────────────────────────────────────────────

/** Ease-out bounce — maps t ∈ [0,1] to a bounced value ∈ [0,1] */
function easeOutBounce(t: number): number {
  const n1 = 7.5625;
  const d1 = 2.75;
  if (t < 1 / d1) {
    return n1 * t * t;
  } else if (t < 2 / d1) {
    const t2 = t - 1.5 / d1;
    return n1 * t2 * t2 + 0.75;
  } else if (t < 2.5 / d1) {
    const t2 = t - 2.25 / d1;
    return n1 * t2 * t2 + 0.9375;
  } else {
    const t2 = t - 2.625 / d1;
    return n1 * t2 * t2 + 0.984375;
  }
}

// ── Animation state type ──────────────────────────────────────────────────────

interface AnimState {
  progress: number;
  phase: 'path' | 'zones' | 'done';
  /** Per-zone elapsed time in ms (starts counting when zone drop-in begins) */
  zoneTimers: number[];
  rafId: number;
  lastTs: number;
}

// ── Wait helper ───────────────────────────────────────────────────────────────

function wait(ms: number): Promise<void> {
  return new Promise((res) => setTimeout(res, ms));
}

// ── Typewriter ────────────────────────────────────────────────────────────────

async function typewrite(el: HTMLElement, text: string, ms = 22): Promise<void> {
  el.textContent = '';
  for (const ch of text) {
    el.textContent += ch;
    await wait(ms);
  }
}

// ── Biome display names ───────────────────────────────────────────────────────

const BIOME_DISPLAY_NAMES: Record<string, string> = {
  foret_broceliande: 'FORÊT DE BROCÉLIANDE',
  cotes_sauvages:    'CÔTES SAUVAGES',
  marais_korrigans:  'MARAIS DES KORRIGANS',
  landes_bruyere:    'LANDES DE BRUYÈRE',
  cercles_pierres:   'CERCLES DE PIERRES',
  monts_brumeux:     'MONTS BRUMEUX',
  plaine_druides:    'PLAINE DES DRUIDES',
  vallee_anciens:    'VALLÉE DES ANCIENS',
};

// ── Faction reputation mini-bars ─────────────────────────────────────────────

const FACTION_COLORS: Readonly<Record<string, string>> = {
  druides:   '#33ff66',
  anciens:   '#64b4ff',
  korrigans: '#b450ff',
  niamh:     '#ffb4dc',
  ankou:     '#8ca0b4',
} as const;

const FACTION_ABBR: Readonly<Record<string, string>> = {
  druides:   'DRU',
  anciens:   'ANC',
  korrigans: 'KOR',
  niamh:     'NIA',
  ankou:     'ANK',
} as const;

const FACTION_ORDER: ReadonlyArray<string> = [
  'druides', 'anciens', 'korrigans', 'niamh', 'ankou',
];

function buildFactionBars(factions: Readonly<Record<string, number>>): HTMLElement {
  const container = document.createElement('div');
  container.style.cssText = [
    'position:absolute;right:8px;top:50%;transform:translateY(-50%);',
    'display:flex;flex-direction:column;gap:3px;',
    'pointer-events:none;z-index:10;',
  ].join('');

  for (const id of FACTION_ORDER) {
    const rep = Math.max(0, Math.min(100, factions[id] ?? 0));
    const filled = Math.floor(rep / 12.5);
    const bar = '█'.repeat(filled) + '░'.repeat(8 - filled);
    const repStr = String(Math.round(rep)).padStart(2, '0');
    const color = FACTION_COLORS[id] ?? '#33ff66';
    const abbr = FACTION_ABBR[id] ?? id.slice(0, 3).toUpperCase();

    const row = document.createElement('div');
    row.style.cssText = [
      `color:${color};`,
      `font-size:9px;font-family:'Courier New',monospace;letter-spacing:0.05em;`,
      'white-space:nowrap;text-shadow:0 0 4px currentColor;',
    ].join('');
    row.textContent = `${abbr} ${bar} ${repStr}`;
    container.appendChild(row);
  }

  return container;
}

// ── Main export ───────────────────────────────────────────────────────────────

export async function showMapGenOverlay(biome: string): Promise<void> {
  // ── Build overlay structure ──────────────────────────────────────────────
  const overlay = document.createElement('div');
  overlay.id = 'mapgen-overlay';
  overlay.style.cssText = [
    'position:fixed;inset:0;z-index:9500;',
    `background:${PAL.bg};`,
    'display:flex;flex-direction:row;',
    'opacity:0;transition:opacity 0.55s;',
    `font-family:'Courier New',monospace;`,
  ].join('');
  document.body.appendChild(overlay);

  // Left panel — CRT terminal
  const leftPanel = document.createElement('div');
  leftPanel.style.cssText = [
    'width:clamp(220px,36%,380px);padding:clamp(24px,4vw,48px) clamp(16px,3vw,36px);',
    'display:flex;flex-direction:column;justify-content:center;',
    `border-right:1px solid rgba(51,255,102,0.18);overflow:hidden;`,
  ].join('');
  overlay.appendChild(leftPanel);

  // Biome name title header — fades in after 200ms
  const biomeTitleEl = document.createElement('div');
  biomeTitleEl.id = 'map-biome-title';
  const biomeName = BIOME_DISPLAY_NAMES[biome] ?? biome.toUpperCase().replace(/_/g, ' ');
  biomeTitleEl.textContent = `NEMETON.SYS > ${biomeName}`;
  biomeTitleEl.style.cssText = [
    `color:#33ff66;font-family:'Courier New',monospace;font-size:11px;`,
    `letter-spacing:0.25em;text-transform:uppercase;margin-bottom:8px;`,
    `opacity:0;transition:opacity 0.6s;`,
  ].join('');
  leftPanel.appendChild(biomeTitleEl);
  setTimeout(() => { biomeTitleEl.style.opacity = '1'; }, 200);

  // CRT system header
  const sigilEl = document.createElement('div');
  sigilEl.textContent = '> MERLIN_OS v2.4 :: RUN_INIT';
  sigilEl.style.cssText = [
    `color:${PAL.border};font-size:11px;letter-spacing:2px;`,
    `margin-bottom:6px;opacity:0.7;font-family:'Courier New',monospace;`,
  ].join('');
  leftPanel.appendChild(sigilEl);

  const subheaderEl = document.createElement('div');
  subheaderEl.textContent = `> BIOME_SCAN :: ${biome.toUpperCase()}`;
  subheaderEl.style.cssText = [
    `color:${PAL.border};font-size:10px;letter-spacing:1px;`,
    `margin-bottom:20px;opacity:0.55;font-family:'Courier New',monospace;`,
  ].join('');
  leftPanel.appendChild(subheaderEl);

  const titleEl = document.createElement('div');
  titleEl.style.cssText = [
    `color:${PAL.titleGold};font-size:clamp(13px,1.6vw,18px);`,
    `letter-spacing:0.08em;margin-bottom:8px;min-height:26px;font-weight:bold;line-height:1.4;`,
    `font-family:'Courier New',monospace;text-transform:uppercase;`,
    `text-shadow:0 0 8px rgba(51,255,102,0.4);`,
  ].join('');
  leftPanel.appendChild(titleEl);

  // LLM loading placeholder
  const thinkingEl = document.createElement('div');
  thinkingEl.textContent = '> QUERYING_GROQ_API...';
  thinkingEl.style.cssText = [
    `color:${PAL.border};font-size:11px;`,
    `margin-bottom:18px;opacity:0.8;transition:opacity 0.4s;`,
    `font-family:'Courier New',monospace;`,
  ].join('');
  leftPanel.appendChild(thinkingEl);

  // Inject blinking cursor keyframe once (guarded by id)
  if (!document.getElementById('map-think-style')) {
    const styleEl = document.createElement('style');
    styleEl.id = 'map-think-style';
    styleEl.textContent = '@keyframes celtos-cursor-blink{0%,100%{opacity:1}50%{opacity:0.4}}';
    document.head.appendChild(styleEl);
  }
  thinkingEl.style.animation = 'celtos-cursor-blink 0.8s step-end infinite';

  // Typewriter dots animation while LLM is queried
  const THINKING_FRAMES = [
    '> QUERYING_GROQ_API.  ',
    '> QUERYING_GROQ_API.. ',
    '> QUERYING_GROQ_API...',
    '> NEMETON.SYS > ready ',
  ] as const;
  let thinkingFrame = 0;
  const thinkingInterval = setInterval(() => {
    thinkingFrame = (thinkingFrame + 1) % THINKING_FRAMES.length;
    thinkingEl.textContent = THINKING_FRAMES[thinkingFrame] ?? THINKING_FRAMES[0];
  }, 400);

  const divider = document.createElement('div');
  divider.style.cssText = [
    `width:100%;height:1px;background:linear-gradient(90deg,${PAL.border},transparent);`,
    'margin-bottom:18px;opacity:0.4;',
  ].join('');
  leftPanel.appendChild(divider);

  const scenarioContainer = document.createElement('div');
  scenarioContainer.style.cssText = 'display:flex;flex-direction:column;gap:12px;flex:1;overflow:hidden;';
  leftPanel.appendChild(scenarioContainer);

  const hintEl = document.createElement('button');
  hintEl.textContent = '[ COMMENCER L\'AVENTURE ]';
  hintEl.style.cssText = [
    `color:${PAL.accent};font-size:clamp(11px,1.2vw,13px);`,
    `margin-top:auto;padding:10px 14px;opacity:0;transition:opacity 0.5s,box-shadow 0.2s,background 0.2s;`,
    `letter-spacing:0.14em;font-family:'Courier New',monospace;`,
    `border:1px solid ${PAL.border};background:rgba(51,255,102,0.04);`,
    `cursor:pointer;text-transform:uppercase;outline:none;`,
    `text-shadow:0 0 8px rgba(51,255,102,0.5);`,
  ].join('');
  hintEl.addEventListener('mouseenter', () => {
    sfx('hover');
    hintEl.style.background = 'rgba(51,255,102,0.10)';
    hintEl.style.boxShadow = '0 0 14px rgba(51,255,102,0.22)';
  });
  hintEl.addEventListener('mouseleave', () => {
    hintEl.style.background = 'rgba(51,255,102,0.04)';
    hintEl.style.boxShadow = 'none';
  });
  leftPanel.appendChild(hintEl);

  // Right panel — canvas map
  const rightPanel = document.createElement('div');
  rightPanel.style.cssText = 'flex:1;position:relative;overflow:hidden;min-width:0;';
  overlay.appendChild(rightPanel);

  const canvas = document.createElement('canvas');
  canvas.style.cssText = 'position:absolute;inset:0;width:100%;height:100%;display:block;';
  rightPanel.appendChild(canvas);

  // CRT vignette — dark corner bloom
  const vignette = document.createElement('div');
  vignette.style.cssText = [
    'position:absolute;inset:0;pointer-events:none;',
    'background:radial-gradient(ellipse at 50% 50%,transparent 42%,rgba(0,8,0,0.55) 100%);',
  ].join('');
  rightPanel.appendChild(vignette);

  // Faction reputation mini-bars (C252)
  const factionBars = buildFactionBars(store.getState().run.factions);
  rightPanel.appendChild(factionBars);

  // ── C158: Start LLM call IMMEDIATELY (parallel with fade-in) ─────────────
  const llm = getLLMAdapter();
  const scenarioPromise: Promise<RunScenario> = llm
    ? llm.generateRunScenario(biome)
        .then((r) => r ?? buildFallback(biome))
        .catch(() => buildFallback(biome))
    : Promise.resolve(buildFallback(biome));

  // ── Fade in ──────────────────────────────────────────────────────────────
  requestAnimationFrame(() => requestAnimationFrame(() => { overlay.style.opacity = '1'; }));
  await wait(600); // browser paints; LLM has 600ms head start

  // ── Size canvas NOW (DOM has been painted) ────────────────────────────────
  const resizeCanvas = (): void => {
    const w = rightPanel.clientWidth  || window.innerWidth  * 0.62;
    const h = rightPanel.clientHeight || window.innerHeight;
    canvas.width  = Math.max(w, 200);
    canvas.height = Math.max(h, 200);
  };
  resizeCanvas();
  window.addEventListener('resize', resizeCanvas);

  // ── Get scenario (LLM or fallback, max 5.5s total incl fade-in) ──────────
  const scenario = await Promise.race([
    scenarioPromise,
    new Promise<RunScenario>((res) => setTimeout(() => res(buildFallback(biome)), 4900)),
  ]);

  // Hide "thinking" placeholder — stop animation first
  clearInterval(thinkingInterval);
  thinkingEl.style.opacity = '0';

  const ctx = canvas.getContext('2d')!;

  // Generate CRT scanlines once at final canvas size
  const grain = createScanlineTexture(canvas.width, canvas.height);
  const stampGrain = (): void => {
    ctx.save();
    ctx.globalAlpha = 0.85;
    ctx.drawImage(grain, 0, 0);
    ctx.restore();
  };

  // Compass rose position (top-right margin)
  const roseX = canvas.width - 52;
  const roseY = 52;
  const roseSize = 22;

  // ── Cursor orb — glowing dot that travels the path as it's drawn ─────────
  const cursorOrb = document.createElement('div');
  cursorOrb.id = 'map-cursor-orb';
  cursorOrb.style.cssText = [
    'position:absolute',
    'width:10px',
    'height:10px',
    'border-radius:50%',
    'background:rgba(51,255,102,0.9)',
    'box-shadow:0 0 8px rgba(51,255,102,0.8), 0 0 16px rgba(51,255,102,0.4)',
    'transform:translate(-50%,-50%)',
    'pointer-events:none',
    'z-index:10',
    'transition:opacity 0.3s',
  ].join(';');
  rightPanel.appendChild(cursorOrb);

  const mapData = buildMapData(canvas.width, canvas.height, scenario.events, biome);

  // ── Phase 1: draw terrain patches ────────────────────────────────────────
  const TERRAIN_DURATION = 1800; // ms
  const terrainStart = performance.now();

  await new Promise<void>((resolve) => {
    const tick = (): void => {
      const elapsed = performance.now() - terrainStart;
      const overallP = Math.min(elapsed / TERRAIN_DURATION, 1);

      ctx.clearRect(0, 0, canvas.width, canvas.height);

      // Background — CRT dark
      ctx.fillStyle = PAL.bg;
      ctx.fillRect(0, 0, canvas.width, canvas.height);

      // Terrain patches — staggered
      const numPatches = mapData.terrainPatches.length;
      for (let i = 0; i < numPatches; i++) {
        const patchStart = (i / numPatches) * 0.6;
        const patchP = Math.max(0, (overallP - patchStart) / 0.4);
        drawPatchAt(ctx, mapData.terrainPatches[i]!, patchP);
      }

      drawBiomeDecorations(ctx, canvas.width, canvas.height, biome);
      stampGrain();
      drawCelticBorder(ctx, canvas.width, canvas.height);

      if (overallP >= 1) {
        sfx('beep');
        resolve();
      } else {
        requestAnimationFrame(tick);
      }
    };
    tick();
  });

  // ── Phase 2 + 3: animated path drawing then zone drop-in ─────────────────
  //
  // startMapAnimation() drives both phases via a single RAF loop (animState).
  // Phase 'path'  : drawProgress 0→1 over 1500ms (dt/1500 per frame)
  // Phase 'zones' : each zone drops in with ease-out-bounce, staggered 80ms
  //
  const PATH_ANIM_MS = 1500;
  const ZONE_DROP_MS = 300;
  const ZONE_STAGGER = 80;
  const ZONE_DROP_PX = 30;

  const animState: AnimState = {
    progress: 0,
    phase: 'path',
    zoneTimers: new Array<number>(mapData.events.length).fill(-1),
    rafId: 0,
    lastTs: 0,
  };

  /** Y offset for a zone (0 = settled, ZONE_DROP_PX = start) using bounce */
  const zoneYOffset = (i: number): number => {
    const elapsed = animState.zoneTimers[i]!;
    if (elapsed < 0) return ZONE_DROP_PX;           // not yet started → hidden above
    const t = Math.min(elapsed / ZONE_DROP_MS, 1);
    return ZONE_DROP_PX * (1 - easeOutBounce(t));   // 30 → 0
  };

  /** Alpha for a zone (0 before drop-in starts, 1 when settled) */
  const zoneAlpha = (i: number): number => {
    const elapsed = animState.zoneTimers[i]!;
    if (elapsed < 0) return 0;
    return Math.min(elapsed / ZONE_DROP_MS, 1);
  };

  // Shared full-canvas redraw used by both phases
  const redrawCanvas = (): void => {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = PAL.bg;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    for (const patch of mapData.terrainPatches) drawPatchAt(ctx, patch, 1);
    drawBiomeDecorations(ctx, canvas.width, canvas.height, biome);
    drawPathAt(ctx, mapData.pathPoints, animState.progress);
    stampGrain();
    const start = mapData.pathPoints[0]!;
    if (animState.progress > 0.05) drawHeroMarker(ctx, start.x, start.y);
    if (animState.progress > 0.5)  drawCompassRose(ctx, roseX, roseY, roseSize);

    // Zone icons — only drawn in 'zones' or 'done' phase
    if (animState.phase !== 'path') {
      for (let i = 0; i < mapData.events.length; i++) {
        const ev = mapData.events[i]!;
        const pt = getPathPoint(mapData.pathPoints, ev.position);
        const alpha = zoneAlpha(i);
        if (alpha <= 0) continue;
        // translate vertically for bounce drop-in
        ctx.save();
        ctx.translate(0, zoneYOffset(i));
        drawEventNode(ctx, pt.x, pt.y, ev, alpha);
        ctx.restore();
      }
    }

    drawCelticBorder(ctx, canvas.width, canvas.height);
  };

  // Resolve promises to sequence phases
  let pathResolve!: () => void;
  let zonesResolve!: () => void;
  const pathDone = new Promise<void>((res) => { pathResolve = res; });
  const zonesDone = new Promise<void>((res) => { zonesResolve = res; });

  const startMapAnimation = (): void => {
    if (animState.rafId !== 0) return; // idempotent guard

    const tick = (ts: number): void => {
      const dt = animState.lastTs === 0 ? 0 : ts - animState.lastTs;
      animState.lastTs = ts;

      if (animState.phase === 'path') {
        animState.progress = Math.min(animState.progress + dt / PATH_ANIM_MS, 1);
        redrawCanvas();

        // Position cursor orb at the leading edge of the drawn path
        const orbPt = getPathPoint(mapData.pathPoints, animState.progress);
        cursorOrb.style.left = orbPt.x + 'px';
        cursorOrb.style.top  = orbPt.y + 'px';

        if (animState.progress >= 1) {
          animState.phase = 'zones';
          // Fade out orb then remove it
          cursorOrb.style.opacity = '0';
          setTimeout(() => { cursorOrb.parentNode?.removeChild(cursorOrb); }, 350);
          pathResolve();
        }
      } else if (animState.phase === 'zones') {
        redrawCanvas();

        // Advance each zone timer that has started
        let allDone = true;
        for (let i = 0; i < animState.zoneTimers.length; i++) {
          const t = animState.zoneTimers[i]!;
          if (t < 0) { allDone = false; continue; }  // not yet triggered
          const next = t + dt;
          animState.zoneTimers[i] = next;
          if (next < ZONE_DROP_MS) allDone = false;
        }

        if (allDone && animState.zoneTimers.every((t) => t >= 0)) {
          animState.phase = 'done';
          zonesResolve();
          return; // stop RAF
        }
      } else {
        // 'done' — stop loop
        return;
      }

      animState.rafId = requestAnimationFrame(tick);
    };

    animState.rafId = requestAnimationFrame(tick);
  };

  // ── Start animation (path phase) ──────────────────────────────────────────
  // Start typing title concurrently with path drawing
  typewrite(titleEl, scenario.titre.toUpperCase(), 40);
  sfx('mapDraw');

  startMapAnimation();

  // Wait for path to fully draw before starting zone drop-ins
  await pathDone;
  sfx('beep');

  // ── Phase 3: scenario paragraphs + zone drop-in concurrently ─────────────
  const paragraphs = [...scenario.scenario];

  // Trigger zone drop-ins one by one, staggered, as paragraphs typewrite
  let rafActive = true; // kept for Phase 5 cancel compat

  // Kick off zone timers progressively (staggered by 80ms regardless of text)
  const triggerZonesSequentially = async (): Promise<void> => {
    for (let i = 0; i < animState.zoneTimers.length; i++) {
      animState.zoneTimers[i] = 0; // start this zone's drop-in
      await wait(ZONE_STAGGER);
    }
  };

  // Run paragraphs and zone triggers concurrently
  await Promise.all([
    // Left panel: typewrite paragraphs
    (async (): Promise<void> => {
      for (let i = 0; i < paragraphs.length; i++) {
        const para = document.createElement('div');
        para.style.cssText = [
          `color:${PAL.ink};font-size:clamp(11px,1.3vw,13px);line-height:1.65;`,
          `font-family:'Courier New',monospace;`,
          `border-left:2px solid ${PAL.border};padding-left:8px;`,
          'opacity:0;transition:opacity 0.3s;',
        ].join('');
        scenarioContainer.appendChild(para);
        requestAnimationFrame(() => requestAnimationFrame(() => { para.style.opacity = '1'; }));
        await typewrite(para, paragraphs[i]!, 20);
        await wait(200);
      }
    })(),
    // Right panel: trigger zone drop-ins
    triggerZonesSequentially(),
  ]);

  // Wait for all zone animations to complete
  await zonesDone;
  await wait(400);

  // ── Inject map-dive CSS keyframe (guarded) ───────────────────────────────
  if (!document.getElementById('map-dive-style')) {
    const diveStyle = document.createElement('style');
    diveStyle.id = 'map-dive-style';
    diveStyle.textContent = `
      @keyframes map-dive {
        0%   { transform: scale(1) translateY(0);     opacity: 1; }
        40%  { transform: scale(1.8) translateY(-5%); opacity: 0.9; }
        100% { transform: scale(4.5) translateY(-15%); opacity: 0; }
      }
    `;
    document.head.appendChild(diveStyle);
  }

  // ── Phase 4: show "Entrer" hint + wait for click ──────────────────────────
  hintEl.style.opacity = '1';

  await new Promise<void>((resolve) => {
    let resolved = false;
    const done = (): void => {
      if (resolved) return;
      resolved = true;
      hintEl.removeEventListener('click', onBtnClick);
      overlay.removeEventListener('click', onOverlayClick);
      document.removeEventListener('keydown', onKey);
      clearTimeout(autoTimer);
      resolve();
    };
    const triggerDiveAndDone = (stopProp?: MouseEvent): void => {
      if (resolved) return;
      // Prevent double-click
      hintEl.disabled = true;
      hintEl.style.opacity = '0.5';
      if (stopProp) stopProp.stopPropagation();
      // Fire SFX immediately
      sfx('mapZoom');
      // Apply dive animation to the whole overlay
      overlay.style.animation = 'map-dive 700ms cubic-bezier(0.4,0,1,1) forwards';
      // Delay actual resolution by 650ms so animation is visible
      setTimeout(done, 650);
    };
    const onBtnClick = (e: MouseEvent): void => { sfx('click'); triggerDiveAndDone(e); };
    const onOverlayClick = (): void => { triggerDiveAndDone(); };
    const onKey = (e: KeyboardEvent): void => {
      if (e.code === 'Space' || e.code === 'Enter') { e.preventDefault(); triggerDiveAndDone(); }
    };
    hintEl.addEventListener('click', onBtnClick);
    overlay.addEventListener('click', onOverlayClick);
    document.addEventListener('keydown', onKey);

    // Auto-continue after 10s if no interaction
    const autoTimer = setTimeout(done, 10000);
  });

  // ── Phase 5: zoom-into-map transition ─────────────────────────────────────
  // Cancel any still-running animation RAF to prevent leaks
  rafActive = false;
  if (animState.rafId !== 0) {
    cancelAnimationFrame(animState.rafId);
    animState.rafId = 0;
  }
  // sfx('mapZoom') already fired at button-click time (dive cinematic)

  const entryPt = mapData.pathPoints[0]!;
  const scaleTarget = 8;
  const cw = canvas.width;
  const ch = canvas.height;
  const offsetX = cw / 2 - entryPt.x;
  const offsetY = ch / 2 - entryPt.y;

  // Zoom canvas via CSS transform — N64 dive-in
  canvas.style.transition = 'transform 0.9s cubic-bezier(0.2,0,0.8,1)';
  canvas.style.transformOrigin = `${entryPt.x}px ${entryPt.y}px`;
  canvas.style.transform = `scale(${scaleTarget}) translate(${offsetX / scaleTarget}px, ${offsetY / scaleTarget}px)`;

  // Fade overlay to black simultaneously
  overlay.style.transition = 'opacity 0.8s ease 0.15s';
  overlay.style.opacity = '0';

  await wait(950);

  // ── Cleanup ───────────────────────────────────────────────────────────────
  window.removeEventListener('resize', resizeCanvas);
  document.getElementById('map-dive-style')?.remove();
  overlay.remove();
}
