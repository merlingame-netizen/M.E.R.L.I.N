// Merlin's Lair — 3D interior hub (T062+T064). 4 zones: Map/Crystal/Bookshelf/Door.
// Cycle 31: AAA lighting (6 sources — key/rim/fill/cauldron/hemi/ambient; C36 added HemisphereLight).
// Cycle 35: Window + forest view + day/night/season cycle. GLB assets: cauldron/bougie/table/biblio.

import { AdditiveBlending, AmbientLight, BoxGeometry, BufferAttribute, BufferGeometry, CylinderGeometry, Fog, Group, HemisphereLight, InstancedMesh, Material, Mesh, MeshBasicMaterial, MeshStandardMaterial, Object3D, PerspectiveCamera, PointLight, Points, PointsMaterial, Raycaster, Scene, SphereGeometry, TorusGeometry, Vector2, WebGLRenderer } from 'three';
import { createLairDensity } from './LairDensity';
import { loadLairGLBs } from './LairGLBAssets';
import { createLairWindow, type LairTimeParams } from './LairWindow';
import { startAmbient, stopAmbient } from '../audio/SFXManager';
import { clearGLBCache } from '../engine/AssetLoader';

// ── Types ────────────────────────────────────────────────────────────────────

// GDB mapping: map=biome, crystal=oghams, bookshelf=journal, door=run, cauldron=dialogue_merlin
export type LairZone = 'map' | 'crystal' | 'bookshelf' | 'door' | 'cauldron' | 'skull';

interface InteractiveObject {
  mesh: Object3D;
  zone: LairZone;
  hovered: boolean;
  visualMesh?: Mesh;   // visible mesh for emissive boost when hitTarget is invisible
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

function createWalls(): { group: Group; floorMesh: Mesh; wallsGroup: Group } {
  const group = new Group();
  const wallsGroup = new Group(); // contains only the 3 wall boxes (hidden when mur_pierre.glb loads)
  const stoneMat = new MeshStandardMaterial({ color: 0x3a3228, roughness: 0.95, metalness: 0.0, flatShading: true });
  const mortarMat = new MeshStandardMaterial({ color: 0x2a2420, roughness: 1.0, metalness: 0.0, flatShading: true });
  // C129: mortar lines at z=-9.74 are 0.01u in front of back wall front face at z=-9.75.
  // polygonOffset prevents z-fighting against mur_pierre InstancedMesh tiles on 16-bit depth GPUs.
  mortarMat.polygonOffset = true;
  mortarMat.polygonOffsetFactor = -2; // C79: align with scene-wide standard (was -1 — weaker than mur_pierre/sol_pierre -2/-4)
  mortarMat.polygonOffsetUnits = -4;  // C79: -2/-4 matches GLB overlay pattern; prevents mortar z-fight on 16-bit depth GPUs

  // Back wall
  const back = new Mesh(new BoxGeometry(24, 16, 0.5), stoneMat);
  back.position.set(0, 3, -10);
  group.add(back); wallsGroup.add(back);

  // Left wall
  const left = new Mesh(new BoxGeometry(0.5, 16, 20), stoneMat);
  left.position.set(-12, 3, 0);
  group.add(left); wallsGroup.add(left);

  // Right wall
  const right = new Mesh(new BoxGeometry(0.5, 16, 20), stoneMat);
  right.position.set(12, 3, 0);
  group.add(right); wallsGroup.add(right);

  // Flagstone floor
  const floorMat = new MeshStandardMaterial({ color: 0x201c18, roughness: 0.9, metalness: 0.0, flatShading: true });
  const floor = new Mesh(new BoxGeometry(24, 0.3, 20), floorMat);
  floor.position.set(0, -5, 0);
  group.add(floor);

  // Ceiling
  const ceilMat = new MeshStandardMaterial({ color: 0x1a1610, roughness: 1.0, metalness: 0.0, flatShading: true });
  const ceil = new Mesh(new BoxGeometry(24, 0.4, 20), ceilMat);
  ceil.position.set(0, 11, 0);
  group.add(ceil);

  // Wooden beams
  const beamMat = new MeshStandardMaterial({ color: 0x3d2b1a, roughness: 0.85, metalness: 0.0, flatShading: true });
  const beamPositions: Array<[number, number, number]> = [[-4, 10.5, -5], [4, 10.5, -5], [-4, 10.5, 3], [4, 10.5, 3]];
  for (const [x, y, z] of beamPositions) {
    const beam = new Mesh(new BoxGeometry(1.2, 0.8, 0.8), beamMat);
    beam.position.set(x, y, z);
    group.add(beam);
  }
  // Cross beams
  const hBeam1 = new Mesh(new BoxGeometry(0.8, 0.6, 16), beamMat);
  hBeam1.position.set(-4, 10.8, -1);
  group.add(hBeam1);
  const hBeam2 = new Mesh(new BoxGeometry(0.8, 0.6, 16), beamMat);
  hBeam2.position.set(4, 10.8, -1);
  group.add(hBeam2);

  // Stone mortar lines
  for (let i = -3; i <= 3; i++) {
    const mortar = new Mesh(new BoxGeometry(24, 0.08, 0.5), mortarMat);
    mortar.position.set(0, i * 1.5 + 3, -9.74);
    group.add(mortar);
  }

  return { group, floorMesh: floor, wallsGroup };
}

// ── Table with Map/Scroll ────────────────────────────────────────────────────

function createMapTable(): { group: Group; hitTarget: Mesh } {
  const group = new Group();
  const woodMat = new MeshStandardMaterial({ color: 0x4a3520, roughness: 0.8, metalness: 0.0, flatShading: true });
  const mapMat = new MeshStandardMaterial({
    color: 0xc8a96e,
    roughness: 0.6,
    metalness: 0.0,
    emissive: 0x3a2a10,
    emissiveIntensity: 0.15,
    flatShading: true,
  });

  // Table top
  const top = new Mesh(new BoxGeometry(4, 0.18, 2.5), woodMat);
  top.position.set(-5, -2, -3);
  group.add(top);

  // Table legs
  const legPositions: Array<[number, number]> = [[-6.8, -4.2], [-3.2, -4.2], [-6.8, -1.8], [-3.2, -1.8]];
  for (const [lx, lz] of legPositions) {
    const leg = new Mesh(new BoxGeometry(0.2, 3, 0.2), woodMat);
    leg.position.set(lx, -3.5, lz);
    group.add(leg);
  }

  // Map/scroll on table (hit target)
  const scroll = new Mesh(new BoxGeometry(3, 0.08, 1.8), mapMat);
  scroll.position.set(-5, -1.88, -3);
  group.add(scroll);

  // Scroll border
  const scrollBorder = new Mesh(
    new BoxGeometry(3.1, 0.06, 0.15),
    new MeshStandardMaterial({ color: 0x8b6a3a, roughness: 0.7, metalness: 0.1, flatShading: true })
  );
  scrollBorder.position.set(-5, -1.87, -4.0);
  group.add(scrollBorder);

  return { group, hitTarget: scroll };
}

// ── Crystal Ball ─────────────────────────────────────────────────────────────

interface CrystalResult {
  group: Group;
  hitTarget: Mesh;
  light: PointLight;
  mat: MeshStandardMaterial;
  sphere: Mesh;
}

function createCrystalBall(): CrystalResult {
  const group = new Group();
  const pedestalMat = new MeshStandardMaterial({ color: 0x2a2220, roughness: 0.85, metalness: 0.05, flatShading: true }); // C46: dark basalt/slate register (was 0.6/0.3 = polished metal)
  const crystalMat = new MeshStandardMaterial({
    color: 0x9060cc,
    roughness: 0.25,
    metalness: 0.1,
    transparent: true,
    opacity: 0.82,
    emissive: 0x6030aa,
    emissiveIntensity: 0.6,
    // C49: no flatShading — crystal is the only transparent PBR material; smooth normals
    // enable refractive shimmer on the oracle sphere (all other materials keep flatShading:true).
  });

  // Pedestal
  const pedestal = new Mesh(new CylinderGeometry(0.4, 0.55, 0.9, 8), pedestalMat);
  pedestal.position.set(5, -2, -4);
  group.add(pedestal);

  // Crystal sphere (also hit target) — 8×6 segments for readable low-poly facets
  // C51: 16×12 segments (192 faces) — smooth silhouette now that C49 removed flatShading.
  // 8×6 (48 faces) left visible equatorial facets even with interpolated normals.
  const sphere = new Mesh(new SphereGeometry(0.7, 16, 12), crystalMat);
  sphere.position.set(5, -1.0, -4);
  group.add(sphere);

  // Purple glow — range 5 to avoid bleeding onto back wall (was 8)
  const light = new PointLight(0x9060cc, 2.5, 5, 2);
  light.position.set(5, -1.0, -4);
  group.add(light);

  // C95: separate invisible hit target — survives sphere.visible=false after crystal_ball.glb loads.
  // Three.js raycasting skips objects with .visible=false; material.visible=false is transparent
  // but the object stays raycast-able. Other zones (bookshelf, door, map) use this pattern.
  const hitSphere = new Mesh(
    new SphereGeometry(0.85, 6, 5),
    new MeshBasicMaterial({ visible: false })
  );
  hitSphere.position.set(5, -1.0, -4);
  group.add(hitSphere);

  return { group, hitTarget: hitSphere, light, mat: crystalMat, sphere };
}

// ── Bookshelf ─────────────────────────────────────────────────────────────────

function createBookshelf(): { group: Group; hitTarget: Mesh; frame: Mesh } {
  const group = new Group();
  const shelfMat = new MeshStandardMaterial({ color: 0x3d2b1a, roughness: 0.85, metalness: 0.0, flatShading: true, emissive: 0x2a1a08, emissiveIntensity: 0.0 });
  // C87: pool of 6 shared book materials — was 18 separate instances (3 rows × 6 books)
  const bookMatPool = [0x8b2020, 0x1a4a2a, 0x1a2a5a, 0x5a3a10, 0x4a1060, 0x6a2010].map(
    (c) => new MeshStandardMaterial({ color: c, roughness: 0.8, metalness: 0.0, flatShading: true })
  );

  // Shelf frame — also returned as visualMesh for emissive hover boost
  const frame = new Mesh(new BoxGeometry(3.5, 5.5, 0.8), shelfMat);
  frame.position.set(8, 0.5, -8);
  group.add(frame);

  // 3 shelf rows with books — shared shelf geometry + pooled book materials
  const shelfGeo = new BoxGeometry(3.2, 0.12, 0.75);
  for (let row = 0; row < 3; row++) {
    const shelf = new Mesh(shelfGeo, shelfMat);
    shelf.position.set(8, -1.0 + row * 1.7, -8);
    group.add(shelf);

    let xOff = -1.4;
    for (let b = 0; b < 6; b++) {
      const bookW = 0.28 + (b * 0.07) % 0.15;
      const bookH = 1.0 + (b * 0.11) % 0.5;
      const book = new Mesh(
        new BoxGeometry(bookW, bookH, 0.58),
        bookMatPool[b % bookMatPool.length]!   // C87: reuse pooled material
      );
      book.position.set(8 + xOff + bookW / 2, -0.45 + row * 1.7 + bookH / 2, -8);
      book.rotation.y = (b % 2 === 0 ? 1 : -1) * 0.04;
      group.add(book);
      xOff += bookW + 0.04;
    }
  }

  // Invisible hit target (front face)
  const hitTarget = new Mesh(
    new BoxGeometry(3.5, 5.5, 0.15),
    new MeshBasicMaterial({ visible: false })
  );
  hitTarget.position.set(8, 0.5, -7.65);
  group.add(hitTarget);

  return { group, hitTarget, frame };
}

// ── Door with Light Underneath ────────────────────────────────────────────────

interface DoorResult {
  group: Group;
  hitTarget: Mesh;
  lightBeam: PointLight;
  doorPanel: Mesh;  // visible panel for emissive hover boost
}

function createDoor(): DoorResult {
  const group = new Group();
  const doorMat = new MeshStandardMaterial({ color: 0x2e1f0e, roughness: 0.9, metalness: 0.05, flatShading: true, emissive: 0x5a3010, emissiveIntensity: 0.05 });
  const ironMat = new MeshStandardMaterial({ color: 0x2a2828, roughness: 0.5, metalness: 0.7, flatShading: true });
  const lightMat = new MeshBasicMaterial({ color: 0x88ffcc, transparent: true, opacity: 0.85 });

  // Door frame
  const frameL = new Mesh(new BoxGeometry(0.3, 7, 0.5), doorMat);
  frameL.position.set(-10.1, 0.5, 4);
  group.add(frameL);
  const frameR = new Mesh(new BoxGeometry(0.3, 7, 0.5), doorMat);
  frameR.position.set(-10.1, 0.5, 7);
  group.add(frameR);
  const frameTop = new Mesh(new BoxGeometry(0.3, 0.3, 3.6), doorMat);
  frameTop.position.set(-10.1, 4.2, 5.5);
  group.add(frameTop);

  // Door panel — C122/DOOR-ZF-01: clone doorMat to isolate polygonOffset on panel only.
  // Panel (0.15u thick) overlaps with frame corners (z=4.0±0.25, z=7.0±0.25) at shared X range.
  // polygonOffset biases panel forward in depth so it renders consistently on top of frame faces.
  const panelMat = doorMat.clone();
  panelMat.polygonOffset = true;
  panelMat.polygonOffsetFactor = -1;
  panelMat.polygonOffsetUnits = -2;
  const door = new Mesh(new BoxGeometry(0.15, 6.5, 3), panelMat);
  door.position.set(-10.15, 0.25, 5.5);
  group.add(door);

  // Iron straps
  for (let i = 0; i < 3; i++) {
    const strap = new Mesh(new BoxGeometry(0.18, 0.12, 2.8), ironMat);
    strap.position.set(-10.07, -1.5 + i * 1.8, 5.5);
    group.add(strap);
  }

  // Light sliver under door
  const lightSliver = new Mesh(new BoxGeometry(0.05, 0.06, 2.8), lightMat);
  lightSliver.position.set(-10.07, -2.17, 5.5);
  group.add(lightSliver);

  // Point light seeping through
  const lightBeam = new PointLight(0x44ffaa, 3.0, 5, 2);
  lightBeam.position.set(-9.8, -1.8, 5.5);
  group.add(lightBeam);

  // Invisible hit target
  const hitTarget = new Mesh(
    new BoxGeometry(0.5, 7, 3.5),
    new MeshBasicMaterial({ visible: false })
  );
  hitTarget.position.set(-9.9, 0.5, 5.5);
  group.add(hitTarget);

  return { group, hitTarget, lightBeam, doorPanel: door };
}

// ── Candle System (T064) ──────────────────────────────────────────────────────

interface CandleData {
  light: PointLight;
  particles: Float32Array;
  particleVel: Float32Array;
  particleLife: Float32Array;
  particleGeo: BufferGeometry;
  phase: number;
  cx: number;
  cy: number;
  cz: number;
}

// C131/CANDLES-FACTORY-01: removed scene parameter — scene.add(group) moved to call site to match
// every other factory in this file (createWalls, createMapTable, createCrystalBall, createBookshelf,
// createDoor, createCauldron all return a group; caller does scene.add). Prevents the BUG-L-DOUBLE-ADD
// class of bug where internal scene.add creates an ambiguous responsibility boundary.
function createCandles(): { candles: CandleData[]; group: Group } {
  // Positions match CANDLE_POSITIONS in LairGLBAssets.ts — procedural fallback aligns to GLB placement
  const candlePositions: Array<[number, number, number]> = [
    [-5, -4.85, -7],
    [0, -4.85, -8.5],
    [3, -4.85, -6],
  ];

  // candleBaseMat is a template only — each body gets its own clone() to prevent
  // emissive hover bleed across all 3 candles (BUG-L-CANDLE-SHARED-MAT).
  const candleBaseMat = new MeshStandardMaterial({
    color: 0xeedd99,
    roughness: 0.9,
    metalness: 0.0,
    emissive: 0x554400,
    emissiveIntensity: 0.3,
    flatShading: true,
  });
  const wickMat = new MeshStandardMaterial({ color: 0x111111, roughness: 1.0, flatShading: true });

  const candles: CandleData[] = [];
  // group holds bodies + wicks + sharedLight — hidden when bougie.glb loads
  const group = new Group();

  // Single shared PointLight covers all 3 candles — saves 2 GPU light slots vs individual lights.
  // Positioned at centroid of the 3 candle positions, larger range to cover all.
  const sharedLight = new PointLight(0x33aa55, 1.8, 9, 2);
  // C108: Y values updated to match actual candlePositions (all cy = -4.85). Former values
  // (-1.6, -4.6, -3.0) were stale from an older layout — light was 1.8u above the flames.
  sharedLight.position.set((-5 + 0 + 3) / 3, (-4.85 + -4.85 + -4.85) / 3 + 0.55, (-7 + -8.5 + -6) / 3);
  group.add(sharedLight);

  for (let i = 0; i < candlePositions.length; i++) {
    const [cx, cy, cz] = candlePositions[i]!;

    // Candle body + wick added to group (hidden when bougie.glb loads)
    // candleBaseMat.clone() ensures each body has an independent material ref.
    const body = new Mesh(new CylinderGeometry(0.1, 0.12, 0.7, 8), candleBaseMat.clone());
    body.position.set(cx, cy, cz);
    group.add(body);

    // Wick
    const wick = new Mesh(new CylinderGeometry(0.012, 0.012, 0.1, 4), wickMat);
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

    const geo = new BufferGeometry();
    geo.setAttribute('position', new BufferAttribute(positions, 3));

    const particleMat = new PointsMaterial({
      color: 0xff7722,
      size: 0.06,
      transparent: true,
      opacity: 0.75,
      blending: AdditiveBlending,
      depthWrite: false,
    });

    const points = new Points(geo, particleMat);
    // Add to group so Points can be individually targeted. C47: when bougie.glb loads,
    // LairGLBAssets hides only Mesh children (bodies+wicks) via `instanceof Mesh` filter —
    // Points flame particles are intentionally preserved alongside GLB candle geometry.
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
  if (candles.length === 0) return;
  const maxLife = 1.2;
  // C80: flicker hoisted — all 3 candles share sharedLight (same object ref); only the last
  // iteration's write survived anyway (overwritten twice). Was 9 Math.sin/frame (3×3),
  // 6 dead. Now 3/frame using candles[0].phase as representative.
  const ph = candles[0]!.phase;
  const flicker =
    Math.sin(t * 7.3 + ph) * 0.25 +
    Math.sin(t * 13.1 + ph * 2.1) * 0.1 +
    Math.sin(t * 3.7 + ph * 0.5) * 0.08;
  candles[0]!.light.intensity = 1.8 + flicker;
  for (const candle of candles) {

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
  points: Points;
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

  const geo = new BufferGeometry();
  geo.setAttribute('position', new BufferAttribute(positions, 3));

  const mat = new PointsMaterial({
    color: 0xddccaa,
    size: 0.04,
    transparent: true,
    opacity: 0.35,
    blending: AdditiveBlending,
    depthWrite: false,
  });

  const points = new Points(geo, mat);

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

// ── C157: Magic Dust — green phosphor motes (brownian drift) ─────────────────

interface MagicDustSystem {
  points: Points;
  update: (dt: number) => void;
}

function createMagicDust(): MagicDustSystem {
  const N = 30;
  const positions = new Float32Array(N * 3);
  const velocities = new Float32Array(N * 3);

  for (let i = 0; i < N; i++) {
    positions[i * 3 + 0] = (Math.random() - 0.5) * 22;
    positions[i * 3 + 1] = 0.5 + Math.random() * 7.5;
    positions[i * 3 + 2] = (Math.random() - 0.5) * 18;
    velocities[i * 3 + 0] = (Math.random() - 0.5) * 0.015;
    velocities[i * 3 + 1] = (Math.random() - 0.5) * 0.007;
    velocities[i * 3 + 2] = (Math.random() - 0.5) * 0.012;
  }

  const geo = new BufferGeometry();
  geo.setAttribute('position', new BufferAttribute(positions, 3));

  const mat = new PointsMaterial({
    color: 0x33ff66,
    size: 0.04,
    transparent: true,
    opacity: 0.35,
    blending: AdditiveBlending,
    depthWrite: false,
  });

  const points = new Points(geo, mat);

  const update = (dt: number): void => {
    const speed = dt * 60;
    for (let i = 0; i < N; i++) {
      // Brownian: add small random kick each frame
      velocities[i * 3 + 0]! += (Math.random() - 0.5) * 0.0008;
      velocities[i * 3 + 1]! += (Math.random() - 0.5) * 0.0004;
      velocities[i * 3 + 2]! += (Math.random() - 0.5) * 0.0006;
      // Dampen to prevent drift explosion
      velocities[i * 3 + 0]! *= 0.98;
      velocities[i * 3 + 1]! *= 0.98;
      velocities[i * 3 + 2]! *= 0.98;

      positions[i * 3 + 0]! += (velocities[i * 3 + 0] ?? 0) * speed;
      positions[i * 3 + 1]! += (velocities[i * 3 + 1] ?? 0) * speed;
      positions[i * 3 + 2]! += (velocities[i * 3 + 2] ?? 0) * speed;

      // Bounce on room bounds (±11, 0.5-8, ±9)
      if ((positions[i * 3 + 0] ?? 0) > 11)  { positions[i * 3 + 0] = 11;  velocities[i * 3 + 0]! *= -1; }
      if ((positions[i * 3 + 0] ?? 0) < -11) { positions[i * 3 + 0] = -11; velocities[i * 3 + 0]! *= -1; }
      if ((positions[i * 3 + 1] ?? 0) > 8)   { positions[i * 3 + 1] = 8;   velocities[i * 3 + 1]! *= -1; }
      if ((positions[i * 3 + 1] ?? 0) < 0.5) { positions[i * 3 + 1] = 0.5; velocities[i * 3 + 1]! *= -1; }
      if ((positions[i * 3 + 2] ?? 0) > 9)   { positions[i * 3 + 2] = 9;   velocities[i * 3 + 2]! *= -1; }
      if ((positions[i * 3 + 2] ?? 0) < -9)  { positions[i * 3 + 2] = -9;  velocities[i * 3 + 2]! *= -1; }
    }
    geo.attributes['position']!.needsUpdate = true;
  };

  return { points, update };
}

// ── Cauldron with Green Steam ─────────────────────────────────────────────────

interface CauldronSystem {
  group: Group;
  body: Mesh;
  glow: PointLight;
  positions: Float32Array;
  velocities: Float32Array;
  lifetimes: Float32Array;
  geoGreen: BufferGeometry;
  geoTeal: BufferGeometry;
  update: (t: number, dt: number) => void;
}

function createCauldron(scene: Scene): CauldronSystem {
  const ironMat = new MeshStandardMaterial({ color: 0x1a1a1a, roughness: 0.5, metalness: 0.6, flatShading: true, emissive: 0x00aa33, emissiveIntensity: 0.0 });

  const group = new Group();

  // Cauldron body
  // C153/CAULDRON-Y-01: align procedural body Y to GLB position (-4.65) — was -3.8.
  // LairGLBAssets.ts sets gltf.scene.position.set(2, -4.65, -7) so the GLB loads 0.85u
  // below the procedural mesh, causing a visible downward pop when the GLB fades in.
  const body = new Mesh(new SphereGeometry(0.65, 10, 8), ironMat);
  body.scale.y = 0.8;
  body.position.set(2, -4.65, -7);
  group.add(body);
  // C129/BUG-L-DOUBLE-ADD-01: removed scene.add(group) from here — every other factory returns group and
  // lets the caller add. Internal scene.add() was the architectural root of BUG-L-07 class (easy to lose
  // track of where items belong when both scene and group are valid parent targets inside one function).

  // Legs
  const legDef: Array<[number, number]> = [[-0.4, -0.3], [0.4, -0.3], [0, 0.5]];
  for (const [lx, lz] of legDef) {
    const leg = new Mesh(new CylinderGeometry(0.06, 0.05, 0.5, 5), ironMat);
    leg.position.set(2 + lx, -4.4, -7 + lz);
    group.add(leg);
  }

  // C157: green phosphor glow — 0x00ff44, distance 8, range 0.6-1.4 (2Hz sine)
  const glow = new PointLight(0x00ff44, 1.0, 8, 2);
  glow.position.set(2, -3.2, -7);
  group.add(glow);

  // C177: cauldron smoke — 50 particles (was 30), rising smoke with upward drift.
  // Color split: indices 0-29 = green 0x33ff66, indices 30-49 = blue-teal 0x22aaff.
  // Two separate BufferGeometries (one per color band) sharing contiguous regions of
  // the same positions Float32Array — avoids per-vertex color attributes, lower GPU overhead.
  const N = 50;
  const N_GREEN = 30;
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

  // Green band: particles 0–29 (view into same buffer, no copy)
  const posGreen = new Float32Array(positions.buffer, 0, N_GREEN * 3);
  const geoGreen = new BufferGeometry();
  geoGreen.setAttribute('position', new BufferAttribute(posGreen, 3));
  const steamMatGreen = new PointsMaterial({
    color: 0x33ff66,
    size: 0.06,
    transparent: true,
    opacity: 0.55,
    blending: AdditiveBlending,
    depthWrite: false,
  });
  group.add(new Points(geoGreen, steamMatGreen));

  // Teal band: particles 30–49 (view offset by N_GREEN * 3 floats * 4 bytes/float)
  const posTeal = new Float32Array(positions.buffer, N_GREEN * 3 * 4, (N - N_GREEN) * 3);
  const geoTeal = new BufferGeometry();
  geoTeal.setAttribute('position', new BufferAttribute(posTeal, 3));
  const steamMatTeal = new PointsMaterial({
    color: 0x22aaff,
    size: 0.06,
    transparent: true,
    opacity: 0.55,
    blending: AdditiveBlending,
    depthWrite: false,
  });
  group.add(new Points(geoTeal, steamMatTeal));

  const update = (t: number, dt: number): void => {
    // C157: intensity oscillates 0.6-1.4 at 2Hz (= 2*PI*2 rad/s ≈ 12.57)
    glow.intensity = 1.0 + Math.sin(t * (Math.PI * 4)) * 0.4;
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
        // C177: rising smoke — upward drift acceleration
        velocities[p * 3 + 1]! += 0.8 * dt;
        positions[p * 3 + 1]! += (velocities[p * 3 + 1] ?? 0) * dt;
        positions[p * 3 + 2]! += (velocities[p * 3 + 2] ?? 0) * dt;
      }
    }
    geoGreen.attributes['position']!.needsUpdate = true;
    geoTeal.attributes['position']!.needsUpdate = true;
  };

  return { group, body, glow, positions, velocities, lifetimes, geoGreen, geoTeal, update };
}

// ── Potion Bottles ────────────────────────────────────────────────────────────

function createPotionBottles(): Group {
  const group = new Group();
  const shelfMat = new MeshStandardMaterial({ color: 0x3d2b1a, roughness: 0.85, metalness: 0.0, flatShading: true });

  const smallShelf = new Mesh(new BoxGeometry(2.5, 0.1, 0.5), shelfMat);
  smallShelf.position.set(6, -3.5, -7.7);
  group.add(smallShelf);

  const bottleData: Array<{ color: number; x: number; y: number; z: number }> = [
    { color: 0xcc2222, x: 5.4, y: -3.2, z: -7.5 },
    { color: 0x2244cc, x: 6.1, y: -3.3, z: -7.8 },
    { color: 0x22aa44, x: 6.8, y: -3.35, z: -7.6 },
  ];

  for (const b of bottleData) {
    const mat = new MeshStandardMaterial({
      color: b.color,
      roughness: 0.1,
      metalness: 0.0,
      transparent: true,
      opacity: 0.78,
      emissive: b.color,
      emissiveIntensity: 0.08, // C129/POTION-EMISSIVE-01: reduce from 0.25 — was too bright vs ambient lair lighting
      flatShading: true,
    });
    const bottle = new Mesh(new CylinderGeometry(0.12, 0.15, 0.55, 8), mat);
    bottle.position.set(b.x, b.y, b.z);
    group.add(bottle);
    const neck = new Mesh(new CylinderGeometry(0.06, 0.1, 0.18, 6), mat);
    neck.position.set(b.x, b.y + 0.35, b.z);
    group.add(neck);
  }

  return group;
}

// ── Skull ─────────────────────────────────────────────────────────────────────

function createSkull(): { group: Group; cranium: Mesh; baseY: number } {
  // C172: upgraded to full low-poly procédural skull (cranium + jaw + eye sockets)
  // All geometry uses flatShading:true for consistent N64/low-poly aesthetic
  const BASE_X = 9, BASE_Y = -1.9, BASE_Z = -9;
  const group = new Group();
  group.position.set(BASE_X, BASE_Y, BASE_Z);

  // C79: emissive=0xd4c89a at intensity=0.0 — allows applyHoverTo() to boost on hover (was no-op: emissive 0,0,0 → guard failed)
  const boneMat = new MeshStandardMaterial({ color: 0xd4c89a, roughness: 0.7, metalness: 0.15, flatShading: true, emissive: 0xd4c89a, emissiveIntensity: 0.0 });

  // 1. Cranium — low-poly geode (6×4 segments, flat-shaded facets)
  const cranium = new Mesh(new SphereGeometry(0.35, 6, 4), boneMat);
  cranium.scale.set(1.0, 0.85, 0.9);
  // position relative to group origin (0,0,0)
  group.add(cranium);

  // 2. Jaw — box slightly below and forward of cranium
  const jaw = new Mesh(new BoxGeometry(0.42, 0.18, 0.32, 2, 1, 2), boneMat);
  jaw.position.set(0, -0.22, 0.05);
  group.add(jaw);

  // 3. Eye sockets — dark hollow spheres (left, right)
  const eyeMat = new MeshStandardMaterial({ color: 0x0a0808, roughness: 1.0, flatShading: true });
  const leftEye = new Mesh(new SphereGeometry(0.08, 4, 3), eyeMat);
  leftEye.position.set(-0.12, 0.08, 0.28);
  group.add(leftEye);
  const rightEye = new Mesh(new SphereGeometry(0.08, 4, 3), eyeMat);
  rightEye.position.set(0.12, 0.08, 0.28);
  group.add(rightEye);

  return { group, cranium, baseY: BASE_Y };
}

// ── Ambient Lighting — 6-source pass (degraded to 5 on low-end mobile) ── // C52: corrected count (was '5/4', actual 6/5)
// C89-P2: lowEnd=true skips backAccent PointLight (Mali-G57/Adreno 610 budget ~4 lights at 60fps)
function setupLighting(scene: Scene, lowEnd = false): void {
  scene.add(new AmbientLight(0x1a1008, 0.3));                          // dark warm base (reduced to balance HemiLight below)
  // C33: HemisphereLight fills stone surfaces — reports flagged every cycle that flatShading relied
  // solely on 5 PointLights with no ambient fill. Sky=blue-grey dungeon vault, ground=warm stone bounce.
  // intensity=0.25: subtle — doesn't wash out dramatic PointLight shadows, just reveals stone facets.
  scene.add(new HemisphereLight(0x2a3820, 0x3a2a1a, 0.25));           // C36: deep forest green-black sky (was 0x7080a0 steel-blue — fought warm candle/moonbeam palette)
  // C85-02: key moved from overhead [0,8,-2] to forward-angled [0,3,2] — creates
  // depth shadows toward back wall, correct Celtic hall dramaturgy
  const key = new PointLight(0xff6618, 0.9, 22, 1.6);
  key.position.set(0, 3.0, 2); scene.add(key);                              // forward warm fire
  const rim = new PointLight(0x6699cc, 0.55, 18, 2.0);
  rim.position.set(8, 2, 7); scene.add(rim);                                 // cool rim from door
  // C89-P2: fill intensity boosted +0.15 on low-end to compensate for missing backAccent depth
  const fill = new PointLight(0x225533, lowEnd ? 0.55 : 0.4, 16, 2.0);
  fill.position.set(-9, 0, -5); scene.add(fill);                             // warm fill left wall
  if (!lowEnd) {
    // C85-02: back-wall accent — warm ember glow throwing forward shadows from rear (skipped on low-end)
    const backAccent = new PointLight(0xff5500, 0.35, 12, 2.0);
    backAccent.position.set(0, 1.5, -11); scene.add(backAccent);
  }
}

// ── Main Export ──────────────────────────────────────────────────────────────
export function initMerlinLair(container: HTMLElement): LairResult {
  const renderer = new WebGLRenderer({ antialias: true, alpha: false });
  renderer.setSize(container.clientWidth, container.clientHeight);
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.setClearColor(0x0d0a08, 1);
  container.appendChild(renderer.domElement);
  // C85-01: ARIA accessibility — canvas is interactive region
  renderer.domElement.setAttribute('role', 'application');
  renderer.domElement.setAttribute('aria-label', 'Antre de Merlin — chargement des zones...');  // C38: updated to dynamic count after interactives[] built
  renderer.domElement.setAttribute('tabindex', '0');
  renderer.domElement.style.touchAction = 'none'; // prevent mobile scroll interference
  // C102: auto-focus canvas so C85-01 keyboard nav works without requiring a prior click
  // { preventScroll: true } avoids iOS/desktop layout jump on initial mount
  renderer.domElement.focus({ preventScroll: true });
  // C88: aria-live region — screen readers announce zone focus/activation (WCAG 2.1 AA)
  const ariaLive = document.createElement('div');
  ariaLive.id = 'lair-aria-live'; // C126: stable ID for aria-describedby linkage (WCAG 2.1 SC 1.3.1)
  ariaLive.setAttribute('role', 'status'); // C137/BUG-C135-01: WCAG 2.1 AA — role=status required on aria-live region
  ariaLive.setAttribute('aria-live', 'polite');
  ariaLive.setAttribute('aria-atomic', 'true');
  ariaLive.style.cssText = 'position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0,0,0,0);white-space:nowrap;';
  container.style.position = container.style.position || 'relative';
  container.appendChild(ariaLive);
  // C126: link canvas to ariaLive region so AT knows where to read descriptions from
  renderer.domElement.setAttribute('aria-describedby', 'lair-aria-live');

  // C101: zone hover lore toast — visual-only (sighted users). Screen reader announcements go through
  // ariaLive div (line 692) to avoid double-announcement when keyboard nav updates both regions. (C132)
  const zoneToast = document.createElement('div');
  zoneToast.setAttribute('role', 'presentation'); // C132: visual only — ariaLive handles AT output
  zoneToast.setAttribute('aria-live', 'off');      // C132: suppress; ariaLive announces mouse hover too
  zoneToast.setAttribute('aria-atomic', 'true');
  zoneToast.style.cssText = [
    `position:absolute;bottom:16px;left:50%;transform:translateX(-50%);`,
    `background:rgba(1,6,2,0.90);border:1px solid rgba(51,255,102,0.25);`,
    `border-left:2px solid #1a8833;padding:8px 18px;`,
    `font-family:'Courier New',monospace;text-align:left;`,
    `pointer-events:none;opacity:0;transition:opacity 0.2s ease;`,
    `display:flex;flex-direction:column;gap:2px;line-height:1.4;min-width:180px;`,
  ].join('');
  container.appendChild(zoneToast);

  // C157: floating zone label — top-center CRT-style label on hover
  const zoneFloatLabel = document.createElement('div');
  zoneFloatLabel.setAttribute('role', 'presentation');
  zoneFloatLabel.setAttribute('aria-live', 'off');
  zoneFloatLabel.style.cssText = [
    'position:absolute;top:20%;left:50%;transform:translateX(-50%);',
    'color:#33ff66;font:12px Courier New,monospace;',
    'letter-spacing:0.2em;text-transform:uppercase;',
    'pointer-events:none;opacity:0;transition:opacity 0.15s ease;',
    'text-shadow:0 0 8px rgba(51,255,102,0.6);',
  ].join('');
  container.appendChild(zoneFloatLabel);

  // C157: door "début de l'aventure" cinematic overlay
  const doorCinematicOverlay = document.createElement('div');
  doorCinematicOverlay.style.cssText = [
    'position:absolute;inset:0;',
    'display:flex;align-items:center;justify-content:center;',
    'background:rgba(0,0,0,0);pointer-events:none;z-index:20;',
    'transition:background 0.8s ease;',
  ].join('');
  const doorCinematicText = document.createElement('div');
  doorCinematicText.style.cssText = [
    'color:#33ff66;font:12px Courier New,monospace;',
    'letter-spacing:0.3em;text-transform:uppercase;opacity:0;',
    'transition:font-size 0.8s ease,opacity 0.2s ease;',
  ].join('');
  doorCinematicText.textContent = '[ DEBUT DE L\'AVENTURE ]';
  doorCinematicOverlay.appendChild(doorCinematicText);
  container.appendChild(doorCinematicOverlay);

  // C201: ambient Merlin whisper panel — lore quotes near cauldron, 8s rotation cycle
  const WHISPERS: readonly string[] = [
    "Les Oghams ne mentent jamais… ils choisissent simplement ce qu'ils révèlent.",
    "Chaque biome porte la mémoire d'un druide disparu.",
    "L'Anam grandit dans le silence entre les cartes.",
    "Brocéliande n'est pas un lieu. C'est un état d'esprit.",
    "Les Korrigans gardent ce que les hommes ont oublié de chercher.",
    "Une réputation se construit en un run, se détruit en une carte.",
    "Le Beith protège. Le Huath révèle. Le Ruis transforme.",
    "Ce qui semble échec est parfois l'amorce d'une maîtrise.",
    "Les pierres dressées comptent les étoiles depuis avant les hommes.",
    "Groq murmure, Merlin écoute, le joueur décide.",
    "Toute run est unique. Nulle route ne se répète dans la forêt.",
    "Le cauldron ne ment pas — il révèle ce que tu refuses de voir.",
  ];
  // Inject style once per page — idempotent guard
  if (!document.getElementById('lair-whisper-style')) {
    const whisperStyle = document.createElement('style');
    whisperStyle.id = 'lair-whisper-style';
    whisperStyle.textContent = `
      #lair-whisper {
        position: absolute;
        bottom: 22%;
        left: 50%;
        transform: translateX(-50%);
        font: italic 0.78rem 'Courier New', monospace;
        color: rgba(51,255,102,0.75);
        text-align: center;
        max-width: 420px;
        pointer-events: none;
        opacity: 0;
        transition: opacity 1.2s ease;
        letter-spacing: 0.03em;
        text-shadow: 0 0 8px rgba(51,255,102,0.4);
        z-index: 5;
      }
    `;
    document.head.appendChild(whisperStyle);
  }
  const whisperEl = (() => {
    const existing = document.getElementById('lair-whisper');
    if (existing) return existing as HTMLDivElement;
    const el = document.createElement('div');
    el.id = 'lair-whisper';
    container.appendChild(el);
    return el;
  })();

  // C220: bookshelf lore excerpt panel — rotating fragments from Merlin's library
  const BOOK_EXCERPTS: Array<{ title: string; text: string }> = [
    { title: 'Codex Oghamicus',       text: 'Le Beith protège les seuils. Ne franchis jamais une porte sans invoquer son nom.' },
    { title: 'Traité des Factions',   text: 'Les Korrigans n\'ont pas de mémoire. Ils ont des habitudes. Ce n\'est pas la même chose.' },
    { title: 'Chronique de Brocéliande', text: 'La forêt n\'oublie jamais un visage. Elle se souvient des vivants et des morts.' },
    { title: 'Mémoires d\'Ankou',     text: 'La mort n\'est pas une fin. C\'est une carte que chaque voyageur tire tôt ou tard.' },
    { title: 'Annales Druidiques',    text: 'L\'Anam se transmet d\'une run à l\'autre comme une flamme de bougie en bougie.' },
    { title: 'Journal de Niamh',      text: 'Guérir n\'est pas effacer. C\'est apprendre à porter la blessure autrement.' },
    { title: 'Grimoire des Anciens',  text: 'Chaque Ogham a un prix. Huath te révèle ce que tu préfères ignorer.' },
    { title: 'Carte des Biomes',      text: 'Les Landes gardent le souvenir de ceux qui ont voulu les traverser trop vite.' },
    { title: 'Rituel du Cercle',      text: 'Pour activer un cercle de pierres, il faut d\'abord se souvenir de son propre nom.' },
    { title: 'Secrets du Marais',     text: 'Les feux follets du marais sont les âmes des joueurs qui ont choisi trop vite.' },
  ];
  let bookExcerptIndex = 0;
  const bookExcerptEl = (() => {
    const existing = document.getElementById('lair-book-excerpt');
    if (existing) return existing as HTMLDivElement;
    const panel = document.createElement('div');
    panel.id = 'lair-book-excerpt';
    panel.style.cssText = [
      'position:absolute',
      'bottom:55%',
      'left:62%',
      'width:260px',
      'background:rgba(1,8,2,0.92)',
      'border:1px solid rgba(51,255,102,0.3)',
      'padding:12px',
      'font-family:\'Courier New\',monospace',
      'pointer-events:none',
      'opacity:0',
      'transition:opacity 0.4s ease',
      'z-index:6',
    ].join(';');
    const titleEl = document.createElement('div');
    titleEl.className = 'book-title';
    titleEl.style.cssText = [
      'font-size:0.65rem',
      'color:rgba(51,255,102,0.5)',
      'letter-spacing:0.1em',
      'text-transform:uppercase',
      'margin-bottom:6px',
    ].join(';');
    const textEl = document.createElement('div');
    textEl.className = 'book-text';
    textEl.style.cssText = [
      'font-size:0.72rem',
      'color:rgba(51,255,102,0.8)',
      'font-style:italic',
      'line-height:1.5',
    ].join(';');
    panel.appendChild(titleEl);
    panel.appendChild(textEl);
    container.appendChild(panel);
    return panel;
  })();

  // C227: crystal sphere fortune panel — rotating mystical prophecies on hover
  const CRYSTAL_FORTUNES: string[] = [
    'La prochaine carte changera le cours de votre run.',
    'Méfiez-vous du Korrigan qui sourit sans raison.',
    "L'Ogham Ruis est proche. Sa transformation est inévitable.",
    'Trois cartes vous séparent d\'une décision cruciale.',
    'Les Druides ont noté vos choix. Leur mémoire est longue.',
    'La mort n\'est pas la fin ici — c\'est un passage entre les runs.',
    'Votre Anam grandit dans l\'ombre. Il sera prêt bientôt.',
    'Le biome suivant révélera ce que ce biome a caché.',
    'Huath vous attend au prochain carrefour.',
    'La forêt se souvient de votre premier choix.',
    "Niamh murmure : 'Guérir maintenant ou mourir plus tard.'",
    'Un cercle se ferme. Une porte s\'ouvre.',
  ];
  let crystalFortuneIndex = 0;
  const crystalFortuneEl = (() => {
    const existing = document.getElementById('crystal-fortune');
    if (existing) return existing as HTMLDivElement;
    const el = document.createElement('div');
    el.id = 'crystal-fortune';
    el.style.cssText = [
      'position:absolute',
      'top:25%',
      'left:52%',
      'width:200px',
      'font:italic 0.7rem \'Courier New\',monospace',
      'color:rgba(136,255,204,0.85)',
      'text-align:center',
      'pointer-events:none',
      'opacity:0',
      'transition:opacity 0.5s',
      'text-shadow:0 0 10px rgba(51,255,102,0.5)',
      'z-index:6',
    ].join(';');
    container.appendChild(el);
    return el;
  })();

  // C157: zone label map (bracket notation per spec)
  const ZONE_FLOAT_LABELS: Readonly<Record<string, string>> = {
    map:       '[ MAP DES BIOMES ]',
    crystal:   '[ SPHERE DE CRISTAL ]',
    bookshelf: '[ BIBLIOTHEQUE ]',
    door:      "[ PORTE DE L'AVENTURE ]",
    cauldron:  '[ CHAUDRON DE MERLIN ]',
    skull:     '[ CRANE DU SAGE ]',
  };

  // Scene + Camera
  const scene = new Scene();
  scene.fog = new Fog(0x0d0a08, 12, 28);

  const camera = new PerspectiveCamera(62, container.clientWidth / container.clientHeight, 0.1, 60);
  camera.position.set(0, 0.5, 10); // C127: start pulled back — entry cinematic eases to z=7
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
  // C177: teal PointLight near crystal sphere — breathes in sync with emissive pulse (0x22ffaa, 0.6, 8)
  const crystalTealLight = new PointLight(0x22ffaa, 0.6, 8);
  crystalTealLight.position.set(5, -1.0, -4);
  scene.add(crystalTealLight);

  const { group: shelfGroup, hitTarget: shelfHit, frame: shelfFrame } = createBookshelf();
  scene.add(shelfGroup);

  const { group: doorGroup, hitTarget: doorHit, lightBeam: doorLight, doorPanel } = createDoor();
  scene.add(doorGroup);
  // C188: green rune inscription glow — fades in/out on door hover (lerped in update)
  const doorRuneLight = new PointLight(0x33ff66, 0.0, 8);
  doorRuneLight.position.set(-9.8, 0.5, 5.5);
  scene.add(doorRuneLight);

  const { candles, group: candleGroup } = createCandles();
  scene.add(candleGroup); // C131/CANDLES-FACTORY-01: moved from inside createCandles() — consistent with all other factories
  const dust = createDustMotes();
  scene.add(dust.points);

  // C157: green phosphor magic dust — brownian drift, complement existing wisps
  const magicDust = createMagicDust();
  scene.add(magicDust.points);

  const cauldron = createCauldron(scene);
  scene.add(cauldron.group); // C129/BUG-L-DOUBLE-ADD-01: moved from inside createCauldron() — consistent with all other factories
  scene.add(createPotionBottles());
  const { group: skullGroup, cranium: skullCranium, baseY: skullBaseY } = createSkull(); scene.add(skullGroup);
  const cleanupLairDensity = createLairDensity(scene, isLowEndMobile); // C35: cleanup for moon.target; C38: lowEnd gate for biblio PointLight

  // Cauldron interactive hit target — C153/CAULDRON-Y-01: aligned to GLB y=-4.65.
  // Previous: y=-3.8 matched the old procedural body. Now both body and GLB are at -4.65
  // so the hit target is correct for the entire lair lifecycle (before and after GLB loads).
  const cauldronHit = new Mesh(
    new SphereGeometry(0.9, 8, 6),
    new MeshBasicMaterial({ visible: false })
  );
  cauldronHit.position.set(2, -4.65, -7);
  scene.add(cauldronHit);

  // C231: cauldron bubble particle system — 12 rising green spheres
  let _bubbleMeshes: Mesh[] = [];
  let _bubbleTimer = 0;

  // C241: floor rune circles — dual counter-rotating torus rings on lair floor
  let _runeRing1: Mesh | null = null;
  let _runeRing2: Mesh | null = null;
  let _runeRingTime = 0;

  // C264: glowing potion vials on left-wall shelf
  let _vialMeshes: Mesh[] = [];
  let _vialLights: PointLight[] = [];
  let _vialTime = 0;

  // C269: spell tome on map table — auto-open/close cycle (8s period)
  let _tomePivotGroup: Group | null = null;
  let _tomeCoverMesh: Mesh | null = null;
  let _tomePagesMesh: Mesh | null = null;
  let _tomeTime = 0;
  let _tomeOpenAngle = 0; // 0 = closed, PI*0.6 = fully open

  // C231: create 12 bubble meshes rising from the cauldron (body at 2, -4.65, -7)
  {
    const CAULDRON_X = 2;
    const CAULDRON_Y = -4.65;
    const CAULDRON_Z = -7;
    const bubbleMat = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.6 });
    const bubbleGeo = new SphereGeometry(0.05, 4, 3);
    for (let bi = 0; bi < 12; bi++) {
      const bm = new Mesh(bubbleGeo, bubbleMat.clone());
      const bx = CAULDRON_X + (Math.random() - 0.5) * 0.6;
      const bz = CAULDRON_Z + (Math.random() - 0.5) * 0.6;
      bm.position.set(bx, CAULDRON_Y + 0.4 + Math.random() * 0.4, bz);
      bm.userData = {
        baseX: bx,
        baseZ: bz,
        speed: 0.3 + Math.random() * 0.4,
        phase: Math.random() * Math.PI * 2,
        active: false,
        cauldronY: CAULDRON_Y,
      };
      (bm.material as MeshBasicMaterial).opacity = 0;
      scene.add(bm);
      _bubbleMeshes.push(bm);
    }
  }

  // C241: create dual concentric rune rings on lair floor (floor top surface at y = -5 + 0.15 = -4.85)
  {
    const FLOOR_Y = -4.85;
    const RING_Z = -8;
    const outerGeo = new TorusGeometry(3.5, 0.06, 6, 48);
    const outerMat = new MeshBasicMaterial({ color: 0x22aa55, transparent: true, opacity: 0.35 });
    _runeRing1 = new Mesh(outerGeo, outerMat);
    _runeRing1.rotation.x = -Math.PI / 2;
    _runeRing1.position.set(0, FLOOR_Y + 0.02, RING_Z);
    scene.add(_runeRing1);

    const innerGeo = new TorusGeometry(2.0, 0.04, 6, 32);
    const innerMat = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.5 });
    _runeRing2 = new Mesh(innerGeo, innerMat);
    _runeRing2.rotation.x = -Math.PI / 2;
    _runeRing2.position.set(0, FLOOR_Y + 0.02, RING_Z);
    scene.add(_runeRing2);
  }

  // C264: create 3 glowing potion vials on left-wall shelf (z=-8.5, shelfY=-3.5 → bottle base at shelfY+0.25=-3.25)
  {
    const SHELF_Y = -3.5;
    const VIAL_Y = SHELF_Y + 0.25;
    const vialDefs: Array<{ x: number; color: number; intensity: number }> = [
      { x: -2.5, color: 0x22ff44, intensity: 0.3 },
      { x: -2.0, color: 0x44ff88, intensity: 0.25 },
      { x: -1.5, color: 0x00cc44, intensity: 0.2 },
    ];
    const bodyGeo = new CylinderGeometry(0.12, 0.15, 0.5, 8);
    const stopperGeo = new SphereGeometry(0.13, 6, 4);
    for (const vd of vialDefs) {
      const mat = new MeshBasicMaterial({ color: vd.color });
      const body = new Mesh(bodyGeo, mat);
      body.position.set(vd.x, VIAL_Y, -8.5);
      scene.add(body);
      const stopper = new Mesh(stopperGeo, mat);
      stopper.position.set(vd.x, VIAL_Y + 0.25, -8.5);
      scene.add(stopper);
      _vialMeshes.push(body, stopper);
      const light = new PointLight(vd.color, vd.intensity, 1.5);
      light.position.set(vd.x, VIAL_Y, -8.5);
      scene.add(light);
      _vialLights.push(light);
    }
  }

  // C269: spell tome — sits on map table, cover rotates open/closed on 8s cycle.
  // Table top surface at y = -2 + 0.09 = -1.91; scroll at -1.88. Tome sits at -1.75 (slightly elevated).
  // Pivot group positions cover hinge at spine edge (x + 0.275) so rotation.z opens like a book.
  {
    const TOME_X = -5;
    const TOME_Y = -1.75;
    const TOME_Z = -5;
    const pagesMat = new MeshBasicMaterial({ color: 0x1a1c14 });
    const coverMat = new MeshBasicMaterial({ color: 0x0a1208 });
    // Pages (book body) — slightly narrower than cover
    const pages = new Mesh(new BoxGeometry(0.55, 0.06, 0.75), pagesMat);
    pages.position.set(TOME_X, TOME_Y, TOME_Z);
    scene.add(pages);
    _tomePagesMesh = pages;
    // Cover pivot group — origin at the spine (left edge x - 0.275)
    const pivotGroup = new Group();
    pivotGroup.position.set(TOME_X - 0.275, TOME_Y + 0.04, TOME_Z);
    // Cover mesh positioned to the right of the pivot (center offset +0.275)
    const cover = new Mesh(new BoxGeometry(0.55, 0.02, 0.75), coverMat);
    cover.position.set(0.275, 0, 0);
    pivotGroup.add(cover);
    scene.add(pivotGroup);
    _tomeCoverMesh = cover;
    _tomePivotGroup = pivotGroup;
  }

  // Forest window + day/night/season cycle
  const lairWindow = createLairWindow(scene);

  // GLB asset overlays (async — procedural fallbacks remain if GLB unavailable).
  // Pass procedural groups so table_druidique.glb + bibliotheque.glb hide them on load (fixes z-fighting).
  // C81-03: disposed flag prevents late-resolving GLBs from adding to a torn-down scene.
  let lairDisposed = false;
  let crystalGLBGroup: Group | null = null; // C101: stored to sync float animation to GLB
  let crystalGLBBaseY = -1.0; // C118: base Y from GLB export root; overwritten by onCrystalGroupLoaded
  // C111: stored to animate GLB emissive in update loop (procedural mat targets hidden sphere post-load)
  let crystalGLBMat: MeshStandardMaterial | null = null;
  // C174: cauldron GLB material for emissive pulsing (same pattern as crystalGLBMat)
  let cauldronGLBMat: MeshStandardMaterial | null = null;
  // C174: periodic cauldron bubble SFX — fires every ~4s when !lowFpsMode
  let bubbleSFXTimer = 0;
  const BUBBLE_SFX_INTERVAL = 4.2;
  let doorFlashing = false;    // C101: door cinematic — lights/emissive burst before transition
  let doorFlashTimer = 0;
  let doorFlashCancelHandle = 0; // C102: tracked to allow clearTimeout in dispose()
  // C102: FPS monitoring — adaptive quality drops dust when < 45fps sustained
  let fpsFrameCount = 0;
  let fpsElapsed = 0;
  let lowFpsMode = false;
  // C201: whisper rotation state (-1 = waiting for first whisper after WHISPER_START_MS)
  let whisperIndex = -1;
  let whisperTimer = 0;          // ms accumulator
  let whisperFading = false;     // true while fading-out before text swap
  let whisperFadeTimer = 0;      // ms — counts 1200ms fade-out window
  const WHISPER_CYCLE_MS = 8000; // 8s between whispers
  const WHISPER_FADE_MS  = 1200; // 1.2s CSS transition
  const WHISPER_START_MS = 3000; // 3s initial delay
  const cancelGLBFades = loadLairGLBs(scene, { // C133: capture cancel-all to stop in-flight fadeInGLB rAFs on dispose
    mapGroup, shelfGroup, floorMesh, wallsGroup,
    cauldronGroup: cauldron.group, candleGroup,
    crystalSphere: crystalData.sphere,
    // When GLB loads, swap visualMesh to the GLB body so hover emissive works on GLB path
    // C174: also capture GLB material for emissive pulsing in update loop
    onCauldronGLBLoaded: (mesh) => {
      const entry = interactives.find((i) => i.zone === 'cauldron');
      if (entry) entry.visualMesh = mesh;
      cauldronGLBMat = mesh.material as MeshStandardMaterial;
    },
    // C95: swap crystal visualMesh to GLB mesh so hover emissive targets GLB (not hidden sphere)
    // C111: also capture GLB material so update loop can animate its emissiveIntensity (BUG-C46-01)
    onCrystalGLBLoaded: (mesh) => {
      const entry = interactives.find((i) => i.zone === 'crystal');
      if (entry) entry.visualMesh = mesh;
      crystalGLBMat = mesh.material as MeshStandardMaterial;
    },
    // C101: store GLB group so update loop can animate its Y position (float effect)
    // C118: also capture base Y so float animation is a delta (not hardcoded -1.0)
    onCrystalGroupLoaded: (group) => { crystalGLBGroup = group; crystalGLBBaseY = group.position.y; },
    // C121: when table_druidique.glb loads it hides mapGroup — mapHit (scroll) becomes invisible and
    // raycaster skips invisible meshes, making the map zone permanently unhoverable/unclickable.
    // Swap both mesh (hit target) and visualMesh to the first GLB mesh so raycasting stays live.
    onMapGLBLoaded: (mesh) => {
      const entry = interactives.find((i) => i.zone === 'map');
      if (entry) {
        entry.mesh = mesh;
        entry.visualMesh = mesh;
        // C131/GLB-EMISSIVE-01: table_druidique.glb gets applyFlatShading only — emissive stays
        // Color(0,0,0) by default. applyHoverTo() guards on emissive.r/g/b > 0; without this fix
        // the hover emissive boost silently no-ops for the map zone after GLB loads.
        // Restore same warm parchment emissive as procedural mapMat (0x3a2a10).
        if (mesh.material instanceof MeshStandardMaterial) {
          mesh.material.emissive.setHex(0x3a2a10);
          mesh.material.emissiveIntensity = entry.baseEmissive ?? 0.15;
        }
        raycastTargets = interactives.map((i) => i.mesh);
      }
    },
    // C122: same pattern for bookshelf — shelfHit inside shelfGroup, hidden when bibliotheque.glb loads.
    onShelfGLBLoaded: (mesh) => {
      const entry = interactives.find((i) => i.zone === 'bookshelf');
      if (entry) {
        entry.mesh = mesh;
        entry.visualMesh = mesh;
        // C131/GLB-EMISSIVE-01: bibliotheque.glb gets applyFlatShading only — same black emissive problem.
        // Restore same warm wood emissive as procedural shelfMat (0x2a1a08), intensity=0 to match
        // procedural baseline (applyHoverTo boosts to 0.65 on hover, restores to 0 on unhover).
        if (mesh.material instanceof MeshStandardMaterial) {
          mesh.material.emissive.setHex(0x2a1a08);
          mesh.material.emissiveIntensity = 0.0;
        }
        raycastTargets = interactives.map((i) => i.mesh);
      }
    },
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
    // C78: skull prop hover — shows Celtic lore toast (no click action, no keyboard nav)
    // C79: cranium as visualMesh so applyHoverTo() emissive boost works (Group.material was undefined → guard failed)
    { mesh: skullGroup,          zone: 'skull',     hovered: false, visualMesh: skullCranium, baseEmissive: 0.0 },
  ];

  // C38: update ARIA label now that zone count is known (was placeholder "chargement..." set before this array)
  // C79: use Tab-navigable count (excludes hover-only 'skull') so AT users aren't told 6 zones when Tab cycles 5
  const tabNavCount = interactives.filter(i => i.zone !== 'skull').length;
  renderer.domElement.setAttribute('aria-label', `Antre de Merlin — ${tabNavCount} zones interactives. Tab pour naviguer, Entrée pour activer.`);

  // C118: cache crystalEntry ref at init — avoids Array.find() closure allocation in 60fps update loop
  const crystalEntry = interactives.find((i) => i.zone === 'crystal')!;
  // C174: cache cauldronEntry + skullEntry for emissive animation (same pattern as crystalEntry)
  const cauldronEntry = interactives.find((i) => i.zone === 'cauldron')!;
  const skullEntry = interactives.find((i) => i.zone === 'skull')!;
  // C188: cache doorEntry for rune light lerp — avoids Array.find() on hot 60fps path
  const doorEntry = interactives.find((i) => i.zone === 'door')!;
  // C122: cache raycaster targets — interactives.map() on every mousemove allocates a 5-element array at 60fps.
  // Refreshed only in onMapGLBLoaded / onShelfGLBLoaded when entry.mesh changes.
  let raycastTargets: Object3D[] = interactives.map((i) => i.mesh);

  const raycaster = new Raycaster();
  const mouse = new Vector2();
  let zoneClickCallback: ((zone: LairZone) => void) | null = null;
  let elapsedTime = 0;
  // C127: entry pull-in cinematic — camera eases from z=10 to z=7 over 1.2s
  const ENTRY_CAM_DURATION = 1.2;
  let entryCamDone = false;
  let currentHovered: InteractiveObject | null = null;

  const getIntersected = (): InteractiveObject | null => {
    raycaster.setFromCamera(mouse, camera);
    const hits = raycaster.intersectObjects(raycastTargets, true);
    if (hits.length === 0) return null;
    const hitObj = hits[0]!.object;
    return interactives.find((i) => i.mesh === hitObj || i.mesh.getObjectById(hitObj.id) !== undefined) ?? null;
  };

  const applyHoverTo = (obj: InteractiveObject, intensity: number): void => {
    const target = obj.visualMesh ?? (obj.mesh as Mesh);
    // C119: instanceof guard replaces unsafe cast — MeshBasicMaterial has no emissive property;
    // GLB swaps (onCauldronGLBLoaded) may bring in non-Standard materials → silent no-op was correct
    // behaviour but the cast hid the contract. Now it's explicit.
    if (!(target.material instanceof MeshStandardMaterial)) return;
    // C46: Three.js Color is always truthy (object, never null) — guard must check actual channel values
    if (target.material.emissive.r > 0 || target.material.emissive.g > 0 || target.material.emissive.b > 0) target.material.emissiveIntensity = intensity;
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
        // C33: scale now lerped in update loop — no setScalar here
        applyHoverTo(currentHovered, currentHovered.baseEmissive ?? 0.15);
      }
      currentHovered = found;
      if (currentHovered) {
        currentHovered.hovered = true;
        // C33: scale lerped toward 1.05 in update loop — smooth Celtic ritual feel
        applyHoverTo(currentHovered, 0.65);
        renderer.domElement.style.cursor = 'pointer';
        // C82-01: subtle shimmer on zone enter — SFXManager listens via window 'merlin_sfx'
        window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'hover' } }));
        // C188: approach footstep — one per hover-enter for crystal/bookshelf/skull (illusion of stepping toward object)
        if (currentHovered.zone === 'crystal' || currentHovered.zone === 'bookshelf' || currentHovered.zone === 'skull') {
          window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'step' } }));
        }
        // C157: show floating top-center zone label
        zoneFloatLabel.textContent = ZONE_FLOAT_LABELS[currentHovered.zone] ?? '';
        zoneFloatLabel.style.opacity = '1';
        // C101: show lore toast with zone name + description
        const zone = currentHovered.zone;
        // C104: textContent — XSS-safe, forward-compatible if zone labels come from LLM
        zoneToast.textContent = '';
        const lbl = document.createElement('strong');
        lbl.style.cssText = `color:#33ff66;font-size:13px;font-family:'Courier New',monospace;letter-spacing:0.08em;`;
        lbl.textContent = ZONE_ARIA_LABELS[zone];
        const desc = document.createElement('span');
        desc.style.cssText = `color:rgba(51,255,102,0.55);font-size:11px;font-family:'Courier New',monospace;`;
        desc.textContent = ZONE_LORE[zone];
        zoneToast.appendChild(lbl);
        zoneToast.appendChild(desc);
        zoneToast.style.opacity = '1';
        // C131: WCAG 4.1.2 — sync aria-label on mouse hover (was only updated on keyboard nav)
        renderer.domElement.setAttribute('aria-label', `Zone : ${ZONE_ARIA_LABELS[zone]} — Cliquez pour activer`);
        // C132: announce via ariaLive (zoneToast now aria-live=off to prevent double-announce on keyboard nav)
        ariaLive.textContent = `${ZONE_ARIA_LABELS[zone]} — ${ZONE_LORE[zone]}`;
        // C220: bookshelf lore excerpt — rotate excerpt on each hover-enter
        if (zone === 'bookshelf') {
          const excerpt = BOOK_EXCERPTS[bookExcerptIndex % BOOK_EXCERPTS.length];
          bookExcerptIndex = (bookExcerptIndex + 1) % BOOK_EXCERPTS.length;
          const titleNode = bookExcerptEl.querySelector('.book-title') as HTMLDivElement;
          const textNode  = bookExcerptEl.querySelector('.book-text')  as HTMLDivElement;
          if (titleNode) titleNode.textContent = excerpt.title;
          if (textNode)  textNode.textContent  = excerpt.text;
          bookExcerptEl.style.opacity = '0.9';
        }
        // C227: crystal sphere fortune — rotate prophecy on each hover-enter
        if (zone === 'crystal') {
          crystalFortuneEl.textContent = CRYSTAL_FORTUNES[crystalFortuneIndex % CRYSTAL_FORTUNES.length];
          crystalFortuneIndex = (crystalFortuneIndex + 1) % CRYSTAL_FORTUNES.length;
          crystalFortuneEl.style.opacity = '1';
        }
      } else {
        renderer.domElement.style.cursor = 'default';
        zoneToast.style.opacity = '0';
        zoneFloatLabel.style.opacity = '0'; // C157: hide float label on unhover
        bookExcerptEl.style.opacity = '0'; // C220: hide book excerpt on leave
        crystalFortuneEl.style.opacity = '0'; // C227: hide crystal fortune on leave
        renderer.domElement.setAttribute('aria-label', `Antre de Merlin — ${tabNavCount} zones interactives. Tab pour naviguer, Entrée pour activer.`); // C38/C79: tabNavCount excludes hover-only skull
      }
    }
  };

  // C85-01: zone label map (used by pointer action + keyboard nav + aria-live)
  const ZONE_ARIA_LABELS: Readonly<Record<LairZone, string>> = {
    map:       'Carte des Biomes',
    crystal:   'Sph\u00e8re de Vision', // C140/LORE: ogham=pierre runique, pas sph\u00e8re cristal
    bookshelf: 'Journal de Merlin',
    cauldron:  'Chaudron Druidique',
    door:      'Sortie vers l\'aventure',
    skull:     'Crâne du Sage',
  };

  // C110: lore descriptions enhanced — Celtic-immersive atmosphere (was generic UI copy).
  // References specific mythological anchors: Cerridwen (cauldron goddess), Brocéliande (sacred forest).
  const ZONE_LORE: Readonly<Record<LairZone, string>> = {
    map:       'Quelle contrée de Bretagne t\'appelle ce soir ?',
    crystal:   'La sph\u00e8re de cristal r\u00e9v\u00e8le les oghams de la prochaine carte',
    bookshelf: 'Les chroniques de Merlin gardent mémoire de tes actes',
    cauldron:  'Le chaudron de Cerridwen bouillonne de sagesse ancienne',
    door:      'Les bois de Brocéliande t\'attendent, voyageur',
    skull:     'Les anciens druides méditaient face à la mort — gardienne des secrets oubliés',
  };

  const onPointerAction = (e: { clientX: number; clientY: number }): void => {
    const rect = renderer.domElement.getBoundingClientRect();
    mouse.x = ((e.clientX - rect.left) / rect.width) * 2 - 1;
    mouse.y = -((e.clientY - rect.top) / rect.height) * 2 + 1;
    const found = getIntersected();
    if (found && zoneClickCallback) {
      // C82-01: confirm click audio before callback (which may trigger scene transition)
      window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'flip' } }));
      // skull is hover-only (no game action) — announcing "activée" misleads AT users (WCAG 4.1.3)
      if (found.zone !== 'skull') ariaLive.textContent = `${ZONE_ARIA_LABELS[found.zone]} activée`;
      if (found.zone === 'door') {
        // C101: cinematic flash — 380ms burst before transition to give visual drama
        // C121: guard double-click — second click while flashing would overwrite doorFlashCancelHandle
        // making the first setTimeout untrackable (cannot be cleared in dispose)
        if (doorFlashing) return;
        const cb = zoneClickCallback; // capture before setTimeout (TypeScript narrowing)
        doorFlashing = true;
        doorFlashTimer = 0;
        (doorPanel.material as MeshStandardMaterial).emissiveIntensity = 1.2;
        window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'magic_reveal' } }));
        // C157: door cinematic overlay — dark background + expanding text + mapZoom SFX at 400ms
        doorCinematicText.style.fontSize = '12px';
        doorCinematicText.style.opacity = '1';
        doorCinematicOverlay.style.background = 'rgba(0,0,0,0.6)';
        // Trigger font-size expansion (CSS transition runs on next paint)
        window.requestAnimationFrame(() => {
          doorCinematicText.style.fontSize = '28px';
        });
        window.setTimeout(() => {
          if (!lairDisposed) window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'mapZoom' } }));
        }, 400);
        doorFlashCancelHandle = window.setTimeout(() => {
          doorFlashing = false;
          // Reset cinematic overlay
          doorCinematicText.style.opacity = '0';
          doorCinematicOverlay.style.background = 'rgba(0,0,0,0)';
          if (!lairDisposed) cb(found.zone); // C102: guard against stale callback after dispose()
        }, 380);
      } else {
        // C188: skull click — ominous critical_alert SFX (more fitting than default hover flip)
        if (found.zone === 'skull') {
          window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'critical_alert' } }));
        }
        zoneClickCallback(found.zone);
      }
    }
  };

  // Touch → pointer bridge (BUG-L-06 fix)
  // C95: tap-to-preview — touchstart shows lore toast; touchend activates if no drag occurred.
  // Previous: touchstart → activate immediately (toast never shown on mobile, UX regression).
  // Fix: touchstart → hover (shows toast), touchend (no swipe) → activate, touchend (swipe) → clear only.
  let touchMoved = false;
  const onTouchMove = (e: TouchEvent): void => {
    e.preventDefault();
    touchMoved = true;
    const t = e.touches[0] ?? e.changedTouches[0];
    if (t) onMouseMove({ clientX: t.clientX, clientY: t.clientY });
  };
  const onTouchStart = (e: TouchEvent): void => {
    e.preventDefault();
    touchMoved = false;
    const t = e.touches[0] ?? e.changedTouches[0];
    if (t) onMouseMove({ clientX: t.clientX, clientY: t.clientY }); // C95: reveal lore toast on press
  };
  // C85-01: touchend clears hover — prevents zones staying visually stuck on mobile
  // C95: also activates zone on tap-lift (no drag); passes changedTouches coordinate to onPointerAction
  const onTouchEnd = (e: TouchEvent): void => {
    if (!touchMoved) {
      const t = e.changedTouches[0];
      if (t) onPointerAction({ clientX: t.clientX, clientY: t.clientY }); // C95: activate on clean tap
    }
    if (currentHovered) {
      currentHovered.hovered = false;
      // C98: scale lerped back to 1.0 in update loop — no setScalar needed here
      applyHoverTo(currentHovered, currentHovered.baseEmissive ?? 0.15);
      currentHovered = null;
      renderer.domElement.style.cursor = 'default';
      zoneToast.style.opacity = '0'; // C132/BUG-C131-01: hide lore toast on tap-lift — mouseleave path
      zoneFloatLabel.style.opacity = '0'; // C157: hide float label on tap-lift
      bookExcerptEl.style.opacity = '0'; // C220: hide book excerpt on tap-lift
      crystalFortuneEl.style.opacity = '0'; // C227: hide crystal fortune on tap-lift
      // was the only path that set opacity=0; touchEnd only cleared emissive/scale but left toast visible.
    }
  };

  // C85-01: keyboard navigation — Tab cycles zones, Enter/Space activates
  // C155/SKULL-KB-01: add skull to keyboard cycle — it has ZONE_ARIA_LABELS + ZONE_LORE
  // entries and a hover-only action (no game effect). WCAG 2.1.1 requires all interactive
  // elements to be keyboard-reachable. The Enter handler at line 1086 already guards skull
  // (skull = hover-only; ariaLive not announced as "activée" to avoid misleading feedback).
  const KEYBOARD_ZONES: LairZone[] = ['map', 'crystal', 'bookshelf', 'cauldron', 'skull', 'door'];
  let keyboardZoneIdx = -1;
  const onKeyDown = (e: KeyboardEvent): void => {
    if ((e.key === 'Tab' && !e.shiftKey) || e.key === 'ArrowRight' || e.key === 'ArrowDown') {
      e.preventDefault();
      keyboardZoneIdx = (keyboardZoneIdx + 1) % KEYBOARD_ZONES.length;
    } else if ((e.key === 'Tab' && e.shiftKey) || e.key === 'ArrowLeft' || e.key === 'ArrowUp') {
      e.preventDefault();
      keyboardZoneIdx = (keyboardZoneIdx - 1 + KEYBOARD_ZONES.length) % KEYBOARD_ZONES.length;
    } else if ((e.key === 'Enter' || e.key === ' ') && currentHovered && zoneClickCallback) {
      e.preventDefault();
      window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'flip' } }));
      // C84: skull guard — matches pointer-path fix (C83). currentHovered can be skull if mouse-
      // hovered skull then user switches to keyboard; skull is hover-only (no game action).
      if (currentHovered.zone !== 'skull') ariaLive.textContent = `${ZONE_ARIA_LABELS[currentHovered.zone]} activée`;
      // C113: keyboard door activation mirrors pointer cinematic — 380ms flash + magic_reveal SFX
      // C121: same double-activation guard as pointer path — keyboard Enter can fire twice in 380ms
      if (currentHovered.zone === 'door') {
        if (doorFlashing) return;
        const kbZone = currentHovered.zone;
        const kbCb = zoneClickCallback;
        doorFlashing = true;
        doorFlashTimer = 0;
        (doorPanel.material as MeshStandardMaterial).emissiveIntensity = 1.2;
        window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'magic_reveal' } }));
        // C157: door cinematic overlay (keyboard path — mirrors pointer path)
        doorCinematicText.style.fontSize = '12px';
        doorCinematicText.style.opacity = '1';
        doorCinematicOverlay.style.background = 'rgba(0,0,0,0.6)';
        window.requestAnimationFrame(() => { doorCinematicText.style.fontSize = '28px'; });
        window.setTimeout(() => {
          if (!lairDisposed) window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'mapZoom' } }));
        }, 400);
        doorFlashCancelHandle = window.setTimeout(() => {
          doorFlashing = false;
          doorCinematicText.style.opacity = '0';
          doorCinematicOverlay.style.background = 'rgba(0,0,0,0)';
          if (!lairDisposed) kbCb(kbZone);
        }, 380);
      } else {
        // C188: skull keyboard Enter — ominous critical_alert SFX (mirrors pointer-path fix)
        if (currentHovered.zone === 'skull') {
          window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'critical_alert' } }));
        }
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
      // C98: scale lerped back to 1.0 in update loop
      applyHoverTo(currentHovered, currentHovered.baseEmissive ?? 0.15);
    }
    currentHovered = next;
    if (currentHovered) {
      currentHovered.hovered = true;
      // C33: scale lerped toward 1.05 in update loop
      applyHoverTo(currentHovered, 0.65);
      window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'hover' } }));
      renderer.domElement.setAttribute('aria-label', `Zone active : ${ZONE_ARIA_LABELS[zone]} — Entrée pour activer`);
      ariaLive.textContent = `${ZONE_ARIA_LABELS[zone]} — Appuyez sur Entrée pour activer`;
      // C101: sync lore toast with keyboard navigation (onMouseMove only fires on pointer)
      // C104: textContent — XSS-safe (keyboard path mirrors pointer path)
      zoneToast.textContent = '';
      const kLbl = document.createElement('strong');
      kLbl.style.cssText = `color:#33ff66;font-size:13px;font-family:'Courier New',monospace;letter-spacing:0.08em;`;
      kLbl.textContent = ZONE_ARIA_LABELS[zone];
      const kDesc = document.createElement('span');
      kDesc.style.cssText = `color:rgba(51,255,102,0.55);font-size:11px;font-family:'Courier New',monospace;`;
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

  // C53: camera sway angular frequencies — computed ONCE at init, not per rAF frame.
  // Eliminates 4 multiplications/frame (0.3*PI*2 and 0.17*PI*2 are constant; V8 cannot
  // constant-fold across closure boundaries without an explicit const declaration).
  const SWAY_X_FREQ = 0.3 * Math.PI * 2;  // 1.885 rad/s (0.3 Hz)
  const SWAY_Y_FREQ = 0.17 * Math.PI * 2; // 1.068 rad/s (0.17 Hz)

  // Update loop
  const update = (dt: number): void => {
    if (lairDisposed) return; // C105: guard stale rAF frame after dispose() on slow devices
    elapsedTime += dt;

    // C127: entry cinematic — cubic ease-out pull from z=10 to z=7 over 1.2s
    if (!entryCamDone) {
      const t = Math.min(elapsedTime / ENTRY_CAM_DURATION, 1.0);
      const eased = 1 - (1 - t) * (1 - t) * (1 - t); // cubic ease-out
      camera.position.z = 10 - 3 * eased; // 10 → 7
      if (t >= 1.0) { camera.position.z = 7; entryCamDone = true; }
    }

    // Camera slow sway — only after entry cinematic to keep pull-in as pure Z track
    if (entryCamDone) {
      camera.position.x = Math.sin(elapsedTime * SWAY_X_FREQ) * 0.1; // C53: SWAY_X_FREQ = 0.3*PI*2 (hoisted)
      // C50: 0.23→0.17Hz — beat period: |0.3-0.23|⁻¹=14.3s (noticeable loop) → |0.3-0.17|⁻¹=7.7s (below perceptual threshold)
      camera.position.y = 0.5 + Math.sin(elapsedTime * SWAY_Y_FREQ) * 0.06; // C53: SWAY_Y_FREQ = 0.17*PI*2 (hoisted)
    } else {
      camera.position.x = 0;   // no lateral drift during cinematic
      camera.position.y = 0.5; // stable Y baseline
    }

    // Crystal ball pulse
    crystalData.light.intensity = 2.2 + Math.sin(elapsedTime * 1.8) * 0.4;
    // C177: crystal sphere emissive pulse — 3s period (Math.PI*2/3 rad/s), range 0.3↔1.2.
    // Hover boosts base by +0.3 (unhovered centre=0.75, hovered centre=1.05) before sine swing.
    // C118: use cached crystalEntry (set at init) — no Array.find() allocation on hot path
    const crystalPulse = Math.sin(elapsedTime * (Math.PI * 2 / 3)) * 0.45;
    const crystalEmissive = (crystalEntry.hovered ? 1.05 : 0.75) + crystalPulse;
    crystalData.mat.emissiveIntensity = crystalEmissive;
    // C111: also animate GLB material emissive — procedural mat targets hidden sphere post-load (BUG-C46-01)
    if (crystalGLBMat) crystalGLBMat.emissiveIntensity = crystalEmissive;
    // C177: crystal teal glow PointLight breathes in sync with emissive pulse
    crystalTealLight.intensity = 0.6 + crystalPulse * 0.8;

    // C174: cauldron iron emissive pulse — green hot-metal glow (in sync with glow PointLight 2.3Hz)
    const cauldronEmissive = (cauldronEntry.hovered ? 0.18 : 0.06) + Math.sin(elapsedTime * 2.3) * 0.04;
    (cauldron.body.material as MeshStandardMaterial).emissiveIntensity = cauldronEmissive;
    if (cauldronGLBMat) cauldronGLBMat.emissiveIntensity = cauldronEmissive;

    // C174: skull haunting pulse — slow sinusoidal bone-glow (0.7Hz, offset π to phase against crystal)
    const skullEmissive = (skullEntry.hovered ? 0.28 : 0.05) + Math.sin(elapsedTime * 0.7 + Math.PI) * 0.03;
    (skullCranium.material as MeshStandardMaterial).emissiveIntensity = skullEmissive;
    // C172: skull bob — gentle vertical oscillation (0.8Hz, 0.02 amplitude) — magical/living feel
    skullGroup.position.y = skullBaseY + Math.sin(elapsedTime * 0.8 * Math.PI * 2) * 0.02;

    // C174: periodic cauldron bubble SFX — auditory presence without visual spam
    if (!lowFpsMode) {
      bubbleSFXTimer += dt;
      if (bubbleSFXTimer >= BUBBLE_SFX_INTERVAL) {
        bubbleSFXTimer = 0;
        window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'cauldron' } }));
      }
    }
    // C118: procedural sphere uses -1.0 (always correct); GLB uses crystalGLBBaseY delta (GLB root Y)
    // C53: cache float sin — sin(t*0.9) used twice (sphere + GLB); one call instead of two per frame
    const floatSin = Math.sin(elapsedTime * 0.9);
    // C95: skip dead write on sphere once GLB has taken over (sphere is hidden, write was wasted every frame)
    if (!crystalGLBGroup) crystalData.sphere.position.y = -1.0 + floatSin * 0.04;
    // C101: sync GLB group float — procedural sphere is hidden post-load, GLB takes its place
    if (crystalGLBGroup) crystalGLBGroup.position.y = crystalGLBBaseY + floatSin * 0.04;

    // Door light flicker — C101: burst overrides normal flicker during door cinematic
    if (doorFlashing) {
      doorFlashTimer += dt;
      doorLight.intensity = 12 + Math.sin(doorFlashTimer * 45) * 4;
    } else {
      doorLight.intensity = 2.8 + Math.sin(elapsedTime * 4.1) * 0.3;
    }

    // C188: door rune glow — lerp green PointLight toward 1.2 on hover, 0.0 on unhover
    {
      const runeTarget = doorEntry.hovered ? 1.2 : 0.0;
      doorRuneLight.intensity += (runeTarget - doorRuneLight.intensity) * Math.min(1, dt * 6);
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

    // Candles (T064) — C81: gate under !lowFpsMode; flicker is cosmetic (same as dust)
    if (!lowFpsMode) updateCandles(candles, dt, elapsedTime);

    // Dust motes — C102: skip on low-fps devices (pure cosmetic, saves ~1ms/frame)
    if (!lowFpsMode) dust.update(dt);
    // C157: green phosphor magic dust (same FPS gate as dust — cosmetic)
    if (!lowFpsMode) magicDust.update(dt);

    // Cauldron steam — C82: gate under !lowFpsMode (steam + glow sin is cosmetic)
    if (!lowFpsMode) cauldron.update(elapsedTime, dt);

    // C231: cauldron bubble particle system — gate under !lowFpsMode (cosmetic)
    if (!lowFpsMode) {
      _bubbleTimer += dt;
      if (_bubbleTimer >= 0.3) {
        _bubbleTimer = 0;
        // Activate a random inactive bubble
        const inactive = _bubbleMeshes.filter((b) => !b.userData['active']);
        if (inactive.length > 0) {
          const pick = inactive[Math.floor(Math.random() * inactive.length)];
          pick.position.y = (pick.userData['cauldronY'] as number) + 0.4;
          pick.userData['active'] = true;
        }
      }
      for (const bm of _bubbleMeshes) {
        if (!bm.userData['active']) continue;
        const cY = bm.userData['cauldronY'] as number;
        const spd = bm.userData['speed'] as number;
        const ph  = bm.userData['phase']  as number;
        const bx  = bm.userData['baseX']  as number;
        bm.position.y += spd * dt;
        bm.position.x = bx + Math.sin(elapsedTime * 2 + ph) * 0.05;
        // Fade opacity 0.6 → 0 as bubble rises from cY+0.4 to cY+1.5
        const rise = bm.position.y - (cY + 0.4);
        const t01  = Math.min(1, rise / 1.1);
        (bm.material as MeshBasicMaterial).opacity = 0.6 * (1 - t01);
        if (bm.position.y > cY + 1.5) {
          bm.userData['active'] = false;
          bm.position.y = cY + 0.4;
          (bm.material as MeshBasicMaterial).opacity = 0;
        }
      }
    }

    // C241: floor rune rings — slow counter-rotation + opacity pulse (cosmetic, gate under !lowFpsMode)
    if (!lowFpsMode) {
      _runeRingTime += dt;
      if (_runeRing1) {
        _runeRing1.rotation.z += dt * 0.15;
        (_runeRing1.material as MeshBasicMaterial).opacity = 0.25 + Math.sin(_runeRingTime * 0.5) * 0.1;
      }
      if (_runeRing2) {
        _runeRing2.rotation.z -= dt * 0.22;
        (_runeRing2.material as MeshBasicMaterial).opacity = 0.4 + Math.sin(_runeRingTime * 0.7 + 1.0) * 0.12;
      }
    }

    // C264: vial light pulse — gentle sine intensity oscillation
    if (!lowFpsMode) {
      _vialTime += dt;
      for (let i = 0; i < _vialLights.length; i++) {
        _vialLights[i].intensity = 0.2 + Math.sin(_vialTime * 1.2 + i * 1.1) * 0.1;
      }
    }

    // C269: spell tome open/close cycle — 8s period, opens over 1s, stays open 3s, then closes
    if (!lowFpsMode && _tomePivotGroup) {
      _tomeTime += dt;
      const cycle = _tomeTime % 8;
      const targetAngle = (cycle > 2 && cycle < 5) ? Math.PI * 0.6 : 0;
      _tomeOpenAngle += (targetAngle - _tomeOpenAngle) * Math.min(dt * 2, 1);
      _tomePivotGroup.rotation.z = _tomeOpenAngle;
    }

    // Forest window (leaf sway + glass shimmer) — C83: gate leaf sway under !lowFpsMode
    // Leaf sway = 3 Math.sin/frame (spring/summer, default season) — cosmetic, same category as dust
    if (!lowFpsMode) lairWindow.update(elapsedTime);

    // C33: dt-based hover scale lerp — smooth Celtic ritual feel (replaces instant setScalar in handlers)
    // 18 units/s → ~100ms transition at 60fps, ~55ms at 30fps. Stops when within 0.001 of target.
    for (const obj of interactives) {
      const mesh = (obj.visualMesh ?? obj.mesh) as Mesh;
      const targetScale = obj.hovered ? 1.05 : 1.0;
      const cur = mesh.scale.x;
      if (Math.abs(cur - targetScale) > 0.001) {
        mesh.scale.setScalar(cur + (targetScale - cur) * Math.min(1, 18 * dt));
      }
    }

    // C201: ambient whisper rotation — 8s cycle, 1.2s fade-out/in, 3s initial delay.
    // State: whisperIndex=-1 means "not yet shown first whisper".
    // whisperFading=true means currently fading out before a text swap.
    // Cycle: wait WHISPER_CYCLE_MS → fade-out 1.2s → swap text → fade-in → repeat.
    whisperTimer += dt * 1000;
    if (!whisperFading) {
      const threshold = whisperIndex < 0 ? WHISPER_START_MS : WHISPER_CYCLE_MS;
      if (whisperTimer >= threshold) {
        if (whisperIndex < 0) {
          // First whisper: no fade-out needed, just show directly
          whisperIndex = 0;
          whisperEl.textContent = WHISPERS[0];
          whisperEl.style.opacity = '0.75';
          whisperTimer = 0;
        } else {
          // Subsequent whispers: fade out current, then swap
          whisperFading = true;
          whisperFadeTimer = 0;
          whisperEl.style.opacity = '0';
        }
      }
    } else {
      whisperFadeTimer += dt * 1000;
      if (whisperFadeTimer >= WHISPER_FADE_MS) {
        whisperIndex = (whisperIndex + 1) % WHISPERS.length;
        whisperEl.textContent = WHISPERS[whisperIndex];
        whisperEl.style.opacity = '0.75';
        whisperFading = false;
        whisperTimer = 0;
        whisperFadeTimer = 0;
      }
    }

    renderer.render(scene, camera);
  };

  const dispose = (): void => {
    // C154/LAIR-05: null callback first — blocks any post-dispose onPointerAction/onKeyDown
    // click events during the 300ms cutToBlack window before canvas listeners are removed.
    // The `if (found && zoneClickCallback)` guard in onPointerAction short-circuits with null.
    zoneClickCallback = null;
    lairDisposed = true; // C81-03: signal in-flight GLB .then() callbacks to abort
    cancelGLBFades(); // C133: stop any in-flight fadeInGLB rAFs immediately (no extra frame after dispose)
    cleanupLairDensity(); // C35: remove moon.target (world-space Object3D — not reached by traverse)
    scene.remove(lairWindow.windowLight.target); // C83: spotlight target added at world level — not in group, not reached by traverse
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
    renderer.domElement.removeEventListener('touchmove', onTouchMove, { passive: false } as EventListenerOptions);
    renderer.domElement.removeEventListener('touchstart', onTouchStart, { passive: false } as EventListenerOptions);
    renderer.domElement.removeEventListener('touchend', onTouchEnd);
    renderer.domElement.removeEventListener('keydown', onKeyDown);
    // C120: cancel door flash timeout — lairDisposed guard blocks cb() but closure stays alive 380ms
    clearTimeout(doorFlashCancelHandle);
    // C97: mur_pierre uses one cloned geometry + one cloned material shared across 3 InstancedMeshes.
    // Without dedup guards, traverse calls geometry.dispose()/material.dispose() 3× on the same
    // object, firing redundant WebGL deallocation events. Use Sets to dispose each only once.
    const disposedGeos = new Set<BufferGeometry>();
    const disposedMats = new Set<Material>();
    scene.traverse((obj) => {
      if (obj instanceof InstancedMesh) {
        // C109: InstancedMesh.dispose() fires the renderer 'dispose' event so the instanceMatrix
        // GPU buffer (InstancedBufferAttribute) is deallocated. Without this call, instanceMatrix
        // data leaks on repeated hub ↔ lair navigations — geometry.dispose() alone only clears
        // the base vertex attributes, not the per-instance matrix buffer.
        obj.dispose();
        if (!disposedGeos.has(obj.geometry)) { disposedGeos.add(obj.geometry); obj.geometry.dispose(); }
        const mat = obj.material as Material;
        if (!disposedMats.has(mat)) { disposedMats.add(mat); mat.dispose(); }
      } else if (obj instanceof Mesh || obj instanceof Points) {
        if (!disposedGeos.has(obj.geometry)) { disposedGeos.add(obj.geometry); obj.geometry.dispose(); }
        if (Array.isArray(obj.material)) {
          obj.material.forEach((m) => { if (!disposedMats.has(m)) { disposedMats.add(m); m.dispose(); } });
        } else {
          const mat = obj.material as Material;
          if (!disposedMats.has(mat)) { disposedMats.add(mat); mat.dispose(); }
        }
      }
    });
    renderer.dispose();
    // C119: reset cursor BEFORE removeChild — style write has no effect on detached nodes;
    // prevents persistent 'pointer' cursor leaking onto next scene's container on fast transition
    renderer.domElement.style.cursor = 'default';
    if (renderer.domElement.parentNode) {
      renderer.domElement.parentNode.removeChild(renderer.domElement);
    }
    if (ariaLive.parentNode) {
      ariaLive.parentNode.removeChild(ariaLive);
    }
    if (zoneToast.parentNode) {
      zoneToast.parentNode.removeChild(zoneToast);
    }
    // C157: remove new DOM elements
    if (zoneFloatLabel.parentNode) {
      zoneFloatLabel.parentNode.removeChild(zoneFloatLabel);
    }
    if (doorCinematicOverlay.parentNode) {
      doorCinematicOverlay.parentNode.removeChild(doorCinematicOverlay);
    }
    // C201: remove whisper panel
    if (whisperEl.parentNode) {
      whisperEl.parentNode.removeChild(whisperEl);
    }
    // C220: remove bookshelf lore excerpt panel
    if (bookExcerptEl.parentNode) {
      bookExcerptEl.parentNode.removeChild(bookExcerptEl);
    }
    // C227: remove crystal fortune panel
    if (crystalFortuneEl.parentNode) {
      crystalFortuneEl.parentNode.removeChild(crystalFortuneEl);
    }
    // C231: clear bubble refs (geometries/materials disposed by scene.traverse above)
    _bubbleMeshes = [];
    // C241: clear rune ring refs (geometries/materials disposed by scene.traverse above)
    _runeRing1 = null;
    _runeRing2 = null;
    // C264: clear vial refs (geometries/materials disposed by scene.traverse above)
    _vialMeshes = [];
    _vialLights = [];
    // C269: clear tome refs (geometries/materials disposed by scene.traverse above)
    _tomeCoverMesh = null;
    _tomePagesMesh = null;
    _tomePivotGroup = null;
  };

  const onZoneClick = (cb: (zone: LairZone) => void): void => {
    zoneClickCallback = cb;
  };

  const setTime = (params: LairTimeParams): void => {
    lairWindow.updateTime(params);
  };

  return { update, dispose, onZoneClick, setTime };
}
