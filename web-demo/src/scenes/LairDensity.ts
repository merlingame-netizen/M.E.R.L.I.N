// LairDensity — extracted from MerlinLairScene (Cycle 34) to stay under 800-line limit.
// Adds shelves+books, moonlight SpotLight, parchment rolls to the lair scene.

import { BoxGeometry, CylinderGeometry, Group, Mesh, MeshStandardMaterial, PointLight, Scene, SpotLight } from 'three';

/** Add shelves, moonlight shaft and parchment rolls to the lair scene.
 *  Returns a cleanup callback that removes the SpotLight target from the scene —
 *  moon.target is world-space (scene.add) so it won't be caught by traverse() in dispose(). */
export function createLairDensity(scene: Scene): () => void {
  const group = new Group();

  const sM = new MeshStandardMaterial({ color: 0x3d2b1a, roughness: 0.85, metalness: 0.0, flatShading: true });
  const bC = [0x6b1a1a, 0x1a3a6b, 0x2a5a1a, 0x5a4a10, 0x3a1060];
  for (const [y, z] of [[1.5, -2.0], [-0.5, 0.5], [2.5, 3.5]] as [number, number][]) {
    const plank = new Mesh(new BoxGeometry(0.15, 3.2, 0.7), sM);
    plank.position.set(-11.4, y, z); group.add(plank);
    for (let b = 0; b < 5; b++) {
      const bw = 0.3 + (b * 0.09) % 0.14, bh = 0.8 + (b * 0.13) % 0.45;
      const book = new Mesh(new BoxGeometry(bw, bh, 0.55),
        new MeshStandardMaterial({ color: bC[b % bC.length]!, roughness: 0.8, metalness: 0.0, flatShading: true }));
      book.position.set(-11.55, y - 1.2 + bh / 2, z - 0.8 + b * 0.35); group.add(book);
    }
  }
  const moon = new SpotLight(0xb8d4ff, 1.8, 18, Math.PI / 9, 0.45, 1.5);
  moon.position.set(-9, 9, 0); moon.target.position.set(-4, -3, 0);
  group.add(moon);           // in group so light disappears with density objects
  scene.add(moon.target);   // target stays in world-space for correct lookAt
  const pM = new MeshStandardMaterial({ color: 0xd4b878, roughness: 0.9, metalness: 0.0, flatShading: true });
  for (const [x, z, ry] of [[-3.5, 3.2, 0.4], [-2.0, 4.0, -0.3], [-4.8, 2.0, 0.9]] as [number, number, number][]) {
    const roll = new Mesh(new CylinderGeometry(0.07, 0.07, 0.7, 7), pM);
    roll.rotation.z = Math.PI / 2; roll.rotation.y = ry;
    roll.position.set(x, -4.8, z); group.add(roll);
  }
  // C36: warm amber accent for right-wall bibliotheque zone (no dedicated light before)
  const biblio = new PointLight(0xffa040, 0.6, 6, 2);
  biblio.position.set(10, -3.5, -7);
  group.add(biblio);

  scene.add(group);
  // C35: return cleanup so MerlinLairScene.dispose() can remove the world-space target
  return () => { scene.remove(moon.target); };
}
