// ═══════════════════════════════════════════════════════════════════════════════
// Coast Biome — Procedural coastal scene with GLB assets
// Uses existing menu_coast GLBs + procedural ocean, sky, terrain
// ═══════════════════════════════════════════════════════════════════════════════

import { AmbientLight, BackSide, BoxGeometry, BufferAttribute, Color, ConeGeometry, CylinderGeometry, DirectionalLight, DodecahedronGeometry, FrontSide, Group, HemisphereLight, Material, Mesh, MeshStandardMaterial, PlaneGeometry, ShaderMaterial, SphereGeometry } from 'three';
import { loadGLB } from '../engine/AssetLoader';

/** Build a procedural ground plane — flat-shaded for low-poly AAA look. */
function createGround(): Mesh {
  const geo = new PlaneGeometry(200, 200, 48, 48);
  // Gentle terrain undulation
  const pos = geo.attributes.position as BufferAttribute;
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i);
    const z = pos.getY(i); // PlaneGeometry Y = world Z after rotation
    const height = Math.sin(x * 0.05) * 0.8 + Math.cos(z * 0.08) * 0.5 + Math.random() * 0.2;
    pos.setZ(i, height);
  }
  geo.computeVertexNormals();

  const mat = new MeshStandardMaterial({
    color: 0x2e5228,
    roughness: 0.95,
    metalness: 0.0,
    flatShading: true,
  });
  const mesh = new Mesh(geo, mat);
  mesh.rotation.x = -Math.PI / 2;
  mesh.receiveShadow = true;
  return mesh;
}

/** Build a low-poly ocean with flat-shading for faceted wave look. */
function createOcean(): Mesh {
  const geo = new PlaneGeometry(200, 200, 24, 18);
  const mat = new MeshStandardMaterial({
    color: 0x1a3d5c,
    roughness: 0.3,
    metalness: 0.35,
    transparent: true,
    opacity: 0.88,
    flatShading: true,
  });
  const mesh = new Mesh(geo, mat);
  mesh.rotation.x = -Math.PI / 2;
  mesh.position.set(60, -0.5, 0);
  mesh.name = 'ocean_plane';
  return mesh;
}

/**
 * Celtic Breton sky — overcast moody gradient.
 * Top: dark slate-grey (0x2a3240) — brooding Celtic sky.
 * Mid-horizon: warm grey-green (0x5a6a50) — forest haze where sky meets tree line.
 * Bottom: mist cream (0x8a9a78) — matches fog plane color for seamless blend.
 * Cycle 33: replaces generic blue 0x4488bb/0xaaccdd.
 */
function createSky(): Mesh {
  const geo = new SphereGeometry(150, 16, 12);
  const mat = new ShaderMaterial({
    uniforms: {
      topColor:    { value: new Color(0x2a3240) },  // dark slate-grey zenith
      midColor:    { value: new Color(0x4a5a48) },  // grey-green mid
      bottomColor: { value: new Color(0x8a9a78) },  // warm mist at horizon
    },
    vertexShader: `
      varying vec3 vWorldPosition;
      void main() {
        vec4 worldPos = modelMatrix * vec4(position, 1.0);
        vWorldPosition = worldPos.xyz;
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
      }
    `,
    fragmentShader: `
      uniform vec3 topColor;
      uniform vec3 midColor;
      uniform vec3 bottomColor;
      varying vec3 vWorldPosition;
      void main() {
        float h = clamp(normalize(vWorldPosition).y * 0.5 + 0.5, 0.0, 1.0);
        vec3 col = h < 0.5
          ? mix(bottomColor, midColor, h * 2.0)
          : mix(midColor, topColor, (h - 0.5) * 2.0);
        gl_FragColor = vec4(col, 1.0);
      }
    `,
    side: BackSide,
  });
  return new Mesh(geo, mat);
}

/**
 * Scatter low-poly Celtic trees in 3 depth layers for AAA visual depth.
 * Layer 0 (near): 12 trees, large, full detail
 * Layer 1 (mid):  16 trees, medium, slightly desaturated
 * Layer 2 (far):  12 trees, small, silhouette-style dark
 * Uses flat-shaded ConeGeometry for conifer (more Celtic than sphere).
 */
function createTrees(count: number): Group {
  const group = new Group();

  const layers: Array<{ start: number; end: number; minR: number; maxR: number; colorBase: number; scaleBase: number; scaleVar: number }> = [
    { start: 0,  end: 12, minR: 6,  maxR: 18, colorBase: 0x2d6b2d, scaleBase: 1.1, scaleVar: 0.5 },  // near — vivid green
    { start: 12, end: 28, minR: 18, maxR: 32, colorBase: 0x265a26, scaleBase: 0.85, scaleVar: 0.4 }, // mid — darker
    { start: 28, end: count, minR: 32, maxR: 55, colorBase: 0x1a3d1a, scaleBase: 0.6, scaleVar: 0.3 }, // far — silhouette
  ];

  for (const layer of layers) {
    const trunkMat = new MeshStandardMaterial({ color: 0x4a2e12, roughness: 0.95, flatShading: true });
    const leafMat = new MeshStandardMaterial({ color: layer.colorBase, roughness: 0.9, flatShading: true });

    for (let i = layer.start; i < layer.end; i++) {
      const tree = new Group();

      // Per-tree geometry instances — shared geometries cause dispose() to free the GPU
      // buffer on the first traversal hit, leaving all subsequent meshes with dangling refs.
      const trunkGeo = new CylinderGeometry(0.08, 0.18, 2.4, 5);
      const cone1Geo = new ConeGeometry(1.1, 2.2, 6);
      const cone2Geo = new ConeGeometry(0.8, 1.8, 6);
      const cone3Geo = new ConeGeometry(0.5, 1.4, 5);

      const trunk = new Mesh(trunkGeo, trunkMat);
      trunk.castShadow = true;
      tree.add(trunk);

      // 3-tier cone stack for Celtic conifer
      const c1 = new Mesh(cone1Geo, leafMat);
      c1.position.y = 1.4;
      c1.castShadow = true;
      tree.add(c1);

      const c2 = new Mesh(cone2Geo, leafMat);
      c2.position.y = 2.5;
      c2.castShadow = true;
      tree.add(c2);

      const c3 = new Mesh(cone3Geo, leafMat);
      c3.position.y = 3.5;
      c3.castShadow = true;
      tree.add(c3);

      const angle = Math.random() * Math.PI * 2;
      const radius = layer.minR + Math.random() * (layer.maxR - layer.minR);
      tree.position.set(
        Math.cos(angle) * radius - 10,
        0,
        Math.sin(angle) * radius - 10
      );
      tree.scale.setScalar(layer.scaleBase + Math.random() * layer.scaleVar);
      // Slight random lean for organic feel
      tree.rotation.z = (Math.random() - 0.5) * 0.08;
      group.add(tree);
    }
  }
  return group;
}

/** Scatter procedural rocks — flat-shaded granite. */
function createRocks(count: number): Group {
  const group = new Group();
  const rockMat = new MeshStandardMaterial({ color: 0x5e5450, roughness: 0.9, flatShading: true });

  for (let i = 0; i < count; i++) {
    const geo = new DodecahedronGeometry(0.3 + Math.random() * 0.7, 0);
    const rock = new Mesh(geo, rockMat);
    rock.castShadow = true;
    const angle = Math.random() * Math.PI * 2;
    const radius = 5 + Math.random() * 50;
    rock.position.set(
      Math.cos(angle) * radius - 5,
      -0.1,
      Math.sin(angle) * radius
    );
    rock.rotation.set(Math.random(), Math.random(), Math.random());
    rock.scale.set(1, 0.6 + Math.random() * 0.4, 1);
    group.add(rock);
  }
  return group;
}

/**
 * Ground-level fog plane with animated opacity.
 * T005 optimization (cycle 13):
 *  - noise() reduced from 4 trig ops to 2 (removed weighted secondary terms)
 *  - edgeFade replaced by radial distance from UV center (1 smoothstep vs 4)
 *  - uDensity lowered 0.35 -> 0.25 (reduces transparent overdraw budget)
 *  - DoubleSide -> FrontSide (fog viewed from above only, halves rasterization)
 *  - uTime clamped via mod(uTime, 100.0) to prevent float precision drift on long sessions
 * Expected gain: ~35% fragment cost reduction on tile-based GPUs (GTX 1060 target: 60fps).
 */
function createFog(): Mesh {
  const geo = new PlaneGeometry(180, 180, 1, 1);
  const mat = new ShaderMaterial({
    uniforms: {
      uTime: { value: 0 },
      // Warm breton mist: grey-green instead of cold blue (Cycle 31 AAA pass)
      uFogColor: { value: new Color(0x8a9a78) },
      uDensity: { value: 0.25 },
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

      // Optimized noise: 2 trig ops instead of 4 (dropped 0.5-weighted secondary terms)
      float noise(vec2 p, float t) {
        float tt = mod(t, 100.0);
        return sin(p.x * 1.7 + tt * 0.3) * cos(p.y * 2.3 + tt * 0.2);
      }

      void main() {
        vec2 p = vUv * 6.0 - 3.0;
        float n = noise(p, uTime) * 0.5 + 0.5;
        // Radial edge fade: single smoothstep on distance from UV center (replaces 4 smoothsteps)
        float dist = length(vUv - vec2(0.5));
        float edgeFade = smoothstep(0.5, 0.2, dist);
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
  mesh.position.set(0, 0.8, 0);
  mesh.name = 'fog_plane';
  return mesh;
}

/** Standing stones / menhirs — flat-shaded granite look. */
function createMenhirs(count: number): Group {
  const group = new Group();
  const mat = new MeshStandardMaterial({ color: 0x787068, roughness: 0.85, flatShading: true });
  const mossMat = new MeshStandardMaterial({ color: 0x556644, roughness: 0.95, flatShading: true });

  for (let i = 0; i < count; i++) {
    const height = 2.5 + Math.random() * 3.5;
    const menhir = new Mesh(new BoxGeometry(0.55, height, 0.38), mat);
    menhir.castShadow = true;
    menhir.position.set(
      -18 + Math.random() * 36,
      height / 2,
      -25 + Math.random() * 12
    );
    menhir.rotation.y = Math.random() * Math.PI;
    menhir.rotation.z = (Math.random() - 0.5) * 0.12;
    group.add(menhir);

    // Moss patch at base
    const moss = new Mesh(new BoxGeometry(0.65, 0.15, 0.5), mossMat);
    moss.position.set(menhir.position.x, 0.07, menhir.position.z);
    moss.rotation.y = menhir.rotation.y;
    group.add(moss);
  }
  return group;
}

export interface BiomeSceneResult {
  readonly group: Group;
  readonly update: (dt: number) => void;
  readonly dispose: () => void;
}

/**
 * Build the full coastal biome scene — AAA lighting pass (Cycle 31).
 * Lighting: AmbientLight + DirectionalLight (sun) + HemisphereLight (sky/ground) + RimLight (backlight).
 * Trees: 40 total in 3 depth layers with flat-shaded Celtic conifers.
 * Fog: warm breton mist (0x8a9a7a) instead of cold blue.
 */
export async function buildCoastScene(): Promise<BiomeSceneResult> {
  const group = new Group();

  // ── Lighting — AAA 3-source setup ──────────────────────────────────────────
  // 1. Ambient — warm dark base
  const ambient = new AmbientLight(0x304028, 0.55);
  group.add(ambient);

  // 2. Directional sun — low angle, golden celtic light from NW
  const sun = new DirectionalLight(0xffd8a0, 1.4);
  sun.position.set(-20, 18, 10);
  sun.castShadow = true;
  sun.shadow.mapSize.set(1024, 1024);
  sun.shadow.camera.near = 0.5;
  sun.shadow.camera.far = 100;
  sun.shadow.camera.left = -40;
  sun.shadow.camera.right = 40;
  sun.shadow.camera.top = 40;
  sun.shadow.camera.bottom = -40;
  group.add(sun);

  // 3. HemisphereLight — sky (soft blue) / ground (dark green) for ambient occlusion feel
  const hemi = new HemisphereLight(0x7799cc, 0x223316, 0.45);
  group.add(hemi);

  // 4. Rim light — cool backlight from ocean direction to separate silhouettes
  const rim = new DirectionalLight(0x88bbcc, 0.35);
  rim.position.set(50, 8, -20);
  group.add(rim);

  // Procedural elements
  group.add(createGround());
  group.add(createOcean());
  group.add(createSky());
  group.add(createTrees(40));
  group.add(createRocks(18));
  group.add(createMenhirs(7));
  group.add(createFog());

  // Load GLB assets in parallel — Promise.allSettled so one failure doesn't block others
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
    if (r.status !== 'fulfilled' || !cfg) continue;
    const model = r.value.scene.clone();
    // C85: clone material before mutation — scene.clone() shares material refs with cached
    // GLTF, so writing flatShading/needsUpdate directly mutates the cached asset (same
    // class as LairGLBAssets C81-04 bougie fix). Clone per-mesh to isolate this instance.
    model.traverse((child) => {
      if (child instanceof Mesh && child.material instanceof MeshStandardMaterial) {
        child.material = (child.material as MeshStandardMaterial).clone();
        child.material.flatShading = true;
        child.material.needsUpdate = true;
      }
    });
    model.position.set(cfg.pos[0], cfg.pos[1], cfg.pos[2]);
    model.scale.setScalar(cfg.scale);
    group.add(model);
  }

  // Ocean animation — flat-shaded low-poly wave facets via vertex displacement
  const oceanMesh = group.children.find(
    (c) => c instanceof Mesh && (c as Mesh).name === 'ocean_plane'
  ) as Mesh | undefined;

  // Pre-cache ocean geometry base positions for wave animation
  let oceanBaseY: Float32Array | null = null;
  if (oceanMesh) {
    const posAttr = oceanMesh.geometry.attributes['position'] as BufferAttribute;
    oceanBaseY = new Float32Array(posAttr.array as Float32Array);
  }

  // Fog animation
  const fogMesh = group.children.find(
    (c) => c instanceof Mesh && c.name === 'fog_plane'
  ) as Mesh | undefined;

  // Track whether to skip ocean vertex update this frame (low-FPS adaptive LOD)
  let _skipOceanFrame = false;

  const update = (dt: number): void => {
    const t = performance.now() * 0.001;
    // Animate low-poly ocean vertices for faceted wave look.
    // Low-FPS adaptive: skip every other frame when dt > 33ms (<30fps) to keep
    // the game loop responsive on mobile/low-end hardware.
    if (oceanMesh && oceanBaseY) {
      _skipOceanFrame = !_skipOceanFrame;
      if (!_skipOceanFrame || dt <= 0.033) {
        const posAttr = oceanMesh.geometry.attributes['position'] as BufferAttribute;
        const arr = posAttr.array as Float32Array;
        for (let i = 0; i < posAttr.count; i++) {
          // PlaneGeometry stores X and Y in local space; after mesh.rotation.x=-PI/2
          // local-X stays world-X, local-Y becomes world-Z. Named accordingly to
          // prevent future "fix" that swaps indices and silently breaks wave topology.
          const bx = oceanBaseY[i * 3] ?? 0;
          const by_local = oceanBaseY[i * 3 + 1] ?? 0; // local-Y = world-Z post-rotation
          const wave = Math.sin(bx * 0.12 + t * 0.9) * 0.9 + Math.cos(by_local * 0.09 + t * 0.7) * 0.6;
          arr[i * 3 + 2] = wave;
        }
        posAttr.needsUpdate = true;
        // flatShading:true — GPU computes per-face normals, no JS recompute needed
      }
    }
    if (fogMesh) {
      const fogMat = fogMesh.material as ShaderMaterial;
      fogMat.uniforms['uTime']!.value = t;
    }
  };

  const dispose = (): void => {
    group.traverse((child) => {
      if (child instanceof Mesh) {
        child.geometry.dispose();
        if (Array.isArray(child.material)) {
          child.material.forEach((m) => m.dispose());
        } else {
          (child.material as Material).dispose();
        }
      }
      // Dispose DirectionalLight shadow maps (WebGLRenderTarget ~4MB each).
      // The traverse only visits Meshes by default so lights need explicit handling.
      // Without this, each run leaks one shadow map on the GPU.
      if (child instanceof DirectionalLight && child.shadow.map) {
        child.shadow.map.dispose();
      }
    });
    group.clear();
  };

  return { group, update, dispose };
}
