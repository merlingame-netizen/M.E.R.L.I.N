// =============================================================================
// GenericBiome — Parametric procedural scene for 6 non-dedicated biomes.
// Biomes: marais_korrigans, landes_bruyere, cercles_pierres,
//         monts_brumeux, plaine_druides, vallee_anciens.
// Each biome gets unique terrain color, fog, lighting, stone formations, and
// ambient particles — distinct atmospheres without duplicate scene files.
// C159: biome IDs updated to match game design bible + atmosphere tables.
// =============================================================================

import {
  AmbientLight, AdditiveBlending, BoxGeometry, BufferAttribute, BufferGeometry,
  ConeGeometry, CylinderGeometry, DodecahedronGeometry, DoubleSide, Fog, Group, HemisphereLight,
  InstancedMesh, Mesh, MeshBasicMaterial, MeshLambertMaterial, MeshStandardMaterial, Object3D, PlaneGeometry,
  PointLight, Points, PointsMaterial, SphereGeometry, TorusGeometry, Vector3,
} from 'three';

import type { BiomeSceneResult } from './CoastBiome';
import { loadGLB } from '../engine/AssetLoader';

// ── Biome theme definitions ───────────────────────────────────────────────────

interface BiomeTheme {
  readonly fogColor: number;
  readonly fogNear: number;
  readonly fogFar: number;
  readonly groundColor: number;
  readonly skyTop: number;
  readonly skyMid: number;
  readonly ambientColor: number;
  readonly keyColor: number;
  readonly rimColor: number;
  readonly particleColor: number;
  readonly stoneDensity: number; // 4–12
  readonly treeCount: number;    // 0–20
  readonly stoneType: 'menhir' | 'dolmen' | 'circle' | 'ruins';
}

const THEMES: Readonly<Record<string, BiomeTheme>> = {
  // C159: atmosphere tables from game design brief — fog/ground/accent per biome
  marais_korrigans: {
    fogColor: 0x0a1520, fogNear: 5, fogFar: 32,
    groundColor: 0x1a2a10, skyTop: 0x060e10, skyMid: 0x0e2018,
    ambientColor: 0x081008, keyColor: 0x8866cc, rimColor: 0x4433aa,
    particleColor: 0x8866cc,
    stoneDensity: 5, treeCount: 12, stoneType: 'menhir',
  },
  landes_bruyere: {
    fogColor: 0x1a0e08, fogNear: 8, fogFar: 45,
    groundColor: 0x3a2010, skyTop: 0x120a04, skyMid: 0x261408,
    ambientColor: 0x140c06, keyColor: 0xcc6633, rimColor: 0x883322,
    particleColor: 0xcc6633,
    stoneDensity: 8, treeCount: 4, stoneType: 'menhir',
  },
  cercles_pierres: {
    fogColor: 0x080808, fogNear: 10, fogFar: 50,
    groundColor: 0x282828, skyTop: 0x040404, skyMid: 0x101010,
    ambientColor: 0x080808, keyColor: 0x33ff66, rimColor: 0x1a8833,
    particleColor: 0x33ff66,
    stoneDensity: 12, treeCount: 0, stoneType: 'circle',
  },
  monts_brumeux: {
    fogColor: 0x101418, fogNear: 6, fogFar: 38,
    groundColor: 0x202830, skyTop: 0x0a0e12, skyMid: 0x161e28,
    ambientColor: 0x0c1018, keyColor: 0x4466aa, rimColor: 0x224488,
    particleColor: 0x4466aa,
    stoneDensity: 9, treeCount: 5, stoneType: 'menhir',
  },
  plaine_druides: {
    fogColor: 0x061206, fogNear: 8, fogFar: 42,
    groundColor: 0x1a3010, skyTop: 0x040c04, skyMid: 0x0e2010,
    ambientColor: 0x081208, keyColor: 0x33cc44, rimColor: 0x228833,
    particleColor: 0x33cc44,
    stoneDensity: 6, treeCount: 14, stoneType: 'dolmen',
  },
  vallee_anciens: {
    fogColor: 0x14100a, fogNear: 7, fogFar: 40,
    groundColor: 0x2a1e0e, skyTop: 0x0c0a06, skyMid: 0x181208,
    ambientColor: 0x100c06, keyColor: 0x33aa66, rimColor: 0x1a6633,
    particleColor: 0x33aa66,
    stoneDensity: 7, treeCount: 8, stoneType: 'ruins',
  },
};

const DEFAULT_THEME = THEMES['marais_korrigans']!;

// ── Terrain ───────────────────────────────────────────────────────────────────

function createTerrain(color: number): Mesh {
  const geo = new PlaneGeometry(200, 200, 40, 40);
  const pos = geo.attributes.position as BufferAttribute;
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i);
    const z = pos.getY(i);
    const h =
      Math.sin(x * 0.06) * 1.2 +
      Math.cos(z * 0.09) * 0.8 +
      Math.sin(x * 0.14 + z * 0.11) * 0.4 +
      (Math.random() - 0.5) * 0.25;
    pos.setZ(i, h);
  }
  geo.computeVertexNormals();
  const mat = new MeshStandardMaterial({ color, roughness: 0.97, metalness: 0.0, flatShading: true });
  const mesh = new Mesh(geo, mat);
  mesh.rotation.x = -Math.PI / 2;
  mesh.position.y = -1;
  return mesh;
}

// ── Sky sphere ────────────────────────────────────────────────────────────────

function createSky(topColor: number, midColor: number): Mesh {
  const geo = new SphereGeometry(150, 12, 10);
  const count = geo.attributes.position!.count;
  const colors = new Float32Array(count * 3);
  const pos = geo.attributes.position as BufferAttribute;
  for (let i = 0; i < count; i++) {
    const y = pos.getY(i);
    const t = Math.max(0, Math.min(1, (y + 30) / 80));
    const top = { r: (topColor >> 16 & 0xff) / 255, g: (topColor >> 8 & 0xff) / 255, b: (topColor & 0xff) / 255 };
    const mid = { r: (midColor >> 16 & 0xff) / 255, g: (midColor >> 8 & 0xff) / 255, b: (midColor & 0xff) / 255 };
    colors[i * 3 + 0] = top.r * t + mid.r * (1 - t);
    colors[i * 3 + 1] = top.g * t + mid.g * (1 - t);
    colors[i * 3 + 2] = top.b * t + mid.b * (1 - t);
  }
  geo.setAttribute('color', new BufferAttribute(colors, 3));
  const mat = new MeshStandardMaterial({ vertexColors: true, side: 2, flatShading: false });
  return new Mesh(geo, mat);
}

// ── Twisted trees ─────────────────────────────────────────────────────────────

function createTrees(count: number, trunkColor: number): Group {
  if (count === 0) return new Group();
  const group = new Group();
  const trunkMat = new MeshStandardMaterial({ color: trunkColor, roughness: 0.9, metalness: 0.0, flatShading: true });
  const R = () => Math.random();

  for (let i = 0; i < count; i++) {
    const x = (R() - 0.5) * 70;
    const z = -8 - R() * 50;
    const h = 2.5 + R() * 4;

    const trunk = new Mesh(new CylinderGeometry(0.07 + R() * 0.06, 0.12 + R() * 0.08, h, 5), trunkMat);
    trunk.position.set(x, h / 2 - 1, z);
    trunk.rotation.z = (R() - 0.5) * 0.3;
    trunk.rotation.x = (R() - 0.5) * 0.15;
    group.add(trunk);

    // Bare branches
    for (let b = 0; b < 3; b++) {
      const branchH = 0.6 + R() * 0.8;
      const branch = new Mesh(new CylinderGeometry(0.025, 0.04, branchH, 4), trunkMat);
      const angle = b * (Math.PI * 2 / 3) + R() * 0.5;
      branch.position.set(
        x + Math.cos(angle) * 0.5,
        h * 0.6 + b * 0.5 - 1,
        z + Math.sin(angle) * 0.5,
      );
      branch.rotation.z = Math.cos(angle) * 0.5;
      branch.rotation.x = Math.sin(angle) * 0.5;
      group.add(branch);
    }
  }
  return group;
}

// ── Stone formations ──────────────────────────────────────────────────────────

function createStones(theme: BiomeTheme): Group {
  const group = new Group();
  const stoneMat = new MeshStandardMaterial({
    color: 0x786858, roughness: 0.95, metalness: 0.0, flatShading: true,
    emissive: theme.keyColor, emissiveIntensity: 0.04,
  });
  const R = () => Math.random();

  if (theme.stoneType === 'circle') {
    // Stone circle — Cercles de Pierres
    const radius = 8;
    const stoneCount = 10;
    for (let i = 0; i < stoneCount; i++) {
      const angle = (i / stoneCount) * Math.PI * 2;
      const h = 1.8 + R() * 1.4;
      const stone = new Mesh(
        new CylinderGeometry(0.2 + R() * 0.15, 0.28 + R() * 0.1, h, 5),
        stoneMat,
      );
      stone.position.set(Math.cos(angle) * radius, h / 2 - 1, Math.sin(angle) * radius - 15);
      stone.rotation.y = R() * Math.PI;
      stone.rotation.z = (R() - 0.5) * 0.1;
      group.add(stone);
    }
    // Center altar stone
    const altar = new Mesh(new CylinderGeometry(0.4, 0.5, 0.4, 6), stoneMat);
    altar.position.set(0, -0.8, -15);
    group.add(altar);
  } else if (theme.stoneType === 'dolmen') {
    // Dolmen trilithon
    const capstone = new Mesh(new BoxGeometry(3.5, 0.4, 2), stoneMat);
    capstone.position.set(0, 1.8, -12);
    group.add(capstone);
    const left = new Mesh(new BoxGeometry(0.4, 2.2, 0.6), stoneMat);
    left.position.set(-1.4, 0.1, -12);
    group.add(left);
    const right = left.clone();
    right.position.set(1.4, 0.1, -12);
    group.add(right);
    // Scattered stones
    for (let i = 0; i < theme.stoneDensity; i++) {
      const h = 0.5 + R() * 1.5;
      const m = new Mesh(new CylinderGeometry(0.15, 0.22, h, 5), stoneMat);
      m.position.set((R() - 0.5) * 40, h / 2 - 1, -5 - R() * 40);
      m.rotation.y = R() * Math.PI;
      group.add(m);
    }
  } else if (theme.stoneType === 'ruins') {
    // Ruined celtic walls
    for (let i = 0; i < 5; i++) {
      const w = 0.5 + R() * 0.4;
      const h = 0.4 + R() * 1.2;
      const d = 2 + R() * 3;
      const m = new Mesh(new BoxGeometry(w, h, d), stoneMat);
      m.position.set((R() - 0.5) * 20, h / 2 - 1, -8 - R() * 25);
      m.rotation.y = R() * Math.PI;
      group.add(m);
    }
  } else {
    // Menhirs — default scattered upright stones
    for (let i = 0; i < theme.stoneDensity; i++) {
      const h = 1.2 + R() * 2.5;
      const m = new Mesh(new CylinderGeometry(0.14, 0.22, h, 5), stoneMat);
      m.position.set((R() - 0.5) * 60, h / 2 - 1, -5 - R() * 50);
      m.rotation.y = R() * Math.PI;
      m.rotation.z = (R() - 0.5) * 0.12;
      group.add(m);
    }
  }
  return group;
}

// ── Scattered rocks / galets ─────────────────────────────────────────────────
// 8 low-poly boulders dispersed around the path — common to every biome.

function createRocks(groundColor: number): Group {
  const group = new Group();
  const R = () => Math.random();
  // Stone color: slightly lighter/greyer than ground
  const stoneBase = (groundColor & 0xfefefe) + 0x181818;
  const stoneMat = new MeshStandardMaterial({ color: stoneBase, roughness: 0.92, metalness: 0.0, flatShading: true });

  for (let i = 0; i < 8; i++) {
    const scale = 0.4 + R() * 0.8;
    const rock = new Mesh(new SphereGeometry(scale, 4, 3), stoneMat);
    const angle = R() * Math.PI * 2;
    const radius = 4 + R() * 20;
    rock.position.set(
      Math.cos(angle) * radius,
      scale * 0.3 - 1,
      -5 - R() * 35,
    );
    rock.scale.set(1, 0.6 + R() * 0.4, 1);
    rock.rotation.y = R() * Math.PI;
    group.add(rock);
  }
  return group;
}

// ── Ambient particles (fireflies / embers / stars) ────────────────────────────

interface ParticleSystem {
  readonly points: Points;
  update(dt: number): void;
}

function createParticles(color: number, count = 80): ParticleSystem {
  const positions = new Float32Array(count * 3);
  const velocities = new Float32Array(count * 3);
  const phases = new Float32Array(count);
  const R = () => Math.random();

  for (let i = 0; i < count; i++) {
    positions[i * 3 + 0] = (R() - 0.5) * 50;
    positions[i * 3 + 1] = R() * 6 - 0.5;
    positions[i * 3 + 2] = (R() - 0.5) * 50;
    velocities[i * 3 + 0] = (R() - 0.5) * 0.4;
    velocities[i * 3 + 1] = (R() - 0.5) * 0.2;
    velocities[i * 3 + 2] = (R() - 0.5) * 0.4;
    phases[i] = R() * Math.PI * 2;
  }

  const geo = new BufferGeometry();
  geo.setAttribute('position', new BufferAttribute(positions, 3));
  const mat = new PointsMaterial({
    color,
    size: 0.055,
    transparent: true,
    opacity: 0.75,
    blending: AdditiveBlending,
    depthWrite: false,
  });
  const points = new Points(geo, mat);

  const update = (dt: number): void => {
    const speed = dt * 60;
    for (let i = 0; i < count; i++) {
      positions[i * 3 + 0]! += (velocities[i * 3 + 0] ?? 0) * dt;
      positions[i * 3 + 1]! += Math.sin((Date.now() * 0.001 + phases[i]!) * 0.8) * 0.002 * speed;
      positions[i * 3 + 2]! += (velocities[i * 3 + 2] ?? 0) * dt;
      // Wrap within bounds
      if ((positions[i * 3 + 0] ?? 0) > 25)  positions[i * 3 + 0] = -25;
      if ((positions[i * 3 + 0] ?? 0) < -25) positions[i * 3 + 0] = 25;
      if ((positions[i * 3 + 1] ?? 0) > 8)   positions[i * 3 + 1] = -0.5;
      if ((positions[i * 3 + 1] ?? 0) < -1)  positions[i * 3 + 1] = 6;
      if ((positions[i * 3 + 2] ?? 0) > 25)  positions[i * 3 + 2] = -25;
      if ((positions[i * 3 + 2] ?? 0) < -25) positions[i * 3 + 2] = 25;
    }
    geo.attributes['position']!.needsUpdate = true;
  };

  return { points, update };
}

// ── Main export ───────────────────────────────────────────────────────────────

export async function buildGenericBiomeScene(biome: string): Promise<BiomeSceneResult> {
  const theme = THEMES[biome] ?? DEFAULT_THEME;
  const group = new Group();

  // Fog — stored in userData for main.ts to read and apply via sceneManager.updateFog()
  // Density uses FogExp2 formula: 20% visibility at fogFar → density = sqrt(-ln(0.2)) / fogFar
  group.userData['fogColor'] = theme.fogColor;
  group.userData['fogNear'] = theme.fogNear;
  group.userData['fogFar'] = theme.fogFar;
  group.userData['fogDensity'] = Math.sqrt(1.609) / theme.fogFar;

  // Lighting
  group.add(new AmbientLight(theme.ambientColor, 0.8));
  group.add(new HemisphereLight(theme.skyTop, theme.groundColor, 0.5));

  const key = new PointLight(theme.keyColor, 2.0, 35, 1.5);
  key.position.set(0, 6, -5);
  group.add(key);

  const rim = new PointLight(theme.rimColor, 0.8, 20, 2.0);
  rim.position.set(-10, 3, 5);
  group.add(rim);

  // Procedural elements
  group.add(createTerrain(theme.groundColor));
  group.add(createSky(theme.skyTop, theme.skyMid));

  // Trunk color: slightly lighter than ground
  const trunkColor = (theme.groundColor & 0xfefefe) + 0x0a0a08;
  group.add(createTrees(theme.treeCount, trunkColor));
  group.add(createStones(theme));
  group.add(createRocks(theme.groundColor));

  // Ambient particles
  const particles = createParticles(theme.particleColor, 60);
  group.add(particles.points);

  // Outer refs for biome-specific animated elements (captured by update closure)
  let plaineDruideFireLight: PointLight | null = null;
  let plaineDruideFireMesh: Mesh | null = null;
  let maraisWater: Mesh | null = null;
  let maraisWaterTime = 0;
  let landeSporeMesh: Points | null = null;
  let landeSporeTime = 0;
  let cerclesInscriptionMats: MeshStandardMaterial[] = [];
  let cerclesTime = 0;
  let altarRuneRing: Mesh | null = null;
  let altarRuneTime = 0;
  let valleeWispMesh: Points | null = null;
  let valleeWispTime = 0;
  let montsWindMesh: Points | null = null;
  let montsWindTime = 0;
  let montsSnowMeshes: Mesh[] = [];
  let _eagleGroup: Group | null = null;
  let _eagleWingL: Mesh | null = null;
  let _eagleWingR: Mesh | null = null;
  let _eagleAngle = 0;
  let plaineWispMeshes: Mesh[] = [];
  let plaineWispTime = 0;
  let plaineObeliskGlowMat: MeshBasicMaterial | null = null;
  let plaineObeliskTime = 0;
  let maraisWispMeshes: Mesh[] = [];
  let maraisWispTime = 0;

  // Water plane for marais biome
  if (biome === 'marais_korrigans') {
    const waterMat = new MeshStandardMaterial({
      color: 0x1a3a28,
      roughness: 0.1, metalness: 0.35,
      transparent: true, opacity: 0.70,
      emissive: 0x0a2418,
      emissiveIntensity: 0.18,
      flatShading: true,
    });
    const water = new Mesh(new PlaneGeometry(160, 160, 18, 14), waterMat);
    water.rotation.x = -Math.PI / 2;
    water.position.y = -0.6;
    group.add(water);
    maraisWater = water;

    // Korrigan silhouettes — small dark humanoid shapes at swamp's edge
    const korriganMat = new MeshBasicMaterial({ color: 0x050a08 });
    const korriganPositions: Array<[number, number, number]> = [
      [-8, -0.5, -18], [5, -0.5, -22], [-3, -0.5, -30],
      [11, -0.5, -15], [-14, -0.5, -25], [7, -0.5, -35],
    ];
    korriganPositions.forEach(([x, y, z]) => {
      const figure = new Group();
      // Body (short cylinder — korrigans are small)
      const body = new Mesh(new CylinderGeometry(0.18, 0.22, 0.7, 6), korriganMat);
      body.position.y = 0.35;
      figure.add(body);
      // Head (small sphere)
      const head = new Mesh(new SphereGeometry(0.14, 5, 4), korriganMat);
      head.position.y = 0.85;
      figure.add(head);
      // Hat (cone — korrigans wear pointed hats)
      const hat = new Mesh(new ConeGeometry(0.14, 0.35, 6), korriganMat);
      hat.position.y = 1.1;
      figure.add(hat);
      figure.position.set(x, y, z);
      // Random slight rotation for variety
      figure.rotation.y = Math.random() * Math.PI * 2;
      group.add(figure);
    });

    // Chaotic will-o'-wisp particles — korrigans = chaos/trickery, erratic movement
    const wispMat = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.6 });
    for (let i = 0; i < 10; i++) {
      const wisp = new Mesh(new SphereGeometry(0.1, 4, 3), wispMat.clone());
      wisp.position.set(
        (Math.random() - 0.5) * 30,
        0.2 + Math.random() * 1.3,
        -8 - Math.random() * 17,
      );
      wisp.userData = {
        phase: Math.random() * Math.PI * 2,
        noiseX: Math.random() * 10,
        noiseZ: Math.random() * 10,
        speed: 0.8 + Math.random() * 0.6,
      };
      group.add(wisp);
      maraisWispMeshes.push(wisp);
    }

    // Bog body — dark humanoid silhouette partially submerged (atmospheric dread prop)
    const bogMat = new MeshBasicMaterial({ color: 0x050a07 });

    // Torso — tilted, partially submerged
    const bogTorso = new Mesh(new BoxGeometry(0.5, 1.2, 0.3), bogMat);
    bogTorso.position.set(6, -1.8, -20);
    bogTorso.rotation.z = 0.3;
    bogTorso.rotation.y = 0.5;
    group.add(bogTorso);

    // Head
    const bogHead = new Mesh(new SphereGeometry(0.2, 5, 4), bogMat);
    bogHead.position.set(6.3, -0.9, -20);
    group.add(bogHead);

    // Arm reaching up
    const bogArm = new Mesh(new CylinderGeometry(0.06, 0.06, 0.8, 4), bogMat);
    bogArm.position.set(6.7, -1.4, -20);
    bogArm.rotation.z = -0.6;
    group.add(bogArm);

    // Water ripple around the bog body
    const bogRippleMat = new MeshBasicMaterial({ color: 0x1a3020, transparent: true, opacity: 0.4 });
    const bogRipple = new Mesh(new TorusGeometry(0.6, 0.04, 4, 12), bogRippleMat);
    bogRipple.rotation.x = -Math.PI / 2;
    bogRipple.position.set(6, -2.2, -20);
    group.add(bogRipple);
  }

  // Landes bruyere: heather bushes (low orange-purple blobs)
  if (biome === 'landes_bruyere') {
    const heatherMat = new MeshStandardMaterial({ color: 0xcc6633, roughness: 0.9, metalness: 0.0, flatShading: true, emissive: 0x883322, emissiveIntensity: 0.12 });
    for (let i = 0; i < 30; i++) {
      const h = new Mesh(new SphereGeometry(0.3 + Math.random() * 0.4, 5, 4), heatherMat);
      h.scale.y = 0.35;
      h.position.set((Math.random() - 0.5) * 60, -0.75, -5 - Math.random() * 50);
      group.add(h);
    }
    // Heather spore particles — gentle mint-green motes drifting in the wind
    const SPORE_COUNT = 80;
    const sporeGeo = new BufferGeometry();
    const sporePos = new Float32Array(SPORE_COUNT * 3);
    for (let i = 0; i < SPORE_COUNT; i++) {
      sporePos[i * 3]     = (Math.random() - 0.5) * 60;
      sporePos[i * 3 + 1] = 0.3 + Math.random() * 3.0;
      sporePos[i * 3 + 2] = -5 - Math.random() * 50;
    }
    sporeGeo.setAttribute('position', new BufferAttribute(sporePos, 3));
    const sporeMat = new PointsMaterial({ color: 0x88ffaa, size: 0.08, transparent: true, opacity: 0.5, sizeAttenuation: true });
    landeSporeMesh = new Points(sporeGeo, sporeMat);
    group.add(landeSporeMesh);

    // Distant dolmen — Neolithic megalithic monument (two uprights + capstone)
    const dolmenStoneL = new Mesh(
      new BoxGeometry(0.6, 3.5, 0.8),
      new MeshBasicMaterial({ color: 0x2a3020 })
    );
    dolmenStoneL.position.set(-4, -2.25, -35);
    group.add(dolmenStoneL);

    const dolmenStoneR = new Mesh(
      new BoxGeometry(0.6, 3, 0.8),
      new MeshBasicMaterial({ color: 0x1e2818 })
    );
    dolmenStoneR.position.set(-1.5, -2.5, -35);
    group.add(dolmenStoneR);

    const dolmenCap = new Mesh(
      new BoxGeometry(4.5, 0.5, 1.2),
      new MeshBasicMaterial({ color: 0x252f1c })
    );
    dolmenCap.position.set(-2.75, -0.35, -35);
    dolmenCap.rotation.z = 0.03;
    group.add(dolmenCap);

    // Small burial mound (half-sphere dome) behind the dolmen
    const moundMesh = new Mesh(
      new SphereGeometry(2.5, 8, 4, 0, Math.PI * 2, 0, Math.PI / 2),
      new MeshBasicMaterial({ color: 0x1a2010 })
    );
    moundMesh.position.set(-2.75, -3.2, -38);
    group.add(moundMesh);

    // Mysterious hooded figure — distant silhouette, stillness creates dread
    const figureMat = new MeshBasicMaterial({ color: 0x0a0e0a });
    const figureCloak = new Mesh(
      new CylinderGeometry(0.25, 0.45, 1.8, 6),
      figureMat
    );
    figureCloak.position.set(-12, -2.1, -38);
    figureCloak.rotation.x = 0.08;
    group.add(figureCloak);

    const figureHood = new Mesh(
      new SphereGeometry(0.28, 5, 4, 0, Math.PI * 2, 0, Math.PI * 0.65),
      new MeshBasicMaterial({ color: 0x080c08 })
    );
    figureHood.position.set(-12, -0.85, -38);
    group.add(figureHood);
  }

  // Vallee anciens: ruined hut silhouettes with warm glow
  if (biome === 'vallee_anciens') {
    const hutMat = new MeshStandardMaterial({ color: 0x4a3018, roughness: 0.9, metalness: 0.0, flatShading: true });
    const roofMat = new MeshStandardMaterial({ color: 0x6a4820, roughness: 0.85, metalness: 0.0, flatShading: true, emissive: 0x22aa55, emissiveIntensity: 0.08 });
    for (let i = 0; i < 5; i++) {
      const x = (Math.random() - 0.5) * 40;
      const z = -10 - Math.random() * 30;
      const body = new Mesh(new CylinderGeometry(1.2, 1.4, 1.8, 8), hutMat);
      body.position.set(x, -0.1, z);
      group.add(body);
      const roof = new Mesh(new ConeGeometry(1.5, 1.4, 8), roofMat);
      roof.position.set(x, 1.6, z);
      group.add(roof);
    }
    // Load tower_unified.glb as distant landmark
    loadGLB('/assets/models/tower_unified.glb').then(gltf => {
      const tower = gltf.scene.clone();
      tower.position.set(12, 0, -35);
      tower.scale.setScalar(2.5);
      tower.rotation.y = -Math.PI * 0.25;
      group.add(tower);
    }).catch(() => { /* GLB optional */ });
    // Ancestor will-o-wisps — 25 ghostly pale-green motes drifting near the ruins
    const VALLEE_WISP_COUNT = 25;
    const wispGeo = new BufferGeometry();
    const wispPos = new Float32Array(VALLEE_WISP_COUNT * 3);
    for (let i = 0; i < VALLEE_WISP_COUNT; i++) {
      wispPos[i * 3]     = (Math.random() - 0.5) * 30;       // x ∈ [-15, 15]
      wispPos[i * 3 + 1] = 0.5 + Math.random() * 2.0;        // y ∈ [0.5, 2.5]
      wispPos[i * 3 + 2] = -12 - Math.random() * 28;         // z ∈ [-12, -40]
    }
    wispGeo.setAttribute('position', new BufferAttribute(wispPos, 3));
    const wispMat = new PointsMaterial({
      color: 0xaaffcc,
      size: 0.12,
      transparent: true,
      opacity: 0.4,
      blending: AdditiveBlending,
      depthWrite: false,
      sizeAttenuation: true,
    });
    valleeWispMesh = new Points(wispGeo, wispMat);
    group.add(valleeWispMesh);

    // 4 ancient stone stelae — tall carved pillars with faded rune engravings
    const stelaeData: Array<{ geo: [number, number, number]; pos: [number, number, number]; rotY: number; color: number }> = [
      { geo: [0.4, 5, 0.2],    pos: [-10, -0.5, -40], rotY:  0.2,  color: 0x2a3020 },
      { geo: [0.3, 6.5, 0.18], pos: [ -5, -0.5, -43], rotY: -0.1,  color: 0x1a2010 },
      { geo: [0.35, 4, 0.2],   pos: [  3, -0.5, -42], rotY:  0.15, color: 0x1e2818 },
      { geo: [0.4, 7, 0.22],   pos: [ 10, -0.5, -40], rotY: -0.2,  color: 0x2a3020 },
    ];
    const runeMat = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.12 });
    stelaeData.forEach(({ geo, pos, rotY, color }) => {
      const [gw, gh, gd] = geo;
      const [px, py, pz] = pos;
      const stele = new Mesh(
        new BoxGeometry(gw, gh, gd),
        new MeshBasicMaterial({ color }),
      );
      stele.position.set(px, py + gh / 2, pz);
      stele.rotation.y = rotY;
      group.add(stele);
      // Faded rune glow — very thin plane pressed against the front face
      const rune = new Mesh(new PlaneGeometry(0.25, 0.4), runeMat.clone());
      rune.position.set(px, py + gh / 2 + 0.5, pz + gd / 2 + 0.12);
      group.add(rune);
    });
  }

  // Monts brumeux: extra mist rocks (large boulders on ridgeline)
  if (biome === 'monts_brumeux') {
    const R2 = () => Math.random();
    const rockMat = new MeshStandardMaterial({ color: 0x384050, roughness: 0.88, metalness: 0.0, flatShading: true });
    for (let i = 0; i < 6; i++) {
      const s = 1.2 + R2() * 2.0;
      const boulder = new Mesh(new SphereGeometry(s, 5, 4), rockMat);
      boulder.scale.set(1, 0.7 + R2() * 0.3, 1.1 + R2() * 0.4);
      boulder.position.set((R2() - 0.5) * 50, s * 0.2 - 1, -8 - R2() * 40);
      boulder.rotation.y = R2() * Math.PI;
      group.add(boulder);
    }
    // Load rocks_set.glb as additional detail
    loadGLB('/assets/models/rocks_set.glb').then(gltf => {
      const rocks = gltf.scene.clone();
      rocks.position.set(-8, -1.2, -20);
      rocks.scale.setScalar(3.5);
      rocks.rotation.y = Math.PI * 0.3;
      group.add(rocks);
    }).catch(() => { /* GLB optional */ });
    // Alpine wind mist particles — 60 pale icy blue-grey motes drifting across the ridgeline
    const MONTS_WIND_COUNT = 60;
    const windGeo = new BufferGeometry();
    const windPos = new Float32Array(MONTS_WIND_COUNT * 3);
    for (let i = 0; i < MONTS_WIND_COUNT; i++) {
      windPos[i * 3]     = (Math.random() - 0.5) * 50;   // x ∈ [-25, 25]
      windPos[i * 3 + 1] = 0.5 + Math.random() * 7.5;    // y ∈ [0.5, 8]
      windPos[i * 3 + 2] = -5 - Math.random() * 40;      // z ∈ [-5, -45]
    }
    windGeo.setAttribute('position', new BufferAttribute(windPos, 3));
    const windMat = new PointsMaterial({
      color: 0xc0d8e0,
      size: 0.06,
      transparent: true,
      opacity: 0.3,
      sizeAttenuation: true,
    });
    montsWindMesh = new Points(windGeo, windMat);
    group.add(montsWindMesh);
    // Distant mountain ridge silhouettes — 3 peaks in background
    const peakCentral = new Mesh(
      new ConeGeometry(12, 18, 4),
      new MeshBasicMaterial({ color: 0x0a100a }),
    );
    peakCentral.scale.x = 1.8;
    peakCentral.position.set(0, 2, -45);
    group.add(peakCentral);
    const peakLeft = new Mesh(
      new ConeGeometry(9, 13, 4),
      new MeshBasicMaterial({ color: 0x0d150d }),
    );
    peakLeft.position.set(-18, -1, -42);
    group.add(peakLeft);
    const peakRight = new Mesh(
      new ConeGeometry(10, 15, 4),
      new MeshBasicMaterial({ color: 0x0c130c }),
    );
    peakRight.position.set(16, 0, -44);
    group.add(peakRight);
    // Thin mist plane spanning mountain base
    const mistPlane = new Mesh(
      new PlaneGeometry(80, 6),
      new MeshBasicMaterial({ color: 0x1a2a1a, transparent: true, opacity: 0.3, side: DoubleSide }),
    );
    mistPlane.position.set(0, -1, -43);
    mistPlane.rotation.x = -0.12;
    group.add(mistPlane);
    // Snowflake particles — 60 pale white flakes falling gently across the ridge
    const snowGeo = new SphereGeometry(0.06, 3, 2);
    const snowMat = new MeshBasicMaterial({ color: 0xddeeff, transparent: true, opacity: 0.7 });
    for (let i = 0; i < 60; i++) {
      const snow = new Mesh(snowGeo, snowMat);
      const sx = (Math.random() - 0.5) * 60;
      const sy = -1 + Math.random() * 11;
      const sz = -3 - Math.random() * 39;
      snow.position.set(sx, sy, sz);
      snow.userData = {
        speed: 0.5 + Math.random() * 0.5,
        driftX: (Math.random() - 0.5) * 0.3,
        startY: sy,
      };
      group.add(snow);
      montsSnowMeshes.push(snow);
    }
    // Soaring eagle silhouette — flat BoxGeometry planes grouped and animated in a slow circle
    const eagleMat = new MeshBasicMaterial({ color: 0x0a0f0a });
    const eagleGroup = new Group();
    // Body
    const eagleBody = new Mesh(new BoxGeometry(0.15, 0.08, 0.6), eagleMat);
    eagleGroup.add(eagleBody);
    // Left wing
    const wingL = new Mesh(new BoxGeometry(1.8, 0.04, 0.5), eagleMat);
    wingL.position.set(-0.95, 0, 0.05);
    wingL.rotation.z = -0.3;
    eagleGroup.add(wingL);
    // Right wing
    const wingR = new Mesh(new BoxGeometry(1.8, 0.04, 0.5), eagleMat);
    wingR.position.set(0.95, 0, 0.05);
    wingR.rotation.z = 0.3;
    eagleGroup.add(wingR);
    // Tail
    const eagleTail = new Mesh(new BoxGeometry(0.08, 0.04, 0.35), eagleMat);
    eagleTail.position.set(0, 0, -0.47);
    eagleGroup.add(eagleTail);
    // Initial position
    eagleGroup.position.set(8, 12, -50);
    group.add(eagleGroup);
    _eagleGroup = eagleGroup;
    _eagleWingL = wingL;
    _eagleWingR = wingR;
  }

  // Cercles de Pierres: Neolithic standing stone ring (7 stones in a circle)
  if (biome === 'cercles_pierres') {
    // Outer ring of 8 peripheral standing stones (background, added C279)
    const STONE_RING_RADIUS = 8;
    const STONE_COLORS = [0x2a3020, 0x1e2818, 0x1a2a14, 0x2a3020, 0x1e2818, 0x1a2a14, 0x2a3020, 0x1e2818];
    const STONE_HEIGHTS = [3.5, 5.0, 4.2, 3.8, 5.5, 3.2, 4.8, 4.0];
    const STONE_WIDTHS = [0.5, 0.4, 0.55, 0.45, 0.4, 0.5, 0.45, 0.5];
    for (let i = 0; i < 8; i++) {
      const angle = (i / 8) * Math.PI * 2;
      const x = Math.cos(angle) * STONE_RING_RADIUS;
      const z = -15 + Math.sin(angle) * STONE_RING_RADIUS;
      const h = STONE_HEIGHTS[i];
      const w = STONE_WIDTHS[i];
      const stoneGeo = new BoxGeometry(w, h, w * 0.6);
      const stoneMat2 = new MeshBasicMaterial({ color: STONE_COLORS[i] });
      const stone = new Mesh(stoneGeo, stoneMat2);
      stone.position.set(x, h / 2 - 3, z);
      stone.rotation.y = angle;
      stone.rotation.z = (Math.random() - 0.5) * 0.08;
      group.add(stone);
    }

    const R2 = () => Math.random();
    const stoneMat = new MeshStandardMaterial({
      color: 0x6a5e48, roughness: 0.90, metalness: 0.0, flatShading: true,
      emissive: 0x221810, emissiveIntensity: 0.06,
    });
    const inscriptionMat = new MeshStandardMaterial({
      color: 0x8a7a5e, roughness: 0.85, metalness: 0.0, flatShading: true,
      emissive: 0x33ff66, emissiveIntensity: 0.04,
    });
    // Collect mats for pulsing animation
    cerclesInscriptionMats = [inscriptionMat, stoneMat];
    const RING_R = 7.5;
    const STONE_COUNT = 7;
    for (let i = 0; i < STONE_COUNT; i++) {
      const angle = (i / STONE_COUNT) * Math.PI * 2;
      const ht = 2.4 + R2() * 1.6;
      const stone = new Mesh(new BoxGeometry(0.55 + R2() * 0.25, ht, 0.35 + R2() * 0.15), stoneMat);
      stone.position.set(Math.cos(angle) * RING_R, ht / 2 - 1.0, Math.sin(angle) * RING_R - 15);
      stone.rotation.y = angle + (R2() - 0.5) * 0.3;
      stone.rotation.z = (R2() - 0.5) * 0.08;
      stone.castShadow = true;
      group.add(stone);
    }
    // Central altar flat stone — uses inscriptionMat (emissive 0x33ff66)
    const altar = new Mesh(new BoxGeometry(2.0, 0.25, 1.0), inscriptionMat);
    altar.position.set(0, -0.62, -15);
    group.add(altar);
    // Two altar uprights
    const upright1 = new Mesh(new BoxGeometry(0.25, 1.2, 0.25), stoneMat);
    upright1.position.set(-0.7, -0.25, -15);
    group.add(upright1);
    const upright2 = new Mesh(new BoxGeometry(0.25, 1.2, 0.25), stoneMat);
    upright2.position.set(0.7, -0.25, -15);
    group.add(upright2);
    // Central altar flat stone (cylinder)
    const altarStone = new Mesh(
      new CylinderGeometry(1.2, 1.4, 0.25, 8),
      new MeshLambertMaterial({ color: 0x2a3a2a, emissive: 0x0a1a0a }),
    );
    altarStone.position.set(0, -0.87, -15);
    group.add(altarStone);
    // Rotating rune ring flat on ground
    const runeMat = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.6 });
    altarRuneRing = new Mesh(new TorusGeometry(2.5, 0.08, 6, 32), runeMat);
    altarRuneRing.position.set(0, -0.75, -15);
    altarRuneRing.rotation.x = -Math.PI / 2;
    group.add(altarRuneRing);
  }

  // Plaine des Druides: scattered ritual poles + central sacred fire
  if (biome === 'plaine_druides') {
    const R2 = () => Math.random();
    const poleMat = new MeshStandardMaterial({
      color: 0x3c2810, roughness: 0.98, metalness: 0.0, flatShading: true,
    });
    const totemMat = new MeshStandardMaterial({
      color: 0x5a3818, roughness: 0.92, metalness: 0.0, flatShading: true,
      emissive: 0x22aa55, emissiveIntensity: 0.15,
    });
    // 8 ritual poles scattered around path
    for (let i = 0; i < 8; i++) {
      const side = i % 2 === 0 ? 1 : -1;
      const pole = new Mesh(new CylinderGeometry(0.06, 0.08, 3.0 + R2() * 1.5, 5), poleMat);
      pole.position.set(side * (4 + R2() * 5), 0.2, -5 - i * 7 + R2() * 3);
      pole.rotation.z = (R2() - 0.5) * 0.12;
      group.add(pole);
      // Small totem cap
      const cap = new Mesh(new SphereGeometry(0.14, 4, 3), totemMat);
      cap.position.set(pole.position.x, pole.position.y + 1.7 + R2() * 0.7, pole.position.z);
      group.add(cap);
    }
    // Central sacred fire pit (3 flat stones around a glow)
    const fireStoneMat = new MeshStandardMaterial({ color: 0x4a3828, roughness: 0.88, flatShading: true });
    for (let i = 0; i < 3; i++) {
      const angle = (i / 3) * Math.PI * 2;
      const fs = new Mesh(new BoxGeometry(0.5, 0.15, 0.28), fireStoneMat);
      fs.position.set(Math.cos(angle) * 0.7, -0.72, -18 + Math.sin(angle) * 0.7);
      fs.rotation.y = angle;
      group.add(fs);
    }
    const fireMat = new MeshStandardMaterial({
      color: 0xff5500, emissive: 0xff3300, emissiveIntensity: 1.2,
      flatShading: true, roughness: 1.0, metalness: 0.0,
    });
    const fireCore = new Mesh(new SphereGeometry(0.22, 4, 3), fireMat);
    fireCore.position.set(0, -0.45, -18);
    group.add(fireCore);
    // Sacred fire PointLight
    const fireLight = new PointLight(0xff5500, 2.0, 12);
    fireLight.position.set(0, 0, -18);
    group.add(fireLight);
    // Store references for animation in update()
    plaineDruideFireLight = fireLight;
    plaineDruideFireMesh = fireCore;
    // Orbiting druid wisps — 8 green will-o'-wisps circling the druid stone
    const wispGeo = new SphereGeometry(0.12, 6, 4);
    for (let i = 0; i < 8; i++) {
      const wispMat = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.7 });
      const wisp = new Mesh(wispGeo, wispMat);
      const orbitRadius = 4 + (i % 3) * 1.5;
      const orbitY = 1.2 + (i % 4) * 0.4;
      wisp.userData = { orbitRadius, orbitY, phase: (i / 8) * Math.PI * 2, speed: 0.4 + (i % 3) * 0.15 };
      group.add(wisp);
      plaineWispMeshes.push(wisp);
    }
    // Central obelisk monument
    const obeliskBodyMat = new MeshBasicMaterial({ color: 0x2a3020 });
    const obeliskBody = new Mesh(new CylinderGeometry(0.4, 0.6, 10, 4), obeliskBodyMat);
    obeliskBody.position.set(0, 0, -18);
    group.add(obeliskBody);
    const obeliskCapMat = new MeshBasicMaterial({ color: 0x2a3020 });
    const obeliskCap = new Mesh(new CylinderGeometry(0, 0.4, 1.5, 4), obeliskCapMat);
    obeliskCap.position.set(0, 5.75, -18);
    group.add(obeliskCap);
    // Rune inscription glow on obelisk face
    const glowMat = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.2 });
    const glowPlane = new Mesh(new PlaneGeometry(0.3, 1.2), glowMat);
    glowPlane.position.set(0, 0, -17.45);
    group.add(glowPlane);
    plaineObeliskGlowMat = glowMat;
  }

  const update = (dt: number): void => {
    particles.update(dt);
    // Gentle key light flicker
    key.intensity = 1.9 + Math.sin(Date.now() * 0.002) * 0.15;
    // Sacred fire flicker for plaine_druides
    if (plaineDruideFireLight !== null) {
      plaineDruideFireLight.intensity = 2.0 + Math.sin(Date.now() * 0.008) * 0.6 + (Math.random() - 0.5) * 0.3;
    }
    if (plaineDruideFireMesh !== null) {
      (plaineDruideFireMesh.material as MeshStandardMaterial).emissiveIntensity =
        1.2 + Math.sin(Date.now() * 0.012) * 0.4;
    }
    // Plaine des Druides — orbiting druid wisps
    if (plaineWispMeshes.length > 0) {
      plaineWispTime += dt;
      for (const wisp of plaineWispMeshes) {
        const { orbitRadius, orbitY, phase, speed } = wisp.userData as { orbitRadius: number; orbitY: number; phase: number; speed: number };
        const angle = plaineWispTime * speed + phase;
        wisp.position.set(
          Math.cos(angle) * orbitRadius,
          orbitY + Math.sin(plaineWispTime * 1.3 + phase) * 0.2,
          Math.sin(angle) * orbitRadius - 12,
        );
        (wisp.material as MeshBasicMaterial).opacity = 0.5 + Math.sin(plaineWispTime * 2 + phase) * 0.2;
      }
    }
    // Plaine des Druides — obelisk rune glow pulse
    if (plaineObeliskGlowMat) {
      plaineObeliskTime += dt;
      plaineObeliskGlowMat.opacity = 0.12 + Math.sin(plaineObeliskTime * 0.6) * 0.08;
    }
    // Marais korrigans — chaotic will-o'-wisp particles
    if (maraisWispMeshes.length > 0) {
      maraisWispTime += dt;
      for (const wisp of maraisWispMeshes) {
        const { phase, noiseX, noiseZ, speed } = wisp.userData as { phase: number; noiseX: number; noiseZ: number; speed: number };
        const t = maraisWispTime * speed;
        wisp.position.x = Math.sin(t * 0.7 + noiseX) * 8 + Math.sin(t * 1.3 + phase) * 4;
        wisp.position.y = 0.6 + Math.sin(t * 1.1 + phase) * 0.4 + Math.abs(Math.sin(t * 2.3)) * 0.3;
        wisp.position.z = -15 + Math.sin(t * 0.5 + noiseZ) * 8 + Math.cos(t * 0.9) * 3;
        // Erratic opacity flicker
        (wisp.material as MeshBasicMaterial).opacity = 0.3 + Math.abs(Math.sin(t * 4.5 + phase)) * 0.5;
      }
    }
    // Marais swamp water — subtle vertex displacement ripple
    if (maraisWater !== null) {
      maraisWaterTime += dt;
      const pos = maraisWater.geometry.attributes['position'] as BufferAttribute;
      const arr = pos.array as Float32Array;
      const width = 19; // PlaneGeometry(160,160,18,14) → 18+1 = 19 verts/row
      const height = 15; // 14+1 = 15 rows
      for (let j = 0; j < height; j++) {
        for (let i = 0; i < width; i++) {
          const idx = (j * width + i) * 3;
          const x = arr[idx]!;
          const y = arr[idx + 1]!;
          // Slow swamp ripple — much gentler than coast ocean (bog water barely moves)
          const wave =
            Math.sin(x * 0.08 + maraisWaterTime * 0.4) * 0.12 +
            Math.cos(y * 0.11 + maraisWaterTime * 0.3 + 1.5) * 0.08 +
            Math.sin(x * 0.15 + y * 0.09 + maraisWaterTime * 0.5) * 0.05;
          arr[idx + 2] = wave;
        }
      }
      pos.needsUpdate = true;
      maraisWater.geometry.computeVertexNormals();
    }
    // Landes bruyere spore drift — slow rightward wind + gentle vertical bob
    if (landeSporeMesh !== null) {
      landeSporeTime += dt;
      const pos = landeSporeMesh.geometry.getAttribute('position') as BufferAttribute;
      for (let i = 0; i < pos.count; i++) {
        pos.setX(i, pos.getX(i) + 0.3 * dt);
        pos.setY(i, pos.getY(i) + Math.sin(landeSporeTime * 0.5 + i * 0.7) * 0.015);
        if (pos.getX(i) > 30) pos.setX(i, -30);
      }
      pos.needsUpdate = true;
    }
    // Cercles de Pierres — pulsing Ogham inscription emissive
    if (cerclesInscriptionMats.length > 0) {
      cerclesTime += dt;
      // Index 0 = inscriptionMat (altar, brighter pulse), index 1 = stoneMat (subtler)
      const insMat = cerclesInscriptionMats[0];
      const stMat  = cerclesInscriptionMats[1];
      if (insMat !== undefined) {
        insMat.emissiveIntensity = 0.3 + Math.sin(cerclesTime * 0.5) * 0.2;
      }
      if (stMat !== undefined) {
        stMat.emissiveIntensity = 0.06 + Math.sin(cerclesTime * 0.3) * 0.04;
      }
    }
    // Cercles de Pierres — rotating altar rune ring
    if (altarRuneRing !== null) {
      altarRuneTime += dt;
      altarRuneRing.rotation.z += dt * 0.25;
      (altarRuneRing.material as MeshBasicMaterial).opacity = 0.4 + Math.sin(altarRuneTime * 1.2) * 0.25;
    }
    // Vallee Anciens — ancestor will-o-wisp drift
    if (valleeWispMesh !== null) {
      valleeWispTime += dt;
      const pos = valleeWispMesh.geometry.getAttribute('position') as BufferAttribute;
      for (let i = 0; i < pos.count; i++) {
        const phase = i * 0.8;
        pos.setY(i, pos.getY(i) + Math.sin(valleeWispTime * 0.4 + phase) * 0.008);
        pos.setX(i, pos.getX(i) + Math.cos(valleeWispTime * 0.3 + phase * 0.7) * 0.006);
        // Wrap Y to keep wisps hovering above ground
        if (pos.getY(i) > 3.0)  pos.setY(i, 0.5);
        if (pos.getY(i) < 0.3)  pos.setY(i, 2.5);
        // Wrap X within scene bounds
        if (pos.getX(i) > 15)  pos.setX(i, -15);
        if (pos.getX(i) < -15) pos.setX(i, 15);
      }
      pos.needsUpdate = true;
    }
    // Monts brumeux — alpine wind mist drift (fast rightward + gentle vertical float)
    if (montsWindMesh !== null) {
      montsWindTime += dt;
      const t = montsWindTime;
      const pos = montsWindMesh.geometry.getAttribute('position') as BufferAttribute;
      for (let i = 0; i < pos.count; i++) {
        pos.setX(i, pos.getX(i) + 4.0 * dt + Math.sin(t * 0.2 + i * 0.5) * 0.02);
        pos.setY(i, pos.getY(i) + 0.3 * dt * Math.sin(t * 0.15 + i * 0.9));
        if (pos.getX(i) > 25)  pos.setX(i, -25);
        if (pos.getY(i) > 8)   pos.setY(i, 0.5);
      }
      pos.needsUpdate = true;
    }
    // Monts brumeux — snowflakes falling gently with slight lateral drift
    for (const snow of montsSnowMeshes) {
      snow.position.y -= snow.userData['speed'] * dt;
      snow.position.x += snow.userData['driftX'] * dt;
      if (snow.position.y < -2) {
        snow.position.y = snow.userData['startY'];
        snow.position.x = (Math.random() - 0.5) * 60;
      }
    }
    // Monts brumeux — soaring eagle slow circle + wing flap
    if (_eagleGroup !== null) {
      _eagleAngle += dt * 0.12;
      const t = Date.now() * 0.001;
      _eagleGroup.position.x = Math.cos(_eagleAngle) * 10 + 0;
      _eagleGroup.position.z = Math.sin(_eagleAngle) * 8 - 45;
      _eagleGroup.rotation.y = -_eagleAngle + Math.PI / 2;
      if (_eagleWingL !== null) {
        _eagleWingL.rotation.z = -0.3 + Math.sin(t * 1.8) * 0.15;
      }
      if (_eagleWingR !== null) {
        _eagleWingR.rotation.z = 0.3 - Math.sin(t * 1.8) * 0.15;
      }
    }
  };

  const dispose = (): void => {
    plaineWispMeshes = [];
    plaineObeliskGlowMat = null;
    maraisWispMeshes = [];
    montsSnowMeshes = [];
    altarRuneRing = null;
    _eagleGroup = null;
    _eagleWingL = null;
    _eagleWingR = null;
    group.traverse((obj) => {
      if (obj instanceof Mesh) {
        obj.geometry.dispose();
        if (Array.isArray(obj.material)) obj.material.forEach((m) => m.dispose());
        else (obj.material as MeshStandardMaterial).dispose();
      }
    });
  };

  return { group, update, dispose };
}
