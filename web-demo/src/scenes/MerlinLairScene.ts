// Merlin's Lair — 3D interior hub (T062+T064). 4 zones: Map/Crystal/Bookshelf/Door.
// Cycle 31: AAA lighting (5 sources — key/rim/fill/cauldron/ambient).
// Cycle 35: Window + forest view + day/night/season cycle. GLB assets: cauldron/bougie/table/biblio.

import * as THREE from 'three';
import { createLairDensity } from './LairDensity';
import { loadLairGLBs } from './LairGLBAssets';
import { createLairWindow, type LairTimeParams } from './LairWindow';
import { startAmbient, stopAmbient } from '../audio/SFXManager';
import { clearGLBCache } from '../engine/AssetLoader';

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
    roughness: 0.25,
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

  // Crystal sphere (also hit target) — 8×6 segments for readable low-poly facets
  const sphere = new THREE.Mesh(new THREE.SphereGeometry(0.7, 8, 6), crystalMat);
  sphere.position.set(5, -1.0, -4);
  group.add(sphere);

  // Purple glow — range 5 to avoid bleeding onto back wall (was 8)
  const light = new THREE.PointLight(0x9060cc, 2.5, 5, 2);
  light.position.set(5, -1.0, -4);
  group.add(light);

  // C95: separate invisible hit target — survives sphere.visible=false after crystal_ball.glb loads.
  // THREE.js raycasting skips objects with .visible=false; material.visible=false is transparent
  // but the object stays raycast-able. Other zones (bookshelf, door, map) use this pattern.
  const hitSphere = new THREE.Mesh(
    new THREE.SphereGeometry(0.85, 6, 5),
    new THREE.MeshBasicMaterial({ visible: false })
  );
  hitSphere.position.set(5, -1.0, -4);
  group.add(hitSphere);

  return { group, hitTarget: hitSphere, light, mat: crystalMat, sphere };
}

// ── Bookshelf ─────────────────────────────────────────────────────────────────

function createBookshelf(): { group: THREE.Group; hitTarget: THREE.Mesh; frame: THREE.Mesh } {
  const group = new THREE.Group();
  const shelfMat = new THREE.MeshStandardMaterial({ color: 0x3d2b1a, roughness: 0.85, metalness: 0.0, flatShading: true, emissive: 0x2a1a08, emissiveIntensity: 0.0 });
  // C87: pool of 6 shared book materials — was 18 separate instances (3 rows × 6 books)
  const bookMatPool = [0x8b2020, 0x1a4a2a, 0x1a2a5a, 0x5a3a10, 0x4a1060, 0x6a2010].map(
    (c) => new THREE.MeshStandardMaterial({ color: c, roughness: 0.8, metalness: 0.0, flatShading: true })
  );

  // Shelf frame — also returned as visualMesh for emissive hover boost
  const frame = new THREE.Mesh(new THREE.BoxGeometry(3.5, 5.5, 0.8), shelfMat);
  frame.position.set(8, 0.5, -8);
  group.add(frame);

  // 3 shelf rows with books — shared shelf geometry + pooled book materials
  const shelfGeo = new THREE.BoxGeometry(3.2, 0.12, 0.75);
  for (let row = 0; row < 3; row++) {
    const shelf = new THREE.Mesh(shelfGeo, shelfMat);
    shelf.position.set(8, -1.0 + row * 1.7, -8);
    group.add(shelf);

    let xOff = -1.4;
    for (let b = 0; b < 6; b++) {
      const bookW = 0.28 + (b * 0.07) % 0.15;
      const bookH = 1.0 + (b * 0.11) % 0.5;
      const book = new THREE.Mesh(
        new THREE.BoxGeometry(bookW, bookH, 0.58),
        bookMatPool[b % bookMatPool.length]!   // C87: reuse pooled material
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

function createCandles(scene: THREE.Scene): { candles: CandleData[]; group: THREE.Group } {
  // Positions match CANDLE_POSITIONS in LairGLBAssets.ts — procedural fallback aligns to GLB placement
  const candlePositions: Array<[number, number, number]> = [
    [-5, -4.85, -7],
    [0, -4.85, -8.5],
    [3, -4.85, -6],
  ];

  // candleBaseMat is a template only — each body gets its own clone() to prevent
  // emissive hover bleed across all 3 candles (BUG-L-CANDLE-SHARED-MAT).
  const candleBaseMat = new THREE.MeshStandardMaterial({
    color: 0xeedd99,
    roughness: 0.9,
    metalness: 0.0,
    emissive: 0x554400,
    emissiveIntensity: 0.3,
    flatShading: true,
  });
  const wickMat = new THREE.MeshStandardMaterial({ color: 0x111111, roughness: 1.0, flatShading: true });

  const candles: CandleData[] = [];
  // group holds bodies + wicks + sharedLight — hidden when bougie.glb loads
  const group = new THREE.Group();
  scene.add(group);

  // Single shared PointLight covers all 3 candles — saves 2 GPU light slots vs individual lights.
  // Positioned at centroid of the 3 candle positions, larger range to cover all.
  const sharedLight = new THREE.PointLight(0xff9933, 1.8, 9, 2);
  // C108: Y values updated to match actual candlePositions (all cy = -4.85). Former values
  // (-1.6, -4.6, -3.0) were stale from an older layout — light was 1.8u above the flames.
  sharedLight.position.set((-5 + 0 + 3) / 3, (-4.85 + -4.85 + -4.85) / 3 + 0.55, (-7 + -8.5 + -6) / 3);
  group.add(sharedLight);

  for (let i = 0; i < candlePositions.length; i++) {
    const [cx, cy, cz] = candlePositions[i]!;

    // Candle body + wick added to group (hidden when bougie.glb loads)
    // candleBaseMat.clone() ensures each body has an independent material ref.
    const body = new THREE.Mesh(new THREE.CylinderGeometry(0.1, 0.12, 0.7, 8), candleBaseMat.clone());
    body.position.set(cx, cy, cz);
    group.add(body);

    // Wick
    const wick = new THREE.Mesh(new THREE.CylinderGeometry(0.012, 0.012, 0.1, 4), wickMat);
    wick.position.set(cx, cy + 0.4, cz);
    group.add(wick);

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
    // BUG-L-10-CANDLE-MAT fix: add to group (not scene) so particles are hidden
    // when bougie.glb loads and candleGroup.visible = false.
    group.add(points);

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

  // C81-07: template materials are never added to the scene so scene.traverse()
  // in dispose() won't reach them. Dispose here — clones are independent after .clone().
  candleBaseMat.dispose();
  wickMat.dispose();

  return { candles, group };
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
  body: THREE.Mesh;
  glow: THREE.PointLight;
  positions: Float32Array;
  velocities: Float32Array;
  lifetimes: Float32Array;
  geo: THREE.BufferGeometry;
  update: (t: number, dt: number) => void;
}

function createCauldron(scene: THREE.Scene): CauldronSystem {
  const ironMat = new THREE.MeshStandardMaterial({ color: 0x1a1a1a, roughness: 0.5, metalness: 0.6, flatShading: true, emissive: 0x00aa33, emissiveIntensity: 0.0 });
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

  return { group, body, glow, positions, velocities, lifetimes, geo, update };
}

// ── Potion Bottles ────────────────────────────────────────────────────────────

function createPotionBottles(): THREE.Group {
  const group = new THREE.Group();
  const shelfMat = new THREE.MeshStandardMaterial({ color: 0x3d2b1a, roughness: 0.85, metalness: 0.0, flatShading: true });

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

// ── Ambient Lighting — 5-source pass (degraded to 4 on low-end mobile) ──
// C89-P2: lowEnd=true skips backAccent PointLight (Mali-G57/Adreno 610 budget ~4 lights at 60fps)
function setupLighting(scene: THREE.Scene, lowEnd = false): void {
  scene.add(new THREE.AmbientLight(0x1a1008, 0.5));                          // dark warm base
  // C85-02: key moved from overhead [0,8,-2] to forward-angled [0,3,2] — creates
  // depth shadows toward back wall, correct Celtic hall dramaturgy
  const key = new THREE.PointLight(0xff6618, 0.9, 22, 1.6);
  key.position.set(0, 3.0, 2); scene.add(key);                              // forward warm fire
  const rim = new THREE.PointLight(0x6699cc, 0.55, 18, 2.0);
  rim.position.set(8, 2, 7); scene.add(rim);                                 // cool rim from door
  // C89-P2: fill intensity boosted +0.15 on low-end to compensate for missing backAccent depth
  const fill = new THREE.PointLight(0xcc8833, lowEnd ? 0.55 : 0.4, 16, 2.0);
  fill.position.set(-9, 0, -5); scene.add(fill);                             // warm fill left wall
  if (!lowEnd) {
    // C85-02: back-wall accent — warm ember glow throwing forward shadows from rear (skipped on low-end)
    const backAccent = new THREE.PointLight(0xff5500, 0.35, 12, 2.0);
    backAccent.position.set(0, 1.5, -11); scene.add(backAccent);
  }
}

// ── Main Export ──────────────────────────────────────────────────────────────
export function initMerlinLair(container: HTMLElement): LairResult {
  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false });
  renderer.setSize(container.clientWidth, container.clientHeight);
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.setClearColor(0x0d0a08, 1);
  container.appendChild(renderer.domElement);
  // C85-01: ARIA accessibility — canvas is interactive region
  renderer.domElement.setAttribute('role', 'application');
  renderer.domElement.setAttribute('aria-label', 'Antre de Merlin — 5 zones interactives. Tab pour naviguer, Entrée pour activer.');
  renderer.domElement.setAttribute('tabindex', '0');
  renderer.domElement.style.touchAction = 'none'; // prevent mobile scroll interference
  // C102: auto-focus canvas so C85-01 keyboard nav works without requiring a prior click
  // { preventScroll: true } avoids iOS/desktop layout jump on initial mount
  renderer.domElement.focus({ preventScroll: true });
  // C88: aria-live region — screen readers announce zone focus/activation (WCAG 2.1 AA)
  const ariaLive = document.createElement('div');
  ariaLive.setAttribute('aria-live', 'polite');
  ariaLive.setAttribute('aria-atomic', 'true');
  ariaLive.style.cssText = 'position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0,0,0,0);white-space:nowrap;';
  container.style.position = container.style.position || 'relative';
  container.appendChild(ariaLive);

  // C101: zone hover lore toast — sighted players need text context (aria-live only serves screen readers)
  const zoneToast = document.createElement('div');
  zoneToast.style.cssText = [
    'position:absolute;bottom:16px;left:50%;transform:translateX(-50%);',
    'background:rgba(10,8,6,0.82);border:1px solid rgba(205,133,63,0.35);border-radius:8px;',
    'padding:8px 18px;font-family:Georgia,serif;text-align:center;',
    'pointer-events:none;opacity:0;transition:opacity 0.2s ease;',
    'display:flex;flex-direction:column;gap:2px;line-height:1.4;min-width:180px;',
  ].join('');
  container.appendChild(zoneToast);

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
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2)); // C102: re-sync DPR on zoom/monitor switch
  };
  // C117: ResizeObserver fires on container resize (sidebar collapse, flex changes) — window.resize
  // only fires when the viewport changes, missing layout-driven container size changes.
  let resizeObserver: ResizeObserver | null = null;
  if (typeof ResizeObserver !== 'undefined') {
    resizeObserver = new ResizeObserver(onResize);
    resizeObserver.observe(container);
  } else {
    window.addEventListener('resize', onResize); // fallback for very old environments
  }

  // Build scene elements
  // C89-P2: detect low-end mobile (Android/iOS high-DPR) → drop 5th PointLight to stay at 60fps
  // C90-P2: intentionally static — evaluated once at scene init. Orientation changes after init
  // do not re-evaluate; this is acceptable since lighting is rebuilt only on scene reconstruct.
  const isLowEndMobile = /Android|iPhone|iPad|iPod/i.test(navigator.userAgent) && window.devicePixelRatio >= 2;
  setupLighting(scene, isLowEndMobile);
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

  const { candles, group: candleGroup } = createCandles(scene);
  const dust = createDustMotes();
  scene.add(dust.points);

  const cauldron = createCauldron(scene);
  scene.add(createPotionBottles());
  scene.add(createSkull());
  createLairDensity(scene);

  // Cauldron interactive hit target (sphere r=0.9, centred on cauldron.body y=-3.8)
  // C107: aligned to visual center — was y=-4.0 (0.2u below visual, BUG-39-13)
  const cauldronHit = new THREE.Mesh(
    new THREE.SphereGeometry(0.9, 8, 6),
    new THREE.MeshBasicMaterial({ visible: false })
  );
  cauldronHit.position.set(2, -3.8, -7);
  scene.add(cauldronHit);

  // Forest window + day/night/season cycle
  const lairWindow = createLairWindow(scene);

  // GLB asset overlays (async — procedural fallbacks remain if GLB unavailable).
  // Pass procedural groups so table_druidique.glb + bibliotheque.glb hide them on load (fixes z-fighting).
  // C81-03: disposed flag prevents late-resolving GLBs from adding to a torn-down scene.
  let lairDisposed = false;
  let crystalGLBGroup: THREE.Group | null = null; // C101: stored to sync float animation to GLB
  let crystalGLBBaseY = -1.0; // C118: base Y from GLB export root; overwritten by onCrystalGroupLoaded
  // C111: stored to animate GLB emissive in update loop (procedural mat targets hidden sphere post-load)
  let crystalGLBMat: THREE.MeshStandardMaterial | null = null;
  let doorFlashing = false;    // C101: door cinematic — lights/emissive burst before transition
  let doorFlashTimer = 0;
  let doorFlashCancelHandle = 0; // C102: tracked to allow clearTimeout in dispose()
  // C102: FPS monitoring — adaptive quality drops dust when < 45fps sustained
  let fpsFrameCount = 0;
  let fpsElapsed = 0;
  let lowFpsMode = false;
  loadLairGLBs(scene, {
    mapGroup, shelfGroup, floorMesh, wallsGroup,
    cauldronGroup: cauldron.group, candleGroup,
    crystalSphere: crystalData.sphere,
    // When GLB loads, swap visualMesh to the GLB body so hover emissive works on GLB path
    onCauldronGLBLoaded: (mesh) => {
      const entry = interactives.find((i) => i.zone === 'cauldron');
      if (entry) entry.visualMesh = mesh;
    },
    // C95: swap crystal visualMesh to GLB mesh so hover emissive targets GLB (not hidden sphere)
    // C111: also capture GLB material so update loop can animate its emissiveIntensity (BUG-C46-01)
    onCrystalGLBLoaded: (mesh) => {
      const entry = interactives.find((i) => i.zone === 'crystal');
      if (entry) entry.visualMesh = mesh;
      crystalGLBMat = mesh.material as THREE.MeshStandardMaterial;
    },
    // C101: store GLB group so update loop can animate its Y position (float effect)
    // C118: also capture base Y so float animation is a delta (not hardcoded -1.0)
    onCrystalGroupLoaded: (group) => { crystalGLBGroup = group; crystalGLBBaseY = group.position.y; },
  }, () => lairDisposed);

  // C93-P1: forest ambient audio — SFXManager handles AudioContext suspension via pendingAmbientType
  startAmbient('forest');

  // Interactive zones for raycasting (visualMesh = visible mesh for emissive boost)
  const interactives: InteractiveObject[] = [
    { mesh: mapHit,              zone: 'map',       hovered: false, baseEmissive: 0.15 },
    { mesh: crystalData.hitTarget, zone: 'crystal', hovered: false, visualMesh: crystalData.sphere, baseEmissive: 0.6 },
    { mesh: shelfHit,            zone: 'bookshelf', hovered: false, visualMesh: shelfFrame, baseEmissive: 0.0 },
    { mesh: doorHit,             zone: 'door',      hovered: false, visualMesh: doorPanel,  baseEmissive: 0.05 },
    { mesh: cauldronHit,         zone: 'cauldron',  hovered: false, visualMesh: cauldron.body, baseEmissive: 0.0 },
  ];

  // C118: cache crystalEntry ref at init — avoids Array.find() closure allocation in 60fps update loop
  const crystalEntry = interactives.find((i) => i.zone === 'crystal')!;

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
        // C97: scale applied to visualMesh (visible geometry), not hitTarget (invisible raycast mesh)
        (currentHovered.visualMesh ?? currentHovered.mesh).scale.setScalar(1.0);
        applyHoverTo(currentHovered, currentHovered.baseEmissive ?? 0.15);
      }
      currentHovered = found;
      if (currentHovered) {
        currentHovered.hovered = true;
        (currentHovered.visualMesh ?? currentHovered.mesh).scale.setScalar(1.05);
        applyHoverTo(currentHovered, 0.65);
        renderer.domElement.style.cursor = 'pointer';
        // C82-01: subtle shimmer on zone enter — SFXManager listens via window 'merlin_sfx'
        window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'hover' } }));
        // C101: show lore toast with zone name + description
        const zone = currentHovered.zone;
        // C104: textContent — XSS-safe, forward-compatible if zone labels come from LLM
        zoneToast.textContent = '';
        const lbl = document.createElement('strong');
        lbl.style.cssText = 'color:#cd853f;font-size:15px;';
        lbl.textContent = ZONE_ARIA_LABELS[zone];
        const desc = document.createElement('span');
        desc.style.cssText = 'color:rgba(232,220,200,0.7);font-size:12px;';
        desc.textContent = ZONE_LORE[zone];
        zoneToast.appendChild(lbl);
        zoneToast.appendChild(desc);
        zoneToast.style.opacity = '1';
      } else {
        renderer.domElement.style.cursor = 'default';
        zoneToast.style.opacity = '0';
      }
    }
  };

  // C85-01: zone label map (used by pointer action + keyboard nav + aria-live)
  const ZONE_ARIA_LABELS: Readonly<Record<LairZone, string>> = {
    map:       'Carte des Biomes',
    crystal:   'Pierre des Oghams',
    bookshelf: 'Journal de Merlin',
    cauldron:  'Chaudron Druidique',
    door:      'Sortie vers l\'aventure',
  };

  // C110: lore descriptions enhanced — Celtic-immersive atmosphere (was generic UI copy).
  // References specific mythological anchors: Cerridwen (cauldron goddess), Brocéliande (sacred forest).
  const ZONE_LORE: Readonly<Record<LairZone, string>> = {
    map:       'Quelle contrée de Bretagne t\'appelle ce soir ?',
    crystal:   'Les runes d\'ogham murmurent dans la pierre sacrée',
    bookshelf: 'Les chroniques de Merlin gardent mémoire de tes actes',
    cauldron:  'Le chaudron de Cerridwen bouillonne de sagesse ancienne',
    door:      'Les bois de Brocéliande t\'attendent, voyageur',
  };

  const onPointerAction = (e: { clientX: number; clientY: number }): void => {
    const rect = renderer.domElement.getBoundingClientRect();
    mouse.x = ((e.clientX - rect.left) / rect.width) * 2 - 1;
    mouse.y = -((e.clientY - rect.top) / rect.height) * 2 + 1;
    const found = getIntersected();
    if (found && zoneClickCallback) {
      // C82-01: confirm click audio before callback (which may trigger scene transition)
      window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'flip' } }));
      ariaLive.textContent = `${ZONE_ARIA_LABELS[found.zone]} activée`;
      if (found.zone === 'door') {
        // C101: cinematic flash — 380ms burst before transition to give visual drama
        const cb = zoneClickCallback; // capture before setTimeout (TypeScript narrowing)
        doorFlashing = true;
        doorFlashTimer = 0;
        (doorPanel.material as THREE.MeshStandardMaterial).emissiveIntensity = 1.2;
        window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'magic_reveal' } }));
        doorFlashCancelHandle = window.setTimeout(() => {
          doorFlashing = false;
          if (!lairDisposed) cb(found.zone); // C102: guard against stale callback after dispose()
        }, 380);
      } else {
        zoneClickCallback(found.zone);
      }
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
  // C85-01: touchend clears hover — prevents zones staying visually stuck on mobile
  const onTouchEnd = (): void => {
    if (currentHovered) {
      currentHovered.hovered = false;
      // C98: scale on visualMesh (visible geometry), not hitTarget (invisible)
      (currentHovered.visualMesh ?? currentHovered.mesh).scale.setScalar(1.0);
      applyHoverTo(currentHovered, currentHovered.baseEmissive ?? 0.15);
      currentHovered = null;
      renderer.domElement.style.cursor = 'default';
    }
  };

  // C85-01: keyboard navigation — Tab cycles zones, Enter/Space activates
  const KEYBOARD_ZONES: LairZone[] = ['map', 'crystal', 'bookshelf', 'cauldron', 'door'];
  let keyboardZoneIdx = -1;
  const onKeyDown = (e: KeyboardEvent): void => {
    if (e.key === 'Tab' || e.key === 'ArrowRight' || e.key === 'ArrowDown') {
      e.preventDefault();
      keyboardZoneIdx = (keyboardZoneIdx + 1) % KEYBOARD_ZONES.length;
    } else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') {
      e.preventDefault();
      keyboardZoneIdx = (keyboardZoneIdx - 1 + KEYBOARD_ZONES.length) % KEYBOARD_ZONES.length;
    } else if ((e.key === 'Enter' || e.key === ' ') && currentHovered && zoneClickCallback) {
      e.preventDefault();
      window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'flip' } }));
      ariaLive.textContent = `${ZONE_ARIA_LABELS[currentHovered.zone]} activée`;
      // C113: keyboard door activation mirrors pointer cinematic — 380ms flash + magic_reveal SFX
      if (currentHovered.zone === 'door') {
        const kbZone = currentHovered.zone;
        const kbCb = zoneClickCallback;
        doorFlashing = true;
        doorFlashTimer = 0;
        (doorPanel.material as THREE.MeshStandardMaterial).emissiveIntensity = 1.2;
        window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'magic_reveal' } }));
        doorFlashCancelHandle = window.setTimeout(() => {
          doorFlashing = false;
          if (!lairDisposed) kbCb(kbZone);
        }, 380);
      } else {
        zoneClickCallback(currentHovered.zone);
      }
      return;
    } else {
      return;
    }
    const zone = KEYBOARD_ZONES[keyboardZoneIdx]!;
    const next = interactives.find((i) => i.zone === zone) ?? null;
    if (currentHovered && currentHovered !== next) {
      currentHovered.hovered = false;
      // C98: scale on visualMesh (visible geometry), not hitTarget (invisible)
      (currentHovered.visualMesh ?? currentHovered.mesh).scale.setScalar(1.0);
      applyHoverTo(currentHovered, currentHovered.baseEmissive ?? 0.15);
    }
    currentHovered = next;
    if (currentHovered) {
      currentHovered.hovered = true;
      (currentHovered.visualMesh ?? currentHovered.mesh).scale.setScalar(1.05);
      applyHoverTo(currentHovered, 0.65);
      window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'hover' } }));
      renderer.domElement.setAttribute('aria-label', `Zone active : ${ZONE_ARIA_LABELS[zone]} — Entrée pour activer`);
      ariaLive.textContent = `${ZONE_ARIA_LABELS[zone]} — Appuyez sur Entrée pour activer`;
      // C101: sync lore toast with keyboard navigation (onMouseMove only fires on pointer)
      // C104: textContent — XSS-safe (keyboard path mirrors pointer path)
      zoneToast.textContent = '';
      const kLbl = document.createElement('strong');
      kLbl.style.cssText = 'color:#cd853f;font-size:15px;';
      kLbl.textContent = ZONE_ARIA_LABELS[zone];
      const kDesc = document.createElement('span');
      kDesc.style.cssText = 'color:rgba(232,220,200,0.7);font-size:12px;';
      kDesc.textContent = ZONE_LORE[zone];
      zoneToast.appendChild(kLbl);
      zoneToast.appendChild(kDesc);
      zoneToast.style.opacity = '1';
    } else {
      zoneToast.style.opacity = '0';
    }
  };

  renderer.domElement.addEventListener('mousemove', onMouseMove);
  renderer.domElement.addEventListener('click', onPointerAction);
  renderer.domElement.addEventListener('touchmove', onTouchMove, { passive: false });
  renderer.domElement.addEventListener('touchstart', onTouchStart, { passive: false });
  renderer.domElement.addEventListener('touchend', onTouchEnd);
  renderer.domElement.addEventListener('keydown', onKeyDown);

  // Update loop
  const update = (dt: number): void => {
    if (lairDisposed) return; // C105: guard stale rAF frame after dispose() on slow devices
    elapsedTime += dt;

    // Camera slow sway (fixed camera, slight oscillation for life)
    camera.position.x = Math.sin(elapsedTime * 0.3 * Math.PI * 2) * 0.1;
    camera.position.y = 0.5 + Math.sin(elapsedTime * 0.23 * Math.PI * 2) * 0.06;

    // Crystal ball pulse
    crystalData.light.intensity = 2.2 + Math.sin(elapsedTime * 1.8) * 0.4;
    // C113: boost emissive base when crystal is hovered — unhovered=0.5, hovered=0.9.
    // Without this, update loop overrides applyHoverTo(0.65) every frame → hover invisible.
    // C118: use cached crystalEntry (set at init) — no Array.find() allocation on hot path
    const crystalEmissive = (crystalEntry.hovered ? 0.9 : 0.5) + Math.sin(elapsedTime * 1.4) * 0.15;
    crystalData.mat.emissiveIntensity = crystalEmissive;
    // C111: also animate GLB material emissive — procedural mat targets hidden sphere post-load (BUG-C46-01)
    if (crystalGLBMat) crystalGLBMat.emissiveIntensity = crystalEmissive;
    // C118: procedural sphere uses -1.0 (always correct); GLB uses crystalGLBBaseY delta (GLB root Y)
    crystalData.sphere.position.y = -1.0 + Math.sin(elapsedTime * 0.9) * 0.04;
    // C101: sync GLB group float — procedural sphere is hidden post-load, GLB takes its place
    if (crystalGLBGroup) crystalGLBGroup.position.y = crystalGLBBaseY + Math.sin(elapsedTime * 0.9) * 0.04;

    // Door light flicker — C101: burst overrides normal flicker during door cinematic
    if (doorFlashing) {
      doorFlashTimer += dt;
      doorLight.intensity = 12 + Math.sin(doorFlashTimer * 45) * 4;
    } else {
      doorLight.intensity = 2.8 + Math.sin(elapsedTime * 4.1) * 0.3;
    }

    // C102: FPS monitoring — sample every 2s, enable low-fps mode below 45fps
    fpsFrameCount++;
    fpsElapsed += dt;
    if (fpsElapsed >= 2.0) {
      const fps = fpsFrameCount / fpsElapsed;
      // C108: hysteresis band [45, 52] — prevents dust particles toggling when FPS hovers ~45fps
      if (fps < 45) lowFpsMode = true;
      else if (fps > 52) lowFpsMode = false;
      fpsFrameCount = 0;
      fpsElapsed = 0;
    }

    // Candles (T064)
    updateCandles(candles, dt, elapsedTime);

    // Dust motes — C102: skip on low-fps devices (pure cosmetic, saves ~1ms/frame)
    if (!lowFpsMode) dust.update(dt);

    // Cauldron steam
    cauldron.update(elapsedTime, dt);

    // Forest window (leaf sway + glass shimmer)
    lairWindow.update(elapsedTime);

    renderer.render(scene, camera);
  };

  const dispose = (): void => {
    lairDisposed = true; // C81-03: signal in-flight GLB .then() callbacks to abort
    clearTimeout(doorFlashCancelHandle); // C102: prevent stale door transition after teardown
    stopAmbient(); // C93-P1: stop forest ambient on scene teardown
    // C117: clear GLB cache before geometry.dispose() — prevents returning disposed-geometry GLTF
    // on second lair visit (cauldron/table/biblio/sol_pierre/crystal_ball added as gltf.scene directly)
    clearGLBCache();
    if (resizeObserver) {
      resizeObserver.disconnect();
    } else {
      window.removeEventListener('resize', onResize);
    }
    renderer.domElement.removeEventListener('mousemove', onMouseMove);
    renderer.domElement.removeEventListener('click', onPointerAction);
    renderer.domElement.removeEventListener('touchmove', onTouchMove);
    renderer.domElement.removeEventListener('touchstart', onTouchStart);
    renderer.domElement.removeEventListener('touchend', onTouchEnd);
    renderer.domElement.removeEventListener('keydown', onKeyDown);
    scene.traverse((obj) => {
      if (obj instanceof THREE.InstancedMesh) {
        // C109: InstancedMesh.dispose() fires the renderer 'dispose' event so the instanceMatrix
        // GPU buffer (InstancedBufferAttribute) is deallocated. Without this call, instanceMatrix
        // data leaks on repeated hub ↔ lair navigations — geometry.dispose() alone only clears
        // the base vertex attributes, not the per-instance matrix buffer.
        obj.dispose();
        obj.geometry.dispose();
        (obj.material as THREE.Material).dispose();
      } else if (obj instanceof THREE.Mesh || obj instanceof THREE.Points) {
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
    if (ariaLive.parentNode) {
      ariaLive.parentNode.removeChild(ariaLive);
    }
    if (zoneToast.parentNode) {
      zoneToast.parentNode.removeChild(zoneToast);
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
