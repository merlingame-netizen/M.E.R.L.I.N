// ═══════════════════════════════════════════════════════════════════════════════
// Forêt de Brocéliande — Mystical Celtic forest walk scene
// Dense oak canopy, ground fog, will-o'-wisp particles, standing stones.
// Optimised: same patterns as CoastBiome (alt-frame ocean → alt-frame wisps).
// ═══════════════════════════════════════════════════════════════════════════════

import {
  AmbientLight, BackSide, BoxGeometry, BufferAttribute, BufferGeometry,
  Color, ConeGeometry, CylinderGeometry, DirectionalLight, DodecahedronGeometry,
  Float32BufferAttribute, FogExp2, FrontSide, Group, HemisphereLight, Material,
  Mesh, MeshBasicMaterial, MeshStandardMaterial, PlaneGeometry, Points,
  PointsMaterial, ShaderMaterial, SphereGeometry, Vector3,
} from 'three';

import type { BiomeSceneResult } from './CoastBiome';

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
    color: 0x1e3a18,      // deep forest moss
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
    // horizon (t=0): 0x1e301e (0.118, 0.188, 0.118) dark forest-green
    // zenith  (t=1): 0x040a04 (0.016, 0.039, 0.016) near-black
    cols[i * 3 + 0] = 0.118 - t * 0.102;
    cols[i * 3 + 1] = 0.188 - t * 0.149;
    cols[i * 3 + 2] = 0.118 - t * 0.102;
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

  // High dark storm band — dense charcoal-green slabs
  addLayer(55, [-90, -35], 16, 0.7, [0x0c180c, 0x111e11, 0x0a150a], [12, 24]);
  // Mid canopy band — medium coverage
  addLayer(38, [-70, -20], 14, 1.3, [0x162416, 0x192a19, 0x0e1a0e], [8, 18]);
  // Low horizon wisps — lighter for depth illusion
  addLayer(22, [-55, -8],  12, 2.1, [0x1c2e1c, 0x203620, 0x172517], [6, 14]);

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
    // Near corridor — flanks the rail path
    { count: 20, minR: 4, maxR: 14, crownColor: 0x1e4a1e, trunkColor: 0x2a1a0a, scaleBase: 1.1, scaleVar: 0.6, heightBase: 3.5 },
    // Mid distance
    { count: 28, minR: 14, maxR: 30, crownColor: 0x173817, trunkColor: 0x221508, scaleBase: 0.85, scaleVar: 0.4, heightBase: 3.0 },
    // Far silhouette layer — very dark, atmospheric
    { count: 24, minR: 30, maxR: 60, crownColor: 0x0e250e, trunkColor: 0x180f04, scaleBase: 0.65, scaleVar: 0.3, heightBase: 2.5 },
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

function createForestMenhirs(): Group {
  const group = new Group();
  const stoneMat = new MeshStandardMaterial({ color: 0x5a5040, roughness: 0.88, flatShading: true });
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

    // Ogham inscription — thin vertical lines on stone (CylinderGeometry carved lines)
    const inscriptionMat = new MeshStandardMaterial({ color: 0x2a1e10, roughness: 0.99, flatShading: true });
    for (let j = 0; j < 3; j++) {
      const line = new Mesh(new BoxGeometry(0.02, 0.25, 0.45), inscriptionMat);
      line.position.set(x + (j - 1) * 0.12, ht * 0.45 + j * 0.08, z);
      line.rotation.y = menhir.rotation.y;
      group.add(line);
    }
  }
  return group;
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

// ── Main export ───────────────────────────────────────────────────────────────

export async function buildForestScene(): Promise<BiomeSceneResult> {
  const group = new Group();

  // Atmospheric fog (Three.js scene fog — applied by renderer)
  // Instanced on the group, picked up by SceneManager when scene.fog is set there.
  // We embed fog params in this group for SceneManager to detect.
  (group as Group & { fogColor?: number; fogDensity?: number }).fogColor   = 0x1a2a18;
  (group as Group & { fogColor?: number; fogDensity?: number }).fogDensity = 0.028;

  // ── Lighting — dark enchanted forest ──────────────────────────────────────
  // 1. Low ambient — forest is dark, light mostly from wisps and shafts
  const ambient = new AmbientLight(0x182418, 0.35);
  group.add(ambient);

  // 2. Moon / diffuse overhead — cold blue-grey (no direct sun visible)
  const moonLight = new DirectionalLight(0x8899bb, 0.7);
  moonLight.position.set(5, 25, 10);
  group.add(moonLight);

  // 3. Hemisphere — canopy green above, dark soil below
  const hemi = new HemisphereLight(0x224422, 0x0e1a0a, 0.5);
  group.add(hemi);

  // 4. Accent — warm amber glow from deeper forest (as if firelight far away)
  const accent = new DirectionalLight(0xaa7733, 0.28);
  accent.position.set(-15, 4, -40);
  group.add(accent);

  // ── Scene geometry ─────────────────────────────────────────────────────────
  group.add(createForestGround());
  const { skyGroup, cloudLayers } = createForestSky();
  group.add(skyGroup);
  group.add(createForestTrees());
  group.add(createUndergrowth());
  group.add(createForestMenhirs());
  group.add(createForestDebris());
  group.add(createCanopyRays());

  const fog = createForestFog();
  group.add(fog);

  const wisps = createWisps();
  group.add(wisps.object);

  // ── Animation state ────────────────────────────────────────────────────────
  let sceneTime = 0;

  const update = (dt: number): void => {
    sceneTime += dt;

    // Fog shader time
    const fogMat = fog.material as ShaderMaterial;
    fogMat.uniforms['uTime']!.value = sceneTime;

    // Will-o'-wisps orbit
    wisps.update(dt);

    // C162: animated cloud drift — each band at different speed for parallax
    for (const layer of cloudLayers) {
      for (const child of layer.group.children) {
        child.position.x += layer.speed * dt;
        if (child.position.x > 110) child.position.x -= 220;
      }
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
  };

  return { group, update, dispose };
}
