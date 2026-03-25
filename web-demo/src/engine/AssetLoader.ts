// ═══════════════════════════════════════════════════════════════════════════════
// Asset Loader — GLB/GLTF loading with caching
// ═══════════════════════════════════════════════════════════════════════════════

import * as THREE from 'three';
import { GLTFLoader, type GLTF } from 'three/addons/loaders/GLTFLoader.js';

const loader = new GLTFLoader();
const cache = new Map<string, GLTF>();

/** Load a GLB file, returning cached result if available. */
export async function loadGLB(url: string): Promise<GLTF> {
  const cached = cache.get(url);
  if (cached) return cached;

  return new Promise((resolve, reject) => {
    loader.load(
      url,
      (gltf) => {
        cache.set(url, gltf);
        // Enable shadows on all meshes
        gltf.scene.traverse((child) => {
          if (child instanceof THREE.Mesh) {
            child.castShadow = true;
            child.receiveShadow = true;
          }
        });
        resolve(gltf);
      },
      undefined,
      reject
    );
  });
}

/** Load multiple GLB files in parallel. */
export async function loadGLBs(urls: readonly string[]): Promise<Map<string, GLTF>> {
  const results = await Promise.allSettled(urls.map((url) => loadGLB(url)));
  const map = new Map<string, GLTF>();
  results.forEach((result, i) => {
    if (result.status === 'fulfilled') {
      map.set(urls[i], result.value);
    } else {
      console.warn(`Failed to load ${urls[i]}:`, result.reason);
    }
  });
  return map;
}

/** Clone a loaded GLB scene (for reusing assets). */
export function cloneGLBScene(gltf: GLTF): THREE.Group {
  return gltf.scene.clone();
}
