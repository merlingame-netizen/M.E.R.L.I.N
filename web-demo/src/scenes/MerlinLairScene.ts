// Merlin's Lair — 3D interior hub (T062+T064). 4 zones: Map/Crystal/Bookshelf/Door.
// Cycle 31: AAA lighting (5 sources — key/rim/fill/cauldron/ambient).
// Cycle 35: Window + forest view + day/night/season cycle. GLB assets: cauldron/bougie/table/biblio.

import * as THREE from 'three';
import { createLairDensity } from './LairDensity';
import { loadLairGLBs } from './LairGLBAssets';
import { createLairWindow, type LairTimeParams } from './LairWindow';

// ── Types ────────────────────────────────────────────────────────────────────

// GDB mapping: map=biome, crystal=oghams, bookshelf=journal, door=run, cauldron=dialogue_merlin
export type LairZone = 'map' | 'crystal' | 'bookshelf' | 'door' | 'cauldron';

interface InteractiveObject {
  mesh: THREE.Object3D;
  zone: LairZone;
  hovered: boolean;
  visualMesh?: THREE.Mesh;   // visible mesh for emissive boost when hitTarget is invisible
  baseEmissive?: number;     // emissiveIntensity to restore on unhover
}

export interface LairResult {
  update: (dt: number) => void;
  dispose: () => void;
  onZoneClick: (cb: (zone: LairZone) => void) => void;
  setTime: (params: LairTimeParams) => void;
}

export type { LairTimeParams };

// ── Stone Walls + Floor + Ceiling ────────────────────────────────────────────

function createWalls(): { group: THREE.Group; floorMesh: THREE.Mesh; wallsGroup: THREE.Group } {
  const group = new THREE.Group();
  const wallsGroup = new THREE.Group(); // contains only the 3 wall boxes (hidden when mur_pierre.glb loads)
  const stoneMat = new THREE.MeshStandardMaterial({ color: 0x3a3228, roughness: 0.95, metalness: 0.0, flatShading: true });
  const mortarMat = new THREE.MeshStandardMaterial({ color: 0x2a2420, roughness: 1.0, metalness: 0.0, flatShading: true });

  // Back wall
  const back = new THREE.Mesh(new THREE.BoxGeometry(24, 16, 0.5), stoneMat);
  back.position.set(0, 3, -10);
  group.add(back); wallsGroup.add(back);

  // Left wall
  const left = new THREE.Mesh(new THREE.BoxGeometry(0.5, 16, 20), stoneMat);
  left.position.set(-12, 3, 0);
  group.add(left); wallsGroup.add(left);

  // Right wall
  const right = new THREE.Mesh(new THREE.BoxGeometry(0.5, 16, 20), stoneMat);
  right.position.set(12, 3, 0);
  group.add(right); wallsGroup.add(right);

  // Flagstone floor
  const floorMat = new THREE.MeshStandardMaterial({ color: 0x201c18, roughness: 0.9, metalness: 0.0, flatShading: true });
  const floor = new THREE.Mesh(new THREE.BoxGeometry(24, 0.3, 20), floorMat);
  floor.position.set(0, -5, 0);
  group.add(floor);

  // Ceiling
  const ceilMat = new THREE.MeshStandardMaterial({ color: 0x1a1610, roughness: 1.0, metalness: 0.0, flatShading: true });
  const ceil = new THREE.Mesh(new THREE.BoxGeometry(24, 0.4, 20), ceilMat);
  ceil.position.set(0, 11, 0);
  group.add(ceil);

  // Wooden beams
  const beamMat = new THREE.MeshStandardMaterial({ color: 0x3d2b1a, roughness: 0.85, metalness: 0.0, flatShading: true });
  const beamPositions: Array<[number, number, number]> = [[-4, 10.5, -5], [4, 10.5, -5], [-4, 10.5, 3], [4, 10.5, 3]];
  for (const [x, y, z] of beamPositions) {
    const beam = new THREE.Mesh(new THREE.BoxGeometry(1.2, 0.8, 0.8), beamMat);
    beam.position.set(x, y, z);
    group.add(beam);
  }
  // Cross beams
  const hBeam1 = new THREE.Mesh(new THREE.BoxGeometry(0.8, 0.6, 16), beamMat);
  hBeam1.position.set(-4, 10.8, -1);
  group.add(hBeam1);
  const hBeam2 = new THREE.Mesh(new THREE.BoxGeometry(0.8, 0.6, 16), beamMat);
  hBeam2.position.set(4, 10.8, -1);
  group.add(hBeam2);

  // Stone mortar lines
  for (let i = -3; i <= 3; i++) {
    const mortar = new THREE.Mesh(new THREE.BoxGeometry(24, 0.08, 0.5), mortarMat);
    mortar.position.set(0, i * 1.5 + 3, -9.74);
    group.add(mortar);
  }

  return { group, floorMesh: floor, wallsGroup };
}

// ── Table with Map/Scroll ────────────────────────────────────────────────────

function createMapTable(): { group: THREE.Group; hitTarget: THREE.Mesh } {
  const group = new THREE.Group();
  const woodMat = new THREE.MeshStandardMaterial({ color: 0x4a3520, roughness: 0.8, metalness: 0.0, flatShading: true });
  const mapMat = new THREE.MeshStandardMaterial({
    color: 0xc8a96e,
    roughness: 0.6,
    metalness: 0.0,
    emissive: 0x3a2a10,
    emissiveIntensity: 0.15,
    flatShading: true,
  });

  // Table top
  const top = new THREE.Mesh(new THREE.BoxGeometry(4, 0.18, 2.5), woodMat);
  top.position.set(-5, -2, -3);
  group.add(top);

  // Table legs
  const legPositions: Array<[number, number]> = [[-6.8, -4.2], [-3.2, -4.2], [-6.8, -1.8], [-3.2, -1.8]];
  for (const [lx, lz] of legPositions) {
    const leg = new THREE.Mesh(new THREE.BoxGeometry(0.2, 3, 0.2), woodMat);
    leg.position.set(lx, -3.5, lz);
    group.add(leg);
  }

  // Map/scroll on table (hit target)
  const scroll = new THREE.Mesh(new THREE.BoxGeometry(3, 0.08, 1.8), mapMat);
  scroll.position.set(-5, -1.88, -3);
  group.add(scroll);

  // Scroll border
  const scrollBorder = new THREE.Mesh(
    new THREE.BoxGeometry(3.1, 0.06, 0.15),
    new THREE.MeshStandardMaterial({ color: 0x8b6a3a, roughness: 0.7, metalness: 0.1, flatShading: true })
  );
  scrollBorder.position.set(-5, -1.87, -4.0);
  group.add(scrollBorder);

  return { group, hitTarget: scroll };
}

// ── Crystal Ball ─────────────────────────────────────────────────────────────

interface CrystalResult {
  group: THREE.Group;
  hitTarget: THREE.Mesh;
  light: THREE.PointLight;
  mat: THREE.MeshStandardMaterial;
  sphere: THREE.Mesh;
}

function createCrystalBall(): CrystalResult {
  const group = new THREE.Group();
  const pedestalMat = new THREE.MeshStandardMaterial({ color: 0x2a2220, roughness: 0.6, metalness: 0.3, flatShading: true });
  const crystalMat = new THREE.MeshStandardMaterial({
    color: 0x9060cc,
    roughness: 0.05,
    metalness: 0.1,
    transparent: true,
    opacity: 0.82,
    emissive: 0x6030aa,
    emissiveIntensity: 0.6,
    flatShading: true,
  });

  // Pedestal
  const pedestal = new THREE.Mesh(new THREE.CylinderGeometry(0.4, 0.55, 0.9, 8), pedestalMat);
  pedestal.position.set(5, -2, -4);
  group.add(pedestal);

  // Crystal sphere (also hit target)
  const sphere = new THREE.Mesh(new THREE.SphereGeometry(0.7, 16, 16), crystalMat);
  sphere.position.set(5, -1.0, -4);
  group.add(sphere);

  // Purple glow
  const light = new THREE.PointLight(0x9060cc, 2.5, 8, 2);
  light.position.set(5, -1.0, -4);
  group.add(light);

  return { group, hitTarget: sphere, light, mat: crystalMat, sphere };
}

// ── Bookshelf ─────────────────────────────────────────────────────────────────

function createBookshelf(): { group: THREE.Group; hitTarget: THREE.Mesh; frame: THREE.Mesh } {
  const group = new THREE.Group();
  const shelfMat = new THREE.MeshStandardMaterial({ color: 0x3d2b1a, roughness: 0.85, metalness: 0.0, flatShading: true, emissive: 0x2a1a08, emissiveIntensity: 0.0 });
  const bookColors = [0x8b2020, 0x1a4a2a, 0x1a2a5a, 0x5a3a10, 0x4a1060, 0x6a2010];

  // Shelf frame — also returned as visualMesh for emissive hover boost
  const frame = new THREE.Mesh(new THREE.BoxGeometry(3.5, 5.5, 0.8), shelfMat);
  frame.position.set(8, 0.5, -8);
  group.add(frame);

  // 3 shelf rows with books
  for (let row = 0; row < 3; row++) {
    const shelf = new THREE.Mesh(new THREE.BoxGeometry(3.2, 0.12, 0.75), shelfMat);
    shelf.position.set(8, -1.0 + row * 1.7, -8);
    group.add(shelf);

    let xOff = -1.4;
    for (let b = 0; b < 6; b++) {
      const bookW = 0.28 + (b * 0.07) % 0.15;
      const bookH = 1.0 + (b * 0.11) % 0.5;
      const book = new THREE.Mesh(
        new THREE.BoxGeometry(bookW, bookH, 0.58),
        new THREE.MeshStandardMaterial({ color: bookColors[b % bookColors.length]!, roughness: 0.8, metalness: 0.0, flatShading: true })
      );
      book.position.set(8 + xOff + bookW / 2, -0.45 + row * 1.7 + bookH / 2, -8);
      book.rotation.y = (b % 2 === 0 ? 1 : -1) * 0.04;
      group.add(book);
      xOff += bookW + 0.04;
    }
  }

  // Invisible hit target (front face)
  const hitTarget = new THREE.Mesh(
    new THREE.BoxGeometry(3.5, 5.5, 0.15),
    new THREE.MeshBasicMaterial({ visible: false })
  );
  hitTarget.position.set(8, 0.5, -7.65);
  group.add(hitTarget);

  return { group, hitTarget, frame };
}

// ── Door with Light Underneath ────────────────────────────────────────────────

interface DoorResult {
  group: THREE.Group;
  hitTarget: THREE.Mesh;
  lightBeam: THREE.PointLight;
  doorPanel: THREE.Mesh;  // visible panel for emissive hover boost
}

function createDoor(): DoorResult {
  const group = new THREE.Group();
  const doorMat = new THREE.MeshStandardMaterial({ color: 0x2e1f0e, roughness: 0.9, metalness: 0.05, flatShading: true, emissive: 0x5a3010, emissiveIntensity: 0.05 });
  const ironMat = new THREE.MeshStandardMaterial({ color: 0x2a2828, roughness: 0.5, metalness: 0.7, flatShading: true });
  const lightMat = new THREE.MeshBasicMaterial({ color: 0xffdd88, transparent: true, opacity: 0.85 });

  // Door frame
  const frameL = new THREE.Mesh(new THREE.BoxGeometry(0.3, 7, 0.5), doorMat);
  frameL.position.set(-10.1, 0.5, 4);
  group.add(frameL);
  const frameR = new THREE.Mesh(new THREE.BoxGeometry(0.3, 7, 0.5), doorMat);
  frameR.position.set(-10.1, 0.5, 7);
  group.add(frameR);
  const frameTop = new THREE.Mesh(new THREE.BoxGeometry(0.3, 0.3, 3.6), doorMat);
  frameTop.position.set(-10.1, 4.2, 5.5);
  group.add(frameTop);

  // Door panel
  const door = new THREE.Mesh(new THREE.BoxGeometry(0.15, 6.5, 3), doorMat);
  door.position.set(-10.15, 0.25, 5.5);
  group.add(door);

  // Iron straps
  for (let i = 0; i < 3; i++) {
    const strap = new THREE.Mesh(new THREE.BoxGeometry(0.18, 0.12, 2.8), ironMat);
    strap.position.set(-10.07, -1.5 + i * 1.8, 5.5);
    group.add(strap);
  }

  // Light sliver under door
  const lightSliver = new THREE.Mesh(new THREE.BoxGeometry(0.05, 0.06, 2.8), lightMat);
  lightSliver.position.set(-10.07, -2.17, 5.5);
  group.add(lightSliver);

  // Point light seeping through
  const lightBeam = new THREE.PointLight(0xffdd66, 3.0, 5, 2);
  lightBeam.position.set(-9.8, -1.8, 5.5);
  group.add(lightBeam);

  // Invisible hit target
  const hitTarget = new THREE.Mesh(
    new THREE.BoxGeometry(0.5, 7, 3.5),
    new THREE.MeshBasicMaterial({ visible: false })
  );
  hitTarget.position.set(-9.9, 0.5, 5.5);
  group.add(hitTarget);

  return { group, hitTarget, lightBeam, doorPanel: door };
}

// ── Candle System (T064) ──────────────────────────────────────────────────────

interface CandleData {
  light: THREE.PointLight;
  particles: Float32Array;
  particleVel: Float32Array;
  particleLife: Float32Array;
  particleGeo: THREE.BufferGeometry;
  phase: number;
  cx: number;
  cy: number;
  cz: number;
}

function createCandles(scene: THREE.Scene): CandleData[] {
  const candlePositions: Array<[number, number, number]> = [
    [-5, -1.6, -7],
    [0, -4.6, -8.5],
    [3, -3.0, -6],
  ];

  const candleMat = new THREE.MeshStandardMaterial({
    color: 0xeedd99,
    roughness: 0.9,
    metalness: 0.0,
    emissive: 0x554400,
    emissiveIntensity: 0.3,
    flatShading: true,
  });
  const wickMat = new THREE.MeshStandardMaterial({ color: 0x111111, roughness: 1.0, flatShading: true });

  const candles: CandleData[] = [];

  // Single shared PointLight covers all 3 candles — saves 2 GPU light slots vs individual lights.
  // Positioned at centroid of the 3 candle positions, larger range to cover all.
  const sharedLight = new THREE.PointLight(0xff9933, 1.8, 9, 2);
  sharedLight.position.set((-5 + 0 + 3) / 3, (-1.6 + -4.6 + -3.0) / 3 + 0.55, (-7 + -8.5 + -6) / 3);
  scene.add(sharedLight);

  for (let i = 0; i < candlePositions.length; i++) {
    const [cx, cy, cz] = candlePositions[i]!;

    // Candle body
    const body = new THREE.Mesh(new THREE.CylinderGeometry(0.1, 0.12, 0.7, 8), candleMat);
    body.position.set(cx, cy, cz);
    scene.add(body);

    // Wick
    const wick = new THREE.Mesh(new THREE.CylinderGeometry(0.012, 0.012, 0.1, 4), wickMat);
    wick.position.set(cx, cy + 0.4, cz);
    scene.add(wick);

    // All candles reference the shared light; updateCandles drives intensity from last candle's flicker.
    const light = sharedLight;

    // Particle system (20 particles, upward drift, orange→transparent)
    const N = 20;
    const positions = new Float32Array(N * 3);
    const velocities = new Float32Array(N * 3);
    const lifetimes = new Float32Array(N);
    const maxLife = 1.2;

    for (let p = 0; p < N; p++) {
      lifetimes[p] = Math.random() * maxLife;
      const lifeRatio = (lifetimes[p] ?? 0) / maxLife;
      positions[p * 3 + 0] = cx + (Math.random() - 0.5) * 0.04;
      positions[p * 3 + 1] = cy + 0.55 + lifeRatio * 0.36;
      positions[p * 3 + 2] = cz + (Math.random() - 0.5) * 0.04;
      velocities[p * 3 + 0] = (Math.random() - 0.5) * 0.03;
      velocities[p * 3 + 1] = 0.18 + Math.random() * 0.12;
      velocities[p * 3 + 2] = (Math.random() - 0.5) * 0.03;
    }

    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.BufferAttribute(positions, 3));

    const particleMat = new THREE.PointsMaterial({
      color: 0xff7722,
      size: 0.06,
      transparent: true,
      opacity: 0.75,
      blending: THREE.AdditiveBlending,
      depthWrite: false,
    });

    const points = new THREE.Points(geo, particleMat);
    scene.add(points);

    candles.push({
      light,
      particles: positions,
      particleVel: velocities,
      particleLife: lifetimes,
      particleGeo: geo,
      phase: i * 1.37,
      cx,
      cy,
      cz,
    });
  }

  return candles;
}

function updateCandles(candles: CandleData[], dt: number, t: number): void {
  const maxLife = 1.2;
  for (const candle of candles) {
    // Flicker: multi-frequency sin
    const flicker =
      Math.sin(t * 7.3 + candle.phase) * 0.25 +
      Math.sin(t * 13.1 + candle.phase * 2.1) * 0.1 +
      Math.sin(t * 3.7 + candle.phase * 0.5) * 0.08;
    candle.light.intensity = 1.8 + flicker;

    const N = candle.particleLife.length;
    for (let p = 0; p < N; p++) {
      candle.particleLife[p]! += dt;
      if ((candle.particleLife[p] ?? 0) >= maxLife) {
        // Reset particle at flame origin
        candle.particleLife[p] = 0;
        candle.particles[p * 3 + 0] = candle.cx + (Math.random() - 0.5) * 0.04;
        candle.particles[p * 3 + 1] = candle.cy + 0.55;
        candle.particles[p * 3 + 2] = candle.cz + (Math.random() - 0.5) * 0.04;
        candle.particleVel[p * 3 + 0] = (Math.random() - 0.5) * 0.03;
        candle.particleVel[p * 3 + 1] = 0.18 + Math.random() * 0.12;
        candle.particleVel[p * 3 + 2] = (Math.random() - 0.5) * 0.03;
      } else {
        candle.particles[p * 3 + 0]! += (candle.particleVel[p * 3 + 0] ?? 0) * dt;
        candle.particles[p * 3 + 1]! += (candle.particleVel[p * 3 + 1] ?? 0) * dt;
        candle.particles[p * 3 + 2]! += (candle.particleVel[p * 3 + 2] ?? 0) * dt;
        // Slight horizontal drift
        candle.particleVel[p * 3 + 0]! += (Math.random() - 0.5) * 0.005;
      }
    }
    candle.particleGeo.attributes['position']!.needsUpdate = true;
  }
}

// ── Dust Motes ────────────────────────────────────────────────────────────────

interface DustSystem {
  points: THREE.Points;
  update: (dt: number) => void;
}

function createDustMotes(): DustSystem {
  const N = 80;
  const positions = new Float32Array(N * 3);
  const velocities = new Float32Array(N * 3);

  for (let i = 0; i < N; i++) {
    positions[i * 3 + 0] = (Math.random() - 0.5) * 20;
    positions[i * 3 + 1] = (Math.random() - 0.5) * 10 + 2;
    positions[i * 3 + 2] = (Math.random() - 0.5) * 16;
    velocities[i * 3 + 0] = (Math.random() - 0.5) * 0.02;
    velocities[i * 3 + 1] = (Math.random() - 0.5) * 0.008 + 0.003;
    velocities[i * 3 + 2] = (Math.random() - 0.5) * 0.015;
  }

  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.BufferAttribute(positions, 3));

  const mat = new THREE.PointsMaterial({
    color: 0xddccaa,
    size: 0.04,
    transparent: true,
    opacity: 0.35,
    blending: THREE.AdditiveBlending,
    depthWrite: false,
  });

  const points = new THREE.Points(geo, mat);

  const update = (dt: number): void => {
    const speed = dt * 60;
    for (let i = 0; i < N; i++) {
      positions[i * 3 + 0]! += (velocities[i * 3 + 0] ?? 0) * speed;
      positions[i * 3 + 1]! += (velocities[i * 3 + 1] ?? 0) * speed;
      positions[i * 3 + 2]! += (velocities[i * 3 + 2] ?? 0) * speed;
      if ((positions[i * 3 + 0] ?? 0) > 10) positions[i * 3 + 0] = -10;
      if ((positions[i * 3 + 0] ?? 0) < -10) positions[i * 3 + 0] = 10;
      if ((positions[i * 3 + 1] ?? 0) > 8) positions[i * 3 + 1] = -3;
      if ((positions[i * 3 + 1] ?? 0) < -3) positions[i * 3 + 1] = 8;
      if ((positions[i * 3 + 2] ?? 0) > 8) positions[i * 3 + 2] = -8;
      if ((positions[i * 3 + 2] ?? 0) < -8) positions[i * 3 + 2] = 8;
    }
    geo.attributes['position']!.needsUpdate = true;
  };

  return { points, update };
}

// ── Cauldron with Green Steam ─────────────────────────────────────────────────

interface CauldronSystem {
  group: THREE.Group;
  glow: THREE.PointLight;
  positions: Float32Array;
  velocities: Float32Array;
  lifetimes: Float32Array;
  geo: THREE.BufferGeometry;
  update: (t: number, dt: number) => void;
}

function createCauldron(scene: THREE.Scene): CauldronSystem {
  const ironMat = new THREE.MeshStandardMaterial({ color: 0x1a1a1a, roughness: 0.5, metalness: 0.6, flatShading: true });
  const steamMat = new THREE.PointsMaterial({
    color: 0x44cc88,
    size: 0.12,
    transparent: true,
    opacity: 0.55,
    blending: THREE.AdditiveBlending,
    depthWrite: false,
  });

  const group = new THREE.Group();

  // Cauldron body
  const body = new THREE.Mesh(new THREE.SphereGeometry(0.65, 10, 8), ironMat);
  body.scale.y = 0.8;
  body.position.set(2, -3.8, -7);
  group.add(body);
  scene.add(group);

  // Legs
  const legDef: Array<[number, number]> = [[-0.4, -0.3], [0.4, -0.3], [0, 0.5]];
  for (const [lx, lz] of legDef) {
    const leg = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.05, 0.5, 5), ironMat);
    leg.position.set(2 + lx, -4.4, -7 + lz);
    group.add(leg);
  }

  // Green glow
  const glow = new THREE.PointLight(0x22cc44, 1.2, 3.5, 2);
  glow.position.set(2, -3.2, -7);
  group.add(glow);

  // Steam particles
  const N = 30;
  const positions = new Float32Array(N * 3);
  const velocities = new Float32Array(N * 3);
  const lifetimes = new Float32Array(N);
  const maxLife = 2.0;

  for (let p = 0; p < N; p++) {
    lifetimes[p] = Math.random() * maxLife;
    const lr = (lifetimes[p] ?? 0) / maxLife;
    positions[p * 3 + 0] = 2 + (Math.random() - 0.5) * 0.5;
    positions[p * 3 + 1] = -3.2 + lr * 0.7;
    positions[p * 3 + 2] = -7 + (Math.random() - 0.5) * 0.5;
    velocities[p * 3 + 0] = (Math.random() - 0.5) * 0.04;
    velocities[p * 3 + 1] = 0.12 + Math.random() * 0.1;
    velocities[p * 3 + 2] = (Math.random() - 0.5) * 0.04;
  }

  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.BufferAttribute(positions, 3));
  const steamPoints = new THREE.Points(geo, steamMat);
  group.add(steamPoints);

  const update = (t: number, dt: number): void => {
    glow.intensity = 1.1 + Math.sin(t * 2.3) * 0.15;
    for (let p = 0; p < N; p++) {
      lifetimes[p]! += dt;
      if ((lifetimes[p] ?? 0) >= maxLife) {
        lifetimes[p] = 0;
        positions[p * 3 + 0] = 2 + (Math.random() - 0.5) * 0.5;
        positions[p * 3 + 1] = -3.2;
        positions[p * 3 + 2] = -7 + (Math.random() - 0.5) * 0.5;
        velocities[p * 3 + 0] = (Math.random() - 0.5) * 0.04;
        velocities[p * 3 + 1] = 0.12 + Math.random() * 0.1;
        velocities[p * 3 + 2] = (Math.random() - 0.5) * 0.04;
      } else {
        positions[p * 3 + 0]! += (velocities[p * 3 + 0] ?? 0) * dt;
        positions[p * 3 + 1]! += (velocities[p * 3 + 1] ?? 0) * dt;
        positions[p * 3 + 2]! += (velocities[p * 3 + 2] ?? 0) * dt;
      }
    }
    geo.attributes['position']!.needsUpdate = true;
  };

  return { group, glow, positions, velocities, lifetimes, geo, update };
}

// ── Potion Bottles ────────────────────────────────────────────────────────────

function createPotionBottles(): THREE.Group {
  const group = new THREE.Group();
  const shelfMat = new THREE.MeshStandardMaterial({ color: 0x3d2b1a, roughness: 0.85, flatShading: true });

  const smallShelf = new THREE.Mesh(new THREE.BoxGeometry(2.5, 0.1, 0.5), shelfMat);
  smallShelf.position.set(6, -3.5, -7.7);
  group.add(smallShelf);

  const bottleData: Array<{ color: number; x: number; y: number; z: number }> = [
    { color: 0xcc2222, x: 5.4, y: -3.2, z: -7.5 },
    { color: 0x2244cc, x: 6.1, y: -3.3, z: -7.8 },
    { color: 0x22aa44, x: 6.8, y: -3.35, z: -7.6 },
  ];

  for (const b of bottleData) {
    const mat = new THREE.MeshStandardMaterial({
      color: b.color,
      roughness: 0.1,
      metalness: 0.0,
      transparent: true,
      opacity: 0.78,
      emissive: b.color,
      emissiveIntensity: 0.25,
      flatShading: true,
    });
    const bottle = new THREE.Mesh(new THREE.CylinderGeometry(0.12, 0.15, 0.55, 8), mat);
    bottle.position.set(b.x, b.y, b.z);
    group.add(bottle);
    const neck = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.1, 0.18, 6), mat);
    neck.position.set(b.x, b.y + 0.35, b.z);
    group.add(neck);
  }

  return group;
}

// ── Skull ─────────────────────────────────────────────────────────────────────

function createSkull(): THREE.Group {
  const group = new THREE.Group();
  const boneMat = new THREE.MeshStandardMaterial({ color: 0xd4c89a, roughness: 0.7, metalness: 0.0, flatShading: true });
  const cranium = new THREE.Mesh(new THREE.SphereGeometry(0.22, 8, 7), boneMat);
  cranium.scale.y = 0.85;
  cranium.position.set(9, -1.9, -9);
  group.add(cranium);
  const jaw = new THREE.Mesh(new THREE.BoxGeometry(0.28, 0.12, 0.22), boneMat);
  jaw.position.set(9, -2.18, -9.02);
  group.add(jaw);
  return group;
}

// ── Ambient Lighting — 3-source pass (mobile-safe: AmbientLight + key + rim + fill = 4) ──
function setupLighting(scene: THREE.Scene): void {
  scene.add(new THREE.AmbientLight(0x1a1008, 0.5));                          // dark warm base
  const key = new THREE.PointLight(0xff6618, 1.1, 22, 1.6);
  key.position.set(0, 8, -2); scene.add(key);                                // overhead warm fire
  const rim = new THREE.PointLight(0x6699cc, 0.55, 18, 2.0);
  rim.position.set(8, 2, 7); scene.add(rim);                                 // cool rim from door
  const fill = new THREE.PointLight(0xcc8833, 0.4, 16, 2.0);
  fill.position.set(-9, 0, -5); scene.add(fill);                             // warm fill left wall
  // shelfFill and cauldron accent removed — crystal + CauldronSystem.glow cover those areas
}

// ── Main Export ──────────────────────────────────────────────────────────────
export function initMerlinLair(container: HTMLElement): LairResult {
  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false });
  renderer.setSize(container.clientWidth, container.clientHeight);
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.setClearColor(0x0d0a08, 1);
  container.appendChild(renderer.domElement);

  // Scene + Camera
  const scene = new THREE.Scene();
  scene.fog = new THREE.Fog(0x0d0a08, 12, 28);

  const camera = new THREE.PerspectiveCamera(62, container.clientWidth / container.clientHeight, 0.1, 60);
  camera.position.set(0, 0.5, 7);
  camera.lookAt(0, 0, -4);

  const onResize = (): void => {
    const w = container.clientWidth;
    const h = container.clientHeight;
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
    renderer.setSize(w, h);
  };
  window.addEventListener('resize', onResize);

  // Build scene elements
  setupLighting(scene);
  const { group: wallsRootGroup, floorMesh, wallsGroup } = createWalls();
  scene.add(wallsRootGroup);

  const { group: mapGroup, hitTarget: mapHit } = createMapTable();
  scene.add(mapGroup);

  const crystalData = createCrystalBall();
  scene.add(crystalData.group);

  const { group: shelfGroup, hitTarget: shelfHit, frame: shelfFrame } = createBookshelf();
  scene.add(shelfGroup);

  const { group: doorGroup, hitTarget: doorHit, lightBeam: doorLight, doorPanel } = createDoor();
  scene.add(doorGroup);

  const candles = createCandles(scene);
  const dust = createDustMotes();
  scene.add(dust.points);

  const cauldron = createCauldron(scene);
  scene.add(createPotionBottles());
  scene.add(createSkull());
  createLairDensity(scene);

  // Cauldron interactive hit target (sphere r=1.2, oracle Merlin dialogue zone)
  const cauldronHit = new THREE.Mesh(
    new THREE.SphereGeometry(1.2, 8, 6),
    new THREE.MeshBasicMaterial({ visible: false })
  );
  cauldronHit.position.set(2, -3.0, -7);
  scene.add(cauldronHit);

  // Forest window + day/night/season cycle
  const lairWindow = createLairWindow(scene);

  // GLB asset overlays (async — procedural fallbacks remain if GLB unavailable).
  // Pass procedural groups so table_druidique.glb + bibliotheque.glb hide them on load (fixes z-fighting).
  loadLairGLBs(scene, { mapGroup, shelfGroup, floorMesh, wallsGroup, cauldronGroup: cauldron.group });

  // Interactive zones for raycasting (visualMesh = visible mesh for emissive boost)
  const interactives: InteractiveObject[] = [
    { mesh: mapHit,              zone: 'map',       hovered: false, baseEmissive: 0.15 },
    { mesh: crystalData.hitTarget, zone: 'crystal', hovered: false, baseEmissive: 0.6  },
    { mesh: shelfHit,            zone: 'bookshelf', hovered: false, visualMesh: shelfFrame, baseEmissive: 0.0 },
    { mesh: doorHit,             zone: 'door',      hovered: false, visualMesh: doorPanel,  baseEmissive: 0.05 },
    { mesh: cauldronHit,         zone: 'cauldron',  hovered: false, baseEmissive: 0.0 },
  ];

  const raycaster = new THREE.Raycaster();
  const mouse = new THREE.Vector2();
  let zoneClickCallback: ((zone: LairZone) => void) | null = null;
  let elapsedTime = 0;
  let currentHovered: InteractiveObject | null = null;

  const getIntersected = (): InteractiveObject | null => {
    raycaster.setFromCamera(mouse, camera);
    const targets = interactives.map((i) => i.mesh);
    const hits = raycaster.intersectObjects(targets, true);
    if (hits.length === 0) return null;
    const hitObj = hits[0]!.object;
    return interactives.find((i) => i.mesh === hitObj || i.mesh.getObjectById(hitObj.id) !== undefined) ?? null;
  };

  const applyHoverTo = (obj: InteractiveObject, intensity: number): void => {
    const target = obj.visualMesh ?? (obj.mesh as THREE.Mesh);
    const mat = target.material as THREE.MeshStandardMaterial;
    if (mat?.emissive) mat.emissiveIntensity = intensity;
  };

  const onMouseMove = (e: { clientX: number; clientY: number }): void => {
    const rect = renderer.domElement.getBoundingClientRect();
    mouse.x = ((e.clientX - rect.left) / rect.width) * 2 - 1;
    mouse.y = -((e.clientY - rect.top) / rect.height) * 2 + 1;
    const found = getIntersected();
    if (found !== currentHovered) {
      if (currentHovered) {
        currentHovered.hovered = false;
        currentHovered.mesh.scale.setScalar(1.0);
        applyHoverTo(currentHovered, currentHovered.baseEmissive ?? 0.15);
      }
      currentHovered = found;
      if (currentHovered) {
        currentHovered.hovered = true;
        currentHovered.mesh.scale.setScalar(1.05);
        applyHoverTo(currentHovered, 0.65);
        renderer.domElement.style.cursor = 'pointer';
      } else {
        renderer.domElement.style.cursor = 'default';
      }
    }
  };

  const onPointerAction = (e: { clientX: number; clientY: number }): void => {
    const rect = renderer.domElement.getBoundingClientRect();
    mouse.x = ((e.clientX - rect.left) / rect.width) * 2 - 1;
    mouse.y = -((e.clientY - rect.top) / rect.height) * 2 + 1;
    const found = getIntersected();
    if (found && zoneClickCallback) {
      zoneClickCallback(found.zone);
    }
  };

  // Touch → pointer bridge (BUG-L-06 fix)
  const onTouchMove = (e: TouchEvent): void => {
    e.preventDefault();
    const t = e.touches[0] ?? e.changedTouches[0];
    if (t) onMouseMove({ clientX: t.clientX, clientY: t.clientY });
  };
  const onTouchStart = (e: TouchEvent): void => {
    e.preventDefault();
    const t = e.touches[0] ?? e.changedTouches[0];
    if (t) onPointerAction({ clientX: t.clientX, clientY: t.clientY });
  };

  renderer.domElement.addEventListener('mousemove', onMouseMove);
  renderer.domElement.addEventListener('click', onPointerAction);
  renderer.domElement.addEventListener('touchmove', onTouchMove, { passive: false });
  renderer.domElement.addEventListener('touchstart', onTouchStart, { passive: false });

  // Update loop
  const update = (dt: number): void => {
    elapsedTime += dt;

    // Camera slow sway (fixed camera, slight oscillation for life)
    camera.position.x = Math.sin(elapsedTime * 0.3 * Math.PI * 2) * 0.1;
    camera.position.y = 0.5 + Math.sin(elapsedTime * 0.23 * Math.PI * 2) * 0.06;

    // Crystal ball pulse
    crystalData.light.intensity = 2.2 + Math.sin(elapsedTime * 1.8) * 0.4;
    crystalData.mat.emissiveIntensity = 0.5 + Math.sin(elapsedTime * 1.4) * 0.15;
    crystalData.sphere.position.y = -1.0 + Math.sin(elapsedTime * 0.9) * 0.04;

    // Door light flicker
    doorLight.intensity = 2.8 + Math.sin(elapsedTime * 4.1) * 0.3;

    // Candles (T064)
    updateCandles(candles, dt, elapsedTime);

    // Dust motes
    dust.update(dt);

    // Cauldron steam
    cauldron.update(elapsedTime, dt);

    // Forest window (leaf sway + glass shimmer)
    lairWindow.update(elapsedTime);

    renderer.render(scene, camera);
  };

  const dispose = (): void => {
    window.removeEventListener('resize', onResize);
    renderer.domElement.removeEventListener('mousemove', onMouseMove);
    renderer.domElement.removeEventListener('click', onPointerAction);
    renderer.domElement.removeEventListener('touchmove', onTouchMove);
    renderer.domElement.removeEventListener('touchstart', onTouchStart);
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
    renderer.domElement.style.cursor = 'default';
  };

  const onZoneClick = (cb: (zone: LairZone) => void): void => {
    zoneClickCallback = cb;
  };

  const setTime = (params: LairTimeParams): void => {
    lairWindow.updateTime(params);
  };

  return { update, dispose, onZoneClick, setTime };
}
