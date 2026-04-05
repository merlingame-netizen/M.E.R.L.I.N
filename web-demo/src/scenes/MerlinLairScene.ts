// Merlin's Lair — 3D interior hub (T062+T064). 4 zones: Map/Crystal/Bookshelf/Door.
// Cycle 31: AAA lighting (6 sources — key/rim/fill/cauldron/hemi/ambient; C36 added HemisphereLight).
// Cycle 35: Window + forest view + day/night/season cycle. GLB assets: cauldron/bougie/table/biblio.

import { AdditiveBlending, AmbientLight, BoxGeometry, BufferAttribute, BufferGeometry, CircleGeometry, ConeGeometry, CylinderGeometry, DoubleSide, Fog, Group, HemisphereLight, InstancedMesh, Line, LineBasicMaterial, LineLoop, Material, Mesh, MeshBasicMaterial, MeshStandardMaterial, Object3D, PerspectiveCamera, PlaneGeometry, PointLight, Points, PointsMaterial, Raycaster, RingGeometry, Scene, SphereGeometry, TorusGeometry, Vector2, Vector3, WebGLRenderer } from 'three';
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

// ── C328: Right-Wall Bookshelf with Tomes ────────────────────────────────────

function createTomeBookshelf(): { group: Group; bookmarkMesh: Mesh } {
  const group = new Group();

  // Back panel (vertical spine flush against right wall)
  const backMat = new MeshStandardMaterial({ color: 0x0c1208, roughness: 0.9, metalness: 0.0, flatShading: true });
  const backPanel = new Mesh(new BoxGeometry(0.1, 4.0, 2.0), backMat);
  backPanel.position.set(5.8, -1.5, -8.5);
  group.add(backPanel);

  // 3 horizontal shelf planks — y: -2.8 / -1.5 / -0.2
  const plankGeo = new BoxGeometry(0.06, 0.06, 1.9);
  const plankMat = new MeshStandardMaterial({ color: 0x0c1208, roughness: 0.9, metalness: 0.0, flatShading: true });
  const plankYs = [-2.8, -1.5, -0.2];
  for (const py of plankYs) {
    const plank = new Mesh(plankGeo, plankMat);
    plank.position.set(5.8, py, -8.5);
    group.add(plank);
  }

  // 14 tomes spread across 3 shelves (4 / 5 / 5 books per shelf)
  const SPINE_COLORS = [0x0a1f0a, 0x1a2a1a, 0x0c2010, 0x061408, 0x152a15];
  interface BookDef { w: number; h: number; z: number; yBase: number; tilt?: number }

  // Build book definitions — lined left-to-right along z axis on each shelf plank
  // Shelf z range: center -8.5, plank depth 1.9 → z from -9.45 to -7.55
  const bookDefs: BookDef[] = [];

  // shelf 0 — y=-2.8 — 4 books
  const shelf0Y = -2.8;
  const shelf0Books: Array<[number, number, number?]> = [
    [0.12, 0.38, -0.15],
    [0.16, 0.30, 0.15],
    [0.10, 0.42, -0.15],
    [0.14, 0.35, undefined],
  ];
  let zOff0 = -8.5 - (shelf0Books.reduce((s, b) => s + b[0]!, 0) + (shelf0Books.length - 1) * 0.025) / 2;
  for (const [bw, bh, tilt] of shelf0Books) {
    bookDefs.push({ w: bw, h: bh, z: zOff0 + bw / 2, yBase: shelf0Y, tilt });
    zOff0 += bw + 0.025;
  }

  // shelf 1 — y=-1.5 — 5 books
  const shelf1Y = -1.5;
  const shelf1Books: Array<[number, number, number?]> = [
    [0.10, 0.40, undefined],
    [0.18, 0.28, 0.15],
    [0.12, 0.44, undefined],
    [0.09, 0.36, -0.15],
    [0.15, 0.32, undefined],
  ];
  let zOff1 = -8.5 - (shelf1Books.reduce((s, b) => s + b[0]!, 0) + (shelf1Books.length - 1) * 0.022) / 2;
  for (const [bw, bh, tilt] of shelf1Books) {
    bookDefs.push({ w: bw, h: bh, z: zOff1 + bw / 2, yBase: shelf1Y, tilt });
    zOff1 += bw + 0.022;
  }

  // shelf 2 — y=-0.2 — 5 books
  const shelf2Y = -0.2;
  const shelf2Books: Array<[number, number, number?]> = [
    [0.13, 0.38, 0.15],
    [0.11, 0.45, undefined],
    [0.16, 0.30, undefined],
    [0.10, 0.40, -0.15],
    [0.14, 0.34, undefined],
  ];
  let zOff2 = -8.5 - (shelf2Books.reduce((s, b) => s + b[0]!, 0) + (shelf2Books.length - 1) * 0.022) / 2;
  for (const [bw, bh, tilt] of shelf2Books) {
    bookDefs.push({ w: bw, h: bh, z: zOff2 + bw / 2, yBase: shelf2Y, tilt });
    zOff2 += bw + 0.022;
  }

  // Instantiate books
  let bookmarkMesh: Mesh | null = null;
  bookDefs.forEach((bd, idx) => {
    const spineColor = SPINE_COLORS[idx % SPINE_COLORS.length]!;
    const mat = new MeshStandardMaterial({ color: spineColor, roughness: 0.85, metalness: 0.0, flatShading: true });
    const book = new Mesh(new BoxGeometry(bd.w, bd.h, 0.14), mat);
    // Y: shelf plank surface + half book height for it to sit on the plank
    book.position.set(5.75, bd.yBase + bd.h / 2, bd.z);
    if (bd.tilt !== undefined) book.rotation.z = bd.tilt;
    group.add(book);

    // Glowing bookmark — sticks out of book #7 (1-indexed) on shelf 1
    if (idx === 6) {
      const bmMat = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.7 });
      const bm = new Mesh(new BoxGeometry(0.02, 0.3, 0.01), bmMat);
      // Position: top of the book (center + half height + half bookmark height)
      bm.position.set(5.75, bd.yBase + bd.h + 0.15, bd.z);
      group.add(bm);
      bookmarkMesh = bm;
    }
  });

  // Fallback if idx=6 somehow missing (TypeScript narrowing guard)
  if (!bookmarkMesh) {
    const bmMat = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.7 });
    bookmarkMesh = new Mesh(new BoxGeometry(0.02, 0.3, 0.01), bmMat);
    bookmarkMesh.position.set(5.75, -0.8, -8.5);
    group.add(bookmarkMesh);
  }

  return { group, bookmarkMesh };
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

  // C277: scrying pool — shallow dark bowl + pulsing vision disc on lair floor
  let _scryingPoolMesh: Mesh | null = null;
  let _scryingVisionMesh: Mesh | null = null;
  let _scryingTime = 0;

  // C284: wall-mounted astrolabe — 3 concentric torus rings on the back wall
  let _astroRing1: Mesh | null = null;
  let _astroRing2: Mesh | null = null;
  let _astroRing3: Mesh | null = null;
  let _astroTime = 0;

  // C292: skull shelf — 3 skulls with pulsing green eye glow
  const _skullLights: PointLight[] = [];

  // C301: wall moss/algae patches — slow breathing opacity
  const _mossPatches: Mesh[] = [];

  // C316: cauldron steam wisps — 8 larger, slower, more translucent spheres rising above bubbles
  const _steamWisps: Mesh[] = [];

  // C328: right-wall decorative bookshelf
  let _bookshelfGroup: Group | null = null;
  let _bookmarkMesh: Mesh | null = null;
  let _bookmarkTime = 0;

  // C335: alchemy floor symbols — 4 etched glyphs with sequential glow
  const _alchemySymbolMeshes: Mesh[] = [];
  const _alchemyLights: PointLight[] = [];
  let _alchemyTime = 0;

  // C343: map table scattered items — scroll, parchment, rune stones, quill, inkwell
  let _mapTableGroup: Group | null = null;
  let _mapScrollLight: PointLight | null = null;
  let _mapParchment: Mesh | null = null;
  let _mapParchmentTime = 0;

  // C347: back-ledge candle arc — 5 candles with independent green flame flicker
  const _candleFlames: Mesh[] = [];
  const _candleLights: PointLight[] = [];

  // C355: hanging herb bundles — 5 clusters dangling from ceiling beams, slow pendulum sway
  const _herbBundles355: Group[] = [];
  const _herbLights355: PointLight[] = [];

  // C376: wind chime rods — 5 metallic tubes hanging from ceiling, pendulum physics + chime flash
  const _chimeRods376: Mesh[] = [];
  const _chimeLights376: PointLight[] = [];
  const _chimeAngles376: number[] = [];
  const _chimeVelocities376: number[] = [];

  // C380: crystal orb rack — 3 glowing orbs on iron stands, independent vision flare events
  const _orbMeshes380: Mesh[] = [];
  const _orbLights380: PointLight[] = [];
  let _orbVisionT380 = -1;
  let _orbNextVision380 = 12.0;
  let _orbVisionIdx380 = 0;

  // C361: enchanted mirror portal — oval frame + ripple surface + vision pulse
  let mirrorGroup361: Group | null = null;
  let mirrorSurface361: Mesh | null = null;
  let mirrorLight361: PointLight | null = null;
  let mirrorPulseT361 = -1;
  let mirrorNextPulse361 = 10.0;

  // C384: alchemical balance scale — pendulum arm, two pans on chains, green spark events
  let _scaleGroup384: Group | null = null;
  let _scaleArm384: Mesh | null = null;
  let _scalePanLeft384: Group | null = null;
  let _scalePanRight384: Group | null = null;
  let _scaleSparkLight384: PointLight | null = null;
  let _scaleNextSpark384 = 8.0;
  let _scaleSparkT384 = -1;

  // C391: pendulum wall clock — dark ornate case, swinging pendulum, rotating hands, chime flash
  let _clockGroup391: Group | null = null;
  let _clockPendulum391: Group | null = null;
  let _clockHourHand391: Mesh | null = null;
  let _clockMinuteHand391: Mesh | null = null;
  let _clockChimeLight391: PointLight | null = null;
  let _clockAngle391 = 0;
  let _clockVelocity391 = 1.2;
  let _clockChimeT391 = -1;
  let _clockNextChime391 = 15.0;

  // C396: floating magical parchment scroll — slow unroll/re-roll + read flash event
  let _scrollGroup396: Group | null = null;
  let _scrollFace396: Mesh | null = null;
  let _scrollLight396: PointLight | null = null;
  let _scrollReadT396 = -1;
  let _scrollNextRead396 = 10.0;
  let _scrollUnrollT396 = 0;

  // C401: spider web with dew drops — upper-left corner (-3.5, 3.2, -2.5)
  let _webGroup: Group | null = null;
  let _webDewT = 0;
  const _webDewSpheres: Mesh[] = [];

  // C408: bubbling cauldron with steam and potion glow — (-2, 0, -5)
  let _cauldronGroup: Group | null = null;
  let _cauldronT = 0;
  let _cauldronBubbleTimer = 0;
  const _steamPuffs: Mesh[] = [];
  const _steamVel: { vy: number; life: number; maxLife: number }[] = [];
  let _cauldronLight: PointLight | null = null;
  let _potionSurface: Mesh | null = null;

  // C413: floating spell tome
  let _tomeGroup: Group | null = null;
  let _tomeT = 0;
  let _tomePageFlipTimer = 0;
  let _tomePageFlipDur = 0;
  let _tomePageL: Mesh | null = null;
  let _tomePageR: Mesh | null = null;
  let _tomeGlowLight: PointLight | null = null;

  // C418: suspended astrolabe
  let _astroGroup: Group | null = null;
  let _astroT = 0;
  let _astroRingOuter: Group | null = null;
  let _astroRingMid: Group | null = null;
  let _astroRingInner: Group | null = null;

  // C424: ceiling star projector
  let _starProjGroup: Group | null = null;
  let _starProjT = 0;
  const _starDots: Mesh[] = [];
  let _starProjLight: PointLight | null = null;

  // C428: sleeping familiar cat
  let _catGroup: Group | null = null;
  let _catT = 0;
  let _catWakeTimer = 0;
  let _catNextWake = 12 + Math.random() * 15;
  let _catBody: Mesh | null = null;
  let _catEyeL: Mesh | null = null;
  let _catEyeR: Mesh | null = null;
  let _catHead: Group | null = null;

  // C432: floating hourglass
  let _hourglassGroup: Group | null = null;
  let _hourglassT = 0;
  let _hourglassFlipTimer = 0;
  let _hourglassNextFlip = 20 + Math.random() * 15;
  let _hourglassFlipping = false;
  const _sandParticles: Mesh[] = [];
  const _sandVel: { y: number; life: number; maxLife: number }[] = [];
  let _hourglassLight: PointLight | null = null;

  // C436 — floor summoning rune circle (closure-scope vars)
  let _runeCircleGroup: Group | null = null;
  let _runeCircleT = 0;
  let _runeActivateTimer = 0;
  let _runeNextActivate = 10 + Math.random() * 20;
  let _runeActivating = false;
  let _runeActiveDur = 0;
  const _runeRings: Mesh[] = [];
  let _runeCircleLight: PointLight | null = null;

  // C441 — celestial star map parchment (closure-scope vars)
  let starMapGroup441: Group | null = null;
  let starMapT441: number = 0;
  const starDots441: Mesh[] = [];

  // C447 — enchanted mirror (closure-scope vars)
  let mirrorGroup447: Group | null = null;
  let mirrorT447: number = 0;
  let mirrorSurfaceMat447: MeshBasicMaterial | null = null;
  let mirrorFlashTimer447: number = 25;
  let mirrorFlashing447: boolean = false;
  let mirrorFlashT447: number = 0;
  let mirrorLight447: PointLight | null = null;

  // C452 — floating scrying orb (closure-scope vars)
  let scryingOrbGroup452: Group | null = null;
  let scryingOrbT452: number = 0;
  let scryingOrbMat452: MeshBasicMaterial | null = null;
  let scryingOrbLight452: PointLight | null = null;
  let scryingOrbVisionTimer452: number = 18;
  let scryingOrbVisionActive452: boolean = false;
  let scryingOrbVisionT452: number = 0;

  // C457 — magical stone fireplace with green flames
  let fireplaceGroup457: Group | null = null;
  let fireplaceT457: number = 0;
  let fireplaceFlames457: Mesh[] = [];
  let fireplaceSparks457: Mesh[] = [];
  let fireplaceLight457: PointLight | null = null;

  // C462 — floating runic calendar disc
  let calendarDisc462: Group | null = null;
  let calendarDiscT462: number = 0;
  let calendarRunesMats462: MeshBasicMaterial[] = [];
  let calendarDiscLight462: PointLight | null = null;
  let calendarSurgeTimer462: number = 25;
  let calendarSurging462: boolean = false;
  let calendarSurgeT462: number = 0;

  // C438 — potion bottle shelf
  let _potionShelfGroup: Group | null = null;
  let _potionShelfT = 0;
  const _potionLiquids: Mesh[] = [];
  const _potionLights: PointLight[] = [];

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

  // C316: create 8 steam wisps rising from the cauldron mouth (larger/slower/more translucent than bubbles)
  {
    const CAULDRON_X = 2;
    const CAULDRON_Z = -7;
    const wispGeo = new SphereGeometry(0.14, 5, 4);
    for (let wi = 0; wi < 8; wi++) {
      const wm = new Mesh(wispGeo, new MeshBasicMaterial({ color: 0x1a3a1a, transparent: true, opacity: 0 }));
      const startX = CAULDRON_X + (Math.random() - 0.5) * 0.6;
      const startZ = CAULDRON_Z + (Math.random() - 0.5) * 0.6;
      wm.position.set(startX, -4.0, startZ);
      wm.userData = {
        startX,
        startZ,
        speed: 0.18 + Math.random() * 0.14,
        phase: Math.random() * Math.PI * 2,
        driftX: 0.08 + Math.random() * 0.10,
        driftZ: 0.08 + Math.random() * 0.10,
      };
      scene.add(wm);
      _steamWisps.push(wm);
    }
  }

  // C328: right-wall decorative bookshelf with tomes and glowing bookmark
  {
    const { group: tbGroup, bookmarkMesh: tbBookmark } = createTomeBookshelf();
    scene.add(tbGroup);
    _bookshelfGroup = tbGroup;
    _bookmarkMesh = tbBookmark;
  }

  // C335: alchemy floor symbols — 4 etched glyphs on the flagstone floor (y=-4.85)
  // Colors: 0x0a2a12 (dim), glow flares to 0x33ff66 (bright) at peak
  {
    const FLOOR_Y = -4.85;
    const DIM_COLOR = 0x0a2a12;

    // Helper: create a MeshBasicMaterial for an alchemy symbol mesh
    const alchMat = (opacity: number): MeshBasicMaterial =>
      new MeshBasicMaterial({ color: DIM_COLOR, transparent: true, opacity, depthWrite: false });

    // ── Symbol 1: Circle — torus flat on floor at (-2, -4.85, -6) ────────────
    {
      const geo = new TorusGeometry(0.4, 0.03, 6, 24);
      const mesh = new Mesh(geo, alchMat(0.20));
      mesh.rotation.x = -Math.PI / 2;
      mesh.position.set(-2, FLOOR_Y + 0.01, -6);
      scene.add(mesh);
      _alchemySymbolMeshes.push(mesh);
      const light = new PointLight(0x33ff66, 0.0, 3);
      light.position.set(-2, FLOOR_Y + 0.3, -6);
      scene.add(light);
      _alchemyLights.push(light);
    }

    // ── Symbol 2: Triangle — 3 BoxGeometry bars arranged as triangle sides ───
    {
      const barGeo = new BoxGeometry(0.7, 0.03, 0.04);
      const mat = alchMat(0.18);
      const PX = 2.5, PZ = -9;
      // Bottom bar — horizontal
      const b0 = new Mesh(barGeo, mat);
      b0.position.set(PX, FLOOR_Y + 0.01, PZ + 0.2);
      scene.add(b0);
      _alchemySymbolMeshes.push(b0);
      // Left bar — rotated 60°
      const b1 = new Mesh(barGeo, mat.clone());
      b1.position.set(PX - 0.175, FLOOR_Y + 0.01, PZ - 0.1);
      b1.rotation.y = Math.PI / 3;
      scene.add(b1);
      _alchemySymbolMeshes.push(b1);
      // Right bar — rotated -60°
      const b2 = new Mesh(barGeo, mat.clone());
      b2.position.set(PX + 0.175, FLOOR_Y + 0.01, PZ - 0.1);
      b2.rotation.y = -Math.PI / 3;
      scene.add(b2);
      _alchemySymbolMeshes.push(b2);
      const light = new PointLight(0x33ff66, 0.0, 3);
      light.position.set(PX, FLOOR_Y + 0.3, PZ);
      scene.add(light);
      _alchemyLights.push(light);
    }

    // ── Symbol 3: Cross within circle — torus + 2 crossing bars ─────────────
    {
      const PX = -4, PZ = -9.5;
      const mat = alchMat(0.15);
      const torus = new Mesh(new TorusGeometry(0.5, 0.025, 5, 24), mat);
      torus.rotation.x = -Math.PI / 2;
      torus.position.set(PX, FLOOR_Y + 0.01, PZ);
      scene.add(torus);
      _alchemySymbolMeshes.push(torus);
      // Horizontal bar
      const barH = new Mesh(new BoxGeometry(0.9, 0.02, 0.03), mat.clone());
      barH.position.set(PX, FLOOR_Y + 0.012, PZ);
      scene.add(barH);
      _alchemySymbolMeshes.push(barH);
      // Vertical bar (rotated 90° around Y)
      const barV = new Mesh(new BoxGeometry(0.9, 0.02, 0.03), mat.clone());
      barV.rotation.y = Math.PI / 2;
      barV.position.set(PX, FLOOR_Y + 0.014, PZ);
      scene.add(barV);
      _alchemySymbolMeshes.push(barV);
      const light = new PointLight(0x33ff66, 0.0, 3);
      light.position.set(PX, FLOOR_Y + 0.3, PZ);
      scene.add(light);
      _alchemyLights.push(light);
    }

    // ── Symbol 4: Spiral — outer + inner torus concentric ────────────────────
    {
      const PX = 4, PZ = -7;
      const outerMesh = new Mesh(new TorusGeometry(0.3, 0.02, 5, 16), alchMat(0.16));
      outerMesh.rotation.x = -Math.PI / 2;
      outerMesh.position.set(PX, FLOOR_Y + 0.01, PZ);
      scene.add(outerMesh);
      _alchemySymbolMeshes.push(outerMesh);
      const innerMesh = new Mesh(new TorusGeometry(0.15, 0.02, 5, 12), alchMat(0.16));
      innerMesh.rotation.x = -Math.PI / 2;
      innerMesh.position.set(PX, FLOOR_Y + 0.012, PZ);
      scene.add(innerMesh);
      _alchemySymbolMeshes.push(innerMesh);
      const light = new PointLight(0x33ff66, 0.0, 3);
      light.position.set(PX, FLOOR_Y + 0.3, PZ);
      scene.add(light);
      _alchemyLights.push(light);
    }
  }

  // C343: map table scattered items — rolled scroll, parchment, rune stones, quill, inkwell.
  // Map table top at (-5, -2, -3), surface y = -2 + 0.09 = -1.91. Scroll hit-target at y=-1.88.
  // Tome sits at TOME_Z=-5 (north edge). Items placed south of tome (z=-3 area, table surface).
  {
    const TABLE_X = -5;
    const TABLE_Y = -1.91; // table top surface y
    const group = new Group();

    // ── Rolled map scroll (horizontal cylinder) ──────────────────────────────
    const scrollMat = new MeshBasicMaterial({ color: 0x1a2a1a });
    const scrollCyl = new Mesh(new CylinderGeometry(0.08, 0.08, 1.6, 6), scrollMat);
    scrollCyl.rotation.z = Math.PI / 2; // lay horizontal along X axis
    scrollCyl.position.set(TABLE_X + 0.3, TABLE_Y + 0.08, -2.5);
    group.add(scrollCyl);

    // End caps on scroll cylinder
    const capGeo = new CircleGeometry(0.08, 6);
    const capMat = new MeshBasicMaterial({ color: 0x1a2a1a, side: DoubleSide });
    const capLeft = new Mesh(capGeo, capMat);
    capLeft.rotation.y = Math.PI / 2;
    capLeft.position.set(TABLE_X + 0.3 - 0.8, TABLE_Y + 0.08, -2.5);
    group.add(capLeft);
    const capRight = new Mesh(capGeo, capMat.clone());
    capRight.rotation.y = -Math.PI / 2;
    capRight.position.set(TABLE_X + 0.3 + 0.8, TABLE_Y + 0.08, -2.5);
    group.add(capRight);

    // ── Flat unrolled parchment portion (next to scroll) ─────────────────────
    const parchMat = new MeshBasicMaterial({ color: 0x0c1a0c, transparent: true, opacity: 0.35, side: DoubleSide, depthWrite: false });
    const parch = new Mesh(new PlaneGeometry(1.2, 0.8), parchMat);
    parch.rotation.x = -Math.PI / 2 - 0.1; // flat on table with slight perspective tilt
    parch.position.set(TABLE_X - 0.7, TABLE_Y + 0.005, -2.6);
    group.add(parch);
    _mapParchment = parch;

    // Green glow from map glyphs — above parchment
    const scrollLight = new PointLight(0x33ff66, 0.08, 3);
    scrollLight.position.set(TABLE_X - 0.7, TABLE_Y + 0.5, -2.6);
    group.add(scrollLight);
    _mapScrollLight = scrollLight;

    // ── 3 rune stone tokens (flat cylinders) ────────────────────────────────
    const stoneDefs: Array<{ dx: number; dz: number; color: number }> = [
      { dx: -1.2, dz: -3.2, color: 0x0a140a },
      { dx: -0.6, dz: -2.2, color: 0x0c160c },
      { dx:  0.6, dz: -3.5, color: 0x0a140a },
    ];
    for (const sd of stoneDefs) {
      const stone = new Mesh(
        new CylinderGeometry(0.08, 0.10, 0.04, 6),
        new MeshBasicMaterial({ color: sd.color })
      );
      stone.position.set(TABLE_X + sd.dx, TABLE_Y + 0.02, sd.dz);
      group.add(stone);
    }

    // ── Quill / stylus (thin tapered cylinder at slight angle) ───────────────
    const quill = new Mesh(
      new CylinderGeometry(0.008, 0.02, 0.8, 4),
      new MeshBasicMaterial({ color: 0x0a1a0a })
    );
    quill.position.set(TABLE_X + 0.8, TABLE_Y + 0.04, -3.3);
    quill.rotation.z = 0.25; // slight angle across table
    quill.rotation.y = 0.4;
    group.add(quill);

    // ── Inkwell (short wide cylinder + flat cap) ─────────────────────────────
    const inkwellMat = new MeshBasicMaterial({ color: 0x080e08 });
    const inkwell = new Mesh(new CylinderGeometry(0.06, 0.08, 0.12, 8), inkwellMat);
    inkwell.position.set(TABLE_X + 1.1, TABLE_Y + 0.06, -2.8);
    group.add(inkwell);
    const inkCap = new Mesh(new CircleGeometry(0.06, 8), new MeshBasicMaterial({ color: 0x080e08 }));
    inkCap.rotation.x = -Math.PI / 2;
    inkCap.position.set(TABLE_X + 1.1, TABLE_Y + 0.12, -2.8);
    group.add(inkCap);

    scene.add(group);
    _mapTableGroup = group;
  }

  // C347: back-ledge candle arc — 5 candles at x=-1.0..1.4, y=-3.0, z=-9.8
  // Wax: 0x0a180a, Flame: 0x33ff66 (CeltOS charter — zero amber/orange/yellow)
  {
    const CANDLE_Y = -3.0;
    const CANDLE_Z = -9.8;
    const CANDLE_X_POSITIONS = [-1.0, -0.4, 0.2, 0.8, 1.4];
    const waxMat = new MeshBasicMaterial({ color: 0x0a180a });
    const flameMat = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.92 });

    const heightVariations = [0.0, 0.12, -0.06, 0.18, 0.04]; // deterministic slight height variation

    for (let i = 0; i < CANDLE_X_POSITIONS.length; i++) {
      const cx = CANDLE_X_POSITIONS[i]!;
      const candleH = 0.35 + heightVariations[i]!;

      // Wax column
      const waxBody = new Mesh(new CylinderGeometry(0.05, 0.06, candleH, 6), waxMat.clone());
      waxBody.position.set(cx, CANDLE_Y + candleH / 2, CANDLE_Z);
      scene.add(waxBody);

      // Wax drip ring at base — slightly wider
      const waxDrip = new Mesh(new CylinderGeometry(0.05, 0.08, 0.06, 6), waxMat.clone());
      waxDrip.position.set(cx, CANDLE_Y + 0.03, CANDLE_Z);
      scene.add(waxDrip);

      // Flame cone at top of wax column
      const flameY = CANDLE_Y + candleH + 0.06; // sits just above wax top
      const flame = new Mesh(new ConeGeometry(0.04, 0.12, 4), flameMat.clone());
      flame.position.set(cx, flameY, CANDLE_Z);
      scene.add(flame);
      _candleFlames.push(flame);

      // Per-candle green glow
      const candleLight = new PointLight(0x33ff66, 0.2, 2.5);
      candleLight.position.set(cx, flameY, CANDLE_Z);
      scene.add(candleLight);
      _candleLights.push(candleLight);
    }
  }

  // C355: hanging herb bundles — 5 clusters of dried herbs/flowers dangling from ceiling beams
  // Ceiling underside at y ≈ 11 - 0.4/2 = 10.8. Beams at y ≈ 10.5. Bundles hang at y = 3.5 (long rope implied).
  // CeltOS charter: green family only — 0x1a3a1a stems, 0x2a5a2a clusters, 0x33ff66 light, 0x0d4420 emissive.
  {
    const HERB_POSITIONS: Array<[number, number, number]> = [
      [-2, 3.5, -3], [1, 3.5, -2.5], [-1, 3.5, -4.5], [2.5, 3.5, -3.5], [0, 3.5, -2],
    ];
    const stemMat = new MeshStandardMaterial({ color: 0x1a3a1a, roughness: 0.9, metalness: 0.0, flatShading: true });
    const clusterMat = new MeshStandardMaterial({
      color: 0x2a5a2a, roughness: 0.85, metalness: 0.0, flatShading: true,
      emissive: new (stemMat.emissive.constructor as new (hex: number) => typeof stemMat.emissive)(0x0d4420),
      emissiveIntensity: 0.04,
    });
    // Use explicit hex setHex — avoids needing to import Color
    clusterMat.emissive.setHex(0x0d4420);
    const STEM_COUNTS = [3, 4, 5, 3, 4]; // deterministic per bundle
    const STEM_OFFSETS: Array<Array<[number, number]>> = [
      [[-0.03, -0.01], [0.02, 0.04], [-0.01, -0.04]],
      [[-0.04, 0.02], [0.03, -0.03], [0.00, 0.05], [-0.02, -0.02]],
      [[-0.03, -0.02], [0.04, 0.01], [-0.01, 0.04], [0.02, -0.03], [0.00, 0.00]],
      [[-0.02, 0.03], [0.03, -0.01], [0.00, -0.04]],
      [[-0.03, 0.02], [0.04, -0.02], [0.01, 0.05], [-0.02, -0.03]],
    ];
    const STEM_ROTS: Array<Array<number>> = [
      [0.1, -0.15, 0.2],
      [-0.1, 0.18, -0.12, 0.08],
      [0.15, -0.1, 0.2, -0.18, 0.05],
      [0.12, -0.14, 0.08],
      [-0.08, 0.16, -0.12, 0.1],
    ];
    for (let bi = 0; bi < HERB_POSITIONS.length; bi++) {
      const [bx, by, bz] = HERB_POSITIONS[bi]!;
      const bundle = new Group();
      bundle.position.set(bx, by, bz);
      const count = STEM_COUNTS[bi]!;
      const offsets = STEM_OFFSETS[bi]!;
      const rots = STEM_ROTS[bi]!;
      const stemH = 0.3 + bi * 0.04; // subtle height variation per bundle
      // Stems hanging downward (cylinder long axis = Y by default)
      for (let si = 0; si < count; si++) {
        const [ox, oz] = offsets[si]!;
        const stem = new Mesh(new CylinderGeometry(0.01, 0.015, stemH, 4), stemMat.clone());
        stem.position.set(ox, -stemH / 2, oz);
        stem.rotation.z = rots[si]!;
        bundle.add(stem);
      }
      // Leaf/flower cluster — 8 tiny spheres at bottom of bundle
      const clusterY = -stemH - 0.04;
      const CLUSTER_OFFSETS: Array<[number, number, number]> = [
        [-0.04, 0, -0.03], [0.04, 0, -0.02], [0, 0.04, 0.03], [-0.03, -0.03, 0.02],
        [0.03, 0.03, -0.04], [-0.02, 0, 0.04], [0.02, -0.04, 0], [0, 0.02, -0.02],
      ];
      for (const [cx, cy, cz] of CLUSTER_OFFSETS) {
        const sphere = new Mesh(new SphereGeometry(0.03, 4, 3), clusterMat.clone());
        sphere.position.set(cx, clusterY + cy, cz);
        bundle.add(sphere);
      }
      // Ambient herb glow — faint green PointLight at cluster position
      const herbLight = new PointLight(0x33ff66, 0.05, 1.2);
      herbLight.position.set(0, clusterY, 0);
      bundle.add(herbLight);
      _herbLights355.push(herbLight);

      scene.add(bundle);
      _herbBundles355.push(bundle);
    }
    // Shared mats not added to scene — dispose handled via traverse in dispose()
    stemMat.dispose();
    clusterMat.dispose();
  }

  // C376: wind chime rods — 5 thin metallic tubes hanging from ceiling at (-1.5, 3.2, -2.5)
  {
    const ROD_LENGTHS = [0.5, 0.65, 0.45, 0.7, 0.55];
    const ROD_OFFSETS = [-0.18, -0.09, 0, 0.09, 0.18];
    const PIVOT_X = -1.5;
    const PIVOT_Y = 3.2;
    const PIVOT_Z = -2.5;
    for (let i = 0; i < ROD_LENGTHS.length; i++) {
      const len = ROD_LENGTHS[i]!;
      const xOff = ROD_OFFSETS[i]!;
      const chimeMat = new MeshStandardMaterial({
        color: 0x0d2a0d, roughness: 0.2, metalness: 0.7, flatShading: false,
      });
      chimeMat.emissive.setHex(0x0d4420);
      chimeMat.emissiveIntensity = 0.05;
      const rodGeo = new CylinderGeometry(0.012, 0.012, len, 5);
      const rod = new Mesh(rodGeo, chimeMat);
      rod.position.set(PIVOT_X + xOff, PIVOT_Y - len / 2, PIVOT_Z);
      scene.add(rod);
      _chimeRods376.push(rod);
      _chimeAngles376.push(Math.random() * 0.2 - 0.1);
      _chimeVelocities376.push((Math.random() - 0.5) * 0.3);
      const light = new PointLight(0x33ff66, 0.0, 1.5);
      light.position.set(PIVOT_X + xOff, PIVOT_Y - len, PIVOT_Z);
      scene.add(light);
      _chimeLights376.push(light);
    }
  }

  // C380: crystal orb rack — wooden/iron rack with 3 glowing nebula orbs on the bookshelf side
  {
    const standMat380 = new MeshStandardMaterial({ color: 0x0a1a0a, roughness: 0.8, metalness: 0.5 });

    // Rack shelf — horizontal bar spanning 3 orb positions
    const rackShelf = new Mesh(new BoxGeometry(1.0, 0.06, 0.12), standMat380);
    rackShelf.position.set(-2.5, 1.1, -3.8);
    scene.add(rackShelf);

    const ORB_OFFSETS_380 = [-0.32, 0, 0.32];
    ORB_OFFSETS_380.forEach((ox, i) => {
      // Stand post
      const post = new Mesh(new CylinderGeometry(0.015, 0.02, 0.25, 5), standMat380.clone());
      post.position.set(-2.5 + ox, 0.975, -3.8);
      scene.add(post);

      // Cradle ring
      const cradle = new Mesh(new TorusGeometry(0.09, 0.015, 6, 10), standMat380.clone());
      cradle.position.set(-2.5 + ox, 1.21, -3.8);
      cradle.rotation.x = Math.PI / 2;
      scene.add(cradle);

      // Crystal orb
      const orbGeo = new SphereGeometry(0.1, 10, 8);
      const orbMat = new MeshStandardMaterial({
        color: 0x051505,
        emissive: new (MeshStandardMaterial.prototype.emissive.constructor as unknown as new (hex: number) => typeof MeshStandardMaterial.prototype.emissive)(0x0d4420),
        emissiveIntensity: 0.15,
        roughness: 0.0,
        metalness: 0.1,
        transparent: true,
        opacity: 0.65,
      });
      orbMat.emissive.setHex(0x0d4420);
      const orb = new Mesh(orbGeo, orbMat);
      orb.position.set(-2.5 + ox, 1.22, -3.8);
      orb.userData['phase'] = i * 1.3;
      scene.add(orb);
      _orbMeshes380.push(orb);

      // Orb point light
      const orbLight = new PointLight(0x33ff66, 0.10, 2.5);
      orbLight.position.set(-2.5 + ox, 1.22, -3.8);
      scene.add(orbLight);
      _orbLights380.push(orbLight);
    });

    _orbNextVision380 = 12.0 + Math.random() * 6.0;
  }

  // C384: alchemical balance scale — pendulum arm + two hanging pans + spark light
  {
    _scaleGroup384 = new Group();
    const scaleMat = new MeshStandardMaterial({ color: 0x0d200d, roughness: 0.3, metalness: 0.7 });
    const panMat = new MeshStandardMaterial({ color: 0x0a1a0a, roughness: 0.5, metalness: 0.6 });

    // Base and column
    const base384 = new Mesh(new CylinderGeometry(0.2, 0.25, 0.06, 8), scaleMat);
    _scaleGroup384.add(base384);
    const column384 = new Mesh(new CylinderGeometry(0.025, 0.03, 0.7, 6), scaleMat);
    column384.position.y = 0.38;
    _scaleGroup384.add(column384);

    // Top pivot sphere
    const pivot384 = new Mesh(new SphereGeometry(0.04, 6, 5), scaleMat);
    pivot384.position.y = 0.73;
    _scaleGroup384.add(pivot384);

    // Balance arm (rotates around pivot)
    _scaleArm384 = new Mesh(new BoxGeometry(0.7, 0.025, 0.025), scaleMat);
    _scaleArm384.position.y = 0.73;
    _scaleGroup384.add(_scaleArm384);

    // Left pan group
    _scalePanLeft384 = new Group();
    _scalePanLeft384.position.set(-0.32, 0.73, 0);
    for (let i = 0; i < 3; i++) {
      const link = new Mesh(new BoxGeometry(0.01, 0.07, 0.01), scaleMat);
      link.position.y = -0.05 - i * 0.07;
      _scalePanLeft384.add(link);
    }
    const panL = new Mesh(new CylinderGeometry(0.1, 0.08, 0.02, 8), panMat);
    panL.position.y = -0.28;
    _scalePanLeft384.add(panL);
    _scaleGroup384.add(_scalePanLeft384);

    // Right pan group (mirror)
    _scalePanRight384 = new Group();
    _scalePanRight384.position.set(0.32, 0.73, 0);
    for (let i = 0; i < 3; i++) {
      const link = new Mesh(new BoxGeometry(0.01, 0.07, 0.01), scaleMat);
      link.position.y = -0.05 - i * 0.07;
      _scalePanRight384.add(link);
    }
    const panR = new Mesh(new CylinderGeometry(0.1, 0.08, 0.02, 8), panMat);
    panR.position.y = -0.28;
    _scalePanRight384.add(panR);
    _scaleGroup384.add(_scalePanRight384);

    // Spark light (over left pan)
    _scaleSparkLight384 = new PointLight(0x33ff66, 0.0, 1.5);
    _scaleSparkLight384.position.set(-0.32, 0.45, 0);
    _scaleGroup384.add(_scaleSparkLight384);

    _scaleGroup384.position.set(1.5, 0, -4.0);
    scene.add(_scaleGroup384);
    _scaleNextSpark384 = 8.0 + Math.random() * 4.0;
  }

  // C391: pendulum wall clock — dark ornate case on left wall (x=-3.2, y=2.0, z=-3.0)
  {
    _clockGroup391 = new Group();
    const clockCaseMat = new MeshStandardMaterial({ color: 0x0a1a0a, roughness: 0.7, metalness: 0.4 });
    const clockFaceMat = new MeshStandardMaterial({ color: 0x051505, emissiveIntensity: 0.05, roughness: 0.4, metalness: 0.1 });
    clockFaceMat.emissive.setHex(0x0d4420);
    const handMat = new MeshStandardMaterial({ color: 0x0d2a0d, roughness: 0.3, metalness: 0.6 });

    // Clock case (box)
    const caseBox = new Mesh(new BoxGeometry(0.5, 0.5, 0.08), clockCaseMat);
    _clockGroup391.add(caseBox);

    // Clock face (disc, cylinder on its side)
    const face = new Mesh(new CylinderGeometry(0.22, 0.22, 0.02, 12), clockFaceMat);
    face.rotation.x = Math.PI / 2;
    face.position.z = 0.05;
    _clockGroup391.add(face);

    // Hour hand
    _clockHourHand391 = new Mesh(new BoxGeometry(0.025, 0.12, 0.015), handMat);
    _clockHourHand391.position.set(0, 0.04, 0.07);
    _clockGroup391.add(_clockHourHand391);

    // Minute hand
    _clockMinuteHand391 = new Mesh(new BoxGeometry(0.015, 0.16, 0.015), handMat);
    _clockMinuteHand391.position.set(0, 0.06, 0.08);
    _clockGroup391.add(_clockMinuteHand391);

    // Pendulum housing extension below clock case
    const housing = new Mesh(new BoxGeometry(0.35, 0.55, 0.06), clockCaseMat.clone());
    housing.position.y = -0.52;
    _clockGroup391.add(housing);

    // Pendulum group (pivots from top of housing)
    _clockPendulum391 = new Group();
    _clockPendulum391.position.set(0, -0.27, 0);
    // Rod
    const pendulumRod = new Mesh(new BoxGeometry(0.012, 0.38, 0.012), handMat.clone());
    pendulumRod.position.y = -0.19;
    _clockPendulum391.add(pendulumRod);
    // Weight disc
    const pendulumWeight = new Mesh(new CylinderGeometry(0.06, 0.06, 0.04, 8), clockCaseMat.clone());
    pendulumWeight.rotation.x = Math.PI / 2;
    pendulumWeight.position.y = -0.4;
    _clockPendulum391.add(pendulumWeight);
    _clockGroup391.add(_clockPendulum391);

    // Chime light
    _clockChimeLight391 = new PointLight(0x33ff66, 0.0, 2.5);
    _clockChimeLight391.position.set(0, 0, 0.3);
    _clockGroup391.add(_clockChimeLight391);

    _clockGroup391.position.set(-3.2, 2.0, -3.0);
    _clockGroup391.rotation.y = Math.PI / 2;
    scene.add(_clockGroup391);
    _clockNextChime391 = 15.0 + Math.random() * 10.0;

    // Dispose template mats (clones in use, templates not in scene)
    clockCaseMat.dispose();
    clockFaceMat.dispose();
    handMat.dispose();
  }

  // C396: floating magical parchment scroll — mid-air level (x=0.5, y=1.8, z=-3.5)
  {
    _scrollGroup396 = new Group();
    const rollMat = new MeshStandardMaterial({ color: 0x0d1f0d, roughness: 0.8, metalness: 0.3 });
    const faceMat396 = new MeshStandardMaterial({
      color: 0x051505,
      emissiveIntensity: 0.08,
      transparent: true,
      opacity: 0.7,
      roughness: 0.9,
    });
    faceMat396.emissive.setHex(0x0d4420);

    // Left roll
    const rollL = new Mesh(new CylinderGeometry(0.04, 0.04, 0.25, 6), rollMat.clone());
    rollL.rotation.z = Math.PI / 2;
    rollL.position.x = -0.22;
    _scrollGroup396.add(rollL);

    // Right roll
    const rollR = new Mesh(new CylinderGeometry(0.04, 0.04, 0.25, 6), rollMat.clone());
    rollR.rotation.z = Math.PI / 2;
    rollR.position.x = 0.22;
    _scrollGroup396.add(rollR);

    // Scroll face (flat parchment between rolls)
    _scrollFace396 = new Mesh(new PlaneGeometry(0.4, 0.22), faceMat396);
    _scrollFace396.position.x = 0;
    _scrollGroup396.add(_scrollFace396);

    // Glow light
    _scrollLight396 = new PointLight(0x33ff66, 0.06, 1.5);
    _scrollGroup396.add(_scrollLight396);

    _scrollGroup396.position.set(0.5, 1.8, -3.5);
    _scrollGroup396.rotation.y = 0.3;
    scene.add(_scrollGroup396);
    _scrollNextRead396 = 10.0 + Math.random() * 5.0;

    // Dispose template mats (clones in use, templates not in scene)
    rollMat.dispose();
  }

  // C401: spider web with dew drops — upper-left corner (-3.5, 3.2, -2.5)
  {
    _webGroup = new Group();
    const wireMat = new LineBasicMaterial({ color: 0x0d2a12 });

    // 6 radial spokes from center to radius 0.6
    const SPOKE_COUNT = 6;
    const SPOKE_RADIUS = 0.6;
    for (let si = 0; si < SPOKE_COUNT; si++) {
      const angle = (si / SPOKE_COUNT) * Math.PI * 2;
      const spokeGeo = new BufferGeometry().setFromPoints([
        new Vector3(0, 0, 0),
        new Vector3(Math.cos(angle) * SPOKE_RADIUS, Math.sin(angle) * SPOKE_RADIUS, 0),
      ]);
      const spoke = new Line(spokeGeo, wireMat);
      _webGroup.add(spoke);
    }

    // 3 concentric ring polygons at radii 0.2, 0.4, 0.6 (12-segment LineLoop)
    const RING_SEGMENTS = 12;
    for (const ringR of [0.2, 0.4, 0.6]) {
      const ringPoints: Vector3[] = [];
      for (let ri = 0; ri <= RING_SEGMENTS; ri++) {
        const a = (ri / RING_SEGMENTS) * Math.PI * 2;
        ringPoints.push(new Vector3(Math.cos(a) * ringR, Math.sin(a) * ringR, 0));
      }
      const ringGeo = new BufferGeometry().setFromPoints(ringPoints);
      const ring = new LineLoop(ringGeo, wireMat);
      _webGroup.add(ring);
    }

    // 12 dew drops placed at random positions on the spokes
    const dewGeo = new SphereGeometry(0.025, 4, 3);
    const dewMat = new MeshStandardMaterial({
      color: 0x1a4a22,
      emissive: 0x0a2a0e,
      emissiveIntensity: 0.3,
      transparent: true,
      opacity: 0.7,
    });
    for (let di = 0; di < 12; di++) {
      const spokeAngle = (Math.floor(di * SPOKE_COUNT / 12) / SPOKE_COUNT) * Math.PI * 2;
      const t = 0.15 + Math.random() * 0.8;
      const dew = new Mesh(dewGeo, dewMat.clone());
      dew.position.set(Math.cos(spokeAngle) * SPOKE_RADIUS * t, Math.sin(spokeAngle) * SPOKE_RADIUS * t, 0.005);
      _webDewSpheres.push(dew);
      _webGroup.add(dew);
    }

    _webGroup.rotation.z = 0.15;
    _webGroup.rotation.x = -0.2;
    _webGroup.position.set(-3.5, 3.2, -2.5);
    scene.add(_webGroup);

    // Dispose template geo/mat (clones in use)
    dewGeo.dispose();
    dewMat.dispose();
    wireMat.dispose();
  }

  // C408: bubbling cauldron with steam and potion glow
  {
    _cauldronGroup = new Group();

    // Body
    const bodyGeo = new SphereGeometry(0.45, 10, 8);
    const bodyMat = new MeshBasicMaterial({ color: 0x0a1410 });
    const body = new Mesh(bodyGeo, bodyMat);
    body.scale.set(1, 0.75, 1);
    body.position.set(0, 0.35, 0);
    _cauldronGroup.add(body);

    // Rim ring
    const rimGeo = new TorusGeometry(0.45, 0.04, 6, 16);
    const rimMat = new MeshBasicMaterial({ color: 0x0a1a10 });
    const rim = new Mesh(rimGeo, rimMat);
    rim.position.set(0, 0.62, 0);
    _cauldronGroup.add(rim);

    // 3 legs
    const legAngles = [0, (2 * Math.PI) / 3, (4 * Math.PI) / 3];
    legAngles.forEach(angle => {
      const legGeo = new CylinderGeometry(0.04, 0.06, 0.35, 4);
      const legMat = new MeshBasicMaterial({ color: 0x0a1410 });
      const leg = new Mesh(legGeo, legMat);
      leg.position.set(Math.cos(angle) * 0.3, 0.08, Math.sin(angle) * 0.3);
      _cauldronGroup!.add(leg);
    });

    // Potion surface (liquid top)
    const potionGeo = new CircleGeometry(0.42, 16);
    const potionMat = new MeshBasicMaterial({ color: 0x0d3318, transparent: true, opacity: 0.9 });
    _potionSurface = new Mesh(potionGeo, potionMat);
    _potionSurface.rotation.x = -Math.PI / 2;
    _potionSurface.position.set(0, 0.64, 0);
    _cauldronGroup.add(_potionSurface);

    // Cauldron glow light
    _cauldronLight = new PointLight(0x33ff66, 0.25, 4.0);
    _cauldronLight.position.set(0, 0.8, 0);
    _cauldronGroup.add(_cauldronLight);

    // 8 steam puff spheres
    const puffGeo = new SphereGeometry(0.12, 4, 3);
    for (let i = 0; i < 8; i++) {
      const puffMat = new MeshBasicMaterial({ color: 0x0d2a14, transparent: true, opacity: 0.0 });
      const puff = new Mesh(puffGeo.clone(), puffMat);
      puff.position.set(0, 0.65, 0);
      const maxLife = 1.5 + i * 0.15;
      _steamPuffs.push(puff);
      _steamVel.push({ vy: 0.4 + i * 0.05, life: maxLife * (i / 8), maxLife });
      _cauldronGroup.add(puff);
    }
    puffGeo.dispose();

    _cauldronGroup.position.set(-2, 0, -5);
    scene.add(_cauldronGroup);
  }

  // C413 — floating spell tome
  {
    _tomeGroup = new Group();

    // Lectern base
    const lecternGeo = new BoxGeometry(0.5, 0.9, 0.4);
    const lecternMat = new MeshStandardMaterial({ color: 0x0a1a10, emissive: 0x050a08, roughness: 0.9, metalness: 0.0 });
    const lecternMesh = new Mesh(lecternGeo, lecternMat);
    lecternMesh.position.set(0, 0.45, 0);

    // Lectern top slant
    const topGeo = new BoxGeometry(0.55, 0.06, 0.45);
    const topMesh = new Mesh(topGeo, lecternMat);
    topMesh.position.set(0, 0.92, 0);
    topMesh.rotation.x = 0.2;

    // Book cover (back spine)
    const spineGeo = new BoxGeometry(0.08, 0.35, 0.28);
    const spineMat = new MeshStandardMaterial({ color: 0x0a2a14, emissive: 0x050f08, roughness: 0.8, metalness: 0.0 });
    const spineMesh = new Mesh(spineGeo, spineMat);
    spineMesh.position.set(0, 1.22, 0);

    // Left page
    const pageGeo = new BoxGeometry(0.22, 0.28, 0.02);
    const pageMat = new MeshBasicMaterial({ color: 0x0d2a14, transparent: true, opacity: 0.85 });
    _tomePageL = new Mesh(pageGeo, pageMat);
    _tomePageL.position.set(-0.15, 1.22, 0);
    _tomePageL.rotation.y = 0.15;

    // Right page
    _tomePageR = new Mesh(pageGeo.clone(), pageMat.clone() as MeshBasicMaterial);
    _tomePageR.position.set(0.15, 1.22, 0);
    _tomePageR.rotation.y = -0.15;

    // Glow lines on pages (thin planes for rune text effect)
    const runeLineMat = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.3 });
    for (let li = 0; li < 4; li++) {
      const lineGeo = new PlaneGeometry(0.16, 0.018);
      const lineMesh = new Mesh(lineGeo, runeLineMat);
      lineMesh.position.set(-0.15, 1.28 - li * 0.05, 0.012);
      _tomeGroup.add(lineMesh);
      const lineR = new Mesh(lineGeo.clone(), runeLineMat.clone() as MeshBasicMaterial);
      lineR.position.set(0.15, 1.28 - li * 0.05, 0.012);
      _tomeGroup.add(lineR);
    }

    // Point light above book
    _tomeGlowLight = new PointLight(0x33ff66, 0.2, 3.5);
    _tomeGlowLight.position.set(0, 1.55, 0);

    _tomePageFlipTimer = 0;
    _tomePageFlipDur = 4 + Math.random() * 6;

    _tomeGroup.add(lecternMesh, topMesh, spineMesh, _tomePageL, _tomePageR, _tomeGlowLight);
    _tomeGroup.position.set(2.5, 0, -3);
    scene.add(_tomeGroup);
  }

  // C418: suspended astrolabe
  {
    _astroGroup = new Group();

    // Hanging chain: 4 small spheres above
    const chainMat = new MeshBasicMaterial({ color: 0x0a2a14 });
    for (let ci = 0; ci < 4; ci++) {
      const bead = new Mesh(new SphereGeometry(0.025, 4, 3), chainMat);
      bead.position.y = 0.15 + ci * 0.12;
      _astroGroup.add(bead);
    }

    // Outer ring: TorusGeometry(0.55, 0.04, 6, 24)
    _astroRingOuter = new Group();
    const outerRing = new Mesh(
      new TorusGeometry(0.55, 0.04, 6, 24),
      new MeshBasicMaterial({ color: 0x0d2a14 })
    );
    for (let t = 0; t < 4; t++) {
      const tick = new Mesh(
        new BoxGeometry(0.04, 0.12, 0.04),
        new MeshBasicMaterial({ color: 0x1a4a22 })
      );
      tick.position.set(Math.cos(t * Math.PI / 2) * 0.55, Math.sin(t * Math.PI / 2) * 0.55, 0);
      _astroRingOuter.add(tick);
    }
    _astroRingOuter.add(outerRing);

    // Mid ring: TorusGeometry(0.38, 0.035, 6, 20), tilted 35°
    _astroRingMid = new Group();
    const midRing = new Mesh(
      new TorusGeometry(0.38, 0.035, 6, 20),
      new MeshBasicMaterial({ color: 0x0d3318 })
    );
    _astroRingMid.rotation.x = 0.6;
    _astroRingMid.add(midRing);

    // Inner ring: TorusGeometry(0.22, 0.03, 5, 16), tilted 70°
    _astroRingInner = new Group();
    const innerRing = new Mesh(
      new TorusGeometry(0.22, 0.03, 5, 16),
      new MeshBasicMaterial({ color: 0x0a2a14 })
    );
    _astroRingInner.rotation.z = 1.2;
    _astroRingInner.add(innerRing);

    // Central star pointer: thin cross of 2 BoxGeometry
    const pointerMat = new MeshBasicMaterial({ color: 0x33ff66 });
    const ptrH = new Mesh(new BoxGeometry(0.3, 0.03, 0.03), pointerMat);
    const ptrV = new Mesh(new BoxGeometry(0.03, 0.3, 0.03), pointerMat);
    const ptrCore = new Mesh(new SphereGeometry(0.04, 4, 3), new MeshBasicMaterial({ color: 0x33ff66 }));

    // Glow light
    const astroLight = new PointLight(0x33ff66, 0.12, 3.0);

    _astroGroup.add(_astroRingOuter, _astroRingMid, _astroRingInner, ptrH, ptrV, ptrCore, astroLight);
    _astroGroup.position.set(0, 3.2, -4);
    scene.add(_astroGroup);
  }

  // C424: ceiling star projector — device at (1.5, 0, -2), projects star map onto ceiling y=4
  {
    _starProjGroup = new Group();

    // Projector body
    const bodyMat = new MeshBasicMaterial({ color: 0x0a2a14 });
    const body = new Mesh(new BoxGeometry(0.18, 0.12, 0.18), bodyMat);
    body.position.set(0, 0.06, 0);
    _starProjGroup.add(body);

    // Lens
    const lensMat = new MeshBasicMaterial({ color: 0x0d3318 });
    const lens = new Mesh(new CylinderGeometry(0.04, 0.06, 0.08, 6), lensMat);
    lens.position.set(0, 0.16, 0);
    _starProjGroup.add(lens);

    // Core glow sphere
    const coreMat = new MeshBasicMaterial({ color: 0x33ff66 });
    const core = new Mesh(new SphereGeometry(0.025, 4, 3), coreMat);
    core.position.set(0, 0.16, 0);
    _starProjGroup.add(core);

    // Ceiling projection plane (dim base)
    const ceilPlaneMat = new MeshBasicMaterial({
      color: 0x0d2a14,
      transparent: true,
      opacity: 0.12,
      depthWrite: false,
      side: DoubleSide
    });
    const ceilPlane = new Mesh(new PlaneGeometry(3.5, 3.0), ceilPlaneMat);
    ceilPlane.position.set(0, 4.05, 0);
    ceilPlane.rotation.x = Math.PI / 2;
    _starProjGroup.add(ceilPlane);

    // 15 star dots scattered on ceiling (y=4.1)
    const starMat = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.8 });
    const starPositions: Array<[number, number, number]> = [
      [-1.2, 4.1, -0.8], [-0.5, 4.1, -1.1], [0.3, 4.1, -0.9], [0.9, 4.1, -1.3], [1.1, 4.1, -0.4],
      [0.6, 4.1,  0.3], [-0.2, 4.1,  0.7], [-0.9, 4.1,  0.5], [-1.3, 4.1,  0.1], [0.0, 4.1,  0.2],
      [-0.6, 4.1, -0.3], [0.5, 4.1, -0.5], [1.2, 4.1,  0.6], [-0.3, 4.1,  1.0], [0.8, 4.1,  0.9]
    ];
    for (const [sx, sy, sz] of starPositions) {
      const dot = new Mesh(new SphereGeometry(0.035, 4, 3), starMat.clone());
      dot.position.set(sx, sy, sz);
      _starProjGroup.add(dot);
      _starDots.push(dot);
    }

    // 10 constellation lines connecting pairs of stars
    const linePairs: Array<[number, number]> = [
      [0, 1], [1, 2], [2, 3], [3, 4], [4, 5],
      [5, 6], [6, 7], [7, 8], [9, 10], [11, 12]
    ];
    const lineMat = new LineBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.35 });
    for (const [ai, bi] of linePairs) {
      const pa = starPositions[ai];
      const pb = starPositions[bi];
      const pts = [
        new Vector3(pa[0], pa[1], pa[2]),
        new Vector3(pb[0], pb[1], pb[2])
      ];
      const lineGeo = new BufferGeometry().setFromPoints(pts);
      const line = new Line(lineGeo, lineMat.clone());
      _starProjGroup.add(line);
    }

    // Projection cone (visual beam from device up to ceiling)
    const coneMat = new MeshBasicMaterial({
      color: 0x33ff66,
      transparent: true,
      opacity: 0.03,
      side: DoubleSide,
      depthWrite: false
    });
    const cone = new Mesh(new ConeGeometry(1.8, 4.0, 8, 1, true), coneMat);
    cone.position.set(0, 2.1, 0);
    _starProjGroup.add(cone);

    // Ambient point light near ceiling
    _starProjLight = new PointLight(0x33ff66, 0.08, 5.0);
    _starProjLight.position.set(0, 3.5, 0);
    _starProjGroup.add(_starProjLight);

    _starProjGroup.position.set(1.5, 0, -2);
    scene.add(_starProjGroup);
  }

  // C428 — sleeping familiar cat
  {
    _catGroup = new Group();
    _catHead = new Group();

    const catMat = new MeshBasicMaterial({ color: 0x0a1a10 });
    const eyeMatL = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.0 });
    const eyeMatR = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.0 });

    // Cushion
    const cushion = new Mesh(new BoxGeometry(0.55, 0.08, 0.45), new MeshBasicMaterial({ color: 0x0a1a10 }));
    cushion.position.set(0, 0, 0);

    // Body (curled, sleeping position) — scaled sphere
    const bodyGeo = new SphereGeometry(0.22, 7, 5);
    _catBody = new Mesh(bodyGeo, catMat);
    _catBody.scale.set(1.4, 0.75, 1.1);
    _catBody.position.set(0, 0.14, 0);

    // Head
    const headMesh = new Mesh(new SphereGeometry(0.13, 6, 5), catMat);
    headMesh.position.set(0, 0, 0);

    // Ears: 2 small cones
    const earGeo = new ConeGeometry(0.045, 0.1, 4);
    const earL = new Mesh(earGeo, catMat);
    earL.position.set(-0.075, 0.1, 0);
    earL.rotation.z = -0.3;
    const earR = new Mesh(earGeo.clone(), catMat);
    earR.position.set(0.075, 0.1, 0);
    earR.rotation.z = 0.3;

    // Eyes (tiny spheres, normally invisible — glow when awake)
    _catEyeL = new Mesh(new SphereGeometry(0.022, 4, 3), eyeMatL);
    _catEyeL.position.set(-0.045, 0.02, 0.11);
    _catEyeR = new Mesh(new SphereGeometry(0.022, 4, 3), eyeMatR);
    _catEyeR.position.set(0.045, 0.02, 0.11);

    // Tail: thin curved cylinder approximation
    const tail = new Mesh(new CylinderGeometry(0.025, 0.015, 0.35, 4), catMat);
    tail.position.set(0.18, 0.12, -0.15);
    tail.rotation.z = 0.8;
    tail.rotation.x = 0.4;

    _catHead.add(headMesh, earL, earR, _catEyeL, _catEyeR);
    _catHead.position.set(0.2, 0.22, 0.1); // head resting on body
    _catHead.rotation.z = 0.5; // tilted in sleep

    _catGroup.add(cushion, _catBody, _catHead, tail);
    _catGroup.position.set(-1.5, 0.15, -2);
    scene.add(_catGroup);
  }

  // C432 — floating hourglass
  {
    _hourglassGroup = new Group();

    const frameMat = new MeshBasicMaterial({ color: 0x0a2a14 });
    const glassMat = new MeshBasicMaterial({ color: 0x0d2a14, transparent: true, opacity: 0.35, side: DoubleSide });

    const topBulb = new Mesh(new SphereGeometry(0.18, 8, 6), glassMat.clone());
    topBulb.scale.set(1, 0.7, 1);
    topBulb.position.set(0, 0.22, 0);

    const botBulb = new Mesh(new SphereGeometry(0.18, 8, 6), glassMat.clone());
    botBulb.scale.set(1, 0.7, 1);
    botBulb.position.set(0, -0.22, 0);

    const neck = new Mesh(new CylinderGeometry(0.018, 0.018, 0.1, 6), glassMat.clone());
    neck.position.set(0, 0, 0);

    const ringGeo = new TorusGeometry(0.2, 0.025, 5, 14);
    const topRing = new Mesh(ringGeo, frameMat);
    topRing.position.set(0, 0.42, 0);
    const botRing = new Mesh(ringGeo.clone(), frameMat);
    botRing.position.set(0, -0.42, 0);
    const midRing = new Mesh(new TorusGeometry(0.03, 0.02, 4, 8), frameMat);
    midRing.position.set(0, 0, 0);

    for (let pi = 0; pi < 3; pi++) {
      const angle = (pi / 3) * Math.PI * 2;
      const pillar = new Mesh(new CylinderGeometry(0.015, 0.015, 0.84, 4), frameMat);
      pillar.position.set(Math.cos(angle) * 0.19, 0, Math.sin(angle) * 0.19);
      _hourglassGroup.add(pillar);
    }

    for (let si = 0; si < 8; si++) {
      const sand = new Mesh(
        new SphereGeometry(0.013, 3, 2),
        new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.0 })
      );
      sand.position.set(0, 0.18 - si * 0.045, 0);
      _sandParticles.push(sand);
      _sandVel.push({ y: -0.3 - si * 0.02, life: si * 0.15, maxLife: 0.8 + Math.random() * 0.3 });
      _hourglassGroup.add(sand);
    }

    _hourglassLight = new PointLight(0x33ff66, 0.1, 2.5);
    _hourglassLight.position.set(0, 0, 0);

    _hourglassGroup.add(topBulb, botBulb, neck, topRing, botRing, midRing, _hourglassLight);
    _hourglassGroup.position.set(-0.5, 1.8, -3.5);
    scene.add(_hourglassGroup);
  }

  // C436 — floor summoning rune circle
  {
    _runeCircleGroup = new Group();

    const dimMat = (): MeshBasicMaterial => new MeshBasicMaterial({ color: 0x0d2a14, transparent: true, opacity: 0.35, depthWrite: false });
    const glowMat = (): MeshBasicMaterial => new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.25, depthWrite: false });

    // 3 concentric rings using RingGeometry
    const ringRadii = [0.6, 1.0, 1.35];
    ringRadii.forEach((r) => {
      const ring = new Mesh(
        new RingGeometry(r - 0.02, r + 0.02, 32),
        dimMat()
      );
      ring.rotation.x = -Math.PI / 2;
      ring.position.set(0, 0, 0);
      _runeRings.push(ring);
      _runeCircleGroup!.add(ring);
    });

    // 6-pointed star — 6 thin diamond shapes radiating from center
    for (let si = 0; si < 6; si++) {
      const angle = (si / 6) * Math.PI * 2;
      const spoke = new Mesh(
        new PlaneGeometry(0.04, 1.2),
        dimMat()
      );
      spoke.rotation.x = -Math.PI / 2;
      spoke.rotation.z = angle;
      spoke.position.set(0, 0, 0);
      _runeRings.push(spoke);
      _runeCircleGroup!.add(spoke);
    }

    // 12 rune tick marks at the outer ring
    for (let ti = 0; ti < 12; ti++) {
      const angle = (ti / 12) * Math.PI * 2;
      const tick = new Mesh(
        new PlaneGeometry(0.035, 0.1),
        dimMat()
      );
      tick.rotation.x = -Math.PI / 2;
      tick.rotation.z = angle;
      tick.position.set(Math.cos(angle) * 1.35, 0, Math.sin(angle) * 1.35);
      _runeRings.push(tick);
      _runeCircleGroup!.add(tick);
    }

    // Central glow disc
    const centerDisc = new Mesh(
      new CircleGeometry(0.15, 12),
      glowMat()
    );
    centerDisc.rotation.x = -Math.PI / 2;
    _runeRings.push(centerDisc);
    _runeCircleGroup.add(centerDisc);

    // Light
    _runeCircleLight = new PointLight(0x33ff66, 0.05, 4.0);
    _runeCircleLight.position.set(0, 0.3, 0);
    _runeCircleGroup.add(_runeCircleLight);

    _runeCircleGroup.position.set(0, 0.01, -1);
    scene.add(_runeCircleGroup);
  }

  // C441 — celestial star map parchment
  {
    starMapGroup441 = new Group();
    starMapGroup441.position.set(-2.8, 2.4, -3.8);
    starMapGroup441.rotation.set(0, Math.PI * 0.15, 0);

    // Parchment backing
    const parchBacking = new Mesh(
      new PlaneGeometry(1.4, 1.0),
      new MeshBasicMaterial({ color: 0x020f04, transparent: true, opacity: 0.85 })
    );
    starMapGroup441.add(parchBacking);

    // Border frame — 4 thin strips: top, bottom, left, right
    const borderMat = new MeshBasicMaterial({ color: 0x0d2a14 });
    const borderDefs: Array<[number, number, number, number, number, number]> = [
      [1.4, 0.04, 0.04,  0,  0.52, 0],  // top
      [1.4, 0.04, 0.04,  0, -0.52, 0],  // bottom
      [0.04, 1.0, 0.04, -0.72, 0, 0],   // left
      [0.04, 1.0, 0.04,  0.72, 0, 0],   // right
    ];
    for (const [bw, bh, bd, bx, by, bz] of borderDefs) {
      const strip = new Mesh(new BoxGeometry(bw, bh, bd), borderMat);
      strip.position.set(bx, by, bz + 0.01);
      starMapGroup441.add(strip);
    }

    // 15 star dot positions (u,v in [-0.6..0.6, -0.45..0.45])
    const starPositions: Array<[number, number]> = [
      [-0.42, 0.30], [-0.10, 0.38], [ 0.25, 0.32], [ 0.50, 0.20], [ 0.40, -0.05],
      [ 0.15, -0.30], [-0.20, -0.38], [-0.50, -0.18], [-0.55, 0.05], [ 0.00, 0.10],
      [-0.28, 0.10], [ 0.30, 0.08], [ 0.55, -0.30], [-0.05, -0.10], [ 0.18, 0.38],
    ];
    const starGeo = new SphereGeometry(0.018, 4, 4);
    for (const [sx, sy] of starPositions) {
      const dot = new Mesh(
        starGeo,
        new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 1.0 })
      );
      dot.position.set(sx, sy, 0.02);
      starDots441.push(dot);
      starMapGroup441.add(dot);
    }

    // 6 constellation lines — connect groups of 3-4 stars by index
    const constellationSets: Array<number[]> = [
      [0, 1, 2, 3],   // top arc
      [4, 9, 6],      // center-right to center-bottom-left
      [5, 13, 11],    // bottom mid
      [7, 8, 0],      // left side
      [10, 9, 14],    // inner cluster
      [3, 4, 12],     // right column
    ];
    const lineMat = new LineBasicMaterial({ color: 0x1a8833, transparent: true, opacity: 0.5 });
    for (const indices of constellationSets) {
      const points: Vector3[] = indices.map(idx => {
        const [sx, sy] = starPositions[idx];
        return new Vector3(sx, sy, 0.015);
      });
      const lineGeo = new BufferGeometry().setFromPoints(points);
      const line = new Line(lineGeo, lineMat);
      starMapGroup441.add(line);
    }

    // Ambient point light at parchment center, offset toward viewer
    const starLight = new PointLight(0x33ff66, 0.08, 3.0);
    starLight.position.set(0, 0, 0.3);
    starMapGroup441.add(starLight);

    scene.add(starMapGroup441);
  }

  // C447 — enchanted mirror
  {
    mirrorGroup447 = new Group();
    mirrorGroup447.position.set(3.2, 2.2, -2.0);
    mirrorGroup447.rotation.set(0, -Math.PI * 0.5, 0);

    // Outer oval frame — TorusGeometry scaled to oval
    const outerFrameMesh = new Mesh(
      new TorusGeometry(0.55, 0.1, 6, 24),
      new MeshBasicMaterial({ color: 0x0d2a14 })
    );
    outerFrameMesh.scale.set(1.0, 1.35, 1.0);
    mirrorGroup447.add(outerFrameMesh);

    // Inner frame decoration
    const innerFrameMesh = new Mesh(
      new TorusGeometry(0.5, 0.04, 4, 20),
      new MeshBasicMaterial({ color: 0x1a8833 })
    );
    innerFrameMesh.scale.set(1.0, 1.35, 1.0);
    mirrorGroup447.add(innerFrameMesh);

    // Mirror surface
    mirrorSurfaceMat447 = new MeshBasicMaterial({ color: 0x010802, transparent: true, opacity: 0.9 });
    const mirrorSurface = new Mesh(new PlaneGeometry(0.85, 1.1), mirrorSurfaceMat447);
    mirrorSurface.position.set(0, 0, 0.02);
    mirrorGroup447.add(mirrorSurface);

    // Subtle surface glow plane
    const glowPlane = new Mesh(
      new PlaneGeometry(0.7, 0.9),
      new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.04 })
    );
    glowPlane.position.set(0, 0, 0.03);
    mirrorGroup447.add(glowPlane);

    // Frame top ornament
    const topOrnament = new Mesh(
      new SphereGeometry(0.08, 6, 4),
      new MeshBasicMaterial({ color: 0x1a8833 })
    );
    topOrnament.position.set(0, 0.55 * 1.35 + 0.04, 0);
    mirrorGroup447.add(topOrnament);

    // Point light offset toward room
    mirrorLight447 = new PointLight(0x33ff66, 0.06, 4.0);
    mirrorLight447.position.set(0.3, 0, 0);
    mirrorGroup447.add(mirrorLight447);

    scene.add(mirrorGroup447);
  }

  // C452 — floating scrying orb
  {
    scryingOrbGroup452 = new Group();
    scryingOrbGroup452.position.set(0.5, 0.9, -1.5);

    // Pedestal: 3-tier stacked cylinders
    const pedestalBase = new Mesh(
      new CylinderGeometry(0.25, 0.3, 0.08, 8),
      new MeshBasicMaterial({ color: 0x0a1a10 })
    );
    pedestalBase.position.y = -0.55;
    scryingOrbGroup452.add(pedestalBase);

    const pedestalMid = new Mesh(
      new CylinderGeometry(0.1, 0.22, 0.25, 6),
      new MeshBasicMaterial({ color: 0x0a1a10 })
    );
    pedestalMid.position.y = -0.38;
    scryingOrbGroup452.add(pedestalMid);

    const pedestalTop = new Mesh(
      new CylinderGeometry(0.2, 0.12, 0.06, 8),
      new MeshBasicMaterial({ color: 0x0d2a14 })
    );
    pedestalTop.position.y = -0.22;
    scryingOrbGroup452.add(pedestalTop);

    // Crystal orb outer shell (transparent dark glass)
    const orbOuter = new Mesh(
      new SphereGeometry(0.2, 12, 10),
      new MeshBasicMaterial({ color: 0x0a2a14, transparent: true, opacity: 0.55 })
    );
    scryingOrbMat452 = orbOuter.material as MeshBasicMaterial;
    scryingOrbGroup452.add(orbOuter);

    // Inner glow core (smaller bright sphere inside)
    const orbCore = new Mesh(
      new SphereGeometry(0.1, 8, 8),
      new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.6 })
    );
    scryingOrbGroup452.add(orbCore);

    // Orbit ring (thin torus around orb equator)
    const orbitRing = new Mesh(
      new TorusGeometry(0.22, 0.015, 4, 24),
      new MeshBasicMaterial({ color: 0x1a8833, transparent: true, opacity: 0.6 })
    );
    orbitRing.rotation.x = Math.PI * 0.3;
    scryingOrbGroup452.add(orbitRing);

    // PointLight at orb center
    scryingOrbLight452 = new PointLight(0x33ff66, 0.35, 5.0);
    scryingOrbGroup452.add(scryingOrbLight452);

    scene.add(scryingOrbGroup452);
  }

  // C457 — magical stone fireplace (back wall, centered)
  {
    fireplaceGroup457 = new Group();
    fireplaceGroup457.position.set(0, 0, -4.5);

    // Stone surround: left pillar, right pillar, lintel
    const leftPillar = new Mesh(
      new BoxGeometry(0.3, 1.6, 0.3),
      new MeshBasicMaterial({ color: 0x0a1a10 })
    );
    leftPillar.position.set(-0.85, 0.8, 0);
    fireplaceGroup457.add(leftPillar);

    const rightPillar = new Mesh(
      new BoxGeometry(0.3, 1.6, 0.3),
      new MeshBasicMaterial({ color: 0x0a1a10 })
    );
    rightPillar.position.set(0.85, 0.8, 0);
    fireplaceGroup457.add(rightPillar);

    const lintel = new Mesh(
      new BoxGeometry(2.0, 0.25, 0.3),
      new MeshBasicMaterial({ color: 0x0a1a10 })
    );
    lintel.position.set(0, 1.75, 0);
    fireplaceGroup457.add(lintel);

    // Mantelpiece (wide shelf above lintel)
    const mantel = new Mesh(
      new BoxGeometry(2.4, 0.1, 0.5),
      new MeshBasicMaterial({ color: 0x0d2a14 })
    );
    mantel.position.set(0, 1.92, 0.1);
    fireplaceGroup457.add(mantel);

    // Hearth floor (dark slab)
    const hearth = new Mesh(
      new BoxGeometry(1.5, 0.08, 0.6),
      new MeshBasicMaterial({ color: 0x020f04 })
    );
    hearth.position.set(0, 0.04, 0.2);
    fireplaceGroup457.add(hearth);

    // Back wall of fireplace opening
    const backWall = new Mesh(
      new BoxGeometry(1.4, 1.6, 0.06),
      new MeshBasicMaterial({ color: 0x010802 })
    );
    backWall.position.set(0, 0.8, -0.1);
    fireplaceGroup457.add(backWall);

    // 3 logs
    for (let i = 0; i < 3; i++) {
      const log = new Mesh(
        new CylinderGeometry(0.055, 0.07, 1.0, 6),
        new MeshBasicMaterial({ color: 0x020f04 })
      );
      log.rotation.z = Math.PI * 0.5;
      log.position.set(-0.3 + i * 0.3, 0.1, 0.1);
      fireplaceGroup457.add(log);
    }

    // 4 flame cones (staggered sizes)
    const flameDefs457 = [
      { h: 0.9,  r: 0.22, x: -0.2,  y: 0.15 },
      { h: 1.3,  r: 0.18, x:  0.1,  y: 0.15 },
      { h: 0.7,  r: 0.15, x:  0.35, y: 0.15 },
      { h: 1.0,  r: 0.12, x: -0.4,  y: 0.15 },
    ];
    flameDefs457.forEach((def) => {
      const flame = new Mesh(
        new ConeGeometry(def.r, def.h, 6),
        new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.75 })
      );
      flame.position.set(def.x, def.y + def.h / 2, 0.1);
      fireplaceGroup457!.add(flame);
      fireplaceFlames457.push(flame);
    });

    // 8 spark particles
    for (let i = 0; i < 8; i++) {
      const spark = new Mesh(
        new SphereGeometry(0.02, 3, 3),
        new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.9 })
      );
      spark.position.set((Math.random() - 0.5) * 0.8, 0.2 + Math.random() * 0.8, 0.1);
      spark.userData = {
        vx: (Math.random() - 0.5) * 0.3,
        vy: 0.5 + Math.random() * 0.5,
        phase: Math.random() * Math.PI * 2,
      };
      fireplaceGroup457!.add(spark);
      fireplaceSparks457.push(spark);
    }

    // Dynamic firelight
    fireplaceLight457 = new PointLight(0x33ff66, 1.2, 8.0);
    fireplaceLight457.position.set(0, 0.8, 0.4);
    fireplaceGroup457.add(fireplaceLight457);

    scene.add(fireplaceGroup457);
  }

  // C462 — floating runic calendar disc
  {
    calendarDisc462 = new Group();
    calendarDisc462.position.set(-1.5, 2.8, -3.5);

    // Stone pedestal below disc
    const discPedestal = new Mesh(
      new CylinderGeometry(0.12, 0.18, 1.8, 6),
      new MeshBasicMaterial({ color: 0x0a1a10 })
    );
    discPedestal.position.y = -1.2;
    calendarDisc462!.add(discPedestal);

    // Main disc face (cylinder, very flat)
    const discFace = new Mesh(
      new CylinderGeometry(0.9, 0.9, 0.1, 16),
      new MeshBasicMaterial({ color: 0x0a1a10 })
    );
    calendarDisc462!.add(discFace);

    // Outer ring (torus around disc edge)
    const outerRing = new Mesh(
      new TorusGeometry(0.92, 0.05, 4, 20),
      new MeshBasicMaterial({ color: 0x0d2a14 })
    );
    outerRing.rotation.x = Math.PI * 0.5;
    calendarDisc462!.add(outerRing);

    // Inner ring
    const innerRing = new Mesh(
      new TorusGeometry(0.55, 0.03, 4, 16),
      new MeshBasicMaterial({ color: 0x1a8833 })
    );
    innerRing.rotation.x = Math.PI * 0.5;
    calendarDisc462!.add(innerRing);

    // 12 rune planes evenly spaced on the disc face
    for (let i = 0; i < 12; i++) {
      const angle = (i / 12) * Math.PI * 2;
      const rune = new Mesh(
        new PlaneGeometry(0.12, 0.18),
        new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.5 })
      );
      rune.position.set(Math.cos(angle) * 0.7, 0.07, Math.sin(angle) * 0.7);
      rune.rotation.x = -Math.PI * 0.5;
      calendarRunesMats462.push(rune.material as MeshBasicMaterial);
      calendarDisc462!.add(rune);
    }

    // Hub centre sphere
    const hub = new Mesh(
      new SphereGeometry(0.1, 6, 6),
      new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.7 })
    );
    hub.position.y = 0.08;
    calendarDisc462!.add(hub);

    // PointLight
    calendarDiscLight462 = new PointLight(0x33ff66, 0.3, 6.0);
    calendarDiscLight462.position.y = 0.3;
    calendarDisc462!.add(calendarDiscLight462);

    scene.add(calendarDisc462);
  }

  // C438 — potion bottle shelf
  {
    _potionShelfGroup = new Group();

    // Shelf plank
    const shelfMat = new MeshBasicMaterial({ color: 0x0a1a10 });
    const shelf = new Mesh(new BoxGeometry(1.4, 0.06, 0.22), shelfMat);
    shelf.position.set(0, 0, 0);
    _potionShelfGroup.add(shelf);

    // Wall bracket supports: 2 small blocks
    const brL = new Mesh(new BoxGeometry(0.06, 0.2, 0.18), shelfMat);
    brL.position.set(-0.6, -0.13, 0);
    const brR = new Mesh(new BoxGeometry(0.06, 0.2, 0.18), shelfMat);
    brR.position.set(0.6, -0.13, 0);
    _potionShelfGroup.add(brL, brR);

    // 5 bottles with varying shapes
    const bottleDefs = [
      { x: -0.52, bottleH: 0.38, bottleR: 0.07,  fillH: 0.22, fillR: 0.055 },
      { x: -0.25, bottleH: 0.5,  bottleR: 0.055, fillH: 0.35, fillR: 0.04  },
      { x: 0,     bottleH: 0.42, bottleR: 0.08,  fillH: 0.15, fillR: 0.065 },
      { x: 0.25,  bottleH: 0.32, bottleR: 0.065, fillH: 0.25, fillR: 0.05  },
      { x: 0.52,  bottleH: 0.48, bottleR: 0.06,  fillH: 0.42, fillR: 0.048 },
    ];

    const glassMat = new MeshBasicMaterial({ color: 0x0a2a14, transparent: true, opacity: 0.5 });

    bottleDefs.forEach((def, i) => {
      const baseY = 0.03 + def.bottleH / 2;

      // Bottle body
      const bottle = new Mesh(
        new CylinderGeometry(def.bottleR * 0.85, def.bottleR, def.bottleH, 8),
        glassMat.clone()
      );
      bottle.position.set(def.x, baseY, 0);

      // Bottle neck
      const neck = new Mesh(
        new CylinderGeometry(def.bottleR * 0.3, def.bottleR * 0.6, def.bottleH * 0.25, 6),
        glassMat.clone()
      );
      neck.position.set(def.x, baseY + def.bottleH / 2 * 0.7, 0);

      // Cork
      const cork = new Mesh(
        new CylinderGeometry(def.bottleR * 0.28, def.bottleR * 0.28, 0.04, 5),
        shelfMat
      );
      cork.position.set(def.x, baseY + def.bottleH * 0.62, 0);

      // Liquid fill (inside bottle, glowing)
      const liquidMat = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.8 });
      const liquid = new Mesh(
        new CylinderGeometry(def.fillR * 0.9, def.fillR, def.fillH, 8),
        liquidMat
      );
      liquid.position.set(def.x, 0.03 + def.fillH / 2, 0);
      _potionLiquids.push(liquid);

      // Per-bottle glow light (sparse — every other)
      if (i % 2 === 0) {
        const pLight = new PointLight(0x33ff66, 0.06, 1.2);
        pLight.position.set(def.x, baseY, 0.15);
        _potionLights.push(pLight);
        _potionShelfGroup!.add(pLight);
      }

      _potionShelfGroup!.add(bottle, neck, cork, liquid);
    });

    _potionShelfGroup.position.set(3, 1.5, -2.5);
    scene.add(_potionShelfGroup);
  }

  // C361: enchanted mirror portal — tall oval frame leaning against back wall (x=2.5, y=1.2, z=-4.5)
  {
    mirrorGroup361 = new Group();

    // Oval frame — torus scaled tall (1.0 × 1.4) to form an oval ring
    const frameMat361 = new MeshStandardMaterial({ color: 0x1a3a1a, roughness: 0.8, metalness: 0.3, flatShading: true });
    const frameGeo = new TorusGeometry(0.65, 0.08, 8, 20);
    const frame = new Mesh(frameGeo, frameMat361);
    frame.scale.set(1.0, 1.4, 1.0);
    mirrorGroup361.add(frame);

    // Mirror surface — PlaneGeometry subdivided for vertex ripple animation
    const surfaceGeo = new PlaneGeometry(1.1, 1.5, 10, 14);
    const surfaceMat = new MeshStandardMaterial({
      color: 0x051505,
      emissive: new (frameMat361.emissive.constructor as new (hex: number) => typeof frameMat361.emissive)(0x0d4420),
      emissiveIntensity: 0.15,
      transparent: true,
      opacity: 0.82,
      roughness: 0.1,
      metalness: 0.6,
    });
    surfaceMat.emissive.setHex(0x0d4420);
    mirrorSurface361 = new Mesh(surfaceGeo, surfaceMat);
    mirrorGroup361.add(mirrorSurface361);

    // Green glow light
    mirrorLight361 = new PointLight(0x33ff66, 0.12, 3.0);
    mirrorLight361.position.set(0, 0, 0.5);
    mirrorGroup361.add(mirrorLight361);

    // Position mirror against back wall, slightly tilted forward
    mirrorGroup361.position.set(2.5, 1.2, -4.5);
    mirrorGroup361.rotation.x = -0.08;

    scene.add(mirrorGroup361);
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

  // C277: scrying pool — shallow dark bowl + pulsing green vision disc
  // Floor top surface at FLOOR_Y = -4.85. Bowl rim at -4.85 + 0.06 = -4.79.
  // Position (2, _, -6): 1 unit in front of cauldron (z=-7), clear of crystal ball (x=5) and rune rings (x=0,z=-8).
  {
    const POOL_Y = -4.85 + 0.06;
    const poolMat = new MeshBasicMaterial({ color: 0x050c05 });
    const pool = new Mesh(new CylinderGeometry(0.8, 0.8, 0.12, 16), poolMat);
    pool.position.set(2, POOL_Y, -6);
    scene.add(pool);
    _scryingPoolMesh = pool;

    const visionMat = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.3 });
    const vision = new Mesh(new CircleGeometry(0.7, 16), visionMat);
    vision.rotation.x = -Math.PI / 2;
    vision.position.set(2, POOL_Y + 0.07, -6);
    scene.add(vision);
    _scryingVisionMesh = vision;

    const poolLight = new PointLight(0x33ff66, 0.4, 3);
    poolLight.position.set(2, POOL_Y + 0.5, -6);
    scene.add(poolLight);
  }

  // C284: astrolabe — 3 concentric torus rings mounted on back wall (z ≈ -9.75, back wall front face)
  // Position: left side of wall (-4, 0.5) — clear of window (right), door (centre), and mortar lines.
  {
    const ASTRO_X = -4;
    const ASTRO_Y = 0.5;
    const ASTRO_Z = -9.75; // flush against front face of back wall

    const ring1Mat = new MeshBasicMaterial({ color: 0x22aa55, transparent: true, opacity: 0.7 });
    const ring1 = new Mesh(new TorusGeometry(1.2, 0.04, 6, 32), ring1Mat);
    ring1.position.set(ASTRO_X, ASTRO_Y, ASTRO_Z);
    scene.add(ring1);
    _astroRing1 = ring1;

    const ring2Mat = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.8 });
    const ring2 = new Mesh(new TorusGeometry(0.8, 0.04, 6, 24), ring2Mat);
    ring2.position.set(ASTRO_X, ASTRO_Y, ASTRO_Z + 0.02);
    scene.add(ring2);
    _astroRing2 = ring2;

    const ring3Mat = new MeshBasicMaterial({ color: 0x1a8833, transparent: true, opacity: 0.9 });
    const ring3 = new Mesh(new TorusGeometry(0.4, 0.04, 6, 16), ring3Mat);
    ring3.position.set(ASTRO_X, ASTRO_Y, ASTRO_Z + 0.04);
    scene.add(ring3);
    _astroRing3 = ring3;

    const centerMat = new MeshBasicMaterial({ color: 0x33ff66 });
    const center = new Mesh(new SphereGeometry(0.08, 6, 4), centerMat);
    center.position.set(ASTRO_X, ASTRO_Y, ASTRO_Z + 0.06);
    scene.add(center);
  }

  // C292: skull shelf — shelf plank + 3 skulls (cranium + jaw) with green eye PointLights
  {
    const SHELF_COLOR = 0x1a1208;
    const BONE_COLOR  = 0xc8c0a8;
    const skullShelfGroup = new Group();

    // Shelf plank
    const shelfPlankMat = new MeshStandardMaterial({ color: SHELF_COLOR, roughness: 0.8, metalness: 0.1 });
    const shelfPlank = new Mesh(new BoxGeometry(1.4, 0.06, 0.2), shelfPlankMat);
    shelfPlank.position.set(-3.5, -2.8, -9.6);
    skullShelfGroup.add(shelfPlank);

    const skullDefs: Array<{ x: number; y: number; z: number; scale: number; rotY: number }> = [
      { x: -3.5, y: -2.6, z: -9.6, scale: 1.00, rotY:  0.0  }, // center
      { x: -3.8, y: -2.6, z: -9.6, scale: 0.90, rotY:  0.4  }, // left
      { x: -3.2, y: -2.6, z: -9.6, scale: 0.85, rotY: -0.3  }, // right
    ];

    const boneMat = new MeshStandardMaterial({ color: BONE_COLOR, roughness: 0.8, metalness: 0.1 });

    for (const sd of skullDefs) {
      const skullG = new Group();
      skullG.position.set(sd.x, sd.y, sd.z);
      skullG.scale.setScalar(sd.scale);
      skullG.rotation.y = sd.rotY;

      // Cranium
      const cranium = new Mesh(new SphereGeometry(0.14, 8, 6), boneMat);
      skullG.add(cranium);

      // Jaw — offset -0.07 Y below cranium centre
      const jaw = new Mesh(new BoxGeometry(0.14, 0.06, 0.12), boneMat);
      jaw.position.set(0, -0.07, 0);
      skullG.add(jaw);

      // Green eye glow — at eye level (+0.02 Y, -0.05 Z relative to cranium)
      const eyeLight = new PointLight(0x33ff66, 0.15, 1.0);
      eyeLight.position.set(0, 0.02, -0.05);
      cranium.add(eyeLight);
      _skullLights.push(eyeLight);

      skullShelfGroup.add(skullG);
    }

    scene.add(skullShelfGroup);
  }

  // C301: wall moss/algae patches — 5 flat planes on stone walls, breathing opacity
  {
    const mossDefs: Array<{ w: number; h: number; x: number; y: number; z: number; ry?: number; color: number; opacity: number }> = [
      { w: 1.2, h: 0.8, x: -6.5 + 0.001, y: -1.5, z: -8,   ry: Math.PI / 2,  color: 0x0a1f0a, opacity: 0.35 },
      { w: 0.9, h: 1.1, x: -6.5 + 0.001, y: -3.0, z: -6.5, ry: Math.PI / 2,  color: 0x0d2510, opacity: 0.28 },
      { w: 1.4, h: 0.6, x:  1.0,         y: -2.5, z: -10.5 + 0.001,            color: 0x091a09, opacity: 0.32 },
      { w: 0.7, h: 0.9, x:  6.5 - 0.001, y: -1.8, z: -7,   ry: -Math.PI / 2, color: 0x0c2010, opacity: 0.25 },
      { w: 1.0, h: 0.7, x: -2.0,         y: -3.5, z: -10.5 + 0.001,            color: 0x0a1a0a, opacity: 0.30 },
    ];
    for (const def of mossDefs) {
      const mat = new MeshBasicMaterial({ color: def.color, transparent: true, opacity: def.opacity, side: DoubleSide, depthWrite: false });
      const mesh = new Mesh(new PlaneGeometry(def.w, def.h), mat);
      mesh.position.set(def.x, def.y, def.z);
      if (def.ry !== undefined) mesh.rotation.y = def.ry;
      scene.add(mesh);
      _mossPatches.push(mesh);
    }
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

    // C316: steam wisps — rising, billowing, fading (cosmetic, gate under !lowFpsMode)
    if (!lowFpsMode) {
      for (const wm of _steamWisps) {
        const spd    = wm.userData['speed']  as number;
        const ph     = wm.userData['phase']  as number;
        const sx     = wm.userData['startX'] as number;
        const sz     = wm.userData['startZ'] as number;
        const driftX = wm.userData['driftX'] as number;
        const driftZ = wm.userData['driftZ'] as number;
        const progress = ((elapsedTime * spd + ph) % (Math.PI * 2)) / (Math.PI * 2);
        wm.position.y = -4.0 + progress * 3.5;
        wm.position.x = sx + Math.sin(elapsedTime * 0.4 + ph) * driftX * progress;
        wm.position.z = sz + Math.cos(elapsedTime * 0.35 + ph) * driftZ * progress;
        const s = 0.8 + progress * 1.8;
        wm.scale.setScalar(s);
        (wm.material as MeshBasicMaterial).opacity = (1 - progress) * 0.28;
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

    // C277: scrying pool vision — ripple opacity + scale breathe
    _scryingTime += dt;
    if (_scryingVisionMesh) {
      const mat = _scryingVisionMesh.material as MeshBasicMaterial;
      mat.opacity = 0.2 + Math.sin(_scryingTime * 1.1) * 0.15 + Math.sin(_scryingTime * 2.7) * 0.05;
      const scale = 0.95 + Math.sin(_scryingTime * 0.8) * 0.06;
      _scryingVisionMesh.scale.set(scale, scale, 1);
    }

    // C284: astrolabe ring rotation — 3 rings at different speeds/directions (cosmetic, gate under !lowFpsMode)
    if (!lowFpsMode) {
      _astroTime += dt;
      if (_astroRing1) _astroRing1.rotation.z += dt * 0.08;   // outer: very slow clockwise
      if (_astroRing2) _astroRing2.rotation.z -= dt * 0.15;   // middle: counter-clockwise
      if (_astroRing3) _astroRing3.rotation.z += dt * 0.25;   // inner: faster clockwise
    }

    // C292: skull shelf eye glow pulse — staggered per skull
    _skullLights.forEach((light, i) => {
      light.intensity = 0.08 + Math.sin(elapsedTime * 0.9 + i * 1.3) * 0.07;
    });

    // C301: moss/algae breathing opacity — imperceptibly slow sine pulse
    _mossPatches.forEach((patch, i) => {
      const mat = patch.material as MeshBasicMaterial;
      const base = [0.35, 0.28, 0.32, 0.25, 0.30][i];
      mat.opacity = base + Math.sin(elapsedTime * 0.18 + i * 0.7) * 0.04;
    });

    // C328: bookmark glow pulse — 0.4 + sin(t*0.8)*0.3 range (cosmetic, always-on, cheap)
    if (_bookmarkMesh) {
      _bookmarkTime += dt;
      (_bookmarkMesh.material as MeshBasicMaterial).opacity = 0.4 + Math.sin(_bookmarkTime * 0.8) * 0.3;
    }

    // C335: alchemy floor symbols — sequential glow pulse (4 symbols, 3s offset each)
    if (!lowFpsMode && _alchemySymbolMeshes.length > 0) {
      _alchemyTime += dt;
      const PEAK_OFFSETS = [0, 3, 6, 9]; // seconds — one symbol peaks every 3s
      // Mesh index ranges per symbol: sym0=[0], sym1=[1,2,3], sym2=[4,5,6], sym3=[7,8]
      const SYM_MESH_RANGES: Array<[number, number]> = [[0, 0], [1, 3], [4, 6], [7, 8]];
      const BASE_OPACITIES = [0.20, 0.18, 0.15, 0.16];
      for (let s = 0; s < 4; s++) {
        const offset = PEAK_OFFSETS[s]!;
        const sinVal = Math.sin((_alchemyTime - offset) * 0.5);
        const opacity = BASE_OPACITIES[s]! + sinVal * 0.08;
        const [rStart, rEnd] = SYM_MESH_RANGES[s]!;
        for (let mi = rStart; mi <= rEnd; mi++) {
          const m = _alchemySymbolMeshes[mi];
          if (m) (m.material as MeshBasicMaterial).opacity = Math.max(0.04, Math.min(1, opacity));
        }
        // Flare point light toward 0.15 at peak (sinVal≈1), fade to 0 at trough
        const light = _alchemyLights[s];
        if (light) {
          const lightTarget = Math.max(0, sinVal) * 0.15;
          light.intensity += (lightTarget - light.intensity) * Math.min(1, dt * 4);
        }
      }
    }

    // C343: map parchment opacity pulse — gentle sine breathe
    if (_mapParchment) {
      _mapParchmentTime += dt;
      (_mapParchment.material as MeshBasicMaterial).opacity = 0.30 + Math.sin(_mapParchmentTime * 0.5) * 0.05;
    }
    // C343: map scroll glow — very slow intensity drift
    if (_mapScrollLight) {
      _mapScrollLight.intensity = 0.06 + Math.sin(elapsedTime * 0.4) * 0.02;
    }

    // C347: candle arc flicker — per-candle independent phase (cosmetic, gate under !lowFpsMode)
    if (!lowFpsMode && _candleFlames.length > 0) {
      const t = elapsedTime;
      for (let i = 0; i < _candleFlames.length; i++) {
        const flame = _candleFlames[i]!;
        const scaleX = 0.8 + Math.sin(t * 7.3 + i * 1.2) * 0.3;
        const scaleY = 0.9 + Math.sin(t * 6.1 + i * 2.1) * 0.2;
        flame.scale.set(scaleX, scaleY, scaleX);
        flame.rotation.z = Math.sin(t * 4.2 + i * 1.7) * 0.12;
        const light = _candleLights[i];
        if (light) light.intensity = 0.15 + Math.sin(t * 8.5 + i * 2.3) * 0.1;
      }
    }

    // C355: herb bundle sway — slow pendulum motion per bundle (cosmetic, gate under !lowFpsMode)
    if (!lowFpsMode) {
      _herbBundles355.forEach((bundle, i) => {
        bundle.rotation.z = Math.sin(elapsedTime * 0.4 + i * 1.1) * 0.04;
        bundle.rotation.x = Math.sin(elapsedTime * 0.3 + i * 0.7) * 0.02;
      });
    }

    // C376: wind chime pendulum physics + chime flash (cosmetic, gate under !lowFpsMode)
    if (!lowFpsMode) {
      const ROD_LENGTHS_376 = [0.5, 0.65, 0.45, 0.7, 0.55];
      const ROD_OFFSETS_376 = [-0.18, -0.09, 0, 0.09, 0.18];
      const GRAVITY_376 = 2.5;
      const DAMPING_376 = 0.995;
      const PIVOT_X_376 = -1.5;
      const PIVOT_Y_376 = 3.2;
      const PIVOT_Z_376 = -2.5;
      _chimeRods376.forEach((rod, i) => {
        const len = ROD_LENGTHS_376[i]!;
        const xOff = ROD_OFFSETS_376[i]!;
        const prevAngle = _chimeAngles376[i]!;
        // Pendulum physics
        const accel = -GRAVITY_376 * Math.sin(_chimeAngles376[i]!) / len;
        _chimeVelocities376[i] = (_chimeVelocities376[i]! + accel * dt) * DAMPING_376;
        // Random nudge occasionally
        if (Math.random() < dt * 0.15) _chimeVelocities376[i] = _chimeVelocities376[i]! + (Math.random() - 0.5) * 0.4;
        _chimeAngles376[i] = _chimeAngles376[i]! + _chimeVelocities376[i]! * dt;
        // Update rod position — pivot at top, rod hangs down, swings in XZ plane
        rod.position.x = PIVOT_X_376 + xOff + Math.sin(_chimeAngles376[i]!) * len / 2;
        rod.position.y = PIVOT_Y_376 - Math.cos(_chimeAngles376[i]!) * len / 2;
        rod.rotation.z = _chimeAngles376[i]!;
        const light = _chimeLights376[i]!;
        light.position.x = PIVOT_X_376 + xOff + Math.sin(_chimeAngles376[i]!) * len;
        light.position.y = PIVOT_Y_376 - Math.cos(_chimeAngles376[i]!) * len;
        // Chime flash at swing reversal (velocity sign change near extremes)
        const crossedZero = prevAngle * _chimeAngles376[i]! < 0 && Math.abs(_chimeAngles376[i]!) > 0.05;
        const mat = rod.material as MeshStandardMaterial;
        if (crossedZero) {
          mat.emissiveIntensity = 0.25;
          light.intensity = 0.3;
        } else {
          mat.emissiveIntensity = Math.max(0.05, mat.emissiveIntensity * 0.85);
          light.intensity = Math.max(0.0, light.intensity * 0.85);
        }
      });
    }

    // C380: crystal orb nebula pulse + vision flare events
    if (!lowFpsMode) {
      _orbMeshes380.forEach((orb, i) => {
        const phase = orb.userData['phase'] as number;
        const pulse = 0.12 + Math.sin(elapsedTime * 0.7 + phase) * 0.06 + Math.sin(elapsedTime * 1.3 + phase * 2) * 0.03;
        (orb.material as MeshStandardMaterial).emissiveIntensity = pulse;
        if (_orbLights380[i]) _orbLights380[i]!.intensity = pulse * 0.8;
      });

      // Vision event timer
      _orbNextVision380 -= dt;
      if (_orbNextVision380 <= 0 && _orbVisionT380 < 0) {
        _orbVisionT380 = 0;
        _orbVisionIdx380 = Math.floor(Math.random() * 3);
        _orbNextVision380 = 12.0 + Math.random() * 6.0;
      }
      if (_orbVisionT380 >= 0) {
        _orbVisionT380 += dt;
        const vOrb = _orbMeshes380[_orbVisionIdx380];
        const vLight = _orbLights380[_orbVisionIdx380];
        if (vOrb && vLight) {
          if (_orbVisionT380 < 0.5) {
            const t = _orbVisionT380 / 0.5;
            (vOrb.material as MeshStandardMaterial).emissiveIntensity = 0.15 + t * 0.35;
            vLight.intensity = 0.10 + t * 0.40;
          } else if (_orbVisionT380 < 1.2) {
            const t = (_orbVisionT380 - 0.5) / 0.7;
            (vOrb.material as MeshStandardMaterial).emissiveIntensity = 0.50 - t * 0.35;
            vLight.intensity = 0.50 - t * 0.40;
          } else {
            _orbVisionT380 = -1;
          }
        }
      }
    }

    // C384: alchemical balance scale — pendulum tilt + spark events
    if (!lowFpsMode && _scaleArm384) {
      const tilt = Math.sin(elapsedTime * 0.4) * 0.12 + Math.sin(elapsedTime * 0.7) * 0.04;
      _scaleArm384.rotation.z = tilt;
      if (_scalePanLeft384) _scalePanLeft384.rotation.z = -tilt * 0.5;
      if (_scalePanRight384) _scalePanRight384.rotation.z = tilt * 0.5;

      _scaleNextSpark384 -= dt;
      if (_scaleNextSpark384 <= 0 && _scaleSparkT384 < 0) {
        _scaleSparkT384 = 0;
        _scaleNextSpark384 = 8.0 + Math.random() * 4.0;
      }
      if (_scaleSparkT384 >= 0 && _scaleSparkLight384) {
        _scaleSparkT384 += dt;
        if (_scaleSparkT384 < 0.2) {
          _scaleSparkLight384.intensity = (_scaleSparkT384 / 0.2) * 0.4;
        } else if (_scaleSparkT384 < 0.6) {
          _scaleSparkLight384.intensity = 0.4 - ((_scaleSparkT384 - 0.2) / 0.4) * 0.4;
        } else {
          _scaleSparkLight384.intensity = 0;
          _scaleSparkT384 = -1;
        }
      }
    }

    // C391: pendulum wall clock — physics swing, hand rotation, chime flash
    if (!lowFpsMode && _clockPendulum391) {
      const clockL = 0.4;
      const clockG = 9.8;
      const clockAccel = -(clockG / clockL) * Math.sin(_clockAngle391);
      _clockVelocity391 = (_clockVelocity391 + clockAccel * dt) * 0.999;
      if (Math.abs(_clockVelocity391) < 0.3 && Math.abs(_clockAngle391) < 0.05) {
        _clockVelocity391 = 1.2 * (Math.random() > 0.5 ? 1 : -1);
      }
      _clockAngle391 += _clockVelocity391 * dt;
      _clockPendulum391.rotation.z = _clockAngle391;

      if (_clockHourHand391) _clockHourHand391.rotation.z = -elapsedTime * 0.00145;
      if (_clockMinuteHand391) _clockMinuteHand391.rotation.z = -elapsedTime * 0.01745;

      _clockNextChime391 -= dt;
      if (_clockNextChime391 <= 0 && _clockChimeT391 < 0) {
        _clockChimeT391 = 0;
        _clockNextChime391 = 15.0 + Math.random() * 10.0;
        _clockVelocity391 *= 1.5;
      }
      if (_clockChimeT391 >= 0 && _clockChimeLight391) {
        _clockChimeT391 += dt;
        if (_clockChimeT391 < 0.2) {
          _clockChimeLight391.intensity = (_clockChimeT391 / 0.2) * 0.25;
        } else if (_clockChimeT391 < 0.4) {
          _clockChimeLight391.intensity = 0.25 - ((_clockChimeT391 - 0.2) / 0.2) * 0.25;
        } else {
          _clockChimeLight391.intensity = 0;
          _clockChimeT391 = -1;
        }
      }
    }

    // C396: floating magical parchment scroll — bob, unroll, read flash
    if (!lowFpsMode && _scrollGroup396 && _scrollFace396) {
      // Gentle floating bob
      _scrollGroup396.position.y = 1.8 + Math.sin(elapsedTime * 0.5) * 0.04;
      _scrollGroup396.rotation.y = 0.3 + Math.sin(elapsedTime * 0.2) * 0.06;

      // Unroll cycle (0→1→0 over 4s)
      _scrollUnrollT396 += dt * 0.25;
      const unroll396 = Math.sin(_scrollUnrollT396) * 0.5 + 0.5;
      _scrollFace396.scale.x = 0.3 + unroll396 * 0.7; // width varies as scroll unrolls

      // Read flash
      _scrollNextRead396 -= dt;
      if (_scrollNextRead396 <= 0 && _scrollReadT396 < 0) {
        _scrollReadT396 = 0;
        _scrollNextRead396 = 10.0 + Math.random() * 5.0;
      }
      if (_scrollReadT396 >= 0) {
        _scrollReadT396 += dt;
        const sMat = _scrollFace396.material as MeshStandardMaterial;
        if (_scrollReadT396 < 0.5) {
          sMat.emissiveIntensity = 0.08 + (_scrollReadT396 / 0.5) * 0.10;
        } else if (_scrollReadT396 < 1.0) {
          sMat.emissiveIntensity = 0.18 - ((_scrollReadT396 - 0.5) / 0.5) * 0.10;
        } else {
          sMat.emissiveIntensity = 0.08;
          _scrollReadT396 = -1;
        }
        if (_scrollLight396) _scrollLight396.intensity = (sMat.emissiveIntensity - 0.05) * 2;
      } else if (_scrollLight396) {
        _scrollLight396.intensity = 0.05 + Math.sin(elapsedTime * 0.7) * 0.02;
      }
    }

    // C401: spider web dew drops glistening + subtle sway
    if (_webGroup) {
      _webDewT += dt;
      for (let i = 0; i < _webDewSpheres.length; i++) {
        const dew = _webDewSpheres[i];
        (dew.material as MeshStandardMaterial).opacity = 0.55 + Math.sin(_webDewT * 1.5 + i * 0.4) * 0.25;
      }
      _webGroup.rotation.z = 0.15 + Math.sin(_webDewT * 0.3) * 0.02;
    }

    // C408: bubbling cauldron — potion ripple, light flicker, steam puffs
    if (_cauldronGroup) {
      _cauldronT += dt;
      _cauldronBubbleTimer += dt;
      if (_potionSurface) {
        (_potionSurface.material as MeshBasicMaterial).opacity =
          0.85 + Math.sin(_cauldronT * 4.5) * 0.1;
      }
      if (_cauldronLight) {
        _cauldronLight.intensity = 0.22 + Math.sin(_cauldronT * 7.2) * 0.07;
      }
      _steamPuffs.forEach((puff, i) => {
        const v = _steamVel[i];
        v.life += dt;
        if (v.life >= v.maxLife) {
          v.life = 0;
          puff.position.set((Math.random() - 0.5) * 0.2, 0.65, (Math.random() - 0.5) * 0.2);
        } else {
          const t = v.life / v.maxLife;
          puff.position.y += v.vy * dt;
          puff.scale.setScalar(0.5 + t * 1.5);
          const mat = puff.material as MeshBasicMaterial;
          mat.opacity = t < 0.3 ? (t / 0.3) * 0.25 : (1 - t) * 0.25;
        }
      });
    }

    // C413: floating spell tome — hover, rotate, page flip, glow pulse
    if (_tomeGroup) {
      _tomeT += dt;
      _tomePageFlipTimer += dt;

      // Hover float
      _tomeGroup.position.y = Math.sin(_tomeT * 0.7) * 0.06;
      // Slow rotation
      _tomeGroup.rotation.y = Math.sin(_tomeT * 0.25) * 0.15;

      // Light pulse
      if (_tomeGlowLight) {
        _tomeGlowLight.intensity = 0.18 + Math.sin(_tomeT * 2.1) * 0.06;
      }

      // Page flip event trigger
      if (_tomePageFlipTimer >= _tomePageFlipDur) {
        _tomePageFlipTimer = 0;
        _tomePageFlipDur = 4 + Math.random() * 6;
      }
      // Animate pages during flip (first 0.6s of cycle)
      if (_tomePageL && _tomePageR) {
        if (_tomePageFlipTimer < 0.6) {
          const ft = _tomePageFlipTimer / 0.6;
          _tomePageL.rotation.y = 0.15 + Math.sin(ft * Math.PI) * 0.4;
          _tomePageR.rotation.y = -0.15 - Math.sin(ft * Math.PI) * 0.4;
          if (_tomeGlowLight) _tomeGlowLight.intensity = 0.35 + Math.sin(ft * Math.PI) * 0.25;
        }
      }
    }

    // C418: suspended astrolabe — multi-ring rotation + gentle sway
    if (_astroGroup) {
      _astroT += dt;
      if (_astroRingOuter) _astroRingOuter.rotation.y = _astroT * 0.3;
      if (_astroRingMid) _astroRingMid.rotation.y = _astroT * -0.5;
      if (_astroRingInner) _astroRingInner.rotation.x = _astroT * 0.7;
      _astroGroup.rotation.z = Math.sin(_astroT * 0.2) * 0.08;
    }

    // C424: ceiling star projector — twinkle + slow rotation + light pulse
    if (_starProjGroup) {
      _starProjT += dt;
      _starProjGroup.rotation.y = _starProjT * 0.015;
      for (let si = 0; si < _starDots.length; si++) {
        const dot = _starDots[si];
        const mat = dot.material as MeshBasicMaterial;
        mat.opacity = 0.5 + 0.3 * Math.sin(_starProjT * 1.5 + si * 0.7);
      }
      if (_starProjLight) {
        _starProjLight.intensity = 0.06 + 0.04 * Math.sin(_starProjT * 1.2);
      }
    }

    // C428: sleeping familiar cat — breathing + wake animation
    if (_catGroup && _catBody) {
      _catT += dt;
      _catWakeTimer += dt;

      // Breathing: slow body scale pulse
      const breath = 1.0 + Math.sin(_catT * 0.9) * 0.035;
      _catBody.scale.set(1.4 * breath, 0.75, 1.1 * breath);

      // Wake event
      if (_catWakeTimer >= _catNextWake) {
        _catWakeTimer = 0;
        _catNextWake = 20 + Math.random() * 15;
      }

      // Wake phase: 0-0.5s open eyes, 0.5-3s awake, 3-4s close eyes
      const wakePhase = _catWakeTimer;
      let eyeOpacity = 0;
      if (wakePhase < 0.5) {
        eyeOpacity = wakePhase / 0.5;
        if (_catHead) _catHead.rotation.y = -(wakePhase / 0.5) * 0.4;
      } else if (wakePhase < 3.0) {
        eyeOpacity = 1.0;
        if (_catHead) _catHead.rotation.y = -0.4 + Math.sin(wakePhase * 0.8) * 0.3;
      } else if (wakePhase < 4.0) {
        eyeOpacity = 1.0 - (wakePhase - 3.0);
        if (_catHead) _catHead.rotation.y = -(1.0 - (wakePhase - 3.0)) * 0.3;
      } else {
        if (_catHead) _catHead.rotation.y = 0;
      }

      if (_catEyeL) (_catEyeL.material as MeshBasicMaterial).opacity = eyeOpacity;
      if (_catEyeR) (_catEyeR.material as MeshBasicMaterial).opacity = eyeOpacity;
    }

    // C432: floating hourglass update
    if (_hourglassGroup) {
      _hourglassT += dt;
      _hourglassFlipTimer += dt;

      _hourglassGroup.position.y = 1.8 + Math.sin(_hourglassT * 0.55) * 0.08;
      _hourglassGroup.rotation.y = _hourglassT * 0.2;

      if (_hourglassFlipTimer >= _hourglassNextFlip && !_hourglassFlipping) {
        _hourglassFlipping = true;
        _hourglassFlipTimer = 0;
        _hourglassNextFlip = 20 + Math.random() * 15;
      }
      if (_hourglassFlipping) {
        _hourglassGroup.rotation.z += dt * 3.0;
        if (_hourglassGroup.rotation.z >= Math.PI) {
          _hourglassGroup.rotation.z = 0;
          _hourglassFlipping = false;
        }
      }

      _sandParticles.forEach((sand, i) => {
        const vel = _sandVel[i];
        vel.life += dt;
        if (vel.life >= vel.maxLife) {
          vel.life = 0;
          sand.position.set((Math.random() - 0.5) * 0.02, 0.18, (Math.random() - 0.5) * 0.02);
        } else {
          sand.position.y += vel.y * dt;
          const t = vel.life / vel.maxLife;
          (sand.material as MeshBasicMaterial).opacity = t < 0.2 ? (t / 0.2) * 0.9 : (1 - t) * 0.9;
        }
      });

      if (_hourglassLight) {
        _hourglassLight.intensity = 0.08 + Math.sin(_hourglassT * 1.8) * 0.04;
      }
    }

    // C436 — floor summoning rune circle update
    if (_runeCircleGroup) {
      _runeCircleT += dt;
      _runeActivateTimer += dt;

      // Trigger activation
      if (_runeActivateTimer >= _runeNextActivate && !_runeActivating) {
        _runeActivating = true;
        _runeActiveDur = 0;
        _runeActivateTimer = 0;
        _runeNextActivate = 25 + Math.random() * 20;
      }

      let baseOpacity: number;
      if (_runeActivating) {
        _runeActiveDur += dt;
        if (_runeActiveDur > 4.0) _runeActivating = false;
        // Pulse: rise 0-0.5s, hold shimmer 0.5-3s, fade 3-4s
        const at = _runeActiveDur;
        if (at < 0.5) baseOpacity = (at / 0.5) * 0.8;
        else if (at < 3.0) baseOpacity = 0.8 + Math.sin(at * 5) * 0.15;
        else baseOpacity = (1.0 - (at - 3.0)) * 0.8;
        if (_runeCircleLight) _runeCircleLight.intensity = baseOpacity * 0.4;
        // Slow rotation when active
        _runeCircleGroup.rotation.y = _runeCircleT * 0.3;
      } else {
        baseOpacity = 0.25 + Math.sin(_runeCircleT * 0.7) * 0.08;
        if (_runeCircleLight) _runeCircleLight.intensity = 0.04 + Math.sin(_runeCircleT * 0.5) * 0.02;
        // Very slow idle rotation
        _runeCircleGroup.rotation.y = _runeCircleT * 0.04;
      }

      _runeRings.forEach((el, i) => {
        const mat = el.material as MeshBasicMaterial;
        mat.opacity = baseOpacity * (0.85 + Math.sin(_runeCircleT * 1.2 + i * 0.4) * 0.15);
      });
    }

    // C447 — enchanted mirror update
    if (mirrorGroup447) {
      mirrorT447 += dt;
      mirrorFlashTimer447 -= dt;

      // Subtle surface swirl via opacity breathing
      if (mirrorSurfaceMat447 && !mirrorFlashing447) {
        mirrorSurfaceMat447.opacity = 0.88 + 0.06 * Math.sin(mirrorT447 * 0.7);
      }

      // Trigger vision flash
      if (mirrorFlashTimer447 <= 0) {
        mirrorFlashTimer447 = 20 + Math.random() * 15;
        mirrorFlashing447 = true;
        mirrorFlashT447 = 0;
        window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'shimmer' } }));
      }

      // Flash animation: 0-0.3s brighten, 0.3-1.2s fade
      if (mirrorFlashing447) {
        mirrorFlashT447 += dt;
        if (mirrorFlashT447 < 0.3) {
          const p = mirrorFlashT447 / 0.3;
          if (mirrorSurfaceMat447) mirrorSurfaceMat447.opacity = 0.9 + 0.1 * p;
          if (mirrorLight447) mirrorLight447.intensity = 0.06 + 0.5 * p;
        } else if (mirrorFlashT447 < 1.2) {
          const p = (mirrorFlashT447 - 0.3) / 0.9;
          if (mirrorSurfaceMat447) mirrorSurfaceMat447.opacity = 1.0 - 0.12 * p;
          if (mirrorLight447) mirrorLight447.intensity = 0.56 - 0.5 * p;
        } else {
          mirrorFlashing447 = false;
          if (mirrorLight447) mirrorLight447.intensity = 0.06;
        }
      }
    }

    // C452 — floating scrying orb update
    scryingOrbT452 += dt;
    scryingOrbVisionTimer452 -= dt;

    if (scryingOrbGroup452) {
      // Levitation: bob up and down
      scryingOrbGroup452.position.y = 0.9 + 0.08 * Math.sin(scryingOrbT452 * 0.9);
      // Slow rotation
      scryingOrbGroup452.rotation.y = scryingOrbT452 * 0.2;
    }

    // Outer orb opacity breathe
    if (scryingOrbMat452 && !scryingOrbVisionActive452) {
      scryingOrbMat452.opacity = 0.45 + 0.15 * Math.sin(scryingOrbT452 * 1.4);
    }

    // Light breathe
    if (scryingOrbLight452 && !scryingOrbVisionActive452) {
      scryingOrbLight452.intensity = 0.3 + 0.1 * Math.sin(scryingOrbT452 * 1.8);
    }

    // Trigger vision
    if (scryingOrbVisionTimer452 <= 0) {
      scryingOrbVisionTimer452 = 15 + Math.random() * 10;
      scryingOrbVisionActive452 = true;
      scryingOrbVisionT452 = 0;
      window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'shimmer' } }));
    }

    // Vision animation
    if (scryingOrbVisionActive452) {
      scryingOrbVisionT452 += dt;
      if (scryingOrbVisionT452 < 0.4) {
        const p = scryingOrbVisionT452 / 0.4;
        if (scryingOrbMat452) scryingOrbMat452.opacity = 0.55 + 0.45 * p;
        if (scryingOrbLight452) scryingOrbLight452.intensity = 0.3 + 1.2 * p;
      } else if (scryingOrbVisionT452 < 1.5) {
        const p = (scryingOrbVisionT452 - 0.4) / 1.1;
        if (scryingOrbMat452) scryingOrbMat452.opacity = 1.0 - 0.5 * p;
        if (scryingOrbLight452) scryingOrbLight452.intensity = 1.5 - 1.2 * p;
      } else {
        scryingOrbVisionActive452 = false;
      }
    }

    // C457 — fireplace update
    fireplaceT457 += dt;

    // Flame flicker
    fireplaceFlames457.forEach((flame, i) => {
      const f = 0.85 + 0.2 * Math.sin(fireplaceT457 * 5.0 + i * 1.7);
      flame.scale.set(f, 0.9 + 0.15 * Math.sin(fireplaceT457 * 4.0 + i), f);
      const mat = flame.material as MeshBasicMaterial;
      mat.opacity = 0.6 + 0.2 * Math.sin(fireplaceT457 * 4.5 + i * 2.3);
    });

    // Sparks rise and reset
    fireplaceSparks457.forEach((spark) => {
      const ud = spark.userData as { vx: number; vy: number; phase: number };
      spark.position.y += ud.vy * dt;
      spark.position.x += Math.sin(fireplaceT457 * 3 + ud.phase) * 0.01;
      const mat = spark.material as MeshBasicMaterial;
      mat.opacity = Math.max(0, 1.0 - (spark.position.y - 0.2) / 1.5);
      if (spark.position.y > 1.7 || mat.opacity <= 0.02) {
        spark.position.set((Math.random() - 0.5) * 0.6, 0.2, 0.1);
        mat.opacity = 0.9;
      }
    });

    // Light flicker
    if (fireplaceLight457) {
      fireplaceLight457.intensity = 1.0 + 0.4 * Math.sin(fireplaceT457 * 6.0);
    }

    // C462 — floating runic calendar disc update
    calendarDiscT462 += dt;
    calendarSurgeTimer462 -= dt;

    if (calendarDisc462) {
      calendarDisc462.rotation.y = calendarDiscT462 * 0.12;
      calendarDisc462.position.y = 2.8 + 0.12 * Math.sin(calendarDiscT462 * 0.5);
    }

    if (!calendarSurging462) {
      calendarRunesMats462.forEach((mat, i) => {
        mat.opacity = 0.35 + 0.2 * Math.sin(calendarDiscT462 * 0.9 + i * (Math.PI / 6));
      });
      if (calendarDiscLight462) {
        calendarDiscLight462.intensity = 0.25 + 0.08 * Math.sin(calendarDiscT462 * 1.0);
      }
    }

    if (calendarSurgeTimer462 <= 0) {
      calendarSurgeTimer462 = 20 + Math.random() * 10;
      calendarSurging462 = true;
      calendarSurgeT462 = 0;
      window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'power_up' } }));
    }

    if (calendarSurging462) {
      calendarSurgeT462 += dt;
      if (calendarSurgeT462 < 2.0) {
        const t = calendarSurgeT462 / 2.0;
        calendarRunesMats462.forEach((mat) => {
          mat.opacity = 0.8 - 0.4 * t;
        });
        if (calendarDiscLight462) {
          calendarDiscLight462.intensity = 0.25 + 0.8 * (1 - t);
        }
        if (calendarDisc462) {
          calendarDisc462.rotation.y += dt * 1.5;
        }
      } else {
        calendarSurging462 = false;
      }
    }

    // C441 — celestial star map parchment update
    if (starMapGroup441) {
      starMapT441 += dt;
      starDots441.forEach((dot, i) => {
        const mat = dot.material as MeshBasicMaterial;
        mat.opacity = 0.7 + 0.3 * Math.sin(starMapT441 * 1.2 + i * 0.7);
      });
    }

    // C438 — potion bottle shelf update
    if (_potionShelfGroup) {
      _potionShelfT += dt;
      // Liquid bubble pulse — each bottle at different frequency
      _potionLiquids.forEach((liq, i) => {
        const freq = 1.2 + i * 0.3;
        const phase = i * 0.8;
        liq.scale.y = 1.0 + Math.sin(_potionShelfT * freq + phase) * 0.06;
        liq.scale.x = 1.0 + Math.sin(_potionShelfT * freq * 1.3 + phase) * 0.03;
        const mat = liq.material as MeshBasicMaterial;
        mat.opacity = 0.75 + Math.sin(_potionShelfT * freq * 2 + phase) * 0.12;
      });
      // Light flicker
      _potionLights.forEach((light, i) => {
        light.intensity = 0.05 + Math.sin(_potionShelfT * 1.8 + i * 1.1) * 0.025;
      });
    }

    // C361: enchanted mirror portal — vertex ripple + vision pulse
    if (!lowFpsMode && mirrorSurface361) {
      // Sinusoidal vertex displacement on mirror surface
      const pos = (mirrorSurface361.geometry as BufferGeometry).attributes['position'];
      if (pos) {
        for (let i = 0; i < pos.count; i++) {
          const x = pos.getX(i);
          const y = pos.getY(i);
          const r = Math.sqrt(x * x + y * y);
          pos.setZ(i, Math.sin(r * 4.0 - elapsedTime * 2.0) * 0.015 + Math.sin(r * 7.0 + elapsedTime * 1.3) * 0.008);
        }
        (pos as BufferAttribute).needsUpdate = true;
      }

      // Vision pulse timer — triggers every 10–14s
      mirrorNextPulse361 -= dt;
      if (mirrorNextPulse361 <= 0 && mirrorPulseT361 < 0) {
        mirrorPulseT361 = 0;
        mirrorNextPulse361 = 10.0 + Math.random() * 4.0;
      }
      if (mirrorPulseT361 >= 0) {
        mirrorPulseT361 += dt;
        const mat = mirrorSurface361.material as MeshStandardMaterial;
        if (mirrorPulseT361 < 0.4) {
          mat.emissiveIntensity = 0.15 + (mirrorPulseT361 / 0.4) * 0.45;
          if (mirrorLight361) mirrorLight361.intensity = 0.12 + (mirrorPulseT361 / 0.4) * 0.5;
        } else if (mirrorPulseT361 < 1.2) {
          const decay = 1.0 - (mirrorPulseT361 - 0.4) / 0.8;
          mat.emissiveIntensity = 0.15 + decay * 0.45;
          if (mirrorLight361) mirrorLight361.intensity = 0.12 + decay * 0.5;
        } else {
          mat.emissiveIntensity = 0.15;
          if (mirrorLight361) mirrorLight361.intensity = 0.12;
          mirrorPulseT361 = -1;
        }
      }
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
    // C277: clear scrying pool refs (geometries/materials disposed by scene.traverse above)
    _scryingPoolMesh = null;
    _scryingVisionMesh = null;
    // C284: clear astrolabe ring refs (geometries/materials disposed by scene.traverse above)
    _astroRing1 = _astroRing2 = _astroRing3 = null;
    // C292: clear skull light refs (geometries/materials disposed by scene.traverse above)
    _skullLights.length = 0;
    // C301: clear moss patch refs (geometries/materials disposed by scene.traverse above)
    _mossPatches.length = 0;
    // C316: clear steam wisp refs (geometries/materials disposed by scene.traverse above)
    _steamWisps.length = 0;
    // C328: clear tome bookshelf refs (geometries/materials disposed by scene.traverse above)
    _bookshelfGroup = null;
    _bookmarkMesh = null;
    // C335: clear alchemy symbol refs (geometries/materials disposed by scene.traverse above)
    _alchemySymbolMeshes.length = 0;
    _alchemyLights.length = 0;
    // C343: clear map table group refs (geometries/materials disposed by scene.traverse above)
    _mapTableGroup = null;
    _mapScrollLight = null;
    _mapParchment = null;
    // C355: clear herb bundle refs (geometries/materials disposed by scene.traverse above)
    _herbBundles355.length = 0;
    _herbLights355.length = 0;
    // C376: remove chime rods and lights explicitly (not under a shared Group)
    _chimeRods376.forEach(r => { scene.remove(r); r.geometry.dispose(); (r.material as MeshStandardMaterial).dispose(); });
    _chimeRods376.length = 0;
    _chimeLights376.forEach(l => { scene.remove(l); });
    _chimeLights376.length = 0;
    _chimeAngles376.length = 0;
    _chimeVelocities376.length = 0;
    // C380: remove orb meshes and lights explicitly (not under a shared Group)
    _orbMeshes380.forEach(o => { scene.remove(o); o.geometry.dispose(); (o.material as MeshStandardMaterial).dispose(); });
    _orbMeshes380.length = 0;
    _orbLights380.forEach(l => { scene.remove(l); l.dispose(); });
    _orbLights380.length = 0;
    // C361: clear mirror portal refs (geometries/materials disposed by scene.traverse above)
    mirrorGroup361 = null;
    mirrorSurface361 = null;
    if (mirrorLight361) { mirrorLight361 = null; }
    // C384: remove balance scale group and all children
    if (_scaleGroup384) {
      scene.remove(_scaleGroup384);
      _scaleGroup384.traverse(c => {
        if ((c as Mesh).geometry) (c as Mesh).geometry.dispose();
        const mat = (c as Mesh).material;
        if (mat) (mat as MeshStandardMaterial).dispose();
      });
      _scaleGroup384 = null;
    }
    _scaleArm384 = null;
    _scalePanLeft384 = null;
    _scalePanRight384 = null;
    if (_scaleSparkLight384) { _scaleSparkLight384.dispose(); _scaleSparkLight384 = null; }
    // C391: remove clock group and all children
    if (_clockGroup391) {
      scene.remove(_clockGroup391);
      _clockGroup391.traverse(c => {
        if ((c as Mesh).geometry) (c as Mesh).geometry.dispose();
        const mat = (c as Mesh).material;
        if (mat) (mat as MeshStandardMaterial).dispose();
      });
      _clockGroup391 = null;
    }
    _clockPendulum391 = null;
    _clockHourHand391 = null;
    _clockMinuteHand391 = null;
    if (_clockChimeLight391) { _clockChimeLight391.dispose(); _clockChimeLight391 = null; }
    // C396: remove floating scroll group and all children
    if (_scrollGroup396) {
      scene.remove(_scrollGroup396);
      _scrollGroup396.traverse(c => {
        if ((c as Mesh).geometry) (c as Mesh).geometry.dispose();
        const mat = (c as Mesh).material;
        if (mat) (mat as MeshStandardMaterial).dispose();
      });
      _scrollGroup396 = null;
    }
    _scrollFace396 = null;
    if (_scrollLight396) { _scrollLight396.dispose(); _scrollLight396 = null; }
    // C401: spider web + dew drops
    if (_webGroup) {
      scene.remove(_webGroup);
      _webGroup.traverse(c => {
        if ((c as Mesh).geometry) (c as Mesh).geometry.dispose();
        const mat = (c as Mesh).material;
        if (mat) (mat as MeshStandardMaterial | LineBasicMaterial).dispose();
      });
      _webGroup = null;
    }
    _webDewSpheres.length = 0;
    // C408: cauldron + steam
    if (_cauldronGroup) {
      scene.remove(_cauldronGroup);
      _cauldronGroup.traverse(c => {
        if (c instanceof Mesh) {
          c.geometry.dispose();
          if (Array.isArray(c.material)) c.material.forEach(m => m.dispose());
          else c.material.dispose();
        }
        if (c instanceof PointLight) c.dispose();
      });
      _steamPuffs.length = 0;
      _steamVel.length = 0;
      _cauldronLight = null;
      _potionSurface = null;
      _cauldronGroup = null;
    }
    // C413: floating spell tome
    if (_tomeGroup) {
      _tomeGroup.traverse(c => {
        if (c instanceof Mesh) {
          c.geometry.dispose();
          if (Array.isArray(c.material)) c.material.forEach(m => m.dispose());
          else c.material.dispose();
        }
        if (c instanceof PointLight) c.dispose();
      });
      _tomePageL = null;
      _tomePageR = null;
      _tomeGlowLight = null;
      scene.remove(_tomeGroup);
      _tomeGroup = null;
    }
    // C418: suspended astrolabe
    if (_astroGroup) {
      _astroGroup.traverse(c => {
        if (c instanceof Mesh) {
          c.geometry.dispose();
          if (Array.isArray(c.material)) c.material.forEach(m => m.dispose());
          else c.material.dispose();
        }
        if (c instanceof PointLight) c.dispose();
      });
      _astroRingOuter = null;
      _astroRingMid = null;
      _astroRingInner = null;
      scene.remove(_astroGroup);
      _astroGroup = null;
    }
    // C424: ceiling star projector
    if (_starProjGroup) {
      _starProjGroup.traverse(c => {
        if (c instanceof Mesh) {
          c.geometry.dispose();
          if (Array.isArray(c.material)) c.material.forEach(m => m.dispose());
          else c.material.dispose();
        } else if (c instanceof Line) {
          c.geometry.dispose();
          (c.material as LineBasicMaterial).dispose();
        } else if (c instanceof PointLight) {
          c.dispose();
        }
      });
      _starDots.length = 0;
      _starProjLight = null;
      scene.remove(_starProjGroup);
      _starProjGroup = null;
    }
    // C428: sleeping familiar cat
    if (_catGroup) {
      _catGroup.traverse(c => {
        if (c instanceof Mesh) {
          c.geometry.dispose();
          if (Array.isArray(c.material)) c.material.forEach(m => m.dispose());
          else c.material.dispose();
        }
      });
      _catBody = null; _catEyeL = null; _catEyeR = null; _catHead = null;
      scene.remove(_catGroup);
      _catGroup = null;
    }
    // C432: floating hourglass
    if (_hourglassGroup) {
      _hourglassGroup.traverse(c => {
        if (c instanceof Mesh) {
          c.geometry.dispose();
          if (Array.isArray(c.material)) c.material.forEach(m => m.dispose());
          else c.material.dispose();
        }
        if (c instanceof PointLight) c.dispose();
      });
      _sandParticles.length = 0;
      _sandVel.length = 0;
      _hourglassLight = null;
      scene.remove(_hourglassGroup);
      _hourglassGroup = null;
    }
    // C436 — floor summoning rune circle dispose
    if (_runeCircleGroup) {
      _runeCircleGroup.traverse(c => {
        if (c instanceof Mesh) {
          c.geometry.dispose();
          if (Array.isArray(c.material)) c.material.forEach(m => m.dispose());
          else c.material.dispose();
        }
        if (c instanceof PointLight) c.dispose();
      });
      _runeRings.length = 0;
      _runeCircleLight = null;
      scene.remove(_runeCircleGroup);
      _runeCircleGroup = null;
    }
    // C441 — celestial star map parchment dispose
    if (starMapGroup441) {
      starMapGroup441.traverse((c) => {
        if (c instanceof Mesh) { c.geometry.dispose(); (c.material as Material).dispose(); }
        else if (c instanceof Line) { c.geometry.dispose(); (c.material as Material).dispose(); }
      });
      scene.remove(starMapGroup441);
      starMapGroup441 = null;
    }
    starDots441.length = 0;
    // C447 — enchanted mirror dispose
    if (mirrorGroup447) {
      mirrorGroup447.traverse((c) => {
        if (c instanceof Mesh) { c.geometry.dispose(); (c.material as Material).dispose(); }
      });
      scene.remove(mirrorGroup447);
      mirrorGroup447 = null;
    }
    mirrorSurfaceMat447 = null;
    mirrorLight447 = null;
    // C452 — floating scrying orb dispose
    if (scryingOrbGroup452) {
      scryingOrbGroup452.traverse((c) => {
        if (c instanceof Mesh) { c.geometry.dispose(); (c.material as Material).dispose(); }
      });
      scene.remove(scryingOrbGroup452);
      scryingOrbGroup452 = null;
    }
    scryingOrbMat452 = null;
    scryingOrbLight452 = null;
    // C457 — fireplace dispose
    if (fireplaceGroup457) {
      fireplaceGroup457.traverse((c) => {
        if (c instanceof Mesh) { c.geometry.dispose(); (c.material as Material).dispose(); }
      });
      scene.remove(fireplaceGroup457);
      fireplaceGroup457 = null;
    }
    fireplaceFlames457 = [];
    fireplaceSparks457 = [];
    fireplaceLight457 = null;
    // C462 — floating runic calendar disc dispose
    if (calendarDisc462) {
      calendarDisc462.traverse((c) => {
        if (c instanceof Mesh) { c.geometry.dispose(); (c.material as Material).dispose(); }
      });
      scene.remove(calendarDisc462);
      calendarDisc462 = null;
    }
    calendarRunesMats462 = [];
    calendarDiscLight462 = null;
    // C438 — potion bottle shelf dispose
    if (_potionShelfGroup) {
      _potionShelfGroup.traverse(c => {
        if (c instanceof Mesh) {
          c.geometry.dispose();
          if (Array.isArray(c.material)) c.material.forEach(m => m.dispose());
          else c.material.dispose();
        }
        if (c instanceof PointLight) c.dispose();
      });
      _potionLiquids.length = 0;
      _potionLights.length = 0;
      scene.remove(_potionShelfGroup);
      _potionShelfGroup = null;
    }
  };

  const onZoneClick = (cb: (zone: LairZone) => void): void => {
    zoneClickCallback = cb;
  };

  const setTime = (params: LairTimeParams): void => {
    lairWindow.updateTime(params);
  };

  return { update, dispose, onZoneClick, setTime };
}
