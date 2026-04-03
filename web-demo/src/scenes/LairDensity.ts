// LairDensity — extracted from MerlinLairScene (Cycle 34) to stay under 800-line limit.
// Adds shelves+books, moonlight SpotLight, parchment rolls to the lair scene.

import * as THREE from 'three';

/** Add shelves, moonlight shaft and parchment rolls to the lair scene. */
export function createLairDensity(scene: THREE.Scene): void {
  const sM = new THREE.MeshStandardMaterial({ color: 0x3d2b1a, roughness: 0.85, metalness: 0.0, flatShading: true });
  const bC = [0x6b1a1a, 0x1a3a6b, 0x2a5a1a, 0x5a4a10, 0x3a1060];
  for (const [y, z] of [[1.5, -2.0], [-0.5, 0.5], [2.5, 3.5]] as [number, number][]) {
    const plank = new THREE.Mesh(new THREE.BoxGeometry(0.15, 3.2, 0.7), sM);
    plank.position.set(-11.4, y, z); scene.add(plank);
    for (let b = 0; b < 5; b++) {
      const bw = 0.3 + (b * 0.09) % 0.14, bh = 0.8 + (b * 0.13) % 0.45;
      const book = new THREE.Mesh(new THREE.BoxGeometry(bw, bh, 0.55),
        new THREE.MeshStandardMaterial({ color: bC[b % bC.length]!, roughness: 0.8, metalness: 0.0, flatShading: true }));
      book.position.set(-11.55, y - 1.2 + bh / 2, z - 0.8 + b * 0.35); scene.add(book);
    }
  }
  const moon = new THREE.SpotLight(0xb8d4ff, 1.8, 18, Math.PI / 9, 0.45, 1.5);
  moon.position.set(-9, 9, 0); moon.target.position.set(-4, -3, 0);
  scene.add(moon); scene.add(moon.target);
  const pM = new THREE.MeshStandardMaterial({ color: 0xd4b878, roughness: 0.9, metalness: 0.0, flatShading: true });
  for (const [x, z, ry] of [[-3.5, 3.2, 0.4], [-2.0, 4.0, -0.3], [-4.8, 2.0, 0.9]] as [number, number, number][]) {
    const roll = new THREE.Mesh(new THREE.CylinderGeometry(0.07, 0.07, 0.7, 7), pM);
    roll.rotation.z = Math.PI / 2; roll.rotation.y = ry;
    roll.position.set(x, -4.8, z); scene.add(roll);
  }
}
