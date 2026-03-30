// ═══════════════════════════════════════════════════════════════════════════════
// Coast Biome — Procedural coastal scene with GLB assets
// Uses existing menu_coast GLBs + procedural ocean, sky, terrain
// ═══════════════════════════════════════════════════════════════════════════════

import * as THREE from 'three';
import { loadGLB } from '../engine/AssetLoader';

/** Build a procedural ground plane. */
function createGround(): THREE.Mesh {
  const geo = new THREE.PlaneGeometry(200, 200, 64, 64);
  // Gentle terrain undulation
  const pos = geo.attributes.position;
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i);
    const z = pos.getY(i); // PlaneGeometry Y = world Z after rotation
    const height = Math.sin(x * 0.05) * 0.8 + Math.cos(z * 0.08) * 0.5 + Math.random() * 0.2;
    pos.setZ(i, height);
  }
  geo.computeVertexNormals();

  const mat = new THREE.MeshStandardMaterial({
    color: 0x3a5f3a,
    roughness: 0.9,
    metalness: 0.0,
  });
  const mesh = new THREE.Mesh(geo, mat);
  mesh.rotation.x = -Math.PI / 2;
  mesh.receiveShadow = true;
  return mesh;
}

/** Build a simple ocean plane with animated shader. */
function createOcean(): THREE.Mesh {
  const geo = new THREE.PlaneGeometry(200, 200, 1, 1);
  const mat = new THREE.MeshStandardMaterial({
    color: 0x1a4a6a,
    roughness: 0.2,
    metalness: 0.4,
    transparent: true,
    opacity: 0.85,
  });
  const mesh = new THREE.Mesh(geo, mat);
  mesh.rotation.x = -Math.PI / 2;
  mesh.position.set(60, -0.5, 0);
  return mesh;
}

/** Build procedural sky gradient. */
function createSky(): THREE.Mesh {
  const geo = new THREE.SphereGeometry(150, 32, 32);
  const mat = new THREE.ShaderMaterial({
    uniforms: {
      topColor: { value: new THREE.Color(0x4488bb) },
      bottomColor: { value: new THREE.Color(0xaaccdd) },
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
      uniform vec3 bottomColor;
      varying vec3 vWorldPosition;
      void main() {
        float h = normalize(vWorldPosition).y;
        float t = clamp(h * 0.5 + 0.5, 0.0, 1.0);
        gl_FragColor = vec4(mix(bottomColor, topColor, t), 1.0);
      }
    `,
    side: THREE.BackSide,
  });
  return new THREE.Mesh(geo, mat);
}

/** Scatter simple procedural trees. */
function createTrees(count: number): THREE.Group {
  const group = new THREE.Group();
  const trunkGeo = new THREE.CylinderGeometry(0.1, 0.15, 2, 6);
  const trunkMat = new THREE.MeshStandardMaterial({ color: 0x5a3a1a, roughness: 0.9 });
  const leafGeo = new THREE.SphereGeometry(0.8, 8, 6);
  const leafMat = new THREE.MeshStandardMaterial({ color: 0x2d6b2d, roughness: 0.8 });

  for (let i = 0; i < count; i++) {
    const tree = new THREE.Group();
    const trunk = new THREE.Mesh(trunkGeo, trunkMat);
    trunk.castShadow = true;
    tree.add(trunk);

    const leaves = new THREE.Mesh(leafGeo, leafMat);
    leaves.position.y = 1.5;
    leaves.scale.set(1, 1.2, 1);
    leaves.castShadow = true;
    tree.add(leaves);

    const angle = Math.random() * Math.PI * 2;
    const radius = 8 + Math.random() * 40;
    tree.position.set(
      Math.cos(angle) * radius - 10,
      0,
      Math.sin(angle) * radius - 10
    );
    tree.scale.setScalar(0.8 + Math.random() * 1.2);
    group.add(tree);
  }
  return group;
}

/** Scatter procedural rocks. */
function createRocks(count: number): THREE.Group {
  const group = new THREE.Group();
  const rockMat = new THREE.MeshStandardMaterial({ color: 0x666666, roughness: 0.85 });

  for (let i = 0; i < count; i++) {
    const geo = new THREE.DodecahedronGeometry(0.3 + Math.random() * 0.7, 0);
    const rock = new THREE.Mesh(geo, rockMat);
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

/** Ground-level fog plane with animated opacity. */
function createFog(): THREE.Mesh {
  const geo = new THREE.PlaneGeometry(180, 180, 1, 1);
  const mat = new THREE.ShaderMaterial({
    uniforms: {
      uTime: { value: 0 },
      uFogColor: { value: new THREE.Color(0xaabbcc) },
      uDensity: { value: 0.35 },
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

      // Simple noise approximation using sin waves
      float noise(vec2 p) {
        return sin(p.x * 1.7 + uTime * 0.3) * cos(p.y * 2.3 + uTime * 0.2)
             + sin(p.x * 3.1 - uTime * 0.15) * 0.5
             + cos(p.y * 1.9 + uTime * 0.25) * 0.5;
      }

      void main() {
        vec2 p = vUv * 6.0 - 3.0;
        float n = noise(p) * 0.5 + 0.5;
        // Fade at edges so fog blends into scene
        float edgeFade = smoothstep(0.0, 0.25, vUv.x) * smoothstep(1.0, 0.75, vUv.x)
                       * smoothstep(0.0, 0.25, vUv.y) * smoothstep(1.0, 0.75, vUv.y);
        float alpha = n * uDensity * edgeFade;
        gl_FragColor = vec4(uFogColor, alpha);
      }
    `,
    transparent: true,
    depthWrite: false,
    side: THREE.DoubleSide,
  });
  const mesh = new THREE.Mesh(geo, mat);
  mesh.rotation.x = -Math.PI / 2;
  mesh.position.set(0, 0.8, 0);
  mesh.name = 'fog_plane';
  return mesh;
}

/** Standing stones / menhirs. */
function createMenhirs(count: number): THREE.Group {
  const group = new THREE.Group();
  const mat = new THREE.MeshStandardMaterial({ color: 0x888888, roughness: 0.7 });

  for (let i = 0; i < count; i++) {
    const height = 2 + Math.random() * 3;
    const geo = new THREE.BoxGeometry(0.5, height, 0.3);
    const menhir = new THREE.Mesh(geo, mat);
    menhir.castShadow = true;
    menhir.position.set(
      -15 + Math.random() * 30,
      height / 2,
      -20 + Math.random() * 10
    );
    menhir.rotation.y = Math.random() * Math.PI;
    menhir.rotation.z = (Math.random() - 0.5) * 0.1;
    group.add(menhir);
  }
  return group;
}

export interface BiomeSceneResult {
  readonly group: THREE.Group;
  readonly update: (dt: number) => void;
}

/** Build the full coastal biome scene. */
export async function buildCoastScene(): Promise<BiomeSceneResult> {
  const group = new THREE.Group();

  // Procedural elements
  group.add(createGround());
  group.add(createOcean());
  group.add(createSky());
  group.add(createTrees(25));
  group.add(createRocks(15));
  group.add(createMenhirs(5));
  group.add(createFog());

  // Try loading GLB assets (non-blocking — fallback to procedural if fails)
  const glbBase = '/assets/';
  const glbFiles = ['cliff_unified.glb', 'cabin_unified.glb', 'crystal_cluster_unified.glb'];

  for (const file of glbFiles) {
    try {
      const gltf = await loadGLB(glbBase + file);
      const model = gltf.scene.clone();
      // Position each model
      if (file.includes('cliff')) {
        model.position.set(15, -1, -15);
        model.scale.setScalar(3);
      } else if (file.includes('cabin')) {
        model.position.set(-5, 0, -8);
        model.scale.setScalar(1.5);
      } else if (file.includes('crystal')) {
        model.position.set(8, 0, -3);
        model.scale.setScalar(2);
      }
      group.add(model);
    } catch {
      // GLB not available — procedural fallback already added
    }
  }

  // Ocean animation
  const oceanMesh = group.children.find(
    (c) => c instanceof THREE.Mesh && (c as THREE.Mesh).position.x > 50
  ) as THREE.Mesh | undefined;

  // Fog animation
  const fogMesh = group.children.find(
    (c) => c instanceof THREE.Mesh && c.name === 'fog_plane'
  ) as THREE.Mesh | undefined;

  const update = (dt: number): void => {
    if (oceanMesh) {
      oceanMesh.position.y = -0.5 + Math.sin(performance.now() * 0.001) * 0.15;
    }
    if (fogMesh) {
      const fogMat = fogMesh.material as THREE.ShaderMaterial;
      fogMat.uniforms.uTime.value = performance.now() * 0.001;
    }
  };

  return { group, update };
}
