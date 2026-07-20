/*
 * Poolrooms — Backrooms Level 37, Three.js, mobile-first.
 * ---------------------------------------------------------------------------
 * This module is CONCATENATED after `vendor/three.module.js` by `build.py`,
 * so every Three.js export (Scene, PerspectiveCamera, Vector3, ...) is already
 * in module scope and referenced here by its bare name. There is no `import`
 * on purpose — that keeps the built `index.html` a single self-contained
 * <script type="module"> with zero network dependencies (works under the
 * strict Artifact CSP, on GitHub Pages, on Vercel, or from a local server).
 *
 * Gameplay: wade through an endless liminal pool complex, collect 5 bottles of
 * almond water, then reach the emergency exit — while an entity stalks you.
 */
'use strict';

const { PI, sin, cos, min, max, abs, sqrt, floor, ceil, round, hypot, atan2, sign } = Math;
const TAU = PI * 2;
const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
const lerp = (a, b, t) => a + (b - a) * t;

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------
const CFG = {
  grid: 16,          // maze is grid x grid cells
  cell: 6.0,         // world units per cell
  wallH: 4.2,        // wall / room height
  wallT: 0.5,        // wall thickness
  eye: 1.62,         // camera eye height
  waterY: 0.14,      // shallow water surface height
  toCollect: 5,      // almond-water bottles to win
  walkSpeed: 3.3,
  sprintSpeed: 6.0,
  playerRadius: 0.42,
  entitySpeed: 2.55,
  entityChase: 4.35,
  entitySight: 22.0, // detection range with line of sight
  entityCatch: 1.15,
};

// Aquamarine poolrooms palette
const COL = {
  fog: new Color(0x74bcb8),
  tileLight: new Color(0xeef3ee),
  tileGrout: new Color(0x7fb8b0),
  water: new Color(0x0f9aa6),
  caustic: new Color(0x8ff2ea),
  sky: new Color(0xdff3ef),
  ground: new Color(0x2b5b58),
  bottle: new Color(0xf3f7ff),
  exit: new Color(0x7CFFB0),
  entity: new Color(0xf5f8ff),
};

// ---------------------------------------------------------------------------
// Seeded RNG (mulberry32) — a fresh seed each run gives a new layout
// ---------------------------------------------------------------------------
function makeRNG(seed) {
  let a = seed >>> 0;
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// ---------------------------------------------------------------------------
// Procedural textures (canvas → CanvasTexture). No external image files.
// ---------------------------------------------------------------------------
function mkCanvas(s) {
  const c = document.createElement('canvas');
  c.width = c.height = s;
  return c;
}

function tileAlbedo() {
  const S = 512, c = mkCanvas(S), x = c.getContext('2d');
  x.fillStyle = '#7fb0aa'; x.fillRect(0, 0, S, S);           // grout
  const n = 4, gap = 6, t = (S - gap * (n + 1)) / n;
  for (let i = 0; i < n; i++) for (let j = 0; j < n; j++) {
    const px = gap + i * (t + gap), py = gap + j * (t + gap);
    const shade = 226 + ((i * 7 + j * 13) % 18);
    const g = x.createLinearGradient(px, py, px + t, py + t);
    g.addColorStop(0, `rgb(${shade},${shade + 6},${shade})`);
    g.addColorStop(1, `rgb(${shade - 18},${shade - 10},${shade - 14})`);
    x.fillStyle = g; x.fillRect(px, py, t, t);
    // subtle stains
    x.fillStyle = `rgba(90,140,130,${0.05 + ((i + j) % 3) * 0.03})`;
    x.beginPath();
    x.arc(px + t * (0.3 + 0.4 * ((i * 3 + j) % 5) / 5), py + t * 0.6, t * 0.4, 0, TAU);
    x.fill();
  }
  const tex = new CanvasTexture(c);
  tex.wrapS = tex.wrapT = RepeatWrapping;
  tex.colorSpace = SRGBColorSpace;
  tex.anisotropy = 8;
  return tex;
}

function tileNormal() {
  const S = 512, c = mkCanvas(S), x = c.getContext('2d');
  x.fillStyle = '#8080ff'; x.fillRect(0, 0, S, S);
  const n = 4, gap = 6, t = (S - gap * (n + 1)) / n;
  // carve grooves at grout lines by shading normals sideways
  x.strokeStyle = '#8080ff';
  for (let i = 0; i <= n; i++) {
    const p = gap * 0.5 + i * (t + gap);
    const gl = x.createLinearGradient(p - gap, 0, p + gap, 0);
    gl.addColorStop(0, '#a0a0ff'); gl.addColorStop(0.5, '#8080ff'); gl.addColorStop(1, '#6060ff');
    x.fillStyle = gl; x.fillRect(p - gap, 0, gap * 2, S);
    const gv = x.createLinearGradient(0, p - gap, 0, p + gap);
    gv.addColorStop(0, '#8080a0'.replace('a0', 'a0')); // vertical variation
    x.fillStyle = 'rgba(128,128,255,0)';
  }
  // vertical grooves
  for (let j = 0; j <= n; j++) {
    const p = gap * 0.5 + j * (t + gap);
    const gv = x.createLinearGradient(0, p - gap, 0, p + gap);
    gv.addColorStop(0, '#80a0ff'); gv.addColorStop(0.5, '#8080ff'); gv.addColorStop(1, '#8060ff');
    x.fillStyle = gv; x.fillRect(0, p - gap, S, gap * 2);
  }
  const tex = new CanvasTexture(c);
  tex.wrapS = tex.wrapT = RepeatWrapping;
  tex.anisotropy = 8;
  return tex;
}

function roughMap() {
  const S = 256, c = mkCanvas(S), x = c.getContext('2d');
  x.fillStyle = '#4a4a4a'; x.fillRect(0, 0, S, S);
  for (let i = 0; i < 800; i++) {
    const a = 0.02 + Math.random() * 0.08;
    x.fillStyle = `rgba(${Math.random() < 0.5 ? 20 : 200},0,0,${a})`;
    x.beginPath();
    x.arc(Math.random() * S, Math.random() * S, 4 + Math.random() * 30, 0, TAU);
    x.fill();
  }
  const tex = new CanvasTexture(c);
  tex.wrapS = tex.wrapT = RepeatWrapping;
  return tex;
}

// Animated-looking caustics baked into one tiling texture (scrolled at runtime).
function causticTex() {
  const S = 512, c = mkCanvas(S), x = c.getContext('2d');
  x.fillStyle = '#000'; x.fillRect(0, 0, S, S);
  const rng = makeRNG(1337);
  x.globalCompositeOperation = 'lighter';
  for (let k = 0; k < 44; k++) {
    const cx = rng() * S, cy = rng() * S, r = 30 + rng() * 90;
    const g = x.createRadialGradient(cx, cy, 0, cx, cy, r);
    const a = 0.18 + rng() * 0.22;
    g.addColorStop(0, `rgba(180,255,245,${a})`);
    g.addColorStop(0.5, `rgba(120,240,230,${a * 0.4})`);
    g.addColorStop(1, 'rgba(0,0,0,0)');
    x.fillStyle = g; x.beginPath(); x.arc(cx, cy, r, 0, TAU); x.fill();
    // wrap copies so tiling stays seamless
    for (const [ox, oy] of [[S, 0], [-S, 0], [0, S], [0, -S]]) {
      const g2 = x.createRadialGradient(cx + ox, cy + oy, 0, cx + ox, cy + oy, r);
      g2.addColorStop(0, `rgba(180,255,245,${a})`);
      g2.addColorStop(1, 'rgba(0,0,0,0)');
      x.fillStyle = g2; x.beginPath(); x.arc(cx + ox, cy + oy, r, 0, TAU); x.fill();
    }
  }
  const tex = new CanvasTexture(c);
  tex.wrapS = tex.wrapT = RepeatWrapping;
  return tex;
}

function waterNormal() {
  const S = 256, c = mkCanvas(S), x = c.getContext('2d');
  x.fillStyle = '#8080ff'; x.fillRect(0, 0, S, S);
  const rng = makeRNG(77);
  x.globalCompositeOperation = 'lighter';
  for (let k = 0; k < 60; k++) {
    const cx = rng() * S, cy = rng() * S, r = 20 + rng() * 50;
    const ang = rng() * TAU;
    const nx = 128 + cos(ang) * 90, ny = 128 + sin(ang) * 90;
    const g = x.createRadialGradient(cx, cy, 0, cx, cy, r);
    g.addColorStop(0, `rgba(${nx | 0},${ny | 0},255,0.5)`);
    g.addColorStop(1, 'rgba(128,128,255,0)');
    x.fillStyle = g; x.beginPath(); x.arc(cx, cy, r, 0, TAU); x.fill();
  }
  const tex = new CanvasTexture(c);
  tex.wrapS = tex.wrapT = RepeatWrapping;
  return tex;
}

// Simple gradient env for reflections on wet tiles + water.
function envTexture(renderer) {
  const S = 256, c = mkCanvas(S * 2), x = c.getContext('2d');
  c.height = S;
  const g = x.createLinearGradient(0, 0, 0, S);
  g.addColorStop(0.0, '#e8f6f1');
  g.addColorStop(0.45, '#bfe6df');
  g.addColorStop(0.5, '#a7d8d2');
  g.addColorStop(0.55, '#6fb2ad');
  g.addColorStop(1.0, '#3d6d69');
  x.fillStyle = g; x.fillRect(0, 0, S * 2, S);
  const tex = new CanvasTexture(c);
  tex.mapping = EquirectangularReflectionMapping;
  tex.colorSpace = SRGBColorSpace;
  const pmrem = new PMREMGenerator(renderer);
  const env = pmrem.fromEquirectangular(tex).texture;
  pmrem.dispose();
  tex.dispose();
  return env;
}

// ---------------------------------------------------------------------------
// The game
// ---------------------------------------------------------------------------
class Poolrooms {
  constructor(canvas) {
    this.canvas = canvas;
    this.state = 'menu'; // menu | play | won | lost
    this.quality = 2;    // 2 = full, 1 = medium, 0 = low (adaptive)
    this.collected = 0;
    this.walls = [];     // AABBs {x0,z0,x1,z1}
    this.bottles = [];
    this.clock = new Clock();
    this.tmp = new Vector3();
    this.raycaster = new Raycaster();

    this._initRenderer();
    this._initScene();
    this._initPost();
    this._initInput();
    this.audio = new AudioEngine();

    this.newRun();
    window.addEventListener('resize', () => this.resize());
    this.resize();
  }

  // ---- renderer / scene -------------------------------------------------
  _initRenderer() {
    const r = new WebGLRenderer({ canvas: this.canvas, antialias: true, powerPreference: 'high-performance' });
    r.setPixelRatio(min(window.devicePixelRatio || 1, 2));
    // Manual color pipeline: keep scene linear, tonemap+encode in the final pass.
    r.toneMapping = NoToneMapping;
    r.outputColorSpace = LinearSRGBColorSpace;
    r.shadowMap.enabled = false;
    this.renderer = r;
    this.dpr = r.getPixelRatio();
  }

  _initScene() {
    const scene = new Scene();
    scene.background = COL.fog.clone();
    scene.fog = new FogExp2(COL.fog.getHex(), 0.058);
    this.scene = scene;

    this.camera = new PerspectiveCamera(74, 1, 0.05, 200);
    this.yaw = 0; this.pitch = 0;
    this.pos = new Vector3(0, CFG.eye, 0);
    this.vel = new Vector3();

    // lights — bright, sourceless
    scene.add(new HemisphereLight(COL.sky.getHex(), COL.ground.getHex(), 0.82));
    const key = new DirectionalLight(0xffffff, 0.5);
    key.position.set(0.4, 1, 0.2);
    scene.add(key);
    this.playerLight = new PointLight(0xbdeee8, 0.6, 18, 1.6);
    scene.add(this.playerLight);

    // reflections
    this.scene.environment = envTexture(this.renderer);

    // shared textures / materials
    this._buildMaterials();
  }

  _buildMaterials() {
    const rep = CFG.cell / 3;
    this.texCaustic = causticTex();
    this.texWaterN = waterNormal();

    const alb = tileAlbedo(), nrm = tileNormal(), rgh = roughMap();

    this.matWall = new MeshStandardMaterial({
      map: alb, normalMap: nrm, roughnessMap: rgh,
      color: 0xe6efe8, metalness: 0.05, roughness: 0.62,
      envMapIntensity: 0.55,
    });
    this.matWall.map.repeat.set(1, CFG.wallH / CFG.cell);
    this.matWall.normalMap.repeat.copy(this.matWall.map.repeat);

    this.matFloor = new MeshStandardMaterial({
      map: alb.clone(), normalMap: nrm.clone(), roughnessMap: rgh,
      color: 0xcfe4de, metalness: 0.1, roughness: 0.22,
      emissiveMap: this.texCaustic, emissive: COL.caustic, emissiveIntensity: 0.3,
      envMapIntensity: 0.9,
    });
    this.matFloor.map.wrapS = this.matFloor.map.wrapT = RepeatWrapping;
    this.matFloor.map.repeat.set(0.5, 0.5);
    this.matFloor.emissiveMap.repeat.set(0.4, 0.4);

    this.matCeil = new MeshStandardMaterial({
      map: alb.clone(), color: 0xd4e6e1, metalness: 0.0, roughness: 0.8,
      emissiveMap: this.texCaustic.clone(), emissive: COL.caustic, emissiveIntensity: 0.18,
    });
    this.matCeil.map.repeat.set(0.5, 0.5);
    this.matCeil.emissiveMap.repeat.set(0.3, 0.3);

    this.matPillar = new MeshStandardMaterial({
      map: alb.clone(), normalMap: nrm.clone(), color: 0xf3f7f2,
      metalness: 0.05, roughness: 0.55, envMapIntensity: 0.5,
    });
    this.matPillar.map.repeat.set(1, CFG.wallH / 2);

    this.matWater = new MeshStandardMaterial({
      color: COL.water, transparent: true, opacity: 0.8,
      metalness: 0.85, roughness: 0.08,
      normalMap: this.texWaterN, normalScale: new Vector2(0.55, 0.55),
      emissiveMap: this.texCaustic.clone(), emissive: COL.caustic, emissiveIntensity: 0.5,
      envMapIntensity: 1.5, depthWrite: false,
    });
    this.matWater.normalMap.repeat.set(CFG.grid * 1.5, CFG.grid * 1.5);
    this.matWater.emissiveMap.repeat.set(CFG.grid * 0.5, CFG.grid * 0.5);
  }

  // ---- level generation -------------------------------------------------
  newRun() {
    // wipe previous geometry
    if (this.levelGroup) { this.scene.remove(this.levelGroup); disposeGroup(this.levelGroup); }
    this.levelGroup = new Group();
    this.scene.add(this.levelGroup);
    this.walls.length = 0;
    this.bottles.length = 0;
    this.collected = 0;

    const seed = (Date.now() ^ (performance.now() * 1000)) >>> 0;
    const rng = makeRNG(seed);
    const N = CFG.grid, C = CFG.cell;

    // --- maze via randomized DFS, then braid for open pool rooms ---
    const NB = 1, EB = 2, SB = 4, WB = 8;
    const g = Array.from({ length: N }, () => new Array(N).fill(NB | EB | SB | WB));
    const vis = Array.from({ length: N }, () => new Array(N).fill(false));
    const stack = [[0, 0]]; vis[0][0] = true;
    const dirs = [[0, -1, NB, SB], [1, 0, EB, WB], [0, 1, SB, NB], [-1, 0, WB, EB]];
    while (stack.length) {
      const [ci, cj] = stack[stack.length - 1];
      const opts = [];
      for (const [di, dj, a, b] of dirs) {
        const ni = ci + di, nj = cj + dj;
        if (ni >= 0 && ni < N && nj >= 0 && nj < N && !vis[ni][nj]) opts.push([ni, nj, a, b]);
      }
      if (!opts.length) { stack.pop(); continue; }
      const [ni, nj, a, b] = opts[(rng() * opts.length) | 0];
      g[ci][cj] &= ~a; g[ni][nj] &= ~b; vis[ni][nj] = true; stack.push([ni, nj]);
    }
    // braid: remove ~45% of interior walls to make it open & loopy
    for (let i = 0; i < N; i++) for (let j = 0; j < N; j++) {
      if (i < N - 1 && (g[i][j] & EB) && rng() < 0.45) { g[i][j] &= ~EB; g[i + 1][j] &= ~WB; }
      if (j < N - 1 && (g[i][j] & SB) && rng() < 0.45) { g[i][j] &= ~SB; g[i][j + 1] &= ~NB; }
    }

    const cx = i => (i - (N - 1) / 2) * C; // cell center world coord
    this.cellToWorld = (i, j) => new Vector3(cx(i), 0, cx(j));

    // --- floor (with caustics) + water + ceiling (single big planes) ---
    const span = N * C;
    const floor = new Mesh(new PlaneGeometry(span, span), this.matFloor);
    floor.rotation.x = -PI / 2; this.levelGroup.add(floor);

    const water = new Mesh(new PlaneGeometry(span, span), this.matWater);
    water.rotation.x = -PI / 2; water.position.y = CFG.waterY; water.renderOrder = 2;
    this.water = water; this.levelGroup.add(water);

    const ceil = new Mesh(new PlaneGeometry(span, span), this.matCeil);
    ceil.rotation.x = PI / 2; ceil.position.y = CFG.wallH; this.levelGroup.add(ceil);

    // --- walls (InstancedMesh) ---
    const wallGeo = new BoxGeometry(1, CFG.wallH, 1);
    const segs = [];
    const addWall = (x, y, z, sx, sz) => {
      segs.push({ x, y, z, sx, sz });
      const hx = sx / 2 + CFG.playerRadius * 0, hz = sz / 2;
      this.walls.push({ x0: x - sx / 2, z0: z - sz / 2, x1: x + sx / 2, z1: z + sz / 2 });
    };
    const T = CFG.wallT;
    for (let i = 0; i < N; i++) for (let j = 0; j < N; j++) {
      const wx = cx(i), wz = cx(j);
      if (g[i][j] & EB) addWall(wx + C / 2, CFG.wallH / 2, wz, T, C + T);
      if (g[i][j] & SB) addWall(wx, CFG.wallH / 2, wz + C / 2, C + T, T);
      if (i === 0 && (g[i][j] & WB)) addWall(wx - C / 2, CFG.wallH / 2, wz, T, C + T);
      if (j === 0 && (g[i][j] & NB)) addWall(wx, CFG.wallH / 2, wz - C / 2, C + T, T);
    }
    const wm = new InstancedMesh(wallGeo, this.matWall, segs.length);
    const m4 = new Matrix4();
    segs.forEach((s, k) => { m4.makeScale(s.sx, 1, s.sz); m4.setPosition(s.x, s.y, s.z); wm.setMatrixAt(k, m4); });
    wm.instanceMatrix.needsUpdate = true; this.levelGroup.add(wm);

    // --- decorative columns at grid intersections (InstancedMesh) ---
    const pillars = [];
    for (let i = 0; i <= N; i++) for (let j = 0; j <= N; j++) {
      if (rng() < 0.4) pillars.push([(i - N / 2) * C, (j - N / 2) * C]);
    }
    const pGeo = new CylinderGeometry(0.42, 0.5, CFG.wallH, 12);
    const pm = new InstancedMesh(pGeo, this.matPillar, pillars.length);
    pillars.forEach(([px, pz], k) => {
      m4.makeTranslation(px, CFG.wallH / 2, pz); pm.setMatrixAt(k, m4);
      this.walls.push({ x0: px - 0.5, z0: pz - 0.5, x1: px + 0.5, z1: pz + 0.5 });
    });
    pm.instanceMatrix.needsUpdate = true; this.levelGroup.add(pm);

    // --- player spawn (center-ish) ---
    this.pos.set(cx(1) + 0.01, CFG.eye, cx(1) + 0.01);
    this.yaw = rng() * TAU; this.pitch = 0;

    // --- bottles: pick cells far from spawn ---
    const cells = [];
    for (let i = 0; i < N; i++) for (let j = 0; j < N; j++) cells.push([i, j]);
    shuffle(cells, rng);
    const spawnCell = [1, 1];
    const far = cells.filter(([i, j]) => hypot(i - spawnCell[0], j - spawnCell[1]) > N * 0.28);
    for (let k = 0; k < CFG.toCollect; k++) {
      const [i, j] = far[k];
      const p = this.cellToWorld(i, j); p.y = 1.0;
      this.bottles.push(this._makeBottle(p));
    }

    // --- exit door (far corner) ---
    const exitCell = far[far.length - 1];
    this.exitPos = this.cellToWorld(exitCell[0], exitCell[1]);
    this.exit = this._makeExit(this.exitPos);

    // --- entity ---
    this.entity = this._makeEntity(this.cellToWorld((N - 2), (N - 2)));

    this._updateHUD();
    this._syncCamera();
  }

  _makeBottle(p) {
    const grp = new Group(); grp.position.copy(p);
    const body = new Mesh(new CylinderGeometry(0.13, 0.13, 0.42, 12),
      new MeshStandardMaterial({ color: COL.bottle, transparent: true, opacity: 0.5, metalness: 0.1, roughness: 0.05, envMapIntensity: 1.5 }));
    const water = new Mesh(new CylinderGeometry(0.115, 0.115, 0.3, 12),
      new MeshStandardMaterial({ color: 0xeae6d0, emissive: 0xd8d2a8, emissiveIntensity: 0.6, roughness: 0.4 }));
    water.position.y = -0.05;
    const cap = new Mesh(new CylinderGeometry(0.07, 0.07, 0.12, 10),
      new MeshStandardMaterial({ color: 0x88e0d8, emissive: 0x2fbfc6, emissiveIntensity: 1.2 }));
    cap.position.y = 0.27;
    const glow = new PointLight(0x9ff2ea, 0.9, 5, 2); grp.add(glow);
    grp.add(body, water, cap);
    grp.userData = { taken: false, spin: Math.random() * TAU };
    this.levelGroup.add(grp);
    return grp;
  }

  _makeExit(p) {
    const grp = new Group(); grp.position.copy(p);
    const frameMat = new MeshStandardMaterial({ color: 0x223b35, metalness: 0.6, roughness: 0.3, emissive: 0x000000 });
    const door = new Mesh(new BoxGeometry(1.6, 3.0, 0.2),
      new MeshStandardMaterial({ color: 0x0c1a18, emissive: COL.exit, emissiveIntensity: 0.0, metalness: 0.2, roughness: 0.5 }));
    door.position.y = 1.5;
    const frameT = new Mesh(new BoxGeometry(2.0, 0.25, 0.3), frameMat); frameT.position.y = 3.05;
    const frameL = new Mesh(new BoxGeometry(0.25, 3.2, 0.3), frameMat); frameL.position.set(-0.9, 1.6, 0);
    const frameR = frameL.clone(); frameR.position.x = 0.9;
    const light = new PointLight(COL.exit.getHex(), 0.0, 8, 2); light.position.y = 2.2;
    grp.add(door, frameT, frameL, frameR, light);
    grp.userData = { door, light, unlocked: false };
    this.levelGroup.add(grp);
    return grp;
  }

  _makeEntity(p) {
    const grp = new Group(); grp.position.copy(p);
    const mat = new MeshStandardMaterial({ color: COL.entity, emissive: 0xbfe6e0, emissiveIntensity: 0.35, roughness: 0.9, metalness: 0.0, transparent: true, opacity: 0.92 });
    const body = new Mesh(new CapsuleGeometry(0.34, 1.5, 6, 12), mat); body.position.y = 1.15;
    const head = new Mesh(new SphereGeometry(0.28, 16, 16), mat); head.position.y = 2.15;
    grp.add(body, head);
    grp.userData = {
      mode: 'wander', target: p.clone(), speed: CFG.entitySpeed,
      repick: 0, bob: 0,
    };
    grp.position.y = 0;
    this.levelGroup.add(grp);
    return grp;
  }

  // ---- post processing (bright→blur→composite bloom + grade) ------------
  _initPost() {
    const q = new PlaneGeometry(2, 2);
    const vert = `varying vec2 vUv; void main(){ vUv = uv; gl_Position = vec4(position.xy, 0.0, 1.0); }`;
    this.postCam = new OrthographicCamera(-1, 1, 1, -1, 0, 1);
    this.postScene = new Scene();
    this.quad = new Mesh(q, null);
    this.postScene.add(this.quad);

    this.matBright = new ShaderMaterial({
      uniforms: { tDiffuse: { value: null }, threshold: { value: 0.9 } },
      vertexShader: vert, toneMapped: false,
      fragmentShader: `
        uniform sampler2D tDiffuse; uniform float threshold; varying vec2 vUv;
        void main(){ vec3 c = texture2D(tDiffuse, vUv).rgb;
          float l = dot(c, vec3(0.2126,0.7152,0.0722));
          float k = max(0.0, l - threshold);
          gl_FragColor = vec4(c * (k / max(l, 1e-4)), 1.0); }`,
    });
    this.matBlur = new ShaderMaterial({
      uniforms: { tDiffuse: { value: null }, dir: { value: new Vector2() }, texel: { value: new Vector2() } },
      vertexShader: vert, toneMapped: false,
      fragmentShader: `
        uniform sampler2D tDiffuse; uniform vec2 dir; uniform vec2 texel; varying vec2 vUv;
        void main(){
          vec2 o = dir * texel;
          vec3 s = texture2D(tDiffuse, vUv).rgb * 0.227027;
          s += texture2D(tDiffuse, vUv + o*1.3846).rgb * 0.316216;
          s += texture2D(tDiffuse, vUv - o*1.3846).rgb * 0.316216;
          s += texture2D(tDiffuse, vUv + o*3.2308).rgb * 0.070270;
          s += texture2D(tDiffuse, vUv - o*3.2308).rgb * 0.070270;
          gl_FragColor = vec4(s, 1.0); }`,
    });
    this.matFinal = new ShaderMaterial({
      uniforms: {
        tScene: { value: null }, tBloom: { value: null },
        bloomStrength: { value: 0.85 }, time: { value: 0 },
        grain: { value: 0.06 }, vignette: { value: 1.0 },
        dread: { value: 0.0 }, res: { value: new Vector2() },
      },
      vertexShader: vert, toneMapped: false,
      fragmentShader: `
        uniform sampler2D tScene; uniform sampler2D tBloom;
        uniform float bloomStrength, time, grain, vignette, dread; uniform vec2 res;
        varying vec2 vUv;
        vec3 aces(vec3 x){ return clamp((x*(2.51*x+0.03))/(x*(2.43*x+0.59)+0.14),0.0,1.0); }
        float hash(vec2 p){ p = fract(p*vec2(123.34,456.21)); p += dot(p,p+45.32); return fract(p.x*p.y); }
        void main(){
          vec2 uv = vUv; vec2 d = uv - 0.5; float r2 = dot(d,d);
          float ca = (0.0012 + 0.006*r2) * (1.0 + dread*2.0);
          vec3 col;
          col.r = texture2D(tScene, uv + d*ca).r;
          col.g = texture2D(tScene, uv).g;
          col.b = texture2D(tScene, uv - d*ca).b;
          col += texture2D(tBloom, uv).rgb * bloomStrength;
          col *= 0.82;                              // exposure
          col = aces(col);
          col = (col - 0.5) * 1.11 + 0.5;           // contrast
          float sat = dot(col, vec3(0.299,0.587,0.114));
          col = mix(vec3(sat), col, 1.14);          // saturation
          // teal grade + dread desaturate
          float lum = dot(col, vec3(0.299,0.587,0.114));
          col = mix(col, vec3(lum)*vec3(0.72,0.95,0.95), dread*0.6);
          float vig = smoothstep(0.92, 0.12, r2*1.7);
          col *= mix(1.0, vig, vignette*(0.55 + dread*0.4));
          float g = (hash(uv*res + fract(time)) - 0.5) * grain;
          col += g;
          col = pow(clamp(col,0.0,1.0), vec3(1.0/2.2));
          gl_FragColor = vec4(col, 1.0); }`,
    });
  }

  _allocTargets(w, h) {
    const opt = { type: HalfFloatType, depthBuffer: true };
    disposeRT(this.rtScene); disposeRT(this.rtA); disposeRT(this.rtB);
    this.rtScene = new WebGLRenderTarget(w, h, opt);
    const bw = max(1, w >> 1), bh = max(1, h >> 1);
    this.rtA = new WebGLRenderTarget(bw, bh, { type: HalfFloatType, depthBuffer: false });
    this.rtB = new WebGLRenderTarget(bw, bh, { type: HalfFloatType, depthBuffer: false });
    this.matFinal.uniforms.res.value.set(w, h);
    this.bloomTexel = new Vector2(1 / bw, 1 / bh);
  }

  _renderQuad(mat, target) {
    this.quad.material = mat;
    this.renderer.setRenderTarget(target || null);
    this.renderer.render(this.postScene, this.postCam);
  }

  render() {
    const r = this.renderer;
    r.setRenderTarget(this.rtScene);
    r.clear();
    r.render(this.scene, this.camera);

    if (this.quality >= 1) {
      // bright pass → rtA
      this.matBright.uniforms.tDiffuse.value = this.rtScene.texture;
      this._renderQuad(this.matBright, this.rtA);
      // blur H (rtA→rtB), blur V (rtB→rtA)
      this.matBlur.uniforms.texel.value.copy(this.bloomTexel);
      this.matBlur.uniforms.tDiffuse.value = this.rtA.texture;
      this.matBlur.uniforms.dir.value.set(1, 0);
      this._renderQuad(this.matBlur, this.rtB);
      this.matBlur.uniforms.tDiffuse.value = this.rtB.texture;
      this.matBlur.uniforms.dir.value.set(0, 1);
      this._renderQuad(this.matBlur, this.rtA);
      this.matFinal.uniforms.tBloom.value = this.rtA.texture;
      this.matFinal.uniforms.bloomStrength.value = this.quality >= 2 ? 0.6 : 0.42;
    } else {
      this.matFinal.uniforms.tBloom.value = this.rtScene.texture;
      this.matFinal.uniforms.bloomStrength.value = 0.0;
    }
    this.matFinal.uniforms.grain.value = this.quality >= 2 ? 0.06 : 0.03;
    this.matFinal.uniforms.tScene.value = this.rtScene.texture;
    this._renderQuad(this.matFinal, null);
  }

  // ---- input ------------------------------------------------------------
  _initInput() {
    this.keys = {};
    this.look = { x: 0, y: 0 };     // look-drag delta (accumulated per frame)
    this.move = { x: 0, y: 0 };     // joystick vector -1..1
    this.sprintHeld = false;
    this.isTouch = ('ontouchstart' in window) || navigator.maxTouchPoints > 0;

    // keyboard
    addEventListener('keydown', e => {
      this.keys[e.code] = true;
      if (e.code === 'ShiftLeft' || e.code === 'ShiftRight') this.sprintHeld = true;
      if (e.code === 'KeyE') this._tryInteract();
    });
    addEventListener('keyup', e => {
      this.keys[e.code] = false;
      if (e.code === 'ShiftLeft' || e.code === 'ShiftRight') this.sprintHeld = false;
    });

    // desktop mouse look via pointer lock
    this.canvas.addEventListener('click', () => {
      if (this.state === 'play' && !this.isTouch && document.pointerLockElement !== this.canvas)
        this.canvas.requestPointerLock?.();
    });
    addEventListener('mousemove', e => {
      if (document.pointerLockElement === this.canvas) {
        this.look.x += e.movementX; this.look.y += e.movementY;
      }
    });
  }

  bindTouch(ui) {
    this.ui = ui;
    // Joystick (left)
    const stick = ui.stick, knob = ui.knob;
    let sid = null, sc = { x: 0, y: 0 };
    const startStick = (id, x, y) => { sid = id; sc = { x, y }; stick.style.opacity = '1'; };
    const moveStick = (x, y) => {
      const dx = x - sc.x, dy = y - sc.y, R = 46;
      const len = hypot(dx, dy), cl = min(len, R);
      const ang = atan2(dy, dx);
      const kx = cos(ang) * cl, ky = sin(ang) * cl;
      knob.style.transform = `translate(${kx}px,${ky}px)`;
      this.move.x = (cos(ang) * cl) / R; this.move.y = (sin(ang) * cl) / R;
    };
    const endStick = () => { sid = null; this.move.x = this.move.y = 0; knob.style.transform = 'translate(0,0)'; stick.style.opacity = '0.55'; };

    // Look (right half) + buttons handled on the doc
    let lid = null, lx = 0, ly = 0;

    const onStart = e => {
      for (const t of e.changedTouches) {
        const leftZone = t.clientX < innerWidth * 0.5;
        if (leftZone && sid === null) {
          stick.style.left = t.clientX + 'px'; stick.style.top = t.clientY + 'px';
          startStick(t.identifier, t.clientX, t.clientY);
        } else if (!leftZone && lid === null) {
          lid = t.identifier; lx = t.clientX; ly = t.clientY;
        }
      }
    };
    const onMove = e => {
      for (const t of e.changedTouches) {
        if (t.identifier === sid) moveStick(t.clientX, t.clientY);
        else if (t.identifier === lid) {
          this.look.x += (t.clientX - lx) * 1.4; this.look.y += (t.clientY - ly) * 1.4;
          lx = t.clientX; ly = t.clientY;
        }
      }
      e.preventDefault();
    };
    const onEnd = e => {
      for (const t of e.changedTouches) {
        if (t.identifier === sid) endStick();
        else if (t.identifier === lid) lid = null;
      }
    };
    const surf = ui.touchSurface;
    surf.addEventListener('touchstart', onStart, { passive: false });
    surf.addEventListener('touchmove', onMove, { passive: false });
    surf.addEventListener('touchend', onEnd);
    surf.addEventListener('touchcancel', onEnd);

    // buttons
    const press = (el, on, off) => {
      el.addEventListener('touchstart', e => { e.preventDefault(); e.stopPropagation(); on(); }, { passive: false });
      el.addEventListener('touchend', e => { e.preventDefault(); e.stopPropagation(); off && off(); });
    };
    press(ui.sprintBtn, () => this.sprintHeld = true, () => this.sprintHeld = false);
    press(ui.actBtn, () => this._tryInteract());
  }

  // ---- gameplay update --------------------------------------------------
  _tryInteract() {
    if (this.state !== 'play') return;
    // manual pickup fallback (auto-pickup also runs each frame)
    this._checkBottles(1.8);
  }

  _syncCamera() {
    this.camera.position.copy(this.pos);
    this.camera.rotation.set(0, 0, 0);
    this.camera.rotateY(this.yaw);
    this.camera.rotateX(this.pitch);
  }

  _collide(px, pz, radius) {
    // circle vs AABB push-out against nearby walls
    let x = px, z = pz;
    for (const w of this.walls) {
      const cxp = clamp(x, w.x0, w.x1), czp = clamp(z, w.z0, w.z1);
      const dx = x - cxp, dz = z - czp;
      const d2 = dx * dx + dz * dz;
      if (d2 < radius * radius) {
        const d = sqrt(d2) || 0.0001;
        const push = (radius - d);
        x += (dx / d) * push; z += (dz / d) * push;
      }
    }
    return [x, z];
  }

  updatePlayer(dt) {
    // apply look
    const lookSpeed = this.isTouch ? 0.0016 : 0.0022;
    this.yaw -= this.look.x * lookSpeed;
    this.pitch -= this.look.y * lookSpeed;
    this.pitch = clamp(this.pitch, -1.3, 1.3);
    this.look.x = this.look.y = 0;

    // movement input
    let mx = 0, mz = 0;
    if (this.keys['KeyW'] || this.keys['ArrowUp']) mz -= 1;
    if (this.keys['KeyS'] || this.keys['ArrowDown']) mz += 1;
    if (this.keys['KeyA'] || this.keys['ArrowLeft']) mx -= 1;
    if (this.keys['KeyD'] || this.keys['ArrowRight']) mx += 1;
    mx += this.move.x; mz += this.move.y;
    const ml = hypot(mx, mz);
    if (ml > 1) { mx /= ml; mz /= ml; }

    // stamina + sprint
    const moving = ml > 0.05;
    const wantSprint = this.sprintHeld && moving && this.stamina > 0.05;
    if (wantSprint) this.stamina = max(0, this.stamina - dt * 0.35);
    else this.stamina = min(1, this.stamina + dt * 0.22);
    const speed = wantSprint ? CFG.sprintSpeed : CFG.walkSpeed;

    // to world space (yaw)
    const sinY = sin(this.yaw), cosY = cos(this.yaw);
    const wx = mx * cosY - mz * sinY;
    const wz = mx * sinY + mz * cosY;

    let nx = this.pos.x + wx * speed * dt;
    let nz = this.pos.z + wz * speed * dt;
    [nx, nz] = this._collide(nx, nz, CFG.playerRadius);
    // clamp to arena
    const lim = (CFG.grid * CFG.cell) / 2 - 0.6;
    nx = clamp(nx, -lim, lim); nz = clamp(nz, -lim, lim);

    // head bob + wade splash
    this.bobT = (this.bobT || 0) + dt * speed * (moving ? 1.4 : 0);
    const bob = moving ? sin(this.bobT * 2.2) * 0.035 : 0;
    this.pos.set(nx, CFG.eye + bob, nz);

    // wade sfx
    this._stepAccum = (this._stepAccum || 0) + (moving ? dt * speed : 0);
    if (this._stepAccum > 1.8) { this._stepAccum = 0; this.audio.splash(); }

    this.playerLight.position.set(nx, CFG.eye + 0.3, nz);
    this._syncCamera();
  }

  updateEntity(dt) {
    const e = this.entity, u = e.userData;
    const toP = this.tmp.set(this.pos.x - e.position.x, 0, this.pos.z - e.position.z);
    const dist = toP.length();
    const seen = dist < CFG.entitySight && !this._segBlocked(e.position.x, e.position.z, this.pos.x, this.pos.z);

    if (seen) { u.mode = 'chase'; }
    else if (u.mode === 'chase' && dist > CFG.entitySight * 1.3) { u.mode = 'wander'; }

    let tx, tz, spd;
    if (u.mode === 'chase') {
      tx = this.pos.x; tz = this.pos.z; spd = CFG.entityChase;
    } else {
      u.repick -= dt;
      if (u.repick <= 0 || (u.target.distanceTo(e.position) < 1.2)) {
        const N = CFG.grid;
        u.target = this.cellToWorld((Math.random() * N) | 0, (Math.random() * N) | 0);
        u.repick = 4 + Math.random() * 4;
      }
      tx = u.target.x; tz = u.target.z; spd = CFG.entitySpeed;
    }
    const dx = tx - e.position.x, dz = tz - e.position.z, dl = hypot(dx, dz) || 1;
    let nx = e.position.x + (dx / dl) * spd * dt;
    let nz = e.position.z + (dz / dl) * spd * dt;
    [nx, nz] = this._collide(nx, nz, 0.4);
    e.position.x = nx; e.position.z = nz;
    e.lookAt(this.pos.x, e.position.y + 2, this.pos.z);
    u.bob += dt * 3; e.children[0].position.y = 1.15 + sin(u.bob) * 0.04;

    // dread ramp by proximity
    const dread = clamp(1 - dist / 14, 0, 1) * (u.mode === 'chase' ? 1 : 0.5);
    this.dread = lerp(this.dread || 0, dread, 0.08);
    this.matFinal.uniforms.dread.value = this.dread;
    this.scene.fog.density = lerp(0.05, 0.10, this.dread);
    this.audio.setTension(this.dread, u.mode === 'chase');

    if (dist < CFG.entityCatch) this._lose();
  }

  _segBlocked(ax, az, bx, bz) {
    const steps = ceil(hypot(bx - ax, bz - az) / 0.5);
    for (let s = 1; s < steps; s++) {
      const t = s / steps, x = lerp(ax, bx, t), z = lerp(az, bz, t);
      for (const w of this.walls) {
        if (x > w.x0 - 0.1 && x < w.x1 + 0.1 && z > w.z0 - 0.1 && z < w.z1 + 0.1) return true;
      }
    }
    return false;
  }

  _checkBottles(range) {
    for (const b of this.bottles) {
      if (b.userData.taken) continue;
      const d = hypot(b.position.x - this.pos.x, b.position.z - this.pos.z);
      if (d < range) {
        b.userData.taken = true; b.visible = false;
        this.collected++; this.audio.collect();
        if (this.collected >= CFG.toCollect) this._unlockExit();
        this._updateHUD();
      }
    }
  }

  _unlockExit() {
    this.exit.userData.unlocked = true;
    this.exit.userData.door.material.emissiveIntensity = 1.4;
    this.exit.userData.light.intensity = 2.2;
    this.audio.chime();
  }

  updateItems(dt, t) {
    for (const b of this.bottles) {
      if (b.userData.taken) continue;
      b.rotation.y += dt * 1.2;
      b.position.y = 1.0 + sin(t * 2 + b.userData.spin) * 0.12;
    }
    // caustics scroll
    const off = t * 0.02;
    this.matFloor.emissiveMap.offset.set(off, off * 0.7);
    this.matFloor.emissiveIntensity = 0.28 + sin(t * 1.3) * 0.1;
    this.matCeil.emissiveMap.offset.set(-off * 0.6, off * 0.5);
    this.matWater.emissiveMap.offset.set(off * 0.8, -off * 0.5);
    this.matWater.emissiveIntensity = 0.45 + sin(t * 0.9 + 1) * 0.15;
    this.texWaterN.offset.set(t * 0.015, t * 0.01);
    this.water.material.normalMap.offset.copy(this.texWaterN.offset);

    this._checkBottles(1.5); // auto pickup
    // reach exit
    if (this.exit.userData.unlocked) {
      const d = hypot(this.exit.position.x - this.pos.x, this.exit.position.z - this.pos.z);
      if (d < 1.6) this._win();
    }
  }

  // ---- HUD / state ------------------------------------------------------
  _updateHUD() {
    if (!this.ui) return;
    this.ui.count.textContent = `${this.collected} / ${CFG.toCollect}`;
    this.ui.objective.textContent = this.collected >= CFG.toCollect
      ? 'ATTEINS LA SORTIE' : 'ALMOND WATER';
    // directional hint arrow toward nearest target
    const target = this.collected >= CFG.toCollect ? this.exit.position : this._nearestBottle();
    if (target) {
      const ang = atan2(target.x - this.pos.x, -(target.z - this.pos.z)) - this.yaw;
      this.ui.hint.style.transform = `rotate(${ang}rad)`;
      this.ui.hint.style.opacity = '0.8';
    } else this.ui.hint.style.opacity = '0';
  }

  _nearestBottle() {
    let best = null, bd = 1e9;
    for (const b of this.bottles) {
      if (b.userData.taken) continue;
      const d = hypot(b.position.x - this.pos.x, b.position.z - this.pos.z);
      if (d < bd) { bd = d; best = b.position; }
    }
    return best;
  }

  start() {
    this.state = 'play';
    this.stamina = 1;
    this.dread = 0;
    this.audio.resume();
    this.audio.startAmbient();
    if (this.ui) {
      this.ui.menu.classList.add('hidden');
      this.ui.hud.classList.remove('hidden');
      if (this.isTouch) this.ui.touchWrap.classList.remove('hidden');
    }
    if (!this.isTouch) this.canvas.requestPointerLock?.();
  }

  _win() {
    if (this.state !== 'play') return;
    this.state = 'won';
    this.audio.win();
    document.exitPointerLock?.();
    if (this.ui) this.ui.touchWrap.classList.add('hidden');
    if (this.ui) { this.ui.endTitle.textContent = 'TU T’ES ÉCHAPPÉ'; this.ui.endSub.textContent = 'Tu as trouvé la sortie de secours.'; this.ui.end.classList.remove('hidden'); this.ui.end.classList.add('win'); }
  }

  _lose() {
    if (this.state !== 'play') return;
    this.state = 'lost';
    this.audio.stinger();
    document.exitPointerLock?.();
    if (this.ui) this.ui.touchWrap.classList.add('hidden');
    if (this.ui) { this.ui.endTitle.textContent = 'ELLE T’A TROUVÉ'; this.ui.endSub.textContent = 'L’entité t’a rattrapé.'; this.ui.end.classList.remove('hidden', 'win'); }
  }

  restart() {
    this.newRun();
    if (this.ui) { this.ui.end.classList.add('hidden'); this.ui.hud.classList.remove('hidden'); }
    this.start();
  }

  // ---- adaptive quality + resize ---------------------------------------
  resize() {
    const w = innerWidth, h = innerHeight;
    this.renderer.setSize(w, h, false);
    this.camera.aspect = w / h; this.camera.updateProjectionMatrix();
    const pr = this.renderer.getPixelRatio();
    this._allocTargets(max(2, floor(w * pr)), max(2, floor(h * pr)));
  }

  _adapt(fps) {
    this._fpsAvg = this._fpsAvg ? lerp(this._fpsAvg, fps, 0.1) : fps;
    this._adaptT = (this._adaptT || 0) + 1;
    if (this._adaptT < 90) return; // wait ~1.5s between changes
    if (this._fpsAvg < 40 && this.quality > 0) { this.quality--; this._adaptT = 0; this._maybeLowerDPR(); }
    else if (this._fpsAvg < 30) { this._maybeLowerDPR(); this._adaptT = 0; }
    else if (this._fpsAvg > 57 && this.quality < 2) { this.quality++; this._adaptT = 0; }
  }

  _maybeLowerDPR() {
    const cur = this.renderer.getPixelRatio();
    if (cur > 1) { this.renderer.setPixelRatio(max(1, cur - 0.5)); this.resize(); }
  }

  // ---- main loop --------------------------------------------------------
  loop() {
    const dt = min(0.05, this.clock.getDelta());
    const t = this.clock.elapsedTime;
    this.matFinal.uniforms.time.value = t;

    if (this.state === 'play') {
      this.updatePlayer(dt);
      this.updateEntity(dt);
      this.updateItems(dt, t);
      this._updateHUD();
    } else {
      // idle caustic shimmer even in menu
      const off = t * 0.02;
      this.matFloor.emissiveMap.offset.set(off, off * 0.7);
      this.texWaterN.offset.set(t * 0.015, t * 0.01);
      this.water.material.normalMap.offset.copy(this.texWaterN.offset);
    }

    this.render();

    // fps sample
    const now = performance.now();
    if (this._lt) this._adapt(1000 / max(1, now - this._lt));
    this._lt = now;

    requestAnimationFrame(() => this.loop());
  }
}

// ---------------------------------------------------------------------------
// Procedural audio (WebAudio) — ambient drone, water, heartbeat, cues.
// ---------------------------------------------------------------------------
class AudioEngine {
  constructor() { this.ctx = null; this.ambient = false; }
  resume() {
    if (!this.ctx) {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) return;
      this.ctx = new AC();
      this.master = this.ctx.createGain(); this.master.gain.value = 0.5; this.master.connect(this.ctx.destination);
      this._reverb();
    }
    if (this.ctx.state === 'suspended') this.ctx.resume();
  }
  _reverb() {
    const c = this.ctx, len = c.sampleRate * 2.6;
    const buf = c.createBuffer(2, len, c.sampleRate);
    for (let ch = 0; ch < 2; ch++) {
      const d = buf.getChannelData(ch);
      for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, 2.4);
    }
    this.conv = c.createConvolver(); this.conv.buffer = buf;
    this.revGain = c.createGain(); this.revGain.gain.value = 0.5;
    this.conv.connect(this.revGain); this.revGain.connect(this.master);
  }
  _noise(dur) {
    const c = this.ctx, n = c.sampleRate * dur, b = c.createBuffer(1, n, c.sampleRate), d = b.getChannelData(0);
    for (let i = 0; i < n; i++) d[i] = Math.random() * 2 - 1;
    const s = c.createBufferSource(); s.buffer = b; return s;
  }
  startAmbient() {
    if (!this.ctx || this.ambient) return; this.ambient = true;
    const c = this.ctx;
    // low drone (two detuned oscillators)
    [55, 55.4, 82.5].forEach((f, i) => {
      const o = c.createOscillator(); o.type = 'sine'; o.frequency.value = f;
      const g = c.createGain(); g.gain.value = 0.05 - i * 0.01;
      o.connect(g); g.connect(this.master); g.connect(this.conv); o.start();
    });
    // filtered water hiss
    const src = this._noise(4); src.loop = true;
    const bp = c.createBiquadFilter(); bp.type = 'bandpass'; bp.frequency.value = 900; bp.Q.value = 0.6;
    const wg = c.createGain(); wg.gain.value = 0.02;
    src.connect(bp); bp.connect(wg); wg.connect(this.master); wg.connect(this.conv); src.start();
    // occasional drips
    this._dripTimer = setInterval(() => this.drip(), 1400);
    // tension layer (silent until entity near)
    this.tenGain = c.createGain(); this.tenGain.gain.value = 0;
    const to = c.createOscillator(); to.type = 'sawtooth'; to.frequency.value = 47;
    const tf = c.createBiquadFilter(); tf.type = 'lowpass'; tf.frequency.value = 200;
    to.connect(tf); tf.connect(this.tenGain); this.tenGain.connect(this.master); to.start();
  }
  setTension(x, chasing) {
    if (!this.ctx || !this.tenGain) return;
    this.tenGain.gain.setTargetAtTime(x * 0.12, this.ctx.currentTime, 0.3);
    // heartbeat when close
    if (x > 0.45) {
      const now = performance.now();
      const interval = chasing ? 380 : 620;
      if (!this._hb || now - this._hb > interval) { this._hb = now; this.heartbeat(); }
    }
  }
  _tone(f, dur, type, vol, toRev) {
    const c = this.ctx; if (!c) return;
    const o = c.createOscillator(); o.type = type || 'sine'; o.frequency.value = f;
    const g = c.createGain(); g.gain.value = 0;
    g.gain.linearRampToValueAtTime(vol, c.currentTime + 0.01);
    g.gain.exponentialRampToValueAtTime(0.0001, c.currentTime + dur);
    o.connect(g); g.connect(this.master); if (toRev) g.connect(this.conv);
    o.start(); o.stop(c.currentTime + dur + 0.05);
  }
  drip() { if (this.ctx) this._tone(1200 + Math.random() * 900, 0.18, 'sine', 0.05, true); }
  splash() {
    if (!this.ctx) return;
    const s = this._noise(0.25), bp = this.ctx.createBiquadFilter();
    bp.type = 'bandpass'; bp.frequency.value = 1400 + Math.random() * 600;
    const g = this.ctx.createGain(); g.gain.value = 0.08;
    g.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + 0.22);
    s.connect(bp); bp.connect(g); g.connect(this.master); s.start(); s.stop(this.ctx.currentTime + 0.26);
  }
  collect() { this._tone(880, 0.12, 'triangle', 0.12); setTimeout(() => this._tone(1320, 0.18, 'triangle', 0.12, true), 80); }
  chime() { [660, 990, 1320].forEach((f, i) => setTimeout(() => this._tone(f, 0.4, 'sine', 0.1, true), i * 120)); }
  heartbeat() { this._tone(60, 0.12, 'sine', 0.25); setTimeout(() => this._tone(50, 0.14, 'sine', 0.2), 130); }
  stinger() { this._tone(120, 0.6, 'sawtooth', 0.25, true); this._tone(90, 0.8, 'square', 0.15, true); }
  win() { [523, 659, 784, 1046].forEach((f, i) => setTimeout(() => this._tone(f, 0.5, 'sine', 0.12, true), i * 140)); }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function shuffle(a, rng) {
  for (let i = a.length - 1; i > 0; i--) { const j = (rng() * (i + 1)) | 0;[a[i], a[j]] = [a[j], a[i]]; }
  return a;
}
function disposeRT(rt) { if (rt) rt.dispose(); }
function disposeGroup(g) {
  g.traverse(o => {
    if (o.geometry) o.geometry.dispose();
    if (o.material) { const m = o.material; (Array.isArray(m) ? m : [m]).forEach(x => x.dispose && x.dispose()); }
  });
}

// ---------------------------------------------------------------------------
// Boot + UI wiring
// ---------------------------------------------------------------------------
function boot() {
  // mobile viewport safety (Artifact injects its own <head>)
  if (!document.querySelector('meta[name="viewport"]')) {
    const m = document.createElement('meta');
    m.name = 'viewport';
    m.content = 'width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover';
    document.head.appendChild(m);
  }

  const canvas = document.getElementById('gl');
  let game;
  try {
    game = new Poolrooms(canvas);
  } catch (err) {
    document.getElementById('fatal').textContent = 'WebGL error: ' + err.message;
    document.getElementById('fatal').style.display = 'flex';
    console.error(err);
    return;
  }
  window.__game = game;

  const $ = id => document.getElementById(id);
  const ui = {
    menu: $('menu'), hud: $('hud'), end: $('end'),
    count: $('count'), objective: $('objective'), hint: $('hint'),
    stick: $('stick'), knob: $('knob'), touchSurface: $('touch'), touchWrap: $('touchUI'),
    sprintBtn: $('sprintBtn'), actBtn: $('actBtn'),
    endTitle: $('endTitle'), endSub: $('endSub'),
  };
  game.bindTouch(ui);
  game.ui = ui;
  $('touchUI').classList.add('hidden'); // touch controls appear only during play
  if (!game.isTouch) {
    $('controlsHint').textContent = 'ZQSD / WASD pour marcher · souris pour regarder · Maj pour courir · E pour prendre';
  }

  $('startBtn').addEventListener('click', () => game.start());
  $('retryBtn').addEventListener('click', () => game.restart());

  game.loop();
}

if (document.readyState === 'loading') addEventListener('DOMContentLoaded', boot);
else boot();
