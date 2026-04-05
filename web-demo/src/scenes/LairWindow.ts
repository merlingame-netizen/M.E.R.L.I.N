// LairWindow — Forest window with day/night/season cycle for MerlinLairScene.
// Window on back-right wall area [4, 3.5, -9.75], facing +Z (into scene).
// Forest silhouettes at z=-10.6 (behind glass). Light through window adapts to hour/season.

import { BoxGeometry, Color, ConeGeometry, DoubleSide, FrontSide, Group, Mesh, MeshBasicMaterial, MeshStandardMaterial, PlaneGeometry, PointLight, Scene, SphereGeometry, SpotLight } from 'three';

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
    // Dawn: cool blue-green forest light (CeltOS forest palette — no amber)
    const t = (h - 5) / 3;
    color = new Color().setRGB(0.3 + t * 0.4, 0.55 + t * 0.35, 0.45 + t * 0.3);
    intensity = 0.3 + t * 0.7;
  } else if (h >= 8 && h < 17) {
    // Day: cool forest-filtered daylight
    const seasonBright = season === 'summer' ? 1.2 : season === 'winter' ? 0.85 : 1.0;
    color = new Color(0xd4f0e8);
    intensity = 1.1 * seasonBright;
  } else if (h >= 17 && h < 20) {
    // Dusk: deep forest blue-green fade (CeltOS — no sunset amber)
    const t = (h - 17) / 3;
    color = new Color().setRGB(0.1 + t * 0.05, 0.25 - t * 0.1, 0.35 - t * 0.1);
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

  // Stone window frame (back wall z=-9.75) — emissive for glow pulse
  const frameMat = new MeshStandardMaterial({
    color: 0x2e2924,
    roughness: 0.98,
    metalness: 0.0,
    flatShading: true,
    emissive: new Color(0x002200),
    emissiveIntensity: 0.03,
  });
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

  const windowLight = new SpotLight(0xd4f0e8, 1.0, 20, Math.PI / 5, 0.5, 1.8);
  windowLight.position.set(4.0, 5.0, -9.0);
  windowLight.target.position.set(2.5, -2.0, -3.0);  // casts onto floor below
  group.add(windowLight);        // in group so it disappears with the window if group.visible=false
  scene.add(windowLight.target); // target stays in world-space so lookAt works correctly

  // ── Window interior glow light (portal effect — breathes on 8s cycle) ────

  const windowInteriorLight = new PointLight(0x22ff66, 0.15, 6);
  windowInteriorLight.position.set(4.0, 3.5, -9.2); // just inside the window on the room side
  group.add(windowInteriorLight);

  // ── Stars (visible in night-sky backdrop behind the glass) ───────────────

  const starMat = new MeshStandardMaterial({
    color: 0xffffff,
    emissive: new Color(0xd4f0ff),
    emissiveIntensity: 0.6,
    roughness: 1.0,
    metalness: 0.0,
  });

  // 6 star positions scattered across the upper sky area visible through the glass
  const starPositions: Array<[number, number]> = [
    [3.15, 5.1],
    [3.55, 4.7],
    [4.25, 5.3],
    [4.65, 4.85],
    [4.85, 5.15],
    [3.8,  5.0],
  ];

  const starMeshes: Mesh[] = starPositions.map(([sx, sy]) => {
    const starMesh = new Mesh(new SphereGeometry(0.04, 3, 2), starMat);
    starMesh.position.set(sx, sy, -10.55); // just in front of sky backdrop
    starMesh.visible = false; // shown only at night via updateTime
    group.add(starMesh);
    return starMesh;
  });

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

    // Show stars only at night (h < 5 || h >= 20)
    const h = ((params.hour % 24) + 24) % 24;
    const isNight = h < 5 || h >= 20;
    starMeshes.forEach(s => { s.visible = isNight; });
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
    // C150/LW-NIGHT-CLAMP-01: clamp intensity to [0,1] before inversion — a negative
    // intensity (valid Three.js for subtractive light) would produce nightWeight > 1,
    // making glassMat.opacity exceed its [0,1] domain (opacity = 0.28 + ~0.07 at night).
    // Three.js clamps opacity silently but the shimmer amplitude formula breaks.
    const nightWeight = 1 - Math.min(1, Math.max(0, windowLight.intensity));
    glassMat.opacity = 0.28 - nightWeight * 0.05 + Math.sin(elapsed * 0.4) * 0.02 * nightWeight;

    // Window portal glow — 8-second breathing cycle (forest green pulse)
    const breathe = Math.sin(elapsed * (Math.PI * 2 / 8)); // -1 .. 1, period = 8s
    frameMat.emissiveIntensity = 0.075 + breathe * 0.045; // oscillates 0.03 .. 0.12
    windowInteriorLight.intensity = 0.15 + breathe * 0.08; // oscillates 0.07 .. 0.23
  };

  scene.add(group);
  return { group, windowLight, updateTime, update };
}
