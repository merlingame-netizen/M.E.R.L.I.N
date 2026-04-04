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

// C97: GLB fade-in — prevents hard pop-in on slow connections.
// Fades all mesh opacities from 0 → 1 over durationMs via rAF.
// Restores transparent=false after completion to avoid depth-sort artifacts.
// C122: pass isDisposed so the rAF tick auto-stops when the lair is disposed mid-fade —
// avoids writing to materials on a renderer that has already been torn down.
function fadeInGLB(group: THREE.Object3D, durationMs = 400, isDisposed?: () => boolean): () => void {
  let cancelled = false;
  const meshes: THREE.Mesh[] = [];
  group.traverse((child) => {
    if (child instanceof THREE.Mesh) {
      // C120: instanceof guard — Blender GLTF always produces MeshStandardMaterial but guard
      // prevents silent failure if any future GLB path brings MeshBasicMaterial (matches C119 philosophy)
      if (!(child.material instanceof THREE.MeshStandardMaterial)) return;
      child.material.transparent = true;
      child.material.opacity = 0;
      child.material.needsUpdate = true;
      meshes.push(child);
    }
  });
  if (meshes.length === 0) return () => { /* nothing to cancel */ };
  const start = performance.now();
  const tick = (): void => {
    if (cancelled || isDisposed?.()) return; // C122: bail out if scene was disposed during fade
    const t = Math.min((performance.now() - start) / durationMs, 1);
    for (const m of meshes) {
      if (m.material instanceof THREE.MeshStandardMaterial) m.material.opacity = t;
    }
    if (t < 1) {
      requestAnimationFrame(tick);
    } else {
      for (const m of meshes) {
        if (!(m.material instanceof THREE.MeshStandardMaterial)) continue;
        m.material.opacity = 1;
        m.material.transparent = false;
        m.material.needsUpdate = true;
      }
    }
  };
  requestAnimationFrame(tick);
  return () => { cancelled = true; };
}

// C101: enforce flat-shading on all non-crystal GLBs to match procedural mesh aesthetic
function applyFlatShading(obj: THREE.Object3D): void {
  obj.traverse((child) => {
    if (child instanceof THREE.Mesh) {
      // C120: instanceof guard — consistent with C119/fadeInGLB; MeshBasicMaterial has no flatShading
      if (!(child.material instanceof THREE.MeshStandardMaterial)) return;
      child.material.flatShading = true;
      child.material.needsUpdate = true;
    }
  });
}

export interface LairProceduralGroups {
  mapGroup: THREE.Group;
  shelfGroup: THREE.Group;
  floorMesh?: THREE.Mesh;
  wallsGroup?: THREE.Group;    // full walls group hidden when mur_pierre.glb loads
  cauldronGroup?: THREE.Group; // procedural cauldron body+legs hidden when cauldron_merlin.glb loads
  candleGroup?: THREE.Group;   // procedural candle bodies+wicks+light hidden when bougie.glb loads
  crystalSphere?: THREE.Mesh;  // C93-P2: procedural sphere hidden when crystal_ball.glb loads (hitTarget/light stay)
  onCauldronGLBLoaded?: (bodyMesh: THREE.Mesh) => void; // callback to update visualMesh in interactives[]
  onCrystalGLBLoaded?: (mesh: THREE.Mesh) => void;      // C95: callback to swap visualMesh to GLB mesh for hover emissive
  onCrystalGroupLoaded?: (group: THREE.Group) => void;  // C101: callback to store GLB group ref for float animation
  onMapGLBLoaded?: (mesh: THREE.Mesh) => void;          // C121: swap map interactives entry to GLB mesh (mapGroup hidden on load)
  onShelfGLBLoaded?: (mesh: THREE.Mesh) => void;        // C122: swap bookshelf interactives entry to GLB mesh (shelfGroup hidden on load)
}

export function loadLairGLBs(
  scene: THREE.Scene,
  proceduralGroups?: LairProceduralGroups,
  // C81-03: caller passes () => true after lair.dispose() fires — prevents late scene.add()
  isDisposed?: () => boolean,
): () => void {
  // C133: collect cancel handles so dispose() can stop any in-progress fade-in rAFs immediately.
  // Without this, fadeInGLB rAFs run 1 extra frame after dispose (guarded by isDisposed, but wasteful).
  const cancelHandles: Array<() => void> = [];

  // Cauldron: Blender low-poly (bois brun + métal sombre, 34 polys, validated)
  loadGLB('/cauldron_merlin.glb').then((gltf) => {
    if (isDisposed?.()) return; // C81-03: abort if lair already disposed
    gltf.scene.traverse((child) => {
      if (child instanceof THREE.Mesh) {
        // C81-04: clone material before mutation to avoid polluting the cached GLB prototype
        child.material = (child.material as THREE.MeshStandardMaterial).clone();
        (child.material as THREE.MeshStandardMaterial).roughness = 0.9;
        (child.material as THREE.MeshStandardMaterial).metalness = 0.0;
        (child.material as THREE.MeshStandardMaterial).flatShading = true;
        (child.material as THREE.MeshStandardMaterial).needsUpdate = true;
      }
    });
    gltf.scene.position.set(2, -4.65, -7);
    gltf.scene.scale.setScalar(0.72);
    scene.add(gltf.scene);
    cancelHandles.push(fadeInGLB(gltf.scene, 400, isDisposed)); // C97/C133
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
    if (isDisposed?.()) return; // C81-03
    for (const [cx, cy, cz] of CANDLE_POSITIONS) {
      const clone = gltf.scene.clone(true);
      clone.traverse((child) => {
        if (child instanceof THREE.Mesh) {
          child.material = (child.material as THREE.MeshStandardMaterial).clone();
          // C90-P1: set emissiveIntensity=0 baseline — guards against dirty emissive state
          // if a slow-loading GLB resolves after rapid hover/unhover cycles
          (child.material as THREE.MeshStandardMaterial).emissiveIntensity = 0.0;
          (child.material as THREE.MeshStandardMaterial).flatShading = true;
          (child.material as THREE.MeshStandardMaterial).needsUpdate = true;
        }
      });
      clone.scale.setScalar(0.42);
      clone.position.set(cx, cy, cz);
      scene.add(clone);
      cancelHandles.push(fadeInGLB(clone, 400, isDisposed)); // C97/C133
    }
    if (proceduralGroups?.candleGroup) {
      // C112: hide only non-Light children — sharedLight must stay active for candle warmth post-GLB
      proceduralGroups.candleGroup.children.forEach((child) => {
        if (!(child instanceof THREE.Light)) child.visible = false;
      });
    }
  }).catch(() => { /* procedural candle bodies remain */ });

  // Table druidique: anchored to map-table zone. Hide procedural mapGroup on success.
  loadGLB('/table_druidique.glb').then((gltf) => {
    if (isDisposed?.()) return; // C81-03
    gltf.scene.position.set(-5, -5.0, -3);
    gltf.scene.scale.setScalar(1.0);
    applyFlatShading(gltf.scene); // C101: match procedural flat-shading aesthetic
    // C128: polygonOffset guards against z-fighting on 16-bit depth GPUs (Mali-T720/Adreno 306).
    // table_druidique at Y=-5.0 is adjacent to sol_pierre at Y=-4.98 — same risk pattern as bibliotheque.
    gltf.scene.traverse((child) => {
      if (child instanceof THREE.Mesh) {
        const m = child.material;
        if (m instanceof THREE.MeshStandardMaterial) {
          m.polygonOffset = true;
          m.polygonOffsetFactor = -2;
          m.polygonOffsetUnits = -4;
          m.needsUpdate = true;
        }
      }
    });
    scene.add(gltf.scene);
    cancelHandles.push(fadeInGLB(gltf.scene, 400, isDisposed)); // C97/C133
    if (proceduralGroups) proceduralGroups.mapGroup.visible = false;
    // C121: notify scene so map interactives entry can swap hit target + visualMesh to GLB mesh.
    // Without this, raycaster skips the now-invisible procedural scroll and map zone is unclickable.
    if (proceduralGroups?.onMapGLBLoaded) {
      let firstMesh: THREE.Mesh | null = null;
      gltf.scene.traverse((child) => { if (!firstMesh && child instanceof THREE.Mesh) firstMesh = child; });
      if (firstMesh) proceduralGroups.onMapGLBLoaded(firstMesh);
    }
  }).catch(() => { /* procedural map table remains */ });

  // Bibliothèque: right-wall zone. Hide procedural shelfGroup on success.
  loadGLB('/bibliotheque.glb').then((gltf) => {
    if (isDisposed?.()) return; // C81-03
    gltf.scene.position.set(8.8, -5.0, -8);
    gltf.scene.scale.set(1.2, 1.0, 0.8);
    applyFlatShading(gltf.scene); // C101: match procedural flat-shading aesthetic
    // C125: non-uniform scale risks micro z-fighting against right-wall tiles at x=11.76.
    // Apply polygonOffset matching sol_pierre / mur_pierre pattern: factor=-2, units=-4.
    gltf.scene.traverse((child) => {
      if (child instanceof THREE.Mesh) {
        const m = child.material;
        if (m instanceof THREE.MeshStandardMaterial) {
          m.polygonOffset = true;
          m.polygonOffsetFactor = -2;
          m.polygonOffsetUnits = -4;
          m.needsUpdate = true;
        }
      }
    });
    scene.add(gltf.scene);
    cancelHandles.push(fadeInGLB(gltf.scene, 400, isDisposed)); // C97/C133
    if (proceduralGroups) proceduralGroups.shelfGroup.visible = false;
    // C122: shelfHit lives inside shelfGroup — becomes invisible to raycaster when group is hidden.
    // Mirror the onMapGLBLoaded pattern to swap interactives entry to the live GLB mesh.
    if (proceduralGroups?.onShelfGLBLoaded) {
      let firstMesh: THREE.Mesh | null = null;
      gltf.scene.traverse((child) => { if (!firstMesh && child instanceof THREE.Mesh) firstMesh = child; });
      if (firstMesh) proceduralGroups.onShelfGLBLoaded(firstMesh);
    }
  }).catch(() => { /* procedural bookshelf remains */ });

  // Sol pierre: Blender flagstone floor (97 polys, vertex-colored).
  // Positioned 0.02 above procedural floor to avoid z-fighting without needing a mesh ref.
  loadGLB('/sol_pierre.glb').then((gltf) => {
    if (isDisposed?.()) return; // C81-03
    gltf.scene.position.set(0, -4.98, 0);
    gltf.scene.scale.set(1.0, 1.0, 1.0);
    applyFlatShading(gltf.scene); // C101: match procedural flat-shading aesthetic
    // C112: polygonOffset guards against Z-fighting on 16-bit GPU depth buffers (Mali-T720/Adreno 306).
    // The 0.02u Y-offset alone is insufficient — at depth ~10u, 16-bit precision is ~0.05u.
    // Matches mur_pierre pattern: factor=-2, units=-4.
    gltf.scene.traverse((child) => {
      if (child instanceof THREE.Mesh) {
        const m = child.material as THREE.MeshStandardMaterial;
        m.polygonOffset = true;
        m.polygonOffsetFactor = -2;
        m.polygonOffsetUnits = -4;
        m.needsUpdate = true;
      }
    });
    scene.add(gltf.scene);
    cancelHandles.push(fadeInGLB(gltf.scene, 400, isDisposed)); // C97/C133
    if (proceduralGroups?.floorMesh) proceduralGroups.floorMesh.visible = false;
  }).catch(() => { /* procedural floor remains */ });

  // Mur pierre: C87 — InstancedMesh replaces 48 clones (48 draw calls → 3).
  // 3 InstancedMeshes (one per rotation: back=0°, left=+90°, right=-90°).
  // Wall spans y=-5 to y=11 (16u height). ROW_H = 16/3 ≈ 5.33u. Scale [4, ROW_H, 1] per tile.
  loadGLB('/mur_pierre.glb').then((gltf) => {
    if (isDisposed?.()) return; // C81-03
    // Extract first mesh geometry + material from GLB
    let tileGeo: THREE.BufferGeometry | null = null;
    let tileMat: THREE.Material | null = null;
    gltf.scene.traverse((child) => {
      if (!tileGeo && child instanceof THREE.Mesh) {
        tileGeo = child.geometry.clone(); // owned copy — safe to dispose independently
        tileMat = (child.material as THREE.MeshStandardMaterial).clone();
        // C89-P1: polygonOffset prevents micro z-fighting on tile seams (Mali/Adreno 16-bit depth)
        // C90-P2: factor/units bumped -1→-2/-4 — covers shallow camera angles to back wall
        (tileMat as THREE.MeshStandardMaterial).polygonOffset = true;
        (tileMat as THREE.MeshStandardMaterial).polygonOffsetFactor = -2;
        (tileMat as THREE.MeshStandardMaterial).flatShading = true; // C101: match scene aesthetic
        (tileMat as THREE.MeshStandardMaterial).polygonOffsetUnits = -4;
      }
    });
    if (!tileGeo || !tileMat) return;

    const ROW_H = 16 / 3;
    const rowY = (r: number): number => -5 + ROW_H * (r + 0.5);
    const dummy = new THREE.Object3D();

    // Back wall: 18 tiles (6 cols × 3 rows), rotY = 0
    const backMesh = new THREE.InstancedMesh(tileGeo, tileMat, 18);
    let idx = 0;
    for (let r = 0; r < 3; r++) {
      for (let i = 0; i < 6; i++) {
        dummy.position.set(-10 + i * 4, rowY(r), -9.76);
        dummy.scale.set(4, ROW_H, 1);
        dummy.rotation.set(0, 0, 0);
        dummy.updateMatrix();
        backMesh.setMatrixAt(idx++, dummy.matrix);
      }
    }
    backMesh.instanceMatrix.needsUpdate = true;
    scene.add(backMesh);

    // Left wall: 15 tiles (5 cols × 3 rows), rotY = +90°
    const leftMesh = new THREE.InstancedMesh(tileGeo, tileMat, 15);
    idx = 0;
    for (let r = 0; r < 3; r++) {
      for (let i = 0; i < 5; i++) {
        dummy.position.set(-11.76, rowY(r), -8 + i * 4);
        dummy.scale.set(4, ROW_H, 1);
        dummy.rotation.set(0, Math.PI / 2, 0);
        dummy.updateMatrix();
        leftMesh.setMatrixAt(idx++, dummy.matrix);
      }
    }
    leftMesh.instanceMatrix.needsUpdate = true;
    scene.add(leftMesh);

    // Right wall: 15 tiles (5 cols × 3 rows), rotY = -90°
    const rightMesh = new THREE.InstancedMesh(tileGeo, tileMat, 15);
    idx = 0;
    for (let r = 0; r < 3; r++) {
      for (let i = 0; i < 5; i++) {
        dummy.position.set(11.76, rowY(r), -8 + i * 4);
        dummy.scale.set(4, ROW_H, 1);
        dummy.rotation.set(0, -Math.PI / 2, 0);
        dummy.updateMatrix();
        rightMesh.setMatrixAt(idx++, dummy.matrix);
      }
    }
    rightMesh.instanceMatrix.needsUpdate = true;
    scene.add(rightMesh);

    if (proceduralGroups?.wallsGroup) proceduralGroups.wallsGroup.visible = false;
  }).catch(() => { /* procedural stone walls remain */ });

  // Crystal ball: C93-P2 — GLB overlay on procedural sphere. hitTarget + PointLight stay active.
  // C95: emissive purple set on GLB material (matching procedural crystal glow 0x6030aa).
  // C95: onCrystalGLBLoaded callback updates interactives[] visualMesh so hover emissive targets GLB.
  loadGLB('/crystal_ball.glb').then((gltf) => {
    if (isDisposed?.()) return;
    const glbMeshes: THREE.Mesh[] = [];
    gltf.scene.traverse((child) => {
      if (child instanceof THREE.Mesh) {
        child.material = (child.material as THREE.MeshStandardMaterial).clone();
        (child.material as THREE.MeshStandardMaterial).emissive = new THREE.Color(0x6030aa);
        (child.material as THREE.MeshStandardMaterial).emissiveIntensity = 0.6; // match procedural baseline
        (child.material as THREE.MeshStandardMaterial).needsUpdate = true;
        glbMeshes.push(child);
      }
    });
    gltf.scene.position.set(5, -1.0, -4);
    gltf.scene.scale.setScalar(0.8);
    scene.add(gltf.scene);
    cancelHandles.push(fadeInGLB(gltf.scene, 400, isDisposed)); // C97/C133
    if (proceduralGroups?.crystalSphere) proceduralGroups.crystalSphere.visible = false;
    if (proceduralGroups?.onCrystalGLBLoaded && glbMeshes.length > 0) {
      proceduralGroups.onCrystalGLBLoaded(glbMeshes[0]!);
    }
    // C101: pass the GLB group to the scene update loop so it inherits the procedural float animation
    proceduralGroups?.onCrystalGroupLoaded?.(gltf.scene);
  }).catch(() => { /* procedural crystal sphere remains */ });

  // C133: return cancel-all so MerlinLairScene.dispose() can stop any in-flight rAFs immediately
  return () => { cancelHandles.forEach((cancel) => cancel()); };
}
