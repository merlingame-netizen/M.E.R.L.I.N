// LairWindow — Forest window with day/night/season cycle for MerlinLairScene.
// Window on back-right wall area [4, 3.5, -9.75], facing +Z (into scene).
// Forest silhouettes at z=-10.6 (behind glass). Light through window adapts to hour/season.

import { BoxGeometry, BufferGeometry, CircleGeometry, Color, ConeGeometry, DoubleSide, Float32BufferAttribute, FrontSide, Group, MathUtils, Mesh, MeshBasicMaterial, MeshStandardMaterial, PlaneGeometry, PointLight, Points, PointsMaterial, Scene, SphereGeometry, SpotLight } from 'three';

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

  // ── Starfield — 30 points in two tiers (dim + bright), z=-9.4 behind glass ─

  // Module-level state (outer-var pattern per task spec)
  let _starPoints: Points | null = null;
  let _shootingStar: Mesh | null = null;
  let _shootingStarTimer = 0;          // countdown to next shot (seconds)
  let _shootingStarActive = false;     // true while streak is travelling
  let _shootingStarProgress = 0;       // 0..1 across 0.6 s travel

  {
    // --- dim tier: 20 stars, color 0x1a4422, size 0.025
    // --- bright tier: 10 stars, color 0x33ff66, size 0.04
    // Two separate Points objects so each can have its own PointsMaterial
    // (PointsMaterial.size is per-material, not per-vertex in WebGL 1 fallback).

    const dimGeo = new BufferGeometry();
    const dimPositions: number[] = [];
    for (let i = 0; i < 20; i++) {
      dimPositions.push(
        -6 + Math.random() * 12,  // x ∈ [-6, 6]
        3  + Math.random() * 6,   // y ∈ [3, 9]
        -9.4,                     // z — behind window glass plane
      );
    }
    dimGeo.setAttribute('position', new Float32BufferAttribute(dimPositions, 3));

    const brightGeo = new BufferGeometry();
    const brightPositions: number[] = [];
    for (let i = 0; i < 10; i++) {
      brightPositions.push(
        -6 + Math.random() * 12,
        3  + Math.random() * 6,
        -9.4,
      );
    }
    brightGeo.setAttribute('position', new Float32BufferAttribute(brightPositions, 3));

    const dimMat = new PointsMaterial({
      color: 0x1a4422,
      size: 0.025,
      transparent: true,
      opacity: 0,
      depthWrite: false,
    });
    const brightMat = new PointsMaterial({
      color: 0x33ff66,
      size: 0.04,
      transparent: true,
      opacity: 0,
      depthWrite: false,
    });

    const dimPoints  = new Points(dimGeo,    dimMat);
    const brightPoints = new Points(brightGeo, brightMat);

    // Bundle both into a single Group so we can add them together and address
    // them via _starPoints userData — but the task spec asks for a single
    // _starPoints; store the bright one there and dim as a sibling.
    // We'll animate both by walking group.children in update().
    group.add(dimPoints);
    group.add(brightPoints);
    // _starPoints references the bright one (used for visible toggle check)
    _starPoints = brightPoints;
    // Tag both so update() can find them
    dimPoints.userData['starTier']    = 'dim';
    brightPoints.userData['starTier'] = 'bright';
  }

  // ── Shooting star (periodic diagonal streak) ──────────────────────────────

  {
    const ssMat = new MeshBasicMaterial({
      color: 0x33ff66,
      transparent: true,
      opacity: 0,
    });
    const ssMesh = new Mesh(new BoxGeometry(0.8, 0.02, 0.01), ssMat);
    // Orient the streak diagonally: from (-5,8) to (5,4) → angle ≈ -21.8°
    ssMesh.rotation.z = Math.atan2(4 - 8, 5 - (-5)); // atan2(dy, dx) → negative (downward)
    ssMesh.position.set(-5, 8, -9.35);
    ssMesh.visible = false;
    group.add(ssMesh);
    _shootingStar = ssMesh;
    // Schedule first shot: random delay in [8, 12] seconds
    _shootingStarTimer = 8 + Math.random() * 4;
  }

  // ── Moon disc (night + dawn, CeltOS pale green-white) ────────────────────

  let moonMesh: Mesh | null = null;
  const moonMat = new MeshBasicMaterial({ color: 0xddeedd, transparent: true, opacity: 0 });
  moonMesh = new Mesh(new CircleGeometry(1.2, 16), moonMat);
  moonMesh.position.set(4, 5, -9.5);
  group.add(moonMesh);

  // ── Aurora bands (3 horizontal planes, CeltOS green, night only) ─────────

  let auroraMeshes: Mesh[] = [];
  const auroraYPositions = [7.5, 8.2, 8.9];
  auroraMeshes = auroraYPositions.map((y, i) => {
    const mat = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0, side: DoubleSide });
    const mesh = new Mesh(new PlaneGeometry(12, 0.4), mat);
    mesh.position.set(0, y, -9.5);
    mesh.userData['phase'] = i * 0.8;
    group.add(mesh);
    return mesh;
  });

  // ── Fireflies (visible outside window at night + dusk) ───────────────────

  let _windowFireflies: Mesh[] = [];
  let _prevElapsed = 0;

  {
    const flyMat = new MeshBasicMaterial({ color: 0x33ff66, transparent: true, opacity: 0 });
    const flyGeo = new SphereGeometry(0.06, 4, 3);
    for (let i = 0; i < 7; i++) {
      const mesh = new Mesh(flyGeo, flyMat.clone());
      const sx = -3 + Math.random() * 8;          // x ∈ [-3, 5]
      const sy = 2 + Math.random() * 5;            // y ∈ [2, 7]
      const sz = -9.3 - Math.random() * 0.8;       // z ∈ [-9.3, -8.5] — just outside pane
      mesh.position.set(sx, sy, sz);
      mesh.userData = {
        phase:  Math.random() * Math.PI * 2,
        vx:     (Math.random() - 0.5) * 0.3,
        vy:     (Math.random() - 0.5) * 0.15,
        startX: sx,
        startY: sy,
        startZ: sz,
      };
      group.add(mesh);
      _windowFireflies.push(mesh);
    }
  }

  // ── Rain streaks on glass pane (night + dusk, z=-9.3, in front of glass) ──

  const _rainStreaks: Mesh[] = [];

  {
    const streakMat = new MeshBasicMaterial({
      color: 0x1a4433,
      transparent: true,
      opacity: 0,
      depthWrite: false,
    });
    const streakGeo = new BoxGeometry(0.02, 0.3, 0.01);
    for (let i = 0; i < 15; i++) {
      const mesh = new Mesh(streakGeo, streakMat.clone());
      const sx = -4 + Math.random() * 8;     // x ∈ [-4, 4] — across the window frame
      const sy = 3 + Math.random() * 5;      // y ∈ [3, 8]
      mesh.position.set(sx + 4.0, sy, -9.3); // offset by window center x=4.0
      mesh.rotation.z = 0.05;               // slight wind-drift angle
      mesh.userData = {
        speed:  2.0 + Math.random() * 2.5,  // 2.0 – 4.5 units/s
      };
      mesh.visible = false;
      group.add(mesh);
      _rainStreaks.push(mesh);
    }
  }

  // ── State ─────────────────────────────────────────────────────────────────

  let currentSeason: Season = 'spring';
  let currentTimeOfDay: 'day' | 'dawn' | 'dusk' | 'night' = 'day';

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

    // Show star Points tiers only at night (h < 5 || h >= 20)
    const h = ((params.hour % 24) + 24) % 24;
    const isNight = h < 5 || h >= 20;
    if (_starPoints !== null) {
      group.children.forEach(child => {
        if ((child as Points).userData['starTier'] !== undefined) {
          child.visible = isNight;
        }
      });
    }

    // Track time-of-day for moon/aurora lerp targets
    if (h >= 5 && h < 8) {
      currentTimeOfDay = 'dawn';
    } else if (h >= 8 && h < 17) {
      currentTimeOfDay = 'day';
    } else if (h >= 17 && h < 20) {
      currentTimeOfDay = 'dusk';
    } else {
      currentTimeOfDay = 'night';
    }
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

    // Moon disc — fade in at night (0.85) and dawn (0.4), hidden otherwise
    if (moonMesh !== null) {
      const mat = moonMesh.material as MeshBasicMaterial;
      const moonTarget = currentTimeOfDay === 'night' ? 0.85
        : currentTimeOfDay === 'dawn' ? 0.4
        : 0;
      // elapsed is cumulative — use fixed 60fps step for lerp (smooth regardless of framerate)
      mat.opacity = MathUtils.lerp(mat.opacity, moonTarget, 0.016 * 1.5);
    }

    // Aurora bands — gentle wave + opacity fade (night only)
    auroraMeshes.forEach(mesh => {
      const mat = mesh.material as MeshBasicMaterial;
      const phase = mesh.userData['phase'] as number;
      const auroraTarget = currentTimeOfDay === 'night'
        ? 0.08 + Math.sin(elapsed * 0.3 + phase) * 0.04
        : 0;
      mat.opacity = MathUtils.lerp(mat.opacity, auroraTarget, 0.016 * 1.5);
      mesh.position.x = Math.sin(elapsed * 0.2 + phase) * 0.5;
    });

    // Fireflies — drift and twinkle outside the window (night + dusk only)
    const dt = elapsed - _prevElapsed;
    _prevElapsed = elapsed;
    const flyOpacityTarget = currentTimeOfDay === 'night' ? 0.8
      : currentTimeOfDay === 'dusk' ? 0.4
      : 0;
    _windowFireflies.forEach(fly => {
      const mat = fly.material as MeshBasicMaterial;
      const phase = fly.userData['phase'] as number;
      const vx    = fly.userData['vx'] as number;
      const vy    = fly.userData['vy'] as number;
      // Lerp base opacity toward target
      mat.opacity = MathUtils.lerp(mat.opacity, flyOpacityTarget, 0.016 * 1.5);
      if (flyOpacityTarget > 0) {
        // Drift position
        fly.position.x += vx * dt;
        fly.position.y += vy * dt;
        // Bounce within bounds
        if (fly.position.x < -3 || fly.position.x > 5) { fly.userData['vx'] = -vx; }
        if (fly.position.y <  2 || fly.position.y > 7) { fly.userData['vy'] = -vy; }
        // Twinkle: modulate opacity around the lerped base
        mat.opacity = mat.opacity * (0.6 + Math.sin(elapsed * 4 + phase) * 0.4);
      }
    });

    // Rain streaks — fall down the glass pane at night + dusk
    const rainVisible = currentTimeOfDay === 'night' || currentTimeOfDay === 'dusk';
    _rainStreaks.forEach(streak => {
      const mat = streak.material as MeshBasicMaterial;
      if (rainVisible) {
        if (!streak.visible) { streak.visible = true; }
        mat.opacity = 0.4;
        const speed = streak.userData['speed'] as number;
        streak.position.y -= dt * speed;
        // Reset when fallen below window sill area
        if (streak.position.y < 2.5) {
          streak.position.y = 8.5 + Math.random() * 1.0;
          streak.position.x = 4.0 + (-4 + Math.random() * 8); // center x=4.0 ± 4
        }
      } else {
        streak.visible = false;
        mat.opacity = 0;
      }
    });

    // Starfield — twinkle both tiers via uniform PointsMaterial opacity
    if (_starPoints !== null) {
      group.children.forEach((child, childIndex) => {
        const tier = (child as Points).userData['starTier'] as string | undefined;
        if (tier === undefined) return;
        const pMat = (child as Points).material as PointsMaterial;
        const baseOpacity = tier === 'bright' ? 0.9 : 0.55;
        // Unique phase per Points object; childIndex gives a stable offset
        pMat.opacity = baseOpacity * (Math.sin(elapsed * 1.5 + childIndex * 0.7) * 0.3 + 0.7);
      });
    }

    // Shooting star — countdown → travel → fade, night only
    if (_shootingStar !== null) {
      if (currentTimeOfDay === 'night') {
        if (!_shootingStarActive) {
          _shootingStarTimer -= dt;
          if (_shootingStarTimer <= 0) {
            _shootingStarActive      = true;
            _shootingStarProgress    = 0;
            _shootingStar.visible    = true;
            _shootingStar.position.set(-5, 8, -9.35);
          }
        } else {
          _shootingStarProgress += dt / 0.6;
          if (_shootingStarProgress >= 1) {
            _shootingStarActive   = false;
            _shootingStar.visible = false;
            _shootingStarTimer    = 8 + Math.random() * 4;
          } else {
            const t = _shootingStarProgress;
            _shootingStar.position.x = MathUtils.lerp(-5, 5, t);
            _shootingStar.position.y = MathUtils.lerp(8, 4, t);
            const ssMat = _shootingStar.material as MeshBasicMaterial;
            ssMat.opacity = (1 - t) * 0.95;
          }
        }
      } else if (_shootingStarActive) {
        // Left night mid-shot — clean up
        _shootingStarActive   = false;
        _shootingStar.visible = false;
        _shootingStarTimer    = 8 + Math.random() * 4;
      }
    }
  };

  scene.add(group);
  return { group, windowLight, updateTime, update };
}
