// LairGLBAssets — Async GLB overlays for MerlinLairScene.
// Each GLB replaces the procedural mesh; on success the procedural group is hidden.
// On load failure, procedural fallback stays visible.

import * as THREE from 'three';
import { loadGLB } from '../engine/AssetLoader';

const CANDLE_POSITIONS: Array<[number, number, number]> = [
  [-5, -4.85, -7],
  [0, -4.85, -8.5],
  [3, -4.85, -6],
];

export interface LairProceduralGroups {
  mapGroup: THREE.Group;
  shelfGroup: THREE.Group;
  floorMesh?: THREE.Mesh;
  wallsGroup?: THREE.Group;    // full walls group hidden when mur_pierre.glb loads
  cauldronGroup?: THREE.Group; // procedural cauldron body+legs hidden when cauldron_merlin.glb loads
}

export function loadLairGLBs(
  scene: THREE.Scene,
  proceduralGroups?: LairProceduralGroups,
): void {
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
    if (proceduralGroups?.cauldronGroup) proceduralGroups.cauldronGroup.visible = false;
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

  // Table druidique: anchored to map-table zone. Hide procedural mapGroup on success.
  loadGLB('/table_druidique.glb').then((gltf) => {
    gltf.scene.position.set(-5, -5.0, -3);
    gltf.scene.scale.setScalar(1.0);
    scene.add(gltf.scene);
    if (proceduralGroups) proceduralGroups.mapGroup.visible = false;
  }).catch(() => { /* procedural map table remains */ });

  // Bibliothèque: right-wall zone. Hide procedural shelfGroup on success.
  loadGLB('/bibliotheque.glb').then((gltf) => {
    gltf.scene.position.set(8.8, -5.0, -8);
    gltf.scene.scale.set(1.2, 1.0, 0.8);
    scene.add(gltf.scene);
    if (proceduralGroups) proceduralGroups.shelfGroup.visible = false;
  }).catch(() => { /* procedural bookshelf remains */ });

  // Sol pierre: Blender flagstone floor (97 polys, vertex-colored).
  // Positioned 0.02 above procedural floor to avoid z-fighting without needing a mesh ref.
  loadGLB('/sol_pierre.glb').then((gltf) => {
    gltf.scene.position.set(0, -4.98, 0);
    gltf.scene.scale.set(1.0, 1.0, 1.0);
    scene.add(gltf.scene);
    if (proceduralGroups?.floorMesh) proceduralGroups.floorMesh.visible = false;
  }).catch(() => { /* procedural floor remains */ });

  // Mur pierre: Blender stone tile (5 rows × 4 stones = 126 polys).
  // Tiled in a grid to preserve stone aspect ratio (avoid 6× horizontal stretch).
  // Back wall: 6 tiles × 4u wide = 24u total. Left/right: 5 tiles × 4u = 20u total.
  loadGLB('/mur_pierre.glb').then((gltf) => {
    // Back wall: 6 tiles side by side (z-offset 0.02 in front of procedural wall)
    for (let i = 0; i < 6; i++) {
      const tile = gltf.scene.clone(true);
      tile.scale.set(4, 16, 1);
      tile.position.set(-10 + i * 4, 3, -9.76);
      scene.add(tile);
    }
    // Left wall: 5 tiles along depth, rotated 90°
    for (let i = 0; i < 5; i++) {
      const tile = gltf.scene.clone(true);
      tile.scale.set(4, 16, 1);
      tile.rotation.y = Math.PI / 2;
      tile.position.set(-11.76, 3, -8 + i * 4);
      scene.add(tile);
    }
    // Right wall: 5 tiles along depth, rotated -90°
    for (let i = 0; i < 5; i++) {
      const tile = gltf.scene.clone(true);
      tile.scale.set(4, 16, 1);
      tile.rotation.y = -Math.PI / 2;
      tile.position.set(11.76, 3, -8 + i * 4);
      scene.add(tile);
    }
    if (proceduralGroups?.wallsGroup) proceduralGroups.wallsGroup.visible = false;
  }).catch(() => { /* procedural stone walls remain */ });
}
