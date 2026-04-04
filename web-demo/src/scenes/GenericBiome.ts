// =============================================================================
// GenericBiome — Parametric procedural scene for 6 non-dedicated biomes.
// Biomes: marais_korrigans, landes_bruyere, cercles_pierres, villages_celtes,
//         collines_dolmens, iles_mystiques.
// Each biome gets unique terrain color, fog, lighting, stone formations, and
// ambient particles — distinct atmospheres without duplicate scene files.
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
  // N64 Banjo-Kazooie vivid palette — bright, saturated, low-poly pop
  marais_korrigans: {
    fogColor: 0x4a8c3c, fogNear: 5, fogFar: 32,
    groundColor: 0x3a7228, skyTop: 0x1a6e48, skyMid: 0x4aaa5c,
    ambientColor: 0x306830, keyColor: 0x44ff88, rimColor: 0x22cc55,
    particleColor: 0x88ffaa,
    stoneDensity: 5, treeCount: 12, stoneType: 'menhir',
  },
  landes_bruyere: {
    fogColor: 0x8850b0, fogNear: 8, fogFar: 45,
    groundColor: 0x6a3888, skyTop: 0x4a2090, skyMid: 0x9050c0,
    ambientColor: 0x503080, keyColor: 0xcc66ff, rimColor: 0x8844cc,
    particleColor: 0xee99ff,
    stoneDensity: 8, treeCount: 4, stoneType: 'menhir',
  },
  cercles_pierres: {
    fogColor: 0x3050c0, fogNear: 10, fogFar: 50,
    groundColor: 0x405898, skyTop: 0x1030a0, skyMid: 0x4060d0,
    ambientColor: 0x283880, keyColor: 0x88aaff, rimColor: 0x4466dd,
    particleColor: 0xaaccff,
    stoneDensity: 12, treeCount: 0, stoneType: 'circle',
  },
  villages_celtes: {
    fogColor: 0xc07828, fogNear: 8, fogFar: 42,
    groundColor: 0xa06030, skyTop: 0x784020, skyMid: 0xc88040,
    ambientColor: 0x885030, keyColor: 0xffaa44, rimColor: 0xff6622,
    particleColor: 0xffdd88,
    stoneDensity: 4, treeCount: 18, stoneType: 'ruins',
  },
  collines_dolmens: {
    fogColor: 0x5aa040, fogNear: 6, fogFar: 36,
    groundColor: 0x4a8830, skyTop: 0x2a7050, skyMid: 0x5aa860,
    ambientColor: 0x3a6838, keyColor: 0x66dd44, rimColor: 0x44aa22,
    particleColor: 0xaaeebb,
    stoneDensity: 6, treeCount: 8, stoneType: 'dolmen',
  },
  iles_mystiques: {
    fogColor: 0x2888cc, fogNear: 5, fogFar: 28,
    groundColor: 0x306898, skyTop: 0x1050a0, skyMid: 0x3080c8,
    ambientColor: 0x206080, keyColor: 0x44ccff, rimColor: 0x2299ee,
    particleColor: 0x66eeff,
    stoneDensity: 7, treeCount: 6, stoneType: 'menhir',
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

  // Fog (applied via scene.fog in main.ts workaround — set on group userData for consumer)
  group.userData['fogColor'] = theme.fogColor;
  group.userData['fogNear'] = theme.fogNear;
  group.userData['fogFar'] = theme.fogFar;

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

  // Ambient particles
  const particles = createParticles(theme.particleColor, 60);
  group.add(particles.points);

  // Water plane for marais/iles biomes
  if (biome === 'marais_korrigans' || biome === 'iles_mystiques') {
    const waterMat = new MeshStandardMaterial({
      color: biome === 'iles_mystiques' ? 0x1488ee : 0x28c868,
      roughness: 0.1, metalness: 0.35,
      transparent: true, opacity: 0.75,
      emissive: biome === 'iles_mystiques' ? 0x0844aa : 0x106630,
      emissiveIntensity: 0.18,
      flatShading: true,
    });
    const water = new Mesh(new PlaneGeometry(160, 160, 18, 14), waterMat);
    water.rotation.x = -Math.PI / 2;
    water.position.y = -0.6;
    group.add(water);
  }

  // Landes bruyère: heather bushes (low purple blobs)
  if (biome === 'landes_bruyere') {
    const heatherMat = new MeshStandardMaterial({ color: 0xcc55ee, roughness: 0.9, metalness: 0.0, flatShading: true, emissive: 0x8822aa, emissiveIntensity: 0.12 });
    for (let i = 0; i < 30; i++) {
      const h = new Mesh(new SphereGeometry(0.3 + Math.random() * 0.4, 5, 4), heatherMat);
      h.scale.y = 0.35;
      h.position.set((Math.random() - 0.5) * 60, -0.75, -5 - Math.random() * 50);
      group.add(h);
    }
  }

  // Villages celtes: hut silhouettes
  if (biome === 'villages_celtes') {
    const hutMat = new MeshStandardMaterial({ color: 0x8a6040, roughness: 0.9, metalness: 0.0, flatShading: true });
    const roofMat = new MeshStandardMaterial({ color: 0xb08840, roughness: 0.85, metalness: 0.0, flatShading: true, emissive: 0x604820, emissiveIntensity: 0.12 });
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

  const update = (dt: number): void => {
    particles.update(dt);
    // Gentle key light flicker
    key.intensity = 1.9 + Math.sin(Date.now() * 0.002) * 0.15;
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
