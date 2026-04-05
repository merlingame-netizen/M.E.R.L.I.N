// ═══════════════════════════════════════════════════════════════════════════════
// Coast Biome — ISO low-poly coastal scene (C161 visual overhaul)
// Reference: dramatic cliff + teal faceted ocean + layered flat-shaded clouds.
// ═══════════════════════════════════════════════════════════════════════════════

import {
  AmbientLight, BackSide, BoxGeometry, BufferAttribute, BufferGeometry, CircleGeometry, Color,
  ConeGeometry, CylinderGeometry, DirectionalLight,
  DodecahedronGeometry, DoubleSide, Float32BufferAttribute, Group, HemisphereLight,
  Line, LineBasicMaterial,
  Material, Mesh, MeshBasicMaterial, MeshStandardMaterial, PlaneGeometry, PointLight, Points,
  PointsMaterial, SphereGeometry, SpotLight,
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

// ── Lighthouse rotating beacon — cotes_sauvages (C404) ────────────────────
let lighthouseGroup404: Group | null = null;
let lighthouseBeaconLight404: SpotLight | null = null;
let lighthouseT404 = 0;

// ── Sea cave with bioluminescent algae — cotes_sauvages (C411) ─────────────
let seaCaveGroup411: Group | null = null;
let seaCaveT411 = 0;
let seaCaveLight411: PointLight | null = null;
const seaCaveAlgae411: Mesh[] = [];

// ── Dolphin pod leaping — cotes_sauvages (C415) ───────────────────────────
const dolphinPod415: Group[] = [];
const dolphinT415: number[] = [0, 2.2, 4.4];

// ── Sunken ship mast — cotes_sauvages (C420) ──────────────────────────────
let shipMastGroup420: Group | null = null;
let shipMastT420 = 0;
const shipSeaweed420: Mesh[] = [];

// ── Whale tail breach — cotes_sauvages (C444) ─────────────────────────────
let whaleGroup444: Group | null = null;
let whaleT444: number = 0;
let whaleTimer444: number = 30;
let whaleBreaching444: boolean = false;
let whaleCycle444: number = 0;
const whaleSplashParticles444: Mesh[] = [];

// ── Bioluminescent jellyfish cluster (C449) ────────────────────────────────
let jellyfishGroup449: Group | null = null;
let jellyfishT449: number = 0;
const jellyfishBells449: Mesh[] = [];
const jellyfishData449: { ox: number; oz: number; phase: number; speed: number }[] = [];

// ── Underwater kelp forest (C454) ─────────────────────────────────────────
let kelpGroup454: Group | null = null;
let kelpT454: number = 0;
const kelpStalks454: Mesh[][] = [];

// ── Drowned city ruins — Ker-Is (C459) ────────────────────────────────────
let ruinsGroup459: Group | null = null;
let ruinsT459: number = 0;
const ruinsMossPatches459: Mesh[] = [];

// ── Sea stack with circling seabirds (C464) ───────────────────────────────
let seaStackGroup464: Group | null = null;
let seaStackT464: number = 0;
const seaStackBirds464: Group[] = [];

// ── Ancient surf menhir (C469) ────────────────────────────────────────────
let surfMenhirGroup469: Group | null = null;
let surfMenhirT469: number = 0;
let surfMenhirFoamMat469: MeshBasicMaterial | null = null;
const surfMenhirGlyphs469: Mesh[] = [];
let surfMenhirWaveTimer469: number = 25;

// ── Bioluminescent plankton bloom (C474) ──────────────────────────────────
let planktonGroup474: Group | null = null;
let planktonT474: number = 0;
const planktonParticles474: Mesh[] = [];
// Store per-particle data inline via userData

// ── Bioluminescent fish school (C479) ─────────────────────────────────────
let fishSchoolGroup479: Group | null = null;
let fishSchoolT479: number = 0;
const fishBodies479: Group[] = [];
// Leader position (computed each frame)
let fishLeaderX479: number = 0;
let fishLeaderY479: number = -1.5;
let fishLeaderZ479: number = -6;

// ── Tide pools with starfish and anemones (C484) ──────────────────────────
let t484: number = 0;
let crabTimer484: number = 15 + Math.random() * 10;
let crabActive484: boolean = false;
let crabProgress484: number = 0;
const tidePoolGroup484: Group[] = [];
const tidePoolWaterMats484: MeshStandardMaterial[] = [];
const starfishMeshes484: Mesh[] = [];
const anemonteTentacles484: { mesh: Mesh; phase: number; poolIdx: number }[] = [];
const crabMeshes484: Mesh[] = [];
const crabStartPos484: [number, number, number][] = [];
const crabEndPos484: [number, number, number][] = [];

// ── Sunken shipwreck hull (C489) ──────────────────────────────────────────
let wreckGroup489: Group | null = null;
let t489: number = 0;
const wreckKelpMeshes489: Mesh[] = [];
let wreckLight489: PointLight | null = null;
let wreckHullMat489: MeshStandardMaterial | null = null;
let wreckGhostTimer489: number = 25 + Math.random() * 15;
let wreckGhostActive489: boolean = false;
let wreckGhostT489: number = 0;

// ── Dolphin pod leaping (C499) ────────────────────────────────────────────
let dolphinGroup499: Group | null = null;
let t499: number = 0;
const dolphins499: Group[] = [];

interface DolphinState499 {
  leaping: boolean;
  leapT: number;
  interval: number;
  timer: number;
  startX: number;
  startY: number;
  startZ: number;
  heading: number;
}
const dolphinStates499: DolphinState499[] = [];
const dolphinTimers499: number[] = [];
const dolphinTs499: number[] = [];
const splashPool499: Mesh[] = [];

// ── Sea serpent breach (C494) ─────────────────────────────────────────────
let serpentGroup494: Group | null = null;
let t494: number = 0;
type SerpentState494 = 'hidden' | 'rising' | 'hang' | 'diving';
let serpentState494: SerpentState494 = 'hidden';
let serpentStateT494: number = 0;
let serpentTimer494: number = 20 + Math.random() * 15;
const splashParticles494: Mesh[] = [];
const serpentSegMats494: MeshStandardMaterial[] = [];

// ── Mermaid silhouette glimpsed through a wave (C504) ─────────────────────
let mermaidGroup504: Group | null = null;
let t504: number = 0;
type MermaidState504 = 'hidden' | 'approach' | 'hover' | 'retreat';
let mermaidState504: MermaidState504 = 'hidden';
let mermaidStateT504: number = 0;
let mermaidTimer504: number = 25 + Math.random() * 15;
const mermaidMats504: MeshStandardMaterial[] = [];
let mermaidLight504: PointLight | null = null;
let mermaidTailMesh504: Mesh | null = null;
let mermaidTailFluke504: Group | null = null;
const mermaidHairMeshes504: Mesh[] = [];
const mermaidArmMeshes504: { mesh: Mesh; side: 1 | -1 }[] = [];

// ── Ancient sea altar emerging at low tide (C509) ────────────────────────
let altarSeaGroup509: Group | null = null;

// ── Deep jellyfish bloom rising from the depths (C514) ───────────────────
let deepJellyGroup514: Group | null = null;
let t514: number = 0;
const deepJellies514: Group[] = [];
const deepJellyBellMats514: MeshStandardMaterial[] = [];
type DeepJellyState514 = 'resting' | 'rising' | 'hover' | 'sinking';
let deepJellyState514: DeepJellyState514 = 'resting';
let deepJellyStateT514: number = 0;
let deepJellyTimer514: number = 50 + Math.random() * 20;
const deepJellyBaseYs514: number[] = [];
const deepJellyTargetYs514: number[] = [];
let t509: number = 0;
type AltarSeaState509 = 'submerged' | 'rising' | 'emerged' | 'sinking';
let altarSeaState509: AltarSeaState509 = 'submerged';
let altarSeaStateT509: number = 0;
let altarSeaTimer509: number = 35 + Math.random() * 20;
const altarSeaRuneMats509: MeshStandardMaterial[] = [];
let altarSeaLight509: PointLight | null = null;
const altarSeaDroplets509: Mesh[] = [];
const altarSeaBaseY509: number = -1.2;
let altarSeaPeakSFX509: boolean = false;

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

  // ── Lighthouse rotating beacon (C404) — cotes_sauvages ───────────────────
  {
    lighthouseGroup404 = new Group();

    // Base
    const baseMat = new MeshStandardMaterial({ color: 0x0a1a10, roughness: 0.9, flatShading: true });
    const base = new Mesh(new CylinderGeometry(0.8, 1.0, 1.2, 8), baseMat);
    base.position.set(0, 0.6, 0);
    lighthouseGroup404.add(base);

    // Tower
    const towerMat = new MeshStandardMaterial({ color: 0x0a1a10, roughness: 0.85, flatShading: true });
    const tower = new Mesh(new CylinderGeometry(0.4, 0.6, 8, 8), towerMat);
    tower.position.set(0, 4, 0);
    lighthouseGroup404.add(tower);

    // Tower top cap
    const capMat = new MeshStandardMaterial({ color: 0x0d2a14, roughness: 0.8, flatShading: true });
    const cap = new Mesh(new CylinderGeometry(0.7, 0.7, 0.3, 8), capMat);
    cap.position.set(0, 8.15, 0);
    lighthouseGroup404.add(cap);

    // Lantern housing
    const lanternMat = new MeshStandardMaterial({ color: 0x0a2a14, emissive: 0x0d3310, roughness: 0.7, flatShading: true });
    const lantern = new Mesh(new CylinderGeometry(0.35, 0.35, 0.6, 8), lanternMat);
    lantern.position.set(0, 8.6, 0);
    lighthouseGroup404.add(lantern);

    // Beacon point light — starts off, pulses during rotation
    const beaconPoint = new PointLight(0x33ff66, 0.0, 18.0);
    beaconPoint.position.set(0, 8.6, 0);
    lighthouseGroup404.add(beaconPoint);

    // SpotLight — narrow rotating beam
    const spot = new SpotLight(0x33ff66, 0.6, 40, Math.PI * 0.04, 0.3);
    spot.position.set(0, 8.6, 0);
    lighthouseBeaconLight404 = spot;
    lighthouseGroup404.add(spot);

    lighthouseGroup404.position.set(14, 0, -35);
    group.add(lighthouseGroup404);
  }

  // ── Sea cave with bioluminescent algae (C411) — cotes_sauvages ────────────
  {
    seaCaveGroup411 = new Group();

    // Left rock wall
    const leftWallGeo = new BoxGeometry(1.2, 4, 1.5);
    const rockMat = new MeshBasicMaterial({ color: 0x0a1a10 });
    const leftWall = new Mesh(leftWallGeo, rockMat);
    leftWall.position.set(-1.6, 2, 0);
    seaCaveGroup411.add(leftWall);

    // Right rock wall
    const rightWallGeo = new BoxGeometry(1.2, 4, 1.5);
    const rightWall = new Mesh(rightWallGeo, new MeshBasicMaterial({ color: 0x0a1a10 }));
    rightWall.position.set(1.6, 2, 0);
    seaCaveGroup411.add(rightWall);

    // Arch top
    const archGeo = new BoxGeometry(4.5, 1.2, 1.5);
    const arch = new Mesh(archGeo, new MeshBasicMaterial({ color: 0x0a1a10 }));
    arch.position.set(0, 4.6, 0);
    seaCaveGroup411.add(arch);

    // Cave dark interior
    const interiorGeo = new PlaneGeometry(3.0, 4.0);
    const interior = new Mesh(interiorGeo, new MeshBasicMaterial({ color: 0x010501, opacity: 0.97, transparent: true }));
    interior.position.set(0, 2, 0.2);
    interior.rotation.y = Math.PI;
    seaCaveGroup411.add(interior);

    // 8 algae patches on interior walls
    const caveGroupRef = seaCaveGroup411!;
    const leftAlgaeYs = [0.8, 1.5, 2.2, 3.0];
    const rightAlgaeYs = [1.0, 1.8, 2.5, 3.2];
    leftAlgaeYs.forEach(y => {
      const geo = new PlaneGeometry(0.3, 0.4);
      const mat = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.4 });
      const patch = new Mesh(geo, mat);
      patch.position.set(-1.1, y, 0.3);
      patch.rotation.y = Math.PI / 2;
      caveGroupRef.add(patch);
      seaCaveAlgae411.push(patch);
    });
    rightAlgaeYs.forEach(y => {
      const geo = new PlaneGeometry(0.3, 0.4);
      const mat = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.4 });
      const patch = new Mesh(geo, mat);
      patch.position.set(1.1, y, 0.3);
      patch.rotation.y = -Math.PI / 2;
      caveGroupRef.add(patch);
      seaCaveAlgae411.push(patch);
    });

    // Inner glow
    const glow = new PointLight(0x33ff66, 0.3, 5.0);
    glow.position.set(0, 1.5, 0.5);
    seaCaveLight411 = glow;
    seaCaveGroup411.add(glow);

    seaCaveGroup411.position.set(-18, 0, -30);
    group.add(seaCaveGroup411);
  }

  // ── Dolphin pod leaping (C415) — cotes_sauvages ───────────────────────────
  {
    const bodyMat    = new MeshBasicMaterial({ color: 0x0a2a14 });
    const finMat     = new MeshBasicMaterial({ color: 0x0a2a14 });
    const flukeMat   = new MeshBasicMaterial({ color: 0x0a2a14 });
    const snoutMat   = new MeshBasicMaterial({ color: 0x0a2a14 });

    // Build template dolphin
    const templateDolphin = new Group();

    const bodyGeo = new SphereGeometry(0.3, 8, 5);
    const bodyMesh = new Mesh(bodyGeo, bodyMat);
    bodyMesh.scale.set(1, 0.55, 2.2);
    templateDolphin.add(bodyMesh);

    const dorsalGeo = new ConeGeometry(0.08, 0.25, 4);
    const dorsalMesh = new Mesh(dorsalGeo, finMat);
    dorsalMesh.position.set(0, 0.22, -0.1);
    templateDolphin.add(dorsalMesh);

    const flukeGeo = new BoxGeometry(0.45, 0.06, 0.12);
    const flukeMesh = new Mesh(flukeGeo, flukeMat);
    flukeMesh.position.set(0, 0, -0.65);
    flukeMesh.rotation.x = 0.3;
    templateDolphin.add(flukeMesh);

    const snoutGeo = new ConeGeometry(0.07, 0.22, 5);
    const snoutMesh = new Mesh(snoutGeo, snoutMat);
    snoutMesh.position.set(0, 0.03, 0.7);
    snoutMesh.rotation.x = -1.55;
    templateDolphin.add(snoutMesh);

    for (let i = 0; i < 3; i++) {
      const dolphin = templateDolphin.clone();
      dolphin.position.set(6 + i * 1.2, -0.5, -25 - i * 0.8);
      dolphinPod415.push(dolphin);
      dolphinT415[i] = i * 2.2;
      group.add(dolphin);
    }
  }

  // ── Sunken ship mast (C420) — cotes_sauvages ─────────────────────────────
  {
    shipMastGroup420 = new Group();
    const darkWoodMat = new MeshBasicMaterial({ color: 0x0a1a10 });

    // Main mast — tilted cylinder
    const mastGeo = new CylinderGeometry(0.08, 0.12, 5.5, 6);
    const mastMesh = new Mesh(mastGeo, darkWoodMat);
    mastMesh.position.set(0, 2.75, 0);
    mastMesh.rotation.z = 0.12;
    shipMastGroup420.add(mastMesh);

    // Yardarm — horizontal crossbar
    const yardGeo = new CylinderGeometry(0.05, 0.07, 3.8, 5);
    const yardMesh = new Mesh(yardGeo, darkWoodMat);
    yardMesh.position.set(0, 4.8, 0);
    yardMesh.rotation.z = Math.PI / 2;
    shipMastGroup420.add(yardMesh);

    // Crow's nest
    const nestGeo = new CylinderGeometry(0.3, 0.3, 0.2, 8, 1, false);
    const nestMesh = new Mesh(nestGeo, darkWoodMat);
    nestMesh.position.set(0, 3.8, 0);
    shipMastGroup420.add(nestMesh);

    // Tattered sail remnant
    const sailGeo = new PlaneGeometry(1.5, 1.2);
    const sailMat = new MeshBasicMaterial({ color: 0x0a1a10, transparent: true, opacity: 0.6, side: DoubleSide });
    const sailMesh = new Mesh(sailGeo, sailMat);
    sailMesh.position.set(-0.5, 4.0, 0);
    shipMastGroup420.add(sailMesh);

    // Rigging ropes — 3 angled lines from mast top to yardarm ends
    const ropeAngles = [-0.8, 0.0, 0.8];
    for (let i = 0; i < 3; i++) {
      const ropeGeo = new CylinderGeometry(0.015, 0.015, 2.2, 3);
      const ropeMesh = new Mesh(ropeGeo, darkWoodMat);
      ropeMesh.position.set(ropeAngles[i]! * 0.9, 4.6, 0);
      ropeMesh.rotation.z = ropeAngles[i]! * 0.5;
      shipMastGroup420.add(ropeMesh);
    }

    // 6 seaweed strands hanging from yardarm
    const seaweedMat = new MeshBasicMaterial({ color: 0x0d2a14, transparent: true, opacity: 0.8 });
    const seaweedXPositions = [-1.6, -0.96, -0.32, 0.32, 0.96, 1.6];
    for (let i = 0; i < 6; i++) {
      const weedGeo = new CylinderGeometry(0.02, 0.02, 0.6, 3);
      const weedMesh = new Mesh(weedGeo, seaweedMat.clone());
      weedMesh.position.set(seaweedXPositions[i]!, 4.5, 0);
      shipMastGroup420.add(weedMesh);
      shipSeaweed420.push(weedMesh);
    }

    // Ambient depth shimmer point light
    const depthLight = new PointLight(0x33ff66, 0.04, 6.0);
    depthLight.position.set(0, 1.0, 0);
    shipMastGroup420.add(depthLight);

    shipMastGroup420.position.set(-6, -1, -38);
    group.add(shipMastGroup420);
  }

  // ── Whale tail breach (C444) — cotes_sauvages ─────────────────────────────
  {
    whaleGroup444 = new Group();

    // Left fluke
    const leftFluke = new Mesh(
      new SphereGeometry(1.2, 6, 4),
      new MeshBasicMaterial({ color: 0x0a2a14 })
    );
    leftFluke.scale.set(1.0, 0.15, 0.6);
    leftFluke.position.set(-0.8, 0, 0);
    leftFluke.rotation.z = Math.PI * 0.1;
    whaleGroup444.add(leftFluke);

    // Right fluke
    const rightFluke = leftFluke.clone();
    rightFluke.position.set(0.8, 0, 0);
    rightFluke.rotation.z = -Math.PI * 0.1;
    whaleGroup444.add(rightFluke);

    // Tail peduncle (connecting body part)
    const peduncle = new Mesh(
      new CylinderGeometry(0.25, 0.35, 1.0, 8),
      new MeshBasicMaterial({ color: 0x0a2a14 })
    );
    peduncle.position.set(0, -0.5, 0);
    whaleGroup444.add(peduncle);

    // 6 splash droplets spread around base
    const splashMat = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0 });
    const splashOffsets = [
      [-0.9, 0, 0.5], [0.9, 0, 0.5], [0, 0, -0.8],
      [-0.6, 0, -0.4], [0.6, 0, -0.4], [0, 0, 0.9],
    ];
    for (let i = 0; i < 6; i++) {
      const dropMesh = new Mesh(
        new SphereGeometry(0.06, 4, 3),
        splashMat.clone()
      );
      dropMesh.position.set(
        splashOffsets[i]![0],
        splashOffsets[i]![1],
        splashOffsets[i]![2]
      );
      whaleGroup444.add(dropMesh);
      whaleSplashParticles444.push(dropMesh);
    }

    whaleGroup444.position.set(8, -3, -10);
    group.add(whaleGroup444);
  }

  // ── Bioluminescent jellyfish cluster (C449) ────────────────────────────────
  {
    jellyfishGroup449 = new Group();
    jellyfishGroup449.position.set(-5, -1, -8);
    const _jg449 = jellyfishGroup449;

    const jConfigs = [
      { x: 0,    y: 0,    z: 0,    phase: 0,   speed: 0.9 },
      { x: 1.5,  y: 0.3,  z: -1,   phase: 1.0, speed: 1.1 },
      { x: -1.2, y: -0.2, z: -0.8, phase: 2.1, speed: 0.8 },
      { x: 0.8,  y: 0.5,  z: 1.2,  phase: 3.2, speed: 1.0 },
      { x: -0.5, y: -0.4, z: 1.5,  phase: 4.0, speed: 1.2 },
      { x: 2.0,  y: 0.1,  z: 0.5,  phase: 5.1, speed: 0.7 },
    ];

    jConfigs.forEach((cfg) => {
      const jGroup = new Group();
      jGroup.position.set(cfg.x, cfg.y, cfg.z);

      // Bell: flattened sphere for jellyfish dome
      const bell = new Mesh(
        new SphereGeometry(0.22, 8, 6),
        new MeshBasicMaterial({ color: 0x0a2a14, transparent: true, opacity: 0.55 })
      );
      bell.scale.y = 0.45;
      jGroup.add(bell);
      jellyfishBells449.push(bell);

      // Glow rim: torus around bell equator
      const rim = new Mesh(
        new TorusGeometry(0.22, 0.025, 4, 16),
        new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.8 })
      );
      rim.position.y = -0.05;
      jGroup.add(rim);

      // 4 tentacles hanging down
      for (let t = 0; t < 4; t++) {
        const tAngle = (t / 4) * Math.PI * 2;
        const tPoints: number[] = [];
        for (let s = 0; s <= 6; s++) {
          tPoints.push(
            Math.cos(tAngle) * 0.1 * (1 - s / 8),
            -s * 0.12,
            Math.sin(tAngle) * 0.1 * (1 - s / 8)
          );
        }
        const tGeo = new BufferGeometry();
        tGeo.setAttribute('position', new Float32BufferAttribute(tPoints, 3));
        const tentacle = new Line(tGeo, new LineBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.35 }));
        jGroup.add(tentacle);
      }

      // Point light per jellyfish
      const jLight = new PointLight(0x33ff66, 0.08, 2.0);
      jGroup.add(jLight);

      _jg449.add(jGroup);
      jellyfishData449.push({ ox: cfg.x, oz: cfg.z, phase: cfg.phase, speed: cfg.speed });
    });

    group.add(jellyfishGroup449);
  }

  // ── Underwater kelp forest (C454) ─────────────────────────────────────────
  {
    kelpGroup454 = new Group();
    kelpGroup454.position.set(3, -2, -12);

    const kelpPositions: [number, number][] = [
      [-1.5, 0], [-0.5, 0.8], [0.5, -0.5], [1.5, 0.3],
      [2.2, -0.8], [-2.2, 0.5], [0, 1.5], [-1.0, -1.2],
      [1.0, 1.0], [2.8, 0.2],
    ];

    kelpPositions.forEach(([kx, kz]) => {
      const stalkHeight = 1.5 + Math.random() * 1.5;
      const segCount = 4;
      const segHeight = stalkHeight / segCount;
      const stalk: Mesh[] = [];

      for (let s = 0; s < segCount; s++) {
        const isTop = s === segCount - 1;
        const seg = new Mesh(
          new CylinderGeometry(isTop ? 0.03 : 0.05, 0.06, segHeight, 4),
          new MeshBasicMaterial({
            color: isTop ? 0x33ff66 : 0x0d2a14,
            transparent: true,
            opacity: isTop ? 0.8 : 0.9,
          })
        );
        seg.position.set(kx, s * segHeight + segHeight * 0.5, kz);
        stalk.push(seg);
        kelpGroup454!.add(seg);
      }

      kelpStalks454.push(stalk);

      const tipLight = new PointLight(0x33ff66, 0.05, 1.5);
      tipLight.position.set(kx, stalkHeight, kz);
      kelpGroup454!.add(tipLight);
    });

    group.add(kelpGroup454);
  }

  // ── Drowned city ruins — Ker-Is (C459) ────────────────────────────────────
  {
    ruinsGroup459 = new Group();
    ruinsGroup459.position.set(-8, -1.5, -15);

    // Column definitions: [x, z, height, radius]
    const columnDefs = [
      { x: 0,   z: 0,   h: 3.5, r: 0.35 },  // tall
      { x: 2.5, z: -1,  h: 2.0, r: 0.3  },  // medium
      { x: -2,  z: 0.5, h: 1.2, r: 0.25 },  // short (broken)
      { x: 3.5, z: 1.5, h: 4.0, r: 0.38 },  // arch left pillar
      { x: 5.5, z: 1.5, h: 4.0, r: 0.38 },  // arch right pillar
    ];

    columnDefs.forEach((def) => {
      // Column shaft
      const col = new Mesh(
        new CylinderGeometry(def.r * 0.85, def.r, def.h, 8),
        new MeshBasicMaterial({ color: 0x0a1a10 })
      );
      col.position.set(def.x, def.h / 2, def.z);
      ruinsGroup459!.add(col);

      // Capital (top slab)
      const capital = new Mesh(
        new BoxGeometry(def.r * 2.4, 0.18, def.r * 2.4),
        new MeshBasicMaterial({ color: 0x0a1a10 })
      );
      capital.position.set(def.x, def.h + 0.09, def.z);
      ruinsGroup459!.add(capital);

      // 2 moss patches per column
      for (let m = 0; m < 2; m++) {
        const moss = new Mesh(
          new SphereGeometry(0.1 + Math.random() * 0.08, 5, 4),
          new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.4 })
        );
        moss.scale.y = 0.25;
        moss.position.set(
          def.x + (Math.random() - 0.5) * def.r * 1.5,
          0.5 + Math.random() * (def.h - 0.5),
          def.z + (Math.random() - 0.5) * def.r * 1.5
        );
        ruinsMossPatches459.push(moss);
        ruinsGroup459!.add(moss);
      }
    });

    // Archway lintel between columns 4 and 5
    const lintel = new Mesh(
      new BoxGeometry(2.3, 0.25, 0.7),
      new MeshBasicMaterial({ color: 0x0a1a10 })
    );
    lintel.position.set(4.5, 4.12, 1.5);
    ruinsGroup459!.add(lintel);

    // Scattered rubble: 4 broken pieces on the ground
    for (let i = 0; i < 4; i++) {
      const rubble = new Mesh(
        new BoxGeometry(0.3 + Math.random() * 0.4, 0.15, 0.2 + Math.random() * 0.3),
        new MeshBasicMaterial({ color: 0x0a1a10 })
      );
      rubble.position.set(-1 + i * 1.2, 0.08, -0.5 + Math.random() * 1.0);
      rubble.rotation.y = Math.random() * Math.PI;
      ruinsGroup459!.add(rubble);
    }

    // Ambient ruin light
    const ruinLight = new PointLight(0x33ff66, 0.1, 6.0);
    ruinLight.position.set(2, 2, 0);
    ruinsGroup459!.add(ruinLight);

    group.add(ruinsGroup459);
  }

  // ── Sea stack with circling seabirds (C464) ───────────────────────────────
  {
    seaStackGroup464 = new Group();
    seaStackGroup464.position.set(12, -0.5, -18);

    // Sea stack main column (tapered cylinder)
    const stackBase = new Mesh(
      new CylinderGeometry(1.2, 1.6, 1.5, 8),
      new MeshBasicMaterial({ color: 0x0a1a10 })
    );
    stackBase.position.y = 0.75;
    seaStackGroup464.add(stackBase);

    const stackMid = new Mesh(
      new CylinderGeometry(0.9, 1.2, 2.5, 8),
      new MeshBasicMaterial({ color: 0x0a1a10 })
    );
    stackMid.position.y = 2.75;
    seaStackGroup464.add(stackMid);

    const stackTop = new Mesh(
      new CylinderGeometry(0.6, 0.9, 2.0, 7),
      new MeshBasicMaterial({ color: 0x0a1a10 })
    );
    stackTop.position.y = 5.0;
    seaStackGroup464.add(stackTop);

    // Flat top platform
    const topPlatform = new Mesh(
      new CylinderGeometry(0.65, 0.65, 0.25, 8),
      new MeshBasicMaterial({ color: 0x0a1a10 })
    );
    topPlatform.position.y = 6.13;
    seaStackGroup464.add(topPlatform);

    // Sea foam ring at base (dark green, not white)
    const foam = new Mesh(
      new TorusGeometry(1.55, 0.18, 4, 16),
      new MeshBasicMaterial({ color: 0x0d2a14, transparent: true, opacity: 0.6 })
    );
    foam.rotation.x = Math.PI * 0.5;
    foam.position.y = 0.08;
    seaStackGroup464.add(foam);

    // 6 circling birds at varying heights/radii
    const birdConfigs = [
      { orbitR: 3.5, orbitY: 7.0, orbitSpeed: 0.5,  phase: 0   },
      { orbitR: 4.2, orbitY: 5.5, orbitSpeed: 0.4,  phase: 1.0 },
      { orbitR: 3.0, orbitY: 8.5, orbitSpeed: 0.6,  phase: 2.1 },
      { orbitR: 5.0, orbitY: 6.5, orbitSpeed: 0.35, phase: 3.2 },
      { orbitR: 3.8, orbitY: 9.0, orbitSpeed: 0.55, phase: 4.3 },
      { orbitR: 4.5, orbitY: 7.8, orbitSpeed: 0.45, phase: 5.4 },
    ];

    birdConfigs.forEach((cfg) => {
      const birdGroup = new Group();

      // Body
      const body = new Mesh(
        new BoxGeometry(0.12, 0.06, 0.35),
        new MeshBasicMaterial({ color: 0x020f04 })
      );
      birdGroup.add(body);

      // Wings (two small planes)
      const leftWing = new Mesh(
        new PlaneGeometry(0.35, 0.08),
        new MeshBasicMaterial({ color: 0x020f04, side: DoubleSide })
      );
      leftWing.position.set(-0.2, 0, 0);
      leftWing.rotation.z = Math.PI * 0.1;
      birdGroup.add(leftWing);

      const rightWing = leftWing.clone();
      rightWing.position.set(0.2, 0, 0);
      rightWing.rotation.z = -Math.PI * 0.1;
      birdGroup.add(rightWing);

      // Initial position
      birdGroup.position.set(cfg.orbitR, cfg.orbitY, 0);

      seaStackGroup464!.add(birdGroup);
      seaStackBirds464.push(birdGroup);
      // Store config in userData
      (birdGroup as any).orbitR = cfg.orbitR;
      (birdGroup as any).orbitY = cfg.orbitY;
      (birdGroup as any).orbitSpeed = cfg.orbitSpeed;
      (birdGroup as any).phase = cfg.phase;
    });

    group.add(seaStackGroup464);
  }

  // ── Ancient surf menhir (C469) ────────────────────────────────────────────
  {
    surfMenhirGroup469 = new Group();
    surfMenhirGroup469.position.set(-4, -1.0, -6);

    // Main menhir shaft — tall tapered box
    const menhirShaft = new Mesh(
      new BoxGeometry(0.85, 5.5, 0.65),
      new MeshBasicMaterial({ color: 0x0a1a10 })
    );
    menhirShaft.position.y = 2.75;
    // Slight lean
    menhirShaft.rotation.z = 0.04;
    surfMenhirGroup469!.add(menhirShaft);

    // Wider base (submerged section)
    const menhirBase = new Mesh(
      new BoxGeometry(1.1, 1.5, 0.85),
      new MeshBasicMaterial({ color: 0x0a1a10 })
    );
    menhirBase.position.y = 0.0;
    surfMenhirGroup469!.add(menhirBase);

    // 6 Ogham glyph planes on front face — vertical column
    for (let i = 0; i < 6; i++) {
      const glyph = new Mesh(
        new PlaneGeometry(0.12, 0.2),
        new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.55 })
      );
      glyph.position.set(0.33, 0.8 + i * 0.6, 0);
      surfMenhirGlyphs469.push(glyph);
      surfMenhirGroup469!.add(glyph);
    }

    // Algae/barnacle patches (dark green spheres, flattened)
    for (let i = 0; i < 5; i++) {
      const patch = new Mesh(
        new SphereGeometry(0.1 + Math.random() * 0.07, 4, 3),
        new MeshBasicMaterial({ color: 0x0d2a14 })
      );
      patch.scale.y = 0.3;
      patch.position.set(
        (Math.random() - 0.5) * 0.7,
        -0.3 + Math.random() * 0.8,
        0.35
      );
      surfMenhirGroup469!.add(patch);
    }

    // Surf foam ring at water line
    const menhirFoam = new Mesh(
      new TorusGeometry(0.75, 0.12, 4, 16),
      new MeshBasicMaterial({ color: 0x0d2a14, transparent: true, opacity: 0.5 })
    );
    menhirFoam.rotation.x = Math.PI * 0.5;
    menhirFoam.position.y = 0.05;
    surfMenhirFoamMat469 = menhirFoam.material as MeshBasicMaterial;
    surfMenhirGroup469!.add(menhirFoam);

    // Glow light
    const menhirLight = new PointLight(0x33ff66, 0.12, 5.0);
    menhirLight.position.set(0, 2.0, 0.5);
    surfMenhirGroup469!.add(menhirLight);

    group.add(surfMenhirGroup469);
  }

  // ── Bioluminescent plankton bloom (C474) ──────────────────────────────────
  {
    planktonGroup474 = new Group();
    planktonGroup474.position.set(0, -0.5, -8);  // ocean surface area

    for (let i = 0; i < 40; i++) {
      const p = new Mesh(
        new SphereGeometry(0.035, 3, 3),
        new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.0 })
      );
      // Random spread in a flat volume (ocean surface layer)
      p.position.set(
        (Math.random() - 0.5) * 14,
        -0.1 + (Math.random() - 0.5) * 0.4,
        (Math.random() - 0.5) * 8
      );
      // Store drift data
      (p as any).__px = p.position.x;
      (p as any).__pz = p.position.z;
      (p as any).__phase = Math.random() * Math.PI * 2;
      (p as any).__speed = 0.15 + Math.random() * 0.25;
      (p as any).__pulseSpeed = 0.8 + Math.random() * 1.5;
      (p as any).__driftX = (Math.random() - 0.5) * 0.3;
      (p as any).__driftZ = (Math.random() - 0.5) * 0.2;

      planktonParticles474.push(p);
      planktonGroup474!.add(p);
    }

    group.add(planktonGroup474);
  }

  // ── Bioluminescent fish school (C479) ───────────────────────────────────
  {
    fishSchoolGroup479 = new Group();
    fishSchoolGroup479.position.set(-2, 0, -6);

    for (let i = 0; i < 20; i++) {
      const fishGroup = new Group();

      // Body: elongated box
      const body = new Mesh(
        new BoxGeometry(0.08, 0.05, 0.2),
        new MeshBasicMaterial({ color: 0x0d2a14 })
      );
      fishGroup.add(body);

      // Tail fin: small plane angled at back
      const tail = new Mesh(
        new PlaneGeometry(0.06, 0.08),
        new MeshBasicMaterial({ color: 0x0d2a14, side: DoubleSide })
      );
      tail.position.z = 0.12;
      tail.rotation.y = Math.PI * 0.5;
      fishGroup.add(tail);

      // Bioluminescent stripe (thin plane on body side)
      const stripe = new Mesh(
        new PlaneGeometry(0.16, 0.018),
        new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.7, side: DoubleSide })
      );
      stripe.position.y = 0.018;
      fishGroup.add(stripe);

      // Scatter loosely around school center
      fishGroup.position.set(
        (Math.random() - 0.5) * 3,
        -1.0 + (Math.random() - 0.5) * 1.0,
        (Math.random() - 0.5) * 3
      );

      // Store school offset (each fish has a slightly different target offset from leader)
      (fishGroup as any).__offsetX = (Math.random() - 0.5) * 2.0;
      (fishGroup as any).__offsetY = (Math.random() - 0.5) * 0.8;
      (fishGroup as any).__offsetZ = (Math.random() - 0.5) * 2.0;
      (fishGroup as any).__phase = Math.random() * Math.PI * 2;
      (fishGroup as any).__tailPhase = Math.random() * Math.PI * 2;

      fishSchoolGroup479!.add(fishGroup);
      fishBodies479.push(fishGroup);
    }

    group.add(fishSchoolGroup479);
  }

  // ── Tide pools with starfish and anemones (C484) ──────────────────────────
  {
    const poolPositions: [number, number, number][] = [
      [6, 0.01, -5],
      [8, 0.01, -8],
    ];

    const waterMat = new MeshStandardMaterial({
      color: 0x0a1a10,
      emissive: 0x0a3320,
      emissiveIntensity: 0.3,
      transparent: true,
      opacity: 0.85,
      metalness: 0.1,
      roughness: 0.0,
    });

    const starfishMat = new MeshStandardMaterial({
      color: 0x1a4428,
      emissive: 0x33ff66,
      emissiveIntensity: 0.5,
      flatShading: true,
    });

    const anemoneBodyMat = new MeshStandardMaterial({
      color: 0x0d3322,
      emissive: 0x33ff66,
      emissiveIntensity: 0.7,
      flatShading: true,
    });

    poolPositions.forEach((pos, poolIdx) => {
      const poolGroup = new Group();
      poolGroup.position.set(pos[0], pos[1], pos[2]);

      // Water disc
      const poolRadius = 0.8 + Math.random() * 0.4;
      const waterMesh = new Mesh(
        new CylinderGeometry(poolRadius, poolRadius, 0.05, 16),
        waterMat.clone(),
      );
      waterMesh.position.y = 0;
      poolGroup.add(waterMesh);
      tidePoolWaterMats484.push(waterMesh.material as MeshStandardMaterial);

      // 3 starfish per pool
      for (let s = 0; s < 3; s++) {
        const starGroup = new Group();
        const angle = (s / 3) * Math.PI * 2;
        const r = 0.3 + Math.random() * 0.35;
        starGroup.position.set(
          Math.cos(angle) * r,
          0.04,
          Math.sin(angle) * r,
        );
        // 5 arms at 72° intervals, each tilted 90° to lie flat
        for (let a = 0; a < 5; a++) {
          const armAngle = (a / 5) * Math.PI * 2;
          const arm = new Mesh(
            new ConeGeometry(0.04, 0.25, 4),
            starfishMat,
          );
          arm.rotation.z = Math.PI / 2; // lie flat
          arm.rotation.y = armAngle;
          arm.position.set(
            Math.cos(armAngle) * 0.1,
            0,
            Math.sin(armAngle) * 0.1,
          );
          starGroup.add(arm);
        }
        poolGroup.add(starGroup);
        // Store the group container as a Mesh-like for Y rotation animation
        (starGroup as any).__poolIdx = poolIdx;
        starfishMeshes484.push(starGroup as unknown as Mesh);
      }

      // 4 sea anemones per pool
      for (let an = 0; an < 4; an++) {
        const anemoneGroup = new Group();
        const angle = (an / 4) * Math.PI * 2 + 0.4;
        const r = 0.4 + Math.random() * 0.3;
        anemoneGroup.position.set(
          Math.cos(angle) * r,
          0.04,
          Math.sin(angle) * r,
        );

        // Central stalk
        const stalk = new Mesh(
          new CylinderGeometry(0.03, 0.05, 0.15, 5),
          anemoneBodyMat,
        );
        stalk.position.y = 0.075;
        anemoneGroup.add(stalk);

        // 6 tentacles splayed at top
        for (let tt = 0; tt < 6; tt++) {
          const tentAngle = (tt / 6) * Math.PI * 2;
          const tentacle = new Mesh(
            new ConeGeometry(0.02, 0.12, 3),
            anemoneBodyMat,
          );
          tentacle.position.set(
            Math.cos(tentAngle) * 0.04,
            0.15,
            Math.sin(tentAngle) * 0.04,
          );
          // Tilt outward from center
          tentacle.rotation.z = 0.5;
          tentacle.rotation.y = tentAngle;
          anemoneGroup.add(tentacle);
          anemonteTentacles484.push({
            mesh: tentacle,
            phase: Math.random() * Math.PI * 2,
            poolIdx,
          });
        }

        poolGroup.add(anemoneGroup);
      }

      // Hermit crab (hidden initially)
      const crab = new Mesh(
        new BoxGeometry(0.08, 0.06, 0.06),
        new MeshStandardMaterial({
          color: 0x1a3a28,
          emissive: 0x224433,
          emissiveIntensity: 0.3,
          flatShading: true,
        }),
      );
      crab.visible = false;
      crab.position.y = 0.04;
      poolGroup.add(crab);
      crabMeshes484.push(crab);
      // Edge-to-edge start/end within pool radius
      const cr = (poolRadius - 0.12);
      const startA = Math.random() * Math.PI * 2;
      const endA = startA + Math.PI + (Math.random() - 0.5) * 0.8;
      crabStartPos484.push([Math.cos(startA) * cr, 0.04, Math.sin(startA) * cr]);
      crabEndPos484.push([Math.cos(endA) * cr, 0.04, Math.sin(endA) * cr]);

      group.add(poolGroup);
      tidePoolGroup484.push(poolGroup);
    });
  }

  // ── Sunken shipwreck hull (C489) ──────────────────────────────────────────
  {
    wreckGroup489 = new Group();

    // Hull main body
    wreckHullMat489 = new MeshStandardMaterial({
      color: 0x0a1a0a,
      roughness: 0.95,
      metalness: 0.0,
      flatShading: true,
      emissive: 0x0a1a0a,
      emissiveIntensity: 0.0,
    });
    const hull489 = new Mesh(new BoxGeometry(3.0, 1.2, 0.8), wreckHullMat489);
    wreckGroup489.add(hull489);

    // Hull bottom keel — curved cylinder, rotated 90° on Z
    const keelMat = new MeshStandardMaterial({
      color: 0x0a1a0a, roughness: 0.95, metalness: 0.0, flatShading: true,
    });
    const keel489 = new Mesh(new CylinderGeometry(0.4, 0.5, 3.0, 6, 1, true), keelMat);
    keel489.rotation.z = Math.PI / 2;
    keel489.position.y = -0.5;
    const _wg489 = wreckGroup489;
    _wg489.add(keel489);

    // 3 broken ribs
    const ribMat = new MeshStandardMaterial({
      color: 0x0a1a0a, roughness: 0.95, metalness: 0.0, flatShading: true,
    });
    const ribOffsets: [number, number][] = [[-1.0, -0.15], [0.0, 0.0], [1.0, 0.15]];
    ribOffsets.forEach(([rx, rz]) => {
      const rib = new Mesh(new BoxGeometry(0.05, 1.0, 0.05), ribMat);
      rib.position.set(rx, 0.5, rz * 0.1);
      rib.rotation.z = rz === 0 ? 0.0 : rz < 0 ? -0.26 : 0.26;
      _wg489.add(rib);
    });

    // Broken mast stump
    const mastMat = new MeshStandardMaterial({
      color: 0x0a1a0a, roughness: 0.95, metalness: 0.0, flatShading: true,
    });
    const mast489 = new Mesh(new CylinderGeometry(0.08, 0.1, 1.5, 6), mastMat);
    mast489.position.set(1.2, 0.6, 0.0);
    mast489.rotation.z = 0.436; // ~25°
    _wg489.add(mast489);

    // 6 barnacle clusters
    const barnMat = new MeshStandardMaterial({
      color: 0x0d1f0d, roughness: 0.95, metalness: 0.0, flatShading: true,
    });
    const barnPositions: [number, number, number][] = [
      [-1.2, -0.3, 0.35], [-0.4, -0.4, -0.35], [0.3, -0.3, 0.35],
      [1.0, -0.4, -0.35], [-0.8, 0.4, 0.35], [0.6, 0.4, -0.35],
    ];
    barnPositions.forEach(([bx, by, bz]) => {
      const barnacle = new Mesh(new SphereGeometry(0.08, 5, 5), barnMat);
      barnacle.scale.y = 0.4;
      barnacle.position.set(bx, by, bz);
      _wg489.add(barnacle);
    });

    // Interior glow point light
    wreckLight489 = new PointLight(0x33ff66, 0.5, 4.0);
    wreckLight489.position.set(0, 0, 0);
    _wg489.add(wreckLight489);

    // 4 kelp wisps
    const kelpMat489 = new MeshStandardMaterial({
      color: 0x0a2a14,
      side: DoubleSide,
      transparent: true,
      opacity: 0.6,
      roughness: 0.95,
      metalness: 0.0,
      emissive: 0x1a5522,
      emissiveIntensity: 0.4,
    });
    const kelpPhases489: number[] = [0.0, 1.57, 3.14, 4.71];
    kelpPhases489.forEach((phase, i) => {
      const wisp = new Mesh(new PlaneGeometry(0.1, 0.8), kelpMat489);
      const angle = (i / 4) * Math.PI * 2;
      wisp.position.set(Math.cos(angle) * 1.2, 0.2, Math.sin(angle) * 0.3);
      (wisp as any).__kelpPhase489 = phase;
      wreckKelpMeshes489.push(wisp);
      _wg489.add(wisp);
    });

    _wg489.position.set(-10, -0.4, -8);
    group.add(_wg489);
  }

  // ── Dolphin pod leaping (C499) ────────────────────────────────────────────
  {
    dolphinGroup499 = new Group();

    const dolphinMat = new MeshStandardMaterial({
      color: 0x0a2a14,
      emissive: 0x1a4428,
      emissiveIntensity: 0.2,
      roughness: 0.6,
    });

    // Splash particle pool — 4 dolphins × 4 particles each = 16 total
    const splashGeo = new SphereGeometry(0.05, 4, 3);
    for (let i = 0; i < 16; i++) {
      const sp = new Mesh(splashGeo, new MeshStandardMaterial({
        color: 0x1a4060,
        transparent: true,
        opacity: 0.0,
        roughness: 0.8,
      }));
      sp.position.set(0, -50, 0);
      splashPool499.push(sp);
      dolphinGroup499.add(sp);
    }

    const startPositions: [number, number, number, number][] = [
      [-2, 0, -15, 0.3],
      [ 0, 0, -18, -0.2],
      [ 3, 0, -14, 0.5],
      [-4, 0, -20, 0.1],
    ];
    // Stagger initial timers so dolphins leap at different times
    const initialIntervals = [14, 17, 12, 19];

    for (let i = 0; i < 4; i++) {
      const cfg = startPositions[i]!;
      const dolphin = new Group();

      // Body — elongated cylinder, horizontal
      const body = new Mesh(
        new CylinderGeometry(0.1, 0.05, 0.7, 8),
        dolphinMat.clone(),
      );
      body.rotation.z = Math.PI / 2; // horizontal
      dolphin.add(body);

      // Nose cone — at front (+X after rotation)
      const nose = new Mesh(
        new ConeGeometry(0.07, 0.2, 6),
        dolphinMat.clone(),
      );
      nose.rotation.z = -Math.PI / 2;
      nose.position.set(0.45, 0, 0);
      dolphin.add(nose);

      // Dorsal fin — on top, tilted slightly back
      const dorsal = new Mesh(
        new ConeGeometry(0.04, 0.18, 4),
        dolphinMat.clone(),
      );
      dorsal.position.set(0, 0.1, 0);
      dorsal.rotation.z = -0.25;
      dolphin.add(dorsal);

      // Tail flukes — 2 planes angled left/right at rear
      const flukeMat = new MeshStandardMaterial({
        color: 0x0a2a14,
        emissive: 0x1a4428,
        emissiveIntensity: 0.2,
        roughness: 0.6,
        side: DoubleSide,
      });
      const flukeL = new Mesh(new PlaneGeometry(0.15, 0.1), flukeMat);
      flukeL.position.set(-0.38, 0, 0);
      flukeL.rotation.y = 0.4;
      dolphin.add(flukeL);

      const flukeR = new Mesh(new PlaneGeometry(0.15, 0.1), flukeMat.clone());
      flukeR.position.set(-0.38, 0, 0);
      flukeR.rotation.y = -0.4;
      dolphin.add(flukeR);

      dolphin.position.set(cfg[0], cfg[1], cfg[2]);
      dolphin.rotation.y = cfg[3];
      dolphin.visible = false;
      dolphins499.push(dolphin);
      dolphinGroup499.add(dolphin);

      const interval = initialIntervals[i]!;
      dolphinStates499.push({
        leaping: false,
        leapT: 0,
        interval,
        timer: i * 4 + 2, // stagger initial delays
        startX: cfg[0],
        startY: 0,
        startZ: cfg[2],
        heading: cfg[3],
      });
      dolphinTimers499.push(i * 4 + 2);
      dolphinTs499.push(0);
    }

    group.add(dolphinGroup499);
  }

  // ── Sea serpent breach (C494) ─────────────────────────────────────────────
  {
    serpentGroup494 = new Group();
    serpentGroup494.position.set(5, 0, -12);
    serpentGroup494.visible = false;

    const segRadii: number[] = [0.25, 0.22, 0.20, 0.17, 0.13, 0.08];
    // Pre-computed arc positions and Y-rotations for each segment
    const segPositions: [number, number, number][] = [
      [-2.0, 0.0, 0],
      [-1.2, 2.0, 0],
      [-0.3, 3.5, 0],
      [ 0.6, 3.8, 0],
      [ 1.5, 2.5, 0],
      [ 2.2, 0.5, 0],
    ];
    // Z-rotation (radians): head tilts 60° up, tail tilts 60° down
    const segRotZ: number[] = [
      -Math.PI / 3,   // seg0 head: 60° forward/up
      -Math.PI / 6,   // seg1: 30° up
       0.0,           // seg2: near horizontal
       0.0,           // seg3: peak
       Math.PI / 6,   // seg4: 30° down
       Math.PI / 3,   // seg5 tail: 60° down
    ];
    const roughnessAlternating: number[] = [0.6, 0.8, 0.6, 0.8, 0.6, 0.8];

    for (let i = 0; i < 6; i++) {
      const r = segRadii[i]!;
      const mat = new MeshStandardMaterial({
        color: 0x0a2a14,
        emissive: 0x1a4428,
        emissiveIntensity: 0.3,
        roughness: roughnessAlternating[i]!,
        metalness: 0.0,
        flatShading: true,
      });
      serpentSegMats494.push(mat);

      const segMesh = new Mesh(new CylinderGeometry(r * 0.85, r, 0.7, 8), mat);
      const pos = segPositions[i]!;
      segMesh.position.set(pos[0], pos[1], pos[2]);
      segMesh.rotation.z = segRotZ[i]!;
      serpentGroup494.add(segMesh);
    }

    // Head cap — SphereGeometry at seg0 front
    const headCapMat = new MeshStandardMaterial({
      color: 0x0a2a14, emissive: 0x1a4428, emissiveIntensity: 0.3,
      roughness: 0.7, metalness: 0.0, flatShading: true,
    });
    serpentSegMats494.push(headCapMat);
    const headCap = new Mesh(new SphereGeometry(0.25, 8, 6), headCapMat);
    const headPos = segPositions[0]!;
    headCap.position.set(headPos[0] - 0.3, headPos[1] + 0.1, headPos[2]);
    serpentGroup494.add(headCap);

    // Eyes — 2 small emissive spheres
    const eyeMat = new MeshStandardMaterial({
      color: 0x33ff66, emissive: 0x33ff66, emissiveIntensity: 1.0, roughness: 0.3,
    });
    serpentSegMats494.push(eyeMat);
    const eyeL = new Mesh(new SphereGeometry(0.04, 5, 4), eyeMat);
    eyeL.position.set(headPos[0] - 0.52, headPos[1] + 0.2, headPos[2] + 0.12);
    serpentGroup494.add(eyeL);
    const eyeR = new Mesh(new SphereGeometry(0.04, 5, 4), eyeMat.clone());
    eyeR.position.set(headPos[0] - 0.52, headPos[1] + 0.2, headPos[2] - 0.12);
    serpentGroup494.add(eyeR);

    // Splash particles — 8 small spheres, placed at group origin (water surface)
    const splashMat = new MeshStandardMaterial({
      color: 0x1a4060, emissive: 0x0a2040, emissiveIntensity: 0.2,
      roughness: 0.8, transparent: true, opacity: 0.0,
    });
    for (let i = 0; i < 8; i++) {
      const sp = new Mesh(new SphereGeometry(0.06, 4, 4), splashMat.clone());
      const angle = (i / 8) * Math.PI * 2;
      sp.position.set(Math.cos(angle) * 0.8, 0, Math.sin(angle) * 0.4);
      (sp as any).__spAngle494 = angle;
      (sp as any).__spSpeed494 = 1.5 + Math.random() * 1.0;
      splashParticles494.push(sp);
      serpentGroup494.add(sp);
    }

    group.add(serpentGroup494);
  }

  // ── Mermaid silhouette glimpsed through a wave (C504) ─────────────────────
  {
    mermaidGroup504 = new Group();
    mermaidMats504.length = 0;
    mermaidHairMeshes504.length = 0;
    mermaidArmMeshes504.length = 0;

    const makeMat504 = (): MeshStandardMaterial => {
      const m = new MeshStandardMaterial({
        color: 0x0a2a14,
        emissive: 0x33ff66,
        emissiveIntensity: 0.9,
        transparent: true,
        opacity: 0.0,
      });
      mermaidMats504.push(m);
      return m;
    };

    // Torso
    const torso = new Mesh(new CylinderGeometry(0.06, 0.1, 0.45, 6), makeMat504());
    torso.position.set(0, 0, 0);
    mermaidGroup504.add(torso);

    // Head
    const head = new Mesh(new SphereGeometry(0.1, 7, 6), makeMat504());
    head.position.set(0, 0.325, 0);
    mermaidGroup504.add(head);

    // Arms (2) — angled outward at ±40° from torso sides
    for (const side of [-1, 1] as const) {
      const arm = new Mesh(new CylinderGeometry(0.025, 0.03, 0.3, 4), makeMat504());
      arm.rotation.z = side * (40 * Math.PI / 180);
      arm.position.set(side * 0.14, 0.08, 0);
      mermaidGroup504.add(arm);
      mermaidArmMeshes504.push({ mesh: arm, side });
    }

    // Tail — below torso, tapering down
    const tail = new Mesh(new CylinderGeometry(0.09, 0.04, 0.5, 6), makeMat504());
    tail.position.set(0, -0.475, 0);
    mermaidGroup504.add(tail);
    mermaidTailMesh504 = tail;

    // Tail fluke — 2 PlaneGeometry angled into a V at tail tip
    const flukeGroup = new Group();
    flukeGroup.position.set(0, -0.725, 0);
    for (const angle of [-0.4, 0.4]) {
      const fluke = new Mesh(new PlaneGeometry(0.2, 0.12), makeMat504());
      (fluke.material as MeshStandardMaterial).side = DoubleSide;
      fluke.rotation.y = angle;
      flukeGroup.add(fluke);
    }
    mermaidGroup504.add(flukeGroup);
    mermaidTailFluke504 = flukeGroup;

    // Long hair — 4 strands flowing upward/backward from head
    for (let h = 0; h < 4; h++) {
      const hair = new Mesh(new CylinderGeometry(0.015, 0.005, 0.4, 4), makeMat504());
      const angleOffset = (h / 4) * Math.PI * 0.6 - 0.15;
      hair.position.set(
        Math.sin(angleOffset) * 0.07,
        0.38 + 0.2,
        Math.cos(angleOffset) * 0.04 - 0.06,
      );
      hair.rotation.z = (h % 2 === 0 ? 1 : -1) * 0.15;
      hair.rotation.x = -0.2;
      mermaidGroup504.add(hair);
      mermaidHairMeshes504.push(hair);
    }

    // Faint PointLight inside group
    mermaidLight504 = new PointLight(0x33ff66, 0.0, 4.0);
    mermaidLight504.position.set(0, 0, 0);
    mermaidGroup504.add(mermaidLight504);

    // Position: just below water surface (negative Y), far into scene
    mermaidGroup504.position.set(-6, -1.5, -10);
    group.add(mermaidGroup504);
  }

  // ── Ancient sea altar emerging at low tide (C509) ────────────────────────
  {
    altarSeaGroup509 = new Group();
    altarSeaRuneMats509.length = 0;
    altarSeaDroplets509.length = 0;
    altarSeaPeakSFX509 = false;
    altarSeaState509 = 'submerged';
    altarSeaStateT509 = 0;
    altarSeaTimer509 = 35 + Math.random() * 20;

    // Main altar body
    const altarBody = new Mesh(
      new BoxGeometry(1.0, 0.7, 0.7),
      new MeshStandardMaterial({ color: 0x060e06, roughness: 0.9, metalness: 0.0, flatShading: true }),
    );
    altarBody.position.set(0, 0.35, 0);
    altarSeaGroup509.add(altarBody);

    // Top slab — slightly overhanging
    const altarSlab = new Mesh(
      new BoxGeometry(1.15, 0.08, 0.8),
      new MeshStandardMaterial({ color: 0x0a1a0a, roughness: 0.9, metalness: 0.0, flatShading: true }),
    );
    altarSlab.position.set(0, 0.74, 0);
    altarSeaGroup509.add(altarSlab);

    // 4 Ogham inscription panels — one on each face (+X, -X, +Z, -Z)
    const runeOffsets: [number, number, number, number][] = [
      [ 0.501, 0.35,  0.0,  0.0],   // +X face
      [-0.501, 0.35,  0.0,  Math.PI], // -X face
      [ 0.0,   0.35,  0.351, Math.PI / 2],  // +Z face
      [ 0.0,   0.35, -0.351, -Math.PI / 2], // -Z face
    ];
    for (let ri = 0; ri < 4; ri++) {
      const [rx, ry, rz, ry2] = runeOffsets[ri]!;
      const runeMat = new MeshStandardMaterial({
        color: 0x002200,
        emissive: 0x33ff66,
        emissiveIntensity: 0.8,
        transparent: true,
        opacity: 0.9,
        roughness: 0.6,
        metalness: 0.0,
      });
      altarSeaRuneMats509.push(runeMat);
      const runePanel = new Mesh(new PlaneGeometry(0.15, 0.5), runeMat);
      runePanel.position.set(rx, ry, rz);
      runePanel.rotation.y = ry2;
      altarSeaGroup509.add(runePanel);
    }

    // Barnacle clusters on base — 5 flattened spheres
    const barnaclePos: [number, number, number][] = [
      [-0.35, 0.04,  0.25],
      [ 0.3,  0.04, -0.28],
      [-0.1,  0.04,  0.32],
      [ 0.4,  0.04,  0.1],
      [-0.3,  0.04, -0.1],
    ];
    for (const [bx, by, bz] of barnaclePos) {
      const barnacle = new Mesh(
        new SphereGeometry(0.07, 5, 4),
        new MeshStandardMaterial({ color: 0x060e06, roughness: 0.95, flatShading: true }),
      );
      barnacle.position.set(bx, by, bz);
      barnacle.scale.y = 0.35;
      altarSeaGroup509.add(barnacle);
    }

    // Sea anemones on top slab — 3 clusters
    const anemonePos509: [number, number, number][] = [
      [-0.3, 0.78,  0.2],
      [ 0.2, 0.78, -0.2],
      [ 0.0, 0.78,  0.0],
    ];
    for (const [ax, ay, az] of anemonePos509) {
      const anemone = new Mesh(
        new CylinderGeometry(0.04, 0.06, 0.12, 6),
        new MeshStandardMaterial({
          color: 0x0d2a1a,
          emissive: 0x1a5522,
          emissiveIntensity: 0.5,
          roughness: 0.8,
          flatShading: true,
        }),
      );
      anemone.position.set(ax, ay, az);
      altarSeaGroup509.add(anemone);
    }

    // Coral accents — 2 branching cylinders
    const coralPos509: [number, number, number, number][] = [
      [-0.45, 0.1,  0.0,  0.3],
      [ 0.45, 0.1, -0.1, -0.25],
    ];
    for (const [cx, cy, cz, cangle] of coralPos509) {
      const coral = new Mesh(
        new CylinderGeometry(0.04, 0.02, 0.2, 5),
        new MeshStandardMaterial({
          color: 0x051a0f,
          emissive: 0x0d3322,
          emissiveIntensity: 0.4,
          roughness: 0.8,
          flatShading: true,
        }),
      );
      coral.position.set(cx, cy, cz);
      coral.rotation.z = cangle;
      altarSeaGroup509.add(coral);
    }

    // Point light at altar top
    altarSeaLight509 = new PointLight(0x33ff66, 0.15, 6.0);
    altarSeaLight509.position.set(0, 0.9, 0);
    altarSeaGroup509.add(altarSeaLight509);

    // Water droplet particles — 6 pooled spheres
    const dropletGeo = new SphereGeometry(0.04, 4, 3);
    for (let di = 0; di < 6; di++) {
      const droplet = new Mesh(
        dropletGeo,
        new MeshStandardMaterial({ color: 0x1a3a3a, transparent: true, opacity: 0.0, roughness: 0.3 }),
      );
      droplet.position.set(0, -50, 0);
      droplet.visible = false;
      droplet.userData = { active: false, velY: 0, age: 0, maxAge: 0.8 };
      altarSeaGroup509.add(droplet);
      altarSeaDroplets509.push(droplet);
    }

    // Place group base at (3, altarSeaBaseY509, -6) — normally submerged
    altarSeaGroup509.position.set(3, altarSeaBaseY509, -6);
    group.add(altarSeaGroup509);
  }

  // ── Deep jellyfish bloom rising from the depths (C514) ──────────────────
  {
    deepJellyGroup514 = new Group();
    const R = (): number => Math.random();

    const bellMat = new MeshStandardMaterial({
      color: 0x0a2a14, emissive: 0x33ff66, emissiveIntensity: 0.2,
      transparent: true, opacity: 0.45, roughness: 0.5, metalness: 0.0,
    });
    const innerGlowMat = new MeshStandardMaterial({
      color: 0x0a2a14, emissive: 0x33ff66, emissiveIntensity: 0.4,
      transparent: true, opacity: 0.3, roughness: 0.5, metalness: 0.0,
    });
    const armMat = new MeshStandardMaterial({
      color: 0x0a2a14, emissive: 0x33ff66, emissiveIntensity: 0.2,
      transparent: true, opacity: 0.5, side: DoubleSide, roughness: 0.6,
    });
    const tentacleMat = new MeshStandardMaterial({
      color: 0x0a2a14, emissive: 0x1a5522, emissiveIntensity: 0.1,
      transparent: true, opacity: 0.4, roughness: 0.7,
    });

    deepJellyBellMats514.push(bellMat, innerGlowMat);

    const jellyXs = [-7.5, -4.5, -1.8, 1.2, 3.8, 5.5, 7.2, -6.0];
    const jellyZs = [-19, -23, -20, -25, -21, -18, -24, -22];
    const jellyDepths = [-3.5, -4.2, -3.0, -4.8, -3.8, -4.0, -3.2, -5.0];

    for (let ji = 0; ji < 8; ji++) {
      const jelly = new Group();
      const phase = R() * Math.PI * 2;
      jelly.userData['phase'] = phase;

      // Bell dome
      const bellGeo = new SphereGeometry(0.28, 10, 7);
      const bell = new Mesh(bellGeo, bellMat.clone());
      bell.scale.set(1, 0.55, 1);
      jelly.add(bell);
      deepJellyBellMats514.push(bell.material as MeshStandardMaterial);

      // Inner glow dome
      const innerGeo = new SphereGeometry(0.18, 8, 6);
      const inner = new Mesh(innerGeo, innerGlowMat.clone());
      inner.scale.set(1, 0.5, 1);
      jelly.add(inner);
      deepJellyBellMats514.push(inner.material as MeshStandardMaterial);

      // Oral arms — 6 PlaneGeometry hanging down from bell center
      const armGeo = new PlaneGeometry(0.06, 0.5);
      for (let ai = 0; ai < 6; ai++) {
        const arm = new Mesh(armGeo, armMat.clone());
        const armAngle = (ai / 6) * Math.PI * 2;
        arm.position.set(
          Math.cos(armAngle) * 0.05,
          -0.2,
          Math.sin(armAngle) * 0.05,
        );
        arm.rotation.y = armAngle;
        arm.userData['armIdx'] = ai;
        jelly.add(arm);
      }

      // Tentacles — 8 thin cylinders hanging from bell edge
      const tentGeo = new CylinderGeometry(0.008, 0.003, 0.7, 3);
      for (let ti = 0; ti < 8; ti++) {
        const tentAngle = (ti / 8) * Math.PI * 2;
        const tent = new Mesh(tentGeo, tentacleMat.clone());
        tent.position.set(
          Math.cos(tentAngle) * 0.26,
          -0.2,
          Math.sin(tentAngle) * 0.26,
        );
        // Fan outward
        tent.rotation.z = Math.cos(tentAngle) * 0.25;
        tent.rotation.x = Math.sin(tentAngle) * 0.25;
        tent.userData['tentIdx'] = ti;
        jelly.add(tent);
      }

      const baseY = jellyDepths[ji]!;
      deepJellyBaseYs514.push(baseY);
      deepJellyTargetYs514.push(-0.5 + R() * 1.5);

      jelly.position.set(jellyXs[ji]!, baseY, jellyZs[ji]!);
      deepJellyGroup514.add(jelly);
      deepJellies514.push(jelly);
    }

    group.add(deepJellyGroup514);
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

    // ── Lighthouse rotating beacon (C404) ─────────────────────────────────
    if (lighthouseGroup404 && lighthouseBeaconLight404) {
      lighthouseT404 += dt * 0.8;
      lighthouseBeaconLight404.rotation.y = lighthouseT404;
      const beamAngle = lighthouseT404 % (Math.PI * 2);
      const facingCamera = Math.cos(beamAngle - Math.PI);
      lighthouseBeaconLight404.intensity = Math.max(0, facingCamera) * 0.8;
      const pointLight = lighthouseGroup404.children.find(c => c instanceof PointLight) as PointLight | undefined;
      if (pointLight) pointLight.intensity = 0.3 + Math.sin(lighthouseT404 * 2) * 0.3;
    }

    // ── Sea cave bioluminescence (C411) ─────────────────────────────────────
    if (seaCaveGroup411 && seaCaveLight411) {
      seaCaveT411 += dt;
      seaCaveLight411.intensity = 0.25 + Math.sin(seaCaveT411 * 1.2) * 0.08 + Math.sin(seaCaveT411 * 2.7) * 0.04;
      seaCaveAlgae411.forEach((patch, i) => {
        const mat = patch.material as MeshBasicMaterial;
        mat.opacity = 0.3 + Math.sin(seaCaveT411 * 1.5 + i * 0.7) * 0.15;
      });
    }

    // ── Dolphin pod leaping (C415) ───────────────────────────────────────────
    dolphinPod415.forEach((dolphin, i) => {
      dolphinT415[i] += dt * 0.7;
      const cycle = dolphinT415[i] % 7.0;

      const baseX = 6 + i * 1.2;
      const baseZ = -25 - i * 0.8;

      if (cycle < 2.5) {
        const t = cycle / 2.5;
        dolphin.position.y = -0.5 + Math.sin(t * Math.PI) * 2.8;
        dolphin.position.x = baseX + t * 1.5;
        dolphin.rotation.x = Math.PI * 0.5 - t * Math.PI;
        dolphin.visible = true;
      } else if (cycle < 2.8) {
        dolphin.position.y = -0.5 - (cycle - 2.5) / 0.3 * 0.8;
        dolphin.visible = true;
      } else {
        dolphin.visible = false;
        dolphin.position.set(baseX, -0.5, baseZ);
        dolphin.rotation.x = 0;
      }
    });

    // ── Sunken ship mast sway (C420) ────────────────────────────────────────
    if (shipMastGroup420) {
      shipMastT420 += dt * 0.4;
      shipMastGroup420.rotation.z = 0.12 + Math.sin(shipMastT420 * 0.6) * 0.03;
      shipSeaweed420.forEach((weed, i) => {
        weed.rotation.z = Math.sin(shipMastT420 * 1.2 + i * 0.5) * 0.2;
        weed.rotation.x = Math.sin(shipMastT420 * 0.9 + i * 0.8) * 0.1;
      });
    }

    // ── Whale tail breach (C444) ─────────────────────────────────────────────
    if (whaleGroup444) {
      whaleT444 += dt;
      if (!whaleBreaching444) {
        whaleTimer444 -= dt;
        if (whaleTimer444 <= 0) {
          whaleBreaching444 = true;
          whaleCycle444 = 0;
          whaleTimer444 = 25 + Math.random() * 15;
          window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'whoosh' } }));
        }
      }
      if (whaleBreaching444) {
        whaleCycle444 += dt;
        if (whaleCycle444 < 1.5) {
          // Phase: rise from y=-3 to y=1.5
          whaleGroup444.position.y = -3 + 4.5 * (whaleCycle444 / 1.5);
          whaleSplashParticles444.forEach((p, i) => {
            const mat = p.material as MeshBasicMaterial;
            mat.opacity = 0.8 * Math.sin(whaleCycle444 * Math.PI / 1.5);
            p.position.y = 0.3 * Math.sin(whaleCycle444 * 3 + i);
          });
        } else if (whaleCycle444 < 3.0) {
          // Phase: hold at apex, slight tilt
          whaleGroup444.position.y = 1.5;
          whaleGroup444.rotation.x = 0.2 * ((whaleCycle444 - 1.5) / 1.5);
        } else if (whaleCycle444 < 5.0) {
          // Phase: tilt and dive back
          const tDive = (whaleCycle444 - 3.0) / 2.0;
          whaleGroup444.position.y = 1.5 - 4.5 * tDive;
          whaleGroup444.rotation.x = 0.2 + 0.8 * tDive;
          whaleSplashParticles444.forEach((p) => {
            const mat = p.material as MeshBasicMaterial;
            mat.opacity = 0;
          });
        } else {
          // Reset
          whaleBreaching444 = false;
          whaleCycle444 = 0;
          whaleGroup444.position.y = -3;
          whaleGroup444.rotation.x = 0;
        }
      }
    }

    // ── Jellyfish cluster pulse and drift (C449) ─────────────────────────────
    if (jellyfishGroup449) {
      jellyfishT449 += dt;
      jellyfishBells449.forEach((bell, i) => {
        const d = jellyfishData449[i];
        if (!d) return;
        // Bell pulse: contract / expand
        const pulseY = 0.4 + 0.12 * Math.sin(jellyfishT449 * d.speed * 2 + d.phase);
        const pulseXZ = 0.9 + 0.12 * Math.sin(jellyfishT449 * d.speed + d.phase);
        bell.scale.set(pulseXZ, pulseY, pulseXZ);
        // Bell opacity breathing
        const mat = bell.material as MeshBasicMaterial;
        mat.opacity = 0.4 + 0.2 * Math.sin(jellyfishT449 * d.speed + d.phase);
        // Drift parent jGroup
        const jGroup = bell.parent;
        if (jGroup) {
          jGroup.position.y = (d.phase % 1.0) - 0.5 + 0.25 * Math.sin(jellyfishT449 * 0.3 + d.phase);
          jGroup.position.x = d.ox + 0.3 * Math.sin(jellyfishT449 * 0.2 + d.phase);
          jGroup.position.z = d.oz + 0.2 * Math.cos(jellyfishT449 * 0.15 + d.phase);
        }
      });
    }

    // ── Kelp forest sway (C454) ───────────────────────────────────────────────
    if (kelpGroup454) {
      kelpT454 += dt;
      kelpStalks454.forEach((stalk, ki) => {
        const phaseOffset = ki * 0.6;
        stalk.forEach((seg, si) => {
          const swayAmt = (si / stalk.length) * 0.18;
          const swayX = swayAmt * Math.sin(kelpT454 * 0.8 + phaseOffset);
          const swayZ = swayAmt * 0.5 * Math.cos(kelpT454 * 0.6 + phaseOffset + 0.5);
          seg.rotation.z = swayX * 0.8;
          seg.rotation.x = swayZ * 0.8;
          if (si === stalk.length - 1) {
            const mat = seg.material as MeshBasicMaterial;
            mat.opacity = 0.6 + 0.25 * Math.sin(kelpT454 * 1.5 + phaseOffset);
          }
        });
      });
    }

    // ── Ker-Is ruins moss bioluminescence (C459) ─────────────────────────────
    ruinsT459 += dt;
    ruinsMossPatches459.forEach((moss, i) => {
      const mat = moss.material as MeshBasicMaterial;
      mat.opacity = 0.3 + 0.15 * Math.sin(ruinsT459 * 0.5 + i * 0.8);
    });

    // ── Sea stack bird orbits (C464) ──────────────────────────────────────
    seaStackT464 += dt;
    seaStackBirds464.forEach((bird) => {
      const r = (bird as any).orbitR as number;
      const y = (bird as any).orbitY as number;
      const speed = (bird as any).orbitSpeed as number;
      const phase = (bird as any).phase as number;
      const angle = seaStackT464 * speed + phase;
      bird.position.x = Math.cos(angle) * r;
      bird.position.z = Math.sin(angle) * r;
      bird.position.y = y + 0.3 * Math.sin(seaStackT464 * 1.5 + phase);
      // Face direction of travel (tangent)
      bird.rotation.y = -angle + Math.PI * 0.5;
      // Wing flap
      const wings = bird.children;
      if (wings[1]) wings[1].rotation.z = Math.PI * 0.1 + 0.12 * Math.sin(seaStackT464 * 4 + phase);
      if (wings[2]) wings[2].rotation.z = -(Math.PI * 0.1 + 0.12 * Math.sin(seaStackT464 * 4 + phase));
    });

    // ── Surf menhir animation (C469) ──────────────────────────────────────
    surfMenhirT469 += dt;
    surfMenhirWaveTimer469 -= dt;

    // Glyph breathing
    surfMenhirGlyphs469.forEach((g, i) => {
      const mat = g.material as MeshBasicMaterial;
      mat.opacity = 0.4 + 0.2 * Math.sin(surfMenhirT469 * 0.7 + i * 0.5);
    });

    // Foam shimmer
    if (surfMenhirFoamMat469) {
      surfMenhirFoamMat469.opacity = 0.4 + 0.15 * Math.sin(surfMenhirT469 * 2.0);
    }

    // Wave crash event
    if (surfMenhirWaveTimer469 <= 0) {
      surfMenhirWaveTimer469 = 20 + Math.random() * 15;
      // Flash foam
      if (surfMenhirFoamMat469) surfMenhirFoamMat469.opacity = 0.9;
      window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'water_drop' } }));
    }

    // ── Plankton bloom animation (C474) ───────────────────────────────────
    planktonT474 += dt;
    planktonParticles474.forEach((p) => {
      const phase = (p as any).__phase as number;
      const pulseSpeed = (p as any).__pulseSpeed as number;
      const driftX = (p as any).__driftX as number;
      const driftZ = (p as any).__driftZ as number;
      const px = (p as any).__px as number;
      const pz = (p as any).__pz as number;

      // Drift slowly
      p.position.x = px + driftX * Math.sin(planktonT474 * 0.2 + phase);
      p.position.z = pz + driftZ * Math.cos(planktonT474 * 0.15 + phase);
      p.position.y = -0.1 + 0.08 * Math.sin(planktonT474 * pulseSpeed + phase);

      // Opacity pulse — most are faint, occasional bright flash
      const basePulse = 0.3 + 0.3 * Math.sin(planktonT474 * pulseSpeed + phase);
      const mat = p.material as MeshBasicMaterial;
      mat.opacity = Math.max(0, basePulse);

      // Wrap around if drifted too far
      if (p.position.x > 7) p.position.x = -7;
      if (p.position.x < -7) p.position.x = 7;
    });

    // ── Fish school animation (C479) ─────────────────────────────────────
    fishSchoolT479 += dt;

    // Leader traces an ellipse in the ocean
    fishLeaderX479 = Math.cos(fishSchoolT479 * 0.3) * 5;
    fishLeaderY479 = -1.5 + 0.5 * Math.sin(fishSchoolT479 * 0.4);
    fishLeaderZ479 = Math.sin(fishSchoolT479 * 0.25) * 3;

    // Each fish follows leader + offset
    fishBodies479.forEach((fish) => {
      const ox = (fish as any).__offsetX as number;
      const oy = (fish as any).__offsetY as number;
      const oz = (fish as any).__offsetZ as number;
      const phase = (fish as any).__phase as number;
      const tailPhase = (fish as any).__tailPhase as number;

      // Target position
      const tx = fishLeaderX479 + ox + 0.3 * Math.sin(fishSchoolT479 * 1.2 + phase);
      const ty = fishLeaderY479 + oy + 0.15 * Math.sin(fishSchoolT479 * 0.9 + phase);
      const tz = fishLeaderZ479 + oz + 0.2 * Math.cos(fishSchoolT479 * 1.1 + phase);

      // Smooth follow (lerp)
      fish.position.x += (tx - fish.position.x) * 2.5 * dt;
      fish.position.y += (ty - fish.position.y) * 2.5 * dt;
      fish.position.z += (tz - fish.position.z) * 2.5 * dt;

      // Face direction of movement
      const dx = tx - fish.position.x;
      const dz = tz - fish.position.z;
      if (Math.abs(dx) > 0.01 || Math.abs(dz) > 0.01) {
        fish.rotation.y = Math.atan2(dx, dz);
      }

      // Tail waggle (rotate children[1] = tail)
      if (fish.children[1]) {
        fish.children[1].rotation.z = 0.3 * Math.sin(fishSchoolT479 * 5 + tailPhase);
      }
    });

    // ── Tide pools animation (C484) ───────────────────────────────────────
    t484 += dt;

    // Water ripple emissiveIntensity oscillation
    tidePoolWaterMats484.forEach((mat) => {
      mat.emissiveIntensity = 0.2 + 0.15 * Math.sin(t484 * 0.8);
    });

    // Starfish slow Y rotation
    starfishMeshes484.forEach((sf, i) => {
      sf.rotation.y += 0.015 * dt * (i % 2 === 0 ? 1 : -1);
    });

    // Anemone tentacle sway
    anemonteTentacles484.forEach((td) => {
      td.mesh.rotation.x = 0.5 + 0.25 * Math.sin(t484 * 1.5 + td.phase);
      td.mesh.rotation.z = td.mesh.rotation.z + 0.1 * Math.sin(t484 * 1.3 + td.phase + 1.0) * dt;
    });

    // Hermit crab per pool
    crabTimer484 -= dt;
    if (crabTimer484 <= 0 && !crabActive484) {
      crabActive484 = true;
      crabProgress484 = 0;
      // Activate one crab (alternate by time)
      const crabIdx = Math.floor(t484 / 20) % crabMeshes484.length;
      crabMeshes484.forEach((c, i) => { c.visible = (i === crabIdx); });
      window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'splash' } }));
    }
    if (crabActive484) {
      crabProgress484 = Math.min(1, crabProgress484 + dt * 0.12);
      const crabIdx = Math.floor(t484 / 20) % crabMeshes484.length;
      const crab = crabMeshes484[crabIdx];
      if (crab) {
        const sp = crabStartPos484[crabIdx];
        const ep = crabEndPos484[crabIdx];
        if (sp && ep) {
          crab.position.x = sp[0] + (ep[0] - sp[0]) * crabProgress484;
          crab.position.y = sp[1];
          crab.position.z = sp[2] + (ep[2] - sp[2]) * crabProgress484;
        }
      }
      if (crabProgress484 >= 1) {
        crabActive484 = false;
        crabTimer484 = 15 + Math.random() * 10;
        crabMeshes484.forEach((c) => { c.visible = false; });
      }
    }

    // ── Sunken shipwreck hull animation (C489) ────────────────────────────
    t489 += dt;

    // Kelp wisp sway
    wreckKelpMeshes489.forEach((wisp) => {
      const phase = (wisp as any).__kelpPhase489 as number;
      wisp.rotation.z = Math.sin(t489 * 1.2 + phase) * 0.3;
    });

    // Interior glow flicker
    if (wreckLight489) {
      wreckLight489.intensity = 0.4 + 0.15 * Math.sin(t489 * 3.1 + 0.7);
    }

    // Ghost ship echo — timer-driven hull shimmer
    wreckGhostTimer489 -= dt;
    if (wreckGhostTimer489 <= 0 && !wreckGhostActive489) {
      wreckGhostActive489 = true;
      wreckGhostT489 = 0;
      wreckGhostTimer489 = 25 + Math.random() * 15;
      window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'shimmer' } }));
    }
    if (wreckGhostActive489 && wreckHullMat489) {
      wreckGhostT489 += dt;
      let ghostIntensity = 0;
      if (wreckGhostT489 < 1.0) {
        // Fade in over 1s
        ghostIntensity = (wreckGhostT489 / 1.0) * 0.5;
      } else if (wreckGhostT489 < 3.0) {
        // Fade out over 2s
        ghostIntensity = (1.0 - (wreckGhostT489 - 1.0) / 2.0) * 0.5;
      } else {
        wreckGhostActive489 = false;
        ghostIntensity = 0;
      }
      wreckHullMat489.emissiveIntensity = Math.max(0, ghostIntensity);
    }

    // ── Sea serpent breach (C494) ────────────────────────────────────────────
    if (serpentGroup494) {
      t494 += dt;

      if (serpentState494 === 'hidden') {
        serpentTimer494 -= dt;
        if (serpentTimer494 <= 0) {
          serpentState494 = 'rising';
          serpentStateT494 = 0;
          serpentGroup494.visible = true;
          serpentGroup494.scale.setScalar(0);
          window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'splash' } }));
        }

      } else if (serpentState494 === 'rising') {
        serpentStateT494 += dt;
        const progress = Math.min(serpentStateT494 / 1.5, 1.0);
        serpentGroup494.scale.setScalar(progress);
        serpentGroup494.position.y = 0.05 * Math.sin(t494 * 2);
        // Animate splash particles during rise
        splashParticles494.forEach((sp, i) => {
          const angle = (sp as any).__spAngle494 as number;
          const spd = (sp as any).__spSpeed494 as number;
          const spT = serpentStateT494;
          sp.position.set(
            Math.cos(angle) * 0.8 + Math.cos(angle) * spd * spT,
            Math.sin(spT * Math.PI) * 1.5,
            Math.sin(angle) * 0.4 + Math.sin(angle) * spd * spT * 0.5,
          );
          const mat = sp.material as MeshStandardMaterial;
          mat.opacity = (spT < 1.0) ? Math.sin(spT * Math.PI) * 0.75 : 0.0;
          // Unused variable guard
          void i;
        });
        if (progress >= 1.0) {
          serpentState494 = 'hang';
          serpentStateT494 = 0;
        }

      } else if (serpentState494 === 'hang') {
        serpentStateT494 += dt;
        serpentGroup494.position.y = 0.05 * Math.sin(t494 * 2);
        // Hide splash
        splashParticles494.forEach((sp) => {
          (sp.material as MeshStandardMaterial).opacity = 0;
        });
        if (serpentStateT494 >= 0.5) {
          serpentState494 = 'diving';
          serpentStateT494 = 0;
        }

      } else if (serpentState494 === 'diving') {
        serpentStateT494 += dt;
        const progress = Math.min(serpentStateT494 / 1.0, 1.0);
        serpentGroup494.scale.setScalar(1.0 - progress);
        serpentGroup494.position.y = 0.05 * Math.sin(t494 * 2);
        if (progress >= 1.0) {
          serpentState494 = 'hidden';
          serpentStateT494 = 0;
          serpentTimer494 = 20 + Math.random() * 15;
          serpentGroup494.visible = false;
          serpentGroup494.scale.setScalar(1);
        }
      }
    }

    // ── Mermaid silhouette glimpsed through a wave (C504) ────────────────────
    if (mermaidGroup504 && mermaidLight504) {
      t504 += dt;

      if (mermaidState504 === 'hidden') {
        mermaidTimer504 -= dt;
        if (mermaidTimer504 <= 0) {
          mermaidState504 = 'approach';
          mermaidStateT504 = 0;
          mermaidGroup504.position.y = -1.5;
          window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'shimmer' } }));
        }

      } else if (mermaidState504 === 'approach') {
        mermaidStateT504 += dt;
        const p = Math.min(mermaidStateT504 / 2.0, 1.0);
        const opacity = p * 0.65;
        mermaidMats504.forEach((m) => { m.opacity = opacity; });
        mermaidLight504.intensity = opacity * 0.5;
        mermaidGroup504.position.y = -1.5 + p * 1.2; // rises to y=-0.3
        if (p >= 1.0) {
          mermaidState504 = 'hover';
          mermaidStateT504 = 0;
        }

      } else if (mermaidState504 === 'hover') {
        mermaidStateT504 += dt;
        // Tail undulation
        if (mermaidTailMesh504) {
          mermaidTailMesh504.rotation.x = 0.3 * Math.sin(t504 * 2.5);
        }
        // Tail fluke follows with lag
        if (mermaidTailFluke504) {
          mermaidTailFluke504.rotation.x = 0.4 * Math.sin(t504 * 2.5 + 0.5);
        }
        // Hair sway
        mermaidHairMeshes504.forEach((hair, hairIdx) => {
          hair.rotation.z = 0.2 * Math.sin(t504 * 1.8 + hairIdx * 0.5);
        });
        // Arms drift — reaching forward
        mermaidArmMeshes504.forEach(({ mesh, side }) => {
          mesh.rotation.z = side * (0.4 + 0.1 * Math.sin(t504 * 1.3));
        });
        // Overall gentle rock
        mermaidGroup504.rotation.z = 0.05 * Math.sin(t504 * 0.8);
        if (mermaidStateT504 >= 1.5) {
          mermaidState504 = 'retreat';
          mermaidStateT504 = 0;
        }

      } else if (mermaidState504 === 'retreat') {
        mermaidStateT504 += dt;
        const p = Math.min(mermaidStateT504 / 1.5, 1.0);
        const opacity = 0.65 * (1.0 - p);
        mermaidMats504.forEach((m) => { m.opacity = opacity; });
        mermaidLight504.intensity = opacity * 0.5;
        mermaidGroup504.position.y = -0.3 - p * 1.2; // descends back to y=-1.5
        if (p >= 1.0) {
          mermaidState504 = 'hidden';
          mermaidStateT504 = 0;
          mermaidTimer504 = 25 + Math.random() * 15;
          mermaidGroup504.position.y = -1.5;
          mermaidGroup504.rotation.z = 0;
        }
      }
    }

    // ── Ancient sea altar emerging at low tide (C509) ────────────────────────
    if (altarSeaGroup509 && altarSeaLight509) {
      t509 += dt;

      if (altarSeaState509 === 'submerged') {
        altarSeaTimer509 -= dt;
        altarSeaLight509.intensity = 0.15;
        if (altarSeaTimer509 <= 0) {
          altarSeaState509 = 'rising';
          altarSeaStateT509 = 0;
          altarSeaPeakSFX509 = false;
          window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'splash' } }));
          // Activate droplet particles
          for (let di = 0; di < altarSeaDroplets509.length; di++) {
            const drop = altarSeaDroplets509[di]!;
            drop.visible = true;
            drop.position.set(
              (Math.random() - 0.5) * 0.8,
              0.7 + Math.random() * 0.15,
              (Math.random() - 0.5) * 0.5,
            );
            drop.userData['active'] = true;
            drop.userData['velY'] = -0.8 - Math.random() * 0.6;
            drop.userData['age'] = 0;
            drop.userData['maxAge'] = 0.5 + Math.random() * 0.3;
            (drop.material as MeshStandardMaterial).opacity = 0.75;
          }
        }
      } else if (altarSeaState509 === 'rising') {
        altarSeaStateT509 += dt;
        const p = Math.min(altarSeaStateT509 / 4.0, 1.0);
        altarSeaGroup509.position.y = altarSeaBaseY509 + (0.1 - altarSeaBaseY509) * p;
        altarSeaLight509.intensity = 0.15 + 0.85 * p;
        if (!altarSeaPeakSFX509 && p >= 1.0) {
          altarSeaPeakSFX509 = true;
          window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'chime' } }));
        }
        if (p >= 1.0) {
          altarSeaState509 = 'emerged';
          altarSeaStateT509 = 0;
          altarSeaStateT509 = 8 + Math.random() * 4;
        }
      } else if (altarSeaState509 === 'emerged') {
        altarSeaStateT509 -= dt;
        altarSeaLight509.intensity = 1.0;
        // Rune pulse while emerged
        for (let ri = 0; ri < altarSeaRuneMats509.length; ri++) {
          altarSeaRuneMats509[ri]!.emissiveIntensity = 0.8 + 0.5 * Math.sin(t509 * 2.1 + ri);
        }
        if (altarSeaStateT509 <= 0) {
          altarSeaState509 = 'sinking';
          altarSeaStateT509 = 0;
        }
      } else if (altarSeaState509 === 'sinking') {
        altarSeaStateT509 += dt;
        const p = Math.min(altarSeaStateT509 / 4.0, 1.0);
        altarSeaGroup509.position.y = 0.1 + (altarSeaBaseY509 - 0.1) * p;
        altarSeaLight509.intensity = 1.0 - 0.85 * p;
        // Fade runes back to base intensity
        for (let ri = 0; ri < altarSeaRuneMats509.length; ri++) {
          altarSeaRuneMats509[ri]!.emissiveIntensity = 0.8;
        }
        if (p >= 1.0) {
          altarSeaState509 = 'submerged';
          altarSeaStateT509 = 0;
          altarSeaTimer509 = 35 + Math.random() * 20;
          altarSeaGroup509.position.y = altarSeaBaseY509;
        }
      }

      // Animate droplet particles
      for (let di = 0; di < altarSeaDroplets509.length; di++) {
        const drop = altarSeaDroplets509[di]!;
        if (!drop.userData['active']) continue;
        const age: number = (drop.userData['age'] as number) + dt;
        drop.userData['age'] = age;
        const maxAge: number = drop.userData['maxAge'] as number;
        const velY: number = drop.userData['velY'] as number;
        drop.position.y += velY * dt;
        const opacity = Math.max(0, 0.75 * (1.0 - age / maxAge));
        (drop.material as MeshStandardMaterial).opacity = opacity;
        if (drop.position.y <= 0 || age >= maxAge) {
          drop.userData['active'] = false;
          drop.visible = false;
          drop.position.set(0, -50, 0);
        }
      }
    }

    // ── Dolphin pod leaping (C499) ────────────────────────────────────────────
    t499 += dt;
    for (let i = 0; i < 4; i++) {
      const state = dolphinStates499[i]!;
      const dolphin = dolphins499[i]!;

      if (!state.leaping) {
        state.timer -= dt;
        if (state.timer <= 0) {
          // Start leap
          state.leaping = true;
          state.leapT = 0;
          dolphin.visible = true;
          dolphin.position.set(state.startX, state.startY, state.startZ);
          dolphin.rotation.y = state.heading;
          window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'splash' } }));
        }
      } else {
        // Total leap duration = rise (0.8s) + peak (0.1s) + dive (0.6s) = 1.5s
        state.leapT += dt;
        const totalDuration = 1.5;
        const p = Math.min(state.leapT / totalDuration, 1.0);

        // Parabolic Y: peakHeight * 4 * p * (1-p), peakHeight = 2.5
        const waterY = state.startY;
        dolphin.position.y = waterY + 2.5 * 4.0 * p * (1.0 - p);

        // Horizontal travel — 3 units in heading direction
        dolphin.position.x = state.startX + Math.sin(state.heading) * 3.0 * p;
        dolphin.position.z = state.startZ + Math.cos(state.heading) * 3.0 * p;

        // Body pitch: nose-up on way up, nose-down on way down
        dolphin.rotation.z = -0.8 * (0.5 - p) * Math.PI;

        if (p >= 1.0) {
          // Dolphin re-enters water — splash particles
          const splashBase = i * 4;
          for (let s = 0; s < 4; s++) {
            const sp = splashPool499[splashBase + s]!;
            const angle = (s / 4) * Math.PI * 2;
            sp.position.set(
              dolphin.position.x + Math.cos(angle) * 0.2,
              waterY + 0.1,
              dolphin.position.z + Math.sin(angle) * 0.2,
            );
            (sp as any).__splashT499 = 0.0;
            (sp as any).__splashVY499 = 1.5 + Math.random() * 1.0;
            (sp as any).__splashAngle499 = angle;
            (sp.material as MeshStandardMaterial).opacity = 0.7;
            sp.visible = true;
          }

          dolphin.visible = false;
          dolphin.rotation.z = 0;
          state.leaping = false;
          state.leapT = 0;
          state.timer = 12 + Math.random() * 8;
          // Update start position to where dolphin landed
          state.startX = dolphin.position.x;
          state.startZ = dolphin.position.z;
        }
      }

      // Animate this dolphin's splash particles
      const splashBase = i * 4;
      for (let s = 0; s < 4; s++) {
        const sp = splashPool499[splashBase + s]!;
        if (!sp.visible) continue;
        const spT = ((sp as any).__splashT499 as number) + dt;
        (sp as any).__splashT499 = spT;
        const vy = (sp as any).__splashVY499 as number;
        sp.position.y = (sp as any).__splashVY499 !== undefined
          ? dolphinStates499[i]!.startY + 0.1 + vy * spT - 2.5 * spT * spT
          : 0;
        const opacity = Math.max(0, 0.7 * (1.0 - spT / 0.5));
        (sp.material as MeshStandardMaterial).opacity = opacity;
        if (spT >= 0.5) {
          sp.visible = false;
          sp.position.set(0, -50, 0);
        }
      }
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

    // ── Deep jellyfish bloom rising from the depths (C514) ──────────────────
    if (deepJellyGroup514) {
      t514 += dt;

      // Bloom state machine
      if (deepJellyState514 === 'resting') {
        deepJellyTimer514 -= dt;
        if (deepJellyTimer514 <= 0) {
          deepJellyState514 = 'rising';
          deepJellyStateT514 = 0;
          window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'shimmer' } }));
        }
      } else if (deepJellyState514 === 'rising') {
        deepJellyStateT514 += dt;
        const p = Math.min(deepJellyStateT514 / 8.0, 1.0);
        for (let ji = 0; ji < deepJellies514.length; ji++) {
          const jelly = deepJellies514[ji]!;
          const baseY = deepJellyBaseYs514[ji]!;
          const targetY = deepJellyTargetYs514[ji]!;
          jelly.position.y = baseY + (targetY - baseY) * p;
          // Ramp up emissive
          const bellMat514 = (jelly.children[0] as Mesh | undefined)?.material as MeshStandardMaterial | undefined;
          if (bellMat514) bellMat514.emissiveIntensity = 0.2 + 0.3 * p;
          const innerMat514 = (jelly.children[1] as Mesh | undefined)?.material as MeshStandardMaterial | undefined;
          if (innerMat514) innerMat514.emissiveIntensity = 0.4 + 0.8 * p;
        }
        if (p >= 1.0) {
          deepJellyState514 = 'hover';
          deepJellyStateT514 = 0;
        }
      } else if (deepJellyState514 === 'hover') {
        deepJellyStateT514 += dt;
        if (deepJellyStateT514 >= 5.0) {
          deepJellyState514 = 'sinking';
          deepJellyStateT514 = 0;
        }
      } else if (deepJellyState514 === 'sinking') {
        deepJellyStateT514 += dt;
        const p = Math.min(deepJellyStateT514 / 5.0, 1.0);
        for (let ji = 0; ji < deepJellies514.length; ji++) {
          const jelly = deepJellies514[ji]!;
          const baseY = deepJellyBaseYs514[ji]!;
          const targetY = deepJellyTargetYs514[ji]!;
          jelly.position.y = targetY + (baseY - targetY) * p;
          // Ramp down emissive
          const bellMat514 = (jelly.children[0] as Mesh | undefined)?.material as MeshStandardMaterial | undefined;
          if (bellMat514) bellMat514.emissiveIntensity = 0.5 - 0.3 * p;
          const innerMat514 = (jelly.children[1] as Mesh | undefined)?.material as MeshStandardMaterial | undefined;
          if (innerMat514) innerMat514.emissiveIntensity = 1.2 - 0.8 * p;
        }
        if (p >= 1.0) {
          deepJellyState514 = 'resting';
          deepJellyStateT514 = 0;
          deepJellyTimer514 = 50 + Math.random() * 20;
        }
      }

      // Per-jellyfish animation always active
      for (let ji = 0; ji < deepJellies514.length; ji++) {
        const jelly = deepJellies514[ji]!;
        const phase: number = jelly.userData['phase'] as number;

        // Bell pulse — scale.y oscillates 0.5–0.65
        const bellPulse = 0.575 + 0.075 * Math.sin(t514 * 1.5 + phase);
        const bell514 = jelly.children[0];
        if (bell514) bell514.scale.y = bellPulse;
        const inner514 = jelly.children[1];
        if (inner514) inner514.scale.y = bellPulse * (0.5 / 0.55);

        // Animate arms and tentacles (children index 2+)
        for (let ci = 2; ci < jelly.children.length; ci++) {
          const child = jelly.children[ci]!;
          const userData = child.userData as Record<string, unknown>;
          if ('armIdx' in userData) {
            const armIdx = userData['armIdx'] as number;
            child.rotation.z = 0.1 * Math.sin(t514 * 2.8 + armIdx * 1.0);
          } else if ('tentIdx' in userData) {
            const tentIdx = userData['tentIdx'] as number;
            child.rotation.x = 0.15 * Math.sin(t514 * 2.0 + tentIdx * 0.4 + phase);
          }
        }

        // Slow bob at base depth when resting
        if (deepJellyState514 === 'resting') {
          const baseY = deepJellyBaseYs514[ji]!;
          jelly.position.y = baseY + 0.08 * Math.sin(t514 * 0.4 + phase);
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
    if (lighthouseGroup404) {
      lighthouseGroup404.traverse(c => {
        if (c instanceof Mesh) {
          c.geometry.dispose();
          if (Array.isArray(c.material)) c.material.forEach(m => m.dispose());
          else c.material.dispose();
        }
        if (c instanceof SpotLight || c instanceof PointLight) c.dispose();
      });
      lighthouseGroup404 = null;
      lighthouseBeaconLight404 = null;
    }
    if (seaCaveGroup411) {
      seaCaveGroup411.traverse(c => {
        if (c instanceof Mesh) { c.geometry.dispose(); if (Array.isArray(c.material)) c.material.forEach(m => m.dispose()); else c.material.dispose(); }
        if (c instanceof PointLight) c.dispose();
      });
      seaCaveAlgae411.length = 0;
      seaCaveLight411 = null;
      seaCaveGroup411 = null;
    }
    dolphinPod415.forEach(d => {
      d.traverse(c => {
        if (c instanceof Mesh) { c.geometry.dispose(); if (Array.isArray(c.material)) c.material.forEach(m => m.dispose()); else c.material.dispose(); }
      });
    });
    dolphinPod415.length = 0;
    dolphinT415.length = 0;
    if (shipMastGroup420) {
      shipMastGroup420.traverse(c => {
        if (c instanceof Mesh) { c.geometry.dispose(); if (Array.isArray(c.material)) c.material.forEach(m => m.dispose()); else c.material.dispose(); }
        if (c instanceof PointLight) c.dispose();
      });
      shipSeaweed420.length = 0;
      shipMastGroup420 = null;
    }
    if (whaleGroup444) {
      whaleGroup444.traverse(c => {
        if (c instanceof Mesh) {
          c.geometry.dispose();
          if (Array.isArray(c.material)) c.material.forEach(m => m.dispose());
          else c.material.dispose();
        }
      });
      whaleSplashParticles444.length = 0;
      whaleGroup444 = null;
    }
    if (jellyfishGroup449) {
      jellyfishGroup449.traverse(c => {
        if (c instanceof Mesh || c instanceof Line) {
          c.geometry.dispose();
          if (Array.isArray(c.material)) c.material.forEach((m: Material) => m.dispose());
          else (c.material as Material).dispose();
        }
        if (c instanceof PointLight) c.dispose();
      });
      jellyfishBells449.length = 0;
      jellyfishData449.length = 0;
      jellyfishGroup449 = null;
    }
    if (kelpGroup454) {
      kelpGroup454.traverse(c => {
        if (c instanceof Mesh) {
          c.geometry.dispose();
          (c.material as Material).dispose();
        }
      });
      kelpGroup454 = null;
    }
    kelpStalks454.length = 0;
    if (ruinsGroup459) {
      ruinsGroup459.traverse(c => {
        if (c instanceof Mesh) {
          c.geometry.dispose();
          (c.material as Material).dispose();
        }
      });
      ruinsGroup459 = null;
    }
    ruinsMossPatches459.length = 0;
    if (seaStackGroup464) {
      seaStackGroup464.traverse(c => {
        if (c instanceof Mesh) {
          c.geometry.dispose();
          (c.material as Material).dispose();
        }
      });
      seaStackGroup464 = null;
    }
    seaStackBirds464.length = 0;
    if (surfMenhirGroup469) {
      surfMenhirGroup469.traverse(c => {
        if (c instanceof Mesh) {
          c.geometry.dispose();
          (c.material as Material).dispose();
        }
      });
      surfMenhirGroup469 = null;
    }
    surfMenhirFoamMat469 = null;
    surfMenhirGlyphs469.length = 0;
    if (planktonGroup474) {
      planktonGroup474.traverse(c => {
        if (c instanceof Mesh) {
          c.geometry.dispose();
          (c.material as MeshBasicMaterial).dispose();
        }
      });
      planktonGroup474 = null;
    }
    planktonParticles474.length = 0;
    if (fishSchoolGroup479) {
      fishSchoolGroup479.traverse(c => {
        if (c instanceof Mesh) {
          c.geometry.dispose();
          (c.material as MeshBasicMaterial).dispose();
        }
      });
      fishSchoolGroup479 = null;
    }
    fishBodies479.length = 0;
    tidePoolGroup484.forEach((pg) => {
      pg.traverse((c) => {
        if ((c as Mesh).geometry) (c as Mesh).geometry.dispose();
        if ((c as Mesh).material) {
          const mat = (c as Mesh).material;
          if (Array.isArray(mat)) mat.forEach((m) => m.dispose());
          else (mat as Material).dispose();
        }
      });
    });
    tidePoolGroup484.length = 0;
    tidePoolWaterMats484.length = 0;
    starfishMeshes484.length = 0;
    anemonteTentacles484.length = 0;
    crabMeshes484.length = 0;
    crabStartPos484.length = 0;
    crabEndPos484.length = 0;
    if (wreckGroup489) {
      wreckGroup489.traverse((c) => {
        if (c instanceof Mesh) {
          c.geometry.dispose();
          if (Array.isArray(c.material)) c.material.forEach((m: Material) => m.dispose());
          else (c.material as Material).dispose();
        }
        if (c instanceof PointLight) c.dispose();
      });
      wreckGroup489 = null;
    }
    wreckKelpMeshes489.length = 0;
    wreckLight489 = null;
    wreckHullMat489 = null;
    if (dolphinGroup499) {
      dolphinGroup499.traverse((c) => {
        if (c instanceof Mesh) {
          c.geometry.dispose();
          if (Array.isArray(c.material)) c.material.forEach((m: Material) => m.dispose());
          else (c.material as Material).dispose();
        }
      });
      dolphinGroup499 = null;
    }
    dolphins499.length = 0;
    dolphinStates499.length = 0;
    dolphinTimers499.length = 0;
    dolphinTs499.length = 0;
    splashPool499.length = 0;
    if (serpentGroup494) {
      serpentGroup494.traverse((c) => {
        if (c instanceof Mesh) {
          c.geometry.dispose();
          if (Array.isArray(c.material)) c.material.forEach((m: Material) => m.dispose());
          else (c.material as Material).dispose();
        }
      });
      serpentGroup494 = null;
    }
    splashParticles494.length = 0;
    serpentSegMats494.length = 0;
    serpentState494 = 'hidden';
    serpentTimer494 = 20 + Math.random() * 15;
    if (mermaidGroup504) {
      mermaidGroup504.traverse((c) => {
        if (c instanceof Mesh) {
          c.geometry.dispose();
          if (Array.isArray(c.material)) c.material.forEach((m: Material) => m.dispose());
          else (c.material as Material).dispose();
        }
        if (c instanceof PointLight) c.dispose();
      });
      mermaidGroup504 = null;
    }
    mermaidMats504.length = 0;
    mermaidLight504 = null;
    mermaidTailMesh504 = null;
    mermaidTailFluke504 = null;
    mermaidHairMeshes504.length = 0;
    mermaidArmMeshes504.length = 0;
    mermaidState504 = 'hidden';
    mermaidTimer504 = 25 + Math.random() * 15;
    if (altarSeaGroup509) {
      altarSeaGroup509.traverse((c) => {
        if (c instanceof Mesh) {
          c.geometry.dispose();
          if (Array.isArray(c.material)) c.material.forEach((m: Material) => m.dispose());
          else (c.material as Material).dispose();
        }
        if (c instanceof PointLight) c.dispose();
      });
      altarSeaGroup509 = null;
    }
    altarSeaRuneMats509.length = 0;
    altarSeaLight509 = null;
    altarSeaDroplets509.length = 0;
    altarSeaState509 = 'submerged';
    altarSeaTimer509 = 35 + Math.random() * 20;
    group.clear();
  };

  return { group, update, dispose };
}
