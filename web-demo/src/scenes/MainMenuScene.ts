// ═══════════════════════════════════════════════════════════════════════════════
// Main Menu Scene — Stormy cliff + sea, STATIC camera, animated world
// T061 + T064 (VFX: sea spray particles + god ray sprite)
// Camera is fixed at (0, 12, 35) looking toward (0, 5, -20). World animates.
// ═══════════════════════════════════════════════════════════════════════════════

import * as THREE from 'three';

// ── Types ────────────────────────────────────────────────────────────────────

interface ParticleData {
  baseX: number;
  baseZ: number;
  velY: number;
  velZ: number;
  lifetime: number;
  maxLifetime: number;
}

interface MainMenuResult {
  renderer: THREE.WebGLRenderer;
  update: (dt: number) => void;
  /** No-op kept for API compatibility — camera is now static. Calls onComplete immediately. */
  startDolly: (onComplete: () => void) => void;
  dispose: () => void;
}

// ── Stormy Ocean ─────────────────────────────────────────────────────────────

function createStormyOcean(): { mesh: THREE.Mesh; update: (t: number) => void } {
  const geo = new THREE.PlaneGeometry(400, 400, 80, 80);

  const mat = new THREE.ShaderMaterial({
    uniforms: {
      uTime: { value: 0 },
      uStorminess: { value: 1.0 },
    },
    vertexShader: `
      uniform float uTime;
      uniform float uStorminess;
      varying float vWorldY;
      void main() {
        vec3 pos = position;
        float wave =
          sin(pos.x * 0.10 + uTime * 1.2) * 2.0 +
          cos(pos.y * 0.15 + uTime * 0.8) * 1.5 +
          sin(pos.x * 0.05 + pos.y * 0.07 + uTime * 2.0) * 0.8;
        pos.z += wave * uStorminess;
        vWorldY = pos.z;
        gl_Position = projectionMatrix * modelViewMatrix * vec4(pos, 1.0);
      }
    `,
    fragmentShader: `
      varying float vWorldY;
      void main() {
        float t = clamp((vWorldY + 3.0) / 6.0, 0.0, 1.0);
        vec3 deep = vec3(0.04, 0.08, 0.18);
        vec3 crest = vec3(0.18, 0.35, 0.55);
        vec3 foam  = vec3(0.55, 0.65, 0.75);
        vec3 col = mix(deep, crest, t);
        // Foam on wave peaks
        float foamFactor = smoothstep(0.6, 1.0, t);
        col = mix(col, foam, foamFactor * 0.6);
        // Specular shimmer
        float spec = smoothstep(0.7, 1.0, t) * 0.3;
        col += vec3(spec);
        gl_FragColor = vec4(col, 0.92);
      }
    `,
    transparent: true,
    side: THREE.FrontSide,
  });

  const mesh = new THREE.Mesh(geo, mat);
  mesh.rotation.x = -Math.PI / 2;
  mesh.position.set(0, -2, 0);

  return {
    mesh,
    update: (t: number) => {
      (mat.uniforms['uTime'] as { value: number }).value = t;
    },
  };
}

// ── Cliff Geometry ───────────────────────────────────────────────────────────

function createCliff(): THREE.Group {
  const group = new THREE.Group();
  const mat = new THREE.MeshStandardMaterial({ color: 0x2a2520, roughness: 0.95, metalness: 0.0 });

  // Main cliff body
  const body = new THREE.Mesh(new THREE.BoxGeometry(30, 28, 20), mat);
  body.position.set(-18, 2, -10);
  group.add(body);

  // Upper ledge
  const ledge = new THREE.Mesh(new THREE.BoxGeometry(22, 6, 14), mat);
  ledge.position.set(-14, 17, -8);
  group.add(ledge);

  // Rocky outcrop (irregular, using smaller boxes)
  const rock1 = new THREE.Mesh(new THREE.BoxGeometry(8, 5, 6), mat);
  rock1.position.set(-6, 14, -5);
  rock1.rotation.y = 0.3;
  group.add(rock1);

  const rock2 = new THREE.Mesh(new THREE.BoxGeometry(5, 3, 5), mat);
  rock2.position.set(-10, 18, -3);
  rock2.rotation.y = -0.2;
  group.add(rock2);

  return group;
}

// ── Tower Silhouette ─────────────────────────────────────────────────────────

function createTower(): THREE.Group {
  const group = new THREE.Group();
  const mat = new THREE.MeshStandardMaterial({ color: 0x14120f, roughness: 1.0, metalness: 0.0 });

  // Main tower shaft
  const shaft = new THREE.Mesh(new THREE.BoxGeometry(5, 28, 5), mat);
  shaft.position.set(0, 14, 0);
  group.add(shaft);

  // Battlement top
  const top = new THREE.Mesh(new THREE.BoxGeometry(7, 4, 7), mat);
  top.position.set(0, 30, 0);
  group.add(top);

  // Turret spheres at corners
  const turretMat = new THREE.MeshStandardMaterial({ color: 0x0e0c09, roughness: 1.0, metalness: 0.0 });
  const turretGeo = new THREE.SphereGeometry(1.5, 6, 6);
  const offsets: [number, number][] = [[-3, -3], [3, -3], [-3, 3], [3, 3]];
  for (const [ox, oz] of offsets) {
    const t = new THREE.Mesh(turretGeo, turretMat);
    t.position.set(ox, 32, oz);
    group.add(t);
  }

  // Window glow (orange light from within)
  const windowGeo = new THREE.PlaneGeometry(1.5, 2.0);
  const windowMat = new THREE.MeshBasicMaterial({ color: 0xff8833, transparent: true, opacity: 0.8 });
  const window1 = new THREE.Mesh(windowGeo, windowMat);
  window1.position.set(2.51, 10, 0);
  window1.rotation.y = Math.PI / 2;
  group.add(window1);

  // Point light inside tower
  const insideLight = new THREE.PointLight(0xff6600, 2.0, 25, 2);
  insideLight.position.set(2.5, 10, 0);
  group.add(insideLight);

  group.position.set(32, -2, -70);
  return group;
}

// ── Stormy Sky ───────────────────────────────────────────────────────────────

function createStormySky(): THREE.Mesh {
  const geo = new THREE.SphereGeometry(380, 32, 16);
  const mat = new THREE.ShaderMaterial({
    uniforms: {
      uTime: { value: 0 },
    },
    vertexShader: `
      varying vec3 vWorldPos;
      void main() {
        vWorldPos = position;
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
      }
    `,
    fragmentShader: `
      uniform float uTime;
      varying vec3 vWorldPos;
      void main() {
        float t = clamp((vWorldPos.y + 50.0) / 280.0, 0.0, 1.0);
        vec3 top    = vec3(0.04, 0.04, 0.10);
        vec3 mid    = vec3(0.08, 0.12, 0.22);
        vec3 bottom = vec3(0.16, 0.20, 0.30);
        vec3 col = mix(bottom, mid, min(t * 2.0, 1.0));
        col = mix(col, top, max(t * 2.0 - 1.0, 0.0));
        // Storm cloud streaks
        float cloud = sin(vWorldPos.x * 0.02 + uTime * 0.1) * cos(vWorldPos.z * 0.015 - uTime * 0.08);
        col += vec3(cloud * 0.03);
        gl_FragColor = vec4(col, 1.0);
      }
    `,
    side: THREE.BackSide,
  });

  const sky = new THREE.Mesh(geo, mat);
  return sky;
}

// ── Sea Spray Particle System (T064) ─────────────────────────────────────────

class SeaSpraySystem {
  private readonly points: THREE.Points;
  private readonly positions: Float32Array;
  private readonly opacities: Float32Array;
  private readonly particles: ParticleData[] = [];
  private readonly COUNT = 150;

  constructor() {
    this.positions = new Float32Array(this.COUNT * 3);
    this.opacities = new Float32Array(this.COUNT);

    // Initialize particles
    for (let i = 0; i < this.COUNT; i++) {
      this.particles.push(this.resetParticle(i));
    }

    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.BufferAttribute(this.positions, 3));

    const mat = new THREE.PointsMaterial({
      color: 0xaaccdd,
      size: 0.25,
      transparent: true,
      opacity: 0.6,
      blending: THREE.AdditiveBlending,
      depthWrite: false,
      sizeAttenuation: true,
    });

    this.points = new THREE.Points(geo, mat);
  }

  private resetParticle(i: number): ParticleData {
    const baseX = -20 + Math.random() * 20;
    const baseZ = -20 + Math.random() * 20;
    const maxLifetime = 1.2 + Math.random() * 1.0;

    this.positions[i * 3]     = baseX;
    this.positions[i * 3 + 1] = -1.5 + Math.random() * 0.5;
    this.positions[i * 3 + 2] = baseZ;

    return {
      baseX,
      baseZ,
      velY: 2.5 + Math.random() * 2.5,
      velZ: (Math.random() - 0.5) * 1.5,
      lifetime: Math.random() * maxLifetime, // stagger initial positions
      maxLifetime,
    };
  }

  update(dt: number): void {
    for (let i = 0; i < this.COUNT; i++) {
      const p = this.particles[i];
      p.lifetime += dt;

      const alive = p.lifetime / p.maxLifetime;

      if (p.lifetime >= p.maxLifetime) {
        const reset = this.resetParticle(i);
        reset.lifetime = 0; // always start fresh on death
        this.particles[i] = reset;
        continue;
      }

      this.positions[i * 3 + 1] += p.velY * dt;
      this.positions[i * 3 + 2] += p.velZ * dt;

      // Fade in then out
      this.opacities[i] = alive < 0.2
        ? alive / 0.2
        : 1.0 - (alive - 0.2) / 0.8;
    }

    const posAttr = this.points.geometry.getAttribute('position') as THREE.BufferAttribute;
    posAttr.needsUpdate = true;
  }

  get object(): THREE.Points {
    return this.points;
  }
}

// ── God Ray Sprite (T064) ────────────────────────────────────────────────────

function createGodRay(): { sprite: THREE.Sprite; update: (t: number) => void } {
  const mat = new THREE.SpriteMaterial({
    color: 0xffeeaa,
    transparent: true,
    opacity: 0.15,
    blending: THREE.AdditiveBlending,
    depthWrite: false,
  });

  const sprite = new THREE.Sprite(mat);
  sprite.position.set(12, 28, -22);
  sprite.scale.set(28, 65, 1);

  return {
    sprite,
    update: (t: number) => {
      mat.opacity = 0.12 + Math.sin(t * 0.7) * 0.05;
    },
  };
}

// ── Public: initMainMenu ─────────────────────────────────────────────────────

export function initMainMenu(container: HTMLElement): MainMenuResult {
  // Scene
  const scene = new THREE.Scene();
  scene.fog = new THREE.FogExp2(0x1a2030, 0.008);

  // Camera — STATIC, locked at a beautiful angle. World animates, camera does not.
  const camera = new THREE.PerspectiveCamera(
    60,
    container.clientWidth / container.clientHeight,
    0.1,
    800
  );
  camera.position.set(0, 12, 35);
  camera.lookAt(new THREE.Vector3(0, 5, -20));

  // Renderer
  const renderer = new THREE.WebGLRenderer({
    antialias: true,
    alpha: false,
  });
  renderer.setSize(container.clientWidth, container.clientHeight);
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 0.85;
  container.appendChild(renderer.domElement);

  // Resize
  const onResize = () => {
    camera.aspect = container.clientWidth / container.clientHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(container.clientWidth, container.clientHeight);
  };
  window.addEventListener('resize', onResize);

  // Lighting
  const ambient = new THREE.AmbientLight(0x334455, 0.5);
  scene.add(ambient);

  const cliffLight = new THREE.PointLight(0xffaa44, 1.5, 80, 1.5);
  cliffLight.position.set(-14, 22, -5);
  scene.add(cliffLight);

  const moonLight = new THREE.DirectionalLight(0x8899bb, 0.4);
  moonLight.position.set(-20, 40, 20);
  scene.add(moonLight);

  // Build scene elements
  const ocean = createStormyOcean();
  scene.add(ocean.mesh);

  const cliff = createCliff();
  scene.add(cliff);

  const tower = createTower();
  scene.add(tower);

  const sky = createStormySky();
  scene.add(sky);

  const spray = new SeaSpraySystem();
  scene.add(spray.object);

  const godRay = createGodRay();
  scene.add(godRay.sprite);

  // Elapsed time accumulator for world animation
  let elapsedTime = 0;

  // Animation loop (called from main.ts) — camera is static, world animates
  const update = (dt: number): void => {
    elapsedTime += dt;

    ocean.update(elapsedTime);
    godRay.update(elapsedTime);
    spray.update(dt);

    // Animate sky time uniform
    const skyMat = sky.material as THREE.ShaderMaterial;
    (skyMat.uniforms['uTime'] as { value: number }).value = elapsedTime;

    // Subtle cliff light flicker
    cliffLight.intensity = 1.4 + Math.sin(elapsedTime * 3.1) * 0.15;

    renderer.render(scene, camera);
  };

  // No-op: camera is static. Calls onComplete immediately for flow compatibility.
  const startDolly = (onComplete: () => void): void => {
    onComplete();
  };

  const dispose = (): void => {
    window.removeEventListener('resize', onResize);
    renderer.dispose();
    // Dispose geometries + materials
    scene.traverse((obj) => {
      if (obj instanceof THREE.Mesh || obj instanceof THREE.Points) {
        obj.geometry.dispose();
        if (Array.isArray(obj.material)) {
          obj.material.forEach((m) => m.dispose());
        } else {
          (obj.material as THREE.Material).dispose();
        }
      }
    });
    if (renderer.domElement.parentNode) {
      renderer.domElement.parentNode.removeChild(renderer.domElement);
    }
  };

  return { renderer, update, startDolly, dispose };
}
