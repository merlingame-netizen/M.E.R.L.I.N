// LairGLBAssets — Async GLB overlays for MerlinLairScene.
// Each GLB enhances the procedural mesh already visible; fallback = procedural stays.

import * as THREE from 'three';
import { loadGLB } from '../engine/AssetLoader';

const CANDLE_POSITIONS: Array<[number, number, number]> = [
  [-5, -4.85, -7],
  [0, -4.85, -8.5],
  [3, -4.85, -6],
];

export function loadLairGLBs(scene: THREE.Scene): void {
  // Cauldron: Blender low-poly (bois brun + métal sombre, 34 polys, validated)
  loadGLB('/cauldron_merlin.glb').then((gltf) => {
    gltf.scene.traverse((child) => {
      if (child instanceof THREE.Mesh) {
        (child.material as THREE.MeshStandardMaterial).roughness = 0.9;
        (child.material as THREE.MeshStandardMaterial).metalness = 0.0;
        (child.material as THREE.MeshStandardMaterial).needsUpdate = true;
      }
    });
    gltf.scene.position.set(2, -4.65, -7);
    gltf.scene.scale.setScalar(0.72);
    scene.add(gltf.scene);
  }).catch(() => { /* procedural cauldron remains */ });

  // Bougies: 3 instances, scale 0.42 for candle-height consistency
  loadGLB('/bougie.glb').then((gltf) => {
    for (const [cx, cy, cz] of CANDLE_POSITIONS) {
      const clone = gltf.scene.clone(true);
      clone.scale.setScalar(0.42);
      clone.position.set(cx, cy, cz);
      scene.add(clone);
    }
  }).catch(() => { /* procedural candle bodies remain */ });

  // Table druidique: anchored to map-table zone position
  loadGLB('/table_druidique.glb').then((gltf) => {
    gltf.scene.position.set(-5, -5.0, -3);
    gltf.scene.scale.setScalar(1.0);
    scene.add(gltf.scene);
  }).catch(() => { /* procedural map table remains */ });

  // Bibliothèque: right-wall zone, slight z-scale reduction to fit depth
  loadGLB('/bibliotheque.glb').then((gltf) => {
    gltf.scene.position.set(8.8, -5.0, -8);
    gltf.scene.scale.set(1.2, 1.0, 0.8);
    scene.add(gltf.scene);
  }).catch(() => { /* procedural bookshelf remains */ });
}
