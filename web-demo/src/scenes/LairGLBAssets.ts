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
  candleGroup?: THREE.Group;   // procedural candle bodies+wicks+light hidden when bougie.glb loads
  onCauldronGLBLoaded?: (bodyMesh: THREE.Mesh) => void; // callback to update visualMesh in interactives[]
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
    // Update interactives[] visualMesh to the GLB body so hover emissive works on GLB path
    if (proceduralGroups?.onCauldronGLBLoaded) {
      const glbMeshes: THREE.Mesh[] = [];
      gltf.scene.traverse((child) => { if (child instanceof THREE.Mesh) glbMeshes.push(child); });
      // Prefer a mesh named 'body' or 'bowl'; fall back to first mesh if none match
      const bodyMesh = glbMeshes.find((m) => /body|bowl/i.test(m.name)) ?? glbMeshes[0];
      if (bodyMesh) {
        (bodyMesh.material as THREE.MeshStandardMaterial).emissive = new THREE.Color(0x00aa33);
        (bodyMesh.material as THREE.MeshStandardMaterial).emissiveIntensity = 0.0;
        proceduralGroups.onCauldronGLBLoaded(bodyMesh);
      }
    }
  }).catch(() => { /* procedural cauldron remains */ });

  // Bougies: 3 instances, scale 0.42 for candle-height consistency.
  // Each clone gets its own material instances (BUG-L-10: shared refs cause
  // all candles to change colour together on hover — breaks flicker animation).
  loadGLB('/bougie.glb').then((gltf) => {
    for (const [cx, cy, cz] of CANDLE_POSITIONS) {
      const clone = gltf.scene.clone(true);
      clone.traverse((child) => {
        if (child instanceof THREE.Mesh) {
          child.material = (child.material as THREE.MeshStandardMaterial).clone();
        }
      });
      clone.scale.setScalar(0.42);
      clone.position.set(cx, cy, cz);
      scene.add(clone);
    }
    if (proceduralGroups?.candleGroup) proceduralGroups.candleGroup.visible = false;
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
  // 3 vertical rows × N horizontal cols to preserve stone aspect ratio (~1:1.07 vs previous 1:3.2).
  // Wall spans y=-5 to y=11 (height 16). Each row is 16/3 ≈ 5.33u tall.
  // Back wall: 6 cols × 3 rows = 18 tiles. Left/right: 5 cols × 3 rows = 15 tiles each.
  loadGLB('/mur_pierre.glb').then((gltf) => {
    const ROW_H = 16 / 3;
    const rowY = (r: number) => -5 + ROW_H * (r + 0.5);
    // Back wall: 6 cols × 3 rows (z-offset 0.02 in front of procedural wall)
    for (let r = 0; r < 3; r++) {
      for (let i = 0; i < 6; i++) {
        const tile = gltf.scene.clone(true);
        tile.scale.set(4, ROW_H, 1);
        tile.position.set(-10 + i * 4, rowY(r), -9.76);
        scene.add(tile);
      }
    }
    // Left wall: 5 cols × 3 rows, rotated 90°
    for (let r = 0; r < 3; r++) {
      for (let i = 0; i < 5; i++) {
        const tile = gltf.scene.clone(true);
        tile.scale.set(4, ROW_H, 1);
        tile.rotation.y = Math.PI / 2;
        tile.position.set(-11.76, rowY(r), -8 + i * 4);
        scene.add(tile);
      }
    }
    // Right wall: 5 cols × 3 rows, rotated -90°
    for (let r = 0; r < 3; r++) {
      for (let i = 0; i < 5; i++) {
        const tile = gltf.scene.clone(true);
        tile.scale.set(4, ROW_H, 1);
        tile.rotation.y = -Math.PI / 2;
        tile.position.set(11.76, rowY(r), -8 + i * 4);
        scene.add(tile);
      }
    }
    if (proceduralGroups?.wallsGroup) proceduralGroups.wallsGroup.visible = false;
  }).catch(() => { /* procedural stone walls remain */ });
}
