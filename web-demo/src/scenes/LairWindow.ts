// LairWindow — Forest window with day/night/season cycle for MerlinLairScene.
// Window on back-right wall area [4, 3.5, -9.75], facing +Z (into scene).
// Forest silhouettes at z=-10.6 (behind glass). Light through window adapts to hour/season.

import { BoxGeometry, Color, ConeGeometry, DoubleSide, FrontSide, Group, Mesh, MeshBasicMaterial, MeshStandardMaterial, PlaneGeometry, Scene, SpotLight } from 'three';

export type Season = 'spring' | 'summer' | 'autumn' | 'winter';

export interface LairTimeParams {
  hour: number;   // 0–24
  season: Season;
}

interface WindowResult {
  group: Group;
  windowLight: SpotLight;
  updateTime: (params: LairTimeParams) => void;
  update: (elapsed: number) => void;
}

// ── Season tree colors ────────────────────────────────────────────────────────

const SEASON_TREE_COLOR: Record<Season, number> = {
  spring:  0x2e6e2e,
  summer:  0x1a4e1a,
  autumn:  0x8a3a08,
  winter:  0x2a2828,
};

const SEASON_SKY_COLOR: Record<Season, number> = {
  spring:  0x8ab4d4,
  summer:  0x6a9fc4,
  autumn:  0x8a7464,
  winter:  0x4a5464,
};

// ── Hour → window light parameters ───────────────────────────────────────────

function hourToLightParams(hour: number, season: Season): { color: Color; intensity: number } {
  // Wrap to [0, 24)
  const h = ((hour % 24) + 24) % 24;

  let color: Color;
  let intensity: number;

  if (h >= 5 && h < 8) {
    // Dawn: orange-pink blush
    const t = (h - 5) / 3;
    color = new Color().setRGB(1.0, 0.5 + t * 0.35, 0.2 + t * 0.5);
    intensity = 0.3 + t * 0.7;
  } else if (h >= 8 && h < 17) {
    // Day: warm white light
    const seasonBright = season === 'summer' ? 1.2 : season === 'winter' ? 0.85 : 1.0;
    color = new Color(0xfff5e0);
    intensity = 1.1 * seasonBright;
  } else if (h >= 17 && h < 20) {
    // Dusk: orange-red sunset
    const t = (h - 17) / 3;
    color = new Color().setRGB(1.0, 0.4 - t * 0.3, 0.05);
    intensity = 1.0 - t * 0.85;
  } else {
    // Night: cold moonlight
    const moonPhase = Math.sin((h / 24) * Math.PI) * 0.5 + 0.5;
    color = new Color().setRGB(0.15 + moonPhase * 0.05, 0.2 + moonPhase * 0.06, 0.38 + moonPhase * 0.12);
    intensity = 0.05 + moonPhase * 0.2;
  }

  return { color, intensity };
}

// ── Window construction ───────────────────────────────────────────────────────

export function createLairWindow(scene: Scene): WindowResult {
  const group = new Group();

  // Stone window frame (back wall z=-9.75)
  const frameMat = new MeshStandardMaterial({ color: 0x2e2924, roughness: 0.98, metalness: 0.0, flatShading: true });
  // Left jamb
  const jambL = new Mesh(new BoxGeometry(0.4, 4.4, 0.5), frameMat);
  jambL.position.set(2.6, 3.5, -9.75);
  group.add(jambL);
  // Right jamb
  const jambR = new Mesh(new BoxGeometry(0.4, 4.4, 0.5), frameMat);
  jambR.position.set(5.4, 3.5, -9.75);
  group.add(jambR);
  // Lintel (top)
  const lintel = new Mesh(new BoxGeometry(3.4, 0.4, 0.5), frameMat);
  lintel.position.set(4.0, 5.5, -9.75);
  group.add(lintel);
  // Sill (bottom)
  const sill = new Mesh(new BoxGeometry(3.4, 0.35, 0.7), frameMat);
  sill.position.set(4.0, 1.5, -9.65);
  group.add(sill);
  // Mullion (center vertical)
  const mullion = new Mesh(new BoxGeometry(0.15, 4.0, 0.45), frameMat);
  mullion.position.set(4.0, 3.5, -9.75);
  group.add(mullion);

  // Glass panes (semi-transparent, tinted by sky color)
  // C144/LAIR-WIN-01: polygonOffset prevents z-fighting with coplanar frame front face
  // (PlaneGeometry at z=-9.5 vs BoxGeometry depth=0.5 at z=-9.75 → front face at z=-9.5)
  const glassMat = new MeshStandardMaterial({
    color: 0x8ab4d4,
    transparent: true,
    opacity: 0.28,
    roughness: 0.05,
    metalness: 0.1,
    side: DoubleSide,
    polygonOffset: true,
    polygonOffsetFactor: -1,
    polygonOffsetUnits: -2,
  });
  const glassL = new Mesh(new PlaneGeometry(1.15, 3.85), glassMat);
  glassL.position.set(3.2, 3.5, -9.5);
  group.add(glassL);
  const glassR = new Mesh(new PlaneGeometry(1.15, 3.85), glassMat);
  glassR.position.set(4.8, 3.5, -9.5);
  group.add(glassR);

  // ── Forest exterior (behind glass, at z=-10.6) ────────────────────────────

  const treeMat = new MeshStandardMaterial({ color: 0x2e6e2e, roughness: 1.0, metalness: 0.0, flatShading: true });

  // Sky backdrop (flat plane behind trees)
  const skyMat = new MeshBasicMaterial({ color: 0x8ab4d4, side: FrontSide });
  const skyPane = new Mesh(new PlaneGeometry(2.8, 3.9), skyMat);
  skyPane.position.set(4.0, 3.5, -10.58);
  group.add(skyPane);

  // Tree silhouettes (flat low-poly planes acting as silhouettes)
  const treeConfigs: Array<{ x: number; h: number; w: number; trunkH: number }> = [
    { x: 3.0, h: 3.2, w: 0.5, trunkH: 1.4 },
    { x: 3.9, h: 4.0, w: 0.65, trunkH: 1.6 },
    { x: 5.0, h: 2.8, w: 0.44, trunkH: 1.0 },
  ];

  // Shared material for all trunks + canopies — all update to the same season color,
  // so cloning is wasteful (was creating 5 orphaned MeshStandardMaterial instances).
  // scene.traverse() in Lair dispose() handles disposal via any of the 6 shared-material meshes.
  const treeObjects: Mesh[] = [];

  for (const cfg of treeConfigs) {
    // Trunk — shares treeMat (same color as canopy per season)
    const trunkMesh = new Mesh(
      new BoxGeometry(0.12, cfg.trunkH, 0.12),
      treeMat
    );
    trunkMesh.position.set(cfg.x, 1.5 + cfg.trunkH / 2, -10.6);
    group.add(trunkMesh);

    // Canopy — shares treeMat
    const canopyMesh = new Mesh(
      new ConeGeometry(cfg.w, cfg.h, 5),
      treeMat
    );
    canopyMesh.position.set(cfg.x, 1.5 + cfg.trunkH + cfg.h / 2, -10.6);
    group.add(canopyMesh);
    treeObjects.push(canopyMesh); // only canopies need per-frame sway rotation
  }

  // ── Spotlight through window ──────────────────────────────────────────────

  const windowLight = new SpotLight(0xfff5e0, 1.0, 20, Math.PI / 5, 0.5, 1.8);
  windowLight.position.set(4.0, 5.0, -9.0);
  windowLight.target.position.set(2.5, -2.0, -3.0);  // casts onto floor below
  group.add(windowLight);        // in group so it disappears with the window if group.visible=false
  scene.add(windowLight.target); // target stays in world-space so lookAt works correctly

  // ── State ─────────────────────────────────────────────────────────────────

  let currentSeason: Season = 'spring';

  const updateTime = (params: LairTimeParams): void => {
    currentSeason = params.season;
    const { color, intensity } = hourToLightParams(params.hour, params.season);
    windowLight.color.copy(color);
    windowLight.intensity = intensity;

    // Update sky backdrop color
    const skyCol = new Color(SEASON_SKY_COLOR[params.season]);
    // Mix with time-of-day darkness
    const dayFactor = Math.max(0, Math.min(1, intensity / 1.2));
    skyMat.color.copy(skyCol).multiplyScalar(0.2 + dayFactor * 0.8);

    // Update glass tint
    glassMat.color.copy(skyCol).multiplyScalar(0.6 + dayFactor * 0.4);

    // Update shared tree material color — one write affects all 6 trunk+canopy meshes
    const treeCol = new Color(SEASON_TREE_COLOR[params.season]);
    treeMat.color.copy(params.season === 'winter' ? new Color(0x2a2828) : treeCol);
  };

  const update = (elapsed: number): void => {
    // Gentle leaf sway (only during day, only spring/summer)
    if (currentSeason === 'spring' || currentSeason === 'summer') {
      treeObjects.forEach((t, i) => {
        t.rotation.z = Math.sin(elapsed * 0.7 + i * 1.2) * 0.04;
      });
    }
    // C50: glass shimmers at night only (moonlight reflection) — stable by day.
    // windowLight.intensity tracks day/night: ~1.0 at noon, ~0.0 at midnight.
    const nightWeight = Math.max(0, 1 - Math.min(1, windowLight.intensity));
    glassMat.opacity = 0.28 - nightWeight * 0.05 + Math.sin(elapsed * 0.4) * 0.02 * nightWeight;
  };

  scene.add(group);
  return { group, windowLight, updateTime, update };
}
