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
  ConeGeometry, CylinderGeometry, DodecahedronGeometry, Fog, Group, HemisphereLight,
  InstancedMesh, Mesh, MeshStandardMaterial, Object3D, PlaneGeometry,
  PointLight, Points, PointsMaterial, SphereGeometry, Vector3,
} from 'three';

import type { BiomeSceneResult } from './CoastBiome';

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
    ambientColor: 0x080808, keyColor: 0xe8c84c, rimColor: 0xaa9030,
    particleColor: 0xe8c84c,
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
    ambientColor: 0x100c06, keyColor: 0xd4aa44, rimColor: 0x988830,
    particleColor: 0xd4aa44,
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
  }

  // Vallee anciens: ruined hut silhouettes with warm glow
  if (biome === 'vallee_anciens') {
    const hutMat = new MeshStandardMaterial({ color: 0x4a3018, roughness: 0.9, metalness: 0.0, flatShading: true });
    const roofMat = new MeshStandardMaterial({ color: 0x6a4820, roughness: 0.85, metalness: 0.0, flatShading: true, emissive: 0xd4aa44, emissiveIntensity: 0.08 });
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
  }

  // Cercles de Pierres: Neolithic standing stone ring (7 stones in a circle)
  if (biome === 'cercles_pierres') {
    const R2 = () => Math.random();
    const stoneMat = new MeshStandardMaterial({
      color: 0x6a5e48, roughness: 0.90, metalness: 0.0, flatShading: true,
      emissive: 0x221810, emissiveIntensity: 0.06,
    });
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
    // Central altar flat stone
    const altarMat = new MeshStandardMaterial({
      color: 0x8a7a5e, roughness: 0.85, metalness: 0.0, flatShading: true,
      emissive: 0x33ff66, emissiveIntensity: 0.04,
    });
    const altar = new Mesh(new BoxGeometry(2.0, 0.25, 1.0), altarMat);
    altar.position.set(0, -0.62, -15);
    group.add(altar);
    // Two altar uprights
    const upright1 = new Mesh(new BoxGeometry(0.25, 1.2, 0.25), stoneMat);
    upright1.position.set(-0.7, -0.25, -15);
    group.add(upright1);
    const upright2 = new Mesh(new BoxGeometry(0.25, 1.2, 0.25), stoneMat);
    upright2.position.set(0.7, -0.25, -15);
    group.add(upright2);
  }

  // Plaine des Druides: scattered ritual poles + central sacred fire
  if (biome === 'plaine_druides') {
    const R2 = () => Math.random();
    const poleMat = new MeshStandardMaterial({
      color: 0x3c2810, roughness: 0.98, metalness: 0.0, flatShading: true,
    });
    const totemMat = new MeshStandardMaterial({
      color: 0x5a3818, roughness: 0.92, metalness: 0.0, flatShading: true,
      emissive: 0xcc4400, emissiveIntensity: 0.15,
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
  };

  const dispose = (): void => {
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
