// ═══════════════════════════════════════════════════════════════════════════════
// Forêt de Brocéliande — Mystical Celtic forest walk scene
// Dense oak canopy, ground fog, will-o'-wisp particles, standing stones.
// Optimised: same patterns as CoastBiome (alt-frame ocean → alt-frame wisps).
// ═══════════════════════════════════════════════════════════════════════════════

import {
  AmbientLight, BackSide, BoxGeometry, BufferAttribute, BufferGeometry,
  CircleGeometry, Color, ConeGeometry, CylinderGeometry, DirectionalLight, DodecahedronGeometry,
  DoubleSide, Float32BufferAttribute, FogExp2, FrontSide, Group, HemisphereLight, Material,
  Mesh, MeshBasicMaterial, MeshStandardMaterial, PlaneGeometry, Points, PointLight,
  PointsMaterial, ShaderMaterial, SphereGeometry, TorusGeometry, Vector3,
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
  };

  return { group, update, dispose };
}
