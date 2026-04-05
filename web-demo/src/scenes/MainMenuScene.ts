// ═══════════════════════════════════════════════════════════════════════════════
// Main Menu Scene — Cycle 31 — "Path to coastal tower" rewrite
// Focused N64 vivid aesthetic: stone path, cliff, tower, ocean, starry sky.
// flatShading: true on ALL MeshStandardMaterial — key to the low-poly look.
// ═══════════════════════════════════════════════════════════════════════════════

import {
  AmbientLight,
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
  BoxGeometry,
} from 'three';

// ── Constants ─────────────────────────────────────────────────────────────────

const CAM_START = new Vector3(-1, 4.5, 19);
const CAM_END   = new Vector3(0, 3, -1);
const LOOK_START = new Vector3(0, 2, -8);
const LOOK_END   = new Vector3(0, 5, -15);
const DOLLY_DURATION = 6; // seconds

// ── Easing ────────────────────────────────────────────────────────────────────

function easeInOut(t: number): number {
  return t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
}

// ── Title overlay ─────────────────────────────────────────────────────────────

function buildTitleOverlay(): HTMLDivElement {
  if (document.getElementById('menu-title-overlay')) {
    return document.getElementById('menu-title-overlay') as HTMLDivElement;
  }
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

// ── Ocean ─────────────────────────────────────────────────────────────────────

interface OceanData {
  mesh: Mesh;
  horizonPlane: Mesh;
  baseY: Float32Array;
}

function buildOcean(): OceanData {
  const geo = new PlaneGeometry(80, 50, 24, 16);
  const posAttr = geo.attributes['position'] as BufferAttribute;
  const baseY = new Float32Array(posAttr.count);

  // Vertex colors: turquoise near shore → deep blue far
  const cols = new Float32Array(posAttr.count * 3);
  for (let i = 0; i < posAttr.count; i++) {
    const z = posAttr.getZ(i); // local Z before rotation
    const t = Math.max(0, Math.min(1, (z + 25) / 50)); // 0=far, 1=near
    cols[i * 3 + 0] = 0.039 + t * 0.024;   // R: deep→near
    cols[i * 3 + 1] = 0.282 + t * 0.550;   // G
    cols[i * 3 + 2] = 0.627 + t * 0.094;   // B
    baseY[i] = posAttr.getZ(i);
  }
  geo.setAttribute('color', new BufferAttribute(cols, 3));

  const mat = new MeshStandardMaterial({
    vertexColors: true,
    flatShading: true,
    roughness: 0.55,
    metalness: 0.22,
  });
  const mesh = new Mesh(geo, mat);
  mesh.rotation.x = -Math.PI / 2;
  mesh.position.set(-12, -3, -20);

  const horizGeo = new PlaneGeometry(160, 60, 4, 4);
  const horizMat = new MeshStandardMaterial({ color: 0x0848a0, flatShading: true, roughness: 0.7 });
  const horizonPlane = new Mesh(horizGeo, horizMat);
  horizonPlane.rotation.x = -Math.PI / 2;
  horizonPlane.position.set(0, -3.5, -55);

  return { mesh, horizonPlane, baseY };
}

function updateOcean(ocean: OceanData, t: number): void {
  const geo = ocean.mesh.geometry as PlaneGeometry;
  const pos = geo.attributes['position'] as BufferAttribute;
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i);
    const z = ocean.baseY[i] ?? 0;
    const wave = Math.sin(t * 0.8 + x * 0.3 + z * 0.2) * 0.22
               + Math.sin(t * 1.1 + x * 0.5) * 0.11;
    pos.setY(i, wave);
  }
  pos.needsUpdate = true;
  geo.computeVertexNormals();
}

// ── Terrain ───────────────────────────────────────────────────────────────────

function buildTerrain(): Mesh[] {
  const meshes: Mesh[] = [];

  // Main ground plane — low-poly grass/rock
  const groundGeo = new PlaneGeometry(80, 60, 20, 16);
  const posAttr = groundGeo.attributes['position'] as BufferAttribute;
  // Deform vertices slightly for low-poly look
  for (let i = 0; i < posAttr.count; i++) {
    const x = posAttr.getX(i);
    const z = posAttr.getZ(i);
    // Keep a corridor in the middle flat (path area: |x| < 3)
    const offCenter = Math.abs(x) < 3 ? 0 : (Math.random() - 0.5) * 0.4;
    posAttr.setY(i, offCenter);
    void z; // suppress unused warning
  }
  groundGeo.computeVertexNormals();
  const groundMat = new MeshStandardMaterial({ color: 0x1a2a1a, flatShading: true, roughness: 0.95 });
  const ground = new Mesh(groundGeo, groundMat);
  ground.rotation.x = -Math.PI / 2;
  ground.position.set(0, 0, 0);
  meshes.push(ground);

  // Cliff face — raide mur sombre
  const cliffGeo = new PlaneGeometry(60, 8, 12, 4);
  const cliffMat = new MeshStandardMaterial({ color: 0x151e15, flatShading: true, roughness: 0.98 });
  const cliff = new Mesh(cliffGeo, cliffMat);
  cliff.position.set(-10, -1.5, -9);
  cliff.rotation.y = Math.PI * 0.08;
  meshes.push(cliff);

  return meshes;
}

// ── Stone path ────────────────────────────────────────────────────────────────

function buildStonePath(): Mesh[] {
  const meshes: Mesh[] = [];
  const slabMat = new MeshStandardMaterial({ color: 0x484030, flatShading: true, roughness: 0.95 });

  const slabs = 15;
  for (let i = 0; i < slabs; i++) {
    const t = i / (slabs - 1); // 0=near, 1=far
    const z = 18 - t * 26;    // z from 18 to -8
    const w = 1.2 + Math.random() * 0.6;
    const d = 0.8 + Math.random() * 0.5;
    const xOff = (Math.random() - 0.5) * 0.8;
    const geo = new BoxGeometry(w, 0.12, d);
    const mesh = new Mesh(geo, slabMat);
    mesh.position.set(xOff, 0.05, z);
    // slight random rotation
    mesh.rotation.y = (Math.random() - 0.5) * 0.15;
    meshes.push(mesh);
  }

  // Side pebbles / low grass tufts
  const pebbleMat = new MeshStandardMaterial({ color: 0x1a3010, flatShading: true, roughness: 1.0 });
  const pebblePositions: Array<[number, number, number]> = [
    [2.2, 0.04, 14], [-2.0, 0.04, 10], [2.5, 0.04, 6],
    [-2.3, 0.04, 2], [2.0, 0.04, -2], [-2.5, 0.04, -5],
    [1.8, 0.04, 16], [-1.8, 0.04, -1],
  ];
  for (const [px, py, pz] of pebblePositions) {
    const geo = new BoxGeometry(0.4, 0.08, 0.3);
    const p = new Mesh(geo, pebbleMat);
    p.position.set(px, py, pz);
    meshes.push(p);
  }

  return meshes;
}

// ── Rocks ─────────────────────────────────────────────────────────────────────

function buildRocks(): Mesh[] {
  const meshes: Mesh[] = [];
  const rockMat = new MeshStandardMaterial({ color: 0x1a2218, flatShading: true, roughness: 0.98 });

  const positions: Array<[number, number, number, number]> = [
    [4.5, 0, 4, 1.2],
    [-4.2, 0, 8, 1.5],
    [5.0, 0, -1, 0.9],
    [-5.5, 0, 2, 1.1],
  ];
  for (const [rx, ry, rz, scale] of positions) {
    const geo = new DodecahedronGeometry(scale, 0);
    const m = new Mesh(geo, rockMat);
    m.position.set(rx, ry + scale * 0.4, rz);
    m.rotation.y = Math.random() * Math.PI;
    meshes.push(m);
  }

  return meshes;
}

// ── Coastal tower ─────────────────────────────────────────────────────────────

interface TowerData {
  meshes: Mesh[];
  windowLight: PointLight;
}

function buildTower(): TowerData {
  const meshes: Mesh[] = [];
  const stoneMat = new MeshStandardMaterial({ color: 0x252822, flatShading: true, roughness: 0.94 });
  const darkMat = new MeshStandardMaterial({ color: 0x0a0a08, flatShading: true, roughness: 1.0 });
  const roofMat = new MeshStandardMaterial({ color: 0x1a1f18, flatShading: true, roughness: 0.9 });

  // Body
  const bodyGeo = new CylinderGeometry(1.8, 2.2, 14, 7);
  const body = new Mesh(bodyGeo, stoneMat);
  body.position.set(0, 7, -14);
  meshes.push(body);

  // Conical roof
  const roofGeo = new ConeGeometry(2.4, 3.5, 7);
  const roof = new Mesh(roofGeo, roofMat);
  roof.position.set(0, 15.25, -14);
  meshes.push(roof);

  // Door
  const doorGeo = new BoxGeometry(0.8, 1.6, 0.2);
  const door = new Mesh(doorGeo, darkMat);
  door.position.set(0, 0.8, -11.8);
  meshes.push(door);

  // Battlements (6 small boxes around rim)
  const battMat = new MeshStandardMaterial({ color: 0x252822, flatShading: true, roughness: 0.94 });
  for (let i = 0; i < 6; i++) {
    const angle = (i / 6) * Math.PI * 2;
    const geo = new BoxGeometry(0.5, 0.7, 0.5);
    const batt = new Mesh(geo, battMat);
    batt.position.set(
      Math.sin(angle) * 1.9,
      14.35,
      -14 + Math.cos(angle) * 1.9,
    );
    meshes.push(batt);
  }

  // Window light glow
  const windowLight = new PointLight(0xffcc44, 1.8, 8);
  windowLight.position.set(0, 8, -12);

  return { meshes, windowLight };
}

// ── Torch ─────────────────────────────────────────────────────────────────────

interface TorchData {
  meshes: Mesh[];
  light: PointLight;
}

function buildTorch(): TorchData {
  const stickMat = new MeshStandardMaterial({ color: 0x3a2010, flatShading: true, roughness: 0.95 });
  const stickGeo = new CylinderGeometry(0.05, 0.07, 1.2, 5);
  const stick = new Mesh(stickGeo, stickMat);
  stick.position.set(2.0, 0.7, 6);

  const flameMat = new MeshBasicMaterial({ color: 0xff8833 });
  const flameGeo = new ConeGeometry(0.12, 0.28, 5);
  const flame = new Mesh(flameGeo, flameMat);
  flame.position.set(2.0, 1.42, 6);

  const torchLight = new PointLight(0xff8833, 0.9, 6);
  torchLight.position.set(2.0, 1.4, 6);

  return { meshes: [stick, flame], light: torchLight };
}

// ── Stars ─────────────────────────────────────────────────────────────────────

function buildStars(): Points {
  const count = 200;
  const positions = new Float32Array(count * 3);
  for (let i = 0; i < count; i++) {
    const theta = Math.random() * Math.PI * 2;
    const phi = Math.acos(2 * Math.random() - 1);
    const r = 55 + Math.random() * 10;
    positions[i * 3 + 0] = r * Math.sin(phi) * Math.cos(theta);
    positions[i * 3 + 1] = Math.abs(r * Math.cos(phi)) + 5; // upper hemisphere
    positions[i * 3 + 2] = r * Math.sin(phi) * Math.sin(theta);
  }
  const geo = new BufferGeometry();
  geo.setAttribute('position', new Float32BufferAttribute(positions, 3));
  const mat = new PointsMaterial({ color: 0xaad4ff, size: 0.12, transparent: true, opacity: 0.7 });
  return new Points(geo, mat);
}

// ── Moon ─────────────────────────────────────────────────────────────────────

function buildMoon(): Mesh {
  const geo = new SphereGeometry(2.5, 8, 6);
  const mat = new MeshBasicMaterial({ color: 0xc8e8c8 });
  const moon = new Mesh(geo, mat);
  moon.position.set(12, 22, -35);
  return moon;
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

  // ── Scene ─────────────────────────────────────────────────────────────────
  const scene = new Scene();
  scene.background = new Color(0x060c1a);
  scene.fog = new FogExp2(0x060c1a, 0.009);

  // ── Camera ────────────────────────────────────────────────────────────────
  const camera = new PerspectiveCamera(60, (container.clientWidth || window.innerWidth) / (container.clientHeight || window.innerHeight), 0.1, 200);
  camera.position.copy(CAM_START);
  camera.lookAt(LOOK_START);

  // ── Lighting ──────────────────────────────────────────────────────────────
  const ambientLight = new AmbientLight(0x152030, 0.45);
  scene.add(ambientLight);

  const moonLight = new DirectionalLight(0xc0d8ff, 0.7);
  moonLight.position.set(10, 20, 5);
  scene.add(moonLight);

  // ── Ocean ─────────────────────────────────────────────────────────────────
  const ocean = buildOcean();
  scene.add(ocean.mesh);
  scene.add(ocean.horizonPlane);

  // ── Terrain ───────────────────────────────────────────────────────────────
  for (const m of buildTerrain()) scene.add(m);

  // ── Path ──────────────────────────────────────────────────────────────────
  for (const m of buildStonePath()) scene.add(m);

  // ── Rocks ─────────────────────────────────────────────────────────────────
  for (const m of buildRocks()) scene.add(m);

  // ── Tower ─────────────────────────────────────────────────────────────────
  const tower = buildTower();
  for (const m of tower.meshes) scene.add(m);
  scene.add(tower.windowLight);

  // ── Torch ─────────────────────────────────────────────────────────────────
  const torch = buildTorch();
  for (const m of torch.meshes) scene.add(m);
  scene.add(torch.light);

  // ── Stars & Moon ──────────────────────────────────────────────────────────
  scene.add(buildStars());
  scene.add(buildMoon());

  // ── Title overlay ─────────────────────────────────────────────────────────
  const titleOverlay = buildTitleOverlay();
  container.appendChild(titleOverlay);

  // ── Resize handler ────────────────────────────────────────────────────────
  const onResize = (): void => {
    const w = container.clientWidth || window.innerWidth;
    const h = container.clientHeight || window.innerHeight;
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
    renderer.setSize(w, h);
  };
  window.addEventListener('resize', onResize);

  // ── Dolly state ───────────────────────────────────────────────────────────
  let dollyActive = false;
  let dollyElapsed = 0;
  let dollyCallback: (() => void) | null = null;

  // ── Time accumulator ─────────────────────────────────────────────────────
  let elapsed = 0;
  const currentLookAt = LOOK_START.clone();

  // ── Update loop ───────────────────────────────────────────────────────────
  const update = (dt: number): void => {
    elapsed += dt;

    // Ocean wave animation
    updateOcean(ocean, elapsed);

    // Torch flicker
    torch.light.intensity = 0.9 + Math.sin(elapsed * 7.3) * 0.25 + Math.sin(elapsed * 13.1) * 0.1;

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
      // Idle breathing
      camera.position.y = CAM_START.y + Math.sin(elapsed * 0.2) * 0.003;
      camera.lookAt(LOOK_START);
    }

    renderer.render(scene, camera);
  };

  // ── startDolly ────────────────────────────────────────────────────────────
  const startDolly = (onComplete: () => void): void => {
    dollyActive = true;
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
          obj.material.dispose();
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
