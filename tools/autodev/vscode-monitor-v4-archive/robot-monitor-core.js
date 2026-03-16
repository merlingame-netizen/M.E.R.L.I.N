// robot-monitor-core.js — Pixel Art Robot Monitor Engine v2
// Multi-project themes, Animal Crossing clustering, task panel
(function () {
  'use strict';

  // ── THEMES ──
  const THEMES = {
    merlin: {
      id: 'merlin',
      headerTitle: 'MERLIN MONITOR',
      spriteSet: 'hat',
      palette: {
        bg: '#050a05', panel: '#080e08', grid: '#0a140a',
        green: '#00ff41', greenDim: '#00aa2a', amber: '#ffb300',
        cyan: '#00e5ff', red: '#ff3333', gray: '#6d7b6d',
        text: '#b0c8b0', border: '#1a2a1a', white: '#e0ffe0', smoke: '#3a4a3a',
      },
      domainColors: {
        'gameplay': '#ffb300', 'ui-ux': '#00e5ff', 'llm-lora': '#00ff41',
        'world-structure': '#8B6914', 'visual-polish': '#aa44ff',
        'game-director': '#e0ffe0', 'ui-components': '#44aaff',
        'scene-scripts': '#ff8844', 'autoloads-visual': '#44ff88',
        'swarm:codex': '#4488ff', 'swarm:claude': '#00ff41',
      },
    },
    data: {
      id: 'data',
      headerTitle: 'ROBOT MONITOR',
      spriteSet: 'robot',
      palette: {
        bg: '#0a0500', panel: '#0e0800', grid: '#140a00',
        green: '#FF7900', greenDim: '#cc6100', amber: '#ffb300',
        cyan: '#00e5ff', red: '#cd3c14', gray: '#7b6d5a',
        text: '#c8b8a0', border: '#2a1a0a', white: '#ffe0c0', smoke: '#4a3a2a',
      },
      domainColors: {
        'bigquery': '#FF7900', 'hive': '#cc6100', 'qlik': '#00e5ff',
        'powerbi': '#ffb300', 'sql': '#44aaff', 'python': '#44ff88',
        'director': '#ffe0c0',
      },
    },
    cours: {
      id: 'cours',
      headerTitle: 'STUDY MONITOR',
      spriteSet: 'book',
      palette: {
        bg: '#050508', panel: '#080810', grid: '#0a0a14',
        green: '#4488ff', greenDim: '#2266cc', amber: '#ffb300',
        cyan: '#66bbff', red: '#ff4444', gray: '#6d6d7b',
        text: '#b0b0c8', border: '#1a1a2a', white: '#e0e0ff', smoke: '#3a3a4a',
      },
      domainColors: {
        'slides': '#4488ff', 'content': '#66bbff', 'exercises': '#ffb300',
        'review': '#44ff88', 'design': '#aa44ff', 'director': '#e0e0ff',
      },
    },
  };

  let activeTheme = THEMES.merlin;
  function P() { return activeTheme.palette; }

  function setTheme(id) {
    if (THEMES[id]) activeTheme = THEMES[id];
  }

  function domainColor(domain) {
    return activeTheme.domainColors[domain] || P().greenDim;
  }

  // ── PIXEL FONT (3x5 bitmap) ──
  const FONT = {
    'A':[7,5,7,5,5],'B':[6,5,6,5,6],'C':[7,4,4,4,7],'D':[6,5,5,5,6],
    'E':[7,4,6,4,7],'F':[7,4,6,4,4],'G':[7,4,5,5,7],'H':[5,5,7,5,5],
    'I':[7,2,2,2,7],'J':[3,1,1,5,7],'K':[5,5,6,5,5],'L':[4,4,4,4,7],
    'M':[5,7,7,5,5],'N':[5,7,7,7,5],'O':[7,5,5,5,7],'P':[7,5,7,4,4],
    'Q':[7,5,5,7,1],'R':[7,5,7,6,5],'S':[7,4,7,1,7],'T':[7,2,2,2,2],
    'U':[5,5,5,5,7],'V':[5,5,5,5,2],'W':[5,5,7,7,5],'X':[5,5,2,5,5],
    'Y':[5,5,2,2,2],'Z':[7,1,2,4,7],
    '0':[7,5,5,5,7],'1':[2,6,2,2,7],'2':[7,1,7,4,7],'3':[7,1,7,1,7],
    '4':[5,5,7,1,1],'5':[7,4,7,1,7],'6':[7,4,7,5,7],'7':[7,1,1,1,1],
    '8':[7,5,7,5,7],'9':[7,5,7,1,7],
    '.':[0,0,0,0,2],':':[0,2,0,2,0],'-':[0,0,7,0,0],'_':[0,0,0,0,7],
    '/':[1,1,2,4,4],'%':[5,1,2,4,5],' ':[0,0,0,0,0],'!':[2,2,2,0,2],
    '?':[7,1,2,0,2],'+':[0,2,7,2,0],'>':[4,2,1,2,4],
  };

  function drawText(ctx, text, x, y, color, scale) {
    scale = scale || 1;
    ctx.fillStyle = color || P().text;
    const str = String(text).toUpperCase();
    let cx = x;
    for (let i = 0; i < str.length; i++) {
      const ch = FONT[str[i]];
      if (ch) {
        for (let r = 0; r < 5; r++) {
          for (let c = 0; c < 3; c++) {
            if (ch[r] & (1 << (2 - c))) {
              ctx.fillRect(cx + c * scale, y + r * scale, scale, scale);
            }
          }
        }
      }
      cx += 4 * scale;
    }
    return cx - x;
  }

  function textWidth(text, scale) {
    return String(text).length * 4 * (scale || 1) - (scale || 1);
  }

  // ── SPRITE INDICES ──
  const _ = 0, O = 1, D = 2, S = 3, G = 4, A = 5, M = 6;

  // ── SPRITE SETS ──
  // Hat (M.E.R.L.I.N.) — 12x14 floating wizard hat
  const HAT_IDLE = [
    [_,_,_,_,_,S,S,_,_,_,_,_],  // star tip
    [_,_,_,_,_,O,O,_,_,_,_,_],
    [_,_,_,_,O,A,A,O,_,_,_,_],
    [_,_,_,O,A,A,A,A,O,_,_,_],
    [_,_,O,A,A,A,A,A,A,O,_,_],
    [_,O,A,A,A,A,A,A,A,A,O,_],
    [O,A,A,A,A,A,A,A,A,A,A,O],
    [O,D,D,D,D,D,D,D,D,D,D,O],  // brim
    [_,O,O,O,O,O,O,O,O,O,O,_],
    [_,_,_,_,_,_,_,_,_,_,_,_],
    [_,_,_,_,_,_,_,_,_,_,_,_],
    [_,_,_,_,_,_,_,_,_,_,_,_],
    [_,_,_,_,_,_,_,_,_,_,_,_],
    [_,_,_,_,_,_,_,_,_,_,_,_],
  ];

  const HAT_WORKING = [
    [_,_,_,_,_,S,S,_,_,_,_,_],
    [_,_,S,_,_,O,O,_,_,S,_,_],  // sparkles
    [_,_,_,_,O,A,A,O,_,_,_,_],
    [_,_,_,O,A,A,A,A,O,_,_,_],
    [_,S,O,A,A,A,A,A,A,O,S,_],  // sparkles sides
    [_,O,A,A,A,A,A,A,A,A,O,_],
    [O,A,A,A,A,A,A,A,A,A,A,O],
    [O,D,D,D,D,D,D,D,D,D,D,O],
    [_,O,O,O,O,O,O,O,O,O,O,_],
    [_,_,_,_,_,_,_,_,_,_,_,_],
    [_,_,_,_,_,_,_,_,_,_,_,_],
    [_,_,_,_,_,_,_,_,_,_,_,_],
    [_,_,_,_,_,_,_,_,_,_,_,_],
    [_,_,_,_,_,_,_,_,_,_,_,_],
  ];

  const HAT_WORKING2 = [
    [_,_,_,_,_,S,S,_,_,_,_,_],
    [_,_,_,_,_,O,O,_,_,_,_,_],
    [_,S,_,_,O,A,A,O,_,_,S,_],  // sparkles shifted
    [_,_,_,O,A,A,A,A,O,_,_,_],
    [_,_,O,A,A,A,A,A,A,O,_,_],
    [S,O,A,A,A,A,A,A,A,A,O,S],  // sparkles low
    [O,A,A,A,A,A,A,A,A,A,A,O],
    [O,D,D,D,D,D,D,D,D,D,D,O],
    [_,O,O,O,O,O,O,O,O,O,O,_],
    [_,_,_,_,_,_,_,_,_,_,_,_],
    [_,_,_,_,_,_,_,_,_,_,_,_],
    [_,_,_,_,_,_,_,_,_,_,_,_],
    [_,_,_,_,_,_,_,_,_,_,_,_],
    [_,_,_,_,_,_,_,_,_,_,_,_],
  ];

  const HAT_CELEBRATE = [
    [_,_,S,_,_,S,S,_,_,S,_,_],  // lots of stars
    [_,S,_,_,_,O,O,_,_,_,S,_],
    [_,_,_,_,O,A,A,O,_,_,_,_],
    [_,_,_,O,A,A,A,A,O,_,_,_],
    [_,_,O,A,A,A,A,A,A,O,_,_],
    [_,O,A,A,A,A,A,A,A,A,O,_],
    [O,A,A,A,A,A,A,A,A,A,A,O],
    [O,D,D,D,D,D,D,D,D,D,D,O],
    [_,O,O,O,O,O,O,O,O,O,O,_],
    [_,_,_,_,_,_,_,_,_,_,_,_],
    [_,_,S,_,_,_,_,_,_,S,_,_],  // sparkles below
    [_,_,_,_,_,_,_,_,_,_,_,_],
    [_,_,_,_,S,_,_,S,_,_,_,_],
    [_,_,_,_,_,_,_,_,_,_,_,_],
  ];

  // Robot compact (Data/Orange) — 12x16
  const ROBOT_IDLE = [
    [_,_,_,_,_,S,S,_,_,_,_,_],  // antenna
    [_,_,_,O,O,O,O,O,O,_,_,_],  // head top
    [_,_,_,O,D,D,D,D,O,_,_,_],
    [_,_,_,O,S,D,D,S,O,_,_,_],  // eyes
    [_,_,_,O,D,G,G,D,O,_,_,_],  // mouth
    [_,_,_,_,O,M,M,O,_,_,_,_],  // neck
    [_,_,O,O,O,O,O,O,O,O,_,_],  // torso
    [_,_,O,D,A,A,A,A,D,O,_,_],  // badge
    [_,_,O,D,D,D,D,D,D,O,_,_],
    [_,_,O,O,O,O,O,O,O,O,_,_],
    [_,M,M,_,O,D,D,O,_,M,M,_],  // arms
    [_,M,M,_,O,D,D,O,_,M,M,_],
    [_,_,_,_,_,O,O,_,_,_,_,_],  // waist
    [_,_,_,_,O,M,M,O,_,_,_,_],  // legs
    [_,_,_,O,M,_,_,M,O,_,_,_],
    [_,_,_,O,O,_,_,O,O,_,_,_],  // feet
  ];

  const ROBOT_TYPING = JSON.parse(JSON.stringify(ROBOT_IDLE));
  ROBOT_TYPING[10] = [_,_,M,M,O,D,D,O,M,M,_,_];  // arms bent
  ROBOT_TYPING[11] = [_,_,_,M,O,D,D,O,M,_,_,_];

  const ROBOT_CELEBRATE = JSON.parse(JSON.stringify(ROBOT_IDLE));
  ROBOT_CELEBRATE[10] = [M,M,_,_,O,D,D,O,_,_,M,M];  // arms up
  ROBOT_CELEBRATE[11] = [M,_,_,_,O,D,D,O,_,_,_,M];

  // Book + Pencil (Cours) — 14x14
  const BOOK_CLOSED = [
    [_,_,_,_,_,_,_,_,_,_,_,_,_,_],
    [_,_,_,_,_,_,_,_,_,_,_,_,_,_],
    [_,_,O,O,O,O,O,O,O,_,_,_,_,_],
    [_,_,O,A,A,A,A,A,O,_,_,_,_,_],
    [_,_,O,A,A,A,A,A,O,_,_,_,_,_],
    [_,_,O,A,A,A,A,A,O,_,_,M,_,_],  // pencil resting
    [_,_,O,A,A,A,A,A,O,_,_,M,_,_],
    [_,_,O,A,A,A,A,A,O,_,_,M,_,_],
    [_,_,O,A,A,A,A,A,O,_,_,M,_,_],
    [_,_,O,D,D,D,D,D,O,_,_,S,_,_],  // pencil tip
    [_,_,O,O,O,O,O,O,O,_,_,_,_,_],
    [_,_,_,_,_,_,_,_,_,_,_,_,_,_],
    [_,_,_,_,_,_,_,_,_,_,_,_,_,_],
    [_,_,_,_,_,_,_,_,_,_,_,_,_,_],
  ];

  const BOOK_OPEN = [
    [_,_,_,_,_,_,_,_,_,_,_,_,_,_],
    [_,O,O,O,O,O,O,O,O,O,_,_,_,_],
    [_,O,D,D,D,O,D,D,D,O,_,_,_,_],  // spine
    [_,O,D,G,G,O,G,G,D,O,_,_,M,_],  // text lines + pencil writing
    [_,O,D,D,D,O,D,D,D,O,_,_,M,_],
    [_,O,D,G,G,O,G,G,D,O,_,_,M,_],  // text
    [_,O,D,D,D,O,D,D,D,O,_,_,M,_],
    [_,O,D,G,G,O,G,G,D,O,_,_,S,_],  // pencil tip writes
    [_,O,D,D,D,O,D,D,D,O,_,_,_,_],
    [_,O,O,O,O,O,O,O,O,O,_,_,_,_],
    [_,_,_,_,_,_,_,_,_,_,_,_,_,_],
    [_,_,_,_,_,_,_,_,_,_,_,_,_,_],
    [_,_,_,_,_,_,_,_,_,_,_,_,_,_],
    [_,_,_,_,_,_,_,_,_,_,_,_,_,_],
  ];

  const BOOK_OPEN2 = [
    [_,_,_,_,_,_,_,_,_,_,_,_,_,_],
    [_,O,O,O,O,O,O,O,O,O,_,_,_,_],
    [_,O,D,D,D,O,D,D,D,O,_,_,_,_],
    [_,O,D,G,G,O,G,G,D,O,_,M,_,_],  // pencil shifted
    [_,O,D,D,D,O,D,D,D,O,_,M,_,_],
    [_,O,D,G,G,O,G,G,D,O,_,M,_,_],
    [_,O,D,D,D,O,D,D,D,O,_,S,_,_],  // tip lower
    [_,O,D,G,G,O,G,G,D,O,_,_,_,_],
    [_,O,D,D,D,O,D,D,D,O,_,_,_,_],
    [_,O,O,O,O,O,O,O,O,O,_,_,_,_],
    [_,_,_,_,_,_,_,_,_,_,_,_,_,_],
    [_,_,_,_,_,_,_,_,_,_,_,_,_,_],
    [_,_,_,_,_,_,_,_,_,_,_,_,_,_],
    [_,_,_,_,_,_,_,_,_,_,_,_,_,_],
  ];

  const BOOK_DONE = [
    [_,_,_,_,_,_,_,_,_,_,_,_,_,_],
    [_,O,O,O,O,O,O,O,O,O,_,_,_,_],
    [_,O,D,D,D,O,D,D,D,O,_,_,_,_],
    [_,O,D,D,D,O,D,S,D,O,_,_,_,_],  // checkmark
    [_,O,D,D,D,O,S,D,D,O,_,_,_,_],
    [_,O,D,S,D,O,D,D,D,O,_,_,_,_],
    [_,O,D,D,S,O,D,D,D,O,_,_,_,_],
    [_,O,D,D,D,O,D,D,D,O,_,_,_,_],
    [_,O,D,D,D,O,D,D,D,O,_,_,_,_],
    [_,O,O,O,O,O,O,O,O,O,_,_,_,_],
    [_,_,_,_,_,_,_,_,_,_,_,_,_,_],
    [_,_,_,_,_,_,_,_,_,_,_,_,_,_],
    [_,_,_,_,_,_,_,_,_,_,_,_,_,_],
    [_,_,_,_,_,_,_,_,_,_,_,_,_,_],
  ];

  // Sprite set registry
  const SPRITE_SETS = {
    hat:   { size: { w: 12, h: 14 }, colorMap: { [O]: '#1a0a2a', [D]: '#2a1a3a', [S]: null, [G]: null, [A]: null, [M]: '#8B7500' } },
    robot: { size: { w: 12, h: 16 }, colorMap: { [O]: null, [D]: '#0d1a0d', [S]: null, [G]: null, [A]: null, [M]: null } },
    book:  { size: { w: 14, h: 14 }, colorMap: { [O]: null, [D]: '#1a1420', [S]: null, [G]: null, [A]: null, [M]: '#8B7500' } },
  };

  function getSpriteForState(setId, state, frame) {
    if (setId === 'hat') {
      if (state === STATE.WORKING) return (frame % 2 === 0) ? HAT_WORKING : HAT_WORKING2;
      if (state === STATE.DONE) return HAT_CELEBRATE;
      if (state === STATE.ERROR) return HAT_IDLE;
      return HAT_IDLE;
    }
    if (setId === 'book') {
      if (state === STATE.WORKING) return (frame % 2 === 0) ? BOOK_OPEN : BOOK_OPEN2;
      if (state === STATE.DONE) return BOOK_DONE;
      if (state === STATE.ERROR) return BOOK_CLOSED;
      return BOOK_CLOSED;
    }
    // robot (default)
    if (state === STATE.WORKING) return (frame % 2 === 0) ? ROBOT_TYPING : ROBOT_IDLE;
    if (state === STATE.DONE) return ROBOT_CELEBRATE;
    return ROBOT_IDLE;
  }

  function getSpriteSize() {
    return SPRITE_SETS[activeTheme.spriteSet]?.size || { w: 12, h: 16 };
  }

  // ── SPRITE RENDERER ──
  function drawSprite(ctx, spriteData, x, y, scale, accentColor, eyeColor) {
    const p = P();
    const setColors = SPRITE_SETS[activeTheme.spriteSet]?.colorMap || {};
    const colorMap = {
      [O]: setColors[O] || p.panel,
      [D]: setColors[D] || '#0d1a0d',
      [S]: eyeColor || p.green,
      [G]: p.greenDim,
      [A]: accentColor || p.greenDim,
      [M]: setColors[M] || p.gray,
    };

    for (let row = 0; row < spriteData.length; row++) {
      for (let col = 0; col < spriteData[row].length; col++) {
        const pixel = spriteData[row][col];
        if (pixel === 0) continue;
        const color = colorMap[pixel];
        if (!color) continue;
        ctx.fillStyle = color;
        ctx.fillRect(Math.floor(x + col * scale), Math.floor(y + row * scale), scale, scale);
      }
    }
  }

  // ── PARTICLES ──
  class Particle {
    constructor(x, y, vx, vy, color, life, noGravity) {
      this.x = x; this.y = y; this.vx = vx; this.vy = vy;
      this.color = color; this.life = life; this.maxLife = life;
      this.noGravity = noGravity || false;
    }
    update(dt) {
      this.x += this.vx * dt;
      this.y += this.vy * dt;
      if (!this.noGravity) this.vy += 30 * dt;
      this.life -= dt;
    }
    draw(ctx, scale) {
      if (this.life <= 0) return;
      ctx.globalAlpha = Math.max(0, this.life / this.maxLife);
      ctx.fillStyle = this.color;
      ctx.fillRect(Math.floor(this.x), Math.floor(this.y), scale * 2, scale * 2);
      ctx.globalAlpha = 1;
    }
  }

  class ParticleSystem {
    constructor() { this.particles = []; }
    emit(x, y, color, count, spreadX, spreadY, noGravity) {
      for (let i = 0; i < count; i++) {
        this.particles.push(new Particle(
          x + (Math.random() - 0.5) * spreadX, y,
          (Math.random() - 0.5) * 40, -(Math.random() * spreadY + 20),
          color, 0.8 + Math.random() * 0.6, noGravity
        ));
      }
    }
    update(dt) {
      for (const p of this.particles) p.update(dt);
      this.particles = this.particles.filter(p => p.life > 0);
    }
    draw(ctx, scale) {
      for (const p of this.particles) p.draw(ctx, scale);
    }
  }

  // ── FSM ──
  const STATE = { IDLE: 0, WORKING: 1, TALKING: 2, DONE: 3, ERROR: 4 };
  const STATE_NAMES = ['IDLE', 'WORKING', 'TALKING', 'DONE', 'ERROR'];

  // ── ROBOT (Worker Entity) ──
  class Robot {
    constructor(domain, index) {
      this.domain = domain;
      this.index = index;
      this.state = STATE.IDLE;
      this.frame = 0;
      this.frameTimer = 0;
      this.x = 0; this.y = 0;
      this.targetX = 0; this.targetY = 0;
      this.gridX = 0; this.gridY = 0;  // "home" position
      this.bobOffset = 0;
      this.bobTimer = Math.random() * Math.PI * 2;
      this.shakeOffset = 0;
      this.currentTask = '';
      this.progress = 0;
      this.filesModified = [];
      this.error = '';
      this.tool = 'claude'; // swarm tool badge (claude/codex/auto)
      this.accentColor = domainColor(domain);
      this.celebrationDone = false;
      this.particles = new ParticleSystem();
      this.blinkTimer = Math.random() * 3;
      this.isBlinking = false;
      this.clusterId = -1;  // -1 = no cluster
    }

    setState(newState) {
      if (this.state !== newState) {
        this.state = newState;
        this.frame = 0;
        this.frameTimer = 0;
        this.celebrationDone = false;
      }
    }

    updateFromStatus(statusData) {
      this.currentTask = statusData.current_task || '';
      this.progress = statusData.progress || 0;
      this.filesModified = statusData.files_modified || [];
      this.error = statusData.error || (statusData.blockers && statusData.blockers[0]) || '';
      if (statusData.tool) this.tool = statusData.tool;

      const s = String(statusData.status || 'pending').toLowerCase();
      if (s === 'in_progress' || s === 'running') this.setState(STATE.WORKING);
      else if (s === 'done' || s === 'merged' || s === 'completed') this.setState(STATE.DONE);
      else if (s === 'error' || s === 'failed') this.setState(STATE.ERROR);
      else this.setState(STATE.IDLE);
    }

    update(dt) {
      this.particles.update(dt);
      this.bobTimer += dt * 2;
      this.blinkTimer -= dt;

      // Smooth movement toward target
      this.x += (this.targetX - this.x) * Math.min(1, dt * 4);
      this.y += (this.targetY - this.y) * Math.min(1, dt * 4);

      const p = P();
      switch (this.state) {
        case STATE.IDLE:
          this.bobOffset = Math.sin(this.bobTimer) * 2;
          this.frameTimer += dt;
          if (this.frameTimer > 0.8) { this.frame = (this.frame + 1) % 2; this.frameTimer = 0; }
          if (this.blinkTimer <= 0) {
            this.isBlinking = !this.isBlinking;
            this.blinkTimer = this.isBlinking ? 0.15 : (2 + Math.random() * 3);
          }
          this.shakeOffset = 0;
          break;
        case STATE.WORKING:
          this.bobOffset = Math.sin(this.bobTimer * 3) * 0.5;
          this.frameTimer += dt;
          if (this.frameTimer > 0.2) { this.frame = (this.frame + 1) % 4; this.frameTimer = 0; }
          this.shakeOffset = 0;
          this.isBlinking = false;
          break;
        case STATE.TALKING:
          this.bobOffset = Math.sin(this.bobTimer * 1.5) * 1;
          this.frameTimer += dt;
          if (this.frameTimer > 0.4) { this.frame = (this.frame + 1) % 3; this.frameTimer = 0; }
          this.shakeOffset = 0;
          break;
        case STATE.DONE:
          this.bobOffset = Math.sin(this.bobTimer) * 1;
          this.frameTimer += dt;
          if (!this.celebrationDone) {
            if (this.frameTimer > 0.15) {
              this.frame++;
              this.frameTimer = 0;
              if (this.frame % 3 === 0) {
                this.particles.emit(this.x + 20, this.y - 5, p.green, 3, 30, 40);
              }
              if (this.frame >= 6) this.celebrationDone = true;
            }
          }
          this.shakeOffset = 0;
          break;
        case STATE.ERROR:
          this.bobOffset = 0;
          this.frameTimer += dt;
          if (this.frameTimer > 0.3) { this.frame = (this.frame + 1) % 3; this.frameTimer = 0; }
          this.shakeOffset = (Math.random() - 0.5) * 2;
          if (Math.random() < dt * 2) {
            this.particles.emit(this.x + 20, this.y - 2, p.smoke, 1, 10, 30);
          }
          break;
      }
    }

    draw(ctx, scale) {
      const px = Math.floor(this.x + this.shakeOffset);
      const py = Math.floor(this.y + this.bobOffset);
      const p = P();
      const sz = getSpriteSize();

      // Choose sprite
      const sprite = getSpriteForState(activeTheme.spriteSet, this.state, this.frame);
      let eyeColor = null;
      if (this.state === STATE.ERROR) eyeColor = p.red;
      else if (this.state === STATE.IDLE && this.isBlinking) eyeColor = p.panel;

      drawSprite(ctx, sprite, px, py, scale, this.accentColor, eyeColor);
      this.particles.draw(ctx, scale);

      // Domain label
      const ls = Math.max(1, Math.floor(scale / 3));
      const label = this.domain.toUpperCase();
      const tw = textWidth(label, ls);
      const spriteW = sz.w * scale;
      drawText(ctx, label, px + (spriteW - tw) / 2, py + sz.h * scale + 4, this.accentColor, ls);

      // State badge
      const stateName = STATE_NAMES[this.state];
      const sc = this.state === STATE.ERROR ? p.red : this.state === STATE.WORKING ? p.cyan : this.state === STATE.DONE ? p.green : p.gray;
      const stw = textWidth(stateName, ls);
      drawText(ctx, stateName, px + (spriteW - stw) / 2, py + sz.h * scale + 4 + 7 * ls, sc, ls);

      // Tool badge (swarm: CLAUDE / CODEX)
      if (this.tool && this.tool !== 'claude') {
        const toolLabel = this.tool.toUpperCase();
        const toolColor = this.tool === 'codex' ? '#4488ff' : p.green;
        const tlw = textWidth(toolLabel, ls);
        drawText(ctx, toolLabel, px + (spriteW - tlw) / 2, py + sz.h * scale + 4 + 14 * ls, toolColor, ls);
      }
    }
  }

  // ── CLUSTER (Animal Crossing collaboration) ──
  class Cluster {
    constructor(robots) {
      this.robots = robots;
      this.centerX = 0;
      this.centerY = 0;
      this.particles = new ParticleSystem();
      this.age = 0;
    }

    update(dt) {
      this.age += dt;
      this.particles.update(dt);

      // Compute centroid from grid positions
      let cx = 0, cy = 0;
      for (const r of this.robots) { cx += r.gridX; cy += r.gridY; }
      cx /= this.robots.length;
      cy /= this.robots.length;
      this.centerX = cx;
      this.centerY = cy;

      // Arrange robots in circle around centroid
      const n = this.robots.length;
      const radius = Math.max(15, n * 8);
      for (let i = 0; i < n; i++) {
        const angle = (i / n) * Math.PI * 2 - Math.PI / 2;
        this.robots[i].targetX = cx + Math.cos(angle) * radius;
        this.robots[i].targetY = cy + Math.sin(angle) * radius;
      }

      // Emit collaboration particles
      if (Math.random() < dt * 1.5) {
        const p = P();
        this.particles.emit(cx + 10, cy - 10, p.green, 2, 20, 15, true);
      }
    }

    draw(ctx, scale) {
      const p = P();
      // Glow circle
      const r = Math.max(25, this.robots.length * 12);
      ctx.globalAlpha = 0.08;
      ctx.fillStyle = p.green;
      ctx.beginPath();
      ctx.arc(Math.floor(this.centerX + 10), Math.floor(this.centerY + 10), r, 0, Math.PI * 2);
      ctx.fill();
      ctx.globalAlpha = 1;

      // Particles
      this.particles.draw(ctx, scale);

      // Shared label
      if (this.robots.length >= 2) {
        const ls = Math.max(1, Math.floor(scale / 3));
        const label = 'COLLAB';
        const tw = textWidth(label, ls);
        drawText(ctx, label, Math.floor(this.centerX + 10 - tw / 2), Math.floor(this.centerY - 20), p.cyan, ls);
      }
    }
  }

  // ── INFO BUBBLE ──
  function drawBubble(ctx, robot, scale) {
    if (!robot.currentTask && robot.state !== STATE.ERROR) return;
    const p = P();
    const sz = getSpriteSize();
    const spriteW = sz.w * scale;
    const text = robot.state === STATE.ERROR
      ? (robot.error || 'ERROR').substring(0, 22)
      : robot.currentTask.substring(0, 22);
    if (!text) return;

    const fs = Math.max(1, Math.floor(scale / 3));
    const tw = textWidth(text, fs);
    const pad = 3 * fs;
    const bw = tw + pad * 2;
    const bh = 5 * fs + pad * 2;
    const bx = Math.floor(robot.x + (spriteW - bw) / 2);
    const by = Math.floor(robot.y + robot.bobOffset - bh - 6);

    ctx.fillStyle = p.panel;
    ctx.fillRect(bx, by, bw, bh);
    const bc = robot.state === STATE.ERROR ? p.red : p.greenDim;
    ctx.fillStyle = bc;
    ctx.fillRect(bx, by, bw, 1);
    ctx.fillRect(bx, by + bh - 1, bw, 1);
    ctx.fillRect(bx, by, 1, bh);
    ctx.fillRect(bx + bw - 1, by, 1, bh);

    const tailX = Math.floor(robot.x + spriteW / 2);
    ctx.fillStyle = p.panel;
    ctx.fillRect(tailX - 1, by + bh, 3, 2);

    drawText(ctx, text, bx + pad, by + pad, robot.state === STATE.ERROR ? p.red : p.text, fs);

    if (robot.state === STATE.WORKING && robot.progress > 0) {
      const barY = by + bh + 3;
      ctx.fillStyle = p.border;
      ctx.fillRect(bx, barY, bw, Math.max(2, fs * 2));
      ctx.fillStyle = p.green;
      ctx.fillRect(bx, barY, Math.floor(bw * robot.progress / 100), Math.max(2, fs * 2));
    }
  }

  // ══════════════════════════════════════════════════════════════
  // ── VILLAGE MODE — Pixel Agents v4 ──
  // 5 modules: SpriteFactory, AgentEntity, ZoneLayout, InteractionManager, DataBridge
  // ══════════════════════════════════════════════════════════════

  // ── MODULE 1: SPRITE FACTORY ──

  // Base bodies (8x12 pixel grids)
  const BODY_HUMANOID = [
    [_,_,_,O,O,_,_,_],
    [_,_,O,S,S,O,_,_],
    [_,_,_,O,O,_,_,_],
    [_,_,O,A,A,O,_,_],
    [_,_,O,A,A,O,_,_],
    [_,_,O,A,A,O,_,_],
    [_,_,O,D,D,O,_,_],
    [_,_,_,O,O,_,_,_],
    [_,_,O,_,_,O,_,_],
    [_,_,O,_,_,O,_,_],
    [_,O,O,_,_,O,O,_],
    [_,_,_,_,_,_,_,_],
  ];

  const BODY_ORB = [
    [_,_,_,_,_,_,_,_],
    [_,_,_,_,_,_,_,_],
    [_,_,_,S,S,_,_,_],
    [_,_,A,A,A,A,_,_],
    [_,A,A,S,S,A,A,_],
    [_,A,A,A,A,A,A,_],
    [_,_,A,A,A,A,_,_],
    [_,_,_,D,D,_,_,_],
    [_,_,_,_,_,_,_,_],
    [_,_,_,_,_,_,_,_],
    [_,_,_,_,_,_,_,_],
    [_,_,_,_,_,_,_,_],
  ];

  const BODY_TOME = [
    [_,_,_,_,_,_,_,_],
    [_,_,_,_,_,_,_,_],
    [_,O,M,M,M,M,O,_],
    [_,O,M,A,A,M,O,_],
    [_,O,D,S,S,D,O,_],
    [_,O,D,D,D,D,O,_],
    [_,O,D,S,S,D,O,_],
    [_,O,D,D,D,D,O,_],
    [_,O,M,M,M,M,O,_],
    [_,_,M,O,O,M,_,_],
    [_,_,_,_,_,_,_,_],
    [_,_,_,_,_,_,_,_],
  ];

  const VILLAGE_ACCESSORIES = {
    orchestration: { pixels: [[S,A,S],[A,G,A],[_,A,_]], dx: 2, dy: -3 },
    core:          { pixels: [[_,_,M],[_,M,_],[M,M,_]], dx: 5, dy: 4 },
    llm:           { pixels: [[_,S,_],[S,G,S],[_,S,_]], dx: 2, dy: -3 },
    design:        { pixels: [[_,A,_],[A,_,A],[_,A,_]], dx: 2, dy: 3 },
    narrative:     { pixels: [[_,_,S],[_,S,_],[S,_,_]], dx: 5, dy: 1 },
    creative:      { pixels: [[G,_,S],[_,A,_],[S,_,G]], dx: 2, dy: 3 },
    'ui-ux':       { pixels: [[_,S,_],[S,A,S],[_,S,_]], dx: 2, dy: 3 },
    quality:       { pixels: [[_,A,_],[A,A,A],[_,A,_]], dx: 2, dy: 3 },
    ops:           { pixels: [[_,M,_],[M,_,M],[_,M,_]], dx: 2, dy: 3 },
    security:      { pixels: [[_,M,_],[M,S,M],[M,M,M]], dx: 2, dy: 3 },
    data:          { pixels: [[M,_,M],[M,_,M],[M,M,M]], dx: 5, dy: 4 },
    education:     { pixels: [[A,A,A,A],[_,O,O,_]], dx: 2, dy: -2 },
    tools:         { pixels: [[M,_],[M,M],[_,M]], dx: 5, dy: 5 },
    general:       { pixels: [[_,S,_],[S,S,S],[_,S,_]], dx: 2, dy: 0 },
  };

  const PROJECT_TINTS = {
    merlin: '#00ff41', data: '#FF7900', cours: '#4488ff', common: '#b0c8b0',
  };

  function nameHash(str) {
    var h = 0;
    for (var i = 0; i < str.length; i++) {
      h = ((h << 5) - h + str.charCodeAt(i)) | 0;
    }
    return Math.abs(h);
  }

  const CATEGORY_ACCESSORY_MAP = {
    'orchestration': 'orchestration', 'core': 'core', 'llm': 'llm',
    'llm-lora': 'llm', 'design': 'design', 'narrative': 'narrative',
    'creative': 'creative', 'ui-ux': 'ui-ux', 'quality': 'quality',
    'ops': 'ops', 'security': 'security', 'data': 'data',
    'education': 'education', 'tools': 'tools', 'general': 'general',
  };

  function cloneGrid(grid) {
    var out = [];
    for (var r = 0; r < grid.length; r++) {
      out[r] = [];
      for (var c = 0; c < grid[r].length; c++) {
        out[r][c] = grid[r][c];
      }
    }
    return out;
  }

  function applyAccessory(grid, accessory, flipH, offsetVariation) {
    if (!accessory) return;
    var px = accessory.pixels;
    var dx = accessory.dx + (offsetVariation || 0);
    var dy = accessory.dy;
    var accW = px[0].length;
    for (var r = 0; r < px.length; r++) {
      var gy = dy + r;
      if (gy < 0 || gy >= grid.length) continue;
      for (var c = 0; c < accW; c++) {
        var val = flipH ? px[r][accW - 1 - c] : px[r][c];
        if (val === _) continue;
        var gx = dx + c;
        if (gx < 0 || gx >= grid[0].length) continue;
        grid[gy][gx] = val;
      }
    }
  }

  const HUMANOID_EYE_POS = [{ row: 1, col: 3 }, { row: 1, col: 4 }];
  const ORB_GLOW_POS = [{ row: 2, col: 3 }, { row: 2, col: 4 }, { row: 4, col: 3 }, { row: 4, col: 4 }];

  function makeBlinkFrame(grid, baseType) {
    var blinked = cloneGrid(grid);
    if (baseType === 'humanoid') {
      for (var i = 0; i < HUMANOID_EYE_POS.length; i++) {
        var ep = HUMANOID_EYE_POS[i];
        if (ep.row < blinked.length && ep.col < blinked[ep.row].length) blinked[ep.row][ep.col] = _;
      }
    } else if (baseType === 'orb') {
      for (var i2 = 0; i2 < ORB_GLOW_POS.length; i2++) {
        var gp = ORB_GLOW_POS[i2];
        if (gp.row < blinked.length && gp.col < blinked[gp.row].length) {
          if (blinked[gp.row][gp.col] === S) blinked[gp.row][gp.col] = D;
        }
      }
    } else {
      for (var r = 4; r <= 6; r++) {
        for (var c = 0; c < blinked[r].length; c++) {
          if (blinked[r][c] === S) blinked[r][c] = D;
        }
      }
    }
    return blinked;
  }

  function makeWalkFrame(grid, baseType, direction) {
    var walked = cloneGrid(grid);
    if (baseType === 'humanoid') {
      if (direction < 0) {
        walked[8] = [_,O,_,_,_,_,O,_];
        walked[9] = [O,_,_,_,_,_,_,O];
        walked[10] = [O,O,_,_,_,_,O,O];
      } else {
        walked[8] = [_,_,_,O,O,_,_,_];
        walked[9] = [_,O,_,_,_,_,O,_];
        walked[10] = [O,O,_,_,_,_,O,O];
      }
    } else if (baseType === 'orb') {
      for (var r = 2; r <= 7; r++) {
        var newRow = [_,_,_,_,_,_,_,_];
        for (var c = 0; c < walked[r].length; c++) {
          var nc = c + direction;
          if (nc >= 0 && nc < 8) newRow[nc] = walked[r][c];
        }
        walked[r] = newRow;
      }
    } else {
      if (direction < 0) {
        walked[2] = [O,M,M,M,M,O,_,_];
        walked[9] = [_,_,_,M,O,O,M,_];
      } else {
        walked[2] = [_,_,O,M,M,M,M,O];
        walked[9] = [_,M,O,O,M,_,_,_];
      }
    }
    return walked;
  }

  function makeWorkFrame(grid, accessory, highlight) {
    if (!highlight || !accessory) return cloneGrid(grid);
    var worked = cloneGrid(grid);
    var px = accessory.pixels;
    var dx = accessory.dx;
    var dy = accessory.dy;
    for (var r = 0; r < px.length; r++) {
      var gy = dy + r;
      if (gy < 0 || gy >= worked.length) continue;
      for (var c = 0; c < px[r].length; c++) {
        var gx = dx + c;
        if (gx < 0 || gx >= worked[0].length) continue;
        if (worked[gy][gx] === S) worked[gy][gx] = G;
        if (worked[gy][gx] === A) worked[gy][gx] = S;
      }
    }
    return worked;
  }

  var _spriteCache = {};

  const SpriteFactory = {
    generate: function(category, project, name) {
      var cacheKey = (category || 'general') + '-' + (project || 'common') + '-' + (name || 'unknown');
      if (_spriteCache[cacheKey]) return _spriteCache[cacheKey];

      var baseType = 'humanoid';
      var nameLower = (name || '').toLowerCase();
      var catLower = (category || '').toLowerCase();

      if (nameLower.indexOf('superpowers') >= 0 || catLower === 'skill' || catLower === 'skills') {
        baseType = 'orb';
      } else if (catLower.indexOf('doc') >= 0 || catLower === 'education' ||
                 catLower.indexOf('writer') >= 0 || catLower.indexOf('knowledge') >= 0) {
        baseType = 'tome';
      }

      var base;
      if (baseType === 'orb') base = cloneGrid(BODY_ORB);
      else if (baseType === 'tome') base = cloneGrid(BODY_TOME);
      else base = cloneGrid(BODY_HUMANOID);

      var accKey = CATEGORY_ACCESSORY_MAP[catLower] || 'general';
      var accessory = VILLAGE_ACCESSORIES[accKey] || VILLAGE_ACCESSORIES.general;

      var h = nameHash(name || 'agent');
      var flipH = (h % 2) === 1;
      var offsetVar = (h % 3) - 1;

      applyAccessory(base, accessory, flipH, offsetVar);

      var idle1 = cloneGrid(base);
      var idle2 = makeBlinkFrame(base, baseType);
      var walk1 = makeWalkFrame(base, baseType, -1);
      var walk2 = makeWalkFrame(base, baseType, 1);
      var work1 = makeWorkFrame(base, accessory, true);
      var work2 = cloneGrid(base);

      applyAccessory(walk1, accessory, flipH, offsetVar);
      applyAccessory(walk2, accessory, flipH, offsetVar);

      var result = {
        idle: [idle1, idle2],
        walk: [walk1, walk2],
        work: [work1, work2],
        size: { w: 8, h: 12 },
        baseType: baseType,
      };

      _spriteCache[cacheKey] = result;
      return result;
    },
    clearCache: function() { _spriteCache = {}; },
  };


  // ── MODULE 2: AGENT ENTITY ──

  STATE.WANDER = 5;
  STATE.SLEEP = 6;
  STATE_NAMES[5] = 'WANDER';
  STATE_NAMES[6] = 'SLEEP';

  function AgentEntity(agentData) {
    this.name = agentData.name || 'unknown';
    this.category = agentData.category || 'general';
    this.project = agentData.project || 'merlin';
    this.type = agentData.type || 'agent';
    this.score = agentData.score || 0;

    this.x = 0; this.y = 0;
    this.targetX = 0; this.targetY = 0;
    this.zoneX = 0; this.zoneY = 0;
    this.zone = null;

    this.wanderTarget = null;
    this.wanderTimer = Math.random() * 2;  // Start wandering quickly
    this.wanderSpeed = 30 + Math.random() * 20;  // 30-50 px/s — visible movement

    this.state = STATE.IDLE;  // Static in grid by default
    this.isActive = false;
    this.collaborationGroup = null;  // Set when agents work together
    this.currentTask = '';
    this.progress = 0;
    this.error = '';
    this.invocationCount = 0;

    this.frame = 0;
    this.frameTimer = 0;
    this.bobOffset = 0;
    this.bobPhase = Math.random() * Math.PI * 2;

    this.spriteData = SpriteFactory.generate(this.category, this.project, this.name);
    this.accentColor = PROJECT_TINTS[this.project] || PROJECT_TINTS.common;

    this.description = agentData.description || '';

    this.hovered = false;
    this.pinned = false;
    this._searchMatch = false;
    this.particles = new ParticleSystem();
  }

  AgentEntity.prototype._pickWanderTarget = function() {
    if (!this.zone) return;
    this.wanderTarget = {
      x: this.zone.x + Math.random() * Math.max(1, this.zone.w - 16),
      y: this.zone.y + Math.random() * Math.max(1, this.zone.h - 20),
    };
  };

  AgentEntity.prototype.update = function(dt) {
    this.particles.update(dt);
    this.frameTimer += dt;

    if (this.state === STATE.WORKING || this.state === STATE.TALKING) {
      // Active: fast bob, move toward workspace target
      this.bobPhase += dt * 3;
      this.bobOffset = Math.sin(this.bobPhase) * 0.5;
      if (this.frameTimer > 0.2) { this.frame = (this.frame + 1) % 2; this.frameTimer = 0; }
      this.x += (this.targetX - this.x) * Math.min(1, dt * 4);
      this.y += (this.targetY - this.y) * Math.min(1, dt * 4);
    } else if (this.state === STATE.DONE) {
      // Done: gentle bob, lerp back to zone
      this.bobPhase += dt;
      this.bobOffset = Math.sin(this.bobPhase) * 1;
      if (this.frameTimer > 0.6) { this.frame = (this.frame + 1) % 2; this.frameTimer = 0; }
      this.x += (this.zoneX - this.x) * Math.min(1, dt * 2);
      this.y += (this.zoneY - this.y) * Math.min(1, dt * 2);
    } else if (this.state === STATE.ERROR) {
      // Error: shake + stay in workspace
      this.bobPhase += dt * 2;
      this.bobOffset = (Math.random() - 0.5) * 2;
      if (this.frameTimer > 0.3) { this.frame = (this.frame + 1) % 2; this.frameTimer = 0; }
      this.x += (this.targetX - this.x) * Math.min(1, dt * 4);
      this.y += (this.targetY - this.y) * Math.min(1, dt * 4);
    } else if (this.state === STATE.WANDER) {
      // WANDER: walk randomly within zone — village alive
      this.bobPhase += dt * 1.5;
      this.bobOffset = Math.sin(this.bobPhase) * 1.5;
      if (this.frameTimer > 0.4) { this.frame = (this.frame + 1) % 2; this.frameTimer = 0; }

      this.wanderTimer -= dt;
      if (this.wanderTimer <= 0 || !this.wanderTarget) {
        this._pickWanderTarget();
        this.wanderTimer = 1.5 + Math.random() * 3;  // 1.5-4.5s — frequent direction changes
      }
      if (this.wanderTarget) {
        var wdx = this.wanderTarget.x - this.x;
        var wdy = this.wanderTarget.y - this.y;
        var wdist = Math.sqrt(wdx * wdx + wdy * wdy);
        if (wdist > 2) {
          var wspeed = this.wanderSpeed * dt;
          this.x += (wdx / wdist) * Math.min(wspeed, wdist);
          this.y += (wdy / wdist) * Math.min(wspeed, wdist);
        }
      }

      // Ambient particles — occasional sparkle
      this._ambientTimer = (this._ambientTimer || 0) - dt;
      if (this._ambientTimer <= 0) {
        this._ambientTimer = 8 + Math.random() * 7; // 8-15s
        this.particles.emit(this.x + 4, this.y, this.accentColor, 2);
      }

    } else {
      // IDLE / SLEEP: stay fixed at zone position, gentle breathing bob
      this.bobPhase += dt * 0.8;
      this.bobOffset = Math.sin(this.bobPhase) * 0.5;
      if (this.frameTimer > 1.0) { this.frame = (this.frame + 1) % 2; this.frameTimer = 0; }
      // Lerp to zone position (snap back if moved)
      this.x += (this.zoneX - this.x) * Math.min(1, dt * 3);
      this.y += (this.zoneY - this.y) * Math.min(1, dt * 3);
    }
  };

  AgentEntity.prototype.draw = function(ctx, scale) {
    var frames;
    if (this.state === STATE.WORKING || this.state === STATE.TALKING) frames = this.spriteData.work;
    else frames = this.spriteData.idle;

    var sprite = frames[this.frame % frames.length];
    var drawY = Math.floor(this.y + this.bobOffset);
    var drawX = Math.floor(this.x);

    if (this.state === STATE.SLEEP) ctx.globalAlpha = 0.4;

    if (this.invocationCount > 0) {
      var glowPad = 2 + Math.min(4, Math.floor(this.invocationCount / 10));
      var glowAlpha = Math.min(0.2, this.invocationCount / 100);
      // Pulse effect
      glowAlpha *= (0.7 + 0.3 * Math.sin(this.bobPhase * 2));
      // Warm shift for high-activity: accent → amber
      var glowColor = this.invocationCount > 50 ? '#ffaa00' : this.accentColor;
      ctx.fillStyle = glowColor;
      ctx.globalAlpha = glowAlpha;
      var gw = this.spriteData.size.w * scale + glowPad * 2;
      var gh = this.spriteData.size.h * scale + glowPad * 2;
      ctx.fillRect(drawX - glowPad, drawY - glowPad, gw, gh);
    }

    ctx.globalAlpha = (this.state === STATE.SLEEP) ? 0.4 : 1.0;
    drawSprite(ctx, sprite, drawX, drawY, scale, this.accentColor);
    ctx.globalAlpha = 1.0;

    this.particles.draw(ctx, scale);

    if (this._searchMatch) {
      ctx.strokeStyle = '#ffff00';
      ctx.lineWidth = 1;
      ctx.strokeRect(drawX - 2, drawY - 2, this.spriteData.size.w * scale + 4, this.spriteData.size.h * scale + 4);
    }

    if (this.hovered) {
      ctx.strokeStyle = this.accentColor;
      ctx.lineWidth = 1;
      ctx.strokeRect(drawX - 1, drawY - 1, this.spriteData.size.w * scale + 2, this.spriteData.size.h * scale + 2);
    }
  };

  AgentEntity.prototype.activate = function(workerData) {
    this.isActive = true;
    this.state = STATE.WORKING;
    this.currentTask = workerData.current_task || '';
    this.progress = workerData.progress || 0;
    this.error = workerData.error || '';
    var s = String(workerData.status || '').toLowerCase();
    if (s === 'error' || s === 'failed') this.state = STATE.ERROR;
    if (s === 'done' || s === 'completed') this.state = STATE.DONE;
  };

  AgentEntity.prototype.deactivate = function() {
    this.isActive = false;
    this.state = STATE.IDLE;  // Return to static grid position
    this.currentTask = '';
    this.progress = 0;
    this.error = '';
    this.collaborationGroup = null;
  };


  // ── MODULE 3: ZONE LAYOUT ──

  const ZoneLayout = {
    zones: {},
    workspace: null,
    scale: 2,

    _catOrder: [
      'orchestration', 'core', 'llm', 'design', 'narrative', 'creative',
      'ui-ux', 'quality', 'ops', 'security', 'data', 'education', 'tools', 'general'
    ],

    _catColors: {
      'orchestration': '#e0ffe0', 'core': '#00ff41', 'llm': '#44ff88',
      'design': '#ffb300', 'narrative': '#aa44ff', 'creative': '#ff8844',
      'ui-ux': '#00e5ff', 'quality': '#ff3333', 'ops': '#6d7b6d',
      'security': '#ff4444', 'data': '#FF7900', 'education': '#4488ff',
      'tools': '#66bbff', 'general': '#b0c8b0'
    },

    compute: function(entities, canvasW, canvasH) {
      var HEADER_H = 28;
      var COLS = 4;
      var PAD = 2;

      var totalEntities = entities.length;
      // Min scale 1.5 for clickability
      if (totalEntities <= 50) this.scale = 2;
      else this.scale = 1.5;

      var groups = {};
      var skillEntities = [];
      for (var i = 0; i < entities.length; i++) {
        var e = entities[i];
        if (e.type === 'skill') { skillEntities.push(e); continue; }
        var cat = e.category || 'general';
        if (!groups[cat]) groups[cat] = [];
        groups[cat].push(e);
      }

      var activeCats = [];
      for (var ci = 0; ci < this._catOrder.length; ci++) {
        var catName = this._catOrder[ci];
        if (groups[catName] && groups[catName].length > 0) activeCats.push(catName);
      }

      // Layout: agents top 60%, workspace middle 15%, skills bottom 25%
      var usableH = canvasH - HEADER_H;
      var hasSkills = skillEntities.length > 0;

      var agentAreaPct = hasSkills ? 0.60 : 0.80;
      var wsPct = 0.15;
      var skillsPct = hasSkills ? 0.25 : 0;

      var agentAreaH = Math.floor(usableH * agentAreaPct);
      var wsH = Math.floor(usableH * wsPct);
      var skillsH = hasSkills ? Math.max(60, usableH - agentAreaH - wsH) : 0;

      var agentAreaY = HEADER_H;
      var wsY = agentAreaY + agentAreaH;
      var skillsY = wsY + wsH;

      this.workspace = { x: 0, y: wsY, w: canvasW, h: wsH };

      // Agent category zones — grid layout in top area
      var totalCats = activeCats.length;
      var rows = Math.ceil(totalCats / COLS);
      if (rows < 1) rows = 1;
      var cellW = Math.floor(canvasW / COLS);
      var cellH = Math.floor(agentAreaH / Math.max(rows, 1));
      if (cellH < 60) cellH = 60;  // Min 60px for wander space

      this.zones = {};
      for (var gi = 0; gi < activeCats.length; gi++) {
        var cn = activeCats[gi];
        var row = Math.floor(gi / COLS);
        var col = gi % COLS;
        var zx = Math.floor(col * cellW) + PAD;
        var zy = Math.floor(agentAreaY + row * cellH) + PAD;
        var zw = cellW - PAD * 2;
        var zh = cellH - PAD * 2;
        if (zy + zh > wsY) zh = wsY - zy - PAD;
        if (zh < 30) zh = 30;

        this.zones[cn] = { x: zx, y: zy, w: zw, h: zh, label: cn, color: this._catColors[cn] || P().text, agents: groups[cn] || [] };
      }

      // Skills zone — FULL WIDTH band at bottom
      if (hasSkills) {
        this.zones['_skills'] = { x: PAD, y: skillsY + PAD, w: canvasW - PAD * 2, h: skillsH - PAD * 2, label: 'skills', color: '#66bbff', agents: skillEntities };
      }

      for (var zk in this.zones) {
        if (!this.zones.hasOwnProperty(zk)) continue;
        this._positionEntitiesInZone(this.zones[zk]);
      }
      return this.zones;
    },

    _positionEntitiesInZone: function(zone) {
      var agents = zone.agents;
      if (!agents || agents.length === 0) return;
      var LABEL_H = 8;
      var innerX = zone.x + 2;
      var innerY = zone.y + LABEL_H + 2;
      var innerW = zone.w - 4;
      var innerH = zone.h - LABEL_H - 4;
      if (innerH < 10) innerH = 10;

      var cols = Math.ceil(Math.sqrt(agents.length));
      var rows = Math.ceil(agents.length / cols);
      var cellW = Math.floor(innerW / Math.max(cols, 1));
      var cellH = Math.floor(innerH / Math.max(rows, 1));

      for (var i = 0; i < agents.length; i++) {
        var row = Math.floor(i / cols);
        var col = i % cols;
        var ex = Math.floor(innerX + col * cellW + cellW * 0.3);
        var ey = Math.floor(innerY + row * cellH + cellH * 0.2);
        agents[i].zoneX = ex;
        agents[i].zoneY = ey;
        agents[i].zone = { x: zone.x, y: zone.y + LABEL_H, w: zone.w, h: zone.h - LABEL_H };
        if (agents[i].x === 0 && agents[i].y === 0) {
          agents[i].x = ex;
          agents[i].y = ey;
        }
      }
    },

    drawZones: function(ctx) {
      var p = P();
      for (var zk in this.zones) {
        if (!this.zones.hasOwnProperty(zk)) continue;
        var zone = this.zones[zk];

        ctx.save();
        ctx.globalAlpha = 0.05;
        ctx.fillStyle = zone.color;
        ctx.fillRect(Math.floor(zone.x), Math.floor(zone.y), Math.floor(zone.w), Math.floor(zone.h));
        ctx.restore();

        ctx.save();
        ctx.globalAlpha = 0.3;
        ctx.fillStyle = zone.color;
        this._dottedRect(ctx, Math.floor(zone.x), Math.floor(zone.y), Math.floor(zone.w), Math.floor(zone.h));
        ctx.restore();

        // Zone label: semi-opaque background + scale 2 + agent count
        var labelScale = Math.max(1, Math.floor(this.scale));
        var countStr = zone.agents ? ' (' + zone.agents.length + ')' : '';
        var labelStr = zone.label.toUpperCase() + countStr;
        var lblW = textWidth(labelStr, labelScale);
        var lblH = 4 * labelScale + 2;
        ctx.save();
        ctx.globalAlpha = 0.7;
        ctx.fillStyle = p.panel;
        ctx.fillRect(Math.floor(zone.x + 1), Math.floor(zone.y + 1), lblW + 4, lblH + 2);
        ctx.restore();
        drawText(ctx, labelStr, zone.x + 3, zone.y + 2, zone.color, labelScale);
      }

      if (this.workspace) {
        var ws = this.workspace;
        // Workspace background
        ctx.save();
        ctx.globalAlpha = 0.08;
        ctx.fillStyle = p.green;
        ctx.fillRect(Math.floor(ws.x), Math.floor(ws.y), Math.floor(ws.w), Math.floor(ws.h));
        ctx.restore();

        // Full dotted border (all 4 sides)
        ctx.save();
        ctx.globalAlpha = 0.3;
        ctx.fillStyle = p.green;
        this._dottedRect(ctx, Math.floor(ws.x), Math.floor(ws.y), Math.floor(ws.w), Math.floor(ws.h));
        ctx.restore();

        // Workspace label — contextual
        var hasActive = false;
        for (var zk2 in this.zones) {
          if (!this.zones.hasOwnProperty(zk2)) continue;
          var za = this.zones[zk2].agents || [];
          for (var zai = 0; zai < za.length; zai++) {
            if (za[zai].isActive) { hasActive = true; break; }
          }
          if (hasActive) break;
        }
        var wsLabel = hasActive ? 'ACTIVE WORKSPACE' : 'AWAITING ORDERS...';
        var wsColor = hasActive ? p.green : p.dim;
        var wsLw = textWidth(wsLabel, 1);
        drawText(ctx, wsLabel, Math.floor(ws.x + (ws.w - wsLw) / 2), Math.floor(ws.y + 2), wsColor, 1);
      }
    },

    _dottedRect: function(ctx, x, y, w, h) {
      for (var dx = 0; dx < w; dx += 2) ctx.fillRect(x + dx, y, 1, 1);
      for (var dx2 = 0; dx2 < w; dx2 += 2) ctx.fillRect(x + dx2, y + h - 1, 1, 1);
      for (var dy = 0; dy < h; dy += 2) ctx.fillRect(x, y + dy, 1, 1);
      for (var dy2 = 0; dy2 < h; dy2 += 2) ctx.fillRect(x + w - 1, y + dy2, 1, 1);
    }
  };


  // ── MODULE 4: INTERACTION MANAGER ──

  const InteractionManager = {
    mouseX: -1, mouseY: -1,
    hoveredEntity: null, pinnedEntity: null,
    lastClickTime: 0, _animFrame: 0, _attached: false,

    attach: function(canvas) {
      if (this._attached) return;
      this._attached = true;
      var self = this;
      canvas.addEventListener('mousemove', function(e) {
        var rect = canvas.getBoundingClientRect();
        var dpr = window.devicePixelRatio || 1;
        self.mouseX = Math.floor((e.clientX - rect.left) * dpr);
        self.mouseY = Math.floor((e.clientY - rect.top) * dpr);
      });
      canvas.addEventListener('click', function() {
        if (self.hoveredEntity) {
          self.pinnedEntity = (self.pinnedEntity === self.hoveredEntity) ? null : self.hoveredEntity;
        } else {
          self.pinnedEntity = null;
        }
        self.lastClickTime = Date.now();
      });
      canvas.addEventListener('dblclick', function() {
        self.pinnedEntity = null;
        self.hoveredEntity = null;
      });
      canvas.addEventListener('mouseleave', function() {
        self.mouseX = -1; self.mouseY = -1;
        self.hoveredEntity = null;
      });
    },

    hitTest: function(entities, scale) {
      if (this.mouseX < 0 || this.mouseY < 0) { this.hoveredEntity = null; return null; }
      var spriteW = 12 * scale;
      var spriteH = 14 * scale;
      for (var i = 0; i < entities.length; i++) {
        var e = entities[i];
        var ex = e.x || 0;
        var ey = e.y || 0;
        if (this.mouseX >= ex && this.mouseX <= ex + spriteW && this.mouseY >= ey && this.mouseY <= ey + spriteH) {
          this.hoveredEntity = e;
          e.hovered = true;
          return e;
        }
        e.hovered = false;
      }
      this.hoveredEntity = null;
      return null;
    },

    drawTooltip: function(ctx, entity, scale, canvasW, canvasH) {
      if (!entity) return;
      var p = P();
      var fs = 1;
      var pad = 3;
      var lineH = 7;

      var lines = [];
      var lineColors = [];
      lines.push((entity.name || 'unknown').toUpperCase());
      lineColors.push(p.cyan);
      lines.push(((entity.category || 'general') + ' > ' + (entity.project || '?')).toUpperCase());
      lineColors.push(p.gray);

      if (entity.state === STATE.WORKING) { lines.push('STATUS: WORKING'); lineColors.push(p.cyan); }
      else if (entity.state === STATE.ERROR) { lines.push('STATUS: ERROR'); lineColors.push(p.red); }
      else if (entity.state === STATE.DONE) { lines.push('STATUS: DONE'); lineColors.push(p.green); }

      if (entity.currentTask) {
        var task = entity.currentTask;
        if (task.length > 30) task = task.substring(0, 27) + '...';
        lines.push('TASK: ' + task.toUpperCase());
        lineColors.push(p.text);
      }

      if (entity.error && entity.state === STATE.ERROR) {
        var errMsg = entity.error;
        if (errMsg.length > 28) errMsg = errMsg.substring(0, 25) + '...';
        lines.push('ERR: ' + errMsg.toUpperCase());
        lineColors.push(p.red);
      }

      if (entity.progress > 0 && entity.state === STATE.WORKING) {
        var pct = Math.min(100, Math.max(0, entity.progress));
        lines.push('PROGRESS: ' + pct + '%');
        lineColors.push(p.green);
      }

      if (entity.invocationCount > 0) {
        lines.push('INVOCATIONS: ' + entity.invocationCount);
        lineColors.push(p.gray);
      }

      if (entity.description) {
        var desc = entity.description;
        if (desc.length > 30) desc = desc.substring(0, 27) + '...';
        lines.push(desc.toUpperCase());
        lineColors.push(p.dim);
      }

      var maxLineW = 0;
      for (var li = 0; li < lines.length; li++) {
        var lw = textWidth(lines[li], fs);
        if (lw > maxLineW) maxLineW = lw;
      }
      var tipW = Math.min(maxLineW + pad * 2, 160);
      var tipH = lines.length * lineH + pad * 2;
      var ex = entity.x || 0;
      var ey = entity.y || 0;
      var sprW = 12 * scale;

      var tipX = Math.floor(ex + sprW / 2 - tipW / 2);
      var tipY = Math.floor(ey - tipH - 7);
      if (tipX < 1) tipX = 1;
      if (tipX + tipW > canvasW - 1) tipX = canvasW - tipW - 1;
      if (tipY < 1) tipY = Math.floor(ey + 14 * scale + 5);

      ctx.save();
      ctx.globalAlpha = 0.9;
      ctx.fillStyle = p.panel;
      ctx.fillRect(tipX, tipY, tipW, tipH);
      ctx.restore();

      ctx.fillStyle = p.cyan;
      ctx.fillRect(tipX, tipY, tipW, 1);
      ctx.fillRect(tipX, tipY + tipH - 1, tipW, 1);
      ctx.fillRect(tipX, tipY, 1, tipH);
      ctx.fillRect(tipX + tipW - 1, tipY, 1, tipH);

      var tailX = Math.floor(ex + sprW / 2);
      if (tailX < tipX + 2) tailX = tipX + 2;
      if (tailX > tipX + tipW - 4) tailX = tipX + tipW - 4;
      ctx.fillStyle = p.panel;
      ctx.fillRect(tailX - 1, tipY + tipH, 3, 1);
      ctx.fillRect(tailX, tipY + tipH + 1, 1, 1);
      ctx.fillStyle = p.cyan;
      ctx.fillRect(tailX - 2, tipY + tipH, 1, 1);
      ctx.fillRect(tailX + 2, tipY + tipH, 1, 1);

      for (var ti = 0; ti < lines.length; ti++) {
        drawText(ctx, lines[ti], tipX + pad, tipY + pad + ti * lineH, lineColors[ti], fs);
      }
    },

    drawActivityBubbles: function(ctx, entities, scale) {
      this._animFrame = (this._animFrame + 1) % 90;
      var p = P();
      var fs = 1;
      var pad = 2;

      for (var i = 0; i < entities.length; i++) {
        var e = entities[i];
        if (e.state !== STATE.WORKING && e.state !== STATE.ERROR) continue;
        if (e === this.hoveredEntity || e === this.pinnedEntity) continue;

        var ex = e.x || 0;
        var ey = e.y || 0;
        var spriteW = 12 * scale;
        var bubbleText, borderColor;

        if (e.state === STATE.ERROR) {
          bubbleText = '!';
          borderColor = p.red;
        } else {
          if (e.currentTask) bubbleText = e.currentTask.substring(0, 12);
          else {
            var dotPhase = Math.floor(this._animFrame / 15) % 3;
            bubbleText = dotPhase === 0 ? '.  ' : dotPhase === 1 ? '.. ' : '...';
          }
          borderColor = p.cyan;
        }

        var tw = textWidth(bubbleText, fs);
        var bw = Math.min(tw + pad * 2, 60);
        var bh = 5 * fs + pad * 2;
        var bx = Math.floor(ex + spriteW / 2 - bw / 2);
        var by = Math.floor(ey - bh - 3);

        ctx.fillStyle = p.panel;
        ctx.fillRect(bx, by, bw, bh);
        ctx.fillStyle = borderColor;
        ctx.fillRect(bx, by, bw, 1);
        ctx.fillRect(bx, by + bh - 1, bw, 1);
        ctx.fillRect(bx, by, 1, bh);
        ctx.fillRect(bx + bw - 1, by, 1, bh);

        var textColor = e.state === STATE.ERROR ? p.red : p.text;
        drawText(ctx, bubbleText.toUpperCase(), bx + pad, by + pad, textColor, fs);
      }
    }
  };


  // ── MODULE 5: DATA BRIDGE ──

  const DataBridge = {
    entities: [],
    entityMap: {},
    initialized: false,

    initFromRoster: function(rosterData) {
      if (!rosterData) return;
      this.entities = [];
      this.entityMap = {};

      var projects = rosterData.projects || {};
      for (var pid in projects) {
        if (!projects.hasOwnProperty(pid)) continue;
        var agents = projects[pid] || [];
        for (var ai = 0; ai < agents.length; ai++) {
          var ag = agents[ai];
          var entity = new AgentEntity({ name: ag.name || 'unnamed', category: ag.category || 'general', project: pid, type: 'agent', description: ag.description || '' });
          this.entities.push(entity);
          this.entityMap[this._normalizeKey(entity.name)] = entity;
        }
      }

      var common = rosterData.commonAgents || [];
      for (var ci = 0; ci < common.length; ci++) {
        var ca = common[ci];
        var cEntity = new AgentEntity({ name: ca.name || 'unnamed', category: ca.category || 'general', project: 'common', type: 'agent', description: ca.description || '' });
        this.entities.push(cEntity);
        this.entityMap[this._normalizeKey(cEntity.name)] = cEntity;
      }

      var skills = rosterData.skills || [];
      for (var si = 0; si < skills.length; si++) {
        var sk = skills[si];
        var sEntity = new AgentEntity({ name: sk.name || 'unnamed-skill', category: 'general', project: 'all', type: 'skill', score: sk.score || 0 });
        this.entities.push(sEntity);
        this.entityMap[this._normalizeKey(sEntity.name)] = sEntity;
      }

      this.initialized = true;
    },

    applyStatus: function(statusData) {
      if (!statusData || !this.initialized) return;
      var activatedNames = {};
      var workers = statusData.workers || [];

      for (var wi = 0; wi < workers.length; wi++) {
        var w = workers[wi];
        var domain = w.domain || w.name || '';
        if (!domain) continue;
        var entity = this._findEntity(domain);

        if (!entity) {
          entity = new AgentEntity({ name: domain, category: 'general', project: 'unknown', type: 'agent' });
          this.entities.push(entity);
          this.entityMap[this._normalizeKey(domain)] = entity;
        }

        entity.currentTask = w.current_task || '';
        entity.progress = w.progress || 0;
        entity.error = w.error || '';
        var s = String(w.status || 'pending').toLowerCase();
        if (s === 'in_progress' || s === 'running') { entity.state = STATE.WORKING; entity.isActive = true; }
        else if (s === 'done' || s === 'completed' || s === 'merged') { entity.state = STATE.DONE; entity.isActive = true; }
        else if (s === 'error' || s === 'failed') { entity.state = STATE.ERROR; entity.isActive = true; }
        else { entity.state = STATE.IDLE; entity.isActive = false; }
        activatedNames[this._normalizeKey(domain)] = true;
      }

      for (var ei = 0; ei < this.entities.length; ei++) {
        var ent = this.entities[ei];
        var key = this._normalizeKey(ent.name);
        if (ent.isActive && !activatedNames[key]) {
          ent.isActive = false;
          ent.state = STATE.IDLE;  // Return to static grid
          ent.currentTask = '';
          ent.progress = 0;
          ent.collaborationGroup = null;
        }
      }
    },

    applyMetrics: function(metricsData) {
      if (!metricsData || !this.initialized) return;
      var topAgents = metricsData.topAgents || [];
      for (var ai = 0; ai < topAgents.length; ai++) {
        var ag = topAgents[ai];
        var entity = this._findEntity(ag.name || '');
        if (entity) entity.invocationCount = ag.count || 0;
      }
      var topSkills = metricsData.topSkills || [];
      for (var si = 0; si < topSkills.length; si++) {
        var sk = topSkills[si];
        var sEntity = this._findEntity(sk.name || '');
        if (sEntity) sEntity.invocationCount = sk.count || 0;
      }
    },

    applyLiveActivity: function(agents) {
      if (!agents || !this.initialized) return;
      var now = Date.now();
      var activeNames = {};

      for (var i = 0; i < agents.length; i++) {
        var a = agents[i];
        var name = a.name || '';
        if (!name) continue;

        // Try exact match first, then fuzzy
        var entity = this._findEntity(name);

        // If no match, try matching by category/description keywords
        if (!entity) {
          entity = this._findEntityByKeywords(name, a.description || '');
        }

        // If still no match, create a dynamic entity
        if (!entity) {
          entity = new AgentEntity({ name: name, category: this._guessCategory(name), project: a.project || 'common', type: 'agent', description: a.description || '' });
          this.entities.push(entity);
          this.entityMap[this._normalizeKey(name)] = entity;
          this._needsRelayout = true;
        }

        if (!entity.isActive) {
          entity.state = STATE.WORKING;
          entity.isActive = true;
        }
        entity.currentTask = a.description || 'active';
        entity._liveTs = now;
        activeNames[this._normalizeKey(entity.name)] = true;
      }

      // Re-layout if new entities were added
      if (this._needsRelayout) {
        this._needsRelayout = false;
      }

      // Deactivate entities that were live-activated but no longer active
      for (var ei = 0; ei < this.entities.length; ei++) {
        var ent = this.entities[ei];
        if (ent._liveTs && !activeNames[this._normalizeKey(ent.name)]) {
          ent.isActive = false;
          ent.state = STATE.IDLE;
          ent.currentTask = '';
          ent._liveTs = 0;
        }
      }
    },

    _findEntityByKeywords: function(name, desc) {
      // Map common Claude Code subagent types to likely entity names
      var AGENT_MAP = {
        'explore': ['godot_expert', 'debug_qa', 'llm_expert'],
        'general-purpose': ['studio_orchestrator', 'task_dispatcher'],
        'plan': ['studio_orchestrator', 'task_dispatcher'],
        'build-error-resolver': ['debug_qa', 'godot_expert'],
        'code-reviewer': ['merlin_guardian', 'debug_qa'],
        'security-reviewer': ['merlin_guardian'],
        'tdd-guide': ['debug_qa'],
        'doc-updater': ['narrative_writer'],
        'refactor-cleaner': ['godot_expert'],
        'e2e-runner': ['debug_qa'],
        'architect': ['studio_orchestrator'],
        'planner': ['studio_orchestrator', 'task_dispatcher'],
      };
      var key = name.toLowerCase().replace(/[-_\s]/g, '');
      for (var mapKey in AGENT_MAP) {
        if (key === mapKey.replace(/[-_\s]/g, '')) {
          var candidates = AGENT_MAP[mapKey];
          for (var ci = 0; ci < candidates.length; ci++) {
            var ent = this.entityMap[this._normalizeKey(candidates[ci])];
            if (ent && !ent.isActive) return ent;
          }
        }
      }
      // Fallback: search description keywords against entity names
      var words = (name + ' ' + desc).toLowerCase().split(/[\s_-]+/);
      for (var k in this.entityMap) {
        if (!this.entityMap.hasOwnProperty(k)) continue;
        var e = this.entityMap[k];
        if (e.isActive) continue;
        for (var wi = 0; wi < words.length; wi++) {
          if (words[wi].length > 3 && k.indexOf(words[wi]) >= 0) return e;
        }
      }
      return null;
    },

    _guessCategory: function(name) {
      var n = name.toLowerCase();
      if (/explore|search|grep|glob/.test(n)) return 'core';
      if (/build|error|resolve/.test(n)) return 'quality';
      if (/security|review/.test(n)) return 'security';
      if (/plan|architect/.test(n)) return 'orchestration';
      if (/test|tdd|e2e/.test(n)) return 'quality';
      if (/doc|write/.test(n)) return 'ops';
      if (/design|ui/.test(n)) return 'ui-ux';
      if (/llm|lora|brain/.test(n)) return 'llm';
      return 'general';
    },

    getActiveEntities: function() {
      var result = [];
      for (var i = 0; i < this.entities.length; i++) {
        if (this.entities[i].isActive) result.push(this.entities[i]);
      }
      return result;
    },

    _normalizeKey: function(name) {
      return String(name).toLowerCase().replace(/[-_]/g, '');
    },

    _findEntity: function(name) {
      if (!name) return null;
      var key = this._normalizeKey(name);
      if (this.entityMap[key]) return this.entityMap[key];
      for (var k in this.entityMap) {
        if (!this.entityMap.hasOwnProperty(k)) continue;
        if (k.indexOf(key) === 0 || key.indexOf(k) === 0) return this.entityMap[k];
      }
      for (var k2 in this.entityMap) {
        if (!this.entityMap.hasOwnProperty(k2)) continue;
        if (k2.indexOf(key) !== -1 || key.indexOf(k2) !== -1) return this.entityMap[k2];
      }
      return null;
    }
  };

  // ══════════════════════════════════════════════════════════════
  // ── END VILLAGE MODE MODULES ──
  // ══════════════════════════════════════════════════════════════


  // ── TASK PANEL (DOM) ──
  class TaskPanel {
    constructor(element) {
      this.el = element;
      this.lastHtml = '';
    }

    update(data) {
      const p = P();
      const workers = data.workers || [];
      const state = (data.state || 'idle').toUpperCase();
      const stateColor = state === 'RUNNING' ? p.cyan : state === 'DONE' ? p.green : state === 'STOPPED' ? p.red : p.amber;

      let html = '<div style="padding:6px;">';
      html += '<div style="color:' + p.green + ';font-size:10px;font-weight:700;letter-spacing:1px;margin-bottom:6px;">' + activeTheme.headerTitle + '</div>';
      html += '<div style="color:' + stateColor + ';font-size:9px;margin-bottom:4px;">' + state + '</div>';

      if (data.objective) {
        html += '<div style="color:' + p.gray + ';font-size:9px;margin-bottom:8px;word-break:break-word;">' + this._esc(data.objective).substring(0, 80) + '</div>';
      }

      html += '<div style="border-top:1px solid ' + p.border + ';margin:4px 0;"></div>';
      html += '<div style="font-size:9px;color:' + p.gray + ';margin-bottom:4px;letter-spacing:0.5px;">WORKERS (' + workers.length + ')</div>';

      for (const w of workers) {
        const domain = w.domain || w.name || '?';
        const status = (w.status || 'pending').toLowerCase();
        const dotColor = status === 'in_progress' || status === 'running' ? p.cyan
          : status === 'done' || status === 'completed' || status === 'merged' ? p.green
          : status === 'error' || status === 'failed' ? p.red
          : p.gray;
        const task = w.current_task || '';
        const progress = w.progress || 0;

        html += '<div style="margin-bottom:6px;">';
        html += '<div style="display:flex;align-items:center;gap:4px;">';
        html += '<span style="width:6px;height:6px;border-radius:50%;background:' + dotColor + ';display:inline-block;flex-shrink:0;"></span>';
        html += '<span style="color:' + (domainColor(domain)) + ';font-size:10px;font-weight:600;">' + this._esc(domain) + '</span>';
        if (w.a2a_status) {
          const a2aBadgeColor = w.a2a_status === 'delegating' ? p.amber : w.a2a_status === 'waiting' ? p.cyan : w.a2a_status === 'receiving' ? p.green : p.gray;
          html += '<span style="font-size:7px;padding:1px 4px;border-radius:3px;background:' + a2aBadgeColor + ';color:#000;margin-left:4px;font-weight:600;">' + this._esc(w.a2a_status).toUpperCase() + '</span>';
        }
        html += '</div>';
        if (w.progress_pct != null && w.progress_pct > 0) {
          html += '<div style="margin-left:10px;margin-top:2px;height:3px;background:' + p.border + ';border-radius:1px;">';
          html += '<div style="width:' + Math.min(100, w.progress_pct) + '%;height:100%;background:' + p.cyan + ';border-radius:1px;transition:width 0.3s;"></div>';
          html += '</div>';
        }

        if (task) {
          html += '<div style="color:' + p.text + ';font-size:9px;margin-left:10px;opacity:0.8;">' + this._esc(task).substring(0, 30) + '</div>';
        }

        if (progress > 0 && (status === 'in_progress' || status === 'running')) {
          html += '<div style="margin-left:10px;margin-top:2px;height:3px;background:' + p.border + ';border-radius:1px;">';
          html += '<div style="width:' + progress + '%;height:100%;background:' + p.green + ';border-radius:1px;"></div>';
          html += '</div>';
        }

        if (w.error || (w.blockers && w.blockers.length > 0)) {
          const err = w.error || w.blockers[0] || '';
          html += '<div style="color:' + p.red + ';font-size:8px;margin-left:10px;">' + this._esc(err).substring(0, 40) + '</div>';
        }

        html += '</div>';
      }

      html += '</div>';

      if (html !== this.lastHtml) {
        this.el.innerHTML = html;
        this.lastHtml = html;
      }
    }

    _esc(s) {
      return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    }
  }

  // ── ROSTER PANEL (DOM) ──
  // Displays full agent/skill catalog across all projects
  class RosterPanel {
    constructor(element) {
      this.el = element;
      this.lastHtml = '';
      this.rosterData = null;
      this.filter = 'all'; // 'all' | 'merlin' | 'data' | 'cours' | 'common'
    }

    setFilter(f) {
      this.filter = f;
      if (this.rosterData) this.render();
    }

    update(data) {
      this.rosterData = data;
      this.render();
    }

    render() {
      if (!this.rosterData) return;
      var p = P();
      var d = this.rosterData;
      var filter = this.filter;

      // Category icons (text-based pixel art feel)
      var catIcons = {
        'core': '>', 'llm': '>', 'design': '>', 'narrative': '>',
        'creative': '>', 'ui-ux': '>', 'quality': '>', 'ops': '>',
        'security': '>', 'orchestration': '>', 'data': '>', 'education': '>',
        'tools': '>', 'general': '>',
      };

      // Category colors
      var catColors = {
        'core': '#00ff41', 'llm': '#44ff88', 'design': '#ffb300',
        'narrative': '#aa44ff', 'creative': '#ff8844', 'ui-ux': '#00e5ff',
        'quality': '#ff3333', 'ops': '#6d7b6d', 'security': '#ff4444',
        'orchestration': '#e0ffe0', 'data': '#FF7900', 'education': '#4488ff',
        'tools': '#66bbff', 'general': '#b0c8b0',
      };

      // Project badge colors
      var projColors = { merlin: '#00ff41', data: '#FF7900', cours: '#4488ff', common: '#b0c8b0' };

      var html = '<div style="padding:6px;font-family:\'Cascadia Code\',\'Fira Code\',Consolas,monospace;">';

      // Title
      html += '<div style="color:' + p.green + ';font-size:11px;font-weight:700;letter-spacing:1px;margin-bottom:6px;">ROSTER</div>';

      // Totals summary
      var t = d.totals || {};
      html += '<div style="font-size:9px;margin-bottom:6px;display:flex;gap:6px;flex-wrap:wrap;">';
      var projBtns = [
        { id: 'all', label: 'ALL', count: (t.merlin||0)+(t.data||0)+(t.cours||0)+(t.common||0) },
        { id: 'merlin', label: 'MERLIN', count: t.merlin||0 },
        { id: 'data', label: 'DATA', count: t.data||0 },
        { id: 'cours', label: 'COURS', count: t.cours||0 },
        { id: 'common', label: 'COMMON', count: t.common||0 },
      ];
      for (var bi = 0; bi < projBtns.length; bi++) {
        var btn = projBtns[bi];
        var active = filter === btn.id;
        var btnBg = active ? (projColors[btn.id] || p.green) : p.border;
        var btnFg = active ? p.bg : (projColors[btn.id] || p.text);
        html += '<span data-roster-filter="' + btn.id + '" style="cursor:pointer;padding:2px 5px;border-radius:2px;';
        html += 'background:' + btnBg + ';color:' + btnFg + ';font-size:8px;font-weight:600;">';
        html += btn.label + ' ' + btn.count + '</span>';
      }
      html += '</div>';

      html += '<div style="border-top:1px solid ' + p.border + ';margin:4px 0;"></div>';

      // Agents grouped by category
      var agents = this._filteredAgents(d);
      var grouped = {};
      for (var ai = 0; ai < agents.length; ai++) {
        var a = agents[ai];
        var cat = a.category || 'general';
        if (!grouped[cat]) grouped[cat] = [];
        grouped[cat].push(a);
      }

      var catOrder = ['orchestration','core','llm','design','narrative','creative','ui-ux','quality','ops','security','data','education','tools','general'];
      var totalAgents = agents.length;
      html += '<div style="font-size:9px;color:' + p.gray + ';margin-bottom:4px;letter-spacing:0.5px;">AGENTS (' + totalAgents + ')</div>';

      for (var ci = 0; ci < catOrder.length; ci++) {
        var cat = catOrder[ci];
        if (!grouped[cat] || grouped[cat].length === 0) continue;
        var catGroup = grouped[cat];
        var cc = catColors[cat] || p.text;

        html += '<div style="margin-bottom:6px;">';
        html += '<div style="color:' + cc + ';font-size:9px;font-weight:600;text-transform:uppercase;margin-bottom:2px;">';
        html += (catIcons[cat] || '>') + ' ' + cat + ' (' + catGroup.length + ')</div>';
        html += '<div style="display:flex;flex-wrap:wrap;gap:3px;margin-left:8px;">';

        for (var gi = 0; gi < catGroup.length; gi++) {
          var ag = catGroup[gi];
          var projBadge = projColors[ag.project] || p.gray;
          html += '<span style="font-size:8px;padding:1px 4px;border-radius:2px;';
          html += 'border:1px solid ' + projBadge + ';color:' + p.text + ';">';
          html += this._esc(ag.name) + '</span>';
        }

        html += '</div></div>';
      }

      // Skills section
      var skills = (d.skills || []);
      html += '<div style="border-top:1px solid ' + p.border + ';margin:6px 0;"></div>';
      html += '<div style="font-size:9px;color:' + p.gray + ';margin-bottom:4px;letter-spacing:0.5px;">SKILLS (' + skills.length + ')</div>';

      for (var si = 0; si < skills.length; si++) {
        var sk = skills[si];
        var score = sk.score || 0;
        var barColor = score >= 9 ? '#00ff41' : score >= 7 ? '#44ff88' : score >= 5 ? '#ffb300' : score >= 3 ? '#ff8844' : '#6d7b6d';
        var barW = Math.max(1, Math.min(10, score)) * 10;
        var projLabel = sk.projects || '';

        html += '<div style="display:flex;align-items:center;gap:4px;margin-bottom:2px;font-size:8px;">';
        html += '<div style="width:100px;height:4px;background:' + p.border + ';border-radius:1px;flex-shrink:0;">';
        html += '<div style="width:' + barW + '%;height:100%;background:' + barColor + ';border-radius:1px;"></div></div>';
        html += '<span style="color:' + barColor + ';width:14px;text-align:right;">' + score + '</span>';
        html += '<span style="color:' + p.text + ';flex:1;">' + this._esc(sk.name) + '</span>';
        if (projLabel) {
          html += '<span style="color:' + p.gray + ';font-size:7px;">' + this._esc(projLabel) + '</span>';
        }
        html += '</div>';
      }

      html += '</div>';

      if (html !== this.lastHtml) {
        this.el.innerHTML = html;
        this.lastHtml = html;
        this._bindFilters();
      }
    }

    _filteredAgents(d) {
      var filter = this.filter;
      var all = [];
      if (d.projects) {
        for (var pid in d.projects) {
          if (!d.projects.hasOwnProperty(pid)) continue;
          if (filter !== 'all' && filter !== pid) continue;
          var arr = d.projects[pid] || [];
          for (var i = 0; i < arr.length; i++) all.push(arr[i]);
        }
      }
      if (filter === 'all' || filter === 'common') {
        var common = d.commonAgents || [];
        for (var j = 0; j < common.length; j++) all.push(common[j]);
      }
      return all;
    }

    _bindFilters() {
      var self = this;
      var btns = this.el.querySelectorAll('[data-roster-filter]');
      for (var i = 0; i < btns.length; i++) {
        btns[i].addEventListener('click', function () {
          self.setFilter(this.getAttribute('data-roster-filter'));
        });
      }
    }

    _esc(s) {
      return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    }
  }

  // ── METRICS PANEL (DOM) ──
  class MetricsPanel {
    constructor(element) {
      this.el = element;
      this.lastHtml = '';
      this.metricsData = null;
    }

    update(data) {
      this.metricsData = data;
      this.render();
    }

    render() {
      if (!this.metricsData) return;
      var p = P();
      var d = this.metricsData;

      var html = '<div style="padding:6px;font-family:\'Cascadia Code\',\'Fira Code\',Consolas,monospace;">';
      html += '<div style="color:' + p.green + ';font-size:11px;font-weight:700;letter-spacing:1px;margin-bottom:4px;">METRICS</div>';
      html += '<div style="font-size:9px;color:' + p.gray + ';margin-bottom:6px;">' + (d.total || 0) + ' events tracked</div>';

      // By project
      var byProj = d.byProject || {};
      var projKeys = Object.keys(byProj);
      if (projKeys.length > 0) {
        html += '<div style="font-size:9px;color:' + p.gray + ';margin-bottom:3px;letter-spacing:0.5px;">BY PROJECT</div>';
        html += '<div style="display:flex;gap:8px;margin-bottom:8px;flex-wrap:wrap;">';
        var projColors = { merlin: '#00ff41', data: '#FF7900', cours: '#4488ff', unknown: '#6d7b6d' };
        for (var pi = 0; pi < projKeys.length; pi++) {
          var pk = projKeys[pi];
          html += '<span style="font-size:9px;color:' + (projColors[pk] || p.text) + ';font-weight:600;">' + pk.toUpperCase() + ' ' + byProj[pk] + '</span>';
        }
        html += '</div>';
      }

      // Activity sparkline (last 14 days)
      var byDay = d.byDay || [];
      if (byDay.length > 0) {
        var maxDay = Math.max.apply(null, byDay.map(function(x) { return x.count; }));
        html += '<div style="font-size:9px;color:' + p.gray + ';margin-bottom:3px;letter-spacing:0.5px;">ACTIVITY (14 DAYS)</div>';
        html += '<div style="display:flex;align-items:flex-end;gap:2px;height:30px;margin-bottom:8px;">';
        for (var di = 0; di < byDay.length; di++) {
          var barH = maxDay > 0 ? Math.max(2, Math.round(byDay[di].count / maxDay * 28)) : 2;
          html += '<div title="' + byDay[di].day + ': ' + byDay[di].count + '" style="flex:1;height:' + barH + 'px;background:' + p.green + ';border-radius:1px;opacity:0.8;"></div>';
        }
        html += '</div>';
      }

      html += '<div style="border-top:1px solid ' + p.border + ';margin:4px 0;"></div>';

      // Top agents
      var topAgents = d.topAgents || [];
      if (topAgents.length > 0) {
        var maxA = topAgents[0].count || 1;
        html += '<div style="font-size:9px;color:' + p.gray + ';margin-bottom:3px;letter-spacing:0.5px;">TOP AGENTS (' + topAgents.length + ')</div>';
        for (var ai = 0; ai < topAgents.length; ai++) {
          var ag = topAgents[ai];
          var bwA = Math.max(5, Math.round(ag.count / maxA * 100));
          html += '<div style="display:flex;align-items:center;gap:4px;margin-bottom:2px;font-size:8px;">';
          html += '<div style="width:80px;height:4px;background:' + p.border + ';border-radius:1px;flex-shrink:0;">';
          html += '<div style="width:' + bwA + '%;height:100%;background:' + p.cyan + ';border-radius:1px;"></div></div>';
          html += '<span style="color:' + p.cyan + ';width:20px;text-align:right;">' + ag.count + '</span>';
          html += '<span style="color:' + p.text + ';flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">' + this._esc(ag.name) + '</span>';
          html += '</div>';
        }
      }

      html += '<div style="border-top:1px solid ' + p.border + ';margin:6px 0;"></div>';

      // Top skills
      var topSkills = d.topSkills || [];
      if (topSkills.length > 0) {
        var maxS = topSkills[0].count || 1;
        html += '<div style="font-size:9px;color:' + p.gray + ';margin-bottom:3px;letter-spacing:0.5px;">TOP SKILLS (' + topSkills.length + ')</div>';
        for (var si = 0; si < topSkills.length; si++) {
          var sk = topSkills[si];
          var bwS = Math.max(5, Math.round(sk.count / maxS * 100));
          html += '<div style="display:flex;align-items:center;gap:4px;margin-bottom:2px;font-size:8px;">';
          html += '<div style="width:80px;height:4px;background:' + p.border + ';border-radius:1px;flex-shrink:0;">';
          html += '<div style="width:' + bwS + '%;height:100%;background:' + p.amber + ';border-radius:1px;"></div></div>';
          html += '<span style="color:' + p.amber + ';width:20px;text-align:right;">' + sk.count + '</span>';
          html += '<span style="color:' + p.text + ';flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">' + this._esc(sk.name) + '</span>';
          html += '</div>';
        }
      } else {
        html += '<div style="font-size:8px;color:' + p.gray + ';">No skill invocations recorded yet.</div>';
      }

      html += '</div>';

      if (html !== this.lastHtml) {
        this.el.innerHTML = html;
        this.lastHtml = html;
      }
    }

    _esc(s) {
      return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    }
  }

  // ── TRAIN PANEL ──
  // GPU Training control panel — brain cards, quality gates, chat, enrichment
  class TrainPanel {
    constructor(el) {
      this.el = el;
      this._data = null;
      this._chatHistory = [];
    }

    update(data) {
      if (!this.el) return;
      this._data = data || {};
      var p = P();
      var d = this._data;
      var html = '';

      // Brain definitions
      var brains = [
        { id: 'narrator', label: 'NARRATOR 4B', role: 'Texte creatif, choix, ambiance', model: 'Qwen2.5-3B', color: '#aa44ff' },
        { id: 'gamemaster', label: 'GAME MASTER 2B', role: 'Effets JSON, equilibrage', model: 'Qwen2.5-1.5B', color: '#00ff41' },
        { id: 'worker', label: 'WORKER 0.8B', role: 'Taches rapides, scoring', model: 'Qwen2.5-0.5B', color: '#66bbff' }
      ];

      // Header
      html += '<div style="font-size:10px;color:' + p.cyan + ';font-weight:700;letter-spacing:1px;margin-bottom:6px;">GPU TRAIN + CHAT</div>';

      // Brain cards
      html += '<div style="display:flex;gap:4px;margin-bottom:8px;flex-wrap:wrap;">';
      for (var bi = 0; bi < brains.length; bi++) {
        var brain = brains[bi];
        var brainState = (d.brains && d.brains[brain.id]) || {};
        var status = brainState.status || 'unknown';
        var score = brainState.score || '--';
        var dataset = brainState.dataset_count || '--';
        var lastTrained = brainState.last_trained || '--';

        var statusColor = status === 'complete' || status === 'submitted' ? p.green :
                          status === 'error' ? p.red :
                          status === 'running' ? p.cyan : p.gray;

        html += '<div style="flex:1;min-width:80px;background:' + p.panel + ';border:1px solid ' + brain.color + '40;padding:4px;border-radius:2px;">';
        html += '<div style="font-size:8px;font-weight:700;color:' + brain.color + ';letter-spacing:0.5px;">' + brain.label + '</div>';
        html += '<div style="font-size:7px;color:' + p.gray + ';margin:2px 0;">' + brain.role + '</div>';
        html += '<div style="font-size:7px;color:' + p.dim + ';">Model: ' + brain.model + '</div>';
        html += '<div style="font-size:7px;margin:2px 0;"><span style="color:' + p.gray + ';">Status: </span><span style="color:' + statusColor + ';font-weight:700;">' + status.toUpperCase() + '</span></div>';
        html += '<div style="font-size:7px;color:' + p.gray + ';">Score: <span style="color:' + p.text + ';">' + score + '</span></div>';
        html += '<div style="font-size:7px;color:' + p.gray + ';">Dataset: <span style="color:' + p.text + ';">' + dataset + ' samples</span></div>';
        html += '<div style="font-size:7px;color:' + p.dim + ';">' + lastTrained + '</div>';
        html += '<div style="margin-top:3px;display:flex;gap:2px;">';
        html += '<button class="train-btn" data-action="status" data-brain="' + brain.id + '" style="flex:1;font-size:7px;padding:2px;background:' + p.border + ';color:' + p.text + ';border:none;cursor:pointer;border-radius:1px;">STATUS</button>';
        html += '<button class="train-btn" data-action="submit" data-brain="' + brain.id + '" style="flex:1;font-size:7px;padding:2px;background:' + brain.color + '30;color:' + brain.color + ';border:none;cursor:pointer;border-radius:1px;">SUBMIT</button>';
        html += '<button class="train-btn" data-action="test" data-brain="' + brain.id + '" style="flex:1;font-size:7px;padding:2px;background:' + p.border + ';color:' + p.cyan + ';border:none;cursor:pointer;border-radius:1px;">TEST</button>';
        html += '</div>';
        html += '</div>';
      }
      html += '</div>';

      // Quality Gates
      var gates = d.qualityGates || {};
      html += '<div style="font-size:8px;color:' + p.gray + ';font-weight:700;letter-spacing:0.5px;margin-bottom:3px;">QUALITY GATES</div>';
      var gateItems = [
        { key: 'format_compliance', label: 'FORMAT', target: 70, color: p.cyan },
        { key: 'french_rate', label: 'FRENCH', target: 90, color: p.green },
        { key: 'tu_rate', label: 'TU FORM', target: 60, color: '#ffb300' },
        { key: 'celtic_density', label: 'CELTIC', target: 50, color: '#aa44ff' }
      ];
      for (var gi = 0; gi < gateItems.length; gi++) {
        var g = gateItems[gi];
        var val = gates[g.key] || 0;
        var pct = Math.min(100, Math.max(0, val));
        var pass = pct >= g.target;
        html += '<div style="display:flex;align-items:center;gap:4px;margin-bottom:2px;font-size:7px;">';
        html += '<span style="width:40px;color:' + p.gray + ';">' + g.label + '</span>';
        html += '<div style="flex:1;height:4px;background:' + p.border + ';border-radius:1px;position:relative;">';
        html += '<div style="width:' + pct + '%;height:100%;background:' + g.color + ';border-radius:1px;"></div>';
        html += '<div style="position:absolute;left:' + g.target + '%;top:-1px;width:1px;height:6px;background:' + p.text + ';"></div>';
        html += '</div>';
        html += '<span style="width:28px;text-align:right;color:' + (pass ? p.green : p.red) + ';">' + pct + '%</span>';
        html += '</div>';
      }

      // Chat Test
      html += '<div style="border-top:1px solid ' + p.border + ';margin:6px 0;"></div>';
      html += '<div style="font-size:8px;color:' + p.gray + ';font-weight:700;letter-spacing:0.5px;margin-bottom:3px;">CHAT TEST</div>';
      html += '<div style="display:flex;gap:2px;margin-bottom:3px;">';
      html += '<select id="trainChatModel" style="flex:1;font-size:7px;padding:2px;background:' + p.panel + ';color:' + p.text + ';border:1px solid ' + p.border + ';">';
      html += '<option value="narrator">Narrator</option>';
      html += '<option value="gamemaster">Game Master</option>';
      html += '<option value="worker">Worker</option>';
      html += '</select>';
      html += '<select id="trainChatEndpoint" style="flex:1;font-size:7px;padding:2px;background:' + p.panel + ';color:' + p.text + ';border:1px solid ' + p.border + ';">';
      html += '<option value="ollama">Ollama Local</option>';
      html += '<option value="together">Together.ai</option>';
      html += '<option value="groq">Groq</option>';
      html += '</select>';
      html += '</div>';
      html += '<div style="display:flex;gap:2px;margin-bottom:3px;">';
      html += '<input id="trainChatInput" type="text" placeholder="Prompt..." style="flex:1;font-size:7px;padding:2px 4px;background:' + p.panel + ';color:' + p.text + ';border:1px solid ' + p.border + ';outline:none;" />';
      html += '<button id="trainChatSend" style="font-size:7px;padding:2px 6px;background:' + p.cyan + '30;color:' + p.cyan + ';border:none;cursor:pointer;">SEND</button>';
      html += '</div>';
      html += '<div id="trainChatResponse" style="font-size:7px;color:' + p.text + ';background:' + p.bg + ';padding:3px;border:1px solid ' + p.border + ';min-height:30px;max-height:80px;overflow-y:auto;white-space:pre-wrap;border-radius:1px;">';
      html += (d.chatResponse || 'Ready to chat...').substring(0, 500);
      html += '</div>';

      // Training Enrichment
      html += '<div style="border-top:1px solid ' + p.border + ';margin:6px 0;"></div>';
      html += '<div style="font-size:8px;color:' + p.gray + ';font-weight:700;letter-spacing:0.5px;margin-bottom:3px;">ENRICHMENT</div>';
      html += '<div style="display:flex;gap:2px;margin-bottom:2px;">';
      html += '<input id="trainEnrichInput" type="text" placeholder="Orientation / phrase..." style="flex:1;font-size:7px;padding:2px 4px;background:' + p.panel + ';color:' + p.text + ';border:1px solid ' + p.border + ';outline:none;" />';
      html += '<select id="trainEnrichCat" style="font-size:7px;padding:2px;background:' + p.panel + ';color:' + p.text + ';border:1px solid ' + p.border + ';">';
      html += '<option value="tone">Tone</option>';
      html += '<option value="format">Format</option>';
      html += '<option value="language">Language</option>';
      html += '<option value="lore">Lore</option>';
      html += '</select>';
      html += '<button id="trainEnrichAdd" style="font-size:7px;padding:2px 6px;background:#ffb30030;color:#ffb300;border:none;cursor:pointer;">ADD</button>';
      html += '</div>';
      var queueCount = (d.enrichmentQueue || []).length;
      html += '<div style="font-size:7px;color:' + p.dim + ';">Queue: ' + queueCount + ' phrases pending</div>';

      // Pipeline phases
      html += '<div style="border-top:1px solid ' + p.border + ';margin:6px 0;"></div>';
      html += '<div style="font-size:8px;color:' + p.gray + ';font-weight:700;letter-spacing:0.5px;margin-bottom:3px;">PIPELINE</div>';
      var phases = ['doctor', 'setup', 'submit', 'status', 'download', 'benchmark'];
      var currentPhase = d.currentPhase || 'idle';
      for (var pi = 0; pi < phases.length; pi++) {
        var ph = phases[pi];
        var phColor = ph === currentPhase ? p.cyan : p.dim;
        var phPrefix = ph === currentPhase ? '>' : ' ';
        html += '<div style="font-size:7px;color:' + phColor + ';">' + phPrefix + ' ' + (pi + 1) + '. ' + ph.toUpperCase() + '</div>';
      }

      this.el.innerHTML = html;

      // Wire button clicks
      this._wireButtons();
    }

    _wireButtons() {
      if (!this.el) return;
      var self = this;
      var btns = this.el.querySelectorAll('.train-btn');
      for (var i = 0; i < btns.length; i++) {
        btns[i].addEventListener('click', function() {
          var action = this.getAttribute('data-action');
          var brain = this.getAttribute('data-brain');
          if (self.onAction) self.onAction(action, brain);
        });
      }
      var sendBtn = this.el.querySelector('#trainChatSend');
      if (sendBtn) {
        sendBtn.addEventListener('click', function() {
          var input = self.el.querySelector('#trainChatInput');
          var model = self.el.querySelector('#trainChatModel');
          var endpoint = self.el.querySelector('#trainChatEndpoint');
          if (input && model && self.onAction) {
            self.onAction('chat', model.value, {
              prompt: input.value,
              endpoint: endpoint ? endpoint.value : 'ollama'
            });
          }
        });
      }
      var addBtn = this.el.querySelector('#trainEnrichAdd');
      if (addBtn) {
        addBtn.addEventListener('click', function() {
          var input = self.el.querySelector('#trainEnrichInput');
          var cat = self.el.querySelector('#trainEnrichCat');
          if (input && input.value && self.onAction) {
            self.onAction('enrich', null, {
              phrase: input.value,
              category: cat ? cat.value : 'tone'
            });
            input.value = '';
          }
        });
      }
    }

    _esc(s) {
      return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    }
  }

  // ── SCENE ──
  class Scene {
    constructor(canvas, taskPanelEl) {
      this.canvas = canvas;
      this.ctx = canvas.getContext('2d');
      this.ctx.imageSmoothingEnabled = false;
      this.robots = [];
      this.clusters = [];
      this.scale = 3;
      this.lastTime = 0;
      this.running = false;
      this.sessionState = 'idle';
      this.objective = '';
      this.checkpoint = '';
      this.taskPanel = taskPanelEl ? new TaskPanel(taskPanelEl) : null;
      this.rosterPanel = taskPanelEl ? new RosterPanel(taskPanelEl) : null;
      this.metricsPanel = taskPanelEl ? new MetricsPanel(taskPanelEl) : null;
      this.trainPanel = taskPanelEl ? new TrainPanel(taskPanelEl) : null;
      if (this.trainPanel) {
        this.trainPanel.onAction = function(action, brain, opts) {
          // Forward to extension via postMessage (if vscodeApi available)
          if (window._trainActionCallback) {
            window._trainActionCallback(action, brain, opts);
          }
        };
      }
      this.mode = 'live'; // 'live' | 'roster' | 'metrics' | 'train'
      this.renderMode = 'village'; // 'village' | 'neural'
      this._neuralRenderer = null;
      this._lastData = null;
      this._clusterStability = {};

      // Village mode — activated when roster data arrives
      this.villageMode = false;
      this._villageLayoutDone = false;
      this._searchQuery = '';

      // Performance: FPS cap (sidebar = smaller canvas = lower FPS target)
      this._targetFPS = 30;
      this._frameInterval = 1000 / this._targetFPS;
      this._lastFrameTime = 0;
    }

    setData(data) {
      if (!data) return;
      this._lastData = data;
      this.sessionState = data.state || 'idle';
      this.objective = data.objective || '';
      this.checkpoint = data.checkpoint || '';

      // Village mode: apply status to DataBridge entities
      if (this.villageMode && DataBridge.initialized) {
        DataBridge.applyStatus(data);
        // Move active entities toward workspace
        if (ZoneLayout.workspace) {
          var ws = ZoneLayout.workspace;
          var active = DataBridge.getActiveEntities();
          var n = active.length;
          for (var ai = 0; ai < n; ai++) {
            var wsCx = ws.x + ws.w / 2;
            var radius = Math.max(20, n * 10);
            var angle = (ai / Math.max(1, n)) * Math.PI * 2 - Math.PI / 2;
            active[ai].targetX = wsCx + Math.cos(angle) * radius - 6;
            active[ai].targetY = ws.y + ws.h / 2 + Math.sin(angle) * Math.min(radius, ws.h / 3);
          }
        }
        if (this.mode === 'live' && this.taskPanel) this.taskPanel.update(data);
        return;
      }

      // v3 fallback: Robot-based mode
      const workers = data.workers || [];
      const existingMap = {};
      for (const r of this.robots) existingMap[r.domain] = r;

      const newRobots = [];
      for (let i = 0; i < workers.length; i++) {
        const w = workers[i];
        const domain = w.domain || w.name || 'worker-' + i;
        let robot = existingMap[domain];
        if (!robot) {
          robot = new Robot(domain, i);
        }
        robot.index = i;
        robot.accentColor = domainColor(domain);
        robot.updateFromStatus(w);
        newRobots.push(robot);
        delete existingMap[domain];
      }

      if (newRobots.length === 0) {
        if (this.robots.length === 0 || this.robots[0].domain !== 'system') {
          newRobots.push(new Robot('system', 0));
        } else {
          newRobots.push(this.robots[0]);
        }
      }

      this.robots = newRobots;
      this._layout();
      this._buildCollaborations();

      if (this.mode === 'live' && this.taskPanel) this.taskPanel.update(data);
    }

    setRoster(data) {
      this._rosterData = data;

      // Initialize village mode when roster arrives
      if (data && data.projects) {
        DataBridge.initFromRoster(data);
        this.villageMode = true;
        this._villageLayoutDone = false;
        InteractionManager.attach(this.canvas);

        // Apply metrics if already received
        if (this._metricsData) DataBridge.applyMetrics(this._metricsData);
        // Apply status if already received
        if (this._lastData) DataBridge.applyStatus(this._lastData);
        // Compute layout
        this._villageLayout();

        // Initialize neural renderer if in neural mode
        if (this.renderMode === 'neural') {
          this._initNeural();
        }
      }

      if (this.mode === 'roster' && this.rosterPanel) {
        this.rosterPanel.update(data);
      }
    }

    setMetrics(data) {
      this._metricsData = data;
      if (this.villageMode && DataBridge.initialized) {
        DataBridge.applyMetrics(data);
      }
      if (this.mode === 'metrics' && this.metricsPanel) {
        this.metricsPanel.update(data);
      }
    }

    setAgentCards(data) {
      this._agentCardsData = data;
      if (this.mode === 'a2a' && this.taskPanel) {
        this._renderA2APanel();
      }
    }

    setMessages(data) {
      this._messagesData = data;
      if (this.mode === 'a2a' && this.taskPanel) {
        this._renderA2APanel();
      }
    }

    _renderA2APanel() {
      if (!this.taskPanel) return;
      var panel = this.taskPanel.el || this.taskPanel;
      if (!panel) return;

      var cards = this._agentCardsData || {};
      var messages = this._messagesData || {};
      var p = P();

      var html = '';
      html += '<div style="padding:8px;font-family:inherit;color:' + p.text + ';font-size:10px;">';

      // Header
      html += '<div style="color:' + p.green + ';font-size:11px;font-weight:bold;margin-bottom:8px;letter-spacing:1px;">A2A PROTOCOL</div>';

      // Agent count
      var agentCount = cards.agent_count || 0;
      var taskTypes = cards.capability_index ? Object.keys(cards.capability_index).length : 0;
      var keywords = cards.keyword_index ? Object.keys(cards.keyword_index).length : 0;
      html += '<div style="color:' + p.gray + ';margin-bottom:6px;">' + agentCount + ' agents | ' + taskTypes + ' task types | ' + keywords + ' keywords</div>';

      // Category index
      if (cards.category_index) {
        html += '<div style="color:' + p.amber + ';font-size:10px;margin-top:8px;margin-bottom:4px;">CATEGORIES</div>';
        for (var cat in cards.category_index) {
          var agents = cards.category_index[cat];
          html += '<div style="margin-left:8px;margin-bottom:2px;">';
          html += '<span style="color:' + p.cyan + ';">' + cat + '</span>';
          html += '<span style="color:' + p.gray + ';"> (' + agents.length + '): </span>';
          html += '<span style="color:' + p.text + ';">' + agents.join(', ') + '</span>';
          html += '</div>';
        }
      }

      // Dependency graph
      if (cards.dependency_graph) {
        html += '<div style="color:' + p.amber + ';font-size:10px;margin-top:8px;margin-bottom:4px;">DEPENDENCIES</div>';
        for (var agentId in cards.dependency_graph) {
          var deps = cards.dependency_graph[agentId];
          if (deps.length > 0) {
            html += '<div style="margin-left:8px;margin-bottom:2px;">';
            html += '<span style="color:' + p.green + ';">' + agentId + '</span>';
            html += '<span style="color:' + p.gray + ';"> → </span>';
            html += '<span style="color:' + p.text + ';">' + deps.join(', ') + '</span>';
            html += '</div>';
          }
        }
      }

      // Messages
      var totalMessages = 0;
      for (var inbox in messages) {
        totalMessages += messages[inbox].length;
      }

      html += '<div style="color:' + p.amber + ';font-size:10px;margin-top:8px;margin-bottom:4px;">MESSAGES (' + totalMessages + ')</div>';
      if (totalMessages === 0) {
        html += '<div style="margin-left:8px;color:' + p.gray + ';">No pending messages</div>';
      } else {
        for (var agentInbox in messages) {
          var msgs = messages[agentInbox];
          for (var mi = 0; mi < msgs.length; mi++) {
            var msg = msgs[mi];
            var typeColor = msg.type === 'delegation' ? p.amber : msg.type === 'task_response' ? p.green : p.cyan;
            html += '<div style="margin-left:8px;margin-bottom:3px;padding:3px;border-left:2px solid ' + typeColor + ';">';
            html += '<span style="color:' + typeColor + ';">[' + msg.type + ']</span> ';
            html += '<span style="color:' + p.text + ';">' + msg.from_agent + ' → ' + msg.to_agent + '</span>';
            if (msg.payload && msg.payload.action) {
              html += '<div style="margin-left:12px;color:' + p.gray + ';">' + msg.payload.action + '</div>';
            }
            html += '</div>';
          }
        }
      }

      html += '</div>';

      // Use the panel element directly
      if (panel.innerHTML !== undefined) {
        panel.innerHTML = html;
      }
    }

    setLiveActivity(agents) {
      if (this.villageMode && DataBridge.initialized) {
        var prevCount = DataBridge.entities.length;
        DataBridge.applyLiveActivity(agents);
        // Relayout if new dynamic entities were added
        if (DataBridge.entities.length !== prevCount) {
          this._villageLayout();
        }
        // Move active entities toward workspace
        if (ZoneLayout.workspace) {
          var ws = ZoneLayout.workspace;
          var active = DataBridge.getActiveEntities();
          var n = active.length;
          for (var ai = 0; ai < n; ai++) {
            var wsCx = ws.x + ws.w / 2;
            var radius = Math.max(20, n * 10);
            var angle = (ai / Math.max(1, n)) * Math.PI * 2 - Math.PI / 2;
            active[ai].targetX = wsCx + Math.cos(angle) * radius - 6;
            active[ai].targetY = ws.y + ws.h / 2 + Math.sin(angle) * Math.min(radius, ws.h / 3);
          }
        }
      }
    }

    setMode(mode) {
      this.mode = mode;
      if (mode === 'roster' && this.rosterPanel) {
        this.rosterPanel.update(this._rosterData);
      } else if (mode === 'metrics' && this.metricsPanel) {
        this.metricsPanel.update(this._metricsData);
      } else if (mode === 'train' && this.trainPanel) {
        this.trainPanel.update(this._trainData || {});
      } else if (mode === 'a2a') {
        this._renderA2APanel();
      } else if (mode === 'live' && this.taskPanel) {
        this.taskPanel.update(this._lastData || {});
      }
    }

    setRenderMode(mode) {
      this.renderMode = mode; // 'village' | 'neural'
      if (mode === 'neural') {
        this._initNeural();
      }
    }

    _initNeural() {
      if (!window.NeuralRenderer) return;
      if (!this._neuralRenderer) {
        this._neuralRenderer = new window.NeuralRenderer();
      }
      if (DataBridge.initialized && !this._neuralRenderer.initialized) {
        this._neuralRenderer.init(
          DataBridge.entities,
          ZoneLayout._catOrder,
          ZoneLayout._catColors,
          activeTheme.id
        );
        this._neuralRenderer.resize(this.canvas.width, this.canvas.height);
      }
    }

    _tickNeural(ctx, dt) {
      if (!this._neuralRenderer || !this._neuralRenderer.initialized) {
        this._initNeural();
        if (!this._neuralRenderer || !this._neuralRenderer.initialized) {
          // Not ready yet — draw void
          ctx.fillStyle = '#020305';
          ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
          return;
        }
      }
      this._neuralRenderer.tick(ctx, dt);
    }

    setTrainData(data) {
      this._trainData = data;
      if (this.mode === 'train' && this.trainPanel) {
        this.trainPanel.update(data);
      }
    }

    setSearchFilter(query) {
      this._searchQuery = (query || '').toLowerCase().trim();
      if (!this.villageMode || !DataBridge.initialized) return;
      var entities = DataBridge.entities;
      for (var i = 0; i < entities.length; i++) {
        var e = entities[i];
        if (!this._searchQuery) {
          // Clear filter — restore from SLEEP to IDLE if not active
          if (e.state === STATE.SLEEP && !e.isActive) {
            e.state = STATE.IDLE;
          }
          e._searchMatch = false;
        } else {
          var haystack = (e.name + ' ' + e.category + ' ' + e.project + ' ' + (e.description || '')).toLowerCase();
          if (haystack.indexOf(this._searchQuery) >= 0) {
            e._searchMatch = true;
            if (!e.isActive && e.state === STATE.SLEEP) e.state = STATE.IDLE;
          } else {
            e._searchMatch = false;
            if (!e.isActive) e.state = STATE.SLEEP;
          }
        }
      }
    }

    _buildCollabGroups(activeEntities) {
      // Group active entities that share the same task or are all working together
      // Returns array of arrays: [[entity, entity], [entity], ...]
      if (!activeEntities || activeEntities.length < 2) return [];

      var groups = [];
      var assigned = {};

      // Group by shared task text (if non-empty and matching)
      var taskMap = {};
      for (var i = 0; i < activeEntities.length; i++) {
        var e = activeEntities[i];
        if (e.currentTask && e.state === STATE.WORKING) {
          // Normalize task key: first 20 chars lowercase
          var tkey = e.currentTask.substring(0, 20).toLowerCase().replace(/\s+/g, ' ');
          if (!taskMap[tkey]) taskMap[tkey] = [];
          taskMap[tkey].push(e);
        }
      }

      for (var tk in taskMap) {
        if (!taskMap.hasOwnProperty(tk)) continue;
        if (taskMap[tk].length >= 2) {
          groups.push(taskMap[tk]);
          for (var j = 0; j < taskMap[tk].length; j++) {
            assigned[taskMap[tk][j].name] = true;
            taskMap[tk][j].collaborationGroup = groups.length - 1;
          }
        }
      }

      // All remaining WORKING entities without a shared task → single collab group
      var remaining = [];
      for (var r = 0; r < activeEntities.length; r++) {
        if (!assigned[activeEntities[r].name] && activeEntities[r].state === STATE.WORKING) {
          remaining.push(activeEntities[r]);
        }
      }
      if (remaining.length >= 2) {
        groups.push(remaining);
        for (var ri = 0; ri < remaining.length; ri++) {
          remaining[ri].collaborationGroup = groups.length - 1;
        }
      }

      return groups;
    }

    _villageLayout() {
      if (!DataBridge.initialized) return;
      var entities = DataBridge.entities;
      ZoneLayout.compute(entities, this.canvas.width, this.canvas.height);
      this.scale = ZoneLayout.scale;
      this._villageLayoutDone = true;
    }

    _layout() {
      const n = this.robots.length;
      const cw = this.canvas.width;
      const ch = this.canvas.height;
      const sz = getSpriteSize();

      const maxCols = Math.min(n, Math.max(2, Math.floor(cw / 80)));
      const rows = Math.ceil(n / maxCols);
      const cols = Math.min(n, maxCols);

      const maxSpriteW = cw / (cols + 0.5);
      this.scale = Math.max(2, Math.min(4, Math.floor(maxSpriteW / sz.w)));
      const spriteW = sz.w * this.scale;
      const spriteH = sz.h * this.scale;

      const headerH = 30;
      const labelH = 20;
      const spacingX = Math.floor((cw - cols * spriteW) / (cols + 1));
      const spacingY = Math.floor((ch - headerH - rows * (spriteH + labelH)) / (rows + 1));

      for (let i = 0; i < this.robots.length; i++) {
        const row = Math.floor(i / cols);
        const col = i % cols;
        const gx = spacingX + col * (spriteW + spacingX);
        const gy = headerH + spacingY + row * (spriteH + labelH + spacingY);
        this.robots[i].gridX = gx;
        this.robots[i].gridY = gy;
        this.robots[i].targetX = gx;
        this.robots[i].targetY = gy;
        if (this.robots[i].x === 0 && this.robots[i].y === 0) {
          this.robots[i].x = gx;
          this.robots[i].y = gy;
        }
      }
    }

    _buildCollaborations() {
      // Union-find for clustering
      const n = this.robots.length;
      const parent = Array.from({ length: n }, (_, i) => i);
      function find(i) { while (parent[i] !== i) { parent[i] = parent[parent[i]]; i = parent[i]; } return i; }
      function union(a, b) { parent[find(a)] = find(b); }

      for (let i = 0; i < n; i++) {
        for (let j = i + 1; j < n; j++) {
          const a = this.robots[i];
          const b = this.robots[j];

          // Shared files
          if (a.filesModified.length > 0 && b.filesModified.length > 0) {
            if (a.filesModified.some(f => b.filesModified.includes(f))) {
              union(i, j);
              continue;
            }
          }
          // Both working
          if (a.state === STATE.WORKING && b.state === STATE.WORKING) {
            union(i, j);
          }
        }
      }

      // Group by root
      const groups = {};
      for (let i = 0; i < n; i++) {
        const root = find(i);
        if (!groups[root]) groups[root] = [];
        groups[root].push(this.robots[i]);
      }

      // Build clusters (only groups of 2+)
      const newClusters = [];
      const clusterKeys = {};
      for (const robots of Object.values(groups)) {
        if (robots.length < 2) {
          // Reset to grid position
          for (const r of robots) { r.targetX = r.gridX; r.targetY = r.gridY; r.clusterId = -1; }
          continue;
        }
        const key = robots.map(r => r.domain).sort().join('+');
        clusterKeys[key] = true;

        // Stability: require 2 consecutive cycles
        this._clusterStability[key] = (this._clusterStability[key] || 0) + 1;
        if (this._clusterStability[key] < 2) {
          for (const r of robots) { r.targetX = r.gridX; r.targetY = r.gridY; r.clusterId = -1; }
          continue;
        }

        // Reuse existing cluster or create new
        let cluster = this.clusters.find(c => c.robots.map(r => r.domain).sort().join('+') === key);
        if (!cluster) cluster = new Cluster(robots);
        else cluster.robots = robots;

        const cid = newClusters.length;
        for (const r of robots) r.clusterId = cid;
        newClusters.push(cluster);
      }

      // Decay stability for keys not seen this cycle
      for (const key of Object.keys(this._clusterStability)) {
        if (!clusterKeys[key]) {
          this._clusterStability[key] = Math.max(0, this._clusterStability[key] - 1);
        }
      }

      this.clusters = newClusters;
    }

    _drawBackground() {
      const c = this.ctx;
      const p = P();
      const w = this.canvas.width;
      const h = this.canvas.height;

      c.fillStyle = p.bg;
      c.fillRect(0, 0, w, h);
      c.fillStyle = p.grid;
      for (let x = 0; x < w; x += 8) c.fillRect(x, 0, 1, h);
      for (let y = 0; y < h; y += 8) c.fillRect(0, y, w, 1);
      c.fillStyle = 'rgba(0,0,0,0.04)';
      for (let y = 0; y < h; y += 2) c.fillRect(0, y, w, 1);
    }

    _drawHeader() {
      const ctx = this.ctx;
      const p = P();
      const w = this.canvas.width;
      const s = Math.max(1, Math.floor(this.scale / 2));

      // Debug: show entity count + village mode status
      var debugInfo = 'V:' + (this.villageMode ? '1' : '0') + ' E:' + (DataBridge.initialized ? DataBridge.entities.length : '?') + ' R:' + (this._rosterData ? '1' : '0');
      drawText(ctx, activeTheme.headerTitle, 4, 4, p.green, s);
      drawText(ctx, debugInfo, 4, 4 + 7 * s + 7, '#ff6600', Math.max(1, s - 1));

      const stateColor = this.sessionState === 'running' ? p.cyan
        : this.sessionState === 'done' ? p.green
        : this.sessionState === 'stopped' ? p.red : p.amber;
      const stateLabel = this.sessionState.toUpperCase();
      drawText(ctx, stateLabel, w - textWidth(stateLabel, s) - 4, 4, stateColor, s);

      if (this.objective) {
        drawText(ctx, this.objective.substring(0, 50), 4, 4 + 7 * s, p.gray, Math.max(1, s - 1));
      }

      ctx.fillStyle = p.border;
      ctx.fillRect(0, 26, w, 1);
    }

    tick(timestamp) {
      if (!this.running) return;

      // FPS cap — skip frame if too soon
      var elapsed = timestamp - this._lastFrameTime;
      if (elapsed < this._frameInterval) {
        requestAnimationFrame((t) => this.tick(t));
        return;
      }
      this._lastFrameTime = timestamp;

      const dt = this.lastTime ? Math.min((timestamp - this.lastTime) / 1000, 0.1) : 0.016;
      this.lastTime = timestamp;

      // ── NEURAL MODE ──
      if (this.renderMode === 'neural' && DataBridge.initialized) {
        this._tickNeural(this.ctx, dt);
        requestAnimationFrame((t) => this.tick(t));
        return;
      }

      // ── VILLAGE MODE ──
      if (this.villageMode && DataBridge.initialized) {
        var entities = DataBridge.entities;
        var p = P();
        var ctx = this.ctx;
        var scale = this.scale;

        // Update all entities
        for (var vi = 0; vi < entities.length; vi++) entities[vi].update(dt);

        // Hit test
        InteractionManager.hitTest(entities, scale);

        // Render background + zones
        this._drawBackground();
        this._drawHeader();
        ZoneLayout.drawZones(ctx);

        // ── Collaboration links: draw lines between active agents sharing a task ──
        var active = DataBridge.getActiveEntities();
        if (active.length >= 2) {
          // Group active entities by collaboration (same current task or all WORKING)
          var collabGroups = this._buildCollabGroups(active);
          for (var cg = 0; cg < collabGroups.length; cg++) {
            var group = collabGroups[cg];
            if (group.length < 2) continue;

            // Draw glow circle around group centroid
            var cx = 0, cy = 0;
            for (var gi = 0; gi < group.length; gi++) { cx += group[gi].x; cy += group[gi].y; }
            cx /= group.length; cy /= group.length;
            var radius = Math.max(20, group.length * 12);

            ctx.save();
            ctx.globalAlpha = 0.06;
            ctx.fillStyle = p.green;
            ctx.beginPath();
            ctx.arc(Math.floor(cx + 6), Math.floor(cy + 6), radius, 0, Math.PI * 2);
            ctx.fill();
            ctx.restore();

            // Draw solid lines between all pairs — schematic links
            ctx.save();
            ctx.globalAlpha = 0.6;
            ctx.strokeStyle = '#ffffff';
            ctx.lineWidth = 2;
            for (var li = 0; li < group.length; li++) {
              for (var lj = li + 1; lj < group.length; lj++) {
                var ax = Math.floor(group[li].x + 4 * scale);
                var ay = Math.floor(group[li].y + 6 * scale);
                var bx = Math.floor(group[lj].x + 4 * scale);
                var by = Math.floor(group[lj].y + 6 * scale);
                ctx.beginPath();
                ctx.moveTo(ax, ay);
                ctx.lineTo(bx, by);
                ctx.stroke();
                // Small dot at each endpoint
                ctx.fillStyle = p.cyan;
                ctx.globalAlpha = 0.8;
                ctx.fillRect(ax - 2, ay - 2, 4, 4);
                ctx.fillRect(bx - 2, by - 2, 4, 4);
                ctx.globalAlpha = 0.6;
              }
            }
            ctx.restore();

            // Collaboration label — show shared task name or "COLLAB"
            var collabLabel = 'COLLAB';
            if (group[0] && group[0].currentTask) {
              collabLabel = group[0].currentTask.substring(0, 20).toUpperCase();
            }
            // Pulse alpha on collaboration circle
            var pulseAlpha = 0.5 + 0.3 * Math.sin(Date.now() / 400);
            ctx.save();
            ctx.globalAlpha = pulseAlpha * 0.12;
            ctx.fillStyle = p.cyan;
            ctx.beginPath();
            ctx.arc(Math.floor(cx + 6), Math.floor(cy + 6), radius * 0.7, 0, Math.PI * 2);
            ctx.fill();
            ctx.restore();
            var clw = textWidth(collabLabel, 1);
            drawText(ctx, collabLabel, Math.floor(cx + 6 - clw / 2), Math.floor(cy - 12), p.cyan, 1);
          }
        }

        // Draw entities z-sorted by Y
        var sorted = entities.slice().sort(function(a, b) { return a.y - b.y; });
        for (var si = 0; si < sorted.length; si++) {
          sorted[si].draw(ctx, scale);
        }

        // Activity bubbles (for WORKING/ERROR entities not hovered)
        InteractionManager.drawActivityBubbles(ctx, entities, scale);

        // Tooltip for hovered or pinned entity
        var tooltipTarget = InteractionManager.pinnedEntity || InteractionManager.hoveredEntity;
        if (tooltipTarget) {
          InteractionManager.drawTooltip(ctx, tooltipTarget, scale, this.canvas.width, this.canvas.height);
        }

        // Entity count in footer
        var countLabel = entities.length + ' AGENTS';
        if (active.length > 0) countLabel += ' / ' + active.length + ' ACTIVE';
        drawText(ctx, countLabel, 4, this.canvas.height - 8, p.gray, 1);

        requestAnimationFrame((t) => this.tick(t));
        return;
      }

      // ── V3 MODE (fallback) ──
      for (const cluster of this.clusters) cluster.update(dt);
      for (const robot of this.robots) robot.update(dt);

      this._drawBackground();
      this._drawHeader();

      for (const cluster of this.clusters) cluster.draw(this.ctx, this.scale);

      const sortedRobots = [...this.robots].sort((a, b) => a.y - b.y);
      for (const robot of sortedRobots) {
        robot.draw(this.ctx, this.scale);
        drawBubble(this.ctx, robot, this.scale);
      }

      if (this.robots.length === 1 && this.robots[0].domain === 'system') {
        const p2 = P();
        const msg = 'WAITING FOR AUTODEV...';
        const ms = Math.max(1, Math.floor(this.scale / 2));
        drawText(this.ctx, msg, (this.canvas.width - textWidth(msg, ms)) / 2, this.canvas.height - 20, p2.gray, ms);
      }

      requestAnimationFrame((t) => this.tick(t));
    }

    start() {
      if (this.running) return;
      this.running = true;
      this.lastTime = 0;
      requestAnimationFrame((t) => this.tick(t));
    }

    stop() { this.running = false; }

    resize(width, height) {
      const dpr = window.devicePixelRatio || 1;
      this.canvas.width = Math.floor(width * dpr);
      this.canvas.height = Math.floor(height * dpr);
      this.canvas.style.width = width + 'px';
      this.canvas.style.height = height + 'px';
      this.ctx.imageSmoothingEnabled = false;

      // Adaptive FPS: smaller canvas = lower target
      this._targetFPS = (width < 400) ? 20 : 30;
      this._frameInterval = 1000 / this._targetFPS;

      if (this._neuralRenderer) {
        this._neuralRenderer.resize(this.canvas.width, this.canvas.height);
      }
      if (this.villageMode && DataBridge.initialized) {
        this._villageLayout();
      } else if (this.robots.length > 0) {
        this._layout();
      }
    }
  }

  // ── EXPORT ──
  window.RobotMonitor = {
    THEMES, Scene, Robot, Cluster, ParticleSystem, TaskPanel, RosterPanel, MetricsPanel, TrainPanel,
    SpriteFactory, AgentEntity, ZoneLayout, InteractionManager, DataBridge,
    drawText, textWidth, STATE, STATE_NAMES, setTheme,
    getTheme: function () { return activeTheme; },
  };
})();
