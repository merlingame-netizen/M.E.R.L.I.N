// ═══════════════════════════════════════════════════════════════════════════════
// Coast Biome — ISO low-poly coastal scene (C161 visual overhaul)
// Reference: dramatic cliff + teal faceted ocean + layered flat-shaded clouds.
// ═══════════════════════════════════════════════════════════════════════════════

import {
  AmbientLight, BackSide, BoxGeometry, BufferAttribute, Color,
  ConeGeometry, CylinderGeometry, DirectionalLight,
  DodecahedronGeometry, Group, HemisphereLight,
  Material, Mesh, MeshStandardMaterial, PlaneGeometry, SphereGeometry,
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
    color: 0xb89e58, // C163: N64 sandy-golden cliff path
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
    colors[i * 3 + 0] = 0.047 + depth * 0.031;
    colors[i * 3 + 1] = 0.353 + depth * 0.557;
    colors[i * 3 + 2] = 0.722 + depth * 0.094;
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

// ── Export interface ──────────────────────────────────────────────────────────

export interface BiomeSceneResult {
  readonly group: Group;
  readonly update: (dt: number) => void;
  readonly dispose: () => void;
}

// ── Main builder ──────────────────────────────────────────────────────────────

export async function buildCoastScene(): Promise<BiomeSceneResult> {
  const group = new Group();

  // C167: fog params for sceneManager.updateFog() — matches sky horizon vertex colour
  // (0.471, 0.769, 0.941) = 0x78c4f0; light coastal sea-haze, density kept low.
  (group as typeof group & { fogColor: number; fogDensity: number }).fogColor   = 0x78c4f0;
  (group as typeof group & { fogColor: number; fogDensity: number }).fogDensity = 0.010;

  // ── C163: N64 bright coastal lighting — warm golden sun + vivid sky hemisphere ──
  group.add(new AmbientLight(0x5090b8, 0.65));

  const isLowEndMobile = /Android|iPhone|iPad|iPod/i.test(navigator.userAgent) && window.devicePixelRatio >= 2;
  const sun = new DirectionalLight(0xffe888, 2.2); // C163: warm N64 golden sun
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
  group.add(new HemisphereLight(0x78c4f0, 0x6a8840, 0.60));

  // Ocean fill from sea side — vivid cyan
  const rim = new DirectionalLight(0x40c8e8, 0.55);
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
    group.clear();
  };

  return { group, update, dispose };
}
