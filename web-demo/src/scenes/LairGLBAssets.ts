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
  wallsGroup?: THREE.Group;  // full walls group hidden when mur_pierre.glb loads
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

  // Mur pierre: Blender stone wall tile (126 polys). Scaled to cover the back wall (24×16 units).
  // Positioned 0.02 in front of the procedural back wall (z=-10) to avoid z-fighting.
  // Left and right walls rotated 90° from the same GLB.
  loadGLB('/mur_pierre.glb').then((gltf) => {
    // Back wall
    const back = gltf.scene.clone(true);
    back.scale.set(24, 16, 1);
    back.position.set(0, 3, -9.76);
    scene.add(back);
    // Left wall (rotated 90° around Y)
    const left = gltf.scene.clone(true);
    left.scale.set(20, 16, 1);
    left.rotation.y = Math.PI / 2;
    left.position.set(-11.76, 3, 0);
    scene.add(left);
    // Right wall (rotated -90° around Y)
    const right = gltf.scene.clone(true);
    right.scale.set(20, 16, 1);
    right.rotation.y = -Math.PI / 2;
    right.position.set(11.76, 3, 0);
    scene.add(right);
    if (proceduralGroups?.wallsGroup) proceduralGroups.wallsGroup.visible = false;
  }).catch(() => { /* procedural stone walls remain */ });
}
