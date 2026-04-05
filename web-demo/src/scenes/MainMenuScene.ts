// ═══════════════════════════════════════════════════════════════════════════════
// Main Menu Scene — v3 — "Coastal Clifftop Path"
// Fixed camera overlooking a Celtic coastal path from above.
// N64 aesthetic: flatShading, vivid palette, low-poly geometry.
// Dynamic skybox: updates in real-time based on Europe/Paris local clock.
// ═══════════════════════════════════════════════════════════════════════════════

import {
  AmbientLight,
  BoxGeometry,
  BufferAttribute,
  BufferGeometry,
  Color,
  ConeGeometry,
  CylinderGeometry,
  DirectionalLight,
  DodecahedronGeometry,
  Float32BufferAttribute,
  FogExp2,
  Mesh,
  MeshBasicMaterial,
  MeshStandardMaterial,
  NoToneMapping,
  PerspectiveCamera,
  PlaneGeometry,
  PointLight,
  Points,
  PointsMaterial,
  Scene,
  SphereGeometry,
  Vector3,
  WebGLRenderer,
} from 'three';

// ── Camera positions ──────────────────────────────────────────────────────────
// Elevated cliff-top view looking down the path toward the sea and tower.

const CAM_START  = new Vector3(-1.5, 6.0, 17);
const CAM_END    = new Vector3( 4.5, 3.5,  2);
const LOOK_START = new Vector3(-1.0, 1.8, -5);
const LOOK_END   = new Vector3( 6.0, 2.0,-13);
const DOLLY_DURATION = 6;

function easeInOut(t: number): number {
  return t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
}

// ── Title overlay ─────────────────────────────────────────────────────────────

function buildTitleOverlay(): HTMLDivElement {
  const existing = document.getElementById('menu-title-overlay');
  if (existing) return existing as HTMLDivElement;
  const overlay = document.createElement('div');
  overlay.id = 'menu-title-overlay';
  overlay.style.cssText = [
    'position:absolute;top:0;left:0;width:100%;height:100%;',
    'pointer-events:none;z-index:10;',
    'display:flex;align-items:flex-start;justify-content:center;',
    'padding-top:13vh;',
  ].join('');
  const letters = 'M.E.R.L.I.N.'.split('');
  const wrapper = document.createElement('div');
  wrapper.style.cssText = 'display:flex;gap:0px;';
  letters.forEach((ch, i) => {
    const span = document.createElement('span');
    span.textContent = ch;
    span.style.cssText = [
      'color:#c8e8ff;font-family:\'Courier New\',monospace;',
      'font-size:clamp(28px,6vw,64px);font-weight:bold;letter-spacing:0.06em;',
      'opacity:0;transition:opacity 0.35s;text-shadow:0 0 18px rgba(170,210,255,0.55);',
    ].join('');
    setTimeout(() => { span.style.opacity = '1'; }, 200 + i * 120);
    wrapper.appendChild(span);
  });
  overlay.appendChild(wrapper);
  return overlay;
}

// ── Brittany time-of-day helpers ──────────────────────────────────────────────

function getBrittanyHour(): number {
  try {
    const parts = new Intl.DateTimeFormat('fr-FR', {
      timeZone: 'Europe/Paris',
      hour: 'numeric', minute: 'numeric', hour12: false,
    }).formatToParts(new Date());
    const h = parseInt(parts.find(p => p.type === 'hour')?.value   ?? '12');
    const m = parseInt(parts.find(p => p.type === 'minute')?.value ?? '0');
    return h + m / 60;
  } catch { return 12; }
}

function lerpCol(a: number, b: number, t: number): number {
  const ar = (a >> 16) & 0xff, ag = (a >> 8) & 0xff, ab = a & 0xff;
  const br = (b >> 16) & 0xff, bg = (b >> 8) & 0xff, bb = b & 0xff;
  return (
    (Math.round(ar + (br - ar) * t) << 16) |
    (Math.round(ag + (bg - ag) * t) << 8)  |
     Math.round(ab + (bb - ab) * t)
  );
}

interface TODParams {
  skyHex: number;
  fogDensity: number;
  ambientHex: number; ambientInt: number;
  dirHex: number;     dirInt: number;
  dirX: number;       dirY: number;     dirZ: number;
  showStars: boolean; showMoon: boolean; showSun: boolean;
  sunX: number;       sunY: number;
}

function getTimeOfDay(hour: number): TODParams {
  // Night 21h–5h
  if (hour >= 21 || hour < 5) return {
    skyHex: 0x04080f, fogDensity: 0.010,
    ambientHex: 0x0c1828, ambientInt: 0.50,
    dirHex: 0x90b8d8, dirInt: 0.65, dirX: 8, dirY: 20, dirZ: 5,
    showStars: true, showMoon: true, showSun: false, sunX: 0, sunY: 0,
  };
  // Pre-dawn 5h–7h
  if (hour < 7) {
    const t = (hour - 5) / 2;
    return {
      skyHex: lerpCol(0x04080f, 0x180c06, t), fogDensity: 0.009,
      ambientHex: 0x12101a, ambientInt: 0.30 + t * 0.20,
      dirHex: lerpCol(0x446688, 0xff7722, t), dirInt: 0.12 + t * 0.45,
      dirX: -13, dirY: 3 + t * 6, dirZ: -20,
      showStars: t < 0.55, showMoon: hour < 6.5, showSun: t > 0.4,
      sunX: -16, sunY: 2 + t * 5,
    };
  }
  // Morning 7h–10h
  if (hour < 10) {
    const t = (hour - 7) / 3;
    return {
      skyHex: lerpCol(0x180c06, 0x1a4c80, t), fogDensity: 0.009,
      ambientHex: lerpCol(0x1e1628, 0x304868, t), ambientInt: 0.50 + t * 0.36,
      dirHex: lerpCol(0xff9955, 0xfff5dc, t), dirInt: 0.60 + t * 0.55,
      dirX: -13 + t * 5, dirY: 8 + t * 12, dirZ: -28,
      showStars: false, showMoon: false, showSun: true,
      sunX: -13 + t * 6, sunY: 8 + t * 12,
    };
  }
  // Day 10h–17h
  if (hour < 17) {
    const arch = hour < 13.5 ? (hour - 10) / 3.5 : (17 - hour) / 3.5;
    const sunX = -4 + (hour - 10) * 2.5;
    const sunY = 16 + arch * 14;
    return {
      skyHex: 0x1a5eb8, fogDensity: 0.008,
      ambientHex: 0x40567a, ambientInt: 0.88,
      dirHex: 0xfff5dc, dirInt: 1.25,
      dirX: sunX, dirY: sunY, dirZ: -28,
      showStars: false, showMoon: false, showSun: true, sunX, sunY,
    };
  }
  // Dusk 17h–21h
  const t = (hour - 17) / 4;
  return {
    skyHex: lerpCol(0x1a5eb8, 0x04080f, t), fogDensity: 0.009,
    ambientHex: lerpCol(0x40567a, 0x0c1828, t), ambientInt: 0.88 - t * 0.38,
    dirHex: lerpCol(0xff7020, 0x90b8d8, t), dirInt: 1.25 - t * 0.90,
    dirX: 8 + t * 5, dirY: 18 - t * 15, dirZ: -25,
    showStars: t > 0.65, showMoon: t > 0.65, showSun: t < 0.60,
    sunX: 10 + t * 8, sunY: 18 - t * 16,
  };
}

// ── Terrain ───────────────────────────────────────────────────────────────────

function buildTerrain(): Mesh[] {
  const meshes: Mesh[] = [];

  // Cliff-top ground — grey-green coastal heath
  const groundGeo = new PlaneGeometry(80, 60, 20, 14);
  const pos = groundGeo.attributes['position'] as BufferAttribute;
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i);
    const z = pos.getZ(i);
    const offCenter = Math.abs(x) < 4 ? 0 : (Math.random() - 0.5) * 0.35;
    pos.setY(i, offCenter);
    void z;
  }
  groundGeo.computeVertexNormals();
  const groundMat = new MeshStandardMaterial({ color: 0x1a2814, roughness: 0.97, metalness: 0.0, flatShading: true });
  const ground = new Mesh(groundGeo, groundMat);
  ground.rotation.x = -Math.PI / 2;
  meshes.push(ground);

  // Cliff face — drops down to the sea on the left
  const cliffGeo = new PlaneGeometry(55, 7, 14, 4);
  const cliffPos = cliffGeo.attributes['position'] as BufferAttribute;
  for (let i = 0; i < cliffPos.count; i++) {
    cliffPos.setY(i, cliffPos.getY(i) + (Math.random() - 0.5) * 0.3);
  }
  cliffGeo.computeVertexNormals();
  const cliffMat = new MeshStandardMaterial({ color: 0x14201a, roughness: 0.98, metalness: 0.0, flatShading: true });
  const cliff = new Mesh(cliffGeo, cliffMat);
  cliff.position.set(-10, -2.5, -6);
  cliff.rotation.y = Math.PI * 0.06;
  meshes.push(cliff);

  return meshes;
}

// ── Stone path ────────────────────────────────────────────────────────────────

function buildStonePath(): Mesh[] {
  const meshes: Mesh[] = [];
  const slabMat = new MeshStandardMaterial({ color: 0x504035, roughness: 0.96, metalness: 0.0, flatShading: true });
  const slabs = 16;
  for (let i = 0; i < slabs; i++) {
    const t = i / (slabs - 1);
    const z = 17 - t * 30;
    const w = 1.1 + Math.random() * 0.7;
    const d = 0.7 + Math.random() * 0.5;
    const geo = new BoxGeometry(w, 0.13, d);
    const m = new Mesh(geo, slabMat);
    m.position.set((Math.random() - 0.5) * 0.6, 0.06 + Math.random() * 0.05, z);
    m.rotation.y = (Math.random() - 0.5) * 0.18;
    meshes.push(m);
  }
  // Side pebbles
  const pebbleMat = new MeshStandardMaterial({ color: 0x1a300f, roughness: 1.0, metalness: 0.0, flatShading: true });
  for (const [px, pz] of [[ 2.2, 14], [-2.0, 10], [2.5, 6], [-2.3, 2], [2.0, -2], [-2.5, -6]] as [number, number][]) {
    const geo = new BoxGeometry(0.4, 0.08, 0.3);
    const p = new Mesh(geo, pebbleMat);
    p.position.set(px, 0.04, pz);
    meshes.push(p);
  }
  return meshes;
}

// ── Ocean ─────────────────────────────────────────────────────────────────────

interface OceanData { mesh: Mesh; horizPlane: Mesh; baseY: Float32Array }

function buildOcean(): OceanData {
  const geo = new PlaneGeometry(70, 40, 22, 14);
  const posAttr = geo.attributes['position'] as BufferAttribute;
  const baseY = new Float32Array(posAttr.count);
  const cols = new Float32Array(posAttr.count * 3);
  for (let i = 0; i < posAttr.count; i++) {
    const z = posAttr.getZ(i);
    const t = Math.max(0, Math.min(1, (z + 20) / 40));
    cols[i * 3 + 0] = 0.04 + t * 0.02;
    cols[i * 3 + 1] = 0.28 + t * 0.55;
    cols[i * 3 + 2] = 0.62 + t * 0.09;
    baseY[i] = posAttr.getZ(i);
  }
  geo.setAttribute('color', new BufferAttribute(cols, 3));
  const mat = new MeshStandardMaterial({ vertexColors: true, flatShading: true, roughness: 0.55, metalness: 0.22 });
  const mesh = new Mesh(geo, mat);
  mesh.rotation.x = -Math.PI / 2;
  mesh.position.set(-14, -3.2, -18);

  const horizGeo = new PlaneGeometry(150, 50, 4, 4);
  const horizMat = new MeshStandardMaterial({ color: 0x074080, roughness: 0.7, metalness: 0.0, flatShading: true });
  const horizPlane = new Mesh(horizGeo, horizMat);
  horizPlane.rotation.x = -Math.PI / 2;
  horizPlane.position.set(0, -3.6, -55);

  return { mesh, horizPlane, baseY };
}

function updateOcean(ocean: OceanData, t: number): void {
  const geo = ocean.mesh.geometry as PlaneGeometry;
  const pos = geo.attributes['position'] as BufferAttribute;
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i);
    const z = ocean.baseY[i] ?? 0;
    pos.setY(i, Math.sin(t * 0.8 + x * 0.3 + z * 0.2) * 0.22
                + Math.sin(t * 1.1 + x * 0.5) * 0.11);
  }
  pos.needsUpdate = true;
  geo.computeVertexNormals();
}

// ── Tower / cabin ─────────────────────────────────────────────────────────────

interface TowerData { meshes: Mesh[]; windowLight: PointLight }

function buildTower(): TowerData {
  const meshes: Mesh[] = [];
  const stoneMat = new MeshStandardMaterial({ color: 0x242820, roughness: 0.94, metalness: 0.0, flatShading: true });
  const roofMat  = new MeshStandardMaterial({ color: 0x181d16, roughness: 0.92, metalness: 0.0, flatShading: true });
  const darkMat  = new MeshStandardMaterial({ color: 0x080806, roughness: 1.00, metalness: 0.0, flatShading: true });

  // Tower body
  const bodyGeo = new CylinderGeometry(1.8, 2.2, 13, 7);
  const body = new Mesh(bodyGeo, stoneMat);
  body.position.set(9, 6.5, -13);
  meshes.push(body);

  // Conical roof
  const roofGeo = new ConeGeometry(2.4, 3.2, 7);
  const roof = new Mesh(roofGeo, roofMat);
  roof.position.set(9, 14.1, -13);
  meshes.push(roof);

  // Door arch
  const doorGeo = new BoxGeometry(0.9, 1.8, 0.2);
  const door = new Mesh(doorGeo, darkMat);
  door.position.set(9, 0.9, -10.8);
  meshes.push(door);

  // Battlements
  for (let i = 0; i < 6; i++) {
    const angle = (i / 6) * Math.PI * 2;
    const bGeo = new BoxGeometry(0.55, 0.75, 0.55);
    const batt = new Mesh(bGeo, stoneMat);
    batt.position.set(9 + Math.sin(angle) * 1.9, 13.4, -13 + Math.cos(angle) * 1.9);
    meshes.push(batt);
  }

  // Warm window light
  const windowLight = new PointLight(0xffcc44, 2.0, 9);
  windowLight.position.set(9, 7.5, -11.5);

  return { meshes, windowLight };
}

// ── Rocks ─────────────────────────────────────────────────────────────────────

function buildRocks(): Mesh[] {
  const meshes: Mesh[] = [];
  const mat = new MeshStandardMaterial({ color: 0x1c1e18, roughness: 0.98, metalness: 0.0, flatShading: true });
  for (const [rx, ry, rz, s] of [
    [4, 0, 4, 1.1], [-4, 0, 8, 1.4], [5.5, 0, -1, 0.8],
    [-5, 0, 2, 1.0], [3.5, 0, -4, 0.7], [-3.5, 0, -2, 0.9],
  ] as [number, number, number, number][]) {
    const geo = new DodecahedronGeometry(s, 0);
    const m = new Mesh(geo, mat);
    m.position.set(rx, ry + s * 0.4, rz);
    m.rotation.y = Math.random() * Math.PI;
    meshes.push(m);
  }
  return meshes;
}

// ── Torch beside the path ─────────────────────────────────────────────────────

interface TorchData { meshes: Mesh[]; light: PointLight }

function buildTorch(): TorchData {
  const stickMat = new MeshStandardMaterial({ color: 0x3a1e0a, roughness: 0.95, metalness: 0.0, flatShading: true });
  const stickGeo = new CylinderGeometry(0.055, 0.075, 1.3, 5);
  const stick = new Mesh(stickGeo, stickMat);
  stick.position.set(2.2, 0.75, 8);

  const flameMat = new MeshBasicMaterial({ color: 0xff8833 });
  const flameGeo = new ConeGeometry(0.12, 0.28, 5);
  const flame = new Mesh(flameGeo, flameMat);
  flame.position.set(2.2, 1.54, 8);

  const light = new PointLight(0xff8833, 1.1, 7);
  light.position.set(2.2, 1.5, 8);

  return { meshes: [stick, flame], light };
}

// ── Ogham standing stone ──────────────────────────────────────────────────────

function buildOghamStone(): Mesh[] {
  const meshes: Mesh[] = [];
  const stoneMat = new MeshStandardMaterial({ color: 0x3c3028, roughness: 0.97, metalness: 0.0, flatShading: true });
  const runeMat  = new MeshStandardMaterial({
    color: 0x55ee88, roughness: 0.4, metalness: 0.0, flatShading: true,
    emissive: new Color(0x22bb55), emissiveIntensity: 0.55,
  });

  const slab = new Mesh(new BoxGeometry(0.44, 3.1, 0.22), stoneMat);
  slab.position.set(-3.2, 1.55, 5);
  slab.rotation.z = 0.05;
  meshes.push(slab);

  for (let n = 0; n < 5; n++) {
    const nw = 0.18 + Math.random() * 0.12;
    const notch = new Mesh(new BoxGeometry(nw, 0.06, 0.26), runeMat);
    notch.position.set(-3.06, 0.55 + n * 0.44, 5);
    meshes.push(notch);
  }

  const base = new Mesh(new BoxGeometry(0.78, 0.10, 0.48), stoneMat);
  base.position.set(-3.2, 0.05, 5);
  meshes.push(base);

  return meshes;
}

// ── Stars & celestial objects ─────────────────────────────────────────────────

function buildStars(): Points {
  const count = 220;
  const positions = new Float32Array(count * 3);
  for (let i = 0; i < count; i++) {
    const theta = Math.random() * Math.PI * 2;
    const phi   = Math.acos(2 * Math.random() - 1);
    const r     = 58 + Math.random() * 12;
    positions[i * 3 + 0] = r * Math.sin(phi) * Math.cos(theta);
    positions[i * 3 + 1] = Math.abs(r * Math.cos(phi)) + 6;
    positions[i * 3 + 2] = r * Math.sin(phi) * Math.sin(theta);
  }
  const geo = new BufferGeometry();
  geo.setAttribute('position', new Float32BufferAttribute(positions, 3));
  return new Points(geo, new PointsMaterial({ color: 0xaad4ff, size: 0.13, transparent: true, opacity: 0.75 }));
}

function buildMoon(): Mesh {
  const geo = new SphereGeometry(2.6, 8, 6);
  const mat = new MeshBasicMaterial({ color: 0xd8ead8 });
  const moon = new Mesh(geo, mat);
  moon.position.set(14, 22, -38);
  return moon;
}

function buildSun(): Mesh {
  const geo = new SphereGeometry(4.0, 8, 6);
  const mat = new MeshBasicMaterial({ color: 0xffffc0 });
  return new Mesh(geo, mat);
}

// ── Main export ───────────────────────────────────────────────────────────────

export function initMainMenu(container: HTMLElement): {
  renderer: WebGLRenderer;
  update: (dt: number) => void;
  startDolly: (onComplete: () => void) => void;
  dispose: () => void;
} {
  // ── Renderer ──────────────────────────────────────────────────────────────
  const renderer = new WebGLRenderer({ antialias: false, alpha: false });
  renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
  renderer.setSize(container.clientWidth || window.innerWidth, container.clientHeight || window.innerHeight);
  renderer.toneMapping = NoToneMapping;
  container.appendChild(renderer.domElement);

  // ── Initial time-of-day ───────────────────────────────────────────────────
  let tod = getTimeOfDay(getBrittanyHour());

  // ── Scene ─────────────────────────────────────────────────────────────────
  const scene = new Scene();
  scene.background = new Color(tod.skyHex);
  scene.fog = new FogExp2(tod.skyHex, tod.fogDensity);

  // ── Camera — truly fixed until dolly ─────────────────────────────────────
  const camera = new PerspectiveCamera(
    58,
    (container.clientWidth || window.innerWidth) / (container.clientHeight || window.innerHeight),
    0.1, 200,
  );
  camera.position.copy(CAM_START);
  camera.lookAt(LOOK_START);

  // ── Lighting ──────────────────────────────────────────────────────────────
  const ambientLight = new AmbientLight(tod.ambientHex, tod.ambientInt);
  scene.add(ambientLight);

  const dirLight = new DirectionalLight(tod.dirHex, tod.dirInt);
  dirLight.position.set(tod.dirX, tod.dirY, tod.dirZ);
  scene.add(dirLight);

  // ── Geometry ──────────────────────────────────────────────────────────────
  for (const m of buildTerrain())    scene.add(m);
  for (const m of buildStonePath())  scene.add(m);
  for (const m of buildRocks())      scene.add(m);
  for (const m of buildOghamStone()) scene.add(m);

  const ocean = buildOcean();
  scene.add(ocean.mesh);
  scene.add(ocean.horizPlane);

  const tower = buildTower();
  for (const m of tower.meshes) scene.add(m);
  scene.add(tower.windowLight);

  const torch = buildTorch();
  for (const m of torch.meshes) scene.add(m);
  scene.add(torch.light);

  // ── Celestial objects ─────────────────────────────────────────────────────
  const starsObj = buildStars();
  starsObj.visible = tod.showStars;
  scene.add(starsObj);

  const moonObj = buildMoon();
  moonObj.visible = tod.showMoon;
  scene.add(moonObj);

  const sunObj = buildSun();
  sunObj.visible = tod.showSun;
  sunObj.position.set(tod.sunX, tod.sunY, -40);
  scene.add(sunObj);

  // ── Title overlay ─────────────────────────────────────────────────────────
  const titleOverlay = buildTitleOverlay();
  container.appendChild(titleOverlay);

  // ── Resize ────────────────────────────────────────────────────────────────
  const onResize = (): void => {
    const w = container.clientWidth || window.innerWidth;
    const h = container.clientHeight || window.innerHeight;
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
    renderer.setSize(w, h);
  };
  window.addEventListener('resize', onResize);

  // ── State ─────────────────────────────────────────────────────────────────
  let dollyActive  = false;
  let dollyElapsed = 0;
  let dollyCallback: (() => void) | null = null;
  let elapsed = 0;
  const currentLookAt = LOOK_START.clone();

  // Sky refresh: recalculate every 60 s so the skybox tracks local time in real-time
  let skyRefreshTimer = 60;

  function applySkyTOD(t: TODParams): void {
    scene.background = new Color(t.skyHex);
    (scene.fog as FogExp2).color.set(t.skyHex);
    (scene.fog as FogExp2).density = t.fogDensity;
    ambientLight.color.set(t.ambientHex);
    ambientLight.intensity = t.ambientInt;
    dirLight.color.set(t.dirHex);
    dirLight.intensity = t.dirInt;
    dirLight.position.set(t.dirX, t.dirY, t.dirZ);
    starsObj.visible = t.showStars;
    moonObj.visible  = t.showMoon;
    sunObj.visible   = t.showSun;
    if (t.showSun) sunObj.position.set(t.sunX, t.sunY, -40);
  }

  // ── Update ────────────────────────────────────────────────────────────────
  const update = (dt: number): void => {
    elapsed += dt;

    // Real-time sky — refresh every 60 s from Europe/Paris clock
    skyRefreshTimer -= dt;
    if (skyRefreshTimer <= 0) {
      skyRefreshTimer = 60;
      tod = getTimeOfDay(getBrittanyHour());
      applySkyTOD(tod);
    }

    // Ocean waves
    updateOcean(ocean, elapsed);

    // Torch flicker
    torch.light.intensity = 1.1 + Math.sin(elapsed * 7.1) * 0.28 + Math.sin(elapsed * 13.3) * 0.10;

    // Tower window flicker
    tower.windowLight.intensity = 2.0 + Math.sin(elapsed * 5.8) * 0.45 + Math.sin(elapsed * 9.2) * 0.15;

    // Camera: fixed in idle, dolly when started
    if (dollyActive) {
      dollyElapsed += dt;
      const rawT = Math.min(dollyElapsed / DOLLY_DURATION, 1);
      const t = easeInOut(rawT);
      camera.position.lerpVectors(CAM_START, CAM_END, t);
      currentLookAt.lerpVectors(LOOK_START, LOOK_END, t);
      camera.lookAt(currentLookAt);
      if (rawT >= 1) {
        dollyActive = false;
        const cb = dollyCallback;
        dollyCallback = null;
        cb?.();
      }
    } else {
      // Truly fixed — no breathing, no animation
      camera.position.copy(CAM_START);
      camera.lookAt(LOOK_START);
    }

    renderer.render(scene, camera);
  };

  // ── startDolly ────────────────────────────────────────────────────────────
  const startDolly = (onComplete: () => void): void => {
    dollyActive  = true;
    dollyElapsed = 0;
    dollyCallback = onComplete;
  };

  // ── dispose ───────────────────────────────────────────────────────────────
  const dispose = (): void => {
    window.removeEventListener('resize', onResize);
    titleOverlay.remove();
    scene.traverse((obj) => {
      if (obj instanceof Mesh) {
        obj.geometry.dispose();
        if (Array.isArray(obj.material)) {
          obj.material.forEach((m) => m.dispose());
        } else {
          (obj.material as MeshStandardMaterial).dispose();
        }
      }
      if (obj instanceof Points) {
        obj.geometry.dispose();
        (obj.material as PointsMaterial).dispose();
      }
    });
    renderer.dispose();
    renderer.domElement.remove();
  };

  return { renderer, update, startDolly, dispose };
}
