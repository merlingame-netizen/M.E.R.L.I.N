// ═══════════════════════════════════════════════════════════════════════════════
// Coast Biome — ISO low-poly coastal scene (C161 visual overhaul)
// Reference: dramatic cliff + teal faceted ocean + layered flat-shaded clouds.
// ═══════════════════════════════════════════════════════════════════════════════

import {
  AmbientLight, BackSide, BoxGeometry, BufferAttribute, BufferGeometry, CircleGeometry, Color,
  ConeGeometry, CylinderGeometry, DirectionalLight,
  DodecahedronGeometry, DoubleSide, Group, HemisphereLight,
  Material, Mesh, MeshBasicMaterial, MeshStandardMaterial, PlaneGeometry, PointLight, Points,
  PointsMaterial, SphereGeometry,
  TorusGeometry,
} from 'three';
import { loadGLB } from '../engine/AssetLoader';

// ── Ground (cliff path — sandy grey-brown like reference) ────────────────────

function createGround(): Mesh {
  const geo = new PlaneGeometry(200, 200, 52, 52);
  const pos = geo.attributes.position as BufferAttribute;
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i);
    const z = pos.getY(i);
    const h =
      Math.sin(x * 0.048) * 1.1 +
      Math.cos(z * 0.072) * 0.65 +
      Math.sin(x * 0.13 + z * 0.09) * 0.35 +
      (Math.random() - 0.5) * 0.22;
    pos.setZ(i, h);
  }
  geo.computeVertexNormals();
  const mat = new MeshStandardMaterial({
    color: 0x3a2e18, // C168: dark wet stone cliff path
    roughness: 0.97, metalness: 0.0, flatShading: true,
  });
  const mesh = new Mesh(geo, mat);
  mesh.rotation.x = -Math.PI / 2;
  mesh.receiveShadow = true;
  return mesh;
}

// ── Teal faceted ocean with vertex color depth variation ─────────────────────

interface OceanResult {
  mesh: Mesh;
  basePositions: Float32Array;
}

function createOcean(): OceanResult {
  const geo = new PlaneGeometry(220, 220, 44, 36);
  const pos = geo.attributes.position as BufferAttribute;
  const count = pos.count;

  // C163: N64 vivid ocean vertex colors — bright turquoise near shore → deep azure far
  const colors = new Float32Array(count * 3);
  for (let i = 0; i < count; i++) {
    const x = pos.getX(i);
    const depth = Math.max(0, Math.min(1, (x + 110) / 220));
    // Near shore (depth=1): 0x14e8d0 = (0.078, 0.910, 0.816) vivid N64 turquoise
    // Open sea  (depth=0): 0x0c5ab8 = (0.047, 0.353, 0.722) deep N64 ocean blue
    // C168: dark stormy ocean — deep navy to dark teal near shore
    colors[i * 3 + 0] = 0.020 + depth * 0.019;
    colors[i * 3 + 1] = 0.063 + depth * 0.172;
    colors[i * 3 + 2] = 0.118 + depth * 0.204;
  }
  geo.setAttribute('color', new BufferAttribute(colors, 3));

  const mat = new MeshStandardMaterial({
    vertexColors: true,
    roughness: 0.18,
    metalness: 0.28,
    transparent: true,
    opacity: 0.92,
    flatShading: true,
  });
  const mesh = new Mesh(geo, mat);
  mesh.rotation.x = -Math.PI / 2;
  mesh.position.set(68, -0.6, 0);
  mesh.name = 'ocean_plane';

  const basePositions = new Float32Array(pos.array as Float32Array);
  return { mesh, basePositions };
}

// ── Foam strips near shoreline ────────────────────────────────────────────────

function createFoamStrips(): Group {
  const group = new Group();
  const foamMat = new MeshStandardMaterial({
    color: 0xdce8e0,
    roughness: 0.95, metalness: 0.0,
    transparent: true, opacity: 0.72,
    flatShading: true,
    emissive: 0xaaccbb, emissiveIntensity: 0.08,
  });
  const R = () => Math.random();
  // Irregular foam slabs along the shoreline (x ≈ 22–35)
  for (let i = 0; i < 14; i++) {
    const w = 3 + R() * 6;
    const d = 0.8 + R() * 1.4;
    const foam = new Mesh(new PlaneGeometry(w, d, 3, 2), foamMat);
    foam.rotation.x = -Math.PI / 2;
    foam.position.set(
      22 + R() * 14,
      -0.48 + R() * 0.08,
      -25 + R() * 50,
    );
    foam.rotation.z = (R() - 0.5) * 0.4;
    group.add(foam);
  }
  return group;
}

// ── Dramatic ISO low-poly sky — base sphere + layered cloud slabs ─────────────

interface SkyResult {
  group: Group;
  cloudLayers: CloudLayer[];
}

interface CloudLayer {
  group: Group;
  speed: number; // world-X drift per second
  baseX: number;
}

function createSky(): SkyResult {
  const group = new Group();

  // C163: N64 bright coastal sky — vivid day-blue gradient
  const skyGeo = new SphereGeometry(148, 14, 10);
  const skyPos = skyGeo.attributes.position as BufferAttribute;
  const skyCols = new Float32Array(skyPos.count * 3);
  for (let i = 0; i < skyPos.count; i++) {
    const y = skyPos.getY(i);
    const t = Math.max(0, Math.min(1, (y + 60) / 140));
    // horizon: 0x78c4f0 = (0.471, 0.769, 0.941) N64 vivid sky-blue horizon
    // zenith:  0x1848c8 = (0.094, 0.282, 0.784) deep clear-blue zenith
    const hr = 0.471, hg = 0.769, hb = 0.941;
    const zr = 0.094, zg = 0.282, zb = 0.784;
    skyCols[i * 3 + 0] = hr + (zr - hr) * t;
    skyCols[i * 3 + 1] = hg + (zg - hg) * t;
    skyCols[i * 3 + 2] = hb + (zb - hb) * t;
  }
  skyGeo.setAttribute('color', new BufferAttribute(skyCols, 3));
  const skyMesh = new Mesh(skyGeo, new MeshStandardMaterial({
    vertexColors: true, side: BackSide, flatShading: true,
    roughness: 1.0, metalness: 0.0,
  }));
  group.add(skyMesh);

  // Cloud slab factory — flat BoxGeometry tiles
  const cloudLayers: CloudLayer[] = [];

  const addCloudLayer = (
    yBase: number,
    greyRange: [number, number],
    count: number,
    speed: number,
    zRange: [number, number],
    scaleRange: [number, number],
  ): void => {
    const layerGroup = new Group();
    const R = () => Math.random();
    for (let i = 0; i < count; i++) {
      const grey = greyRange[0] + R() * (greyRange[1] - greyRange[0]);
      const g = Math.floor(grey * 255);
      const col = (g << 16) | (g << 8) | g;
      const slab = new Mesh(
        new BoxGeometry(
          16 + R() * 28,       // wide cloud
          1.5 + R() * 3.5,     // flat
          5 + R() * 10,        // depth
          Math.floor(2 + R() * 3), 1, Math.floor(1 + R() * 2),
        ),
        new MeshStandardMaterial({
          color: col,
          flatShading: true,
          roughness: 1.0, metalness: 0.0,
          emissive: col, emissiveIntensity: 0.04,
        }),
      );
      slab.position.set(
        (R() - 0.5) * 200,
        yBase + (R() - 0.5) * 8,
        zRange[0] + R() * (zRange[1] - zRange[0]),
      );
      slab.rotation.y = (R() - 0.5) * 0.3;
      const s = scaleRange[0] + R() * (scaleRange[1] - scaleRange[0]);
      slab.scale.set(s, 1, s * 0.6);
      layerGroup.add(slab);
    }
    group.add(layerGroup);
    cloudLayers.push({ group: layerGroup, speed, baseX: 0 });
  };

  // C163: N64 bright white/cream clouds — vivid puffy day clouds
  // High layer — bright white clouds
  addCloudLayer(55, [0.90, 0.98], 12, 0.8,  [-80, 60], [0.9, 1.5]);
  // Mid layer — warm cream clouds
  addCloudLayer(38, [0.82, 0.94], 14, 1.4,  [-70, 50], [0.8, 1.3]);
  // Low horizon layer — light sky-tinted wisps
  addCloudLayer(22, [0.72, 0.88], 10, 2.0,  [-60, 40], [0.7, 1.1]);

  return { group, cloudLayers };
}

// ── Integrated cliff formation ────────────────────────────────────────────────
// Stacked, overlapping DodecahedronGeometry(0) rocks forming a unified cliff face.
// Rocks vary in size and are clustered in vertical columns to mimic the reference.

function createCliff(): Group {
  const group = new Group();

  const rockColors = [0x5a5248, 0x625848, 0x706858, 0x4e4840, 0x686050];
  const R = () => Math.random();

  const makeMat = (): MeshStandardMaterial => new MeshStandardMaterial({
    color: rockColors[Math.floor(R() * rockColors.length)]!,
    roughness: 0.92, metalness: 0.0, flatShading: true,
  });

  // ── Main cliff body: left side of path, rising from ocean to summit ──────
  // 3 vertical columns of large rocks forming the cliff face
  const columns: Array<{ x: number; z: number; yStart: number; stacks: number }> = [
    { x: 14,  z: -20, yStart: -3, stacks: 7 },
    { x: 18,  z: -10, yStart: -3, stacks: 8 },
    { x: 16,  z:   0, yStart: -3, stacks: 6 },
    { x: 20,  z:  10, yStart: -3, stacks: 5 },
    { x: 15,  z: -30, yStart: -3, stacks: 5 },
  ];

  for (const col of columns) {
    let y = col.yStart;
    for (let s = 0; s < col.stacks; s++) {
      const size = 2.5 - s * 0.18 + (R() - 0.5) * 0.6;  // taper upward
      const geo = new DodecahedronGeometry(size, 0);
      const rock = new Mesh(geo, makeMat());
      rock.position.set(
        col.x + (R() - 0.5) * 1.6,
        y + size * 0.7,
        col.z + (R() - 0.5) * 1.4,
      );
      rock.rotation.set(R() * 0.5, R() * Math.PI, R() * 0.4);
      rock.scale.set(1 + R() * 0.3, 0.55 + R() * 0.25, 1 + R() * 0.3); // flatter = more angular cliff
      rock.castShadow = true;
      group.add(rock);
      y += size * 1.1; // stack upward
    }
  }

  // ── Cliff base: wide flat rocks at water level ────────────────────────────
  for (let i = 0; i < 18; i++) {
    const size = 1.2 + R() * 2.2;
    const geo = new DodecahedronGeometry(size, 0);
    const rock = new Mesh(geo, makeMat());
    rock.position.set(
      10 + R() * 16,
      -1.2 + R() * 0.5,
      -40 + R() * 80,
    );
    rock.rotation.set(R() * 0.3, R() * Math.PI, R() * 0.25);
    rock.scale.set(1.2 + R() * 0.4, 0.35 + R() * 0.2, 1.1 + R() * 0.4);
    group.add(rock);
  }

  // ── Scattered path-side rocks (foreground texture) ────────────────────────
  for (let i = 0; i < 22; i++) {
    const size = 0.3 + R() * 1.1;
    const geo = new DodecahedronGeometry(size, 0);
    const rock = new Mesh(geo, makeMat());
    rock.position.set(
      (R() - 0.5) * 16,
      -0.15 + R() * 0.15,
      -30 + R() * 60,
    );
    rock.rotation.set(R() * 0.6, R() * Math.PI, R() * 0.5);
    rock.scale.set(1, 0.5 + R() * 0.4, 1);
    group.add(rock);
  }

  // ── Cliff-top vegetation (dark green low shrubs) ──────────────────────────
  const bushMat = new MeshStandardMaterial({
    color: 0x2a4a22, roughness: 0.95, metalness: 0.0, flatShading: true,
    emissive: 0x1a3015, emissiveIntensity: 0.08,
  });
  for (let i = 0; i < 16; i++) {
    const r = 0.3 + R() * 0.55;
    const bush = new Mesh(new DodecahedronGeometry(r, 0), bushMat);
    bush.position.set(
      10 + R() * 14,
      3 + R() * 6,
      -28 + R() * 56,
    );
    bush.rotation.set(R() * 0.4, R() * Math.PI, R() * 0.3);
    bush.scale.set(1.4, 0.6, 1.2);
    group.add(bush);
  }

  return group;
}

// ── Celtic conifers — 3-layer depth ──────────────────────────────────────────

function createTrees(count: number): Group {
  const group = new Group();
  const layers: Array<{
    start: number; end: number;
    minR: number; maxR: number;
    colorBase: number; scaleBase: number; scaleVar: number;
  }> = [
    { start: 0,  end: 12, minR: 6,  maxR: 16, colorBase: 0x2a5e22, scaleBase: 1.0, scaleVar: 0.45 },
    { start: 12, end: 27, minR: 16, maxR: 30, colorBase: 0x224e1a, scaleBase: 0.8, scaleVar: 0.35 },
    { start: 27, end: count, minR: 30, maxR: 55, colorBase: 0x18381a, scaleBase: 0.55, scaleVar: 0.28 },
  ];
  for (const layer of layers) {
    const trunkMat = new MeshStandardMaterial({ color: 0x3e2810, roughness: 0.95, flatShading: true });
    const leafMat  = new MeshStandardMaterial({ color: layer.colorBase, roughness: 0.88, flatShading: true });
    for (let i = layer.start; i < layer.end; i++) {
      const tree = new Group();
      const trunk = new Mesh(new CylinderGeometry(0.07, 0.16, 2.2, 5), trunkMat);
      tree.add(trunk);
      const c1 = new Mesh(new ConeGeometry(1.05, 2.1, 6), leafMat);
      c1.position.y = 1.35; tree.add(c1);
      const c2 = new Mesh(new ConeGeometry(0.78, 1.7, 6), leafMat);
      c2.position.y = 2.4; tree.add(c2);
      const c3 = new Mesh(new ConeGeometry(0.5, 1.3, 5), leafMat);
      c3.position.y = 3.35; tree.add(c3);
      const angle = Math.random() * Math.PI * 2;
      const radius = layer.minR + Math.random() * (layer.maxR - layer.minR);
      tree.position.set(Math.cos(angle) * radius - 12, 0, Math.sin(angle) * radius - 8);
      tree.scale.setScalar(layer.scaleBase + Math.random() * layer.scaleVar);
      tree.rotation.z = (Math.random() - 0.5) * 0.07;
      group.add(tree);
    }
  }
  return group;
}

// ── Menhirs ───────────────────────────────────────────────────────────────────

function createMenhirs(count: number): Group {
  const group = new Group();
  // C163: N64 sandstone cliff colours
  const mat  = new MeshStandardMaterial({ color: 0xa08048, roughness: 0.88, flatShading: true });
  const moss = new MeshStandardMaterial({ color: 0x5a8830, roughness: 0.95, flatShading: true });
  for (let i = 0; i < count; i++) {
    const h = 2.4 + Math.random() * 3.2;
    const m = new Mesh(new BoxGeometry(0.52, h, 0.36), mat);
    m.position.set(-16 + Math.random() * 32, h / 2, -24 + Math.random() * 10);
    m.rotation.y = Math.random() * Math.PI;
    m.rotation.z = (Math.random() - 0.5) * 0.11;
    m.castShadow = true;
    group.add(m);
    const mp = new Mesh(new BoxGeometry(0.62, 0.13, 0.48), moss);
    mp.position.set(m.position.x, 0.06, m.position.z);
    group.add(mp);
  }
  return group;
}

// ── Ground fog strip ──────────────────────────────────────────────────────────
// Simple translucent plane (no shader) — warm breton mist.

function createFogPlane(): Mesh {
  const mat = new MeshStandardMaterial({
    color: 0x4aaa28, // C163: N64 vivid green bushes on cliff top
    transparent: true, opacity: 0.18,
    roughness: 1.0, metalness: 0.0,
    depthWrite: false,
  });
  const mesh = new Mesh(new PlaneGeometry(180, 180, 1, 1), mat);
  mesh.rotation.x = -Math.PI / 2;
  mesh.position.y = 0.7;
  mesh.name = 'fog_plane';
  return mesh;
}

// ── Seabird flock — soaring silhouettes riding coastal thermals ───────────────

interface SeabirdState {
  phase: number;
  speed: number;
  dir: 1 | -1;
}

interface SeabirdFlockResult {
  birds: Group[];
  birdMats: MeshBasicMaterial[];
  update: (t: number, dt: number) => void;
}

function createSeabirdFlock(): SeabirdFlockResult {
  const birds: Group[] = [];
  const birdMats: MeshBasicMaterial[] = [];
  const states: SeabirdState[] = [];
  const R = (): number => Math.random();

  // Pale coastal white-grey — seagull colouring, avoids pure-white bloom
  const wingMat = new MeshBasicMaterial({ color: 0xe8f0e8, side: DoubleSide });
  birdMats.push(wingMat);

  const wingGeo = new PlaneGeometry(0.8, 0.2);

  for (let i = 0; i < 5; i++) {
    const bird = new Group();

    // Left wing — ±35° rest angle (seagulls hold wings flatter than crows)
    const leftWing = new Group();
    const lMesh = new Mesh(wingGeo, wingMat);
    lMesh.position.set(-0.4, 0, 0);
    leftWing.add(lMesh);
    leftWing.rotation.z = Math.PI / (180 / 35); // 35°
    bird.add(leftWing);

    // Right wing — mirror
    const rightWing = new Group();
    const rMesh = new Mesh(wingGeo, wingMat);
    rMesh.position.set(0.4, 0, 0);
    rightWing.add(rMesh);
    rightWing.rotation.z = -Math.PI / (180 / 35); // -35°
    bird.add(rightWing);

    // Higher altitude than forest crows — seagulls soar on thermals
    bird.position.set(
      -25 + R() * 50,
      6  + R() * 8,
      -5 - R() * 15,
    );

    const state: SeabirdState = {
      phase: R() * Math.PI * 2,
      speed: 2.5 + R() * 1.5,  // 2.5 – 4.0 units/s
      dir:   (R() < 0.5 ? 1 : -1) as 1 | -1,
    };
    states.push(state);
    birds.push(bird);
  }

  const update = (t: number, dt: number): void => {
    for (let i = 0; i < birds.length; i++) {
      const bird  = birds[i]!;
      const state = states[i]!;

      // Slower, more majestic flap — seagull soaring rhythm
      const leftWing  = bird.children[0]!;
      const rightWing = bird.children[1]!;
      const flapAngle = Math.PI / (180 / 35); // 35° base
      const flapAmp   = 0.45;
      leftWing.rotation.z  =  flapAngle + Math.sin(t * 3.5 + state.phase) * flapAmp;
      rightWing.rotation.z = -flapAngle - Math.sin(t * 3.5 + state.phase) * flapAmp;

      // Lateral flight
      bird.position.x += state.dir * state.speed * dt;

      // Gentle vertical soaring — coastal thermals (bigger amplitude than forest)
      bird.position.y += Math.sin(t * 0.5 + state.phase) * 0.3 * dt;

      // Wider wrap boundary — open coast, birds travel farther
      if (Math.abs(bird.position.x) > 45) {
        bird.position.x = -state.dir * (38 + R() * 6);
        bird.position.y =  6 + R() * 8;
        bird.position.z = -5 - R() * 15;
        state.phase     =  R() * Math.PI * 2;
        state.speed     =  2.5 + R() * 1.5;
      }
    }
  };

  return { birds, birdMats, update };
}

// ── Shipwreck silhouette — partially submerged on right-side rocks (C253) ────
// Dark weathered wood colors per CeltOS charter: 0x1a1208 / 0x120e06 (no amber).

function createShipwreck(): Group {
  const group = new Group();
  const darkWood     = new MeshBasicMaterial({ color: 0x1a1208 });
  const nearBlackWood = new MeshBasicMaterial({ color: 0x120e06 });

  // Hull — large box listing to port
  const hull = new Mesh(new BoxGeometry(8, 2.5, 3), darkWood);
  hull.position.set(18, -1.5, -25);
  hull.rotation.z = 0.35;
  group.add(hull);

  // Broken main mast — tilted toward water
  const mast = new Mesh(new CylinderGeometry(0.12, 0.15, 7, 4), nearBlackWood);
  mast.position.set(20, 1.5, -24);
  mast.rotation.z = -0.6;
  group.add(mast);

  // Mast spar — horizontal cross-piece
  const spar = new Mesh(new CylinderGeometry(0.08, 0.1, 4, 4), nearBlackWood);
  spar.position.set(19, 3, -24.5);
  spar.rotation.z = Math.PI / 2;
  group.add(spar);

  // Rigging rope hints — two thin angled lines connecting mast to hull edge
  const rope1 = new Mesh(new CylinderGeometry(0.03, 0.03, 4, 3), nearBlackWood);
  rope1.position.set(21, 1.8, -24.2);
  rope1.rotation.z = -1.1;
  group.add(rope1);

  const rope2 = new Mesh(new CylinderGeometry(0.03, 0.03, 4, 3), nearBlackWood);
  rope2.position.set(19.5, 2.1, -25.0);
  rope2.rotation.z = -0.85;
  rope2.rotation.y = 0.2;
  group.add(rope2);

  return group;
}

// ── Distant fishing boat silhouette on horizon (C293) ────────────────────────
// Small dark silhouette ~58 units out to sea; gentle bob + lateral drift in update().

function createFishingBoat(): Group {
  const group = new Group();
  const silMat = new MeshBasicMaterial({ color: 0x0a1008 });

  // Hull
  const hull = new Mesh(new BoxGeometry(3.5, 0.8, 1.2), silMat);
  hull.position.set(0, 0, 0);
  group.add(hull);

  // Cabin — centered on hull, offset +0.75 Y
  const cabin = new Mesh(new BoxGeometry(0.9, 0.7, 0.8), silMat);
  cabin.position.set(0, 0.75, 0);
  group.add(cabin);

  // Mast — vertical cylinder from hull center
  const mast = new Mesh(new CylinderGeometry(0.04, 0.04, 3.5, 4), silMat);
  mast.position.set(0, 1.75, 0); // 3.5/2 above hull center
  group.add(mast);

  // Boom — horizontal, rotated 90° on Z, at -0.6 Y relative to mast top
  const boom = new Mesh(new CylinderGeometry(0.03, 0.03, 2.0, 4), silMat);
  boom.rotation.z = Math.PI / 2;
  boom.position.set(0, 1.75 + 3.5 / 2 - 0.6, 0); // near mast top, offset -0.6
  group.add(boom);

  // Sail — DoubleSide translucent dark green, offset slightly from mast
  const sailMat = new MeshBasicMaterial({
    color: 0x1a2a1a,
    side: DoubleSide,
    transparent: true,
    opacity: 0.7,
  });
  const sail = new Mesh(new PlaneGeometry(1.6, 2.2), sailMat);
  sail.position.set(0.5, 2.35, 0); // offset from mast toward boom
  group.add(sail);

  // Place group at horizon
  group.position.set(10, 0.2, -58);
  return group;
}

// ── Export interface ──────────────────────────────────────────────────────────

export interface BiomeSceneResult {
  readonly group: Group;
  readonly update: (dt: number) => void;
  readonly dispose: () => void;
}

// ── Main builder ──────────────────────────────────────────────────────────────

// ── Lighthouse outer-var declarations (outer-var pattern: assign inside builder) ──
let lighthouseMesh: Mesh | null = null;
let lighthouseBeamMesh: Mesh | null = null;
let lighthouseLight: PointLight | null = null;
let _beamGroup: Group | null = null;
let _beamCone: Mesh | null = null;
let _beamAngle = 0;
let _beamFlashed = false;

// ── Sea foam particle pool (C243) ─────────────────────────────────────────────
let _foamMeshes: Mesh[] = [];
let _foamTimer = 0;

// ── Tide pool anemones (C273) ─────────────────────────────────────────────────
let _anemoneMeshes: Mesh[] = [];
let _anemoneTime = 0;

// ── Distant fishing boat silhouette (C293) ────────────────────────────────
let _boatGroup: Group | null = null;

// ── Tide pool + scuttling crab (C308) ─────────────────────────────────────
let _crabGroup: Group | null = null;
let _tidePoolLight: PointLight | null = null;

// ── Seagull flock — animated loose formation (C298) ──────────────────────
const _seagullGroups: Group[] = [];
const _seagullWingsL: Mesh[] = [];
const _seagullWingsR: Mesh[] = [];

// ── Kelp forest — tall swaying strands in shallow water (C324) ───────────
const _kelpStrands: Mesh[] = [];
const _kelpBulbs: Mesh[] = [];

// ── Underwater caustic light patches on seabed (C332) ────────────────────
const _causticPatches: Mesh[] = [];

// ── Storm petrel flock — dusk-only erratic silhouettes (C340) ────────────
const _petrelGroups: Group[] = [];
const _petrelWingsL: Mesh[] = [];
const _petrelWingsR: Mesh[] = [];
let _currentTimeOfDay: 'day' | 'dawn' | 'dusk' | 'night' = 'dusk';

// ── Harbor buoy chain — 5-buoy line marking safe harbor entrance (C353) ──
const _buoyGroups: Group[] = [];
const _buoyBeacons: Mesh[] = [];
const _buoyLights: PointLight[] = [];

// ── Sea spray burst particles at cliff base (C359) ────────────────────────
let sprayPoints359: Points | null = null;
let sprayPositions359: Float32Array | null = null;
let sprayVelocities359: Array<[number, number, number]> = [];
let sprayLifetimes359: Float32Array | null = null;
let sprayNextBurst359 = 3.0;

// ── Distant whale breach animation (C367) ─────────────────────────────────
let whaleMesh367: Mesh | null = null;
let whaleLight367: PointLight | null = null;
let whaleBreach367T = -1;   // -1 = resting, 0+ = animating
let whaleNext367 = 20.0 + Math.random() * 15.0;

// ── Bioluminescent wave crests (C371) ─────────────────────────────────────
let waveCrests371: Mesh[] = [];
let waveCrestData371: Array<{ z: number; speed: number; light: PointLight }> = [];

// ── Breaking wave (C395) ───────────────────────────────────────────────────
let waveGroup395: Group | null = null;
let waveFace395: Mesh | null = null;
let waveCrest395: Mesh | null = null;
let waveFlashLight395: PointLight | null = null;
let wavePhase395 = 0;     // 0=wait, 1=rise, 2=curl, 3=crash, 4=dissipate
let wavePhaseT395 = 0;
let waveWaitT395 = 0;

// ── Sea turtle swimming — cotes_sauvages (C399) ───────────────────────────
let turtleGroup: Group | null = null;
let turtleT = 0;
let turtleDir = 1;
let _turtleFrontL: Mesh | null = null;
let _turtleFrontR: Mesh | null = null;

export async function buildCoastScene(): Promise<BiomeSceneResult> {
  const group = new Group();

  // C167: fog params for sceneManager.updateFog() — matches sky horizon vertex colour
  // (0.471, 0.769, 0.941) = 0x78c4f0; light coastal sea-haze, density kept low.
  // C168: dark coastal storm haze
  (group as typeof group & { fogColor: number; fogDensity: number }).fogColor   = 0x182030;
  (group as typeof group & { fogColor: number; fogDensity: number }).fogDensity = 0.014;

  // ── C163: N64 bright coastal lighting — warm golden sun + vivid sky hemisphere ──
  group.add(new AmbientLight(0x304050, 0.35)); // C168: dark stormy ambient

  const isLowEndMobile = /Android|iPhone|iPad|iPod/i.test(navigator.userAgent) && window.devicePixelRatio >= 2;
  const sun = new DirectionalLight(0x8898b8, 1.0); // C168: muted stormy sun
  sun.position.set(-18, 28, 15);
  if (!isLowEndMobile) {
    sun.castShadow = true;
    sun.shadow.mapSize.set(1024, 1024);
    sun.shadow.camera.near = 0.5;
    sun.shadow.camera.far = 100;
    sun.shadow.camera.left = -45;
    sun.shadow.camera.right = 45;
    sun.shadow.camera.top = 45;
    sun.shadow.camera.bottom = -45;
  }
  group.add(sun);

  // Sky blue / sandy-green ground hemisphere
  group.add(new HemisphereLight(0x1a2840, 0x1a2810, 0.35)); // C168: dark storm hemisphere

  // Ocean fill from sea side — vivid cyan
  const rim = new DirectionalLight(0x1a3050, 0.25); // C168: dark sea-side fill
  rim.position.set(55, 8, -18);
  group.add(rim);

  // ── Scene elements ────────────────────────────────────────────────────────
  group.add(createGround());

  const { mesh: oceanMesh, basePositions: oceanBase } = createOcean();
  group.add(oceanMesh);
  group.add(createFoamStrips());

  const { group: skyGroup, cloudLayers } = createSky();
  group.add(skyGroup);

  group.add(createCliff());
  group.add(createTrees(40));
  group.add(createMenhirs(6));
  group.add(createFogPlane());

  // ── Lighthouse — tall tower on left cliff with rotating green beam ─────────
  // Tower body: white-ish cylinder at left cliff position
  lighthouseMesh = new Mesh(
    new CylinderGeometry(0.3, 0.5, 8, 8),
    new MeshStandardMaterial({ color: 0xdde8dd, roughness: 0.85, flatShading: true }),
  );
  lighthouseMesh.position.set(-20, 4, -35);
  group.add(lighthouseMesh);

  // Lens housing sphere at tower top
  const lensMesh = new Mesh(
    new SphereGeometry(0.8, 8, 6),
    new MeshBasicMaterial({ color: 0x33ff66 }),
  );
  lensMesh.position.set(-20, 9, -35);
  group.add(lensMesh);

  // Point light at lighthouse top — green CeltOS charter
  lighthouseLight = new PointLight(0x33ff66, 0.6, 30);
  lighthouseLight.position.set(-20, 9, -35);
  group.add(lighthouseLight);

  // Rotating beam group — both the bright center streak and volumetric cone child
  _beamGroup = new Group();
  _beamGroup.position.set(-20, 9, -35);
  _beamAngle = 0;
  _beamFlashed = false;

  // Center streak — thin bright box (existing beam)
  lighthouseBeamMesh = new Mesh(
    new BoxGeometry(0.1, 0.2, 25),
    new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.15 }),
  );
  // Box geometry is centered; offset so tip is at origin and beam fans away in +Z
  lighthouseBeamMesh.position.set(0, 0, 12.5);
  _beamGroup.add(lighthouseBeamMesh);

  // Volumetric cone — open cone with tip at lens, fans 25 units out horizontally
  // CylinderGeometry(radiusTop, radiusBottom, height, radialSeg, heightSeg, openEnded)
  _beamCone = new Mesh(
    new CylinderGeometry(0.0, 0.8, 25, 8, 1, true),
    new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.04, side: DoubleSide }),
  );
  // Rotate 90° on X so cone points horizontally (+Z direction) with tip at origin
  _beamCone.rotation.x = Math.PI / 2;
  // Cylinder origin is at its center height; shift so tip aligns at group origin
  _beamCone.position.set(0, 0, 12.5);
  _beamGroup.add(_beamCone);

  group.add(_beamGroup);

  // Soaring seabird flock — pale silhouettes on coastal thermals
  const seabirdFlock = createSeabirdFlock();
  for (const bird of seabirdFlock.birds) {
    group.add(bird);
  }

  // ── Shipwreck silhouette on right-side rocks (C253) ──────────────────────
  group.add(createShipwreck());

  // ── Tide pool anemones on rocks near shipwreck area (C273) ───────────────
  _anemoneMeshes = [];
  _anemoneTime = 0;
  const anemonePositions: [number, number, number][] = [
    [12, -0.5, -15],
    [13.5, -0.5, -16],
    [14, -0.5, -14],
    [11, -0.5, -14.5],
    [15, -0.5, -15.5],
  ];
  const anemoneColors = [0xcc2266, 0x22aa66, 0x1a7a55, 0xcc2266, 0x22aa66];
  for (let i = 0; i < 5; i++) {
    const pos = anemonePositions[i]!;
    const color = anemoneColors[i]!;
    const mat = new MeshBasicMaterial({ color });

    // Stalk — static cylinder base
    const stalk = new Mesh(new CylinderGeometry(0.15, 0.2, 0.3, 6), mat.clone());
    stalk.position.set(pos[0], pos[1] + 0.15, pos[2]);
    group.add(stalk);

    // Dome — partial sphere top (pulsing tentacle crown)
    const dome = new Mesh(
      new SphereGeometry(0.3, 6, 4, 0, Math.PI * 2, 0, Math.PI * 0.6),
      mat.clone(),
    );
    dome.position.set(pos[0], pos[1] + 0.3, pos[2]);
    _anemoneMeshes.push(dome);
    group.add(dome);
  }

  // ── Sea foam particle pool — 15 pooled spheres (C243) ────────────────────
  _foamMeshes = [];
  _foamTimer = 0;
  const foamGeo = new SphereGeometry(0.15, 4, 3);
  for (let i = 0; i < 15; i++) {
    const foamMesh = new Mesh(
      foamGeo,
      new MeshBasicMaterial({ color: 0xf0fff0, transparent: true, opacity: 0 }),
    );
    foamMesh.position.set(0, -10, 0);
    foamMesh.userData = { active: false, lifetime: 0, maxLife: 0.6, x: 0, z: 0 };
    _foamMeshes.push(foamMesh);
    group.add(foamMesh);
  }

  // ── Sea cave arch entrance — left cliff side (C289) ─────────────────────
  {
    const CAVE_X = -25;
    const CAVE_Y = -0.5;
    const CAVE_Z = -35;
    const ROCK_COLOR = 0x1a1a14;
    const DARK_COLOR = 0x0e0e0a;

    // Left pillar
    const leftPillar = new Mesh(
      new BoxGeometry(1.5, 5, 1.0),
      new MeshBasicMaterial({ color: ROCK_COLOR }),
    );
    leftPillar.position.set(CAVE_X - 2.0, CAVE_Y + 2.5, CAVE_Z);
    group.add(leftPillar);

    // Right pillar
    const rightPillar = new Mesh(
      new BoxGeometry(1.5, 5, 1.0),
      new MeshBasicMaterial({ color: ROCK_COLOR }),
    );
    rightPillar.position.set(CAVE_X + 2.0, CAVE_Y + 2.5, CAVE_Z);
    group.add(rightPillar);

    // Arch lintel (top)
    const arch = new Mesh(
      new BoxGeometry(5.5, 2.0, 1.0),
      new MeshBasicMaterial({ color: ROCK_COLOR }),
    );
    arch.position.set(CAVE_X, CAVE_Y + 5.5, CAVE_Z);
    group.add(arch);

    // Dark cave interior (void plane behind arch)
    const voidPlane = new Mesh(
      new PlaneGeometry(2.8, 3.5),
      new MeshBasicMaterial({ color: DARK_COLOR, side: DoubleSide }),
    );
    voidPlane.position.set(CAVE_X, CAVE_Y + 2.2, CAVE_Z + 0.1);
    group.add(voidPlane);

    // Faint green bioluminescent glow from cave interior
    const glowPlane = new Mesh(
      new PlaneGeometry(2.0, 2.5),
      new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.06, side: DoubleSide }),
    );
    glowPlane.position.set(CAVE_X, CAVE_Y + 2.2, CAVE_Z + 0.15);
    group.add(glowPlane);
  }

  // ── Distant fishing boat silhouette on horizon (C293) ────────────────────
  _boatGroup = createFishingBoat();
  group.add(_boatGroup);

  // ── Seagull flock — 6 birds in loose formation (C298) ───────────────────
  {
    const FLOCK_CX = -5;
    const FLOCK_CY = 14;
    const FLOCK_CZ = -40;
    const bodyMat   = new MeshBasicMaterial({ color: 0x0e1a0e });
    const wingMatL  = new MeshBasicMaterial({ color: 0x0e1a0e, side: DoubleSide });
    const wingMatR  = new MeshBasicMaterial({ color: 0x0e1a0e, side: DoubleSide });
    const bodyGeo   = new BoxGeometry(0.08, 0.04, 0.22);
    const wingGeoL  = new BoxGeometry(0.7, 0.03, 0.18);
    const wingGeoR  = new BoxGeometry(0.7, 0.03, 0.18);

    const R = (): number => Math.random();
    for (let i = 0; i < 6; i++) {
      const bird = new Group();

      const body = new Mesh(bodyGeo, bodyMat);
      bird.add(body);

      const leftWing  = new Mesh(wingGeoL, wingMatL);
      leftWing.position.set(-0.35, 0, 0);
      bird.add(leftWing);

      const rightWing = new Mesh(wingGeoR, wingMatR);
      rightWing.position.set(0.35, 0, 0);
      bird.add(rightWing);

      const ox = (R() - 0.5) * 12;   // -6 to +6
      const oy = (R() - 0.5) * 12;
      const oz = (R() - 0.5) * 12;
      bird.position.set(FLOCK_CX + ox, FLOCK_CY + oy, FLOCK_CZ + oz);
      bird.userData = {
        ox, oy, oz,
        speed:    0.3 + R() * 0.4,
        phase:    R() * Math.PI * 2,
        flapSpeed: 2.5 + R() * 2.0,
        flapAmp:   0.25 + R() * 0.20,
      };

      _seagullGroups.push(bird);
      _seagullWingsL.push(leftWing);
      _seagullWingsR.push(rightWing);
      group.add(bird);
    }
  }

  // ── Kelp forest — 12 tall swaying strands near shoreline (C324) ─────────
  {
    const kelpMat = new MeshBasicMaterial({ color: 0x0a1f12 });
    const bulbMat = new MeshBasicMaterial({ color: 0x0a1f12, transparent: true, opacity: 0.7 });
    const R = (): number => Math.random();

    // Scatter indices for bulbs — attach bulbs to strands 0, 3, 7, 10
    const bulbStrandIndices = new Set([0, 3, 7, 10]);

    for (let i = 0; i < 12; i++) {
      const height = 3.5 + R() * 2.0;
      const strand = new Mesh(
        new CylinderGeometry(0.04, 0.08, height, 5),
        kelpMat,
      );
      const sx = -12 + R() * 24;           // x ∈ [-12, 12]
      const sz = -6 + -(R() * 8);          // z ∈ [-6, -14]
      const sy = height / 2 - 0.5;         // base sits on seabed
      strand.position.set(sx, sy, sz);
      strand.userData = {
        swayPhase: R() * Math.PI * 2,
        swaySpeed: 0.5 + R() * 0.7,        // 0.5–1.2
        height,
        baseX: sx,
        baseZ: sz,
      };
      _kelpStrands.push(strand);
      group.add(strand);

      // Bulb at strand top for selected strands
      if (bulbStrandIndices.has(i)) {
        const bulb = new Mesh(new SphereGeometry(0.18, 5, 4), bulbMat);
        bulb.position.set(sx, sy + height / 2, sz);   // starts at strand top
        bulb.userData = { strandIndex: i };
        _kelpBulbs.push(bulb);
        group.add(bulb);
      }
    }
  }

  // ── Underwater caustic light patches on seabed (C332) ───────────────────
  // 8 flat PlaneGeometry patches that simulate light filtering through water.
  // CeltOS charter: 0x0a2a1a (dark teal base), opacity flickers 0.01–0.11.
  {
    const R = (): number => Math.random();
    for (let i = 0; i < 8; i++) {
      const patch = new Mesh(
        new PlaneGeometry(1.2 + R() * 0.8, 0.8 + R() * 0.6),
        new MeshBasicMaterial({ color: 0x0a2a1a, transparent: true, opacity: 0, depthWrite: false }),
      );
      patch.rotation.x = -Math.PI / 2;
      const bx = -10 + R() * 20;   // x ∈ [-10, 10]
      const bz = -5  - R() * 13;   // z ∈ [-5, -18]
      patch.position.set(bx, -0.05, bz);
      patch.userData = {
        baseX: bx,
        baseZ: bz,
        phase: R() * Math.PI * 2,
        speed: 0.8 + R() * 0.7,    // 0.8–1.5 flicker rate
      };
      _causticPatches.push(patch);
      group.add(patch);
    }
  }

  // ── Storm petrel flock — 10 erratic birds at dusk (C340) ───────────────
  {
    const PETREL_CX = 0;
    const PETREL_CY = 5;
    const PETREL_CZ = -30;
    const petrelBodyMat = new MeshBasicMaterial({ color: 0x0c1a10 });
    const petrelWingMat = new MeshBasicMaterial({ color: 0x0c1a10, side: DoubleSide });
    const bodyGeo        = new BoxGeometry(0.04, 0.02, 0.18);
    const wingGeoL       = new BoxGeometry(0.45, 0.02, 0.08);
    const wingGeoR       = new BoxGeometry(0.45, 0.02, 0.08);

    const R = (): number => Math.random();
    for (let i = 0; i < 10; i++) {
      const bird = new Group();

      const body = new Mesh(bodyGeo, petrelBodyMat);
      bird.add(body);

      const leftWing = new Mesh(wingGeoL, petrelWingMat);
      leftWing.position.set(-0.225, 0, 0);
      bird.add(leftWing);

      const rightWing = new Mesh(wingGeoR, petrelWingMat);
      rightWing.position.set(0.225, 0, 0);
      bird.add(rightWing);

      const ox = (R() - 0.5) * 14;   // scatter ±7 around center
      const oy = (R() - 0.5) * 5;    // y offset within 3-8 band
      const oz = (R() - 0.5) * 10;
      bird.position.set(PETREL_CX + ox, PETREL_CY + oy, PETREL_CZ + oz);
      bird.userData = {
        ox, oy, oz,
        speed:       1.2 + R() * 1.3,         // 1.2–2.5
        phase:       R() * Math.PI * 2,
        flapSpeed:   3.5 + R() * 3.0,          // 3.5–6.5
        flapAmp:     0.3 + R() * 0.2,           // 0.3–0.5
        erraticPhase: R() * Math.PI * 2,
      };

      _petrelGroups.push(bird);
      _petrelWingsL.push(leftWing);
      _petrelWingsR.push(rightWing);
      group.add(bird);
    }
  }

  // ── Harbor buoy chain — 5 buoys marking safe harbor entrance (C353) ──────
  // Line from (-15, 0, -10) to (0, 0, -18), 5 evenly spaced buoys.
  {
    const BUOY_COUNT   = 5;
    const START_X      = -15;
    const START_Z      = -10;
    const END_X        =   0;
    const END_Z        = -18;
    const BUOY_COLOR   = 0x0a1a10;
    const BEACON_COLOR = 0x33ff66;
    const buoyMat   = new MeshBasicMaterial({ color: BUOY_COLOR });
    const floatMat  = new MeshBasicMaterial({ color: BUOY_COLOR });
    const chainMat  = new MeshBasicMaterial({ color: BUOY_COLOR, transparent: true, opacity: 0.5 });

    // Compute buoy world positions (will be mutated each frame for bob)
    const buoyBasePos: Array<{ x: number; y: number; z: number }> = [];

    for (let i = 0; i < BUOY_COUNT; i++) {
      const alpha = i / (BUOY_COUNT - 1);
      const bx    = START_X + alpha * (END_X - START_X);
      const bz    = START_Z + alpha * (END_Z - START_Z);
      const by    = 0.05;
      buoyBasePos.push({ x: bx, y: by, z: bz });

      const buoyGroup = new Group();
      buoyGroup.position.set(bx, by, bz);

      // Body
      const body = new Mesh(new CylinderGeometry(0.12, 0.15, 0.35, 6), buoyMat);
      buoyGroup.add(body);

      // Float disk at waterline (y = 0 relative to group)
      const floatDisk = new Mesh(new TorusGeometry(0.18, 0.04, 5, 12), floatMat);
      floatDisk.rotation.x = Math.PI / 2;
      floatDisk.position.y = 0;
      buoyGroup.add(floatDisk);

      // Beacon sphere on top
      const beaconMesh = new Mesh(
        new SphereGeometry(0.06, 5, 3),
        new MeshBasicMaterial({ color: BEACON_COLOR, transparent: true, opacity: 0.7 }),
      );
      beaconMesh.position.y = 0.35 / 2 + 0.06;
      buoyGroup.add(beaconMesh);
      _buoyBeacons.push(beaconMesh);

      // Point light at beacon position
      const beaconLight = new PointLight(BEACON_COLOR, 0.12, 2.5);
      beaconLight.position.y = 0.35 / 2 + 0.06;
      buoyGroup.add(beaconLight);
      _buoyLights.push(beaconLight);

      _buoyGroups.push(buoyGroup);
      group.add(buoyGroup);
    }

    // Chain segments — 4 links connecting adjacent buoys
    // Stored in userData so update() can reorient them each frame
    for (let i = 0; i < BUOY_COUNT - 1; i++) {
      const a = buoyBasePos[i]!;
      const b = buoyBasePos[i + 1]!;
      const dx    = b.x - a.x;
      const dz    = b.z - a.z;
      const dist  = Math.sqrt(dx * dx + dz * dz);
      const midX  = (a.x + b.x) / 2;
      const midZ  = (a.z + b.z) / 2;
      const midY  = (a.y + b.y) / 2;
      const chain = new Mesh(new CylinderGeometry(0.015, 0.015, dist, 4), chainMat);
      chain.position.set(midX, midY, midZ);
      // Orient along the XZ axis: rotate around Z axis by -90° then yaw to match direction
      chain.rotation.x = Math.PI / 2;
      chain.rotation.z = Math.atan2(dx, dz);
      chain.userData['buoyA'] = i;
      chain.userData['buoyB'] = i + 1;
      group.add(chain);
      // Store reference on buoyGroup[i] userData for update
      _buoyGroups[i]!.userData['chainOut'] = chain;
    }
  }

  // ── Sea spray burst particles at cliff base (C359) ───────────────────────
  {
    const SPRAY_COUNT = 40;
    const sprayPos = new Float32Array(SPRAY_COUNT * 3);
    const sprayLife = new Float32Array(SPRAY_COUNT).fill(-1); // -1 = inactive
    const sprayVel: Array<[number, number, number]> = [];
    for (let i = 0; i < SPRAY_COUNT; i++) {
      sprayPos[i * 3] = 0; sprayPos[i * 3 + 1] = -100; sprayPos[i * 3 + 2] = 0; // hide inactive
      sprayVel.push([0, 0, 0]);
    }
    const sprayGeo = new BufferGeometry();
    sprayGeo.setAttribute('position', new BufferAttribute(sprayPos, 3));
    const sprayMat = new PointsMaterial({ color: 0x1a6633, size: 0.08, transparent: true, opacity: 0.35, depthWrite: false });
    sprayPoints359 = new Points(sprayGeo, sprayMat);
    sprayPositions359 = sprayPos;
    sprayVelocities359 = sprayVel;
    sprayLifetimes359 = sprayLife;
    group.add(sprayPoints359);
  }

  // ── Distant whale breach animation (C367) ─────────────────────────────────
  {
    const whaleGeo = new SphereGeometry(0.8, 8, 5);
    whaleGeo.scale(1.0, 0.4, 2.5); // elongated body shape
    const whaleMat = new MeshStandardMaterial({ color: 0x071a07, roughness: 0.9 });
    whaleMesh367 = new Mesh(whaleGeo, whaleMat);
    whaleMesh367.position.set(-12, -2, -28); // far distance, below water
    whaleMesh367.visible = false;
    group.add(whaleMesh367);

    whaleLight367 = new PointLight(0x33ff66, 0.0, 8);
    whaleLight367.position.set(-12, 0, -28);
    group.add(whaleLight367);
  }

  // ── Bioluminescent wave crests (C371) ─────────────────────────────────────
  {
    const crestMat = new MeshBasicMaterial({
      color: 0x0d3a1a, transparent: true, opacity: 0.0, depthWrite: false, side: DoubleSide,
    });
    const WAVE_COUNT = 4;
    for (let i = 0; i < WAVE_COUNT; i++) {
      const crestGeo = new PlaneGeometry(18, 0.12);
      crestGeo.rotateX(-Math.PI / 2);
      const crest = new Mesh(crestGeo, crestMat.clone());
      const startZ = -28 + i * 7;
      crest.position.set(0, -0.55, startZ);
      group.add(crest);
      waveCrests371.push(crest);

      const light = new PointLight(0x33ff66, 0.0, 4.0);
      light.position.set(0, -0.25, startZ);
      group.add(light);
      waveCrestData371.push({ z: startZ, speed: 0.8 + Math.random() * 0.4, light });
    }
  }

  // ── Breaking wave (C395) ──────────────────────────────────────────────────
  {
    waveGroup395 = new Group();

    // Wave face (tall plane, starts flat/invisible)
    const waveFaceGeo = new PlaneGeometry(12, 3.5, 1, 8); // wide, tall
    const waveFaceMat = new MeshBasicMaterial({ color: 0x071f0f, transparent: true, opacity: 0.0, side: DoubleSide, depthWrite: false });
    waveFace395 = new Mesh(waveFaceGeo, waveFaceMat);
    waveFace395.rotation.x = -Math.PI / 2; // start flat (lying on water)
    waveFace395.position.y = 0.1;
    waveGroup395.add(waveFace395);

    // Crest strip (thin bright strip at top of wave)
    const waveCrestGeo = new PlaneGeometry(12, 0.3);
    const waveCrestMat = new MeshBasicMaterial({ color: 0x1a6633, transparent: true, opacity: 0.0, side: DoubleSide, depthWrite: false });
    waveCrest395 = new Mesh(waveCrestGeo, waveCrestMat);
    waveCrest395.position.y = 1.75; // top of wave face
    waveGroup395.add(waveCrest395);

    // Crash flash light
    waveFlashLight395 = new PointLight(0x33ff66, 0.0, 10);
    waveFlashLight395.position.set(0, 2, 0);
    waveGroup395.add(waveFlashLight395);

    waveGroup395.position.set(0, 0, -32);
    group.add(waveGroup395);
    waveWaitT395 = 5.0 + Math.random() * 3.0; // initial wait
  }

  // ── GLB overlays (non-blocking) ───────────────────────────────────────────
  const glbBase = '/assets/';
  const glbConfigs = [
    { file: 'cliff_unified.glb',           pos: [15, -1, -15] as const, scale: 3   },
    { file: 'cabin_unified.glb',           pos: [-5, 0,  -8]  as const, scale: 1.5 },
    { file: 'crystal_cluster_unified.glb', pos: [8,  0,  -3]  as const, scale: 2   },
  ];
  const glbResults = await Promise.allSettled(
    glbConfigs.map(({ file }) => loadGLB(glbBase + file))
  );
  for (let i = 0; i < glbResults.length; i++) {
    const r = glbResults[i];
    const cfg = glbConfigs[i];
    if (r?.status !== 'fulfilled' || !cfg) continue;
    const model = r.value.scene.clone();
    model.traverse((child) => {
      if (child instanceof Mesh && child.material instanceof MeshStandardMaterial) {
        child.material = child.material.clone();
        child.material.flatShading = true;
        child.material.needsUpdate = true;
      }
    });
    model.position.set(cfg.pos[0], cfg.pos[1], cfg.pos[2]);
    model.scale.setScalar(cfg.scale);
    group.add(model);
  }

  // ── Sea turtle (C399) — cotes_sauvages ───────────────────────────────────
  {
    const shellMat = new MeshStandardMaterial({ color: 0x0a2a14, emissive: 0x0d3310, roughness: 0.85, flatShading: true });
    const headMat  = new MeshStandardMaterial({ color: 0x0a2a14, roughness: 0.85, flatShading: true });
    const flipMat  = new MeshStandardMaterial({ color: 0x0a2a14, roughness: 0.85, flatShading: true });

    turtleGroup = new Group();

    // Shell — flattened sphere
    const shell = new Mesh(new SphereGeometry(0.6, 8, 6), shellMat);
    shell.scale.set(1, 0.45, 1.3);
    turtleGroup.add(shell);

    // Head
    const head = new Mesh(new SphereGeometry(0.2, 6, 4), headMat);
    head.position.set(0, 0, 0.8);
    turtleGroup.add(head);

    // Flippers — 4x BoxGeometry(0.5, 0.06, 0.25)
    // Front-left
    const flipFL = new Mesh(new BoxGeometry(0.5, 0.06, 0.25), flipMat.clone());
    flipFL.position.set(-0.55, 0, 0.3);
    flipFL.rotation.y = -0.4;
    turtleGroup.add(flipFL);
    _turtleFrontL = flipFL;

    // Front-right
    const flipFR = new Mesh(new BoxGeometry(0.5, 0.06, 0.25), flipMat.clone());
    flipFR.position.set(0.55, 0, 0.3);
    flipFR.rotation.y = 0.4;
    turtleGroup.add(flipFR);
    _turtleFrontR = flipFR;

    // Rear-left
    const flipRL = new Mesh(new BoxGeometry(0.5, 0.06, 0.25), flipMat.clone());
    flipRL.position.set(-0.5, 0, -0.4);
    flipRL.rotation.y = 0.5;
    turtleGroup.add(flipRL);

    // Rear-right
    const flipRR = new Mesh(new BoxGeometry(0.5, 0.06, 0.25), flipMat.clone());
    flipRR.position.set(0.5, 0, -0.4);
    flipRR.rotation.y = -0.5;
    turtleGroup.add(flipRR);

    turtleGroup.position.set(-8, -0.3, -20);
    group.add(turtleGroup);
  }

  // ── Runtime state ─────────────────────────────────────────────────────────
  let sceneTime = 0;
  let _oceanAltFrame = false;

  // Ocean base positions cached from OceanResult
  const oceanPosAttr = oceanMesh.geometry.attributes['position'] as BufferAttribute;
  const oceanArr = oceanPosAttr.array as Float32Array;

  // ── Update loop ───────────────────────────────────────────────────────────
  const update = (dt: number): void => {
    sceneTime += dt;
    const t = sceneTime;

    // Animated cloud drift — each layer at different speed
    for (const layer of cloudLayers) {
      layer.group.position.x += layer.speed * dt;
      // Wrap cloud layer when fully off screen
      if (layer.group.position.x > 120) layer.group.position.x -= 240;
    }

    // Teal ocean wave animation — faceted flat-shaded vertex displacement
    _oceanAltFrame = !_oceanAltFrame;
    if (!_oceanAltFrame || dt <= 0.033) {
      for (let i = 0; i < oceanPosAttr.count; i++) {
        const bx = oceanBase[i * 3] ?? 0;
        const by = oceanBase[i * 3 + 1] ?? 0;
        // Stronger wave amplitude vs. old scene — more dramatic facets
        const wave =
          Math.sin(bx * 0.10 + t * 1.1) * 1.2 +
          Math.cos(by * 0.08 + t * 0.85) * 0.85 +
          Math.sin((bx + by) * 0.06 + t * 0.6) * 0.5;
        oceanArr[i * 3 + 2] = wave;
      }
      oceanPosAttr.needsUpdate = true;
    }

    // Subtle sun intensity flicker (overcast clouds passing)
    sun.intensity = 1.5 + Math.sin(t * 0.18) * 0.12 + Math.sin(t * 0.43) * 0.06;

    // Lighthouse beam — slow Y-axis rotation of the beam group
    if (_beamGroup !== null) {
      _beamAngle = (_beamAngle + dt * 0.4) % (Math.PI * 2);
      _beamGroup.rotation.y = _beamAngle;
    }

    // Lighthouse lens pulse — slow breathing intensity
    if (lighthouseLight !== null) {
      lighthouseLight.intensity = 0.5 + Math.sin(t * 0.4) * 0.15;

      // Secondary flash when beam passes roughly toward camera (angle ≈ 0 ± 0.3 rad)
      const facingCamera = _beamAngle < 0.3 || _beamAngle > Math.PI * 2 - 0.3;
      if (facingCamera && !_beamFlashed) {
        lighthouseLight.intensity += 0.3;
        _beamFlashed = true;
        // Auto-clear flag after 100 ms so flash doesn't re-trigger until next revolution
        setTimeout(() => { _beamFlashed = false; }, 100);
      } else if (!facingCamera) {
        _beamFlashed = false;
      }
    }

    // Seabird flock soaring
    seabirdFlock.update(t, dt);

    // Tide pool anemone pulse (C273)
    _anemoneTime += dt;
    for (let i = 0; i < _anemoneMeshes.length; i++) {
      const phase = i * 0.8;
      const pulse = 0.9 + Math.sin(_anemoneTime * 1.3 + phase) * 0.12;
      _anemoneMeshes[i]!.scale.set(pulse, 0.8 + Math.sin(_anemoneTime * 0.9 + phase) * 0.15, pulse);
    }

    // Sea foam particle bursts at wave crests (C243)
    _foamTimer += dt;
    if (_foamTimer > 0.15) {
      _foamTimer = 0;
      const inactive = _foamMeshes.find(f => !f.userData['active']);
      if (inactive) {
        inactive.userData['active'] = true;
        inactive.userData['lifetime'] = 0;
        inactive.userData['x'] = (Math.random() - 0.5) * 30;
        inactive.userData['z'] = -8 + (Math.random() - 0.5) * 15;
        inactive.position.set(inactive.userData['x'], 0.1, inactive.userData['z']);
      }
    }
    for (const foam of _foamMeshes) {
      if (!foam.userData['active']) continue;
      foam.userData['lifetime'] += dt;
      const t2 = foam.userData['lifetime'] / foam.userData['maxLife'];
      const opacity = t2 < 0.3 ? (t2 / 0.3) * 0.7 : (1 - (t2 - 0.3) / 0.7) * 0.7;
      (foam.material as MeshBasicMaterial).opacity = Math.max(0, opacity);
      foam.position.y = 0.1 + Math.sin(t2 * Math.PI) * 0.15;
      if (foam.userData['lifetime'] >= foam.userData['maxLife']) {
        foam.userData['active'] = false;
        foam.position.y = -10;
      }
    }

    // Distant fishing boat — gentle bob + slow lateral drift (C293)
    if (_boatGroup !== null) {
      _boatGroup.position.y = 0.2 + Math.sin(t * 0.5) * 0.12;
      _boatGroup.position.x = 10 + Math.sin(t * 0.08) * 1.5;
    }

    // Seagull flock — loose orbital formation with wing flap (C298)
    const fcx = Math.sin(t * 0.15) * 8;
    const fcz = -40 + Math.sin(t * 0.11) * 5;
    for (let i = 0; i < _seagullGroups.length; i++) {
      const bird      = _seagullGroups[i]!;
      const leftWing  = _seagullWingsL[i]!;
      const rightWing = _seagullWingsR[i]!;
      const ud        = bird.userData as { ox: number; oy: number; oz: number; speed: number; phase: number; flapSpeed: number; flapAmp: number };

      const bx = fcx + ud.ox + Math.cos(t * ud.speed + ud.phase) * 3;
      const by = (-5 + 14 + ud.oy) + Math.sin(t * 0.8 + ud.phase) * 0.6;
      const bz = fcz + ud.oz + Math.sin(t * ud.speed + ud.phase) * 2;
      bird.position.set(bx, by, bz);

      leftWing.rotation.z  =  ud.flapAmp * Math.sin(t * ud.flapSpeed + ud.phase);
      rightWing.rotation.z = -ud.flapAmp * Math.sin(t * ud.flapSpeed + ud.phase);

      const vx = Math.cos(t * ud.speed + ud.phase) * ud.speed * 3;
      const vz = Math.cos(t * ud.speed + ud.phase + Math.PI / 2) * ud.speed * 2;
      bird.rotation.y = Math.atan2(vx, vz);
    }

    // Kelp forest sway — seaweed in current (C324)
    for (let i = 0; i < _kelpStrands.length; i++) {
      const strand = _kelpStrands[i]!;
      const sp = strand.userData['swaySpeed'] as number;
      const ph = strand.userData['swayPhase'] as number;
      strand.rotation.z = Math.sin(t * sp + ph) * 0.12;
      strand.rotation.x = Math.cos(t * sp * 0.7 + ph) * 0.06;
    }
    for (let i = 0; i < _kelpBulbs.length; i++) {
      const bulb = _kelpBulbs[i]!;
      const si   = bulb.userData['strandIndex'] as number;
      const strand = _kelpStrands[si];
      if (strand !== undefined) {
        const sp = strand.userData['swaySpeed'] as number;
        const ph = strand.userData['swayPhase'] as number;
        const h  = strand.userData['height'] as number;
        const sy = strand.userData['baseX'] !== undefined ? (h / 2 - 0.5) : 0;
        // Bulb follows strand tip position, accounting for sway rotation
        const swayZ = Math.sin(t * sp + ph) * 0.12 * (h / 2);
        const swayX = Math.cos(t * sp * 0.7 + ph) * 0.06 * (h / 2);
        bulb.position.set(
          (strand.userData['baseX'] as number) + swayX,
          sy + h / 2,
          (strand.userData['baseZ'] as number) + swayZ,
        );
      }
    }

    // Caustic light patches — shimmer + drift + warp (C332)
    for (let i = 0; i < _causticPatches.length; i++) {
      const patch = _causticPatches[i]!;
      const ph    = patch.userData['phase'] as number;
      const sp    = patch.userData['speed'] as number;
      const bx    = patch.userData['baseX'] as number;
      const bz    = patch.userData['baseZ'] as number;

      // Opacity flicker: 0.01–0.11
      (patch.material as MeshBasicMaterial).opacity = Math.max(0, 0.06 + Math.sin(t * sp + ph) * 0.05);

      // Slight underwater current drift on X
      patch.position.x = bx + Math.sin(t * 0.3 + ph) * 0.3;
      patch.position.z = bz;

      // Scale pulse — patches warp like real caustics
      patch.scale.x = 1.0 + Math.sin(t * sp * 1.3 + ph) * 0.15;
      patch.scale.z = 1.0 + Math.cos(t * sp * 0.9 + ph) * 0.12;
    }

    // Tide pool crab scuttle + water shimmer (C308)
    if (_crabGroup !== null) {
      _crabGroup.position.x = 5.8 + Math.sin(t * 0.35) * 0.3;
      _crabGroup.position.z = -8.2 + Math.cos(t * 0.28) * 0.2;
      _crabGroup.rotation.y = Math.sin(t * 0.35) * 0.4;
    }
    if (_tidePoolLight !== null) {
      _tidePoolLight.intensity = 0.05 + Math.sin(t * 1.1) * 0.03;
    }

    // Storm petrel flock — dusk-only erratic swarm (C340)
    const petrelsVisible = _currentTimeOfDay === 'dusk';
    for (let i = 0; i < _petrelGroups.length; i++) {
      const bird      = _petrelGroups[i]!;
      const leftWing  = _petrelWingsL[i]!;
      const rightWing = _petrelWingsR[i]!;
      bird.visible = petrelsVisible;
      if (!petrelsVisible) continue;

      const ud = bird.userData as {
        ox: number; oy: number; oz: number;
        speed: number; phase: number;
        flapSpeed: number; flapAmp: number;
        erraticPhase: number;
      };

      // Swarm center drifts slowly
      const pcx = Math.sin(t * 0.3) * 12;
      const pcz = -30 + Math.sin(t * 0.2) * 8;

      // Per-bird erratic position: orbital + chaotic secondary jitter
      const bx = pcx + ud.ox + Math.cos(t * ud.speed + ud.phase) * 4 + Math.sin(t * 3.1 + ud.erraticPhase) * 1.5;
      const by = (5 + ud.oy) + Math.sin(t * ud.speed * 0.7 + ud.phase) * 0.8;
      const bz = pcz + ud.oz + Math.sin(t * ud.speed + ud.phase) * 3;
      bird.position.set(bx, by, bz);

      // Fast flap
      leftWing.rotation.z  =  ud.flapAmp * Math.sin(t * ud.flapSpeed + ud.phase);
      rightWing.rotation.z = -ud.flapAmp * Math.sin(t * ud.flapSpeed + ud.phase);

      // Direction from velocity
      const vx = -Math.sin(t * ud.speed + ud.phase) * ud.speed * 4 + Math.cos(t * 3.1 + ud.erraticPhase) * 3.1 * 1.5;
      const vz =  Math.cos(t * ud.speed + ud.phase) * ud.speed * 3;
      bird.rotation.y = Math.atan2(vx, vz);
    }

    // Harbor buoy bob + beacon flash + chain stretch (C353)
    for (let i = 0; i < _buoyGroups.length; i++) {
      const buoy        = _buoyGroups[i]!;
      const beaconLight = _buoyLights[i]!;
      const bobY        = 0.05 + Math.sin(t * 0.8 + i * 0.6) * 0.08;
      buoy.position.y   = bobY;

      // Beacon intensity flash
      beaconLight.intensity = 0.08 + Math.sin(t * 2.5 + i * 1.2) * 0.06;

      // Update outgoing chain midpoint Y to follow buoy bob
      const chainOut = buoy.userData['chainOut'] as Mesh | undefined;
      if (chainOut !== undefined) {
        const nextBuoy = _buoyGroups[i + 1];
        if (nextBuoy !== undefined) {
          const midY = (bobY + nextBuoy.position.y) / 2;
          chainOut.position.y = midY;
        }
      }
    }

    // Sea spray burst particles at cliff base (C359)
    if (sprayPoints359 !== null && sprayPositions359 !== null && sprayLifetimes359 !== null) {
      // Burst timer
      sprayNextBurst359 -= dt;
      if (sprayNextBurst359 <= 0) {
        sprayNextBurst359 = 3.0 + Math.random() * 2.0;
        const burstX = (Math.random() - 0.5) * 12; // along cliff base
        const burstZ = -18 + Math.random() * 3;     // near cliffs
        let launched = 0;
        for (let i = 0; i < 40 && launched < 10; i++) {
          if (sprayLifetimes359[i]! < 0) {
            sprayLifetimes359[i] = 1.2 + Math.random() * 0.4;
            sprayPositions359[i * 3]     = burstX + (Math.random() - 0.5) * 0.5;
            sprayPositions359[i * 3 + 1] = 0.2;
            sprayPositions359[i * 3 + 2] = burstZ + (Math.random() - 0.5) * 0.5;
            sprayVelocities359[i] = [
              (Math.random() - 0.5) * 0.8,
              1.5 + Math.random() * 1.2,
              (Math.random() - 0.5) * 0.8,
            ];
            launched++;
          }
        }
      }

      // Update particles
      const GRAVITY = -3.0;
      let anyActive = false;
      for (let i = 0; i < 40; i++) {
        if (sprayLifetimes359[i]! < 0) continue;
        anyActive = true;
        sprayLifetimes359[i] -= dt;
        if (sprayLifetimes359[i]! <= 0) {
          sprayLifetimes359[i] = -1;
          sprayPositions359[i * 3 + 1] = -100; // hide
          continue;
        }
        const vel = sprayVelocities359[i]!;
        vel[1] += GRAVITY * dt;
        sprayPositions359[i * 3]     += vel[0] * dt;
        sprayPositions359[i * 3 + 1] += vel[1] * dt;
        sprayPositions359[i * 3 + 2] += vel[2] * dt;
      }
      if (anyActive || sprayNextBurst359 < 0.5) {
        (sprayPoints359.geometry as BufferGeometry).attributes['position']!.needsUpdate = true;
      }
    }

    // Whale breach timer (C367)
    whaleNext367 -= dt;
    if (whaleNext367 <= 0 && whaleBreach367T < 0) {
      whaleBreach367T = 0;
      whaleNext367 = 20.0 + Math.random() * 15.0;
      if (whaleMesh367) whaleMesh367.visible = true;
    }

    if (whaleBreach367T >= 0 && whaleMesh367) {
      whaleBreach367T += dt;
      const t = whaleBreach367T;

      if (t < 0.8) {
        // Rising phase
        const rise = Math.sin((t / 0.8) * Math.PI * 0.5);
        whaleMesh367.position.y = -2 + rise * 5;
        whaleMesh367.rotation.z = rise * 0.4; // arc lean
      } else if (t < 1.5) {
        // Falling phase
        const fall = (t - 0.8) / 0.7;
        whaleMesh367.position.y = 3 - fall * 5;
        whaleMesh367.rotation.z = 0.4 - fall * 0.6;
        // Splash light on entry
        if (whaleMesh367.position.y < 0.5 && whaleLight367) {
          whaleLight367.intensity = Math.max(0, (0.5 - whaleMesh367.position.y) / 0.5) * 0.4;
        }
      } else {
        // Done
        whaleMesh367.visible = false;
        whaleMesh367.position.y = -2;
        whaleMesh367.rotation.z = 0;
        if (whaleLight367) whaleLight367.intensity = 0;
        whaleBreach367T = -1;
      }
    }

    // ── Bioluminescent wave crests (C371) ───────────────────────────────────
    waveCrests371.forEach((crest, i) => {
      const data = waveCrestData371[i];
      if (!data) return;
      data.z += data.speed * dt;

      if (data.z > -2) {
        data.z = -28 - Math.random() * 4;
        data.speed = 0.8 + Math.random() * 0.4;
      }

      crest.position.z = data.z;
      data.light.position.z = data.z;

      const distToShore = Math.abs(data.z - (-2));
      const breakZone = 6.0;
      if (distToShore < breakZone) {
        const brightness = Math.pow(1.0 - distToShore / breakZone, 2);
        (crest.material as MeshBasicMaterial).opacity = brightness * 0.45;
        data.light.intensity = brightness * 0.2;
      } else {
        (crest.material as MeshBasicMaterial).opacity = 0.0;
        data.light.intensity = 0.0;
      }
    });

    // ── Sea turtle swimming (C399) ────────────────────────────────────────
    if (turtleGroup !== null) {
      turtleT += dt * 0.3 * turtleDir;
      turtleGroup.position.x = -8 + Math.sin(turtleT * 0.5) * 3;
      turtleGroup.position.y = Math.sin(turtleT) * 0.15 - 0.3;
      turtleGroup.rotation.y = Math.sin(turtleT * 0.5) * 0.3;
      if (_turtleFrontL !== null) _turtleFrontL.rotation.z =  Math.sin(turtleT * 3) * 0.3;
      if (_turtleFrontR !== null) _turtleFrontR.rotation.z = -Math.sin(turtleT * 3) * 0.3;
      if (turtleT > 12)  turtleDir = -1;
      if (turtleT < -12) turtleDir =  1;
    }

    // ── Breaking wave (C395) ────────────────────────────────────────────────
    if (waveFace395 && waveCrest395 && waveFlashLight395) {
      const faceMat = waveFace395.material as MeshBasicMaterial;
      const crestMat = waveCrest395.material as MeshBasicMaterial;

      if (wavePhase395 === 0) {
        // Waiting
        waveWaitT395 -= dt;
        faceMat.opacity = 0;
        crestMat.opacity = 0;
        waveFlashLight395.intensity = 0;
        if (waveWaitT395 <= 0) { wavePhase395 = 1; wavePhaseT395 = 0; }

      } else if (wavePhase395 === 1) {
        // Rising (1.5s): rotate face from flat to vertical
        wavePhaseT395 += dt;
        const t = Math.min(wavePhaseT395 / 1.5, 1.0);
        waveFace395.rotation.x = -Math.PI / 2 + t * (Math.PI / 2); // flat → vertical
        faceMat.opacity = t * 0.45;
        crestMat.opacity = t * 0.4;
        if (wavePhaseT395 >= 1.5) { wavePhase395 = 2; wavePhaseT395 = 0; }

      } else if (wavePhase395 === 2) {
        // Curling (0.5s): top rotates forward
        wavePhaseT395 += dt;
        const t = Math.min(wavePhaseT395 / 0.5, 1.0);
        waveFace395.rotation.x = t * 0.4; // slight forward lean
        faceMat.opacity = 0.45 + t * 0.1;
        crestMat.opacity = 0.4 + t * 0.3;
        if (wavePhaseT395 >= 0.5) { wavePhase395 = 3; wavePhaseT395 = 0; }

      } else if (wavePhase395 === 3) {
        // Crash (0.5s): flash + face falls
        wavePhaseT395 += dt;
        const t = Math.min(wavePhaseT395 / 0.5, 1.0);
        waveFlashLight395.intensity = Math.sin(t * Math.PI) * 0.35;
        faceMat.opacity = 0.55 * (1 - t);
        crestMat.opacity = 0.7 * (1 - t);
        waveFace395.rotation.x = 0.4 + t * 1.2;
        if (wavePhaseT395 >= 0.5) { wavePhase395 = 4; wavePhaseT395 = 0; }

      } else if (wavePhase395 === 4) {
        // Dissipate (0.8s)
        wavePhaseT395 += dt;
        faceMat.opacity = 0;
        crestMat.opacity = 0;
        waveFlashLight395.intensity = Math.max(0, 0.1 * (1 - wavePhaseT395 / 0.8));
        if (wavePhaseT395 >= 0.8) {
          wavePhase395 = 0;
          waveWaitT395 = 8.0 + Math.random() * 4.0;
          waveFace395.rotation.x = -Math.PI / 2; // reset to flat
        }
      }
    }
  };

  // ── Dispose ───────────────────────────────────────────────────────────────
  const dispose = (): void => {
    const seenMaterials = new Set<Material>();
    group.traverse((child) => {
      if (child instanceof Mesh) {
        child.geometry.dispose();
        if (Array.isArray(child.material)) {
          child.material.forEach((m) => seenMaterials.add(m));
        } else {
          seenMaterials.add(child.material as Material);
        }
      }
      if (child instanceof DirectionalLight && child.shadow.map) {
        child.shadow.map.dispose();
      }
    });
    seenMaterials.forEach((m) => m.dispose());
    for (const mat of seabirdFlock.birdMats) {
      mat.dispose();
    }
    _foamMeshes = [];
    _anemoneMeshes = [];
    _boatGroup = null;
    _crabGroup = null;
    _tidePoolLight = null;
    _beamGroup = null;
    _beamCone = null;
    lighthouseBeamMesh = null;
    lighthouseLight = null;
    lighthouseMesh = null;
    _seagullGroups.length = 0;
    _seagullWingsL.length = 0;
    _seagullWingsR.length = 0;
    _kelpStrands.length = 0;
    _kelpBulbs.length = 0;
    _causticPatches.length = 0;
    _petrelGroups.length = 0;
    _petrelWingsL.length = 0;
    _petrelWingsR.length = 0;
    _buoyGroups.length   = 0;
    _buoyBeacons.length  = 0;
    _buoyLights.length   = 0;
    if (sprayPoints359 !== null) {
      group.remove(sprayPoints359);
      sprayPoints359.geometry.dispose();
      (sprayPoints359.material as PointsMaterial).dispose();
      sprayPoints359 = null;
    }
    sprayPositions359 = null;
    sprayVelocities359 = [];
    sprayLifetimes359 = null;
    if (whaleMesh367) { group.remove(whaleMesh367); whaleMesh367.geometry.dispose(); (whaleMesh367.material as MeshStandardMaterial).dispose(); whaleMesh367 = null; }
    if (whaleLight367) { group.remove(whaleLight367); whaleLight367.dispose(); whaleLight367 = null; }
    waveCrests371.forEach(c => {
      group.remove(c);
      c.geometry.dispose();
      (c.material as MeshBasicMaterial).dispose();
    });
    waveCrests371 = [];
    waveCrestData371.forEach(d => { group.remove(d.light); d.light.dispose(); });
    waveCrestData371 = [];
    if (waveGroup395) {
      group.remove(waveGroup395);
      waveGroup395.traverse(c => { if ((c as Mesh).geometry) (c as Mesh).geometry.dispose(); if ((c as Mesh).material) ((c as Mesh).material as MeshBasicMaterial).dispose(); });
      waveGroup395 = null;
    }
    waveFace395 = null; waveCrest395 = null;
    if (waveFlashLight395) { waveFlashLight395.dispose(); waveFlashLight395 = null; }
    if (turtleGroup !== null) {
      turtleGroup.traverse(c => {
        if ((c as Mesh).geometry) (c as Mesh).geometry.dispose();
        if ((c as Mesh).material) ((c as Mesh).material as MeshStandardMaterial).dispose();
      });
      group.remove(turtleGroup);
      turtleGroup = null;
    }
    _turtleFrontL = null;
    _turtleFrontR = null;
    group.clear();
  };

  return { group, update, dispose };
}
