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
  CircleGeometry, Color, ConeGeometry, CylinderGeometry, DodecahedronGeometry, DoubleSide, Fog, Group, HemisphereLight,
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
  let crystalGroups366: Group[] = [];
  let crystalLights366: PointLight[] = [];
  let _eagleGroup: Group | null = null;
  let _eagleWingL: Mesh | null = null;
  let _eagleWingR: Mesh | null = null;
  let _eagleAngle = 0;
  let _lakeMesh: Mesh | null = null;
  let _lakeLight: PointLight | null = null;
  let _waterfallGroup: Group | null = null;
  let _waterfallLight: PointLight | null = null;
  let _goatGroup: Group | null = null;
  let _goatHead: Mesh | null = null;
  let _goatTail: Mesh | null = null;
  let _goatBody: Mesh | null = null;
  let plaineWispMeshes: Mesh[] = [];
  let plaineWispTime = 0;
  let plaineObeliskGlowMat: MeshBasicMaterial | null = null;
  let plaineObeliskTime = 0;
  let _wellGroup: Group | null = null;
  let _wellBucket: Mesh | null = null;
  let _wellLight: PointLight | null = null;
  let _moonGroup: Group | null = null;
  let _moonHalo: Mesh | null = null;
  let _moonLight: PointLight | null = null;
  const _cropCircleMeshes: Mesh[] = [];
  let _cropCircleLight: PointLight | null = null;
  let _cropCircleTime = 0;
  // ── Menhir procession (C354) ─────────────────────────────────────────────
  let menhirGroup354: Group | null = null;
  let menhirMeshes354: Mesh[] = [];
  let menhirLights354: PointLight[] = [];
  let _menhirElapsed354 = 0;
  let maraisWispMeshes: Mesh[] = [];
  let maraisWispTime = 0;
  const _bogFireflies: Mesh[] = [];
  const _bogFireflyLights: PointLight[] = [];
  const _fogTendrils: Mesh[] = [];
  let _lureWisp: Mesh | null = null;
  let _lureLight: PointLight | null = null;
  const _lureTrailOrbs: Mesh[] = [];
  const _lureTrailPositions: Array<[number, number, number]> = [];
  const _auroraBands: Mesh[] = [];
  let _auroraTime = 0;
  let _deadTreeGroup: Group | null = null;
  let _templeGroup: Group | null = null;
  let _gateGroup: Group | null = null;
  let _gateLight: PointLight | null = null;
  let _gateRunePlane: Mesh | null = null;
  const _altarFireMeshes: Mesh[] = [];
  let _altarFireLight: PointLight | null = null;
  const _dancerGroups: Group[] = [];
  const _dancerArmGroups: Group[] = [];
  const _ravenGroups: Group[] = [];
  const _ravenWings: Mesh[] = [];
  const _heatherMeshes: Mesh[] = [];
  let _moorCircleGroup: Group | null = null;
  let _moorCircleLight: PointLight | null = null;
  let _watchtowerGroup: Group | null = null;
  let _watchtowerLight: PointLight | null = null;
  const _spiritBeams: Mesh[] = [];
  const _spiritLights: PointLight[] = [];
  let _spiritBeamTime = 0;
  // ── Crow on dolmen (C358) ─────────────────────────────────────────────────
  let crowGroup358: Group | null = null;
  let crowWings358: Mesh[] = [];
  let crowWingMat358: MeshStandardMaterial | null = null;
  let crowNextFlap358 = 0;
  let crowFlapT358 = -1;

  // ── Ignis fatuus wisp procession (C386) ──────────────────────────────────
  let ignisFatuusGroup386: Group | null = null;
  let ignisMeshes386: Mesh[] = [];
  let ignisLights386: PointLight[] = [];
  let ignisTime386 = 0;
  let ignisDirection386 = 1;
  let ignisNextReverse386 = 15.0;

  // Moonbeam shaft — cercles_pierres (C362)
  let moonbeamMesh362: Mesh | null = null;
  let moonbeamLight362: PointLight | null = null;

  // Cloaked druid silhouettes — cercles_pierres (C390)
  let druidGroup390: Group | null = null;
  let druidArmLeft390: Mesh | null = null;
  let druidArmRight390: Mesh | null = null;

  // ── Ancient tomb entrance — vallee_anciens (C378) ─────────────────────────
  let tombGroup378: Group | null = null;
  let tombGlowLight378: PointLight | null = null;
  let tombFlareT378 = -1;
  let tombNextFlare378 = 10.0;

  // ── Ritual bonfire — plaine_druides (C370) ───────────────────────────────
  let bonfireGroup370: Group | null = null;
  let bonfireFlames370: Mesh[] = [];
  let bonfireLight370: PointLight | null = null;
  let bonfireEmbers370: Mesh[] = [];
  let bonfireEmberData370: Array<{ vy: number; life: number; maxLife: number }> = [];
  let bonfireElapsed370 = 0;

  // ── Giant sleeping toad on lily pad — marais_korrigans (C374) ────────────
  let toadGroup374: Group | null = null;
  let toadBody374: Mesh | null = null;

  // ── Harvest scarecrow silhouette — plaine_druides (C382) ─────────────────
  let scarecrowGroup382: Group | null = null;
  let scarecrowEyes382: Mesh[] = [];

  // ── Korrigan spirit dancers — marais_korrigans (C394) ────────────────────
  let korrGroup394: Group | null = null;
  let korrFigures394: Group[] = [];
  let korrTime394 = 0;
  let korrDir394 = 1;
  let korrNextDir394 = 8.0;

  // ── Hermit's mountain cave entrance — monts_brumeux (C398) ───────────────
  let caveGroup398: Group | null = null;
  let caveGlowLight398: PointLight | null = null;
  let caveShadowT398 = -1;
  let caveNextShadow398 = 10.0;

  // ── Stone labyrinth ruins — vallee_anciens (C403) ─────────────────────────
  let labyrinthGroup403: Group | null = null;
  let labyrinthMossT403 = 0;

  // ── Central altar ritual fire — cercles_pierres (C407) ────────────────────
  let altarFireGroup407: Group | null = null;
  let altarFireT407 = 0;
  const altarEmbers407: Mesh[] = [];
  const altarEmberVel407: { vx: number; vy: number; life: number; maxLife: number }[] = [];
  let altarFireCone407: Mesh | null = null;
  let altarFireLight407: PointLight | null = null;

  // ── Soaring eagle — monts_brumeux (C412) ──────────────────────────────────
  let eagleGroup412: Group | null = null;
  let eagleT412 = 0;
  let eagleWingT412 = 0;
  let eagleWingL412: Mesh | null = null;
  let eagleWingR412: Mesh | null = null;

  // ── Carved menhir with glowing spirals — landes_bruyere (C417) ───────────
  let menhirGroup417: Group | null = null;
  let menhirT417 = 0;
  const menhirCarveGlows417: Mesh[] = [];
  let menhirLight417: PointLight | null = null;

  // ── Rotting swamp dock — marais_korrigans (C422) ──────────────────────────
  let swampDockGroup422: Group | null = null;
  let swampDockT422 = 0;
  const swampDockAlgae422: Mesh[] = [];
  let swampDockLight422: PointLight | null = null;

  // ── Spectral ghost apparition — vallee_anciens (C425) ────────────────────
  let ghostGroup425: Group | null = null;
  let ghostT425 = 0;
  let ghostPhaseTimer425 = 0;
  let ghostNextAppear425 = 5 + Math.random() * 10;
  let ghostBody425: Mesh | null = null;
  let ghostHead425: Mesh | null = null;
  let ghostLight425: PointLight | null = null;

  // ── Stone sundial — plaine_druides (C429) ────────────────────────────────
  let sundialGroup429: Group | null = null;
  let sundialT429 = 0;
  let sundialShadow429: Mesh | null = null;
  let sundialLight429: PointLight | null = null;

  // ── Moonrise arc — cercles_pierres (C433) ────────────────────────────────
  let stoneMoonGroup433: Group | null = null;
  let stoneMoonT433 = 0;
  let stoneMoonMesh433: Mesh | null = null;
  let stoneMoonLight433: PointLight | null = null;

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

    // Dead gnarled tree — stillness = menace (NO animation)
    const treeMat = new MeshStandardMaterial({ color: 0x0c110c, roughness: 0.95, metalness: 0.0 });
    _deadTreeGroup = new Group();

    // Main trunk
    const trunk = new Mesh(new CylinderGeometry(0.18, 0.28, 5.0, 5), treeMat);
    trunk.position.set(0, 2.5, 0);
    trunk.rotation.z = 0.08;
    _deadTreeGroup.add(trunk);

    // Branch 1 — upper left
    const branch1 = new Mesh(new CylinderGeometry(0.06, 0.12, 2.5, 4), treeMat);
    branch1.position.set(-1.2, 4.5, 0);
    branch1.rotation.z = -0.7;
    branch1.rotation.y = 0.3;
    _deadTreeGroup.add(branch1);

    // Branch 2 — upper right
    const branch2 = new Mesh(new CylinderGeometry(0.05, 0.10, 2.0, 4), treeMat);
    branch2.position.set(1.0, 4.2, 0.1);
    branch2.rotation.z = 0.6;
    branch2.rotation.y = -0.5;
    _deadTreeGroup.add(branch2);

    // Branch 3 — mid left drooping
    const branch3 = new Mesh(new CylinderGeometry(0.04, 0.08, 1.8, 4), treeMat);
    branch3.position.set(-0.9, 2.8, 0.2);
    branch3.rotation.z = -1.1;
    _deadTreeGroup.add(branch3);

    // Twig 1 — from branch 1 tip
    const twig1 = new Mesh(new CylinderGeometry(0.02, 0.04, 1.0, 3), treeMat);
    twig1.position.set(-2.2, 5.2, 0.1);
    twig1.rotation.z = -0.5;
    _deadTreeGroup.add(twig1);

    // Twig 2 — from branch 2 tip
    const twig2 = new Mesh(new CylinderGeometry(0.02, 0.04, 0.8, 3), treeMat);
    twig2.position.set(1.8, 5.0, 0.2);
    twig2.rotation.z = 0.4;
    _deadTreeGroup.add(twig2);

    _deadTreeGroup.position.set(15, 2.5, -20);
    group.add(_deadTreeGroup);

    // Erratic firefly swarm — 18 malevolent motes lurching through the bog (C319)
    // 12 bright (0x33ff66) + 6 dim (0x1a5522), scattered x=[-15,15] y=[0.3,2.5] z=[-8,-32]
    const _ffGeo = new SphereGeometry(0.05, 4, 3);
    for (let i = 0; i < 18; i++) {
      const isBright = i < 12;
      const ffMat = new MeshBasicMaterial({
        color: isBright ? 0x33ff66 : 0x1a5522,
        transparent: true,
        opacity: 0.8,
      });
      const ff = new Mesh(_ffGeo, ffMat);
      const R = Math.random;
      ff.position.set(
        (R() - 0.5) * 30,       // x ∈ [-15, 15]
        0.3 + R() * 2.2,         // y ∈ [0.3, 2.5]
        -8 - R() * 24,           // z ∈ [-8, -32]
      );
      // Target position and state
      ff.userData = {
        tx: ff.position.x,
        ty: ff.position.y,
        tz: ff.position.z,
        moveSpeed: 2.0 + R() * 2.0,   // 2.0–4.0
        moveTimer: 0,
        restTimer: 0,
        resting: false,
        phase: R() * Math.PI * 2,
      };
      group.add(ff);
      _bogFireflies.push(ff);

      // Every 3rd bright firefly gets a point light
      if (isBright && i % 3 === 0) {
        const ffLight = new PointLight(0x33ff66, 0.0, 0);
        ffLight.position.copy(ff.position);
        group.add(ffLight);
        _bogFireflyLights.push(ffLight);
        ff.userData['lightIndex'] = _bogFireflyLights.length - 1;
      }
    }
    // Assign fresh random targets to all fireflies
    for (const ff of _bogFireflies) {
      const R = Math.random;
      ff.userData['tx'] = (R() - 0.5) * 30;
      ff.userData['ty'] = 0.3 + R() * 2.2;
      ff.userData['tz'] = -8 - R() * 24;
      ff.userData['moveTimer'] = 1.2 + R() * 1.3; // initial move interval 1.2–2.5s
    }

    // Creeping fog tendrils — 6 low-rising planes hugging the swamp ground (C334)
    for (let i = 0; i < 6; i++) {
      const R = Math.random;
      const tendrilMat = new MeshBasicMaterial({
        color: 0x061408,
        transparent: true,
        opacity: 0,
        side: DoubleSide,
        depthWrite: false,
      });
      const tendril = new Mesh(
        new PlaneGeometry(4.0 + R() * 2.0, 1.5 + R() * 0.8),
        tendrilMat,
      );
      const baseX = (R() - 0.5) * 24;  // x ∈ [-12, 12]
      const baseZ = -8 - R() * 22;     // z ∈ [-8, -30]
      tendril.rotation.x = -Math.PI / 2 + 0.15;
      tendril.position.set(baseX, 0.08, baseZ);
      tendril.userData = {
        baseX,
        baseZ,
        phase: R() * Math.PI * 2,
        speed: 0.05 + R() * 0.07,      // 0.05–0.12 (extremely slow)
        maxOpacity: 0.08 + R() * 0.10, // 0.08–0.18
      };
      group.add(tendril);
      _fogTendrils.push(tendril);
    }

    // Lure wisp — large beckoning will-o'-wisp on figure-8 path (C345)
    const lureMat = new MeshBasicMaterial({ color: 0x33ff66 });
    const lureOrb = new Mesh(new SphereGeometry(0.3, 8, 6), lureMat);
    lureOrb.position.set(0, 1.2, -18);
    group.add(lureOrb);
    _lureWisp = lureOrb;

    const lureLight = new PointLight(0x33ff66, 0.8, 8);
    lureLight.position.copy(lureOrb.position);
    group.add(lureLight);
    _lureLight = lureLight;

    // Trail orbs (5 progressively older positions)
    const trailScales: number[] = [0.7, 0.55, 0.4, 0.25, 0.1];
    const trailOpacities: number[] = [0.6, 0.45, 0.3, 0.18, 0.08];
    for (let i = 0; i < 5; i++) {
      const trailMat = new MeshBasicMaterial({
        color: 0x33ff66,
        transparent: true,
        opacity: trailOpacities[i]!,
      });
      const trailOrb = new Mesh(new SphereGeometry(0.10, 5, 3), trailMat);
      trailOrb.position.set(0, 1.2, -18);
      trailOrb.scale.setScalar(trailScales[i]!);
      group.add(trailOrb);
      _lureTrailOrbs.push(trailOrb);
    }
    // Seed trail with current position so orbs don't start at origin
    for (let i = 0; i < 5; i++) {
      _lureTrailPositions.push([0, 1.2, -18]);
    }

    // Giant sleeping toad on lily pad (C374)
    toadGroup374 = new Group();

    // Lily pad
    const padGeo = new CylinderGeometry(0.7, 0.7, 0.04, 12);
    const padMat = new MeshStandardMaterial({ color: 0x071f07, roughness: 0.9 });
    const pad = new Mesh(padGeo, padMat);
    pad.position.y = -0.02;
    toadGroup374.add(pad);

    // Toad body
    const bodyGeo = new SphereGeometry(0.35, 8, 6);
    const bodyMat = new MeshStandardMaterial({
      color: 0x0a1f0a, roughness: 0.85, emissive: new Color(0x0d4420), emissiveIntensity: 0.05,
    });
    toadBody374 = new Mesh(bodyGeo, bodyMat);
    toadBody374.scale.set(1.0, 0.6, 1.2);
    toadBody374.position.y = 0.18;
    toadGroup374.add(toadBody374);

    // Eyes (glowing green)
    const eyeGeo = new SphereGeometry(0.07, 6, 4);
    const eyeMat = new MeshBasicMaterial({ color: 0x33ff66 });
    ([-0.15, 0.15] as number[]).forEach((ex) => {
      const eye = new Mesh(eyeGeo, eyeMat);
      eye.position.set(ex, 0.36, 0.2);
      toadGroup374!.add(eye);
    });

    // Feet (4 flat cylinders)
    ([[-0.25, -0.18], [0.25, -0.18], [-0.28, 0.12], [0.28, 0.12]] as Array<[number, number]>).forEach(([fx, fz]) => {
      const footGeo = new CylinderGeometry(0.08, 0.1, 0.04, 5);
      const foot = new Mesh(footGeo, padMat);
      foot.position.set(fx, 0.05, fz);
      toadGroup374!.add(foot);
    });

    toadGroup374.position.set(3, 0, -18);
    group.add(toadGroup374);

    // Korrigan spirit dancers ring dance (C394)
    korrGroup394 = new Group();
    const korrMat = new MeshStandardMaterial({ color: 0x050a05, roughness: 0.95 });

    // Central post with carved face
    const korrPost = new Mesh(new CylinderGeometry(0.06, 0.08, 1.2, 6), korrMat);
    korrPost.position.y = 0.6;
    korrGroup394.add(korrPost);

    // Carved face indicator (emissive plane)
    const korrFaceMat = new MeshStandardMaterial({ color: 0x051505, emissive: new Color(0x0d4420), emissiveIntensity: 0.15 });
    const korrFace = new Mesh(new PlaneGeometry(0.1, 0.1), korrFaceMat);
    korrFace.position.set(0, 1.0, 0.065);
    korrGroup394.add(korrFace);

    // Post glow
    const korrPostLight = new PointLight(0x33ff66, 0.08, 3.0);
    korrPostLight.position.y = 1.1;
    korrGroup394.add(korrPostLight);

    // 3 korrigan figures
    for (let ki = 0; ki < 3; ki++) {
      const fig = new Group();
      // Body (short squat cylinder)
      const kfBody = new Mesh(new CylinderGeometry(0.1, 0.14, 0.55, 6), korrMat);
      kfBody.position.y = 0.28;
      fig.add(kfBody);
      // Head
      const kfHead = new Mesh(new SphereGeometry(0.1, 6, 4), korrMat);
      kfHead.position.y = 0.65;
      fig.add(kfHead);
      // Hat (small cone)
      const kfHat = new Mesh(new ConeGeometry(0.07, 0.2, 5), korrMat);
      kfHat.position.y = 0.85;
      fig.add(kfHat);

      korrGroup394.add(fig);
      korrFigures394.push(fig);
    }

    korrGroup394.position.set(-3, 0, -15);
    group.add(korrGroup394);

    // Rotting swamp dock (C422)
    swampDockGroup422 = new Group();
    const dockWoodMat = new MeshStandardMaterial({ color: 0x0a1a10, emissive: 0x040806 });
    const dockPostMat = new MeshStandardMaterial({ color: 0x0a1a10, emissive: 0x040806 });

    // 6 dock planks side by side extending in z
    for (let i = 0; i < 6; i++) {
      const plank = new Mesh(new BoxGeometry(0.7, 0.06, 0.9), dockWoodMat);
      plank.position.set(i * 0.7 - 1.75, 0.2, 0);
      plank.rotation.x = i % 2 === 0 ? 0.05 : -0.03;
      swampDockGroup422.add(plank);
    }

    // 4 support posts at corners and mid-points
    const postPositions: Array<[number, number, number, number]> = [
      [-1.8, -0.4, 0.45, -0.07],
      [-1.8, -0.4, -0.45, 0.09],
      [1.8, -0.4, 0.45, 0.05],
      [0, -0.4, -0.45, -0.08],
    ];
    postPositions.forEach(([px, py, pz, tilt]) => {
      const post = new Mesh(new CylinderGeometry(0.06, 0.08, 1.2, 5), dockPostMat);
      post.position.set(px, py, pz);
      post.rotation.z = tilt;
      swampDockGroup422!.add(post);
    });

    // 2 cross-braces at 45 degrees between posts
    for (let b = 0; b < 2; b++) {
      const brace = new Mesh(new CylinderGeometry(0.04, 0.04, 1.8, 4), dockPostMat);
      brace.position.set(b === 0 ? -0.9 : 0.9, -0.1, 0);
      brace.rotation.z = b === 0 ? Math.PI / 4 : -Math.PI / 4;
      swampDockGroup422.add(brace);
    }

    // 4 algae pools (glowing) at water level
    const algaeMat = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.2, depthWrite: false });
    const algaePositions: Array<[number, number, number]> = [
      [-1.5, 0.01, 0.6],
      [1.5, 0.01, -0.6],
      [0.5, 0.01, 0.5],
      [-0.8, 0.01, -0.4],
    ];
    algaePositions.forEach(([ax, ay, az]) => {
      const algae = new Mesh(new CircleGeometry(0.25, 8), algaeMat.clone());
      algae.rotation.x = -Math.PI / 2;
      algae.position.set(ax, ay, az);
      swampDockGroup422!.add(algae);
      swampDockAlgae422.push(algae);
    });

    // Point light for bioluminescent glow
    swampDockLight422 = new PointLight(0x33ff66, 0.12, 5.0);
    swampDockLight422.position.set(0, 0.5, 0);
    swampDockGroup422.add(swampDockLight422);

    swampDockGroup422.position.set(-6, 0, -12);
    group.add(swampDockGroup422);
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

    // Heather ground cover — 20 clumps of tiny sphere clusters + 8 tall stalks
    const heatherGeoSmall = new SphereGeometry(0.08, 3, 2);
    const heatherGeoTall  = new SphereGeometry(0.12, 3, 2);
    const heatherMat2     = new MeshBasicMaterial({ color: 0x1a2a15 });
    const R = () => Math.random();

    for (let ci = 0; ci < 20; ci++) {
      const cx = (R() - 0.5) * 36;          // x ∈ [-18, 18]
      const cz = -8 - R() * 27;             // z ∈ [-8, -35]
      const cy = -(R() * 0.05);             // y ∈ [0, -0.05]

      // 3 spheres per clump, slightly offset from centre
      for (let si = 0; si < 3; si++) {
        const s = new Mesh(heatherGeoSmall, heatherMat2);
        s.position.set(
          cx + (R() - 0.5) * 0.4,
          cy + R() * 0.08,
          cz + (R() - 0.5) * 0.4
        );
        const scl = 0.7 + R() * 0.6;        // 0.7 – 1.3
        s.scale.setScalar(scl);
        // Every 4th sphere gets a sway phase
        if ((ci * 3 + si) % 4 === 0) {
          s.userData['swayPhase'] = R() * Math.PI * 2;
        }
        group.add(s);
        _heatherMeshes.push(s);
      }
    }

    // 8 taller heather stalks
    for (let ti = 0; ti < 8; ti++) {
      const stalk = new Mesh(heatherGeoTall, heatherMat2);
      stalk.position.set(
        (R() - 0.5) * 36,
        -(R() * 0.05),
        -8 - R() * 27
      );
      const scl = 0.7 + R() * 0.6;
      stalk.scale.set(scl, scl * 1.4, scl);
      if (ti % 4 === 0) {
        stalk.userData['swayPhase'] = R() * Math.PI * 2;
      }
      group.add(stalk);
      _heatherMeshes.push(stalk);
    }

    // Weathered standing stone circle — smaller than cercles_pierres, a moor relic
    {
      const circleGroup = new Group();
      const stoneMat = new MeshStandardMaterial({ color: 0x151f12, roughness: 0.95, metalness: 0.0, flatShading: true });
      const centerX = 10;
      const centerZ = -26;
      const radius = 4;
      const STONE_COUNT = 6;
      const Rnd = () => Math.random();

      for (let i = 0; i < STONE_COUNT; i++) {
        const angle = (i / STONE_COUNT) * Math.PI * 2;
        const w = 0.2 + Rnd() * 0.15;
        const h = 1.4 + Rnd() * 0.5;
        const d = 0.18 + Rnd() * 0.08;
        const stone = new Mesh(new BoxGeometry(w, h, d), stoneMat);
        stone.position.set(
          centerX + Math.cos(angle) * radius,
          h / 2 - 1,
          centerZ + Math.sin(angle) * radius,
        );
        stone.rotation.z = (Rnd() - 0.5) * 0.2;
        stone.rotation.y = Rnd() * 0.3;
        circleGroup.add(stone);
      }

      // Partial lintel spanning stones 0 and 1 (two adjacent stones at top)
      const lintelMat = new MeshStandardMaterial({ color: 0x111a0f, roughness: 0.95, metalness: 0.0, flatShading: true });
      const angle0 = 0;
      const angle1 = (1 / STONE_COUNT) * Math.PI * 2;
      const s0x = centerX + Math.cos(angle0) * radius;
      const s0z = centerZ + Math.sin(angle0) * radius;
      const s1x = centerX + Math.cos(angle1) * radius;
      const s1z = centerZ + Math.sin(angle1) * radius;
      const lintel = new Mesh(new BoxGeometry(4.2, 0.18, 0.2), lintelMat);
      lintel.position.set((s0x + s1x) / 2, 1.8, (s0z + s1z) / 2);
      lintel.rotation.y = Math.atan2(s1x - s0x, s1z - s0z);
      circleGroup.add(lintel);

      // Center flat marker stone
      const markerMat = new MeshStandardMaterial({ color: 0x151f12, roughness: 0.95, metalness: 0.0, flatShading: true });
      const marker = new Mesh(new CylinderGeometry(0.3, 0.35, 0.12, 6), markerMat);
      marker.position.set(centerX, -0.94, centerZ);
      circleGroup.add(marker);

      group.add(circleGroup);
      _moorCircleGroup = circleGroup;

      // Very subtle ambient glow at circle center
      const circleLight = new PointLight(0x33ff66, 0.03, 6);
      circleLight.position.set(centerX, 0.5, centerZ);
      group.add(circleLight);
      _moorCircleLight = circleLight;
    }

    // Ruined watchtower — broken circular tower in the far background
    {
      const towerGroup = new Group();
      const stoneMat = new MeshBasicMaterial({ color: 0x121b12 });
      const stoneMatDs = new MeshBasicMaterial({ color: 0x121b12, side: DoubleSide });

      // Base cylinder
      const base = new Mesh(new CylinderGeometry(1.8, 2.2, 1.2, 8), stoneMat);
      base.position.set(-22, 0.6, -45);
      towerGroup.add(base);

      // Lower wall (open-ended cylinder, DoubleSide)
      const wall = new Mesh(new CylinderGeometry(1.6, 1.8, 5.0, 8, 1, true), stoneMatDs);
      wall.position.set(-22, 3.5, -45);
      towerGroup.add(wall);

      // Broken top rim — 3/4 torus
      const rim = new Mesh(
        new TorusGeometry(1.65, 0.2, 6, 16, Math.PI * 1.5),
        new MeshBasicMaterial({ color: 0x0e1a0e })
      );
      rim.position.set(-22, 6.1, -45);
      towerGroup.add(rim);

      // Interior floor glimpse
      const floor = new Mesh(
        new CircleGeometry(1.4, 8),
        new MeshBasicMaterial({ color: 0x0c140c, transparent: true, opacity: 0.4, side: DoubleSide })
      );
      floor.position.set(-22, 2.0, -45);
      floor.rotation.x = -Math.PI / 2;
      towerGroup.add(floor);

      // Rubble — 5 scattered box pieces around base
      const rubbleSizes: Array<[number, number, number]> = [
        [0.7, 0.3, 0.5],
        [0.5, 0.4, 0.4],
        [0.9, 0.25, 0.6],
        [0.4, 0.35, 0.45],
        [0.6, 0.28, 0.5],
      ];
      const rubbleOffsets: Array<[number, number]> = [
        [2.1, 0.8], [-2.3, -0.6], [1.5, -2.0], [-1.0, 2.2], [2.5, -1.5],
      ];
      const rubbleRotations: number[] = [0.3, 1.1, 2.2, 0.7, 1.8];
      const rubbleMat = new MeshBasicMaterial({ color: 0x121b12 });
      for (let ri = 0; ri < 5; ri++) {
        const [rw, rh, rd] = rubbleSizes[ri];
        const [rx, rz] = rubbleOffsets[ri];
        const rubble = new Mesh(new BoxGeometry(rw, rh, rd), rubbleMat);
        rubble.position.set(-22 + rx, rh / 2 - 0.1, -45 + rz);
        rubble.rotation.y = rubbleRotations[ri];
        towerGroup.add(rubble);
      }

      // Arrow slit — dark plane suggesting interior depth
      const slitMat = new MeshBasicMaterial({ color: 0x060c06, transparent: true, opacity: 0.8, side: DoubleSide });
      const slit = new Mesh(new PlaneGeometry(0.15, 0.6), slitMat);
      slit.position.set(-23.5, 4.2, -44.5);
      towerGroup.add(slit);

      group.add(towerGroup);
      _watchtowerGroup = towerGroup;

      // Faint glow from arrow slit
      const towerLight = new PointLight(0x33ff66, 0.05, 4);
      towerLight.position.set(-23.4, 4.2, -44.6);
      group.add(towerLight);
      _watchtowerLight = towerLight;
    }

    // Crow perched on dolmen capstone (C358)
    {
      crowGroup358 = new Group();
      const crowMat = new MeshStandardMaterial({ color: 0x0a1a0a, roughness: 0.9 });

      // Body
      const bodyGeo = new BoxGeometry(0.18, 0.14, 0.28);
      const body = new Mesh(bodyGeo, crowMat);
      crowGroup358.add(body);

      // Head
      const headGeo = new BoxGeometry(0.12, 0.12, 0.12);
      const head = new Mesh(headGeo, crowMat);
      head.position.set(0, 0.1, 0.12);
      crowGroup358.add(head);

      // Beak
      const beakGeo = new BoxGeometry(0.04, 0.04, 0.1);
      const beak = new Mesh(beakGeo, crowMat);
      beak.position.set(0, 0.09, 0.22);
      crowGroup358.add(beak);

      // Tail
      const tailGeo = new BoxGeometry(0.12, 0.06, 0.18);
      const tail = new Mesh(tailGeo, crowMat);
      tail.position.set(0, 0.0, -0.2);
      tail.rotation.x = 0.3;
      crowGroup358.add(tail);

      // Eye
      const eyeGeo = new SphereGeometry(0.015, 4, 3);
      const eyeMat = new MeshBasicMaterial({ color: 0x33ff66 });
      const eye = new Mesh(eyeGeo, eyeMat);
      eye.position.set(0.045, 0.12, 0.17);
      crowGroup358.add(eye);

      // Wings (folded flat against body by default)
      crowWingMat358 = new MeshStandardMaterial({ color: 0x0a1a0a, roughness: 0.9, emissive: new Color(0x33ff66), emissiveIntensity: 0.0 });
      for (const sx of [-1, 1]) {
        const wingGeo = new BoxGeometry(0.22, 0.04, 0.24);
        const wing = new Mesh(wingGeo, crowWingMat358.clone());
        wing.position.set(sx * 0.18, 0.02, -0.02);
        wing.rotation.z = sx * 0.15;
        wing.userData['side'] = sx;
        crowGroup358.add(wing);
        crowWings358.push(wing);
      }

      // Dolmen capstone at (-2.75, -0.35, -35), capstone top y = -0.10
      // Crow body half-height = 0.07 → group y = -0.03
      crowGroup358.position.set(-2.75, -0.03, -35);
      group.add(crowGroup358);

      crowNextFlap358 = 8 + Math.random() * 4;
    }

    // Ignis fatuus procession — 5 wisps luring travelers across the moor (C386)
    ignisFatuusGroup386 = new Group();
    const wispmMat = new MeshBasicMaterial({ color: 0x1a8833, transparent: true, opacity: 0.8 });

    for (let i = 0; i < 5; i++) {
      const sphere = new Mesh(new SphereGeometry(0.06 - i * 0.008, 6, 4), wispmMat.clone());
      sphere.userData['idx'] = i;
      ignisFatuusGroup386.add(sphere);
      ignisMeshes386.push(sphere);

      const light = new PointLight(0x33ff66, 0.12 - i * 0.015, 2.5);
      ignisFatuusGroup386.add(light);
      ignisLights386.push(light);
    }

    group.add(ignisFatuusGroup386);

    // ── Carved menhir with glowing spiral energy (C417) ──────────────────────
    menhirGroup417 = new Group();

    // Main stone — tapering pillar
    const menhirMainMat = new MeshBasicMaterial({ color: 0x0a1a10 });
    const menhirMain = new Mesh(new CylinderGeometry(0.22, 0.35, 3.5, 6), menhirMainMat);
    menhirMain.position.set(0, 1.75, 0);
    menhirGroup417.add(menhirMain);

    // Base stone
    const menhirBase = new Mesh(new CylinderGeometry(0.38, 0.42, 0.3, 6), new MeshBasicMaterial({ color: 0x0a1a10 }));
    menhirBase.position.set(0, 0.15, 0);
    menhirGroup417.add(menhirBase);

    // Cap rock
    const menhirCap = new Mesh(new SphereGeometry(0.22, 5, 4), new MeshBasicMaterial({ color: 0x0a1a10 }));
    menhirCap.scale.set(1, 0.6, 1);
    menhirCap.position.set(0, 3.62, 0);
    menhirGroup417.add(menhirCap);

    // Spiral carvings — 5 flat disc planes stacked up the stone surface
    const spiralYPositions = [0.8, 1.3, 1.8, 2.3, 2.8];
    spiralYPositions.forEach((yPos, i) => {
      const glyph = new Mesh(
        new PlaneGeometry(0.55, 0.55),
        new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.25 }),
      );
      glyph.position.set(0, yPos, 0.23);
      glyph.rotation.z = i * 0.3;
      menhirGroup417!.add(glyph);
      menhirCarveGlows417.push(glyph);
    });

    // Energy aura — open cylinder
    const menhirAura = new Mesh(
      new CylinderGeometry(0.28, 0.42, 3.5, 8, 1, true),
      new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.04, side: DoubleSide, depthWrite: false }),
    );
    menhirAura.position.set(0, 1.75, 0);
    menhirGroup417.add(menhirAura);

    // Druidic point light
    menhirLight417 = new PointLight(0x33ff66, 0.15, 5.0);
    menhirLight417.position.set(0, 2.5, 0);
    menhirGroup417.add(menhirLight417);

    menhirGroup417.position.set(5, 0, -18);
    group.add(menhirGroup417);
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

    // Aurora borealis — 3 undulating horizontal bands overhead
    const auroraConfig: Array<{ y: number; z: number; color: number }> = [
      { y: 18, z: -30, color: 0x33ff66 },
      { y: 20, z: -28, color: 0x1a5533 },
      { y: 22, z: -26, color: 0x0a2a1a },
    ];
    for (const cfg of auroraConfig) {
      const band = new Mesh(
        new PlaneGeometry(30, 1.2),
        new MeshBasicMaterial({
          color: cfg.color,
          transparent: true,
          opacity: 0.0,
          depthWrite: false,
          side: DoubleSide,
        }),
      );
      band.position.set(0, cfg.y, cfg.z);
      band.rotation.x = -Math.PI * 0.15;
      group.add(band);
      _auroraBands.push(band);
    }

    // Partial temple ruins — collapsed structure in background (C317)
    const templeGroup = new Group();
    const templeStoneMat = new MeshStandardMaterial({ color: 0x141f14, roughness: 0.96, metalness: 0.0, flatShading: true });
    const templeDarkMat  = new MeshStandardMaterial({ color: 0x0c150c, roughness: 0.96, metalness: 0.0, flatShading: true });

    // Base platform
    const platform = new Mesh(new BoxGeometry(14, 0.4, 6), templeStoneMat);
    platform.position.set(0, -0.2, -43);
    templeGroup.add(platform);

    // Standing column 1 — full height
    const col1 = new Mesh(new CylinderGeometry(0.35, 0.4, 5.5, 7), templeStoneMat);
    col1.position.set(-5, 2.75, -43);
    templeGroup.add(col1);

    // Standing column 2 — shorter (damaged)
    const col2 = new Mesh(new CylinderGeometry(0.35, 0.4, 4.2, 7), templeStoneMat);
    col2.position.set(-1.5, 2.1, -44);
    templeGroup.add(col2);

    // Fallen column — lying on ground
    const colFallen = new Mesh(new CylinderGeometry(0.3, 0.35, 5.0, 7), templeStoneMat);
    colFallen.position.set(3, 0.15, -43.5);
    colFallen.rotation.z = Math.PI / 2;
    colFallen.rotation.y = 0.3;
    templeGroup.add(colFallen);

    // Partial lintel — spans col1 & col2
    const lintel = new Mesh(new BoxGeometry(5, 0.45, 0.4), templeDarkMat);
    lintel.position.set(-3.5, 5.5, -43);
    templeGroup.add(lintel);

    // Rubble blocks — scattered near fallen column
    const rubbleData: Array<[number, number, number, number, number, number, number]> = [
      [0.5, 0.3, 0.4,  2.0, -0.15, -42.5,  0.3],
      [0.8, 0.5, 0.6,  4.5, -0.25, -43.8,  1.1],
      [0.7, 0.4, 0.5,  1.5, -0.20, -44.5, -0.5],
      [0.9, 0.6, 0.7,  5.5, -0.30, -42.0,  0.8],
    ];
    for (const [rw, rh, rd, rx, ry, rz, ryRot] of rubbleData) {
      const rubble = new Mesh(new BoxGeometry(rw, rh, rd), templeStoneMat);
      rubble.position.set(rx, ry, rz);
      rubble.rotation.y = ryRot;
      templeGroup.add(rubble);
    }

    // Glow from cracks — constant dim point light
    const crackGlow = new PointLight(0x33ff66, 0.08, 8);
    crackGlow.position.set(0, 0.5, -43);
    templeGroup.add(crackGlow);

    group.add(templeGroup);
    _templeGroup = templeGroup;

    // Monumental stone gate arch at z=-15 (valley entrance)
    const gateGroup = new Group();
    const gateStoneMat = new MeshStandardMaterial({ color: 0x141f14, roughness: 0.97, metalness: 0.0, flatShading: true });
    const gateArchMat  = new MeshBasicMaterial({ color: 0x0c1a0c });

    // Left pillar
    const leftPillar = new Mesh(new BoxGeometry(1.2, 8.0, 1.2), gateStoneMat);
    leftPillar.position.set(-5, 4.0, -15);
    gateGroup.add(leftPillar);

    // Right pillar
    const rightPillar = new Mesh(new BoxGeometry(1.2, 8.0, 1.2), gateStoneMat);
    rightPillar.position.set(5, 4.0, -15);
    gateGroup.add(rightPillar);

    // Arch keystone / flat lintel
    const lintelGate = new Mesh(new BoxGeometry(3.5, 1.5, 1.0), gateStoneMat);
    lintelGate.position.set(0, 8.5, -15);
    gateGroup.add(lintelGate);

    // Half-torus arch curve (opens upward)
    const archTorus = new Mesh(new TorusGeometry(2.0, 0.2, 6, 12, Math.PI), gateArchMat);
    archTorus.position.set(0, 8.0, -15);
    archTorus.rotation.z = 0;
    gateGroup.add(archTorus);

    // Corner caps on top of each pillar
    const capGeo = new CylinderGeometry(0.6, 0.8, 0.5, 6);
    const leftCap = new Mesh(capGeo, gateStoneMat);
    leftCap.position.set(-5, 8.25, -15);
    gateGroup.add(leftCap);
    const rightCap = new Mesh(capGeo, gateStoneMat);
    rightCap.position.set(5, 8.25, -15);
    gateGroup.add(rightCap);

    // Rune carving glow plane centered on lintel front face
    const runeGateMat = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.15, side: DoubleSide });
    const runeGatePlane = new Mesh(new PlaneGeometry(2.0, 0.6), runeGateMat);
    runeGatePlane.position.set(0, 8.5, -14.5);
    gateGroup.add(runeGatePlane);
    _gateRunePlane = runeGatePlane;

    // Ambient gate point light
    const gateLight = new PointLight(0x33ff66, 0.12, 12);
    gateLight.position.set(0, 7.0, -14);
    gateGroup.add(gateLight);
    _gateLight = gateLight;

    group.add(gateGroup);
    _gateGroup = gateGroup;

    // Vertical spirit pillar beams — rising from prominent stelae tops (C351)
    const spiritBeamPositions: Array<[number, number, number]> = [
      [-4, 2.0, -28],
      [ 3, 2.5, -30],
      [-1, 3.0, -32],
    ];
    for (const [bx, by, bz] of spiritBeamPositions) {
      const beamGeo = new CylinderGeometry(0.0, 0.25, 12, 6, 1, true);
      const beamMat = new MeshBasicMaterial({
        color: 0x0a3a1a,
        transparent: true,
        opacity: 0.0,
        side: DoubleSide,
        depthWrite: false,
      });
      const beam = new Mesh(beamGeo, beamMat);
      beam.position.set(bx, by + 6, bz); // centre of 12-unit column
      group.add(beam);
      _spiritBeams.push(beam);

      const pLight = new PointLight(0x33ff66, 0.0, 8);
      pLight.position.set(bx, by, bz);
      group.add(pLight);
      _spiritLights.push(pLight);
    }

    // Ancient tomb entrance — dolmen-style doorway with dark interior (C378)
    tombGroup378 = new Group();
    const stoneMat378 = new MeshStandardMaterial({ color: 0x1e2e1e, roughness: 0.95, metalness: 0.0 });

    // Left upright
    const leftStone378 = new Mesh(new BoxGeometry(0.5, 2.8, 0.4), stoneMat378);
    leftStone378.position.set(-0.8, 1.4, 0);
    tombGroup378.add(leftStone378);

    // Right upright
    const rightStone378 = new Mesh(new BoxGeometry(0.5, 2.8, 0.4), stoneMat378);
    rightStone378.position.set(0.8, 1.4, 0);
    tombGroup378.add(rightStone378);

    // Capstone
    const capStone378 = new Mesh(new BoxGeometry(2.4, 0.45, 0.6), stoneMat378);
    capStone378.position.set(0, 2.95, 0);
    tombGroup378.add(capStone378);

    // Dark interior plane
    const interiorGeo378 = new PlaneGeometry(1.1, 2.5);
    const interiorMat378 = new MeshBasicMaterial({ color: 0x010501, transparent: true, opacity: 0.95, depthWrite: false });
    const interior378 = new Mesh(interiorGeo378, interiorMat378);
    interior378.position.set(0, 1.25, 0.01);
    tombGroup378.add(interior378);

    // Inner glow light
    tombGlowLight378 = new PointLight(0x33ff66, 0.0, 4.0);
    tombGlowLight378.position.set(0, 1.0, -1.5);
    tombGroup378.add(tombGlowLight378);

    tombGroup378.position.set(6, 0, -35);
    tombGroup378.rotation.y = -0.4;
    group.add(tombGroup378);
    tombNextFlare378 = 10.0 + Math.random() * 8.0;

    // Stone labyrinth ruins (C403)
    labyrinthGroup403 = new Group();
    const wallMat403 = new MeshLambertMaterial({ color: 0x0a1a10, emissive: 0x050f08 });
    const mossMat403 = new MeshBasicMaterial({ color: 0x0d2a14, transparent: true, opacity: 0.5 });

    // Wall segments: [geometry_args, position_x, position_y, position_z]
    const wallDefs403: Array<[number, number, number, number, number, number]> = [
      // w,    h,    d,    x,    y,     z
      [3.0, 1.2, 0.3, 4.0, 0.6, -20.0],   // Wall 1: east-west, length 3
      [0.3, 1.2, 2.5, 5.5, 0.6, -21.25],  // Wall 2: north-south, length 2.5
      [2.0, 1.2, 0.3, 2.0, 0.6, -23.0],   // Wall 3: east-west, length 2
      [0.3, 1.2, 1.5, 3.0, 0.6, -22.75],  // Wall 4: north-south, length 1.5
      [1.0, 1.2, 0.3, 4.5, 0.6, -24.0],   // Wall 5: east-west cap, length 1
    ];

    for (const [ww, wh, wd, wx, wy, wz] of wallDefs403) {
      // Wall body
      const wallMesh = new Mesh(new BoxGeometry(ww, wh, wd), wallMat403);
      wallMesh.position.set(wx, wy, wz);
      labyrinthGroup403.add(wallMesh);
      // Moss overlay on top
      const mossMesh = new Mesh(new BoxGeometry(ww, 0.05, wd), mossMat403);
      mossMesh.position.set(wx, wy + 0.65, wz);
      labyrinthGroup403.add(mossMesh);
    }

    // Faint ancient green shimmer
    const labLight403 = new PointLight(0x33ff66, 0.05, 6.0);
    labLight403.position.set(4, 1.5, -22);
    labyrinthGroup403.add(labLight403);

    group.add(labyrinthGroup403);

    // Spectral ghost apparition (C425)
    ghostGroup425 = new Group();

    const ghostBodyMat = new MeshBasicMaterial({
      color: 0x0d2a14,
      transparent: true,
      opacity: 0.0,
      depthWrite: false,
      side: DoubleSide,
    });
    ghostBody425 = new Mesh(new CylinderGeometry(0.15, 0.1, 0.9, 7), ghostBodyMat);
    ghostBody425.position.set(0, 0.85, 0);
    ghostGroup425.add(ghostBody425);

    const ghostHeadMat = ghostBodyMat.clone();
    ghostHead425 = new Mesh(new SphereGeometry(0.18, 6, 5), ghostHeadMat);
    ghostHead425.position.set(0, 1.55, 0);
    ghostGroup425.add(ghostHead425);

    const ghostTrailMat = ghostBodyMat.clone();
    const ghostTrail425 = new Mesh(new ConeGeometry(0.12, 0.5, 6, 1, true), ghostTrailMat);
    ghostTrail425.position.set(0, 0.3, 0);
    ghostTrail425.rotation.x = Math.PI;
    ghostGroup425.add(ghostTrail425);

    ghostLight425 = new PointLight(0x33ff66, 0.0, 4.0);
    ghostLight425.position.set(0, 1.2, 0);
    ghostGroup425.add(ghostLight425);

    ghostGroup425.position.set(-3, 0, -18);
    group.add(ghostGroup425);
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

    // Frozen lake surface
    const lakeGeo = new PlaneGeometry(18, 12);
    const lakeMat = new MeshBasicMaterial({
      color: 0x0a1a18,
      transparent: true,
      opacity: 0.55,
      depthWrite: false,
      side: DoubleSide,
    });
    const lakeMesh = new Mesh(lakeGeo, lakeMat);
    lakeMesh.rotation.x = -Math.PI / 2;
    lakeMesh.position.set(0, -0.02, -22);
    group.add(lakeMesh);
    _lakeMesh = lakeMesh;

    // Ice crack lines
    const crackMat = new MeshBasicMaterial({ color: 0x1a2e2a });
    const crackDefs: [number, number, number, number, number, number, number][] = [
      [0.03, 0.01, 4.2, -2, 0.01, -20, 0.3],
      [0.03, 0.01, 3.8,  3, 0.01, -23, -0.2],
      [0.03, 0.01, 2.9, -5, 0.01, -24, 0.7],
    ];
    for (const [w, h, d, cx, cy, cz, ry] of crackDefs) {
      const crack = new Mesh(new BoxGeometry(w, h, d), crackMat);
      crack.position.set(cx, cy, cz);
      crack.rotation.y = ry;
      group.add(crack);
    }

    // Subtle shimmer point light
    const lakeLight = new PointLight(0x33ff66, 0.05, 12);
    lakeLight.position.set(0, 0.5, -22);
    group.add(lakeLight);
    _lakeLight = lakeLight;

    // Frozen waterfall on left mountain face (C330)
    const waterfallGroup = new Group();
    // Main ice sheet
    const iceSheetMat = new MeshBasicMaterial({
      color: 0x0a1e1a,
      transparent: true,
      opacity: 0.45,
      side: DoubleSide,
    });
    const iceSheet = new Mesh(new PlaneGeometry(3.5, 7.0), iceSheetMat);
    iceSheet.position.set(-8, 3.5, -43);
    iceSheet.rotation.y = 0.4;
    iceSheet.rotation.x = -0.1;
    waterfallGroup.add(iceSheet);
    // Ice ridges — 4 vertical strips
    const ridgeMat = new MeshBasicMaterial({ color: 0x0c2218 });
    const ridgeXOffsets = [-8.8, -8.3, -7.7, -7.2];
    for (const rx of ridgeXOffsets) {
      const ridge = new Mesh(new BoxGeometry(0.15, 7.0, 0.08), ridgeMat);
      ridge.position.set(rx, 3.5, -43);
      waterfallGroup.add(ridge);
    }
    // Frozen splash base
    const splashMat = new MeshBasicMaterial({
      color: 0x0a1e1a,
      transparent: true,
      opacity: 0.55,
    });
    const splash = new Mesh(new CylinderGeometry(1.5, 2.0, 0.3, 8), splashMat);
    splash.position.set(-8, -0.15, -43);
    waterfallGroup.add(splash);
    // Icicles — 6 hanging from bottom of ice sheet
    const icicleMat = new MeshBasicMaterial({ color: 0x0d2a22 });
    const icicleXPositions = [-9, -8.6, -8.2, -7.8, -7.4, -7];
    for (const ix of icicleXPositions) {
      const icicleLen = 0.4 + Math.random() * 0.3;
      const icicle = new Mesh(new ConeGeometry(0.05, icicleLen, 4), icicleMat);
      icicle.position.set(ix, -0.05, -43);
      icicle.rotation.x = Math.PI;
      waterfallGroup.add(icicle);
    }
    group.add(waterfallGroup);
    _waterfallGroup = waterfallGroup;
    // Glow — very subtle green shimmer
    const waterfallLight = new PointLight(0x33ff66, 0.06, 8);
    waterfallLight.position.set(-8, 1.5, -42.5);
    group.add(waterfallLight);
    _waterfallLight = waterfallLight;

    // Mountain goat silhouette grazing on a ledge (C346)
    const goatMat = new MeshLambertMaterial({ color: 0x0c1a10 });
    const goatGroup = new Group();

    // Body
    const bodyMesh = new Mesh(new BoxGeometry(0.35, 0.22, 0.55), goatMat);
    bodyMesh.position.set(-12, 6.5, -44);
    goatGroup.add(bodyMesh);

    // Neck
    const neckMesh = new Mesh(new BoxGeometry(0.1, 0.15, 0.1), goatMat);
    neckMesh.position.set(-12, 6.64, -43.86);
    goatGroup.add(neckMesh);

    // Head
    const headMesh = new Mesh(new BoxGeometry(0.14, 0.16, 0.18), goatMat);
    headMesh.position.set(-12, 6.72, -43.72);
    goatGroup.add(headMesh);

    // Horn L
    const hornL = new Mesh(new CylinderGeometry(0.01, 0.02, 0.18, 3), goatMat);
    hornL.position.set(-12.05, 6.88, -43.68);
    hornL.rotation.x = 0.4;
    goatGroup.add(hornL);

    // Horn R
    const hornR = new Mesh(new CylinderGeometry(0.01, 0.02, 0.18, 3), goatMat);
    hornR.position.set(-11.95, 6.88, -43.68);
    hornR.rotation.x = 0.4;
    goatGroup.add(hornR);

    // 4 legs at body corners, extending down
    const legPositions: Array<[number, number, number]> = [
      [-12.12, 6.265, -43.78],
      [-11.88, 6.265, -43.78],
      [-12.12, 6.265, -44.22],
      [-11.88, 6.265, -44.22],
    ];
    legPositions.forEach(([lx, ly, lz]) => {
      const leg = new Mesh(new BoxGeometry(0.05, 0.25, 0.05), goatMat);
      leg.position.set(lx, ly, lz);
      goatGroup.add(leg);
    });

    // Tail
    const tailMesh = new Mesh(new BoxGeometry(0.04, 0.08, 0.02), goatMat);
    tailMesh.position.set(-12, 6.52, -44.28);
    tailMesh.rotation.x = -0.5;
    goatGroup.add(tailMesh);

    group.add(goatGroup);
    _goatGroup = goatGroup;
    _goatHead = headMesh;
    _goatTail = tailMesh;
    _goatBody = bodyMesh;

    // Ice crystal formations on rocky ledges (C366)
    const crystalMat366 = new MeshStandardMaterial({
      color: 0x0a2a1a, emissive: new Color(0x0d4420), emissiveIntensity: 0.10,
      roughness: 0.2, metalness: 0.4, transparent: true, opacity: 0.85,
    });

    const clusterPositions = [
      new Vector3(-4, 0.5, -24),
      new Vector3(3, 1.0, -28),
      new Vector3(-1, 0.8, -32),
    ];

    clusterPositions.forEach((clusterPos, ci) => {
      const clusterGroup = new Group();
      const count = 4 + ci; // 4, 5, 6 crystals per cluster
      for (let i = 0; i < count; i++) {
        const h = 0.4 + Math.random() * 0.6;
        const geo = new ConeGeometry(0.04 + Math.random() * 0.03, h, 4);
        const mat = crystalMat366.clone();
        mat.userData['phase'] = Math.random() * Math.PI * 2;
        const mesh = new Mesh(geo, mat);
        mesh.position.set(
          (Math.random() - 0.5) * 0.4,
          h / 2,
          (Math.random() - 0.5) * 0.4,
        );
        mesh.rotation.set(
          (Math.random() - 0.5) * 0.3,
          Math.random() * Math.PI,
          (Math.random() - 0.5) * 0.2,
        );
        clusterGroup.add(mesh);
      }

      const light366 = new PointLight(0x33ff66, 0.08, 2.5);
      light366.position.set(0, 0.3, 0);
      clusterGroup.add(light366);
      crystalLights366.push(light366);

      clusterGroup.position.copy(clusterPos);
      group.add(clusterGroup);
      crystalGroups366.push(clusterGroup);
    });

    // Hermit's mountain cave entrance (C398)
    caveGroup398 = new Group();
    const rockMat398 = new MeshStandardMaterial({ color: 0x1a2a1e, roughness: 0.95 });

    // Cave mouth arch — 3 rough stone blocks forming an arch
    const leftPillar = new Mesh(new BoxGeometry(0.5, 1.8, 0.4), rockMat398);
    leftPillar.position.set(-0.65, 0.9, 0);
    caveGroup398.add(leftPillar);

    const rightPillar = new Mesh(new BoxGeometry(0.5, 1.8, 0.4), rockMat398);
    rightPillar.position.set(0.65, 0.9, 0);
    caveGroup398.add(rightPillar);

    const archTop = new Mesh(new BoxGeometry(1.6, 0.55, 0.45), rockMat398);
    archTop.position.set(0, 1.93, 0);
    caveGroup398.add(archTop);

    // Cave interior darkness
    const interiorMat398 = new MeshBasicMaterial({ color: 0x010501, transparent: true, opacity: 0.96, depthWrite: false });
    const interior398 = new Mesh(new PlaneGeometry(0.95, 1.75), interiorMat398);
    interior398.position.set(0, 0.88, 0.01);
    caveGroup398.add(interior398);

    // Inner glow
    caveGlowLight398 = new PointLight(0x33ff66, 0.08, 4.0);
    caveGlowLight398.position.set(0, 0.8, -1.5);
    caveGroup398.add(caveGlowLight398);

    // Icicles hanging above entrance
    const icicleMat398 = new MeshStandardMaterial({ color: 0x0a2a1a, roughness: 0.2, metalness: 0.3, emissive: new Color(0x0d3310), emissiveIntensity: 0.08, transparent: true, opacity: 0.7 });
    for (let i = 0; i < 5; i++) {
      const h398 = 0.15 + Math.random() * 0.2;
      const icicle398 = new Mesh(new ConeGeometry(0.025, h398, 4), icicleMat398.clone());
      icicle398.rotation.x = Math.PI; // point down
      icicle398.position.set(-0.35 + i * 0.18, 1.85, 0.04);
      caveGroup398.add(icicle398);
    }

    caveGroup398.position.set(-5, 0, -28);
    group.add(caveGroup398);
    caveNextShadow398 = 10.0 + Math.random() * 5.0;

    // ── Soaring eagle (C412) ─────────────────────────────────────────────────
    const eagle412Mat = new MeshLambertMaterial({ color: 0x0a2a14, flatShading: true });
    const eagle412WingMat = new MeshLambertMaterial({ color: 0x0d2a14, flatShading: true });
    eagleGroup412 = new Group();

    // Body — elongated torso
    const eagleBody412 = new Mesh(new BoxGeometry(0.35, 0.12, 0.55), eagle412Mat);
    eagleGroup412.add(eagleBody412);

    // Head
    const eagleHead412 = new Mesh(new SphereGeometry(0.1, 4, 3), eagle412Mat);
    eagleHead412.position.set(0, 0.05, 0.28);
    eagleGroup412.add(eagleHead412);

    // Tail — slightly tilted
    const eagleTail412 = new Mesh(new BoxGeometry(0.18, 0.05, 0.22), eagle412Mat);
    eagleTail412.position.set(0, -0.02, -0.28);
    eagleTail412.rotation.x = 0.12;
    eagleTail412.scale.x = 0.7;
    eagleGroup412.add(eagleTail412);

    // Left wing
    const wingL412 = new Mesh(new BoxGeometry(0.9, 0.04, 0.3), eagle412WingMat);
    wingL412.position.set(-0.62, 0, 0.05);
    eagleGroup412.add(wingL412);
    eagleWingL412 = wingL412;

    // Right wing
    const wingR412 = new Mesh(new BoxGeometry(0.9, 0.04, 0.3), eagle412WingMat);
    wingR412.position.set(0.62, 0, 0.05);
    eagleGroup412.add(wingR412);
    eagleWingR412 = wingR412;

    // Wing tip feathers — left (fan of 3)
    const featherOffsets: Array<[number, number]> = [[-0.04, 0], [0, 0.06], [0.04, -0.06]];
    featherOffsets.forEach(([dz, dx]) => {
      const lf = new Mesh(new BoxGeometry(0.12, 0.03, 0.18), eagle412WingMat);
      lf.position.set(-1.12 + dx, 0, 0.05 + dz);
      lf.rotation.z = 0.08;
      eagleGroup412!.add(lf);
    });

    // Wing tip feathers — right (mirrored)
    featherOffsets.forEach(([dz, dx]) => {
      const rf = new Mesh(new BoxGeometry(0.12, 0.03, 0.18), eagle412WingMat);
      rf.position.set(1.12 - dx, 0, 0.05 + dz);
      rf.rotation.z = -0.08;
      eagleGroup412!.add(rf);
    });

    eagleGroup412.position.set(4, 11, -15);
    group.add(eagleGroup412);
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

    // Ritual altar fire — 12 rising green flame particles above altar center (C306)
    const flameMat = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 1.0 });
    for (let i = 0; i < 12; i++) {
      const particle = new Mesh(new SphereGeometry(0.06, 4, 3), flameMat.clone());
      particle.userData = {
        baseX: (Math.random() - 0.5) * 0.4,
        baseZ: -15 + (Math.random() - 0.5) * 0.4,
        riseSpeed: 0.8 + Math.random() * 0.8,
        phase: Math.random() * Math.PI * 2,
        maxHeight: 0.8 + Math.random() * 0.6,
      };
      group.add(particle);
      _altarFireMeshes.push(particle);
    }
    // Altar fire point light
    const altarFireLight = new PointLight(0x33ff66, 0.6, 5);
    altarFireLight.position.set(0, 0.8, -15);
    group.add(altarFireLight);
    _altarFireLight = altarFireLight;

    // Spectral dancing figures — 5 ghostly silhouettes orbiting altar at radius 5 (C327)
    const dancerMat = new MeshBasicMaterial({ color: 0x0a2a1a, transparent: true, opacity: 0.35 });
    for (let fi = 0; fi < 5; fi++) {
      const figureGroup = new Group();
      // Torso
      const torso = new Mesh(new CylinderGeometry(0.08, 0.14, 0.9, 5), dancerMat);
      torso.position.set(0, 0, 0);
      figureGroup.add(torso);
      // Head
      const head = new Mesh(new SphereGeometry(0.10, 5, 4), dancerMat);
      head.position.set(0, 0.55, 0);
      figureGroup.add(head);
      // Arms
      const armsGroup = new Group();
      const arms = new Mesh(new BoxGeometry(0.5, 0.04, 0.06), dancerMat);
      armsGroup.add(arms);
      armsGroup.position.set(0, 0.1, 0);
      figureGroup.add(armsGroup);
      // Place figure at initial orbit position
      const baseAngle = (fi / 5) * Math.PI * 2;
      figureGroup.position.set(
        Math.cos(baseAngle) * 5,
        0.5,
        -15 + Math.sin(baseAngle) * 5,
      );
      group.add(figureGroup);
      _dancerGroups.push(figureGroup);
      _dancerArmGroups.push(armsGroup);
    }

    // Circling raven flock — 7 birds soaring overhead in a loose gyre (C342)
    const RAVEN_COLOR = 0x080e08;
    const ravenBodyMat = new MeshBasicMaterial({ color: RAVEN_COLOR });
    const ravenWingMat = new MeshBasicMaterial({ color: RAVEN_COLOR });
    const ravenBodyGeo = new BoxGeometry(0.06, 0.02, 0.25);
    const ravenWingGeo = new BoxGeometry(0.55, 0.02, 0.12);
    const RAVEN_COUNT = 7;
    const ravenParams = [
      { radius: 7.0, orbitSpeed: -0.35, flapSpeed: 2.2, flapAmp: 0.28, yOffset:  1.5 },
      { radius: 5.5, orbitSpeed: -0.42, flapSpeed: 1.9, flapAmp: 0.32, yOffset: -0.8 },
      { radius: 8.5, orbitSpeed: -0.31, flapSpeed: 2.8, flapAmp: 0.21, yOffset:  0.4 },
      { radius: 6.2, orbitSpeed: -0.47, flapSpeed: 2.5, flapAmp: 0.35, yOffset: -1.2 },
      { radius: 9.0, orbitSpeed: -0.38, flapSpeed: 2.0, flapAmp: 0.25, yOffset:  2.0 },
      { radius: 5.0, orbitSpeed: -0.44, flapSpeed: 3.0, flapAmp: 0.20, yOffset: -0.3 },
      { radius: 7.8, orbitSpeed: -0.33, flapSpeed: 2.3, flapAmp: 0.30, yOffset:  1.0 },
    ];
    for (let ri = 0; ri < RAVEN_COUNT; ri++) {
      const phase = (ri / RAVEN_COUNT) * Math.PI * 2;
      const p = ravenParams[ri];
      const ravenGroup = new Group();
      const body = new Mesh(ravenBodyGeo, ravenBodyMat);
      ravenGroup.add(body);
      const wings = new Mesh(ravenWingGeo, ravenWingMat);
      ravenGroup.add(wings);
      ravenGroup.position.set(
        p.radius * Math.cos(phase),
        12 + p.yOffset,
        -15 + p.radius * Math.sin(phase),
      );
      ravenGroup.userData = {
        radius: p.radius,
        orbitSpeed: p.orbitSpeed,
        phase,
        flapSpeed: p.flapSpeed,
        flapAmp: p.flapAmp,
        yOffset: p.yOffset,
      };
      group.add(ravenGroup);
      _ravenGroups.push(ravenGroup);
      _ravenWings.push(wings);
    }

    // Moonbeam shaft descending onto central altar (C362)
    const beamGeo362 = new CylinderGeometry(0.15, 0.8, 20, 8, 1, true);
    const beamMat362 = new MeshBasicMaterial({
      color: 0x0a2a0a, transparent: true, opacity: 0.08,
      side: DoubleSide, depthWrite: false,
    });
    moonbeamMesh362 = new Mesh(beamGeo362, beamMat362);
    moonbeamMesh362.position.set(0, 7.38, -15);
    group.add(moonbeamMesh362);

    moonbeamLight362 = new PointLight(0x33ff66, 0.12, 5.0);
    moonbeamLight362.position.set(0, -0.12, -15);
    group.add(moonbeamLight362);

    // Cloaked druid silhouette figures at stone circle (C390)
    druidGroup390 = new Group();
    const figMat = new MeshStandardMaterial({ color: 0x050d05, roughness: 0.95 });
    const armMat = new MeshStandardMaterial({
      color: 0x050d05, roughness: 0.95,
      emissive: new Color(0x0d4420), emissiveIntensity: 0.08,
    });

    const DRUID_CIRCLE_R = 3.0;
    const ALTAR_X = 0;
    const ALTAR_Z = -15;

    for (let i = 0; i < 5; i++) {
      const angle = (i / 5) * Math.PI * 2 + Math.PI / 10;
      const fx = ALTAR_X + Math.cos(angle) * DRUID_CIRCLE_R;
      const fz = ALTAR_Z + Math.sin(angle) * DRUID_CIRCLE_R;

      const figGroup = new Group();

      // Cloak/body — tapered cylinder silhouette
      const body = new Mesh(new CylinderGeometry(0.14, 0.22, 1.6, 6), figMat);
      body.position.y = 0.8;
      figGroup.add(body);

      // Hood/head — small sphere
      const hood = new Mesh(new SphereGeometry(0.15, 6, 5), figMat);
      hood.scale.set(1, 1.1, 1);
      hood.position.y = 1.7;
      figGroup.add(hood);

      // Aura light
      const aura = new PointLight(0x33ff66, 0.04, 1.5);
      aura.position.y = 1.0;
      figGroup.add(aura);

      // Figure i===2 gets raised arms (the ritualist)
      if (i === 2) {
        druidArmLeft390 = new Mesh(new BoxGeometry(0.08, 0.55, 0.08), armMat);
        druidArmLeft390.position.set(-0.22, 1.3, 0);
        druidArmLeft390.rotation.z = -0.8;
        figGroup.add(druidArmLeft390);

        druidArmRight390 = new Mesh(new BoxGeometry(0.08, 0.55, 0.08), armMat);
        druidArmRight390.position.set(0.22, 1.3, 0);
        druidArmRight390.rotation.z = 0.8;
        figGroup.add(druidArmRight390);
      }

      figGroup.position.set(fx, 0, fz);
      figGroup.rotation.y = Math.atan2(-Math.cos(angle), -Math.sin(angle));
      figGroup.userData['bobPhase'] = i * 0.8;
      druidGroup390.add(figGroup);
    }

    group.add(druidGroup390);
  }

  // Central altar ritual fire — cercles_pierres (C407)
  if (biome === 'cercles_pierres') {
    altarFireGroup407 = new Group();

    // Flat stone altar
    const altarStoneMesh = new Mesh(
      new BoxGeometry(1.2, 0.2, 0.8),
      new MeshLambertMaterial({ color: 0x0a1a10 }),
    );
    altarStoneMesh.position.set(0, 0.1, -15);
    altarFireGroup407.add(altarStoneMesh);

    // Fire base log
    const logMesh = new Mesh(
      new CylinderGeometry(0.15, 0.2, 0.3, 6),
      new MeshLambertMaterial({ color: 0x0a1a0a }),
    );
    logMesh.position.set(0, 0.3, -15);
    altarFireGroup407.add(logMesh);

    // Main fire cone
    const fireCone = new Mesh(
      new ConeGeometry(0.25, 1.4, 8, 1, true),
      new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.7, side: DoubleSide }),
    );
    fireCone.position.set(0, 0.95, -15);
    altarFireGroup407.add(fireCone);
    altarFireCone407 = fireCone;

    // Inner flame
    const innerFlame = new Mesh(
      new ConeGeometry(0.12, 1.0, 6, 1, true),
      new MeshBasicMaterial({ color: 0x1aff55, transparent: true, opacity: 0.9, side: DoubleSide }),
    );
    innerFlame.position.set(0, 1.0, -15);
    altarFireGroup407.add(innerFlame);

    // Fire point light
    const fireLight = new PointLight(0x33ff66, 0.5, 8.0);
    fireLight.position.set(0, 1.5, -15);
    altarFireGroup407.add(fireLight);
    altarFireLight407 = fireLight;

    // 12 ember particles
    for (let i = 0; i < 12; i++) {
      const ember = new Mesh(
        new SphereGeometry(0.03, 3, 2),
        new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 1.0 }),
      );
      ember.position.set(0, 0.3, -15);
      altarFireGroup407.add(ember);
      altarEmbers407.push(ember);
      altarEmberVel407.push({
        vx: (Math.random() - 0.5) * 0.6,
        vy: Math.random() * 1.2 + 0.4,
        life: Math.random() * 1.5,
        maxLife: Math.random() * 1.5 + 0.8,
      });
    }

    group.add(altarFireGroup407);

    // ── Moonrise arc (C433) ───────────────────────────────────────────────
    stoneMoonGroup433 = new Group();

    // Moon sphere — dark green, large, distant
    const moonSphere433 = new Mesh(
      new SphereGeometry(1.8, 10, 8),
      new MeshBasicMaterial({ color: 0x0d2a14, transparent: true, opacity: 0.8 }),
    );
    stoneMoonMesh433 = moonSphere433;
    stoneMoonGroup433.add(moonSphere433);

    // Moon glow halo — translucent green shell
    const moonHalo433 = new Mesh(
      new SphereGeometry(2.2, 8, 6),
      new MeshBasicMaterial({
        color: 0x33ff66, transparent: true, opacity: 0.06,
        side: DoubleSide, depthWrite: false,
      }),
    );
    stoneMoonGroup433.add(moonHalo433);

    // Point light for dynamic stone illumination
    const moonLight433 = new PointLight(0x33ff66, 0.3, 25.0);
    stoneMoonLight433 = moonLight433;
    stoneMoonGroup433.add(moonLight433);

    // Start below horizon to the left (group-local coords)
    stoneMoonGroup433.position.set(-18, -2, -25);
    group.add(stoneMoonGroup433);
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

    // ── Stone well (C303) ────────────────────────────────────────────────────
    const wellGroup = new Group();

    // Base ring
    const wellBaseMat = new MeshStandardMaterial({ color: 0x1a2215, roughness: 0.95, metalness: 0.0, flatShading: true });
    const wellBase = new Mesh(new CylinderGeometry(0.9, 1.0, 0.25, 12), wellBaseMat);
    wellBase.position.set(8, 0.12, -14);
    wellGroup.add(wellBase);

    // Wall cylinder (open-ended)
    const wellWallMat = new MeshStandardMaterial({ color: 0x1a2215, roughness: 0.95, metalness: 0.0, flatShading: true, side: DoubleSide });
    const wellWall = new Mesh(new CylinderGeometry(0.75, 0.8, 0.9, 12, 1, true), wellWallMat);
    wellWall.position.set(8, 0.7, -14);
    wellGroup.add(wellWall);

    // Cap ring
    const wellCapMat = new MeshStandardMaterial({ color: 0x121a0e, roughness: 0.95, metalness: 0.0, flatShading: true });
    const wellCap = new Mesh(new CylinderGeometry(0.85, 0.85, 0.08, 12), wellCapMat);
    wellCap.position.set(8, 1.2, -14);
    wellGroup.add(wellCap);

    // Left post
    const wellPostMat = new MeshStandardMaterial({ color: 0x0c1008, roughness: 0.98, metalness: 0.0, flatShading: true });
    const wellPostL = new Mesh(new CylinderGeometry(0.05, 0.05, 1.4, 5), wellPostMat);
    wellPostL.position.set(7.6, 1.6, -14);
    wellGroup.add(wellPostL);

    // Right post
    const wellPostR = new Mesh(new CylinderGeometry(0.05, 0.05, 1.4, 5), wellPostMat);
    wellPostR.position.set(8.4, 1.6, -14);
    wellGroup.add(wellPostR);

    // Crossbeam (horizontal)
    const wellBeam = new Mesh(new CylinderGeometry(0.04, 0.04, 0.9, 5), wellPostMat);
    wellBeam.rotation.z = Math.PI / 2;
    wellBeam.position.set(8, 2.3, -14);
    wellGroup.add(wellBeam);

    // Rope
    const wellRopeMat = new MeshStandardMaterial({ color: 0x0a0e0a, roughness: 0.98, metalness: 0.0, flatShading: true });
    const wellRope = new Mesh(new CylinderGeometry(0.01, 0.01, 0.6, 3), wellRopeMat);
    wellRope.position.set(8, 1.6, -14);
    wellGroup.add(wellRope);

    // Bucket
    const wellBucketMat = new MeshStandardMaterial({ color: 0x0c1008, roughness: 0.95, metalness: 0.0, flatShading: true });
    const wellBucket = new Mesh(new CylinderGeometry(0.12, 0.10, 0.22, 6), wellBucketMat);
    wellBucket.position.set(8, 1.6, -14);
    wellGroup.add(wellBucket);

    // Magical water glow (PointLight inside the well)
    const wellGlowLight = new PointLight(0x33ff66, 0.12, 2.5);
    wellGlowLight.position.set(8, 0.4, -14);
    wellGroup.add(wellGlowLight);

    group.add(wellGroup);
    _wellGroup = wellGroup;
    _wellBucket = wellBucket;
    _wellLight = wellGlowLight;

    // ── Harvest moon (C322) ──────────────────────────────────────────────────
    const moonGroup = new Group();

    // Moon disc
    const moonDiscMat = new MeshBasicMaterial({
      color: 0x1a3a22, transparent: true, opacity: 0.75, side: DoubleSide,
    });
    const moonDisc = new Mesh(new CircleGeometry(2.8, 16), moonDiscMat);
    moonDisc.position.set(12, 18, -50);
    moonGroup.add(moonDisc);

    // Moon halo (backplate, slightly behind disc)
    const moonHaloMat = new MeshBasicMaterial({
      color: 0x0a2a15, transparent: true, opacity: 0.15, side: DoubleSide, depthWrite: false,
    });
    const moonHalo = new Mesh(new CircleGeometry(3.5, 16), moonHaloMat);
    moonHalo.position.set(12, 18, -50.1);
    moonGroup.add(moonHalo);

    // Glow ring (torus outline)
    const moonRingMat = new MeshBasicMaterial({
      color: 0x1a5533, transparent: true, opacity: 0.2, side: DoubleSide,
    });
    const moonRing = new Mesh(new TorusGeometry(3.2, 0.15, 6, 32), moonRingMat);
    moonRing.position.set(12, 18, -50);
    moonGroup.add(moonRing);

    // Moonlight point light
    const moonLight = new PointLight(0x33ff66, 0.15, 40);
    moonLight.position.set(12, 18, -48);
    moonGroup.add(moonLight);

    group.add(moonGroup);
    _moonGroup = moonGroup;
    _moonHalo = moonHalo;
    _moonLight = moonLight;

    // ── Crop circle formations (C341) ────────────────────────────────────────
    const cropMat = () => new MeshBasicMaterial({ color: 0x0a1f0a, transparent: true, depthWrite: false });

    // Pattern 1 — main circle at (−6, −0.01, −25)
    const p1Outer = new Mesh(new TorusGeometry(5.0, 0.06, 5, 48), cropMat());
    (p1Outer.material as MeshBasicMaterial).opacity = 0.35;
    p1Outer.rotation.x = -Math.PI / 2;
    p1Outer.position.set(-6, -0.01, -25);
    group.add(p1Outer);
    _cropCircleMeshes.push(p1Outer);

    const p1Inner = new Mesh(new TorusGeometry(2.5, 0.05, 5, 36), cropMat());
    (p1Inner.material as MeshBasicMaterial).opacity = 0.30;
    p1Inner.rotation.x = -Math.PI / 2;
    p1Inner.position.set(-6, -0.01, -25);
    group.add(p1Inner);
    _cropCircleMeshes.push(p1Inner);

    const p1Center = new Mesh(new CircleGeometry(0.8, 16), cropMat());
    (p1Center.material as MeshBasicMaterial).opacity = 0.25;
    p1Center.rotation.x = -Math.PI / 2;
    p1Center.position.set(-6, -0.01, -25);
    group.add(p1Center);
    _cropCircleMeshes.push(p1Center);

    // Pattern 2 — satellite circle at (2, −0.01, −28)
    const p2Ring = new Mesh(new TorusGeometry(2.0, 0.05, 5, 32), cropMat());
    (p2Ring.material as MeshBasicMaterial).opacity = 0.28;
    p2Ring.rotation.x = -Math.PI / 2;
    p2Ring.position.set(2, -0.01, -28);
    group.add(p2Ring);
    _cropCircleMeshes.push(p2Ring);

    for (let bi = 0; bi < 4; bi++) {
      const bar = new Mesh(new BoxGeometry(3.8, 0.02, 0.06), cropMat());
      (bar.material as MeshBasicMaterial).opacity = 0.28;
      bar.position.set(2, -0.01, -28);
      bar.rotation.y = (bi / 4) * Math.PI;
      group.add(bar);
      _cropCircleMeshes.push(bar);
    }

    // Pattern 3 — tiny circle at (−10, −0.01, −20)
    const p3Ring = new Mesh(new TorusGeometry(1.2, 0.04, 5, 24), cropMat());
    (p3Ring.material as MeshBasicMaterial).opacity = 0.22;
    p3Ring.rotation.x = -Math.PI / 2;
    p3Ring.position.set(-10, -0.01, -20);
    group.add(p3Ring);
    _cropCircleMeshes.push(p3Ring);

    for (let ci = 0; ci < 2; ci++) {
      const crossBar = new Mesh(new BoxGeometry(2.2, 0.02, 0.05), cropMat());
      (crossBar.material as MeshBasicMaterial).opacity = 0.22;
      crossBar.position.set(-10, -0.01, -20);
      crossBar.rotation.y = ci * (Math.PI / 2);
      group.add(crossBar);
      _cropCircleMeshes.push(crossBar);
    }

    // Glow point light above main circle
    const cropGlow = new PointLight(0x33ff66, 0.04, 12);
    cropGlow.position.set(-6, 0.5, -25);
    group.add(cropGlow);
    _cropCircleLight = cropGlow;

    // ── Menhir procession (C354) ─────────────────────────────────────────────
    // 7 standing stones leading from mid-field toward the obelisk at (0,0,-18)
    menhirGroup354 = new Group();
    const _mR = () => Math.random();
    for (let mi = 0; mi < 7; mi++) {
      const t354 = mi / 6; // 0..1 along the line
      const baseX = -8 + t354 * 6;  // -8 to -2
      const baseZ = -10 - t354 * 8; // -10 to -18
      const jitterX = (_mR() - 0.5) * 0.6;
      const jitterZ = (_mR() - 0.5) * 0.6;
      const geo = new BoxGeometry(
        0.3 + _mR() * 0.1,
        2.5 + _mR() * 0.8,
        0.25 + _mR() * 0.08,
      );
      const mat = new MeshStandardMaterial({
        color: 0x2a4a2a,
        roughness: 0.95,
        metalness: 0.0,
        emissive: new Color(0x0d4420),
        emissiveIntensity: 0.05,
      });
      const mesh = new Mesh(geo, mat);
      const height = (geo.parameters as { height: number }).height;
      mesh.position.set(baseX + jitterX, height * 0.5 - 0.5, baseZ + jitterZ);
      mesh.rotation.y = (_mR() - 0.5) * 0.15;
      menhirGroup354.add(mesh);
      menhirMeshes354.push(mesh);
    }
    // Two point lights at start and end of procession
    const mLight0 = new PointLight(0x33ff66, 0.0, 4);
    mLight0.position.set(-8, 1.5, -10);
    menhirGroup354.add(mLight0);
    menhirLights354.push(mLight0);
    const mLight1 = new PointLight(0x33ff66, 0.0, 4);
    mLight1.position.set(-2, 1.5, -18);
    menhirGroup354.add(mLight1);
    menhirLights354.push(mLight1);
    group.add(menhirGroup354);

    // ── Green ritual bonfire (C370) ──────────────────────────────────────────
    bonfireGroup370 = new Group();

    // Log pile — 3 dark cylinders in a triangle
    const logMat370 = new MeshStandardMaterial({ color: 0x1a1a0a, roughness: 0.95 });
    const _bfg = bonfireGroup370;
    [0, 1, 2].forEach(i => {
      const angle370 = (i / 3) * Math.PI * 2;
      const log370 = new Mesh(new CylinderGeometry(0.06, 0.08, 0.7, 5), logMat370);
      log370.position.set(Math.cos(angle370) * 0.2, 0.04, Math.sin(angle370) * 0.2);
      log370.rotation.z = Math.PI / 2 + angle370 * 0.3;
      _bfg.add(log370);
    });

    // Flame tongues — 6 tall thin cones, green palette
    const flameColors370 = [0x0a3a0a, 0x1a6a1a, 0x33ff66, 0x1a6a1a, 0x0a3a0a, 0x22aa44];
    for (let fi = 0; fi < 6; fi++) {
      const fh = 0.5 + Math.random() * 0.7;
      const flameGeo370 = new ConeGeometry(0.06 + Math.random() * 0.04, fh, 4);
      const flameMat370 = new MeshBasicMaterial({
        color: flameColors370[fi % flameColors370.length],
        transparent: true,
        opacity: 0.65 + Math.random() * 0.2,
        depthWrite: false,
        side: DoubleSide,
      });
      const flame370 = new Mesh(flameGeo370, flameMat370);
      flame370.position.set((Math.random() - 0.5) * 0.2, fh / 2, (Math.random() - 0.5) * 0.2);
      flame370.userData['baseH'] = fh;
      flame370.userData['phase'] = Math.random() * Math.PI * 2;
      bonfireGroup370.add(flame370);
      bonfireFlames370.push(flame370);
    }

    // Embers — 8 tiny rising spheres
    const emberBaseMat370 = new MeshBasicMaterial({ color: 0x33ff66, transparent: true });
    for (let ei = 0; ei < 8; ei++) {
      const ember370 = new Mesh(new SphereGeometry(0.015, 3, 2), emberBaseMat370.clone());
      ember370.position.set((Math.random() - 0.5) * 0.3, Math.random() * 0.3, (Math.random() - 0.5) * 0.3);
      ember370.visible = false;
      bonfireGroup370.add(ember370);
      bonfireEmbers370.push(ember370);
      bonfireEmberData370.push({ vy: 0.5 + Math.random() * 0.8, life: 0, maxLife: 1.5 + Math.random() });
    }

    // Flickering point light
    bonfireLight370 = new PointLight(0x33ff66, 0.5, 8.0);
    bonfireLight370.position.set(0, 0.8, 0);
    bonfireGroup370.add(bonfireLight370);

    bonfireGroup370.position.set(2, 0, -14);
    group.add(bonfireGroup370);

    // ── Harvest scarecrow silhouette (C382) ──────────────────────────────────
    scarecrowGroup382 = new Group();
    const scMat = new MeshStandardMaterial({ color: 0x0a1a05, roughness: 0.9 });

    // Vertical post
    const scPost = new Mesh(new BoxGeometry(0.08, 2.2, 0.08), scMat);
    scPost.position.y = 1.1;
    scarecrowGroup382.add(scPost);

    // Horizontal arm post
    const scArms = new Mesh(new BoxGeometry(1.4, 0.08, 0.08), scMat);
    scArms.position.y = 1.6;
    scarecrowGroup382.add(scArms);

    // Body (stuffed sack)
    const scBody = new Mesh(new BoxGeometry(0.3, 0.5, 0.2), scMat);
    scBody.position.y = 1.35;
    scarecrowGroup382.add(scBody);

    // Head
    const scHead = new Mesh(new BoxGeometry(0.22, 0.22, 0.18), scMat);
    scHead.position.y = 1.75;
    scarecrowGroup382.add(scHead);

    // Pointed hat (cone)
    const scHatGeo = new ConeGeometry(0.14, 0.3, 6);
    const scHat = new Mesh(scHatGeo, scMat);
    scHat.position.y = 2.02;
    scarecrowGroup382.add(scHat);

    // Hat brim
    const scBrim = new Mesh(new CylinderGeometry(0.2, 0.2, 0.04, 8), scMat);
    scBrim.position.y = 1.88;
    scarecrowGroup382.add(scBrim);

    // Glowing eyes
    const scEyeMat = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.0 });
    ([-0.06, 0.06] as number[]).forEach(ex => {
      const scEye = new Mesh(new SphereGeometry(0.02, 4, 3), scEyeMat.clone());
      scEye.position.set(ex, 1.77, 0.1);
      scarecrowGroup382!.add(scEye);
      scarecrowEyes382.push(scEye);
    });

    // Arm sleeves (hanging cloth suggestion)
    ([-0.5, 0.5] as number[]).forEach(ax => {
      const scSleeve = new Mesh(new BoxGeometry(0.18, 0.35, 0.14), scMat);
      scSleeve.position.set(ax, 1.5, 0);
      scSleeve.rotation.z = ax * 0.15;
      scarecrowGroup382!.add(scSleeve);
    });

    scarecrowGroup382.position.set(-5, 0, -12);
    group.add(scarecrowGroup382);

    // ── Stone sundial (C429) ─────────────────────────────────────────────────
    sundialGroup429 = new Group();

    // Base disc
    const sdBase = new Mesh(
      new CylinderGeometry(0.75, 0.8, 0.12, 16),
      new MeshLambertMaterial({ color: 0x0a1a10 }),
    );
    sdBase.position.set(0, 0.06, 0);
    sundialGroup429.add(sdBase);

    // Pedestal
    const sdPedestal = new Mesh(
      new CylinderGeometry(0.2, 0.25, 0.6, 8),
      new MeshLambertMaterial({ color: 0x0a1a10 }),
    );
    sdPedestal.position.set(0, -0.25, 0);
    sundialGroup429.add(sdPedestal);

    // Gnomon (pointer) — tilted like a real sundial
    const sdGnomon = new Mesh(
      new BoxGeometry(0.05, 0.5, 0.04),
      new MeshLambertMaterial({ color: 0x0a1a10 }),
    );
    sdGnomon.position.set(0, 0.37, 0);
    sdGnomon.rotation.z = 0.5;
    sundialGroup429.add(sdGnomon);

    // 12 hour tick marks around the rim
    const tickMat = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.4 });
    for (let i = 0; i < 12; i++) {
      const angle = (i / 12) * Math.PI * 2;
      const tick = new Mesh(new BoxGeometry(0.06, 0.04, 0.12), tickMat);
      tick.position.set(Math.cos(angle) * 0.6, 0.13, Math.sin(angle) * 0.6);
      tick.rotation.y = -angle;
      sundialGroup429.add(tick);
    }

    // Shadow plane (gnomon shadow)
    const sdShadow = new Mesh(
      new PlaneGeometry(0.65, 0.04),
      new MeshBasicMaterial({ color: 0x0a1a10, transparent: true, opacity: 0.7 }),
    );
    sdShadow.rotation.x = -Math.PI / 2;
    sdShadow.position.set(0, 0.13, 0);
    sundialGroup429.add(sdShadow);
    sundialShadow429 = sdShadow;

    // Point light
    const sdLight = new PointLight(0x33ff66, 0.08, 3.0);
    sdLight.position.set(0, 0.5, 0);
    sundialGroup429.add(sdLight);
    sundialLight429 = sdLight;

    sundialGroup429.position.set(-4, 0, -10);
    group.add(sundialGroup429);
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
    // Plaine des Druides — stone well bucket sway + magical water pulse
    if (_wellBucket !== null) {
      const t = Date.now() * 0.001;
      _wellBucket.rotation.z = Math.sin(t * 0.4) * 0.05;
    }
    if (_wellLight !== null) {
      const t = Date.now() * 0.001;
      _wellLight.intensity = 0.08 + Math.sin(t * 0.7) * 0.04;
    }
    // Plaine des Druides — harvest moon drift + halo pulse + light pulse (C322)
    if (_moonGroup !== null) {
      const t = Date.now() * 0.001;
      _moonGroup.position.y = 18 + Math.sin(t * 0.02) * 0.5;
    }
    if (_moonHalo !== null) {
      const t = Date.now() * 0.001;
      (_moonHalo.material as MeshBasicMaterial).opacity = 0.10 + Math.sin(t * 0.3) * 0.05;
    }
    if (_moonLight !== null) {
      const t = Date.now() * 0.001;
      _moonLight.intensity = 0.12 + Math.sin(t * 0.25) * 0.03;
    }
    // Plaine des Druides — crop circle slow rotation + glow pulse (C341)
    if (_cropCircleMeshes.length > 0) {
      _cropCircleTime += dt;
      const t = _cropCircleTime;
      for (const ring of _cropCircleMeshes) {
        ring.rotation.z += dt * 0.01;
      }
      // Center disc (index 2) opacity pulse
      const disc = _cropCircleMeshes[2];
      if (disc !== undefined) {
        (disc.material as MeshBasicMaterial).opacity = 0.20 + Math.sin(t * 0.3) * 0.06;
      }
    }
    if (_cropCircleLight !== null) {
      const t = _cropCircleTime;
      _cropCircleLight.intensity = 0.02 + Math.sin(t * 0.15) * 0.02;
    }
    // Plaine des Druides — menhir procession wave pulse (C354)
    if (menhirMeshes354.length > 0) {
      _menhirElapsed354 += dt;
      const cycle354 = (_menhirElapsed354 % 7.0) / 7.0; // 0..1 over 7s
      menhirMeshes354.forEach((m, i) => {
        const phase = i / menhirMeshes354.length;
        const wave = Math.max(0, 1 - Math.abs(cycle354 - phase) * 6);
        (m.material as MeshStandardMaterial).emissiveIntensity = 0.05 + wave * 0.10;
      });
      // pulse light at start and end of procession
      if (menhirLights354[0]) menhirLights354[0].intensity = (menhirMeshes354[0].material as MeshStandardMaterial).emissiveIntensity * 0.4;
      if (menhirLights354[1]) menhirLights354[1].intensity = (menhirMeshes354[menhirMeshes354.length - 1].material as MeshStandardMaterial).emissiveIntensity * 0.4;
    }
    // Plaine des Druides — green ritual bonfire flickering flames + embers (C370)
    if (bonfireGroup370 !== null && bonfireFlames370.length > 0) {
      bonfireElapsed370 += dt;
      const et370 = bonfireElapsed370;
      bonfireFlames370.forEach((flame370) => {
        const phase370 = flame370.userData['phase'] as number;
        const flicker370 = 0.85 + Math.sin(et370 * 8 + phase370) * 0.15 + Math.sin(et370 * 13.7 + phase370 * 2) * 0.08;
        flame370.scale.y = flicker370;
        flame370.scale.x = 0.9 + Math.sin(et370 * 5 + phase370) * 0.1;
        flame370.rotation.y = Math.sin(et370 * 3 + phase370) * 0.15;
        (flame370.material as MeshBasicMaterial).opacity = (0.65 + Math.sin(et370 * 6 + phase370) * 0.15) * flicker370;
      });
      if (bonfireLight370 !== null) {
        bonfireLight370.intensity = 0.4 + Math.sin(et370 * 7.3) * 0.15 + Math.sin(et370 * 11.1) * 0.1 + Math.random() * 0.05;
      }
      bonfireEmbers370.forEach((ember370, ei) => {
        const data370 = bonfireEmberData370[ei];
        if (data370 === undefined) return;
        if (ember370.visible) {
          data370.life += dt;
          ember370.position.y += data370.vy * dt;
          ember370.position.x += Math.sin(et370 * 2 + ei) * 0.01;
          (ember370.material as MeshBasicMaterial).opacity = Math.max(0, 1 - data370.life / data370.maxLife);
          if (data370.life >= data370.maxLife) {
            ember370.visible = false;
            data370.life = 0;
          }
        } else if (Math.random() < dt * 0.5) {
          ember370.position.set((Math.random() - 0.5) * 0.2, 0.2, (Math.random() - 0.5) * 0.2);
          ember370.visible = true;
          data370.life = 0;
        }
      });
    }
    // Plaine des Druides — harvest scarecrow wind sway + eye glow (C382)
    if (scarecrowGroup382 !== null) {
      const tSc = Date.now() * 0.001;
      scarecrowGroup382.rotation.z = Math.sin(tSc * 0.6) * 0.03 + Math.sin(tSc * 1.3) * 0.015;
      scarecrowEyes382.forEach(eye => {
        (eye.material as MeshBasicMaterial).opacity = 0.15 + Math.sin(tSc * 0.5) * 0.1;
      });
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
    // Marais korrigans — erratic firefly swarm (C319)
    if (_bogFireflies.length > 0) {
      const t = Date.now() * 0.001;
      for (const ff of _bogFireflies) {
        const ud = ff.userData as {
          tx: number; ty: number; tz: number;
          moveSpeed: number; moveTimer: number; restTimer: number;
          resting: boolean; phase: number; lightIndex?: number;
        };

        if (ud.resting) {
          ud.restTimer -= dt;
          if (ud.restTimer <= 0) {
            // Pick new random target and start moving
            const R = Math.random;
            ud.tx = (R() - 0.5) * 30;
            ud.ty = 0.3 + R() * 2.2;
            ud.tz = -8 - R() * 24;
            ud.moveTimer = 1.2 + R() * 1.3;
            ud.resting = false;
          }
        } else {
          // Lerp toward target
          const dx = ud.tx - ff.position.x;
          const dy = ud.ty - ff.position.y;
          const dz = ud.tz - ff.position.z;
          const dist = Math.sqrt(dx * dx + dy * dy + dz * dz);
          if (dist < 0.05) {
            // Close enough — freeze briefly
            ud.resting = true;
            ud.restTimer = 0.3 + Math.random() * 0.5;
          } else {
            const step = Math.min(ud.moveSpeed * dt, dist);
            const inv = step / dist;
            ff.position.x += dx * inv;
            ff.position.y += dy * inv;
            ff.position.z += dz * inv;
          }
        }

        // Fast flicker opacity
        (ff.material as MeshBasicMaterial).opacity = 0.4 + Math.sin(t * 8.0 + ud.phase) * 0.4;

        // Sync attached point light if any
        if (ud.lightIndex !== undefined) {
          const fl = _bogFireflyLights[ud.lightIndex];
          if (fl !== undefined) {
            fl.position.copy(ff.position);
            fl.intensity = 0.15 + Math.sin(t * 7.0 + ud.phase) * 0.15;
          }
        }
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
    // Marais korrigans — creeping fog tendrils (C334)
    if (_fogTendrils.length > 0) {
      const t = Date.now() * 0.001;
      for (const tendril of _fogTendrils) {
        const { baseX, baseZ, phase, speed, maxOpacity } = tendril.userData as {
          baseX: number; baseZ: number; phase: number; speed: number; maxOpacity: number;
        };
        (tendril.material as MeshBasicMaterial).opacity = Math.max(
          0,
          maxOpacity * (0.5 + Math.sin(t * speed + phase) * 0.5),
        );
        tendril.position.x = baseX + Math.sin(t * speed * 0.7 + phase) * 1.5;
        tendril.position.z = baseZ + Math.cos(t * speed * 0.5 + phase) * 1.0;
        tendril.rotation.z = Math.sin(t * speed * 2.0 + phase) * 0.08;
      }
    }
    // Marais korrigans — lure wisp figure-8 path with trailing orbs (C345)
    if (_lureWisp !== null && _lureLight !== null) {
      const t = Date.now() * 0.001;
      const lx = Math.sin(t * 0.18) * 7;
      const ly = 1.2 + Math.sin(t * 0.36) * 0.6;
      const lz = -18 + Math.sin(t * 0.18) * Math.cos(t * 0.18) * 4;
      _lureWisp.position.set(lx, ly, lz);
      _lureLight.position.set(lx, ly, lz);
      _lureLight.intensity = 0.6 + Math.sin(t * 1.5) * 0.2;
      const pulse = 0.9 + Math.sin(t * 2.0) * 0.12;
      _lureWisp.scale.setScalar(pulse);
      // Push new position into ring buffer
      _lureTrailPositions.push([lx, ly, lz]);
      if (_lureTrailPositions.length > 5) _lureTrailPositions.shift();
      // Position trail orbs at stored (older) positions
      for (let i = 0; i < _lureTrailOrbs.length; i++) {
        const trailOrb = _lureTrailOrbs[i];
        const pos = _lureTrailPositions[_lureTrailPositions.length - 1 - i];
        if (trailOrb !== undefined && pos !== undefined) {
          trailOrb.position.set(pos[0], pos[1], pos[2]);
        }
      }
    }
    // Marais korrigans — sleeping toad breathing + lily pad bob (C374)
    if (toadBody374 !== null && toadGroup374 !== null) {
      const t374 = Date.now() * 0.001;
      const breathe = 1.0 + Math.sin(t374 * 0.8) * 0.04;
      toadBody374.scale.set(breathe, 0.6 * breathe, 1.2 * breathe);
      toadGroup374.position.y = Math.sin(t374 * 0.3) * 0.02;
      toadGroup374.rotation.z = Math.sin(t374 * 0.2 + 1) * 0.01;
    }
    // Korrigan spirit dancers ring dance animation (C394)
    if (korrFigures394.length > 0 && korrGroup394) {
      korrTime394 += dt * korrDir394 * 0.6;

      korrNextDir394 -= dt;
      if (korrNextDir394 <= 0) {
        korrDir394 *= -1;
        korrNextDir394 = 8.0 + Math.random() * 2.0;
      }

      const DANCE_RADIUS = 0.9;
      korrFigures394.forEach((fig, i) => {
        const angle = korrTime394 + (i / 3) * Math.PI * 2;
        const fx = Math.cos(angle) * DANCE_RADIUS;
        const fz = Math.sin(angle) * DANCE_RADIUS;
        const fy = Math.abs(Math.sin(korrTime394 * 3 + i * 1.5)) * 0.12;
        fig.position.set(fx, fy, fz);
        fig.rotation.y = -angle + Math.PI / 2;

        // Head bob
        const head = fig.children[1];
        if (head) head.position.y = 0.65 + Math.sin(korrTime394 * 4 + i) * 0.03;
      });
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
    // Landes bruyere — heather wind sway (every 4th mesh has swayPhase)
    if (_heatherMeshes.length > 0) {
      const t = Date.now() * 0.001;
      for (const mesh of _heatherMeshes) {
        const swayPhase = mesh.userData['swayPhase'] as number | undefined;
        if (swayPhase !== undefined) {
          mesh.rotation.z = Math.sin(t * 0.6 + swayPhase) * 0.05;
        }
      }
    }
    // Landes bruyere — moor stone circle subtle glow pulse
    if (_moorCircleLight !== null) {
      _moorCircleLight.intensity = 0.03 + Math.sin(Date.now() * 0.001 * 0.2) * 0.02;
    }
    // Landes bruyere — crow on dolmen head tilt + wing flap (C358)
    if (crowGroup358 !== null) {
      const t358 = Date.now() * 0.001;
      // Idle head tilt (children[1] = head)
      crowGroup358.children[1].rotation.y = Math.sin(t358 * 0.3) * 0.12;
      crowGroup358.children[1].rotation.x = Math.sin(t358 * 0.2 + 1) * 0.05;

      // Wing flap timer
      crowNextFlap358 -= dt;
      if (crowNextFlap358 <= 0 && crowFlapT358 < 0) {
        crowFlapT358 = 0;
        crowNextFlap358 = 8 + Math.random() * 4;
      }
      if (crowFlapT358 >= 0) {
        crowFlapT358 += dt;
        const flapPhase = Math.min(crowFlapT358 / 1.0, 1.0);
        const flapAngle = Math.sin(flapPhase * Math.PI) * 0.9;
        const emissive = Math.sin(flapPhase * Math.PI) * 0.12;
        crowWings358.forEach(w => {
          w.rotation.z = (w.userData['side'] as number) * (0.15 + flapAngle);
          (w.material as MeshStandardMaterial).emissiveIntensity = emissive;
        });
        if (crowFlapT358 >= 1.0) crowFlapT358 = -1;
      }
    }
    // Landes bruyere — ignis fatuus wisp procession (C386)
    if (ignisMeshes386.length > 0 && ignisFatuusGroup386) {
      ignisTime386 += dt * ignisDirection386 * 0.4;

      // Reverse direction timer
      ignisNextReverse386 -= dt;
      if (ignisNextReverse386 <= 0) {
        ignisDirection386 *= -1;
        ignisNextReverse386 = 15.0 + Math.random() * 5.0;
      }

      // Lead wisp traces a sinusoidal path across the moor
      ignisMeshes386.forEach((mesh, i) => {
        // Each wisp follows leader with delay i * 0.5s
        const t = ignisTime386 - i * 0.5;
        const wx = Math.sin(t * 0.7) * 8;
        const wz = -20 + Math.sin(t * 1.1) * 3;
        const wy = 0.5 + Math.sin(t * 2.3) * 0.2 + Math.sin(t * 5.1 + i) * 0.08;

        mesh.position.set(wx, wy, wz);
        ignisLights386[i].position.set(wx, wy, wz);

        // Flicker opacity and size
        (mesh.material as MeshBasicMaterial).opacity = 0.65 + Math.sin(landeSporeTime * 8 + i * 1.3) * 0.2;
        ignisLights386[i].intensity = 0.10 + Math.sin(landeSporeTime * 6 + i * 0.9) * 0.04;
      });
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
    // Cercles de Pierres — rising altar fire particles
    if (_altarFireMeshes.length > 0) {
      const t = Date.now() * 0.001;
      for (const particle of _altarFireMeshes) {
        const { baseX, baseZ, riseSpeed, phase, maxHeight } = particle.userData as {
          baseX: number; baseZ: number; riseSpeed: number; phase: number; maxHeight: number;
        };
        const progress = ((t * riseSpeed + phase) % (Math.PI * 2)) / (Math.PI * 2);
        particle.position.x = baseX + Math.sin(t * 2.3 + phase) * 0.08;
        particle.position.y = 0.5 + progress * maxHeight;
        particle.position.z = baseZ;
        const s = (1 - progress) * 0.8 + 0.2;
        particle.scale.setScalar(s);
        (particle.material as MeshBasicMaterial).opacity = 1 - progress;
      }
    }
    // Cercles de Pierres — altar fire light pulse
    if (_altarFireLight !== null) {
      const t = Date.now() * 0.001;
      _altarFireLight.intensity = 0.4 + Math.sin(t * 2.1) * 0.2;
    }
    // Cercles de Pierres — spectral dancers orbit altar (C327)
    if (_dancerGroups.length > 0) {
      const t = Date.now() * 0.001;
      const orbitSpeed = 0.4;
      for (let fi = 0; fi < _dancerGroups.length; fi++) {
        const baseAngle = (fi / 5) * Math.PI * 2;
        const angle = baseAngle + orbitSpeed * t;
        const x = Math.cos(angle) * 5;
        const z = -15 + Math.sin(angle) * 5;
        const y = 0.5 + Math.sin(t * 1.2 + fi * 1.26) * 0.15;
        _dancerGroups[fi].position.set(x, y, z);
        _dancerGroups[fi].rotation.y = -angle + Math.PI / 2;
        _dancerArmGroups[fi].rotation.z = Math.sin(t * 2.1 + fi * 0.8) * 0.4;
      }
    }
    // Cercles de Pierres — circling raven flock overhead (C342)
    if (_ravenGroups.length > 0) {
      const t = Date.now() * 0.001;
      for (let ri = 0; ri < _ravenGroups.length; ri++) {
        const rg = _ravenGroups[ri];
        const ud = rg.userData as { radius: number; orbitSpeed: number; phase: number; flapSpeed: number; flapAmp: number; yOffset: number };
        const angle = ud.phase + ud.orbitSpeed * t;
        rg.position.x = ud.radius * Math.cos(angle);
        rg.position.z = -15 + ud.radius * Math.sin(angle);
        rg.position.y = 12 + ud.yOffset + Math.sin(t * 0.6 + ud.phase) * 0.8;
        rg.rotation.y = -angle + Math.PI / 2;
        _ravenWings[ri].rotation.z = ud.flapAmp * Math.sin(t * ud.flapSpeed + ud.phase);
      }
    }
    // Cercles de Pierres — moonbeam shaft pulse (C362)
    if (moonbeamMesh362 !== null) {
      const t = Date.now() * 0.001;
      const pulse = 0.08 + Math.sin(t * 0.5) * 0.04 + Math.sin(t * 0.13) * 0.02;
      (moonbeamMesh362.material as MeshBasicMaterial).opacity = pulse;
      moonbeamMesh362.rotation.y += dt * 0.05;
      if (moonbeamLight362 !== null) {
        moonbeamLight362.intensity = pulse * 1.5;
      }
    }
    // Cercles de Pierres — cloaked druid figures cloak ripple + arm animation (C390)
    if (druidGroup390 !== null) {
      const t390 = Date.now() * 0.001;
      druidGroup390.children.forEach((fig) => {
        const phase = (fig as Group).userData['bobPhase'] as number || 0;
        (fig as Group).scale.x = 1.0 + Math.sin(t390 * 1.2 + phase) * 0.015;
        (fig as Group).scale.z = 1.0 + Math.sin(t390 * 0.9 + phase + 1) * 0.01;
      });
      if (druidArmLeft390 !== null && druidArmRight390 !== null) {
        const armAngle = 0.8 + Math.sin(t390 * 0.3) * 0.25;
        druidArmLeft390.rotation.z = -armAngle;
        druidArmRight390.rotation.z = armAngle;
      }
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
    // Vallee Anciens — aurora borealis undulation
    if (_auroraBands.length > 0) {
      _auroraTime += dt;
      const t = _auroraTime;
      _auroraBands.forEach((band, i) => {
        (band.material as MeshBasicMaterial).opacity = Math.max(0, 0.12 + Math.sin(t * 0.3 + i * 1.1) * 0.10);
        band.position.x = Math.sin(t * 0.2 + i * 0.7) * 3.0;
        band.rotation.z = Math.sin(t * 0.15 + i * 0.5) * 0.08;
      });
    }
    // Vallee Anciens — stone gate rune glow pulse
    if (_gateRunePlane !== null) {
      const t = _auroraTime; // reuse same accumulator
      (_gateRunePlane.material as MeshBasicMaterial).opacity = 0.10 + Math.sin(t * 0.35) * 0.06;
    }
    if (_gateLight !== null) {
      const t = _auroraTime;
      _gateLight.intensity = 0.08 + Math.sin(t * 0.4) * 0.04;
    }
    // Vallee Anciens — spirit pillar beams sequential activation (C351)
    if (_spiritBeams.length > 0) {
      _spiritBeamTime += dt;
      const t = _spiritBeamTime;
      const cycle = t % 18;
      _spiritBeams.forEach((beam, i) => {
        const mat = beam.material as MeshBasicMaterial;
        const peakStart = i * 6;
        const peakEnd   = peakStart + 4;
        if (cycle >= peakStart && cycle < peakEnd) {
          mat.opacity = 0.10 + Math.sin(t * 2.0) * 0.04;
        } else {
          mat.opacity = Math.max(0, mat.opacity - dt * 0.3);
        }
        if (i < _spiritLights.length) {
          _spiritLights[i].intensity = mat.opacity * 0.8;
        }
      });
    }
    // Vallee Anciens — ancient tomb inner glow pulse + occasional flare (C378)
    if (tombGlowLight378) {
      tombGlowLight378.intensity = 0.05 + Math.sin(_auroraTime * 0.4) * 0.04;
      tombNextFlare378 -= dt;
      if (tombNextFlare378 <= 0 && tombFlareT378 < 0) {
        tombFlareT378 = 0;
        tombNextFlare378 = 10.0 + Math.random() * 8.0;
      }
      if (tombFlareT378 >= 0) {
        tombFlareT378 += dt;
        if (tombFlareT378 < 0.3) {
          tombGlowLight378.intensity = 0.05 + (tombFlareT378 / 0.3) * 0.10;
        } else if (tombFlareT378 < 0.8) {
          tombGlowLight378.intensity = 0.15 - ((tombFlareT378 - 0.3) / 0.5) * 0.10;
        } else {
          tombGlowLight378.intensity = 0.05 + Math.sin(_auroraTime * 0.4) * 0.04;
          tombFlareT378 = -1;
        }
      }
    }
    // Vallee Anciens — stone labyrinth moss pulse (C403)
    if (labyrinthGroup403) {
      labyrinthMossT403 += dt;
      const labLight = labyrinthGroup403.children.find(c => c instanceof PointLight) as PointLight | undefined;
      if (labLight) labLight.intensity = 0.04 + Math.sin(labyrinthMossT403 * 0.6) * 0.015;
    }
    // Cercles de Pierres — central altar ritual fire (C407)
    if (altarFireGroup407) {
      altarFireT407 += dt;
      if (altarFireCone407) {
        altarFireCone407.scale.x = 0.85 + Math.sin(altarFireT407 * 8.3) * 0.18;
        altarFireCone407.scale.z = 0.85 + Math.sin(altarFireT407 * 7.1 + 1) * 0.18;
        altarFireCone407.scale.y = 0.9 + Math.sin(altarFireT407 * 5.7) * 0.12;
        (altarFireCone407.material as MeshBasicMaterial).opacity = 0.6 + Math.sin(altarFireT407 * 11) * 0.15;
      }
      if (altarFireLight407) {
        altarFireLight407.intensity = 0.45 + Math.sin(altarFireT407 * 9.3) * 0.12;
      }
      altarEmbers407.forEach((ember, i) => {
        const vel = altarEmberVel407[i];
        vel.life += dt;
        if (vel.life > vel.maxLife) {
          vel.life = 0;
          vel.maxLife = Math.random() * 1.5 + 0.8;
          vel.vx = (Math.random() - 0.5) * 0.6;
          vel.vy = Math.random() * 1.2 + 0.4;
          ember.position.set(0, 0.3, -15);
        } else {
          ember.position.x += vel.vx * dt;
          ember.position.y += vel.vy * dt;
          ember.position.y -= dt * 0.15;
          (ember.material as MeshBasicMaterial).opacity = 1.0 - vel.life / vel.maxLife;
        }
      });
    }
    // Monts brumeux — soaring eagle slow banking circle + wing flap (C412)
    if (eagleGroup412) {
      eagleT412 += dt * 0.18;
      eagleWingT412 += dt * 0.9;
      const orbitR = 6.0;
      const cx = 0, cz = -20;
      eagleGroup412.position.x = cx + Math.cos(eagleT412) * orbitR;
      eagleGroup412.position.z = cz + Math.sin(eagleT412) * orbitR;
      eagleGroup412.position.y = 11 + Math.sin(eagleT412 * 2.3) * 0.8;
      eagleGroup412.rotation.y = -(eagleT412 + Math.PI / 2);
      eagleGroup412.rotation.z = Math.sin(eagleT412) * 0.25;
      const flapAngle = Math.sin(eagleWingT412) * 0.18;
      if (eagleWingL412) eagleWingL412.rotation.z = flapAngle;
      if (eagleWingR412) eagleWingR412.rotation.z = -flapAngle;
    }
    // Landes bruyere — carved menhir spiral pulse (C417)
    if (menhirGroup417) {
      menhirT417 += dt;
      menhirCarveGlows417.forEach((glyph, i) => {
        const mat = glyph.material as MeshBasicMaterial;
        mat.opacity = 0.18 + Math.sin(menhirT417 * 1.8 + i * 0.7) * 0.15;
        glyph.rotation.z = (i * 0.3) + menhirT417 * (0.1 + i * 0.02);
      });
      if (menhirLight417) {
        menhirLight417.intensity = 0.12 + Math.sin(menhirT417 * 0.9) * 0.05;
      }
    }
    // Marais korrigans — rotting swamp dock algae bioluminescence (C422)
    if (swampDockGroup422) {
      swampDockT422 += dt;
      swampDockAlgae422.forEach((algae, i) => {
        const mat = algae.material as MeshBasicMaterial;
        mat.opacity = 0.15 + Math.sin(swampDockT422 * 1.4 + i * 0.8) * 0.1;
      });
      if (swampDockLight422) {
        swampDockLight422.intensity = 0.10 + Math.sin(swampDockT422 * 0.9) * 0.04;
      }
    }
    // Vallee anciens — spectral ghost apparition fade cycle (C425)
    if (ghostGroup425 && ghostBody425 && ghostHead425 && ghostLight425) {
      ghostT425 += dt;
      ghostPhaseTimer425 += dt;

      if (ghostPhaseTimer425 >= ghostNextAppear425) {
        ghostPhaseTimer425 = 0;
        ghostNextAppear425 = 15 + Math.random() * 10;
      }

      const phase = ghostPhaseTimer425;
      let opacity = 0;
      if (phase < 2.0) {
        opacity = (phase / 2.0) * 0.45;
      } else if (phase < 6.0) {
        opacity = 0.45 + Math.sin(ghostT425 * 1.5) * 0.08;
      } else if (phase < 8.0) {
        opacity = (1.0 - (phase - 6.0) / 2.0) * 0.45;
      }

      ghostGroup425.traverse(c => {
        if (c instanceof Mesh) {
          const mat = c.material as MeshBasicMaterial;
          if (mat.transparent) mat.opacity = opacity;
        }
      });
      ghostLight425.intensity = opacity * 0.35;

      ghostGroup425.position.y = Math.sin(ghostT425 * 0.6) * 0.2;
      ghostGroup425.position.x = -3 + Math.sin(ghostT425 * 0.25) * 0.4;
      ghostGroup425.rotation.y = Math.sin(ghostT425 * 0.15) * 0.5;
    }
    // Plaine des Druides — stone sundial rotating shadow (C429)
    if (sundialGroup429) {
      sundialT429 += dt;
      // Shadow rotates slowly (full rotation every 120s = simulated day cycle)
      if (sundialShadow429) {
        sundialShadow429.rotation.y = sundialT429 * (Math.PI * 2 / 120);
        // Shadow length pulses slightly
        sundialShadow429.scale.x = 0.9 + Math.sin(sundialT429 * 0.1) * 0.15;
      }
      // Tick marks pulse gently
      if (sundialLight429) {
        sundialLight429.intensity = 0.07 + Math.sin(sundialT429 * 0.8) * 0.025;
      }
    }
    // Cercles de Pierres — moonrise arc across sky (C433)
    if (stoneMoonGroup433 && stoneMoonMesh433 && stoneMoonLight433) {
      stoneMoonT433 += dt;
      const arcT = (stoneMoonT433 % 90) / 90;
      const arcAngle = arcT * Math.PI;

      stoneMoonGroup433.position.x = Math.cos(arcAngle) * 20 - 2;
      stoneMoonGroup433.position.y = Math.sin(arcAngle) * 16 - 1;
      stoneMoonGroup433.position.z = -30;

      let moonOpacity = 0.8;
      if (arcT < 0.15) moonOpacity = (arcT / 0.15) * 0.8;
      else if (arcT > 0.85) moonOpacity = ((1 - arcT) / 0.15) * 0.8;
      (stoneMoonMesh433.material as MeshBasicMaterial).opacity = moonOpacity;

      const zenithFactor = Math.sin(arcAngle);
      stoneMoonLight433.intensity = zenithFactor * 0.35;
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
    // Monts brumeux — frozen lake shimmer
    if (_lakeMesh !== null) {
      const t = Date.now() * 0.001;
      (_lakeMesh.material as MeshBasicMaterial).opacity = 0.50 + Math.sin(t * 0.25) * 0.05;
    }
    if (_lakeLight !== null) {
      const t = Date.now() * 0.001;
      _lakeLight.intensity = 0.03 + Math.sin(t * 0.4) * 0.02;
    }
    // Monts brumeux — frozen waterfall shimmer (C330)
    if (_waterfallGroup !== null) {
      const t = Date.now() * 0.001;
      const iceSheetMesh = _waterfallGroup.children[0] as Mesh;
      (iceSheetMesh.material as MeshBasicMaterial).opacity = 0.42 + Math.sin(t * 0.18) * 0.04;
    }
    if (_waterfallLight !== null) {
      const t = Date.now() * 0.001;
      _waterfallLight.intensity = 0.04 + Math.sin(t * 0.3) * 0.02;
    }
    // Monts brumeux — mountain goat grazing animation (C346)
    if (_goatHead !== null || _goatTail !== null || _goatBody !== null) {
      const t = Date.now() * 0.001;
      if (_goatHead !== null) {
        _goatHead.rotation.x = Math.sin(t * 0.4) * 0.15;
      }
      if (_goatTail !== null) {
        _goatTail.rotation.z = Math.sin(t * 2.5) * 0.2;
      }
      if (_goatBody !== null) {
        _goatBody.rotation.z = Math.sin(t * 0.15) * 0.02;
      }
    }
    // Monts brumeux — ice crystal moonlight shimmer (C366)
    if (crystalGroups366.length > 0) {
      const elapsedTime366 = montsWindTime; // reuse accumulated monts time
      crystalGroups366.forEach((cg, ci) => {
        cg.children.forEach((child) => {
          if (child instanceof Mesh && child.material) {
            const mat = child.material as MeshStandardMaterial;
            const phase = (mat.userData['phase'] as number) ?? 0;
            mat.emissiveIntensity = 0.10 + Math.sin(elapsedTime366 * 0.7 + phase + ci * 1.2) * 0.08;
          }
        });
        if (crystalLights366[ci] !== undefined) {
          crystalLights366[ci].intensity = 0.06 + Math.sin(elapsedTime366 * 0.5 + ci * 0.8) * 0.04;
        }
      });
    }
    // Monts brumeux — hermit cave inner glow flicker + shadow event (C398)
    if (caveGlowLight398) {
      // Slow flicker (hermit's fire)
      caveGlowLight398.intensity = 0.06 + Math.sin(montsWindTime * 1.8) * 0.03 + Math.sin(montsWindTime * 3.1) * 0.02;

      // Shadow event (brief dimming = someone passes by)
      caveNextShadow398 -= dt;
      if (caveNextShadow398 <= 0 && caveShadowT398 < 0) {
        caveShadowT398 = 0;
        caveNextShadow398 = 10.0 + Math.random() * 5.0;
      }
      if (caveShadowT398 >= 0) {
        caveShadowT398 += dt;
        if (caveShadowT398 < 0.3) caveGlowLight398.intensity *= 0.3;
        else if (caveShadowT398 < 0.6) caveGlowLight398.intensity *= 0.5;
        else { caveShadowT398 = -1; }
      }
    }
  };

  const dispose = (): void => {
    plaineWispMeshes = [];
    plaineObeliskGlowMat = null;
    _wellGroup = null;
    _wellBucket = null;
    _wellLight = null;
    _moonGroup = null;
    _moonHalo = null;
    _moonLight = null;
    _cropCircleMeshes.length = 0;
    _cropCircleLight = null;
    // Menhir procession cleanup (C354)
    if (menhirGroup354) { group.remove(menhirGroup354); menhirGroup354.traverse(c => { if ((c as Mesh).geometry) (c as Mesh).geometry.dispose(); }); menhirGroup354 = null; }
    menhirMeshes354 = [];
    menhirLights354 = [];
    // Ritual bonfire cleanup (C370)
    if (bonfireGroup370) { group.remove(bonfireGroup370); bonfireGroup370.traverse(c => { const m = c as Mesh; if (m.geometry) m.geometry.dispose(); if (m.material) { if (Array.isArray(m.material)) m.material.forEach(mt => mt.dispose()); else m.material.dispose(); } }); bonfireGroup370 = null; }
    bonfireFlames370 = [];
    bonfireEmbers370 = [];
    bonfireEmberData370 = [];
    if (bonfireLight370) { bonfireLight370.dispose(); bonfireLight370 = null; }
    maraisWispMeshes = [];
    _bogFireflies.length = 0;
    _bogFireflyLights.length = 0;
    _fogTendrils.length = 0;
    _lureWisp = null;
    _lureLight = null;
    _lureTrailOrbs.length = 0;
    _lureTrailPositions.length = 0;
    // Toad on lily pad cleanup (C374)
    if (toadGroup374) { group.remove(toadGroup374); toadGroup374.traverse(c => { const cm = c as Mesh; if (cm.geometry) cm.geometry.dispose(); if (cm.material) { if (Array.isArray(cm.material)) cm.material.forEach(mt => mt.dispose()); else cm.material.dispose(); } }); toadGroup374 = null; }
    toadBody374 = null;
    // Korrigan spirit dancers cleanup (C394)
    if (korrGroup394) { group.remove(korrGroup394); korrGroup394.traverse(c => { const cm = c as Mesh; if (cm.geometry) cm.geometry.dispose(); if (cm.material) { if (Array.isArray(cm.material)) cm.material.forEach(mt => mt.dispose()); else cm.material.dispose(); } }); korrGroup394 = null; }
    korrFigures394 = [];
    _auroraBands.length = 0;
    montsSnowMeshes = [];
    altarRuneRing = null;
    _altarFireMeshes.length = 0;
    _altarFireLight = null;
    _dancerGroups.length = 0;
    _dancerArmGroups.length = 0;
    _ravenGroups.length = 0;
    _ravenWings.length = 0;
    _eagleGroup = null;
    _eagleWingL = null;
    _eagleWingR = null;
    _lakeMesh = null;
    _lakeLight = null;
    _waterfallGroup = null;
    _waterfallLight = null;
    _goatGroup = null;
    _goatHead = null;
    _goatTail = null;
    _goatBody = null;
    // Ice crystal formations cleanup (C366)
    crystalGroups366.forEach(cg => {
      group.remove(cg);
      cg.traverse(c => {
        const m = c as Mesh;
        if (m.geometry) m.geometry.dispose();
        if (m.material) {
          if (Array.isArray(m.material)) m.material.forEach(mat => mat.dispose());
          else (m.material as MeshStandardMaterial).dispose();
        }
      });
    });
    crystalGroups366 = [];
    crystalLights366 = [];
    // Hermit cave entrance cleanup (C398)
    if (caveGroup398) { group.remove(caveGroup398); caveGroup398.traverse(c => { const cm = c as Mesh; if (cm.geometry) cm.geometry.dispose(); if (cm.material) { if (Array.isArray(cm.material)) cm.material.forEach(mt => mt.dispose()); else cm.material.dispose(); } }); caveGroup398 = null; }
    if (caveGlowLight398) { caveGlowLight398.dispose(); caveGlowLight398 = null; }
    _deadTreeGroup = null;
    _templeGroup = null;
    _gateGroup = null;
    _gateLight = null;
    _gateRunePlane = null;
    _heatherMeshes.length = 0;
    _moorCircleGroup = null;
    _moorCircleLight = null;
    _watchtowerGroup = null;
    _watchtowerLight = null;
    // Moonbeam shaft cleanup (C362)
    if (moonbeamMesh362) { group.remove(moonbeamMesh362); (moonbeamMesh362.geometry as BufferGeometry).dispose(); moonbeamMesh362 = null; }
    if (moonbeamLight362) { group.remove(moonbeamLight362); moonbeamLight362.dispose(); moonbeamLight362 = null; }
    // Cloaked druid figures cleanup (C390)
    if (druidGroup390) { group.remove(druidGroup390); druidGroup390.traverse(c => { const cm = c as Mesh; if (cm.geometry) cm.geometry.dispose(); if (cm.material) { if (Array.isArray(cm.material)) cm.material.forEach(mt => mt.dispose()); else (cm.material as MeshStandardMaterial).dispose(); } }); druidGroup390 = null; }
    druidArmLeft390 = null;
    druidArmRight390 = null;
    // Crow on dolmen cleanup (C358)
    if (crowGroup358) { group.remove(crowGroup358); crowGroup358.traverse(c => { if ((c as Mesh).geometry) (c as Mesh).geometry.dispose(); }); crowGroup358 = null; }
    crowWings358 = [];
    if (crowWingMat358) { crowWingMat358.dispose(); crowWingMat358 = null; }
    _spiritBeams.length = 0;
    _spiritLights.length = 0;
    // Ancient tomb entrance cleanup (C378)
    if (tombGroup378) { group.remove(tombGroup378); tombGroup378.traverse(c => { const cm = c as Mesh; if (cm.geometry) cm.geometry.dispose(); if (cm.material) { if (Array.isArray(cm.material)) cm.material.forEach(mt => mt.dispose()); else cm.material.dispose(); } }); tombGroup378 = null; }
    if (tombGlowLight378) { tombGlowLight378.dispose(); tombGlowLight378 = null; }
    // Stone labyrinth ruins cleanup (C403)
    if (labyrinthGroup403) {
      labyrinthGroup403.traverse(c => {
        if (c instanceof Mesh) { c.geometry.dispose(); if (Array.isArray(c.material)) c.material.forEach(m => m.dispose()); else c.material.dispose(); }
        if (c instanceof PointLight) c.dispose();
      });
      labyrinthGroup403 = null;
    }
    // Central altar ritual fire cleanup (C407)
    if (altarFireGroup407) {
      altarFireGroup407.traverse(c => {
        if (c instanceof Mesh) { c.geometry.dispose(); if (Array.isArray(c.material)) c.material.forEach(m => m.dispose()); else c.material.dispose(); }
        if (c instanceof PointLight) c.dispose();
      });
      altarEmbers407.length = 0;
      altarEmberVel407.length = 0;
      altarFireCone407 = null;
      altarFireLight407 = null;
      altarFireGroup407 = null;
    }
    // Soaring eagle cleanup (C412)
    if (eagleGroup412) {
      eagleGroup412.traverse(c => {
        if (c instanceof Mesh) { c.geometry.dispose(); if (Array.isArray(c.material)) c.material.forEach(m => m.dispose()); else c.material.dispose(); }
      });
      group.remove(eagleGroup412);
      eagleWingL412 = null;
      eagleWingR412 = null;
      eagleGroup412 = null;
    }
    // Carved menhir cleanup (C417)
    if (menhirGroup417) {
      menhirGroup417.traverse(c => {
        if (c instanceof Mesh) { c.geometry.dispose(); if (Array.isArray(c.material)) c.material.forEach(m => m.dispose()); else c.material.dispose(); }
        if (c instanceof PointLight) c.dispose();
      });
      group.remove(menhirGroup417);
      menhirCarveGlows417.length = 0;
      menhirLight417 = null;
      menhirGroup417 = null;
    }
    // Rotting swamp dock cleanup (C422)
    if (swampDockGroup422) {
      swampDockGroup422.traverse(c => {
        if (c instanceof Mesh) { c.geometry.dispose(); if (Array.isArray(c.material)) c.material.forEach(m => m.dispose()); else c.material.dispose(); }
        if (c instanceof PointLight) c.dispose();
      });
      group.remove(swampDockGroup422);
      swampDockAlgae422.length = 0;
      swampDockLight422 = null;
      swampDockGroup422 = null;
    }
    // Spectral ghost apparition cleanup (C425)
    if (ghostGroup425) {
      ghostGroup425.traverse(c => {
        if (c instanceof Mesh) { c.geometry.dispose(); if (Array.isArray(c.material)) c.material.forEach(m => m.dispose()); else c.material.dispose(); }
        if (c instanceof PointLight) c.dispose();
      });
      group.remove(ghostGroup425);
      ghostBody425 = null; ghostHead425 = null; ghostLight425 = null;
      ghostGroup425 = null;
    }
    // Stone sundial cleanup (C429)
    if (sundialGroup429) {
      sundialGroup429.traverse(c => {
        if (c instanceof Mesh) { c.geometry.dispose(); if (Array.isArray(c.material)) c.material.forEach(m => m.dispose()); else c.material.dispose(); }
        if (c instanceof PointLight) c.dispose();
      });
      group.remove(sundialGroup429);
      sundialShadow429 = null;
      sundialLight429 = null;
      sundialGroup429 = null;
    }
    // Moonrise arc cleanup (C433)
    if (stoneMoonGroup433) {
      stoneMoonGroup433.traverse(c => {
        if (c instanceof Mesh) { c.geometry.dispose(); if (Array.isArray(c.material)) c.material.forEach(m => m.dispose()); else c.material.dispose(); }
        if (c instanceof PointLight) c.dispose();
      });
      group.remove(stoneMoonGroup433);
      stoneMoonMesh433 = null;
      stoneMoonLight433 = null;
      stoneMoonGroup433 = null;
    }
    // Harvest scarecrow cleanup (C382)
    if (scarecrowGroup382) { group.remove(scarecrowGroup382); scarecrowGroup382.traverse(c => { const cm = c as Mesh; if (cm.geometry) cm.geometry.dispose(); if (cm.material) { if (Array.isArray(cm.material)) cm.material.forEach(mt => mt.dispose()); else cm.material.dispose(); } }); scarecrowGroup382 = null; }
    scarecrowEyes382 = [];
    // Ignis fatuus wisp procession cleanup (C386)
    if (ignisFatuusGroup386) { group.remove(ignisFatuusGroup386); ignisFatuusGroup386.traverse(c => { const cm = c as Mesh; if (cm.geometry) cm.geometry.dispose(); if (cm.material) { if (Array.isArray(cm.material)) cm.material.forEach(mt => mt.dispose()); else cm.material.dispose(); } }); ignisFatuusGroup386 = null; }
    ignisMeshes386 = [];
    ignisLights386 = [];
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
