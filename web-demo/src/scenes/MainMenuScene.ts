// ═══════════════════════════════════════════════════════════════════════════════
// Main Menu Scene — Cycle 26 — Low-poly coastal cliff + tower
// Reference: dark stormy coast, flat-shaded polygons throughout.
// Camera: fixed high angle (-8,18,28) looking (4,2,-10). World animates.
// flatShading: true on ALL MeshStandardMaterial = the key low-poly look.
// ═══════════════════════════════════════════════════════════════════════════════

import { AdditiveBlending, AmbientLight, BackSide, BoxGeometry, BufferAttribute, BufferGeometry, CircleGeometry, Color, ConeGeometry, CylinderGeometry, DirectionalLight, DoubleSide, FogExp2, Group, Material, Mesh, MeshBasicMaterial, MeshStandardMaterial, NoToneMapping, PerspectiveCamera, PlaneGeometry, PointLight, Points, PointsMaterial, Scene, SphereGeometry, Vector3, WebGLRenderer } from 'three';

// ── Types ────────────────────────────────────────────────────────────────────

interface ParticleData {
  baseX: number;
  baseZ: number;
  velY: number;
  velZ: number;
  lifetime: number;
  maxLifetime: number;
}

interface MainMenuResult {
  renderer: WebGLRenderer;
  update: (dt: number) => void;
  /** Animate camera walk from cliff toward the tower over ~6 s, then calls onComplete. */
  startDolly: (onComplete: () => void) => void;
  dispose: () => void;
}

// ── Low-poly Ocean ───────────────────────────────────────────────────────────
// PlaneGeometry with many segments so flatShading creates visible wave facets.
// Vertex Y displacement in update() to animate the waves.

interface OceanResult {
  mesh: Mesh;
  horizonPlane: Mesh;
  update: (t: number) => void;
}

function createLowPolyOcean(): OceanResult {
  // Many segments so flatShading creates visible polygon faces per wave
  const geo = new PlaneGeometry(80, 60, 30, 20);

  // C163: N64 vivid ocean vertex colors — bright turquoise near shore → deep teal far
  const posAttr0 = geo.attributes['position'] as BufferAttribute;
  const vertCols = new Float32Array(posAttr0.count * 3);
  for (let i = 0; i < posAttr0.count; i++) {
    const x = posAttr0.getX(i); // local X: +40=near shore, -40=deep
    const shore = Math.max(0, Math.min(1, (x + 40) / 80));
    // near (shore=1): 0x18e8d0 = (0.094, 0.910, 0.816) N64 vivid turquoise
    // deep (shore=0): 0x0a5aaa = (0.039, 0.353, 0.667) deep ocean blue
    // near shore: dark teal, deep: dark navy
    vertCols[i * 3 + 0] = 0.020 + shore * 0.019;
    vertCols[i * 3 + 1] = 0.063 + shore * 0.172;
    vertCols[i * 3 + 2] = 0.118 + shore * 0.204;
  }
  geo.setAttribute('color', new BufferAttribute(vertCols, 3));

  const mat = new MeshStandardMaterial({
    vertexColors: true,
    flatShading: true,
    roughness: 0.55,
    metalness: 0.22,
  });

  const mesh = new Mesh(geo, mat);
  mesh.rotation.x = -Math.PI / 2;
  // Ocean is left half of scene, below cliff level
  mesh.position.set(-18, -2, -8);

  // Horizon plane: N64 vivid cyan far ocean
  const horizonGeo = new PlaneGeometry(120, 50, 12, 6);
  const horizonMat = new MeshStandardMaterial({
    color: 0x081828,   // C168: dark navy storm horizon
    flatShading: true,
    roughness: 0.6,
    metalness: 0.2,
  });
  const horizonPlane = new Mesh(horizonGeo, horizonMat);
  horizonPlane.rotation.x = -Math.PI / 2;
  horizonPlane.position.set(-10, -2, -45);

  // Store original Y positions for wave animation
  const posAttr = geo.attributes['position'] as BufferAttribute;
  const count = posAttr.count;
  const baseY = new Float32Array(count);
  for (let i = 0; i < count; i++) {
    baseY[i] = posAttr.getY(i);
  }

  const update = (t: number): void => {
    const positions = posAttr.array as Float32Array;
    for (let i = 0; i < count; i++) {
      const x = posAttr.getX(i);
      const z = baseY[i]; // original "z" in plane space = y before rotation
      const wave =
        Math.sin(x * 0.18 + t * 1.1) * 0.8 +
        Math.cos(z * 0.22 + t * 0.75) * 0.6 +
        Math.sin(x * 0.07 + z * 0.09 + t * 1.8) * 0.4;
      positions[i * 3 + 2] = wave; // Z in plane space = up after rotation
    }
    posAttr.needsUpdate = true;
    // flatShading:true — GPU computes per-face normals from vertex positions at render time.
    // computeVertexNormals() is unnecessary and was wasting ~1-2ms/frame on mobile.
  };

  return { mesh, horizonPlane, update };
}

// ── Foam patches near cliff base ─────────────────────────────────────────────

interface FoamPatchResult {
  group: Group;
  update: (t: number) => void;
}

function createFoamPatches(): FoamPatchResult {
  const group = new Group();
  const mat = new MeshStandardMaterial({
    color: 0xddeeff,
    flatShading: true,
    roughness: 1.0,
    metalness: 0.0,
    transparent: true,
    opacity: 0.75,
  });

  const positions: [number, number, number][] = [
    [-4, -1.8, -2],
    [-7, -1.8, 2],
    [-2, -1.8, -5],
    [-9, -1.8, -1],
    [-5, -1.8, 4],
    [-3, -1.8, 1],
    [-6, -1.8, -4],
    [-10, -1.8, 3],
    [-1, -1.8, -3],
    [-8, -1.8, -3],
    [-11, -1.8, 1],
    [-4, -1.8, 5],
    [-6, -1.8, 6],
    [-2, -1.8, 2],
    [-13, -1.8, -1],
    [-3, -1.8, -6],
    [-7, -1.8, -5],
    [-9, -1.8, 4],
    [-5, -1.8, -7],
    [-11, -1.8, -4],
    [-14, -1.8, 2],
    [-12, -1.8, 5],
    [-1, -1.8, -7],
    [-8, -1.8, 7],
    [-10, -1.8, -6],
  ];

  for (let i = 0; i < positions.length; i++) {
    const [x, y, z] = positions[i];
    const geo = new CircleGeometry(0.6 + Math.random() * 0.5, 5);
    const foam = new Mesh(geo, mat);
    foam.rotation.x = -Math.PI / 2;
    foam.position.set(x, y, z);
    // Store base Y and per-patch phase offset for Y-animation
    foam.userData['baseY'] = y;
    foam.userData['phase'] = i * 0.42; // spread phases across patches
    group.add(foam);
  }

  // Animate each foam patch with a gentle sinusoidal Y bob — living sea feel
  const update = (t: number): void => {
    for (const child of group.children) {
      const mesh = child as Mesh;
      const baseY = mesh.userData['baseY'] as number;
      const phase = mesh.userData['phase'] as number;
      mesh.position.y = baseY + Math.sin(t * 1.5 + phase) * 0.003;
    }
  };

  return { group, update };
}

// ── Cliff Rocks ──────────────────────────────────────────────────────────────
// Multiple BoxGeometry masses with manually displaced vertices for angular look.
// ALL use flatShading: true to show each face as a distinct polygon.

function displaceVertices(geo: BufferGeometry, amount: number): void {
  const posAttr = geo.attributes['position'] as BufferAttribute;
  const arr = posAttr.array as Float32Array;
  for (let i = 0; i < posAttr.count; i++) {
    arr[i * 3]     += (Math.random() - 0.5) * amount;
    arr[i * 3 + 1] += (Math.random() - 0.5) * amount;
    arr[i * 3 + 2] += (Math.random() - 0.5) * amount;
  }
  posAttr.needsUpdate = true;
  // flatShading:true — GPU computes per-face normals at render time; computeVertexNormals() here
  // was wasting ~0.3-0.5ms per call × 11 cliffs = ~3-5ms init on mobile (C175).
}

function createCliff(): Group {
  const group = new Group();

  // C168: Dark atmospheric stone cliff — wet stormy rock palette
  const matBase = new MeshStandardMaterial({
    color: 0x3a2e1c,
    flatShading: true,
    roughness: 0.95,
    metalness: 0.0,
  });
  const matShadow = new MeshStandardMaterial({
    color: 0x201410,
    flatShading: true,
    roughness: 1.0,
    metalness: 0.0,
  });
  const matHighlight = new MeshStandardMaterial({
    color: 0x4e3e28,
    flatShading: true,
    roughness: 0.88,
    metalness: 0.0,
  });

  // Main cliff body — large angular mass, left-center (4,4,4 segments for coarser facets)
  const bodyGeo = new BoxGeometry(18, 14, 12, 4, 4, 4);
  displaceVertices(bodyGeo, 2.0);
  const body = new Mesh(bodyGeo, matBase);
  body.position.set(-6, 0, -10);
  group.add(body);

  // Upper cliff platform (4 segs, stronger displacement)
  const upperGeo = new BoxGeometry(14, 6, 10, 4, 4, 4);
  displaceVertices(upperGeo, 1.8);
  const upper = new Mesh(upperGeo, matHighlight);
  upper.position.set(-4, 10, -9);
  group.add(upper);

  // Left face — darker shadow side (more segments = more angular silhouette)
  const leftGeo = new BoxGeometry(8, 18, 8, 4, 4, 4);
  displaceVertices(leftGeo, 2.0);
  const left = new Mesh(leftGeo, matShadow);
  left.position.set(-12, 1, -8);
  left.rotation.y = 0.15;
  group.add(left);

  // Rocky outcrop 1 — mid cliff
  const rock1Geo = new BoxGeometry(7, 5, 6, 4, 4, 4);
  displaceVertices(rock1Geo, 1.8);
  const rock1 = new Mesh(rock1Geo, matBase);
  rock1.position.set(-2, 7, -6);
  rock1.rotation.y = 0.4;
  group.add(rock1);

  // Rocky outcrop 2 — high right, connects to tower base
  const rock2Geo = new BoxGeometry(10, 4, 8, 4, 4, 4);
  displaceVertices(rock2Geo, 1.6);
  const rock2 = new Mesh(rock2Geo, matHighlight);
  rock2.position.set(4, 13, -11);
  rock2.rotation.y = -0.2;
  group.add(rock2);

  // Foreground rocks — closer to camera (depth layering, darker)
  const rock3Geo = new BoxGeometry(4, 3, 4, 4, 4, 4);
  displaceVertices(rock3Geo, 1.4);
  const rock3 = new Mesh(rock3Geo, matShadow);
  rock3.position.set(0, 5, -2);
  rock3.rotation.y = 0.6;
  group.add(rock3);

  const rock4Geo = new BoxGeometry(3, 2, 3, 4, 4, 4);
  displaceVertices(rock4Geo, 1.2);
  const rock4 = new Mesh(rock4Geo, matBase);
  rock4.position.set(-8, 4, -3);
  rock4.rotation.y = -0.3;
  group.add(rock4);

  // Three additional foreground rock masses for depth layering
  const rock5Geo = new BoxGeometry(5, 4, 4, 4, 4, 4);
  displaceVertices(rock5Geo, 1.6);
  const rock5 = new Mesh(rock5Geo, matShadow);
  rock5.position.set(-15, 2, -5);
  rock5.rotation.y = 0.9;
  group.add(rock5);

  const rock6Geo = new BoxGeometry(6, 3, 5, 4, 4, 4);
  displaceVertices(rock6Geo, 1.5);
  const rock6 = new Mesh(rock6Geo, matBase);
  rock6.position.set(-18, 1, -12);
  rock6.rotation.y = -0.5;
  group.add(rock6);

  const rock7Geo = new BoxGeometry(4, 5, 4, 4, 4, 4);
  displaceVertices(rock7Geo, 1.7);
  const rock7 = new Mesh(rock7Geo, matShadow);
  rock7.position.set(2, 3, -3);
  rock7.rotation.y = 1.2;
  group.add(rock7);

  // Large waterline rock — partially submerged at ocean edge
  const waterRockGeo = new BoxGeometry(8, 5, 6, 4, 4, 4);
  displaceVertices(waterRockGeo, 1.8);
  const waterRock = new Mesh(waterRockGeo, matShadow);
  waterRock.position.set(-14, -1, -3);
  waterRock.rotation.y = 0.25;
  group.add(waterRock);

  return group;
}

// ── Distant Cliff Silhouette ─────────────────────────────────────────────────
// Pure flat dark slab at z=-90 — no detail, pure depth silhouette.

function createDistantSilhouette(): Mesh {
  const geo = new BoxGeometry(60, 20, 2);
  const mat = new MeshStandardMaterial({
    color: 0x1a1e28,
    flatShading: true,
    roughness: 1.0,
    metalness: 0.0,
  });
  const mesh = new Mesh(geo, mat);
  mesh.position.set(0, 5, -90);
  return mesh;
}

// ── Sandy Path ───────────────────────────────────────────────────────────────

function createPath(): Mesh {
  const geo = new PlaneGeometry(2.5, 16, 3, 6);
  displaceVertices(geo, 0.15);
  const mat = new MeshStandardMaterial({
    color: 0xb0a080,
    flatShading: true,
    roughness: 1.0,
    metalness: 0.0,
  });
  const mesh = new Mesh(geo, mat);
  mesh.rotation.x = -Math.PI / 2;
  mesh.rotation.z = 0.3;
  mesh.position.set(2, 8.2, -6);
  return mesh;
}

// ── Tower ────────────────────────────────────────────────────────────────────
// CylinderGeometry with 7 radial segments = low-poly faceted cylinder.
// Conical roof also 7 segments. Battlements as small BoxGeometry notches.

function createTower(): Group {
  const group = new Group();

  // C168: Dark weathered stone tower
  const mat = new MeshStandardMaterial({
    color: 0x48403a,
    flatShading: true,
    roughness: 0.9,
    metalness: 0.0,
  });
  const matDark = new MeshStandardMaterial({
    color: 0x302820,
    flatShading: true,
    roughness: 1.0,
    metalness: 0.0,
  });
  const matRoof = new MeshStandardMaterial({
    color: 0x201c18,
    flatShading: true,
    roughness: 1.0,
    metalness: 0.0,
  });

  // Ground floor section (wider base)
  const base = new Mesh(new CylinderGeometry(1.9, 2.2, 3.0, 7), mat);
  base.position.set(0, 1.5, 0);
  group.add(base);

  // Second section
  const s2 = new Mesh(new CylinderGeometry(1.7, 1.9, 3.0, 7), mat);
  s2.position.set(0, 4.5, 0);
  group.add(s2);

  // Third section
  const s3 = new Mesh(new CylinderGeometry(1.6, 1.7, 3.0, 7), mat);
  s3.position.set(0, 7.5, 0);
  group.add(s3);

  // Top section (battlements ring)
  const s4 = new Mesh(new CylinderGeometry(1.7, 1.6, 2.0, 7), matDark);
  s4.position.set(0, 10.0, 0);
  group.add(s4);

  // Battlement notches — 7 small boxes around the top ring
  // C168: slightly lighter than wall for battlement silhouette contrast
  const notchMat = new MeshStandardMaterial({
    color: 0x504840,
    flatShading: true,
    roughness: 0.9,
    metalness: 0.0,
  });
  for (let i = 0; i < 7; i++) {
    const angle = (i / 7) * Math.PI * 2;
    const notch = new Mesh(new BoxGeometry(0.5, 0.8, 0.4), notchMat);
    notch.position.set(
      Math.cos(angle) * 1.7,
      11.4,
      Math.sin(angle) * 1.7
    );
    notch.rotation.y = angle;
    group.add(notch);
  }

  // Conical roof — 7 segments = clearly low-poly cone
  const roofGeo = new CylinderGeometry(0, 1.8, 3.5, 7);
  const roof = new Mesh(roofGeo, matRoof);
  roof.position.set(0, 13.25, 0);
  group.add(roof);

  // Arched window — dark rectangle on the cylinder face
  const windowMat = new MeshBasicMaterial({ color: 0x1a1008 });
  const windowGeo = new PlaneGeometry(0.6, 0.9);
  const win = new Mesh(windowGeo, windowMat);
  win.position.set(0, 7.2, 1.65);
  group.add(win);

  // Warm interior point light (visible through window)
  const insideLight = new PointLight(0xffcc44, 2.2, 14, 2); // C168: brighter warm glow against dark scene
  insideLight.position.set(0, 7, 0);
  group.add(insideLight);

  // Position tower: right side, top of cliff
  group.position.set(6, 13, -13);
  return group;
}

// ── Polygon Cloud Shapes ─────────────────────────────────────────────────────
// Flat BoxGeometry planes at varied z-depths (-20 to -80) for parallax.
// Each cloud has slight rx/rz tilt for organic feel.
// Wispy high-altitude clouds: very flat h=0.3, wide 25-40 units.
// Slow x-drift animation (0.002 units/frame) via update().

interface CloudConfig {
  color: number;
  w: number;
  h: number;
  d: number;
  x: number;
  y: number;
  z: number;
  ry: number;
  rx: number;
  rz: number;
}

function createClouds(): { group: Group; update: (t: number) => void } {
  const group = new Group();

  // C168: Dark stormy cloud palette — layered charcoal-grey storm clouds
  const cloudConfigs: CloudConfig[] = [
    // Mid-depth heavy storm clouds
    { color: 0x3a4055, w: 14, h: 2.8, d: 0.6, x: -20, y: 32, z: -40, ry: 0.05,  rx: -0.03, rz:  0.01 },
    { color: 0x2e3448, w: 10, h: 2.2, d: 0.5, x:  -8, y: 35, z: -45, ry: -0.08, rx:  0.04, rz: -0.02 },
    { color: 0x454a60, w: 18, h: 3.0, d: 0.7, x:   5, y: 30, z: -35, ry: 0.12,  rx: -0.05, rz:  0.02 },
    { color: 0x282d3e, w: 11, h: 1.8, d: 0.4, x:  15, y: 33, z: -42, ry: -0.05, rx:  0.02, rz: -0.01 },
    { color: 0x3c4158, w: 15, h: 2.4, d: 0.6, x: -25, y: 28, z: -38, ry: 0.1,   rx: -0.04, rz:  0.015},
    { color: 0x4a5068, w: 20, h: 3.4, d: 0.8, x:  -5, y: 27, z: -32, ry: -0.15, rx:  0.05, rz: -0.02 },
    // Deep storm layer — darker, heavier
    { color: 0x222638, w: 12, h: 2.0, d: 0.4, x:  20, y: 36, z: -60, ry: 0.02,  rx: -0.02, rz:  0.01 },
    { color: 0x1e2230, w: 16, h: 2.6, d: 0.5, x: -15, y: 38, z: -65, ry: -0.06, rx:  0.03, rz: -0.015},
    { color: 0x2a2e40, w: 24, h: 3.8, d: 0.8, x:   0, y: 25, z: -70, ry: 0.08,  rx: -0.03, rz:  0.02 },
    { color: 0x1c2030, w: 18, h: 2.8, d: 0.6, x: -30, y: 31, z: -55, ry: -0.1,  rx:  0.04, rz: -0.01 },
    { color: 0x252838, w: 20, h: 3.0, d: 0.6, x:  25, y: 29, z: -50, ry: 0.07,  rx: -0.05, rz:  0.02 },
    // Very far massive dark cloud bank
    { color: 0x181a28, w: 40, h: 5.0, d: 1.0, x:  -5, y: 22, z: -80, ry: 0.03,  rx:  0.01, rz: -0.005},
    // High-altitude thin storm streaks — very dark
    { color: 0x20243a, w: 38, h: 0.6, d: 0.2, x: -10, y: 45, z: -75, ry: -0.04, rx: -0.01, rz:  0.005},
    { color: 0x1a1e30, w: 32, h: 0.5, d: 0.2, x:  15, y: 48, z: -80, ry: 0.06,  rx:  0.01, rz: -0.005},
  ];

  for (const cfg of cloudConfigs) {
    const geo = new BoxGeometry(cfg.w, cfg.h, cfg.d);
    const mat = new MeshStandardMaterial({
      color: cfg.color,
      flatShading: true,
      roughness: 1.0,
      metalness: 0.0,
    });
    const cloud = new Mesh(geo, mat);
    cloud.position.set(cfg.x, cfg.y, cfg.z);
    cloud.rotation.set(cfg.rx, cfg.ry, cfg.rz);
    group.add(cloud);
  }

  // Slow x-drift: 0.002 units/frame (frame ~16ms → ~0.12 units/s)
  const update = (t: number): void => {
    group.children.forEach((child, i) => {
      // Each cloud drifts at slightly different speed for parallax
      const speed = 0.002 + i * 0.0002;
      child.position.x += speed;
      // Wrap around: if cloud drifts too far right, teleport left
      if (child.position.x > 60) {
        child.position.x -= 120;
      }
    });
    // suppress unused t warning
    void t;
  };

  return { group, update };
}

// ── Sky Background ───────────────────────────────────────────────────────────
// C162: vertex-colored SphereGeometry (BackSide) for polygon-gradient stormy sky.
// Zenith near-black → horizon slate-blue — consistent ISO low-poly style.

function createSkyBox(): Mesh {
  // C163: N64 Banjo-Kazooie bright sky — vivid blue gradient
  const geo = new SphereGeometry(280, 20, 14);
  const pos = geo.attributes['position'] as BufferAttribute;
  const cols = new Float32Array(pos.count * 3);
  for (let i = 0; i < pos.count; i++) {
    const y = pos.getY(i);
    const t = Math.max(0, Math.min(1, (y + 280) / 560)); // 0=bottom 1=top
    // horizon (t=0): 0x72b8e8 = (0.447, 0.722, 0.910) vivid N64 sky-blue horizon
    // zenith  (t=1): 0x1a3fa8 = (0.102, 0.247, 0.659) deep clear blue zenith
    // C168: dark storm sky — near-black zenith, dark slate horizon
    cols[i * 3 + 0] = 0.125 - t * 0.086;
    cols[i * 3 + 1] = 0.157 - t * 0.102;
    cols[i * 3 + 2] = 0.220 - t * 0.126;
  }
  geo.setAttribute('color', new BufferAttribute(cols, 3));
  return new Mesh(geo, new MeshStandardMaterial({
    vertexColors: true, flatShading: true, roughness: 1.0, metalness: 0.0, side: BackSide,
  }));
}

// ── Vegetation — Angular Bushes ───────────────────────────────────────────────
// ConeGeometry(r, h, 4) = 4 segments → diamond/triangular shape when flat-shaded.

function createVegetation(): Group {
  const group = new Group();

  // C168: Dark muted grey-green storm vegetation
  const mat1 = new MeshStandardMaterial({
    color: 0x1a3a14,
    flatShading: true,
    roughness: 1.0,
    metalness: 0.0,
  });
  const mat2 = new MeshStandardMaterial({
    color: 0x1e4818,
    flatShading: true,
    roughness: 1.0,
    metalness: 0.0,
  });

  // 18 angular bushes scattered on right cliff side
  const positions: [number, number, number, number, number][] = [
    [2, 9.5, -5, 0.4, 0.7],
    [4, 10, -7, 0.3, 0.6],
    [6, 11, -9, 0.35, 0.65],
    [3, 8.5, -4, 0.45, 0.8],
    [7, 12, -10, 0.3, 0.55],
    [5, 10.5, -6, 0.4, 0.7],
    [8, 11.5, -8, 0.35, 0.6],
    [1, 9, -3, 0.3, 0.65],
    [9, 13, -11, 0.4, 0.75],
    [4, 9.8, -3, 0.35, 0.6],
    [6, 11.2, -5, 0.3, 0.55],
    [2, 8.8, -6, 0.4, 0.7],
    [7, 10.8, -4, 0.35, 0.65],
    [5, 12.1, -12, 0.3, 0.6],
    [3, 9.2, -8, 0.4, 0.7],
    [8, 13.5, -9, 0.35, 0.65],
    [1, 8.5, -2, 0.3, 0.6],
    [10, 14, -12, 0.4, 0.75],
  ];

  for (let i = 0; i < positions.length; i++) {
    const [x, y, z, r, h] = positions[i];
    const geo = new ConeGeometry(r, h, 4);
    const mat = i % 2 === 0 ? mat1 : mat2;
    const bush = new Mesh(geo, mat);
    bush.position.set(x, y, z);
    bush.rotation.y = Math.random() * Math.PI;
    group.add(bush);
  }

  return group;
}

// ── Sea Spray Particle System ─────────────────────────────────────────────────

class SeaSpraySystem {
  private readonly points: Points;
  private readonly positions: Float32Array;
  private readonly particles: ParticleData[] = [];
  private readonly COUNT = 120;

  constructor() {
    this.positions = new Float32Array(this.COUNT * 3);

    for (let i = 0; i < this.COUNT; i++) {
      this.particles.push(this.resetParticle(i));
    }

    const geo = new BufferGeometry();
    geo.setAttribute('position', new BufferAttribute(this.positions, 3));

    const mat = new PointsMaterial({
      color: 0xaaccdd,
      size: 0.2,
      transparent: true,
      opacity: 0.55,
      blending: AdditiveBlending,
      depthWrite: false,
      sizeAttenuation: true,
    });

    this.points = new Points(geo, mat);
    // Position spray at cliff base / ocean edge
    this.points.position.set(-6, 0, -4);
  }

  private resetParticle(i: number): ParticleData {
    const baseX = -8 + Math.random() * 10;
    const baseZ = -6 + Math.random() * 6;
    const maxLifetime = 1.0 + Math.random() * 1.2;

    this.positions[i * 3]     = baseX;
    this.positions[i * 3 + 1] = -0.5 + Math.random() * 0.3;
    this.positions[i * 3 + 2] = baseZ;

    return {
      baseX,
      baseZ,
      velY: 2.0 + Math.random() * 2.0,
      velZ: (Math.random() - 0.5) * 1.2,
      lifetime: Math.random() * maxLifetime,
      maxLifetime,
    };
  }

  update(dt: number): void {
    for (let i = 0; i < this.COUNT; i++) {
      const p = this.particles[i];
      p.lifetime += dt;

      if (p.lifetime >= p.maxLifetime) {
        const reset = this.resetParticle(i);
        reset.lifetime = 0;
        this.particles[i] = reset;
        continue;
      }

      this.positions[i * 3 + 1] += p.velY * dt;
      this.positions[i * 3 + 2] += p.velZ * dt;
    }

    const posAttr = this.points.geometry.getAttribute('position') as BufferAttribute;
    posAttr.needsUpdate = true;
  }

  get object(): Points {
    return this.points;
  }
}

// ── God Ray — additive glow above cliff horizon ───────────────────────────────

function createGodRay(): { mesh: Mesh; update: (dt: number) => void } {
  const geo = new PlaneGeometry(12, 22);
  const mat = new MeshBasicMaterial({
    color: 0xa0b0c8,  // C168: cool storm light shaft
    transparent: true,
    opacity: 0.08,
    blending: AdditiveBlending,
    depthWrite: false,
    side: DoubleSide,
  });
  const mesh = new Mesh(geo, mat);
  mesh.position.set(-5, 14, -18);
  mesh.rotation.z = 0.18; // slight tilt toward cliff

  let elapsed = 0;
  const update = (dt: number): void => {
    elapsed += dt;
    // Subtle opacity pulse 0.12..0.28 — reduced range for mobile readability
    (mesh.material as MeshBasicMaterial).opacity =
      0.05 + Math.sin(elapsed * (Math.PI * 2) / 4.0) * 0.03;
  };

  return { mesh, update };
}

// ── Star / Constellation Background ─────────────────────────────────────────
// C229: Static 2D star field on a canvas behind the rune rain (z-index:0).
// Stars are drawn once (no RAF) — saves GPU. Positions are deterministic so the
// constellation looks the same on every load (seeded via Math.sin hash).

interface StarCanvasResult {
  canvas: HTMLCanvasElement;
  dispose: () => void;
}

function createStarConstellationCanvas(container: HTMLElement): StarCanvasResult {
  const canvas = document.createElement('canvas');
  canvas.id = 'menu-stars-canvas';
  canvas.style.cssText = 'position:fixed;inset:0;pointer-events:none;z-index:0;';
  canvas.width = window.innerWidth;
  canvas.height = window.innerHeight;

  // Insert as first child so it sits behind everything else in the container
  if (container.firstChild) {
    container.insertBefore(canvas, container.firstChild);
  } else {
    container.appendChild(canvas);
  }

  const ctx = canvas.getContext('2d')!;
  const W = canvas.width;
  const H = canvas.height;
  const STAR_COUNT = 120;

  // Deterministic pseudo-random via sin hash — same layout every load
  const hash = (n: number): number => {
    const v = Math.sin(n * 127.1) * 43758.5453;
    return v - Math.floor(v); // fractional part in [0, 1)
  };

  // Build star positions
  const sx = new Float32Array(STAR_COUNT);
  const sy = new Float32Array(STAR_COUNT);
  for (let i = 0; i < STAR_COUNT; i++) {
    sx[i] = hash(i * 1.0) * W;
    sy[i] = hash(i * 2.0 + 0.5) * H;
  }

  // Draw stars
  for (let i = 0; i < STAR_COUNT; i++) {
    const alpha = 0.05 + hash(i * 3.0 + 1.0) * 0.20; // [0.05, 0.25]
    const radius = 1.0 + hash(i * 4.0 + 2.0) * 1.0;   // [1, 2] px
    ctx.beginPath();
    ctx.arc(sx[i]!, sy[i]!, radius, 0, Math.PI * 2);
    ctx.fillStyle = `rgba(51,255,102,${alpha.toFixed(3)})`;
    ctx.fill();
  }

  // Draw constellation lines — 6 pairs connecting deterministic star indices
  const CONSTELLATION_PAIRS: [number, number][] = [
    [0, 7], [7, 14], [14, 3], [3, 28], [28, 45], [45, 60],
  ];
  ctx.strokeStyle = 'rgba(51,255,102,0.08)';
  ctx.lineWidth = 1;
  for (const [a, b] of CONSTELLATION_PAIRS) {
    ctx.beginPath();
    ctx.moveTo(sx[a]!, sy[a]!);
    ctx.lineTo(sx[b]!, sy[b]!);
    ctx.stroke();
  }

  return {
    canvas,
    dispose: () => {
      if (canvas.parentNode) canvas.parentNode.removeChild(canvas);
    },
  };
}

// ── Ogham Rune Rain ──────────────────────────────────────────────────────────
// C297: Particle-based rune rain — 40 individual ogham characters falling
// behind the text overlay (z-index:0). CeltOS green only, idempotent guard.

interface RuneParticle {
  x: number;
  y: number;
  speed: number;
  char: string;
  opacity: number;
  size: number;
}

interface RuneRainResult {
  canvas: HTMLCanvasElement;
  dispose: () => void;
}

let _runeRainRafId = 0;

function createRuneRainCanvas(container: HTMLElement): RuneRainResult {
  // Idempotent guard — reuse canvas if already present
  const existing = document.getElementById('menu-rune-rain') as HTMLCanvasElement | null;
  if (existing) {
    return {
      canvas: existing,
      dispose: () => {
        cancelAnimationFrame(_runeRainRafId);
        existing.remove();
      },
    };
  }

  const canvas = document.createElement('canvas');
  canvas.id = 'menu-rune-rain';
  canvas.style.cssText =
    'position:absolute;inset:0;pointer-events:none;z-index:0;opacity:0.18;';
  canvas.width = container.clientWidth || window.innerWidth;
  canvas.height = container.clientHeight || window.innerHeight;
  container.appendChild(canvas);

  const ctx = canvas.getContext('2d')!;
  const OGHAM_CHARS: string[] = [
    'ᚁ','ᚂ','ᚃ','ᚄ','ᚅ','ᚆ','ᚇ','ᚈ','ᚉ','ᚊ',
    'ᚋ','ᚌ','ᚍ','ᚎ','ᚏ','ᚐ','ᚑ','ᚒ',
  ];
  const PARTICLE_COUNT = 40;

  const makeParticle = (w: number, h: number): RuneParticle => ({
    x: Math.random() * w,
    y: Math.random() * h,
    speed: 0.4 + Math.random() * 0.8,
    char: OGHAM_CHARS[Math.floor(Math.random() * OGHAM_CHARS.length)]!,
    opacity: Math.random(),
    size: 11 + Math.floor(Math.random() * 8),
  });

  const w = canvas.width;
  const h = canvas.height;
  const particles: RuneParticle[] = Array.from({ length: PARTICLE_COUNT }, () =>
    makeParticle(w, h),
  );

  const loop = (): void => {
    const cw = canvas.width;
    const ch = canvas.height;
    ctx.clearRect(0, 0, cw, ch);

    for (const p of particles) {
      p.y += p.speed;
      if (p.y > ch) {
        p.y = -20;
        p.x = Math.random() * cw;
        p.char = OGHAM_CHARS[Math.floor(Math.random() * OGHAM_CHARS.length)]!;
        p.opacity = Math.random();
        p.size = 11 + Math.floor(Math.random() * 8);
        p.speed = 0.4 + Math.random() * 0.8;
      }
      ctx.fillStyle = `rgba(51,255,102,${(0.4 + p.opacity * 0.6).toFixed(2)})`;
      ctx.font = `${p.size}px Courier New`;
      ctx.fillText(p.char, p.x, p.y);
    }

    _runeRainRafId = requestAnimationFrame(loop);
  };

  _runeRainRafId = requestAnimationFrame(loop);

  const onResize = (): void => {
    canvas.width = container.clientWidth || window.innerWidth;
    canvas.height = container.clientHeight || window.innerHeight;
  };
  window.addEventListener('resize', onResize);

  return {
    canvas,
    dispose: () => {
      cancelAnimationFrame(_runeRainRafId);
      window.removeEventListener('resize', onResize);
      canvas.remove();
    },
  };
}

// ── C186: Floating magic orbs — Zelda/N64 title screen energy ───────────────

interface OrbData {
  orbitRadius: number;
  orbitSpeed: number;
  orbitPhase: number;
  orbitTilt: number;
  bobFreq: number;
  bobAmp: number;
  bobPhase: number;
  baseY: number;
  light: PointLight;
}

function createMenuOrbs(): { group: Group; update: (dt: number) => void } {
  const group = new Group();

  const orbConfigs = [
    // [color, meshR, orbitR, speed, phase, tilt, baseY]
    [0x33ff66, 0.09, 6.0,  0.22, 0.0,  0.15, 2.5],   // CeltOS green
    [0x22aaff, 0.07, 8.5,  0.18, 1.1,  0.25, 3.5],   // blue
    [0x88ffaa, 0.06, 5.2,  0.30, 2.3,  0.10, 1.8],   // pale green
    [0xaaffcc, 0.08, 7.0,  0.15, 0.7,  0.35, 4.0],   // cyan-mint
    [0x44ff88, 0.05, 9.5,  0.25, 3.5,  0.20, 2.0],   // vivid green
    [0x22ff88, 0.10, 4.5,  0.35, 4.8,  0.05, 3.0],   // emerald
  ] as const;

  const orbData: OrbData[] = [];

  for (const [color, meshR, orbitR, speed, phase, tilt, baseY] of orbConfigs) {
    const orbMat = new MeshStandardMaterial({
      color,
      emissive: color,
      emissiveIntensity: 1.0,
      roughness: 0.3,
      metalness: 0.1,
    });
    const orb = new Mesh(new SphereGeometry(meshR, 6, 5), orbMat);
    group.add(orb);

    const light = new PointLight(color, 0.8, 6);
    group.add(light);

    orbData.push({
      orbitRadius: orbitR,
      orbitSpeed: speed,
      orbitPhase: phase,
      orbitTilt: tilt,
      bobFreq: 0.7 + Math.random() * 0.6,
      bobAmp: 0.25,
      bobPhase: Math.random() * Math.PI * 2,
      baseY,
      light,
    });
    (light as PointLight & { _orbMesh: Mesh })._orbMesh = orb;
  }

  let elapsed = 0;
  const update = (dt: number): void => {
    elapsed += dt;
    orbData.forEach((d, i) => {
      const angle = elapsed * d.orbitSpeed + d.orbitPhase;
      const x = Math.cos(angle) * d.orbitRadius;
      const z = (Math.sin(angle) * d.orbitRadius * Math.cos(d.orbitTilt)) - 4;
      const y = d.baseY + Math.sin(elapsed * d.bobFreq + d.bobPhase) * d.bobAmp;

      const l = orbData[i]!.light;
      const orb = (l as PointLight & { _orbMesh: Mesh })._orbMesh;
      orb.position.set(x, y, z);
      l.position.set(x, y, z);

      // Gentle intensity breathing
      l.intensity = 0.8 + Math.sin(elapsed * 1.3 + d.orbitPhase) * 0.25;
    });
  };

  return { group, update };
}

// ── C385: Scrolling Celtic knotwork border ────────────────────────────────────
// CSS-animated SVG decorative border along screen edges.
// Thin interlaced diamond/chevron paths in CeltOS green (#33ff66) at low opacity.
// Pattern scrolls along top/bottom (horizontal) and left/right (vertical).

function ensureKnotworkStyle385(): void {
  if (document.getElementById('knotwork-style-385')) return;
  const s = document.createElement('style');
  s.id = 'knotwork-style-385';
  s.textContent = [
    '@keyframes knot-scroll-h{from{transform:translateX(0)}to{transform:translateX(-200px)}}',
    '@keyframes knot-scroll-v{from{transform:translateY(0)}to{transform:translateY(-200px)}}',
    '.knotwork-top-385,.knotwork-bottom-385{animation:knot-scroll-h 12s linear infinite;}',
    '.knotwork-left-385,.knotwork-right-385{animation:knot-scroll-v 12s linear infinite;}',
  ].join('');
  document.head.appendChild(s);
}

function createKnotworkBorder385(container: HTMLElement): HTMLElement {
  ensureKnotworkStyle385();

  const wrap = document.createElement('div');
  wrap.id = 'knotwork-border-385';
  wrap.style.cssText = 'position:fixed;inset:0;pointer-events:none;z-index:1;overflow:hidden;';

  const edges: { side: string; style: string }[] = [
    { side: 'top',    style: 'position:absolute;top:0;left:0;right:0;height:20px;' },
    { side: 'bottom', style: 'position:absolute;bottom:0;left:0;right:0;height:20px;' },
    { side: 'left',   style: 'position:absolute;top:0;left:0;bottom:0;width:20px;' },
    { side: 'right',  style: 'position:absolute;top:0;right:0;bottom:0;width:20px;' },
  ];

  edges.forEach(({ side, style }) => {
    const isVert = side === 'left' || side === 'right';
    const svgW = isVert ? 20 : 200;
    const svgH = isVert ? 200 : 20;

    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('width', String(svgW));
    svg.setAttribute('height', String(svgH));
    svg.style.cssText = style + 'overflow:visible;';

    const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    if (!isVert) {
      path.setAttribute('d', [
        'M0,10 L10,4 L20,10 L30,4 L40,10 L50,4 L60,10 L70,4 L80,10 L90,4',
        'L100,10 L110,4 L120,10 L130,4 L140,10 L150,4 L160,10 L170,4 L180,10 L190,4 L200,10',
        'M10,16 L20,10 L30,16 L40,10 L50,16 L60,10 L70,16 L80,10 L90,16 L100,10',
        'L110,16 L120,10 L130,16 L140,10 L150,16 L160,10 L170,16 L180,10 L190,16 L200,10',
      ].join(' '));
    } else {
      path.setAttribute('d', [
        'M10,0 L4,10 L10,20 L4,30 L10,40 L4,50 L10,60 L4,70 L10,80 L4,90',
        'L10,100 L4,110 L10,120 L4,130 L10,140 L4,150 L10,160 L4,170 L10,180 L4,190 L10,200',
        'M16,10 L10,20 L16,30 L10,40 L16,50 L10,60 L16,70 L10,80 L16,90 L10,100',
        'L16,110 L10,120 L16,130 L10,140 L16,150 L10,160 L16,170 L10,180 L16,190 L10,200',
      ].join(' '));
    }
    path.setAttribute('stroke', '#33ff66');
    path.setAttribute('stroke-width', '1');
    path.setAttribute('fill', 'none');
    path.setAttribute('opacity', '0.14');
    svg.appendChild(path);

    svg.classList.add(`knotwork-${side}-385`);
    wrap.appendChild(svg);
  });

  container.appendChild(wrap);
  return wrap;
}

function destroyKnotworkBorder385(): void {
  const el = document.getElementById('knotwork-border-385');
  if (el && el.parentNode) el.parentNode.removeChild(el);
  const styleEl = document.getElementById('knotwork-style-385');
  if (styleEl && styleEl.parentNode) styleEl.parentNode.removeChild(styleEl);
}

// ── Public: initMainMenu ─────────────────────────────────────────────────────

export function initMainMenu(container: HTMLElement): MainMenuResult {
  // C168: Dark stormy Atlantic coast — near-black bg, heavy overcast fog
  const scene = new Scene();
  scene.background = new Color(0x181c28);
  scene.fog = new FogExp2(0x181c28, 0.012);

  // Camera: fixed high angle, looking right-to-left over the cliff
  // C134/MM-08: guard against Infinity aspect ratio when container has not yet been laid out
  // (clientHeight === 0 during SSR or before first paint). Infinity aspect clips all geometry.
  const camera = new PerspectiveCamera(
    55,
    container.clientWidth / (container.clientHeight > 0 ? container.clientHeight : 1),
    0.1,
    600
  );
  camera.position.set(-8, 18, 28);
  camera.lookAt(new Vector3(4, 2, -10));

  // Renderer — no antialias keeps the sharp polygon edges of flat shading
  const renderer = new WebGLRenderer({
    antialias: false,
    alpha: false,
  });
  renderer.setSize(container.clientWidth, container.clientHeight);
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.5));
  renderer.toneMapping = NoToneMapping;
  container.appendChild(renderer.domElement);
  renderer.domElement.setAttribute('role', 'img');
  renderer.domElement.setAttribute('aria-label', 'Scène 3D — Côte rocheuse de Bretagne, tour de Merlin sous un ciel orageux');

  // Resize handler
  const onResize = (): void => {
    camera.aspect = container.clientWidth / (container.clientHeight > 0 ? container.clientHeight : 1);
    camera.updateProjectionMatrix();
    renderer.setSize(container.clientWidth, container.clientHeight);
  };
  window.addEventListener('resize', onResize);

  // C168: Stormy overcast lighting — cool grey-blue, dim but readable
  const ambient = new AmbientLight(0x304458, 0.35);
  scene.add(ambient);

  const sunLight = new DirectionalLight(0x8898c0, 0.9); // muted stormy blue-white
  sunLight.position.set(-15, 35, 20);
  scene.add(sunLight);

  const fillLight = new DirectionalLight(0x1a3060, 0.25); // dark blue fill
  fillLight.position.set(10, 10, 30);
  scene.add(fillLight);

  // Build scene
  const skyBox = createSkyBox();
  scene.add(skyBox);

  const clouds = createClouds();
  scene.add(clouds.group);

  const ocean = createLowPolyOcean();
  scene.add(ocean.mesh);
  scene.add(ocean.horizonPlane);

  const foam = createFoamPatches();
  scene.add(foam.group);

  const distantSilhouette = createDistantSilhouette();
  scene.add(distantSilhouette);

  const cliff = createCliff();
  scene.add(cliff);

  const path = createPath();
  scene.add(path);

  const tower = createTower();
  scene.add(tower);

  const veg = createVegetation();
  scene.add(veg);

  const spray = new SeaSpraySystem();
  scene.add(spray.object);

  // T064: God ray above cliff horizon
  const godRay = createGodRay();
  scene.add(godRay.mesh);

  // C186: Floating magic orbs — N64 title screen energy
  const orbs = createMenuOrbs();
  scene.add(orbs.group);

  // ── C402: Aurora borealis curtain — two billowing green planes in sky ─────────
  let auroraMesh1: Mesh | null = null;
  let auroraMesh2: Mesh | null = null;
  let auroraT = 0;
  let auroraPos1: Float32Array | null = null;
  let auroraPos2: Float32Array | null = null;
  let auroraOrigY1: Float32Array | null = null;
  let auroraOrigY2: Float32Array | null = null;

  {
    // Strip 1: wide primary curtain
    const geo1 = new PlaneGeometry(40, 8, 30, 10);
    const mat1 = new MeshBasicMaterial({
      color: 0x33ff66,
      transparent: true,
      opacity: 0.08,
      side: DoubleSide,
      depthWrite: false,
    });
    const origY1 = new Float32Array(geo1.attributes['position'].count);
    for (let i = 0; i < geo1.attributes['position'].count; i++) {
      origY1[i] = (geo1.attributes['position'] as BufferAttribute).getY(i);
    }
    auroraOrigY1 = origY1;
    auroraPos1 = geo1.attributes['position'].array as Float32Array;
    auroraMesh1 = new Mesh(geo1, mat1);
    auroraMesh1.position.set(0, 12, -30);
    auroraMesh1.rotation.x = 0.1;
    scene.add(auroraMesh1);

    // Strip 2: thinner secondary curtain, slight offset
    const geo2 = new PlaneGeometry(35, 4, 25, 8);
    const mat2 = new MeshBasicMaterial({
      color: 0x33ff66,
      transparent: true,
      opacity: 0.04,
      side: DoubleSide,
      depthWrite: false,
    });
    const origY2 = new Float32Array(geo2.attributes['position'].count);
    for (let i = 0; i < geo2.attributes['position'].count; i++) {
      origY2[i] = (geo2.attributes['position'] as BufferAttribute).getY(i);
    }
    auroraOrigY2 = origY2;
    auroraPos2 = geo2.attributes['position'].array as Float32Array;
    auroraMesh2 = new Mesh(geo2, mat2);
    auroraMesh2.position.set(2, 15, -32);
    auroraMesh2.rotation.x = 0.1;
    scene.add(auroraMesh2);
  }

  // ── C356: Ambient magical dust — 120 tiny green motes floating slowly upward ──
  let ambientParticles356: Points | null = null;
  let ambientParticlePositions356: Float32Array | null = null;
  let ambientParticlePhases356: Float32Array | null = null;
  {
    const COUNT = 120;
    const positions = new Float32Array(COUNT * 3);
    const phases = new Float32Array(COUNT);
    for (let i = 0; i < COUNT; i++) {
      positions[i * 3]     = (Math.random() - 0.5) * 30;       // x: -15 to 15
      positions[i * 3 + 1] = (Math.random() - 0.5) * 16;       // y: -8 to 8
      positions[i * 3 + 2] = (Math.random() - 0.5) * 6 - 5;    // z: behind scene
      phases[i] = Math.random() * Math.PI * 2;
    }
    const geom356 = new BufferGeometry();
    geom356.setAttribute('position', new BufferAttribute(positions, 3));
    const mat356 = new PointsMaterial({ color: 0x33ff66, size: 0.06, transparent: true, opacity: 0.3, depthWrite: false });
    ambientParticles356 = new Points(geom356, mat356);
    ambientParticlePositions356 = positions;
    ambientParticlePhases356 = phases;
    scene.add(ambientParticles356);
  }

  // ── C373: Celtic moon — large dark green sphere in background ──────────────
  let moonMesh373: Mesh | null = null;
  let moonLight373: PointLight | null = null;
  let moonCloudT373 = -1;
  let moonNextCloud373 = 8.0;

  // ── C373: Celtic moon construction ──────────────────────────────────────────
  {
    const moonGeo = new SphereGeometry(3.5, 16, 12);
    const moonMat = new MeshStandardMaterial({
      color: 0x0d2a0d,
      roughness: 0.9,
      metalness: 0.0,
      emissive: new Color(0x0a1f0a),
      emissiveIntensity: 0.15,
    });
    moonMesh373 = new Mesh(moonGeo, moonMat);
    moonMesh373.position.set(8, 7, -25);
    scene.add(moonMesh373);

    moonLight373 = new PointLight(0x33ff66, 0.04, 30);
    moonLight373.position.set(8, 7, -22);
    scene.add(moonLight373);

    moonNextCloud373 = 8.0 + Math.random() * 5.0;
  }

  // ── C321: CeltOS title overlay — letter-by-letter reveal + glow pulse ────────
  // DOM overlay on canvas: M.E.R.L.I.N. each letter fades+slides in individually.
  container.style.position = container.style.position || 'relative';

  const titleOverlay = document.createElement('div');
  titleOverlay.style.cssText = [
    'position:absolute;top:18%;left:50%;transform:translateX(-50%);',
    'pointer-events:none;z-index:10;text-align:center;',
    'display:flex;flex-direction:column;align-items:center;gap:8px;',
  ].join('');
  container.appendChild(titleOverlay);

  // titleEl wraps individual letter <span>s
  const titleEl = document.createElement('div');
  titleEl.style.cssText = [
    'font-family:Courier New,monospace;font-size:28px;',
    'color:#33ff66;letter-spacing:0.4em;',
    'text-shadow:0 0 10px rgba(51,255,102,0.3);',
    'display:inline-flex;',
  ].join('');
  titleOverlay.appendChild(titleEl);

  const subtitleEl = document.createElement('div');
  subtitleEl.style.cssText = [
    'font-size:10px;font-family:"Courier New",monospace;',
    'color:rgba(51,255,102,0.5);letter-spacing:6px;',
    'opacity:0;',
    'transform:translateY(4px);',
    'transition:opacity 600ms ease,transform 600ms ease;',
  ].join('');
  subtitleEl.textContent = 'LE JEU DES OGHAMS';
  titleOverlay.appendChild(subtitleEl);

  // C200: CTA pulse prompt — "APPUYEZ SUR ENTRÉE"
  const ctaEl = document.createElement('div');
  ctaEl.style.cssText = [
    'position:absolute;bottom:14%;width:100%;text-align:center;',
    'font:0.75rem "Courier New",monospace;',
    'color:rgba(51,255,102,0.6);letter-spacing:0.2em;',
    'animation:celtos-cta-pulse 1.8s ease infinite;',
    'pointer-events:none;',
  ].join('');
  ctaEl.textContent = 'APPUYEZ SUR ENTRÉE';
  container.appendChild(ctaEl);

  // Inject keyframes — letter reveal + glow pulse + CTA pulse (idempotent via ID)
  if (!document.getElementById('merlin-glow-keyframes')) {
    const styleTag = document.createElement('style');
    styleTag.id = 'merlin-glow-keyframes';
    styleTag.textContent = [
      '@keyframes title-letter-in{',
      'from{opacity:0;transform:translateY(-8px);}',
      'to{opacity:1;transform:translateY(0);}',
      '}',
      '@keyframes merlin-glow-pulse{',
      '0%,100%{text-shadow:0 0 8px rgba(51,255,102,0.8);}',
      '50%{text-shadow:0 0 18px rgba(51,255,102,1.0),0 0 32px rgba(51,255,102,0.4);}',
      '}',
    ].join('');
    document.head.appendChild(styleTag);
  }

  // C200: CTA pulse keyframe (separate guard ID)
  if (!document.getElementById('celtos-title-anim')) {
    const s = document.createElement('style');
    s.id = 'celtos-title-anim';
    s.textContent = '@keyframes celtos-cta-pulse{0%,100%{opacity:0.3}50%{opacity:1}}';
    document.head.appendChild(s);
  }

  // C321: Letter-by-letter reveal — each letter is a <span> animated individually.
  // Fire whoosh SFX at start, then stagger 80ms per letter (200ms duration each).
  // After all letters (~720ms), trigger glow pulse: strong → fade to resting glow over 800ms.
  // Subtitle fades in from 500ms offset.
  const TITLE_TEXT = 'M.E.R.L.I.N.';
  const _titleTimers: number[] = [];

  // Fire whoosh SFX immediately as reveal begins
  window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'whoosh' } }));

  TITLE_TEXT.split('').forEach((ch, i) => {
    const span = document.createElement('span');
    span.textContent = ch;
    span.style.cssText = [
      'opacity:0;',
      'display:inline-block;',
      'animation:title-letter-in 200ms ease-out forwards;',
      `animation-delay:${80 * i}ms;`,
    ].join('');
    titleEl.appendChild(span);
  });

  // After all letters revealed (~80ms × 11 + 200ms = ~1080ms), trigger glow pulse then settle
  const REVEAL_DONE = 80 * (TITLE_TEXT.length - 1) + 220; // last letter finishes
  const glowTid = window.setTimeout(() => {
    titleEl.style.transition = 'text-shadow 800ms ease-out';
    titleEl.style.textShadow = '0 0 30px rgba(51,255,102,0.6),0 0 60px rgba(51,255,102,0.3)';
    const settleTid = window.setTimeout(() => {
      titleEl.style.textShadow = '0 0 10px rgba(51,255,102,0.3)';
    }, 800);
    _titleTimers.push(settleTid);
  }, REVEAL_DONE);
  _titleTimers.push(glowTid);

  // Subtitle fades in from 500ms after reveal start
  const subTid = window.setTimeout(() => {
    subtitleEl.style.opacity = '0.5';
    subtitleEl.style.transform = 'translateY(0)';
  }, 500);
  _titleTimers.push(subTid);

  let elapsedTime = 0;

  // Dolly walk state — camera animates from cliff position toward tower door
  const DOLLY_DURATION = 6.0; // seconds
  const DOLLY_CAM_START  = new Vector3(-8, 18, 28);
  const DOLLY_CAM_END    = new Vector3(3, 8, 4);    // approach tower, lower, closer
  const DOLLY_LOOK_START = new Vector3(4, 2, -10);
  const DOLLY_LOOK_END   = new Vector3(6, 8, -13);  // tower door area
  let _dollyActive = false;
  let _dollyElapsed = 0;
  let _dollyOnComplete: (() => void) | null = null;
  // C157: spray fade during dolly — opacity lerps 0.55→0 over dolly duration
  let _dollySprayFade = false;

  const _dollyLook = new Vector3();

  const update = (dt: number): void => {
    elapsedTime += dt;
    ocean.update(elapsedTime);
    clouds.update(elapsedTime);
    foam.update(elapsedTime);
    spray.update(dt);
    godRay.update(dt);
    orbs.update(dt);

    // C402: animate aurora borealis curtains
    auroraT += dt * 0.4;
    if (auroraMesh1 !== null && auroraPos1 !== null && auroraOrigY1 !== null) {
      for (let i = 0; i < auroraPos1.length; i += 3) {
        const x = auroraPos1[i]!;
        const baseY = auroraOrigY1[i / 3]!;
        auroraPos1[i + 1] =
          baseY +
          Math.sin(auroraT + x * 0.3) * 1.5 +
          Math.sin(auroraT * 0.7 + x * 0.15) * 0.8;
      }
      (auroraMesh1.geometry as PlaneGeometry).attributes['position'].needsUpdate = true;
      (auroraMesh1.material as MeshBasicMaterial).opacity =
        0.06 + Math.sin(auroraT * 0.5) * 0.03;
    }
    if (auroraMesh2 !== null && auroraPos2 !== null && auroraOrigY2 !== null) {
      const t2 = auroraT + 1.2;
      for (let i = 0; i < auroraPos2.length; i += 3) {
        const x = auroraPos2[i]!;
        const baseY = auroraOrigY2[i / 3]!;
        auroraPos2[i + 1] =
          baseY +
          Math.sin(t2 + x * 0.3) * 1.0 +
          Math.sin(t2 * 0.7 + x * 0.15) * 0.5;
      }
      (auroraMesh2.geometry as PlaneGeometry).attributes['position'].needsUpdate = true;
    }

    // C373: animate Celtic moon — slow rotation + cloud sweep
    if (moonMesh373) {
      moonMesh373.rotation.y += dt * 0.015;

      moonNextCloud373 -= dt;
      if (moonNextCloud373 <= 0 && moonCloudT373 < 0) {
        moonCloudT373 = 0;
        moonNextCloud373 = 8.0 + Math.random() * 6.0;
      }
      if (moonCloudT373 >= 0) {
        moonCloudT373 += dt;
        const mat = moonMesh373.material as MeshStandardMaterial;
        if (moonCloudT373 < 1.0) {
          mat.emissiveIntensity = 0.15 + (moonCloudT373 / 1.0) * 0.10;
        } else if (moonCloudT373 < 2.0) {
          mat.emissiveIntensity = 0.25 - ((moonCloudT373 - 1.0) / 1.0) * 0.10;
        } else {
          mat.emissiveIntensity = 0.15;
          moonCloudT373 = -1;
        }
      }
    }

    // C356: animate ambient magical dust particles
    if (ambientParticles356 !== null && ambientParticlePositions356 !== null) {
      const pos = ambientParticlePositions356;
      const COUNT = pos.length / 3;
      for (let i = 0; i < COUNT; i++) {
        pos[i * 3 + 1] += 0.003; // slow float up
        pos[i * 3]     += Math.sin(elapsedTime * 0.2 + ambientParticlePhases356![i]) * 0.001; // drift
        if (pos[i * 3 + 1] > 8) pos[i * 3 + 1] = -8; // wrap around
      }
      (ambientParticles356.geometry as BufferGeometry).attributes['position'].needsUpdate = true;
    }

    // C168: day/night cycle — slow sine oscillation (period ~180s)
    // dayT: 0=storm-night, 1=storm-day. Always stormy, never fully bright.
    const dayT = (Math.sin(elapsedTime * (Math.PI * 2) / 180) + 1) / 2;
    ambient.intensity  = 0.25 + dayT * 0.20;
    sunLight.intensity = 0.60 + dayT * 0.50;
    // Fog shifts: night 0x101020 → day 0x202838
    const fogR = 0.063 + dayT * 0.062;
    const fogG = 0.063 + dayT * 0.094;
    const fogB = 0.125 + dayT * 0.095;
    (scene.fog as FogExp2).color.setRGB(fogR, fogG, fogB);
    (scene.background as Color).setRGB(fogR, fogG, fogB);

    if (_dollyActive) {
      _dollyElapsed = Math.min(_dollyElapsed + dt, DOLLY_DURATION);
      const raw = _dollyElapsed / DOLLY_DURATION;
      // Ease-in-out sinusoidal: smooth acceleration and deceleration
      const t = 0.5 - 0.5 * Math.cos(raw * Math.PI);

      camera.position.lerpVectors(DOLLY_CAM_START, DOLLY_CAM_END, t);
      _dollyLook.lerpVectors(DOLLY_LOOK_START, DOLLY_LOOK_END, t);
      camera.lookAt(_dollyLook);

      // C157: fade spray particles and title overlay during dolly
      if (_dollySprayFade) {
        const fadeT = Math.min(raw * 1.5, 1.0); // fade completes at 2/3 of dolly
        const sprayMat = spray.object.material as PointsMaterial;
        sprayMat.opacity = 0.55 * (1 - fadeT);
        titleOverlay.style.opacity = String(1 - fadeT);
      }

      if (_dollyElapsed >= DOLLY_DURATION) {
        _dollyActive = false;
        _dollySprayFade = false;
        const cb = _dollyOnComplete;
        _dollyOnComplete = null;
        cb?.();
      }
    }

    renderer.render(scene, camera);
  };

  // Start 6-second camera walk toward tower. Calls onComplete when animation ends.
  // C157: fires mapDraw SFX at frame 0, fades spray/title overlay during walk.
  const startDolly = (onComplete: () => void): void => {
    _dollyActive = true;
    _dollyElapsed = 0;
    _dollyOnComplete = onComplete;
    _dollySprayFade = true;
    window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'mapDraw' } }));
  };

  // C171: Menu hover SFX — pointerenter on start/continue buttons
  const menuStartBtn = document.getElementById('menu-start-btn');
  const menuContinueBtn = document.getElementById('menu-continue-btn');

  const onStartHover = (): void => {
    window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'hover' } }));
  };
  const onContinueHover = (): void => {
    window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'hover' } }));
  };

  if (menuStartBtn) menuStartBtn.addEventListener('pointerenter', onStartHover);
  if (menuContinueBtn) menuContinueBtn.addEventListener('pointerenter', onContinueHover);

  // C229: Static star/constellation background canvas — lowest z-index, drawn once
  const starBg = createStarConstellationCanvas(container);

  // C176: Ogham rune rain overlay — injected behind menu DOM, above Three.js canvas
  const runeRain = createRuneRainCanvas(container);

  // C385: Scrolling Celtic knotwork border — SVG strips along all 4 screen edges
  createKnotworkBorder385(container);

  // C276: Animated Celtic border on #main-menu-overlay — conic-gradient spin
  const menuOverlayEl = document.getElementById('main-menu-overlay');
  if (!document.getElementById('menu-border-style')) {
    const borderStyle = document.createElement('style');
    borderStyle.id = 'menu-border-style';
    borderStyle.textContent = [
      '@property --border-angle{',
      'syntax:"<angle>";',
      'inherits:true;',
      'initial-value:0turn;}',
      '@keyframes celtos-border-spin{',
      'from{--border-angle:0turn}',
      'to{--border-angle:1turn}}',
      '@keyframes celtos-border-glow{',
      '0%,100%{border-color:rgba(51,255,102,0.15)}',
      '50%{border-color:rgba(51,255,102,0.55)}}',
      '.celtos-border-animated{',
      '--border-angle:0turn;',
      'border:1px solid rgba(51,255,102,0.3);',
      'padding:2px;',
      'background:',
      'linear-gradient(rgba(1,8,2,0.97),rgba(1,8,2,0.97)) padding-box,',
      'conic-gradient(',
      'from var(--border-angle),',
      'rgba(51,255,102,0.08) 0%,',
      'rgba(51,255,102,0.6) 20%,',
      'rgba(51,255,102,0.08) 40%,',
      'rgba(51,255,102,0.0) 60%,',
      'rgba(51,255,102,0.6) 80%,',
      'rgba(51,255,102,0.08) 100%',
      ') border-box;',
      'animation:celtos-border-spin 4s linear infinite,celtos-border-glow 4s ease-in-out infinite;}',
    ].join('');
    document.head.appendChild(borderStyle);
  }
  if (menuOverlayEl) menuOverlayEl.classList.add('celtos-border-animated');

  // C256: Mouse parallax on constellation canvas
  let _menuMouseX = 0;
  let _menuMouseY = 0;
  const _menuMouseHandler = (e: MouseEvent): void => {
    _menuMouseX = (e.clientX / window.innerWidth - 0.5) * 2;  // -1 to +1
    _menuMouseY = (e.clientY / window.innerHeight - 0.5) * 2; // -1 to +1
  };
  document.addEventListener('mousemove', _menuMouseHandler);
  const _parallaxInterval: ReturnType<typeof setInterval> = setInterval(() => {
    const maxShift = 12;
    starBg.canvas.style.transform =
      `translate(${(-_menuMouseX * maxShift).toFixed(2)}px, ${(-_menuMouseY * maxShift).toFixed(2)}px)`;
  }, 16);

  const dispose = (): void => {
    window.removeEventListener('resize', onResize);
    // C171: remove hover listeners
    if (menuStartBtn) menuStartBtn.removeEventListener('pointerenter', onStartHover);
    if (menuContinueBtn) menuContinueBtn.removeEventListener('pointerenter', onContinueHover);
    // C256: remove mouse parallax listeners and interval
    document.removeEventListener('mousemove', _menuMouseHandler);
    clearInterval(_parallaxInterval);
    // C229: remove static star background canvas
    starBg.dispose();
    // C176: stop rune rain RAF and remove canvas
    runeRain.dispose();
    // C385: remove knotwork border SVG overlay and its style tag
    destroyKnotworkBorder385();
    // C200: clear all typewriter timers
    _titleTimers.forEach((id) => window.clearTimeout(id));
    _titleTimers.length = 0;
    // C200: remove CTA element
    if (ctaEl.parentNode) ctaEl.parentNode.removeChild(ctaEl);
    // C200: remove CTA style element
    const ctaStyle = document.getElementById('celtos-title-anim');
    if (ctaStyle && ctaStyle.parentNode) ctaStyle.parentNode.removeChild(ctaStyle);
    // C276: remove border style and class
    const borderStyleEl = document.getElementById('menu-border-style');
    if (borderStyleEl && borderStyleEl.parentNode) borderStyleEl.parentNode.removeChild(borderStyleEl);
    if (menuOverlayEl) menuOverlayEl.classList.remove('celtos-border-animated');
    // C157: remove title overlay DOM
    if (titleOverlay.parentNode) {
      titleOverlay.parentNode.removeChild(titleOverlay);
    }
    // C356: remove ambient particle field
    if (ambientParticles356 !== null) {
      scene.remove(ambientParticles356);
      ambientParticles356 = null;
    }
    ambientParticlePositions356 = null;
    ambientParticlePhases356 = null;

    // C402: dispose aurora curtains
    if (auroraMesh1) {
      scene.remove(auroraMesh1);
      auroraMesh1.geometry.dispose();
      (auroraMesh1.material as MeshBasicMaterial).dispose();
      auroraMesh1 = null;
    }
    auroraPos1 = null;
    auroraOrigY1 = null;
    if (auroraMesh2) {
      scene.remove(auroraMesh2);
      auroraMesh2.geometry.dispose();
      (auroraMesh2.material as MeshBasicMaterial).dispose();
      auroraMesh2 = null;
    }
    auroraPos2 = null;
    auroraOrigY2 = null;

    // C373: dispose Celtic moon
    if (moonMesh373) {
      scene.remove(moonMesh373);
      moonMesh373.geometry.dispose();
      (moonMesh373.material as MeshStandardMaterial).dispose();
      moonMesh373 = null;
    }
    if (moonLight373) {
      scene.remove(moonLight373);
      moonLight373.dispose();
      moonLight373 = null;
    }

    scene.traverse((obj) => {
      if (obj instanceof Mesh || obj instanceof Points) {
        obj.geometry.dispose();
        if (Array.isArray(obj.material)) {
          obj.material.forEach((m) => m.dispose());
        } else {
          (obj.material as Material).dispose();
        }
      }
    });
    renderer.dispose();
    if (renderer.domElement.parentNode) {
      renderer.domElement.parentNode.removeChild(renderer.domElement);
    }
  };

  return { renderer, update, startDolly, dispose };
}
