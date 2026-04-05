// ═══════════════════════════════════════════════════════════════════════════════
// Main Menu Scene — Cycle 26 — Low-poly coastal cliff + tower
// Reference: dark stormy coast, flat-shaded polygons throughout.
// Camera: fixed high angle (-8,18,28) looking (4,2,-10). World animates.
// flatShading: true on ALL MeshStandardMaterial = the key low-poly look.
// ═══════════════════════════════════════════════════════════════════════════════

import { AdditiveBlending, AmbientLight, BackSide, BoxGeometry, BufferAttribute, BufferGeometry, CircleGeometry, Color, ConeGeometry, CylinderGeometry, DirectionalLight, DoubleSide, FogExp2, Group, Line, LineBasicMaterial, Material, Mesh, MeshBasicMaterial, MeshStandardMaterial, NoToneMapping, PerspectiveCamera, PlaneGeometry, PointLight, Points, PointsMaterial, Scene, Shape, ShapeGeometry, SphereGeometry, TorusGeometry, Vector3, WebGLRenderer } from 'three';

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
let _runeRainContainer406: HTMLDivElement | null = null;
let _mountainGroup409: Group | null = null;
let _mountainT409 = 0;

// C414: shooting star comet streaks
const _comets414: {
  line: Line;
  active: boolean;
  t: number;
  duration: number;
  startX: number; startY: number; startZ: number;
  dx: number; dy: number;
  nextFire: number;
}[] = [];
let _cometSceneRef414: Scene | null = null;

// C419 — rolling ground fog
const _fogPlanes419: Mesh[] = [];
let _fogT419 = 0;

// C423 — Crann Bethadh (Celtic Tree of Life)
let _crannGroup423: Group | null = null;
let _crannT423 = 0;
let _crannLeafLight423: PointLight | null = null;

// C427 — distant stone circle silhouette
let _stoneCircleGroup427: Group | null = null;
let _stoneCircleT427 = 0;
let _stoneCircleLight427: PointLight | null = null;

// C431 — CeltOS boot terminal
let _celtosTerminal431: HTMLDivElement | null = null;
let _celtosInterval431: ReturnType<typeof setInterval> | null = null;

// C434 — distant lightning storm
let _stormGroup434: Group | null = null;
let _stormT434 = 0;
let _stormFlashTimer434 = 0;
let _stormNextFlash434 = 6 + Math.random() * 10;
const _lightningBolts434: Line[] = [];
let _stormAmbientLight434: PointLight | null = null;
let _stormFlashActive434 = false;
let _stormFlashDur434 = 0;

// C445 — Celtic knotwork portal ring
let _portalGroup445: Group | null = null;
let _portalT445: number = 0;
let _portalGlyphs445: Mesh[] = [];
let _portalRingMat445: MeshBasicMaterial | null = null;

// C450 — Sacred crane flock V-formation
let craneGroup450: Group | null = null;
let craneT450: number = 0;
let craneWingPairs450: { left: Mesh; right: Mesh }[] = [];

// C455 — Towering Ogham obelisk with glowing carved inscriptions
let obeliskGroup455: Group | null = null;
let obeliskT455: number = 0;
let obeliskGlyphs455: Mesh[] = [];
let obeliskSurgeTimer455: number = 30;
let obeliskSurgeActive455: boolean = false;
let obeliskSurgeT455: number = 0;

// C460 — Ghostly Celtic longship sailing across the distant background
let longshipGroup460: Group | null = null;
let longshipT460: number = 0;

// C465 — Spectral ancestor procession circling in the far background
let ancestorGroup465: Group | null = null;
let ancestorT465: number = 0;
let ancestorFigures465: Group[] = [];

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

    // C409: glow pulse on mountain snow-cap
    if (_mountainGroup409) {
      _mountainT409 += dt;
      const glowM = _mountainGroup409.children[3] as Mesh;
      if (glowM) {
        (glowM.material as MeshBasicMaterial).opacity = 0.06 + Math.sin(_mountainT409 * 0.4) * 0.03;
      }
    }

    // C414: shooting star comet streaks
    _comets414.forEach(comet => {
      if (!comet.active) {
        comet.nextFire -= dt;
        if (comet.nextFire <= 0) {
          comet.active = true;
          comet.t = 0;
          comet.startX = -20 + Math.random() * 10;
          comet.startY = 8 + Math.random() * 6;
          comet.startZ = -45;
          comet.dx = 18 + Math.random() * 8;
          comet.dy = -(2 + Math.random() * 3);
          comet.duration = 0.8 + Math.random() * 0.4;
          comet.nextFire = 10 + Math.random() * 12;
          (comet.line.material as LineBasicMaterial).opacity = 0.85;
        }
      } else {
        comet.t += dt;
        const progress = comet.t / comet.duration;
        if (progress >= 1.0) {
          comet.active = false;
          (comet.line.material as LineBasicMaterial).opacity = 0.0;
          return;
        }
        const positions = comet.line.geometry.attributes['position'] as BufferAttribute;
        const TAIL = 8;
        for (let pi = 0; pi < TAIL; pi++) {
          const tailT = Math.max(0, progress - pi * 0.018);
          const tx = comet.startX + comet.dx * tailT;
          const ty = comet.startY + comet.dy * tailT;
          positions.setXYZ(pi, tx, ty, comet.startZ);
        }
        positions.needsUpdate = true;
        const fade = progress < 0.7 ? 1.0 : 1.0 - (progress - 0.7) / 0.3;
        (comet.line.material as LineBasicMaterial).opacity = 0.85 * fade;
      }
    });

    // C419: animate rolling ground fog
    if (_fogPlanes419.length > 0) {
      _fogT419 += dt;
      _fogPlanes419.forEach(plane => {
        const { speed, baseX, phase } = plane.userData as { speed: number; baseX: number; phase: number };
        plane.position.x = baseX + Math.sin(_fogT419 * speed + phase) * 4.0;
        const mat = plane.material as MeshBasicMaterial;
        mat.opacity = 0.14 + Math.sin(_fogT419 * 0.3 + phase) * 0.06;
      });
    }

    // C423: animate Crann Bethadh tree sway and leaf light pulse
    if (_crannGroup423) {
      _crannT423 += dt;
      _crannGroup423.rotation.z = Math.sin(_crannT423 * 0.15) * 0.015;
      if (_crannLeafLight423) {
        _crannLeafLight423.intensity = 0.12 + Math.sin(_crannT423 * 0.5) * 0.05;
      }
    }

    // C427: stone circle ancient energy pulse
    if (_stoneCircleGroup427 && _stoneCircleLight427) {
      _stoneCircleT427 += dt;
      // Very slow energy pulse — ancient and steady
      _stoneCircleLight427.intensity = 0.06 + Math.sin(_stoneCircleT427 * 0.35) * 0.03;
    }

    // C434: distant lightning storm
    if (_stormGroup434) {
      _stormT434 += dt;
      _stormFlashTimer434 += dt;

      // Trigger lightning
      if (_stormFlashTimer434 >= _stormNextFlash434 && !_stormFlashActive434) {
        _stormFlashActive434 = true;
        _stormFlashDur434 = 0;
        _stormNextFlash434 = 8 + Math.random() * 12;
        _stormFlashTimer434 = 0;

        // Randomize bolt paths (in group-local space, from cloud base downward)
        const numBolts = 1 + Math.floor(Math.random() * 3);
        _lightningBolts434.forEach((bolt, bi) => {
          if (bi < numBolts) {
            const sx = (Math.random() - 0.5) * 5;
            const pts = [
              new Vector3(sx, -2, 0),
              new Vector3(sx + (Math.random() - 0.5) * 1.5, -4.5, 0),
              new Vector3(sx + (Math.random() - 0.5) * 2, -7, 0),
              new Vector3(sx + (Math.random() - 0.5) * 1, -9, 0),
            ];
            bolt.geometry.setFromPoints(pts);
            (bolt.material as LineBasicMaterial).opacity = 0.95;
          } else {
            (bolt.material as LineBasicMaterial).opacity = 0.0;
          }
        });
      }

      if (_stormFlashActive434) {
        _stormFlashDur434 += dt;
        // Flash: bright for 0.08s, then fast fade
        const flashT = _stormFlashDur434;
        let boltOpacity = 0;
        if (flashT < 0.08) boltOpacity = 0.95;
        else if (flashT < 0.25) boltOpacity = (1.0 - (flashT - 0.08) / 0.17) * 0.95;
        else {
          _stormFlashActive434 = false;
          boltOpacity = 0;
        }
        _lightningBolts434.forEach(bolt => {
          if ((bolt.material as LineBasicMaterial).opacity > 0)
            (bolt.material as LineBasicMaterial).opacity = boltOpacity;
        });
        if (_stormAmbientLight434) _stormAmbientLight434.intensity = boltOpacity * 0.4;
      } else {
        if (_stormAmbientLight434) _stormAmbientLight434.intensity = 0.015 + Math.sin(_stormT434 * 0.3) * 0.008;
      }
    }

    // C445: Celtic knotwork portal ring
    _portalT445 += dt;
    if (_portalGroup445) {
      _portalGroup445.rotation.z = _portalT445 * 0.08;
      _portalGroup445.rotation.y = Math.PI * 0.1 + Math.sin(_portalT445 * 0.2) * 0.05;
    }
    if (_portalRingMat445) {
      _portalRingMat445.opacity = 0.6 + 0.2 * Math.sin(_portalT445 * 1.5);
    }
    _portalGlyphs445.forEach((g, i) => {
      const angle = (i / 8) * Math.PI * 2 + _portalT445 * 0.15;
      g.position.x = Math.cos(angle) * 2.2;
      g.position.y = Math.sin(angle) * 2.2;
      (g.material as MeshBasicMaterial).opacity = 0.5 + 0.4 * Math.sin(_portalT445 * 2.0 + i * 0.8);
    });

    // C450: crane flock flyover
    craneT450 += dt;

    if (craneGroup450) {
      const flightCycle = craneT450 % 40;
      craneGroup450.position.x = 18 - (43 * flightCycle / 40);
      craneGroup450.position.y = 14 + 1.5 * Math.sin(craneT450 * 0.15);
      craneGroup450.rotation.y = Math.PI * 0.05 + 0.04 * Math.sin(craneT450 * 0.3);
    }

    craneWingPairs450.forEach(({ left, right }, i) => {
      const flapAngle = Math.PI * 0.08 * Math.sin(craneT450 * 3.5 + i * 0.4);
      left.rotation.z = Math.PI * 0.1 + flapAngle;
      right.rotation.z = -(Math.PI * 0.1 + flapAngle);
    });

    // C455: Ogham obelisk — breathing glyphs and surge animation
    obeliskT455 += dt;
    obeliskSurgeTimer455 -= dt;

    if (!obeliskSurgeActive455) {
      obeliskGlyphs455.forEach((g, i) => {
        (g.material as MeshBasicMaterial).opacity = 0.25 + 0.2 * Math.sin(obeliskT455 * 0.6 + i * 0.4);
      });
    }

    if (obeliskSurgeTimer455 <= 0) {
      obeliskSurgeTimer455 = 25 + Math.random() * 15;
      obeliskSurgeActive455 = true;
      obeliskSurgeT455 = 0;
      window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'power_up' } }));
    }

    if (obeliskSurgeActive455) {
      obeliskSurgeT455 += dt;
      const surgeProgress = obeliskSurgeT455 / 1.5;
      obeliskGlyphs455.forEach((g, i) => {
        const mat = g.material as MeshBasicMaterial;
        const glyphProgress = i / (obeliskGlyphs455.length - 1);
        if (obeliskSurgeT455 < 1.5) {
          const dist = Math.abs(surgeProgress - glyphProgress);
          mat.opacity = dist < 0.2 ? 0.9 : 0.3;
        } else {
          const fadeT = (obeliskSurgeT455 - 1.5) / 0.5;
          mat.opacity = 0.9 - 0.65 * Math.min(fadeT, 1.0);
        }
      });
      if (obeliskSurgeT455 >= 2.0) {
        obeliskSurgeActive455 = false;
      }
    }

    // C460: Ghostly longship — crosses right→left over 60s, gentle ocean bob
    longshipT460 += dt;
    if (longshipGroup460) {
      const cycle460 = longshipT460 % 60;
      longshipGroup460.position.x = 30 - (70 * cycle460 / 60);
      longshipGroup460.position.y = -2 + 0.3 * Math.sin(longshipT460 * 0.4);
      longshipGroup460.rotation.z = 0.03 * Math.sin(longshipT460 * 0.4);
    }

    // C465: Spectral ancestor procession — 5 figures orbit slowly, breathing opacity
    ancestorT465 += dt;
    ancestorFigures465.forEach((fig) => {
      const figData = fig as unknown as Record<string, number>;
      const speed = figData['__orbitSpeed'];
      const phase = figData['__orbitPhase'];
      const angle = ancestorT465 * speed + phase;
      fig.position.x = Math.cos(angle) * 8;
      fig.position.z = Math.sin(angle) * 8;
      fig.rotation.y = -angle + Math.PI * 0.5;
      fig.position.y = 0.1 * Math.sin(ancestorT465 * 0.8 + phase);
      const opacity = 0.15 + 0.08 * Math.sin(ancestorT465 * 0.3 + phase);
      fig.traverse((child) => {
        if (child instanceof Mesh) {
          const mat = child.material as MeshBasicMaterial;
          if (mat.transparent) {
            mat.opacity = opacity * (mat.color.getHex() === 0x33ff66 ? 2.5 : 1.0);
          }
        }
      });
    });

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

  // C406 — falling ogham rune rain
  if (!document.getElementById('merlin-rune-rain-406')) {
    const style406 = document.createElement('style');
    style406.id = 'merlin-rune-rain-406';
    style406.textContent = `
      #rune-rain-overlay-406 {
        position: fixed;
        top: 0; left: 0;
        width: 100%; height: 100%;
        pointer-events: none;
        z-index: 2;
        overflow: hidden;
      }
      .rune-glyph-406 {
        position: absolute;
        font-family: 'Courier New', monospace;
        font-size: 18px;
        color: #1a8833;
        opacity: 0;
        animation: runefall406 var(--dur, 12s) linear var(--delay, 0s) infinite;
      }
      @keyframes runefall406 {
        0%   { transform: translateY(-40px); opacity: 0; }
        10%  { opacity: 0.6; }
        85%  { opacity: 0.4; }
        100% { transform: translateY(110vh); opacity: 0; }
      }
    `;
    document.head.appendChild(style406);
  }
  const runeOverlay406 = document.createElement('div');
  runeOverlay406.id = 'rune-rain-overlay-406';
  const oghams406 = ['ᚁ','ᚂ','ᚃ','ᚄ','ᚅ','ᚆ','ᚇ','ᚈ','ᚉ','ᚊ','ᚋ','ᚌ','ᚍ','ᚎ','ᚏ','ᚐ','ᚑ','ᚒ','ᚓ','ᚔ'];
  const cols406 = [4, 9, 15, 22, 31, 38, 48, 57, 63, 72, 80, 88];
  cols406.forEach((left, i) => {
    const span = document.createElement('span');
    span.className = 'rune-glyph-406';
    span.textContent = oghams406[i % oghams406.length];
    span.style.left = `${left}%`;
    const dur = 10 + (i % 5) * 2.5;
    const delay = -(i * 1.8);
    span.style.setProperty('--dur', `${dur}s`);
    span.style.setProperty('--delay', `${delay}s`);
    if (i % 3 === 0) span.style.color = '#33ff66';
    runeOverlay406.appendChild(span);
  });
  document.body.appendChild(runeOverlay406);
  _runeRainContainer406 = runeOverlay406;

  // C409: Layered mountain range silhouettes — depth parallax background
  {
    const makeMountainShape = (peaks: [number, number][], baseY: number, width: number): ShapeGeometry => {
      const shape = new Shape();
      shape.moveTo(-width / 2, baseY);
      peaks.forEach(([x, y]) => shape.lineTo(x, y));
      shape.lineTo(width / 2, baseY);
      shape.closePath();
      return new ShapeGeometry(shape);
    };
    const farPeaks: [number, number][] = [
      [-18,0],[-14,4],[-10,2],[-6,7],[-2,3],[2,8],[6,4],[10,6],[14,2],[18,0],
    ];
    const farMesh = new Mesh(
      makeMountainShape(farPeaks, -3, 36),
      new MeshBasicMaterial({ color: 0x050f08, transparent: true, opacity: 0.9, depthWrite: false }),
    );
    farMesh.position.set(0, -1, -50);
    const midPeaks: [number, number][] = [
      [-15,0],[-11,3],[-7,5],[-3,2],[1,6],[5,3],[9,5],[13,2],[15,0],
    ];
    const midMesh = new Mesh(
      makeMountainShape(midPeaks, -3, 30),
      new MeshBasicMaterial({ color: 0x071408, transparent: true, opacity: 0.92, depthWrite: false }),
    );
    midMesh.position.set(0, -1, -40);
    const nearPeaks: [number, number][] = [
      [-12,0],[-8,2],[-4,4],[0,1],[4,3],[8,1.5],[12,0],
    ];
    const nearMesh = new Mesh(
      makeMountainShape(nearPeaks, -3, 24),
      new MeshBasicMaterial({ color: 0x030a04, transparent: true, opacity: 0.95, depthWrite: false }),
    );
    nearMesh.position.set(0, -1, -30);
    const glowMesh = new Mesh(
      new PlaneGeometry(1.0, 0.3),
      new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.08, depthWrite: false }),
    );
    glowMesh.position.set(2, 7.5, -50);
    _mountainGroup409 = new Group();
    _mountainGroup409.add(farMesh, midMesh, nearMesh, glowMesh);
    scene.add(_mountainGroup409);
  }

  // C414: shooting star comets
  _cometSceneRef414 = scene;
  {
    const NUM_COMETS = 3;
    for (let ci = 0; ci < NUM_COMETS; ci++) {
      const points: Vector3[] = [];
      for (let pi = 0; pi < 8; pi++) points.push(new Vector3(0, 0, 0));
      const cometGeo = new BufferGeometry().setFromPoints(points);
      const cometMat = new LineBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.0 });
      const cometLine = new Line(cometGeo, cometMat);
      scene.add(cometLine);
      _comets414.push({
        line: cometLine,
        active: false,
        t: 0,
        duration: 0.8 + Math.random() * 0.4,
        startX: 0, startY: 0, startZ: -45,
        dx: 0, dy: 0,
        nextFire: 4 + ci * 6 + Math.random() * 4,
      });
    }
  }

  // C419 — rolling ground fog
  {
    const fogConfigs = [
      { x: -8,  z: -12, width: 22, speed: 0.4,  phase: 0.0 },
      { x:  5,  z: -18, width: 28, speed: -0.3, phase: 1.8 },
      { x: -3,  z: -8,  width: 18, speed: 0.25, phase: 3.4 },
      { x:  10, z: -24, width: 32, speed: -0.5, phase: 0.9 },
      { x: -12, z: -15, width: 20, speed: 0.35, phase: 2.6 },
    ];
    fogConfigs.forEach(cfg => {
      const fogGeo = new PlaneGeometry(cfg.width, 3.5);
      const fogMat = new MeshBasicMaterial({
        color: 0x0a1a0e,
        transparent: true,
        opacity: 0.18,
        depthWrite: false,
        side: DoubleSide,
      });
      const fogMesh = new Mesh(fogGeo, fogMat);
      fogMesh.rotation.x = -Math.PI / 2;
      fogMesh.position.set(cfg.x, 0.5, cfg.z);
      fogMesh.userData = { speed: cfg.speed, baseX: cfg.x, phase: cfg.phase, width: cfg.width };
      scene.add(fogMesh);
      _fogPlanes419.push(fogMesh);
    });
  }

  // C423 — Crann Bethadh (Celtic Tree of Life)
  _crannGroup423 = new Group();

  const trunkMat = new MeshBasicMaterial({ color: 0x050f08 });
  const crownMat = new MeshBasicMaterial({ color: 0x0a1a0e, transparent: true, opacity: 0.92 });
  const glowMat = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.06, depthWrite: false });

  // Main trunk: tapered cylinder, very tall
  const trunk = new Mesh(new CylinderGeometry(0.4, 0.9, 8, 7), trunkMat);
  trunk.position.set(0, 4, 0);

  // Root buttresses: 4 flat wedge-like BoxGeometry at base
  const rootAngles = [0, Math.PI / 2, Math.PI, -Math.PI / 2];
  rootAngles.forEach(angle => {
    const root = new Mesh(new BoxGeometry(0.5, 0.6, 2.5), trunkMat);
    root.position.set(Math.sin(angle) * 1.2, 0.3, Math.cos(angle) * 1.2);
    root.rotation.y = angle;
    root.rotation.x = 0.3;
    _crannGroup423!.add(root);
  });

  // Main canopy: 5 overlapping SphereGeometry spheres for crown
  const crownOffsets = [
    { x: 0,    y: 10.5, z:  0,    r: 4.5 },
    { x: -3.5, y: 9,    z:  0,    r: 3.0 },
    { x:  3.5, y: 9,    z:  0,    r: 3.0 },
    { x: -2,   y: 11.5, z:  0.5,  r: 2.2 },
    { x:  2,   y: 11.5, z: -0.5,  r: 2.2 },
  ];
  crownOffsets.forEach(({ x, y, z, r }) => {
    const crown = new Mesh(new SphereGeometry(r, 8, 6), crownMat);
    crown.position.set(x, y, z);
    _crannGroup423!.add(crown);
    const glow = new Mesh(new SphereGeometry(r * 1.15, 6, 5), glowMat.clone());
    glow.position.set(x, y, z);
    _crannGroup423!.add(glow);
  });

  // Major branches: 6 thick angled cylinders
  const branchDefs = [
    { x: -2,   y: 7, z:  0, rx:  0.5, rz: -0.6, len: 3.5 },
    { x:  2,   y: 7, z:  0, rx:  0.5, rz:  0.6, len: 3.5 },
    { x: -1.5, y: 9, z:  0, rx:  0.3, rz: -0.8, len: 2.8 },
    { x:  1.5, y: 9, z:  0, rx:  0.3, rz:  0.8, len: 2.8 },
    { x:  0,   y: 8, z: -1, rx: -0.4, rz:  0,   len: 2.5 },
    { x:  0,   y: 8, z:  1, rx:  0.4, rz:  0,   len: 2.5 },
  ];
  branchDefs.forEach(({ x, y, z, rx, rz, len }) => {
    const branch = new Mesh(new CylinderGeometry(0.1, 0.2, len, 5), trunkMat);
    branch.position.set(x, y, z);
    branch.rotation.x = rx;
    branch.rotation.z = rz;
    _crannGroup423!.add(branch);
  });

  // Canopy point light
  _crannLeafLight423 = new PointLight(0x33ff66, 0.15, 12.0);
  _crannLeafLight423.position.set(0, 11, 0);

  _crannGroup423.add(trunk, _crannLeafLight423);
  _crannGroup423.position.set(-12, 0, -45);
  scene.add(_crannGroup423);

  // C427 — distant stone circle
  _stoneCircleGroup427 = new Group();

  const stoneDarkMat = new MeshBasicMaterial({ color: 0x050f08 });
  const NUM_STONES = 8;
  const RING_RADIUS = 3.2;

  // Standing stones
  for (let si = 0; si < NUM_STONES; si++) {
    const angle = (si / NUM_STONES) * Math.PI * 2;
    const stoneH = 2.2 + (si % 3) * 0.4; // varying heights
    const stoneW = 0.45 + (si % 2) * 0.1;
    const stone = new Mesh(new BoxGeometry(stoneW, stoneH, 0.3), stoneDarkMat);
    stone.position.set(
      Math.cos(angle) * RING_RADIUS,
      stoneH / 2,
      Math.sin(angle) * RING_RADIUS
    );
    stone.rotation.y = angle; // face inward
    _stoneCircleGroup427.add(stone);
  }

  // Lintel stones (4 pairs of adjacent stones get a cap)
  for (let li = 0; li < 4; li++) {
    const angle1 = (li * 2 / NUM_STONES) * Math.PI * 2;
    const angle2 = ((li * 2 + 1) / NUM_STONES) * Math.PI * 2;
    const midAngle = (angle1 + angle2) / 2;
    const lintelH = 2.8; // top of shorter stone
    const lintel = new Mesh(new BoxGeometry(1.6, 0.35, 0.3), stoneDarkMat);
    lintel.position.set(
      Math.cos(midAngle) * RING_RADIUS,
      lintelH + 0.175,
      Math.sin(midAngle) * RING_RADIUS
    );
    lintel.rotation.y = midAngle;
    _stoneCircleGroup427.add(lintel);
  }

  // Central altar stone: flat slab
  const altar = new Mesh(new BoxGeometry(1.0, 0.2, 0.6), stoneDarkMat);
  altar.position.set(0, 0.1, 0);
  _stoneCircleGroup427.add(altar);

  // Faint green energy glow at center (ancient power)
  _stoneCircleLight427 = new PointLight(0x33ff66, 0.08, 8.0);
  _stoneCircleLight427.position.set(0, 1.5, 0);
  _stoneCircleGroup427.add(_stoneCircleLight427);

  _stoneCircleGroup427.position.set(16, 0, -44);
  scene.add(_stoneCircleGroup427);

  // C431 — CeltOS boot terminal
  if (!document.getElementById('celtos-terminal-431')) {
    const style = document.createElement('style');
    style.id = 'celtos-terminal-431-style';
    style.textContent = `
    #celtos-terminal-431 {
      position: fixed;
      bottom: 18px;
      left: 18px;
      width: 320px;
      background: rgba(1,8,2,0.92);
      border: 1px solid #1a8833;
      border-radius: 2px;
      padding: 8px 10px;
      font-family: 'Courier New', monospace;
      font-size: 11px;
      color: #1a8833;
      pointer-events: none;
      z-index: 10;
      box-shadow: 0 0 12px rgba(51,255,102,0.15);
      overflow: hidden;
      max-height: 140px;
    }
    #celtos-terminal-431 .ct-line {
      line-height: 1.5;
      white-space: nowrap;
      overflow: hidden;
    }
    #celtos-terminal-431 .ct-line.bright { color: #33ff66; }
    #celtos-terminal-431 .ct-cursor {
      display: inline-block;
      width: 7px;
      height: 12px;
      background: #33ff66;
      animation: ctblink 1s step-end infinite;
      vertical-align: text-bottom;
    }
    @keyframes ctblink { 0%,100%{opacity:1} 50%{opacity:0} }
  `;
    document.head.appendChild(style);
  }

  const terminal = document.createElement('div');
  terminal.id = 'celtos-terminal-431';
  document.body.appendChild(terminal);
  _celtosTerminal431 = terminal;

  const BOOT_SEQUENCES = [
    [
      { text: 'CeltOS v4.2.1 — MERLIN KERNEL', bright: true },
      { text: 'Loading druidic modules... [OK]' },
      { text: 'Ogham subsystem: 18 glyphs active' },
      { text: 'LLM bridge: GROQ/qwen — connected' },
      { text: 'Ley line network: nominal' },
      { text: 'Biome renderer: 8 zones loaded [OK]', bright: true },
    ],
    [
      { text: 'MERLIN.EXE — Arcane Process Manager', bright: true },
      { text: 'Faction registry: 5 entities loaded' },
      { text: 'FastRoute pool: 500+ cards indexed' },
      { text: 'Brocéliande fog: enabled' },
      { text: 'Memory palace: run_state.json clean' },
      { text: 'SYSTEM READY >', bright: true },
    ],
    [
      { text: '>> DIAGNOSTIC MODE <<', bright: true },
      { text: 'Crystal orb: calibrated' },
      { text: 'Pendulum clock: synchronized' },
      { text: 'Familiar status: sleeping (nominal)' },
      { text: 'Cauldron temp: 98.6°D (optimal)' },
      { text: 'All systems: OPERATIONAL', bright: true },
    ],
  ];

  let seqIdx = 0;

  function runBootSequence(): void {
    if (!_celtosTerminal431) return;
    _celtosTerminal431.innerHTML = '';
    const seq = BOOT_SEQUENCES[seqIdx % BOOT_SEQUENCES.length];
    seqIdx++;
    let lineIdx = 0;

    function addLine(): void {
      if (!_celtosTerminal431 || lineIdx >= seq.length) {
        if (_celtosTerminal431) {
          const cursor = document.createElement('span');
          cursor.className = 'ct-cursor';
          _celtosTerminal431.appendChild(cursor);
        }
        return;
      }
      const item = seq[lineIdx++];
      const line = document.createElement('div');
      line.className = 'ct-line' + (item.bright ? ' bright' : '');
      line.textContent = item.text;
      _celtosTerminal431.appendChild(line);
      const fullText = item.text;
      line.textContent = '';
      let charIdx = 0;
      const charInterval = setInterval(() => {
        if (charIdx < fullText.length) {
          line.textContent += fullText[charIdx++];
        } else {
          clearInterval(charInterval);
          setTimeout(addLine, 120);
        }
      }, 28);
    }

    addLine();
  }

  runBootSequence();
  _celtosInterval431 = setInterval(runBootSequence, 30000);

  // C434 — distant lightning storm
  _stormGroup434 = new Group();

  const cloudMat434 = new MeshBasicMaterial({ color: 0x0a1a0e, transparent: true, opacity: 0.88, depthWrite: false });

  // Storm cloud mass: 5 overlapping SphereGeometry blobs
  const cloudDefs434 = [
    { x: 0, y: 0, z: 0, r: 4.5 },
    { x: -3.5, y: -1, z: 1, r: 3.2 },
    { x: 3.5, y: -0.5, z: -1, r: 3.8 },
    { x: 1, y: 2, z: 0.5, r: 2.8 },
    { x: -2, y: 1.5, z: -1, r: 2.5 },
  ];
  cloudDefs434.forEach(({ x, y, z, r }) => {
    const cloud = new Mesh(new SphereGeometry(r, 7, 5), cloudMat434.clone());
    cloud.position.set(x, y, z);
    _stormGroup434!.add(cloud);
  });

  // Pre-build 3 lightning bolt lines (hidden by default)
  for (let bi = 0; bi < 3; bi++) {
    const boltPoints = [new Vector3(0, 0, 0), new Vector3(0, 0, 0), new Vector3(0, 0, 0), new Vector3(0, 0, 0)];
    const boltGeo = new BufferGeometry().setFromPoints(boltPoints);
    const boltMat = new LineBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.0 });
    const bolt = new Line(boltGeo, boltMat);
    _lightningBolts434.push(bolt);
    _stormGroup434!.add(bolt);
  }

  // Ambient storm glow light (dim, occasional flash)
  _stormAmbientLight434 = new PointLight(0x33ff66, 0.02, 30.0);
  _stormAmbientLight434.position.set(0, -3, 0);
  _stormGroup434.add(_stormAmbientLight434);

  _stormGroup434.position.set(20, 12, -48);
  scene.add(_stormGroup434);

  // C445 — Celtic knotwork portal ring
  _portalGroup445 = new Group();
  _portalGroup445.position.set(-6, 2, -15);
  _portalGroup445.rotation.y = Math.PI * 0.1;

  const portalRing = new Mesh(
    new TorusGeometry(2.2, 0.12, 8, 48),
    new MeshBasicMaterial({ color: 0x1a8833, transparent: true, opacity: 0.75 }),
  );
  _portalRingMat445 = portalRing.material as MeshBasicMaterial;
  _portalGroup445.add(portalRing);

  const innerRing = new Mesh(
    new TorusGeometry(1.8, 0.05, 6, 36),
    new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.4 }),
  );
  _portalGroup445.add(innerRing);

  const portalFace = new Mesh(
    new CircleGeometry(1.75, 32),
    new MeshBasicMaterial({ color: 0x010802, transparent: true, opacity: 0.6, side: DoubleSide }),
  );
  _portalGroup445.add(portalFace);

  for (let i = 0; i < 8; i++) {
    const angle = (i / 8) * Math.PI * 2;
    const glyph = new Mesh(
      new PlaneGeometry(0.18, 0.18),
      new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.8, side: DoubleSide }),
    );
    glyph.position.set(Math.cos(angle) * 2.2, Math.sin(angle) * 2.2, 0.05);
    _portalGlyphs445.push(glyph);
    _portalGroup445.add(glyph);
  }

  const portalLight = new PointLight(0x33ff66, 0.25, 10);
  _portalGroup445.add(portalLight);

  scene.add(_portalGroup445);

  // C450 — Sacred crane flock V-formation
  craneGroup450 = new Group();

  const craneFormation = [
    { x: 0,    y: 0,    z: 0    },
    { x: -1.2, y: -0.3, z: 0.8  },
    { x:  1.2, y: -0.3, z: 0.8  },
    { x: -2.4, y: -0.5, z: 1.6  },
    { x:  2.4, y: -0.5, z: 1.6  },
    { x: -3.6, y: -0.7, z: 2.4  },
    { x:  3.6, y: -0.7, z: 2.4  },
  ];

  craneFormation.forEach((pos) => {
    const birdGroup = new Group();
    birdGroup.position.set(pos.x, pos.y, pos.z);

    const body = new Mesh(
      new BoxGeometry(0.08, 0.06, 0.5),
      new MeshBasicMaterial({ color: 0x0d2a14 }),
    );
    birdGroup.add(body);

    const leftWing = new Mesh(
      new PlaneGeometry(0.5, 0.12),
      new MeshBasicMaterial({ color: 0x0d2a14, side: DoubleSide }),
    );
    leftWing.position.set(-0.3, 0.02, 0);
    leftWing.rotation.z = Math.PI * 0.1;
    birdGroup.add(leftWing);

    const rightWing = new Mesh(
      new PlaneGeometry(0.5, 0.12),
      new MeshBasicMaterial({ color: 0x0d2a14, side: DoubleSide }),
    );
    rightWing.position.set(0.3, 0.02, 0);
    rightWing.rotation.z = -Math.PI * 0.1;
    birdGroup.add(rightWing);

    const neck = new Mesh(
      new BoxGeometry(0.04, 0.04, 0.3),
      new MeshBasicMaterial({ color: 0x0d2a14 }),
    );
    neck.position.set(0, 0.04, -0.35);
    birdGroup.add(neck);

    craneWingPairs450.push({ left: leftWing, right: rightWing });
    craneGroup450!.add(birdGroup);
  });

  craneGroup450.position.set(18, 14, -35);
  craneGroup450.rotation.y = Math.PI * 0.05;

  scene.add(craneGroup450);

  // C455 — Towering Ogham obelisk with glowing carved inscriptions
  obeliskGroup455 = new Group();
  obeliskGroup455.position.set(8, 0, -28);
  obeliskGroup455.rotation.y = -Math.PI * 0.12;

  // Main pillar: tall tapered BoxGeometry
  const pillar455 = new Mesh(
    new BoxGeometry(0.7, 5.5, 0.5),
    new MeshBasicMaterial({ color: 0x0a1a10 }),
  );
  pillar455.position.y = 2.75;
  obeliskGroup455.add(pillar455);

  // Pyramid cap
  const cap455 = new Mesh(
    new CylinderGeometry(0, 0.4, 0.8, 4),
    new MeshBasicMaterial({ color: 0x0a1a10 }),
  );
  cap455.position.y = 5.9;
  obeliskGroup455.add(cap455);

  // Base plinth
  const plinth455 = new Mesh(
    new BoxGeometry(1.1, 0.35, 0.8),
    new MeshBasicMaterial({ color: 0x020f04 }),
  );
  plinth455.position.y = 0.18;
  obeliskGroup455.add(plinth455);

  // 8 glyph planes on the front face — stacked vertically
  for (let i455 = 0; i455 < 8; i455++) {
    const glyph455 = new Mesh(
      new PlaneGeometry(0.3, 0.3),
      new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.4 }),
    );
    glyph455.position.set(0, 0.8 + i455 * 0.55, 0.26);
    obeliskGlyphs455.push(glyph455);
    obeliskGroup455.add(glyph455);
  }

  // Ground scatter: 3 small fallen stones around base
  for (let j455 = 0; j455 < 3; j455++) {
    const stone455 = new Mesh(
      new BoxGeometry(0.2 + Math.random() * 0.2, 0.1, 0.15 + Math.random() * 0.1),
      new MeshBasicMaterial({ color: 0x0a1a10 }),
    );
    stone455.position.set(-0.6 + j455 * 0.6, 0.05, 0.4 + Math.random() * 0.2);
    stone455.rotation.y = Math.random() * Math.PI;
    obeliskGroup455.add(stone455);
  }

  // Ambient glow light at base
  const obeliskLight455 = new PointLight(0x33ff66, 0.12, 8.0);
  obeliskLight455.position.set(0, 1.0, 0.5);
  obeliskGroup455.add(obeliskLight455);

  scene.add(obeliskGroup455);

  // C460 — Ghostly Celtic longship sailing across the distant background
  longshipGroup460 = new Group();
  longshipGroup460.position.set(30, -2, -50);
  longshipGroup460.rotation.y = Math.PI * 0.05;

  // Hull: elongated tapered box
  const hull460 = new Mesh(
    new BoxGeometry(5.0, 0.7, 1.4),
    new MeshBasicMaterial({ color: 0x0a1a10 }),
  );
  hull460.position.y = 0;
  longshipGroup460.add(hull460);

  // Bow: pointed front wedge
  const bow460 = new Mesh(
    new CylinderGeometry(0.01, 0.7, 1.5, 4),
    new MeshBasicMaterial({ color: 0x0a1a10 }),
  );
  bow460.rotation.z = -Math.PI * 0.5;
  bow460.position.set(3.1, 0, 0);
  longshipGroup460.add(bow460);

  // Stern: raised back
  const stern460 = new Mesh(
    new BoxGeometry(0.5, 0.9, 1.3),
    new MeshBasicMaterial({ color: 0x0a1a10 }),
  );
  stern460.position.set(-2.3, 0.4, 0);
  longshipGroup460.add(stern460);

  // Mast
  const mast460 = new Mesh(
    new CylinderGeometry(0.05, 0.07, 3.5, 5),
    new MeshBasicMaterial({ color: 0x020f04 }),
  );
  mast460.position.set(0.3, 2.0, 0);
  longshipGroup460.add(mast460);

  // Yard arm (horizontal spar)
  const yardArm460 = new Mesh(
    new CylinderGeometry(0.04, 0.04, 2.2, 4),
    new MeshBasicMaterial({ color: 0x020f04 }),
  );
  yardArm460.rotation.z = Math.PI * 0.5;
  yardArm460.position.set(0.3, 3.2, 0);
  longshipGroup460.add(yardArm460);

  // Sail: semi-transparent ghostly
  const sail460 = new Mesh(
    new PlaneGeometry(2.0, 2.0),
    new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.2, side: DoubleSide }),
  );
  sail460.position.set(0.3, 2.2, 0);
  longshipGroup460.add(sail460);

  // Sail symbol: faint ogham glyph face
  const sailSymbol460 = new Mesh(
    new PlaneGeometry(0.6, 0.6),
    new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.4 }),
  );
  sailSymbol460.position.set(0.3, 2.2, 0.06);
  longshipGroup460.add(sailSymbol460);

  // Dragon prow head
  const prow460 = new Mesh(
    new SphereGeometry(0.15, 5, 4),
    new MeshBasicMaterial({ color: 0x0d2a14 }),
  );
  prow460.position.set(3.8, 0.3, 0);
  longshipGroup460.add(prow460);

  scene.add(longshipGroup460);

  // C465 — Spectral ancestor procession circling in the far background
  ancestorGroup465 = new Group();
  ancestorGroup465.position.set(-2, -3, -40);

  for (let i = 0; i < 5; i++) {
    const figGroup = new Group();

    // Body torso
    const torso465 = new Mesh(
      new BoxGeometry(0.35, 0.65, 0.25),
      new MeshBasicMaterial({ color: 0x0d2a14, transparent: true, opacity: 0.2 }),
    );
    torso465.position.y = 1.0;
    figGroup.add(torso465);

    // Head
    const head465 = new Mesh(
      new SphereGeometry(0.2, 5, 4),
      new MeshBasicMaterial({ color: 0x0d2a14, transparent: true, opacity: 0.18 }),
    );
    head465.position.y = 1.6;
    figGroup.add(head465);

    // Robe/cloak
    const robe465 = new Mesh(
      new BoxGeometry(0.42, 0.9, 0.28),
      new MeshBasicMaterial({ color: 0x0d2a14, transparent: true, opacity: 0.22 }),
    );
    robe465.position.y = 0.45;
    figGroup.add(robe465);

    // Very faint eye glow
    const eyeGlow465 = new Mesh(
      new SphereGeometry(0.03, 3, 3),
      new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.4 }),
    );
    eyeGlow465.position.set(0, 1.62, 0.18);
    figGroup.add(eyeGlow465);

    // Initial orbit position
    const startAngle = (i / 5) * Math.PI * 2;
    figGroup.position.set(Math.cos(startAngle) * 8, 0, Math.sin(startAngle) * 8);

    (figGroup as unknown as Record<string, number>)['__orbitPhase'] = startAngle;
    (figGroup as unknown as Record<string, number>)['__orbitSpeed'] = 0.06 + i * 0.003;

    ancestorGroup465!.add(figGroup);
    ancestorFigures465.push(figGroup);
  }

  scene.add(ancestorGroup465);

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
    // C406: remove falling ogham rune rain overlay
    if (_runeRainContainer406) {
      _runeRainContainer406.remove();
      _runeRainContainer406 = null;
    }
    const runeStyle406 = document.getElementById('merlin-rune-rain-406');
    if (runeStyle406) runeStyle406.remove();
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

    // C409: dispose mountain silhouette group
    if (_mountainGroup409) {
      _mountainGroup409.traverse((c) => {
        if (c instanceof Mesh) {
          c.geometry.dispose();
          (c.material as MeshBasicMaterial).dispose();
        }
      });
      scene.remove(_mountainGroup409);
      _mountainGroup409 = null;
    }

    // C414: dispose comet streaks
    _comets414.forEach(comet => {
      comet.line.geometry.dispose();
      (comet.line.material as LineBasicMaterial).dispose();
      if (_cometSceneRef414) _cometSceneRef414.remove(comet.line);
    });
    _comets414.length = 0;
    _cometSceneRef414 = null;

    // C419: dispose ground fog planes
    _fogPlanes419.forEach(plane => {
      plane.geometry.dispose();
      (plane.material as MeshBasicMaterial).dispose();
      scene.remove(plane);
    });
    _fogPlanes419.length = 0;

    // C423: dispose Crann Bethadh tree
    if (_crannGroup423) {
      _crannGroup423.traverse(obj => {
        if (obj instanceof Mesh) {
          obj.geometry.dispose();
          if (Array.isArray(obj.material)) {
            obj.material.forEach((m: Material) => m.dispose());
          } else {
            (obj.material as Material).dispose();
          }
        }
      });
      scene.remove(_crannGroup423);
      _crannGroup423 = null;
      _crannLeafLight423 = null;
    }

    // C427: dispose stone circle
    if (_stoneCircleGroup427) {
      _stoneCircleGroup427.traverse(c => {
        if (c instanceof Mesh) {
          c.geometry.dispose();
          if (Array.isArray(c.material)) {
            c.material.forEach((m: Material) => m.dispose());
          } else {
            (c.material as Material).dispose();
          }
        }
        if (c instanceof PointLight) c.dispose();
      });
      scene.remove(_stoneCircleGroup427);
      _stoneCircleLight427 = null;
      _stoneCircleGroup427 = null;
    }

    // C431: dispose CeltOS terminal
    if (_celtosInterval431) { clearInterval(_celtosInterval431); _celtosInterval431 = null; }
    if (_celtosTerminal431) { _celtosTerminal431.remove(); _celtosTerminal431 = null; }
    const ctStyle = document.getElementById('celtos-terminal-431-style');
    if (ctStyle) ctStyle.remove();

    // C434: dispose distant lightning storm
    if (_stormGroup434) {
      _stormGroup434.traverse(c => {
        if (c instanceof Mesh) { c.geometry.dispose(); if (Array.isArray(c.material)) c.material.forEach(m => m.dispose()); else c.material.dispose(); }
        if (c instanceof Line) { c.geometry.dispose(); (c.material as LineBasicMaterial).dispose(); }
        if (c instanceof PointLight) c.dispose();
      });
      _lightningBolts434.length = 0;
      _stormAmbientLight434 = null;
      scene.remove(_stormGroup434);
      _stormGroup434 = null;
    }

    // C445: dispose Celtic knotwork portal ring
    if (_portalGroup445) {
      _portalGroup445.traverse((c) => {
        if (c instanceof Mesh) { c.geometry.dispose(); (c.material as Material).dispose(); }
      });
      scene.remove(_portalGroup445);
      _portalGroup445 = null;
    }
    _portalGlyphs445 = [];
    _portalRingMat445 = null;

    // C450: dispose crane flock
    if (craneGroup450) {
      craneGroup450.traverse((c) => {
        if (c instanceof Mesh) { c.geometry.dispose(); (c.material as Material).dispose(); }
      });
      scene.remove(craneGroup450);
      craneGroup450 = null;
    }
    craneWingPairs450 = [];

    // C455: dispose Ogham obelisk
    if (obeliskGroup455) {
      obeliskGroup455.traverse((c) => {
        if (c instanceof Mesh) { c.geometry.dispose(); (c.material as Material).dispose(); }
      });
      scene.remove(obeliskGroup455);
      obeliskGroup455 = null;
    }
    obeliskGlyphs455 = [];
    obeliskSurgeActive455 = false;

    // C460: dispose ghostly longship
    if (longshipGroup460) {
      longshipGroup460.traverse((c) => {
        if (c instanceof Mesh) { c.geometry.dispose(); (c.material as Material).dispose(); }
      });
      scene.remove(longshipGroup460);
      longshipGroup460 = null;
    }

    // C465: dispose spectral ancestor procession
    if (ancestorGroup465) {
      ancestorGroup465.traverse((c) => {
        if (c instanceof Mesh) { c.geometry.dispose(); (c.material as Material).dispose(); }
      });
      scene.remove(ancestorGroup465);
      ancestorGroup465 = null;
    }
    ancestorFigures465 = [];

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
