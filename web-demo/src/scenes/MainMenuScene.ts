// ═══════════════════════════════════════════════════════════════════════════════
// Main Menu Scene — Cycle 26 — Low-poly coastal cliff + tower
// Reference: dark stormy coast, flat-shaded polygons throughout.
// Camera: fixed high angle (-8,18,28) looking (4,2,-10). World animates.
// flatShading: true on ALL MeshStandardMaterial = the key low-poly look.
// ═══════════════════════════════════════════════════════════════════════════════

import * as THREE from 'three';

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
  renderer: THREE.WebGLRenderer;
  update: (dt: number) => void;
  /** No-op kept for API compatibility — camera is static. Calls onComplete immediately. */
  startDolly: (onComplete: () => void) => void;
  dispose: () => void;
}

// ── Low-poly Ocean ───────────────────────────────────────────────────────────
// PlaneGeometry with many segments so flatShading creates visible wave facets.
// Vertex Y displacement in update() to animate the waves.

interface OceanResult {
  mesh: THREE.Mesh;
  horizonPlane: THREE.Mesh;
  update: (t: number) => void;
}

function createLowPolyOcean(): OceanResult {
  // Many segments so flatShading creates visible polygon faces per wave
  const geo = new THREE.PlaneGeometry(80, 60, 30, 20);
  const mat = new THREE.MeshStandardMaterial({
    color: 0x2a6b5a,
    flatShading: true,
    roughness: 0.8,
    metalness: 0.1,
  });

  const mesh = new THREE.Mesh(geo, mat);
  mesh.rotation.x = -Math.PI / 2;
  // Ocean is left half of scene, below cliff level
  mesh.position.set(-18, -2, -8);

  // Horizon plane: lighter teal plane far back to create depth gradient
  const horizonGeo = new THREE.PlaneGeometry(120, 50, 12, 6);
  const horizonMat = new THREE.MeshStandardMaterial({
    color: 0x3a8070,
    flatShading: true,
    roughness: 0.9,
    metalness: 0.05,
  });
  const horizonPlane = new THREE.Mesh(horizonGeo, horizonMat);
  horizonPlane.rotation.x = -Math.PI / 2;
  horizonPlane.position.set(-10, -2, -45);

  // Store original Y positions for wave animation
  const posAttr = geo.attributes['position'] as THREE.BufferAttribute;
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
  group: THREE.Group;
  update: (t: number) => void;
}

function createFoamPatches(): FoamPatchResult {
  const group = new THREE.Group();
  const mat = new THREE.MeshStandardMaterial({
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
    const geo = new THREE.CircleGeometry(0.6 + Math.random() * 0.5, 5);
    const foam = new THREE.Mesh(geo, mat);
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
      const mesh = child as THREE.Mesh;
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

function displaceVertices(geo: THREE.BufferGeometry, amount: number): void {
  const posAttr = geo.attributes['position'] as THREE.BufferAttribute;
  const arr = posAttr.array as Float32Array;
  for (let i = 0; i < posAttr.count; i++) {
    arr[i * 3]     += (Math.random() - 0.5) * amount;
    arr[i * 3 + 1] += (Math.random() - 0.5) * amount;
    arr[i * 3 + 2] += (Math.random() - 0.5) * amount;
  }
  posAttr.needsUpdate = true;
  geo.computeVertexNormals();
}

function createCliff(): THREE.Group {
  const group = new THREE.Group();

  const matBase = new THREE.MeshStandardMaterial({
    color: 0x3a3830,
    flatShading: true,
    roughness: 0.95,
    metalness: 0.0,
  });
  const matShadow = new THREE.MeshStandardMaterial({
    color: 0x2a2820,
    flatShading: true,
    roughness: 1.0,
    metalness: 0.0,
  });
  const matHighlight = new THREE.MeshStandardMaterial({
    color: 0x4a4838,
    flatShading: true,
    roughness: 0.9,
    metalness: 0.0,
  });

  // Main cliff body — large angular mass, left-center (4,4,4 segments for coarser facets)
  const bodyGeo = new THREE.BoxGeometry(18, 14, 12, 4, 4, 4);
  displaceVertices(bodyGeo, 2.0);
  const body = new THREE.Mesh(bodyGeo, matBase);
  body.position.set(-6, 0, -10);
  group.add(body);

  // Upper cliff platform (4 segs, stronger displacement)
  const upperGeo = new THREE.BoxGeometry(14, 6, 10, 4, 4, 4);
  displaceVertices(upperGeo, 1.8);
  const upper = new THREE.Mesh(upperGeo, matHighlight);
  upper.position.set(-4, 10, -9);
  group.add(upper);

  // Left face — darker shadow side (more segments = more angular silhouette)
  const leftGeo = new THREE.BoxGeometry(8, 18, 8, 4, 4, 4);
  displaceVertices(leftGeo, 2.0);
  const left = new THREE.Mesh(leftGeo, matShadow);
  left.position.set(-12, 1, -8);
  left.rotation.y = 0.15;
  group.add(left);

  // Rocky outcrop 1 — mid cliff
  const rock1Geo = new THREE.BoxGeometry(7, 5, 6, 4, 4, 4);
  displaceVertices(rock1Geo, 1.8);
  const rock1 = new THREE.Mesh(rock1Geo, matBase);
  rock1.position.set(-2, 7, -6);
  rock1.rotation.y = 0.4;
  group.add(rock1);

  // Rocky outcrop 2 — high right, connects to tower base
  const rock2Geo = new THREE.BoxGeometry(10, 4, 8, 4, 4, 4);
  displaceVertices(rock2Geo, 1.6);
  const rock2 = new THREE.Mesh(rock2Geo, matHighlight);
  rock2.position.set(4, 13, -11);
  rock2.rotation.y = -0.2;
  group.add(rock2);

  // Foreground rocks — closer to camera (depth layering, darker)
  const rock3Geo = new THREE.BoxGeometry(4, 3, 4, 4, 4, 4);
  displaceVertices(rock3Geo, 1.4);
  const rock3 = new THREE.Mesh(rock3Geo, matShadow);
  rock3.position.set(0, 5, -2);
  rock3.rotation.y = 0.6;
  group.add(rock3);

  const rock4Geo = new THREE.BoxGeometry(3, 2, 3, 4, 4, 4);
  displaceVertices(rock4Geo, 1.2);
  const rock4 = new THREE.Mesh(rock4Geo, matBase);
  rock4.position.set(-8, 4, -3);
  rock4.rotation.y = -0.3;
  group.add(rock4);

  // Three additional foreground rock masses for depth layering
  const rock5Geo = new THREE.BoxGeometry(5, 4, 4, 4, 4, 4);
  displaceVertices(rock5Geo, 1.6);
  const rock5 = new THREE.Mesh(rock5Geo, matShadow);
  rock5.position.set(-15, 2, -5);
  rock5.rotation.y = 0.9;
  group.add(rock5);

  const rock6Geo = new THREE.BoxGeometry(6, 3, 5, 4, 4, 4);
  displaceVertices(rock6Geo, 1.5);
  const rock6 = new THREE.Mesh(rock6Geo, matBase);
  rock6.position.set(-18, 1, -12);
  rock6.rotation.y = -0.5;
  group.add(rock6);

  const rock7Geo = new THREE.BoxGeometry(4, 5, 4, 4, 4, 4);
  displaceVertices(rock7Geo, 1.7);
  const rock7 = new THREE.Mesh(rock7Geo, matShadow);
  rock7.position.set(2, 3, -3);
  rock7.rotation.y = 1.2;
  group.add(rock7);

  // Large waterline rock — partially submerged at ocean edge
  const waterRockGeo = new THREE.BoxGeometry(8, 5, 6, 4, 4, 4);
  displaceVertices(waterRockGeo, 1.8);
  const waterRock = new THREE.Mesh(waterRockGeo, matShadow);
  waterRock.position.set(-14, -1, -3);
  waterRock.rotation.y = 0.25;
  group.add(waterRock);

  return group;
}

// ── Distant Cliff Silhouette ─────────────────────────────────────────────────
// Pure flat dark slab at z=-90 — no detail, pure depth silhouette.

function createDistantSilhouette(): THREE.Mesh {
  const geo = new THREE.BoxGeometry(60, 20, 2);
  const mat = new THREE.MeshStandardMaterial({
    color: 0x1a1e28,
    flatShading: true,
    roughness: 1.0,
    metalness: 0.0,
  });
  const mesh = new THREE.Mesh(geo, mat);
  mesh.position.set(0, 5, -90);
  return mesh;
}

// ── Sandy Path ───────────────────────────────────────────────────────────────

function createPath(): THREE.Mesh {
  const geo = new THREE.PlaneGeometry(2.5, 16, 3, 6);
  displaceVertices(geo, 0.15);
  const mat = new THREE.MeshStandardMaterial({
    color: 0xb0a080,
    flatShading: true,
    roughness: 1.0,
    metalness: 0.0,
  });
  const mesh = new THREE.Mesh(geo, mat);
  mesh.rotation.x = -Math.PI / 2;
  mesh.rotation.z = 0.3;
  mesh.position.set(2, 8.2, -6);
  return mesh;
}

// ── Tower ────────────────────────────────────────────────────────────────────
// CylinderGeometry with 7 radial segments = low-poly faceted cylinder.
// Conical roof also 7 segments. Battlements as small BoxGeometry notches.

function createTower(): THREE.Group {
  const group = new THREE.Group();

  const mat = new THREE.MeshStandardMaterial({
    color: 0x8a8068,
    flatShading: true,
    roughness: 0.9,
    metalness: 0.0,
  });
  const matDark = new THREE.MeshStandardMaterial({
    color: 0x6a6050,
    flatShading: true,
    roughness: 1.0,
    metalness: 0.0,
  });
  const matRoof = new THREE.MeshStandardMaterial({
    color: 0x5a5244,
    flatShading: true,
    roughness: 1.0,
    metalness: 0.0,
  });

  // Ground floor section (wider base)
  const base = new THREE.Mesh(new THREE.CylinderGeometry(1.9, 2.2, 3.0, 7), mat);
  base.position.set(0, 1.5, 0);
  group.add(base);

  // Second section
  const s2 = new THREE.Mesh(new THREE.CylinderGeometry(1.7, 1.9, 3.0, 7), mat);
  s2.position.set(0, 4.5, 0);
  group.add(s2);

  // Third section
  const s3 = new THREE.Mesh(new THREE.CylinderGeometry(1.6, 1.7, 3.0, 7), mat);
  s3.position.set(0, 7.5, 0);
  group.add(s3);

  // Top section (battlements ring)
  const s4 = new THREE.Mesh(new THREE.CylinderGeometry(1.7, 1.6, 2.0, 7), matDark);
  s4.position.set(0, 10.0, 0);
  group.add(s4);

  // Battlement notches — 7 small boxes around the top ring
  const notchMat = new THREE.MeshStandardMaterial({
    color: 0x9a9078,
    flatShading: true,
    roughness: 0.9,
    metalness: 0.0,
  });
  for (let i = 0; i < 7; i++) {
    const angle = (i / 7) * Math.PI * 2;
    const notch = new THREE.Mesh(new THREE.BoxGeometry(0.5, 0.8, 0.4), notchMat);
    notch.position.set(
      Math.cos(angle) * 1.7,
      11.4,
      Math.sin(angle) * 1.7
    );
    notch.rotation.y = angle;
    group.add(notch);
  }

  // Conical roof — 7 segments = clearly low-poly cone
  const roofGeo = new THREE.CylinderGeometry(0, 1.8, 3.5, 7);
  const roof = new THREE.Mesh(roofGeo, matRoof);
  roof.position.set(0, 13.25, 0);
  group.add(roof);

  // Arched window — dark rectangle on the cylinder face
  const windowMat = new THREE.MeshBasicMaterial({ color: 0x1a1008 });
  const windowGeo = new THREE.PlaneGeometry(0.6, 0.9);
  const win = new THREE.Mesh(windowGeo, windowMat);
  win.position.set(0, 7.2, 1.65);
  group.add(win);

  // Warm interior point light (visible through window)
  const insideLight = new THREE.PointLight(0xffaa44, 1.2, 12, 2);
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

function createClouds(): { group: THREE.Group; update: (t: number) => void } {
  const group = new THREE.Group();

  const cloudConfigs: CloudConfig[] = [
    // Mid-depth storm clouds
    { color: 0x2d3545, w: 14, h: 1.8, d: 0.4, x: -20, y: 32, z: -40, ry: 0.05,  rx: -0.03, rz:  0.01 },
    { color: 0x3a4555, w: 10, h: 1.4, d: 0.3, x:  -8, y: 35, z: -45, ry: -0.08, rx:  0.04, rz: -0.02 },
    { color: 0x2d3545, w: 16, h: 2.0, d: 0.5, x:   5, y: 30, z: -35, ry: 0.12,  rx: -0.05, rz:  0.02 },
    { color: 0x505f70, w:  9, h: 1.2, d: 0.3, x:  15, y: 33, z: -42, ry: -0.05, rx:  0.02, rz: -0.01 },
    { color: 0x3d4a5a, w: 12, h: 1.6, d: 0.4, x: -25, y: 28, z: -38, ry: 0.1,   rx: -0.04, rz:  0.015},
    { color: 0x2d3545, w: 18, h: 2.2, d: 0.6, x:  -5, y: 27, z: -32, ry: -0.15, rx:  0.05, rz: -0.02 },
    // Deep clouds (further back)
    { color: 0x5a6575, w:  8, h: 1.0, d: 0.2, x:  20, y: 36, z: -60, ry: 0.02,  rx: -0.02, rz:  0.01 },
    { color: 0x4a5565, w: 11, h: 1.5, d: 0.3, x: -15, y: 38, z: -65, ry: -0.06, rx:  0.03, rz: -0.015},
    { color: 0x6a7585, w: 20, h: 2.4, d: 0.5, x:   0, y: 25, z: -70, ry: 0.08,  rx: -0.03, rz:  0.02 },
    { color: 0x3d4a5a, w: 13, h: 1.7, d: 0.4, x: -30, y: 31, z: -55, ry: -0.1,  rx:  0.04, rz: -0.01 },
    { color: 0x2d3545, w: 15, h: 1.9, d: 0.4, x:  25, y: 29, z: -50, ry: 0.07,  rx: -0.05, rz:  0.02 },
    // Very far background mass
    { color: 0x1e2535, w: 30, h: 3.0, d: 0.7, x:  -5, y: 22, z: -80, ry: 0.03,  rx:  0.01, rz: -0.005},
    // High-altitude wispy clouds (h=0.3, very flat)
    { color: 0x6a7585, w: 35, h: 0.3, d: 0.2, x:  -10, y: 45, z: -75, ry: -0.04, rx: -0.01, rz:  0.005},
    { color: 0x5f6e7e, w: 28, h: 0.3, d: 0.15, x: 15, y: 48, z: -80, ry: 0.06,  rx:  0.01, rz: -0.005},
  ];

  for (const cfg of cloudConfigs) {
    const geo = new THREE.BoxGeometry(cfg.w, cfg.h, cfg.d);
    const mat = new THREE.MeshStandardMaterial({
      color: cfg.color,
      flatShading: true,
      roughness: 1.0,
      metalness: 0.0,
    });
    const cloud = new THREE.Mesh(geo, mat);
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
// Large box (BackSide) for dark stormy sky. flatShading for polygon look.

function createSkyBox(): THREE.Mesh {
  const geo = new THREE.BoxGeometry(400, 200, 400);
  const mat = new THREE.MeshStandardMaterial({
    color: 0x1a2030,
    flatShading: true,
    roughness: 1.0,
    metalness: 0.0,
    side: THREE.BackSide,
  });
  return new THREE.Mesh(geo, mat);
}

// ── Vegetation — Angular Bushes ───────────────────────────────────────────────
// ConeGeometry(r, h, 4) = 4 segments → diamond/triangular shape when flat-shaded.

function createVegetation(): THREE.Group {
  const group = new THREE.Group();

  const mat1 = new THREE.MeshStandardMaterial({
    color: 0x1a3020,
    flatShading: true,
    roughness: 1.0,
    metalness: 0.0,
  });
  const mat2 = new THREE.MeshStandardMaterial({
    color: 0x243818,
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
    const geo = new THREE.ConeGeometry(r, h, 4);
    const mat = i % 2 === 0 ? mat1 : mat2;
    const bush = new THREE.Mesh(geo, mat);
    bush.position.set(x, y, z);
    bush.rotation.y = Math.random() * Math.PI;
    group.add(bush);
  }

  return group;
}

// ── Sea Spray Particle System ─────────────────────────────────────────────────

class SeaSpraySystem {
  private readonly points: THREE.Points;
  private readonly positions: Float32Array;
  private readonly particles: ParticleData[] = [];
  private readonly COUNT = 120;

  constructor() {
    this.positions = new Float32Array(this.COUNT * 3);

    for (let i = 0; i < this.COUNT; i++) {
      this.particles.push(this.resetParticle(i));
    }

    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.BufferAttribute(this.positions, 3));

    const mat = new THREE.PointsMaterial({
      color: 0xaaccdd,
      size: 0.2,
      transparent: true,
      opacity: 0.55,
      blending: THREE.AdditiveBlending,
      depthWrite: false,
      sizeAttenuation: true,
    });

    this.points = new THREE.Points(geo, mat);
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

    const posAttr = this.points.geometry.getAttribute('position') as THREE.BufferAttribute;
    posAttr.needsUpdate = true;
  }

  get object(): THREE.Points {
    return this.points;
  }
}

// ── God Ray — additive glow above cliff horizon ───────────────────────────────

function createGodRay(): { mesh: THREE.Mesh; update: (dt: number) => void } {
  const geo = new THREE.PlaneGeometry(12, 22);
  const mat = new THREE.MeshBasicMaterial({
    color: 0xffd090,
    transparent: true,
    opacity: 0.25,
    blending: THREE.AdditiveBlending,
    depthWrite: false,
    side: THREE.DoubleSide,
  });
  const mesh = new THREE.Mesh(geo, mat);
  mesh.position.set(-5, 14, -18);
  mesh.rotation.z = 0.18; // slight tilt toward cliff

  let elapsed = 0;
  const update = (dt: number): void => {
    elapsed += dt;
    // Subtle opacity pulse 0.12..0.28 — reduced range for mobile readability
    (mesh.material as THREE.MeshBasicMaterial).opacity =
      0.20 + Math.sin(elapsed * (Math.PI * 2) / 3.0) * 0.08;
  };

  return { mesh, update };
}

// ── Public: initMainMenu ─────────────────────────────────────────────────────

export function initMainMenu(container: HTMLElement): MainMenuResult {
  const scene = new THREE.Scene();
  scene.background = new THREE.Color(0x1a2030);
  scene.fog = new THREE.FogExp2(0x1a2030, 0.012);

  // Camera: fixed high angle, looking right-to-left over the cliff
  const camera = new THREE.PerspectiveCamera(
    55,
    container.clientWidth / container.clientHeight,
    0.1,
    600
  );
  camera.position.set(-8, 18, 28);
  camera.lookAt(new THREE.Vector3(4, 2, -10));

  // Renderer — no antialias keeps the sharp polygon edges of flat shading
  const renderer = new THREE.WebGLRenderer({
    antialias: false,
    alpha: false,
  });
  renderer.setSize(container.clientWidth, container.clientHeight);
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.5));
  renderer.toneMapping = THREE.NoToneMapping;
  container.appendChild(renderer.domElement);
  renderer.domElement.setAttribute('role', 'img');
  renderer.domElement.setAttribute('aria-label', 'Scène 3D — Côte rocheuse de Bretagne, tour de Merlin sous un ciel orageux');

  // Resize handler
  const onResize = (): void => {
    camera.aspect = container.clientWidth / container.clientHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(container.clientWidth, container.clientHeight);
  };
  window.addEventListener('resize', onResize);

  // Lighting — single directional from top-left (storm light)
  const ambient = new THREE.AmbientLight(0x202030, 0.4);
  scene.add(ambient);

  const stormLight = new THREE.DirectionalLight(0x8899bb, 1.2);
  stormLight.position.set(-20, 30, 10);
  scene.add(stormLight);

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

  let elapsedTime = 0;

  const update = (dt: number): void => {
    elapsedTime += dt;
    ocean.update(elapsedTime);
    clouds.update(elapsedTime);
    foam.update(elapsedTime);
    spray.update(dt);
    godRay.update(dt);
    renderer.render(scene, camera);
  };

  // No-op: camera is static. Calls onComplete immediately for flow compatibility.
  const startDolly = (onComplete: () => void): void => {
    onComplete();
  };

  const dispose = (): void => {
    window.removeEventListener('resize', onResize);
    scene.traverse((obj) => {
      if (obj instanceof THREE.Mesh || obj instanceof THREE.Points) {
        obj.geometry.dispose();
        if (Array.isArray(obj.material)) {
          obj.material.forEach((m) => m.dispose());
        } else {
          (obj.material as THREE.Material).dispose();
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
