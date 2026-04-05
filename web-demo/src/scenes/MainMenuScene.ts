// ═══════════════════════════════════════════════════════════════════════════════
// Main Menu Scene — Cycle 32 — "Knoll of Oghams at Dusk"
// Full N64 aesthetic: vivid saturated palette, flatShading everywhere, chunky
// low-poly geometry. Fixed beautiful dusk so the menu always looks great.
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
  Group,
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

// ── Camera dolly ──────────────────────────────────────────────────────────────

const CAM_START  = new Vector3(0, 4.0, 20);
const CAM_END    = new Vector3(0, 2.5, 2);
const LOOK_START = new Vector3(0, 2.5, -4);
const LOOK_END   = new Vector3(0, 3.5, -12);
const DOLLY_DURATION = 6;

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

// ── Ground — rolling N64 Celtic hills ────────────────────────────────────────

function buildGround(): Mesh[] {
  const meshes: Mesh[] = [];

  // Main knoll — vivid forest green, lumpy low-poly terrain
  const mainGeo = new PlaneGeometry(100, 80, 28, 20);
  const pos = mainGeo.attributes['position'] as BufferAttribute;
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i);
    const z = pos.getZ(i);
    // Gentle knoll: highest in the middle (stone circle area, z ≈ -8)
    const d = Math.sqrt(x * x + (z + 8) * (z + 8));
    const bump = Math.max(0, 3.5 - d * 0.18) + (Math.random() - 0.5) * 0.35;
    pos.setY(i, bump);
  }
  mainGeo.computeVertexNormals();
  const groundMat = new MeshStandardMaterial({ color: 0x1d6624, roughness: 0.97, metalness: 0.0, flatShading: true });
  meshes.push(new Mesh(mainGeo, groundMat));

  // Far rolling hills silhouette (two dark mounds behind the scene)
  const hillPositions: Array<[number, number, number, number, number]> = [
    [-22, 1.8, -28, 12, 6],
    [ 18, 2.2, -30, 14, 7],
    [  0, 1.2, -36, 18, 5],
  ];
  const hillMat = new MeshStandardMaterial({ color: 0x0d2c10, roughness: 1.0, metalness: 0.0, flatShading: true });
  for (const [hx, hy, hz, rx, ry] of hillPositions) {
    const geo = new SphereGeometry(1, 7, 5);
    const hill = new Mesh(geo, hillMat);
    hill.scale.set(rx, ry, rx * 0.6);
    hill.position.set(hx, hy, hz);
    meshes.push(hill);
  }

  return meshes;
}

// ── Stone path ────────────────────────────────────────────────────────────────

function buildStonePath(): Mesh[] {
  const meshes: Mesh[] = [];
  const slabMat = new MeshStandardMaterial({ color: 0x6b5840, roughness: 0.96, metalness: 0.0, flatShading: true });
  const slabs = 14;
  for (let i = 0; i < slabs; i++) {
    const t = i / (slabs - 1);
    const z = 18 - t * 28;
    const w = 1.1 + Math.random() * 0.7;
    const d = 0.7 + Math.random() * 0.5;
    const geo = new BoxGeometry(w, 0.14, d);
    const m = new Mesh(geo, slabMat);
    m.position.set((Math.random() - 0.5) * 0.7, 0.07 + Math.random() * 0.06, z);
    m.rotation.y = (Math.random() - 0.5) * 0.18;
    meshes.push(m);
  }
  return meshes;
}

// ── N64 Trees — chunky cylinder trunk + cone canopy ──────────────────────────

function buildTrees(): Mesh[] {
  const meshes: Mesh[] = [];
  const trunkMat  = new MeshStandardMaterial({ color: 0x5c3010, roughness: 0.95, metalness: 0.0, flatShading: true });
  const canopyMat = new MeshStandardMaterial({ color: 0x1e9c30, roughness: 0.90, metalness: 0.0, flatShading: true });
  const canopy2   = new MeshStandardMaterial({ color: 0x157020, roughness: 0.90, metalness: 0.0, flatShading: true });

  const trees: Array<[number, number, number, number]> = [
    [-9,  0, -5,   1.0],
    [ 9,  0, -7,   1.15],
    [-13, 0, -14,  0.9],
    [ 13, 0, -12,  1.1],
    [-7,  0, -18,  0.85],
    [ 7,  0, -22,  1.2],
    [-18, 0, -20,  0.95],
    [ 17, 0, -18,  1.0],
  ];
  for (const [tx, ty, tz, scale] of trees) {
    const th = (2.2 + Math.random() * 0.8) * scale;
    const tr = (0.22 + Math.random() * 0.08) * scale;
    const trunkGeo = new CylinderGeometry(tr * 0.6, tr, th, 5);
    const trunk = new Mesh(trunkGeo, trunkMat);
    trunk.position.set(tx, ty + th * 0.5, tz);
    meshes.push(trunk);

    // Two stacked cones for N64-chunky canopy
    const cr1 = (1.4 + Math.random() * 0.6) * scale;
    const ch1 = (2.8 + Math.random() * 0.6) * scale;
    const cone1Geo = new ConeGeometry(cr1, ch1, 6);
    const cone1 = new Mesh(cone1Geo, canopyMat);
    cone1.position.set(tx, ty + th + ch1 * 0.42, tz);
    cone1.rotation.y = Math.random() * Math.PI;
    meshes.push(cone1);

    const cr2 = cr1 * 0.7;
    const ch2 = ch1 * 0.7;
    const cone2Geo = new ConeGeometry(cr2, ch2, 6);
    const cone2 = new Mesh(cone2Geo, canopy2);
    cone2.position.set(tx, ty + th + ch1 * 0.55 + ch2 * 0.42, tz);
    cone2.rotation.y = Math.random() * Math.PI;
    meshes.push(cone2);
  }
  return meshes;
}

// ── Ogham Stone Circle — 7 standing stones in a ring ─────────────────────────

interface StoneCircleData {
  group: Group;
  wispMeshes: Mesh[];
  wispPhases: number[];
  circleLight: PointLight;
}

function buildStoneCircle(): StoneCircleData {
  const group = new Group();
  const stoneMat = new MeshStandardMaterial({ color: 0x4a3f34, roughness: 0.96, metalness: 0.0, flatShading: true });
  const runeMat  = new MeshStandardMaterial({
    color: 0x33ff88, roughness: 0.3, metalness: 0.0, flatShading: true,
    emissive: new Color(0x00cc55), emissiveIntensity: 0.8,
  });
  const N = 7;
  const R = 4.2;
  for (let i = 0; i < N; i++) {
    const angle = (i / N) * Math.PI * 2;
    const height = 2.0 + Math.random() * 1.4;
    const w = 0.38 + Math.random() * 0.12;
    const d = 0.22 + Math.random() * 0.08;
    const geo = new BoxGeometry(w, height, d);
    const stone = new Mesh(geo, stoneMat);
    stone.position.set(Math.cos(angle) * R, height * 0.5, Math.sin(angle) * R);
    stone.rotation.y = angle + (Math.random() - 0.5) * 0.3;
    stone.rotation.z = (Math.random() - 0.5) * 0.08;
    group.add(stone);

    // Ogham notch marks (2-4 per stone, horizontal cuts on front face)
    const notchCount = 2 + Math.floor(Math.random() * 3);
    for (let n = 0; n < notchCount; n++) {
      const nw = 0.20 + Math.random() * 0.12;
      const notchGeo = new BoxGeometry(nw, 0.05, d + 0.02);
      const notch = new Mesh(notchGeo, runeMat);
      notch.position.set(
        Math.cos(angle) * R,
        0.5 + n * (height * 0.18),
        Math.sin(angle) * R,
      );
      notch.rotation.y = angle + (Math.random() - 0.5) * 0.3;
      group.add(notch);
    }
  }

  // Central altar stone — flat capstone
  const capGeo = new BoxGeometry(1.4, 0.28, 0.9);
  const cap = new Mesh(capGeo, stoneMat);
  cap.position.set(0, 1.82, 0);
  group.add(cap);
  const leg1Geo = new BoxGeometry(0.28, 1.8, 0.28);
  const leg1 = new Mesh(leg1Geo, stoneMat);
  leg1.position.set(-0.45, 0.9, 0);
  group.add(leg1);
  const leg2 = new Mesh(leg1Geo, stoneMat);
  leg2.position.set(0.45, 0.9, 0);
  group.add(leg2);

  // Floating wisps around the circle
  const wispMat = new MeshStandardMaterial({
    color: 0x88ffcc, roughness: 0.2, metalness: 0.0, flatShading: false,
    transparent: true, opacity: 0.75,
    emissive: new Color(0x22ffaa), emissiveIntensity: 1.2,
  });
  const wispMeshes: Mesh[] = [];
  const wispPhases: number[] = [];
  for (let w = 0; w < 8; w++) {
    const geo = new SphereGeometry(0.07 + Math.random() * 0.05, 5, 4);
    const wisp = new Mesh(geo, wispMat.clone() as MeshStandardMaterial);
    wispMeshes.push(wisp);
    wispPhases.push((w / 8) * Math.PI * 2);
    group.add(wisp);
  }

  // Central green spirit light
  const circleLight = new PointLight(0x44ff88, 1.2, 12);
  circleLight.position.set(0, 1.5, 0);
  group.add(circleLight);

  group.position.set(0, 0, -8);
  return { group, wispMeshes, wispPhases, circleLight };
}

// ── Distant tower silhouette ──────────────────────────────────────────────────

function buildTower(): Mesh[] {
  const meshes: Mesh[] = [];
  const silMat = new MeshStandardMaterial({ color: 0x0c0a10, roughness: 1.0, metalness: 0.0, flatShading: true });

  const bodyGeo = new CylinderGeometry(1.4, 1.8, 12, 6);
  const body = new Mesh(bodyGeo, silMat);
  body.position.set(-18, 6, -28);
  meshes.push(body);

  const roofGeo = new ConeGeometry(1.9, 3.0, 6);
  const roof = new Mesh(roofGeo, silMat);
  roof.position.set(-18, 13.5, -28);
  meshes.push(roof);

  // Warm amber window
  const winLight = new PointLight(0xffaa33, 1.4, 8);
  winLight.position.set(-17.5, 7.5, -26.5);
  // Not a Mesh — handled separately; store as userData trick not needed, just push
  // We'll add it in initMainMenu directly

  return meshes;
}

// ── Moon & Stars ──────────────────────────────────────────────────────────────

function buildNightSky(): { stars: Points; moon: Mesh } {
  // Stars
  const count = 280;
  const positions = new Float32Array(count * 3);
  for (let i = 0; i < count; i++) {
    const theta = Math.random() * Math.PI * 2;
    const phi = Math.acos(2 * Math.random() - 1);
    const r = 60 + Math.random() * 15;
    positions[i * 3 + 0] = r * Math.sin(phi) * Math.cos(theta);
    positions[i * 3 + 1] = Math.abs(r * Math.cos(phi)) + 8;
    positions[i * 3 + 2] = r * Math.sin(phi) * Math.sin(theta);
  }
  const geo = new BufferGeometry();
  geo.setAttribute('position', new Float32BufferAttribute(positions, 3));
  const mat = new PointsMaterial({ color: 0xffd8ff, size: 0.18, transparent: true, opacity: 0.85 });
  const stars = new Points(geo, mat);

  // Moon — large, N64-chunky sphere, warm ivory
  const moonGeo = new SphereGeometry(3.2, 7, 5);
  const moonMat = new MeshBasicMaterial({ color: 0xffe8c0 });
  const moon = new Mesh(moonGeo, moonMat);
  moon.position.set(16, 24, -42);

  return { stars, moon };
}

// ── Rocks scattered around the scene ─────────────────────────────────────────

function buildRocks(): Mesh[] {
  const meshes: Mesh[] = [];
  const mat = new MeshStandardMaterial({ color: 0x2e2820, roughness: 0.98, metalness: 0.0, flatShading: true });
  const positions: Array<[number, number, number, number]> = [
    [5.5, 0, 8, 0.8], [-5.0, 0, 6, 1.0],
    [7.0, 0, 2, 0.6], [-6.5, 0, -1, 0.9],
    [4.0, 0, -3, 0.7], [-4.0, 0, 3, 0.55],
  ];
  for (const [rx, ry, rz, scale] of positions) {
    const geo = new DodecahedronGeometry(scale, 0);
    const m = new Mesh(geo, mat);
    m.position.set(rx, ry + scale * 0.4, rz);
    m.rotation.y = Math.random() * Math.PI;
    meshes.push(m);
  }
  return meshes;
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
  renderer.setSize(
    container.clientWidth  || window.innerWidth,
    container.clientHeight || window.innerHeight,
  );
  renderer.toneMapping = NoToneMapping;
  container.appendChild(renderer.domElement);

  // ── Scene — deep N64 dusk palette ────────────────────────────────────────
  const SKY_COLOR = 0x120820; // deep violet dusk
  const scene = new Scene();
  scene.background = new Color(SKY_COLOR);
  scene.fog = new FogExp2(SKY_COLOR, 0.007);

  // ── Camera ────────────────────────────────────────────────────────────────
  const camera = new PerspectiveCamera(
    60,
    (container.clientWidth || window.innerWidth) / (container.clientHeight || window.innerHeight),
    0.1,
    200,
  );
  camera.position.copy(CAM_START);
  camera.lookAt(LOOK_START);

  // ── Lighting — dusk warm-cool contrast ───────────────────────────────────
  const ambientLight = new AmbientLight(0x1a1030, 0.55);
  scene.add(ambientLight);

  // Sunset directional from west — deep orange
  const sunsetLight = new DirectionalLight(0xff7020, 1.1);
  sunsetLight.position.set(-14, 6, -10);
  scene.add(sunsetLight);

  // Cool blue moonlight from east
  const moonLight = new DirectionalLight(0x8090d8, 0.45);
  moonLight.position.set(10, 18, 5);
  scene.add(moonLight);

  // ── Ground ────────────────────────────────────────────────────────────────
  for (const m of buildGround()) scene.add(m);

  // ── Stone path ────────────────────────────────────────────────────────────
  for (const m of buildStonePath()) scene.add(m);

  // ── Trees ─────────────────────────────────────────────────────────────────
  for (const m of buildTrees()) scene.add(m);

  // ── Rocks ─────────────────────────────────────────────────────────────────
  for (const m of buildRocks()) scene.add(m);

  // ── Stone circle ──────────────────────────────────────────────────────────
  const circle = buildStoneCircle();
  scene.add(circle.group);

  // ── Tower silhouette ──────────────────────────────────────────────────────
  for (const m of buildTower()) scene.add(m);
  const towerLight = new PointLight(0xffaa33, 1.4, 8);
  towerLight.position.set(-17.5, 7.5, -26.5);
  scene.add(towerLight);

  // ── Night sky ─────────────────────────────────────────────────────────────
  const { stars, moon } = buildNightSky();
  scene.add(stars);
  scene.add(moon);

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
  let dollyActive = false;
  let dollyElapsed = 0;
  let dollyCallback: (() => void) | null = null;
  let elapsed = 0;
  const currentLookAt = LOOK_START.clone();

  // ── Update ────────────────────────────────────────────────────────────────
  const update = (dt: number): void => {
    elapsed += dt;

    // Tower window flicker
    towerLight.intensity = 1.3 + Math.sin(elapsed * 6.8) * 0.3 + Math.sin(elapsed * 11.2) * 0.12;

    // Stone circle wisps — helical orbit
    const R_WISP = 4.8;
    for (let w = 0; w < circle.wispMeshes.length; w++) {
      const phase = circle.wispPhases[w]!;
      const speed = 0.28 + w * 0.03;
      const age = ((elapsed * speed + phase / (Math.PI * 2)) % 1.0);
      const spiralAngle = elapsed * (0.6 + w * 0.08) + phase;
      const yBase = 0.4 + age * 3.5;
      const wispR = R_WISP * (0.7 + 0.3 * Math.sin(elapsed * 0.4 + phase));
      const wisp = circle.wispMeshes[w]!;
      wisp.position.set(
        Math.cos(spiralAngle) * wispR,
        yBase,
        Math.sin(spiralAngle) * wispR,
      );
      const mat = wisp.material as MeshStandardMaterial;
      mat.opacity = age < 0.75
        ? 0.55 + 0.25 * Math.sin(elapsed * 2.5 + phase)
        : 0.55 * (1.0 - (age - 0.75) / 0.25);
      mat.emissiveIntensity = 1.0 + 0.6 * Math.sin(elapsed * 2.0 + phase);
    }

    // Circle ambient light pulse
    circle.circleLight.intensity = 1.0 + 0.4 * Math.sin(elapsed * 1.1);

    // Moon gentle bob
    moon.position.y = 24 + Math.sin(elapsed * 0.15) * 0.5;

    // Camera dolly or idle breathing
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
      camera.position.y = CAM_START.y + Math.sin(elapsed * 0.18) * 0.05;
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
