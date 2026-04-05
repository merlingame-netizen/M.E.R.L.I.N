// ═══════════════════════════════════════════════════════════════════════════════
// Forêt de Brocéliande — Mystical Celtic forest walk scene
// Dense oak canopy, ground fog, will-o'-wisp particles, standing stones.
// Optimised: same patterns as CoastBiome (alt-frame ocean → alt-frame wisps).
// ═══════════════════════════════════════════════════════════════════════════════

import {
  AmbientLight, BackSide, BoxGeometry, BufferAttribute, BufferGeometry,
  CircleGeometry, Color, ConeGeometry, CylinderGeometry, DirectionalLight, DodecahedronGeometry,
  DoubleSide, Float32BufferAttribute, FogExp2, FrontSide, Group, HemisphereLight, Line,
  LineBasicMaterial, Material,
  Mesh, MeshBasicMaterial, MeshStandardMaterial, PlaneGeometry, Points, PointLight,
  PointsMaterial, RingGeometry, ShaderMaterial, SphereGeometry, TorusGeometry, Vector3,
} from 'three';

import type { BiomeSceneResult } from './CoastBiome';
import { loadGLB } from '../engine/AssetLoader';

// ── Helpers ───────────────────────────────────────────────────────────────────

const R = (): number => Math.random();

// ── Ground ────────────────────────────────────────────────────────────────────

function createForestGround(): Mesh {
  const geo = new PlaneGeometry(200, 200, 52, 52);
  const pos = geo.attributes['position'] as BufferAttribute;
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i);
    const z = pos.getY(i);
    const h =
      Math.sin(x * 0.07 + 0.5) * 0.6 +
      Math.cos(z * 0.09 + 1.2) * 0.4 +
      Math.sin(x * 0.22 + z * 0.18) * 0.2 +
      R() * 0.15;
    pos.setZ(i, h);
  }
  geo.computeVertexNormals();
  const mat = new MeshStandardMaterial({
    color: 0x2e7a18,      // C163: N64 vivid grass-green forest floor
    roughness: 0.98,
    metalness: 0.0,
    flatShading: true,
  });
  const mesh = new Mesh(geo, mat);
  mesh.rotation.x = -Math.PI / 2;
  mesh.receiveShadow = true;
  return mesh;
}

// ── Sky dome (flat-shaded vertex-colored sphere + animated BoxGeometry cloud slabs) ──
// C162: replace smooth ShaderMaterial gradient with ISO low-poly consistent style.
// Vertex color: near-black zenith → dark forest-green horizon. 3 animated cloud bands.

interface ForestCloudLayer { group: Group; speed: number; }
interface ForestSkyResult { skyGroup: Group; cloudLayers: ForestCloudLayer[]; }

function createForestSky(): ForestSkyResult {
  const skyGroup = new Group();
  const cloudLayers: ForestCloudLayer[] = [];

  // Vertex-colored SphereGeometry — BackSide so camera is inside
  const geo = new SphereGeometry(160, 16, 12);
  const pos = geo.attributes['position'] as BufferAttribute;
  const cols = new Float32Array(pos.count * 3);
  for (let i = 0; i < pos.count; i++) {
    const y = pos.getY(i);
    const t = Math.max(0, Math.min(1, (y + 160) / 320)); // 0=bottom 1=top
    // C163: N64 vivid forest night sky — rich blue-indigo
    // horizon (t=0): 0x2848b8 = (0.157, 0.282, 0.722) vivid deep blue-violet horizon
    // zenith  (t=1): 0x0c1858 = (0.047, 0.094, 0.345) deep blue zenith
    cols[i * 3 + 0] = 0.157 - t * 0.110;
    cols[i * 3 + 1] = 0.282 - t * 0.188;
    cols[i * 3 + 2] = 0.722 - t * 0.377;
  }
  geo.setAttribute('color', new BufferAttribute(cols, 3));
  const skyMat = new MeshStandardMaterial({
    vertexColors: true, flatShading: true, roughness: 1.0, metalness: 0.0, side: BackSide,
  });
  skyGroup.add(new Mesh(geo, skyMat));

  // Helper: create one animated cloud band and add to skyGroup
  const addLayer = (
    yBase: number, zRange: [number, number], slabCount: number,
    speed: number, colors: number[], wRange: [number, number],
  ): void => {
    const g = new Group();
    for (let i = 0; i < slabCount; i++) {
      const color = colors[i % colors.length]!;
      const w = wRange[0] + R() * (wRange[1] - wRange[0]);
      const cloudGeo = new BoxGeometry(w, 1.2 + R() * 1.4, 0.35 + R() * 0.25);
      const cloudMat = new MeshStandardMaterial({ color, flatShading: true, roughness: 1.0, metalness: 0.0 });
      const mesh = new Mesh(cloudGeo, cloudMat);
      mesh.position.set(-90 + R() * 180, yBase + R() * 10, zRange[0] + R() * (zRange[1] - zRange[0]));
      mesh.rotation.y = (R() - 0.5) * 0.4;
      g.add(mesh);
    }
    skyGroup.add(g);
    cloudLayers.push({ group: g, speed });
  };

  // C163: N64 enchanted forest clouds — visible blue-grey/violet cloud bands
  // High band — dark blue-grey clouds
  addLayer(55, [-90, -35], 16, 0.7, [0x182850, 0x1e3060, 0x142048], [12, 24]);
  // Mid canopy band — medium blue-indigo
  addLayer(38, [-70, -20], 14, 1.3, [0x243860, 0x2a4070, 0x1e3258], [8, 18]);
  // Low horizon wisps — lighter mist-blue
  addLayer(22, [-55, -8],  12, 2.1, [0x304878, 0x385080, 0x2c4470], [6, 14]);

  return { skyGroup, cloudLayers };
}

// ── Dense forest trees ────────────────────────────────────────────────────────
// Brocéliande uses broad oak-style trees (sphere crown + trunk) not conifers.

function createForestTrees(): Group {
  const group = new Group();

  const layers: Array<{
    count: number; minR: number; maxR: number;
    crownColor: number; trunkColor: number;
    scaleBase: number; scaleVar: number; heightBase: number;
  }> = [
    // C163: N64 vivid forest trees — Banjo-Kazooie style bright greens
    // Near corridor — flanks the rail path
    { count: 20, minR: 4, maxR: 14, crownColor: 0x2e8a1e, trunkColor: 0x5a3010, scaleBase: 1.1, scaleVar: 0.6, heightBase: 3.5 },
    // Mid distance
    { count: 28, minR: 14, maxR: 30, crownColor: 0x247218, trunkColor: 0x482808, scaleBase: 0.85, scaleVar: 0.4, heightBase: 3.0 },
    // Far silhouette layer — darker but still visible
    { count: 24, minR: 30, maxR: 60, crownColor: 0x1a5010, trunkColor: 0x301a04, scaleBase: 0.65, scaleVar: 0.3, heightBase: 2.5 },
  ];

  for (const layer of layers) {
    const trunkMat = new MeshStandardMaterial({ color: layer.trunkColor, roughness: 0.98, flatShading: true });

    for (let i = 0; i < layer.count; i++) {
      const tree = new Group();
      const ht = layer.heightBase + R() * 1.8;
      const crownR = 1.4 + R() * 0.8;

      // Trunk
      const trunk = new Mesh(
        new CylinderGeometry(0.12, 0.22, ht, 5),
        trunkMat,
      );
      tree.add(trunk);

      // Crown — dual sphere for more oak-like silhouette
      const crownMat = new MeshStandardMaterial({
        color: layer.crownColor,
        roughness: 0.95,
        flatShading: true,
      });
      const crown1 = new Mesh(new SphereGeometry(crownR, 5, 4), crownMat);
      crown1.position.y = ht * 0.5 + crownR * 0.6;
      tree.add(crown1);

      // Secondary crown bump for organic look
      const crown2 = new Mesh(new SphereGeometry(crownR * 0.7, 4, 3), crownMat);
      crown2.position.set(
        (R() - 0.5) * crownR,
        ht * 0.5 + crownR * 1.0,
        (R() - 0.5) * crownR * 0.5,
      );
      tree.add(crown2);

      const angle = R() * Math.PI * 2;
      const radius = layer.minR + R() * (layer.maxR - layer.minR);
      // Position along corridor Z axis (path goes in -Z direction)
      tree.position.set(
        Math.cos(angle) * radius,
        0,
        Math.sin(angle) * radius - 15,
      );
      tree.scale.setScalar(layer.scaleBase + R() * layer.scaleVar);
      tree.rotation.y = R() * Math.PI * 2;
      tree.rotation.z = (R() - 0.5) * 0.06;
      tree.castShadow = true;
      group.add(tree);
    }
  }
  return group;
}

// ── Forest floor vegetation (ferns, bushes) ───────────────────────────────────

function createUndergrowth(): Group {
  const group = new Group();
  const fernMat  = new MeshStandardMaterial({ color: 0x2d5c1e, roughness: 0.98, flatShading: true });
  const bushMat  = new MeshStandardMaterial({ color: 0x244018, roughness: 0.98, flatShading: true });

  // Ferns — flat splayed cones
  for (let i = 0; i < 40; i++) {
    const fern = new Mesh(new ConeGeometry(0.5 + R() * 0.6, 0.4, 5), fernMat);
    const angle = R() * Math.PI * 2;
    const r = 3 + R() * 28;
    fern.position.set(Math.cos(angle) * r - 5, 0.1, Math.sin(angle) * r - 20);
    fern.rotation.y = R() * Math.PI;
    group.add(fern);
  }

  // Low bushes
  for (let i = 0; i < 25; i++) {
    const bush = new Mesh(new SphereGeometry(0.35 + R() * 0.5, 4, 3), bushMat);
    const angle = R() * Math.PI * 2;
    const r = 4 + R() * 22;
    bush.position.set(Math.cos(angle) * r - 4, 0.2, Math.sin(angle) * r - 18);
    group.add(bush);
  }
  return group;
}

// ── Menhirs — standing stones partially swallowed by forest ──────────────────

interface ForestMenhirResult { group: Group; menhirLights: PointLight[]; }

function createForestMenhirs(): ForestMenhirResult {
  const group = new Group();
  const menhirLights: PointLight[] = [];
  const stoneMat = new MeshStandardMaterial({
    color: 0x5a5040, roughness: 0.88, flatShading: true,
    emissive: 0x001a00, emissiveIntensity: 0.08,
  });
  const mossMat  = new MeshStandardMaterial({ color: 0x344e28, roughness: 0.98, flatShading: true });

  const positions: [number, number, number, number][] = [
    [ -8, 0, -12, 0.15],
    [  9, 0, -18, -0.08],
    [ -5, 0, -28,  0.12],
    [ 12, 0, -35, -0.05],
    [ -12, 0, -42, 0.20],
    [  6,  0, -52, -0.10],
    [ -4,  0, -60,  0.08],
  ];

  for (const [x, , z, lean] of positions) {
    const ht = 2.8 + R() * 2.4;
    const menhir = new Mesh(new BoxGeometry(0.6, ht, 0.4), stoneMat);
    menhir.castShadow = true;
    menhir.position.set(x, ht / 2, z);
    menhir.rotation.z = lean;
    menhir.rotation.y = R() * Math.PI;
    group.add(menhir);

    // Moss on base
    const moss = new Mesh(new BoxGeometry(0.7, 0.12, 0.5), mossMat);
    moss.position.set(x, 0.06, z);
    group.add(moss);

    // Ogham inscription — thin vertical lines on stone, glowing green runes
    const inscriptionMat = new MeshStandardMaterial({
      color: 0x001500, roughness: 0.99, flatShading: true,
      emissive: 0x00ff22, emissiveIntensity: 0.4,
    });
    for (let j = 0; j < 3; j++) {
      const line = new Mesh(new BoxGeometry(0.02, 0.25, 0.45), inscriptionMat);
      line.position.set(x + (j - 1) * 0.12, ht * 0.45 + j * 0.08, z);
      line.rotation.y = menhir.rotation.y;
      group.add(line);
    }

    // Druidic glow — faint green point light at menhir base
    const menhirLight = new PointLight(0x22ff44, 0.25, 5);
    menhirLight.position.set(x, 0.3, z);
    group.add(menhirLight);
    menhirLights.push(menhirLight);
  }
  return { group, menhirLights };
}

// ── Forest torch path lights ──────────────────────────────────────────────────
// 6 torch pillars evenly spaced along the Z path, alternating left/right.

interface TorchEntry { light: PointLight; phase: number; }
interface ForestTorchResult { group: Group; torchLights: TorchEntry[]; }

function createForestTorches(): ForestTorchResult {
  const group = new Group();
  const torchLights: TorchEntry[] = [];

  const poleMat    = new MeshStandardMaterial({ color: 0x4a2808, roughness: 0.98, flatShading: true });
  const bracketMat = new MeshStandardMaterial({ color: 0x2a2020, roughness: 0.90, flatShading: true });
  const flameMat   = new MeshStandardMaterial({
    color: 0xff6010, emissive: 0xff4000, emissiveIntensity: 1.2, flatShading: true,
  });

  const torchPositions: [number, number][] = [
    [-3, -8],
    [ 3, -18],
    [-3, -28],
    [ 3, -38],
    [-3, -48],
    [ 3, -58],
  ];

  for (let i = 0; i < torchPositions.length; i++) {
    const [x, z] = torchPositions[i]!;

    // Wooden pole — ground level, center at Y=1.0 so base sits at Y=0
    const pole = new Mesh(new CylinderGeometry(0.06, 0.08, 2.0, 5), poleMat);
    pole.position.set(x, 1.0, z);
    group.add(pole);

    // Iron bracket at top of pole
    const bracket = new Mesh(new BoxGeometry(0.04, 0.12, 0.04), bracketMat);
    bracket.position.set(x, 2.1, z);
    group.add(bracket);

    // Flame orb
    const flame = new Mesh(new SphereGeometry(0.12, 4, 3), flameMat);
    flame.position.set(x, 2.25, z);
    group.add(flame);

    // Point light attached to flame position
    const torchLight = new PointLight(0xff6010, 1.2, 10);
    torchLight.position.set(x, 2.25, z);
    group.add(torchLight);
    torchLights.push({ light: torchLight, phase: i * (Math.PI * 2 / torchPositions.length) });
  }

  return { group, torchLights };
}

// ── Roots & fallen logs ───────────────────────────────────────────────────────

function createForestDebris(): Group {
  const group = new Group();
  const logMat = new MeshStandardMaterial({ color: 0x3a2510, roughness: 0.98, flatShading: true });
  const rootMat = new MeshStandardMaterial({ color: 0x2a1a08, roughness: 0.99, flatShading: true });

  // Fallen logs
  for (let i = 0; i < 8; i++) {
    const len = 2.5 + R() * 3.5;
    const log = new Mesh(new CylinderGeometry(0.18, 0.22, len, 5), logMat);
    const angle = R() * Math.PI * 2;
    const r = 5 + R() * 18;
    log.position.set(Math.cos(angle) * r - 3, 0.15, Math.sin(angle) * r - 20);
    log.rotation.z = Math.PI / 2;
    log.rotation.y = R() * Math.PI;
    group.add(log);
  }

  // Exposed roots (thin bent cylinders)
  for (let i = 0; i < 12; i++) {
    const root = new Mesh(new CylinderGeometry(0.04, 0.07, 1.2 + R() * 1.0, 4), rootMat);
    const angle = R() * Math.PI * 2;
    const r = 3 + R() * 15;
    root.position.set(Math.cos(angle) * r - 4, 0.1, Math.sin(angle) * r - 18);
    root.rotation.z = (R() - 0.5) * 0.8;
    root.rotation.y = R() * Math.PI;
    group.add(root);
  }
  return group;
}

// ── Will-o'-wisp particles ────────────────────────────────────────────────────

// ── Falling leaf particles ─────────────────────────────────────────────��───────
// 50 tiny leaf fragments slowly drifting down + gentle X/Z sway — N64 atmosphere bonus.

interface LeafData {
  x: number; z: number;
  y: number;       // current Y
  yStart: number;  // reset height
  fallSpeed: number;
  swayPhase: number; swayFreq: number; swayAmp: number;
}

function createLeafDrift(): { object: Points; update: (dt: number) => void } {
  const COUNT = 50;
  const positions = new Float32Array(COUNT * 3);
  const colors    = new Float32Array(COUNT * 3);
  const leafData: LeafData[] = [];

  // Palette: dark greens + faded golds (fallen leaves)
  const palette = [
    [0.18, 0.48, 0.12],  // dark green
    [0.24, 0.55, 0.16],  // medium green
    [0.55, 0.50, 0.12],  // yellow-green
    [0.45, 0.32, 0.08],  // golden brown (dead leaf)
  ];

  for (let i = 0; i < COUNT; i++) {
    const angle = R() * Math.PI * 2;
    const r = 3 + R() * 32;
    const x = Math.cos(angle) * r - 5;
    const z = Math.sin(angle) * r - 20;
    const yStart = 8 + R() * 12;
    const y = R() * yStart; // staggered start heights

    leafData.push({
      x, z, y, yStart,
      fallSpeed: 0.35 + R() * 0.8,
      swayPhase: R() * Math.PI * 2,
      swayFreq: 0.6 + R() * 0.8,
      swayAmp: 0.3 + R() * 0.7,
    });

    positions[i * 3]     = x;
    positions[i * 3 + 1] = y;
    positions[i * 3 + 2] = z;

    const col = palette[i % palette.length]!;
    colors[i * 3]     = col[0]!;
    colors[i * 3 + 1] = col[1]!;
    colors[i * 3 + 2] = col[2]!;
  }

  const geo = new BufferGeometry();
  geo.setAttribute('position', new Float32BufferAttribute(positions, 3));
  geo.setAttribute('color', new Float32BufferAttribute(colors, 3));

  const mat = new PointsMaterial({
    size: 0.08,
    vertexColors: true,
    transparent: true,
    opacity: 0.60,
    sizeAttenuation: true,
  });

  const object = new Points(geo, mat);
  let elapsed = 0;

  const update = (dt: number): void => {
    elapsed += dt;
    const posAttr = geo.attributes['position'] as BufferAttribute;
    const arr = posAttr.array as Float32Array;

    for (let i = 0; i < COUNT; i++) {
      const d = leafData[i]!;
      d.y -= d.fallSpeed * dt;
      if (d.y < 0) {
        d.y = d.yStart; // reset to top
      }
      const sway = Math.sin(elapsed * d.swayFreq + d.swayPhase) * d.swayAmp;
      arr[i * 3]     = d.x + sway;
      arr[i * 3 + 1] = d.y;
      arr[i * 3 + 2] = d.z + Math.cos(elapsed * d.swayFreq * 0.7 + d.swayPhase) * d.swayAmp * 0.5;
    }
    posAttr.needsUpdate = true;
  };

  return { object, update };
}

interface WispData {
  baseX: number;
  baseY: number;
  baseZ: number;
  phase: number;
  speed: number;
  radius: number;
}

function createWisps(): { object: Points; update: (dt: number) => void } {
  const COUNT = 60;
  const positions = new Float32Array(COUNT * 3);
  const colors    = new Float32Array(COUNT * 3);
  const wispData: WispData[] = [];

  // Color palette: pale green, blue-white, amber — Celtic spirit lights
  const palette = [
    [0.4, 1.0, 0.6],   // pale green
    [0.5, 0.8, 1.0],   // blue-white
    [1.0, 0.85, 0.4],  // amber gold
    [0.6, 1.0, 0.9],   // cyan-teal
  ];

  for (let i = 0; i < COUNT; i++) {
    const angle = R() * Math.PI * 2;
    const r = 3 + R() * 30;
    const bx = Math.cos(angle) * r - 5;
    const bz = Math.sin(angle) * r - 25;
    const by = 0.8 + R() * 4.0;

    wispData.push({ baseX: bx, baseY: by, baseZ: bz, phase: R() * Math.PI * 2, speed: 0.4 + R() * 0.8, radius: 0.3 + R() * 1.2 });

    positions[i * 3]     = bx;
    positions[i * 3 + 1] = by;
    positions[i * 3 + 2] = bz;

    const col = palette[i % palette.length]!;
    colors[i * 3]     = col[0]!;
    colors[i * 3 + 1] = col[1]!;
    colors[i * 3 + 2] = col[2]!;
  }

  const geo = new BufferGeometry();
  geo.setAttribute('position', new Float32BufferAttribute(positions, 3));
  geo.setAttribute('color', new Float32BufferAttribute(colors, 3));

  const mat = new PointsMaterial({
    size: 0.18,
    vertexColors: true,
    transparent: true,
    opacity: 0.72,
    sizeAttenuation: true,
  });

  const object = new Points(geo, mat);
  let elapsed = 0;
  let _altFrame = false;

  const update = (dt: number): void => {
    elapsed += dt;
    _altFrame = !_altFrame;
    // Alternate-frame update — wisps don't need per-frame precision
    if (_altFrame && dt <= 0.05) return;

    const posAttr = geo.attributes['position'] as BufferAttribute;
    const arr = posAttr.array as Float32Array;

    for (let i = 0; i < COUNT; i++) {
      const d = wispData[i]!;
      const t = elapsed * d.speed + d.phase;
      arr[i * 3]     = d.baseX + Math.sin(t * 1.1) * d.radius;
      arr[i * 3 + 1] = d.baseY + Math.sin(t * 0.7 + 1.2) * 0.6;
      arr[i * 3 + 2] = d.baseZ + Math.cos(t * 0.9) * d.radius;
    }
    posAttr.needsUpdate = true;
  };

  return { object, update };
}

// ── Ground fog (denser than coast) ────────────────────────────────────────────

function createForestFog(): Mesh {
  const geo = new PlaneGeometry(160, 160, 1, 1);
  const mat = new ShaderMaterial({
    uniforms: {
      uTime:     { value: 0 },
      uFogColor: { value: new Color(0x1a2e18) },  // dark green forest mist
      uDensity:  { value: 0.38 },                  // denser than coast (0.25)
    },
    vertexShader: `
      varying vec2 vUv;
      void main() {
        vUv = uv;
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
      }
    `,
    fragmentShader: `
      uniform float uTime;
      uniform vec3 uFogColor;
      uniform float uDensity;
      varying vec2 vUv;

      float noise(vec2 p, float t) {
        float tt = mod(t, 100.0);
        return sin(p.x * 1.4 + tt * 0.25) * cos(p.y * 1.9 + tt * 0.18);
      }

      void main() {
        vec2 p = vUv * 7.0 - 3.5;
        float n = noise(p, uTime) * 0.5 + 0.5;
        float dist = length(vUv - vec2(0.5));
        float edgeFade = smoothstep(0.5, 0.15, dist);
        float alpha = n * uDensity * edgeFade;
        gl_FragColor = vec4(uFogColor, alpha);
      }
    `,
    transparent: true,
    depthWrite: false,
    side: FrontSide,
  });
  const mesh = new Mesh(geo, mat);
  mesh.rotation.x = -Math.PI / 2;
  mesh.position.set(0, 0.6, -10);
  mesh.name = 'forest_fog_plane';
  return mesh;
}

// ── Canopy ray shafts (god rays from above) ───────────────────────────────────
// Semi-transparent cone volumes filtered down from canopy gaps.

function createCanopyRays(): Group {
  const group = new Group();
  const rayMat = new MeshBasicMaterial({
    color: 0x88bb66,
    transparent: true,
    opacity: 0.045,
    depthWrite: false,
  });

  const rayPositions: [number, number, number][] = [
    [-3, 10, -15],
    [ 6, 12, -28],
    [-8, 9,  -38],
    [ 4, 11, -52],
  ];

  for (const [x, y, z] of rayPositions) {
    const ht = 10 + R() * 5;
    const ray = new Mesh(new ConeGeometry(1.8 + R() * 0.8, ht, 6), rayMat.clone());
    ray.position.set(x, y - ht / 2, z);
    ray.rotation.z = (R() - 0.5) * 0.15;
    group.add(ray);
  }
  return group;
}

// ── Ground mist discs ─────────────────────────────────────────────────────────
// 9 low-lying fog patches along the rail path — ground-level atmosphere.

function createGroundMist(): Group {
  const group = new Group();
  const positions: [number, number, number][] = [
    [ 0,   0.1,  -8],
    [-4,   0.1, -14],
    [ 5,   0.1, -20],
    [-2,   0.1, -27],
    [ 6,   0.1, -35],
    [-5,   0.1, -42],
    [ 3,   0.1, -50],
    [-3,   0.1, -58],
    [ 0,   0.1, -65],
  ];

  for (const [x, y, z] of positions) {
    const radius = 2.5 + R() * 1.5;
    const geo = new CircleGeometry(radius, 8);
    const mat = new MeshBasicMaterial({
      color: 0x0a1a0a,
      transparent: true,
      opacity: 0.28 + R() * 0.08,
      depthWrite: false,
    });
    const disc = new Mesh(geo, mat);
    disc.rotation.x = -Math.PI / 2;
    disc.position.set(x + (R() - 0.5) * 2, y, z);
    group.add(disc);
  }
  return group;
}

// ── Volumetric light shaft ─────────────────────────────────────────────────────
// PointLight pulse + translucent cone volume simulating god rays from canopy.

interface VolumetricLightResult {
  lightGroup: Group;
  pointLight: PointLight;
}

function createVolumetricLight(): VolumetricLightResult {
  const lightGroup = new Group();

  // The animated point light
  const pointLight = new PointLight(0x33ff22, 0.8, 30, 1.5);
  pointLight.position.set(0, 12, -5);
  lightGroup.add(pointLight);

  // Visual cone volume (wide-top cone pointing down toward ground)
  const coneGeo = new CylinderGeometry(0.1, 1.5, 10, 8);
  const coneMat = new MeshBasicMaterial({
    color: 0x33ff22,
    transparent: true,
    opacity: 0.04,
    depthWrite: false,
    side: DoubleSide,
  });
  const cone = new Mesh(coneGeo, coneMat);
  // Cone origin is center; offset so wide end is near ground (y=7), narrow end at top (y=12)
  cone.position.set(0, 7, -5);
  lightGroup.add(cone);

  return { lightGroup, pointLight };
}

// ── Crow flock — animated silhouette birds in the canopy ─────────────────────

interface CrowState {
  phase: number;
  speed: number;
  dir: 1 | -1;
  restTimer: number;
}

interface CrowFlockResult {
  crows: Group[];
  crowMats: MeshBasicMaterial[];
  update: (t: number, dt: number) => void;
}

function createCrowFlock(): CrowFlockResult {
  const crows: Group[] = [];
  const crowMats: MeshBasicMaterial[] = [];
  const states: CrowState[] = [];

  const wingMat = new MeshBasicMaterial({ color: 0x080808, side: DoubleSide });
  crowMats.push(wingMat);

  const wingGeo = new PlaneGeometry(0.6, 0.25);

  for (let i = 0; i < 4; i++) {
    const crow = new Group();

    // Left wing — angled outward at +45°
    const leftWing = new Group();
    const lMesh = new Mesh(wingGeo, wingMat);
    lMesh.position.set(-0.3, 0, 0);
    leftWing.add(lMesh);
    leftWing.rotation.z = Math.PI / 4;
    crow.add(leftWing);

    // Right wing — angled outward at -45°
    const rightWing = new Group();
    const rMesh = new Mesh(wingGeo, wingMat);
    rMesh.position.set(0.3, 0, 0);
    rightWing.add(rMesh);
    rightWing.rotation.z = -Math.PI / 4;
    crow.add(rightWing);

    crow.position.set(
      -20 + R() * 40,
      8 + R() * 5,
      -5 - R() * 25,
    );

    const state: CrowState = {
      phase:     R() * Math.PI * 2,
      speed:     1.5 + R() * 1.0,
      dir:       (R() < 0.5 ? 1 : -1) as 1 | -1,
      restTimer: R() * 8,
    };
    states.push(state);
    crows.push(crow);
  }

  const update = (t: number, dt: number): void => {
    for (let i = 0; i < crows.length; i++) {
      const crow  = crows[i]!;
      const state = states[i]!;

      // Wing flap — left wing index 0, right wing index 1
      const leftWing  = crow.children[0]!;
      const rightWing = crow.children[1]!;
      leftWing.rotation.z  =  Math.PI / 4 + Math.sin(t * 6 + state.phase) * 0.6;
      rightWing.rotation.z = -Math.PI / 4 - Math.sin(t * 6 + state.phase) * 0.6;

      // Flight movement
      crow.position.x += state.dir * state.speed * dt;
      crow.position.y += Math.sin(t * 0.8 + state.phase) * 0.2 * dt;

      // Reset when crow exits view laterally
      if (Math.abs(crow.position.x) > 35) {
        crow.position.x  = -state.dir * (28 + R() * 6);
        crow.position.y  =  8 + R() * 5;
        crow.position.z  = -5 - R() * 25;
        state.phase      =  R() * Math.PI * 2;
        state.speed      =  1.5 + R() * 1.0;
      }
    }
  };

  return { crows, crowMats, update };
}

// ── Ancient stone column ruins ────────────────────────────────────────────────
// C246: 5 standing stones in slight arc at depth z=-41 to -45, plus a fallen lintel.

function createAncientRuins(): Group {
  const group = new Group();

  // Standing stone definitions: [radiusTop, radiusBottom, height, x, y, z, rotZ, color]
  const stones: [number, number, number, number, number, number, number, number][] = [
    [0.40, 0.50, 5.0, -12, -0.5, -42,  0.05, 0x2a3020],
    [0.35, 0.45, 6.5,  -6, -0.5, -44, -0.04, 0x1e2818],
    [0.45, 0.50, 4.0,   0, -0.5, -45,  0.00, 0x252f1c],
    [0.38, 0.48, 7.0,   6, -0.5, -43,  0.06, 0x2a3020],
    [0.30, 0.40, 3.5,  14, -0.5, -41, -0.08, 0x1e2818],
  ];

  for (const [rTop, rBot, ht, x, y, z, rz, col] of stones) {
    const geo = new CylinderGeometry(rTop, rBot, ht, 5);
    const mat = new MeshBasicMaterial({ color: col });
    const mesh = new Mesh(geo, mat);
    mesh.position.set(x, y + ht / 2, z);
    mesh.rotation.z = rz;
    group.add(mesh);
  }

  // Fallen lintel — ruined trilith crosspiece across stones 2 & 3
  const lintelGeo = new BoxGeometry(8, 0.4, 0.5);
  const lintelMat = new MeshBasicMaterial({ color: 0x252f1c });
  const lintel = new Mesh(lintelGeo, lintelMat);
  lintel.position.set(-3, 2.5, -43.5);
  group.add(lintel);

  return group;
}

// ── Celtic cross standing stone monument ─────────────────────────────────────
// C288: Single tall Celtic cross at forest edge — shaft, bar, ring, plinth.
// Position x=-20, z=-32 — clear of fairy ring (z=-18, x=5) and ruins (z=-41~-45, x=-12~+14).

function createCelticCross(): Group {
  const group = new Group();
  const CROSS_X = -20;
  const CROSS_Y_BASE = 0;
  const CROSS_Z = -32;
  const STONE_COLOR = 0x2a3020;

  // Vertical shaft: tall rectangular pillar
  const shaftGeo = new BoxGeometry(0.35, 4.5, 0.2);
  const shaftMat = new MeshBasicMaterial({ color: STONE_COLOR });
  const shaft = new Mesh(shaftGeo, shaftMat);
  shaft.position.set(CROSS_X, CROSS_Y_BASE + 2.25, CROSS_Z);
  group.add(shaft);

  // Horizontal bar: shorter piece at ~2/3 height
  const barGeo = new BoxGeometry(1.8, 0.35, 0.2);
  const barMat = new MeshBasicMaterial({ color: STONE_COLOR });
  const bar = new Mesh(barGeo, barMat);
  bar.position.set(CROSS_X, CROSS_Y_BASE + 3.0, CROSS_Z);
  group.add(bar);

  // Ring circle at intersection (TorusGeometry flat, facing forward)
  const ringGeo = new TorusGeometry(0.75, 0.12, 6, 16);
  const ringMat = new MeshBasicMaterial({ color: STONE_COLOR });
  const ring = new Mesh(ringGeo, ringMat);
  ring.position.set(CROSS_X, CROSS_Y_BASE + 3.0, CROSS_Z + 0.05);
  group.add(ring);

  // Base plinth
  const plinthGeo = new BoxGeometry(0.7, 0.3, 0.4);
  const plinthMat = new MeshBasicMaterial({ color: 0x1e2818 });
  const plinth = new Mesh(plinthGeo, plinthMat);
  plinth.position.set(CROSS_X, CROSS_Y_BASE + 0.15, CROSS_Z);
  group.add(plinth);

  return group;
}

// ── Dawn dew droplets — module-level time-of-day + droplet state ─────────────
// Outer-var pattern: assigned inside builder, animated in update closure.
let _forestTimeOfDay: 'day' | 'dawn' | 'dusk' | 'night' = 'day';
const _dewDroplets: Mesh[] = [];
const _dewLights: PointLight[] = [];

// ── Cycle-357: stone bridge over forest stream ────────────────────────────────
let bridgeGroup357: Group | null = null;
let streamMesh357: Mesh | null = null;
const streamLights357: PointLight[] = [];

// ── Cycle-363: carved runestone with glowing ogham inscription ────────────────
let runestoneGroup363: Group | null = null;
let runestoneCarvings363: Mesh | null = null;
let runestoneLight363: PointLight | null = null;
let runestoneRippleT363 = -1;
let runestoneNextRipple363 = 12.0;

// ── Cycle-375: forest deer silhouette grazing at forest edge ──────────────────
let deerGroup375: Group | null = null;
let deerHead375: Group | null = null;
let deerGrazeT375 = 0;
let deerAlertT375 = -1;
let deerNextAlert375 = 15.0;

// ── Cycle-383: phosphorescent mushroom ring in forest clearing ────────────────
let mushroomGroup383: Group | null = null;
let mushroomCaps383: Mesh[] = [];
let mushroomRingLight383: PointLight | null = null;

// ── Cycle-387: ancient hollow tree with pulsing magical interior ──────────────
let hollowTreeGroup387: Group | null = null;
let hollowTreeLight387: PointLight | null = null;
let hollowPulseT387 = -1;
let hollowNextPulse387 = 8.0;

// ── Cycle-392: ancient stone well with glowing magical water ──────────────────
let wellGroup392: Group | null = null;
let wellWater392: Mesh | null = null;
let wellLight392: PointLight | null = null;
let wellRippleT392 = -1;
let wellNextRipple392 = 12.0;

// ── Cycle-400: fairy lights string between trees ───────────────────────────────
let fairyLightsGroup: Group | null = null;
let fairyT = 0;
let _fairyBulbs: Mesh[] = [];
let _fairyPointLight: PointLight | null = null;

// ── Cycle-405: ground mist tendrils ────────────────────────────────────────────
let mistGroup405: Group | null = null;
const mistPlanes405: Mesh[] = [];
const mistBaseY405: number[] = [];
let mistT405 = 0;

// ── Cycle-410: waterfall cascade ───────────────────────────────────────────────
let waterfallGroup410: Group | null = null;
let waterfallT410 = 0;
const waterfallPlanes410: Mesh[] = [];

// ── Cycle-416: spring of visions ──────────────────────────────────────────────
let springGroup416: Group | null = null;
let springT416 = 0;
let springVisionTimer416 = 0;
let springVisionDur416 = 8 + Math.random() * 10;
let springWaterMesh416: Mesh | null = null;
let springGlowLight416: PointLight | null = null;

// ── Cycle-421: standing Celtic cross ──────────────────────────────────────────
let celticCrossGroup421: Group | null = null;

// ── Cycle-426: raven flock circling overhead ───────────────────────────────────
const ravenFlock426: Group[] = [];
const ravenT426: number[] = [];
const ravenWingL426: Mesh[] = [];
const ravenWingR426: Mesh[] = [];
let celticCrossT421 = 0;

// ── Cycle-430: druidic candle circle ──────────────────────────────────────────
let candleCircleGroup430: Group | null = null;
let candleT430 = 0;
const candleFlames430: Mesh[] = [];
let candleCenterLight430: PointLight | null = null;
const celticCrossGlows421: Mesh[] = [];
let celticCrossLight421: PointLight | null = null;

// ── Cycle-435: bard's harp leaning against oak ────────────────────────────────
let harpGroup435: Group | null = null;
let harpT435 = 0;
let harpVibrateTimer435 = 0;
let harpNextVibrate435 = 8 + Math.random() * 12;
let harpVibrating435 = false;
let harpVibrateDur435 = 0;
const harpStrings435: Line[] = [];
let harpLight435: PointLight | null = null;

// ── Cycle-439: glowing dragonfly swarm ───────────────────────────────────────
const dragonflySwarm439: Group[] = [];
const dragonflyT439: number[] = [];
const dragonflyWingPairs439: Mesh[][] = [];
let dragonflyCloudT439 = 0;

// ── Cycle-442: fairy mushroom ring ────────────────────────────────────────────
let mushroomRingGroup442: Group | null = null;
let mushroomT442: number = 0;
let mushroomCaps442: Mesh[] = [];
let mushroomWisp442: Mesh | null = null;
let wispT442: number = 0;

// ── Cycle-446: ancient stone wishing well with glowing water + vision ripples ─
let wellGroup446: Group | null = null;
let wellT446: number = 0;
let wellWaterMat446: MeshBasicMaterial | null = null;
let wellRippleTimer446: number = 10;

// ── Cycle-451: moonlit forest pool with lily pads and droplet ripple events ───
let poolGroup451: Group | null = null;
let poolT451: number = 0;
let poolWaterMat451: MeshBasicMaterial | null = null;
let poolRippleTimer451: number = 15;
const poolLilyPads451: Mesh[] = [];

// ── Cycle-456: ancient hollow oak tree with glowing heartwood interior ────────
let hollowOakGroup456: Group | null = null;
let hollowOakT456: number = 0;
let hollowOakInnerMat456: MeshBasicMaterial | null = null;
let hollowOakLight456: PointLight | null = null;

// ── Cycle-461: druidic burial mound (tumulus) with glowing dolmen entrance ────
let tumulus461: Group | null = null;
let tumulusT461: number = 0;
let tumulusGlowMat461: MeshBasicMaterial | null = null;
let tumulusLight461: PointLight | null = null;

// ── Main export ───────────────────────────────────────────────────────────────

export async function buildForestScene(): Promise<BiomeSceneResult> {
  const group = new Group();

  // Atmospheric fog (Three.js scene fog — applied by renderer)
  // Instanced on the group, picked up by SceneManager when scene.fog is set there.
  // We embed fog params in this group for SceneManager to detect.
  // C159: dark forest green fog — deep canopy atmosphere
  (group as Group & { fogColor?: number; fogDensity?: number }).fogColor   = 0x061206;
  (group as Group & { fogColor?: number; fogDensity?: number }).fogDensity = 0.022;

  // ── Lighting — dark enchanted forest ──────────────────────────────────────
  // C163: N64 enchanted forest lighting — vivid blue night + moonlight + warm firefly glow
  // 1. Bright ambient — N64 forests are always visible, even at night
  const ambient = new AmbientLight(0x141828, 0.30); // C168: very dark forest ambient
  group.add(ambient);

  // 2. Moon / diffuse overhead — vivid blue-white N64 moonlight
  const moonLight = new DirectionalLight(0x4060a0, 0.55); // C168: dim moon through clouds
  moonLight.position.set(5, 30, 10);
  group.add(moonLight);

  // 3. Hemisphere — vivid blue canopy sky / warm green soil
  const hemi = new HemisphereLight(0x101830, 0x0e1e08, 0.40); // C168: dark canopy hemisphere
  group.add(hemi);

  // 4. Accent — warm amber torch/firelight from deeper forest
  const accent = new DirectionalLight(0xcc6010, 0.50); // C168: warmer fire accent to contrast
  accent.position.set(-15, 4, -40);
  group.add(accent);

  // ── Scene geometry ─────────────────────────────────────────────────────────
  group.add(createForestGround());
  const { skyGroup, cloudLayers } = createForestSky();
  group.add(skyGroup);
  group.add(createForestTrees());
  group.add(createUndergrowth());
  const { group: menhirGroup, menhirLights } = createForestMenhirs();
  group.add(menhirGroup);
  const { group: torchGroup, torchLights } = createForestTorches();
  group.add(torchGroup);
  group.add(createForestDebris());
  group.add(createAncientRuins());
  group.add(createCelticCross());
  group.add(createCanopyRays());
  group.add(createGroundMist());

  const fog = createForestFog();
  group.add(fog);

  const wisps = createWisps();
  group.add(wisps.object);

  const leaves = createLeafDrift();
  group.add(leaves.object);

  const { lightGroup, pointLight: volLight } = createVolumetricLight();
  group.add(lightGroup);

  const crowFlock = createCrowFlock();
  for (const crow of crowFlock.crows) {
    group.add(crow);
  }

  // ── Mystical floating lantern — CeltOS-green glowing orb deep in the forest ──
  let _lanternMesh: Mesh | null = null;
  let _lanternLight: PointLight | null = null;
  let _lanternTime = 0;
  {
    const lanternGeo = new SphereGeometry(0.25, 8, 6);
    const lanternMat = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.9 });
    _lanternMesh = new Mesh(lanternGeo, lanternMat);
    _lanternMesh.position.set(-8, 2.5, -28);
    group.add(_lanternMesh);

    _lanternLight = new PointLight(0x33ff66, 0.8, 8);
    _lanternLight.position.set(-8, 2.5, -28);
    group.add(_lanternLight);

    const cageGeo = new TorusGeometry(0.3, 0.04, 4, 8);
    const cageMat = new MeshBasicMaterial({ color: 0x1a3010 });
    const cage = new Mesh(cageGeo, cageMat);
    cage.position.set(-8, 2.5, -28);
    cage.rotation.z = Math.PI / 2;
    group.add(cage);
    // Attach cage as child of lantern for synchronized bobbing
    _lanternMesh.add(cage);
    cage.position.set(0, 0, 0);
  }

  // ── Fairy ring of mushrooms — Celtic magical symbol on the forest floor ──────
  {
    const FAIRY_RING_RADIUS = 3;
    const FAIRY_RING_CENTER_X = 5;
    const FAIRY_RING_CENTER_Z = -18;

    // Ground glow disc — very faint green underneath the ring
    const glowGeo = new CircleGeometry(3.5, 16);
    const glowMat = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.04 });
    const glow = new Mesh(glowGeo, glowMat);
    glow.rotation.x = -Math.PI / 2;
    glow.position.set(FAIRY_RING_CENTER_X, 0.01, FAIRY_RING_CENTER_Z);
    group.add(glow);

    for (let i = 0; i < 9; i++) {
      const angle = (i / 9) * Math.PI * 2;
      const mx = FAIRY_RING_CENTER_X + Math.cos(angle) * FAIRY_RING_RADIUS;
      const mz = FAIRY_RING_CENTER_Z + Math.sin(angle) * FAIRY_RING_RADIUS;

      // Stem: thin cylinder, half-height above ground
      const stemGeo = new CylinderGeometry(0.04, 0.06, 0.25, 5);
      const stemMat = new MeshBasicMaterial({ color: 0xd4c8a0 });
      const stem = new Mesh(stemGeo, stemMat);
      stem.position.set(mx, 0.125, mz);
      group.add(stem);

      // Cap: partial sphere dome, flipped upward
      const capGeo = new SphereGeometry(0.12, 6, 4, 0, Math.PI * 2, 0, Math.PI * 0.55);
      const capColor = i % 3 === 0 ? 0x661a0a : i % 3 === 1 ? 0x8a3010 : 0xaa4418;
      const capMat = new MeshBasicMaterial({ color: capColor });
      const cap = new Mesh(capGeo, capMat);
      cap.position.set(mx, 0.25, mz);
      cap.rotation.x = Math.PI;
      group.add(cap);
    }
  }

  // ── Will-o'-wisp cluster — 3 orbiting CeltOS-green wisps near z=-22 ──────────
  const _wispMeshes: Mesh[] = [];
  const _wispLights: PointLight[] = [];
  {
    const CX = 12;
    const CY = 1.2;
    const CZ = -22;
    const wispParams: [number, number, number][] = [
      [1.5, 0.7, 0.0],
      [2.0, 1.0, 2.1],
      [2.5, 0.6, 4.2],
    ];
    for (const [radius, speed, phase] of wispParams) {
      const geo = new SphereGeometry(0.18, 6, 4);
      const mat = new MeshBasicMaterial({ color: 0x33ff66 });
      const mesh = new Mesh(geo, mat);
      mesh.position.set(
        CX + radius * Math.cos(phase),
        CY,
        CZ + radius * Math.sin(phase),
      );
      mesh.userData = { cx: CX, cy: CY, cz: CZ, radius, speed, phase };
      group.add(mesh);
      _wispMeshes.push(mesh);

      const light = new PointLight(0x33ff66, 0.4, 4);
      light.position.copy(mesh.position);
      group.add(light);
      _wispLights.push(light);
    }
  }

  // ── Ground mist layer — 3 large drifting planes close to ground (CeltOS charter) ──
  // Colors: 0x0a2010 family, opacity max 0.18. Slow lateral drift + breathing opacity.
  const _mistLayers: Mesh[] = [];
  const _mistBases: number[] = [0.12, 0.09, 0.07];
  {
    const mistDefs: [number, number, number, number, number, number, number][] = [
      // w,  d,   x,    y,     z,    color,      baseOpacity
      [40, 12,   0, 0.15, -20, 0x0a2010, 0.12],
      [35, 10,   0, 0.25, -25, 0x0d2515, 0.09],
      [30,  8,   0, 0.35, -15, 0x081808, 0.07],
    ];
    for (let i = 0; i < mistDefs.length; i++) {
      const [w, d, x, y, z, color, baseOpacity] = mistDefs[i]!;
      const geo = new PlaneGeometry(w, d);
      const mat = new MeshBasicMaterial({
        color,
        transparent: true,
        opacity: baseOpacity,
        depthWrite: false,
        side: DoubleSide,
      });
      const mesh = new Mesh(geo, mat);
      mesh.rotation.x = -Math.PI / 2;
      mesh.position.set(x, y, z);
      _mistLayers.push(mesh);
      _mistBases[i] = baseOpacity;
      group.add(mesh);
    }
  }

  // ── Rain drizzle — 80 thin pale blue-grey streaks falling through forest ─────
  const _rainMeshes: Mesh[] = [];
  let _rainTime = 0;
  {
    const rainGeo = new CylinderGeometry(0.01, 0.01, 0.3, 3);
    const rainMat = new MeshBasicMaterial({ color: 0xaabbcc, transparent: true, opacity: 0.25 });
    for (let i = 0; i < 80; i++) {
      const drop = new Mesh(rainGeo, rainMat);
      const startY = -2 + R() * 10;
      drop.position.set(
        -25 + R() * 50,
        startY,
        -35 + R() * 32,
      );
      drop.userData = { startY, speed: 4 + R() * 3, range: 10 };
      _rainMeshes.push(drop);
      group.add(drop);
    }
  }

  // ── Firefly swarm — 20 glowing CeltOS-green particles drifting through forest ─
  const _fireflyMeshes: Mesh[] = [];
  let _fireflyTime = 0;
  {
    const flyGeo = new SphereGeometry(0.06, 4, 3);
    for (let i = 0; i < 20; i++) {
      const flyMat = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.8 });
      const fly = new Mesh(flyGeo, flyMat);
      fly.position.set(
        -25 + R() * 50,
        0.5 + R() * 3.5,
        -30 + R() * 25,
      );
      fly.userData = {
        vx: (R() - 0.5) * 0.4,
        vy: (R() - 0.5) * 0.15,
        vz: (R() - 0.5) * 0.4,
        phase: R() * Math.PI * 2,
      };
      _fireflyMeshes.push(fly);
      group.add(fly);
    }
  }

  // ── Treant silhouette — looming living-tree creature deep in the background ───
  // CeltOS charter: ZERO amber/orange/yellow. Color 0x0c1a0c (very dark green).
  let _treantGroup: Group | null = null;
  const _treantEyeLights: PointLight[] = [];
  let _treantBody: Mesh | null = null;
  {
    const treantMat = new MeshBasicMaterial({ color: 0x0c1a0c });
    const tg = new Group();
    _treantGroup = tg;

    // Body trunk
    const bodyGeo = new CylinderGeometry(0.6, 1.0, 8.0, 6);
    const bodyMesh = new Mesh(bodyGeo, treantMat);
    bodyMesh.position.set(20, 4.0, -48);
    _treantBody = bodyMesh;
    tg.add(bodyMesh);

    // Left arm — thick branch extending up-left
    const lArmGeo = new CylinderGeometry(0.2, 0.4, 5.0, 5);
    const lArm = new Mesh(lArmGeo, treantMat);
    lArm.position.set(18, 6.5, -48);
    lArm.rotation.z = 0.9;
    lArm.rotation.y = 0.2;
    tg.add(lArm);

    // Right arm
    const rArmGeo = new CylinderGeometry(0.2, 0.4, 4.5, 5);
    const rArm = new Mesh(rArmGeo, treantMat);
    rArm.position.set(22.5, 6.0, -48);
    rArm.rotation.z = -0.8;
    rArm.rotation.y = -0.3;
    tg.add(rArm);

    // Head crown — slightly flattened sphere
    const crownGeo = new SphereGeometry(1.2, 6, 4);
    const crown = new Mesh(crownGeo, treantMat);
    crown.position.set(20, 8.8, -48);
    crown.scale.y = 0.7;
    tg.add(crown);

    // Root left — rising from ground
    const rootLGeo = new CylinderGeometry(0.15, 0.3, 2.5, 4);
    const rootL = new Mesh(rootLGeo, treantMat);
    rootL.position.set(18.5, -0.2, -48);
    rootL.rotation.z = 0.5;
    tg.add(rootL);

    // Root right
    const rootRGeo = new CylinderGeometry(0.15, 0.3, 2.2, 4);
    const rootR = new Mesh(rootRGeo, treantMat);
    rootR.position.set(21.5, -0.2, -48);
    rootR.rotation.z = -0.4;
    tg.add(rootR);

    // Sub-branches (4) branching from arm tips at various angles
    const subBranchDefs: [number, number, number, number, number, number, number][] = [
      // x,    y,    z,   rz,   ry,  rx
      [16.5, 8.2, -48, 1.2, 0.4, 0.1, 0],
      [15.8, 7.0, -48, 0.9, -0.3, 0.2, 0],
      [24.0, 8.0, -48, -1.1, -0.5, -0.1, 0],
      [23.2, 6.8, -48, -1.4, 0.3, 0.1, 0],
    ];
    const subGeo = new CylinderGeometry(0.06, 0.14, 2.0, 4);
    for (const [bx, by, bz, rz, ry, rx] of subBranchDefs) {
      const sub = new Mesh(subGeo, treantMat);
      sub.position.set(bx, by, bz);
      sub.rotation.z = rz;
      sub.rotation.y = ry;
      sub.rotation.x = rx;
      tg.add(sub);
    }

    // Two glowing eyes
    const eyeGeo = new SphereGeometry(0.08, 5, 4);
    const eyeMat = new MeshBasicMaterial({ color: 0x33ff66 });
    const eyePositions: [number, number, number][] = [
      [19.6, 8.6, -47.5],
      [20.4, 8.6, -47.5],
    ];
    for (let ei = 0; ei < eyePositions.length; ei++) {
      const [ex, ey, ez] = eyePositions[ei]!;
      const eye = new Mesh(eyeGeo, eyeMat);
      eye.position.set(ex, ey, ez);
      tg.add(eye);

      const eyeLight = new PointLight(0x33ff66, 0.2, 4);
      eyeLight.position.set(ex, ey, ez);
      tg.add(eyeLight);
      _treantEyeLights.push(eyeLight);
    }

    group.add(tg);
  }

  // ── Perched owl silhouettes — 2 owls watching from high branches ──────────────
  // CeltOS charter: ZERO amber/orange/yellow. Body 0x0c1a0c, eyes 0x33ff66.
  const _owlHeads: Mesh[] = [];
  const _owlEyeLights: PointLight[] = [];
  {
    const owlBodyMat  = new MeshBasicMaterial({ color: 0x0c1a0c });
    const owlEyeMat   = new MeshBasicMaterial({ color: 0x33ff66 });

    const buildOwl = (
      px: number, py: number, pz: number,
      scaleFactor: number,
      rotY: number,
      owlIndex: number,
    ): void => {
      const owlGroup = new Group();

      // Body — 6-sided cylinder
      const bodyGeo = new CylinderGeometry(0.12, 0.18, 0.42, 6);
      const body = new Mesh(bodyGeo, owlBodyMat);
      owlGroup.add(body);

      // Head — sphere atop body, slight forward tilt
      const headGeo = new SphereGeometry(0.15, 6, 4);
      const head = new Mesh(headGeo, owlBodyMat);
      head.position.set(0, 0.32, 0.02);
      head.rotation.x = 0.15;
      owlGroup.add(head);
      _owlHeads.push(head);

      // Ear tufts — small cones at top of head
      const tuftGeo = new ConeGeometry(0.04, 0.12, 3);
      const tuftL = new Mesh(tuftGeo, owlBodyMat);
      tuftL.position.set(-0.07, 0.46, 0.02);
      tuftL.rotation.z = -0.25;
      owlGroup.add(tuftL);

      const tuftR = new Mesh(tuftGeo, owlBodyMat);
      tuftR.position.set(0.07, 0.46, 0.02);
      tuftR.rotation.z = 0.25;
      owlGroup.add(tuftR);

      // Wings — boxes offset left/right with slight angle
      const wingGeo = new BoxGeometry(0.08, 0.28, 0.22);
      const wingL = new Mesh(wingGeo, owlBodyMat);
      wingL.position.set(-0.17, -0.02, 0);
      wingL.rotation.z = 0.12;
      wingL.userData = { side: 'L', owlIndex };
      owlGroup.add(wingL);

      const wingR = new Mesh(wingGeo, owlBodyMat);
      wingR.position.set(0.17, -0.02, 0);
      wingR.rotation.z = -0.12;
      wingR.userData = { side: 'R', owlIndex };
      owlGroup.add(wingR);

      // Glowing eyes — 2 small spheres
      const eyeGeo = new SphereGeometry(0.025, 4, 3);
      const eyeOffsets: [number, number, number][] = [
        [-0.055, 0.32, 0.13],
        [ 0.055, 0.32, 0.13],
      ];
      for (let ei = 0; ei < eyeOffsets.length; ei++) {
        const [ex, ey, ez] = eyeOffsets[ei]!;
        const eyeMesh = new Mesh(eyeGeo, owlEyeMat);
        eyeMesh.position.set(ex, ey, ez);
        owlGroup.add(eyeMesh);

        const eyeLight = new PointLight(0x33ff66, 0.08, 1.5);
        eyeLight.position.set(px + ex * scaleFactor, py + ey * scaleFactor, pz + ez * scaleFactor);
        group.add(eyeLight);
        _owlEyeLights.push(eyeLight);
      }

      owlGroup.position.set(px, py, pz);
      owlGroup.scale.setScalar(scaleFactor);
      owlGroup.rotation.y = rotY;
      group.add(owlGroup);
    };

    // Owl 1 — perched on branch at (-15, 4.5, -30)
    buildOwl(-15, 4.5, -30, 1.0, 0.3, 0);
    // Owl 2 — perched higher at (8, 6.0, -35), slightly smaller, rotated differently
    buildOwl(8, 6.0, -35, 0.85, -0.8, 1);
  }

  // ── Dawn dew droplets — 25 small spheres on near ground, visible only at dawn ──
  // CeltOS charter: color 0x0a2a1a (dark green-teal), sparkle 0x33ff66.
  // Scattered x=[-15,15] z=[-5,-20] y=0.04. Module-level arrays reused across runs.
  _dewDroplets.length = 0;
  _dewLights.length = 0;
  {
    const DEW_COUNT = 25;
    const dewGeo = new SphereGeometry(0.04, 4, 3);
    for (let i = 0; i < DEW_COUNT; i++) {
      const mat = new MeshBasicMaterial({
        color: 0x0a2a1a,
        transparent: true,
        opacity: 0,
      });
      const drop = new Mesh(dewGeo, mat);
      drop.position.set(
        -15 + R() * 30,
        0.04,
        -5 - R() * 15,
      );
      drop.visible = false;
      drop.userData = {
        phase: R() * Math.PI * 2,
        sparkleTimer: 2 + R() * 2,   // seconds until next sparkle
      };
      _dewDroplets.push(drop);
      group.add(drop);
    }

    // 4 subtle PointLights at dew cluster positions — dawn shimmer
    const lightPositions: [number, number, number][] = [
      [-10, 0.2, -8],
      [  5, 0.2, -12],
      [ -4, 0.2, -17],
      [ 11, 0.2, -6],
    ];
    for (let li = 0; li < lightPositions.length; li++) {
      const [lx, ly, lz] = lightPositions[li]!;
      const dewLight = new PointLight(0x33ff66, 0.0, 2);
      dewLight.position.set(lx, ly, lz);
      _dewLights.push(dewLight);
      group.add(dewLight);
    }
  }

  // ── Cycle-357: ancient stone bridge over glimmering forest stream ─────────────
  {
    bridgeGroup357 = new Group();
    const stoneMat357 = new MeshStandardMaterial({ color: 0x2a3a2a, roughness: 0.95, metalness: 0.0 });

    // Main deck — bridge spans x=-3..3, runs in x direction, z width 1.8
    const deckGeo = new BoxGeometry(6.2, 0.25, 1.8);
    const deck = new Mesh(deckGeo, stoneMat357);
    deck.position.set(0, 0.12, -12);
    bridgeGroup357.add(deck);

    // 3 arch blocks beneath the deck
    for (let i = 0; i < 3; i++) {
      const ax = (i - 1) * 1.8;
      const archGeo = new BoxGeometry(1.4, 0.4, 1.6);
      const arch = new Mesh(archGeo, stoneMat357);
      arch.position.set(ax, -0.15, -12);
      bridgeGroup357.add(arch);
    }

    // Parapets — low walls running along the length (x-axis), offset in z
    for (const pz of [-12 + 0.8, -12 - 0.8]) {
      const paraGeo = new BoxGeometry(6.2, 0.4, 0.22);
      const para = new Mesh(paraGeo, stoneMat357);
      para.position.set(0, 0.45, pz);
      bridgeGroup357.add(para);
    }

    // Stream water plane — animated PlaneGeometry beneath bridge
    const streamGeo = new PlaneGeometry(8, 4, 8, 4);
    streamGeo.rotateX(-Math.PI / 2);
    const streamMat357 = new MeshStandardMaterial({
      color: 0x0a2a0a,
      emissive: new Color(0x0d4420),
      emissiveIntensity: 0.12,
      transparent: true,
      opacity: 0.7,
      roughness: 0.3,
      metalness: 0.1,
    });
    streamMesh357 = new Mesh(streamGeo, streamMat357);
    streamMesh357.position.set(0, -0.3, -12);
    bridgeGroup357.add(streamMesh357);

    // Stream PointLights — faint green moonlit water glow
    for (const lx of [-1.5, 1.5]) {
      const sl = new PointLight(0x33ff66, 0.1, 3.5);
      sl.position.set(lx, -0.1, -12);
      bridgeGroup357.add(sl);
      streamLights357.push(sl);
    }

    group.add(bridgeGroup357);
  }

  // ── Cycle-363: carved runestone with pulsing ogham inscription ───────────────
  {
    runestoneGroup363 = new Group();

    // Stone slab
    const stoneMat363 = new MeshStandardMaterial({ color: 0x1a2a1a, roughness: 0.95, metalness: 0.0 });
    const slabGeo = new BoxGeometry(0.35, 1.8, 0.1);
    const slab = new Mesh(slabGeo, stoneMat363);
    slab.rotation.y = 0.3;
    runestoneGroup363.add(slab);

    // Carving overlay — same shape, slightly in front, emissive lines
    const carvingGeo = new PlaneGeometry(0.28, 1.65, 1, 8);
    const carvingMat = new MeshStandardMaterial({
      color: 0x0a1a0a,
      emissive: new Color(0x33ff66),
      emissiveIntensity: 0.10,
      transparent: true,
      opacity: 0.6,
      depthWrite: false,
    });
    runestoneCarvings363 = new Mesh(carvingGeo, carvingMat);
    runestoneCarvings363.position.set(0.02, 0, 0.06);
    runestoneCarvings363.rotation.y = 0.3;
    runestoneGroup363.add(runestoneCarvings363);

    // Point light
    runestoneLight363 = new PointLight(0x33ff66, 0.08, 2.5);
    runestoneLight363.position.set(0, 0.5, 0.4);
    runestoneGroup363.add(runestoneLight363);

    // Position: near path edge
    runestoneGroup363.position.set(5, 0, -8);
    group.add(runestoneGroup363);
  }

  // ── Cycle-375: forest deer silhouette grazing at forest edge ─────────────────
  {
    deerGroup375 = new Group();
    const bodyMat = new MeshStandardMaterial({ color: 0x071407, roughness: 0.95 });
    const antlerMat = new MeshStandardMaterial({ color: 0x0a1f0a, roughness: 0.95 });

    // Body
    const body = new Mesh(new BoxGeometry(0.6, 0.35, 1.0), bodyMat);
    body.position.y = 0.6;
    deerGroup375.add(body);

    // Neck
    const neck = new Mesh(new BoxGeometry(0.18, 0.35, 0.2), bodyMat);
    neck.position.set(0, 0.85, 0.35);
    neck.rotation.x = -0.3;
    deerGroup375.add(neck);

    // Head group (for grazing animation)
    deerHead375 = new Group();
    deerHead375.position.set(0, 1.0, 0.5);

    const head = new Mesh(new BoxGeometry(0.2, 0.2, 0.3), bodyMat);
    deerHead375.add(head);

    // Eyes
    const eyeMat = new MeshBasicMaterial({ color: 0x33ff66 });
    ([-0.08, 0.08] as number[]).forEach(ex => {
      const eye = new Mesh(new SphereGeometry(0.018, 4, 3), eyeMat);
      eye.position.set(ex, 0.04, 0.14);
      deerHead375!.add(eye);
    });

    // Antlers
    ([-0.07, 0.07] as number[]).forEach((ax, idx) => {
      const sign = idx === 0 ? -1 : 1;
      const antlerBase = new Mesh(new CylinderGeometry(0.015, 0.02, 0.25, 4), antlerMat);
      antlerBase.position.set(ax, 0.18, 0.0);
      antlerBase.rotation.z = ax * 0.3;
      const branch = new Mesh(new CylinderGeometry(0.01, 0.015, 0.15, 4), antlerMat);
      branch.position.set(ax * 0.6, 0.12, 0.04);
      branch.rotation.z = ax * 0.8;
      antlerBase.add(branch);
      deerHead375!.add(antlerBase);
      void sign;
    });

    deerGroup375.add(deerHead375);

    // Legs (4)
    ([ [-0.18, -0.22], [0.18, -0.22], [-0.18, 0.22], [0.18, 0.22] ] as [number, number][]).forEach(([lx, lz]) => {
      const leg = new Mesh(new BoxGeometry(0.1, 0.55, 0.1), bodyMat);
      leg.position.set(lx, 0.27, lz);
      deerGroup375!.add(leg);
    });

    deerGroup375.position.set(-8, 0, -14);
    deerGroup375.rotation.y = 0.5;
    group.add(deerGroup375);
  }

  // ── Cycle-383: phosphorescent mushroom ring in forest clearing ───────────────
  {
    mushroomGroup383 = new Group();
    const stemMat383 = new MeshStandardMaterial({ color: 0x0a1a0a, roughness: 0.9 });

    const SHROOM_COUNT = 11;
    const RING_RADIUS = 1.2;
    for (let i = 0; i < SHROOM_COUNT; i++) {
      const angle = (i / SHROOM_COUNT) * Math.PI * 2;
      const rx = Math.cos(angle) * RING_RADIUS;
      const rz = Math.sin(angle) * RING_RADIUS;
      const scale = 0.7 + R() * 0.6;

      // Stem
      const stemH = 0.15 * scale;
      const stem = new Mesh(new CylinderGeometry(0.025 * scale, 0.03 * scale, stemH, 5), stemMat383);
      stem.position.set(rx, stemH / 2, rz);
      mushroomGroup383.add(stem);

      // Cap
      const capGeo = new CylinderGeometry(0.1 * scale, 0.05 * scale, 0.06 * scale, 7);
      const capMat = new MeshStandardMaterial({
        color: 0x0d2a0d,
        emissive: new Color(0x0d4420),
        emissiveIntensity: 0.25,
        roughness: 0.8,
      });
      const cap = new Mesh(capGeo, capMat);
      cap.position.set(rx, stemH + 0.03 * scale, rz);
      cap.userData.phase = R() * Math.PI * 2;
      mushroomGroup383.add(cap);
      mushroomCaps383.push(cap);
    }

    // Ring ambient light
    mushroomRingLight383 = new PointLight(0x33ff66, 0.1, 4.0);
    mushroomGroup383.add(mushroomRingLight383);

    mushroomGroup383.position.set(3, 0, -16);
    group.add(mushroomGroup383);
  }

  // ── Cycle-387: ancient hollow tree with glowing magical interior ─────────────
  {
    hollowTreeGroup387 = new Group();
    const trunkMat387 = new MeshStandardMaterial({ color: 0x0a1a05, roughness: 0.95, metalness: 0.0 });

    // Main trunk (slightly tilted)
    const trunk1 = new Mesh(new CylinderGeometry(0.3, 0.45, 3.5, 7), trunkMat387);
    trunk1.position.y = 1.75;
    trunk1.rotation.z = 0.05;
    hollowTreeGroup387.add(trunk1);

    // Gnarled base bulge
    const base387 = new Mesh(new SphereGeometry(0.5, 8, 6), trunkMat387);
    base387.position.y = 0.2;
    base387.scale.set(1, 0.5, 1);
    hollowTreeGroup387.add(base387);

    // Major branch fork
    const branch1_387 = new Mesh(new CylinderGeometry(0.1, 0.2, 1.8, 5), trunkMat387);
    branch1_387.position.set(0.4, 2.8, 0);
    branch1_387.rotation.z = 0.5;
    hollowTreeGroup387.add(branch1_387);

    const branch2_387 = new Mesh(new CylinderGeometry(0.08, 0.15, 1.5, 5), trunkMat387);
    branch2_387.position.set(-0.35, 3.0, 0);
    branch2_387.rotation.z = -0.4;
    hollowTreeGroup387.add(branch2_387);

    // Hollow opening (dark plane suggesting interior)
    const hollowGeo387 = new CircleGeometry(0.2, 8);
    const hollowMat387 = new MeshBasicMaterial({ color: 0x010501, transparent: true, opacity: 0.92, depthWrite: false });
    const hollow387 = new Mesh(hollowGeo387, hollowMat387);
    hollow387.position.set(0.1, 0.5, 0.42);
    hollowTreeGroup387.add(hollow387);

    // Hollow glow light (inside trunk)
    hollowTreeLight387 = new PointLight(0x33ff66, 0.0, 2.0);
    hollowTreeLight387.position.set(0.1, 0.5, 0.0);
    hollowTreeGroup387.add(hollowTreeLight387);

    hollowTreeGroup387.position.set(-6, 0, -20);
    group.add(hollowTreeGroup387);
    hollowNextPulse387 = 8.0 + Math.random() * 5.0;
  }

  // ── Cycle-392: ancient stone well with glowing magical water ─────────────────
  {
    wellGroup392 = new Group();
    const stoneMat392 = new MeshStandardMaterial({ color: 0x1a2a1a, roughness: 0.95 });
    const woodMat392 = new MeshStandardMaterial({ color: 0x0a1a05, roughness: 0.9 });

    // Well wall (open ring)
    const wallGeo = new CylinderGeometry(0.5, 0.55, 0.5, 12, 1, true);
    const wall = new Mesh(wallGeo, stoneMat392);
    wall.position.y = 0.25;
    wellGroup392.add(wall);

    // Wall top ring
    const topRing = new Mesh(new TorusGeometry(0.52, 0.06, 6, 12), stoneMat392);
    topRing.rotation.x = Math.PI / 2;
    topRing.position.y = 0.52;
    wellGroup392.add(topRing);

    // Wall bottom ring
    const botRing = new Mesh(new TorusGeometry(0.52, 0.05, 6, 12), stoneMat392);
    botRing.rotation.x = Math.PI / 2;
    botRing.position.y = 0.02;
    wellGroup392.add(botRing);

    // Water surface
    const waterGeo = new CircleGeometry(0.45, 12);
    waterGeo.rotateX(-Math.PI / 2);
    const waterMat392 = new MeshStandardMaterial({
      color: 0x051505,
      emissive: new Color(0x0d4420),
      emissiveIntensity: 0.15,
      transparent: true,
      opacity: 0.75,
      roughness: 0.1,
      metalness: 0.3,
    });
    wellWater392 = new Mesh(waterGeo, waterMat392);
    wellWater392.position.y = 0.38;
    wellGroup392.add(wellWater392);

    // Beam crosspiece
    const beam = new Mesh(new BoxGeometry(0.08, 0.08, 1.3), woodMat392);
    beam.position.y = 0.85;
    beam.rotation.y = 0.4;
    wellGroup392.add(beam);

    // Two support posts
    ([-0.5, 0.5] as number[]).forEach(sx => {
      const post = new Mesh(new BoxGeometry(0.07, 0.5, 0.07), woodMat392);
      post.position.set(sx * Math.cos(0.4), 0.65, sx * Math.sin(0.4));
      wellGroup392!.add(post);
    });

    // Bucket (hanging from beam center)
    const bucketGeo = new CylinderGeometry(0.06, 0.05, 0.12, 6);
    const bucket = new Mesh(bucketGeo, woodMat392);
    bucket.position.y = 0.62;
    wellGroup392.add(bucket);

    // Water glow light
    wellLight392 = new PointLight(0x33ff66, 0.08, 2.5);
    wellLight392.position.y = 0.5;
    wellGroup392.add(wellLight392);

    wellGroup392.position.set(7, 0, -10);
    group.add(wellGroup392);
    wellNextRipple392 = 12.0 + Math.random() * 6.0;
  }

  // ── Cycle-400: fairy lights string between two trees ──────────────────────
  {
    fairyLightsGroup = new Group();

    // Catenary string: 20 points from (-3,2.5,-10) to (4,2.5,-10), droop at y=2.0
    const startX = -3; const endX = 4; const midY = 2.0; const stringY = 2.5; const stringZ = -10;
    const ptCount = 20;
    const positions = new Float32Array(ptCount * 3);
    for (let i = 0; i < ptCount; i++) {
      const t = i / (ptCount - 1);
      const x = startX + t * (endX - startX);
      // Parabolic droop: 0 at ends, max sag at middle
      const sag = 4 * (midY - stringY) * t * (1 - t);
      const y = stringY + sag;
      positions[i * 3 + 0] = x;
      positions[i * 3 + 1] = y;
      positions[i * 3 + 2] = stringZ;
    }
    const stringGeo = new BufferGeometry();
    stringGeo.setAttribute('position', new Float32BufferAttribute(positions, 3));
    const stringMat = new MeshBasicMaterial({ color: 0x0a2a14 });
    // Use LineSegments-compatible approach: Three.Line needs LineBasicMaterial
    // but we only have MeshBasicMaterial imported. Import Line via BufferGeometry trick:
    // Actually create a thin tube-like representation with Points for the wire visual,
    // and bulbs are the main visual element. Use Points for the wire.
    const wireMat = new PointsMaterial({ color: 0x0a2a14, size: 0.04 });
    const wire = new Points(stringGeo, wireMat);
    fairyLightsGroup.add(wire);
    stringMat.dispose(); // not used

    // 8 glowing bulbs evenly spaced along the catenary
    _fairyBulbs = [];
    const bulbGeo = new SphereGeometry(0.07, 4, 3);
    for (let i = 0; i < 8; i++) {
      const t = i / 7; // 0..1
      const x = startX + t * (endX - startX);
      const sag = 4 * (midY - stringY) * t * (1 - t);
      const y = stringY + sag;
      const bulbMat = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 1.0 });
      const bulb = new Mesh(bulbGeo, bulbMat);
      bulb.position.set(x, y, stringZ);
      fairyLightsGroup.add(bulb);
      _fairyBulbs.push(bulb);
    }

    // Point light at midpoint for ambient glow
    _fairyPointLight = new PointLight(0x33ff66, 0.15, 5.0);
    _fairyPointLight.position.set(0.5, midY, stringZ);
    fairyLightsGroup.add(_fairyPointLight);

    group.add(fairyLightsGroup);
  }

  // ── Cycle-405: ground mist tendrils ──────────────────────────────────────────
  {
    mistGroup405 = new Group();
    const mistPositions: [number, number, number][] = [
      [-6, 0, -8], [2, 0, -11], [-4, 0, -16],
      [7, 0, -13], [-2, 0, -19], [5, 0, -22],
    ];
    for (let i = 0; i < mistPositions.length; i++) {
      const [px, , pz] = mistPositions[i]!;
      const geo = new PlaneGeometry(0.4, 2.5);
      const mat = new MeshBasicMaterial({
        color: 0x0d2a14,
        transparent: true,
        opacity: 0.0,
        depthWrite: false,
        side: DoubleSide,
      });
      const plane = new Mesh(geo, mat);
      plane.position.set(px, -0.5, pz);
      plane.rotation.y = Math.random() * Math.PI * 2;
      mistBaseY405.push(-0.5);
      mistPlanes405.push(plane);
      mistGroup405.add(plane);
    }
    group.add(mistGroup405);
  }

  // ── Cycle-410: waterfall cascade at (-10, 0, -18) ────────────────────────────
  {
    waterfallGroup410 = new Group();

    // Rock ledge atop the falls
    const ledgeMat = new MeshBasicMaterial({ color: 0x0a1a10 });
    const ledge = new Mesh(new BoxGeometry(2.5, 0.5, 0.6), ledgeMat);
    ledge.position.set(0, 2.5, 0);
    waterfallGroup410.add(ledge);

    // Side walls
    for (const sx of [-1, 1]) {
      const side = new Mesh(new BoxGeometry(0.5, 3, 0.5), ledgeMat);
      side.position.set(sx, 1.2, 0);
      waterfallGroup410.add(side);
    }

    // 3 water cascade planes
    for (let pi = 0; pi < 3; pi++) {
      const planeGeo = new PlaneGeometry(0.5, 2.5, 2, 12);
      const planeMat = new MeshBasicMaterial({
        color: 0x0d2a14,
        transparent: true,
        opacity: 0.65,
        side: DoubleSide,
        depthWrite: false,
      });
      const plane = new Mesh(planeGeo, planeMat);
      plane.position.set(-0.6 + pi * 0.6, 1.25, 0.05);
      waterfallGroup410.add(plane);
      waterfallPlanes410.push(plane);
    }

    // Splash pool
    const poolGeo = new CircleGeometry(1.0, 12);
    const poolMat = new MeshBasicMaterial({
      color: 0x0a2a14,
      transparent: true,
      opacity: 0.7,
    });
    const pool = new Mesh(poolGeo, poolMat);
    pool.rotation.x = -Math.PI / 2;
    pool.position.set(0, 0.05, 0.3);
    waterfallGroup410.add(pool);

    // Pool glow
    const poolGlow = new PointLight(0x33ff66, 0.08, 3.5);
    poolGlow.position.set(0, 0.2, 0.3);
    waterfallGroup410.add(poolGlow);

    waterfallGroup410.position.set(-10, 0, -18);
    group.add(waterfallGroup410);
  }

  // ── Cycle-416: Spring of Visions at (8, 0, -25) ────────────────────────────
  {
    springGroup416 = new Group();

    // Basin rim
    const rimGeo = new TorusGeometry(1.1, 0.2, 6, 16);
    const rimMat = new MeshBasicMaterial({ color: 0x0a1a10 });
    const rim = new Mesh(rimGeo, rimMat);
    rim.position.set(0, 0.18, 0);
    springGroup416.add(rim);

    // Basin floor
    const floorGeo = new CylinderGeometry(0.9, 0.9, 0.25, 16);
    const floorMat = new MeshBasicMaterial({ color: 0x0a1a10 });
    const floor = new Mesh(floorGeo, floorMat);
    floor.position.set(0, 0.0, 0);
    springGroup416.add(floor);

    // 6 upright rim stones
    for (let si = 0; si < 6; si++) {
      const angle = (si / 6) * Math.PI * 2;
      const stoneGeo = new BoxGeometry(0.15, 0.35, 0.15);
      const stoneMat = new MeshBasicMaterial({ color: 0x0a1a10 });
      const stone = new Mesh(stoneGeo, stoneMat);
      stone.position.set(Math.cos(angle) * 1.1, 0.28, Math.sin(angle) * 1.1);
      springGroup416.add(stone);
    }

    // Water surface
    const waterGeo = new CircleGeometry(0.88, 20);
    const waterMat = new MeshBasicMaterial({ color: 0x0d3318, transparent: true, opacity: 0.85, depthWrite: false });
    springWaterMesh416 = new Mesh(waterGeo, waterMat);
    springWaterMesh416.rotation.x = -Math.PI / 2;
    springWaterMesh416.position.set(0, 0.22, 0);
    springGroup416.add(springWaterMesh416);

    // Pool glow light
    springGlowLight416 = new PointLight(0x33ff66, 0.2, 4.0);
    springGlowLight416.position.set(0, 0.5, 0);
    springGroup416.add(springGlowLight416);

    springGroup416.position.set(8, 0, -25);
    group.add(springGroup416);
  }

  // ── Cycle-421: standing Celtic cross at (0, 0, -28) ──────────────────────────
  {
    celticCrossGroup421 = new Group();
    const stoneMat421 = new MeshStandardMaterial({ color: 0x0a1a10, emissive: new Color(0x040a06), roughness: 0.95, metalness: 0.0 });

    // Base plinth
    const plinthMesh = new Mesh(new BoxGeometry(1.2, 0.4, 1.2), stoneMat421);
    plinthMesh.position.set(0, 0.2, 0);
    celticCrossGroup421.add(plinthMesh);

    // Vertical shaft
    const shaftMesh = new Mesh(new BoxGeometry(0.28, 3.8, 0.22), stoneMat421);
    shaftMesh.position.set(0, 2.3, 0);
    celticCrossGroup421.add(shaftMesh);

    // Horizontal arm
    const armMesh = new Mesh(new BoxGeometry(1.5, 0.26, 0.22), stoneMat421);
    armMesh.position.set(0, 3.4, 0);
    celticCrossGroup421.add(armMesh);

    // Ring (Celtic ring connector)
    const ringMesh = new Mesh(new TorusGeometry(0.38, 0.08, 6, 16), stoneMat421);
    ringMesh.position.set(0, 3.4, 0);
    ringMesh.rotation.x = Math.PI / 2;
    celticCrossGroup421.add(ringMesh);

    // Cross top
    const topMesh = new Mesh(new BoxGeometry(0.28, 0.5, 0.22), stoneMat421);
    topMesh.position.set(0, 4.35, 0);
    celticCrossGroup421.add(topMesh);

    // Knotwork glow overlays — 4 flat planes on shaft face
    const glowPositions421 = [0.8, 1.5, 2.2, 2.9];
    glowPositions421.forEach(y => {
      const g = new Mesh(
        new PlaneGeometry(0.22, 0.35),
        new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.2 }),
      );
      g.position.set(0, y, 0.12);
      celticCrossGlows421.push(g);
      celticCrossGroup421!.add(g);
    });

    // Ring glow: RingGeometry on ring face
    const ringGlow = new Mesh(
      new RingGeometry(0.22, 0.45, 16),
      new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.15 }),
    );
    ringGlow.position.set(0, 3.4, 0.12);
    celticCrossGlows421.push(ringGlow);
    celticCrossGroup421.add(ringGlow);

    // Moss patches at base
    const mossMat421 = new MeshBasicMaterial({ color: 0x0d2a14, transparent: true, opacity: 0.6 });
    const mossPositions421: [number, number, number][] = [[-0.3, 0.41, 0.2], [0.25, 0.41, -0.15], [-0.1, 0.41, -0.3]];
    mossPositions421.forEach(([mx, my, mz]) => {
      const moss = new Mesh(new PlaneGeometry(0.35, 0.25), mossMat421);
      moss.position.set(mx, my, mz);
      moss.rotation.x = -Math.PI / 2;
      celticCrossGroup421!.add(moss);
    });

    // Ambient glow light
    celticCrossLight421 = new PointLight(0x33ff66, 0.1, 4.5);
    celticCrossLight421.position.set(0, 2.5, 0.5);
    celticCrossGroup421.add(celticCrossLight421);

    celticCrossGroup421.position.set(0, 0, -28);
    group.add(celticCrossGroup421);
  }

  // ── Cycle-426: raven flock circling overhead ──────────────────────────────────
  {
    const bodyGeo = new BoxGeometry(0.12, 0.07, 0.28);
    const wingLGeo = new BoxGeometry(0.38, 0.03, 0.14);
    const wingRGeo = new BoxGeometry(0.38, 0.03, 0.14);
    const headGeo = new SphereGeometry(0.055, 4, 3);
    const tailGeo = new BoxGeometry(0.08, 0.03, 0.1);
    const ravenMat = new MeshBasicMaterial({ color: 0x0a1a10 });

    for (let i = 0; i < 6; i++) {
      const raven = new Group();

      const body = new Mesh(bodyGeo.clone(), ravenMat);
      raven.add(body);

      const wingL = new Mesh(wingLGeo.clone(), ravenMat);
      wingL.position.set(-0.25, 0, 0.02);
      raven.add(wingL);
      ravenWingL426.push(wingL);

      const wingR = new Mesh(wingRGeo.clone(), ravenMat);
      wingR.position.set(0.25, 0, 0.02);
      raven.add(wingR);
      ravenWingR426.push(wingR);

      const head = new Mesh(headGeo.clone(), ravenMat);
      head.position.set(0, 0.04, 0.14);
      raven.add(head);

      const tail = new Mesh(tailGeo.clone(), ravenMat);
      tail.position.set(0, -0.01, -0.16);
      raven.add(tail);

      ravenT426.push(i * 1.05);
      ravenFlock426.push(raven);
      group.add(raven);
    }
    // Dispose template geometries (each raven uses .clone())
    bodyGeo.dispose();
    wingLGeo.dispose();
    wingRGeo.dispose();
    headGeo.dispose();
    tailGeo.dispose();
    ravenMat.dispose();
  }

  // ── Cycle-430: druidic candle circle ──────────────────────────────────────────
  {
    candleCircleGroup430 = new Group();

    const NUM_CANDLES = 7;
    const CIRCLE_R = 0.9;
    const waxMat = new MeshBasicMaterial({ color: 0x0a1a10 });
    const flameMat = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.85 });

    for (let ci = 0; ci < NUM_CANDLES; ci++) {
      const angle = (ci / NUM_CANDLES) * Math.PI * 2;
      const cx = Math.cos(angle) * CIRCLE_R;
      const cz = Math.sin(angle) * CIRCLE_R;

      // Wax column
      const candleHeight = 0.18 + (ci % 3) * 0.06;
      const wax = new Mesh(new CylinderGeometry(0.025, 0.028, candleHeight, 6), waxMat);
      wax.position.set(cx, candleHeight / 2, cz);

      // Wick: tiny cylinder on top
      const wick = new Mesh(new CylinderGeometry(0.004, 0.004, 0.025, 4), waxMat);
      wick.position.set(cx, candleHeight + 0.012, cz);

      // Flame: small cone
      const flame = new Mesh(
        new ConeGeometry(0.022, 0.07, 5, 1, true),
        flameMat.clone(),
      );
      flame.position.set(cx, candleHeight + 0.055, cz);
      candleFlames430.push(flame);

      // Small flame glow: PointLight per candle every other candle to keep light count down
      if (ci % 2 === 0) {
        const candleLight = new PointLight(0x33ff66, 0.04, 1.5);
        candleLight.position.set(cx, candleHeight + 0.1, cz);
        candleCircleGroup430.add(candleLight);
      }

      candleCircleGroup430.add(wax, wick, flame);
    }

    // Central glyph: flat hexagonal plane on ground
    const glyphGeo = new CircleGeometry(0.5, 6);
    const glyphMat = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.08, depthWrite: false });
    const glyph = new Mesh(glyphGeo, glyphMat);
    glyph.rotation.x = -Math.PI / 2;
    glyph.position.set(0, 0.01, 0);
    candleCircleGroup430.add(glyph);

    // Central ambient light
    candleCenterLight430 = new PointLight(0x33ff66, 0.15, 3.5);
    candleCenterLight430.position.set(0, 0.5, 0);
    candleCircleGroup430.add(candleCenterLight430);

    candleCircleGroup430.position.set(4, 0, -20);
    group.add(candleCircleGroup430);

    waxMat.dispose();
    flameMat.dispose();
  }

  // ── Cycle-435: bard's harp leaning against oak ───────────────────────────────
  {
    harpGroup435 = new Group();

    const frameMat = new MeshBasicMaterial({ color: 0x0a1a10 });

    // Neck: curved arch — approximate with BoxGeometry + rotation
    const neck = new Mesh(new BoxGeometry(0.08, 1.6, 0.06), frameMat);
    neck.rotation.z = 0.25;
    neck.position.set(-0.3, 0.9, 0);

    // Column: vertical front pillar
    const column = new Mesh(new BoxGeometry(0.07, 1.3, 0.06), frameMat);
    column.position.set(0.1, 0.65, 0);

    // Soundboard: flat body
    const body = new Mesh(new BoxGeometry(0.55, 1.1, 0.04), frameMat);
    body.position.set(-0.1, 0.55, -0.05);

    // Base: foot
    const base = new Mesh(new BoxGeometry(0.5, 0.1, 0.18), frameMat);
    base.position.set(-0.1, 0.05, 0);

    // 8 harp strings (vertical lines from neck to base, fanning)
    const STRING_COUNT = 8;
    const stringMat = new LineBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.5 });
    for (let si = 0; si < STRING_COUNT; si++) {
      const t435 = si / (STRING_COUNT - 1);
      const topX = -0.25 + t435 * 0.33;
      const botX = -0.05 + t435 * 0.2;
      const topY = 1.5 - t435 * 0.35;
      const pts = [
        new Vector3(topX, topY, 0),
        new Vector3(botX, 0.12, 0),
      ];
      const strGeo = new BufferGeometry().setFromPoints(pts);
      const strLine = new Line(strGeo, stringMat.clone());
      harpStrings435.push(strLine);
      harpGroup435.add(strLine);
    }
    stringMat.dispose();

    // Decorative carved knot on neck top
    const knotGeo = new TorusGeometry(0.06, 0.018, 4, 8);
    const knot = new Mesh(knotGeo, frameMat.clone());
    knot.position.set(-0.35, 1.65, 0);

    // Glow light
    harpLight435 = new PointLight(0x33ff66, 0.06, 3.0);
    harpLight435.position.set(-0.1, 0.8, 0.2);

    harpGroup435.add(neck, column, body, base, knot, harpLight435);

    frameMat.dispose();

    // Lean harp against tree (tilt back)
    harpGroup435.rotation.z = 0.15;
    harpGroup435.position.set(-4, 0, -22);
    group.add(harpGroup435);
  }

  // ── Cycle-439: dragonfly swarm ────────────────────────────────────────────────
  {
    const NUM_DRAGONFLIES = 12;
    const SWARM_CENTER = new Vector3(5, 0, -16);

    const bodyMat439 = new MeshBasicMaterial({ color: 0x0d2a14 });
    const wingMat439 = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.55, side: DoubleSide });

    for (let di = 0; di < NUM_DRAGONFLIES; di++) {
      const dragonfly = new Group();

      // Body: tiny elongated box
      const body = new Mesh(new BoxGeometry(0.025, 0.025, 0.1), bodyMat439);
      dragonfly.add(body);

      // Wings: 2 flat ellipse-like planes (PlaneGeometry scaled)
      const wingPair: Mesh[] = [];
      const wingGeo = new PlaneGeometry(0.08, 0.035);

      const wingL = new Mesh(wingGeo, wingMat439.clone());
      wingL.position.set(-0.055, 0, 0.01);
      wingL.rotation.z = 0.3;
      wingPair.push(wingL);
      dragonfly.add(wingL);

      const wingR = new Mesh(wingGeo.clone(), wingMat439.clone());
      wingR.position.set(0.055, 0, 0.01);
      wingR.rotation.z = -0.3;
      wingPair.push(wingR);
      dragonfly.add(wingR);

      // Tail wings (smaller rear pair)
      const tailWingL = new Mesh(new PlaneGeometry(0.06, 0.025), wingMat439.clone());
      tailWingL.position.set(-0.045, 0, -0.04);
      tailWingL.rotation.z = 0.2;
      wingPair.push(tailWingL);
      dragonfly.add(tailWingL);

      const tailWingR = new Mesh(new PlaneGeometry(0.06, 0.025), wingMat439.clone());
      tailWingR.position.set(0.045, 0, -0.04);
      tailWingR.rotation.z = -0.2;
      wingPair.push(tailWingR);
      dragonfly.add(tailWingR);

      // Random starting position within swarm cloud
      const r = Math.random() * 3.0;
      const angle = Math.random() * Math.PI * 2;
      dragonfly.position.set(
        SWARM_CENTER.x + Math.cos(angle) * r,
        1.5 + Math.random() * 1.5,
        SWARM_CENTER.z + Math.sin(angle) * r,
      );

      dragonflySwarm439.push(dragonfly);
      dragonflyT439.push(Math.random() * Math.PI * 2);
      dragonflyWingPairs439.push(wingPair);
      group.add(dragonfly);
    }

    bodyMat439.dispose();
    wingMat439.dispose();
  }

  // ── Cycle-442: fairy mushroom ring ──────────────────────────────────────────
  {
    mushroomRingGroup442 = new Group();
    mushroomRingGroup442.position.set(-3, 0, -8);
    mushroomCaps442 = [];

    for (let i = 0; i < 9; i++) {
      const angle = i * Math.PI * 2 / 9;
      const rx = Math.cos(angle) * 1.2;
      const rz = Math.sin(angle) * 1.2;

      // Stem
      const stemGeo = new CylinderGeometry(0.04, 0.06, 0.3, 6);
      const stemMat = new MeshBasicMaterial({ color: 0x020f04 });
      const stem = new Mesh(stemGeo, stemMat);
      stem.position.set(rx, 0.15, rz);
      mushroomRingGroup442.add(stem);

      // Cap
      const capGeo = new SphereGeometry(0.14, 6, 4);
      const capMat = new MeshBasicMaterial({ color: 0x0d2a14, transparent: true, opacity: 0.9 });
      const cap = new Mesh(capGeo, capMat);
      cap.scale.y = 0.5;
      cap.position.set(rx, 0.38, rz);
      mushroomCaps442.push(cap);
      mushroomRingGroup442.add(cap);
    }

    // Wisp orb in center
    const wispGeo = new SphereGeometry(0.08, 6, 6);
    const wispMat = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.6 });
    mushroomWisp442 = new Mesh(wispGeo, wispMat);
    mushroomWisp442.position.set(0, 0.8, 0);
    mushroomRingGroup442.add(mushroomWisp442);

    // Center point light
    const wispLight442 = new PointLight(0x33ff66, 0.15, 3.5);
    wispLight442.position.set(0, 0.5, 0);
    mushroomRingGroup442.add(wispLight442);

    group.add(mushroomRingGroup442);
  }

  // ── Cycle-446: ancient stone wishing well ────────────────────────────────────
  {
    wellGroup446 = new Group();

    const stoneMat446 = new MeshBasicMaterial({ color: 0x0a1a10 });
    const topStoneMat446 = new MeshBasicMaterial({ color: 0x0d2a14 });
    const woodMat446 = new MeshBasicMaterial({ color: 0x020f04 });
    const ropeMat446 = new MeshBasicMaterial({ color: 0x0d2a14 });

    // Well wall — open cylinder
    const wall446 = new Mesh(new CylinderGeometry(0.5, 0.55, 0.8, 12, 1, true), stoneMat446);
    wall446.position.y = 0.4;
    wellGroup446.add(wall446);

    // Base ring at y=0
    const baseRing446 = new Mesh(new TorusGeometry(0.55, 0.06, 4, 12), stoneMat446);
    baseRing446.rotation.x = Math.PI / 2;
    baseRing446.position.y = 0;
    wellGroup446.add(baseRing446);

    // Top ring at y=0.8
    const topRing446 = new Mesh(new TorusGeometry(0.5, 0.05, 4, 12), topStoneMat446);
    topRing446.rotation.x = Math.PI / 2;
    topRing446.position.y = 0.8;
    wellGroup446.add(topRing446);

    // Water surface at y=0.3 inside well
    const waterGeo446 = new CylinderGeometry(0.44, 0.44, 0.04, 16);
    const waterMat446 = new MeshBasicMaterial({ color: 0x0a2a14, transparent: true, opacity: 0.7 });
    wellWaterMat446 = waterMat446;
    const water446 = new Mesh(waterGeo446, waterMat446);
    water446.position.y = 0.3;
    wellGroup446.add(water446);

    // Crossbeam at y=1.1 spanning well top
    const beam446 = new Mesh(new BoxGeometry(1.2, 0.08, 0.08), woodMat446);
    beam446.position.y = 1.1;
    wellGroup446.add(beam446);

    // Rope hanging from center crossbeam at y=0.8
    const rope446 = new Mesh(new CylinderGeometry(0.015, 0.015, 0.6, 4), ropeMat446);
    rope446.position.y = 0.8;
    wellGroup446.add(rope446);

    // Bucket at bottom of rope
    const bucket446 = new Mesh(new CylinderGeometry(0.06, 0.05, 0.1, 6), stoneMat446);
    bucket446.position.y = 0.5;
    wellGroup446.add(bucket446);

    // Glow point light at water level
    const glowLight446 = new PointLight(0x33ff66, 0.12, 2.5);
    glowLight446.position.y = 0.35;
    wellGroup446.add(glowLight446);

    wellGroup446.position.set(2, 0, -5);
    group.add(wellGroup446);
  }

  // ── Cycle-451: moonlit forest pool ───────────────────────────────────────────
  {
    poolGroup451 = new Group();
    poolGroup451.position.set(-4, 0, -12);

    // Pool bed (slightly sunken)
    const poolBed = new Mesh(
      new CylinderGeometry(1.8, 2.0, 0.15, 16),
      new MeshBasicMaterial({ color: 0x020f04 })
    );
    poolBed.position.y = -0.1;
    poolGroup451.add(poolBed);

    // Water surface
    const water451 = new Mesh(
      new CylinderGeometry(1.75, 1.75, 0.05, 20),
      new MeshBasicMaterial({ color: 0x0a2a14, transparent: true, opacity: 0.75 })
    );
    water451.position.y = 0.02;
    poolWaterMat451 = water451.material as MeshBasicMaterial;
    poolGroup451.add(water451);

    // 7 surrounding stones
    for (let i = 0; i < 7; i++) {
      const angle = (i / 7) * Math.PI * 2;
      const stone = new Mesh(
        new SphereGeometry(0.2 + Math.random() * 0.1, 5, 4),
        new MeshBasicMaterial({ color: 0x0a1a10 })
      );
      stone.position.set(Math.cos(angle) * 2.0, 0.05, Math.sin(angle) * 2.0);
      stone.scale.y = 0.6;
      poolGroup451.add(stone);
    }

    // 5 lily pads (flat discs)
    for (let i = 0; i < 5; i++) {
      const pad = new Mesh(
        new CylinderGeometry(0.18, 0.18, 0.02, 8),
        new MeshBasicMaterial({ color: 0x0d2a14, transparent: true, opacity: 0.85 })
      );
      const angle = (i / 5) * Math.PI * 2 + 0.3;
      const r = 0.5 + Math.random() * 0.8;
      pad.position.set(Math.cos(angle) * r, 0.05, Math.sin(angle) * r);
      poolGroup451.add(pad);
      poolLilyPads451.push(pad);
    }

    // Glow PointLight at pool center
    const poolLight451 = new PointLight(0x33ff66, 0.1, 4.0);
    poolLight451.position.y = 0.5;
    poolGroup451.add(poolLight451);

    group.add(poolGroup451);
  }

  // ── Cycle-456: ancient hollow oak tree ───────────────────────────────────────
  {
    hollowOakGroup456 = new Group();
    hollowOakGroup456.position.set(6, 0, -20);

    // Outer trunk (open-ended cylinder)
    const trunk = new Mesh(
      new CylinderGeometry(0.9, 1.1, 3.5, 10, 1, true),
      new MeshBasicMaterial({ color: 0x0a1a10, side: DoubleSide })
    );
    trunk.position.y = 1.75;
    hollowOakGroup456.add(trunk);

    // Inner hollow surface (slightly smaller, glowing)
    const inner = new Mesh(
      new CylinderGeometry(0.75, 0.9, 3.4, 10, 1, true),
      new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.15, side: DoubleSide })
    );
    inner.position.y = 1.75;
    hollowOakInnerMat456 = inner.material as MeshBasicMaterial;
    hollowOakGroup456.add(inner);

    // Floor disc inside hollow
    const floor = new Mesh(
      new CylinderGeometry(0.85, 0.85, 0.06, 10),
      new MeshBasicMaterial({ color: 0x0d2a14 })
    );
    floor.position.y = 0.04;
    hollowOakGroup456.add(floor);

    // 3 root buttresses radiating from base
    for (let i = 0; i < 3; i++) {
      const angle = (i / 3) * Math.PI * 2 + Math.PI * 0.2;
      const root = new Mesh(
        new BoxGeometry(0.25, 0.5, 1.2),
        new MeshBasicMaterial({ color: 0x020f04 })
      );
      root.position.set(Math.cos(angle) * 0.9, 0.2, Math.sin(angle) * 0.9);
      root.rotation.y = -angle;
      root.rotation.z = Math.PI * 0.08;
      hollowOakGroup456.add(root);
    }

    // Partial canopy suggestion: 2 branch stubs at top
    for (const side of [-1, 1]) {
      const branch = new Mesh(
        new CylinderGeometry(0.05, 0.1, 1.4, 5),
        new MeshBasicMaterial({ color: 0x0a1a10 })
      );
      branch.position.set(side * 0.5, 3.8, 0);
      branch.rotation.z = side * Math.PI * 0.25;
      hollowOakGroup456.add(branch);
    }

    // Inner PointLight
    hollowOakLight456 = new PointLight(0x33ff66, 0.4, 4.0);
    hollowOakLight456.position.y = 1.0;
    hollowOakGroup456.add(hollowOakLight456);

    group.add(hollowOakGroup456);
  }

  // ── Cycle-461: druidic burial mound (tumulus) with glowing dolmen entrance ──
  {
    tumulus461 = new Group();
    tumulus461.position.set(-8, 0, -18);

    // Earth mound: flattened hemisphere
    const mound = new Mesh(
      new SphereGeometry(2.0, 12, 8, 0, Math.PI * 2, 0, Math.PI * 0.5),
      new MeshBasicMaterial({ color: 0x020f04 })
    );
    mound.scale.y = 0.55;
    mound.position.y = 0.01;
    tumulus461.add(mound);

    // Ground cap (covers bottom of sphere)
    const groundCap = new Mesh(
      new CylinderGeometry(2.0, 2.0, 0.06, 12),
      new MeshBasicMaterial({ color: 0x010802 })
    );
    groundCap.position.y = 0.03;
    tumulus461.add(groundCap);

    // Dolmen entrance: left upright stone
    const leftUpright = new Mesh(
      new BoxGeometry(0.22, 1.0, 0.28),
      new MeshBasicMaterial({ color: 0x0a1a10 })
    );
    leftUpright.position.set(-0.42, 0.5, 1.92);
    tumulus461.add(leftUpright);

    // Dolmen entrance: right upright stone
    const rightUpright = new Mesh(
      new BoxGeometry(0.22, 1.0, 0.28),
      new MeshBasicMaterial({ color: 0x0a1a10 })
    );
    rightUpright.position.set(0.42, 0.5, 1.92);
    tumulus461.add(rightUpright);

    // Dolmen entrance: lintel
    const dolmenLintel = new Mesh(
      new BoxGeometry(1.1, 0.22, 0.32),
      new MeshBasicMaterial({ color: 0x0a1a10 })
    );
    dolmenLintel.position.set(0, 1.08, 1.92);
    tumulus461.add(dolmenLintel);

    // Dark passage floor inside entrance
    const passageFloor = new Mesh(
      new BoxGeometry(0.6, 0.04, 0.8),
      new MeshBasicMaterial({ color: 0x010802 })
    );
    passageFloor.position.set(0, 0.02, 1.7);
    tumulus461.add(passageFloor);

    // Glowing inner plane (visible through entrance gap)
    const innerGlow = new Mesh(
      new PlaneGeometry(0.55, 0.8),
      new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0.12 })
    );
    innerGlow.position.set(0, 0.5, 1.5);
    tumulusGlowMat461 = innerGlow.material as MeshBasicMaterial;
    tumulus461.add(innerGlow);

    // PointLight inside mound
    tumulusLight461 = new PointLight(0x33ff66, 0.18, 4.0);
    tumulusLight461.position.set(0, 0.5, 0.8);
    tumulus461.add(tumulusLight461);

    // 3 small stones scattered in front of entrance
    for (let i = 0; i < 3; i++) {
      const stone = new Mesh(
        new SphereGeometry(0.1 + Math.random() * 0.08, 5, 4),
        new MeshBasicMaterial({ color: 0x0a1a10 })
      );
      stone.scale.y = 0.5;
      stone.position.set(-0.5 + i * 0.5, 0.05, 2.3 + Math.random() * 0.3);
      tumulus461.add(stone);
    }

    group.add(tumulus461);
  }

  // Distant druid cabin (GLB) — deep forest at x=-8, z=-25
  loadGLB('/assets/cabin_unified.glb').then(gltf => {
    const cabin = gltf.scene.clone();
    cabin.position.set(-8, -1.0, -25);
    cabin.scale.setScalar(1.8);
    cabin.rotation.y = Math.PI * 0.15;
    // Apply forest tint — dark green emissive
    cabin.traverse(child => {
      if ((child as any).isMesh) {
        const mesh = child as import('three').Mesh;
        if (Array.isArray(mesh.material)) {
          mesh.material.forEach(m => {
            if ((m as any).isMeshStandardMaterial) {
              (m as import('three').MeshStandardMaterial).emissive?.setHex(0x001a00);
              (m as import('three').MeshStandardMaterial).emissiveIntensity = 0.05;
            }
          });
        } else if ((mesh.material as any).isMeshStandardMaterial) {
          (mesh.material as import('three').MeshStandardMaterial).emissive?.setHex(0x001a00);
          (mesh.material as import('three').MeshStandardMaterial).emissiveIntensity = 0.05;
        }
      }
    });
    group.add(cabin);
  }).catch(() => { /* GLB optional — forest works without it */ });

  // ── Animation state ────────────────────────────────────────────────────────
  let sceneTime = 0;

  const update = (dt: number): void => {
    sceneTime += dt;

    // Fog shader time
    const fogMat = fog.material as ShaderMaterial;
    fogMat.uniforms['uTime']!.value = sceneTime;

    // Will-o'-wisps orbit
    wisps.update(dt);

    // Falling leaf drift
    leaves.update(dt);

    // Volumetric light pulse — 3s period, intensity 0.6 ↔ 1.0
    volLight.intensity = 0.8 + Math.sin(sceneTime * (Math.PI * 2 / 3)) * 0.2;

    // Torch flicker — randomized amber fire
    for (const entry of torchLights) {
      entry.light.intensity = 1.2 + Math.sin(sceneTime * 8.0 + entry.phase) * 0.25 + (Math.random() - 0.5) * 0.08;
    }

    // Menhir pulse — slow druidic breathing
    for (let mi = 0; mi < menhirLights.length; mi++) {
      menhirLights[mi]!.intensity = 0.25 + Math.sin(sceneTime * 0.6 + mi * 0.9) * 0.12;
    }

    // C162: animated cloud drift — each band at different speed for parallax
    for (const layer of cloudLayers) {
      for (const child of layer.group.children) {
        child.position.x += layer.speed * dt;
        if (child.position.x > 110) child.position.x -= 220;
      }
    }

    // Crow flock flight
    crowFlock.update(sceneTime, dt);

    // Floating lantern bob + pulse
    _lanternTime += dt;
    if (_lanternMesh) {
      _lanternMesh.position.y = 2.5 + Math.sin(_lanternTime * 0.7) * 0.3;
      _lanternMesh.position.x = -8 + Math.sin(_lanternTime * 0.4) * 0.15;
      (_lanternMesh.material as MeshBasicMaterial).opacity = 0.7 + Math.sin(_lanternTime * 1.5) * 0.2;
    }
    if (_lanternLight) {
      _lanternLight.position.copy(_lanternMesh!.position);
      _lanternLight.intensity = 0.6 + Math.sin(_lanternTime * 1.5) * 0.2;
    }

    // Rain drizzle fall + subtle wind drift
    _rainTime += dt;
    for (const drop of _rainMeshes) {
      drop.position.y -= (drop.userData as { speed: number; startY: number; range: number }).speed * dt;
      drop.position.x += 0.5 * dt;
      if (drop.position.y < (drop.userData as { startY: number; range: number }).startY - (drop.userData as { range: number }).range) {
        drop.position.y = (drop.userData as { startY: number }).startY;
      }
      if (drop.position.x > 25) drop.position.x -= 50;
    }

    // Will-o'-wisp cluster — orbit + bob + pulse
    for (let wi = 0; wi < _wispMeshes.length; wi++) {
      const wm = _wispMeshes[wi]!;
      const wl = _wispLights[wi]!;
      const ud = wm.userData as { cx: number; cy: number; cz: number; radius: number; speed: number; phase: number };
      const wt = sceneTime * ud.speed + ud.phase;
      const wx = ud.cx + ud.radius * Math.cos(wt);
      const wy = ud.cy + Math.sin(sceneTime * 1.3 + ud.phase) * 0.4;
      const wz = ud.cz + ud.radius * Math.sin(wt);
      wm.position.set(wx, wy, wz);
      const ws = 0.9 + Math.sin(sceneTime * 1.5 + ud.phase) * 0.1;
      wm.scale.setScalar(ws);
      wl.position.set(wx, wy, wz);
      wl.intensity = 0.2 + Math.sin(sceneTime * 2.0 + ud.phase) * 0.2;
    }

    // Ground mist layer drift + opacity breathing
    if (_mistLayers[0]) _mistLayers[0].position.x = Math.sin(sceneTime * 0.06) * 4;
    if (_mistLayers[1]) _mistLayers[1].position.x = Math.cos(sceneTime * 0.08) * 3;
    if (_mistLayers[2]) _mistLayers[2].position.x = Math.sin(sceneTime * 0.05 + 1.2) * 5;
    for (let mi = 0; mi < _mistLayers.length; mi++) {
      const mmat = _mistLayers[mi]!.material as MeshBasicMaterial;
      mmat.opacity = _mistBases[mi]! + Math.sin(sceneTime * 0.12 + mi * 1.1) * 0.03;
    }

    // Treant — barely perceptible breath + eye pulse
    if (_treantBody) {
      _treantBody.scale.x = 1.0 + Math.sin(sceneTime * 0.15) * 0.01;
    }
    for (let ti = 0; ti < _treantEyeLights.length; ti++) {
      _treantEyeLights[ti]!.intensity = 0.12 + Math.sin(sceneTime * 0.4 + ti * 0.5) * 0.08;
    }

    // Owl head scan + wing rustle + eye pulse + occasional blink
    // _owlHeads: [owl0Head, owl1Head]  _owlEyeLights: [owl0eyeL, owl0eyeR, owl1eyeL, owl1eyeR]
    for (let oi = 0; oi < _owlHeads.length; oi++) {
      const head = _owlHeads[oi]!;
      // Slow head scan — different phase per owl
      head.rotation.y = Math.sin(sceneTime * 0.2 + oi * 1.5) * 0.4;

      // Wing micro-rustle — side stored in userData on wing children
      const owlGroup = head.parent;
      if (owlGroup) {
        for (const child of owlGroup.children) {
          const ud = child.userData as { side?: string };
          if (ud.side === 'L') {
            child.rotation.z = 0.12 + Math.sin(sceneTime * 0.15 + oi * 2.3) * 0.05;
          } else if (ud.side === 'R') {
            child.rotation.z = -0.12 - Math.sin(sceneTime * 0.15 + oi * 2.3) * 0.05;
          }
        }
      }

      // Eye pulse — 2 lights per owl
      for (let ei = 0; ei < 2; ei++) {
        const lightIdx = oi * 2 + ei;
        const eyeLight = _owlEyeLights[lightIdx];
        if (eyeLight) {
          // Occasional blink: every ~6s window offset per owl, eyes shut for 100ms
          const blinkCycle = (sceneTime + oi * 2.3) % 6.0;
          const blinking = blinkCycle < 0.1;
          eyeLight.intensity = blinking
            ? 0
            : 0.06 + Math.sin(sceneTime * 0.8 + ei * 1.5 + oi * 2.7) * 0.04;
        }
      }
    }

    // Firefly swarm drift + twinkle
    _fireflyTime += dt;
    for (const fly of _fireflyMeshes) {
      fly.position.x += (fly.userData as { vx: number; vy: number; vz: number; phase: number }).vx * dt;
      fly.position.y += (fly.userData as { vx: number; vy: number; vz: number; phase: number }).vy * dt;
      fly.position.z += (fly.userData as { vx: number; vy: number; vz: number; phase: number }).vz * dt;
      if (fly.position.x < -25 || fly.position.x > 25) (fly.userData as { vx: number }).vx *= -1;
      if (fly.position.y < 0.3  || fly.position.y > 5)  (fly.userData as { vy: number }).vy *= -1;
      if (fly.position.z < -32  || fly.position.z > -3)  (fly.userData as { vz: number }).vz *= -1;
      (fly.material as MeshBasicMaterial).opacity =
        0.4 + Math.sin(_fireflyTime * 3 + (fly.userData as { phase: number }).phase) * 0.4;
    }

    // Dawn dew droplets — glistening on ground surfaces, only visible at dawn
    const isDawn = _forestTimeOfDay === 'dawn';
    for (let di = 0; di < _dewDroplets.length; di++) {
      const drop = _dewDroplets[di]!;
      const ud = drop.userData as { phase: number; sparkleTimer: number };
      if (!isDawn) {
        drop.visible = false;
        (drop.material as MeshBasicMaterial).opacity = 0;
        continue;
      }
      drop.visible = true;
      // Countdown to next sparkle event
      ud.sparkleTimer -= dt;
      if (ud.sparkleTimer <= 0) {
        // Brief sparkle — opacity spike for 80 ms then normal return
        (drop.material as MeshBasicMaterial).opacity = 0.9;
        // Reset timer: next sparkle in 2-4 seconds (staggered)
        ud.sparkleTimer = 2 + R() * 2;
      } else if (ud.sparkleTimer <= 0.08) {
        // Still within sparkle window: hold high
        (drop.material as MeshBasicMaterial).opacity = 0.9;
      } else {
        // Normal glistening
        (drop.material as MeshBasicMaterial).opacity =
          0.4 + Math.sin(sceneTime * 2.0 + ud.phase) * 0.15;
      }
    }

    // Dew cluster lights — subtle dawn shimmer
    for (let li = 0; li < _dewLights.length; li++) {
      const dl = _dewLights[li]!;
      dl.intensity = isDawn
        ? 0.06 + Math.sin(sceneTime * 1.5 + li) * 0.03
        : 0;
    }

    // Cycle-357: stream shimmer + vertex wave + stream light pulse
    if (streamMesh357) {
      const shimmer = 0.08 + Math.sin(sceneTime * 1.2) * 0.04;
      (streamMesh357.material as MeshStandardMaterial).emissiveIntensity = shimmer;
      const posAttr = (streamMesh357.geometry as BufferGeometry).attributes['position'] as BufferAttribute;
      for (let i = 0; i < posAttr.count; i++) {
        const sx = posAttr.getX(i);
        const sz = posAttr.getZ(i);
        posAttr.setY(i, Math.sin(sx * 0.8 + sceneTime * 1.5) * 0.04 + Math.sin(sz * 1.2 + sceneTime) * 0.02);
      }
      posAttr.needsUpdate = true;
    }
    for (let si = 0; si < streamLights357.length; si++) {
      streamLights357[si]!.intensity = 0.08 + Math.sin(sceneTime * 0.9 + si * 1.3) * 0.04;
    }

    // Cycle-375: deer grazing animation
    if (deerHead375 && deerGroup375) {
      deerGrazeT375 += dt * 0.4;
      const graze = Math.sin(deerGrazeT375) * 0.5 + 0.5; // 0 to 1
      deerHead375.rotation.x = graze * 0.6; // nod forward to graze
      deerHead375.position.y = 1.0 - graze * 0.3;

      deerNextAlert375 -= dt;
      if (deerNextAlert375 <= 0 && deerAlertT375 < 0) {
        deerAlertT375 = 0;
        deerNextAlert375 = 12.0 + Math.random() * 8.0;
      }
      if (deerAlertT375 >= 0) {
        deerAlertT375 += dt;
        if (deerAlertT375 < 2.0) {
          deerHead375.rotation.x = -0.1; // head up
          deerHead375.position.y = 1.05;
        } else {
          deerAlertT375 = -1; // resume grazing
        }
      }

      deerGroup375.rotation.y = 0.5 + Math.sin(sceneTime * 0.1) * 0.03;
    }

    // Cycle-363: runestone carving pulse + ripple
    if (runestoneCarvings363) {
      const mat = runestoneCarvings363.material as MeshStandardMaterial;

      // Idle pulse
      mat.emissiveIntensity = 0.10 + Math.sin(sceneTime * 0.6) * 0.04;
      if (runestoneLight363) runestoneLight363.intensity = 0.08 + Math.sin(sceneTime * 0.6) * 0.04;

      // Ripple timer
      runestoneNextRipple363 -= dt;
      if (runestoneNextRipple363 <= 0 && runestoneRippleT363 < 0) {
        runestoneRippleT363 = 0;
        runestoneNextRipple363 = 12.0 + Math.random() * 4.0;
      }
      if (runestoneRippleT363 >= 0) {
        runestoneRippleT363 += dt;
        const progress = runestoneRippleT363 / 1.5;
        const brightness = Math.sin(Math.min(progress, 1.0) * Math.PI);
        mat.emissiveIntensity = 0.10 + brightness * 0.10;
        if (runestoneLight363) runestoneLight363.intensity = 0.08 + brightness * 0.06;
        if (runestoneRippleT363 >= 1.5) runestoneRippleT363 = -1;
      }
    }

    // Cycle-383: mushroom ring — independent cap glow pulse + ring light breathe
    if (mushroomCaps383.length > 0) {
      mushroomCaps383.forEach(cap => {
        const phase = cap.userData.phase as number;
        const glow = 0.22 + Math.sin(sceneTime * 0.8 + phase) * 0.12;
        (cap.material as MeshStandardMaterial).emissiveIntensity = glow;
      });
      if (mushroomRingLight383) {
        mushroomRingLight383.intensity = 0.08 + Math.sin(sceneTime * 0.3) * 0.04;
      }
    }

    // Cycle-387: hollow tree — ambient faint glow + occasional pulse event
    if (hollowTreeLight387) {
      // Ambient faint glow
      hollowTreeLight387.intensity = 0.03 + Math.sin(sceneTime * 0.5) * 0.02;

      // Pulse event countdown
      hollowNextPulse387 -= dt;
      if (hollowNextPulse387 <= 0 && hollowPulseT387 < 0) {
        hollowPulseT387 = 0;
        hollowNextPulse387 = 8.0 + Math.random() * 5.0;
      }
      if (hollowPulseT387 >= 0) {
        hollowPulseT387 += dt;
        if (hollowPulseT387 < 0.4) {
          hollowTreeLight387.intensity = 0.03 + (hollowPulseT387 / 0.4) * 0.12;
        } else if (hollowPulseT387 < 1.0) {
          hollowTreeLight387.intensity = 0.15 - ((hollowPulseT387 - 0.4) / 0.6) * 0.12;
        } else {
          hollowPulseT387 = -1;
        }
      }
    }

    // Cycle-392: stone well — water shimmer + ripple event
    if (wellWater392 && wellLight392) {
      const mat392 = wellWater392.material as MeshStandardMaterial;
      mat392.emissiveIntensity = 0.12 + Math.sin(sceneTime * 0.8) * 0.05;
      wellLight392.intensity = 0.06 + Math.sin(sceneTime * 0.6) * 0.03;

      wellNextRipple392 -= dt;
      if (wellNextRipple392 <= 0 && wellRippleT392 < 0) {
        wellRippleT392 = 0;
        wellNextRipple392 = 12.0 + Math.random() * 6.0;
      }
      if (wellRippleT392 >= 0) {
        wellRippleT392 += dt;
        if (wellRippleT392 < 0.5) {
          mat392.emissiveIntensity = 0.12 + (wellRippleT392 / 0.5) * 0.18;
          wellLight392.intensity = 0.06 + (wellRippleT392 / 0.5) * 0.14;
        } else if (wellRippleT392 < 1.0) {
          const t = (wellRippleT392 - 0.5) / 0.5;
          mat392.emissiveIntensity = 0.30 - t * 0.18;
          wellLight392.intensity = 0.20 - t * 0.14;
        } else {
          wellRippleT392 = -1;
        }
      }
    }

    // Cycle-400: fairy lights twinkle + light flicker
    fairyT += dt;
    for (let i = 0; i < _fairyBulbs.length; i++) {
      const bulb = _fairyBulbs[i]!;
      (bulb.material as MeshBasicMaterial).opacity = 0.7 + Math.sin(fairyT * 3 + i * 0.8) * 0.3;
    }
    if (_fairyPointLight) {
      _fairyPointLight.intensity = 0.12 + Math.sin(fairyT * 2.5) * 0.05;
    }

    // Cycle-405: ground mist tendrils
    if (mistGroup405) {
      mistT405 += dt * 0.25;
      mistPlanes405.forEach((plane, i) => {
        const phase = mistT405 + i * 1.1;
        const cycle = phase % 6.0;
        const rising = cycle < 3.0;
        const t = rising ? cycle / 3.0 : (cycle - 3.0) / 3.0;
        plane.position.y = rising
          ? mistBaseY405[i]! + t * 2.2
          : mistBaseY405[i]! + 2.2 + t * 0.5;
        const mat = plane.material as MeshBasicMaterial;
        mat.opacity = rising ? t * 0.18 : (1.0 - t) * 0.18;
        plane.rotation.y += dt * 0.05;
      });
    }

    // Cycle-410: waterfall cascade animation
    if (waterfallGroup410) {
      waterfallT410 += dt * 1.2;
      waterfallPlanes410.forEach((plane, pi) => {
        const pos = plane.geometry.attributes['position'] as BufferAttribute;
        for (let i = 0; i < pos.count; i++) {
          const x = pos.getX(i);
          const y = pos.getY(i);
          // Horizontal ripple that scrolls downward
          const wave = Math.sin(y * 3 + waterfallT410 * 4 + pi * 1.1) * 0.04;
          pos.setX(i, x + wave - (pi - 1) * 0.02); // slight lean per stream
        }
        pos.needsUpdate = true;
        // Opacity flicker for foam effect
        (plane.material as MeshBasicMaterial).opacity = 0.55 + Math.sin(waterfallT410 * 3 + pi) * 0.15;
      });
    }

    // Cycle-416: spring of visions animation
    if (springGroup416 && springWaterMesh416 && springGlowLight416) {
      springT416 += dt;
      springVisionTimer416 += dt;

      // Water surface ripple (animate geometry vertices)
      const waterPos = springWaterMesh416.geometry.attributes['position'] as BufferAttribute;
      for (let vi = 0; vi < waterPos.count; vi++) {
        const x = waterPos.getX(vi);
        const z = waterPos.getZ(vi);
        const dist = Math.sqrt(x * x + z * z);
        waterPos.setY(vi, Math.sin(dist * 5 - springT416 * 2.5) * 0.018);
      }
      waterPos.needsUpdate = true;

      // Base light pulse
      let baseIntensity = 0.18 + Math.sin(springT416 * 1.3) * 0.06;

      // Vision flash event
      if (springVisionTimer416 >= springVisionDur416) {
        springVisionTimer416 = 0;
        springVisionDur416 = 8 + Math.random() * 10;
      }
      if (springVisionTimer416 < 0.5) {
        // Flash: bright surge then fade
        const ft = springVisionTimer416 / 0.5;
        baseIntensity += Math.sin(ft * Math.PI) * 0.5;
        const mat = springWaterMesh416.material as MeshBasicMaterial;
        mat.opacity = 0.85 + Math.sin(ft * Math.PI) * 0.15;
      }
      springGlowLight416.intensity = baseIntensity;
    }

    // Cycle-421: Celtic cross knotwork glow pulse
    if (celticCrossGroup421) {
      celticCrossT421 += dt;
      celticCrossGlows421.forEach((glyph, i) => {
        const mat = glyph.material as MeshBasicMaterial;
        mat.opacity = 0.15 + Math.sin(celticCrossT421 * 1.1 + i * 0.5) * 0.1;
      });
      if (celticCrossLight421) {
        celticCrossLight421.intensity = 0.08 + Math.sin(celticCrossT421 * 0.7) * 0.04;
      }
    }

    // Cycle-426: raven flock orbit + wing flap
    ravenFlock426.forEach((raven, i) => {
      ravenT426[i] += dt * (0.28 + i * 0.015);
      const t = ravenT426[i]!;
      const radius = 4.5 + (i % 3) * 0.8;
      const cx = 0, cz = -15;
      raven.position.x = cx + Math.cos(t) * radius;
      raven.position.z = cz + Math.sin(t) * radius;
      raven.position.y = 7.5 + (i % 2) * 1.2 + Math.sin(t * 1.7 + i) * 0.4;
      raven.rotation.y = -(t + Math.PI / 2);
      raven.rotation.z = Math.sin(t) * 0.2;
      const flap = Math.sin(t * 4.5 + i * 0.3) * 0.35;
      if (ravenWingL426[i]) ravenWingL426[i]!.rotation.z = flap;
      if (ravenWingR426[i]) ravenWingR426[i]!.rotation.z = -flap;
    });

    // Cycle-430: druidic candle circle — independent flame flicker
    if (candleCircleGroup430) {
      candleT430 += dt;
      candleFlames430.forEach((flame, i) => {
        const mat = flame.material as MeshBasicMaterial;
        mat.opacity = 0.7 + Math.sin(candleT430 * 7.3 + i * 1.1) * 0.2;
        flame.scale.y = 0.85 + Math.sin(candleT430 * 9.1 + i * 0.7) * 0.2;
        flame.scale.x = 0.9 + Math.sin(candleT430 * 5.7 + i * 1.4) * 0.12;
      });
      if (candleCenterLight430) {
        candleCenterLight430.intensity = 0.12 + Math.sin(candleT430 * 1.2) * 0.05;
      }
    }

    // Cycle-435: bard's harp — string vibration + ambient idle pulse
    if (harpGroup435) {
      harpT435 += dt;
      harpVibrateTimer435 += dt;

      // Trigger vibration
      if (harpVibrateTimer435 >= harpNextVibrate435 && !harpVibrating435) {
        harpVibrating435 = true;
        harpVibrateDur435 = 0;
        harpVibrateTimer435 = 0;
        harpNextVibrate435 = 10 + Math.random() * 14;
      }

      if (harpVibrating435) {
        harpVibrateDur435 += dt;
        if (harpVibrateDur435 > 2.0) {
          harpVibrating435 = false;
        }
        const vibrT = harpVibrateDur435;
        harpStrings435.forEach((str, i) => {
          const mat = str.material as LineBasicMaterial;
          mat.opacity = 0.5 + Math.sin(vibrT * 8 + i * 0.4) * 0.4;
        });
        if (harpLight435) harpLight435.intensity = 0.15 + Math.sin(vibrT * 6) * 0.1;
      } else {
        // Idle: faint ambient pulse
        harpStrings435.forEach((str, i) => {
          const mat = str.material as LineBasicMaterial;
          mat.opacity = 0.35 + Math.sin(harpT435 * 0.8 + i * 0.3) * 0.15;
        });
        if (harpLight435) harpLight435.intensity = 0.05 + Math.sin(harpT435 * 0.6) * 0.02;
      }
    }

    // Cycle-439: dragonfly swarm orbit + wing flutter + bioluminescence
    dragonflyCloudT439 += dt;
    dragonflySwarm439.forEach((df, di) => {
      dragonflyT439[di] += dt * (1.5 + di * 0.08);
      const t = dragonflyT439[di]!;

      // Lissajous-like wandering orbit
      const orbitR = 1.2 + Math.sin(t * 0.3 + di) * 0.6;
      const orbitAngle = t * 0.4 + di * (Math.PI * 2 / 12);
      df.position.x = 5 + Math.cos(orbitAngle) * orbitR + Math.sin(t * 0.7) * 0.4;
      df.position.z = -16 + Math.sin(orbitAngle) * orbitR + Math.cos(t * 0.5) * 0.3;
      df.position.y = 1.8 + Math.sin(t * 1.2 + di * 0.5) * 0.5;

      // Face direction of travel
      df.rotation.y = orbitAngle + Math.PI / 2;
      df.rotation.z = Math.sin(t * 0.8) * 0.15;

      // Wing flutter (very fast)
      const flutter = Math.sin(t * 18) * 0.5;
      const wings = dragonflyWingPairs439[di]!;
      if (wings[0]) wings[0].rotation.y = flutter;
      if (wings[1]) wings[1].rotation.y = -flutter;
      if (wings[2]) wings[2].rotation.y = flutter * 0.7;
      if (wings[3]) wings[3].rotation.y = -flutter * 0.7;

      // Wing opacity pulse (bioluminescence)
      wings.forEach((w, wi) => {
        const mat = w.material as MeshBasicMaterial;
        mat.opacity = 0.4 + Math.sin(t * 3 + wi * 0.4) * 0.25;
      });
    });

    // Cycle-442: mushroom ring bioluminescence + wisp hover
    mushroomT442 += dt;
    wispT442 += dt;
    mushroomCaps442.forEach((cap, i) => {
      const mat = cap.material as MeshBasicMaterial;
      mat.opacity = 0.6 + 0.35 * Math.sin(mushroomT442 * 0.8 + i * 0.7);
    });
    if (mushroomWisp442) {
      mushroomWisp442.position.y = 0.8 + 0.15 * Math.sin(wispT442 * 1.3);
    }

    // Cycle-446: stone wishing well — water shimmer + vision ripple event
    wellT446 += dt;
    wellRippleTimer446 -= dt;
    if (wellWaterMat446) {
      wellWaterMat446.opacity = 0.55 + 0.2 * Math.sin(wellT446 * 1.8);
    }
    if (wellRippleTimer446 <= 0) {
      wellRippleTimer446 = 8 + Math.random() * 7;
      window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'water_drop' } }));
      if (wellWaterMat446) wellWaterMat446.opacity = 1.0;
    }

    // Cycle-451: moonlit forest pool — shimmer, lily bob, droplet ripple
    poolT451 += dt;
    poolRippleTimer451 -= dt;
    if (poolWaterMat451) {
      poolWaterMat451.opacity = 0.65 + 0.15 * Math.sin(poolT451 * 1.2);
    }
    poolLilyPads451.forEach((pad, i) => {
      pad.position.y = 0.05 + 0.015 * Math.sin(poolT451 * 0.8 + i * 1.1);
    });
    if (poolRippleTimer451 <= 0) {
      poolRippleTimer451 = 12 + Math.random() * 8;
      if (poolWaterMat451) poolWaterMat451.opacity = 1.0;
      window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'water_drop' } }));
    }

    // Cycle-456: hollow oak heartwood pulse
    hollowOakT456 += dt;
    if (hollowOakInnerMat456) {
      hollowOakInnerMat456.opacity = 0.1 + 0.08 * Math.sin(hollowOakT456 * 0.6);
    }
    if (hollowOakLight456) {
      hollowOakLight456.intensity = 0.35 + 0.12 * Math.sin(hollowOakT456 * 0.6);
    }

    // Cycle-461: tumulus dolmen glow pulse
    tumulusT461 += dt;
    if (tumulusGlowMat461) {
      tumulusGlowMat461.opacity = 0.08 + 0.06 * Math.sin(tumulusT461 * 0.7);
    }
    if (tumulusLight461) {
      tumulusLight461.intensity = 0.15 + 0.07 * Math.sin(tumulusT461 * 0.7);
    }
  };

  const dispose = (): void => {
    group.traverse((obj) => {
      if (obj instanceof Mesh || obj instanceof Points) {
        obj.geometry.dispose();
        if (Array.isArray(obj.material)) {
          (obj.material as Material[]).forEach((m) => m.dispose());
        } else {
          (obj.material as Material).dispose();
        }
      }
    });
    for (const mat of crowFlock.crowMats) {
      mat.dispose();
    }
    _mistLayers.length = 0;
    _wispMeshes.length = 0;
    _wispLights.length = 0;
    _rainMeshes.length = 0;
    _fireflyMeshes.length = 0;
    _lanternMesh = null;
    _lanternLight = null;
    _treantGroup = null;
    _treantBody = null;
    _treantEyeLights.length = 0;
    _owlHeads.length = 0;
    _owlEyeLights.length = 0;
    _dewDroplets.length = 0;
    _dewLights.length = 0;
    // Cycle-357: bridge + stream cleanup
    if (bridgeGroup357) {
      group.remove(bridgeGroup357);
      bridgeGroup357.traverse(c => {
        if ((c as Mesh).geometry) (c as Mesh).geometry.dispose();
        const mat = (c as Mesh).material;
        if (mat) {
          if (Array.isArray(mat)) {
            (mat as Material[]).forEach(m => m.dispose());
          } else {
            (mat as Material).dispose();
          }
        }
      });
      bridgeGroup357 = null;
    }
    streamMesh357 = null;
    streamLights357.length = 0;
    // Cycle-363: runestone cleanup
    if (runestoneGroup363) {
      group.remove(runestoneGroup363);
      runestoneGroup363.traverse(c => {
        if ((c as Mesh).geometry) (c as Mesh).geometry.dispose();
        const mat = (c as Mesh).material;
        if (mat) {
          if (Array.isArray(mat)) {
            (mat as Material[]).forEach(m => m.dispose());
          } else {
            (mat as Material).dispose();
          }
        }
      });
      runestoneGroup363 = null;
    }
    runestoneCarvings363 = null;
    if (runestoneLight363) { runestoneLight363.dispose(); runestoneLight363 = null; }
    // Cycle-375: deer cleanup
    if (deerGroup375) {
      group.remove(deerGroup375);
      deerGroup375.traverse(c => {
        if ((c as Mesh).geometry) (c as Mesh).geometry.dispose();
        const mat = (c as Mesh).material;
        if (mat) {
          if (Array.isArray(mat)) {
            (mat as Material[]).forEach(m => m.dispose());
          } else {
            (mat as Material).dispose();
          }
        }
      });
      deerGroup375 = null;
    }
    deerHead375 = null;
    // Cycle-383: mushroom ring cleanup
    if (mushroomGroup383) {
      group.remove(mushroomGroup383);
      mushroomGroup383.traverse(c => {
        if ((c as Mesh).geometry) (c as Mesh).geometry.dispose();
        const mat = (c as Mesh).material;
        if (mat) {
          if (Array.isArray(mat)) {
            (mat as Material[]).forEach(m => m.dispose());
          } else {
            (mat as Material).dispose();
          }
        }
      });
      mushroomGroup383 = null;
    }
    mushroomCaps383 = [];
    if (mushroomRingLight383) { mushroomRingLight383.dispose(); mushroomRingLight383 = null; }
    // Cycle-387: hollow tree cleanup
    if (hollowTreeGroup387) {
      group.remove(hollowTreeGroup387);
      hollowTreeGroup387.traverse(c => {
        if ((c as Mesh).geometry) (c as Mesh).geometry.dispose();
        const mat = (c as Mesh).material;
        if (mat) {
          if (Array.isArray(mat)) {
            (mat as Material[]).forEach(m => m.dispose());
          } else {
            (mat as Material).dispose();
          }
        }
      });
      hollowTreeGroup387 = null;
    }
    if (hollowTreeLight387) { hollowTreeLight387.dispose(); hollowTreeLight387 = null; }
    // Cycle-392: stone well cleanup
    if (wellGroup392) {
      group.remove(wellGroup392);
      wellGroup392.traverse(c => {
        if ((c as Mesh).geometry) (c as Mesh).geometry.dispose();
        const mat = (c as Mesh).material;
        if (mat) {
          if (Array.isArray(mat)) {
            (mat as Material[]).forEach(m => m.dispose());
          } else {
            (mat as Material).dispose();
          }
        }
      });
      wellGroup392 = null;
    }
    wellWater392 = null;
    if (wellLight392) { wellLight392.dispose(); wellLight392 = null; }
    // Cycle-400: fairy lights cleanup
    if (fairyLightsGroup) {
      group.remove(fairyLightsGroup);
      fairyLightsGroup.traverse(c => {
        if ((c as Mesh).geometry) (c as Mesh).geometry.dispose();
        const mat = (c as Mesh).material;
        if (mat) {
          if (Array.isArray(mat)) {
            (mat as Material[]).forEach(m => m.dispose());
          } else {
            (mat as Material).dispose();
          }
        }
      });
      fairyLightsGroup = null;
    }
    _fairyBulbs = [];
    if (_fairyPointLight) { _fairyPointLight.dispose(); _fairyPointLight = null; }
    // Cycle-405: mist tendrils cleanup
    if (mistGroup405) {
      mistPlanes405.forEach(p => {
        p.geometry.dispose();
        (p.material as MeshBasicMaterial).dispose();
      });
      mistPlanes405.length = 0;
      mistBaseY405.length = 0;
      mistGroup405 = null;
    }
    // Cycle-410: waterfall cleanup
    if (waterfallGroup410) {
      waterfallGroup410.traverse(c => {
        if (c instanceof Mesh) {
          c.geometry.dispose();
          if (Array.isArray(c.material)) {
            c.material.forEach(m => m.dispose());
          } else {
            c.material.dispose();
          }
        }
        if (c instanceof PointLight) c.dispose();
      });
      waterfallPlanes410.length = 0;
      waterfallGroup410 = null;
    }
    // Cycle-416: spring of visions cleanup
    if (springGroup416) {
      springGroup416.traverse(c => {
        if (c instanceof Mesh) {
          c.geometry.dispose();
          if (Array.isArray(c.material)) {
            c.material.forEach(m => m.dispose());
          } else {
            c.material.dispose();
          }
        }
        if (c instanceof PointLight) c.dispose();
      });
      springWaterMesh416 = null;
      springGlowLight416 = null;
      springGroup416 = null;
    }
    // Cycle-421: Celtic cross cleanup
    if (celticCrossGroup421) {
      celticCrossGroup421.traverse(c => {
        if (c instanceof Mesh) {
          c.geometry.dispose();
          if (Array.isArray(c.material)) c.material.forEach(m => m.dispose());
          else c.material.dispose();
        }
        if (c instanceof PointLight) c.dispose();
      });
      celticCrossGlows421.length = 0;
      celticCrossLight421 = null;
      celticCrossGroup421 = null;
    }
    // Cycle-426: raven flock cleanup
    ravenFlock426.forEach(raven => {
      raven.traverse(c => {
        if (c instanceof Mesh) {
          c.geometry.dispose();
          if (Array.isArray(c.material)) c.material.forEach(m => m.dispose());
          else c.material.dispose();
        }
      });
    });
    ravenFlock426.length = 0;
    ravenT426.length = 0;
    ravenWingL426.length = 0;
    ravenWingR426.length = 0;
    // Cycle-430: druidic candle circle cleanup
    if (candleCircleGroup430) {
      candleCircleGroup430.traverse(c => {
        if (c instanceof Mesh) {
          c.geometry.dispose();
          if (Array.isArray(c.material)) c.material.forEach(m => m.dispose());
          else c.material.dispose();
        }
        if (c instanceof PointLight) c.dispose();
      });
      candleFlames430.length = 0;
      candleCenterLight430 = null;
      candleCircleGroup430 = null;
    }
    // Cycle-435: bard's harp cleanup
    if (harpGroup435) {
      harpGroup435.traverse(c => {
        if (c instanceof Mesh) {
          c.geometry.dispose();
          if (Array.isArray(c.material)) c.material.forEach(m => m.dispose());
          else c.material.dispose();
        }
        if (c instanceof Line) {
          c.geometry.dispose();
          (c.material as LineBasicMaterial).dispose();
        }
        if (c instanceof PointLight) c.dispose();
      });
      harpStrings435.length = 0;
      harpLight435 = null;
      harpGroup435 = null;
    }
    // Cycle-439: dragonfly swarm cleanup
    dragonflySwarm439.forEach(df => {
      df.traverse(c => {
        if (c instanceof Mesh) {
          c.geometry.dispose();
          if (Array.isArray(c.material)) {
            (c.material as Material[]).forEach(m => m.dispose());
          } else {
            (c.material as Material).dispose();
          }
        }
      });
    });
    dragonflySwarm439.length = 0;
    dragonflyT439.length = 0;
    dragonflyWingPairs439.length = 0;

    // Cycle-442: mushroom ring cleanup
    if (mushroomRingGroup442) {
      mushroomRingGroup442.traverse(c => {
        if (c instanceof Mesh) {
          c.geometry.dispose();
          if (Array.isArray(c.material)) {
            (c.material as Material[]).forEach(m => m.dispose());
          } else {
            (c.material as Material).dispose();
          }
        }
      });
      mushroomRingGroup442 = null;
    }
    mushroomCaps442 = [];
    mushroomWisp442 = null;

    // Cycle-446: stone wishing well cleanup
    if (wellGroup446) {
      group.remove(wellGroup446);
      wellGroup446.traverse(c => {
        if ((c as Mesh).geometry) (c as Mesh).geometry.dispose();
        const mat = (c as Mesh).material;
        if (mat) {
          if (Array.isArray(mat)) {
            (mat as Material[]).forEach(m => m.dispose());
          } else {
            (mat as Material).dispose();
          }
        }
      });
      wellGroup446 = null;
    }
    wellWaterMat446 = null;

    // Cycle-451: moonlit forest pool cleanup
    if (poolGroup451) {
      group.remove(poolGroup451);
      poolGroup451.traverse(c => {
        if ((c as Mesh).geometry) (c as Mesh).geometry.dispose();
        const mat = (c as Mesh).material;
        if (mat) {
          if (Array.isArray(mat)) {
            (mat as Material[]).forEach(m => m.dispose());
          } else {
            (mat as Material).dispose();
          }
        }
      });
      poolGroup451 = null;
    }
    poolWaterMat451 = null;
    poolLilyPads451.length = 0;

    // Cycle-456: hollow oak cleanup
    if (hollowOakGroup456) {
      group.remove(hollowOakGroup456);
      hollowOakGroup456.traverse(c => {
        if ((c as Mesh).geometry) (c as Mesh).geometry.dispose();
        const mat = (c as Mesh).material;
        if (mat) {
          if (Array.isArray(mat)) {
            (mat as Material[]).forEach(m => m.dispose());
          } else {
            (mat as Material).dispose();
          }
        }
      });
      hollowOakGroup456 = null;
    }
    hollowOakInnerMat456 = null;
    hollowOakLight456 = null;

    // Cycle-461: tumulus cleanup
    if (tumulus461) {
      group.remove(tumulus461);
      tumulus461.traverse(c => {
        if ((c as Mesh).geometry) (c as Mesh).geometry.dispose();
        const mat = (c as Mesh).material;
        if (Array.isArray(mat)) {
          mat.forEach(m => m.dispose());
        } else if (mat) {
          (mat as Material).dispose();
        }
      });
      tumulus461 = null;
    }
    tumulusGlowMat461 = null;
    tumulusLight461 = null;
  };

  return { group, update, dispose };
}
